extends Control
## A small diagram of a trainer's battle ring (see ring.gd): eight cells round the trainer, each with the icon of the
## beast standing there (dimmed if it has fainted), the four sides marked with their element's initial, and the side
## facing the foe outlined in the gem colour. `facing` turns the diagram so that side points at the foe (0 = up,
## PI / 2 = right...). All in the shades of the UI gem.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Ring = preload("res://scripts/core/ring.gd")
const PixelArt = preload("res://scripts/gfx/pixel_art.gd")

## {slot: beast}
var ring: Dictionary = {}
## the side facing the foe (-1: none, as in the book)
var active_side := -1
## where the active side points on screen (radians; 0 = up)
var facing := 0.0
## shown in the middle: the trainer's shield points, as filled / empty pips
var shield := -1
var max_shield := 0
## a slot to ring (the book's cursor), or -1
var highlight := -1


func _init(px := 150.0) -> void:
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_ring(r: Dictionary, side := -1) -> void:
	ring = r
	active_side = side
	queue_redraw()


## Where slot k's cell sits (its centre), with the active side's middle at `facing`.
func cell_center(k: int) -> Vector2:
	var c := size / 2.0
	var rad := minf(size.x, size.y) * 0.36
	var base := facing if active_side >= 0 else 0.0
	var mid := active_side * 2 if active_side >= 0 else 0
	var a := base + float(k - mid) * TAU / 8.0
	return c + Vector2(sin(a), -cos(a)) * rad


func _draw() -> void:
	var c := size / 2.0
	var rad := minf(size.x, size.y) * 0.36
	var cell := minf(size.x, size.y) * 0.22
	# the ring itself
	draw_arc(c, rad, 0, TAU, 48, Color(UIKit.BORDER, 0.35), 2.0, true)
	draw_arc(c, rad * 0.45, 0, TAU, 32, Color(UIKit.BORDER, 0.25), 1.5, true)
	var font := UIKit.font_body()
	var fs := UIKit.body_px(20)
	for k in Ring.SLOTS:
		var p := cell_center(k)
		var r := Rect2(p - Vector2(cell, cell) / 2.0, Vector2(cell, cell))
		var on_side := active_side >= 0 and k in Ring.side_slots(active_side)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(UIKit.WINDOW_TOP, 0.9) if not on_side else Color(UIKit.ACCENT.darkened(0.35), 0.95)
		sb.border_color = UIKit.ACCENT.lightened(0.25) if on_side else Color(UIKit.BORDER, 0.45)
		if k == highlight:
			sb.border_color = UIKit.LIGHT
		sb.set_border_width_all(3 if on_side or k == highlight else 2)
		sb.set_corner_radius_all(int(cell * (0.22 if not Ring.is_corner(k) else 0.45)))
		sb.anti_aliasing = true
		draw_style_box(sb, r)
		var b = ring.get(k, null)
		if b != null:
			var tex := PixelArt.beast_texture(b.genes)
			var col := Color.WHITE if b.hp > 0 else Color(0.35, 0.35, 0.4, 0.7)
			draw_texture_rect(tex, r.grow(-cell * 0.08), false, col)
			if b.hp <= 0:
				draw_line(r.position + Vector2(cell * 0.2, cell * 0.2), r.end - Vector2(cell * 0.2, cell * 0.2), Color(UIKit.BORDER, 0.8), 2.0)
		if not Ring.is_corner(k):
			# the side's element, just outside its cell
			var out := (p - c).normalized()
			var lp := p + out * cell * 0.78
			var letter := String(Ring.slot_elements(k)[0]).substr(0, 1).to_upper()
			var ts := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			draw_string(font, lp - Vector2(ts.x / 2.0, -ts.y * 0.3), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIKit.GOLD if on_side else UIKit.DIM)
	# the trainer in the middle, with their shield
	draw_circle(c, rad * 0.32, Color(UIKit.WINDOW_BOTTOM, 0.95))
	draw_arc(c, rad * 0.32, 0, TAU, 24, Color(UIKit.BORDER, 0.6), 2.0, true)
	if shield >= 0 and max_shield > 0:
		var n := max_shield
		for i in n:
			var a := -PI / 2.0 + TAU * float(i) / n
			var pp := c + Vector2(cos(a), sin(a)) * rad * 0.16 if n > 1 else c
			if i < shield:
				draw_circle(pp, rad * 0.075, UIKit.GOLD_BRIGHT)
			else:
				draw_arc(pp, rad * 0.075, 0, TAU, 12, Color(UIKit.DIM, 0.8), 1.5, true)
