extends SceneTree
## Geometry regressions for Tidewater's recessed galleries and closed arena shoulders.
## Run with --headless --path . --script res://tools/check_tidewater_layout.gd.
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
