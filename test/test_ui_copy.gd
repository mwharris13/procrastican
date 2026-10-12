extends GutTest
## Descriptions must fit two 8 px lines in a panel; every content id needs an icon.

const MAX_DESC := 56
const MAX_WORD := 28

var d: GameData


func before_each():
	d = GameData.load_all()


func test_descriptions_fit_the_panel():
	for list in [d.upgrades, d.perks, d.modifiers, d.cans]:
		for item in list:
			var desc: String = item.desc
			assert_lte(desc.length(), MAX_DESC, "%s: %s" % [item.id, desc])
			for w in desc.split(" "):
				assert_lte(w.length(), MAX_WORD, "%s word %s" % [item.id, w])


func test_every_upgrade_can_and_perk_has_an_icon():
	for list in [d.upgrades, d.cans, d.perks]:
		for item in list:
			assert_true(SpriteBank.has("icons", "icon_" + item.id), "icons/icon_" + item.id)


func test_ui_sprites_exist():
	for n in ["panel", "panel_rare", "button_normal", "button_pressed", "button_disabled", "button_primary_normal",
			"button_primary_pressed", "tab_on", "tab_off", "chip", "pip_on", "pip_off", "coin_icon", "new_best_stamp"]:
		assert_true(SpriteBank.has("ui", n), "ui/" + n)


func test_theme_builds_with_pixel_font_and_sliced_buttons():
	var t := UiTheme.build()
	assert_eq(t.default_font_size, UiTheme.SMALL)
	assert_true(t.default_font is FontFile)
	assert_true(t.get_stylebox("normal", "Button") is StyleBoxTexture)
	assert_true(t.get_stylebox("panel", "PanelContainer") is StyleBoxTexture)
	assert_true(t.get_stylebox("focus", "Button") is StyleBoxEmpty)
	var f: FontFile = UiTheme.font()
	assert_eq(f.antialiasing, TextServer.FONT_ANTIALIASING_NONE)
	assert_eq(f.hinting, TextServer.HINTING_NONE)
	assert_eq(f.subpixel_positioning, TextServer.SUBPIXEL_POSITIONING_DISABLED)
