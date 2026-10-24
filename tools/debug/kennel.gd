extends RefCounted
## Real kennel UI in fresh state. --scene=kennel [--touch] [--verify=1] [--preview=poor|empty]

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const MapLoader = preload("res://scripts/world/map_loader.gd")

var main
var bad := 0
var town := "caccoon"


func run(root, opts: Dictionary) -> void:
	main = root
	UI.auto = true
	await main._go(MapLoader.interior_of(town, "center"), "entry")
	UI.auto = false
	_seed()
	Places.kennel(main.world, town)
	await main._wait(0.3)
	await _dialogs()
	await _open_list()
	if opts.get("verify", "0") == "1":
		await _verify()
		print("KENNEL UI DONE: %d problem(s)" % bad)
		_seed()
	if opts.get("preview", "") == "poor":
		GameState.gold = 0
	elif opts.get("preview", "") == "empty":
		for pen in GameState.kennels[town]:
			pen["beast"] = null
	if UI.stack.back().title != "Kennel":
		await main._press("ui_cancel")
		await main._wait(0.25)
	await _open_list()
	if opts.get("preview", "") == "empty":
		UI.stack.back().text_label.visible_characters = -1
	await main._wait(float(opts.get("wait", "0.5")))


func _seed() -> void:
	GameState.gold = 300
	var pens := []
	for i in 4:
		var b = GameState.Beasts.create([0, 24, 12, 30][i], [1, 20, 40, 12][i])
		if i == 3:
			b.nickname = "A Very Long Beast Nickname"
		pens.append({"beast": b, "yours": i == 3, "since": GameState.play_time})
	GameState.kennels[town] = pens
	main.world.refresh_kennel()


func _open_list() -> void:
	var menu = UI.stack.back()
	_check(menu is UI.ListMenu and menu.title == "Kennel", "adoption list opens from keeper menu")
	await _choose(menu, 0)
	await main._wait(0.3)


func _verify() -> void:
	var menu = UI.stack.back()
	var player_pos: Vector2i = main.world.player_pos
	_layout(menu)
	_check(menu.title.contains("300 gold") and menu.items[0]["right"] == "40 gold" and menu.items[3]["right"] == "Free", "list shows balance, adoption fee and free reclaim")
	await main._press("ui_down")
	await main._wait(0.15)
	_check(menu._focus == 1 and menu.desc_label.text.contains("78 gold"), "direction input shows the selected beast's level fee")
	if menu._pager.visible:
		await _tap(menu._pager._next.get_global_rect().get_center())
		await main._wait(0.2)
		_check(menu._scroll.scroll_vertical > 0, "Next tap reaches the remaining pens")
	menu.buttons.back().grab_focus()
	await main._wait(0.2)
	_check(menu.desc_label.text.contains("A Very Long Beast Nickname"), "long nickname remains readable in details")
	_layout(menu)
	menu.buttons[0].grab_focus()
	await main._wait(0.2)
	await _tap(menu.buttons[0].get_global_rect().intersection(menu._scroll.get_global_rect()).get_center())
	await main._wait(0.3)
	_check(UI.stack.size() == 1 and UI.stack.back() is UI.BeastView and GameState.gold == 300, "one row tap only opens the beast summary")
	await main._press("ui_accept")
	await main._wait(0.3)
	_check(UI.stack.back() is UI.DialogBox and str(UI.stack.back().lines).contains("40 gold"), "confirmation discloses fee and balance")
	await _dialogs()
	await _choose(UI.stack.back(), 1)
	await main._wait(0.3)
	_check(UI.stack.back() is UI.ListMenu and UI.stack.back().title == "Kennel" and GameState.gold == 300 and GameState.kennels[town][0]["beast"] != null, "No tap returns to keeper and keeps beast and gold")
	await _open_list()
	await main._press("ui_accept")
	await main._wait(0.3)
	await main._press("ui_accept")
	await main._wait(0.3)
	await _dialogs()
	await _choose(UI.stack.back(), 0)
	await main._wait(0.3)
	_check(GameState.gold == 260 and GameState.kennels[town][0]["beast"] == null, "Yes tap charges once and adopts once")
	await _dialogs()
	GameState.gold = 0
	await _open_list()
	_check(UI.stack.back().desc_label.text.contains("Not enough gold"), "poor trainer sees affordability in details")
	await main._press("ui_accept")
	await main._wait(0.3)
	await main._press("ui_accept")
	await main._wait(0.3)
	_check(UI.stack.back() is UI.DialogBox and str(UI.stack.back().lines).contains("78 gold"), "unaffordable pen explains fee")
	await _dialogs()
	_check(GameState.gold == 0 and GameState.kennels[town][1]["beast"] != null, "unaffordable selection returns without adoption")
	for pen in GameState.kennels[town]:
		pen["beast"] = null
	await _open_list()
	_check(UI.stack.back() is UI.DialogBox and str(UI.stack.back().lines).contains("empty"), "empty kennel shows its usual message")
	await _dialogs()
	_check(main.world.player_pos == player_pos, "menu taps never move the player")


func _dialogs() -> void:
	for i in 20:
		if UI.stack.is_empty() or not UI.stack.back() is UI.DialogBox or UI.stack.back() is UI.ConfirmPrompt:
			return
		UI.stack.back().text_label.visible_characters = -1
		await main._press("ui_accept")
		await main._wait(0.2)
	_check(false, "dialogue resolves within twenty pages")


func _layout(menu) -> void:
	var rect: Rect2 = menu._outer.get_global_rect()
	if not main.get_viewport().get_visible_rect().encloses(rect):
		print("kennel layout ", rect, " viewport ", main.get_viewport().get_visible_rect(), " bottom reserve ", UI.controls.menu_bottom_reserve(rect.position.x, rect.end.x))
	_check(main.get_viewport().get_visible_rect().encloses(rect), "menu fits viewport")
	_check(rect.encloses(menu.desc_label.get_global_rect()), "details stay inside menu")
	for button in menu.buttons:
		_check(button.size.y >= UIKit.row_h(), "rows retain shared minimum size")
	if menu._pager.visible:
		_check(rect.encloses(menu._pager.get_global_rect()), "page controls stay visible")
	if UI.is_touch():
		for id in UI.controls._buttons:
			var button: TouchScreenButton = UI.controls._buttons[id]
			if button.visible:
				var hit: Rect2 = UI.controls.button_rect(id).grow(UI.controls.TOUCH_SLOP)
				for row in menu.buttons:
					var visible: Rect2 = row.get_global_rect().intersection(menu._scroll.get_global_rect())
					if visible.has_area():
						_check(not hit.has_point(visible.get_center()), "visible choice stays reachable beside %s" % id)


func _choose(menu, index: int) -> void:
	if menu is UI.ConfirmPrompt:
		if index == 0:
			while menu.idx < menu.lines.size() - 1:
				await main._press("ui_accept")
				await main._wait(0.05)
		await main._wait(0.3)
		await _tap(UI.controls.button_rect("a" if index == 0 else "b").get_center())
		return
	# Focus scrolling keeps the requested row visible before a direct tap.
	menu.buttons[index].grab_focus()
	await main._wait(0.2)
	var hit: Rect2 = menu.buttons[index].get_global_rect().intersection(menu._scroll.get_global_rect())
	_check(hit.has_area(), "chosen row is visible before tapping")
	await _tap(hit.get_center())


func _tap(at: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.position = at
		event.pressed = pressed
		main.get_viewport().push_input(event, true)
		await main.get_tree().process_frame


func _check(ok: bool, label: String) -> void:
	if not ok:
		bad += 1
		print("FAIL ", label)
