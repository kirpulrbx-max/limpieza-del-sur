extends Node
## Prueba de juego automatizada con renderizado real (no headless):
##   godot -- --autotest --shots=/ruta/capturas --save=user://autotest.json
## Usa los mismos caminos de código que el jugador: rayo de interacción, E, menú y
## modo construcción. Verifica el "primer objetivo" y guarda capturas de pantalla.

var world: Node
var shots_dir := ""
var failures := 0
var _n := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
	if shots_dir != "":
		DirAccess.make_dir_recursive_absolute(shots_dir)
	SaveManager.settings.offline_enabled = false
	await _wait(0.5)
	await _run()
	print("AUTOPLAY: %s (%d fallos)" % ["OK" if failures == 0 else "FALLÓ", failures])
	SaveManager.delete_save()
	get_tree().quit(0 if failures == 0 else 1)


func check(cond: bool, label: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + label)
	if not cond:
		failures += 1


func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if shots_dir == "":
		return
	_n += 1
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%02d_%s.png" % [shots_dir, _n, name])


## Coloca al jugador a `dist` metros del objetivo mirándolo.
func look_at_point(target: Vector3, dist := 2.6, height := 1.6) -> void:
	var p: CharacterBody3D = world.player
	var flat := Vector3(p.global_position.x - target.x, 0, p.global_position.z - target.z)
	if flat.length() < 0.1:
		flat = Vector3(0, 0, 1)
	var pos := target + flat.normalized() * dist
	var iv: Node3D = world.island_at(target)
	if iv:
		var local: Vector3 = iv.to_local(pos)
		pos.y = iv.to_global(Vector3(local.x, iv.layout.height_at(local.x, local.z), local.z)).y + 0.1
	p.teleport(pos, 0.0)
	var eye := pos + Vector3(0, height, 0)
	var dir := (target - eye).normalized()
	p.rotation.y = atan2(-dir.x, -dir.z)
	p._pitch = asin(clampf(dir.y, -1.0, 1.0))
	p.head.rotation.x = p._pitch
	await _wait(0.15)


## Acelera el tiempo de juego hasta que se cumpla cond (o pasen max_game_s segundos simulados).
func _fast_forward(cond: Callable, max_game_s: float) -> void:
	var t0: float = GameState.stats.get("playtime", 0.0)
	Engine.time_scale = 10.0
	while not cond.call() and GameState.stats.get("playtime", 0.0) - t0 < max_game_s:
		await get_tree().process_frame
	Engine.time_scale = 1.0


func interact() -> bool:
	var p = world.player
	p._find_target()
	if p._target == null:
		return false
	p._do_interact()
	return true


func _run() -> void:
	var gs = GameState
	var p = world.player
	world.start_game(false)
	await _wait(1.0)
	await shot("inicio_isla_muerta")

	print("== Fase 2-3: movimiento, agua y semillas")
	var start: Vector3 = p.global_position
	Input.action_press("move_forward")
	for i in 60:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	check(p.global_position.distance_to(start) > 1.0, "el jugador se mueve en primera persona (%.1f m)" % p.global_position.distance_to(start))
	check(p.is_on_floor(), "el jugador está sobre el terreno")
	var origin: Node3D = world.islands["origin"]
	var pond_pt: Vector3 = origin.to_global(Vector3(1.0, origin.layout.water_level(), 1.0))
	await look_at_point(pond_pt, 4.2)
	await shot("mirando_estanque")
	var got := 0
	for i in 12:
		if interact():
			got += 1
		await _wait(0.05)
	check(gs.res["water"] >= 10.0, "recoger agua del estanque con E (%s)" % NumFmt.fmt(gs.res["water"]))
	var seeds: Array = world.phenomena.items.filter(func(it): return it.kind == "seed")
	check(seeds.size() > 0, "hay semillas flotantes en la isla")
	if seeds.size() > 0:
		await look_at_point(seeds[0].global_position, 2.2, 1.2)
		interact()
		await _wait(0.5)
	check(gs.res["seeds"] >= 1.0, "recoger una semilla")

	print("== Fase 3-4: plantar, regar, crecer y producir")
	var plot: Node3D = origin.plots[0]
	await look_at_point(plot.global_position, 2.4)
	await shot("parcela")
	check(interact(), "interactuar con la parcela")
	check(gs.plants.size() == 1, "se planta el Helecho Burbuja")
	await _wait(0.3)
	var pv: Node3D = world.plant_views.values()[0]
	await look_at_point(pv.global_position + Vector3(0, 0.4, 0), 2.4)
	check(p.prompt.contains("Regar"), "el brote pide riego: «%s»" % p.prompt.split("\n")[0])
	interact()
	check(gs.plants[0].watered, "regar el brote")
	gs.add_res("light", 30.0)
	gs.add_res("water", 40.0)
	await _fast_forward(func(): return gs.plants[0].mature, 60.0)
	check(gs.plants[0].mature, "la planta madura")
	await _wait(0.5)
	check(gs.rates["essence"] > 0.0, "genera esencia automáticamente (%s)" % NumFmt.rate(gs.rates["essence"]))
	await look_at_point(pv.global_position + Vector3(0, 0.5, 0), 2.8)
	await shot("primera_planta")

	print("== Fase 6-7: mejora desde el menú")
	gs.add_res("essence", 20.0)
	world.hud.open_menu("upgrades")
	await _wait(0.4)
	await shot("menu_mejoras")
	var bought := false
	for b in world.hud.menu.find_children("*", "Button", true, false):
		if b.text == "Mejorar" and not b.disabled:
			b.pressed.emit()
			bought = true
			break
	check(bought and gs.stats.get("upgrades_bought", 0.0) >= 1.0, "comprar una mejora con el botón del menú")
	for tab in ["tech", "species", "inventory", "map", "stats", "rebirth", "settings"]:
		world.hud.open_menu(tab)
		await _wait(0.3)
		await shot("menu_" + tab)
	world.hud.menu.visible = false

	print("== Fase 5-8: ecosistema, estructuras, fauna y expansión")
	var v0: float = gs.vitality
	gs.add_res("essence", 3000.0)
	gs.stats["essence_run"] = 3000.0
	gs.tick(0.2)
	for t in [&"condensation", &"optics", &"botany", &"fauna", &"automation"]:
		gs.add_res("oxygen", 100.0)
		check(gs.research(t), "investigar %s" % t)
	gs.res["essence"] = 5000.0
	check(gs.buy_upgrade(&"expansion"), "expandir la Isla Origen")
	await _wait(0.5)
	check(origin.plots.size() == gs.plot_count(&"origin"), "aparecen las nuevas parcelas (%d)" % origin.plots.size())
	gs.res["seeds"] = 20.0
	gs.selected_species = &"lily"
	for i in range(1, origin.plots.size()):
		gs.res["water"] = 100.0
		gs.res["light"] = 100.0
		gs.plant(&"origin", i, &"lily" if i % 2 == 0 else &"fern")
		gs.water_plant(int(gs.plants[-1].id))
	# Construir usando el modo construcción real del jugador
	await look_at_point(origin.to_global(Vector3(0, 0, 13.0)), 6.0)
	p._pitch = -0.6
	p.head.rotation.x = p._pitch
	p.enter_build(&"condenser")
	await _wait(0.3)
	await shot("modo_construccion")
	p._update_build()
	var before: int = gs.structures.size()
	if p._ghost_valid:
		var iv: Node3D = world.islands[String(p._ghost_island)]
		gs.build(p.build_type, p._ghost_island, iv.to_local(p._ghost_pos), 0.0)
	check(gs.structures.size() == before + 1, "colocar un condensador en modo construcción (%s)" % p.build_error)
	p.exit_build()
	for st in [&"prism", &"seeder", &"collector", &"nest"]:
		var placed := false
		for i in 72:
			var a := TAU * i / 72.0
			var wp: Vector3 = origin.surface_point(Vector2(cos(a), sin(a)) * (12.0 + (i % 3)))
			if world.placement_error(st, &"origin", wp, Vector3.UP) == "":
				placed = gs.build(st, &"origin", origin.to_local(wp), a)
				break
		check(placed, "colocar %s en un sitio válido" % st)
	await _fast_forward(func(): return false, 80.0)
	gs.res["essence"] = 5000.0
	gs.res["oxygen"] = 200.0
	check(gs.introduce_fauna(&"butterfly"), "introducir mariposas de vidrio")
	await _fast_forward(func(): return false, 30.0)
	check(gs.vitality > v0 + 0.2, "el ecosistema cambia visualmente: vitalidad %s -> %s" % [NumFmt.pct(v0), NumFmt.pct(gs.vitality)])
	gs.time_of_day = 0.42
	await look_at_point(origin.surface_point(Vector2(0, 0)) + Vector3(0, 0.8, 0), 11.0, 2.2)
	await _wait(1.0)
	await shot("ecosistema_vivo")
	gs.time_of_day = 0.78
	await _wait(1.5)
	await shot("atardecer")
	gs.time_of_day = 0.95
	await _wait(1.5)
	await shot("noche")
	gs.time_of_day = 0.45

	print("== Fase 8: puente a la Isla Cristalina")
	gs.res["essence"] = 1e5
	gs.res["light"] = 100.0
	gs.stats["essence_run"] = 1e5
	gs.tick(0.2)
	check(gs.research(&"bridge_crystal"), "investigar el puente de luz")
	await _wait(2.5)
	check(world.bridges.has("crystal"), "aparece el puente")
	var b: Node3D = world.bridges["crystal"]
	p.teleport(b.global_position + Vector3(0, 0.3, 0) - b.global_transform.basis.z * -8.0, 0.0)
	p.look_at(world.islands["crystal"].global_position + Vector3(0, 1.5, 0), Vector3.UP)
	p.rotation.x = 0
	p.rotation.z = 0
	p._pitch = -0.05
	p.head.rotation.x = p._pitch
	await _wait(0.8)
	await shot("puente_isla_cristalina")
	var target: Vector3 = world.islands["crystal"].surface_point(Vector2(0, 0)) + Vector3(0, 0.5, 0)
	p.teleport(target, 0.0)
	await _wait(1.2)
	check(gs.islands_visited.has("crystal"), "visitar la Isla Cristalina")
	await shot("isla_cristalina")

	print("== Fase 10: guardar y cargar")
	var n_plants: int = gs.plants.size()
	var n_struct: int = gs.structures.size()
	check(SaveManager.save_game(true), "guardar partida")
	gs.new_game()
	gs.world_reset.emit()
	await _wait(0.3)
	check(world.plant_views.size() == 0, "el mundo se vacía al empezar de nuevo")
	check(SaveManager.load_game(false), "cargar partida")
	await _wait(0.5)
	check(gs.plants.size() == n_plants and world.plant_views.size() == n_plants, "plantas restauradas en el mundo (%d)" % world.plant_views.size())
	check(world.structure_views.size() == n_struct, "estructuras restauradas en el mundo (%d)" % world.structure_views.size())
	world.respawn_player()
	await _wait(0.8)
	await shot("partida_cargada")
	print("  FPS aproximados: %d" % Engine.get_frames_per_second())
