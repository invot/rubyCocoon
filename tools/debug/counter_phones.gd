extends RefCounted
## Service phones: real tap/confirm dispatch, representative room captures, no player saves.
const ML = preload("res://scripts/world/map_loader.gd")
const DB = preload("res://scripts/data/world_db.gd")
var bad := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		bad += 1
		print("FAIL ", label)

func run(main, opts: Dictionary) -> void:
	UI.auto = true
	GameState.set_flag("intro_done")
	GameState.set_flag("called_dad")
	var representatives := {}
	var instances := 0
	for town in DB.TOWNS:
		for b in ML.load_map(town, {})["buildings"]:
			var rooms := ML.room_set(b)
			for f in rooms.size():
				var id := ML.floor_id(b["interior"], f + 1)
				var m := ML.load_map(id, {})
				if (b["shop"] in ["house", "home", "uncle"] and not b.get("hotel", false)) or rooms[f] == "hotel_suite":
					continue
				check(not m.get("furniture", {}).values().has("phone"), "service phone still on a table: " + id)
				if not m.has("counter_phone"):
					continue
				instances += 1
				var phone: Vector2i = m["counter_phone"]
				check(ML.MapGen.get_t(m, phone.x, phone.y) == ML.MapGen.COUNTER, "phone needs a counter: " + id)
				var key: String = ("kelpwick_" if town == "kelpwick" else "") + rooms[f]
				representatives[key] = id
	var directory := String(opts.get("shots", "res://build/shots/counter_phones"))
	DirAccess.make_dir_recursive_absolute(directory)
	for key in representatives:
		main._load_world(representatives[key], "entry")
		var world = main.world
		for n in world.map["npcs"]:
			n["roam"] = false
			n["wander"] = false
		var phone: Vector2i = world.map["counter_phone"]
		# Walk the real route from the entrance to the customer side.
		await main._walk_test([phone + Vector2i(0, 2)])
		await main._wait(0.5)
		await RenderingServer.frame_post_draw
		main._save_shot(directory + "/" + key + ".png")
		await main._walk_test([phone + Vector2i.DOWN])
		check(world.player_pos == phone + Vector2i.DOWN, "customer approach: " + key)
		world.facing = Vector2i.UP
		load("res://scripts/gfx/voxel_person.gd").face(world.player, world.facing)
		await main._wait(0.5)
		await RenderingServer.frame_post_draw
		UI.auto_log.clear()
		UI.auto_answers = [-1]
		await main._press("interact")
		await main._wait(0.2)
		check(UI.auto_log.any(func(line): return "Who will you call?" in String(line)), "confirm opens phone instead of attendant: " + key)
		UI.auto_log.clear()
		UI.auto_answers = [-1]
		var at: Vector2 = world.cam.unproject_position(world.tile_pos(phone) + Vector3(0, 1.2, 0))
		check(world._pick(at).get("tile", Vector2i(-1, -1)) == phone, "raised phone tap bounds: " + key)
		for down in [true, false]:
			var event := InputEventScreenTouch.new()
			event.index = 0
			event.position = at
			event.pressed = down
			Input.parse_input_event(event)
			await main.get_tree().process_frame
		await main._wait(0.4)
		check(UI.auto_log.any(func(line): return "Who will you call?" in String(line)), "tap opens phone: " + key)
	print("COUNTER PHONES DONE: %d problem(s), %d instances, %d layouts" % [bad, instances, representatives.size()])
