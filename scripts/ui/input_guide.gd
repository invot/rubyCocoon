extends HBoxContainer
## Fixed input mappings. Only Controller mode adds a Controllercons duotone illustration.
const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Layout = preload("res://scripts/core/controller_layout.gd")
var input_mode := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 20)
	rebuild()


func rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var mode := input_mode if input_mode != "" else Prefs.effective_input()
	var profile := Layout.describe(Controllers.layout)
	var keys := VBoxContainer.new()
	keys.alignment = BoxContainer.ALIGNMENT_CENTER
	keys.add_theme_constant_override("separation", 8)
	add_child(keys)
	var lines := ["← ↑ ↓ →: Move", "A / Enter: Action / confirm", "S / Esc: Back · hold S to run", "Space: Book", "Shift: Pause", "Flute: Arrows + A / S"]
	if mode == "screen":
		lines = ["D-pad: Move", "A: Action / confirm", "B: Back · hold to run", "Start: Book", "Pause: Pause / stop song", "Flute: D-pad + A / B"]
	elif mode == "controller":
		lines = ["D-pad / stick: Move", "%s: Action / confirm" % profile.accept,
			"%s: Back / run" % profile.back, "%s: Book" % profile.start, "%s: Pause" % profile.pause,
			"Flute: D-pad +\n%s / %s" % [profile.accept, profile.back]]
	_add_keys(keys, lines)
	if mode != "controller":
		return
	var art := VBoxContainer.new()
	art.name = "ControllerArt"
	art.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(art)
	var title := UIKit.header(profile.name, UIKit.HEAD, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	art.add_child(title)
	var image := TextureRect.new()
	image.texture = load("res://assets/ui/controllers/%s.svg" % Controllers.layout)
	image.custom_minimum_size = Vector2(160, 180)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(image)


func _add_keys(keys: VBoxContainer, lines: Array) -> void:
	for text in lines:
		var label := UIKit.label(text, 32, UIKit.LIGHT)
		label.add_theme_font_size_override("font_size", UIKit.body_px(32))
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		label.add_theme_constant_override("shadow_offset_y", 2)
		label.add_theme_constant_override("outline_size", 3)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		keys.add_child(label)
