extends "res://scripts/ui/dialog_box.gd"
## The normal dialogue window, with the film owning the beat instead of the modal stack.
signal advance_requested
var instant_text := false


func _ready() -> void:
	super()
	# Only the actual window takes taps; the film's Skip / Next buttons remain reachable above it.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in get_children():
		if child is PanelContainer:
			child.gui_input.connect(_panel_input)
			child.minimum_size_changed.connect(_queue_fit)
	text_label.minimum_size_changed.connect(_queue_fit)


func _show_line() -> void:
	super()
	if instant_text:
		text_label.visible_characters = -1
		shown = 99999.0


func _paginate() -> void:
	await super()
	_queue_fit()


func _queue_fit() -> void:
	_fit_window.call_deferred()


func _fit_window() -> void:
	# Fit the inherited window to its actual font/padding minimum after wrapping. Resizing or a different
	# screen scale can otherwise leave a three-line Label taller than the dialogue's nominal box.
	for child in get_children():
		if child is PanelContainer and child != name_panel:
			_box_h = maxf(_box_h, child.get_combined_minimum_size().y)
			child.offset_top = -12.0 - _box_h - _bottom_gap()
	if name_panel != null:
		name_panel.offset_top = -12.0 - _box_h - 46.0 - _bottom_gap()
		name_panel.offset_bottom = -12.0 - _box_h + 6.0 - _bottom_gap()


func _advance() -> void:
	if not _paged:
		return
	if text_label.visible_characters != -1 and text_label.visible_characters < text_label.get_total_character_count():
		text_label.visible_characters = -1
		shown = 99999.0
	elif idx + 1 < lines.size():
		idx += 1
		_show_line()
	else:
		advance_requested.emit()


func _panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
		accept_event()


func _gui_input(_event: InputEvent) -> void:
	pass
