class_name Aero
extends RefCounted
## Tema visual "Frutiger Aero" y fábrica de controles reutilizables.

const TEXT := Color(0.97, 0.99, 1.0)
const TEXT_DIM := Color(0.78, 0.9, 1.0, 0.85)
const ACCENT := Color(0.45, 0.95, 1.0)
const GOOD := Color(0.55, 1.0, 0.6)
const BAD := Color(1.0, 0.5, 0.45)
const WARN := Color(1.0, 0.85, 0.4)

static var _theme: Theme
static var _bold: Font


static func font(bold := false) -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Segoe UI", "Frutiger", "Myriad Pro", "Ubuntu", "Noto Sans", "Cantarell", "DejaVu Sans", "Sans-Serif"])
	f.font_weight = 700 if bold else 500
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return f


static func bold() -> Font:
	if _bold == null:
		_bold = font(true)
	return _bold


static func flat(bg: Color, border := Color(1, 1, 1, 0.55), radius := 14, bw := 1, shadow := 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0.0, 0.1, 0.25, 0.25)
	sb.shadow_size = shadow
	sb.shadow_offset = Vector2(0, 3)
	sb.set_content_margin_all(10)
	sb.anti_aliasing = true
	return sb


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 16
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0.02, 0.15, 0.3, 0.55))
	t.set_constant("outline_size", "Label", 3)
	t.set_stylebox("panel", "PanelContainer", flat(Color(0.06, 0.32, 0.52, 0.62)))
	t.set_stylebox("panel", "Panel", flat(Color(0.06, 0.32, 0.52, 0.62)))
	# Botones aqua
	var normal := flat(Color(0.12, 0.6, 0.92, 0.92), Color(1, 1, 1, 0.75), 10, 1, 4)
	normal.set_content_margin_all(8)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	var hover := normal.duplicate()
	hover.bg_color = Color(0.25, 0.75, 1.0, 0.98)
	hover.border_color = Color(1, 1, 1, 1)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.05, 0.42, 0.75, 0.98)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.35, 0.45, 0.55, 0.55)
	disabled.border_color = Color(1, 1, 1, 0.25)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color(1, 1, 1, 0.9)
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(10)
	for cls in ["Button", "OptionButton"]:
		t.set_stylebox("normal", cls, normal)
		t.set_stylebox("hover", cls, hover)
		t.set_stylebox("pressed", cls, pressed)
		t.set_stylebox("disabled", cls, disabled)
		t.set_stylebox("focus", cls, focus)
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, Color.WHITE)
		t.set_color("font_disabled_color", cls, Color(0.85, 0.9, 0.95, 0.6))
		t.set_color("font_outline_color", cls, Color(0.0, 0.2, 0.4, 0.6))
		t.set_constant("outline_size", cls, 3)
		t.set_font("font", cls, bold())
	# Pestañas seleccionadas (toggle)
	var toggled := hover.duplicate()
	toggled.bg_color = Color(0.3, 0.85, 0.55, 0.98)
	t.set_stylebox("hover_pressed", "Button", toggled)
	# Barras de progreso
	var bg := flat(Color(0.0, 0.12, 0.25, 0.55), Color(1, 1, 1, 0.35), 8, 1, 0)
	bg.set_content_margin_all(0)
	var fill := flat(Color(0.35, 0.95, 0.65), Color(1, 1, 1, 0.6), 8, 1, 0)
	fill.set_content_margin_all(0)
	t.set_stylebox("background", "ProgressBar", bg)
	t.set_stylebox("fill", "ProgressBar", fill)
	t.set_color("font_color", "ProgressBar", TEXT)
	# Sliders y casillas
	var track := flat(Color(0.0, 0.15, 0.3, 0.6), Color(1, 1, 1, 0.4), 6, 1, 0)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", track)
	var grab := flat(Color(0.4, 0.9, 1.0), Color(1, 1, 1, 0.9), 6, 1, 0)
	grab.content_margin_top = 4
	grab.content_margin_bottom = 4
	t.set_stylebox("grabber_area", "HSlider", grab)
	t.set_stylebox("grabber_area_highlight", "HSlider", grab)
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", Color.WHITE)
	t.set_color("font_pressed_color", "CheckBox", TEXT)
	t.set_color("font_hover_pressed_color", "CheckBox", Color.WHITE)
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		t.set_stylebox(st, "CheckBox", empty)
	t.set_stylebox("panel", "PopupMenu", flat(Color(0.06, 0.3, 0.5, 0.97)))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_stylebox("panel", "TooltipPanel", flat(Color(0.05, 0.25, 0.45, 0.95), Color(1, 1, 1, 0.6), 8))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	var sgrab := flat(Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.0), 6, 0, 0)
	t.set_stylebox("grabber", "VScrollBar", sgrab)
	t.set_stylebox("grabber_highlight", "VScrollBar", sgrab)
	t.set_stylebox("grabber_pressed", "VScrollBar", sgrab)
	t.set_stylebox("scroll", "VScrollBar", flat(Color(0, 0.1, 0.2, 0.3), Color(0, 0, 0, 0), 6, 0, 0))
	_theme = t
	return t


static func panel(bg := Color(0.06, 0.32, 0.52, 0.62), radius := 14) -> GlassPanel:
	var p := GlassPanel.new()
	p.add_theme_stylebox_override("panel", flat(bg, Color(1, 1, 1, 0.55), radius))
	return p


static func label(text: String, size := 16, color := TEXT, is_bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if is_bold:
		l.add_theme_font_override("font", bold())
	return l


static func button(text: String, cb: Callable = Callable(), min_w := 0.0) -> AeroButton:
	var b := AeroButton.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	if min_w > 0.0:
		b.custom_minimum_size.x = min_w
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


static func bar(color := Color(0.35, 0.95, 0.65), h := 12.0) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.min_value = 0.0
	pb.max_value = 1.0
	pb.step = 0.0
	pb.custom_minimum_size.y = h
	var fill := flat(color, Color(1, 1, 1, 0.6), 8, 1, 0)
	fill.set_content_margin_all(0)
	pb.add_theme_stylebox_override("fill", fill)
	return pb


static func hbox(sep := 8) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


static func vbox(sep := 6) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


static func margin(child: Control, m := 12) -> MarginContainer:
	var mc := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, m)
	mc.add_child(child)
	return mc


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c
