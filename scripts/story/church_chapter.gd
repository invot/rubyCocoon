extends RefCounted
## The Dustwell church and its undercroft (docs/scaraba-implementation-plan.md WP8; the outline's §5).
##   - After P7's report, Grubb waits at the church door and unlocks it with his inspector's key (church_entered).
##     Hoss and Clem are inside: Hoss by his strongbox with the old mage story, Clem quiet by the well, Grubb at the
##     door. The well goes down into the undercroft.
##   - The undercroft reuses the town well's cave shapes in a harder palette: the Jackals' sentries, the five beavers
##     (friendly now, they were beaten in the well arc), a flooded gallery, and the barred door they chew through.
##   - Behind the door: Lio, Bea, Orin and Sable's three juniors. Hoss comes down, is cornered and confesses (A8),
##     then fights for the strongbox key; beaten, he hands it over and the Jackals disband.
##   - Upstairs again, the strongbox gives the coded ledger and the freight manifest. On the square the searchers and
##     the freed trainers have their reunion (trainers_freed), and Clem says his farewell (clem_left).
const TempleProps = preload("res://scripts/gfx/temple_props.gd")
const TrainerCell = preload("res://scripts/story/trainer_cell.gd")
const ScarabaTown = preload("res://scripts/story/scaraba_town.gd")

const CHURCH := "dustwell#8"
const NAVE := "church_nave"
const CELLAR := "church_cellar"
const GALLERY := "church_gallery"
const BARRED := "church_barred"
const ROOM := "church_room"
## The church door is at (39, 18); the hero comes out below it, where Grubb waits.
const OUT_GRUBB := Vector2i(38, 20)
## Where the freed trainers and Sable's juniors stand at the church door, and the searchers come round for the reunion.
const OUT_TRAINERS := [Vector2i(37, 19), Vector2i(41, 19), Vector2i(39, 20)]
const OUT_JUNIORS := [Vector2i(36, 19), Vector2i(38, 19), Vector2i(40, 19)]
const SEARCH_AT := [Vector2i(36, 20), Vector2i(38, 20), Vector2i(40, 20)]
const OUT_CLEM := Vector2i(42, 19)

const GRUBB_AT := Vector2i(2, 10)
const HOSS_AT := Vector2i(12, 9)
const CLEM_AT := Vector2i(6, 3)
const WELL_AT := Vector2i(4, 8)
const STRONGBOX_AT := Vector2i(13, 9)
const EMBLEM_AT := Vector2i(8, 0)
const BEAVER_AT := [Vector2i(5, 3), Vector2i(9, 3), Vector2i(13, 3), Vector2i(6, 7), Vector2i(12, 7)]
const SENTRY_AT := [Vector2i(16, 4), Vector2i(15, 7), Vector2i(12, 4)]
const ROOM_HOSS := Vector2i(12, 8)
const ROOM_TRAINERS := [Vector2i(4, 3), Vector2i(8, 3), Vector2i(12, 3)]
const ROOM_JUNIORS := [Vector2i(4, 6), Vector2i(8, 6), Vector2i(12, 6)]

const HOSS_LOOK := {"skin": "#c8946c", "hair": "#2a1a12", "shirt": "#6a3a3a", "pants": "#3a3036", "hat": "#2e2622", "outfit": "coat"}
const CLEM_LOOK := {"skin": "#e0b48c", "hair": "#8a5a2a", "shirt": "#a8743a", "pants": "#4a3a2e", "hat": "#5a3e26", "outfit": "coat"}
const SENTRY_LOOKS := [{"skin": "#d8a880", "hair": "#3a2a1a", "shirt": "#7a3a2a", "pants": "#4a3a2a", "hat": "#4a3a2a"},
	{"skin": "#b07850", "hair": "#1a1210", "shirt": "#6a4a2a", "pants": "#3a2a1a", "hat": "#5a3a22"}]
const BEAVERS := ["Pebble", "Nub", "Dibble", "Crumb", "Velvet"]


# ---------------------------------------------------------------- who is where
static func npcs(map: Dictionary) -> Array:
	var out := []
	var id := String(map.get("id", ""))
	var room := String(map.get("room_key", ""))
	if id == "dustwell":
		# the inspector waits by the door until it's open
		if GameState.flag("grubb_report") and not GameState.flag("church_entered"):
			out.append(_grubb(OUT_GRUBB, false))
		if GameState.flag("hoss_confessed") and not GameState.flag("trainers_freed"):
			for i in 3:
				out.append(_trainer(i, OUT_TRAINERS[i]))
			for i in 3:
				out.append(_junior(i, OUT_JUNIORS[i]))
		elif GameState.flag("trainers_freed") and not GameState.flag("clem_left"):
			# (a saved game interrupted mid-reunion still gets Clem's farewell; the trainers have gone home)
			out.append(_clem(OUT_CLEM, true))
	elif room.begins_with("church_"):
		match room:
			NAVE:
				if GameState.flag("church_entered"):
					out.append(_well())
					out.append(_strongbox())
					out.append(_emblem())
				if GameState.flag("church_entered") and not GameState.flag("hoss_confessed"):
					out.append(_hoss(HOSS_AT, "nave"))
					out.append(_clem(CLEM_AT, false))
				if GameState.flag("church_entered") and not GameState.flag("trainers_freed"):
					out.append(_grubb(GRUBB_AT, true))
			CELLAR:
				if not GameState.flag("undercroft_beavers"):
					for i in 5:
						out.append(_beaver(i))
				for i in 2:
					if not GameState.flag("church_sentry_%d" % i):
						out.append(_sentry(i))
			GALLERY:
				if not GameState.flag("church_sentry_2"):
					out.append(_sentry(2))
			ROOM:
				if GameState.flag("church_entered") and not GameState.flag("trainers_freed"):
					out.append(_hoss(ROOM_HOSS, "room"))
				for i in 3:
					out.append(_trainer(i, ROOM_TRAINERS[i]))
				for i in 3:
					out.append(_junior(i, ROOM_JUNIORS[i]))
	return out


static func talk(world, n: Dictionary) -> void:
	match String(n["id"]):
		"church_grubb":
			await _unlock(world, n)
		"church_strongbox":
			await _strongbox_talk()
		"church_emblem":
			await Story.say(["A ring of beaten bronze set into the wall, and a smaller ring within it. The elemental mages' sign.",
				"There's no cross anywhere in this church. Whoever raised it never wanted one."])
		"church_well":
			await _well_talk()
		"church_hoss":
			await _hoss_talk(n)
		"church_clem":
			await _clem_talk(n)
		"church_beaver":
			await _beaver_talk(world)
		"church_sentry":
			await _sentry_fight(world, n)
		"church_trainer":
			await _trainer_talk(n)
		"church_junior":
			await _junior_talk(n)


## The first entry into the church and its undercroft: the beavers come along, the door is chewed, Hoss confesses,
## and the square has its reunion.
static func on_enter(world) -> void:
	var room := String(world.map.get("room_key", ""))
	if room.begins_with("church_"):
		if room in [CELLAR, GALLERY, BARRED] and GameState.flag("undercroft_beavers") and not GameState.flag("trainers_door"):
			_followers(world)
		if room == BARRED and GameState.flag("undercroft_beavers") and not GameState.flag("trainers_door"):
			await _chew(world)
		elif room == ROOM and GameState.flag("church_entered") and not GameState.flag("hoss_confessed"):
			await _hoss_scene(world)
	elif String(world.map_id) == "dustwell" and GameState.flag("hoss_confessed") and not GameState.flag("trainers_freed"):
		await _reunion(world)


# ---------------------------------------------------------------- the door, Grubb and the nave
static func _grubb(at: Vector2i, inside: bool) -> Dictionary:
	return {"kind": "story", "id": "church_grubb", "name": "Inspector Grubb", "pos": at, "look": _grubb_look(), "facing": Vector2i(0, 1),
		"still": true, "story": not inside}


static func _grubb_look() -> Dictionary:
	return {"skin": "#d8a880", "hair": "#4a3a2a", "shirt": "#e8c040", "pants": "#4a4a52", "hat": "#e8c040", "outfit": "coat"}


static func _unlock(world, n: Dictionary) -> void:
	if GameState.flag("church_entered"):
		await Story.say(["Grubb has his notebook out at the door, writing down the state of the lock."], "Inspector Grubb")
		return
	await Story.say(["There you are. The church has been barred since before I got to Dustwell. From the inside.", "Inspector's key. Old building, older lock. Stand back."], "Inspector Grubb")
	Sfx.play("door")
	GameState.set_flag("church_entered")
	await Story.say(["The door swings in on a cold, dry nave. Two men are already standing at the far end, and neither of them looks pleased to see you.", "I'll stay at the door. A company inspector does not climb down wells."], "Inspector Grubb")
	UI.toast("The church is open.")
	if is_instance_valid(world) and world.npcs.values().has(n):
		world.remove_npc(n)


static func _hoss(at: Vector2i, where: String) -> Dictionary:
	return {"kind": "story", "id": "church_hoss", "name": "Bandit Hoss", "pos": at, "look": HOSS_LOOK, "facing": Vector2i(0, 1),
		"still": true, "story": where == "nave"}


static func _clem(at: Vector2i, farewell: bool) -> Dictionary:
	return {"kind": "story", "id": "church_clem", "name": "Clem", "pos": at, "look": CLEM_LOOK, "facing": Vector2i(0, 1),
		"still": true, "story": farewell}


static func _hoss_talk(n: Dictionary) -> void:
	if GameState.flag("hoss_confessed"):
		await Story.say(["Hoss sits with his back to the wall, the fight gone out of him. He doesn't look up."], "Bandit Hoss")
		return
	await Story.say(["This here church belonged to them elemental wizards once. It's ours now.",
		"Trainers keep going missing, and who's behind it? Wizards. Every one of them. Stands to reason.",
		"You're the one from Scaraba. Grubb's hound. Come to look down our well?"], "Bandit Hoss")
	await Story.say(["Go on, then. Look. See what the mages left down there. The town's been drinking from that well for years, and never once asked where the water came from."], "Bandit Hoss")
	await Story.say(["Clem, keep your mouth shut."], "Bandit Hoss")


static func _clem_talk(n: Dictionary) -> void:
	if GameState.flag("clem_left"):
		await Story.say(["Clem is gone. The church is quiet."], "Clem")
		return
	if n.get("story", false) and GameState.flag("trainers_freed"):
		await _clem_farewell()
		return
	await Story.say(["...", "You're the one who went down the town well. The beavers liked you."], "Clem")
	await Story.say(["Hoss talks about wizards all day. He's wrong about them. Not about everything."], "Clem")


static func _well() -> Dictionary:
	return {"kind": "story", "id": "church_well", "name": "Church Well", "pos": WELL_AT, "scene": _well_node(), "still": true,
		"facing": Vector2i(0, 1), "story": true}


static func _strongbox() -> Dictionary:
	var open := GameState.item_count("coded_ledger") > 0
	return {"kind": "story", "id": "church_strongbox", "name": "Strongbox", "pos": STRONGBOX_AT, "scene": TempleProps.chest(open),
		"still": true, "facing": Vector2i(0, 1), "story": true, "mark_height": 0.9}


static func _emblem() -> Dictionary:
	return {"kind": "story", "id": "church_emblem", "name": "", "pos": EMBLEM_AT, "scene": _emblem_node(), "still": true,
		"visual_offset": Vector3(0, 1.55, 0.3), "mark_height": 1.7}


static func _well_talk() -> void:
	await Story.say(["The church well. Its stone ring is newer than the steps beside it: worn steps, cut into the shaft wall, going down into the dark.",
		"The mages kept their church over it. Hoss kept his secrets down it."])


static func _strongbox_talk() -> void:
	if GameState.item_count("coded_ledger") > 0:
		await Story.say(["The strongbox is empty now."])
		return
	if not GameState.flag("hoss_confessed"):
		await Story.say(["Hoss's strongbox. Locked, and the key is on his belt."])
		return
	Sfx.play("buy")
	GameState.receive_item("coded_ledger")
	GameState.receive_item("freight_manifest")
	await Story.say(["Hoss's key turns in the strongbox. Inside: a ledger written in a freight cipher, and a Gearheart manifest folded in behind it.",
		"Dates, payments, names. The trainers are entered as freight, and the depot at Cogsworth takes delivery.",
		"The ledger and the manifest go in your bag."])
	UI.toast("Hoss's ledger and the manifest.")


# ---------------------------------------------------------------- the undercroft
static func _beaver(i: int) -> Dictionary:
	return {"kind": "story", "id": "church_beaver", "name": BEAVERS[i], "pos": BEAVER_AT[i], "look": {"critter": "beaver"},
		"facing": Vector2i(0, 1), "still": true, "story": true}


static func _sentry(i: int) -> Dictionary:
	return {"kind": "story", "id": "church_sentry", "sentry": i, "name": "Jackal Sentry", "pos": SENTRY_AT[i], "look": SENTRY_LOOKS[i % 2],
		"facing": Vector2i(0, 1), "still": true, "story": true}


static func _beaver_talk(world) -> void:
	if GameState.flag("undercroft_beavers"):
		await Story.say(["The beaver gives a toothy nod and keeps close."])
		return
	GameState.set_flag("undercroft_beavers")
	await Story.say(["Pebble! The third strongest beaver in the whole well! You came back!", "And you brought friends. And a ladder. We heard the chewing stop upstairs."], "Pebble")
	await Story.say(["The well's gone quiet since the water came back. Too quiet. No dams to build, no trainers to fight.", "We're coming with you. Our teeth are good for more than dams."], "Nub")
	var others: Array = world.npcs.values().filter(func(n): return n.get("id", "") == "church_beaver")
	for n in others:
		world.remove_npc(n)
	_followers(world)
	UI.toast("The beavers are following you.")


## The five beavers walk behind the hero through the undercroft (the twins' follower, five critters wide).
static func _followers(world) -> void:
	if not is_instance_valid(world) or world.get_node_or_null("BeaverFollowers") != null:
		return
	var f: Node3D = preload("res://scripts/story/twin_followers.gd").new()
	f.name = "BeaverFollowers"
	world.add_child(f)
	var looks := []
	for i in 5:
		looks.append({"critter": "beaver"})
	f.setup(world, looks, 1.0)


static func _chew(world) -> void:
	GameState.set_flag("trainers_door")
	await Story.say(["The beavers fan out along the barred door, tails drumming, and set their teeth to the frame.", "Chew, chew, chew. The old wood gives all at once and the door drops into the room beyond."],
		"Pebble")
	await Story.say(["\"Third strongest beaver says chew,\" says the third strongest beaver, last."], "Velvet")
	UI.toast("The beavers have chewed through the door.")
	world.refresh_npc_marks()


static func _sentry_fight(world, n: Dictionary) -> void:
	var i := int(n.get("sentry", 0))
	if GameState.flag("church_sentry_%d" % i):
		await Story.say(["The sentry won't meet your eye."], "Jackal Sentry")
		return
	await Story.say(["You're not supposed to be down here. Nobody's supposed to be down here."], "Jackal Sentry")
	var res: String = await Story.trainer_battle({"name": "Jackal Sentry", "cls": "Jackal", "look": SENTRY_LOOKS[i % 2],
		"team": [[6, 22, false], [33, 22, false]], "defeat": "All right! All right. I'm going."})
	if res != "win":
		return
	GameState.set_flag("church_sentry_%d" % i)
	UI.toast("The sentry has run for the ladder.")
	if is_instance_valid(world) and world.npcs.values().has(n):
		world.remove_npc(n)


# ---------------------------------------------------------------- the confession
static func _hoss_scene(world) -> void:
	if GameState.flag("hoss_confessed"):
		return
	await Story.say(["Boots on the ladder. Hoss comes down last, breathing hard, and puts himself between you and the door.",
		"Clem's behind him, and stays behind him."], "Bandit Hoss")
	await Story.say(["You went down our well. You broke our door. You turned my crew around.", "All right. You want the truth? Here it is, and the trainers can hear it too."], "Bandit Hoss")
	await Story.say(["The mage story was a front. There's no wizard taking trainers. There's a buyer, and the buyer pays in Gearheart freight.",
		"The trainers were my trade. Every one of them. I kept the books in the strongbox by the church door, and I kept them for days like this."], "Bandit Hoss")
	await Story.say(["Now get out of my church."], "Bandit Hoss")
	var res: String = await Story.trainer_battle(hoss_def())
	if res != "win":
		return
	GameState.set_flag("hoss_confessed")
	GameState.set_flag("jackals_disbanded")
	await Story.say(["Hoss goes down hard and stays down. When he gets up, he's holding out a key.",
		"\"The strongbox. By the door. Take it and get out.\""], "Bandit Hoss")
	UI.toast("Hoss has given up the strongbox key. The Jackals are standing down.")


static func hoss_def() -> Dictionary:
	return {"name": "Hoss", "cls": "Jackal Boss", "look": HOSS_LOOK,
		"team": [[12, 26, false], [21, 26, false], [9, 27, false]], "shield": 1,
		"defeat": "Enough! Nobody's paying me enough for this."}


static func _trainer(i: int, at: Vector2i) -> Dictionary:
	return {"kind": "story", "id": "church_trainer", "trainer": i, "name": TrainerCell.NAMES[i], "pos": at, "look": TrainerCell.LOOKS[i],
		"facing": Vector2i(0, 1), "still": true, "story": GameState.flag("trainers_freed")}


static func _junior(i: int, at: Vector2i) -> Dictionary:
	return {"kind": "story", "id": "church_junior", "junior": i, "name": ScarabaTown.JUNIORS[i], "pos": at, "look": ScarabaTown.JUNIOR_LOOKS[i],
		"facing": Vector2i(0, 1), "still": true, "story": GameState.flag("trainers_freed")}


static func _trainer_talk(n: Dictionary) -> void:
	var i := int(n.get("trainer", 0))
	if not GameState.flag("hoss_confessed"):
		await Story.say(["A trainer looks up from the floor. \"You came down here for us?\""], TrainerCell.NAMES[i])
		return
	await Story.say(["Lio: \"They fed us, at least. It's the waiting that was the worst.\"",
		"Bea: \"You're the one who opened the cages. Hoss said nobody would.\"",
		"Orin: \"When we're up top, I've got a letter to finish.\""], TrainerCell.NAMES[i])


static func _junior_talk(n: Dictionary) -> void:
	var i := int(n.get("junior", 0))
	if not GameState.flag("hoss_confessed"):
		await Story.say(["One of Sable's juniors. \"She'll be waiting at the arena. She's always waiting.\""], ScarabaTown.JUNIORS[i])
		return
	await Story.say(["We're going home to Scaraba with you. Sable's going to be furious, and I can't wait."], ScarabaTown.JUNIORS[i])


# ---------------------------------------------------------------- the reunion and Clem
static func _reunion(world) -> void:
	await Story.say(["The church door bangs open and the whole square turns to look. Sable's juniors come out first, blinking in the sun."])
	await Story.say(["Lio! LIO! You're really— put me down, you're covered in cave dirt—"], "Kip")
	await Story.say(["Bea! You wrote! You're home!"], "Junie")
	await Story.say(["Orin. Orin, I looked everywhere. ...Don't you dare say you're sorry."], "Tamsin")
	await Story.say(["The trainers are home, and the square fills up with people who put up posters and people who read them. Somebody starts ringing the gate bell.",
		"The posters come down. All of them, except one, for luck."])
	GameState.set_flag("trainers_freed")
	UI.toast("The missing trainers are home!")
	await Story.say(["Ammon: We'll go back to Scaraba with you. All three of us. Sable can shout at us there."], "Ammon")
	await _clem_farewell()


static func _clem_farewell() -> void:
	if GameState.flag("clem_left"):
		return
	GameState.set_flag("clem_left")
	await Story.say(["Clem comes out last, his hat pulled down. He stops in front of you and turns something over in his palm: a chip of grey-green stone, lit from inside.",
		"\"Earth shard. Found it in the well when I was small. It's what I do the tricks with.\""], "Clem")
	await Story.say(["He makes a fist and a little cairn of dust rises off the cobbles, stands, and falls.",
		"\"I want to be a real wizard. Not like Hoss says. Like the old ones.\"",
		"\"The fire temple's the only one I've heard of. Up past Caldera Road. I'm going to ask it for a teacher.\""], "Clem")
	await Story.say(["He puts the shard away, tips his hat, and walks off up the street without looking back."], "Clem")
	UI.toast("Clem has left for the Caldera Road.")


# ---------------------------------------------------------------- the nave's fittings
static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


static func _box(parent: Node3D, size: Vector3, at: Vector3, colour: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(colour)
	mi.position = at
	parent.add_child(mi)


## A stone well mouth: a ring of blocks, a black drop, and a bucket on the rim.
static func _well_node() -> Node3D:
	var root := Node3D.new()
	var stone := Color("#8e877a")
	for i in 8:
		var a := TAU * i / 8.0
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.3, 0.5, 0.42)
		mi.mesh = bm
		mi.material_override = _mat(stone)
		mi.position = Vector3(cos(a) * 0.45, 0.25, sin(a) * 0.45)
		mi.rotation.y = -a
		root.add_child(mi)
	var hole := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.32
	disc.bottom_radius = 0.32
	disc.height = 0.04
	hole.mesh = disc
	hole.material_override = _mat(Color("#0c0a10"))
	hole.position.y = 0.03
	root.add_child(hole)
	_box(root, Vector3(0.4, 0.05, 0.05), Vector3(0, 1.6, 0), Color("#6a5238"))
	for x in [-0.2, 0.2]:
		_box(root, Vector3(0.06, 1.6, 0.06), Vector3(x, 0.8, 0), Color("#6a5238"))
	var bucket := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.14
	cm.bottom_radius = 0.11
	cm.height = 0.24
	bucket.mesh = cm
	bucket.material_override = _mat(Color("#7a5636"))
	bucket.position = Vector3(0.3, 0.14, 0.3)
	root.add_child(bucket)
	return root


## The air mages' emblem: two rings of bronze set in the wall, no cross.
static func _emblem_node() -> Node3D:
	var root := Node3D.new()
	var bronze := Color("#c8a050")
	for r in [[0.52, 0.07], [0.28, 0.05]]:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = float(r[0]) - float(r[1])
		tm.outer_radius = float(r[0])
		tm.rings = 24
		tm.ring_segments = 8
		ring.mesh = tm
		ring.material_override = _mat(bronze)
		ring.rotation.x = PI / 2.0
		root.add_child(ring)
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		_box(root, Vector3(0.06, 0.34, 0.05), Vector3(cos(a) * 0.68, sin(a) * 0.68, 0), bronze)
	return root


