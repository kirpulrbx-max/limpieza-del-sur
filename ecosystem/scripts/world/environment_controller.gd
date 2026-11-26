extends Node3D
## Cielo, sol/luna, niebla, nubes y partículas ambientales. Ciclo día/noche y
## saturación ligada a la vitalidad del ecosistema (mundo gris -> mundo vivo).

const SKY_SHADER := preload("res://shaders/sky.gdshader")
const CLOUD_SHADER := preload("res://shaders/cloud.gdshader")

var env: Environment
var sky_mat: ShaderMaterial
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var bubbles: GPUParticles3D
var fireflies: GPUParticles3D
var cloud_mat: ShaderMaterial
var follow: Node3D
var _cloud_offset := 0.0

const DAY := {"top": Color(0.13, 0.48, 0.95), "hor": Color(0.66, 0.9, 1.0), "bot": Color(0.45, 0.76, 1.0)}
const DUSK := {"top": Color(0.25, 0.3, 0.7), "hor": Color(1.0, 0.68, 0.5), "bot": Color(0.6, 0.55, 0.85)}
const NIGHT := {"top": Color(0.02, 0.04, 0.14), "hor": Color(0.1, 0.16, 0.36), "bot": Color(0.05, 0.08, 0.22)}


func _ready() -> void:
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_light_color = DAY.hor
	env.fog_density = 0.004
	env.fog_aerial_perspective = 0.6
	env.fog_sky_affect = 0.0
	env.ssao_enabled = false
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.7
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.3
	sun.shadow_enabled = SaveManager.settings.get("shadows", true)
	sun.directional_shadow_max_distance = 60.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.shadow_blur = 1.5
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.light_energy = 0.0
	moon.shadow_enabled = false
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(moon)

	_build_clouds()
	bubbles = _make_ambient(80, ProcMesh.sphere(0.12, 10), ProcMesh.glass(Color(0.85, 1.0, 1.0, 0.06), 0.4, 1.0, 1.4), Vector3(0, 0.35, 0), 14.0)
	fireflies = _make_ambient(90, ProcMesh.sphere(0.04, 6), ProcMesh.neon(Color(0.8, 1.0, 0.5), 5.0), Vector3(0, 0.05, 0), 8.0)


func apply_settings() -> void:
	sun.shadow_enabled = SaveManager.settings.get("shadows", true)


func _build_clouds() -> void:
	cloud_mat = ShaderMaterial.new()
	cloud_mat.shader = CLOUD_SHADER
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	mm.mesh = q
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var xfs: Array[Transform3D] = []
	for c in 70:
		var a := rng.randf() * TAU
		var r := rng.randf_range(45.0, 230.0)
		var center := Vector3(cos(a) * r, rng.randf_range(-70.0, -18.0) if rng.randf() < 0.7 else rng.randf_range(20.0, 60.0), sin(a) * r)
		var puffs := rng.randi_range(4, 8)
		for p in puffs:
			var s := rng.randf_range(10.0, 26.0)
			var off := Vector3(rng.randf_range(-14, 14), rng.randf_range(-3, 4), rng.randf_range(-14, 14))
			xfs.append(Transform3D(Basis().scaled(Vector3(s * 1.4, s, 1.0)), center + off))
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = cloud_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 500.0
	add_child(mmi)


func _make_ambient(amount: int, mesh: Mesh, mat: Material, vel: Vector3, extent: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 12.0
	p.preprocess = 6.0
	p.visibility_aabb = AABB(Vector3(-40, -20, -40), Vector3(80, 40, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(extent * 1.6, 3.0, extent * 1.6)
	pm.direction = vel.normalized() if vel.length() > 0 else Vector3.UP
	pm.spread = 25.0
	pm.initial_velocity_min = vel.length() * 0.5
	pm.initial_velocity_max = vel.length() * 1.5
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 3.0
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	p.process_material = pm
	p.draw_pass_1 = mesh
	p.material_override = mat
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


func _mix(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	return {"top": a.top.lerp(b.top, t), "hor": a.hor.lerp(b.hor, t), "bot": a.bot.lerp(b.bot, t)}


func _process(delta: float) -> void:
	var tod := GameState.time_of_day
	var v := GameState.vitality
	# Sol: amanece en 0.25, mediodía 0.5, anochece en 0.75.
	var ang := (tod - 0.25) * TAU
	var elev := sin(ang)
	sun.look_at_from_position(Vector3.ZERO, -Vector3(cos(ang) * 0.6, maxf(elev, -0.2), 0.5).normalized(), Vector3.UP)
	moon.look_at_from_position(Vector3.ZERO, -Vector3(-cos(ang) * 0.6, maxf(-elev, 0.1), -0.4).normalized(), Vector3.UP)
	var day := GameState.daylight()
	var dusk := clampf(1.0 - absf(elev) * 3.5, 0.0, 1.0)
	var pal := _mix(NIGHT, DAY, smoothstep(0.15, 0.85, day))
	pal = _mix(pal, DUSK, dusk * 0.7)
	# Un ecosistema muerto tiene un cielo apagado.
	var grey := 1.0 - v
	for k in pal:
		var c: Color = pal[k]
		var l := c.get_luminance()
		pal[k] = c.lerp(Color(l, l, l * 1.05), grey * 0.45)
	sky_mat.set_shader_parameter("top_color", pal.top)
	sky_mat.set_shader_parameter("horizon_color", pal.hor)
	sky_mat.set_shader_parameter("bottom_color", pal.bot)
	sky_mat.set_shader_parameter("night", 1.0 - smoothstep(0.15, 0.55, day))
	_cloud_offset += delta * 0.004
	sky_mat.set_shader_parameter("cloud_offset", _cloud_offset)
	sun.light_energy = clampf(elev * 3.0, 0.0, 1.0) * 1.35
	sun.light_color = Color(1.0, 0.96, 0.88).lerp(Color(1.0, 0.62, 0.4), dusk)
	moon.light_energy = clampf(-elev * 3.0, 0.0, 1.0) * 0.35
	env.fog_light_color = pal.hor
	env.ambient_light_energy = 0.55 + 0.5 * day
	env.adjustment_saturation = lerpf(0.72, 1.18, v)
	env.fog_density = lerpf(0.0032, 0.0012, v)
	cloud_mat.set_shader_parameter("light_color", Color(1, 1, 1).lerp(Color(0.32, 0.38, 0.6), 1.0 - day).lerp(Color(1.0, 0.8, 0.7), dusk * 0.6))
	cloud_mat.set_shader_parameter("shade_color", pal.bot.lerp(Color(0.8, 0.85, 1.0), 0.4))
	if follow:
		var fp := follow.global_position
		bubbles.global_position = fp
		fireflies.global_position = fp
	bubbles.amount_ratio = 0.15 + 0.85 * v
	fireflies.amount_ratio = (1.0 - day) * v
