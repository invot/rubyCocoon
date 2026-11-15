extends RefCounted
## Exercises progression, real lesson input, and save persistence without touching player saves.
const BeatCue = preload("res://scripts/battle/beat_cue.gd")
const Beasts = preload("res://scripts/core/beasts.gd")
const FluteGame = preload("res://scripts/ui/flute_game.gd")
const Ring = preload("res://scripts/core/ring.gd")
const ML = preload("res://scripts/world/map_loader.gd")
const MG = preload("res://scripts/world/map_gen.gd")
const BuildEdition = preload("res://scripts/core/build_edition.gd")
const Codex = preload("res://scripts/ui/codex.gd")
const CodexDB = preload("res://scripts/data/codex_db.gd")
var main
var opts: Dictionary
var bad := 0
var captured := {}
var practice_missed := false
var practice_landed := false
var failed_song := false


func check(ok: bool, message: String) -> void:
	print("ok   " if ok else "FAIL ", message)
	if not ok:
		bad += 1


func shot(name: String) -> void:
	if not opts.has("shots") or DisplayServer.get_name() == "headless" or captured.has(name):
		return
	captured[name] = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(opts["shots"]))
	await main._wait(0.15)
	await RenderingServer.frame_post_draw
	main._save_shot(String(opts["shots"]).path_join(name + ".png"))


func npc(id: String) -> Dictionary:
	return main._npc(id)


func run(game, options: Dictionary) -> void:
	main = game
	opts = options
	check(GameState.save_dir().begins_with("res://build/"), "isolated tutorial state")
	if bad:
		return
	var part: String = opts.get("part", "all")
	if part in ["all", "dance"]:
		await dance()
	if part in ["all", "summon"]:
		await summon()
	if part in ["all", "rhythm"]:
		await rhythm()
	if part in ["all", "ring"]:
		await ring()
	if part in ["all", "practice"]:
		await practice()
	if part == "field":
		await field()
	if main.in_battle:
		UI.auto = true
		for battle in main.view.get_children():
			if battle.get_script() == load(main.BATTLE_PATH):
				battle.result = "win"
		var top = UI.stack.back() if not UI.stack.is_empty() else null
		if top != null and top.has_method("_rotate"):
			top.close({"kind": "go"})
		for i in 1000:
			if not main.in_battle:
				break
			await main._wait(0.025)
	UI.auto = false
	print("MECHANIC LESSONS DONE: %d problem(s)" % bad)


## Drive genuine modal input. Miss the first practice beat, then land it, including by direct tap on touch.
func drive(done: Array) -> void:
	var until := Time.get_ticks_msec() + 180000
	while not done[0] and Time.get_ticks_msec() < until:
		var top = UI.stack.back() if not UI.stack.is_empty() else null
		if top is BeatCue:
			if top._finished:
				if top.most == 1 and top.grades == ["miss"]:
					practice_missed = true
				if top.most == 1 and (top.grades.has("good") or top.grades.has("perfect")):
					practice_landed = true
			elif top.most == 1 and not practice_missed:
				pass
			else:
				await shot("rhythm_practice" if top.most == 1 else "rhythm_chain")
				if not top._finished and top._now() >= top._expected() - 0.01:
					if UI.is_touch():
						await main._tap_at(top._center)
					else:
						await main._press("ui_accept")
		elif top != null:
			if top is FluteGame:
				if top.phase in ["study", "play"]:
					await shot("summon_song")
					if not failed_song:
						for i in 3:
							await main._press("flute_%d" % ((int(top.melody[top.pos][0]) + 1) % 4 + 1))
						failed_song = true
					else:
						for button in top.melody[top.pos]:
							await main._press("flute_%d" % (int(button) + 1))
				await main._wait(0.05)
				continue
			if main._test.get("stop", "") == "trainer" and top.has_method("_rotate"):
				await main.get_tree().process_frame
				continue
			if top is UI.DialogBox:
				if not top._paged:
					await main.get_tree().process_frame
					continue
				top.shown = 99999.0
				top.text_label.visible_characters = -1
				if top.speaker == "Instructor Lucille":
					await shot("instructor")
					if top.text_label.text.contains("just the demo"):
						await shot("demo_slippers")
					if top.text_label.text.contains("In the full game"):
						await shot("demo_full_game")
				if top.speaker == "Dancer Jasper":
					await shot("demo_jasper")
				if top.speaker == "Codex":
					await shot("codex")
				if top.speaker == "Tester Tess":
					await shot("ring_coach")
				if top.speaker == "Ranger Wren":
					await shot("field_guide")
			if top is UI.DialogBox and UI.is_touch():
				await main._tap_at(top.text_label.get_global_rect().get_center())
			else:
				await main._press("ui_accept")
		await main._wait(0.025)
	check(done[0], "lesson finishes through the real input path")


func dance() -> void:
	UI.auto = true
	GameState.set_flag("dance_lesson_done", false)
	GameState.set_flag("dance_shoes_returned", false)
	GameState.inventory.erase("dance_shoes")
	GameState.trainer_level = 3
	await main._go("dustwell", Vector2i(23, 3))
	main.world.frozen = true
	var jasper := npc("dance_blocker")
	check(not jasper.is_empty(), "Jasper waits on the north road")
	check(not main.world._walkable(Vector2i(22, 2)) and not main.world._walkable(Vector2i(23, 2)), "both tiles of the single north road are blocked")
	check(is_equal_approx(jasper["node"].position.x, 23.0), "Jasper sits centered between the two road tiles")
	check(main.world.VPer.pose_of(jasper["node"]) == "sit", "Jasper is seated")
	var north: Array = main.world.map["exits"].keys().filter(func(p): return main.world.map["exits"][p]["to"] == "route4")
	check(north.size() == 2 and north.all(func(p): return p.x in [22, 23]), "one two-tile north exit")
	main.world.facing = Vector2i.UP
	await main.world._interact()
	check(GameState.flag("dance_shoes_asked") and not GameState.flag("dance_shoes_returned"), "right-hand road tile talks to the same blocker")
	await shot("jasper_blocks_road")
	await main._go("dustwell", Vector2i(4, 6))
	main.world.frozen = true
	check(not Places.door_locked(main.world.map["buildings"][1]), "dance studio is always open")
	await shot("studio_exterior")
	await main.world._enter_building(main.world.map["buildings"][1])
	for i in 800:
		if main.world.map_id == "dustwell#1" and not main._transitioning:
			break
		await main._wait(0.025)
	main.world.frozen = true
	check(main.world.map["room_key"] == "dance_studio", "existing building identity now hosts the studio")
	UI.auto_log.clear()
	await Story.talk(main.world, npc("dance_instructor"))
	check(str(UI.auto_log).contains("too weak to dance") and not GameState.flag("dance_lesson_done"), "level 3 refused without unlocking rhythm")
	GameState.trainer_level = 4
	UI.auto = false
	main.world.busy = true
	var done := [false]
	var teach := func():
		await Story.talk(main.world, npc("dance_instructor"))
		done[0] = true
	teach.call()
	await drive(done)
	main.world.busy = false
	if BuildEdition.is_demo():
		await demo_boundary()
		return
	check(GameState.flag("dance_lesson_done") and GameState.item_count("dance_shoes") == 1, "level 4 lesson unlocks rhythm and awards shoes")
	check(GameState.save_game(9), "save the completed lesson before returning shoes")
	GameState.set_flag("dance_lesson_done", false)
	check(GameState.load_game(9) and GameState.flag("dance_lesson_done") and GameState.item_count("dance_shoes") == 1, "save restores lesson and unreturned shoes")
	UI.auto = true
	await main._go("dustwell", Vector2i(23, 3))
	main.world.frozen = true
	await Story.talk(main.world, npc("dance_blocker"))
	check(GameState.flag("dance_shoes_returned") and GameState.item_count("dance_shoes") == 0, "shoes returned once")
	check(main.world._walkable(Vector2i(22, 2)) and main.world._walkable(Vector2i(23, 2)), "both road tiles reopen")
	check(await Story.can_use_exit(main.world, {"to": "route4"}), "the road to Sundown opens")
	await main._go("dustwell", Vector2i(23, 3))
	check(npc("dance_blocker").is_empty(), "Jasper is not loaded after returning shoes")
	await shot("road_open")


func demo_boundary() -> void:
	check(GameState.flag("dance_lesson_done") and GameState.item_count("dance_shoes") == 0, "demo lesson unlocks rhythm without slippers")
	check(GameState.save_game(9), "save completed demo lesson")
	GameState.set_flag("dance_lesson_done", false)
	check(GameState.load_game(9) and GameState.flag("dance_lesson_done"), "demo save restores rhythm")
	UI.auto = true
	GameState.set_flag("guardian_water")
	check(Story.next_goal() == "demo_freeplay", "hints lead to continued play instead of unavailable shoes")
	await main._go("dustwell", Vector2i(23, 3))
	main.world.frozen = true
	UI.auto = false
	var done := [false]
	var talk := func():
		await Story.talk(main.world, npc("dance_blocker"))
		done[0] = true
	talk.call()
	await drive(done)
	UI.auto = true
	check(not GameState.flag("dance_shoes_returned") and not npc("dance_blocker").is_empty(), "Jasper stays after talking")
	check(not main.world._walkable(Vector2i(22, 2)) and not main.world._walkable(Vector2i(23, 2)), "both road tiles stay blocked after lesson")
	check(not await Story.can_use_exit(main.world, {"to": "route4"}), "exit cannot pass the demo boundary")
	GameState.set_flag("dance_shoes_returned")
	GameState.add_item("dance_shoes")
	check(not await Story.can_use_exit(main.world, {"to": "route4"}), "stale flags and injected shoes cannot open the road")
	main.world.frozen = false
	main.goto_map("sundown", "start")
	check(main._pending_goto.is_empty() and not main.world.frozen, "direct travel is refused without freezing play")
	await main._go("sundown")
	check(main.world.map_id == "dustwell", "transition guard refuses later towns")
	for id in Story.WorldDB.TOWN_ORDER:
		check(BuildEdition.allows_map(id + "#0") == (Story.WorldDB.TOWN_ORDER.find(id) <= 4), "demo town and interior boundary: " + id)
	GameState.map_id = "sundown"
	GameState.last_center = "sundown"
	GameState.visited.append("sundown")
	check(GameState.save_game(9) and GameState.load_game(9), "load isolated contaminated demo state")
	check(GameState.map_id == "dustwell" and GameState.last_center == "caccoon" and not GameState.visited.has("sundown"), "out-of-demo saved destinations reset safely")
	check(not GameState.flag("dance_shoes_returned") and GameState.item_count("dance_shoes") == 0, "demo load removes stale road unlocks")
	await main._go("dustwell", Vector2i(23, 3))
	check(not npc("dance_blocker").is_empty(), "Jasper persists after reload")
	await main._go("route3", "start")
	check(main.world.map_id == "route3" and not main.world.wilds.is_empty(), "backtracking and wild beasts remain available")
	await shot("demo_freeplay")


## No summon lesson any more: nobody waits outside the temple after you win Abyssion, and the Codex can explain
## summons once one is yours.
func summon() -> void:
	UI.auto = true
	GameState.summons = []
	check(not CodexDB.eligible("summon"), "the Codex can't explain summons before you have one")
	await main._go("reef", Vector2i(70, 18))
	GameState.summons = ["water"]
	var waiting: Array = Story.extra_npcs(ML.load_map("reef", GameState.flags))
	check(waiting.filter(func(n): return n.get("id", "") in ["summon_coach", "tide_keeper"]).is_empty(), "nobody waits outside the temple after capture")
	check(CodexDB.eligible("summon"), "the Codex can explain summons once one is yours")
	GameState.summons = []


## Rhythm attacks: unlocked by Lucille's lesson, the Codex explains them in your next battle with a practice beat (a
## missed beat retries until a real hit lands, by key or by a tap on the ring).
func rhythm() -> void:
	UI.auto = false
	GameState.set_flag("dance_lesson_done")
	GameState.trainer_level = maxi(4, GameState.trainer_level)
	GameState.set_flag("codex_seen_rhythm", false)
	GameState.set_flag("ring_rotation_taught")
	main._test["stop"] = "trainer"
	practice_missed = false
	practice_landed = false
	var done := [false]
	var open := func():
		await main._battlecmd_test()
		done[0] = true
	open.call()
	await drive(done)
	check(GameState.flag("codex_seen_rhythm"), "the Codex explains rhythm attacks in the first battle after the lesson")
	check(practice_missed and practice_landed, "a missed practice beat retries until a real hit lands")
	await _leave_battle()
	GameState.set_flag("ring_rotation_taught", false)


func _leave_battle() -> void:
	if not main.in_battle:
		return
	UI.auto = true
	for battle in main.view.get_children():
		if battle.get_script() == load(main.BATTLE_PATH):
			battle.result = "win"
	var top = UI.stack.back() if not UI.stack.is_empty() else null
	if top != null and top.has_method("_rotate"):
		top.close({"kind": "go"})
	for i in 1000:
		if not main.in_battle:
			break
		await main._wait(0.025)
	UI.auto = false


func ring() -> void:
	UI.auto = false
	GameState.set_flag("ring_rotation_taught", false)
	main._test["stop"] = "trainer"
	var done := [false]
	var open := func():
		await main._battlecmd_test()
		done[0] = true
	open.call()
	await drive(done)
	var panel = UI.stack.back() if not UI.stack.is_empty() else null
	check(panel != null and panel.has_method("_rotate") and panel.info.get("rotation_lesson", false), "four-beast party: the Codex starts an interactive rotation lesson")
	# the battle (the panel closes and opens again as the ring turns)
	var after_stage = panel.hooks.get("stage", null) if panel != null and panel.has_method("_rotate") else null
	check(GameState.flag("codex_seen_ring"), "the Codex explained turning the ring")
	if panel != null and panel.has_method("_rotate"):
		var labels: Array = panel.rows[0]["options"].map(func(o): return String(o.get("label", "")))
		var codex_opt: Dictionary = panel.rows[0]["options"][labels.find("Ask Codex")] if labels.has("Ask Codex") else {}
		check(codex_opt.get("icon", "") == "help" and codex_opt.get("sub", false), "the trainer's bar has Ask Codex with its ? icon")
		var stage = panel.hooks.get("stage", null)
		check(stage != null and stage._sim != null and Codex.in_lesson(), "the ring lesson shows the Codex's simulation until you turn the ring")
	if panel == null or not panel.has_method("_rotate"):
		return
	for i in 20:
		var row: Dictionary = panel.rows[0]
		if row["options"][row["sel"]]["label"] == "Watch":
			break
		await main._press("ui_right")
	await main._press("ui_accept")
	await main._wait(0.1)
	check(panel.focus > 0, "trainer action chosen first")
	await main._press("ui_accept")
	check(not panel.picking and not GameState.flag("ring_rotation_taught"), "confirmation cannot skip the required rotation")
	await shot("ring_rotation")
	if UI.is_touch():
		await main._tap_at(UI.controls.button_rect("up").get_center())
	else:
		await main._press("ui_up")
	for i in 400:
		var top = UI.stack.back() if not UI.stack.is_empty() else null
		if top is UI.DialogBox:
			top.shown = 99999.0
			await main._press("ui_accept")
		if GameState.flag("ring_rotation_taught") and top != null and top.has_method("_rotate"):
			break
		await main._wait(0.025)
	check(GameState.flag("ring_rotation_taught"), "actual ring turn completes the lesson")
	check(after_stage != null and after_stage._sim == null and not Codex.in_lesson(), "turning the ring ends the lesson and its simulation")
	# a skipped lesson: its bubble closes, the rest of its talk is left out, and the simulation goes
	GameState.set_flag("codex_seen_protection", false)
	var skip_done := [false]
	var run_chime := func():
		await Codex.chime("protection")
		skip_done[0] = true
	run_chime.call()
	await main._wait(0.1)
	# (shot() itself waits a moment: this lands near the wipe's peak)
	await shot("sim_wipe")
	check(after_stage != null and after_stage._sim != null, "a Codex lesson turns the stage into its simulation")
	check(Sfx._music_kind == "codex", "the simulation plays its own music (Bit Quest)")
	Codex.skip()
	for i in 40:
		if skip_done[0]:
			break
		await main._wait(0.025)
	check(skip_done[0] and after_stage._sim == null and not Codex.in_lesson(), "skipping a lesson ends it at once, simulation and all")
	# (the look and the music change at the wipe's peak)
	await main._wait(0.7)
	check(Sfx._music_kind in ["battle", "boss"] and (after_stage._wipe == null or not after_stage._wipe.visible), "the battle's own music comes back after the lesson's wipe")
	# the Codex's face follows the battle: sad when one of yours faints, bouncing when you win
	Codex.react("sad", 1.0)
	await main._wait(0.05)
	check(Codex.head._react_mood == "sad" and Codex.head._react_left > 0.0, "the Codex looks sad when it's told to")
	await shot("codex_sad")
	Codex.react("excited", 1.0, true)
	await main._wait(0.2)
	check(Codex.head._bounce_left > 0.0 and absf(Codex.head._pivot.position.y) > 0.001, "the Codex bounces when it celebrates")
	await shot("codex_celebrate")
	check(GameState.flag("codex_seen_protection"), "a skipped topic still counts as told (you can ask about it)")
	# a tap on the head brings up its question list, here and now; B puts it away
	var under = UI.stack.back() if not UI.stack.is_empty() else null
	Codex.head.tapped.emit()
	var asked := false
	for i in 40:
		await main._wait(0.025)
		if not UI.stack.is_empty() and UI.stack.back() != under and Codex._asking:
			asked = true
			break
	check(asked, "a tap on the Codex brings up its question list")
	await main._press("ui_cancel")
	for i in 40:
		if not Codex._asking:
			break
		await main._wait(0.025)
	check(not Codex._asking and not UI.get_tree().paused, "B puts the list away and the battle carries on")
	for i in 80:
		var top = UI.stack.back() if not UI.stack.is_empty() else null
		if top != null and top.has_method("_rotate"):
			break
		await main._wait(0.025)
	# A first-use explanation pauses confirmation; dismissing it resumes the same choice only once.
	var active = UI.stack.back() if not UI.stack.is_empty() else null
	if active != null and active.has_method("_rotate"):
		var before: int = active.focus
		active.rows[before]["options"].append({"id": "move", "move": "heat_wave", "label": "Heat Wave", "target": "enemies"})
		active.rows[before]["sel"] = active.rows[before]["options"].size() - 1
		GameState.set_flag("codex_seen_all_targets", false)
		GameState.set_flag("codex_seen_status", false)
		await main._press("ui_accept")
		await main._wait(0.05)
		check(UI.stack.back() is UI.DialogBox and active._teaching and not active.picking, "first-use lesson pauses the actual confirm action")
		check(UI.stack.back().speaker == "Codex" and UI.stack.back().anchor_control != null, "the Codex teaches from its head in the corner")
		for i in 120:
			var top = UI.stack.back()
			if top is UI.DialogBox:
				top.shown = 99999.0
				await main._press("ui_accept")
			if active.picking:
				break
			await main._wait(0.025)
		check(active.picking and not active.rows[before].get("done", false), "lesson dismissal opens targeting without confirming it")
		check(GameState.flag("codex_seen_all_targets") and GameState.flag("codex_seen_status"), "first-use topics are saved independently")
	check(CodexDB.eligible("bat") == GameState.weapons().has("bat"), "the Codex only explains the bat once it's yours")
	GameState.set_flag("codex_off")
	GameState.set_flag("codex_seen_protection", false)
	check(not await Codex.chime("protection") and not GameState.flag("codex_seen_protection"), "switched off, the Codex stays quiet and keeps the topic for later")
	GameState.set_flag("codex_off", false)


## A Codex action lesson on rails: after explaining "Choosing for each beast" it runs one practice turn in its
## simulation, only Watch open for you, every hit shown but nobody hurt, and everything put back afterwards.
func practice() -> void:
	await _leave_battle()
	UI.auto = false
	Engine.time_scale = 2.0
	GameState.set_flag("ring_rotation_taught")
	GameState.set_flag("codex_off", false)
	GameState.set_flag("codex_seen_team", false)
	await main._do_goto("route1", "west")
	await main._wait(1.0)
	var a := Beasts.create(0, 20)
	var b := Beasts.create(3, 20)
	a.slot = 0
	b.slot = 1
	GameState.party = [a, b]
	# (in the red: once the lesson's done, the Codex heals it)
	a.hp = 1
	# every other lesson done, none skipped (earlier parts leave some untold or skipped on purpose)
	for k in GameState.flags.keys():
		if String(k).begins_with("codex_skipped_"):
			GameState.set_flag(String(k), false)
	for id in CodexDB.TOPICS:
		if String(id) != "team":
			GameState.set_flag("codex_seen_" + String(id))
	GameState.ring_side = 0
	GameState.max_shield = 4
	GameState.shield = 4
	var foes := [Beasts.create(12, 20), Beasts.create(15, 20)]
	var run_battle := func():
		await main.start_battle({"wild": false, "foes": foes, "trainer": {"name": "Tess", "cls": "Tester", "team": []}, "seed": 7})
	run_battle.call()
	var bt = null
	var panel = null
	var until := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < until:
		if bt == null:
			for c in main.view.get_children():
				if c.get_script() == load(main.BATTLE_PATH):
					bt = c
		var top = UI.stack.back() if not UI.stack.is_empty() else null
		if bt != null and bt._practice == "team" and top != null and top.has_method("_rotate"):
			panel = top
			break
		if top is UI.DialogBox and top._paged:
			top.shown = 99999.0
			await main._press("ui_accept")
		await main._wait(0.03)
	check(panel != null, "after explaining it, the Codex opens a practice turn of choosing for each beast")
	if panel == null:
		return
	await shot("practice_panel")
	check(bt._sim != null and Codex.in_lesson(), "the practice runs in the Codex's simulation")
	var open: Array = panel.rows[0]["options"].filter(func(o): return not o.get("disabled", false)).map(func(o): return String(o.get("id", "")))
	check(open.has("watch") and not open.has("weapon") and not open.has("items"), "on rails: only Watch is open for you (%s)" % str(open))
	var hp := {}
	for x in bt.st:
		hp[x] = x.hp
	var hit_seen := false
	until = Time.get_ticks_msec() + 90000
	while Time.get_ticks_msec() < until and (bt._practice != "" or Codex.in_lesson()):
		var top = UI.stack.back() if not UI.stack.is_empty() else null
		if top is UI.DialogBox and top._paged:
			top.shown = 99999.0
		if bt._practice != "" and not bt._commanding and not hit_seen and bt._acting_ref != null:
			hit_seen = true
			await shot("practice_hit")
		await main._press("ui_accept")
		await main._wait(0.05)
	check(bt._practice == "" and not Codex.in_lesson(), "the practice turn ends, and the lesson with it")
	var same := true
	for x in hp:
		if x.hp < hp[x]:
			same = false
	check(same, "nobody lost HP in the practice")
	# all its lessons done: the Codex heals a beast in the red, once
	until = Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < until and a.hp < a.max_hp():
		var top = UI.stack.back() if not UI.stack.is_empty() else null
		if top is UI.DialogBox and top._paged:
			top.shown = 99999.0
			if top.speaker == "Codex" and top.text_label.text.contains("patch you up"):
				await shot("codex_heal")
			await main._press("ui_accept")
		await main._wait(0.05)
	check(Codex.mastered() and a.hp == a.max_hp() and bt._codex_healed, "lessons done, the Codex heals a beast in the red (once a battle)")
	# the achievement needs every lesson taught, none ever skipped (asking later doesn't make up for one), tips on
	GameState.set_flag("codex_skipped_guard")
	UI.auto = true
	await Codex.explain("guard")
	UI.auto = false
	check(not Codex.mastered(), "a skipped lesson loses the Codex's heal for good")
	GameState.set_flag("codex_skipped_guard", false)
	GameState.set_flag("codex_seen_bat", false)
	check(not Codex.mastered(), "a lesson not yet given keeps the heal locked")
	GameState.set_flag("codex_seen_bat")
	GameState.set_flag("codex_off")
	check(not Codex.mastered(), "with its tips off, no heal")
	GameState.set_flag("codex_off", false)
	check(bt.result == "" and GameState.shield == 4, "the battle carries on as it was")
	await main._wait(0.8)
	check(bt._sim == null and bt.stage_env.sky != bt.SimLook._sky and not (bt._wipe != null and bt._wipe.visible), "the simulation ends with the practice, and the stage looks itself again")
	await _leave_battle()
	Engine.time_scale = 1.0


func field() -> void:
	UI.auto = true
	await main._go("route2", Vector2i(9, 6))
	main.world.frozen = true
	UI.auto = false
	var done := [false]
	var explain := func():
		await Story.talk(main.world, npc("weapon_guide"))
		done[0] = true
	explain.call()
	await drive(done)
	check(done[0], "field guide explains the mechanism beside it")
