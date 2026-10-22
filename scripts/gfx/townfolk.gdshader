shader_type spatial;
// The townsfolk (townfolk.gd): each vertex carries the kit's own colour (COLOR, linear) and, in UV2, its colour slot
// and how much lighter or darker than the slot's colour it is drawn (1 as the colour is; above 1 it is mixed toward
// white). A slot whose colour has alpha 0 keeps the kit's colour. Slot 8 is the top's colour, never camo (the inside
// of the camo jacket's collar); slot 9 is a worn pack's own colour.
// Camo (camo 1): the top and bottoms are patched in three tones instead, the patches cells of a pattern laid out on
// the body as it stands at rest (CUSTOM0), so they stay put on the cloth as it moves; like a forester's jacket, the
// chest and back and the thighs are plain, in the light tone.
render_mode cull_back, specular_schlick_ggx;

uniform vec4 skin : source_color = vec4(0.94, 0.78, 0.63, 1.0);
uniform vec4 hair : source_color = vec4(0.25, 0.16, 0.1, 1.0);
uniform vec4 eyes : source_color = vec4(0.28, 0.18, 0.12, 1.0);
uniform vec4 top : source_color = vec4(0.5, 0.5, 0.5, 0.0);
uniform vec4 bottom : source_color = vec4(0.5, 0.5, 0.5, 0.0);
uniform vec4 shoes : source_color = vec4(0.5, 0.5, 0.5, 0.0);
uniform vec4 hat : source_color = vec4(0.5, 0.5, 0.5, 0.0);
uniform vec4 pack : source_color = vec4(0.42, 0.48, 0.3, 1.0);
uniform float camo = 0.0;
uniform vec4 camo_light : source_color = vec4(0.6, 0.62, 0.38, 1.0);
uniform vec4 camo_mid : source_color = vec4(0.36, 0.48, 0.28, 1.0);
uniform vec4 camo_dark : source_color = vec4(0.23, 0.31, 0.2, 1.0);
// how big the patches are (metres, on the kit's body)
uniform float camo_cell = 0.045;

varying vec3 col;
varying vec3 rest;
varying float camo_on;
varying float camo_slot;
varying float light;

vec3 shade(vec3 c, float l) {
	return l <= 1.0 ? c * l : mix(c, vec3(1.0), clamp(l - 1.0, 0.0, 1.0));
}

vec3 hash3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}

void vertex() {
	int slot = int(UV2.x + 0.5);
	vec4 want = vec4(0.0);
	if (slot == 1) want = skin;
	else if (slot == 2) want = hair;
	else if (slot == 3) want = eyes;
	else if (slot == 4 || slot == 8) want = top;
	else if (slot == 5) want = bottom;
	else if (slot == 6) want = shoes;
	else if (slot == 7) want = hat;
	else if (slot == 9) want = pack;
	col = mix(COLOR.rgb, shade(want.rgb, UV2.y), want.a);
	rest = CUSTOM0.xyz;
	light = UV2.y;
	camo_on = (slot == 4 || slot == 5) ? camo : 0.0;
	camo_slot = float(slot);
}

void fragment() {
	vec3 c = col;
	// the plain panels: the jacket's body between the belt and the shoulders, the trousers above the knee
	bool plain = camo_slot < 4.5 ? (abs(rest.x) < 0.16 && rest.y > 0.71 && rest.y < 0.99) : rest.y > 0.40;
	if (camo_on > 0.5 && plain) {
		c = shade(camo_light.rgb, min(light, 1.0));
	} else if (camo_on > 0.5) {
		// the nearest of a jittered grid of points: its cell's tone
		vec3 p = rest / camo_cell;
		vec3 i = floor(p);
		vec3 f = fract(p);
		float best = 9.0;
		vec3 id = i;
		for (int z = -1; z <= 1; z++) {
			for (int y = -1; y <= 1; y++) {
				for (int x = -1; x <= 1; x++) {
					vec3 o = vec3(float(x), float(y), float(z));
					vec3 d = o + hash3(i + o) * 0.85 - f;
					float dd = dot(d, d);
					if (dd < best) {
						best = dd;
						id = i + o;
					}
				}
			}
		}
		float t = hash3(id).x;
		vec3 tone = t < 0.46 ? camo_light.rgb : (t < 0.76 ? camo_mid.rgb : camo_dark.rgb);
		c = shade(tone, min(light, 1.0));
	}
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
