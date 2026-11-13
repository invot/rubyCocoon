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
	var started := Time.get_ticks_usec()
	book._open_tab(1)
	print("Beasts page built in %.0f ms (%d beasts)" % [(Time.get_ticks_usec() - started) / 1000.0, GameState.party.size()])
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
	if opts.has("shots") and opts.get("matrix", "0") != "1":
		book.beasts_page.activate(1)
		await main._wait(0.3)
		await _shot(opts, "_actions")
		book.beasts_page._close_actions()
		UI.clear_all()
		await main._wait(0.1)
		_fixture(true)
		GameState.party[0].hp = maxi(1, GameState.party[0].max_hp() / 3)
		var storage := Book.new()
		storage.storage_mode = true
		storage.setup(main.world, "beasts")
		UI.push(storage)
		book = storage
		await main._wait(0.6)
		await _shot(opts, "_storage")
		storage.beasts_page.activate(storage.beasts_page._row_of(GameState.storage[0]))
		await main._wait(0.3)
		await _shot(opts, "_storage_placing")
	if opts.get("placing", "0") == "1":
		book.beasts_page.activate(1)
		book.beasts_page._do_action("move")
		book.beasts_page.move_destination(1)
		await main._wait(0.3)
		_check_layout()
		await _shot(opts, "_placement")
	if opts.get("battle", "0") == "1":
		await _battle_opening()
	print("RING START DONE: %d problem(s)" % bad)


func _fixture(sparse: bool) -> void:
	GameState.party = []
	GameState.storage = []
	GameState.beast_slots = 4 if sparse else 8
	GameState.ring_side = 0
	GameState.preferred_ring_side = 0
	var entries := [[0, 0], [24, 4]] if sparse else [[0, 0], [3, 1], [30, 2], [30, 3], [24, 4], [12, 5], [12, 6], [0, 7]]
	for entry in entries:
		var beast := Beasts.create(entry[0], 8)
		beast.slot = entry[1]
		GameState.party.append(beast)
	if sparse:
		var stored := Beasts.create(0, 5)
		stored.slot = -1
		stored.nickname = "Stored Embit"
		GameState.storage.append(stored)


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
	var started := Time.get_ticks_usec()
	book = Book.new().setup(main.world, "beasts")
	UI.push(book)
	print("book opened on Beasts in %.0f ms (%d beasts)" % [(Time.get_ticks_usec() - started) / 1000.0, GameState.party.size()])


func _inputs() -> void:
	var at: Vector2i = main.world.player_pos
	await _tabs_up_down()
	var page = book.beasts_page
	await main._tap_at(book.row_buttons[0].get_global_rect().get_center())
	_check(GameState.preferred_ring_side == 2, "one Default element tap skips empty Air exactly once")
	_check(UI.stack.size() == 1, "default element stays within the beast list")
	for down in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_A
		event.pressed = down
		Input.parse_input_event(event)
		await main.get_tree().process_frame
	await main._wait(0.1)
	_check(GameState.preferred_ring_side == 0, "gamepad A changes the focused default element once")
	await main._press("ui_left")
	await main._wait(0.1)
	_check(GameState.preferred_ring_side == 2 and book.tab == 1, "Left on Default element rotates without changing tabs")
	book.focus_row = 0
	book.row_buttons[0].grab_focus()
	await main._press("ui_up")
	await main._wait(0.05)
	_check(book.mode == "tabs" and book.tab == 1, "Up on the first row goes back to the tabs")
	await main._press("ui_down")
	await main._wait(0.05)
	_check(book.mode == "list" and book.row_buttons[0].has_focus(), "Down from the tabs returns to the first row")
	var fire = GameState.party[0]
	var stored = GameState.storage[0]
	_check(book.rows.size() == 1 + GameState.party.size() and not book.rows.any(func(row): return row.get("beast", null) == stored),
		"the book lists only carried (ring) beasts, never stored ones")
	_check(book.rows.slice(1).all(func(row): return String(row.get("sub", "")).begins_with("HP ") and " MP " in String(row["sub"])),
		"every beast row shows its HP and MP under its name")
	fire.hp = 1
	var vit: String = page.vitals(fire)
	_check(vit.begins_with("HP 1/%d" % fire.max_hp()) and vit.ends_with("MP %d" % fire.max_mp()), "vitals show current/limit, or one value when full: %s" % vit)
	fire.heal_full()
	await main._press("ui_down")
	_check(book.focus_row == 1, "Down still selects a beast")
	await main._wait(0.2)
	var stage = page.preview.stage
	_check(stage.selected_beast == fire, "focusing a beast highlights it on the ring")
	await main._press("ui_accept")
	await main._wait(0.05)
	_check(page.actions_for == fire and page.picked == null and fire.slot == 0 and UI.stack.size() == 1,
		"one A opens the beast's actions without moving it or opening another screen")
	var ids: Array = page.action_buttons.keys()
	_check(ids == ["info", "move", "equip"], "actions are Info, Move and Equip (no Fly without a strong air beast): %s" % [ids])
	_check(page.action_buttons["info"].has_focus(), "the first action has the focus")
	_check(page.action_buttons.values().all(func(button): return button.custom_minimum_size.y >= UIKit.row_h()), "action buttons keep full touch height")
	await main._press("ui_right")
	_check(page.action_buttons["move"].has_focus() and book.tab == 1, "Right moves along the actions without changing tabs")
	await main._press("ui_accept")
	await main._wait(0.05)
	_check(page.picked == fire and fire.slot == 0 and book.mode == "ring_place", "Move picks the beast up without moving it yet (mode %s, picked %s)" % [book.mode, page.picked != null])
	await main._press("ui_right")
	_check(page.destination == 1 and fire.slot == 0, "Right previews an empty compatible corner without changing the formation")
	await main._wait(0.2)
	_check(stage.selected_beast == fire and stage.aim_mesh == null and stage._front_geometry.size() > 0,
		"placement outlines the selected 3D beast without a yellow arrow")
	_check((stage.nodes[fire] as Node3D).position.distance_to(stage._slot_pos("ally", 1)) < 0.01,
		"the selected model previews the destination while its saved slot stays unchanged")
	var cycled := []
	for step in 3:
		cycled.append(page.destination)
		page.move_destination(1)
	_check(cycled.size() == 3 and cycled.has(0) and cycled.has(1) and cycled.has(7) and page.destination == 1,
		"a fire beast cycles exactly its three element-compatible ring slots (no storage in the book)")
	await main._wait(0.2)
	_check(stage._model_geometry(fire).all(func(geometry): return geometry.layers & 1 != 0 and geometry.layers & stage.FRONT_LAYER != 0 and geometry.layers & stage.FADED_LAYER == 0),
		"the moving selected beast stays fully opaque in the main view and continuously in the outline mask")
	var water = GameState.party[1]
	_check(stage._model_geometry(water).all(func(geometry): return geometry.layers & stage.FADED_LAYER != 0 and geometry.layers & 1 == 0),
		"the other beasts render only in the faded layer")
	_check(not page.store_button.visible, "the book has no Store action")
	await main._press("ui_accept")
	_check(page.picked == null and fire.slot == 1, "A confirms one move")
	await main._tap_at(book.row_buttons[1].get_global_rect().get_center())
	_check(page.actions_for == fire, "tapping a beast opens its actions")
	await main._tap_at(page.action_buttons["move"].get_global_rect().get_center())
	_check(page.picked == fire, "tapping Move picks it up")
	await main._press("ui_right")
	await main._press("ui_cancel")
	_check(page.picked == null and fire.slot == 1 and page.actions_for == fire and page.action_buttons["move"].has_focus(),
		"B cancels tentative placement and returns to the actions on Move")
	await main._press("ui_cancel")
	_check(page.actions_for == null and book.mode == "list" and book.row_buttons[1].has_focus(), "B closes the actions back to the list")
	await main._press("ui_cancel")
	_check(UI.stack.size() == 1 and main.world.player_pos == at, "menu inputs never walk the player")
	await _storage_inputs(fire, stored)
	_open()
	await main._wait(0.3)
	# No-party state, then a full roster with compatible occupied swaps and scrolling.
	GameState.preferred_ring_side = 0
	GameState.party = []
	GameState.storage = []
	book._open_tab(1)
	await main._wait(0.1)
	_check(book.rows.size() == 1 and book.beasts_page.preview.stage.nodes.is_empty(), "an empty roster keeps Default element and an empty 3D ring")
	_fixture(false)
	book._open_tab(1)
	await main._wait(0.1)
	page = book.beasts_page
	fire = GameState.party[0]
	page.activate(1)
	page._do_action("move")
	page.move_destination(1)
	var dest: int = page.destination
	var other = GameState.beast_at(dest)
	_check(other != null and other != fire, "a full ring offers an occupied compatible spot")
	await main._press("ui_accept")
	_check(fire.slot == dest and other.slot == 0, "two beasts already in the ring trade places on confirmation")
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


## The Beast Center's storage: the same page in storage mode, the only place to swap carried and stored beasts.
func _storage_inputs(fire, stored) -> void:
	UI.clear_all()
	await main._wait(0.1)
	book = Book.new()
	book.storage_mode = true
	book.setup(main.world, "beasts")
	UI.push(book)
	await main._wait(0.4)
	var page = book.beasts_page
	_check(not book.tab_strip.visible and book.rows.size() == GameState.party.size() + GameState.storage.size(),
		"storage lists carried and stored beasts, without the book's tabs or Default element")
	var row: int = page._row_of(stored)
	_check(row == GameState.party.size(), "stored beasts follow the carried ones")
	fire.hp = 1
	await main._tap_at(book.row_buttons[row].get_global_rect().get_center())
	_check(page.picked == stored, "tapping a stored beast picks it up")
	for i in 3:
		if page.destination == fire.slot:
			break
		await main._press("ui_right")
	_check(page.destination == fire.slot, "an occupied compatible spot can be chosen without swapping yet")
	await main._press("ui_accept")
	await main._wait(0.1)
	_check(GameState.party.has(stored) and stored.slot == 1 and GameState.storage.has(fire) and fire.slot == -1,
		"confirmation swaps a stored beast onto an occupied ring spot")
	_check(fire.hp == fire.max_hp(), "a beast going into storage is healed")
	page = book.beasts_page
	_check(page._row_of(stored) < GameState.party.size() and page._row_of(fire) >= GameState.party.size(), "the list moves both beasts to their new sections")
	page.activate(page._row_of(stored))
	var stops: Array = page._stops()
	_check(stops.back() == page.STORE_STOP, "a carried beast's spots end with Storage, so Store works with the d-pad")
	if not await _select_storage_destination(page):
		return
	_check(page.heading.text.ends_with("Storage") and page.store_button.visible and not page.store_button.disabled, "Storage stop and Store button are offered")
	await main._press("ui_accept")
	await main._wait(0.1)
	page = book.beasts_page
	_check(GameState.storage.has(stored) and page.slots_label.text == "1 / 4 slots used", "storing a beast updates occupied versus unlocked slots")
	page.activate(0)
	if not await _select_storage_destination(page):
		return
	await main._press("ui_accept")
	_check(GameState.party.size() == 1 and page.store_button.disabled, "the last carried beast cannot be placed in storage")
	await main._press("ui_cancel")
	await main._press("ui_cancel")
	_check((not is_instance_valid(book) or book.closed) and UI.stack.is_empty(), "B closes the storage screen")


## A failed earlier pickup can leave no Storage stop. Fail instead of spinning
## synchronously and queuing unbounded audio play commands without a frame.
func _select_storage_destination(page) -> bool:
	var stops: Array = page._stops()
	if not stops.has(page.STORE_STOP):
		_check(false, "the picked beast offers a Storage destination")
		return false
	for i in stops.size():
		if page.destination == page.STORE_STOP:
			return true
		page.move_destination(1)
		await main.get_tree().process_frame
	_check(page.destination == page.STORE_STOP, "the Storage destination is reachable in one cycle")
	return page.destination == page.STORE_STOP


## Every tab: Up from the top of its page goes to the tabs, and Down from the tabs goes back into the page.
func _tabs_up_down() -> void:
	var had_map: bool = GameState.flags.get("world_map", true)
	GameState.flags["world_map"] = true
	for i in book.TABS.size():
		book._open_tab(i)
		book.mode = "list"
		book._focus_first()
		await main._wait(0.1)
		var name: String = book.TABS[i]["id"]
		var owner_before: Control = book.get_viewport().gui_get_focus_owner()
		if name == "map":
			# from the northernmost town
			if is_instance_valid(book.map_view):
				for k in 12:
					await main._press("ui_up")
				await main._wait(0.05)
		else:
			await main._press("ui_up")
			await main._wait(0.05)
		_check(book.mode == "tabs", "%s: Up at the top goes to the tabs (mode %s, focus was %s)" % [name, book.mode, owner_before])
		await main._press("ui_down")
		await main._wait(0.05)
		var owner: Control = book.get_viewport().gui_get_focus_owner()
		_check(book.mode == "list" and owner != null and book.tab == i, "%s: Down from the tabs enters the page (mode %s, focus %s)" % [name, book.mode, owner])
	GameState.flags["world_map"] = had_map
	book._open_tab(1)
	book.mode = "list"
	book.focus_row = 0
	book._focus_first()
	await main._wait(0.1)


func _check_layout() -> void:
	var page = book.beasts_page
	var clip: Rect2 = book.right_scroll.get_global_rect().grow(1.0)
	_check(book.rows[0]["text"] == "Default element" and book.row_buttons[0].get_child(0).text == "Fire",
		"Default element and its name occupy the first left row")
	_check(book.right_box.find_children("*", "Button", true, false).all(func(button): return button.text in ["Info", "Store", "Move", "Fly", "Equip"]),
		"ring preview has no default-element arrow buttons")
	_check(page.details.custom_minimum_size.y >= UIKit.row_h() and (not page.details.visible or clip.encloses(page.details.get_global_rect())),
		"beast details remain reachable at the shared touch/desktop size")
	_check(book.rows.slice(1).all(func(row): return "Lv " in row.get("right", "") and not "Ring " in row.get("right", "") and "HP " in String(row.get("sub", ""))),
		"every carried beast lists its level and its HP and MP, with no ring icon")
	_check(book.right_scroll.get_v_scroll_bar().max_value <= book.right_scroll.get_v_scroll_bar().page + 2.0, "ring and selector fit without detail scrolling")
	var preview = page.preview.stage
	_check(page.slots_label.text == "%d / %d slots used" % [GameState.ring().size(), GameState.party_max()],
		"right pane shows occupied slots and unlocked capacity")
	_check(preview.player_rig == null and preview.ring_root["ally"].get_child_count() == 9,
		"Beasts preview omits the trainer and center dais, retaining the circle and eight pads")
	_check(preview.nodes.size() == GameState.ring().size() and preview.pads["ally"].size() == 8,
		"preview uses all eight battle pads and the actual party's 3D models")
	_check(preview.camera_director == null and preview.floating == null,
		"preview never starts combat or constructs a battle HUD")
	var battle_direction: Vector3 = (preview._cam_look() - preview._cam_pos()).normalized()
	_check(preview.cam.global_basis.z.dot(-battle_direction) > 0.999,
		"preview preserves the battle camera's perspective direction")
	var visible := Rect2(Vector2.ZERO, Vector2(preview.get_viewport().size))
	var fits := true
	for beast in preview.nodes:
		var model: Node3D = preview.nodes[beast]
		var shown_slot: int = page.destination if page.picked == beast else beast.slot
		fits = fits and model.position.distance_to(preview._slot_pos("ally", shown_slot)) < 0.01
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			for index in 8:
				var point := mesh.global_transform * mesh.get_aabb().get_endpoint(index)
				fits = fits and visible.has_point(preview.cam.unproject_position(point))
	_check(fits, "3D beasts stand on their battle slots and fit inside the preview")


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
	if battle != null:
		_check(battle.player_rig != null and battle.ring_root["ally"].get_child_count() == 10,
			"actual battles retain the trainer and center dais")
		await battle._turn_ring("ally", 0, true)
		_check(GameState.preferred_ring_side == 0 and GameState.starting_ring_side() == 0,
			"a player-chosen battle rotation becomes the next battle's opening side")
		await battle._turn_ring("ally", 2)
		_check(GameState.preferred_ring_side == 0, "automatic formation changes retain the player's chosen front")
		_check(GameState.save_game(2) and GameState.load_game(2) and GameState.preferred_ring_side == 0,
			"the battle-chosen front survives isolated save/load")


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
