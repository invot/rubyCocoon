extends SceneTree
## Checks that the game's data points at things that exist: every beast (race id) a route, map, trainer, leader,
## coach, temple, fishing pool, egg or signature move names; every song and move named; every item a shop sells;
## every summon's model; and that everyone on every map (and the hero, in every outfit, hairdo and pack the
## character creator offers) can be dressed. Fast: no battles, nothing drawn. Prints only what's wrong, then
## "DATA CHECK DONE: <n> problem(s)".
## Run: godot --headless --path . --script res://tools/check_data.gd  (or tools/run_tests.sh)

const RaceDB = preload("res://scripts/data/race_db.gd")
const WorldDB = preload("res://scripts/data/world_db.gd")
const SongDB = preload("res://scripts/data/song_db.gd")
const MoveDB = preload("res://scripts/data/move_db.gd")
const ItemDB = preload("res://scripts/data/item_db.gd")
const LadderDB = preload("res://scripts/data/ladder_db.gd")
const MapLoader = preload("res://scripts/world/map_loader.gd")
const Townfolk = preload("res://scripts/gfx/townfolk.gd")

var bad := 0


func _init() -> void:
	_beasts()
	_songs_moves_items()
	_maps()
	_people()
	print("DATA CHECK DONE: %d problem(s)" % bad)
	quit(1 if bad > 0 else 0)


func _fail(what: String) -> void:
	bad += 1
	print("FAIL ", what)


## A constant's value as written in a script's source (for scripts that need the game running to load).
func _const(path: String, name: String, pattern: String) -> String:
	var re := RegEx.create_from_string("const " + name + " := " + pattern)
	var hit := re.search(FileAccess.get_file_as_string(path))
	return hit.get_string(1) if hit != null else ""


## A race id that exists: one of the lines' forms, or a legendary or robot (RaceDB.SPECIAL, after the lines).
func _race(id, where: String) -> void:
	var ok: bool = typeof(id) in [TYPE_INT, TYPE_FLOAT] and int(id) >= 0 and int(id) < RaceDB.count() + RaceDB.SPECIAL.size()
	if not ok:
		_fail("%s: no such beast %s" % [where, str(id)])


func _team(team: Array, where: String) -> void:
	for s in team:
		if not s is Array or s.is_empty():
			_fail("%s: a team member that isn't [race, level]: %s" % [where, str(s)])
			continue
		_race(s[0], where)
		if s.size() > 1 and (int(s[1]) < 1 or int(s[1]) > 100):
			_fail("%s: level %s out of range" % [where, str(s[1])])


func _song(id, where: String) -> void:
	if String(id) != "" and SongDB.get_song(String(id)).is_empty():
		_fail("%s: no such song %s" % [where, str(id)])


func _beasts() -> void:
	for id in RaceDB.STARTERS:
		_race(id, "starters")
	for r in WorldDB.ROUTES:
		for id in WorldDB.ROUTES[r].get("races", []):
			_race(id, "route %s races" % r)
	for t in WorldDB.TOWNS:
		if WorldDB.TOWNS[t].has("mascot"):
			_race(WorldDB.TOWNS[t]["mascot"], "town %s mascot" % t)
	for a in WorldDB.ARENAS:
		_team(WorldDB.ARENAS[a].get("team", []), "arena %s leader" % a)
	for l in WorldDB.LESSON_TRAINERS + WorldDB.ARENA_LESSONS:
		_team(l.get("team", []), "lesson %s" % l.get("lesson", "?"))
	for tk in WorldDB.TEMPLES:
		var t: Dictionary = WorldDB.TEMPLES[tk]
		_race(t["guardian"], "temple %s guardian" % tk)
		for h in t.get("helpers", []):
			_race(h, "temple %s helper" % tk)
		_song(t.get("song", ""), "temple %s" % tk)
		if not ResourceLoader.exists("res://assets/summons/%s.res" % tk):
			_fail("temple %s: no summon model assets/summons/%s.res" % [tk, tk])
	# (fishing.gd and story.gd need the game's autoloads to load, so their beasts are read from the source)
	var pools = JSON.parse_string(_const("res://scripts/world/fishing.gd", "POOLS", "(.*)"))
	if not pools is Array:
		_fail("fishing.gd: POOLS not found")
	else:
		for pool in pools:
			for id in pool:
				_race(id, "fishing pool")
	var re := RegEx.create_from_string("const BUILDER_EGG := ([0-9]+)")
	var hit := re.search(FileAccess.get_file_as_string("res://scripts/autoload/story.gd"))
	if hit == null:
		_fail("story.gd: BUILDER_EGG not found")
	else:
		_race(int(hit.get_string(1)), "the builder's egg")
	for mv in MoveDB.SIGNATURE:
		_race(MoveDB.SIGNATURE[mv], "signature move %s" % mv)
	for rank in LadderDB.RANK_NAMES.size():
		for i in LadderDB.count(rank + 1):
			_team(LadderDB.opponent(rank + 1, i).get("team", []), "ladder rank %d #%d" % [rank + 1, i])


func _songs_moves_items() -> void:
	for a in WorldDB.ARENAS:
		_song(WorldDB.ARENAS[a].get("song", ""), "arena %s song" % a)
		_song(WorldDB.ARENAS[a].get("flute", ""), "arena %s flute song" % a)
	for b in WorldDB.BARDS:
		_song(WorldDB.BARDS[b].get("song", ""), "bard on %s" % b)
	for s in SongDB.ORDER:
		_song(s, "song order")
	for el in MoveDB.POOLS:
		for mv in MoveDB.POOLS[el]:
			if MoveDB.get_move(mv).is_empty():
				_fail("move pool %s: no such move %s" % [el, mv])
	for mv in MoveDB.SIGNATURE:
		if MoveDB.get_move(mv).is_empty():
			_fail("signature move %s doesn't exist" % mv)
	for it in ItemDB.ITEMS:
		for town in ItemDB.ITEMS[it].get("sold_in", []):
			if not WorldDB.TOWNS.has(town):
				_fail("item %s: sold in %s, which isn't a town" % [it, town])


## Every map with its rooms, before and after the story's big moments: encounters and trainers name real beasts,
## bards real songs, and everyone can be dressed.
func _maps() -> void:
	var cleared := {"has_starter": true, "island_peace": true, "bandits_cleared": true, "ceo_defeated": true, "ritual_done": true}
	for flags in [{}, cleared]:
		for id in WorldDB.TOWNS.keys() + WorldDB.ROUTES.keys():
			var m := MapLoader.load_map(id, flags)
			_map(m, id)
			for b in m.get("buildings", []):
				for f in range(1, MapLoader.room_set(b).size() + 1):
					var fid := MapLoader.floor_id(b["interior"], f)
					_map(MapLoader.load_map(fid, flags), fid)


func _map(m: Dictionary, id: String) -> void:
	for x in m.get("encounter", {}).get("races", []):
		_race(x, "map %s encounters" % id)
	for n in m.get("npcs", []):
		var who := "map %s %s" % [id, n.get("name", n.get("kind", "npc"))]
		_team(n.get("team", []), who)
		if n.has("song"):
			_song(n["song"], who)
		if n.has("look") and n.get("beast_genes", null) == null and not n.has("robot_body"):
			_dress(n["look"], who)


func _dress(look: Dictionary, who: String) -> void:
	var o := Townfolk.outfit(look)
	var count: int = Townfolk.data()["parts"].size()
	for p in o["parts"]:
		if int(p) < 0 or int(p) >= count:
			_fail("%s: dressed in a part that doesn't exist (%s)" % [who, str(p)])
			return
		if not ResourceLoader.exists("res://assets/townfolk/parts/%s.res" % Townfolk.data()["parts"][int(p)]["file"]):
			_fail("%s: part %s has no mesh" % [who, str(p)])
			return


## The hero in everything the character creator offers.
func _people() -> void:
	for body in Townfolk.HERO_OUTFITS:
		for person in Townfolk.HERO_OUTFITS[body]:
			_dress({"face": "hero", "body": body, "person": person}, "hero %s outfit %d" % [body, person])
	for hd in Townfolk.HAIRDOS.size():
		_dress({"face": "hero", "hairdo": hd}, "hero hairdo %d" % hd)
	# the one pack, always on, in the colour chosen
	var o := Townfolk.outfit({"face": "hero", "pack_colour": "#3a5a8a"})
	if not o["parts"].has(Townfolk.PACK) or o["colours"].get("pack") != Color("#3a5a8a"):
		_fail("the hero isn't wearing the pack in the colour chosen")
	for id in Townfolk.PART_FIXES:
		if int(id) >= Townfolk.data()["parts"].size():
			_fail("PART_FIXES names part %d, which doesn't exist" % id)
	_dress({"outfit": "camo", "shirt": "#c84040"}, "a camo trainer")
