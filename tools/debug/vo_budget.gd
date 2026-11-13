extends "res://tools/debug/vo_perf.gd"
## Settled source-complexity guard; rendered measurements remain separate from headless limits.
const Inventory = preload("res://tools/debug/budget_inventory.gd")
const TerrainBefore = preload("res://tools/experiments/011/terrain_before.gdshader")
const TerrainLookup = preload("res://tools/experiments/011/terrain_lookup.gdshader")
const LIMITS := "res://docs/visual_overhaul/ledger/budgets.json"
const METRICS := ["geometry_nodes", "surface_submissions", "source_triangles", "distinct_materials",
	"transparent_surfaces", "texture_rgba8_mip_bytes"]
var _source := Inventory.new()
var _base_lod := 1.0
var _terrain_shader: Shader = preload("res://scripts/gfx/terrain.gdshader")
var _terrain_optimized := ""
var _noise_lookup: Texture2D
var _vertex_active := false
var _vertex_materials := {}
var _vertex_shaders := {}


func run(main, opts: Dictionary) -> void:
	_terrain_optimized = _terrain_shader.code
	if opts.get("diag_glow", "1") == "0":
		for child in main.get_children():
			if child.has_method("set_diag_glow"):
				child.set_diag_glow(false)
	if opts.has("diag_msaa"):
		for child in main.get_children():
			if child.has_method("set_diag_msaa"):
				child.set_diag_msaa(int(opts.diag_msaa))
	var options := opts.duplicate()
	options["passes"] = "6" if opts.get("trial", "") == "suite" else ("3" if opts.get("trial", "") in ["terrain", "noise", "lighting"] else "1")
	options["duration"] = "0"
	options["verify"] = "1"
	options["benchmark_kind"] = "budget-011"
	options["position_sampling"] = "settled start/midpoint/end positions of standard cardinal routes; source AABBs, base LOD and full batch/particle capacity"
	if opts.get("await_focus", "0") == "1":
		main.get_window().title = "Ruby Cocoon - 011 " + String(opts.get("report", "")).get_base_dir().get_file()
	main.get_window().grab_focus()
	await main.get_tree().process_frame
	_base_lod = main.view.mesh_lod_threshold
	await super.run(main, options)
	if opts.get("trial", "") in ["terrain", "noise"]:
		_terrain_shader.code = _terrain_optimized
	var profile := "touch20x9" if Prefs.is_mobile() else "desktop16x9"
	var failures := []
	if opts.get("record", "0") != "1":
		if not FileAccess.file_exists(LIMITS):
			failures.append("missing budget limits; record/review explicitly, never auto-update limits in tests")
		else:
			var limits = JSON.parse_string(FileAccess.get_file_as_string(LIMITS))
			if not limits is Dictionary or limits.get("schema", 0) != 1 or not limits.get("profiles", {}).has(profile):
				failures.append("invalid/missing profile in budgets.json")
			else:
				var expected: Dictionary = limits.profiles[profile]
				if _segments.size() != expected.size():
					failures.append("scene set differs from reviewed budget")
				for label in _segments:
					if not expected.has(label):
						failures.append("unbudgeted scene " + label)
						continue
					for sample in _segments[label].samples:
						for metric in METRICS:
							if not expected[label].has(metric) or sample.source[metric] > expected[label][metric]:
								failures.append("%s %s %s > %s" % [label, metric, sample.source[metric], expected[label].get(metric, "missing")])
	for failure in failures:
		_fail(failure)
	_write_report()
	print("VO BUDGET DONE: %d problem(s); profile=%s; record=%s" % [bad, profile, opts.get("record", "0")])


func _route() -> void:
	if _opts.get("trial", "") == "lighting":
		_vertex_active = _passes.size() == 1
		await _arrive("route1", "west")
		await _field("coastal_path", [_main.world.map.spawns.east])
		_segments.coastal_path["experiment"] = {"trial": "vertex" if _vertex_active else "pixel", "materials": _vertex_materials.size(), "shaders": _vertex_shaders.size()}
		for state in _vertex_materials.values():
			state.material.shading_mode = state.mode
		for state in _vertex_shaders.values():
			var shader: Shader = state.shader
			shader.code = state.code
		_vertex_materials.clear()
		_vertex_shaders.clear()
		_vertex_active = false
		return
	if _opts.get("trial", "") == "noise":
		if _terrain_shader.code != TerrainLookup.code:
			_terrain_shader.code = TerrainLookup.code
		if _noise_lookup == null:
			var image := Image.create(256, 256, false, Image.FORMAT_R8)
			var rng := RandomNumberGenerator.new()
			rng.seed = 12026
			for y in 256:
				for x in 256:
					image.set_pixel(x, y, Color(rng.randf(), 0, 0))
			_noise_lookup = ImageTexture.create_from_image(image)
		await _arrive("route1", "west")
		var changed := {}
		var fast: bool = _passes.size() == 1
		for node in _main.world.find_children("*", "MeshInstance3D", true, false):
			for surface in node.mesh.get_surface_count() if node.mesh != null else 0:
				var material: Material = node.get_active_material(surface)
				if material is ShaderMaterial and material.shader == _terrain_shader and not changed.has(material.get_instance_id()):
					material.set_shader_parameter("noise_lookup", _noise_lookup)
					material.set_shader_parameter("fast_noise", fast)
					changed[material.get_instance_id()] = material
		if changed.is_empty():
			_fail("noise trial did not bind terrain materials")
		await _field("coastal_path", [_main.world.map.spawns.east])
		_segments.coastal_path["experiment"] = {"trial": "lookup" if fast else "analytic", "materials": changed.size(), "lookup_size": 256, "lookup_seed": 12026}
		for material in changed.values():
			material.set_shader_parameter("fast_noise", false)
		return
	if _opts.get("trial", "") == "terrain":
		var optimized: bool = _passes.size() == 1
		_terrain_shader.code = _terrain_optimized if optimized else TerrainBefore.code
		await _arrive("route1", "west")
		await _field("coastal_path", [_main.world.map.spawns.east])
		_segments.coastal_path["experiment"] = {"trial": "optimized" if optimized else "original", "shader_sha256": _terrain_shader.code.sha256_text()}
		return
	if _opts.get("trial", "") == "suite":
		var trial: String = ["none", "scenery_off", "terrain_off", "unshaded", "lod4", "none"][_passes.size()]
		_main.view.debug_draw = Viewport.DEBUG_DRAW_UNSHADED if trial == "unshaded" else Viewport.DEBUG_DRAW_DISABLED
		_main.view.mesh_lod_threshold = 4.0 if trial == "lod4" else _base_lod
		await _arrive("route1", "west")
		var hidden := 0
		var restore := []
		var visible_foliage := 0
		for node in _main.world.find_children("*", "GeometryInstance3D", true, false):
			var mesh: Mesh = node.mesh if node is MeshInstance3D else (node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh != null else null)
			if mesh == null:
				continue
			var foliage := false
			var terrain := false
			for surface in mesh.get_surface_count():
				var material: Material = node.material_override if node.material_override != null else (node.get_active_material(surface) if node is MeshInstance3D else mesh.surface_get_material(surface))
				if material is ShaderMaterial and material.shader != null:
					foliage = foliage or material.resource_name == "foliage" or material.shader.resource_path.ends_with("foliage.gdshader")
					terrain = terrain or material.shader.resource_path.ends_with("terrain.gdshader")
			if foliage and node.visible:
				visible_foliage += 1
			if (trial == "scenery_off" and foliage) or (trial == "terrain_off" and terrain):
				restore.append({"node": node, "visible": node.visible})
				node.hide()
				hidden += 1
		if trial in ["scenery_off", "terrain_off"] and hidden == 0:
			_fail("GPU attribution did not find expected " + trial + " materials")
		await _field("coastal_path", [_main.world.map.spawns.east])
		_segments.coastal_path["experiment"] = {"trial": trial, "hidden_nodes": hidden, "visible_foliage_before_mask": visible_foliage,
			"mesh_lod_threshold": _main.view.mesh_lod_threshold, "debug_draw": _main.view.debug_draw}
		for item in restore:
			if is_instance_valid(item.node):
				item.node.visible = item.visible
		_main.view.debug_draw = Viewport.DEBUG_DRAW_DISABLED
		_main.view.mesh_lod_threshold = _base_lod
		if _passes.size() > 0 and visible_foliage != _passes[0].segments.coastal_path.experiment.visible_foliage_before_mask:
			_fail("cached foliage visibility changed between trial passes")
		return
	if _opts.get("part", "") == "coastal":
		await _arrive("route1", "west")
		await _field("coastal_path", [_main.world.map.spawns.east])
		return
	await super._route()
	await _battle()


func _field(label: String, goals: Array) -> void:
	var world = _main.world
	var tiles := _field_tiles(world, goals)
	var positions := []
	for i in range(1, tiles.size()):
		for f in range(1, TILE_FRAMES + 1):
			positions.append(world._along(world.tile_pos(tiles[i - 1]), world.tile_pos(tiles[i]), float(f) / TILE_FRAMES))
	if positions.is_empty():
		positions.append(world.player.position)
	var samples := []
	for index in [0, positions.size() / 2, positions.size() - 1]:
		world.player.position = positions[index]
		world.player_pos = Vector2i(floori(world.player.position.x), floori(world.player.position.z))
		for i in 90:
			world._process(DT)
		await _main.get_tree().process_frame
		await _main.get_tree().process_frame
		if not world.visible_buildings_ready():
			_fail("building construction did not settle: " + label)
		samples.append(await _sample(label + "_" + str(index), world, world.cam))
	_segments[label] = {"tiles": tiles.map(func(t): return [t.x, t.y]), "samples": samples}


func _battle() -> void:
	_main.view.remove_child(_main.world)
	var battle = load("res://tools/debug/battle_stage_fixture.gd").new()
	battle.setup({"wild": false, "map": "route1", "seed": ROUTE_SEED,
		"foes": [Beasts.create(12, 20), Beasts.create(15, 20)], "trainer": {"name": "Tess", "cls": "Tester"}})
	_main.view.add_child(battle)
	await _main._wait(0.1)
	battle.set_process(false)
	_segments["coast_battle"] = {"samples": [await _sample("coast_battle", battle, battle.cam)]}
	battle.hud.queue_free()
	_main.view.remove_child(battle)
	battle.queue_free()
	_main.view.add_child(_main.world)
	_main.world.cam.make_current()


func _sample(label: String, root: Node3D, camera: Camera3D) -> Dictionary:
	if _vertex_active:
		_apply_vertex_trial(root)
	var source: Dictionary = _source.collect(root, camera)
	if not source.unsupported_textures.is_empty():
		_fail("unsupported texture classes: " + str(source.unsupported_textures))
	var result := {"source": source, "rendered": {}, "effective_msaa": _main.view.msaa_3d}
	if DisplayServer.get_name() != "headless":
		var frames := []
		for i in 120:
			frames.append(root.player.position if root == _main.world else Vector3.ZERO)
		result.rendered = await super._measure(label, root, camera, frames)
		var key := "RENDERING_INFO_TEXTURE_MEM_USED"
		result["texture_memory_bytes"] = RenderingServer.get_rendering_info(ClassDB.class_get_integer_constant("RenderingServer", key)) if ClassDB.class_has_integer_constant("RenderingServer", key) else 0
	return result


func _apply_vertex_trial(root: Node3D) -> void:
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		var mesh: Mesh = node.mesh if node is MeshInstance3D else (node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh != null else null)
		if mesh == null:
			continue
		for surface in mesh.get_surface_count():
			var material: Material = node.material_override if node.material_override != null else (node.get_active_material(surface) if node is MeshInstance3D else mesh.surface_get_material(surface))
			if material is BaseMaterial3D and material.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL:
				_vertex_materials[material.get_instance_id()] = {"material": material, "mode": material.shading_mode}
				material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
			elif material is ShaderMaterial and material.shader != null:
				var shader: Shader = material.shader
				var eligible: bool = material.resource_name == "foliage" or shader == _terrain_shader
				if eligible and not _vertex_shaders.has(shader.get_instance_id()) and not "vertex_lighting" in shader.code:
					_vertex_shaders[shader.get_instance_id()] = {"shader": shader, "code": shader.code}
					shader.code = shader.code.replace("render_mode ", "render_mode vertex_lighting, ") if "render_mode " in shader.code else shader.code.replace("shader_type spatial;", "shader_type spatial;\nrender_mode vertex_lighting;")
