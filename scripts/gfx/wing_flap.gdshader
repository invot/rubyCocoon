shader_type spatial;
render_mode cull_disabled;
// A summon's wings beating (the title screen's dragon): everything further than `root` from the middle (x = 0) is a
// wing, swung about a hinge at (root, hinge_y) and bending more towards its tip, so it curls as it beats. Its own
// texture and alpha cut-out, as the summon's material has them. `t` is the time, set from the script.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform float scissor = 0.5;
uniform float root = 0.1;
uniform float hinge_y = 0.42;
uniform float tip = 0.5;
uniform float beat = 0.55; // beats per second
uniform float lift = 0.35; // radians up at the top of the stroke
uniform float drop = 0.6; // radians down at the bottom
uniform float t = 0.0;

void vertex() {
	float d = abs(VERTEX.x) - root;
	if (d > 0.0) {
		float side = sign(VERTEX.x);
		// a quick downstroke, a slower recovery
		float ph = fract(t * beat);
		float up = ph < 0.4 ? 1.0 - smoothstep(0.0, 0.4, ph) : smoothstep(0.4, 1.0, ph);
		float a = mix(-drop, lift, up) * pow(clamp(d / (tip - root), 0.0, 1.0), 0.7);
		float c = cos(a);
		float s = sin(a);
		vec2 rel = vec2(d, VERTEX.y - hinge_y);
		VERTEX.x = side * (root + rel.x * c - rel.y * s);
		VERTEX.y = hinge_y + rel.x * s + rel.y * c;
		vec2 n = vec2(NORMAL.x * side, NORMAL.y);
		NORMAL.x = side * (n.x * c - n.y * s);
		NORMAL.y = n.x * s + n.y * c;
	}
}

void fragment() {
	vec4 c = texture(albedo_tex, UV);
	if (c.a < scissor) {
		discard;
	}
	ALBEDO = c.rgb;
	ROUGHNESS = 0.65;
	SPECULAR = 0.4;
}
