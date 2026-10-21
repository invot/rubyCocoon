extends Node
## Story events, quests, NPC conversations, field moves, trainer battles and wild encounters.
##
## Quest flags (GameState.flags):
##   intro_done, got_egg, has_starter            - the first egg and the first hatch (opens the Coastal Path)
##   lesson_screen/turns/slingshot/items/ring, tutorial_done   - the Coastal Path's teachers
##   flute_lesson_done                             - the guided capture of your first wild beast after the flute
##   shell_heard, kelp_heard, culprit_beaten, island_peace   - the Isle of Tides feud (opens the reef)
##   guardian_water                                - also opens the Dune Road to the desert
##   met_sheriff, bandits_cleared                  - Sundown's bandits (opens the Dune Sea)
##   ceo_defeated                                  - Gearhart Tower (opens Caldera Road)
##   relic_quest, relic_sun, relic_moon, relic_earth, ritual_done   - the jungle ritual (raises the earth temple)
##   guardian_water/air/fire/earth                 - temple guardians beaten (legendary eggs)
##   ghost_merge, got_requiem, nyx_defeated, game_cleared   - Gravenmoor and the Umbral Legion

const Beasts = preload("res://scripts/core/beasts.gd")
const RaceDB = preload("res://scripts/data/race_db.gd")
const WorldDB = preload("res://scripts/data/world_db.gd")
const SongDB = preload("res://scripts/data/song_db.gd")
const MoveDB = preload("res://scripts/data/move_db.gd")
const MapGen = preload("res://scripts/world/map_gen.gd")
const MapLoader = preload("res://scripts/world/map_loader.gd")
const VP = preload("res://scripts/gfx/voxel_props.gd")
const UIKit = preload("res://scripts/ui/ui_kit.gd")
const ChatterDB = preload("res://scripts/data/chatter_db.gd")
const ItemDB = preload("res://scripts/data/item_db.gd")
const Ring = preload("res://scripts/core/ring.gd")

const ELDER_LOOK := {"skin": "#e8c0a0", "hair": "#e8e8e8", "shirt": "#6a4a8a", "pants": "#3a2a4a", "outfit": "robe"}
const GUARD_LOOK := {"skin": "#d8a880", "hair": "#3a2a1a", "shirt": "#4a7a4a", "pants": "#3a3a2a", "hat": "#6a5a3a"}
const CAPTAIN_LOOK := {"skin": "#d8a880", "hair": "#e8e8e8", "shirt": "#2a3a6a", "pants": "#2a2a3a", "hat": "#1a1a2a", "outfit": "coat"}
const CHIEF_SHELL_LOOK := {"skin": "#c89070", "hair": "#2a1a10", "shirt": "#e0a040", "pants": "#6a4a2a", "outfit": "robe"}
const CHIEF_KELP_LOOK := {"skin": "#a87050", "hair": "#d8d8d8", "shirt": "#30a0a0", "pants": "#2a4a4a", "outfit": "robe", "hair_style": 1}
const SMUGGLER_LOOK := {"skin": "#d8b090", "hair": "#1a1a1a", "shirt": "#3a3a3a", "pants": "#2a2a2a", "hat": "#8a2a2a"}
const SHERIFF_LOOK := {"skin": "#d8a880", "hair": "#6a4a2a", "shirt": "#a07040", "pants": "#3a3048", "hat": "#4a3020", "outfit": "coat"}
const PROTESTER_LOOK := {"skin": "#f0c8a0", "hair": "#c86a30", "shirt": "#6a6a5a", "pants": "#3a3a3a", "outfit": "apron"}
const SHAMAN_LOOK := {"skin": "#a8704a", "hair": "#e8e0d0", "shirt": "#3a8a4a", "pants": "#6a4a2a", "hat": "#d8b040", "outfit": "robe"}
const DIGGER_LOOK := {"skin": "#c8b8a8", "hair": "#7a7a7a", "shirt": "#4a4048", "pants": "#2a2830", "hat": "#2a2a2a", "outfit": "coat"}
const GRUNT_LOOK := {"skin": "#d8b8a0", "hair": "#20182a", "shirt": "#2a2038", "pants": "#18121f", "hat": "#4a2a6a", "outfit": "armor"}
const UNCLE_LOOK := {"skin": "#e0b088", "hair": "#6a3a20", "shirt": "#3a7a8a", "pants": "#3a3a48", "hat": "#e8d8a0", "outfit": "coat"}

## Elder Rowan's four eggs (RaceDB.STARTERS), by the line's first form.
const EGG_BLURB := {
	0: "A warm, flickering egg. Fire beasts are offensive tanks: tough and hard-hitting.",
	24: "A cool, rippling egg. Water beasts are healers who keep the team alive.",
	12: "A heavy, pebbly egg. Earth beasts are defenders who shield their friends.",
	30: "A light, breezy egg. Air beasts are tricksters of status and evasion.",
}
const RELICS := {
	"sun": {"name": "Sun Relic", "map": "vinehollow", "anchor": "relic_sun"},
	"moon": {"name": "Moon Relic", "map": "route8", "anchor": "relic_moon"},
	"earth": {"name": "Earth Relic", "map": "route9", "anchor": "relic_earth"},
}


# ================================================================ map population
func _at(map: Dictionary, name: String, fallback: Vector2i) -> Vector2i:
	return map.get("anchors", {}).get(name, fallback)


func _has_anchor(map: Dictionary, name: String) -> bool:
	return map.get("anchors", {}).has(name)


## The Coastal Path's teachers and Tidewater's arena coaches (WorldDB.LESSON_TRAINERS, ARENA_LESSONS).
const LESSON_TRAINERS = WorldDB.LESSON_TRAINERS
const ARENA_LESSONS = WorldDB.ARENA_LESSONS


## The teachers standing on this map's anchors (the Coastal Path, Kit's cabin, or Tidewater's arena).
func _lesson_trainers(map: Dictionary) -> Array:
	var out := []
	var town: String = map.get("parent", map["id"])
	for t in LESSON_TRAINERS + ARENA_LESSONS:
		if _has_anchor(map, t["anchor"]) and String(t.get("town", town)) == town:
			var lt: Dictionary = t.duplicate(true)
			lt["kind"] = "trainer"
			lt["pos"] = _at(map, t["anchor"], Vector2i.ZERO)
			lt["sight"] = int(t.get("sight", 4))
			lt["flag"] = "lesson_" + String(t["lesson"])
			lt["reward"] = 40
			out.append(lt)
	return out


## How many more logs the Coastal Path's footbridge needs than you're carrying: Kit hands over that many (0 once the
## bridge is mended).
func logs_missing() -> int:
	var bf := _bridge_flag()
	if bf == "" or GameState.flag(bf):
		return 0
	var need := int(WorldDB.OBSTACLES["n"].get("need", 1))
	return maxi(0, need - int(GameState.flags.get(bf + "_logs", 0)) - GameState.item_count("bridge_log"))


## The flag the Coastal Path's footbridge sets once it's mended ("" if the map has none).
func _bridge_flag() -> String:
	var m := MapLoader.load_map("route1", {})
	for q in m["obstacles"]:
		if m["obstacles"][q]["kind"] == "broken_bridge":
			return m["obstacles"][q]["flag"]
	return ""


## Coach Ondine's beast for the side of your ring facing the foe: one that's weak to that side's element.
const WEAK_FOES := {"fire": 36, "water": 12, "air": 3}


## True once a town's arena lessons are all done (always, for a town without any).
func arena_lessons_done(town: String) -> bool:
	return ARENA_LESSONS.all(func(t): return String(t["town"]) != town or GameState.flag("lesson_" + String(t["lesson"])))


## Coach Ondine's lesson: her beast is weak to the element of the side of your ring that will face it. Nothing is weak
## to earth, so with your earth side facing the foe you borrow the arena's air practice beasts for the lesson.
func _elements_lesson(def: Dictionary) -> void:
	var ring := GameState.ring()
	var side := GameState.ring_side
	if not Ring.side_alive(ring, side):
		side = maxi(0, Ring.best_side(ring))
	var el := Ring.side_element(side)
	if not WEAK_FOES.has(el):
		el = "air"
	def["practice_side"] = el
	def["team"] = [[WEAK_FOES[el], 4]]


func extra_npcs(map: Dictionary) -> Array:
	var out := []
	var id: String = map["id"]
	if map["kind"] == "interior":
		# a teacher at home (Youngster Kit, in his cabin)
		return _lesson_trainers(map)
	var plaza: Vector2i = map.get("plaza", Vector2i(map["w"] / 2, map["h"] / 2))
	if WorldDB.TOWNS.has(id):
		var race: int = WorldDB.TOWNS[id]["mascot"]
		var p := _at(map, "mascot", plaza + Vector2i(3, 3))
		if MapGen.walkable(MapGen.get_t(map, p.x, p.y)):
			out.append({"kind": "story", "id": "mascot", "name": RaceDB.race_name(race), "pos": p, "beast_genes": RaceDB.genes(race), "facing": Vector2i(-1, 0)})
	match id:
		"caccoon":
			out.append({"kind": "story", "id": "elder", "name": "Elder Rowan", "pos": _at(map, "elder", plaza), "look": ELDER_LOOK, "facing": Vector2i(0, 1), "story": true})
			out.append({"kind": "story", "id": "guard", "name": "Scout Bram", "pos": _at(map, "guard", plaza + Vector2i(8, 1)), "look": GUARD_LOOK, "facing": Vector2i(-1, 0)})
			if not GameState.flag("has_starter"):
				_close_edge(map, "east", "A wooden gate. Scout Bram won't let anyone onto the Coastal Path without a beast of their own.")
			# a little thank-you to the voxel artist StickyBizcuit, tucked away in the north-west corner
			if MapGen.walkable(MapGen.get_t(map, 3, 2)):
				out.append({"kind": "story", "id": "bizcuit", "name": "Bizcuit", "pos": Vector2i(3, 2), "facing": Vector2i(0, 1),
					"look": {"skin": "#f0c8a0", "hair": "#c8843a", "shirt": "#e8b860", "pants": "#6a4a2a", "hat": "#a0603a", "outfit": "apron"}})
		"route1":
			out.append_array(_lesson_trainers(map))
		"tidewater", "shellhaven":
			if id == "tidewater" and not GameState.flag("guardian_water"):
				_close_edge(map, "north", "The Dune Road is shut: sandstorms as tall as lighthouses. Folk say they won't settle until things are calm at the Temple of Tides, out on the Isle of Tides.")
			if _has_anchor(map, "uncle"):
				out.append({"kind": "story", "id": "uncle", "name": "Uncle Rafe", "pos": _at(map, "uncle", plaza), "look": UNCLE_LOOK, "facing": Vector2i(0, 1), "story": true})
			if _has_anchor(map, "ferry"):
				out.append({"kind": "story", "id": "ferry", "name": "Captain Gull", "pos": _at(map, "ferry", plaza), "look": CAPTAIN_LOOK, "facing": Vector2i(0, 1)})
			if id == "shellhaven":
				out.append({"kind": "story", "id": "chief_shell", "name": "Chief Marlo", "pos": _at(map, "chief", plaza), "look": CHIEF_SHELL_LOOK, "facing": Vector2i(0, 1), "story": true})
		"kelpwick":
			out.append({"kind": "story", "id": "chief_kelp", "name": "Chief Coralie", "pos": _at(map, "chief", plaza), "look": CHIEF_KELP_LOOK, "facing": Vector2i(0, 1), "story": true})
		"route6":
			if _has_anchor(map, "inspector") and not GameState.flag("mine_pass_ok"):
				out.append({"kind": "story", "id": "inspector", "name": "Inspector Grubb", "pos": _at(map, "inspector", plaza), "story": true, "facing": Vector2i(-1, 0),
					"look": {"skin": "#d8a880", "hair": "#4a3a2a", "shirt": "#e8c040", "pants": "#4a4a52", "hat": "#e8c040", "outfit": "coat"}})
		"route9":
			if _has_anchor(map, "warden") and not GameState.flag("warden_beaten"):
				out.append({"kind": "story", "id": "warden", "name": "Warden Kato", "pos": _at(map, "warden", plaza), "story": true, "facing": Vector2i(0, -1),
					"flag": "warden_beaten", "look": SHAMAN_LOOK, "team": [[18, 41], [27, 41], [33, 42]],
					"lines": ["Stop. Beyond this crossing the jungle grows wild and old.", "Only trainers strong enough to protect it may pass. Show me!"],
					"defeat": "Your beasts fight with a good heart. Go, and tread softly."})
		"route10":
			if _has_anchor(map, "sentinel") and not GameState.flag("sentinel_beaten"):
				out.append({"kind": "story", "id": "sentinel", "name": "Sentinel Morrow", "pos": _at(map, "sentinel", plaza), "story": true, "facing": Vector2i(-1, 0),
					"flag": "sentinel_beaten", "look": GRUNT_LOOK, "team": [[21, 47, true], [33, 47, true], [0, 48, true]],
					"lines": ["No one reaches Gravenmoor. General Vexmora's orders.", "Turn back, or join the shadows!"],
					"defeat": "The General... will not be pleased..."})
		"route2":
			if GameState.flag("shell_heard") and GameState.flag("kelp_heard") and not GameState.flag("culprit_beaten"):
				out.append({"kind": "story", "id": "culprit", "name": "Smuggler Rook", "pos": _at(map, "culprit", plaza), "look": SMUGGLER_LOOK, "facing": Vector2i(0, 1), "story": true})
		"sundown":
			out.append({"kind": "story", "id": "sheriff", "name": "Sheriff Dalton", "pos": _at(map, "sheriff", plaza), "look": SHERIFF_LOOK, "facing": Vector2i(0, 1), "story": true})
		"cogsworth":
			out.append({"kind": "story", "id": "protester", "name": "Tinker Wren", "pos": _at(map, "protester", plaza), "look": PROTESTER_LOOK, "facing": Vector2i(0, 1), "story": true})
		"vinehollow":
			out.append({"kind": "story", "id": "shaman", "name": "Shaman Ayo", "pos": _at(map, "shaman", plaza), "look": SHAMAN_LOOK, "facing": Vector2i(0, 1), "story": true})
			out.append({"kind": "story", "id": "shrine", "name": "Old Shrine", "pos": _at(map, "shrine", plaza + Vector2i(0, -2)), "asset": "head_totem", "asset_h": 1.9, "facing": Vector2i(0, 1)})
		"gravenmoor":
			out.append({"kind": "story", "id": "gravedigger", "name": "Old Mort", "pos": _at(map, "gravedigger", plaza), "look": DIGGER_LOOK, "facing": Vector2i(0, 1), "story": true})
			if _has_anchor(map, "grunt_a"):
				out.append({"kind": "trainer", "pos": _at(map, "grunt_a", plaza), "facing": Vector2i(0, 1), "sight": 2, "flag": "tr_gravenmoor_gate",
					"name": "Grunt Vesper", "cls": "Umbral Legion", "look": GRUNT_LOOK, "legion": true,
					"team": [[27, 44, true], [6, 44, true], [36, 45, true]], "lines": ["The cathedral is closed by order of General Vexmora!"],
					"defeat": "Fine... go in. Commander Nyx will finish you.", "vanish": true})
	for k in RELICS:
		var r: Dictionary = RELICS[k]
		if r["map"] == id and GameState.flag("relic_quest") and not GameState.flag("relic_" + k) and _has_anchor(map, r["anchor"]):
			out.append({"kind": "story", "id": "relic", "relic": k, "name": r["name"], "pos": _at(map, r["anchor"], plaza), "mesh": VP.relic(k), "facing": Vector2i(0, 1)})
	return out


## Blocks every exit on one edge of a map with a fence (until the map is reloaded with the flag set).
func _close_edge(map: Dictionary, dir: String, text: String) -> void:
	for t in map.get("openings", {}).get(dir, []):
		MapGen.set_t(map, t.x, t.y, MapGen.FENCE)
		map["signs"][t] = text
		map["exits"].erase(t)


func npc_has_news(n: Dictionary) -> bool:
	match n.get("id", ""):
		"elder":
			return not GameState.flag("got_egg")
		"inspector", "warden", "sentinel":
			return true
		"uncle":
			return not _lessons_done()
		"guard":
			return GameState.flag("has_starter") and not GameState.flag("bram_sendoff")
		"chief_shell":
			return not GameState.flag("shell_heard") or (GameState.flag("culprit_beaten") and not GameState.flag("island_peace"))
		"chief_kelp":
			return not GameState.flag("kelp_heard") or (GameState.flag("culprit_beaten") and not GameState.flag("island_peace"))
		"culprit":
			return true
		"sheriff":
			return not GameState.flag("met_sheriff") or (GameState.flag("bandits_cleared") and not GameState.flag("sheriff_thanks"))
		"protester":
			return not GameState.flag("ceo_defeated")
		"ceo":
			return not GameState.flag("ceo_defeated")
		"shaman":
			return not GameState.flag("relic_quest") or (_relic_count() == 3 and not GameState.flag("ritual_done"))
		"gravedigger":
			return not GameState.flag("got_requiem")
		"nyx":
			return not GameState.flag("nyx_defeated")
		"vexmora":
			return not GameState.flag("game_cleared")
	return false


func _relic_count() -> int:
	var n := 0
	for k in RELICS:
		if GameState.flag("relic_" + k):
			n += 1
	return n


# ================================================================ map events
func on_map_enter(world) -> void:
	var id: String = world.map_id
	world.busy = true
	if world.interior and world.map["building"].get("shop", "") == "home" and not GameState.flag("intro_done"):
		await _intro()
	elif id == "tidewater" and not GameState.flag("seen_tidewater"):
		GameState.set_flag("seen_tidewater")
		await UI.say(["Tidewater! Ferries to the Isle of Tides leave from the long pier.",
			"Uncle Rafe lives in the little house right by the west gate. He's got your father's flute!",
			"Sparkwire Electronics is here too. You've heard they can add shield points and beast slots for crystal shards."])
	elif id == "gravenmoor" and not GameState.flag("ghost_merge"):
		GameState.set_flag("ghost_merge")
		await UI.say(["A cold fog rolls over Gravenmoor. Black Legion banners hang from every rooftop.",
			"Here, where the shadows gather, ghost beasts can be bonded with at last.",
			"From now on, defeated ghost beasts may leave Shadow Eggs, and ghost beasts can be merged at any Beast Center."])
	elif id == "reef" and not GameState.flag("seen_reef"):
		GameState.set_flag("seen_reef")
		await UI.say(["The coral wall has parted. Far across the reef, the Temple of Tides rises from the waves."])
	elif id == "route9" and GameState.flag("ritual_done") and not GameState.flag("seen_roots"):
		GameState.set_flag("seen_roots")
		await UI.say(["The ground still hums from the ritual. The Temple of Roots now stands where there were only vines."])
	elif id == "route10" and not GameState.flag("seen_moor"):
		GameState.set_flag("seen_moor")
		await UI.say(["The Moor Road. Ghost beasts drift through the fog... They have no weakness at all."])
	world.busy = false
	world.refresh_npc_marks()
	# a teacher who can see you where you've arrived stops you straight away
	await world.spot_you()


func _intro() -> void:
	GameState.set_flag("intro_done")
	await UI.say([
		"Cocoon Cove: a sleepy seaside hamlet, where Embits nap on every sunny rooftop.",
		"For generations, trainers from the Cove have raised beasts of fire, water, earth and air.",
		"But lately, travellers whisper of the Umbral Legion and their ghost beasts, black as night and stronger than any element.",
		"Today, %s is finally old enough to raise a beast of their own." % GameState.player_name,
	])
	await UI.say(["Good morning, sleepyhead! Today's the big day!",
		"Elder Rowan is waiting in the plaza with a beast egg for you.",
		"Oh, and one more thing. Your father's old reed flute... he left it with your Uncle Rafe in Tidewater, the next town east along the Coastal Path.",
		"Rafe promised to teach you to play it once you were old enough. Well, you are now! Go and see him.",
		"Hatch your egg first, though. The Coastal Path is no place to wander without a beast."], "Mom")


## Uncle Rafe's lessons in Tidewater: the flute, then Weaken, then Capture I. Returns true when all are done.
func uncle_lessons() -> bool:
	var who := "Uncle Rafe"
	var b_key := "B" if Prefs.touch_enabled() else "B (the S key)"
	if not GameState.has_flute():
		await UI.say(["%s! Look at you, all grown up, with a beast of your own and everything!" % GameState.player_name,
			"I suppose you're here for this. Your father's reed flute. I've kept it polished for years.",
			"A flute is a trainer's other half. Songs can lift your beasts, trip up the foe, and even win a wild beast over."], who)
		GameState.gear["flute"] = "reed_flute"
		GameState.set_flag("reed_flute")
		Sfx.play("capture")
		UI.toast("Received your father's Reed Flute!", UIKit.GOLD)
		await UI.say(["You received the Reed Flute! You can play it on your own turn in battle."])
	if not GameState.knows_song("weaken"):
		await UI.say(["First song: Weaken. Play it on your turn in battle and every foe drops its guard: their Defense falls.",
			"Songs are written down as sheet music. Every note on the staff is one of your buttons: left, right, A or %s." % b_key,
			"It works like this. The song plays once, and each note lights up on the sheet as it sounds.",
			"Then it's your turn. Play the notes back in order. The sheet stays up, so read as you go!",
			"Play them all in order before your time runs out. Today I'll give you plenty of time, and I'll walk you through it on the page."], who)
		if not await Places.learn_attempts("weaken", who, 0.0, {"coach": who, "lesson": true}):
			await UI.say(["No rush, kid. Come back whenever you want another go. I'm not going anywhere. Well, fishing. But then right back here."], who)
			return false
		await UI.say(["Ha! That's your father's knack, right there.",
			"Out in the wild you won't get as long as I gave you today. A four-note song gives you about ten seconds, a bit more for longer songs.",
			"The quicker you finish, the stronger the song. Green is full power. Yellow and orange are weaker, and in the red it only works about half as well.",
			"Every wrong note takes a little off, and three of them spoil the song completely.",
			"As you master a song it grows: longer, then higher notes, up and then down, and at last chords, where you press A or B together with a direction.",
			"Longer songs are harder to remember, but much stronger. Practise any song from the Flute page of your book."], who)
	if GameState.capture_level() == 0:
		await UI.say(["Now the important one: Capture. Play it for a wild beast and it might choose to join you.",
			"It works on beasts up to level %d, as long as one of your own beasts is at least as strong." % SongDB.CAPTURE_CAPS[0],
			"Play it flawlessly, without a single wrong note, and even a stronger beast might listen. Your father caught a Tempestrix that way once. Allegedly. I wasn't there.",
			"Speed matters here too: finish in the green and a beast is far likelier to listen. In the red, your odds are about half.",
			"Same as before: listen, remember, play it back. This time you're on your own!"], who)
		if not await Places.learn_attempts(SongDB.capture_id(1), who, 0.0, {"lesson": true}):
			await UI.say(["Almost had it! Talk to me when you want another try."], who)
			return false
		await UI.say(["That's my %s! When one of your beasts outgrows Capture I, practise the next level from your book." % GameState.hero_word("nephew", "niece"),
			"Oh, and the Tidewater Arena only lets in trainers with a flute. You've got one now. Go show Captain Marina what you can do!"], who)
	return true


func _lessons_done() -> bool:
	return GameState.has_flute() and GameState.knows_song("weaken") and GameState.capture_level() > 0


## Called before an exit (map edge, door mat or stairs) is used. Returning false cancels the step.
func can_use_exit(world, ex: Dictionary) -> bool:
	if not world.interior:
		return true
	var key: String = world.map.get("room_key", "")
	var going_up := String(ex["to"]).contains("@") and int(String(ex["to"]).get_slice("@", 1)) > int(world.map.get("floor_num", 1))
	if not going_up:
		return true
	if key.begins_with("ceo_"):
		for p in world.npcs:
			var n: Dictionary = world.npcs[p]
			if n.has("robot_body") and not GameState.flag(n.get("flag", "")):
				await UI.say(["A Gearhart Sentry's red eye swivels towards you. \"STAIRWELL LOCKED. DEFEAT ALL SENTRIES ON THIS FLOOR.\""])
				return false
	elif key == "cathedral" and not GameState.flag("nyx_defeated"):
		await UI.say(["Commander Nyx blocks the way to the crypt stairs."], "Commander Nyx")
		return false
	return true


func can_enter(world, b: Dictionary) -> bool:
	match b["shop"]:
		"arena":
			if not GameState.has_flute():
				await UI.say(["Hold it! Arena rules: every challenger brings a flute. Songs are half the battle in here!",
					"No flute, no entry. Come back when you've got one."], "Arena Doorman")
				return false
		"hideout":
			if not GameState.flag("met_sheriff"):
				await UI.say(["A crude wooden door in the rock. Rough voices and laughter echo from inside...",
					"Maybe you should talk to someone in Sundown Gulch before barging in."])
				return false
	return true


# ================================================================ field moves
## The player examined an obstacle group. A party beast of the right element clears it.
func field_move(world, grp: Dictionary) -> void:
	var info: Dictionary = WorldDB.OBSTACLES.get(grp["char"], {})
	if info.has("item"):
		await _item_obstacle(world, grp, info)
		return
	if info.get("flyer", false):
		await _flyer_obstacle(world, grp)
		return
	var elements: Array = grp["elements"]
	var who = GameState.party_element(elements)
	var name: String = grp["name"]
	if who == null:
		var els := []
		for e in elements:
			els.append(e)
		var need := " or ".join(els) if els.size() < 4 else "any"
		await UI.say(["A %s blocks the way." % name, "A healthy %s beast could clear it." % need if need != "any" else "Any healthy beast could help clear it."])
		return
	var el: String = who.element
	var mv_name := ""
	for mv in who.moves:
		var m := MoveDB.get_move(mv)
		if m.get("el", "") == el and m.get("kind", "") == "attack":
			mv_name = m["name"]
			break
	if mv_name == "":
		mv_name = {"fire": "a burst of flame", "water": "a jet of water", "earth": "a mighty tackle", "air": "a gust of wind"}.get(el, "its power")
	if not await UI.ask("A %s blocks the way. Should %s use %s?" % [name, who.nickname, mv_name]):
		return
	Sfx.play({"fire": "fire", "water": "ice", "earth": "smash", "air": "fly"}.get(el, "smash"))
	await UI.flash(Color({"fire": "#ff9a50", "water": "#80c8ff", "earth": "#c8a070", "air": "#e0fff0"}.get(el, "#ffffff")), 1)
	GameState.set_flag(grp["flag"])
	world.clear_obstacle(grp)
	var verb: String = WorldDB.FIELD_VERBS.get(el, "cleared it")
	if grp["kind"] == "vines":
		verb = "burned the brambles to ash" if el == "fire" else "sliced the brambles down with razor-sharp wind"
	elif grp["kind"] == "chasm":
		verb = "toppled a tree across the ravine to make a bridge"
	elif grp["kind"] == "driftwood" and el == "water":
		verb = "washed it out to sea"
	await UI.say(["%s used %s and %s!" % [who.nickname, mv_name, verb]])


## A broken bridge (or similar) fixed with a key item.
## The washed-out footbridge: Youngster Kit, in the cabin beside it, gives you the logs once you've had his lesson; lay
## them across the creek, one after another.
func _item_obstacle(world, grp: Dictionary, info: Dictionary) -> void:
	var item: String = info["item"]
	var need := int(info.get("need", 1))
	var key: String = grp["flag"] + "_logs"
	var placed := int(GameState.flags.get(key, 0))
	if GameState.item_count(item) <= 0:
		if placed == 0:
			await UI.say(["The footbridge has washed away. Only its four posts are left standing in the creek.",
				"Youngster Kit, in the log cabin just west of here, has been gathering logs from the storm trees to mend it."])
		else:
			await UI.say(["%d of %d logs are laid across the creek. Youngster Kit in the cabin nearby has the rest." % [placed, need]])
		return
	if not await UI.ask("Lay Kit's logs across the creek?"):
		return
	while GameState.item_count(item) > 0 and placed < need:
		GameState.remove_item(item)
		placed += 1
		GameState.set_flag(key, placed)
		Sfx.play("smash", 0.2)
		await world.place_bridge_log(grp, placed)
	if placed < need:
		await UI.say(["Thunk! %d of %d logs in place. Youngster Kit must have the rest." % [placed, need]])
		return
	GameState.set_flag(grp["flag"])
	world.clear_obstacle(grp)
	Sfx.play("levelup")
	await UI.say(["The last log rolls snugly into place. The footbridge is finished!", "It wobbles a bit. Don't jump on it."])


## A cliff with a rope at the top: a beast with wings flies up and drops it down.
func _flyer_obstacle(world, grp: Dictionary) -> void:
	var who = GameState.party_flyer()
	if who == null:
		await UI.say(["A sheer cliff, far too steep to climb. A rope ladder is coiled at the very top.",
			"If only something with wings could fly up there and drop it down..."])
		return
	if not await UI.ask("A rope ladder is coiled at the top of the cliff. Should %s fly up and drop it down?" % who.nickname):
		return
	Sfx.play("fly")
	await UI.flash(Color("#e0fff0"), 1)
	GameState.set_flag(grp["flag"])
	world.clear_obstacle(grp)
	Sfx.play("levelup")
	await UI.say(["%s flaps up the cliff, tugs the rope free with its beak and lets it tumble down. Clatter!" % who.nickname,
		"The rope ladder hangs all the way to the bottom. Up you go!"])


## The road blockers: the mine checkpoint (needs a Miner's Pass), the Jungle Warden and the Legion sentinel (battles).
func _blocker(world, n: Dictionary) -> void:
	match n["id"]:
		"inspector":
			if GameState.item_count("miner_pass") > 0:
				await UI.say(["A Miner's Pass, signed by Foreman Gorran himself! Everything's in order.",
					"Mind the drills, keep left of the carts, and don't lick the copper. On you go!"], n["name"])
				GameState.set_flag("mine_pass_ok")
				world.remove_npc(n)
				Sfx.play("door")
				return
			await UI.say(["Halt! This is a Copperpick Mining Co. checkpoint. Nobody passes without a Miner's Pass.",
				"Want one? Foreman Gorran hands them out. He runs the arena back in Copperpick.",
				"Beat him there and he might just sign one for you. He respects a strong trainer. And a firm handshake."], n["name"])
		"warden", "sentinel":
			var warden: bool = n["id"] == "warden"
			if GameState.alive_party().is_empty():
				await UI.say(["Your beasts can hardly stand. Heal them first."], n["name"])
				return
			await UI.say(n["lines"], n["name"])
			var res := await trainer_battle({"name": n["name"].get_slice(" ", 1), "cls": n["name"].get_slice(" ", 0), "team": n["team"], "boss": true,
				"look": n.get("look", {}), "defeat": n["defeat"], "reward": 2400 if warden else 3600})
			if res != "win":
				return
			GameState.set_flag(n["flag"])
			world.remove_npc(n)
			await UI.say([("The Warden steps aside and bows. The way into the deep jungle is open." if warden else
				"The sentinel dissolves into black smoke. The road to Gravenmoor is open.")])


# ================================================================ conversations
func talk(world, n: Dictionary) -> void:
	match n.get("kind", ""):
		"keeper":
			await Places.open(n["building"], world)
		"leader":
			await Places.leader_talk(n["building"])
		"resident":
			await Places.house(n["building"], int(n.get("seed", 0)))
		"trainer":
			await _talk_trainer(world, n)
		"villager":
			await _talk_villager(world, n)
		"guardian":
			await _guardian(world, n)
		"story":
			await _talk_story(world, n)
	if is_instance_valid(world):
		world.refresh_npc_marks()


func _talk_villager(world, n: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(n.get("seed", 0))
	var town: Dictionary = WorldDB.TOWNS.get(world.map_id, {})
	var lines := []
	var r := rng.randi_range(0, 99)
	var quest := ""
	if world.map_id == "shellhaven" and not GameState.flag("island_peace"):
		quest = "Those Kelpwick folk stole our fishing nets! Everyone knows it. My cousin's neighbour's goat saw it."
	elif world.map_id == "kelpwick" and not GameState.flag("island_peace"):
		quest = "Someone from Shellhaven poured ink all over our reef. The fish are wearing tiny frowns!"
	elif world.map_id == "sundown" and not GameState.flag("bandits_cleared"):
		quest = "Black Bart's gang rode through again. Took every sack of flour. And my favourite spoon. Monsters."
	elif world.map_id == "cogsworth" and not GameState.flag("ceo_defeated"):
		quest = "Gearhart rations our steam and walled off Mount Cinder. He even charges for whistling now!"
	if r < 10 and not town.is_empty():
		lines.append("Welcome to %s! %s" % [town["name"], town["blurb"]])
	elif r < 24 and quest != "":
		lines.append(quest)
	elif r < 36:
		lines.append(WorldDB.TIPS[rng.randi_range(0, WorldDB.TIPS.size() - 1)])
	elif r < 46 and town.has("signature"):
		# the town's mascot and the move it teaches its own kind
		var race := int(town["mascot"])
		var tip: String = ChatterDB.MASCOT_MOVE[rng.randi_range(0, ChatterDB.MASCOT_MOVE.size() - 1)]
		lines.append(tip.replace("{mascot}", RaceDB.race_name(race)).replace("{move}", MoveDB.get_move(town["signature"])["name"]).replace("{lv}", str(MoveDB.SIGNATURE_LEVEL)))
	elif r < 62 and ChatterDB.TOWNS.has(world.map_id):
		lines = ChatterDB.pick(ChatterDB.TOWNS[world.map_id], rng)
	else:
		lines = ChatterDB.pick(ChatterDB.QUIRKY, rng)
	# and a casual hint about what to do next (it changes once you've done it)
	var hints: Array = ChatterDB.HINTS.get(next_goal(), [])
	if not hints.is_empty():
		lines = lines + [hints[rng.randi_range(0, hints.size() - 1)]]
	await UI.say(ChatterDB.fill(lines, GameState.player_name), n.get("name", ""))


## What the player should do next, for the townsfolk's hints (ChatterDB.HINTS).
func next_goal() -> String:
	for step in [["got_egg", "egg"], ["has_starter", "hatch"]]:
		if not GameState.flag(step[0]):
			return step[1]
	if not GameState.flag("tutorial_done"):
		# Kit's logs, still to be laid across the footbridge
		if GameState.flag("lesson_slingshot") and _bridge_flag() != "" and not GameState.flag(_bridge_flag()):
			return "bridge"
		return "path"
	if not GameState.has_flute():
		return "flute"
	if not _lessons_done():
		return "rafe"
	# Tidewater's arena: its coaches' lessons, then Tide Captain Marina's crest (the ferry wants it)
	if not arena_lessons_done("tidewater"):
		return "arena"
	if not GameState.crests.has(WorldDB.ARENAS["tidewater"]["crest"]):
		return "marina"
	if not GameState.flag("shell_heard") and not GameState.flag("kelp_heard"):
		return "ferry"
	if not (GameState.flag("shell_heard") and GameState.flag("kelp_heard")):
		return "chiefs"
	for step in [["culprit_beaten", "smuggler"], ["island_peace", "peace"], ["guardian_water", "temple"], ["met_sheriff", "desert"],
			["bandits_cleared", "bandits"], ["guardian_air", "winds"], ["mine_pass_ok", "mine"], ["ceo_defeated", "gearhart"],
			["guardian_fire", "flame"], ["relic_quest", "jungle"], ["ritual_done", "relics"], ["guardian_earth", "roots"],
			["nyx_defeated", "gravenmoor"], ["game_cleared", "vexmora"]]:
		if not GameState.flag(step[0]):
			return step[1]
	return "done"


func _talk_trainer(world, n: Dictionary) -> void:
	var name: String = "%s %s" % [n.get("cls", "Trainer"), n.get("name", "")]
	var song: String = n.get("song", "")
	if GameState.flag(n.get("flag", "")):
		if song != "" and n.get("encore", false) and not GameState.knows_song(song) and not GameState.alive_party().is_empty():
			if await UI.ask("Back for an encore? Battle me again and I'll play the %s for you!" % SongDB.song_name(song), name):
				await trainer_battle({"name": n.get("name", ""), "cls": n.get("cls", "Trainer"), "team": n["team"], "defeat": "What an encore!",
					"look": n.get("look", {}), "song": song, "flute_skill": n.get("flute_skill", 0.8), "encore": true, "reward": 60})
			return
		await UI.say([n.get("defeat", "Good battle!") if typeof(n.get("defeat")) == TYPE_STRING else "Good battle!"], name)
		# (a game saved before Kit kept the logs in his cabin: he hands over any the footbridge still needs)
		if n.get("gift", {}).has("bridge_log") and logs_missing() > 0:
			await UI.say(["Oh! You still need logs for the footbridge? Here, I've got plenty!"], name)
			_give({"bridge_log": 1})
		return
	if GameState.party.is_empty():
		await UI.say(["You don't have any beasts? Come back once you've hatched one!"], name)
		return
	if n.has("lesson"):
		# a lesson can't be lost: it starts with your beasts at their best
		GameState.heal_party()
	if GameState.alive_party().is_empty() and GameState.shield <= 0:
		await UI.say(["Your beasts are too tired to battle! Heal them first."], name)
		return
	if n.has("needs") and not GameState.flag(String(n["needs"])):
		await UI.say([String(n.get("first", "Come back once you've had the other lesson!"))], name)
		return
	await UI.say(n.get("lines", ["Let's battle!"]), name)
	var def := {"name": n.get("name", ""), "cls": n.get("cls", "Trainer"), "team": n["team"], "defeat": n.get("defeat", ""),
		"look": n.get("look", {}), "robot_body": n.get("robot_body", ""), "song": song, "boss": n.get("bandit_boss", false), "flute_skill": n.get("flute_skill", 0.8), "encore": n.get("encore", false)}
	for k in ["lesson", "reward"]:
		if n.has(k):
			def[k] = n[k]
	if n.get("lesson", "") == "elements":
		_elements_lesson(def)
	var res := await trainer_battle(def)
	if res != "win":
		return
	GameState.set_flag(n["flag"])
	if n.has("lesson"):
		await _lesson_done(n, name)
		# the next teacher who can see you (Coach Ondine, right after Coach Rory) steps in
		await world.spot_you()
	if n.get("vanish", false):
		world.remove_npc(n)
	if n.get("bandit_boss", false):
		GameState.set_flag("bandits_cleared")
		Sfx.play("levelup")
		await UI.say(["\"Alright, alright! We're leavin'! The Dune Sea road's all yours!\"",
			"Black Bart and his gang scatter into the desert. The barricade on the Dune Sea road has been torn down!"])
	elif n.get("legion", false) and not GameState.flag("met_legion"):
		GameState.set_flag("met_legion")
		await UI.say(["So the rumours are true... The Umbral Legion is here, with beasts twisted into shadow.",
			"Those ghost beasts had no weakness at all. You'll need strong, merged beasts to stand against them."])


## After a teacher's lesson on the Coastal Path: their parting words, a gift, and once all five are done, the path's
## lessons are over.
func _lesson_done(n: Dictionary, name: String) -> void:
	GameState.heal_party()
	await UI.say(n.get("after", []), name)
	_give(n.get("gift", {}))
	if LESSON_TRAINERS.all(func(t): return GameState.flag("lesson_" + String(t["lesson"]))):
		GameState.set_flag("tutorial_done")


## A teacher's gift. Kit's logs: as many as the footbridge still needs.
func _give(gift: Dictionary) -> void:
	for item in gift:
		var k := logs_missing() if item == "bridge_log" else int(gift[item])
		if k <= 0:
			continue
		GameState.add_item(item, k)
		Sfx.play("pickup")
		UI.toast("Received %d %s!" % [k, ItemDB.item_name(item) + ("s" if k > 1 else "")], UIKit.GOLD)


## A town's mascot: it teaches its town's signature move (WorldDB.TOWNS "signature", MoveDB.SIGNATURE) to a beast of
## its own line at Lv 40 or more, and only to one of those; anyone else just gets its antics.
func _mascot(world, n: Dictionary) -> void:
	Sfx.play("growl")
	var town: Dictionary = WorldDB.TOWNS.get(world.map_id, {})
	var race := int(town.get("mascot", -1))
	var mv: String = town.get("signature", "")
	var name: String = n.get("name", "")
	var kin: Array = GameState.party.filter(func(b): return RaceDB.first_form(b.race) == RaceDB.first_form(race) and not b.ghost)
	if mv == "" or kin.is_empty():
		await UI.say([String(ChatterDB.MASCOT[randi() % ChatterDB.MASCOT.size()]) % name])
		return
	var move_name: String = MoveDB.get_move(mv)["name"]
	var ready: Array = kin.filter(func(b): return b.level >= MoveDB.SIGNATURE_LEVEL and not b.known.has(mv))
	if ready.is_empty():
		if kin.any(func(b): return b.known.has(mv)):
			await UI.say(["The %s and your %s trade a knowing look. They both know %s." % [name, kin[0].nickname, move_name]])
		else:
			await UI.say(["The %s sniffs your %s from nose to tail, then puffs out its chest. It seems to want it stronger first." % [name, kin[0].nickname],
				"(A %s of Lv %d or more can learn %s here.)" % [name, MoveDB.SIGNATURE_LEVEL, move_name]])
		return
	var b = ready[0]
	if ready.size() > 1:
		var c: int = await UI.choose("Which %s learns %s?" % [name, move_name], ready.map(func(x): return {"text": x.nickname, "right": "Lv %d" % x.level}))
		if c < 0:
			return
		b = ready[c]
	if not await UI.ask("The %s strikes a pose in front of your %s, then does it again, slower. It wants to teach it %s! Learn it?" % [name, b.nickname, move_name]):
		return
	var res: String = b.learn(mv)
	Sfx.play("levelup")
	var out := ["%s learned %s!" % [b.nickname, move_name]]
	if res == "known":
		out.append("It already uses four moves, so %s waits among its known moves: swap it in from Start → Beasts → Moves." % move_name)
	await UI.say(out)


func _talk_story(world, n: Dictionary) -> void:
	match n.get("id", ""):
		"elder":
			await _elder(world, n)
		"uncle":
			if not _lessons_done():
				await uncle_lessons()
			else:
				await UI.say([["Practise, practise, practise! A song you can play half asleep is a song that wins battles.",
					"The ferry to the Isle of Tides leaves from the long pier. The islanders are funny about their fish.",
					"Your father always said: a quick tune beats a perfect one played too late. Then he'd play it perfectly AND quickly. Show-off."][randi() % 3]], "Uncle Rafe")
		"mom":
			GameState.heal_party()
			Sfx.play("heal")
			if GameState.flag("game_cleared"):
				await UI.say(["My little hero! The whole Cove is talking about you.", "I healed your beasts. Go on, the world is waiting!"], "Mom")
			elif GameState.flag("has_starter"):
				await UI.say(["You look tired! Let me take care of your beasts.", "...There. Good as new! Come home any time."], "Mom")
			elif GameState.flag("got_egg"):
				await UI.say(["What a lovely egg! Take it to the Beast Center by the square, the one with the red-and-white awning and the paw print over the door. Nurse Clover can hatch it."], "Mom")
			else:
				await UI.say(["Elder Rowan is waiting for you in the plaza.", "I'm so proud of you, %s." % GameState.player_name], "Mom")
		"guard":
			if GameState.flag("has_starter") and not GameState.flag("tutorial_done"):
				GameState.set_flag("bram_sendoff")
				await UI.say(["Hey, you hatched it! Look at that little %s. It has your nose." % GameState.party[0].nickname,
					"The gate's open. Along the Coastal Path, the trainers will each teach you a bit of battling. Everyone who passes gets a lesson. Rules are rules. Mostly my rules.",
					"Your uncle's waiting in Tidewater at the end of the path. Off you go, champ!"], "Scout Bram")
			elif GameState.flag("has_starter"):
				await UI.say(["Off you go! The Coastal Path leads east to Tidewater.",
					"Wild beasts roam the path once you've got a flute to play them. Creep up behind one and you'll get the jump on it. Let one sneak up behind YOU and, well... don't.",
					"...I hide in the tall grass sometimes. It makes me harder to spot. Nobody knows. Now you know."], "Scout Bram")
			else:
				await UI.say(["Whoa there! Wild beasts roam the Coastal Path. Also bees. Mostly beasts.", "I can't let you through without a beast of your own. Go see Elder Rowan in the plaza!"], "Scout Bram")
		"inspector", "warden", "sentinel":
			await _blocker(world, n)
		"center_guide":
			await UI.say(["Hi, sugar! Welcome to the Beast Center. Every one in the land is built just like this one, so you'll never get lost.",
				"Each machine has its own bay along the back wall. That big soda can in the corner? The healing machine. Slot your beasts in and they come out good as new. Free, any time!",
				"Next to it is the storage terminal, then Nurse Clover's counter. She hatches eggs in the incubator beside her.",
				"The glowing altar on the end merges two beasts that have hit their level limit into one stronger beast. Very fancy. Very sparkly.",
				"And through the side door is the kennel. Pip finds homes for beasts other trainers couldn't keep. You can adopt one, or leave one of yours.",
				"Don't forget to save your journey in your book! Each save is kept in its own slot with a little snapshot."], "Guide Dottie")
		"kennel_keeper":
			await Places.kennel(world, world.kennel_town())
		"thunderhawk":
			await Places.skytower(n["building"])
		"bizcuit":
			await UI.say(["Oh! You found my hiding spot. I'm Bizcuit. Sticky Bizcuit, if you're being formal.",
				"I carve little worlds out of cubes: trees, fences, lamp posts, the odd market stall...",
				"Whatever you're making, believe in yourself like I believe in you. NEVER GIVE UPPPPPP!"], "Bizcuit")
			if not GameState.flag("bizcuit_gift"):
				GameState.set_flag("bizcuit_gift")
				GameState.add_item("honey_cake", 3)
				Sfx.play("buy")
				await UI.say(["Here, have some biscuits. Well, cakes. Close enough!", "You received 3 Honey Cakes!"], "Bizcuit")
		"mascot":
			await _mascot(world, n)
		"ferry":
			await _ferry(world)
		"chief_shell", "chief_kelp":
			await _chief(world, n)
		"culprit":
			await _culprit(world, n)
		"sheriff":
			await _sheriff()
		"protester":
			await _protester()
		"receptionist":
			if GameState.flag("ceo_defeated"):
				await UI.say(["Mr. Gearhart has... stepped down. The new council meets on the top floor every Tuesday."], "Receptionist")
			else:
				await UI.say(["Welcome to Gearhart Tower. Mr. Gearhart is not taking visitors.",
					"...You want to see him anyway? The sentries on each floor will have something to say about that."], "Receptionist")
		"ceo":
			await _ceo(world, n)
		"shaman":
			await _shaman(world)
		"shrine":
			await _shrine(world)
		"relic":
			await _relic(world, n)
		"gravedigger":
			await _gravedigger()
		"nyx":
			await _nyx(world, n)
		"vexmora":
			await _finale(world, n)


func _elder(_world, _n: Dictionary) -> void:
	if not GameState.flag("got_egg"):
		await UI.say(["Ah, %s! There you are. Today you become a beast trainer." % GameState.player_name,
			"Every trainer starts the same way: with an egg, and a promise to care for what hatches.",
			"I have four eggs here, one of each element. Choose carefully, but know that any of them can become great."], "Elder Rowan")
		var pick := -1
		while pick < 0:
			var items := []
			for r in RaceDB.STARTERS:
				var el := RaceDB.element(r)
				items.append({"text": "%s Egg" % el.capitalize(), "right": el.to_upper(), "desc": EGG_BLURB[r]})
			var c: int = await UI.choose("Choose your egg", items, {"cancel": false, "width": 520, "dim": 0.4})
			var race: int = RaceDB.STARTERS[c]
			if await UI.ask("Will you take the %s Egg?" % RaceDB.element(race).capitalize(), "Elder Rowan"):
				pick = race
		GameState.add_egg(pick)
		GameState.set_flag("got_egg")
		Sfx.play("capture")
		await UI.say(["You received the %s Egg!" % RaceDB.element(pick).capitalize()])
		await UI.say(["Take it to the Beast Center, right across the road from this square: the blue building with the red-and-white striped awning and a red paw print over the door. Nurse Clover will help it hatch.",
			"A fresh hatchling starts at level 1, so be gentle with it at first. Win battles and it will grow strong.",
			"Defeated wild beasts sometimes leave an egg behind, about one time in five. Collect them and hatch them too!",
			"Remember the elements: fire is weak to air, earth to water, water to air, and air to fire.",
			"And %s... beware the Umbral Legion. Their ghost beasts have no weakness." % GameState.player_name], "Elder Rowan")
		return
	if not GameState.flag("has_starter"):
		await UI.say(["Your egg won't hatch in your pocket! The Beast Center is right across the road from this square.",
			"Look for the red-and-white striped awning and the red paw print over the door. Nurse Clover is inside."], "Elder Rowan")
		return
	if GameState.flag("game_cleared"):
		await UI.say(["The ghost beasts are free, and the Legion is gone. You did it, %s." % GameState.player_name], "Elder Rowan")
		return
	var tips := [
		"Remember: fire is weak to air, earth to water, water to air, and air to fire.",
		"You have %d of 8 arena crests. Each arena master teaches a new flute song." % GameState.crest_count(),
		"Your beasts' elemental powers work outside battle too. Vines burn, sand washes away, boulders shatter!",
		"Crystal shards glitter in hidden corners. Volt in Tidewater turns them into shield points and beast slots.",
		"Merge two beasts at their level limit at a Beast Center, and the child gets stronger.",
	]
	await UI.say([tips[randi() % tips.size()]], "Elder Rowan")


func _ferry(world) -> void:
	if not _lessons_done():
		await UI.say(["Ahoy! The Isle of Tides is no place for a trainer without a flute.",
			"Go and see your Uncle Rafe first. Then we'll talk boats."], "Captain Gull")
		return
	var here: String = world.map_id
	var crest: String = WorldDB.ARENAS["tidewater"]["crest"]
	if here == "tidewater" and not GameState.crests.has(crest):
		await UI.say(["Ahoy! The islanders only let proven trainers ashore. Earn the %s from Tide Captain Marina at the arena first." % crest,
			"The arena's coaches will get you ready for her. Then we'll talk boats."], "Captain Gull")
		return
	var dest := "shellhaven" if here == "tidewater" else "tidewater"
	if not await UI.ask("All aboard! The ferry sails to %s. Life jackets optional, dramatic sea shanties mandatory. Hop on?" % WorldDB.map_name(dest), "Captain Gull"):
		return
	Sfx.play("door")
	GameState.main.goto_map(dest, "dock")


func _chief(world, n: Dictionary) -> void:
	var shell: bool = n["id"] == "chief_shell"
	var nm: String = n["name"]
	if GameState.flag("island_peace"):
		await UI.say(["Shellhaven and Kelpwick are one island again, thanks to you.",
			"The coral gate east of Kelpwick stays open. The Temple of Tides awaits beyond the reef."], nm)
		return
	if GameState.flag("culprit_beaten"):
		await UI.say(["Smuggler Rook confessed everything? The nets, the ink... it was him all along?",
			"We fought each other for nothing. I'll send word to the other chief at once.",
			"...",
			"It's done. Our villages will open the coral gate together. Go east of Kelpwick, across the reef, to the Temple of Tides."], nm)
		GameState.set_flag("island_peace")
		Sfx.play("levelup")
		UI.toast("The coral gate to the reef has opened!", UIKit.GOLD)
		await GameState.main.reload_map()
		return
	if shell:
		GameState.set_flag("shell_heard")
		await UI.say(["A trainer from the mainland? Hmph. Listen well.",
			"Somebody from Kelpwick has been stealing our fishing nets. Three times this month!",
			"Until they return them, the old coral gate to the reef stays shut. The temple can rot for all I care."], nm)
	else:
		GameState.set_flag("kelp_heard")
		await UI.say(["You came from Shellhaven, didn't you? I can smell the fish.",
			"Someone from that village poured squid ink all over our reef. Our coral is dying!",
			"Only both chiefs together can open the coral gate to the Temple of Tides. And I'll never work with Marlo."], nm)
	if GameState.flag("shell_heard") and GameState.flag("kelp_heard"):
		await UI.say(["Both villages blame each other... but neither seems to have done it.",
			"Maybe someone on the Isle Trail between the villages knows more."])
		await GameState.main.reload_map()


func _culprit(world, n: Dictionary) -> void:
	await UI.say(["Eh? What're you staring at? These nets? Never seen 'em before.",
		"...Fine! Yes, I nicked the nets, and I inked the reef too. While those fools fight, nobody's watching the temple treasure!",
		"You'll never prove it. Not if I sink your beasts first!"], "Smuggler Rook")
	if GameState.alive_party().is_empty():
		await UI.say(["Ha! Your beasts can barely stand. Scram!"], "Smuggler Rook")
		return
	var res := await trainer_battle({"name": "Rook", "cls": "Smuggler", "boss": true, "team": [[21, 7], [33, 8]], "look": SMUGGLER_LOOK,
		"defeat": "Alright, alright! I'll give the nets back. And I'll tell the chiefs everything...", "reward": 900})
	if res == "win":
		GameState.set_flag("culprit_beaten")
		world.remove_npc(n)
		await UI.say(["Smuggler Rook drops the stolen nets and slinks off to confess to the chiefs.",
			"Tell either chief what happened!"])


func _sheriff() -> void:
	if GameState.flag("bandits_cleared"):
		if not GameState.flag("sheriff_thanks"):
			GameState.set_flag("sheriff_thanks")
			GameState.gold += 2500
			GameState.add_item("revival_seed", 2)
			Sfx.play("buy")
			await UI.say(["You ran Black Bart's gang out of the desert? Well, I'll be!",
				"Here's the bounty: 2500 gold and a couple of Revival Seeds. Sundown owes you one, partner.",
				"The road north through the Dune Sea is open again. They say an old temple to the winds stands out there."], "Sheriff Dalton")
		else:
			await UI.say(["Quiet as a church on Monday, ever since you cleaned up this town."], "Sheriff Dalton")
		return
	GameState.set_flag("met_sheriff")
	await UI.say(["Howdy, stranger. Mind yourself in Sundown. Black Bart's gang has this town by the throat.",
		"They raid our stores, then hole up in their hideout out on the Dune Sea road. They've barricaded the road north, too.",
		"I'm one sheriff with one old Galeberry. If you're half the trainer you look, go teach those varmints some manners.",
		"Their hideout's a door in the rocks, just north of town."], "Sheriff Dalton")


func _protester() -> void:
	if GameState.flag("ceo_defeated"):
		await UI.say(["The steam is flowing again! And the Caldera Road gate is open. You're a hero in Cogsworth!"], "Tinker Wren")
		return
	await UI.say(["Down with Gearhart! Down with the rations!",
		"Magnus Gearhart owns every pipe and piston in Cogsworth. He's holding the whole city hostage.",
		"Now he's sealed the Caldera Road so he can drill into Mount Cinder and sell its fire. The volcano could blow!",
		"He hides at the top of Gearhart Tower, behind floors full of robot sentries. Somebody has to stop him."], "Tinker Wren")


func _ceo(world, n: Dictionary) -> void:
	if GameState.flag("ceo_defeated"):
		await UI.say(["My beautiful drilling contracts... ruined by a child with a flute.",
			"Fine. FINE. The council can have their steam."], "Magnus Gearhart")
		return
	await UI.say(["So. You're the pest who scrapped my sentries.",
		"Do you know what's inside Mount Cinder? Fire. Endless, free fire. Bottled and sold, it will make Gearhart Industries a god.",
		"The city? Cattle. They'll pay whatever I ask for their steam.",
		"Enough talk. My finest machines will turn your little pets into scrap!"], "Magnus Gearhart")
	if GameState.alive_party().is_empty():
		await UI.say(["Hah! Your beasts are already broken. Security will see you out."], "Magnus Gearhart")
		return
	var res := await trainer_battle({"name": "Gearhart", "cls": "CEO", "boss": true, "team": [[44, 34], [45, 35], [46, 35], [43, 36]],
		"look": n.get("look", {}), "defeat": "Impossible... My machines... my fortune...", "reward": 6000})
	if res == "win":
		GameState.set_flag("ceo_defeated")
		GameState.shards += 2
		Sfx.play("levelup")
		await UI.say(["Gearhart slumps into his enormous chair. Outside, the city's steam whistles start to sing.",
			"The Caldera Road gate grinds open. The path to Mount Cinder and the Temple of Flame is clear!",
			"The grateful engineers of Cogsworth hand you 2 crystal shards. (%d in your bag)" % GameState.shards])


func _shaman(world) -> void:
	if GameState.flag("ritual_done"):
		await UI.say(["The Temple of Roots has woken. Its guardian waits deep inside, on the Jungle Trail.",
			"Only those the jungle trusts may face it. You have earned that trust."], "Shaman Ayo")
		return
	if not GameState.flag("relic_quest"):
		GameState.set_flag("relic_quest")
		await UI.say(["The jungle has been restless since the strangers in black came through.",
			"Long ago, our people sealed the Temple of Roots beneath the earth. Only the ritual of the three relics can raise it.",
			"The Sun Relic was hidden here in Vinehollow. The Moon Relic rests on the Summit Pass. The Earth Relic lies on the Jungle Trail.",
			"Bring all three to the old shrine in our village, and we will perform the ritual."], "Shaman Ayo")
		await GameState.main.reload_map()
		return
	var n := _relic_count()
	if n < 3:
		await UI.say(["You have found %d of the three relics. Keep searching: the Sun here in Vinehollow, the Moon on Summit Pass, the Earth on the Jungle Trail." % n], "Shaman Ayo")
	else:
		await UI.say(["All three relics! Place them on the old shrine, and the ritual can begin."], "Shaman Ayo")


func _shrine(world) -> void:
	if GameState.flag("ritual_done"):
		await UI.say(["The three relics glow softly on the old shrine."])
		return
	if _relic_count() < 3:
		await UI.say(["An ancient shrine carved with a sun, a moon and a mountain. Three hollows wait for something."])
		return
	await UI.say(["You place the Sun, Moon and Earth relics into the hollows of the shrine.",
		"Shaman Ayo begins to chant. The drums of Vinehollow answer..."])
	Sfx.play("merge")
	await UI.flash(Color("#a0ff90"), 4)
	GameState.set_flag("ritual_done")
	await UI.say(["The ground shakes! Far to the south, something vast pushes up through the jungle.",
		"The Temple of Roots has risen on the Jungle Trail!"])
	Sfx.play("levelup")


func _relic(world, n: Dictionary) -> void:
	var k: String = n["relic"]
	GameState.set_flag("relic_" + k)
	world.remove_npc(n)
	Sfx.play("capture")
	await UI.say(["You found the %s! (%d of 3)" % [n["name"], _relic_count()]])


func _gravedigger() -> void:
	if GameState.flag("got_requiem"):
		await UI.say(["The ghosts aren't wicked, you know. Just lost. The Legion drags them up from the crypt and twists them.",
			"Vexmora's down there now, beneath the cathedral. Commander Nyx guards the stairs."], "Old Mort")
		return
	GameState.set_flag("got_requiem")
	GameState.learn_song("requiem")
	Sfx.play("levelup")
	await UI.say(["A living trainer, in Gravenmoor? Hah. Haven't seen one of those in a while.",
		"Those ghost beasts out on the moor won't listen to your ordinary songs. But this one... this one they remember.",
		"It's the Requiem of Dusk. My mother taught it to me. Play it for a ghost beast, and it may follow you home.",
		"Same rules as your Capture song, mind: no stronger than your Capture level, and only perfection reaches the really tough ones."], "Old Mort")
	UI.toast("Learned the song: Requiem of Dusk!", UIKit.GOLD)
	await UI.say(["You learned the Requiem of Dusk! It's the only song that charms ghost beasts."])


func _nyx(world, n: Dictionary) -> void:
	if GameState.flag("nyx_defeated"):
		return
	await UI.say(["The Legion's grunts couldn't stop you? How embarrassing for them.",
		"General Vexmora is waking the oldest ghosts in the crypt below. Soon the Legion's army will be endless.",
		"You won't interrupt her."], "Commander Nyx")
	if GameState.alive_party().is_empty():
		await UI.say(["Come back when your beasts can stand."], "Commander Nyx")
		return
	var res := await trainer_battle({"name": "Nyx", "cls": "Commander", "boss": true, "team": [[3, 49, true], [24, 49, true], [18, 50, true]],
		"look": n.get("look", {}), "song": "discord", "flute_skill": 0.85, "defeat": "General... forgive me.", "reward": 5000})
	if res == "win":
		GameState.set_flag("nyx_defeated")
		world.remove_npc(n)
		await UI.say(["Commander Nyx vanishes in a swirl of shadow. The stairs to the crypt are open."])


func _finale(world, n: Dictionary) -> void:
	if GameState.flag("game_cleared"):
		return
	if GameState.alive_party().is_empty():
		await UI.say(["Your beasts can barely stand. Heal them first!"])
		return
	await UI.say(["So the child from Cocoon Cove made it all the way to my crypt.",
		"Every ghost beast in this place answers to me. They have no weakness. No fear. No mercy.",
		"With them, the Legion will take every town from the coast to the jungle. Starting with you."], "General Vexmora")
	var res := await trainer_battle({"name": "Vexmora", "cls": "General", "boss": true, "team": [[9, 54, true], [21, 54, true], [30, 55, true], [12, 56, true]],
		"look": n.get("look", {}), "song": "dread", "flute_skill": 0.9, "defeat": "...The light in your beasts. It's stronger than any shadow.", "reward": 12000})
	if res != "win":
		return
	GameState.set_flag("game_cleared")
	world.remove_npc(n)
	Sfx.music("ending")
	await UI.say(["General Vexmora's shadows unravel. The Umbral Legion's banners fall all across Gravenmoor.",
		"Freed from the Legion's command, the ghost beasts drift quietly up into the moonlight."])
	await UI.say(["★ THE END ★", "Thank you for playing Ruby Cocoon!",
		"Your journey continues: hatch every egg, master every song, and merge the ultimate team."])
	await GameState.main.reload_map()


# ================================================================ temple guardians
func _guardian(world, n: Dictionary) -> void:
	var tk: String = n["temple"]
	var t: Dictionary = WorldDB.TEMPLES[tk]
	var race: int = t["guardian"]
	if GameState.flag(n["flag"]):
		return
	Sfx.play("growl")
	await UI.say(["%s, guardian of the %s, opens its eyes." % [RaceDB.race_name(race), t["name"]],
		"Its gaze weighs you, and your beasts. Then it rises to test you!"])
	if GameState.alive_party().is_empty():
		await UI.say(["The guardian closes its eyes again. Your beasts are in no state to fight."])
		return
	var lv: int = t["level"]
	var room: Dictionary = world.map.get("room", {})
	var minions: Array = room.get("encounter", {}).get("races", [race, race])
	var team := [[race, lv], [int(minions[0]), lv - 3], [int(minions[minions.size() - 1]), lv - 3]]
	if lv < 20:
		# the first temple's guardian brings just one helper
		team.resize(2)
	var res := await trainer_battle({"name": RaceDB.race_name(race), "cls": "Guardian", "team": team, "guardian": true,
		"defeat": "", "reward": lv * 60})
	if res != "win":
		return
	GameState.set_flag(n["flag"])
	world.remove_npc(n)
	GameState.add_egg(race)
	Sfx.play("levelup")
	await UI.flash(Color(t["glow"]), 3)
	await UI.say(["The guardian bows its great head and dissolves into light...",
		"Where it stood lies a radiant egg, pulsing with %s power!" % String(t["element"]),
		"You received the %s! Take it to a Beast Center to hatch it." % GameState.egg_name(GameState.eggs.back()),
		"A beast born from this egg is the mightiest of its element. When merged, its legacy dominates: about 80% of the child comes from it."])


# ================================================================ battles
func build_team(spec: Array) -> Array:
	var out := []
	for s in spec:
		var ghost: bool = s.size() > 2 and s[2]
		out.append(Beasts.create(int(s[0]), int(s[1]), ghost))
	return out


## def: name, cls, team [[race, level, ghost?]], defeat, reward, arena, look, guardian
func trainer_battle(def: Dictionary) -> String:
	var foes := build_team(def["team"])
	var nicks: Array = def.get("nicknames", [])
	for i in mini(nicks.size(), foes.size()):
		foes[i].nickname = nicks[i]
	var res: String = await GameState.main.start_battle({"wild": false, "foes": foes, "trainer": def, "arena": def.get("arena", false), "seed": randi()})
	return res


## Bodies of the beasts that live in packs (and only in the high-level areas): herds, flocks and the eels' shoals.
## Everything else roams alone.
const PACK_BODIES := ["quad", "flyer", "serpent"]
## Wild levels at or above this can have packs.
const PACK_MIN_LEVEL := 16
## A beast no stronger than your best one usually roams with more of its own kind (and stands its ground).
const PACK_CHANCE_WEAK := 0.7


## The beasts for one roaming encounter on this map: usually one, sometimes a small pack.
func roll_wild(map: Dictionary) -> Array:
	var enc: Dictionary = map.get("encounter", {})
	if enc.is_empty():
		return []
	var races: Array = enc.get("races", [])
	var lv: Array = enc["lv"]
	var ghost_rate: float = float(enc.get("ghosts", 0.0))
	var first := _roll_wild_race(races)
	var lead = _roll_wild_beast(first, lv, ghost_rate)
	var foes := [lead]
	var cap := pack_cap(enc)
	if cap <= 1:
		return foes
	if lead.level <= GameState.best_level() and randf() < PACK_CHANCE_WEAK:
		# safety in numbers: two or three of the same beast
		var n := mini(cap, 3 if GameState.alive_party().size() >= 2 and randf() < 0.4 else 2)
		for i in range(1, n):
			foes.append(_roll_wild_beast(first, lv, ghost_rate))
	elif int(lv[0]) >= PACK_MIN_LEVEL and String(lead.genes.get("body", "")) in PACK_BODIES and randf() < 0.3:
		var n2 := mini(cap, 2 if int(lv[0]) < 26 or randf() < 0.5 else 3)
		for i in range(1, n2):
			foes.append(_roll_wild_beast(first if randf() < 0.7 else _roll_wild_race(races), lv, ghost_rate))
	return foes


## The most beasts in one roaming group: alone on the early roads (always on the Coastal Path), pairs from Lv 7, and
## threes only from Lv 16. A road's "pack" sets it outright.
func pack_cap(enc: Dictionary) -> int:
	if enc.has("pack"):
		return int(enc["pack"])
	var lo := int(enc["lv"][0])
	return 1 if lo < 7 else (2 if lo < 16 else 3)


func _roll_wild_race(races: Array) -> int:
	var w := randf()
	if races.is_empty() or w < 0.03:
		return randi_range(0, RaceDB.NORMAL_COUNT - 1)
	if w < 0.36:
		return int(races[0])
	return int(races[randi_range(0, races.size() - 1)])


func _roll_wild_beast(race: int, lv: Array, ghost_rate: float):
	var level := randi_range(int(lv[0]), int(lv[1]))
	var ghost := randf() < ghost_rate
	if ghost:
		level += 2
	var abandoned := not ghost and randf() < 0.025 + GameState.gear_fx("abandoned")
	if abandoned:
		level += randi_range(2, 5)
	var b := Beasts.create(race, level, ghost)
	b.abandoned = abandoned
	b.hp = b.max_hp()
	return b


## A battle with roaming beasts. kind: "sneak" (you caught it off guard), "wild" (face to face) or "ambush" (it caught you).
## The first lone wild beast after Uncle Rafe's lessons is a guided battle (battle.gd LESSONS "flute"): playing Weaken,
## then Capture to win it over.
func wild_battle(_world, foes: Array, kind: String) -> String:
	if GameState.alive_party().is_empty():
		return "run"
	var lesson := ""
	# (not for older saves that have caught beasts already)
	if _lessons_done() and not GameState.flag("flute_lesson_done") and GameState.caught.size() <= 2 and foes.size() == 1 and not foes[0].ghost:
		lesson = "flute"
		# a lesson can't be lost: it starts with your beasts at their best
		GameState.heal_party()
	return await GameState.main.start_battle({"wild": true, "foes": foes, "seed": randi(), "intro": kind, "lesson": lesson,
		"ambush": {"sneak": "player", "ambush": "foe"}.get(kind, "") if lesson == "" else ""})


## A random wild battle on the current map (test scenes).
func wild_encounter(world) -> void:
	if GameState.alive_party().is_empty():
		return
	var enc: Dictionary = world.map["encounter"]
	var races: Array = enc.get("races", [])
	var lv: Array = enc["lv"]
	var ghost_rate: float = float(enc.get("ghosts", 0.0))
	var n := 1
	var r := randf()
	if r < 0.07 and GameState.party.size() >= 3:
		n = 3
	elif r < 0.25 and GameState.party.size() >= 2:
		n = 2
	var foes := []
	for i in n:
		var race: int
		var w := randf()
		if races.is_empty() or w < 0.03:
			race = randi_range(0, RaceDB.count() - 1)
		elif w < 0.36:
			race = races[0]
		else:
			race = races[randi_range(0, races.size() - 1)]
		var level := randi_range(int(lv[0]), int(lv[1]))
		var ghost := randf() < ghost_rate
		if ghost:
			level += 2
		var abandoned := not ghost and randf() < 0.025 + GameState.gear_fx("abandoned")
		if abandoned:
			level += randi_range(2, 5)
		var b := Beasts.create(race, level, ghost)
		b.abandoned = abandoned
		b.hp = b.max_hp()
		foes.append(b)
	await GameState.main.start_battle({"wild": true, "foes": foes, "seed": randi()})


## Called by arenas when a crest is won.
func on_crest() -> void:
	var c := GameState.crest_count()
	if c == 3:
		await UI.say(["News from the road: soldiers in black armour have been seen in the mountains near Copperpick.",
			"Trainers say their ghost beasts shrug off every element."])
	elif c == 6:
		await UI.say(["A traveller whispers: the Umbral Legion has taken Gravenmoor, east of Riverbend.",
			"They say their General is digging beneath the old cathedral."])
	elif c == 8:
		await UI.say(["With eight crests, you are the strongest trainer the land has seen in an age.",
			"Gravenmoor lies east along the Moor Road. The Legion is waiting."])
