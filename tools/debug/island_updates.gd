extends RefCounted
## Focused navigation and visual evidence for the hotel and village changes.
const ML = preload("res://scripts/world/map_loader.gd")
const Elev = preload("res://scripts/world/elevation.gd")
var bad := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		bad += 1
		print("FAIL ", message)

func run(main, opts: Dictionary) -> void:
	UI.auto = true
	GameState.set_flag("intro_done")
	GameState.set_flag("called_dad")
	var resort := ML.load_map("shellhaven", {})
	var hotel: Dictionary = resort["buildings"].filter(func(b): return b.get("hotel", false))[0]
	var base: String = hotel["interior"]
	await main._go(base, "entry")
	# Walk to the foot, up the flight, across the balcony and into the upper hall.
	for point in [Vector2i(16, 9), Vector2i(16, 3), Vector2i(1, 2)]:
		await main._walk_test([point])
	check(main.world.player_pos == Vector2i(1, 2), "walk climbs the lobby staircase to the upper balcony")
	check(is_equal_approx(main.world.player.position.y, 2.7), "balcony stands one storey above the lobby")
	await main._walk_test([Vector2i(0, 2)])
	await main._settle(base + "@5")
	check(main.world.map_id == base + "@5", "upper left hallway opens from the balcony")
	await main._walk_test([Vector2i(0, 2)])
	await main._settle(base)
	check(main.world.map_id == base and Elev.surface(main.world.map, main.world.player_pos) > 2.6, "return from upper hall stays on the balcony")
	for point in [Vector2i(16, 3), Vector2i(16, 9), Vector2i(1, 10), Vector2i(0, 10)]:
		await main._walk_test([point])
	await main._settle(base + "@4")
	check(main.world.map_id == base + "@4", "lower left hallway opens from the lobby")
	for f in [6, 7, 8, 9]:
		await main._go(ML.floor_id(base, f), "start")
		if f == 7:
			check(main.world.npcs.size() == 2 and main.world.npcs.values().all(func(n): return n.get("treadmill", false)), "two treadmill guests run in the gym")
	await main._go("kelpwick", Vector2i(37, 8))
	var crowd: Array = main.world.npcs.values().filter(func(n): return n.get("id", "") == "reef_crowd")
	check(crowd.size() == 2, "two villagers block the reef path")
	check(crowd.all(func(n): return n["look"].get("islander", false)), "reef villagers wear the shared island outfit")
	check(not main.world._walkable(Vector2i(38, 7)) and not main.world._walkable(Vector2i(38, 8)), "both path rows remain blocked before Nerissa")
	if opts.has("shots") and DisplayServer.get_name() != "headless":
		var dir := String(opts["shots"])
		DirAccess.make_dir_recursive_absolute(dir)
		var shots := [[base, Vector2i(10, 10), "hotel_lobby"], [base + "@6", Vector2i(9, 5), "hotel_pool"],
			[base + "@7", Vector2i(5, 4), "hotel_gym"], [base + "@9", Vector2i(2, 3), "hotel_ice"],
			["kelpwick#0", Vector2i(17, 5), "kelpwick_healing"], ["kelpwick#1", "entry", "kelpwick_home"],
			["kelpwick", Vector2i(37, 8), "kelpwick_gate"], ["caccoon", Vector2i(12, 25), "cove_girl"],
			["shellhaven", Vector2i(44, 21), "beach_guests"]]
		for shot in shots:
			await main._go(shot[0], shot[1])
			await main._wait(0.8)
			if shot[2] == "hotel_lobby":
				main.world.cam_free = true
				main.world.cam.position = Vector3(10.5, 14, 24)
				main.world.cam.look_at(Vector3(10.5, 2.0, 6.5))
				await main._wait(0.2)
			await RenderingServer.frame_post_draw
			main._save_shot(dir + "/" + shot[2] + ".png")
	print("ISLAND UPDATES DONE: %d problem(s)" % bad)
