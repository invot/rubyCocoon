extends "res://scripts/ui/modal.gd"
## Arranging your beasts (the Beasts page of the book): your battle ring as eight big cells round you, the side that
## faces the foe at the top, and your storage as a grid of cells beside it (its beasts, and an empty cell at the end).
## Pick a beast (tap it, or move the cursor with the d-pad and press A), then where it should go: only the cells it may
## go to light up, the rest darken. A slot it can stand on (trading places with whoever is there, if they can stand on
## its old one), or a storage cell (swapping with the beast in it, or into the empty one). Tap the beast again, or B,
## to put it back down; B again, or Done, closes. The rules are GameState.ring_move_reason's.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Ring = preload("res://scripts/core/ring.gd")
const PixelArt = preload("res://scripts/gfx/pixel_art.gd")

## storage's cells per row
const STORE_COLS := 4

## On a phone the d-pad and A/B buttons hide while this is open: the cells are tapped, and Done closes it.
var hides_touch_pad := true

var window: PanelContainer
var ring_area: Control
var store_scroll: ScrollContainer
var store_grid: GridContainer
var count_label: Label
var info_box: VBoxContainer
var hint: Label
var done_button: Button
## the ring's eight cells (by slot), then storage's
var cells: Array = []
## the beast picked up, or null
var picked = null
var _time := 0.0


func _ready() -> void:
	dim = 0.6
	queue_redraw()
	Sfx.play("open")
	window = PanelContainer.new()
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(window)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	window.add_child(vb)
	var top := HBoxContainer.new()
	vb.add_child(top)
	var title := UIKit.header("Arrange your beasts", UIKit.LIGHT, UIKit.HEAD_SIZE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	count_label = UIKit.label("", 20, UIKit.GOLD)
	top.add_child(count_label)
	var panes := HBoxContainer.new()
	panes.add_theme_constant_override("separation", 22)
	panes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(panes)
	ring_area = Control.new()
	ring_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ring_area.size_flags_stretch_ratio = 1.1
	ring_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring_area.draw.connect(_draw_ring)
	ring_area.resized.connect(_place_ring)
	panes.add_child(ring_area)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panes.add_child(right)
	right.add_child(UIKit.header("STORAGE", UIKit.GOLD, UIKit.HEAD_SMALL))
	store_scroll = ScrollContainer.new()
	store_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	store_scroll.follow_focus = true
	store_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(store_scroll)
	store_grid = GridContainer.new()
	store_grid.columns = STORE_COLS
	store_grid.add_theme_constant_override("h_separation", 8)
	store_grid.add_theme_constant_override("v_separation", 8)
	store_scroll.add_child(store_grid)
	info_box = VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 2)
	info_box.custom_minimum_size.y = 96
	right.add_child(info_box)
	hint = UIKit.label("", 20, UIKit.ACCENT.lightened(0.35))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(120, 52)
	right.add_child(hint)
	done_button = Button.new()
	done_button.text = "Done"
	done_button.custom_minimum_size = Vector2(200, 56)
	done_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	var chip := UIKit.chip(UIKit.ACCENT, UIKit.BORDER, 16.0, Vector4(18, 4, 18, 4), 3.0)
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		done_button.add_theme_stylebox_override(st, chip)
	done_button.add_theme_color_override("font_color", UIKit.LIGHT)
	done_button.add_theme_color_override("font_focus_color", UIKit.LIGHT)
	done_button.add_theme_color_override("font_hover_color", UIKit.LIGHT)
	done_button.pressed.connect(_close)
	right.add_child(done_button)
	for k in Ring.SLOTS:
		var c := Cell.new(self, {"slot": k})
		ring_area.add_child(c)
		cells.append(c)
	_fill_storage()
	_layout()
	resized.connect(_layout)
	_refresh()
	(cells[GameState.ring_side * 2] as Control).grab_focus.call_deferred()


## The window fills most of the screen, so the cells are big enough to tap.
func _layout() -> void:
	var vp := size if size.x > 0 else get_viewport_rect().size
	var avail := vp.y - (UI.bottom_reserve() if is_instance_valid(UI) else 0.0)
	var w := minf(vp.x - 48.0, 1240.0)
	window.position = Vector2(roundf((vp.x - w) / 2.0), 14.0)
	window.size = Vector2(w, avail - 24.0)


## Storage's cells: one per beast, and an empty one at the end to put a beast into.
func _fill_storage() -> void:
	for c in cells.slice(Ring.SLOTS):
		store_grid.remove_child(c)
		c.queue_free()
	cells = cells.slice(0, Ring.SLOTS)
	for j in GameState.storage.size() + 1:
		var c := Cell.new(self, {"store": j})
		c.custom_minimum_size = Vector2(88, 88)
		store_grid.add_child(c)
		cells.append(c)


## Where the ring sits in its pane: [its centre, its radius, a cell's size], under a line saying which side faces the
## foe.
func _ring_geometry() -> Array:
	var top := 34.0
	var s := minf(ring_area.size.x, ring_area.size.y - top)
	var cell := clampf(s * 0.22, 72.0, 120.0)
	return [Vector2(ring_area.size.x / 2.0, top + s / 2.0), s / 2.0 - cell * 0.52, cell]


## The ring's cells round the trainer, the side facing the foe at the top (as in the book's ring diagram).
func _place_ring() -> void:
	var g := _ring_geometry()
	var mid := GameState.ring_side * 2
	for k in Ring.SLOTS:
		var a := float(k - mid) * TAU / 8.0
		var p: Vector2 = g[0] + Vector2(sin(a), -cos(a)) * float(g[1])
		var cc: Control = cells[k]
		cc.size = Vector2(g[2], g[2])
		cc.position = p - cc.size / 2.0
	ring_area.queue_redraw()


## The ring itself under the cells: its circle and the trainer in the middle, under a line saying which side faces
## the foe (each cell names the elements it takes).
func _draw_ring() -> void:
	var g := _ring_geometry()
	var c: Vector2 = g[0]
	var rad: float = g[1]
	ring_area.draw_arc(c, rad, 0, TAU, 64, Color(UIKit.BORDER, 0.3), 3.0, true)
	ring_area.draw_circle(c, rad * 0.3, Color(UIKit.WINDOW_BOTTOM, 0.95))
	ring_area.draw_arc(c, rad * 0.3, 0, TAU, 32, Color(UIKit.BORDER, 0.6), 2.0, true)
	var h := rad * 0.11
	ring_area.draw_circle(c + Vector2(0, -h * 1.1), h * 0.55, UIKit.LIGHT)
	ring_area.draw_colored_polygon(PackedVector2Array([c + Vector2(-h * 0.8, h * 1.1), c + Vector2(-h * 0.5, -h * 0.3),
		c + Vector2(h * 0.5, -h * 0.3), c + Vector2(h * 0.8, h * 1.1)]), UIKit.LIGHT)
	var font := UIKit.font_body()
	var fs := UIKit.body_px(18)
	var you := "You"
	var ys := font.get_string_size(you, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	ring_area.draw_string(font, c + Vector2(-ys.x / 2.0, h * 2.6), you, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIKit.DIM)
	var word := "▲  Your %s side faces the foe  ▲" % Ring.side_element(GameState.ring_side).capitalize()
	var ws := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.body_px(20))
	ring_area.draw_string(font, Vector2((ring_area.size.x - ws.x) / 2.0, 22.0), word, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.body_px(20), UIKit.GOLD)


func _process(delta: float) -> void:
	_time += delta
	for c in cells:
		(c as Control).queue_redraw()


## The beast in a cell, or null.
func beast_in(dest: Dictionary):
	if dest.has("slot"):
		return GameState.beast_at(int(dest["slot"]))
	var j: int = dest["store"]
	return GameState.storage[j] if j < GameState.storage.size() else null


## A cell the picked-up beast may go to (always false with nothing picked up).
func can_go(dest: Dictionary) -> bool:
	return picked != null and beast_in(dest) != picked and GameState.ring_move_reason(picked, dest) == ""


## A cell was tapped (or chosen with A): pick its beast up, or put the one picked up there.
func use_cell(c) -> void:
	var b = beast_in(c.dest)
	if picked == null:
		if b == null:
			Sfx.play("error")
			hint.text = "Nobody's here. Pick a beast first."
			return
		picked = b
		Sfx.play("confirm")
		_refresh(c)
		return
	if b == picked:
		_put_down()
		return
	var why := GameState.ring_move_reason(picked, c.dest)
	if why != "":
		Sfx.play("error")
		hint.text = why
		return
	var moved = picked
	GameState.ring_move(moved, c.dest)
	picked = null
	Sfx.play("pickup")
	var keep := cells.find(c)
	_fill_storage()
	_refresh()
	(cells[clampi(keep, 0, cells.size() - 1)] as Control).grab_focus()
	hint.text = _where(moved) + ("" if b == null else " " + _where(b))


## "Embit stands on the Fire side.", "Embit is in storage."
func _where(b) -> String:
	if GameState.party.has(b):
		return "%s stands on the %s." % [b.nickname, Ring.slot_name(b.slot)]
	return "%s is in storage." % b.nickname


func _put_down() -> void:
	picked = null
	Sfx.play("back")
	_refresh()


## The count, the hint and the details of the focused (or picked-up) beast.
func _refresh(focused = null) -> void:
	count_label.text = "Ring %d / %d   ·   Storage %d" % [GameState.party.size(), GameState.party_max(), GameState.storage.size()]
	if picked != null:
		hint.text = "Where should %s go? The lit cells can take it. %s" % [picked.nickname, "Tap it again to put it back." if UI.is_touch() else "B puts it back."]
	else:
		hint.text = "%s a beast to move it round your ring, or in and out of storage." % ("Tap" if UI.is_touch() else "Choose")
	show_info(focused if focused != null else get_viewport().gui_get_focus_owner())


## The details of a cell's beast (or, for an empty cell, what it takes).
func show_info(c) -> void:
	for ch in info_box.get_children():
		info_box.remove_child(ch)
		ch.queue_free()
	if c == null or not c is Cell:
		return
	var b = beast_in(c.dest)
	if b == null:
		if c.dest.has("slot"):
			var k: int = c.dest["slot"]
			var els: Array = Ring.slot_elements(k).map(func(e): return String(e).capitalize())
			info_box.add_child(UIKit.header(Ring.slot_name(k), UIKit.INK, UIKit.HEAD_SMALL))
			info_box.add_child(UIKit.label("Empty. Takes a %s beast." % els[0] if els.size() == 1 else "Empty. Takes a %s or %s beast, or a %s / %s one." % [els[0], els[1], els[0], els[1]], 18, UIKit.DIM))
		else:
			info_box.add_child(UIKit.header("Storage", UIKit.INK, UIKit.HEAD_SMALL))
			info_box.add_child(UIKit.label("An empty cell: put a beast here to store it.", 18, UIKit.DIM))
		return
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	name_row.add_child(UIKit.header(b.nickname, UIKit.INK, UIKit.HEAD_SMALL))
	for el in b.elements():
		name_row.add_child(UIKit.element_tag(el))
	info_box.add_child(name_row)
	var place := "on the %s" % Ring.slot_name(b.slot) if GameState.party.has(b) else "in storage"
	info_box.add_child(UIKit.label("Lv %d   HP %d / %d   %s" % [b.level, maxi(0, b.hp), b.max_hp(), place], 18, UIKit.DIM))


func on_input(ev: InputEvent) -> void:
	if not ev.is_pressed() or ev.is_echo():
		return
	if ev.is_action_pressed("menu"):
		_close()
	elif ev.is_action_pressed("ui_cancel"):
		if picked != null:
			_put_down()
		else:
			_close()
	elif get_viewport().gui_get_focus_owner() == null and (ev.is_action_pressed("ui_up") or ev.is_action_pressed("ui_down")
			or ev.is_action_pressed("ui_left") or ev.is_action_pressed("ui_right")):
		(cells[0] as Control).grab_focus()


func _close() -> void:
	Sfx.play("back")
	close()


## One cell: a beast's icon on a tile (a ring slot: brighter on the side facing the foe, rounder for a corner), with its
## slot's elements or the beast's level under it. While a beast is picked up, the cells it may go to pulse in the
## gem and the rest darken; the beast picked up wears a gold frame.
class Cell extends Button:
	const UIKit = preload("res://scripts/ui/ui_kit.gd")
	const Ring = preload("res://scripts/core/ring.gd")
	const PixelArt = preload("res://scripts/gfx/pixel_art.gd")
	var editor
	var dest: Dictionary

	func _init(_editor, _dest: Dictionary) -> void:
		editor = _editor
		dest = _dest
		focus_mode = Control.FOCUS_ALL
		flat = true
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		pressed.connect(func(): editor.use_cell(self))
		focus_entered.connect(func(): editor.show_info(self))
		mouse_entered.connect(func(): if not UI.is_touch(): grab_focus())

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var b = editor.beast_in(dest)
		var slot: int = int(dest.get("slot", -1))
		var facing := slot >= 0 and slot in Ring.side_slots(GameState.ring_side)
		var lifted: bool = editor.picked != null and editor.picked == b
		var can: bool = editor.can_go(dest)
		var pulse := 0.5 + 0.5 * sin(editor._time * TAU / 0.9)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(UIKit.ACCENT.darkened(0.35), 0.95) if facing else Color(UIKit.WINDOW_TOP, 0.95)
		sb.set_corner_radius_all(int(size.x * (0.45 if slot >= 0 and Ring.is_corner(slot) else 0.18)))
		sb.anti_aliasing = true
		sb.border_color = Color(UIKit.BORDER, 0.45)
		sb.set_border_width_all(2)
		if can:
			sb.border_color = UIKit.ACCENT.lightened(0.3).lerp(UIKit.LIGHT, pulse)
			sb.set_border_width_all(5)
			sb.shadow_color = Color(UIKit.ACCENT.lightened(0.2), 0.35 + 0.35 * pulse)
			sb.shadow_size = int(6 + 6 * pulse)
		if lifted:
			sb.border_color = UIKit.GOLD_BRIGHT
			sb.set_border_width_all(5)
		if has_focus():
			sb.border_color = UIKit.LIGHT if not can and not lifted else sb.border_color
			sb.set_border_width_all(maxi(sb.border_width_top, 4))
		draw_style_box(sb, r)
		var font := UIKit.font_body()
		var fs := UIKit.body_px(17)
		var under := ""
		if b != null:
			var ir := Rect2(r.position + Vector2(size.x * 0.16, size.y * 0.06), Vector2(size.x * 0.68, size.y * 0.68))
			if lifted:
				ir.position.y -= size.y * 0.06 * (0.5 + 0.5 * sin(editor._time * 6.0))
			var down: bool = b.hp <= 0
			draw_texture_rect(PixelArt.beast_texture(b.genes), ir, false, Color(0.4, 0.38, 0.42, 0.8) if down else Color.WHITE)
			if down:
				var c := ir.get_center()
				var s := ir.size.x * 0.3
				for d in [Vector2(s, s), Vector2(s, -s)]:
					draw_line(c - d, c + d, Color(0, 0, 0, 0.7), 6.0, true)
					draw_line(c - d, c + d, UIKit.ACCENT.lightened(0.2), 3.0, true)
			under = "Lv %d" % b.level
		elif slot >= 0:
			under = "/".join(Ring.slot_elements(slot).map(func(e): return String(e).capitalize()))
			# (a corner's round edge leaves less room at the foot)
			var room := size.x * (0.66 if Ring.is_corner(slot) else 0.9)
			while fs > 8 and font.get_string_size(under, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
				fs -= 1
		else:
			var plus := "+"
			var ps := font.get_string_size(plus, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.body_px(30))
			draw_string(font, r.get_center() + Vector2(-ps.x / 2.0, ps.y * 0.3), plus, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.body_px(30), Color(UIKit.DIM, 0.6))
		if under != "":
			var us := font.get_string_size(under, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			draw_string(font, Vector2((size.x - us.x) / 2.0, size.y - 6.0), under, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIKit.GOLD if facing else UIKit.DIM)
		if editor.picked != null and not can and not lifted:
			# somewhere it can't go
			var dark := sb.duplicate() as StyleBoxFlat
			dark.bg_color = Color(0, 0, 0, 0.55)
			dark.set_border_width_all(0)
			dark.shadow_size = 0
			draw_style_box(dark, r)
