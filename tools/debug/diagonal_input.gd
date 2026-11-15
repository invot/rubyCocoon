extends RefCounted
## Routed keyboard/joypad/touch events and the public Settings preference.
const Book = preload("res://scripts/ui/book_menu.gd")
const UIKit = preload("res://scripts/ui/ui_kit.gd")
const DEVICE := 7
const KEYS := {"move_up": KEY_UP, "move_down": KEY_DOWN, "move_left": KEY_LEFT, "move_right": KEY_RIGHT, "run": KEY_S}
var main
var bad := 0
var checks := 0
var book


class KeepAwake extends Node:
	var previous := false
	func _exit_tree() -> void:
		DisplayServer.screen_set_keep_on(previous)


class LiveProbe extends Node:
	var world
	var last_tile: Vector2i
	func _process(_delta: float) -> void:
		if not is_instance_valid(world) or world.moving or world.player_pos == last_tile:
			return
		last_tile = world.player_pos
		print("LIVE INPUT STOP: tile=%s centred=%s diagonal=%s" % [last_tile,
			world.player.position.is_equal_approx(world.tile_pos(last_tile)), Prefs.diagonal_movement])


func run(host, opts: Dictionary) -> void:
	main = host
	if OS.has_feature("android"):
		var awake := KeepAwake.new()
		awake.previous = DisplayServer.screen_is_kept_on()
		main.add_child(awake)
		DisplayServer.screen_set_keep_on(true)
		print("DIAGONAL TEST KEEP AWAKE: ", DisplayServer.screen_is_kept_on())
	main.get_window().title = "Ruby Cocoon - 013 diagonal input"
	if DisplayServer.get_name() == "headless":
		main.get_window().size = Vector2i(2400, 1080) if Prefs.is_mobile() and opts.get("reference", "0") != "1" else Vector2i(1280, 720)
	if opts.get("verify", "1") == "1":
		_persistence()
	UI.auto = true
	await main._go("tidewater", "center")
	UI.auto = false
	var w = main.world
	w.frozen = true
	w.busy = true
	Prefs.render_height = 540
	Prefs.graphics_quality = "min"
	Prefs.diagonal_movement = false
	Prefs.apply()
	if opts.get("verify", "1") == "1":
		if opts.get("pad_only", "0") != "1":
			await _directions(w)
		if Prefs.is_mobile():
			await _touch_pad(w, String(opts.get("touch_shots", "")))
		if opts.get("pad_only", "0") == "1":
			print("DIAGONAL INPUT DONE: %d problem(s), %d checks" % [bad, checks])
			return
		await _settings(w)
	else:
		_open(w)
		await main._wait(0.3)
		_focus_diagonal()
	if opts.has("fade_shots"):
		await _fade_shots(w, String(opts.fade_shots))
	if opts.has("shots"):
		var path := String(opts.shots)
		DirAccess.make_dir_recursive_absolute(path)
		for gem in UIKit.ACCENT_ORDER:
			Prefs.accent = gem
			Prefs.apply()
			await main._wait(0.2)
			_focus_diagonal()
			await main._wait(0.2)
			await RenderingServer.frame_post_draw
			main._save_shot(path.path_join("settings_" + gem + ".png"))
		Prefs.accent = "ruby"
		Prefs.apply()
		_focus_diagonal()
	if opts.get("live", "0") == "1":
		# Leave the same isolated game and Settings row for OS-level key/click checks.
		var patch := _open_patch(w)
		if patch.x >= 0:
			w.player_pos = patch
			w.player.position = w.tile_pos(patch)
		var probe := LiveProbe.new()
		probe.world = w
		probe.last_tile = w.player_pos
		main.add_child(probe)
		print("LIVE INPUT START: tile=%s" % w.player_pos)
		await main._wait(0.3)
		var target: Vector2 = book.row_buttons[_row()].get_global_rect().get_center() * Vector2(main.get_window().size) / main.get_viewport().get_visible_rect().size
		print("LIVE INPUT ROW: ", JSON.stringify({"x": roundi(target.x), "y": roundi(target.y)}))
		w.busy = false
		w.frozen = false
		main._test["quit"] = "0"
	print("DIAGONAL INPUT DONE: %d problem(s), %d checks" % [bad, checks])


## Timed visual QA for active/idle controls; ordinary fixtures skip this.
func _fade_shots(w, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path)
	await main._wait(2.5)
	await _fade_shot(path, "book_idle")
	var right: Vector2 = UI.controls.button_rect("right").get_center()
	_touch(right, 3, true)
	await main._wait(0.15)
	await _fade_shot(path, "book_active")
	await main._wait(2.5)
	await _fade_shot(path, "book_held")
	_touch(right, 3, false)
	await _frame()
	await main._press("menu")
	await main._wait(0.3)
	await _fade_shot(path, "field_active")
	await main._wait(2.5)
	await _fade_shot(path, "field_idle")
	_touch(UI.controls.button_rect("right").get_center(), 3, true)
	await main._wait(2.5)
	await _fade_shot(path, "field_held")
	_touch(UI.controls.button_rect("right").get_center(), 3, false)
	await _frame()
	_check(not w.moving, "opacity preview touches do not leak through its frozen field")


func _fade_shot(path: String, state: String) -> void:
	await RenderingServer.frame_post_draw
	main._save_shot(path.path_join(state + ".png"))
	print("PAD FADE %s: alpha=%.2f right=%s" % [state, UI.controls.touch_root.modulate.a, Input.is_action_pressed("move_right")])


func _persistence() -> void:
	_check(Prefs.prefs_path().begins_with("res://build/") or Prefs.prefs_path().begins_with("user://bench/vo/"), "isolated preferences")
	var config := ConfigFile.new()
	config.set_value("audio", "music", 0.4)
	DirAccess.make_dir_recursive_absolute(Prefs.prefs_path().get_base_dir())
	config.save(Prefs.prefs_path())
	Prefs.diagonal_movement = true
	Prefs.load_prefs()
	_check(not Prefs.diagonal_movement and is_equal_approx(Prefs.music_volume, 0.4), "old settings default Off and preserve audio")
	Prefs.diagonal_movement = true
	Prefs.save_prefs()
	Prefs.diagonal_movement = false
	Prefs.load_prefs()
	_check(Prefs.diagonal_movement, "On survives save and reload")
	config.set_value("controls", "diagonal_movement", "invalid")
	config.save(Prefs.prefs_path())
	Prefs.load_prefs()
	_check(not Prefs.diagonal_movement, "invalid saved value defaults Off")


func _directions(w) -> void:
	for enabled in [false, true]:
		Prefs.diagonal_movement = enabled
		Prefs.apply()
		_check(w.diagonal_movement == enabled, "world follows runtime setting")
		for pair in [["move_up", "move_right", Vector2i(1, -1)], ["move_up", "move_left", Vector2i(-1, -1)],
			["move_down", "move_right", Vector2i.ONE], ["move_down", "move_left", Vector2i(-1, 1)]]:
			_key(pair[0], true)
			_key(pair[1], true)
			await _frame()
			w._note_keys()
			_check(_matches(w._key_dir(), pair[2], enabled), "two keyboard directions, option " + str(enabled))
			_key(pair[0], false)
			_key(pair[1], false)
			await _frame()
			w._note_keys()
		Input.joy_connection_changed.emit(DEVICE, true)
		_axis(Vector2(0.8, -0.8))
		await _frame()
		_check(_matches(w._key_dir(), Vector2i(1, -1), enabled), "stick respects option")
		_axis(Vector2(0.1, 0.1))
		await _frame()
		_check(w._key_dir() == Vector2i.ZERO, "stick deadzone remains")
		_axis(Vector2.ZERO)
		for button in [JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_DOWN]:
			_pad(button, true)
		await _frame()
		w._note_keys()
		_check(_matches(w._key_dir(), Vector2i.ONE, enabled), "physical d-pad respects option")
		for button in [JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_DOWN]:
			_pad(button, false)
		await _frame()
		w._note_keys()
		Input.joy_connection_changed.emit(DEVICE, false)
	Prefs.diagonal_movement = true
	_key("move_up", true)
	_key("move_down", true)
	await _frame()
	w._note_keys()
	_check(w._key_dir() == Vector2i.ZERO, "opposite keys cancel")
	_key("move_up", false)
	_key("move_down", false)
	await _frame()
	w._note_keys()
	# Exercise the actual input-to-step path, releasing midway through a diagonal.
	var start := _open_patch(w)
	_check(start.x >= 0, "open patch for routed keyboard step")
	if start.x >= 0:
		w.player_pos = start
		w.player.position = w.tile_pos(start)
		_key("run", true)
		_key("move_right", true)
		_key("move_down", true)
		await _frame()
		# Keep the field frozen until the raw events are available, then enter
		# its normal dispatcher once. Slow device frames must not start an
		# extra held-key step before this one-step fixture can release them.
		w._note_keys()
		w._read_input()
		_check(w.moving and w.move_speed > 7.0, "keyboard B/run plus diagonal starts a run")
		Prefs.diagonal_movement = false
		Prefs.apply()
		_key("move_right", false)
		_key("move_down", false)
		_key("run", false)
		await _frame()
		for i in 180:
			if not w.moving:
				break
			await main.get_tree().process_frame
		w.frozen = true
		w.busy = true
		_check(w.player_pos == start + Vector2i.ONE and w.player.position.is_equal_approx(w.tile_pos(w.player_pos)), "released diagonal completes its centred step after switching Off")


func _touch_pad(w, transition_shots := "") -> void:
	Prefs.input_mode = "screen"
	Prefs.touch_controls = "on"
	var controls = UI.controls
	for enabled in [false, true]:
		Prefs.diagonal_movement = enabled
		Prefs.apply()
		await _frame()
		var centre: Vector2 = controls._buttons.up.position + Vector2(controls.ARM / 2.0, controls.ARM * 1.5)
		for d: Vector2i in [Vector2i.ONE, Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var point: Vector2 = centre + Vector2(d) * controls.ARM
			_touch(point, 3, true)
			await _frame()
			w._note_keys()
			_check(_matches(w._key_dir(), d, enabled), "corner touch respects option: " + str(d))
			_check(controls.covers(point), "diagonal zone stays inside no-tap area")
			_touch(point, 3, false)
			await _frame()
			w._note_keys()
			_check(w._key_dir() == Vector2i.ZERO, "touch release clears both axes")
		if enabled:
			var right: Vector2 = controls.button_rect("right").get_center()
			var down: Vector2 = controls.button_rect("down").get_center()
			_touch(right, 3, true)
			await _frame()
			_drag(right, centre + Vector2.ONE * controls.ARM, 3)
			await _frame()
			w._note_keys()
			_check(w._key_dir() == Vector2i.ONE, "sliding a thumb enters the diagonal zone")
			_drag(centre + Vector2.ONE * controls.ARM, down, 3)
			await _frame()
			w._note_keys()
			_check(w._key_dir() == Vector2i.DOWN, "sliding out releases the other axis")
			_touch(down, 3, false)
			await _frame()
			var b: Vector2 = controls.button_rect("b").get_center()
			_touch(b, 4, true)
			_touch(centre + Vector2.ONE * controls.ARM, 3, true)
			await _frame()
			w._note_keys()
			_check(Input.is_action_pressed("run") and w._key_dir() == Vector2i.ONE, "B plus diagonal is multitouch")
			_touch(centre + Vector2.ONE * controls.ARM, 3, false)
			_touch(b, 4, false)
			await _frame()
	Prefs.diagonal_movement = true
	Prefs.apply()
	controls.set_flute_mode(true)
	await _frame()
	var left: Vector2 = controls.button_rect("left").get_center()
	var a: Vector2 = controls.button_rect("a").get_center()
	_touch(left, 3, true)
	_touch(a, 4, true)
	await _frame()
	_check(Input.is_action_pressed("flute_1") and Input.is_action_pressed("flute_3") and not Input.is_action_pressed("move_left"), "flute direction/button chord has no movement")
	_touch(left, 3, false)
	_touch(a, 4, false)
	await _frame()
	controls.set_flute_mode(false)
	await _frame()
	_check(not Input.is_action_pressed("flute_1") and not Input.is_action_pressed("flute_3"), "flute chord releases cleanly")
	await _touch_transitions(transition_shots)


func _touch_transitions(shots: String) -> void:
	var controls = UI.controls
	Prefs.diagonal_movement = false
	Prefs.apply()
	await _frame()
	var right: Vector2 = controls.button_rect("right").get_center()
	var up: Vector2 = controls.button_rect("up").get_center()
	var b: Vector2 = controls.button_rect("b").get_center()
	_touch(right, 3, true)
	_touch(up, 4, true)
	_touch(b, 5, true)
	await _frame()
	_check(Input.is_action_pressed("move_up") and Input.is_action_pressed("run"), "transition starts with multiple held fingers")
	if not shots.is_empty():
		DirAccess.make_dir_recursive_absolute(shots)
		await RenderingServer.frame_post_draw
		main._save_shot(shots.path_join("held.png"))
	# The real loading screen handles every raw event ahead of the pad. Reproduce
	# lifting all fingers while it owns input, then the transition cleanup.
	var loading = load("res://scripts/ui/loading_screen.gd").new()
	main.add_child(loading)
	_touch(right, 3, false)
	_touch(up, 4, false)
	_touch(b, 5, false)
	await _frame()
	_check(Input.is_action_pressed("move_up") and controls._buttons.up.is_pressed(), "loading screen reproduces a swallowed finger-up")
	loading.queue_free()
	controls.release_touch_inputs()
	await _frame()
	_check(not Input.is_action_pressed("move_up") and not Input.is_action_pressed("move_right") and not Input.is_action_pressed("run") and not Input.is_action_pressed("ui_up") and not Input.is_action_pressed("ui_cancel"), "transition clears swallowed releases and fallback arm")
	_check(not controls._buttons.up.is_pressed() and not controls._buttons.right.is_pressed() and not controls._buttons.b.is_pressed(), "transition clears native button fingers")
	if not shots.is_empty():
		await RenderingServer.frame_post_draw
		main._save_shot(shots.path_join("released.png"))
	_touch(right, 3, true)
	await _frame()
	_check(Input.is_action_pressed("move_right"), "same finger index presses normally after transition")
	main.get_window().focus_exited.emit()
	await _frame()
	_check(not Input.is_action_pressed("move_right") and not controls._buttons.right.is_pressed(), "focus loss clears native and synthetic movement")
	_touch(right, 3, false)
	_touch(right, 3, true)
	await _frame()
	_touch(right, 3, false)
	await _frame()
	_check(not Input.is_action_pressed("move_right"), "fresh press and release works after focus returns")


func _settings(w) -> void:
	Prefs.diagonal_movement = false
	Prefs.apply()
	_open(w)
	await main._wait(0.3)
	_focus_diagonal()
	await main._wait(0.2)
	var row := _row()
	_check(row >= 0, "Diagonal movement row is present")
	if row < 0:
		return
	var b: Button = book.row_buttons[row]
	_check(b.size.y >= UIKit.row_h() and b.get_theme_font_size("font_size") == 32, "row keeps standard target and 32-unit text")
	_check(b.get_global_rect().intersection(book.list_scroll.get_global_rect()).size.y >= b.size.y - 1.0, "focused setting scrolls fully into view")
	var at: Vector2i = w.player_pos
	var scroll_before: int = book.list_scroll.scroll_vertical
	await main._tap_at(b.get_global_rect().get_center())
	_check(Prefs.diagonal_movement and book.focus_row == row and UI.stack.size() == 1, "one row tap toggles once and keeps focus")
	_check(absi(book.list_scroll.scroll_vertical - scroll_before) <= 2, "toggling retains the row's scroll position")
	await main._press("ui_left")
	_check(not Prefs.diagonal_movement, "Left toggles Off")
	await main._press("ui_right")
	_check(Prefs.diagonal_movement, "Right toggles On")
	_check(w.player_pos == at and not w.moving, "settings input does not move the hero")
	if Prefs.is_mobile():
		_check(not UI.controls._pad_diagonal, "menus keep cardinal touch navigation")
	Prefs.save_prefs()
	Prefs.diagonal_movement = false
	Prefs.load_prefs()
	Prefs.apply()
	_check(Prefs.diagonal_movement, "setting survives menu save/reload")
	_focus_diagonal()


func _open(w) -> void:
	book = Book.new().setup(w, "settings")
	UI.push(book)


func _row() -> int:
	for i in book.rows.size():
		if book.rows[i].text == "Diagonal movement":
			return i
	return -1


func _focus_diagonal() -> void:
	var row := _row()
	if row >= 0:
		book.row_buttons[row].grab_focus()


func _open_patch(w) -> Vector2i:
	for y in range(3, int(w.map.h) - 3):
		for x in range(3, int(w.map.w) - 3):
			var p := Vector2i(x, y)
			if w._can_step(p, p + Vector2i.ONE):
				return p
	return Vector2i(-1, -1)


func _matches(d: Vector2i, diagonal: Vector2i, enabled: bool) -> bool:
	return d == diagonal if enabled else absi(d.x) + absi(d.y) == 1 and (d.x == diagonal.x or d.y == diagonal.y)


func _key(action: String, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEYS[action]
	ev.physical_keycode = KEYS[action]
	ev.pressed = down
	Input.parse_input_event(ev)


func _axis(v: Vector2) -> void:
	for pair in [[JOY_AXIS_LEFT_X, v.x], [JOY_AXIS_LEFT_Y, v.y]]:
		var ev := InputEventJoypadMotion.new()
		ev.device = DEVICE
		ev.axis = pair[0]
		ev.axis_value = pair[1]
		Input.parse_input_event(ev)


func _pad(button: int, down: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = DEVICE
	ev.button_index = button
	ev.pressed = down
	Input.parse_input_event(ev)


func _touch(at: Vector2, index: int, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = at * Vector2(main.get_window().size) / main.get_viewport().get_visible_rect().size
	ev.pressed = down
	Input.parse_input_event(ev)


func _drag(from: Vector2, to: Vector2, index: int) -> void:
	var ev := InputEventScreenDrag.new()
	var scale: Vector2 = Vector2(main.get_window().size) / main.get_viewport().get_visible_rect().size
	ev.index = index
	ev.position = to * scale
	ev.relative = (to - from) * scale
	Input.parse_input_event(ev)


func _frame() -> void:
	await main.get_tree().process_frame
	await main.get_tree().process_frame


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		bad += 1
	print("ok   " if ok else "FAIL ", what)
