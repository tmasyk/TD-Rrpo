class_name WaveDirector
extends RefCounted
## The adaptive-difficulty brain — the runtime "AI".
##
## Composes each wave's enemy mix from the floor number and the player's recent
## performance. It rubber-bands (bounded), and counter-picks against the player's
## tower build, so it reads as an intelligent opponent — all with cheap heuristics,
## no neural nets or network calls.
##
## `perf` snapshot shape (all optional, sane defaults applied):
##   {
##     "leak_rate": float,        # fraction of last wave that leaked (0..1)
##     "lives_fraction": float,   # current lives / starting lives (0..1)
##     "gold_banked": int,        # unspent gold (over-banking => crank pressure)
##     "splash_ratio": float,     # fraction of towers that are splash (0..1)
##     "single_ratio": float,     # fraction that are single-target (0..1)
##     "slow_ratio": float,       # fraction that are slow/CC (0..1)
##   }

## Enemy families unlock by depth so the climb keeps introducing threats.
const FAMILY_UNLOCK_FLOOR := {
	&"normal": 1,
	&"fast": 2,
	&"armored": 4,
	&"swarm": 6,
	&"flying": 9,
	&"shielded": 12,
	&"boss": 10,  # only spawned on landmark floors
}

func compose_wave(floor_number: int, wave_index: int, perf: Dictionary) -> WaveSpec:
	var spec := WaveSpec.new()

	# --- 1. Base budget grows with floor + wave. ---
	var base_budget := 40.0 + floor_number * 12.0 + wave_index * 8.0

	# --- 2. Bounded rubber-banding from performance. ---
	# Cruising (low leaks, high lives, hoarding gold) => push harder.
	# Bleeding out => ease off, but never below a floor-scaled minimum.
	var pressure := 1.0
	var leak_rate := float(perf.get("leak_rate", 0.0))
	var lives_fraction := float(perf.get("lives_fraction", 1.0))
	var gold_banked := int(perf.get("gold_banked", 0))

	if leak_rate < 0.05 and lives_fraction > 0.8:
		pressure += 0.20                      # they're cruising — tighten
	if gold_banked > 150:
		pressure += 0.10                      # hoarding — they can afford more
	if lives_fraction < 0.35:
		pressure -= 0.20                      # bleeding — ease up
	pressure = clampf(pressure, 0.8, 1.4)     # never trivial, never brutal

	var budget := base_budget * pressure

	# --- 3. Counter-pick against the player's build. ---
	# Heavy splash? favour fast singletons that splash struggles to focus.
	# Heavy single-target? favour swarms. Heavy slow? armored bruisers.
	var weights := _family_weights(floor_number)
	var splash_ratio := float(perf.get("splash_ratio", 0.0))
	var single_ratio := float(perf.get("single_ratio", 0.0))
	var slow_ratio := float(perf.get("slow_ratio", 0.0))
	if splash_ratio > 0.4:
		weights[&"fast"] = weights.get(&"fast", 0.0) + 1.5
	if single_ratio > 0.4:
		weights[&"swarm"] = weights.get(&"swarm", 0.0) + 1.5
	if slow_ratio > 0.4:
		weights[&"armored"] = weights.get(&"armored", 0.0) + 1.2

	# --- 4. Spend the budget across 1–3 families. ---
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(floor_number) + ":" + str(wave_index))

	var is_landmark_boss := floor_number % 10 == 0 and wave_index == 0
	if is_landmark_boss:
		spec.spawns.append(_make_entry(&"boss", 1, floor_number))
		spec.rationale = "Landmark boss wave."
		spec.spawn_interval = 0.0
		return spec

	var family_count := 1 + (rng.randi() % 3)  # 1..3
	var chosen := _weighted_pick_distinct(rng, weights, family_count)
	var per_family_budget := budget / float(max(1, chosen.size()))

	for fam in chosen:
		var unit_cost := _unit_cost(fam, floor_number)
		var count := max(1, int(per_family_budget / unit_cost))
		spec.spawns.append(_make_entry(fam, count, floor_number))

	spec.spawn_interval = clampf(0.7 - floor_number * 0.01, 0.25, 0.7)
	spec.rationale = "floor=%d wave=%d pressure=%.2f families=%s" % [
		floor_number, wave_index, pressure, str(chosen),
	]
	return spec

# --- Helpers ---

func _family_weights(floor_number: int) -> Dictionary:
	var w: Dictionary = {}
	for fam in FAMILY_UNLOCK_FLOOR.keys():
		if fam == &"boss":
			continue
		if floor_number >= int(FAMILY_UNLOCK_FLOOR[fam]):
			w[fam] = 1.0
	if w.is_empty():
		w[&"normal"] = 1.0
	return w

func _weighted_pick_distinct(rng: RandomNumberGenerator, weights: Dictionary, n: int) -> Array:
	var pool: Array = weights.keys()
	var result: Array = []
	var working := weights.duplicate()
	for _i in range(min(n, pool.size())):
		var total := 0.0
		for k in working.keys():
			total += float(working[k])
		if total <= 0.0:
			break
		var roll := rng.randf() * total
		var acc := 0.0
		for k in working.keys():
			acc += float(working[k])
			if roll <= acc:
				result.append(k)
				working.erase(k)
				break
	if result.is_empty():
		result.append(&"normal")
	return result

## Rough "point cost" of one enemy of a family at a given depth, used to convert
## the wave budget into counts. Tougher families cost more, so you get fewer.
func _unit_cost(family: StringName, floor_number: int) -> float:
	var base := {
		&"normal": 4.0,
		&"fast": 5.0,
		&"armored": 9.0,
		&"swarm": 2.0,
		&"flying": 7.0,
		&"shielded": 11.0,
		&"boss": 100.0,
	}
	return float(base.get(family, 4.0)) * (1.0 + floor_number * 0.05)

## Build a spawn entry with depth-scaled stats. Real values get refined against
## EnemyData resources in M3; these are the procedural baseline.
func _make_entry(family: StringName, count: int, floor_number: int) -> Dictionary:
	var hp_base := {
		&"normal": 20, &"fast": 14, &"armored": 45, &"swarm": 8,
		&"flying": 22, &"shielded": 35, &"boss": 600,
	}
	var speed_base := {
		&"normal": 1.0, &"fast": 1.8, &"armored": 0.7, &"swarm": 1.1,
		&"flying": 1.2, &"shielded": 0.9, &"boss": 0.6,
	}
	var armor_base := {
		&"normal": 0, &"fast": 0, &"armored": 4, &"swarm": 0,
		&"flying": 0, &"shielded": 2, &"boss": 6,
	}
	var flags: Array[StringName] = []
	if family == &"flying":
		flags.append(&"flying")
	if family == &"shielded":
		flags.append(&"shielded")
	var scale := 1.0 + floor_number * 0.18
	return {
		"family": family,
		"count": count,
		"hp": int(round(float(hp_base.get(family, 20)) * scale)),
		"speed": float(speed_base.get(family, 1.0)),
		"armor": int(armor_base.get(family, 0)) + floor_number / 6,
		"bounty": 2 + floor_number / 4,
		"flags": flags,
	}
