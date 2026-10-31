extends Node
## Story events, quests, NPC conversations, field moves, trainer battles and wild encounters.
##
## Quest flags (GameState.flags):
##   intro_done, got_egg, has_starter            - the first egg and the first hatch (opens the Coastal Path)
##   lesson_screen/turns/slingshot/items/ring, tutorial_done   - the Coastal Path's teachers
##   flute_lesson_done                             - the guided capture of your first wild beast after the flute
##   shell_heard, kelp_heard, island_peace         - the Isle of Tides: Kelpwick shut the reef against Shellhaven's
##                                                   souvenir-hunting tourists; beating Nerissa opens it (island_peace)
##   guardian_water                                - also opens the Dune Road to the desert
##   met_sheriff, bandits_cleared                  - Sundown's bandits (opens the Dune Sea)
##   ceo_defeated                                  - Gearhart Tower (opens Caldera Road)
##   opening_seen, missing_trainers, trainers_freed - prologue, Dustwell reveal, tower freight-cage rescue
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
const Phone = preload("res://scripts/world/phone.gd")
const TrainerCell = preload("res://scripts/story/trainer_cell.gd")

const ELDER_LOOK := {"skin": "#e8c0a0", "hair": "#e8e8e8", "shirt": "#6a4a8a", "pants": "#3a2a4a", "outfit": "robe"}
const GUARD_LOOK := {"skin": "#d8a880", "hair": "#3a2a1a", "shirt": "#4a7a4a", "pants": "#3a3a2a", "hat": "#6a5a3a"}
const CAPTAIN_LOOK := {"skin": "#d8a880", "hair": "#e8e8e8", "shirt": "#2a3a6a", "pants": "#2a2a3a", "hat": "#1a1a2a", "outfit": "coat"}
const CHIEF_SHELL_LOOK := {"skin": "#c89070", "hair": "#2a1a10", "shirt": "#e0a040", "pants": "#6a4a2a", "outfit": "robe"}
const CHIEF_KELP_LOOK := {"skin": "#a87050", "hair": "#d8d8d8", "shirt": "#30a0a0", "pants": "#2a4a4a", "outfit": "robe", "hair_style": 1}
## Kelpwick villagers standing shoulder to shoulder across the reef path (the map's crowd gate) until Nerissa is beaten.
const REEF_CROWD := [
	{"name": "Villager Tamsin", "look": {"skin": "#a87050", "hair": "#2a1a10", "shirt": "#30a0a0", "pants": "#3a3020", "outfit": "apron", "hair_style": 1}},
	{"name": "Villager Oren", "look": {"skin": "#8a5a3c", "hair": "#1a1410", "shirt": "#e07a5a", "pants": "#2a4a4a", "hat": "#d8c080"}},
	{"name": "Villager Kai", "look": {"skin": "#c08a60", "hair": "#3a2a1a", "shirt": "#e8c040", "pants": "#2a3a4a"}},
	{"name": "Villager Ula", "look": {"skin": "#9a6440", "hair": "#d8d8d8", "shirt": "#5a9a5a", "pants": "#4a3a2a", "outfit": "robe", "hair_style": 1}},
]
## A Shellhaven resort guest on the Isle Trail, showing off a shell prised from the Temple of Tides.
const TOURIST_LOOK := {"skin": "#f0c8a8", "hair": "#d8a040", "shirt": "#f07aa0", "pants": "#f0e0b0", "hat": "#f4e8c0", "hair_style": 1}
const SHERIFF_LOOK := {"skin": "#d8a880", "hair": "#6a4a2a", "shirt": "#a07040", "pants": "#3a3048", "hat": "#4a3020", "outfit": "coat"}
const PROTESTER_LOOK := {"skin": "#f0c8a0", "hair": "#c86a30", "shirt": "#6a6a5a", "pants": "#3a3a3a", "outfit": "apron"}
const SHAMAN_LOOK := {"skin": "#a8704a", "hair": "#e8e0d0", "shirt": "#3a8a4a", "pants": "#6a4a2a", "hat": "#d8b040", "outfit": "robe"}
const DIGGER_LOOK := {"skin": "#c8b8a8", "hair": "#7a7a7a", "shirt": "#4a4048", "pants": "#2a2830", "hat": "#2a2a2a", "outfit": "coat"}
const GRUNT_LOOK := {"skin": "#d8b8a0", "hair": "#20182a", "shirt": "#2a2038", "pants": "#18121f", "hat": "#4a2a6a", "outfit": "armor"}
const BUILDER_LOOK := {"skin": "#d8a880", "hair": "#c8c8d0", "shirt": "#c8803a", "pants": "#4a5a7a", "hat": "#e8c040", "outfit": "coat"}
## The egg Old Hal gives you for mending the footbridge (a Tadlet).
const BUILDER_EGG := 27
const VBld = preload("res://scripts/gfx/voxel_buildings.gd")
const FISHER_LOOK := {"skin": "#c08a60", "hair": "#d8d8d8", "shirt": "#e8c040", "pants": "#3a4a5a", "hat": "#e8c040", "outfit": "coat"}
const Fishing = preload("res://scripts/world/fishing.gd")
const UNCLE_LOOK := {"skin": "#e0b088", "hair": "#6a3a20", "shirt": "#3a7a8a", "pants": "#3a3a48", "hat": "#e8d8a0", "outfit": "coat"}
const NEIGHBOR_LOOK := {"skin": "#c89070", "hair": "#e8e0d0", "shirt": "#d88648", "pants": "#40586a", "outfit": "apron", "hair_style": 1}
## Miss Odile, feeding the wild beasts in Bellerive's park: a long purple dress, her hair up.
const FEEDER_LOOK := {"skin": "#8a5a3c", "hair": "#2a1e18", "shirt": "#7a4a9a", "pants": "#5a3a78", "outfit": "robe", "hair_style": 1}
## The Dune Ranger, keeping folk off the Dune Road while the sandstorm blows: dusty khaki and a wide hat.
## Keeper Pell, who tends the Temple of Tides' isle and knows its old waterworks
const KEEPER_LOOK := {"skin": "#b07850", "hair": "#e0e0e0", "shirt": "#3a8ab0", "pants": "#e8dcc0", "hat": "#e8dcc0", "outfit": "robe"}
const TempleProps = preload("res://scripts/gfx/temple_props.gd")
const RANGER_LOOK := {"skin": "#c89068", "hair": "#3a2a1a", "shirt": "#c8a060", "pants": "#6a5038", "hat": "#8a6a3a", "outfit": "coat"}

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


## The Coastal Path's teachers and Bellerive's arena coaches (WorldDB.LESSON_TRAINERS, ARENA_LESSONS).
const LESSON_TRAINERS = WorldDB.LESSON_TRAINERS
const ARENA_LESSONS = WorldDB.ARENA_LESSONS


## The teachers standing on this map's anchors (the Coastal Path, Kit's cabin, or Bellerive's arena).
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


## How many more logs the Coastal Path's footbridge needs than you're carrying: the builder's stack holds that many (0
## once the bridge is mended).
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
		# a teacher at home (Youngster Kit, in his cabin), or Uncle Rafe at home
		var inside := _lesson_trainers(map)
		if map.get("room_key", "") == "ceo_4":
			if not GameState.flag("trainers_freed"):
				for i in 3:
					var cell := TrainerCell.new()
					cell.index = i
					inside.append({"kind": "story", "id": "captive", "name": TrainerCell.NAMES[i], "pos": _at(map, "captive_%d" % i, Vector2i(3 + i * 4, 4)), "scene": cell, "still": true, "story": true, "captive_index": i})
			inside.append({"kind": "story", "id": "freight_control", "name": "Freight Lock Control", "pos": _at(map, "freight_control", Vector2i(7, 6)), "scene": _freight_control_node(), "still": true, "story": true})
		# Gil's spare fishing pole, leaning in his shack until you take it
		if _has_anchor(map, "rod") and not GameState.flag("got_rod"):
			inside.append({"kind": "story", "id": "rod", "name": "", "pos": _at(map, "rod", Vector2i.ZERO), "mesh": _pole_mesh(), "still": true, "facing": Vector2i(0, 1)})
		if _has_anchor(map, "builder"):
			inside.append({"kind": "story", "id": "builder", "name": "Old Hal", "pos": _at(map, "builder", Vector2i.ZERO), "look": BUILDER_LOOK, "facing": Vector2i(0, 1), "story": true})
		if _has_anchor(map, "uncle"):
			inside.append({"kind": "story", "id": "uncle", "name": "Uncle Rafe", "pos": _at(map, "uncle", Vector2i.ZERO), "look": UNCLE_LOOK, "facing": Vector2i(0, 1), "story": true})
		inside.append_array(temple_objects(map))
		inside.append_array(fixtures(map))
		return inside
	var plaza: Vector2i = map.get("plaza", Vector2i(map["w"] / 2, map["h"] / 2))
	out.append_array(fixtures(map))
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
			# the logs stacked by the builder's door, until you've taken them (or mended the footbridge)
			if _has_anchor(map, "logpile") and not GameState.flag("logs_taken") and not (_bridge_flag() != "" and GameState.flag(_bridge_flag())):
				out.append({"kind": "story", "id": "logpile", "name": "", "pos": _at(map, "logpile", Vector2i.ZERO), "mesh": _log_pile(), "still": true, "facing": Vector2i(0, 1)})
		"route3":
			# a sandstorm over the whole Dune Road until the Temple of Tides is calmed (world.gd draws it): a step in, the
			# Dune Ranger runs over and sends you back to Bellerive (sandstorm_stop)
			if not GameState.flag("guardian_water"):
				map["sandstorm"] = true
				out.append({"kind": "story", "id": "ranger", "name": "Dune Ranger", "pos": map["spawns"]["south"] + Vector2i(0, -3),
					"look": RANGER_LOOK, "facing": Vector2i(0, 1), "spots": true})
		"tidewater", "shellhaven":
			if _has_anchor(map, "rafe_neighbor"):
				out.append({"kind": "story", "id": "rafe_neighbor", "name": "Neighbor Nell", "pos": _at(map, "rafe_neighbor", plaza), "look": NEIGHBOR_LOOK, "facing": Vector2i(-1, 0), "story": true})
			if _has_anchor(map, "uncle"):
				out.append({"kind": "story", "id": "uncle", "name": "Uncle Rafe", "pos": _at(map, "uncle", plaza), "look": UNCLE_LOOK, "facing": Vector2i(0, 1), "story": true})
			if _has_anchor(map, "park_feeder"):
				out.append({"kind": "story", "id": "park_feeder", "name": "Miss Odile", "pos": _at(map, "park_feeder", plaza), "look": FEEDER_LOOK, "facing": Vector2i(0, 1)})
			if _has_anchor(map, "fisher"):
				out.append({"kind": "story", "id": "fisher", "name": "Fisher Gil", "pos": _at(map, "fisher", plaza), "look": FISHER_LOOK, "facing": Vector2i(0, 1), "rod": true})
			if _has_anchor(map, "ferry"):
				out.append({"kind": "story", "id": "ferry", "name": "Captain Gull", "pos": _at(map, "ferry", plaza), "look": CAPTAIN_LOOK, "facing": Vector2i(0, 1)})
			if id == "shellhaven":
				out.append({"kind": "story", "id": "chief_shell", "name": "Chief Marlo", "pos": _at(map, "chief", plaza), "look": CHIEF_SHELL_LOOK, "facing": Vector2i(0, 1), "story": true})
		"reef":
			if _has_anchor(map, "tide_keeper"):
				out.append({"kind": "story", "id": "tide_keeper", "name": "Keeper Pell", "pos": _at(map, "tide_keeper", plaza), "look": KEEPER_LOOK,
					"facing": Vector2i(-1, 0), "story": true})
		"kelpwick":
			out.append({"kind": "story", "id": "chief_kelp", "name": "Chief Coralie", "pos": _at(map, "chief", plaza), "look": CHIEF_KELP_LOOK, "facing": Vector2i(0, 1), "story": true})
			# villagers block the reef path, one on each gate tile (the gate tiles are gone once it opens)
			var gate_tiles: Array = map.get("gate_tiles", [])
			for i in gate_tiles.size():
				var who: Dictionary = REEF_CROWD[i % REEF_CROWD.size()]
				out.append({"kind": "story", "id": "reef_crowd", "name": who["name"], "pos": gate_tiles[i], "look": who["look"], "facing": Vector2i(-1, 0), "still": true, "blocking": true})
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
			if _has_anchor(map, "tourist"):
				out.append({"kind": "story", "id": "tourist", "name": "Tourist Gwen", "pos": _at(map, "tourist", plaza), "look": TOURIST_LOOK, "facing": Vector2i(0, 1)})
		"sundown":
			out.append({"kind": "story", "id": "sheriff", "name": "Sheriff Dalton", "pos": _at(map, "sheriff", plaza), "look": SHERIFF_LOOK, "facing": Vector2i(0, 1), "story": true})
		"cogsworth":
			out.append({"kind": "story", "id": "protester", "name": "Tinker Wren", "pos": _at(map, "protester", plaza), "look": PROTESTER_LOOK, "facing": Vector2i(0, 1), "story": true})
			if GameState.flag("trainers_freed"):
				for i in 3:
					out.append({"kind": "story", "id": "rescued_trainer", "name": TrainerCell.NAMES[i], "pos": _at(map, "protester", plaza) + Vector2i(-3 + i * 3, 1), "look": TrainerCell.LOOKS[i], "facing": Vector2i(0, 1), "still": true, "captive_index": i})
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
		"rafe_neighbor":
			return not GameState.has_flute() and not GameState.flag("met_rafe_neighbor")
		"guard":
			return GameState.flag("has_starter") and not GameState.flag("bram_sendoff")
		"chief_shell":
			return not GameState.flag("shell_heard") and not GameState.flag("island_peace")
		"chief_kelp":
			return (not GameState.flag("kelp_heard") and not GameState.flag("island_peace")) or _reef_earned()
		"sheriff":
			return not GameState.flag("met_sheriff") or (GameState.flag("bandits_cleared") and not GameState.flag("sheriff_thanks"))
		"protester":
			return not GameState.flag("ceo_defeated")
		"ceo":
			return not GameState.flag("ceo_defeated")
		"freight_control", "captive":
			return not GameState.flag("trainers_freed")
		"tide_keeper":
			return not GameState.flag("met_tide_keeper")
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
	elif id == "dustwell" and not GameState.flag("missing_trainers"):
		GameState.set_flag("missing_trainers")
		await UI.say(["That noticeboard... NEW TRAINERS MISSING. Three names. Three flutes left in the sand.",
			"Until Dustwell, your biggest worry was learning the next song. Someone out here is taking people."])
		await UI.say(["Only this season's new trainers. Gone between one watering stop and the next.",
			"A witness saw metal footprints by a Gearhart freight wagon. Sheriff Dalton in Sundown is asking questions.",
			"Travel with your beasts close, all right?"], "Oasis Keeper")
	elif id == "tidewater" and GameState.flag("got_rod") and not GameState.flag("fish_lesson") and not world.interior:
		await fish_lesson(world)
	elif id == "gravenmoor" and not GameState.flag("ghost_merge"):
		GameState.set_flag("ghost_merge")
		await UI.say(["A cold fog rolls over Gravenmoor. Black Legion banners hang from every rooftop.",
			"Here, where the shadows gather, ghost beasts can be bonded with at last.",
			"From now on, defeated ghost beasts may leave Shadow Eggs, and ghost beasts can be merged at any Beast Center."])
	elif id == "reef" and not GameState.flag("seen_reef"):
		GameState.set_flag("seen_reef")
		await UI.say(["Past Kelpwick's villagers at last. Far across the reef, the Temple of Tides rises from the waves."])
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
	# This short objective survives skipping the film. The hero knows nothing about the tower.
	await UI.say(["First day of spring, %s! The beasts are waking and trainer season is officially open!" % GameState.player_name,
		"Elder Rowan has your first egg in the plaza. Hatch it at the Beast Center before you head out.",
		"Then go east along the Coastal Path to Bellerive. Uncle Rafe has your dad's flute, and he's promised to teach you."], "Mom")


## Uncle Rafe's lessons in Bellerive: the flute, then Weaken, then Capture I. Kept short: he plays each song once,
## then you play it back (the 30-second lesson clock, see flute_game.gd). Returns true when all are done.
func uncle_lessons() -> bool:
	var who := "Uncle Rafe"
	var b_key := "B" if Prefs.touch_enabled() else "B (the S key)"
	var lesson := {"lesson": true, "performer": who}
	if not GameState.has_flute():
		await UI.say(["%s! Look at you, all grown up, with a beast of your own and everything!" % GameState.player_name,
			"Here's what you came for: your father's reed flute. Songs can lift your beasts, trip up a foe, even win a wild beast over."], who)
		GameState.gear["flute"] = "reed_flute"
		GameState.set_flag("reed_flute")
		Sfx.play("capture")
		UI.toast("Received your father's Reed Flute!", UIKit.GOLD)
		await UI.say(["You received the Reed Flute! You can play it on your own turn in battle."])
	if not GameState.knows_song("weaken"):
		await UI.say(["First song: Weaken. It makes every foe drop its guard. Here, I'll play it for you.",
			"Each line on the sheet is a button: left, right, A and %s, from the bottom up. When I stop, it's your turn: play the notes left to right." % b_key], who)
		if not await Places.learn_attempts("weaken", who, 0.0, lesson):
			await UI.say(["No rush, kid. Come back whenever you want another go."], who)
			return false
		await UI.say(["Ha! That's your father's knack, right there.",
			"In a battle nobody plays it for you: read the sheet and go. Finish while the bar's green for full power. Three wrong notes spoil it."], who)
	if GameState.capture_level() == 0:
		await UI.say(["Now the important one: Capture. Play it for a wild beast and it might join you, up to level %d." % SongDB.CAPTURE_CAPS[0],
			"Same as before: I play, then you!"], who)
		if not await Places.learn_attempts(SongDB.capture_id(1), who, 0.0, lesson):
			await UI.say(["Almost had it! Talk to me when you want another try."], who)
			return false
		await UI.say(["That's my %s! Practise your songs from the Flute page of your book." % GameState.hero_word("nephew", "niece"),
			"Oh, and the Bellerive Arena only lets in trainers with a flute. Go show Captain Marina what you can do!"], who)
	return true


func _lessons_done() -> bool:
	return GameState.has_flute() and GameState.knows_song("weaken") and GameState.capture_level() > 0


## Called before an exit (map edge, door mat or stairs) is used. Returning false cancels the step.
func can_use_exit(world, ex: Dictionary) -> bool:
	if not world.interior:
		return true
	# the first time you go to leave home, the phone rings: Dad, calling from work (answer it, and the game's saved)
	if world.map["building"].get("shop", "") == "home" and not GameState.flag("called_dad") and not String(ex["to"]).contains("#"):
		if world.get_node_or_null("Ringer") != null:
			await UI.say(["The phone's still ringing, sweetie! Go on, answer it."], "Mom")
			return false
		Phone.ring(world)
		await UI.say(["Ring-ring! Ring-ring!"])
		await UI.say(["Oh! The phone! Could you get that, sweetie? It's probably your father, calling from work."], "Mom")
		return false
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
	elif key == "crypt_1" and not GameState.flag("guardian_ghost"):
		await UI.say(["A wall of shadow seals the stairs down. Something in the crypt still stirs: its guardian, Nocthrax.",
			"Win it over first. The crypt's singing stones hold its song."])
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
	if el not in elements:
		el = who.element2
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
## Fisher Gil, on the Bellerive pier: he offers you his spare pole, and once you've taken it, shows you how to fish.
func _fisher(world) -> void:
	var who := "Fisher Gil"
	if not GameState.flag("fisher_met"):
		GameState.set_flag("fisher_met")
		await UI.say(["Ahoy! Gil's the name. Been fishing off this pier since before there was a pier.",
			"Water beasts live all round the docks. Hook one, reel it in, and it'll come out fighting. Catch it, if you've a flute!",
			"Fancy a go? There's a spare pole in my shack, right there on the planks. Go on in and take it."], who)
		return
	if GameState.flag("got_rod") and not GameState.flag("fish_lesson"):
		await fish_lesson(world)
		return
	if not GameState.flag("got_rod"):
		await UI.say(["The spare pole's in my shack, just along the planks. Help yourself!"], who)
		return
	await UI.say([["They bite best where the water ripples. Cast anywhere else and you'll mostly catch your breath.",
		"No bait? They'll still bite. But put some worms on your hook and the bigger ones come up. The island folk sell them.",
		"Further on, they sell fancy lures. Shiny ones bring up beasts I've only heard about in songs."][randi() % 3]], who)


## Gil's spare pole in his shack: yours once you've asked him, and taking it without asking is stealing.
func _take_rod(world, n: Dictionary) -> void:
	if not GameState.flag("fisher_met"):
		await UI.say(["A fishing pole, leaning in the corner. It isn't yours.",
			"Taking somebody's things without asking is stealing, and stealing is bad! Whoever owns it is probably fishing off the pier outside."])
		return
	GameState.set_flag("got_rod")
	GameState.add_item("fishing_rod")
	Sfx.play("item")
	world.remove_npc(n)
	UI.toast("Received the Fishing Pole!", UIKit.GOLD)
	await UI.say(["You took Gil's spare fishing pole. He'll want to see you use it!"])


## Out of the shack with his pole: Gil stops you and shows you how to fish, off the deck in front of it (something
## always bites, the line is gentler, and you can't lose it for good: he has you try again).
func fish_lesson(world) -> void:
	var who := "Fisher Gil"
	await UI.say(["Hold on there! Before you go dropping that line just anywhere, let me show you how it's done.",
		"See the water rippling? That's where they're feeding. Face the water, press A, and your line's in."], who)
	var t: Vector2i = world.player_pos + world.facing
	if MapGen.get_t(world.map, t.x, t.y) != MapGen.WATER:
		for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
			if MapGen.get_t(world.map, world.player_pos.x + d.x, world.player_pos.y + d.y) == MapGen.WATER:
				t = world.player_pos + d
				break
	world.facing = t - world.player_pos
	while true:
		var res := await Fishing.cast(world, t, true, who)
		if res == "landed":
			break
		if res == "":
			return
		await UI.say([{"cancelled": "Patience! Don't reel in before it bites. Let's go again.",
			"too_fast": "Too eager! Steady taps, not a frenzy. Again!",
			"too_slow": "Faster than that, or it wriggles free. Again!"}.get(res, "Ah, it got away! Happens to the best of us. Again!")], who)
	GameState.set_flag("fish_lesson")
	await UI.say(["Not bad at all for a first catch!",
		"You can fish in any water you can reach, but the ripples are where they bite. And put some bait on your hook: it stays on till something bites, and the better the bait, the bigger the beast."], who)


## The fishing pole leaning in Gil's shack: a long cane pole, its reel, and a coil of line.
func _pole_mesh() -> Mesh:
	var k := VBld.Kit.new()
	k.box("color", Vector3(0, 1.05, -0.3), Vector3(0.05, 2.1, 0.05), Color("#7a5a32"))
	k.box("color", Vector3(0, 0.55, -0.26), Vector3(0.12, 0.12, 0.08), Color("#3a3a40"))
	k.box("color", Vector3(0, 0.03, -0.3), Vector3(0.3, 0.06, 0.3), Color("#e8e0c8"))
	return k.mesh()


## Old Hal the builder, in his cabin by the washed-out footbridge: he's too tired to mend it himself, so he lends you
## the logs stacked by his door; once it's mended, he gives you an egg to hatch at the next Beast Center.
func _builder() -> void:
	var who := "Old Hal"
	var bf := _bridge_flag()
	var mended: bool = bf != "" and GameState.flag(bf)
	if mended and not GameState.flag("builder_egg"):
		await UI.say(["You mended my footbridge? All by yourself? Well, I'll be. My knees thank you. So does my back.",
			"A deal's a deal. Here: an egg I found washed up after the storm. Have Nurse Clover at the Beast Center in Bellerive hatch it for you."], who)
		GameState.add_egg(BUILDER_EGG)
		GameState.set_flag("builder_egg")
		Sfx.play("pickup")
		UI.toast("Received a beast egg!", UIKit.GOLD)
		return
	if mended:
		await UI.say(["Look after that egg! And mind the footbridge. It wobbles. It's meant to. Probably."], who)
		return
	if GameState.flag("builder_asked"):
		await UI.say(["The logs are stacked right outside my door. Lay them across the old posts in the creek and come back.",
			"I'd do it myself, but I've done my sitting down for the day, and I'm not stopping now."], who)
		return
	GameState.set_flag("builder_asked")
	await UI.say(["Oh! A visitor. I'm Hal, the builder round here. Built that footbridge myself, forty years ago.",
		"Then the storm took it. I've hauled the logs back from the storm trees, but these old bones are too tired to build it again.",
		"Tell you what: the logs are stacked by my door. Lay them across the old posts in the creek, and I'll give you a beast egg I found."], who)


## The stack of logs by the builder's door: his to lend, once he's asked you to mend the footbridge.
func _logpile(world, n: Dictionary) -> void:
	if not GameState.flag("builder_asked"):
		await UI.say(["A neat stack of logs, fresh from the storm trees. They must belong to whoever lives in the cabin."])
		return
	GameState.set_flag("logs_taken")
	_give({"bridge_log": 5})
	world.remove_npc(n)
	await UI.say(["You heave the logs onto your shoulder. Oof. Now, to the old footbridge's posts in the creek."])


## The logs stacked by the builder's door, as seen in the world: three side by side, two on them, one on top, lying
## across the way you look at them.
func _log_pile() -> Mesh:
	var VPr = load("res://scripts/gfx/voxel_props.gd")
	var src: ArrayMesh = VPr.log_mesh(14, 3.0)
	var arr := src.surface_get_arrays(0)
	var sv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var sn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var sc: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var r := src.get_aabb().size.y / 2.0
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var cols := PackedColorArray()
	var turn := Basis.IDENTITY
	for sp in [[-1.0, 0], [0.0, 0], [1.0, 0], [-0.5, 1], [0.5, 1], [0.0, 2]]:
		var off := Vector3(0, float(sp[1]) * r * 1.75, float(sp[0]) * r * 2.02)
		for i in sv.size():
			verts.append(turn * sv[i] + off)
			normals.append(turn * sn[i])
			cols.append(sc[i])
	var out_arr := []
	out_arr.resize(Mesh.ARRAY_MAX)
	out_arr[Mesh.ARRAY_VERTEX] = verts
	out_arr[Mesh.ARRAY_NORMAL] = normals
	out_arr[Mesh.ARRAY_COLOR] = cols
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out_arr)
	out.surface_set_material(0, src.surface_get_material(0))
	return out


## The washed-out footbridge: lay the builder's logs across the creek, one after another.
func _item_obstacle(world, grp: Dictionary, info: Dictionary) -> void:
	var item: String = info["item"]
	var need := int(info.get("need", 1))
	var key: String = grp["flag"] + "_logs"
	var placed := int(GameState.flags.get(key, 0))
	if GameState.item_count(item) <= 0:
		if placed == 0:
			await UI.say(["The footbridge has washed away. Only its four posts are left standing in the creek.",
				"Whoever lives in the log cabin just west of here might know something about it."])
		else:
			await UI.say(["%d of %d logs are laid across the creek. The rest are by the builder's door." % [placed, need]])
		return
	if not await UI.ask("Lay the builder's logs across the creek?"):
		return
	while GameState.item_count(item) > 0 and placed < need:
		GameState.remove_item(item)
		placed += 1
		GameState.set_flag(key, placed)
		Sfx.play("smash", 0.2)
		await world.place_bridge_log(grp, placed)
	if placed < need:
		await UI.say(["Thunk! %d of %d logs in place. The rest must still be by the builder's door." % [placed, need]])
		return
	GameState.set_flag(grp["flag"])
	world.clear_obstacle(grp)
	world.finish_footbridge(grp)
	Sfx.play("levelup")
	await UI.say(["The last log rolls snugly into place. The footbridge is finished!", "It wobbles a bit. Don't jump on it. Old Hal will want to hear about this!"])


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
		quest = "Have you seen Kelpwick? Darling little huts! Shame they've walled off the temple. I wanted a carving for my mantelpiece."
	elif world.map_id == "kelpwick" and not GameState.flag("island_peace"):
		quest = "Resort folk carried off the temple's shell lamps as souvenirs. Now the tide comes in crooked."
	elif world.map_id == "sundown" and not GameState.flag("bandits_cleared"):
		quest = "Black Bart's gang rode through again. Took every sack of flour. And my favourite spoon. Monsters."
	elif world.map_id == "cogsworth" and not GameState.flag("ceo_defeated"):
		quest = "Those freight wagons aren't carrying machinery. Wren heard people calling from inside. Gearhart's sentries guard every lift."
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
		var bf := _bridge_flag()
		# the footbridge mended: Old Hal's egg waits in his cabin
		if bf != "" and GameState.flag(bf) and not GameState.flag("builder_egg"):
			return "builder_egg"
		# the builder's logs, still to be laid across the footbridge
		if GameState.flag("builder_asked") and bf != "" and not GameState.flag(bf):
			return "bridge"
		return "path"
	if not GameState.has_flute():
		return "flute"
	if not _lessons_done():
		return "rafe"
	# Bellerive's arena: its coaches' lessons, then Tide Captain Marina's crest (the ferry wants it)
	if not arena_lessons_done("tidewater"):
		return "arena"
	if not GameState.crests.has(WorldDB.ARENAS["tidewater"]["crest"]):
		return "marina"
	if not GameState.flag("shell_heard") and not GameState.flag("kelp_heard"):
		return "ferry"
	# Kelpwick's side of the story, then Reef Warden Nerissa, whose win gets the villagers off the reef path
	if not GameState.flag("kelp_heard") and not GameState.flag("island_peace"):
		return "chiefs"
	for step in [["island_peace", "warden"], ["guardian_water", "temple"], ["met_sheriff", "desert"],
			["bandits_cleared", "bandits"], ["guardian_air", "winds"], ["mine_pass_ok", "mine"], ["ceo_defeated", "gearhart"],
			["trainers_freed", "rescue"],
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
		# Any automatic teacher who can see you steps in; manual teachers wait to be spoken to.
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


## A gift. The builder's logs: as many as the footbridge still needs.
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
		"freight_control":
			await _free_trainers(world)
		"captive":
			var lines := ["They took us off the desert road. The robots brought us here in freight cages. Please, get us out!",
				"The door control is on that console. Gearhart's command seal keeps it locked. Beat him and we can get out!",
				"I only left home this spring. I was supposed to send Dad a letter. Please tell me we're going home."]
			await UI.say([lines[int(n.get("captive_index", 0))]], n["name"])
		"rescued_trainer":
			await UI.say(["Wren helped us call our families. We're going home together. Thanks for giving us our first spring back."], n["name"])
		"lever":
			await _lever(world, n)
		"chest":
			await _chest(n)
		"tide_keeper":
			await _tide_keeper()
		"song_stone":
			await Places.song_stone(world, n)
		"song_tablet":
			await Places.song_tablet(world, n)
		"elder":
			await _elder(world, n)
		"builder":
			await _builder()
		"fisher":
			await _fisher(world)
		"park_feeder":
			# the wild beasts of the park leave her be: she brings them candy corn
			await UI.say([["Bonjour, chère! These wild beasts never lay a paw on me. Why? I feed them their favorite snack: candy corn!",
				"A handful a day, and we're the best of friends. They come running the moment they hear the bag rustle."],
				["Mind the beasts, chère. They only behave for me, and only because of the candy corn.",
				"You'd best not try it yourself. They only trust the hand that's fed them since they were hatchlings."]][1 if GameState.flag("met_park_feeder") else 0], n["name"])
			GameState.set_flag("met_park_feeder")
		"rod":
			await _take_rod(world, n)
		"logpile":
			await _logpile(world, n)
		"rafe_neighbor":
			var lines := ["Welcome to Bellerive! You must be Rafe's family. I'm Nell, an old friend of your uncle's.",
				"See the big golden flute sign above that door? That's Rafe's house, on the north side of this road, right by the west entrance."]
			if not GameState.has_flute():
				lines.append("He's been keeping your father's flute safe for you. Go on in! He's been looking forward to teaching you.")
			elif not _lessons_done():
				lines.append("I heard you trying out that flute! Rafe still has a song or two to teach you. Pop back in when you're ready.")
			else:
				lines.append("Lovely to hear a flute in that house again. Rafe's been humming all morning.")
			await UI.say(lines, n["name"])
			GameState.set_flag("met_rafe_neighbor")
		"uncle":
			if not _lessons_done():
				await uncle_lessons()
			else:
				await UI.say([["Practise, practise, practise! A song you can play half asleep is a song that wins battles.",
					"The ferry to the Isle of Tides leaves from the long pier. The islanders are funny about their fish.",
					"Your father always said: a quick tune beats a perfect one played too late. Then he'd play it perfectly AND quickly. Show-off."][randi() % 3]], "Uncle Rafe")
		"mom":
			if world.get_node_or_null("Ringer") != null:
				await UI.say(["Quick, the phone! It's ringing!"], "Mom")
				return
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
					"Your uncle's waiting in Bellerive at the end of the path. Off you go, champ!"], "Scout Bram")
			elif GameState.flag("has_starter"):
				await UI.say(["Off you go! The Coastal Path leads east to Bellerive.",
					"Wild beasts roam the path once you've got a flute to play them. Creep up behind one and you'll get the jump on it. Let one sneak up behind YOU and, well... don't.",
					"...I hide in the tall grass sometimes. It makes me harder to spot. Nobody knows. Now you know."], "Scout Bram")
			else:
				await UI.say(["Whoa there! Wild beasts roam the Coastal Path. Also bees. Mostly beasts.", "I can't let you through without a beast of your own. Go see Elder Rowan in the plaza!"], "Scout Bram")
		"inspector", "warden", "sentinel":
			await _blocker(world, n)
		"center_guide":
			await UI.say(["Hi, sugar! Welcome to the Beast Center. Every one in the land is built just like this one, so you'll never get lost.",
				"Each machine has its own bay along the back wall. First, Nurse Clover's counter. She hatches eggs in the incubator beside her.",
				"That tall glass chamber next along? The healing machine. Pop your beasts in and they come out good as new. Free, any time! The storage terminal's right beside it.",
				"The glowing altar on the end merges two beasts that have hit their level limit into one stronger beast. Very fancy. Very sparkly.",
				"And round the end of that wall on the left is the kennel. Pip finds homes for beasts other trainers couldn't keep. You can adopt one, or leave one of yours.",
				"And that red phone on the nurse's counter? Call your dad on it any time. That's how you save your journey."], "Guide Dottie")
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
		"ranger":
			await _ranger()
		"chief_shell", "chief_kelp":
			await _chief(world, n)
		"tourist":
			await _tourist(n)
		"reef_crowd":
			await _reef_crowd(n)
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
		"Crystal shards glitter in hidden corners. Volt in Bellerive turns them into shield points and beast slots.",
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
	GameState.main.goto_map(dest, "dock")


## Your first step into the Dune Road's sandstorm: the Dune Ranger spots you and jogs over (straight down the road, as
## a trainer would; from where the ranger stands if you're not in line), then sends you back to Bellerive.
func sandstorm_stop(world) -> void:
	for p in world.npcs:
		var n: Dictionary = world.npcs[p]
		if n.get("id", "") != "ranger":
			continue
		var d: Vector2i = world.player_pos - p
		world._face_npc(n, d)
		if (d.x == 0) != (d.y == 0) and absi(d.x + d.y) > 1:
			n["facing"] = d.sign()
			await world._trainer_approach(n, p, absi(d.x + d.y))
		else:
			await talk(world, n)
		return
	await _ranger()


func _ranger() -> void:
	await UI.say(["Whoa, whoa! What are you doing out here? You're going to get blown away!",
		"Wait for the storm to finish. You'll never get through until then!",
		"Folk say it won't settle until things are calm at the Temple of Tides, out on the Isle of Tides. Back to town with you!"], "Dune Ranger")
	GameState.main.goto_map("tidewater", "north", Vector2i(0, 1))


## The Isle of Tides: Shellhaven's resort guests have been carrying bits of the Temple of Tides home as souvenirs, so
## Kelpwick's villagers stand across the way to the reef. Shellhaven thinks the village quaint but backwards; Kelpwick
## thinks the resort is selling off the island. The villagers step aside only to a trainer who beats Reef Warden Nerissa
## in its great hut (reef_opened), proving they're no tourist.
func _chief(_world, n: Dictionary) -> void:
	var nm: String = n["name"]
	if n["id"] == "chief_shell":
		if GameState.flag("island_peace"):
			await UI.say(["Kelpwick's let the reef path open again? Splendid! I'll have the brochures reprinted.",
				"Coralie says guests may look but not take. Honestly, they're only pebbles... but very well. Look, don't take."], nm)
			return
		if GameState.flag("shell_heard"):
			await UI.say(["Kelpwick still standing guard over their reef? Chief Coralie's east along the Isle Trail.",
				"Do be patient with her. They're simple folk. They don't get much sophisticated company."], nm)
			return
		GameState.set_flag("shell_heard")
		await UI.say(["Welcome to Shellhaven, the jewel of the Isle of Tides! Do try La Perla. The chef trained on the mainland.",
			"You'll want the Temple of Tides, of course. Every guest does. And those Kelpwick villagers are standing in the road to stop anyone reaching it!",
			"Quaint people, bless them. Grass huts, fish on sticks. But backwards. That temple could be the finest attraction on the coast.",
			"So a few guests took home a carved stone or two. Little keepsakes! Hardly a crime.",
			"Go east along the Isle Trail and talk some sense into Chief Coralie, would you?"], nm)
		return
	if GameState.flag("island_peace"):
		await UI.say(["Nerissa told me how you battled. You fight for your beasts, not for keepsakes.",
			"Our folk on the reef path will let you by. Go gently in the Temple of Tides. Take nothing but its song."], nm)
		return
	if _reef_earned():
		await reef_opened(nm)
		return
	if GameState.flag("kelp_heard"):
		await UI.say(["Nerissa waits by the ring in the great hut. Beat her, and our folk will let you through to the reef.",
			"A tourist would have given up and gone back for cocktails by now."], nm)
		return
	GameState.set_flag("kelp_heard")
	await UI.say(["Another visitor from the resort? Let me guess. You've come for the Temple of Tides.",
		"Shellhaven's guests climb all over it. They chip the carvings and prise shells off the altar to take home as souvenirs.",
		"The temple keeps the tides in balance. With every stone they take, the sea grows angrier. So now we stand across the path ourselves.",
		"They call us quaint. Backwards. Meanwhile they line our beaches with deck chairs and sell the view by the night.",
		"If you want through, prove you're a trainer and not a tourist. Beat Reef Warden Nerissa in our great hut, the big one on the high street."], nm)


## True once you hold Nerissa's crest but the villagers still block the reef path (a game saved before beating her opened it).
func _reef_earned() -> bool:
	return GameState.crests.has(WorldDB.ARENAS["kelpwick"]["crest"]) and not GameState.flag("island_peace")


## You beat Reef Warden Nerissa: no tourist battles like that, so Kelpwick's villagers let you through to the reef (the
## town map clears them when it's next loaded, as you leave the great hut).
func reef_opened(who: String) -> void:
	if GameState.flag("island_peace"):
		return
	await UI.say(["No tourist battles like that. You trust your beasts, and they trust you.",
		"I'll tell Coralie, and our folk on the reef path will let you by. Go gently in the Temple of Tides."], who)
	GameState.set_flag("island_peace")
	Sfx.play("levelup")
	UI.toast("The way to the reef is open!", UIKit.GOLD)
	if GameState.main.world != null and GameState.main.world.map_id == "kelpwick":
		await GameState.main.reload_map()


## Tourist Gwen on the Isle Trail, with a shell prised off the temple's altar (until Kelpwick makes her give it back).
func _reef_crowd(n: Dictionary) -> void:
	if _reef_earned():
		await reef_opened(n["name"])
		return
	await UI.say(["Sorry, the reef path's closed. Too many tourists have been carrying the Temple of Tides home in their pockets.",
		"Beat Reef Warden Nerissa in the great hut and prove you're no tourist. Then we'll let you by."], n["name"])


func _tourist(n: Dictionary) -> void:
	if GameState.flag("island_peace"):
		await UI.say(["Kelpwick made me give my shell back! Honestly.", "...The altar did look happier with it, I suppose."], n["name"])
		return
	await UI.say(["Isn't the Temple of Tides divine? I got in before those villagers started standing in the road.",
		"Look: a genuine temple shell! It was stuck to an altar, but it came right off.",
		"What? Everybody takes one. It's practically a gift shop."], n["name"])


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
		"And new trainers are vanishing. We found Gearhart freight seals where the last camp stood. Those wagons go north to Cogsworth.",
		"Black Bart's gang raids our stores, then holes up out on the Dune Sea road. They've barricaded the road north, too.",
		"I'm one sheriff with one old Galeberry. If you're half the trainer you look, go teach those varmints some manners.",
		"Their hideout's a door in the rocks, just north of town."], "Sheriff Dalton")


func _protester() -> void:
	if GameState.flag("ceo_defeated") and not GameState.flag("trainers_freed"):
		await UI.say(["You beat Gearhart? The trainers are still locked in his freight cages!", "Use the Freight Lock Control on the top floor. I'll get their families on the phone."], "Tinker Wren")
		return
	if GameState.flag("ceo_defeated"):
		await UI.say(["The trainers are safe. Their families know. And the steam is flowing again!", "You gave this city its heart back."], "Tinker Wren")
		return
	await UI.say(["Down with Gearhart! Down with the rations!",
		"His robots have been taking new trainers off the desert roads. I heard them inside the freight lift. They're still alive.",
		"Gearhart owns every pipe and piston here. He supplies the cages; the Umbral Legion pays for the people.",
		"Climb Gearhart Tower. Beat his robot sentries, stop him, and use the top-floor freight control to free the trainers.",
		"He's sealed the Caldera Road too. Stop his drilling before Mount Cinder blows!"], "Tinker Wren")


func _ceo(world, n: Dictionary) -> void:
	if GameState.flag("ceo_defeated"):
		await UI.say(["The freight control accepts my command seal now. Take your precious trainers.",
			"Vexmora will hear about this."], "Magnus Gearhart")
		return
	await UI.say(["So. You're the pest who scrapped my sentries.",
		"Those trainers? Vexmora needs living bonds to command his ghosts. I supply the transport. Very profitable.",
		"Do you know what's inside Mount Cinder? Fire. Endless, free fire. Bottled and sold, it will make Gearheart Industries a god.",
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
			"His command seal falls onto the desk. The Freight Lock Control can open the trainers' cages now!",
			"The Caldera Road gate grinds open. The path to Mount Cinder and the Temple of Flame is clear!",
			"The grateful engineers of Cogsworth hand you 2 crystal shards. (%d in your bag)" % GameState.shards])


func _freight_control_node() -> Node3D:
	var root := Node3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.65, 0.75, 0.55)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#344b62")
	mesh.material = mat
	var base := MeshInstance3D.new()
	base.mesh = mesh
	base.position.y = 0.375
	root.add_child(base)
	var screen := MeshInstance3D.new()
	var panel := BoxMesh.new()
	panel.size = Vector3(0.54, 0.3, 0.04)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color("#72c9c5" if GameState.flag("trainers_freed") else "#d77c9a")
	panel.material = glow
	screen.mesh = panel
	screen.position = Vector3(0, 0.85, 0.2)
	screen.rotation.x = -0.35
	root.add_child(screen)
	var label := Label3D.new()
	label.text = "FREIGHT LOCK\nOPEN" if GameState.flag("trainers_freed") else "FREIGHT LOCK\nCOMMAND SEAL"
	label.position = Vector3(0, 1.4, 0)
	label.font_size = 26
	label.pixel_size = 0.004
	root.add_child(label)
	return root


func _free_trainers(world) -> void:
	if GameState.flag("trainers_freed"):
		await UI.say(["All freight cages are open. The transport orders have been cancelled."])
		return
	if not GameState.flag("ceo_defeated"):
		await UI.say(["FREIGHT LOCK: COMMAND SEAL REQUIRED.", "Gearhart has the seal. You'll have to defeat him first."], "Freight Lock Control")
		return
	GameState.set_flag("trainers_freed")
	GameState.set_flag("missing_trainers")
	Sfx.play("lever")
	for npc in world.npcs.values():
		if npc.get("id", "") == "captive":
			npc["node"].release()
	await UI.say(["You press Gearhart's command seal to the console. The freight locks snap open. All three trainers step free."])
	await UI.say(["I kept thinking nobody knew where we were. You found us.", "A general ordered this. Vexmora. The next shipment was bound for Gravenmoor."], "Trainer Lio")
	await UI.say(["We're going home. All of us. Thank you."], "Trainer Bea")
	await UI.say(["You cancel the remaining transport orders and send the missing-trainer register to Tinker Wren.",
		"TRAINERS RESCUED · Lio, Bea and Orin are safe. Wren will reunite them with their families.",
		"The trail leads to the Umbral Legion in Gravenmoor. This season belongs to trainers, not Vexmora."])
	await GameState.main.reload_map()


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
		"You won't interrupt him."], "Commander Nyx")
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
	if not GameState.flag("trainers_freed"):
		await UI.say(["The trainers in Gearhart Tower are still locked in their freight cages.",
			"Free them with the top-floor Freight Lock Control before confronting Vexmora. You won't leave them behind."])
		return
	if GameState.alive_party().is_empty():
		await UI.say(["Your beasts can barely stand. Heal them first!"])
		return
	await UI.say(["So the child from Cocoon Cove made it all the way to my crypt.",
		"Gearhart's shipments have stopped. So you are the one who opened my cages.",
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


# ================================================================ levers, chests and the temple keeper
## A map's levers and treasure chests (map_loader.gd _fixture), as story objects.
func fixtures(map: Dictionary) -> Array:
	var out := []
	for lv in map.get("levers", []):
		out.append({"kind": "story", "id": "lever", "name": "", "pos": lv["pos"], "lever": lv["flag"], "info": lv["info"],
			"scene": TempleProps.lever(GameState.flag(lv["flag"])), "still": true, "facing": Vector2i(0, 1)})
	for ch in map.get("chests", []):
		out.append({"kind": "story", "id": "chest", "name": "", "pos": ch["pos"], "item": ch["item"], "chest": ch["flag"],
			"scene": TempleProps.chest(GameState.flag(ch["flag"])), "still": true, "facing": Vector2i(0, 1)})
	return out


## Pulls a lever (once: it locks): its flag drains the floods it works, here or in another room (map_loader.gd).
func _lever(world, n: Dictionary) -> void:
	var info: Dictionary = n.get("info", {})
	var flag: String = n["lever"]
	if GameState.flag(flag):
		await UI.say([String(info.get("done", "The lever is locked in place."))])
		return
	if not await UI.ask(String(info.get("ask", "An old lever. Pull it?"))):
		return
	Sfx.play("lever")
	await TempleProps.pull(n["node"])
	GameState.set_flag(flag)
	await UI.say(info.get("lines", ["Somewhere, water rushes away."]))
	# the water here drains (or fills) at once
	if flag in world.map.get("flood_flags", []):
		await GameState.main.reload_map()


## Opens a treasure chest (each once).
func _chest(n: Dictionary) -> void:
	if GameState.flag(n["chest"]):
		await UI.say(["The chest is empty."])
		return
	GameState.set_flag(n["chest"])
	await TempleProps.open_chest(n["node"])
	GameState.add_item(n["item"])
	Sfx.play("item")
	var item_name := ItemDB.item_name(n["item"])
	var article := "some" if item_name.ends_with("s") else ("an" if item_name.left(1).to_upper() in "AEIOU" else "a")
	await UI.say(["You opened the chest. Inside: %s %s!" % [article, item_name]])


## Keeper Pell, outside the Temple of Tides: how its halls drain, and what prowls them.
func _tide_keeper() -> void:
	var nm := "Keeper Pell"
	if GameState.flag("guardian_water"):
		await UI.say(["The sea's calm again, and the winds off the desert with it. You did that.",
			"The temple's halls will keep. Come back whenever you like."], nm)
		return
	GameState.set_flag("met_tide_keeper")
	if GameState.flag("tides_lever_3"):
		await UI.say(["The great pool's drained! The stair down to the guardian's chamber is open.",
			"Read the tablet down there before you wake it. The stones' song is the only thing it heeds."], nm)
		return
	await UI.say(["You came over the falls? Then you've a keen eye for old waterworks. You'll need it in there.",
		"The Temple of Tides floods its own halls. The guardian's chamber lies under the great pool by the door.",
		"The old priests drained it with three levers, one in each of the temple's wings. Pull them all."], nm)
	await UI.say(["Mind the wings, though. Strong water beasts swim those channels, and you'll see them coming.",
		"An air beast on the side that faces them helps. And the priests left treasure lying about. Keep an eye out."], nm)


# ================================================================ temple guardians
## The singing stones and the tablet in a temple's room (or Gravenmoor's crypt), on its anchors stone_0 .. stone_3 and
## tablet. Each stone is one flute button (left, right, A, B, in their flute-game colours); the tablet sings the order
## (Places.song_tablet), and striking them in it teaches the temple's song (Places.song_stone).
const STONE_GLYPHS := ["<", ">", "A", "B"]
const STONE_COLORS := [Color("#e8603a"), Color("#3f8fe0"), Color("#c8384e"), Color("#d89a28")]


func temple_objects(map: Dictionary) -> Array:
	var tk := WorldDB.temple_for_room(String(map.get("room_key", "")))
	if tk == "" or not _has_anchor(map, "tablet"):
		return []
	var lit: bool = GameState.flag("stones_" + tk)
	var out := []
	for i in 4:
		if not _has_anchor(map, "stone_%d" % i):
			continue
		var stone := _stone_node(i, lit)
		out.append({"kind": "story", "id": "song_stone", "name": "", "temple": tk, "stone": i, "pos": _at(map, "stone_%d" % i, Vector2i.ZERO),
			"scene": stone[0], "glow": stone[1], "light": stone[2], "facing": Vector2i(0, 1)})
	var glow := Color(String(WorldDB.TEMPLES[tk]["glow"]))
	out.append({"kind": "story", "id": "song_tablet", "name": "", "temple": tk, "pos": _at(map, "tablet", Vector2i.ZERO),
		"scene": _tablet_node(glow), "facing": Vector2i(0, 1)})
	return out


## A rune stone: a six-sided pillar on a plinth with a crystal on top in its button's colour, the button's glyph
## floating over it, and a light that wakes when it sings. Returns [node, crystal material, light].
func _stone_node(i: int, lit: bool) -> Array:
	var root := Node3D.new()
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("#5c6270")
	stone.roughness = 1.0
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.62, 0.22, 0.62)
	base.mesh = bm
	base.material_override = stone
	base.position.y = 0.11
	root.add_child(base)
	var pillar := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.15
	cm.bottom_radius = 0.24
	cm.height = 1.2
	cm.radial_segments = 6
	pillar.mesh = cm
	pillar.material_override = stone
	pillar.position.y = 0.82
	root.add_child(pillar)
	var c: Color = STONE_COLORS[i]
	var gem := StandardMaterial3D.new()
	gem.albedo_color = c
	gem.emission_enabled = true
	gem.emission = c
	gem.emission_energy_multiplier = 1.4 if lit else 0.25
	var crystal := MeshInstance3D.new()
	var pm := SphereMesh.new()
	pm.radius = 0.19
	pm.height = 0.5
	pm.radial_segments = 6
	pm.rings = 3
	crystal.mesh = pm
	crystal.material_override = gem
	crystal.position.y = 1.62
	root.add_child(crystal)
	var glyph := Label3D.new()
	glyph.text = STONE_GLYPHS[i]
	glyph.font = UIKit.font_body()
	glyph.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	glyph.font_size = 56
	glyph.outline_size = 12
	glyph.modulate = c.lightened(0.25)
	glyph.pixel_size = 0.008
	glyph.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	glyph.position.y = 2.1
	root.add_child(glyph)
	var light := OmniLight3D.new()
	light.light_color = c
	light.omni_range = 3.0
	light.light_energy = 0.6 if lit else 0.0
	light.position.y = 1.7
	root.add_child(light)
	return [root, gem, light]


## The tablet that sings the stones' order: a slanted slab carved with glowing lines.
func _tablet_node(glow: Color) -> Node3D:
	var root := Node3D.new()
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("#8a8478")
	stone.roughness = 1.0
	var slab := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.95, 0.75, 0.14)
	slab.mesh = bm
	slab.material_override = stone
	slab.position = Vector3(0, 0.62, 0)
	slab.rotation.x = -0.45
	root.add_child(slab)
	var foot := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.7, 0.3, 0.4)
	foot.mesh = fm
	foot.material_override = stone
	foot.position.y = 0.15
	root.add_child(foot)
	var lines := StandardMaterial3D.new()
	lines.albedo_color = glow
	lines.emission_enabled = true
	lines.emission = glow
	lines.emission_energy_multiplier = 1.6
	for k in 4:
		var l := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.12, 0.08, 0.02)
		l.mesh = lm
		l.material_override = lines
		l.position = Vector3(-0.3 + k * 0.2, 0.08 * sin(k * 1.7), 0.075)
		slab.add_child(l)
	var note := Label3D.new()
	note.text = "♪"
	note.font_size = 64
	note.outline_size = 10
	note.modulate = glow
	note.pixel_size = 0.008
	note.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	note.position.y = 1.45
	root.add_child(note)
	return root



func _guardian(world, n: Dictionary) -> void:
	var tk: String = n["temple"]
	var t: Dictionary = WorldDB.TEMPLES[tk]
	var race: int = t["guardian"]
	var song: String = t["song"]
	if GameState.flag(n["flag"]):
		return
	if not GameState.knows_song(song):
		await UI.say(["%s, guardian of the %s, sleeps on, coiled around the altar." % [RaceDB.race_name(race), t["name"]],
			"Its eyes stay shut. The song that wakes it is still locked in the singing stones."])
		return
	Sfx.play("growl")
	await UI.say(["The %s stirs the air, and %s opens its eyes." % [SongDB.song_name(song), RaceDB.race_name(race)],
		"It rises to test you! It can't be beaten, only won over: wear it down, then play the %s to it." % SongDB.song_name(song)])
	if GameState.alive_party().is_empty():
		await UI.say(["The guardian closes its eyes again. Your beasts are in no state to fight."])
		return
	var lv: int = t["level"]
	# (the crypt's guardian is a ghost; its helpers are the crypt's own beasts)
	var team := [[race, lv, t.get("ghost", false)]]
	for h in t.get("helpers", []):
		team.append([int(h), lv - 3])
	var foes := build_team(team)
	if foes[0].ghost:
		# a legendary already has a guardian's stats: no ghost's extra strength on top of them
		for k in foes[0].base:
			foes[0].base[k] = snappedf(float(foes[0].base[k]) / Beasts.GHOST_STAT_MULT, 0.1)
		foes[0].heal_full()
	var res: String = await GameState.main.start_battle({"wild": true, "foes": foes, "guardian": tk, "seed": randi(), "intro": "wild"})
	if res != "win" or not GameState.summons.has(tk):
		return
	world.remove_npc(n)
	Sfx.play("levelup")
	await UI.say(["%s is yours now: a summon!" % RaceDB.race_name(race),
		"In battle, choose Summon and play the %s: %s arrives and strikes every foe at once. Once per battle, for one shield point." % [SongDB.song_name(song), RaceDB.race_name(race)]])


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
func wild_battle(_world, foes: Array, kind: String, extra := {}) -> String:
	if GameState.alive_party().is_empty():
		return "run"
	var lesson := ""
	# (not for older saves that have caught beasts already)
	if _lessons_done() and not GameState.flag("flute_lesson_done") and GameState.caught.size() <= 2 and foes.size() == 1 and not foes[0].ghost:
		lesson = "flute"
		# a lesson can't be lost: it starts with your beasts at their best
		GameState.heal_party()
	var cfg := {"wild": true, "foes": foes, "seed": randi(), "intro": kind, "lesson": lesson,
		"ambush": {"sneak": "player", "ambush": "foe"}.get(kind, "") if lesson == "" else ""}
	cfg.merge(extra, true)
	return await GameState.main.start_battle(cfg)


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
