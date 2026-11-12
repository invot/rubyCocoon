extends RefCounted
## The small round icons on the battle bars (floating_hud.gd), drawn as flat shapes so they stay sharp at any size.
##   - Beside an action's name on the chooser's bar: a disc in the action's colour with a white glyph.
##       an elemental attack   its element's colour (elements.gd), with the element's glyph
##       a plain attack        ATTACK grey, with claw marks (your weapons too)
##       anything else         SUPPORT navy, with a glyph for what it does (Defend's shield, a heal's cross, ...)
##   - Beside a target's name while an attack is aimed at it: a red burst with "!" when it is weak to that attack, a
##     slate shield when it resists it (its own element).
## Colour is never the only cue: every kind has its own glyph, and the two target marks have their own outlines.
const Elements = preload("res://scripts/data/elements.gd")
const MoveDB = preload("res://scripts/data/move_db.gd")

## Attacks with no element.
const ATTACK := Color("#727a88")
## Every action that isn't an attack.
const SUPPORT := Color("#34467f")
const WEAK := Color("#e0382e")
const RESIST := Color("#5b6d8a")
const GLYPH := Color.WHITE
const ELEMENT_KINDS := ["fire", "water", "earth", "air", "ghost"]
## What the move kinds other than "attack" show (move_db.gd "kind").
const MOVE_GLYPHS := {"heal": "heal", "cleanse": "heal", "revive": "heal", "buff": "buff", "shield": "defend", "taunt": "buff",
	"special": "buff", "debuff": "hex", "status": "hex"}


## The icon for a beast's move: its element for an elemental attack, "attack" for a plain one, else what it does.
static func for_move(id: String) -> String:
	var m := MoveDB.get_move(id)
	if String(m["kind"]) == "attack":
		return String(m["el"]) if String(m["el"]) in ELEMENT_KINDS else "attack"
	return String(MOVE_GLYPHS.get(String(m["kind"]), "buff"))


## Which of the three colour groups an icon belongs to: "element", "attack" or "support".
static func group(kind: String) -> String:
	return "element" if kind in ELEMENT_KINDS else ("attack" if kind == "attack" else "support")


## The disc's colour. Element colours are deepened where they are too pale to carry a white glyph.
static func color(kind: String) -> Color:
	match group(kind):
		"attack":
			return ATTACK
		"support":
			return SUPPORT
	var c := Elements.color(kind)
	var lum := c.get_luminance()
	return c.darkened(clampf((lum - 0.42) * 0.75, 0.0, 0.4))


## An action's icon, centred on `at` with radius `r`.
static func draw(canvas: CanvasItem, kind: String, at: Vector2, r: float, alpha := 1.0) -> void:
	if kind == "":
		return
	var disc := Color(color(kind), alpha)
	canvas.draw_circle(at, r, disc, true, -1.0, true)
	_glyph(canvas, kind, at, r * 0.62, Color(GLYPH, alpha), disc)


## A target's mark: "weak" (a red burst with "!") or "resist" (a slate shield with a bar), centred on `at`.
static func draw_mark(canvas: CanvasItem, mark: String, at: Vector2, r: float, alpha := 1.0) -> void:
	if mark == "weak":
		var pts := PackedVector2Array()
		for i in 16:
			var a := TAU * float(i) / 16.0 - PI * 0.5
			pts.append(at + Vector2(cos(a), sin(a)) * (r * (1.08 if i % 2 == 0 else 0.72)))
		canvas.draw_colored_polygon(pts, Color(WEAK, alpha))
		var w := maxf(1.5, r * 0.26)
		canvas.draw_line(at + Vector2(0, -r * 0.5), at + Vector2(0, r * 0.12), Color(GLYPH, alpha), w, true)
		canvas.draw_circle(at + Vector2(0, r * 0.42), w * 0.6, Color(GLYPH, alpha), true, -1.0, true)
	elif mark == "resist":
		canvas.draw_colored_polygon(_shield(at, r * 1.05), Color(RESIST, alpha))
		canvas.draw_line(at + Vector2(-r * 0.42, -r * 0.08), at + Vector2(r * 0.42, -r * 0.08), Color(GLYPH, alpha), maxf(1.5, r * 0.26), true)


static func _shield(at: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([at + Vector2(-0.8, -0.82) * r, at + Vector2(0.8, -0.82) * r, at + Vector2(0.8, 0.05) * r,
		at + Vector2(0.45, 0.65) * r, at + Vector2(0, 0.98) * r, at + Vector2(-0.45, 0.65) * r, at + Vector2(-0.8, 0.05) * r])


static func _poly(canvas: CanvasItem, at: Vector2, s: float, pts: Array, col: Color) -> void:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(at + p * s)
	canvas.draw_colored_polygon(out, col)


## The glyph inside a disc, within `s` of `at`. `back`: the disc's colour, for details cut out of the glyph.
static func _glyph(canvas: CanvasItem, kind: String, at: Vector2, s: float, col: Color, back: Color) -> void:
	var w := maxf(1.5, s * 0.34)
	match kind:
		"fire":
			_poly(canvas, at, s, [Vector2(0.05, -1.0), Vector2(0.5, -0.3), Vector2(0.72, 0.25), Vector2(0.5, 0.8), Vector2(0, 1.0),
				Vector2(-0.5, 0.8), Vector2(-0.72, 0.3), Vector2(-0.55, -0.2), Vector2(-0.25, 0.1), Vector2(-0.2, -0.5)], col)
			_poly(canvas, at, s, [Vector2(0.02, 0.1), Vector2(0.3, 0.5), Vector2(0.15, 0.82), Vector2(-0.15, 0.82), Vector2(-0.3, 0.5)], back)
		"water":
			_poly(canvas, at, s, [Vector2(0, -1.0), Vector2(0.45, -0.3), Vector2(0.7, 0.25), Vector2(0.55, 0.72), Vector2(0, 0.98),
				Vector2(-0.55, 0.72), Vector2(-0.7, 0.25), Vector2(-0.45, -0.3)], col)
		"earth":
			_poly(canvas, at, s, [Vector2(-1.0, 0.75), Vector2(-0.35, -0.55), Vector2(0.0, 0.05), Vector2(0.35, -0.85), Vector2(1.0, 0.75)], col)
		"air":
			for i in 3:
				var y := (float(i) - 1.0) * 0.6 * s
				var half := s * (0.95 if i == 1 else 0.65)
				canvas.draw_line(at + Vector2(-half, y), at + Vector2(half * 0.55, y), col, w * 0.8, true)
				canvas.draw_arc(at + Vector2(half * 0.55, y - s * 0.22), s * 0.22, -PI * 0.5, PI * 0.5, 8, col, w * 0.8, true)
		"ghost":
			_poly(canvas, at, s, [Vector2(-0.75, 0.95), Vector2(-0.75, -0.2), Vector2(-0.55, -0.72), Vector2(0, -0.98), Vector2(0.55, -0.72),
				Vector2(0.75, -0.2), Vector2(0.75, 0.95), Vector2(0.38, 0.6), Vector2(0, 0.95), Vector2(-0.38, 0.6)], col)
			for x in [-0.3, 0.3]:
				canvas.draw_circle(at + Vector2(x, -0.2) * s, s * 0.17, back, true, -1.0, true)
		"attack":
			for i in 3:
				var x := (float(i) - 1.0) * 0.55 * s
				canvas.draw_line(at + Vector2(x + s * 0.3, -s * 0.85), at + Vector2(x - s * 0.3, s * 0.85), col, w * 0.85, true)
		"defend":
			canvas.draw_colored_polygon(_shield(at, s), col)
		"heal":
			canvas.draw_line(at + Vector2(-s * 0.85, 0), at + Vector2(s * 0.85, 0), col, w * 1.25)
			canvas.draw_line(at + Vector2(0, -s * 0.85), at + Vector2(0, s * 0.85), col, w * 1.25)
		"buff", "hex":
			# stacked chevrons: up for a boost, down for something that weakens or ails
			var d := -1.0 if kind == "buff" else 1.0
			for i in 2:
				var y := (float(i) - 0.5) * 0.8 * s * d
				canvas.draw_polyline(PackedVector2Array([at + Vector2(-s * 0.75, y - d * s * 0.1), at + Vector2(0, y + d * s * 0.55), at + Vector2(s * 0.75, y - d * s * 0.1)]), col, w, true)
		"move":
			canvas.draw_line(at + Vector2(0, -s * 0.5), at + Vector2(0, s * 0.5), col, w, true)
			for d in [-1.0, 1.0]:
				_poly(canvas, at, s, [Vector2(0, d * 1.0), Vector2(-0.55, d * 0.35), Vector2(0.55, d * 0.35)], col)
		"item":
			# a potion bottle
			canvas.draw_circle(at + Vector2(0, s * 0.3), s * 0.68, col, true, -1.0, true)
			canvas.draw_line(at + Vector2(0, -s * 0.9), at + Vector2(0, -s * 0.1), col, w * 1.3)
			canvas.draw_line(at + Vector2(-s * 0.42, -s * 0.9), at + Vector2(s * 0.42, -s * 0.9), col, w * 0.8, true)
		"flute":
			# a note
			canvas.draw_circle(at + Vector2(-s * 0.3, s * 0.55), s * 0.42, col, true, -1.0, true)
			canvas.draw_line(at + Vector2(s * 0.06, s * 0.55), at + Vector2(s * 0.06, -s * 0.85), col, w * 0.8, true)
			canvas.draw_line(at + Vector2(s * 0.06, -s * 0.85), at + Vector2(s * 0.7, -s * 0.45), col, w, true)
		"watch":
			# an eye
			_poly(canvas, at, s, [Vector2(-1.0, 0), Vector2(-0.5, -0.5), Vector2(0, -0.65), Vector2(0.5, -0.5), Vector2(1.0, 0),
				Vector2(0.5, 0.5), Vector2(0, 0.65), Vector2(-0.5, 0.5)], col)
			canvas.draw_circle(at, s * 0.32, back, true, -1.0, true)
		"summon":
			# a four-pointed star
			_poly(canvas, at, s, [Vector2(0, -1.0), Vector2(0.25, -0.25), Vector2(1.0, 0), Vector2(0.25, 0.25), Vector2(0, 1.0),
				Vector2(-0.25, 0.25), Vector2(-1.0, 0), Vector2(-0.25, -0.25)], col)
		"run":
			canvas.draw_line(at + Vector2(-s * 0.9, 0), at + Vector2(s * 0.2, 0), col, w, true)
			_poly(canvas, at, s, [Vector2(1.0, 0), Vector2(0.15, -0.65), Vector2(0.15, 0.65)], col)
		_:
			canvas.draw_circle(at, s * 0.4, col, true, -1.0, true)
