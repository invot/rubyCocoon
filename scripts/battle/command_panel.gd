extends "res://scripts/ui/modal.gd"
## The battle's command panel (as in Jade Cocoon 2): you, then your three active beasts, stacked in rows.
##   ◄ / ►  change the focused row's action (your action, or the beast's move: the side's element, neutral or Defend)
##   A       confirm it; a move that needs a target then asks for one with ◄ / ► and A
##   B       go back a step
##   ▲ / ▼   move between the beasts; ▲ on the top beast or ▼ on the bottom one turns the ring to the next side with
##           a beast standing on it (your beasts' choices are then made afresh)
## You choose your own action first (you always act first), then the beasts'. When every standing beast has its move,
## the round begins. Every part can be tapped too.
##
## The panel only collects choices: rows (built by battle.gd) keep their state, so the panel can close for a sub-menu
## (items, the flute) and open again where it left off. done emits {"kind": "go"} when everything is chosen,
## {"kind": "rotate", "dir": -1 / 1}, or {"kind": "sub", "row": i} (the focused option needs battle.gd's own menu).
## rows: [{kind: "trainer" | "beast", beast, name, icon, sub, options: [{label, right, desc, target, disabled,
##         sub}], sel, done, target_sel, targets: [{label, ref}], status: "" | "down" | "empty", locked}]
## info: {side, up, down, prompt}; on_point: Callable(ref) points the battle's arrow at a target (or null).

const UIKit = preload("res://scripts/ui/ui_kit.gd")

var rows: Array = []
var info: Dictionary = {}
var focus := 0
var picking := false
var on_point: Callable
var targets_for: Callable

var _panel: PanelContainer
var _row_nodes: Array = []
var _desc: Label
var _side_label: Label
var _hint_label: Label
var _up_btn: Button
var _down_btn: Button


func setup(_rows: Array, _info: Dictionary, _focus: int, _targets_for: Callable, _on_point: Callable) -> Control:
	rows = _rows
	info = _info
	focus = clampi(_focus, 0, rows.size() - 1)
	targets_for = _targets_for
	on_point = _on_point
	return self


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var touch: bool = UI.is_touch()
	var row_h := 56.0 if touch else 42.0
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UIKit.box("dialogue", Vector4(0, -4, 0, -2)))
	# desktop: the bottom-right corner, clear of your ring; phones: between the d-pad and A / B
	var vw := get_viewport_rect().size.x
	var w := 640.0 if not touch else minf(900.0, vw - 600.0)
	_panel.custom_minimum_size = Vector2(w, 0)
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var bottom := 10.0 + (UI.bottom_reserve() if is_instance_valid(UI) else 0.0)
	if touch:
		_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_panel.offset_left = -w / 2.0
		_panel.offset_right = w / 2.0
	else:
		_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_panel.offset_left = -16.0 - w
		_panel.offset_right = -16.0
	_panel.offset_bottom = -bottom
	_panel.offset_top = -bottom
	add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	_panel.add_child(vb)
	# the side facing the foe, and where ▲ / ▼ would turn the ring
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	vb.add_child(head)
	_side_label = UIKit.header("", UIKit.GOLD)
	head.add_child(_side_label)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	_hint_label = UIKit.label("", 20, UIKit.DIM)
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_hint_label)
	for i in rows.size():
		if i == 1:
			_up_btn = _turn_button(-1)
			vb.add_child(_up_btn)
		var r := _make_row(i, row_h)
		vb.add_child(r)
		_row_nodes.append(r)
	_down_btn = _turn_button(1)
	vb.add_child(_down_btn)
	var sep := HSeparator.new()
	vb.add_child(sep)
	_desc = UIKit.label("", 20, UIKit.INK)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.add_theme_constant_override("line_spacing", 0)
	_desc.custom_minimum_size = Vector2(w - 50.0, 2.0 * UIKit.body_px(20) + 6.0)
	_desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	vb.add_child(_desc)
	_redraw()


## A slim "turn the ring" bar above the top beast (▲) and below the bottom one (▼), for tapping.
func _turn_button(dir: int) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 30 if UI.is_touch() else 24)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", UIKit.body_px(20))
	b.pressed.connect(func(): _rotate(dir))
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(st, empty)
	b.add_theme_color_override("font_color", UIKit.DIM)
	b.add_theme_color_override("font_hover_color", UIKit.GOLD)
	b.add_theme_color_override("font_disabled_color", Color(UIKit.DIM, 0.35))
	return b


func _make_row(i: int, row_h: float) -> Control:
	var row: Dictionary = rows[i]
	var c := PanelContainer.new()
	c.custom_minimum_size = Vector2(0, row_h)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.gui_input.connect(func(ev): _row_click(i, ev))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	c.add_child(hb)
	var ic := TextureRect.new()
	ic.texture = row.get("icon", null)
	ic.custom_minimum_size = Vector2(row_h - 10.0, row_h - 10.0)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(ic)
	var nl := UIKit.label(row.get("name", ""), 20, UIKit.LIGHT)
	nl.clip_text = true
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nl.custom_minimum_size = Vector2(150, 0)
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nl.name = "Name"
	hb.add_child(nl)
	var left := _arrow_button("◄", func(): _focus_row(i); _cycle(-1))
	left.name = "Left"
	hb.add_child(left)
	var opt := HBoxContainer.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.add_theme_constant_override("separation", 8)
	opt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(opt)
	var ol := UIKit.label("", 20, UIKit.INK)
	ol.name = "Opt"
	ol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ol.clip_text = true
	ol.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	opt.add_child(ol)
	var orr := UIKit.label("", 20, UIKit.GOLD)
	orr.name = "Right"
	orr.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	orr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	opt.add_child(orr)
	var right := _arrow_button("►", func(): _focus_row(i); _cycle(1))
	right.name = "RightBtn"
	hb.add_child(right)
	var ok := _arrow_button("OK", func(): _focus_row(i); _confirm())
	ok.name = "Ok"
	ok.custom_minimum_size.x = 56
	hb.add_child(ok)
	return c


func _arrow_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(48 if UI.is_touch() else 36, 0)
	b.pressed.connect(cb)
	var sb := UIKit.chip(UIKit.WINDOW_TOP, Color(UIKit.BORDER, 0.5), 10.0, Vector4(6, 0, 6, 0))
	for st in ["normal", "disabled"]:
		b.add_theme_stylebox_override(st, sb)
	var hl := UIKit.chip(UIKit.ACCENT, UIKit.BORDER, 10.0, Vector4(6, 0, 6, 0))
	for st in ["hover", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(st, hl)
	b.add_theme_font_size_override("font_size", UIKit.body_px(20))
	return b


# ---------------------------------------------------------------- drawing
func _redraw() -> void:
	_side_label.text = String(info.get("side", ""))
	var up: String = info.get("up", "")
	var down: String = info.get("down", "")
	_hint_label.text = "◄► change   A ok   B back"
	if _up_btn:
		_up_btn.text = ("      ▲  turn to the %s side" % up) if up != "" else ""
		_up_btn.disabled = up == "" or not rows[0].get("done", false)
	if _down_btn:
		_down_btn.text = ("      ▼  turn to the %s side" % down) if down != "" else ""
		_down_btn.disabled = down == "" or not rows[0].get("done", false)
	for i in rows.size():
		var row: Dictionary = rows[i]
		var node: PanelContainer = _row_nodes[i]
		var on := i == focus
		var sb: StyleBox
		if on:
			sb = UIKit.highlight()
		else:
			sb = StyleBoxEmpty.new()
		node.add_theme_stylebox_override("panel", sb)
		var opt_l: Label = node.find_child("Opt", true, false)
		var right_l: Label = node.find_child("Right", true, false)
		var ok_b: Button = node.find_child("Ok", true, false)
		var lb: Button = node.find_child("Left", true, false)
		var rb: Button = node.find_child("RightBtn", true, false)
		var status: String = row.get("status", "")
		var usable: bool = status == "" and not row.get("locked", false) and _row_enabled(i)
		lb.visible = usable
		rb.visible = usable
		ok_b.visible = usable
		if status == "down":
			opt_l.text = "Fainted"
			right_l.text = ""
			opt_l.add_theme_color_override("font_color", UIKit.DIM)
			continue
		if status == "empty":
			opt_l.text = "— empty slot —"
			right_l.text = ""
			opt_l.add_theme_color_override("font_color", UIKit.DIM)
			continue
		var opts: Array = row["options"]
		var o: Dictionary = opts[clampi(int(row.get("sel", 0)), 0, opts.size() - 1)]
		if picking and on:
			var ts: Array = row.get("targets", [])
			var t: Dictionary = ts[clampi(int(row.get("target_sel", 0)), 0, ts.size() - 1)] if not ts.is_empty() else {}
			opt_l.text = "%s  →  %s" % [o["label"], t.get("label", "?")]
			right_l.text = "◄► target"
		else:
			opt_l.text = ("✓ " if row.get("done", false) else "") + String(o["label"])
			right_l.text = String(o.get("right", ""))
		var col := UIKit.INK
		if o.get("disabled", false):
			col = Color(UIKit.DIM, 0.8)
		elif row.get("done", false):
			col = UIKit.GOLD_BRIGHT
		opt_l.add_theme_color_override("font_color", col)
		ok_b.text = "✓" if row.get("done", false) else "OK"
	var fr: Dictionary = rows[focus]
	if fr.get("status", "") != "":
		_desc.text = String(fr.get("status_desc", ""))
	else:
		var fo: Dictionary = fr["options"][clampi(int(fr.get("sel", 0)), 0, fr["options"].size() - 1)]
		_desc.text = String(fo.get("desc", ""))
		if picking:
			_desc.text = "Choose a target with ◄ ►, then A.   B: back to the moves."
	if String(info.get("prompt", "")) != "" and focus == 0 and not rows[0].get("done", false):
		_desc.text = String(info["prompt"]) + "\n" + _desc.text


## The beasts' rows open once your own action is chosen.
func _row_enabled(i: int) -> bool:
	return i == 0 or rows[0].get("done", false)


# ---------------------------------------------------------------- input
func on_input(ev: InputEvent) -> void:
	if ev.is_echo() and not (ev.is_action("ui_left") or ev.is_action("ui_right")):
		return
	if not ev.is_pressed():
		return
	if ev.is_action_pressed("ui_left", true):
		_cycle(-1)
	elif ev.is_action_pressed("ui_right", true):
		_cycle(1)
	elif ev.is_action_pressed("ui_up"):
		_move(-1)
	elif ev.is_action_pressed("ui_down"):
		_move(1)
	elif ev.is_action_pressed("ui_accept") or ev.is_action_pressed("interact"):
		_confirm()
	elif ev.is_action_pressed("ui_cancel"):
		_back()


func _row_click(i: int, ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if i != focus:
			_focus_row(i)
		elif not picking:
			_confirm()


func _focus_row(i: int) -> void:
	if i == focus or not _row_enabled(i):
		return
	if picking:
		picking = false
	focus = i
	Sfx.play("select")
	_point_row()
	_redraw()


func _point_row() -> void:
	if not on_point.is_valid():
		return
	var row: Dictionary = rows[focus]
	if picking:
		var ts: Array = row.get("targets", [])
		on_point.call(ts[clampi(int(row.get("target_sel", 0)), 0, ts.size() - 1)]["ref"] if not ts.is_empty() else null)
	else:
		on_point.call("trainer_self" if row["kind"] == "trainer" else row.get("beast", null))


func _cycle(dir: int) -> void:
	var row: Dictionary = rows[focus]
	if row.get("status", "") != "" or row.get("locked", false) or not _row_enabled(focus):
		return
	if picking:
		var ts: Array = row.get("targets", [])
		if ts.size() > 1:
			row["target_sel"] = posmod(int(row.get("target_sel", 0)) + dir, ts.size())
			Sfx.play("select")
			_point_row()
		_redraw()
		return
	var n: int = row["options"].size()
	if n <= 1:
		return
	row["sel"] = posmod(int(row.get("sel", 0)) + dir, n)
	row["done"] = false
	Sfx.play("select")
	_redraw()


## ▲ / ▼: to the next beast row; past the top or bottom beast, turn the ring.
func _move(dir: int) -> void:
	if picking:
		return
	if focus == 0:
		if dir > 0 and rows[0].get("done", false):
			_focus_row(1)
		return
	var nxt := focus + dir
	if nxt < 1:
		_rotate(-1)
		return
	if nxt >= rows.size():
		_rotate(1)
		return
	_focus_row(nxt)


func _rotate(dir: int) -> void:
	if not rows[0].get("done", false):
		Sfx.play("error")
		return
	if String(info.get("up" if dir < 0 else "down", "")) == "":
		Sfx.play("error")
		return
	Sfx.play("page")
	close({"kind": "rotate", "dir": dir, "focus": 1 if dir < 0 else rows.size() - 1})


func _confirm() -> void:
	var row: Dictionary = rows[focus]
	if not _row_enabled(focus):
		return
	if row.get("status", "") != "" or row.get("locked", false):
		_advance()
		return
	var o: Dictionary = row["options"][clampi(int(row.get("sel", 0)), 0, row["options"].size() - 1)]
	if o.get("disabled", false):
		Sfx.play("error")
		return
	if picking:
		picking = false
		row["done"] = true
		Sfx.play("confirm")
		_advance()
		return
	if o.get("sub", false):
		Sfx.play("confirm")
		close({"kind": "sub", "row": focus, "focus": focus})
		return
	var kind: String = o.get("target", "none")
	if kind in ["enemy", "ally", "ally_ko"]:
		var ts: Array = targets_for.call(row, o) if targets_for.is_valid() else []
		if ts.is_empty():
			Sfx.play("error")
			_desc.text = "There's no one to use that on right now."
			return
		row["targets"] = ts
		row["target_sel"] = clampi(int(row.get("target_sel", 0)), 0, ts.size() - 1)
		if ts.size() > 1:
			picking = true
			Sfx.play("confirm")
			_point_row()
			_redraw()
			return
		row["target_sel"] = 0
	else:
		row["targets"] = []
	row["done"] = true
	Sfx.play("confirm")
	_advance()


## After a confirmation: to the next beast that still needs a move, or begin the round when all are set.
func _advance() -> void:
	for i in range(1, rows.size()):
		var k := posmod(focus - 1 + i, rows.size() - 1) + 1 if focus > 0 else i
		var r: Dictionary = rows[k]
		if r.get("status", "") == "" and not r.get("done", false) and not r.get("locked", false):
			focus = k
			_point_row()
			_redraw()
			return
	if rows[0].get("done", false):
		if on_point.is_valid():
			on_point.call(null)
		close({"kind": "go", "focus": focus})
		return
	focus = 0
	_redraw()


func _back() -> void:
	if picking:
		picking = false
		Sfx.play("back")
		_point_row()
		_redraw()
		return
	var row: Dictionary = rows[focus]
	if row.get("done", false) and not row.get("locked", false):
		row["done"] = false
		Sfx.play("back")
		_redraw()
		return
	if focus > 0:
		# back up to the beast chosen last, or to your own action
		for k in range(focus - 1, 0, -1):
			if rows[k].get("done", false):
				rows[k]["done"] = false
				_focus_row(k)
				return
		if not rows[0].get("locked", false):
			rows[0]["done"] = false
			Sfx.play("back")
			_focus_row(0)
			_redraw()
		return
	Sfx.play("error")
