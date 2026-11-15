extends Control
## "Hold B: Skip lesson": a small gem button beside the Codex's head while it runs a lesson in battle (codex.gd
## begin_lesson). Holding B (Esc on a keyboard) for SKIP_HOLD seconds skips the lesson, a thin white bar filling under
## the words as you hold; a tap of B still turns the Codex's page. A click or tap on the button skips at once.

signal skip

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const EdgeButton = preload("res://scripts/ui/edge_button.gd")
## Held this long, B skips (the films' hold, opening.gd SKIP_HOLD).
const SKIP_HOLD := 1.0
## Shorter than this is a tap (it turns the page), and the bar doesn't show yet.
const TAP := 0.2
const GAP := 12.0

var button: Control
var _meter: ColorRect
var _hold := -1.0
var _keys := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	button = EdgeButton.new()
	add_child(button)
	button.setup(_text())
	button.pressed.connect(func() -> void: skip.emit())
	_meter = ColorRect.new()
	_meter.color = Color(1, 1, 1, 0.9)
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.button.add_child(_meter)
	_meter.visible = false


func _text() -> String:
	_keys = not UI.is_touch() and not UI.controls.controller_guide()
	return "Hold Esc: Skip lesson" if _keys else "Hold B: Skip lesson"


## Beside `head` (the Codex's head, global rect), centred on it.
func place_beside(head: Rect2) -> void:
	var keys: bool = not UI.is_touch() and not UI.controls.controller_guide()
	if keys != _keys:
		button.button.text = _text()
	var s: Vector2 = button.button_size()
	var pad: float = button._pad()
	var at := Vector2(head.end.x + GAP, head.get_center().y - s.y / 2.0)
	button.button.custom_minimum_size = s
	button.button.size = s
	button.button.position = Vector2(pad, pad)
	button.size = s + Vector2(pad, pad) * 2.0
	button.global_position = (at - Vector2(pad, pad)).round()


func _process(delta: float) -> void:
	if not visible:
		_hold = -1.0
		return
	if Input.is_action_pressed("ui_cancel"):
		_hold = maxf(_hold, 0.0) + delta
		if _hold >= SKIP_HOLD:
			_hold = -1.0
			skip.emit()
	else:
		_hold = -1.0
	var s: Vector2 = button.button.size
	_meter.visible = _hold >= TAP
	_meter.position = Vector2(14.0, s.y - 8.0)
	_meter.size = Vector2((s.x - 28.0) * clampf((_hold - TAP) / (SKIP_HOLD - TAP), 0.0, 1.0), 3.0)
