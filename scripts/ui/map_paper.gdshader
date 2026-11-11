shader_type canvas_item;
render_mode unshaded;

uniform sampler2D paper_mask : filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 paper_size = vec2(1.0);
varying vec2 paper_uv;

void vertex() {
	paper_uv = VERTEX / paper_size;
}

void fragment() {
	// Every draw command shares the sheet's alpha, including water, land and markers.
	float inside = step(0.0, paper_uv.x) * step(paper_uv.x, 1.0)
		* step(0.0, paper_uv.y) * step(paper_uv.y, 1.0);
	COLOR.a *= texture(paper_mask, paper_uv).a * inside;
}
