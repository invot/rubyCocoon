extends RefCounted
## Exercises progression, real lesson input, and save persistence without touching player saves.
const BeatCue = preload("res://scripts/battle/beat_cue.gd")
const FluteGame = preload("res://scripts/ui/flute_game.gd")
const Ring = preload("res://scripts/core/ring.gd")
const ML = preload("res://scripts/world/map_loader.gd")
const MG = preload("res://scripts/world/map_gen.gd")
const BuildEdition = preload("res://scripts/core/build_edition.gd")
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
	if part in ["all", "ring"]:
		await ring()
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
				if top.speaker == "Coach Ondine":
					await shot("summon_trainer")
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
	check(practice_missed and practice_landed, "a missed practice beat retries until a real hit lands")
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


func summon() -> void:
	UI.auto = true
	GameState.summons = []
	GameState.set_flag("lesson_summon", false)
	await main._go("reef", Vector2i(70, 18))
	check(npc("summon_coach").is_empty(), "summon trainer absent before winning Abyssion")
	GameState.summons = ["water"]
	var waiting: Array = Story.extra_npcs(ML.load_map("reef", GameState.flags))
	check(waiting.filter(func(n): return n.get("id", "") in ["summon_coach", "tide_keeper"]).size() == 1, "only the summon trainer waits outside the temple after capture")
	GameState.learn_song(String(Story.WorldDB.TEMPLES["water"]["song"]))
	GameState.shield = 0
	UI.auto = false
	var done := [false]
	var leave := func():
		await main._go("reef", Vector2i(70, 18))
		done[0] = true
	leave.call()
	await drive(done)
	check(GameState.flag("lesson_summon"), "trainer appears on leaving temple and completes the summon lesson")
	check(failed_song, "failed summon can be retried in the protected lesson")
	check(npc("summon_coach").is_empty(), "completed summon trainer leaves")
	UI.auto = true
	await main._go("reef", Vector2i(70, 18))
	check(npc("summon_coach").is_empty(), "summon trainer stays absent on re-entry")


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
	check(panel != null and panel.has_method("_rotate") and panel.info.get("rotation_lesson", false), "four-beast party triggers an interactive rotation lesson")
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
	# A first-use explanation pauses confirmation; dismissing it resumes the same choice only once.
	var active = UI.stack.back() if not UI.stack.is_empty() else null
	if active != null and active.has_method("_rotate"):
		var before: int = active.focus
		active.rows[before]["options"].append({"id": "move", "move": "heat_wave", "label": "Heat Wave", "target": "enemies"})
		active.rows[before]["sel"] = active.rows[before]["options"].size() - 1
		GameState.set_flag("battle_tip_all_targets", false)
		GameState.set_flag("battle_tip_status", false)
		await main._press("ui_accept")
		await main._wait(0.05)
		check(UI.stack.back() is UI.DialogBox and active._teaching and not active.picking, "first-use lesson pauses the actual confirm action")
		check(UI.stack.back().speaker == "Tester Tess", "opponent teaches through a speech bubble")
		for i in 120:
			var top = UI.stack.back()
			if top is UI.DialogBox:
				top.shown = 99999.0
				await main._press("ui_accept")
			if active.picking:
				break
			await main._wait(0.025)
		check(active.picking and not active.rows[before].get("done", false), "lesson dismissal opens targeting without confirming it")
		check(GameState.flag("battle_tip_all_targets") and GameState.flag("battle_tip_status"), "first-use topics are saved independently")


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
