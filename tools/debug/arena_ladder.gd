extends RefCounted
## Real ladder menus in fresh state. --scene=arena-ladder --touch --rank=10 --shot=...
## --verify=1 checks layout, paging, focus, direct taps and A/B; --matrix=1 also visits every style/gem.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const LadderDB = preload("res://scripts/data/ladder_db.gd")
const MapLoader = preload("res://scripts/world/map_loader.gd")

var bad := 0
var main


func run(root, opts: Dictionary) -> void:
	main = root
	for lesson in Story.ARENA_LESSONS:
		GameState.set_flag("lesson_" + String(lesson["lesson"]))
	GameState.set_flag("met_ladder")
	UI.auto = true
	await main._go(MapLoader.interior_of("tidewater", "arena"), "entry")
	UI.auto = false
	if opts.get("verify", "0") == "1":
		var styles: Array = UIKit.STYLES if opts.get("matrix", "0") == "1" else [UIKit.style]
		var gems: Array = UIKit.ACCENT_ORDER if opts.get("matrix", "0") == "1" else [UIKit.accent_name]
		for style in styles:
			for gem in gems:
				UIKit.set_style(style)
				UIKit.set_accent(gem)
				UI.root.theme = UIKit.make_theme()
				UI.controls.refresh()
				for rank in [1, 10]:
					await _open(rank)
					if rank == 10 and opts.has("shots") and DisplayServer.get_name() != "headless":
						await RenderingServer.frame_post_draw
						main._save_shot("%s_%s_%s.png" % [opts["shots"], style, gem])
					await _verify_menu()
					await main._press("ui_cancel")
					await main._wait(0.25)
		# Empty lists use the same sizing/placement path, with no trainer row to focus.
		UI.choose("No trainers", [], {"anchor": "right", "width": 480})
		await main._wait(0.3)
		_check_layout(UI.stack.back())
		await main._press("ui_cancel")
		await main._wait(0.25)
		print("ARENA LADDER DONE: %d problem(s)" % bad)
	await _open(clampi(int(opts.get("rank", "10")), 1, 10))
	await main._wait(float(opts.get("wait", "1")))


func _open(rank: int) -> void:
	GameState.ladder = {}
	for r in range(1, rank):
		GameState.ladder[r] = range(LadderDB.count(r))
	GameState.trainer_level = rank
	Places.ladder()
	await main._wait(0.4)


func _verify_menu() -> void:
	var menu = UI.stack.back()
	var player_pos: Vector2i = main.world.player_pos
	_check_layout(menu)
	_check(menu.buttons[0].has_focus(), "first trainer has keyboard/gamepad focus")
	await main._press("ui_down")
	await main._wait(0.15)
	_check(menu._focus == 1, "direction input selects the next trainer")
	menu.buttons[0].grab_focus()
	await main._wait(0.15)
	if menu._pager.visible:
		_check(menu._pager._next.size.y >= UIKit.row_h(), "page buttons keep the shared minimum height")
		await _tap(menu._pager._next.get_global_rect().get_center())
		await main._wait(0.25)
		_check(menu._scroll.scroll_vertical > 0, "direct Next tap pages the trainer list")
		await _tap(menu._pager._prev.get_global_rect().get_center())
		await main._wait(0.25)
		_check(menu._scroll.scroll_vertical == 0, "direct Prev tap returns to the first page")
	menu.buttons.back().grab_focus()
	await main._wait(0.2)
	_check(menu._scroll.get_global_rect().intersects(menu.buttons.back().get_global_rect()), "focus navigation reaches the final trainer")
	_check_layout(menu)
	# A real row tap must choose once. An exhausted test party opens the normal healing message instead of a fight.
	for beast in GameState.party:
		beast.hp = 0
	await _tap(menu.buttons.back().get_global_rect().intersection(menu._scroll.get_global_rect()).get_center())
	await main._wait(0.25)
	_check(UI.stack.size() == 1 and UI.stack.back() != menu and UI.stack.back().get("speaker") == "Arena Host",
		"one trainer tap opens exactly one healing message")
	if not UI.stack.is_empty() and UI.stack.back().get("speaker") == "Arena Host":
		var dialog = UI.stack.back()
		dialog.text_label.visible_characters = -1
		await main._press("ui_accept")
		await main._wait(0.3)
	GameState.heal_party()
	if UI.is_touch():
		var back: TouchScreenButton = UI.controls._buttons["b"]
		await _tap(back.position + Vector2.ONE * UI.controls.ROUND / 2.0)
		await main._wait(0.25)
		_check(UI.stack.is_empty(), "touch B cancels the ladder without choosing a trainer")
		await _open(1)
		for beast in GameState.party:
			beast.hp = 0
		var accept: TouchScreenButton = UI.controls._buttons["a"]
		await _tap(accept.position + Vector2.ONE * UI.controls.ROUND / 2.0)
		await main._wait(0.25)
		_check(UI.stack.size() == 1 and UI.stack.back().get("speaker") == "Arena Host", "touch A confirms once")
		if not UI.stack.is_empty() and UI.stack.back().get("speaker") == "Arena Host":
			UI.stack.back().text_label.visible_characters = -1
			await main._press("ui_accept")
			await main._wait(0.3)
		GameState.heal_party()
	_check(main.world.player_pos == player_pos, "menu taps never move the player")


func _check_layout(menu) -> void:
	var rect: Rect2 = menu._outer.get_global_rect()
	_check(main.get_viewport().get_visible_rect().encloses(rect), "whole menu stays on screen")
	for button in menu.buttons:
		_check(button.size.y >= UIKit.row_h(), "trainer row keeps the shared minimum height")
	if UI.is_touch():
		for id in UI.controls._buttons:
			var button: TouchScreenButton = UI.controls._buttons[id]
			if button.visible:
				var hit := Rect2(button.position, button.texture_normal.get_size()).grow(UI.controls.TOUCH_SLOP)
				_check(not rect.intersects(hit), "menu clears %s and its enlarged hit area" % id)
	if menu._pager.visible:
		_check(rect.encloses(menu._pager.get_global_rect()) and menu._pager._count.text != "", "page controls and count stay inside the menu")
	if menu.desc_label != null:
		_check(rect.encloses(menu.desc_label.get_global_rect()), "trainer details stay inside the menu")


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
