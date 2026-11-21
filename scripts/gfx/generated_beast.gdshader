shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

// Imported material/vertex colors are linear RGB in UV.xy and UV2.x.
// UV2.y marks only forehead crystal facets, travelling with the head in merges.
uniform float gem_glow = 0.0;
uniform float ghost = 0.0;
uniform float lid_shut = 0.0;

void fragment() {
	vec3 painted = clamp(vec3(UV, UV2.x), vec3(0.0), vec3(1.0));
	float gem = step(0.5, UV2.y);
	vec3 shade = mix(painted, painted * vec3(0.14, 0.06, 0.22) + vec3(0.025, 0.008, 0.045), ghost);
	ALBEDO = mix(shade, min(painted * 1.5 + vec3(0.12), vec3(1.0)), gem * gem_glow * 0.65);
	ROUGHNESS = mix(0.72, 0.22, gem);
	SPECULAR = mix(0.28, 0.65, gem);
	EMISSION = painted * gem * gem_glow * 3.5;
}
