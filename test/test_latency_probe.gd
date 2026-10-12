extends GutTest

func test_input_to_next_frame_latency():
	var p := LatencyProbe.new()
	p.mark_frame(0)
	p.mark_input(1_000)
	p.mark_frame(5_000)
	p.mark_frame(21_000)
	assert_almost_eq(p.input_avg_ms(), 4.0, 0.001)
	assert_almost_eq(p.input_max_ms(), 4.0, 0.001)
	assert_almost_eq(p.frame_avg_ms(), (5.0 + 16.0) / 2.0, 0.001)
	assert_almost_eq(p.frame_max_ms(), 16.0, 0.001)

func test_only_first_input_before_a_frame_counts():
	var p := LatencyProbe.new()
	p.mark_input(0)
	p.mark_input(3_000)
	p.mark_frame(10_000)
	assert_almost_eq(p.input_avg_ms(), 10.0, 0.001)

func test_empty_probe_reports_zero():
	var p := LatencyProbe.new()
	assert_eq(p.input_avg_ms(), 0.0)
	assert_eq(p.frame_max_ms(), 0.0)
