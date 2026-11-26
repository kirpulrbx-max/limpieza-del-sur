extends Node3D
## Fauna visible: cada especie se dibuja con un MultiMesh (barato) y agentes con
## movimiento simple. El número visible sigue a la población simulada (máx. MAX_VISIBLE).

const MAX_VISIBLE := 28
const BUTTERFLY_SHADER := preload("res://shaders/butterfly.gdshader")

var world: Node
var _groups := {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for fd in DB.fauna:
		_groups[String(fd.id)] = _make_group(fd)


func _make_group(fd: FaunaDef) -> Dictionary:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = MAX_VISIBLE
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	match fd.model:
		&"butterfly":
			var q := QuadMesh.new()
			q.size = Vector2(0.5, 0.32)
			q.orientation = PlaneMesh.FACE_Y
			mm.mesh = q
			var m := ShaderMaterial.new()
			m.shader = BUTTERFLY_SHADER
			m.set_shader_parameter("wing_color", Color(fd.color, 0.8))
			mmi.material_override = m
		&"fish":
			mm.mesh = ProcMesh.sphere(0.16, 12)
			mmi.material_override = ProcMesh.gloss(fd.color, 0.15, 0.0, fd.color * 0.4, 0.6)
		&"jelly":
			var hemi := SphereMesh.new()
			hemi.radius = 0.55
			hemi.height = 0.6
			hemi.is_hemisphere = true
			mm.mesh = hemi
			mmi.material_override = ProcMesh.glass(Color(fd.color, 0.3), 1.2, 0.9, 1.6, 2.0)
	add_child(mmi)
	var agents: Array = []
	for i in MAX_VISIBLE:
		agents.append({"pos": Vector3.ZERO, "vel": Vector3.ZERO, "target": Vector3.ZERO, "t": _rng.randf() * 10.0, "init": false,
			"center": Vector3.ZERO, "radius": 1.0, "speed": _rng.randf_range(0.4, 0.9), "height": _rng.randf_range(0.0, 1.0)})
	return {"def": fd, "mm": mm, "agents": agents}


func _process(delta: float) -> void:
	for fid in _groups:
		var g: Dictionary = _groups[fid]
		var pop: float = GameState.fauna.get(fid, 0.0)
		var n := mini(int(ceil(pop)), MAX_VISIBLE)
		var mm: MultiMesh = g.mm
		mm.visible_instance_count = n
		if n == 0:
			continue
		var fd: FaunaDef = g.def
		for i in n:
			var a: Dictionary = g.agents[i]
			match fd.model:
				&"butterfly":
					_butterfly(a, delta)
				&"fish":
					_fish(a, delta)
				&"jelly":
					_jelly(a, delta)
			mm.set_instance_transform(i, a.xf)


func _random_plant_pos() -> Vector3:
	var keys: Array = world.plant_views.keys()
	if keys.is_empty():
		return world.islands["origin"].global_position + Vector3(0, 2, 0)
	var pv: Node3D = world.plant_views[keys[_rng.randi() % keys.size()]]
	return pv.global_position + Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.8, 2.2), _rng.randf_range(-1, 1))


func _butterfly(a: Dictionary, delta: float) -> void:
	a.t += delta
	if not a.init:
		a.init = true
		a.pos = _random_plant_pos()
		a.target = _random_plant_pos()
	var to: Vector3 = a.target - a.pos
	if to.length() < 0.5 or a.t > 8.0:
		a.target = _random_plant_pos()
		a.t = 0.0
	var desired: Vector3 = to.normalized() * 1.6
	desired += Vector3(sin(a.t * 3.1), sin(a.t * 4.3) * 0.8, cos(a.t * 2.7)) * 0.8
	a.vel = a.vel.lerp(desired, clampf(delta * 2.0, 0.0, 1.0))
	a.pos += a.vel * delta
	var fwd: Vector3 = a.vel.normalized() if a.vel.length() > 0.01 else Vector3.FORWARD
	var basis := Basis.looking_at(Vector3(fwd.x, 0, fwd.z).normalized() if absf(fwd.y) < 0.99 else Vector3.FORWARD, Vector3.UP)
	a.xf = Transform3D(basis, a.pos)


func _fish(a: Dictionary, delta: float) -> void:
	if not a.init:
		a.init = true
		var ponds: Array = []
		for isl in world.islands.values():
			if isl.def.pond_radius > 0.0 and GameState.is_island_unlocked(isl.def.id):
				ponds.append(isl)
		var isl = ponds[_rng.randi() % ponds.size()]
		a.center = isl.to_global(Vector3(isl.def.pond_offset.x, isl.layout.water_level() - 0.35, isl.def.pond_offset.y))
		a.radius = isl.def.pond_radius * _rng.randf_range(0.3, 0.75)
	a.t += delta * a.speed
	var ang: float = a.t
	var p: Vector3 = a.center + Vector3(cos(ang) * a.radius, sin(a.t * 2.3) * 0.08 - a.height * 0.3, sin(ang) * a.radius)
	var tangent := Vector3(-sin(ang), 0, cos(ang))
	var basis := Basis.looking_at(tangent, Vector3.UP).scaled(Vector3(0.6, 0.7, 1.6))
	a.xf = Transform3D(basis, p)


func _jelly(a: Dictionary, delta: float) -> void:
	if not a.init:
		a.init = true
		var isls: Array = []
		for isl in world.islands.values():
			if GameState.is_island_unlocked(isl.def.id):
				isls.append(isl)
		var isl = isls[_rng.randi() % isls.size()]
		a.center = isl.global_position + Vector3(0, 6.0 + a.height * 6.0, 0)
		a.radius = isl.layout.radius * _rng.randf_range(0.5, 1.2)
	a.t += delta * a.speed * 0.25
	var pulse := 1.0 + 0.15 * sin(a.t * 12.0)
	var p: Vector3 = a.center + Vector3(cos(a.t) * a.radius, sin(a.t * 3.0) * 1.2, sin(a.t) * a.radius)
	a.xf = Transform3D(Basis().scaled(Vector3(pulse, 1.0 / pulse, pulse)), p)
