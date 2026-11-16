shader_type spatial;
#include "res://scripts/battle/stage_floor.gdshaderinc"
varying vec3 world_position;
varying vec4 masks;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	masks = stage_ground_masks(world_position.xz);
}

void fragment() {
	ALBEDO = stage_floor_color(stage_ground_color(world_position.xz, masks), world_position);
	ROUGHNESS = 1.0;
	SPECULAR = 0.2;
}
