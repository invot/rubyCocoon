extends RefCounted
## Talking critters keep the trainer rig for battle gestures and focus anchors.
static func dress(rig: Node3D) -> void:
	for mesh in rig.find_children("*", "MeshInstance3D", true, false):
		mesh.visible = false
	var body: Node3D = rig.get_node("Body")
	var root := Node3D.new()
	body.add_child(root)
	rig.set_meta("critter_visual", root)
	var painter = load("res://scripts/story/prison_stage.gd").new()
	painter.sphere(root, Vector3(0, 0.7, 0), Vector3(0.48, 0.64, 0.36), "84717b")
	painter.sphere(root, Vector3(0, 1.25, 0.12), Vector3(0.4, 0.36, 0.36), "84717b")
	painter.sphere(root, Vector3(0, 1.2, 0.48), Vector3(0.19, 0.12, 0.2), "d8a5ac")
	for side in [-1, 1]:
		painter.sphere(root, Vector3(side * 0.21, 1.36, 0.4), Vector3.ONE * 0.035, "252331")
		painter.sphere(root, Vector3(side * 0.4, 0.7, 0.22), Vector3(0.2, 0.15, 0.18), "d8a5ac")
		painter.sphere(root, Vector3(side * 0.23, 0.1, 0.16), Vector3(0.2, 0.1, 0.26), "d8a5ac")
		for finger in 3:
			painter.sphere(root, Vector3(side * 0.4 + (finger - 1) * 0.09, 0.7, 0.4), Vector3(0.035, 0.04, 0.09), "e7d8bd")
	painter.free()
