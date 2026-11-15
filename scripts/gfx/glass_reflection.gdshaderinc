// One faint, defocused reflection across the viewport, shared by indoor and outdoor
// glazing. SCREEN_UV keeps adjacent panes from restarting the stripes at their edges.
float glass_reflection(vec2 screen_uv, vec2 viewport_size) {
	float aspect = viewport_size.x / max(viewport_size.y, 1.0);
	float diagonal = screen_uv.x - screen_uv.y * 0.55 / aspect;
	// Broad Gaussian bands with different widths, like softly reflected strip lights.
	float broad = exp(-pow((diagonal - 0.08) / 0.065, 2.0));
	broad += 0.75 * exp(-pow((diagonal - 0.43) / 0.09, 2.0));
	broad += 0.85 * exp(-pow((diagonal - 0.82) / 0.07, 2.0));
	float slim = 0.35 * exp(-pow((diagonal - 0.25) / 0.025, 2.0));
	slim += 0.25 * exp(-pow((diagonal - 0.64) / 0.035, 2.0));
	return clamp(broad + slim, 0.0, 1.0);
}
