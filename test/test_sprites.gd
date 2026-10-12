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
