extends RefCounted
## Cliff-town regression and library preview, using fresh state and the real world/UI.
const MapLoader = preload("res://scripts/world/map_loader.gd")
const MapGen = preload("res://scripts/world/map_gen.gd")
const Elev = preload("res://scripts/world/elevation.gd")

var bad := 0


func run(main, opts: Dictionary) -> void:
	UI.auto = true
	GameState.set_flag("intro_done")
	await Menus.world_map()
	_check(not GameState.flag("world_map") and "Cocoon Cove Library" in String(UI.auto_log.back()), "before the gift, opening the map points players to the library")
	await main._go("caccoon", "start")
	var town: Dictionary = main.world.map
	var library := MapLoader.interior_of("caccoon", "bookstore")
	_check(library == "caccoon#5", "library appends to the five existing building identities")
	_check(town["buildings"][0]["shop"] == "center" and town["buildings"][1]["shop"] == "home"
		and town["buildings"][2]["shop"] == "apothecary", "Beast Center, home and apothecary keep their saved interior ids")
	var open_town := MapLoader.load_map("caccoon", {})
	_check(town["exits"].is_empty() and open_town["exits"].size() == 2
		and open_town["exits"].values().all(func(e): return e["to"] == "route1"), "Bram closes the only exit until the first beast, with no shore route")
	var forbidden := false
	var lower_walkable := false
	for y in town["h"]:
		for x in town["w"]:
			var code := MapGen.get_t(town, x, y)
			forbidden = forbidden or code in [MapGen.SAND, MapGen.BRIDGE]
			lower_walkable = lower_walkable or (MapGen.walkable(code) and Elev.surface(town, Vector2i(x, y)) < 3.0)
	_check(not forbidden and not lower_walkable, "no beach, pier or walkable ground below the bluff")
	var home: Dictionary = town["buildings"][1]
	var home_level := Elev.surface(town, home["door"])
	_check(home_level > Elev.surface(town, town["buildings"][0]["door"])
		and [3, 4].all(func(i): return Elev.surface(town, town["buildings"][i]["door"]) == home_level), "the starting home and both neighboring houses share a shelf above town")
	_check(town.get("outskirt_houses", []).is_empty() and town.get("scenery_houses", []).size() == 3, "two close background homes and the cliff shack replace distant outskirt buildings")
	for entry in town.get("scenery_houses", []):
		var position := Vector2i(int(entry["x"]), int(entry["y"]))
		_check(main.world.find_child(entry["name"], true, false) != null, "%s renders" % entry["name"])
		_check(not MapGen.walkable(MapGen.get_t(town, position.x, position.y)), "%s has no accessible entrance" % entry["name"])
		if entry["name"] != "CliffShack":
			_check(Elev.surface(town, position) == Elev.surface(town, town["buildings"][0]["door"]), "background home stays on the Beast Center's level")
	main.world.spawn_at(Vector2i(8, 21))
	_check(main.world._walkable(main.world.player_pos), "a save on the old pier loads onto safe ground")
	main.world.spawn_at("start")
	var b: Dictionary = town["buildings"][5]
	await main._walk_test([b["door"] + Vector2i(0, 1)])
	_check(main.world.player_pos == b["door"] + Vector2i(0, 1), "the home lane reaches the library at the square entrance")
	main.world.facing = Vector2i(0, -1)
	await main.world._interact()
	await main._settle(library)
	_check(main.world.map.get("room_key", "") == "library", "front door enters the public reading room")
	await main._walk_test([Vector2i(5, 3)])
	main.world.facing = Vector2i(0, -1)
	UI.auto = false
	if opts.get("verify", "0") == "1":
		main.world._interact()
		await main._wait(0.35)
		_check(not UI.stack.is_empty(), "A talks to Quill across the counter")
		var presses := 0
		while not UI.stack.is_empty() and presses < 30:
			if UI.is_touch():
				var button = UI.controls._buttons["a"]
				await main._tap_at(button.get_global_transform_with_canvas() * Vector2(UI.controls.ROUND / 2.0, UI.controls.ROUND / 2.0))
			else:
				await main._press("ui_accept")
			await main._wait(0.22)
			presses += 1
		_check(GameState.flag("world_map") and UI.stack.is_empty(), "dialogue controls receive the map and close without leaking into another interaction")
		_check(GameState.party.is_empty() and not GameState.has_flute() and not GameState.flag("got_egg"), "the map gift leaves the egg and flute progression untouched")
		Menus.world_map()
		await main._wait(0.4)
		_check(not UI.stack.is_empty(), "the acquired map unfolds")
		await main._press("ui_cancel")
		await main._wait(0.25)
		UI.auto = true
		await main.world._interact()
		_check(GameState.flag("world_map"), "repeat visits preserve the map")
		if GameState.save_dir().begins_with("res://build/"):
			_check(GameState.save_game(0), "map acquired state saves to the isolated test slot")
			GameState.set_flag("world_map", false)
			_check(GameState.load_game(0) and GameState.flag("world_map"), "map ownership survives save/load")
		GameState.flags.erase("world_map")
		UI.auto = false
		Menus.world_map()
		await main._wait(0.3)
		_check(not UI.stack.is_empty() and UI.stack.back().get_script().resource_path.ends_with("world_map_view.gd"), "older saves without a map flag retain map access")
		await main._press("ui_cancel")
		await main._wait(0.25)
		print("COCOON DONE: %d problem(s)" % bad)
		return
	if opts.get("preview", "room") == "gift":
		main.world._interact()
		await main._wait(0.5)
		if not UI.stack.is_empty():
			UI.stack.back().text_label.visible_characters = -1
	await main._wait(float(opts.get("wait", "2")))
	if opts.has("shot"):
		await RenderingServer.frame_post_draw
		main._save_shot(String(opts["shot"]))


func _check(ok: bool, label: String) -> void:
	print("ok   " if ok else "FAIL ", label)
	if not ok:
		bad += 1
