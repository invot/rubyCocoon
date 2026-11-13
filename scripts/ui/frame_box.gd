extends StyleBox
## The game's one window style (the user's 2026-11-13 direction): a slightly rounded off-white box with a faint tint of
## the gem (`paper`), no border and no blur behind it, with a soft shadow under the windows. The same box, with other
## fills, is every row, button, tag, plate and item slot (see UIKit).
## - `fill` is drawn as given; `blur` (kept as the name for "a window over the scene") draws the paper instead.
## - `line` no longer draws a border; a box with `ring` set draws a thin focus ring just inside its edge instead (the
##   focused standalone button).
## - `legacy` keeps the old look for the battle HUDs, which stay as they were: a near-black box at 60% with the scene
##   blurred behind it (blur.gdshader), inside a thin white ornamental border from Kenney's Fantasy UI Borders
##   (assets/ui/kenney, CC0), drawn as a nine-patch whose cells cover a whole number of screen pixels (`unit`).

const DIR := "res://assets/ui/kenney/"
## The pack's shapes in use: [file, corner size in cells]. The art is on a 2-pixel grid; a cell is one of its squares.
const FRAMES := {"window": ["panel-border-010", 6], "row": ["panel-border-008", 5], "slot": ["panel-border-001", 5]}
const DIVIDER := "divider-003"
## cells at the divider's ornamented end that are not stretched
const DIVIDER_END := 11
const FILL_ALPHA := 0.6
## without the blur
const PLAIN_ALPHA := 0.8
const SHADER := "res://scripts/ui/blur.gdshader"

## UI units per cell of the art: a whole number of screen pixels (UIKit.set_screen_scale).
static var unit := 2.0
static var blur_on := true
## the battle HUDs' black, faintly tinted with the gem (UIKit.set_accent)
static var shade := Color(0.034, 0.005, 0.007)
## the windows' off-white, faintly tinted with the gem (UIKit.set_accent)
static var paper := Color(0.965, 0.945, 0.94)
## how rounded each kind of box is (UI units)
const RADIUS := {"window": 12.0, "row": 9.0, "slot": 8.0}
## the windows' soft shadow
const SHADOW := Color(0.08, 0.06, 0.07, 0.16)
## how opaque the paper is over the scene
const PAPER_ALPHA := 0.96
static var _tex := {}
static var _material: ShaderMaterial

## which of FRAMES
var frame := "window"
## the border's tint (alpha 0: no border)
var line := Color.WHITE
## a flat fill inside the border (alpha 0: none)
var fill := Color(0, 0, 0, 0)
## the blurred, darkened scene inside the border instead of `fill`
var blur := false
## fades a blurred inside (a flat fill and the border fade with their own colours' alpha)
var alpha := 1.0
## the old dark, bordered, blurred look (battle HUDs only)
var legacy := false
## a focus ring inside the edge (alpha 0: none)
var ring := Color(0, 0, 0, 0)
var _flat: StyleBoxFlat


func _draw(ci: RID, rect: Rect2) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	if not legacy:
		_draw_paper(ci, rect)
		return
	var t: Array = textures(frame)
	if blur and blur_on:
		RenderingServer.canvas_item_set_material(ci, material().get_rid())
		_patch(ci, rect, t[2], t[3], Color(1, 1, 1, alpha))
		_patch(ci, rect, t[1], t[3], Color(shade, FILL_ALPHA * alpha))
	elif blur:
		_patch(ci, rect, t[1], t[3], Color(shade, PLAIN_ALPHA * alpha))
	elif fill.a > 0.0:
		_patch(ci, rect, t[1], t[3], fill)
	if line.a > 0.0:
		_patch(ci, rect, t[0], t[3], line)


## The current look: a rounded flat box (the paper for a window, else its fill), with an optional focus ring.
func _draw_paper(ci: RID, rect: Rect2) -> void:
	var col := Color(paper, PAPER_ALPHA * alpha) if blur else fill
	if col.a <= 0.0 and ring.a <= 0.0:
		return
	if _flat == null:
		_flat = StyleBoxFlat.new()
		_flat.anti_aliasing = true
		_flat.corner_detail = 6
	var r: float = minf(RADIUS.get(frame, 9.0), minf(rect.size.x, rect.size.y) / 2.0)
	_flat.set_corner_radius_all(int(round(r)))
	_flat.bg_color = col
	_flat.draw_center = col.a > 0.0
	var rw := 0 if ring.a <= 0.0 else int(maxf(2.0, round(unit * 1.5)))
	_flat.set_border_width_all(rw)
	_flat.border_color = ring
	if blur and frame == "window":
		_flat.shadow_color = Color(SHADOW, SHADOW.a * alpha)
		_flat.shadow_size = 10
		_flat.shadow_offset = Vector2(0, 3)
	else:
		_flat.shadow_size = 0
	_flat.draw(ci, rect)


## A box of this kind, for a control or for draw_style_box. `pad`: the content padding (l, t, r, b).
static func make(frame_name: String, line_col: Color, fill_col := Color(0, 0, 0, 0), blurred := false, pad := Vector4.ZERO, old_look := false) -> StyleBox:
	var sb: StyleBox = load("res://scripts/ui/frame_box.gd").new()
	sb.legacy = old_look
	sb.frame = frame_name
	sb.line = line_col
	sb.fill = fill_col
	sb.blur = blurred
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	return sb


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load(SHADER)
	return _material


## A frame's textures: [its lines (white), its inside (white), its inside as the blur marker, corner size in cells].
static func textures(name: String) -> Array:
	if _tex.has(name):
		return _tex[name]
	var spec: Array = FRAMES.get(name, FRAMES["window"])
	var img := _cells(String(spec[0]))
	var w := img.get_width()
	var h := img.get_height()
	# what's outside the frame: every clear cell reachable from the edge
	var outside := {}
	var todo: Array[Vector2i] = []
	for x in w:
		todo.append(Vector2i(x, 0))
		todo.append(Vector2i(x, h - 1))
	for y in h:
		todo.append(Vector2i(0, y))
		todo.append(Vector2i(w - 1, y))
	while not todo.is_empty():
		var p: Vector2i = todo.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h or outside.has(p) or img.get_pixelv(p).a > 0.5:
			continue
		outside[p] = true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			todo.append(p + d)
	var lines := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var inside := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var marker := Image.create(w, h, false, Image.FORMAT_RGBA8)
	lines.fill(Color(1, 1, 1, 0))
	inside.fill(Color(1, 1, 1, 0))
	# (clear magenta, so a filtered edge of the marker stays magenta)
	marker.fill(Color(1, 0, 1, 0))
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.5:
				lines.set_pixel(x, y, Color.WHITE)
			elif not outside.has(Vector2i(x, y)):
				inside.set_pixel(x, y, Color.WHITE)
				marker.set_pixel(x, y, Color(1, 0, 1, 1))
	var out := [ImageTexture.create_from_image(lines), ImageTexture.create_from_image(inside),
		ImageTexture.create_from_image(marker), int(spec[1])]
	_tex[name] = out
	return out


## One of the pack's images, a pixel per cell of its 2-pixel grid.
static func _cells(file: String) -> Image:
	var src: Texture2D = load(DIR + file + ".png")
	var img := src.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_NEAREST)
	return img


static func _patch(ci: RID, rect: Rect2, tex: Texture2D, margin: int, col: Color) -> void:
	var ts := tex.get_size()
	var m := float(margin)
	var d := minf(m * unit, minf(rect.size.x, rect.size.y) / 2.0)
	var xs := [rect.position.x, rect.position.x + d, rect.end.x - d, rect.end.x]
	var ys := [rect.position.y, rect.position.y + d, rect.end.y - d, rect.end.y]
	var us := [0.0, m, ts.x - m, ts.x]
	var vs := [0.0, m, ts.y - m, ts.y]
	var rid := tex.get_rid()
	for j in 3:
		for i in 3:
			var dst := Rect2(xs[i], ys[j], xs[i + 1] - xs[i], ys[j + 1] - ys[j])
			if dst.size.x <= 0.0 or dst.size.y <= 0.0:
				continue
			RenderingServer.canvas_item_add_texture_rect_region(ci, dst, rid, Rect2(us[i], vs[j], us[i + 1] - us[i], vs[j + 1] - vs[j]), col)


## The divider's height in UI units.
static func divider_height() -> float:
	return divider_texture().get_height() * unit


static func divider_texture() -> Texture2D:
	if not _tex.has(DIVIDER):
		_tex[DIVIDER] = [ImageTexture.create_from_image(_cells(DIVIDER))]
	return _tex[DIVIDER][0]


## The pack's divider across `rect` (centred in its height), tinted: a double line with the ornament at the ends
## asked for.
static func draw_divider(ci: RID, rect: Rect2, col: Color, left_end := true, right_end := true) -> void:
	var tex := divider_texture()
	var ts := tex.get_size()
	var h := ts.y * unit
	var y := rect.position.y + (rect.size.y - h) / 2.0
	if left_end and right_end:
		var half := rect.size.x / 2.0
		_divider_piece(ci, Rect2(rect.position.x, y, half, h), tex, col, true, true)
		_divider_piece(ci, Rect2(rect.position.x + half, y, rect.size.x - half, h), tex, col, false, true)
	else:
		_divider_piece(ci, Rect2(rect.position.x, y, rect.size.x, h), tex, col, left_end, left_end or right_end)


## A stretch of the divider whose ornament (if `ornament`) is at its right end, or its left when `flip`.
static func _divider_piece(ci: RID, r: Rect2, tex: Texture2D, col: Color, flip: bool, ornament: bool) -> void:
	var ts := tex.get_size()
	var rid := tex.get_rid()
	var e := float(DIVIDER_END)
	var ew := minf(e * unit, r.size.x) if ornament else 0.0
	var line_w := r.size.x - ew
	var sign := -1.0 if flip else 1.0
	if line_w > 0.0:
		var lx := r.position.x + ew if flip else r.position.x
		RenderingServer.canvas_item_add_texture_rect_region(ci, Rect2(lx, r.position.y, line_w, r.size.y), rid, Rect2(1, 0, 2.0 * sign, ts.y), col)
	if ew > 0.0:
		var ex := r.position.x if flip else r.end.x - ew
		RenderingServer.canvas_item_add_texture_rect_region(ci, Rect2(ex, r.position.y, ew, r.size.y), rid, Rect2(ts.x - e, 0, e * sign, ts.y), col)
