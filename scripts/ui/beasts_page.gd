extends Node
## A single roster beside the live ring. Placement is tentative until A confirms.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Ring = preload("res://scripts/core/ring.gd")
const PixelArt = preload("res://scripts/gfx/pixel_art.gd")
const RingPreview = preload("res://scripts/ui/battle_ring_preview.gd")

var book
var preview: Control
var heading: Label
var slots_label: Label
var hint: Label
var details: Button
var store_button: Button
var ring_badges: Dictionary = {}
var beasts: Array = []
var picked = null
var focused = null
## A tentative ring slot; storage is a separate action.
var destination := -1
var _turn: Tween


func setup(owner_book) -> Node:
	book = owner_book
	return self


func _ready() -> void:
	GameState.fix_ring()
	book._make_list(book.left_box, "Beasts %d" % (GameState.party.size() + GameState.storage.size()))
	book._add_row({"text": "Default element", "right": Ring.side_element(GameState.starting_ring_side()).capitalize(), "right_font": 32})
	beasts = GameState.party.duplicate() + GameState.storage.duplicate()
	for beast in beasts:
		book._add_row({"text": beast.nickname, "right": _status(beast), "right_width": 156,
			"icon": PixelArt.beast_texture(beast.genes), "beast": beast})
		var badge := RingBadge.new()
		badge.beast = beast
		badge.button = book.row_buttons.back()
		badge.button.add_child(badge)
		ring_badges[beast] = badge
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
	details.text = "Details"
	details.tooltip_text = "Beast summary, moves and gear"
	details.custom_minimum_size = Vector2(128, UIKit.row_h())
	UIKit.plate_button(details)
	details.pressed.connect(_show_details)
	top.add_child(details)
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
	hint = UIKit.label("", 24)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	book.right_box.add_child(hint)
	_refresh_ring()
	_focus_row(clampi(book.focus_row, 0, book.rows.size() - 1))


func _status(beast) -> String:
	return "Lv %d%s" % [beast.level, " · KO" if beast.hp <= 0 else ""]


func _focus_row(index: int) -> void:
	if picked != null:
		book.mode = "ring_place"
		return
	focused = book.rows[index].get("beast", null)
	details.disabled = focused == null
	details.visible = focused != null
	store_button.visible = false
	if focused != null:
		heading.visible = true
		heading.text = "%s · %s" % [focused.nickname, Ring.slot_name(focused.slot) if GameState.party.has(focused) else "Storage"]
		hint.text = "A: Choose a ring spot"
	else:
		heading.visible = false
		hint.text = "◄ / ►: Change default element" if index == 0 else "An egg. Beast Centers can hatch it."


func activate(index: int) -> bool:
	(book.row_buttons[index] as Control).grab_focus()
	if index == 0:
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
	# Finish a default-element turn before calculating any preview destinations.
	if _turn != null and _turn.is_running():
		_turn.kill()
	preview.facing = 0.0
	picked = beast
	focused = beast
	book.mode = "ring_place"
	details.disabled = false
	destination = int(beast.slot) if GameState.party.has(beast) else -1
	if destination < 0:
		for slot in Ring.legal_slots(beast):
			destination = slot
			break
	Sfx.play("confirm")
	_show_destination()
	return true


func _allowed(slot: int) -> bool:
	if slot < 0:
		return false
	return (GameState.party.has(picked) and int(picked.slot) == slot) or GameState.ring_move_reason(picked, {"slot": slot}) == ""


func move_destination(dir: int) -> void:
	for step in range(1, 9):
		var next := posmod(maxi(destination, 0) + step * dir, 8)
		if Ring.can_hold(picked, next):
			destination = next
			Sfx.play("select")
			_show_destination()
			return


func _show_destination() -> void:
	heading.visible = true
	store_button.visible = GameState.party.has(picked)
	store_button.disabled = GameState.party.size() <= 1
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
	if not _allowed(destination):
		Sfx.play("error")
		hint.text = GameState.ring_move_reason(picked, {"slot": destination})
		return
	if not GameState.party.has(picked) or int(picked.slot) != destination:
		var target := {"slot": destination}
		var reason := GameState.ring_move(picked, target)
		if reason != "":
			Sfx.play("error")
			hint.text = reason
			return
	Sfx.play("pickup")
	picked = null
	book.mode = "list"
	_refresh_statuses()
	_refresh_ring()
	_focus_row(book.focus_row)


func _refresh_statuses() -> void:
	for index in range(1, beasts.size() + 1):
		var beast = book.rows[index]["beast"]
		book.rows[index]["right"] = _status(beast)
		(book.row_buttons[index].get_child(0) as Label).text = _status(beast)
		ring_badges[beast].visible = GameState.party.has(beast)
		ring_badges[beast].queue_redraw()


func store_selected() -> void:
	if picked == null or not GameState.party.has(picked):
		return
	var reason := GameState.ring_move(picked, {"store": GameState.storage.size()})
	if reason != "":
		Sfx.play("error")
		hint.text = reason
		return
	_cancel()
	_refresh_statuses()


func _cancel() -> void:
	if picked == null:
		return
	picked = null
	book.mode = "list"
	_refresh_ring()
	Sfx.play("back")
	_focus_row(book.focus_row)


func _refresh_ring() -> void:
	preview.clear_placement()
	preview.set_ring(GameState.ring(), GameState.starting_ring_side())
	slots_label.text = "%d / %d slots used" % [GameState.ring().size(), GameState.party_max()]
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
	if (picked != null or index == 0) and on_input(event):
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
	if book.mode == "list" and book.focus_row == 0:
		if event.is_action("ui_left") or event.is_action("ui_right"):
			turn_default(-1 if event.is_action("ui_left") else 1)
			return true
	return false


func _show_details() -> void:
	var beast = focused
	if beast == null:
		return
	_cancel()
	if GameState.party.has(beast):
		await Menus.beast_options(beast)
	else:
		await UI.show_beast(beast)
	if is_instance_valid(book) and is_inside_tree():
		book._keep_row = book.focus_row
		book._open_tab(book.tab)


## A monochrome ring of eight pads beside the name, with no extra focus/tap target.
class RingBadge extends Control:
	const UIKit = preload("res://scripts/ui/ui_kit.gd")
	var beast
	var button: Button

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = GameState.party.has(beast)
		tooltip_text = "In the battle ring"
		button.draw.connect(queue_redraw)
		button.resized.connect(_place)
		_place()

	func _place() -> void:
		var font := button.get_theme_font("font")
		var text_width := font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x
		var name_left := 22.0 + minf(button.icon.get_width(), 44.0) + button.get_theme_constant("h_separation")
		position = Vector2(minf(name_left + text_width + 12.0, button.size.x - 148.0), (button.size.y - 32.0) / 2.0)
		size = Vector2(32, 32)

	func _draw() -> void:
		if not GameState.party.has(beast):
			return
		var lit := button.has_focus() or button.get_draw_mode() != BaseButton.DRAW_NORMAL
		var color := UIKit.LIGHT if lit else UIKit.ACCENT
		draw_arc(size / 2.0, 10.0, 0, TAU, 48, color, 1.8, true)
		for index in 8:
			var angle := TAU * index / 8.0
			draw_circle(size / 2.0 + Vector2(cos(angle), sin(angle)) * 10.0, 2.8, color, true, -1, true)
