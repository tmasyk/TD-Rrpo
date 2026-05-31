class_name EnemyData
extends Resource
## Designer-tunable enemy family baseline. The WaveDirector scales these by floor
## at runtime; authored .tres files (res://resources/enemies/) define the family's
## identity, art, and flags. Author concrete enemies in the editor.

@export var family: StringName = &"normal"
@export var display_name: String = "Grunt"

@export_group("Base stats (floor 1)")
@export var base_hp: int = 20
@export var base_speed: float = 1.0        # cells per second multiplier
@export var base_armor: int = 0
@export var base_bounty: int = 2

@export_group("Flags")
@export var is_flying: bool = false
@export var is_shielded: bool = false
@export var is_boss: bool = false

@export_group("Presentation")
@export var tint: Color = Color.WHITE
@export var sprite: Texture2D = null       # placeholder until asset pipeline (M6)
