extends RefCounted
## Isolated storage, phone, timer, arrival and live list-input regression scenario.
const Courier = preload("res://scripts/core/sky_courier.gd")
const Stacks = preload("res://scripts/core/item_stacks.gd")
const Screen = preload("res://scripts/ui/locker_screen.gd")
const UIKit = preload("res://scripts/ui/ui_kit.gd")
var main: Node
var bad := 0
var opts: Dictionary

class PointerFence extends Node:
	# A desktop mouse moving during an injected touch must not cancel that scripted gesture.
	func _input(ev: InputEvent) -> void:
		if ev is InputEventMouseMotion:
			get_viewport().set_input_as_handled()

func check(ok: bool, message: String) -> void:
	if not ok:
		bad += 1
	print("%s %s" % ["ok" if ok else "FAIL", message])

func shot(suffix: String) -> void:
	if opts.has("shots") and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		main._save_shot(String(opts.shots) + "_" + suffix + ".png")

func screen(kind := "desk") -> Control:
	var s := Screen.new()
	s.mode = kind
	UI.push(s)
	return s

func tap(target) -> void:
	for frame in 3:
		await main.get_tree().process_frame
	var at: Vector2 = target.get_global_rect().get_center() if target is Control else target
	var fence := PointerFence.new()
	main.add_child(fence)
	# Use genuine touch events in touch runs, with enough time for the new rows to lay out.
	if not UIKit.touch_ui():
		await main._tap_at(at)
	else:
		for down in [true, false]:
			var ev := InputEventScreenTouch.new()
			ev.index = 0
			ev.position = at * Vector2(main.get_window().size) / main.get_viewport().get_visible_rect().size
			ev.pressed = down
			Input.parse_input_event(ev)
			await main.get_tree().process_frame
	fence.queue_free()
	await main._wait(0.25)

func press_a() -> void:
	if not UIKit.touch_ui():
		await main._press("ui_accept")
		return
	var button: TouchScreenButton = UI.controls._buttons["a"]
	await tap(button.get_global_transform_with_canvas() * (button.texture_normal.get_size() / 2.0))

func run(root: Node, options: Dictionary) -> void:
	main = root
	opts = options
	if DisplayServer.get_name() != "headless":
		main.get_window().grab_focus()
	check(GameState.save_dir().begins_with("res://build/"), "isolated save directory")
	if bad > 0:
		return
	if opts.get("pose_only", "0") == "1":
		UI.auto = true
		await main._go("caccoon", "start")
		main.world.frozen = true
		await main._wait(3.3)
		GameState.inventory = {}
		GameState.locker = {"potion": 9}
		Courier.order(2, {"potion": 9})
		GameState.courier_left = 0.1
		UI.auto = false
		main.world.frozen = false
		await main._wait(1.2)
		await shot("mount_pose")
		await main._wait(3.3)
		await shot("rider_talking")
		UI.auto = true
		for modal in UI.stack.duplicate():
			modal.close(-1)
		await main._wait(1.5)
		print("SKY COURIER POSE DONE: %d problem(s)" % bad)
		return
	GameState.inventory = {"minor_potion": 216, "slingshot": 1}
	GameState.locker = {"potion": 432}
	check(Stacks.used(GameState.locker) == 48, "locker holds 48 nine-item stacks")
	check(Stacks.move(GameState.inventory, GameState.locker, "minor_potion", 9, 48) == 0, "full locker rejects a new stack")
	check(Stacks.move(GameState.locker, GameState.inventory, "potion", 9, 24) == 0, "full bag rejects a delivery")
	GameState.locker = {"potion": 18, "spirit_drop": 12}
	check(Courier.order(2, {"potion": 18}), "delivery reserves selected stacks")
	check(int(Courier.available().get("potion", 0)) == 0 and GameState.locker.potion == 18, "reserved stock stays safe in the locker")
	check(Courier.order(2, {"spirit_drop": 9}) and Courier.available().potion == 18, "replacement releases the earlier order")
	check(not Courier.order(2, {"potion": 109}), "overlarge or unavailable loads rejected")
	Courier.receive_fitting()
	check(GameState.courier_request.items.spirit_drop == 9, "full bag leaves undelivered stock reserved")
	GameState.remove_item("minor_potion", 9)
	check(Courier.receive("spirit_drop", 3) == 3, "partial delivery uses a freed bag slot")
	check(Courier.receive("spirit_drop", 6) == 6, "delivery fills the partial stack")
	check(GameState.locker.spirit_drop == 3, "only delivered quantities leave locker")
	GameState.courier_request = {}
	GameState.gold = 19
	check(not Courier.pickup({"spirit_drop": 9}) and GameState.item_count("spirit_drop") == 9, "poor pickup preserves items and gold")
	GameState.gold = 20
	check(Courier.pickup({"spirit_drop": 9}) and GameState.gold == 0, "pickup stores a load for exactly 20 gold")
	check(not Courier.pickup({"minor_potion": 117}), "pickup cannot exceed 12 stacks")
	Courier.order(3, {"potion": 9})
	GameState.courier_left = 11.5
	check(GameState.save_game(0) and GameState.load_game(0), "save and load locker and pending request")
	check(GameState.locker.potion == 18 and GameState.courier_request.items.potion == 9 and is_equal_approx(GameState.courier_left, 11.5), "reservation and remaining timer survive saving")
	GameState.courier_request = {}
	UI.auto = true
	await main._go("caccoon", "start")
	UI.auto = false
	main.world.frozen = true
	if opts.has("shots"):
		await main._wait(3.3)
	GameState.inventory = {"minor_potion": 18, "spirit_drop": 9}
	GameState.locker = {"potion": 108, "honey_cake": 9}
	var s := screen()
	await main._wait(0.4)
	check(s.lists.size() == 2 and s.entries[0].size() == 3, "two lists split quantities into stacks")
	for menu in s.lists:
		for button in menu.buttons:
			check(button.size.y >= UIKit.row_h(), "full-size stack row")
	await main._press("ui_accept")
	await main._wait(0.2)
	check(GameState.item_count("minor_potion") == 17 and GameState.locker.minor_potion == 1, "one A moves exactly one item")
	check(s.entries[0][0].count == 8 and s.entries[0][1].count == 9, "the selected stack counts down without repacking it")
	for i in 8:
		await press_a()
		await main._wait(0.04)
	check(GameState.item_count("minor_potion") == 9 and GameState.locker.minor_potion == 9, "nine separate A presses transfer one whole stack")
	check(UI.stack.size() == 1 and s.active == 0, "A transfers stay on the same screen and source list")
	await main._press("ui_right")
	await main._wait(0.2)
	check(s.active == 1, "keyboard changes list")
	await main._press("ui_left")
	await tap(s.lists[0].buttons[1])
	check(GameState.item_count("spirit_drop") == 8 and GameState.locker.spirit_drop == 1, "a row tap transfers exactly one item")
	for gem in UIKit.ACCENT_ORDER:
		UIKit.set_accent(gem)
		UI.root.theme = UIKit.make_theme()
		UI.controls.refresh()
		s._refresh()
		await main._wait(0.2)
		await shot("locker_" + gem)
	# Real shared rail buttons must move the long list, on touch as well as desktop.
	check(s.lists[1]._rail.enabled, "shared scroll rail enabled on both input layouts")
	await tap(s.lists[1]._rail._down)
	await main._wait(0.4)
	check(s.lists[1]._scroll.scroll_vertical > 0, "scroll button moves locker list")
	s.close({})
	await main._wait(0.25)
	GameState.inventory = {"minor_potion": 9}
	GameState.locker = {"potion": 117}
	s = screen("order")
	await main._wait(0.25)
	# Seed a nearly full request, then exercise its actual last accepted and rejected A presses.
	s.selected = {"potion": 107}
	s._refresh()
	await main._wait(0.2)
	await main._press("ui_accept")
	await main._wait(0.1)
	await main._press("ui_accept")
	await main._wait(0.1)
	check(Stacks.used(s.selected) == 12 and int(s.selected.get("potion", 0)) == 108, "call picker stops at twelve stacks (%d selected)" % Stacks.used(s.selected))
	await shot("order")
	s.close({})
	await main._wait(0.25)
	GameState.inventory = {"minor_potion": 216}
	GameState.locker = {"potion": 9}
	Courier.order(2, {"potion": 9})
	s = screen("receive")
	await main._wait(0.25)
	await shot("full_bag")
	await tap(s.lists[0].buttons[0])
	for i in 8:
		await press_a()
		await main._wait(0.04)
	check(GameState.locker.get("minor_potion", 0) == 9, "overflow screen hands a bag stack back to storage")
	await tap(s.lists[1].buttons[0])
	for i in 8:
		await press_a()
		await main._wait(0.04)
	check(GameState.item_count("potion") == 9 and GameState.courier_request.items.is_empty(), "overflow screen fills the freed slot")
	s.active = 0
	s._focus_row(0)
	UI.auto = true
	UI.auto_answers = [0]
	await tap(s.action_buttons[0])
	await main._wait(0.2)
	check(GameState.item_count("minor_potion") == 198, "drop removes exactly one confirmed stack")
	UI.auto = false
	s.close({})
	GameState.courier_request = {}
	await main._wait(0.25)
	# The employee's actual pickup screen commits and charges only after Done.
	GameState.inventory = {"minor_potion": 9}
	GameState.locker = {}
	GameState.gold = 20
	Courier.order(1)
	Courier.visit(main.world, null)
	await main._wait(0.25)
	s = UI.stack.back()
	await tap(s.lists[0].buttons[0])
	await main._wait(0.1)
	check(GameState.gold == 20 and GameState.item_count("minor_potion") == 9, "pickup selection is staged until Done")
	UI.auto = true
	await tap(s.action_buttons.back())
	await main._wait(0.25)
	check(GameState.gold == 0 and GameState.locker.get("minor_potion", 0) == 1 and GameState.item_count("minor_potion") == 8, "employee stores selected pickup for twenty gold")
	GameState.gold = 5
	UI.auto_answers = [2, 1]
	await main.Phone.call_home(main.world, main.Phone.FEE)
	check(GameState.gold == 0 and GameState.courier_request.service == 1, "company is the third contact and a payphone charges five coins")
	GameState.courier_request = {}
	UI.auto = false
	GameState.inventory = {"minor_potion": 1}
	GameState.locker = {}
	s = screen()
	await main._wait(0.3)
	await main._press("ui_accept")
	await main._wait(0.2)
	check(s.active == 0 and GameState.item_count("minor_potion") == 0 and GameState.locker.minor_potion == 1, "an emptied source never reverses transfer direction")
	s.close({})
	await main._wait(0.2)
	GameState.locker = {}
	s = screen()
	await main._wait(0.3)
	check(s.entries[0].is_empty() and s.entries[1].is_empty(), "empty lists open safely")
	await shot("empty")
	await main._press("ui_cancel")
	await main._wait(0.3)
	if opts.get("ui_only", "0") == "1":
		print("SKY COURIER UI DONE: %d problem(s)" % bad)
		return
	# Timers pause in each modal/control state and on enclosed maps.
	Courier.order(0)
	GameState.courier_left = 1.0
	main.world._courier_tick(0.5)
	check(is_equal_approx(GameState.courier_left, 1.0), "frozen control pauses timer")
	main.world.frozen = false
	s = screen()
	main.world._courier_tick(0.5)
	check(is_equal_approx(GameState.courier_left, 1.0), "menus pause timer")
	s.close({})
	await main._wait(0.3)
	main.world.busy = true
	var before: float = GameState.courier_left
	main.world._courier_tick(0.5)
	check(GameState.courier_left == before, "dialogue/scripted interaction pauses timer")
	main.world.busy = false
	main.in_battle = true
	main.world._courier_tick(0.5)
	check(GameState.courier_left == before, "battles pause timer")
	main.in_battle = false
	main.world.interior = true
	main.world._courier_tick(0.5)
	check(GameState.courier_left == before, "indoors pauses timer")
	main.world.interior = false
	var kind: String = main.world.map.kind
	main.world.map.kind = "temple"
	check(not main.world.courier_open_sky(), "temples never qualify")
	main.world.map.kind = "dungeon"
	check(not main.world.courier_open_sky(), "dungeons never qualify")
	main.world.map.kind = kind
	# A ready bird waits if every adjacent tile is blocked, then waits through a started step.
	var MapGen = preload("res://scripts/world/map_gen.gd")
	var saved := {}
	for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
		var p: Vector2i = main.world.player_pos + d
		saved[p] = MapGen.get_t(main.world.map, p.x, p.y)
		MapGen.set_t(main.world.map, p.x, p.y, MapGen.TREE)
	GameState.courier_left = 0.0
	main.world._courier_tick(0.1)
	check(not is_instance_valid(main.world.courier_bird), "blocked adjacent tiles defer landing")
	for p in saved:
		MapGen.set_t(main.world.map, p.x, p.y, saved[p])
	main.world.moving = true
	main.world._courier_tick(0.1)
	check(not is_instance_valid(main.world.courier_bird), "landing waits until the started step finishes")
	main.world.moving = false
	GameState.courier_request = {}
	# Each actual visit, with a shortened outdoor timer. Ride and combined ride use the shared flight.
	for service in 4:
		UI.auto = true
		await main._go("caccoon", "start")
		if opts.has("shots"):
			main.world.frozen = true
			await main._wait(3.3)
		GameState.visited = ["caccoon", "tidewater"]
		GameState.inventory = {}
		GameState.locker = {"potion": 9}
		GameState.gold = 500
		UI.auto_answers = [0]
		Courier.order(service, {"potion": 9} if service in [2, 3] else {})
		GameState.courier_left = 0.1
		if service == 2 and opts.has("shots"):
			UI.auto = false
		main.world.frozen = false
		await main._wait(0.2)
		check(main.world.frozen and is_instance_valid(main.world.courier_bird), "service %d swoops and freezes control" % service)
		await main._wait(1.3)
		if is_instance_valid(main.world.courier_employee):
			var rider: Node3D = main.world.courier_employee
			var bird: Node3D = main.world.courier_bird
			check(main.world.VPer.pose_of(rider) == "sit", "employee stays seated during service %d" % service)
			var forward_person: Vector3 = rider.get_node("Body").global_basis.z.normalized()
			var forward_bird: Vector3 = bird.global_basis.x.normalized()
			var head_pose: Transform3D = bird.skel.get_bone_global_pose(bird.skel.find_bone("head"))
			check(is_equal_approx(bird.skel.get_bone_pose_rotation(0).get_euler().z, -PI / 4.0), "mount body leans forty-five degrees")
			check(absf(head_pose.basis.x.normalized().y) < 0.01, "mount face stays level with the ground")
			check(forward_person.dot(forward_bird) > 0.99, "rider and bird face the same direction during service %d" % service)
		await shot("arrival_%d" % service)
		if service == 2 and opts.has("shots"):
			await main._wait(2.5)
			await shot("rider_talking")
			UI.auto = true
			for modal in UI.stack.duplicate():
				modal.close(-1)
		await main._wait(4.5)
		for tick in 200:
			if main._pending_goto.is_empty() and not main._transitioning and not main.world.busy:
				break
			await main._wait(0.1)
		check(GameState.courier_request.is_empty(), "service %d finishes request" % service)
		if service in [0, 3]:
			check(main.world.map_id == "tidewater" and GameState.gold == 500 - Places.FLIGHT_COST * 2, "service %d rides for double fare" % service)
		if service in [2, 3]:
			check(GameState.item_count("potion") == 9, "service %d delivers before departure" % service)
	# No gold still gets delivery, and a full bag returns leftovers to the locker.
	await main._go("caccoon", "start")
	GameState.inventory = {"minor_potion": 216}
	GameState.locker = {"potion": 9}
	GameState.gold = 0
	Courier.order(3, {"potion": 9})
	await Courier.visit(main.world, null)
	check(GameState.locker.potion == 9 and GameState.item_count("potion") == 0 and main.world.map_id == "caccoon", "full bag and no gold return delivery without a ride")
	GameState.inventory = {}
	Courier.order(3, {"potion": 9})
	await Courier.visit(main.world, null)
	check(GameState.item_count("potion") == 9 and GameState.gold == 0, "no gold never blocks delivery")
	Courier.order(1)
	await Courier.visit(main.world, null)
	check(GameState.courier_request.is_empty() and GameState.gold == 0, "unaffordable pickup leaves without charge")
	UI.auto = false
	print("SKY COURIER DONE: %d problem(s)" % bad)
