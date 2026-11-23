shader_type spatial;
// A tall landmark south of a street (Dustwell's old church, frontier_builder.gd _church): drawn like its baked
// material (its colour texture, matte, both sides), but whatever of it stands between the camera and the hero
// dissolves in a dither over their shape, as high ground does (terrain.gdshader's see-through patch), so it never
// hides them; and while it stands between the camera and the hero at all (the camera close behind its front, the hero
// on the street behind it), all of it thins away ("cutaway", eased in and out by see_through.gd, which also keeps
// "hole" on the hero). Its colour texture's clear pixels are cut out (the air emblems hung on it).
render_mode cull_disabled;

uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic;
// xyz the hero's feet, w 1 while it's on
uniform vec4 hole = vec4(0.0);
// 0 whole .. 1 gone, in a dither
uniform float cutaway = 0.0;

float bayer(vec2 px) {
	int i = int(mod(px.x, 4.0)) + int(mod(px.y, 4.0)) * 4;
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0;
}

void fragment() {
	// (the camera's view only: the sun's shadow pass looks straight down its own orthographic view)
	if (cutaway > 0.0 && PROJECTION_MATRIX[3][3] < 0.5 && cutaway > bayer(FRAGCOORD.xy)) {
		discard;
	}
	if (hole.w > 0.5 && PROJECTION_MATRIX[3][3] < 0.5) {
		vec3 wpos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		// only what is truly in front of them, nearer the camera across the map
		if (length(wpos.xz - CAMERA_POSITION_WORLD.xz) < length(hole.xz - CAMERA_POSITION_WORLD.xz) - 0.4) {
			vec4 f = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(hole.xyz, 1.0));
			vec4 hd = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(hole.xyz + vec3(0.0, 1.9, 0.0), 1.0));
			vec4 g = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
			vec2 asp = vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0);
			vec2 a = f.xy / f.w * asp;
			vec2 up = hd.xy / hd.w * asp - a;
			float tall = max(length(up), 0.0001);
			up /= tall;
			vec2 rel = g.xy / g.w * asp - a;
			// along the body (0 at the feet, 1 at the head) and out to the side, in body heights
			float along = dot(rel, up) / tall;
			float side = abs(dot(rel, vec2(-up.y, up.x))) / tall;
			float r = max(side / 0.48, (along - 0.9) / 0.4);
			if (along > -0.1 && r < 1.0 && smoothstep(1.0, 0.55, r) > bayer(FRAGCOORD.xy)) {
				discard;
			}
		}
	}
	vec4 t = texture(albedo_tex, UV);
	if (t.a < 0.5) {
		discard;
	}
	ALBEDO = t.rgb * COLOR.rgb;
	ROUGHNESS = 0.9;
}
