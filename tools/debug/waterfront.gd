extends RefCounted
## Real walking and tap interactions, fresh state, without reading player saves.
var bad := 0

func run(main, opts: Dictionary) -> void:
	UI.auto = true
	GameState.set_flag("intro_done")
	await main._go("caccoon", Vector2i(29, 21))
	await _tap(main, Vector2i(29, 20))
	_check(UI.auto_log.any(func(line): return "Cocoon Cove Library. Free world maps" in String(line)), "tap reads the relocated library sign")
	await main._walk_test([Vector2i(31, 20)])
	_check(main.world.player_pos == Vector2i(31, 20), "library doorstep is clear")
	await main._go("tidewater", Vector2i(10, 25))
	for entry in main.world.map.get("street_props", []):
		var t := Vector2i(int(entry[0]), int(entry[1]))
		_check(not main.world._walkable(t), "dock cargo blocks its occupied tile at %s" % t)
		_check(main.world._walkable(t + Vector2i.DOWN) and main.world._walkable(t + Vector2i(0, 2)), "two walking rows remain clear beside cargo")
	for x in [10, 23, 44, 60]:
		await main._walk_test([Vector2i(x, 26)])
		await main._walk_test([Vector2i(x, 29)])
		_check(main.world.player_pos == Vector2i(x, 29), "descended dock stairs at x=%d" % x)
		await main._walk_test([Vector2i(x, 25)])
		_check(main.world.player_pos == Vector2i(x, 25), "ascended dock stairs at x=%d" % x)
	await main._walk_test([Vector2i(68, 36)])
	await _tap(main, Vector2i(71, 35))
	await main._settle("tidewater#12")
	_check(main.world.map_id == "tidewater#12", "tap enters the equipment shack")
	if main.world.map_id != "tidewater#12":
		print("WATERFRONT DONE: %d problem(s)" % bad)
		return
	var found: Array = main.world.map["items"].duplicate(true)
	for item in found:
		await _tap(main, item["pos"])
		_check(GameState.item_count(item["item"]) == 1, "tap collects " + item["item"])
	await main._go("tidewater", Vector2i(68, 36))
	await main._go("tidewater#12", "entry")
	_check(main.world.items.is_empty(), "collected gear stays gone on re-entry")
	UI.auto = false
	print("WATERFRONT DONE: %d problem(s)" % bad)

func _tap(main, tile: Vector2i) -> void:
	await main._wait(0.6)
	var at: Vector2 = main.world.cam.unproject_position(main.world.tile_pos(tile) + Vector3(0, 0.3, 0))
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
	await main._wait(0.8)

func _check(ok: bool, label: String) -> void:
	print("ok   " if ok else "FAIL ", label)
	if not ok:
		bad += 1
