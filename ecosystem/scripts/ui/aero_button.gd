class_name AeroButton
extends Button
## Botón brillante con reflejo superior y sonido.


func _ready() -> void:
	mouse_entered.connect(func():
		if not disabled:
			Audio.play("hover"))
	pressed.connect(func(): Audio.play("click"))


func _draw() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.22 if not disabled else 0.06)
	sb.corner_radius_top_left = 9
	sb.corner_radius_top_right = 9
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	draw_style_box(sb, Rect2(Vector2(3, 2), Vector2(size.x - 6, size.y * 0.45)))
