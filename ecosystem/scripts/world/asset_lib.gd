class_name AssetLib
extends RefCounted
## Modelos 3D externos (Poly Haven, CC0) en res://assets/models/<id>/<id>.gltf.
## Normaliza su tamaño y ofrece variantes de material para mostrar la salud de las plantas.

const WILT := Color(0.55, 0.42, 0.26)
const BUCKETS := 5

static var _scenes := {}
static var _sizes := {}
static var _mats := {}


static func path(id: String) -> String:
	return "res://assets/models/%s/%s.gltf" % [id, id]


static func has(id: String) -> bool:
	return ResourceLoader.exists(path(id))


static func _scene(id: String) -> PackedScene:
	if not _scenes.has(id):
		_scenes[id] = load(path(id)) if has(id) else null
	return _scenes[id]


## Instancia el modelo con la base en el origen y la altura indicada (en metros).
static func instance(id: String, height: float) -> Node3D:
	var ps := _scene(id)
	if ps == null:
		return null
	var model: Node3D = ps.instantiate()
	var aabb: AABB = _sizes.get(id, AABB())
	if not _sizes.has(id):
		aabb = _bounds(model)
		_sizes[id] = aabb
	var h := maxf(aabb.size.y, 0.001)
	var s := height / h
	var root := Node3D.new()
	root.name = id
	root.add_child(model)
	model.scale = Vector3.ONE * s
	model.position = Vector3(-aabb.get_center().x * s, -aabb.position.y * s, -aabb.get_center().z * s)
	return root


static func _bounds(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var xf := Transform3D()
		var p: Node = m
		while p != null and p != n:
			if p is Node3D:
				xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var b: AABB = xf * m.mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


static func meshes(n: Node) -> Array:
	return n.find_children("*", "MeshInstance3D", true, false)


## Aplica un nivel de salud (0..1) tiñendo los materiales hacia un tono marchito.
## Usa variantes cacheadas por tramos para no duplicar materiales por planta.
static func apply_health(n: Node, health: float) -> void:
	var bucket := clampi(int(round(health * (BUCKETS - 1))), 0, BUCKETS - 1)
	for mi in meshes(n):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var base: Material = m.mesh.surface_get_material(i)
			if not (base is BaseMaterial3D):
				continue
			m.set_surface_override_material(i, _variant(base as BaseMaterial3D, bucket))


static func _variant(base: BaseMaterial3D, bucket: int) -> Material:
	if bucket == BUCKETS - 1:
		return base
	var key := "%d_%d" % [base.get_instance_id(), bucket]
	if not _mats.has(key):
		var v := base.duplicate() as BaseMaterial3D
		var t := 1.0 - float(bucket) / (BUCKETS - 1)
		v.albedo_color = base.albedo_color.lerp(WILT, t * 0.75)
		_mats[key] = v
	return _mats[key]


## Sombras desactivadas y distancia de visibilidad para decoración.
static func set_lod(n: Node, range_end: float, shadows := true) -> void:
	for mi in meshes(n):
		var g := mi as GeometryInstance3D
		g.visibility_range_end = range_end
		g.visibility_range_end_margin = 4.0
		g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if not shadows:
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
