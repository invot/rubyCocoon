extends Control
## An animated value bar (HP / XP). Tall bars use the bronze set1 frame; slim ones a plain pixel border.

const UIKit = preload("res://scripts/ui/ui_kit.gd")

var ratio := 1.0
var shown := 1.0
var fixed_color := Color(0, 0, 0, 0)
var text := ""
var _frame: StyleBoxTexture


func _init(min_size := Vector2(160, 10)) -> void:
	custom_minimum_size = min_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_ratio(r: float, instant := false) -> void:
	ratio = clampf(r, 0.0, 1.0)
	if instant:
		shown = ratio
	queue_redraw()


func _process(delta: float) -> void:
	if absf(shown - ratio) > 0.001:
		shown = move_toward(shown, ratio, delta * 1.2)
		queue_redraw()


func _draw() -> void:
	var col := fixed_color if fixed_color.a > 0 else UIKit.hp_color(shown)
	var r := Rect2(Vector2.ZERO, size)
	var inner: Rect2
	if size.y >= 24:
		if _frame == null:
			_frame = UIKit.box("bar_frame")
		draw_style_box(_frame, r)
		inner = r.grow_individual(-9, -9, -9, -9)
		draw_rect(inner, Color("#2a1c1c"))
	else:
		draw_rect(r, Color("#493333"))
		inner = r.grow(-2)
		draw_rect(inner, Color("#2a1c1c"))
	var w := floorf(inner.size.x * shown / 3.0) * 3.0
	if w <= 0.0:
		return
	var fill := Rect2(inner.position, Vector2(w, inner.size.y))
	draw_rect(fill, col)
	var band := maxf(2.0, floorf(inner.size.y / 3.0))
	draw_rect(Rect2(fill.position, Vector2(w, band)), col.lightened(0.3))
	draw_rect(Rect2(fill.position + Vector2(0, inner.size.y - band), Vector2(w, band)), col.darkened(0.25))
	if text != "":
		draw_string(UIKit.font_body(), Vector2(6, size.y - 6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.body_px(UIKit.BODY_SMALL), UIKit.LIGHT)
