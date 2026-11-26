extends Node3D
## Puente de luz entre dos islas: cristal transitable con barandillas de neón.

var from_island: Node3D
var to_island: Node3D
var _orbs: Array[Node3D] = []
var _t := 0.0


func setup(a: Node3D, b: Node3D, animate: bool) -> void:
	from_island = a
	to_island = b
	name = "Bridge_%s_%s" % [a.def.id, b.def.id]
	rebuild()
	if animate:
		scale = Vector3(1, 1, 0.01)
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector3.ONE, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _edge_point(isl: Node3D, toward: Vector3) -> Vector3:
	var local: Vector3 = isl.to_local(toward)
	var dir := Vector2(local.x, local.z).normalized()
	var a := atan2(dir.y, dir.x)
	var r: float = isl.layout.edge_radius(a) - 1.2
	var p := dir * r
	return isl.surface_point(p) + Vector3(0, 0.05, 0)


func rebuild() -> void:
	for c in get_children():
		c.free()
	_orbs.clear()
	var start := _edge_point(from_island, to_island.global_position)
	var end := _edge_point(to_island, from_island.global_position)
	var mid := (start + end) * 0.5
	var length := start.distance_to(end)
	global_position = mid
	look_at(end, Vector3.UP)
	var width := 3.0
	var deck := BoxMesh.new()
	deck.size = Vector3(width, 0.18, length)
	ProcMesh.add(self, deck, ProcMesh.glass(Color(0.6, 0.95, 1.0, 0.35), 0.5, 0.6, 2.0), Vector3(0, -0.09, 0), Vector3.ONE, Vector3.ZERO, false)
	var rail := BoxMesh.new()
	rail.size = Vector3(0.08, 0.08, length)
	for side in [-1.0, 1.0]:
		ProcMesh.add(self, rail, ProcMesh.neon(Color(0.5, 1.0, 1.0), 3.0), Vector3(side * width * 0.5, 0.9, 0), Vector3.ONE, Vector3.ZERO, false)
		ProcMesh.add(self, rail, ProcMesh.chrome(), Vector3(side * width * 0.5, 0.02, 0), Vector3(1.5, 1.5, 1), Vector3.ZERO, false)
	var posts := int(length / 4.0)
	for i in posts + 1:
		var z := -length * 0.5 + length * i / maxf(posts, 1)
		for side in [-1.0, 1.0]:
			ProcMesh.add(self, ProcMesh.cylinder(0.04, 0.04, 0.9, 6), ProcMesh.white(), Vector3(side * width * 0.5, 0.45, z), Vector3.ONE, Vector3.ZERO, false)
		if i % 2 == 0:
			var orb := Node3D.new()
			orb.position = Vector3(0, 1.8, z)
			add_child(orb)
			ProcMesh.add(orb, ProcMesh.sphere(0.15, 10), ProcMesh.neon(Color(0.7, 1.0, 1.0), 3.0), Vector3.ZERO, Vector3.ONE, Vector3.ZERO, false)
			_orbs.append(orb)
	# Colisión: suelo y barandillas invisibles para no caer al vacío.
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	for spec in [[Vector3(width, 0.3, length + 1.0), Vector3(0, -0.15, 0)],
			[Vector3(0.2, 1.4, length), Vector3(-width * 0.5, 0.6, 0)],
			[Vector3(0.2, 1.4, length), Vector3(width * 0.5, 0.6, 0)]]:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = spec[0]
		cs.shape = box
		cs.position = spec[1]
		body.add_child(cs)
	add_child(body)


func _process(delta: float) -> void:
	_t += delta
	for i in _orbs.size():
		_orbs[i].position.y = 1.8 + 0.15 * sin(_t * 2.0 + i)
