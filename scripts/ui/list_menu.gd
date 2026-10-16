extends "res://scripts/ui/modal.gd"
## Keyboard/touch list menu on a parchment card. Emits the chosen index, or -1 when cancelled.
## items: Array of String or Dictionary {text, right, disabled, desc, icon}
## opts: anchor, width, rows, cancel, start, on_focus (Callable), dim, title_size, margin

const UIKit = preload("res://scripts/ui/ui_kit.gd")

const ROW_H := 46.0

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
	var width := float(opts.get("width", 360)) + 40.0
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", -10)
	add_child(outer)
	var title_lines := title.split("\n")
	if title != "":
		var rib := UIKit.ribbon(title_lines[0], true)
		rib.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		rib.custom_minimum_size.x = minf(width, maxf(220.0, title_lines[0].length() * 19.0 + 80.0))
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
	var row_h := 56.0 if has_icons else ROW_H
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
			b.add_theme_constant_override("icon_max_width", 48)
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
