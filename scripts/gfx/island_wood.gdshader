shader_type spatial;
render_mode cull_disabled;
uniform vec4 wood_colour : source_color = vec4(0.67, 0.43, 0.24, 1.0);
uniform bool roofing = false;
varying vec3 place;
varying vec3 facing;
void vertex() {
	place = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	facing = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	float along = abs(facing.z) > abs(facing.x) ? place.x : place.z;
	float board = along / 0.32;
	float edge = min(fract(board), 1.0 - fract(board));
	float seam = smoothstep(0.0, max(fwidth(board), 0.025), edge);
	float tone = 0.96 + 0.035 * sin(floor(board) * 2.4) + 0.02 * sin(place.y * 1.7);
	ALBEDO = wood_colour.rgb * mix(0.78, tone, seam);
	if (roofing) {
		float bands = 0.88 + 0.09 * sin(place.y * 37.0) + 0.045 * sin((place.x + place.z) * 93.0);
		ALBEDO = wood_colour.rgb * bands;
	}
	ROUGHNESS = 0.94;
}
