extends Control
## A small button in the gem that hangs under a window's right end, overlapping its bottom edge: "B: Cancel" under a
## menu while you talk to someone or use the phone (list_menu.gd cancel_button), "A: Continue" under a level-up's or
## hatching's stats (beast_cinematic.gd). The button itself stays small; this control, its tap area, is a little
## larger, so it keeps a full-size target on touch. `pressed` fires once per click or tap.

signal pressed

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const FONT := 24
## how much of the button sits over the window's bottom edge, and how far in from its right end it stands
const OVERLAP := 0.4
const INSET := 28.0

var button: Button
var _fired := false


func setup(text: String) -> Control:
	button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	UIKit.plate_button(button, Vector4(14, 0, 14, 0))
	button.add_theme_font_override("font", UIKit.font_body())
	button.add_theme_font_size_override("font_size", UIKit.body_px(FONT))
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.pressed.connect(_fire)
	add_child(button)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 2
	return self


func _gui_input(ev: InputEvent) -> void:
	# a click in the tap area around the button
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
		accept_event()
		_fire()


func _fire() -> void:
	if _fired or not visible:
		return
	_fired = true
	pressed.emit()
	# one press per click, even if the button and the tap area around it both see it
	_rearm.call_deferred()


func _rearm() -> void:
	_fired = false


## The button's visible size.
func button_size() -> Vector2:
	var h := 64.0 if UIKit.touch_ui() else 44.0
	var w := UIKit.font_body().get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.body_px(FONT)).x + 44.0
	return Vector2(w, h)


func _pad() -> float:
	return maxf(0.0, (UIKit.row_h() - button_size().y) / 2.0)


## How far it (with its tap area) reaches below the window's bottom edge.
func overhang() -> float:
	return button_size().y * (1.0 - OVERLAP) + _pad()


## Stands it under the right end of `rect` (global), over its bottom edge.
func place_under(rect: Rect2) -> void:
	var s := button_size()
	var pad := _pad()
	button.custom_minimum_size = s
	button.size = s
	button.position = Vector2(pad, pad)
	size = s + Vector2(pad, pad) * 2.0
	global_position = (Vector2(rect.end.x - INSET - s.x, rect.end.y - s.y * OVERLAP) - Vector2(pad, pad)).round()
