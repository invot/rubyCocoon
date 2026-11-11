shader_type canvas_item;
// A flat outline round the silhouettes in the battle's front render (battle.gd front_texture, used only for its
// alpha): it colours only the pixels just outside a model, never its inside, so a model made of many parts (hair,
// eyes, clothes) gets one clean line round its outer edge. Each highlighted model has a screen box and a colour; an
// outline pixel takes the colour of the nearest box.

uniform float width = 4.0;            // in front-render pixels
uniform int count = 0;
uniform vec4 boxes[8];                // x0, y0, x1, y1 in UV
uniform vec4 colors[8];

void fragment() {
	float inside = texture(TEXTURE, UV).a;
	vec2 reach = TEXTURE_PIXEL_SIZE * width;
	float near = 0.0;
	for (int i = 0; i < 16; i++) {
		float angle = float(i) * 0.3926991;
		vec2 dir = vec2(cos(angle), sin(angle));
		near = max(near, texture(TEXTURE, UV + dir * reach).a);
		near = max(near, texture(TEXTURE, UV + dir * reach * 0.5).a);
	}
	float line = clamp(near * 2.0 - 1.0, 0.0, 1.0) * (1.0 - smoothstep(0.35, 0.65, inside));
	vec3 col = vec3(1.0);
	float best = 1e9;
	for (int i = 0; i < 8; i++) {
		if (i >= count) {
			break;
		}
		vec4 b = boxes[i];
		float d = distance(clamp(UV, b.xy, b.zw), UV);
		if (d < best) {
			best = d;
			col = colors[i].rgb;
		}
	}
	COLOR = vec4(col, line);
}
