extends CharacterBody3D
## Jugador en primera persona: movimiento fluido, interacción por rayo, modo construcción
## y el "Recolector Aero" (herramienta visible en mano).

const WALK := 5.2
const SPRINT := 8.6
const ACCEL := 11.0
const AIR_ACCEL := 3.0
const JUMP := 5.4
const GRAVITY := 14.0
const REPEAT := 0.22
const REMOVE_TIME := 0.8

var world: Node
var hud: CanvasLayer
var prompt := ""
var prompt_error := false
var remove_progress := 0.0
var build_mode := false
var build_type: StringName = &"condenser"
var build_error := ""

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera
@onready var ray: RayCast3D = $Head/Camera/Ray

var _pitch := 0.0
var _bob_t := 0.0
var _step_acc := 0.0
var _repeat := 0.0
var _target: Node = null
var _target_hit := Vector3.ZERO
var _ghost: Node3D
var _ghost_rot := 0.0
var _ghost_valid := false
var _ghost_island: StringName = &""
var _ghost_pos := Vector3.ZERO
var _tool: Node3D
var _tool_core: MeshInstance3D
var _tool_kick := 0.0
var _beam: MeshInstance3D
var _beam_mesh: ImmediateMesh
var _beam_t := 0.0
var _beam_target := Vector3.ZERO
var _last_pos := Vector3.ZERO


func _ready() -> void:
	_build_tool()
	GameState.collected.connect(func(_k, _a): _tool_kick = 1.0)


func teleport(pos: Vector3, yaw: float) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	rotation.y = yaw
	_pitch = -0.12
	head.rotation.x = _pitch
	_last_pos = pos


func blocked() -> bool:
	return hud == null or hud.is_blocking() or not GameState.running


func _unhandled_input(event: InputEvent) -> void:
	if blocked():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s: float = SaveManager.settings.mouse_sensitivity
		var inv := -1.0 if SaveManager.settings.invert_y else 1.0
		rotate_y(-event.relative.x * s)
		_pitch = clampf(_pitch - event.relative.y * s * inv, -1.45, 1.45)
		head.rotation.x = _pitch
	elif event is InputEventMouseButton and event.pressed and build_mode:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_build(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_build(-1)
	elif event is InputEventMouseButton and event.pressed and not build_mode:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cycle_species(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cycle_species(-1)
	if event.is_action_pressed("build_mode"):
		if build_mode:
			exit_build()
		else:
			enter_build(build_type)
	elif event.is_action_pressed("next_species") and not build_mode:
		cycle_species(1)
	elif event.is_action_pressed("rotate") and build_mode:
		_ghost_rot += PI / 4.0
	elif event.is_action_pressed("secondary") and build_mode:
		exit_build()


func _physics_process(delta: float) -> void:
	camera.fov = SaveManager.settings.fov
	var input := Vector2.ZERO
	if not blocked():
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var sprinting := Input.is_action_pressed("sprint") and not blocked()
	var speed := SPRINT if sprinting else WALK
	var accel := ACCEL if is_on_floor() else AIR_ACCEL
	var hv := Vector3(velocity.x, 0, velocity.z).lerp(dir * speed, clampf(accel * delta, 0.0, 1.0))
	velocity.x = hv.x
	velocity.z = hv.z
	if is_on_floor():
		if Input.is_action_just_pressed("jump") and not blocked():
			velocity.y = JUMP
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	# Balanceo de cámara y pasos
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hspeed > 0.5:
		_bob_t += delta * hspeed * 1.6
		_step_acc += hspeed * delta
		if _step_acc > (2.2 if sprinting else 1.7):
			_step_acc = 0.0
			Audio.play("step", randf_range(0.8, 1.2), -10.0)
	else:
		_bob_t = lerpf(_bob_t, round(_bob_t / PI) * PI, delta * 5.0)
	head.position.y = 1.62 + sin(_bob_t * 2.0) * 0.045
	head.position.x = cos(_bob_t) * 0.025
	GameState.add_stat("distance_walked", global_position.distance_to(_last_pos) if is_on_floor() else 0.0)
	_last_pos = global_position


func _process(delta: float) -> void:
	_update_tool(delta)
	if blocked():
		prompt = ""
		remove_progress = 0.0
		if _ghost:
			_ghost.visible = false
		return
	if build_mode:
		_update_build()
		return
	ray.target_position = Vector3(0, 0, -GameState.reach())
	_find_target()
	_repeat -= delta
	var target_ok := _target != null and is_instance_valid(_target)
	if target_ok and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("primary")):
		_do_interact()
	elif target_ok and (Input.is_action_pressed("interact") or Input.is_action_pressed("primary")) and _target.get("continuous") == true and _repeat <= 0.0:
		_do_interact()
	if target_ok and _target.has_method("remove_action") and Input.is_action_pressed("remove"):
		remove_progress += delta / REMOVE_TIME
		if remove_progress >= 1.0:
			remove_progress = 0.0
			_target.remove_action()
	else:
		remove_progress = 0.0


func _find_target() -> void:
	_target = null
	prompt = ""
	prompt_error = false
	ray.force_raycast_update()
	if not ray.is_colliding():
		return
	var n: Node = ray.get_collider()
	_target_hit = ray.get_collision_point()
	while n != null and not n.has_method("get_prompt"):
		n = n.get_parent()
	if n == null:
		return
	var text: String = n.get_prompt()
	if text == "":
		# Parcela ocupada: la planta tiene prioridad aunque el rayo toque la parcela.
		return
	_target = n
	prompt = text
	prompt_error = not text.begins_with("[E]")
	if n.has_method("get_remove_prompt"):
		prompt += "\n" + n.get_remove_prompt()


func _do_interact() -> void:
	_repeat = REPEAT
	_target.interact(self, _target_hit)
	_tool_kick = 1.0
	_beam_t = 0.25
	_beam_target = _target_hit


func cycle_species(step: int) -> void:
	var options: Array = []
	for d in DB.plants:
		if GameState.is_species_unlocked(d):
			options.append(d.id)
	if options.is_empty():
		return
	var i := options.find(GameState.selected_species)
	GameState.selected_species = options[posmod(i + step, options.size())]
	Audio.play("click")


# --------------------------------------------------------------------------------------
# Construcción
# --------------------------------------------------------------------------------------

func enter_build(type: StringName) -> void:
	var sd := DB.structure(type)
	if sd == null or not GameState.has_tech(sd.unlock_tech):
		var first := _available_structures()
		if first.is_empty():
			GameState.notify.emit("Aún no conoces ninguna estructura: investiga en el Árbol tecnológico", "warn")
			Audio.play("error")
			return
		type = first[0]
	build_type = type
	build_mode = true
	_make_ghost()
	Audio.play("click")


func exit_build() -> void:
	build_mode = false
	if _ghost:
		_ghost.queue_free()
		_ghost = null


func _available_structures() -> Array:
	var out := []
	for sd in DB.structures:
		if GameState.has_tech(sd.unlock_tech):
			out.append(sd.id)
	return out


func _cycle_build(step: int) -> void:
	var list := _available_structures()
	if list.is_empty():
		return
	var i := list.find(build_type)
	build_type = list[posmod(i + step, list.size())]
	_make_ghost()


func _make_ghost() -> void:
	if _ghost:
		_ghost.queue_free()
	_ghost = Node3D.new()
	_ghost.set_script(preload("res://scripts/world/structure_view.gd"))
	world.add_child(_ghost)
	_ghost.setup(build_type, {}, true)


func _update_build() -> void:
	prompt = ""
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * 14.0
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := space.intersect_ray(q)
	_ghost_valid = false
	build_error = ""
	if hit.is_empty():
		_ghost.visible = false
		build_error = "Apunta al suelo de una isla"
		return
	var n: Node = hit.collider
	var island_id: StringName = &""
	while n != null:
		if n.has_meta("island_id"):
			island_id = n.get_meta("island_id")
			break
		n = n.get_parent()
	_ghost.visible = true
	_ghost.global_position = hit.position
	_ghost.rotation.y = _ghost_rot
	if island_id == &"":
		build_error = "Solo se puede construir sobre el terreno"
	else:
		build_error = world.placement_error(build_type, island_id, hit.position, hit.normal)
		if build_error == "":
			build_error = GameState.structure_check(build_type)
	_ghost_valid = build_error == ""
	_ghost.set_ghost_valid(_ghost_valid)
	_ghost_island = island_id
	_ghost_pos = hit.position
	if Input.is_action_just_pressed("primary") or Input.is_action_just_pressed("interact"):
		if _ghost_valid:
			var iv: Node3D = world.islands[String(island_id)]
			var local: Vector3 = iv.to_local(hit.position)
			if GameState.build(build_type, island_id, local, _ghost_rot):
				Audio.play("build")
				GameState.notify.emit("Construido: " + DB.structure(build_type).display_name, "good")
		else:
			Audio.play("error")
			GameState.notify.emit(build_error, "bad")


# --------------------------------------------------------------------------------------
# Herramienta en mano
# --------------------------------------------------------------------------------------

func _build_tool() -> void:
	_tool = Node3D.new()
	camera.add_child(_tool)
	_tool.position = Vector3(0.34, -0.3, -0.62)
	_tool.scale = Vector3.ONE * 0.6
	var body := ProcMesh.add(_tool, ProcMesh.cylinder(0.035, 0.05, 0.32, 16), ProcMesh.white(), Vector3.ZERO, Vector3.ONE, Vector3(PI * 0.5, 0, 0), false)
	body.layers = 1
	ProcMesh.add(_tool, ProcMesh.torus(0.05, 0.065, 24), ProcMesh.chrome(), Vector3(0, 0, -0.12), Vector3.ONE, Vector3(PI * 0.5, 0, 0), false)
	ProcMesh.add(_tool, ProcMesh.sphere(0.075, 16), ProcMesh.glass(Color(0.6, 1.0, 1.0, 0.25), 0.8, 0.9), Vector3(0, 0, -0.2), Vector3.ONE, Vector3.ZERO, false)
	_tool_core = ProcMesh.add(_tool, ProcMesh.sphere(0.035, 10), ProcMesh.neon(Color(0.5, 1.0, 0.9), 3.0), Vector3(0, 0, -0.2), Vector3.ONE, Vector3.ZERO, false)
	for g in _tool.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam_mesh = ImmediateMesh.new()
	_beam = MeshInstance3D.new()
	_beam.mesh = _beam_mesh
	_beam.material_override = ProcMesh.neon(Color(0.6, 1.0, 1.0), 3.0)
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.top_level = true
	add_child(_beam)


func _update_tool(delta: float) -> void:
	_tool_kick = maxf(0.0, _tool_kick - delta * 5.0)
	var sway := Vector3(cos(_bob_t) * 0.008, sin(_bob_t * 2.0) * 0.006, 0)
	_tool.position = Vector3(0.34, -0.3, -0.62 + _tool_kick * 0.04) + sway
	_tool.rotation.x = _tool_kick * 0.25
	_tool_core.scale = Vector3.ONE * (1.0 + _tool_kick * 0.8 + 0.1 * sin(Time.get_ticks_msec() * 0.006))
	_tool.visible = not build_mode
	_beam_t -= delta
	_beam_mesh.clear_surfaces()
	if _beam_t > 0.0:
		var start := _tool_core.global_position
		_beam_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for i in 6:
			var t0 := float(i) / 6.0
			var t1 := float(i + 1) / 6.0
			var jitter := Vector3(randf_range(-0.03, 0.03), randf_range(-0.03, 0.03), randf_range(-0.03, 0.03))
			_beam_mesh.surface_add_vertex(start.lerp(_beam_target, t0) + jitter)
			_beam_mesh.surface_add_vertex(start.lerp(_beam_target, t1))
		_beam_mesh.surface_end()
