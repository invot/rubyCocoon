extends StyleBox
## A soft, rounded window: a gradient fill (top to bottom, or left to right for selection pills), a blurred drop
## shadow, a cream border and a faint inner rim of light. Drawn as smooth polygons, so the corners stay round at any
## screen scale (the windows of the PS2 RPGs, not pixel boxes).

var top := Color(0.23, 0.18, 0.32, 0.94)
var bottom := Color(0.13, 0.10, 0.19, 0.94)
## true: the gradient runs left to right (top = left colour)
var horizontal := false
var border := Color("#f7ecd8")
var border_w := 3.0
var radius := 16.0
## the faint line of light just inside the border (alpha 0 = none)
var rim := Color(1, 1, 1, 0.10)
var shadow := Color(0, 0, 0, 0.32)
var shadow_off := Vector2(0, 4)
var shadow_size := 6.0
## an accent bar down the left edge, inside the border (alpha 0 = none)
var stripe := Color(0, 0, 0, 0)
var stripe_w := 6.0


func _draw(ci: RID, rect: Rect2) -> void:
	var r := minf(radius, minf(rect.size.x, rect.size.y) / 2.0)
	# shadow: a few rounded layers, each a little larger and fainter
	if shadow.a > 0.0 and shadow_size > 0.0:
		var steps := 3
		for i in steps:
			var g := shadow_size * float(i + 1) / steps
			var sr := Rect2(rect.position + shadow_off, rect.size).grow(g - shadow_size * 0.5)
			var pts := _round_rect(sr, r + g * 0.5)
			RenderingServer.canvas_item_add_polygon(ci, pts, PackedColorArray([Color(shadow, shadow.a / steps)]))
	# fill
	var fill_pts := _round_rect(rect, r)
	var cols := PackedColorArray()
	cols.resize(fill_pts.size())
	for i in fill_pts.size():
		var t := (fill_pts[i].x - rect.position.x) / maxf(1.0, rect.size.x) if horizontal else (fill_pts[i].y - rect.position.y) / maxf(1.0, rect.size.y)
		cols[i] = top.lerp(bottom, clampf(t, 0.0, 1.0))
	RenderingServer.canvas_item_add_polygon(ci, fill_pts, cols)
	# accent stripe down the left
	if stripe.a > 0.0:
		var inset := border_w + 3.0
		var sr2 := Rect2(rect.position + Vector2(inset, inset + r * 0.35), Vector2(stripe_w, rect.size.y - (inset + r * 0.35) * 2.0))
		if sr2.size.y > 0.0:
			RenderingServer.canvas_item_add_polygon(ci, _round_rect(sr2, stripe_w / 2.0), PackedColorArray([stripe]))
	# inner rim of light
	if rim.a > 0.0:
		var ir := rect.grow(-(border_w + 2.0))
		if ir.size.x > 4.0 and ir.size.y > 4.0:
			_outline(ci, ir, maxf(1.0, r - border_w - 2.0), rim, 1.5)
	# border
	if border_w > 0.0 and border.a > 0.0:
		_outline(ci, rect.grow(-border_w / 2.0), maxf(1.0, r - border_w / 2.0), border, border_w)


func _outline(ci: RID, rect: Rect2, r: float, col: Color, w: float) -> void:
	var pts := _round_rect(rect, r)
	pts.append(pts[0])
	pts.append(pts[1])
	RenderingServer.canvas_item_add_polyline(ci, pts, PackedColorArray([col]), w, true)


## The outline of a rounded rectangle, clockwise from the top-left corner.
static func _round_rect(rect: Rect2, r: float) -> PackedVector2Array:
	r = clampf(r, 0.0, minf(rect.size.x, rect.size.y) / 2.0)
	var pts := PackedVector2Array()
	var seg := clampi(int(r / 2.0), 3, 10)
	var centres := [rect.position + Vector2(r, r), Vector2(rect.end.x - r, rect.position.y + r),
		rect.end - Vector2(r, r), Vector2(rect.position.x + r, rect.end.y - r)]
	var starts := [PI, PI * 1.5, 0.0, PI * 0.5]
	for k in 4:
		for i in seg + 1:
			var a: float = starts[k] + PI * 0.5 * float(i) / seg
			pts.append(centres[k] + Vector2(cos(a), sin(a)) * r)
	return pts
