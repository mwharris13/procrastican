extends GutTest

func _add(s: Control) -> Control:
	add_child_autofree(s)
	return s

func test_title_emits_signals_and_shows_coins():
	var t: TitleScreen = _add(TitleScreen.new())
	watch_signals(t)
	t.set_coins(12_500.0)
	assert_string_contains(t.coins_label.text, "12.5K")
	t.play_button.pressed.emit()
	assert_signal_emitted(t, "play")

func test_perk_pick_offers_and_emits_choice():
	var p: PerkPickScreen = _add(PerkPickScreen.new())
	watch_signals(p)
	var perks := GameData.load_all().perks.slice(0, 3)
	p.show_perks(perks)
	assert_eq(p.buttons.size(), 3)
	assert_string_contains(p.buttons[1].text, perks[1].name)
	p.buttons[1].pressed.emit()
	assert_signal_emitted_with_parameters(p, "picked", [perks[1]])

func test_results_show_numbers():
	var r: ResultsScreen = _add(ResultsScreen.new())
	r.show_results(512.3, 14, 3.2e6, true)
	assert_string_contains(r.summary.text, "512.3")
	assert_string_contains(r.summary.text, "3.2M")
	assert_string_contains(r.summary.text, "NEW RECORD")

func test_results_ignore_presses_until_armed():
	var r: ResultsScreen = _add(ResultsScreen.new())
	watch_signals(r)
	r.show_results(10.0, 1, 5.0, false)
	assert_false(r.armed())
	r.again_button.pressed.emit()
	r.shop_button.pressed.emit()
	assert_signal_not_emitted(r, "again")
	assert_signal_not_emitted(r, "shop")
	r._shown_ms -= 1000
	assert_true(r.armed())
	r.again_button.pressed.emit()
	assert_signal_emitted(r, "again")
	r.shop_button.pressed.emit()
	assert_signal_emitted(r, "shop")

func test_settings_export_then_import_with_confirm():
	var s: SettingsScreen = _add(SettingsScreen.new())
	watch_signals(s)
	var save := SaveStore.defaults()
	save.coins = 99.0
	s.set_save(save)
	assert_true(s.export_box.text.begins_with(SaveStore.CODE_PREFIX))
	s.import_box.text = s.export_box.text
	assert_false(s.try_import())
	assert_signal_not_emitted(s, "imported")
	assert_true(s.try_import())
	assert_signal_emitted(s, "imported")

func test_bad_import_leaves_save_untouched():
	var s: SettingsScreen = _add(SettingsScreen.new())
	watch_signals(s)
	s.set_save(SaveStore.defaults())
	s.import_box.text = "PCAN1:garbage"
	assert_false(s.try_import())
	assert_false(s.try_import())
	assert_signal_not_emitted(s, "imported")
	assert_string_contains(s.status.text, "isn't a valid")
