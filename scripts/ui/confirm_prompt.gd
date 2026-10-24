extends "res://scripts/ui/dialog_box.gd"
## A answers Yes and B answers No directly. The mobile pad grows its own labelled choices.

var confirmation_labels := {"a": "Yes", "b": "No"}
var yes_text := "Yes"
var no_text := "No"
var _yes_button: Button


func _ready() -> void:
	super._ready()
	if not UIKit.touch_ui():
		var choices := HBoxContainer.new()
		choices.add_theme_constant_override("separation", 24)
		add_child(choices)
		for choice in [["A: " + yes_text, 0], ["B: " + no_text, 1]]:
			var button := Button.new()
			button.text = choice[0]
			button.focus_mode = Control.FOCUS_NONE
			button.custom_minimum_size = Vector2(220, UIKit.row_h())
			if choice[1] == 0:
				_yes_button = button
				button.pressed.connect(_accept)
			else:
				button.pressed.connect(_answer.bind(1))
			choices.add_child(button)
		UIKit.place(choices, "bottom", Vector2(24, 24))


func _bottom_gap() -> float:
	return super._bottom_gap() + (0.0 if UIKit.touch_ui() else 96.0)


func _process(delta: float) -> void:
	super._process(delta)
	if _paged:
		# Decision prompts are readable immediately. A only advances when a long question has another page.
		text_label.visible_characters = -1
		more.visible = false
		confirmation_labels["a"] = yes_text if idx == lines.size() - 1 else "Next"
		confirmation_labels["b"] = no_text
		if _yes_button != null:
			_yes_button.text = "A: " + String(confirmation_labels["a"])


func on_input(ev: InputEvent) -> void:
	if ev.is_echo() or not ev.is_pressed():
		return
	if ev.is_action_pressed("ui_cancel"):
		_answer(1)
	elif _paged and (ev.is_action_pressed("ui_accept") or ev.is_action_pressed("interact")):
		_accept()


func _accept() -> void:
	if not _paged:
		return
	if idx < lines.size() - 1:
		_advance()
	else:
		_answer(0)


func _answer(index: int) -> void:
	Sfx.play("confirm" if index == 0 else "back")
	close(index)


func _gui_input(_ev: InputEvent) -> void:
	# Tapping the question itself is never consent. Use the labelled choices.
	pass
