extends RefCounted
## Queued actions whose target is down by the time they happen are passed on (ring.gd retarget, battle.gd _retarget):
## two beasts aim at one foe and the first knocks it out; again with only the trainer left; then with nobody left.
## --scene=battle-redirect --shots=res://build/shots/battle_redirect
const Ring = preload("res://scripts/core/ring.gd")
const MoveDB = preload("res://scripts/data/move_db.gd")


class Dummy:
	var hp := 10
	var top := 10
	func _init(h: int) -> void:
		hp = h
	func hp_ratio() -> float:
		return float(hp) / float(top)


var _bad := 0


func _check(ok: bool, label: String) -> void:
	if not ok:
		_bad += 1
	print("%s %s" % ["ok  " if ok else "FAIL", label])


func run(main: Node) -> void:
	_rules()
	main._test["stop"] = "trainer"
	await main._battlecmd_test()
	var battle: Node
	for child in main.view.get_children():
		if child.get_script() == load(main.BATTLE_PATH):
			battle = child
	if battle == null:
		_check(false, "battle fixture opened")
		print("BATTLE REDIRECT DONE: %d problem(s)" % _bad)
		return
	var shots := String(main._test.get("shots", ""))
	var capture := func(label: String) -> void:
		if shots == "":
			return
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(shots.get_base_dir())
		main._save_shot(shots + "_" + label + ".png")
	battle._show_option({}, {})
	battle._commanding = false
	battle._refresh()
	var first = battle.ally_slots[0]
	var second = battle.ally_slots[1]
	var foes: Array = battle.foe_slots.filter(Ring.standing)
	_check(foes.size() == 2 and first != null and second != null, "fixture: two of your beasts face two foes")
	var x = foes[0]
	var y = foes[1]
	# (neither attack can miss, so the checks below don't depend on luck)
	for b in [first, second]:
		battle._st(b)["stages"]["acc"] = 6
		b.status = ""
	var cost := MoveDB.mp_cost("ember")
	second.mp = second.max_mp()
	battle.foe_shield = 2
	battle.foe_max_shield = 2

	# 1. both aim at one foe; the first knocks it out, the second's attack goes to the foe beside it
	x.hp = 1
	y.hp = y.max_hp()
	var mp_before: int = second.mp
	var seen := await _round(main, battle, [
		{"type": "move", "actor": first, "move": "tackle", "target": x, "prio": 5},
		{"type": "move", "actor": second, "move": "ember", "target": x, "prio": 0}], second, capture, "foe")
	_check(x.hp <= 0, "the first attack knocks out the foe both were aimed at")
	_check(y.hp < y.max_hp(), "the second attack lands on the other foe standing on that side")
	_check(second.mp == mp_before - cost and cost > 0, "the redirected move spends its MP once")
	_check(not seen.any(func(t): return "no target" in t), "no 'no target' message")

	# 2. only the trainer left: the second attack is turned on the trainer
	y.hp = 1
	mp_before = second.mp
	var shield: int = battle.foe_shield
	seen = await _round(main, battle, [
		{"type": "move", "actor": first, "move": "tackle", "target": y, "prio": 5},
		{"type": "move", "actor": second, "move": "ember", "target": y, "prio": 0}], second, capture, "trainer")
	_check(y.hp <= 0, "the first attack knocks out the last foe facing you")
	_check(battle.foe_shield == shield - 1 and battle.result == "", "the second attack strikes their trainer (a shield point breaks)")
	_check(second.mp == mp_before - cost, "the attack on the trainer spends its MP")

	# 3. nobody left to hit (as against a wild pack): the action is dropped without a word and costs no MP
	battle.wild = true
	mp_before = second.mp
	seen = await _round(main, battle, [{"type": "move", "actor": second, "move": "ember", "target": y, "prio": 0}], second, capture, "")
	battle.wild = false
	battle.result = ""
	_check(second.mp == mp_before, "a dropped move costs no MP")
	_check(not seen.any(func(t): return second.nickname in t), "a dropped move says nothing")
	var had: int = GameState.item_count("minor_potion")
	GameState.add_item("minor_potion")
	_check(battle._targets_for(second, {"target": "enemy", "kind": "status"}, y).is_empty(), "a weakening move is never turned on a trainer")
	_check(battle._targets_for(second, MoveDB.get_move("fire_spin"), y).is_empty(), "a hit-everyone move only drops the fallen: no trainer strike")

	# healing: a fallen ally's heal goes to the weakest one standing; a revive stays with its target
	var third = battle.ally_slots[2]
	first.hp = 0
	second.hp = second.max_hp()
	third.hp = maxi(1, third.max_hp() / 3)
	_check(battle._targets_for(second, {"target": "ally", "kind": "heal"}, first) == [third], "a heal for a fallen ally goes to the weakest ally standing")
	_check(battle._targets_for(second, {"target": "ally_ko", "kind": "revive"}, first) == [first], "a revive keeps its fallen target")
	_check(battle._targets_for(second, {"target": "ally_ko", "kind": "revive"}, third).is_empty(), "a revive is not passed on to a standing ally")
	var hp_before: int = third.hp
	await battle._do_item({"type": "item", "item": "minor_potion", "target": first})
	_check(third.hp > hp_before and GameState.item_count("minor_potion") == had, "a potion for a fallen ally heals the weakest one standing")
	GameState.add_item("minor_potion")
	third.hp = 0
	second.hp = 0
	await battle._do_item({"type": "item", "item": "minor_potion", "target": first})
	_check(GameState.item_count("minor_potion") == had + 1, "with nobody standing the potion stays in the bag")
	print("BATTLE REDIRECT DONE: %d problem(s)" % _bad)


## Resolves `acts`, returning every caption shown; captures `label` while `watch` is acting on its passed-on target.
func _round(main: Node, battle: Node, acts: Array, watch, capture: Callable, label: String) -> Array:
	var done := [false]
	var seen := []
	var shot := label == ""
	var last := UI.top_bar.current_text()
	var go := func() -> void:
		await battle._resolve(acts)
		done[0] = true
	go.call()
	while not done[0]:
		var text := UI.top_bar.current_text()
		if text != last:
			last = text
			seen.append(text)
		if not shot and battle._acting_ref == watch and watch.nickname in text:
			shot = true
			await main._wait(0.15)
			await capture.call(label)
		await main.get_tree().process_frame
	await main._wait(0.3)
	return seen


## The shared rule itself (Ring.retarget / weakest), on bare rows.
func _rules() -> void:
	var up := Dummy.new(10)
	var mid := Dummy.new(10)
	var low := Dummy.new(4)
	var down := Dummy.new(0)
	_check(Ring.retarget([up, mid, low], 1, 0, true) == 1, "a standing target is kept")
	_check(Ring.retarget([up, down, low], 1, 0, true) == 0, "middle down: the corner nearer the attacker's row (top)")
	_check(Ring.retarget([up, down, low], 1, 2, true) == 2, "middle down: the corner nearer the attacker's row (bottom)")
	_check(Ring.retarget([down, mid, low], 0, 2, true) == 1, "top down: the middle before the far corner")
	_check(Ring.retarget([down, down, low], 0, 0, true) == 2, "a standing foe comes before the open trainer")
	_check(Ring.retarget([down, null, down], 0, 0, true) == Ring.TRAINER, "nobody standing: the trainer")
	_check(Ring.retarget([down, null, down], 0, 0, false) == Ring.NO_TARGET, "nobody standing and no trainer: dropped")
	_check(Ring.retarget([up, down, low], Ring.TRAINER, 2, true) == Ring.TRAINER, "aimed at a trainer who is still open: kept")
	_check(Ring.retarget([up, mid, low], Ring.TRAINER, 2, true) == 2, "the trainer covered again: the foe facing the attacker")
	_check(Ring.retarget([up, mid, low], Ring.NO_TARGET, -1, true) == 1, "a trainer's action with its target gone: the middle")
	_check(Ring.weakest([up, down, low]) == low and Ring.weakest([down, null]) == null, "weakest standing ally")
