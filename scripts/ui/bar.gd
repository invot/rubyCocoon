extends Control
## An animated value bar (HP / MP / XP): a rounded, pale-edged dark trough holding a rounded fill in a shade of the
## gem (or `fixed_color`), with a soft lighter band along the top of the fill.

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


static func _rounded(col: Color, radius: float, edge := Color(0, 0, 0, 0), edge_w := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(radius))
	sb.corner_detail = 6
	sb.anti_aliasing = true
	if edge_w > 0:
		sb.border_color = edge
		sb.set_border_width_all(edge_w)
	return sb


func _draw() -> void:
	var col := fixed_color if fixed_color.a > 0 else UIKit.hp_color(shown)
	_draw_bar(col)


## A dark trough edged in the gem, its corners nicked, and a square fill inside, in steps of whole pixels.
func _draw_bar(col: Color) -> void:
	var u := 2.0 if size.y >= 8.0 else 1.0
	var r := Rect2(Vector2.ZERO, size)
	var line := UIKit.BORDER
	draw_rect(r.grow(-u), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(u, 0, r.size.x - 2.0 * u, u), line)
	draw_rect(Rect2(u, r.size.y - u, r.size.x - 2.0 * u, u), line)
	draw_rect(Rect2(0, u, u, r.size.y - 2.0 * u), line)
	draw_rect(Rect2(r.size.x - u, u, u, r.size.y - 2.0 * u), line)
	var inner := r.grow(-2.0 * u) if r.size.y > 4.0 * u else r.grow(-u)
	var w := floorf(inner.size.x * shown / u) * u
	if w > 0.0:
		draw_rect(Rect2(inner.position, Vector2(w, inner.size.y)), col)
	_draw_text()


func _draw_text() -> void:
	if text != "":
		var fs := UIKit.body_px(UIKit.BODY_SMALL)
		var font := UIKit.font_body()
		var y := (size.y + font.get_ascent(fs) - font.get_descent(fs)) / 2.0
		# white letters edged in dark, readable on the fill and the dark trough alike
		draw_string_outline(font, Vector2(10, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0.03, 0.03, 0.05, 0.8))
		draw_string(font, Vector2(10, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIKit.LIGHT)
