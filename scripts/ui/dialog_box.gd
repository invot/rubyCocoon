extends "res://scripts/ui/modal.gd"
## Typewriter dialogue in a window along the bottom of the screen, with the speaker's name on an accent tab.
## Text sits at the top of the box (not vertically centred), three big lines at a time: longer lines are split into pages.

const LINES_PER_PAGE := 3

const UIKit = preload("res://scripts/ui/ui_kit.gd")

var lines: Array = []
var speaker := ""
var portrait: Texture2D = null
var idx := 0
var shown := 0.0
var text_label: Label
var name_panel: PanelContainer
var more: TextureRect
var _blink := 0.0
var _last_blip := 0
var _voice := 1.0
var _paged := false
var _box_h := 202.0


func setup(_lines: Array, _speaker := "", _portrait: Texture2D = null) -> Control:
	lines = _lines
	speaker = _speaker
	portrait = _portrait
	# every speaker gets their own voice pitch
	_voice = 0.8 + float(absi(speaker.hash()) % 9) * 0.06 if speaker != "" else 1.0
	return self


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.box("dialogue", Vector4(26, 8, 26, 4)))
	p.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	var side := 304.0 if UI.is_touch() else 48.0
	p.offset_left = side
	p.offset_right = -side
	_box_h = 3.0 * UIKit.body_px(UIKit.BODY_HUGE) + 70.0
	p.offset_top = -12.0 - _box_h - _bottom_gap()
	p.offset_bottom = -12 - _bottom_gap()
	add_child(p)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	p.add_child(hb)
	if portrait:
		var tr := TextureRect.new()
		tr.texture = portrait
		tr.custom_minimum_size = Vector2(120, 120)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hb.add_child(tr)
	text_label = UIKit.label("", UIKit.BODY_HUGE, UIKit.INK)
	text_label.add_theme_constant_override("line_spacing", 0)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	hb.add_child(text_label)
	if speaker != "":
		name_panel = PanelContainer.new()
		name_panel.add_theme_stylebox_override("panel", UIKit.box("nameplate", Vector4(8, -2, 8, -2)))
		var nl := UIKit.header(speaker, UIKit.LIGHT)
		name_panel.add_child(nl)
		name_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		name_panel.offset_left = side + 24
		name_panel.offset_top = -12.0 - _box_h - 46.0 - _bottom_gap()
		name_panel.offset_bottom = -12.0 - _box_h + 6.0 - _bottom_gap()
		add_child(name_panel)
	more = UIKit.icon("arrow_down")
	more.stretch_mode = TextureRect.STRETCH_KEEP
	more.self_modulate = UIKit.GOLD
	add_child(more)
	_place_more(0.0)
	text_label.text = ""
	_paginate.call_deferred()


## Splits every line into pages of LINES_PER_PAGE wrapped lines, once the label knows its width.
func _paginate() -> void:
	await get_tree().process_frame
	var width := text_label.size.x - 4.0
	var font := text_label.get_theme_font("font")
	var fs := text_label.get_theme_font_size("font_size")
	var pages := []
	for raw in lines:
		var wrapped := []
		var cur := ""
		for word in str(raw).split(" "):
			var trial := word if cur == "" else cur + " " + word
			if cur != "" and font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
				wrapped.append(cur)
				cur = word
			else:
				cur = trial
		wrapped.append(cur)
		for i in range(0, wrapped.size(), LINES_PER_PAGE):
			pages.append(" ".join(wrapped.slice(i, i + LINES_PER_PAGE)))
	lines = pages
	_paged = true
	_show_line()


## Leaves room for the key legend / touch controls at the bottom of the screen.
func _bottom_gap() -> float:
	return UI.bottom_reserve() if is_instance_valid(UI) else 0.0


func _place_more(bob: float) -> void:
	var side := 304.0 if UI.is_touch() else 48.0
	var vp := size if size.x > 0 else get_viewport_rect().size
	more.position = Vector2(vp.x - side - 64, vp.y - _bottom_gap() - 48 + bob)


func _show_line() -> void:
	text_label.text = str(lines[idx])
	text_label.visible_characters = 0
	shown = 0.0
	_last_blip = 0


func _process(delta: float) -> void:
	if not _paged:
		return
	var total := text_label.get_total_character_count()
	if text_label.visible_characters < total and text_label.visible_characters != -1:
		var speed: float = Prefs.text_speed if is_instance_valid(Prefs) else 60.0
		shown = 99999.0 if speed <= 0.0 else shown + delta * speed
		text_label.visible_characters = mini(total, int(shown))
		if text_label.visible_characters - _last_blip >= 4:
			_last_blip = text_label.visible_characters
			Sfx.play_pitched("talk", _voice)
		more.visible = false
	else:
		_blink += delta
		more.visible = true
		_place_more(absf(sin(_blink * 5.0)) * 6.0)


func _advance() -> void:
	if not _paged:
		return
	if text_label.visible_characters != -1 and text_label.visible_characters < text_label.get_total_character_count():
		text_label.visible_characters = -1
		shown = 99999.0
		return
	idx += 1
	Sfx.play("blip")
	if idx >= lines.size():
		close()
	else:
		_show_line()


func on_input(ev: InputEvent) -> void:
	if ev.is_echo():
		return
	if ev.is_action_pressed("ui_accept") or ev.is_action_pressed("interact") or ev.is_action_pressed("ui_cancel"):
		_advance()


func _gui_input(ev: InputEvent) -> void:
	# taps arrive as emulated mouse clicks too, so only mouse events are handled here
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if not UI.touch_blocks(ev.position):
			_advance()
