extends RefCounted
## Bag boundaries, lossless migration, shopping, persistent world swaps and live book input.
const Book = preload("res://scripts/ui/book_menu.gd")
const UIKit = preload("res://scripts/ui/ui_kit.gd")
var bad := 0
var main: Node


func check(ok: bool, message: String) -> void:
	if not ok:
		bad += 1
	print("%s %s" % ["ok" if ok else "FAIL", message])


func run(root: Node, opts: Dictionary) -> void:
	main = root
	GameState.inventory = {}
	check(GameState.add_item("minor_potion", 10) == 0 and GameState.stacks_used(GameState.inventory) == 2, "tenth item starts another stack")
	GameState.inventory = {"minor_potion": 215}
	check(GameState.add_item("minor_potion", 3) == 2 and GameState.item_count("minor_potion") == 216, "partial acceptance returns remainder")
	check(GameState.add_item("potion") == 1, "new kind cannot enter a full bag")
	for id in ["miner_pass", "slingshot", "sheet_hymn"]:
		check(GameState.add_item(id, 100) == 0, "exempt item: " + id)
	check(GameState.stacks_used(GameState.inventory) == 24, "exempt items use no stacks")
	GameState.tower_inventory = {"potion": 432}
	GameState.receive_item("honey_cake", 3)
	check(GameState.tower_inventory.get("honey_cake") == 3, "rewards exceed tower capacity without loss")
	check(GameState.transfer_item("minor_potion", 9, true) == 0, "manual deposits respect tower limit")
	check(GameState.transfer_item("potion", 9, false) == 0, "withdrawal respects bag limit")
	GameState.inventory = {"minor_potion": 700, "potion": 9, "slingshot": 1}
	check(GameState.save_dir().begins_with("res://build/"), "only isolated saves")
	check(GameState.save_game(0), "save oversized legacy fixture")
	check(GameState.load_game(0), "load and migrate fixture")
	check(GameState.item_count("minor_potion") == 216 and GameState.tower_inventory.get("minor_potion") == 484 and GameState.tower_inventory.get("potion") == 441, "migration preserves all items beyond both limits")
	check(GameState.save_game(0) and GameState.load_game(0) and GameState.tower_inventory.get("minor_potion") == 484, "migration does not run twice on saved data")
	UI.auto = true
	UI.auto_answers = [0, -1]
	var gold: int = GameState.gold
	await Places._buy(["potion"])
	check(GameState.gold == gold and GameState.item_count("potion") == 0, "refused purchase charges no gold")
	await main._go("caccoon", "start")
	main.world.frozen = true
	var at := Vector2i(1, 1)
	var item := {"item": "potion", "flag": "bag_limit_pickup", "pos": at, "node": Node3D.new()}
	main.world.add_child(item["node"])
	main.world.items[at] = item
	UI.auto_answers = [1]
	await main.world._pickup(item)
	check(not GameState.flag(item["flag"]) and main.world.items.has(at), "declining full pickup keeps it on map")
	UI.auto_answers = [0, -1]
	await main.world._pickup(item)
	check(not GameState.flag(item["flag"]), "canceling stack selection preserves pickup")
	UI.auto_answers = [0, 0, 0]
	await main.world._pickup(item)
	check(GameState.item_count("potion") == 1 and item["item"] == "minor_potion" and item["count"] == 9, "swap takes incoming item and leaves outgoing stack")
	check(GameState.save_game(0) and GameState.load_game(0) and GameState.flags.get("bag_swap:bag_limit_pickup", {}).get("count") == 9, "left stack persists through save/load")
	GameState.remove_item("minor_potion", 9)
	await main.world._pickup(item)
	check(not main.world.items.has(at) and not GameState.flags.has("bag_swap:bag_limit_pickup"), "collecting left stack clears its persistence record")
	UI.auto = false
	GameState.inventory = {"minor_potion": 10, "spirit_drop": 9, "fire_bomb": 9, "power_collar": 9, "silver_flute": 9, "sheet_hymn": 1, "miner_pass": 1, "slingshot": 1}
	var book = Book.new().setup(main.world, "bag")
	UI.push(book)
	await main._wait(0.5)
	var bag = book.bag
	check(bag != null and bag.stacks.size() == 9, "Bag shows each stack and key items separately")
	book.mode = "list"
	book._focus_first()
	await main._wait(0.1)
	await main._press("ui_right")
	await main._wait(0.1)
	check(bag.focus_cell == 1, "keyboard selection advances one stack")
	var target: Button = bag.cells[3]
	bag.grid_scroll.ensure_control_visible(target)
	await main._wait(0.3)
	await tap(target.get_global_rect().get_center())
	await main._wait(0.2)
	check(UI.stack.size() == 1 and bag.mode == "actions" and bag.picked == 3, "tap opens exactly one item's actions (stack %d, %s)" % [UI.stack.size(), bag.mode])
	await main._press("ui_cancel")
	await main._wait(0.2)
	check(UI.stack.size() == 1 and bag.mode == "grid", "B returns from the actions to the grid")
	for c in bag.cells:
		check(c.size.y >= UIKit.row_h(), "item slot meets target minimum")
	GameState.inventory = {}
	book._open_tab(3)
	check(book.bag.stacks.is_empty(), "empty bag remains usable")
	GameState.inventory = {"minor_potion": 10, "spirit_drop": 9, "fire_bomb": 72, "power_collar": 9, "silver_flute": 36, "worm_bait": 18, "sheet_hymn": 1, "slingshot": 1}
	while UI.top_bar.pending() > 0:
		await main._wait(0.25)
	for gem in UIKit.ACCENT_ORDER:
		Prefs.accent = gem
		Prefs.apply()
		book._keep_row = 0
		book._open_tab(3)
		book.mode = "list"
		book._focus_first()
		await main._wait(0.3)
		if opts.has("shots") and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			main._save_shot(String(opts["shots"]) + "_" + gem + ".png")
	book.close()
	await main._wait(0.3)
	GameState.inventory = {"minor_potion": 216}
	var ground := {"item": "potion", "flag": "bag_limit_live", "pos": at, "node": Node3D.new()}
	main.world.add_child(ground["node"])
	main.world.items[at] = ground
	main.world._pickup(ground)
	await main._wait(0.4)
	check(UI.stack.size() == 1, "full pickup opens one live confirmation")
	if opts.has("shots") and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		main._save_shot(String(opts["shots"]) + "_pickup.png")
	await main._press("ui_cancel")
	await main._wait(0.2)
	check(UI.stack.is_empty() and main.world.items.has(at), "B declines a pickup directly")
	print("BAG LIMIT DONE: %d problem(s)" % bad)


func tap(at: Vector2) -> void:
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
	await main._wait(0.12)
