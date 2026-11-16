extends Control
## A small button in the gem that hangs under a window's right end, overlapping its bottom edge: "B: Cancel" under a
## menu while you talk to someone or use the phone (list_menu.gd cancel_button), "A: Continue" under a level-up's or
## hatching's stats (beast_cinematic.gd), "[Start] Confirm" under the character creator's window (hero_maker.gd). The
## letter (or Start) is shown as the input's own prompt icon before the word (prompt()). The button itself stays small; this control, its tap area, is a little
## larger, so it keeps a full-size target on touch. `pressed` fires once per click or tap.

signal pressed

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const FONT := 24
## how much of the button sits over the window's bottom edge, and how far in from its right end it stands
const OVERLAP := 0.4
const INSET := 28.0

var button: Button
var _fired := false
## a smaller button (the flute's "A: Dismiss"); its tap area keeps the full row height
var compact := false


func setup(text: String, small := false, icon: Texture2D = null) -> Control:
	compact = small
	button = Button.new()
	# "A: Continue", "B: Cancel": the button's own prompt (Kenney's Input Prompts, for the input in use) stands in for
	# the letter before the word
	if icon == null and (text.begins_with("A: ") or text.begins_with("B: ")):
		icon = prompt("accept" if text.begins_with("A") else "back")
		text = text.substr(3)
	button.text = text
	if icon != null:
		# a button's input prompt (Kenney's Input Prompts, white) before its word: cut to the drawing itself (the
		# prompts sit small in the middle of a square), about as tall as the button's capitals
		button.icon = trimmed(icon)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", int(_icon_w()))
		button.add_theme_constant_override("h_separation", 8)
	button.focus_mode = Control.FOCUS_NONE
	UIKit.plate_button(button, Vector4(14, 0, 14, 0))
	button.add_theme_font_override("font", UIKit.font_body())
	button.add_theme_font_size_override("font_size", UIKit.body_px(_font()))
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
	var h := (40.0 if UIKit.touch_ui() else 28.0) if compact else (64.0 if UIKit.touch_ui() else 44.0)
	var w := UIKit.font_body().get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.body_px(_font())).x + (30.0 if compact else 44.0)
	if button.icon != null:
		w += _icon_w() + 8.0 - 12.0
	return Vector2(w, h)


## An icon's width: its drawing scaled to about the button's text height.
func _icon_w() -> float:
	if button == null or button.icon == null:
		return 0.0
	var tall := 34.0 if UIKit.touch_ui() else 24.0
	var s := button.icon.get_size()
	return roundf(tall * s.x / maxf(s.y, 1.0))


## A button's prompt for the input in use (Kenney's Input Prompts, assets/ui/input_prompts/): "accept" (A), "back"
## (B) or "start". A keyboard's keys (A, S and the space bar), the connected controller's own buttons
## (controller_layout.gd prompt_icons), and on a touch screen Xbox's lettered A, B and Start, like the pad's.
static func prompt(what: String) -> Texture2D:
	var name: String = {"accept": "xbox_button_a", "back": "xbox_button_b", "start": "xbox_button_start"}[what]
	match Prefs.effective_input():
		"keyboard":
			name = {"accept": "keyboard_a", "back": "keyboard_s", "start": "keyboard_space"}[what]
		"controller":
			name = String(load("res://scripts/core/controller_layout.gd").prompt_icons(Controllers.layout)[what])
	return load("res://assets/ui/input_prompts/%s.svg" % name)


static var _trims := {}


## An icon cut to what's drawn on it (an AtlasTexture over its opaque part), made once per icon.
static func trimmed(icon: Texture2D) -> Texture2D:
	if _trims.has(icon):
		return _trims[icon]
	var img := icon.get_image()
	if img == null:
		return icon
	if img.is_compressed():
		img.decompress()
	var used := img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return icon
	var a := AtlasTexture.new()
	a.atlas = icon
	a.region = Rect2(used.grow(1)).intersection(Rect2(Vector2.ZERO, img.get_size()))
	_trims[icon] = a
	return a


func _font() -> int:
	return 20 if compact else FONT


func _pad() -> float:
	return maxf(0.0, (UIKit.row_h() - button_size().y) / 2.0)


## How far it (with its tap area) reaches below the window's bottom edge.
func overhang() -> float:
	return button_size().y * (1.0 - OVERLAP) + _pad()


## Stands it under the right end of `rect` (global), over its bottom edge; `beside` (another edge button's width
## and the gap) moves it left of one already there.
func place_under(rect: Rect2, beside := 0.0) -> void:
	var s := button_size()
	var pad := _pad()
	button.custom_minimum_size = s
	button.size = s
	button.position = Vector2(pad, pad)
	size = s + Vector2(pad, pad) * 2.0
	global_position = (Vector2(rect.end.x - INSET - beside - s.x, rect.end.y - s.y * OVERLAP) - Vector2(pad, pad)).round()
