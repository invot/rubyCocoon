extends RefCounted
## Stages clips for the trailer (--scene=trailer --shot=film|world|battle), recorded by tools/trailer/record.sh with
## Godot's movie writer. Fresh state only; never reads or writes player saves. The run is ended by --quit-after.
##
## --shot=film   the opening film, start to finish
## --shot=world  --map=caccoon --from=start --to=center[;plaza;12,8] [--run=1] [--crane=3] [--lead=0.5] [--flags=a+b]
##     the hero walks from one of the map's spawns (or a tile) to each goal in turn, seen by the gameplay camera;
##     --crane=seconds starts high and wide and comes down to it first.
## --shot=battle --map=route1 --party=2:40,32:40 --foes=27:10,30:11 [--trainer=Name,Class,outfit,#shirt,#pants,#hair]
##     [--summon=fire] [--intro=wild|sneak|ambush] [--seed=5] [--shield=2]
##     a battle played by itself through the real battle camera. A beast is race:level, with :g for a ghost.
##     --map also takes arena:<town> (that town's arena hall) and tower:<floor> (Gearhart Tower).

const Beasts = preload("res://scripts/core/beasts.gd")
const BattleTutorials = preload("res://scripts/core/battle_tutorials.gd")
const MapLoader = preload("res://scripts/world/map_loader.gd")
const NOWHERE := Vector2i(-999, -999)


func run(main, opts: Dictionary) -> void:
	UI.auto = false
	GameState.player_name = String(opts.get("name", "Andrew"))
	# a trainer some way into the journey: the first-time lessons and battle tips are behind them
	for f in ["intro_done", "got_egg", "has_starter", "tutorial_done", "flute_lesson_done", "dance_lesson_done",
			"dance_shoes_returned", "ring_rotation_taught", "lesson_summon", "reed_flute"]:
		GameState.set_flag(f)
	for t in Story.LESSON_TRAINERS + Story.ARENA_LESSONS:
		GameState.set_flag("lesson_" + String(t["lesson"]))
	for topic in BattleTutorials.TIPS:
		GameState.set_flag("battle_tip_" + String(topic))
	GameState.gear["flute"] = "reed_flute"
	GameState.learn_song("weaken")
	GameState.learn_song("capture3")
	for f in String(opts.get("flags", "")).split("+", false):
		GameState.set_flag(f)
	for b in _beasts(String(opts.get("party", "0:8"))):
		GameState.add_beast(b)
	GameState.fix_ring()
	match String(opts.get("shot", "world")):
		"battle":
			await _battle(main, opts)
		"film":
			# the opening film as it plays in a new game, without the controls' hints in the top-centre HUD
			UI.top_bar.modulate.a = 0.0
			var film = main._opening(0.0, false)
			await film.finished
		_:
			await _world(main, opts)
	await main.get_tree().create_timer(3600).timeout


func _beasts(list: String) -> Array:
	var out := []
	for item in list.split(",", false):
		var parts := item.split(":")
		out.append(Beasts.create(int(parts[0]), int(parts[1]) if parts.size() > 1 else 10, parts.size() > 2 and parts[2] == "g"))
	return out


func _tile(world, spot: String) -> Variant:
	if "," in spot:
		return Vector2i(int(spot.get_slice(",", 0)), int(spot.get_slice(",", 1)))
	if world != null:
		if world.map["spawns"].has(spot):
			return world.map["spawns"][spot]
		if world.map["anchors"].has(spot):
			return world.map["anchors"][spot]
	return spot


func _world(main, opts: Dictionary) -> void:
	var from := String(opts.get("from", "start"))
	await main._do_goto(String(opts.get("map", "caccoon")), _tile(null, from))
	var world = main.world
	while world == null or world.cam == null or main._transitioning:
		await main.get_tree().process_frame
		world = main.world
	var crane := float(opts.get("crane", "0"))
	if crane > 0.0:
		# down from high and wide onto the gameplay camera's own place, which then takes over
		world.cam_free = true
		var t := 0.0
		var side := float(opts.get("side", "6"))
		while t < crane:
			var s := t / crane
			s = s * s * (3.0 - 2.0 * s)
			var target: Vector3 = world.cam_target
			target.x = clampf(target.x, 7.0, maxf(7.0, world.map["w"] - 7.0))
			target.z = clampf(target.z, 4.0, maxf(4.0, world.map["h"] - 2.5))
			var off: Vector3 = (world.CAM_OFFSET * 2.3 + Vector3(side, 3.0, 0)).lerp(world.CAM_OFFSET, s)
			world.cam.position = target + off
			world.cam.look_at(target + Vector3(0, world.CAM_LOOK_Y, 0), Vector3.UP)
			await main.get_tree().process_frame
			t += main.get_process_delta_time()
		world.cam_free = false
	await main._wait(float(opts.get("lead", "0.5")))
	for goal in String(opts.get("to", "")).split(";", false):
		var tile = _tile(world, goal)
		if not tile is Vector2i:
			print("TRAILER: no spot called ", goal, " on ", world.map_id, " (spawns ", world.map["spawns"].keys(), ", anchors ", world.map["anchors"].keys(), ")")
			continue
		world._walk_to([tile], NOWHERE, opts.get("run", "0") == "1")
		for i in 2400:
			await main.get_tree().process_frame
			if main.world != world or (world._path.is_empty() and not world.moving):
				break
		if main.world != world:
			return
	print("TRAILER: walk done at ", world.player_pos)


func _battle(main, opts: Dictionary) -> void:
	var map_id := String(opts.get("map", "route1"))
	var from := String(opts.get("from", "start"))
	var arena := map_id.begins_with("arena:")
	if arena:
		map_id = MapLoader.interior_of(map_id.get_slice(":", 1), "arena")
		from = String(opts.get("from", "entry"))
	elif map_id.begins_with("tower:"):
		map_id = MapLoader.floor_id(MapLoader.interior_of("cogsworth", "ceo_tower"), int(map_id.get_slice(":", 1)))
		from = String(opts.get("from", "entry"))
	await main._do_goto(map_id, _tile(null, from))
	await main._wait(float(opts.get("lead", "0.6")))
	var cfg := {"wild": not opts.has("trainer"), "foes": _beasts(String(opts.get("foes", "27:8,30:8"))),
		"seed": int(opts.get("seed", "5")), "autoplay": true, "arena": arena}
	if opts.has("intro"):
		cfg["intro"] = String(opts.intro)
	if opts.has("trainer"):
		var t := String(opts.trainer).split(",")
		var look := {"skin": "#e8c0a0", "hair": "#3a2a20", "shirt": "#2a3a6a", "pants": "#22232e"}
		if t.size() > 2 and t[2] != "":
			look["outfit"] = t[2]
		for i in [[3, "shirt"], [4, "pants"], [5, "hair"], [6, "hat"]]:
			if t.size() > i[0] and t[i[0]] != "":
				look[i[1]] = t[i[0]]
		cfg["trainer"] = {"name": t[0], "cls": t[1].replace("_", " ") if t.size() > 1 else "Trainer", "look": look}
	var shield := int(opts.get("shield", "2"))
	GameState.max_shield = shield
	GameState.shield = shield
	if opts.has("summon"):
		GameState.summons = [String(opts.summon)]
		cfg["auto_summon"] = String(opts.summon)
	var result: String = await main.start_battle(cfg)
	print("TRAILER: battle over: ", result)
