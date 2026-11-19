extends "res://scripts/ui/modal.gd"
## The Start menu: one large window with a strip of tabs across the top and two panes, a list on the left and the
## chosen row's details on the right (the menus of the early PS2 RPGs), on tan paper with a spine between the pages (book_paper.gd).
## Tabs: Trainer, Beasts, Flute, Bag, Codex, Map, Settings.
## Controls: ◄/► switch tabs (or adjust Default element / beast placement), ▲/▼ choose, A to act; ▲ at the top of a
## page goes to the tabs and ▼ (or A) from the tabs back into it; S (back) returns to the tabs / closes, Start closes.

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
const ScrollRail = preload("res://scripts/ui/scroll_rail.gd")
const WorldMap = preload("res://scripts/ui/world_map.gd")
const BeastsPage = preload("res://scripts/ui/beasts_page.gd")
const BagPage = preload("res://scripts/ui/bag_page.gd")
const BookPaper = preload("res://scripts/ui/book_paper.gd")
const Codex = preload("res://scripts/ui/codex.gd")
const CodexDB = preload("res://scripts/data/codex_db.gd")
const FluteGame = preload("res://scripts/ui/flute_game.gd")
const SpellDB = preload("res://scripts/data/spell_db.gd")

## Let the book show through the pad while keeping every control available.
var touch_controls_alpha := 0.55

const TABS := [
	{"id": "trainer", "name": "Trainer", "icon": "tab_trainer"},
	{"id": "beasts", "name": "Beasts", "icon": "tab_beasts"},
	{"id": "flute", "name": "Flute", "icon": "icon_notes"},
	{"id": "bag", "name": "Bag", "icon": "tab_bag"},
	{"id": "codex", "name": "Codex", "icon": "tab_codex"},
	{"id": "map", "name": "Map", "icon": "icon_map"},
	{"id": "settings", "name": "Settings", "icon": "tab_settings"},
]
## the tab strip's height, and the gap between the tabs and the window
const TAB_H := 64.0
const TAB_GAP := 6.0
## Two equal pages throughout the full-width book.
const LEFT_SHARE := 0.5
const SLOT_SHORT := {"weapon": "Weapon", "flute": "Flute", "head": "Hat", "feet": "Boots", "acc": "Charm"}
const CREST_ICONS := {"Wave Crest": "crest_wave", "Coral Crest": "crest_coral", "Spur Crest": "crest_spur", "Ore Crest": "crest_ore",
	"Cog Crest": "crest_cog", "Flame Crest": "crest_flame", "Vine Crest": "crest_vine", "River Crest": "crest_river"}
const ARENA_ORDER := ["tidewater", "kelpwick", "sundown", "copperpick", "cogsworth", "emberfall", "vinehollow", "riverbend"]

static var last_tab := 1
## Keep the mobile pad usable alongside direct row/tab taps. Start closes the book.
var hides_touch_pad := false

var world = null
## The Beast Center's and kennel's storage screen (Menus.storage_screen): only the Beasts page, without the tabs, with
## your stored beasts beside the ring (beasts_page.gd). B closes it.
var storage_mode := false
## First pickup: a short, skippable introduction using the journal's own tabs and pages.
var journal_tour := false
var _tour_input_after := 0
const TOUR_SKIP_HOLD := 0.8
var _tour_hold := 0.0
var _tour_cover: Control
var _tour_tip: PanelContainer
var _tour_meter: ProgressBar
var _tour_hud_alpha := -1.0
const TAB_INTROS := [
	"Your journal opens with Start. This page shows your portrait, gold, shield, arena crests and trainer gear.",
	"See your beasts and eggs, check their health and arrange your battle ring. Beast Centers handle storage.",
	"Find your songs, read what they do and practise playing them once you have a flute.",
	"Check your items and equipment. Choose an item to use it, equip it or read about it.",
	"Once you meet the Codex, come here to ask about the battle mechanics you've discovered.",
	"Once the librarian gives you a map, explore Rubisa here and read about its towns.",
	"Adjust sound, graphics, controls and your interface gem. You can also return to the title here.",
]
var tab := 1
var mode := "list"
var book: Control
var markers: Array = []
## the window's pages: tan paper with a spine at the fold (book_paper.gd), behind the window, whose own box is empty
var window: PanelContainer
var paper: Control
var divider: VSeparator
var tab_strip: HBoxContainer
var left_box: VBoxContainer
var right_box: VBoxContainer
## the right pane's scroller, and (Classic) the column it and its scroll buttons stand in
var right_scroll: ScrollContainer
var right_col: HBoxContainer
var list_box: VBoxContainer
var _list_tail: Control
var list_scroll: ScrollContainer
var detail_box: VBoxContainer
var rows: Array = []
var row_buttons: Array = []
var focus_row := 0
## the Map tab's world map (world_map.gd)
var map_view: Control
var _t := 0.0
var _keep_row := -1
var _changing_row := false
var _shown_inputs: Array[String] = []
## the gem the open page was built in (a page is rebuilt when it changes)
var _built_gem := ""
var beasts_page: Node
## the Bag tab's grid, actions and target ring while it's open (bag_page.gd)
var bag: Node


func setup(_world, start_tab := "") -> Control:
	world = _world
	dim = 0.55
	tab = last_tab
	for i in TABS.size():
		if TABS[i]["id"] == start_tab:
			tab = i
	return self


func _exit_tree() -> void:
	_restore_tour_hud()
	if UI.controls:
		UI.controls.show_legend(false)


func _ready() -> void:
	if UI.controls:
		UI.controls.show_legend(true)
	Sfx.play("page")
	_build()
	resized.connect(_layout)
	UI.controls.layout_changed.connect(_layout)
	if is_instance_valid(Prefs):
		Prefs.changed.connect(_on_prefs_changed)
	Controllers.changed.connect(_on_controllers_changed)
	_open_tab(tab)


## The tabs, the window and its two panes.
func _build() -> void:
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
		m.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		m.expand_icon = false
		m.add_theme_constant_override("icon_max_width", 36)
		m.text = GameState.codex_text(TABS[i]["name"])
		m.add_theme_font_override("font", UIKit.font_head())
		m.add_theme_font_size_override("font_size", UIKit.head_px(UIKit.HEAD_SMALL))
		m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		m.custom_minimum_size.y = TAB_H
		m.pressed.connect(_click_tab.bind(i))
		tab_strip.add_child(m)
		markers.append(m)
	tab_strip.visible = not storage_mode
	paper = BookPaper.new()
	book.add_child(paper)
	window = PanelContainer.new()
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.add_theme_stylebox_override("panel", _page_margins())
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
	# the fold between the pages: the paper draws the spine there, so the divider only keeps its room
	divider = VSeparator.new()
	divider.add_theme_stylebox_override("separator", StyleBoxEmpty.new())
	divider.item_rect_changed.connect(_place_spine)
	panes.add_child(divider)
	# the detail pane scrolls, so a tall page (a beast's skills and family tree on a phone) never pushes the window
	# off the screen, with up / down buttons beside it once it runs past a page (see scroll_rail.gd)
	right_col = HBoxContainer.new()
	right_col.add_theme_constant_override("separation", 6)
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_stretch_ratio = 1.0 - LEFT_SHARE
	right_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panes.add_child(right_col)
	right_scroll = _scroller()
	right_col.add_child(right_scroll)
	right_col.add_child(ScrollRail.new().setup(right_scroll))
	right_box = VBoxContainer.new()
	right_box.add_theme_constant_override("separation", 8)
	right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_scroll.add_child(right_box)
	_layout()


## A pane's scroller: up and down only, filling the room beside its scroll buttons.
func _scroller() -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return sc


## The window fills most of the screen (above the key guide or touch pad), so rows and text are big enough to tap.
func _layout() -> void:
	var vp := size if size.x > 0 else get_viewport_rect().size
	var avail := vp.y - (UI.bottom_reserve() if is_instance_valid(UI) else 0.0)
	var side := 24.0
	var top := 14.0
	var w := minf(vp.x - side * 2.0, 1232.0) if UI.is_touch() else vp.x - side * 2.0
	book.position = Vector2((vp.x - w) / 2.0, top)
	book.size = Vector2(w, avail - top - 10.0)
	tab_strip.position = Vector2.ZERO
	tab_strip.size = Vector2(w, TAB_H)
	# (storage mode has no tabs, but keeps their room free for the top-centre HUD's notices, such as "Embit was stored.")
	var tabs_h := TAB_H + TAB_GAP
	window.position = Vector2(0, tabs_h)
	window.size = Vector2(w, book.size.y - tabs_h)
	paper.position = window.position
	paper.size = window.size
	left_box.size_flags_stretch_ratio = _left_share()
	right_col.size_flags_stretch_ratio = 1.0 - _left_share()
	if is_instance_valid(_tour_tip):
		_place_tour_tip.call_deferred()


## The window's content padding with no box of its own (the paper behind it is the box).
func _page_margins() -> StyleBox:
	var src := UIKit.box("textfield")
	var sb := StyleBoxEmpty.new()
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sb.set_content_margin(side, src.get_content_margin(side))
	return sb


## The spine follows the divider between the pages.
func _place_spine() -> void:
	if not is_instance_valid(paper) or not is_instance_valid(divider):
		return
	paper.spine_x = divider.get_global_rect().get_center().x - paper.get_global_rect().position.x
	paper.refresh()


func _left_share() -> float:
	return LEFT_SHARE


## A new gem (from the Settings tab): the window and tabs are redrawn in it.
func _on_prefs_changed() -> void:
	if not is_inside_tree():
		return
	window.add_theme_stylebox_override("panel", _page_margins())
	paper.refresh()
	_style_tabs()
	if _changing_row:
		return
	if TABS[tab]["id"] == "settings":
		_keep_row = focus_row
		_open_tab(tab)
		return
	if _built_gem != UIKit.accent_name and mode == "list" and not row_buttons.is_empty():
		_keep_row = focus_row
		_open_tab(tab)
	elif _built_gem != UIKit.accent_name:
		var keep_mode := mode
		_open_tab(tab)
		mode = keep_mode


func _on_controllers_changed() -> void:
	if is_inside_tree() and TABS[tab]["id"] == "settings":
		if _shown_inputs != Prefs.available_inputs():
			_keep_row = focus_row
			_open_tab(tab)
		elif mode == "list" and focus_row < rows.size():
			_row_focused(focus_row)


## The tabs: rounded bookmarks; the open one filled with the gem with white text, the rest the book's tan paper with
## dim text.
func _style_tabs() -> void:
	for k in markers.size():
		var m: Button = markers[k]
		var open := k == tab
		var sb: StyleBox = UIKit.chip(UIKit.ACCENT, Color(0, 0, 0, 0), 0.0, Vector4(6, -2, 6, -2)) if open else UIKit.FrameBox.make("row", Color(0, 0, 0, 0), UIKit.book_paper(), false, Vector4(10, 0, 10, 0))
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
	if journal_tour:
		return
	if i != tab:
		Sfx.play("page")
		_open_tab(i)
	mode = "list"
	_focus_first()


func _open_tab(i: int) -> void:
	var keep_scroll := list_scroll.scroll_vertical if i == tab and is_instance_valid(list_scroll) else 0
	var keep_tail := _list_tail.custom_minimum_size.y if i == tab and is_instance_valid(_list_tail) else 0.0
	if i != tab:
		focus_row = 0
	tab = i
	last_tab = i
	_built_gem = UIKit.accent_name
	_style_tabs()
	_clear(left_box)
	_clear(right_box)
	rows = []
	row_buttons = []
	list_box = null
	_list_tail = null
	detail_box = null
	map_view = null
	if is_instance_valid(beasts_page):
		remove_child(beasts_page)
		beasts_page.queue_free()
	beasts_page = null
	if is_instance_valid(bag):
		bag.queue_free()
	bag = null
	right_scroll.scroll_vertical = 0
	_layout()
	match TABS[tab]["id"]:
		"trainer":
			_tab_trainer()
		"beasts":
			_tab_beasts()
		"flute":
			_tab_flute()
		"bag":
			_tab_bag()
		"codex":
			_tab_codex()
		"map":
			_tab_map()
		"settings":
			_tab_settings()
	if is_instance_valid(list_box):
		_list_tail = Control.new()
		_list_tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Keep the range valid while rebuilding a setting. Otherwise the
		# restored scroll value clamps before the trailing space is laid out.
		_list_tail.custom_minimum_size.y = keep_tail
		list_box.add_child(_list_tail)
	if mode == "list":
		_focus_first.call_deferred()
	if is_instance_valid(list_scroll):
		list_scroll.set_deferred("scroll_vertical", keep_scroll)
		_settle_list_focus(list_scroll)
	if journal_tour:
		_build_tour_tip()


## Input choices can resize the book while its rows are rebuilt. Wait for the
## containers to settle before ensuring the retained selection is fully visible.
func _settle_list_focus(scroll: ScrollContainer) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree() or not is_instance_valid(scroll) or scroll != list_scroll or focus_row >= row_buttons.size():
		return
	if UI.is_touch() and is_instance_valid(_list_tail):
		var rect := scroll.get_global_rect()
		var reserve: float = UI.controls.menu_bottom_reserve(rect.position.x, rect.end.x, true)
		# Enough trailing space to bring even the final row above the pad's
		# enlarged no-tap zone, without shrinking rows or moving the controls.
		_list_tail.custom_minimum_size.y = maxf(0.0, rect.end.y - (get_viewport_rect().size.y - reserve))
		await get_tree().process_frame
		await get_tree().process_frame
		if not is_instance_valid(scroll) or scroll != list_scroll or focus_row >= row_buttons.size():
			return
	if mode != "list":
		return
	scroll.ensure_control_visible(row_buttons[focus_row])
	_keep_focus_clear_of_pad(focus_row)


func _clear(c: Control) -> void:
	for ch in c.get_children():
		c.remove_child(ch)
		ch.queue_free()


## Puts a title, a scrolling list and (optionally) a detail area in the chosen panes.
func _make_list(on: VBoxContainer, title: String, detail_on: VBoxContainer = null) -> void:
	on.add_child(_pane_title(title))
	# with up / down buttons beside it once it runs past a page (see scroll_rail.gd)
	var side := HBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	on.add_child(side)
	list_scroll = _scroller()
	list_scroll.follow_focus = true
	side.add_child(list_scroll)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 0)
	list_scroll.add_child(list_box)
	side.add_child(ScrollRail.new().setup(list_scroll))
	detail_box = detail_on


## row: {text, right, icon, disabled, act: Callable, detail: Callable(VBoxContainer), adjust: Callable(dir), header: bool}
## The soft arrows either side of an adjustable value, in the value's colour (white while its row is lit).
func _value_arrows(rl: Label) -> void:
	var fs := rl.get_theme_font_size("font_size")
	var tw := rl.get_theme_font("font").get_string_size(rl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var col := rl.get_theme_color("font_color")
	var y := rl.size.y / 2.0
	var s := fs * 0.2
	load("res://scripts/ui/soft_arrow.gd").draw_arrow(rl, Vector2(rl.size.x - tw + fs * 0.5, y), Vector2.LEFT, s, col)
	load("res://scripts/ui/soft_arrow.gd").draw_arrow(rl, Vector2(rl.size.x - fs * 0.5, y), Vector2.RIGHT, s, col)


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
		# Adjustable values share their action label's size, including every Settings row.
		var value_size := UIKit.BUTTON_FONT_SIZE if row.has("adjust") else int(row.get("right_font", 20))
		# "◄ value ►": the value between two of the game's soft arrows (soft_arrow.gd), drawn rather than typed
		var value := str(row["right"])
		var arrows := value.begins_with("◄ ") and value.ends_with(" ►")
		if arrows:
			value = "     %s     " % value.trim_prefix("◄ ").trim_suffix(" ►")
		var rl := UIKit.label(value, value_size, UIKit.GOLD)
		UIKit.follow_row(b, rl, UIKit.GOLD)
		if arrows:
			rl.draw.connect(_value_arrows.bind(rl))
		var value_width := UIKit.font_body().get_string_size(rl.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			rl.get_theme_font_size("font_size")).x
		var right_width := maxf(float(row.get("right_width", 110)), value_width + 8.0)
		rl.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
		rl.offset_left = -right_width - 8.0
		rl.offset_right = -8
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(rl)
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = 22
		empty.content_margin_right = 12 + right_width
		var hl := UIKit.highlight(right_width)
		b.add_theme_stylebox_override("normal", empty)
		b.add_theme_stylebox_override("disabled", empty)
		for st in ["hover", "focus", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(st, hl)
	if row.has("sub"):
		# a second, small line under the name (a beast's HP and MP): the row grows to fit it
		var sub_h := 30.0
		# the name sits near the top and the small line just under it, the pair centred in the row
		var name_h := 40.0
		var row_h := maxf(UIKit.row_h(), name_h + sub_h + 12.0)
		var top := (row_h - name_h - sub_h) / 2.0
		b.custom_minimum_size.y = row_h
		for st in ["normal", "disabled", "hover", "focus", "pressed", "hover_pressed"]:
			if b.has_theme_stylebox_override(st):
				var box: StyleBox = b.get_theme_stylebox(st)
				box.content_margin_top = top
				box.content_margin_bottom = row_h - top - name_h
		if row.has("right"):
			(b.get_child(0) as Label).offset_bottom = -(row_h - top - name_h)
			(b.get_child(0) as Label).offset_top = top
		var sl := UIKit.label(str(row["sub"]), 20, UIKit.DIM)
		UIKit.follow_row(b, sl, UIKit.DIM)
		sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sl.set_anchors_preset(Control.PRESET_TOP_WIDE)
		# (left-aligned with the name: past the row's padding, the icon as drawn and the gap after it)
		var sub_left := 22.0
		if b.icon != null:
			sub_left += b.icon.get_width() + b.get_theme_constant("h_separation") + 4.0
		sl.offset_left = sub_left
		sl.offset_right = -12
		sl.offset_top = top + name_h - 4.0
		sl.offset_bottom = top + name_h - 4.0 + sub_h
		sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_child(sl)
		row["sub_label"] = sl
	if row.has("item_slot"):
		# One square item slot per stack, with a readable action label beside it.
		b.custom_minimum_size.y = maxf(96, UIKit.row_h())
		var pad := StyleBoxEmpty.new()
		pad.content_margin_left = 112
		b.add_theme_stylebox_override("normal", pad)
		var highlight := UIKit.highlight()
		highlight.content_margin_left = 112
		for state in ["focus", "hover"]:
			b.add_theme_stylebox_override(state, highlight)
		for state in ["pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(state, UIKit.solid(Vector4(112, 0, 0, 0)))
		var slot := Panel.new()
		slot.position = Vector2(8, 4)
		slot.size = Vector2(88, 88)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_theme_stylebox_override("panel", UIKit.slot_box())
		b.add_child(slot)
		var icon := TextureRect.new()
		icon.texture = UI.Glyphs.item(row["item_slot"])
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if UI.Glyphs.smooth(icon.texture) else CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.position = Vector2(24, 8)
		icon.size = Vector2(40, 40)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		var count := UIKit.label("x%d" % int(row["stack_count"]), 32)
		count.position = Vector2(0, 48)
		count.size = Vector2(88, 36)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(count)
	var idx := rows.size()
	if idx == 0:
		# Up on the first row goes back to the tabs, before focus navigation looks for something above it
		b.gui_input.connect(func(ev: InputEvent) -> void:
			if mode == "list" and ev.is_action_pressed("ui_up") and to_tabs():
				b.accept_event())
	b.pressed.connect(_activate.bind(idx))
	b.focus_entered.connect(_row_focused.bind(idx))
	b.mouse_entered.connect(func(): if mode == "list": b.grab_focus())
	list_box.add_child(b)
	rows.append(row)
	row_buttons.append(b)


func _focus_first() -> void:
	if journal_tour:
		if is_instance_valid(_tour_cover):
			_tour_cover.grab_focus()
		return
	if is_instance_valid(bag):
		bag.focus()
		return
	if is_instance_valid(map_view):
		map_view.grab_focus()
		mode = "list"
		return
	if row_buttons.is_empty():
		mode = "tabs"
		return
	var i := clampi(_keep_row if _keep_row >= 0 else focus_row, 0, row_buttons.size() - 1)
	_keep_row = -1
	(row_buttons[i] as Button).grab_focus()
	_row_focused(i)
	if is_instance_valid(list_scroll):
		list_scroll.ensure_control_visible.call_deferred(row_buttons[i])


func _row_focused(i: int) -> void:
	if i != focus_row:
		Sfx.play("select")
	focus_row = i
	mode = "list"
	var row: Dictionary = rows[i]
	if detail_box != null and row.has("detail"):
		_clear(detail_box)
		if detail_box == right_box:
			right_scroll.scroll_vertical = 0
		(row["detail"] as Callable).call(detail_box)
	_keep_focus_clear_of_pad.call_deferred(i)


func _keep_focus_clear_of_pad(i: int) -> void:
	if not is_inside_tree() or not UI.is_touch() or i != focus_row or i >= row_buttons.size() or not is_instance_valid(list_scroll):
		return
	var rect: Rect2 = row_buttons[i].get_global_rect()
	var reserve: float = UI.controls.menu_bottom_reserve(rect.position.x, rect.end.x, true)
	var bottom := minf(list_scroll.get_global_rect().end.y, get_viewport_rect().size.y - reserve)
	if rect.end.y > bottom:
		list_scroll.scroll_vertical += ceili(rect.end.y - bottom)


func _activate(i: int) -> void:
	if is_instance_valid(beasts_page) and beasts_page.activate(i):
		return
	if mode != "list":
		mode = "list"
	var row: Dictionary = rows[i]
	if row.get("disabled", false) or not row.has("act"):
		Sfx.play("error")
		return
	Sfx.play("confirm")
	_changing_row = true
	await (row["act"] as Callable).call()
	_changing_row = false
	if closed:
		return
	_keep_row = i
	_open_tab(tab)


func _process(delta: float) -> void:
	_t += delta
	if journal_tour:
		if is_instance_valid(_tour_cover) and not _tour_cover.has_focus():
			_tour_cover.grab_focus()
		# A tap of B does nothing; only a deliberate hold skips the tour.
		_tour_hold = _tour_hold + delta if Input.is_action_pressed("ui_cancel") else 0.0
		if is_instance_valid(_tour_meter):
			_tour_meter.value = _tour_hold / TOUR_SKIP_HOLD
		if _tour_hold >= TOUR_SKIP_HOLD:
			_finish_tour()
	# while the tabs have the cursor, the open tab pulses
	for k in markers.size():
		(markers[k] as Control).modulate = Color(1, 1, 1, 0.7 + 0.3 * absf(sin(_t * 4.0))) if k == tab and mode == "tabs" else Color.WHITE


func on_input(ev: InputEvent) -> void:
	if ev.is_echo() and not (ev.is_action("ui_left") or ev.is_action("ui_right")):
		return
	if not ev.is_pressed():
		return
	if journal_tour:
		if ev.is_action_pressed("ui_accept"):
			_tour_next()
		return
	if ev.is_action_pressed("menu"):
		_close_book()
		return
	if is_instance_valid(bag) and bag.on_input(ev):
		return
	if is_instance_valid(beasts_page) and beasts_page.on_input(ev):
		return
	if ev.is_action_pressed("ui_cancel"):
		if mode == "list" and not storage_mode:
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
			var keep := focus_row
			_changing_row = true
			(rows[focus_row]["adjust"] as Callable).call(dir)
			_changing_row = false
			Sfx.play("toggle")
			_keep_row = keep
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


## Up from the top of a page (its first row, the Bag's top row of slots, the Map's northernmost town): the cursor goes
## back to the tab strip. Returns false where there are no tabs (the storage screen).
func to_tabs() -> bool:
	if storage_mode or mode != "list":
		return false
	Sfx.play("select")
	mode = "tabs"
	get_viewport().gui_release_focus()
	return true


func _close_book() -> void:
	Sfx.play("back")
	close()


# ================================================================ small builders
func _build_tour_tip() -> void:
	_tour_input_after = Time.get_ticks_msec() + 180
	_tour_hold = 0.0
	get_viewport().gui_release_focus()
	if is_instance_valid(_tour_cover):
		_tour_cover.free()
	# The actual page remains visible, but no row, tab or setting can activate underneath its tooltip.
	_tour_cover = Control.new()
	_tour_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tour_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	_tour_cover.focus_mode = Control.FOCUS_ALL
	add_child(_tour_cover)
	_tour_cover.grab_focus()
	for direction in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_tour_cover.set_focus_neighbor(direction, _tour_cover.get_path())
	_tour_tip = PanelContainer.new()
	_tour_tip.add_theme_stylebox_override("panel", UIKit.window(Vector4(20, 14, 20, 14)))
	_tour_cover.add_child(_tour_tip)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 8)
	_tour_tip.add_child(lines)
	lines.add_child(_h("%s · %d / %d" % [GameState.codex_text(TABS[tab]["name"]), tab + 1, TABS.size()], UIKit.HEAD, UIKit.HEAD_SMALL))
	var explanation := UIKit.label(GameState.codex_text(TAB_INTROS[tab]), 24, UIKit.INK)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lines.add_child(explanation)
	lines.add_child(_row_of([
		_tour_prompt(SongDB.BTN_A, "TourA"), UIKit.label("Finish" if tab == TABS.size() - 1 else "Next", 20, UIKit.INK),
		UIKit.label(" ·  Hold", 20, UIKit.INK), _tour_prompt(SongDB.BTN_B, "TourB"), UIKit.label("Skip", 20, UIKit.INK),
	]))
	_tour_meter = ProgressBar.new()
	_tour_meter.max_value = 1.0
	_tour_meter.show_percentage = false
	_tour_meter.custom_minimum_size.y = 4
	_tour_meter.add_theme_stylebox_override("background", UIKit.FrameBox.make("row", Color.TRANSPARENT, UIKit.WELL, false, Vector4.ZERO))
	_tour_meter.add_theme_stylebox_override("fill", UIKit.FrameBox.make("row", Color.TRANSPARENT, UIKit.ACCENT, false, Vector4.ZERO))
	lines.add_child(_tour_meter)
	if _tour_hud_alpha < 0.0:
		_tour_hud_alpha = UI.top_bar.modulate.a
		UI.top_bar.modulate.a = 0.0
	_place_tour_tip.call_deferred()
	_tour_tip.resized.connect(_place_tour_tip)


## Reuse the flute sheet's smooth circular prompts and its per-button colours.
func _tour_prompt(button: int, node_name: String) -> TextureRect:
	var icon := TextureRect.new()
	icon.name = node_name
	icon.texture = FluteGame.PROMPTS[button]
	icon.self_modulate = FluteGame.BTN_COLORS[button]
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _place_tour_tip() -> void:
	if not is_instance_valid(_tour_tip):
		return
	var width := minf(620.0, size.x - 48.0)
	_tour_tip.size = Vector2(width, 0)
	_tour_tip.position = Vector2((size.x - width) / 2.0, size.y - UI.bottom_reserve() - _tour_tip.size.y - 18.0)


func _restore_tour_hud() -> void:
	if _tour_hud_alpha >= 0.0 and is_instance_valid(UI.top_bar):
		UI.top_bar.modulate.a = _tour_hud_alpha
		_tour_hud_alpha = -1.0


func _tour_next() -> void:
	if Time.get_ticks_msec() < _tour_input_after:
		return
	if tab == TABS.size() - 1:
		_finish_tour()
	else:
		Sfx.play("page")
		_open_tab(tab + 1)


func _finish_tour() -> void:
	if Time.get_ticks_msec() < _tour_input_after:
		return
	journal_tour = false
	_tour_cover.queue_free()
	_restore_tour_hud()
	Sfx.play("page")
	_open_tab(0)


## Rows work by direct tap or A; the d-pad remains available while the book is open.
func _press() -> String:
	return "Tap" if UI.is_touch() else "Press A"


func _adjust_hint() -> String:
	return "Tap to change it" if UI.is_touch() else "Use ◄/► to adjust"


func _h(text: String, color := UIKit.INK, size := UIKit.HEAD_SIZE) -> Label:
	return UIKit.header(text, color, size)


func _t_label(text: String, color := UIKit.INK, big := false, wrap := true) -> Label:
	# (wrapping text is prose: Regular; a short unwrapped caption is small text, bold upper case)
	var l := UIKit.label(text, 24 if big or wrap else 20, color)
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


## A pane's title: a heading in the gem over the divider.
func _pane_title(text: String) -> Control:
	var vb := VBoxContainer.new()
	vb.name = "PaneTitle"
	vb.add_theme_constant_override("separation", 4)
	vb.add_child(UIKit.header(text, UIKit.HEAD, UIKit.HEAD_SIZE))
	vb.add_child(UIKit.divider(0.0, "right"))
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
	info.add_child(_w("Caught %d / %d" % [GameState.caught.size(), RaceDB.count()]))
	var nxt := GameState.trainer_xp_for(GameState.trainer_level + 1)
	info.add_child(_w("Trainer Lv %d%s" % [GameState.trainer_level, ("  (%d / %d XP)" % [GameState.trainer_xp, nxt]) if GameState.trainer_level < GameState.TRAINER_LEVEL_MAX else ""]))
	info.add_child(_w("Beast slots %d / %d" % [GameState.beast_slots, GameState.PARTY_MAX]))
	if GameState.trainer_mp_unlocked():
		info.add_child(_w("MP %d / %d" % [GameState.trainer_mp, GameState.trainer_max_mp()]))
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
	for slot in ["weapon", "flute", "head", "feet", "acc"]:
		var id: String = GameState.gear[slot]
		_add_row({"text": SLOT_SHORT[slot], "right": ItemDB.item_name(id) if id != "" else "—", "right_width": 190,
			"act": func(): await Menus.equip_trainer_slot(slot),
			"detail": func(c): c.add_child(_t_label(ItemDB.get_item(id).get("desc", "Nothing equipped.") if id != "" else "Nothing equipped. %s to equip trainer gear." % _press()))})
	var hints: Array = Story.ChatterDB.HINTS.get(Story.next_goal(), [])
	if not hints.is_empty():
		_add_row({"text": "Next objective", "detail": func(c): c.add_child(_t_label(hints[0]))})
	# the spells you know (spell_db.gd), each as your equipped weapon delivers it
	for sid in GameState.known_spells:
		_add_row({"text": "Spell", "right": SpellDB.spell_name(sid), "right_width": 190,
			"detail": func(c): _spell_detail(c, String(sid))})


func _spell_detail(c: VBoxContainer, sid: String) -> void:
	var s := SpellDB.get_spell(sid)
	c.add_child(_h(SpellDB.spell_name(sid)))
	c.add_child(_t_label("%s · %d MP" % [Elements.label(SpellDB.element(sid)).capitalize(), SpellDB.mp_cost(sid)]))
	c.add_child(_t_label(String(s.get("desc", ""))))
	var names := []
	for w in ItemDB.WEAPONS:
		if GameState.item_count(w) > 0:
			names.append("%s: %s" % [ItemDB.item_name(w), SpellDB.attack_name(sid, w)])
	c.add_child(_t_label("\n".join(names)))
	if SpellDB.has_field_use(sid):
		c.add_child(_t_label("Play the water song near water in the field to use it there."))


# ================================================================ Beasts
func _tab_beasts() -> void:
	beasts_page = BeastsPage.new().setup(self, storage_mode)
	add_child(beasts_page)


func _egg_detail(c: VBoxContainer, e: Dictionary) -> void:
	c.add_child(_h(GameState.egg_name(e)))
	var shell := TextureRect.new()
	shell.texture = GameState.EggLooks.icon(e)
	shell.custom_minimum_size = Vector2(144, 144)
	shell.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shell.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	c.add_child(shell)
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
		_add_row({"text": "No flute yet", "detail": func(c): c.add_child(_t_label("Your father's reed flute is waiting for you with Uncle Rafe in Bellerive, east along the Coastal Path. He'll teach you to play it."))})
		return
	_make_list(left_box, "Songs %d / %d" % [GameState.songs.size(), SongDB.ORDER.size()], right_box)
	# the songs you know come first (battle songs, then temple songs), the ones still to learn after them
	var known_ids := []
	var unknown_ids := []
	for sid in SongDB.ordered(GameState.songs):
		(known_ids if GameState.knows_song(sid) else unknown_ids).append(sid)
	var temple := known_ids.filter(func(id): return SongDB.get_song(id)["kind"] == "summon")
	var battle := known_ids.filter(func(id): return SongDB.get_song(id)["kind"] == "effect")
	var hdr := ""
	for sid in battle + temple + unknown_ids:
		var s := SongDB.get_song(sid)
		var known := GameState.knows_song(sid)
		var want: String = {"summon": "TEMPLE SONGS"}.get(s["kind"], "BATTLE SONGS") if known else "NOT YET LEARNED"
		if want != hdr:
			hdr = want
			_add_row({"header": true, "text": hdr})
		var right := SongDB.tag(sid) if known else ""
		if known and s["kind"] == "summon":
			# whether its guardian is yours yet
			right = "SUMMON" if GameState.summons.has(String(s["summon"])) else "GUARDIAN"
		_add_row({"text": s["name"] if known else "? ? ?", "right": right, "right_width": 150,
			"disabled": not known, "detail": _song_detail.bind(sid), "act": _song_act.bind(sid)})


func _song_act(sid: String) -> void:
	if not GameState.knows_song(sid):
		return
	await Places.practice_once(sid)


func _song_detail(c: VBoxContainer, sid: String) -> void:
	var s := SongDB.get_song(sid)
	var known := GameState.knows_song(sid)
	if not known:
		c.add_child(_h("Unknown song"))
		c.add_child(_t_label("Where to learn it: " + String(s["from"]), UIKit.DIM))
		return
	c.add_child(_h(s["name"]))
	var kt := UIKit.tag({"summon": "SUMMON"}.get(s["kind"], "BATTLE"), UIKit.ACCENT)
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
	c.add_child(_t_label("Each star of mastery makes the song stronger and adds notes to practise. In battle you play only its first melody.", UIKit.DIM))
	c.add_child(_spacer())
	c.add_child(_t_label("Learned from: " + String(s["from"]), UIKit.DIM))
	var lv := GameState.song_level(sid)
	c.add_child(_t_label("Level %d of %d  ·  %d notes" % [lv, SongDB.max_level(sid), SongDB.note_count(sid, lv)], UIKit.DIM))
	c.add_child(_spacer())
	var flute: String = GameState.gear["flute"]
	c.add_child(_t_label("Your flute: %s" % ItemDB.item_name(flute)))
	c.add_child(_t_label("%s to practise it." % _press(), UIKit.ACCENT))


## The Bag: a grid of item slots and the chosen item's details, actions and targets (bag_page.gd).
func _tab_bag() -> void:
	bag = BagPage.new().setup(self)
	add_child(bag)
	bag.build(_keep_row if _keep_row >= 0 else focus_row)
	_keep_row = -1


# ================================================================ Codex
## The Codex's topics (codex_db.gd): only what you're eligible to know, by group. A topic's words show on the right;
## A has the Codex say them.
func _tab_codex() -> void:
	if not CodexDB.has_codex():
		_make_list(left_box, GameState.codex_name(), right_box)
		_add_row({"text": GameState.codex_text("No Codex yet"), "detail": func(c): c.add_child(_t_label("Trainers along the Coastal Path are teaching you to battle. Picnicker Mae, the last of them, has something for you."))})
		return
	_make_list(left_box, "Ask " + GameState.codex_name(), right_box)
	for g in CodexDB.menu():
		_add_row({"header": true, "text": String(g["group"]).to_upper()})
		for id in g["ids"]:
			_add_row({"text": CodexDB.title(id), "detail": _codex_detail.bind(String(id)), "act": Codex.explain.bind(String(id))})


func _codex_detail(c: VBoxContainer, id: String) -> void:
	c.add_child(_h(CodexDB.title(id)))
	c.add_child(_t_label(CodexDB.plain(id)))
	if id == "spells":
		for sid in GameState.known_spells:
			c.add_child(_t_label("%s · %d MP" % [SpellDB.attack_name(sid, GameState.weapons()[0]), SpellDB.mp_cost(sid)]))
	c.add_child(_t_label("A: Ask " + GameState.codex_name(), UIKit.DIM))


# ================================================================ Map
## The world map across the left page, with you marked on it; the town picked on it (by tap or the d-pad) is
## described on the right. Once an air beast of yours can carry you (Places.own_flyer), you can fly from here to any
## town you've visited.
func _tab_map() -> void:
	left_box.add_child(_pane_title("Rubisa"))
	if not GameState.flags.get("world_map", true):
		left_box.add_child(_t_label("You don't have a map yet. Librarian Quill has a free one for you at Cocoon Cove Library, beside the path from home to the square.", UIKit.DIM))
		return
	map_view = WorldMap.new().setup(GameState.map_id)
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_view.focused.connect(_town_focused)
	map_view.activated.connect(_fly_to)
	map_view.focus_entered.connect(func() -> void: mode = "list")
	map_view.edge_up.connect(func() -> void: to_tabs())
	left_box.add_child(map_view)
	detail_box = right_box
	_town_focused(map_view.town())


func _town_focused(t: String) -> void:
	_clear(right_box)
	right_scroll.scroll_vertical = 0
	_town_detail(right_box, t)


func _town_detail(c: VBoxContainer, t: String) -> void:
	var info: Dictionary = WorldDB.TOWNS[t]
	var here: bool = map_view.here == t
	if not GameState.visited.has(t):
		c.add_child(_h("Unexplored"))
		c.add_child(_t_label("You haven't been here yet. Keep following the roads!", UIKit.DIM))
		return
	c.add_child(_h(info["name"]))
	if here:
		c.add_child(_t_label("You are here.", UIKit.ACCENT))
	elif WorldDB.ROUTES.has(map_view.here):
		var r: Dictionary = WorldDB.ROUTES[map_view.here]
		if t in [r["from"], r["to"]]:
			c.add_child(_t_label("You're on the %s, which leads here." % r["name"], UIKit.ACCENT))
	var flyer = Places.own_flyer()
	if flyer != null and not here:
		# (kept near the top, where it's in view without scrolling)
		if _can_fly():
			var fly := Button.new()
			fly.text = "Fly here"
			fly.focus_mode = Control.FOCUS_NONE
			UIKit.plate_button(fly)
			fly.custom_minimum_size = Vector2(220, UIKit.row_h())
			fly.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			fly.pressed.connect(_fly_to.bind(t))
			c.add_child(fly)
			c.add_child(_t_label("%s can carry you here.%s" % [flyer.nickname, "" if UI.is_touch() else " Press A to fly."], UIKit.DIM))
		else:
			c.add_child(_t_label("Step outside, and %s can fly you here." % flyer.nickname, UIKit.DIM))
	c.add_child(_spacer())
	c.add_child(_t_label("%s  ·  Mascot: %s" % [String(info["size"]).capitalize(), RaceDB.race_name(info["mascot"])], UIKit.DIM))
	c.add_child(_t_label(info["blurb"]))
	var roads := []
	for rid in WorldDB.ROUTES:
		if t in [WorldDB.ROUTES[rid]["from"], WorldDB.ROUTES[rid]["to"]]:
			roads.append(WorldDB.ROUTES[rid]["name"])
	c.add_child(_t_label("Roads: " + ", ".join(roads), UIKit.DIM))
	var shops := []
	for s in info["shops"]:
		var place: String = info.get("place_names", {}).get(s, "Library" if t == "caccoon" and s == "bookstore" else String(s).replace("_", " ").capitalize())
		if not s in ["house", "uncle"] and not shops.has(place):
			shops.append(place)
	shops.append_array(info.get("landmarks", []))
	c.add_child(_t_label("Places: " + ", ".join(shops), UIKit.DIM))
	if WorldDB.ARENAS.has(t):
		var a: Dictionary = WorldDB.ARENAS[t]
		var won: bool = GameState.crests.has(a["crest"])
		c.add_child(_row_of([UIKit.icon(CREST_ICONS.get(a["crest"], "crest_empty") if won else "crest_empty"),
			_w("%s %s
%s" % [a["title"], a["leader"], "Crest won!" if won else "Not yet challenged"])]))


## Flying needs open sky: not from indoors.
func _can_fly() -> bool:
	return world != null and not world.interior


## A visited town picked on the map (A, or Fly here): your air beast flies you there, once you say yes.
func _fly_to(t: String) -> void:
	var flyer = Places.own_flyer()
	if flyer == null or not _can_fly() or t == map_view.here or not GameState.visited.has(t):
		if flyer != null:
			Sfx.play("error")
		return
	if not await UI.ask("Fly to %s with %s?" % [WorldDB.map_name(t), flyer.nickname]):
		return
	await Places.fly_to(t)
	close()


# ================================================================ Settings
func _tab_settings() -> void:
	_make_list(left_box, "Settings")
	detail_box = VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 6)
	right_box.add_child(_pane_title("Controls"))
	right_box.add_child(detail_box)
	var pct := func(v: float): return "%d%%" % int(round(v * 100))
	var ri: int = Prefs.RESOLUTIONS.find(Prefs.render_height)
	_add_row({"text": "Resolution", "right": "◄ %dp ►" % Prefs.render_height, "right_width": 210, "right_font": UIKit.BUTTON_FONT_SIZE,
		"adjust": func(d): Prefs.set_value("render_height", Prefs.RESOLUTIONS[posmod(ri + d, Prefs.RESOLUTIONS.size())]),
		"act": func(): Prefs.set_value("render_height", Prefs.RESOLUTIONS[posmod(ri + 1, Prefs.RESOLUTIONS.size())]),
		"detail": _controls_help.bind("3D resolution: 540p, 720p, 1080p or 1440p. Lower is faster, with crisp pixels. Menus stay sharp. %s." % _adjust_hint())})
	var qi: int = Prefs.QUALITY_ORDER.find(Prefs.graphics_quality)
	_add_row({"text": "Graphics", "right": "◄ %s ►" % Prefs.graphics_quality.capitalize(), "right_width": 210, "right_font": UIKit.BUTTON_FONT_SIZE,
		"adjust": func(d): Prefs.set_value("graphics_quality", Prefs.QUALITY_ORDER[posmod(qi + d, Prefs.QUALITY_ORDER.size())]),
		"act": func(): Prefs.set_value("graphics_quality", Prefs.QUALITY_ORDER[posmod(qi + 1, Prefs.QUALITY_ORDER.size())]),
		"detail": _controls_help.bind("Min: no dynamic shadows, glow or anti-aliasing. Mid: soft shadows, glow and 2x anti-aliasing. Max: 4x anti-aliasing and supported ambient occlusion. Works at any resolution.")})
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
	if CodexDB.has_codex():
		var codex_on := not GameState.flag("codex_off")
		_add_row({"text": "Codex tips", "right": "◄ %s ►" % ("On" if codex_on else "Off"), "right_width": 150,
			"adjust": func(_d): GameState.set_flag("codex_off", codex_on),
			"act": func(): GameState.set_flag("codex_off", codex_on),
			"detail": _controls_help.bind("On: your Codex chimes in the first time something new comes up in battle. Off: it stays quiet, but you can still ask it anything.")})
	var gems: Array = UIKit.ACCENT_ORDER
	var gi := maxi(0, gems.find(UIKit.accent_name))
	_add_row({"text": "Color", "right": "◄ %s ►" % UIKit.gem_name(gems[gi]), "right_width": 150,
		"adjust": func(d): Prefs.set_value("accent", gems[posmod(gi + d, gems.size())]),
		"act": func(): Prefs.set_value("accent", gems[posmod(gi + 1, gems.size())]),
		"detail": _controls_help.bind("The color used for window tints, headings and bars: Ruby, Sapphire, Emerald or Hematite.")})
	var inputs := Prefs.available_inputs()
	_shown_inputs = inputs.duplicate()
	var current := maxi(0, inputs.find(Prefs.effective_input()))
	_add_row({"text": "Input", "right": "◄ %s ►" % Prefs.effective_input().capitalize(), "right_width": 240,
		"adjust": func(d): Prefs.set_value("input_mode", inputs[posmod(current + d, inputs.size())]),
		"act": func(): Prefs.set_value("input_mode", inputs[posmod(current + 1, inputs.size())]),
		"detail": _controls_help.bind("Choose an available input. Controls are fixed.")})
	_add_row({"text": "Key guide", "right": "◄ %s ►" % ("On" if Prefs.show_key_legend else "Off"), "right_width": 150,
		"adjust": func(_d): Prefs.set_value("show_key_legend", not Prefs.show_key_legend),
		"act": func(): Prefs.set_value("show_key_legend", not Prefs.show_key_legend),
		"detail": _controls_help.bind("The strip at the bottom of the screen that shows which keys do what.")})
	_add_row({"text": "Diagonal movement", "right": "◄ %s ►" % ("On" if Prefs.diagonal_movement else "Off"), "right_width": 150,
		"adjust": func(_d): Prefs.set_value("diagonal_movement", not Prefs.diagonal_movement),
		"act": func(): Prefs.set_value("diagonal_movement", not Prefs.diagonal_movement),
		"detail": _controls_help.bind("On: move eight ways with two arrow keys, the controller stick or d-pad, or the touch pad's corners. Off: move four ways. You cannot cut blocked corners. Hold B to run.")})
	if not Prefs.is_mobile():
		_add_row({"text": "Fullscreen", "right": "◄ %s ►" % ("On" if Prefs.fullscreen else "Off"), "right_width": 150,
			"adjust": func(_d): Prefs.set_value("fullscreen", not Prefs.fullscreen),
			"act": func(): Prefs.set_value("fullscreen", not Prefs.fullscreen),
			"detail": _controls_help.bind("Play in a window or full screen.")})
	_add_row({"text": "Credits", "act": _credits, "detail": _controls_help.bind("The artists, musicians and sound designers behind Ruby Cocoon.")})
	_add_row({"text": "Quit to title", "act": _quit, "detail": _controls_help.bind("Return to the title screen. Unsaved progress is lost!")})


func _controls_help(c: VBoxContainer, what: String) -> void:
	c.add_child(_t_label(what, UIKit.HEAD))
	var guide = load("res://scripts/ui/input_guide.gd").new()
	c.add_child(guide)


func _credits() -> void:
	await Menus.credits()


func _quit() -> void:
	if await UI.ask("Return to the title screen? Unsaved progress will be lost.", "", "Quit", "Stay"):
		close()
		GameState.main.back_to_title()
