class_name IslandLayout
extends RefCounted
## Geometría determinista de las islas: contorno, altura del terreno y parcelas.
## La usan tanto el mundo 3D como la simulación (sin depender de nodos).

const RING_START := 5.6
const RING_STEP := 3.6
const PLOT_SPACING := 3.4

var def: IslandDef
var radius: float
var noise := FastNoiseLite.new()
var outline_noise := FastNoiseLite.new()


func _init(d: IslandDef, r: float) -> void:
	def = d
	radius = r
	noise.seed = d.noise_seed
	noise.frequency = 0.07
	noise.fractal_octaves = 3
	outline_noise.seed = d.noise_seed + 101
	outline_noise.frequency = 0.9


## Radio del contorno en la dirección angle (ligeramente irregular).
func edge_radius(angle: float) -> float:
	var n := outline_noise.get_noise_2d(cos(angle) * 1.5, sin(angle) * 1.5)
	return radius * (1.0 + 0.07 * n)


func height_at(x: float, z: float) -> float:
	var ang := atan2(z, x)
	var r := Vector2(x, z).length() / edge_radius(ang)
	var y := 1.1 * (1.0 - r * r)
	y += noise.get_noise_2d(x, z) * 0.7 * clampf((1.0 - r) * 2.5, 0.0, 1.0)
	if def.pond_radius > 0.0:
		var d := Vector2(x, z).distance_to(def.pond_offset) / def.pond_radius
		y -= 1.5 * (1.0 - smoothstep(0.55, 1.2, d))
	return y


func water_level() -> float:
	if def.pond_radius <= 0.0:
		return -999.0
	# Nivel algo por debajo del borde del estanque.
	var lowest := 99.0
	for i in 16:
		var a := TAU * i / 16.0
		var p := def.pond_offset + Vector2(cos(a), sin(a)) * def.pond_radius * 1.05
		lowest = minf(lowest, height_at(p.x, p.y))
	return lowest - 0.12


func is_in_pond(x: float, z: float, margin: float = 0.0) -> bool:
	return def.pond_radius > 0.0 and Vector2(x, z).distance_to(def.pond_offset) < def.pond_radius + margin


## Posiciones locales (x, z) de las primeras `count` parcelas, en anillos concéntricos.
func plot_positions(count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var ring := 0
	while out.size() < count and ring < 12:
		var r := RING_START + RING_STEP * ring
		if r > radius * 0.93 - 1.6:
			break
		var slots := int(floor(TAU * r / PLOT_SPACING))
		var offset := 0.5 * ring + PI * 0.5
		for i in slots:
			var a := offset + TAU * i / slots
			var p := Vector2(cos(a), sin(a)) * r
			if is_in_pond(p.x, p.y, 1.8):
				continue
			if r > edge_radius(a) - 1.8:
				continue
			out.append(p)
			if out.size() >= count:
				break
		ring += 1
	return out


## Posiciones locales de los cristales decorativos/de luz, cerca del borde.
func crystal_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = def.noise_seed * 13
	for i in def.crystal_count:
		var a := TAU * (i + rng.randf_range(-0.2, 0.2)) / maxf(1, def.crystal_count) + 0.3
		var rr := edge_radius(a) * rng.randf_range(0.82, 0.9)
		out.append(Vector2(cos(a), sin(a)) * rr)
	return out
