extends RefCounted
## Shared beach profile for terrain, feet and touch picking. Deep water retains ordinary blocked water tiles.
const WATER_Y := -0.12
const MAX_WADE_DEPTH := 0.05
const WADE_FLOOR := WATER_Y - MAX_WADE_DEPTH
const DEEP_FLOOR := -1.65
const MapGen = preload("res://scripts/world/map_gen.gd")
const Elev = preload("res://scripts/world/elevation.gd")

## Small, deterministic clusters on freshwater banks only. Never on beaches, crossings or fishing ripples.
## Returns visual transforms; neither the map nor walking/collision data is changed.
static func lily_pads(m: Dictionary) -> Array:
	var out := []
	if not m.get("biome", {}).get("lily_pads", false) or m.get("kind", "") == "interior":
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = String(m.get("id", "")).hash() + 4721
	var planted: Array[Vector2i] = []
	for z in range(2, int(m["h"]) - 2):
		for x in range(2, int(m["w"]) - 2):
			var p := Vector2i(x, z)
			if not _lily_bank(m, p) or rng.randf() > 0.38:
				continue
			if planted.any(func(q: Vector2i) -> bool: return p.distance_squared_to(q) < 9):
				continue
			planted.append(p)
			for offset in [Vector2(-0.25, -0.23), Vector2(0.24, -0.17), Vector2(-0.02, 0.25)]:
				var size := rng.randf_range(0.43, 0.5)
				var at := Vector3(x + 0.5 + offset.x, Elev.surface(m, p) + WATER_Y + 0.026, z + 0.5 + offset.y)
				out.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), at))
	return out


static func _lily_bank(m: Dictionary, p: Vector2i) -> bool:
	if MapGen.get_t(m, p.x, p.y) != MapGen.WATER or Elev.diagonal(m, p) != 0:
		return false
	var bank := false
	var level := Elev.surface(m, p)
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var q := p + Vector2i(dx, dz)
			var tile := MapGen.get_t(m, q.x, q.y)
			if tile in [MapGen.SAND, MapGen.SHALLOWS] or contains(m, q.x + 0.5, q.y + 0.5):
				return false
			if absi(dx) <= 1 and absi(dz) <= 1 and (tile in [MapGen.BRIDGE, MapGen.BUILDING, MapGen.DOOR] or m.get("over_water", {}).has(q)):
				return false
			if dx * dx + dz * dz < 4 and m.get("fish_spots", {}).has(q):
				return false
			# The gameplay camera looks north: don't plant the cluster behind a southern tree crown.
			if dz > 0 and absi(dx) <= 1 and tile == MapGen.TREE:
				return false
			if absi(dx) + absi(dz) == 1 and tile in [MapGen.GRASS, MapGen.TALL, MapGen.FLOWERS, MapGen.BUSH, MapGen.TREE] \
					and is_equal_approx(Elev.surface(m, q), level) and Elev.diagonal(m, q) == 0:
				bank = true
	for boat in m.get("boats", []):
		if Vector2(p.x + 0.5, p.y + 0.5).distance_to(Vector2(boat[0], boat[1])) < float(boat[4]) * 0.5 + 2.0:
			return false
	return bank

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
		var curve := (sin(x * 0.42) + sin(x * 0.93) * 0.35) * 0.3
		return WADE_FLOOR * smoothstep(float(r[1]) + curve, wade_end, z)
	return lerpf(WADE_FLOOR, DEEP_FLOOR, smoothstep(wade_end, float(r[3]), z))

static func step_sound(m: Dictionary, tile: Vector2i) -> String:
	var depth := WATER_Y - bottom(m, tile.x + 0.5, tile.y + 0.5)
	return "step_water" if contains(m, tile.x + 0.5, tile.y + 0.5) and depth > 0.005 and depth <= MAX_WADE_DEPTH + 0.001 else ""
