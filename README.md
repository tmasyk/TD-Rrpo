# ASCENT

A maze tower-defense roguelike for mobile, built in **Godot 4**. You climb an
endless tower — each floor is a TD maze you **build yourself** by placing towers
that force enemies to wind through your gauntlet. Procedural runtime systems
(not live AI services) generate floors and adapt difficulty, so the climb is
endlessly varied.

> Status: **M0 — scaffold**. The architecture, procedural systems, and a visible
> smoke-test scene exist; the playable gameplay slice lands in M1.

## Design

- [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md) — full vision, loops, the tower
  meta, towers/enemies, and the roadmap.
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — code-level map.

## Project layout

```
project.godot              Godot 4 project (open this folder in the editor)
icon.svg
scenes/main/               Main scene — orchestrates a floor (scaffold demo)
scripts/autoload/          Singletons: EventBus, GameState, RunManager
scripts/systems/           Procedural "AI": FloorGenerator, WaveDirector, MazeGrid
scripts/data/              Editor-tunable Resources: TowerData, EnemyData
docs/                      Design + architecture
```

## Running it

You need the **Godot 4.3+** editor (this repo contains no engine binary):

1. Install Godot 4 from <https://godotengine.org/download> (or your package
   manager / Steam).
2. Open Godot → **Import** → select this folder's `project.godot`.
3. Press **F5** (Play). The scaffold scene draws the procedurally generated
   floor: obstacles, entrance (green), exit (red), the current shortest enemy
   path (yellow), and lets you click to place test towers — the maze rule
   rejects any placement that would fully seal the path.

Controls in the scaffold: **Left click** place/remove a test tower · **N** next
floor · **R** restart run. Watch the **Output** panel for the generated
`FloorSpec` and a sample `WaveDirector` composition.

## Verifying headless (no GUI needed)

The procedural systems and the full combat loop can be checked without opening
the editor — useful for CI and for environments without a display:

```bash
# Compile every script + import resources (surfaces parse errors):
godot --headless --path . --import

# Logic smoke test: floor generation, maze-seal rejection, wave composition:
godot --headless --path . --script tests/logic_smoke.gd

# Integration drive: loads the real scene, builds towers, runs a full wave:
godot --headless --path . res://tests/wave_drive.tscn
```

Each exits non-zero on failure.

## What's next (see the roadmap in the design doc)

M1 playable slice → M2 run loop → M3 adaptive difficulty → M4 town meta →
M5 content/feel → M6 offline asset pipeline → M7 mobile polish.
