extends RefCounted
## Fresh-state mobile menu interaction checks and previews: --scene=mobile-menus --touch --verify=1
## --preview=confirm|list|book|title; --shots=res://build/shots/mobile_menu captures representative states.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
var main
var bad := 0
var answer := -1
var choice := -1


func run(root, opts: Dictionary) -> void:
	main = root
	UI.auto = true
	await main._go("caccoon#0", "entry")
	UI.auto = false
	if opts.get("verify", "0") == "1":
		if UIKit.touch_ui():
			await _verify(opts)
		else:
			await _verify_desktop()
		print("MOBILE MENUS DONE: %d problem(s)" % bad)
	match opts.get("preview", "confirm"):
		"list":
			await _center_menu()
		"book":
			Menus.pause_menu(main.world, "beasts")
		"title":
			main._title()
		_:
			_ask()
	await main._wait(0.4)


func _ask(question := "Put your beasts in the healing chamber?") -> void:
	answer = -1
	answer = 1 if await UI.ask(question, "Beast Center") else 0


func _verify_desktop() -> void:
	_ask("Read the whole question before deciding. ".repeat(16))
	await main._wait(0.15)
	var prompt = UI.stack.back()
	_check(prompt.lines.size() > 1 and prompt._yes_button.text == "A: Next", "long desktop question offers Next before Yes")
	prompt._yes_button.pressed.emit()
	_check(prompt.idx == 1 and answer == -1, "desktop Next advances exactly one question page")
	while prompt.idx < prompt.lines.size() - 1:
		await main._press("ui_accept")
	await main._wait(0.05)
	_check(prompt._yes_button.text == "A: Yes", "last desktop question page offers Yes")
	prompt._yes_button.pressed.emit()
	_check(answer == 1 and UI.stack.is_empty(), "desktop Yes answers directly")
	_ask()
	await main._wait(0.1)
	await main._press("ui_cancel")
	_check(answer == 0, "desktop B or Escape answers No directly")


func _center_menu() -> void:
	Places.beast_center("caccoon")
	await main._wait(0.15)
	for i in 10:
		if UI.stack.is_empty() or not UI.stack.back() is UI.DialogBox:
			return
		UI.stack.back().text_label.visible_characters = -1
		await main._press("ui_accept")
		await main._wait(0.06)


func _long_menu() -> void:
	var items := []
	for i in 18:
		items.append({"text": "Choice %d" % (i + 1), "desc": "Scroll with Up/Down or tap any visible choice."})
	choice = await UI.choose("Choose a beast", items, {"anchor": "right", "width": 400})


func _verify(opts: Dictionary) -> void:
	var original_pos: Vector2i = main.world.player_pos
	_ask()
	await main._wait(0.08)
	var middle_width: float = UI.controls.button_rect("a").size.x
	_check(middle_width > UI.controls.ROUND and middle_width < 240.0, "answer buttons animate through an intermediate width")
	await main._wait(0.3)
	var prompt = UI.stack.back()
	_check(prompt is UI.ConfirmPrompt and UI.stack.size() == 1, "question and direct answers share one prompt")
	_check(UI.controls._labels["a"].text == "A: Yes" and UI.controls._labels["b"].text == "B: No", "pad labels show A: Yes and B: No")
	_check(not UI.controls.button_rect("a").grow(UI.controls.TOUCH_SLOP).intersects(UI.controls.button_rect("b").grow(UI.controls.TOUCH_SLOP)), "wide A/B hit areas stay separate")
	await _shot(opts, "yes_no")
	await _tap(prompt.text_label.get_global_rect().get_center())
	_check(answer == -1 and UI.stack.back() == prompt, "tapping question text cannot accept it")
	# Hit the newly widened part, outside the original round button.
	await _tap(UI.controls.button_rect("b").position + Vector2(26, 52))
	await main._wait(0.15)
	_check(answer == 0 and UI.stack.is_empty(), "one tap on widened B answers No")
	_ask()
	await main._wait(0.3)
	await _tap(UI.controls.button_rect("a").position + Vector2(26, 52))
	await main._wait(0.15)
	_check(answer == 1 and UI.stack.is_empty(), "one tap on widened A answers Yes")
	_ask()
	await main._wait(0.1)
	await main._press("ui_cancel")
	_check(answer == 0, "keyboard/controller cancel maps directly to No")
	_ask()
	await main._wait(0.1)
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_A
		event.pressed = pressed
		Input.parse_input_event(event)
		await main.get_tree().process_frame
	_check(answer == 1, "gamepad A maps directly to Yes")
	await main._wait(0.3)
	_check(UI.controls.button_rect("a").size.x == UI.controls.ROUND and UI.controls._labels["a"].text == "A", "normal button shapes and labels return after the prompt")
	await _center_menu()
	await main._wait(0.2)
	var menu = UI.stack.back()
	_check(menu is UI.ListMenu and menu.title == "Beast Center", "real Beast Center choices open")
	_check(menu._scroll.size.y >= UIKit.row_h() * 3.0, "several full-size choices fit at once")
	_check(absf(menu._outer.get_global_rect().get_center().x - main.get_viewport().get_visible_rect().size.x / 2.0) < 2.0, "mobile choices sit in the center")
	_check(not menu._pager.visible, "ordinary mobile lists have no paging footer")
	await _shot(opts, "choices")
	await main._press("ui_cancel")
	await main._wait(0.15)
	_long_menu()
	await main._wait(0.2)
	menu = UI.stack.back()
	for i in 7:
		await _tap(UI.controls.button_rect("down").get_center())
	await main._wait(0.15)
	_check(menu._focus == 7 and menu._scroll.scroll_vertical > 0, "d-pad Down scrolls the selection into view")
	await _tap(UI.controls.button_rect("up").get_center())
	await main._wait(0.1)
	_check(menu._focus == 6, "d-pad Up moves back one choice")
	await _tap(menu.buttons[6].get_global_rect().intersection(menu._scroll.get_global_rect()).get_center())
	await main._wait(0.1)
	_check(choice == 6 and UI.stack.is_empty(), "one direct tap selects the visible option")
	Menus.pause_menu(main.world, "beasts")
	await main._wait(0.5)
	var book = UI.stack.back()
	for id in ["up", "down", "left", "right", "a", "b", "start", "pause"]:
		_check(UI.controls._buttons[id].visible and UI.controls._buttons[id].process_mode != Node.PROCESS_MODE_DISABLED, "Start book keeps %s usable" % id)
	await _shot(opts, "book")
	await _tap(UI.controls.button_rect("down").get_center())
	await main._wait(0.1)
	_check(book.focus_row == 1, "book rows respond to the retained d-pad")
	await _tap(UI.controls.button_rect("start").get_center())
	await main._wait(0.15)
	_check(UI.stack.is_empty(), "Start closes the book once")
	_check(main.world.player_pos == original_pos, "all menu inputs leave the world player in place")


func _tap(at: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.position = at
		event.pressed = pressed
		main.get_viewport().push_input(event, true)
		await main.get_tree().process_frame


func _shot(opts: Dictionary, name: String) -> void:
	if opts.has("shots"):
		await main.get_tree().process_frame
		main._save_shot(String(opts["shots"]) + "_" + name + ".png")


func _check(ok: bool, label: String) -> void:
	if not ok:
		bad += 1
	print("ok " if ok else "FAIL ", label)
