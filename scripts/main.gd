extends Node2D
## M0 loop: aim → run → tap to kick again. Task 20 replaces this with the full game flow.

# Real-time lockout so rapid tapping at run end doesn't skip the result message.
const RESTART_LOCKOUT_MS := 400

var data: GameData
var stats: Dictionary
var juice: Juice
var sfx: Sfx
var probe := LatencyProbe.new()
var run_view: RunView
var hud: Hud
var overlay: TuningOverlay
var combo := 0
var _waiting_restart := false
var _run_ended_ms := 0


func _ready() -> void:
	data = GameData.load_all()
	stats = data.tuning.duplicate()
	juice = Juice.new()
	add_child(juice)
	sfx = Sfx.new()
	add_child(sfx)
	run_view = RunView.new()
	add_child(run_view)
	run_view.setup(juice, sfx, probe)
	hud = Hud.new()
	add_child(hud)
	run_view.sim_event.connect(_on_sim_event)
	run_view.progressed.connect(hud.set_distance)
	run_view.run_ended.connect(_on_run_ended)
	overlay = TuningOverlay.new()
	overlay.setup(stats, probe)
	add_child(overlay)
	overlay.visibility_toggled.connect(_on_overlay_toggled)
	_new_run()


func _new_run() -> void:
	combo = 0
	hud.set_combo(0)
	hud.set_distance(0.0)
	hud.show_message("Pull back and release to kick")
	run_view.start_aim(stats)


func _on_sim_event(ev: Dictionary) -> void:
	match ev.type:
		"launch":
			hud.show_message("")
		"graded":
			if ev.grade == TapJudge.Grade.PERFECT:
				combo += 1
			elif ev.grade == TapJudge.Grade.MISS:
				combo = 0
			hud.set_combo(combo)


func _on_overlay_toggled(open: bool) -> void:
	if open:
		run_view.cancel_drag()
	run_view.input_enabled = not open


func _on_run_ended(ev: Dictionary) -> void:
	hud.show_message("%.1f m. Tap to kick again" % ev.x)
	_waiting_restart = true
	_run_ended_ms = Time.get_ticks_msec()


func _unhandled_input(event: InputEvent) -> void:
	if _waiting_restart and event is InputEventScreenTouch and event.pressed \
			and Time.get_ticks_msec() - _run_ended_ms >= RESTART_LOCKOUT_MS:
		_waiting_restart = false
		_new_run()
