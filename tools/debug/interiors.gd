extends RefCounted
## Every distinct furnished room through the real world renderer, with fresh test state.
## --scene=interiors --shots=res://build/shots/interiors [--rooms=home,studio_a]

const MapLoader = preload("res://scripts/world/map_loader.gd")
const WorldDB = preload("res://scripts/data/world_db.gd")
const InteriorMaps = preload("res://scripts/data/maps/interior_maps.gd")


func run(main, opts: Dictionary) -> void:
	UI.auto = true
	main.autoplay = true
	# Include the earth temple, which only exists after the jungle ritual.
	GameState.set_flag("ritual_done")
	var representatives := {}
	var instances := 0
	for id in WorldDB.TOWNS.keys() + WorldDB.ROUTES.keys():
		var town := MapLoader.load_map(id, GameState.flags)
		for b in town["buildings"]:
			var rooms := MapLoader.room_set(b)
			for f in rooms.size():
				instances += 1
				if not representatives.has(rooms[f]):
					representatives[rooms[f]] = MapLoader.floor_id(b["interior"], f + 1)
	var wanted := String(opts.get("rooms", "")).split(",", false)
	var directory := String(opts.get("shots", "res://build/shots/interiors"))
	DirAccess.make_dir_recursive_absolute(directory)
	var captured := 0
	for key in InteriorMaps.ROOMS:
		if not wanted.is_empty() and not key in wanted:
			continue
		if not representatives.has(key):
			push_error("No built instance of interior template " + key)
			continue
		# Build the real map and spawn without on-enter story events (Rory's lesson, bosses).
		main._load_world(representatives[key], "entry")
		main.world.frozen = true
		for n in main.world.map["npcs"]:
			n["roam"] = false
			n["wander"] = false
		# Optional survey of larger dungeons; normal captures keep the gameplay camera.
		if opts.get("overview", "0") == "1":
			var w: float = main.world.map["w"]
			var h: float = main.world.map["h"]
			var at := Vector3(w / 2.0, 0.0, h / 2.0)
			var pull := maxf(1.0, maxf(w / 11.0, h / 6.0))
			main.world.cam_free = true
			main.world.cam.position = at + main.world.CAM_OFFSET_ROOM * pull
			main.world.cam.look_at(at + Vector3(0, main.world.CAM_LOOK_Y, 0), Vector3.UP)
		await main._wait(float(opts.get("wait", "0.35")))
		await RenderingServer.frame_post_draw
		main._save_shot(directory + "/" + key + ".png")
		captured += 1
	print("INTERIOR TOUR DONE: %d templates, %d instances" % [captured, instances])
