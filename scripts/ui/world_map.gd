extends Control
## The world map (the Start book's Map page): the twelve towns and the routes between them in white lines, the towns
## you've visited in the gem, and a pin where you are. The towns are spread over whatever room it's given (clear of the
## touch pad where it reaches over the page), while their names and the pin keep their full, readable size. The d-pad
## moves its cursor to the nearest town that way and a tap picks a town (`focused`); A asks to act on the picked one
## (`activated`: the book flies you there, if you can).

signal focused(town: String)
signal activated(town: String)

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const WorldDB = preload("res://scripts/data/world_db.gd")

const SIZE_R := {"hamlet": 9.0, "village": 11.0, "town": 13.0, "city": 16.0}
## room kept round the towns for their names and the pin (left, top, right, bottom; UI units)
const PAD := Vector4(56, 44, 56, 40)
## how much wider than tall the map may be stretched to fill its room
const MAX_STRETCH := 1.4
## how near a town a tap must land (UI units)
const TAP_R := 52.0
const DIRS := {"ui_left": Vector2.LEFT, "ui_right": Vector2.RIGHT, "ui_up": Vector2.UP, "ui_down": Vector2.DOWN}

## the town or route you're on
var here := ""
## the page it's drawn on: town names are edged in it, so the routes' dashes never run through them
var paper := Color(0, 0, 0, 0)
var _order: Array = []
var _focus := 0
var _t := 0.0
## map positions (WorldDB.MAP_POS) to the screen: a scale for each axis and an offset (see _fit)
var _k := Vector2.ZERO
var _o := Vector2.ZERO
## the towns' and routes' bounds in map space (they never change)
var _lo := Vector2.ZERO
var _span := Vector2.ONE


func setup(map_id: String) -> Control:
	here = map_id.get_slice("#", 0)
	_order = WorldDB.TOWN_ORDER.duplicate()
	# (on a route, the cursor starts on the town it leads from)
	var start := String(WorldDB.ROUTES[here]["from"]) if WorldDB.ROUTES.has(here) else here
	_focus = maxi(0, _order.find(start))
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(240, 160)
	var lo := Vector2(INF, INF)
	var hi := -lo
	var pts: Array = WorldDB.MAP_POS.values()
	for path in WorldDB.ROUTE_PATHS.values():
		pts.append_array(path)
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	_lo = lo
	_span = (hi - lo).max(Vector2.ONE)
	return self


## The town under the cursor.
func town() -> String:
	return _order[_focus]


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## Spreads the towns (and the routes' bends) over the room inside the padding, centred. (Every frame: the page it's
## on unfolds and slides, and the touch pad's reach depends on where it ends up.)
func _fit() -> void:
	var pad := _padding()
	var room := (size - Vector2(pad.x + pad.z, pad.y + pad.w)).max(Vector2.ONE)
	var ky := minf(room.y / _span.y, room.x / _span.x)
	_k = Vector2(clampf(room.x / _span.x, ky, ky * MAX_STRETCH), ky)
	_o = (Vector2(pad.x, pad.y) + (room - _span * _k) / 2.0 - _lo * _k).round()


## PAD, widened on the side where the d-pad or A / B reach over the map, so no town (or its name) sits under them.
func _padding() -> Vector4:
	var pad := PAD
	if not is_instance_valid(UI.controls) or not UI.is_touch():
		return pad
	var r := get_global_rect()
	for group in UI.controls.CLUSTERS:
		var zone: Rect2 = UI.controls.cluster_zone(group, UI.controls.TOUCH_SLOP)
		if not zone.intersects(r):
			continue
		if zone.get_center().x < r.get_center().x:
			pad.x = maxf(pad.x, zone.end.x - r.position.x + PAD.x)
		else:
			pad.z = maxf(pad.z, r.end.x - zone.position.x + PAD.z)
	return pad


func _to_screen(p: Vector2) -> Vector2:
	return (_o + p * _k).round()


func _route_points(rid: String) -> Array:
	var r: Dictionary = WorldDB.ROUTES[rid]
	var pts := []
	for p in WorldDB.ROUTE_PATHS.get(rid, [WorldDB.MAP_POS[r["from"]], WorldDB.MAP_POS.get(r["to"], WorldDB.MAP_POS[r["from"]])]):
		pts.append(_to_screen(p))
	return pts


func _middle(pts: Array) -> Vector2:
	return pts[pts.size() / 2] if pts.size() > 2 else (pts[0] + pts[1]) / 2.0


func _radius(tid: String) -> float:
	return roundf(float(SIZE_R.get(WorldDB.TOWNS[tid]["size"], 10.0)) * clampf(minf(_k.x, _k.y), 0.75, 1.0))


func _draw() -> void:
	_fit()
	var k := minf(_k.x, _k.y)
	var font := UIKit.font_body()
	var fs := UIKit.body_px(20)
	# a faint grid, like a survey map
	var grid := maxf(40.0, roundf(80.0 * k))
	for gx in range(int(grid / 2.0), int(size.x), int(grid)):
		draw_line(Vector2(gx, 0), Vector2(gx, size.y), Color(1, 1, 1, 0.04), 1.0)
	for gy in range(int(grid / 2.0), int(size.y), int(grid)):
		draw_line(Vector2(0, gy), Vector2(size.x, gy), Color(1, 1, 1, 0.04), 1.0)
	# the sea between the isles and the jungle, mountains along the north
	for i in 6:
		for j in 5:
			var w := _to_screen(Vector2(415 + j * 39 + (i % 2) * 17, 240 + i * 26))
			draw_arc(w, 10.0 * k, PI * 1.1, PI * 1.9, 8, Color(1, 1, 1, 0.22), 2.0)
	for i in 7:
		var mp := _to_screen(Vector2(195 + i * 59, 4 + (i % 2) * 12))
		draw_colored_polygon(PackedVector2Array([mp + Vector2(-28, 30) * k, mp + Vector2(0, -6) * k, mp + Vector2(28, 30) * k]), Color(1, 1, 1, 0.1))
	# routes (named on the book's facing page, where there's room)
	for rid in WorldDB.ROUTES:
		var pts := _route_points(rid)
		var r: Dictionary = WorldDB.ROUTES[rid]
		var locked: bool = r.has("locked_flag") and not GameState.flag(r["locked_flag"])
		var col := Color(1, 1, 1, 0.55) if not locked else Color(1, 1, 1, 0.18)
		for i in pts.size() - 1:
			_dashed(pts[i], pts[i + 1], col, 4.0 if here == rid else 3.0)
	# towns, with an arena's crest badge, and their names (??? until you've been)
	for i in _order.size():
		var tid: String = _order[i]
		var p := _to_screen(WorldDB.MAP_POS[tid])
		var rad := _radius(tid)
		var visited: bool = GameState.visited.has(tid)
		draw_circle(p, rad + 3, UIKit.BORDER)
		draw_circle(p, rad, UIKit.ACCENT if visited else UIKit.BORDER_INNER)
		var arena: Dictionary = WorldDB.ARENAS.get(tid, {})
		if not arena.is_empty():
			var won: bool = GameState.crests.has(arena["crest"])
			draw_circle(p + Vector2(rad, -rad), 7, UIKit.BORDER)
			draw_circle(p + Vector2(rad, -rad), 5, UIKit.GOLD_BRIGHT if won else UIKit.BORDER_INNER)
		var label: String = WorldDB.TOWNS[tid]["name"] if visited else "???"
		var base := (p + Vector2(-120, rad + 6 + font.get_ascent(fs))).round()
		if paper.a > 0.0:
			draw_string_outline(font, base, label, HORIZONTAL_ALIGNMENT_CENTER, 240, fs, 8, paper)
		draw_string(font, base, label, HORIZONTAL_ALIGNMENT_CENTER, 240, fs, UIKit.INK if visited else UIKit.DIM)
		if i == _focus:
			draw_arc(p, rad + 8 + sin(_t * 5.0) * 2.0, 0, TAU, 32, UIKit.LIGHT, 2.0)
	# you: a pin on your town, or halfway along your route
	if WorldDB.MAP_POS.has(here):
		_pin(_to_screen(WorldDB.MAP_POS[here]) - Vector2(0, _radius(here) - 2))
	elif WorldDB.ROUTES.has(here):
		_pin(_middle(_route_points(here)))


func _pin(tip: Vector2) -> void:
	tip.y += roundf(sin(_t * 4.0) * 4.0)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-10, -20), tip + Vector2(10, -20)]), UIKit.BORDER)
	draw_circle(tip + Vector2(0, -22), 9, UIKit.BORDER)
	draw_circle(tip + Vector2(0, -22), 5, UIKit.ACCENT)


func _dashed(a: Vector2, b: Vector2, col: Color, width: float) -> void:
	var len := a.distance_to(b)
	var dir := (b - a) / maxf(1.0, len)
	var d := 0.0
	while d < len:
		draw_line(a + dir * d, a + dir * minf(len, d + 12.0), col, width)
		d += 20.0


func _gui_input(ev: InputEvent) -> void:
	# (a tap arrives as a touch and as the mouse click it's mirrored into; picking a town twice changes nothing)
	if ev is InputEventMouseButton or ev is InputEventScreenTouch:
		if ev.pressed and (ev is InputEventScreenTouch or ev.button_index == MOUSE_BUTTON_LEFT):
			grab_focus()
			var i := _town_at(ev.position)
			if i >= 0:
				_pick(i)
			accept_event()
		return
	if not ev.is_pressed():
		return
	for a in DIRS:
		if ev.is_action_pressed(a, true):
			_step(DIRS[a])
			accept_event()
			return
	if ev.is_action_pressed("ui_accept"):
		accept_event()
		activated.emit(town())


## The town nearest a tap, if it's near enough one.
func _town_at(p: Vector2) -> int:
	var best := -1
	var near := TAP_R
	for i in _order.size():
		var d := p.distance_to(_to_screen(WorldDB.MAP_POS[_order[i]]))
		if d < near:
			near = d
			best = i
	return best


## The cursor to the nearest town that way (favouring the ones most nearly straight ahead).
func _step(dir: Vector2) -> void:
	var from := _to_screen(WorldDB.MAP_POS[town()])
	var best := -1
	var best_cost := INF
	for i in _order.size():
		var d := _to_screen(WorldDB.MAP_POS[_order[i]]) - from
		var ahead := d.dot(dir)
		if i == _focus or ahead <= 0.0:
			continue
		var cost := ahead + absf(d.cross(dir)) * 2.0
		if cost < best_cost:
			best_cost = cost
			best = i
	if best >= 0:
		_pick(best)


func _pick(i: int) -> void:
	if i == _focus:
		return
	_focus = i
	Sfx.play("blip")
	focused.emit(town())
