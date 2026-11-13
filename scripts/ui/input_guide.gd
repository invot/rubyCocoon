extends HBoxContainer
## Fixed input mappings. Only Controller mode adds a Controllercons duotone illustration.
const UIKit = preload("res://scripts/ui/ui_kit.gd")
var input_mode := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 20)
	Prefs.changed.connect(rebuild)
	Controllers.changed.connect(rebuild)
	rebuild()


func rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var mode := input_mode if input_mode != "" else Prefs.effective_input()
	if mode == "controller":
		var art: Control = load("res://scripts/ui/controller_diagram.gd").new()
		art.name = "ControllerArt"
		add_child(art)
		return
	var keys := VBoxContainer.new()
	keys.alignment = BoxContainer.ALIGNMENT_CENTER
	keys.add_theme_constant_override("separation", 8)
	add_child(keys)
	var lines := ["◄ ▲ ▼ ►: Move", "A / Enter: Action / confirm", "S / Esc: Back · hold S to run", "Space: Book", "Shift: Pause"]
	if mode == "screen":
		lines = ["D-pad: Move", "A: Action / confirm", "B: Back · hold to run", "Start: Book", "Pause: Pause"]
	_add_keys(keys, lines)


func _add_keys(keys: VBoxContainer, lines: Array) -> void:
	for text in lines:
		var label := UIKit.label(text, 32, UIKit.INK)
		label.add_theme_font_size_override("font_size", UIKit.body_px(32))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		keys.add_child(label)
