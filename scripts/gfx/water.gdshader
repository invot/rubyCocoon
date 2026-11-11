shader_type spatial;
render_mode cull_disabled;
#include "res://scripts/gfx/water_motion.gdshaderinc"
// Clear, depth-coloured water on all three renderers. Falling sheets share its transparency and use vertical flow lines.
// One depth read; no screen-colour copy, simulation viewport, or per-frame CPU work.

uniform sampler2DArray frames : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
uniform float frame_count = 10.0;
uniform float fps = 6.0;
uniform vec4 tint : source_color = vec4(0.23, 0.56, 0.88, 1.0);
uniform float opacity = 0.82;
uniform float glow = 0.0;
uniform float spec = 0.4;
uniform float wave_height = 0.045;
uniform bool fall_swell = false;
uniform bool fall_rim = false;
// Distant battle scenery has no modelled bed. Ordinary water always uses the actual scene depth.
uniform float backdrop_depth = 0.0;
uniform float absorption_strength = 1.35;
uniform float fall_stretch = 1.0;
uniform float froth = 0.3;
uniform float tex_scale = 0.5;
uniform vec2 drift = vec2(0.0, 0.03);
// Optional beach profile, shared with shoreline.gd. The five-centimetre wading shelf stays calm.
uniform vec4 shore = vec4(0.0);
uniform vec3 shore_levels = vec3(-0.12, -0.17, -1.65);

varying vec3 wpos;
varying vec3 wnorm;
varying vec2 flow_uv;

// A connected network of rounded, irregular light cells. The sites move independently and the domain bends,
// so the honeycomb breathes and reshapes instead of sliding a fixed grid across the surface.
float light_cells(vec2 p) {
	p += vec2(sin(p.y * 1.4 + TIME * 0.085), cos(p.x * 1.25 - TIME * 0.075)) * 0.38;
	vec2 cell = floor(p);
	vec2 local = fract(p);
	float first = 8.0;
	float second = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbour = vec2(float(x), float(y));
			vec2 seed = cell + neighbour;
			vec2 phase = fract(sin(vec2(dot(seed, vec2(127.1, 311.7)), dot(seed, vec2(269.5, 183.3)))) * 43758.5453);
			vec2 site = 0.5 + 0.25 * sin(phase * 6.283185 + TIME * vec2(0.10, 0.085));
			vec2 delta = neighbour + site - local;
			float distance_sq = dot(delta, delta);
			second = min(second, max(first, distance_sq));
			first = min(first, distance_sq);
		}
	}
	float edge = second - first;
	float aa = max(fwidth(edge), 0.012);
	float core = 1.0 - smoothstep(0.018, 0.075 + aa, edge);
	float halo = 1.0 - smoothstep(0.04, 0.24 + aa, edge);
	return core * 0.74 + halo * 0.26;
}

vec3 water_colour(float absorption) {
	vec3 shallow = mix(vec3(0.025, 0.28, 0.22), tint.rgb, 0.18);
	vec3 deep = tint.rgb * vec3(0.38, 0.66, 0.78);
	return mix(shallow, deep, absorption);
}

float beach_bottom(vec2 p) {
	float wade_end = shore.w - 2.5;
	float curve = (sin(p.x * 0.42) + sin(p.x * 0.93) * 0.35) * 0.3;
	return p.y <= wade_end ? shore_levels.y * smoothstep(shore.y + curve, wade_end, p.y)
		: mix(shore_levels.y, shore_levels.z, smoothstep(wade_end, shore.w, p.y));
}

bool on_beach(vec2 p) {
	return shore.z > shore.x && p.x >= shore.x && p.x <= shore.z && p.y >= shore.y;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	flow_uv = UV;
	float swell = 0.0;
	if (glow == 0.0 && (abs(wnorm.y) > 0.5 || fall_swell)) {
		float calm = on_beach(wpos.xz) ? smoothstep(0.04, 0.4, shore_levels.x - beach_bottom(wpos.xz)) : 1.0;
		swell = water_swell(wpos.xz, TIME) * wave_height * calm;
		VERTEX.y += swell;
		wpos.y += swell;
	}
}

void fragment() {
	float f = mod(floor(TIME * fps), frame_count);
	vec3 col;
	float alpha = opacity;
	float emission = glow;
	float depth = 0.0;
	float absorption = 0.0;
	if (glow == 0.0) {
		float scene_depth = texture(depth_texture, SCREEN_UV).r;
		#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
			vec3 ndc = vec3(SCREEN_UV, scene_depth) * 2.0 - 1.0;
		#else
			vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, scene_depth);
		#endif
		vec4 scene = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		vec3 behind = scene.xyz / scene.w;
		// Falling sheets absorb across their face, horizontal water down into its bed: one shared opacity rule.
		depth = abs(wnorm.y) > 0.5 ? max(wpos.y - behind.y, backdrop_depth) : max(dot(wpos - behind, wnorm), 0.0);
		absorption = 1.0 - exp(-depth * absorption_strength);
		alpha = min(opacity, mix(0.08, 0.98, absorption)) * smoothstep(0.0, 0.025, depth);
	}
	if (glow > 0.0) {
		vec2 uv = abs(wnorm.y) > 0.5 ? wpos.xz * tex_scale + drift * TIME
			: vec2(wpos.x + wpos.z, wpos.y / fall_stretch) * tex_scale + vec2(0.0, 1.2 / fall_stretch) * TIME;
		vec3 c = texture(frames, vec3(uv, f)).rgb;
		col = c;
	} else if (abs(wnorm.y) <= 0.5) {
		// Quiet vertical stream lines, with a slow downward pulse. No honeycomb or noisy texture frames on a fall.
		float side = wpos.x + wpos.z;
		float stretch = clamp(fall_stretch, 1.0, 1.8);
		float down = (wpos.y + TIME * 0.5) / stretch;
		float bend = sin(down * 2.8 + side * 1.7) * 0.35 + sin(down * 5.1 - side * 2.0) * 0.12;
		float lane = sin(side * 13.0 + bend);
		float aa = max(fwidth(lane), 0.015);
		float lines = 1.0 - smoothstep(0.045, 0.11 + aa, abs(lane));
		float travel = smoothstep(-0.25, 0.5, sin(down * 4.0 + sin(side * 7.0))
			+ 0.35 * sin(down * 7.3 - side * 4.0));
		col = water_colour(absorption);
		col = mix(col, vec3(0.88, 0.98, 0.94), lines * travel * (0.42 + froth * 0.08));
		NORMAL = normalize((VIEW_MATRIX * vec4(normalize(wnorm + vec3(0.0, 0.65, 0.0)), 0.0)).xyz);
		emission = 0.04;
	} else {
		// Real transparency reveals the existing sand, rocks, hulls and feet. Deep water absorbs the bottom.
		col = water_colour(absorption);

		// Continuous crossing wave normals, including smaller ripples between mesh vertices.
		vec2 p = wpos.xz;
		vec2 phases = water_phases(p, TIME);
		float a = phases.x;
		float b = phases.y;
		float crest_light = smoothstep(0.8, 1.35, sin(a) + 0.45 * sin(b));
		col += vec3(0.025, 0.045, 0.04) * crest_light * smoothstep(0.12, 0.6, depth);
		vec2 slope = (vec2(0.78, 1.18) * cos(a) + vec2(-1.42, 0.55) * cos(b) * 0.45) * wave_height;
		slope += vec2(cos(dot(p, vec2(5.2, 3.8)) - TIME * 2.3), cos(dot(p, vec2(-3.8, 4.6)) - TIME * 1.8)) * 0.022;
		slope *= smoothstep(0.015, 0.18, depth);
		NORMAL = normalize((VIEW_MATRIX * vec4(normalize(vec3(-slope.x, 1.0, -slope.y)), 0.0)).xyz);

		// Soft caustic honeycomb reads through the shallows and remains a quieter surface shimmer offshore.
		// Subtract the flow offset to carry the light downstream, with a much slower change of cell shape.
		float cells = light_cells((p - drift * TIME) * 0.8);
		float caustic = cells * smoothstep(0.015, 0.12, depth) * mix(0.055, 0.13, exp(-depth * 0.65));
		col = mix(col, vec3(0.88, 0.98, 0.94), caustic);
		alpha = max(alpha, caustic * 0.8);

		// Depth intersections follow any opaque mesh entering the water, including rocks and dock supports.
		float lace = 0.65 + 0.35 * sin(p.x * 13.0 + sin(p.y * 9.0) + TIME * 1.7);
		float contact = (1.0 - smoothstep(0.025, 0.16, depth)) * 0.85;
		float ring = sin(depth * 30.0 - TIME * 1.65 + sin(p.x * 2.0 + p.y * 2.4) * 0.6);
		float foam = max(contact, smoothstep(0.78, 0.98, ring) * (1.0 - smoothstep(0.08, 0.4, depth)) * lace * 0.6);
		if (on_beach(p)) {
			float bed = beach_bottom(p);
			float still_depth = shore_levels.x - bed;
			if (still_depth <= 0.0) { discard; }
			// Two broken, gently curling wash lines travel towards the dry sand.
			float curl = sin(p.x * 0.62 + TIME * 0.12) * 0.16 + sin(p.x * 1.35) * 0.05;
			float wash = sin((p.y + curl) * 4.1 + TIME * 1.25);
			float crest = smoothstep(0.93, 0.995, wash) * (1.0 - smoothstep(0.1, 0.65, still_depth));
			// Distinguish a rock's surface from the shallow sand, so the entire wading shelf never turns white.
			float asset_contact = smoothstep(0.02, 0.12, still_depth - depth);
			foam = max(foam * asset_contact, crest * lace * 0.8);
			alpha *= smoothstep(0.0, 0.02, still_depth);
		}
		col = mix(col, vec3(0.92, 0.98, 0.98), foam);
		alpha = max(alpha, foam * 0.92);
		emission = 0.04;
	}
	// The narrow crest belongs to the joined rim, so it follows the same vertices through every swell.
	if (glow == 0.0 && fall_rim && flow_uv.x > 0.5) {
		float crest = 1.0 - smoothstep(0.015, 0.055, flow_uv.y);
		col = mix(col, vec3(0.96, 0.99, 1.0), crest);
		alpha = max(alpha, crest * 0.9);
	}
	ALBEDO = col;
	EMISSION = col * emission;
	// Preserve the existing prop-fade multiplier.
	ALPHA *= alpha;
	ROUGHNESS = glow > 0.0 ? 0.18 : 0.3;
	SPECULAR = glow > 0.0 ? 0.7 : spec;
}
