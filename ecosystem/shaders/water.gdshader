shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;
// Agua transparente con refracción, absorción por profundidad y espuma de orilla.
// "clarity" pasa de agua turbia a agua cristalina al progresar.

uniform vec3 clear_color : source_color = vec3(0.3, 0.85, 1.0);
uniform vec3 murky_color : source_color = vec3(0.36, 0.4, 0.26);
uniform vec3 deep_color : source_color = vec3(0.02, 0.32, 0.62);
uniform float clarity : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D normal_a : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D normal_b : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;

void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 uv = world.xz;
	vec3 n1 = texture(normal_a, uv * 0.11 + TIME * vec2(0.021, 0.013)).rgb;
	vec3 n2 = texture(normal_b, uv * 0.19 - TIME * vec2(0.017, 0.026)).rgb;
	NORMAL_MAP = normalize(mix(n1, n2, 0.5));
	NORMAL_MAP_DEPTH = 0.55;

	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec4 view = INV_PROJECTION_MATRIX * ndc;
	view.xyz /= view.w;
	float wdepth = clamp(VERTEX.z - view.z, 0.0, 20.0);

	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	vec2 off = (n1.xy - 0.5) * 0.04 * clamp(wdepth, 0.0, 1.0);
	vec3 refr = texture(screen_tex, SCREEN_UV + off).rgb;
	vec3 tint = mix(murky_color, clear_color, clarity);
	float absorb = 1.0 - exp(-wdepth * mix(2.8, 0.55, clarity));
	float transmission = (1.0 - absorb * mix(0.95, 0.7, clarity)) * (1.0 - fres * 0.7);
	float foam = (1.0 - smoothstep(0.0, 0.22, wdepth)) * (0.6 + 0.4 * sin(TIME * 2.0 + uv.x * 3.0));
	vec3 body = mix(tint, deep_color * mix(0.5, 1.0, clarity), absorb * 0.7);
	ALBEDO = mix(body, vec3(1.0), foam * 0.7) * (1.0 - transmission * 0.85);
	EMISSION = refr * transmission * mix(0.8, 1.0, clarity) * tint * 1.15;
	ROUGHNESS = 0.03;
	METALLIC = 0.0;
	SPECULAR = 0.75;
}
