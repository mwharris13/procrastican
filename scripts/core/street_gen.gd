class_name StreetGen
extends RefCounted
## Seeded, chunked street layout of helpers and hazards per zone.

const CHUNK_M := 30.0
const SAFE_START_M := 8.0

var street_seed := 0
var zones: Array
var objects: Dictionary
var helper_freq := 1.0
var _cache := {}


func _init(p_seed: int, p_zones: Array, p_objects: Dictionary, p_helper_freq: float) -> void:
	street_seed = p_seed
	zones = p_zones
	objects = p_objects
	helper_freq = p_helper_freq


func chunk(index: int) -> Array:
	if _cache.has(index):
		return _cache[index]
	var out: Array = []
	if index >= 0 and not zones.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([street_seed, index])
		var start := index * CHUNK_M
		# Midpoint, so a chunk straddling a zone boundary takes the zone covering most of it.
		var zone: Dictionary = zones[RunState.zone_index_at(zones, start + CHUNK_M * 0.5)]
		_place(out, rng, start, zone.helpers, _count(rng, float(zone.helpers_per_chunk) * helper_freq))
		_place(out, rng, start, zone.hazards, _count(rng, float(zone.hazards_per_chunk)))
		out.sort_custom(func(a, b): return a.x < b.x)
	_cache[index] = out
	return out


func _count(rng: RandomNumberGenerator, expected: float) -> int:
	var n := int(floorf(expected))
	return n + (1 if rng.randf() < expected - n else 0)


func _place(out: Array, rng: RandomNumberGenerator, start: float, ids: Array, n: int) -> void:
	for i in n:
		var x := start + rng.randf_range(2.0, CHUNK_M - 2.0)
		if x < SAFE_START_M or ids.is_empty():
			continue
		out.append({"id": ids[rng.randi_range(0, ids.size() - 1)], "x": x})


func objects_between(x0: float, x1: float) -> Array:
	var out: Array = []
	if x1 <= x0:
		return out
	for i in range(int(floorf(x0 / CHUNK_M)), int(floorf(x1 / CHUNK_M)) + 1):
		for o in chunk(i):
			if o.x > x0 and o.x <= x1:
				out.append(o)
	return out
