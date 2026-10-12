extends GutTest

const STEP := 1.0 / 240.0
var stats: Dictionary

func before_each():
	stats = GameData.load_all().tuning.duplicate()
	stats.air_drag = 0.0

func _sim() -> RunSim:
	var s := RunSim.new(stats)
	s.launch(45.0, 1.0)
	return s

## Advances in small steps until ttd <= seconds; returns events seen.
func _until_ttd(s: RunSim, seconds: float) -> Array:
	var out: Array = []
	for i in 20000:
		if s.can.time_to_touchdown() <= seconds:
			break
		out.append_array(s.advance(STEP))
	return out

func _until_type(s: RunSim, type: String) -> Array:
	var out: Array = []
	for i in 40000:
		var ev := s.advance(STEP)
		out.append_array(ev)
		for e in ev:
			if e.type == type:
				return out
	return out

func _graded(events: Array) -> Array:
	return events.filter(func(e): return e.type == "graded")

func test_buffered_early_tap_grades_perfect_at_touchdown():
	var s := _sim()
	_until_ttd(s, 0.03)
	assert_eq(s.tap(s.can_center()).get("type"), "tap_buffered")
	var ev := _until_type(s, "graded")
	var g := _graded(ev)
	assert_eq(g.size(), 1)
	assert_eq(g[0].grade, TapJudge.Grade.PERFECT)
	assert_gt(s.can.vel.y, 0.0)
	assert_eq(s.perfect_count, 1)

func test_buffered_tap_at_100ms_grades_good():
	var s := _sim()
	_until_ttd(s, 0.10)
	s.tap(s.can_center())
	var g := _graded(_until_type(s, "graded"))
	assert_eq(g[0].grade, TapJudge.Grade.GOOD)

func test_late_tap_after_touchdown_grades_by_delay():
	var s := _sim()
	_until_type(s, "touchdown")
	s.advance(0.03)
	var r := s.tap(s.can_center())
	assert_eq(r.get("type"), "graded")
	assert_eq(r.grade, TapJudge.Grade.PERFECT)
	var s2 := _sim()
	_until_type(s2, "touchdown")
	s2.advance(0.09)
	assert_eq(s2.tap(s2.can_center()).grade, TapJudge.Grade.GOOD)

func test_no_tap_gives_miss_after_late_window():
	var s := _sim()
	_until_type(s, "touchdown")
	var ev := s.advance(stats.good_window + 0.01)
	var g := _graded(ev)
	assert_eq(g.size(), 1)
	assert_eq(g[0].grade, TapJudge.Grade.MISS)

func test_tap_out_of_reach_is_ignored():
	var s := _sim()
	_until_ttd(s, 0.03)
	assert_eq(s.tap(s.can_center() + Vector2(stats.tap_reach_m + 0.5, 0)), {})

func test_too_early_tap_is_ignored_then_window_tap_counts():
	var s := _sim()
	_until_ttd(s, 0.5)
	assert_eq(s.tap(s.can_center()), {})
	_until_ttd(s, 0.03)
	assert_eq(s.tap(s.can_center()).get("type"), "tap_buffered")
	assert_eq(_graded(_until_type(s, "graded"))[0].grade, TapJudge.Grade.PERFECT)

func test_second_tap_in_window_is_ignored():
	var s := _sim()
	_until_ttd(s, 0.05)
	s.tap(s.can_center())
	assert_eq(s.tap(s.can_center()), {})
	var g := _graded(_until_type(s, "graded"))
	assert_eq(g.size(), 1)

func test_long_hitch_keeps_event_order():
	var s := _sim()
	_until_ttd(s, 0.03)
	s.tap(s.can_center())
	var ev := s.advance(0.5)
	var types := ev.map(func(e): return e.type)
	assert_eq(types[0], "touchdown")
	assert_eq(types[1], "graded")
	assert_eq(ev[1].grade, TapJudge.Grade.PERFECT)
	assert_gte(s.can.pos.y, 0.0)

func test_run_ends_at_rest_without_taps():
	var s := _sim()
	var ev := _until_type(s, "run_end")
	assert_true(s.ended)
	assert_eq(ev[-1].reason, "rest")
	assert_eq(s.advance(1.0), [])

func test_rest_waits_for_open_late_window():
	var s := _sim()
	s.can.launch(5.0, 0.05)
	var ev := _until_type(s, "run_end")
	var types := ev.map(func(e): return e.type)
	assert_gte(types.find("graded"), 0)
	assert_true(types.find("graded") < types.find("run_end"))

func test_air_kick_spends_charge_when_far_from_ground():
	stats.air_kicks = 1.0
	var s := _sim()
	s.advance(0.2)
	var vx := s.can.vel.x
	assert_eq(s.tap(s.can_center()).get("type"), "air_kick")
	assert_gt(s.can.vel.x, vx)
	assert_eq(s.tap(s.can_center()), {})

func test_super_kick_every_nth_perfect():
	stats.super_kick_every = 1.0
	var s := _sim()
	_until_ttd(s, 0.02)
	s.tap(s.can_center())
	var g := _graded(_until_type(s, "graded"))
	assert_true(g[0].super)

func test_watchdog_ends_endless_roll():
	stats.ground_friction = 0.0
	stats.max_run_time = 3.0
	var s := _sim()
	var ev := _until_type(s, "run_end")
	assert_eq(ev[-1].reason, "watchdog")

func test_long_advance_emits_miss_before_next_touchdown():
	var s := _sim()
	_until_type(s, "touchdown")
	var ev := s.advance(1.0)
	var types := ev.map(func(e): return e.type)
	var td := types.find("touchdown")
	assert_gte(td, 1, "a second touchdown occurs in the long advance")
	assert_eq(types[0], "graded")
	assert_eq(ev[0].grade, TapJudge.Grade.MISS)
	assert_eq(_graded(ev.slice(0, td)).size(), 1)

class FakeStreet:
	var objects := {}
	var placed: Array = []
	func objects_between(x0: float, x1: float) -> Array:
		return placed.filter(func(o): return o.x > x0 and o.x <= x1)

func _street(id: String, def: Dictionary, x: float) -> FakeStreet:
	var f := FakeStreet.new()
	f.objects[id] = def
	f.placed = [{"id": id, "x": x}]
	return f

func test_low_can_hits_helper_and_bounces():
	var s := RunSim.new(stats)
	s.street = _street("trash_can", {"kind": "helper", "height": 50.0, "bounce_vy": 9.0, "speed_mult": 1.2, "combo": 1}, 3.0)
	s.launch(20.0, 1.0)
	var ev := _until_type(s, "helper")
	assert_eq(ev[-1].id, "trash_can")
	assert_eq(ev[-1].combo, 1)
	assert_gte(s.can.vel.y, 9.0)

func test_high_can_flies_over_helper():
	var s := RunSim.new(stats)
	s.street = _street("dog", {"kind": "helper", "height": 0.01, "bounce_vy": 9.0, "speed_mult": 1.2, "combo": 1}, 6.0)
	s.launch(60.0, 1.0)
	var ev := s.advance(0.6)
	assert_false(ev.any(func(e): return e.type == "helper"))

func test_touchdown_in_puddle_slows_can():
	var s := RunSim.new(stats)
	s.launch(45.0, 1.0)
	var c := CanPhysics.new(stats)
	c.launch(45.0, 1.0)
	var land := {}
	for i in 2000:
		var e: Array = []
		c.step(1.0 / 240.0, e)
		if not e.is_empty():
			land = e[0]
			break
	s.street = _street("puddle", {"kind": "hazard", "width": 4.0, "speed_keep": 0.5}, land.x - 2.0)
	var ev := _until_type(s, "hazard").filter(func(e): return e.type == "hazard")
	assert_eq(ev[-1].id, "puddle")
	assert_false(ev[-1].trampoline)
	assert_almost_eq(s.can.last_impact_vel.x, c.last_impact_vel.x * 0.5, 0.2)

func test_trampoline_puddle_bounces_up():
	stats.puddle_trampoline = 1.0
	var s := RunSim.new(stats)
	s.launch(10.0, 0.3)
	s.street = _street("puddle", {"kind": "hazard", "width": 50.0, "speed_keep": 0.5}, 0.0)
	var ev := _until_type(s, "hazard").filter(func(e): return e.type == "hazard")
	assert_true(ev[-1].trampoline)
	assert_gt(s.can.vel.y, 0.0)

func _rolling_sim() -> RunSim:
	var s := RunSim.new(stats)
	s.launch(45.0, 1.0)
	s.can.rolling = true
	s.can.vel = Vector2(20.0, 0.0)
	s.can.pos = Vector2.ZERO
	s.street = _street("storm_drain", {"kind": "hazard", "width": 0.5, "speed_keep": 0.5}, 3.0)
	return s

func test_rolling_can_catches_narrow_hazard_in_one_big_step():
	var s := _rolling_sim()
	var ev := s.advance(0.5)
	var hz := ev.filter(func(e): return e.type == "hazard")
	assert_eq(hz.size(), 1)
	assert_lt(s.can.vel.x, 12.0)

func test_rolling_can_catches_narrow_hazard_in_small_steps():
	var s := _rolling_sim()
	var hz := _until_type(s, "hazard").filter(func(e): return e.type == "hazard")
	assert_eq(hz.size(), 1)

func test_super_kick_all_perfect_chain_still_comes_to_rest():
	stats.super_kick_every = 5.0
	var s := _sim()
	var reason := ""
	for i in int(120.0 / STEP):
		if s.ended:
			break
		if s.can.time_to_touchdown() <= 0.02:
			s.tap(s.can_center())
		for ev in s.advance(STEP):
			if ev.type == "run_end":
				reason = ev.reason
	assert_eq(reason, "rest")
