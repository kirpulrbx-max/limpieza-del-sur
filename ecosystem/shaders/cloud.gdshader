shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Nubes volumétricas falsas: billboards suaves en MultiMesh.

uniform vec3 light_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 shade_color : source_color = vec3(0.72, 0.82, 0.97);
uniform float opacity = 0.85;

varying float rnd;

void vertex() {
	rnd = fract(sin(dot(MODEL_MATRIX[3].xz, vec2(12.9898, 78.233))) * 43758.5453);
	mat4 bb = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * bb * mat4(vec4(sx, 0, 0, 0), vec4(0, sy, 0, 0), vec4(0, 0, 1, 0), vec4(0, 0, 0, 1));
}

void fragment() {
	vec2 c = UV - 0.5;
	float d = length(c) * 2.0;
	float a = smoothstep(1.0, 0.15, d);
	a *= 0.85 + 0.15 * sin(atan(c.y, c.x) * 5.0 + rnd * 6.0);
	vec3 col = mix(shade_color, light_color, smoothstep(0.75, 0.15, UV.y));
	ALBEDO = col;
	ALPHA = a * opacity;
}
