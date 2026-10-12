extends GutTest

const FIX := "res://test/fixtures/art"

var baker: ArtBaker
var sheet: Dictionary


func before_each():
	baker = ArtBaker.new()
	assert_true(baker.load_palette(FIX + "/palette.json"))
	sheet = baker.bake_sheet(FIX + "/ok")


func _palette_colors() -> Array:
	return [Color("e63946"), Color("ffffff"), Color("4b5a8a")]


func test_bakes_every_frame():
	assert_eq(baker.errors.size(), 0, str(baker.errors))
	var names: Array = sheet.regions.keys()
	names.sort()
	assert_eq(names, ["a", "spin#0", "spin#1", "spin#2", "spin#3", "strip#0", "strip#1"])


func test_alpha_is_hard_and_colors_are_on_palette():
	var img: Image = sheet.image
	var allowed := _palette_colors()
	var opaque := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			assert_true(c.a == 0.0 or c.a == 1.0, "alpha at %d,%d is %f" % [x, y, c.a])
			if c.a == 1.0:
				opaque += 1
				assert_true(allowed.any(func(p): return p.is_equal_approx(c)), "off-palette %s at %d,%d" % [c, x, y])
	assert_gt(opaque, 50)


func test_off_palette_source_color_snaps_to_nearest():
	var r: Dictionary = sheet.regions["a"]
	# The f0f0f0 bar in the source must land on palette white.
	assert_eq(sheet.image.get_pixel(r.x + 1, r.y + 0), Color("ffffff"))


func test_spin_frames_rotate_bounds():
	assert_eq([sheet.regions["spin#0"].w, sheet.regions["spin#0"].h], [6, 10])
	assert_eq([sheet.regions["spin#1"].w, sheet.regions["spin#1"].h], [10, 6])
	assert_eq([sheet.regions["spin#2"].w, sheet.regions["spin#2"].h], [6, 10])
	assert_eq([sheet.regions["spin#1"].ax, sheet.regions["spin#1"].ay], [5, 3], "spin frames anchor at center")


func test_frame_strip_splits_with_anchor():
	var f0: Dictionary = sheet.regions["strip#0"]
	var f1: Dictionary = sheet.regions["strip#1"]
	assert_eq([f0.w, f0.h, f0.ax, f0.ay], [4, 4, 0, 0])
	assert_eq(sheet.image.get_pixel(f0.x + 1, f0.y + 1), Color("e63946"))
	assert_eq(sheet.image.get_pixel(f1.x + 1, f1.y + 1), Color("4b5a8a"))


func test_default_anchor_is_bottom_center():
	assert_eq([sheet.regions["a"].ax, sheet.regions["a"].ay], [5, 10])


func test_regions_lie_inside_sheet():
	var size: Vector2i = sheet.image.get_size()
	for n in sheet.regions:
		var r: Dictionary = sheet.regions[n]
		assert_true(Rect2i(Vector2i.ZERO, size).encloses(Rect2i(r.x, r.y, r.w, r.h)), n)


func test_missing_palette_attribute_fails():
	assert_eq(baker.bake_sheet(FIX + "/nopal"), {})
	assert_string_contains(baker.errors[-1], "missing data-palette")


func test_unknown_palette_group_fails():
	assert_eq(baker.bake_sheet(FIX + "/badgroup"), {})
	assert_string_contains(baker.errors[-1], "unknown palette group 'zz'")


func test_save_sheet_writes_png_and_json():
	var out := "user://bake_test"
	assert_eq(ArtBaker.save_sheet(sheet, out, "ok"), OK)
	assert_true(FileAccess.file_exists(out + "/ok.png"))
	var regions = JSON.parse_string(FileAccess.get_file_as_string(out + "/ok.json"))
	assert_eq(regions.size(), 7)
	DirAccess.remove_absolute(out + "/ok.png")
	DirAccess.remove_absolute(out + "/ok.json")
