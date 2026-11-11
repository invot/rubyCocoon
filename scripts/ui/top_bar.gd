extends PanelContainer
## The top bar: the one place at the top centre of the screen for short messages, owned by the UI autoload (UI.top_bar).
## A dark box like every window (the blurred scene under the windows' near-black, framed in white), its sides tapered
## in a little towards the bottom, hanging from the top edge of the screen with no top border: [left icon] text [right icon], with no divider ornaments inside it. It sits inside
## the device's safe area and grows with its text up to a maximum width, then wraps.
## - Outside battle it is hidden until there is something to say (UI.toast, UI.pickup, UI.place_name): it slides
##   down, holds for HOLD seconds and slides away, one message after another. Messages with the same key merge into the
##   one showing or waiting ("Potion x3"). These always have a left icon and never a right one.
## - In battle (begin_battle .. end_battle) it is always there and shows the battle's messages (battle.gd msg): the
##   icon of whoever a message is about stands on the left for the opposing side and on the right for yours, and the
##   unused slot keeps its space so the text doesn't jump. Notices posted meanwhile wait for the battle to end.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const FrameBox = preload("res://scripts/ui/frame_box.gd")

## seconds a message stays fully shown outside battle, and to slide in or out
const HOLD := 2.5
const SLIDE := 0.25
## the icon slots (UI units): a 12-pixel glyph at 3 units a pixel
const ICON := 36.0
## the text, all in League Spartan: the main line (notices, battle messages and place names) and the dim second line
const TEXT_SIZE := 24
const SUB_SIZE := 18
## gap under the safe area's top edge: none, the bar hangs from the top of the screen (its box reaches up past any
## safe-area inset to the screen's edge, and has no top border)
const TOP := 0.0
## widest outside battle (UI units), and the space kept free at either side of the screen
const MAX_W := 860.0
const SIDE := 24.0
## the strip's inner padding at its ends and top/bottom
const PAD_X := 34.0
const PAD_Y := 8.0
const GAP := 10.0
## how far each side leans in from the top corners to the bottom ones
const TAPER := 16.0
## darker than a window: it holds short lines of text over whatever the scene is
const SHADE_ALPHA := 0.78

var battle := false
var label: Label
var sub_label: Label
var left_icon: TextureRect
var right_icon: TextureRect
var _row: HBoxContainer

var _queue: Array = []
## the message showing outside battle: {text, fmt, count, icon, sub, heading, key, smooth}
var _msg: Dictionary = {}
## "" (hidden), "in", "hold", "out"
var _phase := ""
var _hold := 0.0
## 0 hidden .. 1 shown
var _slide := 0.0
var _battle_max := 0.0
var _settle := 0
var _marker: ImageTexture


func _init() -> void:
	name = "TopBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := StyleBoxEmpty.new()
	pad.content_margin_left = PAD_X
	pad.content_margin_right = PAD_X
	pad.content_margin_top = PAD_Y
	pad.content_margin_bottom = PAD_Y
	add_theme_stylebox_override("panel", pad)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", int(GAP))
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	left_icon = _slot()
	_row.add_child(left_icon)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 0)
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(texts)
	label = UIKit.label("", TEXT_SIZE, UIKit.INK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(label)
	sub_label = UIKit.label("", SUB_SIZE, UIKit.DIM)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_label.visible = false
	texts.add_child(sub_label)
	right_icon = _slot()
	_row.add_child(right_icon)
	visible = false
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0, 1, 1))
	_marker = ImageTexture.create_from_image(img)
	resized.connect(queue_redraw)


func _slot() -> TextureRect:
	var t := TextureRect.new()
	t.custom_minimum_size = Vector2(ICON, ICON)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


# ---------------------------------------------------------------- outside battle
## Queues a message. opts: sub (a dim second line), heading (the gem heading colour: place names), key (messages with the same
## key merge, adding their counts; with replace, the newer one takes the older one's place), count, fmt (with a count:
## "%d" is replaced by it; without: " x<count>" is added past 1), smooth (a smooth icon rather than pixel art), hold
## (seconds it stays up instead of HOLD: a film's controls at the start of each scene).
func post(text: String, icon: Texture2D, opts := {}) -> void:
	var m := {"text": text, "icon": icon, "sub": String(opts.get("sub", "")), "heading": bool(opts.get("heading", false)),
		"key": String(opts.get("key", "")), "count": int(opts.get("count", 1)), "fmt": String(opts.get("fmt", "")),
		"smooth": bool(opts.get("smooth", false)), "replace": bool(opts.get("replace", false)), "hold": float(opts.get("hold", HOLD))}
	if m["key"] != "":
		if not _msg.is_empty() and _msg["key"] == m["key"]:
			_merge(_msg, m)
			if not battle:
				_apply(_msg)
				# (shown again in full: back in if it was leaving, and its time starts over)
				_hold = 0.0
				if _phase == "out":
					_phase = "in"
			return
		for q in _queue:
			if q["key"] == m["key"]:
				_merge(q, m)
				return
	_queue.append(m)
	if _phase == "" and not battle:
		_next()


## How many messages are showing or waiting (outside battle).
func pending() -> int:
	return _queue.size() + (0 if _msg.is_empty() else 1)


## The text on the bar now ("" when it's hidden).
func current_text() -> String:
	return label.text if visible else ""


func _merge(into: Dictionary, m: Dictionary) -> void:
	if m.get("replace", false):
		into.merge(m, true)
		return
	into["count"] = int(into["count"]) + int(m["count"])
	into["sub"] = m["sub"]
	into["icon"] = m["icon"]


func _shown_text(m: Dictionary) -> String:
	var n := int(m.get("count", 1))
	var fmt := String(m.get("fmt", ""))
	if fmt != "":
		return fmt % n
	return String(m["text"]) + (" x%d" % n if n > 1 else "")


func _next() -> void:
	if _queue.is_empty():
		_msg = {}
		_phase = ""
		visible = false
		return
	_msg = _queue.pop_front()
	_apply(_msg)
	_phase = "in"
	_hold = 0.0
	_slide = 0.0
	visible = true
	_place()


func _apply(m: Dictionary) -> void:
	_set_text(_shown_text(m), String(m.get("sub", "")), bool(m.get("heading", false)))
	var icon: Texture2D = m.get("icon", null)
	left_icon.texture = icon
	# (pixel art up to the slot's size stays sharp; a bigger picture, such as an egg, is smoothed as it shrinks)
	var smooth: bool = m.get("smooth", false) or UI.Glyphs.smooth(icon) or (icon != null and icon.get_width() > ICON)
	left_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if smooth else CanvasItem.TEXTURE_FILTER_NEAREST
	left_icon.visible = true
	right_icon.texture = null
	# (no right icon outside battle: its slot folds away)
	right_icon.visible = false
	_fit(_max_w())


# ---------------------------------------------------------------- battle
## The battle has started: the bar stays shown with the battle's messages until end_battle. A notice that was showing
## goes back to the front of the queue (unless it had mostly been read).
func begin_battle() -> void:
	if battle:
		return
	battle = true
	if not _msg.is_empty() and _phase in ["in", "hold"] and _hold < HOLD * 0.5:
		_queue.push_front(_msg)
	_msg = {}
	_phase = ""
	_set_text("", "", false)
	left_icon.texture = null
	right_icon.texture = null
	left_icon.visible = true
	right_icon.visible = true
	visible = true
	_fit(_max_w())


## Back to notices: the bar slides away, then any notices that came in meanwhile follow.
func end_battle() -> void:
	if not battle:
		return
	battle = false
	_phase = "out" if visible else ""
	if _phase == "":
		_next()


## A battle message: `icon` (who it's about) stands on the right for your side (`ours`), on the left for the other.
## `max_w`: the widest the bar may be (UI units; 0 keeps the last), so it stays clear of the foe's grid.
func say_battle(text: String, icon: Texture2D, ours: bool, max_w := 0.0) -> void:
	if not battle:
		begin_battle()
	if max_w > 0.0:
		_battle_max = max_w
	_set_text(text, "", false)
	left_icon.texture = null if ours else icon
	right_icon.texture = icon if ours else null
	var filter := CanvasItem.TEXTURE_FILTER_LINEAR if UI.Glyphs.smooth(icon) else CanvasItem.TEXTURE_FILTER_NEAREST
	left_icon.texture_filter = filter
	right_icon.texture_filter = filter
	_fit(_max_w())


## The bar's lowest edge where it rests (UI units), for windows placed under it.
func bottom() -> float:
	return _shown_y() + size.y


# ---------------------------------------------------------------- layout
func _set_text(main: String, sub: String, heading: bool) -> void:
	# Place names use the same semibold heading weight as the rest of the interface.
	label.add_theme_font_override("font", UIKit.font_head() if heading else UIKit.font_body())
	label.add_theme_font_size_override("font_size", UIKit.body_px(TEXT_SIZE))
	label.add_theme_color_override("font_color", UIKit.HEAD if heading else UIKit.INK)
	label.text = main
	sub_label.add_theme_font_override("font", UIKit.font_body())
	sub_label.add_theme_font_size_override("font_size", UIKit.body_px(SUB_SIZE))
	sub_label.add_theme_color_override("font_color", UIKit.DIM)
	sub_label.text = sub
	sub_label.visible = sub != ""


func _max_w() -> float:
	var room := _safe_rect().size.x - SIDE * 2.0
	if battle and _battle_max > 0.0:
		return minf(_battle_max, room)
	return minf(MAX_W, room)


## Fits the text to its words, up to the widest the bar may be (then it wraps).
func _fit(max_w: float) -> void:
	var slots := ICON * (2.0 if right_icon.visible else 1.0)
	var fixed := PAD_X * 2.0 + slots + GAP * (2.0 if right_icon.visible else 1.0)
	var room := maxf(80.0, max_w - fixed)
	var w := minf(room, maxf(_natural(label), _natural(sub_label) if sub_label.visible else 0.0))
	label.custom_minimum_size.x = ceilf(w)
	sub_label.custom_minimum_size.x = ceilf(w)
	reset_size()
	# (wrapped labels settle their height over the next frames)
	_settle = 2
	var want: Material = FrameBox.material() if FrameBox.blur_on else null
	if material != want:
		material = want
		queue_redraw()
	_place()


func _natural(l: Label) -> float:
	if l.text == "":
		return 0.0
	var font := l.get_theme_font("font")
	var fs := l.get_theme_font_size("font_size")
	return font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 2.0


## The part of the screen clear of notches and rounded corners (UI units).
func _safe_rect() -> Rect2:
	return UIKit.safe_rect(self)


func _shown_y() -> float:
	return _safe_rect().position.y + TOP


func _place() -> void:
	var safe := _safe_rect()
	var x := clampf(roundf((get_viewport_rect().size.x - size.x) * 0.5), safe.position.x, maxf(safe.position.x, safe.end.x - size.x))
	var t := 1.0 - pow(1.0 - _slide, 3.0)
	position = Vector2(x, roundf(lerpf(-size.y - 12.0, _shown_y(), t)))


func _process(delta: float) -> void:
	if _settle > 0:
		_settle -= 1
		reset_size()
	if battle:
		_slide = move_toward(_slide, 1.0, delta / SLIDE)
	else:
		match _phase:
			"in":
				_slide = move_toward(_slide, 1.0, delta / SLIDE)
				if _slide >= 1.0:
					_phase = "hold"
			"hold":
				_hold += delta
				if _hold >= float(_msg.get("hold", HOLD)):
					_phase = "out"
			"out":
				_slide = move_toward(_slide, 0.0, delta / SLIDE)
				if _slide <= 0.0:
					_msg = {}
					_phase = ""
					visible = false
					_next()
	if visible:
		_place()


# ---------------------------------------------------------------- drawing
## The box: the blurred scene (the windows' shared blur, FrameBox) under the windows' near-black, outlined in white,
## its sides leaning in towards the bottom.
func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	var t := minf(TAPER, r.size.x * 0.2)
	# (the box starts at the screen's top edge, above the safe area's inset if there is one)
	var up := -maxf(0.0, _shown_y())
	var pts := PackedVector2Array([Vector2(0, up), Vector2(r.size.x, up), Vector2(r.size.x - t, r.size.y), Vector2(t, r.size.y)])
	var uvs := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	var blurred := FrameBox.blur_on and material != null
	if blurred:
		draw_colored_polygon(pts, Color.WHITE, uvs, _marker)
	draw_colored_polygon(pts, Color(FrameBox.shade, SHADE_ALPHA if blurred else maxf(SHADE_ALPHA, FrameBox.PLAIN_ALPHA)))
	# the outline, drawn just inside the shape on whole screen pixels: the two sides and the bottom, no top edge
	var w := FrameBox.unit
	var h := w / 2.0
	var k := t / (r.size.y - up)
	var line := PackedVector2Array([Vector2(h, up), Vector2(t + h - k * h, r.size.y - h),
		Vector2(r.size.x - t - h + k * h, r.size.y - h), Vector2(r.size.x - h, up)])
	draw_polyline(line, UIKit.BORDER, w, true)
