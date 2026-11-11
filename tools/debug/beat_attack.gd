extends RefCounted
## The trainer weapons' beat attack (scripts/core/beat_chain.gd, battle/beat_cue.gd, battle.gd _weapon_chain): its rules
## on their own, then chains in a real trainer battle with presses injected at set offsets from each beat (1 to 4 hits,
## a miss part-way, the first beat missed or let go, an early press, longer chains at higher trainer levels, the
## guided first time's wider windows), one real press of A through the input path, the plain throw below trainer Lv 4,
## the boomerang on every foe, the bat's run and swing, a blow at an open trainer, a boss's rolled chain, and Sfx's
## beat clock and percussion layer.
## --scene=beat-attack [--shots=res://build/shots/beat/attack]: the cue spinning in, a hit, the end of a full chain
const BeatChain = preload("res://scripts/core/beat_chain.gd")
const BeatCue = preload("res://scripts/battle/beat_cue.gd")
const Ring = preload("res://scripts/core/ring.gd")

var _bad := 0
var _main: Node
var _battle: Node
var _shots := ""


func _check(ok: bool, label: String) -> void:
	if not ok:
		_bad += 1
	print("%s %s" % ["ok  " if ok else "FAIL", label])


func run(main: Node) -> void:
	_main = main
	_shots = String(main._test.get("shots", ""))
	_rules()
	main._test["stop"] = "trainer"
	await main._battlecmd_test()
	# (the battlecmd fixture runs at double speed: the beat attack is timed by the music, so back to real time)
	Engine.time_scale = 1.0
	for child in main.view.get_children():
		if child.get_script() == load(main.BATTLE_PATH):
			_battle = child
	if _battle == null:
		_check(false, "battle fixture opened")
		print("BEAT ATTACK DONE: %d problem(s)" % _bad)
		return
	_battle._show_option({}, {})
	_battle._commanding = false
	_battle._refresh()
	await _clock()
	await _chains()
	await _press_a()
	await _plain_and_trainer()
	await _rival()
	print("BEAT ATTACK DONE: %d problem(s)" % _bad)


func _rules() -> void:
	_check([1, 2, 3].all(func(lv): return BeatChain.max_hits(lv) == 0), "no beat attack below trainer Lv 4")
	_check(BeatChain.max_hits(4) == 3 and BeatChain.max_hits(5) == 4 and BeatChain.max_hits(9) == 8 and BeatChain.max_hits(10) == 10,
		"hits by trainer level: 3 at Lv 4, one more a level, 10 at Lv 10")
	_check(BeatChain.grade(0.0) == "perfect" and BeatChain.grade(-0.05) == "perfect" and BeatChain.grade(0.1) == "good"
		and BeatChain.grade(-0.12) == "good" and BeatChain.grade(0.2) == "miss", "grades by distance from the beat, early or late")
	_check(BeatChain.grade(0.09, true) == "perfect" and BeatChain.grade(0.18, true) == "good" and BeatChain.grade(0.18) == "miss",
		"wider windows for the guided first time and the first road")
	var full := BeatChain.hits_from(["perfect", "good", "perfect"], 3)
	_check(full.size() == 3 and full[2]["crit"] and not full[0]["crit"] and is_equal_approx(float(full[2]["mult"]), 0.5 * 1.5)
		and is_equal_approx(float(full[1]["mult"]), 0.3), "a full chain: each hit by its grade, the last critical")
	_check(BeatChain.hits_from(["miss"], 3).map(func(h): return h["grade"]) == ["weak"], "the first beat missed: one weak hit")
	_check(BeatChain.hits_from(["perfect", "miss", "perfect"], 3).size() == 1, "a miss ends the chain; hits landed count")
	_check(not BeatChain.hits_from(["perfect", "perfect"], 4).any(func(h): return h["crit"]), "no critical for a chain cut short")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var weak := 0
	var strong := 0
	for i in 300:
		weak += BeatChain.roll(0.0, 6, rng).size()
		strong += BeatChain.roll(1.0, 6, rng).size()
	_check(strong > weak and weak > 300, "a foe's rolled chain is longer the stronger they are (%d vs %d hits)" % [strong, weak])
	_check(BeatChain.level_line(3, 4) != "" and BeatChain.level_line(4, 4) == "" and BeatChain.level_line(5, 6) != "",
		"reaching a level that adds a hit says so")
	for track in Sfx.TEMPOS:
		var bar = load(Sfx._perc_path(track))
		var want: float = 4.0 * 60.0 / float(Sfx.TEMPOS[track]["bpm"])
		_check(bar is AudioStreamWAV and absf(bar.get_length() - want) < 0.001 and bar.loop_mode == AudioStreamWAV.LOOP_FORWARD,
			"%s: the percussion bar is baked, four beats long and loops" % track)
	_check(Sfx.TEMPOS.has(String(Sfx.TRACKS["battle"])) and Sfx.TEMPOS.has(String(Sfx.TRACKS["boss"])), "both battle tracks have a tempo")


## Sfx keeps the battle track's beat, and the percussion bed plays along.
func _clock() -> void:
	var b0: float = Sfx.beat_now()
	await _main._wait(1.0)
	var b1: float = Sfx.beat_now()
	var per: float = Sfx.beat_period()
	_check(not is_nan(b0) and is_equal_approx(per, 60.0 / 106.0), "the battle track's beat is kept (%.3f s a beat)" % per)
	_check(b1 - b0 > 1.0 / per * 0.8 and b1 - b0 < 1.0 / per * 1.2, "the beat moves on with the music (%.2f beats in a second)" % (b1 - b0))
	_check(Sfx._perc_mode == "bed" and Sfx._perc.playing and Sfx._perc_key == String(Sfx.TRACKS["battle"]), "the percussion layer plays quietly along")


func _foes() -> Array:
	return _battle.foe_slots.filter(Ring.standing)


func _heal_all() -> void:
	for f in _battle.foe_slots:
		if f != null:
			# (plenty of HP, so no chain is cut short by a knockout)
			f.hp = 9999
			_battle._st(f)["defend"] = false
			_battle._st(f)["shield"] = 0
			_battle._st(f)["down"] = false
			f.status = ""


## One weapon turn with `presses` injected (offsets in seconds from each beat; null: let it go by).
func _turn(weapon: String, presses: Array, target = null) -> Dictionary:
	_heal_all()
	if target == null:
		target = _foes()[0]
	UI.auto_beats = [presses]
	var hp: int = target.hp
	var done := [false]
	var go := func() -> void:
		await _battle._do_weapon({"type": "weapon", "weapon": weapon, "target": target})
		done[0] = true
	_battle.last_chain = {}
	go.call()
	var full_mid := false
	while not done[0]:
		if not UI.stack.is_empty() and UI.stack.back() is BeatCue:
			full_mid = full_mid or Sfx._perc_mode == "full"
		await _main.get_tree().process_frame
	await _main._wait(0.2)
	var out: Dictionary = _battle.last_chain.duplicate()
	out["hp_lost"] = hp - target.hp
	out["full"] = full_mid
	return out


func _chains() -> void:
	GameState.trainer_level = 4
	GameState.set_flag("beat_taught")
	# the first road keeps the wider windows; elsewhere the normal ones
	_battle.cfg["map"] = "route1"
	var r0 := await _turn("slingshot", [0.17, 0.0, 0.0], null)
	_check(r0.get("easy", false) and r0.get("landed", []).size() == 3, "on the first road the timing is easier (%s)" % [r0.get("landed", [])])
	_battle.cfg["map"] = "route2"
	_capture_mid("slingshot")
	var r := await _turn("slingshot", [0.0, 0.0, 0.0], null)
	_check(r.get("landed", []) == ["perfect", "perfect", "perfect"] and r["hp_lost"] > 0, "Lv 4: three on the beat, three hits (%s, %d damage)" % [r.get("landed", []), r["hp_lost"]])
	_check(r.get("full", false) and Sfx._perc_mode == "bed", "the percussion comes up for the chain and back down after")
	var r2 := await _turn("slingshot", [0.0, 0.1, -0.03], null)
	_check(r2.get("landed", []) == ["perfect", "good", "perfect"], "each press graded by its distance from the beat (%s)" % [r2.get("landed", [])])
	var r3 := await _turn("slingshot", [0.0, 0.3], null)
	_check(r3.get("landed", []) == ["perfect"] and r3.get("grades", []) == ["perfect", "miss"] and r3["hp_lost"] > 0, "a miss ends the chain; the hit landed counts (%s)" % [r3.get("grades", [])])
	var r4 := await _turn("slingshot", [0.25], null)
	_check(r4.get("landed", []) == ["weak"] and r4["hp_lost"] > 0, "the first beat missed: one weak hit (%s, %d damage)" % [r4.get("landed", []), r4["hp_lost"]])
	var r5 := await _turn("slingshot", [null, null, null], null)
	_check(r5.get("landed", []) == ["weak"], "every beat let go by: still one weak hit, the turn isn't wasted")
	var r6 := await _turn("slingshot", [-0.2], null)
	_check(r6.get("grades", []) == ["miss"], "a press well before the beat is a miss")
	_check(r["hp_lost"] > r4["hp_lost"], "a full chain hits harder than a glancing blow (%d vs %d)" % [r["hp_lost"], r4["hp_lost"]])
	# two hits, then the third let go: two hits, no critical
	var r7 := await _turn("slingshot", [0.0, 0.0, null], null)
	_check(r7.get("landed", []).size() == 2, "two hits then a beat let go: two hits")
	# higher trainer levels: longer chains, up to ten
	GameState.trainer_level = 7
	var six := []
	for i in 6:
		six.append(0.0)
	var r8 := await _turn("slingshot", six, null)
	_check(r8.get("landed", []).size() == 6 and r8.get("most", 0) == 6, "Lv 7: six hits on six beats")
	GameState.trainer_level = 10
	var ten := []
	for i in 10:
		ten.append(0.0)
	var r9 := await _turn("slingshot", ten, null)
	_check(r9.get("landed", []).size() == 10, "Lv 10: all ten hits (%d)" % r9.get("landed", []).size())
	# the guided first time: wider windows
	GameState.trainer_level = 4
	GameState.flags.erase("beat_taught")
	var r10 := await _turn("slingshot", [0.17, -0.17, 0.17], null)
	_check(r10.get("easy", false) and r10.get("landed", []) == ["good", "good", "good"] and GameState.flag("beat_taught"),
		"the first beat attack is guided: a press 0.17 s off still counts (%s)" % [r10.get("landed", [])])
	# the boomerang: every foe on the side facing you, each throw
	GameState.add_item("boomerang")
	_heal_all()
	var before := _foes().map(func(f): return f.hp)
	UI.auto_beats = [[0.0, 0.0, 0.0]]
	_capture_mid("boomerang")
	await _battle._do_weapon({"type": "weapon", "weapon": "boomerang", "target": null})
	await _main._wait(0.2)
	var after := _foes().map(func(f): return f.hp)
	_check(before.size() == 2 and after[0] < before[0] and after[1] < before[1] and _battle.last_chain.get("landed", []).size() == 3,
		"the boomerang sweeps both foes, three throws (%s -> %s)" % [before, after])
	# the bat: run up, three swings, back home
	GameState.add_item("bat")
	_capture_mid("bat")
	var rb := await _turn("bat", [0.0, 0.0, 0.0], null)
	_check(rb.get("landed", []).size() == 3 and rb["hp_lost"] > 0, "the bat: three swings land (%d damage)" % rb["hp_lost"])
	_check(_battle.player_rig.position.distance_to(_battle.PLAYER_POS + Vector3(0, 0.1, 0)) < 0.05, "after the bat, your trainer is back on their pad")
	_check(GameState.weapons() == ["slingshot", "boomerang", "bat"], "your weapons, in the bar's order")
	_check(_battle._weapon_options().map(func(o): return o["label"]) == ["Slingshot", "Boomerang", "Bat"], "your trainer's bar lists the weapons you own")


## A real press of A, through the input path, on the first beat: graded once, then the rest let go by.
func _press_a() -> void:
	GameState.trainer_level = 4
	GameState.set_flag("beat_taught")
	_heal_all()
	UI.auto_beats = []
	var was_auto: bool = UI.auto
	UI.auto = false
	var done := [false]
	var go := func() -> void:
		await _battle._do_weapon({"type": "weapon", "weapon": "slingshot", "target": _foes()[0]})
		done[0] = true
	_battle.last_chain = {}
	go.call()
	var cue = null
	var found := false
	while not found and not done[0]:
		await _main.get_tree().process_frame
		if not UI.stack.is_empty() and UI.stack.back() is BeatCue:
			cue = UI.stack.back()
			found = true
	var shot_hit := false
	if found:
		# the cue spinning in (captured while there's still time before the beat), then the beat itself: press A once
		for i in 8:
			await _main.get_tree().process_frame
		if _shots != "" and Sfx.beat_now() < cue.first_beat - 1.0:
			await _shot("lead")
		while Sfx.beat_now() < cue.first_beat - 0.01 and not done[0]:
			await _main.get_tree().process_frame
		var ev := InputEventAction.new()
		ev.action = "ui_accept"
		ev.pressed = true
		Input.parse_input_event(ev)
		await _main.get_tree().process_frame
		var up := InputEventAction.new()
		up.action = "ui_accept"
		up.pressed = false
		Input.parse_input_event(up)
		await _main._wait(0.12)
		if not shot_hit:
			shot_hit = true
			await _shot("hit")
	while not done[0]:
		await _main.get_tree().process_frame
	UI.auto = was_auto
	var g: Array = _battle.last_chain.get("grades", [])
	_check(found and g.size() == 2 and String(g[0]) in ["perfect", "good"] and String(g[1]) == "miss",
		"one press of A on the first beat: graded once, then the next beat let go (%s)" % [g])


func _plain_and_trainer() -> void:
	# below trainer Lv 4: one plain throw, no cue
	GameState.trainer_level = 3
	_heal_all()
	var t = _foes()[0]
	_battle._st(t)["stages"]["eva"] = -6
	var hp: int = t.hp
	var cue_seen := [false]
	var done := [false]
	var go := func() -> void:
		await _battle._do_weapon({"type": "weapon", "weapon": "slingshot", "target": t})
		done[0] = true
	go.call()
	while not done[0]:
		cue_seen[0] = cue_seen[0] or (not UI.stack.is_empty() and UI.stack.back() is BeatCue)
		await _main.get_tree().process_frame
	_battle._st(t)["stages"]["eva"] = 0
	_check(not cue_seen[0] and t.hp < hp, "below trainer Lv 4 the slingshot makes one plain throw (no cue)")
	# an open trainer: one blow, one shield point, whatever the level
	GameState.trainer_level = 10
	for f in _battle.foe_slots:
		if f != null:
			f.hp = 0
	_battle.foe_shield = 2
	_battle.result = ""
	UI.auto_beats = []
	await _battle._do_weapon({"type": "weapon", "weapon": "slingshot", "target": "trainer"})
	_check(_battle.foe_shield == 1 and _battle.result == "", "a weapon at an open trainer is one blow: one shield point (%d left)" % _battle.foe_shield)
	_heal_all()


## A boss's weapon: rolled, never played, and only at your beasts.
func _rival() -> void:
	_battle.trainer["boss"] = false
	_check(_battle._rival_weapon_action(false).is_empty(), "road trainers never use a weapon")
	_battle.trainer["boss"] = true
	var mine: Array = _battle._alive(_battle.ally_slots)
	for b in mine:
		b.hp = b.max_hp()
	var total_before := 0
	for b in mine:
		total_before += b.hp
	var shield_before := GameState.shield
	var cue_seen := [false]
	var done := [false]
	var go := func() -> void:
		await _battle._do_rival_weapon({"type": "rival_weapon", "weapon": "boomerang"})
		done[0] = true
	go.call()
	while not done[0]:
		cue_seen[0] = cue_seen[0] or (not UI.stack.is_empty() and UI.stack.back() is BeatCue)
		await _main.get_tree().process_frame
	var total_after := 0
	for b in mine:
		total_after += b.hp
	_check(not cue_seen[0] and total_after < total_before and GameState.shield == shield_before,
		"a boss's boomerang: rolled hits on your beasts, no cue, never at you (%d -> %d HP)" % [total_before, total_after])
	_battle.trainer["boss"] = false


## Captures `label` once the next chain has two hits in (the pips filling, a grade beside the ring).
func _capture_mid(label: String) -> void:
	if _shots == "":
		return
	for i in 1200:
		await _main.get_tree().process_frame
		if not UI.stack.is_empty() and UI.stack.back() is BeatCue and UI.stack.back().grades.size() >= 2:
			await _main._wait(0.06)
			await _shot(label)
			return


func _shot(label: String) -> void:
	if _shots == "":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_shots.get_base_dir())
	_main._save_shot(_shots + "_" + label + ".png")
