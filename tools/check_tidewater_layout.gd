extends SceneTree
## Geometry regressions for Tidewater's recessed galleries and closed arena shoulders.
## Run with --headless --path . --script res://tools/check_tidewater_layout.gd.
const MapLoader = preload("res://scripts/world/map_loader.gd")
const MapGen = preload("res://scripts/world/map_gen.gd")
const Elev = preload("res://scripts/world/elevation.gd")
const ItemDB = preload("res://scripts/data/item_db.gd")
const HarborBoats = preload("res://scripts/gfx/harbor_boats.gd")
const VA = preload("res://scripts/gfx/voxel_assets.gd")
const Creole = preload("res://scripts/gfx/creole_builder.gd")

var problems := 0

func _init() -> void:
	for shop in ["uncle", "bookstore", "apothecary", "electronics", "house"]:
		var building := Creole.build({"shop": shop, "x": 0, "y": 0, "w": 5, "d": 3,
			"door": Vector2i(2, 2), "seed": 10})
		var triangles := _triangles(building)
		for vertex in triangles:
			if vertex.z > 1.51:
				_fail("%s gallery or porch projects onto the path" % shop)
				break
		building.free()
	var arena := Creole.build({"shop": "arena", "x": 0, "y": 0, "w": 8, "d": 5,
		"door": Vector2i(4, 4), "seed": 10})
	var triangles := _triangles(arena)
	# Rays beside both pavilion shoulders must hit the front shell, rather than the back wall.
	for x in [-2.0, -1.6, 2.2, 2.6]:
		var front_hit := false
		for i in range(0, triangles.size(), 3):
			var hit = Geometry3D.ray_intersects_triangle(Vector3(x, 1.6, 6), Vector3.FORWARD,
				triangles[i], triangles[i + 1], triangles[i + 2])
			if hit != null and hit.z > 0:
				front_hit = true
				break
		if not front_hit:
			_fail("arena shoulder at x=%.1f exposes the back wall" % x)
	arena.free()
	_waterfront()
	print("TIDEWATER LAYOUT DONE: %d problem(s)" % problems)
	quit(1 if problems else 0)

func _triangles(node: Node3D, parent := Transform3D.IDENTITY) -> PackedVector3Array:
	var out := PackedVector3Array()
	var xf := parent * node.transform
	if node is MeshInstance3D and node.mesh != null:
		for vertex in node.mesh.get_faces():
			out.append(xf * vertex)
	for child in node.get_children():
		if child is Node3D:
			out.append_array(_triangles(child, xf))
	return out

func _fail(message: String) -> void:
	problems += 1
	print("FAIL " + message)


func _waterfront() -> void:
	var m := MapLoader.load_map("tidewater", {})
	var reached := {Vector2i(10, 24): true}
	var queue := [Vector2i(10, 24)]
	var index := 0
	while index < queue.size():
		var p: Vector2i = queue[index]
		index += 1
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var q: Vector2i = p + d
			if q.x < 0 or q.x >= m["w"] or q.y < 0 or q.y >= m["h"] or reached.has(q):
				continue
			if MapGen.walkable(MapGen.get_t(m, q.x, q.y)) and Elev.joined(m, p, q):
				reached[q] = true
				queue.append(q)
	for x in [10, 11, 23, 24, 25, 44, 45, 60, 61]:
		for y in [26, 27, 28, 29]:
			if not reached.has(Vector2i(x, y)):
				_fail("stair route unreachable at %d,%d" % [x, y])
		if Elev.ramp_dir(m, Vector2i(x, 26)) != Vector2i.ZERO:
			_fail("quay wall row must remain level")
	# Decking meets the retaining wall directly, with two full rows even at the eastern return.
	for x in range(2, 74):
		for y in [28, 29]:
			if Elev.ramp_dir(m, Vector2i(x, y)) != Vector2i.ZERO:
				continue
			if MapGen.get_t(m, x, y) != MapGen.BRIDGE or not reached.has(Vector2i(x, y)):
				_fail("continuous two-tile boardwalk broken at %d,%d" % [x, y])
		if MapGen.get_t(m, x, 27) == MapGen.WATER:
			_fail("water gap between the marina and stone wall at x=%d" % x)
	if m["buildings"][11]["interior"] != "tidewater#11" or m["buildings"][11]["x"] != 4:
		_fail("Gil's saved building identity changed")
	for y in range(31, 37):
		for x in range(42, 48):
			var expected := MapGen.BRIDGE if x in [44, 45] else MapGen.WATER
			if MapGen.get_t(m, x, y) != expected:
				_fail("steamboat pier must be straight and exactly two tiles wide")
	for y in range(18, 27):
		if MapGen.get_t(m, 73, y) != MapGen.FENCE:
			_fail("eastern shoreline must be closed below the arena")
	_boat_clearance(m)
	var shack: Dictionary = m["buildings"][12]
	if not reached.has(shack["door"] + Vector2i.DOWN):
		_fail("equipment shack doorstep unreachable")
	if not m.get("over_water", {}).has(shack["door"]):
		_fail("equipment shack must stand over the water")
	var room := MapLoader.load_map(shack["interior"], {})
	if room["room_key"] != "harbour_shack":
		_fail("eastern shack does not use its equipment room")
	for id in ["rope_collar", "cloth_band", "twine_anklet"]:
		var item: Dictionary = ItemDB.ITEMS[id]
		if item["kind"] != "gear" or item["tier"] != 0 or item["mods"].values() != [0.05]:
			_fail("harbour gear must be starter-strength beast gear: " + id)
		if not ("item:" + id) in room["room"]["anchors"].values():
			_fail("missing gear pickup: " + id)
	var cove := MapLoader.load_map("caccoon", {})
	if not cove["signs"].has(Vector2i(29, 20)) or cove["signs"].has(Vector2i(31, 21)):
		_fail("library sign must be beside the facade, clear of the doorway")


## Check actual transformed mesh bounds, including paddle wheels, hulls and sail booms.
func _boat_clearance(m: Dictionary) -> void:
	var berths := []
	for boat in m["boats"]:
		var name := String(boat[3])
		var bounds: AABB = HarborBoats.mesh(name).get_aabb() if HarborBoats.has(name) else VA.aabb(name)
		var scale := float(boat[4]) / maxf(bounds.size.x, bounds.size.z)
		var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(float(boat[2]))).scaled(Vector3.ONE * scale), Vector3(float(boat[0]), 0, float(boat[1])))
		bounds = xf * bounds
		var berth := Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z)).grow(0.15)
		for y in range(maxi(0, floori(berth.position.y)), mini(m["h"], ceili(berth.end.y))):
			for x in range(maxi(0, floori(berth.position.x)), mini(m["w"], ceili(berth.end.x))):
				if MapGen.get_t(m, x, y) != MapGen.WATER:
					_fail("%s bounds %s overlap dock/shore at %d,%d" % [name, berth, x, y])
		for other in berths:
			if berth.intersects(other["rect"]):
				_fail("%s overlaps %s" % [name, other["name"]])
		berths.append({"name": name, "rect": berth})
