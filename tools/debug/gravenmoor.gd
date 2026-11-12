extends RefCounted
## Fresh-state fog arrival, NPC context, ghost guidance and written-text input checks.
## --scene=gravenmoor --shots=res://build/shots/gravenmoor [--touch] [--preview=arrival|talk|notice]
const VA = preload("res://scripts/gfx/voxel_assets.gd")
const UIKit = preload("res://scripts/ui/ui_kit.gd")
var main
var bad := 0


func run(root, opts: Dictionary) -> void:
	main = root
	if UIKit.touch_ui():
		Prefs.touch_controls = "on"
		UI.controls.refresh()
	if DisplayServer.get_name() == "headless":
		main.get_window().size = Vector2i(2400, 1080) if UIKit.touch_ui() else Vector2i(1920, 1080)
		main._fit_view()
	for flag in ["intro_done", "got_egg", "has_starter", "tutorial_done", "lesson_weaken", "lesson_capture",
			"arena_lesson_team", "arena_lesson_elements", "island_peace", "guardian_water", "met_sheriff", "bandits_cleared",
			"guardian_air", "mine_pass_ok", "ceo_defeated", "trainers_freed", "guardian_fire", "relic_quest", "ritual_done", "guardian_earth"]:
		GameState.set_flag(flag)
	GameState.gear["flute"] = "reed_flute"
	GameState.learn_song("weaken")
	GameState.set_flag("lesson_team")
	GameState.set_flag("lesson_elements")
	GameState.crests.append(Story.WorldDB.ARENAS["tidewater"]["crest"])
	UI.auto = true
	# The old arrival flags remain compatible, but no arrival explains the scenery in a modal.
	for spec in [["reef", "seen_reef"], ["route9", "seen_roots"], ["route10", "seen_moor"], ["gravenmoor", "ghost_merge"]]:
		UI.auto_log.clear()
		await main._go(spec[0], "start")
		_check(GameState.flag(spec[1]) and UI.auto_log.is_empty() and not main.world.busy, spec[0] + ": silent arrival keeps its progression flag")
	var villager: Dictionary = {}
	for n in main.world.npcs.values():
		n["wander"] = false
		if n.get("kind", "") == "villager":
			villager = n
	_check(not villager.is_empty(), "a local is available to speak to")
	if villager.is_empty():
		return
	UI.auto_log.clear()
	await Story.talk(main.world, villager)
	_check(UI.auto_log.size() == 1 and String(UI.auto_log[0]).begins_with(villager["name"] + ":") and "fog" in String(UI.auto_log[0]), "the local notices the fog in named speech")
	GameState.set_flag("game_cleared")
	UI.auto_log.clear()
	await Story.talk(main.world, villager)
	_check("Legion" in String(UI.auto_log[0]) or "ghost's back" in String(UI.auto_log[0]), "the local's reaction changes after the Legion falls")
	GameState.flags.erase("game_cleared")
	UI.auto_log.clear()
	await Story.talk(main.world, main._npc("gravedigger"))
	_check(not GameState.knows_song("requiem") and GameState.flag("got_requiem"), "Mort explains Shadow Eggs and teaches no capture song")
	UI.auto_answers = [3]
	UI.auto_log.clear()
	await Places.beast_center("gravenmoor")
	_check("Shadow Egg" in String(UI.auto_log[0]) and String(UI.auto_log[0]).begins_with("Nurse Clover:"), "Clover explains ghost eggs herself")
	var lamps: Array[Node] = main.world.find_children("StreetLampLight*", "OmniLight3D", true, false)
	_check(lamps.size() == 4, "Gravenmoor's four lamps cast light")
	for lamp in lamps:
		_check(lamp.light_energy > 0 and not lamp.shadow_enabled, "lamplight stays on without extra shadow casters")
	var lit := VA.street_lamp(true)
	_check(lit == VA.street_lamp(true) and lit != VA.street_lamp(false), "lit lamp meshes are shared and daytime lamps stay separate")
	var glow := false
	for i in lit.get_surface_count():
		if lit.surface_get_name(i) == "lit_glass":
			glow = lit.surface_get_material(i).emission_enabled
	_check(glow, "the lantern panes visibly emit light")
	UI.auto = false
	# A real local and their unchanged street; no preview-only NPC or camera.
	var near: Vector2i = villager["pos"] + Vector2i.DOWN
	main.world.spawn_at(near, Vector2i.UP)
	await main._wait(1.0)
	await _shot(opts, "arrival")
	if opts.get("preview", "") == "arrival":
		return
	# Start the conversation by tapping the actual NPC (or with the keyboard).
	if UI.is_touch():
		var node: Node3D = villager["node"]
		var screen: Vector2 = main.world.cam.unproject_position(node.position + Vector3(0, 0.8, 0)) * main.get_viewport().get_visible_rect().size / Vector2(main.view.size)
		await _touch(screen)
	else:
		await main._press("interact")
	await main._wait(0.25)
	_check(UI.stack.size() == 1, "one interaction opens the local's speech")
	if not UI.stack.is_empty():
		var dialog = UI.stack.back()
		_check(dialog.bubble_mode and dialog.speaker == villager["name"] and dialog._anchored, "context speech points to the local")
		dialog.text_label.visible_characters = -1
		await _shot(opts, "talk")
		if opts.get("preview", "") == "talk":
			return
		while not UI.stack.is_empty():
			await main._press("ui_accept")
			await main._wait(0.05)
	await main._wait(0.2)
	var sign_tile: Vector2i = main.world.map["signs"].keys()[0]
	main.world.spawn_at(sign_tile + Vector2i.DOWN, Vector2i.UP)
	await main._wait(0.6)
	var tile: Vector2i = main.world.player_pos
	for gem in ["ruby", "sapphire", "emerald", "hematite"]:
		UIKit.set_accent(gem)
		UI.root.theme = UIKit.make_theme()
		UI.controls.refresh()
		if UI.is_touch():
			await _touch(UI.controls.button_rect("a").get_center())
		else:
			await main._press("interact")
		await main._wait(0.15)
		var notice = UI.stack.back()
		_check(String(notice.lines[0]).begins_with("Gravenmoor."), "interacting with the real sign reads its written notice")
		if UIKit.touch_ui():
			_check(UI.is_touch() and UI.controls.touch_root.is_visible_in_tree() and UI.controls._buttons["a"].is_visible_in_tree(), "written notices retain visible touch controls")
		_check(not notice.bubble_mode and notice.bubble == null, gem + ": written notice uses the dark window")
		_check(notice.text_label.get_line_count() <= 3, "written notice keeps three readable lines per page")
		notice.text_label.visible_characters = -1
		await _shot(opts, "notice_" + gem)
		if opts.get("preview", "") == "notice":
			return
		if UI.is_touch():
			await _touch(UI.controls.button_rect("a").get_center())
		else:
			await main._press("ui_accept")
		await main._wait(0.2)
		_check(UI.stack.is_empty() and main.world.player_pos == tile, "one confirm dismisses the notice without moving")
	print("GRAVENMOOR DONE: %d problem(s)" % bad)


func _touch(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.position = point
		event.index = 0
		event.pressed = pressed
		main.get_viewport().push_input(event, true)
		await main.get_tree().process_frame


func _shot(opts: Dictionary, label: String) -> void:
	if not opts.has("shots") or DisplayServer.get_name() == "headless":
		return
	await main._wait(0.1)
	await main.get_tree().process_frame
	await RenderingServer.frame_post_draw
	main._save_shot(String(opts["shots"]) + "_" + label + ".png")


func _check(ok: bool, label: String) -> void:
	print("ok   " if ok else "FAIL ", label)
	if not ok:
		bad += 1
