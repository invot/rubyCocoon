extends RefCounted
## --scene=battle-poses: the beasts' battle poses in a real battle, through the battle's own camera (beast_rig.gd,
## beast_model.gd, battle.gd _cast, battle_camera.gd "cast" / "impact"):
##   1. a cast that's extra effective: the cut to the caster gathering its glow, letting it go, the cut to the foe it
##      lands on (a heavy hit, its number with it)
##   2. Defend held, then a plain attack (a lunge) blocked by it
##   3. a plain attack landing as an ordinary hit
##   4. a heal cast on an ally (its glow landing as rising motes)
##   5. a foe knocked out (the knockout shot, the faint)
## Prints what each step saw and "BATTLE POSES DONE: n problem(s)". --shots=dir saves <dir>/<step>.png (use
## --shot_w=0 for full size); --old=1 fields the old models (a legendary casting, robots for foes) for their tweened
## poses; --save_dir= keeps the test's saves apart.
const BATTLE_PATH := "res://scripts/battle/battle.gd"
const PANEL_PATH := "res://scripts/battle/command_panel.gd"
const Rig = preload("res://scripts/gfx/beast_rig.gd")
const Beasts = preload("res://scripts/core/beasts.gd")

var _bad := 0
var _main: Node
var _battle: Node


func _check(ok: bool, label: String) -> void:
	if not ok:
		_bad += 1
	print("%s %s" % ["ok  " if ok else "FAIL", label])


func run(main: Node) -> void:
	_main = main
	var old: bool = main._test.get("old", "0") == "1"
	await main._do_goto("route1", "west")
	await main._wait(1.0)
	# your side: a fire caster (a legendary's old model, with --old), a water healer, and a plain fighter
	var caster = Beasts.create(41 if old else 2, 30)
	var healer = Beasts.create(29, 30)
	var fighter = Beasts.create(17, 30)
	for b in [caster, healer, fighter]:
		b.base["hp"] = float(b.base["hp"]) * 4.0
		b.hp = b.max_hp()
		b.mp = b.max_mp()
	GameState.beast_slots = 4
	GameState.party = [caster, healer, fighter]
	# (the air-water side: slots 1, 2 and 3, the healer in the middle; slots hold only their elements)
	caster.slot = 1
	healer.slot = 2
	fighter.slot = 3
	GameState.storage = []
	GameState.ring_side = 1
	GameState.preferred_ring_side = -1
	GameState.max_shield = 2
	GameState.shield = 2
	# the foe's: an air beast (fire is extra effective on it) and a water one that defends (robots, with --old)
	var flyer = Beasts.create(44 if old else 31, 30)
	var guard = Beasts.create(45 if old else 25, 30)
	for f in [flyer, guard]:
		f.base["hp"] = float(f.base["hp"]) * 3.0
		f.hp = f.max_hp()
	main.start_battle({"wild": true, "foes": [flyer, guard], "seed": 7})
	for i in 3000:
		var top = UI.stack.back() if not UI.stack.is_empty() else null
		if top != null and top.get_script() == load(PANEL_PATH) and not top.closed:
			break
		await main.get_tree().process_frame
	for c in main.view.get_children():
		if c.get_script() == load(BATTLE_PATH):
			_battle = c
	_check(_battle != null, "the battle opens")
	if _battle == null:
		print("BATTLE POSES DONE: %d problem(s)" % _bad)
		return
	_battle._show_option({}, {})
	_battle._commanding = false
	_battle._refresh()
	for b in [caster, healer, fighter]:
		_battle._st(b)["stages"]["acc"] = 6
	var cd: RefCounted = _battle.camera_director
	if main._test.get("verbose", "0") == "1":
		cd.shot_changed.connect(func(n: String) -> void: print("  shot: %s %.2f" % [n, cd.clock]))
	print("field: ", _battle.ally_slots.map(func(b): return b.nickname if b != null else "-"), " vs ", _battle.foe_slots.map(func(b): return b.nickname if b != null else "-"), "  caster slot ", caster.slot, " ", caster.elements(), " party ", GameState.party.size(), " cap ", GameState.slot_cap())

	# 1. a cast, extra effective
	var hp0: int = flyer.hp
	var seen := await _round([{"type": "move", "actor": caster, "move": "ember", "target": flyer, "prio": 5}], [
		["cast", func() -> bool: return _battle._casting, 0.45],
		["release", func() -> bool: return _battle._casting, Rig.CAST_TIME * Rig.RELEASE_AT + 0.1],
		["impact", func() -> bool: return cd.shot == "impact", 0.24]])
	_check(seen.has("cast") and seen.has("impact"), "a cast cuts to the caster, then to where it lands (%s)" % [seen])
	_check(flyer.hp < hp0, "the cast's hit lands (%d -> %d HP)" % [hp0, flyer.hp])
	_check(_battle._casting == false, "the cast is over once the move is")

	# 2. Defend held, then a blocked lunge
	var r: Node3D = _battle._model(guard)
	seen = await _round([{"type": "defend", "actor": guard, "prio": 7},
		{"type": "move", "actor": fighter, "move": "tackle", "target": guard, "prio": 0}], [
		["defend", func() -> bool: return "braces" in UI.top_bar.current_text(), 0.5],
		["block", func() -> bool: return cd.shot == "follow", Rig.ATTACK_TIME * Rig.HIT_AT + 0.08]])
	if r is Rig:
		_check((r as Rig).guard, "a defending beast holds its braced stance")
	else:
		_check(bool(r.get_meta("pose_guard", false)), "a defending old model holds its crouch")
	_battle._end_defend("foe")
	if r is Rig:
		_check(not (r as Rig).guard, "its stance ends with Defend")

	# 3. an ordinary hit
	seen = await _round([{"type": "move", "actor": fighter, "move": "tackle", "target": flyer, "prio": 0}], [
		["hit", func() -> bool: return cd.shot == "follow", Rig.ATTACK_TIME * Rig.HIT_AT + 0.06]])

	# 4. a heal cast on an ally
	fighter.hp = fighter.max_hp() / 2
	_battle._refresh()
	seen = await _round([{"type": "move", "actor": healer, "move": "mend", "target": fighter, "prio": 0}], [
		["heal_cast", func() -> bool: return _battle._casting, 0.5],
		["heal", func() -> bool: return cd.shot == "impact", 0.3]])
	_check(fighter.hp > fighter.max_hp() / 2, "the heal lands on the ally")

	# 5. a knockout
	guard.hp = 1
	_battle._refresh()
	seen = await _round([{"type": "move", "actor": fighter, "move": "tackle", "target": guard, "prio": 0}], [
		["faint", func() -> bool: return cd.shot == "knockout", 0.75]])
	_check(guard.hp <= 0, "the foe is knocked out")
	var gr = _battle._rig(guard)
	if gr != null:
		_check(gr.state == "lie" and gr._out, "a fainted beast lies down knocked out")
	print("BATTLE POSES DONE: %d problem(s)" % _bad)


## Runs one round of `acts` (battle.gd _resolve), saving a shot for each of `marks` ([name, when it starts, seconds
## after]) as it happens; returns the names it took.
func _round(acts: Array, marks: Array) -> Array:
	var done := [false]
	var taken := []
	var go := func() -> void:
		await _battle._resolve(acts)
		done[0] = true
	go.call()
	var i := 0
	var t0 := -1.0
	var clock := 0.0
	while not done[0] or i < marks.size():
		if i < marks.size():
			var mk: Array = marks[i]
			if t0 < 0.0 and (mk[1] as Callable).call():
				t0 = clock
			if t0 >= 0.0 and clock - t0 >= float(mk[2]):
				await _shot(String(mk[0]))
				taken.append(mk[0])
				i += 1
				# (a later mark of the same shot counts from the same start)
				if i < marks.size() and not (marks[i][1] as Callable).call():
					t0 = -1.0
		elif done[0]:
			break
		if done[0] and i < marks.size() and t0 < 0.0:
			print("FAIL never saw %s" % marks[i][0])
			_bad += 1
			break
		await _main.get_tree().process_frame
		clock += _main.get_process_delta_time()
	while not done[0]:
		await _main.get_tree().process_frame
	await _main._wait(0.6)
	return taken


func _shot(name: String) -> void:
	var dir := String(_main._test.get("shots", ""))
	if dir == "":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_main._save_shot(dir.path_join(name + ".png"))
