extends "res://scripts/ui/modal.gd"
## Two reusable ListMenus. Each A press or row tap transfers one item from the selected stack.
const UIKit = preload("res://scripts/ui/ui_kit.gd")
const ListMenu = preload("res://scripts/ui/list_menu.gd")
const ItemDB = preload("res://scripts/data/item_db.gd")
const Stacks = preload("res://scripts/core/item_stacks.gd")
const Courier = preload("res://scripts/core/sky_courier.gd")

var mode := "desk"
var selected: Dictionary = {}
var lists: Array = []
var entries: Array = []
var active := 0
var body: VBoxContainer
var columns: HBoxContainer
var action_buttons: Array[Button] = []
## All manual moves are staged until Confirm; Cancel preserves the state from when the screen opened.
var _inventory: Dictionary = {}
var _locker: Dictionary = {}
var _pending: Dictionary = {}
## Items handed back stay visible on the bird until the visit ends.
var _returned: Dictionary = {}
## Keep the chosen chunk's countdown visible while the dictionary compacts identical items.
var _fragment: Dictionary = {}

static func open(kind := "desk") -> Dictionary:
	if UI.auto:
		await UI.get_tree().process_frame
		return {}
	var screen = load("res://scripts/ui/locker_screen.gd").new()
	screen.mode = kind
	UI.push(screen)
	var answer = await screen.done
	return answer if answer is Dictionary else {}

func _ready() -> void:
	_inventory = GameState.inventory.duplicate()
	_locker = GameState.locker.duplicate()
	_pending = GameState.courier_request.get("items", {}).duplicate()
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	add_child(body)
	var safe := UIKit.safe_rect(self)
	var width := minf(safe.size.x - 64.0, 1160.0)
	body.custom_minimum_size.x = width
	columns = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	body.add_child(columns)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	body.add_child(actions)
	for action in ["Confirm", "Cancel"]:
		var b := Button.new()
		b.text = action
		b.custom_minimum_size = Vector2(240, UIKit.row_h())
		UIKit.plate_button(b)
		actions.add_child(b)
		action_buttons.append(b)
		if action == "Confirm":
			b.pressed.connect(_confirm)
		else:
			b.pressed.connect(_cancel)
	_refresh()
	UIKit.place(body, "center", Vector2(24, 24))
	var shift := safe.get_center() - get_viewport_rect().get_center() - Vector2(0, UI.bottom_reserve() / 2.0)
	body.position += shift

func _stock() -> Array:
	if mode == "desk":
		return [_inventory, Courier.available(_locker, _pending)]
	if mode == "receive":
		var bird := _pending.duplicate()
		for id in _returned:
			bird[id] = int(bird.get(id, 0)) + int(_returned[id])
		return [_inventory, bird]
	var source: Dictionary = (_locker if mode == "order" else _inventory).duplicate()
	for id in selected:
		source[id] = int(source[id]) - int(selected[id])
		if source[id] <= 0:
			source.erase(id)
	return [source, selected]

func _refresh(index := 0) -> void:
	for c in columns.get_children():
		columns.remove_child(c)
		c.queue_free()
	lists.clear()
	entries.clear()
	var stocks := _stock()
	var names := ["Inventory", "Locker"]
	var caps := [Courier.BAG_CAP, Courier.LOCKER_CAP]
	if mode in ["order", "pickup"]:
		names = ["Locker" if mode == "order" else "Inventory", "Bird"]
		caps = [Courier.LOCKER_CAP if mode == "order" else Courier.BAG_CAP, Courier.LOAD_CAP]
	elif mode == "receive":
		names[1] = "Bird"
		caps[1] = Courier.LOAD_CAP
	var rows := clampi(floori((UIKit.safe_rect(self).size.y - UI.bottom_reserve() - 220.0) / UIKit.row_h()), 2, 6)
	for side in 2:
		var data := Stacks.rows(stocks[side])
		if _fragment.get("side", -1) == side and int(stocks[side].get(_fragment.id, 0)) >= int(_fragment.count):
			var rest: Dictionary = stocks[side].duplicate()
			rest[_fragment.id] = int(rest[_fragment.id]) - int(_fragment.count)
			data = Stacks.rows(rest)
			data.insert(mini(int(_fragment.index), data.size()), {"id": _fragment.id, "count": _fragment.count})
		entries.append(data)
		var items := []
		for entry in data:
			items.append({"text": "%s ×%d" % [ItemDB.get_item(entry.id).get("name", entry.id), entry.count],
				"icon": UI.Glyphs.item(entry.id)})
		var menu := ListMenu.new()
		var used := Stacks.used(_locker) if mode == "desk" and side == 1 else Stacks.used(stocks[side])
		var title := "%s  %d/%d" % [names[side], used, caps[side]]
		if mode == "receive" and side == 1:
			title = "Bird  %d" % used
		menu.setup(title, items,
			{"embedded": true, "fixed_rows": true, "expand_icons": true, "icon_width": 48, "keep_anchor": true,
			"width": (body.custom_minimum_size.x - 12.0) / 2.0 - 40.0,
			"rows": rows, "on_pick": _pick.bind(side), "on_focus": _focus.bind(side)})
		menu.custom_minimum_size.x = (body.custom_minimum_size.x - 12.0) / 2.0
		menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(menu)
		menu.custom_minimum_size.y = menu._outer.get_combined_minimum_size().y
		lists.append(menu)
	_focus_row.call_deferred(index)

func _focus(_index: int, side: int) -> void:
	active = side

func _focus_row(index: int) -> void:
	if lists[active].buttons.is_empty():
		action_buttons[0].grab_focus()
		return
	if not lists[active].buttons.is_empty():
		var button: Button = lists[active].buttons[clampi(index, 0, lists[active].buttons.size() - 1)]
		button.grab_focus()
		lists[active]._scroll.ensure_control_visible.call_deferred(button)

func _pick(index: int, side: int) -> void:
	active = side
	_move(index, 1)

func _move(index: int, quantity: int) -> void:
	var id: String = entries[active][index].id
	var moved := 0
	if mode == "desk" or mode == "receive":
		if active == 0:
			moved = Stacks.move(_inventory, _locker, id, quantity, Courier.LOCKER_CAP)
			if mode == "receive" and moved > 0:
				_returned[id] = int(_returned.get(id, 0)) + moved
		elif mode == "receive":
			if int(_pending.get(id, 0)) > 0:
				moved = Courier.receive(id, quantity, _inventory, _locker, _pending)
			else:
				moved = Stacks.move(_locker, _inventory, id, mini(quantity, int(_returned.get(id, 0))), Courier.BAG_CAP)
				if moved > 0:
					_returned[id] -= moved
					if _returned[id] == 0:
						_returned.erase(id)
		else:
			moved = Stacks.move(_locker, _inventory, id, quantity, Courier.BAG_CAP)
	else:
		var stocks := _stock()
		if active == 0:
			moved = Stacks.move(stocks[0], selected, id, quantity, Courier.LOAD_CAP)
		else:
			moved = Stacks.move(selected, stocks[0], id, quantity, 100000)
	if moved == 0:
		Sfx.play("error")
		UI.toast("No room for that item.")
	else:
		var remaining := int(entries[active][index].count) - moved
		_fragment = {"id": id, "count": remaining, "side": active, "index": index} if remaining > 0 else {}
	_refresh(index)

func _confirm() -> void:
	if mode in ["desk", "receive"]:
		GameState.inventory.assign(_inventory)
		GameState.locker.assign(_locker)
		if mode == "receive" and not GameState.courier_request.is_empty():
			GameState.courier_request["items"] = _pending.duplicate()
	close(selected.duplicate())

func _cancel() -> void:
	close({})

func _input(ev: InputEvent) -> void:
	if closed or UI.stack.is_empty() or UI.stack.back() != self or not ev.is_pressed() or ev.is_echo():
		return
	var focus := get_viewport().gui_get_focus_owner()
	var on_action := focus in action_buttons
	if ev.is_action("ui_left") or ev.is_action("ui_right"):
		active = 1 - active
		_focus_row(0)
	elif on_action and ev.is_action("ui_up"):
		_focus_row(lists[active].buttons.size() - 1)
	elif on_action and not ev.is_action("ui_cancel"):
		return
	elif ev.is_action("ui_up") or ev.is_action("ui_down"):
		if ev.is_action("ui_down") and lists[active]._focus == lists[active].buttons.size() - 1:
			action_buttons[0].grab_focus()
		else:
			lists[active]._step_focus(-1 if ev.is_action("ui_up") else 1)
	elif ev.is_action("ui_cancel"):
		_cancel()
	else:
		return
	get_viewport().set_input_as_handled()
