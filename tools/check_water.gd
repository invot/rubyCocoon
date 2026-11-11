extends SceneTree
## Seabed drawing must never alter walking elevations, wading limits, or the height of separate river reaches.
const Terrain = preload("res://scripts/world/terrain_mesh.gd")
const MapGen = preload("res://scripts/world/map_gen.gd")
const Shoreline = preload("res://scripts/world/shoreline.gd")
const MapLoader = preload("res://scripts/world/map_loader.gd")
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
	_check_fall_join()
	# A shoreline rectangle can include a grassy bank; the profile must leave that bank raised and dry.
	var verge := MapGen._new_map("beach_verge", "route", 4, 4)
	verge["shoreline"] = [0, 0, 4, 6]
	MapGen.set_t(verge, 1, 1, MapGen.BUSH)
	check(is_zero_approx(Shoreline.bottom(verge, 1.5, 1.5)), "shore profile never sinks a planted grass bank")
	var rim := Terrain.new()
	rim.setup(4, 4, 42, verge)
	for z in 4:
		for x in 4:
			rim.set_tile(x, z, "sand", 0.0)
	rim.set_tile(1, 1, "grass", 0.0, false, 0, true)
	check(is_equal_approx(rim._vertex_y(1, 1, 3, 3), Terrain.LIFT), "shore profile preserves the turf pillow height")
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
	# Audit actual authored maps: freshwater decoration must never spread onto beaches or change gameplay tiles.
	var pad_count := 0
	for id in MapGen.WorldDB.TOWNS.keys() + MapGen.WorldDB.ROUTES.keys():
		var real := MapLoader.load_map(id, {})
		var before = real["grid"].duplicate()
		var pads := Shoreline.lily_pads(real)
		if id == "riverbend":
			check(MapGen.get_t(real, 7, 15) == MapGen.BUSH, "Riverbend's stone fence ends before the waterfall's low planted bank")
			for x in [7, 8, 9, 10]:
				check(is_equal_approx(Shoreline.Elev.surface(real, Vector2i(x, 15)), 1.0), "both banks enclose Riverbend's waterfall crest")
				check(is_zero_approx(Shoreline.Elev.surface(real, Vector2i(x, 16))), "both banks reach Riverbend's waterfall foot")
		check(real["grid"] == before, "%s: decoration leaves navigation intact" % id)
		check(pads == Shoreline.lily_pads(real), "%s: stable clusters on reload" % id)
		if id in ["caccoon", "tidewater", "shellhaven", "kelpwick", "route1", "route2", "reef"]:
			check(pads.is_empty(), "%s: no lily pads in coastal water" % id)
		pad_count += pads.size()
		for xf: Transform3D in pads:
			var tile := Vector2i(floori(xf.origin.x), floori(xf.origin.z))
			check(MapGen.get_t(real, tile.x, tile.y) == MapGen.WATER, "%s: pads stay on blocked water" % id)
			check(Shoreline.lily_floats(real, tile, Vector2(xf.origin.x, xf.origin.z), xf.basis.get_scale().x),
				"%s: the pad at %s floats whole, clear of the bank" % [id, xf.origin])
			for dz in range(-2, 3):
				for dx in range(-2, 3):
					check(MapGen.get_t(real, tile.x + dx, tile.y + dz) not in [MapGen.SAND, MapGen.SHALLOWS], "%s: no pads near beaches" % id)
		if not pads.is_empty():
			print("LILY PADS %s: %d, first=%s" % [id, pads.size(), pads[0].origin])
	check(pad_count > 0, "freshwater maps have lily pad clusters")
	print("WATER CHECK DONE: %d problem(s)" % bad)
	quit(1 if bad > 0 else 0)


func _check_fall_join() -> void:
	var levels := PackedFloat32Array([1, 1, 0, 0])
	var directions := PackedByteArray([0, 0, 0, 0])
	var m := {"w": 2, "h": 2, "grid": PackedByteArray([MapGen.WATER, MapGen.WATER, MapGen.WATER, MapGen.WATER]),
		"elev": {"lo": levels, "hi": levels.duplicate(), "dir": directions}}
	var t := Terrain.new()
	t.setup(2, 2, 42, m)
	for z in 2:
		for x in 2:
			t.set_tile(x, z, "bed", -0.42, false, 1)
	t._prepare_water_bed()
	t._prepare_fall_offsets()
	var arrays := t._liquid_mesh(1).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var checked_top := false
	var checked_foot := false
	for i in verts.size():
		if normals[i].z < 0.99 or not is_equal_approx(verts[i].x, 1.0):
			continue
		check(verts[i].z < 1.0, "falling sheet is recessed behind the cliff's original edge")
		var connected := false
		for j in verts.size():
			if normals[j].y > 0.99 and verts[i].is_equal_approx(verts[j]):
				connected = true
				break
		check(connected, "fall's top and foot share vertices with horizontal water")
		checked_top = checked_top or is_zero_approx(uvs[i].y)
		checked_foot = checked_foot or uvs[i].y > 0.9
	check(checked_top and checked_foot, "join audit covered both ends of the fall")
	check(t._grid(0, 0)[8].z < 1.0 - Terrain.FALL_SETBACK, "backing rock stays behind the recessed water")
	check(m["elev"]["lo"] == PackedFloat32Array([1, 1, 0, 0]), "recessing the channel leaves gameplay heights intact")

func check(ok: bool, label: String) -> void:
	if not ok:
		bad += 1
		print("FAIL ", label)
