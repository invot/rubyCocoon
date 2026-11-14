extends CanvasLayer
## On-screen controls.
##  Desktop: a strip along the bottom showing which keys do what.
##  Mobile:  a d-pad bottom-left, A and B bottom-right, Start and Pause bottom-centre: Kenney's Xbox prompts, the d-pad
##           off-white with the held way in the gem, the buttons the gem with white letters.
##  Both use Kenney's input prompts (assets/ui/input_prompts/), and light up what is held.
## Touch buttons send the same input actions as the keyboard, so every screen works with them.

const UIKit = preload("res://scripts/ui/ui_kit.gd")

const LEGEND_H := 48.0
var _legend_tween: Tween
signal layout_changed
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
## The key guide appears with the Start book, and also throughout the desktop web title flow.
var _legend_up := false
var _title_legend_up := false
var touch_root: Node2D
var _buttons := {}
var _touch_on := false
## the gem the legend and pad were drawn in
var _gem := ""


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_legend()
	_build_touch()
	_gem = UIKit.accent_name
	get_viewport().size_changed.connect(_layout)
	if is_instance_valid(Prefs):
		Prefs.changed.connect(refresh)
	Controllers.changed.connect(refresh)
	refresh()


func refresh() -> void:
	if _gem != UIKit.accent_name:
		_recolour()
	var next_touch := Prefs.touch_enabled() and (not title_mode or film_mode)
	if _touch_on and not next_touch:
		# A controller connected while a thumb was down: release the pad's actions before hiding it.
		for id in PAD_ACTIONS:
			if (_buttons[id] as TouchScreenButton).is_pressed() or id == _arm:
				_send_actions(id, false)
		_arm = ""
	_touch_on = next_touch
	touch_root.visible = _touch_on
	touch_root.process_mode = Node.PROCESS_MODE_INHERIT if _touch_on else Node.PROCESS_MODE_DISABLED
	_show_rows()
	_place_legend(true)
	_layout()
	layout_changed.emit()


func legend_visible() -> bool:
	return legend != null and legend.visible and _guide_requested()


func controller_visible() -> bool:
	return controller_guide() and _legend_up and not title_mode


func _guide_requested() -> bool:
	return _legend_up or _title_legend_up and (controller_guide() or Prefs.is_desktop_web() or Prefs.input_mode == "keyboard")


func controller_guide() -> bool:
	return Prefs.effective_input() == "controller"


func legend_height() -> float:
	var safe := UIKit.safe_rect(legend)
	return LEGEND_H + get_viewport().get_visible_rect().size.y - safe.end.y


## Slides the key legend up into view (or back down out of sight).
func show_legend(on: bool) -> void:
	if on == _legend_up:
		return
	_legend_up = on
	_place_legend(false)
	layout_changed.emit()


## The web title flow and the Start book own their visibility independently.
func show_title_legend(on: bool) -> void:
	if on == _title_legend_up:
		return
	_title_legend_up = on
	_place_legend(false)
	layout_changed.emit()


func _place_legend(instant: bool) -> void:
	if not is_inside_tree() or not is_instance_valid(legend) or not legend.is_inside_tree():
		return
	legend.visible = not _legend_up and not _touch_on and not controller_guide() and (Prefs.show_key_legend or Prefs.is_desktop_web()) and not title_mode
	if _legend_tween != null and _legend_tween.is_valid():
		_legend_tween.kill()
	var height := legend_height()
	var top := -height if _guide_requested() else 0.0
	if instant:
		legend.offset_top = top
		legend.offset_bottom = top + height
		return
	var tw := legend.create_tween()
	_legend_tween = tw
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(legend, "offset_top", top, 0.25)
	tw.parallel().tween_property(legend, "offset_bottom", top + height, 0.25)


func touch_visible() -> bool:
	return _touch_on


## Only screens explicitly requesting it (the full map or ring editor) hide the side pad.
func _process(_delta: float) -> void:
	if legend != null and legend.visible:
		_update_legend_icons()
	if not _touch_on or _buttons.is_empty():
		return
	var top = UI.stack.back() if is_instance_valid(UI) and not UI.stack.is_empty() else null
	var answers: Dictionary = top.get("confirmation_labels") if top != null and top.get("confirmation_labels") is Dictionary else {}
	var film := film_mode
	if answers != _answer_labels:
		var changed_mode := answers.is_empty() != _answer_labels.is_empty()
		_answer_labels = answers.duplicate()
		if changed_mode:
			if _answer_tween != null and _answer_tween.is_valid():
				_answer_tween.kill()
			_answer_tween = create_tween()
			_answer_tween.tween_property(self, "_answer_blend", 0.0 if answers.is_empty() else 1.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_layout()
	var hide: bool = top != null and top.get("hides_touch_pad") == true
	_show_group(ARMS, not hide and not film)
	_show_group(["a", "b"], not hide)
	_show_group(["start", "pause"], not film)
	_update_answer_faces()
	_update_pad_faces()


## Shows or steps aside one cluster of the pad with its drawings.
func _show_group(ids: Array, on: bool) -> void:
	if (_buttons[ids[0]] as TouchScreenButton).visible == on:
		return
	for id in ids:
		var b: TouchScreenButton = _buttons[id]
		b.visible = on
		# hidden touch buttons still catch touches: switch them off while they're stepped aside (letting go of
		# anything held, as their own release would never come)
		if not on and b.is_pressed():
			_send(id, false)
		b.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
		if _faces.has(id):
			(_faces[id] as CanvasItem).visible = on
			(_shadows[id] as CanvasItem).visible = on
	if "up" in ids:
		_dpad_face.visible = on
		_dpad_shadow.visible = on
		_dpad_arm.visible = on and _dpad_shown != ""


## Redraws the legend strip and the pad in the current gem.
func _recolour() -> void:
	_gem = UIKit.accent_name
	legend.add_theme_stylebox_override("panel", _legend_style())
	for e in _legend_icons:
		e["on"] = not e["on"]
	_recolour_pad()


# ---------------------------------------------------------------- desktop key legend
func _legend_style() -> StyleBox:
	# the off-white box, like every window
	return UIKit.plate(UIKit.BORDER, Vector4(16, 0, 16, 0))


func _build_legend() -> void:
	legend = PanelContainer.new()
	legend.add_theme_stylebox_override("panel", _legend_style())
	legend.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	legend.offset_top = -LEGEND_H
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(legend)
	_legend_box = CenterContainer.new()
	legend.add_child(_legend_box)
	_legend_row = _legend_keys([[ARROW_KEYS, "Move"], ["a", "Action"], ["s", "Back · hold to run"], ["space", "Start"],
		["shift", "Pause"]])
	_legend_box.add_child(_legend_row)
	_flute_row = _legend_keys([[ARROW_KEYS, "Arrow notes"], ["a", "A note"], ["s", "B note"], ["escape", "Stop playing"]])
	_flute_row.visible = false
	_legend_box.add_child(_flute_row)


## The legend's icons are Kenney's keyboard keys (assets/ui/input_prompts/): at rest the
## outlined key in near-black, and while it is held the filled key in the gem (its cut-out letter shows the strip).
const ARROW_KEYS := ["left", "up", "down", "right"]
const KEY_ICONS := {"left": "keyboard_arrow_left", "up": "keyboard_arrow_up", "down": "keyboard_arrow_down",
	"right": "keyboard_arrow_right", "a": "keyboard_a", "s": "keyboard_s", "space": "keyboard_space",
	"shift": "keyboard_shift", "escape": "keyboard_escape"}
const KEY_CODES := {"left": KEY_LEFT, "up": KEY_UP, "down": KEY_DOWN, "right": KEY_RIGHT, "a": KEY_A, "s": KEY_S,
	"space": KEY_SPACE, "shift": KEY_SHIFT, "escape": KEY_ESCAPE}
## an icon's height on the legend strip (Kenney's keys have a margin inside their square, so the icon is a little
## taller than the key it shows)
const CAP_H := 40.0
## the legend's icons: {rect, rest, held, test (Callable -> bool)}
var _legend_icons: Array = []
var _legend_box: CenterContainer


func _legend_keys(keys: Array) -> HBoxContainer:
	var icons: Array = []
	for k in keys:
		var caps: Array = []
		for face in (k[0] if k[0] is Array else [k[0]]):
			var code: Key = KEY_CODES[face]
			caps.append(_legend_icon(KEY_ICONS[face] + "_outline", KEY_ICONS[face], func() -> bool:
				return Input.is_physical_key_pressed(code)))
		icons.append([caps, k[1]])
	return _legend_items(icons)


## The strip's items: [[icons], what they do] each.
func _legend_items(items: Array) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 30)
	for it in items:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 6)
		var caps := HBoxContainer.new()
		caps.add_theme_constant_override("separation", 0)
		caps.alignment = BoxContainer.ALIGNMENT_CENTER
		for icon in it[0]:
			caps.add_child(icon)
		item.add_child(caps)
		var dl := UIKit.label(it[1], 20, UIKit.INK)
		dl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		item.add_child(dl)
		hb.add_child(item)
	return hb


## One icon on the strip: `rest` (an outlined icon, in near-black) normally, `held` (filled, in the gem) while `test`.
func _legend_icon(rest: String, held: String, test: Callable) -> TextureRect:
	var r := TextureRect.new()
	r.texture = _icon(rest)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	r.custom_minimum_size = Vector2(CAP_H, CAP_H)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.self_modulate = UIKit.INK
	_legend_icons.append({"rect": r, "rest": rest, "held": held, "test": test, "on": false})
	return r


## Which row the strip shows: the keys, or the flute game's notes.
func _show_rows() -> void:
	_legend_row.visible = not controller_guide() and not flute_mode
	_flute_row.visible = not controller_guide() and flute_mode


## Lights the legend's icons for what is held (each frame while the strip shows).
func _update_legend_icons() -> void:
	for e in _legend_icons:
		var r: TextureRect = e["rect"]
		if not r.is_visible_in_tree():
			continue
		var on: bool = e["test"].call()
		if on != e["on"]:
			e["on"] = on
			r.texture = _icon(e["held"] if on else e["rest"])
			r.self_modulate = UIKit.ACCENT if on else UIKit.INK


# ---------------------------------------------------------------- touch controls
## One arm of the d-pad (the cross is three arms across), A and B's diameter, and Start / Pause's pill (the Xbox
## pill's own proportions).
const ARM := 88.0
const ROUND := 104.0
const PILL := Vector2(96, 64)
## how far each face's soft shadow drops
const SHADOW_DROP := 5.0

## Kenney's input prompts (CC0, assets/ui/input_prompts/, copied by tools/input_prompts/build.py): the pad uses the
## Xbox d-pad, A, B and START pill, and a PAUSE pill made to match. Each is a white 64-unit SVG; prompt_tint.gdshader
## colours it (the d-pad off-white with its held arm in the gem; the buttons the gem with white letters).
const PROMPTS := "res://assets/ui/input_prompts/"
const TINT := preload("res://scripts/ui/prompt_tint.gdshader")
## where each kind of icon's shape lies in its 64-unit square (the rest is Kenney's margin)
const SHAPE_ROUND := Rect2(8, 8, 48, 48)
const SHAPE_PILL := Rect2(8, 16, 48, 32)
const FACE_ICONS := {"a": "xbox_button_a", "b": "xbox_button_b", "start": "xbox_button_start", "pause": "xbox_button_pause"}
## an answer pill's icon (A or B, white on the gem) as a share of its height, and the room around it
const ANSWER_ICON := 0.72
const ANSWER_PAD := 16.0

## the d-pad's drawing: Kenney's outlined cross in off-white, with the arm for the way being held (by the touch pad,
## keys or a controller) filled in the gem. The four arm buttons over it only take touches: each answers in its own quarter of
## the pad (a wedge from the middle out past its edge, see _arm_shape), so a thumb only ever holds one of the four ways.
var _dpad_face: Sprite2D
var _dpad_shadow: Sprite2D
var _dpad_arm: Sprite2D
var _dpad_shown := "-"
var _dpad_box := Rect2()
## A, B, Start and Pause's drawings and their shadows (the buttons themselves only take touches)
var _faces := {}
var _shadows := {}
var _face_state := {}
## A and B's gem pills while they answer Yes / No, and the answer beside each button's letter
var _answer_pills := {}
var _labels := {}
var _answer_labels := {}
var _answer_tween: Tween
var _answer_blend := 0.0:
	set(value):
		_answer_blend = value
		_layout()


static func _icon(name: String) -> Texture2D:
	return load(PROMPTS + name + ".svg")


func _tint(body: Color, mark := Color.WHITE, letter := Color.WHITE, solid: Texture2D = null) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TINT
	m.set_shader_parameter("body", body)
	m.set_shader_parameter("mark", mark)
	m.set_shader_parameter("letter", letter)
	m.set_shader_parameter("has_solid", solid != null)
	m.set_shader_parameter("solid", solid)
	return m


## A drawing and its shadow (the same shape, black and faint, a little lower): [face, shadow].
func _face_sprite(tex: Texture2D, solid: Texture2D) -> Array:
	var shadow := Sprite2D.new()
	shadow.centered = false
	shadow.texture = tex
	shadow.material = _tint(Color(0, 0, 0, 0.26), Color(0, 0, 0, 0.26), Color.BLACK, solid)
	touch_root.add_child(shadow)
	var face := Sprite2D.new()
	face.centered = false
	face.texture = tex
	touch_root.add_child(face)
	return [face, shadow]


func _build_touch() -> void:
	touch_root = Node2D.new()
	# the icons' SVGs are imported large, with mipmaps, and drawn smoothly scaled down
	touch_root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(touch_root)
	var pair := _face_sprite(_icon("xbox_dpad_none"), null)
	_dpad_face = pair[0]
	_dpad_shadow = pair[1]
	_dpad_face.material = _tint(UIKit.WELL)
	# the held arm: Kenney's filled d-pad with that arm marked, drawing only the mark (in the gem) inside the outline
	_dpad_arm = Sprite2D.new()
	_dpad_arm.centered = false
	_dpad_arm.visible = false
	_dpad_arm.material = _tint(Color(1, 1, 1, 0), UIKit.ACCENT)
	touch_root.add_child(_dpad_arm)
	for k in ["a", "b"]:
		var pill := Panel.new()
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.visible = false
		touch_root.add_child(pill)
		_answer_pills[k] = pill
	for k in ["a", "b", "start", "pause"]:
		var solid := _icon(FACE_ICONS[k] + "_solid")
		var both := _face_sprite(_icon(FACE_ICONS[k]), solid)
		_faces[k] = both[0]
		_shadows[k] = both[1]
		(both[0] as Sprite2D).material = _tint(UIKit.button_fill(), Color.WHITE, UIKit.LIGHT, solid)
	for dir in ["up", "down", "left", "right"]:
		_touch_button(dir, Vector2(ARM, ARM))
	for k in ["a", "b"]:
		var b2 := _touch_button(k, Vector2(ROUND, ROUND))
		# the answer beside the letter while A / B answer Yes / No
		var l := UIKit.label("", 32, UIKit.LIGHT)
		l.add_theme_font_size_override("font_size", UIKit.body_px(32))
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.visible = false
		b2.add_child(l)
		_labels[k] = l
	for k in ["start", "pause"]:
		_touch_button(k, PILL)
	_recolour_pad()
	_layout()


func _answer_icon() -> float:
	return roundf(ROUND * ANSWER_ICON)


## A and B's width: round, or (while they answer) a pill holding the button's letter and its answer.
func _answer_width() -> float:
	var text_w := 0.0
	for id in _answer_labels:
		text_w = maxf(text_w, UIKit.font_body().get_string_size(String(_answer_labels[id]), HORIZONTAL_ALIGNMENT_LEFT, -1,
			UIKit.body_px(32)).x)
	var width := maxf(200.0, (ROUND - _answer_icon()) * 0.5 + _answer_icon() + ANSWER_PAD + text_w + ANSWER_PAD * 2.0)
	return lerpf(ROUND, width, _answer_blend)


## Keeps A and B in step with a Yes / No prompt: round gem buttons, or a gem pill with the button (white, its cut-out
## letter showing the gem) at its left and the answer in white to its right.
func _update_answer_faces() -> void:
	if _labels.is_empty():
		return
	var wide := _answer_blend > 0.001
	for id in ["a", "b"]:
		var label: Label = _labels[id]
		var text: String = String(_answer_labels.get(id, "")) if _answer_blend > 0.45 else ""
		if label.text != text:
			label.text = text
		label.visible = text != ""
		(_answer_pills[id] as Panel).visible = wide and (_faces[id] as Sprite2D).visible
		(_shadows[id] as Sprite2D).visible = (_faces[id] as Sprite2D).visible and not wide


## The answer pills' style in the current gem (the drawings' colours follow in _update_pad_faces).
func _recolour_pad() -> void:
	_face_state.clear()
	(_dpad_face.material as ShaderMaterial).set_shader_parameter("body", UIKit.WELL)
	(_dpad_arm.material as ShaderMaterial).set_shader_parameter("mark", UIKit.ACCENT)
	for k in _answer_pills:
		var sb := StyleBoxFlat.new()
		sb.bg_color = UIKit.button_fill()
		sb.set_corner_radius_all(int(ROUND / 2.0))
		sb.anti_aliasing = true
		sb.corner_detail = 12
		sb.shadow_color = Color(0, 0, 0, 0.26)
		sb.shadow_size = 6
		sb.shadow_offset = Vector2(0, SHADOW_DROP - 1.0)
		(_answer_pills[k] as Panel).add_theme_stylebox_override("panel", sb)


## The pad's held states, each frame: the d-pad's arm in the gem for the way being held, a held button a deeper gem.
func _update_pad_faces() -> void:
	var dir := _held_way()
	if dir != _dpad_shown:
		_dpad_shown = dir
		_dpad_arm.visible = dir != "" and _dpad_face.visible
		if dir != "":
			_dpad_arm.texture = _icon("xbox_dpad_" + dir)
			_fit(_dpad_arm, Rect2(_dpad_box.position, _dpad_box.size), SHAPE_ROUND)
	var wide := _answer_blend > 0.001
	for k in _faces:
		var down := (_buttons[k] as TouchScreenButton).is_pressed()
		var on_pill: bool = wide and k in ["a", "b"]
		var state := "%s %s %s" % [down, on_pill, UIKit.accent_name]
		if _face_state.get(k, "") == state:
			continue
		_face_state[k] = state
		var m := (_faces[k] as Sprite2D).material as ShaderMaterial
		var fill := UIKit.pressed_fill() if down else UIKit.button_fill()
		if on_pill:
			# on its pill: a white button whose cut-out letter shows the gem behind it
			m.set_shader_parameter("body", UIKit.LIGHT)
			m.set_shader_parameter("has_solid", false)
			((_answer_pills[k] as Panel).get_theme_stylebox("panel") as StyleBoxFlat).bg_color = fill
		else:
			m.set_shader_parameter("body", fill)
			m.set_shader_parameter("has_solid", true)


## The way being held: the touch pad's arm, else a direction key or a controller's d-pad or stick.
func _held_way() -> String:
	if _arm != "":
		return _arm
	for dir in ARMS:
		if Input.is_action_pressed("move_" + dir) or Input.is_action_pressed("ui_" + dir):
			return dir
	return ""


## Sizes `sprite` so its icon's shape (`shape`, in Kenney's 64-unit square) fills `box`.
static func _fit(sprite: Sprite2D, box: Rect2, shape: Rect2) -> void:
	if sprite.texture == null:
		return
	var px := float(sprite.texture.get_width()) / 64.0
	var k := box.size.x / shape.size.x / px
	sprite.scale = Vector2(k, k)
	sprite.position = box.position - shape.position * px * k


static func _blank(sz: Vector2i) -> ImageTexture:
	var img := Image.create(sz.x, sz.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


## A touch button covering `box` (the hit area reaches a little further, so near-misses still count). It draws nothing
## itself: its icon is drawn under it (_faces, _dpad_face).
func _touch_button(id: String, box: Vector2) -> TouchScreenButton:
	var b := TouchScreenButton.new()
	b.texture_normal = _blank(Vector2i(int(box.x), int(box.y)))
	b.passby_press = id in ["up", "down", "left", "right"]
	b.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	b.pressed.connect(_send.bind(id, true))
	b.released.connect(_send.bind(id, false))
	if id in ["a", "b"]:
		var circle := CircleShape2D.new()
		circle.radius = box.x / 2.0 + TOUCH_SLOP
		b.shape = circle
	elif id in ["up", "down", "left", "right"]:
		b.shape = _arm_shape(id)
	else:
		var rect := RectangleShape2D.new()
		rect.size = box + Vector2.ONE * TOUCH_SLOP * 2.0
		b.shape = rect
	b.shape_centered = true
	b.shape_visible = false
	touch_root.add_child(b)
	_buttons[id] = b
	return b


## An arm's touch area: the quarter of the d-pad on its side of the two diagonals, from the middle of the cross out to
## a little past its edge (in the arm's own space, centred on the arm). The four never overlap, so wherever a thumb
## lands or slides it holds just one way.
static func _arm_shape(dir: String) -> ConvexPolygonShape2D:
	var out: Vector2 = {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}[dir]
	var side := Vector2(-out.y, out.x)
	var reach := ARM * 1.5 + TOUCH_SLOP
	var middle := -out * ARM
	var shape := ConvexPolygonShape2D.new()
	shape.points = PackedVector2Array([middle, middle + (out + side) * reach, middle + (out - side) * reach])
	return shape


## The flute minigame's notes. While flute_mode is on, these buttons send only their note, without the button blip.
const FLUTE_LANES := {"left": "flute_1", "right": "flute_2", "a": "flute_3", "b": "flute_4", "up": "flute_5", "down": "flute_6"}

var flute_mode := false
var _legend_row: Control
var _flute_row: Control


## Cinematics and save-browser previews can hide the pad; the ordinary title menu keeps it available.
var title_mode := false


func set_title_mode(on: bool) -> void:
	if on == title_mode:
		return
	title_mode = on
	refresh()


## A film that takes input (the prologue) keeps only A and B, looking as they always do: nothing can move, and there
## is no book or pause to open, so the d-pad, Start and Pause step aside until it ends.
var film_mode := false


func set_film_mode(on: bool) -> void:
	if on == film_mode:
		return
	film_mode = on
	refresh()


func set_flute_mode(on: bool) -> void:
	if on == flute_mode:
		return
	# let go of anything held, so no action stays stuck down across the switch
	for id in PAD_ACTIONS:
		for action in PAD_ACTIONS[id] + ([FLUTE_LANES[id]] if FLUTE_LANES.has(id) else []):
			if Input.is_action_pressed(action):
				Input.action_release(action)
	_arm = ""
	flute_mode = on
	if _legend_row:
		_show_rows()


## The d-pad arm whose arrow is held: one at a time (outside the flute game), so two thumbs, or one on the line
## between two arms, never hold two ways at once. The newest wins; let go of it and an arm still held takes over.
const ARMS := ["up", "down", "left", "right"]
var _arm := ""


func _send(id: String, down: bool) -> void:
	if id in ARMS and not flute_mode:
		if down:
			if _arm != "" and _arm != id:
				_send_actions(_arm, false)
			_arm = id
		elif id != _arm:
			# already let go of when another arm took over
			return
		else:
			_arm = ""
			for other in ARMS:
				if other != id and (_buttons[other] as TouchScreenButton).is_pressed():
					_arm = other
					_send_actions(other, true)
					break
	if down and PAD_PITCH.has(id) and not flute_mode:
		Sfx.play_tone("blip", PAD_PITCH[id], PAD_VOL)
	_send_actions(id, down)


func _send_actions(id: String, down: bool) -> void:
	var actions: Array = PAD_ACTIONS[id]
	if flute_mode and FLUTE_LANES.has(id):
		actions = [FLUTE_LANES[id]]
	elif id in ["a", "b"] and down and not UI.stack.is_empty():
		# A modal takes one accept/cancel event per press, without also triggering a world action or running.
		actions = ["ui_accept" if id == "a" else "ui_cancel"]
	for action in actions:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = down
		Input.parse_input_event(ev)


func _layout() -> void:
	if touch_root == null:
		return
	_place_legend(true)
	var safe := UIKit.safe_rect(legend)
	legend.offset_left = safe.position.x
	legend.offset_right = safe.end.x - get_viewport().get_visible_rect().size.x
	var vp := get_viewport().get_visible_rect().size
	var pad := Vector2(28, vp.y - 28 - ARM * 3.0)
	_dpad_box = Rect2(pad, Vector2.ONE * ARM * 3.0)
	for sprite in [_dpad_face, _dpad_shadow, _dpad_arm]:
		_fit(sprite, _dpad_box, SHAPE_ROUND)
	_dpad_shadow.position.y += SHADOW_DROP
	_buttons["up"].position = pad + Vector2(ARM, 0)
	_buttons["left"].position = pad + Vector2(0, ARM)
	_buttons["right"].position = pad + Vector2(ARM * 2.0, ARM)
	_buttons["down"].position = pad + Vector2(ARM, ARM * 2.0)
	var width := _answer_width()
	_buttons["a"].position = Vector2(vp.x - 28 - width, vp.y - 28 - ROUND - lerpf(70.0, 160.0, _answer_blend))
	_buttons["b"].position = Vector2(vp.x - 28 - width - lerpf(124.0, 0.0, _answer_blend), vp.y - 28 - ROUND)
	_buttons["start"].position = Vector2(roundf(vp.x / 2.0) - PILL.x - 8, vp.y - 26 - PILL.y)
	_buttons["pause"].position = Vector2(roundf(vp.x / 2.0) + 8, vp.y - 26 - PILL.y)
	for id in ["start", "pause"]:
		var box := Rect2((_buttons[id] as TouchScreenButton).position, PILL)
		_fit(_faces[id], box, SHAPE_PILL)
		_fit(_shadows[id], box, SHAPE_PILL)
		(_shadows[id] as Sprite2D).position.y += SHADOW_DROP
	for id in ["a", "b"]:
		var at: Vector2 = (_buttons[id] as TouchScreenButton).position
		# round, the button fills its circle; on its answer pill it shrinks to the pill's left end
		var icon := lerpf(ROUND, _answer_icon(), _answer_blend)
		var inset := (ROUND - icon) * 0.5
		var box := Rect2(at + Vector2(inset, inset), Vector2(icon, icon))
		_fit(_faces[id], box, SHAPE_ROUND)
		_fit(_shadows[id], box, SHAPE_ROUND)
		(_shadows[id] as Sprite2D).position.y += SHADOW_DROP
		var pill: Panel = _answer_pills[id]
		pill.position = at
		pill.size = Vector2(width, ROUND)
		var label: Label = _labels[id]
		label.position = Vector2(inset + icon + ANSWER_PAD, 0)
		label.size = Vector2(maxf(0.0, width - label.position.x - ANSWER_PAD), ROUND)
		var button: TouchScreenButton = _buttons[id]
		if _answer_blend > 0.001:
			if not button.shape is ConvexPolygonShape2D:
				button.shape = ConvexPolygonShape2D.new()
			button.shape_centered = false
			button.shape.points = UIKit.round_rect(Rect2(-Vector2.ONE * TOUCH_SLOP, Vector2(width, ROUND) + Vector2.ONE * TOUCH_SLOP * 2.0), ROUND / 2.0 + TOUCH_SLOP)
		else:
			if not button.shape is CircleShape2D:
				button.shape = CircleShape2D.new()
				button.shape.radius = ROUND / 2.0 + TOUCH_SLOP
			button.shape_centered = true


## The button clusters, each one no-tap zone: the whole d-pad (its middle and the corners between the arrows too),
## A and B together, and Start/Pause.
const CLUSTERS := [["up", "down", "left", "right"], ["a", "b"], ["start", "pause"]]
## How far past a cluster's edge (beyond the buttons' own slop) a tap still belongs to the controls.
const NO_TAP_MARGIN := 48.0


## Current face bounds, including the animated Yes/No width.
func button_rect(id: String) -> Rect2:
	var button: TouchScreenButton = _buttons[id]
	var box: Vector2 = button.texture_normal.get_size()
	if id in ["a", "b"]:
		box.x = _answer_width()
	return Rect2(button.position, box)


## Bottom space a menu needs at its horizontal position, including the buttons' enlarged hit areas and a gap.
## Central menus can use the space between the side controls; right-hand lists must stop above A/B.
func menu_bottom_reserve(left: float, right: float) -> float:
	if not _touch_on:
		return legend_height() if legend_visible() else 0.0
	var reserve := 0.0
	var height := get_viewport().get_visible_rect().size.y
	for group in CLUSTERS:
		var zone := cluster_zone(group, TOUCH_SLOP + 12.0)
		if zone.has_area() and left < zone.end.x and right > zone.position.x:
			reserve = maxf(reserve, height - zone.position.y)
	return reserve


## How much of the screen's right edge the A/B cluster takes, with its no-tap margin (0 without the touch pad): a
## menu standing on the right keeps clear of it by standing beside it (list_menu.gd, the menu shot).
func right_cluster_width() -> float:
	var zone := cluster_zone(["a", "b"], TOUCH_SLOP + NO_TAP_MARGIN)
	if not zone.has_area():
		return 0.0
	return maxf(0.0, get_viewport().get_visible_rect().size.x - zone.position.x)


## A cluster's buttons' faces together, grown by `grow`; empty while the touch pad (or that cluster) is hidden.
func cluster_zone(group: Array, grow: float) -> Rect2:
	if not _touch_on or not (_buttons[group[0]] as TouchScreenButton).visible:
		return Rect2()
	var zone := Rect2()
	for i in group.size():
		var r := button_rect(group[i])
		zone = r if i == 0 else zone.merge(r)
	return zone.grow(grow)


## True near the touch controls, so a thumb that slips off a button or lands in the middle of the d-pad doesn't
## also count as a tap on the world (walk there) or on dialogue.
func covers(p: Vector2) -> bool:
	for group in CLUSTERS:
		if cluster_zone(group, TOUCH_SLOP + NO_TAP_MARGIN).has_point(p):
			return true
	return false
