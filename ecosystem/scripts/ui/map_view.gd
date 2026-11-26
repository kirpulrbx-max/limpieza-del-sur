extends Control
## Mapa cenital del archipiélago dibujado con datos reales: islas, puentes, parcelas,
## plantas, estructuras, fauna y posición del jugador.

var world: Node
var _t := 0.0

const STRUCT_COLORS := {
	"condenser": Color(0.3, 0.7, 1.0), "prism": Color(1.0, 0.85, 0.3), "seeder": Color(0.4, 1.0, 0.6),
	"collector": Color(0.5, 1.0, 1.0), "nest": Color(0.9, 0.9, 1.0),
}


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	draw_style_box(Aero.flat(Color(0.02, 0.15, 0.3, 0.55), Color(1, 1, 1, 0.4), 16, 1, 0), Rect2(Vector2.ZERO, size))
	if world == null:
		return
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for iv in world.islands.values():
		var p := Vector2(iv.global_position.x, iv.global_position.z)
		var r: float = iv.layout.radius + 4.0
		mn = mn.min(p - Vector2(r, r))
		mx = mx.max(p + Vector2(r, r))
	var span := mx - mn
	var sc := minf((size.x - 60.0) / span.x, (size.y - 60.0) / span.y)
	var off := (size - span * sc) * 0.5
	var to_map := func(w: Vector3) -> Vector2:
		return off + (Vector2(w.x, w.z) - mn) * sc
	# Puentes
	for b in world.bridges.values():
		draw_line(to_map.call(b.from_island.global_position), to_map.call(b.to_island.global_position), Color(0.6, 1.0, 1.0, 0.8), 3.0 * sc / 4.0 + 2.0, true)
	# Islas
	for iv in world.islands.values():
		var d: IslandDef = iv.def
		var c: Vector2 = to_map.call(iv.global_position)
		var r: float = iv.layout.radius * sc
		var unlocked := GameState.is_island_unlocked(d.id)
		var col := d.grass_dead.lerp(d.grass_lush, GameState.vitality) if unlocked else Color(0.6, 0.65, 0.75, 0.35)
		var outline := PackedVector2Array()
		for i in 49:
			var a := TAU * i / 48.0
			var er: float = iv.layout.edge_radius(a)
			outline.append(c + Vector2(cos(a), sin(a)) * er * sc)
		draw_colored_polygon(outline, col)
		draw_polyline(outline, Color(1, 1, 1, 0.8 if unlocked else 0.3), 2.0, true)
		if d.pond_radius > 0.0:
			draw_circle(c + d.pond_offset * sc, d.pond_radius * sc, Color(0.3, 0.75, 1.0, 0.9 if unlocked else 0.3))
		for cp in iv.layout.crystal_positions():
			draw_circle(c + cp * sc, 0.9 * sc, Color(d.crystal_color, 0.9 if unlocked else 0.3))
		var font := get_theme_default_font()
		var label := d.display_name + ("" if unlocked else "  (sellada)")
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(font, c + Vector2(-tw * 0.5, -r - 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.95 if unlocked else 0.5))
		if not unlocked:
			continue
		var plots: Array[Vector2] = iv.layout.plot_positions(GameState.plot_count(d.id))
		for i in plots.size():
			var pp: Vector2 = c + plots[i] * sc
			var plant := GameState.plant_at_plot(d.id, i)
			if plant.is_empty():
				draw_arc(pp, 0.8 * sc, 0, TAU, 12, Color(1, 1, 1, 0.6), 1.5, true)
			else:
				var pd := DB.plant(plant.species)
				var pc := pd.color.lerp(Color(0.55, 0.43, 0.28), 1.0 - float(plant.health))
				draw_circle(pp, (0.45 + 0.45 * float(plant.growth)) * sc, pc)
				if plant.bloom >= 1.0:
					draw_arc(pp, 1.0 * sc, 0, TAU, 12, Color(1, 0.9, 0.4), 2.0, true)
				if not plant.watered:
					draw_circle(pp, 0.3 * sc, Color(0.3, 0.7, 1.0))
	# Estructuras
	for s in GameState.structures:
		var iv = world.islands.get(s.island)
		if iv == null:
			continue
		var sp: Vector2 = to_map.call(iv.to_global(Vector3(s.x, 0, s.z)))
		var half := maxf(0.7 * sc, 4.0)
		draw_rect(Rect2(sp - Vector2(half, half), Vector2(half, half) * 2.0), STRUCT_COLORS.get(s.type, Color.WHITE))
		draw_rect(Rect2(sp - Vector2(half, half), Vector2(half, half) * 2.0), Color(0, 0, 0, 0.5), false, 1.0)
	# Jugador
	var pl: Node3D = world.player
	var ppos: Vector2 = to_map.call(pl.global_position)
	var fwd := -pl.global_transform.basis.z
	var dir := Vector2(fwd.x, fwd.z).normalized()
	var side := Vector2(-dir.y, dir.x)
	var pulse := 1.0 + 0.15 * sin(_t * 5.0)
	var tri := PackedVector2Array([ppos + dir * 12.0 * pulse, ppos - dir * 7.0 + side * 7.0, ppos - dir * 3.0, ppos - dir * 7.0 - side * 7.0])
	draw_colored_polygon(tri, Color(1.0, 0.4, 0.5))
	draw_polyline(tri + PackedVector2Array([tri[0]]), Color(1, 1, 1), 1.5, true)
	# Leyenda
	var font2 := get_theme_default_font()
	var y := 22.0
	for item in [["Planta (color = salud)", Color(0.4, 0.9, 0.5)], ["Parcela libre", Color(1, 1, 1, 0.7)], ["Floración lista", Color(1, 0.9, 0.4)],
			["Brote sin regar", Color(0.3, 0.7, 1.0)], ["Estructura", Color(0.5, 1.0, 1.0)], ["Tú", Color(1.0, 0.4, 0.5)]]:
		draw_circle(Vector2(22, y - 5), 6, item[1])
		draw_string(font2, Vector2(34, y), item[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.9))
		y += 20.0
