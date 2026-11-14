extends Control
## The title screen's own top-centre HUD (art_title.gd): a carved stone plaque hanging from the top edge with the
## game's name, unlike the shared top bar (top_bar.gd) every other screen uses. It is a trapezoid, a little wider at the
## top, each side one straight slant; a groove follows its sides and bottom, and runes (world_lettering.gd's
## substitution alphabet) are cut under the name. Everything is drawn: a soft painted stone surface from a small shader,
## and a blurred black shadow.
## It slides down once the title menu is up and steps back up while the top bar has a notice to show.
const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Lettering = preload("res://scripts/gfx/world_lettering.gd")
const NAME_FONT = preload("res://ui/CormorantSC-Bold.ttf")

## the plaque's half-width along its bottom, its depth, and how much wider each side is at the top: each side is one
## straight slant from the top edge to the bottom (UI units)
const CORE := 280.0
const DEPTH := 110.0
const WING := 44.0
## the shadow: how far it drops, how far its blur spreads, its darkest alpha and how many layers make the blur
const SHADOW_DROP := 4.0
const SHADOW_BLUR := 18.0
const SHADOW_ALPHA := 0.55
const SHADOW_STEPS := 12
const NAME_SIZE := 64
const RUNE_SIZE := 20
const SLIDE := 0.45

const STONE_SHADER := """
shader_type canvas_item;
uniform vec4 light : source_color = vec4(0.83, 0.79, 0.72, 1.0);
uniform vec4 dark : source_color = vec4(0.69, 0.65, 0.59, 1.0);
uniform float depth = 118.0;
varying vec2 lp;
void vertex() { lp = VERTEX; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p = p * 2.03 + 3.1; a *= 0.5; }
	return v;
}
void fragment() {
	// soft painted mottling: broad patches, a gentle finer layer, lit from above
	float broad = fbm(lp / 46.0);
	float fine = fbm(lp / 14.0 + 11.0);
	vec3 c = mix(dark.rgb, light.rgb, smoothstep(0.2, 0.8, broad));
	c *= 0.98 + 0.04 * fine;
	c *= mix(1.07, 0.86, clamp(lp.y / depth, 0.0, 1.0));
	COLOR = vec4(c * COLOR.rgb, COLOR.a);
}
"""

var demo := false
var _stone: Control
var _carving: Control
## 0 hidden .. 1 shown
var _slide := 0.0
## the gem the name's colour was drawn from (redrawn when it changes)
var _gem := Color.TRANSPARENT


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stone = Control.new()
	_stone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = STONE_SHADER
	mat.set_shader_parameter("depth", DEPTH)
	_stone.material = mat
	add_child(_stone)
	_stone.draw.connect(_draw_stone)
	_carving = Control.new()
	_carving.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_carving)
	_carving.draw.connect(_draw_carving)
	size = Vector2((CORE + WING) * 2.0, DEPTH + 24.0)
	_stone.size = size
	_carving.size = size


func _process(delta: float) -> void:
	# (a notice in the shared top bar gets the top edge to itself for a moment)
	var want := 1.0 if not (is_instance_valid(UI.top_bar) and UI.top_bar.visible) else 0.0
	_slide = move_toward(_slide, want, delta / SLIDE)
	_place()
	if _gem != UIKit.ACCENT:
		_gem = UIKit.ACCENT
		_carving.queue_redraw()


func _place() -> void:
	var parent := get_parent_control()
	if parent == null:
		return
	var safe := UIKit.safe_rect(parent)
	var t := 1.0 - pow(1.0 - _slide, 3.0)
	position = Vector2(roundf(parent.size.x * 0.5 - size.x * 0.5), roundf(lerpf(-size.y - 8.0, safe.position.y, t)))


## The plaque's outline, centred on x = size.x / 2 (clockwise from the top left): a trapezoid, wider at the top.
func _outline() -> PackedVector2Array:
	var cx := size.x * 0.5
	var top := -1.0
	var tip := CORE + WING
	# each side runs in one straight slant from the top edge down to the bottom corner
	var right: Array[Vector2] = [Vector2(tip, top), Vector2(CORE, DEPTH)]
	var pts := PackedVector2Array()
	pts.append(Vector2(cx - tip, top))
	pts.append(Vector2(cx + tip, top))
	for p in right.slice(1):
		pts.append(Vector2(cx + p.x, p.y))
	for i in range(right.size() - 1, 0, -1):
		pts.append(Vector2(cx - right[i].x, right[i].y))
	return pts


## The outline's sides and bottom offset `inset` units inward (a true offset, so the line keeps an even distance from
## every edge, with sharp corners), as open lines that stop at the top rather than running along it.
func _inset_lines(inset: float) -> Array[PackedVector2Array]:
	# The top edge lifted well clear past both points, so its offset falls off the plaque and is cut away below, while
	# the wings' undersides keep their own slope right up to their points.
	var shape := _outline()
	var raised := PackedVector2Array([shape[0] + Vector2(-60.0, -100.0), shape[1] + Vector2(60.0, -100.0)])
	raised.append_array(shape.slice(1))
	raised.append(shape[0])
	var best := PackedVector2Array()
	for poly: PackedVector2Array in Geometry2D.offset_polygon(raised, -inset, Geometry2D.JOIN_MITER):
		if poly.size() > best.size():
			best = poly
	var lines: Array[PackedVector2Array] = []
	var n := best.size()
	if n < 3:
		return lines
	var floor_y := 1.0
	# start the walk at a point above the cut so no line wraps round the loop's start
	var start := 0
	for i in n:
		if best[i].y < floor_y:
			start = i
			break
	var cur := PackedVector2Array()
	for k in range(1, n + 1):
		var a := best[(start + k - 1) % n]
		var b := best[(start + k) % n]
		var a_in := a.y >= floor_y
		var b_in := b.y >= floor_y
		if a_in != b_in:
			var cross := a.lerp(b, (floor_y - a.y) / (b.y - a.y))
			cur.append(cross)
			if not b_in:
				lines.append(cur)
				cur = PackedVector2Array()
		if b_in:
			cur.append(b)
	if cur.size() > 1:
		lines.append(cur)
	return lines


func _shifted(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + by)
	return out


func _draw() -> void:
	# a plain black shadow, blurred: layers grown out from the outline, each faint, so it fades smoothly outward
	var shape := _shifted(_outline(), Vector2(0, SHADOW_DROP))
	for i in SHADOW_STEPS:
		var grow := SHADOW_BLUR * (1.0 - float(i) / SHADOW_STEPS)
		for poly: PackedVector2Array in Geometry2D.offset_polygon(shape, grow, Geometry2D.JOIN_ROUND):
			draw_colored_polygon(poly, Color(0, 0, 0, SHADOW_ALPHA / SHADOW_STEPS))


func _draw_stone() -> void:
	_stone.draw_colored_polygon(_outline(), Color.WHITE)


func _draw_carving() -> void:
	var c := _carving
	var cx := size.x * 0.5
	var lit := Color(1, 1, 1, 0.42)
	var cut := Color(0.24, 0.21, 0.19, 0.55)
	# a lit edge just inside the face's outline, and the carved groove inside it, both following the sides and bottom
	# at an even distance (none along the top, which meets the screen's edge)
	for line in _inset_lines(1.0):
		c.draw_polyline(line, Color(1, 1, 1, 0.22), 2.0, true)
	for line in _inset_lines(11.0):
		c.draw_polyline(_shifted(line, Vector2(0, 1.5)), lit, 2.0, true)
		c.draw_polyline(line, cut, 2.0, true)
	var rune_font: Font = Lettering.FONT
	# the name, carved deep and large
	var title := "Ruby Cocoon"
	var ts := NAME_FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE)
	var base_y := 6.0 + NAME_FONT.get_ascent(NAME_SIZE)
	var ink := UIKit.HEAD.darkened(0.35)
	c.draw_string(NAME_FONT, Vector2(cx - ts.x * 0.5, base_y + 2.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, lit)
	c.draw_string(NAME_FONT, Vector2(cx - ts.x * 0.5, base_y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, ink)
	# a band under the name: runes (or DEMO in a demo) between two rules ending in small diamonds
	var band_y := 84.0
	var band := "Demo" if demo else Lettering.encode("hatch grow merge")
	var band_font: Font = NAME_FONT if demo else rune_font
	var band_size := 24 if demo else RUNE_SIZE - 2
	var bw := band_font.get_string_size(band, HORIZONTAL_ALIGNMENT_LEFT, -1, band_size).x
	_engrave(band_font, band, Vector2(cx - bw * 0.5, band_y + band_font.get_ascent(band_size) * 0.5 - 2.0), band_size,
		ink if demo else cut, lit)
	for side: float in [-1.0, 1.0]:
		var a := cx + side * (bw * 0.5 + 14.0)
		var b := cx + side * (CORE - 66.0)
		c.draw_line(Vector2(a, band_y + 1.5), Vector2(b, band_y + 1.5), lit, 2.0, true)
		c.draw_line(Vector2(a, band_y), Vector2(b, band_y), cut, 2.0, true)
		_diamond(Vector2(b + side * 7.0, band_y), 5.0, cut, lit)


func _engrave(font: Font, text: String, at: Vector2, fs: int, ink: Color, lit: Color) -> void:
	_carving.draw_string(font, at + Vector2(0, 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, lit)
	_carving.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)


func _diamond(at: Vector2, r: float, ink: Color, lit: Color) -> void:
	var pts := PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)])
	_carving.draw_colored_polygon(_shifted(pts, Vector2(0, 1.5)), lit)
	_carving.draw_colored_polygon(pts, ink)
