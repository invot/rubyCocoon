extends RefCounted
## Fresh-state marina walking, tap navigation and ferry arrival checks; no player saves.
const ML = preload("res://scripts/world/map_loader.gd")
const MG = preload("res://scripts/world/map_gen.gd")
const WORLD = preload("res://scripts/data/world_db.gd")
const SHORE = preload("res://scripts/world/shoreline.gd")
var bad := 0

func check(ok: bool, message: String) -> void:
	print("ok " if ok else "FAIL ", message)
	if not ok:
		bad += 1

func run(main, opts: Dictionary) -> void:
	Engine.time_scale = 3.0
	UI.auto = true
	GameState.set_flag("intro_done")
	GameState.set_flag("island_peace")
	await main._go("shellhaven", Vector2i(44, 22))
	var open_beach := true
	for x in range(23, int(main.world.map["w"])):
		for y in range(23, int(main.world.map["h"])):
			open_beach = open_beach and MG.get_t(main.world.map, x, y) in [MG.WATER, MG.SHALLOWS]
	check(open_beach, "beach opens directly onto the sea with no docks in front")
	check(MG.get_t(main.world.map, 3, 17) == MG.WATER and MG.get_t(main.world.map, 3, 21) == MG.WATER, "middle pier has no hook around the large yacht")
	for tile in [Vector2i(44, 14), Vector2i(28, 12), Vector2i(21, 12), Vector2i(18, 24), Vector2i(4, 24), Vector2i(18, 24), Vector2i(18, 16), Vector2i(3, 16), Vector2i(18, 16), Vector2i(18, 8), Vector2i(8, 8)]:
		await main._walk_test([tile])
		check(main.world.player_pos == tile, "marina walkway reaches %s" % tile)
	check(main.world.map["spawns"]["dock"] == Vector2i(8, 8), "ferry arrival is beside the new berth")
	var other := ML.load_map("tidewater", GameState.flags)
	var ferry: Array = other["boats"].filter(func(bt): return bt[3] == "ferry")[0]
	var boats: Array = main.world.map["boats"]
	check(boats.any(func(bt): return bt[3] == ferry[3] and is_equal_approx(float(bt[4]), float(ferry[4]))), "same ferry asset and scale at both ports")
	await main._walk_test([Vector2i(28, 12)])
	check(main.world.player_pos == Vector2i(28, 12), "western pier ramp still reaches town")
	await main._go("shellhaven", Vector2i(14, 16))
	await main._wait(0.8)
	var at: Vector2 = main.world.cam.unproject_position(main.world.tile_pos(Vector2i(14, 15)) + Vector3(0, 0.02, 0))
	for down in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = at
		event.pressed = down
		Input.parse_input_event(event)
		await main.get_tree().process_frame
	await main._wait(0.8)
	check(main.world.player_pos == Vector2i(14, 15), "tap walks along the marina (at %s)" % main.world.player_pos)
	await shore(main, opts)
	# Only synthetic saves under build/: old outdoor positions shift once; interior ids stay stable.
	main._test["save_dir"] = "res://build/shellhaven_marina_touch_saves/" if UI.is_touch() else "res://build/shellhaven_marina_saves/"
	GameState.map_id = "shellhaven"
	GameState.pos = Vector2i(24, 21)
	GameState.flags.erase("shellhaven_west_marina")
	check(GameState.save_game(8) and GameState.load_game(8), "isolated old-layout save loads")
	check(GameState.pos == Vector2i(24 + WORLD.SHELLHAVEN_WEST_PADDING, 21), "old beach position stays on its original tile")
	check(GameState.save_game(8) and GameState.load_game(8), "isolated updated save reloads")
	check(GameState.pos == Vector2i(42, 21), "new-layout save position is not shifted again")
	Engine.time_scale = 1.0
	UI.auto = false
	print("SHELLHAVEN MARINA DONE: %d problem(s)" % bad)

func shore(main, opts: Dictionary) -> void:
	await main._go("shellhaven", Vector2i(43, 22))
	await main._press("move_down")
	await main._wait(0.5)
	check(main.world.player_pos == Vector2i(43, 23), "direction input steps from sand into the shallows")
	var depth: float = SHORE.WATER_Y - main.world.player.position.y
	check(depth > 0.0 and depth <= SHORE.MAX_WADE_DEPTH + 0.001, "feet wade no deeper than five centimetres")
	check(SHORE.step_sound(main.world.map, main.world.player_pos) == "step_water", "wet step selects the pitter-patter sound")
	check(Sfx._streams.get("res://sfx/Custom/Shallow_Step_1.wav") != null or Sfx._streams.get("res://sfx/Custom/Shallow_Step_2.wav") != null, "walking in shallows loads and plays a wet footfall")
	for i in 3:
		await main._press("move_down")
		await main._wait(0.3)
	check(main.world.player_pos == Vector2i(43, 23), "repeated direction presses cannot enter deeper water")
	Input.action_press("run")
	await main._press("move_down")
	await main._wait(0.4)
	Input.action_release("run")
	check(main.world.player_pos == Vector2i(43, 23), "running cannot cross the shallow-water limit")
	# Tap the adjacent shallow tile through the actual window's input pipeline.
	var at: Vector2 = main.world.cam.unproject_position(main.world.tile_pos(Vector2i(44, 23)) + Vector3(0, 0.02, 0))
	for down in [true, false]:
		var ev := InputEventScreenTouch.new()
		ev.index = 0
		ev.position = at
		ev.pressed = down
		Input.parse_input_event(ev)
		await main.get_tree().process_frame
	await main._wait(0.7)
	check(main.world.player_pos == Vector2i(44, 23), "tap navigation walks along the shallows")
	main.world.tap_at(main.world.cam.unproject_position(main.world.tile_pos(Vector2i(44, 24))))
	await main._wait(0.5)
	check(main.world.player_pos == Vector2i(44, 23), "tapping deep water cannot bypass the wading limit")
	if opts.has("shot") and DisplayServer.get_name() != "headless":
		Engine.time_scale = 1.0
		await main._wait(0.5)
		main._save_shot(String(opts["shot"]))
		await main._wait(1.0)
		main._save_shot(String(opts["shot"]).replace(".png", "_wave.png"))
		Engine.time_scale = 3.0
	await main._press("move_up")
	await main._wait(0.5)
	check(main.world.player_pos == Vector2i(44, 22), "trainer returns from the shallows to dry sand")
