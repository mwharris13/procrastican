class_name Sfx
extends Node
## Round-robin voice pool over preloaded procedural sounds.

const VOICES := 6
# name: [f0, f1, dur, noise, decay, vol]
const SOUNDS := {
	"kick": [140.0, 60.0, 0.12, 0.25, 18.0, 0.9],
	"perfect": [660.0, 990.0, 0.14, 0.0, 14.0, 0.6],
	"good": [440.0, 520.0, 0.10, 0.05, 18.0, 0.5],
	"miss": [180.0, 90.0, 0.10, 0.5, 25.0, 0.5],
	"helper": [300.0, 700.0, 0.18, 0.0, 10.0, 0.5],
	"hazard": [120.0, 80.0, 0.20, 0.7, 12.0, 0.5],
	"coin": [1320.0, 1760.0, 0.12, 0.0, 16.0, 0.4],
	"ui": [880.0, 880.0, 0.05, 0.0, 30.0, 0.3],
	"tick": [1800.0, 1500.0, 0.025, 0.0, 60.0, 0.25],
}

var streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for k in SOUNDS:
		var a: Array = SOUNDS[k]
		streams[k] = SynthSfx.make(a[0], a[1], a[2], a[3], a[4], a[5])
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(sound: String, pitch: float = 1.0) -> void:
	if not streams.has(sound):
		push_warning("Sfx: unknown sound %s" % sound)
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = streams[sound]
	p.pitch_scale = pitch
	p.play()
