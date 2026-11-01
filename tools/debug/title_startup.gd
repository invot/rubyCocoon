extends RefCounted
## Dragon entrance: natural completion, skip inputs, and one screen per confirmation.
var bad := 0

func run(main) -> void:
	_check(is_instance_valid(main._title_intro) and UI.stack.is_empty(), "dragon entrance precedes the menu")
	var mode: String = main._test.get("skip", "touch" if Prefs.is_mobile() else "key")
	if mode != "none":
		main._title_intro.freeze(1.8)
		await main._wait(0.1)
		var point: Vector2 = main.get_viewport().get_visible_rect().size * Vector2(0.5, 0.7)
		if mode == "touch-a":
			point = UI.controls._buttons["a"].position + Vector2(52, 52)
		Input.parse_input_event(_skip_event(mode, true, point, main))
		await main._wait(0.2)
		_check(UI.stack.size() == 1 and UI.stack.back().get_script() == UI.ListMenu, "skip opens only the title menu, even while held")
		if mode == "key":
			var echo := _skip_event(mode, true, point, main) as InputEventKey
			echo.echo = true
			Input.parse_input_event(echo)
			await main.get_tree().process_frame
			_check(UI.stack.size() == 1 and UI.stack.back().get_script() == UI.ListMenu, "held A does not confirm the new menu")
		Input.parse_input_event(_skip_event(mode, false, point, main))
	var deadline := Time.get_ticks_msec() + 15000
	while UI.stack.is_empty() and Time.get_ticks_msec() < deadline:
		await main.get_tree().process_frame
	_check(not UI.stack.is_empty(), "menu becomes ready without hanging")
	if UI.stack.is_empty():
		return
	await main._wait(0.3)
	_check(not main._title_skip_held, "skip input is released before the next confirmation")
	_check(main.view.render_target_update_mode == SubViewport.UPDATE_DISABLED, "menu does not render a 3D background")
	_check(not is_instance_valid(main._title_intro), "dragon entrance is put away")
	var menu = UI.stack.back()
	_check(menu.get_script() == UI.ListMenu and UI.stack.size() == 1, "entrance ends at the New Game / Load Game menu")
	if main._test.get("fixture", "0") == "1":
		_check(menu.buttons.any(func(b): return b.text == "Load Game"), "Load Game remains available with a test save")
	if menu.buttons.size() > 1:
		await main._press("ui_down")
		_check(menu._focus == 1, "keyboard moves focus")
		await main._press("ui_up")
		_check(menu._focus == 0, "keyboard returns to the first choice")
	if main._test.has("shot"):
		main._save_shot(String(main._test["shot"]))
	for button in menu.buttons:
		if button.text == "New Game":
			await main._tap_at(button.get_global_rect().get_center())
			break
	await main._wait(0.3)
	_check(not UI.stack.is_empty() and UI.stack.back().get_script().resource_path == "res://scripts/ui/hero_maker.gd" and is_instance_valid(main._title_nodes[0]), "one tap opens the character creator once")
	_check(UI.stack.size() == 1, "the title tap does not confirm the character creator")
	_check(main.view.render_target_update_mode == SubViewport.UPDATE_DISABLED, "only the creator preview renders in 3D")
	await main._press("ui_cancel")
	await main._wait(0.3)
	_check(not UI.stack.is_empty() and UI.stack.back().get_script() == UI.ListMenu, "B returns to the title")
	print("TITLE STARTUP DONE: %d problem(s)" % bad)


func _skip_event(mode: String, down: bool, point: Vector2, main) -> InputEvent:
	if mode == "key":
		var key := InputEventKey.new()
		key.physical_keycode = KEY_A
		key.pressed = down
		return key
	if mode == "gamepad":
		var pad := InputEventJoypadButton.new()
		pad.button_index = JOY_BUTTON_A
		pad.pressed = down
		return pad
	# Input.parse_input_event uses window pixels; menu and pad coordinates use logical UI units.
	point *= Vector2(main.get_window().size) / main.get_viewport().get_visible_rect().size
	if mode == "mouse":
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.position = point
		mouse.pressed = down
		return mouse
	var touch := InputEventScreenTouch.new()
	touch.position = point
	touch.pressed = down
	return touch

func _check(ok: bool, label: String) -> void:
	if not ok:
		bad += 1
	print(("ok   " if ok else "FAIL ") + label)
