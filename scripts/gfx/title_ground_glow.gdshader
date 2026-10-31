shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, fog_disabled;

#include "res://scripts/gfx/title_moonlight.gdshaderinc"

// A soft wash of moonlight over the existing red ground, with no extra lights or shadows.
uniform vec3 moon_at = vec3(0.0, 5.6, -28.0);
uniform float moon_size = 23.0;
uniform sampler2D ground_tex : source_color, filter_linear_mipmap_anisotropic;

varying vec3 world_at;

void vertex() {
	world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Continue the moon card's halo along the same camera rays, so it never ends at a hard seam.
	vec3 camera_at = INV_VIEW_MATRIX[3].xyz;
	vec3 ray = world_at - camera_at;
	vec3 on_moon = camera_at + ray * ((moon_at.z - camera_at.z) / min(ray.z, -0.001));
	float halo = moon_halo(length((on_moon.xy - moon_at.xy) / moon_size), 0.15);
	// The broader reflection gently widens toward the viewer, retaining the painted ground texture.
	float width = 2.0 + max(world_at.z + 28.0, 0.0) * 0.08;
	float across = world_at.x / width;
	float along = (world_at.z + 16.0) / 24.0;
	float reflection = exp(-across * across - along * along) * 0.19;
	float surface = dot(texture(ground_tex, UV * vec2(18.0, 12.0)).rgb, vec3(0.333));
	ALBEDO = MOON_GLOW * (halo + reflection * (0.75 + surface * 0.25));
	ALPHA = 1.0;
}
