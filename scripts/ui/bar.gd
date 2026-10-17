extends Control
## An animated value bar (HP / MP / XP): a white-edged black trough filled with the accent (or `fixed_color`), with a
## lighter top line and a darker bottom line on the fill.

const UIKit = preload("res://scripts/ui/ui_kit.gd")

var ratio := 1.0
var shown := 1.0
var fixed_color := Color(0, 0, 0, 0)
var text := ""


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
	var edge := 2.0 if size.y >= 10 else 1.0
	draw_rect(r, UIKit.BORDER)
	var inner := r.grow(-edge)
	draw_rect(inner, Color("#0a0a0e"))
	inner = inner.grow(-1.0) if size.y >= 14 else inner
	var w := floorf(inner.size.x * shown / 2.0) * 2.0
	if w > 0.0:
		var fill := Rect2(inner.position, Vector2(w, inner.size.y))
		draw_rect(fill, col)
		var band := maxf(1.0, floorf(inner.size.y / 4.0))
		draw_rect(Rect2(fill.position, Vector2(w, band)), col.lerp(Color.WHITE, 0.35))
		draw_rect(Rect2(fill.position + Vector2(0, inner.size.y - band), Vector2(w, band)), col.darkened(0.3))
	if text != "":
		draw_string(UIKit.font_body(), Vector2(6, size.y - 6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.body_px(UIKit.BODY_SMALL), UIKit.LIGHT)
