extends RefCounted
## The pieces of a temple's puzzles and the roads to it: the levers that drain its floods (map_loader.gd "floods"),
## treasure chests, and an ornate stone bridge. Built from VBld.Kit boxes, in the soft stone and wood of the rest.

const VBld = preload("res://scripts/gfx/voxel_buildings.gd")

const STONE := Color("#b8b0a0")
const BRONZE := Color("#c89a48")
const WOOD := Color("#8a5a32")
const GOLD := Color("#e8c050")


## A lever on a stone block: its bronze arm leans back (north) until pulled, then forward. The arm is the "Arm" node,
## pivoting on its hinge, for Story to swing (pull()).
static func lever(pulled: bool) -> Node3D:
	var root := Node3D.new()
	var k := VBld.Kit.new()
	k.box("color", Vector3(0, 0.22, 0), Vector3(0.62, 0.44, 0.5), STONE)
	k.box("color", Vector3(0, 0.47, 0), Vector3(0.7, 0.06, 0.58), STONE.lightened(0.12))
	# the slot the arm swings in
	k.box("color", Vector3(0, 0.505, 0), Vector3(0.12, 0.02, 0.42), Color("#2a2622"))
	var base := MeshInstance3D.new()
	base.mesh = k.mesh()
	root.add_child(base)
	var arm := Node3D.new()
	arm.name = "Arm"
	arm.position = Vector3(0, 0.5, 0)
	var a := VBld.Kit.new()
	a.box("tin", Vector3(0, 0.36, 0), Vector3(0.08, 0.72, 0.08), BRONZE)
	a.box("color", Vector3(0, 0.76, 0), Vector3(0.18, 0.16, 0.18), Color("#3a8ab0"))
	var am := MeshInstance3D.new()
	am.mesh = a.mesh()
	arm.add_child(am)
	arm.rotation.x = arm_angle(pulled)
	root.add_child(arm)
	return root


## The arm's lean: back (north, -z) before it's pulled, forward after.
static func arm_angle(pulled: bool) -> float:
	return 0.6 if pulled else -0.6


## Swings a lever's arm forward.
static func pull(node: Node3D) -> void:
	var arm: Node3D = node.get_node_or_null("Arm")
	if arm == null:
		return
	var tw := node.create_tween()
	tw.tween_property(arm, "rotation:x", arm_angle(true), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished


## A wooden treasure chest banded in gold, its lid ("Lid", hinged along the back) shut or thrown open.
static func chest(open: bool) -> Node3D:
	var root := Node3D.new()
	var k := VBld.Kit.new()
	k.box("planks", Vector3(0, 0.2, 0), Vector3(0.7, 0.4, 0.48), WOOD)
	for x: float in [-0.24, 0.24]:
		k.box("tin", Vector3(x, 0.2, 0), Vector3(0.07, 0.42, 0.5), GOLD)
	k.box("tin", Vector3(0, 0.26, 0.245), Vector3(0.12, 0.14, 0.02), GOLD)
	if open:
		# the gleam inside
		k.box("glow", Vector3(0, 0.39, 0), Vector3(0.6, 0.02, 0.38), Color("#ffe8a0"))
	var body := MeshInstance3D.new()
	body.mesh = k.mesh()
	root.add_child(body)
	var lid := Node3D.new()
	lid.name = "Lid"
	lid.position = Vector3(0, 0.4, -0.24)
	var l := VBld.Kit.new()
	l.box("planks", Vector3(0, 0.08, 0.24), Vector3(0.72, 0.16, 0.5), WOOD.lightened(0.08))
	for x: float in [-0.24, 0.24]:
		l.box("tin", Vector3(x, 0.08, 0.24), Vector3(0.07, 0.18, 0.52), GOLD)
	var lm := MeshInstance3D.new()
	lm.mesh = l.mesh()
	lid.add_child(lm)
	lid.rotation.x = -1.9 if open else 0.0
	root.add_child(lid)
	return root


## Throws a chest's lid open.
static func open_chest(node: Node3D) -> void:
	var lid: Node3D = node.get_node_or_null("Lid")
	if lid == null:
		return
	var tw := node.create_tween()
	tw.tween_property(lid, "rotation:x", -1.9, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished


## An ornate stone bridge `span_len` tiles long and `wide` across, running along x (its middle at the origin, its deck at
## y = 0): a paved deck on a low arch, and balustrades of little columns under a capped rail, ending in a newel post
## at each corner.
static func ornate_bridge(span_len: int, wide: int) -> ArrayMesh:
	var k := VBld.Kit.new()
	var hl := span_len / 2.0
	var hw := wide / 2.0
	var pale := Color("#e6dccb")
	var warm := Color("#d4c4a6")
	# the deck, a shade warmer down its middle
	k.box("color", Vector3(0, -0.06, 0), Vector3(span_len + 0.2, 0.14, wide + 0.1), pale)
	k.box("color", Vector3(0, 0.005, 0), Vector3(span_len + 0.2, 0.01, wide - 0.6), warm)
	# the arch under it: stepped courses, deepest at the ends
	for i in 4:
		var span := span_len - 0.6 * i
		k.box("color", Vector3(0, -0.22 - 0.12 * i, 0), Vector3(span, 0.14, wide - 0.1), pale.darkened(0.06 * (i + 1)), true)
	for e: int in [-1, 1]:
		k.box("color", Vector3(e * (hl - 0.15), -0.55, 0), Vector3(0.5, 0.9, wide + 0.1), pale.darkened(0.1), true)
	# balustrades: base, columns, capped rail
	for s: int in [-1, 1]:
		var z := s * (hw - 0.08)
		k.box("color", Vector3(0, 0.07, z), Vector3(span_len + 0.2, 0.14, 0.2), pale)
		var n := int(span_len * 3)
		for i in n + 1:
			var x := -hl + float(i) * span_len / n
			k.box("color", Vector3(x, 0.32, z), Vector3(0.09, 0.36, 0.09), pale.lightened(0.05))
		k.box("color", Vector3(0, 0.55, z), Vector3(span_len + 0.2, 0.1, 0.24), pale.lightened(0.08))
		for e: int in [-1, 1]:
			var c := Vector3(e * (hl + 0.05), 0, z)
			k.box("color", c + Vector3(0, 0.38, 0), Vector3(0.32, 0.76, 0.32), pale)
			k.box("color", c + Vector3(0, 0.8, 0), Vector3(0.38, 0.08, 0.38), pale.lightened(0.08))
			k.box("color", c + Vector3(0, 0.92, 0), Vector3(0.22, 0.16, 0.22), pale.lightened(0.04))
	return k.mesh()


## Rails along a plain plank bridge's sides: posts at each tile's corner and a rope-bound rail, `span_len` tiles long,
## running along x (the deck's middle at the origin, its top at y = 0), `wide` tiles across.
static func bridge_rails(span_len: int, wide: int) -> ArrayMesh:
	var k := VBld.Kit.new()
	var hl := span_len / 2.0
	var hw := wide / 2.0
	for s: int in [-1, 1]:
		var z := s * (hw - 0.06)
		for i in span_len + 1:
			k.box("planks", Vector3(-hl + i, 0.3, z), Vector3(0.1, 0.6, 0.1), WOOD.darkened(0.1))
		k.box("planks", Vector3(0, 0.55, z), Vector3(span_len + 0.1, 0.07, 0.07), WOOD)
		k.box("color", Vector3(0, 0.33, z), Vector3(span_len, 0.03, 0.03), Color("#c8b080"))
	return k.mesh()
