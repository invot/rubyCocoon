extends Control
## A trainer's battle ring in the battle HUD, as a slanted 3x3 grid of tiles (as in Jade Cocoon 2): the trainer in the
## middle, the eight slots of the ring round them. The grid leans like the field does from over your shoulder, so each
## tile sits where its pad stands.
##   - Your grid ("ally") has the side facing the foe as its left column: its top, middle and bottom tiles are the rows
##     of the move bars beside it. The foe's grid ("foe") is the same grid turned half round, its fighting side on the
##     right, towards you.
##   - The slots run anticlockwise round the grid (as round the ring), so turning the ring turns the grid: ▲ past your
##     top beast turns it anticlockwise (the top row comes round to the left), ▼ past the bottom one clockwise.
##   - A tile with a beast on it carries the beast's icon, with a small HP bar; a fainted beast's icon is crossed out.
##     Slots nobody stands on are faded out.
##   - A wild pack ("wild") is a single slanted line of three tiles: no trainer, no turning.
## All in the shades of the UI gem.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Ring = preload("res://scripts/core/ring.gd")
const PixelArt = preload("res://scripts/gfx/pixel_art.gd")

## the border cells, in the order the slots run (anticlockwise on screen), from the top tile of the fighting side
const ALLY_BORDER := [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(2, 1), Vector2i(2, 0), Vector2i(1, 0)]
const FOE_BORDER := [Vector2i(2, 2), Vector2i(2, 1), Vector2i(2, 0), Vector2i(1, 0), Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)]

## the tile grid: column pitch, row pitch (the move bars' too), and how far each row leans left of the one above
var pitch := Vector2(72, 50)
var slant := 22.0
var tile := Vector2(64, 30)

var team := "ally"
var wild := false
## {slot: beast} for a ring; [beast or null] x3 (top to bottom) for a wild pack
var ring: Dictionary = {}
var line: Array = []
var side := 0
## shield points, drawn as blue orbs under the grid
var shield := 0
var max_shield := 0
var show_shield := false
## the trainer can be hit (the middle of the fighting side is down)
var open := false
## the trainer standing in the middle: a small picture of them (battle.gd _person_icon); without one, a plain figure
var trainer_icon: Texture2D = null
## the tile of the beast you're choosing for (a slot, or a line index for the wild pack), -2 for the trainer (while
## you choose your own action), or -1
var focus := -1
## the tile being aimed at: a slot / line index, -2 for the trainer, or -1; targets: more of them (a move that hits
## them all, or a slot a beast could Move to)
var target := -1
var targets: Array = []

## turning: the border's cells are drawn this many steps round from their places (eased back to 0)
var _turn := 0.0
var _time := 0.0

signal tile_tapped(index: int)


func _init(_team := "ally", _wild := false, scale_k := 1.0) -> void:
	team = _team
	wild = _wild
	pitch *= scale_k
	slant *= scale_k
	tile *= scale_k
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(4.0 + 2.0 * slant + tile.x + 2.0 * pitch.x + 4.0, top_pad() + 2.0 * pitch.y + tile.y * 0.5 + 26.0 * scale_k)


## Room above the top row's tiles for the icons standing on them.
func top_pad() -> float:
	return tile.x * 0.74 * 0.86 - tile.y * 0.1


func _process(delta: float) -> void:
	_time += delta
	if focus != -1 or target != -1 or not targets.is_empty() or open:
		queue_redraw()


func set_ring(r: Dictionary, s: int) -> void:
	ring = r
	side = s
	queue_redraw()


func set_line(l: Array) -> void:
	line = l
	queue_redraw()


## Turns the grid from `from_side` to the current side over `secs` (call after setting the new side).
func animate_turn(from_side: int, secs := 0.45) -> void:
	var d := wrapi(side - from_side, -2, 2)
	if d == 0:
		return
	_turn = 2.0 * d
	var tw := create_tween()
	tw.tween_method(func(v: float): _turn = v; queue_redraw(), 2.0 * d, 0.0, secs).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


## The middle of cell (c, r): rows lean left as they go down.
func cell_pos(c: Vector2) -> Vector2:
	return Vector2(4.0 + 2.0 * slant + tile.x * 0.5 + c.x * pitch.x - c.y * slant, top_pad() + c.y * pitch.y)


## Where slot k's tile is drawn right now (part way round while the grid turns).
func slot_pos(k: int) -> Vector2:
	var border: Array = ALLY_BORDER if team == "ally" else FOE_BORDER
	var i := float(posmod(k - (2 * side - 1), 8)) + _turn
	var i0 := floori(i)
	var t := i - i0
	var a: Vector2i = border[posmod(i0, 8)]
	var b: Vector2i = border[posmod(i0 + 1, 8)]
	return cell_pos(Vector2(a).lerp(Vector2(b), t))


## Wild pack: tile i of the line (top to bottom), in the column facing you.
func line_pos(i: int) -> Vector2:
	return cell_pos(Vector2(2, i))


## The screen-space centre of the tile for slot / line index `i` (-2: the trainer), for pointing at it.
func tile_center(i: int) -> Vector2:
	if i == -2:
		return cell_pos(Vector2(1, 1))
	return line_pos(i) if wild else slot_pos(i)


func _draw() -> void:
	if wild:
		for i in 3:
			var b = line[i] if i < line.size() else null
			_draw_tile(line_pos(i), b, true, i == focus, i == target or i in targets, "")
		return
	var fighting := Ring.side_slots(side)
	# back to front: the top row first, so icons overlap the row above them
	var order := []
	for k in Ring.SLOTS:
		order.append(k)
	order.sort_custom(func(x, y): return slot_pos(x).y < slot_pos(y).y)
	var centre := cell_pos(Vector2(1, 1))
	var drew_trainer := false
	for k in order:
		var p := slot_pos(k)
		if not drew_trainer and p.y >= centre.y - 1.0:
			_draw_trainer(centre)
			drew_trainer = true
		var letter := ""
		if not Ring.is_corner(k):
			letter = String(Ring.slot_elements(k)[0]).substr(0, 1).to_upper()
		var faded: bool = team == "ally" and focus == -2 and k in fighting
		_draw_tile(p, ring.get(k, null), k in fighting and not faded, k == focus, k == target or k in targets, letter, faded)
	if not drew_trainer:
		_draw_trainer(centre)
	if show_shield and max_shield > 0:
		var y := cell_pos(Vector2(0, 2)).y + tile.y * 0.5 + 14.0
		var x0 := cell_pos(Vector2(0, 2)).x - tile.x * 0.5 + 6.0
		_orbs(self, Vector2(x0, y), shield, max_shield, 7.0 * (tile.y / 26.0))


## One tile: a flattened hexagon, brighter for the side facing the foe, faded out when nobody stands on it.
func _draw_tile(p: Vector2, b, fighting: bool, focused: bool, targeted: bool, letter: String, faded := false) -> void:
	var opacity := 0.25 if faded else 1.0
	var w := tile.x * 0.5
	var h := tile.y * 0.5
	var hex := PackedVector2Array([p + Vector2(-w, 0), p + Vector2(-w * 0.62, -h), p + Vector2(w * 0.62, -h), p + Vector2(w, 0),
		p + Vector2(w * 0.62, h), p + Vector2(-w * 0.62, h)])
	var used: bool = b != null
	var fill := UIKit.ACCENT.darkened(0.25) if fighting else UIKit.WINDOW_TOP
	fill.a = 0.95 if used else 0.35
	fill.a *= opacity
	var edge := UIKit.GOLD_BRIGHT if fighting else UIKit.BORDER
	edge.a = 0.9 if used else 0.3
	if fighting and not used:
		edge.a = 0.55
	edge.a *= opacity
	draw_colored_polygon(hex, fill)
	# a lighter top half, for a bevel
	var top := PackedVector2Array([hex[0], hex[1], hex[2], hex[3]])
	draw_colored_polygon(top, Color(1, 1, 1, (0.08 if used else 0.03) * opacity))
	var loop := hex.duplicate()
	loop.append(hex[0])
	draw_polyline(loop, edge, 2.0, true)
	if focused or targeted:
		var pulse := 0.55 + 0.45 * sin(_time * 7.0)
		var ring_col := UIKit.LIGHT if focused else Color("#ffe08a")
		ring_col.a = pulse
		var big := PackedVector2Array()
		for v in loop:
			big.append(p + (v - p) * 1.22)
		draw_polyline(big, ring_col, 3.0, true)
	if letter != "" and not used:
		var font := UIKit.font_body()
		var fs := UIKit.body_px(16)
		var ts := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(font, p + Vector2(-ts.x / 2.0, ts.y * 0.3), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UIKit.DIM, 0.6 * opacity))
	if b == null:
		return
	# the beast's icon stands on its tile, with a small HP bar along the tile's foot
	var isz := tile.x * 0.74
	var ir := Rect2(p - Vector2(isz * 0.5, isz * 0.86), Vector2(isz, isz))
	var down: bool = b.hp <= 0
	var icon_color := Color(0.4, 0.38, 0.42, 0.75) if down else Color.WHITE
	icon_color.a *= opacity
	draw_texture_rect(PixelArt.beast_texture(b.genes), ir, false, icon_color)
	var bw := tile.x * 0.62
	var br := Rect2(p + Vector2(-bw * 0.5, h * 0.35), Vector2(bw, maxf(3.0, tile.y * 0.16)))
	draw_rect(br.grow(1.0), Color(0, 0, 0, 0.6 * opacity))
	if not down:
		var ratio: float = clampf(float(b.hp) / maxf(1.0, float(b.max_hp())), 0.0, 1.0)
		draw_rect(Rect2(br.position, Vector2(br.size.x * ratio, br.size.y)), Color(UIKit.hp_color(ratio), opacity))
	elif not faded:
		# fallen: a bold cross over the icon
		UIKit.draw_cross(self, ir.get_center(), isz * 0.42)


## The trainer's tile in the middle: a round dais with the trainer standing on it, glowing when they're open to attack.
func _draw_trainer(p: Vector2) -> void:
	var w := tile.x * 0.5
	var h := tile.y * 0.5
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(p + Vector2(cos(a) * w * 0.8, sin(a) * h))
	var fill := UIKit.WINDOW_BOTTOM
	if open:
		fill = UIKit.ACCENT.lerp(Color.WHITE, 0.1 + 0.15 * (0.5 + 0.5 * sin(_time * 5.0)))
	draw_colored_polygon(pts, fill)
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, Color(UIKit.BORDER, 0.7), 2.0, true)
	if target == -2 or -2 in targets or focus == -2:
		var pulse := Color("#ffe08a") if target == -2 or -2 in targets else UIKit.LIGHT
		pulse.a = 0.55 + 0.45 * sin(_time * 7.0)
		var big := PackedVector2Array()
		for v in loop:
			big.append(p + (v - p) * 1.3)
		draw_polyline(big, pulse, 3.0, true)
	if trainer_icon != null:
		# the trainer, full length, standing on the dais, with a dark outline so they read over the field
		var ih := tile.x * 1.05
		var isz := Vector2(ih * float(trainer_icon.get_width()) / maxf(1.0, float(trainer_icon.get_height())), ih)
		var r := Rect2(p - Vector2(isz.x * 0.5, isz.y - h * 0.45), isz)
		for d in [Vector2(-1.5, 0), Vector2(1.5, 0), Vector2(0, -1.5), Vector2(0, 1.5)]:
			draw_texture_rect(trainer_icon, Rect2(r.position + d, r.size), false, Color(0, 0, 0, 0.75))
		draw_texture_rect(trainer_icon, r, false)
		return
	# a little person: head and shoulders
	var col := UIKit.LIGHT
	draw_circle(p + Vector2(0, -h * 1.25), h * 0.42, col)
	var body := PackedVector2Array([p + Vector2(-w * 0.32, h * 0.1), p + Vector2(-w * 0.2, -h * 0.8), p + Vector2(w * 0.2, -h * 0.8), p + Vector2(w * 0.32, h * 0.1)])
	draw_colored_polygon(body, col)


## A row of shield orbs: filled blue for each point left, hollow for each one broken.
static func _orbs(ci: CanvasItem, at: Vector2, n: int, of: int, r: float) -> void:
	for i in of:
		var c := at + Vector2(i * r * 2.6 + r, 0)
		if i < n:
			ci.draw_circle(c, r + 1.5, Color("#0b1e3a"))
			ci.draw_circle(c, r, Color("#3a8cff"))
			ci.draw_circle(c + Vector2(-r * 0.3, -r * 0.35), r * 0.38, Color("#cfe6ff"))
		else:
			ci.draw_arc(c, r, 0, TAU, 16, Color("#7aa6d8", 0.7), 2.0, true)


func _gui_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	var best := -100
	var bd := tile.x * 0.6
	var cands := [-2]
	if wild:
		cands = [0, 1, 2]
	else:
		for k in Ring.SLOTS:
			cands.append(k)
	for i in cands:
		var d := (tile_center(i) - (ev as InputEventMouseButton).position).length()
		if d < bd:
			bd = d
			best = i
	if best != -100:
		tile_tapped.emit(best)
		accept_event()
