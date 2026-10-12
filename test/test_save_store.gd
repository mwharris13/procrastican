extends GutTest

const PATH := "user://test_save.json"

func after_each():
	for p in [PATH, PATH + ".corrupt"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func test_missing_file_gives_defaults():
	assert_eq(SaveStore.load_from(PATH), SaveStore.defaults())

func test_round_trip():
	var d := SaveStore.defaults()
	d.coins = 1234.0
	d.levels = {"reach": 3}
	d.owned_cans = ["soda", "paint"]
	d.equipped_can = "paint"
	assert_true(SaveStore.save_to(d, PATH))
	var back := SaveStore.load_from(PATH)
	assert_eq(back.coins, 1234.0)
	assert_eq(back.levels.reach, 3)
	assert_eq(back.equipped_can, "paint")

func test_large_coins_round_trip():
	var d := SaveStore.defaults()
	d.coins = 1.5e40
	SaveStore.save_to(d, PATH)
	assert_almost_eq(SaveStore.load_from(PATH).coins / 1e40, 1.5, 1e-9)

func test_corrupt_file_is_set_aside_and_defaults_load():
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	assert_eq(SaveStore.load_from(PATH), SaveStore.defaults())
	assert_true(FileAccess.file_exists(PATH + ".corrupt"))

func test_normalize_fills_missing_and_repairs_bad_fields():
	var n := SaveStore.normalize({"version": 1, "coins": -5, "equipped_can": "lucky", "owned_cans": ["paint"]})
	assert_eq(n.coins, 0.0)
	assert_true(n.owned_cans.has("soda"))
	assert_eq(n.equipped_can, "soda")
	assert_eq(n.levels, {})

func test_normalize_rejects_future_versions_and_junk():
	assert_eq(SaveStore.normalize({"version": 99, "coins": 1}), {})
	assert_eq(SaveStore.normalize("hello"), {})
	assert_eq(SaveStore.normalize({"foo": 1}), {})

func test_export_import_round_trip():
	var d := SaveStore.defaults()
	d.coins = 77.0
	var code := SaveStore.export_code(d)
	assert_true(code.begins_with(SaveStore.CODE_PREFIX))
	assert_eq(SaveStore.import_code("  " + code + "\n").coins, 77.0)

func test_import_rejects_bad_codes():
	assert_eq(SaveStore.import_code(""), {})
	assert_eq(SaveStore.import_code("hello"), {})
	assert_eq(SaveStore.import_code(SaveStore.CODE_PREFIX + "!!!notbase64"), {})
	assert_eq(SaveStore.import_code(SaveStore.CODE_PREFIX + Marshalls.utf8_to_base64("[1,2]")), {})
