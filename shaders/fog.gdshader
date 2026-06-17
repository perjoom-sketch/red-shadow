shader_type canvas_item;
// Animated, domain-warped fbm fog for a mystical drifting mist.

uniform vec4 fog_color : source_color = vec4(0.45, 0.12, 0.22, 1.0);
uniform float speed = 0.03;
uniform float density = 0.45;
uniform vec2 scale = vec2(3.0, 2.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		v += amp * noise(p);
		p *= 2.0;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV * scale;
	float t = TIME * speed;
	float n = fbm(uv + vec2(t, t * 0.5));
	n = fbm(uv + vec2(n * 1.6 - t, n + t * 0.3)); // domain warp
	float a = smoothstep(0.25, 0.95, n) * density;
	COLOR = vec4(fog_color.rgb, a * fog_color.a);
}
