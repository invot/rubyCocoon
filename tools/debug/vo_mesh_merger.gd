extends "res://tools/debug/vo_perf.gd"
## Isolated asset-preparation experiment, not a runtime batching conversion.
const Merger = preload("res://tools/experiments/006/StaticMeshMerger/merge_utils.gd")
const Creole = preload("res://scripts/gfx/creole_builder.gd")
const Finish = preload("res://scripts/gfx/surface_finish.gd")
const VA = preload("res://scripts/gfx/voxel_assets.gd")
const HouseBuilder = preload("res://scripts/gfx/house_builder.gd")

func run(main, opts: Dictionary) -> void:
	var options := opts.duplicate()
	options["passes"] = "3"
	options["duration"] = "0"
	options["benchmark_kind"] = "mesh-merger-006"
	options["position_sampling"] = "240-frame static hold of an isolated structure"
	main.get_window().grab_focus()
	await main.get_tree().process_frame
	await super.run(main, options)

func _route() -> void:
	_main.get_window().title = "Ruby Cocoon - 006 isolated merger - pass %d/3" % (_passes.size() + 1)
	var field = _main.world
	if is_instance_valid(field) and field.get_parent() != null:
		_main.view.remove_child(field)
	var fixture := Node3D.new()
	_main.view.add_child(fixture)
	var building := Creole.build({"shop": "house", "x": 0, "y": 0, "w": 6, "d": 6,
		"door": Vector2i(3, 5), "seed": 12026, "locked": false})
	fixture.add_child(building)
	Finish.apply(building)
	var camera := Camera3D.new()
	fixture.add_child(camera)
	# Same elevated, north-looking perspective as the gameplay camera; isolated structure.
	camera.position = Vector3(8, 8, 12)
	camera.look_at(Vector3(0, 2.5, 0))
	camera.fov = 50
	camera.make_current()
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	fixture.add_child(sun)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#7c9cab")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#b0bdd0")
	environment.environment.ambient_light_energy = 0.6
	fixture.add_child(environment)
	var eligible: Array[MeshInstance3D] = []
	var excluded := 0
	var before_surfaces := 0
	var before_lods := 0
	var door_meshes := []
	for key in HouseBuilder._meshes:
		if String(key).begins_with("door_"):
			door_meshes.append(HouseBuilder._meshes[key])
	for node in building.find_children("*", "MeshInstance3D", true, false):
		var safe: bool = node.skin == null and node.mesh != null and node.get_child_count() == 0 and not (node.mesh in door_meshes)
		if node.mesh != null:
			for s in node.mesh.get_surface_count():
				if node.mesh is ArrayMesh and "door" in node.mesh.surface_get_name(s).to_lower():
					safe = false
				var mat: Material = node.get_active_material(s)
				if not mat is BaseMaterial3D or mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					safe = false
				if String(node.mesh.resource_path).get_file().begins_with("door_") or (mat != null and "door" in String(mat.resource_name).to_lower()):
					safe = false
				if node.mesh is ArrayMesh and not VA.surface_lods(node.mesh, s).is_empty():
					before_lods += 1
					safe = false
		if safe and node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
			eligible.append(node)
			before_surfaces += node.mesh.get_surface_count()
		else:
			excluded += 1
	var began := Time.get_ticks_usec()
	var merged: ArrayMesh = Merger.merge_multiple_meshes(eligible)
	var build_ms := (Time.get_ticks_usec() - began) / 1000.0
	var contract := _contract(eligible, merged)
	var replacement := MeshInstance3D.new()
	replacement.mesh = merged
	fixture.add_child(replacement)
	var candidate := _passes.size() == 1
	replacement.visible = candidate
	for node in eligible:
		node.visible = not candidate
	var frames := 3 if _opts.get("verify", "0") == "1" else 240
	await _main._wait(0.15)
	var positions := []
	for i in frames:
		positions.append(Vector3.ZERO)
	var result := await _measure("merger_%d" % _passes.size(), fixture, camera, positions, func(): pass)
	result["experiment"] = {"part": "merger", "candidate": candidate, "eligible_nodes": eligible.size(),
		"excluded_nodes": excluded, "source_surfaces": before_surfaces, "merged_surfaces": merged.get_surface_count(),
		"excluded_lod_surfaces": before_lods, "build_ms": build_ms,
		"geometry_contract": contract,
		"plugin_commit": "e0de5d302d12ec16161e43bb7afac2e79f0b5aeb",
		"collision": "no generated mesh collision; original tile rules unchanged"}
	_segments["isolated_creole"] = result
	fixture.free()
	if is_instance_valid(field):
		_main.view.add_child(field)
		field.cam.make_current()


func _contract(sources: Array[MeshInstance3D], merged: ArrayMesh) -> Dictionary:
	var expected := {}
	for node in sources:
		for s in node.mesh.get_surface_count():
			var material: Material = node.get_active_material(s)
			if not expected.has(material):
				expected[material] = []
			expected[material].append_array(_vertices(node.mesh, s, node.global_transform))
	var result := {"material_groups": expected.size(), "vertices": 0, "position_error": 0.0,
		"normal_error": 0.0, "uv_error": 0.0, "color_error": 0.0, "valid": true}
	if merged.get_surface_count() != expected.size():
		result.valid = false
	for s in merged.get_surface_count():
		var material := merged.surface_get_material(s)
		var actual := _vertices(merged, s, Transform3D.IDENTITY)
		var original: Array = expected.get(material, [])
		if actual.size() != original.size():
			result.valid = false
			continue
		result.vertices += actual.size()
		for i in actual.size():
			result.position_error = maxf(result.position_error, actual[i][0].distance_to(original[i][0]))
			result.normal_error = maxf(result.normal_error, actual[i][1].distance_to(original[i][1]))
			result.uv_error = maxf(result.uv_error, actual[i][2].distance_to(original[i][2]))
			var a: Color = actual[i][3]
			var b: Color = original[i][3]
			result.color_error = maxf(result.color_error, maxf(absf(a.r-b.r), maxf(absf(a.g-b.g), maxf(absf(a.b-b.b), absf(a.a-b.a)))))
	for key in ["position_error", "normal_error", "uv_error", "color_error"]:
		if result[key] > 0.001:
			result.valid = false
	return result


func _vertices(mesh: Mesh, surface: int, xf: Transform3D) -> Array:
	var arrays := mesh.surface_get_arrays(surface)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var ids: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(positions.size()))
	var normal_xf := xf.basis.inverse().transposed()
	var result := []
	for i in ids:
		var normal: Vector3 = Vector3.ZERO if arrays[Mesh.ARRAY_NORMAL] == null else (normal_xf * arrays[Mesh.ARRAY_NORMAL][i]).normalized()
		var uv: Vector2 = Vector2.ZERO if arrays[Mesh.ARRAY_TEX_UV] == null else arrays[Mesh.ARRAY_TEX_UV][i]
		var color: Color = Color.WHITE if arrays[Mesh.ARRAY_COLOR] == null else arrays[Mesh.ARRAY_COLOR][i]
		result.append([xf * positions[i], normal, uv, color])
	return result
