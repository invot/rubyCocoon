shader_type spatial;
render_mode cull_disabled;
// Water and lava: a looping PSX animation (texture array frames), coloured per biome. Lava glows.

uniform sampler2DArray frames : source_color, filter_nearest_mipmap, repeat_enable;
uniform float frame_count = 10.0;
uniform float fps = 6.0;
uniform vec4 tint : source_color = vec4(0.23, 0.56, 0.88, 1.0);
uniform float opacity = 0.82;
uniform float glow = 0.0;
// texture repeats per world unit
uniform float tex_scale = 0.5;
uniform vec2 drift = vec2(0.0, 0.03);

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
	// falling water froths white
	if (abs(wnorm.y) <= 0.5 && glow == 0.0) {
		col = mix(col, vec3(0.92, 0.96, 1.0), 0.3 * c.r);
	}
	ALBEDO = col;
	EMISSION = col * glow;
	ALPHA = opacity;
	ROUGHNESS = 0.18;
	SPECULAR = 0.7;
}
