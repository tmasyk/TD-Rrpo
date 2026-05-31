class_name WaveSpec
extends RefCounted
## One wave's worth of enemies, produced by WaveDirector. Pure data.

## Ordered list of spawn entries. Each entry:
##   { "family": StringName, "count": int, "hp": int, "speed": float,
##     "armor": int, "bounty": int, "flags": Array[StringName] }
var spawns: Array[Dictionary] = []
## Seconds between individual enemy spawns.
var spawn_interval: float = 0.6
## Human-readable note about why the director composed it this way (debug/telemetry).
var rationale: String = ""

func total_enemies() -> int:
	var n := 0
	for entry in spawns:
		n += int(entry.get("count", 0))
	return n

func _to_string() -> String:
	return "WaveSpec(total=%d entries=%d interval=%.2f :: %s)" % [
		total_enemies(), spawns.size(), spawn_interval, rationale,
	]
