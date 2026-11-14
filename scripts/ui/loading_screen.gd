extends Control
## Progress reports completed construction phases, never a timer pretending to measure loading.
const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Slideshow = preload("res://scripts/ui/art_slideshow.gd")
const CAPTION_SECONDS := 5.0
const DOT_SECONDS := 0.5
var slideshow: Control
var panel: PanelContainer
var caption: Label
var progress: ProgressBar
var destination: Label
var _caption_index := 0
var _caption_clock := 0.0
var _dot_clock := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UIKit.make_theme()
	slideshow = Slideshow.new()
	slideshow.index = randi() % Slideshow.library().slides.size()
	add_child(slideshow)
	panel = UIKit.panel()
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	destination = UIKit.header("", UIKit.HEAD, 32)
	destination.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(destination)
	caption = UIKit.label("", 28)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(caption)
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 24
	progress.show_percentage = false
	progress.max_value = 1.0
	progress.add_theme_stylebox_override("background", UIKit.chip(UIKit.WELL, Color.TRANSPARENT))
	progress.add_theme_stylebox_override("fill", UIKit.solid())
	column.add_child(progress)
	_caption_index = randi() % Slideshow.library().captions.size()
	_set_caption()
	resized.connect(_layout)
	_layout.call_deferred()

func _layout() -> void:
	var safe := UIKit.safe_rect(self).grow(-24.0)
	panel.size.x = minf(720.0, safe.size.x)
	panel.position = Vector2(safe.get_center().x - panel.size.x * 0.5, safe.end.y - panel.size.y - 24.0)

func set_progress(value: float) -> void:
	progress.value = maxf(progress.value, clampf(value, 0.0, 1.0))

func _process(delta: float) -> void:
	_caption_clock += delta
	_dot_clock = fmod(_dot_clock + delta, DOT_SECONDS * 4.0)
	if _caption_clock >= CAPTION_SECONDS:
		_caption_clock = fmod(_caption_clock, CAPTION_SECONDS)
		_caption_index = (_caption_index + 1) % Slideshow.library().captions.size()
		_set_caption()
	# Hidden trailing characters still reserve their width, so the centered text never wiggles.
	caption.visible_characters = caption.text.length() - 3 + int(_dot_clock / DOT_SECONDS)
	_layout()

func _set_caption() -> void:
	caption.text = String(Slideshow.library().captions[_caption_index]).trim_suffix("...") + "..."
	_dot_clock = 0.0
	caption.visible_characters = caption.text.length() - 3

func _input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
