extends RefCounted
## Repeatable visual-overhaul baseline. Scripted cardinal traversal, not an input/AI test.
## Fixed simulation steps and frames per tile keep the same views on every renderer.
const Beasts = preload("res://scripts/core/beasts.gd")
const MapLoader = preload("res://scripts/world/map_loader.gd")
const Person = preload("res://scripts/gfx/voxel_person.gd")
const ROUTE_SEED := 12026
const DT := 1.0 / 60.0
const TILE_FRAMES := 14
const DIRECTIONS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
var bad := 0
var _main
var _opts: Dictionary
var _trace := {}
var _transitions := []
var _segments := {}
var _passes := []
var _focus_losses := []
var _previous_keep_on := false
var _title_ready_wait_ms := 0.0
var _precompile := {}
var _shadow_state := true


func run(main, opts: Dictionary) -> void:
	_main = main
	_opts = opts
	# Refuse to run if either override is absent: startup must also use isolated preferences.
	var save_path := String(opts.get("save_dir", ""))
	var prefs_path := String(opts.get("prefs_path", ""))
	if not _isolated(save_path) or not _isolated(prefs_path):
		_fail("vo-perf requires isolated --save_dir and --prefs_path under res://build/ or user://bench/vo/")
		return
	var resolution_sweep := PackedInt32Array()
	if opts.has("resolution_sweep"):
		for height in String(opts.resolution_sweep).split(","):
			if not height.is_valid_int() or not int(height) in Prefs.RESOLUTIONS:
				_fail("invalid benchmark resolution sweep")
				return
			resolution_sweep.append(int(height))
	# Step 008: one pass per entry with every light's shadows on or off, everything else unchanged.
	var shadow_sweep := []
	if opts.has("shadow_sweep"):
		for state in String(opts.shadow_sweep).split(","):
			if not state in ["on", "off"]:
				_fail("invalid benchmark shadow sweep")
				return
			shadow_sweep.append(state == "on")
	var quality_node: Node = null
	for child in Prefs.get_children():
		if child.has_method("set_diag_shadows"):
			quality_node = child
	if not shadow_sweep.is_empty() and (quality_node == null or not resolution_sweep.is_empty()):
		_fail("shadow sweep needs the render-quality node and no resolution sweep")
		return
	var kept_on := DisplayServer.screen_is_kept_on()
	_previous_keep_on = kept_on
	DisplayServer.screen_set_keep_on(true)
	main.get_window().focus_exited.connect(_focus_lost)
	seed(ROUTE_SEED)
	Engine.time_scale = 1.0
	# Connected desktop controllers must not silently replace the requested touch workload.
	Prefs.input_mode = "screen" if Prefs.is_mobile() else "keyboard"
	Prefs.apply()
	UI.controls.set_title_mode(false)
	UI.controls.refresh()
	UI.auto = true
	if opts.get("verify", "0") == "1":
		# Exercise both deferred quality callbacks after temporary nodes have already been freed.
		for i in 8:
			for temporary in [MeshInstance3D.new(), OmniLight3D.new(), WorldEnvironment.new()]:
				main.view.add_child(temporary)
				temporary.free()
		await main.get_tree().process_frame
	for flag in ["intro_done", "tutorial_done", "ritual_done", "opening_seen", "has_starter"]:
		GameState.set_flag(flag)
	# Traverse the repaired tutorial footbridge; no progression is changed outside this fixture.
	for obstacle in MapLoader.load_map("route1", {}).get("obstacles", {}).values():
		GameState.set_flag(obstacle["flag"])
	GameState.party = [Beasts.create(0, 20), Beasts.create(3, 20), Beasts.create(30, 20)]
	GameState.beast_slots = 3
	for i in 3:
		GameState.party[i].slot = [7, 0, 1][i]
	_main.get_tree().process_frame.connect(_transition_sample)
	if opts.get("title_ready", "0") == "1":
		var title_started := Time.get_ticks_usec()
		await main._title_backdrop()
		_title_ready_wait_ms = (Time.get_ticks_usec() - title_started) / 1000.0
	if opts.get("precompile", "0") == "1":
		# step 009b: the title menu's Compatibility shader precompile, timed as the title would run it
		_precompile = await main.precompile_shaders()
		_precompile["requested"] = true
	var began := Time.get_ticks_usec()
	var duration := float(opts.get("duration", "0"))
	var requested_passes := maxi(1, int(opts.get("passes", "1")))
	if not resolution_sweep.is_empty():
		requested_passes = resolution_sweep.size()
		duration = 0.0
	if not shadow_sweep.is_empty():
		requested_passes = shadow_sweep.size()
		duration = 0.0
	while true:
		if not shadow_sweep.is_empty():
			_shadow_state = shadow_sweep[_passes.size()]
			quality_node.set_diag_shadows(_shadow_state)
		if not resolution_sweep.is_empty():
			Prefs.render_height = resolution_sweep[_passes.size()]
			Prefs.apply()
			# Let the existing viewport resize handler settle before any route/frame samples.
			await main.get_tree().process_frame
			await main.get_tree().process_frame
		_transitions = []
		_segments = {}
		await _route()
		_passes.append({"segments": _segments, "transitions": _transitions,
			"elapsed_s": (Time.get_ticks_usec() - began) / 1000000.0, "focus_losses": _focus_losses.duplicate(),
			"render_height": Prefs.render_height, "render_size": [main.view.size.x, main.view.size.y],
			"refresh_hz": DisplayServer.screen_get_refresh_rate(), "vsync": DisplayServer.window_get_vsync_mode(),
			"max_fps": Engine.max_fps, "quality": Prefs.graphics_quality,
			"shadows": quality_node == null or quality_node.diag_shadows})
		_write_report()
		print("VO PERF PASS ", _passes.size(), " elapsed_s=", (Time.get_ticks_usec() - began) / 1000000.0)
		if bad > 0 or not _focus_losses.is_empty():
			break
		if (duration <= 0.0 and _passes.size() >= requested_passes) or (duration > 0.0 and Time.get_ticks_usec() - began >= duration * 1000000.0):
			break
	if quality_node != null:
		quality_node.set_diag_shadows(true)
	_main.get_tree().process_frame.disconnect(_transition_sample)
	main.get_window().focus_exited.disconnect(_focus_lost)
	DisplayServer.screen_set_keep_on(kept_on)
	UI.auto = false
	print("VO PERF DONE: %d problem(s)" % bad)


func _isolated(path: String) -> bool:
	return (path.begins_with("res://build/") or path.begins_with("user://bench/vo/")) and not ".." in path


func _focus_lost() -> void:
	_focus_losses.append(Time.get_ticks_msec())
	_fail("benchmark lost foreground focus; this pass is not valid sustained-run evidence")
	# A minimized window may never emit the awaited draw signal. Preserve the partial failure and release resources.
	_write_report()
	DisplayServer.screen_set_keep_on(_previous_keep_on)
	_main.get_tree().quit(1)


func _route() -> void:
	await _arrive("route1", "west")
	await _field("coastal_path", [_main.world.map["spawns"]["east"]])
	await _arrive("caccoon", Vector2i(30, 22))
	var home: Dictionary = _main.world.map["buildings"].filter(func(b): return b["shop"] == "home")[0]
	await _field("cove_plaza", [Vector2i(38, 22), Vector2i(38, 27), Vector2i(30, 27), Vector2i(30, 22), home["door"] + Vector2i.DOWN])
	await _arrive(home["interior"], "entry")
	await _field("hero_house", [])
	await _arrive("tidewater", "west")
	await _field("rue_royale", [Vector2i(40, 8)])
	if _opts.get("verify", "0") != "1" and _opts.get("load_only", "0") != "1":
		await _battle()


func _write_report() -> void:
	var report := {
		"schema": 1, "route_version": 1, "seed": ROUTE_SEED,
		"benchmark": String(_opts.get("benchmark_kind", "vo-perf")),
		"position_sampling": String(_opts.get("position_sampling", "14 frames per tile on the standard route")),
		"loading_only": _opts.get("load_only", "0") == "1",
		"warmup_shared": _opts.get("warmup_shared", "0") == "1",
		"shader_cache_enabled": ProjectSettings.get_setting_with_override("rendering/shader_compiler/shader_cache/enabled"),
		"title_script_ready": _opts.get("title_ready", "0") == "1", "title_script_wait_ms": _title_ready_wait_ms,
		"title_precompile": _precompile,
		"engine": Engine.get_version_info(), "platform": OS.get_name(),
		"processor": OS.get_processor_name(), "gpu": RenderingServer.get_video_adapter_name(),
		"renderer": RenderingServer.get_current_rendering_method(), "driver": RenderingServer.get_current_rendering_driver_name(),
		"window": [_main.get_window().size.x, _main.get_window().size.y],
		"render_size": [_main.view.size.x, _main.view.size.y], "touch": Prefs.is_mobile(),
		"input_mode": Prefs.effective_input(), "touch_controls_visible": UI.controls.touch_visible(),
		"quality": Prefs.graphics_quality, "render_height": Prefs.render_height,
		"vsync": DisplayServer.window_get_vsync_mode(), "max_fps": Engine.max_fps,
		"simulation_dt": DT, "frames_per_tile": TILE_FRAMES if not _opts.has("benchmark_kind") else 0,
		"notes": ["Desktop results do not establish phone performance.",
			"Field camera, animation, water, fading and visibility use the shared world tick at fixed dt; input, encounters and NPC wandering are frozen.",
			"Frame intervals include presentation pacing. CPU process and render CPU are separate, overlapping measurements, not summed.",
			"Inventory is a conservative frustum/AABB estimate at start, midpoint and end; includes occluded surfaces, excludes LOD and occlusion decisions. No inventory or screenshot work occurs inside measured intervals.",
			"Zero-valued render timing or memory counters may be unsupported by the renderer; consult metric availability."],
		"transitions": _transitions, "segments": _segments, "problems": bad,
		"passes": _passes, "focus_losses": _focus_losses,
		"screen_keep_on": DisplayServer.screen_is_kept_on(),
	}
	var path := String(_opts.get("report", "res://build/perf/vo/run.json"))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("cannot write " + path)
	else:
		var serialized := JSON.stringify(report, "\t")
		file.store_string(serialized)
		file.close()
		print("VO PERF REPORT ", path)
		if OS.has_feature("web"):
			# Debug export's same-origin collector retains the full trace outside browser storage.
			JavaScriptBridge.eval("window.voPerfReport(" + serialized + ");", true)


func _arrive(id: String, spawn) -> void:
	print("VO PERF arrival ", id)
	seed(ROUTE_SEED)
	var pipelines := {}
	if _opts.get("diagnose", "0") == "1":
		pipelines = load("res://tools/debug/vo_cost.gd").pipeline_counters()
	_trace = {"map": id, "started": Time.get_ticks_usec(), "black_start": -1, "black_end": -1}
	await _main._do_goto(id, spawn)
	_transition_sample()
	_transitions.append({"map": id, "total_ms": (Time.get_ticks_usec() - int(_trace.started)) / 1000.0,
		"black_ms": maxf(0.0, (int(_trace.black_end) - int(_trace.black_start)) / 1000.0)})
	if _opts.has("shadow_sweep"):
		_transitions.back()["lights"] = _shadow_lights(_main.world)
	if _opts.get("diagnose", "0") == "1":
		var after: Dictionary = load("res://tools/debug/vo_cost.gd").pipeline_counters()
		for key in after:
			after[key] -= pipelines.get(key, 0)
		_transitions.back()["pipeline_compilation_delta"] = after
	if _opts.get("load_phases", "0") == "1":
		_transitions.back()["loading_phases_ms"] = _main.cost_load_phases.duplicate()
		_transitions.back()["continuous_black_ms"] = _main.cost_continuous_black_ms
		_transitions.back()["warmup"] = _main.world.cost_warmup_stats.duplicate()
	_trace = {}
	_main.world.busy = true
	_main.world.frozen = true
	_main.world.set_process(false)
	for npc in _main.world.map["npcs"]:
		npc["roam"] = false
		npc["wander"] = false
	# Disable the field notice before steady-state sampling, independently of wall time.
	await _main._wait(0.03 if _opts.get("verify", "0") == "1" else 4.0)


func _transition_sample() -> void:
	if _trace.is_empty() or _trace.get("closed", false):
		return
	var now := Time.get_ticks_usec()
	if UI.fade_rect.color.a >= 0.999:
		if int(_trace.black_start) < 0:
			_trace.black_start = now
		_trace.black_end = now
	elif int(_trace.black_start) >= 0 and int(_trace.black_end) >= 0:
		# Include the final black interval, once, at the first non-black frame.
		_trace.black_end = now
		_trace["closed"] = true


func _path(world, start: Vector2i, goal: Vector2i) -> Array:
	var previous := {start: start}
	var queue := [start]
	var cursor := 0
	while cursor < queue.size():
		var p: Vector2i = queue[cursor]
		cursor += 1
		if p == goal:
			var result := []
			while p != start:
				result.push_front(p)
				p = previous[p]
			return result
		for d in DIRECTIONS:
			var q: Vector2i = p + d
			if previous.has(q) or not world._can_step(p, q) or world.map["exits"].has(q) or world.doors.has(q):
				continue
			previous[q] = p
			queue.append(q)
	_fail("no cardinal route from %s to %s on %s" % [start, goal, world.map_id])
	return []


func _field(label: String, goals: Array) -> void:
	if _opts.get("load_only", "0") == "1":
		await _capture(label + "_arrival")
		return
	var world = _main.world
	var tiles := [world.player_pos]
	for goal in goals:
		tiles.append_array(_path(world, tiles.back(), goal))
	print("VO PERF route ", label, " tiles=", tiles.size())
	if _opts.get("verify", "0") == "1":
		return
	var positions := []
	for i in range(1, tiles.size()):
		for f in range(1, TILE_FRAMES + 1):
			positions.append(world._along(world.tile_pos(tiles[i - 1]), world.tile_pos(tiles[i]), float(f) / TILE_FRAMES))
	if positions.is_empty():
		for i in 240:
			positions.append(world.player.position)
	var result := await _measure(label, world, world.cam, positions)
	result["tiles"] = tiles.map(func(t): return [t.x, t.y])
	_segments[label] = result


func _battle() -> void:
	_main.view.remove_child(_main.world)
	var battle = load("res://tools/debug/battle_stage_fixture.gd").new()
	battle.setup({"wild": false, "map": "route1", "seed": ROUTE_SEED,
		"foes": [Beasts.create(12, 20), Beasts.create(15, 20)], "trainer": {"name": "Tess", "cls": "Tester"}})
	_main.view.add_child(battle)
	await _main._wait(3.3)
	battle.set_process(false)
	var frames := []
	for i in 240:
		frames.append(Vector3.ZERO)
	_segments["coast_battle"] = await _measure("coast_battle", battle, battle.cam, frames)
	battle.hud.queue_free()
	_main.view.remove_child(battle)
	battle.queue_free()
	# Keep the field attached to its viewport for the next pass's shader/scenery retention.
	_main.view.add_child(_main.world)
	_main.world.cam.make_current()


func _measure(label: String, subject: Node3D, camera: Camera3D, positions: Array, advance := Callable(), measured_view: SubViewport = null, captures := {}) -> Dictionary:
	var vp: RID = (_main.view if measured_view == null else measured_view).get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var values := {"frame_ms": [], "process_cpu_ms": [], "tick_cpu_ms": [], "render_cpu_ms": [], "gpu_ms": [],
		"draw_calls": [], "objects": [], "primitives": [], "video_memory_bytes": []}
	var inventory := []
	var last := 0
	var is_field: bool = subject == _main.world
	for i in positions.size():
		if i == 0 or i == positions.size() / 2 or captures.has(i):
			inventory.append(_inventory(subject, camera, i))
			if i == positions.size() / 2:
				await _capture(label)
			if captures.has(i):
				await _capture(label + "_" + String(captures[i]))
			for warm in 3:
				await _main.get_tree().process_frame
			last = Time.get_ticks_usec()
		var began := Time.get_ticks_usec()
		if advance.is_valid():
			advance.call()
		elif is_field:
			var before: Vector3 = subject.player.position
			subject.player.position = positions[i]
			subject.player_pos = Vector2i(floori(positions[i].x), floori(positions[i].z))
			subject._process(DT)
			var direction: Vector3 = subject.player.position - before
			if direction.length_squared() > 0.000001:
				Person.face(subject.player, Vector2i(roundi(direction.x * TILE_FRAMES), roundi(direction.z * TILE_FRAMES)), true)
				subject.anim_t += Person.phase_for(direction.length(), 1.0 / (DT * TILE_FRAMES))
				Person.animate(subject.player, subject.anim_t, 1.0 / (DT * TILE_FRAMES))
		else:
			subject._process(DT)
		values.tick_cpu_ms.append((Time.get_ticks_usec() - began) / 1000.0)
		await _main.get_tree().process_frame
		var now := Time.get_ticks_usec()
		values.frame_ms.append((now - last) / 1000.0)
		last = now
		values.process_cpu_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		values.render_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(vp))
		values.gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
		values.draw_calls.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		values.objects.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
		values.primitives.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		values.video_memory_bytes.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED))
	RenderingServer.viewport_set_measure_render_time(vp, false)
	inventory.append(_inventory(subject, camera, positions.size()))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	await _capture(label + "_end")
	var summary := {}
	for key in values:
		summary[key] = _stats(values[key])
	var diagnosis := {}
	if _opts.get("diagnose", "0") == "1" or _opts.has("shadow_sweep"):
		var cost = load("res://tools/debug/vo_cost.gd")
		diagnosis = {"whole_tree": cost.inventory(subject), "end_view": cost.inventory(subject, camera)}
		if _opts.has("shadow_sweep"):
			diagnosis["lights"] = _shadow_lights(subject)
		if is_field and _opts.get("diagnose", "0") == "1":
			diagnosis.script_probes = cost.script_probes(subject)
		if _opts.get("eligibility", "0") == "1":
			diagnosis.material_eligibility = load("res://tools/debug/material_eligibility.gd").audit(subject)
	var worst := []
	var indices := range(positions.size())
	indices.sort_custom(func(a, b): return values.frame_ms[a] > values.frame_ms[b])
	for i in mini(5, indices.size()):
		var index: int = indices[i]
		worst.append({"frame": index, "ms": values.frame_ms[index]})
	print("VO PERF ", label, " ", JSON.stringify(summary.frame_ms))
	return {"frames": positions.size(), "summary": summary, "worst_five": worst, "trace": values, "inventory": inventory, "diagnosis": diagnosis,
		"availability": {"gpu_timing": summary.gpu_ms.max > 0.0, "render_cpu_timing": summary.render_cpu_ms.max > 0.0,
			"video_memory": summary.video_memory_bytes.max > 0.0}}


## Outside measured intervals. Record effective light flags rather than trusting the requested switch.
func _shadow_lights(subject: Node3D) -> Array:
	var lights := []
	for light in subject.find_children("*", "Light3D", true, false):
		var base: Dictionary = light.get_meta(&"render_quality_baseline", {})
		if not base.has("shadow"):
			_fail("shadow diagnostic found an unregistered light: " + String(subject.get_path_to(light)))
		elif light.shadow_enabled != (base["shadow"] and _shadow_state and Prefs.graphics_quality != "min"):
			_fail("effective shadow state disagrees with diagnostic request: " + String(subject.get_path_to(light)))
		var entry := {"path": String(subject.get_path_to(light)), "type": light.get_class(),
			"shadows": light.shadow_enabled, "visible": light.is_visible_in_tree()}
		if light is DirectionalLight3D:
			entry["distance"] = light.directional_shadow_max_distance
			entry["splits"] = light.directional_shadow_mode
		elif light is SpotLight3D:
			entry["range"] = light.spot_range
			entry["angle"] = light.spot_angle
		elif light is OmniLight3D:
			entry["range"] = light.omni_range
		lights.append(entry)
	return lights


func _capture(label: String) -> void:
	var shots := String(_opts.get("shots", ""))
	if shots != "":
		if _opts.has("duration"):
			shots += "/pass_%02d" % (_passes.size() + 1)
		DirAccess.make_dir_recursive_absolute(shots)
		await RenderingServer.frame_post_draw
		_main._save_shot(shots + "/" + label + ".png")
		if OS.has_feature("web") and _opts.get("web_images", "0") == "1" and ("riverbend" in label or "caccoon_occlusion" in label or label.begins_with("merger")):
			# Optional diagnostic bridge. Encoding/upload happens outside measured intervals.
			var bytes := FileAccess.get_file_as_bytes(shots + "/" + label + ".png")
			JavaScriptBridge.eval("window.voPerfImage(" + JSON.stringify("%02d_%s" % [_passes.size() + 1, label]) + "," + JSON.stringify(Marshalls.raw_to_base64(bytes)) + ");", true)


func _inventory(root: Node3D, camera: Camera3D, frame: int) -> Dictionary:
	var materials := {}
	var surfaces := 0
	var meshes := 0
	var planes := camera.get_frustum()
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		if not node.is_visible_in_tree() or node.layers & camera.cull_mask == 0:
			continue
		var mesh: Mesh = null
		if node is MeshInstance3D:
			mesh = node.mesh
		elif node is MultiMeshInstance3D and node.multimesh != null:
			mesh = node.multimesh.mesh
		if mesh == null:
			continue
		var bounds: AABB = node.global_transform * node.get_aabb()
		var outside := false
		for plane in planes:
			var inside := false
			for corner in 8:
				if not plane.is_point_over(bounds.get_endpoint(corner)):
					inside = true
					break
			if not inside:
				outside = true
				break
		if outside:
			continue
		meshes += 1
		for surface in mesh.get_surface_count():
			surfaces += 1
			var material: Material = node.material_override
			if material == null:
				material = node.get_active_material(surface) if node is MeshInstance3D else mesh.surface_get_material(surface)
			if material != null:
				materials[material.get_instance_id()] = true
		if node.material_overlay != null:
			materials[node.material_overlay.get_instance_id()] = true
	return {"frame": frame, "frustum_meshes": meshes, "surfaces": surfaces, "distinct_materials": materials.size()}


func _stats(values: Array) -> Dictionary:
	var sorted := values.duplicate()
	sorted.sort()
	var n := sorted.size()
	return {"median": (float(sorted[(n - 1) / 2]) + float(sorted[n / 2])) / 2.0,
		"p95": sorted[maxi(0, ceili(n * 0.95) - 1)], "p99": sorted[maxi(0, ceili(n * 0.99) - 1)], "max": sorted.back()}


func _fail(message: String) -> void:
	bad += 1
	push_error(message)
