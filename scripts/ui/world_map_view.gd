extends "res://scripts/ui/modal.gd"
## Map of the twelve towns and the routes between them, drawn in white lines on a dark window (towns you've visited
## and your marker in the accent).

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const WorldDB = preload("res://scripts/data/world_db.gd")
const RaceDB = preload("res://scripts/data/race_db.gd")
const PixelArt = preload("res://scripts/gfx/pixel_art.gd")

const SIZE_R := {"hamlet": 9.0, "village": 11.0, "town": 13.0, "city": 16.0}

var here := ""
var _t := 0.0
var _focus := 0
var _order: Array = []


func setup(current_map: String) -> Control:
	here = current_map.get_slice("#", 0)
	dim = 0.7
	_order = WorldDB.TOWN_ORDER.duplicate()
	_focus = maxi(0, _order.find(here))
	return self


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _area() -> Rect2:
	return Rect2((size.x - 1100) / 2.0, (size.y - 640) / 2.0, 1100, 640)


func _to_screen(p: Vector2) -> Vector2:
	var a := _area()
	return a.position + Vector2(70, 60) + p * Vector2(1.18, 1.0)


func _route_points(rid: String) -> Array:
	var r: Dictionary = WorldDB.ROUTES[rid]
	if WorldDB.ROUTE_PATHS.has(rid):
		var pts := []
		for p in WorldDB.ROUTE_PATHS[rid]:
			pts.append(_to_screen(p))
		return pts
	return [_to_screen(WorldDB.MAP_POS[r["from"]]), _to_screen(WorldDB.MAP_POS[r["to"]])]


func _draw() -> void:
	super._draw()
	var font := UIKit.font_body()
	var hfont := UIKit.font_head()
	var a := _area()
	draw_style_box(UIKit.box("textfield"), a)
	# a faint grid, like a survey map
	for gx in range(int(a.position.x) + 40, int(a.end.x) - 20, 80):
		draw_line(Vector2(gx, a.position.y + 10), Vector2(gx, a.end.y - 10), Color(1, 1, 1, 0.04), 1.0)
	for gy in range(int(a.position.y) + 40, int(a.end.y) - 20, 80):
		draw_line(Vector2(a.position.x + 10, gy), Vector2(a.end.x - 10, gy), Color(1, 1, 1, 0.04), 1.0)
	# sea in the south-east corner, mountains in the north
	for i in 6:
		var wy := a.position.y + 300 + i * 26
		for k in 5:
			var wx := a.position.x + 560 + k * 46 + (i % 2) * 20
			draw_arc(Vector2(wx, wy), 10, PI * 1.1, PI * 1.9, 8, Color(1, 1, 1, 0.22), 2.0)
	for i in 7:
		var mp := a.position + Vector2(300 + i * 70, 64 + (i % 2) * 12)
		draw_colored_polygon(PackedVector2Array([mp + Vector2(-28, 30), mp + Vector2(0, -6), mp + Vector2(28, 30)]), Color(1, 1, 1, 0.1))
	draw_string(hfont, a.position + Vector2(24, 48), "The Realm", HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.head_px(32), UIKit.LIGHT)
	draw_rect(Rect2(a.position + Vector2(24, 58), Vector2(200, 3)), UIKit.ACCENT)
	# routes
	for rid in WorldDB.ROUTES:
		var pts := _route_points(rid)
		var r: Dictionary = WorldDB.ROUTES[rid]
		var locked: bool = r.has("locked_flag") and not GameState.flag(r["locked_flag"])
		var col := Color(1, 1, 1, 0.55) if not locked else Color(1, 1, 1, 0.18)
		for i in pts.size() - 1:
			_dashed(pts[i], pts[i + 1], col, 4.0 if here != rid else 6.0)
		if here == rid:
			var mid: Vector2 = pts[pts.size() / 2] if pts.size() > 2 else (pts[0] + pts[1]) / 2.0
			_marker(mid)
		var lp: Vector2 = pts[pts.size() / 2] if pts.size() > 2 else (pts[0] + pts[1]) / 2.0
		draw_string(font, lp + Vector2(6, -6), r["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.body_px(22), UIKit.DIM)
	# towns
	for i in _order.size():
		var tid: String = _order[i]
		var t: Dictionary = WorldDB.TOWNS[tid]
		var p := _to_screen(WorldDB.MAP_POS[tid])
		var rad: float = SIZE_R.get(t["size"], 10.0)
		var visited: bool = GameState.visited.has(tid)
		var col := UIKit.ACCENT if visited else Color("#3a3a42")
		draw_circle(p, rad + 3, UIKit.BORDER)
		draw_circle(p, rad, col)
		var arena: Dictionary = WorldDB.ARENAS.get(tid, {})
		if not arena.is_empty():
			var won: bool = GameState.crests.has(arena["crest"])
			draw_circle(p + Vector2(rad, -rad), 7, UIKit.BORDER)
			draw_circle(p + Vector2(rad, -rad), 5, UIKit.GOLD_BRIGHT if won else Color("#3a3a42"))
		var label: String = t["name"] if visited else "???"
		draw_string(font, p + Vector2(-110, rad + 22), label, HORIZONTAL_ALIGNMENT_CENTER, 220, UIKit.body_px(22), UIKit.INK)
		if i == _focus:
			draw_arc(p, rad + 8 + sin(_t * 5.0) * 2.0, 0, TAU, 32, Color("#ffffff"), 2.0)
		if tid == here:
			_marker(p)
	# info panel for the focused town
	var ft: String = _order[_focus]
	var info: Dictionary = WorldDB.TOWNS[ft]
	var box := Rect2(a.position + Vector2(a.size.x - 548, a.size.y - 150), Vector2(520, 104))
	draw_style_box(UIKit.box("banner"), box.grow(6))
	if GameState.visited.has(ft):
		draw_string(hfont, box.position + Vector2(18, 34), "%s  (%s)" % [info["name"], String(info["size"]).capitalize()], HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.head_px(32), UIKit.LIGHT)
		draw_string(font, box.position + Vector2(18, 62), info["blurb"], HORIZONTAL_ALIGNMENT_LEFT, 500, UIKit.body_px(22), UIKit.INK)
		var extra := "Mascot: %s" % RaceDB.race_name(info["mascot"])
		if WorldDB.ARENAS.has(ft):
			var ar: Dictionary = WorldDB.ARENAS[ft]
			extra += "    Arena: %s %s%s" % [ar["title"], ar["leader"], "  (won)" if GameState.crests.has(ar["crest"]) else ""]
		draw_string(font, box.position + Vector2(18, 88), extra, HORIZONTAL_ALIGNMENT_LEFT, 500, UIKit.body_px(22), UIKit.DIM)
	else:
		draw_string(hfont, box.position + Vector2(18, 34), "Unexplored", HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.head_px(32), UIKit.DIM)
		draw_string(font, box.position + Vector2(18, 62), "You haven't been here yet.", HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.body_px(22), UIKit.INK)
	draw_string(font, a.position + Vector2(a.size.x - 300, a.size.y - 22), "Left/Right: browse towns    S: close", HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.body_px(22), UIKit.DIM)


func _marker(p: Vector2) -> void:
	var bob := sin(_t * 4.0) * 4.0
	var tip := p + Vector2(0, -10 + bob)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-10, -20), tip + Vector2(10, -20)]), UIKit.BORDER)
	draw_circle(tip + Vector2(0, -22), 9, UIKit.BORDER)
	draw_circle(tip + Vector2(0, -22), 5, UIKit.ACCENT)


func _dashed(a: Vector2, b: Vector2, col: Color, width: float) -> void:
	var len := a.distance_to(b)
	var dir := (b - a) / maxf(1.0, len)
	var d := 0.0
	while d < len:
		var e := minf(len, d + 12.0)
		draw_line(a + dir * d, a + dir * e, col, width)
		d += 20.0


func on_input(ev: InputEvent) -> void:
	if ev.is_echo() and not (ev.is_action("ui_left") or ev.is_action("ui_right")):
		return
	if ev.is_action_pressed("ui_right") or ev.is_action_pressed("ui_down"):
		_focus = (_focus + 1) % _order.size()
		Sfx.play("blip")
	elif ev.is_action_pressed("ui_left") or ev.is_action_pressed("ui_up"):
		_focus = (_focus - 1 + _order.size()) % _order.size()
		Sfx.play("blip")
	elif ev.is_action_pressed("ui_cancel") or ev.is_action_pressed("ui_accept") or ev.is_action_pressed("menu"):
		Sfx.play("back")
		close()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		close()
