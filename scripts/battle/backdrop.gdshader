shader_type spatial;
render_mode cull_back, shadows_disabled;
#include "res://scripts/battle/stage_floor.gdshaderinc"

uniform sampler2D panorama : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float repeats = 6.0;
uniform vec4 paint_tint : source_color = vec4(1.0);
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 scenery = texture(panorama, vec2(UV.x * repeats, UV.y)).rgb;
	// The curved foot uses the arena's actual floor texture and receives the same light as the floor.
	// Above it the baked artwork supplies its own lighting. Neither the ground edge nor a vertical join is exposed.
	vec3 floor_color = texture(ground_texture, vec2(world_position.x, world_position.z - 1.5)).rgb;
	float painted = smoothstep(0.1, 1.65, world_position.y);
	ALBEDO = stage_floor_color(floor_color, world_position) * (1.0 - painted);
	EMISSION = scenery * paint_tint.rgb * painted * 0.55;
	ROUGHNESS = 1.0;
}
