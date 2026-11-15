shader_type spatial;
// Exterior window glass (window_glass.gd): opaque, never a room behind it (AGENTS.md, Building exteriors). It shows
// the sky reflected in it, a soft blue from the horizon up with painted clouds, picked by the view reflected off the
// pane, so the clouds slide across it as the camera moves. A faint, defocused diagonal reflection spans the screen.
// The glass's own paint (vertex colour: its tint) shows under the reflection. Works on Mobile and Compatibility.
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://scripts/gfx/glass_reflection.gdshaderinc"

uniform sampler2D clouds : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 sky_top : source_color = vec3(0.24, 0.50, 0.84);
uniform vec3 sky_horizon : source_color = vec3(0.62, 0.80, 0.95);
uniform vec3 cloud_colour : source_color = vec3(1.0, 1.0, 1.0);
// how much of the reflection covers the glass's paint
uniform float reflect_amount = 0.8;
// the glints' brightness, and a faint glow so the sky still reads on a shaded wall (kept low: night stays dark)
uniform float glint = 0.10;
uniform float sheen = 0.08;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 v = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 r = reflect(-v, n);
	// the camera looks down on the town, so the reflection mostly points up into the sky
	float up = clamp(r.y * 0.5 + 0.5, 0.0, 1.0);
	vec3 sky = mix(sky_horizon, sky_top, smoothstep(0.45, 1.0, up));
	// clouds laid across the pane (so a whole window shows sky and cloud), shifted by the reflected direction: as the
	// camera moves they drift across the glass like a real reflection
	vec3 across = normalize(cross(vec3(0.0, 1.0, 0.0), n) + vec3(1e-4, 0.0, 0.0));
	vec2 pane = vec2(dot(world_pos, across), world_pos.y);
	float c = texture(clouds, pane * vec2(0.22, 0.32) + vec2(dot(r, across), r.y) * 0.9).r;
	sky = mix(sky, cloud_colour, c * 0.85);
	float band = glass_reflection(SCREEN_UV, VIEWPORT_SIZE);
	float fresnel = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 3.0);
	vec3 paint = pow(COLOR.rgb, vec3(2.2));
	vec3 col = mix(paint, sky, clamp(reflect_amount + fresnel * 0.25, 0.0, 1.0));
	ALBEDO = col * 0.88 + band * glint * 0.5;
	EMISSION = (sky * sheen + vec3(band * glint * 0.4)) * (0.6 + 0.4 * fresnel);
	ROUGHNESS = 0.3;
	METALLIC = 0.0;
	SPECULAR = 0.45;
}
