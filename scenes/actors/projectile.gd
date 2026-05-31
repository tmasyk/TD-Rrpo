class_name Projectile
extends Node2D
## A homing shot fired by a Tower. Tracks its target; on impact deals damage
## (single-target or splash) and applies slow if the firing tower has it.

const SPEED := 480.0
const HIT_DISTANCE := 8.0

var _target: Enemy = null
var _damage: float = 8.0
var _pierce: int = 0
var _splash_radius_px: float = 0.0
var _slow_factor: float = 0.0
var _slow_duration: float = 0.0
var _color: Color = Color(0.95, 0.95, 0.7)

func setup(target: Enemy, damage: float, pierce: int, splash_radius_px: float,
		slow_factor: float, slow_duration: float, color: Color) -> void:
	_target = target
	_damage = damage
	_pierce = pierce
	_splash_radius_px = splash_radius_px
	_slow_factor = slow_factor
	_slow_duration = slow_duration
	_color = color

func _physics_process(delta: float) -> void:
	# Target may have died or leaked before we arrive.
	if not is_instance_valid(_target):
		queue_free()
		return
	var to_target := _target.global_position - global_position
	var dist := to_target.length()
	var step := SPEED * delta
	if dist <= step + HIT_DISTANCE:
		global_position = _target.global_position
		_impact()
		return
	global_position += to_target / dist * step
	queue_redraw()

func _impact() -> void:
	if _splash_radius_px > 0.0:
		# Damage everything in the blast.
		for e in get_tree().get_nodes_in_group("enemies"):
			var enemy := e as Enemy
			if enemy == null:
				continue
			if enemy.global_position.distance_to(global_position) <= _splash_radius_px:
				enemy.take_damage(_damage, _pierce)
				enemy.apply_slow(_slow_factor, _slow_duration)
	elif is_instance_valid(_target):
		_target.take_damage(_damage, _pierce)
		_target.apply_slow(_slow_factor, _slow_duration)
	queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 4.0, _color)
