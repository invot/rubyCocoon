extends RefCounted
## Dustwell's missing trainers, fresh state, no player saves (--scene=dustwell): arriving says nothing, the posters and
## the three searching friends stand about town, a poster reads by touch, and Deputy Rusk's escaped prisoner runs from
## the deputy's request through Slim's story, Barkeep Dusty's Card Ledger, Slim cleared and the partnership, then the
## posters and friends once the trainers are home ("DUSTWELL DONE: 0 problem(s)").
var bad := 0


func run(main, opts: Dictionary) -> void:
	UI.auto = true
	GameState.set_flag("intro_done")
	var said := UI.auto_log.size()
	await main._go("dustwell", "south")
	_check(GameState.flag("missing_trainers"), "arriving sets missing_trainers")
	_check(UI.auto_log.size() == said, "no speech on arriving")
	_check(main.world.map["buildings"].size() == 7, "seven buildings on Main Street")
	_check(_npcs(main, "poster").size() == 4, "four poster boards")
	_check(_npcs(main, "searcher").size() == 3, "three friends searching")
	_check(_npcs(main, "convict").is_empty(), "Slim hides until the deputy asks")
	# a poster reads by touch, from the road in
	var poster: Dictionary = _npcs(main, "poster").filter(func(n): return n["pos"] == Vector2i(21, 19))[0]
	await main._walk_test([Vector2i(21, 20)])
	await _tap(main, poster["pos"])
	_check(_said("MISSING: TRAINER") or _said("THREE NEW TRAINERS"), "tapping a poster reads it")
	for n in _npcs(main, "searcher"):
		await Story.talk(main.world, n)
	_check(_said("Tamsin: Orin wrote") and GameState.flag("searcher_2"), "the friends tell their stories")
	_check(not Story.npc_has_news(_npcs(main, "searcher")[0]), "a friend heard out has no more news")
	# the jail: the deputy asks for help (Yes)
	await main._go("dustwell#6", "entry")
	var deputy: Dictionary = _npcs(main, "deputy")[0] if not _npcs(main, "deputy").is_empty() else {}
	_check(not deputy.is_empty(), "Deputy Rusk is in the jail")
	_check(main.world.map["name"] == "Dustwell Jail", "the jail's name")
	if deputy.is_empty():
		_done()
		return
	_check(Story.npc_has_news(deputy), "the deputy has news")
	UI.auto_answers = [0]
	await Story.talk(main.world, deputy)
	_check(GameState.flag("convict_asked"), "agreeing sets convict_asked")
	# Slim, behind the wagon
	await main._go("dustwell", "south")
	var slim: Array = _npcs(main, "convict")
	_check(slim.size() == 1, "Slim hides behind the wagon once asked")
	if slim.is_empty():
		_done()
		return
	await Story.talk(main.world, slim[0])
	_check(GameState.flag("convict_found"), "Slim's story sets convict_found")
	# the saloon's barkeep: the ledger
	await main._go("dustwell#5", "entry")
	_check(main.world.map["name"] == "Oasis Saloon", "the saloon's name")
	_check(main.world.map["building"].get("frontier", "") == "saloon", "the saloon keeps its look")
	await Story.card_ledger()
	_check(GameState.item_count("card_ledger") == 1, "Barkeep Dusty hands over the Card Ledger")
	await Story.card_ledger()
	_check(GameState.item_count("card_ledger") == 1, "only one ledger")
	# the proof shown to the deputy: Slim cleared, the deputy asks for help (Yes)
	await main._go("dustwell#6", "entry")
	deputy = _npcs(main, "deputy")[0]
	_check(Story.npc_has_news(deputy), "the deputy wants to see the proof")
	var gold: int = GameState.gold
	UI.auto_answers = [0]
	await Story.talk(main.world, deputy)
	_check(GameState.flag("slim_cleared"), "the ledger clears Slim")
	_check(GameState.item_count("card_ledger") == 0, "the deputy keeps the ledger")
	_check(GameState.flag("deputy_partner"), "agreeing to help find the trainers")
	_check(GameState.gold == gold + 300, "the deputy pays Slim's reward")
	_check(not Story.npc_has_news(deputy), "the deputy has nothing new")
	await main._go("dustwell", "south")
	slim = _npcs(main, "convict")
	_check(slim.size() == 1 and slim[0]["facing"] == Vector2i(0, 1), "Slim stands free")
	await Story.talk(main.world, slim[0])
	_check(_said("Free as a tumbleweed"), "Slim's thanks")
	# the trainers home: FOUND on the posters, happy friends
	GameState.set_flag("trainers_freed")
	await main._go("dustwell", "south")
	await Story.talk(main.world, _npcs(main, "poster")[0])
	_check(_said("painted FOUND"), "posters say FOUND")
	await Story.talk(main.world, _npcs(main, "searcher")[0])
	_check(_said("Lio's home"), "Kip's friend is home")
	if opts.has("shot"):
		await main._go("dustwell", Vector2i(39, 18))
		await main._wait(1.0)
	_done()


func _done() -> void:
	UI.auto = false
	print("DUSTWELL DONE: %d problem(s)" % bad)


func _npcs(main, id: String) -> Array:
	return main.world.map["npcs"].filter(func(n): return n.get("id", "") == id)


func _said(text: String) -> bool:
	return UI.auto_log.any(func(line): return text in String(line))


func _check(ok: bool, what: String) -> void:
	if not ok:
		bad += 1
		print("FAIL ", what)


func _tap(main, tile: Vector2i) -> void:
	await main._wait(0.6)
	var at: Vector2 = main.world.cam.unproject_position(main.world.tile_pos(tile) + Vector3(0, 0.8, 0))
	at *= Vector2(main.get_window().size) / Vector2(main.view.size)
	for down in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.pressed = down
		event.position = at
		Input.parse_input_event(event)
		await main.get_tree().process_frame
	for i in 120:
		await main._wait(0.1)
		if not is_instance_valid(main.world) or (main.world._path.is_empty() and not main.world.moving and not main.world.busy):
			break
