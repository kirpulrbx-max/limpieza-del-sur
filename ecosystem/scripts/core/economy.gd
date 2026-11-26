class_name Economy
extends RefCounted
## Utilidades de coste y nombres de recursos.

const RESOURCES := ["water", "light", "oxygen", "essence", "seeds", "pollen", "pearls"]

const NAMES := {
	"water": "Agua", "light": "Luz", "oxygen": "Oxígeno", "essence": "Esencia",
	"seeds": "Semillas", "pollen": "Polen", "pearls": "Perlas", "ecos": "Ecos",
}

const COLORS := {
	"water": Color(0.25, 0.65, 1.0), "light": Color(1.0, 0.86, 0.3), "oxygen": Color(0.55, 0.95, 1.0),
	"essence": Color(0.45, 1.0, 0.55), "seeds": Color(0.85, 0.65, 0.35), "pollen": Color(1.0, 0.75, 0.25),
	"pearls": Color(0.95, 0.9, 1.0), "ecos": Color(0.8, 0.6, 1.0), "biodiv": Color(1.0, 0.5, 0.75),
}


static func scaled_cost(base: Dictionary, growth: float, level: int) -> Dictionary:
	var out := {}
	var m := pow(growth, level)
	for k in base:
		out[k] = ceil(float(base[k]) * m)
	return out


static func cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k in cost:
		parts.append("%s %s" % [NumFmt.fmt(cost[k]), NAMES.get(k, k)])
	return ", ".join(parts)
