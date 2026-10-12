extends SceneTree
## CLI: bakes every art/src/<sheet>/ directory into assets/sprites/<sheet>.png + .json.

const SRC := "res://art/src"
const OUT := "res://assets/sprites"


func _init() -> void:
	var baker := ArtBaker.new()
	if not baker.load_palette("res://art/palette.json"):
		_abort(baker)
		return
	var sheets := {}
	var dirs := Array(DirAccess.get_directories_at(SRC))
	dirs.sort()
	for d in dirs:
		var sheet := baker.bake_sheet(SRC.path_join(d))
		if sheet.is_empty():
			_abort(baker)
			return
		sheets[d] = sheet
	# Write only after every sheet baked, so a bad SVG never leaves a half-updated set.
	for d in sheets:
		var err := ArtBaker.save_sheet(sheets[d], OUT, d)
		if err != OK:
			printerr("bake_art: failed writing %s (error %d)" % [d, err])
			quit(1)
			return
		print("bake_art: %s → %d frames, %s" % [d, sheets[d].regions.size(), sheets[d].image.get_size()])
	quit(0)


func _abort(baker: ArtBaker) -> void:
	for e in baker.errors:
		printerr("bake_art: " + e)
	quit(1)
