shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Terreno de isla: la hierba pasa de muerta a exuberante según la vitalidad del ecosistema.

uniform vec3 grass_dead : source_color = vec3(0.56, 0.5, 0.42);
uniform vec3 grass_lush : source_color = vec3(0.32, 0.86, 0.36);
uniform vec3 rock_color : source_color = vec3(0.78, 0.82, 0.9);
uniform vec3 sand_color : source_color = vec3(0.95, 0.9, 0.76);
uniform vec3 glow_color : source_color = vec3(0.4, 0.9, 1.0);
uniform float vitality : hint_range(0.0, 1.0) = 0.0;
uniform float water_level = -999.0;
uniform vec2 pond_center = vec2(0.0);
uniform float pond_radius = 0.0;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
// Texturas de detalle CC0 (ambientCG): se tiñen con la paleta estilizada de la isla.
uniform bool use_detail = false;
uniform sampler2D grass_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D grass_nrm : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D rock_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D rock_nrm : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float detail_scale = 0.35;

varying vec3 wpos;
varying vec3 wnorm;
varying vec3 lpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	lpos = VERTEX;
}

void fragment() {
	float n = texture(noise_tex, wpos.xz * 0.045).r;
	float n2 = texture(noise_tex, wpos.xz * 0.23 + vec2(0.37)).r;
	float lush_amt = clamp(vitality * 1.35 - (n - 0.5) * 0.9 - 0.1, 0.0, 1.0);
	vec3 grass = mix(grass_dead * (0.82 + 0.32 * n2), grass_lush * (0.78 + 0.45 * n2), lush_amt);
	float up = smoothstep(0.45, 0.78, wnorm.y);
	vec3 rock = rock_color * (0.72 + 0.4 * n);
	rock *= 0.88 + 0.12 * sin(lpos.y * 2.6 + n * 5.0);
	float pd = length(lpos.xz - pond_center);
	float sand = pond_radius > 0.0 ? (1.0 - smoothstep(pond_radius * 1.02, pond_radius * 1.3, pd)) * up : 0.0;
	vec3 col = mix(rock, grass, up);
	col = mix(col, sand_color * (0.9 + 0.15 * n2), sand);
	// Vetas luminosas en la base rocosa: tecnología y naturaleza fusionadas.
	float vein = smoothstep(0.93, 1.0, sin(lpos.y * 1.7 + n * 9.0)) * (1.0 - up);
	if (use_detail) {
		vec2 guv = wpos.xz * detail_scale;
		// Proyección lateral para la roca (evita estiramientos en los acantilados).
		vec2 ruv = (abs(wnorm.x) > abs(wnorm.z) ? wpos.zy : wpos.xy) * detail_scale * 0.6;
		vec3 g = texture(grass_tex, guv).rgb;
		vec3 r = texture(rock_tex, ruv).rgb;
		float gl = dot(g, vec3(0.333)) / 0.3;
		float rl = dot(r, vec3(0.333)) / 0.45;
		col *= mix(mix(0.6 + 0.4 * rl, 1.0, up), mix(0.55 + 0.45 * gl, 1.0, sand), up);
		vec3 nm = mix(texture(rock_nrm, ruv).rgb, texture(grass_nrm, guv).rgb, up);
		NORMAL_MAP = nm;
		NORMAL_MAP_DEPTH = 0.8;
	}
	ALBEDO = col;
	ROUGHNESS = mix(0.45, 0.82, up);
	SPECULAR = 0.45;
	EMISSION = glow_color * vein * (0.4 + vitality);
}
