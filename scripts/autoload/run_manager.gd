extends Node
## Per-RUN state (autoload singleton "RunManager").
##
## Tracks the current climb: floor number, lives, gold, active FloorSpec.
## Everything here is reset when a new run starts. Long-term progression is in
## GameState. This object is the single source of truth the Main scene reads.

var is_active: bool = false
var floor_number: int = 0
var wing_id: StringName = &"foundation"
var run_seed: int = 0

var lives: int = 0
var gold: int = 0

var current_floor_spec: FloorSpec = null

# Systems used to drive the run. Created fresh per run.
var _floor_generator: FloorGenerator = null
var _wave_director: WaveDirector = null

func start_run(wing: StringName = &"foundation", seed_override: int = -1) -> void:
	is_active = true
	floor_number = 0
	wing_id = wing
	run_seed = seed_override if seed_override >= 0 else randi()
	lives = 20
	gold = 100
	_floor_generator = FloorGenerator.new()
	_wave_director = WaveDirector.new()
	EventBus.run_started.emit()
	EventBus.lives_changed.emit(lives)
	EventBus.gold_changed.emit(gold)
	advance_floor()

func advance_floor() -> void:
	floor_number += 1
	# Per-floor seed derived from run seed so each floor is reproducible.
	var floor_seed := hash(str(run_seed) + ":" + str(floor_number))
	current_floor_spec = _floor_generator.generate(floor_number, wing_id, floor_seed)
	EventBus.floor_started.emit(floor_number)

func clear_current_floor() -> void:
	EventBus.floor_cleared.emit(floor_number)

func compose_wave(wave_index: int, perf: Dictionary) -> WaveSpec:
	return _wave_director.compose_wave(floor_number, wave_index, perf)

# --- Economy ---

func add_gold(amount: int) -> void:
	gold += amount
	EventBus.gold_changed.emit(gold)

func try_spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	EventBus.gold_changed.emit(gold)
	return true

func lose_life(amount: int = 1) -> void:
	lives = max(0, lives - amount)
	EventBus.lives_changed.emit(lives)
	if lives <= 0:
		end_run(false)

# --- Lifecycle ---

func end_run(victory: bool) -> void:
	if not is_active:
		return
	is_active = false
	# Award meta-currency scaled by how high the player climbed.
	GameState.add_meta_currency(floor_number * 10)
	GameState.record_run_result(floor_number)
	EventBus.run_ended.emit(victory, floor_number)
