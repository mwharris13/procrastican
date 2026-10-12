extends GutTest

var d: GameData


func before_each():
	d = GameData.load_all()


func test_every_object_has_a_sprite():
	for id in d.objects:
		assert_true(SpriteBank.has("objects", id), "objects/" + id)


func test_every_can_has_sixteen_spin_frames():
	for c in d.cans:
		for i in 16:
			assert_true(SpriteBank.has("cans", "%s#%d" % [c.id, i]), "cans/%s#%d" % [c.id, i])


func test_every_kid_pose_exists():
	for pose in ["idle#0", "idle#1", "aim_light", "aim_strong", "kick", "watch", "cheer", "shrug"]:
		assert_true(SpriteBank.has("kid", pose), "kid/" + pose)


func test_frame_returns_region_and_anchor():
	var f := SpriteBank.frame("objects", "mailbox")
	assert_true(f.tex is Texture2D)
	assert_eq(f.anchor, Vector2(f.region.size.x / 2, f.region.size.y).floor())


func test_unknown_sprite_returns_empty():
	assert_eq(SpriteBank.frame("objects", "no_such_sprite"), {})
	assert_false(SpriteBank.has("no_such_sheet", "x"))


func test_spin_frame_index():
	var cases := [[0.0, 0], [11.24, 0], [11.26, 1], [359.0, 0], [-22.5, 15], [720.0, 0], [90.0, 4]]
	for c in cases:
		assert_eq(RunView.spin_frame(deg_to_rad(c[0])), c[1], "angle %s" % c[0])


func test_every_building_name_exists_in_its_sheet():
	for sheet in ZoneLook.BUILDINGS:
		for n in ZoneLook.BUILDINGS[sheet]:
			assert_true(SpriteBank.has(sheet, n), "%s/%s" % [sheet, n])


func test_every_run_view_scenery_sprite_exists():
	var refs := {
		"block": ["sun_low", "cloud_a", "cloud_b", "hills_far", "hills_near", "house_shadow"],
		"downtown": ["sun_dusk", "cloud_dusk", "skyline", "streetlight"],
		"highway": ["city_far", "moon", "star_a", "star_b", "lamp_sodium"],
		"fx": ["light_pool"],
	}
	for sheet in refs:
		for n in refs[sheet]:
			assert_true(SpriteBank.has(sheet, n), "%s/%s" % [sheet, n])
