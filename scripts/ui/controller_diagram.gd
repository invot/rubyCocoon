extends Control
## Read-only callouts around the supplied controller art. Button positions share its 64-unit viewBox.
const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Layout = preload("res://scripts/core/controller_layout.gd")
const HEIGHT := 460.0
var layout_id := ""
var _texture: Texture2D
var _labels := {}
var _image_rect := Rect2()
var _points := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	custom_minimum_size.y = HEIGHT
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if layout_id == "":
		layout_id = Controllers.layout
	_texture = load("res://assets/ui/controllers/%s.svg" % layout_id)
	_points = Layout.button_points(layout_id)
	var profile := Layout.describe(layout_id)
	for entry in [["move", "Move\nD-pad / stick"], ["pause", "Pause\n" + profile.pause],
		["start", "Book\n" + profile.start], ["accept", "Action / confirm\n" + profile.accept],
		["back", "Back / run\n" + profile.back]]:
		var label := UIKit.label(entry[1], 32, UIKit.LIGHT)
		label.add_theme_font_size_override("font_size", UIKit.body_px(32))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		label.add_theme_constant_override("shadow_offset_y", 2)
		add_child(label)
		_labels[entry[0]] = label
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	if _labels.is_empty():
		return
	var w := size.x
	var side := minf(360.0, w - 32.0)
	_image_rect = Rect2(Vector2((w - side) / 2.0, (HEIGHT - side) / 2.0), Vector2.ONE * side)
	for entry in [["move", 0.0, 0.36, 0.0], ["pause", 0.38, 0.26, 0.0],
		["start", 0.68, 0.32, 0.0], ["accept", 0.0, 0.5, HEIGHT - 78.0],
		["back", 0.5, 0.5, HEIGHT - 78.0]]:
		var label: Label = _labels[entry[0]]
		label.position = Vector2(w * entry[1], entry[3])
		label.size = Vector2(w * entry[2], 76.0)
	queue_redraw()


func _anchor(button: String) -> Vector2:
	return _image_rect.position + (_points[button] as Vector2) / 64.0 * _image_rect.size


func _label_edge(id: String, bottom: bool) -> Vector2:
	var label: Label = _labels[id]
	return label.position + Vector2(label.size.x / 2.0, label.size.y if bottom else 0.0)


func _draw() -> void:
	if _texture == null or _labels.is_empty():
		return
	draw_texture_rect(_texture, _image_rect, false)
	# Move has two endpoints: the d-pad and left stick. Its branch stays outside the left grip.
	var move := _label_edge("move", true)
	var left := _image_rect.position.x - 8.0
	for button in ["dpad", "stick"]:
		var point := _anchor(button)
		_leader([move, Vector2(move.x, 92.0), Vector2(left, 92.0), Vector2(left, point.y), point])
	for button in ["pause", "start"]:
		var from := _label_edge(button, true)
		var point := _anchor(button)
		_leader([from, Vector2(from.x, 94.0), Vector2(point.x, 94.0), point])
	var accept := _anchor("accept")
	var below := _label_edge("accept", false)
	_leader([accept, Vector2(accept.x, HEIGHT - 112.0), Vector2(below.x, HEIGHT - 112.0), below])
	var back := _anchor("back")
	var back_label := _label_edge("back", false)
	var right := _image_rect.end.x + 8.0
	_leader([back, Vector2(right, back.y), Vector2(right, HEIGHT - 96.0), Vector2(back_label.x, HEIGHT - 96.0), back_label])


func _leader(path: PackedVector2Array) -> void:
	draw_polyline(path, Color(0, 0, 0, 0.8), 5.0, true)
	draw_polyline(path, UIKit.LIGHT, 2.0, true)
	# A small dot marks the exact button; lines can be read without relying on colour.
	var point := path[0] if path[0].y > 100.0 else path[-1]
	draw_circle(point, 5.0, Color(0, 0, 0, 0.8), true, -1.0, true)
	draw_circle(point, 3.0, UIKit.LIGHT, true, -1.0, true)
