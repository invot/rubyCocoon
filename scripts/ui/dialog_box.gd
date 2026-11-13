extends "res://scripts/ui/modal.gd"
## Named speech uses a white bubble; written text and system prompts use the shared dark window.
## CinematicDialog shares the spoken/written distinction.
## Text stays top-aligned. Speech pages keep complete sentences, normally within three lines.

const LINES_PER_PAGE := 3
## Leave the face readable on either side of the bubble, including the pointer's tip.
const HEAD_GAP := 64.0
const CHEVRON_H := 18.0

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
var bubble_mode := true
var speaker_node: Node3D
var bubble: PanelContainer
var _surface: ColorRect
var _name_label: Label
var _head_local := Vector3(0, 1.35, 0)
var _head_screen := Vector2.ZERO
var _anchored := false
var _below := false
var _bubble_rect := Rect2()
var _tail := PackedVector2Array()
var _gem := ""
var _last_head_screen := Vector2.INF
var _had_anchor := false
var _tail_below := false
var _door_anchor := false
var _door_bottom := Vector2.ZERO
var _speech_width := 720.0


func setup(_lines: Array, _speaker := "", _portrait: Texture2D = null, _speaker_node: Node3D = null) -> Control:
	lines = _lines
	speaker = _speaker
	portrait = _portrait
	speaker_node = _speaker_node
	bubble_mode = speaker != ""
	# every speaker gets their own voice pitch
	_voice = 0.8 + float(absi(speaker.hash()) % 9) * 0.06 if speaker != "" else 1.0
	return self


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if bubble_mode:
		_ready_bubble()
		return
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


func _ready_bubble() -> void:
	_surface = UIKit.speech_surface()
	add_child(_surface)
	bubble = PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", UIKit.speech_box())
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bubble)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 16)
	bubble.add_child(row)
	if portrait != null:
		var image := TextureRect.new()
		image.texture = portrait
		image.custom_minimum_size = Vector2(120, 120)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(image)
	text_label = UIKit.label("", UIKit.BODY_HUGE, UIKit.DARK)
	text_label.add_theme_font_override("font", UIKit.font_dialog())
	text_label.add_theme_font_size_override("font_size", UIKit.body_px(UIKit.DIALOG_SIZE))
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.add_theme_constant_override("line_spacing", 0)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	row.add_child(text_label)
	if speaker != "":
		name_panel = PanelContainer.new()
		name_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_panel.add_theme_stylebox_override("panel", UIKit.speech_box(true))
		_name_label = UIKit.header(speaker, UIKit.ACCENT)
		_name_label.add_theme_color_override("font_color", UIKit.INK)
		_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_panel.add_child(_name_label)
		add_child(name_panel)
	more = UIKit.icon("arrow_down")
	more.mouse_filter = Control.MOUSE_FILTER_IGNORE
	more.stretch_mode = TextureRect.STRETCH_KEEP
	more.self_modulate = UIKit.DARK
	more.visible = false
	add_child(more)
	# Sample the posed head once. Breathing, looking around and talking must not shake the bubble.
	if is_instance_valid(speaker_node) and speaker_node.has_meta("skeleton"):
		var skeleton: Skeleton3D = speaker_node.get_meta("skeleton")
		var head := skeleton.find_bone("head")
		if head >= 0:
			var local := speaker_node.to_local(skeleton.to_global(skeleton.get_bone_global_pose(head).origin))
			_head_local.y = local.y + 0.12
	_layout_bubble()
	_paginate.call_deferred()


## Project the stable head offset through the speaker's own viewport; the world renders in a SubViewport.
func _project_head() -> bool:
	if not is_instance_valid(speaker_node) or not speaker_node.is_inside_tree() or not speaker_node.is_visible_in_tree():
		return false
	var view := speaker_node.get_viewport()
	var camera := view.get_camera_3d()
	if camera == null:
		return false
	_door_anchor = speaker_node.has_meta("speech_bounds")
	if _door_anchor:
		var bounds: AABB = speaker_node.get_meta("speech_bounds")
		var centre := bounds.get_center()
		var top := speaker_node.to_global(Vector3(centre.x, bounds.end.y, centre.z))
		var bottom := speaker_node.to_global(Vector3(centre.x, bounds.position.y, centre.z))
		if camera.is_position_behind(top) or camera.is_position_behind(bottom):
			return false
		var scale := get_viewport_rect().size / view.get_visible_rect().size
		_head_screen = _snap(camera.unproject_position(top) * scale)
		_door_bottom = _snap(camera.unproject_position(bottom) * scale)
		return get_viewport_rect().has_point(_head_screen) or get_viewport_rect().has_point(_door_bottom)
	var head := speaker_node.to_global(_head_local)
	if camera.is_position_behind(head):
		return false
	_head_screen = camera.unproject_position(head) * get_viewport_rect().size / view.get_visible_rect().size
	_head_screen = _snap(_head_screen)
	return get_viewport_rect().has_point(_head_screen)


func _snap(point: Vector2) -> Vector2:
	var scale := get_viewport().get_screen_transform().get_scale()
	return (point * scale).round() / scale


func _layout_bubble() -> void:
	if _gem != UIKit.accent_name:
		_gem = UIKit.accent_name
		if _name_label != null:
			(name_panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = UIKit.ACCENT
	var safe := UIKit.safe_rect(self).grow(-16.0)
	var plate_h := name_panel.get_combined_minimum_size().y - 6.0 if name_panel != null else 0.0
	var width := minf(_speech_width, safe.size.x)
	var line_count := String(lines[idx]).count("\n") + 1 if _paged else LINES_PER_PAGE
	_box_h = text_label.get_theme_font("font").get_height(text_label.get_theme_font_size("font_size")) * line_count + 48.0
	if portrait != null:
		_box_h = maxf(_box_h, 168.0)
	var room := Rect2(safe.position + Vector2(0, plate_h), safe.size - Vector2(0, plate_h))
	room.size.y -= _below_reserve()
	_anchored = _project_head()
	if _anchored and _door_anchor and UI.top_bar != null and UI.top_bar.visible:
		# A place-name notice may still be showing just after the player knocks indoors.
		var top := maxf(room.position.y, UI.top_bar.get_global_rect().end.y + plate_h + 8.0)
		room.size.y -= top - room.position.y
		room.position.y = top
	var gap := CHEVRON_H + 6.0 if _door_anchor else HEAD_GAP
	_below = _anchored and _head_screen.y - gap - _box_h < room.position.y
	if _anchored and _door_anchor and _below:
		_head_screen = _door_bottom
	var at := Vector2(safe.get_center().x - width / 2.0, safe.end.y - _bottom_gap() - _box_h)
	if _anchored:
		at = Vector2(_head_screen.x - width / 2.0, _head_screen.y + gap if _below else _head_screen.y - gap - _box_h)
	at.x = clampf(at.x, room.position.x, room.end.x - width)
	at.y = clampf(at.y, room.position.y, room.end.y - _box_h)
	var rect := Rect2(at, Vector2(width, _box_h))
	# Test the whole bubble plus name plate against the controls' generous no-world-tap zones.
	# Moving above a cluster always provides a solution on the supported landscape viewports.
	if UI.controls != null and UI.is_touch():
		for group in UI.controls.CLUSTERS:
			var zone: Rect2 = UI.controls.cluster_zone(group, UI.controls.TOUCH_SLOP + UI.controls.NO_TAP_MARGIN)
			var footprint := Rect2(rect.position - Vector2(0, plate_h), rect.size + Vector2(0, plate_h))
			footprint.size.y += _below_reserve()
			if zone.has_area() and footprint.intersects(zone):
				rect.position.y = minf(rect.position.y, zone.position.y - rect.size.y - _below_reserve() - 4.0)
	rect.position = _snap(rect.position)
	var changed := rect != _bubble_rect
	if changed:
		_bubble_rect = rect
		bubble.position = rect.position
		bubble.size = rect.size
	if name_panel != null:
		name_panel.position = _snap(rect.position + Vector2(20, -plate_h))
		name_panel.size = name_panel.get_combined_minimum_size()
	if not changed and _last_head_screen == _head_screen and _had_anchor == _anchored and _tail_below == _below:
		return
	_last_head_screen = _head_screen
	_had_anchor = _anchored
	_tail_below = _below
	_surface.position = rect.position - Vector2(18, 42)
	_surface.size = rect.size + Vector2(36, 84)
	var paper := _surface.material as ShaderMaterial
	paper.set_shader_parameter("body_size", rect.size)
	paper.set_shader_parameter("surface_size", _surface.size)
	paper.set_shader_parameter("has_tail", _anchored)
	_tail.clear()
	if _anchored:
		# Clamping the window slides the chevron along its edge, rather than moving the speaker anchor.
		var edge_x := clampf(_head_screen.x, rect.position.x + 28.0, rect.end.x - 28.0)
		var edge_y := rect.position.y if _below else rect.end.y
		var tip := Vector2(clampf(_head_screen.x, edge_x - 24.0, edge_x + 24.0), edge_y + (-CHEVRON_H if _below else CHEVRON_H))
		# Start just inside the paper, covering the border where the chevron joins it.
		var base_y := edge_y + (2.0 if _below else -2.0)
		_tail = PackedVector2Array([_snap(Vector2(edge_x - 12.0, base_y)), _snap(tip), _snap(Vector2(edge_x + 12.0, base_y))])
		paper.set_shader_parameter("tail_a", _tail[0] - _surface.position)
		paper.set_shader_parameter("tail_b", _tail[1] - _surface.position)
		paper.set_shader_parameter("tail_c", _tail[2] - _surface.position)
	_place_more(0.0)


## Packs complete spoken sentences into pages once the label knows its width.
func _paginate() -> void:
	await get_tree().process_frame
	var width := text_label.size.x - 4.0
	var font := text_label.get_theme_font("font")
	var fs := text_label.get_theme_font_size("font_size")
	var pages := []
	var stops := RegEx.new()
	stops.compile("[.!?]+[\"”’']*(?=\\s|$)")
	for raw in lines:
		if not bubble_mode:
			var written := _wrapped(str(raw), font, fs, width)
			for i in range(0, written.size(), LINES_PER_PAGE):
				pages.append("\n".join(written.slice(i, i+LINES_PER_PAGE)))
			continue
		var page := ""
		var paragraph_index := 0
		for paragraph in str(raw).split("\n"):
			var sentences := []
			var start := 0
			for stop in stops.search_all(paragraph):
				sentences.append(paragraph.substr(start, stop.get_end()-start).strip_edges())
				start = stop.get_end()
			if start < paragraph.length():
				sentences.append(paragraph.substr(start).strip_edges())
			var first := true
			for sentence: String in sentences:
				if sentence == "":
					continue
				var separator := "\n" if first and paragraph_index > 0 else " "
				var trial := sentence if page == "" else page + separator + sentence
				if _wrapped(trial, font, fs, width).size() > LINES_PER_PAGE and page != "":
					pages.append("\n".join(_wrapped(page, font, fs, width)))
					page = ""
				page = sentence if page == "" else page + separator + sentence
				first = false
			paragraph_index += 1
		if page != "":
			var wrapped := _wrapped(page, font, fs, width)
			# An unusually long single sentence stays intact, in a taller bubble.
			pages.append("\n".join(wrapped))
	lines = pages
	# Wrapping is already measured above. A second wrap at a manually inserted break
	# can add an empty line on a different text backend or fractional browser scale.
	text_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_paged = true
	_show_line()


func _wrapped(text: String, font: Font, fs: int, width: float) -> Array:
	var wrapped := []
	for paragraph in text.split("\n"):
		var current := ""
		for word in paragraph.split(" ", false):
			var trial := word if current == "" else current + " " + word
			if current != "" and font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
				wrapped.append(current)
				current = ""
			current = word if current == "" else current + " " + word
		wrapped.append(current)
	return wrapped


## Leaves room for the key legend / touch controls at the bottom of the screen.
func _bottom_gap() -> float:
	return UI.bottom_reserve() if is_instance_valid(UI) else 0.0


func _below_reserve() -> float:
	return 0.0


func _place_more(bob: float) -> void:
	if bubble_mode:
		more.position = _snap(_bubble_rect.end - Vector2(42, 28) + Vector2(0, bob))
		return
	var side := 304.0 if UI.is_touch() else 48.0
	var vp := size if size.x > 0 else get_viewport_rect().size
	more.position = Vector2(vp.x - side - 64, vp.y - _bottom_gap() - 48 + bob)


func _show_line() -> void:
	text_label.text = str(lines[idx])
	text_label.visible_characters = 0
	shown = 0.0
	_last_blip = 0


func _process(delta: float) -> void:
	if closed:
		return
	if bubble_mode:
		_layout_bubble()
	if not _paged:
		return
	var total := text_label.get_total_character_count()
	if text_label.visible_characters < total and text_label.visible_characters != -1:
		var speed: float = Prefs.text_speed if is_instance_valid(Prefs) else 60.0
		shown = 99999.0 if speed <= 0.0 else shown + delta * speed
		text_label.visible_characters = mini(total, int(shown))
		if text_label.visible_characters - _last_blip >= 4:
			_last_blip = text_label.visible_characters
			if speaker != "":
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
	# Handle the original pointer only: emulated mouse/touch copies must never confirm a second page.
	if ev.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var click: bool = ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT
	var tap: bool = ev is InputEventScreenTouch and ev.pressed and ev.index == 0
	if click or tap:
		if not UI.touch_blocks(ev.position):
			_advance()
			accept_event()
