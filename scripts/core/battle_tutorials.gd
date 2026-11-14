extends RefCounted
## Which Codex topics (scripts/data/codex_db.gd) a battle choice brings up: the Codex chimes in about each the first
## time it's picked (scripts/ui/codex.gd chime). Completion lives in ordinary save flags ("codex_seen_<id>").
const MoveDB = preload("res://scripts/data/move_db.gd")


static func topics(option: Dictionary) -> Array:
	var out := []
	if option.get("id", "") == "shift":
		out.append("move")
	var weapon: String = option.get("weapon", "")
	if weapon in ["boomerang", "bat"]:
		out.append(weapon)
	if not option.has("move"):
		return out
	var m := MoveDB.get_move(option["move"])
	var fx: Dictionary = m.get("fx", {})
	if String(m.get("kind", "")) == "attack" and String(m.get("el", "")) in ["fire", "water", "earth", "air"]:
		out.append("elements")
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
