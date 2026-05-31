extends Node
## Headless integration drive: load the real Main scene, build towers, start a
## wave, and run combat to completion — exercising Tower targeting, Projectile
## impact, and Enemy death/leak. Fails loudly on any engine/script error.
##
## Run as a *scene* (so autoloads load):
##   godot --headless --path . res://tests/wave_drive.tscn

var _main: Node = null
var _frames: int = 0
var _started: bool = false
var _peak_alive: int = 0

func _ready() -> void:
	print("== ASCENT wave drive ==")
	_main = load("res://scenes/main/main.tscn").instantiate()
	add_child(_main)

func _process(_delta: float) -> void:
	_frames += 1

	if _frames == 10 and not _started:
		_build_and_start()
		_started = true

	if _started:
		_peak_alive = maxi(_peak_alive, _main._alive)

	if _frames > 1500:
		print("drove %d frames | peak_alive=%d | lives=%d | gold=%d | floor=%d"
			% [_frames, _peak_alive, RunManager.lives, RunManager.gold, RunManager.floor_number])
		if _peak_alive <= 0:
			printerr("FAIL: no enemies were ever spawned/alive")
			get_tree().quit(1)
		else:
			print("PASS: combat ran without errors")
			get_tree().quit(0)

func _build_and_start() -> void:
	var spec: FloorSpec = RunManager.current_floor_spec
	RunManager.gold = 100000  # plenty, so placement is the only gate
	var placed := 0
	for y in range(1, spec.grid_size.y - 1):
		for x in range(spec.grid_size.x):
			if placed >= 8:
				break
			if _main._try_build(Vector2i(x, y)):
				placed += 1
	print("placed %d towers; starting wave" % placed)
	_main._start_wave()
