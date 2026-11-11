extends Control
## The world map (the Start book's Map page): inked geography on aged paper, supplied town markers,
## and a flag where you are. The towns are spread over whatever room it's given (clear of the
## touch pad where it reaches over the page). Names live on the facing detail page. The d-pad
## moves its cursor to the nearest town that way and a tap picks a town (`focused`); A asks to act on the picked one
## (`activated`: the book flies you there, if you can).

signal focused(town: String)
signal activated(town: String)

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const WorldDB = preload("res://scripts/data/world_db.gd")

const PAPER = preload("res://assets/ui/world_map/paper.png")
const CARTOGRAPHY = preload("res://assets/ui/world_map/cartography.png")
const TOWN_MARK = preload("res://assets/ui/world_map/town.png")
const UNKNOWN_MARK = preload("res://assets/ui/world_map/unknown.png")
const POSITION_MARK = preload("res://assets/ui/world_map/position.png")
const PAPER_CLIP = preload("res://scripts/ui/map_paper.gdshader")
## These are the printed map's inks, independent of the surrounding menu's gem.
const MAP_INK := Color("493822")
const ART_ORIGIN := Vector2(-100, -140)
const ART_SIZE := Vector2(1040, 760)
const MARK_SIZE := Vector2(24, 34)

## room kept around the markers (left, top, right, bottom; UI units)
const PAD := Vector4(44, 60, 44, 36)
## Limit distortion while allowing a taller book page to use its available height.
const MAX_STRETCH := 1.4
## how near a town a tap must land (UI units)
const TAP_R := 52.0
const DIRS := {"ui_left": Vector2.LEFT, "ui_right": Vector2.RIGHT, "ui_up": Vector2.UP, "ui_down": Vector2.DOWN}

## the town or route you're on
var here := ""
var _order: Array = []
var _focus := 0
## map positions (WorldDB.MAP_POS) to the screen: a scale for each axis and an offset (see _fit)
var _k := Vector2.ZERO
var _o := Vector2.ZERO


func setup(map_id: String) -> Control:
	here = map_id.get_slice("#", 0)
	_order = WorldDB.TOWN_ORDER.duplicate()
	# (on a route, the cursor starts on the town it leads from)
	var start := String(WorldDB.ROUTES[here]["from"]) if WorldDB.ROUTES.has(here) else here
	_focus = maxi(0, _order.find(start))
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var sheet := ShaderMaterial.new()
	sheet.shader = PAPER_CLIP
	sheet.set_shader_parameter("paper_mask", PAPER)
	material = sheet
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(240, 160)
	return self


## The town under the cursor.
func town() -> String:
	return _order[_focus]


func _process(_delta: float) -> void:
	queue_redraw()


## Spreads the towns (and the routes' bends) over the room inside the padding, centred. (Every frame: the page it's
## on unfolds and slides, and the touch pad's reach depends on where it ends up.)
func _fit() -> void:
	(material as ShaderMaterial).set_shader_parameter("paper_size", size.max(Vector2.ONE))
	var pad := _padding()
	var room := (size - Vector2(pad.x + pad.z, pad.y + pad.w)).max(Vector2.ONE)
	# Fit the complete coastline, including its margins, rather than only the town coordinates.
	var fit := room / ART_SIZE
	var base := minf(fit.x, fit.y)
	_k = fit.min(Vector2.ONE * base * MAX_STRETCH)
	_o = (Vector2(pad.x, pad.y) + (room - ART_SIZE * _k) / 2.0 - ART_ORIGIN * _k).round()


## PAD, widened on the side where the d-pad or A / B reach over the map, so no marker sits under them.
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


func _draw() -> void:
	_fit()
	# Paper is a physical map laid inside the shared dark book, rather than a new window style.
	draw_texture_rect(PAPER, Rect2(Vector2.ZERO, size), false)
	# Continuous sea wash across the entire sheet, clipped to its ragged alpha edge.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.36, 0.53, 0.52, 0.16))
	draw_texture_rect(CARTOGRAPHY, Rect2(_to_screen(ART_ORIGIN), ART_SIZE * _k), false)
	# routes (named on the book's facing page, where there's room)
	for rid in WorldDB.ROUTES:
		var pts := _route_points(rid)
		var r: Dictionary = WorldDB.ROUTES[rid]
		var locked: bool = r.has("locked_flag") and not GameState.flag(r["locked_flag"])
		var col := Color(MAP_INK, 0.8) if not locked else Color(MAP_INK, 0.35)
		if here == rid:
			col = MAP_INK
		for i in pts.size() - 1:
			_dashed(pts[i], pts[i + 1], col, 3.0 if here == rid else 2.0)
	_dashed(_to_screen(WorldDB.MAP_POS[WorldDB.FERRY[0]]), _to_screen(WorldDB.MAP_POS[WorldDB.FERRY[1]]), Color(MAP_INK, 0.4), 1.0)
	# Supplied legend markers keep their white fill and black symbols on every gem.
	for tid in _order:
		var p := _to_screen(WorldDB.MAP_POS[tid])
		var visited: bool = GameState.visited.has(tid)
		_marker(POSITION_MARK if tid == here else (TOWN_MARK if visited else UNKNOWN_MARK), p)
		var arena: Dictionary = WorldDB.ARENAS.get(tid, {})
		if not arena.is_empty() and GameState.crests.has(arena["crest"]):
			var badge := p + Vector2(17, -29)
			draw_circle(badge, 7, MAP_INK)
			draw_circle(badge, 5, UIKit.GOLD_BRIGHT)
	if WorldDB.ROUTES.has(here):
		var route_tip := _middle(_route_points(here))
		var flag_tip := route_tip + Vector2(40, 0)
		draw_line(route_tip, flag_tip, MAP_INK, 1.0)
		draw_circle(route_tip, 3, MAP_INK)
		_marker(POSITION_MARK, flag_tip)
	# Only the selection corners: town names and unexplored text belong on the facing page.
	for i in _order.size():
		var tid: String = _order[i]
		var p := _to_screen(WorldDB.MAP_POS[tid])
		if i == _focus:
			# White corner marks, edged in ink so selection reads against light paper as well.
			var r := Rect2(p - Vector2(18, 38), Vector2(36, 42))
			for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
				var inward: Vector2 = (r.get_center() - corner).sign()
				for axis in [Vector2(inward.x, 0), Vector2(0, inward.y)]:
					draw_line(corner, corner + axis * 9, MAP_INK, 5.0)
					draw_line(corner, corner + axis * 9, UIKit.LIGHT, 2.0)


func _marker(texture: Texture2D, tip: Vector2) -> void:
	draw_texture_rect(texture, Rect2((tip - Vector2(MARK_SIZE.x / 2.0, MARK_SIZE.y)).round(), MARK_SIZE), false)


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
	# The supplied pins extend above their map coordinate: their whole visible body is tappable.
	for i in _order.size():
		var tip := _to_screen(WorldDB.MAP_POS[_order[i]])
		if Rect2(tip - Vector2(MARK_SIZE.x / 2.0, MARK_SIZE.y), MARK_SIZE).grow(6).has_point(p):
			return i
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
