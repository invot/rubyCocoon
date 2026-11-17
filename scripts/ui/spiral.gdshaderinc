// The battle swirl, shared by its three graphics tiers (spiral.gdshader: max, spiral_mid: mid, spiral_min: min).
// Two thick, flat-ended arms wind out of the middle of the screen round each other, one in each of the colour's
// two tones. The moment the first pair is halfway to covering the screen a second starts from the middle on top
// of it; that one covers the screen and keeps turning while the battle loads, then a hole of the same shape opens
// from the middle onto the battle.
//
// SPIRAL_TIER 2 (max): soft shadows under each pair's edges, sparkles, a translucent first pair (first_alpha).
// SPIRAL_TIER 1 (mid): sparkles, no shadows.  SPIRAL_TIER 0 (min): flat arms only.
//
// Kept cheap for phones: only two pairs ever, and each pixel paints the newer one first and stops as soon as it
// is opaque, so once the screen is covered (all through loading) every pixel evaluates a single pair; sparkles cost something only inside their own small cell, and the hole only
// once it opens. No loops over sparkles, no sin() hashes (imprecise and slow on mobile GPUs).
uniform vec4 color : source_color = vec4(0.25, 0.56, 0.88, 1.0);
uniform vec4 color_secondary : source_color = vec4(0.18, 0.42, 0.66, 1.0);
uniform sampler2D sparkle_atlas : filter_linear_mipmap, repeat_disable;
uniform float progress = 0.0;
uniform float reveal = 0.0;
uniform float elapsed = 0.0;
uniform float entry_duration = 0.8;
uniform float aspect = 1.7778;
/// The very first pair's opacity (the max tier lets the world show through it a little).
uniform float first_alpha = 1.0;
uniform bool multicolor = false;

/// A full-grown arm's step outward per turn, in screen heights. An arm is half this wide.
const float PITCH = 0.64;
/// A pair starts out this much tighter and opens up as it grows.
const float YOUNG = 0.5;
/// Turns per second of the whole swirl.
const float SPIN = 0.42;
/// Each pair is turned this far round from the one under it, so its arms lie across the older arms' edges.
const float STAGGER = 0.25;
const float SHADOW_REACH = 0.03;
const float SHADOW = 0.34;
const float SPARKLE_CELL = 0.4;
const float SPARKLE_FRAMES = 7.0;

struct Wave {
	float mask;    // how much of this pixel the pair covers
	float tone;    // 0: the first arm, 1: the second
	float shadow;  // the soft shadow it casts just outside its edges (max tier)
	float along;   // turns along the arm from the middle
	float arm;     // which arm this pixel lies in
	float across;  // 0..1 across the arm
	float pitch;
};

// Dave Hoskins' hash: arithmetic only, stable at mobile precision.
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float pitch_at(float growth) {
	float g = clamp(growth, 0.0, 1.0);
	return PITCH * mix(YOUNG, 1.0, g * (2.0 - g));
}

/// growth: 0 (nothing) to 1 (the screen covered). turn: this pair's rotation, in turns.
Wave wave(float r, float angle, float growth, float turn, float corner, float aa) {
	Wave o;
	o.mask = 0.0;
	o.shadow = 0.0;
	o.tone = 0.0;
	o.pitch = pitch_at(growth);
	// Arms are bands of an Archimedean spiral: `along` counts turns from the middle, the same for both arms.
	float w = angle - turn;
	float s = 2.0 * r / o.pitch - 2.0 * w;
	float band = floor(s);
	o.across = s - band;
	o.arm = mod(band, 2.0);
	o.along = (band + 0.5) * 0.5 + w;
	if (growth <= 0.0) {
		return o;
	}
	float reach = growth >= 1.0 ? 1000.0 : -0.25 + growth * (corner * 1.04 / o.pitch + 0.5);
	// The flat end: a straight cut across the arm where it has grown to; the neighbouring bands' cuts blend in
	// across the arm's sides so its edges stay smooth.
	float arc = TAU * max(r, aa * 2.0) / aa;
	float own = clamp((reach - o.along) * arc + 0.5, 0.0, 1.0);
	float inner = clamp((reach - o.along + 0.5) * arc + 0.5, 0.0, 1.0);
	float outer = clamp((reach - o.along - 0.5) * arc + 0.5, 0.0, 1.0);
	float d_in = o.across * o.pitch * 0.5;
	float d_out = (1.0 - o.across) * o.pitch * 0.5;
	float b_in = 0.5 * clamp(1.0 - d_in / aa, 0.0, 1.0);
	float b_out = 0.5 * clamp(1.0 - d_out / aa, 0.0, 1.0);
	o.mask = own * (1.0 - b_in - b_out) + inner * b_in + outer * b_out;
	o.tone = mix(o.arm, 1.0 - o.arm, b_in + b_out);
#if SPIRAL_TIER >= 2
	if (o.mask < 1.0) {
		// Just past the end of this arm, or just outside the last turn of the other one.
		float arc_units = TAU * max(r, aa * 2.0);
		float past_end = max(o.along - reach, 0.0) * arc_units;
		float past_side = length(vec2(d_in, max(o.along - 0.5 - reach, 0.0) * arc_units));
		o.shadow = exp(-min(past_end, past_side) / SHADOW_REACH) * (1.0 - o.mask);
	}
#endif
	return o;
}

#if SPIRAL_TIER >= 1
/// White sparkles that live in an arm: they ride outward along it, growing and blurring toward the screen's edge,
/// and never cross its sides or its flat end. One cell per pixel; most cells are empty and stop early.
float sparkles(vec2 p, Wave o, float turn, float seed, float corner, float aa) {
	float per_turn = 3.14159265 * o.pitch / SPARKLE_CELL;
	float along = max(o.along, 0.0);
	float drift = elapsed * 0.55;
	float q = per_turn * along * along - drift;
	float cell = floor(q);
	vec2 id = vec2(cell, o.arm + seed * 7.0);
	float pick = hash(id);
	if (pick < 0.3) {
		return 0.0;
	}
	float at = cell + 0.34 + 0.32 * hash(id + 3.1) + drift;
	float centre_along = sqrt(max(at, 0.0) / per_turn);
	float centre_r = o.pitch * centre_along;
	float far = clamp(centre_r / corner, 0.0, 1.0);
	float size = min(mix(0.035, 0.105, far), o.pitch * 0.2);
	centre_r += (hash(id + 9.7) - 0.5) * 2.0 * max(o.pitch * 0.25 - size * 0.8, 0.0);
	float centre_angle = TAU * (centre_along - (o.arm + 0.5) * 0.5 + turn);
	vec2 uv = (p - centre_r * vec2(cos(centre_angle), sin(centre_angle))) / (size * 2.0) + 0.5;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
		return 0.0;
	}
	float frame = floor(fract(elapsed * 0.85 + pick * 5.0) * SPARKLE_FRAMES);
	// Blurred by a lower mip toward the edge: the same one sample, so the blur costs nothing.
	float blur = 4.2 * smoothstep(0.12, 0.95, far);
	float lod = max(log2(64.0 * aa / size), 0.0) + blur;
	vec2 atlas_uv = (vec2(frame, 0.0) + clamp(uv, vec2(0.02), vec2(0.98))) / vec2(SPARKLE_FRAMES, 1.0);
	float glint = textureLod(sparkle_atlas, atlas_uv, lod).a * (1.0 + 0.9 * blur);
	float edge = min(o.across, 1.0 - o.across) * o.pitch * 0.5;
	float kept = smoothstep(0.0, aa * 2.0 + 0.012 * far, edge) * o.mask;
	return clamp(glint, 0.0, 1.0) * kept;
}
#endif

void fragment() {
	float aa = SCREEN_PIXEL_SIZE.y;
	vec2 p = (FRAGCOORD.xy * SCREEN_PIXEL_SIZE - 0.5) * vec2(aspect, 1.0);
	float corner = 0.5 * length(vec2(aspect, 1.0));
	float r = length(p);
	float angle = atan(p.y, p.x) / TAU;
	float spin = elapsed * SPIN;
	float period = max(entry_duration, 0.05) * 0.5;
	// Only two pairs: the second covers the screen and stays, turning, until the battle is ready.
	float newest = min(floor(elapsed / period), 1.0);

	vec3 light = color.rgb;
	vec3 dark = color_secondary.rgb;
	// Premultiplied, painted front to back: the newest pair first, older ones only where it leaves a gap.
	vec4 paint = vec4(0.0);
	float found = 0.0;
	Wave top;
	float top_turn = 0.0;
	float top_seed = 0.0;
	float top_alpha = 0.0;
	// The second pair, then the first where the second leaves a gap (once grown, the second covers every pixel).
	for (int i = 0; i < 2; i++) {
		float n = newest - float(i);
		if (n < 0.0) {
			break;
		}
		float growth = (elapsed - n * period) / (period * 2.0);
		float opacity = 1.0;
		if (n < 0.5) {
			growth = max(growth, progress);
			opacity = first_alpha;
		}
		float turn = spin + n * STAGGER;
		Wave o = wave(r, angle, growth, turn, corner, aa);
		// Every other pair is a shade apart, so a new arm shows against the one it crosses.
		float odd = mod(n, 2.0);
		vec3 first = mix(light, mix(light, vec3(1.0), 0.09), odd);
		vec3 second = mix(dark, dark * 0.84, odd);
		if (multicolor) {
			float stripe = mod(floor(o.along * 2.0), 3.0);
			first = stripe < 1.0 ? color.rgb : (stripe < 2.0 ? color_secondary.rgb : vec3(0.87, 0.66, 0.22));
			second = stripe < 1.0 ? vec3(0.24, 0.62, 0.46) : (stripe < 2.0 ? vec3(0.59, 0.39, 0.69) : color_secondary.rgb);
		}
		float a = o.mask * opacity;
		paint += (1.0 - paint.a) * vec4(mix(first, second, o.tone) * a, a);
#if SPIRAL_TIER >= 2
		paint.a += (1.0 - paint.a) * o.shadow * SHADOW;
#endif
		if (found < 0.5 && o.mask > 0.5) {
			found = 1.0;
			top = o;
			top_turn = turn;
			top_seed = n;
			top_alpha = opacity;
		}
		if (paint.a > 0.999) {
			break;
		}
	}
	vec3 rgb = paint.rgb / max(paint.a, 0.0001);
#if SPIRAL_TIER >= 1
	// Sparkles only in a solid pair, never in Max's see-through first one.
	if (found > 0.5 && top_alpha > 0.999) {
		rgb = mix(rgb, vec3(1.0), sparkles(p, top, top_turn, top_seed, corner, aa) * 0.9);
	}
#endif
	float alpha = paint.a;
	if (reveal > 0.0) {
		// The way out: one more pair of arms, of nothing, opening onto the battle.
		alpha *= 1.0 - wave(r, angle, reveal, spin + (newest + 1.0) * STAGGER, corner, aa).mask;
	}
	COLOR = vec4(rgb, alpha * color.a);
}
