class_name Tower
extends Node2D
## A placed tower. Occupies one grid cell (so it also acts as a maze wall via the
## MazeGrid), acquires targets in range, and fires Projectiles on a cooldown.

const ProjectileScene := preload("res://scenes/actors/projectile.tscn")

var data: TowerData
var cell: Vector2i
var _cell_size: int = 42
var _range_px: float = 0.0
var _cooldown: float = 0.0
var _show_range: bool = false

func setup(tower_data: TowerData, grid_cell: Vector2i, cell_center: Vector2, cell_size: int) -> void:
	data = tower_data
	cell = grid_cell
	_cell_size = cell_size
	global_position = cell_center
	_range_px = data.attack_range * float(cell_size)

func _physics_process(delta: float) -> void:
	if data == null:
		return
	if _cooldown > 0.0:
		_cooldown -= delta
		return
	var target := _acquire_target()
	if target != null:
		_fire(target)
		_cooldown = 1.0 / maxf(0.05, data.fire_rate)

## Target the in-range enemy nearest to its goal (the "leader"), so we focus
## the enemy most likely to leak.
func _acquire_target() -> Enemy:
	var best: Enemy = null
	var best_progress := -1
	for e in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as Enemy
		if enemy == null:
			continue
		if enemy.is_flying() and not data.can_target_flying:
			continue
		if enemy.global_position.distance_to(global_position) > _range_px:
			continue
		if enemy.progress() > best_progress:
			best_progress = enemy.progress()
			best = enemy
	return best

func _fire(target: Enemy) -> void:
	var proj := ProjectileScene.instantiate() as Projectile
	proj.global_position = global_position
	var splash_px := data.splash_radius * float(_cell_size)
	proj.setup(target, data.damage, data.armor_pierce, splash_px,
			data.slow_factor, data.slow_duration, _color())
	# Siblings of the tower so they render in the same space.
	get_parent().add_child(proj)

func set_show_range(v: bool) -> void:
	_show_range = v
	queue_redraw()

func _color() -> Color:
	match data.id:
		&"cannon": return Color(0.9, 0.55, 0.3)
		&"frost": return Color(0.5, 0.8, 0.95)
		_: return Color(0.45, 0.6, 0.95)

func _draw() -> void:
	var half := float(_cell_size) * 0.5 - 4.0
	draw_rect(Rect2(Vector2(-half, -half), Vector2(half * 2, half * 2)), _color(), true)
	if _show_range and _range_px > 0.0:
		draw_arc(Vector2.ZERO, _range_px, 0.0, TAU, 48, Color(1, 1, 1, 0.18), 1.5)
