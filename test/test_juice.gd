extends GutTest

var j: Juice

func before_each():
	j = Juice.new()
	add_child_autofree(j)

func after_each():
	Engine.time_scale = 1.0

func test_hitstop_slows_then_restores_on_real_time():
	j.hitstop(0.06)
	assert_eq(Engine.time_scale, Juice.HITSTOP_SCALE)
	j.advance_real(0.03)
	assert_eq(Engine.time_scale, Juice.HITSTOP_SCALE)
	j.advance_real(0.04)
	assert_eq(Engine.time_scale, 1.0)

func test_end_hitstop_restores_immediately():
	j.hitstop(10.0)
	j.end_hitstop()
	assert_eq(Engine.time_scale, 1.0)

func test_shake_decays_to_zero():
	j.shake(4.0)
	j.advance_real(0.01)
	assert_lte(absf(j.shake_offset.x), 4.0)
	j.advance_real(1.0)
	assert_eq(j.shake_offset, Vector2.ZERO)

func test_popup_and_burst_create_nodes():
	var l := j.popup("PERFECT!", Vector2(100, 100), Color.YELLOW)
	assert_eq(l.text, "PERFECT!")
	assert_eq(l.get_parent(), j.popup_layer)
	var host := Node2D.new()
	add_child_autofree(host)
	var p := j.burst(host, Vector2(50, 50), Color.WHITE)
	assert_eq(p.get_parent(), host)
	assert_true(p.emitting)
