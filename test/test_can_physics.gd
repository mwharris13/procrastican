extends GutTest

var stats: Dictionary

func before_each():
	stats = GameData.load_all().tuning.duplicate()

func _fly_to_touchdown(c: CanPhysics) -> Dictionary:
	for i in 2000:
		var ev: Array = []
		c.step(1.0 / 60.0, ev)
		for e in ev:
			if e.type == "touchdown":
				return e
	return {}

func test_launch_sets_velocity_from_angle_and_power():
	var c := CanPhysics.new(stats)
	c.launch(45.0, 0.5)
	assert_almost_eq(c.vel.length(), stats.launch_speed_max * 0.5, 0.001)
	assert_almost_eq(c.vel.x, c.vel.y, 0.001)

func test_same_inputs_same_flight():
	var a := CanPhysics.new(stats)
	var b := CanPhysics.new(stats)
	a.launch(40.0, 0.8)
	b.launch(40.0, 0.8)
	for i in 120:
		a.step(1.0 / 60.0, [])
		b.step(1.0 / 60.0, [])
	assert_eq(a.pos, b.pos)

func test_touchdown_event_and_dead_bounce_loses_energy():
	var c := CanPhysics.new(stats)
	c.launch(45.0, 1.0)
	var ev := _fly_to_touchdown(c)
	assert_eq(ev.get("type"), "touchdown")
	assert_eq(c.pos.y, 0.0)
	assert_lt(c.vel.length(), c.last_impact_vel.length())

func test_perfect_rekick_beats_good_beats_dead():
	var c := CanPhysics.new(stats)
	c.launch(45.0, 1.0)
	_fly_to_touchdown(c)
	var dead_vx := c.vel.x
	c.rekick(false)
	var good_vx := c.vel.x
	c.rekick(true)
	var perfect_vx := c.vel.x
	assert_gt(good_vx, dead_vx)
	assert_gt(perfect_vx, good_vx)
	assert_gt(perfect_vx, c.last_impact_vel.x)
	assert_gte(c.vel.y, stats.rekick_vy_min)

func test_speed_is_capped():
	var c := CanPhysics.new(stats)
	c.launch(45.0, 1.0)
	_fly_to_touchdown(c)
	c.last_impact_vel = Vector2(stats.max_speed * 2.0, -10.0)
	c.rekick(true)
	assert_lte(c.vel.x, stats.max_speed)

func test_always_comes_to_rest_without_taps():
	var c := CanPhysics.new(stats)
	c.launch(45.0, 1.0)
	var t := 0.0
	while not c.at_rest and t < 60.0:
		t += c.step(1.0 / 60.0, [])
	assert_true(c.at_rest)
	assert_eq(c.vel, Vector2.ZERO)

func test_large_dt_stops_at_touchdown():
	var c := CanPhysics.new(stats)
	c.launch(45.0, 0.3)
	var ev: Array = []
	var used := c.step(5.0, ev)
	assert_lt(used, 5.0)
	assert_eq(ev.size(), 1)
	assert_eq(ev[0].type, "touchdown")
	assert_gte(c.pos.y, 0.0)

func test_time_to_touchdown_predicts_without_drag():
	stats.air_drag = 0.0
	var c := CanPhysics.new(stats)
	c.launch(60.0, 1.0)
	c.step(0.1, [])
	var predicted := c.time_to_touchdown()
	var t0 := c.time
	var ev := _fly_to_touchdown(c)
	assert_almost_eq(ev.t - t0, predicted, 0.01)

func test_time_to_touchdown_inf_when_rolling():
	var c := CanPhysics.new(stats)
	assert_eq(c.time_to_touchdown(), INF)
	c.launch(10.0, 0.2)
	c.rolling = true
	assert_eq(c.time_to_touchdown(), INF)

func test_air_kick_adds_forward_speed():
	var c := CanPhysics.new(stats)
	c.launch(45.0, 0.5)
	c.step(0.1, [])
	var vx := c.vel.x
	c.air_kick(4.0)
	assert_almost_eq(c.vel.x, vx + 4.0, 0.001)
