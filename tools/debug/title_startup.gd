extends RefCounted
## Artwork title: crossfade/zoom, navigation, touch clusters and one screen per confirmation.
var bad := 0

func run(main) -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while UI.stack.is_empty() and Time.get_ticks_msec() < deadline:
		await main.get_tree().process_frame
	_check(not UI.stack.is_empty(), "slideshow title menu becomes ready")
	if UI.stack.is_empty():
		return
	await main._wait(0.3)
	var stage = main._title_nodes[0]
	_check(main.view.render_target_update_mode == SubViewport.UPDATE_DISABLED and not main.screen.visible, "title leaves the unused 3D viewport asleep")
	_check(not is_instance_valid(main._title_intro), "slideshow has no entrance blocking menu input")
	_check(stage.get_parent() == UI.root and stage.logo.is_visible_in_tree(), "slideshow and title remain behind the menu")
	_check(stage.logo.get_script() == stage.Plaque and stage.logo.get_rect().get_center().x > main.get_viewport().get_visible_rect().size.x * 0.45
		and stage.logo.get_rect().get_center().x < main.get_viewport().get_visible_rect().size.x * 0.55, "the game's name hangs on its stone plaque at the top centre")
	_check(not UI.top_bar.visible, "the shared top bar stays out of the title screen")
	_check(stage.slideshow.front.texture != null, "first artwork is loaded")
	var before_time: float = stage.slideshow.elapsed
	await main._wait(0.1)
	_check(stage.slideshow.elapsed > before_time, "slideshow zoom continues while the menu waits")
	# Verify an actual crossfade and wrap using the same production controller.
	var art = stage.slideshow
	while art.back.texture == null and Time.get_ticks_msec() < deadline:
		await main.get_tree().process_frame
	art.elapsed = art.HOLD + art.FADE * 0.5
	art._process(0.0)
	_check(art.back.modulate.a > 0.4 and art.back.modulate.a < 0.6, "artwork crossfades through half opacity")
	art.index = art.library().slides.size() - 1
	art.elapsed = art.HOLD + art.FADE
	art._process(0.0)
	_check(art.index == 0, "slideshow wraps to the first artwork")
	var menu = UI.stack.back()
	_check(menu.get_script() == UI.ListMenu and UI.stack.size() == 1, "slideshow keeps the New Game / Load Game menu")
	if main._test.get("fixture", "0") == "1":
		_check(menu.buttons.any(func(b): return b.text == "Load Game"), "Load Game remains available with a test save")
	if menu.buttons.size() > 1:
		var before: int = menu._focus
		await main._press("ui_down")
		_check(menu._focus == posmod(before + 1, menu.buttons.size()), "keyboard moves focus to the next choice")
		await main._press("ui_up")
		_check(menu._focus == before, "keyboard returns to the previous choice")
	if main._test.has("shot"):
		main._save_shot(String(main._test["shot"]))
	if UI.is_touch():
		# A tap on or just beside the d-pad belongs to the pad: it must not pick a menu row behind it.
		var pad_zone: Rect2 = UI.controls.cluster_zone(UI.controls.CLUSTERS[0], UI.controls.TOUCH_SLOP + UI.controls.NO_TAP_MARGIN)
		var spots: Array = [pad_zone.get_center(), Vector2(pad_zone.end.x - 6.0, pad_zone.get_center().y)]
		for button in menu.buttons:
			var overlap: Rect2 = button.get_global_rect().intersection(pad_zone)
			if overlap.has_area():
				spots.append(overlap.get_center())
		for spot in spots:
			await main._tap_at(spot)
			await main._wait(0.2)
			_check(UI.stack.size() == 1 and UI.stack.back() == menu, "a tap at %s near the d-pad picks no title choice" % spot)
		# A probe button lying under the d-pad and reaching past its zone: taps in the zone miss it, taps outside hit it.
		var probe := Button.new()
		var hits := [0]
		probe.pressed.connect(func(): hits[0] += 1)
		probe.position = pad_zone.position
		probe.size = Vector2(pad_zone.size.x + 160.0, pad_zone.size.y)
		UI.modal_layer.add_child(probe)
		await main._wait(0.05)
		await main._tap_at(pad_zone.get_center())
		await main._tap_at(Vector2(pad_zone.end.x - 6.0, pad_zone.get_center().y))
		_check(hits[0] == 0, "taps on and around the d-pad do not reach a button behind it")
		await main._tap_at(Vector2(pad_zone.end.x + 80.0, pad_zone.get_center().y))
		_check(hits[0] == 1, "the same button still takes a tap outside the d-pad's zone")
		probe.queue_free()
		await main._wait(0.05)
	for button in menu.buttons:
		if button.text == "New Game":
			await main._tap_at(button.get_global_rect().get_center())
			break
	# (the creator's script may still be loading on a busy machine: wait for it, then a little longer so a leaked
	# second confirmation would show)
	var creator_deadline := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < creator_deadline and not (not UI.stack.is_empty() and UI.stack.back().get_script().resource_path == "res://scripts/ui/hero_maker.gd"):
		await main.get_tree().process_frame
	await main._wait(0.3)
	_check(not UI.stack.is_empty() and UI.stack.back().get_script().resource_path == "res://scripts/ui/hero_maker.gd" and is_instance_valid(main._title_nodes[0]), "one tap opens the character creator once")
	_check(UI.stack.size() == 1, "the title tap does not confirm the character creator")
	_check(is_instance_valid(stage) and not stage.logo.visible, "creator hides only the title lettering, retaining the background")
	await main._press("ui_cancel")
	await main._wait(0.3)
	_check(not UI.stack.is_empty() and UI.stack.back().get_script() == UI.ListMenu, "B returns to the title")
	_check(is_instance_valid(stage) and stage.logo.is_visible_in_tree(), "returning restores the title lettering")
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
