extends RefCounted
## Fresh-state bubble placement and real input checks; --shots=res://build/shots/speech captures the matrix.
const UIKit = preload("res://scripts/ui/ui_kit.gd")
const VPer = preload("res://scripts/gfx/voxel_person.gd")
var main
var bad := 0
var answer := -1


func run(root, opts: Dictionary) -> void:
	main = root
	if opts.has("preview"):
		main.get_window().title = "Ruby Cocoon - Speech: " + String(opts["preview"])
	if DisplayServer.get_name() == "headless":
		main.get_window().size = Vector2i(2400, 1080) if UIKit.touch_ui() else Vector2i(1920, 1080)
		main._fit_view()
	UI.auto = true
	await main._go("caccoon", "start")
	UI.auto = false
	main.world.busy = true
	if opts.has("shots"):
		await main._wait(3.2)
	var elder: Dictionary = {}
	for npc in main.world.npcs.values():
		if npc.get("id", "") == "elder":
			elder = npc
	var node: Node3D = elder["node"]
	main.world.spawn_at(elder["pos"] + Vector2i(0, 2), Vector2i(0, -1))
	await main._wait(0.5)
	main.world.cam_free = true
	main.world.cam.global_position = node.global_position + main.world.CAM_OFFSET
	main.world.cam.look_at(node.global_position + Vector3(0, main.world.CAM_LOOK_Y, 0), Vector3.UP)
	var original_camera: Transform3D = main.world.cam.global_transform
	var original_position := node.global_position
	for sample in ["top", "bottom", "dpad"]:
		main.world.cam.global_transform = original_camera
		var target := Vector2(0.5, 0.10) if sample == "top" else Vector2(0.5, 0.88)
		if sample == "dpad":
			target = Vector2(0.12, 0.69)
		_frame_head(node, target)
		Story.say(["The road is full of stories. Take your time, and listen to the people you meet."], "Elder Rowan")
		await main._wait(0.15)
		var dialog = UI.stack.back()
		dialog.text_label.visible_characters = -1
		_check(dialog._anchored, sample + ": named world speech uses the NPC node")
		_check(dialog._below == (sample == "top"), sample + ": correct chevron edge")
		if sample in ["top", "bottom"]:
			_check(absf(dialog._tail[1].y - dialog._head_screen.y) >= dialog.HEAD_GAP - dialog.CHEVRON_H - 1.0, sample + ": pointer leaves breathing room around the face")
		_check_layout(dialog, sample)
		await _shot(opts, sample)
		if opts.get("preview", "") == sample:
			return
		var before: Rect2 = dialog._bubble_rect
		var anchor_before: Vector2 = dialog._head_screen
		VPer.set_talking(node, true)
		await main._wait(0.25)
		_check(dialog._bubble_rect == before, sample + ": idle/talking animation leaves the bubble still")
		VPer.set_talking(node, false)
		node.position.x += 0.5
		await main._wait(0.05)
		_check(dialog._head_screen.x != anchor_before.x, sample + ": real movement updates the projected anchor")
		node.global_position = original_position
		dialog.close()
	main.world.cam.global_transform = original_camera
	# Nine explicit lines must remain exactly three pages, including long/unbroken words.
	var nine := "A warm morning in Cocoon Cove.\nThe boats are ready at the docks.\nTake a friend along for the journey.\nThe road bends toward Bellerive.\nListen for birds among the trees.\nRest whenever your beasts grow tired.\nEvery town has a story to tell.\nKeep your flute close at hand.\nCome home and tell us what you find."
	UI.say([nine], "Elder Rowan", null, node)
	await main._wait(0.15)
	var dialog = UI.stack.back()
	_check(dialog.lines.size() == 3, "nine lines become exactly three pages")
	var player_tile: Vector2i = main.world.player_pos
	for page in 3:
		_check(dialog.idx == page and dialog.text_label.get_line_count() <= 3, "long speech page %d has at most three lines" % (page + 1))
		dialog.text_label.visible_characters = -1
		await _shot(opts, "long_%d" % (page + 1))
		if opts.get("preview", "") == "long_%d" % (page + 1):
			return
		if page == 0:
			await _click(dialog._bubble_rect.get_center())
		elif page == 1:
			await _joy(JOY_BUTTON_A)
		else:
			await main._press("ui_accept")
		await main._wait(0.06)
	_check(UI.stack.is_empty(), "mouse/tap, gamepad and keyboard each advance exactly one page")
	_check(main.world.player_pos == player_tile, "dialogue input never moves the hero")
	UI.say(["Reveal this sentence, then advance on a separate press."], "Elder Rowan", null, node)
	await main._wait(0.1)
	dialog = UI.stack.back()
	await main._press("ui_accept")
	_check(not dialog.closed and dialog.idx == 0 and dialog.text_label.visible_characters == -1, "one press reveals typing without dismissing the page")
	dialog.close()
	# Moving out of view, hiding or freeing the source must use stationary speech without a tail.
	UI.say(["A voice beyond the edge of the screen."], "Elder Rowan", null, node)
	await main._wait(0.1)
	dialog = UI.stack.back()
	node.position.x += 200.0
	await main._wait(0.05)
	_check(not dialog._anchored and dialog._tail.is_empty(), "off-screen voice falls back without a chevron")
	node.global_position = original_position
	node.hide()
	await main._wait(0.05)
	_check(not dialog._anchored, "hidden speaker falls back")
	node.show()
	dialog.close()
	var transient := Node3D.new()
	main.world.add_child(transient)
	transient.position = original_position
	UI.say(["An echo."], "Echo", null, transient)
	await main._wait(0.1)
	transient.queue_free()
	await main._wait(0.05)
	_check(not UI.stack.back()._anchored, "freed speaker safely falls back")
	UI.stack.back().close()
	for name in ["", "Dad", "Muffled Voice"]:
		UI.say(["You hear a familiar voice."], name)
		await main._wait(0.1)
		dialog = UI.stack.back()
		dialog.text_label.visible_characters = -1
		_check(not dialog._anchored and dialog._tail.is_empty(), "text/phone/off-screen voice stays stationary: " + name)
		_check(dialog.bubble_mode == (name != ""), "only named speech gets a white bubble: " + name)
		if name != "":
			_check_layout(dialog, "stationary")
		else:
			_check(dialog.bubble == null and dialog.text_label.get_theme_color("font_color") == UIKit.INK, "written text uses a dark window with white text")
		await _shot(opts, "stationary" if name == "" else name.to_lower().replace(" ", "_"))
		dialog.close()
	# Real indoor counter dialogue, followed by runtime palette changes on an already open bubble.
	UI.auto = true
	await main._go("caccoon#0", "entry")
	UI.auto = false
	main.world.busy = true
	if opts.has("shots"):
		await main._wait(3.2)
	Places.beast_center("caccoon")
	await main._wait(0.15)
	dialog = UI.stack.back()
	_check(dialog.speaker_node == main.world.speaker_node("Nurse Clover") and dialog._anchored, "Places passes the actual indoor keeper")
	for gem in UIKit.ACCENT_ORDER:
		UIKit.set_accent(gem)
		await main._wait(0.05)
		dialog.text_label.visible_characters = -1
		_check(dialog.name_panel.get_theme_stylebox("panel").bg_color == UIKit.ACCENT and dialog._name_label.get_theme_color("font_color") == UIKit.INK, "open name plate follows " + gem)
		_check_layout(dialog, "indoors " + gem)
		await _shot(opts, "indoors_" + gem)
		if opts.get("preview", "") == "indoors_" + gem:
			return
	# Close the keeper's introduction and the ensuing menu to complete its coroutine.
	for i in 12:
		if UI.stack.is_empty():
			break
		if UI.stack.back() is UI.DialogBox:
			UI.stack.back().text_label.visible_characters = -1
			await main._press("ui_accept")
		else:
			await main._press("ui_cancel")
		await main._wait(0.06)
	for accepted in [false, true]:
		_ask()
		await main._wait(0.35)
		dialog = UI.stack.back()
		_check(dialog._anchored, "Yes/No question is anchored to the keeper")
		_check_layout(dialog, "Yes/No")
		if UI.is_touch():
			_check(UI.controls._labels["a"].text == "A: Yes" and UI.controls.button_rect("a").size.x > UI.controls.ROUND, "Yes/No retains widened labelled touch buttons")
			await _shot(opts, "yes_no")
			await _touch(UI.controls.button_rect("a" if accepted else "b").get_center())
		else:
			await main._press("ui_accept" if accepted else "ui_cancel")
		await main._wait(0.1)
		_check(answer == (1 if accepted else 0) and UI.stack.is_empty(), "one direct A/B press answers exactly once")
	await main._wait(0.3)
	if UI.is_touch():
		_check(UI.controls.button_rect("a").size.x == UI.controls.ROUND, "touch buttons restore their normal shape")
	var film = load("res://scripts/ui/cinematic_dialog.gd").new()
	film.setup(["Cinematics keep their own presentation."], "Elder Rowan")
	UI.modal_layer.add_child(film)
	await main._wait(0.1)
	_check(not film.bubble_mode and film.bubble == null, "cinematic dialogue retains its dark window")
	film.queue_free()
	print("SPEECH DONE: %d problem(s)" % bad)
	if opts.get("quit", "1") == "0":
		Story.say(["Welcome to the Beast Center! Your beasts can rest here any time."], "Nurse Clover")
		await main._wait(0.2)
		UI.stack.back().text_label.visible_characters = -1


func _ask() -> void:
	answer = -1
	answer = 1 if await UI.ask("Shall I look after your beasts?", "Nurse Clover", "Yes", "No", main.world.speaker_node("Nurse Clover")) else 0


## Pan the unchanged gameplay camera to frame a real NPC at the requested part of the screen.
func _frame_head(node: Node3D, fraction: Vector2) -> void:
	var cam: Camera3D = main.world.cam
	var head := node.global_position + Vector3(0, 1.3, 0)
	var current := cam.unproject_position(head)
	var depth := -cam.to_local(head).z
	cam.global_position += cam.project_position(current, depth) - cam.project_position(Vector2(main.view.size) * fraction, depth)


func _check_layout(dialog, label: String) -> void:
	var safe := UIKit.safe_rect(dialog)
	var footprint: Rect2 = dialog._bubble_rect
	if dialog.name_panel != null:
		footprint = footprint.merge(dialog.name_panel.get_global_rect())
	_check(safe.encloses(footprint), label + ": bubble and name plate stay in the safe area")
	var pixels: Vector2 = dialog.bubble.position * dialog.get_viewport().get_screen_transform().get_scale()
	_check(pixels.is_equal_approx(pixels.round()), label + ": position snaps to whole screen pixels")
	if UI.is_touch():
		for group in UI.controls.CLUSTERS:
			var zone: Rect2 = UI.controls.cluster_zone(group, UI.controls.TOUCH_SLOP + UI.controls.NO_TAP_MARGIN)
			_check(not footprint.intersects(zone), label + ": clear of " + String(group[0]) + " touch cluster")
	_check(dialog.text_label.get_line_count() <= 3, label + ": at most three visible lines")


func _click(at: Vector2) -> void:
	if UI.is_touch():
		await _touch(at)
		return
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.pressed = pressed
		Input.parse_input_event(event)
		await main.get_tree().process_frame


func _touch(at: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.position = at
		event.pressed = pressed
		main.get_viewport().push_input(event, true)
		await main.get_tree().process_frame


func _joy(button: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await main.get_tree().process_frame


func _shot(opts: Dictionary, label: String) -> void:
	if opts.has("shots") and DisplayServer.get_name() != "headless":
		await main._wait(0.05)
		await RenderingServer.frame_post_draw
		main._save_shot(String(opts["shots"]) + "_" + label + ".png")


func _check(ok: bool, label: String) -> void:
	if not ok:
		bad += 1
	print("ok " if ok else "FAIL ", label)
