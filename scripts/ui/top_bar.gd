extends PanelContainer
## The top bar: the one place at the top centre of the screen for short messages, owned by the UI autoload (UI.top_bar).
## An off-white box like every window (no border, no blur), hanging from the top edge of the screen with its bottom
## corners slightly rounded: [left icon] text [right icon]. It sits inside the device's safe area.
## - It has exactly three sizes (SIZES): small (one line, narrow), medium (one line, wide) and large (two lines, wide).
##   A message takes the smallest that holds it; text never shrinks. One that even the large size can't hold is split
##   into pages that show one after another (a long second line gets pages of its own).
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
## the text, all in Quattrocento Sans: the main line (notices, battle messages and place names) and the dim second line
const TEXT_SIZE := 24
const SUB_SIZE := 18
## gap under the safe area's top edge: none, the bar hangs from the top of the screen (its box reaches up past any
## safe-area inset to the screen's edge)
const TOP := 0.0
## the three sizes (UI units): [width, lines of text]
const SIZES := {"small": [360.0, 1], "medium": [640.0, 1], "large": [640.0, 2]}
const SIZE_ORDER := ["small", "medium", "large"]
## widest it may be (the large size), and the space kept free at either side of the screen
const MAX_W := 640.0
const SIDE := 24.0
## the strip's inner padding at its ends and top/bottom
const PAD_X := 34.0
const PAD_Y := 8.0
const GAP := 10.0
## how far the battle bars' left edges lean (floating_hud.gd, which keeps its look; the top bar itself is now square-sided)
const TAPER := 16.0
## the bottom corners' rounding
const RADIUS := 12.0
## how long each page of a long message shows in battle
const BATTLE_PAGE := 1.6

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
## which of SIZES the bar is showing
var size_name := "small"
## the pages of the message showing ([[text, sub], ...]) and which one is up
var _pages: Array = []
var _page := 0
var _page_time := 0.0
var _box: StyleBoxFlat


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
	_box = StyleBoxFlat.new()
	_box.anti_aliasing = true
	_box.corner_detail = 6
	_box.shadow_size = 10
	_box.shadow_offset = Vector2(0, 3)
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
	var priority: bool = opts.get("priority", false) and not battle
	if m["key"] != "":
		if not _msg.is_empty() and _msg["key"] == m["key"]:
			_merge(_msg, m)
			if not battle:
				_apply(_msg)
				# (shown again in full: back in if it was leaving, and its time starts over)
				_hold = 0.0
				if priority:
					_phase = "hold"
					_slide = 1.0
					_place()
				if _phase == "out":
					_phase = "in"
			return
		for i in _queue.size():
			var q: Dictionary = _queue[i]
			if q["key"] == m["key"]:
				_merge(q, m)
				if not priority:
					return
				_queue.remove_at(i)
				m = q
				break
	# Acquiring an item is immediate feedback. Arrival notices must not make the
	# player wait several seconds to learn what they just picked up.
	if priority:
		if not _msg.is_empty() and _msg["key"] != "place":
			_queue.push_front(_msg)
		_msg = m
		_apply(m)
		_phase = "hold"
		_hold = 0.0
		_slide = 1.0
		visible = true
		_place()
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
	var icon: Texture2D = m.get("icon", null)
	left_icon.texture = icon
	# (pixel art up to the slot's size stays sharp; a bigger picture, such as an egg, is smoothed as it shrinks)
	var smooth: bool = m.get("smooth", false) or UI.Glyphs.smooth(icon) or (icon != null and icon.get_width() > ICON)
	left_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if smooth else CanvasItem.TEXTURE_FILTER_NEAREST
	left_icon.visible = true
	right_icon.texture = null
	# (no right icon outside battle: its slot folds away)
	right_icon.visible = false
	_pages = _paginate(_shown_text(m), String(m.get("sub", "")))
	_page = 0
	_show_page()


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
	_pages = [["", ""]]
	_page = 0
	left_icon.texture = null
	right_icon.texture = null
	left_icon.visible = true
	right_icon.visible = true
	visible = true
	_show_page()


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
	left_icon.texture = null if ours else icon
	right_icon.texture = icon if ours else null
	var filter := CanvasItem.TEXTURE_FILTER_LINEAR if UI.Glyphs.smooth(icon) else CanvasItem.TEXTURE_FILTER_NEAREST
	left_icon.texture_filter = filter
	right_icon.texture_filter = filter
	_pages = _paginate(text, "")
	_page = 0
	_page_time = 0.0
	_show_page()


## The bar's lowest edge where it rests (UI units), for windows placed under it.
func bottom() -> float:
	return _shown_y() + size.y


# ---------------------------------------------------------------- layout
func _set_text(main: String, sub: String, heading: bool) -> void:
	# Place names use the same bold heading face as the rest of the interface.
	label.add_theme_font_override("font", UIKit.font_head() if heading else UIKit.font_body())
	label.add_theme_font_size_override("font_size", UIKit.body_px(TEXT_SIZE))
	label.add_theme_color_override("font_color", UIKit.HEAD if heading else UIKit.INK)
	label.text = main
	sub_label.add_theme_font_override("font", UIKit.font_bold())
	sub_label.add_theme_font_size_override("font_size", UIKit.body_px(SUB_SIZE))
	sub_label.add_theme_color_override("font_color", UIKit.DIM)
	sub_label.text = sub
	sub_label.visible = sub != ""


func _max_w() -> float:
	var room := _safe_rect().size.x - SIDE * 2.0
	if battle and _battle_max > 0.0:
		return minf(_battle_max, room)
	return minf(MAX_W, room)


## How wide one of the sizes is here (never past the room on screen).
func _size_w(which: String) -> float:
	return minf(float(SIZES[which][0]), _max_w())


## The room for text inside a size, past the padding and the icon slots in use.
func _text_w(which: String) -> float:
	var two := battle
	var fixed := PAD_X * 2.0 + ICON * (2.0 if two else 1.0) + GAP * (2.0 if two else 1.0)
	return maxf(80.0, _size_w(which) - fixed)


## How many lines `text` takes at `w` in the main face (`heading`: the bold face) or the second line's.
func _lines(text: String, w: float, sub := false, heading := false) -> int:
	if text == "":
		return 0
	var font: Font = UIKit.font_bold() if sub else (UIKit.font_head() if heading else UIKit.font_body())
	var fs := UIKit.body_px(SUB_SIZE if sub else TEXT_SIZE)
	var shown := text.to_upper() if sub else text
	var h := font.get_multiline_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, w, fs, -1,
		TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE).y
	return maxi(1, int(round(h / font.get_height(fs))))


## Splits a message into pages that each fit the large size: [[text, sub], ...]. Most messages are one page; a second
## line that won't fit beside the first gets pages of its own, shown in the main face.
func _paginate(text: String, sub: String) -> Array:
	var w := _text_w("large")
	var heading := bool(_msg.get("heading", false)) if not battle else false
	if sub == "" and _lines(text, w, false, heading) <= 2:
		return [[text, ""]]
	if sub != "" and _lines(text, w, false, heading) == 1 and _lines(sub, w, true) == 1:
		return [[text, sub]]
	var pages: Array = []
	for part in [text, sub]:
		if part == "":
			continue
		var cur := ""
		for word in String(part).split(" ", false):
			var next: String = word if cur == "" else cur + " " + word
			if cur != "" and _lines(next, w, false, heading and part == text) > 2:
				pages.append([cur, ""])
				cur = word
			else:
				cur = next
		if cur != "":
			pages.append([cur, ""])
	return pages if not pages.is_empty() else [["", ""]]


## Shows the current page in the smallest size that holds it.
func _show_page() -> void:
	var p: Array = _pages[_page] if _page < _pages.size() else ["", ""]
	var heading := bool(_msg.get("heading", false)) and not battle and _page == 0
	_set_text(String(p[0]), String(p[1]), heading)
	_fit()


## Picks the size: small or medium when the page is one line there, else large (two lines).
func _fit() -> void:
	var main := label.text
	var sub := sub_label.text if sub_label.visible else ""
	var heading := label.get_theme_font("font") == UIKit.font_head()
	size_name = "large"
	if sub == "":
		for which in ["small", "medium"]:
			if _lines(main, _text_w(which), false, heading) <= 1:
				size_name = which
				break
	var lines := int(SIZES[size_name][1])
	var line_h := UIKit.font_body().get_height(UIKit.body_px(TEXT_SIZE))
	var tw := _text_w(size_name)
	label.custom_minimum_size.x = ceilf(tw)
	sub_label.custom_minimum_size.x = ceilf(tw)
	custom_minimum_size = Vector2(_size_w(size_name), ceilf(maxf(ICON, line_h * lines) + PAD_Y * 2.0))
	reset_size()
	# (wrapped labels settle their height over the next frames)
	_settle = 2
	material = null
	queue_redraw()
	_place()


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
		if _page < _pages.size() - 1:
			_page_time += delta
			if _page_time >= BATTLE_PAGE:
				_page_time = 0.0
				_page += 1
				_show_page()
	else:
		match _phase:
			"in":
				_slide = move_toward(_slide, 1.0, delta / SLIDE)
				if _slide >= 1.0:
					_phase = "hold"
			"hold":
				_hold += delta
				if _hold >= float(_msg.get("hold", HOLD)):
					if _page < _pages.size() - 1:
						# the next page of a long message, in place
						_page += 1
						_hold = 0.0
						_show_page()
					else:
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
## The box: the windows' off-white (no border, no blur), its bottom corners slightly rounded, with a soft shadow.
func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	# (the box starts at the screen's top edge, above the safe area's inset if there is one)
	var up := -maxf(0.0, _shown_y())
	_box.bg_color = Color(FrameBox.paper, FrameBox.PAPER_ALPHA)
	_box.shadow_color = FrameBox.SHADOW
	_box.corner_radius_top_left = 0
	_box.corner_radius_top_right = 0
	_box.corner_radius_bottom_left = int(RADIUS)
	_box.corner_radius_bottom_right = int(RADIUS)
	draw_style_box(_box, Rect2(0, up, r.size.x, r.size.y - up))
