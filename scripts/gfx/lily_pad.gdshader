shader_type spatial;
render_mode cull_disabled;
#include "res://scripts/gfx/water_motion.gdshaderinc"

void vertex() {
	// A whole leaf moves as one, without stretching its notch or fine veins.
	vec2 centre = MODEL_MATRIX[3].xz;
	VERTEX.y += water_swell(centre, TIME) * 0.045 / length(MODEL_MATRIX[1].xyz);
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.78;
	SPECULAR = 0.18;
}
