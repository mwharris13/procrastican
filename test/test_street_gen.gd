extends GutTest

var d: GameData

func before_each():
	d = GameData.load_all()

func test_chunks_are_deterministic_and_sorted():
	var a := StreetGen.new(5, d.zones, d.objects, 1.0)
	var b := StreetGen.new(5, d.zones, d.objects, 1.0)
	for i in 10:
		assert_eq(a.chunk(i), b.chunk(i))
		var xs := a.chunk(i).map(func(o): return o.x)
		var sorted := xs.duplicate()
		sorted.sort()
		assert_eq(xs, sorted)

func test_different_seed_differs():
	var a := StreetGen.new(1, d.zones, d.objects, 1.0)
	var b := StreetGen.new(2, d.zones, d.objects, 1.0)
	var same := true
	for i in 10:
		same = same and a.chunk(i) == b.chunk(i)
	assert_false(same)

func test_launch_area_is_clear_and_objects_match_zone():
	var g := StreetGen.new(3, d.zones, d.objects, 1.0)
	for o in g.objects_between(-1.0, StreetGen.SAFE_START_M):
		fail_test("object in launch area at %f" % o.x)
	for o in g.objects_between(400.0, 1199.0):
		var z: Dictionary = d.zones[1]
		assert_true(z.helpers.has(o.id) or z.hazards.has(o.id), o.id)

func test_helper_freq_increases_helpers():
	var lo := StreetGen.new(9, d.zones, d.objects, 1.0)
	var hi := StreetGen.new(9, d.zones, d.objects, 3.0)
	var count := func(g): return g.objects_between(0.0, 3000.0).filter(func(o): return d.objects[o.id].kind == "helper").size()
	assert_gt(count.call(hi), count.call(lo))

func test_objects_between_is_half_open():
	var g := StreetGen.new(4, d.zones, d.objects, 2.0)
	var all := g.objects_between(0.0, 300.0)
	assert_gt(all.size(), 0)
	var x: float = all[0].x
	assert_false(g.objects_between(x, x + 0.001).any(func(o): return o.x == x))
	assert_true(g.objects_between(x - 0.001, x).any(func(o): return o.x == x))
