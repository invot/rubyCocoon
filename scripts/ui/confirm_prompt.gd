extends "res://scripts/ui/dialog_box.gd"
## A Yes/No question. On desktop the two answers stand side by side under the speech bubble (or the window); an outline
## marks the active one, Yes to begin with, and left / right (or the mouse) moves it. A picks the active answer and B
## always answers No. The picked answer fills with the gem, with white text, the other disappears, and the prompt
## closes a moment later. While the touch pad is showing, its own A/B buttons grow into labelled A: Yes / B: No
## instead (controls_overlay.gd) and the on-screen answers step aside; whenever the pad is hidden (a controller or
## keyboard on a phone, say) the answers show as on desktop, so the choice is always visible.

var confirmation_labels := {"a": "Yes", "b": "No"}
var yes_text := "Yes"
var no_text := "No"
var _choices: HBoxContainer
var _buttons: Array[Button] = []
## which answer the outline is on: 0 Yes, 1 No
var _active := 0
var _answering := false


func _ready() -> void:
	super._ready()
	var choices := HBoxContainer.new()
	_choices = choices
	choices.add_theme_constant_override("separation", 80 if bubble_mode else 24)
	add_child(choices)
	for choice in [[yes_text, 0], [no_text, 1]]:
		var button := Button.new()
		button.text = choice[0]
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(220, UIKit.row_h())
		button.pressed.connect(_clicked.bind(choice[1]))
		button.mouse_entered.connect(_set_active.bind(choice[1]))
		choices.add_child(button)
		_buttons.append(button)
	_restyle()
	if not bubble_mode:
		UIKit.place(choices, "bottom", Vector2(24, 24))
	choices.visible = _answers_shown()


## The answers show on screen unless the touch pad is up to show A: Yes / B: No itself.
func _answers_shown() -> bool:
	return not (is_instance_valid(Prefs) and Prefs.touch_enabled())


func _bottom_gap() -> float:
	return super._bottom_gap() + (96.0 if _answers_shown() else 0.0)


func _below_reserve() -> float:
	return UIKit.row_h() + 24.0 if bubble_mode and _answers_shown() else 0.0


## Moves the outline to answer `index`.
func _set_active(index: int) -> void:
	if _answering or index == _active or not _on_last_page() or not _choices.visible:
		return
	_active = index
	Sfx.play("select")
	_restyle()


func _restyle() -> void:
	for i in _buttons.size():
		_style_answer(_buttons[i], "on" if i == _active else "off")


## One answer's look: "off", "on" (outlined: the active answer) or "picked" (filled with the gem, white text).
func _style_answer(button: Button, state: String) -> void:
	var box: StyleBox
	var text := UIKit.LIGHT if state == "picked" else UIKit.INK
	if bubble_mode:
		# the replies are speech too: little white bubbles in the dialogue's hand
		button.add_theme_font_override("font", UIKit.font_dialog())
		button.add_theme_font_size_override("font_size", UIKit.body_px(UIKit.DIALOG_SIZE))
		var paper := StyleBoxFlat.new()
		paper.bg_color = UIKit.ACCENT if state == "picked" else Color.WHITE
		paper.set_corner_radius_all(12)
		paper.set_content_margin_all(12)
		paper.shadow_color = Color(UIKit.DARK, 0.22)
		paper.shadow_size = 4
		paper.shadow_offset = Vector2(0, 3)
		paper.border_color = UIKit.ACCENT
		paper.set_border_width_all(4 if state == "on" else 0)
		box = UIKit.FrameBox.bezeled(paper) if state != "picked" else paper
	else:
		button.add_theme_font_override("font", UIKit.font_body())
		button.add_theme_font_size_override("font_size", UIKit.body_px(UIKit.BUTTON_FONT_SIZE))
		var pad := Vector4(16, 4, 16, 4)
		if state == "picked":
			box = UIKit.FrameBox.make("row", Color(0, 0, 0, 0), UIKit.ACCENT, false, pad)
		else:
			box = UIKit.FrameBox.make("window", UIKit.BORDER, Color(0, 0, 0, 0), true, pad)
			if state == "on":
				box.ring = UIKit.ACCENT
	for st in ["normal", "hover", "focus", "pressed", "hover_pressed", "disabled"]:
		button.add_theme_stylebox_override(st, box)
	for st in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color"]:
		button.add_theme_color_override(st, text)


func _on_last_page() -> bool:
	return not _paged or idx >= lines.size() - 1


func _process(delta: float) -> void:
	super._process(delta)
	# a controller connected (or the pad brought back) mid-question swaps how the answers are shown
	if _choices != null and not _answering:
		_choices.visible = _answers_shown()
	if _choices != null and bubble_mode:
		_choices.position = _snap(Vector2(_bubble_rect.get_center().x-_choices.size.x/2.0, _bubble_rect.end.y+18.0))
	if _paged:
		# Decision prompts are readable immediately. A only advances when a long question has another page; the
		# answers wait for the last page, with the usual arrow until then.
		text_label.visible_characters = -1
		var last := _on_last_page()
		more.visible = not last
		confirmation_labels["a"] = yes_text if last else "Next"
		confirmation_labels["b"] = no_text
		if _choices != null and not _answering:
			_choices.modulate.a = 1.0 if last else 0.0


func on_input(ev: InputEvent) -> void:
	if _answering or ev.is_echo() or not ev.is_pressed():
		return
	if ev.is_action_pressed("ui_cancel"):
		_answer(1)
	elif _paged and (ev.is_action_pressed("ui_accept") or ev.is_action_pressed("interact")):
		_accept()
	elif _choices != null and _choices.visible and (ev.is_action_pressed("ui_left") or ev.is_action_pressed("ui_right")):
		_set_active(1 - _active)


func _accept() -> void:
	if _answering or not _paged:
		return
	if not _on_last_page():
		_advance()
	else:
		# with the pad's labelled A/B there's no outline to move: A is Yes
		_answer(_active if _choices != null and _choices.visible else 0)


## A click on an answer picks it, once the answers are showing (the last page).
func _clicked(index: int) -> void:
	if _on_last_page():
		_answer(index)


func _answer(index: int) -> void:
	if _answering:
		return
	_answering = true
	Sfx.play("confirm")
	if _choices != null and _choices.visible:
		for i in _buttons.size():
			_buttons[i].disabled = true
			# Keep both slots to prevent the chosen answer from jumping sideways.
			_buttons[i].modulate.a = 1.0 if i == index else 0.0
			if i == index:
				_style_answer(_buttons[i], "picked")
		await get_tree().create_timer(0.35).timeout
	close(index)


func _gui_input(_ev: InputEvent) -> void:
	# Tapping the question itself is never consent. Use the answers.
	pass
