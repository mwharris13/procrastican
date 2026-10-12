extends GutTest

const BAD_DIR := "user://bad_data"

func after_each():
	if FileAccess.file_exists(BAD_DIR + "/tuning.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAD_DIR + "/tuning.json"))

func test_tuning_has_every_required_stat_as_number():
	var d := GameData.load_all()
	for key in GameData.REQUIRED_STATS:
		assert_true(d.tuning.has(key), key)
		assert_true(typeof(d.tuning[key]) == TYPE_FLOAT, key + " is float")

func test_read_json_missing_or_corrupt_returns_null():
	assert_null(GameData.read_json("user://does_not_exist.json"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BAD_DIR))
	var f := FileAccess.open(BAD_DIR + "/tuning.json", FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	assert_null(GameData.read_json(BAD_DIR + "/tuning.json"))

func test_load_all_from_bad_dir_gives_empty_tuning():
	var d := GameData.load_all("user://nowhere")
	assert_eq(d.tuning, {})
