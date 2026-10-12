class_name SynthSfx
extends RefCounted
## Tiny procedural sound generator so v1 ships without audio assets.

const MIX_RATE := 22050


static func make(f0: float, f1: float, dur: float, noise: float = 0.0, decay: float = 8.0, vol: float = 0.8, noise_seed: int = 1) -> AudioStreamWAV:
	var n := int(dur * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = noise_seed
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		phase += TAU * lerpf(f0, f1, t / dur) / MIX_RATE
		# A 2.5 ms attack ramp avoids a click at the start.
		var env := exp(-decay * t) * minf(1.0, t * 400.0)
		var s := (sin(phase) * (1.0 - noise) + rng.randf_range(-1.0, 1.0) * noise) * env * vol
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
