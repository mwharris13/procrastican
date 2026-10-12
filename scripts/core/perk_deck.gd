class_name PerkDeck
extends RefCounted
## Weighted perk offers without replacement; luck boosts rare and epic weights.

const RARITY_WEIGHT := {"common": 10.0, "rare": 3.0, "epic": 1.0}


static func weight(perk: Dictionary, rare_mult: float) -> float:
	var w: float = RARITY_WEIGHT.get(perk.rarity, 1.0)
	return w if perk.rarity == "common" else w * rare_mult


static func draw(perks: Array, rng: RandomNumberGenerator, count: int, exclude: Array, rare_mult: float) -> Array:
	var pool := perks.filter(func(p): return not exclude.has(p.id))
	var out: Array = []
	while out.size() < count and not pool.is_empty():
		var total := 0.0
		for p in pool:
			total += weight(p, rare_mult)
		var r := rng.randf() * total
		var pick: Dictionary = pool[-1]
		for p in pool:
			r -= weight(p, rare_mult)
			if r < 0.0:
				pick = p
				break
		out.append(pick)
		pool.erase(pick)
	return out
