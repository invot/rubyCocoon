extends RefCounted
## Fresh title startup: immediate choices, an idle world viewport, and one screen per confirmation.
var bad := 0

func run(main) -> void:
	_check(not UI.stack.is_empty(), "menu is ready without waiting for an entrance")
	_check(main.view.render_target_update_mode == SubViewport.UPDATE_DISABLED, "title does not render a 3D background")
	var deadline := Time.get_ticks_msec() + 15000
	while UI.stack.is_empty() and Time.get_ticks_msec() < deadline:
		await main.get_tree().process_frame
	_check(not UI.stack.is_empty(), "menu becomes ready without hanging")
	if UI.stack.is_empty():
		return
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
	_check(UI.stack.size() == 1, "the title tap does not confirm the character creator")
	_check(main.view.render_target_update_mode == SubViewport.UPDATE_DISABLED, "only the creator preview renders in 3D")
	await main._press("ui_cancel")
	await main._wait(0.3)
	_check(not UI.stack.is_empty() and UI.stack.back().get_script() == UI.ListMenu, "B returns to the title")
	print("TITLE STARTUP DONE: %d problem(s)" % bad)

func _check(ok: bool, label: String) -> void:
	if not ok:
		bad += 1
	print(("ok   " if ok else "FAIL ") + label)
