shader_type spatial;
render_mode cull_disabled;
// Water and lava: a looping PSX animation (texture array frames), coloured per biome. Lava glows.

uniform sampler2DArray frames : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float frame_count = 10.0;
uniform float fps = 6.0;
uniform vec4 tint : source_color = vec4(0.23, 0.56, 0.88, 1.0);
uniform float opacity = 0.82;
uniform float glow = 0.0;
// texture repeats per world unit
uniform float tex_scale = 0.5;
uniform vec2 drift = vec2(0.0, 0.03);
// Optional sandy beach: x minimum, slope start z, x maximum, offshore end z. Zero width disables it.
uniform vec4 shore = vec4(0.0);
uniform vec3 shore_levels = vec3(-0.12, -0.17, -0.42);

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	float f = mod(floor(TIME * fps), frame_count);
	// a waterfall's sheet (terrain_mesh.gd) runs down, quickly
	vec2 uv = abs(wnorm.y) > 0.5 ? wpos.xz * tex_scale + drift * TIME : vec2(wpos.x + wpos.z, wpos.y) * tex_scale + vec2(0.0, 1.2) * TIME;
	vec3 c = texture(frames, vec3(uv, f)).rgb;
	vec3 col = glow > 0.0 ? c : tint.rgb * (0.62 + 0.55 * c);
	float alpha = opacity;
	if (shore.z > shore.x && wpos.x >= shore.x && wpos.x <= shore.z && wpos.z >= shore.y && glow == 0.0) {
		float wade_end = shore.w - 2.5;
		float bottom = wpos.z <= wade_end ? shore_levels.y * smoothstep(shore.y, wade_end, wpos.z) : mix(shore_levels.y, shore_levels.z, smoothstep(wade_end, shore.w, wpos.z));
		float depth = shore_levels.x - bottom;
		if (depth <= 0.0) { discard; }
		float clear = smoothstep(0.0, 0.30, depth);
		col = mix(vec3(0.48, 0.79, 0.77), col, clear);
		alpha = mix(0.36, opacity, clear) * smoothstep(0.0, 0.025, depth);
		// Broad, quiet crests travel shoreward, curling slightly along the sand and dissolving into lace.
		float curl = sin(wpos.x * 0.62) * 0.11 + sin(wpos.x * 1.35 + TIME * 0.35) * 0.045;
		float phase = fract((wpos.z - wade_end + curl) / 1.8 + TIME * 0.22);
		float crest = (1.0 - smoothstep(0.025, 0.12, abs(phase - 0.5))) * smoothstep(0.0, 0.022, depth);
		float shore_fade = 1.0 - smoothstep(wade_end + 0.6, shore.w + 0.6, wpos.z);
		float lace = 0.55 + 0.2 * sin(wpos.x * 6.0 + sin(wpos.z * 3.0) + TIME);
		float foam = crest * shore_fade * lace;
		col = mix(col, vec3(0.94, 0.97, 0.92), foam);
		alpha = max(alpha, foam * 0.75);
	}
	// falling water froths white
	if (abs(wnorm.y) <= 0.5 && glow == 0.0) {
		col = mix(col, vec3(0.92, 0.96, 1.0), 0.3 * c.r);
	}
	ALBEDO = col;
	EMISSION = col * glow;
	ALPHA = alpha;
	ROUGHNESS = 0.18;
	SPECULAR = 0.7;
}
