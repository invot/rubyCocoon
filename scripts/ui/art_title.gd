extends Control
const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Slideshow = preload("res://scripts/ui/art_slideshow.gd")
const Edition = preload("res://scripts/core/build_edition.gd")
const Plaque = preload("res://scripts/ui/title_plaque.gd")
var slideshow: Control
## the game's name on its carved stone plaque at the top centre (title_plaque.gd), this screen's own top HUD; Load
## Game and the character creator hide it
var logo: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	slideshow = Slideshow.new()
	add_child(slideshow)
	logo = Plaque.new()
	logo.demo = Edition.is_demo()
	add_child(logo)
