shader_type canvas_item;
// The title carousel's button (title_carousel.gd): a softly rounded box of the gem laid over the scene behind it, blurred. The gem
// is most opaque across the middle and thins towards the ends, where more of the blurred art shows through.
// Like blur.gdshader it reads the screen copy's mipmaps, so it works on the Mobile and Compatibility renderers alike.
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec4 gem : source_color = vec4(0.82, 0.12, 0.18, 1.0);
uniform vec2 rect_size = vec2(460.0, 104.0);
// the corners' radius (a gently rounded rectangle, not a pill)
uniform float radius = 18.0;
uniform float lod = 3.5;
uniform float spread = 6.0;
// the gem's opacity at the ends and across the middle
uniform float edge_alpha = 0.38;
uniform float middle_alpha = 0.9;

void fragment() {
	vec2 p = (UV - 0.5) * rect_size;
	float r = min(radius, rect_size.y * 0.5);
	vec2 q = abs(p) - (rect_size * 0.5 - vec2(r));
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
	// (about one screen pixel of soft edge, whatever the UI's scale)
	float aa = max(fwidth(d), 0.5);
	float cover = clamp(0.5 - d / aa, 0.0, 1.0);
	vec2 px = SCREEN_PIXEL_SIZE * spread;
	vec3 b = textureLod(screen_tex, SCREEN_UV, lod).rgb * 0.4;
	b += textureLod(screen_tex, SCREEN_UV + vec2(px.x, px.y), lod).rgb * 0.15;
	b += textureLod(screen_tex, SCREEN_UV + vec2(-px.x, px.y), lod).rgb * 0.15;
	b += textureLod(screen_tex, SCREEN_UV + vec2(px.x, -px.y), lod).rgb * 0.15;
	b += textureLod(screen_tex, SCREEN_UV + vec2(-px.x, -px.y), lod).rgb * 0.15;
	float across = abs(UV.x - 0.5) * 2.0;
	float k = mix(middle_alpha, edge_alpha, smoothstep(0.15, 1.0, across));
	vec3 col = mix(b, gem.rgb, k);
	// a soft bezel like the windows': the top edge lit, the foot shaded
	float v = UV.y;
	col += vec3(0.10) * smoothstep(0.35, 0.0, v) - vec3(0.08) * smoothstep(0.7, 1.0, v);
	COLOR = vec4(col, cover * COLOR.a);
}
