extends Node3D
## Superficie de agua del estanque. Mirar + E recoge agua (mantener para seguir recogiendo).

var island: Node3D
var radius := 3.0
var _ripple: GPUParticles3D

var continuous := true


func setup(isl: Node3D, r: float, mat: Material) -> void:
	island = isl
	radius = r
	var disc := ProcMesh.cylinder(r * 1.35, r * 1.35, 0.02, 56)
	var mi := ProcMesh.add(self, disc, mat, Vector3.ZERO, Vector3.ONE, Vector3.ZERO, false)
	mi.name = "Water"
	var area := Area3D.new()
	area.collision_layer = 2
	area.collision_mask = 0
	area.monitoring = false
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = r * 1.05
	shape.height = 0.5
	cs.shape = shape
	area.add_child(cs)
	add_child(area)
	_ripple = _make_splash()
	add_child(_ripple)


func _make_splash() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 24
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 0.9
	p.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 35.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 3.0
	pm.gravity = Vector3(0, -7, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	p.process_material = pm
	p.draw_pass_1 = ProcMesh.sphere(0.06, 8)
	p.material_override = ProcMesh.glass(Color(0.6, 0.9, 1.0, 0.5), 0.8, 0.5)
	return p


func get_prompt() -> String:
	var amount: float = GameState.tool_power() * island.def.water_mult
	if GameState.res["water"] >= GameState.cap("water") - 0.01:
		return "Agua al máximo (%s) — mejora los Depósitos" % NumFmt.fmt(GameState.cap("water"))
	return "[E] Recoger agua  (+%s)" % NumFmt.fmt(amount)


func interact(_player: Node, hit: Vector3) -> void:
	var amount: float = GameState.tool_power() * island.def.water_mult
	var got := GameState.add_res("water", amount)
	if got > 0.0:
		GameState.add_stat("water_collected", got)
		GameState.collected.emit("water", got)
		Audio.play("water", randf_range(0.9, 1.15), -4.0)
		_ripple.global_position = hit
		_ripple.restart()
	else:
		Audio.play("error", 1.0, -8.0)
