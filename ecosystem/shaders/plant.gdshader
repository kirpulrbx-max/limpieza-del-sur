shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
// Hojas brillantes con barniz (clearcoat). Se marchitan según la salud de la planta.

uniform vec3 base_color : source_color = vec3(0.3, 0.85, 0.4);
uniform vec3 dead_color : source_color = vec3(0.55, 0.43, 0.28);
uniform float translucency = 0.35;
uniform float emission_strength = 0.0;
uniform float sway = 0.04;
instance uniform float health = 1.0;
instance uniform float pulse = 0.0;

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	float t = TIME * 1.3 + o.x * 0.7 + o.z * 0.5;
	VERTEX.x += sin(t) * sway * VERTEX.y;
	VERTEX.z += cos(t * 0.9) * sway * 0.6 * VERTEX.y;
}

void fragment() {
	vec3 c = mix(dead_color, base_color, smoothstep(0.1, 0.8, health));
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = c;
	ROUGHNESS = 0.3;
	SPECULAR = 0.6;
	CLEARCOAT = 0.7;
	CLEARCOAT_ROUGHNESS = 0.08;
	BACKLIGHT = c * translucency;
	EMISSION = c * (emission_strength + pulse * 0.9) * (0.3 + f) + vec3(f) * 0.06 * health;
}
