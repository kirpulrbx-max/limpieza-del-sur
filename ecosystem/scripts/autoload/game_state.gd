extends Node
## Estado central del juego (modelo). Las escenas 3D y la interfaz son vistas
## que leen este estado y reaccionan a sus señales.

signal resources_changed
signal plant_added(p: Dictionary)
signal plant_removed(pid: int)
signal plant_matured(p: Dictionary)
signal bloom_harvested(p: Dictionary, amount: float)
signal structure_added(s: Dictionary)
signal structure_removed(sid: int)
signal upgrade_bought(id: StringName)
signal tech_unlocked(id: StringName)
signal fauna_changed
signal mission_completed(m: MissionDef)
signal level_up(level: int)
signal island_unlocked(id: StringName)
signal island_changed(id: StringName)
signal notify(text: String, kind: String)
signal world_reset
signal collected(kind: String, amount: float)

const DAY_LENGTH := 360.0
const TICK := 0.2
const WATER_SPROUT_COST := 2.0
const BASE_CAPS := {"water": 100.0, "light": 100.0, "oxygen": 200.0, "pollen": 60.0, "pearls": 40.0}

var running := false
var res := {}
var rates := {}
var gross := {}
var usage := {}
var plants: Array = []
var structures: Array = []
var fauna := {}
var upgrades := {}
var prestige_levels := {}
var techs := {}
var islands_visited := {}
var mission_index := 0
var endless_mission := 0
var stats := {}
var lifetime := {}
var ecos := 0.0
var time_of_day := 0.3
var eco_level := 1
var vitality := 0.0
var vitality_target := 0.0
var balance := 1.0
var biodiversity := 0.0
var plant_satisfaction := 1.0
var fauna_satisfaction := 1.0
var warnings: Array[String] = []
var selected_species: StringName = &"fern"
var next_id := 1
var current_island: StringName = &"origin"

var _acc := 0.0
var _layouts := {}
var _mission_cache: MissionDef = null


func _ready() -> void:
	InputSetup.ensure_actions()
	new_game()
	running = false


func _process(delta: float) -> void:
	if not running:
		return
	stats["playtime"] = stats.get("playtime", 0.0) + delta
	lifetime["playtime"] = lifetime.get("playtime", 0.0) + delta
	_acc += delta
	var steps := 0
	while _acc >= TICK and steps < 10:
		_acc -= TICK
		steps += 1
		tick(TICK)
	if steps > 0:
		resources_changed.emit()
	vitality = lerpf(vitality, vitality_target, clampf(delta * 0.6, 0.0, 1.0))


## Avanza la simulación dt segundos.
func tick(dt: float) -> void:
	EcosystemSim.step(self, dt)
	_update_level()
	_check_missions()


# ======================================================================================
# Partida nueva / renacimiento
# ======================================================================================

func new_game() -> void:
	prestige_levels = {}
	ecos = 0.0
	lifetime = {"essence_total": 0.0, "prestiges": 0.0, "playtime": 0.0, "ecos_earned": 0.0}
	_reset_run(false)


func _reset_run(keep_basic_tech: bool) -> void:
	res = {}
	rates = {}
	gross = {}
	usage = {}
	for k in Economy.RESOURCES:
		res[k] = 0.0
		rates[k] = 0.0
	res["seeds"] = 3.0 * plevel(&"p_seedbank")
	res["essence"] = 200.0 * plevel(&"p_seedbank")
	plants = []
	structures = []
	fauna = {}
	upgrades = {}
	var kept := {}
	if keep_basic_tech:
		for t in DB.techs:
			if t.basic and techs.has(String(t.id)):
				kept[String(t.id)] = true
	techs = kept
	islands_visited = {"origin": true}
	mission_index = 0 if lifetime.get("prestiges", 0.0) == 0.0 else mission_index
	stats = {"playtime": 0.0}
	time_of_day = 0.3
	eco_level = 1
	vitality = 0.0
	vitality_target = 0.0
	balance = 1.0
	biodiversity = 0.0
	warnings = []
	selected_species = &"fern"
	current_island = &"origin"
	_layouts = {}
	_mission_cache = null


# ======================================================================================
# Recursos
# ======================================================================================

func cap(k: String) -> float:
	if k == "seeds":
		return 20.0 + 10.0 * level(&"storage")
	if BASE_CAPS.has(k):
		return BASE_CAPS[k] * pow(1.5, level(&"storage"))
	return INF


## Añade (o resta, si amount < 0) un recurso respetando la capacidad. Devuelve lo aplicado.
func add_res(k: String, amount: float, emit := true) -> float:
	var before: float = res.get(k, 0.0)
	var after := clampf(before + amount, 0.0, cap(k))
	res[k] = after
	var applied := after - before
	if k == "essence" and applied > 0.0:
		stats["essence_run"] = stats.get("essence_run", 0.0) + applied
		lifetime["essence_total"] = lifetime.get("essence_total", 0.0) + applied
	if emit:
		resources_changed.emit()
	return applied


func can_afford(cost: Dictionary) -> bool:
	for k in cost:
		if k == "ecos":
			if ecos < cost[k] - 0.0001:
				return false
		elif res.get(k, 0.0) < cost[k] - 0.0001:
			return false
	return true


func pay(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for k in cost:
		if k == "ecos":
			ecos -= cost[k]
		else:
			res[k] = res.get(k, 0.0) - cost[k]
	resources_changed.emit()
	return true


func add_stat(key: String, amount: float = 1.0) -> void:
	stats[key] = stats.get(key, 0.0) + amount


func give(reward: Dictionary) -> void:
	for k in reward:
		if k == "ecos":
			ecos += reward[k]
		else:
			add_res(k, reward[k], false)
	resources_changed.emit()


# ======================================================================================
# Multiplicadores
# ======================================================================================

func level(id: StringName) -> int:
	return int(upgrades.get(String(id), 0))


func plevel(id: StringName) -> int:
	return int(prestige_levels.get(String(id), 0))


func has_tech(id: StringName) -> bool:
	return id == &"" or techs.has(String(id))


func tool_power() -> float:
	return 1.0 + level(&"tool_power")


func magnet_radius() -> float:
	return 1.6 + 1.5 * level(&"tool_magnet")


func reach() -> float:
	return 4.5 + level(&"tool_reach")


func growth_mult() -> float:
	return (1.0 + 0.2 * level(&"fast_growth")) * (1.0 + 0.25 * plevel(&"p_fastroot"))


func water_eff() -> float:
	return pow(0.92, level(&"deep_roots"))


func light_eff() -> float:
	return pow(0.92, level(&"mirror_leaves"))


func seed_mult() -> float:
	return 1.0 + 0.25 * level(&"seed_rain")


func bloom_speed() -> float:
	return 1.0 + 0.15 * level(&"bloom")


func bloom_value() -> float:
	return 1.0 + 0.25 * level(&"bloom")


func struct_mult() -> float:
	return 1.0 + 0.3 * level(&"struct_boost")


func o2_mult() -> float:
	return 1.0 + 0.25 * level(&"respiration")


func biodiv_mult() -> float:
	return 1.0 + biodiversity * 0.02


func balance_mult() -> float:
	return 0.4 + 0.6 * balance


func prestige_mult() -> float:
	return (1.0 + 0.03 * ecos) * (1.0 + 0.15 * plevel(&"p_resonance"))


func fauna_bonus() -> float:
	var b := 0.0
	var poll := 1.0 + 0.2 * level(&"pollination")
	for fid in fauna:
		var fd: FaunaDef = DB.fauna_def(fid)
		if fd:
			b += fauna[fid] * fd.plant_bonus * poll
	return 1.0 + b


## Multiplicador común (sin fotosíntesis ni fauna): prestigio, biodiversidad, equilibrio.
func essence_mult_base() -> float:
	return prestige_mult() * biodiv_mult() * balance_mult()


## Multiplicador de esencia de la flora.
func essence_mult() -> float:
	return essence_mult_base() * (1.0 + 0.3 * level(&"photosynthesis")) * fauna_bonus()


func offline_efficiency() -> float:
	var e := 0.5 + 0.1 * plevel(&"p_memory")
	if has_tech(&"offline_memory"):
		e += 0.25
	return minf(e, 1.0)


func offline_max_hours() -> float:
	return float(SaveManager.settings.get("offline_hours", 8)) + 2.0 * plevel(&"p_memory")


func daylight() -> float:
	var elev := sin((time_of_day - 0.25) * TAU)
	return clampf(elev * 1.4 + 0.45, 0.15, 1.0)


# ======================================================================================
# Islas y parcelas
# ======================================================================================

func island_radius(id: StringName) -> float:
	var d := DB.island(id)
	var r := d.radius
	if id == &"origin":
		r += 2.4 * level(&"expansion")
	return r


func layout(id: StringName) -> IslandLayout:
	var r := island_radius(id)
	var key := String(id)
	var l: IslandLayout = _layouts.get(key)
	if l == null or not is_equal_approx(l.radius, r):
		l = IslandLayout.new(DB.island(id), r)
		_layouts[key] = l
	return l


func plot_count(id: StringName) -> int:
	var d := DB.island(id)
	var n := d.base_plots
	if id == &"origin":
		n += 4 * level(&"expansion")
	return n


func is_island_unlocked(id: StringName) -> bool:
	var d := DB.island(id)
	return d != null and has_tech(d.unlock_tech)


func plant_at_plot(island: StringName, plot: int) -> Dictionary:
	for p in plants:
		if p.island == String(island) and int(p.plot) == plot:
			return p
	return {}


func find_plant(pid: int) -> Dictionary:
	for p in plants:
		if int(p.id) == pid:
			return p
	return {}


func visit_island(id: StringName) -> void:
	current_island = id
	if not islands_visited.has(String(id)):
		islands_visited[String(id)] = true
		var d := DB.island(id)
		notify.emit("Has llegado a %s — %s" % [d.display_name, d.biome], "good")
		Audio.play("levelup")


# ======================================================================================
# Flora
# ======================================================================================

func plant_full_cost(d: PlantDef) -> Dictionary:
	var c := d.plant_cost.duplicate()
	c["seeds"] = float(d.seed_cost)
	return c


func is_species_unlocked(d: PlantDef) -> bool:
	return has_tech(d.unlock_tech)


## Devuelve "" si se puede plantar, o el motivo si no.
func plant_check(island: StringName, plot: int, species: StringName) -> String:
	var d := DB.plant(species)
	if d == null:
		return "Especie desconocida"
	if not is_species_unlocked(d):
		return "%s aún no está investigado" % d.display_name
	if d.allowed_islands.size() > 0 and not d.allowed_islands.has(String(island)):
		return "%s solo crece en: %s" % [d.display_name, ", ".join(d.allowed_islands)]
	if plot < 0 or plot >= plot_count(island):
		return "Parcela no disponible"
	if not plant_at_plot(island, plot).is_empty():
		return "Parcela ocupada"
	if not can_afford(plant_full_cost(d)):
		return "Necesitas " + Economy.cost_text(plant_full_cost(d))
	return ""


func plant(island: StringName, plot: int, species: StringName, auto := false) -> bool:
	if plant_check(island, plot, species) != "":
		return false
	var d := DB.plant(species)
	pay(plant_full_cost(d))
	var p := {
		"id": next_id, "species": String(species), "island": String(island), "plot": plot,
		"growth": 0.0, "health": 1.0, "watered": false, "mature": false, "bloom": 0.0, "seed_acc": 0.0, "auto": auto,
	}
	next_id += 1
	plants.append(p)
	add_stat("plants_planted")
	if auto:
		add_stat("auto_planted")
	plant_added.emit(p)
	return true


func water_plant(pid: int) -> bool:
	var p := find_plant(pid)
	if p.is_empty() or p.watered:
		return false
	if res["water"] < WATER_SPROUT_COST:
		notify.emit("Necesitas %d de agua para regar" % int(WATER_SPROUT_COST), "bad")
		return false
	res["water"] -= WATER_SPROUT_COST
	p.watered = true
	add_stat("sprouts_watered")
	resources_changed.emit()
	return true


func harvest_bloom(pid: int, efficiency := 1.0) -> float:
	var p := find_plant(pid)
	if p.is_empty() or p.bloom < 1.0:
		return 0.0
	var d := DB.plant(p.species)
	var isl := DB.island(p.island)
	var amount := d.essence * 15.0 * essence_mult() * isl.essence_mult * bloom_value() * efficiency
	p.bloom = 0.0
	add_res("essence", amount)
	add_res("oxygen", d.oxygen * 10.0)
	add_stat("blooms_harvested")
	bloom_harvested.emit(p, amount)
	return amount


func uproot(pid: int) -> bool:
	var p := find_plant(pid)
	if p.is_empty():
		return false
	plants.erase(p)
	var d := DB.plant(p.species)
	add_res("seeds", d.seed_cost)
	plant_removed.emit(pid)
	return true


func on_plant_matured(p: Dictionary) -> void:
	add_stat("plants_matured")
	plant_matured.emit(p)


func species_count(species: String) -> int:
	var n := 0
	for p in plants:
		if p.species == species:
			n += 1
	return n


func alive_plants() -> int:
	var n := 0
	for p in plants:
		if p.watered and p.health >= 0.3:
			n += 1
	return n


func mature_plants() -> int:
	var n := 0
	for p in plants:
		if p.mature:
			n += 1
	return n


# ======================================================================================
# Fauna
# ======================================================================================

func capacity(kind: StringName) -> float:
	var c := 0.0
	if kind == &"water":
		for isl in DB.islands:
			if is_island_unlocked(isl.id):
				c += isl.pond_capacity
		return c
	for p in plants:
		if p.mature:
			var d := DB.plant(p.species)
			c += d.habitat * p.health
	for s in structures:
		var sd := DB.structure(s.type)
		if sd:
			c += sd.fauna_capacity
	return c


func fauna_total(kind: StringName) -> float:
	var t := 0.0
	for fid in fauna:
		var fd := DB.fauna_def(fid)
		if fd and fd.habitat_kind == kind:
			t += fauna[fid]
	return t


func fauna_check(fid: StringName) -> String:
	var fd := DB.fauna_def(fid)
	if fd == null:
		return "Especie desconocida"
	if not has_tech(fd.unlock_tech):
		return "Requiere investigación"
	var free := capacity(fd.habitat_kind) - fauna_total(fd.habitat_kind)
	if free < fd.intro_amount:
		return "Hábitat insuficiente (libre: %s)" % NumFmt.fmt(maxf(free, 0.0))
	if not can_afford(fd.intro_cost):
		return "Necesitas " + Economy.cost_text(fd.intro_cost)
	return ""


func introduce_fauna(fid: StringName) -> bool:
	if fauna_check(fid) != "":
		return false
	var fd := DB.fauna_def(fid)
	pay(fd.intro_cost)
	fauna[String(fid)] = fauna.get(String(fid), 0.0) + fd.intro_amount
	add_stat("fauna_introduced")
	fauna_changed.emit()
	notify.emit("%s se han unido al ecosistema" % fd.display_name, "good")
	return true


func on_fauna_extinct(fid: String) -> void:
	var fd := DB.fauna_def(fid)
	notify.emit("¡%s han desaparecido del ecosistema!" % fd.display_name, "bad")
	fauna_changed.emit()


func recompute_biodiversity() -> void:
	var counts := {}
	for p in plants:
		if p.watered and p.health >= 0.3:
			counts[p.species] = counts.get(p.species, 0) + 1
	var b := 0.0
	var distinct := 0
	for sp in counts:
		b += DB.plant(sp).biodiversity * (1.0 + log(float(counts[sp])))
		distinct += 1
	for fid in fauna:
		var n: float = fauna[fid]
		if n >= 1.0:
			b += DB.fauna_def(fid).biodiversity * (1.0 + log(n))
			distinct += 1
	if distinct > 0:
		b *= 1.0 + 0.15 * (distinct - 1)
	biodiversity = b
	var score := mature_plants() * 0.08 + b * 0.025
	vitality_target = (1.0 - exp(-score)) * (0.6 + 0.4 * balance)


# ======================================================================================
# Estructuras
# ======================================================================================

func structure_count(type: String) -> int:
	var n := 0
	for s in structures:
		if s.type == type:
			n += 1
	return n


func structure_cost(type: StringName) -> Dictionary:
	var sd := DB.structure(type)
	return Economy.scaled_cost(sd.cost, sd.cost_growth, structure_count(String(type)))


func structure_check(type: StringName) -> String:
	var sd := DB.structure(type)
	if sd == null:
		return "Desconocida"
	if not has_tech(sd.unlock_tech):
		return "Requiere investigación"
	if sd.max_count > 0 and structure_count(String(type)) >= sd.max_count:
		return "Máximo alcanzado (%d)" % sd.max_count
	if not can_afford(structure_cost(type)):
		return "Necesitas " + Economy.cost_text(structure_cost(type))
	return ""


func build(type: StringName, island: StringName, local_pos: Vector3, rot: float) -> bool:
	if structure_check(type) != "":
		return false
	pay(structure_cost(type))
	var s := {"id": next_id, "type": String(type), "island": String(island),
		"x": local_pos.x, "y": local_pos.y, "z": local_pos.z, "rot": rot, "timer": 0.0}
	next_id += 1
	structures.append(s)
	add_stat("structures_built")
	add_stat("built_" + String(type))
	structure_added.emit(s)
	return true


func demolish(sid: int) -> bool:
	for s in structures:
		if int(s.id) == sid:
			structures.erase(s)
			var sd := DB.structure(s.type)
			var refund := Economy.scaled_cost(sd.cost, sd.cost_growth, structure_count(s.type))
			for k in refund:
				refund[k] = floor(refund[k] * 0.5)
			give(refund)
			structure_removed.emit(sid)
			return true
	return false


func seeder_action(s: Dictionary) -> void:
	var island := StringName(s.island)
	for p in plants:
		if p.island == s.island and not p.watered:
			if water_plant(int(p.id)):
				return
	var species := selected_species
	var d := DB.plant(species)
	if d == null or not is_species_unlocked(d) or (d.allowed_islands.size() > 0 and not d.allowed_islands.has(s.island)) \
			or not can_afford(plant_full_cost(d)):
		species = &"fern"
	for i in plot_count(island):
		if plant_at_plot(island, i).is_empty():
			plant(island, i, species, true)
			return


func collector_action(s: Dictionary) -> void:
	for p in plants:
		if p.island == s.island and p.bloom >= 1.0:
			harvest_bloom(int(p.id), 0.75)


# ======================================================================================
# Mejoras y tecnología
# ======================================================================================

func upgrade_cost(id: StringName) -> Dictionary:
	var u := DB.upgrade(id)
	var lv := plevel(id) if u.category == &"prestige" else level(id)
	return Economy.scaled_cost(u.cost, u.cost_growth, lv)


func upgrade_check(id: StringName) -> String:
	var u := DB.upgrade(id)
	if u == null:
		return "Desconocida"
	if not has_tech(u.unlock_tech):
		return "Requiere investigación"
	var lv := plevel(id) if u.category == &"prestige" else level(id)
	if u.max_level > 0 and lv >= u.max_level:
		return "Nivel máximo"
	if not can_afford(upgrade_cost(id)):
		return "Necesitas " + Economy.cost_text(upgrade_cost(id))
	return ""


func buy_upgrade(id: StringName) -> bool:
	if upgrade_check(id) != "":
		return false
	var u := DB.upgrade(id)
	pay(upgrade_cost(id))
	if u.category == &"prestige":
		prestige_levels[String(id)] = plevel(id) + 1
	else:
		upgrades[String(id)] = level(id) + 1
		add_stat("upgrades_bought")
	if id == &"expansion":
		island_changed.emit(&"origin")
	upgrade_bought.emit(id)
	resources_changed.emit()
	return true


func tech_check(id: StringName) -> String:
	var t := DB.tech(id)
	if t == null:
		return "Desconocida"
	if has_tech(id):
		return "Investigada"
	for r in t.requires:
		if not has_tech(StringName(r)):
			return "Requiere: " + DB.tech(StringName(r)).display_name
	if eco_level < t.min_level:
		return "Requiere nivel de ecosistema %d" % t.min_level
	if not can_afford(t.cost):
		return "Necesitas " + Economy.cost_text(t.cost)
	return ""


func research(id: StringName) -> bool:
	if tech_check(id) != "":
		return false
	var t := DB.tech(id)
	pay(t.cost)
	techs[String(id)] = true
	add_stat("techs_unlocked")
	tech_unlocked.emit(id)
	notify.emit("Investigado: " + t.display_name, "good")
	for isl in DB.islands:
		if isl.unlock_tech == id:
			island_unlocked.emit(isl.id)
			notify.emit("¡Un puente de luz conecta con %s!" % isl.display_name, "good")
	return true


# ======================================================================================
# Nivel del ecosistema y misiones
# ======================================================================================

static func level_threshold(n: int) -> float:
	if n <= 1:
		return 0.0
	return 50.0 * pow(6.0, n - 2)


func _update_level() -> void:
	var e: float = stats.get("essence_run", 0.0)
	while e >= level_threshold(eco_level + 1):
		eco_level += 1
		level_up.emit(eco_level)
		notify.emit("¡El ecosistema alcanza el nivel %d!" % eco_level, "good")


func level_progress() -> float:
	var a := level_threshold(eco_level)
	var b := level_threshold(eco_level + 1)
	return clampf((stats.get("essence_run", 0.0) - a) / (b - a), 0.0, 1.0)


func current_mission() -> MissionDef:
	if mission_index < DB.missions.size():
		return DB.missions[mission_index]
	# Misiones infinitas generadas tras la historia principal.
	if _mission_cache == null or _mission_cache.id != StringName("endless_%d" % endless_mission):
		var m := MissionDef.new()
		m.id = StringName("endless_%d" % endless_mission)
		var target := 1e5 * pow(3.0, endless_mission)
		m.title = "Expansión vital %d" % (endless_mission + 1)
		m.description = "Genera %s de esencia en este ciclo." % NumFmt.fmt(target)
		m.kind = &"stat"
		m.key = "essence_run"
		m.target = target
		m.reward = {"seeds": 5.0, "pollen": 10.0 * (endless_mission + 1)}
		_mission_cache = m
	return _mission_cache


func mission_value(m: MissionDef) -> float:
	match m.kind:
		&"stat":
			return stats.get(m.key, 0.0) + (lifetime.get(m.key, 0.0) if m.key == "prestiges" else 0.0)
		&"tech":
			return 1.0 if has_tech(StringName(m.key)) else 0.0
		&"fauna":
			return fauna.get(m.key, 0.0)
		&"level":
			return float(eco_level)
		&"biodiv":
			return biodiversity
		&"upgrade":
			return float(level(StringName(m.key)))
		&"structure":
			return float(structure_count(m.key))
		&"plant_species":
			return float(species_count(m.key))
		&"plants_alive":
			return float(alive_plants())
		&"island_visit":
			return 1.0 if islands_visited.has(m.key) else 0.0
	return 0.0


func _check_missions() -> void:
	for i in 3:
		var m := current_mission()
		if mission_value(m) < m.target:
			return
		give(m.reward)
		mission_completed.emit(m)
		notify.emit("Objetivo cumplido: %s  (+%s)" % [m.title, Economy.cost_text(m.reward)], "good")
		Audio.play("mission")
		if mission_index < DB.missions.size():
			mission_index += 1
		else:
			endless_mission += 1


# ======================================================================================
# Renacimiento ecológico
# ======================================================================================

func prestige_gain() -> float:
	return floor(sqrt(stats.get("essence_run", 0.0) / 50000.0))


func prestige_check() -> String:
	if not has_tech(&"rebirth"):
		return "Investiga Renacimiento ecológico"
	if prestige_gain() < 1.0:
		return "Necesitas generar más esencia en este ciclo"
	return ""


func do_prestige() -> bool:
	if prestige_check() != "":
		return false
	var gain := prestige_gain()
	ecos += gain
	lifetime["ecos_earned"] = lifetime.get("ecos_earned", 0.0) + gain
	lifetime["prestiges"] = lifetime.get("prestiges", 0.0) + 1.0
	var keep := plevel(&"p_keeptech") > 0
	_reset_run(keep)
	world_reset.emit()
	notify.emit("Renacimiento: +%s Ecos. El ecosistema renace más fuerte." % NumFmt.fmt(gain), "good")
	return true


# ======================================================================================
# Serialización
# ======================================================================================

func serialize() -> Dictionary:
	return {
		"res": res, "plants": plants, "structures": structures, "fauna": fauna,
		"upgrades": upgrades, "prestige": prestige_levels, "techs": techs,
		"islands_visited": islands_visited, "mission_index": mission_index,
		"endless_mission": endless_mission, "stats": stats, "lifetime": lifetime,
		"ecos": ecos, "time_of_day": time_of_day, "eco_level": eco_level,
		"selected_species": String(selected_species), "next_id": next_id,
		"vitality": vitality,
	}


func deserialize(d: Dictionary) -> void:
	_reset_run(false)
	for k in Economy.RESOURCES:
		res[k] = float(d.get("res", {}).get(k, 0.0))
	plants = []
	for p in d.get("plants", []):
		if DB.plant(p.get("species", "")) == null:
			continue
		plants.append({
			"id": int(p.id), "species": String(p.species), "island": String(p.island), "plot": int(p.plot),
			"growth": float(p.growth), "health": float(p.health), "watered": bool(p.watered),
			"mature": bool(p.mature), "bloom": float(p.get("bloom", 0.0)), "seed_acc": float(p.get("seed_acc", 0.0)),
		})
	structures = []
	for s in d.get("structures", []):
		if DB.structure(s.get("type", "")) == null:
			continue
		structures.append({
			"id": int(s.id), "type": String(s.type), "island": String(s.island),
			"x": float(s.x), "y": float(s.y), "z": float(s.z), "rot": float(s.rot), "timer": float(s.get("timer", 0.0)),
		})
	fauna = {}
	for k in d.get("fauna", {}):
		fauna[String(k)] = float(d.fauna[k])
	upgrades = _int_dict(d.get("upgrades", {}))
	prestige_levels = _int_dict(d.get("prestige", {}))
	techs = {}
	for k in d.get("techs", {}):
		techs[String(k)] = true
	islands_visited = {}
	for k in d.get("islands_visited", {"origin": true}):
		islands_visited[String(k)] = true
	mission_index = int(d.get("mission_index", 0))
	endless_mission = int(d.get("endless_mission", 0))
	stats = d.get("stats", {"playtime": 0.0}).duplicate()
	lifetime = d.get("lifetime", lifetime).duplicate()
	ecos = float(d.get("ecos", 0.0))
	time_of_day = float(d.get("time_of_day", 0.3))
	eco_level = int(d.get("eco_level", 1))
	selected_species = StringName(d.get("selected_species", "fern"))
	next_id = int(d.get("next_id", 1))
	vitality = float(d.get("vitality", 0.0))
	recompute_biodiversity()
	vitality = maxf(vitality, vitality_target * 0.8)
	_update_level()


func _int_dict(src: Dictionary) -> Dictionary:
	var out := {}
	for k in src:
		out[String(k)] = int(src[k])
	return out
