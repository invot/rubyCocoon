shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;
// The title's dragon, far off and half hidden: its own small render (view_tex, from a SubViewport) softened by a blur,
// with banks of night mist drifting across it. The mist fades out before the card's edges. `t`: the time, from the
// script.
uniform sampler2D view_tex : source_color, filter_linear;
uniform vec2 texel = vec2(0.0016, 0.0021);
uniform float spread = 2.6;
uniform float t = 0.0;
uniform vec4 mist : source_color = vec4(0.2, 0.24, 0.4, 1.0);
uniform float thickness = 0.4;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec4 d = vec4(0.0);
	float total = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			float w = (x == 0 ? 2.0 : 1.0) * (y == 0 ? 2.0 : 1.0);
			d += texture(view_tex, UV + vec2(float(x), float(y)) * texel * spread) * w;
			total += w;
		}
	}
	d /= total;
	float edge = smoothstep(0.0, 0.2, UV.x) * smoothstep(1.0, 0.8, UV.x) * smoothstep(0.0, 0.25, UV.y) * smoothstep(1.0, 0.7, UV.y);
	float m = fbm(UV * vec2(3.5, 2.2) + vec2(t * 0.035, t * 0.008));
	float ma = smoothstep(0.45, 0.85, m) * thickness * edge;
	// (the blur thins the wings out: firm them up again)
	float da = clamp(d.a * 1.6, 0.0, 1.0);
	float a = ma + da * (1.0 - ma);
	ALBEDO = (mist.rgb * ma + d.rgb * da * (1.0 - ma)) / max(a, 0.001);
	ALPHA = a;
}
