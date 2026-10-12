extends GutTest

var d: GameData

func before_each():
	d = GameData.load_all()

func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

func test_same_seed_same_draw():
	var a := PerkDeck.draw(d.perks, _rng(7), 3, [], 1.0)
	var b := PerkDeck.draw(d.perks, _rng(7), 3, [], 1.0)
	assert_eq(a.map(func(p): return p.id), b.map(func(p): return p.id))

func test_no_duplicates_and_exclude_respected():
	for s in 50:
		var picks := PerkDeck.draw(d.perks, _rng(s), 3, ["super_kick"], 1.0)
		var ids := picks.map(func(p): return p.id)
		assert_eq(ids.size(), 3)
		assert_false(ids.has("super_kick"))
		for id in ids:
			assert_eq(ids.count(id), 1)

func test_count_larger_than_pool():
	assert_eq(PerkDeck.draw(d.perks.slice(0, 2), _rng(1), 3, [], 1.0).size(), 2)

func test_rare_mult_raises_rare_share():
	var rng := _rng(42)
	var base := 0
	var boosted := 0
	for i in 3000:
		if PerkDeck.draw(d.perks, rng, 1, [], 1.0)[0].rarity != "common":
			base += 1
		if PerkDeck.draw(d.perks, rng, 1, [], 4.0)[0].rarity != "common":
			boosted += 1
	assert_gt(boosted, base * 1.5)

func test_modifier_draw_weighted_and_deterministic():
	var counts := {}
	var rng := _rng(3)
	for i in 4000:
		var m := ModifierDeck.draw(d.modifiers, rng)
		counts[m.id] = counts.get(m.id, 0) + 1
	assert_gt(counts.nice_day, counts.windy)
	assert_eq(ModifierDeck.draw(d.modifiers, _rng(9)).id, ModifierDeck.draw(d.modifiers, _rng(9)).id)
	assert_eq(ModifierDeck.draw([], _rng(1)), {})
