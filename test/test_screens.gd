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
	p._shown_ms -= 1000
	assert_eq(p.buttons.size(), 3)
	assert_eq(p.buttons[1].perk.name, perks[1].name)
	p.buttons[1].pressed.emit()
	assert_signal_emitted_with_parameters(p, "picked", [perks[1]])

func test_results_show_numbers():
	var r: ResultsScreen = _add(ResultsScreen.new())
	r.show_results(512.3, 14, 3.2e6, true, 23, "Downtown x10")
	r.finish_count()
	assert_string_contains(r.distance_label.text, "512.3")
	assert_string_contains(r.coins_label.text, "3.2M")
	assert_true(r.stamp.visible)
	assert_eq(r.kid.pose, "cheer")
	assert_eq(r.perfects_label.text, "23")
	assert_eq(r.zone_label.text, "Downtown x10")

func test_results_without_record_shrugs_and_hides_stamp():
	var r: ResultsScreen = _add(ResultsScreen.new())
	r.show_results(10.0, 1, 5.0, false)
	assert_false(r.stamp.visible)
	assert_eq(r.kid.pose, "shrug")

func test_results_coin_count_ticks_up_to_target():
	var r: ResultsScreen = _add(ResultsScreen.new())
	watch_signals(r)
	r.show_results(10.0, 1, 1000.0, false)
	assert_eq(r.coins_label.text, "+0")
	await wait_seconds(1.1)
	assert_eq(r.coins_label.text, "+" + NumFmt.format(1000.0))
	assert_signal_emitted(r, "coin_tick")

func test_perk_pick_shows_checkpoint_and_rare_cards_use_lilac():
	var p: PerkPickScreen = _add(PerkPickScreen.new())
	var perks := GameData.load_all().perks
	p.show_perks([perks[0], perks[4]], 250.0)
	assert_string_contains(p.checkpoint_label.text, "250")
	assert_eq(p.buttons[0].theme_type_variation, "RowButton")
	assert_eq(p.buttons[1].theme_type_variation, "RareCard")

func test_perk_pick_ignores_press_until_armed():
	var p := PerkPickScreen.new()
	add_child_autofree(p)
	p.show_perks(GameData.load_all().perks.slice(0, 3))
	watch_signals(p)
	p.buttons[0].pressed.emit()
	assert_signal_not_emitted(p, "picked")

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

func test_logo_and_icon_sprites_exist():
	assert_true(SpriteBank.has("ui", "logo"))
	assert_true(SpriteBank.has("app", "icon"))
