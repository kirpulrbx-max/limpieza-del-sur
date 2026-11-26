extends CanvasLayer
## HUD: recursos y producción, nivel del ecosistema, objetivo, avisos, mira con
## indicaciones, barra de herramientas, notificaciones, título y diálogos.

const MENU_SCRIPT := preload("res://scripts/ui/menu.gd")

var world: Node
var root: Control
var menu: Control
var title: Control
var dialog_layer: Control
var _chips := {}
var _level_label: Label
var _level_bar: ProgressBar
var _level_next: Label
var _vital_label: Label
var _balance_label: Label
var _biodiv_label: Label
var _clock_label: Label
var _mission_title: Label
var _mission_desc: Label
var _mission_bar: ProgressBar
var _mission_value: Label
var _mission_reward: Label
var _warnings: VBoxContainer
var _prompt: Label
var _remove_bar: ProgressBar
var _hotbar_label: Label
var _hotbar_cost: Label
var _toasts: VBoxContainer
var _fps: Label
var _crosshair: Control
var _hud_root: Control
var _refresh := 0.0
var _mission_shown: StringName = &""


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Aero.theme()
	add_child(root)
	_hud_root = Control.new()
	_hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hud_root)
	_build_resource_bar()
	_build_eco_panel()
	_build_mission_panel()
	_build_center()
	_build_hotbar()
	_build_toasts()
	menu = Control.new()
	menu.set_script(MENU_SCRIPT)
	menu.hud = self
	root.add_child(menu)
	menu.visible = false
	dialog_layer = Control.new()
	dialog_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dialog_layer)
	GameState.notify.connect(toast)
	GameState.mission_completed.connect(func(_m): _pulse(_mission_title))
	SaveManager.offline_report.connect(_on_offline_report)
	GameState.level_up.connect(func(l): _show_banner("Nivel %d del ecosistema" % l))


func is_blocking() -> bool:
	return menu.visible or (title != null and title.visible) or dialog_layer.get_child_count() > 0


func _process(delta: float) -> void:
	_update_mouse()
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.1
		_update_values()
	var p = world.player if world else null
	_hud_root.visible = GameState.running and not SaveManager.settings.get("hide_hud", false)
	if p:
		if p.build_mode:
			_prompt.text = ""
			var sd := DB.structure(p.build_type)
			_hotbar_label.text = "CONSTRUIR · %s" % sd.display_name
			_hotbar_cost.text = "%s   ·   %s\n[Clic] colocar  [R] rotar  [Rueda] cambiar  [B / Clic der.] salir" % [
				Economy.cost_text(GameState.structure_cost(p.build_type)), p.build_error if p.build_error != "" else "Ubicación válida"]
			_hotbar_cost.add_theme_color_override("font_color", Aero.BAD if p.build_error != "" else Aero.GOOD)
		else:
			_prompt.text = p.prompt
			_prompt.add_theme_color_override("font_color", Aero.WARN if p.prompt_error else Aero.TEXT)
			var d := DB.plant(GameState.selected_species)
			_hotbar_label.text = "SEMILLA · %s" % d.display_name
			_hotbar_cost.text = "%s   ·   [Q / Rueda] cambiar especie   [B] construir" % Economy.cost_text(GameState.plant_full_cost(d))
			_hotbar_cost.add_theme_color_override("font_color", Aero.TEXT if GameState.can_afford(GameState.plant_full_cost(d)) else Aero.WARN)
		_remove_bar.visible = p.remove_progress > 0.0
		_remove_bar.value = p.remove_progress
	_fps.visible = SaveManager.settings.get("show_fps", false)
	if _fps.visible:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()


func _unhandled_input(event: InputEvent) -> void:
	if not GameState.running:
		return
	if dialog_layer.get_child_count() > 0:
		return
	if event.is_action_pressed("menu"):
		toggle_menu("")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("map"):
		toggle_menu("map")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		if menu.visible:
			menu.visible = false
		else:
			if world.player.build_mode:
				world.player.exit_build()
			else:
				open_menu("system")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quicksave"):
		SaveManager.save_game()
	elif event.is_action_pressed("quickload"):
		if SaveManager.load_game(false):
			toast("Partida cargada", "info")
	elif event.is_action_pressed("toggle_hud"):
		SaveManager.settings["hide_hud"] = not SaveManager.settings.get("hide_hud", false)


func toggle_menu(tab: String) -> void:
	if menu.visible and (tab == "" or menu.current_tab == tab):
		menu.visible = false
	else:
		open_menu(tab)


func open_menu(tab: String) -> void:
	menu.visible = true
	menu.open(tab if tab != "" else menu.current_tab)
	Audio.play("click")


func _update_mouse() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var want := Input.MOUSE_MODE_VISIBLE if (is_blocking() or not GameState.running) else Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode != want:
		Input.mouse_mode = want


# ======================================================================================
# Construcción del HUD
# ======================================================================================

func _build_resource_bar() -> void:
	var panel := Aero.panel(Color(0.05, 0.3, 0.5, 0.55), 16)
	panel.position = Vector2(16, 14)
	_hud_root.add_child(panel)
	var row := Aero.hbox(16)
	panel.add_child(row)
	for k in Economy.RESOURCES:
		var chip := Aero.hbox(6)
		chip.add_child(ResIcon.new(k, 30))
		var col := Aero.vbox(-4)
		var amt := Aero.label("0", 17, Aero.TEXT, true)
		var rate := Aero.label("", 12, Aero.TEXT_DIM)
		col.add_child(amt)
		col.add_child(rate)
		chip.add_child(col)
		chip.tooltip_text = Economy.NAMES[k]
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(chip)
		_chips[k] = {"box": chip, "amount": amt, "rate": rate}


func _build_eco_panel() -> void:
	var panel := Aero.panel(Color(0.05, 0.35, 0.45, 0.58), 16)
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.position = Vector2(-16, 14)
	panel.custom_minimum_size = Vector2(330, 0)
	_hud_root.add_child(panel)
	var col := Aero.vbox(4)
	panel.add_child(col)
	var top := Aero.hbox(8)
	_level_label = Aero.label("Ecosistema · Nivel 1", 18, Aero.TEXT, true)
	top.add_child(_level_label)
	top.add_child(Aero.spacer())
	_clock_label = Aero.label("Día", 14, Aero.TEXT_DIM)
	top.add_child(_clock_label)
	col.add_child(top)
	_level_bar = Aero.bar(Color(0.45, 1.0, 0.6), 12)
	col.add_child(_level_bar)
	_level_next = Aero.label("", 12, Aero.TEXT_DIM)
	col.add_child(_level_next)
	var stats := Aero.hbox(14)
	_vital_label = Aero.label("", 14)
	_balance_label = Aero.label("", 14)
	var bio := Aero.hbox(4)
	bio.add_child(ResIcon.new("biodiv", 18))
	_biodiv_label = Aero.label("", 14)
	bio.add_child(_biodiv_label)
	stats.add_child(_vital_label)
	stats.add_child(_balance_label)
	stats.add_child(bio)
	col.add_child(stats)
	_warnings = Aero.vbox(4)
	_warnings.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_warnings.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_warnings.position = Vector2(-16, 150)
	_warnings.alignment = BoxContainer.ALIGNMENT_END
	_hud_root.add_child(_warnings)


func _build_mission_panel() -> void:
	var panel := Aero.panel(Color(0.08, 0.4, 0.35, 0.55), 16)
	panel.position = Vector2(16, 96)
	panel.custom_minimum_size = Vector2(340, 0)
	_hud_root.add_child(panel)
	var col := Aero.vbox(4)
	panel.add_child(col)
	col.add_child(Aero.label("OBJETIVO", 12, Aero.ACCENT, true))
	_mission_title = Aero.label("", 18, Aero.TEXT, true)
	col.add_child(_mission_title)
	_mission_desc = Aero.label("", 14, Aero.TEXT_DIM)
	_mission_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mission_desc.custom_minimum_size.x = 320
	col.add_child(_mission_desc)
	var row := Aero.hbox(8)
	_mission_bar = Aero.bar(Color(0.5, 0.9, 1.0), 10)
	_mission_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mission_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_mission_bar)
	_mission_value = Aero.label("", 13, Aero.TEXT_DIM)
	row.add_child(_mission_value)
	col.add_child(row)
	_mission_reward = Aero.label("", 12, Aero.GOOD)
	col.add_child(_mission_reward)


func _build_center() -> void:
	_crosshair = Control.new()
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.draw.connect(func():
		_crosshair.draw_arc(Vector2.ZERO, 7.0, 0, TAU, 24, Color(1, 1, 1, 0.85), 1.6, true)
		_crosshair.draw_circle(Vector2.ZERO, 1.8, Color(1, 1, 1, 0.95)))
	_hud_root.add_child(_crosshair)
	_prompt = Aero.label("", 18, Aero.TEXT, true)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.anchor_left = 0.0
	_prompt.anchor_right = 1.0
	_prompt.anchor_top = 0.5
	_prompt.anchor_bottom = 0.5
	_prompt.offset_top = 26
	_prompt.offset_bottom = 90
	_prompt.add_theme_constant_override("outline_size", 6)
	_hud_root.add_child(_prompt)
	_remove_bar = Aero.bar(Aero.BAD, 8)
	_remove_bar.anchor_left = 0.5
	_remove_bar.anchor_right = 0.5
	_remove_bar.anchor_top = 0.5
	_remove_bar.anchor_bottom = 0.5
	_remove_bar.offset_left = -80
	_remove_bar.offset_right = 80
	_remove_bar.offset_top = 96
	_remove_bar.offset_bottom = 104
	_remove_bar.visible = false
	_hud_root.add_child(_remove_bar)


func _build_hotbar() -> void:
	var panel := Aero.panel(Color(0.05, 0.3, 0.5, 0.6), 18)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -340
	panel.offset_right = 340
	panel.offset_top = -92
	panel.offset_bottom = -34
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hud_root.add_child(panel)
	var col := Aero.vbox(2)
	panel.add_child(col)
	_hotbar_label = Aero.label("", 17, Aero.TEXT, true)
	_hotbar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_hotbar_label)
	_hotbar_cost = Aero.label("", 13)
	_hotbar_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_hotbar_cost)
	var hints := Aero.label("[Tab] Menú   [M] Mapa   [E/Clic] Interactuar   [Mayús] Correr   [F5] Guardar   [F1] Ocultar HUD", 13, Aero.TEXT_DIM)
	hints.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hints.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hints.position = Vector2(18, -12)
	_hud_root.add_child(hints)
	_fps = Aero.label("", 13, Aero.TEXT_DIM)
	_fps.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_fps.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_fps.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_fps.position = Vector2(-18, -12)
	_hud_root.add_child(_fps)


func _build_toasts() -> void:
	_toasts = Aero.vbox(6)
	_toasts.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toasts.position = Vector2(-20, -110)
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toasts)


# ======================================================================================
# Actualización
# ======================================================================================

func _update_values() -> void:
	for k in _chips:
		var c: Dictionary = _chips[k]
		var amount: float = GameState.res.get(k, 0.0)
		var cap: float = GameState.cap(k)
		var unlocked: bool = amount > 0.0 or k in ["water", "light", "oxygen", "essence", "seeds"] or GameState.gross.get(k, 0.0) > 0.0
		c.box.visible = unlocked
		c.amount.text = NumFmt.fmt(amount) if is_inf(cap) else "%s/%s" % [NumFmt.fmt(amount), NumFmt.fmt(cap)]
		var full := not is_inf(cap) and amount >= cap - 0.01
		c.amount.add_theme_color_override("font_color", Aero.WARN if full else Aero.TEXT)
		var r: float = GameState.rates.get(k, 0.0)
		c.rate.text = NumFmt.rate(r) if k != "seeds" else ""
		c.rate.add_theme_color_override("font_color", Aero.GOOD if r > 0.005 else (Aero.BAD if r < -0.005 else Aero.TEXT_DIM))
	_level_label.text = "Ecosistema · Nivel %d" % GameState.eco_level
	_level_bar.value = GameState.level_progress()
	_level_next.text = "Siguiente nivel: %s / %s de esencia generada" % [NumFmt.fmt(GameState.stats.get("essence_run", 0.0)), NumFmt.fmt(GameState.level_threshold(GameState.eco_level + 1))]
	_vital_label.text = "Vitalidad %s" % NumFmt.pct(GameState.vitality)
	_balance_label.text = "Equilibrio %s" % NumFmt.pct(GameState.balance)
	_balance_label.add_theme_color_override("font_color", Aero.GOOD if GameState.balance > 0.85 else (Aero.WARN if GameState.balance > 0.6 else Aero.BAD))
	_biodiv_label.text = "%s" % NumFmt.fmt(GameState.biodiversity)
	var tod := GameState.time_of_day
	var hours := int(fposmod(tod * 24.0 + 0.0, 24.0))
	var mins := int(fposmod(tod * 24.0 * 60.0, 60.0))
	_clock_label.text = "%s %02d:%02d" % ["Día" if GameState.daylight() > 0.4 else "Noche", hours, mins]
	var m := GameState.current_mission()
	if m.id != _mission_shown:
		_mission_shown = m.id
		_mission_title.text = m.title
		_mission_desc.text = m.description
		_mission_reward.text = "Recompensa: " + Economy.cost_text(m.reward)
	var v := GameState.mission_value(m)
	_mission_bar.value = clampf(v / m.target, 0.0, 1.0)
	_mission_value.text = "%s / %s" % [NumFmt.fmt(minf(v, m.target)), NumFmt.fmt(m.target)]
	# Avisos de desequilibrio
	var w := GameState.warnings
	while _warnings.get_child_count() < w.size():
		var pill := Aero.panel(Color(0.6, 0.2, 0.15, 0.7), 12)
		pill.add_child(Aero.label("", 14, Color(1, 0.95, 0.9), true))
		_warnings.add_child(pill)
	for i in _warnings.get_child_count():
		var pill: Control = _warnings.get_child(i)
		pill.visible = i < w.size()
		if pill.visible:
			var lbl: Label = pill.get_child(0)
			lbl.text = w[i]
			var severe: bool = not w[i].contains("esperando")
			pill.add_theme_stylebox_override("panel", Aero.flat(Color(0.65, 0.22, 0.15, 0.72) if severe else Color(0.55, 0.45, 0.1, 0.65), Color(1, 1, 1, 0.5), 12))


func toast(text: String, kind := "info") -> void:
	var col: Color = {"good": Color(0.1, 0.5, 0.3, 0.8), "bad": Color(0.6, 0.18, 0.15, 0.8), "warn": Color(0.55, 0.42, 0.08, 0.8)}.get(kind, Color(0.05, 0.32, 0.55, 0.8))
	var p := Aero.panel(col, 12)
	var l := Aero.label(text, 15, Aero.TEXT, true)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 340
	p.add_child(l)
	p.modulate.a = 0.0
	_toasts.add_child(p)
	while _toasts.get_child_count() > 6:
		_toasts.get_child(0).free()
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(3.5 if kind != "good" else 4.5)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)


func _pulse(c: Control) -> void:
	var tw := c.create_tween()
	c.pivot_offset = c.size * 0.5
	tw.tween_property(c, "scale", Vector2(1.12, 1.12), 0.12)
	tw.tween_property(c, "scale", Vector2.ONE, 0.25)


func _show_banner(text: String) -> void:
	var l := Aero.label(text, 42, Color(1, 1, 1), true)
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.3, 0.5, 0.8))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.offset_top = 170
	l.offset_bottom = 240
	l.modulate.a = 0.0
	root.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.4)
	tw.tween_interval(2.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)


# ======================================================================================
# Diálogos y pantalla de título
# ======================================================================================

## Diálogo modal con botones. buttons = [[texto, callable], ...]
func dialog(title_text: String, body: String, buttons: Array) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.1, 0.2, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog_layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var p := Aero.panel(Color(0.05, 0.33, 0.55, 0.92), 18)
	p.custom_minimum_size = Vector2(520, 0)
	center.add_child(p)
	var col := Aero.vbox(12)
	p.add_child(Aero.margin(col, 10))
	col.add_child(Aero.label(title_text, 24, Aero.TEXT, true))
	var b := Aero.label(body, 16, Aero.TEXT_DIM)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size.x = 480
	col.add_child(b)
	var row := Aero.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_END
	for spec in buttons:
		var cb: Callable = spec[1]
		row.add_child(Aero.button(spec[0], func():
			shade.queue_free()
			dialog_layer.remove_child(shade)
			if cb.is_valid():
				cb.call(), 120))
	col.add_child(row)


func _on_offline_report(seconds: float, gains: Dictionary) -> void:
	var lines: PackedStringArray = []
	for k in gains:
		lines.append("%s %s%s" % [Economy.NAMES.get(k, k), "+" if gains[k] > 0 else "", NumFmt.fmt(gains[k])])
	var body := "Tu ecosistema siguió vivo durante %s (eficiencia %s).\n\n%s" % [
		NumFmt.duration(seconds), NumFmt.pct(GameState.offline_efficiency()), "\n".join(lines) if lines.size() > 0 else "Sin cambios."]
	dialog("Mientras estabas fuera", body, [["¡Genial!", Callable()]])


func show_title() -> void:
	title = Control.new()
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(title)
	var grad := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.05, 0.35, 0.7, 0.55))
	g.set_color(1, Color(0.4, 0.85, 1.0, 0.1))
	gt.gradient = g
	gt.fill_from = Vector2(0, 1)
	gt.fill_to = Vector2(0, 0)
	grad.texture = gt
	grad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	title.add_child(grad)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.add_child(center)
	var col := Aero.vbox(14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)
	var t := Aero.label("ECOSYSTEM", 96, Color(1, 1, 1), true)
	t.add_theme_constant_override("outline_size", 14)
	t.add_theme_color_override("font_outline_color", Color(0.0, 0.35, 0.6, 0.7))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	var sub := Aero.label("Haz florecer un ecosistema suspendido en el cielo", 22, Aero.TEXT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size.y = 24
	col.add_child(gap)
	var p := Aero.panel(Color(0.05, 0.33, 0.55, 0.65), 20)
	var bcol := Aero.vbox(10)
	p.add_child(Aero.margin(bcol, 14))
	var box := CenterContainer.new()
	box.add_child(p)
	col.add_child(box)
	if SaveManager.has_save():
		bcol.add_child(Aero.button("Continuar", func(): _start(true), 320))
	bcol.add_child(Aero.button("Nueva partida", func():
		if SaveManager.has_save():
			dialog("¿Nueva partida?", "Se borrará la partida guardada actual.", [["Cancelar", Callable()], ["Empezar de cero", func(): _start(false)]])
		else:
			_start(false), 320))
	bcol.add_child(Aero.button("Salir", func(): get_tree().quit(), 320))
	var help := Aero.label("WASD moverse · Ratón mirar · E / Clic interactuar · Q cambiar semilla · B construir · Tab menú · M mapa", 15, Aero.TEXT_DIM)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(help)


func _start(load_save: bool) -> void:
	title.visible = false
	title.queue_free()
	title = null
	world.start_game(load_save)
	Audio.play("levelup")
