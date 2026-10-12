class_name ModifierDeck
extends RefCounted
## Picks one street modifier per run, weighted.


static func draw(mods: Array, rng: RandomNumberGenerator) -> Dictionary:
	if mods.is_empty():
		return {}
	var total := 0.0
	for m in mods:
		total += float(m.weight)
	var r := rng.randf() * total
	for m in mods:
		r -= float(m.weight)
		if r < 0.0:
			return m
	return mods[-1]
