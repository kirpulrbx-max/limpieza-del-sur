extends Node3D
## Fenómenos naturales recolectables: rocío (agua), motas de luz, semillas flotantes y
## burbujas de oxígeno. Gestiona su aparición, el imán del recolector y la recogida.

const KINDS := {
	"dew": {"res": "water", "base": 3.0, "color": Color(0.35, 0.75, 1.0, 0.5), "name": "rocío", "sound": "collect"},
	"light": {"res": "light", "base": 3.0, "color": Color(1.0, 0.9, 0.4, 0.5), "name": "mota de luz", "sound": "light"},
	"seed": {"res": "seeds", "base": 1.0, "color": Color(0.95, 0.8, 0.5, 0.4), "name": "semilla", "sound": "seed"},
	"bubble": {"res": "oxygen", "base": 5.0, "color": Color(0.8, 1.0, 1.0, 0.08), "name": "burbuja de oxígeno", "sound": "pop"},
}
const LIMITS := {"dew": 6, "light": 6, "seed": 3, "bubble": 8}

var world: Node
var items: Array = []
var _timers := {"dew": 2.0, "light": 3.0, "seed": 1.0, "bubble": 6.0}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func clear() -> void:
	for it in items:
		if is_instance_valid(it):
			it.queue_free()
	items.clear()


func count(kind: String) -> int:
	var n := 0
	for it in items:
		if it.kind == kind:
			n += 1
	return n


func _process(delta: float) -> void:
	if not GameState.running:
		return
	var day := GameState.daylight()
	for kind in _timers:
		_timers[kind] -= delta
		if _timers[kind] > 0.0:
			continue
		match kind:
			"dew":
				_timers[kind] = 7.0
			"light":
				_timers[kind] = 6.0 / (0.3 + day)
			"seed":
				_timers[kind] = 24.0 / GameState.seed_mult()
			"bubble":
				_timers[kind] = 9.0 / (1.0 + GameState.mature_plants() * 0.15)
		if count(kind) < LIMITS[kind]:
			_spawn_random(kind)
	_update_items(delta)


func _unlocked_islands() -> Array:
	var out := []
	for isl in world.islands.values():
		if GameState.is_island_unlocked(isl.def.id):
			out.append(isl)
	return out


func _spawn_random(kind: String) -> void:
	var isls := _unlocked_islands()
	if isls.is_empty():
		return
	var isl = isls[_rng.randi() % isls.size()]
	var pos := Vector3.ZERO
	match kind:
		"dew":
			if isl.def.pond_radius > 0.0:
				var a := _rng.randf() * TAU
				var r: float = isl.def.pond_radius + _rng.randf_range(0.6, 2.5)
				pos = isl.surface_point(isl.def.pond_offset + Vector2(cos(a), sin(a)) * r) + Vector3(0, _rng.randf_range(0.6, 1.4), 0)
			else:
				pos = _random_surface(isl) + Vector3(0, 1.0, 0)
		"light":
			if isl.crystals.is_empty():
				return
			var c: Node3D = isl.crystals[_rng.randi() % isl.crystals.size()]
			pos = c.global_position + Vector3(_rng.randf_range(-1.6, 1.6), _rng.randf_range(1.0, 2.6), _rng.randf_range(-1.6, 1.6))
		"seed":
			pos = _random_surface(isl) + Vector3(0, _rng.randf_range(1.0, 2.0), 0)
		"bubble":
			var mature: Array = []
			for p in GameState.plants:
				if p.mature and p.island == String(isl.def.id):
					mature.append(p)
			if mature.is_empty():
				return
			var pv = world.plant_views.get(int(mature[_rng.randi() % mature.size()].id))
			if pv == null:
				return
			pos = pv.global_position + Vector3(_rng.randf_range(-0.4, 0.4), 0.8, _rng.randf_range(-0.4, 0.4))
	spawn(kind, pos, isl.def)


func _random_surface(isl) -> Vector3:
	for i in 10:
		var a := _rng.randf() * TAU
		var r: float = sqrt(_rng.randf()) * isl.layout.edge_radius(a) * 0.8
		var p := Vector2(cos(a), sin(a)) * r
		if not isl.layout.is_in_pond(p.x, p.y, 0.5):
			return isl.surface_point(p)
	return isl.global_position + Vector3(0, 2, 0)


func spawn(kind: String, pos: Vector3, island_def: IslandDef) -> Node3D:
	var it := Collectible.new()
	it.kind = kind
	it.island_def = island_def
	it.phenomena = self
	add_child(it)
	it.global_position = pos
	it.build(KINDS[kind].color)
	items.append(it)
	return it


func _update_items(delta: float) -> void:
	var player: Node3D = world.player
	var magnet := GameState.magnet_radius()
	var collectors: Array = []
	for sv in world.structure_views.values():
		if sv.def.model == &"collector":
			collectors.append(sv)
	for it in items.duplicate():
		if not is_instance_valid(it):
			items.erase(it)
			continue
		it.age += delta
		if it.age > 120.0:
			_remove(it)
			continue
		var target: Node3D = null
		var ppos := player.global_position + Vector3(0, 1.0, 0)
		if it.global_position.distance_to(ppos) < magnet:
			target = player
		else:
			for c in collectors:
				if it.global_position.distance_to(c.global_position) < c.def.effect_radius:
					target = c
					break
		if target:
			var tp: Vector3 = target.global_position + Vector3(0, 1.0 if target == player else 2.4, 0)
			var dir: Vector3 = tp - it.global_position
			var speed := 6.0 + 10.0 / maxf(dir.length(), 0.3)
			it.global_position += dir.normalized() * minf(speed * delta, dir.length())
			if dir.length() < 0.45:
				collect(it, target != player)


func collect(it: Node3D, automatic := false) -> void:
	if not is_instance_valid(it) or it.collected:
		return
	var k: Dictionary = KINDS[it.kind]
	var amount: float = k.base
	if it.kind != "seed":
		amount *= GameState.tool_power()
	if it.kind == "dew":
		amount *= it.island_def.water_mult
	elif it.kind == "light":
		amount *= it.island_def.light_mult
	var got := GameState.add_res(k.res, amount)
	if it.kind == "bubble":
		got += GameState.add_res("essence", 1.0 * GameState.tool_power() * GameState.essence_mult())
	if got <= 0.0 and not automatic:
		GameState.notify.emit("Almacén de %s lleno" % Economy.NAMES[k.res], "warn")
		Audio.play("error", 1.0, -6.0)
		return
	it.collected = true
	GameState.add_stat("motes_collected")
	match it.kind:
		"dew":
			GameState.add_stat("water_collected", got)
		"light":
			GameState.add_stat("light_collected", got)
			GameState.add_stat("light_motes")
		"seed":
			GameState.add_stat("seeds_collected", got)
	GameState.collected.emit(k.res, got)
	Audio.play(k.sound, randf_range(0.95, 1.1), -3.0 if not automatic else -14.0)
	_remove(it)


func _remove(it: Node3D) -> void:
	items.erase(it)
	if is_instance_valid(it):
		it.vanish()


# ======================================================================================

class Collectible extends Node3D:
	var kind := "dew"
	var island_def: IslandDef
	var phenomena: Node
	var age := 0.0
	var collected := false
	var _t := 0.0
	var _core: Node3D

	func build(color: Color) -> void:
		var area := Area3D.new()
		area.collision_layer = 2
		area.collision_mask = 0
		area.monitoring = false
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 0.5
		cs.shape = sh
		area.add_child(cs)
		add_child(area)
		_core = Node3D.new()
		add_child(_core)
		match kind:
			"seed":
				ProcMesh.add(_core, ProcMesh.sphere(0.09, 10), ProcMesh.gloss(Color(0.75, 0.55, 0.3), 0.3, 0.0, Color(0.9, 0.7, 0.3), 0.6), Vector3.ZERO, Vector3(1, 1.4, 1))
				var fluff := ProcMesh.glass(Color(1, 1, 1, 0.25), 1.0, 0.2, 1.5)
				ProcMesh.add(_core, ProcMesh.sphere(0.32, 14), fluff, Vector3(0, 0.3, 0), Vector3(1, 0.55, 1), Vector3.ZERO, false)
				for i in 6:
					var a := TAU * i / 6.0
					ProcMesh.add(_core, ProcMesh.cylinder(0.006, 0.006, 0.3, 4), ProcMesh.neon(Color(1, 1, 1), 1.0), Vector3(cos(a) * 0.12, 0.2, sin(a) * 0.12), Vector3.ONE, Vector3(sin(a) * 0.6, 0, -cos(a) * 0.6), false)
			"bubble":
				ProcMesh.add(_core, ProcMesh.sphere(0.25, 18), ProcMesh.glass(color, 0.5, 1.0, 1.4), Vector3.ZERO, Vector3.ONE, Vector3.ZERO, false)
			_:
				ProcMesh.add(_core, ProcMesh.sphere(0.22, 16), ProcMesh.glass(color, 1.2, 0.6, 1.8), Vector3.ZERO, Vector3.ONE, Vector3.ZERO, false)
				ProcMesh.add(_core, ProcMesh.sphere(0.08, 10), ProcMesh.neon(Color(color, 1.0).lightened(0.4), 3.5), Vector3.ZERO, Vector3.ONE, Vector3.ZERO, false)
		_t = randf() * 6.0
		scale = Vector3.ONE * 0.01
		create_tween().tween_property(self, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _process(delta: float) -> void:
		_t += delta
		_core.position.y = 0.12 * sin(_t * 1.8)
		_core.rotation.y += delta * 0.7
		if kind == "bubble":
			global_position.y += delta * 0.15
		elif kind == "seed":
			global_position.x += sin(_t * 0.5) * delta * 0.25
			global_position.z += cos(_t * 0.4) * delta * 0.25

	func get_prompt() -> String:
		var k: Dictionary = phenomena.KINDS[kind]
		return "[E] Recoger %s" % k.name

	func interact(_player: Node, _hit: Vector3) -> void:
		phenomena.collect(self)

	func vanish() -> void:
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector3.ONE * 1.6, 0.12)
		tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.15)
		tw.tween_callback(queue_free)
