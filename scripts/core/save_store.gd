class_name SaveStore
extends RefCounted
## Versioned JSON save in user:// plus a copyable export code.

const VERSION := 1
const DEFAULT_PATH := "user://save.json"
const CODE_PREFIX := "PCAN1:"

static var _B64 := _make_b64()


static func defaults() -> Dictionary:
	return {
		"version": VERSION, "coins": 0.0, "levels": {}, "owned_cans": ["soda"],
		"equipped_can": "soda", "best_distance": 0.0, "runs": 0, "lifetime_coins": 0.0,
	}


static func normalize(raw: Variant) -> Dictionary:
	if not (raw is Dictionary) or not raw.has("version") or not raw.has("coins"):
		return {}
	var version := _to_int(raw.version, -1)
	if version < 0 or version > VERSION:
		return {}
	var d := defaults()
	d.coins = _nonneg(raw.get("coins", 0.0))
	d.best_distance = _nonneg(raw.get("best_distance", 0.0))
	d.lifetime_coins = _nonneg(raw.get("lifetime_coins", 0.0))
	d.runs = _to_int(raw.get("runs", 0))
	var levels = raw.get("levels", {})
	if levels is Dictionary:
		for k in levels:
			d.levels[str(k)] = _to_int(levels[k])
	var owned = raw.get("owned_cans", [])
	if owned is Array:
		for c in owned:
			if not d.owned_cans.has(str(c)):
				d.owned_cans.append(str(c))
	var eq := str(raw.get("equipped_can", "soda"))
	d.equipped_can = eq if d.owned_cans.has(eq) else "soda"
	return d


static func _to_int(v: Variant, fallback: int = 0) -> int:
	if not (v is int or v is float):
		return fallback
	var f := float(v)
	if not is_finite(f):
		return fallback
	return int(clampf(f, 0.0, 1_000_000_000.0))


static func _nonneg(v: Variant) -> float:
	var f := float(v) if (v is float or v is int) else 0.0
	return f if is_finite(f) and f > 0.0 else 0.0


static func load_from(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return defaults()
	var d := normalize(_parse(FileAccess.get_file_as_string(path)))
	if d.is_empty():
		push_warning("SaveStore: corrupt save set aside at %s.corrupt" % path)
		DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".corrupt"))
		return defaults()
	return d


static func save_to(data: Dictionary, path: String = DEFAULT_PATH) -> bool:
	# Check first: a failed open logs an engine error, which GUT counts as a failure.
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path.get_base_dir())):
		return false
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	return true


static func export_code(data: Dictionary) -> String:
	return CODE_PREFIX + Marshalls.utf8_to_base64(JSON.stringify(data))


static func import_code(code: String) -> Dictionary:
	var c := code.strip_edges()
	if not c.begins_with(CODE_PREFIX):
		return {}
	var body := c.substr(CODE_PREFIX.length())
	for ws in [" ", "\t", "\n", "\r"]:
		body = body.replace(ws, "")
	# Pre-validate: base64_to_utf8 logs an engine error on bad input, which GUT counts as a failure.
	if body.length() % 4 != 0 or not _B64.search(body):
		return {}
	var text := Marshalls.base64_to_utf8(body)
	if text.is_empty():
		return {}
	return normalize(_parse(text))


static func _make_b64() -> RegEx:
	var r := RegEx.new()
	r.compile("^[A-Za-z0-9+/]*={0,2}$")
	return r


# Instance parse() returns an error code instead of logging an engine error like parse_string.
static func _parse(text: String) -> Variant:
	var json := JSON.new()
	return json.data if json.parse(text) == OK else null
