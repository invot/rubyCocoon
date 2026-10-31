shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;
// Composite the flat dragon and painted eye glow with a lightly antialiased outline.
uniform sampler2D view_tex : source_color, filter_linear;
uniform float t = 0.0;
void fragment() {
    vec4 dragon = texture(view_tex, UV);
    ALBEDO = dragon.rgb;
    ALPHA = dragon.a;
}
