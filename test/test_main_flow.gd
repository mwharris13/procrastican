extends GutTest

const SAVE := "user://test_main_save.json"
var main

func before_each():
	main = load("res://scenes/main.tscn").instantiate()
	main.save_path = SAVE
	add_child_autofree(main)

func after_each():
	get_tree().paused = false
	Engine.time_scale = 1.0
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

func _launch_and_finish():
	main.run_view.begin_drag(Vector2(100, 300))
	main.run_view.update_drag(Vector2(40, 360))
	main.run_view.end_drag()
	for i in 20000:
		main.run_view.tick(1.0 / 60.0)
		if main.run_view.state == "done":
			return

func _spare_kick():
	return GameData.load_all().perks.filter(func(p): return p.id == "spare_kick")[0]

func test_starts_on_title():
	assert_eq(main.screen, Main.Screen.TITLE)
	assert_true(main.title.visible)
	assert_false(main.hud.visible)

func test_start_run_rolls_modifier_and_aims():
	main.start_run()
	assert_eq(main.screen, Main.Screen.RUN)
	assert_eq(main.run_view.state, "aiming")
	assert_false(main.modifier.is_empty())
	assert_string_contains(main.hud.info_label.text, main.modifier.name)

func test_run_end_pays_out_saves_and_shows_results():
	main.start_run()
	_launch_and_finish()
	assert_eq(main.screen, Main.Screen.RESULTS)
	assert_gt(main.save.coins, 0.0)
	assert_eq(main.save.runs, 1)
	assert_true(FileAccess.file_exists(SAVE))

func test_perk_checkpoint_pauses_and_pick_applies():
	main.start_run()
	main._on_progressed(RunState.PERK_FIRST_M + 1.0)
	assert_eq(main.screen, Main.Screen.PERK)
	assert_true(get_tree().paused)
	main.perk_pick.buttons[0].pressed.emit()
	assert_eq(main.screen, Main.Screen.RUN)
	assert_eq(main.run_perks.size(), 1)
	assert_false(get_tree().paused)

func test_spare_kick_perk_adds_air_kick_mid_run():
	main.start_run()
	var before: int = main.run_view.sim.air_kicks_left
	main._on_progressed(RunState.PERK_FIRST_M + 1.0)
	main.perk_pick.picked.emit(_spare_kick())
	assert_eq(main.run_view.sim.air_kicks_left, before + 1)

func test_double_pick_applies_only_one_perk():
	main.start_run()
	main._on_progressed(RunState.PERK_FIRST_M + 1.0)
	main.perk_pick.picked.emit(_spare_kick())
	main.perk_pick.picked.emit(_spare_kick())
	assert_eq(main.run_perks.size(), 1)

func test_overlay_toggle_gates_run_input():
	main.start_run()
	main.overlay.visibility_toggled.emit(true)
	assert_false(main.run_view.input_enabled)
	main.overlay.visibility_toggled.emit(false)
	assert_true(main.run_view.input_enabled)

func test_background_pause_restores_time_scale():
	main.start_run()
	main.juice.hitstop(5.0)
	main.background_pause()
	assert_eq(Engine.time_scale, 1.0)
	assert_true(get_tree().paused)
	assert_true(main.pause_label.visible)
	main.resume()
	assert_false(get_tree().paused)

func test_failed_save_shows_toast():
	main.save_path = "user://missing_dir/deeper/save.json"
	main._persist()
	assert_string_contains(main.toast_label.text, "Couldn't save")

func test_import_replaces_save_and_returns_to_title():
	var d := SaveStore.defaults()
	d.coins = 4242.0
	main.open_settings()
	main.settings.imported.emit(d)
	assert_eq(main.save.coins, 4242.0)
	assert_eq(main.screen, Main.Screen.TITLE)
