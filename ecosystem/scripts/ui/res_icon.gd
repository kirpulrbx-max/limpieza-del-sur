class_name ResIcon
extends Control
## Icono vectorial de recurso dibujado por código (orbe brillante + glifo).

@export var kind := "water"


func _init(k: String = "water", s: float = 26.0) -> void:
	kind = k
	custom_minimum_size = Vector2(s, s)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c: Color = Economy.COLORS.get(kind, Color.WHITE)
	var r := minf(size.x, size.y) * 0.5
	var ctr := size * 0.5
	draw_circle(ctr, r, c.darkened(0.35))
	draw_circle(ctr, r * 0.88, c)
	draw_circle(ctr + Vector2(0, -r * 0.35), r * 0.55, Color(1, 1, 1, 0.28))
	var w := Color(1, 1, 1, 0.95)
	var s := r * 0.5
	match kind:
		"water":
			var pts := PackedVector2Array()
			for i in 13:
				var a := PI * i / 12.0
				pts.append(ctr + Vector2(cos(a) * s * 0.75, sin(a) * s * 0.75 + s * 0.25))
			pts.append(ctr + Vector2(0, -s * 1.1))
			draw_colored_polygon(pts, w)
		"light":
			draw_circle(ctr, s * 0.55, w)
			for i in 8:
				var a := TAU * i / 8.0
				draw_line(ctr + Vector2(cos(a), sin(a)) * s * 0.8, ctr + Vector2(cos(a), sin(a)) * s * 1.15, w, 2.0)
		"oxygen":
			draw_arc(ctr + Vector2(-s * 0.3, s * 0.15), s * 0.55, 0, TAU, 16, w, 2.0)
			draw_arc(ctr + Vector2(s * 0.45, -s * 0.35), s * 0.32, 0, TAU, 12, w, 2.0)
		"essence":
			var leaf := PackedVector2Array()
			for i in 11:
				var t := float(i) / 10.0
				leaf.append(ctr + Vector2(-s + 2.0 * s * t, -sin(PI * t) * s * 0.7))
			for i in 11:
				var t := 1.0 - float(i) / 10.0
				leaf.append(ctr + Vector2(-s + 2.0 * s * t, sin(PI * t) * s * 0.7))
			draw_colored_polygon(leaf, w)
		"seeds":
			draw_set_transform(ctr, -0.5, Vector2(0.7, 1.0))
			draw_circle(Vector2.ZERO, s * 0.85, w)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		"pollen":
			for p in [Vector2(-0.4, 0.2), Vector2(0.35, 0.3), Vector2(0.0, -0.4), Vector2(0.45, -0.3), Vector2(-0.35, -0.35)]:
				draw_circle(ctr + p * s * 1.2, s * 0.25, w)
		"pearls":
			draw_circle(ctr, s * 0.7, w)
			draw_circle(ctr + Vector2(-s * 0.25, -s * 0.25), s * 0.2, c)
		"biodiv":
			for i in 5:
				var a := TAU * i / 5.0
				draw_circle(ctr + Vector2(cos(a), sin(a)) * s * 0.55, s * 0.38, w)
			draw_circle(ctr, s * 0.3, c.darkened(0.2))
		"ecos":
			for i in 3:
				draw_arc(ctr, s * (0.35 + i * 0.3), i * 1.2, i * 1.2 + PI * 1.4, 12, w, 2.0)
		_:
			draw_circle(ctr, s * 0.5, w)
