extends "res://scripts/ui/dialog_box.gd"
## A film's dialogue, with the film owning the beat instead of the modal stack. Spoken lines use the game's white
## speech bubble, anchored to whoever speaks (a voice from off screen gets the stationary bottom-centre bubble);
## narration, with no speaker, uses the shared dark window. A tap anywhere on it turns the page, as in the game.
signal advance_requested
var instant_text := false
## the dark window, when this is narration
var _window: PanelContainer


func _ready() -> void:
	super()
	if bubble_mode:
		return
	for child in get_children():
		if child is PanelContainer:
			_window = child
			child.minimum_size_changed.connect(_queue_fit)
	text_label.minimum_size_changed.connect(_queue_fit)
	if UI.is_touch():
		# Only A and B show in a film: the window runs along the bottom from the left edge up to them.
		var zone: Rect2 = UI.controls.cluster_zone(["a", "b"], UI.controls.TOUCH_SLOP + 12.0)
		_window.offset_left = UIKit.safe_rect(self).position.x + 48.0
		_window.offset_right = -(get_viewport_rect().size.x - zone.position.x) if zone.has_area() else -48.0
		_fit_window()


## Nothing sits along the bottom edge in a film on a phone (no Start or Pause), so its dialogue goes right down.
func _bottom_gap() -> float:
	return 0.0 if UI.is_touch() else super()


func _place_more(bob: float) -> void:
	if bubble_mode or _window == null:
		super(bob)
	else:
		more.position = _window.position + _window.size - Vector2(64, 44 - bob)


func _show_line() -> void:
	super()
	if instant_text:
		text_label.visible_characters = -1
		shown = 99999.0


func _paginate() -> void:
	await super()
	_queue_fit()


func _queue_fit() -> void:
	if not bubble_mode:
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
