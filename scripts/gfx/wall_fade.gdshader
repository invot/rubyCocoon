shader_type spatial;
// A room wall while it fades (room_builder.gd fade): the same look as its StandardMaterial3D (texture x tint x
// vertex shade), at its tile's opacity from the room's fade map (UV2 holds the tile's centre, in tiles).
render_mode blend_mix, depth_draw_always, cull_back;

uniform sampler2D albedo_tex : source_color, hint_default_white, filter_nearest_mipmap;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform float roughness_v = 0.9;
uniform sampler2D fade_map : filter_nearest;
uniform vec2 map_size = vec2(1.0);

varying float fade;

void vertex() {
	UV *= uv_scale;
	fade = textureLod(fade_map, UV2 / map_size, 0.0).r;
}

void fragment() {
	// a clear wall leaves no depth behind, so nothing past it is hidden
	if (fade < 0.02) {
		discard;
	}
	ALBEDO = texture(albedo_tex, UV).rgb * albedo_color.rgb * COLOR.rgb;
	ROUGHNESS = roughness_v;
	ALPHA = fade;
}
