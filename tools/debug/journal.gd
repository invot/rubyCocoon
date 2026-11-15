extends RefCounted
## Bedroom gate, acquisition, all tabs, skip controls, and isolated save compatibility.
const ML = preload("res://scripts/world/map_loader.gd")
var bad := 0

func check(ok: bool, text: String) -> void:
	if not ok:
		bad += 1
		print("FAIL ", text)

func shot(main, opts: Dictionary, name: String) -> void:
	if not opts.has("shots") or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(String(opts["shots"]))
	await main._wait(0.3)
	await RenderingServer.frame_post_draw
	main._save_shot(String(opts["shots"]) + "/" + name + ".png")

func run(main, opts: Dictionary) -> void:
	UI.auto = true
	GameState.set_flag("woke_up")
	var bedroom := ML.wake_room(ML.interior_of("caccoon", "home"))
	GameState.set_flag("has_journal")
	await main._go(bedroom, Vector2i(8, 3))
	await shot(main, opts, "before")
	GameState.set_flag("has_journal", false)
	await main._go(bedroom, Vector2i(8, 3))
	var w = main.world
	w.frozen = true
	w.facing = Vector2i.RIGHT
	check(w.npcs.has(Vector2i(9, 3)), "journal is on the floor directly in front of the only door")
	check(not w._walkable(Vector2i(9, 3)), "journal blocks the doorway approach")
	check(w.npcs[Vector2i(9, 3)]["story_mark"].visible, "journal has a yellow story crystal")
	await w._open_menu()
	check(UI.stack.is_empty(), "Start points to the journal before collection")
	check(GameState.save_game(0), "save before collecting")
	GameState.set_flag("has_journal")
	check(GameState.load_game(0) and not GameState.flag("has_journal"), "uncollected journal survives reload")
	await shot(main, opts, "bedroom")
	UI.auto = false
	w._interact()
	await main._wait(0.35)
	check(GameState.flag("has_journal") and not w.npcs.has(Vector2i(9, 3)), "pickup removes the blocker")
	var book = UI.stack.back()
	check(book.journal_tour and book.tab == 0, "pickup opens the journal on the first tab exactly once")
	await main._tap_at(book.markers[6].get_global_rect().get_center())
	check(book.tab == 0, "taps cannot activate menu tabs behind the tooltip")
	await shot(main, opts, "tour")
	for i in book.TABS.size():
		check(book.journal_tour and book.tab == i, "tour explains tab %d in order" % i)
		check(book.left_box.get_child_count() > 0 and is_instance_valid(book._tour_tip), "real page is shown beneath its tooltip")
		for prompt in ["TourA", "TourB"]:
			var icon = book._tour_tip.find_child(prompt, true, false)
			check(icon is TextureRect and icon.texture != null and icon.self_modulate != Color.WHITE,
				"tutorial HUD uses the flute game's coloured circular %s prompt" % prompt)
		if i == 1:
			check(is_instance_valid(book.beasts_page), "tour uses the actual Beasts page")
		if i == 3:
			check(is_instance_valid(book.bag), "tour uses the actual Bag page")
		await shot(main, opts, "tab_%d" % i)
		await main._wait(0.22)
		if UI.is_touch():
			var target: Vector2 = UI.controls._buttons["a"].global_position + Vector2.ONE * UI.controls.ROUND / 2.0
			for down in [true, false]:
				var ev := InputEventScreenTouch.new()
				ev.position = target * Vector2(main.get_window().size) / main.get_viewport().get_visible_rect().size
				ev.pressed = down
				Input.parse_input_event(ev)
				await main.get_tree().process_frame
		else:
			await main._press("ui_accept")
		await main._wait(0.03)
	check(not book.journal_tour and book.tab == 0, "tour ends in the usable journal")
	book.close()
	await main._wait(0.2)
	check(w._walkable(Vector2i(9, 3)), "the bedroom door is accessible after pickup")
	for skip in ["keyboard", "controller", "touch"]:
		Menus.pause_menu(w, "trainer", true)
		await main._wait(0.3)
		book = UI.stack.back()
		await main._press("ui_cancel")
		await main._wait(0.1)
		check(book.journal_tour and book.tab == 0, "tapping B does not skip or advance")
		await main._press("menu")
		check(book.journal_tour, "Start does not skip the tooltip tour")
		var event: InputEvent
		if skip == "touch" and UI.is_touch():
			var ev := InputEventScreenTouch.new()
			ev.index = 0
			var target: Vector2 = UI.controls._buttons["b"].global_position + Vector2.ONE * UI.controls.ROUND / 2.0
			ev.position = target * Vector2(main.get_window().size) / main.get_viewport().get_visible_rect().size
			ev.pressed = true
			event = ev
		elif skip == "controller":
			var ev := InputEventJoypadButton.new()
			ev.button_index = JOY_BUTTON_B
			ev.pressed = true
			event = ev
		else:
			var ev := InputEventKey.new()
			ev.physical_keycode = KEY_ESCAPE
			ev.pressed = true
			event = ev
		Input.parse_input_event(event)
		await main._wait(0.3)
		check(book.journal_tour and book._tour_hold > 0.0, "short hold shows progress without skipping")
		await main._wait(0.65)
		event.set("pressed", false)
		Input.parse_input_event(event)
		await main._wait(0.1)
		check(not book.journal_tour and UI.stack.size() == 1, "%s skips the tour without closing or activating another page" % skip)
		book.close()
		await main._wait(0.2)
	check(GameState.save_game(0), "save collected journal")
	GameState.set_flag("has_journal", false)
	check(GameState.load_game(0) and GameState.flag("has_journal"), "journal ownership survives reload")
	GameState.flags.erase("has_journal")
	check(GameState.save_game(0) and GameState.load_game(0) and GameState.flag("has_journal"), "older saves keep their journal access")
	UI.auto = true
	await main._go(bedroom, Vector2i(8, 3))
	check(not main.world.npcs.has(Vector2i(9, 3)), "journal stays collected on later visits")
	print("JOURNAL DONE: %d problem(s)" % bad)
