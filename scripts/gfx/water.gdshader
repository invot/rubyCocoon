shader_type spatial;
render_mode cull_disabled;
// Clear, depth-coloured water on all three renderers. Lava and falling sheets keep their texture animation.
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
	float swell = 0.0;
	if (glow == 0.0 && abs(wnorm.y) > 0.5) {
		float calm = on_beach(wpos.xz) ? smoothstep(0.04, 0.4, shore_levels.x - beach_bottom(wpos.xz)) : 1.0;
		swell = (sin(dot(wpos.xz, vec2(0.78, 1.18)) - TIME * 1.35)
			+ 0.45 * sin(dot(wpos.xz, vec2(-1.42, 0.55)) - TIME * 1.05)) * wave_height * calm;
		VERTEX.y += swell;
		wpos.y += swell;
	}
}

void fragment() {
	float f = mod(floor(TIME * fps), frame_count);
	vec3 col;
	float alpha = opacity;
	float emission = glow;
	if (glow > 0.0 || abs(wnorm.y) <= 0.5) {
		vec2 uv = abs(wnorm.y) > 0.5 ? wpos.xz * tex_scale + drift * TIME
			: vec2(wpos.x + wpos.z, wpos.y / fall_stretch) * tex_scale + vec2(0.0, 1.2 / fall_stretch) * TIME;
		vec3 c = texture(frames, vec3(uv, f)).rgb;
		col = glow > 0.0 ? c : mix(tint.rgb * (0.62 + 0.55 * c), vec3(0.92, 0.96, 1.0), froth * c.r);
	} else {
		float scene_depth = texture(depth_texture, SCREEN_UV).r;
		#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
			vec3 ndc = vec3(SCREEN_UV, scene_depth) * 2.0 - 1.0;
		#else
			vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, scene_depth);
		#endif
		vec4 scene = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		vec3 bottom = scene.xyz / scene.w;
		float depth = max(wpos.y - bottom.y, backdrop_depth);
		// Real transparency reveals the existing sand, rocks, hulls and feet. Deep water absorbs the bottom.
		float absorption = 1.0 - exp(-depth * absorption_strength);
		vec3 shallow = mix(vec3(0.025, 0.28, 0.22), tint.rgb, 0.18);
		vec3 deep = tint.rgb * vec3(0.38, 0.66, 0.78);
		col = mix(shallow, deep, absorption);
		alpha = min(opacity, mix(0.08, 0.98, absorption));
		alpha *= smoothstep(0.0, 0.025, depth);

		// Continuous crossing wave normals, including smaller ripples between mesh vertices.
		vec2 p = wpos.xz;
		float a = dot(p, vec2(0.78, 1.18)) - TIME * 1.35;
		float b = dot(p, vec2(-1.42, 0.55)) - TIME * 1.05;
		float crest_light = smoothstep(0.8, 1.35, sin(a) + 0.45 * sin(b));
		col += vec3(0.025, 0.045, 0.04) * crest_light * smoothstep(0.12, 0.6, depth);
		vec2 slope = (vec2(0.78, 1.18) * cos(a) + vec2(-1.42, 0.55) * cos(b) * 0.45) * wave_height;
		slope += vec2(cos(dot(p, vec2(5.2, 3.8)) - TIME * 2.3), cos(dot(p, vec2(-3.8, 4.6)) - TIME * 1.8)) * 0.022;
		slope *= smoothstep(0.015, 0.18, depth);
		NORMAL = normalize((VIEW_MATRIX * vec4(normalize(vec3(-slope.x, 1.0, -slope.y)), 0.0)).xyz);

		// Soft, moving caustic cells projected onto actual submerged geometry, fading out in the depths.
		vec2 cp = bottom.xz * 2.3;
		cp += vec2(sin(cp.y * 0.7 + TIME * 0.55), cos(cp.x * 0.6 - TIME * 0.45)) * 0.6;
		float cells = abs(sin(cp.x + cp.y * 0.45 + TIME * 0.32) * sin(cp.y - cp.x * 0.35 - TIME * 0.27));
		float caustic = (1.0 - smoothstep(0.025, 0.13, cells)) * smoothstep(0.03, 0.16, depth) * exp(-depth * 1.8);
		col += vec3(0.08, 0.13, 0.10) * caustic;

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
		col = mix(col, vec3(0.88, 0.96, 0.92), foam);
		alpha = max(alpha, foam * 0.85);
		emission = 0.04;
	}
	ALBEDO = col;
	EMISSION = col * emission;
	// Preserve the existing prop-fade multiplier.
	ALPHA *= alpha;
	ROUGHNESS = glow > 0.0 ? 0.18 : 0.3;
	SPECULAR = glow > 0.0 ? 0.7 : spec;
}
