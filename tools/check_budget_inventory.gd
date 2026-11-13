extends SceneTree
const Inventory = preload("res://tools/debug/budget_inventory.gd")


func _initialize() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var camera := Camera3D.new()
	scene.add_child(camera)
	var opaque := StandardMaterial3D.new()
	var texture := GradientTexture2D.new()
	texture.width = 16
	texture.height = 16
	opaque.albedo_texture = texture
	var blended := StandardMaterial3D.new()
	blended.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blended.albedo_texture = texture
	var mesh := BoxMesh.new()
	mesh.material = opaque
	var single := MeshInstance3D.new()
	single.mesh = mesh
	single.material_overlay = blended
	single.hide()
	scene.add_child(single)
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.mesh = mesh
	batch.multimesh.instance_count = 2
	batch.multimesh.set_instance_transform(1, Transform3D(Basis.IDENTITY, Vector3(100, 0, 0)))
	scene.add_child(batch)
	var inventory := Inventory.new()
	var result := inventory.collect(scene, camera)
	var expected := {"geometry_nodes": 2, "source_triangles": 36, "surface_submissions": 3,
		"distinct_materials": 2, "distinct_textures": 1, "transparent_surfaces": 1,
		"texture_rgba8_mip_bytes": ceili(16 * 16 * 4.0 * 4.0 / 3.0)}
	var bad := 0
	for metric in expected:
		if result.get(metric) != expected[metric]:
			push_error("%s: %s != %s" % [metric, result.get(metric), expected[metric]])
			bad += 1
	# Repeated collection must not retain material/texture traversal state.
	if inventory.collect(scene, camera) != result:
		push_error("inventory changed across identical calls")
		bad += 1
	scene.free()
	print("BUDGET INVENTORY DONE: %d problem(s)" % bad)
	quit(0 if bad == 0 else 1)
