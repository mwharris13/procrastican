class_name StatResolver
extends RefCounted
## The one place modifiers stack: (base + Σadd) × Πmul per stat.


static func resolve(base: Dictionary, effects: Array) -> Dictionary:
	var out := base.duplicate()
	var adds := {}
	var muls := {}
	for e in effects:
		var s: String = e.stat
		if not out.has(s):
			push_warning("StatResolver: unknown stat %s" % s)
			continue
		if e.op == "add":
			adds[s] = adds.get(s, 0.0) + float(e.value)
		elif e.op == "mul":
			muls[s] = muls.get(s, 1.0) * float(e.value)
	for s in adds:
		out[s] = float(out[s]) + adds[s]
	for s in muls:
		out[s] = float(out[s]) * muls[s]
	return out
