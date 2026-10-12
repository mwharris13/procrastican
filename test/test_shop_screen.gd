extends GutTest

var d: GameData
var save: Dictionary
var shop: ShopScreen

func before_each():
	d = GameData.load_all()
	save = SaveStore.defaults()
	shop = ShopScreen.new()
	add_child_autofree(shop)

func test_lists_track_upgrades_with_prices():
	save.coins = 0.0
	shop.open(save, d)
	shop.show_track("skills")
	assert_true(shop.rows.has("timing"))
	assert_false(shop.rows.has("kick_power"))
	assert_true(shop.rows.timing.disabled)
	assert_string_contains(shop.rows.timing.text, NumFmt.format(Economy.cost(d.upgrade("timing"), 0)))

func test_buying_updates_save_and_emits_changed():
	save.coins = 1000.0
	shop.open(save, d)
	shop.show_track("gear")
	watch_signals(shop)
	shop.rows.kick_power.pressed.emit()
	assert_eq(Economy.level_of(save, "kick_power"), 1)
	assert_signal_emitted(shop, "changed")
	assert_string_contains(shop.coins_label.text, NumFmt.format(save.coins))

func test_gear_tab_lists_cans_and_equips():
	save.coins = 600.0
	shop.open(save, d)
	shop.show_track("gear")
	assert_true(shop.rows.has("can_paint"))
	shop.rows.can_paint.pressed.emit()
	assert_eq(save.equipped_can, "paint")
	shop.rows.can_soda.pressed.emit()
	assert_eq(save.equipped_can, "soda")

func test_maxed_upgrade_is_disabled():
	save.coins = 1e30
	save.levels["air_kick"] = 5
	shop.open(save, d)
	shop.show_track("skills")
	assert_true(shop.rows.air_kick.disabled)
	assert_string_contains(shop.rows.air_kick.text, "MAX")
