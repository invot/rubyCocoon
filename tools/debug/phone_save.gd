extends RefCounted
## Exercises Dad's real prompts, save card and title handoff with isolated saves.

var bad := 0
var main


func check(ok: bool, message: String) -> void:
	if not ok:
		bad += 1
		print("FAIL ", message)


func answer(yes: bool) -> void:
	if UI.is_touch():
		var button: TouchScreenButton = UI.controls._buttons["a" if yes else "b"]
		var at := button.get_global_transform_with_canvas() * (button.texture_normal.get_size() / 2.0)
		at *= Vector2(main.get_window().size) / main.get_viewport().get_visible_rect().size
		for down in [true, false]:
			var ev := InputEventScreenTouch.new()
			ev.index = 0
			ev.position = at
			ev.pressed = down
			Input.parse_input_event(ev)
			await main.get_tree().process_frame
	else:
		await main._press("ui_accept" if yes else "ui_cancel")
	await main._wait(0.4)


func shot(suffix: String) -> void:
	if main._test.has("shot") and DisplayServer.get_name() != "headless":
		main._save_shot(String(main._test["shot"]).replace(".png", suffix + ".png"))


func run(game) -> void:
	main = game
	check(GameState.save_dir().begins_with("res://build/"), "test saves must be isolated")
	if bad > 0:
		return
	for i in GameState.SLOT_COUNT:
		GameState.delete_slot(i)
	GameState.current_slot = -1
	var start: Vector2i = main.world.player_pos
	main.Phone._save()
	await main._wait(0.6)
	check(UI.stack.back() is UI.ConfirmPrompt, "save needs an explicit Yes/No answer")
	check(GameState.current_slot == -1, "nothing saved before consent")
	shot("_save")
	await answer(false)
	check(GameState.current_slot == -1, "No creates no save")
	check(UI.stack.back() is UI.ConfirmPrompt and UI.stack.back().lines[0] == "Do you want to continue playing?", "continue asked after declining save")
	await answer(true)
	check(UI.stack.is_empty(), "Yes to continue returns to play")
	main.Phone._save()
	await main._wait(0.6)
	await answer(true)
	check(GameState.current_slot >= 0 and GameState.has_save(), "Yes writes the journey")
	check(UI.stack.back() is UI.SaveCard, "one Yes stops on the saved card")
	await answer(true)
	check(UI.stack.back() is UI.ConfirmPrompt and UI.stack.back().lines[0] == "Do you want to continue playing?", "dismissing card stops on continue prompt")
	shot("_continue")
	await answer(true)
	check(UI.stack.is_empty(), "continue after save closes the call")
	var before := FileAccess.get_file_as_bytes(GameState.slot_path(GameState.current_slot))
	main.Phone._save()
	await main._wait(0.6)
	await answer(false)
	check(FileAccess.get_file_as_bytes(GameState.slot_path(GameState.current_slot)) == before, "No preserves existing save bytes")
	check(main.world.player_pos == start, "answers do not move the player")
	await answer(false)
	# Dismiss Dad's goodbye, including the typewriter reveal.
	for i in 2:
		await answer(true)
	await main._wait(1.0)
	check(not main._title_nodes.is_empty(), "No to continue returns to title")
	print("PHONE SAVE DONE: %d problem(s)" % bad)
