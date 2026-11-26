extends Node3D
## Formación de cristal de luz: mirar + E extrae luz. También es origen de motas de luz.

var island: Node3D
var light: OmniLight3D
var _shards: Array[MeshInstance3D] = []
var _flash := 0.0

var continuous := true


func setup(isl: Node3D, seed_value: int) -> void:
	island = isl
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var col: Color = isl.def.crystal_color
	var mat := ProcMesh.glass(Color(col, 0.45), 0.9, 0.5, 2.0)
	var n := rng.randi_range(3, 5)
	for i in n:
		var h := rng.randf_range(1.2, 3.2) * (1.4 if i == 0 else 1.0)
		var w := rng.randf_range(0.6, 1.1)
		var off := Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6)) if i > 0 else Vector3.ZERO
		var tilt := Vector3(rng.randf_range(-0.35, 0.35), rng.randf() * TAU, rng.randf_range(-0.35, 0.35)) if i > 0 else Vector3(0, rng.randf() * TAU, 0)
		var mi := ProcMesh.add(self, ProcMesh.crystal(), mat, off + Vector3(0, h * 0.5, 0), Vector3(w, h, w), tilt)
		_shards.append(mi)
	# Base metálica pulida (tecnología + naturaleza)
	ProcMesh.add(self, ProcMesh.torus(0.9, 1.05, 32), ProcMesh.chrome(), Vector3(0, 0.1, 0))
	light = OmniLight3D.new()
	light.light_color = col
	light.omni_range = 7.0
	light.light_energy = 0.6
	light.shadow_enabled = false
	light.position = Vector3(0, 1.8, 0)
	add_child(light)
	var body := StaticBody3D.new()
	body.collision_layer = 1 | 2
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.9
	shape.height = 3.0
	cs.shape = shape
	cs.position = Vector3(0, 1.5, 0)
	body.add_child(cs)
	add_child(body)


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 3.0)
	var night := 1.0 - GameState.daylight()
	light.light_energy = 0.4 + night * 1.4 + _flash * 2.0
	for s in _shards:
		s.set_instance_shader_parameter("intensity", 1.0 + night * 0.8 + _flash * 2.5)


func get_prompt() -> String:
	if GameState.res["light"] >= GameState.cap("light") - 0.01:
		return "Luz al máximo (%s) — mejora los Depósitos" % NumFmt.fmt(GameState.cap("light"))
	return "[E] Extraer luz del cristal  (+%s)" % NumFmt.fmt(_amount())


func _amount() -> float:
	return GameState.tool_power() * island.def.light_mult * (0.5 + 0.5 * GameState.daylight())


func interact(_player: Node, _hit: Vector3) -> void:
	var got := GameState.add_res("light", _amount())
	if got > 0.0:
		GameState.add_stat("light_collected", got)
		GameState.collected.emit("light", got)
		Audio.play("light", randf_range(0.95, 1.1), -6.0)
		_flash = 1.0
	else:
		Audio.play("error", 1.0, -8.0)
