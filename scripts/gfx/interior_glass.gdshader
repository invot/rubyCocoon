shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// Interior glazing: soften the real miniature garden behind each pane, with broad moving reflections.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
void fragment() {
    // A compact Gaussian kernel also works on Compatibility without a screen mip chain.
    vec2 pixel = vec2(1.0) / vec2(textureSize(screen_texture, 0));
    vec3 outside = vec3(0.0);
    float total = 0.0;
    for (int y = -2; y <= 2; y++) {
        for (int x = -2; x <= 2; x++) {
            float weight = exp(-float(x * x + y * y) * 0.5);
            outside += texture(screen_texture, SCREEN_UV + vec2(float(x), float(y)) * pixel).rgb * weight;
            total += weight;
        }
    }
    outside /= total;
    float diagonal = UV.x * 0.7 + UV.y + dot(VIEW.xy, vec2(0.2, 0.1));
    float shine = exp(-pow((diagonal - 0.62) * 12.0, 2.0)) * 0.16;
    shine += exp(-pow((diagonal - 0.83) * 24.0, 2.0)) * 0.07;
    float edge = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 3.0);
    ALBEDO = mix(outside, vec3(0.75, 0.86, 0.9), 0.06 + edge * 0.12) + vec3(shine);
    ALPHA = 1.0;
}
