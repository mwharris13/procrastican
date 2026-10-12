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
