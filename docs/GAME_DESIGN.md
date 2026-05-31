# Tower Defense — Game Design Document

> Working title: **ASCENT** (a maze tower-defense roguelike)
> Status: living document — v0.1
> Engine: Godot 4 · Target: iOS + Android (2D)

---

## 1. Pitch

You climb an endless **tower**. Each **floor** is a single tower-defense maze.
You don't follow a fixed path — you **build the maze yourself** by placing towers
that force enemies to wind through your gauntlet (the Hell TD / Element TD
lineage). Clear a floor, take the elevator up, and the next floor is harder,
stranger, and procedurally distinct. Between runs you return to a **town** you
develop, spending meta-currency on permanent upgrades, new tower archetypes, and
new tower wings to climb.

The "endless possibilities" come from **procedural runtime systems**, not from
hand-authored content: floors, enemy waves, and difficulty all generate and
adapt to how the player is doing. No live AI services, no GPU, no network calls —
just fast, deterministic-when-we-want-it algorithms that *feel* intelligent.

---

## 2. Core fantasy & loops

### Three nested loops
| Loop | Length | What the player does | What keeps them in it |
|------|--------|----------------------|------------------------|
| **Floor** | 1–3 min | Build a maze, survive the waves | Moment-to-moment optimization |
| **Run** | 15–40 min | Climb floors until you die or bank out | Escalating stakes, build-craft |
| **Meta** | weeks | Develop the town, unlock content | Permanent progression, mastery |

### The floor loop (the heart of the game)
1. Floor loads: an **open buildable area** with an **entrance** and an **exit**.
2. **Build phase**: player places towers. Towers double as **walls** — they
   reshape the only path enemies can take (pathfinding always finds the shortest
   open route). A tower placement that fully seals the exit is **illegal** and
   rejected.
3. **Wave phase**: enemies spawn at the entrance and pathfind toward the exit.
   Each enemy that reaches the exit costs a life.
4. Repeat build/wave for N waves. Survive all waves → **floor cleared**.
5. Choose an upgrade/reward, ride the elevator to the next floor.

### The "maze" is the skill expression
Because the player authors the path, depth comes from:
- **Path length** — long serpentine mazes = more time in the kill zone.
- **Choke points** — where to concentrate splash/slow.
- **Coverage geometry** — range towers want corners that see long straights.
- **Re-mazing** — selling/moving towers mid-run to re-route a new threat.

---

## 3. The Tower (meta structure)

The game world is a **very tall tower** divided into floors.

- **Floors 1–N** within a *wing* share a biome/theme and a tuning band.
- Every ~10 floors = a **landmark floor**: a boss, a rule-twist, or a vault.
- Climbing higher unlocks harder **wings** (new biomes, new enemy families).
- Death sends you back to the **town**; you keep meta-currency + unlocks, lose
  the run's temporary build.

This framing gives endless scaling **without authoring hundreds of levels** —
floor number is the master difficulty dial that drives every procedural system.

---

## 4. Procedural & adaptive systems (the "AI")

These are the systems that make the game feel alive. All are pure algorithms.

### 4.1 Floor Generator
Input: `floor_number`, `wing_id`, `seed`.
Output: a `FloorSpec` — buildable grid size, obstacle layout, entrance/exit
positions, starting gold/lives, wave count, modifiers.
- Uses a seeded RNG so a floor is reproducible (good for daily challenges /
  bug repro) but varied run-to-run.
- Higher floors: larger grids, pre-placed rock obstacles that constrain mazing,
  multiple entrances/exits, hazard tiles.

### 4.2 Wave Director (adaptive difficulty)
Input: `floor_number`, recent player performance (lives lost, leak rate, gold
banked, average clear time).
Output: each wave's enemy composition, count, spacing, and modifiers.
- Think of it as a **dynamic difficulty adjuster + encounter composer**.
- If the player is cruising → tighten the screws (faster, armored, swarms).
- If the player is bleeding lives → ease off slightly (the "rubber band"),
  within a floor-bounded range so it never trivializes the climb.
- Composes **counters**: lots of splash towers built? send fast singletons.
  Heavy single-target? send swarms. This is rule/heuristic-driven, cheap, and
  reads as a "smart" opponent.

### 4.3 Enemy archetype scaling
Stats scale by floor along curves (HP, speed, armor, bounty) plus typed
families (normal, fast, armored, swarm, flying, shielded, boss) that unlock by
wing. New families = the "new enemies the higher you go" pillar.

### 4.4 Reward/economy curve
Procedural reward offers after each floor (tower unlocks, stat boons, relics),
weighted by what the player lacks, to keep builds diverse.

---

## 5. Town meta (between runs)

A developable hub that turns one-off runs into long-term progression.
- **Buildings** unlock features: Forge (tower upgrades), Academy (new tower
  archetypes), Cartographer (choose starting wing/seed), Vault (meta-currency
  banking), Tavern (daily challenge & relics).
- Spend **meta-currency** earned per run (scales with floors climbed).
- Town development gates pacing and gives non-combat goals.

---

## 6. Towers (starting archetypes — v1 targets)

| Tower | Role | Notes |
|-------|------|-------|
| Arrow | Single-target DPS | Cheap baseline, long range |
| Cannon | Splash | Slow, area, anti-swarm |
| Frost | Slow/CC | Low damage, force-multiplier |
| Arcane | Anti-armor / true dmg | Counters shielded/armored |
| Support | Buff aura | Boosts adjacent towers |

All towers are **wall-blocking** (they occupy a grid cell and reshape the maze).
Upgrade paths branch (e.g., Arrow → Sniper or Multishot).

---

## 7. Asset strategy (deferred, but planned)

Per the chosen scope, **no live generative AI in the runtime**. When we add art:
- Build an **offline asset pipeline** (separate tools/scripts) to batch-generate
  candidate sprites/tiles/music, then **curate** the good ones and bake them in.
- Until then, the scaffold uses placeholder colored shapes so gameplay can be
  built and tuned independently of final art.

---

## 8. Technical architecture (Godot 4)

See `docs/ARCHITECTURE.md` for the code-level map. Summary:
- **Autoload singletons**: `EventBus` (signals), `GameState` (persistent meta +
  save), `RunManager` (current run/floor state).
- **Systems** (plain `RefCounted`/`Node` classes): `FloorGenerator`,
  `WaveDirector`, `MazeGrid` (AStarGrid2D wrapper + path-block validation).
- **Data** as Godot `Resource` types: `TowerData`, `EnemyData` — designer-tunable
  in the editor.
- **Scenes**: `Main` orchestrates a floor; gameplay actors (`Tower`, `Enemy`)
  are scenes spawned at runtime.

---

## 9. Roadmap

- [ ] **M0 — Scaffold** (this commit): project structure, autoloads, system
      stubs, design docs.
- [ ] **M1 — Playable floor slice**: grid build, maze pathfinding + block
      validation, one tower, one enemy, one wave, win/lose.
- [ ] **M2 — Run loop**: multiple floors, elevator, FloorGenerator driving
      variety, lives/gold economy.
- [ ] **M3 — Adaptive difficulty**: WaveDirector composing/counter-picking,
      enemy families, scaling curves.
- [ ] **M4 — Meta**: town hub, save/load, meta-currency, unlocks.
- [ ] **M5 — Content & feel**: more towers/enemies, relics, juice (SFX, FX).
- [ ] **M6 — Asset pipeline**: offline generation + curation, real art/music.
- [ ] **M7 — Mobile polish**: touch controls, performance, store builds.

---

## 10. Open questions

- Touch UX for placing/moving towers on small screens (drag-to-place vs tap).
- Monetization stance (premium? cosmetic? none?) — affects meta design.
- How aggressive should rubber-banding be before it feels patronizing?
- Daily-challenge / seeded-leaderboard scope.
