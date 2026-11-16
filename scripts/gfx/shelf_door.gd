extends Node3D
## One half-width glazed leaf slides across a recessed shelf. World owns input and pickup rules.
var tiles: Array[Vector2i] = []
var bounds := AABB()
var leaf: Node3D
var opened := false
var sliding := false
var travel := 0.0
var reward := {}
var prize: Node3D
const FRAME := 0.09


func setup(at: Vector3, width: float, bottom: float, top: float, wood: Material, glass: Material) -> void:
	position = at
	travel = width / 2.0
	var height := top - bottom
	for sy in [bottom, top]:
		_box(self, Vector3(0, sy, 0), Vector3(width, FRAME, 0.07), wood)
	leaf = Node3D.new()
	add_child(leaf)
	leaf.position.x = -width / 4.0
	_box(leaf, Vector3(0, (bottom + top) / 2.0, 0), Vector3(travel - FRAME, height - FRAME, 0.018), glass)
	for sx in [-travel / 2.0, travel / 2.0]:
		_box(leaf, Vector3(sx, (bottom + top) / 2.0, 0.01), Vector3(FRAME, height, 0.06), wood)
	for sy in [bottom, top]:
		_box(leaf, Vector3(0, sy, 0.01), Vector3(travel, FRAME, 0.06), wood)
	_box(leaf, Vector3(travel / 2.0 - 0.075, (bottom + top) / 2.0, 0.055), Vector3(0.045, minf(0.2, height * 0.3), 0.06), wood)
	bounds = AABB(at + Vector3(-width / 2.0, bottom, -0.08), Vector3(width, height, 0.2))


func stock(item: String, flag: String, tile: Vector2i, mesh: Mesh, mat: Material, bottom: float) -> void:
	# (looked up at run time: tool scripts build rooms without the autoloads)
	var state: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("GameState")
	var swap: Dictionary = {}
	if state != null:
		if state.flag(flag) and not state.flags.has("bag_swap:" + flag):
			return
		swap = state.flags.get("bag_swap:" + flag, {})
	prize = MeshInstance3D.new()
	prize.mesh = mesh
	prize.material_override = mat
	var bb := mesh.get_aabb()
	var fit := minf(0.24 / maxf(bb.size.y, 0.01), minf(travel * 0.45 / maxf(bb.size.x, 0.01), 0.16 / maxf(bb.size.z, 0.01)))
	prize.scale = Vector3.ONE * fit
	prize.position = Vector3(-travel / 2.0 - bb.get_center().x * fit, bottom - bb.position.y * fit, -0.16 - bb.get_center().z * fit)
	prize.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	prize.visible = false
	add_child(prize)
	reward = {"item": swap.get("item", item), "count": swap.get("count", 1), "flag": flag, "pos": tile, "node": prize}


func use(world: Node) -> void:
	if sliding:
		return
	if opened and not reward.is_empty() and is_instance_valid(prize):
		await world._pickup(reward)
		return
	sliding = true
	opened = not opened
	var tween := create_tween()
	tween.tween_property(leaf, "position:x", travel / 2.0 if opened else -travel / 2.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if is_instance_valid(prize):
		prize.visible = false
	await tween.finished
	if is_instance_valid(prize):
		prize.visible = opened
	sliding = false


func _box(root: Node3D, at: Vector3, size: Vector3, mat: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(instance)
