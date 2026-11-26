extends Node3D
## Representación 3D de una planta. Lee su estado (crecimiento, salud, floración) de GameState.

var pid := 0
var data: Dictionary
var def: PlantDef
var model: Node3D
var _geoms: Array[GeometryInstance3D] = []
var _asset: Node3D
var _fronds: Array[Node3D] = []
var _drop: Node3D
var _bloom: Node3D
var _bloom_mi: MeshInstance3D
var _scale := 0.0
var _last_health := -1.0
var _last_pulse := -1.0
var _t := 0.0
var _burst: GPUParticles3D


func setup(p: Dictionary) -> void:
	data = p
	pid = int(p.id)
	def = DB.plant(p.species)
	name = "Plant_%d" % pid
	model = Node3D.new()
	add_child(model)
	match def.model:
		&"lily":
			_build_lily()
		&"aurora":
			_build_aurora()
		&"coral":
			_build_coral()
		_:
			_build_fern()
	for c in model.find_children("*", "GeometryInstance3D", true, false):
		_geoms.append(c)
	# Gota: el brote necesita riego
	_drop = Node3D.new()
	ProcMesh.add(_drop, ProcMesh.sphere(0.16, 12), ProcMesh.glass(Color(0.3, 0.7, 1.0, 0.6), 1.2, 0.4), Vector3.ZERO, Vector3(1, 1.3, 1))
	ProcMesh.add(_drop, ProcMesh.cylinder(0.0, 0.11, 0.2, 10), ProcMesh.glass(Color(0.3, 0.7, 1.0, 0.6), 1.2, 0.4), Vector3(0, 0.22, 0))
	_drop.position = Vector3(0, 1.1, 0)
	add_child(_drop)
	# Floración cosechable
	_bloom = Node3D.new()
	_bloom_mi = ProcMesh.add(_bloom, ProcMesh.sphere(0.24, 16), ProcMesh.glass(Color(1.0, 0.85, 0.4, 0.35), 2.0, 1.0, 1.8, 4.0), Vector3.ZERO, Vector3.ONE, Vector3.ZERO, false)
	ProcMesh.add(_bloom, ProcMesh.sphere(0.09, 10), ProcMesh.neon(Color(1.0, 0.95, 0.7), 3.0), Vector3.ZERO, Vector3.ONE, Vector3.ZERO, false)
	add_child(_bloom)
	_burst = GPUParticles3D.new()
	_burst.amount = 30
	_burst.lifetime = 1.2
	_burst.one_shot = true
	_burst.explosiveness = 0.95
	_burst.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 80.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 3.0
	pm.gravity = Vector3(0, 0.5, 0)
	pm.damping_min = 1.5
	pm.damping_max = 2.5
	_burst.process_material = pm
	_burst.draw_pass_1 = ProcMesh.sphere(0.05, 6)
	_burst.material_override = ProcMesh.neon(Color(1.0, 0.95, 0.6), 4.0)
	_burst.position = Vector3(0, 0.8, 0)
	add_child(_burst)
	# Colisión para el rayo de interacción
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.75
	shape.height = _height() * 0.8 + 0.6
	cs.shape = shape
	cs.position = Vector3(0, shape.height * 0.5, 0)
	body.add_child(cs)
	add_child(body)
	_t = randf() * 10.0
	_scale = 0.15 + 0.85 * float(p.growth)
	_apply()


func _height() -> float:
	match def.model:
		&"aurora":
			return 4.5
		&"coral":
			return 2.0
		&"lily":
			return 1.4
	return 1.1


func _process(delta: float) -> void:
	_t += delta
	var target := 0.15 + 0.85 * float(data.growth)
	_scale = move_toward(_scale, target, delta * 0.5)
	_apply()
	_drop.visible = not data.watered
	if _drop.visible:
		_drop.position.y = 0.9 + 0.12 * sin(_t * 3.0)
		_drop.rotation.y += delta
	var ready: bool = data.mature and data.bloom >= 1.0
	_bloom.visible = ready
	if ready:
		_bloom.position = Vector3(0, _height() * _scale + 0.45 + 0.1 * sin(_t * 2.5), 0)


func _apply() -> void:
	model.scale = Vector3.ONE * _scale
	var h: float = data.health if data.watered else 0.75
	if absf(h - _last_health) > 0.01:
		_last_health = h
		for g in _geoms:
			g.set_instance_shader_parameter("health", h)
		# Las hojas se caen cuando la planta se marchita.
		for f in _fronds:
			f.rotation.x = f.get_meta("base_tilt", 0.0) + (1.0 - h) * 0.9
		if _asset:
			AssetLib.apply_health(_asset, h)
			_asset.scale = Vector3(1.0 + (1.0 - h) * 0.15, lerpf(0.65, 1.0, h), 1.0 + (1.0 - h) * 0.15)
	var pulse := 0.0
	if data.mature:
		pulse = 0.25 * float(data.bloom)
	if absf(pulse - _last_pulse) > 0.02:
		_last_pulse = pulse
		for g in _geoms:
			g.set_instance_shader_parameter("pulse", pulse)


# --------------------------------------------------------------------------------------
# Interacción
# --------------------------------------------------------------------------------------

func get_prompt() -> String:
	if not data.watered:
		return "[E] Regar brote de %s  (%d agua)" % [def.display_name, int(GameState.WATER_SPROUT_COST)]
	if data.mature and data.bloom >= 1.0:
		return "[E] Cosechar floración de %s" % def.display_name
	var state := "madura" if data.mature else "creciendo %d%%" % int(data.growth * 100.0)
	var extra := "" if not data.mature else " · floración %d%%" % int(data.bloom * 100.0)
	return "%s · %s · salud %d%%%s" % [def.display_name, state, int(data.health * 100.0), extra]


func get_remove_prompt() -> String:
	return "[mantén X] Arrancar (devuelve %d semilla/s)" % def.seed_cost


func interact(_player: Node, _hit: Vector3) -> void:
	if not data.watered:
		if GameState.water_plant(pid):
			Audio.play("water", 1.2)
		else:
			Audio.play("error")
		return
	if data.mature and data.bloom >= 1.0:
		var got := GameState.harvest_bloom(pid)
		if got > 0.0:
			Audio.play("bloom")
			_burst.restart()


func on_bloom_harvested() -> void:
	_burst.restart()


func remove_action() -> void:
	GameState.uproot(pid)
	Audio.play("pop", 0.7)


# --------------------------------------------------------------------------------------
# Modelos procedurales
# --------------------------------------------------------------------------------------

func _frond(parent: Node3D, mat: Material, yaw: float, tilt: float, length: float, y := 0.05) -> Node3D:
	var pivot := Node3D.new()
	pivot.rotation = Vector3(tilt, yaw, 0)
	pivot.position.y = y
	pivot.set_meta("base_tilt", tilt)
	parent.add_child(pivot)
	ProcMesh.add(pivot, ProcMesh.leaf(), mat, Vector3.ZERO, Vector3(1.0, 1.0, length))
	_fronds.append(pivot)
	return pivot


## Usa un modelo realista de Poly Haven si está disponible (si no, el modelo procedural).
func _use_asset(id: String, height: float) -> bool:
	if not AssetLib.has(id):
		return false
	_asset = AssetLib.instance(id, height)
	model.add_child(_asset)
	return true


func _build_fern() -> void:
	if _use_asset("fern_02", 0.85):
		var bub := ProcMesh.glass(Color(0.7, 1.0, 1.0, 0.1), 0.6, 1.0, 1.6)
		for i in 3:
			var a := TAU * i / 3.0
			ProcMesh.add(model, ProcMesh.sphere(0.08, 10), bub, Vector3(cos(a) * 0.4, 0.85 + i * 0.12, sin(a) * 0.4), Vector3.ONE, Vector3.ZERO, false)
		return
	var mat := ProcMesh.plant_mat(def.color, 0.05, 0.4)
	for i in 8:
		var yaw := TAU * i / 8.0 + randf_range(-0.2, 0.2)
		_frond(model, mat, yaw, randf_range(-0.9, -0.5), randf_range(0.8, 1.1))
	for i in 4:
		_frond(model, mat, TAU * i / 4.0 + 0.4, -1.15, 0.6, 0.1)
	# Burbujas en las puntas: el helecho respira oxígeno
	var bub := ProcMesh.glass(Color(0.7, 1.0, 1.0, 0.1), 0.6, 1.0, 1.6)
	for i in 3:
		var a := TAU * i / 3.0
		ProcMesh.add(model, ProcMesh.sphere(0.08, 10), bub, Vector3(cos(a) * 0.45, 0.75 + i * 0.12, sin(a) * 0.45), Vector3.ONE, Vector3.ZERO, false)


func _build_lily() -> void:
	if _use_asset("anthurium_botany_01", 1.25):
		# Halo prismático: la luz que descompone el lirio.
		ProcMesh.add(model, ProcMesh.sphere(0.09, 12), ProcMesh.neon(def.accent, 2.5), Vector3(0, 1.3, 0), Vector3.ONE, Vector3.ZERO, false)
		ProcMesh.add(model, ProcMesh.sphere(0.32, 18), ProcMesh.glass(Color(def.color, 0.08), 0.9, 1.0, 1.8), Vector3(0, 1.3, 0), Vector3.ONE, Vector3.ZERO, false)
		return
	var stem_mat := ProcMesh.plant_mat(Color(0.3, 0.75, 0.45), 0.0, 0.3)
	ProcMesh.add(model, ProcMesh.cylinder(0.035, 0.05, 1.0, 8), stem_mat, Vector3(0, 0.5, 0))
	_frond(model, stem_mat, 0.3, -0.7, 0.7)
	_frond(model, stem_mat, PI + 0.3, -0.6, 0.6)
	var head := Node3D.new()
	head.position = Vector3(0, 1.0, 0)
	model.add_child(head)
	var petal := ProcMesh.plant_mat(def.color, 0.35, 0.8, 0.02)
	for i in 6:
		var pivot := Node3D.new()
		pivot.rotation = Vector3(-0.35 - (i % 2) * 0.25, TAU * i / 6.0, 0)
		head.add_child(pivot)
		ProcMesh.add(pivot, ProcMesh.leaf(), petal, Vector3.ZERO, Vector3(1.5, 1.0, 0.45))
	ProcMesh.add(head, ProcMesh.sphere(0.08, 12), ProcMesh.neon(def.accent, 2.5), Vector3(0, 0.05, 0))
	ProcMesh.add(head, ProcMesh.sphere(0.2, 16), ProcMesh.glass(Color(def.color, 0.12), 0.8, 1.0), Vector3(0, 0.1, 0), Vector3.ONE, Vector3.ZERO, false)


func _build_aurora() -> void:
	if _use_asset("pachira_aquatica_01", 4.6):
		var orb := ProcMesh.neon(def.accent, 3.0)
		var rng := RandomNumberGenerator.new()
		rng.seed = pid
		for i in 8:
			var a := TAU * i / 8.0 + 0.2
			ProcMesh.add(model, ProcMesh.sphere(0.09, 8), orb, Vector3(cos(a) * 1.3, 2.8 + rng.randf_range(-0.4, 0.6), sin(a) * 1.3), Vector3.ONE, Vector3.ZERO, false)
		return
	var bark := ProcMesh.plant_mat(Color(0.92, 0.94, 0.98), 0.0, 0.1, 0.01)
	ProcMesh.add(model, ProcMesh.cylinder(0.16, 0.32, 3.0, 12), bark, Vector3(0, 1.5, 0))
	var leaves := ProcMesh.plant_mat(def.color, 0.15, 0.6, 0.015)
	var rng := RandomNumberGenerator.new()
	rng.seed = pid
	for i in 5:
		var a := TAU * i / 5.0
		var r := 0.0 if i == 0 else 0.9
		var p := Vector3(cos(a) * r, 3.4 + rng.randf_range(-0.3, 0.5), sin(a) * r)
		ProcMesh.add(model, ProcMesh.sphere(1.0, 20), leaves, p, Vector3.ONE * rng.randf_range(0.75, 1.15))
	var orb := ProcMesh.neon(def.accent, 3.0)
	for i in 7:
		var a := TAU * i / 7.0 + 0.2
		ProcMesh.add(model, ProcMesh.sphere(0.09, 8), orb, Vector3(cos(a) * 1.4, 2.6 + rng.randf_range(-0.2, 0.2), sin(a) * 1.4), Vector3.ONE, Vector3.ZERO, false)
	for i in 3:
		_frond(model, ProcMesh.plant_mat(Color(0.35, 0.8, 0.5), 0.0, 0.4), TAU * i / 3.0, -0.4, 1.0)


func _build_coral() -> void:
	var mat := ProcMesh.plant_mat(def.color, 0.3, 0.6, 0.02)
	var tip := ProcMesh.neon(def.accent, 2.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = pid * 7
	for i in 7:
		var pivot := Node3D.new()
		pivot.rotation = Vector3(rng.randf_range(-0.6, 0.6), rng.randf() * TAU, rng.randf_range(-0.6, 0.6))
		model.add_child(pivot)
		var h := rng.randf_range(0.9, 1.8)
		ProcMesh.add(pivot, ProcMesh.cylinder(0.06, 0.12, 1.0, 8), mat, Vector3(0, h * 0.5, 0), Vector3(1, h, 1))
		ProcMesh.add(pivot, ProcMesh.sphere(0.12, 10), tip, Vector3(0, h, 0))
