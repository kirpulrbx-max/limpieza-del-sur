shader_type sky;
// Cielo infinito: degradado, sol, estrellas y nubes por encima y por debajo de las islas.

uniform vec3 top_color : source_color = vec3(0.16, 0.5, 0.95);
uniform vec3 horizon_color : source_color = vec3(0.68, 0.9, 1.0);
uniform vec3 bottom_color : source_color = vec3(0.5, 0.78, 1.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.82);
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform float cloud_amount : hint_range(0.0, 1.0) = 0.55;
uniform float cloud_offset = 0.0;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x),
		mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float y = d.y;
	vec3 col = mix(horizon_color, top_color, smoothstep(0.0, 0.65, y));
	col = mix(col, bottom_color, smoothstep(0.0, -0.6, y));
	if (LIGHT0_ENABLED) {
		float sd = max(dot(d, LIGHT0_DIRECTION), 0.0);
		col += sun_color * (pow(sd, 700.0) * 8.0 + pow(sd, 10.0) * 0.22) * (1.0 - night);
	}
	if (!AT_CUBEMAP_PASS) {
		if (night > 0.01) {
			vec3 p = floor(d * 220.0);
			float s = step(0.9965, hash3(p));
			col += vec3(s) * night * smoothstep(-0.2, 0.25, y);
		}
		vec2 cuv = d.xz / (abs(y) + 0.22) * 0.9 + vec2(cloud_offset, cloud_offset * 0.35);
		float c = fbm(cuv);
		c = smoothstep(0.62 - cloud_amount * 0.3, 0.92, c);
		float band = 1.0 - smoothstep(0.35, 0.9, abs(y));
		vec3 cloud_col = mix(vec3(1.0, 1.0, 1.0), vec3(0.25, 0.3, 0.5), night);
		col = mix(col, cloud_col, c * 0.8 * band);
	}
	COLOR = col;
}
