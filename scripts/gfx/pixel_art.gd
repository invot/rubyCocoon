extends RefCounted
## Procedural pixel art: modular beasts, people, tiles and props.
## Beasts are assembled from body-part "genes", so merged beasts really mix their parents' parts.

const VBeast = preload("res://scripts/gfx/voxel_beast.gd")
const BeastModel = preload("res://scripts/gfx/beast_model.gd")
const BeastIcons = preload("res://scripts/gfx/beast_icons.gd")

const BW := 40
const BH := 40

static var _cache := {}
## renders merged beasts' icons (beast_icons.gd), once each
static var _painter: SubViewport = null


# ---------------------------------------------------------------- canvas helpers
class Canvas:
	var w: int
	var h: int
	var px: PackedByteArray

	func _init(_w: int, _h: int) -> void:
		w = _w
		h = _h
		px = PackedByteArray()
		px.resize(w * h)
		px.fill(0)

	func put(x: int, y: int, v: int) -> void:
		if x >= 0 and y >= 0 and x < w and y < h:
			px[y * w + x] = v

	func at(x: int, y: int) -> int:
		if x < 0 or y < 0 or x >= w or y >= h:
			return 0
		return px[y * w + x]

	func ellipse(cx: float, cy: float, rx: float, ry: float, v: int, only := -1) -> void:
		rx = maxf(rx, 0.5)
		ry = maxf(ry, 0.5)
		for y in range(int(floor(cy - ry)) - 1, int(ceil(cy + ry)) + 2):
			for x in range(int(floor(cx - rx)) - 1, int(ceil(cx + rx)) + 2):
				var dx := (x + 0.5 - cx) / rx
				var dy := (y + 0.5 - cy) / ry
				if dx * dx + dy * dy <= 1.0:
					if only < 0 or at(x, y) == only:
						put(x, y, v)

	func rect(x0: int, y0: int, x1: int, y1: int, v: int, only := -1) -> void:
		for y in range(mini(y0, y1), maxi(y0, y1) + 1):
			for x in range(mini(x0, x1), maxi(x0, x1) + 1):
				if only < 0 or at(x, y) == only:
					put(x, y, v)

	func tri(ax: float, ay: float, bx: float, by: float, cx: float, cy: float, v: int) -> void:
		var minx := int(floor(minf(ax, minf(bx, cx))))
		var maxx := int(ceil(maxf(ax, maxf(bx, cx))))
		var miny := int(floor(minf(ay, minf(by, cy))))
		var maxy := int(ceil(maxf(ay, maxf(by, cy))))
		for y in range(miny, maxy + 1):
			for x in range(minx, maxx + 1):
				var px_ := x + 0.5
				var py := y + 0.5
				var d1 := (px_ - bx) * (ay - by) - (ax - bx) * (py - by)
				var d2 := (px_ - cx) * (by - cy) - (bx - cx) * (py - cy)
				var d3 := (px_ - ax) * (cy - ay) - (cx - ax) * (py - ay)
				var neg := d1 < 0 or d2 < 0 or d3 < 0
				var pos := d1 > 0 or d2 > 0 or d3 > 0
				if not (neg and pos):
					put(x, y, v)

	func line(x0: float, y0: float, x1: float, y1: float, v: int, thick := 1) -> void:
		var steps := int(maxf(absf(x1 - x0), absf(y1 - y0))) + 1
		for i in steps + 1:
			var t := float(i) / float(steps)
			var x := int(round(lerpf(x0, x1, t)))
			var y := int(round(lerpf(y0, y1, t)))
			if thick <= 1:
				put(x, y, v)
			else:
				rect(x, y, x + thick - 1, y + thick - 1, v)


static func _to_image(c: Canvas, pal: Dictionary, shade_ids: Array, outline_dark := 0.62) -> Image:
	var img := Image.create(c.w, c.h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in c.h:
		for x in c.w:
			var v := c.at(x, y)
			if v == 0:
				continue
			var col: Color = pal.get(v, Color.MAGENTA)
			if shade_ids.has(v):
				if c.at(x, y - 1) == 0:
					col = col.lightened(0.2)
				elif c.at(x, y + 1) == 0 or c.at(x, y + 2) == 0:
					col = col.darkened(0.22)
				elif c.at(x - 1, y) == 0:
					col = col.lightened(0.08)
				elif c.at(x + 1, y) == 0:
					col = col.darkened(0.1)
			img.set_pixel(x, y, col)
	# selective outline: darker version of the neighbouring colour
	var out := img.duplicate() as Image
	for y in c.h:
		for x in c.w:
			if c.at(x, y) != 0:
				continue
			var nb := 0
			for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				var n := c.at(x + d.x, y + d.y)
				if n != 0:
					nb = n
					break
			if nb != 0:
				var base: Color = pal.get(nb, Color.BLACK)
				var oc := base.darkened(outline_dark)
				oc = oc.lerp(Color("#140c18"), 0.35)
				out.set_pixel(x, y, oc)
	return out


static func tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


# ---------------------------------------------------------------- beasts
## A beast's menu icon: a new beast's (a line's form, or a merge of them: _rig_icon()); the rendered icon of a
## legendary's PSX form (assets/psx/beasts/icons, made by tools/make_beast_icons.gd) recoloured with its genes the
## way its model is; a robot's rendered icon (assets/psx/robots/icons) as it is; beasts without a form get the old
## drawn icon.
static func beast_texture(genes: Dictionary) -> ImageTexture:
	var key := "beast:" + JSON.stringify(genes)
	if _cache.has(key):
		return _cache[key]
	var form := String(genes.get("form", ""))
	var path := "res://assets/psx/beasts/icons/%s.res" % form
	var robot := "res://assets/psx/robots/icons/%s.res" % String(genes.get("model", ""))
	var t: ImageTexture
	if BeastModel.rigged(genes):
		t = _rig_icon(genes)
	elif form != "" and ResourceLoader.exists(path):
		t = tex(_form_icon(genes, path))
	elif genes.has("model") and ResourceLoader.exists(robot):
		t = load(robot)
	else:
		t = tex(beast_image(genes))
	_cache[key] = t
	return t


## A new beast's icon: its form's (assets/beasts/icons, made by tools/make_new_beast_icons.gd; a ghost's in its
## black and purple). A merge has its own rendered the first time it's shown (beast_icons.gd), its frame's showing
## till then.
static func _rig_icon(genes: Dictionary) -> ImageTexture:
	var path := _icon_path(genes)
	if not _own_look(genes.get("recipe", {})):
		return load(path) if ResourceLoader.exists(path) else tex(beast_image(genes))
	var img := _form_icon_image(genes)
	if img == null:
		img = Image.create(BeastIcons.SIZE, BeastIcons.SIZE, false, Image.FORMAT_RGBA8)
	var t := tex(img)
	if _painter == null:
		_painter = BeastIcons.new()
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_painter)
	_painter.paint(genes, t)
	return t


## A new beast's form's icon file (a merge's frame's; a ghost's in its black and purple).
static func _icon_path(genes: Dictionary) -> String:
	return "res://assets/beasts/icons/%s%s.res" % [String(genes.get("form", "")), "_ghost" if BeastModel.ghostly(genes) else ""]


## A new beast's form's icon as an Image to draw on, or null where there's none.
static func _form_icon_image(genes: Dictionary) -> Image:
	var path := _icon_path(genes)
	if not ResourceLoader.exists(path):
		return null
	var img: Image = (load(path) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	return img


## Whether a merge looks other than its frame (given parts, or another parent's colours).
static func _own_look(recipe: Dictionary) -> bool:
	for k in recipe:
		if k != "frame" and recipe[k] != recipe.get("frame", ""):
			return true
	return false


static func _form_icon(genes: Dictionary, path: String) -> Image:
	var src: Image = (load(path) as Texture2D).get_image()
	if src.is_compressed():
		src.decompress()
	var img: Image = src.duplicate()
	img.convert(Image.FORMAT_RGBA8)
	# the icon's own spread of tones (it is lit, so brighter than the model's raw colours)
	var lums := []
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.5 and not VBeast._kept(c):
				lums.append(c.get_luminance())
	lums.sort()
	var q := func(f: float) -> float: return float(lums[clampi(int(f * (lums.size() - 1)), 0, lums.size() - 1)]) if not lums.is_empty() else 0.5
	var info := {"lo": q.call(0.06), "mid": q.call(0.5), "hi": q.call(0.94)}
	var tones := VBeast._tones(genes)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				img.set_pixel(x, y, VBeast._recolour(c, info, tones))
	return img


## A beast drawn as an Image: a new beast's form's icon (a merge's frame's: _form_icon_image()), or for the others
## the old drawing from its body-part genes.
static func beast_image(g: Dictionary) -> Image:
	if BeastModel.rigged(g):
		var icon := _form_icon_image(g)
		if icon != null:
			return icon
	var c := Canvas.new(BW, BH)
	var rng := RandomNumberGenerator.new()
	rng.seed = JSON.stringify(g).hash()
	var body: String = g.get("body", "quad")
	var a := _body_anchors(body)
	var head_c: Vector2 = a["head"]
	var hr: float = a["hr"]
	var tail: Vector2 = a["tail"]
	var back: Vector2 = a["back"]
	var hw: float = a["hw"]
	var torso: Rect2i = a["torso"]

	_draw_tail(c, String(g.get("tail", "none")), tail)
	_draw_body(c, body)
	_draw_pattern(c, String(g.get("pattern", "plain")), torso, rng)
	_draw_back(c, String(g.get("back", "none")), back, hw)
	var ears: String = g.get("ears", "none")
	if ears in ["pointed", "round", "long", "fins", "crest", "leaf"]:
		_draw_ears(c, ears, head_c, hr)
	_draw_head(c, String(g.get("head", "round")), head_c, hr, String(g.get("pattern", "plain")))
	if ears in ["horns", "antenna"]:
		_draw_ears(c, ears, head_c, hr)

	var shade: float = float(g.get("shade", 0.0))
	var c1 := Color(str(g.get("c1", "#888888")))
	var c2 := Color(str(g.get("c2", "#cccccc")))
	var c3 := Color(str(g.get("c3", "#ffffff")))
	var eye_w := Color("#f8f6ee")
	var pupil := Color("#161018")
	if shade > 0.0:
		c1 = c1.lerp(Color("#17111f"), shade)
		c2 = c2.lerp(Color("#2a2038"), shade)
		c3 = c3.lerp(Color("#b07cff"), shade)
		eye_w = Color("#ff4f8b").lerp(eye_w, 1.0 - shade)
		pupil = Color("#ffd8e8").lerp(pupil, 1.0 - shade)
	var pal := {
		1: c1, 2: c2, 3: c3, 4: eye_w, 5: pupil, 6: c1.darkened(0.6), 7: c1.darkened(0.28), 8: c2.darkened(0.25),
	}
	var img := _to_image(c, pal, [1, 2, 3, 7, 8])
	if shade > 0.3:
		_add_wisps(img, c, rng, shade)
	return img


static func _add_wisps(img: Image, c: Canvas, rng: RandomNumberGenerator, shade: float) -> void:
	var count := int(10 * shade)
	for i in count:
		for _try in 20:
			var x := rng.randi_range(1, c.w - 2)
			var y := rng.randi_range(1, c.h - 4)
			if c.at(x, y) == 0 and (c.at(x, y + 2) != 0 or c.at(x + 2, y) != 0 or c.at(x - 2, y) != 0):
				var col := Color(0.62, 0.38, 1.0, 0.55) if rng.randf() < 0.6 else Color(0.25, 1.0, 0.85, 0.45)
				img.set_pixel(x, y, col)
				if y > 0 and rng.randf() < 0.5:
					img.set_pixel(x, y - 1, Color(col, col.a * 0.6))
				break


static func _body_anchors(body: String) -> Dictionary:
	match body:
		"quad":
			return {"head": Vector2(29, 16), "hr": 6.5, "tail": Vector2(9, 25), "back": Vector2(19, 21), "hw": 8.0, "torso": Rect2i(9, 21, 21, 13)}
		"biped":
			return {"head": Vector2(20, 12), "hr": 6.5, "tail": Vector2(12, 29), "back": Vector2(17, 19), "hw": 6.0, "torso": Rect2i(12, 17, 15, 16)}
		"bird":
			return {"head": Vector2(26, 17), "hr": 5.5, "tail": Vector2(9, 25), "back": Vector2(17, 21), "hw": 7.0, "torso": Rect2i(9, 20, 19, 13)}
		"serpent":
			return {"head": Vector2(30, 15), "hr": 6.0, "tail": Vector2(4, 33), "back": Vector2(17, 25), "hw": 7.0, "torso": Rect2i(3, 22, 28, 15)}
		"blob":
			return {"head": Vector2(23, 22), "hr": 7.0, "tail": Vector2(8, 30), "back": Vector2(18, 20), "hw": 9.0, "torso": Rect2i(8, 19, 25, 19)}
		"insect":
			return {"head": Vector2(27, 21), "hr": 5.0, "tail": Vector2(5, 25), "back": Vector2(14, 20), "hw": 7.0, "torso": Rect2i(4, 20, 22, 11)}
		"fish":
			return {"head": Vector2(26, 20), "hr": 6.0, "tail": Vector2(8, 22), "back": Vector2(18, 15), "hw": 8.0, "torso": Rect2i(8, 15, 23, 14)}
		"golem":
			return {"head": Vector2(21, 11), "hr": 5.5, "tail": Vector2(8, 30), "back": Vector2(19, 15), "hw": 9.0, "torso": Rect2i(8, 15, 23, 17)}
	return _body_anchors("quad")


static func _draw_body(c: Canvas, body: String) -> void:
	match body:
		"quad":
			c.rect(13, 29, 15, 36, 7)
			c.rect(25, 29, 27, 36, 7)
			c.ellipse(19, 27, 10, 6.5, 1)
			c.rect(10, 30, 12, 37, 1)
			c.rect(22, 30, 24, 37, 1)
			c.ellipse(26, 22, 4, 5, 1)
		"biped":
			c.rect(21, 30, 23, 37, 7)
			c.line(13, 21, 10, 27, 7, 2)
			c.ellipse(19, 25, 7, 8, 1)
			c.rect(14, 30, 16, 37, 1)
			c.line(24, 21, 28, 26, 1, 2)
		"bird":
			c.line(17, 31, 16, 37, 3)
			c.line(21, 31, 22, 37, 3)
			c.put(15, 37, 3)
			c.put(23, 37, 3)
			c.ellipse(18, 26, 9, 6.5, 1)
		"serpent":
			for i in 22:
				var t := i / 21.0
				var x := 4.0 + t * 22.0
				var y := 33.0 - t * 9.0 + sin(t * PI * 2.2) * 2.5
				var r := 2.0 + t * 3.0
				c.ellipse(x, y, r, r, 1)
			c.ellipse(28, 20, 3.5, 4, 1)
		"blob":
			c.ellipse(13, 36, 3, 1.5, 7)
			c.ellipse(20, 28, 12, 9.5, 1)
			c.ellipse(26, 36, 3, 1.5, 1)
		"insect":
			for lx in [13, 18, 23]:
				c.line(lx, 27, lx - 2, 37, 6)
				c.line(lx + 1, 27, lx + 3, 37, 6)
			c.ellipse(11, 25, 7, 5.5, 1)
			c.ellipse(20, 25, 5, 4.5, 1)
		"fish":
			c.ellipse(19, 22, 11, 7, 1)
			c.tri(15, 27, 22, 27, 17, 33, 8)
		"golem":
			c.rect(12, 31, 17, 37, 7)
			c.ellipse(8, 26, 3.5, 6, 7)
			c.ellipse(19, 24, 11, 9, 1)
			c.rect(10, 22, 28, 30, 1)
			c.rect(22, 31, 27, 37, 1)
			c.ellipse(30, 26, 3.5, 6, 1)
		_:
			_draw_body(c, "quad")


static func _draw_pattern(c: Canvas, pattern: String, tr: Rect2i, rng: RandomNumberGenerator) -> void:
	match pattern:
		"spots":
			for i in 5:
				var x := rng.randi_range(tr.position.x + 2, tr.end.x - 3)
				var y := rng.randi_range(tr.position.y + 2, tr.end.y - 4)
				c.ellipse(x, y, 1.4, 1.4, 2, 1)
		"stripes":
			for x in range(tr.position.x + 2, tr.end.x, 4):
				c.rect(x, tr.position.y, x, tr.end.y - 3, 2, 1)
		"belly":
			c.ellipse(tr.position.x + tr.size.x * 0.55, tr.end.y - 3, tr.size.x * 0.33, tr.size.y * 0.3, 2, 1)
		"rings":
			for y in range(tr.position.y + 2, tr.end.y, 4):
				c.rect(tr.position.x, y, tr.end.x, y, 2, 1)


static func _draw_head(c: Canvas, head: String, hc: Vector2, r: float, pattern: String) -> void:
	var hx := hc.x
	var hy := hc.y
	match head:
		"pointy":
			c.ellipse(hx, hy, r, r * 0.9, 1)
			c.tri(hx + r - 2, hy - 1, hx + r + 4, hy + 2, hx + r - 2, hy + 4, 1)
			c.put(int(hx + r + 3), int(hy + 2), 6)
		"beak":
			c.ellipse(hx, hy, r, r, 1)
			c.tri(hx + r - 1, hy - 1, hx + r + 5, hy + 1.5, hx + r - 1, hy + 3, 3)
		"horned":
			c.ellipse(hx, hy, r, r * 0.95, 1)
			c.line(hx - 1, hy - r + 1, hx - 4, hy - r - 4, 3, 2)
			c.line(hx + 2, hy - r + 1, hx + 4, hy - r - 4, 3, 2)
		"snout":
			c.ellipse(hx, hy, r, r, 1)
			c.ellipse(hx + r + 0.5, hy + 2, 3, 2.2, 2)
			c.put(int(hx + r + 3), int(hy + 1), 6)
		"flat":
			c.ellipse(hx, hy + 1, r + 1.5, r - 1.5, 1)
		_:
			c.ellipse(hx, hy, r, r, 1)
	if pattern == "mask":
		c.rect(int(hx - r), int(hy - 2), int(hx + r), int(hy + 1), 2, 1)
	var ex := int(hx + r * 0.3)
	var ey := int(hy - 1)
	c.rect(ex, ey, ex + 1, ey + 1, 4)
	c.put(ex + 1, ey, 5)
	c.put(ex + 1, ey + 1, 5)
	if head != "beak":
		c.put(int(hx + r - 1), int(hy + 3), 6)


static func _draw_ears(c: Canvas, ears: String, hc: Vector2, r: float) -> void:
	var hx := hc.x
	var hy := hc.y
	var top := hy - r
	match ears:
		"pointed":
			c.tri(hx - 5, top + 3, hx - 3, top - 4, hx - 0.5, top + 2, 1)
			c.tri(hx, top + 3, hx + 2, top - 4, hx + 4.5, top + 2, 1)
			c.put(int(hx - 3), int(top), 2)
			c.put(int(hx + 2), int(top), 2)
		"round":
			c.ellipse(hx - 3, top + 1, 2.4, 2.4, 1)
			c.ellipse(hx + 2.5, top + 1, 2.4, 2.4, 1)
			c.put(int(hx - 3), int(top + 1), 2)
			c.put(int(hx + 2), int(top + 1), 2)
		"long":
			c.ellipse(hx - 3, top - 3, 1.7, 5, 1)
			c.ellipse(hx + 1, top - 4, 1.7, 5.5, 1)
			c.line(hx + 1, top - 7, hx + 1, top - 1, 2)
		"fins":
			c.tri(hx - r + 1, hy - 3, hx - r - 5, hy - 6, hx - r + 1, hy + 2, 2)
			c.tri(hx - 1, top + 2, hx + 1, top - 4, hx + 3, top + 2, 2)
		"horns":
			c.line(hx - 2, top + 1, hx - 5, top - 5, 3, 2)
			c.line(hx + 2, top + 1, hx + 3, top - 5, 3, 2)
		"antenna":
			c.line(hx - 1, top, hx - 3, top - 6, 6)
			c.ellipse(hx - 3, top - 6, 1.3, 1.3, 3)
			c.line(hx + 2, top, hx + 4, top - 6, 6)
			c.ellipse(hx + 4, top - 6, 1.3, 1.3, 3)
		"crest":
			for i in 3:
				var x := hx - 4 + i * 2.6
				c.tri(x - 1.5, top + 2, x, top - 3 - (i % 2) * 2, x + 1.5, top + 2, 3)
		"leaf":
			c.ellipse(hx - 1, top - 2, 2, 4, 2)
			c.ellipse(hx + 3, top - 1, 3, 1.6, 2)


static func _draw_tail(c: Canvas, tail: String, t: Vector2) -> void:
	var tx := t.x
	var ty := t.y
	match tail:
		"fluffy":
			c.ellipse(tx - 4, ty - 4, 4, 6.5, 1)
			for y in range(int(ty - 10), int(ty + 3), 3):
				c.rect(int(tx - 9), y, int(tx), y, 2, 1)
		"flame":
			c.tri(tx + 1, ty, tx - 6, ty - 10, tx - 3, ty + 3, 3)
			c.tri(tx + 1, ty - 1, tx - 9, ty - 4, tx - 2, ty + 3, 3)
			c.tri(tx, ty, tx - 3, ty - 6, tx - 1, ty + 2, 4)
		"fin":
			c.tri(tx + 1, ty, tx - 7, ty - 6, tx - 7, ty + 6, 2)
		"spike":
			c.tri(tx + 1, ty - 1, tx - 9, ty + 1, tx + 1, ty + 3, 1)
			c.tri(tx - 3, ty, tx - 5, ty - 4, tx - 7, ty + 1, 3)
		"long":
			c.line(tx, ty, tx - 5, ty + 2, 1, 2)
			c.line(tx - 5, ty + 2, tx - 9, ty - 2, 1, 1)
			c.ellipse(tx - 9, ty - 3, 1.6, 1.6, 3)
		"feather":
			c.ellipse(tx - 4, ty - 3, 4.5, 1.7, 2)
			c.ellipse(tx - 5, ty, 5, 1.7, 3)
			c.ellipse(tx - 3, ty + 3, 3.8, 1.5, 2)
		"leaf":
			c.ellipse(tx - 4, ty - 2, 4.5, 2.2, 2)
			c.line(tx - 8, ty - 2, tx, ty - 2, 8)


static func _draw_back(c: Canvas, back: String, b: Vector2, hw: float) -> void:
	var bx := b.x
	var by := b.y
	match back:
		"wings":
			c.ellipse(bx - 2, by - 5, 7, 4, 2)
			c.tri(bx - 9, by - 5, bx - 12, by - 12, bx - 1, by - 8, 2)
			c.line(bx - 8, by - 5, bx + 3, by - 5, 8)
			c.line(bx - 9, by - 8, bx - 2, by - 8, 3)
		"spikes":
			for i in 4:
				var x := bx - hw + 2 + i * (hw * 2 - 4) / 3.0
				c.tri(x - 2, by + 1, x, by - 5, x + 2, by + 1, 3)
		"shell":
			c.ellipse(bx, by + 1, hw - 1, 5, 2)
			c.line(bx - hw + 3, by + 1, bx + hw - 3, by + 1, 8)
			c.line(bx - 3, by - 3, bx - 3, by + 4, 8)
			c.line(bx + 3, by - 3, bx + 3, by + 4, 8)
		"crystals":
			for i in 3:
				var x := bx - 4 + i * 4
				var top := by - 7 + (i % 2) * 2
				c.tri(x - 2, by + 1, x, top, x + 2, by + 1, 3)
				c.put(int(x), int(top + 2), 4)
		"leaves":
			for i in 3:
				c.ellipse(bx - 5 + i * 5, by - 1 - (i % 2), 2.8, 1.7, 2)
		"flames":
			for i in 3:
				var x := bx - 5 + i * 5
				c.tri(x - 2.5, by + 1, x + (i % 2), by - 6 - (i % 2) * 2, x + 2.5, by + 1, 3)
				c.put(int(x), int(by - 1), 4)
		"fin":
			c.tri(bx - 4, by + 1, bx + 1, by - 7, bx + 4, by + 1, 2)


# ---------------------------------------------------------------- people
## look: skin, hair, shirt, pants, hat (optional), hat_style
static func person_texture(look: Dictionary, dir: int, frame: int) -> ImageTexture:
	var key := "person:%s:%d:%d" % [JSON.stringify(look), dir, frame]
	if _cache.has(key):
		return _cache[key]
	var c := Canvas.new(16, 24)
	# legs
	if dir == 2:
		var off := 0
		if frame == 1:
			off = 1
		elif frame == 2:
			off = -1
		c.rect(6 - off, 17, 7 - off, 21, 8)
		c.rect(8 + off, 17, 9 + off, 21, 2)
		c.rect(6 - off, 22, 7 - off, 22, 6)
		c.rect(8 + off, 22, 10 + off, 22, 6)
	else:
		var ly := 21 if frame != 1 else 20
		var ry := 21 if frame != 2 else 20
		c.rect(5, 17, 6, ly, 2)
		c.rect(9, 17, 10, ry, 2)
		c.rect(5, ly + 1, 6, ly + 1, 6)
		c.rect(9, ry + 1, 10, ry + 1, 6)
	# body
	if dir == 2:
		c.rect(5, 10, 10, 17, 1)
		var sw := 0
		if frame == 1:
			sw = 1
		elif frame == 2:
			sw = -1
		c.rect(7 + sw, 11, 8 + sw, 15, 9)
		c.put(7 + sw, 16, 4)
	else:
		c.rect(4, 10, 11, 17, 1)
		c.rect(3, 11, 3, 15, 9)
		c.rect(12, 11, 12, 15, 9)
		c.put(3, 16, 4)
		c.put(12, 16, 4)
		c.rect(4, 16, 11, 16, 10)
	# head
	c.rect(4, 2, 11, 9, 4)
	c.put(4, 2, 0)
	c.put(11, 2, 0)
	c.put(4, 9, 0)
	c.put(11, 9, 0)
	match dir:
		0:
			c.rect(4, 1, 11, 3, 3)
			c.rect(4, 4, 4, 6, 3)
			c.rect(11, 4, 11, 6, 3)
			c.put(6, 6, 5)
			c.put(9, 6, 5)
		1:
			c.rect(4, 1, 11, 8, 3)
		2:
			c.rect(4, 1, 11, 3, 3)
			c.rect(4, 4, 7, 7, 3)
			c.put(10, 6, 5)
	if look.has("hat"):
		c.rect(3, 1, 12, 2, 7)
		c.rect(5, 0, 10, 0, 7)
		if dir == 2:
			c.rect(11, 2, 13, 2, 7)
	var shirt := Color(str(look.get("shirt", "#c8402f")))
	var pal := {
		1: shirt, 2: Color(str(look.get("pants", "#2e3448"))), 3: Color(str(look.get("hair", "#5a3a20"))),
		4: Color(str(look.get("skin", "#f0c8a0"))), 5: Color("#1a1018"), 6: Color("#2a2020"),
		7: Color(str(look.get("hat", "#5a5a66"))), 8: Color(str(look.get("pants", "#2e3448"))).darkened(0.3),
		9: shirt.darkened(0.15), 10: shirt.darkened(0.45),
	}
	var t := tex(_to_image(c, pal, [1, 2, 3, 7, 9], 0.7))
	_cache[key] = t
	return t


# ---------------------------------------------------------------- tiles & props
static func _noise_tile(base: Color, var_amt: float, seed_v: int, size := 16) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for y in size:
		for x in size:
			var v := rng.randf_range(-var_amt, var_amt)
			img.set_pixel(x, y, base.lightened(v) if v > 0 else base.darkened(-v))
	return img


static func tile_texture(kind: String, biome: Dictionary) -> ImageTexture:
	var key := "tile:%s:%s" % [kind, biome.get("id", "")]
	if _cache.has(key):
		return _cache[key]
	var img: Image
	var rng := RandomNumberGenerator.new()
	rng.seed = key.hash()
	var grass := Color(str(biome.get("grass", "#5f9f43")))
	match kind:
		"grass":
			img = _noise_tile(grass, 0.06, rng.randi())
			for i in 14:
				var x := rng.randi_range(0, 15)
				var y := rng.randi_range(1, 15)
				img.set_pixel(x, y, grass.darkened(0.18))
				img.set_pixel(x, y - 1, grass.darkened(0.1))
			for i in 6:
				img.set_pixel(rng.randi_range(0, 15), rng.randi_range(0, 15), grass.lightened(0.18))
		"flowers":
			img = _noise_tile(grass, 0.06, rng.randi())
			var cols := [Color("#ff5a6a"), Color("#ffe060"), Color("#ffffff"), Color("#a080ff")]
			for i in 5:
				var x := rng.randi_range(1, 14)
				var y := rng.randi_range(1, 14)
				var fc: Color = cols[rng.randi_range(0, cols.size() - 1)]
				img.set_pixel(x, y, fc)
				img.set_pixel(x + 1, y, fc.darkened(0.2))
				img.set_pixel(x, y + 1, fc.darkened(0.2))
				img.set_pixel(x - 1, y, fc.darkened(0.1))
				img.set_pixel(x, y - 1, fc.lightened(0.2))
		"path":
			var pc := Color("#b89a6a")
			if biome.get("id", "") in ["snow"]:
				pc = Color("#c8c0b8")
			elif biome.get("id", "") in ["volcanic", "ashland", "twilight"]:
				pc = Color("#7a6a5a")
			img = _noise_tile(pc, 0.07, rng.randi())
			for i in 7:
				var x := rng.randi_range(0, 14)
				var y := rng.randi_range(0, 14)
				img.set_pixel(x, y, pc.darkened(0.25))
				img.set_pixel(x + 1, y, pc.darkened(0.15))
				img.set_pixel(x, y + 1, pc.lightened(0.1))
		"sand":
			img = _noise_tile(Color("#e8d6a0"), 0.06, rng.randi())
		"plaza":
			var sc := Color("#b8b0a0")
			img = _noise_tile(sc, 0.04, rng.randi())
			for y in 16:
				for x in 16:
					var row := y / 8
					var ox := 4 if row % 2 == 1 else 0
					if y % 8 == 0 or (x + ox) % 8 == 0:
						img.set_pixel(x, y, sc.darkened(0.25))
					elif y % 8 == 1:
						img.set_pixel(x, y, sc.lightened(0.08))
		"water":
			var wc := Color("#3a86d8")
			img = _noise_tile(wc, 0.03, rng.randi())
			for i in 6:
				var x := rng.randi_range(0, 12)
				var y := rng.randi_range(0, 15)
				for k in 3:
					img.set_pixel(x + k, y, wc.lightened(0.3))
		"lava":
			var lc := Color("#ff6a20")
			img = _noise_tile(lc, 0.12, rng.randi())
			for i in 8:
				img.set_pixel(rng.randi_range(0, 15), rng.randi_range(0, 15), Color("#ffe060"))
		"rock":
			var rc := Color(str(biome.get("rock", "#8a8a80")))
			img = _noise_tile(rc, 0.07, rng.randi())
			for i in 3:
				var x := rng.randi_range(1, 13)
				var y := rng.randi_range(1, 13)
				for k in 4:
					img.set_pixel(clampi(x + k, 0, 15), clampi(y + (k % 2), 0, 15), rc.darkened(0.35))
			for x in 16:
				img.set_pixel(x, 0, rc.lightened(0.2))
		"wood":
			var wd := Color("#9a6a40")
			img = _noise_tile(wd, 0.05, rng.randi())
			for y in 16:
				for x in 16:
					if y % 4 == 0:
						img.set_pixel(x, y, wd.darkened(0.35))
			for i in 4:
				img.set_pixel(rng.randi_range(0, 15), rng.randi_range(0, 15), wd.darkened(0.2))
		"brick":
			var bc := Color("#e8dcc0")
			img = _noise_tile(bc, 0.03, rng.randi())
			for y in 16:
				for x in 16:
					var row := y / 4
					var ox := 4 if row % 2 == 1 else 0
					if y % 4 == 0 or (x + ox) % 8 == 0:
						img.set_pixel(x, y, bc.darkened(0.2))
		"roof":
			var rf := Color("#ffffff")
			img = _noise_tile(rf, 0.03, rng.randi())
			for y in 16:
				for x in 16:
					if y % 4 == 3:
						img.set_pixel(x, y, rf.darkened(0.35))
					elif (x + (y / 4) * 2) % 4 == 0:
						img.set_pixel(x, y, rf.darkened(0.15))
		"snow":
			img = _noise_tile(Color("#eef4fa"), 0.03, rng.randi())
		_:
			img = _noise_tile(Color.MAGENTA, 0.0, 1)
	var t := tex(img)
	_cache[key] = t
	return t


static func tallgrass_texture(biome: Dictionary) -> ImageTexture:
	var key := "tallgrass:" + str(biome.get("id", ""))
	if _cache.has(key):
		return _cache[key]
	var grass := Color(str(biome.get("grass", "#5f9f43")))
	if biome.get("id", "") == "snow":
		grass = Color("#7a9a70")
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = key.hash()
	for i in 14:
		var x := rng.randi_range(0, 15)
		var hgt := rng.randi_range(6, 15)
		var lean := rng.randf_range(-0.3, 0.3)
		var col := grass.darkened(rng.randf_range(0.0, 0.3))
		for k in hgt:
			var xx := clampi(int(x + lean * k), 0, 15)
			var yy := 15 - k
			var cc := col.lightened(0.25) if k >= hgt - 2 else col
			img.set_pixel(xx, yy, cc)
	var t := tex(img)
	_cache[key] = t
	return t


static func tree_texture(kind: String, canopy_hex: String) -> ImageTexture:
	var key := "tree:%s:%s" % [kind, canopy_hex]
	if _cache.has(key):
		return _cache[key]
	var c := Canvas.new(32, 44)
	var rng := RandomNumberGenerator.new()
	rng.seed = key.hash()
	match kind:
		"pine", "snowpine":
			c.rect(14, 34, 17, 43, 2)
			for i in 4:
				var y := 8 + i * 7
				var hwid := 5.0 + i * 3.0
				c.tri(16 - hwid, y + 9, 16, y - 4, 16 + hwid, y + 9, 1)
			if kind == "snowpine":
				for i in 4:
					var y := 8 + i * 7
					var hwid := 5.0 + i * 3.0
					c.tri(16 - hwid * 0.5, y + 2, 16, y - 4, 16 + hwid * 0.5, y + 2, 3)
		"palm":
			c.line(15, 43, 18, 14, 2, 3)
			for a in [-2.6, -1.9, -1.2, -0.5, 0.2]:
				var ex := 17 + cos(a) * 13
				var ey := 14 + sin(a) * 4 + 6
				c.line(17, 13, ex, ey, 1, 2)
				c.line(17, 13, 34 - ex, ey, 1, 2)
			c.ellipse(17, 13, 3, 2.5, 1)
		"bush":
			c.ellipse(16, 34, 13, 9, 1)
			c.ellipse(9, 37, 7, 6, 1)
			c.ellipse(23, 37, 7, 6, 1)
			for i in 6:
				c.ellipse(rng.randi_range(6, 26), rng.randi_range(28, 40), 2, 1.5, 3)
		"dead":
			c.line(15, 43, 16, 10, 2, 3)
			c.line(16, 22, 8, 12, 2, 2)
			c.line(17, 18, 25, 9, 2, 2)
			c.line(16, 14, 12, 5, 2, 1)
			for i in 6:
				c.ellipse(rng.randi_range(8, 24), rng.randi_range(6, 20), 2.5, 2, 1)
		_:
			c.rect(14, 30, 17, 43, 2)
			c.ellipse(16, 18, 13, 11, 1)
			c.ellipse(10, 23, 7, 6, 1)
			c.ellipse(22, 23, 7, 6, 1)
			c.ellipse(16, 10, 8, 7, 1)
			for i in 5:
				c.ellipse(rng.randi_range(7, 25), rng.randi_range(8, 26), 2.5, 2, 3)
	var canopy := Color(canopy_hex)
	var pal := {1: canopy, 2: Color("#6a4a30"), 3: canopy.lightened(0.18)}
	if kind == "snowpine":
		pal[3] = Color("#f4f8ff")
	var t := tex(_to_image(c, pal, [1, 2, 3], 0.55))
	_cache[key] = t
	return t


## Interior surfaces. `tint` is the room's wall colour (or rug colour for "rug").
static func room_texture(kind: String, tint: Color) -> ImageTexture:
	var key := "room:%s:%s" % [kind, tint.to_html(false)]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = key.hash()
	var img: Image
	match kind:
		"floor_wood":
			var wd := Color("#a8764a")
			img = _noise_tile(wd, 0.04, rng.randi())
			for y in 16:
				for x in 16:
					if y % 4 == 0:
						img.set_pixel(x, y, wd.darkened(0.3))
					elif (x + (y / 4) * 5) % 16 == 0:
						img.set_pixel(x, y, wd.darkened(0.22))
			for i in 6:
				img.set_pixel(rng.randi_range(0, 15), rng.randi_range(0, 15), wd.darkened(0.12))
		"floor_tile":
			var a := Color("#d8d0c4")
			var b := Color("#b8aea0")
			img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
			for y in 16:
				for x in 16:
					var c := a if ((x / 8) + (y / 8)) % 2 == 0 else b
					if x % 8 == 0 or y % 8 == 0:
						c = c.darkened(0.15)
					img.set_pixel(x, y, c)
		"wallpaper":
			img = _noise_tile(tint, 0.02, rng.randi())
			for y in 16:
				for x in 16:
					if x % 8 == 3:
						img.set_pixel(x, y, tint.darkened(0.08))
					if y == 15 or y == 14:
						img.set_pixel(x, y, tint.darkened(0.35))
		"rug":
			img = _noise_tile(tint, 0.05, rng.randi())
			for y in 16:
				for x in 16:
					if x == 1 or x == 14 or y == 1 or y == 14:
						img.set_pixel(x, y, Color("#f0d890"))
					elif (x + y) % 6 == 0 and x > 2 and x < 13 and y > 2 and y < 13:
						img.set_pixel(x, y, tint.lightened(0.2))
		"books":
			img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
			img.fill(Color("#5a3a26"))
			var cols := [Color("#c84a3a"), Color("#3a6ab0"), Color("#4a9a5a"), Color("#d8b040"), Color("#8a4aa0"), Color("#e8e0d0")]
			for shelf in 3:
				var y0 := 1 + shelf * 5
				var x := 1
				while x < 15:
					var bw := rng.randi_range(1, 2)
					var bh := rng.randi_range(3, 4)
					var c: Color = cols[rng.randi_range(0, cols.size() - 1)]
					for yy in range(y0 + 4 - bh, y0 + 4):
						for xx in range(x, mini(15, x + bw)):
							img.set_pixel(xx, yy, c)
					x += bw
				for xx in 16:
					img.set_pixel(xx, y0 + 4, Color("#3a2416"))
		"shelf":
			img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
			img.fill(Color("#6a4a30"))
			var jar := [Color("#e05a5a"), Color("#5ad0a0"), Color("#f0d050"), Color("#6a8af0"), Color("#d080e0")]
			for shelf in 3:
				var y0 := 1 + shelf * 5
				for x in range(1, 15, 3):
					var c: Color = jar[rng.randi_range(0, jar.size() - 1)]
					img.set_pixel(x, y0 + 1, c.lightened(0.3))
					img.set_pixel(x, y0 + 2, c)
					img.set_pixel(x + 1, y0 + 2, c)
					img.set_pixel(x, y0 + 3, c.darkened(0.2))
					img.set_pixel(x + 1, y0 + 3, c.darkened(0.2))
				for xx in 16:
					img.set_pixel(xx, y0 + 4, Color("#3a2416"))
		"board":
			img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
			img.fill(Color("#a07848"))
			for i in 7:
				var x0 := rng.randi_range(1, 11)
				var y0 := rng.randi_range(1, 11)
				var pc := Color("#f4eedc") if rng.randf() < 0.7 else Color("#f0e080")
				for yy in range(y0, y0 + 4):
					for xx in range(x0, x0 + 4):
						img.set_pixel(xx, yy, pc)
				img.set_pixel(x0 + 1, y0, Color("#c83a3a"))
				img.set_pixel(x0 + 1, y0 + 2, Color("#5a5a5a"))
				img.set_pixel(x0 + 2, y0 + 2, Color("#5a5a5a"))
		_:
			img = _noise_tile(tint, 0.03, 1)
	var t := tex(img)
	_cache[key] = t
	return t


static func icon_texture(kind: String) -> ImageTexture:
	## Small 12x12 icons: item bag, sparkle, note.
	var key := "icon:" + kind
	if _cache.has(key):
		return _cache[key]
	var c := Canvas.new(12, 12)
	var pal := {}
	match kind:
		"bag":
			c.ellipse(6, 7.5, 4.5, 4, 1)
			c.rect(4, 2, 7, 3, 2)
			c.rect(5, 6, 6, 7, 3)
			pal = {1: Color("#e05a3a"), 2: Color("#a03a2a"), 3: Color("#ffe080")}
		"note":
			c.ellipse(4, 9, 2.5, 2, 1)
			c.rect(6, 1, 6, 9, 1)
			c.rect(6, 1, 9, 2, 1)
			pal = {1: Color("#ffe080")}
		_:
			c.rect(5, 1, 6, 10, 1)
			c.rect(1, 5, 10, 6, 1)
			pal = {1: Color("#ffffff")}
	var t := tex(_to_image(c, pal, [1], 0.6))
	_cache[key] = t
	return t


static func shadow_texture() -> ImageTexture:
	var key := "shadow"
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var d := Vector2(x - 7.5, y - 7.5).length() / 8.0
			img.set_pixel(x, y, Color(0, 0, 0, clampf(1.0 - d, 0.0, 1.0) * 0.55))
	var t := tex(img)
	_cache[key] = t
	return t
