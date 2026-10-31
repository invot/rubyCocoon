shader_type spatial;
render_mode unshaded, cull_disabled;
// The title's dragon (the fire summon) as a silhouette against the moon, beating its wings: near black, with a thin
// moonlit rim. Everything further than `root` from the middle (x = 0) is a wing, swung about a hinge at (root, hinge_y)
// and bending more towards its tip, so it curls as it beats. The summon's texture only cuts its outline. `t`: the time,
// from the script.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform float scissor = 0.5;
uniform float root = 0.1;
uniform float hinge_y = 0.42;
uniform float tip = 0.5;
uniform float beat = 0.55; // beats per second
uniform float lift = 0.35; // radians up at the top of the stroke
uniform float drop = 0.6; // radians down at the bottom
uniform float t = 0.0;
uniform vec4 body : source_color = vec4(0.025, 0.03, 0.06, 1.0);
uniform vec4 rim : source_color = vec4(0.7, 0.78, 1.0, 1.0);

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
	if (texture(albedo_tex, UV).a < scissor) {
		discard;
	}
	float edge = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 3.0);
	ALBEDO = mix(body.rgb, rim.rgb, edge * 0.35);
}
