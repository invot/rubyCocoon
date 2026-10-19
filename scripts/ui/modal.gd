extends Control
## Base class for UI screens pushed on the UI stack. Blocks input to things below it.

signal done(result)

var prev_focus = null
var result = null
var closed := false
var dim := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _draw() -> void:
	if dim > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, dim))


## Called by the UI manager with input that GUI controls didn't consume.
func on_input(_ev: InputEvent) -> void:
	pass


func close(r = null) -> void:
	if closed:
		return
	closed = true
	result = r
	UI.pop(self)
	done.emit(r)
