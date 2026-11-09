extends SceneTree
## Windowed water inspection and steady-frame timings. Uses only the existing isolated --scene harness.
## Pass --scene=world:shellhaven --spawn=43,22 --quit=0 --save_dir=res://build/water_saves/.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	root.title = "Ruby Cocoon - Water Preview"
	# Compatibility compiles its first visible materials synchronously; allow a cold shader cache to finish.
	var deadline := Time.get_ticks_msec() + 90000
	while not is_instance_valid(game.world) or game.world.cam == null or game._transitioning:
		await process_frame
		if Time.get_ticks_msec() > deadline:
			push_error("Water preview timed out waiting for the world")
			quit(1)
			return
	await create_timer(3.0).timeout
	var frames: Array[float] = []
	var last := Time.get_ticks_usec()
	for i in 180:
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append(float(now - last) / 1000.0)
		last = now
	frames.sort()
	print("WATER FRAME TIMING: renderer=%s size=%s median=%.2fms p95=%.2fms draw_calls=%d primitives=%d" % [
		RenderingServer.get_current_rendering_method(), game.view.size, frames[90], frames[171],
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	if game._test.has("shot"):
		game._save_shot(String(game._test["shot"]).replace(".png", "_wave.png"))
	if game._test.get("hold", "0") != "1":
		quit()
