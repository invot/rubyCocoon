extends "res://tools/debug/vo_perf.gd"
## 006: isolated experiments. No production settings or source meshes are modified.
const VA = preload("res://scripts/gfx/voxel_assets.gd")
const VP = preload("res://scripts/gfx/voxel_props.gd")
var _occluders := []
var _ranged := []


func run(main, opts: Dictionary) -> void:
	if not opts.get("part", "chunks4") in ["chunks4", "chunks16", "lod", "occlusion", "distance", "pads", "suite"]:
		_fail("unknown scenery experiment")
		return
	var options := opts.duplicate()
	options["passes"] = "3"
	options["duration"] = "0"
	options["benchmark_kind"] = "scenery-006"
	options["position_sampling"] = "240 uniform samples along each cardinal path; static freshwater hold"
	if opts.get("await_focus", "0") == "1":
		main.get_window().title = "Ruby Cocoon - 006 waiting " + String(opts.get("report", "")).get_base_dir().get_file()
	main.get_window().grab_focus()
	await main.get_tree().process_frame
	await super.run(main, options)


func _route() -> void:
	var part: String = _opts.get("part", "chunks4")
	if part == "suite":
		for experiment in ["chunks4", "chunks16", "occlusion", "distance", "pads"]:
			await _experiment(experiment)
		var merger = load("res://tools/debug/vo_mesh_merger.gd").new()
		merger._main = _main
		merger._opts = _opts
		merger._passes = _passes
		await merger._route()
		bad += merger.bad
		_segments.merge(merger._segments)
	else:
		await _experiment(part)


func _experiment(part: String) -> void:
	var candidate := _passes.size() == 1
	var entries := [{"id": "route1", "spawn": "west", "goal": "east"},
			{"id": "caccoon", "spawn": Vector2i(30, 22), "goal": Vector2i(38, 27)},
			{"id": "tidewater", "spawn": "west", "goal": Vector2i(40, 8)}]
	if part == "pads":
		entries = [{"id": "riverbend", "spawn": "start", "goal": "start"}]
	for entry in entries:
		if _opts.has("maps") and not entry.id in String(_opts.maps).split(","):
			continue
		await _arrive(entry.id, entry.spawn)
		var world = _main.world
		_main.get_window().title = "Ruby Cocoon - 006 %s %s - pass %d/3" % [part, entry.id, _passes.size() + 1]
		if part == "occlusion" and entry.id == "tidewater":
			# A short dense-street walk keeps the initial conservative occluders relevant
			# throughout the comparison instead of walking beyond the retained building cache.
			var approach := _path(world, world.player_pos, entry.goal)
			if approach.size() > 7:
				world.spawn_at(approach[-7])
		var pad_start: Vector2i = world.player_pos
		if part == "pads":
			pad_start = _pad_bank(world)
			world.spawn_at(pad_start)
		for i in 90:
			world._process(DT)
		var audit := _bounds(world)
		var setup := {"part": part, "candidate": candidate, "bounds": audit,
			"source_batches": _batches(world).size()}
		var temporary := Node3D.new()
		world.add_child(temporary)
		var sources := []
		var stripped := []
		if part == "pads":
			setup["pad_margins"] = []
			for node in _batches(world):
				if node.multimesh.mesh == VP.lily_pad():
					node.extra_cull_margin = VP.LILY_SWELL_BOUND if candidate else 0.0
					setup.pad_margins.append(node.extra_cull_margin)
			if setup.pad_margins.is_empty():
				_fail("pad fixture has no freshwater pads")
		_occluders = []
		_ranged = []
		var affected := {}
		for key in VA._meshes:
			var path: String = VA.Manifest.ASSETS.get(key, "")
			if path == "":
				continue
			var source: Mesh = load(path)
			var bb := source.get_aabb()
			if Vector3(bb.get_center().x, bb.position.y, bb.get_center().z).length() >= 0.01:
				affected[VA._meshes[key]] = true
		setup["affected_meshes"] = affected.size()
		if part == "lod" and not candidate:
			var copies := {}
			for node in _batches(world):
				var mesh: Mesh = node.multimesh.mesh
				if not mesh is ArrayMesh or not affected.has(mesh):
					continue
				if not copies.has(mesh):
					var copy := ArrayMesh.new()
					for s in mesh.get_surface_count():
						copy.add_surface_from_arrays(mesh.surface_get_primitive_type(s), mesh.surface_get_arrays(s))
						copy.surface_set_material(s, mesh.surface_get_material(s))
					copies[mesh] = copy
				stripped.append({"node": node, "original": node.multimesh})
				var source: MultiMesh = node.multimesh
				var replacement := MultiMesh.new()
				replacement.transform_format = source.transform_format
				replacement.use_colors = source.use_colors
				replacement.use_custom_data = source.use_custom_data
				replacement.instance_count = source.instance_count
				for i in source.instance_count:
					replacement.set_instance_transform(i, source.get_instance_transform(i))
					if source.use_colors:
						replacement.set_instance_color(i, source.get_instance_color(i))
					if source.use_custom_data:
						replacement.set_instance_custom_data(i, source.get_instance_custom_data(i))
				replacement.visible_instance_count = source.visible_instance_count
				node.multimesh = replacement
				node.multimesh.mesh = copies[mesh]
		await _main.get_tree().process_frame
		await _main.get_tree().process_frame
		setup["effective_bounds"] = _bounds(world)
		if part.begins_with("chunks") and candidate:
			var began := Time.get_ticks_usec()
			sources = _rechunk(world, temporary, 4 if part == "chunks4" else 16)
			setup["rebuild_ms"] = (Time.get_ticks_usec() - began) / 1000.0
			setup["candidate_batches"] = temporary.get_child_count()
			await _main.get_tree().process_frame
			await _main.get_tree().process_frame
			setup["candidate_bounds"] = _bounds(world, temporary.get_children())
		if part == "occlusion":
			_occluders = _make_occluders(world)
			setup["occluders"] = _occluders.size()
			setup["occluder_triangles"] = 0
			for item in _occluders:
				setup.occluder_triangles += item.node.occluder.indices.size() / 3
			_main.view.use_occlusion_culling = candidate
			setup["viewport_occlusion"] = _main.view.use_occlusion_culling
			for node in world.player.find_children("*", "GeometryInstance3D", true, false):
				node.ignore_occlusion_culling = true
		if part == "distance":
			var eligible := []
			for key in VA._meshes:
				if String(key).begins_with("grass_leaf_"):
					eligible.append(VA._meshes[key])
			for i in 5:
				eligible.append(VP.flowers(i))
			for node in _batches(world):
				if node.multimesh.mesh in eligible and node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
					_ranged.append({"node": node, "shown": true})
			setup["range_batches"] = _ranged.size()
			setup["range_end"] = 24.0
			setup["hysteresis"] = 2.0
		var path := [world.player_pos]
		var goal: Vector2i = world.map.spawns[entry.goal] if entry.goal is String else entry.goal
		if part == "pads":
			path.append(pad_start)
		else:
			path.append_array(_path(world, world.player_pos, goal))
		if path.size() < 2:
			_fail("scenery route has no traversable path: " + entry.id)
		var frames := 3 if _opts.get("verify", "0") == "1" else 240
		var positions := []
		for i in frames:
			var progress := float(i) / maxi(1, frames - 1) * (path.size() - 1)
			var index := mini(floori(progress), path.size() - 2)
			positions.append(world._along(world.tile_pos(path[index]), world.tile_pos(path[index + 1]), progress - index))
		var cursor := [0]
		var advance := func():
			world.player.position = positions[cursor[0]]
			world.player_pos = Vector2i(floori(world.player.position.x), floori(world.player.position.z))
			world._process(DT)
			_update_experiment(world, candidate)
			cursor[0] += 1
		var label: String = "%s_%s_%d" % [entry.id, part, _passes.size()]
		await _main._wait(0.1)
		var result := await _measure(label, world, world.cam, positions, advance)
		# Diagnostic captures are outside every measured interval.
		if part == "occlusion" and candidate and _opts.get("debug_views", "0") == "1" and RenderingServer.get_current_rendering_method() != "gl_compatibility":
			_main.view.debug_draw = Viewport.DEBUG_DRAW_OCCLUDERS
			await _main.get_tree().process_frame
			await _main.get_tree().process_frame
			await _capture(label + "_occluders_debug")
			_main.view.debug_draw = Viewport.DEBUG_DRAW_DISABLED
		if part == "pads" and _opts.get("verify", "0") != "1":
			await _capture_pad_bounds(world, label)
		result["experiment"] = setup
		result["tiles"] = path.map(func(p): return [p.x, p.y])
		_segments[(part + "_" if _opts.get("part", "") == "suite" else "") + entry.id] = result
		_main.view.use_occlusion_culling = false
		for item in stripped:
			item.node.multimesh = item.original
		for node in sources:
			node.show()
		if part == "pads":
			for node in _batches(world):
				if node.multimesh.mesh == VP.lily_pad():
					node.extra_cull_margin = VP.LILY_SWELL_BOUND
		for item in _ranged:
			item.node.show()
		for item in _occluders:
			if is_instance_valid(item.node):
				item.node.free()
		_occluders = []
		_ranged = []
		temporary.free()


func _batches(world) -> Array:
	# World scenery's own immutable batches only. No buildings, actors or animated effect nodes.
	return world._scenery_root.get_children().filter(func(n): return n is MultiMeshInstance3D and n.multimesh != null)


func _bounds(world, nodes: Array = []) -> Dictionary:
	var result := {"batches": 0, "instances": 0, "underbound": [], "oversized": [], "mesh_lods": 0, "shader_underbound": []}
	result["renderer_bounds_available"] = DisplayServer.get_name() != "headless"
	for node in (_batches(world) if nodes.is_empty() else nodes):
		var mm: MultiMesh = node.multimesh
		var expected := AABB()
		for i in mm.instance_count:
			var bounds: AABB = mm.get_instance_transform(i) * mm.mesh.get_aabb()
			expected = bounds if i == 0 else expected.merge(bounds)
		var actual: AABB = node.get_aabb()
		result.batches += 1
		result.instances += mm.instance_count
		if mm.mesh == VP.lily_pad() and node.extra_cull_margin < (1.0 + 0.45) * 0.045:
			result.shader_underbound.append(String(world.get_path_to(node)))
		if result.renderer_bounds_available and not actual.grow(0.002).encloses(expected):
			result.underbound.append(String(world.get_path_to(node)))
		if result.renderer_bounds_available and (actual.size.x > expected.size.x * 1.1 + 0.01 or actual.size.y > expected.size.y * 1.1 + 0.01 or actual.size.z > expected.size.z * 1.1 + 0.01):
			result.oversized.append(String(world.get_path_to(node)))
		if mm.mesh is ArrayMesh:
			for s in mm.mesh.get_surface_count():
				if not RenderingServer.mesh_get_surface(mm.mesh.get_rid(), s).get("lods", []).is_empty():
					result.mesh_lods += 1
	if not result.underbound.is_empty():
		_fail("scenery bounds omit instance geometry")
	return result


func _pad_bank(world) -> Vector2i:
	var point := Vector3.ZERO
	for node in _batches(world):
		if node.multimesh.mesh == VP.lily_pad():
			point = node.global_transform * node.multimesh.get_instance_transform(0).origin
			break
	var queue := [world.player_pos]
	var seen := {world.player_pos: true}
	var cursor := 0
	var best: Vector2i = world.player_pos
	while cursor < queue.size():
		var tile: Vector2i = queue[cursor]
		cursor += 1
		if world.tile_pos(tile).distance_squared_to(point) < world.tile_pos(best).distance_squared_to(point):
			best = tile
		for direction in DIRECTIONS:
			var next: Vector2i = tile + direction
			if not seen.has(next) and world._can_step(tile, next) and not world.doors.has(next) and not world.map.exits.has(next):
				seen[next] = true
				queue.append(next)
	return best


func _capture_pad_bounds(world, label: String) -> void:
	var overlay := Node3D.new()
	world.add_child(overlay)
	for node in _batches(world):
		if node.multimesh.mesh != VP.lily_pad():
			continue
		for margin in [0.0, VP.LILY_SWELL_BOUND]:
			var bounds: AABB = node.global_transform * node.get_aabb().grow(margin)
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.no_depth_test = true
			material.albedo_color = Color("#ffe060") if margin == 0.0 else Color.WHITE
			var lines := ImmediateMesh.new()
			lines.surface_begin(Mesh.PRIMITIVE_LINES, material)
			for corner in 8:
				for axis in 3:
					if corner & (1 << axis) == 0:
						lines.surface_add_vertex(bounds.get_endpoint(corner))
						lines.surface_add_vertex(bounds.get_endpoint(corner | (1 << axis)))
			lines.surface_end()
			var wire := MeshInstance3D.new()
			wire.mesh = lines
			wire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			overlay.add_child(wire)
	await _capture(label + "_bounds_yellow_static_white_swell")
	overlay.free()


func _rechunk(world, target: Node3D, size: int) -> Array:
	var groups := {}
	var sources := []
	for node in _batches(world):
		var mm: MultiMesh = node.multimesh
		if mm.use_colors or mm.use_custom_data or node.material_overlay != null or not node.visible:
			continue
		sources.append(node)
		for i in mm.instance_count:
			var xf: Transform3D = node.transform * mm.get_instance_transform(i)
			var cell := Vector2i(floori(xf.origin.x / size), floori(xf.origin.z / size))
			var key := [mm.mesh, node.material_override, node.cast_shadow, node.layers, node.lod_bias, node.extra_cull_margin, cell]
			if not groups.has(key):
				groups[key] = {"source": node, "transforms": []}
			groups[key].transforms.append(xf)
	for group in groups.values():
		var source: MultiMeshInstance3D = group.source
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = source.multimesh.mesh
		mm.instance_count = group.transforms.size()
		for i in mm.instance_count:
			mm.set_instance_transform(i, group.transforms[i])
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.material_override = source.material_override
		node.cast_shadow = source.cast_shadow
		node.layers = source.layers
		node.lod_bias = source.lod_bias
		node.extra_cull_margin = source.extra_cull_margin
		target.add_child(node)
	for node in sources:
		node.hide()
	return sources


func _make_occluders(world) -> Array:
	var result := []
	for fade in world.building_fades:
		if not is_instance_valid(fade.node):
			continue
		var points := PackedVector3Array()
		var indices := PackedInt32Array()
		for node in fade.meshes:
			if not node is MeshInstance3D or node.mesh == null or node.skin != null:
				continue
			for s in node.mesh.get_surface_count():
				var mat: Material = node.get_active_material(s)
				if not mat is BaseMaterial3D or mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or mat.albedo_color.a < 1.0:
					continue
				if node.mesh is ArrayMesh and node.mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
					continue
				var arrays: Array = node.mesh.surface_get_arrays(s)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var ids: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(vertices.size()))
				var xf: Transform3D = fade.node.global_transform.affine_inverse() * node.global_transform
				for i in range(0, ids.size(), 3):
					var a: Vector3 = xf * vertices[ids[i]]
					var b: Vector3 = xf * vertices[ids[i + 1]]
					var c: Vector3 = xf * vertices[ids[i + 2]]
					if (b - a).cross(c - a).length() < 2.0:
						continue
					# Only inset real opaque faces; never fill a hollow/open building AABB.
					var center := (a + b + c) / 3.0
					for p in [a, b, c]:
						indices.append(points.size())
						points.append(center + (p - center) * 0.98)
		if not points.is_empty():
			var shape := ArrayOccluder3D.new()
			shape.set_arrays(points, indices)
			var node := OccluderInstance3D.new()
			node.occluder = shape
			fade.node.add_child(node)
			result.append({"node": node, "fade": fade})
	return result


func _update_experiment(world, candidate: bool) -> void:
	for item in _occluders:
		var fade: Dictionary = item.fade
		# Building-cache eviction frees the parent and its occluder together.
		if is_instance_valid(item.node):
			item.node.visible = candidate and is_instance_valid(fade.node) and fade.node.is_visible_in_tree() and fade.opacity >= 1.0
	for item in _ranged:
		if not candidate:
			continue
		var node: MultiMeshInstance3D = item.node
		# Test full bounds rather than the chunk center; never remove a near instance.
		var bounds: AABB = node.global_transform * node.get_aabb()
		var p: Vector3 = world.cam.global_position
		var nearest := p.clamp(bounds.position, bounds.end)
		var distance := p.distance_to(nearest)
		if item.shown and distance > 26.0:
			item.shown = false
		elif not item.shown and distance < 22.0:
			item.shown = true
		node.visible = item.shown

