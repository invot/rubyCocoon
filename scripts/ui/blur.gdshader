shader_type canvas_item;
// The one shared backdrop of every window (frame_box.gd) and of the touch pad (controls_overlay.gd): where an item
// draws its marker (pure magenta, never tinted or seen), the scene behind is shown blurred. A window then lays its
// 60% near-black over that as an ordinary blend, so it is as dark as a plain box on every renderer; the touch pad,
// whose backdrops are single sprites, has the darkening done here instead (`shade`, alpha 0 for windows).
// Everything else the item draws (the border, text, icons) passes through untouched. The blur reads the screen copy's
// mipmaps, so it costs a handful of samples on the Mobile renderer and on the web's Compatibility renderer alike.
// The marker is found by its colour, not its alpha, so a soft (filtered) edge of a marker shape is blurred too.
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float lod = 3.0;
uniform float spread = 5.0;
uniform vec4 shade = vec4(0.0, 0.0, 0.0, 0.0);

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	if (t.a > 0.004 && min(t.r, t.b) - t.g > 0.75) {
		vec2 px = SCREEN_PIXEL_SIZE * spread;
		vec3 b = textureLod(screen_tex, SCREEN_UV, lod).rgb * 0.4;
		b += textureLod(screen_tex, SCREEN_UV + vec2(px.x, px.y), lod).rgb * 0.15;
		b += textureLod(screen_tex, SCREEN_UV + vec2(-px.x, px.y), lod).rgb * 0.15;
		b += textureLod(screen_tex, SCREEN_UV + vec2(px.x, -px.y), lod).rgb * 0.15;
		b += textureLod(screen_tex, SCREEN_UV + vec2(-px.x, -px.y), lod).rgb * 0.15;
		COLOR = vec4(mix(b, shade.rgb, shade.a), COLOR.a);
	}
}
