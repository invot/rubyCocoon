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
	refresh()


func refresh() -> void:
	if _gem != UIKit.accent_name:
		_recolour()
	_touch_on = Prefs.touch_enabled() and not title_mode
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


## The d-pad and A/B step aside while a screen that is tapped directly (the Start book) is on top.
func _process(_delta: float) -> void:
	if not _touch_on or _buttons.is_empty():
		return
	var top = UI.stack.back() if is_instance_valid(UI) and not UI.stack.is_empty() else null
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


## Redraws the legend strip, key caps and pad faces in the current gem.
func _recolour() -> void:
	_gem = UIKit.accent_name
	legend.add_theme_stylebox_override("panel", _legend_style())
	for row in [_legend_row, _flute_row]:
		for item in row.get_children():
			var cap: PanelContainer = item.get_child(0)
			cap.add_theme_stylebox_override("panel", UIKit.box("frame", Vector4(2, -5, 2, -5)))
	_paint_pad()


# ---------------------------------------------------------------- desktop key legend
func _legend_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UIKit.WINDOW_BOTTOM, 0.94)
	sb.border_color = UIKit.BORDER
	sb.border_width_top = 2
	sb.corner_radius_top_left = 22
	sb.corner_radius_top_right = 22
	sb.corner_detail = 8
	sb.anti_aliasing = true
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	return sb


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
## A, B, Start and Pause's labels: they sink a little while their button is held
var _labels := {}


func _build_touch() -> void:
	touch_root = Node2D.new()
	# the faces are drawn smooth (soft edges and shading), so they are scaled smoothly too
	touch_root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(touch_root)
	_dpad_base = Sprite2D.new()
	_dpad_base.centered = false
	touch_root.add_child(_dpad_base)
	for dir in ["up", "down", "left", "right"]:
		_touch_button(dir, Vector2(ARM, ARM))
	for k in ["a", "b"]:
		var b2 := _touch_button(k, Vector2(ROUND, ROUND))
		var l := UIKit.label(k.to_upper(), UIKit.BODY_HUGE, UIKit.LIGHT)
		# big letters: 64 screen pixels on a 1080p phone (BoldPixels stays crisp on multiples of 16)
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
const PAD_STYLE := 5
const FACES := ["dpad", "up", "down", "left", "right", "a", "a_pressed", "b", "b_pressed", "pill", "pill_pressed"]


## (Re)draws every face in the current gem: kept ones straight away, else on a worker thread (until they're ready the
## buttons work, unpainted).
func _paint_pad() -> void:
	for k in _labels:
		(_labels[k] as Label).add_theme_color_override("font_shadow_color", Color(UIKit.BROWN, 0.85))
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
	var faces := {"dpad": _dpad_face(), "pill": _pill_face(false), "pill_pressed": _pill_face(true)}
	for dir in ["up", "down", "left", "right"]:
		faces[dir] = _arm_pressed(dir)
	for k in ["a", "b"]:
		faces[k] = _dome_face(k, false)
		faces[k + "_pressed"] = _dome_face(k, true)
	DirAccess.make_dir_recursive_absolute(PAD_CACHE + key)
	for f in faces:
		(faces[f] as Image).save_png(PAD_CACHE + key + "/" + f + ".png")
	_faces_painted.call_deferred(key, faces)


func _faces_painted(key: String, faces: Dictionary) -> void:
	if key != _pad_key():
		# the gem changed while they were being painted
		_paint_pad()
		return
	_show_faces(faces)


func _show_faces(faces: Dictionary) -> void:
	_dpad_base.texture = ImageTexture.create_from_image(faces["dpad"])
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


## The plate colour of the d-pad and pills (a deep shade of the gem), from the top (t = 0) to the bottom (t = 1).
static func _plate(t: float) -> Color:
	var g := UIKit.ACCENT
	return Color.from_hsv(g.h, g.s * 0.55, 0.40).lerp(Color.from_hsv(g.h, g.s * 0.62, 0.17), t)


## Shades a pixel near a face's edge: lit along the top, shadowed along the bottom (`n` points outwards).
static func _bevel(col: Color, d: float, n: Vector2, width := 7.0) -> Color:
	if d < 0.0 or d > width:
		return col
	var k := 1.0 - d / width
	var f := n.dot(Vector2(-0.3, -1.0).normalized())
	return col.lerp(Color.WHITE, 0.30 * f * k) if f > 0.0 else col.lerp(Color.BLACK, -0.40 * f * k)


static func _cover(d: float) -> float:
	return clampf(d + 0.5, 0.0, 1.0)


## The whole cross: a soft shadow, the rim, a top-lit gradient with bevelled edges, a dimple in the middle and pale
## raised arrows.
static func _dpad_face() -> Image:
	var n := int(ARM * 3.0)
	var img := Image.create(n, n + SHADOW_ROOM, false, Image.FORMAT_RGBA8)
	var rim := UIKit.BORDER
	var centre := Vector2(ARM * 1.5, ARM * 1.5)
	var arrow_col := Color.from_hsv(UIKit.ACCENT.h, UIKit.ACCENT.s * 0.12, 0.96)
	for y in img.get_height():
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5)
			var sh := _sd_cross(p - Vector2(0, 6))
			var col := Color(0, 0, 0, clampf((sh + 4.0) / 8.0, 0.0, 1.0) * 0.38)
			var d := _sd_cross(p)
			var a := _cover(d)
			if a > 0.0:
				var g := Vector2(_sd_cross(p + Vector2(1, 0)) - _sd_cross(p - Vector2(1, 0)), _sd_cross(p + Vector2(0, 1)) - _sd_cross(p - Vector2(0, 1)))
				var outward := -g.normalized() if g.length() > 0.001 else Vector2.ZERO
				var body := _plate(p.y / n)
				body = _bevel(body, d - 2.5, outward)
				# the dimple in the middle: a shallow bowl, dark at the top and lit at the bottom
				var dc := p.distance_to(centre)
				if dc < 24.0:
					var bowl := (p - centre) / 24.0
					body = body.lerp(Color.BLACK, 0.18).lerp(Color.WHITE, clampf(bowl.y, 0.0, 1.0) * 0.12)
				elif dc < 26.0:
					body = body.lerp(Color.WHITE, 0.10)
				for dir in ["up", "down", "left", "right"]:
					var ash := _sd_arrow(p - Vector2(0, 2), dir)
					if ash > -1.0:
						body = body.lerp(Color.BLACK, _cover(ash) * 0.35)
					var ad := _sd_arrow(p, dir)
					if ad > -1.0:
						body = body.lerp(arrow_col, _cover(ad))
				if d < 2.5:
					body = rim.lerp(rim.darkened(0.45), p.y / n)
				col = col.blend(Color(body, 0.94 * a))
			img.set_pixel(x, y, col)
	return img


## A pressed arm: its part of the cross sinks into shadow and its arrow lights up in the gem.
static func _arm_pressed(dir: String) -> Image:
	var off: Vector2 = {"up": Vector2(ARM, 0), "down": Vector2(ARM, ARM * 2.0), "left": Vector2(0, ARM), "right": Vector2(ARM * 2.0, ARM)}[dir]
	var n := int(ARM)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := off + Vector2(x + 0.5, y + 0.5)
			var d := _sd_cross(p)
			var col := Color(0, 0, 0, 0)
			if d > -0.5:
				col = Color(0, 0, 0, 0.30 * _cover(d - 2.5))
				var ad := _sd_arrow(p, dir)
				if ad > -1.0:
					col = col.blend(Color(UIKit.ACCENT.lightened(0.25), _cover(ad)))
			img.set_pixel(x, y, col)
	return img


## A or B: a round, domed button in the gem (B a deeper shade) with a pale rim, a top-lit bevel, a glossy highlight
## and a shadow below; pressed, it sinks onto its shadow and darkens.
static func _dome_face(which: String, pressed: bool) -> Image:
	var w := int(ROUND)
	var img := Image.create(w, w + SHADOW_ROOM, false, Image.FORMAT_RGBA8)
	var r := ROUND / 2.0 - 2.0
	var c := Vector2(ROUND / 2.0, ROUND / 2.0 + (3.0 if pressed else 0.0))
	var sc := Vector2(ROUND / 2.0, ROUND / 2.0 + (4.0 if pressed else 7.0))
	var g := UIKit.ACCENT
	var top := g.lightened(0.22) if which == "a" else g.darkened(0.12)
	var bottom := g.darkened(0.40) if which == "a" else g.darkened(0.62)
	if pressed:
		top = top.darkened(0.2)
		bottom = bottom.darkened(0.15)
	for y in img.get_height():
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var col := Color(0, 0, 0, clampf((r - p.distance_to(sc) + 3.0) / 6.0, 0.0, 1.0) * 0.40)
			var d := r - p.distance_to(c)
			var a := _cover(d)
			if a > 0.0:
				var t := clampf((p.y - (c.y - r)) / (2.0 * r), 0.0, 1.0)
				var body := top.lerp(bottom, t)
				body = _bevel(body, d - 3.0, (p - c).normalized(), 9.0)
				# a glossy highlight across the top of the dome
				var hd := ((p - (c + Vector2(-0.12 * r, -0.50 * r))) / Vector2(0.55 * r, 0.26 * r)).length()
				if hd < 1.0:
					body = body.lerp(Color.WHITE, (1.0 - hd) * (0.12 if pressed else 0.32))
				if d < 3.0:
					body = UIKit.BORDER.lerp(UIKit.BORDER.darkened(0.45), t)
				col = col.blend(Color(body, 0.94 * a))
			img.set_pixel(x, y, col)
	return img


## Start / Pause: a small pill plate in the d-pad's colours, raised on a shadow.
static func _pill_face(pressed: bool) -> Image:
	var sz := Vector2i(int(PILL.x), int(PILL.y) + SHADOW_ROOM)
	var img := Image.create(sz.x, sz.y, false, Image.FORMAT_RGBA8)
	var rect := Rect2(Vector2(0, 2.0 if pressed else 0.0), PILL).grow(-1)
	var shadow := Rect2(Vector2(0, 3.0 if pressed else 6.0), PILL).grow(-1)
	var rad := PILL.y / 2.0 - 1.0
	for y in sz.y:
		for x in sz.x:
			var p := Vector2(x + 0.5, y + 0.5)
			var col := Color(0, 0, 0, clampf((_sd_box(p, shadow, rad) + 3.0) / 6.0, 0.0, 1.0) * 0.38)
			var d := _sd_box(p, rect, rad)
			var a := _cover(d)
			if a > 0.0:
				var t := clampf((p.y - rect.position.y) / rect.size.y, 0.0, 1.0)
				var body := _plate(t)
				if pressed:
					body = body.lerp(UIKit.ACCENT, 0.45)
				var gr := Vector2(_sd_box(p + Vector2(1, 0), rect, rad) - _sd_box(p - Vector2(1, 0), rect, rad),
					_sd_box(p + Vector2(0, 1), rect, rad) - _sd_box(p - Vector2(0, 1), rect, rad))
				body = _bevel(body, d - 2.5, -gr.normalized() if gr.length() > 0.001 else Vector2.ZERO, 6.0)
				if d < 2.5:
					body = UIKit.BORDER.lerp(UIKit.BORDER.darkened(0.45), t)
				col = col.blend(Color(body, 0.94 * a))
			img.set_pixel(x, y, col)
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


## The title screen shows no buttons at all: its menu is tapped (or picked with the keys).
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
		_legend_row.visible = not on
		_flute_row.visible = on


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
		(_labels[id] as Label).position.y = (3.0 if id in ["a", "b"] else 2.0) if down else 0.0
	if down and PAD_PITCH.has(id) and not flute_mode:
		Sfx.play_tone("blip", PAD_PITCH[id], PAD_VOL)
	_send_actions(id, down)


func _send_actions(id: String, down: bool) -> void:
	var actions: Array = PAD_ACTIONS[id]
	if flute_mode and FLUTE_LANES.has(id):
		actions = [FLUTE_LANES[id]]
	elif id == "a" and down and not UI.stack.is_empty():
		# a menu, a dialog or the battle's command panel is on top: it takes A as either action, so one press sends just
		# one (two would confirm twice: a whole round of moves, or two pages of a dialog, from a single tap)
		actions = ["ui_accept"]
	for action in actions:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = down
		Input.parse_input_event(ev)


func _layout() -> void:
	if touch_root == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var pad := Vector2(28, vp.y - 28 - ARM * 3.0)
	_dpad_base.position = pad
	_buttons["up"].position = pad + Vector2(ARM, 0)
	_buttons["left"].position = pad + Vector2(0, ARM)
	_buttons["right"].position = pad + Vector2(ARM * 2.0, ARM)
	_buttons["down"].position = pad + Vector2(ARM, ARM * 2.0)
	_buttons["a"].position = Vector2(vp.x - 28 - ROUND, vp.y - 28 - ROUND - 70)
	_buttons["b"].position = Vector2(vp.x - 28 - ROUND - 124, vp.y - 28 - ROUND)
	_buttons["start"].position = Vector2(roundf(vp.x / 2.0) - PILL.x - 8, vp.y - 26 - PILL.y)
	_buttons["pause"].position = Vector2(roundf(vp.x / 2.0) + 8, vp.y - 26 - PILL.y)


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
		if not (_buttons[group[0]] as TouchScreenButton).visible:
			continue
		var zone := Rect2()
		for i in group.size():
			var b: TouchScreenButton = _buttons[group[i]]
			var r := Rect2(b.position, b.texture_normal.get_size())
			zone = r if i == 0 else zone.merge(r)
		if zone.grow(TOUCH_SLOP + NO_TAP_MARGIN).has_point(p):
			return true
	return false
