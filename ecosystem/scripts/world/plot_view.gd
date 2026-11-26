extends Node3D
## Parcela fértil. Mirar + E planta la especie seleccionada (Q para cambiar de especie).

var island: Node3D
var index := 0
var _ring: MeshInstance3D
var _t := 0.0
var _check_t := 0.0
var _free := true
var _ok := false


func setup(isl: Node3D, i: int) -> void:
	island = isl
	index = i
	name = "Plot_%d" % i
	var soil := ProcMesh.add(self, ProcMesh.cylinder(0.72, 0.82, 0.16, 24), ProcMesh.soil(), Vector3(0, 0.02, 0))
	soil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring = ProcMesh.add(self, ProcMesh.torus(0.8, 0.9, 32), ProcMesh.glass(Color(0.5, 1.0, 0.8, 0.5), 1.2, 0.6), Vector3(0, 0.1, 0), Vector3.ONE, Vector3.ZERO, false)
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.85
	shape.height = 0.5
	cs.shape = shape
	cs.position = Vector3(0, 0.2, 0)
	body.add_child(cs)
	add_child(body)
	_t = i * 0.7


func is_free() -> bool:
	return GameState.plant_at_plot(island.def.id, index).is_empty()


func _process(delta: float) -> void:
	_t += delta
	_check_t -= delta
	if _check_t <= 0.0:
		_check_t = 0.3
		_free = is_free()
		_ok = _free and GameState.plant_check(island.def.id, index, GameState.selected_species) == ""
	_ring.visible = _free
	if _free:
		_ring.set_instance_shader_parameter("intensity", (1.0 + 0.6 * sin(_t * 3.0)) if _ok else 0.25)


func get_prompt() -> String:
	if not is_free():
		return ""
	var sp: StringName = GameState.selected_species
	var d := DB.plant(sp)
	var err := GameState.plant_check(island.def.id, index, sp)
	if err == "":
		return "[E] Plantar %s  (%s)   [Q] cambiar especie" % [d.display_name, Economy.cost_text(GameState.plant_full_cost(d))]
	return "Parcela fértil · %s: %s   [Q] cambiar especie" % [d.display_name, err]


func interact(_player: Node, _hit: Vector3) -> void:
	var sp: StringName = GameState.selected_species
	var err := GameState.plant_check(island.def.id, index, sp)
	if err != "":
		Audio.play("error")
		GameState.notify.emit(err, "bad")
		return
	GameState.plant(island.def.id, index, sp)
	Audio.play("plant")
