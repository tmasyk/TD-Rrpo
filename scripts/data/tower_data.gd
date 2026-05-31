class_name TowerData
extends Resource
## Designer-tunable tower archetype. Author concrete towers as .tres files in the
## editor (res://resources/towers/). Towers double as maze walls — each occupies
## one grid cell and reshapes the enemy path.

@export var id: StringName = &"arrow"
@export var display_name: String = "Arrow Tower"
@export_multiline var description: String = ""

@export_group("Cost")
@export var build_cost: int = 50
@export var sell_value: int = 25

@export_group("Combat")
@export var damage: float = 8.0
@export var attack_range: float = 3.0      # in grid cells
@export var fire_rate: float = 1.0         # shots per second
@export var splash_radius: float = 0.0     # 0 = single target
@export var slow_factor: float = 0.0       # 0 = no slow, 0.3 = 30% slower
@export var slow_duration: float = 0.0
@export var armor_pierce: int = 0          # ignores this much enemy armor
@export var can_target_flying: bool = true

@export_group("Progression")
@export var upgrades_into: Array[TowerData] = []
