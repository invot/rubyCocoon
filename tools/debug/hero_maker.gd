extends RefCounted
## Exercise the real creator controls, not just its setters. No game or preferences are saved.
var bad := 0

func run(main, opts: Dictionary) -> void:
	if opts.has("shots"):
		DirAccess.make_dir_recursive_absolute(String(opts["shots"]))
	main._title()
	await main._wait(0.2)
	var menu = UI.stack.back()
	var index := 0
	for i in menu.items.size():
		if menu.items[i]["text"] == "New Game":
			index = i
	await main._tap_at(menu.buttons[index].get_global_rect().get_center())
	var deadline := Time.get_ticks_msec() + 15000
	while (UI.stack.is_empty() or UI.stack.back().get_script().resource_path != "res://scripts/ui/hero_maker.gd") and Time.get_ticks_msec() < deadline:
		await main.get_tree().process_frame
	_check(not UI.stack.is_empty(), "creator opens")
	if UI.stack.is_empty():
		return
	var maker = UI.stack.back()
	await main._wait(0.2)
	var skeleton = maker._rig.get_meta("skeleton")
	await main._press("ui_right")
	_check(maker.pick["name"] == 1 and maker._rig.get_meta("skeleton") == skeleton, "changing name keeps the preview skeleton")
	await main._press("ui_down")
	await main._press("ui_right")
	_check(maker.pick["body"] == 1, "keyboard changes body")
	# Each arrow is a real, directly tappable control. Outfit and hair must each change once.
	await main._tap_at(maker._arrows[3].get_global_rect().get_center())
	_check(maker.pick["outfit"] == 1, "outfit arrow responds to one tap")
	await main._tap_at(maker._arrows[5].get_global_rect().get_center())
	_check(maker.pick["hairdo"] == 5, "hairdo arrow responds to one tap")
	if opts.has("shots") and DisplayServer.get_name() != "headless":
		await main._wait(0.3)
		main._save_shot(String(opts["shots"]).path_join("creator-look.png"))
	await main._tap_at(maker._tabs[1].get_global_rect().get_center())
	_check(maker.tab == 1, "Colours tab responds to a tap")
	for id in ["pack", "skin", "top", "trousers", "hair", "eyes"]:
		await main.get_tree().process_frame
		await main.get_tree().process_frame
		var chips: Array = maker._chips[id]
		await main._tap_at(chips.back().get_global_rect().get_center())
		_check(maker.pick[id] == chips.size() - 1 and chips.back().scale.x > 1.0, id + " swatch updates selection")
	if opts.has("shots") and DisplayServer.get_name() != "headless":
		await main._wait(0.3)
		main._save_shot(String(opts["shots"]).path_join("creator-colours.png"))
	await main._press("ui_cancel")
	_check(not UI.stack.is_empty() and UI.stack.back().get_script() == UI.ListMenu, "B returns without starting or saving a game")
	print("HERO MAKER DONE: %d problem(s)" % bad)

func _check(ok: bool, label: String) -> void:
	if not ok:
		bad += 1
	print(("ok   " if ok else "FAIL ") + label)
