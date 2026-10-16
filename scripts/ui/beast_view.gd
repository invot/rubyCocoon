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

var beast
var heading := ""
var _sprite: TextureRect
var _t := 0.0


func setup(b, _heading := "") -> Control:
	beast = b
	heading = _heading
	dim = 0.55
	return self


func _ready() -> void:
	var b = beast
	var p := UIKit.panel(Vector2(980, 560))
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
	root.add_child(hb)

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
	xpb.fixed_color = Color("#60a0ff")
	xpb.set_ratio(b.xp_progress(), true)
	left.add_child(xpb)
	if b.at_cap():
		left.add_child(UIKit.label("Ready to merge!", 18, UIKit.ACCENT))
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
	mpb.fixed_color = Color("#5aa8ff")
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
		sbar.fixed_color = Color("#e8c060")
		sbar.set_ratio(float(b.stat(s)) / maxf(60.0, b.level * 2.6 + 10), true)
		grid.add_child(sbar)
	right.add_child(HSeparator.new())
	for ps in b.passives:
		var pl := UIKit.label("◆ %s — %s" % [ps, RaceDB.PASSIVE_DESC.get(ps, "")], 16, UIKit.ACCENT)
		pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		right.add_child(pl)
	var eq := "Gear: " + (ItemDB.item_name(b.equip) if b.equip != "" else "(none)")
	right.add_child(UIKit.label(eq, 16, UIKit.DIM))
	right.add_child(HSeparator.new())
	right.add_child(UIKit.header("Skills", UIKit.ACCENT, UIKit.HEAD_SMALL))
	for mv in b.battle_moves():
		var m := MoveDB.get_move(mv)
		var row := HBoxContainer.new()
		row.add_child(UIKit.element_tag(m["el"], 13))
		var ml := UIKit.label(" %s" % m["name"], 18)
		ml.custom_minimum_size.x = 170
		row.add_child(ml)
		var dl := UIKit.label(_short(mv), 15, UIKit.DIM)
		row.add_child(dl)
		right.add_child(row)
	var extra: int = b.known.size() - b.moves.size()
	if extra > 0:
		right.add_child(UIKit.label("(+%d more moves remembered)" % extra, 15, UIKit.DIM))
	var hint := UIKit.label("A / S close", 15, UIKit.DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(hint)
	UIKit.place(p, "center")


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
	if ev.is_action_pressed("ui_accept") or ev.is_action_pressed("ui_cancel") or ev.is_action_pressed("interact"):
		Sfx.play("back")
		close()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		close()
