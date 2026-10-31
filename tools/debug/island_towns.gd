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
	var boutique: Dictionary = resort["buildings"].filter(func(b): return b["shop"] == "apothecary")[0]
	GameState.gold = 1000
	var first: String = Places.apothecary_stock(2, "shellhaven")[0]
	var expected := GameState.price(int(round(int(Places.ItemDB.get_item(first)["price"]) * 1.4)))
	UI.auto_answers = [0, 0, -1, 2]
	await Places.open(boutique, main.world)
	check(GameState.gold == 1000 - expected, "boutique charges its displayed premium price")
	var hotel: Dictionary = resort["buildings"].filter(func(b): return b.get("hotel", false))[0]
	print("HOTEL INTERIOR ", hotel["interior"])
	await main._go(hotel["interior"], "entry")
	print("[island] lobby ready")
	var suite_door: Vector2i
	for tile in main.world.map["exits"]:
		if String(main.world.map["exits"][tile]["to"]).ends_with("@2"):
			suite_door = tile
	await main._go(hotel["interior"], suite_door + Vector2i(2, 0))
	await main._walk_test([suite_door])
	for attempt in 50:
		if main.world.map_id == hotel["interior"] + "@2" and not main._transitioning:
			break
		await main._wait(0.1)
	print("[island] suite reached ", main.world.map_id)
	check(main.world.map_id == hotel["interior"] + "@2", "hotel suite door is reachable")
	await main._go(hotel["interior"], "entry")
	print("[island] hotel prompt ready")
	UI.auto = false
	GameState.gold = 300
	Places.open(hotel, main.world)
	await main._wait(0.6)
	check(UI.stack.back() is UI.ConfirmPrompt, "hotel uses the shared direct A/B prompt")
	check(UI.stack.back().lines.size() == 1, "hotel decision fits one page at touch reference size")
	if opts.has("shot") and DisplayServer.get_name() != "headless":
		main._save_shot(String(opts["shot"]))
	await answer(false)
	check(GameState.gold == 300, "B declines without charging")
	Places.open(hotel, main.world)
	await main._wait(0.5)
	await answer(true)
	check(GameState.gold == 150, "A charges for exactly one hotel stay")
	await main._press("ui_accept")
	await main._wait(0.3)
	UI.auto = true
	UI.clear_all()
	var west_pad: int = main.world.WorldDB.SHELLHAVEN_WEST_PADDING
	await main._go("shellhaven", Vector2i(24 + west_pad, 21))
	for x in [14, 18, 22, 26, 30, 34]:
		check(not main.world._walkable(Vector2i(x + west_pad, 19)), "occupied chaise blocks walking")
	await main._walk_test([Vector2i(26 + west_pad, 22)])
	check(main.world.player_pos == Vector2i(26 + west_pad, 22), "beach aisle stays open")
	UI.auto = false
	print("ISLAND TOWNS DONE: %d problem(s)" % bad)
