extends RefCounted
## A guest combatant (docs/scaraba-implementation-plan.md WP5; the outline's §4): a story companion who fights beside
## the party without being one of its beasts. Tam and Saffi are the first, in Valkoog.
##   - They stand on the ally side, off the ring: never in the party menu, never a command row, never one of yours to
##     choose or aim.
##   - They choose their own action each round (battle.gd `_guest_acts`): an air spell at a foe, or a heal for the
##     party's beasts or the other guest.
##   - A foe can target them, but they can't die: the hit that would fell one leaves it at 1 HP until a heal arrives
##     (battle.gd `_deal`).
## battle.gd reads the same fields a Beast has (hp, max_hp(), hp_ratio(), level, stat(), status, passives, genes,
## gear_fx(), elements(), element, ghost), so move_db.gd's moves and the shared `_apply_move` rules work on them as
## they are.
const MoveDB = preload("res://scripts/data/move_db.gd")

var nickname := "Guest"
var level := 8
## (a guest never reaches 0: the battle leaves it at 1 HP)
var hp := 30
var hp_max := 30
var element := "air"
## the voxel person it is drawn with (voxel_person.gd, as in the town)
var look := {}
## the moves it chooses between, an air attack and a heal (move_db.gd)
var moves: Array = ["gust", "mend"]
## no MP and no editable HP: a guest spends nothing and carries no statuses
var mp := 0
var status := ""
var status_turns := 0
var ghost := false
var auto_plan := ""
var passives: Array = []
var genes := {}
var slot := -1


func setup(def: Dictionary) -> void:
	nickname = String(def.get("name", "Guest"))
	look = def.get("look", {})
	level = int(def.get("level", 8))
	hp_max = maxi(1, int(def.get("hp", 24 + level * 3)))
	hp = hp_max
	element = String(def.get("element", "air"))
	if def.has("moves"):
		moves = def["moves"]


func max_hp() -> int:
	return hp_max


func max_mp() -> int:
	return 0


func hp_ratio() -> float:
	return clampf(float(hp) / maxf(1.0, float(hp_max)), 0.0, 1.0)


## A guest's stats: a little weaker than the party's beasts, so the heals are the guest's real work.
func stat(which: String) -> float:
	match which:
		"atk":
			return 14.0 + level * 1.6
		"def":
			return 12.0 + level * 1.2
		"spr":
			return 14.0 + level * 1.4
		"spd":
			return 18.0 + level * 1.5
		"eva":
			return 8.0 + level
		"acc":
			return 10.0 + level
	return 10.0


func elements() -> Array:
	return [element]


## Guests carry no gear and have no name perk: anything that looks one up gets nothing.
func gear_fx(_key: String, default = 0):
	return default


func heal_full() -> void:
	hp = hp_max


## The move a guest heals with, or "" if it has none.
func heal_move() -> String:
	for mv in moves:
		if String(MoveDB.get_move(mv).get("kind", "")) in ["heal", "cleanse"]:
			return String(mv)
	return ""


## The air spell a guest attacks with.
func attack_move() -> String:
	for mv in moves:
		if String(MoveDB.get_move(mv).get("kind", "")) == "attack":
			return String(mv)
	return "gust"
