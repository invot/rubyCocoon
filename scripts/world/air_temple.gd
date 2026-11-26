extends RefCounted
## Valkoog, the air temple (docs/scaraba-implementation-plan.md WP6, its wind puzzles reworked 25 Nov 2026; the
## outline's §4). Two climbs, each with its own set of wind puzzles (the rules: wind_puzzle.gd; the rooms:
## interior_maps.gd; the pieces and the wind drawn: wind_pieces.gd):
##   - To the keepers (valkoog_1 .. valkoog_4): soft breath you walk through. You turn the fans by hand; the twins'
##     gust slides the sand jars (it takes an air mage, and before the keepers that's Tam and Saffi). Each hall's sand
##     curtain stands across its flight up until every pinwheel it needs spins and no wind feeds it.
##   - To the dragon (valkoog_gale, valkoog_spire), after the keepers: gales that carry you over the chasms. Only the
##     hero's own Gust wakes a wind-stone; a push flips a vane; the spire's last gale rises from an updraft to the
##     summit's ledge.
## A room's half-done state is the room's while you're in it, and starts over when you walk in again (or when the twins
## blow it back for you); a solved room keeps its pieces where they were (flag valkoog_wind_<room>, the layout in
## flags["valkoog_wind"]). The wind-stones stay awake once woken (their own flags).
const ScarabaTown = preload("res://scripts/story/scaraba_town.gd")
const Wind = preload("res://scripts/world/wind_puzzle.gd")
const Pieces = preload("res://scripts/gfx/wind_pieces.gd")
const VPer = preload("res://scripts/gfx/voxel_person.gd")
const Elev = preload("res://scripts/world/elevation.gd")

const AIR_GLOW := Color("#7fe8d0")
## The keepers' halls in the order they climb (WorldDB.TEMPLES "air" ["rooms"]), then the chamber, the climb to the
## dragon and the summit.
const FLOORS := ["valkoog_1", "valkoog_2", "valkoog_3", "valkoog_4"]
const KEEPERS_ROOM := "valkoog_keepers"
const GALE_ROOMS := ["valkoog_gale", "valkoog_spire"]
const SUMMIT := "temple_air"
const ROOMS := ["valkoog_1", "valkoog_2", "valkoog_3", "valkoog_4", "valkoog_keepers", "valkoog_gale", "valkoog_spire", "temple_air"]
## The five keepers at the star's points (A13): bald, hooded, and one speaks.
const KEEPERS := [
	{"name": "Khepri", "shirt": "#3f8f7a", "skin": "#b98a5c"},
	{"name": "Amunet", "shirt": "#4a7a9a", "skin": "#8a5a38"},
	{"name": "Sethi", "shirt": "#8a6a3a", "skin": "#c89a6a"},
	{"name": "Nebet", "shirt": "#6a5a8a", "skin": "#a06a44"},
	{"name": "Ptahmes", "shirt": "#5a7a5a", "skin": "#d0a878"},
]
const SAVED := "valkoog_wind"
## How high a gale carries you (over the floor or the edge you left), and how fast (tiles a second).
const RIDE_HEIGHT := 0.45
const RIDE_SPEED := 6.5

## The wind room being played: its key, its pieces (wind_puzzle.gd pieces) and their state now.
static var room := ""
static var pcs := {}
static var st := {}


static func keeper_look(i: int) -> Dictionary:
	var k: Dictionary = KEEPERS[clampi(i, 0, KEEPERS.size() - 1)]
	# a mage's look: the long robe under a thick lined hood, and bald under it (townfolk.gd ROBES)
	return {"robe": "hooded", "element": "air", "shirt": String(k["shirt"]), "skin": String(k["skin"])}


static func in_temple(room_key: String) -> bool:
	return ROOMS.has(room_key)


## Whether a room's wind puzzle is solved (a save from before the rework: its floor's star answered).
static func solved(room_key: String) -> bool:
	return GameState.flag("valkoog_wind_" + room_key) or GameState.flag("valkoog_star_" + room_key)


## Whether the hero's side can gust a jar: the twins, or the hero's own stone once the keepers have taught Gust.
static func air_key_along() -> bool:
	if GameState.has_stone("air") and GameState.learned_spell("gust"):
		return true
	return twins_along()


static func twins_along() -> bool:
	return GameState.flag("met_twins") and not GameState.flag("twins_home")


static func floor_after(room_key: String) -> String:
	var at := FLOORS.find(room_key)
	if at < 0:
		return ""
	if at == FLOORS.size() - 1:
		return KEEPERS_ROOM
	return FLOORS[at + 1]


static func gale(map: Dictionary) -> bool:
	return String(Wind.rules(map).get("kind", "")) == "gale"


# ---------------------------------------------------------------- the objects
## A temple room's story objects (Story.extra_npcs): its wind pieces and sand curtain, the keepers round their star,
## and the twins.
static func objects(map: Dictionary) -> Array:
	var key := String(map.get("room_key", ""))
	if not ROOMS.has(key):
		return []
	var out := []
	var anchors: Dictionary = map.get("anchors", {})
	if not Wind.rules(map).is_empty():
		_begin(map)
		for id in pcs:
			var pc: Dictionary = pcs[id]
			# (an updraft's grate is floor you step on: it's drawn with the room, not stood in the way)
			if String(pc["kind"]) in Wind.FLOORED:
				continue
			out.append({"kind": "story", "id": "wind_piece", "piece": String(id), "name": "", "pos": Wind.where(pcs, st, id),
				"scene": _piece_node(pc), "facing": Vector2i.DOWN, "still": true})
		var gate := Wind.gate_tile(map)
		if gate.x >= 0 and not solved(key) and Wind.gate_up(map, pcs, st):
			out.append({"kind": "story", "id": "wind_curtain", "name": "", "pos": gate, "scene": Pieces.curtain(),
				"facing": Vector2i.DOWN, "still": true, "blocking": true})
	if key == KEEPERS_ROOM:
		for i in KEEPERS.size():
			var an := "keeper_%d" % i
			if anchors.has(an):
				out.append({"kind": "story", "id": "air_keeper", "name": String(KEEPERS[i]["name"]), "keeper": i,
					"pos": anchors[an], "look": keeper_look(i), "facing": Vector2i(0, 1), "still": true, "story": true})
	if twins_along() and anchors.has("twin_tam") and anchors.has("twin_saffi"):
		out.append({"kind": "story", "id": "twin_guest", "twin": "tam", "name": "Tam", "pos": anchors["twin_tam"],
			"look": ScarabaTown.TAM_LOOK, "facing": Vector2i(0, 1), "still": true, "scale": 0.72})
		out.append({"kind": "story", "id": "twin_guest", "twin": "saffi", "name": "Saffi", "pos": anchors["twin_saffi"],
			"look": ScarabaTown.SAFFI_LOOK, "facing": Vector2i(0, 1), "still": true, "scale": 0.72})
	return out


## Starts the room's wind: as it was left if it's solved, else fresh.
static func _begin(map: Dictionary) -> void:
	room = String(map.get("room_key", ""))
	pcs = Wind.pieces(map)
	st = Wind.fresh(pcs, GameState.flags)
	var saved: Dictionary = GameState.flags.get(SAVED, {}).get(room, {})
	if solved(room) and not saved.is_empty():
		for id in saved:
			if not st.has(id):
				continue
			var v = saved[id]
			st[id] = Vector2i(int(v[0]), int(v[1])) if v is Array else v
	# (a stone already woken stays awake)
	for id in pcs:
		if String(pcs[id]["kind"]) == "stone":
			st[id] = GameState.flag(String(pcs[id].get("flag", ""))) or bool(st.get(id, false))


static func _keep() -> void:
	var all: Dictionary = GameState.flags.get(SAVED, {})
	var out := {}
	for id in st:
		var v = st[id]
		out[id] = [v.x, v.y] if v is Vector2i else v
	all[room] = out
	GameState.flags[SAVED] = all


## A piece's model, as it stands now.
static func _piece_node(pc: Dictionary) -> Node3D:
	var id := String(pc["id"])
	match String(pc["kind"]):
		"vent":
			return Pieces.vent(String(pc.get("dir", "v")))
		"fan":
			return Pieces.fan(String(st.get(id, "v")))
		"jar":
			return Pieces.jar()
		"pinwheel":
			return Pieces.pinwheel()
		"vane":
			return Pieces.vane(String(st.get(id, "/")))
		"stone":
			return Pieces.wind_stone(String(pc.get("dir", "v")), bool(st.get(id, false)))
	return Node3D.new()


# ---------------------------------------------------------------- walking in
## Walking into one of Valkoog's rooms (Story.on_map_enter): the wind drawn and the pieces turning, a chasm's sides, the
## keepers' star in the floor; the summit remembered (its door back to the keepers opens from there).
static func on_enter(world) -> void:
	var key := String(world.map.get("room_key", ""))
	if not ROOMS.has(key):
		return
	if key == SUMMIT and not GameState.flag("valkoog_summit_reached"):
		GameState.set_flag("valkoog_summit_reached")
	var gfx := _gfx(world)
	if key == KEEPERS_ROOM:
		_keepers_star(world, gfx)
	if Wind.rules(world.map).is_empty():
		return
	if room != key:
		_begin(world.map)
	if gale(world.map):
		gfx.build_chasm(world.map, func(p: Vector2i) -> bool: return Wind.chasm(world.map, p),
			func(p: Vector2i) -> bool: return MapGen_walkable(world.map, p),
			func(p: Vector2i) -> float: return Elev.surface(world.map, p) if Elev.has(world.map) and MapGen_walkable(world.map, p) else 0.0)
		for id in pcs:
			if String(pcs[id]["kind"]) == "updraft":
				var grate := Pieces.updraft()
				grate.name = "Updraft_" + String(id)
				grate.position = world.tile_pos(pcs[id]["at"])
				gfx.add_child(grate)
	_refresh(world)
	if not GameState.flag("valkoog_intro_" + key) and twins_along():
		GameState.set_flag("valkoog_intro_" + key)
		var intro: Array = INTROS.get(key, [])
		for line in intro:
			await Story.say([String(line[1])], String(line[0]))


static func MapGen_walkable(map: Dictionary, p: Vector2i) -> bool:
	return not Wind.solid_tile(map, p) and not Wind.chasm(map, p)


## The room's WindPieces node (wind_pieces.gd), made on first asking.
static func _gfx(world) -> Node3D:
	var g: Node3D = world.get_node_or_null("WindPieces")
	if g == null:
		g = Pieces.new()
		g.name = "WindPieces"
		world.add_child(g)
	return g


## What the twins say walking into each room the first time: [who, line].
const INTROS := {
	"valkoog_1": [["Saffi", "Fans! Push one and it turns. The wind goes where its little arrow points."],
		["Tam", "And the curtain over the stairs stops once that pinwheel spins. Probably. I'm older, so I'd know."]],
	"valkoog_2": [["Tam", "The curtain's made of wind this time. Stop its wind and it'll fall down."],
		["Saffi", "Face a jar and we'll gust it for you. It slides till it bumps into something, so pick your bumps."]],
	"valkoog_3": [["Saffi", "Two pinwheels. And look how much wind that curtain's wasting."]],
	"valkoog_4": [["Tam", "Three pinwheels, three winds."], ["Saffi", "That's what I was going to say."]],
	"valkoog_gale": [["Tam", "This wind's different. It doesn't tickle, it carries."],
		["Saffi", "Wake the stone with your own Gust. Khepri said it has to be you."]],
	"valkoog_spire": [["Saffi", "There's the summit door, up on that ledge."],
		["Tam", "And that grate's an updraft. Get the wind into it and it'll lift you. Maybe."]],
}


# ---------------------------------------------------------------- talking
## What a room's object does when spoken to (Story.talk).
static func talk(world, n: Dictionary) -> void:
	match String(n["id"]):
		"wind_piece":
			await _piece_talk(world, n)
		"wind_curtain":
			await Story.say([_curtain_line(world.map)])
		"twin_guest":
			await _twin_talk(world, n)


static func _piece_talk(world, n: Dictionary) -> void:
	var id := String(n.get("piece", ""))
	if not pcs.has(id) or room != String(world.map.get("room_key", "")):
		return
	var pc: Dictionary = pcs[id]
	var key := room
	var done := solved(key)
	match String(pc["kind"]):
		"vent":
			await Story.say(["A stone mouth breathing a soft, steady wind. It never stops." if not gale(world.map)
				else "A stone mouth roaring with the dragon's wind."])
		"pinwheel":
			var spun: bool = Wind.blow(world.map, pcs, st)["spun"].has(id)
			await Story.say(["The pinwheel whirls, its four colours blurring together." if spun
				else "A pinwheel on a post, perfectly still. It's waiting for a breath of wind."])
		"fan":
			if done:
				await Story.say(["The fan turns lazily. The way up is open."])
				return
			Sfx.play("lever")
			st[id] = Wind.CW[String(st[id])]
			_turn(world, n, Pieces.yaw(String(st[id])), "Head")
			await _changed(world)
		"vane":
			if done:
				await Story.say(["The sail hums in the wind. It's found its way."])
				return
			Sfx.play("lever")
			st[id] = "\\" if String(st[id]) == "/" else "/"
			_turn(world, n, Pieces.vane_yaw(String(st[id])), "Sail")
			await _changed(world)
		"stone":
			if bool(st.get(id, false)):
				await Story.say(["The wind-stone hums, wide awake, pouring out its gale."])
				return
			if not GameState.learned_spell("gust"):
				await Story.say(["A wind-stone, pale and cold. It wants a gust of wind, and a mage's own."])
				return
			if not await Story.field_cast(world, "gust", "Cast Gust into the wind-stone?"):
				return
			GameState.set_flag(String(pc.get("flag", "")))
			st[id] = true
			Sfx.play("fly")
			await UI.flash(AIR_GLOW, 1)
			_wake_stone(n)
			await _changed(world)
			await Story.say(["The stone drinks in your Gust... and breathes it back out, a hundred times stronger."])
		"jar":
			if done:
				await Story.say(["A big sand jar, right where it's needed."])
				return
			if not air_key_along():
				await Story.say(["A big jar packed with sand. It won't budge, not for a push, and not for anything less than a gust."])
				return
			var d: Vector2i = world.facing
			var to := Wind.slide(world.map, pcs, st, id, d, world.player_pos)
			if to == Wind.where(pcs, st, id):
				await Story.say(["The jar rocks, but there's no room for it to slide that way."])
				return
			Sfx.play("fly")
			if twins_along() and not GameState.has_stone("air"):
				await Story.say([["Whoosh!", "Hup!", "There it goes!"].pick_random()], ["Tam", "Saffi"].pick_random())
			st[id] = to
			await _slide_jar(world, n, to)
			Sfx.play("smash")
			await _changed(world)


## The wind changed: the room redrawn, the curtain stilled if it's done, the hero carried off if a gale now runs
## through where they stand.
static func _changed(world) -> void:
	_refresh(world)
	if gale(world.map):
		var r := Wind.ride(world.map, pcs, st, world.player_pos, world.player_pos)
		if not r.is_empty():
			await Story.say(["Whoa! The wind catches you!"])
			await _ride(world, r)
	await _check_solved(world)


static func _check_solved(world) -> void:
	if solved(room):
		return
	var walk := Wind.floor_walk(world.map, _people(world))
	var region := Wind.region(world.map, pcs, st, world.player_pos, walk)
	if not Wind.done_test(world.map, pcs).call(st, region):
		return
	GameState.set_flag("valkoog_wind_" + room)
	_keep()
	if Wind.gate_tile(world.map).x >= 0:
		Sfx.secret_chime()
		await UI.flash(AIR_GLOW, 1)
		_drop_curtain(world)
		await Story.say([_solved_line(room)])
	elif room == "valkoog_spire":
		Sfx.secret_chime()
		await Story.say(["The gale pours into the grate, and a column of air roars up out of it towards the ledge."])


## Tiles where people stand (the twins, the keepers): the solver walks round them as you would.
static func _people(world) -> Dictionary:
	var out := {}
	for p in world.npcs:
		var id := String(world.npcs[p].get("id", ""))
		if id in ["twin_guest", "air_keeper"]:
			out[p] = true
	return out


static func _solved_line(key: String) -> String:
	match key:
		"valkoog_1":
			return "The pinwheel whirls, and the sand curtain over the stairs sighs and settles into a little heap."
		"valkoog_2":
			return "Its wind cut off, the curtain sags, and the sand pours down into a quiet heap. The stairs are clear."
		"valkoog_3":
			return "Both pinwheels whirl. The curtain shivers, and falls."
		"valkoog_4":
			return "Three pinwheels sing in three winds, and the last curtain falls. Above, someone is humming."
	return "The wind settles. The way on is open."


static func _curtain_line(map: Dictionary) -> String:
	var g: Dictionary = Wind.rules(map).get("gate", {})
	var fed := bool(g.get("fed", false)) and bool(Wind.blow(map, pcs, st)["fed"])
	if fed:
		return "A curtain of sand pours across the stairs, blown along by wind from somewhere in the room. You can't see through it, let alone walk."
	return "A curtain of stinging sand hangs across the stairs. Somewhere a pinwheel is still waiting."


# ---------------------------------------------------------------- the twins
## The twins: a hint for the room, and the offer to blow it back as it started. They notice when it can't be done
## from here any more (wind_puzzle.gd solve).
static func _twin_talk(world, n: Dictionary) -> void:
	var who := "Tam" if String(n.get("twin", "tam")) == "tam" else "Saffi"
	var key := String(world.map.get("room_key", ""))
	if Wind.rules(world.map).is_empty() or solved(key):
		await Story.say([_twin_chat(key, who)], who)
		return
	# (fans turn round and vanes flip back, so a keepers' hall can only get stuck once a jar has slid: until then
	# there's nothing to work out, and the search, up to a second on the fourth hall, is skipped)
	var settled := not gale(world.map) and pcs.keys().all(func(id): return String(pcs[id]["kind"]) != "jar" or Wind.where(pcs, st, id) == pcs[id]["at"])
	var plan = [] if settled else Wind.solve(world.map, pcs, st, world.player_pos, Wind.floor_walk(world.map, _people(world)), Wind.done_test(world.map, pcs), 12000)
	if plan == null:
		await Story.say(["Hmm. I don't think that works any more. Something's stuck."], who)
	else:
		await Story.say([_hint(key, who)], who)
	if await UI.ask("Want us to blow it all back the way it started?", who):
		await _reset(world)


static func _twin_chat(key: String, who: String) -> String:
	if key == KEEPERS_ROOM:
		return "Real air mages. Five of them. Don't tell them I said they're bald." if who == "Tam" else "They talk to us like we're grown-ups. I like them."
	if key == SUMMIT:
		return "That's the dragon. The actual dragon. Be polite." if who == "Saffi" else "I'm not scared. You go first, though."
	return ["See? Easy. For us.", "The wind likes you. I can tell.", "Come on, the stairs are open."].pick_random()


static func _hint(key: String, who: String) -> String:
	var lines: Dictionary = {
		"valkoog_1": ["Follow the wind from the vent. Where does each fan send it?", "That fan up by the wall's pointing the wrong way."],
		"valkoog_2": ["Jars stop wind. One jar in the curtain's wind, and down it comes.", "The pillars stop jars sliding. Use them."],
		"valkoog_3": ["What if the curtain's wind blew a pinwheel instead?", "The fan in the curtain's wind can turn it, you know."],
		"valkoog_4": ["One wind for each pinwheel. Start with the one by the vent.", "A jar's sitting in the curtain's wind. That might be good or bad."],
		"valkoog_gale": ["The stone's gale goes up the west wall. The sail decides where after that.", "Wake the stone first. With your Gust."],
		"valkoog_spire": ["Get to the island first. Then the sails out there.", "The wind has to end up in the grate by the ledge."],
	}
	var pick: Array = lines.get(key, ["Hmm."])
	return String(pick[0 if who == "Tam" else mini(1, pick.size() - 1)])


## The room as it started (the twins' gust puts every piece back): reloaded around you where you stand.
static func _reset(world) -> void:
	room = ""
	Sfx.play("fly")
	await UI.flash(Color(0.95, 0.9, 0.75), 1)
	GameState.main.goto_map(world.map_id, world.player_pos, world.facing)


# ---------------------------------------------------------------- stepping
## A step in one of Valkoog's gale rooms (Story.field_guide_on_step): onto a powered updraft, up to its ledge; into a
## gale, carried to where it ends. True when the step was taken over.
static func on_step(world) -> bool:
	if room != String(world.map.get("room_key", "")) or not gale(world.map):
		return false
	var p: Vector2i = world.player_pos
	var wind := Wind.blow(world.map, pcs, st)
	for id in pcs:
		var pc: Dictionary = pcs[id]
		if String(pc["kind"]) == "updraft" and pc["at"] == p and wind["spun"].has(id) and pc.has("to_tile"):
			await _lift(world, pc)
			return true
	var r := Wind.ride(world.map, pcs, st, p, p - world.facing, wind)
	if r.is_empty():
		return false
	await _ride(world, r)
	return true


## Carried along a gale: lifted off your feet and swept along its path (round its vanes), set down where it ends; or,
## where it ends over the chasm, let go and bumped back to the edge you stepped off.
static func _ride(world, r: Dictionary) -> void:
	world._clear_path()
	world.busy = true
	Sfx.play("fly")
	var player: Node3D = world.player
	var tiles: Array = r["ride"]
	var base := float(world.tile_pos(world.player_pos).y)
	var tw: Tween = world.create_tween()
	var at: Vector3 = player.position
	tw.tween_property(player, "position", at + Vector3(0, RIDE_HEIGHT, 0), 0.18)
	at += Vector3(0, RIDE_HEIGHT, 0)
	for t: Vector2i in tiles:
		var ground := base if Wind.chasm(world.map, t) else float(world.tile_pos(t).y)
		var to := Vector3(t.x + 0.5, maxf(ground, base) + RIDE_HEIGHT, t.y + 0.5)
		tw.tween_callback(_face.bind(world, to - at))
		tw.tween_property(player, "position", to, (to - at).length() / RIDE_SPEED)
		at = to
	await tw.finished
	var land: Vector2i = r["land"]
	if bool(r.get("drop", false)):
		Sfx.play("jump")
		await Story.say(["The gale lets go of you over the drop - and a gust from the twins bumps you back to the edge."] if twins_along()
			else ["The gale lets go of you over the drop - and the dragon's wind bumps you back to the edge."])
	var tw2: Tween = world.create_tween()
	tw2.tween_property(player, "position", world.tile_pos(land), 0.25)
	await tw2.finished
	world.player_pos = land
	player.position = world.tile_pos(land)
	world.busy = false
	await _twins_follow(world, land)
	await _check_solved(world)


static func _face(world, d: Vector3) -> void:
	if absf(d.x) < 0.01 and absf(d.z) < 0.01:
		return
	var way := Vector2i(int(signf(d.x)), 0) if absf(d.x) > absf(d.z) else Vector2i(0, int(signf(d.z)))
	world.facing = way
	VPer.face(world.player, way, true)


## Up an updraft's column of air to its ledge.
static func _lift(world, pc: Dictionary) -> void:
	world._clear_path()
	world.busy = true
	Sfx.play("fly")
	var player: Node3D = world.player
	var top: Vector2i = pc["to_tile"]
	var end: Vector3 = world.tile_pos(top)
	var tw: Tween = world.create_tween()
	tw.tween_property(player, "position", player.position + Vector3(0, end.y + 1.1 - player.position.y, 0), 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(player, "position", end + Vector3(0, 0.4, 0), 0.45)
	tw.tween_property(player, "position", end, 0.2)
	await tw.finished
	world.player_pos = top
	world.facing = Vector2i(0, -1)
	VPer.face(player, world.facing, true)
	world.busy = false
	await _twins_follow(world, top)


## The twins ride after you: they reappear on the nearest free tiles beside where you landed.
static func _twins_follow(world, land: Vector2i) -> void:
	if not twins_along():
		return
	var spots := []
	for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1)]:
		var q: Vector2i = land + d
		if world._walkable(q) and Wind.ride(world.map, pcs, st, q, q).is_empty() and Elev.joined(world.map, land, q):
			spots.append(q)
	var twins: Array = world.npcs.values().filter(func(m): return m.get("id", "") == "twin_guest")
	for i in twins.size():
		var m: Dictionary = twins[i]
		if i >= spots.size():
			break
		if (m["pos"] as Vector2i).distance_to(land) <= 2.0:
			continue
		var node: Node3D = m.get("node", null)
		world.npcs.erase(m["pos"])
		m["pos"] = spots[i]
		m["home"] = spots[i]
		world.npcs[spots[i]] = m
		if node != null:
			var tw: Tween = world.create_tween()
			tw.tween_property(node, "position", world.tile_pos(spots[i]) + Vector3(0, 0.6, 0), 0.35)
			tw.tween_property(node, "position", world.tile_pos(spots[i]), 0.2)
			VPer.face(node, Vector2i(0, 1), true)


# ---------------------------------------------------------------- drawing
## Redraws the wind, and sets what turns turning: pinwheels and updrafts the wind reaches, fans it runs through.
static func _refresh(world) -> void:
	var gfx := _gfx(world)
	var wind := Wind.blow(world.map, pcs, st)
	var sources := {}
	for id in pcs:
		sources[id] = pcs[id]["at"]
	var lift := func(t: Vector2i) -> float:
		return 0.0 if Wind.chasm(world.map, t) else Elev.surface(world.map, t)
	gfx.draw_wind(wind["paths"], sources, gale(world.map), lift)
	var through := {}
	for path in wind["paths"]:
		for t in path["tiles"]:
			through[t] = true
	for p in world.npcs:
		var n: Dictionary = world.npcs[p]
		if n.get("id", "") != "wind_piece" or not pcs.has(String(n.get("piece", ""))):
			continue
		var id := String(n["piece"])
		var node: Node3D = n.get("node", null)
		if node == null:
			continue
		match String(pcs[id]["kind"]):
			"pinwheel":
				gfx.spin(node.find_child("Petals", true, false), 2, -2.2 if wind["spun"].has(id) else 0.0)
			"fan":
				gfx.spin(node.find_child("Blades", true, false), 2, 1.6 if through.has(p) else 0.0)
			"stone":
				gfx.spin(node.find_child("Ring", true, false), 1, 0.5 if bool(st.get(id, false)) else 0.0)
	for id in pcs:
		if String(pcs[id]["kind"]) == "updraft":
			var grate: Node3D = gfx.get_node_or_null("Updraft_" + String(id))
			if grate != null:
				(grate.get_node("Column") as Node3D).visible = wind["spun"].has(id)


## A fan's head or a vane's sail swinging round to its new way.
static func _turn(world, n: Dictionary, yaw: float, part: String) -> void:
	var node: Node3D = n.get("node", null)
	if node == null:
		return
	var head: Node3D = node.find_child(part, true, false)
	if head == null:
		return
	var to := yaw
	# (the short way round)
	while to - head.rotation.y > PI:
		to -= TAU
	while to - head.rotation.y < -PI:
		to += TAU
	var tw: Tween = world.create_tween()
	tw.tween_property(head, "rotation:y", to, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func _wake_stone(n: Dictionary) -> void:
	var node: Node3D = n.get("node", null)
	if node == null:
		return
	# (the crystal's facets and the ring's shards light up teal)
	for part in ["Crystal", "Ring"]:
		var holder := node.find_child(part, true, false)
		if holder == null:
			continue
		for mi in holder.get_children():
			if mi is MeshInstance3D:
				mi.material_override = Pieces.mat(Color("#5fd8c0") if part == "Crystal" else Pieces.TEAL, 1.4)


## A jar sliding over the floor to `to`; it moves in the world's people too, so nothing walks through it.
static func _slide_jar(world, n: Dictionary, to: Vector2i) -> void:
	var node: Node3D = n.get("node", null)
	world.npcs.erase(n["pos"])
	var from: Vector2i = n["pos"]
	n["pos"] = to
	n["home"] = to
	world.npcs[to] = n
	if node == null:
		return
	var tw: Tween = world.create_tween()
	tw.tween_property(node, "position", world.tile_pos(to), 0.09 * maxf(1.0, from.distance_to(to))).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished


static func _drop_curtain(world) -> void:
	for p in world.npcs.keys():
		var n: Dictionary = world.npcs[p]
		if n.get("id", "") == "wind_curtain":
			Sfx.play("wind")
			world.remove_npc(n)


## The keepers' chamber: the star cut in its floor, in glowing teal, from point to point in the desert's order.
static func _keepers_star(world, gfx: Node3D) -> void:
	var anchors: Dictionary = world.map.get("anchors", {})
	var pts := []
	for i in 5:
		if not anchors.has("keeper_%d" % i):
			return
		var a: Vector2i = anchors["keeper_%d" % i]
		pts.append(Vector3(a.x + 0.5, 0.015, a.y + 0.5))
	var inlay := Pieces.mat(AIR_GLOW, 0.9)
	# 1, 3, 5, 2, 4, 1 (the keepers 0..4 stand at the points 1..5)
	var order := [0, 2, 4, 1, 3, 0]
	for i in order.size() - 1:
		var a: Vector3 = pts[order[i]]
		var b: Vector3 = pts[order[i + 1]]
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.08, 0.02, a.distance_to(b))
		mi.mesh = bm
		mi.material_override = inlay
		mi.position = (a + b) / 2.0
		mi.look_at_from_position(mi.position, b, Vector3.UP)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gfx.add_child(mi)
	for p in pts:
		var disc := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.42
		cm.bottom_radius = 0.42
		cm.height = 0.02
		cm.radial_segments = 20
		disc.mesh = cm
		disc.material_override = Pieces.mat(Color("#cdb896").lightened(0.15))
		disc.position = p - Vector3(0, 0.004, 0)
		gfx.add_child(disc)


# ---------------------------------------------------------------- battles
## Every battle in Valkoog's inner ways is fought with the twins and the Air Shield (the outline's §4 rules), and a
## loss resets the room instead of costing gold and a walk back.
static func decorate_battle(cfg: Dictionary) -> void:
	cfg["air_shield"] = true
	cfg["retry_room"] = true
	if cfg.has("guests"):
		return
	if not twins_along():
		return
	cfg["guests"] = guests()


## Tam and Saffi as guest combatants (battle_guest.gd): they keep pace with the party by a few levels.
static func guests() -> Array:
	var lv := 8
	for b in GameState.party:
		lv = maxi(lv, int(b.level) - 4)
	var hp := 34 + maxi(0, lv - 8) * 3
	return [{"name": "Tam", "look": ScarabaTown.TAM_LOOK, "level": lv, "hp": hp},
		{"name": "Saffi", "look": ScarabaTown.SAFFI_LOOK, "level": lv, "hp": hp}]
