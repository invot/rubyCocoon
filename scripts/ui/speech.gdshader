shader_type canvas_item;
render_mode unshaded;

// One smooth silhouette for the paper and pointer. Logical units keep the bevel and shadow consistent.
uniform vec2 body_size = vec2(720.0, 180.0);
uniform vec2 surface_size = vec2(756.0, 264.0);
uniform bool has_tail = false;
uniform vec2 tail_a;
uniform vec2 tail_b;
uniform vec2 tail_c;
uniform vec4 paper_top : source_color = vec4(1.0);
uniform vec4 paper_bottom : source_color = vec4(0.94, 0.94, 0.95, 1.0);
uniform vec4 shade : source_color = vec4(0.06, 0.07, 0.09, 0.22);

float cross2(vec2 a, vec2 b) {
	return a.x * b.y - a.y * b.x;
}

float segment_distance(vec2 p, vec2 a, vec2 b) {
	vec2 edge = b - a;
	return length(p - a - edge * clamp(dot(p - a, edge) / max(dot(edge, edge), 0.001), 0.0, 1.0));
}

float triangle_distance(vec2 p) {
	float d = min(segment_distance(p, tail_a, tail_b), min(segment_distance(p, tail_b, tail_c), segment_distance(p, tail_c, tail_a)));
	float a = cross2(tail_b - tail_a, p - tail_a);
	float b = cross2(tail_c - tail_b, p - tail_b);
	float c = cross2(tail_a - tail_c, p - tail_c);
	bool inside = (a >= 0.0 && b >= 0.0 && c >= 0.0) || (a <= 0.0 && b <= 0.0 && c <= 0.0);
	return (inside ? -d : d) - 1.0;
}

float silhouette(vec2 p) {
	vec2 half_size = body_size * 0.5;
	vec2 q = abs(p - vec2(18.0, 42.0) - half_size) - half_size + vec2(16.0);
	float box = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - 16.0;
	if (!has_tail) {
		return box;
	}
	float triangle = triangle_distance(p);
	float blend = max(4.0 - abs(box - triangle), 0.0) / 4.0;
	return min(box, triangle) - blend * blend;
}

void fragment() {
	vec2 p = UV * surface_size;
	float distance_to_edge = silhouette(p);
	float aa = max(fwidth(distance_to_edge), 0.45);
	float paper_alpha = 1.0 - smoothstep(-aa, aa, distance_to_edge);
	float shadow_alpha = (1.0 - smoothstep(-2.0, 10.0, silhouette(p - vec2(0.0, 5.0)))) * shade.a;
	float y = clamp((p.y - 42.0) / body_size.y, 0.0, 1.0);
	vec3 paper = mix(paper_top.rgb, paper_bottom.rgb, smoothstep(0.12, 1.0, y));
	// A quiet bevel, with a white upper face and a slightly shaded lower edge.
	float bevel = 1.0 - smoothstep(0.0, 5.0, -distance_to_edge);
	paper -= bevel * 0.025 * smoothstep(0.2, 1.0, y);
	COLOR = vec4(mix(shade.rgb, paper, paper_alpha), paper_alpha + shadow_alpha * (1.0 - paper_alpha));
}
