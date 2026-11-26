class_name ProcMesh
extends RefCounted
## Fábrica de geometría procedural y materiales compartidos (cacheados para no duplicar recursos).

static var _cache := {}

const GLASS_SHADER := preload("res://shaders/glass.gdshader")
const PLANT_SHADER := preload("res://shaders/plant.gdshader")


static func _cached(key: String, maker: Callable) -> Variant:
	if not _cache.has(key):
		_cache[key] = maker.call()
	return _cache[key]


# --------------------------------------------------------------------------------------
# Materiales
# --------------------------------------------------------------------------------------

static func glass(tint: Color, glow := 0.4, irid := 0.3, rim := 2.5, pulse := 0.0) -> ShaderMaterial:
	var key := "glass_%s_%s_%s_%s_%s" % [tint.to_html(), glow, irid, rim, pulse]
	return _cached(key, func():
		var m := ShaderMaterial.new()
		m.shader = GLASS_SHADER
		m.set_shader_parameter("tint", tint)
		m.set_shader_parameter("glow", glow)
		m.set_shader_parameter("iridescence", irid)
		m.set_shader_parameter("rim_power", rim)
		m.set_shader_parameter("pulse_speed", pulse)
		return m)


static func plant_mat(color: Color, emission := 0.0, translucency := 0.35, sway := 0.04) -> ShaderMaterial:
	var key := "plant_%s_%s_%s_%s" % [color.to_html(), emission, translucency, sway]
	return _cached(key, func():
		var m := ShaderMaterial.new()
		m.shader = PLANT_SHADER
		m.set_shader_parameter("base_color", color)
		m.set_shader_parameter("emission_strength", emission)
		m.set_shader_parameter("translucency", translucency)
		m.set_shader_parameter("sway", sway)
		return m)


static func gloss(color: Color, rough := 0.15, metal := 0.0, emission := Color.BLACK, emission_energy := 1.0) -> StandardMaterial3D:
	var key := "gloss_%s_%s_%s_%s_%s" % [color.to_html(), rough, metal, emission.to_html(), emission_energy]
	return _cached(key, func():
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = rough
		m.metallic = metal
		m.metallic_specular = 0.7
		m.clearcoat_enabled = metal < 0.5
		m.clearcoat = 0.8
		m.clearcoat_roughness = 0.05
		if emission != Color.BLACK:
			m.emission_enabled = true
			m.emission = emission
			m.emission_energy_multiplier = emission_energy
		return m)


static func white() -> StandardMaterial3D:
	return gloss(Color(0.96, 0.98, 1.0), 0.12)


static func chrome() -> StandardMaterial3D:
	return gloss(Color(0.85, 0.9, 0.95), 0.08, 1.0)


static func neon(color: Color, energy := 2.0) -> StandardMaterial3D:
	var key := "neon_%s_%s" % [color.to_html(), energy]
	return _cached(key, func():
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = color
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = energy
		return m)


static func soil() -> StandardMaterial3D:
	return _cached("soil", func():
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.36, 0.25, 0.18)
		m.roughness = 0.9
		return m)


static func noise_texture(seamless := true, normal := false, freq := 0.02) -> NoiseTexture2D:
	var key := "noise_%s_%s_%s" % [seamless, normal, freq]
	return _cached(key, func():
		var t := NoiseTexture2D.new()
		var n := FastNoiseLite.new()
		n.frequency = freq
		n.fractal_octaves = 4
		t.noise = n
		t.width = 256
		t.height = 256
		t.seamless = seamless
		t.as_normal_map = normal
		t.generate_mipmaps = true
		if normal:
			t.bump_strength = 6.0
		return t)


# --------------------------------------------------------------------------------------
# Mallas
# --------------------------------------------------------------------------------------

## Hoja curvada de longitud 1 a lo largo de +Z, ligeramente arqueada hacia arriba.
static func leaf() -> ArrayMesh:
	return _cached("leaf", func():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var seg := 8
		for i in seg:
			var t0 := float(i) / seg
			var t1 := float(i + 1) / seg
			var a := _leaf_pt(t0, -1.0)
			var b := _leaf_pt(t0, 1.0)
			var c := _leaf_pt(t1, -1.0)
			var d := _leaf_pt(t1, 1.0)
			var mid0 := _leaf_pt(t0, 0.0) + Vector3(0, 0.02, 0)
			var mid1 := _leaf_pt(t1, 0.0) + Vector3(0, 0.02, 0)
			for tri in [[a, mid0, c, 0.0, 0.5, 0.0], [mid0, mid1, c, 0.5, 0.5, 0.0], [mid0, b, mid1, 0.5, 1.0, 0.5], [b, d, mid1, 1.0, 1.0, 0.5]]:
				st.set_uv(Vector2(tri[3], t0))
				st.add_vertex(tri[0])
				st.set_uv(Vector2(tri[4], t1))
				st.add_vertex(tri[1])
				st.set_uv(Vector2(tri[5], t1))
				st.add_vertex(tri[2])
		st.generate_normals()
		return st.commit())


static func _leaf_pt(t: float, side: float) -> Vector3:
	var w := sin(PI * pow(t, 0.8)) * 0.2
	return Vector3(side * w, 0.45 * t - 0.55 * t * t, t)


## Brizna de hierba: triángulo estrecho de 3 segmentos (UV.y = altura relativa).
static func blade() -> ArrayMesh:
	return _cached("blade", func():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var h := 0.55
		var pts := [
			[Vector3(-0.045, 0, 0), Vector3(0.045, 0, 0), 0.0],
			[Vector3(-0.035, h * 0.4, 0.01), Vector3(0.035, h * 0.4, 0.01), 0.4],
			[Vector3(-0.018, h * 0.75, 0.03), Vector3(0.018, h * 0.75, 0.03), 0.75],
		]
		var tip := Vector3(0, h, 0.06)
		for i in 2:
			var p0: Array = pts[i]
			var p1: Array = pts[i + 1]
			_quad(st, p0[0], p0[1], p1[0], p1[1], p0[2], p1[2])
		var last: Array = pts[2]
		st.set_uv(Vector2(0, last[2]))
		st.add_vertex(last[0])
		st.set_uv(Vector2(1, last[2]))
		st.add_vertex(last[1])
		st.set_uv(Vector2(0.5, 1.0))
		st.add_vertex(tip)
		st.generate_normals()
		return st.commit())


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, v0: float, v1: float) -> void:
	st.set_uv(Vector2(0, v0))
	st.add_vertex(a)
	st.set_uv(Vector2(1, v0))
	st.add_vertex(b)
	st.set_uv(Vector2(0, v1))
	st.add_vertex(c)
	st.set_uv(Vector2(1, v0))
	st.add_vertex(b)
	st.set_uv(Vector2(1, v1))
	st.add_vertex(d)
	st.set_uv(Vector2(0, v1))
	st.add_vertex(c)


## Flor pequeña (5 pétalos + centro) para el campo de flores.
static func flower() -> ArrayMesh:
	return _cached("flower", func():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var stem_h := 0.32
		var center := Vector3(0, stem_h, 0)
		for i in 5:
			var a := TAU * i / 5.0
			var dir := Vector3(cos(a), 0.25, sin(a))
			var side := Vector3(-sin(a), 0, cos(a)) * 0.05
			st.set_color(Color(1, 1, 1))
			st.add_vertex(center)
			st.add_vertex(center + dir * 0.11 + side)
			st.add_vertex(center + dir * 0.11 - side)
		# Tallo
		st.set_color(Color(0.3, 0.7, 0.3))
		st.add_vertex(Vector3(-0.01, 0, 0))
		st.add_vertex(Vector3(0.01, 0, 0))
		st.add_vertex(center)
		st.generate_normals()
		return st.commit())


## Prisma hexagonal apuntado (cristal).
static func crystal() -> Mesh:
	return _cached("crystal", func():
		var m := CylinderMesh.new()
		m.top_radius = 0.0
		m.bottom_radius = 0.35
		m.height = 1.0
		m.radial_segments = 6
		m.rings = 1
		return m)


static func sphere(radius: float, segments := 16) -> SphereMesh:
	return _cached("sphere_%s_%s" % [radius, segments], func():
		var m := SphereMesh.new()
		m.radius = radius
		m.height = radius * 2.0
		m.radial_segments = segments
		m.rings = maxi(segments / 2, 4)
		return m)


static func cylinder(top: float, bottom: float, height: float, segments := 16) -> CylinderMesh:
	return _cached("cyl_%s_%s_%s_%s" % [top, bottom, height, segments], func():
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = height
		m.radial_segments = segments
		m.rings = 1
		return m)


static func torus(inner: float, outer: float, segments := 32) -> TorusMesh:
	return _cached("torus_%s_%s_%s" % [inner, outer, segments], func():
		var m := TorusMesh.new()
		m.inner_radius = inner
		m.outer_radius = outer
		m.rings = segments
		m.ring_segments = 8
		return m)


## Crea un MeshInstance3D hijo de parent.
static func add(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, scl := Vector3.ONE, rot := Vector3.ZERO, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	mi.rotation = rot
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi
