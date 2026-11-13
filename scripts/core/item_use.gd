extends RefCounted
## Using, equipping and dropping bag items outside battle: which of these an item allows, who it can go on, what it
## would change (before / after, for the Bag page's preview) and doing it. The Bag page (scripts/ui/bag_page.gd) and
## Menus (the beast options' Use item / Equip) share these rules.

const ItemDB = preload("res://scripts/data/item_db.gd")
const Beast = preload("res://scripts/core/beast.gd")
const MoveDB = preload("res://scripts/data/move_db.gd")

## trainer-gear effects by their fx key, as the preview names them
const TRAINER_FX := {"egg": "Egg chance", "speed": "Walking speed", "time": "Time per song", "xp": "Experience",
	"encounter": "Wild encounters", "discount": "Shop discount"}
const STAT_ROWS := ["hp", "atk", "def", "spr", "spd"]
## a beast's status (battle.gd's ailments): the short tag on its ring cell, and what it does
const STATUS := {
	"burn": ["BRN", "Burned: it loses HP each turn and its Attack is lower."],
	"poison": ["PSN", "Poisoned: it loses HP each turn."],
	"sleep": ["SLP", "Asleep: it can't act until it wakes."],
	"shock": ["PAR", "Paralyzed: it may not be able to move."],
	"blind": ["BLD", "Blinded: its attacks often miss."],
	"confuse": ["CNF", "Confused: it may hurt itself."],
	"fear": ["FER", "Terrified: it may freeze up."],
	"stun": ["STN", "Stunned: it loses its next turn."],
	"haunt": ["HNT", "Haunted by a curse."]}


## The tag on a beast's ring cell ("KO" when it has fainted, else its status's, else "") and what it means.
static func condition(b) -> Array:
	if b.hp <= 0:
		return ["KO", "Fainted: it needs reviving (a Revival Seed, or any Beast Center)."]
	if b.status != "":
		return STATUS.get(b.status, [b.status.substr(0, 3).to_upper(), b.status.capitalize() + "."])
	return ["", ""]
const STAT_SHORT := {"hp": "Max HP", "atk": "Attack", "def": "Defense", "spr": "Spirit", "spd": "Speed"}


# ---------------------------------------------------------------- what an item allows
## Has a Use action in the bag at all (consumables, incense, sheet music, bait, tomes).
static func has_use(id: String) -> bool:
	return ItemDB.get_item(id).get("kind", "") in ["use", "sheet", "bait", "tome"]


## Can be put on a beast or on you.
static func has_equip(id: String) -> bool:
	return ItemDB.get_item(id).get("kind", "") in ["gear", "tgear"]


## Key items (weapons among them) stay in the bag; everything else may be thrown away.
static func can_drop(id: String) -> bool:
	var it := ItemDB.get_item(id)
	return not it.is_empty() and it.get("kind", "") != "key" and not it.has("weapon")


## Using it means choosing one of your beasts first.
static func needs_target(id: String) -> bool:
	var it := ItemDB.get_item(id)
	return it.get("kind", "") == "use" and not it.get("battle_only", false) and not it.has("incense")


## Why Use can't be chosen right now, short enough for the right of its row ("" when it can).
static func use_block(id: String, party: Array) -> String:
	var it := ItemDB.get_item(id)
	match it.get("kind", ""):
		"use":
			if it.get("battle_only", false):
				return "In battle"
			if needs_target(id):
				for b in party:
					if beast_block(id, b) == "":
						return ""
				return "No effect"
		"tome":
			return "Bookstore"
		"bait":
			if GameState.item_count("fishing_rod") <= 0:
				return "Needs a pole"
	return ""


## Why Equip can't be chosen right now ("" when it can).
static func equip_block(id: String, party: Array) -> String:
	var it := ItemDB.get_item(id)
	if it.get("kind", "") == "tgear":
		return trainer_block(id)
	for b in party:
		if gear_block(id, b) == "":
			return ""
	return "No beasts" if party.is_empty() else "No one"


# ---------------------------------------------------------------- who it can go on
## Why a field item would do nothing for this beast ("" when it would help).
static func beast_block(id: String, b) -> String:
	var it := ItemDB.get_item(id)
	if not needs_target(id):
		return "It can't be used on a beast."
	if it.has("revive_pct"):
		return "" if b.hp <= 0 else "%s hasn't fainted." % b.nickname
	if it.get("xp_level", false):
		return "%s is at its level limit." % b.nickname if b.at_cap() else ""
	if b.hp <= 0:
		return "%s has fainted. It needs reviving first." % b.nickname
	var helps := false
	if (it.has("heal") or it.has("heal_pct")) and b.hp < b.max_hp():
		helps = true
	if (it.has("mp") or it.has("mp_pct")) and b.mp < b.max_mp():
		helps = true
	if it.get("cure", false) and b.status != "":
		helps = true
	if helps:
		return ""
	if it.has("heal") or it.has("heal_pct"):
		return "%s is already at full health." % b.nickname
	if it.has("mp") or it.has("mp_pct"):
		return "%s's MP is already full." % b.nickname
	return "%s is fine." % b.nickname


## Why this beast can't wear this gear ("" when it can).
static func gear_block(id: String, b) -> String:
	if ItemDB.get_item(id).get("kind", "") != "gear":
		return "Only you can wear that."
	if b.equip == id:
		return "%s already wears it." % b.nickname
	return ""


## Why you can't put this trainer gear on ("" when you can).
static func trainer_block(id: String) -> String:
	var it := ItemDB.get_item(id)
	if it.get("kind", "") != "tgear":
		return "That's for beasts."
	if GameState.gear.get(String(it.get("slot", "")), "") == id:
		return "You're already wearing it."
	return ""


# ---------------------------------------------------------------- previews
## What using a field item on this beast would change: [{name, before, after}], numbers as text.
static func use_preview(id: String, b) -> Array:
	var it := ItemDB.get_item(id)
	var rows := []
	if it.get("xp_level", false):
		var grown = Beast.new()
		grown.load_dict(b.to_dict().duplicate(true))
		grown.equip = b.equip
		grown.gain_xp(grown.xp_for_level(grown.level + 1) - grown.xp)
		rows.append(_row("Level", b.level, grown.level))
		rows.append(_row("HP", "%d / %d" % [maxi(0, b.hp), b.max_hp()], "%d / %d" % [grown.hp, grown.max_hp()]))
		for s in ["atk", "def", "spr", "spd"]:
			rows.append(_row(STAT_SHORT[s], b.stat(s), grown.stat(s)))
		if grown.nickname != b.nickname:
			rows.append(_row("Form", b.nickname, grown.nickname))
		return rows
	var hp: int = maxi(0, b.hp)
	var mp: int = b.mp
	if it.has("revive_pct"):
		hp = maxi(1, int(b.max_hp() * float(it["revive_pct"])))
	else:
		if it.has("heal") or it.has("heal_pct"):
			hp = mini(b.max_hp(), hp + int(it.get("heal", 0)) + int(b.max_hp() * float(it.get("heal_pct", 0.0))))
		if it.has("mp") or it.has("mp_pct"):
			mp = mini(b.max_mp(), mp + int(it.get("mp", 0)) + int(ceil(b.max_mp() * float(it.get("mp_pct", 0.0)))))
	rows.append(_row("HP", "%d / %d" % [maxi(0, b.hp), b.max_hp()], "%d / %d" % [hp, b.max_hp()]))
	rows.append(_row("MP", "%d / %d" % [b.mp, b.max_mp()], "%d / %d" % [mp, b.max_mp()]))
	if it.get("cure", false):
		rows.append(_row("Status", b.status.capitalize() if b.status != "" else "Fine", "Fine"))
	for s in ["atk", "def", "spr", "spd"]:
		rows.append(_row(STAT_SHORT[s], b.stat(s), b.stat(s)))
	return rows


## What putting this gear on this beast would change.
static func gear_preview(id: String, b) -> Array:
	var rows := [_row("Gear", ItemDB.item_name(b.equip) if b.equip != "" else "None", ItemDB.item_name(id))]
	var keep: String = b.equip
	var before := {}
	for s in STAT_ROWS:
		before[s] = b.stat(s)
	b.equip = id
	var after := {}
	for s in STAT_ROWS:
		after[s] = b.stat(s)
	var moves_after: Array = b.battle_moves()
	b.equip = keep
	for s in STAT_ROWS:
		rows.append(_row(STAT_SHORT[s], before[s], after[s]))
	var granted := String(ItemDB.get_item(id).get("grants", ""))
	if granted != "" and not b.battle_moves().has(granted) and moves_after.has(granted):
		rows.append({"name": "New move", "before": "", "after": MoveDB.get_move(granted)["name"]})
	return rows


## What putting this trainer gear on would change: the slot's gear, then each effect it touches.
static func trainer_preview(id: String) -> Array:
	var it := ItemDB.get_item(id)
	var slot := String(it["slot"])
	var old: String = GameState.gear.get(slot, "")
	var rows := [_row(ItemDB.SLOT_NAMES.get(slot, slot.capitalize()), ItemDB.item_name(old) if old != "" else "None", it["name"])]
	var old_fx: Dictionary = ItemDB.get_item(old).get("fx", {}) if old != "" else {}
	var new_fx: Dictionary = it.get("fx", {})
	for key in TRAINER_FX:
		if not old_fx.has(key) and not new_fx.has(key):
			continue
		var rest := GameState.gear_fx(key) - float(old_fx.get(key, 0.0))
		rows.append(_row(TRAINER_FX[key], _pct(GameState.gear_fx(key)), _pct(rest + float(new_fx.get(key, 0.0)))))
	return rows


static func _row(name: String, before, after) -> Dictionary:
	return {"name": name, "before": str(before), "after": str(after)}


static func _pct(v: float) -> String:
	var n := int(round(v * 100.0))
	return "%+d%%" % n if n != 0 else "0%"


# ---------------------------------------------------------------- doing it
## Puts gear on a beast, returning what it wore to the bag; its HP keeps the same distance from its new maximum.
static func put_gear_on(id: String, b) -> void:
	if id != "":
		GameState.remove_item(id)
	if b.equip != "":
		GameState.receive_item(b.equip)
	var old_max: int = b.max_hp()
	b.equip = id
	b.hp = clampi(b.hp + (b.max_hp() - old_max), 0 if b.hp <= 0 else 1, b.max_hp())


## Puts trainer gear on, returning the slot's old gear to the bag (the Reed Flute is kept apart, as always).
static func put_trainer_gear_on(id: String) -> void:
	var slot := String(ItemDB.get_item(id)["slot"])
	GameState.remove_item(id)
	var old: String = GameState.gear[slot]
	if old != "" and old != "reed_flute":
		GameState.receive_item(old)
	GameState.gear[slot] = id
