extends StyleBox
## The divider from Kenney's Fantasy UI Borders (frame_box.gd), tinted: separates a window's sections and flanks
## banner text.

const FrameBox = preload("res://scripts/ui/frame_box.gd")

var line := Color.WHITE
## which ends carry the ornament
var left_end := true
var right_end := true


func _draw(ci: RID, rect: Rect2) -> void:
	if rect.size.x > 0.0:
		FrameBox.draw_divider(ci, rect, line, left_end, right_end)


func _get_minimum_size() -> Vector2:
	return Vector2(0, FrameBox.divider_height())
