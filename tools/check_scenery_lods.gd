extends SceneTree
## Recentring must retain authored LOD thresholds/topology as well as base geometry.
const VA = preload("res://scripts/gfx/voxel_assets.gd")
var bad := 0
var checked := 0
var levels := 0

func _initialize() -> void:
	for path in VA.Manifest.ASSETS.values():
		if not String(path).begins_with("res://assets/nature/"):
			continue
		_check(load(path))
	# Force both renderer index widths; normal shipped scenery uses 16-bit indices.
	for count in [8, 65540]:
		var mesh := ArrayMesh.new()
		var vertices := PackedVector3Array()
		vertices.resize(count)
		for i in count:
			vertices[i] = Vector3(10 + i % 5, i % 3, i % 7)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, count - 1, 3, 4])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {0.5: PackedInt32Array([0, 3, count - 1])})
		_expect(VA.surface_lods(mesh, 0) == {0.5: PackedInt32Array([0, 3, count - 1])}, "known LOD indices at both widths")
		_check(mesh)
	var props = load("res://scripts/gfx/voxel_props.gd")
	var world = load("res://scripts/world/world.gd").new()
	world._multimesh(props.lily_pad(), [Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.36), Vector3.ZERO),
		Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.5), Vector3(20, 0, 0))], null, false, props.LILY_SWELL_BOUND)
	_expect(world.get_child_count() == 2, "pad margin survives outdoor chunking")
	for node in world.get_children():
		_expect(node.extra_cull_margin >= (1.0 + 0.45) * 0.045, "full world-space swell covered at every instance scale")
		_expect(node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "pads stay shadowless")
	world.free()
	print("SCENERY LODS DONE: %d problem(s), %d meshes, %d levels" % [bad, checked, levels])
	quit(bad)

func _check(source: ArrayMesh) -> void:
	var source_bounds := source.get_aabb()
	var offset := Vector3(source_bounds.get_center().x, source_bounds.position.y, source_bounds.get_center().z)
	var result: ArrayMesh = VA._recentered(source)
	checked += 1
	_expect(result.get_surface_count() == source.get_surface_count(), "surface count")
	for s in source.get_surface_count():
		var original := source.surface_get_arrays(s)
		var shifted := result.surface_get_arrays(s)
		_expect(result.surface_get_material(s) == source.surface_get_material(s), "material identity")
		_expect(result.surface_get_name(s) == source.surface_get_name(s), "surface name")
		for channel in Mesh.ARRAY_MAX:
			if channel == Mesh.ARRAY_VERTEX:
				var vertices: PackedVector3Array = original[channel]
				for i in vertices.size():
					var expected: Vector3 = vertices[i] - (offset if offset.length() >= 0.01 else Vector3.ZERO)
					if not expected.is_equal_approx(shifted[channel][i]):
						_expect(false, "vertex translation")
						break
			else:
				_expect(original[channel] == shifted[channel], "unchanged channel %d" % channel)
		var before := VA.surface_lods(source, s)
		var after := VA.surface_lods(result, s)
		_expect(before == after, "LOD thresholds and indices")
		levels += before.size()
	_expect(source.get_aabb() == source_bounds, "source bounds unchanged")

func _expect(condition: bool, label: String) -> void:
	if not condition:
		bad += 1
		push_error("scenery recenter: " + label)
