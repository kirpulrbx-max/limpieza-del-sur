shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_opaque, diffuse_burley;
// Alas de vidrio que aletean (cada instancia con su propia fase).

uniform vec4 wing_color : source_color = vec4(0.55, 0.85, 1.0, 0.75);
uniform float flap_speed = 14.0;

varying float side;

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	float phase = fract(sin(dot(o.xz, vec2(12.9, 78.2))) * 437.5) * 6.28;
	float ang = sin(TIME * flap_speed + phase) * 0.95;
	side = sign(VERTEX.x);
	float ax = abs(VERTEX.x);
	VERTEX.y += ax * sin(ang);
	VERTEX.x = side * ax * cos(ang);
}

void fragment() {
	vec2 c = UV - vec2(0.5);
	float shape = smoothstep(0.5, 0.42, length(vec2(c.x * 0.9, c.y * 1.2)));
	float f = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
	vec3 irid = 0.5 + 0.5 * cos(6.2831 * (UV.x + vec3(0.0, 0.33, 0.67)));
	vec3 col = mix(wing_color.rgb, irid, 0.35);
	ALBEDO = col;
	ALPHA = wing_color.a * shape;
	EMISSION = col * (0.5 + f);
	ROUGHNESS = 0.1;
}
