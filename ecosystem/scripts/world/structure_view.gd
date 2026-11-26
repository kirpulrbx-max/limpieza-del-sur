extends Node3D
## Estructuras futuristas (blanco brillante, cromo, cristal y neón) con animación propia.

var sid := 0
var data: Dictionary
var def: StructureDef
var ghost := false
var _spin: Array[Node3D] = []
var _bob: Node3D
var _drone: Node3D
var _drone_target := Vector3.ZERO
var _drone_busy := 0.0
var _t := 0.0
var _beam: MeshInstance3D


func setup(type: StringName, d: Dictionary = {}, is_ghost := false) -> void:
	def = DB.structure(type)
	data = d
	ghost = is_ghost
	sid = int(d.get("id", 0))
	name = "Structure_%s_%d" % [type, sid]
	match def.model:
		&"condenser":
			_build_condenser()
		&"prism":
			_build_prism()
		&"seeder":
			_build_seeder()
		&"collector":
			_build_collector()
		&"nest":
			_build_nest()
	if not ghost:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = def.footprint * 0.6
		shape.height = 2.2
		cs.shape = shape
		cs.position = Vector3(0, 1.1, 0)
		body.add_child(cs)
		add_child(body)
	else:
		for g in find_children("*", "GeometryInstance3D", true, false):
			(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			(g as GeometryInstance3D).transparency = 0.45
	_t = randf() * 5.0


func set_ghost_valid(valid: bool) -> void:
	for g in find_children("*", "MeshInstance3D", true, false):
		(g as MeshInstance3D).material_overlay = ProcMesh.neon(Color(0.4, 1.0, 0.6, 0.3) if valid else Color(1.0, 0.3, 0.3, 0.3), 1.0)


func _process(delta: float) -> void:
	_t += delta
	for i in _spin.size():
		_spin[i].rotate_y(delta * (0.8 + i * 0.6) * (1 if i % 2 == 0 else -1))
	if _bob:
		_bob.position.y = _bob.get_meta("base_y", 1.2) + 0.08 * sin(_t * 2.0)
	if _drone:
		_update_drone(delta)
	if _beam:
		_beam.scale.y = 1.0 + 0.1 * sin(_t * 6.0)
		_beam.visible = GameState.daylight() > 0.3


# --------------------------------------------------------------------------------------
# Interacción
# --------------------------------------------------------------------------------------

func get_prompt() -> String:
	var parts: PackedStringArray = []
	for k in def.produce:
		parts.append("+%s %s/s" % [NumFmt.fmt(def.produce[k] * GameState.struct_mult()), Economy.NAMES[k]])
	if def.fauna_capacity > 0.0:
		parts.append("+%s hábitat" % NumFmt.fmt(def.fauna_capacity))
	if def.model == &"seeder":
		parts.append("siembra y riega cada %ds" % int(EcosystemSim.SEEDER_INTERVAL))
	if def.model == &"collector":
		parts.append("cosecha floraciones y atrae fenómenos")
	return "%s · %s" % [def.display_name, ", ".join(parts)]


func get_remove_prompt() -> String:
	return "[mantén X] Desmantelar (reembolso 50%)"


func interact(_player: Node, _hit: Vector3) -> void:
	pass


func remove_action() -> void:
	GameState.demolish(sid)
	Audio.play("pop", 0.6)


## Animación del dron cuando planta en una parcela.
func fly_to(world_pos: Vector3) -> void:
	if _drone:
		_drone_target = world_pos
		_drone_busy = 2.5


func _update_drone(delta: float) -> void:
	var home := global_position + Vector3(cos(_t * 0.8) * 1.4, 2.3 + 0.15 * sin(_t * 3.0), sin(_t * 0.8) * 1.4)
	var target := home
	if _drone_busy > 0.0:
		_drone_busy -= delta
		target = _drone_target + Vector3(0, 1.2, 0)
	_drone.global_position = _drone.global_position.lerp(target, clampf(delta * 2.5, 0.0, 1.0))
	_drone.rotate_y(delta * 3.0)


# --------------------------------------------------------------------------------------
# Modelos
# --------------------------------------------------------------------------------------

func _base(radius: float) -> void:
	ProcMesh.add(self, ProcMesh.cylinder(radius, radius * 1.1, 0.3, 24), ProcMesh.white(), Vector3(0, 0.15, 0))
	ProcMesh.add(self, ProcMesh.torus(radius * 0.98, radius * 1.08, 32), ProcMesh.neon(Color(0.4, 0.95, 1.0), 2.5), Vector3(0, 0.3, 0), Vector3.ONE, Vector3.ZERO, false)


func _build_condenser() -> void:
	_base(0.7)
	ProcMesh.add(self, ProcMesh.cylinder(0.08, 0.12, 0.8, 12), ProcMesh.chrome(), Vector3(0, 0.7, 0))
	_bob = Node3D.new()
	_bob.position = Vector3(0, 1.5, 0)
	_bob.set_meta("base_y", 1.5)
	add_child(_bob)
	ProcMesh.add(_bob, ProcMesh.sphere(0.55, 24), ProcMesh.glass(Color(0.75, 0.95, 1.0, 0.15), 0.4, 0.8), Vector3.ZERO, Vector3.ONE, Vector3.ZERO, false)
	ProcMesh.add(_bob, ProcMesh.sphere(0.36, 20), ProcMesh.glass(Color(0.2, 0.6, 1.0, 0.7), 1.2, 0.3), Vector3(0, -0.1, 0), Vector3(1, 0.8, 1))
	for i in 2:
		var ring := Node3D.new()
		ring.position = Vector3(0, 1.5, 0)
		ring.rotation = Vector3(0.5 + i * 0.6, 0, 0.3)
		var holder := Node3D.new()
		holder.add_child(ring)
		add_child(holder)
		ProcMesh.add(ring, ProcMesh.torus(0.68 + i * 0.1, 0.74 + i * 0.1, 40), ProcMesh.chrome())
		_spin.append(holder)


func _build_prism() -> void:
	_base(0.6)
	ProcMesh.add(self, ProcMesh.cylinder(0.35, 0.45, 0.5, 6), ProcMesh.white(), Vector3(0, 0.55, 0))
	var holder := Node3D.new()
	holder.position = Vector3(0, 0.8, 0)
	add_child(holder)
	ProcMesh.add(holder, ProcMesh.crystal(), ProcMesh.glass(Color(1.0, 0.85, 0.35, 0.5), 1.6, 0.7, 2.0), Vector3(0, 0.9, 0), Vector3(1.3, 1.8, 1.3))
	var inv := ProcMesh.add(holder, ProcMesh.crystal(), ProcMesh.glass(Color(1.0, 0.85, 0.35, 0.5), 1.6, 0.7, 2.0), Vector3(0, -0.0, 0), Vector3(1.0, 0.5, 1.0), Vector3(PI, 0, 0))
	inv.position.y = 0.05
	_spin.append(holder)
	var ring := Node3D.new()
	ring.position = Vector3(0, 1.4, 0)
	add_child(ring)
	ProcMesh.add(ring, ProcMesh.torus(0.7, 0.76, 6), ProcMesh.chrome())
	_spin.append(ring)
	_beam = ProcMesh.add(self, ProcMesh.cylinder(0.02, 0.25, 6.0, 12), ProcMesh.glass(Color(1.0, 0.95, 0.7, 0.05), 0.8, 0.0, 1.0), Vector3(0, 5.5, 0), Vector3.ONE, Vector3.ZERO, false)


func _build_seeder() -> void:
	_base(0.8)
	ProcMesh.add(self, ProcMesh.cylinder(0.5, 0.6, 0.12, 6), ProcMesh.gloss(Color(0.3, 0.8, 0.5), 0.2, 0.0, Color(0.2, 0.9, 0.4), 0.8), Vector3(0, 0.36, 0))
	_drone = Node3D.new()
	add_child(_drone)
	_drone.top_level = true
	ProcMesh.add(_drone, ProcMesh.sphere(0.28, 16), ProcMesh.white(), Vector3.ZERO, Vector3(1, 0.7, 1))
	ProcMesh.add(_drone, ProcMesh.sphere(0.18, 14), ProcMesh.glass(Color(0.4, 1.0, 0.6, 0.4), 1.2, 0.5), Vector3(0, 0.15, 0))
	ProcMesh.add(_drone, ProcMesh.torus(0.36, 0.42, 24), ProcMesh.neon(Color(0.5, 1.0, 0.7), 2.0), Vector3.ZERO)
	for i in 3:
		var a := TAU * i / 3.0
		ProcMesh.add(_drone, ProcMesh.sphere(0.05, 6), ProcMesh.neon(Color(0.7, 1.0, 0.8), 3.0), Vector3(cos(a) * 0.42, -0.05, sin(a) * 0.42))
	_drone.global_position = global_position + Vector3(0, 2.3, 0) if is_inside_tree() else Vector3(0, 2.3, 0)


func _build_collector() -> void:
	_base(0.75)
	ProcMesh.add(self, ProcMesh.cylinder(0.18, 0.3, 2.0, 16), ProcMesh.white(), Vector3(0, 1.3, 0))
	ProcMesh.add(self, ProcMesh.cylinder(0.9, 0.2, 0.7, 24), ProcMesh.glass(Color(0.6, 1.0, 1.0, 0.25), 0.8, 0.9), Vector3(0, 2.6, 0))
	ProcMesh.add(self, ProcMesh.sphere(0.2, 14), ProcMesh.neon(Color(0.5, 1.0, 1.0), 3.0), Vector3(0, 2.4, 0))
	var ring := Node3D.new()
	ring.position = Vector3(0, 2.0, 0)
	add_child(ring)
	for i in 3:
		var a := TAU * i / 3.0
		ProcMesh.add(ring, ProcMesh.sphere(0.12, 10), ProcMesh.glass(Color(0.6, 0.9, 1.0, 0.2), 1.0, 1.0), Vector3(cos(a) * 0.8, 0, sin(a) * 0.8))
	ProcMesh.add(ring, ProcMesh.torus(0.75, 0.82, 32), ProcMesh.chrome())
	_spin.append(ring)


func _build_nest() -> void:
	_base(1.0)
	var dome := SphereMesh.new()
	dome.radius = 1.0
	dome.height = 1.6
	dome.is_hemisphere = true
	dome.radial_segments = 10
	dome.rings = 4
	ProcMesh.add(self, dome, ProcMesh.glass(Color(0.75, 1.0, 0.95, 0.18), 0.6, 1.0, 2.0), Vector3(0, 0.3, 0), Vector3.ONE, Vector3.ZERO, false)
	for i in 5:
		var a := TAU * i / 5.0
		var arc := Node3D.new()
		arc.rotation = Vector3(0, a, 0)
		arc.position = Vector3(0, 0.3, 0)
		add_child(arc)
		ProcMesh.add(arc, ProcMesh.torus(0.98, 1.04, 32), ProcMesh.white(), Vector3.ZERO, Vector3(1, 1.6, 1), Vector3(PI * 0.5, 0, 0))
	_bob = Node3D.new()
	_bob.position = Vector3(0, 0.9, 0)
	_bob.set_meta("base_y", 0.9)
	add_child(_bob)
	ProcMesh.add(_bob, ProcMesh.sphere(0.15, 12), ProcMesh.neon(Color(0.7, 1.0, 0.85), 3.0))
