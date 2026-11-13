extends RefCounted
## The top bar outside battle (scripts/ui/top_bar.gd): several pickups in quick succession merge ("Potion x3"), gold
## adds up, a place name waits its turn, each message slides in, holds and leaves, and the bar is hidden afterwards.
## --scene=top-bar [--gem=sapphire] [--touch] [--shots=res://build/shots/top_bar]  (shots: _pickup, _gold, _place)
## [--banners=1]: afterwards shows every town's and road's name over its banner picture (shots: _banner_<map>), and a
## pattern for several kinds of building (_room_<kind>). Last, it walks into a house and a café (_walk_in_house, _walk_in_cafe).

const WorldDB = preload("res://scripts/data/world_db.gd")
const MapLoader = preload("res://scripts/world/map_loader.gd")
const MapGen = preload("res://scripts/world/map_gen.gd")

var bad := 0


func _check(ok: bool, label: String) -> void:
	if not ok:
		bad += 1
	print("%s %s" % ["ok  " if ok else "FAIL", label])


func run(main: Node) -> void:
	await main._do_goto(String(main._test.get("map", "tidewater")), "center")
	await main._wait(1.5)
	var tb = UI.top_bar
	var shots := String(main._test.get("shots", ""))
	var capture := func(label: String) -> void:
		if shots == "":
			return
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shots.get_base_dir()))
		main._save_shot(shots + "_" + label + ".png")
	# (whatever the arrival announced is let go first)
	var t := 0.0
	while tb.visible and t < 12.0:
		await main._wait(0.1)
		t += 0.1
	_check(not tb.visible and tb.pending() == 0, "the bar is hidden while there is nothing to say")

	for i in 3:
		GameState.add_item("potion")
		UI.pickup("potion")
		await main._wait(0.15)
	UI.gold(50)
	UI.gold(70)
	UI.place_name("Tidewater", "Market Row")
	await main._wait(0.5)
	_check(tb.visible and tb.current_text() == "Potion x3", "three quick pickups merge into one message (%s)" % tb.current_text())
	_check(tb.left_icon.visible and tb.left_icon.texture != null and not tb.right_icon.visible, "a pickup has its item's icon on the left and no right icon")
	_check(tb.pending() == 3, "gold and the place name wait their turn (%d showing or waiting)" % tb.pending())
	var r: Rect2 = tb.get_global_rect()
	var vp: Rect2 = tb.get_viewport_rect()
	_check(r.position.y >= 0.0 and r.end.x <= vp.size.x and r.position.x >= 0.0, "the bar sits on screen at the top")
	_check(absf(r.get_center().x - vp.size.x * 0.5) <= 2.0, "the bar is centred")
	_check(tb.size_name == "small" and absf(tb.size.x - float(tb.SIZES["small"][0])) <= 1.0, "a short pickup takes the small size (%s, %d wide)" % [tb.size_name, int(tb.size.x)])
	await capture.call("pickup")

	await _until(main, tb, "+120 gold")
	_check(tb.current_text() == "+120 gold", "gold received together adds up (%s)" % tb.current_text())
	await main._wait(0.4)
	await capture.call("gold")

	await _until(main, tb, "Tidewater")
	_check(tb.current_text() == "Tidewater" and tb.sub_label.visible and tb.sub_label.text == "Market Row", "the place name follows, with its second line")
	_check(tb.size_name == "large", "a place name with its second line takes the large (two-line) size (%s)" % tb.size_name)
	_check(not tb.left_icon.visible and not tb.right_icon.visible, "a place name has no icon")
	_check(tb._backdrop != null and tb._backdrop.diffuse_texture == UI.place_banner(GameState.map_id), "a place name shows its place's picture behind it")
	await main._wait(0.4)
	await capture.call("place")

	# a long notice wraps instead of running off the screen
	UI.toast("A very long notice that keeps going and going, to see that the top bar wraps onto a second line rather than growing past its widest", "notice")
	await _until(main, tb, "A very long")
	await main._wait(0.4)
	_check(tb.size.x <= tb.MAX_W + 1.0 and tb.label.get_line_count() == 2 and tb.size_name == "large", "a long notice wraps to the large size's two lines (%d wide, %d lines, %s)" % [int(tb.size.x), tb.label.get_line_count(), tb.size_name])
	await capture.call("long")
	# one too long even for two lines is split into pages, each fitting the large size
	UI.toast("This notice is far too long for the top bar's largest size, so it has to be split into pages that show one after another, each of them fitting the two lines the large size has room for, and never shrinking its text", "notice")
	await _until(main, tb, "This notice")
	await main._wait(0.4)
	_check(tb._pages.size() >= 2 and tb.label.get_line_count() <= 2 and tb.size_name == "large", "an overlong notice pages (%d pages, %d lines)" % [tb._pages.size(), tb.label.get_line_count()])
	await capture.call("paged")

	t = 0.0
	while tb.visible and t < 20.0:
		await main._wait(0.1)
		t += 0.1
	_check(not tb.visible and tb.pending() == 0, "the bar slides away once everything has been said")
	_check(tb._backdrop == null, "the picture leaves with the place name")

	# every town and road has a picture; a room uses its town's
	var places: Array = WorldDB.TOWN_ORDER.duplicate() + WorldDB.ROUTES.keys()
	var missing := places.filter(func(id): return UI.place_banner(id) == null)
	_check(missing.is_empty(), "every town and road has a banner picture (missing: %s)" % ", ".join(missing))
	# inside, a building shows its kind's pattern in colours it keeps (the same on every floor, and on every visit)
	_check(UI.place_banner("tidewater#3", "center").resource_path.contains("/rooms/arches_"), "a Beast Center shows the arches pattern")
	_check(UI.place_banner("tidewater#3@2", "center") == UI.place_banner("tidewater#3", "center"), "every floor of a building has its colours")
	var kinds := {}
	for k in UI.ROOM_PATTERNS:
		kinds[k] = UI.place_banner("tidewater#%d" % kinds.size(), k) != null
	_check(not kinds.values().has(false) and UI.place_banner("tidewater#0", "no_such_kind") != null, "every kind of building, and any other, has a pattern")
	var ways := {}
	for i in 24:
		ways[UI.place_banner("riverbend#%d" % i, "house").resource_path] = true
	_check(ways.size() >= 5, "neighbouring houses get different colours (%d colourways among 24)" % ways.size())
	# no building anywhere has a vague name ("House", "Apothecary"); the chains (Beast Center, Sky Tower) keep theirs
	var vague := []
	for id in places:
		for b in MapLoader.load_map(id, {}).get("buildings", []):
			if b["shop"] in ["center", "skytower", "decor", "music_shop"]:
				continue
			if String(b["name"]) == String(MapGen.SHOP_NAMES.get(b["shop"], "")) or b["name"] in ["Kennel Barn", "Fishery"]:
				vague.append("%s %s" % [id, b["name"]])
	_check(vague.is_empty(), "every building has a name of its own (vague: %s)" % ", ".join(vague))
	if String(main._test.get("banners", "")) == "1":
		for id in places:
			tb.post(WorldDB.map_name(id), null, {"sub": "Banner preview", "heading": true, "key": "place", "replace": true,
				"priority": true, "backdrop": UI.place_banner(id)})
			await main._wait(0.3)
			await capture.call("banner_" + id)
		var i := 0
		for k in ["house", "cafe", "fishery", "electronics", "bookstore", "center", "apothecary", "arena", "kennel"]:
			tb.post(k.capitalize(), null, {"sub": "Bellerive", "heading": true, "key": "place", "replace": true,
				"priority": true, "backdrop": UI.place_banner("tidewater#%d" % i, k)})
			i += 3
			await main._wait(0.3)
			await capture.call("room_" + k)

	# walking into a house from outside shows its name over its pattern (homes too, these days)
	tb._queue.clear()
	var house := {}
	for bd in main.world.map.get("buildings", []):
		if String(bd.get("shop", "")) == "house" and not Places.door_locked(bd):
			house = bd
			break
	_check(not house.is_empty(), "the town has a house to walk into")
	if not house.is_empty():
		await main._do_goto(String(house["interior"]), "entry")
		await main._wait(0.6)
		_check(tb.visible and tb.current_text() == String(main.world.map["name"]), "a house shows its name on walking in (%s)" % tb.current_text())
		_check(tb._backdrop != null and tb._backdrop.diffuse_texture == UI.place_banner(GameState.map_id, "house"), "...over its own pattern")
		var owner := String(main.world.map["building"].get("owner", ""))
		_check(owner != "" and tb.current_text().begins_with(owner + "'s ") and tb.current_text() != "House", "a house is named for its owner (%s)" % tb.current_text())
		_check((main.world.map["npcs"] as Array).any(func(n): return String(n.get("name", "")) == owner), "...who is home")
		_check(tb.sub_label.text == "Bellerive", "a building's second line is just its town (%s)" % tb.sub_label.text)
		await capture.call("walk_in_house")
	# ...and a shop has a name of its own, never a bare "Café"
	tb._queue.clear()
	await main._do_goto(MapLoader.interior_of("tidewater", "cafe"), "entry")
	await main._wait(0.6)
	_check(tb.visible and tb.current_text() == "Café du Port", "a shop has its own name (%s)" % tb.current_text())
	await capture.call("walk_in_cafe")
	print("TOP BAR DONE: %d problem(s)" % bad)


func _until(main: Node, tb, prefix: String) -> void:
	var t := 0.0
	while not (tb.visible and tb.current_text().begins_with(prefix) and tb._phase == "hold") and t < 15.0:
		await main._wait(0.1)
		t += 0.1
