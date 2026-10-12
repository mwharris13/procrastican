extends GutTest

var stats: Dictionary

func before_each():
	stats = GameData.load_all().tuning.duplicate()

func test_tiny_drag_is_invalid():
	var a := LaunchAim.from_drag(Vector2(-5, 5), stats)
	assert_false(a.valid)

func test_pull_down_left_launches_up_right_at_45():
	var a := LaunchAim.from_drag(Vector2(-40, 40), stats)
	assert_true(a.valid)
	assert_almost_eq(a.angle, 45.0, 0.01)
	assert_almost_eq(a.power, Vector2(40, 40).length() / stats.drag_max_px, 0.001)

func test_power_clamps_at_one():
	assert_eq(LaunchAim.from_drag(Vector2(-500, 100), stats).power, 1.0)

func test_angle_clamps_to_range():
	assert_eq(LaunchAim.from_drag(Vector2(-5, 100), stats).angle, stats.angle_max)
	assert_eq(LaunchAim.from_drag(Vector2(-100, 0), stats).angle, stats.angle_min)
	assert_eq(LaunchAim.from_drag(Vector2(-100, -30), stats).angle, stats.angle_min)

func test_preview_rises_then_ends_at_ground():
	var pts := LaunchAim.preview(45.0, 1.0, stats)
	assert_gt(pts.size(), 3)
	assert_lte(pts.size(), 18)
	assert_gt(pts[0].x, 0.0)
	assert_gt(pts[2].y, 0.0)
