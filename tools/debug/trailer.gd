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
		"play":
			await _play(main, opts)
		_:
			await _world(main, opts)
	await main.get_tree().create_timer(3600).timeout


## --shot=play --map=caccoon --from=start|x,y [--face=u|d|l|r] [--items=id:n+id:n] [--gold=n] [--battle=1 + the
##     battle options] --input=TOKENS
## Real play from key presses, for a gameplay compilation. TOKENS, comma-separated, one after another:
##   w1.5        wait 1.5 s
##   r  a  s+r   tap keys together (l r u d: arrows, a: A, s: S (B / run), m: Space (Start), p: Shift (Pause))
##   s+r@2.4     hold them for 2.4 s
##   go:12_8     walk to a tile (run:12_8 runs), by the path a tap there would take
##   cell:3      click the ring editor's cell 3 (0-7 the ring by slot, then storage); cell:go clicks the first cell
##               the beast picked up may go to, cell:p2 where party beast 2 stands, cell:store the first storage cell it may go to
##   fish        strike when the float dips, then reel steadily until the fishing's over
##   song        play the flute sheet that's up, note by note, then confirm its result
const KEYS := {"l": KEY_LEFT, "r": KEY_RIGHT, "u": KEY_UP, "d": KEY_DOWN, "a": KEY_A, "s": KEY_S, "m": KEY_SPACE, "p": KEY_SHIFT}
const NOTE_KEYS := ["l", "r", "a", "s", "u", "d"]


func _play(main, opts: Dictionary) -> void:
	for it in String(opts.get("items", "")).split("+", false):
		GameState.add_item(it.get_slice(":", 0), int(it.get_slice(":", 1)) if ":" in it else 1)
	if opts.has("gold"):
		GameState.gold = int(opts.gold)
	var face: Vector2i = {"u": Vector2i(0, -1), "d": Vector2i(0, 1), "l": Vector2i(-1, 0), "r": Vector2i(1, 0)}.get(String(opts.get("face", "")), Vector2i.ZERO)
	if opts.has("battle"):
		_battle(main, opts)
	else:
		await main._do_goto(String(opts.get("map", "caccoon")), _tile(null, String(opts.get("from", "start"))), face)
	while main._transitioning:
		await main.get_tree().process_frame
	if opts.has("dump") and main.world != null:
		print("TRAILER: at ", main.world.player_pos)
		for p in main.world.npcs:
			var n = main.world.npcs[p]
			print("TRAILER: npc ", p, " ", n.get("name", "") if n is Dictionary else n)
		print("TRAILER: obstacles ", main.world.map["obstacles"].keys())
		print("TRAILER: fish ", main.world.map.get("fish_spots", []))
	for tok in String(opts.get("input", "")).split(",", false):
		if tok.begins_with("w"):
			await main._wait(float(tok.substr(1)))
		elif tok == "song":
			await _song(main)
		elif tok == "probe":
			var wd = main.world
			print("TRAILER: probe ", wd.map_id, " at ", wd.player_pos, " facing ", wd.facing, " cam ", wd.cam.global_position, " map ", wd.map["w"], "x", wd.map["h"])
		elif tok == "focus":
			var f = main.get_viewport().gui_get_focus_owner()
			print("TRAILER: focus ", f, " ", f.get("dest") if f != null else "", " ", f.get_global_rect() if f != null else "", " top ", UI.stack.back().get_script().resource_path.get_file() if not UI.stack.is_empty() else "")
		elif tok.begins_with("cell:"):
			await _cell(main, tok.get_slice(":", 1))
		elif tok == "fish":
			await _fish(main)
		elif tok.begins_with("go:") or tok.begins_with("run:"):
			# walk (or run) a found path to a tile, as tapping it would
			var world = main.world
			var spot := tok.get_slice(":", 1).replace("_", ",")
			world._walk_to([_tile(world, spot)], NOWHERE, tok.begins_with("run:"))
			for i in 2400:
				await main.get_tree().process_frame
				if main.world != world or (world._path.is_empty() and not world.moving):
					break
		else:
			var hold := 0.07
			if "@" in tok:
				hold = float(tok.get_slice("@", 1))
				tok = tok.get_slice("@", 0)
			await _keys(main, tok.split("+"), hold)
	print("TRAILER: input done")


func _keys(main, names: Array, hold: float) -> void:
	for n in names:
		_key(KEYS.get(n, KEY_A), true)
	await main._wait(hold)
	for n in names:
		_key(KEYS.get(n, KEY_A), false)
	await main.get_tree().process_frame


func _key(code: int, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)


## Plays the flute sheet on screen as a player would: a short look at it, then each note on the song's beat.
func _song(main) -> void:
	var game = null
	for i in 600:
		for m in UI.stack:
			if m.get_script() != null and String(m.get_script().resource_path).ends_with("flute_game.gd"):
				game = m
		if game != null and game.phase in ["study", "play"]:
			break
		await main.get_tree().process_frame
	if game == null:
		print("TRAILER: no flute sheet up")
		return
	await main._wait(0.9)
	for note in game.melody:
		var names := []
		for b in note:
			names.append(NOTE_KEYS[int(b)])
		await _keys(main, names, 0.12)
		await main._wait(game._spb * 0.6)
	await main._wait(1.6)
	await _keys(main, ["a"], 0.07)


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
		"seed": int(opts.get("seed", "5")), "autoplay": opts.get("auto", "1") == "1", "arena": arena}
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


## Fishing as a player does it: wait for the float to dip, strike, then tap to keep the line in the bright zone.
func _fish(main) -> void:
	var seen := false
	for i in 60 * 40:
		var g = UI.stack.back() if not UI.stack.is_empty() else null
		var fishing: bool = g != null and g.get("tension") != null
		if not fishing:
			if seen:
				return
			await main.get_tree().process_frame
			continue
		seen = true
		match String(g.phase):
			"nibble":
				await main._wait(0.25)
				await _keys(main, ["a"], 0.06)
			"reel":
				var z: Vector2 = g._zone()
				if float(g.tension) < (z.x + z.y) / 2.0:
					await _keys(main, ["a"], 0.05)
					await main._wait(0.17)
				else:
					await main.get_tree().process_frame
			_:
				await main.get_tree().process_frame


## A click on one of the ring editor's cells, as a mouse player arranges their beasts.
func _cell(main, which: String) -> void:
	var ed = null
	for m in UI.stack:
		if m.get_script() != null and String(m.get_script().resource_path).ends_with("ring_editor.gd"):
			ed = m
	if ed == null:
		print("TRAILER: no ring editor up")
		return
	var c = null
	if which == "go" or which == "store":
		for i in ed.cells.size():
			if (which == "go" or i >= 8) and ed.can_go(ed.cells[i].dest):
				c = ed.cells[i]
				break
	elif which.begins_with("p"):
		# where the party's beast number N stands
		c = ed.cells[int(GameState.party[int(which.substr(1))].slot)]
	else:
		c = ed.cells[int(which)]
	if c == null:
		print("TRAILER: no cell for ", which)
		return
	await main._tap_at((c as Control).get_global_rect().get_center())
