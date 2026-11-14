shader_type canvas_item;
// The Start book's open pages (book_paper.gd): light tan paper with a faint painted grain, a soft shaded spine
// where the two pages meet, gently darker page edges and the window's rounded corners. Drawn as one rect over the
// sheet's control; cheap enough for the Mobile and Compatibility renderers (one texture read, no loops).

uniform sampler2D grain : filter_linear_mipmap, repeat_enable;
uniform vec4 paper_color : source_color = vec4(0.94, 0.89, 0.80, 1.0);
// the sheet's size and the spine's x, in the control's own units
uniform vec2 sheet_size = vec2(1000.0, 600.0);
uniform float spine_x = 500.0;
uniform float radius = 12.0;
// UI units per grain texel (the texture repeats every 512 texels)
uniform float grain_scale = 1.4;
uniform float grain_strength = 0.09;
uniform float alpha = 1.0;
varying vec2 local;

void vertex() {
	local = VERTEX;
}

float rounded_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 half_size = sheet_size * 0.5;
	float d = rounded_box(local - half_size, half_size, radius);
	float inside = clamp(0.5 - d, 0.0, 1.0);

	float g = texture(grain, local / (512.0 * grain_scale)).r - 0.5;
	vec3 col = paper_color.rgb * (1.0 + g * grain_strength * 2.0);

	// the spine: a soft shade either side of the fold and a thin crease in it, with a faint lift where each page
	// curves up off it
	float sx = abs(local.x - spine_x);
	float shade = 0.16 * exp(-sx / 26.0) + 0.10 * exp(-(sx * sx) / 4.0);
	float lift = 0.035 * exp(-pow((sx - 70.0) / 45.0, 2.0));
	col *= 1.0 - shade;
	col += lift;

	// page edges a touch darker, as if the paper were faintly aged at its rim
	float edge = clamp(-d / 46.0, 0.0, 1.0);
	col *= mix(0.93, 1.0, smoothstep(0.0, 1.0, edge));

	COLOR = vec4(col, paper_color.a * inside * alpha);
}
