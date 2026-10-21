shader_type spatial;
render_mode diffuse_toon, specular_toon, cull_back;
// The new beasts (assets/beasts, beast_rig.gd): soft cel shading in flat, bright colours, as the creature packs they
// come from were painted. Every vertex carries what to paint it by (tools/import_new_beasts.gd): its part, how far
// out along it it is (tip), how much it faces forward and down (belly), a pattern coordinate and where it sits on
// the face. Each part takes its own colour, with optional tips (hands, feet, claws, spike tips), stripes round it or
// bands up it; the body and head can have a belly patch; an eye part is white with a pupil where it looks forward;
// and eyes can be painted on the face, a pair (or a pair on each of up to three faces: white, pupil, glint, an angry
// lid and brow). A ghost is the same beast in
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
// up to three pairs of painted eyes (a face each), each pair mirrored about z = eye_mid: (z from there, y) of the
// right one, its radius (0: no pair), and how far forward the face must be (x); style: lid (0 open .. 1 shut), brow
// (0 none .. 1 angry; < 0: as angry, none painted), pupil size, look up. lid_shut closes them all (blinking, sleep).
const int EYE_PAIRS = 3;
uniform vec4 eye_pos[EYE_PAIRS];
uniform vec4 eye_style[EYE_PAIRS];
uniform float eye_mid[EYE_PAIRS];
uniform float lid_shut = 0.0;
uniform vec3 eye_dark = vec3(0.06, 0.05, 0.08);
uniform vec3 lid_col = vec3(0.5);
uniform float ghost = 0.0;
uniform float rim = 0.35;

varying vec4 attr;
varying vec2 face;
// (the part, unblended: a face across two parts takes one of them whole, rather than whatever parts' numbers lie
// between theirs)
varying flat float part_id;

void vertex() {
	attr = COLOR;
	part_id = COLOR.r;
	face = UV2;
}

// The painted eyes over c, where the face is forward of each pair's eye_pos.w: outlined white with a pupil and its
// glint, the lid coming down over it (its edge a dark line) and the brow above, both slanting down to the nose the
// angrier it is (brow < 0: as angry, but no brow painted, where the sculpt has its own).
vec3 painted_eye(vec3 c) {
	float x = attr.a * 2.0 - 1.0;
	for (int i = 0; i < EYE_PAIRS; i++) {
		vec4 at = eye_pos[i];
		vec4 st = eye_style[i];
		if (at.z <= 0.0 || x < at.w) {
			continue;
		}
		vec2 p = vec2(abs(face.x - eye_mid[i]) - at.x, face.y - at.y) / at.z;
		// (p.x < 0 is the inner side, towards the nose)
		float d = length(p);
		float angry = abs(st.y);
		float bk = 0.55 * angry;
		if (st.y > 0.0 && abs(p.x) < 1.15 && abs(p.y - 1.15 - bk * p.x) < 0.2 * sqrt(1.0 + bk * bk)) {
			return eye_dark;
		}
		if (d > 1.0) {
			continue;
		}
		// the lid's edge: above the eye at lid 0, coming down to its bottom at 1 (shut), slanting less as it shuts
		float lid = max(st.x, lid_shut);
		float shut = lid * lid;
		float lk = 0.45 * angry * (1.0 - shut);
		float above = (p.y - 1.2 + 2.1 * shut - lk * p.x) / sqrt(1.0 + lk * lk);
		if (above > 0.0) {
			return above < 0.14 ? eye_dark : lid_col;
		}
		if (d > 0.86) {
			return eye_dark;
		}
		vec2 q = p - vec2(-0.12, st.w * 0.2 - 0.08);
		float pr = st.z;
		if (length(q) < pr) {
			return length(q - vec2(0.29) * pr) < pr * 0.28 ? vec3(1.0) : eye_dark;
		}
		return vec3(0.97, 0.96, 0.94);
	}
	return c;
}

void fragment() {
	int part = clamp(int(part_id * 15.0 + 0.5), 0, PARTS - 1);
	vec3 c = part_col[part];
	float t = attr.g;
	if (part == EYE) {
		// white with a pupil where it looks forward (t: its normal's x); with painted eyes, the face's colour with them
		// painted on it, as on the face (so a sculpted eyeball blinks with them)
		c = eye_pos[0].z > 0.0 ? painted_eye(c) : (t > 0.82 ? eye_dark : (t > 0.74 ? vec3(0.3) : vec3(0.97, 0.96, 0.94)));
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
