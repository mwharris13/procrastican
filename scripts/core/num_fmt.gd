class_name NumFmt
extends RefCounted
## Idle-game number abbreviation: 1.2K, 34.5M, 8.1B …

const SUFFIXES: Array[String] = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]


static func format(n: float) -> String:
	if is_nan(n):
		return "0"
	if is_inf(n):
		return "∞" if n > 0.0 else "-∞"
	var sign := "-" if n < 0.0 else ""
	var v := absf(n)
	if v < 999.95:
		return sign + str(int(floorf(v)))
	var tier := 0
	while v >= 999.95 and tier < SUFFIXES.size() - 1:
		v /= 1000.0
		tier += 1
	if v >= 999.95:
		var e := int(floorf(log(absf(n)) / log(10.0)))
		var mantissa := absf(n) / pow(10.0, e)
		if mantissa >= 9.995:
			mantissa /= 10.0
			e += 1
		return sign + "%.2fe%d" % [mantissa, e]
	return sign + ("%.1f" % v) + SUFFIXES[tier]
