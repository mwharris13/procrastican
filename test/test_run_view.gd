extends GutTest

var view: RunView
var stats: Dictionary

func before_each():
	stats = GameData.load_all().tuning.duplicate()
	var juice := Juice.new()
	add_child_autofree(juice)
	var sfx := Sfx.new()
	add_child_autofree(sfx)
	view = RunView.new()
	add_child_autofree(view)
	view.setup(juice, sfx, LatencyProbe.new())
	view.start_aim(stats)

func after_each():
	Engine.time_scale = 1.0

func test_world_screen_round_trip():
	var w := Vector2(3.0, 2.0)
	assert_almost_eq(view.screen_to_world(view.world_to_screen(w)).x, w.x, 0.1)
	assert_almost_eq(view.screen_to_world(view.world_to_screen(w)).y, w.y, 0.1)

func test_tiny_drag_does_not_launch():
	view.begin_drag(Vector2(100, 300))
	view.update_drag(Vector2(96, 303))
	view.end_drag()
	assert_eq(view.state, "aiming")
	assert_false(view.sim.can.launched)

func test_pull_back_launches():
	watch_signals(view)
	view.begin_drag(Vector2(100, 300))
	view.update_drag(Vector2(40, 360))
	view.end_drag()
	assert_eq(view.state, "flying")
	assert_true(view.sim.can.launched)
	assert_signal_emitted(view, "sim_event")

func test_run_plays_out_to_end():
	watch_signals(view)
	view.begin_drag(Vector2(100, 300))
	view.update_drag(Vector2(40, 360))
	view.end_drag()
	for i in 6000:
		view.tick(1.0 / 60.0)
		if view.state == "done":
			break
	assert_eq(view.state, "done")
	assert_signal_emitted(view, "run_ended")
	assert_gt(view.cam_x, 0.0)

func test_tap_far_from_can_is_ignored():
	view.begin_drag(Vector2(100, 300))
	view.update_drag(Vector2(40, 360))
	view.end_drag()
	assert_eq(view.tap_screen(Vector2(269, 584)), {})
