extends CanvasLayer
## On-screen controls.
##  Desktop: a strip along the bottom showing which keys do what.
##  Mobile:  a d-pad bottom-left, A and B bottom-right, Start and Pause bottom-centre. Like every window they are the
##           blurred near-black box (blur.gdshader) with white linework; pressed, a button fills solid white.
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
	var next_touch := Prefs.touch_enabled() and not title_mode
	if _touch_on and not next_touch:
		# A controller connected while a thumb was down: release the pad's actions before hiding it.
		for id in PAD_ACTIONS:
			if (_buttons[id] as TouchScreenButton).is_pressed() or id == _arm:
				_send_actions(id, false)
		_arm = ""
	_touch_on = next_touch
	touch_root.visible = _touch_on
	touch_root.process_mode = Node.PROCESS_MODE_INHERIT if _touch_on else Node.PROCESS_MODE_DISABLED
	_legend_row.visible = not controller_guide() and not flute_mode
	_flute_row.visible = not controller_guide() and flute_mode
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
	if not _touch_on or _buttons.is_empty():
		return
	var top = UI.stack.back() if is_instance_valid(UI) and not UI.stack.is_empty() else null
	var answers: Dictionary = top.get("confirmation_labels") if top != null and top.get("confirmation_labels") is Dictionary else {}
	if answers != _answer_labels:
		var changed_mode := answers.is_empty() != _answer_labels.is_empty()
		_answer_labels = answers.duplicate()
		if changed_mode:
			if _answer_tween != null and _answer_tween.is_valid():
				_answer_tween.kill()
			_answer_tween = create_tween()
			_answer_tween.tween_property(self, "_answer_blend", 0.0 if answers.is_empty() else 1.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_layout()
	_update_answer_faces()
	var hide: bool = top != null and top.get("hides_touch_pad") == true
	if _buttons["a"].visible == hide:
		for id in ["up", "down", "left", "right", "a", "b"]:
			var b: TouchScreenButton = _buttons[id]
			b.visible = not hide
			# hidden touch buttons still catch touches: switch them off while they're stepped aside (letting go of
			# anything held, as their own release would never come)
			if hide and b.is_pressed():
				_send(id, false)
			b.process_mode = Node.PROCESS_MODE_DISABLED if hide else Node.PROCESS_MODE_INHERIT
		_dpad_base.visible = not hide
		for k in ["dpad", "a", "b"]:
			(_backdrops[k] as CanvasItem).visible = not hide


## Redraws the legend strip, key caps and pad faces in the current gem.
func _recolour() -> void:
	_gem = UIKit.accent_name
	legend.add_theme_stylebox_override("panel", _legend_style())
	for row in [_legend_row, _flute_row]:
		for item in row.get_children():
			var cap: PanelContainer = item.get_child(0)
			cap.add_theme_stylebox_override("panel", UIKit.box("frame", Vector4(2, -5, 2, -5)))
	_shade_backdrops()
	_paint_pad()


## The pad's backdrops take the windows' near-black (faintly tinted with the gem) at the windows' opacity, or, with the
## blur off, a plain box a little more opaque.
func _shade_backdrops() -> void:
	var fb = UIKit.FrameBox
	var on: bool = fb.blur_on
	_backdrop_material.set_shader_parameter("shade", Color(fb.shade, fb.FILL_ALPHA if on else 1.0))
	for k in _backdrops:
		(_backdrops[k] as CanvasItem).self_modulate.a = 1.0 if on else fb.PLAIN_ALPHA


# ---------------------------------------------------------------- desktop key legend
func _legend_style() -> StyleBox:
	# the blurred dark box, like every window
	return UIKit.plate(UIKit.BORDER, Vector4(16, 0, 16, 0))


func _build_legend() -> void:
	legend = PanelContainer.new()
	legend.add_theme_stylebox_override("panel", _legend_style())
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
		var kl := UIKit.label(k[0], 20, UIKit.INK)
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.add_child(kl)
		item.add_child(cap)
		var dl := UIKit.label(k[1], 20, UIKit.LIGHT)
		dl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		item.add_child(dl)
		hb.add_child(item)
	return hb


# ---------------------------------------------------------------- touch controls
## One arm of the d-pad (the cross is three arms across), A and B's diameter, and Start / Pause's pill.
const ARM := 88.0
const ROUND := 104.0
const PILL := Vector2(100, 44)
## room below each face for its drop shadow
const SHADOW_ROOM := 8

## the d-pad's cross, drawn whole under its four arm buttons (which only show when pressed): getting about, battles,
## menus and the flute game all use it. Each arm answers touches in its own quarter of the pad (a wedge from the middle
## out past its arrow, see _arm_shape), so a thumb only ever holds one of the four ways.
var _dpad_base: Sprite2D
## the blurred, darkened scene behind each face (the d-pad's cross, A, B, Start and Pause), drawn under it
var _backdrops := {}
var _backdrop_material: ShaderMaterial
## A, B, Start and Pause's labels: they sink a little while their button is held
var _labels := {}
var _answer_faces := {}
var _answer_labels := {}
var _answer_tween: Tween
var _answer_blend := 0.0:
	set(value):
		_answer_blend = value
		_layout()


func _build_touch() -> void:
	touch_root = Node2D.new()
	# the faces are drawn smooth (soft edges and shading), so they are scaled smoothly too
	touch_root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(touch_root)
	_dpad_base = Sprite2D.new()
	_dpad_base.centered = false
	_backdrop_material = ShaderMaterial.new()
	_backdrop_material.shader = load(UIKit.FrameBox.SHADER)
	var dpad_back := Sprite2D.new()
	dpad_back.centered = false
	dpad_back.material = _backdrop_material
	touch_root.add_child(dpad_back)
	_backdrops["dpad"] = dpad_back
	for k in ["a", "b", "start", "pause"]:
		# a nine-patch, so A and B's backdrops widen with them for Yes / No
		var back := NinePatchRect.new()
		back.material = _backdrop_material
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if k in ["a", "b"]:
			back.patch_margin_left = 48
			back.patch_margin_right = 48
		else:
			back.patch_margin_left = int(PILL.y / 2.0)
			back.patch_margin_right = int(PILL.y / 2.0)
		touch_root.add_child(back)
		_backdrops[k] = back
	_shade_backdrops()
	touch_root.add_child(_dpad_base)
	for dir in ["up", "down", "left", "right"]:
		_touch_button(dir, Vector2(ARM, ARM))
	for k in ["a", "b"]:
		var b2 := _touch_button(k, Vector2(ROUND, ROUND))
		# Stretch the face's middle, preserving its round ends and pixel borders.
		var face := NinePatchRect.new()
		face.patch_margin_left = 48
		face.patch_margin_right = 48
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.visible = false
		b2.add_child(face)
		_answer_faces[k] = face
		var l := UIKit.label(k.to_upper(), UIKit.BODY_HUGE, UIKit.LIGHT)
		# big letters: 64 screen pixels on a 1080p phone
		l.add_theme_font_size_override("font_size", UIKit.body_px(43))
		_style_cap_label(l, Vector2(ROUND, ROUND))
		b2.add_child(l)
		_labels[k] = l
	for k in ["start", "pause"]:
		var b3 := _touch_button(k, PILL)
		var l2 := UIKit.label(k.to_upper(), 20, UIKit.LIGHT)
		_style_cap_label(l2, PILL)
		b3.add_child(l2)
		_labels[k] = l2
	_paint_pad()
	_layout()


func _answer_width() -> float:
	var width := 240.0
	for id in _answer_labels:
		var text := String(id).to_upper() + ": " + String(_answer_labels[id])
		width = maxf(width, UIKit.font_body().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.body_px(32)).x + 48.0)
	return lerpf(ROUND, width, _answer_blend)


func _update_answer_faces() -> void:
	if _answer_faces.is_empty():
		return
	for id in ["a", "b"]:
		var button: TouchScreenButton = _buttons[id]
		var wide := _answer_blend > 0.001
		var face: NinePatchRect = _answer_faces[id]
		button.self_modulate.a = 0.0 if wide else 1.0
		face.visible = wide
		face.texture = button.texture_pressed if button.is_pressed() else button.texture_normal
		var label: Label = _labels[id]
		var text: String = id.to_upper() + ": " + String(_answer_labels[id]) if _answer_blend > 0.45 and _answer_labels.has(id) else id.to_upper()
		if label.text != text:
			label.text = text
		var font_size := UIKit.body_px(32 if wide else 43)
		if label.get_theme_font_size("font_size") != font_size:
			label.add_theme_font_size_override("font_size", font_size)


## A button's label: crisp pixel text (not smoothed like the faces), centred, with a soft shadow below it.
func _style_cap_label(l: Label, box: Vector2) -> void:
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	l.size = box
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE


## The faces, painted pixel by pixel, take a second or more on a phone: they're painted on a worker thread and kept
## in user:// for each gem, so the game doesn't wait for them and later launches just load them. Bump PAD_STYLE when
## their look changes, so the kept ones are painted afresh.
const PAD_CACHE := "user://touch_pad/"
const PAD_STYLE := 6
const FACES := ["dpad", "up", "down", "left", "right", "a", "a_pressed", "b", "b_pressed", "pill", "pill_pressed",
	"dpad_mark", "round_mark", "pill_mark"]
## the faces' white linework, and their drop shadow outside the shape
const RIM := 3.0
const SHADOW_A := 0.30


## (Re)draws every face in the current gem: kept ones straight away, else on a worker thread (until they're ready the
## buttons work, unpainted).
func _paint_pad() -> void:
	for k in _labels:
		(_labels[k] as Label).add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	var key := _pad_key()
	var faces := _kept_faces(key)
	if not faces.is_empty():
		_show_faces(faces)
		return
	WorkerThreadPool.add_task(_paint_faces.bind(key))


## Where this gem's faces are kept: its name, and its colours, the sizes and PAD_STYLE, so any change paints afresh.
static func _pad_key() -> String:
	return "%s_%x" % [UIKit.accent_name, hash([PAD_STYLE, UIKit.ACCENT.to_html(), UIKit.BORDER.to_html(), UIKit.BROWN.to_html(), ARM, ROUND, PILL])]


static func _kept_faces(key: String) -> Dictionary:
	var out := {}
	for f in FACES:
		var path: String = PAD_CACHE + key + "/" + f + ".png"
		if not FileAccess.file_exists(path):
			return {}
		var img := Image.load_from_file(path)
		if img == null or img.is_empty():
			return {}
		out[f] = img
	return out


## On a worker thread: paints every face, keeps them, and hands them to the main thread.
func _paint_faces(key: String) -> void:
	var faces := {"dpad": _dpad_face(), "pill": _pill_face(false), "pill_pressed": _pill_face(true),
		"dpad_mark": _mark(int(ARM * 3.0), int(ARM * 3.0), _sd_cross),
		"round_mark": _mark(int(ROUND), int(ROUND), _sd_round),
		"pill_mark": _mark(int(PILL.x), int(PILL.y), _sd_pill)}
	for dir in ["up", "down", "left", "right"]:
		faces[dir] = _arm_pressed(dir)
	for k in ["a", "b"]:
		faces[k] = _dome_face(k, false)
		faces[k + "_pressed"] = _dome_face(k, true)
	DirAccess.make_dir_recursive_absolute(PAD_CACHE + key)
	for f in faces:
		(faces[f] as Image).save_png(PAD_CACHE + key + "/" + f + ".png")
	# (through a weak reference: the game may have closed, freeing the overlay, while they were painted)
	Callable(get_script(), "_deliver_faces").call_deferred(weakref(self), key, faces)


static func _deliver_faces(me: WeakRef, key: String, faces: Dictionary) -> void:
	var overlay = me.get_ref()
	if overlay != null:
		overlay._faces_painted(key, faces)


func _faces_painted(key: String, faces: Dictionary) -> void:
	if key != _pad_key():
		# the gem changed while they were being painted
		_paint_pad()
		return
	_show_faces(faces)


func _show_faces(faces: Dictionary) -> void:
	# (the faces are smooth shapes)
	touch_root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_dpad_base.texture = ImageTexture.create_from_image(faces["dpad"])
	(_backdrops["dpad"] as Sprite2D).texture = ImageTexture.create_from_image(faces["dpad_mark"])
	var round_mark := ImageTexture.create_from_image(faces["round_mark"])
	var pill_mark := ImageTexture.create_from_image(faces["pill_mark"])
	for k in ["a", "b"]:
		(_backdrops[k] as NinePatchRect).texture = round_mark
	for k in ["start", "pause"]:
		(_backdrops[k] as NinePatchRect).texture = pill_mark
	for dir in ["up", "down", "left", "right"]:
		var b: TouchScreenButton = _buttons[dir]
		b.texture_normal = _blank(Vector2i(int(ARM), int(ARM)))
		b.texture_pressed = ImageTexture.create_from_image(faces[dir])
	for k in ["a", "b"]:
		_buttons[k].texture_normal = ImageTexture.create_from_image(faces[k])
		_buttons[k].texture_pressed = ImageTexture.create_from_image(faces[k + "_pressed"])
	for k in ["start", "pause"]:
		_buttons[k].texture_normal = ImageTexture.create_from_image(faces["pill"])
		_buttons[k].texture_pressed = ImageTexture.create_from_image(faces["pill_pressed"])


# ---- shapes: signed distances, positive inside
static func _sd_box(p: Vector2, rect: Rect2, r: float) -> float:
	var q := (p - rect.get_center()).abs() - (rect.size / 2.0 - Vector2(r, r))
	return -(Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r)


## The d-pad's cross, in its own 264 x 264 space.
static func _sd_cross(p: Vector2) -> float:
	var v := _sd_box(p, Rect2(ARM, 0, ARM, ARM * 3.0), 16.0)
	var h := _sd_box(p, Rect2(0, ARM, ARM * 3.0, ARM), 16.0)
	return maxf(v, h)


## The arrow on the arm `dir`, pointing outwards (signed distance to a triangle).
static func _sd_arrow(p: Vector2, dir: String) -> float:
	var c := Vector2(ARM * 1.5, ARM * 1.5)
	var out: Vector2 = {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}[dir]
	var side := Vector2(-out.y, out.x)
	var mid := c + out * ARM * 1.02
	var tip := mid + out * 15.0
	var b1 := mid - out * 11.0 + side * 16.0
	var b2 := mid - out * 11.0 - side * 16.0
	var d := INF
	for e in [[tip, b1], [b1, b2], [b2, tip]]:
		var a: Vector2 = e[0]
		var n: Vector2 = (e[1] - a).orthogonal().normalized()
		# the inside is on the side of the third corner
		var third: Vector2 = tip + b1 + b2 - e[0] - e[1]
		if n.dot(third - a) < 0.0:
			n = -n
		d = minf(d, n.dot(p - a))
	return d - 1.5


static func _cover(d: float) -> float:
	return clampf(d + 0.5, 0.0, 1.0)


static func _sd_round(p: Vector2) -> float:
	return ROUND / 2.0 - 2.0 - p.distance_to(Vector2.ONE * ROUND / 2.0)


static func _sd_pill(p: Vector2) -> float:
	return _sd_box(p, Rect2(Vector2.ZERO, PILL).grow(-1), PILL.y / 2.0 - 1.0)


## A backdrop's marker: the shape (`sd`, a signed distance, positive inside) in the blur shader's magenta, soft-edged.
static func _mark(w: int, h: int, sd: Callable) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0, 1, 0))
	for y in h:
		for x in w:
			var a := _cover(float(sd.call(Vector2(x + 0.5, y + 0.5))))
			if a > 0.0:
				img.set_pixel(x, y, Color(1, 0, 1, a))
	return img


## A face's pixel `d` inside its edge (signed distance): a soft shadow outside the shape (`sh`: the distance to the
## shape moved down), the white rim along the edge, and `inner` within it.
static func _line_px(d: float, sh: float, inner: Color) -> Color:
	var col := Color(0, 0, 0, 0)
	if d < 0.5:
		col = Color(0, 0, 0, clampf((sh + 4.0) / 8.0, 0.0, 1.0) * SHADOW_A * (1.0 - _cover(d)))
	var a := _cover(d)
	if a > 0.0:
		var px := inner.blend(Color(UIKit.BORDER, _cover(RIM - d)))
		col = col.blend(Color(px, px.a * a))
	return col


## The whole cross: a white rim round its edge, a faint ring in the middle and white arrows. The blurred backdrop
## behind it (dpad_mark) is its body.
static func _dpad_face() -> Image:
	var n := int(ARM * 3.0)
	var img := Image.create(n, n + SHADOW_ROOM, false, Image.FORMAT_RGBA8)
	var centre := Vector2(ARM * 1.5, ARM * 1.5)
	for y in img.get_height():
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := _sd_cross(p)
			var inner := Color(1, 1, 1, 0)
			if d > 0.0:
				var dc := absf(p.distance_to(centre) - 20.0)
				if dc < 1.5:
					inner = Color(UIKit.BORDER, 0.45 * _cover(1.5 - dc))
				for dir in ["up", "down", "left", "right"]:
					var ad := _sd_arrow(p, dir)
					if ad > -1.0:
						inner = inner.blend(Color(UIKit.BORDER, _cover(ad)))
			img.set_pixel(x, y, _line_px(d, _sd_cross(p - Vector2(0, 5)), inner))
	return img


## A pressed arm: its part of the cross fills solid white and its arrow turns dark.
static func _arm_pressed(dir: String) -> Image:
	var off: Vector2 = {"up": Vector2(ARM, 0), "down": Vector2(ARM, ARM * 2.0), "left": Vector2(0, ARM), "right": Vector2(ARM * 2.0, ARM)}[dir]
	var n := int(ARM)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := off + Vector2(x + 0.5, y + 0.5)
			var d := _sd_cross(p)
			var col := Color(1, 1, 1, 0)
			if d > -0.5:
				col = Color(UIKit.BORDER, _cover(d))
				var ad := _sd_arrow(p, dir)
				if ad > -1.0:
					col = col.blend(Color(UIKit.DARK, _cover(ad) * col.a))
			img.set_pixel(x, y, col)
	return img


## A or B: a round button outlined in white over its blurred backdrop; pressed, it fills solid white (its letter turns
## dark, see _send).
static func _dome_face(_which: String, pressed: bool) -> Image:
	var w := int(ROUND)
	var img := Image.create(w, w + SHADOW_ROOM, false, Image.FORMAT_RGBA8)
	var r := ROUND / 2.0 - 2.0
	var c := Vector2(ROUND / 2.0, ROUND / 2.0)
	var sc := c + Vector2(0, 5)
	var inner := Color(UIKit.BORDER, 1.0) if pressed else Color(1, 1, 1, 0)
	for y in img.get_height():
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			img.set_pixel(x, y, _line_px(r - p.distance_to(c), r - p.distance_to(sc), inner))
	return img


## Start / Pause: a small pill outlined in white over its blurred backdrop; pressed, solid white.
static func _pill_face(pressed: bool) -> Image:
	var sz := Vector2i(int(PILL.x), int(PILL.y) + SHADOW_ROOM)
	var img := Image.create(sz.x, sz.y, false, Image.FORMAT_RGBA8)
	var rect := Rect2(Vector2.ZERO, PILL).grow(-1)
	var shadow := Rect2(Vector2(0, 5), PILL).grow(-1)
	var rad := PILL.y / 2.0 - 1.0
	var inner := Color(UIKit.BORDER, 1.0) if pressed else Color(1, 1, 1, 0)
	for y in sz.y:
		for x in sz.x:
			var p := Vector2(x + 0.5, y + 0.5)
			img.set_pixel(x, y, _line_px(_sd_box(p, rect, rad), _sd_box(p, shadow, rad), inner))
	return img


static func _blank(sz: Vector2i) -> ImageTexture:
	var img := Image.create(sz.x, sz.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


## A touch button whose face covers `box` (the hit area reaches a little further, so near-misses still count).
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
		_legend_row.visible = not on and not controller_guide()
		_flute_row.visible = on and not controller_guide()


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
	if _labels.has(id):
		# pressed: dark letters on the solid white face
		var l: Label = _labels[id]
		l.add_theme_color_override("font_color", UIKit.DARK if down else UIKit.LIGHT)
		l.add_theme_constant_override("shadow_offset_y", 0 if down else 3)
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
	_dpad_base.position = pad
	(_backdrops["dpad"] as Sprite2D).position = pad
	_buttons["up"].position = pad + Vector2(ARM, 0)
	_buttons["left"].position = pad + Vector2(0, ARM)
	_buttons["right"].position = pad + Vector2(ARM * 2.0, ARM)
	_buttons["down"].position = pad + Vector2(ARM, ARM * 2.0)
	var width := _answer_width()
	_buttons["a"].position = Vector2(vp.x - 28 - width, vp.y - 28 - ROUND - lerpf(70.0, 160.0, _answer_blend))
	_buttons["b"].position = Vector2(vp.x - 28 - width - lerpf(124.0, 0.0, _answer_blend), vp.y - 28 - ROUND)
	for id in ["a", "b"]:
		if not _answer_faces.has(id):
			continue
		(_answer_faces[id] as NinePatchRect).size = Vector2(width, ROUND + SHADOW_ROOM)
		(_labels[id] as Label).size.x = width
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
	_buttons["start"].position = Vector2(roundf(vp.x / 2.0) - PILL.x - 8, vp.y - 26 - PILL.y)
	_buttons["pause"].position = Vector2(roundf(vp.x / 2.0) + 8, vp.y - 26 - PILL.y)
	for id in ["a", "b", "start", "pause"]:
		var back: NinePatchRect = _backdrops[id]
		back.position = (_buttons[id] as TouchScreenButton).position
		back.size = Vector2(width, ROUND) if id in ["a", "b"] else PILL


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
