extends "res://scripts/ui/modal.gd"
## Keyboard/touch list menu in a window, with a title tab above it. Emits the chosen index, or -1 when cancelled.
## items: Array of String or Dictionary {text, right, disabled, desc, icon}
## opts: anchor, width, rows, cancel, start, on_focus (Callable), dim, title_size, margin; font_size: the rows' text
## size (UI units); bare: no box at all: the first option is a big glowing button in the gem, pulsing, with a shine
## sweeping across it (the title's "New Game"), and any others plain text under it

const UIKit = preload("res://scripts/ui/ui_kit.gd")


var title := ""
var items: Array = []
var opts: Dictionary = {}
var buttons: Array = []
var desc_label: Label = null
var _panel: PanelContainer
var _outer: VBoxContainer
var _scroll: ScrollContainer
var _pager: Control
var _row_h := 0.0
var _max_rows := 0
var _focus := -1
var _t := 0.0
## the bare menu's big button and the face drawn behind its text (see _draw_hero)
var _hero: Button
var _hero_face: Control
## its size in UI units, and how long the shine takes to cross it and then waits
const HERO_SIZE := Vector2(460, 104)
const SHINE_EVERY := 2.8
const SHINE_CROSS := 0.9


func setup(_title: String, _items: Array, _opts := {}) -> Control:
	title = _title
	opts = _opts
	items = []
	for it in _items:
		if typeof(it) == TYPE_DICTIONARY:
			items.append(it)
		else:
			items.append({"text": str(it)})
	dim = float(opts.get("dim", 0.0))
	return self


func _ready() -> void:
	var width := float(opts.get("width", 360)) * (1.25 if UIKit.touch_ui() else 1.1) + 40.0
	var outer := VBoxContainer.new()
	_outer = outer
	outer.add_theme_constant_override("separation", -2)
	add_child(outer)
	var title_lines := title.split("\n")
	if title != "":
		var rib := UIKit.ribbon(title_lines[0], true)
		rib.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		rib.z_index = 1
		outer.add_child(rib)
	_panel = UIKit.panel()
	outer.add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	_panel.add_child(vb)
	if title_lines.size() > 1:
		vb.add_child(Control.new())
		var sub := UIKit.label("\n".join(title_lines.slice(1)), 20, UIKit.DIM)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.custom_minimum_size.x = width
		vb.add_child(sub)
	elif title != "":
		var gap := Control.new()
		gap.custom_minimum_size.y = 6
		vb.add_child(gap)
	var has_icons := false
	for it in items:
		if it.has("icon") and it["icon"] != null:
			has_icons = true
	var row_h := UIKit.row_h() + (8.0 if has_icons else 0.0)
	var font_size := int(opts.get("font_size", UIKit.BUTTON_FONT_SIZE))
	font_size = maxi(font_size, UIKit.BUTTON_FONT_SIZE)
	if font_size > 0:
		row_h = maxf(row_h, font_size * 2.0)
	_row_h = row_h
	var bare: bool = opts.get("bare", false)
	if bare:
		_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var rows := int(opts.get("rows", 8))
	_max_rows = mini(rows, maxi(1, items.size()))
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 0)
	if bare:
		# nothing to scroll, and the button's glow and pulse reach past its edges (a scroll box would clip them)
		list.add_theme_constant_override("separation", 14)
		vb.add_child(list)
	else:
		var scroll := ScrollContainer.new()
		_scroll = scroll
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		scroll.custom_minimum_size = Vector2(width, row_h * mini(rows, maxi(1, items.size())) + 2)
		vb.add_child(scroll)
		scroll.add_child(list)
		# Prev / Next under a menu longer than it shows (see pager.gd)
		_pager = load("res://scripts/ui/pager.gd").new().setup(scroll)
		vb.add_child(_pager)
	for i in items.size():
		var it: Dictionary = items[i]
		var b := Button.new()
		b.text = it.get("text", "")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = it.get("disabled", false)
		b.custom_minimum_size = Vector2(0, row_h)
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if it.has("icon") and it["icon"] != null:
			b.icon = it["icon"]
			b.expand_icon = false
			b.add_theme_constant_override("icon_max_width", 56)
		if it.has("right"):
			var rl := UIKit.label(str(it["right"]), 20, UIKit.ACCENT if not b.disabled else UIKit.DIM)
			rl.add_theme_font_size_override("font_size", UIKit.body_px(UIKit.BUTTON_FONT_SIZE))
			rl.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
			rl.offset_left = -220
			rl.offset_right = -12
			rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(rl)
			_reserve_right(b, 150.0)
		if font_size > 0:
			b.add_theme_font_size_override("font_size", UIKit.body_px(font_size))
		if bare:
			_bare_button(b, i == 0)
		b.pressed.connect(_pick.bind(i))
		b.focus_entered.connect(_focused.bind(i))
		b.mouse_entered.connect(b.grab_focus)
		list.add_child(b)
		buttons.append(b)
	var has_desc := false
	for it in items:
		if it.has("desc"):
			has_desc = true
	if has_desc or opts.get("desc_box", false):
		vb.add_child(HSeparator.new())
		desc_label = UIKit.label("", 20, UIKit.TEXT)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		desc_label.custom_minimum_size = Vector2(width, 78)
		vb.add_child(desc_label)
	if items.is_empty():
		list.add_child(UIKit.label("(nothing here)", 20, UIKit.DIM))
	UIKit.place(outer, opts.get("anchor", "center"), opts.get("margin", Vector2(24, 24)))
	if _scroll != null:
		get_viewport().size_changed.connect(_fit_rows)
		_fit_rows.call_deferred()
	_grab_start.call_deferred()


## Fit whole, full-sized rows into the window, reserving the title, description and page buttons.
## Reserving the pager even while hidden prevents the list from oscillating between two heights.
func _fit_rows() -> void:
	if _scroll == null:
		return
	var margin: Vector2 = opts.get("margin", Vector2(24, 24))
	var anchor: String = opts.get("anchor", "center")
	UIKit.place(_outer, anchor, margin)
	var rect := _outer.get_global_rect()
	var reserve: float = UI.controls.menu_bottom_reserve(rect.position.x, rect.end.x)
	if anchor in ["bottom", "bottom_right"]:
		reserve = maxf(reserve, UI.bottom_reserve())
	var available := get_viewport().get_visible_rect().size.y - maxf(24.0, margin.y) * 2.0 - reserve
	var chrome := _outer.get_combined_minimum_size().y - _scroll.custom_minimum_size.y
	if not _pager.visible:
		chrome += _pager.get_combined_minimum_size().y + 4.0
	var rows := clampi(floori((available - chrome - 2.0) / _row_h), 1, _max_rows)
	_scroll.custom_minimum_size.y = rows * _row_h + 2.0
	_outer.reset_size()
	# Centre inside the usable height, rather than leaving the last rows/description under the touch pad.
	if anchor in ["center", "left", "right"]:
		_outer.offset_top = -_outer.size.y / 2.0 - reserve / 2.0
		_outer.offset_bottom = _outer.size.y / 2.0 - reserve / 2.0
	elif anchor in ["bottom", "bottom_right"]:
		_outer.offset_top = -margin.y - reserve - _outer.size.y
		_outer.offset_bottom = -margin.y - reserve
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and _scroll.is_ancestor_of(focused):
		_scroll.ensure_control_visible.call_deferred(focused)


## A bare menu's option: the first is the big glowing button, the rest plain outlined text (bright when picked).
func _bare_button(b: Button, hero: bool) -> void:
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_color_override("font_outline_color", UIKit.BROWN)
	if not hero:
		b.custom_minimum_size.y = UIKit.row_h()
		b.add_theme_font_size_override("font_size", UIKit.body_px(UIKit.BUTTON_FONT_SIZE))
		b.add_theme_constant_override("outline_size", 10)
		for c in ["font_color", "font_pressed_color"]:
			b.add_theme_color_override(c, UIKit.DIM)
		for c in ["font_focus_color", "font_hover_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(c, UIKit.LIGHT)
		return
	_hero = b
	b.custom_minimum_size = HERO_SIZE
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_constant_override("outline_size", 14)
	b.add_theme_constant_override("shadow_offset_y", 4)
	b.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	for c in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, UIKit.LIGHT)
	# the face is drawn behind the button's own text
	_hero_face = Control.new()
	_hero_face.show_behind_parent = true
	_hero_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_face.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hero_face.draw.connect(_draw_hero)
	b.add_child(_hero_face)
	# a slow, gentle swell
	b.resized.connect(func(): b.pivot_offset = b.size / 2.0)
	var pulse := b.create_tween().set_loops()
	pulse.tween_property(b, "scale", Vector2(1.06, 1.06), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(b, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _process(delta: float) -> void:
	_t += delta
	if _hero_face != null:
		_hero_face.queue_redraw()


## The big button: a soft glow in the gem that breathes with the pulse, a drop shadow, a pill in the gem (light at the
## top, deep at the bottom) with a glossy upper half, a pale border inside a dark edge, and every few seconds a band
## of light sweeping across it. Brighter while it's the picked option.
func _draw_hero() -> void:
	if UIKit.pixel():
		_draw_hero_pixel()
		return
	var rect := Rect2(Vector2.ZERO, _hero_face.size)
	var r := rect.size.y / 2.0
	var on := _hero.has_focus() or buttons.size() == 1
	var breath := 0.5 + 0.5 * sin(_t * TAU / 1.6)
	var g := UIKit.ACCENT
	# the gem at its brightest: full value at the top, deep and saturated at the bottom
	var glow := Color.from_hsv(g.h, g.s * 0.8, 1.0)
	for i in 7:
		var grow := 3.0 + float(i) * 6.0 + breath * 7.0
		var a := (0.30 if on else 0.08) * (1.0 - float(i) / 7.0) * (0.5 + 0.5 * breath)
		_hero_face.draw_colored_polygon(UIKit.CozyBox._round_rect(rect.grow(grow), r + grow), Color(glow, a))
	_hero_face.draw_colored_polygon(UIKit.CozyBox._round_rect(Rect2(rect.position + Vector2(0, 7), rect.size), r), Color(0, 0, 0, 0.4))
	var pill := UIKit.CozyBox._round_rect(rect, r)
	var top := Color.from_hsv(g.h, g.s * 0.62, 1.0) if on else g.darkened(0.1)
	var bottom := Color.from_hsv(g.h, minf(1.0, g.s * 1.1), g.v * 0.62) if on else g.darkened(0.6)
	var cols := PackedColorArray()
	for q in pill:
		cols.append(top.lerp(bottom, clampf(q.y / rect.size.y, 0.0, 1.0)))
	_hero_face.draw_polygon(pill, cols)
	# gloss across the top half
	var gloss := UIKit.CozyBox._round_rect(Rect2(rect.position + Vector2(r * 0.5, 5), Vector2(rect.size.x - r, rect.size.y * 0.42)), r * 0.5)
	_hero_face.draw_colored_polygon(gloss, Color(1, 1, 1, 0.16 if on else 0.07))
	# the shine: a slanted band of light, cut to the pill's shape
	var k := fposmod(_t, SHINE_EVERY) / SHINE_CROSS
	if on and k < 1.0:
		var x := lerpf(-rect.size.y, rect.size.x + rect.size.y * 0.2, k)
		var band := PackedVector2Array([Vector2(x, rect.size.y), Vector2(x + rect.size.y * 0.5, 0), Vector2(x + rect.size.y * 0.9, 0), Vector2(x + rect.size.y * 0.4, rect.size.y)])
		for part in Geometry2D.intersect_polygons(pill, band):
			_hero_face.draw_colored_polygon(part, Color(1, 1, 1, 0.42))
	# a dark edge round a thick pale border, so it stands out over anything behind it
	var edge := UIKit.CozyBox._round_rect(rect.grow(2.0), r + 2.0)
	edge.append(edge[0])
	_hero_face.draw_polyline(edge, Color(UIKit.BROWN, 0.9), 3.0, true)
	var rim := UIKit.CozyBox._round_rect(rect.grow(-2.5), r - 2.5)
	rim.append(rim[0])
	_hero_face.draw_polyline(rim, UIKit.BORDER if on else UIKit.DIM, 5.0, true)


## Pixel style: the 1-bit plate drawn big (its pixels four times the size), filled with the gem behind its white edge,
## ringed by crisp outlines in the gem that breathe outwards, over a hard drop shadow; every few seconds a band of
## light steps across it, a pixel row at a time.
func _draw_hero_pixel() -> void:
	var rect := Rect2(Vector2.ZERO, _hero_face.size)
	var on := _hero.has_focus() or buttons.size() == 1
	var breath := 0.5 + 0.5 * sin(_t * TAU / 1.6)
	var g := UIKit.ACCENT
	var glow := Color.from_hsv(g.h, g.s * 0.8, 1.0)
	for i in 4:
		var grow := 6.0 + float(i) * 6.0 + roundf(breath * 2.0) * 2.0
		_hero_face.draw_rect(rect.grow(grow), Color(glow, (0.55 if on else 0.15) * (1.0 - float(i) / 4.0) * (0.5 + 0.5 * breath)), false, 4.0)
	_hero_face.draw_rect(Rect2(rect.position + Vector2(0, 8), rect.size), Color(0, 0, 0, 0.45))
	_hero_face.draw_style_box(UIKit.pixel_plate(g if on else g.darkened(0.45), UIKit.PIXEL_LINE, 1.0, 4), rect)
	var k := fposmod(_t, SHINE_EVERY) / SHINE_CROSS
	if on and k < 1.0:
		var inner := rect.grow(-8.0)
		var x := lerpf(inner.position.x - inner.size.y, inner.end.x, k)
		var row := 4.0
		var y := inner.position.y
		while y < inner.end.y:
			var off := (inner.end.y - y) * 0.5
			var a := clampf(x + off, inner.position.x, inner.end.x)
			var b := clampf(x + off + inner.size.y * 0.4, inner.position.x, inner.end.x)
			if b > a:
				_hero_face.draw_rect(Rect2(a, y, b - a, minf(row, inner.end.y - y)), Color(1, 1, 1, 0.35))
			y += row


## Keeps a button's text clear of its right-hand label.
func _reserve_right(b: Button, px: float) -> void:
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 18
	empty.content_margin_right = 12 + px
	var hl := UIKit.highlight(px)
	for st in ["normal", "disabled"]:
		b.add_theme_stylebox_override(st, empty)
	for st in ["hover", "focus", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, hl)


func _grab_start() -> void:
	if buttons.is_empty():
		return
	var s := clampi(int(opts.get("start", 0)), 0, buttons.size() - 1)
	if buttons[s].disabled:
		for i in buttons.size():
			if not buttons[i].disabled:
				s = i
				break
	buttons[s].grab_focus()
	_focused(s)


func _focused(i: int) -> void:
	if _focus != -1 and _focus != i:
		Sfx.play("select")
	_focus = i
	if desc_label:
		desc_label.text = items[i].get("desc", "")
		_fit_rows.call_deferred()
	if opts.has("on_focus"):
		var cb: Callable = opts["on_focus"]
		if cb.is_valid():
			cb.call(i)


func _pick(i: int) -> void:
	if items[i].get("disabled", false):
		Sfx.play("error")
		return
	Sfx.play("confirm")
	close(i)


func on_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_cancel") and not ev.is_echo():
		if opts.get("cancel", true):
			Sfx.play("back")
			close(-1)
