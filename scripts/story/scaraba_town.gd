extends RefCounted
## Scaraba (map `sundown`) on the hero's first visit (docs/scaraba-implementation-plan.md WP4; the outline's §3):
## the Jackals stop the hero inside the south gate (handbill, bounty, the windward charm, the raid offer); Captain
## Dalton's briefing; Windcaller Sable, who won't fight while her three juniors are missing; Inspector Grubb, who hands
## over his house and won't go down to its cistern; Tam and Saffi in the old cistern under it, who then follow the hero; and
## the town's accuser, gate proverb, caravan prayer and Tamsin's lead. Residents' chatter changes over four states
## (state(): first visit, after Valkoog, after the church, after Sable).

const BART_LOOK := {"skin": "#c8946a", "hair": "#2a1a10", "shirt": "#8a3a22", "pants": "#4a3a2a", "hat": "#3a2a1a", "outfit": "coat"}
const JACKAL_LOOKS := [{"skin": "#d8a880", "hair": "#3a2a1a", "shirt": "#7a3a2a", "pants": "#4a3a2a", "hat": "#4a3a2a"},
	{"skin": "#b07850", "hair": "#1a1210", "shirt": "#6a4a2a", "pants": "#3a2a1a", "hat": "#5a3a22"}]
## (the same inspector who holds the Mine Road checkpoint, story.gd "route6")
const GRUBB_LOOK := {"skin": "#d8a880", "hair": "#4a3a2a", "shirt": "#e8c040", "pants": "#4a4a52", "hat": "#e8c040", "outfit": "coat"}
const TAM_LOOK := {"skin": "#b07850", "hair": "#1a1210", "shirt": "#5ab0c8", "pants": "#c8b088"}
const SAFFI_LOOK := {"skin": "#b07850", "hair": "#1a1210", "shirt": "#e8d070", "pants": "#c8b088", "hair_style": 1, "body": "female"}
const ACCUSER_LOOK := {"skin": "#c89070", "hair": "#d8d0c0", "shirt": "#a83a5a", "pants": "#5a3a4a", "outfit": "robe", "hair_style": 1, "body": "female"}
const WARDEN_LOOK := {"skin": "#a87050", "hair": "#e8e0d0", "shirt": "#2f4a7a", "pants": "#e2d4b4", "hat": "#ece2cc", "outfit": "coat"}
const DRIVER_LOOK := {"skin": "#d8a880", "hair": "#5a3a22", "shirt": "#c89040", "pants": "#5a4a3a", "hat": "#e8d8a0"}
const TAMSIN_LOOK := {"skin": "#f0c8a0", "hair": "#8a3a20", "hair_style": 1, "body": "female", "shirt": "#f2c14e", "pants": "#3a5a4a", "hat": "#c86a3a", "pack": true}
## Sable's three juniors (U17), missing until the church; their places in her arena stand empty until they're home
const JUNIORS := ["Ammon", "Isis-Rae", "Djed"]
const JUNIOR_LOOKS := [{"skin": "#c89070", "hair": "#2a1a10", "shirt": "#3a7ab0", "pants": "#3a3a48"},
	{"skin": "#e8c0a0", "hair": "#8a5a2a", "shirt": "#b04a6a", "pants": "#4a3a4a", "body": "female", "hair_style": 1},
	{"skin": "#a87050", "hair": "#1a1210", "shirt": "#c8a040", "pants": "#3a4a3a"}]
const JUNIOR_PLACES := [Vector2i(1, 3), Vector2i(11, 3), Vector2i(11, 4)]
## where the Jackals stand just inside the south gate, and where they walk off to
const GATE_JACKALS := [Vector2i(15, 25), Vector2i(13, 25), Vector2i(16, 25)]
const GRUBB_AT := Vector2i(6, 21)
## (set by the screenshot test to keep the Jackals standing at the gate without stopping the hero)
static var hold_gate := false


static func state() -> String:
	if GameState.flag("north_road_open"):
		return "sable"
	if GameState.flag("trainers_freed"):
		return "church"
	if GameState.flag("guardian_air"):
		return "valkoog"
	return "first"


## Scaraba's story people (Story.extra_npcs), and in its buildings the arena's empty places and the twins.
static func npcs(map: Dictionary) -> Array:
	var out := []
	var parent := String(map.get("parent", map.get("id", "")))
	if map.get("id", "") == "sundown":
		if not GameState.flag("met_jackals"):
			for i in 3:
				out.append({"kind": "story", "id": "scaraba_jackal", "name": "Bart the Jackal" if i == 0 else "Jackal",
					"pos": GATE_JACKALS[i], "look": BART_LOOK if i == 0 else JACKAL_LOOKS[i - 1], "facing": Vector2i(0, 1), "still": true, "blocking": true})
		if not GameState.flag("grubb_report"):
			out.append({"kind": "story", "id": "grubb", "name": "Inspector Grubb", "pos": GRUBB_AT, "look": GRUBB_LOOK, "facing": Vector2i(0, 1),
				"still": true, "story": not GameState.flag("met_grubb")})
		out.append({"kind": "story", "id": "scaraba_accuser", "name": "Madam Hadiza", "pos": Vector2i(19, 12), "look": ACCUSER_LOOK, "facing": Vector2i(0, 1), "still": true})
		out.append({"kind": "story", "id": "scaraba_warden", "name": "Gatewarden Omari", "pos": Vector2i(17, 27), "look": WARDEN_LOOK, "facing": Vector2i(-1, 0), "still": true})
		out.append({"kind": "story", "id": "scaraba_driver", "name": "Caravan Driver Nkem", "pos": Vector2i(25, 12), "look": DRIVER_LOOK, "facing": Vector2i(0, 1), "still": true})
		if not GameState.flag("trainers_freed"):
			out.append({"kind": "story", "id": "scaraba_tamsin", "name": "Tamsin", "pos": Vector2i(27, 12), "look": TAMSIN_LOOK, "facing": Vector2i(0, 1), "still": true,
				"story": not GameState.flag("tamsin_lead")})
	elif parent == "sundown" and map.get("room_key", "") == "arena":
		if GameState.flag("trainers_freed"):
			# (home from the church: they ran ahead to the arena while the wagon came in)
			for i in 3:
				out.append(_junior(i, JUNIOR_PLACES[i]))
		else:
			for i in 3:
				out.append({"kind": "story", "id": "junior_place", "junior": i, "name": "", "pos": JUNIOR_PLACES[i], "scene": _empty_place(i),
					"facing": Vector2i(0, 1), "still": true})
	elif map.get("room_key", "") == "twins_cistern" and not GameState.flag("met_twins"):
		var tam: Vector2i = map.get("anchors", {}).get("tam", Vector2i(3, 3))
		var saffi: Vector2i = map.get("anchors", {}).get("saffi", Vector2i(6, 3))
		out.append({"kind": "story", "id": "twin", "twin": "tam", "name": "Tam", "pos": tam, "look": TAM_LOOK, "facing": Vector2i(0, 1), "still": true,
			"scale": 0.72, "story": true})
		out.append({"kind": "story", "id": "twin", "twin": "saffi", "name": "Saffi", "pos": saffi, "look": SAFFI_LOOK, "facing": Vector2i(0, 1), "still": true,
			"scale": 0.72, "story": true})
	return out


static func talk(world, n: Dictionary) -> void:
	match String(n["id"]):
		"scaraba_jackal":
			await gate_scene(world)
		"grubb":
			await _grubb(world, n)
		"twin":
			await _twins(world)
		"junior_place":
			var name: String = JUNIORS[int(n["junior"])]
			await Story.say(["%s's place at the ringside. A rolled-up practice banner, a water gourd, and a towel folded just so. Nobody's touched them in days." % name])
		"junior":
			var i := int(n.get("junior", 0))
			await Story.say(["Sable's got a list of everything we missed. It's a long list.",
				"Go on, challenge her. She's been waiting for someone worth it."], JUNIORS[i])
		"scaraba_accuser":
			await _accuser()
		"scaraba_warden":
			await Story.say([["The desert tests whoever crosses it. Finding the way by the star is the test. Arriving is just the answer.",
					"That's what my grandmother told every caravan at this gate. Most of them nodded and got lost anyway."],
				["Back from the temple? Then the desert's let you pass twice. That's more than it does for most."],
				["The trainers are home, they say. The gate bell rang for an hour. My ears are still ringing."],
				["Riposo Valley's past the north gate. The soldiers there say you've earned it. I'd say so too."]][["first", "valkoog", "church", "sable"].find(state())], "Gatewarden Omari")
		"scaraba_driver":
			await Story.say(["Before every crossing we say the caravan prayer: \"Winds, keep the way. Stars, show the way. Sand, forget we passed.\"",
				"Three caravans haven't come back this week. I've started saying it twice."] if state() == "first"
				else ["The caravans are rolling again. I still say the prayer. Twice. Habits are hard to break."], "Caravan Driver Nkem")
		"scaraba_tamsin":
			await _tamsin()


## The Jackals just inside the south gate (on the first walk into town, or talking to them): Bart's handbill, the
## bounty on the twins, the windward charm, and his offer.
static func gate_scene(world) -> void:
	if GameState.flag("met_jackals"):
		return
	GameState.set_flag("met_jackals")
	var bart := "Bart the Jackal"
	await Story.say(["Whoa there, sandwalker. Welcome to Scaraba. You look like a trainer who can handle themself.",
		"Name's Bart. Me and the boys are the Jackals. We keep the roads... interesting."], bart)
	GameState.receive_item("jackal_handbill")
	UI.toast("Received the Jackals' Handbill!", "item:jackal_handbill")
	await Story.say(["Here, read this. Two little thieves have been robbing this town blind: a boy and a girl, twins, about so high.",
		"Air wizards, the pair of them. They blow purses right out of people's hands. There's a bounty, and the town wants them gone."], bart)
	await Story.say(["You've heard trainers are going missing out here? Word is, the wizards in Valkoog are behind it. Hiding in that pyramid, handing out stones to children.",
		"So we're going to raid the place. Clean it out. And a trainer like you could come along for a share."], bart)
	GameState.receive_item("windward_charm")
	Sfx.play("capture")
	UI.toast("Received the Windward Charm!", "item:windward_charm")
	await Story.say(["Take this, on the house. A windward charm. Jackal-made. It turns the wind aside when an air wizard throws it at you.",
		"Don't thank me. A dead partner's no use to anyone."], bart)
	await Story.say(["One snag. Valkoog's full of traps, and only a mage gets past them. So first we need those twins.",
		"Find the kids, and we'll carry them through. Then we split the hoard. Think about it, partner."], bart)
	if world != null:
		var gone := []
		for p in world.npcs:
			if world.npcs[p].get("id", "") == "scaraba_jackal":
				gone.append(world.npcs[p])
		for n in gone:
			var path := []
			for k in range(1, 4):
				path.append(Vector2i(n["pos"].x, n["pos"].y - k))
			world.walk_npc_aside(n, path, Vector2i(0, -1))
		await GameState.main.get_tree().create_timer(1.1).timeout
		for n in gone:
			world.remove_npc(n)


## Dalton's briefing, rewritten (WP4): three caravans and three trainers, the seals and the tag, why the watch can't
## move, and why the pyramid goes unguarded. (Story._sheriff calls this before the bounty.)
static func dalton_briefing() -> void:
	var first := not GameState.flag("met_sheriff")
	GameState.set_flag("met_sheriff")
	var dalton := "Captain Dalton"
	if not first:
		await Story.say(["Find out what's under all this. I can't touch Gearheart, but I can hold a road open for whoever can."
			if not GameState.flag("met_twins") else "Grubb's niece and nephew, mixed up with Valkoog? Then go. Bring me something from inside I can act on."], dalton)
		return
	await Story.say(["Welcome to Scaraba. Captain Dalton, gate watch. You came across the desert? On foot? Then you've got more sense than most, or less.",
		"Three caravans gone this week. Three young trainers with them. Every abandoned wagon we find has the same seal on it: Gearheart freight."], dalton)
	if GameState.item_count("freight_tag") > 0:
		await Story.say(["Hold on. Where did you get that tag? Mesa Trail scree? ...That's the same seal. Same freight number series, too.",
			"That's the first thing I've had that ties a Gearheart wagon to the trainers' road. I'll copy the number down. Keep the tag."], dalton)
	else:
		await Story.say(["If you came up the Mesa Trail and saw anything with that seal on it, I'd want to know. It'd be the first thing I could act on."], dalton)
	await Story.say(["Why don't I ride out myself? My watch is on the gate and the caravans, every hour of the day, and the Jackals know it.",
		"And even if I caught a wagon, the law stops at Cogsworth's contracts. Gearheart freight is Gearheart's business, on paper."], dalton)
	await Story.say(["Valkoog? Nobody guards it. Nobody needs to. The traps have kept everyone out for a hundred years.",
		"If the Jackals think there's treasure in there, let them break their necks finding out. The pyramid can wait until somebody brings me something from inside."], dalton)


## The juniors come home after the church (docs/scaraba-implementation-plan.md WP9): Sable sees them at their places,
## and her arena opens (sable_trainers_home).
static func _juniors_home(world) -> void:
	GameState.set_flag("sable_trainers_home")
	await Story.say(["The arena is quiet except for the wind in the high windows. Sable is on the bottom bench with three rolled-up practice banners across her knees.",
		"Then she looks up. Ammon, Isis-Rae and Djed are at their places, still in their road clothes and cave dust."])
	await Story.say(["\"You're late,\" Sable says. \"All three of you. Late for practice, late for me.\"",
		"\"We were in a cage, Windcaller,\" says Djed.",
		"\"Then you're late for practice,\" she says, and holds all three of them at once."], "Windcaller Sable")
	await Story.say(["She straightens up and looks at you over their heads. \"You brought them home. The arena opens for you. Whenever you're ready, I'll show you the wind.\""], "Windcaller Sable")
	UI.toast("Sable's arena is open again.", "pin")
	if is_instance_valid(world):
		world.refresh_npc_marks()


## One of Sable's juniors at their ringside place, home again.
static func _junior(i: int, at: Vector2i) -> Dictionary:
	return {"kind": "story", "id": "junior", "junior": i, "name": JUNIORS[i], "pos": at, "look": JUNIOR_LOOKS[i],
		"facing": Vector2i(0, 1), "still": true, "story": true}


## Sable won't fight while her three juniors are missing (A14).
static func sable_waits(leader: String) -> void:
	GameState.set_flag("met_sable")
	await Story.say(["Not today, trainer. The arena doesn't open with empty benches.",
		"Ammon, Isis-Rae and Djed. My three juniors. They rode out with the last caravan and never rode back.",
		"Find what happened to those caravans, and you'll find them. Bring them home, and I'll give you the hardest battle this town has."], leader)


static func _accuser() -> void:
	match state():
		"first":
			await Story.say(["My purse! Snatched right out of my hand by a gust of wind, in the middle of the market!",
				"There's no wind like that in the market. It was those twins. Everyone says so. The Jackals put up the handbills to prove it."], "Madam Hadiza")
		"valkoog":
			await Story.say(["The Jackals took their handbills down in a hurry. Funny. My purse turned up in Bart's crew's camp, the watch says.",
				"...I'm not apologising to a pair of eight-year-olds. Not yet."], "Madam Hadiza")
		_:
			await Story.say(["I baked the twins a date cake. It's an apology. Don't tell anyone it's an apology."], "Madam Hadiza")


static func _tamsin() -> void:
	GameState.set_flag("tamsin_lead")
	await Story.say(["You! From Dustwell! I followed Orin's trail all the way here. I'm not going home without him.",
		"Here's what I found: the men who hang around Dustwell's old church have the same jackal brand on their boots as Bart's crew.",
		"The church, the Jackals, the missing trainers... It's all one gang. I'd bet my pack on it."], "Tamsin")


static func _grubb(world, n: Dictionary) -> void:
	# after Valkoog and the road fight: the anticlimax. He does not care about arch-wizards; he cares about trainers.
	if GameState.flag("guardian_air") and GameState.flag("jackals_ambush") and not GameState.flag("grubb_report"):
		GameState.set_flag("grubb_report")
		await Story.say(["You're back. The whole town's talking about a wind out of the pyramid, and a fight on the road. I don't care about either.",
			"Three trainers. Three caravans. Did you learn anything in there about any of them? Anything I can put in a report?"], "Inspector Grubb")
		await Story.say(["Nothing in the temple keeps trainers. Only a pipe under the sand, stamped with a Gearheart mark.",
			"Then it's the Jackals. They've been sitting on this town like a lid, and every lead I pull, one of their handbills is under it.",
			"I'm going to Dustwell. There's an old church there the gang's been using, and I mean to be at its door when they open it."], "Inspector Grubb")
		await Story.say(["The gate wagon goes as far as Reed's landing. Be on it, all four of you. And bring that bundle of handbills if you found it."], "Inspector Grubb")
		UI.toast("Grubb is waiting at the gate wagon.")
		return
	if GameState.flag("met_twins"):
		await Story.say(["They're with you? Good. Keep them close, and keep them away from the Jackals.",
			"And if you hear anything in that pyramid about the missing trainers, I want to know. That's my job here. That, and nothing else."], "Inspector Grubb")
		return
	if GameState.flag("met_grubb"):
		await Story.say(["The way down is at the back of the house. I'm not going down there. A company inspector seen searching his own house? I'd be finished.",
			"Just... make sure they're all right."], "Inspector Grubb")
		return
	GameState.set_flag("met_grubb")
	n["story"] = false
	await Story.say(["Inspector Grubb, Gearheart Industries. I'm in Scaraba over the missing trainers. Company business.",
		"...You've seen the handbill. The twins the whole town's hunting are my niece and nephew. Tam and Saffi. They're eight.",
		"They didn't steal anything. They played tricks with the wind, yes. Then the Jackals said 'thieves', and the town believed them."], "Inspector Grubb")
	await Story.say(["This is my house. There's an old cistern under it, with a way down at the back. That's where they're hiding.",
		"I can't go down there. If anyone saw a Gearheart inspector hiding the town's thieves, the company would have me out by sundown. Here, take the key.",
		"Go and talk to them. They won't trust me. They might trust you."], "Inspector Grubb")
	UI.toast("Grubb unlocked his house.")
	world.refresh_locks()


## Tam and Saffi in the cistern: their side, and the favour (Valkoog), then they follow the hero.
static func _twins(world) -> void:
	if GameState.flag("met_twins"):
		return
	await Story.say(["Don't come any closer! I'm the oldest! By ten whole minutes! I'll blow you right back up those stairs!"], "Tam")
	await Story.say(["Tam. They came down the stairs. Uncle Grubb must have sent them.", "Hi. I'm Saffi. He's Tam. He's going to tell you he's the oldest."], "Saffi")
	await Story.say(["I'm the oldest."], "Tam")
	await Story.say(["We never stole anything. We found air stones in the sand by Valkoog, and the wind started listening to us. We used it for jokes. Hats, mostly.",
		"Then the Jackals put up those handbills. Now everyone thinks we're thieves, so the town will hand us over, and the Jackals get us without a fight."], "Saffi")
	await Story.say(["They don't want us for the bounty. They want us for the temple. Only a mage gets past the traps. We're keys."], "Tam")
	await Story.say(["There are wizards inside Valkoog. Real ones. Somebody has to warn them the Jackals are coming, and that they mean to use us.",
		"Will you take us there? You can't open the doors without air magic. But we can. Probably."], "Saffi")
	await Story.say(["Definitely. I'm the oldest."], "Tam")
	GameState.set_flag("met_twins")
	Sfx.play("capture")
	UI.toast("Tam and Saffi are coming with you!")
	for p in world.npcs.keys():
		if world.npcs[p].get("id", "") == "twin":
			world.remove_npc(world.npcs[p])


# ---------------------------------------------------------------- the town's arrival and the twins following
## Map arrival (Story.on_map_enter): the Jackals stop the hero just inside the south gate, and the twins walk behind
## the hero through Scaraba and the desert once they've joined, until Valkoog (P6) takes them on.
static func on_enter(world) -> void:
	# home from the church: Sable's juniors are at their places, and she sees them (WP9)
	if String(world.map_id).begins_with("sundown#") and String(world.map.get("room_key", "")) == "arena" \
			and GameState.flag("trainers_freed") and not GameState.flag("sable_trainers_home"):
		await _juniors_home(world)
	# (and to Dustwell for the church, once Grubb's report is in)
	var in_dustwell: bool = world.map_id == "dustwell" or String(world.map_id).begins_with("dustwell#8")
	if (world.map_id in ["sundown", "route5"] or in_dustwell and GameState.flag("grubb_report")) and GameState.flag("met_twins") and not GameState.flag("twins_home"):
		var f: Node3D = preload("res://scripts/story/twin_followers.gd").new()
		f.name = "TwinFollowers"
		world.add_child(f)
		f.setup(world, [TAM_LOOK, SAFFI_LOOK])
	if world.map_id == "sundown" and not GameState.flag("met_jackals") and world.player_pos.y >= 24 and not hold_gate:
		await gate_scene(world)


## A junior's empty place at the ringside: a low bench with a rolled-up banner.
static func _empty_place(i: int) -> Node3D:
	var root := Node3D.new()
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("#8a5a32")
	var seat := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.7, 0.12, 0.4)
	seat.mesh = bm
	seat.material_override = wood
	seat.position.y = 0.42
	root.add_child(seat)
	for side in [-1, 1]:
		var leg := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.08, 0.4, 0.34)
		leg.mesh = lm
		leg.material_override = wood
		leg.position = Vector3(0.28 * side, 0.2, 0)
		root.add_child(leg)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = [Color("#c8384e"), Color("#3a8ab0"), Color("#d89a28")][i]
	var banner := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.07
	cm.bottom_radius = 0.07
	cm.height = 0.5
	banner.mesh = cm
	banner.material_override = cloth
	banner.rotation.z = PI / 2.0
	banner.position.y = 0.55
	root.add_child(banner)
	return root
