class_name Enemy
extends Node2D
## A single enemy. Follows a precomputed path of world points from its entrance
## to an exit; if it reaches the end it "leaks" (costs a life), if its HP hits 0
## it dies (pays a bounty). Visuals are a placeholder colored circle until art (M6).

## Base traversal speed; the per-enemy `speed` multiplier scales this.
const BASE_CELLS_PER_SEC := 2.2

signal died(bounty: int)
signal leaked()

var max_hp: int = 20
var hp: int = 20
var armor: int = 0
var bounty: int = 2
var family: StringName = &"normal"
var flags: Array = []

var _pixels_per_sec: float = 0.0
var _path: PackedVector2Array = PackedVector2Array()
var _idx: int = 1                      # index of the next waypoint we're heading to
var _dead: bool = false
var _radius: float = 11.0

# Slow / CC state.
var _slow_mult: float = 1.0
var _slow_timer: float = 0.0

## Configure from a WaveDirector spawn entry. `path` is world-space waypoints.
func setup(entry: Dictionary, path: PackedVector2Array, cell_size: int) -> void:
	max_hp = int(entry.get("hp", 20))
	hp = max_hp
	armor = int(entry.get("armor", 0))
	bounty = int(entry.get("bounty", 2))
	family = entry.get("family", &"normal")
	flags = entry.get("flags", [])
	var speed_mult := float(entry.get("speed", 1.0))
	_pixels_per_sec = BASE_CELLS_PER_SEC * speed_mult * float(cell_size)
	_path = path
	if _path.size() > 0:
		global_position = _path[0]
	_idx = 1
	if &"flying" in flags:
		_radius = 9.0

func _ready() -> void:
	add_to_group("enemies")

func is_flying() -> bool:
	return &"flying" in flags

## How far along the path this enemy is (used by towers to prioritize leaders).
func progress() -> int:
	return _idx

func _physics_process(delta: float) -> void:
	if _dead:
		return
	# Tick down any active slow.
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_mult = 1.0

	if _idx >= _path.size():
		_leak()
		return

	var target := _path[_idx]
	var step := _pixels_per_sec * _slow_mult * delta
	var to_target := target - global_position
	var dist := to_target.length()
	if dist <= step:
		global_position = target
		_idx += 1
		if _idx >= _path.size():
			_leak()
	else:
		global_position += to_target / dist * step
	queue_redraw()

func take_damage(amount: float, pierce: int = 0) -> void:
	if _dead:
		return
	var effective_armor := maxi(0, armor - pierce)
	var dealt := maxi(1, int(round(amount)) - effective_armor)
	hp -= dealt
	if hp <= 0:
		_die()
	else:
		queue_redraw()

func apply_slow(factor: float, duration: float) -> void:
	if factor <= 0.0 or duration <= 0.0:
		return
	# Strongest slow wins; refresh duration.
	_slow_mult = minf(_slow_mult, 1.0 - clampf(factor, 0.0, 0.9))
	_slow_timer = maxf(_slow_timer, duration)

func _die() -> void:
	if _dead:
		return
	_dead = true
	died.emit(bounty)
	queue_free()

func _leak() -> void:
	if _dead:
		return
	_dead = true
	leaked.emit()
	queue_free()

func _draw() -> void:
	var base := Color(0.86, 0.36, 0.4)
	match family:
		&"fast": base = Color(0.95, 0.78, 0.32)
		&"armored": base = Color(0.55, 0.58, 0.66)
		&"swarm": base = Color(0.78, 0.45, 0.85)
		&"flying": base = Color(0.5, 0.8, 0.95)
		&"shielded": base = Color(0.4, 0.7, 0.7)
		&"boss": base = Color(0.95, 0.25, 0.25)
	draw_circle(Vector2.ZERO, _radius, base)
	# HP bar.
	if hp < max_hp:
		var w := 22.0
		var frac := clampf(float(hp) / float(max_hp), 0.0, 1.0)
		var top := Vector2(-w * 0.5, -_radius - 7.0)
		draw_rect(Rect2(top, Vector2(w, 3.0)), Color(0, 0, 0, 0.6), true)
		draw_rect(Rect2(top, Vector2(w * frac, 3.0)), Color(0.3, 0.9, 0.4), true)
