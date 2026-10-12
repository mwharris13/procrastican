extends GutTest

var stats: Dictionary
var o: TuningOverlay

func before_each():
	stats = GameData.load_all().tuning.duplicate()
	o = TuningOverlay.new()
	o.setup(stats, LatencyProbe.new())
	add_child_autofree(o)

func test_starts_hidden_and_toggles():
	assert_false(o.visible)
	o.toggle()
	assert_true(o.visible)

func test_set_value_edits_shared_stats():
	o.set_value("gravity", 42.0)
	assert_eq(stats.gravity, 42.0)

func test_export_contains_every_key():
	var parsed = JSON.parse_string(o.export_text())
	for k in TuningOverlay.KEYS:
		assert_true(parsed.has(k), k)

func test_readout_mentions_latency():
	assert_string_contains(o.readout_text(), "input")

func test_toggle_emits_visibility_toggled():
	watch_signals(o)
	o.toggle()
	assert_signal_emitted_with_parameters(o, "visibility_toggled", [true])
	o.toggle()
	assert_signal_emitted_with_parameters(o, "visibility_toggled", [false], 1)

func test_three_finger_chord_toggles():
	for i in 3:
		var t := InputEventScreenTouch.new()
		t.index = i
		t.pressed = true
		o._input(t)
	assert_true(o.visible)

func test_canceled_touch_clears_tracking():
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.pressed = true
	o._input(t)
	var c := InputEventScreenTouch.new()
	c.index = 0
	c.canceled = true
	o._input(c)
	assert_eq(o._touches.size(), 0)

func test_open_fills_readout_immediately():
	o.toggle()
	assert_ne(o._readout.text, "")
