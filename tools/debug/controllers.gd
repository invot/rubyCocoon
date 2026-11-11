extends RefCounted
## Synthetic joypad events exercise the normal input path; USB/Bluetooth pairing needs real hardware.
const Layout = preload("res://scripts/core/controller_layout.gd")
var bad := 0
var main
var opts: Dictionary
const DEVICE := 7


func run(host, args: Dictionary) -> void:
	main = host
	opts = args
	if not Prefs.prefs_path().begins_with("res://build/"):
		_check(false, "use an isolated --prefs_path=res://build/.../settings.cfg")
		return
	Prefs.input_mode = ""
	if opts.get("verify", "1") == "0":
		await _preview()
		return
	for entry in [["Xbox Wireless Controller", "xbox-one"], ["Xbox Series X", "xbox-series-x"],
		["Xbox 360 Controller", "xbox-360"], ["DualSense Wireless Controller", "ps5"],
		["PS4 Controller", "ps4"], ["PLAYSTATION 3 Controller", "ps3"],
		["Nintendo Switch Pro Controller", "switch-pro"], ["Joy-Con (L/R)", "joy-cons"],
		["Wii U Pro Controller", "wii-u-pro"], ["Stadia Controller", "stadia"],
		["USB Gamepad", "xbox-one"], ["Unknown Pro Controller", "xbox-one"]]:
		_check(Layout.identify(entry[0]) == entry[1], "layout: " + entry[0])
	_check(Layout.identify("Wireless Controller", {"vendor_id": 0x054c}) == "ps4", "Sony vendor fallback")
	_check(Layout.describe("switch-pro").accept == "B" and Layout.describe("switch-pro").back == "A", "Nintendo letters match south/east bindings")
	Prefs.touch_controls = "auto"
	UI.controls.refresh()
	var had_touch: bool = UI.controls.touch_visible()
	if had_touch:
		var button: TouchScreenButton = UI.controls._buttons.right
		main._touch((button.position + Vector2.ONE * UI.controls.ARM / 2.0) * Vector2(main.get_window().size) / main.get_viewport().get_visible_rect().size, true)
		await main.get_tree().process_frame
	Input.joy_connection_changed.emit(2, true)
	Input.joy_connection_changed.emit(DEVICE, true)
	_axis(Vector2(0.8, 0.8))
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	_check(Controllers.active_device == DEVICE and Controllers.direction() == Vector2i(1, 1), "last used nonzero device steers diagonally")
	_check(not UI.controls.touch_visible(), "connected controller hides phone pad")
	_check(not Input.is_action_pressed("move_right"), "connecting releases a held screen direction")
	if had_touch:
		main._touch(Vector2.ZERO, false)
	_axis(Vector2.ZERO)
	UI.auto = true
	await main._do_goto("tidewater", "center")
	UI.auto = false
	await main._wait(0.3)
	var w = main.world
	var start := _open_patch(w)
	_check(start.x >= 0, "open ground found for eight-direction movement")
	if start.x < 0:
		return
	for d in [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
		Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]:
		w.player_pos = start
		w.player.position = w.tile_pos(start)
		_axis(Vector2(d) * 0.8)
		await main.get_tree().process_frame
		await main.get_tree().process_frame
		_axis(Vector2.ZERO)
		await _settle(w)
		_check(w.player_pos == start + d and w.player.position.is_equal_approx(w.tile_pos(w.player_pos)), "stick step lands on tile centre: " + str(d))
	_axis(Vector2(0.1, -0.1))
	_check(Controllers.direction() == Vector2i.ZERO, "radial deadzone rejects drift")
	_axis(Vector2.ZERO)
	w.frozen = true
	w.player_pos = start
	w.player.position = w.tile_pos(start)
	w._begin_step(start + Vector2i(1, 1), false)
	var diagonal_duration: float = w._move_length / w.move_speed
	w.moving = false
	w.player_pos = start
	w._begin_step(start + Vector2i.RIGHT, false)
	_check(is_equal_approx(diagonal_duration / (w._move_length / w.move_speed), sqrt(2.0)), "diagonals use the same ground speed")
	w.moving = false
	w.player_pos = start
	w.player.position = w.tile_pos(start)
	var side := start + Vector2i.RIGHT
	w.items[side] = {}
	_check(not w._can_step(start, start + Vector2i(1, 1)), "cannot cut a blocked corner")
	w.items.erase(side)
	w.stair_ways[side] = [start]
	_check(not w._can_step(start, start + Vector2i(1, 1)), "cannot cross a stair rail diagonally")
	w.stair_ways.erase(side)
	w.map.exits[side] = {}
	_check(not w._can_step(start, start + Vector2i(1, 1)), "cannot cut across exit approaches")
	w.map.exits.erase(side)
	Input.action_press("move_up")
	w._note_keys()
	_axis(Vector2(0.8, 0.8))
	_check(w._key_dir() == Vector2i.UP, "cardinal keys take priority over stick")
	Input.action_release("move_up")
	w._note_keys()
	_axis(Vector2.ZERO)
	_check(not UI.controls.controller_visible(), "gameplay keeps controller guide hidden")
	Controllers.layout = Layout.identify(String(opts.get("controller", "Xbox Wireless Controller")))
	Controllers.changed.emit()
	var book = main.loaded_script(Menus.BOOK_PATH).new().setup(w, "settings")
	UI.push(book)
	await main._wait(0.4)
	_check(UI.controls.controller_visible() and is_equal_approx(book.book.size.x, main.get_viewport().get_visible_rect().size.x - 48.0) and is_equal_approx(book._left_share(), 0.5), "book keeps full width and equal pages with the controller on its right page")
	var input_row := -1
	for i in book.rows.size():
		if book.rows[i].text == "Input":
			input_row = i
	_check(input_row >= 0, "Input choice is present in Settings")
	if Prefs.is_mobile():
		Prefs._keyboard_changed(false)
		_check(not "keyboard" in Prefs.available_inputs(), "phone without a keyboard omits Keyboard")
		Prefs._keyboard_changed(true)
		_check("keyboard" in Prefs.available_inputs(), "attached phone keyboard appears immediately")
		await main._wait(0.1)
	book.row_buttons[input_row].grab_focus()
	await main._wait(0.15)
	for i in Prefs.available_inputs().size() * 2:
		await main._press("ui_right")
		await main._wait(0.08)
		_check(book.focus_row == input_row and book.row_buttons[input_row].has_focus(), "cycling Input keeps focus on its row")
		_check(book.row_buttons[input_row].get_global_rect().intersection(book.list_scroll.get_global_rect()).size.y >= book.row_buttons[input_row].size.y - 1.0, "selected Input stays fully visible")
		_check(Prefs.effective_input() in Prefs.available_inputs(), "Input only cycles available devices")
		var guide = book.detail_box.get_child(book.detail_box.get_child_count() - 1)
		_check((guide.find_child("ControllerArt", true, false) != null) == (Prefs.effective_input() == "controller"), "controller artwork appears only for Controller input")
		_check(not UI.controls.legend_visible(), "book has no bottom key strip for any input")
	Prefs.set_value("input_mode", "controller")
	await main._wait(0.2)
	for i in [2, 3, 4, 5]:
		book.row_buttons[i].grab_focus()
		await main._wait(0.12)
		var scroll: int = book.list_scroll.scroll_vertical
		await main._press("ui_right")
		await main._wait(0.12)
		_check(book.focus_row == i and book.row_buttons[i].has_focus() and absi(book.list_scroll.scroll_vertical - scroll) <= 2, "setting change retains focus and scroll: " + str(i))
	var color_row := 5
	await main._tap_at(book.row_buttons[color_row].get_global_rect().get_center())
	await main._wait(0.15)
	_check(book.focus_row == color_row and book.row_buttons[color_row].has_focus(), "tapping a gem keeps focus after recolouring")
	Prefs.save_prefs()
	Prefs.input_mode = "keyboard"
	Prefs.load_prefs()
	_check(Prefs.input_mode == "controller", "preferred input survives settings reload")
	Prefs.set_value("input_mode", "controller")
	await main._wait(0.2)
	book.row_buttons[input_row].grab_focus()
	await main._wait(0.2)
	for gem in ["Ruby", "Sapphire", "Emerald", "Hematite"]:
		Prefs.accent = gem.to_lower()
		Prefs.changed.emit()
		await main._wait(0.25)
		await _shot("book_" + gem.to_lower())
	_pad(JOY_BUTTON_B, true)
	await main.get_tree().process_frame
	_pad(JOY_BUTTON_B, false)
	await main._wait(0.25)
	if not UI.stack.is_empty():
		await main._press("menu")
	await main._wait(0.3)
	_check(UI.stack.is_empty() and not UI.controls.controller_visible(), "closing book hides guide")
	Input.joy_connection_changed.emit(DEVICE, false)
	_check(Controllers.active_device == 2, "disconnect falls back to remaining pad")
	Input.joy_connection_changed.emit(2, false)
	_check(not "controller" in Prefs.available_inputs(), "unplugged controller disappears from Input options")
	_check(UI.controls.touch_visible() == had_touch, "last disconnect restores original touch mode")
	await _shot("disconnected")
	Input.joy_connection_changed.emit(DEVICE, true)
	Controllers.layout = Layout.identify(String(opts.get("controller", "Xbox Wireless Controller")))
	Controllers.changed.emit()
	GameState.save_game(0)
	main._title()
	while UI.stack.is_empty():
		await main.get_tree().process_frame
	await main._wait(0.3)
	var menu = UI.stack.back()
	_check(not UI.controls.controller_visible() and not UI.controls.legend_visible(), "title hides controller illustration and bottom strip")
	var before: int = menu._focus
	_axis(Vector2(0.0, 0.9))
	await main._wait(0.08)
	_axis(Vector2.ZERO)
	await main._wait(0.08)
	_check(menu._focus == posmod(before + 1, menu.buttons.size()), "one stick deflection moves one menu row")
	for i in menu.buttons.size():
		if menu.buttons[menu._focus].text == "New Game":
			break
		_pad(JOY_BUTTON_DPAD_DOWN, true)
		await main.get_tree().process_frame
		_pad(JOY_BUTTON_DPAD_DOWN, false)
	await _shot("title")
	_pad(JOY_BUTTON_A, true)
	await main._wait(0.25)
	_pad(JOY_BUTTON_A, false)
	await main._wait(0.35)
	_check(UI.stack.size() == 1 and UI.stack.back().get_script().resource_path.ends_with("hero_maker.gd"), "one controller confirmation opens creator once")
	_pad(JOY_BUTTON_B, true)
	await main.get_tree().process_frame
	_pad(JOY_BUTTON_B, false)
	await main._wait(0.3)
	_check(UI.stack.size() == 1 and UI.stack.back().get_script() == UI.ListMenu, "controller back returns to title")
	if opts.get("preview", "title") == "settings":
		# Leave a standalone book for real keyboard/mouse inspection without advancing the title coroutine.
		main._title_nodes[0].logo.visible = false
		var preview = main.loaded_script(Menus.BOOK_PATH).new().setup(null, "settings")
		UI.push(preview)
		await main._wait(0.3)
		for i in preview.rows.size():
			if preview.rows[i].text == "Input":
				preview.row_buttons[i].grab_focus()
	print("CONTROLLERS DONE: %d problem(s)" % bad)


func _preview() -> void:
	Input.joy_connection_changed.emit(DEVICE, true)
	Controllers.layout = Layout.identify(String(opts.get("controller", "Unknown Gamepad")))
	Controllers.changed.emit()
	Prefs.input_mode = "controller"
	Prefs.apply()
	UI.auto = true
	await main._do_goto("tidewater", "center")
	UI.auto = false
	main.world.frozen = true
	await main._wait(3.0)
	var book = main.loaded_script(Menus.BOOK_PATH).new().setup(main.world, "settings")
	UI.push(book)
	await main._wait(0.3)
	var input_row := 0
	for i in book.rows.size():
		if book.rows[i].text == "Input":
			input_row = i
	for gem in ["ruby", "sapphire", "emerald", "hematite"]:
		Prefs.accent = gem
		Prefs.apply()
		await main._wait(0.2)
		book.row_buttons[input_row].grab_focus()
		await main._wait(0.2)
		await _shot("book_" + gem)
	for mode in Prefs.available_inputs():
		Prefs.input_mode = mode
		Prefs.apply()
		await main._wait(0.2)
		book.row_buttons[input_row].grab_focus()
		await main._wait(0.2)
		await _shot("input_" + mode)
	Prefs.input_mode = "controller"
	Prefs.apply()
	await main._wait(0.2)
	book.close()
	await main._wait(0.3)
	await _shot("gameplay")
	main._title()
	while UI.stack.is_empty():
		await main.get_tree().process_frame
	await main._wait(0.4)
	await _shot("title")


func _open_patch(w) -> Vector2i:
	for y in range(3, int(w.map.h) - 3):
		for x in range(3, int(w.map.w) - 3):
			var p := Vector2i(x, y)
			var clear := true
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var q := p + Vector2i(dx, dy)
					if not w._walkable(q) or w.map.exits.has(q) or w.stair_ways.has(q) or not is_equal_approx(w._lift(q), w._lift(p)):
						clear = false
			if clear:
				return p
	return Vector2i(-1, -1)


func _axis(v: Vector2) -> void:
	for axis in [[JOY_AXIS_LEFT_X, v.x], [JOY_AXIS_LEFT_Y, v.y]]:
		var event := InputEventJoypadMotion.new()
		event.device = DEVICE
		event.axis = axis[0]
		event.axis_value = axis[1]
		Input.parse_input_event(event)


func _pad(button: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = DEVICE
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)


func _settle(w) -> void:
	for i in 120:
		await main.get_tree().process_frame
		if not w.moving:
			break


func _shot(name: String) -> void:
	if not opts.has("shots") or DisplayServer.get_name() == "headless":
		return
	await main._wait(0.2)
	DirAccess.make_dir_recursive_absolute(opts.shots)
	main._save_shot(String(opts.shots).path_join(name + ".png"))


func _check(ok: bool, what: String) -> void:
	if not ok:
		bad += 1
	print(("ok   " if ok else "FAIL ") + what)
