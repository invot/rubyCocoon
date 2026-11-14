extends Control
## The Start book's open pages (book_menu.gd), drawn behind its window in place of the off-white box: light tan
## paper with a faint painted grain (assets/ui/book/paper_grain.png, baked by tools/book_paper/build.py), a soft
## spine down the fold between the two pages, gently darker page edges, and the windows' soft shadow and bezel. The
## gem tints it faintly, as it does every window (UIKit.book_paper). This is the one window that is not the
## off-white (the user's 2026-11-13 direction).

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const FrameBox = preload("res://scripts/ui/frame_box.gd")
const GRAIN = preload("res://assets/ui/book/paper_grain.png")
const SHADER = preload("res://scripts/ui/book_paper.gdshader")
const RADIUS := 12.0

## the fold's x in this control's units (book_menu.gd sets it from its pages' divider); < 0: none (the storage
## screen still has two pages, so it has one too)
var spine_x := -1.0
var _shadow: StyleBoxFlat
var _sheet: Control
var _bezel: Control
var _mat: ShaderMaterial


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadow = StyleBoxFlat.new()
	_shadow.anti_aliasing = true
	_shadow.corner_detail = 6
	_shadow.set_corner_radius_all(int(RADIUS))
	_shadow.shadow_color = FrameBox.SHADOW
	_shadow.shadow_size = 10
	_shadow.shadow_offset = Vector2(0, 3)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("grain", GRAIN)
	_mat.set_shader_parameter("radius", RADIUS)
	_sheet = Control.new()
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.material = _mat
	_sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet.draw.connect(func(): _sheet.draw_rect(Rect2(Vector2.ZERO, _sheet.size), Color.WHITE))
	add_child(_sheet)
	_bezel = Control.new()
	_bezel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bezel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bezel.draw.connect(func(): FrameBox.draw_bezel(_bezel.get_canvas_item(), Rect2(Vector2.ZERO, _bezel.size),
		Vector4(RADIUS, RADIUS, RADIUS, RADIUS), 1.0, true, UIKit.book_paper()))
	add_child(_bezel)
	resized.connect(refresh)


## Redraws in the current gem and size.
func refresh() -> void:
	var col := UIKit.book_paper()
	_shadow.bg_color = col
	_mat.set_shader_parameter("paper_color", col)
	_mat.set_shader_parameter("sheet_size", size)
	_mat.set_shader_parameter("spine_x", spine_x if spine_x >= 0.0 else -10000.0)
	queue_redraw()
	_sheet.queue_redraw()
	_bezel.queue_redraw()


func _draw() -> void:
	# (the shadow, with the paper's colour under the sheet so its rounded edge never shows a seam)
	_shadow.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
