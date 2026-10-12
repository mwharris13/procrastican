class_name SpriteBank
extends RefCounted
## Loads baked sprite sheets once and draws frames by name at their anchor.

const DIR := "res://assets/sprites/"

static var _sheets := {}
static var _warned := {}


## {tex, region: Rect2, anchor: Vector2}, or {} when the sheet or name is missing (warns once).
static func frame(sheet: String, sprite: String) -> Dictionary:
	var s := _sheet(sheet)
	if s.is_empty() or not s.regions.has(sprite):
		_warn_once("%s/%s" % [sheet, sprite], "SpriteBank: unknown sprite %s/%s" % [sheet, sprite])
		return {}
	return s.frames[sprite]


static func has(sheet: String, sprite: String) -> bool:
	var s := _sheet(sheet)
	return not s.is_empty() and s.regions.has(sprite)


static func names(sheet: String) -> Array:
	var s := _sheet(sheet)
	return [] if s.is_empty() else s.regions.keys()


static func draw(ci: CanvasItem, sheet: String, sprite: String, pos: Vector2, modulate := Color.WHITE) -> void:
	var f := frame(sheet, sprite)
	if f.is_empty():
		return
	ci.draw_texture_rect_region(f.tex, Rect2((pos - f.anchor).round(), f.region.size), f.region, modulate)


static func _sheet(sheet: String) -> Dictionary:
	if _sheets.has(sheet):
		return _sheets[sheet]
	var loaded := {}
	var tex = load(DIR + sheet + ".png") if ResourceLoader.exists(DIR + sheet + ".png") else null
	var regions = JSON.parse_string(FileAccess.get_file_as_string(DIR + sheet + ".json")) if FileAccess.file_exists(DIR + sheet + ".json") else null
	if tex is Texture2D and regions is Dictionary:
		var frames := {}
		for k in regions:
			var r: Dictionary = regions[k]
			frames[k] = {"tex": tex, "region": Rect2(r.x, r.y, r.w, r.h), "anchor": Vector2(r.ax, r.ay)}
		loaded = {"tex": tex, "regions": regions, "frames": frames}
	else:
		_warn_once(sheet, "SpriteBank: missing sheet %s" % sheet)
	_sheets[sheet] = loaded
	return loaded


static func _warn_once(key: String, msg: String) -> void:
	if not _warned.has(key):
		_warned[key] = true
		push_warning(msg)
