extends "res://scripts/ui/modal.gd"
## Keyboard/touch list menu in a window, with a title tab above it. Emits the chosen index, or -1 when cancelled.
## items: Array of String or Dictionary {text, right, disabled, desc, icon}
## opts: anchor, width, rows, cancel, start, on_focus (Callable), dim, title_size, margin; font_size: the rows' text
## size (UI units); bare: no box at all, just the options' text, centred and gently pulsing (e.g. a lone "New Game")

const UIKit = preload("res://scripts/ui/ui_kit.gd")


var title := ""
var items: Array = []
var opts: Dictionary = {}
var buttons: Array = []
var desc_label: Label = null
var _panel: PanelContainer
var _focus := -1
var _t := 0.0


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
	var width := float(opts.get("width", 360)) * (1.25 if UI.is_touch() else 1.1) + 40.0
	var outer := VBoxContainer.new()
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
	var font_size := int(opts.get("font_size", 0))
	if font_size > 0:
		row_h = maxf(row_h, font_size * 2.0)
	var bare: bool = opts.get("bare", false)
	if bare:
		_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var rows := int(opts.get("rows", 8))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(width, row_h * mini(rows, maxi(1, items.size())) + 2)
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 0)
	scroll.add_child(list)
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
			for st in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
				b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
			b.alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.add_theme_constant_override("outline_size", 12)
			b.add_theme_color_override("font_outline_color", Color("#493333"))
			for c in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
				b.add_theme_color_override(c, UIKit.LIGHT)
			var pulse := b.create_tween().set_loops()
			pulse.tween_property(b, "modulate:a", 0.75, 0.9).set_trans(Tween.TRANS_SINE)
			pulse.tween_property(b, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
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
	_grab_start.call_deferred()


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
	buttons[s].grab_focus()
	_focused(s)


func _focused(i: int) -> void:
	if _focus != -1 and _focus != i:
		Sfx.play("select")
	_focus = i
	if desc_label:
		desc_label.text = items[i].get("desc", "")
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
