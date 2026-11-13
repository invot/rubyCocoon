extends StyleBox
## A divider between a window's sections (and flanking banner text): one thin, round-ended line in `line`'s colour.
## (The ornamental Kenney divider went with the borders, the user's 2026-11-13 direction; the ends' flags are kept for
## callers but no longer draw anything different.)

const FrameBox = preload("res://scripts/ui/frame_box.gd")

var line := Color.WHITE
## which ends carried the ornament (ignored now)
var left_end := true
var right_end := true


func _draw(ci: RID, rect: Rect2) -> void:
	if rect.size.x <= 0.0:
		return
	var w := maxf(1.0, FrameBox.unit)
	var y := rect.position.y + rect.size.y / 2.0
	var a := Vector2(rect.position.x + w, y)
	var b := Vector2(rect.end.x - w, y)
	if b.x > a.x:
		RenderingServer.canvas_item_add_line(ci, a, b, line, w, true)


func _get_minimum_size() -> Vector2:
	return Vector2(0, FrameBox.divider_height())
