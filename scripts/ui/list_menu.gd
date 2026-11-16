extends "res://scripts/ui/modal.gd"
## Keyboard/touch list menu in a window, with a title tab above it. Emits the chosen index, or -1 when cancelled.
## items: Array of String or Dictionary {text, right, disabled, desc, icon}
## opts: anchor, width, rows, cancel, start, on_focus (Callable), dim, title_size, margin; font_size: the rows' text
## fixed_rows: reserve the same number of rows even for short or empty lists (paired inventory panes).
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
var _rail: Control
var _row_h := 0.0
var _max_rows := 0
var _focus := -1
var _confirming := false
var _t := 0.0
var _layout_anchor := "center"
var _layout_margin := Vector2(24, 24)
var _held_direction := 0
var _repeat_after := 0.0
## the bare menu's big button and the face drawn behind its text (see _draw_hero)
var _hero: Button
var _hero_face: Control
## its size in UI units, and how long the shine takes to cross it and then waits
const HERO_SIZE := Vector2(460, 104)
const SHINE_EVERY := 2.8
const SHINE_CROSS := 0.9
## opts.cancel_button (menus while talking to someone or on the phone, ui.gd choose): a small "B: Cancel" button in the
## gem under the window's right end, overlapping its bottom edge, in place of a "Leave" row (edge_button.gd).
## the shortest rows (desktop, touch) and their text size when a talk or phone menu shrinks to show every choice
const COMPACT_ROW := Vector2(48, 60)
const COMPACT_FONT := 28
var tab_buttons: Array = []
var _cancel_hit: Control
var _cancel_btn: Button
## opts.ab_buttons (the saved-games list): "A: Select" and "B: Cancel" hang side by side under the window's middle
var _select_hit: Control
const AB_GAP := 20.0
## opts.book_page (the saved games): a Control shown as the right-hand page, the list on the left one, the whole
## window the Start book's tan paper with its spine at the fold between them (book_paper.gd)
var _paper: Control
var _fold: Control
var _book_row: HBoxContainer
var _list_col: VBoxContainer


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
	_layout_anchor = opts.get("anchor", "center")
	_layout_margin = opts.get("margin", Vector2(24, 24))
	if UIKit.touch_ui() and not opts.get("bare", false) and not opts.get("keep_anchor", false):
		_layout_anchor = "center"
		_layout_margin = Vector2(24, 24)
	if opts.get("embedded", false):
		width = float(opts.get("width", 420))
	width = minf(width, get_viewport_rect().size.x - 48.0)
	if opts.has("tabs") and opts.get("beside_pad", false) and UIKit.touch_ui():
		# Four trainers must remain visible. Keep the rank window between both touch clusters,
		# rather than letting its far edge enter the opposite cluster and lose half its height.
		var between: float = get_viewport_rect().size.x - UI.controls.left_cluster_width() - UI.controls.right_cluster_width()
		width = minf(width, maxf(360.0, between - 48.0 - _tab_arrow_room() * 2.0))

	var outer := VBoxContainer.new()
	_outer = outer
	# a little space between the title's tab and the window under it
	outer.add_theme_constant_override("separation", 8)
	add_child(outer)
	var title_lines := title.split("\n")
	# (a menu with tabs shows them in place of its title tag, as the Start book does)
	if title != "" and not opts.has("tabs"):
		var rib := UIKit.ribbon(title_lines[0], true)
		rib.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		rib.z_index = 1
		outer.add_child(rib)
	if opts.has("tabs"):
		# rank tabs float over the window, like the Start book's (the user's direction, 2026-11-15)
		_make_tabs(outer)
	_panel = UIKit.panel()
	if opts.get("embedded", false):
		_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	_list_col = vb
	if opts.has("book_page"):
		_make_book(vb)
	else:
		_panel.add_child(vb)
	if title_lines.size() > 1:
		vb.add_child(Control.new())
		var sub := UIKit.label("\n".join(title_lines.slice(1)), 20, UIKit.DIM)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.custom_minimum_size.x = width
		vb.add_child(sub)
	elif title != "" and not opts.has("tabs"):
		var gap := Control.new()
		gap.custom_minimum_size.y = 6
		vb.add_child(gap)
	var has_icons := false
	for it in items:
		if it.has("icon") and it["icon"] != null:
			has_icons = true
	var row_h := UIKit.row_h() + (8.0 if has_icons and not opts.get("embedded", false) else 0.0)
	var font_size := int(opts.get("font_size", UIKit.BUTTON_FONT_SIZE))
	font_size = maxi(font_size, UIKit.BUTTON_FONT_SIZE)
	if font_size > 0:
		row_h = maxf(row_h, font_size * 2.0)
	_row_h = row_h
	var bare: bool = opts.get("bare", false)
	if bare:
		_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var rows := int(opts.get("rows", 8))
	_max_rows = rows if opts.get("fixed_rows", false) else mini(rows, maxi(1, items.size()))
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
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.custom_minimum_size = Vector2(0, row_h * _max_rows + 2)
		# up / down buttons beside a menu longer than it shows, taking their room from the rows (see scroll_rail.gd)
		var side := HBoxContainer.new()
		side.add_theme_constant_override("separation", 6)
		side.custom_minimum_size.x = width
		vb.add_child(side)
		side.add_child(scroll)
		scroll.add_child(list)
		_rail = load("res://scripts/ui/scroll_rail.gd").new().setup(scroll)
		_rail.enabled = not UIKit.touch_ui() or opts.get("keep_anchor", false)
		side.add_child(_rail)
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
			b.expand_icon = b.icon.has_meta("item_art") or opts.get("expand_icons", false)
			b.add_theme_constant_override("icon_max_width", int(opts.get("icon_width", 56)))
			b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if UI.Glyphs.smooth(b.icon) else CanvasItem.TEXTURE_FILTER_NEAREST
		if it.has("right"):
			var rl := UIKit.label(str(it["right"]), 20, UIKit.GOLD if not b.disabled else UIKit.DIM)
			UIKit.follow_row(b, rl, UIKit.GOLD if not b.disabled else UIKit.DIM)
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
		if not opts.get("embedded", false) and not opts.has("tabs"):
			b.mouse_entered.connect(b.grab_focus)
		list.add_child(b)
		buttons.append(b)
	var has_desc := false
	for it in items:
		if it.has("desc"):
			has_desc = true
	if has_desc or opts.get("desc_box", false):
		vb.add_child(HSeparator.new())
		desc_label = UIKit.label("", 24, UIKit.TEXT)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		desc_label.custom_minimum_size = Vector2(width, 78)
		vb.add_child(desc_label)
	if items.is_empty():
		list.add_child(UIKit.label("(nothing here)", 20, UIKit.DIM))
	# No Select / Back buttons: A picks the row and B goes back, as everywhere, and a row can be clicked or tapped.
	if opts.get("embedded", false):
		outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		return
	if (opts.get("cancel_button", false) or opts.get("ab_buttons", false)) and opts.get("cancel", true) and not bare:
		_make_cancel_button()
	if _paper != null and _cancel_hit != null:
		# the hanging A/B buttons cover only empty paper under the pages, never the list's scroll-down button
		var sb: StyleBox = _panel.get_theme_stylebox("panel")
		sb.content_margin_bottom += ceilf(_cancel_hit.button_size().y * _cancel_hit.OVERLAP) + 10.0
	UIKit.place(outer, _layout_anchor, _layout_margin)
	if _scroll != null:
		get_viewport().size_changed.connect(_fit_rows)
		UI.controls.layout_changed.connect(_fit_rows)
		_fit_rows.call_deferred()
	_grab_start.call_deferred()


## Fit whole, full-sized rows into the window, reserving the title and description.
func _fit_rows() -> void:
	if _scroll == null:
		return
	var margin := _layout_margin
	var anchor := _layout_anchor
	if anchor == "right" and opts.get("beside_pad", false) and UIKit.touch_ui():
		# beside the A/B buttons rather than over them, so the whole height is free for rows
		margin.x = maxf(margin.x, UI.controls.right_cluster_width())
	elif anchor == "left" and opts.get("beside_pad", false) and UIKit.touch_ui():
		# (beside the d-pad, likewise)
		margin.x = maxf(margin.x, UI.controls.left_cluster_width())
	# (room for a tab arrow outside the window's edge)
	margin.x += _tab_arrow_room()
	UIKit.place(_outer, anchor, margin)
	var rect := _outer.get_global_rect()
	var reserve: float = UI.controls.menu_bottom_reserve(rect.position.x, rect.end.x)
	if Prefs.is_desktop_web():
		reserve = maxf(reserve, UI.bottom_reserve())
	if UIKit.touch_ui() and anchor == "center":
		# Keep full-size choices in the middle; a little border overlap with the side pad is allowed.
		reserve = UI.bottom_reserve()
	if anchor in ["bottom", "bottom_right"]:
		reserve = maxf(reserve, UI.bottom_reserve())
	if _cancel_hit != null:
		# the B: Cancel button hangs below the window's bottom edge
		reserve += _cancel_overhang()
	var available := get_viewport().get_visible_rect().size.y - maxf(24.0, margin.y) * 2.0 - reserve
	var chrome := _outer.get_combined_minimum_size().y - _scroll.get_parent_control().get_combined_minimum_size().y
	if _book_row != null:
		# (a right-hand page taller than the list isn't the list's chrome)
		chrome -= maxf(0.0, _book_row.get_combined_minimum_size().y - _list_col.get_combined_minimum_size().y)
	var row_h := _row_h
	var rows := clampi(floori((available - chrome - 2.0) / row_h), 1, _max_rows)
	if opts.get("cancel_button", false) and not opts.get("fixed_rows", false) and rows < _max_rows:
		# Talking with someone or on the phone: rather than scroll for a row or two, the rows get a little shorter
		# (and their text a little smaller) until every choice fits, down to COMPACT_ROW (the user's direction,
		# 2026-11-14); a list longer than that still scrolls.
		var floor_h: float = COMPACT_ROW.y if UIKit.touch_ui() else COMPACT_ROW.x
		row_h = maxf(floor_h, floorf((available - chrome - 2.0) / _max_rows))
		rows = clampi(floori((available - chrome - 2.0) / row_h), 1, _max_rows)
	var compact := row_h < _row_h
	for b in buttons:
		b.custom_minimum_size.y = row_h
		if compact and not b.has_meta("compact"):
			# the theme pads a row's text up to the full row height; the shorter row centres it with less
			b.set_meta("compact", true)
			for st in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
				var box: StyleBox = b.get_theme_stylebox(st)
				if box != null:
					var source := box
					box = box.duplicate()
					# (a frame_box.gd style keeps its look in plain script variables, which duplicate() leaves behind)
					for field in ["frame", "line", "fill", "blur", "alpha", "legacy", "ring"]:
						if field in source:
							box.set(field, source.get(field))
					box.content_margin_top = 2.0
					box.content_margin_bottom = 2.0
					b.add_theme_stylebox_override(st, box)
		var px := UIKit.body_px(COMPACT_FONT if compact else int(opts.get("font_size", UIKit.BUTTON_FONT_SIZE)))
		b.add_theme_font_size_override("font_size", maxi(px, UIKit.body_px(COMPACT_FONT)))
	_scroll.custom_minimum_size.y = rows * row_h + 2.0
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


## A title menu's first option glows; secondary actions keep visible button frames.
func _bare_button(b: Button, hero: bool) -> void:
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_color_override("font_outline_color", UIKit.BROWN)
	if not hero:
		UIKit.plate_button(b)
		b.add_theme_constant_override("outline_size", 0)
		b.custom_minimum_size.y = UIKit.row_h()
		b.add_theme_font_size_override("font_size", UIKit.body_px(UIKit.BUTTON_FONT_SIZE))
		return
	_hero = b
	b.custom_minimum_size = HERO_SIZE
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# white text on the gem face while it's picked, dark on the off-white plate otherwise
	b.add_theme_constant_override("outline_size", 0)
	b.add_theme_color_override("font_color", UIKit.INK)
	for c in ["font_focus_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
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


## The window as an open book: the list on the left page, opts.book_page on the right, on the Start book's paper.
func _make_book(list_col: VBoxContainer) -> void:
	_paper = load("res://scripts/ui/book_paper.gd").new()
	add_child(_paper)
	move_child(_paper, _outer.get_index())
	# the window keeps only its padding: the paper behind it is the box (as book_menu.gd _page_margins)
	var src := UIKit.box("textfield")
	var sb := StyleBoxEmpty.new()
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sb.set_content_margin(side, src.get_content_margin(side))
	_panel.add_theme_stylebox_override("panel", sb)
	_book_row = HBoxContainer.new()
	_book_row.add_theme_constant_override("separation", 18)
	_panel.add_child(_book_row)
	_book_row.add_child(list_col)
	# the fold between the pages: the paper draws the spine there, so this only keeps its room
	var fold := VSeparator.new()
	fold.add_theme_stylebox_override("separator", StyleBoxEmpty.new())
	_fold = fold
	_book_row.add_child(fold)
	var page: Control = opts["book_page"]
	page.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_book_row.add_child(page)


## The paper follows the window, and its spine the fold.
func _place_paper() -> void:
	if _paper == null or _panel == null:
		return
	var r := _panel.get_global_rect()
	if _paper.global_position != r.position or _paper.size != r.size:
		_paper.global_position = r.position
		_paper.size = r.size
	var sx := _fold.get_global_rect().get_center().x - r.position.x
	if absf(sx - _paper.spine_x) > 0.5:
		_paper.spine_x = sx
		_paper.refresh()


func _make_cancel_button() -> void:
	_cancel_hit = load("res://scripts/ui/edge_button.gd").new().setup("B: Cancel")
	_cancel_btn = _cancel_hit.button
	_cancel_hit.pressed.connect(_cancel)
	add_child(_cancel_hit)
	if opts.get("ab_buttons", false):
		_select_hit = load("res://scripts/ui/edge_button.gd").new().setup("A: Select")
		_select_hit.pressed.connect(func():
			if _focus >= 0 and not closed:
				_pick(_focus))
		add_child(_select_hit)


func _cancel_overhang() -> float:
	return _cancel_hit.overhang()


func _place_cancel() -> void:
	if _cancel_hit == null or _panel == null:
		return
	var rect := _panel.get_global_rect()
	if _select_hit == null:
		_cancel_hit.place_under(rect)
		return
	# "A: Select" and "B: Cancel" side by side, centred under the window
	var wa: float = _select_hit.button_size().x
	var wb: float = _cancel_hit.button_size().x
	var left := rect.get_center().x - (wa + AB_GAP + wb) / 2.0
	_select_hit.place_at(rect, left)
	_cancel_hit.place_at(rect, left + wa + AB_GAP)


func _process(delta: float) -> void:
	_t += delta
	_place_paper()
	_place_cancel()
	# while the tabs have the cursor the open one pulses, as in the Start book (book_menu.gd _process)
	for k in tab_buttons.size():
		(tab_buttons[k] as Control).modulate = Color(1, 1, 1, 0.7 + 0.3 * absf(sin(_t * 4.0))) 			if _on_tabs and k == int(opts.get("tab", 0)) else Color.WHITE
	if _hero_face != null:
		_hero_face.queue_redraw()
	if _held_direction != 0:
		if UI.stack.is_empty() or UI.stack.back() != self:
			_held_direction = 0
		else:
			_repeat_after -= delta
			if _repeat_after <= 0.0:
				_step_focus(_held_direction)
				_repeat_after = 0.14


func _input(ev: InputEvent) -> void:
	if closed or UI.stack.is_empty() or UI.stack.back() != self:
		return
	if _on_tabs and ev.is_action_pressed("ui_accept") and not ev.is_echo():
		# A on the tabs goes down into the list
		_leave_tabs()
		get_viewport().set_input_as_handled()
		return
	if opts.has("tabs") and not ev.is_echo() and (ev.is_action_pressed("ui_left") or ev.is_action_pressed("ui_right")):
		var step := -1 if ev.is_action_pressed("ui_left") else 1
		# (no wrapping round: it stops at the first and last rank)
		_change_tab(clampi(int(opts.get("tab", 0)) + step, 0, opts["tabs"].size() - 1))
		get_viewport().set_input_as_handled()
		return
	var direction := -1 if ev.is_action("ui_up") else (1 if ev.is_action("ui_down") else 0)
	if direction == 0:
		return
	if ev.is_pressed():
		_step_focus(direction)
		if ev is InputEventAction:
			_held_direction = direction
			_repeat_after = 0.4
	elif _held_direction == direction:
		_held_direction = 0
	get_viewport().set_input_as_handled()


func _step_focus(direction: int) -> void:
	if buttons.is_empty():
		return
	if not tab_buttons.is_empty():
		# the tabs sit above the rows (the user's direction, 2026-11-15): ▲ from the top row goes up onto them, ▼ from
		# them comes back down to the top row
		if _on_tabs:
			if direction > 0:
				_leave_tabs()
			return
		if direction < 0 and _first_enabled() == maxi(_focus, 0):
			_enter_tabs()
			return
	for step in range(1, buttons.size() + 1):
		var index := posmod(maxi(_focus, 0) + step * direction, buttons.size())
		if not buttons[index].disabled:
			buttons[index].grab_focus()
			if _scroll != null:
				_scroll.ensure_control_visible.call_deferred(buttons[index])
			return


## The big button, the primary action: solid white with dark text while it's the picked option (a dark bordered
## plate otherwise), ringed by crisp outlines in the gem that breathe outwards; every few seconds a band of the gem
## sweeps across it.
func _draw_hero() -> void:
	if _hero_face.size.x <= 0.0 or _hero_face.size.y <= 0.0:
		return
	var rect := Rect2(Vector2.ZERO, _hero_face.size)
	var on := _hero.has_focus() or buttons.size() == 1
	var breath := 0.5 + 0.5 * sin(_t * TAU / 1.6)
	var glow := UIKit.ACCENT.lerp(Color.WHITE, 0.25)
	for i in 3:
		var grow := 6.0 + float(i) * 6.0 + roundf(breath * 2.0) * 2.0
		_hero_face.draw_rect(rect.grow(grow), Color(glow, (0.6 if on else 0.15) * (1.0 - float(i) / 3.0) * (0.5 + 0.5 * breath)), false, 2.0)
	if on:
		_hero_face.draw_style_box(UIKit.row_box(UIKit.ACCENT, Color(0, 0, 0, 0)), rect)
	else:
		_hero_face.draw_style_box(UIKit.row_box(Color(0, 0, 0, 0), UIKit.BORDER, 1.0, true), rect)
	var k := fposmod(_t, SHINE_EVERY) / SHINE_CROSS
	if on and k < 1.0:
		var inner := rect.grow(-8.0)
		var x := lerpf(inner.position.x - inner.size.y, inner.end.x, k)
		var a0 := clampf(x, inner.position.x, inner.end.x)
		var a1 := clampf(x + inner.size.y * 0.5, inner.position.x, inner.end.x)
		var b0 := clampf(x + inner.size.y * 0.5, inner.position.x, inner.end.x)
		var b1 := clampf(x + inner.size.y, inner.position.x, inner.end.x)
		if b1 > a0:
			_hero_face.draw_colored_polygon(PackedVector2Array([Vector2(a0, inner.end.y), Vector2(b0, inner.position.y),
				Vector2(b1, inner.position.y), Vector2(a1, inner.end.y)]), Color(1, 1, 1, 0.18))


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
	if _tabs_held.has(title):
		# (a new rank picked from the tabs: they keep the cursor)
		_tabs_held.erase(title)
		if not tab_buttons.is_empty():
			_enter_tabs(false)
			return
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
	_on_tabs = false
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
	if _confirming or closed:
		return
	if items[i].get("disabled", false):
		Sfx.play("error")
		return
	Sfx.play("confirm")
	if opts.has("confirm_pick"):
		_confirming = true
		_held_direction = 0
		set_process(false)
		hide()
		var accepted: bool = await opts["confirm_pick"].call(i, _panel)
		set_process(true)
		_confirming = false
		if not accepted:
			show()
			buttons[i].grab_focus()
			return
	if opts.has("on_pick"):
		opts["on_pick"].call(i)
		return
	close(i)


func on_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_cancel") and not ev.is_echo():
		_cancel()


func _cancel() -> void:
	if opts.get("cancel", true) and not closed and not _confirming:
		Sfx.play("back")
		close(-1)


## Unlocked ranks in ascending order, as rounded tabs floating over the window like the Start book's (book_menu.gd
## _style_tabs): the open one the gem with white text, the rest the window's off-white with dim text. Three show at a
## time in a strip that slides left or right to keep the open one in view; a gem arrow button stands outside the strip
## at either end, centred on it, only while there are tabs hidden on that side (it opens the nearest of them), and
## ◄/► stop at the first and last rank.
const TABS_SHOWN := 3
const TAB_SEP := 4.0
## the first tab the strip showed last time, per menu title, so it slides on from there
static var _tab_first := {}
var _tab_row: Control
var _tab_scroll: ScrollContainer
var _tab_arrows: Array = []
## whether the tabs have the cursor (▲ from the top row), and, per title, a rank change made from them so the next
## menu opens with the cursor still on the tabs
var _on_tabs := false
static var _tabs_held := {}


func _first_enabled() -> int:
	for i in buttons.size():
		if not buttons[i].disabled:
			return i
	return 0


## The cursor up onto the tabs: no row lit, the open tab pulsing.
func _enter_tabs(sound := true) -> void:
	_on_tabs = true
	var owner_now := get_viewport().gui_get_focus_owner()
	if owner_now != null and is_ancestor_of(owner_now):
		owner_now.release_focus()
	if sound:
		Sfx.play("select")


## The cursor back down to the top row.
func _leave_tabs() -> void:
	_on_tabs = false
	var i := _first_enabled()
	if i < buttons.size():
		buttons[i].grab_focus()
		if _scroll != null:
			_scroll.ensure_control_visible.call_deferred(buttons[i])


func _tab_h() -> float:
	return COMPACT_ROW.y if UIKit.touch_ui() else COMPACT_ROW.x


## How much room a tab arrow takes beside the window (0 when every tab shows).
func _tab_arrow_room() -> float:
	return _tab_h() + 8.0 if opts.has("tabs") and opts["tabs"].size() > TABS_SHOWN else 0.0


func _make_tabs(parent: Control) -> void:
	var tabs: Array = opts["tabs"]
	var n := tabs.size()
	var current := int(opts.get("tab", 0))
	var shown := mini(TABS_SHOWN, n)
	var before: int = _tab_first.get(title, clampi(current - 1, 0, maxi(0, n - shown)))
	var first := clampi(before, 0, maxi(0, n - shown))
	if current < first:
		first = current
	elif current > first + shown - 1:
		first = current - shown + 1
	_tab_first[title] = first
	var tab_h := _tab_h()
	_tab_row = Control.new()
	_tab_row.custom_minimum_size.y = tab_h
	_tab_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_tab_row)
	_tab_scroll = ScrollContainer.new()
	_tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tab_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tab_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_tab_row.add_child(_tab_scroll)
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", int(TAB_SEP))
	_tab_scroll.add_child(strip)
	for i in n:
		var b := Button.new()
		b.text = String(tabs[i])
		b.custom_minimum_size.y = tab_h
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		b.add_theme_font_size_override("font_size", UIKit.body_px(24))
		var open := i == current
		var sb: StyleBox = UIKit.chip(UIKit.ACCENT, Color(0, 0, 0, 0), 0.0, Vector4(6, -2, 6, -2)) if open 			else UIKit.FrameBox.make("row", Color(0, 0, 0, 0), UIKit.FILL, false, Vector4(10, 0, 10, 0))
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(st, sb)
		var col := UIKit.LIGHT if open else UIKit.DIM
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, col)
		b.pressed.connect(_change_tab.bind(i))
		strip.add_child(b)
		tab_buttons.append(b)
	# the arrows, outside the strip's ends
	for k in 2:
		var a := Button.new()
		a.focus_mode = Control.FOCUS_NONE
		# no plate: just the game's soft arrow (soft_arrow.gd) in the gem, pointing outwards
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			a.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		var glyph: Control = load("res://scripts/ui/soft_arrow.gd").make(Vector2.LEFT if k == 0 else Vector2.RIGHT, UIKit.ACCENT)
		glyph.fill = 0.8
		glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		a.add_child(glyph)
		a.size = Vector2(tab_h, tab_h)
		a.visible = first > 0 if k == 0 else first + shown < n
		a.pressed.connect(_change_tab.bind(first - 1 if k == 0 else first + shown))
		_tab_row.add_child(a)
		_tab_arrows.append(a)
	_tab_row.resized.connect(_lay_tabs.bind(shown, before, first))


## Sizes the tabs to the window's width, sets the arrows outside its ends, and slides the strip from where it was.
func _lay_tabs(shown: int, before: int, first: int) -> void:
	var w := _tab_row.size.x
	var tab_w := floorf((w - TAB_SEP * (shown - 1)) / shown)
	for b in tab_buttons:
		b.custom_minimum_size.x = tab_w
	var h := _tab_row.size.y
	_tab_arrows[0].position = Vector2(-h - 8.0, 0)
	_tab_arrows[1].position = Vector2(w + 8.0, 0)
	for a in _tab_arrows:
		a.size = Vector2(h, h)
	_scroll_tabs.call_deferred(tab_w + TAB_SEP, before, first)


## (a frame on, once the strip's new size is known) the first time, slides from where the strip was last time.
func _scroll_tabs(step: float, before: int, first: int) -> void:
	if not is_instance_valid(_tab_scroll):
		return
	if _tab_row.has_meta("slid"):
		if not _tab_row.has_meta("sliding"):
			_tab_scroll.scroll_horizontal = int(first * step)
		return
	_tab_row.set_meta("slid", true)
	if before == first:
		_tab_scroll.scroll_horizontal = int(first * step)
		return
	_tab_scroll.scroll_horizontal = int(before * step)
	_tab_row.set_meta("sliding", true)
	var tw := create_tween()
	tw.tween_property(_tab_scroll, "scroll_horizontal", int(first * step), 0.2).set_trans(Tween.TRANS_SINE)
	tw.finished.connect(func(): _tab_row.remove_meta("sliding"))


func _change_tab(index: int) -> void:
	if index == int(opts.get("tab", 0)):
		return
	if _on_tabs:
		_tabs_held[title] = true
	Sfx.play("page")
	close(-2 - index)
