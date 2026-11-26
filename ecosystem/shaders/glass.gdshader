shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
// Cristal / burbuja iridiscente con borde de Fresnel y brillo propio.

uniform vec4 tint : source_color = vec4(0.6, 0.9, 1.0, 0.3);
uniform float glow = 0.4;
uniform float rim_power = 2.5;
uniform float iridescence = 0.3;
uniform float pulse_speed = 0.0;
instance uniform float intensity = 1.0;

void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	vec3 irid = 0.5 + 0.5 * cos(6.2831 * (f * 1.3 + vec3(0.0, 0.33, 0.67) + TIME * 0.05));
	vec3 c = mix(tint.rgb, irid, iridescence * f);
	float p = 1.0 + 0.25 * sin(TIME * pulse_speed);
	ALBEDO = c;
	ALPHA = clamp(tint.a + f * 0.65, 0.0, 1.0);
	EMISSION = c * glow * (0.35 + f) * p * intensity;
	ROUGHNESS = 0.04;
	METALLIC = 0.15;
	SPECULAR = 0.9;
}
