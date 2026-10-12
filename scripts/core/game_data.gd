class_name GameData
extends RefCounted
## Loads tuning and content JSON from data/.

const DATA_DIR := "res://data"
const REQUIRED_STATS: Array[String] = [
	"gravity", "air_drag", "launch_speed_max", "max_speed", "angle_min", "angle_max",
	"drag_min_px", "drag_max_px", "can_radius", "can_half_height", "restitution_miss",
	"miss_vx_keep", "restitution_good", "good_vx_keep", "restitution_perfect",
	"perfect_vx_boost", "rekick_vy_min", "roll_vy", "ground_friction", "rest_speed",
	"tailwind", "perfect_window", "good_window", "tap_reach_m", "air_kicks",
	"air_kick_boost", "super_kick_every", "super_kick_mult", "helper_speed_mult",
	"helper_freq", "puddle_trampoline", "coin_per_meter", "coin_mult", "combo_step",
	"rare_mult", "max_run_time", "px_per_m",
]

var tuning: Dictionary = {}


static func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("GameData: bad JSON in %s" % path)
		return null
	return json.data


static func load_all(dir: String = DATA_DIR) -> GameData:
	var d := GameData.new()
	var t = read_json(dir + "/tuning.json")
	if t is Dictionary:
		for k in t:
			d.tuning[k] = float(t[k])
	return d
