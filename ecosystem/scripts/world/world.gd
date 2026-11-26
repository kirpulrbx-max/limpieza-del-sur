extends Node3D
## Nodo raíz del juego: construye el mundo a partir de GameState y mantiene las vistas sincronizadas.

const ISLAND_SCRIPT := preload("res://scripts/world/island_view.gd")
const PLANT_SCRIPT := preload("res://scripts/world/plant_view.gd")
const STRUCTURE_SCRIPT := preload("res://scripts/world/structure_view.gd")
const BRIDGE_SCRIPT := preload("res://scripts/world/bridge_view.gd")
const PHENOMENA_SCRIPT := preload("res://scripts/world/phenomena.gd")
const FAUNA_SCRIPT := preload("res://scripts/world/fauna_view.gd")
const ENV_SCRIPT := preload("res://scripts/world/environment_controller.gd")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const HUD_SCRIPT := preload("res://scripts/ui/hud.gd")

var islands := {}
var bridges := {}
var plant_views := {}
var structure_views := {}
var env_ctrl: Node3D
var phenomena: Node3D
var fauna: Node3D
var player: CharacterBody3D
var hud: CanvasLayer
var plants_root: Node3D
var structures_root: Node3D
var _island_check := 0.0


func _ready() -> void:
	add_to_group("world")
	env_ctrl = Node3D.new()
	env_ctrl.set_script(ENV_SCRIPT)
	env_ctrl.name = "Environment"
	add_child(env_ctrl)
	for d in DB.islands:
		var iv := Node3D.new()
		iv.set_script(ISLAND_SCRIPT)
		add_child(iv)
		iv.setup(d)
		islands[String(d.id)] = iv
	_decor_islets()
	plants_root = Node3D.new()
	plants_root.name = "Plants"
	add_child(plants_root)
	structures_root = Node3D.new()
	structures_root.name = "Structures"
	add_child(structures_root)
	phenomena = Node3D.new()
	phenomena.set_script(PHENOMENA_SCRIPT)
	phenomena.name = "Phenomena"
	phenomena.world = self
	add_child(phenomena)
	fauna = Node3D.new()
	fauna.set_script(FAUNA_SCRIPT)
	fauna.name = "Fauna"
	fauna.world = self
	add_child(fauna)
	player = PLAYER_SCENE.instantiate()
	player.world = self
	add_child(player)
	env_ctrl.follow = player
	hud = CanvasLayer.new()
	hud.set_script(HUD_SCRIPT)
	hud.name = "HUD"
	hud.world = self
	add_child(hud)
	player.hud = hud

	GameState.plant_added.connect(_on_plant_added)
	GameState.plant_removed.connect(_on_plant_removed)
	GameState.structure_added.connect(_on_structure_added)
	GameState.structure_removed.connect(_on_structure_removed)
	GameState.world_reset.connect(rebuild_from_state)
	GameState.island_unlocked.connect(_on_island_unlocked)
	GameState.island_changed.connect(_on_island_changed)
	GameState.bloom_harvested.connect(_on_bloom_harvested)
	GameState.level_up.connect(func(_l): Audio.play("levelup"))

	rebuild_from_state()
	respawn_player()
	if "--autotest" in OS.get_cmdline_user_args():
		var bot := Node.new()
		bot.set_script(load("res://tests/autoplay.gd"))
		bot.world = self
		add_child(bot)
	else:
		hud.show_title()


## Arranca la partida (desde la pantalla de título).
func start_game(load_save: bool) -> void:
	if load_save and SaveManager.has_save():
		SaveManager.load_game(true)
	else:
		SaveManager.delete_save()
		GameState.new_game()
		GameState.world_reset.emit()
		_spawn_intro_phenomena()
		SaveManager.save_game(true)
	respawn_player()
	GameState.running = true


func _spawn_intro_phenomena() -> void:
	var origin: Node3D = islands["origin"]
	var d := DB.island(&"origin")
	phenomena.spawn("seed", origin.surface_point(Vector2(2.5, 7.5)) + Vector3(0, 1.3, 0), d)
	phenomena.spawn("seed", origin.surface_point(Vector2(-6.5, 5.0)) + Vector3(0, 1.3, 0), d)
	phenomena.spawn("dew", origin.surface_point(Vector2(-1.0, 4.6)) + Vector3(0, 1.0, 0), d)


func respawn_player() -> void:
	var origin: Node3D = islands["origin"]
	var spawn: Vector3 = origin.surface_point(Vector2(0.0, 11.0)) + Vector3(0, 1.2, 0)
	player.teleport(spawn, 0.0)


## Reconstruye todas las vistas a partir del estado (tras cargar o renacer).
func rebuild_from_state() -> void:
	for iv in islands.values():
		iv.rebuild()
	for pv in plant_views.values():
		pv.queue_free()
	plant_views.clear()
	for sv in structure_views.values():
		sv.queue_free()
	structure_views.clear()
	for b in bridges.values():
		b.queue_free()
	bridges.clear()
	phenomena.clear()
	for p in GameState.plants:
		_on_plant_added(p)
	for s in GameState.structures:
		_on_structure_added(s)
	for d in DB.islands:
		if d.bridge_from != &"" and GameState.is_island_unlocked(d.id):
			_make_bridge(d, false)


func _make_bridge(d: IslandDef, animate: bool) -> void:
	if bridges.has(String(d.id)):
		return
	var b := Node3D.new()
	b.set_script(BRIDGE_SCRIPT)
	add_child(b)
	b.setup(islands[String(d.bridge_from)], islands[String(d.id)], animate)
	bridges[String(d.id)] = b


func _on_island_unlocked(id: StringName) -> void:
	var iv: Node3D = islands[String(id)]
	iv.update_lock(true)
	_make_bridge(DB.island(id), true)


func _on_island_changed(id: StringName) -> void:
	var iv: Node3D = islands[String(id)]
	iv.rebuild()
	for p in GameState.plants:
		if p.island == String(id) and plant_views.has(int(p.id)):
			plant_views[int(p.id)].global_position = iv.plot_world_position(int(p.plot))
	for s in GameState.structures:
		if s.island == String(id) and structure_views.has(int(s.id)):
			structure_views[int(s.id)].global_position = _structure_pos(s)
	for d in DB.islands:
		if bridges.has(String(d.id)) and (d.bridge_from == id or d.id == id):
			bridges[String(d.id)].rebuild()
	GameState.notify.emit("La isla se expande: nuevas parcelas fértiles", "good")


func _on_plant_added(p: Dictionary) -> void:
	var iv: Node3D = islands.get(p.island)
	if iv == null:
		return
	var pv := Node3D.new()
	pv.set_script(PLANT_SCRIPT)
	plants_root.add_child(pv)
	pv.global_position = iv.plot_world_position(int(p.plot))
	pv.rotation.y = randf() * TAU
	pv.setup(p)
	plant_views[int(p.id)] = pv
	if p.get("auto", false) and GameState.running:
		# El dron sembrador vuela hasta la parcela si fue una siembra automática.
		for sv in structure_views.values():
			if sv.def.model == &"seeder" and sv.data.island == p.island:
				sv.fly_to(pv.global_position)


func _on_plant_removed(pid: int) -> void:
	if plant_views.has(pid):
		plant_views[pid].queue_free()
		plant_views.erase(pid)


func _structure_pos(s: Dictionary) -> Vector3:
	var iv: Node3D = islands[s.island]
	return iv.surface_point(Vector2(s.x, s.z))


func _on_structure_added(s: Dictionary) -> void:
	if not islands.has(s.island):
		return
	var sv := Node3D.new()
	sv.set_script(STRUCTURE_SCRIPT)
	structures_root.add_child(sv)
	sv.global_position = _structure_pos(s)
	sv.rotation.y = float(s.rot)
	sv.setup(StringName(s.type), s)
	structure_views[int(s.id)] = sv


func _on_structure_removed(sid: int) -> void:
	if structure_views.has(sid):
		structure_views[sid].queue_free()
		structure_views.erase(sid)


func _on_bloom_harvested(p: Dictionary, _amount: float) -> void:
	var pv = plant_views.get(int(p.id))
	if pv:
		pv.on_bloom_harvested()


## Valida la colocación de una estructura. Devuelve "" si es válida.
func placement_error(type: StringName, island_id: StringName, world_pos: Vector3, normal: Vector3) -> String:
	if not GameState.is_island_unlocked(island_id):
		return "Isla sellada"
	var sd := DB.structure(type)
	var iv: Node3D = islands[String(island_id)]
	var local: Vector3 = iv.to_local(world_pos)
	var p := Vector2(local.x, local.z)
	var lay: IslandLayout = iv.layout
	if normal.y < 0.8:
		return "Terreno demasiado inclinado"
	if p.length() > lay.edge_radius(atan2(p.y, p.x)) - sd.footprint - 0.4:
		return "Demasiado cerca del borde"
	if lay.is_in_pond(p.x, p.y, sd.footprint + 0.3):
		return "No se puede construir en el agua"
	for q in lay.plot_positions(GameState.plot_count(island_id)):
		if p.distance_to(q) < sd.footprint + 0.9:
			return "Demasiado cerca de una parcela"
	for q in lay.crystal_positions():
		if p.distance_to(q) < sd.footprint + 1.2:
			return "Demasiado cerca de un cristal"
	for s in GameState.structures:
		if s.island == String(island_id):
			var other := DB.structure(s.type)
			if p.distance_to(Vector2(s.x, s.z)) < sd.footprint + other.footprint:
				return "Demasiado cerca de otra estructura"
	return ""


func island_at(world_pos: Vector3) -> Node3D:
	for iv in islands.values():
		var d: Vector3 = world_pos - iv.global_position
		if Vector2(d.x, d.z).length() < iv.layout.radius + 1.5 and d.y > -8.0 and d.y < 25.0:
			return iv
	return null


func _process(delta: float) -> void:
	if not GameState.running:
		return
	_island_check -= delta
	if _island_check <= 0.0:
		_island_check = 0.5
		var iv := island_at(player.global_position)
		if iv:
			GameState.visit_island(iv.def.id)
	if player.global_position.y < -45.0:
		respawn_player()
		GameState.notify.emit("El vacío te devuelve a la Isla Origen", "warn")
		Audio.play("pop", 0.5)


## Pequeños islotes decorativos a lo lejos para dar sensación de espacio infinito.
func _decor_islets() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var rock := ProcMesh.gloss(Color(0.78, 0.84, 0.94), 0.55)
	var grass := ProcMesh.gloss(Color(0.42, 0.86, 0.52), 0.45)
	var leaf := ProcMesh.gloss(Color(0.3, 0.9, 0.6), 0.25)
	for i in 16:
		var a := rng.randf() * TAU
		var r := rng.randf_range(105.0, 220.0)
		var root := Node3D.new()
		root.position = Vector3(cos(a) * r, rng.randf_range(-30.0, 28.0), sin(a) * r)
		root.rotation.y = rng.randf() * TAU
		add_child(root)
		var s := rng.randf_range(3.0, 8.0)
		# Base rocosa irregular: varios conos desplazados.
		for k in 3:
			var off := Vector3(rng.randf_range(-0.3, 0.3) * s, -s * (0.5 + 0.25 * k), rng.randf_range(-0.3, 0.3) * s)
			var rr := s * (1.0 - 0.28 * k)
			ProcMesh.add(root, ProcMesh.cylinder(rr, rr * 0.15, s * (1.1 - 0.2 * k), 7), rock, off, Vector3.ONE, Vector3(0, rng.randf() * TAU, 0), false)
		ProcMesh.add(root, ProcMesh.sphere(1.0, 12), grass, Vector3(0, 0.1, 0), Vector3(s * 1.05, s * 0.18, s * 1.05), Vector3.ZERO, false)
		for t in rng.randi_range(1, 3):
			var tp := Vector3(rng.randf_range(-0.5, 0.5) * s, s * 0.15, rng.randf_range(-0.5, 0.5) * s)
			ProcMesh.add(root, ProcMesh.cylinder(0.12 * s / 4.0, 0.2 * s / 4.0, s * 0.5, 6), ProcMesh.white(), tp + Vector3(0, s * 0.25, 0), Vector3.ONE, Vector3.ZERO, false)
			ProcMesh.add(root, ProcMesh.sphere(1.0, 12), leaf, tp + Vector3(0, s * 0.6, 0), Vector3.ONE * s * 0.28, Vector3.ZERO, false)
		if rng.randf() < 0.5:
			ProcMesh.add(root, ProcMesh.crystal(), ProcMesh.glass(Color(0.6, 0.9, 1.0, 0.4), 1.0, 0.6), Vector3(0, -s * 1.4, 0), Vector3(s * 0.35, s * 0.8, s * 0.35), Vector3(PI, 0, 0), false)
