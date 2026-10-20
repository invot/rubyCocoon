shader_type spatial;
render_mode diffuse_toon, specular_toon, cull_back;
// The new beasts (assets/beasts, beast_rig.gd): soft cel shading in flat, bright colours, as the creature packs they
// come from were painted. Every vertex carries what to paint it by (tools/import_new_beasts.gd): its part, how far
// out along it it is (tip), how much it faces forward and down (belly), a pattern coordinate and where it sits on
// the face. Each part takes its own colour, with optional tips (hands, feet, claws, spike tips), stripes round it or
// bands up it; the body and head can have a belly patch; an eye part is white with a pupil where it looks forward;
// and two eyes can be painted on the face (white, pupil, glint, an angry lid and brow). A ghost is the same beast in
// black and purple, glowing faintly.

const int PARTS = 14;
const int EYE = 12;

uniform vec3 part_col[PARTS];
uniform vec3 tip_col[PARTS];
// tip colour from this far out (0..1; above 1: none) to tip_to, over tip_soft (0: a hard edge)
uniform float tip_from[PARTS];
uniform float tip_to[PARTS];
uniform float tip_soft[PARTS];
uniform vec3 stripe_col[PARTS];
// stripes round the part (how many), or bands up it (how many per unit of height); 0: none
uniform float stripes[PARTS];
uniform float bands[PARTS];
uniform vec3 belly_col = vec3(1.0);
// the belly patch on parts with belly_on, where they face forward and down more than belly_from (above 1: none)
uniform float belly_on[PARTS];
uniform float belly_from = 2.0;
// painted eyes, mirrored left and right on the face: (z, y) of the right one, its radius, and how far forward the
// face must be (x); style: lid (0 open .. 1 half closed), brow (0 none .. 1 angry), pupil size, look up
uniform vec4 eye_pos = vec4(0.0, 0.0, 0.0, 9.0);
uniform vec4 eye_style = vec4(0.0, 0.0, 0.5, 0.0);
uniform vec3 eye_dark = vec3(0.06, 0.05, 0.08);
uniform vec3 lid_col = vec3(0.5);
uniform float ghost = 0.0;
uniform float rim = 0.35;

varying vec4 attr;
varying vec2 face;

void vertex() {
	attr = COLOR;
	face = UV2;
}

vec3 painted_eye(vec3 c) {
	if (eye_pos.z <= 0.0 || attr.a * 2.0 - 1.0 < eye_pos.w) {
		return c;
	}
	vec2 p = vec2(abs(face.x) - eye_pos.x, face.y - eye_pos.y) / eye_pos.z;
	// (p.x < 0 is the inner side, towards the nose)
	float d = length(p);
	float brow_y = 1.15 + 0.55 * eye_style.y * p.x;
	if (eye_style.y > 0.0 && abs(p.x) < 1.15 && abs(p.y - brow_y) < 0.2) {
		return eye_dark;
	}
	if (d > 1.0) {
		return c;
	}
	if (d > 0.86) {
		return eye_dark;
	}
	float lid_y = mix(1.2, 0.15, eye_style.x) + 0.45 * eye_style.y * p.x;
	if (p.y > lid_y) {
		return lid_col;
	}
	vec2 q = p - vec2(-0.12, eye_style.w * 0.2 - 0.08);
	if (length(q) < eye_style.z) {
		if (length(q - vec2(0.18, 0.18) * eye_style.z * 1.6) < eye_style.z * 0.28) {
			return vec3(1.0);
		}
		return eye_dark;
	}
	return vec3(0.97, 0.96, 0.94);
}

void fragment() {
	int part = clamp(int(attr.r * 15.0 + 0.5), 0, PARTS - 1);
	vec3 c = part_col[part];
	float t = attr.g;
	if (part == EYE) {
		c = t > 0.82 ? eye_dark : (t > 0.74 ? vec3(0.3) : vec3(0.97, 0.96, 0.94));
	} else {
		if (tip_from[part] <= 1.0) {
			float on = smoothstep(tip_from[part] - tip_soft[part] - 0.0001, tip_from[part], t) * (1.0 - step(tip_to[part], t));
			c = mix(c, tip_col[part], on);
		}
		if (stripes[part] > 0.0 && fract(UV.x * stripes[part]) < 0.5) {
			c = stripe_col[part];
		}
		if (bands[part] > 0.0 && fract(UV.y * bands[part]) < 0.45) {
			c = stripe_col[part];
		}
		if (belly_on[part] > 0.5 && attr.b > belly_from) {
			c = belly_col;
		}
		if (part == 0 || part == 1) {
			c = painted_eye(c);
		}
	}
	if (ghost > 0.5) {
		float l = dot(c, vec3(0.3, 0.55, 0.15));
		c = mix(vec3(0.05, 0.02, 0.09), vec3(0.55, 0.25, 0.95), smoothstep(0.15, 0.95, l));
		EMISSION = c * 0.35;
	}
	ALBEDO = c;
	ROUGHNESS = 0.85;
	SPECULAR = 0.15;
	RIM = rim;
	RIM_TINT = 0.6;
}
