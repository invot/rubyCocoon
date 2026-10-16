extends "res://scripts/ui/modal.gd"
## Single-line text prompt.

const UIKit = preload("res://scripts/ui/ui_kit.gd")

var prompt := ""
var default_text := ""
var edit: LineEdit


func setup(_prompt: String, _default := "") -> Control:
	prompt = _prompt
	default_text = _default
	dim = 0.4
	return self


func _ready() -> void:
	var p := UIKit.panel(Vector2(460, 0))
	add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	p.add_child(vb)
	vb.add_child(UIKit.label(prompt, 22, UIKit.GOLD))
	edit = LineEdit.new()
	edit.text = default_text
	edit.max_length = 14
	edit.select_all_on_focus = true
	edit.text_submitted.connect(func(_t): _submit())
	vb.add_child(edit)
	var ok := Button.new()
	ok.text = "OK"
	ok.pressed.connect(_submit)
	vb.add_child(ok)
	UIKit.place(p, "center")
	edit.grab_focus.call_deferred()


func _submit() -> void:
	Sfx.play("select")
	close(edit.text.strip_edges())
