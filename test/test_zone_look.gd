extends GutTest

var zones: Array


func before_each():
	zones = GameData.load_all().zones


func _start(i: int) -> float:
	return float(zones[i].start_m)


func test_no_blend_inside_a_zone():
	var b := ZoneLook.blend_at(zones, 10.0)
	assert_eq([b.from, b.to, b.t], [0, 0, 0.0])
	b = ZoneLook.blend_at(zones, _start(1) + 5.0)
	assert_eq([b.from, b.to, b.t], [1, 1, 0.0])


func test_blend_ramps_over_window_before_boundary():
	var s := _start(1)
	assert_eq(ZoneLook.blend_at(zones, s - ZoneLook.BLEND_M - 0.01).t, 0.0)
	var mid := ZoneLook.blend_at(zones, s - ZoneLook.BLEND_M / 2.0)
	assert_eq([mid.from, mid.to], [0, 1])
	assert_almost_eq(mid.t, 0.5, 1e-6)
	assert_almost_eq(ZoneLook.blend_at(zones, s - 0.001).t, 1.0, 1e-3)
	assert_eq(ZoneLook.blend_at(zones, s).from, 1, "at the boundary the next zone takes over")


func test_sky_stops_match_zone_endpoints():
	var at0 := ZoneLook.sky_stops(zones, 0.0)
	var in1 := ZoneLook.sky_stops(zones, _start(1) + 1.0)
	for i in ZoneLook.SKY_STOPS:
		assert_eq(at0[i], Color(zones[0].palette.sky[i]))
		assert_eq(in1[i], Color(zones[1].palette.sky[i]))


func test_tint_lerps_between_zones():
	var mid := ZoneLook.tint(zones, _start(2) - ZoneLook.BLEND_M / 2.0)
	var expect := Color(zones[1].palette.tint).lerp(Color(zones[2].palette.tint), 0.5)
	assert_true(mid.is_equal_approx(expect))


func test_building_choice_is_stable_and_follows_slot_zone():
	var a := ZoneLook.building(zones, 3, 21.0)
	assert_eq(a, ZoneLook.building(zones, 3, 21.0))
	assert_eq(a.sheet, "block")
	assert_true(a.name in ZoneLook.BUILDINGS.block)
	assert_eq(ZoneLook.building(zones, 40, _start(1) + 1.0).sheet, "downtown")
