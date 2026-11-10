shader_type spatial;
render_mode cull_back;
// The leaves of the trees, bushes and grass tufts (voxel_assets.gd gives it to every plant). The packs colour a plant
// from a palette: one flat green for a whole crown. Here the crown wears a painted leaf texture (foliage.png, laid on
// from the world's three sides so it never stretches), sunlit on top and deeper underneath, and every plant takes a
// shade of its own from where it stands: warmer or cooler, lighter or darker, so no two side by side match.
// Trunks and branches (the palette's browns) only take a little of the texture, as bark.

// the plant's own palette
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// the leaf texture: grey, 0.5 on average
uniform sampler2D leaves : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
// leaf texture repeats per world unit
uniform float leaf_scale = 0.95;
// how far plants' colours stray from the palette's (0 = all alike)
uniform float vary = 1.0;

varying vec3 wpos;
varying vec3 wnorm;
varying vec3 plant;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// where this plant stands (its own place in a batch of them)
	plant = MODEL_MATRIX[3].xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec3 base = texture(atlas, UV).rgb;
	// green is leaf, the rest wood
	float leafy = clamp((base.g - max(base.r * 1.02, base.b * 1.1)) * 10.0, 0.0, 1.0);
	vec3 n = abs(wnorm);
	n = n * n * n * n;
	n /= max(n.x + n.y + n.z, 0.001);
	vec3 p = wpos * leaf_scale;
	float t = texture(leaves, p.zy).r * n.x + texture(leaves, p.xz).r * n.y + texture(leaves, p.xy).r * n.z;
	// (the texture is soft and close to mid grey: drawn out to full light and shade)
	t = smoothstep(0.3, 0.7, t);
	// this plant's shade
	vec2 id = floor(plant.xz * 16.0);
	float warmth = hash(id);
	float bright = hash(id + vec2(31.7, 5.3));
	// (and the land's: lighter and darker stretches of a wood)
	float drift = vnoise(plant.xz * 0.11 + vec2(3.0, 8.0));
	vec3 tint = mix(vec3(0.72, 0.93, 1.08), vec3(1.1, 1.0, 0.66), warmth * 0.75 + drift * 0.25);
	// (the palette's greens are very bright: eased a little towards grey, and never lightened past them)
	vec3 leaf = mix(base, vec3(dot(base, vec3(0.3, 0.6, 0.1))), 0.14);
	leaf *= mix(vec3(0.9), tint * mix(0.72, 1.0, bright), vary);
	leaf *= mix(0.62, 1.14, t);
	// sunlit on top, yellower in the lightest leaves, deeper underneath
	float up = clamp(wnorm.y * 0.5 + 0.5, 0.0, 1.0);
	leaf *= mix(0.74, 1.06, up);
	leaf = mix(leaf, leaf * vec3(1.12, 1.07, 0.8), smoothstep(0.55, 0.85, t) * up * 0.6);
	vec3 bark = base * mix(0.84, 1.1, texture(leaves, vec2(p.x + p.z, p.y * 0.3) * 1.4).r);
	ALBEDO = mix(bark, leaf, leafy);
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}
