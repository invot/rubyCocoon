extends RefCounted
## Pirate-cove layout, dock access, saved identities, starter gear and library gift.
const MapLoader = preload("res://scripts/world/map_loader.gd")
const MapGen = preload("res://scripts/world/map_gen.gd")
const Elev = preload("res://scripts/world/elevation.gd")
const ItemDB = preload("res://scripts/data/item_db.gd")

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
	_check(town.get("style", "") == "pirate_cove" and town["w"]*town["h"] < 66*49, "the supplied-kit cove is smaller than the former map")
	_check(town.get("boats",[]).is_empty(), "the cove has docks without ships or boats")
	var apothecary: Dictionary = town["buildings"][2]
	_check(not apothecary.get("over_water",false) and Elev.surface(town,apothecary["door"]) == 1.0
		and apothecary["cove_model"] == "house_3", "the apothecary is a plaster shop on the eastern land")
	_check([3,6].all(func(i): return town["buildings"][i].get("over_water",false) and String(town["buildings"][i]["cove_model"]).begins_with("hut_")), "only wooden shacks stand on the dock")
	_check(not town["buildings"][4].get("over_water",false)
		and Elev.surface(town,town["buildings"][4]["door"]) == 1.0, "the plaster neighbor's home stands on land")
	var deck_tiles := 0
	for y in town["h"]:
		for x in town["w"]:
			deck_tiles += 1 if MapGen.get_t(open_town,x,y) == MapGen.BRIDGE else 0
	_check(deck_tiles<=86,"the compact dock has %d public deck tiles, including the removed lightposts (169 before)" % deck_tiles)
	var cargo := 0
	var missing_cargo := []
	for entry in town.get("street_props",[]):
		if MapGen.get_t(town,int(entry[0]),int(entry[1])) == MapGen.STREET_PROP:
			cargo += 1
		else:
			missing_cargo.append(Vector2i(int(entry[0]),int(entry[1])))
	_check(cargo==town.get("street_props",[]).size() and cargo>=10,"all authored crates and barrels render on their spare edge tiles; missing %s" % str(missing_cargo))
	var blocked_lanes := []
	for clear in town.get("prop_clearance",[]):
		for y in range(int(clear[1]),int(clear[1])+int(clear[3])):
			for x in range(int(clear[0]),int(clear[0])+int(clear[2])):
				if MapGen.get_t(town,x,y) == MapGen.STREET_PROP:
					blocked_lanes.append(Vector2i(x,y))
	_check(blocked_lanes.is_empty(),"walking lanes, stairs and doorway approaches contain no furniture: %s" % str(blocked_lanes))
	var accesses := []
	for y in town["h"]:
		for x in town["w"]:
			var p := Vector2i(x,y)
			if not MapGen.walkable(MapGen.get_t(town,x,y)) or Elev.surface(town,p)>0.01:
				continue
			for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var q: Vector2i = p+delta
				if MapGen.walkable(MapGen.get_t(town,q.x,q.y)) and Elev.surface(town,q)>0.01 and Elev.joined(town,p,q):
					accesses.append(q)
	_check(accesses.size()==2 and accesses.all(func(p): return p.x in [44,45] and p.y==30), "only the two-tile right-hand stairs connect land to the dock")
	var reachable: Dictionary = main.world._reachable(town["spawns"]["start"])
	var trapped := []
	for y in town["h"]:
		for x in town["w"]:
			if MapGen.walkable(MapGen.get_t(town,x,y)) and not reachable.has(Vector2i(x,y)):
				trapped.append(Vector2i(x,y))
	_check(trapped.is_empty(), "every walkable tile connects to town; no isolated old-save positions: %s" % str(trapped))
	var models = load("res://scripts/gfx/house_models.gd")
	var cove = load("res://scripts/gfx/cove_buildings.gd")
	for building in town["buildings"]:
		var fit: Dictionary = cove.plan(building)
		_check(is_equal_approx(cove._height(fit["key"], cove.FLOORS[fit["key"]][0], fit["scale"]), cove.ground_storey(fit["key"])), "%s has a person-scale ground storey" % building["name"])
		var node: Node3D = cove.build(building)
		var standard := false
		for inst in node.find_children("*","MeshInstance3D",true,false):
			standard = standard or (inst.mesh is QuadMesh and is_equal_approx(inst.mesh.size.y,models.DOOR_H)
				and is_equal_approx(inst.mesh.size.x,models.DOOR_H/models.DOOR_ASPECT))
		_check(standard, "%s uses the other towns' full-size door" % building["name"])
		node.free()
	var library_b: Dictionary = town["buildings"][5]
	_check(library_b["cove_model"] == "whole_house" and int(library_b["w"]) % 2 == 1
		and library_b["door"].x == int(library_b["x"]) + int(library_b["w"]) / 2,
		"the library is the kit's two-storey house, its door in the middle with a window either side, without loading bays")
	var cottage_area := 5.27 * 3.74
	var library_rect: Rect2 = cove.plan(library_b)["rect"]
	_check(library_rect.get_area() > cottage_area * 1.3, "the library is larger than the old reading cottage")
	_check(MapLoader.room_set(town["buildings"][3]) == ["cove_dock_shack"], "the pier neighbor's home is a wooden shack inside")
	_cove_ground(town)
	var home: Dictionary = town["buildings"][1]
	var home_level := Elev.surface(town, home["door"])
	_check(home_level > Elev.surface(town, town["buildings"][0]["door"])
		and Elev.surface(town,town["buildings"][3]["door"]) == 0.0
		and Elev.surface(town,town["buildings"][4]["door"]) == 1.0, "home overlooks the land village and short shack dock")
	_check(town.get("outskirt_houses", []).is_empty() and town.get("scenery_houses", []).size() == 2, "two close background homes replace distant outskirt buildings")
	for entry in town.get("scenery_houses", []):
		var position := Vector2i(int(entry["x"]), int(entry["y"]))
		# Scenery shares the streamed building path: inspect it with its footprint in view.
		var aim := Vector3(position.x + float(entry["w"]) / 2.0, main.world._lift(position), position.y + float(entry["d"]) / 2.0)
		main.world.cam.position = aim + main.world.CAM_OFFSET
		main.world.cam.look_at(aim + Vector3(0, main.world.CAM_LOOK_Y, 0))
		for attempt in main.world.building_fades.size():
			main.world._fade_buildings(0.0)
			if main.world.find_child(entry["name"], true, false) != null:
				break
		_check(main.world.find_child(entry["name"], true, false) != null, "%s renders" % entry["name"])
		_check(not MapGen.walkable(MapGen.get_t(town, position.x, position.y)), "%s has no accessible entrance" % entry["name"])
		var doorway := Vector2i(floori(float(entry["x"]) + float(entry["w"]) / 2.0 + float(entry.get("cove_door_dx", 0.0))), int(entry["y"]) + int(entry["d"]) - 1)
		_check(main.world._ground_tile(doorway) == MapGen.DOOR and not MapGen.walkable(MapGen.get_t(town, doorway.x, doorway.y)),
			"%s's path runs right up to its door" % entry["name"])
		_check(Elev.surface(town, position) > Elev.surface(town, town["buildings"][0]["door"]), "the scenery homes occupy the rear cliff shelf")
	main.world._place_camera(true)
	if await _preview(main,opts):
		return
	main.world.spawn_at(apothecary["door"]+Vector2i.DOWN)
	main.world.facing = Vector2i.UP
	await _enter(main,apothecary)
	await main._settle(apothecary["interior"])
	_check(main.world.map_id == apothecary["interior"] and main.world.map.get("room_key", "") == "apothecary", "the visible apothecary front door enters its original shop")
	await main._go("caccoon", "start")
	if await _shack(main, opts):
		return
	await main._go("caccoon", "start")
	town = main.world.map
	for legacy in [Vector2i(8,21),Vector2i(65,48),Vector2i(40,17),Vector2i(19,5)]:
		main.world.spawn_at(legacy)
		_check(main.world._walkable(main.world.player_pos), "old saved position %s recovers onto safe ground" % legacy)
	main.world.spawn_at("start")
	var b: Dictionary = town["buildings"][5]
	await main._walk_test([b["door"] + Vector2i(0, 1)])
	_check(main.world.player_pos == b["door"] + Vector2i(0, 1), "the home lane reaches the library at the square entrance")
	main.world.facing = Vector2i(0, -1)
	await _enter(main,b)
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
		_check(not UI.stack.is_empty() and UI.stack.back().get_script().resource_path.ends_with("book_menu.gd")
			and is_instance_valid(UI.stack.back().map_view), "older saves without a map flag retain map access")
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


## The gear shack at the far end of the dock: reached from the square, entered by its door, and its starter gear
## picked up and put on. True when a --preview=shack_path / shack screenshot ends the scenario there.
func _shack(main, opts: Dictionary) -> bool:
	var town: Dictionary = main.world.map
	var shack: Dictionary = town["buildings"][6]
	var step: Vector2i = shack["door"] + Vector2i(0, 1)
	_check(shack["shop"] == "shack" and shack["interior"] == "caccoon#6", "the gear shack follows the saved buildings' interior ids")
	_check(Elev.surface(town, step) == Elev.surface(town, shack["door"]), "the shack's doorstep is level with it")
	main.world.spawn_at(Vector2i(24, 21))
	for i in 3:
		if main.world.player_pos != step:
			await main._walk_test([step])
	_check(main.world.player_pos == step, "the right-hand stairs and simple dock lead to the gear shack's door")
	main.world.facing = Vector2i(0, -1)
	if opts.get("preview", "") == "shack_path":
		await _shot(main, opts)
		return true
	await _enter(main,shack)
	await main._settle(shack["interior"])
	var room: Dictionary = main.world.map
	_check(room.get("room_key", "") == "shack", "the shack's door opens into its room")
	var found := {}
	for it in room["items"]:
		found[it["item"]] = it["pos"]
	_check(found.has("worn_cap") and found.has("old_sneakers") and found.has("rope_collar"), "a cap, sneakers and a beast's collar lie in the shack")
	if opts.get("preview", "") == "shack":
		await _shot(main, opts)
		return true
	for id in found:
		var pos: Vector2i = found[id]
		for d in [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]:
			if main.world._walkable(pos + d) and not main.world.items.has(pos + d):
				await main._walk_test([pos + d])
				if main.world.player_pos == pos + d:
					main.world.facing = -d
					await main.world._interact()
					break
		_check(GameState.item_count(id) == 1, "picked up the %s" % ItemDB.item_name(id))
	_check(ItemDB.stock("tgear", 12, "test").filter(func(id): return id in found).is_empty()
		and ItemDB.stock("gear", 12, "test").filter(func(id): return id in found).is_empty(), "no shop sells the shack's gear")
	var speed := GameState.gear_fx("speed")
	await Menus.use_bag_item("worn_cap")
	await Menus.use_bag_item("old_sneakers")
	_check(GameState.gear["head"] == "worn_cap" and GameState.gear["feet"] == "old_sneakers"
		and GameState.gear_fx("speed") > speed and GameState.gear_fx("egg") > 0.0, "the cap and sneakers can be put on")
	await main._go("caccoon", step)
	await main._go(shack["interior"], "entry")
	await main._settle(shack["interior"])
	_check(main.world.items.is_empty(), "the gear stays picked up after leaving and coming back")
	return false


func _enter(main, building: Dictionary) -> void:
	if UI.is_touch():
		await main._wait(0.35)
		var aim: Vector3 = main.world.tile_pos(building["door"])+Vector3(0,0.9,0)
		if building.has("cove_plan"):
			# Tap the visible leaf, including a shop set back behind its porch.
			var origin := Vector3(building["x"]+building["w"]/2.0,main.world._lift(building["door"]),building["y"]+building["d"]/2.0)
			aim = origin+building["cove_plan"]["door_at"]
		var pixel: Vector2 = main.world.cam.unproject_position(aim)
		var at: Vector2 = pixel*main.get_viewport().get_visible_rect().size/Vector2(main.view.size)
		await main._tap_at(at)
	else:
		await main.world._interact()


func _preview(main, opts: Dictionary) -> bool:
	var name: String = opts.get("preview","")
	if opts.has("window_title"):
		main.get_window().title = String(opts["window_title"])
	var spots := {"square":Vector2i(27,22),"library":Vector2i(22,21),"neighbor":Vector2i(8,21),"home":Vector2i(9,10),"docks":Vector2i(40,38),"gear":main.world.map["buildings"][6]["door"]+Vector2i.DOWN,"apothecary":Vector2i(47,22),"apothecary-wide":Vector2i(47,22)}
	if name != "overview" and not spots.has(name):
		return false
	if name == "overview":
		main.world.cam_free = true
		main.world.cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		main.world.cam.size = 43
		main.world.cam.position = Vector3(27,41,67)
		main.world.cam.look_at(Vector3(27,1,22))
		UI.hud.hide()
	else:
		main.world.spawn_at(spots[name])
		main.world.facing = Vector2i.UP
		if name == "apothecary-wide":
			# The normal following view crops the roof. Keep its angle, but
			# frame the whole facade for the rooftop-room regression capture.
			main.world.cam_free = true
			var aim: Vector3 = main.world.tile_pos(main.world.map["buildings"][2]["door"])+Vector3(0,2.0,-1.3)
			var target := aim+Vector3(0,main.world.CAM_LOOK_Y,0)
			main.world.cam.position = target+(main.world.CAM_OFFSET-Vector3(0,main.world.CAM_LOOK_Y,0))*1.28
			main.world.cam.look_at(target)
	await _shot(main,opts)
	return true


func _shot(main, opts: Dictionary) -> void:
	await main._wait(float(opts.get("wait", "2")))
	if opts.has("shot"):
		await RenderingServer.frame_post_draw
		main._save_shot(String(opts["shot"]))


## The ground the user asked for (2026-11-10): no lawn that looks open but can't be walked on, gentle levels and short
## ramps, a tall rim of cliffs round the cove (on the east above the road, not water), and a path to every door.
func _cove_ground(town: Dictionary) -> void:
	var solid_lawn := []
	for y in town["h"]:
		for x in town["w"]:
			var p := Vector2i(x, y)
			# a hedge is drawn only along its edges (world.gd _hedge_lines): its inside would look like lawn
			if MapGen.get_t(town, x, y) == MapGen.BUSH and [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN].all(
					func(d): return MapGen.get_t(town, x + d.x, y + d.y) == MapGen.BUSH):
				solid_lawn.append(p)
			if MapGen.get_t(town, x, y) == MapGen.BUSH and MapGen.get_t(town, x + 1, y) == MapGen.BUSH 					and MapGen.get_t(town, x, y + 1) == MapGen.BUSH and MapGen.get_t(town, x + 1, y + 1) == MapGen.BUSH:
				solid_lawn.append(p)
	_check(solid_lawn.is_empty(), "no hedge is thick enough to leave dark lawn nobody can walk on: %s" % str(solid_lawn))
	var long_ramps := []
	var steps := {}
	for y in town["h"]:
		for x in town["w"]:
			var p := Vector2i(x, y)
			var d := Elev.ramp_dir(town, p)
			if d == Vector2i.ZERO or Elev.ramp_dir(town, p - d) == d:
				continue
			var n := 0
			while Elev.ramp_dir(town, p + d * n) == d:
				n += 1
			if n > 3:
				long_ramps.append(p)
			steps[roundi(absf(Elev.surface(town, p + d * n) - Elev.surface(town, p - d)))] = true
	_check(long_ramps.is_empty() and steps.keys().all(func(k): return k == 1), "every ramp climbs one level in at most three tiles: %s" % str(long_ramps))
	var road := Elev.surface(town, Vector2i(47, 21))
	var rim := [Vector2i(52, 8), Vector2i(52, 18), Vector2i(1, 10), Vector2i(1, 24), Vector2i(26, 1)]
	_check(rim.all(func(p): return Elev.surface(town, p) - road >= 4.0 and MapGen.get_t(town, p.x, p.y) != MapGen.WATER),
		"a tall cliff rings the cove, on the east above the road instead of water")
	var pathless := []
	var doors := []
	for b in town["buildings"]:
		doors.append(b["door"])
	for entry in town.get("scenery_houses", []):
		var dx := float(entry.get("cove_door_dx", 0.0))
		doors.append(Vector2i(floori(float(entry["x"]) + float(entry["w"]) / 2.0 + dx), int(entry["y"]) + int(entry["d"]) - 1))
	for door in doors:
		var step: Vector2i = door + Vector2i.DOWN
		if not MapGen.get_t(town, step.x, step.y) in [MapGen.PATH, MapGen.PLAZA, MapGen.BRIDGE]:
			pathless.append(door)
	_check(pathless.is_empty(), "a path leads up to every house's door: %s" % str(pathless))


func _check(ok: bool, label: String) -> void:
	print("ok   " if ok else "FAIL ", label)
	if not ok:
		bad += 1
