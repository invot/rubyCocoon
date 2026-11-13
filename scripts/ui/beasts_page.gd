extends Node
## The book's Beasts page (Start → Beasts): the beasts you carry, which are the beasts on your battle ring, beside the
## live 3D ring. Each row shows a beast's level and, under its name, its HP and MP (one number when full). Focusing a
## beast lights it on the ring. A opens its actions in a bar under the ring: **Info** (its details; its moves are chosen
## when it learns a new one), **Move** (to another spot of the ring: ◄ / ► choose, A confirms, B cancels; placement
## is tentative until A), any field action it can do right now (**Fly**), and **Equip**.
## Storage mode (book_menu.storage_mode: the Beast Center's and the kennels' storage, the only places you change which
## beasts you carry) lists your carried and stored beasts in two sections: A picks one up, ◄ / ► choose its ring spot
## (trading places with whoever stands there) and **Store** sends a carried beast to storage, where it's healed.
## Storage is one for the whole land. The rules are GameState.ring_move_reason's.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Ring = preload("res://scripts/core/ring.gd")
const PixelArt = preload("res://scripts/gfx/pixel_art.gd")
const RingPreview = preload("res://scripts/ui/battle_ring_preview.gd")

var book
var storage_mode := false
var preview: Control
var heading: Label
var slots_label: Label
var hint: Label
var details: Button
var store_button: Button
## the actions bar under the ring (Info, Move, Fly, Equip) and its buttons, by action id
var actions_bar: HBoxContainer
var action_buttons: Dictionary = {}
## the beast whose actions are open, or null
var actions_for = null
var beasts: Array = []
var picked = null
var focused = null
## A tentative ring slot; storage is a separate action.
var destination := -1
var _turn: Tween
## the beast (and its action) to focus again once the page is rebuilt
static var _refocus = null
static var _refocus_action := ""


func setup(owner_book, storage := false) -> Node:
	book = owner_book
	storage_mode = storage
	return self


func _ready() -> void:
	GameState.fix_ring()
	if storage_mode:
		book._make_list(book.left_box, "Beast storage")
		book._add_row({"header": true, "text": "With you  %d / %d" % [GameState.party.size(), GameState.party_max()]})
		_add_beasts(GameState.party)
		book._add_row({"header": true, "text": "In storage  %d" % GameState.storage.size()})
		_add_beasts(GameState.storage)
	else:
		book._make_list(book.left_box, "Beasts %d / %d" % [GameState.party.size(), GameState.party_max()])
		book._add_row({"text": "Default element", "right": Ring.side_element(GameState.starting_ring_side()).capitalize(), "right_font": 32})
		_add_beasts(GameState.party)
		for egg in GameState.eggs:
			book._add_row({"text": GameState.egg_name(egg), "right": "Egg", "egg": egg})
	for index in book.row_buttons.size():
		var button: Button = book.row_buttons[index]
		button.gui_input.connect(_row_input.bind(index))
		button.focus_entered.connect(_focus_row.bind(index))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	book.right_box.add_child(top)
	var captions := VBoxContainer.new()
	captions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(captions)
	captions.add_child(book._h("Battle ring"))
	slots_label = UIKit.label("", 24)
	captions.add_child(slots_label)
	details = Button.new()
	details.text = "Info"
	details.tooltip_text = "Beast details and stats"
	details.custom_minimum_size = Vector2(110, UIKit.row_h())
	UIKit.plate_button(details)
	details.pressed.connect(_show_details)
	top.add_child(details)
	details.visible = false
	store_button = Button.new()
	store_button.text = "Store"
	store_button.custom_minimum_size = Vector2(110, UIKit.row_h())
	UIKit.plate_button(store_button)
	store_button.pressed.connect(store_selected)
	top.add_child(store_button)
	store_button.visible = false
	heading = UIKit.label("", 24)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	book.right_box.add_child(heading)
	preview = RingPreview.new()
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	book.right_box.add_child(preview)
	actions_bar = HBoxContainer.new()
	actions_bar.add_theme_constant_override("separation", 8)
	actions_bar.visible = false
	book.right_box.add_child(actions_bar)
	hint = UIKit.label("", 24)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	book.right_box.add_child(hint)
	_refresh_ring()
	var reopen := ""
	if _refocus != null:
		var at := _row_of(_refocus)
		if at >= 0:
			book._keep_row = at
			book.focus_row = at
			reopen = _refocus_action
		_refocus = null
		_refocus_action = ""
	if book.rows.is_empty():
		heading.visible = false
		hint.text = ""
		return
	var start := clampi(book._keep_row if book._keep_row >= 0 else book.focus_row, 0, book.rows.size() - 1)
	_focus_row(start)
	if reopen != "" and focused != null:
		_reopen_later(focused, reopen)


## After the book's own deferred focus on the row has run.
func _reopen_later(beast, action: String) -> void:
	await get_tree().process_frame
	if is_inside_tree() and picked == null:
		_open_actions(beast, action)


func _add_beasts(list: Array) -> void:
	for beast in list:
		book._add_row({"text": beast.nickname, "right": _status(beast), "right_width": 156, "sub": vitals(beast),
			"icon": PixelArt.beast_texture(beast.genes), "beast": beast})
		beasts.append(beast)


func _row_of(beast) -> int:
	for index in book.rows.size():
		if book.rows[index].get("beast", null) == beast:
			return index
	return -1


func _status(beast) -> String:
	return "Lv %d%s" % [beast.level, " · KO" if beast.hp <= 0 else ""]


## "HP 34/50   MP 20": what it has and its limit, or one number when it's full.
static func vitals(beast) -> String:
	var hp: int = maxi(0, beast.hp)
	var mp: int = maxi(0, beast.mp)
	var hp_text := "HP %d" % hp if hp >= beast.max_hp() else "HP %d/%d" % [hp, beast.max_hp()]
	var mp_text := "MP %d" % mp if mp >= beast.max_mp() else "MP %d/%d" % [mp, beast.max_mp()]
	return "%s   %s" % [hp_text, mp_text]


func _is_default_row(index: int) -> bool:
	return not storage_mode and index == 0


func _focus_row(index: int) -> void:
	if picked != null:
		book.mode = "ring_place"
		return
	if actions_for != null:
		_hide_actions()
	focused = book.rows[index].get("beast", null)
	details.visible = storage_mode and focused != null
	store_button.visible = false
	if focused != null:
		heading.visible = true
		heading.text = "%s · %s" % [focused.nickname, Ring.slot_name(focused.slot) if GameState.party.has(focused) else "Storage"]
		if GameState.party.has(focused):
			preview.show_placement(focused, int(focused.slot))
		else:
			preview.clear_placement()
		hint.text = "A: Choose a ring spot" if storage_mode else "A: Info, Move, Equip"
	else:
		preview.clear_placement()
		heading.visible = false
		hint.text = "◄ / ►: Change default element" if _is_default_row(index) else "An egg. Beast Centers can hatch it."


func activate(index: int) -> bool:
	(book.row_buttons[index] as Control).grab_focus()
	if _is_default_row(index):
		_cancel()
		turn_default(1)
		return true
	var beast = book.rows[index].get("beast", null)
	if beast == null:
		_cancel()
		_focus_row(index)
		return true
	if picked == beast:
		_confirm()
		return true
	if storage_mode:
		_pick(beast)
		return true
	if picked != null:
		_cancel(false)
	_open_actions(beast)
	return true


# ---------------------------------------------------------------- the actions bar
## The actions a beast has right now: Info, Move, its field actions (Fly) and Equip.
func actions_of(beast) -> Array:
	var out := [{"id": "info", "text": "Info"}, {"id": "move", "text": "Move"}]
	if Places.can_carry(beast) and book._can_fly() and GameState.visited.size() > 0:
		out.append({"id": "fly", "text": "Fly"})
	out.append({"id": "equip", "text": "Equip"})
	return out


func _open_actions(beast, focus_id := "") -> void:
	if not is_inside_tree() or not GameState.party.has(beast):
		return
	if actions_for == null and focus_id == "":
		Sfx.play("confirm")
	actions_for = beast
	focused = beast
	book.mode = "beast_actions"
	for child in actions_bar.get_children():
		actions_bar.remove_child(child)
		child.queue_free()
	action_buttons = {}
	var list := actions_of(beast)
	for action in list:
		var button := Button.new()
		button.text = action["text"]
		button.custom_minimum_size = Vector2(0, UIKit.row_h())
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIKit.plate_button(button)
		button.pressed.connect(_do_action.bind(action["id"]))
		actions_bar.add_child(button)
		action_buttons[action["id"]] = button
	var buttons: Array = actions_bar.get_children()
	for i in buttons.size():
		var button: Button = buttons[i]
		button.focus_neighbor_left = button.get_path_to(buttons[posmod(i - 1, buttons.size())])
		button.focus_neighbor_right = button.get_path_to(buttons[posmod(i + 1, buttons.size())])
		button.focus_neighbor_top = button.get_path_to(button)
		button.focus_neighbor_bottom = button.get_path_to(button)
		button.focus_next = button.focus_neighbor_right
		button.focus_previous = button.focus_neighbor_left
	actions_bar.visible = true
	heading.visible = true
	heading.text = "%s · %s" % [beast.nickname, Ring.slot_name(beast.slot)]
	preview.show_placement(beast, int(beast.slot))
	hint.text = "◄ / ►: Choose · A: Select · B: Back"
	var first: Button = action_buttons.get(focus_id, buttons[0])
	first.grab_focus()
	book.right_scroll.ensure_control_visible.call_deferred(actions_bar)


## Hides the actions bar (focus stays where it is).
func _hide_actions() -> void:
	actions_for = null
	if is_instance_valid(actions_bar):
		actions_bar.visible = false
	if book.mode == "beast_actions":
		book.mode = "list"


## B on the actions bar: back to the list, on the same beast.
func _close_actions() -> void:
	var beast = actions_for
	_hide_actions()
	Sfx.play("back")
	var at := _row_of(beast)
	if at >= 0:
		(book.row_buttons[at] as Control).grab_focus()
		_focus_row(at)


func _do_action(id: String) -> void:
	var beast = actions_for
	if beast == null:
		return
	match id:
		"move":
			_hide_actions()
			_pick(beast)
			return
		"info":
			Sfx.play("confirm")
			await UI.show_beast(beast)
		"equip":
			Sfx.play("confirm")
			await Menus.equip_beast(beast)
		"fly":
			Sfx.play("confirm")
			if await Places.fly_menu(GameState.map_id, 0, ""):
				if is_instance_valid(book) and not book.closed:
					book.close()
				return
	# (only its row's numbers can have changed: no need to build the ring and its models again)
	if not is_instance_valid(book) or book.closed or not is_inside_tree():
		return
	_refresh_statuses()
	_open_actions(beast, id)


## Builds the page again (stats, equipment and sections may have changed), focusing `beast` and reopening its action.
func _rebuild(beast, action := "") -> void:
	if not is_instance_valid(book) or book.closed or not is_inside_tree():
		return
	_refocus = beast
	_refocus_action = action
	book._keep_row = _row_of(beast)
	book.mode = "list"
	book._open_tab(book.tab)


# ---------------------------------------------------------------- placing a beast on the ring
func _pick(beast) -> void:
	# Finish a default-element turn before calculating any preview destinations.
	if _turn != null and _turn.is_running():
		_turn.kill()
	preview.facing = 0.0
	picked = beast
	focused = beast
	book.mode = "ring_place"
	var at := _row_of(beast)
	if at >= 0 and not (book.row_buttons[at] as Control).has_focus():
		(book.row_buttons[at] as Control).grab_focus()
	destination = int(beast.slot) if GameState.party.has(beast) else -1
	if destination < 0:
		for slot in Ring.legal_slots(beast):
			destination = slot
			break
	Sfx.play("confirm")
	_show_destination()


## Where ◄ / ► can take the picked beast: ring spots it can stand on and, in storage mode for a carried beast, storage
## (STORE_STOP), so Store also works with the d-pad.
const STORE_STOP := -2


func _stops() -> Array:
	var out := []
	for slot in Ring.SLOTS:
		if Ring.can_hold(picked, slot):
			out.append(slot)
	if storage_mode and GameState.party.has(picked):
		out.append(STORE_STOP)
	return out


func _allowed(slot: int) -> bool:
	if slot < 0:
		return false
	return (GameState.party.has(picked) and int(picked.slot) == slot) or GameState.ring_move_reason(picked, {"slot": slot}) == ""


func move_destination(dir: int) -> void:
	var stops := _stops()
	if stops.is_empty():
		return
	var at := stops.find(destination)
	if at < 0:
		# (from an empty spot list, step to the nearest stop in that direction)
		at = 0 if dir > 0 else stops.size() - 1
		dir = 0
	var next: int = stops[posmod(at + dir, stops.size())]
	if next == destination and stops.size() > 1:
		return
	destination = next
	Sfx.play("select")
	_show_destination()


func _show_destination() -> void:
	heading.visible = true
	details.visible = storage_mode
	store_button.visible = storage_mode and GameState.party.has(picked)
	store_button.disabled = GameState.party.size() <= 1
	if destination == STORE_STOP:
		heading.text = "%s → Storage" % picked.nickname
		hint.text = "◄ / ►: Choose spot\nA: Store · B: Cancel"
		preview.show_placement(picked, int(picked.slot))
		return
	if destination < 0:
		heading.text = "%s · No available ring spot" % picked.nickname
	else:
		var place := Ring.slot_name(destination)
		var occupant = GameState.beast_at(destination)
		heading.text = "%s → %s" % [picked.nickname, place]
		if occupant != null and occupant != picked:
			heading.text += "\nSwap with %s" % occupant.nickname
	hint.text = "◄ / ►: Choose spot\nA: Confirm · B: Cancel"
	preview.show_placement(picked, destination)


func _confirm() -> void:
	if destination == STORE_STOP:
		if GameState.party.size() <= 1:
			Sfx.play("error")
			hint.text = "You need to keep at least one beast with you."
			return
		store_selected()
		return
	if not _allowed(destination):
		Sfx.play("error")
		hint.text = GameState.ring_move_reason(picked, {"slot": destination})
		return
	var stored_before: Array = GameState.storage.duplicate()
	if not GameState.party.has(picked) or int(picked.slot) != destination:
		var reason := GameState.ring_move(picked, {"slot": destination})
		if reason != "":
			Sfx.play("error")
			hint.text = reason
			return
	_heal_new_arrivals(stored_before)
	Sfx.play("pickup")
	var beast = picked
	picked = null
	book.mode = "list"
	if storage_mode:
		_rebuild(beast)
		return
	_refresh_statuses()
	_refresh_ring()
	_focus_row(book.focus_row)


## Beasts that have just gone into storage rest there and are healed.
func _heal_new_arrivals(stored_before: Array) -> void:
	for beast in GameState.storage:
		if not stored_before.has(beast):
			beast.heal_full()


func _refresh_statuses() -> void:
	for index in book.rows.size():
		var beast = book.rows[index].get("beast", null)
		if beast == null:
			continue
		book.rows[index]["right"] = _status(beast)
		(book.row_buttons[index].get_child(0) as Label).text = _status(beast)
		book.rows[index]["sub"] = vitals(beast)
		if book.rows[index].has("sub_label"):
			(book.rows[index]["sub_label"] as Label).text = vitals(beast)


func store_selected() -> void:
	if not storage_mode or picked == null or not GameState.party.has(picked):
		return
	var beast = picked
	var reason := GameState.ring_move(beast, {"store": GameState.storage.size()})
	if reason != "":
		Sfx.play("error")
		hint.text = reason
		return
	beast.heal_full()
	Sfx.play("pickup")
	UI.toast("%s was stored." % beast.nickname, beast)
	picked = null
	book.mode = "list"
	_rebuild(beast)


func _cancel(sound := true) -> void:
	if picked == null:
		return
	var beast = picked
	picked = null
	book.mode = "list"
	_refresh_ring()
	if sound:
		Sfx.play("back")
	_focus_row(book.focus_row)
	# in the book, B from placing goes back to the beast's actions, on Move
	if sound and not storage_mode and GameState.party.has(beast):
		_open_actions(beast, "move")


func _refresh_ring() -> void:
	preview.clear_placement()
	preview.set_ring(GameState.ring(), GameState.starting_ring_side())
	slots_label.text = "%d / %d slots used" % [GameState.ring().size(), GameState.party_max()]
	if not storage_mode and not book.row_buttons.is_empty():
		(book.row_buttons[0].get_child(0) as Label).text = Ring.side_element(GameState.starting_ring_side()).capitalize()


func turn_default(dir: int) -> void:
	var before := GameState.starting_ring_side()
	if not GameState.turn_starting_ring(dir):
		return
	if _turn != null and _turn.is_running():
		_turn.kill()
	var after := GameState.starting_ring_side()
	var steps := posmod((after - before) * dir, 4) * dir
	var angle: float = preview.facing + steps * PI / 2.0
	_refresh_ring()
	preview.facing = angle
	_turn = create_tween()
	_turn.tween_property(preview, "facing", 0.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	Sfx.play("toggle")
	_focus_row(0)


func _row_input(event: InputEvent, index: int) -> void:
	if not event.is_pressed():
		return
	if (picked != null or _is_default_row(index)) and on_input(event):
		(book.row_buttons[index] as Control).accept_event()


func on_input(event: InputEvent) -> bool:
	if picked != null:
		if event.is_action("ui_cancel"):
			_cancel()
		elif event.is_action("ui_left") or event.is_action("ui_right"):
			move_destination(-1 if event.is_action("ui_left") else 1)
		elif event.is_action("ui_accept") and not event.is_echo():
			_confirm()
		elif not (event.is_action("ui_up") or event.is_action("ui_down")):
			return false
		return true
	if actions_for != null:
		if event.is_action("ui_cancel"):
			_close_actions()
			return true
		if event.is_action("ui_accept") and not event.is_echo():
			# (the bar lost focus to a click elsewhere: A acts on its first button)
			var focus_owner: Control = book.get_viewport().gui_get_focus_owner()
			if not action_buttons.values().has(focus_owner):
				(action_buttons.values()[0] as Button).grab_focus()
			return true
		# ◄ / ► move along the bar (its buttons' focus neighbours), never to another tab
		return event.is_action("ui_left") or event.is_action("ui_right") or event.is_action("ui_up") or event.is_action("ui_down")
	if storage_mode and (event.is_action("ui_left") or event.is_action("ui_right")):
		return true
	if book.mode == "list" and _is_default_row(book.focus_row):
		if event.is_action("ui_left") or event.is_action("ui_right"):
			turn_default(-1 if event.is_action("ui_left") else 1)
			return true
	return false


func _show_details() -> void:
	var beast = focused
	if beast == null:
		return
	_cancel(false)
	await UI.show_beast(beast)
	_rebuild(beast)
