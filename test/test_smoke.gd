extends GutTest

func test_portrait_270_wide_viewport():
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 270)
	assert_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "keep_width")

func test_main_scene_loads():
	var scene: PackedScene = load("res://scenes/main.tscn")
	assert_not_null(scene)
	var main = scene.instantiate()
	add_child_autofree(main)
	assert_true(main is Node2D)
