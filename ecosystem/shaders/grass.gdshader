shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
// Briznas de hierba (MultiMesh) con viento. Crecen y reverdecen con la vitalidad.

uniform vec3 dead_color : source_color = vec3(0.55, 0.5, 0.38);
uniform vec3 lush_color : source_color = vec3(0.35, 0.9, 0.4);
uniform float vitality : hint_range(0.0, 1.0) = 0.0;
uniform float wind_strength = 0.18;
uniform float tint_variation = 0.25;

varying float h;
varying float rnd;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	h = UV.y;
	vec3 o = MODEL_MATRIX[3].xyz;
	rnd = hash(o.xz);
	VERTEX.y *= mix(0.35, 1.0, vitality) * (0.75 + 0.5 * rnd);
	float t = TIME * 1.7 + o.x * 0.31 + o.z * 0.23;
	float bend = h * h * wind_strength;
	VERTEX.x += (sin(t) + 0.4 * sin(t * 2.3)) * bend;
	VERTEX.z += cos(t * 0.8) * bend * 0.6;
}

void fragment() {
	float l = clamp(vitality * 1.4 - rnd * 0.5, 0.0, 1.0);
	vec3 c = mix(dead_color, lush_color * (1.0 - tint_variation * 0.5 + tint_variation * rnd), l);
	c *= mix(0.5, 1.15, h);
	ALBEDO = c;
	ROUGHNESS = 0.55;
	SPECULAR = 0.35;
	BACKLIGHT = c * 0.35;
}
