extends RefCounted
## Fresh title startup: the dragon enters before the menu; early presses cannot start a game.
var bad := 0

func run(main) -> void:
	await main._wait(0.4)
	_check(UI.stack.is_empty(), "menu waits for the dragon")
	await main._press("ui_accept")
	await main._wait(0.2)
	_check(UI.stack.is_empty(), "an entrance press cannot select New Game")
	var deadline := Time.get_ticks_msec() + 15000
	while UI.stack.is_empty() and Time.get_ticks_msec() < deadline:
		await main.get_tree().process_frame
	_check(not UI.stack.is_empty(), "menu becomes ready without hanging")
	if UI.stack.is_empty():
		return
	_check(main._title_nodes[0]._t >= 4.2, "dragon finishes rising before choices appear")
	await main._wait(0.3)
	var menu = UI.stack.back()
	if menu.buttons.size() > 1:
		await main._press("ui_down")
		_check(menu._focus == 1, "keyboard moves focus")
		await main._press("ui_up")
		_check(menu._focus == 0, "keyboard returns to New Game")
	await main._tap_at(menu.buttons[0].get_global_rect().get_center())
	await main._wait(0.3)
	_check(not UI.stack.is_empty() and UI.stack.back().get_script().resource_path == "res://scripts/ui/hero_maker.gd" and is_instance_valid(main._title_nodes[0]), "one tap opens the character creator once")
	await main._press("ui_cancel")
	await main._wait(0.3)
	_check(not UI.stack.is_empty() and UI.stack.back().get_script() == UI.ListMenu, "B returns to the title")
	print("TITLE STARTUP DONE: %d problem(s)" % bad)

func _check(ok: bool, label: String) -> void:
	if not ok:
		bad += 1
	print(("ok   " if ok else "FAIL ") + label)
