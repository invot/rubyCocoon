extends "res://scripts/ui/modal.gd"
## The title screen's menu: one button low on the screen, the gem over the blurred art (title_pill.gdshader, most
## opaque across its middle), showing one choice at a time, with ▲ and ▼ arrows above and below it (none when New
## Game is the only choice). Up or down slides the words that way inside the button, cropped at its edges, while the
## next choice slides in from the other edge: a ladder that loops round forever (the user's 2026-11-14 direction).
## A, or a tap on the button, picks the choice in it; a tap on an arrow moves as up/down do. Emits the chosen index;
## there is no cancel.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const PILL_SHADER := preload("res://scripts/ui/title_pill.gdshader")
## the button's size, in UI units
const PILL := Vector2(440, 96)
## the arrows' tap areas (desktop, touch) and the gap between them and the button
const ARROW := Vector2(96, 44)
const ARROW_TOUCH := Vector2(140, 48)
const ARROW_GAP := 4.0
const TEXT_SIZE := 44
## how quickly the words slide to their new places (per second, exponential)
const SLIDE := 14.0
## ignores a confirmation this soon after opening, so the press that opened the title can't pick a choice
const SETTLE := 0.15

var items: Array = []
## one flat button per choice, inside the button's clip (no focus of its own: A and taps are handled here)
var buttons: Array = []
## `_focus` and `_cursor` count on past the ends of the list (it loops), and are read modulo its length
var _focus := 0
var _cursor := 0.0
var _pill: ColorRect
var _clip: Control
var _up: Button
var _down: Button
var _age := 0.0


func setup(_items: Array, start := 0) -> Control:
	items = _items.duplicate()
	_focus = clampi(start, 0, maxi(items.size() - 1, 0))
	_cursor = float(_focus)
	return self


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill = ColorRect.new()
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.size = PILL
	var mat := ShaderMaterial.new()
	mat.shader = PILL_SHADER
	mat.set_shader_parameter("rect_size", PILL)
	_pill.material = mat
	add_child(_pill)
	# the words are cropped at the button's edges as they slide
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.size = PILL
	add_child(_clip)
	for i in items.size():
		var b := Button.new()
		b.text = String(items[i])
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", UIKit.font_body())
		b.add_theme_font_size_override("font_size", UIKit.body_px(TEXT_SIZE))
		for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(st, UIKit.LIGHT)
		var empty := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
			b.add_theme_stylebox_override(st, empty)
		b.size = PILL
		b.pressed.connect(_tapped.bind(i))
		_clip.add_child(b)
		buttons.append(b)
	if items.size() > 1:
		_up = _arrow(-1)
		_down = _arrow(1)
	resized.connect(_layout)
	_layout()


## A white triangle in a flat tap area, pointing up (`way` -1) or down (1).
func _arrow(way: int) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		b.add_theme_stylebox_override(st, empty)
	b.size = ARROW_TOUCH if UIKit.touch_ui() else ARROW
	b.draw.connect(func() -> void:
		var c := b.size * 0.5
		var w := 26.0
		var h := 16.0 * float(way)
		var tri := PackedVector2Array([c + Vector2(-w, -h * 0.5), c + Vector2(w, -h * 0.5), c + Vector2(0, h * 0.5)])
		var shadow := PackedVector2Array()
		for p in tri:
			shadow.append(p + Vector2(0, 2))
		b.draw_colored_polygon(shadow, Color(0, 0, 0, 0.35))
		b.draw_colored_polygon(tri, Color(1, 1, 1, 0.75 if b.is_hovered() or b.button_pressed else 1.0) if not b.button_pressed else UIKit.ACCENT.lightened(0.4))
	)
	b.pressed.connect(func() -> void:
		if not UI.stack.is_empty() and UI.stack.back() == self:
			_move(way))
	add_child(b)
	return b


func _process(delta: float) -> void:
	_age += delta
	_cursor = lerpf(_cursor, float(_focus), 1.0 - exp(-SLIDE * delta))
	if absf(_cursor - _focus) < 0.001:
		_cursor = float(_focus)
	(_pill.material as ShaderMaterial).set_shader_parameter("gem", UIKit.button_fill())
	_layout()


## The button low and centred, just above the touch pad's Start and Pause; the arrows over and under it; each choice's
## words at their rung of the ladder.
func _layout() -> void:
	var safe := UIKit.safe_rect(self)
	var cx := safe.get_center().x
	var bottom := 40.0
	if _down != null:
		bottom += _down.size.y + ARROW_GAP
	if UI.controls != null and UI.controls.touch_visible():
		for id in ["start", "pause"]:
			var r: Rect2 = UI.controls.button_rect(id)
			if r.has_area():
				# (the down arrow too stays above them)
				bottom = maxf(bottom, get_viewport_rect().size.y - r.position.y + 6.0 + (_down.size.y + ARROW_GAP if _down != null else 8.0))
	var top_left := Vector2(cx - PILL.x * 0.5, safe.end.y - bottom - PILL.y)
	_pill.position = top_left
	_clip.position = top_left
	if _up != null:
		_up.position = Vector2(cx - _up.size.x * 0.5, top_left.y - ARROW_GAP - _up.size.y)
		_down.position = Vector2(cx - _down.size.x * 0.5, top_left.y + PILL.y + ARROW_GAP)
	var n := float(items.size())
	for i in buttons.size():
		var b: Button = buttons[i]
		var off := float(i) - _cursor
		if n > 1.0:
			off = fposmod(off + n * 0.5, n) - n * 0.5
		b.position = Vector2(0, off * PILL.y)
		b.visible = absf(off) < 0.999
		# only the choice in the button takes a tap
		b.mouse_filter = Control.MOUSE_FILTER_STOP if absf(off) < 0.5 else Control.MOUSE_FILTER_IGNORE


## Which choice is in the button.
func chosen() -> int:
	return posmod(_focus, maxi(items.size(), 1))


## Up (-1) brings in the next choice from below, the words moving up; down (1) the one before, from above.
func _move(way: int) -> void:
	if items.size() < 2:
		return
	_focus -= way
	Sfx.play("select")
	if _up != null:
		_up.queue_redraw()
		_down.queue_redraw()


func _pick() -> void:
	if closed or _age < SETTLE:
		return
	Sfx.play("confirm")
	close(chosen())


func _tapped(i: int) -> void:
	if UI.stack.is_empty() or UI.stack.back() != self:
		return
	if i == chosen():
		_pick()


func on_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_up", true) or ev.is_action_pressed("ui_left", true):
		_move(-1)
	elif ev.is_action_pressed("ui_down", true) or ev.is_action_pressed("ui_right", true):
		_move(1)
	elif ev.is_action_pressed("ui_accept") and not ev.is_echo():
		_pick()
