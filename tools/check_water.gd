extends SceneTree
## Seabed drawing must never alter walking elevations, wading limits, or the height of separate river reaches.
const Terrain = preload("res://scripts/world/terrain_mesh.gd")
const MapGen = preload("res://scripts/world/map_gen.gd")
const Shoreline = preload("res://scripts/world/shoreline.gd")
var bad := 0

func _initialize() -> void:
	var grid := PackedInt32Array([MapGen.WATER, MapGen.BRIDGE, MapGen.BUILDING, MapGen.WATER, MapGen.GRASS,
		MapGen.GRASS, MapGen.GRASS, MapGen.GRASS, MapGen.GRASS, MapGen.GRASS,
		MapGen.WATER, MapGen.BRIDGE, MapGen.BRIDGE, MapGen.WATER, MapGen.GRASS])
	var low := PackedFloat32Array([0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 3, 4, 4, 3, 3])
	var dirs := PackedByteArray()
	dirs.resize(15)
	var m := {"w": 5, "h": 3, "grid": grid, "over_water": {Vector2i(2, 0): true},
		"elev": {"lo": low, "hi": low.duplicate(), "dir": dirs}}
	var original := low.duplicate()
	var t := Terrain.new()
	t.setup(5, 3, 123, m)
	for z in 3:
		for x in 5:
			var wet: bool = grid[x + z * 5] in [MapGen.WATER, MapGen.BRIDGE, MapGen.BUILDING]
			t.set_tile(x, z, "bed" if wet else "grass", -0.42 if wet else 0.0, false, 1 if wet else 0)
	t._lower_dock_beds()
	t._prepare_water_bed()
	check(m["elev"]["lo"] == original and m["elev"]["hi"] == original, "walking elevations are unchanged")
	check(is_zero_approx(t.base_lo[1]) and is_zero_approx(t.base_lo[2]), "sea stays below a raised dock and over-water building")
	check(is_equal_approx(t.base_lo[11], 3.0) and is_equal_approx(t.base_lo[12], 3.0), "a separate high river keeps its own level")
	check(t._vertex_y(1, 0, 2, 1) < -0.1, "the bed below the dock is submerged")
	var beach := {"shoreline": [23, 21, 60, 26]}
	for x in range(23, 60):
		var depth := Shoreline.WATER_Y - Shoreline.bottom(beach, x + 0.5, 23.5)
		check(depth > 0.0 and depth <= Shoreline.MAX_WADE_DEPTH + 0.001, "wading limit at beach column %d" % x)
		var last := 0.0
		for step in 101:
			var z := 21.0 + step * 0.05
			var y := Shoreline.bottom(beach, x + 0.5, z)
			check(y <= last + 0.001, "the beach slopes continuously out to sea")
			last = y
	print("WATER CHECK DONE: %d problem(s)" % bad)
	quit(1 if bad > 0 else 0)

func check(ok: bool, label: String) -> void:
	if not ok:
		bad += 1
		print("FAIL ", label)
