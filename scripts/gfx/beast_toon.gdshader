shader_type spatial;
render_mode diffuse_toon, specular_toon, cull_back;
// The new beasts (assets/beasts, beast_rig.gd): soft cel shading in flat, bright colours, as the creature packs they
// come from were painted. Every vertex carries what to paint it by (tools/import_new_beasts.gd): its part, how far
// out along it it is (tip), how much it faces forward and down (belly), a pattern coordinate and where it sits on
// the face. Each part takes its own colour, with optional tips (hands, feet, claws, spike tips), stripes round it or
// bands up it. The white follows the measured lower rim and ends under the lid. A ghost uses the same geometry.

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
// Independently fitted sockets in mesh order, including all six eyes on the three-berry form.
const int SOCKET_COUNT = 6;
uniform vec4 sockets[SOCKET_COUNT]; // centre (u,y), radii
uniform vec2 lids[SOCKET_COUNT]; // intercept and slope in normalized socket space
uniform float maturity = 1.0;
uniform float lid_shut = 0.0;
uniform vec3 lid_col = vec3(0.5);
uniform float ghost = 0.0;
uniform float rim = 0.35;
// a faint satin finish over the flat colours (surface_finish.gd, set by beast_rig.gd), triplanar in the model's units
uniform sampler2D skin_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float finish_scale = 2.0;
uniform float skin_level = 1.0;

varying vec4 attr;
// (the part, unblended: a face across two parts takes one of them whole, rather than whatever parts' numbers lie
// between theirs)
varying flat float part_id;
varying vec3 obj;
varying vec3 obj_n;

void vertex() {
	attr = COLOR;
	part_id = COLOR.r;
	obj = VERTEX * finish_scale;
	obj_n = abs(NORMAL);
}

vec3 eye_colour(int pair, vec2 p) {
	vec4 eye = sockets[pair];
	float upper = lids[pair].x + lids[pair].y * p.x;
	float bottom = -sqrt(max(0.0, 1.0 - p.x * p.x));
	float lid_edge = p.y - mix(upper, bottom - 0.015, lid_shut);
	float lid_aa = max(fwidth(lid_edge), 0.001);
	float open = 1.0 - smoothstep(-0.5 * lid_aa, 0.5 * lid_aa, lid_edge);
	vec2 centre = vec2(-0.04, mix(0.5 * (min(1.0, lids[pair].x) - 1.0), 0.08, maturity));
	float pupil = length((p - centre) * eye.zw) / max(0.0001, min(eye.z, eye.w)) - mix(0.54, 0.56, maturity);
	float aa = max(fwidth(pupil), 0.001);
	return mix(lid_col, mix(vec3(0.008), vec3(1.0), smoothstep(-0.5 * aa, 0.5 * aa, pupil)), open);
}

void fragment() {
	int part = clamp(int(part_id * 15.0 + 0.5), 0, PARTS - 1);
	vec3 c = part_col[part];
	float t = attr.g;
	if (part != EYE) {
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

		vec3 w = pow(obj_n, vec3(4.0));
		w /= max(w.x + w.y + w.z, 0.0001);
		c *= (texture(skin_tex, obj.zy).rgb * w.x + texture(skin_tex, obj.xz).rgb * w.y + texture(skin_tex, obj.xy).rgb * w.z) / skin_level;
	}
	if (UV.x < -2.0) {
		c = eye_colour(clamp(int(attr.b * 7.0 + 0.5), 0, SOCKET_COUNT - 1), UV + vec2(4.0, 0.0));
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
