extends "res://scripts/ui/dialog_box.gd"
## A answers Yes and B answers No directly. The mobile pad grows its own labelled choices.

var confirmation_labels := {"a": "Yes", "b": "No"}
var yes_text := "Yes"
var no_text := "No"
var _yes_button: Button
var _choices: HBoxContainer
var _buttons: Array[Button] = []
var _answering := false


func _ready() -> void:
	super._ready()
	if not UIKit.touch_ui():
		var choices := HBoxContainer.new()
		_choices = choices
		choices.add_theme_constant_override("separation", 80 if bubble_mode else 24)
		add_child(choices)
		for choice in [["A: " + yes_text, 0], ["B: " + no_text, 1]]:
			var button := Button.new()
			button.text = choice[0]
			button.focus_mode = Control.FOCUS_NONE
			button.custom_minimum_size = Vector2(220, UIKit.row_h())
			UIKit.plate_button(button)
			if bubble_mode:
				_speech_choice(button, false)
			if choice[1] == 0:
				_yes_button = button
				button.pressed.connect(_accept)
			else:
				button.pressed.connect(_answer.bind(1))
			choices.add_child(button)
			_buttons.append(button)
		if not bubble_mode:
			UIKit.place(choices, "bottom", Vector2(24, 24))


func _bottom_gap() -> float:
	return super._bottom_gap() + (0.0 if UIKit.touch_ui() else 96.0)


func _below_reserve() -> float:
	return UIKit.row_h() + 24.0 if bubble_mode and not UIKit.touch_ui() else 0.0


func _speech_choice(button: Button, selected: bool) -> void:
	var paper := StyleBoxFlat.new()
	paper.bg_color = UIKit.INK
	paper.set_corner_radius_all(12)
	paper.set_content_margin_all(12)
	paper.shadow_color = Color(UIKit.DARK, 0.22)
	paper.shadow_size = 4
	paper.shadow_offset = Vector2(0, 3)
	paper.border_color = UIKit.ACCENT if selected else UIKit.INK
	paper.set_border_width_all(4 if selected else 1)
	for state in ["normal", "disabled"]:
		button.add_theme_stylebox_override(state, paper)
	var focused := paper.duplicate() as StyleBoxFlat
	focused.border_color = UIKit.ACCENT
	focused.set_border_width_all(3)
	for state in ["hover", "focus", "pressed", "hover_pressed"]:
		button.add_theme_stylebox_override(state, focused)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		button.add_theme_color_override(state, UIKit.DARK)


func _process(delta: float) -> void:
	super._process(delta)
	if _choices != null and bubble_mode:
		_choices.position = _snap(Vector2(_bubble_rect.get_center().x-_choices.size.x/2.0, _bubble_rect.end.y+18.0))
	if _paged:
		# Decision prompts are readable immediately. A only advances when a long question has another page.
		text_label.visible_characters = -1
		more.visible = false
		confirmation_labels["a"] = yes_text if idx == lines.size() - 1 else "Next"
		confirmation_labels["b"] = no_text
		if _yes_button != null:
			_yes_button.text = "A: " + String(confirmation_labels["a"])


func on_input(ev: InputEvent) -> void:
	if _answering or ev.is_echo() or not ev.is_pressed():
		return
	if ev.is_action_pressed("ui_cancel"):
		_answer(1)
	elif _paged and (ev.is_action_pressed("ui_accept") or ev.is_action_pressed("interact")):
		_accept()


func _accept() -> void:
	if _answering or not _paged:
		return
	if idx < lines.size() - 1:
		_advance()
	else:
		_answer(0)


func _answer(index: int) -> void:
	if _answering:
		return
	_answering = true
	Sfx.play("confirm" if index == 0 else "back")
	if _choices != null and bubble_mode:
		for i in _buttons.size():
			_buttons[i].disabled = true
			# Keep both slots to prevent the chosen bubble from jumping sideways.
			_buttons[i].modulate.a = 1.0 if i == index else 0.0
			if i == index:
				_speech_choice(_buttons[i], true)
		await get_tree().create_timer(0.35).timeout
	close(index)


func _gui_input(_ev: InputEvent) -> void:
	# Tapping the question itself is never consent. Use the labelled choices.
	pass
