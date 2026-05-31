extends SceneTree
## Headless logic smoke test for the procedural systems.
## Run:  godot --headless --script res://tests/logic_smoke.gd
## Exits non-zero if any assertion fails, so it can gate CI.

var _failures: int = 0

func _initialize() -> void:
	print("== ASCENT logic smoke test ==")
	_test_floor_generator()
	_test_maze_seal_rejection()
	_test_wave_director()
	_test_wave_expansion()

	if _failures == 0:
		print("ALL PASS")
		quit(0)
	else:
		printerr("FAILURES: %d" % _failures)
		quit(1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("  FAIL: ", msg)

func _test_floor_generator() -> void:
	print("- FloorGenerator")
	var gen := FloorGenerator.new()
	for floor_number in [1, 5, 10, 25, 50, 100]:
		var spec := gen.generate(floor_number, &"foundation", hash("seed:%d" % floor_number))
		_check(spec.grid_size.x >= 9 and spec.grid_size.y >= 14, "grid sane @%d" % floor_number)
		_check(not spec.entrances.is_empty(), "has entrance @%d" % floor_number)
		_check(not spec.exits.is_empty(), "has exit @%d" % floor_number)
		_check(spec.wave_count >= 6, "wave_count >=6 @%d" % floor_number)
		# An empty maze must always have a route entrance -> exit.
		var grid := MazeGrid.new(spec.grid_size, spec.entrances, spec.exits)
		for c in spec.obstacle_cells:
			grid.add_obstacle(c)
		var path := grid.get_path(spec.entrances[0], spec.exits[0])
		_check(path.size() >= 2, "obstacle layout leaves a path @%d" % floor_number)

	# Determinism: same inputs -> same output.
	var a := gen.generate(7, &"foundation", 12345)
	var b := gen.generate(7, &"foundation", 12345)
	_check(a.obstacle_cells == b.obstacle_cells, "generation is deterministic")

func _test_maze_seal_rejection() -> void:
	print("- MazeGrid seal rejection")
	# A 1-wide corridor: blocking the only cell between entrance and exit must fail.
	var grid := MazeGrid.new(Vector2i(1, 3), [Vector2i(0, 0)], [Vector2i(0, 2)])
	_check(not grid.can_place(Vector2i(0, 1)), "rejects placement that seals the only path")
	# A wider grid: a single tower should be placeable.
	var wide := MazeGrid.new(Vector2i(5, 5), [Vector2i(2, 0)], [Vector2i(2, 4)])
	_check(wide.can_place(Vector2i(1, 2)), "allows placement that leaves a route")
	_check(wide.place_tower(Vector2i(1, 2)), "commits a legal placement")
	_check(not wide.can_place(Vector2i(2, 0)), "rejects building on the entrance")

func _test_wave_director() -> void:
	print("- WaveDirector")
	var director := WaveDirector.new()
	# Cruising player should face >= pressure than a struggling one, same floor/wave.
	var cruising := {"leak_rate": 0.0, "lives_fraction": 1.0, "gold_banked": 300}
	var bleeding := {"leak_rate": 0.5, "lives_fraction": 0.2, "gold_banked": 0}
	for floor_number in [1, 3, 8, 15, 30]:
		var w := director.compose_wave(floor_number, 1, cruising)
		_check(w.total_enemies() > 0, "wave has enemies @%d" % floor_number)
		_check(w.spawn_interval > 0.0, "spawn interval positive @%d" % floor_number)
	var hard := director.compose_wave(10, 2, cruising)
	var easy := director.compose_wave(10, 2, bleeding)
	_check(hard.total_enemies() >= easy.total_enemies(),
		"cruising player faces >= enemies than a struggling one")
	# Landmark boss wave on floor 10, wave 0.
	var boss := director.compose_wave(10, 0, cruising)
	_check(boss.total_enemies() == 1, "floor-10 wave-0 is a single boss")

func _test_wave_expansion() -> void:
	print("- wave expansion (round-robin interleave)")
	# Mirror the controller's expansion to ensure counts are preserved.
	var spawns := [
		{"family": &"normal", "count": 3},
		{"family": &"fast", "count": 2},
	]
	var lanes: Array = []
	for entry in spawns:
		var lane: Array = []
		for _i in range(int(entry["count"])):
			lane.append(entry["family"])
		lanes.append(lane)
	var queue: Array = []
	var added := true
	while added:
		added = false
		for lane in lanes:
			if not lane.is_empty():
				queue.append(lane.pop_front())
				added = true
	_check(queue.size() == 5, "expansion preserves total count")
	_check(queue[0] == &"normal" and queue[1] == &"fast", "families interleave")
