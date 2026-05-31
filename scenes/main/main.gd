extends Node2D
## M1 floor controller — a playable single-floor slice.
##
## Drives the build/wave loop for the current floor: the player places towers
## during the build phase (towers reshape the maze via MazeGrid), then starts a
## wave; enemies pathfind from the entrance to the exit while towers fire. Clear
## all waves -> the floor is cleared and the next (harder) floor generates.
##
## Controls: left-click a cell to build · [1]/[2] select tower · [Space] start
## wave · [R] restart run.

const CELL := 42
const MARGIN := Vector2(40, 170)

const COL_BG := Color(0.12, 0.13, 0.18)
const COL_GRID := Color(0.20, 0.22, 0.30)
const COL_OBSTACLE := Color(0.35, 0.30, 0.28)
const COL_ENTRANCE := Color(0.37, 0.83, 0.64)
const COL_EXIT := Color(0.90, 0.42, 0.45)
const COL_PATH := Color(0.95, 0.85, 0.35, 0.5)

const EnemyScene := preload("res://scenes/actors/enemy.tscn")

# Tower catalog (editor-tunable .tres). Replaced/expanded via the Academy meta later.
const TOWERS := {
	&"arrow": preload("res://resources/towers/arrow.tres"),
	&"cannon": preload("res://resources/towers/cannon.tres"),
}

enum Phase { BUILD, WAVE, GAME_OVER }

var _grid: MazeGrid
var _spec: FloorSpec
var _phase: int = Phase.BUILD
var _wave_index: int = 0
var _selected_tower: StringName = &"arrow"
var _towers: Array[Tower] = []

# Active-wave state.
var _wave_spec: WaveSpec
var _spawn_queue: Array[Dictionary] = []
var _spawn_interval: float = 0.6
var _spawn_timer: float = 0.0
var _alive: int = 0
var _enemy_path: PackedVector2Array = PackedVector2Array()

# Performance tracking for the WaveDirector.
var _this_wave_total: int = 0
var _this_wave_leaked: int = 0
var _last_wave_total: int = 0
var _last_wave_leaked: int = 0

@onready var _hud: Label = $CanvasLayer/HUD
@onready var _toast: Label = $CanvasLayer/Toast
@onready var _start_btn: Button = $CanvasLayer/StartWave
@onready var _arrow_btn: Button = $CanvasLayer/ArrowBtn
@onready var _cannon_btn: Button = $CanvasLayer/CannonBtn
@onready var _towers_root: Node2D = $Towers
@onready var _enemies_root: Node2D = $Enemies
@onready var _projectiles_root: Node2D = $Projectiles

func _ready() -> void:
	EventBus.floor_started.connect(_on_floor_started)
	EventBus.gold_changed.connect(func(_g): _refresh_hud())
	EventBus.lives_changed.connect(func(_l): _refresh_hud())
	EventBus.run_ended.connect(_on_run_ended)
	_start_btn.pressed.connect(_on_start_pressed)
	_arrow_btn.pressed.connect(func(): _select_tower(&"arrow"))
	_cannon_btn.pressed.connect(func(): _select_tower(&"cannon"))
	RunManager.start_run()

# --- Floor lifecycle ---

func _on_floor_started(_floor_number: int) -> void:
	_setup_floor()

func _setup_floor() -> void:
	_spec = RunManager.current_floor_spec
	_grid = MazeGrid.new(_spec.grid_size, _spec.entrances, _spec.exits)
	for cell in _spec.obstacle_cells:
		_grid.add_obstacle(cell)

	_clear_children(_towers_root)
	_clear_children(_enemies_root)
	_clear_children(_projectiles_root)
	_towers.clear()
	_wave_index = 0
	_alive = 0
	_last_wave_total = 0
	_last_wave_leaked = 0
	_phase = Phase.BUILD

	_start_btn.disabled = false
	_set_toast("Floor %d — build your maze, then Start Wave." % RunManager.floor_number)
	_refresh_hud()
	queue_redraw()

# --- Build phase ---

func _select_tower(id: StringName) -> void:
	_selected_tower = id
	_arrow_btn.button_pressed = id == &"arrow"
	_cannon_btn.button_pressed = id == &"cannon"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_build(_world_to_cell(event.position))
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: _select_tower(&"arrow")
			KEY_2: _select_tower(&"cannon")
			KEY_SPACE: _on_start_pressed()
			KEY_R: RunManager.start_run()

func _try_build(cell: Vector2i) -> bool:
	if _phase != Phase.BUILD or _grid == null:
		return false
	var data: TowerData = TOWERS[_selected_tower]
	if RunManager.gold < data.build_cost:
		_set_toast("Not enough gold for %s." % data.display_name)
		return false
	if not _grid.can_place(cell):
		_set_toast("Can't build there — it would seal the maze.")
		return false
	if not RunManager.try_spend_gold(data.build_cost):
		return false
	_grid.place_tower(cell)
	var tower := preload("res://scenes/actors/tower.tscn").instantiate() as Tower
	tower.setup(data, cell, _cell_center(cell), CELL)
	_towers_root.add_child(tower)
	_towers.append(tower)
	EventBus.tower_placed.emit(cell, _selected_tower)
	queue_redraw()  # path preview shifts
	return true

# --- Wave phase ---

func _on_start_pressed() -> void:
	if _phase != Phase.BUILD:
		return
	_start_wave()

func _start_wave() -> void:
	# Lock in the path for this wave (no building mid-wave in M1).
	_enemy_path = _compute_world_path()
	if _enemy_path.size() < 2:
		_set_toast("No path to the exit!")
		return

	_wave_spec = RunManager.compose_wave(_wave_index, _perf_snapshot())
	_spawn_queue = _expand_wave(_wave_spec)
	_spawn_interval = maxf(0.15, _wave_spec.spawn_interval)
	_spawn_timer = 0.0
	_this_wave_total = _spawn_queue.size()
	_this_wave_leaked = 0

	_phase = Phase.WAVE
	_start_btn.disabled = true
	_set_toast("Wave %d / %d — %d incoming!" % [_wave_index + 1, _spec.wave_count, _this_wave_total])
	_refresh_hud()

func _physics_process(delta: float) -> void:
	if _phase != Phase.WAVE:
		return
	# Spawn from the queue on a cadence.
	if not _spawn_queue.is_empty():
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_one(_spawn_queue.pop_front())
			_spawn_timer = _spawn_interval
	# Wave ends when nothing is left to spawn and the field is clear.
	elif _alive <= 0:
		_on_wave_complete()

func _spawn_one(entry: Dictionary) -> void:
	var enemy := EnemyScene.instantiate() as Enemy
	enemy.setup(entry, _enemy_path, CELL)
	enemy.died.connect(_on_enemy_died)
	enemy.leaked.connect(_on_enemy_leaked)
	_enemies_root.add_child(enemy)
	_alive += 1
	EventBus.enemy_spawned.emit(enemy)

func _on_enemy_died(bounty: int) -> void:
	_alive -= 1
	RunManager.add_gold(bounty)

func _on_enemy_leaked() -> void:
	_alive -= 1
	_this_wave_leaked += 1
	RunManager.lose_life(1)

func _on_wave_complete() -> void:
	_last_wave_total = _this_wave_total
	_last_wave_leaked = _this_wave_leaked
	_wave_index += 1
	if _wave_index >= _spec.wave_count:
		RunManager.clear_current_floor()
		_set_toast("Floor %d cleared! Ascending..." % RunManager.floor_number)
		await get_tree().create_timer(1.2).timeout
		if _phase != Phase.GAME_OVER:
			RunManager.advance_floor()  # emits floor_started -> _setup_floor
	else:
		_phase = Phase.BUILD
		_start_btn.disabled = false
		_set_toast("Wave cleared. Build, then Start Wave %d / %d." % [_wave_index + 1, _spec.wave_count])
		_refresh_hud()

func _on_run_ended(victory: bool, floor_reached: int) -> void:
	_phase = Phase.GAME_OVER
	_start_btn.disabled = true
	var msg := "Victory!" if victory else "Run over."
	_set_toast("%s Reached floor %d.\nPress R to start a new run." % [msg, floor_reached])

# --- WaveDirector inputs ---

func _perf_snapshot() -> Dictionary:
	var total := float(maxi(1, _towers.size()))
	var splash := 0
	var slow := 0
	var single := 0
	for t in _towers:
		if t.data.splash_radius > 0.0:
			splash += 1
		elif t.data.slow_factor > 0.0:
			slow += 1
		else:
			single += 1
	var leak_rate := 0.0
	if _last_wave_total > 0:
		leak_rate = float(_last_wave_leaked) / float(_last_wave_total)
	return {
		"leak_rate": leak_rate,
		"lives_fraction": float(RunManager.lives) / float(maxi(1, _spec.starting_lives)),
		"gold_banked": RunManager.gold,
		"splash_ratio": float(splash) / total,
		"single_ratio": float(single) / total,
		"slow_ratio": float(slow) / total,
	}

## Expand a WaveSpec into a round-robin queue of single-enemy spawn dicts so
## families interleave instead of arriving in big mono-blocks.
func _expand_wave(wave: WaveSpec) -> Array[Dictionary]:
	var lanes: Array = []
	for entry in wave.spawns:
		var lane: Array[Dictionary] = []
		var single: Dictionary = entry.duplicate()
		single.erase("count")
		for _i in range(int(entry.get("count", 0))):
			lane.append(single)
		lanes.append(lane)
	var queue: Array[Dictionary] = []
	var added := true
	while added:
		added = false
		for lane in lanes:
			if not lane.is_empty():
				queue.append(lane.pop_front())
				added = true
	return queue

# --- Geometry ---

func _compute_world_path() -> PackedVector2Array:
	if _spec.entrances.is_empty() or _spec.exits.is_empty():
		return PackedVector2Array()
	var cell_path := _grid.get_path(_spec.entrances[0], _spec.exits[0])
	var world := PackedVector2Array()
	for p in cell_path:
		world.append(_cell_center(Vector2i(p)))
	return world

func _cell_center(cell: Vector2i) -> Vector2:
	return MARGIN + Vector2(cell.x * CELL, cell.y * CELL) + Vector2(CELL, CELL) * 0.5

func _world_to_cell(pos: Vector2) -> Vector2i:
	var local := (pos - MARGIN) / float(CELL)
	return Vector2i(int(floor(local.x)), int(floor(local.y)))

# --- UI ---

func _refresh_hud() -> void:
	if _hud == null or _spec == null:
		return
	var sel: TowerData = TOWERS[_selected_tower]
	_hud.text = "ASCENT  ·  Floor %d\nLives %d   Gold %d\nWave %d / %d   ·   Building: %s (%d)" % [
		RunManager.floor_number, RunManager.lives, RunManager.gold,
		mini(_wave_index + 1, _spec.wave_count), _spec.wave_count,
		sel.display_name, sel.build_cost,
	]

func _set_toast(text: String) -> void:
	if _toast:
		_toast.text = text

func _clear_children(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()

# --- Render the static board (actors draw themselves) ---

func _draw() -> void:
	if _spec == null:
		return
	for y in range(_spec.grid_size.y):
		for x in range(_spec.grid_size.x):
			var rect := Rect2(MARGIN + Vector2(x * CELL, y * CELL), Vector2(CELL, CELL))
			draw_rect(rect, COL_BG, true)
			draw_rect(rect, COL_GRID, false, 1.0)
	for cell in _spec.obstacle_cells:
		draw_rect(_inset(cell), COL_OBSTACLE, true)
	for cell in _spec.entrances:
		draw_rect(_inset(cell), COL_ENTRANCE, true)
	for cell in _spec.exits:
		draw_rect(_inset(cell), COL_EXIT, true)
	# Path preview during the build phase.
	if _phase == Phase.BUILD and _grid != null:
		var path := _compute_world_path()
		if path.size() >= 2:
			draw_polyline(path, COL_PATH, 3.0)

func _inset(cell: Vector2i) -> Rect2:
	return Rect2(MARGIN + Vector2(cell.x * CELL, cell.y * CELL) + Vector2(3, 3), Vector2(CELL - 6, CELL - 6))
