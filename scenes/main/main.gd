extends Node2D
## M0 scaffold entry scene. Not the real game yet — it's a *visible smoke test*
## of the procedural pipeline so the architecture is observable before art/actors.
##
## On launch it starts a run, asks FloorGenerator for the current floor, builds a
## MazeGrid, and draws it: obstacles, entrance(s), exit(s), any test towers, and
## the current shortest enemy path. It also logs the generated FloorSpec and a
## sample WaveDirector composition to the Output panel.
##
## Controls (for the scaffold):
##   - Left click a cell : try to place/remove a test tower (maze rule enforced)
##   - N                 : generate the next floor
##   - R                 : restart the run

const CELL := 42
const MARGIN := Vector2(28, 120)

const COL_BG := Color(0.12, 0.13, 0.18)
const COL_GRID := Color(0.22, 0.24, 0.32)
const COL_OBSTACLE := Color(0.35, 0.30, 0.28)
const COL_ENTRANCE := Color(0.37, 0.83, 0.64)
const COL_EXIT := Color(0.90, 0.42, 0.45)
const COL_TOWER := Color(0.40, 0.55, 0.95)
const COL_PATH := Color(0.95, 0.85, 0.35, 0.85)

var _grid: MazeGrid
var _spec: FloorSpec
var _hud: Label

func _ready() -> void:
	_hud = $CanvasLayer/HUD
	EventBus.floor_started.connect(_on_floor_started)
	RunManager.start_run()

func _on_floor_started(_floor_number: int) -> void:
	_setup_floor()

func _setup_floor() -> void:
	_spec = RunManager.current_floor_spec
	_grid = MazeGrid.new(_spec.grid_size, _spec.entrances, _spec.exits)
	for cell in _spec.obstacle_cells:
		_grid.add_obstacle(cell)

	# Log the procedural output so the pipeline is observable headless.
	print("── ", _spec)
	var sample_wave := RunManager.compose_wave(0, {
		"leak_rate": 0.0, "lives_fraction": 1.0, "gold_banked": 100,
	})
	print("   sample wave 0: ", sample_wave)

	_refresh_hud()
	queue_redraw()

func _refresh_hud() -> void:
	if _hud == null:
		return
	_hud.text = "ASCENT — scaffold demo\nFloor %d  ·  Lives %d  ·  Gold %d\nGrid %s  ·  Waves %d\n[Click] tower   [N] next floor   [R] restart" % [
		RunManager.floor_number, RunManager.lives, RunManager.gold,
		str(_spec.grid_size), _spec.wave_count,
	]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_cell_clicked(_world_to_cell(event.position))
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_N:
			RunManager.advance_floor()  # emits floor_started -> _setup_floor
		elif event.keycode == KEY_R:
			RunManager.start_run()

func _on_cell_clicked(cell: Vector2i) -> void:
	if _grid == null or not _grid.in_bounds(cell):
		return
	if _grid.is_blocked(cell) and not (cell in _spec.obstacle_cells):
		_grid.remove_tower(cell)
	else:
		if not _grid.place_tower(cell):
			# Rejected (would seal the maze, or illegal cell).
			print("   placement rejected at ", cell)
	queue_redraw()

# --- Coordinate helpers ---

func _cell_to_world(cell: Vector2i) -> Vector2:
	return MARGIN + Vector2(cell.x * CELL, cell.y * CELL)

func _world_to_cell(pos: Vector2) -> Vector2i:
	var local := (pos - MARGIN) / float(CELL)
	return Vector2i(int(floor(local.x)), int(floor(local.y)))

# --- Rendering ---

func _draw() -> void:
	if _spec == null:
		return
	# Grid background + lines.
	for y in range(_spec.grid_size.y):
		for x in range(_spec.grid_size.x):
			var cell := Vector2i(x, y)
			var rect := Rect2(_cell_to_world(cell), Vector2(CELL, CELL))
			draw_rect(rect, COL_BG, true)
			draw_rect(rect, COL_GRID, false, 1.0)

	# Obstacles.
	for cell in _spec.obstacle_cells:
		draw_rect(_inset(cell), COL_OBSTACLE, true)

	# Test towers (blocked cells that aren't pre-placed obstacles).
	for cell in _grid.get_blocked_cells():
		if not (cell in _spec.obstacle_cells):
			draw_rect(_inset(cell), COL_TOWER, true)

	# Entrances / exits.
	for cell in _spec.entrances:
		draw_rect(_inset(cell), COL_ENTRANCE, true)
	for cell in _spec.exits:
		draw_rect(_inset(cell), COL_EXIT, true)

	# Current shortest path from the first entrance to the first exit.
	if not _spec.entrances.is_empty() and not _spec.exits.is_empty():
		var path := _grid.get_path(_spec.entrances[0], _spec.exits[0])
		if path.size() >= 2:
			var pts := PackedVector2Array()
			for p in path:
				pts.append(_cell_to_world(Vector2i(p)) + Vector2(CELL, CELL) * 0.5)
			draw_polyline(pts, COL_PATH, 3.0)

func _inset(cell: Vector2i) -> Rect2:
	return Rect2(_cell_to_world(cell) + Vector2(3, 3), Vector2(CELL - 6, CELL - 6))
