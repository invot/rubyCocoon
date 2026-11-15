extends RefCounted
## Fresh-state island regression: actual entrances, room links, shop charges and A/B hotel prompts.
const ML = preload("res://scripts/world/map_loader.gd")
var bad := 0
var main

func check(ok: bool, message: String) -> void:
	if not ok:
		bad += 1
		print("FAIL ", message)

func answer(yes: bool) -> void:
	if UI.is_touch() and DisplayServer.get_name() != "headless":
		var button: TouchScreenButton = UI.controls._buttons["a" if yes else "b"]
		var at := button.get_global_transform_with_canvas() * (button.texture_normal.get_size() / 2.0)
		at *= Vector2(main.get_window().size) / main.get_viewport().get_visible_rect().size
		for down in [true, false]:
			var ev := InputEventScreenTouch.new()
			ev.index = 0
			ev.position = at
			ev.pressed = down
			Input.parse_input_event(ev)
			await main.get_tree().process_frame
	else:
		await main._press("ui_accept" if yes else "ui_cancel")
	await main._wait(0.4)

func run(game, opts: Dictionary) -> void:
	main = game
	UI.auto = true
	GameState.set_flag("intro_done")
	GameState.set_flag("island_peace")
	if opts.get("huts", "0") == "1":
		await _huts(opts)
		UI.auto = false
		print("ISLAND TOWNS DONE: %d problem(s)" % bad)
		return
	var town := ML.load_map("kelpwick", GameState.flags)
	var home: Dictionary = town["buildings"].filter(func(b): return b["shop"] == "house")[0]
	await main._go("kelpwick", home["door"] + Vector2i.DOWN)
	await load("res://tools/debug/waterfront.gd").new()._tap(main, home["door"])
	await main._settle(home["interior"])
	check(main.world.map_id == home["interior"], "tap enters round house through the centered door")
	if main.world.map_id == home["interior"]:
		var exit: Vector2i = main.world.map["exits"].keys()[0]
		check(exit.y < int(main.world.map["h"]) - 1, "round-house entrance is in a visible side wall")
		await main._walk_test([exit])
		await main._settle("kelpwick")
		check(main.world.map_id == "kelpwick", "side-wall interior threshold exits to the correct doorstep")
	var store: Dictionary = town["buildings"].filter(func(b): return b["shop"] == "beast_gear")[0]
	var had := GameState.item_count("minor_potion")
	GameState.gold = 1000
	UI.auto_answers = [0, 0, -1, 2]
	await Places.open(store, main.world)
	check(GameState.gold == 979 and GameState.item_count("minor_potion") == had + 1, "basic store displays and charges its 21-gold price")
	var resort := ML.load_map("shellhaven", GameState.flags)
	var center: Dictionary = resort["buildings"].filter(func(b): return b["shop"] == "center")[0]
	var center_front: Vector2i = center["door"] + Vector2i.DOWN
	await main._go("shellhaven", center_front)
	if opts.has("center_shot") and DisplayServer.get_name() != "headless":
		await main._wait(3.2)
		var path := String(opts["center_shot"])
		main._save_shot(path)
		main.world.cam_free = true
		main.world.cam.position = Vector3(40, 18.5, 18)
		main.world.cam.look_at(Vector3(40, 1, 2.7), Vector3.UP)
		await main._wait(0.5)
		main._save_shot(path.replace(".png", "_overview.png"))
		main.world.cam_free = false
	await load("res://tools/debug/waterfront.gd").new()._tap(main, center["door"])
	await main._settle(center["interior"])
	check(main.world.map_id == center["interior"], "tap enters the enlarged Beast Center")
	if main.world.map_id == center["interior"]:
		await main._walk_test([main.world.map["front_doors"][0]])
		await main._settle("shellhaven")
		check(main.world.player_pos == center_front, "Beast Center returns to its original doorstep")
	var boutique: Dictionary = resort["buildings"].filter(func(b): return b["shop"] == "apothecary")[0]
	GameState.gold = 1000
	var first: String = Places.apothecary_stock(2, "shellhaven")[0]
	var expected := GameState.price(int(round(int(Places.ItemDB.get_item(first)["price"]) * 1.4)))
	UI.auto_answers = [0, 0, -1, 2]
	await Places.open(boutique, main.world)
	check(GameState.gold == 1000 - expected, "boutique charges its displayed premium price")
	var hotel: Dictionary = resort["buildings"].filter(func(b): return b.get("hotel", false))[0]
	check(not Places.door_locked(hotel), "hotel is open for business, never a locked house")
	var doorstep: Vector2i = hotel["door"] + Vector2i.DOWN
	await main._go("shellhaven", doorstep)
	if opts.has("shot") and DisplayServer.get_name() != "headless":
		await main._wait(1.0)
		main._save_shot(String(opts["shot"]).replace(".png", "_door.png"))
	await load("res://tools/debug/waterfront.gd").new()._tap(main, hotel["door"])
	await main._settle(hotel["interior"])
	check(main.world.map_id == hotel["interior"], "tap enters the hotel through its street door")
	if main.world.map_id == hotel["interior"]:
		if opts.has("shot") and DisplayServer.get_name() != "headless":
			main._save_shot(String(opts["shot"]).replace(".png", "_lobby.png"))
		await main._walk_test([main.world.map["front_doors"][0]])
		await main._settle("shellhaven")
		check(main.world.map_id == "shellhaven" and main.world.player_pos == doorstep, "leaving the lobby returns to the hotel's doorstep")
		main.world._step(Vector2i.UP, false)
		await main._settle(hotel["interior"])
		check(main.world.map_id == hotel["interior"], "walking up into the hotel door enters it")
	print("HOTEL INTERIOR ", hotel["interior"])
	await main._go(hotel["interior"], "entry")
	print("[island] lobby ready")
	var hotel_base: String = hotel["interior"]
	# Lobby stairs are real elevation within one room; both halls and all guest facilities have reciprocal doors.
	var lobby: Dictionary = main.world.map
	check(lobby["room"].get("balcony", false), "lobby contains an upstairs balcony")
	for f in range(1, ML.room_set(hotel).size() + 1):
		var id := ML.floor_id(hotel_base, f)
		var m := ML.load_map(id, {})
		for door in m["exits"]:
			var ex: Dictionary = m["exits"][door]
			if String(ex["to"]).begins_with(hotel_base):
				var next := ML.load_map(ex["to"], {})
				check(next["spawns"].has(ex["spawn"]), "hotel rooms have reciprocal arrival points")
	GameState.gold = 300
	UI.auto = true
	await Places.open(hotel, main.world)
	check(GameState.gold == 300, "reservation refusal charges no gold")
	check(UI.auto_log.any(func(line): return "reservation" in String(line).to_lower()), "clerk refuses a guest without a reservation")
	var pool := ML.load_map(ML.floor_id(hotel_base, 6), {})
	for beast in GameState.party:
		beast.hp = 1
		beast.mp = 0
	UI.auto_answers = [0]
	await Places.prop(main.world.MapGen.FURN, pool, main.world, Vector2i(10, 6))
	check(GameState.party.all(func(beast): return beast.hp == beast.max_hp() and beast.mp == beast.max_mp()), "hot tub restores the whole party's HP and MP")
	var ice := ML.load_map(ML.floor_id(hotel_base, 9), {})
	var seeds := GameState.item_count("revival_seed")
	await Places.prop(main.world.MapGen.FURN, ice, main.world, Vector2i(3, 2))
	await Places.prop(main.world.MapGen.FURN, ice, main.world, Vector2i(3, 2))
	check(GameState.item_count("revival_seed") == seeds + 1, "broken upstairs ice maker gives its item exactly once")
	UI.clear_all()
	var west_pad: int = main.world.WorldDB.SHELLHAVEN_WEST_PADDING
	await main._go("shellhaven", Vector2i(24 + west_pad, 21))
	for x in [14, 18, 22, 26, 30, 34]:
		check(not main.world._walkable(Vector2i(x + west_pad, 19)), "occupied chaise blocks walking")
	await main._walk_test([Vector2i(26 + west_pad, 22)])
	check(main.world.player_pos == Vector2i(26 + west_pad, 22), "beach aisle stays open")
	UI.auto = false
	print("ISLAND TOWNS DONE: %d problem(s)" % bad)


## Focused stilt-hut regression / preview: --scene=island-towns --huts=1 [--touch] [--shot=...].
func _huts(opts: Dictionary) -> void:
	main.get_window().title = "Ruby Cocoon - Kelpwick huts"
	GameState.gear["flute"] = "reed_flute"
	GameState.set_flag("reed_flute")
	var town := ML.load_map("kelpwick", GameState.flags)
	for b in town["buildings"]:
		if opts.get("arena", "0") == "1" and b["shop"] != "arena":
			continue
		if Places.door_locked(b):
			continue
		await main._go("kelpwick", b["door"] + Vector2i.DOWN)
		await main._wait(0.65)
		var outside = main.world
		var base: float = outside._lift(b["door"])
		if opts.has("shot") and b["shop"] == "arena" and DisplayServer.get_name() != "headless":
			main._save_shot(String(opts["shot"]).replace(".png", "_arena_exterior.png"))
			outside.cam_free = true
			outside.cam.position = Vector3(21.5, 15.5, 17)
			outside.cam.look_at(Vector3(21.5, 2.6, 3.5), Vector3.UP)
			await main._wait(0.5)
			main._save_shot(String(opts["shot"]).replace(".png", "_arena_overview.png"))
			outside.cam_free = false
			await main._wait(0.4)
		if UI.is_touch():
			var at: Vector2 = outside.cam.unproject_position(outside.tile_pos(b["door"]) + Vector3(0, 1.6, 0))
			at *= Vector2(main.get_window().size) / Vector2(main.view.size)
			# Screen-touch events enter in window pixels; Godot applies the viewport stretch once.
			for down in [true, false]:
				var event := InputEventScreenTouch.new()
				event.index = 0
				event.pressed = down
				event.position = at
				Input.parse_input_event(event)
				await main.get_tree().process_frame
		else:
			await main._press("move_up")
		var began: bool = outside.busy and not outside._climb.is_empty()
		var climbed := false
		# Wait for actual motion rather than one timer tick: a screenshot's first-draw hitch can
		# resume the timer before the world's movement callback has run for that frame.
		for attempt in 20:
			if outside.player.position.y > base + 0.01:
				climbed = true
				break
			if main.world != outside:
				break
			await main._wait(0.02)
		check(began or climbed, "%s starts a single stair climb" % b["interior"])
		check(climbed, "%s climbs above the street" % b["interior"])
		if opts.has("shot") and b["shop"] == "house" and DisplayServer.get_name() != "headless":
			main._save_shot(String(opts["shot"]).replace(".png", "_stairs_%d.png" % int(b["index"])))
		# Bound the wait so a broken entrance reports a failure promptly.
		for attempt in 100:
			if main.world.map_id == b["interior"] and not main._transitioning:
				break
			await main._wait(0.1)
		check(main.world.map_id == b["interior"], "%s enters through its raised doorway" % b["interior"])
		if main.world.map_id != b["interior"]:
			continue
		if b["shop"] == "arena":
			var rows: Array = main.world.map["room"]["rows"]
			check(rows.all(func(row): return not "/" in String(row) and not "\\" in String(row) and not " " in String(row)), "arena hall has rectangular walls")
			check(main.world.machines.has("healer"), "rectangular arena retains the healer")
			var phone: Vector2i = main.world.map["counter_phone"]
			await main._walk_test([phone + Vector2i.DOWN])
			check(main.world.player_pos == phone + Vector2i.DOWN, "arena counter phone is reachable")
			if main.world.machines.has("healer"):
				var machine: Vector3 = main.world.machines["healer"]["node"].position
				var approach := Vector2i(floori(machine.x), floori(machine.z)) + Vector2i.DOWN
				await main._walk_test([approach])
				check(main.world.player_pos == approach, "arena healing machine is reachable")
			for tile in main.world.npcs:
				if main.world.npcs[tile].get("kind", "") == "leader":
					await main._walk_test([tile + Vector2i.DOWN])
					check(main.world.player_pos == tile + Vector2i.DOWN, "Nerissa remains reachable")
					break
			if opts.has("shot") and DisplayServer.get_name() != "headless":
				main._save_shot(String(opts["shot"]).replace(".png", "_arena_gameplay.png"))
				main.world.cam_free = true
				main.world.cam.position = Vector3(10.5, 18, 23)
				main.world.cam.look_at(Vector3(10.5, 0, 6), Vector3.UP)
				await main._wait(0.6)
				main._save_shot(String(opts["shot"]).replace(".png", "_arena_interior.png"))
				main.world.cam_free = false
		var exit: Vector2i = main.world.map["front_doors"][0]
		await main._walk_test([exit])
		for attempt in 100:
			if main.world.map_id == "kelpwick" and not main._transitioning:
				break
			await main._wait(0.1)
		check(main.world.map_id == "kelpwick" and main.world.player_pos == b["door"] + Vector2i.DOWN, "%s returns to the foot of its stairs" % b["interior"])
	await main._go("kelpwick", Vector2i(7, 9))
	if opts.has("shot") and DisplayServer.get_name() != "headless":
		await main._wait(1.0)
		main._save_shot(String(opts["shot"]).replace(".png", "_gameplay.png"))
		main.world.cam_free = true
		main.world.cam.position = Vector3(20.5, 27, 32)
		main.world.cam.look_at(Vector3(20.5, 3, 3), Vector3.UP)
		await main._wait(1.0)
		main._save_shot(String(opts["shot"]).replace(".png", "_village.png"))
		main.world.cam.position = Vector3(7.5, 13.5, 16)
		main.world.cam.look_at(Vector3(7.5, 3.5, 3), Vector3.UP)
		await main._wait(1.0)
		main._save_shot(String(opts["shot"]))
	main.world.cam_free = false
	if opts.has("hold"):
		await main._wait(float(opts["hold"]))
