class_name GlassPanel
extends PanelContainer
## Panel de cristal con banda de brillo superior (estilo Aero).

@export var gloss := 0.16


func _draw() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, gloss)
	var r := 14
	var style := get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		r = (style as StyleBoxFlat).corner_radius_top_left
	sb.corner_radius_top_left = r
	sb.corner_radius_top_right = r
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	draw_style_box(sb, Rect2(Vector2(2, 2), Vector2(size.x - 4, minf(size.y * 0.42, 60.0))))
