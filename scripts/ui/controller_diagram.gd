extends Control
## Read-only callouts around the supplied controller art. Button positions share its 64-unit viewBox. Each callout
## says what the button does over Kenney's icon for it (controller_layout.gd prompt_icons): outlined in near-black,
## and filled in the gem while it is held.
const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Layout = preload("res://scripts/core/controller_layout.gd")
const HEIGHT := 460.0
var layout_id := ""
var _texture: Texture2D
var _labels := {}
var _image_rect := Rect2()
var _points := {}
## each callout's icon: {rect, base, rest, action, shown}
var _icons := {}
const ICON := 40.0
const PROMPTS := "res://assets/ui/input_prompts/"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	custom_minimum_size.y = HEIGHT
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if layout_id == "":
		layout_id = Controllers.layout
	_texture = load("res://assets/ui/controllers/%s.svg" % layout_id)
	_points = Layout.button_points(layout_id)
	var icons := Layout.prompt_icons(layout_id)
	for entry in [["move", "Move", "dpad", ""], ["pause", "Pause", "pause", "pause"], ["start", "Book", "start", "menu"],
		["accept", "Action / confirm", "accept", "ui_accept"], ["back", "Back / run", "back", "ui_cancel"]]:
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 0)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := UIKit.label(entry[1], 32, UIKit.INK)
		label.add_theme_font_size_override("font_size", UIKit.body_px(32))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(label)
		var name: String = icons[entry[2]]
		var rest: String = name + ("_none" if entry[0] == "move" else "_outline")
		var icon := TextureRect.new()
		icon.texture = load(PROMPTS + rest + ".svg")
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon.custom_minimum_size = Vector2(ICON, ICON)
		icon.self_modulate = UIKit.INK
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
		add_child(box)
		_labels[entry[0]] = box
		_icons[entry[0]] = {"rect": icon, "base": name, "rest": rest, "action": entry[3], "shown": rest}
	resized.connect(_layout)
	_layout()


## Lights the icon of whatever is held: the button filled in the gem, or the d-pad with the held way's arm filled.
func _process(_delta: float) -> void:
	for id in _icons:
		var e: Dictionary = _icons[id]
		var name: String = e["rest"]
		if id == "move":
			var way := _held_way()
			if way != "":
				name = e["base"] + "_" + way + "_outline"
		elif Input.is_action_pressed(e["action"]):
			name = e["base"]
		if name != e["shown"]:
			e["shown"] = name
			var r: TextureRect = e["rect"]
			r.texture = load(PROMPTS + name + ".svg")
			r.self_modulate = UIKit.INK if name == e["rest"] else UIKit.ACCENT


static func _held_way() -> String:
	for way in ["up", "down", "left", "right"]:
		if Input.is_action_pressed("move_" + way) or Input.is_action_pressed("ui_" + way):
			return way
	return ""


func _layout() -> void:
	if _labels.is_empty():
		return
	var w := size.x
	var side := minf(360.0, w - 32.0)
	_image_rect = Rect2(Vector2((w - side) / 2.0, (HEIGHT - side) / 2.0), Vector2.ONE * side)
	for entry in [["move", 0.0, 0.36, 0.0], ["pause", 0.38, 0.26, 0.0],
		["start", 0.68, 0.32, 0.0], ["accept", 0.0, 0.5, HEIGHT - 78.0],
		["back", 0.5, 0.5, HEIGHT - 78.0]]:
		var label: Control = _labels[entry[0]]
		label.position = Vector2(w * entry[1], entry[3])
		label.size = Vector2(w * entry[2], 76.0)
	queue_redraw()


func _anchor(button: String) -> Vector2:
	return _image_rect.position + (_points[button] as Vector2) / 64.0 * _image_rect.size


func _label_edge(id: String, bottom: bool) -> Vector2:
	var label: Control = _labels[id]
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
	_leader([accept, Vector2(accept.x, HEIGHT - 112.0), Vector2(below.x, HEIGHT - 112.0), below], true)
	var back := _anchor("back")
	var back_label := _label_edge("back", false)
	var right := _image_rect.end.x + 8.0
	_leader([back, Vector2(right, back.y), Vector2(right, HEIGHT - 96.0), Vector2(back_label.x, HEIGHT - 96.0), back_label], true)


func _leader(path: PackedVector2Array, button_at_start := false) -> void:
	draw_polyline(path, UIKit.INK, 2.0, true)
	# A small dot marks the exact button; lines can be read without relying on colour.
	var point := path[0] if button_at_start else path[-1]
	draw_circle(point, 5.0, UIKit.ACCENT, true, -1.0, true)
