class_name FloorGenerator
extends RefCounted
## Procedurally builds a FloorSpec from (floor_number, wing, seed).
##
## Deterministic: the same inputs always yield the same floor, so runs are
## reproducible for debugging and daily-challenge seeds. Higher floors get
## bigger grids, more obstacles, and twist modifiers.

## How many floors share one wing's tuning band before difficulty "wraps".
const FLOORS_PER_LANDMARK := 10

func generate(floor_number: int, wing_id: StringName, seed: int) -> FloorSpec:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	var spec := FloorSpec.new()
	spec.floor_number = floor_number
	spec.wing_id = wing_id
	spec.seed = seed

	# --- Grid grows slowly with depth, capped for mobile screens. ---
	var width: int = clampi(9 + floor_number / 4, 9, 15)
	var height: int = clampi(14 + floor_number / 3, 14, 22)
	spec.grid_size = Vector2i(width, height)

	# --- Entrance(s) along the top, exit(s) along the bottom. ---
	# Deeper floors can have multiple lanes, which complicates mazing.
	var lane_count: int = 1 + mini(floor_number / 12, 2)
	spec.entrances = _spread_points(rng, width, 0, lane_count)
	spec.exits = _spread_points(rng, width, height - 1, lane_count)

	# --- Pre-placed obstacles constrain the buildable maze. ---
	# Density ramps with depth but stays low enough to keep floors solvable.
	var obstacle_ratio: float = clampf(0.02 + floor_number * 0.004, 0.02, 0.12)
	spec.obstacle_cells = _scatter_obstacles(rng, spec, obstacle_ratio)

	# --- Economy / pacing scale gently with depth. ---
	spec.starting_gold = 100  # carried from RunManager in real runs; informative here
	spec.starting_lives = 20
	spec.wave_count = clampi(6 + floor_number / 3, 6, 15)

	# --- Twist modifiers on landmark floors. ---
	spec.modifiers = _roll_modifiers(rng, floor_number)

	return spec

## Pick `count` distinct x-positions on a given row, biased toward spread-out.
func _spread_points(rng: RandomNumberGenerator, width: int, y: int, count: int) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var used: Dictionary = {}
	var attempts := 0
	while points.size() < count and attempts < 64:
		attempts += 1
		var x := rng.randi_range(1, width - 2)
		if used.has(x):
			continue
		used[x] = true
		points.append(Vector2i(x, y))
	if points.is_empty():
		points.append(Vector2i(width / 2, y))
	return points

func _scatter_obstacles(rng: RandomNumberGenerator, spec: FloorSpec, ratio: float) -> Array[Vector2i]:
	var obstacles: Array[Vector2i] = []
	var reserved: Dictionary = {}
	for p in spec.entrances:
		reserved[p] = true
	for p in spec.exits:
		reserved[p] = true

	var total := spec.grid_size.x * spec.grid_size.y
	var target := int(round(total * ratio))
	var placed := 0
	var attempts := 0
	while placed < target and attempts < total * 4:
		attempts += 1
		var cell := Vector2i(
			rng.randi_range(0, spec.grid_size.x - 1),
			rng.randi_range(1, spec.grid_size.y - 2),  # keep top/bottom rows clear
		)
		if reserved.has(cell):
			continue
		reserved[cell] = true
		obstacles.append(cell)
		placed += 1
	return obstacles

func _roll_modifiers(rng: RandomNumberGenerator, floor_number: int) -> Dictionary:
	var mods: Dictionary = {}
	if floor_number % FLOORS_PER_LANDMARK == 0:
		mods["landmark"] = true
		# Alternate landmark flavours deterministically-ish.
		mods["kind"] = ["boss", "vault", "rule_twist"][rng.randi_range(0, 2)]
	return mods
