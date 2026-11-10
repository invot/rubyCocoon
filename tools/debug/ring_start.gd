extends RefCounted
## Starting-side rules, isolated save compatibility, live arrow/focus input and theme/layout previews.
## --scene=ring-start --verify=1 --matrix=1 --shots=res://build/shots/ring_start

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Ring = preload("res://scripts/core/ring.gd")
const Beasts = preload("res://scripts/core/beasts.gd")
const Book = preload("res://scripts/ui/book_menu.gd")

var main: Node
var bad := 0
var book: Control


func run(root: Node, opts: Dictionary) -> void:
	main = root
	if opts.get("verify", "1") == "1":
		await _rules_and_saves()
	UI.auto = true
	await main._go("caccoon#0", "entry")
	UI.auto = false
	main.world.frozen = true
	_fixture(true)
	_open()
	await main._wait(0.6)
	if opts.get("verify", "1") == "1":
		await _inputs()
	_fixture(false)
	book._open_tab(1)
	await main._wait(0.3)
	if opts.get("matrix", "0") == "1":
		for style in ["dark"]:
			for gem in UIKit.ACCENT_ORDER:
				Prefs.accent = gem
				Prefs.apply() # Runtime change only; never save the player's settings.
				await main._wait(0.3)
				_check_layout()
				await _shot(opts, "_%s_%s" % [style, gem])
	else:
		_check_layout()
		await _shot(opts, "")
	if opts.get("battle", "0") == "1":
		await _battle_opening()
	print("RING START DONE: %d problem(s)" % bad)


func _fixture(sparse: bool) -> void:
	GameState.party = []
	GameState.storage = []
	GameState.beast_slots = 8
	GameState.ring_side = 0
	GameState.preferred_ring_side = 0
	var entries := [[0, 0], [24, 4]] if sparse else [[0, 0], [3, 1], [30, 2], [30, 3], [24, 4], [12, 5], [12, 6], [0, 7]]
	for entry in entries:
		var beast := Beasts.create(entry[0], 8)
		beast.slot = entry[1]
		GameState.party.append(beast)


func _rules_and_saves() -> void:
	_check(Ring.next_occupied_side({}, 2, 1) == 2 and not Ring.side_occupied({0: null}, 0), "empty ring and null slots are safe")
	_fixture(true)
	_check(GameState.turn_starting_ring(1) and GameState.starting_ring_side() == 2, "clockwise skips empty Air")
	_check(GameState.turn_starting_ring(1) and GameState.starting_ring_side() == 0, "clockwise wraps past empty Earth")
	_check(GameState.turn_starting_ring(-1) and GameState.starting_ring_side() == 2, "anticlockwise skips empty Earth")
	GameState.party[1].hp = 0
	GameState.preferred_ring_side = 0
	_check(GameState.turn_starting_ring(1) and GameState.starting_ring_side() == 2, "fainted beasts still occupy a starting side")
	_check(Ring.covered_side(GameState.ring(), 2) == 0, "battle guard fallback still covers a fainted middle")
	GameState.party = [GameState.party[0]]
	GameState.preferred_ring_side = 0
	_check(not GameState.turn_starting_ring(1), "one occupied side stays selected")
	GameState.party[0].slot = 1
	_check(GameState.turn_starting_ring(1) and GameState.starting_ring_side() == 1, "a corner occupies both adjoining sides")
	_check(GameState.turn_starting_ring(1) and GameState.starting_ring_side() == 0, "corner rotation skips the two fully empty sides")
	_fixture(true)
	GameState.preferred_ring_side = 1
	_check(GameState.starting_ring_side() == 2, "a preferred side emptied by arrangement resolves to an occupied side")
	GameState.preferred_ring_side = 2
	GameState.ring_side = 3
	_check(GameState.starting_ring_side() == 2, "last-used battle facing does not override the preference")
	# Exercise the actual battle completion path without starting a cinematic or writing player data.
	var battle: Node = load(main.BATTLE_PATH).new()
	battle.ally_side = 1
	battle.result = "run"
	await battle._finish()
	_check(GameState.ring_side == 1 and GameState.preferred_ring_side == 2, "battle completion remembers facing without replacing the chosen opening side")
	battle.free()
	_check(GameState.save_dir().begins_with("res://build/") and GameState.save_game(0), "fixture saves only in isolated build state")
	GameState.new_game("Changed")
	_check(GameState.preferred_ring_side == -1, "new games have no explicit preference")
	_check(GameState.load_game(0) and GameState.preferred_ring_side == 2 and GameState.starting_ring_side() == 2, "preferred opening side survives save/load")
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GameState.slot_path(0)))
	legacy.erase("preferred_ring_side")
	legacy["ring_side"] = 3
	var file := FileAccess.open(GameState.slot_path(1), FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	_check(GameState.load_game(1) and GameState.preferred_ring_side == -1 and GameState.starting_ring_side() == 3,
		"older saves retain last-used facing until the player chooses a side")


func _open() -> void:
	book = Book.new().setup(main.world, "beasts")
	UI.push(book)


func _inputs() -> void:
	var at: Vector2i = main.world.player_pos
	var picker = book.ring_start_picker
	await main._tap_at(picker.right.get_global_rect().get_center())
	_check(GameState.preferred_ring_side == 2 and picker.element.text == "Water", "one arrow tap skips empty Air exactly once")
	_check(UI.stack.size() == 1, "arrow tap does not open storage")
	picker.left.grab_focus()
	for down in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_A
		event.pressed = down
		Input.parse_input_event(event)
		await main.get_tree().process_frame
	await main._wait(0.1)
	_check(GameState.preferred_ring_side == 0, "gamepad A activates the focused left arrow once")
	await main._press("ui_cancel")
	await main._wait(0.05)
	_check(book.row_buttons[0].has_focus() and book.mode == "list", "B from an arrow returns to the ring row")
	await main._press("ui_left")
	await main._wait(0.1)
	_check(GameState.preferred_ring_side == 2 and book.tab == 1, "Left on the ring row rotates without changing tabs")
	await main._press("ui_down")
	await main._wait(0.1)
	_check(book.focus_row == 1, "Down still selects a beast")
	await main._press("ui_up")
	await main._press("ui_accept")
	await main._wait(0.2)
	_check(UI.stack.size() == 2 and UI.stack.back().get_script() == Book.RingEditor, "A on the ring row still opens arrangement")
	_check(UI.stack.back().cells[4].has_focus(), "arrangement opens on the preferred side")
	await main._press("ui_cancel")
	await main._wait(0.2)
	_check(UI.stack.size() == 1 and main.world.player_pos == at, "menu inputs never walk the player")
	# Disabled arrows and no-party state; then a full list with a long nickname and real scrolling.
	GameState.party = [GameState.party[0]]
	GameState.preferred_ring_side = 0
	book._open_tab(1)
	await main._wait(0.1)
	_check(book.ring_start_picker.left.disabled and book.ring_start_picker.right.disabled, "arrows disable when only one side is occupied")
	GameState.party = []
	book._open_tab(1)
	await main._wait(0.1)
	_check(book.row_buttons.is_empty() and book.right_box.find_children("*", "Label", true, false).any(func(label): return "don't have" in label.text), "an empty party keeps its existing empty state")
	_fixture(false)
	GameState.party[0].nickname = "Embit the Extraordinary"
	book.mode = "list"
	book._open_tab(1)
	await main._wait(0.1)
	for i in 8:
		await main._press("ui_down")
	await main._wait(0.1)
	var needs_scroll: bool = book.list_box.size.y > book.list_scroll.size.y + 1.0
	_check(book.focus_row == 8 and (not needs_scroll or book.list_scroll.scroll_vertical > 0),
		"full party and long names keep focus scrolling usable (row %d, scroll %d)" % [book.focus_row, book.list_scroll.scroll_vertical])
	book._keep_row = 0
	book._open_tab(1)
	await main._wait(0.1)


func _check_layout() -> void:
	var picker = book.ring_start_picker
	var clip: Rect2 = book.right_scroll.get_global_rect().grow(1.0)
	for button in [picker.left, picker.right]:
		_check(button.size.x >= UIKit.row_h() and button.size.y >= UIKit.row_h(), "rotation arrow meets desktop/touch minimum")
		_check(clip.encloses(button.get_global_rect()), "rotation arrow is fully visible")
		_check(not UI.touch_blocks(button.get_global_rect().get_center()), "rotation arrow clears touch controls")
	_check(picker.element.text == "Fire" and picker.element.get_global_rect().position.y > picker.left.get_global_rect().position.y,
		"element label is on the second line between the arrows")
	_check(book.right_scroll.get_v_scroll_bar().max_value <= book.right_scroll.get_v_scroll_bar().page + 2.0, "ring and selector fit without detail scrolling")


func _battle_opening() -> void:
	UI.clear_all()
	await main._wait(0.1)
	GameState.preferred_ring_side = 2
	GameState.ring_side = 0
	main.start_battle({"wild": true, "foes": [Beasts.create(12, 3)], "seed": 17})
	var battle: Node
	for i in 600:
		for child in main.view.get_children():
			if child.get_script() == load(main.BATTLE_PATH):
				battle = child
		if battle != null and not battle.ally_ring.is_empty():
			break
		await main.get_tree().process_frame
	_check(battle != null and battle.ally_side == 2, "a real battle opens on the chosen Water side instead of last-used Fire")


func _shot(opts: Dictionary, suffix: String) -> void:
	if opts.has("shots") and DisplayServer.get_name() != "headless":
		var path := String(opts["shots"]) + suffix + ".png"
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		await RenderingServer.frame_post_draw
		main._save_shot(path)


func _check(ok: bool, message: String) -> void:
	if not ok:
		bad += 1
	print("%s %s" % ["ok" if ok else "FAIL", message])
