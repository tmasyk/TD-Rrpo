class_name FloorSpec
extends RefCounted
## A fully-described floor, produced by FloorGenerator. Pure data — no scene refs.

var floor_number: int = 1
var wing_id: StringName = &"foundation"
var seed: int = 0

## Buildable grid size in cells.
var grid_size: Vector2i = Vector2i(11, 16)
## Cells the player cannot build on (pre-placed rock/hazard).
var obstacle_cells: Array[Vector2i] = []
## Where enemies spawn and where they must reach.
var entrances: Array[Vector2i] = []
var exits: Array[Vector2i] = []

## Economy / pacing.
var starting_gold: int = 100
var starting_lives: int = 20
var wave_count: int = 8

## Free-form modifiers for landmark/twist floors (e.g. {"fog": true}).
var modifiers: Dictionary = {}

func _to_string() -> String:
	return "FloorSpec(floor=%d wing=%s grid=%s waves=%d obstacles=%d mods=%s)" % [
		floor_number, wing_id, str(grid_size), wave_count,
		obstacle_cells.size(), str(modifiers),
	]
