class_name IslandView
extends Node3D
## Isla flotante procedural: terreno, estanque, cristales, parcelas, hierba y cúpula de bloqueo.

const TERRAIN_SHADER := preload("res://shaders/terrain.gdshader")
const WATER_SHADER := preload("res://shaders/water.gdshader")
const GRASS_SHADER := preload("res://shaders/grass.gdshader")
const PLOT_SCRIPT := preload("res://scripts/world/plot_view.gd")
const CRYSTAL_SCRIPT := preload("res://scripts/world/crystal_view.gd")
const POND_SCRIPT := preload("res://scripts/world/pond_view.gd")

var def: IslandDef
var layout: IslandLayout
var terrain_mat: ShaderMaterial
var water_mat: ShaderMaterial
var grass_mat: ShaderMaterial
var grass_mm: MultiMeshInstance3D
var flower_mm: MultiMeshInstance3D
var plots: Array = []
var crystals: Array = []
var pond: Node3D
var dome: Node3D
var content: Node3D
var _grass_total := 0
var _flower_total := 0
var _last_vis := -1.0
var _decor: Array = []
var _verts := PackedVector3Array()
var _faces := PackedVector3Array()


func setup(d: IslandDef) -> void:
	def = d
	name = "Island_%s" % d.id
	position = d.position
	terrain_mat = ShaderMaterial.new()
	terrain_mat.shader = TERRAIN_SHADER
	terrain_mat.set_shader_parameter("grass_dead", d.grass_dead)
	terrain_mat.set_shader_parameter("grass_lush", d.grass_lush)
	terrain_mat.set_shader_parameter("rock_color", d.rock_color)
	terrain_mat.set_shader_parameter("glow_color", d.crystal_color)
	terrain_mat.set_shader_parameter("noise_tex", ProcMesh.noise_texture(true, false, 0.03))
	terrain_mat.set_shader_parameter("pond_center", d.pond_offset)
	if ResourceLoader.exists("res://assets/textures/grass004_color.jpg"):
		terrain_mat.set_shader_parameter("grass_tex", load("res://assets/textures/grass004_color.jpg"))
		terrain_mat.set_shader_parameter("grass_nrm", load("res://assets/textures/grass004_normal.jpg"))
		terrain_mat.set_shader_parameter("rock_tex", load("res://assets/textures/rock035_color.jpg"))
		terrain_mat.set_shader_parameter("rock_nrm", load("res://assets/textures/rock035_normal.jpg"))
		terrain_mat.set_shader_parameter("use_detail", true)
	terrain_mat.set_shader_parameter("pond_radius", d.pond_radius)
	water_mat = ShaderMaterial.new()
	water_mat.shader = WATER_SHADER
	water_mat.set_shader_parameter("normal_a", ProcMesh.noise_texture(true, true, 0.02))
	water_mat.set_shader_parameter("normal_b", ProcMesh.noise_texture(true, true, 0.035))
	grass_mat = ShaderMaterial.new()
	grass_mat.shader = GRASS_SHADER
	grass_mat.set_shader_parameter("dead_color", d.grass_dead)
	grass_mat.set_shader_parameter("lush_color", d.grass_lush)
	rebuild()


func rebuild() -> void:
	if content:
		content.free()
	content = Node3D.new()
	content.name = "Content"
	add_child(content)
	plots.clear()
	crystals.clear()
	layout = GameState.layout(def.id)
	terrain_mat.set_shader_parameter("water_level", layout.water_level())
	_build_terrain()
	if def.pond_radius > 0.0:
		_build_pond()
	_build_crystals()
	_build_plots()
	_build_grass()
	_build_decor()
	update_lock(false)
	_last_vis = -1.0


func surface_point(local_xz: Vector2) -> Vector3:
	return to_global(Vector3(local_xz.x, layout.height_at(local_xz.x, local_xz.y), local_xz.y))


func plot_world_position(index: int) -> Vector3:
	var pos := layout.plot_positions(index + 1)
	if pos.size() <= index:
		return global_position
	return surface_point(pos[index])


func _process(_delta: float) -> void:
	var v := GameState.vitality
	if absf(v - _last_vis) < 0.004:
		return
	_last_vis = v
	terrain_mat.set_shader_parameter("vitality", v)
	grass_mat.set_shader_parameter("vitality", v)
	water_mat.set_shader_parameter("clarity", clampf(v * 1.3, 0.0, 1.0))
	if grass_mm:
		grass_mm.multimesh.visible_instance_count = int(_grass_total * (0.3 + 0.7 * v))
	if flower_mm:
		flower_mm.multimesh.visible_instance_count = int(_flower_total * smoothstep(0.25, 0.95, v))
	for d in _decor:
		d.node.visible = v >= d.threshold


# --------------------------------------------------------------------------------------
# Terreno
# --------------------------------------------------------------------------------------

func _build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nr := 24
	var ns := 80
	var nd := 14
	var rock := FastNoiseLite.new()
	rock.seed = def.noise_seed + 7
	rock.frequency = 0.12
	var depth := layout.radius * 0.95
	# Anillos: 0 = centro, 1..nr = superficie, luego borde redondeado y base rocosa.
	var rings: Array = []
	rings.append([Vector3(0, layout.height_at(0, 0), 0)])
	for i in range(1, nr + 1):
		var ring: Array = []
		var f := float(i) / nr
		for j in ns:
			var a := TAU * j / ns
			var er := layout.edge_radius(a) * f
			var x := cos(a) * er
			var z := sin(a) * er
			ring.append(Vector3(x, layout.height_at(x, z), z))
		rings.append(ring)
	var top: Array = rings[nr]
	var lip: Array = []
	for j in ns:
		var p: Vector3 = top[j]
		lip.append(Vector3(p.x * 1.03, p.y - 0.45, p.z * 1.03))
	rings.append(lip)
	for k in range(1, nd + 1):
		var t := float(k) / nd
		var ring: Array = []
		for j in ns:
			var p: Vector3 = lip[j]
			var a := TAU * j / ns
			var shrink := pow(1.0 - t, 1.35)
			var bump := 1.0 + 0.22 * rock.get_noise_3d(cos(a) * 9.0, t * 12.0, sin(a) * 9.0)
			var y := p.y - t * depth * (1.0 + 0.25 * rock.get_noise_2d(cos(a) * 5.0, sin(a) * 5.0))
			if k == nd:
				ring.append(Vector3(0, lip[0].y - depth * 1.1, 0))
			else:
				ring.append(Vector3(p.x * shrink * bump, y, p.z * shrink * bump))
		rings.append(ring)
	# Vértices
	var index_of: Array = []
	var idx := 0
	_verts = PackedVector3Array()
	_faces = PackedVector3Array()
	for ring in rings:
		var ids: Array = []
		for v in ring:
			st.set_uv(Vector2(v.x, v.z) * 0.1)
			st.add_vertex(v)
			_verts.append(v)
			ids.append(idx)
			idx += 1
		index_of.append(ids)
	# Abanico central
	for j in ns:
		_tri(st, index_of[0][0], index_of[1][j], index_of[1][(j + 1) % ns])
	for r in range(1, rings.size() - 1):
		var a_ids: Array = index_of[r]
		var b_ids: Array = index_of[r + 1]
		for j in ns:
			var j2 := (j + 1) % ns
			_tri(st, a_ids[j], b_ids[j], b_ids[j2])
			_tri(st, a_ids[j], b_ids[j2], a_ids[j2])
	st.generate_normals()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	mi.material_override = terrain_mat
	content.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("island_id", def.id)
	var shape := CollisionShape3D.new()
	# La colisión se genera desde los mismos triángulos (no depende del renderizador).
	var concave := ConcavePolygonShape3D.new()
	concave.set_faces(_faces)
	shape.shape = concave
	body.add_child(shape)
	content.add_child(body)


func _tri(st: SurfaceTool, a: int, b: int, c: int) -> void:
	st.add_index(a)
	st.add_index(b)
	st.add_index(c)
	_faces.append(_verts[a])
	_faces.append(_verts[b])
	_faces.append(_verts[c])


# --------------------------------------------------------------------------------------
# Estanque, cristales y parcelas
# --------------------------------------------------------------------------------------

func _build_pond() -> void:
	pond = Node3D.new()
	pond.set_script(POND_SCRIPT)
	pond.name = "Pond"
	content.add_child(pond)
	var wl := layout.water_level()
	pond.position = Vector3(def.pond_offset.x, wl, def.pond_offset.y)
	pond.setup(self, def.pond_radius, water_mat)


func _build_crystals() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = def.noise_seed * 31
	for p in layout.crystal_positions():
		var c := Node3D.new()
		c.set_script(CRYSTAL_SCRIPT)
		content.add_child(c)
		c.position = Vector3(p.x, layout.height_at(p.x, p.y) - 0.15, p.y)
		c.setup(self, rng.randi())
		crystals.append(c)


func _build_plots() -> void:
	var positions := layout.plot_positions(GameState.plot_count(def.id))
	for i in positions.size():
		var pv := Node3D.new()
		pv.set_script(PLOT_SCRIPT)
		content.add_child(pv)
		var p: Vector2 = positions[i]
		pv.position = Vector3(p.x, layout.height_at(p.x, p.y), p.y)
		pv.setup(self, i)
		plots.append(pv)


# --------------------------------------------------------------------------------------
# Hierba y flores (MultiMesh)
# --------------------------------------------------------------------------------------

func _build_grass() -> void:
	var density: float = SaveManager.settings.get("grass_density", 1.0)
	var area_ratio := pow(layout.radius / 14.0, 2.0)
	var n := int(3200 * density * area_ratio)
	var nf := int(450 * density * area_ratio)
	var rng := RandomNumberGenerator.new()
	rng.seed = def.noise_seed * 977
	var avoid: Array[Vector2] = layout.plot_positions(GameState.plot_count(def.id))
	var crystal_pos := layout.crystal_positions()
	var grass_xf: Array[Transform3D] = []
	var flower_xf: Array[Transform3D] = []
	var tries := 0
	while (grass_xf.size() < n or flower_xf.size() < nf) and tries < (n + nf) * 4:
		tries += 1
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * (layout.edge_radius(a) - 0.5)
		var p := Vector2(cos(a), sin(a)) * r
		if layout.is_in_pond(p.x, p.y, 0.15):
			continue
		var blocked := false
		for q in avoid:
			if p.distance_squared_to(q) < 0.9:
				blocked = true
				break
		for q in crystal_pos:
			if p.distance_squared_to(q) < 1.5:
				blocked = true
		if blocked:
			continue
		var y := layout.height_at(p.x, p.y)
		if y < layout.water_level() + 0.05:
			continue
		var basis := Basis(Vector3.UP, rng.randf() * TAU)
		if grass_xf.size() < n:
			var s := rng.randf_range(0.7, 1.4)
			grass_xf.append(Transform3D(basis.scaled(Vector3(s, s * rng.randf_range(0.8, 1.5), s)), Vector3(p.x, y - 0.02, p.y)))
		elif flower_xf.size() < nf:
			var s2 := rng.randf_range(0.8, 1.4)
			flower_xf.append(Transform3D(basis.scaled(Vector3.ONE * s2), Vector3(p.x, y - 0.02, p.y)))
	grass_mm = _make_mm(ProcMesh.blade(), grass_mat, grass_xf, false)
	_grass_total = grass_xf.size()
	var fmat := StandardMaterial3D.new()
	fmat.vertex_color_use_as_albedo = true
	fmat.roughness = 0.3
	fmat.emission_enabled = true
	fmat.emission = Color(0.2, 0.2, 0.25)
	fmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	flower_mm = _make_mm(ProcMesh.flower(), fmat, flower_xf, true, rng)
	_flower_total = flower_xf.size()


func _make_mm(mesh: Mesh, mat: Material, xfs: Array[Transform3D], colors: bool, rng: RandomNumberGenerator = null) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	var palette := [Color(1, 0.6, 0.85), Color(1, 0.95, 0.5), Color(1, 1, 1), Color(0.6, 0.9, 1), Color(0.85, 0.7, 1)]
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		if colors:
			mm.set_instance_color(i, palette[rng.randi() % palette.size()])
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = 110.0
	content.add_child(mmi)
	return mmi


# --------------------------------------------------------------------------------------
# Decoración con modelos de Poly Haven (CC0)
# --------------------------------------------------------------------------------------

const DECOR_ROCKS := ["moon_rock_02", "moon_rock_03", "moon_rock_06", "rock_09"]
const DECOR_PLANTS := ["shrub_03", "shrub_sorrel_01", "calathea_orbifolia_01", "flower_empodium"]


func _build_decor() -> void:
	_decor.clear()
	if not AssetLib.has("rock_09"):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = def.noise_seed * 4241
	var plots := layout.plot_positions(GameState.plot_count(def.id))
	var crystal_pos := layout.crystal_positions()
	var area := pow(layout.radius / 14.0, 2.0)
	var n_rocks := int(9 * area)
	var n_plants := int(22 * area)
	var placed: Array[Vector2] = []
	for i in n_rocks + n_plants:
		var is_rock := i < n_rocks
		for attempt in 25:
			var a := rng.randf() * TAU
			var band := rng.randf_range(0.72, 0.93) if is_rock else rng.randf_range(0.25, 0.9)
			var p := Vector2(cos(a), sin(a)) * layout.edge_radius(a) * band
			if layout.is_in_pond(p.x, p.y, 1.2):
				continue
			var ok := true
			for q in plots:
				if p.distance_to(q) < 2.0:
					ok = false
					break
			for q in crystal_pos:
				if p.distance_to(q) < 2.2:
					ok = false
			for q in placed:
				if p.distance_to(q) < 1.6:
					ok = false
			if not ok:
				continue
			placed.append(p)
			var id: String = DECOR_ROCKS[rng.randi() % DECOR_ROCKS.size()] if is_rock else DECOR_PLANTS[rng.randi() % DECOR_PLANTS.size()]
			var h := rng.randf_range(0.5, 1.3) if is_rock else rng.randf_range(0.45, 1.1)
			var node := AssetLib.instance(id, h)
			if node == null:
				break
			content.add_child(node)
			node.position = Vector3(p.x, layout.height_at(p.x, p.y) - (0.15 if is_rock else 0.02), p.y)
			node.rotation.y = rng.randf() * TAU
			if is_rock:
				node.scale = Vector3(rng.randf_range(1.0, 1.8), 1.0, rng.randf_range(1.0, 1.8))
			AssetLib.set_lod(node, 75.0, is_rock)
			# Las rocas están desde el principio; la vegetación brota con la vitalidad.
			_decor.append({"node": node, "threshold": 0.0 if is_rock else rng.randf_range(0.15, 0.85)})
			break


# --------------------------------------------------------------------------------------
# Bloqueo
# --------------------------------------------------------------------------------------

func update_lock(animate: bool) -> void:
	var locked := not GameState.is_island_unlocked(def.id)
	if locked and dome == null:
		dome = Node3D.new()
		dome.name = "Dome"
		var hemi := SphereMesh.new()
		hemi.radius = layout.radius + 3.0
		hemi.height = layout.radius + 3.0
		hemi.is_hemisphere = true
		hemi.radial_segments = 48
		hemi.rings = 16
		var mi := ProcMesh.add(dome, hemi, ProcMesh.glass(Color(def.crystal_color, 0.08), 0.3, 0.8, 3.0), Vector3(0, -0.5, 0), Vector3.ONE, Vector3.ZERO, false)
		mi.name = "DomeMesh"
		var label := Label3D.new()
		var t := DB.tech(def.unlock_tech)
		label.text = "%s\nSellada · investiga «%s»" % [def.display_name, t.display_name if t else "?"]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 96
		label.pixel_size = 0.012
		label.outline_size = 18
		label.modulate = Color(1, 1, 1)
		label.outline_modulate = Color(0.05, 0.2, 0.4, 0.8)
		label.position = Vector3(0, layout.radius * 0.8 + 4.0, 0)
		label.no_depth_test = false
		dome.add_child(label)
		add_child(dome)
	elif not locked and dome != null:
		var d := dome
		dome = null
		if animate:
			var tw := create_tween()
			tw.tween_property(d, "scale", Vector3(1.3, 1.3, 1.3), 1.2).set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(d, "position:y", 8.0, 1.2)
			tw.tween_callback(d.queue_free)
		else:
			d.queue_free()
