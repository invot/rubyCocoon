shader_type spatial;
// The title's 3D logo letters: polished gold, pale at the top and bottom with a dark horizon band across the middle
// (as chrome lettering on old box art), the extruded sides a deeper amber, and a band of light sweeping across them
// every few seconds. `lo`/`hi`: the letters' bottom and top in the mesh's own space; `t`: the time, from the script.
uniform float lo = 0.0;
uniform float hi = 1.0;
uniform float t = 0.0;
uniform float period = 3.5;
uniform float left = -2.0;
uniform float right = 2.0;

varying vec3 local;

void vertex() {
	local = VERTEX;
}

vec3 gold(float y) {
	vec3 c = mix(vec3(1.0, 0.98, 0.86), vec3(1.0, 0.86, 0.38), smoothstep(1.0, 0.64, y));
	c = mix(c, vec3(0.62, 0.3, 0.06), smoothstep(0.6, 0.5, y));
	c = mix(c, vec3(0.92, 0.56, 0.12), smoothstep(0.5, 0.46, y));
	c = mix(c, vec3(1.0, 0.82, 0.32), smoothstep(0.46, 0.2, y));
	return mix(c, vec3(1.0, 0.94, 0.66), smoothstep(0.2, 0.0, y));
}

void fragment() {
	float y = clamp((local.y - lo) / max(0.001, hi - lo), 0.0, 1.0);
	// the front faces look out along +z in the mesh's own space; the extruded sides don't
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 face = normalize((MODEL_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
	float front = smoothstep(0.6, 0.9, dot(n, face));
	vec3 c = mix(vec3(0.55, 0.26, 0.05), gold(y), front);
	// the sweep: a slanted band crossing the letters, then a pause
	float span = right - left;
	float at = left - 0.6 + fract(t / period) * (span + 1.2) * 1.6;
	float band = 1.0 - smoothstep(0.0, 0.22, abs(local.x + (local.y - lo) * 0.5 - at));
	ALBEDO = c + vec3(1.0, 0.95, 0.8) * band * 0.6;
	METALLIC = 0.75;
	ROUGHNESS = 0.28;
	SPECULAR = 0.8;
	EMISSION = c * 0.18 + vec3(1.0, 0.9, 0.7) * band * 0.9;
}
