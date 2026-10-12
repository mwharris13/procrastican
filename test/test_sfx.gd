extends GutTest

func test_make_has_expected_length_and_format():
	var w := SynthSfx.make(440.0, 440.0, 0.1)
	assert_eq(w.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_eq(w.mix_rate, SynthSfx.MIX_RATE)
	assert_false(w.stereo)
	assert_eq(w.data.size(), int(0.1 * SynthSfx.MIX_RATE) * 2)

func test_make_starts_silent_to_avoid_click():
	var w := SynthSfx.make(440.0, 440.0, 0.1, 0.5)
	assert_lt(absi(w.data.decode_s16(0)), 200)

func test_make_stays_in_range():
	var w := SynthSfx.make(200.0, 50.0, 0.2, 1.0, 1.0, 1.0)
	var peak := 0
	for i in range(0, w.data.size(), 2):
		peak = maxi(peak, absi(w.data.decode_s16(i)))
	assert_lte(peak, 32767)
	assert_gt(peak, 1000)

func test_sfx_builds_all_streams_and_plays_safely():
	var s := Sfx.new()
	add_child_autofree(s)
	for k in ["kick", "perfect", "good", "miss", "helper", "hazard", "coin", "ui"]:
		assert_true(s.streams.has(k), k)
	s.play("kick", 1.2)
	s.play("nope")
	assert_true(true, "unknown sound did not crash")
