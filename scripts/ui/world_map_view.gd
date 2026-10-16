extends "res://scripts/ui/modal.gd"
## Illustrated map of the twelve towns and the routes between them.

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
	draw_rect(a, Color("#e8d8b0"))
	# parchment speckles and border
	for i in 120:
		var px := a.position + Vector2(fmod(i * 97.3, a.size.x), fmod(i * 61.7, a.size.y))
		draw_rect(Rect2(px, Vector2(3, 3)), Color(0.55, 0.42, 0.25, 0.12))
	draw_rect(a, Color("#6a4a2a"), false, 6.0)
	draw_rect(a.grow(-10), Color("#9a7a4a"), false, 2.0)
	# sea in the south-east corner, mountains in the north
	for i in 6:
		var wy := a.position.y + 300 + i * 26
		for k in 5:
			var wx := a.position.x + 560 + k * 46 + (i % 2) * 20
			draw_arc(Vector2(wx, wy), 10, PI * 1.1, PI * 1.9, 8, Color(0.3, 0.5, 0.75, 0.5), 2.0)
	for i in 7:
		var mp := a.position + Vector2(300 + i * 70, 64 + (i % 2) * 12)
		draw_colored_polygon(PackedVector2Array([mp + Vector2(-28, 30), mp + Vector2(0, -6), mp + Vector2(28, 30)]), Color(0.5, 0.45, 0.4, 0.35))
	draw_string(hfont, a.position + Vector2(24, 44), "The Realm", HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.head_px(32), UIKit.ACCENT)
	# routes
	for rid in WorldDB.ROUTES:
		var pts := _route_points(rid)
		var r: Dictionary = WorldDB.ROUTES[rid]
		var locked: bool = r.has("locked_flag") and not GameState.flag(r["locked_flag"])
		var col := Color("#8a6a3a") if not locked else Color(0.45, 0.3, 0.55, 0.6)
		for i in pts.size() - 1:
			_dashed(pts[i], pts[i + 1], col, 4.0 if here != rid else 6.0)
		if here == rid:
			var mid: Vector2 = pts[pts.size() / 2] if pts.size() > 2 else (pts[0] + pts[1]) / 2.0
			_marker(mid)
		var lp: Vector2 = pts[pts.size() / 2] if pts.size() > 2 else (pts[0] + pts[1]) / 2.0
		draw_string(font, lp + Vector2(6, -6), r["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.body_px(22), Color(0.35, 0.25, 0.12, 0.85))
	# towns
	for i in _order.size():
		var tid: String = _order[i]
		var t: Dictionary = WorldDB.TOWNS[tid]
		var p := _to_screen(WorldDB.MAP_POS[tid])
		var rad: float = SIZE_R.get(t["size"], 10.0)
		var visited: bool = GameState.visited.has(tid)
		var col := Color("#c84a3a") if visited else Color("#9a8a7a")
		draw_circle(p, rad + 3, Color("#3a2414"))
		draw_circle(p, rad, col)
		var arena: Dictionary = WorldDB.ARENAS.get(tid, {})
		if not arena.is_empty():
			var won: bool = GameState.crests.has(arena["crest"])
			draw_circle(p + Vector2(rad, -rad), 6, Color("#ffd040") if won else Color("#7a6a5a"))
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
		draw_string(hfont, box.position + Vector2(18, 34), "%s  (%s)" % [info["name"], String(info["size"]).capitalize()], HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.head_px(32), UIKit.ACCENT)
		draw_string(font, box.position + Vector2(18, 62), info["blurb"], HORIZONTAL_ALIGNMENT_LEFT, 500, UIKit.body_px(22), UIKit.INK)
		var extra := "Mascot: %s" % RaceDB.race_name(info["mascot"])
		if WorldDB.ARENAS.has(ft):
			var ar: Dictionary = WorldDB.ARENAS[ft]
			extra += "    Arena: %s %s%s" % [ar["title"], ar["leader"], "  ✓" if GameState.crests.has(ar["crest"]) else ""]
		draw_string(font, box.position + Vector2(18, 88), extra, HORIZONTAL_ALIGNMENT_LEFT, 500, UIKit.body_px(22), UIKit.DIM)
	else:
		draw_string(hfont, box.position + Vector2(18, 34), "Unexplored", HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.head_px(32), UIKit.DIM)
		draw_string(font, box.position + Vector2(18, 62), "You haven't been here yet.", HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.body_px(22), UIKit.INK)
	draw_string(font, a.position + Vector2(a.size.x - 300, a.size.y - 22), "←/→ browse towns    S close", HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.body_px(22), Color("#5a3a1a"))


func _marker(p: Vector2) -> void:
	var bob := sin(_t * 4.0) * 4.0
	var tip := p + Vector2(0, -10 + bob)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-10, -20), tip + Vector2(10, -20)]), Color("#ffd040"))
	draw_circle(tip + Vector2(0, -22), 9, Color("#ffd040"))
	draw_circle(tip + Vector2(0, -22), 4, Color("#c8402f"))


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
