extends Control
## The move bars beside your grid in battle (as in Jade Cocoon 2): one bar for each slot of the side of your ring facing
## the foe, each level with its row of the grid (ring_grid.gd) and leaning with it, and your own bar.
##   - Your bar comes first, on its own: while you choose your action it stands level with the grid's middle row (you
##     stand in its centre cell), trimmed in gold; your trainer level, then your action. Once you move on to your
##     beasts it gives way to their bars. (Your shield points are orbs under the grid.)
##   - A beast's bar: its level on the left, then the move it will use (◄ ► change it while the bar is chosen). Under
##     it, its HP and MP. If the move costs MP, the part of the MP bar it would spend slowly flashes.
##   - Out of the command phase the bars show the beasts' names.
## battle.gd fills `rows` (see set_rows) and the command panel picks the focus; every bar can be tapped too.

const UIKit = preload("res://scripts/ui/ui_kit.gd")

## zone: "left" (the ◄ end), "right" (the ► end) or "body"
signal tapped(row: int, zone: String)

## [{kind: "trainer" | "beast", lv, text, arrows, done, disabled, status: "" | "down" | "empty", hp, max_hp, mp,
##   max_mp, cost, shield, max_shield}]
var rows: Array = []
var focus := -1
var pitch_y := 50.0
var slant := 22.0
var bar_w := 300.0
var pill_h := 30.0
## how much larger than the base sizes everything is drawn (the text too)
var k := 1.0
var _time := 0.0


func _init(_k := 1.0) -> void:
	k = _k
	pitch_y *= k
	slant *= k
	bar_w *= k
	pill_h *= k
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(bar_w + 2.0 * slant, 3.0 * pitch_y + pill_h + 16.0 * k)


func set_rows(r: Array, f := -1) -> void:
	rows = r
	focus = f
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## Row i's pill (1..3 = the top, middle and bottom slots, leaning left as the rows go down; 0 = you, on the middle
## row, level with the grid's centre cell).
func pill_rect(i: int) -> Rect2:
	var row := 2 if i == 0 else i
	var right := size.x - float(row - 1) * slant
	return Rect2(right - bar_w, float(row) * pitch_y, bar_w, pill_h)


## The rows showing: your bar alone while you choose your action, else the beasts'.
func shown() -> Array:
	if focus == 0:
		return [0]
	return range(1, rows.size())


func _draw() -> void:
	var font := UIKit.font_body()
	var big := UIKit.body_px(20 * k)
	var small := UIKit.body_px(12 * k)
	for i: int in shown():
		var row: Dictionary = rows[i]
		var r := pill_rect(i)
		var on := i == focus
		var you: bool = row.get("kind", "") == "trainer"
		var status: String = row.get("status", "")
		var fade := 1.0
		if status == "down":
			fade = 0.6
		elif status == "empty":
			fade = 0.3
		# the pill (yours: a gold rim, and a gold line inside it)
		var fill := UIKit.ACCENT.darkened(0.1) if on else UIKit.WINDOW_TOP
		fill.a = 0.95 * fade if not on else 0.97
		if UIKit.pixel():
			# the 1-bit plate: the gem behind the white for the bar being chosen
			draw_style_box(UIKit.pixel_plate(UIKit.ACCENT if on else UIKit.PIXEL_FILL, UIKit.PIXEL_LINE if on or you else UIKit.PIXEL_DIM, 0.97 if on else 0.95 * fade), r)
		var sb := StyleBoxFlat.new()
		sb.bg_color = fill
		sb.set_corner_radius_all(int(pill_h * 0.5))
		sb.border_color = Color(UIKit.GOLD_BRIGHT, 0.95) if you else Color(UIKit.BORDER, (0.95 if on else 0.55) * fade)
		sb.set_border_width_all(3 if you else 2)
		sb.anti_aliasing = true
		sb.shadow_color = Color(0, 0, 0, 0.35 * fade)
		sb.shadow_size = 3
		sb.shadow_offset = Vector2(0, 2)
		if not UIKit.pixel():
			draw_style_box(sb, r)
		if you and not UIKit.pixel():
			var inner := StyleBoxFlat.new()
			inner.draw_center = false
			inner.set_corner_radius_all(int(pill_h * 0.5) - 3)
			inner.border_color = Color(UIKit.GOLD_BRIGHT, 0.35)
			inner.set_border_width_all(1)
			inner.anti_aliasing = true
			draw_style_box(inner, r.grow(-4.0))
		# the level, in a cap on the left (yours: a gold cap)
		var cap := Rect2(r.position + Vector2(3, 3), Vector2(pill_h * 1.9, pill_h - 6))
		var cb := StyleBoxFlat.new()
		cb.bg_color = UIKit.GOLD_BRIGHT if you else Color(UIKit.WINDOW_BOTTOM, 0.95 * fade)
		cb.set_corner_radius_all(int((pill_h - 6) * 0.5))
		cb.anti_aliasing = true
		if UIKit.pixel():
			draw_style_box(UIKit.pixel_plate(UIKit.PIXEL_LINE if you else UIKit.PIXEL_FILL, UIKit.PIXEL_LINE, fade), cap.grow(1.0))
		else:
			draw_style_box(cb, cap)
		if status != "empty":
			var lv := "Lv%d" % int(row.get("lv", 1))
			var ls := font.get_string_size(lv, HORIZONTAL_ALIGNMENT_LEFT, -1, small)
			draw_string(font, cap.get_center() + Vector2(-ls.x * 0.5, ls.y * 0.32), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, small, UIKit.WINDOW_BOTTOM if you else Color(UIKit.GOLD_BRIGHT, fade))
		# the move / action, between the arrows
		var x0 := cap.end.x + 8.0
		var x1 := r.end.x - 12.0
		var arrows: bool = on and row.get("arrows", false)
		if arrows:
			_tri(Vector2(x0 + 6.0, r.get_center().y), -1, UIKit.LIGHT)
			_tri(Vector2(x1 - 4.0, r.get_center().y), 1, UIKit.LIGHT)
			x0 += 18.0
			x1 -= 18.0
		var text: String = row.get("text", "")
		var col := UIKit.LIGHT if on else UIKit.INK
		if row.get("disabled", false):
			col = Color(UIKit.DIM, 0.85)
		elif row.get("done", false) and not on:
			col = UIKit.GOLD_BRIGHT
		col.a *= fade
		if row.get("done", false):
			var ck := "✓"
			var cs := font.get_string_size(ck, HORIZONTAL_ALIGNMENT_LEFT, -1, small)
			draw_string(font, Vector2(x1 - cs.x, r.get_center().y + cs.y * 0.32), ck, HORIZONTAL_ALIGNMENT_LEFT, -1, small, Color(UIKit.GOLD_BRIGHT, fade))
			x1 -= cs.x + 6.0
		text = _fit(font, text, big, x1 - x0)
		var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, big)
		draw_string(font, Vector2(x0, r.get_center().y + ts.y * 0.3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, big, col)
		# under a beast's pill: its HP and MP
		var sub := Rect2(Vector2(cap.position.x + 8.0, r.end.y + 4.0), Vector2(r.size.x - 30.0, maxf(6.0, pill_h * 0.24)))
		if you or status == "empty":
			continue
		var hp_w := sub.size.x * 0.58
		var hr := Rect2(sub.position, Vector2(hp_w, sub.size.y))
		var mr := Rect2(Vector2(hr.end.x + 8.0, sub.position.y), Vector2(sub.size.x - hp_w - 8.0, sub.size.y))
		_gauge(hr, float(row.get("hp", 0)) / maxf(1.0, float(row.get("max_hp", 1))), UIKit.hp_color(float(row.get("hp", 0)) / maxf(1.0, float(row.get("max_hp", 1)))), fade)
		var mp := float(row.get("mp", 0))
		var mmax := maxf(1.0, float(row.get("max_mp", 1)))
		var cost := float(row.get("cost", 0))
		var mp_col := Color("#a9c8ff")
		if cost > 0.0 and on:
			# the MP this move would spend slowly fades in and out
			var keep := maxf(0.0, mp - cost)
			_gauge(mr, keep / mmax, mp_col, fade)
			var spend := Rect2(mr.position + Vector2(mr.size.x * keep / mmax, 0), Vector2(mr.size.x * (minf(mp, mmax) - keep) / mmax, mr.size.y))
			var pulse := 0.15 + 0.85 * (0.5 + 0.5 * sin(_time * 2.4))
			draw_rect(spend, Color(mp_col, pulse * fade))
			if mp < cost:
				draw_rect(mr, Color(UIKit.ACCENT, 0.5 * pulse), false, 1.5)
		else:
			_gauge(mr, mp / mmax, mp_col, fade)


## A thin gauge: a dark trough with a coloured fill.
func _gauge(r: Rect2, ratio: float, col: Color, fade: float) -> void:
	draw_rect(r.grow(1.5), Color(0, 0, 0, 0.55 * fade))
	draw_rect(r, Color(UIKit.WINDOW_BOTTOM, 0.9 * fade))
	if ratio > 0.0:
		draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(ratio, 0.0, 1.0), r.size.y)), Color(col, fade))


func _tri(c: Vector2, dir: int, col: Color) -> void:
	var s := pill_h * 0.22
	draw_colored_polygon(PackedVector2Array([c + Vector2(dir * s, 0), c + Vector2(-dir * s * 0.7, -s), c + Vector2(-dir * s * 0.7, s)]), col)


## Trims text with an ellipsis to fit `w`.
static func _fit(font: Font, text: String, fs: int, w: float) -> String:
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= w:
		return text
	var t := text
	while t.length() > 1 and font.get_string_size(t + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
		t = t.substr(0, t.length() - 1)
	return t.strip_edges() + "…"


func _gui_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	var p: Vector2 = (ev as InputEventMouseButton).position
	for i: int in shown():
		var r := pill_rect(i)
		if r.grow(4.0).has_point(p):
			var zone := "body"
			if p.x < r.position.x + pill_h * 2.6:
				zone = "left"
			elif p.x > r.end.x - pill_h * 1.4:
				zone = "right"
			tapped.emit(i, zone)
			accept_event()
			return
