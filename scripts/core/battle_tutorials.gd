extends RefCounted
## First-use explanations shared by the battle controller and its previews. Completion lives in ordinary save flags.
const MoveDB = preload("res://scripts/data/move_db.gd")

const TIPS := {
	"retarget": "If an attack's target falls before it lands, it aims at another standing foe. With none left, it can hit an exposed trainer. A heal goes to the ally with the least HP left; a revive stays on its chosen beast.",
	"passives": "Beasts' passive abilities and worn equipment work automatically. You don't spend a turn activating them. The Beasts page in your Start book explains each beast's abilities and gear.",
	"accuracy": "Some moves can miss. Accuracy is the move's hit chance; evasion makes a target harder to hit. A miss still spends the move's MP, so check its description before committing.",
	"shift": "Move uses a beast's turn to change its ring slot. Pick a lit pad with up/down or tap it, then A. You can swap with a fainted beast, but must keep your middle guarded. Only one beast can Move each round.",
	"cooldown": "Some moves need time to recharge. Their menu shows how many turns remain. Pick another move while you wait; plain attacks cost no MP.",
	"support": "Some moves help your own beasts. Choose the move, then aim at an ally and confirm with A. Healing restores HP; a revive brings back a fainted beast.",
	"all_targets": "This move reaches everyone shown by the arrows. You confirm the whole group once with A; you don't need to pick each beast.",
	"status": "Status effects can hurt a beast or stop it acting. Read the move's effect in the top bar. Cure items and cleansing moves remove harmful status; Defend only reduces damage.",
	"stats": "Boosts make a beast's stats stronger; reductions make them weaker. The move's description names the stats it changes. These changes last for this battle.",
	"recoil": "Recoil hurts the beast using the move too. Check its HP before choosing it. Drain works the other way: it restores HP from the damage dealt.",
	"protection": "Protective moves can absorb hits, draw attacks or counter them. The top bar explains this move's protection and how long it lasts.",
	"boomerang": "Your Boomerang sweeps every foe facing you in one throw. Confirm all its targets together. Each extra target takes a slightly softer hit.",
	"bat": "Your Bat hits one foe harder than your other weapons. Pick it beside your trainer, aim at a foe, then A. Rhythm attacks use the same beat timing as your slingshot.",
}


static func topics(option: Dictionary) -> Array:
	var out := []
	if option.get("id", "") == "shift":
		out.append("shift")
	var weapon: String = option.get("weapon", "")
	if weapon in ["boomerang", "bat"]:
		out.append(weapon)
	if not option.has("move"):
		return out
	var m := MoveDB.get_move(option["move"])
	var fx: Dictionary = m.get("fx", {})
	if int(m.get("acc", 100)) < 100:
		out.append("accuracy")
	if int(m.get("cd", 0)) > 0:
		out.append("cooldown")
	if m.get("target", "") in ["ally", "allies", "ally_ko"]:
		out.append("support")
	if m.get("target", "") in ["enemies", "allies"]:
		out.append("all_targets")
	if fx.has("status") or fx.has("cure"):
		out.append("status")
	if fx.has("buff") or fx.has("debuff") or fx.has("self_buff"):
		out.append("stats")
	if fx.has("recoil") or fx.has("drain"):
		out.append("recoil")
	if ["shield_pct", "taunt", "counter", "vanish", "wraith", "regen"].any(func(k): return fx.has(k)):
		out.append("protection")
	return out
