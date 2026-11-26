class_name NumFmt
extends RefCounted
## Formato compacto de números grandes para la interfaz.

const SUFFIXES := ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]


static func fmt(x: float) -> String:
	if is_nan(x) or is_inf(x):
		return "∞"
	var neg := x < 0.0
	var a := absf(x)
	var s: String
	if a < 10.0:
		s = "%.1f" % a
		if s.ends_with(".0"):
			s = s.substr(0, s.length() - 2)
	elif a < 1000.0:
		s = str(int(floor(a)))
	else:
		var tier := int(floor(log(a) / log(1000.0)))
		if tier >= SUFFIXES.size():
			s = "%.2e" % a
		else:
			var v := a / pow(1000.0, tier)
			if v < 10.0:
				s = "%.2f%s" % [v, SUFFIXES[tier]]
			elif v < 100.0:
				s = "%.1f%s" % [v, SUFFIXES[tier]]
			else:
				s = "%d%s" % [int(v), SUFFIXES[tier]]
	return ("-" if neg else "") + s


static func rate(x: float) -> String:
	if absf(x) < 0.005:
		return "±0/s"
	if absf(x) < 10.0:
		return ("+" if x >= 0 else "-") + ("%.2f" % absf(x)) + "/s"
	return ("+" if x >= 0 else "") + fmt(x) + "/s"


static func pct(x: float) -> String:
	return "%d%%" % int(round(x * 100.0))


static func duration(seconds: float) -> String:
	var s := int(seconds)
	var h := s / 3600
	var m := (s % 3600) / 60
	var sec := s % 60
	if h > 0:
		return "%dh %02dm" % [h, m]
	if m > 0:
		return "%dm %02ds" % [m, sec]
	return "%ds" % sec
