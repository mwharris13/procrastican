extends GutTest

var d: GameData
var stats: Dictionary

func before_each():
	d = GameData.load_all()
	stats = d.tuning.duplicate()

func test_zone_lookup():
	assert_eq(RunState.zone_index_at(d.zones, 0.0), 0)
	var downtown: float = d.zones[1].start_m
	assert_eq(RunState.zone_index_at(d.zones, downtown - 0.1), 0)
	assert_eq(RunState.zone_index_at(d.zones, downtown), 1)
	assert_eq(RunState.zone_index_at(d.zones, 5000.0), 2)

func test_combo_rules():
	var r := RunState.new(stats, d.zones)
	r.on_grade(TapJudge.Grade.PERFECT)
	r.on_grade(TapJudge.Grade.PERFECT)
	r.on_grade(TapJudge.Grade.GOOD)
	assert_eq(r.combo, 2)
	r.on_helper(2)
	assert_eq(r.combo, 4)
	r.on_grade(TapJudge.Grade.MISS)
	assert_eq(r.combo, 0)
	assert_eq(r.best_combo, 4)

func test_distance_accumulates_value_with_combo_and_zone():
	var r := RunState.new(stats, d.zones)
	r.on_distance(100.0)
	assert_almost_eq(r.value_meters, 100.0, 1e-6)
	r.combo = 5
	r.on_distance(200.0)
	assert_almost_eq(r.value_meters, 100.0 + 100.0 * (1.0 + 5 * stats.combo_step), 1e-6)
	assert_eq(r.on_distance(150.0), [])

func test_zone_event_and_ten_x_value():
	var r := RunState.new(stats, d.zones)
	var ev := r.on_distance(401.0)
	assert_true(ev.any(func(e): return e.type == "zone" and e.index == 1))
	var before := r.value_meters
	r.on_distance(411.0)
	assert_almost_eq(r.value_meters - before, 10.0 * 10.0, 1e-6)

func test_perk_checkpoints_space_out():
	var r := RunState.new(stats, d.zones)
	assert_eq(r.on_distance(249.0).filter(func(e): return e.type == "perk_due").size(), 0)
	assert_eq(r.on_distance(251.0).filter(func(e): return e.type == "perk_due").size(), 1)
	assert_almost_eq(r.next_perk_at, 250.0 + 250.0 * 1.6, 1e-6)

func test_coins_use_formula():
	var r := RunState.new(stats, d.zones)
	r.on_distance(300.0)
	assert_eq(r.coins(), Economy.run_coins(r.value_meters, stats.coin_per_meter, stats.coin_mult))

func test_perfects_count_only_perfect_grades():
	var r := RunState.new(stats, d.zones)
	r.on_grade(TapJudge.Grade.PERFECT)
	r.on_grade(TapJudge.Grade.GOOD)
	r.on_grade(TapJudge.Grade.MISS)
	r.on_grade(TapJudge.Grade.PERFECT)
	assert_eq(r.perfects, 2)
