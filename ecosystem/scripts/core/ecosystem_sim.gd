class_name EcosystemSim
extends RefCounted
## Simulación del ecosistema. Funciona solo con datos (sin nodos), así que
## sirve igual para el juego en tiempo real, el progreso offline y los tests.
##
## Cadena: Agua + Luz -> Flora -> Oxígeno + Esencia -> Fauna -> Polen/Perlas/Biodiversidad
## -> multiplicadores. Si falta algún recurso, la salud cae y aparecen efectos negativos.

const NATURAL_LIGHT := 0.5
const NATURAL_WATER := 0.12
const SPROUT_FACTOR := 0.4
const SEEDER_INTERVAL := 6.0
const COLLECTOR_INTERVAL := 1.0


static func step(gs, dt: float) -> void:
	var day: float = gs.daylight()
	var prod := {}
	var cons := {}
	for k in Economy.RESOURCES:
		prod[k] = 0.0
		cons[k] = 0.0

	# --- Fuentes naturales y estructuras -------------------------------------------------
	prod["light"] += NATURAL_LIGHT * day
	prod["water"] += NATURAL_WATER
	var smult: float = gs.struct_mult()
	for s in gs.structures:
		var sd: StructureDef = DB.structure(s.type)
		if sd == null:
			continue
		var isl: IslandDef = DB.island(s.island)
		for k in sd.produce:
			var v: float = sd.produce[k] * smult
			if k == "light":
				v *= (0.35 + 0.65 * day) * isl.light_mult
			elif k == "water":
				v *= isl.water_mult
			prod[k] += v

	# --- Demanda de la flora --------------------------------------------------------------
	var weff: float = gs.water_eff()
	var leff: float = gs.light_eff()
	var need_w := 0.0
	var need_l := 0.0
	for p in gs.plants:
		if not p.watered:
			continue
		var d: PlantDef = DB.plant(p.species)
		var stage := 1.0 if p.mature else SPROUT_FACTOR
		need_w += d.water_use * stage * weff
		need_l += d.light_use * stage * leff

	var avail_w: float = gs.res["water"] + prod["water"] * dt
	var avail_l: float = gs.res["light"] + prod["light"] * dt
	var sat_w := 1.0 if need_w <= 0.0 else clampf(avail_w / (need_w * dt), 0.0, 1.0)
	var sat_l := 1.0 if need_l <= 0.0 else clampf(avail_l / (need_l * dt), 0.0, 1.0)
	var psat := minf(sat_w, sat_l)
	cons["water"] += need_w * psat
	cons["light"] += need_l * psat

	# --- Flora ----------------------------------------------------------------------------
	var air_cap: float = gs.capacity(&"air")
	var air_total: float = gs.fauna_total(&"air")
	var overpop := air_total / maxf(air_cap, 0.001) if air_total > 0.0 else 0.0
	var gmult: float = gs.growth_mult()
	var ess_mult: float = gs.essence_mult()
	var o2m: float = gs.o2_mult()
	var seed_m: float = gs.seed_mult()
	var bloom_sp: float = gs.bloom_speed()
	var seeds_gained := 0.0
	var health_sum := 0.0
	var watered := 0
	var withered := 0
	var unwatered := 0
	for p in gs.plants:
		if not p.watered:
			unwatered += 1
			continue
		var d: PlantDef = DB.plant(p.species)
		var isl: IslandDef = DB.island(p.island)
		watered += 1
		var target := psat
		if overpop > 1.2:
			target = minf(target, 1.0 - minf(0.7, overpop - 1.2))
		var speed := 0.05 if target < p.health else 0.2
		p.health = move_toward(p.health, target, dt * speed)
		var h: float = p.health
		health_sum += h
		if h < 0.3:
			withered += 1
		var f := 1.0
		if not p.mature:
			f = 0.15
			p.growth = minf(1.0, p.growth + dt / d.grow_time * gmult * clampf(h * 1.25, 0.05, 1.0))
			if p.growth >= 1.0:
				p.mature = true
				gs.on_plant_matured(p)
		else:
			if h > 0.5:
				p.seed_acc += d.seed_rate * seed_m * h * dt
				while p.seed_acc >= 1.0:
					p.seed_acc -= 1.0
					seeds_gained += 1.0
			p.bloom = minf(1.0, p.bloom + dt / d.bloom_time * bloom_sp * h)
		prod["essence"] += d.essence * f * h * ess_mult * isl.essence_mult
		prod["oxygen"] += d.oxygen * f * h * o2m

	# --- Fauna ----------------------------------------------------------------------------
	var f_o2 := 0.0
	var f_w := 0.0
	var f_l := 0.0
	var any_fauna := false
	for fid in gs.fauna:
		var n: float = gs.fauna[fid]
		if n <= 0.0:
			continue
		any_fauna = true
		var fd: FaunaDef = DB.fauna_def(fid)
		f_o2 += n * fd.oxygen_use
		f_w += n * fd.water_use
		f_l += n * fd.light_use
	var rem_w := avail_w - need_w * psat * dt
	var rem_l := avail_l - need_l * psat * dt
	var avail_o2: float = gs.res["oxygen"] + prod["oxygen"] * dt
	var fs_o2 := 1.0 if f_o2 <= 0.0 else clampf(avail_o2 / (f_o2 * dt), 0.0, 1.0)
	var fs_w := 1.0 if f_w <= 0.0 else clampf(rem_w / (f_w * dt), 0.0, 1.0)
	var fs_l := 1.0 if f_l <= 0.0 else clampf(rem_l / (f_l * dt), 0.0, 1.0)
	var fsat := minf(fs_o2, minf(fs_w, fs_l))
	cons["oxygen"] += f_o2 * fsat
	cons["water"] += f_w * fsat
	cons["light"] += f_l * fsat
	var fess: float = gs.essence_mult_base()
	for fid in gs.fauna.keys():
		var n: float = gs.fauna[fid]
		if n <= 0.0:
			continue
		var fd: FaunaDef = DB.fauna_def(fid)
		var cap: float = gs.capacity(fd.habitat_kind)
		var total: float = gs.fauna_total(fd.habitat_kind)
		if fsat >= 0.85 and total < cap:
			n += n * fd.repro_rate * dt * (1.0 - total / cap) * fsat
		elif fsat < 0.6:
			n -= (n * 0.05 * (0.6 - fsat) / 0.6 + 0.02) * dt
		if cap <= 0.0:
			n -= (n * 0.05 + 0.05) * dt
		elif total > cap * 1.05:
			n -= n * 0.03 * (total / cap - 1.0) * dt
		if n < 0.5:
			n = 0.0
			gs.on_fauna_extinct(fid)
		gs.fauna[fid] = n
		prod["essence"] += n * fd.essence * fsat * fess
		for k in fd.produce:
			prod[k] += n * float(fd.produce[k]) * fsat

	# --- Aplicar producción y consumo -----------------------------------------------------
	for k in Economy.RESOURCES:
		var delta: float = (prod[k] - cons[k]) * dt
		if delta != 0.0:
			gs.add_res(k, delta, false)
	if seeds_gained > 0.0:
		gs.add_res("seeds", seeds_gained, false)
	for k in Economy.RESOURCES:
		var net: float = prod[k] - cons[k]
		gs.rates[k] = lerpf(gs.rates.get(k, 0.0), net, 0.35)
		gs.gross[k] = prod[k]
		gs.usage[k] = cons[k]

	# --- Indicadores del ecosistema -------------------------------------------------------
	gs.plant_satisfaction = health_sum / watered if watered > 0 else 1.0
	gs.fauna_satisfaction = fsat if any_fauna else 1.0
	var over_factor := clampf(1.0 - maxf(0.0, overpop - 1.0) * 2.0, 0.0, 1.0)
	gs.balance = 0.55 * gs.plant_satisfaction + 0.25 * gs.fauna_satisfaction + 0.2 * over_factor
	var w: Array[String] = []
	if need_w > 0.0 and sat_w < 0.6:
		w.append("Sequía: la flora no recibe agua suficiente")
	if need_l > 0.0 and sat_l < 0.6:
		w.append("Penumbra: falta luz para la fotosíntesis")
	if any_fauna and fs_o2 < 0.6:
		w.append("Asfixia: la fauna necesita más oxígeno")
	if overpop > 1.05:
		w.append("Sobrepoblación: la fauna supera su hábitat")
	if withered > 0:
		w.append("%d planta(s) marchita(s)" % withered)
	if unwatered > 0:
		w.append("%d brote(s) esperando riego" % unwatered)
	gs.warnings = w
	gs.recompute_biodiversity()

	# --- Automatización -------------------------------------------------------------------
	for s in gs.structures:
		if s.type == "seeder":
			s.timer = float(s.get("timer", 0.0)) + dt
			while s.timer >= SEEDER_INTERVAL:
				s.timer -= SEEDER_INTERVAL
				gs.seeder_action(s)
		elif s.type == "collector":
			s.timer = float(s.get("timer", 0.0)) + dt
			if s.timer >= COLLECTOR_INTERVAL:
				s.timer = 0.0
				gs.collector_action(s)

	gs.time_of_day = fposmod(gs.time_of_day + dt / gs.DAY_LENGTH, 1.0)
