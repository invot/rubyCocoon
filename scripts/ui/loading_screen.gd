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
	# a bar along the bottom: the destination and a playful status above a thin gem progress bar
	panel = UIKit.panel()
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 24)
	column.add_child(line)
	destination = UIKit.header("", UIKit.HEAD, 32)
	destination.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(destination)
	caption = UIKit.label("", 28)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.clip_text = true
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# hide the dots after laying the line out, so a missing dot leaves its space and the text never shifts
	caption.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	line.add_child(caption)
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 16
	progress.show_percentage = false
	progress.max_value = 1.0
	progress.add_theme_stylebox_override("background", UIKit.chip(UIKit.WELL, Color.TRANSPARENT, 10.0, Vector4.ZERO))
	progress.add_theme_stylebox_override("fill", UIKit.solid(Vector4.ZERO))
	column.add_child(progress)
	_caption_index = randi() % Slideshow.library().captions.size()
	_set_caption()
	resized.connect(_layout)
	_layout.call_deferred()

func _layout() -> void:
	var safe := UIKit.safe_rect(self).grow(-24.0)
	# (shrink to the content's height each time: a container only ever grows on its own)
	panel.size = Vector2(minf(1200.0, safe.size.x), 0.0)
	panel.position = Vector2(safe.get_center().x - panel.size.x * 0.5, safe.end.y - panel.size.y)

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
