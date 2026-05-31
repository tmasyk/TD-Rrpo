extends Node
## Persistent META state (autoload singleton "GameState").
##
## Owns everything that survives across runs: town buildings, unlocks,
## meta-currency, settings. Handles save/load to user://savegame.json.
## The per-run, throwaway state lives in RunManager instead.

const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 1

## Default meta profile for a brand-new player.
var meta: Dictionary = _default_meta()

func _default_meta() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"meta_currency": 0,
		"highest_floor": 0,
		"runs_completed": 0,
		# Town buildings -> level (0 = not built yet).
		"buildings": {
			"forge": 0,
			"academy": 0,
			"cartographer": 0,
			"vault": 0,
			"tavern": 0,
		},
		# Unlocked tower archetype ids.
		"unlocked_towers": ["arrow", "cannon"],
		# Unlocked wings (biomes) the player may start in.
		"unlocked_wings": ["foundation"],
		"settings": {
			"music_volume": 0.8,
			"sfx_volume": 0.9,
		},
	}

func _ready() -> void:
	load_game()

# --- Meta mutation helpers ---

func add_meta_currency(amount: int) -> void:
	meta.meta_currency += amount
	save_game()

func record_run_result(floor_reached: int) -> void:
	meta.runs_completed += 1
	if floor_reached > int(meta.highest_floor):
		meta.highest_floor = floor_reached
	save_game()

func is_tower_unlocked(tower_id: StringName) -> bool:
	return String(tower_id) in meta.unlocked_towers

# --- Persistence ---

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("GameState: could not open save file for writing.")
		return
	f.store_string(JSON.stringify(meta, "\t"))
	f.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		meta = _default_meta()
		save_game()
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_warning("GameState: could not open save file for reading.")
		return
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("GameState: save file corrupt — resetting to defaults.")
		meta = _default_meta()
		save_game()
		return
	meta = _migrate(parsed)

## Forward-compatible migration hook for older save versions.
func _migrate(data: Dictionary) -> Dictionary:
	# Backfill any keys added in newer versions onto older saves.
	var base := _default_meta()
	base.merge(data, true)
	base.version = SAVE_VERSION
	return base
