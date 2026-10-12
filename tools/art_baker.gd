class_name ArtBaker
extends RefCounted
## Turns hand-authored SVG sprites into hard-edged, palette-snapped PNG sheets.

const GUTTER := 1
const MIN_SHEET_WIDTH := 256
const ANCHORS := ["bottom-center", "bottom-left", "center", "top-left"]

var errors := PackedStringArray()
var _groups := {}
var _snap_cache := {}


func load_palette(path: String) -> bool:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		errors.append("%s: palette is not a JSON object" % path)
		return false
	for g in parsed:
		_groups[g] = parsed[g].values().map(func(h): return Color(h))
	return true


## Returns {"image": Image, "regions": {name: {x, y, w, h, ax, ay}}}, or {} on error (see errors).
func bake_sheet(dir: String) -> Dictionary:
	var files := Array(DirAccess.get_files_at(dir)).filter(func(f): return f.ends_with(".svg"))
	files.sort()
	var frames := []
	for f in files:
		if not _bake_file(dir.path_join(f), f.get_basename(), frames):
			return {}
	if frames.is_empty():
		errors.append("%s: no SVG files" % dir)
		return {}
	return _pack(frames)


static func save_sheet(sheet: Dictionary, out_dir: String, sheet_name: String) -> Error:
	DirAccess.make_dir_recursive_absolute(out_dir)
	var err: Error = sheet.image.save_png(out_dir.path_join(sheet_name + ".png"))
	if err != OK:
		return err
	var f := FileAccess.open(out_dir.path_join(sheet_name + ".json"), FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(sheet.regions, "\t", true))
	return OK


func _bake_file(path: String, sprite: String, out: Array) -> bool:
	var src := FileAccess.get_file_as_string(path)
	var head := _root_tag(src)
	if head.is_empty():
		return _fail(path, "no <svg> root element")
	var w := int(_attr(head, "width"))
	var h := int(_attr(head, "height"))
	if w <= 0 or h <= 0:
		return _fail(path, "root needs integer width and height")
	var pal := _attr(head, "data-palette")
	if pal.is_empty():
		return _fail(path, "missing data-palette")
	var colors := []
	for g in pal.split(","):
		g = g.strip_edges()
		if not _groups.has(g):
			return _fail(path, "unknown palette group '%s'" % g)
		colors.append_array(_groups[g])
	var anchor := _attr(head, "data-anchor")
	if anchor.is_empty():
		anchor = "bottom-center"
	if anchor not in ANCHORS:
		return _fail(path, "unknown data-anchor '%s'" % anchor)
	var spin := int(_attr(head, "data-spin"))
	var count := int(_attr(head, "data-frames"))
	if spin > 0:
		var inner := _inner(src, head)
		for i in spin:
			var deg := 360.0 * i / spin
			var r := deg_to_rad(deg)
			# Shave float fuzz so 90° on a 18×26 sprite stays 26×18, not 27×19.
			var rw := ceili(absf(w * cos(r)) + absf(h * sin(r)) - 0.01)
			var rh := ceili(absf(w * sin(r)) + absf(h * cos(r)) - 0.01)
			var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d"><g transform="translate(%s %s) rotate(%s) translate(%s %s)">%s</g></svg>' % [
				rw, rh, rw, rh, rw / 2.0, rh / 2.0, deg, -w / 2.0, -h / 2.0, inner]
			var img := _raster(svg, path, colors)
			if img == null:
				return false
			out.append({"name": "%s#%d" % [sprite, i], "image": img, "anchor": "center"})
		return true
	var full := _raster(src, path, colors)
	if full == null:
		return false
	if count > 1:
		if w % count != 0:
			return _fail(path, "width %d not divisible by data-frames %d" % [w, count])
		var fw := w / count
		for i in count:
			out.append({"name": "%s#%d" % [sprite, i], "image": full.get_region(Rect2i(i * fw, 0, fw, h)), "anchor": anchor})
	else:
		out.append({"name": sprite, "image": full, "anchor": anchor})
	return true


func _raster(svg: String, path: String, colors: Array) -> Image:
	var img := Image.new()
	if img.load_svg_from_string(svg, 1.0) != OK:
		_fail(path, "SVG failed to rasterize")
		return null
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(0, 0, 0, 0) if c.a < 0.5 else _snap(c, colors))
	return img


func _snap(c: Color, colors: Array) -> Color:
	var key := "%d:%d" % [colors.hash(), Color(c.r, c.g, c.b).to_rgba32()]
	if _snap_cache.has(key):
		return _snap_cache[key]
	var best: Color = colors[0]
	var best_d := INF
	for p: Color in colors:
		# Green-weighted distance tracks perceived difference better than plain RGB.
		var d := 2.0 * pow(c.r - p.r, 2) + 4.0 * pow(c.g - p.g, 2) + 3.0 * pow(c.b - p.b, 2)
		if d < best_d:
			best_d = d
			best = p
	_snap_cache[key] = best
	return best


func _pack(frames: Array) -> Dictionary:
	frames.sort_custom(func(a, b):
		var ha: int = a.image.get_height()
		var hb: int = b.image.get_height()
		return ha > hb if ha != hb else a.name < b.name)
	var width := MIN_SHEET_WIDTH
	for fr in frames:
		width = maxi(width, fr.image.get_width() + 2 * GUTTER)
	var x := GUTTER
	var y := GUTTER
	var shelf := 0
	var placed := []
	for fr in frames:
		var fw: int = fr.image.get_width()
		var fh: int = fr.image.get_height()
		if x + fw + GUTTER > width:
			x = GUTTER
			y += shelf + GUTTER
			shelf = 0
		placed.append([fr, x, y])
		x += fw + GUTTER
		shelf = maxi(shelf, fh)
	var sheet := Image.create_empty(width, y + shelf + GUTTER, false, Image.FORMAT_RGBA8)
	var regions := {}
	for p in placed:
		var fr: Dictionary = p[0]
		var img: Image = fr.image
		var fw := img.get_width()
		var fh := img.get_height()
		sheet.blit_rect(img, Rect2i(0, 0, fw, fh), Vector2i(p[1], p[2]))
		var a := Vector2i(fw / 2, fh)
		if fr.anchor == "center":
			a = Vector2i(fw / 2, fh / 2)
		elif fr.anchor == "top-left":
			a = Vector2i.ZERO
		elif fr.anchor == "bottom-left":
			a = Vector2i(0, fh)
		regions[fr.name] = {"x": p[1], "y": p[2], "w": fw, "h": fh, "ax": a.x, "ay": a.y}
	return {"image": sheet, "regions": regions}


func _fail(path: String, why: String) -> bool:
	errors.append("%s: %s" % [path, why])
	return false


static func _root_tag(src: String) -> String:
	var m := RegEx.create_from_string("<svg\\b[^>]*>").search(src)
	return m.get_string() if m else ""


static func _attr(tag: String, attr: String) -> String:
	var m := RegEx.create_from_string("\\s%s\\s*=\\s*\"([^\"]*)\"" % attr).search(tag)
	return m.get_string(1) if m else ""


static func _inner(src: String, head: String) -> String:
	var start := src.find(head) + head.length()
	return src.substr(start, src.rfind("</svg>") - start)
