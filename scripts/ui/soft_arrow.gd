extends Control
## The game's one arrow (the user's direction, 2026-11-15): a broad, low pyramid with softly rounded corners, after the
## touch pad's d-pad arrows (controls_overlay.gd _sd_arrow), in place of the pointed ◄ ► ▲ ▼ glyphs and the sharp
## drawn triangles. As a control it fills its rect, pointing `dir`; other screens' _draw code calls draw_arrow.

## which way it points, and its colour
var dir := Vector2.RIGHT:
	set(v):
		dir = v
		queue_redraw()
var color := Color.WHITE:
	set(v):
		color = v
		queue_redraw()
## how much of the rect's smaller side the arrow's base spans
var fill := 0.62

## the height (base to tip) for a base `2 * s` wide, and how round its corners are
const TALL := 1.25
const ROUND := 0.3


static func make(d: Vector2, col: Color, min_size := Vector2(32, 32)) -> Control:
	var a: Control = (load("res://scripts/ui/soft_arrow.gd") as GDScript).new()
	a.dir = d
	a.color = col
	a.custom_minimum_size = min_size
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return a


func _draw() -> void:
	var s := minf(size.x, size.y) * fill * 0.5
	draw_arrow(self, (size / 2.0).round(), dir, s, color)


## The outline: a triangle `2 * s` across its base and TALL * s from base to tip, centred on `c`, its corners rounded.
static func points(c: Vector2, d: Vector2, s: float) -> PackedVector2Array:
	d = d.normalized()
	var side := Vector2(-d.y, d.x)
	var h := s * TALL
	var v: Array[Vector2] = [c + d * h * 0.5, c - d * h * 0.5 + side * s, c - d * h * 0.5 - side * s]
	# the incircle, to pull each corner in along its bisector so the rounded corner keeps the same outline
	var la := v[1].distance_to(v[2])
	var lb := v[2].distance_to(v[0])
	var lc := v[0].distance_to(v[1])
	var inc := (v[0] * la + v[1] * lb + v[2] * lc) / (la + lb + lc)
	var semi := (la + lb + lc) / 2.0
	var area := absf((v[1] - v[0]).cross(v[2] - v[0])) / 2.0
	var rho := area / semi
	var r := s * ROUND
	var out := PackedVector2Array()
	for i in 3:
		var p: Vector2 = v[i] + (inc - v[i]) * (r / rho)
		var a: Vector2 = v[(i + 2) % 3]
		var b: Vector2 = v[(i + 1) % 3]
		var n1 := (v[i] - a).orthogonal().normalized()
		if n1.dot((a + v[i]) / 2.0 - inc) < 0.0:
			n1 = -n1
		var n2 := (b - v[i]).orthogonal().normalized()
		if n2.dot((b + v[i]) / 2.0 - inc) < 0.0:
			n2 = -n2
		var a1 := n1.angle()
		var sweep := wrapf(n2.angle() - a1, -PI, PI)
		for k in 7:
			out.append(p + Vector2.from_angle(a1 + sweep * k / 6.0) * r)
	return out


## Draws the arrow on any canvas item, with a smooth edge.
static func draw_arrow(ci: CanvasItem, c: Vector2, d: Vector2, s: float, col: Color) -> void:
	var pts := points(c, d, s)
	ci.draw_colored_polygon(pts, col)
	pts.append(pts[0])
	ci.draw_polyline(pts, col, 1.0, true)
