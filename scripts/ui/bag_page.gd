extends Node
## The Start book's Bag tab (book_menu.gd): a grid of item slots on the left page, one per stack with its count when
## there's more than one, and the focused item's name and details on the right page.
## Choosing an item (A, a click or a tap) turns the right page into its actions: Use, Equip (gear only), Drop and Back.
## Use on a beast, or Equip, turns the left page into your battle ring (you in the middle) to choose who it's for;
## only those it would do something for can be chosen. The right page then shows their stats before and after, with
## Confirm and Cancel under them. Drop asks first. The rules are scripts/core/item_use.gd's.
## B steps back a page at a time (target → actions → grid → the book's tabs).

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const ItemDB = preload("res://scripts/data/item_db.gd")
const ItemUse = preload("res://scripts/core/item_use.gd")
const Ring = preload("res://scripts/core/ring.gd")
const PixelArt = preload("res://scripts/gfx/pixel_art.gd")
const BeatChain = preload("res://scripts/core/beat_chain.gd")
const ScrollRail = preload("res://scripts/ui/scroll_rail.gd")
const VoxelPortrait = preload("res://scripts/ui/voxel_portrait.gd")
const Bar = preload("res://scripts/ui/bar.gd")

## the item groups, in the grid's order (each a caption and a test of its item data)
const GROUPS := [
	["Care", "_is_care"], ["Battle item", "_is_battle"], ["Weapon", "_is_weapon"], ["Beast gear", "_is_gear"],
	["Trainer gear", "_is_tgear"], ["Sheet music", "_is_sheet"], ["Fishing", "_is_bait"], ["Key item", "_is_key"],
	["Tome", "_is_tome"]]
## the grid fills out at least this many rows with empty slots, so a nearly empty bag still reads as a bag
const MIN_ROWS := 3
const GAP := 8.0

var book
## "grid", "actions" or "target"
var mode := "grid"
## [{id, count, group}], one per stack, in the grid's order
var stacks: Array = []
var cells: Array = []
var grid: GridContainer
var grid_scroll: ScrollContainer
var columns := 5
## the stack whose actions (or target) are open
var picked := -1
var focus_cell := 0
## "use" or "equip" while choosing a target
var action := ""
var ring_view: Control
var targets: Array = []
## the chosen target: a beast, "trainer", or null
var target = null
var preview_box: VBoxContainer
var confirm_button: Button
var cancel_button: Button
var action_buttons: Array = []
var _built_once := false


func setup(_book) -> Node:
	book = _book
	return self


# ================================================================ the grid
func build(keep_cell := -1) -> void:
	mode = "grid"
	picked = -1
	action = ""
	target = null
	_clear(book.left_box)
	_clear(book.right_box)
	book.left_box.add_child(book._pane_title("Bag  %d/24  ·  %d gold" % [GameState.stacks_used(GameState.inventory), GameState.gold]))
	_gather()
	var side := HBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book.left_box.add_child(side)
	grid_scroll = ScrollContainer.new()
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_scroll.follow_focus = true
	side.add_child(grid_scroll)
	grid = GridContainer.new()
	grid.add_theme_constant_override("h_separation", int(GAP))
	grid.add_theme_constant_override("v_separation", int(GAP))
	grid_scroll.add_child(grid)
	side.add_child(ScrollRail.new().setup(grid_scroll))
	cells = []
	for i in stacks.size():
		var c := ItemCell.new(self, i)
		grid.add_child(c)
		cells.append(c)
	columns = _columns()
	_pad_grid()
	_link_cells()
	grid_scroll.resized.connect(_on_grid_resized)
	if stacks.is_empty():
		book.right_box.add_child(book._t_label("Your bag is empty. Shops and hidden sacks will fill it up!", UIKit.DIM))
		focus_cell = 0
	else:
		focus_cell = clampi(keep_cell if keep_cell >= 0 else focus_cell, 0, stacks.size() - 1)
		_show_info(focus_cell)


## Every stack in the bag, grouped, by name within a group; a kind with more than nine fills several stacks.
func _gather() -> void:
	stacks = []
	var ids := GameState.inventory.keys()
	ids.sort_custom(func(a, b): return ItemDB.item_name(a) < ItemDB.item_name(b))
	for g in GROUPS:
		for id in ids:
			var it := ItemDB.get_item(id)
			if it.is_empty() or not call(g[1], it):
				continue
			var remaining: int = GameState.item_count(id)
			while remaining > 0:
				var amount := remaining if GameState.bag_exempt(id) else mini(remaining, GameState.ITEM_STACK_SIZE)
				stacks.append({"id": id, "count": amount, "group": g[0]})
				remaining -= amount


func _is_care(it: Dictionary) -> bool:
	return it["kind"] == "use" and not it.get("battle_only", false)


func _is_battle(it: Dictionary) -> bool:
	return it["kind"] == "use" and it.get("battle_only", false)


func _is_weapon(it: Dictionary) -> bool:
	return it.has("weapon")


func _is_gear(it: Dictionary) -> bool:
	return it["kind"] == "gear"


func _is_tgear(it: Dictionary) -> bool:
	return it["kind"] == "tgear"


func _is_sheet(it: Dictionary) -> bool:
	return it["kind"] == "sheet"


func _is_bait(it: Dictionary) -> bool:
	return it["kind"] == "bait"


func _is_key(it: Dictionary) -> bool:
	return it["kind"] == "key" and not it.has("weapon")


func _is_tome(it: Dictionary) -> bool:
	return it["kind"] == "tome"


## A slot's side: big enough to tap on a phone, with room for the icon and its count.
static func cell_size() -> float:
	return maxf(96.0, UIKit.row_h() + 16.0)


func _columns() -> int:
	var w: float = grid_scroll.size.x if grid_scroll.size.x > 0 else book.left_box.size.x - ScrollRail.width() - 6.0
	return maxi(3, int(floor((w + GAP) / (cell_size() + GAP))))


func _on_grid_resized() -> void:
	var n := _columns()
	if n != columns and mode == "grid":
		columns = n
		_pad_grid()
		_link_cells()


## Empty slots finish the last row (and fill out the first few), so the grid keeps its shape.
func _pad_grid() -> void:
	grid.columns = columns
	for c in grid.get_children():
		if c is EmptyCell:
			grid.remove_child(c)
			c.queue_free()
	var total := maxi(MIN_ROWS * columns, int(ceil(float(stacks.size()) / columns)) * columns)
	for i in total - stacks.size():
		grid.add_child(EmptyCell.new(cell_size()))


## The d-pad moves round the grid and stops at its edges (B goes back to the tabs).
func _link_cells() -> void:
	for i in cells.size():
		var c: Control = cells[i]
		var col := i % columns
		c.focus_neighbor_left = c.get_path_to(cells[i - 1]) if col > 0 else NodePath(".")
		c.focus_neighbor_right = c.get_path_to(cells[i + 1]) if col < columns - 1 and i + 1 < cells.size() else NodePath(".")
		c.focus_neighbor_top = c.get_path_to(cells[i - columns]) if i - columns >= 0 else NodePath(".")
		var below := mini(i + columns, cells.size() - 1)
		c.focus_neighbor_bottom = c.get_path_to(cells[below]) if below > i and int(below / columns) > int(i / columns) else NodePath(".")
		if i < columns and not c.gui_input.is_connected(_top_cell_input.bind(c)):
			c.gui_input.connect(_top_cell_input.bind(c))
		c.focus_next = c.get_path_to(cells[(i + 1) % cells.size()])
		c.focus_previous = c.get_path_to(cells[posmod(i - 1, cells.size())])


## Up on the top row of slots goes back to the book's tabs.
func _top_cell_input(ev: InputEvent, c: Control) -> void:
	var at := cells.find(c)
	if mode == "grid" and at >= 0 and at < columns and ev.is_action_pressed("ui_up") and book.to_tabs():
		c.accept_event()


## The book hands the cursor to the bag.
func focus() -> void:
	match mode:
		"grid":
			if cells.is_empty():
				book.mode = "tabs"
				return
			book.mode = "list"
			(cells[clampi(focus_cell, 0, cells.size() - 1)] as Control).grab_focus()
		"actions":
			book.mode = "list"
			if not action_buttons.is_empty():
				(action_buttons[0] as Control).grab_focus()
		"target":
			book.mode = "list"
			_focus_target()


func cell_focused(i: int) -> void:
	if mode != "grid":
		return
	if i != focus_cell:
		Sfx.play("select")
	focus_cell = i
	book.focus_row = i
	book.mode = "list"
	_show_info(i)
	_keep_clear_of_pad.call_deferred(i)


## On a phone, a focused slot low on the page scrolls up clear of the touch pad.
func _keep_clear_of_pad(i: int) -> void:
	if not is_inside_tree() or not UI.is_touch() or i != focus_cell or i >= cells.size() or not is_instance_valid(grid_scroll):
		return
	var rect: Rect2 = (cells[i] as Control).get_global_rect()
	var reserve: float = UI.controls.menu_bottom_reserve(rect.position.x, rect.end.x)
	var bottom := minf(grid_scroll.get_global_rect().end.y, book.get_viewport_rect().size.y - reserve)
	if rect.end.y > bottom:
		grid_scroll.scroll_vertical += ceili(rect.end.y - bottom)


## The right page while browsing: the item's name, kind, count and description.
func _show_info(i: int) -> void:
	_clear(book.right_box)
	book.right_scroll.scroll_vertical = 0
	var s: Dictionary = stacks[i]
	var id: String = s["id"]
	var it := ItemDB.get_item(id)
	book.right_box.add_child(_item_heading(id, s))
	book.right_box.add_child(book._t_label(it.get("desc", "")))
	var note := _item_note(id)
	if note != "":
		book.right_box.add_child(book._spacer())
		book.right_box.add_child(book._t_label(note, UIKit.DIM))
	book.right_box.add_child(book._spacer())
	book.right_box.add_child(book._t_label("%s for options." % book._press(), UIKit.ACCENT))


## The item's icon beside its name, with its kind and how many you have under it.
func _item_heading(id: String, s: Dictionary) -> Control:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(80, 80)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.add_theme_stylebox_override("panel", UIKit.slot_box())
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.texture = UI.Glyphs.item(id)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if UI.Glyphs.smooth(icon.texture) else CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(12, 12)
	icon.size = Vector2(56, 56)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)
	top.add_child(slot)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var nm: Label = book._h(ItemDB.item_name(id))
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size.x = 120
	col.add_child(nm)
	var have := GameState.item_count(id)
	col.add_child(book._w("%s  ·  You have %d" % [s.get("group", ""), have] if not GameState.bag_exempt(id) or have > 1 else String(s.get("group", "")), UIKit.DIM))
	top.add_child(col)
	return top


## Where the item stands (worn, on your hook) or when it's used, if that isn't plain.
func _item_note(id: String) -> String:
	var it := ItemDB.get_item(id)
	if it.has("weapon"):
		var most := BeatChain.max_hits(GameState.trainer_level)
		return "Pick it on your own turn in battle. " + ("Press A on the beat: up to %d hits." % most if most > 0 and GameState.flag("dance_lesson_done")
			else "Learn rhythm attacks at Dustwell Oasis's dance studio from trainer Lv %d." % BeatChain.UNLOCK_LEVEL)
	match it.get("kind", ""):
		"use":
			if it.get("battle_only", false):
				return "Use it on your own turn in battle."
		"bait":
			return "It's on your hook." if GameState.bait == id else ""
		"tome":
			return "Tomes are read at a bookstore, where the librarian helps your beast learn the move."
		"tgear":
			var on: String = GameState.gear.get(String(it.get("slot", "")), "")
			return "You're wearing %s there now." % ItemDB.item_name(on) if on != "" else ""
		"key":
			if id == "fishing_rod":
				return "Bait on your hook: %s." % (ItemDB.item_name(GameState.bait) if GameState.bait != "" else "none")
	return ""


# ================================================================ actions
## A slot was chosen: the right page becomes its actions.
func open_actions(i: int, focus_action := "") -> void:
	if i < 0 or i >= stacks.size():
		return
	Sfx.play("confirm")
	picked = i
	focus_cell = i
	mode = "actions"
	_refresh_cells()
	var s: Dictionary = stacks[i]
	var id: String = s["id"]
	_clear(book.right_box)
	book.right_scroll.scroll_vertical = 0
	book.right_box.add_child(_item_heading(id, s))
	book.right_box.add_child(book._spacer(4))
	action_buttons = []
	var list := []
	if ItemUse.has_use(id):
		var label := "Use"
		if ItemDB.get_item(id).get("kind", "") == "bait" and GameState.bait == id:
			label = "Take off hook"
		list.append([label, "use", ItemUse.use_block(id, GameState.party)])
	if ItemUse.has_equip(id):
		list.append(["Equip", "equip", ItemUse.equip_block(id, GameState.party)])
	if ItemUse.can_drop(id):
		list.append(["Drop", "drop", ""])
	list.append(["Back", "back", ""])
	for a in list:
		var b := _action_button(a[0], a[2])
		b.pressed.connect(_on_action.bind(a[1], a[2]))
		b.set_meta("action", a[1])
		book.right_box.add_child(b)
		action_buttons.append(b)
	for k in action_buttons.size():
		var b: Button = action_buttons[k]
		b.focus_neighbor_left = NodePath(".")
		b.focus_neighbor_right = NodePath(".")
		b.focus_neighbor_top = b.get_path_to(action_buttons[k - 1]) if k > 0 else NodePath(".")
		b.focus_neighbor_bottom = b.get_path_to(action_buttons[k + 1]) if k + 1 < action_buttons.size() else NodePath(".")
	var first: Button = action_buttons[0]
	for b in action_buttons:
		if b.get_meta("action") == focus_action:
			first = b
	first.grab_focus()


## An action row: the menu row style, a dim one with its reason on the right when it can't be chosen.
func _action_button(text: String, blocked: String) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, UIKit.row_h())
	b.mouse_entered.connect(func(): if not UI.is_touch() and is_instance_valid(b): b.grab_focus())
	b.focus_entered.connect(func(): Sfx.play("select"))
	if blocked != "":
		for c in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(c, Color(UIKit.DIM, 0.7))
		var rl := UIKit.label(blocked, 20, UIKit.DIM)
		UIKit.follow_row(b, rl, UIKit.DIM)
		rl.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
		var w := UIKit.font_bold().get_string_size(rl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, rl.get_theme_font_size("font_size")).x + 16.0
		rl.offset_left = -w - 8.0
		rl.offset_right = -12
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(rl)
		var held := UIKit.highlight(w)
		for st in ["pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(st, held)
	return b


func _on_action(what: String, blocked: String) -> void:
	if mode != "actions" or picked < 0:
		return
	if blocked != "":
		Sfx.play("error")
		UI.toast(_blocked_line(what, blocked), "notice")
		return
	var id: String = stacks[picked]["id"]
	match what:
		"back":
			back_to_grid()
		"drop":
			await _drop(id)
		"use":
			if ItemUse.needs_target(id):
				Sfx.play("confirm")
				open_targets("use")
			else:
				Sfx.play("confirm")
				var keep := picked
				book._changing_row = true
				await Menus.use_bag_item(id)
				book._changing_row = false
				_after_change(keep, "use")
		"equip":
			Sfx.play("confirm")
			open_targets("equip")


## Why an action can't be used, as a full sentence for the top bar.
func _blocked_line(what: String, blocked: String) -> String:
	match blocked:
		"In battle":
			return "That can only be used in battle."
		"No effect":
			return "None of your beasts needs that right now."
		"Bookstore":
			return "Tomes are read at a bookstore."
		"Needs a pole":
			return "You'll need a fishing pole to use bait."
		"No beasts":
			return "You don't have any beasts to give it to."
		"No one":
			return "All of your beasts already wear it."
	return blocked if what != "equip" else "You're already wearing it."


## Drop asks first; on yes, one of the item is thrown away.
func _drop(id: String) -> void:
	var keep := picked
	var nm := ItemDB.item_name(id)
	book._changing_row = true
	var yes: bool = await UI.ask("Drop one %s? It'll be gone for good." % nm)
	book._changing_row = false
	if book.closed:
		return
	if yes:
		GameState.remove_item(id)
		if GameState.bait == id and GameState.item_count(id) <= 0:
			GameState.bait = ""
		Sfx.play("back")
		UI.toast("You dropped the %s." % nm, "item:" + id)
		_after_change(keep, "drop")
	else:
		open_actions(keep, "drop")


## After an item was used, worn or dropped: back to its actions while any of it is left, else to the grid.
func _after_change(keep: int, focus_action: String) -> void:
	if book.closed:
		return
	var id: String = stacks[keep]["id"] if keep < stacks.size() else ""
	build(keep)
	var at := -1
	for i in stacks.size():
		if stacks[i]["id"] == id:
			at = i
			if i >= keep:
				break
	if at >= 0:
		open_actions(at, focus_action)
	else:
		focus_cell = mini(keep, stacks.size() - 1)
		focus()


func back_to_grid() -> void:
	Sfx.play("back")
	var keep := picked if picked >= 0 else focus_cell
	build(keep)
	focus()


# ================================================================ choosing who
## The left page becomes your ring (you in the middle); only those the item would do something for can be chosen.
func open_targets(what: String) -> void:
	action = what
	mode = "target"
	var id: String = stacks[picked]["id"]
	var nm := ItemDB.item_name(id)
	_clear(book.left_box)
	book.left_box.add_child(book._pane_title(("Use %s on..." if what == "use" else "Equip %s on...") % nm))
	ring_view = RingTargets.new(self)
	ring_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ring_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	book.left_box.add_child(ring_view)
	targets = ring_view.cells
	_clear(book.right_box)
	book.right_scroll.scroll_vertical = 0
	book.right_box.add_child(_item_heading(id, stacks[picked]))
	preview_box = VBoxContainer.new()
	preview_box.add_theme_constant_override("separation", 4)
	book.right_box.add_child(preview_box)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	book.right_box.add_child(buttons)
	confirm_button = _framed_button("Confirm")
	confirm_button.pressed.connect(_confirm)
	buttons.add_child(confirm_button)
	cancel_button = _framed_button("Cancel")
	cancel_button.pressed.connect(_cancel_target)
	buttons.add_child(cancel_button)
	for b in [confirm_button, cancel_button]:
		b.focus_neighbor_top = NodePath(".")
		b.focus_neighbor_bottom = NodePath(".")
		b.focus_entered.connect(func(): if is_instance_valid(b): book.right_scroll.ensure_control_visible(b))
	confirm_button.focus_neighbor_right = confirm_button.get_path_to(cancel_button)
	cancel_button.focus_neighbor_left = cancel_button.get_path_to(confirm_button)
	cancel_button.focus_neighbor_right = NodePath(".")
	target = null
	for c in targets:
		if c.allowed:
			target = c.who
			break
	_show_preview()
	_focus_target.call_deferred()


## The same target: a beast, or "trainer" for you (they can't be compared with ==).
static func same(a, b) -> bool:
	return typeof(a) == typeof(b) and a == b


func _framed_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(180, UIKit.row_h())
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIKit.plate_button(b)
	b.mouse_entered.connect(func(): if not UI.is_touch() and is_instance_valid(b): b.grab_focus())
	return b


func _focus_target() -> void:
	if mode != "target" or not is_instance_valid(ring_view):
		return
	for c in targets:
		if same(c.who, target) and c.allowed:
			c.grab_focus()
			return
	cancel_button.grab_focus()


## A ring cell got the cursor: it's the one the preview shows.
func target_focused(c) -> void:
	if mode != "target" or not c.allowed:
		return
	if not same(c.who, target):
		Sfx.play("select")
	target = c.who
	_show_preview()
	if is_instance_valid(confirm_button):
		confirm_button.focus_neighbor_left = confirm_button.get_path_to(c)
	ring_view.queue_redraw_cells()


## A ring cell was chosen (A, click or tap): it's picked, and the cursor goes to Confirm.
func target_chosen(c) -> void:
	if mode != "target":
		return
	if not c.allowed:
		Sfx.play("error")
		UI.toast(c.why, "notice")
		return
	target_focused(c)
	Sfx.play("confirm")
	confirm_button.grab_focus()


## Before and after for the chosen target.
func _show_preview() -> void:
	_clear(preview_box)
	var id: String = stacks[picked]["id"]
	if target == null:
		preview_box.add_child(book._t_label("Nobody here can use it.", UIKit.DIM))
		confirm_button.disabled = true
		return
	confirm_button.disabled = false
	var rows: Array
	if action == "use":
		rows = ItemUse.use_preview(id, target)
	elif typeof(target) == TYPE_STRING:
		rows = ItemUse.trainer_preview(id)
	else:
		rows = ItemUse.gear_preview(id, target)
	var who_name: String = GameState.player_name if typeof(target) == TYPE_STRING else target.nickname
	var level: int = GameState.trainer_level if typeof(target) == TYPE_STRING else target.level
	preview_box.add_child(book._row_of([book._sub(who_name.to_upper()), book._w("Lv %d" % level, UIKit.DIM)], 12))
	if typeof(target) != TYPE_STRING:
		# HP and MP are on the bars (before ► after); the rows below are what's left
		var bar_rows := {}
		for r in rows:
			if r["name"] in ["HP", "MP"]:
				bar_rows[r["name"]] = r
		rows = rows.filter(func(r): return not r["name"] in ["HP", "MP"])
		_add_vitals(target, bar_rows)
	# the item's own rows full width; the four battle stats two to a line
	var stat_names := ["Attack", "Defense", "Spirit", "Speed"]
	var wide := GridContainer.new()
	wide.columns = 4
	wide.add_theme_constant_override("h_separation", 12)
	wide.add_theme_constant_override("v_separation", 0)
	var stats := GridContainer.new()
	stats.columns = 8
	stats.add_theme_constant_override("h_separation", 10)
	stats.add_theme_constant_override("v_separation", 0)
	for r in rows:
		var on: GridContainer = stats if r["name"] in stat_names else wide
		var changed: bool = r["before"] != r["after"]
		on.add_child(_cell_label(r["name"], UIKit.DIM, true))
		on.add_child(_cell_label(r["before"], UIKit.DIM if changed else UIKit.INK))
		on.add_child(_cell_label("►" if changed else "", UIKit.ACCENT))
		var after := _cell_label(r["after"], UIKit.GOLD if changed else UIKit.INK, false, changed)
		if on == stats:
			after.custom_minimum_size.x = 56
		on.add_child(after)
	if wide.get_child_count() > 0:
		preview_box.add_child(wide)
	if stats.get_child_count() > 0:
		preview_box.add_child(stats)


## A beast's HP and MP bars side by side (with what the item makes them, when it changes them), and its condition
## (fainted or a status) tagged beside them and explained under them.
func _add_vitals(b, change := {}) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	var hp := Bar.new(Vector2(150, 30))
	hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp.set_ratio(b.hp_ratio(), true)
	hp.text = _bar_text("HP", change.get("HP", {}), "%d/%d" % [maxi(0, b.hp), b.max_hp()])
	var mpb := Bar.new(Vector2(150, 30))
	mpb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mpb.fixed_color = UIKit.GOLD_BRIGHT
	mpb.set_ratio(b.mp_ratio(), true)
	mpb.text = _bar_text("MP", change.get("MP", {}), "%d/%d" % [b.mp, b.max_mp()])
	line.add_child(hp)
	line.add_child(mpb)
	var cond: Array = ItemUse.condition(b)
	if cond[0] != "":
		var tag := UIKit.tag(cond[0], Color(0.78, 0.16, 0.16) if cond[0] == "KO" else Color(0.45, 0.2, 0.6), 20)
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(tag)
	preview_box.add_child(line)
	if cond[0] != "":
		preview_box.add_child(book._t_label(cond[1], UIKit.DIM))


func _bar_text(name: String, row: Dictionary, now: String) -> String:
	if row.is_empty() or row["before"] == row["after"]:
		return "%s %s" % [name, now]
	return "%s %s ► %s" % [name, String(row["before"]).replace(" ", ""), String(row["after"]).replace(" ", "")]


func _cell_label(text: String, color: Color, caption := false, strong := false) -> Label:
	var l := UIKit.label(text, 20 if caption else 24, color)
	if strong:
		l.add_theme_font_override("font", UIKit.font_head())
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size.y = 34
	return l


func _confirm() -> void:
	if mode != "target" or target == null:
		return
	var id: String = stacks[picked]["id"]
	var keep := picked
	var who = target
	Sfx.play("confirm")
	book._changing_row = true
	if action == "use":
		mode = "busy"
		await Menus.apply_field_item(id, who)
	elif typeof(who) == TYPE_STRING:
		ItemUse.put_trainer_gear_on(id)
		UI.toast("Equipped %s." % ItemDB.item_name(id), "item:" + id)
	else:
		ItemUse.put_gear_on(id, who)
		UI.toast("%s equipped %s." % [who.nickname, ItemDB.item_name(id)], "item:" + id)
	book._changing_row = false
	_after_change(keep, action)


func _cancel_target() -> void:
	if mode != "target":
		return
	Sfx.play("back")
	var keep := picked
	var what := action
	build(keep)
	open_actions(keep, what)


# ================================================================ input
## Input the book passes on first; true when the bag used it.
func on_input(ev: InputEvent) -> bool:
	var arrow := ev.is_action("ui_left") or ev.is_action("ui_right") or ev.is_action("ui_up") or ev.is_action("ui_down")
	match mode:
		"grid":
			# the grid keeps the d-pad (its edges stop it); B goes to the tabs as on every page
			if arrow and book.mode == "list" and not cells.is_empty():
				if book.get_viewport().gui_get_focus_owner() == null:
					focus()
				return true
			return false
		"actions":
			if ev.is_action_pressed("ui_cancel"):
				back_to_grid()
				return true
			return arrow
		"target":
			if ev.is_action_pressed("ui_cancel"):
				var f: Control = book.get_viewport().gui_get_focus_owner()
				if f == confirm_button or f == cancel_button:
					Sfx.play("back")
					_focus_target()
				else:
					_cancel_target()
				return true
			return arrow
		"busy":
			return true
	return false


func _refresh_cells() -> void:
	for c in cells:
		(c as Control).queue_redraw()


func _clear(c: Control) -> void:
	for ch in c.get_children():
		c.remove_child(ch)
		ch.queue_free()


# ================================================================ cells
## One stack: its icon on a square slot, its count at the corner when there's more than one. Focused: a white frame;
## the stack whose actions are open is filled with the gem.
class ItemCell extends Button:
	const UIKit = preload("res://scripts/ui/ui_kit.gd")
	var page
	var index := 0
	var icon_tex: Texture2D
	var smooth := true

	func _init(_page, i: int) -> void:
		page = _page
		index = i
		focus_mode = Control.FOCUS_ALL
		flat = true
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		var s: Dictionary = page.stacks[i]
		icon_tex = UI.Glyphs.item(s["id"])
		smooth = UI.Glyphs.smooth(icon_tex)
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if smooth else CanvasItem.TEXTURE_FILTER_NEAREST
		var side: float = page.cell_size()
		custom_minimum_size = Vector2(side, side)
		tooltip_text = ""
		pressed.connect(func(): if page.mode in ["grid", "actions"]: page.open_actions(index))
		focus_entered.connect(func(): page.cell_focused(index); queue_redraw())
		focus_exited.connect(queue_redraw)
		mouse_entered.connect(func(): if page.mode == "grid" and not UI.is_touch(): grab_focus())

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var open: bool = page.picked == index
		draw_style_box(UIKit.slot_box(open), r)
		if has_focus() or open:
			draw_style_box(UIKit.highlight(), r.grow(4.0))
		var s: Dictionary = page.stacks[index]
		var isz := size.x * 0.58
		draw_texture_rect(icon_tex, Rect2((size.x - isz) / 2.0, size.y * 0.12, isz, isz), false)
		var n: int = s["count"]
		if n > 1:
			var font := UIKit.font_bold()
			var fs := UIKit.body_px(20)
			var t := "x%d" % n
			var ts := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			var at := Vector2(size.x - ts.x - 10.0, size.y - 10.0)
			draw_string_outline(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 0.85))
			draw_string(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIKit.LIGHT)


## A slot with nothing in it: dim, and never takes the cursor.
class EmptyCell extends Control:
	const UIKit = preload("res://scripts/ui/ui_kit.gd")

	func _init(side: float) -> void:
		custom_minimum_size = Vector2(side, side)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		modulate = Color(1, 1, 1, 0.4)

	func _draw() -> void:
		draw_style_box(UIKit.slot_box(), Rect2(Vector2.ZERO, size))


## Your ring for choosing who an item is for: the eight slots round you, the side facing the foe at the top (as on
## the Beasts page). Cells the item can't go to are dimmed and skipped by the cursor.
class RingTargets extends Control:
	const UIKit = preload("res://scripts/ui/ui_kit.gd")
	const Ring = preload("res://scripts/core/ring.gd")
	const ItemUse = preload("res://scripts/core/item_use.gd")
	const VoxelPortrait = preload("res://scripts/ui/voxel_portrait.gd")
	var page
	var cells: Array = []
	var you: TargetCell

	func _init(_page) -> void:
		page = _page
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var id: String = page.stacks[page.picked]["id"]
		for k in Ring.SLOTS:
			var b = GameState.beast_at(k)
			var c := TargetCell.new(page, b, k)
			if b == null:
				c.why = "Nobody stands there."
			elif page.action == "use":
				c.why = ItemUse.beast_block(id, b)
			else:
				c.why = ItemUse.gear_block(id, b)
			c.allowed = b != null and c.why == ""
			c.disabled = not c.allowed
			add_child(c)
			cells.append(c)
		you = TargetCell.new(page, "trainer", -1)
		you.why = ItemUse.trainer_block(id) if page.action == "equip" else "It's for your beasts."
		you.allowed = you.why == ""
		you.disabled = not you.allowed
		add_child(you)
		cells.append(you)
		for c in cells:
			c.focus_mode = Control.FOCUS_ALL if c.allowed else Control.FOCUS_NONE
		var face := VoxelPortrait.new().setup_person(GameState.hero_look(), 96)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		you.add_child(face)
		you.portrait = face
		resized.connect(_place)

	## [centre, radius, cell size], the ring sized to the page.
	func _geometry() -> Array:
		var s := minf(size.x, size.y)
		var cell := clampf(s * 0.24, 80.0, 132.0)
		return [size / 2.0, s / 2.0 - cell * 0.55, cell]

	func _place() -> void:
		var g := _geometry()
		var mid := GameState.starting_ring_side() * 2
		for k in Ring.SLOTS:
			var a := float(k - mid) * TAU / 8.0
			var c: Control = cells[k]
			c.size = Vector2(g[2], g[2])
			c.position = g[0] + Vector2(sin(a), -cos(a)) * float(g[1]) - c.size / 2.0
		you.size = Vector2(g[2], g[2])
		you.position = g[0] - you.size / 2.0
		if is_instance_valid(you.portrait):
			var p: Control = you.portrait
			var ps: float = g[2] * 0.7
			p.custom_minimum_size = Vector2.ZERO
			p.size = Vector2(ps, ps)
			p.position = Vector2((g[2] - ps) / 2.0, 4.0)
		queue_redraw()

	func queue_redraw_cells() -> void:
		for c in cells:
			c.queue_redraw()

	func _draw() -> void:
		var g := _geometry()
		draw_arc(g[0], g[1], 0, TAU, 64, Color(UIKit.BORDER, 0.3), 3.0, true)


## One place on the ring: a beast (or you) on a tile, its level (or "You") under it; dim where the item can't go.
class TargetCell extends Button:
	const UIKit = preload("res://scripts/ui/ui_kit.gd")
	const Ring = preload("res://scripts/core/ring.gd")
	const PixelArt = preload("res://scripts/gfx/pixel_art.gd")
	const ItemUse = preload("res://scripts/core/item_use.gd")
	var page
	var who
	var slot := -1
	var allowed := false
	var why := ""
	var portrait: Control

	func _init(_page, _who, _slot: int) -> void:
		page = _page
		who = _who
		slot = _slot
		flat = true
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		pressed.connect(func(): page.target_chosen(self))
		focus_entered.connect(func(): page.target_focused(self))
		mouse_entered.connect(func(): if allowed and not UI.is_touch(): grab_focus())

	## Names are cut short with an ellipsis rather than shrunk.
	static func fit(font: Font, text: String, fs: int, w: float) -> String:
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= w:
			return text
		var t := text
		while t.length() > 1 and font.get_string_size(t + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
			t = t.substr(0, t.length() - 1)
		return t + "…"

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var chosen: bool = allowed and page.same(page.target, who)
		# disabled: a faint tile; chosen: filled with the gem; focused: a thin dark ring
		draw_style_box(UIKit.tile_box(UIKit.ACCENT if chosen else UIKit.WELL, Color(0, 0, 0, 0), 1.0 if allowed else 0.5), r)
		if has_focus():
			draw_style_box(UIKit.focus_ring(), r)
		var font := UIKit.font_bold()
		var fs := UIKit.body_px(20)
		var under := ""
		var cond := ["", ""]
		var tint := Color.WHITE if allowed else Color(1, 1, 1, 0.35)
		if typeof(who) == TYPE_STRING:
			under = GameState.player_name.to_upper()
		elif who != null:
			var ir := Rect2(size.x * 0.18, size.y * 0.08, size.x * 0.64, size.y * 0.6)
			var down: bool = who.hp <= 0
			draw_texture_rect(PixelArt.beast_texture(who.genes), ir, false, Color(0.4, 0.38, 0.42, tint.a) if down else tint)
			if down:
				UIKit.draw_cross(self, ir.get_center(), ir.size.x * 0.4)
			under = String(who.nickname).to_upper()
			cond = ItemUse.condition(who)
		if under != "":
			under = fit(font, under, fs, size.x - 12.0)
			var us := font.get_string_size(under, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			draw_string(font, Vector2((size.x - us.x) / 2.0, size.y - 8.0), under, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				UIKit.LIGHT if chosen else (UIKit.INK if allowed else Color(UIKit.DIM, 0.6)))
		if cond[0] != "":
			# fainted or ailing: a small tag at the icon's top-right corner
			var ts := font.get_string_size(cond[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			var tr := Rect2(size.x - ts.x - 18.0, 4.0, ts.x + 12.0, font.get_height(fs) + 2.0)
			var col := Color(0.78, 0.16, 0.16) if cond[0] == "KO" else Color(0.45, 0.2, 0.6)
			draw_rect(tr, Color(col, 0.95 if allowed else 0.6))
			draw_rect(tr, Color(1, 1, 1, 0.9 if allowed else 0.5), false, 2.0)
			draw_string(font, tr.position + Vector2(6.0, font.get_ascent(fs) + 1.0), cond[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, tint.a + 0.3))
		if is_instance_valid(portrait):
			portrait.modulate = Color(1, 1, 1, 1.0 if allowed else 0.35)
