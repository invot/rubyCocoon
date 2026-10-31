extends RefCounted
## Fresh-state mobile menu interaction checks and previews: --scene=mobile-menus --touch --verify=1
## --preview=confirm|list|book|title; --shots=res://build/shots/mobile_menu captures representative states.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Beasts = preload("res://scripts/core/beasts.gd")
const WorldDB = preload("res://scripts/data/world_db.gd")
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
	# the map page with the keys: the cursor moves between towns, and B gives the arrows back to the tabs
	GameState.set_flag("world_map")
	Menus.pause_menu(main.world, "map")
	await main._wait(0.6)
	var book = UI.stack.back()
	_check(is_instance_valid(book.map_view) and book.map_view.has_focus(), "the map page takes the keys")
	await main._press("ui_right")
	await main._wait(0.1)
	_check(book.map_view.town() == "tidewater" and book.TABS[book.tab]["id"] == "map", "Right moves the map's cursor to the next town east")
	await main._press("ui_accept")
	await main._wait(0.1)
	_check(UI.stack.back() == book, "A without an air beast to fly on asks nothing")
	await main._press("ui_cancel")
	await main._press("ui_right")
	await main._wait(0.1)
	_check(book.TABS[book.tab]["id"] == "settings", "after B, Right turns to the next tab")
	await main._press("menu")
	await main._wait(0.2)
	_check(UI.stack.is_empty(), "Start closes the book")


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
	_check(not menu._rail.visible, "ordinary mobile lists have no scroll buttons")
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
	await _book_map(opts)


## The book's scroll buttons, then its Map page: you marked on it, a town picked by a tap, no flying from indoors, and
## outdoors (with an air beast that can carry you) Fly here asking first: B stays, A flies.
func _book_map(opts: Dictionary) -> void:
	Menus.pause_menu(main.world, "bestiary")
	await main._wait(0.6)
	var book = UI.stack.back()
	var rail = book.list_scroll.get_parent().get_child(1)
	_check(rail.active and rail._up.disabled and rail._down.size.y >= UIKit.row_h() and rail._down.size.x >= rail.width(),
		"a long book list gets full-size scroll buttons, the up one greyed at the top")
	await main._tap_at(rail._down.get_global_rect().get_center())
	await main._wait(0.3)
	var scrolled: int = book.list_scroll.scroll_vertical
	_check(scrolled > 0 and not rail._up.disabled, "a tap on the down arrow scrolls the list")
	await main._tap_at(rail._up.get_global_rect().get_center())
	await main._wait(0.3)
	_check(book.list_scroll.scroll_vertical < scrolled, "a tap on the up arrow scrolls it back")
	await _tap(UI.controls.button_rect("start").get_center())
	await main._wait(0.2)
	GameState.set_flag("world_map")
	GameState.visited = ["caccoon", "tidewater"]
	GameState.beast_slots = GameState.PARTY_MAX
	_check(GameState.add_beast(Beasts.create(32, 42)) == "party" and Places.own_flyer() != null, "an air beast of Lv 42 joins the ring, strong enough to fly")
	Menus.world_map()
	await main._wait(0.6)
	book = UI.stack.back()
	_check(is_instance_valid(book.map_view) and book.map_view.town() == "caccoon", "the world map is the book's Map page, starting on your town")
	await main._tap_at(_town_point(book, "tidewater"))
	await main._wait(0.2)
	_check(book.map_view.town() == "tidewater", "a tap picks a town on the map")
	_check(_button(book, "Fly here") == null and _says(book, "Step outside"), "no flying from indoors")
	var covered := []
	for group in UI.controls.CLUSTERS:
		var zone: Rect2 = UI.controls.cluster_zone(group, 0.0)
		covered.append_array(WorldDB.TOWN_ORDER.filter(func(t): return zone.has_point(_town_point(book, t))))
	_check(covered.is_empty(), "every town stays clear of the touch pad %s" % [covered])
	await _tap(UI.controls.button_rect("start").get_center())
	await main._wait(0.2)
	await main._go("caccoon", "start")
	Menus.pause_menu(main.world, "map")
	await main._wait(0.6)
	book = UI.stack.back()
	await main._tap_at(_town_point(book, "tidewater"))
	await main._wait(0.2)
	var fly: Button = _button(book, "Fly here")
	_check(fly != null and fly.size.y >= UIKit.row_h(), "outdoors, a visited town offers a full-size Fly here")
	await _shot(opts, "map")
	if fly == null:
		return
	await main._tap_at(fly.get_global_rect().get_center())
	await main._wait(0.4)
	_check(UI.stack.back() is UI.ConfirmPrompt, "Fly here asks first")
	await _shot(opts, "fly_ask")
	await _tap(UI.controls.button_rect("b").get_center())
	await main._wait(0.3)
	_check(UI.stack.back() == book and GameState.map_id == "caccoon", "B: No keeps you where you are")
	await main._press("ui_accept")
	await main._wait(0.4)
	_check(UI.stack.back() is UI.ConfirmPrompt, "A on the picked town asks too")
	await _tap(UI.controls.button_rect("a").get_center())
	await main._wait(2.0)
	_check(UI.stack.is_empty() and GameState.map_id == "tidewater", "A: Yes flies you there and closes the book")


## Where a town is drawn on the open book's map, on the screen.
func _town_point(book, t: String) -> Vector2:
	return book.map_view.get_global_transform() * book.map_view._to_screen(WorldDB.MAP_POS[t])


func _button(book, text: String) -> Button:
	for b in book.right_box.find_children("*", "Button", true, false):
		if (b as Button).text == text:
			return b
	return null


func _says(book, text: String) -> bool:
	return book.right_box.find_children("*", "Label", true, false).any(func(l): return text in (l as Label).text)


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
