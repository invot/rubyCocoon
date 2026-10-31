extends RefCounted
## Shared beach profile for terrain, feet and touch picking. Deep water retains ordinary blocked water tiles.
const WATER_Y := -0.12
const MAX_WADE_DEPTH := 0.05
const WADE_FLOOR := WATER_Y - MAX_WADE_DEPTH
const DEEP_FLOOR := -0.42

static func contains(m: Dictionary, x: float, z: float) -> bool:
	if not m.has("shoreline"):
		return false
	var r: Array = m["shoreline"]
	return x >= float(r[0]) and x <= float(r[2]) and z >= float(r[1])

static func bottom(m: Dictionary, x: float, z: float) -> float:
	if not contains(m, x, z):
		return 0.0
	var r: Array = m["shoreline"]
	var wade_end := float(r[3]) - 2.5
	if z <= wade_end:
		return WADE_FLOOR * smoothstep(float(r[1]), wade_end, z)
	return lerpf(WADE_FLOOR, DEEP_FLOOR, smoothstep(wade_end, float(r[3]), z))

static func step_sound(m: Dictionary, tile: Vector2i) -> String:
	var depth := WATER_Y - bottom(m, tile.x + 0.5, tile.y + 0.5)
	return "step_water" if contains(m, tile.x + 0.5, tile.y + 0.5) and depth > 0.005 and depth <= MAX_WADE_DEPTH + 0.001 else ""
