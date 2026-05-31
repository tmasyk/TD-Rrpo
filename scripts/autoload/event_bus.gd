extends Node
## Global signal hub (autoload singleton "EventBus").
##
## Decoupled wiring only — NO game logic lives here. Systems emit signals and
## scenes/UI listen, so modules never need to hard-reference each other by path.

# --- Run / floor lifecycle ---
signal run_started
signal run_ended(victory: bool, floor_reached: int)
signal floor_started(floor_number: int)
signal floor_cleared(floor_number: int)

# --- Combat / wave lifecycle ---
signal build_phase_started(wave_index: int)
signal wave_phase_started(wave_index: int)
signal enemy_spawned(enemy: Node)
signal enemy_leaked(enemy: Node)   # reached the exit
signal enemy_killed(enemy: Node, bounty: int)

# --- Economy / status ---
signal gold_changed(amount: int)
signal lives_changed(current: int)

# --- Building ---
signal tower_placement_requested(cell: Vector2i, tower_id: StringName)
signal tower_placed(cell: Vector2i, tower_id: StringName)
signal tower_placement_rejected(cell: Vector2i, reason: String)
