extends RefCounted
## --scene=bag-actions: the Bag page's grid, actions and targets (scripts/ui/bag_page.gd). Use a potion on the one hurt
## beast (taps), find a battle item's Use blocked, put gear on a beast and trainer gear on you (keys), and drop an item
## after saying no and then yes. Only those an item would affect can be chosen. --shots=prefix saves each state.
const Book = preload("res://scripts/ui/book_menu.gd")
const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Beasts = preload("res://scripts/core/beasts.gd")
var bad := 0
var main: Node
var opts := {}


func check(ok: bool, message: String) -> void:
	if not ok:
		bad += 1
	print("%s %s" % ["ok" if ok else "FAIL", message])


func run(root: Node, _opts: Dictionary) -> void:
	main = root
	opts = _opts
	await main._go("caccoon", "start")
	main.world.frozen = true
	await main._wait(1.0)
	GameState.party = []
	GameState.storage = []
	GameState.beast_slots = 4
	var hurt = Beasts.create(0, 12)
	var full = Beasts.create(9, 12)
	var down = Beasts.create(18, 12)
	for b in [hurt, full, down]:
		GameState.add_beast(b)
		b.hp = b.max_hp()
		b.mp = b.max_mp()
	hurt.hp = 5
	down.hp = 0
	full.status = "poison"
	GameState.gear["head"] = "worn_cap"
	GameState.inventory = {"potion": 3, "fire_bomb": 2, "power_collar": 1, "explorer_hat": 1, "miner_pass": 1, "minor_potion": 12}
	while UI.top_bar.pending() > 0:
		await main._wait(0.25)
	var book = Book.new().setup(main.world, "bag")
	UI.push(book)
	await main._wait(0.6)
	var bag = book.bag
	check(bag != null and bag.mode == "grid", "Bag opens on its grid")
	check(bag.stacks.size() == 7, "one slot per stack (%d)" % bag.stacks.size())
	book.mode = "list"
	book._focus_first()
	await main._wait(0.2)
	await shot("grid")

	# ---- a potion, all by taps: the slot opens its actions, Use the ring, the hurt beast, Confirm
	var potion := _cell(bag, "potion")
	await tap(bag.cells[potion])
	check(bag.mode == "actions" and bag.picked == potion, "one tap opens the potion's actions (%s)" % bag.mode)
	check(_actions(bag) == ["Use", "Drop", "Back"], "potion offers Use, Drop, Back: %s" % [_actions(bag)])
	await shot("actions")
	await tap(bag.action_buttons[0])
	check(bag.mode == "target", "Use opens the ring (%s)" % bag.mode)
	await main._wait(0.3)
	var allowed: Array = bag.targets.filter(func(c): return c.allowed)
	check(allowed.size() == 1 and bag.same(allowed[0].who, hurt), "only the hurt beast can take a potion")
	check(bag.same(bag.target, hurt), "the preview starts on it")
	check(not bag.targets.filter(func(c): return typeof(c.who) == TYPE_STRING)[0].allowed, "you can't drink a beast's potion")
	check(bag.targets.all(func(c): return c.disabled == not c.allowed), "the ones it can't help are disabled")
	check(bag.ItemUse.condition(down)[0] == "KO" and bag.ItemUse.condition(full)[0] == "PSN", "fainted and poisoned beasts are tagged")
	await shot("target_use")
	await tap(_target_cell(bag, full))
	check(bag.same(bag.target, hurt) and bag.mode == "target", "tapping a full beast changes nothing")
	UI.auto = true
	await tap(bag.confirm_button)
	await main._wait(0.3)
	UI.auto = false
	check(hurt.hp > 5 and GameState.item_count("potion") == 2, "Confirm uses one potion on it (HP %d)" % hurt.hp)
	check(bag.mode == "actions" and bag.stacks[bag.picked]["id"] == "potion", "back on the potion's actions while some are left")
	await main._press("ui_cancel")
	await main._wait(0.2)
	check(bag.mode == "grid", "B goes back to the grid")

	# ---- the rest by keys: park the pointer, since on desktop hovering a slot or row takes the cursor
	main.get_viewport().warp_mouse(Vector2(2, 2))
	# ---- a battle item: Use shows why it can't be chosen
	_focus_cell(bag, "fire_bomb")
	await main._press("ui_accept")
	await main._wait(0.2)
	check(bag.mode == "actions" and _actions(bag)[0] == "Use", "A opens the fire bomb's actions")
	await main._press("ui_accept")
	await main._wait(0.2)
	check(bag.mode == "actions", "a battle item's Use stays put outside battle")
	await main._press("ui_cancel")
	await main._wait(0.2)

	# ---- beast gear, all by keys: every standing beast may wear it, you may not
	_focus_cell(bag, "power_collar")
	await main._press("ui_accept")
	await main._wait(0.2)
	check(_actions(bag) == ["Equip", "Drop", "Back"], "gear offers Equip, Drop, Back: %s" % [_actions(bag)])
	await main._press("ui_accept")
	await main._wait(0.3)
	check(bag.mode == "target" and bag.action == "equip", "Equip opens the ring")
	var beasts_ok: Array = bag.targets.filter(func(c): return c.allowed and typeof(c.who) != TYPE_STRING)
	var you_ok: bool = bag.targets.filter(func(c): return typeof(c.who) == TYPE_STRING)[0].allowed
	check(beasts_ok.size() == 3 and not you_ok, "beast gear: every beast, not you")
	var rows: Array = bag.ItemUse.gear_preview("power_collar", bag.target)
	check(rows.any(func(r): return r["name"] == "Attack" and int(r["after"]) > int(r["before"])), "preview shows Attack rising")
	await shot("target_gear")
	var who = bag.target
	await main._press("ui_accept")
	await main._wait(0.2)
	check(book.get_viewport().gui_get_focus_owner() == bag.confirm_button, "A on a beast moves to Confirm")
	await main._press("ui_cancel")
	await main._wait(0.2)
	check(bag.mode == "target" and book.get_viewport().gui_get_focus_owner() != bag.confirm_button, "B from Confirm goes back to the ring")
	await main._press("ui_accept")
	await main._wait(0.2)
	await main._press("ui_accept")
	await main._wait(0.4)
	check(who.equip == "power_collar" and GameState.item_count("power_collar") == 0, "Confirm puts the collar on")
	check(bag.mode == "grid", "the last of an item goes back to the grid")

	# ---- trainer gear: only you, the old cap back to the bag
	_focus_cell(bag, "explorer_hat")
	await main._press("ui_accept")
	await main._wait(0.2)
	await main._press("ui_accept")
	await main._wait(0.3)
	var only: Array = bag.targets.filter(func(c): return c.allowed)
	check(only.size() == 1 and typeof(only[0].who) == TYPE_STRING and bag.same(bag.target, "trainer"), "trainer gear: only you")
	await shot("target_trainer")
	await main._press("ui_accept")
	await main._wait(0.2)
	await main._press("ui_accept")
	await main._wait(0.4)
	check(GameState.gear["head"] == "explorer_hat" and GameState.item_count("worn_cap") == 1, "hat on, cap back in the bag")

	# ---- drop asks first: No keeps it, Yes drops one
	_focus_cell(bag, "minor_potion")
	await main._press("ui_accept")
	await main._wait(0.2)
	bag.action_buttons[1].grab_focus()
	await main._press("ui_accept")
	await main._wait(0.5)
	check(UI.stack.size() == 2, "Drop asks first (stack %d)" % UI.stack.size())
	await shot("drop")
	await main._press("ui_cancel")
	await main._wait(0.4)
	check(GameState.item_count("minor_potion") == 12 and bag.mode == "actions", "No keeps it")
	bag.action_buttons[1].grab_focus()
	await main._press("ui_accept")
	await main._wait(0.5)
	await main._press("ui_accept")
	await main._wait(0.5)
	check(GameState.item_count("minor_potion") == 11, "Yes drops one (%d left)" % GameState.item_count("minor_potion"))
	await main._press("ui_cancel")
	await main._wait(0.2)

	# ---- a key item has nothing to do but go back
	_focus_cell(bag, "miner_pass")
	await main._press("ui_accept")
	await main._wait(0.2)
	check(_actions(bag) == ["Back"], "key items can't be used, worn or dropped: %s" % [_actions(bag)])
	await main._press("ui_accept")
	await main._wait(0.2)
	check(bag.mode == "grid", "Back returns to the grid")
	await main._press("ui_cancel")
	await main._wait(0.2)
	check(book.mode == "tabs", "B from the grid goes to the tabs")
	book.close()
	print("BAG ACTIONS DONE: %d problem(s)" % bad)


func _cell(bag, id: String) -> int:
	for i in bag.stacks.size():
		if bag.stacks[i]["id"] == id:
			return i
	return -1


func _focus_cell(bag, id: String) -> void:
	var i := _cell(bag, id)
	if i >= 0:
		(bag.cells[i] as Control).grab_focus()


func _target_cell(bag, who) -> Control:
	for c in bag.targets:
		if bag.same(c.who, who):
			return c
	return null


func _actions(bag) -> Array:
	return bag.action_buttons.map(func(b): return b.text)


func shot(name: String) -> void:
	await main._wait(0.3)
	if opts.has("shots") and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		main._save_shot(String(opts["shots"]) + "_" + name + ".png")


func tap(c: Control) -> void:
	if c == null:
		check(false, "nothing to tap")
		return
	var at := c.get_global_rect().get_center()
	if opts.has("debug_taps"):
		print("tap ", c.name, " ", c.get_global_rect(), " vis ", main.get_viewport().get_visible_rect().size, " win ", main.get_window().size, " focus ", main.get_viewport().gui_get_focus_owner())
	if not UI.is_touch():
		await main._tap_at(at)
		return
	for down in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 7
		event.pressed = down
		event.position = at * Vector2(main.get_window().size) / main.get_viewport().get_visible_rect().size
		Input.parse_input_event(event)
		await main.get_tree().process_frame
	await main._wait(0.15)
