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
	var p := j.burst(host, Vector2(50, 50), "spark")
	assert_eq(p.get_parent(), host)
	assert_true(p.emitting)
	assert_not_null(p.texture)

func test_burst_missing_sprite_does_not_crash():
	var host := Node2D.new()
	add_child_autofree(host)
	var p := j.burst(host, Vector2.ZERO, "nope")
	assert_not_null(p)
	assert_null(p.texture)

func test_flash_frees_itself_after_frames_on_real_time():
	var host := Node2D.new()
	add_child_autofree(host)
	var n := j.flash(host, Vector2(10, 10), "fx", "perfect_burst", 3, 0.05)
	j.advance_real(0.1)
	assert_true(is_instance_valid(n) and not n.is_queued_for_deletion())
	j.advance_real(0.06)
	assert_true(n.is_queued_for_deletion())

func test_flash_missing_sprite_does_not_crash():
	var host := Node2D.new()
	add_child_autofree(host)
	j.flash(host, Vector2.ZERO, "fx", "nope", 2)
	j.advance_real(0.01)
	assert_true(true)

func test_leaving_tree_mid_hitstop_restores_time_scale():
	var other := Juice.new()
	add_child(other)
	other.hitstop(10.0)
	remove_child(other)
	other.free()
	assert_eq(Engine.time_scale, 1.0)

func test_leaving_tree_idle_keeps_external_time_scale():
	var other := Juice.new()
	add_child(other)
	Engine.time_scale = 0.5
	remove_child(other)
	other.free()
	assert_eq(Engine.time_scale, 0.5)
