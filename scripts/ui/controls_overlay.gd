extends CanvasLayer
## On-screen controls.
##  Desktop: a strip along the bottom showing which keys do what.
##  Mobile:  a d-pad bottom-left, A and B bottom-right, Start and Pause bottom-centre.
## Touch buttons send the same input actions as the keyboard, so every screen works with them.

const UIKit = preload("res://scripts/ui/ui_kit.gd")

const LEGEND_H := 48.0
## The touch buttons answer taps a little outside their drawn edge (pixels).
const TOUCH_SLOP := 22.0
## A and B click at a lower pitch than the menu blip, B two notes (a minor third) below A, and softer.
const PAD_PITCH := {"a": 0.75, "b": 0.75 * 0.8409}
const PAD_VOL := -6.0
## actions each touch button presses (game + menu navigation + flute lanes)
const PAD_ACTIONS := {
	"up": ["move_up", "ui_up"], "down": ["move_down", "ui_down"],
	"left": ["move_left", "ui_left"], "right": ["move_right", "ui_right"],
	"a": ["interact", "ui_accept"], "b": ["ui_cancel", "run"],
	"start": ["menu"], "pause": ["pause"],
}

var legend: Control
## The desktop key legend only slides up while the Start book is open.
var _legend_up := false
var touch_root: Node2D
var _buttons := {}
var _touch_on := false


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_legend()
	_build_touch()
	get_viewport().size_changed.connect(_layout)
	if is_instance_valid(Prefs):
		Prefs.changed.connect(refresh)
	refresh()


func refresh() -> void:
	_touch_on = Prefs.touch_enabled()
	touch_root.visible = _touch_on
	legend.visible = not _touch_on and Prefs.show_key_legend
	_place_legend(true)
	_layout()


func legend_visible() -> bool:
	return legend != null and legend.visible and _legend_up


## Slides the key legend up into view (or back down out of sight).
func show_legend(on: bool) -> void:
	if on == _legend_up:
		return
	_legend_up = on
	_place_legend(false)


func _place_legend(instant: bool) -> void:
	if legend == null:
		return
	var top := -LEGEND_H if _legend_up else 0.0
	if instant:
		legend.offset_top = top
		legend.offset_bottom = top + LEGEND_H
		return
	var tw := legend.create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(legend, "offset_top", top, 0.25)
	tw.parallel().tween_property(legend, "offset_bottom", top + LEGEND_H, 0.25)


func touch_visible() -> bool:
	return _touch_on


# ---------------------------------------------------------------- desktop key legend
func _build_legend() -> void:
	legend = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.04, 0.92)
	sb.border_color = UIKit.ACCENT
	sb.border_width_top = 3
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	legend.add_theme_stylebox_override("panel", sb)
	legend.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	legend.offset_top = -LEGEND_H
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(legend)
	var cc := CenterContainer.new()
	legend.add_child(cc)
	_legend_row = _legend_keys([["← ↑ ↓ →", "Move"], ["A", "Action"], ["S", "Back · hold to run"], ["SPACE", "Start"], ["SHIFT", "Pause"]])
	cc.add_child(_legend_row)
	_flute_row = _legend_keys([["← ↑ ↓ →", "Arrow notes"], ["A", "A note"], ["S", "B note"], ["ESC", "Stop playing"]])
	_flute_row.visible = false
	cc.add_child(_flute_row)


func _legend_keys(keys: Array) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 30)
	for k in keys:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 8)
		var cap := PanelContainer.new()
		cap.add_theme_stylebox_override("panel", UIKit.box("frame", Vector4(2, -5, 2, -5)))
		var kl := UIKit.header(k[0], UIKit.INK, UIKit.HEAD_SMALL)
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.add_child(kl)
		item.add_child(cap)
		var dl := UIKit.label(k[1], 20, UIKit.LIGHT)
		dl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		item.add_child(dl)
		hb.add_child(item)
	return hb


# ---------------------------------------------------------------- touch controls
func _build_touch() -> void:
	touch_root = Node2D.new()
	add_child(touch_root)
	for dir in ["up", "down", "left", "right"]:
		var b := _touch_button(dir, "button_square", "button_square_down")
		var arrow := Sprite2D.new()
		arrow.texture = UIKit.tex("icon_arrow")
		arrow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		arrow.position = Vector2(44, 44)
		arrow.rotation = {"right": 0.0, "down": PI / 2.0, "left": PI, "up": -PI / 2.0}[dir]
		b.add_child(arrow)
	for k in ["a", "b"]:
		var b2 := _touch_button(k, "button_round" if k == "a" else "button_round_alt", "button_round_down")
		var l := UIKit.header(k.to_upper(), UIKit.LIGHT, 48)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 6)
		l.size = Vector2(104, 104)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b2.add_child(l)
	for k in ["start", "pause"]:
		var b3 := _touch_button(k, "button_pill", "button_pill_down")
		var l2 := UIKit.header(k.to_upper(), UIKit.LIGHT, UIKit.HEAD_SMALL)
		l2.size = Vector2(90, 66)
		l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b3.add_child(l2)
		var cap := UIKit.label("Menu" if k == "start" else "Pause", 20, UIKit.LIGHT)
		cap.add_theme_color_override("font_outline_color", Color.BLACK)
		cap.add_theme_constant_override("outline_size", 5)
		cap.position = Vector2(0, -28)
		cap.size = Vector2(90, 24)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b3.add_child(cap)


## The touch buttons' faces, drawn here: black and see-through with a white rim; pressed, they fill with the accent.
## "square" (the d-pad, 88), "round" (A and B, 104), "pill" (Start and Pause, 90 x 66).
static func _pad_face(shape: String, pressed: bool) -> ImageTexture:
	var sz: Vector2i = {"square": Vector2i(88, 88), "round": Vector2i(104, 104), "pill": Vector2i(90, 66)}[shape]
	var img := Image.create(sz.x, sz.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var fill := Color(UIKit.ACCENT, 0.85) if pressed else Color(0.04, 0.04, 0.05, 0.62)
	var c := Vector2(sz) / 2.0
	for y in sz.y:
		for x in sz.x:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := 0.0
			match shape:
				"round":
					d = c.x - p.distance_to(c)
				"pill":
					var r := c.y
					var q := Vector2(clampf(p.x, r, sz.x - r), c.y)
					d = r - p.distance_to(q)
				_:
					# a square with corners rounded a little
					var r2 := 12.0
					var q2 := Vector2(clampf(p.x, r2, sz.x - r2), clampf(p.y, r2, sz.y - r2))
					d = r2 - p.distance_to(q2)
			if d < 0.0:
				continue
			if d < 3.0:
				img.set_pixel(x, y, UIKit.BORDER)
			elif d < 5.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0.7))
			else:
				img.set_pixel(x, y, fill)
	return ImageTexture.create_from_image(img)


func _touch_button(id: String, tex_up: String, tex_down: String) -> TouchScreenButton:
	var b := TouchScreenButton.new()
	var shape := "square" if "square" in tex_up else ("round" if "round" in tex_up else "pill")
	b.texture_normal = _pad_face(shape, false)
	b.texture_pressed = _pad_face(shape, true)
	b.passby_press = id in ["up", "down", "left", "right"]
	b.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	b.modulate = Color(1, 1, 1, 0.85)
	b.pressed.connect(_send.bind(id, true))
	b.released.connect(_send.bind(id, false))
	# a hit area bigger than the drawing, so near-misses still count
	var tex_size: Vector2 = b.texture_normal.get_size()
	if id in ["a", "b"]:
		var circle := CircleShape2D.new()
		circle.radius = tex_size.x / 2.0 + TOUCH_SLOP
		b.shape = circle
	else:
		var rect := RectangleShape2D.new()
		rect.size = tex_size + Vector2.ONE * TOUCH_SLOP * (1.0 if id in ["up", "down", "left", "right"] else 2.0)
		b.shape = rect
	b.shape_centered = true
	b.shape_visible = false
	touch_root.add_child(b)
	_buttons[id] = b
	return b


## The flute minigame's notes. While flute_mode is on, these buttons send only their note, without the button blip.
const FLUTE_LANES := {"left": "flute_1", "right": "flute_2", "a": "flute_3", "b": "flute_4", "up": "flute_5", "down": "flute_6"}

var flute_mode := false
var _legend_row: Control
var _flute_row: Control


func set_flute_mode(on: bool) -> void:
	if on == flute_mode:
		return
	# let go of anything held, so no action stays stuck down across the switch
	for id in PAD_ACTIONS:
		for action in PAD_ACTIONS[id] + ([FLUTE_LANES[id]] if FLUTE_LANES.has(id) else []):
			if Input.is_action_pressed(action):
				Input.action_release(action)
	flute_mode = on
	if _legend_row:
		_legend_row.visible = not on
		_flute_row.visible = on


func _send(id: String, down: bool) -> void:
	var actions: Array = PAD_ACTIONS[id]
	if flute_mode and FLUTE_LANES.has(id):
		actions = [FLUTE_LANES[id]]
	elif down and PAD_PITCH.has(id):
		Sfx.play_tone("blip", PAD_PITCH[id], PAD_VOL)
	for action in actions:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = down
		Input.parse_input_event(ev)


func _layout() -> void:
	if touch_root == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var pad := Vector2(28, vp.y - 28 - 88 * 3)
	_buttons["up"].position = pad + Vector2(88, 0)
	_buttons["left"].position = pad + Vector2(0, 88)
	_buttons["right"].position = pad + Vector2(176, 88)
	_buttons["down"].position = pad + Vector2(88, 176)
	_buttons["a"].position = Vector2(vp.x - 28 - 104, vp.y - 28 - 104 - 70)
	_buttons["b"].position = Vector2(vp.x - 28 - 104 - 124, vp.y - 28 - 104)
	_buttons["start"].position = Vector2(vp.x / 2.0 - 100, vp.y - 24 - 66)
	_buttons["pause"].position = Vector2(vp.x / 2.0 + 10, vp.y - 24 - 66)


## The button clusters, each one no-tap zone: the whole d-pad (its middle and the corners between the arrows too),
## A and B together, and Start/Pause.
const CLUSTERS := [["up", "down", "left", "right"], ["a", "b"], ["start", "pause"]]
## How far past a cluster's edge (beyond the buttons' own slop) a tap still belongs to the controls.
const NO_TAP_MARGIN := 48.0


## True near the touch controls, so a thumb that slips off a button or lands in the middle of the d-pad doesn't
## also count as a tap on the world (walk there) or on dialogue.
func covers(p: Vector2) -> bool:
	if not _touch_on:
		return false
	for group in CLUSTERS:
		var zone := Rect2()
		for i in group.size():
			var b: TouchScreenButton = _buttons[group[i]]
			var r := Rect2(b.position, b.texture_normal.get_size())
			zone = r if i == 0 else zone.merge(r)
		if zone.grow(TOUCH_SLOP + NO_TAP_MARGIN).has_point(p):
			return true
	return false
