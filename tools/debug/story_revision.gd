extends RefCounted
const Beasts = preload("res://scripts/core/beasts.gd")
const Maps = preload("res://scripts/world/map_loader.gd")
const Grid = preload("res://scripts/world/map_gen.gd")
const Jail = preload("res://scripts/story/prison_escape.gd")
const Family = preload("res://scripts/story/family_film.gd")
const ItemDB = preload("res://scripts/data/item_db.gd")
var bad := 0
class BattleStub extends Node:
	var _test := {"save_dir": "res://build/story_revision_stub/"}
	var world = null
	var outcome := "win"
	func start_battle(_cfg: Dictionary) -> String:
		await get_tree().process_frame
		return outcome
	func reload_map() -> void:
		await get_tree().process_frame

func run(main, opts: Dictionary) -> void:
	if opts.has("films"):
		await _films(main)
		print("STORY FILMS DONE: %d problem(s)" % bad)
		return
	if opts.has("preview"):
		await _preview(main, opts)
		return
	UI.auto = true
	GameState.new_game("Story tester")
	var clue: int = GameState.nightmare_tool()
	_check(clue >= 0 and clue < 3, "new journey chooses a valid clue")
	_check(GameState.save_game(0), "save clue in isolated journey")
	GameState.flags["nightmare_tool"] = (clue + 1) % 3
	_check(GameState.load_game(0) and GameState.nightmare_tool() == clue, "reload retains the clue")
	GameState.flags.erase("nightmare_tool")
	var old: int = GameState.nightmare_tool()
	GameState.flags.erase("nightmare_tool")
	_check(GameState.nightmare_tool() == old, "legacy clue does not reroll")
	var legacy_cave := Maps.interior_of("route6", "hideout")
	var new_cave := Maps.interior_of("dustwell", "hideout")
	GameState.map_id = legacy_cave
	GameState.pos = Vector2i(3, 3)
	GameState.set_flag("mole_defeated_2")
	GameState.set_flag("chest_%s_2" % legacy_cave)
	_check(GameState.save_game(9) and GameState.load_game(9) and GameState.map_id == new_cave and GameState.pos == Vector2i(-1, -1),
		"old cave saves arrive at the well entrance")
	_check(GameState.flag("beaver_defeated_2") and GameState.flag("chest_%s_2" % new_cave), "old cave victories and claimed chests migrate")
	GameState.map_id = "dustwell"
	GameState.set_flag("chest_%s_4" % legacy_cave)
	_check(GameState.save_game(9) and GameState.load_game(9) and GameState.map_id == "dustwell"
		and GameState.flag("chest_%s_4" % new_cave), "claimed cave treasure migrates for a player saved elsewhere")
	var town := Maps.load_map("dustwell", {})
	var cave_id := ""
	for building in town["buildings"]:
		if building.get("rooms", []).has("well_main") and building.get("well", false):
			cave_id = building["interior"]
	_check(cave_id != "", "Dustwell's well leads to its great chamber")
	var cave := Maps.load_map(cave_id, {})
	_check(cave["room_key"] == "well_main" and cave["chests"].size() == 3 and cave["chests"].all(func(ch): return ch["hidden_until"] == ""),
		"the great chamber's three chests are there from the start")
	_check(cave["encounter"].get("ghosts", 1.0) == 0.0 and cave["encounter"]["roam"], "ordinary wild beasts inhabit the well")
	var stub := BattleStub.new()
	main.add_child(stub)
	GameState.main = stub
	GameState.party = [Beasts.create(0, 60)]
	var fake_world := Node.new()
	fake_world.set_script(load("res://tools/debug/story_revision_world.gd"))
	main.add_child(fake_world)
	# (elemental spells never use the flute: a hero without one, or the temple's song, still learns Water)
	GameState.gear["flute"] = ""
	GameState.songs.erase("song_tides")
	GameState.inventory.erase("water_stone")
	await Story._dale(fake_world, {"name": "Dale"})
	_check(GameState.flag("dale_met") and GameState.flag("well_restored") and GameState.flag("dale_heard"), "Dale's own spell restores the well in one talk")
	_check(GameState.has_stone("water") and GameState.flag("learned_water"), "Dale hands over a water stone and teaches Water, with no flute")
	_check(GameState.flag("well_bridge_4"), "Dale lowers the bridge to his chest")
	var rooms_src := FileAccess.get_file_as_string("res://scripts/data/maps/interior_maps.gd")
	_check(rooms_src.contains("\"chest:wellspring_pendant#0\"") and not rooms_src.contains("chest:water_stone")
		and ItemDB.get_item("wellspring_pendant").get("kind", "") == "tgear"
		and ItemDB.get_item("wellspring_pendant")["fx"].get("spell_water", 0.0) > 0.0, "Dale's chest holds the Wellspring Pendant, which strengthens water attacks")
	var hall := Maps.load_map(Maps.interior_of("reef", "temple"), {"tides_falls_solved": true, "tides_maze_solved": true})
	var panel: Dictionary = {}
	for n in Story.extra_npcs(hall):
		if n.get("target", "") == "water_panel":
			panel = n
		if n.has("scene"):
			n["scene"].free()
	_check(hall["room_key"] == "temple_tides_hall" and not panel.is_empty(), "the temple's great hall keeps its Water target")
	if not panel.is_empty():
		UI.auto_answers = [1]
		await Story._water_target(fake_world, panel)
		_check(not GameState.flag("water_mages_found"), "declining the spell leaves the panel shut")
		UI.auto_answers = [0]
		await Story._water_target(fake_world, panel)
	_check(GameState.flag("water_mages_found"), "Water opens the temple panel")
	var stone := Vector2i(0, 10)
	_check(not hall["exits"].has(stone) and hall["stone_doors"].has(stone), "the closed panel is a stone door flush in the wall, with no passage")
	var opened := Maps.load_map(hall["id"], {"tides_falls_solved": true, "tides_maze_solved": true, "water_mages_found": true})
	var sanctuary := Maps.load_map(opened["exits"][stone]["to"], GameState.flags)
	_check(sanctuary["room_key"] == "temple_tides_sanctuary" and sanctuary["exits"].values()[0]["to"] == hall["id"], "the sanctuary doorway leads back to the great hall")
	var teacher := false
	for n in Story.extra_npcs(sanctuary):
		if n.get("id", "") == "water_teacher":
			teacher = true
			await Story._water_teacher(n["name"])
		if n.has("scene"):
			n["scene"].free()
	_check(teacher and GameState.learned_spell("torrent"), "the teacher appears after the panel opens and teaches Torrent")
	GameState.main = main
	for tool in 3:
		GameState.flags["nightmare_tool"] = tool
		GameState.flags.erase("jail_escaped")
		UI.auto_answers = [1, 0, (tool + 1) % 3, 0, tool]
		UI.auto_flute = [{"acc": 0.0, "mistakes": 3, "cancelled": false}]
		var jail := Jail.new()
		UI.push(jail)
		var jail_ref: WeakRef = weakref(jail)
		await _until(main, func(): return jail_ref.get_ref() == null or jail_ref.get_ref().closed)
		_check(GameState.flag("jail_escape_tool"), "tool route works after a wrong answer: %d" % tool)
		await main.get_tree().process_frame
	var march = load("res://scripts/ui/flute_game.gd").new().setup("dread", "", 0.0, {"mode": "play", "level": 5, "dirt_sheet": true, "melody": Jail.MARCH, "time_limit": 18.0})
	UI.push(march)
	march.phase = "play"
	for note in Jail.MARCH:
		for button in note:
			march._press(button)
	_check(march.accuracy() > 0.0 and march.pos == Jail.MARCH.size(), "custom duck melody can actually be completed")
	march.close(march._result())
	await main.get_tree().process_frame
	GameState.flags.erase("jail_escaped")
	UI.auto_answers = [1]
	UI.auto_flute = [{"acc": 1.0, "mistakes": 0, "cancelled": false}]
	var jail := Jail.new()
	UI.push(jail)
	await _until(main, func(): return jail.mode == "duck")
	_check(jail.mode == "duck", "successful song grants duck control")
	_check(not jail.move_duck(Vector2i(1, -1)), "duck rejects diagonal movement")
	var path := [Vector2i.DOWN, Vector2i.DOWN, Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.UP, Vector2i.UP, Vector2i.UP]
	for direction in path:
		_check(jail.move_duck(direction), "duck traverses the route")
	_check(jail.duck_tile == Jail.LOCK, "duck reaches the lock")
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	jail.on_input(event)
	var jail_ref: WeakRef = weakref(jail)
	await _until(main, func(): return jail_ref.get_ref() == null or jail_ref.get_ref().closed)
	_check(GameState.flag("jail_escape_duck"), "A unlocks the cell through duck route")
	await main.get_tree().process_frame
	GameState.main = stub
	GameState.flags.erase("game_cleared")
	GameState.set_flag("trainers_freed")
	await Story._shutdown(fake_world, 2)
	_check(not GameState.flag("reactor_shutdown_2"), "reactors gated behind scientist battle")
	stub.outcome = "lose"
	await Story._finale(fake_world, {})
	_check(not GameState.flag("vexmora_defeated"), "loss cannot clear scientist")
	stub.outcome = "win"
	UI.auto_log.clear()
	await Story._finale(fake_world, {})
	_check(GameState.flag("reactors_safe") and GameState.flag("game_cleared"), "winning and shutdown complete the ending")
	_check(GameState.flag("mom_fought_goons") and GameState.flag("narrative_revision_complete"), "family scenes complete")
	var transcript := "\n".join(UI.auto_log)
	_check(transcript.find("We're safe") < transcript.find("Will you play spaceships"), "catastrophe contained before spaceships")
	GameState.main = main
	stub.queue_free()
	fake_world.queue_free()
	UI.auto = false
	print("STORY REVISION DONE: %d problem(s)" % bad)

func _until(main, predicate: Callable) -> void:
	var until := Time.get_ticks_msec() + 15000
	while not predicate.call() and Time.get_ticks_msec() < until:
		await main.get_tree().process_frame
	_check(predicate.call(), "asynchronous flow finishes")

func _reachable(map: Dictionary, start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var queue := [start]
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var q: Vector2i = p + d
			if not seen.has(q) and Grid.walkable(Grid.get_t(map, q.x, q.y)):
				seen[q] = true
				queue.append(q)
	return seen

func _check(ok: bool, label: String) -> void:
	if not ok:
		bad += 1
		print("FAIL ", label)

func _preview(main, opts: Dictionary) -> void:
	UI.auto = false
	var kind := String(opts["preview"])
	if kind in ["cave", "reactors"]:
		GameState.set_flag("vexmora_defeated")
		GameState.set_flag("nyx_defeated")
		GameState.set_flag("trainers_freed")
		var place := Maps.interior_of("dustwell", "hideout") if kind == "cave" else Maps.interior_of("gravenmoor", "cathedral") + "@3"
		await main._do_goto(place, "entry" if kind == "cave" else "start")
		main.world.demo = true
		main.world.cam_free = true
		var focus: Vector3 = main.world.tile_pos(Vector2i(12, 8) if kind == "cave" else Vector2i(9, 5))
		main.world.cam.position = focus + Vector3(0, 9, 12)
		main.world.cam.look_at(focus)
		await main._wait(0.6)
		main._save_shot(String(opts["shot"]))
	elif kind in ["nightmare", "sleep"]:
		GameState.flags["nightmare_tool"] = int(opts.get("tool", "0"))
		var opening = main._opening(70.0 if kind == "nightmare" else 55.0, true)
		await _until(main, func(): return not opening.loading)
		await main._wait(0.5)
		main._save_shot(String(opts["shot"]))
		opening.queue_free()
		main._cinematic = null
	elif kind == "jail":
		var jail := Jail.new()
		UI.push(jail)
		await main._wait(1.0)
		main._save_shot(String(opts["shot"]))
	elif kind == "notation":
		var g = load("res://scripts/ui/flute_game.gd").new().setup("dread", "Composed in the dirt · Some symbols are incomplete", 0.0, {"mode": "play", "level": 5, "dirt_sheet": true, "melody": Jail.MARCH, "time_limit": 18.0})
		UI.push(g)
		g.set_process(false)
		await main._wait(0.5)
		main._save_shot(String(opts["shot"]))
	else:
		var film := Family.new()
		film.chapter = kind
		UI.push(film)
		await _until(main, func(): return film.ready_scene)
		film.beat = int(opts.get("beat", "0"))
		film._show()
		film.dialogue.instant_text = true
		await main._wait(0.6)
		film.dialogue.text_label.visible_characters = -1
		await RenderingServer.frame_post_draw
		main._save_shot(String(opts["shot"]))
	UI.clear_all()
	await main.get_tree().process_frame

func _films(main) -> void:
	UI.auto = false
	for chapter in Family.LINES:
		var film := Family.new()
		film.chapter = chapter
		UI.push(film)
		await _until(main, func(): return film.ready_scene)
		_check(UI.controls.film_mode, "film keeps its on-screen controls")
		for beat in Family.LINES[chapter].size():
			film.beat = beat
			film._show()
			for frame in 4:
				await main.get_tree().process_frame
			_check(film.dialogue.lines.size() == 1, "%s beat %d fits one speech page" % [chapter, beat])
		film._next()
		_check(film.closed, "last beat completes film")
		await main.get_tree().process_frame
		_check(not UI.controls.film_mode, "completing restores normal controls")
	var film := Family.new()
	UI.push(film)
	await _until(main, func(): return film.ready_scene)
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	film.on_input(cancel)
	film._process(1.1)
	_check(film.closed, "hold B skips the film")
	await main.get_tree().process_frame
	_check(not UI.controls.film_mode and UI.allow_pause, "skipping restores controls and pause")
