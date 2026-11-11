shader_type canvas_item;
// The battle's own 3D view, shown only where the front render (battle.gd front_texture) has a highlighted model: the
// model as the scene lit it, laid over the end of a bar that runs behind it.

uniform sampler2D mask : filter_linear;

void fragment() {
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= texture(mask, UV).a;
}
