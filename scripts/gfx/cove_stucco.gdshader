shader_type spatial;
// Painted plaster for Cocoon Cove's kit houses (cove_buildings.gd): the house's stucco colour with soft trowel sweeps
// and a gentle drift of tone across each wall, a touch of weathering low down near the ground. Mapped from the world
// (triplanar), so every wall of a house shares one finish whatever the kit's UVs do. Clean and painted, no grain.
uniform vec4 paint : source_color = vec4(0.92, 0.84, 0.66, 1.0);
// how strong the sweeps and drift are (0 = flat paint)
uniform float relief = 1.0;

varying vec3 wpos;
varying vec3 wnorm;
varying float local_y;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	local_y = VERTEX.y;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// trowel sweeps over one plane of the wall: long strokes, mostly level, a finer ripple inside them
float sweeps(vec2 p) {
	float broad = vnoise(vec2(p.x * 0.9, p.y * 3.2));
	float fine = vnoise(vec2(p.x * 2.6 + 4.1, p.y * 7.0 + 1.7));
	return broad * 0.7 + fine * 0.3;
}

uniform float building_opacity = 1.0;

void fragment() {
	// Screen-door coverage keeps the opaque pipeline and hides interior surfaces.
	if (fract(dot(floor(FRAGCOORD.xy), vec2(0.754877666, 0.569840296))) >= building_opacity) discard;
	vec3 n = abs(wnorm);
	n /= max(n.x + n.y + n.z, 0.001);
	float s = sweeps(vec2(wpos.z, wpos.y)) * n.x + sweeps(vec2(wpos.x, wpos.y)) * n.z + vnoise(wpos.xz * 2.0) * n.y;
	float drift = vnoise(vec2(wpos.x + wpos.z, wpos.y) * 0.3 + vec2(9.0, 2.0));
	float tone = 1.0 + relief * (0.07 * (s - 0.5) + 0.06 * (drift - 0.5));
	// a little dust and shade low on the wall (the kit's metres: its floor is at 0)
	tone *= mix(0.9, 1.0, smoothstep(0.0, 1.3, local_y));
	ALBEDO = paint.rgb * tone;
	ROUGHNESS = 0.92;
	SPECULAR = 0.12;
}
