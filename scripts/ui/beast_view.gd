extends "res://scripts/ui/modal.gd"
## Full summary card for one beast.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Bar = preload("res://scripts/ui/bar.gd")
const Elements = preload("res://scripts/data/elements.gd")
const MoveDB = preload("res://scripts/data/move_db.gd")
const RaceDB = preload("res://scripts/data/race_db.gd")
const ItemDB = preload("res://scripts/data/item_db.gd")
const PixelArt = preload("res://scripts/gfx/pixel_art.gd")
const VoxelPortrait = preload("res://scripts/ui/voxel_portrait.gd")
const ScrollRail = preload("res://scripts/ui/scroll_rail.gd")

var beast
var heading := ""
var _sprite: TextureRect
var _t := 0.0
var _panel: PanelContainer
var _scroll: ScrollContainer


func setup(b, _heading := "") -> Control:
	beast = b
	heading = _heading
	dim = 0.55
	return self


func _ready() -> void:
	var b = beast
	var p := UIKit.panel()
	_panel = p
	add_child(p)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	p.add_child(root)
	if heading != "":
		var h := UIKit.ribbon(heading)
		h.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		h.custom_minimum_size.x = 560
		root.add_child(h)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 24)
	var page := HBoxContainer.new()
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(page)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	page.add_child(_scroll)
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(hb)
	page.add_child(ScrollRail.new().setup(_scroll))

	# left: portrait
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	hb.add_child(left)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UIKit.box("slot", Vector4(4, 4, 4, 4)))
	left.add_child(frame)
	frame.add_child(VoxelPortrait.new().setup(b.genes, 280))
	var name_l := UIKit.header(b.nickname, UIKit.INK)
	left.add_child(name_l)
	var tags := HBoxContainer.new()
	tags.add_child(UIKit.element_tag(b.element, 16))
	var role: String = Elements.ROLE.get(b.element, "")
	if role != "":
		tags.add_child(UIKit.label("  " + role, 16, UIKit.DIM))
	left.add_child(tags)
	left.add_child(UIKit.label("Rank %s   Lv %d / %d" % [b.rank_stars(), b.level, b.level_cap()], 18, UIKit.GOLD))
	var xpb := Bar.new(Vector2(280, 8))
	xpb.fixed_color = UIKit.GOLD
	xpb.set_ratio(b.xp_progress(), true)
	left.add_child(xpb)
	if b.at_cap():
		left.add_child(UIKit.label("Ready to merge!", 18, UIKit.HEAD))
	var lin := UIKit.label("Lineage: " + b.lineage_text(), 15, UIKit.DIM)
	lin.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lin.custom_minimum_size.x = 290
	left.add_child(lin)

	# right: stats, passives, moves
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	hb.add_child(right)
	right.add_child(UIKit.label("HP %d / %d" % [maxi(0, b.hp), b.max_hp()], 20))
	var hpb := Bar.new(Vector2(400, 12))
	hpb.set_ratio(b.hp_ratio(), true)
	right.add_child(hpb)
	right.add_child(UIKit.label("MP %d / %d   (elemental attacks spend it)" % [b.mp, b.max_mp()], 20))
	var mpb := Bar.new(Vector2(400, 8))
	mpb.fixed_color = UIKit.GOLD_BRIGHT
	mpb.set_ratio(b.mp_ratio(), true)
	right.add_child(mpb)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	right.add_child(grid)
	for s in ["atk", "def", "spr", "spd"]:
		grid.add_child(UIKit.header(b.STAT_NAMES[s], UIKit.DIM, UIKit.HEAD_SMALL))
		grid.add_child(UIKit.label(str(b.stat(s)), 18))
		var sbar := Bar.new(Vector2(220, 8))
		sbar.fixed_color = UIKit.GOLD
		sbar.set_ratio(float(b.stat(s)) / maxf(60.0, b.level * 2.6 + 10), true)
		grid.add_child(sbar)
	right.add_child(HSeparator.new())
	for ps in b.passives:
		var pl := UIKit.label("%s — %s" % [ps, RaceDB.PASSIVE_DESC.get(ps, "")], 24, UIKit.HEAD)
		pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		right.add_child(pl)
	var eq := "Gear: " + (ItemDB.item_name(b.equip) if b.equip != "" else "(none)")
	right.add_child(UIKit.label(eq, 16, UIKit.DIM))
	right.add_child(HSeparator.new())
	right.add_child(UIKit.header("Skills", UIKit.HEAD, UIKit.HEAD_SMALL))
	for mv in b.battle_moves():
		var m := MoveDB.get_move(mv)
		var row := HBoxContainer.new()
		row.add_child(UIKit.element_tag(m["el"], 13))
		var ml := UIKit.label(" %s" % m["name"], 18)
		ml.custom_minimum_size.x = 170
		row.add_child(ml)
		var dl := UIKit.label(_short(mv), 24, UIKit.DIM)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(dl)
		right.add_child(row)
	var slots := []
	for g in b.slot_groups():
		slots.append("%s %d/%d" % ["Plain" if g == "plain" else String(g).capitalize(), b.slot_moves(g).size(), b.slot_size(g)])
	right.add_child(UIKit.label("Move slots: " + "  ·  ".join(slots), 16, UIKit.DIM))
	get_viewport().size_changed.connect(_layout)
	UI.controls.layout_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var safe := UIKit.safe_rect(self).grow(-24.0)
	if UI.top_bar != null and UI.top_bar.visible:
		var top := maxf(safe.position.y, UI.top_bar.get_global_rect().end.y + 12.0)
		safe.size.y -= top - safe.position.y
		safe.position.y = top
	var w := minf(1060.0, safe.size.x)
	var x := safe.get_center().x - w/2.0
	# The close action spans the free centre, above Start/Pause. Side pads may
	# overlap the frame, rather than reducing the whole detail pane to half a page.
	var bottom: float = UI.bottom_reserve()
	_panel.position = Vector2(x, safe.position.y)
	_panel.size = Vector2(w, safe.size.y-bottom)


func _short(mv: String) -> String:
	var m := MoveDB.get_move(mv)
	var s := ""
	if m.has("power"):
		s += "Pow %d  " % m["power"]
	return s + m.get("desc", "")


func _process(delta: float) -> void:
	_t += delta
	if _sprite:
		_sprite.position.y = sin(_t * 3.0) * 3.0


func on_input(ev: InputEvent) -> void:
	if ev.is_echo():
		return
	if ev.is_action_pressed("ui_down") or ev.is_action_pressed("ui_up"):
		_scroll.scroll_vertical += int(UIKit.row_h()) * (1 if ev.is_action_pressed("ui_down") else -1)
		return
	if ev.is_action_pressed("ui_accept") or ev.is_action_pressed("ui_cancel") or ev.is_action_pressed("interact"):
		Sfx.play("back")
		close()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and not _panel.get_global_rect().has_point(ev.position):
		close()
