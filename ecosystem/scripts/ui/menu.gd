extends Control
## Menú principal del juego (Tab): mejoras, árbol tecnológico, construcción, especies,
## inventario, objetivos, mapa, estadísticas, renacimiento, ajustes y sistema.

const MAP_SCRIPT := preload("res://scripts/ui/map_view.gd")

const TABS := [
	["upgrades", "Mejoras"], ["tech", "Tecnología"], ["build", "Construcción"], ["species", "Especies"],
	["inventory", "Inventario"], ["missions", "Objetivos"], ["map", "Mapa"], ["stats", "Estadísticas"],
	["rebirth", "Renacimiento"], ["settings", "Ajustes"], ["system", "Sistema"],
]

var hud: CanvasLayer
var current_tab := "upgrades"
var _tab_buttons := {}
var _content: VBoxContainer
var _scroll: ScrollContainer
var _header_info: Label
var _refreshers: Array[Callable] = []
var _refresh_t := 0.0
var _dirty := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.12, 0.25, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var win := Aero.panel(Color(0.05, 0.3, 0.5, 0.82), 22)
	win.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win.offset_left = 70
	win.offset_right = -70
	win.offset_top = 40
	win.offset_bottom = -40
	add_child(win)
	var col := Aero.vbox(10)
	win.add_child(Aero.margin(col, 8))
	var header := Aero.hbox(12)
	header.add_child(Aero.label("ECOSYSTEM", 30, Color(1, 1, 1), true))
	_header_info = Aero.label("", 16, Aero.TEXT_DIM)
	_header_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_header_info)
	header.add_child(Aero.spacer())
	header.add_child(Aero.button("Cerrar  [Tab]", func(): visible = false))
	col.add_child(header)
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 6)
	tabs.add_theme_constant_override("v_separation", 6)
	var group := ButtonGroup.new()
	for t in TABS:
		var b := Aero.button(t[1])
		b.toggle_mode = true
		b.button_group = group
		var id: String = t[0]
		b.pressed.connect(func(): open(id))
		tabs.add_child(b)
		_tab_buttons[id] = b
	col.add_child(tabs)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	_content = Aero.vbox(8)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)
	for sig in [GameState.upgrade_bought, GameState.tech_unlocked, GameState.structure_added, GameState.structure_removed,
			GameState.fauna_changed, GameState.mission_completed, GameState.world_reset, GameState.level_up]:
		sig.connect(func(_a = null, _b = null): _dirty = true)


func open(tab: String) -> void:
	current_tab = tab
	if _tab_buttons.has(tab):
		_tab_buttons[tab].button_pressed = true
	_rebuild()
	_scroll.scroll_vertical = 0


func _process(delta: float) -> void:
	if not visible:
		return
	if _dirty:
		_dirty = false
		var sv := _scroll.scroll_vertical
		_rebuild()
		await get_tree().process_frame
		_scroll.scroll_vertical = sv
	_refresh_t -= delta
	if _refresh_t <= 0.0:
		_refresh_t = 0.25
		for r in _refreshers:
			r.call()
		_header_info.text = "Nivel %d · Esencia %s (%s) · Ecos %s" % [GameState.eco_level, NumFmt.fmt(GameState.res.essence),
			NumFmt.rate(GameState.rates.get("essence", 0.0)), NumFmt.fmt(GameState.ecos)]


func _rebuild() -> void:
	for c in _content.get_children():
		c.free()
	_refreshers.clear()
	match current_tab:
		"upgrades":
			_build_upgrades()
		"tech":
			_build_tech()
		"build":
			_build_build()
		"species":
			_build_species()
		"inventory":
			_build_inventory()
		"missions":
			_build_missions()
		"map":
			_build_map()
		"stats":
			_build_stats()
		"rebirth":
			_build_rebirth()
		"settings":
			_build_settings()
		"system":
			_build_system()
	for r in _refreshers:
		r.call()


# --------------------------------------------------------------------------------------
# Utilidades de filas
# --------------------------------------------------------------------------------------

func _section(text: String) -> void:
	var l := Aero.label(text, 20, Aero.ACCENT, true)
	_content.add_child(l)


## Fila con título, descripción, información dinámica y botón de acción.
func _row(title: String, desc: String, info_fn: Callable, btn_text: String, check_fn: Callable, action: Callable, icon := "") -> void:
	var p := Aero.panel(Color(0.08, 0.38, 0.58, 0.55), 14)
	var row := Aero.hbox(12)
	p.add_child(row)
	if icon != "":
		var ic := ResIcon.new(icon, 34)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
	var col := Aero.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(Aero.label(title, 18, Aero.TEXT, true))
	var d := Aero.label(desc, 14, Aero.TEXT_DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(d)
	var info := Aero.label("", 14, Aero.GOOD)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(info)
	row.add_child(col)
	var b: AeroButton = null
	if btn_text != "":
		b = Aero.button(btn_text, func():
			if action.call():
				Audio.play("buy")
			else:
				Audio.play("error")
			_dirty = true, 170)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
	_content.add_child(p)
	_refreshers.append(func():
		if info_fn.is_valid():
			info.text = info_fn.call()
		if b and check_fn.is_valid():
			var err: String = check_fn.call()
			b.disabled = err != ""
			b.tooltip_text = err
			info.add_theme_color_override("font_color", Aero.GOOD if err == "" else Aero.WARN))


func _kv_grid(pairs: Array, cols := 2) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols * 2
	g.add_theme_constant_override("h_separation", 24)
	g.add_theme_constant_override("v_separation", 4)
	for pr in pairs:
		g.add_child(Aero.label(pr[0], 15, Aero.TEXT_DIM))
		var v := Aero.label(str(pr[1]), 15, Aero.TEXT, true)
		g.add_child(v)
	return g


# --------------------------------------------------------------------------------------
# Pestañas
# --------------------------------------------------------------------------------------

func _build_upgrades() -> void:
	var groups := {}
	for u in DB.run_upgrades():
		if not groups.has(u.group):
			groups[u.group] = []
		groups[u.group].append(u)
	for g in groups:
		_section(g)
		for u in groups[g]:
			var id: StringName = u.id
			var locked := not GameState.has_tech(u.unlock_tech)
			var desc: String = u.description
			if locked:
				desc += "  (requiere: %s)" % DB.tech(u.unlock_tech).display_name
			_row(u.display_name, desc,
				func():
					var lv := GameState.level(id)
					var mx := " / %d" % u.max_level if u.max_level > 0 else ""
					return "Nivel %d%s · Coste: %s" % [lv, mx, Economy.cost_text(GameState.upgrade_cost(id))],
				"Mejorar", func(): return GameState.upgrade_check(id), func(): return GameState.buy_upgrade(id), "essence")


func _build_tech() -> void:
	_content.add_child(Aero.label("Investiga para desbloquear especies, estructuras, islas y sistemas. Las flechas indican requisitos.", 15, Aero.TEXT_DIM))
	var tree := Control.new()
	var node_w := 205.0
	var node_h := 150.0
	var gx := 232.0
	var gy := 162.0
	var max_tier := 0
	var max_row := 0
	for t in DB.techs:
		max_tier = maxi(max_tier, t.tier)
		max_row = maxi(max_row, t.row)
	tree.custom_minimum_size = Vector2((max_tier + 1) * gx, (max_row + 1) * gy + 10)
	var centers := {}
	for t in DB.techs:
		centers[String(t.id)] = Vector2(t.tier * gx + node_w * 0.5, t.row * gy + node_h * 0.5)
	tree.draw.connect(func():
		for t in DB.techs:
			for r in t.requires:
				var a: Vector2 = centers[r] + Vector2(node_w * 0.5, 0)
				var b: Vector2 = centers[String(t.id)] - Vector2(node_w * 0.5, 0)
				var done := GameState.has_tech(StringName(r))
				var c := Color(0.5, 1.0, 0.7, 0.9) if done else Color(1, 1, 1, 0.35)
				var mid := (a.x + b.x) * 0.5
				tree.draw_polyline(PackedVector2Array([a, Vector2(mid, a.y), Vector2(mid, b.y), b]), c, 2.5, true)
				tree.draw_circle(b, 4.0, c))
	for t in DB.techs:
		var id: StringName = t.id
		var p := Aero.panel(Color(0.08, 0.38, 0.58, 0.8), 12)
		p.position = Vector2(t.tier * gx, t.row * gy)
		p.custom_minimum_size = Vector2(node_w, node_h)
		p.size = Vector2(node_w, node_h)
		var col := Aero.vbox(2)
		p.add_child(col)
		col.add_child(Aero.label(t.display_name, 15, Aero.TEXT, true))
		var d := Aero.label(t.description, 12, Aero.TEXT_DIM)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(node_w - 24, 0)
		col.add_child(d)
		var info := Aero.label("", 12, Aero.WARN)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.custom_minimum_size = Vector2(node_w - 24, 0)
		col.add_child(info)
		var b := Aero.button("Investigar", func():
			if GameState.research(id):
				Audio.play("levelup")
			else:
				Audio.play("error")
			_dirty = true)
		b.add_theme_font_size_override("font_size", 13)
		col.add_child(b)
		tree.add_child(p)
		_refreshers.append(func():
			var done := GameState.has_tech(id)
			var err := GameState.tech_check(id)
			b.visible = not done
			b.disabled = err != ""
			if done:
				info.text = "✓ Investigada"
				info.add_theme_color_override("font_color", Aero.GOOD)
				p.add_theme_stylebox_override("panel", Aero.flat(Color(0.1, 0.5, 0.35, 0.85), Color(0.7, 1, 0.8, 0.9), 12))
			else:
				info.text = "Coste: %s · Nivel %d" % [Economy.cost_text(t.cost), t.min_level] if err == "" else err
				info.add_theme_color_override("font_color", Aero.GOOD if err == "" else Aero.WARN)
			tree.queue_redraw())
	_content.add_child(tree)


func _build_build() -> void:
	_section("Estructuras")
	_content.add_child(Aero.label("Elige una estructura y colócala en el mundo (también con la tecla B). Mantén X sobre ella para desmantelarla.", 14, Aero.TEXT_DIM))
	for sd in DB.structures:
		var id: StringName = sd.id
		var locked := not GameState.has_tech(sd.unlock_tech)
		var desc: String = sd.description + ("  (requiere: %s)" % DB.tech(sd.unlock_tech).display_name if locked else "")
		_row(sd.display_name, desc,
			func():
				var mx := " / %d" % sd.max_count if sd.max_count > 0 else ""
				return "Construidas: %d%s · Coste: %s" % [GameState.structure_count(String(id)), mx, Economy.cost_text(GameState.structure_cost(id))],
			"Colocar",
			func():
				return GameState.structure_check(id),
			func():
				visible = false
				hud.world.player.enter_build(id)
				return true, "")


func _build_species() -> void:
	_section("Flora")
	for d in DB.plants:
		var id: StringName = d.id
		var unlocked := GameState.is_species_unlocked(d)
		var desc := "%s\nConsumo: %s agua/s, %s luz/s · Produce: %s esencia/s, %s oxígeno/s · Madura en %ds · Hábitat %s" % [
			d.description, d.water_use, d.light_use, d.essence, d.oxygen, int(d.grow_time), d.habitat]
		if d.allowed_islands.size() > 0:
			desc += " · Solo en: " + ", ".join(d.allowed_islands)
		if not unlocked:
			desc += "\nRequiere: " + DB.tech(d.unlock_tech).display_name
		_row(d.display_name, desc,
			func(): return "Plantadas: %d · Coste: %s%s" % [GameState.species_count(String(id)), Economy.cost_text(GameState.plant_full_cost(d)),
				"  · SELECCIONADA" if GameState.selected_species == id else ""],
			"Seleccionar",
			func(): return "" if GameState.is_species_unlocked(d) else "Requiere investigación",
			func():
				GameState.selected_species = id
				return true, "essence")
	_section("Fauna")
	_content.add_child(_kv_grid([
		["Hábitat aéreo", "%s / %s" % [NumFmt.fmt(GameState.fauna_total(&"air")), NumFmt.fmt(GameState.capacity(&"air"))]],
		["Hábitat acuático", "%s / %s" % [NumFmt.fmt(GameState.fauna_total(&"water")), NumFmt.fmt(GameState.capacity(&"water"))]],
	]))
	for fd in DB.fauna:
		var id: StringName = fd.id
		var desc := "%s\nConsume: %s oxígeno/s%s%s por individuo · Produce: %s esencia/s%s · Biodiversidad %s" % [
			fd.description, fd.oxygen_use, (", %s agua/s" % fd.water_use) if fd.water_use > 0 else "", (", %s luz/s" % fd.light_use) if fd.light_use > 0 else "",
			fd.essence, "".join(fd.produce.keys().map(func(k): return ", %s %s/s" % [fd.produce[k], Economy.NAMES[k]])), fd.biodiversity]
		if not GameState.has_tech(fd.unlock_tech):
			desc += "\nRequiere: " + DB.tech(fd.unlock_tech).display_name
		_row(fd.display_name, desc,
			func(): return "Población: %s · Introducir %s cuesta %s" % [NumFmt.fmt(GameState.fauna.get(String(id), 0.0)), NumFmt.fmt(fd.intro_amount), Economy.cost_text(fd.intro_cost)],
			"Introducir", func(): return GameState.fauna_check(id), func(): return GameState.introduce_fauna(id), "biodiv")


func _build_inventory() -> void:
	_section("Recursos")
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	for k in Economy.RESOURCES:
		var p := Aero.panel(Color(0.08, 0.38, 0.58, 0.55), 14)
		p.custom_minimum_size = Vector2(240, 0)
		var row := Aero.hbox(10)
		row.add_child(ResIcon.new(k, 40))
		var col := Aero.vbox(0)
		col.add_child(Aero.label(Economy.NAMES[k], 15, Aero.TEXT_DIM))
		var amt := Aero.label("", 20, Aero.TEXT, true)
		col.add_child(amt)
		var rate := Aero.label("", 13, Aero.TEXT_DIM)
		col.add_child(rate)
		row.add_child(col)
		p.add_child(row)
		grid.add_child(p)
		_refreshers.append(func():
			var c := GameState.cap(k)
			amt.text = NumFmt.fmt(GameState.res[k]) + ("" if is_inf(c) else " / " + NumFmt.fmt(c))
			rate.text = "Producción %s · Consumo %s" % [NumFmt.fmt(GameState.gross.get(k, 0.0)), NumFmt.fmt(GameState.usage.get(k, 0.0))])
	_content.add_child(grid)
	_section("Recolector Aero (herramienta)")
	_content.add_child(_kv_grid([
		["Potencia por recolección", "x%s" % NumFmt.fmt(GameState.tool_power())],
		["Radio del imán", "%s m" % NumFmt.fmt(GameState.magnet_radius())],
		["Alcance", "%s m" % NumFmt.fmt(GameState.reach())],
		["Semilla seleccionada", DB.plant(GameState.selected_species).display_name],
	]))
	_section("Ecosistema")
	var pairs := []
	for d in DB.plants:
		pairs.append([d.display_name, "%d" % GameState.species_count(String(d.id))])
	for sd in DB.structures:
		pairs.append([sd.display_name, "%d" % GameState.structure_count(String(sd.id))])
	for fd in DB.fauna:
		pairs.append([fd.display_name, NumFmt.fmt(GameState.fauna.get(String(fd.id), 0.0))])
	_content.add_child(_kv_grid(pairs, 3))


func _build_missions() -> void:
	_section("Objetivo actual")
	var m := GameState.current_mission()
	_row(m.title, m.description, func():
		var cm := GameState.current_mission()
		return "Progreso: %s / %s · Recompensa: %s" % [NumFmt.fmt(minf(GameState.mission_value(cm), cm.target)), NumFmt.fmt(cm.target), Economy.cost_text(cm.reward)], "", Callable(), Callable())
	_section("Historia del ecosistema")
	for i in DB.missions.size():
		var md: MissionDef = DB.missions[i]
		var done := i < GameState.mission_index
		var l := Aero.label(("✓  " if done else "•  ") + md.title + ("" if done or i == GameState.mission_index else "  (bloqueado)"),
			15, Aero.GOOD if done else (Aero.TEXT if i == GameState.mission_index else Aero.TEXT_DIM))
		_content.add_child(l)


func _build_map() -> void:
	var map := Control.new()
	map.set_script(MAP_SCRIPT)
	map.world = hud.world
	map.custom_minimum_size = Vector2(0, 560)
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(map)


func _build_stats() -> void:
	var s := GameState.stats
	var l := GameState.lifetime
	_section("Ciclo actual")
	_content.add_child(_kv_grid([
		["Tiempo de juego", NumFmt.duration(s.get("playtime", 0.0))], ["Esencia generada", NumFmt.fmt(s.get("essence_run", 0.0))],
		["Agua recogida", NumFmt.fmt(s.get("water_collected", 0.0))], ["Luz recogida", NumFmt.fmt(s.get("light_collected", 0.0))],
		["Semillas recogidas", NumFmt.fmt(s.get("seeds_collected", 0.0))], ["Fenómenos recogidos", NumFmt.fmt(s.get("motes_collected", 0.0))],
		["Plantas sembradas", NumFmt.fmt(s.get("plants_planted", 0.0))], ["Siembras automáticas", NumFmt.fmt(s.get("auto_planted", 0.0))],
		["Plantas maduradas", NumFmt.fmt(s.get("plants_matured", 0.0))], ["Floraciones cosechadas", NumFmt.fmt(s.get("blooms_harvested", 0.0))],
		["Mejoras compradas", NumFmt.fmt(s.get("upgrades_bought", 0.0))], ["Estructuras construidas", NumFmt.fmt(s.get("structures_built", 0.0))],
		["Distancia recorrida", "%s m" % NumFmt.fmt(s.get("distance_walked", 0.0))], ["Islas visitadas", "%d / %d" % [GameState.islands_visited.size(), DB.islands.size()]],
	]))
	_section("Producción y multiplicadores")
	var rows := []
	for k in Economy.RESOURCES:
		rows.append([Economy.NAMES[k], "+%s  -%s  (neto %s)" % [NumFmt.fmt(GameState.gross.get(k, 0.0)), NumFmt.fmt(GameState.usage.get(k, 0.0)), NumFmt.rate(GameState.rates.get(k, 0.0))]])
	rows.append_array([
		["Multiplicador de esencia (flora)", "x%s" % NumFmt.fmt(GameState.essence_mult())],
		["Biodiversidad", "%s (x%s)" % [NumFmt.fmt(GameState.biodiversity), NumFmt.fmt(GameState.biodiv_mult())]],
		["Equilibrio", "%s (x%s)" % [NumFmt.pct(GameState.balance), NumFmt.fmt(GameState.balance_mult())]],
		["Fauna polinizadora", "x%s" % NumFmt.fmt(GameState.fauna_bonus())],
		["Prestigio", "x%s" % NumFmt.fmt(GameState.prestige_mult())],
		["Satisfacción de la flora", NumFmt.pct(GameState.plant_satisfaction)],
		["Satisfacción de la fauna", NumFmt.pct(GameState.fauna_satisfaction)],
		["Vitalidad", NumFmt.pct(GameState.vitality)],
	])
	_content.add_child(_kv_grid(rows, 1))
	_section("Total histórico")
	_content.add_child(_kv_grid([
		["Tiempo total", NumFmt.duration(l.get("playtime", 0.0))], ["Esencia total", NumFmt.fmt(l.get("essence_total", 0.0))],
		["Renacimientos", NumFmt.fmt(l.get("prestiges", 0.0))], ["Ecos obtenidos", NumFmt.fmt(l.get("ecos_earned", 0.0))],
	]))


func _build_rebirth() -> void:
	_section("Renacimiento ecológico")
	var d := Aero.label("Devuelve el ecosistema a su semilla original a cambio de Ecos. Cada Eco da +3% de esencia para siempre y se puede invertir en mejoras permanentes. Se reinician recursos, plantas, estructuras, fauna, mejoras y tecnologías; se conservan Ecos, mejoras permanentes y estadísticas históricas.", 15, Aero.TEXT_DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(d)
	_row("Renacer ahora", "La ganancia crece con la raíz cuadrada de la esencia generada en este ciclo.",
		func(): return "Ecos actuales: %s · Ganarías: %s Ecos" % [NumFmt.fmt(GameState.ecos), NumFmt.fmt(GameState.prestige_gain())],
		"Renacer", func(): return GameState.prestige_check(),
		func():
			hud.dialog("¿Renacimiento ecológico?", "Obtendrás %s Ecos y el ecosistema volverá a empezar." % NumFmt.fmt(GameState.prestige_gain()),
				[["Cancelar", Callable()], ["Renacer", func():
					if GameState.do_prestige():
						hud.world.respawn_player()
						SaveManager.save_game(true)
						Audio.play("levelup")]])
			return true, "ecos")
	_section("Mejoras permanentes")
	for u in DB.prestige_upgrades():
		var id: StringName = u.id
		_row(u.display_name, u.description,
			func():
				var mx := " / %d" % u.max_level if u.max_level > 0 else ""
				return "Nivel %d%s · Coste: %s" % [GameState.plevel(id), mx, Economy.cost_text(GameState.upgrade_cost(id))],
			"Comprar", func(): return GameState.upgrade_check(id), func(): return GameState.buy_upgrade(id), "ecos")


func _slider(label_text: String, key: String, mn: float, mx: float, step: float, fmt_fn: Callable) -> void:
	var row := Aero.hbox(12)
	var l := Aero.label(label_text, 16)
	l.custom_minimum_size.x = 280
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = float(SaveManager.settings[key])
	s.custom_minimum_size.x = 360
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var v := Aero.label(fmt_fn.call(s.value), 16, Aero.TEXT, true)
	s.value_changed.connect(func(val):
		SaveManager.settings[key] = val
		v.text = fmt_fn.call(val)
		SaveManager.save_settings())
	row.add_child(s)
	row.add_child(v)
	_content.add_child(row)


func _check(label_text: String, key: String, on_change: Callable = Callable()) -> void:
	var c := CheckBox.new()
	c.text = label_text
	c.button_pressed = bool(SaveManager.settings[key])
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(func(on):
		SaveManager.settings[key] = on
		SaveManager.save_settings()
		if on_change.is_valid():
			on_change.call())
	_content.add_child(c)


func _option(label_text: String, key: String, values: Array, names: Array) -> void:
	var row := Aero.hbox(12)
	var l := Aero.label(label_text, 16)
	l.custom_minimum_size.x = 280
	row.add_child(l)
	var ob := OptionButton.new()
	ob.focus_mode = Control.FOCUS_NONE
	for i in values.size():
		ob.add_item(names[i], i)
		if values[i] == SaveManager.settings[key]:
			ob.select(i)
	ob.item_selected.connect(func(i):
		SaveManager.settings[key] = values[i]
		SaveManager.save_settings())
	row.add_child(ob)
	_content.add_child(row)


func _build_settings() -> void:
	_section("Controles")
	_slider("Sensibilidad del ratón", "mouse_sensitivity", 0.0005, 0.006, 0.0001, func(v): return "%d" % int(v * 10000))
	_check("Invertir eje vertical", "invert_y")
	_slider("Campo de visión", "fov", 60.0, 100.0, 1.0, func(v): return "%d°" % int(v))
	_section("Audio")
	_slider("Volumen general", "master_volume", 0.0, 1.0, 0.01, func(v): return NumFmt.pct(v))
	_slider("Música y ambiente", "music_volume", 0.0, 1.0, 0.01, func(v): return NumFmt.pct(v))
	_slider("Efectos", "sfx_volume", 0.0, 1.0, 0.01, func(v): return NumFmt.pct(v))
	_section("Gráficos")
	_check("Pantalla completa", "fullscreen")
	_check("Sombras", "shadows", func(): hud.world.env_ctrl.apply_settings())
	_slider("Densidad de hierba (se aplica al reconstruir islas)", "grass_density", 0.2, 1.5, 0.1, func(v): return "x%.1f" % v)
	_content.add_child(Aero.button("Aplicar densidad de hierba ahora", func():
		for iv in hud.world.islands.values():
			iv.rebuild()
		hud.world.rebuild_from_state(), 300))
	_check("Mostrar FPS", "show_fps")
	_section("Progreso")
	_check("Progreso offline activado", "offline_enabled")
	_option("Tiempo offline máximo", "offline_hours", [1, 2, 4, 8, 12, 24], ["1 hora", "2 horas", "4 horas", "8 horas", "12 horas", "24 horas"])
	_option("Autoguardado", "autosave_seconds", [15, 30, 60, 120], ["Cada 15 s", "Cada 30 s", "Cada 60 s", "Cada 2 min"])
	_content.add_child(Aero.label("Eficiencia offline actual: %s · Máximo efectivo: %s h" % [NumFmt.pct(GameState.offline_efficiency()), NumFmt.fmt(GameState.offline_max_hours())], 14, Aero.TEXT_DIM))


func _build_system() -> void:
	_section("Partida")
	var row := Aero.hbox(10)
	row.add_child(Aero.button("Guardar partida", func(): SaveManager.save_game(), 220))
	row.add_child(Aero.button("Cargar partida", func():
		if SaveManager.load_game(false):
			hud.toast("Partida cargada", "info")
			hud.world.respawn_player()
		else:
			hud.toast("No hay partida guardada", "bad"), 220))
	row.add_child(Aero.button("Nueva partida", func():
		hud.dialog("¿Nueva partida?", "Se perderá todo el progreso, incluidos los Ecos.", [["Cancelar", Callable()], ["Borrar y empezar", func():
			visible = false
			hud.world.start_game(false)]]), 220))
	row.add_child(Aero.button("Guardar y salir", func():
		SaveManager.save_game(true)
		get_tree().quit(), 220))
	_content.add_child(row)
	var info := Aero.label("Archivo: %s\nEl juego se autoguarda periódicamente y al cerrar. F5 guarda y F9 carga rápidamente." % ProjectSettings.globalize_path(SaveManager.save_path), 14, Aero.TEXT_DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(info)
	_section("Controles")
	_content.add_child(_kv_grid([
		["WASD / flechas", "Moverse"], ["Ratón", "Mirar"], ["Espacio", "Saltar"], ["Mayús", "Correr"],
		["E / Clic izquierdo", "Interactuar, recoger, plantar, regar, cosechar (mantener en agua y cristales)"],
		["Q / Rueda", "Cambiar especie de semilla"], ["Mantener X", "Arrancar planta / desmantelar estructura"],
		["B", "Modo construcción (R rotar, rueda cambiar, clic derecho salir)"],
		["Tab / I", "Menú"], ["M", "Mapa"], ["Esc", "Sistema / salir del modo construcción"], ["F5 / F9", "Guardado / carga rápida"], ["F1", "Ocultar HUD"],
	], 1))
