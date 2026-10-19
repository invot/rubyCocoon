extends "res://scripts/ui/modal.gd"
## The Start menu: one large window with a strip of tabs across the top and two panes, a list on the left and the
## chosen row's details on the right (the menus of the early PS2 RPGs). In the Pixel style (UIKit.style) the panes are
## the Humble Gift kit's two paper pages, dark with the gem and lined in white: they unfold as the book opens, the
## right one slides out from behind the left whenever a tab opens, and the page titles write themselves in.
## Tabs: Trainer, Beasts, Flute, Bag, Bestiary, Map, Settings.
## Controls: ←/→ switch tabs, ↑/↓ choose, A to act, S (back) returns to the tabs / closes, Start closes.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Bar = preload("res://scripts/ui/bar.gd")
const VoxelPortrait = preload("res://scripts/ui/voxel_portrait.gd")
const RaceDB = preload("res://scripts/data/race_db.gd")
const MoveDB = preload("res://scripts/data/move_db.gd")
const SongDB = preload("res://scripts/data/song_db.gd")
const ItemDB = preload("res://scripts/data/item_db.gd")
const WorldDB = preload("res://scripts/data/world_db.gd")
const Elements = preload("res://scripts/data/elements.gd")
const PixelArt = preload("res://scripts/gfx/pixel_art.gd")
const Ring = preload("res://scripts/core/ring.gd")
const RingView = preload("res://scripts/ui/ring_view.gd")
const Pager = preload("res://scripts/ui/pager.gd")

const TABS := [
	{"id": "trainer", "name": "Trainer", "icon": "tab_trainer"},
	{"id": "beasts", "name": "Beasts", "icon": "tab_beasts"},
	{"id": "flute", "name": "Flute", "icon": "icon_notes"},
	{"id": "bag", "name": "Bag", "icon": "tab_bag"},
	{"id": "bestiary", "name": "Bestiary", "icon": "icon_quill"},
	{"id": "map", "name": "Map", "icon": "icon_map"},
	{"id": "settings", "name": "Settings", "icon": "tab_settings"},
]
## the tab strip's height, and the gap between the tabs and the window
const TAB_H := 64.0
const TAB_GAP := 6.0
## the left (list) pane's share of the window
const LEFT_SHARE := 0.46
## Pixel style: the gap between the two pages, and how far in from a page's edge its ornament frame runs (in the
## kit's pixels: see _draw_frame)
const PAGE_GAP := 12.0
const FRAME_INSET := Vector2(12, 14)
const SLOT_SHORT := {"flute": "Flute", "head": "Hat", "feet": "Boots", "acc": "Charm"}
const CREST_ICONS := {"Wave Crest": "crest_wave", "Coral Crest": "crest_coral", "Spur Crest": "crest_spur", "Ore Crest": "crest_ore",
	"Cog Crest": "crest_cog", "Flame Crest": "crest_flame", "Vine Crest": "crest_vine", "River Crest": "crest_river"}
const ARENA_ORDER := ["tidewater", "kelpwick", "sundown", "copperpick", "cogsworth", "emberfall", "vinehollow", "riverbend"]

static var last_tab := 1
## On a phone the d-pad and A/B buttons hide while the book is on top: its rows and tabs are tapped directly, and
## Start closes it (see controls_overlay.gd).
var hides_touch_pad := true

var world = null
var tab := 1
var mode := "list"
var book: Control
var markers: Array = []
var window: PanelContainer
## Pixel style: the pages (placed by hand, so the right one can slide) and the style the book was built in
var pages: Control
var left_page: PanelContainer
var right_page: PanelContainer
var _built_style := ""
var _slide: Tween
var tab_strip: HBoxContainer
var left_box: VBoxContainer
var right_box: VBoxContainer
var list_box: VBoxContainer
var list_scroll: ScrollContainer
var detail_box: VBoxContainer
var rows: Array = []
var row_buttons: Array = []
var focus_row := 0
var _t := 0.0
var _keep_row := -1


func setup(_world, start_tab := "") -> Control:
	world = _world
	dim = 0.55
	tab = last_tab
	for i in TABS.size():
		if TABS[i]["id"] == start_tab:
			tab = i
	return self


func _exit_tree() -> void:
	if UI.controls:
		UI.controls.show_legend(false)


func _ready() -> void:
	if UI.controls:
		UI.controls.show_legend(true)
	Sfx.play("open")
	_build()
	resized.connect(_layout)
	if is_instance_valid(Prefs):
		Prefs.changed.connect(_on_prefs_changed)
	_open_tab(tab)
	if UIKit.pixel():
		_unfold()


## The tabs, the window and its two panes, in the style the interface is in now.
func _build() -> void:
	_built_style = UIKit.style
	markers = []
	book = Control.new()
	book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(book)
	# the tabs: an icon and a name each; the open one is filled with the accent
	tab_strip = HBoxContainer.new()
	tab_strip.add_theme_constant_override("separation", 4)
	tab_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book.add_child(tab_strip)
	for i in TABS.size():
		var m := Button.new()
		m.focus_mode = Control.FOCUS_NONE
		m.icon = UIKit.tex(TABS[i]["icon"])
		m.expand_icon = false
		m.add_theme_constant_override("icon_max_width", 36)
		m.text = TABS[i]["name"]
		m.add_theme_font_size_override("font_size", UIKit.head_px(UIKit.HEAD_SMALL))
		m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		m.custom_minimum_size.y = TAB_H
		m.pressed.connect(_click_tab.bind(i))
		tab_strip.add_child(m)
		markers.append(m)
	if UIKit.pixel():
		_build_pages()
		_layout()
		return
	window = PanelContainer.new()
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book.add_child(window)
	var panes := HBoxContainer.new()
	panes.add_theme_constant_override("separation", 18)
	panes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.add_child(panes)
	left_box = VBoxContainer.new()
	left_box.add_theme_constant_override("separation", 8)
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_box.size_flags_stretch_ratio = LEFT_SHARE
	left_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panes.add_child(left_box)
	var divider := VSeparator.new()
	var line := StyleBoxLine.new()
	line.vertical = true
	line.color = UIKit.BORDER_INNER
	line.thickness = 2
	divider.add_theme_stylebox_override("separator", line)
	panes.add_child(divider)
	# the detail pane scrolls, so a tall page (a beast's skills and family tree on a phone) never pushes the window
	# off the screen
	var right_scroll := ScrollContainer.new()
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_stretch_ratio = 1.0 - LEFT_SHARE
	# with Prev / Next under it once it runs past a page (see pager.gd)
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_stretch_ratio = 1.0 - LEFT_SHARE
	right_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panes.add_child(right_col)
	right_col.add_child(right_scroll)
	right_col.add_child(Pager.new().setup(right_scroll))
	right_box = VBoxContainer.new()
	right_box.add_theme_constant_override("separation", 8)
	right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_scroll.add_child(right_box)
	_layout()


## Pixel style: the two pages. The right one is drawn first, so it slides out from behind the left.
func _build_pages() -> void:
	window = null
	pages = Control.new()
	pages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book.add_child(pages)
	right_page = _page()
	pages.add_child(right_page)
	left_page = _page()
	pages.add_child(left_page)
	left_box = VBoxContainer.new()
	left_box.add_theme_constant_override("separation", 8)
	left_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_page.add_child(left_box)
	var right_col := VBoxContainer.new()
	right_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_page.add_child(right_col)
	var right_scroll := ScrollContainer.new()
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.add_child(right_scroll)
	right_col.add_child(Pager.new().setup(right_scroll))
	right_box = VBoxContainer.new()
	right_box.add_theme_constant_override("separation", 8)
	right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_scroll.add_child(right_box)


## A page: the kit's paper, dark with the gem and edged in white, with its ornament frame drawn over it.
func _page() -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _page_style())
	p.draw.connect(_draw_frame.bind(p))
	return p


func _page_style() -> StyleBox:
	var s := float(UIKit.PIXEL_SCALE)
	var sb := StyleBoxTexture.new()
	sb.texture = UIKit.piece("page", _page_fill(), UIKit.PIXEL_LINE, UIKit.ACCENT.darkened(0.45))
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sb.set_texture_margin(side, 7.0 * s)
	# (clear of the frame's corner diamonds, which reach 13 pixels in from its corners)
	sb.content_margin_left = (FRAME_INSET.x + 10.0) * s
	sb.content_margin_right = (FRAME_INSET.x + 10.0) * s
	sb.content_margin_top = (FRAME_INSET.y + 14.0) * s
	sb.content_margin_bottom = (FRAME_INSET.y + 15.0) * s
	return sb


## The pages' paper: the gem, deep enough that white text reads on it.
func _page_fill() -> Color:
	return UIKit.ACCENT.darkened(0.7)


## A page's ornament frame (the kit's thin white line with its diamond corners), a little in from the edge, its top
## left open in the middle for the page's title.
func _draw_frame(p: PanelContainer) -> void:
	var s := float(UIKit.PIXEL_SCALE)
	var tex := UIKit.piece("page_frame", Color(0, 0, 0, 0), UIKit.PIXEL_LINE)
	if tex == null:
		return
	var f := Rect2(FRAME_INSET * s, p.size - FRAME_INSET * s * 2.0)
	var c := 16.0 * s
	var col := UIKit.PIXEL_LINE
	# the corners (as the kit drew them, from its 159 x 249 frame)
	p.draw_texture_rect_region(tex, Rect2(f.position, Vector2(c, c)), Rect2(0, 0, c, c))
	p.draw_texture_rect_region(tex, Rect2(Vector2(f.end.x - c, f.position.y), Vector2(c, c)), Rect2(143.0 * s, 0, c, c))
	p.draw_texture_rect_region(tex, Rect2(Vector2(f.position.x, f.end.y - c), Vector2(c, c)), Rect2(0, 233.0 * s, c, c))
	p.draw_texture_rect_region(tex, Rect2(f.end - Vector2(c, c), Vector2(c, c)), Rect2(143.0 * s, 233.0 * s, c, c))
	# the sides and the foot
	p.draw_rect(Rect2(f.position.x, f.position.y + c, s, f.size.y - 2.0 * c), col)
	p.draw_rect(Rect2(f.end.x - s, f.position.y + c, s, f.size.y - 2.0 * c), col)
	p.draw_rect(Rect2(f.position.x + c, f.end.y - s, f.size.x - 2.0 * c, s), col)
	# the top, open round the page's title (written in, letter by letter, as the page opens), each side ending in the
	# kit's little chevron
	var title := String(p.get_meta("title", ""))
	var font := UIKit.font_head()
	var fs := UIKit.head_px(UIKit.HEAD_SIZE)
	var gap := 0.0
	if title != "":
		var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		gap = tw + 44.0
		var shown := title.substr(0, ceili(title.length() * float(p.get_meta("title_ratio", 1.0))))
		var base := Vector2(f.get_center().x - tw / 2.0, f.position.y + font.get_ascent(fs) * 0.5 - 2.0)
		p.draw_string(font, base, shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	gap = clampf(gap, 0.0, f.size.x - 2.0 * c - 20.0 * s)
	var cap := Vector2(9.0 * s, 3.0 * s)
	var gl := f.get_center().x - gap / 2.0
	var gr := f.get_center().x + gap / 2.0
	if gap <= 0.0:
		p.draw_rect(Rect2(f.position.x + c, f.position.y, f.size.x - 2.0 * c, s), col)
		return
	p.draw_rect(Rect2(f.position.x + c, f.position.y, gl - cap.x - f.position.x - c, s), col)
	p.draw_texture_rect_region(tex, Rect2(Vector2(gl - cap.x, f.position.y), cap), Rect2(32.0 * s, 0, cap.x, cap.y))
	p.draw_texture_rect_region(tex, Rect2(Vector2(gr, f.position.y), cap), Rect2(118.0 * s, 0, cap.x, cap.y))
	p.draw_rect(Rect2(gr + cap.x, f.position.y, f.end.x - c - gr - cap.x, s), col)


## Where the right page rests (and, hidden, where it slides out from: tucked behind the left page).
func _right_rest() -> Vector2:
	return Vector2(left_page.size.x + PAGE_GAP, 0)


func _right_hidden() -> Vector2:
	return Vector2(left_page.size.x - right_page.size.x * 0.92, 0)


## Opening the book: the left page unfolds from its middle, then the right slides out from behind it.
func _unfold() -> void:
	left_page.pivot_offset = left_page.size / 2.0
	left_page.scale = Vector2(1, 0.04)
	tab_strip.modulate.a = 0.0
	right_page.position = _right_hidden()
	right_page.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(left_page, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(tab_strip, "modulate:a", 1.0, 0.22)
	tw.tween_callback(_slide_out)


## The right page slides out from behind the left (each time a tab opens), and the titles write themselves in.
func _slide_out() -> void:
	if right_page == null:
		return
	if _slide != null and _slide.is_valid():
		_slide.kill()
	right_page.position = _right_hidden()
	right_page.modulate.a = 0.0
	_slide = create_tween()
	_slide.tween_property(right_page, "position", _right_rest(), 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide.parallel().tween_property(right_page, "modulate:a", 1.0, 0.12)
	for page in [left_page, right_page]:
		var pg := page as Control
		pg.set_meta("title_ratio", 0.0)
		_slide.parallel().tween_method(func(v: float) -> void:
			if is_instance_valid(pg):
				pg.set_meta("title_ratio", v)
				pg.queue_redraw(), 0.0, 1.0, 0.26)


## Pixel style: each page's title, for its frame to write in the gap at its top: the pane's title, or, for the
## right page without one, the heading its details open with (then left out of the page itself).
func _retitle() -> void:
	for p in [left_page, right_page]:
		if p == null:
			continue
		var page := p as PanelContainer
		var title := ""
		var t := page.find_child("PaneTitle", true, false)
		if t != null:
			title = (t.get_child(0) as Label).text
		elif page == right_page:
			var n: Node = right_box
			while n is Container and n.get_child_count() > 0:
				n = n.get_child(0)
			if n is Label and (n as Label).get_theme_font("font") == UIKit.font_head():
				title = (n as Label).text
				(n as Label).visible = false
		page.set_meta("title", title)
		page.queue_redraw()

## The window fills most of the screen (above the key guide or touch pad), so rows and text are big enough to tap.
func _layout() -> void:
	var vp := size if size.x > 0 else get_viewport_rect().size
	var avail := vp.y - (UI.bottom_reserve() if is_instance_valid(UI) else 0.0)
	var side := 24.0
	var top := 14.0
	var w := minf(vp.x - side * 2.0, 1240.0)
	book.position = Vector2(roundf((vp.x - w) / 2.0), top)
	book.size = Vector2(w, avail - top - 10.0)
	tab_strip.position = Vector2.ZERO
	tab_strip.size = Vector2(w, TAB_H)
	if pages != null and is_instance_valid(pages):
		pages.position = Vector2(0, TAB_H + TAB_GAP)
		pages.size = Vector2(w, book.size.y - TAB_H - TAB_GAP)
		var lw := roundf((w - PAGE_GAP) * LEFT_SHARE)
		left_page.position = Vector2.ZERO
		left_page.size = Vector2(lw, pages.size.y)
		left_page.pivot_offset = left_page.size / 2.0
		right_page.size = Vector2(w - lw - PAGE_GAP, pages.size.y)
		if _slide == null or not _slide.is_running():
			right_page.position = _right_rest()
		return
	window.position = Vector2(0, TAB_H + TAB_GAP)
	window.size = Vector2(w, book.size.y - TAB_H - TAB_GAP)


## A new highlight colour (from the Settings tab): the open tab is redrawn in it. A new style: the book is built
## again in it.
func _on_prefs_changed() -> void:
	if not is_inside_tree():
		return
	if UIKit.style != _built_style:
		book.queue_free()
		pages = null
		left_page = null
		right_page = null
		_build()
		_open_tab(tab)
		_focus_first.call_deferred()
		if UIKit.pixel():
			_unfold()
		return
	if window != null:
		window.add_theme_stylebox_override("panel", UIKit.box("textfield"))
	else:
		for p in [left_page, right_page]:
			(p as PanelContainer).add_theme_stylebox_override("panel", _page_style())
			(p as Control).queue_redraw()
	_style_tabs()


## The tabs: rounded chips, the open one filled with the gem and edged in its palest shade, the rest dark with a soft
## edge.
func _style_tabs() -> void:
	for k in markers.size():
		var m: Button = markers[k]
		var open := k == tab
		var sb: StyleBox = UIKit.chip(UIKit.ACCENT if open else UIKit.WINDOW_BOTTOM, UIKit.BORDER if open else Color(UIKit.BORDER, 0.35),
			16.0, Vector4(10, 0, 10, 0), 3.0 if open else 2.0)
		if not open and sb is UIKit.CozyBox:
			sb.top = Color(UIKit.WINDOW_TOP, 0.92)
			sb.bottom = Color(UIKit.WINDOW_BOTTOM, 0.92)
		elif UIKit.pixel():
			# the 1-bit plate: the open tab filled with the gem, the rest near-black with a grey edge
			sb = UIKit.pixel_box("plate", UIKit.ACCENT if open else UIKit.WINDOW_BOTTOM, UIKit.PIXEL_LINE if open else UIKit.PIXEL_DIM,
				Vector4(10, 0, 10, 0))
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			m.add_theme_stylebox_override(st, sb)
		var col := UIKit.LIGHT if open else UIKit.DIM
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			m.add_theme_color_override(c, col)
		m.add_theme_color_override("icon_normal_color", col)
		m.add_theme_color_override("icon_hover_color", col)
		m.add_theme_color_override("icon_pressed_color", col)


# ================================================================ tabs & rows
func _click_tab(i: int) -> void:
	if i != tab:
		Sfx.play("page")
		_open_tab(i)
	mode = "list"
	_focus_first()


func _open_tab(i: int) -> void:
	var turned := i != tab
	tab = i
	last_tab = i
	_style_tabs()
	if turned and right_page != null:
		_slide_out.call_deferred()
	_clear(left_box)
	_clear(right_box)
	rows = []
	row_buttons = []
	list_box = null
	detail_box = null
	match TABS[tab]["id"]:
		"trainer":
			_tab_trainer()
		"beasts":
			_tab_beasts()
		"flute":
			_tab_flute()
		"bag":
			_tab_bag()
		"bestiary":
			_tab_bestiary()
		"map":
			_tab_map()
		"settings":
			_tab_settings()
	if mode == "list":
		_focus_first.call_deferred()
	if left_page != null:
		_retitle()


func _clear(c: Control) -> void:
	for ch in c.get_children():
		c.remove_child(ch)
		ch.queue_free()


## Puts a title, a scrolling list and (optionally) a detail area in the chosen panes.
func _make_list(on: VBoxContainer, title: String, detail_on: VBoxContainer = null) -> void:
	on.add_child(_pane_title(title))
	list_scroll = ScrollContainer.new()
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.follow_focus = true
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	on.add_child(list_scroll)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 0)
	list_scroll.add_child(list_box)
	on.add_child(Pager.new().setup(list_scroll))
	detail_box = detail_on


## row: {text, right, icon, disabled, act: Callable, detail: Callable(VBoxContainer), adjust: Callable(dir), header: bool}
func _add_row(row: Dictionary) -> void:
	if row.get("header", false):
		var h := UIKit.header(row["text"], UIKit.GOLD, UIKit.HEAD_SMALL)
		h.custom_minimum_size.y = 40
		h.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		list_box.add_child(h)
		return
	var b := Button.new()
	b.text = row.get("text", "")
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, UIKit.row_h())
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if row.get("disabled", false):
		b.add_theme_color_override("font_color", Color(UIKit.DIM, 0.7))
		b.add_theme_color_override("font_focus_color", UIKit.DIM)
		b.add_theme_color_override("font_hover_color", UIKit.DIM)
	if row.has("icon") and row["icon"] != null:
		b.icon = row["icon"]
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 44)
	if row.has("right"):
		var rl := UIKit.label(str(row["right"]), 20, UIKit.GOLD)
		rl.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
		rl.offset_left = -220
		rl.offset_right = -8
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(rl)
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = 22
		empty.content_margin_right = 12 + float(row.get("right_width", 110))
		var hl := UIKit.highlight(float(row.get("right_width", 110)))
		b.add_theme_stylebox_override("normal", empty)
		b.add_theme_stylebox_override("disabled", empty)
		for st in ["hover", "focus", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(st, hl)
	var idx := rows.size()
	b.pressed.connect(_activate.bind(idx))
	b.focus_entered.connect(_row_focused.bind(idx))
	b.mouse_entered.connect(func(): if mode == "list": b.grab_focus())
	list_box.add_child(b)
	rows.append(row)
	row_buttons.append(b)


func _focus_first() -> void:
	if row_buttons.is_empty():
		mode = "tabs"
		return
	var i := clampi(_keep_row if _keep_row >= 0 else 0, 0, row_buttons.size() - 1)
	_keep_row = -1
	(row_buttons[i] as Button).grab_focus()
	_row_focused(i)


func _row_focused(i: int) -> void:
	if i != focus_row:
		Sfx.play("select")
	focus_row = i
	mode = "list"
	var row: Dictionary = rows[i]
	if detail_box != null and row.has("detail"):
		_clear(detail_box)
		(row["detail"] as Callable).call(detail_box)
		if left_page != null:
			_retitle()


func _activate(i: int) -> void:
	if mode != "list":
		mode = "list"
	var row: Dictionary = rows[i]
	if row.get("disabled", false) or not row.has("act"):
		Sfx.play("error")
		return
	Sfx.play("confirm")
	_keep_row = i
	await (row["act"] as Callable).call()
	if closed:
		return
	_open_tab(tab)


func _process(delta: float) -> void:
	_t += delta
	# while the tabs have the cursor, the open tab pulses
	for k in markers.size():
		(markers[k] as Control).modulate = Color(1, 1, 1, 0.7 + 0.3 * absf(sin(_t * 4.0))) if k == tab and mode == "tabs" else Color.WHITE


func on_input(ev: InputEvent) -> void:
	if ev.is_echo() and not (ev.is_action("ui_left") or ev.is_action("ui_right")):
		return
	if not ev.is_pressed():
		return
	if ev.is_action_pressed("menu"):
		_close_book()
		return
	if ev.is_action_pressed("ui_cancel"):
		if mode == "list":
			Sfx.play("back")
			mode = "tabs"
			get_viewport().gui_release_focus()
		else:
			_close_book()
		return
	var dir := 0
	if ev.is_action_pressed("ui_left", true):
		dir = -1
	elif ev.is_action_pressed("ui_right", true):
		dir = 1
	if dir != 0:
		if mode == "list" and focus_row < rows.size() and rows[focus_row].has("adjust"):
			(rows[focus_row]["adjust"] as Callable).call(dir)
			Sfx.play("toggle")
			_keep_row = focus_row
			_open_tab(tab)
			return
		Sfx.play("page")
		var keep_mode := mode
		_open_tab(posmod(tab + dir, TABS.size()))
		mode = keep_mode
		if mode == "tabs":
			get_viewport().gui_release_focus()
		return
	if mode == "tabs" and (ev.is_action_pressed("ui_accept") or ev.is_action_pressed("ui_down")):
		mode = "list"
		_focus_first()


func _close_book() -> void:
	Sfx.play("back")
	close()


# ================================================================ small builders
## How to use a row: tapped on a phone (the A button hides while the book is open), A with keys or a pad.
func _press() -> String:
	return "Tap" if UI.is_touch() else "Press A"


func _adjust_hint() -> String:
	return "Tap to change it" if UI.is_touch() else "Use ←/→ to adjust"


func _h(text: String, color := UIKit.INK, size := UIKit.HEAD_SIZE) -> Label:
	return UIKit.header(text, color, size)


func _t_label(text: String, color := UIKit.INK, big := false, wrap := true) -> Label:
	var l := UIKit.label(text, 24 if big else 20, color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 120
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	return l


func _w(text: String, color := UIKit.INK) -> Label:
	return _t_label(text, color, false, false)


func _row_of(children: Array, sep := 8) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", sep)
	for c in children:
		if c is Label and (c as Label).autowrap_mode != TextServer.AUTOWRAP_OFF:
			(c as Label).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		(c as Control).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(c)
	return hb


func _spacer(h := 6.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


func _sub(text: String) -> Label:
	var l := UIKit.header(text, UIKit.GOLD, UIKit.HEAD_SMALL)
	return l


## A pane's title: white text over an accent underline (Pixel: centred in the gap atop the page's frame).
func _pane_title(text: String) -> Control:
	var vb := VBoxContainer.new()
	vb.name = "PaneTitle"
	if UIKit.pixel():
		# (the page's frame writes it: see _retitle)
		var l := UIKit.header(text, UIKit.PIXEL_LINE, UIKit.HEAD_SIZE)
		l.visible = false
		vb.add_child(l)
		return vb
	vb.add_theme_constant_override("separation", 2)
	vb.add_child(UIKit.header(text, UIKit.LIGHT, UIKit.HEAD_SIZE))
	var bar := ColorRect.new()
	bar.color = UIKit.ACCENT
	bar.custom_minimum_size.y = 3
	vb.add_child(bar)
	return vb


# ================================================================ Trainer
func _tab_trainer() -> void:
	left_box.add_child(_pane_title(GameState.player_name))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	left_box.add_child(top)
	top.add_child(VoxelPortrait.new().setup_person(GameState.hero_look(), 150))
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	top.add_child(info)
	info.add_child(_row_of([UIKit.icon("icon_coin"), _w("%d gold" % GameState.gold)]))
	info.add_child(_w("Played %s" % GameState.time_text()))
	info.add_child(_w("Towns %d / 12" % GameState.visited.size()))
	info.add_child(_w("Caught %d / 48" % GameState.caught.size()))
	var nxt := GameState.trainer_xp_for(GameState.trainer_level + 1)
	info.add_child(_w("Trainer Lv %d%s" % [GameState.trainer_level, ("  (%d / %d XP)" % [GameState.trainer_xp, nxt]) if GameState.trainer_level < GameState.TRAINER_LEVEL_MAX else ""]))
	info.add_child(_w("Beast slots %d / %d" % [GameState.beast_slots, GameState.PARTY_MAX]))
	left_box.add_child(_sub("SHIELD"))
	var sh := HBoxContainer.new()
	for i in 4:
		var on := i < GameState.max_shield
		var ic := UIKit.icon("icon_energy" if on else "icon_energy_empty")
		if i >= GameState.max_shield:
			ic.modulate = Color(1, 1, 1, 0.45)
		sh.add_child(ic)
	sh.add_child(_w("  Shards %d" % GameState.shards))
	left_box.add_child(sh)
	left_box.add_child(_sub("ARENA CRESTS"))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	for town in ARENA_ORDER:
		var a: Dictionary = WorldDB.ARENAS[town]
		var won: bool = GameState.crests.has(a["crest"])
		var ic := UIKit.icon(CREST_ICONS.get(a["crest"], "crest_empty") if won else "crest_empty")
		ic.tooltip_text = a["crest"]
		grid.add_child(ic)
	left_box.add_child(grid)

	_make_list(right_box, "Journal")
	detail_box = VBoxContainer.new()
	right_box.add_child(HSeparator.new())
	right_box.add_child(detail_box)
	for slot in ["flute", "head", "feet", "acc"]:
		var id: String = GameState.gear[slot]
		_add_row({"text": SLOT_SHORT[slot], "right": ItemDB.item_name(id) if id != "" else "—", "right_width": 190,
			"act": func(): await Menus.equip_trainer_slot(slot),
			"detail": func(c): c.add_child(_t_label(ItemDB.get_item(id).get("desc", "Nothing equipped.") if id != "" else "Nothing equipped. %s to equip trainer gear." % _press()))})
	var flyer = Places.own_flyer()
	var outdoors: bool = world != null and not world.interior
	_add_row({"text": "Fly", "disabled": flyer == null or not outdoors, "act": _fly,
		"detail": func(c): c.add_child(_t_label(("%s can carry you to any town you've visited." % flyer.nickname) if flyer != null else "An air beast of Lv %d or higher could carry you to any town you've visited." % Places.FLY_LEVEL))})
	_add_row({"text": "Save", "act": _save,
		"detail": func(c): c.add_child(_t_label(("Save into slot %d, with a snapshot of this moment." % (GameState.current_slot + 1)) if GameState.current_slot >= 0 else "Save your journey into the first empty slot. After that, every save goes back into the same slot."))})


func _fly() -> void:
	var flyer = Places.own_flyer()
	if flyer != null and await Places.fly_menu(world.map_id, 0, flyer.nickname):
		close()


func _save() -> void:
	await GameState.main.save_with_card()


# ================================================================ Beasts
func _tab_beasts() -> void:
	GameState.fix_ring()
	_make_list(left_box, "Beasts %d / %d" % [GameState.party.size(), GameState.party_max()], right_box)
	if not GameState.party.is_empty():
		_add_row({"text": "Battle ring", "right": "%s side" % Ring.side_element(GameState.ring_side).capitalize(), "right_width": 150,
			"act": _arrange_ring, "detail": _ring_detail})
	var ordered: Array = GameState.party.duplicate()
	ordered.sort_custom(func(x, y): return int(x.slot) < int(y.slot))
	for b in ordered:
		_add_row({"text": b.nickname, "right": "Lv %d" % b.level if b.hp > 0 else "fainted", "icon": PixelArt.beast_texture(b.genes),
			"act": func(): await Menus.beast_options(b), "detail": _beast_detail.bind(b)})
	if not GameState.eggs.is_empty():
		_add_row({"header": true, "text": "EGGS"})
		for e in GameState.eggs:
			_add_row({"text": GameState.egg_name(e), "right": String(e["kind"]).capitalize(), "detail": _egg_detail.bind(e)})
	if GameState.party.is_empty() and GameState.eggs.is_empty():
		right_box.add_child(_t_label("You don't have any beasts yet.", UIKit.DIM))


## Your battle ring: who stands where, and the rules.
func _ring_detail(c: VBoxContainer) -> void:
	c.add_child(_h("Battle ring"))
	var rv := RingView.new(300.0)
	rv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rv.shield = GameState.shield
	rv.max_shield = GameState.max_shield
	rv.set_ring(GameState.ring(), GameState.ring_side)
	rv.facing = 0.0
	c.add_child(rv)
	c.add_child(_t_label("You stand in the middle; the side facing the foe fights (outlined). Each side takes its own element, each corner either of its two, or a dual beast of both. Turn the ring in battle with ▲ / ▼ past your top or bottom beast.", UIKit.DIM))
	c.add_child(_t_label("%s to move your beasts round the ring." % _press(), UIKit.ACCENT))


## Moves beasts round the ring: pick a beast, then the slot it should stand on (trading places with whoever is there).
func _arrange_ring() -> void:
	while true:
		var party: Array = GameState.party.duplicate()
		party.sort_custom(func(x, y): return int(x.slot) < int(y.slot))
		var items := []
		for b in party:
			items.append({"text": b.nickname, "right": _slot_short(b.slot), "icon": PixelArt.beast_texture(b.genes),
				"desc": "%s beast, on the %s." % [b.element_text(), Ring.slot_name(b.slot)]})
		var c: int = await UI.choose("Move which beast?", items, {"width": 420, "rows": 8})
		if c < 0:
			return
		var b = party[c]
		var spots := []
		for k in Ring.SLOTS:
			var occ = GameState.beast_at(k)
			var why := ""
			if occ == b:
				why = "%s already stands here." % b.nickname
			elif not Ring.can_hold(b, k):
				why = "A %s beast can't stand on the %s." % [b.element_text(), Ring.slot_name(k)]
			elif occ != null and not Ring.can_hold(occ, b.slot):
				why = "%s can't move to the %s to trade places." % [occ.nickname, Ring.slot_name(b.slot)]
			spots.append({"text": Ring.slot_name(k), "right": occ.nickname if occ != null else "—", "disabled": why != "",
				"desc": why if why != "" else ("Trade places with %s." % occ.nickname if occ != null else "Move %s here." % b.nickname)})
		var c2: int = await UI.choose("Where should %s stand?" % b.nickname, spots, {"width": 460, "rows": 8})
		if c2 < 0:
			continue
		var err := GameState.move_to_slot(b, c2)
		if err != "":
			Sfx.play("error")
			await UI.say([err])
		else:
			Sfx.play("confirm")


## "Fire", "Fire/Air": a slot's short name.
func _slot_short(k: int) -> String:
	if k < 0:
		return "—"
	return "/".join(Ring.slot_elements(k).map(func(e): return String(e).capitalize()))


func _egg_detail(c: VBoxContainer, e: Dictionary) -> void:
	c.add_child(_h(GameState.egg_name(e)))
	c.add_child(_t_label("Something stirs inside... Any Beast Center can hatch it. Hatchlings start at Lv 1."))


func _beast_detail(c: VBoxContainer, b) -> void:
	var top := HBoxContainer.new()
	c.add_child(top)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	top.add_child(col)
	var nm := _h(b.nickname)
	nm.clip_text = true
	nm.custom_minimum_size.x = 210
	col.add_child(nm)
	var tags := [] as Array
	for el in b.elements():
		tags.append(UIKit.element_tag(el))
	tags.append(_w(Elements.ROLE.get(b.element, ""), UIKit.DIM))
	col.add_child(_row_of(tags))
	if b.slot >= 0:
		col.add_child(_w("On the %s" % Ring.slot_name(b.slot), UIKit.DIM))
	col.add_child(_row_of([UIKit.stars(b.rank), _w("Lv %d / %d" % [b.level, b.level_cap()])], 4))
	var pt := VoxelPortrait.new().setup(b.genes, 120)
	pt.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(pt)
	var hp := Bar.new(Vector2(360, 33))
	hp.set_ratio(b.hp_ratio(), true)
	hp.text = "HP %d/%d" % [maxi(0, b.hp), b.max_hp()]
	c.add_child(hp)
	var mpb := Bar.new(Vector2(360, 22))
	mpb.fixed_color = UIKit.GOLD_BRIGHT
	mpb.set_ratio(b.mp_ratio(), true)
	mpb.text = "MP %d/%d" % [b.mp, b.max_mp()]
	c.add_child(mpb)
	var xp := Bar.new(Vector2(360, 10))
	xp.fixed_color = UIKit.GOLD
	xp.set_ratio(b.xp_progress(), true)
	c.add_child(xp)
	var stats := GridContainer.new()
	stats.columns = 4
	stats.add_theme_constant_override("h_separation", 10)
	for s in ["atk", "def", "spr", "spd"]:
		stats.add_child(_w(s.to_upper(), UIKit.DIM))
		stats.add_child(_w(str(b.stat(s))))
	c.add_child(stats)
	c.add_child(_sub("SKILLS"))
	for mv in b.battle_moves():
		var m := MoveDB.get_move(mv)
		var line := _w("%s%s" % [m["name"], ("  Pow %d" % m["power"]) if m.has("power") else ""])
		line.clip_text = true
		line.custom_minimum_size.x = 280
		c.add_child(_row_of([UIKit.element_tag(m["el"]), line], 6))
	if not b.passives.is_empty():
		var tl := _t_label("Traits: " + ", ".join(b.passives), UIKit.DIM)
		c.add_child(tl)
	c.add_child(_sub("FAMILY TREE"))
	var tree := FamilyTree.new()
	tree.node = b.family_node(2)
	tree.custom_minimum_size = Vector2(360, 120)
	c.add_child(tree)
	if b.at_cap():
		c.add_child(_t_label("At its level cap! Merge it at a Beast Center to reach Rank %d." % (b.rank + 1), UIKit.ACCENT))


## Draws a beast and its merge parents and grandparents as a little pixel tree.
class FamilyTree extends Control:
	const UIKit = preload("res://scripts/ui/ui_kit.gd")
	const Elements = preload("res://scripts/data/elements.gd")
	var node: Dictionary = {}

	func _draw() -> void:
		var f := UIKit.font_body()
		if node.get("parents", []).is_empty():
			draw_string(f, Vector2(0, UIKit.body_px(22) * 1.15), "No merges yet.", HORIZONTAL_ALIGNMENT_LEFT, size.x, UIKit.body_px(22), UIKit.DIM)
			draw_string(f, Vector2(0, UIKit.body_px(22) * 2.15), "Merge two beasts at their level", HORIZONTAL_ALIGNMENT_LEFT, size.x, UIKit.body_px(22), UIKit.DIM)
			draw_string(f, Vector2(0, UIKit.body_px(22) * 3.15), "cap to grow a family tree!", HORIZONTAL_ALIGNMENT_LEFT, size.x, UIKit.body_px(22), UIKit.DIM)
			return
		var rows := [[node], node["parents"]]
		var gp := []
		for p in node["parents"]:
			for q in p.get("parents", []):
				gp.append(q)
		if not gp.is_empty():
			rows.append(gp)
		var row_h := size.y / rows.size()
		var centers := []
		for r in rows.size():
			var n: int = rows[r].size()
			var cs := []
			for i in n:
				cs.append(Vector2(size.x * (i + 0.5) / n, r * row_h + row_h * 0.5))
			centers.append(cs)
		# links
		for i in centers[1].size():
			_link(centers[0][0], centers[1][i])
		if rows.size() > 2:
			var k := 0
			for i in rows[1].size():
				for q in rows[1][i].get("parents", []):
					_link(centers[1][i], centers[2][k])
					k += 1
		for r in rows.size():
			for i in rows[r].size():
				_box(f, rows[r][i], centers[r][i], size.x / rows[r].size() - 6, r == 0)

	func _link(a: Vector2, b: Vector2) -> void:
		var mid := (a.y + b.y) / 2.0
		var col := UIKit.BORDER_INNER
		draw_line(a, Vector2(a.x, mid), col, 3.0)
		draw_line(Vector2(a.x, mid), Vector2(b.x, mid), col, 3.0)
		draw_line(Vector2(b.x, mid), b, col, 3.0)

	func _box(f: Font, n: Dictionary, c: Vector2, w: float, root: bool) -> void:
		var name: String = n.get("name", "?")
		var maxc := int(w / 10.0)
		if name.length() > maxc:
			name = name.substr(0, maxi(3, maxc - 1)) + "."
		var bw := minf(w, name.length() * 10.0 + 24.0)
		var r := Rect2(c - Vector2(bw / 2.0, 15), Vector2(bw, 30))
		draw_rect(r, Color("#1c1c22") if root else Color("#101014"))
		draw_rect(r, UIKit.ACCENT if root else UIKit.BORDER, false, 2.0)
		var el: String = n.get("element", "fire")
		draw_rect(Rect2(r.position + Vector2(4, 9), Vector2(10, 12)), UIKit.ACCENT)
		draw_string(f, r.position + Vector2(18, 22), name, HORIZONTAL_ALIGNMENT_LEFT, bw - 20, UIKit.body_px(22), UIKit.INK)


# ================================================================ Flute
func _tab_flute() -> void:
	if not GameState.has_flute():
		_make_list(left_box, "Songs", right_box)
		_add_row({"text": "No flute yet", "detail": func(c): c.add_child(_t_label("Your father's reed flute is waiting for you with Uncle Rafe in Tidewater, east along the Coastal Path. He'll teach you to play it."))})
		return
	_make_list(left_box, "Songs %d / %d" % [GameState.songs.size(), SongDB.ORDER.size()], right_box)
	# the songs you know come first (battle songs, then charms), the ones still to learn after them
	var known_ids := []
	var unknown_ids := []
	for sid in SongDB.ordered(GameState.songs):
		(known_ids if GameState.knows_song(sid) else unknown_ids).append(sid)
	var charms := known_ids.filter(func(id): return SongDB.get_song(id)["kind"] == "charm")
	var battle := known_ids.filter(func(id): return SongDB.get_song(id)["kind"] != "charm")
	var hdr := ""
	for sid in battle + charms + unknown_ids:
		var s := SongDB.get_song(sid)
		var known := GameState.knows_song(sid)
		var want: String = ("CHARM SONGS" if s["kind"] == "charm" else "BATTLE SONGS") if known else "NOT YET LEARNED"
		if want != hdr:
			hdr = want
			_add_row({"header": true, "text": hdr})
		var ready: bool = SongDB.capture_level(sid) > 0 and GameState.next_capture_ready()
		var is_cap: bool = SongDB.capture_level(sid) > 0
		_add_row({"text": s["name"] if known else "? ? ?", "right": ("★ new" if ready else SongDB.tag(sid)) if known else "", "right_width": 80 if is_cap else 150,
			"disabled": not known, "detail": _song_detail.bind(sid), "act": _song_act.bind(sid)})


func _song_act(sid: String) -> void:
	if not GameState.knows_song(sid):
		return
	if SongDB.capture_level(sid) > 0 and GameState.next_capture_ready():
		await Places.practice_next_capture()
	else:
		await Places.practice_once(sid)


func _song_detail(c: VBoxContainer, sid: String) -> void:
	var s := SongDB.get_song(sid)
	var known := GameState.knows_song(sid)
	if SongDB.capture_level(sid) > 0 and known:
		_capture_detail(c, sid)
		return
	if not known:
		c.add_child(_h("Unknown song"))
		c.add_child(_t_label("Where to learn it: " + String(s["from"]), UIKit.DIM))
		return
	c.add_child(_h(s["name"]))
	var kt := UIKit.tag("CHARM" if s["kind"] == "charm" else "BATTLE", UIKit.ACCENT)
	kt.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	c.add_child(kt)
	c.add_child(_spacer())
	c.add_child(_t_label(SongDB.describe(sid)))
	c.add_child(_spacer())
	var stars := GameState.mastery_stars(sid)
	var hb := HBoxContainer.new()
	hb.add_child(_w("Mastery "))
	for i in 5:
		hb.add_child(UIKit.icon("icon_star" if i < stars else "icon_star_empty"))
	c.add_child(hb)
	c.add_child(_t_label("Each star of mastery makes the song stronger and adds notes to it.", UIKit.DIM))
	c.add_child(_spacer())
	c.add_child(_t_label("Learned from: " + String(s["from"]), UIKit.DIM))
	var lv := GameState.song_level(sid)
	c.add_child(_t_label("Level %d of %d  ·  %d notes" % [lv, SongDB.max_level(sid), SongDB.note_count(sid, lv)], UIKit.DIM))
	c.add_child(_spacer())
	var flute: String = GameState.gear["flute"]
	c.add_child(_t_label("Your flute: %s" % ItemDB.item_name(flute)))
	c.add_child(_t_label("%s to practise it." % _press(), UIKit.ACCENT))


func _capture_detail(c: VBoxContainer, sid: String) -> void:
	var lv := GameState.capture_level()
	c.add_child(_h(SongDB.song_name(sid)))
	var ct := UIKit.tag("CHARM", UIKit.ACCENT)
	ct.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	c.add_child(ct)
	c.add_child(_spacer())
	c.add_child(_t_label("Charms wild beasts up to Lv %d, if one of your beasts is at least that strong (yours: Lv %d)." % [GameState.capture_cap(), GameState.best_level()]))
	c.add_child(_t_label("The faster and cleaner you play, the better the chance. Play it flawlessly to charm a beast stronger than any of yours.", UIKit.DIM))
	c.add_child(_t_label("Capture %s  ·  %d notes" % [SongDB.ROMAN[lv - 1], SongDB.note_count(sid, lv)], UIKit.DIM))
	c.add_child(_spacer())
	if lv >= SongDB.CAPTURE_CAPS.size():
		c.add_child(_t_label("This is the final level of Capture. Nothing can resist you now!", UIKit.ACCENT))
	elif GameState.next_capture_ready():
		c.add_child(_t_label("Your beasts have outgrown it! %s to practise %s (up to Lv %d)." % [_press(), SongDB.song_name(SongDB.capture_id(lv + 1)), SongDB.CAPTURE_CAPS[lv]], UIKit.ACCENT))
	else:
		c.add_child(_t_label("Next: %s, once one of your beasts reaches Lv %d." % [SongDB.song_name(SongDB.capture_id(lv + 1)), GameState.capture_cap()], UIKit.DIM))
	c.add_child(_spacer())
	var stars := GameState.mastery_stars(sid)
	var hb := HBoxContainer.new()
	hb.add_child(_w("Mastery "))
	for i in 5:
		hb.add_child(UIKit.icon("icon_star" if i < stars else "icon_star_empty"))
	c.add_child(hb)


# ================================================================ Bag
func _tab_bag() -> void:
	_make_list(left_box, "Bag  ·  %d gold" % GameState.gold, right_box)
	var groups := [["CARE", func(it): return it["kind"] == "use" and not it.get("battle_only", false)],
		["BATTLE ITEMS", func(it): return it["kind"] == "use" and it.get("battle_only", false)],
		["BEAST GEAR", func(it): return it["kind"] == "gear"],
		["TRAINER GEAR", func(it): return it["kind"] == "tgear"],
		["SHEET MUSIC", func(it): return it["kind"] == "sheet"],
		["TOMES", func(it): return it["kind"] == "tome"]]
	var ids := GameState.inventory.keys()
	ids.sort_custom(func(a, b): return ItemDB.item_name(a) < ItemDB.item_name(b))
	var any := false
	for g in groups:
		var first := true
		for id in ids:
			var it := ItemDB.get_item(id)
			if not (g[1] as Callable).call(it):
				continue
			if first:
				_add_row({"header": true, "text": g[0]})
				first = false
			any = true
			_add_row({"text": it["name"], "right": "x%d" % GameState.item_count(id), "right_width": 60,
				"act": func(): await Menus.use_bag_item(id), "detail": _item_detail.bind(id)})
	if not any:
		right_box.add_child(_t_label("Your bag is empty. Shops and hidden sacks will fill it up!", UIKit.DIM))


func _item_detail(c: VBoxContainer, id: String) -> void:
	var it := ItemDB.get_item(id)
	c.add_child(_h(it["name"]))
	c.add_child(_t_label("You have %d." % GameState.item_count(id), UIKit.DIM))
	c.add_child(_spacer())
	c.add_child(_t_label(it.get("desc", "")))
	c.add_child(_spacer())
	var how := "%s to use it on a beast." % _press()
	match it["kind"]:
		"gear":
			how = "%s to give it to a beast." % _press()
		"tgear":
			how = "%s to equip it." % _press()
		"sheet":
			how = "%s to play from the sheet and learn the song." % _press()
	if it.get("battle_only", false):
		how = "Use it on your own turn in battle."
	c.add_child(_t_label(how, UIKit.ACCENT))


# ================================================================ Bestiary
func _tab_bestiary() -> void:
	_make_list(left_box, "Seen %d  Caught %d" % [GameState.seen.size(), GameState.caught.size()], right_box)
	for i in RaceDB.count():
		var seen: bool = GameState.seen.has(str(i))
		var caught: bool = GameState.caught.has(str(i))
		_add_row({"text": "%02d %s" % [i + 1, RaceDB.race_name(i) if seen else "? ? ?"], "right": "caught" if caught else ("seen" if seen else ""),
			"detail": _race_detail.bind(i)})


func _race_detail(c: VBoxContainer, i: int) -> void:
	var seen: bool = GameState.seen.has(str(i))
	if not seen:
		c.add_child(_h("? ? ?"))
		c.add_child(_t_label("You haven't met this beast yet.", UIKit.DIM))
		var hint := []
		for rid in WorldDB.ROUTES:
			if WorldDB.ROUTES[rid]["races"].has(i):
				hint.append(WorldDB.ROUTES[rid]["name"])
		if not hint.is_empty():
			c.add_child(_t_label("Rumoured to live on the %s." % hint[0], UIKit.DIM))
		return
	var el := RaceDB.element(i)
	c.add_child(_h(RaceDB.race_name(i)))
	c.add_child(_row_of([UIKit.element_tag(el), _w(Elements.ROLE.get(el, ""), UIKit.DIM)]))
	var pc := CenterContainer.new()
	pc.add_child(VoxelPortrait.new().setup(RaceDB.genes(i), 200))
	c.add_child(pc)
	var r := RaceDB.get_race(i)
	c.add_child(_t_label("Trait: %s. %s" % [r["passive"], RaceDB.PASSIVE_DESC.get(r["passive"], "")]))
	var where := []
	for rid in WorldDB.ROUTES:
		if WorldDB.ROUTES[rid]["races"].has(i):
			where.append(WorldDB.ROUTES[rid]["name"])
	c.add_child(_t_label("Found: " + (", ".join(where) if not where.is_empty() else "nowhere in the wild..."), UIKit.DIM))
	if GameState.caught.has(str(i)):
		c.add_child(_t_label("You've raised one of these!", UIKit.ACCENT))


# ================================================================ Map
func _tab_map() -> void:
	_make_list(left_box, "The Realm", right_box)
	for t in WorldDB.TOWN_ORDER:
		var been: bool = GameState.visited.has(t)
		var here: bool = GameState.map_id.get_slice("#", 0) == t
		_add_row({"text": WorldDB.map_name(t) if been else "? ? ?", "right": "here" if here else "",
			"act": func(): await Menus.world_map(), "detail": _town_detail.bind(t)})


func _town_detail(c: VBoxContainer, t: String) -> void:
	var info: Dictionary = WorldDB.TOWNS[t]
	if not GameState.visited.has(t):
		c.add_child(_h("Unexplored"))
		c.add_child(_t_label("You haven't been here yet. Keep following the roads!", UIKit.DIM))
		return
	c.add_child(_h(info["name"]))
	c.add_child(_t_label(String(info["size"]).capitalize(), UIKit.DIM))
	c.add_child(_spacer())
	c.add_child(_t_label(info["blurb"]))
	c.add_child(_spacer())
	c.add_child(_t_label("Mascot: %s" % RaceDB.race_name(info["mascot"])))
	var shops := []
	for s in info["shops"]:
		if not s in ["house", "uncle"] and not shops.has(s):
			shops.append(String(s).replace("_", " ").capitalize())
	var sl := _t_label("Places: " + ", ".join(shops), UIKit.DIM)
	c.add_child(sl)
	if WorldDB.ARENAS.has(t):
		var a: Dictionary = WorldDB.ARENAS[t]
		var won: bool = GameState.crests.has(a["crest"])
		c.add_child(_row_of([UIKit.icon(CREST_ICONS.get(a["crest"], "crest_empty") if won else "crest_empty"),
			_w("%s %s\n%s" % [a["title"], a["leader"], "Crest won!" if won else "Not yet challenged"])]))
	c.add_child(_spacer())
	c.add_child(_t_label("%s to open the full map." % _press(), UIKit.ACCENT))


# ================================================================ Settings
func _tab_settings() -> void:
	_make_list(left_box, "Settings")
	detail_box = VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 6)
	right_box.add_child(_pane_title("Controls"))
	right_box.add_child(detail_box)
	var pct := func(v: float): return "%d%%" % int(round(v * 100))
	_add_row({"text": "Save game", "act": _save, "detail": _controls_help.bind("Write your progress to the book.")})
	var speeds := [["Slow", 30.0], ["Normal", 60.0], ["Fast", 120.0], ["Instant", 0.0]]
	var cur_speed := 1
	for i in speeds.size():
		if absf(float(speeds[i][1]) - Prefs.text_speed) < 1.0:
			cur_speed = i
	_add_row({"text": "Music", "right": "◄ %s ►" % pct.call(Prefs.music_volume), "right_width": 150,
		"adjust": func(d): Prefs.set_value("music_volume", clampf(snappedf(Prefs.music_volume + 0.1 * d, 0.1), 0.0, 1.0)),
		"act": func(): Prefs.set_value("music_volume", 0.0 if Prefs.music_volume >= 1.0 else clampf(snappedf(Prefs.music_volume + 0.1, 0.1), 0.0, 1.0)),
		"detail": _controls_help.bind("Music volume. %s." % _adjust_hint())})
	_add_row({"text": "Sounds", "right": "◄ %s ►" % pct.call(Prefs.sfx_volume), "right_width": 150,
		"adjust": func(d): Prefs.set_value("sfx_volume", clampf(snappedf(Prefs.sfx_volume + 0.1 * d, 0.1), 0.0, 1.0)),
		"act": func(): Prefs.set_value("sfx_volume", 0.0 if Prefs.sfx_volume >= 1.0 else clampf(snappedf(Prefs.sfx_volume + 0.1, 0.1), 0.0, 1.0)),
		"detail": _controls_help.bind("Sound effect volume. %s." % _adjust_hint())})
	_add_row({"text": "Text speed", "right": "◄ %s ►" % speeds[cur_speed][0], "right_width": 150,
		"adjust": func(d): Prefs.set_value("text_speed", float(speeds[posmod(cur_speed + d, speeds.size())][1])),
		"act": func(): Prefs.set_value("text_speed", float(speeds[posmod(cur_speed + 1, speeds.size())][1])),
		"detail": _controls_help.bind("How fast dialogue appears.")})
	var gems: Array = UIKit.ACCENT_ORDER
	var gi := maxi(0, gems.find(UIKit.accent_name))
	_add_row({"text": "Gem", "right": "◄ %s ►" % UIKit.gem_name(gems[gi]), "right_width": 150,
		"adjust": func(d): Prefs.set_value("accent", gems[posmod(gi + d, gems.size())]),
		"act": func(): Prefs.set_value("accent", gems[posmod(gi + 1, gems.size())]),
		"detail": _controls_help.bind("The gem the menus are cut from: Ruby, Sapphire, Emerald or Hematite.")})
	var styles: Array = UIKit.STYLES
	var si := maxi(0, styles.find(UIKit.style))
	_add_row({"text": "Style", "right": "◄ %s ►" % UIKit.STYLE_NAMES[styles[si]], "right_width": 150,
		"adjust": func(d): Prefs.set_value("ui_style", styles[posmod(si + d, styles.size())]),
		"act": func(): Prefs.set_value("ui_style", styles[posmod(si + 1, styles.size())]),
		"detail": _controls_help.bind("How the menus look: Pixel (crisp white pixel frames and a paper book) or Classic (soft rounded windows).")})
	var touch_opts := ["auto", "on", "off"]
	var ti := maxi(0, touch_opts.find(Prefs.touch_controls))
	_add_row({"text": "Touch pad", "right": "◄ %s ►" % String(touch_opts[ti]).capitalize(), "right_width": 150,
		"adjust": func(d): Prefs.set_value("touch_controls", touch_opts[posmod(ti + d, 3)]),
		"act": func(): Prefs.set_value("touch_controls", touch_opts[posmod(ti + 1, 3)]),
		"detail": _controls_help.bind("On-screen d-pad and buttons. Auto shows them on phones and tablets.")})
	_add_row({"text": "Key guide", "right": "◄ %s ►" % ("On" if Prefs.show_key_legend else "Off"), "right_width": 150,
		"adjust": func(_d): Prefs.set_value("show_key_legend", not Prefs.show_key_legend),
		"act": func(): Prefs.set_value("show_key_legend", not Prefs.show_key_legend),
		"detail": _controls_help.bind("The strip at the bottom of the screen that shows which keys do what.")})
	if not Prefs.is_mobile():
		_add_row({"text": "Fullscreen", "right": "◄ %s ►" % ("On" if Prefs.fullscreen else "Off"), "right_width": 150,
			"adjust": func(_d): Prefs.set_value("fullscreen", not Prefs.fullscreen),
			"act": func(): Prefs.set_value("fullscreen", not Prefs.fullscreen),
			"detail": _controls_help.bind("Play in a window or full screen.")})
	_add_row({"text": "Credits", "act": _credits, "detail": _controls_help.bind("The artists, musicians and sound designers behind Ruby Cocoon.")})
	_add_row({"text": "Quit to title", "act": _quit, "detail": _controls_help.bind("Return to the title screen. Unsaved progress is lost!")})


func _controls_help(c: VBoxContainer, what: String) -> void:
	c.add_child(_t_label(what, UIKit.ACCENT))
	c.add_child(_spacer(10))
	var keys := [["←↑↓→", "Move"], ["A", "Talk / confirm"], ["S", "Back · hold to run"], ["SPACE", "Start: this book"], ["SHIFT", "Pause"]]
	if Prefs.touch_enabled():
		keys = [["D-PAD", "Move"], ["A", "Talk / confirm"], ["B", "Back · hold to run"], ["START", "This book"], ["PAUSE", "Pause"]]
	for k in keys:
		var cap := PanelContainer.new()
		cap.add_theme_stylebox_override("panel", UIKit.box("frame", Vector4(4, -2, 4, -2)))
		cap.custom_minimum_size.x = 92
		var kl := UIKit.label(k[0], 20, UIKit.INK)
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.add_child(kl)
		c.add_child(_row_of([cap, _w(k[1])], 10))
	c.add_child(_spacer(6))
	c.add_child(_t_label("Flute: listen, memorise the sheet, then play the notes back in order with ← → A %s (and ↑ ↓ in bigger songs)." % ("B" if Prefs.touch_enabled() else "S"), UIKit.DIM))


func _credits() -> void:
	await UI.say([
		"Ruby Cocoon. Thank you for playing!",
		"PSX art: chilly_durango, Screaming Brain Studios, Foxhead, Elegant Crow and Caliber Creations; RetroGround Free by Binbun3D (CC BY 4.0); PSX Forest, Cemetery, Castle and Western Town Kits by heyheythere (CC BY 4.0). People: Characters PSX by Elbolilloduro; the hero by yugg0 (base mesh by Vinrax).",
		"Buildings: PS1 House Pack by najjar320; interiors by DissonantVoid; Retro Modular House Pack by Elegant Crow; DINER, 6TWELVE and Trailer Park by Elbolilloduro; PSX Mall Kit and Building Kit by heyheythere (CC BY 4.0); street props: 3D Model by Conor McKenna (CyberThreat/Aphelios), CC BY 4.0; crates by Games by McSteeg; hedges by valsekamerplant.",
		"Beasts: Everything Library Animals by David OReilly; monsters by Quaternius (CC0); fish by CursedLake and ALSTRA INFINITE; alpaca and capybara by obliviist.",
		"Voxel art: StickyBizcuit, Kytric, Maria Starko and other voxel packs (see CREDITS.md).",
		"UI: Humble Gift by Humble Pixel (@Humblepixel); 1-bit UI by BatuhanK; Travel Book Lite by Crusenho; Fantasy RPG UI by dobo_ui (pixelated and recoloured); fonts BoldPixels and Lunchtime Doubly So.",
		"Music: Kevin MacLeod (incompetech.com), CC BY 4.0; plus DJARTMUSIC, Howling Hound Music and Monume (Pixabay).",
		"Sound effects: the packs in the sfx folder. Full list in CREDITS.md.",
	], "Credits")


func _quit() -> void:
	if await UI.ask("Return to the title screen? Unsaved progress will be lost.", "", "Quit", "Stay"):
		close()
		GameState.main.back_to_title()
