class_name MazeGrid
extends RefCounted
## Wraps AStarGrid2D for the maze. Tracks blocked cells (towers + obstacles) and
## — crucially — enforces the maze rule: a placement that fully seals every
## entrance→exit route is illegal and rejected.
##
## Pure logic, no scene tree access, so it can be unit-tested headless.

var size: Vector2i
var entrances: Array[Vector2i] = []
var exits: Array[Vector2i] = []

var _astar: AStarGrid2D
var _blocked: Dictionary = {}  # Vector2i -> true

func _init(grid_size: Vector2i, entrance_cells: Array[Vector2i], exit_cells: Array[Vector2i]) -> void:
	size = grid_size
	entrances = entrance_cells.duplicate()
	exits = exit_cells.duplicate()
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(Vector2i.ZERO, size)
	# 4-directional movement: enemies turn at right angles, classic TD feel.
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.update()

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y

func is_blocked(cell: Vector2i) -> bool:
	return _blocked.has(cell)

## Permanently block a cell (used for pre-placed obstacles at floor setup).
func add_obstacle(cell: Vector2i) -> void:
	if not in_bounds(cell):
		return
	_blocked[cell] = true
	_astar.set_point_solid(cell, true)

## Can the player place a tower here? Rejects out-of-bounds, occupied,
## entrance/exit cells, and — the important one — placements that would leave
## any entrance with no path to any exit.
func can_place(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return false
	if is_blocked(cell):
		return false
	if cell in entrances or cell in exits:
		return false
	# Tentatively block, test connectivity, then revert.
	_astar.set_point_solid(cell, true)
	var ok := _all_routes_open()
	_astar.set_point_solid(cell, false)
	return ok

## Commit a tower placement. Returns false (and changes nothing) if illegal.
func place_tower(cell: Vector2i) -> bool:
	if not can_place(cell):
		return false
	_blocked[cell] = true
	_astar.set_point_solid(cell, true)
	return true

func remove_tower(cell: Vector2i) -> void:
	if _blocked.has(cell):
		_blocked.erase(cell)
		_astar.set_point_solid(cell, false)

## All currently blocked cells (obstacles + towers).
func get_blocked_cells() -> Array:
	return _blocked.keys()

## Shortest path between two cells, or empty if none.
func get_path(from: Vector2i, to: Vector2i) -> PackedVector2Array:
	if not in_bounds(from) or not in_bounds(to):
		return PackedVector2Array()
	return _astar.get_point_path(from, to)

## Every entrance must still reach at least one exit.
func _all_routes_open() -> bool:
	for entrance in entrances:
		var reached_any := false
		for exit in exits:
			var path := _astar.get_id_path(entrance, exit)
			if path.size() > 0:
				reached_any = true
				break
		if not reached_any:
			return false
	return true
