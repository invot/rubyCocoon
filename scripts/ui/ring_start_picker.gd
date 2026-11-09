extends VBoxContainer
## The book's starting-side arrows, stacked label and rotating shared ring diagram.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Ring = preload("res://scripts/core/ring.gd")
const RingView = preload("res://scripts/ui/ring_view.gd")

var left: Button
var right: Button
var element: Label
var diagram: Control
var return_focus: Control
var _turn: Tween


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	add_child(top)
	left = _arrow(-1)
	top.add_child(left)
	var caption := VBoxContainer.new()
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	caption.add_theme_constant_override("separation", 0)
	top.add_child(caption)
	var title := UIKit.label("Starting side", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_child(title)
	element = UIKit.label("", 32)
	element.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_child(element)
	right = _arrow(1)
	top.add_child(right)
	diagram = RingView.new(160.0)
	diagram.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diagram.size_flags_vertical = Control.SIZE_EXPAND_FILL
	diagram.shield = GameState.shield
	diagram.max_shield = GameState.max_shield
	add_child(diagram)
	# RingView's element initials sit just outside its ring; leave them clear of the page frame.
	var foot := Control.new()
	foot.custom_minimum_size.y = 12
	add_child(foot)
	_refresh()
	Prefs.changed.connect(_restyle)


func _arrow(dir: int) -> Button:
	var button := Button.new()
	button.text = "◄" if dir < 0 else "►"
	button.tooltip_text = "Previous starting side" if dir < 0 else "Next starting side"
	button.custom_minimum_size = Vector2(UIKit.row_h(), UIKit.row_h())
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(turn.bind(dir))
	button.gui_input.connect(handle_input)
	_style_arrow(button)
	return button


func _style_arrow(button: Button) -> void:
	UIKit.plate_button(button, Vector4.ZERO)
	for state in ["hover", "focus"]:
		button.add_theme_stylebox_override(state, UIKit.chip(UIKit.ACCENT, UIKit.BORDER, 12.0, Vector4.ZERO))


func _restyle() -> void:
	for button in [left, right]:
		_style_arrow(button)
	diagram.queue_redraw()


func _refresh() -> void:
	var side := GameState.starting_ring_side()
	var placed := GameState.ring()
	element.text = Ring.side_element(side).capitalize()
	diagram.set_ring(placed, side)
	left.disabled = Ring.next_occupied_side(placed, side, -1) == side
	right.disabled = Ring.next_occupied_side(placed, side, 1) == side


func turn(dir: int) -> void:
	var before := GameState.starting_ring_side()
	if not GameState.turn_starting_ring(dir):
		return
	Sfx.play("toggle")
	if _turn != null and _turn.is_running():
		_turn.kill()
	var after := GameState.starting_ring_side()
	var steps := posmod((after - before) * dir, 4) * dir
	var angle: float = diagram.facing + float(steps) * PI / 2.0
	_refresh()
	_face(angle)
	_turn = create_tween()
	_turn.tween_method(_face, angle, 0.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _face(angle: float) -> void:
	diagram.facing = angle
	diagram.queue_redraw()


## Left/right on the ring's menu row or either arrow turns once; A on an arrow uses its normal Button action.
## B or Up/Down from an arrow returns to the list. A on the menu row still opens arrangement/storage.
func handle_input(event: InputEvent) -> void:
	if not event.is_pressed():
		return
	var focus := get_viewport().gui_get_focus_owner()
	if event.is_action("ui_left") or event.is_action("ui_right"):
		accept_event()
		if not event.is_echo():
			turn(-1 if event.is_action("ui_left") else 1)
	elif focus in [left, right] and (event.is_action("ui_cancel") or event.is_action("ui_up") or event.is_action("ui_down")):
		accept_event()
		if is_instance_valid(return_focus):
			return_focus.grab_focus()
