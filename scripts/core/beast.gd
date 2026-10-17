extends RefCounted
## One beast owned by the player, a trainer, or roaming wild.

const MoveDB = preload("res://scripts/data/move_db.gd")
const RaceDB = preload("res://scripts/data/race_db.gd")
const ItemDB = preload("res://scripts/data/item_db.gd")

const STAT_KEYS := ["hp", "atk", "def", "spr", "spd"]
const STAT_NAMES := {"hp": "HP", "atk": "Attack", "def": "Defense", "spr": "Spirit", "spd": "Speed"}
const MAX_MOVES := 4

var uid := 0
var nickname := ""
var race := 0
var lineage: Array = []
## the two beasts merged into this one, as snapshots (see family_node), two generations deep
var parents: Array = []
var element := "fire"
var ghost := false
var rank := 1
var level := 1
var xp := 0
var mp := 0
var base: Dictionary = {}
var genes: Dictionary = {}
var moves: Array = []
var known: Array = []
var passives: Array = []
var equip := ""
var hp := 1
var status := ""
var status_turns := 0
var origin := "wild"
var merges := 0
var abandoned := false


static func xp_for_level(l: int) -> int:
	if l <= 1:
		return 0
	return int(pow(l, 3))


func level_cap() -> int:
	return rank * 20


func at_cap() -> bool:
	return level >= level_cap()


func stat(s: String) -> int:
	var b: float = float(base.get(s, 50.0))
	var v: float
	if s == "hp":
		v = floor(2.0 * b * level / 100.0) + level + 10
	else:
		v = floor(2.0 * b * level / 100.0) + 5
	if equip != "":
		var mods: Dictionary = ItemDB.get_item(equip).get("mods", {})
		v *= 1.0 + float(mods.get(s, 0.0))
	return maxi(1, int(v))


func max_hp() -> int:
	return stat("hp")


## MP pays for elemental attacks. It grows with Spirit and level, and only comes back from healing and MP items.
func max_mp() -> int:
	return 8 + stat("spr") / 2 + level / 2


func mp_ratio() -> float:
	return clampf(float(mp) / float(maxi(1, max_mp())), 0.0, 1.0)


func is_fainted() -> bool:
	return hp <= 0


func hp_ratio() -> float:
	return clampf(float(hp) / float(max_hp()), 0.0, 1.0)


func heal_full() -> void:
	hp = max_hp()
	mp = max_mp()
	status = ""
	status_turns = 0


func display_name() -> String:
	return nickname


func rank_stars() -> String:
	return "★".repeat(rank)


func gear_fx(key: String, default = 0.0):
	if equip == "":
		return default
	return ItemDB.get_item(equip).get("fx", {}).get(key, default)


## Moves usable in battle, including one granted by equipment.
func battle_moves() -> Array:
	var out := moves.duplicate()
	if equip != "":
		var g: String = ItemDB.get_item(equip).get("grants", "")
		if g != "" and not out.has(g):
			out.append(g)
	return out


func learn(move_id: String) -> String:
	## Returns "new" (added to active moves), "known" (stored), or "" (already had it).
	if known.has(move_id):
		return ""
	known.append(move_id)
	if moves.size() < MAX_MOVES:
		moves.append(move_id)
		return "new"
	return "known"


func can_learn(move_id: String) -> bool:
	var el: String = MoveDB.get_move(move_id)["el"]
	if el == "neutral":
		return true
	if ghost:
		return true
	return el == element or _lineage_elements().has(el)


func _lineage_elements() -> Array:
	var out := []
	for r in lineage:
		var e := RaceDB.element(int(r))
		if not out.has(e):
			out.append(e)
	return out


func _learnset_at(l: int) -> Array:
	var out := []
	var races := lineage if lineage.size() > 0 else [race]
	for r in races:
		var ls: Array = RaceDB.ghost_learnset(int(r)) if ghost else RaceDB.learnset(int(r))
		for e in ls:
			if int(e[0]) == l and not out.has(e[1]):
				out.append(e[1])
	return out


## Adds experience. Returns a list of event dictionaries for messages.
func gain_xp(amount: int) -> Array:
	var events := []
	if at_cap() or amount <= 0:
		return events
	xp += amount
	while level < level_cap() and xp >= xp_for_level(level + 1):
		var old_max := max_hp()
		var old_mp := max_mp()
		level += 1
		hp = mini(max_hp(), hp + (max_hp() - old_max)) if hp > 0 else hp
		mp = mini(max_mp(), mp + (max_mp() - old_mp))
		events.append({"type": "level", "level": level})
		for mv in _learnset_at(level):
			var res := learn(mv)
			if res != "":
				events.append({"type": "learn", "move": mv, "active": res == "new"})
	if at_cap():
		xp = xp_for_level(level)
		events.append({"type": "cap"})
	return events


func xp_progress() -> float:
	if at_cap():
		return 1.0
	var a := xp_for_level(level)
	var b := xp_for_level(level + 1)
	return clampf(float(xp - a) / float(maxi(1, b - a)), 0.0, 1.0)


## A snapshot of this beast for family trees: {name, race, rank, element, ghost, parents}.
func family_node(depth := 2) -> Dictionary:
	var ps := []
	if depth > 0:
		for p in parents:
			ps.append(_trim(p, depth - 1))
	return {"name": nickname, "race": race, "rank": rank, "element": element, "ghost": ghost, "parents": ps}


static func _trim(node: Dictionary, depth: int) -> Dictionary:
	var out := node.duplicate()
	var ps := []
	if depth > 0:
		for p in node.get("parents", []):
			ps.append(_trim(p, depth - 1))
	out["parents"] = ps
	return out


func lineage_text() -> String:
	var names := []
	for r in lineage:
		names.append(RaceDB.race_name(int(r)))
	return " × ".join(names)


func to_dict() -> Dictionary:
	return {
		"uid": uid, "nickname": nickname, "race": race, "lineage": lineage, "element": element,
		"ghost": ghost, "rank": rank, "level": level, "xp": xp, "mp": mp, "base": base, "genes": genes,
		"moves": moves, "known": known, "passives": passives, "equip": equip, "hp": hp,
		"origin": origin, "merges": merges, "abandoned": abandoned, "parents": parents,
	}


func load_dict(d: Dictionary) -> void:
	uid = int(d.get("uid", randi()))
	nickname = d.get("nickname", "Beast")
	race = int(d.get("race", 0))
	lineage = d.get("lineage", [race])
	element = d.get("element", "fire")
	ghost = d.get("ghost", false)
	rank = int(d.get("rank", 1))
	level = int(d.get("level", 1))
	xp = int(d.get("xp", 0))
	mp = int(d.get("mp", -1))
	base = d.get("base", {})
	genes = d.get("genes", {})
	moves = d.get("moves", [])
	known = d.get("known", [])
	passives = d.get("passives", [])
	equip = d.get("equip", "")
	hp = int(d.get("hp", 1))
	origin = d.get("origin", "wild")
	merges = int(d.get("merges", 0))
	abandoned = d.get("abandoned", false)
	parents = d.get("parents", [])
	status = ""
	# JSON turns ints into floats; normalise lineage ids
	var lin := []
	for r in lineage:
		lin.append(int(r))
	lineage = lin
	if genes.has("size"):
		genes["size"] = float(genes["size"])
	# saves from before the PSX beasts: the model comes from the race
	if not genes.has("form") and not genes.has("model"):
		genes["form"] = RaceDB.form(race)
