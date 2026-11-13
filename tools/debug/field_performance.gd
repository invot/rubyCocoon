extends RefCounted
## Windowed CPU/GPU sampling while the gameplay camera passes behind houses. No player state is loaded.
const Beasts = preload("res://scripts/core/beasts.gd")
var report := {}

func run(main, opts: Dictionary) -> void:
	if opts.get("await_focus", "0") == "1":
		main.get_window().title = "Ruby Cocoon - 006 field " + String(opts.get("report", "")).get_base_dir().get_file()
	if opts.get("await_focus", "0") == "1" and not await load("res://tools/debug/vo_perf.gd").wait_for_desktop_focus(main):
		push_error("field benchmark could not acquire stable desktop focus")
		return
	UI.auto = true
	for flag in ["intro_done", "tutorial_done", "ritual_done", "opening_seen"]:
		GameState.set_flag(flag)
	GameState.party = [Beasts.create(0, 10)]
	# --finish=0 measures without the surfaces' soft finishes (surface_finish.gd), --prebuild=0 without building every
	# building behind the arrival fade (world.gd prepare_arrival_view)
	load("res://scripts/gfx/surface_finish.gd").enabled = opts.get("finish", "1") == "1"
	(await main.wait_for_script(main.WORLD_PATH)).prebuild = opts.get("prebuild", "1") == "1"
	# --fade=1 / 0 forces the buildings' arrival fade on or off (it is off on Compatibility: world.gd NO_ARRIVAL_FADE)
	if opts.has("fade"):
		(await main.wait_for_script(main.WORLD_PATH)).NO_ARRIVAL_FADE = opts["fade"] == "0"
	for town in String(opts.get("maps", "caccoon,tidewater,cogsworth")).split(","):
		await main._go(town, "start")
		var world = main.world
		world.frozen = true
		world.busy = true
		world.set_process(false)
		var vp: RID = main.view.get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(vp, true)
		var house: Dictionary = world.map["buildings"][1]
		var start := Vector2(float(house["x"])-2.0, float(house["y"])-1.0)
		var frames := []
		var ticks := []
		var gpu := []
		var render_cpu := []
		var sections := {}
		var focused_frames := 0
		var last := Time.get_ticks_usec()
		for i in 240:
			# Same directed path on both runs, including newly visible buildings and their arrival fades.
			var p := start + Vector2(sin(float(i)/120.0*PI)*10.0, 0)
			world.player.position = Vector3(p.x, world._lift(Vector2i(p)), p.y)
			var began := Time.get_ticks_usec()
			world._process(1.0/60.0)
			ticks.append((Time.get_ticks_usec()-began)/1000.0)
			await main.get_tree().process_frame
			var now := Time.get_ticks_usec()
			frames.append((now-last)/1000.0)
			last = now
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
			render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp))
			if main.get_window().has_focus():
				focused_frames += 1
		for method in ["_fade_buildings", "_update_hole", "_animate_npcs", "_update_wilds"]:
			var samples := []
			for i in 60:
				world.player.position.x += 0.01
				var began := Time.get_ticks_usec()
				if method == "_update_hole":
					world.call(method)
				else:
					world.call(method, 1.0/60.0)
				samples.append((Time.get_ticks_usec()-began)/1000.0)
			sections[method] = _stats(samples)
		RenderingServer.viewport_set_measure_render_time(vp, false)
		report[town] = {"frames": _stats(frames), "tick_cpu": _stats(ticks), "gpu": _stats(gpu), "render_cpu": _stats(render_cpu), "sections": sections,
			"focused_frames": focused_frames, "sampled_frames": frames.size(),
			"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)}
		print("[field performance] ", town, " ", JSON.stringify(report[town]))
	if opts.has("report"):
		var file := FileAccess.open(String(opts["report"]), FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t"))
	UI.auto = false
	print("FIELD PERFORMANCE DONE")

func _stats(values: Array) -> Dictionary:
	values.sort()
	return {"median_ms": values[values.size()/2], "p95_ms": values[int(values.size()*0.95)], "max_ms": values.back()}
