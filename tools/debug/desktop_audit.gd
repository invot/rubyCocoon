extends RefCounted
## Recheck the actual Rowan and Pip flows, visible desktop actions and immediate pickups.
const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Beasts = preload("res://scripts/core/beasts.gd")
const TopBar = preload("res://scripts/ui/top_bar.gd")
var main
var opts: Dictionary
var bad := 0
var elder_done := false
var kennel_done := false

func run(host, options: Dictionary) -> void:
	main = host
	opts = options
	UI.auto = true
	for flag in ["intro_done", "tutorial_done", "ritual_done", "opening_seen", "called_dad", "has_starter"]:
		GameState.set_flag(flag)
	GameState.party = [Beasts.create(0, 10)]
	GameState.gold = 300
	await main._go("caccoon", "start")
	main.world.frozen = true
	var elder: Dictionary = main._npc("elder")
	main.world.spawn_at(elder["pos"] + Vector2i.DOWN * 2)
	await main._wait(0.3)
	var speed: float = Prefs.text_speed
	Prefs.text_speed = 0
	UI.auto = false
	GameState.flags.erase("got_egg")
	_elder()
	var menu = await _menu("Choose your egg")
	if menu != null:
		_check_actions(menu, false)
		await _shot("egg-selection")
		await _select(menu)
		await main._wait(0.15)
		var prompt = UI.stack.back()
		_check(prompt is UI.ConfirmPrompt and prompt.speaker == "Elder Rowan", "egg selection opens Rowan's spoken confirmation")
		await _shot("egg-confirmation")
		await main._press("ui_cancel")
		if not UIKit.touch_ui():
			_check(prompt._answering and prompt._buttons[0].modulate.a == 0, "egg No hides Yes during reply feedback")
		await main._wait(0.45)
		menu = await _menu("Choose your egg")
		_check(menu != null, "No returns to egg selection without leaking the press")
		if menu != null:
			UI.auto = true
			UI.auto_answers = [0]
			menu._pick(0)
			for i in 60:
				if elder_done:
					break
				await main.get_tree().process_frame
	_check(elder_done and GameState.flag("got_egg"), "real egg gift flow completes")
	UI.auto = true
	await main._go("caccoon#0", "entry")
	main.world.frozen = true
	UI.auto = false
	var gem: String = UIKit.accent_name
	UIKit.set_accent("hematite")
	var gold: int = GameState.gold
	_kennel()
	menu = await _menu("Kennel")
	if menu != null:
		menu.buttons[0].grab_focus()
		await _select(menu)
		menu = await _menu("Adopt which beast?")
		if menu != null:
			_check_actions(menu, true)
			for row in menu.buttons:
				for child in row.get_children():
					if child is Label:
						_check(child.get_theme_color("font_color") == UIKit.GOLD and UIKit.GOLD.get_luminance() > 0.5, "adoption prices use the lighter Hematite text color")
			await _shot("adoption-hematite")
			await _select(menu)
			await main._wait(0.15)
			_check(UI.stack.back() is UI.BeastView, "adoption opens the beast summary before confirming")
			await main._press("ui_accept")
			await main._wait(0.15)
			_check(UI.stack.back() is UI.ConfirmPrompt and UI.stack.back().speaker == "Kennel Keeper Pip", "adoption confirmation uses Pip's reply bubbles")
			await _shot("adoption-confirmation")
			await main._press("ui_cancel")
			await main._wait(0.45)
			menu = await _menu("Kennel")
			if menu != null:
				await _back(menu)
	_check(kennel_done and GameState.gold == gold, "Back exits the kennel and declining adoption spends nothing")
	UIKit.set_accent(gem)
	Prefs.text_speed = speed
	var empty = UI.ListMenu.new().setup("Empty list", [])
	UI.push(empty)
	await main._wait(0.1)
	if not UIKit.touch_ui():
		_check(empty._select_button.disabled and not empty._back_button.disabled, "empty choice list disables Select and keeps Back")
	await _back(empty)
	var bar := TopBar.new()
	UI.root.add_child(bar)
	bar.post("Arrived", null, {"key": "place"})
	bar.post("First item", null, {"key": "item:first", "priority": true})
	_check(bar.current_text() == "First item" and bar._slide == 1.0, "pickup is fully shown immediately")
	bar.post("Second item", null, {"key": "item:second", "priority": true})
	_check(bar.current_text() == "Second item" and bar._slide == 1.0, "a different pickup interrupts the previous pickup immediately")
	bar.post("First item", null, {"key": "item:first", "priority": true, "count": 3})
	_check(bar.current_text() == "First item x4" and bar.pending() == 2, "queued matching pickup merges and shows immediately without duplicate notices")
	bar.queue_free()
	print("DESKTOP AUDIT DONE: %d problem(s)" % bad)

func _elder() -> void:
	await Story._elder(main.world, {})
	elder_done = true

func _kennel() -> void:
	await Places.kennel(main.world, "caccoon")
	kennel_done = true

func _menu(prefix: String):
	for i in 80:
		await main._wait(0.03)
		if UI.stack.is_empty():
			continue
		var top = UI.stack.back()
		if top is UI.ListMenu and top.title.begins_with(prefix):
			return top
		if top is UI.DialogBox and not top is UI.ConfirmPrompt:
			await main._press("ui_accept")
	_check(false, "expected menu: " + prefix)
	return null

func _check_actions(menu, cancel: bool) -> void:
	if UIKit.touch_ui():
		_check(menu._actions == null, "touch choice lists retain their A/B controls")
		return
	_check(menu._select_button != null and menu._back_button != null, "desktop choice list has visible Select and Back buttons")
	_check(menu._back_button.disabled == not cancel, "Back respects the choice list's cancellation rule")
	_check(menu._select_button.size.y >= UIKit.row_h() and UIKit.safe_rect(menu).encloses(menu._actions.get_global_rect()), "desktop actions are full-sized and on screen")

func _select(menu) -> void:
	if UIKit.touch_ui():
		await main._tap_at(menu.buttons[maxi(0, menu._focus)].get_global_rect().get_center())
	else:
		await main._tap_at(menu._select_button.get_global_rect().get_center())

func _back(menu) -> void:
	if UIKit.touch_ui():
		await main._press("ui_cancel")
	else:
		await main._tap_at(menu._back_button.get_global_rect().get_center())
	await main._wait(0.05)

func _shot(label: String) -> void:
	if opts.has("shots") and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(String(opts["shots"]))
		await RenderingServer.frame_post_draw
		main._save_shot(String(opts["shots"]).path_join(label + ".png"))

func _check(ok: bool, label: String) -> void:
	if not ok:
		bad += 1
	print(("ok " if ok else "FAIL ") + label)
