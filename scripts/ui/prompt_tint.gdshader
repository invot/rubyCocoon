// Recolours one of Kenney's white input prompts (assets/ui/input_prompts/) for the touch pad (controls_overlay.gd).
// The icon's white body takes `body`; Kenney's red highlight (the pressed arm of a d-pad) takes `mark` (each with
// its own alpha, so a transparent body leaves only the highlight). With
// `has_solid`, `solid` is the same button with its lettering filled in (<name>_solid.svg): where the icon has its
// letters cut out, they show in `letter`, so a button can be the gem with white letters.
shader_type canvas_item;

uniform vec4 body : source_color = vec4(1.0);
uniform vec4 mark : source_color = vec4(1.0);
uniform vec4 letter : source_color = vec4(1.0);
uniform bool has_solid = false;
uniform sampler2D solid : filter_linear_mipmap, hint_default_transparent;
// the node's own colour (modulate): COLOR in fragment() already carries the icon's alpha, which would cut the letters
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	// how red this pixel is: Kenney's highlight is #E73246 beside white
	float t = clamp((c.r - c.g) * 1.6, 0.0, 1.0);
	vec3 rgb = mix(body.rgb, mark.rgb, t);
	float a = c.a;
	if (has_solid) {
		float s = max(texture(solid, UV).a, c.a);
		// inside the button: the body where the icon is, the letter where it is cut out
		rgb = mix(letter.rgb, rgb, c.a / max(s, 0.001));
		a = s;
	}
	COLOR = vec4(rgb, a * mix(body.a, mark.a, t)) * tint;
}
