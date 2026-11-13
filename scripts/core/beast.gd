extends RefCounted
## One beast owned by the player, a trainer, or roaming wild.

const MoveDB = preload("res://scripts/data/move_db.gd")
const RaceDB = preload("res://scripts/data/race_db.gd")
const ItemDB = preload("res://scripts/data/item_db.gd")

const STAT_KEYS := ["hp", "atk", "def", "spr", "spd"]
const STAT_NAMES := {"hp": "HP", "atk": "Attack", "def": "Defense", "spr": "Spirit", "spd": "Speed"}
## Plain (neutral) moves have their own two slots, so a beast can always fight off its element.
const PLAIN_SLOTS := 2
## Elemental move slots of a newly hatched first form; each growth into a next form adds one, a merge two.
const FIRST_ELEM_SLOTS := 2

var uid := 0
var nickname := ""
var race := 0
var lineage: Array = []
## the two beasts merged into this one, as snapshots (see family_node), two generations deep
var parents: Array = []
var element := "fire"
## a merged beast of two neighbouring elements on the ring also counts as this one ("" for most beasts)
var element2 := ""
var ghost := false
var rank := 1
var level := 1
var xp := 0
var mp := 0
var base: Dictionary = {}
var genes: Dictionary = {}
var moves: Array = []
## the moves it has learned and not forgotten (the same as `moves`: a forgotten move is gone for good)
var known: Array = []
## how many elemental moves it can hold, split between its elements when it has two (see slot_size)
var elem_slots := FIRST_ELEM_SLOTS
var passives: Array = []
var equip := ""
var hp := 1
var status := ""
var status_turns := 0
var origin := "wild"
var merges := 0
var abandoned := false
## where it stands on its trainer's battle ring (see ring.gd), or -1 (in storage, or not placed yet)
var slot := -1


static func xp_for_level(l: int) -> int:
	if l <= 1:
		return 0
	return int(pow(l, 3))


## Rank 1 tops out at Lv 40, when a beast has grown into its line's final form and can merge; every merge raises
## the limit by 20.
func level_cap() -> int:
	return mini(100, 20 + rank * 20)


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


## MP pays for elemental attacks. Healing, MP items and growing a level restore it.
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


## The beast's elements: one, or two for a dual beast (water and earth, say).
func elements() -> Array:
	return [element] if element2 == "" else [element, element2]


## "Water", or "Water / Earth" for a dual beast.
func element_text() -> String:
	return " / ".join(elements().map(func(e): return String(e).capitalize()))


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


## Returns "new" (it took a free slot), "full" (its slots for that kind of move are full: the player decides what to
## forget, see Menus.decide_learn; nothing changed) or "" (it already has it).
func learn(move_id: String) -> String:
	if moves.has(move_id):
		return ""
	var group := slot_group(move_id)
	if slot_moves(group).size() >= slot_size(group):
		return "full"
	moves.append(move_id)
	_sync_known()
	return "new"


## Forgets `old` for good and uses `new_move` in its place.
func replace_move(old: String, new_move: String) -> void:
	var i := moves.find(old)
	if i < 0:
		moves.append(new_move)
	else:
		moves[i] = new_move
	_sync_known()


## Which slots a move takes: "plain" for a neutral move, else one of its elements. A move of another element (a ghost's
## moves, or a merge's lineage) uses its main element's slots.
func slot_group(move_id: String) -> String:
	var el := String(MoveDB.get_move(move_id).get("el", "neutral"))
	if el == "neutral":
		return "plain"
	return el if element2 != "" and el == element2 else element


## How many moves a group holds. A beast of two elements splits its elemental slots evenly (the odd one to its main).
func slot_size(group: String) -> int:
	if group == "plain":
		return PLAIN_SLOTS
	if element2 == "":
		return elem_slots if group == element else 0
	if group == element2:
		return elem_slots / 2
	return elem_slots - elem_slots / 2 if group == element else 0


func slot_moves(group: String) -> Array:
	return moves.filter(func(m): return slot_group(m) == group)


## Its slot groups in order: its element(s), then plain.
func slot_groups() -> Array:
	return ([element] if element2 == "" else [element, element2]) + ["plain"]


## Drops moves that no longer fit their slots, keeping the most recently learned (the end of `moves`).
func fit_moves() -> void:
	var kept := []
	var counts := {}
	for i in range(moves.size() - 1, -1, -1):
		var m: String = moves[i]
		var g := slot_group(m)
		if kept.has(m) or int(counts.get(g, 0)) >= slot_size(g):
			continue
		counts[g] = int(counts.get(g, 0)) + 1
		kept.push_front(m)
	moves = kept
	_sync_known()


func _sync_known() -> void:
	known = moves.duplicate()


## The slot count a beast should have from its form and rank (new beasts, and saves from before slots).
static func default_elem_slots(race_id: int, rank_n: int) -> int:
	return FIRST_ELEM_SLOTS + RaceDB.stage(race_id) - 1 + 2 * maxi(0, rank_n - 1)


func can_learn(move_id: String) -> bool:
	var el: String = MoveDB.get_move(move_id)["el"]
	if el == "neutral":
		return true
	if ghost:
		return true
	return el == element or el == element2 or _lineage_elements().has(el)


func _lineage_elements() -> Array:
	var out := []
	for r in lineage:
		for e in [RaceDB.element(int(r)), RaceDB.element2(int(r))]:
			if e != "" and not out.has(e):
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
		var previous := growth_look()
		level += 1
		hp = max_hp()
		mp = max_mp()
		var lv_event := {"type": "level", "level": level, "before": previous, "look": growth_look()}
		events.append(lv_event)
		var nf := RaceDB.for_level(race, level)
		if nf != race:
			var was := nickname
			var before := growth_look()
			evolve(nf)
			events.append({"type": "evolve", "from": was, "to": nickname,
				"before": before, "after": growth_look()})
		var learned := []
		for mv in _learnset_at(level):
			var res := learn(mv)
			if res != "":
				events.append({"type": "learn", "move": mv, "active": res == "new"})
				learned.append({"move": mv, "active": res == "new"})
		# (the level-up film lists what it learned beside its stats)
		lv_event["look"]["learned"] = learned
	if at_cap():
		xp = xp_for_level(level)
		events.append({"type": "cap"})
	return events


## Grows into another form of its line (as it levels past RaceDB.EVOLVE): its stats grow as the forms' do, and it
## takes the new form's look and its name (unless it was given a name of its own).
func evolve(nf: int) -> void:
	var old := race
	var ob := RaceDB.base_stats(old)
	var nb := RaceDB.base_stats(nf)
	for i in STAT_KEYS.size():
		var k: String = STAT_KEYS[i]
		base[k] = snappedf(float(base.get(k, 50.0)) * nb[i] / maxf(ob[i], 1.0), 0.1)
	var shade: float = genes.get("shade", 0.0)
	genes = RaceDB.genes(nf)
	genes["shade"] = shade
	var oname := RaceDB.race_name(old)
	if nickname == oname or nickname == "Umbral " + oname:
		nickname = nickname.replace(oname, RaceDB.race_name(nf))
	lineage = lineage.map(func(r): return nf if int(r) == old else int(r))
	race = nf
	elem_slots += maxi(0, RaceDB.stage(nf) - RaceDB.stage(old))
	hp = max_hp()
	mp = max_mp()


## Small immutable presentation snapshot: rewards may cross both evolution thresholds at once.
func growth_look() -> Dictionary:
	return {"genes": genes.duplicate(true), "name": nickname, "race": race, "level": level, "elements": elements(),
		"hp": max_hp(), "mp": max_mp(), "stats": {"hp": max_hp(), "mp": max_mp(),
			"atk": stat("atk"), "def": stat("def"), "spr": stat("spr"), "spd": stat("spd")}}


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
		"uid": uid, "nickname": nickname, "race": race, "lineage": lineage, "element": element, "element2": element2, "slot": slot,
		"ghost": ghost, "rank": rank, "level": level, "xp": xp, "mp": mp, "base": base, "genes": genes,
		"moves": moves, "known": known, "elem_slots": elem_slots, "passives": passives, "equip": equip, "hp": hp,
		"origin": origin, "merges": merges, "abandoned": abandoned, "parents": parents,
	}


func load_dict(d: Dictionary) -> void:
	uid = int(d.get("uid", randi()))
	nickname = d.get("nickname", "Beast")
	race = int(d.get("race", 0))
	lineage = d.get("lineage", [race])
	element = d.get("element", "fire")
	element2 = String(d.get("element2", ""))
	slot = int(d.get("slot", -1))
	ghost = d.get("ghost", false)
	rank = int(d.get("rank", 1))
	level = int(d.get("level", 1))
	xp = int(d.get("xp", 0))
	mp = int(d.get("mp", -1))
	base = d.get("base", {})
	genes = d.get("genes", {})
	moves = d.get("moves", [])
	known = d.get("known", [])
	elem_slots = int(d.get("elem_slots", default_elem_slots(race, rank)))
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
	# (saves from before move slots: keep the newest moves that fit; forgotten moves are no longer remembered)
	fit_moves()
	if genes.has("size"):
		genes["size"] = float(genes["size"])
