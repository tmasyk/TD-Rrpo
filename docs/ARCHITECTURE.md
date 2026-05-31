# Architecture (Godot 4)

A code-level map of the scaffold. Keep this in sync as systems land.

## Layering

```
                 ┌─────────────────────────────────────┐
   Autoloads     │  EventBus   GameState   RunManager   │  (singletons)
                 └───────┬──────────┬───────────┬───────┘
                         │ signals  │ persists  │ run state
                 ┌───────┴──────────┴───────────┴───────┐
   Systems       │ FloorGenerator  WaveDirector  MazeGrid│  (pure logic)
                 └───────┬──────────────────────┬────────┘
                         │ FloorSpec / WaveSpec  │ pathfinding
                 ┌───────┴──────────────────────┴────────┐
   Scenes        │   Main → spawns Tower / Enemy actors   │
                 └────────────────────────────────────────┘
   Data          TowerData, EnemyData  (Resource — editor-tunable)
```

## Autoloads (registered in `project.godot`)

- **`EventBus`** (`scripts/autoload/event_bus.gd`)
  Decoupled signal hub. Systems emit, scenes listen. No game logic lives here —
  it's only the wiring so modules don't hard-reference each other.

- **`GameState`** (`scripts/autoload/game_state.gd`)
  Persistent **meta** layer: town buildings, unlocks, meta-currency, settings.
  Owns save/load to `user://savegame.json`. Survives across runs.

- **`RunManager`** (`scripts/autoload/run_manager.gd`)
  The **current run**: floor number, lives, gold, current `FloorSpec`. Drives
  start_run / advance_floor / end_run. Reset every run.

## Systems (`scripts/systems/`)

- **`FloorGenerator`** — `generate(floor_number, wing_id, seed) -> FloorSpec`.
  Seeded, deterministic per (floor, seed). Produces grid + obstacles +
  entrance/exit + economy + wave count + modifiers.

- **`WaveDirector`** — `compose_wave(floor_number, wave_index, perf) -> WaveSpec`.
  The adaptive-difficulty brain. Reads `PerformanceTracker` snapshot, picks enemy
  families/counts/spacing, applies bounded rubber-banding + counter-picking.

- **`MazeGrid`** — wraps `AStarGrid2D`. Tracks blocked cells (towers/obstacles),
  exposes `can_place(cell)` which rejects placements that would fully seal the
  path from any entrance to any exit, and `get_path(from, to)`.

## Data (`scripts/data/`)

Godot `Resource` subclasses so designers can author `.tres` files in-editor:
- **`TowerData`** — cost, damage, range, fire_rate, splash, slow, upgrade refs.
- **`EnemyData`** — hp, speed, armor, family, bounty, flags (flying/shield).

## Scenes (`scenes/`)

- **`main/main.tscn`** (+ `main.gd`) — orchestrates a single floor: asks
  `FloorGenerator` for a spec, builds the `MazeGrid`, runs build/wave phases,
  reports results to `RunManager`. The scaffold version renders a placeholder
  grid and logs the generated spec so the pipeline is observable before art.

Gameplay actors (`Tower`, `Enemy`) will be added in M1 as spawned scenes.

## Conventions

- GDScript, `class_name` on reusable types, typed vars/params where practical.
- Cross-module communication via `EventBus` signals, not direct node paths.
- Pure logic (generators/director/grid) avoids touching the scene tree so it's
  unit-testable headless.
- Seeded RNG everywhere procedural, so runs are reproducible for debugging.
