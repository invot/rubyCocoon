extends RefCounted
## Shared beach profile for terrain, feet and touch picking. Deep water retains ordinary blocked water tiles.
const WATER_Y := -0.12
const MAX_WADE_DEPTH := 0.05
const WADE_FLOOR := WATER_Y - MAX_WADE_DEPTH
const DEEP_FLOOR := -1.65
const MapGen = preload("res://scripts/world/map_gen.gd")
const Elev = preload("res://scripts/world/elevation.gd")

## The lily pad mesh's outer radius at scale 1 (voxel_props.gd lily_pad: 0.45, rippled 2.5%).
const LILY_RADIUS := 0.462
## Without the built ground to ask, how far the sloping bank reaches into a water tile from dry ground beside it.
const LILY_BANK := 0.32

## Small, deterministic clusters on freshwater banks only. Never on beaches, crossings or fishing ripples.
## Every leaf floats whole on open water: its rim is kept clear of the sloping bank, nudged toward the middle of the
## channel or made a little smaller when it would touch, and left out when even that won't fit. `ground` is the built
## terrain's height at (x, z) (terrain_mesh.gd ground_y); without it a fixed bank width stands in for the slope.
## Returns visual transforms; neither the map nor walking/collision data is changed.
static func lily_pads(m: Dictionary, ground := Callable()) -> Array:
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
			var cluster: Array[Vector3] = []
			for offset in [Vector2(-0.25, -0.23), Vector2(0.24, -0.17), Vector2(-0.02, 0.25)]:
				var size := rng.randf_range(0.43, 0.5)
				var spin := rng.randf() * TAU
				var spot := _lily_spot(m, p, Vector2(x + 0.5 + offset.x, z + 0.5 + offset.y), size, cluster, ground)
				if spot.z <= 0.0:
					continue
				cluster.append(spot)
				var at := Vector3(spot.x, Elev.surface(m, p) + WATER_Y + 0.026, spot.y)
				out.append(Transform3D(Basis(Vector3.UP, spin).scaled(Vector3.ONE * spot.z), at))
			if not cluster.is_empty():
				planted.append(p)
	return out


## Where near `want` a leaf of scale `size` floats whole on tile p's water, clear of the bank and not piled on the
## cluster's other leaves: (x, z, scale), or scale 0 when it doesn't fit anywhere close.
static func _lily_spot(m: Dictionary, p: Vector2i, want: Vector2, size: float, cluster: Array[Vector3], ground: Callable) -> Vector3:
	for scale in [size, size * 0.86, 0.36]:
		var best := Vector3.ZERO
		var best_d := INF
		for dz in range(-3, 4):
			for dx in range(-3, 4):
				var at := want + Vector2(dx, dz) * 0.1
				var d := at.distance_squared_to(want)
				if d >= best_d or not lily_floats(m, p, at, scale, ground):
					continue
				if cluster.any(func(o: Vector3) -> bool: return at.distance_to(Vector2(o.x, o.y)) < (o.z + scale) * LILY_RADIUS * 0.85):
					continue
				best = Vector3(at.x, at.y, scale)
				best_d = d
		if best.z > 0.0:
			return best
	return Vector3.ZERO


## Whether a leaf of scale `scale` centred at `at` lies whole on open water of tile p's level: every tile under it is
## water on that level, and the ground under its rim (the built terrain's, or a fixed bank's) stays below the surface.
static func lily_floats(m: Dictionary, p: Vector2i, at: Vector2, scale: float, ground := Callable()) -> bool:
	var level := Elev.surface(m, p)
	var r := scale * LILY_RADIUS + 0.04
	var reach := r + (0.0 if ground.is_valid() else LILY_BANK)
	for tz in range(floori(at.y - reach), floori(at.y + reach) + 1):
		for tx in range(floori(at.x - reach), floori(at.x + reach) + 1):
			var nearest := Vector2(clampf(at.x, tx, tx + 1), clampf(at.y, tz, tz + 1))
			if nearest.distance_to(at) >= reach:
				continue
			var q := Vector2i(tx, tz)
			if MapGen.get_t(m, tx, tz) != MapGen.WATER or Elev.diagonal(m, q) != 0 or not is_equal_approx(Elev.surface(m, q), level):
				return false
	if not ground.is_valid():
		return true
	var surface := level + WATER_Y - 0.03
	if float(ground.call(at.x, at.y)) >= surface:
		return false
	for k in 16:
		var a := TAU * k / 16.0
		if float(ground.call(at.x + cos(a) * r, at.y + sin(a) * r)) >= surface:
			return false
	return true


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
	# The profile lowers sand and water, never the grassy verge or a rock headland inside its rectangle.
	# Keeping dry ground at its own height preserves the same raised turf edge used beside paths.
	if m.has("grid"):
		var tx := clampi(floori(x), 0, int(m["w"]) - 1)
		var tz := clampi(floori(z), 0, int(m["h"]) - 1)
		if MapGen.get_t(m, tx, tz) not in [MapGen.SAND, MapGen.SHALLOWS, MapGen.WATER]:
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
