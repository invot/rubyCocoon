shader_type canvas_item;
uniform vec4 highlight : source_color = vec4(0.72, 0.08, 0.12, 1.0);
uniform vec4 spans[3];
uniform int span_count = 0;
varying vec2 label_position;
void vertex() {
	label_position = VERTEX;
}
void fragment() {
	for (int i = 0; i < 3; i++) {
		if (i < span_count && all(greaterThanEqual(label_position, spans[i].xy)) && all(lessThanEqual(label_position, spans[i].zw))) {
			COLOR.rgb = highlight.rgb;
		}
	}
}
