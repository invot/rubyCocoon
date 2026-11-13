extends "res://tools/debug/vo_perf.gd"
## Settled source-complexity guard; rendered measurements remain separate from headless limits.
const Inventory = preload("res://tools/debug/budget_inventory.gd")
const LIMITS := "res://docs/visual_overhaul/ledger/budgets.json"
const METRICS := ["geometry_nodes", "surface_submissions", "source_triangles", "distinct_materials",
	"transparent_surfaces", "texture_rgba8_mip_bytes"]
var _source := Inventory.new()
var _base_lod := 1.0


func run(main, opts: Dictionary) -> void:
	var options := opts.duplicate()
	options["passes"] = "5" if opts.get("trial", "") == "suite" else "1"
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
	if _opts.get("trial", "") == "suite":
		var trial: String = ["none", "scenery_off", "unshaded", "lod4", "none"][_passes.size()]
		_main.view.debug_draw = Viewport.DEBUG_DRAW_UNSHADED if trial == "unshaded" else Viewport.DEBUG_DRAW_DISABLED
		_main.view.mesh_lod_threshold = 4.0 if trial == "lod4" else _base_lod
		await _arrive("route1", "west")
		var hidden := 0
		if trial == "scenery_off":
			for node in _main.world.find_children("*", "MultiMeshInstance3D", true, false):
				var foliage := false
				for surface in node.multimesh.mesh.get_surface_count():
					var material: Material = node.material_override if node.material_override != null else node.multimesh.mesh.surface_get_material(surface)
					if material is ShaderMaterial and material.shader != null and (material.resource_name == "foliage" or material.shader.resource_path.ends_with("foliage.gdshader")):
						foliage = true
				if foliage:
					node.hide()
					hidden += 1
			if hidden == 0:
				_fail("foliage attribution did not find the expected batch materials")
		await _field("coastal_path", [_main.world.map.spawns.east])
		_segments.coastal_path["experiment"] = {"trial": trial, "hidden_foliage_batches": hidden,
			"mesh_lod_threshold": _main.view.mesh_lod_threshold, "debug_draw": _main.view.debug_draw}
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
	var source: Dictionary = _source.collect(root, camera)
	if not source.unsupported_textures.is_empty():
		_fail("unsupported texture classes: " + str(source.unsupported_textures))
	var result := {"source": source, "rendered": {}}
	if DisplayServer.get_name() != "headless":
		var frames := []
		for i in 120:
			frames.append(root.player.position if root == _main.world else Vector3.ZERO)
		result.rendered = await super._measure(label, root, camera, frames)
		var key := "RENDERING_INFO_TEXTURE_MEM_USED"
		result["texture_memory_bytes"] = RenderingServer.get_rendering_info(ClassDB.class_get_integer_constant("RenderingServer", key)) if ClassDB.class_has_integer_constant("RenderingServer", key) else 0
	return result
