extends RefCounted
## Approved living-room recipes and geometry checks; opt-in until the ten-house trial is approved.
const Rooms = preload("res://scripts/gfx/room_builder.gd")
## Visible breathing room, shorter than a walkable tile. Movement footprints stay adjoining.
const STUDIO_LAYOUTS := [0, 4]
const DEDICATED_LAYOUTS := [1, 2, 3, 5]
const SEAT_GAP := 0.24
const SQUARE_SEAT_GAP := 0.36
const OPTIONS := [
 {"id": "01-compact-l", "name": "1. Compact L", "rug": [4, 1, 4, 3], "top": "kk_cactus_small_A",
  "pieces": [["sofa", 5, 2, 2, 1, 0], ["coffee_table", 5, 3, 2, 1, 0], ["armchair", 7, 3, 1, 1, -90], ["side_coffee_table", 7, 2, 1, 1, 0]]},
 {"id": "02-open-u", "name": "2. Open U", "rug": [3, 1, 6, 5], "top": "kk_lamp_table", "offsets": [[4, 3, 0, 0.5], [7, 3, 0, 0.5]],
  "pieces": [["sofa", 5, 2, 2, 1, 0], ["coffee_table", 5, 3, 2, 2, 0], ["armchair", 4, 3, 1, 1, 90], ["armchair", 7, 3, 1, 1, -90], ["side_coffee_table", 7, 2, 1, 1, 0]]},
 {"id": "03-facing-pair", "name": "3. Facing pair", "rug": [4, 1, 4, 5], "top": "kk_cactus_small_A",
  "pieces": [["sofa", 5, 2, 2, 1, 0], ["coffee_table", 5, 3, 2, 2, 0], ["armchair", 5, 5, 1, 1, 180], ["armchair", 6, 5, 1, 1, 180], ["side_coffee_table", 7, 2, 1, 1, 0]]},
 {"id": "04-angled-conversation", "name": "4. Angled conversation", "rug": [3, 1, 6, 5], "top": "kk_lamp_table",
  "pieces": [["sofa", 5, 2, 2, 1, 0], ["coffee_table", 5, 3, 2, 2, 0], ["armchair", 4, 5, 1, 1, 135], ["armchair", 7, 5, 1, 1, -135], ["side_coffee_table", 7, 2, 1, 1, 0]]},
 {"id": "05-narrow-room", "name": "5. Narrow-room lounge", "rug": [1, 1, 4, 5], "top": "kk_lamp_table",
  "pieces": [["sofa", 1, 2, 1, 2, 90], ["coffee_table", 2, 2, 1, 2, 90], ["armchair", 2, 4, 1, 1, 180], ["side_coffee_table", 1, 1, 1, 1, 0]]},
 {"id": "06-corner-conversation", "name": "6. Corner conversation", "rug": [3, 1, 6, 5], "top": "kk_cactus_small_A", "offsets": [[7, 3, 0, 0.5]],
  "pieces": [["sofa", 5, 2, 2, 1, 0], ["armchair", 4, 3, 1, 1, 90], ["armchair", 4, 4, 1, 1, 90], ["coffee_table", 5, 3, 2, 2, 0], ["armchair", 7, 3, 1, 1, -90], ["side_coffee_table", 7, 2, 1, 1, 0]]},
]

var problems := 0
var issues: Array[String] = []

func _problem(message: String) -> void:
	problems += 1
	issues.append(message)

func contact_offsets(world: Node, m: Dictionary) -> Dictionary:
	return _contact_offsets(world, m)

func validate(world: Node, recipe: Dictionary) -> Array[String]:
	problems = 0
	issues.clear()
	_check_contact(world, recipe)
	return issues.duplicate()

func _furniture(world: Node) -> Array:
	return world.get_children().filter(func(n): return n is MeshInstance3D and n.has_meta("furniture_kind"))


func _footprint(node: MeshInstance3D, shift := Vector2.ZERO) -> PackedVector2Array:
	var bb := node.mesh.get_aabb()
	var out := PackedVector2Array()
	for corner in [Vector2(bb.position.x, bb.position.z), Vector2(bb.end.x, bb.position.z), Vector2(bb.end.x, bb.end.z), Vector2(bb.position.x, bb.end.z)]:
		var v: Vector3 = node.transform * Vector3(corner.x, 0, corner.y)
		out.append(Vector2(v.x, v.z) + shift)
	return out


## Separating-axis check retains the chair angles instead of treating them as axis-aligned boxes.
func _overlap(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	for polygon in [a, b]:
		for i in polygon.size():
			var edge: Vector2 = polygon[(i + 1) % polygon.size()] - polygon[i]
			var axis := Vector2(-edge.y, edge.x).normalized()
			var amin := INF
			var amax := -INF
			var bmin := INF
			var bmax := -INF
			for v in a:
				amin = minf(amin, v.dot(axis))
				amax = maxf(amax, v.dot(axis))
			for v in b:
				bmin = minf(bmin, v.dot(axis))
				bmax = maxf(bmax, v.dot(axis))
			if amax <= bmin or bmax <= amin:
				return false
	return true


func _forward(node: MeshInstance3D) -> Vector2:
	var forward := node.basis * Vector3.BACK
	return Vector2(forward.x, forward.z).normalized()


func _contact_offsets(world: Node, m: Dictionary) -> Dictionary:
	var nodes := _furniture(world)
	var table: MeshInstance3D = nodes.filter(func(n): return n.get_meta("furniture_kind") == "coffee_table")[0]
	var target := _footprint(table)
	var offsets: Dictionary = m["room"]["furniture_offsets"].duplicate()
	for node: MeshInstance3D in nodes:
		if not node.get_meta("furniture_kind") in ["sofa", "armchair"]:
			continue
		var forward := _forward(node)
		var start := 0.0
		while _overlap(_footprint(node, forward * start), target) and start > -2.0:
			start -= 0.025
		var travel := start
		while not _overlap(_footprint(node, forward * travel), target) and travel < 3.0:
			travel += 0.025
		if travel >= 3.0:
			_problem("Seat does not face the central table")
			continue
		var low := travel - 0.025
		var high := travel
		for i in 16:
			var mid := (low + high) * 0.5
			if _overlap(_footprint(node, forward * mid), target):
				high = mid
			else:
				low = mid
		var at: Vector2i = node.get_meta("furniture_origin")
		# A visible gap gives the seats breathing room without opening a walkable tile.
		offsets[at] = offsets.get(at, Vector2.ZERO) + forward * (low - _seat_gap(table))
	return offsets


func _check_contact(world: Node, option: Dictionary) -> void:
	var nodes := _furniture(world)
	var table: MeshInstance3D = nodes.filter(func(n): return n.get_meta("furniture_kind") == "coffee_table")[0]
	var target := _footprint(table)
	for kind in ["sofa", "armchair", "side_coffee_table", "coffee_table"]:
		var expected: int = option["pieces"].filter(func(p): return p[0] == kind).size()
		var actual := nodes.filter(func(n): return n.get_meta("furniture_kind") == kind).size()
		if actual != expected:
			_problem("%s: expected %d %s pieces, got %d" % [option["id"], expected, kind, actual])
	var table_size := table.mesh.get_aabb().size
	var rectangular: bool = option["id"] in ["01-compact-l", "05-narrow-room"]
	var expected_width := 1.84 if rectangular else 1.6
	var expected_depth := 0.88 if rectangular else 1.6
	if not is_equal_approx(table_size.x, expected_width) or not is_equal_approx(table_size.z, expected_depth):
		_problem(option["id"] + ": incorrect central table dimensions")
	for node: MeshInstance3D in nodes:
		var kind: String = node.get_meta("furniture_kind")
		if kind in ["sofa", "armchair"]:
			if _overlap(_footprint(node, _forward(node) * (_seat_gap(table) - 0.02)), target) or not _overlap(_footprint(node, _forward(node) * (_seat_gap(table) + 0.02)), target):
				_problem(option["id"] + ": seat clearance differs from the intended non-walkable gap")
		elif kind == "side_coffee_table":
			var size := node.mesh.get_aabb().size
			if not is_equal_approx(size.x, size.z) or size.y > 0.4:
				_problem(option["id"] + ": side table must be square and low")
			var decorated := false
			for child in world.get_children():
				if child is MeshInstance3D and child.mesh == Rooms.piece(option["top"]):
					if Vector2(child.position.x - node.position.x, child.position.z - node.position.z).length() < 0.02:
						decorated = true
			if not decorated:
				_problem(option["id"] + ": missing side-table plant or short lamp")


func _seat_gap(table: MeshInstance3D) -> float:
	var size := table.mesh.get_aabb().size
	return SQUARE_SEAT_GAP if is_equal_approx(size.x, size.z) else SEAT_GAP
