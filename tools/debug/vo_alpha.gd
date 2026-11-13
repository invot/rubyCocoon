extends "res://tools/debug/vo_perf.gd"
## 007 diagnostic only. Original/candidate/original; no persistent quality changes.
const Cost = preload("res://tools/debug/vo_cost.gd")
const ZERO_PATHS := ["Beam1", "Beam2", "DeckGlow1", "DeckGlow2", "CenterBeam"]


func run(main, opts: Dictionary) -> void:
	var options := opts.duplicate()
	options["passes"] = "1" if opts.get("inventory", "0") == "1" else "3"
	options["duration"] = "0"
	options["benchmark_kind"] = "alpha-007"
	options["position_sampling"] = "standard 002 route, 14 frames/tile; merge film fixed 1/60 simulation"
	if opts.get("await_focus", "0") == "1":
		main.get_window().title = "Ruby Cocoon - 007 " + String(opts.get("report", "")).get_base_dir().get_file()
	main.get_window().grab_focus()
	await main.get_tree().process_frame
	await super.run(main, options)


func _route() -> void:
	if _opts.get("inventory", "0") == "1":
		await _arrive("route1", "west")
		var world = _main.world
		var path := [world.player_pos]
		path.append_array(_path(world, world.player_pos, world.map.spawns.east))
		world.player_pos = path[path.size() / 2]
		world.player.position = world.tile_pos(world.player_pos)
		for i in 90:
			world._process(DT)
		await _main.get_tree().process_frame
		_segments["coastal_midpoint_inventory"] = {"inventory": _inventory(world, world.cam, 0)}
		await _capture("coastal_midpoint_inventory")
		return
	var part: String = _opts.get("part", "suite")
	if part == "aa":
		# A separate moving-foliage route plus the film; never combine AA with zero-alpha culling.
		await _arrive("route1", "west")
		await _field("coastal_path", [_main.world.map["spawns"]["east"]])
	elif part in ["field", "suite"]:
		await super._route()
	if part in ["film", "suite", "aa"]:
		await _merge_film()


func _measure(label: String, subject: Node3D, camera: Camera3D, positions: Array, advance := Callable(), measured_view: SubViewport = null, captures := {}) -> Dictionary:
	var view: SubViewport = _main.view if measured_view == null else measured_view
	var msaa: int = view.msaa_3d
	var screen_aa: int = view.screen_space_aa
	var fxaa: bool = _opts.get("part", "") == "aa" and _passes.size() == 1
	if fxaa:
		view.msaa_3d = Viewport.MSAA_DISABLED
		view.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	await _main.get_tree().process_frame
	var result: Dictionary = await super._measure(label, subject, camera, positions, advance, measured_view, captures)
	result["alpha_experiment"] = {"candidate": _passes.size() == 1, "part": _opts.get("part", "suite"),
		"msaa": view.msaa_3d, "screen_aa": view.screen_space_aa}
	view.msaa_3d = msaa
	view.screen_space_aa = screen_aa
	return result


func _inventory(root: Node3D, camera: Camera3D, frame: int) -> Dictionary:
	var result: Dictionary = super._inventory(root, camera, frame)
	result["material_inventory"] = Cost.inventory(root, camera)
	var transparent := []
	var ripple_nodes := {}
	if root == _main.world:
		for ripple in root.ripples:
			for node in ripple[0]:
				ripple_nodes[node.get_instance_id()] = true
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		if not Cost._in_view(node, camera):
			continue
		var mesh: Mesh = null
		if node is MeshInstance3D or node is CPUParticles3D:
			mesh = node.mesh
		elif node is MultiMeshInstance3D and node.multimesh != null:
			mesh = node.multimesh.mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var mat: Material = node.material_override
			if mat == null:
				mat = node.get_active_material(s) if node is MeshInstance3D else mesh.surface_get_material(s)
			var mode := "opaque"
			var source := ""
			var zero := false
			if mat is BaseMaterial3D:
				mode = ["opaque", "blend", "scissor", "hash", "depth_prepass"][mat.transparency]
				zero = mat.albedo_color.a == 0.0
			elif mat is ShaderMaterial and mat.shader != null:
				source = mat.shader.resource_path
				# Include compound assignments used by water/fade composition. Source estimate only.
				mode = "custom_alpha" if "ALPHA" in mat.shader.code else "custom_no_alpha"
				if "ALPHA_SCISSOR_THRESHOLD" in mat.shader.code or "ALPHA_HASH_SCALE" in mat.shader.code:
					mode = "custom_cutout"
				if source.ends_with("hatchery_beam.gdshader"):
					# Unset parameters return null headless; this shader's authored default is 0.
					var power = mat.get_shader_parameter("power")
					zero = power == null or power == 0.0
			if mode in ["blend", "depth_prepass", "custom_alpha"]:
				var entry := {"path": String(root.get_path_to(node)), "surface": s, "mode": mode,
					"shader": source, "zero_alpha": zero, "type": node.get_class(), "mesh_type": mesh.get_class(),
					"category": "fishing_ripple" if ripple_nodes.has(node.get_instance_id()) else "other"}
				if node is CPUParticles3D:
					entry["amount"] = node.amount
					entry["emitting"] = node.emitting
					entry["lifetime"] = node.lifetime
				transparent.append(entry)
	result["transparent_sources"] = transparent
	result["source_inventory_scope"] = "visible frustum-AABB material estimate, including occluded/zero-alpha sources; not renderer transparent draw counts or pixel overdraw"
	return result


func _merge_film() -> void:
	var a := Beasts.create(0, 40)
	var b := Beasts.create(30, 40)
	var child := Beasts.merge(a, b, true)
	var film = load("res://scenes/MergeCinematic.tscn").instantiate().setup(a.growth_look(), b.growth_look(), child.growth_look())
	var update_mode: int = _main.view.render_target_update_mode
	_main.view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	UI.auto = false
	UI.push(film)
	film.set_process(false)
	var players: Array[Node] = film.find_children("*", "AnimationPlayer", true, false)
	for player: AnimationPlayer in players:
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var particles: Array[Node] = film.find_children("*", "CPUParticles3D", true, false)
	for i in particles.size():
		var emitter: CPUParticles3D = particles[i]
		emitter.use_fixed_seed = true
		emitter.seed = ROUTE_SEED + i
		emitter.speed_scale = 0.0
		emitter.restart(true)
	await _main.get_tree().process_frame
	await _main.get_tree().process_frame
	var candidate: bool = _passes.size() == 1 and _opts.get("part", "") != "aa"
	var verify: bool = _opts.get("verify", "0") == "1"
	var step_dt: float = 9.5 / 24.0 if verify else DT
	var advance := func():
		film._process(step_dt)
		for player: AnimationPlayer in players:
			player.advance(step_dt)
		for emitter: CPUParticles3D in particles:
			emitter.request_particles_process(step_dt if emitter.emitting else 0.0, 0.0 if emitter.emitting else step_dt)
		# Only exactly transparent authored beams/halos. No particle/parent fade changes.
		for path in ZERO_PATHS:
			var node: MeshInstance3D = film._stage.get_node(path)
			var material: Material = node.material_override
			var zero: bool = float(material.get_shader_parameter("power")) == 0.0 if material is ShaderMaterial else material.albedo_color.a == 0.0
			node.visible = not (candidate and zero)
	var steps := []
	for i in (24 if verify else 570):
		steps.append(Vector3.ZERO)
	var captures := {120: "parents", 240: "fall", 270: "overlap", 300: "landing", 450: "child"}
	var result: Dictionary = await _measure("merge", film._stage, film._camera, steps, advance, film._view, captures)
	result["zero_alpha_candidate"] = candidate
	result["film_elapsed"] = film.elapsed
	result["particle_playback"] = "fixed seed, speed_scale=0, requested DT per simulation step; capture waits do not advance particles"
	result["zero_paths"] = ZERO_PATHS
	_segments["merge"] = result
	film.close()
	await _main.get_tree().process_frame
	_main.view.render_target_update_mode = update_mode
	UI.auto = true
