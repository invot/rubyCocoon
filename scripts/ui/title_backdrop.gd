extends Control
## The start menu has no 3D scene or entrance animation. Keep the world viewport asleep until play begins.
const UIKit = preload("res://scripts/ui/ui_kit.gd")
var logo: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := ColorRect.new()
	background.color = UIKit.WINDOW_BOTTOM
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	logo = UIKit.header("RUBY COCOON", UIKit.GOLD, 96)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)
	logo.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	logo.anchor_top = 0.16
	logo.anchor_bottom = 0.16
	logo.offset_bottom = 120
