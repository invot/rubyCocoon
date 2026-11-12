shader_type spatial;
#include "res://scripts/battle/stage_floor.gdshaderinc"
uniform sampler2D ground_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 tiling = vec2(1.0);
uniform bool grass_patches = false;
uniform sampler2D dirt_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 ground = texture(ground_texture, UV * tiling).rgb;
	if (grass_patches) {
		ground = mix(ground * COLOR.rgb, texture(dirt_texture, UV*tiling).rgb, COLOR.a);
	}
	ALBEDO = stage_floor_color(ground, world_position);
	ROUGHNESS = 1.0;
}
