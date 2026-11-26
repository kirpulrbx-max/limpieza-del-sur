extends Node
## Pruebas automáticas headless de los sistemas (sin gráficos):
##   godot --headless res://tests/test_runner.tscn
## Recorre la cadena completa: agua -> semilla -> planta -> esencia -> mejora,
## desequilibrios, fauna, automatización, guardado/carga, offline y renacimiento.

var failures := 0
var checks := 0


func _ready() -> void:
	SaveManager.save_path = "user://test_save.json"
	await get_tree().process_frame
	_run()
	print("\n=== %d comprobaciones, %d fallos ===" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("  OK   ", label)
	else:
		failures += 1
		print("  FAIL ", label)


func sim(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		GameState.tick(GameState.TICK)
		t += GameState.TICK


func _run() -> void:
	var gs = GameState
	print("== Formato de números")
	check(NumFmt.fmt(1234.0) == "1.23K", "1234 -> 1.23K (%s)" % NumFmt.fmt(1234.0))
	check(NumFmt.fmt(5.0) == "5", "5 -> 5")
	check(NumFmt.fmt(2.5e9) == "2.50B", "2.5e9 -> 2.50B")

	print("== Datos")
	check(DB.plants.size() >= 4, "4 especies de flora")
	check(DB.fauna.size() >= 3, "3 especies de fauna")
	check(DB.techs.size() >= 10, "árbol tecnológico cargado")
	for t in DB.techs:
		for r in t.requires:
			check(DB.tech(StringName(r)) != null, "requisito válido %s -> %s" % [t.id, r])
	for m in DB.missions:
		check(m.target > 0, "misión %s con objetivo" % m.id)

	print("== Primer bucle de juego")
	gs.new_game()
	gs.running = false
	check(gs.plant(&"origin", 0, &"fern") == false, "no se puede plantar sin semillas")
	gs.add_res("water", 10.0)
	gs.add_stat("water_collected", 10.0)
	gs.add_res("seeds", 1.0)
	gs.add_stat("seeds_collected")
	check(gs.plant(&"origin", 0, &"fern"), "plantar helecho")
	check(gs.res["seeds"] == 0.0 and gs.res["water"] == 5.0, "coste de plantar descontado")
	check(gs.plant(&"origin", 0, &"fern") == false, "parcela ocupada")
	var p: Dictionary = gs.plants[0]
	sim(5.0)
	check(p.growth == 0.0, "sin regar no crece")
	check(gs.water_plant(int(p.id)), "regar brote")
	gs.add_res("light", 20.0)
	sim(35.0)
	check(p.mature, "la planta madura (growth=%.2f)" % p.growth)
	check(gs.res["essence"] > 0.0, "produce esencia automáticamente (%.2f)" % gs.res["essence"])
	check(gs.res["oxygen"] > 0.0, "produce oxígeno")
	check(gs.mission_index >= 5, "misiones iniciales completadas (índice %d)" % gs.mission_index)
	gs.res["essence"] = 100.0
	var before: float = gs.essence_mult()
	check(gs.buy_upgrade(&"photosynthesis"), "comprar Fotosíntesis")
	check(gs.essence_mult() > before * 1.2, "la mejora multiplica la esencia")
	check(gs.level(&"photosynthesis") == 1, "nivel de mejora = 1")

	print("== Tecnología, estructuras y fauna")
	gs.res["essence"] = 1e6
	gs.res["oxygen"] = 500.0
	gs.stats["essence_run"] = 5000.0
	gs.tick(0.2)
	check(gs.eco_level >= 4, "nivel del ecosistema sube con la esencia (nivel %d)" % gs.eco_level)
	check(gs.build(&"condenser", &"origin", Vector3(3, 0, 3), 0.0) == false, "condensador bloqueado sin tecnología")
	check(gs.research(&"condensation"), "investigar Condensación")
	check(gs.build(&"condenser", &"origin", Vector3(3, 0, 3), 0.0), "construir condensador")
	var w0: float = gs.gross["water"]
	gs.tick(0.2)
	check(gs.gross["water"] > w0 + 0.5, "el condensador produce agua")
	check(gs.research(&"optics") and gs.research(&"botany") and gs.research(&"fauna"), "investigar óptica, botánica y fauna")
	gs.res["seeds"] = 10.0
	for i in range(1, 4):
		gs.res["water"] = 100.0
		gs.res["light"] = 100.0
		check(gs.plant(&"origin", i, &"lily"), "plantar lirio en parcela %d" % i)
		gs.water_plant(int(gs.plants[-1].id))
	gs.res["light"] = 100.0
	sim(80.0)
	print("== Desequilibrio")
	var saved_structs: Array = gs.structures
	gs.structures = []
	gs.res["water"] = 0.0
	for i in 60:
		gs.res["water"] = 0.0
		gs.tick(1.0)
	check(p.health < 0.6, "sin agua la planta se marchita (salud %.2f)" % p.health)
	check(gs.balance < 0.9, "el equilibrio cae (%.2f)" % gs.balance)
	check(gs.warnings.size() > 0, "aparece un aviso: %s" % str(gs.warnings))
	gs.structures = saved_structs
	gs.res["water"] = 100.0
	gs.res["light"] = 100.0
	sim(30.0)
	check(p.health > 0.9, "con agua se recupera (salud %.2f)" % p.health)

	check(gs.capacity(&"air") > 2.0, "la flora madura da hábitat (%.1f)" % gs.capacity(&"air"))
	check(gs.introduce_fauna(&"butterfly"), "introducir mariposas")
	gs.res["oxygen"] = 200.0
	sim(30.0)
	check(gs.fauna.get("butterfly", 0.0) >= 2.0, "las mariposas sobreviven/crecen (%.2f)" % gs.fauna.get("butterfly", 0.0))
	check(gs.res["pollen"] > 0.0, "las mariposas producen polen")
	check(gs.biodiversity > 3.0, "biodiversidad calculada (%.1f)" % gs.biodiversity)
	# Asfixia: sin oxígeno la fauna desaparece
	var fsave: float = gs.fauna["butterfly"]
	gs.fauna["butterfly"] = 40.0
	sim(60.0)
	check(gs.fauna["butterfly"] < 40.0, "la sobrepoblación reduce la fauna (%.1f)" % gs.fauna["butterfly"])

	print("== Expansión")
	var pc: int = gs.plot_count(&"origin")
	check(gs.buy_upgrade(&"expansion"), "comprar expansión")
	check(gs.plot_count(&"origin") == pc + 4, "más parcelas (%d)" % gs.plot_count(&"origin"))
	check(gs.layout(&"origin").plot_positions(gs.plot_count(&"origin")).size() == gs.plot_count(&"origin"), "posiciones de parcela suficientes")
	for isl in DB.islands:
		var l: IslandLayout = gs.layout(isl.id)
		check(l.plot_positions(gs.plot_count(isl.id)).size() == gs.plot_count(isl.id), "parcelas en %s" % isl.id)
	gs.upgrades["expansion"] = 5
	check(gs.layout(&"origin").plot_positions(gs.plot_count(&"origin")).size() == gs.plot_count(&"origin"), "parcelas con expansión máxima")
	gs.upgrades["expansion"] = 1

	print("== Automatización")
	check(gs.research(&"automation"), "investigar Automatización I")
	gs.res["seeds"] = 5.0
	gs.res["water"] = 100.0
	var planted_before: int = gs.plants.size()
	check(gs.build(&"seeder", &"origin", Vector3(-3, 0, 3), 0.0), "construir sembrador")
	sim(13.0)
	check(gs.plants.size() > planted_before, "el sembrador planta solo (%d -> %d)" % [planted_before, gs.plants.size()])
	check(gs.build(&"collector", &"origin", Vector3(-3, 0, -3), 0.0), "construir recolector")
	for q in gs.plants:
		if q.mature:
			q.bloom = 1.0
	var blooms: float = gs.stats.get("blooms_harvested", 0.0)
	sim(1.2)
	check(gs.stats.get("blooms_harvested", 0.0) > blooms, "el recolector cosecha floraciones")

	print("== Guardado y carga")
	var snap: Dictionary = gs.serialize()
	check(SaveManager.save_game(true), "guardar en disco")
	var ess: float = gs.res["essence"]
	var nplants: int = gs.plants.size()
	gs.new_game()
	check(gs.plants.size() == 0, "partida nueva vacía")
	check(SaveManager.load_game(false), "cargar desde disco")
	check(gs.plants.size() == nplants, "plantas restauradas (%d)" % gs.plants.size())
	check(absf(gs.res["essence"] - ess) < 0.01, "esencia restaurada")
	check(gs.has_tech(&"automation"), "tecnologías restauradas")
	check(gs.structure_count("seeder") == 1, "estructuras restauradas")

	print("== Progreso offline")
	var e0: float = gs.res["essence"]
	var gains: Dictionary = SaveManager.apply_offline_progress(3600.0)
	check(gs.res["essence"] > e0, "una hora offline genera esencia (+%s)" % NumFmt.fmt(gs.res["essence"] - e0))
	SaveManager.settings.offline_enabled = false
	e0 = gs.res["essence"]
	SaveManager.apply_offline_progress(3600.0)
	check(gs.res["essence"] == e0, "offline desactivado no genera nada")
	SaveManager.settings.offline_enabled = true

	print("== Renacimiento")
	gs.stats["essence_run"] = 200000.0
	check(gs.do_prestige() == false, "renacer requiere la tecnología")
	gs.research(&"bridge_crystal")
	gs.techs["rebirth"] = true
	var gain: float = gs.prestige_gain()
	check(gain >= 1.0, "ganancia de ecos = %s" % gain)
	check(gs.do_prestige(), "renacer")
	check(gs.ecos == gain and gs.plants.size() == 0, "ecos obtenidos y ecosistema reiniciado")
	check(gs.prestige_mult() > 1.0, "bonificación permanente activa")
	check(gs.buy_upgrade(&"p_seedbank"), "comprar mejora permanente")
	SaveManager.delete_save()

	print("== Balance: simulación de 40 min con un jugador modelo")
	_balance_run()


## Jugador modelo: recoge agua y luz, planta en cada parcela libre, compra la mejora más barata.
func _balance_run() -> void:
	var gs = GameState
	gs.new_game()
	var t := 0.0
	var milestones := {}
	var order := [&"condensation", &"optics", &"botany", &"automation", &"fauna", &"respiration", &"aurora",
		&"pollination", &"hydrobiology", &"bridge_crystal", &"offline_memory", &"bridge_lagoon", &"rebirth"]
	while t < 2400.0:
		# 2 recolecciones manuales por segundo de agua y luz mientras se juega
		gs.add_res("water", 2.0 * gs.tool_power() * GameState.TICK)
		gs.add_res("light", 1.0 * gs.tool_power() * GameState.TICK)
		if fmod(t, 20.0) < GameState.TICK:
			gs.add_res("seeds", 1.0 * gs.seed_mult())
		for isl in DB.islands:
			if not gs.is_island_unlocked(isl.id):
				continue
			for i in gs.plot_count(isl.id):
				if gs.plant_at_plot(isl.id, i).is_empty():
					var sp := &"fern"
					if gs.has_tech(&"botany") and gs.can_afford(gs.plant_full_cost(DB.plant(&"lily"))):
						sp = &"lily"
					if gs.plant(isl.id, i, sp):
						gs.water_plant(int(gs.plants[-1].id))
		for q in gs.plants:
			if q.bloom >= 1.0:
				gs.harvest_bloom(int(q.id))
		for tid in order:
			if gs.research(tid):
				milestones["tech " + String(tid)] = t
		for st in [&"condenser", &"prism", &"nest", &"seeder"]:
			if gs.structure_check(st) == "" and gs.structure_count(String(st)) < 8:
				gs.build(st, &"origin", Vector3.ZERO, 0.0)
		if gs.fauna_check(&"butterfly") == "":
			gs.introduce_fauna(&"butterfly")
		var best: StringName = &""
		var best_cost := INF
		for u in DB.run_upgrades():
			if gs.upgrade_check(u.id) == "":
				var c: float = gs.upgrade_cost(u.id).values()[0]
				if c < best_cost:
					best_cost = c
					best = u.id
		if best != &"":
			gs.buy_upgrade(best)
		var lv: int = gs.eco_level
		gs.tick(GameState.TICK)
		if gs.eco_level != lv:
			milestones["nivel %d" % gs.eco_level] = t
		t += GameState.TICK
	var keys := milestones.keys()
	keys.sort_custom(func(a, b): return milestones[a] < milestones[b])
	for k in keys:
		print("    %6s  %s" % [NumFmt.duration(milestones[k]), k])
	print("    Esencia/s final: %s | plantas: %d | biodiv: %.1f | mariposas: %.1f | ecos posibles: %s" % [
		NumFmt.fmt(gs.rates["essence"]), gs.plants.size(), gs.biodiversity, gs.fauna.get("butterfly", 0.0), gs.prestige_gain()])
	check(gs.eco_level >= 5, "en 40 min se alcanza al menos el nivel 5 (nivel %d)" % gs.eco_level)
	check(not milestones.has("nivel 10"), "la progresión no se dispara demasiado rápido")
