shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// Interior glazing: soften the real miniature garden behind each pane. Reflection
// bands span the whole screen, at the same scale as the exterior glass.
#include "res://scripts/gfx/glass_reflection.gdshaderinc"
uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
uniform float reflection_strength : hint_range(0.0, 1.0) = 0.14;
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
    float shine = glass_reflection(SCREEN_UV, VIEWPORT_SIZE) * reflection_strength;
    float edge = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 3.0);
    vec3 tinted = mix(outside, vec3(0.75, 0.86, 0.9), 0.06 + edge * 0.12);
    ALBEDO = mix(tinted, vec3(1.0), shine);
    ALPHA = 1.0;
}
