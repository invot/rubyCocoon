extends RefCounted
## Scaraba after Valkoog (docs/scaraba-implementation-plan.md WP7; the outline's §3).
##   - The road ambush: Bart and two of the Jackals wait below Valkoog's stair. They see the air stone and the twins
##     together, call the hero a traitor, fight with a shield, and run for Scaraba. The first scene plays itself
##     (on_enter) and the fight can be picked up again by talking to Bart.
##   - Grubb's report (scaraba_town.gd _grubb) sets grubb_report: the title means nothing to him; he asks about the
##     missing trainers, and the church trip is on.
##   - The cistern under Grubb's house has been searched: the Jackals' bundle of handbills is the evidence, and a
##     loose stone under the bedrolls keeps the crew's stash (the optional aftermath).
##   - The gate wagon skips the desert: Scaraba's south gate to Reed's west landing (and back), with Reed's boat across
##     the lake from the landing. The trip is two legs on real maps, so a save at the landing comes back to it.
const ScarabaTown = preload("res://scripts/story/scaraba_town.gd")

## Where Bart and two of his crew wait, just below the temple's stair.
const AMBUSH_AT := [Vector2i(15, 8), Vector2i(13, 9), Vector2i(17, 9)]
## The parked gate wagon: a driver and his cart inside Scaraba's south gate, and the pair at Reed's west landing.
## (TOWN_WAGON and LANDING_WAGON are where the hero steps down, clear of the driver.)
const TOWN_WAGON := Vector2i(18, 26)
const TOWN_DRIVER := Vector2i(19, 26)
const TOWN_CART := Vector2i(20, 26)
const LANDING_WAGON := Vector2i(4, 10)
const LANDING_DRIVER := Vector2i(3, 10)
const LANDING_CART := Vector2i(2, 11)
## The searched cistern's loose stone (the handbills, then the stash).
const CISTERN_SEARCH := Vector2i(7, 4)
const WAGON_LOOK := {"skin": "#c8946a", "hair": "#3a2a1a", "shirt": "#b8823a", "pants": "#4a3a2a", "hat": "#e0cc90"}


## The road's three Jackals (Bart first) while the ambush waits for them.
static func ambush_ready() -> bool:
	return GameState.flag("guardian_air") and not GameState.flag("jackals_ambush") and not GameState.flag("twins_home")


static func npcs(map: Dictionary) -> Array:
	var out := []
	var id := String(map.get("id", ""))
	if id == "route5" and String(map.get("desert_section", "")) == "valkoog" and ambush_ready():
		for i in AMBUSH_AT.size():
			out.append({"kind": "story", "id": "jackal_road", "name": "Bart the Jackal" if i == 0 else "Jackal",
				"pos": AMBUSH_AT[i], "look": ScarabaTown.BART_LOOK if i == 0 else ScarabaTown.JACKAL_LOOKS[i - 1],
				"facing": Vector2i(0, 1), "still": true, "story": i == 0})
	# the gate wagon waits on both ends (its driver won't leave until Grubb has said where they're going)
	if GameState.flag("guardian_air"):
		if id == "sundown":
			out.append(_driver(TOWN_DRIVER, "to_landing"))
			out.append(_cart(TOWN_CART, "to_landing"))
		elif id == "dustwell_channel":
			out.append(_driver(LANDING_DRIVER, "to_town"))
			out.append(_cart(LANDING_CART, "to_town"))
	# the cistern, searched while the hero was in the temple: the handbills, then the crew's stash
	if String(map.get("room_key", "")) == "twins_cistern" and GameState.flag("guardian_air") and not GameState.flag("cistern_cache"):
		out.append({"kind": "story", "id": "cistern_search", "name": "", "pos": CISTERN_SEARCH, "scene": _stone_node(),
			"facing": Vector2i(0, 1), "still": true, "story": true})
	return out


static func talk(world, n: Dictionary) -> void:
	match String(n["id"]):
		"jackal_road":
			await ambush(world, not GameState.flag("jackals_ambush_met"))
		"cistern_search":
			await _search()
		"gate_wagon":
			await _wagon(String(n.get("mode", "to_landing")))


## The first step off the temple stair: they were waiting for the hero all along.
static func on_enter(world) -> void:
	if world.map_id != "route5" or String(world.map.get("desert_section", "")) != "valkoog":
		return
	if not ambush_ready() or GameState.flag("jackals_ambush_met"):
		return
	await ambush(world, true)


## Bart's exchange, his shielded crew, and the retreat (or just the fight again, if the talk's been had).
static func ambush(world, intro := true) -> void:
	var gang := _gang(world)
	if gang.is_empty():
		return
	if intro:
		GameState.set_flag("jackals_ambush_met")
		await Story.say(["There you are. We've been camped on this road two nights, waiting for the pair of you to come out of that pyramid.",
			"Air stone in your bag. Air mages at your shoulder. You went in with them, and you came out smiling."], "Bart the Jackal")
		await Story.say(["A traitor. That's what the desert's going to call you, sandwalker. Last offer: hand the children over and walk away."], "Bart the Jackal")
		await Story.say(["We're not going anywhere with him."], "Saffi")
		await Story.say(["Then that's how it is. Boys!"], "Bart the Jackal")
	var res: String = await Story.trainer_battle(ambush_def())
	if res != "win":
		return
	await won(world)


## The road fight's setup: Bart's own crew, a point more shield than a trainer of his level is given.
static func ambush_def() -> Dictionary:
	return {"name": "Bart the Jackal", "cls": "Jackal Boss", "look": ScarabaTown.BART_LOOK,
		"team": [[9, 24, false], [6, 24, false], [33, 25, false]], "shield": 2,
		"defeat": "Enough! Enough. The temple's yours."}


## Beaten, the gang runs north for Scaraba (body and spirit; the road is open again).
static func won(world) -> void:
	GameState.set_flag("jackals_ambush")
	await Story.say(["Bart spits in the sand and gets up. The crew scrambles after him, back up the road toward Scaraba.",
		"\"The temple's yours!\" he shouts. \"But this isn't over. We'll be waiting where it's cooler!\""])
	UI.toast("The Jackals have run for Scaraba.")
	var gang := _gang(world)
	for n in gang:
		var path := []
		for k in range(1, 5):
			path.append(Vector2i(n["pos"].x, n["pos"].y - k))
		if is_instance_valid(world):
			world.walk_npc_aside(n, path, Vector2i(0, -1))
	if is_instance_valid(world):
		await world.get_tree().create_timer(1.0).timeout
	for n in gang:
		if is_instance_valid(world) and world.npcs.values().has(n):
			world.remove_npc(n)


# ---------------------------------------------------------------- the searched cistern
## The loose stone: the handbills the whole town was taught to believe, then the crew's stash.
static func _search() -> void:
	if not GameState.flag("cistern_searched"):
		GameState.set_flag("cistern_searched")
		GameState.receive_item("jackal_handbills")
		Sfx.play("item")
		UI.toast("Received the Jackals' Handbills!")
		await Story.say(["The cistern has been turned over. Bedrolls kicked into the corners, the blanket basket emptied, the twins' things scattered.",
			"Under a cracked tile, a bundle of handbills, the same print as the one Bart gave you at the gate. Dozens of them, with a list of the houses the twins were \"seen\" near, written in a confident hand.",
			"It's the whole lie, written down before the town ever told it. The handbills go in your bag."])
		return
	GameState.set_flag("cistern_cache")
	GameState.gold += 220
	GameState.add_item("minor_potion", 2)
	Sfx.play("buy")
	UI.gold(220)
	UI.pickup("minor_potion", 2, "pickup")
	await Story.say(["The loose stone comes away under your hand. Behind it the crew kept what they took when they moved the twins out: a handful of coins in a rag, a pair of potions, and a child's wooden animal carved badly.",
		"You put it back on the shelf where Saffi's bedroll was."])


# ---------------------------------------------------------------- the gate wagon
## The driver and his cart (two objects, one conversation).
static func _driver(at: Vector2i, mode: String) -> Dictionary:
	return {"kind": "story", "id": "gate_wagon", "mode": mode, "name": "Wagon Driver", "pos": at,
		"look": WAGON_LOOK, "facing": Vector2i(0, 1), "still": true, "story": true}


static func _cart(at: Vector2i, mode: String) -> Dictionary:
	return {"kind": "story", "id": "gate_wagon", "mode": mode, "name": "", "pos": at, "scene": _cart_node(),
		"facing": Vector2i(0, 1), "still": true, "blocking": true}


## From Scaraba's gate to Reed's landing, or back: the desert skipped, the lake still to cross.
static func _wagon(mode: String) -> void:
	if not GameState.flag("grubb_report"):
		await Story.say(["The driver shakes his head. \"Inspector's not ready to go. Ask him first.\""], "Wagon Driver")
		return
	if mode == "to_town":
		var home := GameState.flag("trainers_freed")
		var ask_text := "Heading back to Scaraba? Sable's three are aboard already, and the horses are fresh. Ride?" if home \
			else "Heading back to Scaraba? The wagon's empty and the horses are fresh. Ride?"
		if not await Story.ask(ask_text, "Wagon Driver", "Ride", "Not yet"):
			return
		if home:
			# the cutaway home after the church (WP9): Sable's juniors ride back, and run for the arena
			await Story.say(["You climb up behind the driver. Sable's three juniors are wedged in the back among the feed sacks, watching the church until the town wall hides it.",
				"Ammon counts the milestones out loud. Isis-Rae tells him to stop. Djed sleeps. The wheels turn north, and the hardpan gives way to drumlins, the lake, and then the adobe walls."])
		else:
			await Story.say(["You climb up behind the driver. Grubb is already aboard, his collar turned up against the sun.",
				"The wheels turn north, and the hardpan gives way to drumlins, the lake, and then the adobe walls."])
		GameState.main.goto_map("sundown", TOWN_WAGON, Vector2i.DOWN, 0.6)
		return
	if not await Story.ask("Reed's landing first, then her boat across to Dustwell. Ride?", "Wagon Driver", "Ride", "Not yet"):
		return
	await Story.say(["Grubb sits up front with the driver and doesn't say much. Tam and Saffi are in the back, heels drumming on a sack of feed.",
		"The gate rolls open. Scaraba falls away behind the mesa's rim, and the wheels strike the camber of the old river road."])
	# (Reed waits on the west shore when the hero comes in from that side: the boat must be moored there.)
	GameState.set_flag("riverboat_west")
	GameState.main.goto_map("dustwell_channel", LANDING_WAGON, Vector2i.UP, 0.6)


## The loose stone under the cistern's cracked tile: a tilted slab beside its hole.
static func _stone_node() -> Node3D:
	var root := Node3D.new()
	var stone := _mat(Color("#9a9184"))
	var hole := _mat(Color("#2a2420"))
	var gap := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.5, 0.02, 0.5)
	gap.mesh = gm
	gap.material_override = hole
	gap.position.y = 0.01
	root.add_child(gap)
	var slab := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.52, 0.1, 0.52)
	slab.mesh = sm
	slab.material_override = stone
	slab.position = Vector3(0.34, 0.07, 0.16)
	slab.rotation = Vector3(0.1, 0.4, 0.12)
	root.add_child(slab)
	return root


## A small covered cart: four wheels, a bed, a canvas hood.
static func _cart_node() -> Node3D:
	var root := Node3D.new()
	var wood := _mat(Color("#7a5636"))
	var dark := _mat(Color("#4a3a2a"))
	var canvas := _mat(Color("#d8c8a0"))
	var bed := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.3, 0.16, 0.9)
	bed.mesh = bm
	bed.material_override = wood
	bed.position.y = 0.42
	root.add_child(bed)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var wheel := MeshInstance3D.new()
			var wm := CylinderMesh.new()
			wm.top_radius = 0.26
			wm.bottom_radius = 0.26
			wm.height = 0.1
			wm.radial_segments = 10
			wheel.mesh = wm
			wheel.material_override = dark
			wheel.rotation.z = PI / 2.0
			wheel.position = Vector3(0.45 * sx, 0.26, 0.42 * sz)
			root.add_child(wheel)
	for side in [-1, 1]:
		var rail := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(1.34, 0.06, 0.06)
		rail.mesh = rm
		rail.material_override = wood
		rail.position = Vector3(0, 0.54, 0.44 * side)
		root.add_child(rail)
	var hood := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.55
	hm.bottom_radius = 0.55
	hm.height = 1.3
	hm.radial_segments = 8
	hood.mesh = hm
	hood.material_override = canvas
	hood.rotation.z = PI / 2.0
	hood.position.y = 0.95
	root.add_child(hood)
	return root


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m


static func _gang(world) -> Array:
	if not is_instance_valid(world):
		return []
	return world.npcs.values().filter(func(n): return n.get("id", "") == "jackal_road")
