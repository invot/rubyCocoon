extends RefCounted
## Kenney input prompts preview: the title's keyboard strip at rest and with keys held, and (with --touch) the pad's
## d-pad with a way held. Holds only keys and actions the title menu ignores (Left, Shift, move_left).
## godot --path . --resolution 1920x1080 -- --scene=prompt-icons --prefs_path=res://build/prompt_test/settings.cfg --shots=res://build/shots/prompts/keys
## add --resolution 2400x1080 --touch for the pad ("PROMPT ICONS DONE: 0 problem(s)")
var bad := 0


func run(main) -> void:
	var opts: Dictionary = main._test
	if not UI.is_touch():
		Prefs.input_mode = "keyboard"
		Prefs.changed.emit()
	main._title()
	while UI.stack.is_empty():
		await main.get_tree().process_frame
	await main._wait(0.6)
	var c = UI.controls
	if UI.is_touch():
		_check(c.touch_visible(), "the touch pad shows on the title")
		await _shot(main, opts, "pad_rest")
		Input.action_press("move_left")
		await main._wait(0.2)
		_check(c._dpad_face.texture.resource_path.ends_with("xbox_dpad_left.svg"), "a held way lights its d-pad arm")
		await _shot(main, opts, "pad_left")
		Input.action_release("move_left")
		await main._wait(0.2)
		_check(c._dpad_face.texture.resource_path.ends_with("xbox_dpad.svg"), "letting go restores the plain d-pad")
	else:
		_check(c.legend_visible(), "the keyboard strip shows on the title")
		await _shot(main, opts, "keys_rest")
		for key in [KEY_LEFT, KEY_SHIFT]:
			_key(key, true)
		await main._wait(0.2)
		var lit := 0
		for e in c._legend_icons:
			if e["on"]:
				lit += 1
		_check(lit == 2, "held Left and Shift light their keys (%d lit)" % lit)
		await _shot(main, opts, "keys_held")
		for key in [KEY_LEFT, KEY_SHIFT]:
			_key(key, false)
		await main._wait(0.2)
		lit = 0
		for e in c._legend_icons:
			if e["on"]:
				lit += 1
		_check(lit == 0, "released keys return to their outline")
	print("PROMPT ICONS DONE: %d problem(s)" % bad)


func _key(code: Key, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)


func _shot(main, opts: Dictionary, name: String) -> void:
	if not opts.has("shots"):
		return
	await RenderingServer.frame_post_draw
	var dir := String(opts["shots"])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	main.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(dir.path_join(name + ".png")))


func _check(ok: bool, what: String) -> void:
	if not ok:
		bad += 1
	print(("ok   " if ok else "FAIL ") + what)
