extends "res://scripts/ui/modal.gd"
## Pause screen: freezes the game until Pause (or A / B / Start) is pressed again.

const UIKit = preload("res://scripts/ui/ui_kit.gd")

var _was_paused := false
var _t := 0.0
var _hint: Label


func _init() -> void:
	super._init()
	dim = 0.5


func _ready() -> void:
	_was_paused = get_tree().paused
	get_tree().paused = true
	Sfx.play("open")
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	add_child(vb)
	var rib := UIKit.ribbon("PAUSED")
	rib.custom_minimum_size.x = 420
	vb.add_child(rib)
	var card := UIKit.banner_panel(Vector2(420, 0))
	_hint = UIKit.label("Press Pause again to keep playing.", 20)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(_hint)
	vb.add_child(card)
	UIKit.place(vb, "center")


func _process(delta: float) -> void:
	_t += delta
	_hint.modulate.a = 0.6 + 0.4 * absf(sin(_t * 2.5))


func on_input(ev: InputEvent) -> void:
	if ev.is_echo() or not ev.is_pressed():
		return
	if ev.is_action_pressed("pause") or ev.is_action_pressed("menu") or ev.is_action_pressed("ui_accept") or ev.is_action_pressed("ui_cancel"):
		get_tree().paused = _was_paused
		Sfx.play("back")
		close()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		get_tree().paused = _was_paused
		close()
