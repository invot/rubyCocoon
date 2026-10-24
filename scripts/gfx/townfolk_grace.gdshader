shader_type spatial;
render_mode cull_back, specular_schlick_ggx, depth_draw_always;

uniform float opacity : hint_range(0.0, 1.0) = 1.0;
#define PLAYER_GRACE
#include "townfolk.gdshaderinc"
