extends "res://scripts/ui/modal.gd"
## A short system decision, with no speech or camera change.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const EdgeButton = preload("res://scripts/ui/edge_button.gd")

var question := ""
var anchor_control: Control
var panel: PanelContainer
var confirm: Control
var cancel: Control
var _armed := false


func _ready() -> void:
	panel = UIKit.panel()
	add_child(panel)
	var label := UIKit.label(question, 32, UIKit.INK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	confirm = EdgeButton.new().setup("A: Confirm")
	cancel = EdgeButton.new().setup("B: Cancel")
	add_child(confirm)
	add_child(cancel)
	confirm.pressed.connect(_answer.bind(true))
	cancel.pressed.connect(_answer.bind(false))
	# Let the input which opened this screen finish before accepting another.
	await get_tree().process_frame
	_armed = true


func _process(_delta: float) -> void:
	var safe := UIKit.safe_rect(self)
	panel.size = Vector2(minf(640.0, safe.size.x - 48.0), 120.0)
	panel.position = Vector2(safe.get_center().x - panel.size.x / 2.0, safe.position.y + 24.0).round()
	if is_instance_valid(anchor_control):
		var under := anchor_control.get_global_rect()
		panel.size.x = minf(panel.size.x, under.size.x)
		panel.global_position = under.position.round()
	var width: float = confirm.button_size().x + cancel.button_size().x + 24.0
	var left := panel.get_global_rect().get_center().x - width / 2.0
	confirm.place_at(panel.get_global_rect(), left)
	cancel.place_at(panel.get_global_rect(), left + confirm.button_size().x + 24.0)


func on_input(ev: InputEvent) -> void:
	if not _armed or ev.is_echo() or not ev.is_pressed():
		return
	if ev.is_action_pressed("ui_cancel"):
		_answer(false)
	elif ev.is_action_pressed("ui_accept") or ev.is_action_pressed("interact"):
		_answer(true)


func _answer(accepted: bool) -> void:
	if not _armed or closed:
		return
	Sfx.play("confirm" if accepted else "back")
	close(accepted)
