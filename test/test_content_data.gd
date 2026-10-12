extends GutTest

var d: GameData

func before_each():
	d = GameData.load_all()

func _all_effects() -> Array:
	var out: Array = []
	for list in [d.upgrades, d.cans, d.perks, d.modifiers]:
		for item in list:
			out.append_array(item.effects)
	return out

func test_lists_loaded():
	assert_eq(d.upgrades.size(), 9)
	assert_eq(d.cans.size(), 3)
	assert_eq(d.perks.size(), 8)
	assert_eq(d.modifiers.size(), 5)
	assert_eq(d.zones.size(), 3)
	assert_eq(d.objects.size(), 11)

func test_every_effect_targets_a_real_stat():
	for e in _all_effects():
		assert_true(GameData.REQUIRED_STATS.has(e.stat), e.stat)
		assert_true(e.op in ["add", "mul"], e.op)

func test_ids_unique():
	for list in [d.upgrades, d.cans, d.perks, d.modifiers, d.zones]:
		var ids: Array = list.map(func(x): return x.id)
		for id in ids:
			assert_eq(ids.count(id), 1, id)

func test_upgrades_well_formed():
	for u in d.upgrades:
		assert_true(u.track in ["gear", "skills", "luck"], u.id)
		assert_gt(float(u.base_cost), 0.0)
		assert_gt(float(u.cost_growth), 1.0)
		assert_gt(int(u.max_level), 0)

func test_zones_sorted_and_reference_real_objects():
	assert_eq(float(d.zones[0].start_m), 0.0)
	var keys := RunView.default_palette().keys()
	for i in d.zones.size():
		var z: Dictionary = d.zones[i]
		if i > 0:
			assert_gt(float(z.start_m), float(d.zones[i - 1].start_m))
		for k in keys:
			assert_true(z.palette.has(k), z.id + " palette " + k)
		for h in z.helpers:
			assert_eq(d.objects[h].kind, "helper", h)
		for h in z.hazards:
			assert_eq(d.objects[h].kind, "hazard", h)

func test_friction_always_beats_tailwind():
	var all_perks: Array = []
	for p in d.perks:
		all_perks.append_array(p.effects)
	for m in d.modifiers:
		for c in d.cans:
			var s := StatResolver.resolve(d.tuning, m.effects + c.effects + all_perks)
			assert_gt(s.ground_friction, s.tailwind, "%s + %s" % [m.id, c.id])

func test_lookups():
	assert_eq(d.upgrade("reach").name, "Reach")
	assert_eq(d.can("soda").cost, 0.0)
	assert_eq(d.upgrade("nope"), {})
