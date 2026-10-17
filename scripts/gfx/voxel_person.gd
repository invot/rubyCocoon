extends RefCounted
## Chibi low-poly people (player, NPCs), PS1 style. Each part is its own mesh on a pivot so the rig can walk.
## look: skin, hair, shirt, pants, hat (optional), hair_style (0-3), outfit ("plain"/"coat"/"armor"/"robe"/"apron"/"jacket"/"uniform")
## Hero extras (all optional): hat_style "cap" (a plain baseball cap), face "hero" (brows, grin, blush),
## "tee" + "trim" (jacket inner shirt and gold bands), "backpack", "gloves", "shoes" (sneakers).
## Staff "uniform": a short-sleeved polo with a "trim" collar and cuffs, a "badge" name tag and an optional half
## "apron"; staff hat_styles are "visor", "soda" (a diner paper hat with a "trim" stripe) and "band" (a headband).
## Rig faces +Z; rotate the "Body" node to face other directions.
##
## The head is a smooth low-poly head with a painted face, low-poly hair and hats. The outfit is still drawn as a small
## pixel pattern per part (the torso's front, each limb from shoulder to hand): the torso wears its front as a
## texture on a rounded body, and arms and legs are tubes coloured band by band from their patterns, so sleeves, cuffs,
## gloves and sneakers carry over.

const VM = preload("res://scripts/gfx/voxel_mesher.gd")
const LP = preload("res://scripts/gfx/lp_builder.gd")
const VS := 0.062
## The head's size: it sits on the shoulders (its origin is the base of the neck) and is centred HEAD_C above it.
const HEAD_C := Vector3(0, 0.25, 0)
const HEAD_R := Vector3(0.265, 0.25, 0.255)

static var _cache := {}


static func _parts(look: Dictionary) -> Dictionary:
	var key := JSON.stringify(look)
	if _cache.has(key):
		return _cache[key]
	var skin := Color(str(look.get("skin", "#f0c8a0")))
	var hair := Color(str(look.get("hair", "#5a3a20")))
	var shirt := Color(str(look.get("shirt", "#c8402f")))
	var pants := Color(str(look.get("pants", "#2e3448")))
	var outfit: String = look.get("outfit", "plain")
	var style := int(look.get("hair_style", JSON.stringify(look).hash() % 4))
	var has_hat := look.has("hat")
	var hatc := Color(str(look.get("hat", "#5a5a66")))
	var hat_style: String = look.get("hat_style", "")
	var cap := hat_style == "cap"
	var trim := Color(str(look.get("trim", "#ffd071")))
	var hero_face: bool = look.get("face", "") == "hero"

	# ---- torso (8 x 9 x 4, or 8 x 9 x 6 with a backpack behind it)
	var pack: bool = look.has("backpack")
	var zo := 2 if pack else 0
	var t := VM.Grid.new(8, 9, 4 + zo)
	var SH := t.add_color(shirt)
	var SHD := t.add_color(shirt.darkened(0.3))
	var BL := t.add_color(pants.darkened(0.35))
	var BK := t.add_color(Color("#e8c060"))
	var AP := t.add_color(Color("#f0ece0"))
	var fz := 3 + zo
	t.box(0, 0, zo, 7, 8, fz, SH)
	t.box(0, 0, zo, 7, 1, fz, BL)
	t.set_v(3, 1, fz, BK)
	t.set_v(4, 1, fz, BK)
	t.box(2, 8, fz, 5, 8, fz, SHD)
	if outfit == "jacket":
		var TE := t.add_color(Color(str(look.get("tee", "#f4f0e8"))))
		var TR := t.add_color(trim)
		var TRD := t.add_color(trim.darkened(0.25))
		# open front over a tee, a gold hem band, raised collar and a chest badge
		t.box(3, 2, fz, 4, 7, fz, TE)
		t.box(0, 2, zo, 7, 2, fz, TR)
		t.box(2, 3, fz, 2, 7, fz, SHD)
		t.box(5, 3, fz, 5, 7, fz, SHD)
		t.box(1, 8, fz, 2, 8, fz, TRD)
		t.box(5, 8, fz, 6, 8, fz, TRD)
		t.box(3, 8, fz, 4, 8, fz, TE)
		t.set_v(6, 6, fz, TR)
		t.set_v(6, 5, fz, TRD)
		# shoulder stripes
		t.box(0, 7, zo, 0, 8, fz, TR)
		t.box(7, 7, zo, 7, 8, fz, TR)
	if pack:
		var PK := t.add_color(Color(str(look["backpack"])))
		var PKL := t.add_color(Color(str(look["backpack"])).lightened(0.2))
		var PKD := t.add_color(Color(str(look["backpack"])).darkened(0.35))
		var BU := t.add_color(Color("#ffd071"))
		t.box(1, 2, 0, 6, 7, 1, PK)
		t.box(1, 6, 0, 6, 7, 0, PKL)
		t.box(1, 7, 1, 6, 7, 1, PKL)
		t.set_v(3, 5, 0, BU)
		t.set_v(4, 5, 0, BU)
		t.box(1, 2, 0, 6, 2, 0, PKD)
		# straps over the shoulders and down the front
		t.box(1, 8, zo, 1, 8, fz, PKD)
		t.box(6, 8, zo, 6, 8, fz, PKD)
		t.box(1, 4, fz, 1, 7, fz, PKD)
		t.box(6, 4, fz, 6, 7, fz, PKD)
	match outfit:
		"coat":
			t.box(3, 2, fz, 4, 7, fz, SHD)
			t.box(0, 0, zo, 0, 8, fz, SHD)
			t.box(7, 0, zo, 7, 8, fz, SHD)
		"armor":
			t.box(1, 3, fz, 6, 7, fz, SHD)
			t.box(0, 7, zo, 7, 8, fz, SHD)
		"apron":
			t.box(1, 0, fz, 6, 6, fz, AP)
		"robe":
			t.box(3, 0, fz, 4, 8, fz, BK)
		"jacket":
			pass
		"uniform":
			# collar round an open neck, a short button placket and a name badge on the left of the chest
			var UTR := t.add_color(trim)
			t.box(1, 8, zo, 6, 8, fz, UTR)
			t.box(3, 8, fz, 4, 8, fz, t.add_color(skin))
			t.set_v(2, 7, fz, UTR)
			t.set_v(5, 7, fz, UTR)
			t.box(3, 5, fz, 3, 7, fz, SHD)
			t.set_v(3, 6, fz, UTR)
			t.box(5, 5, fz, 6, 6, fz, t.add_color(Color(str(look.get("badge", "#ffe070")))))
			t.box(5, 6, fz, 6, 6, fz, t.add_color(Color(str(look.get("badge", "#ffe070"))).lightened(0.35)))
			if look.has("apron"):
				# a half apron tied round the waist, with a pocket
				var UA := t.add_color(Color(str(look["apron"])))
				var UAD := t.add_color(Color(str(look["apron"])).darkened(0.2))
				t.box(0, 3, zo, 7, 3, fz, UAD)
				t.box(1, 0, fz, 6, 3, fz, UA)
				t.box(3, 1, fz, 4, 2, fz, UAD)
		_:
			t.box(3, 3, fz, 3, 7, fz, SHD)

	# ---- arm (2 x 9 x 3), hand at the bottom
	var arm := VM.Grid.new(2, 9, 3)
	var AS := arm.add_color(shirt)
	var AK := arm.add_color(skin)
	arm.box(0, 2, 0, 1, 8, 2, AS)
	arm.box(0, 0, 0, 1, 1, 2, AK)
	if outfit == "robe":
		arm.box(0, 1, 0, 1, 3, 2, AS)
	if outfit == "jacket":
		# a ribbed cuff a shade darker than the jacket
		arm.box(0, 2, 0, 1, 2, 2, arm.add_color(shirt.darkened(0.18)))
	elif outfit == "uniform":
		# short sleeves with a cuff in the collar colour
		arm.box(0, 2, 0, 1, 4, 2, AK)
		arm.box(0, 5, 0, 1, 5, 2, arm.add_color(trim))
	if look.has("gloves"):
		var GL := arm.add_color(Color(str(look["gloves"])))
		arm.box(0, 1, 0, 1, 1, 2, GL)
		arm.set_v(0, 0, 1, GL)

	# ---- leg (3 x 9 x 3), shoe at the bottom
	var leg := VM.Grid.new(3, 9, 4)
	var LP := leg.add_color(pants)
	var LS := leg.add_color(Color("#2a2020"))
	leg.box(0, 2, 0, 2, 8, 2, LP)
	if look.has("shoes"):
		var SC := leg.add_color(Color(str(look["shoes"])))
		var SW := leg.add_color(Color("#f4f0e8"))
		leg.box(0, 2, 0, 2, 2, 2, leg.add_color(pants.lightened(0.18)))
		leg.box(0, 1, 0, 2, 1, 3, SC)
		leg.box(0, 0, 0, 2, 0, 3, SW)
		leg.set_v(1, 1, 3, SW)
		leg.set_v(1, 1, 2, SW)
	else:
		leg.box(0, 0, 0, 2, 1, 2, LS)
		leg.box(0, 0, 3, 2, 0, 3, LS)
	if outfit == "robe":
		leg.box(0, 2, 0, 2, 8, 2, leg.add_color(shirt))

	var parts := {
		"head": _head(look, skin, hair, hatc, outfit, style, has_hat, hat_style, trim, hero_face),
		"torso": _torso(t, fz, pack, look, shirt),
		"arm": _arm(arm, skin, _top_fabric(outfit)),
		"leg": _leg(leg, look.has("shoes"), outfit == "robe"),
	}
	_cache[key] = parts
	return parts


static func _mat() -> Material:
	return VM.materials()[0]


# ---------------------------------------------------------------- head
## Eye colours people are born with (the look can name its own with "eyes").
const EYE_COLORS := ["#6a4028", "#3a6ac8", "#3a8a5a", "#b07a2a", "#7a4ab0", "#2a8a9a", "#a8483a"]


## The anime face painted on the front of the head (48 x 48, covering the head's front from chin to crown). Big
## eyes: a thick upper lash that flicks out at the outer corner, a tall iris shading from deep to clear round a large
## pupil, a big sparkle and a small one, a fine lower lash. A small mouth and soft blush below; spiky bangs fall
## over the forehead (none under a hood). The hero gets a wide grin and rosier cheeks.
static func _face_tex(skin: Color, hair: Color, iris: Color, hero: bool, bangs: bool, seed: int) -> ImageTexture:
	const N := 48
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	img.fill(skin)
	var lash := Color("#24161e")
	var white := Color("#fdfaf6")
	var put := func(x: int, y: int, c: Color) -> void:
		if x >= 0 and y >= 0 and x < N and y < N:
			img.set_pixel(x, y, c)
	# blush first, so the eyes and lashes sit over it
	var blush := skin.lerp(Color("#ff7f90"), 0.5 if hero else 0.28)
	for cx in [9.0, 39.0]:
		for y in range(29, 34):
			for x in range(int(cx) - 5, int(cx) + 6):
				if pow((x + 0.5 - cx) / 4.5, 2) + pow((y + 0.5 - 31.0) / 2.0, 2) <= 1.0:
					put.call(x, y, blush)
	var rx := 5.4
	var ry := 6.0
	var cy := 23.5
	for e in [[15.0, -1.0], [33.0, 1.0]]:
		var cx: float = e[0]
		var outer: float = e[1]
		for y in range(int(cy - ry) - 4, int(cy + ry) + 3):
			for x in range(int(cx - rx) - 4, int(cx + rx) + 5):
				var px := x + 0.5
				var py := y + 0.5
				var d := pow((px - cx) / rx, 2) + pow((py - cy) / ry, 2)
				if d <= 1.0:
					var t := clampf((py - (cy - ry)) / (2.0 * ry), 0.0, 1.0)
					var col: Color
					if absf(px - cx) > rx * 0.8:
						col = white
					else:
						col = iris.darkened(0.35).lerp(iris.lightened(0.4), t)
						if pow((px - cx) / (rx * 0.42), 2) + pow((py - cy + 0.8) / (ry * 0.48), 2) <= 1.0:
							col = iris.darkened(0.72)
					put.call(x, y, col)
				elif d <= 1.32 and py < cy - ry * 0.3:
					# the upper lash: a fine line along the top of the eye
					put.call(x, y, lash)
				elif d <= 1.25 and py > cy + ry * 0.6 and (px - cx) * outer > rx * 0.2:
					put.call(x, y, skin.darkened(0.3))
		# a small flick at the outer corner
		put.call(int(cx + outer * (rx + 1.0)), int(cy - ry * 0.42), lash)
		# sparkles: a big one up by the outer side, a small one low on the inside
		var hx := cx + outer * rx * 0.3
		var hy := cy - ry * 0.38
		for y in range(int(hy) - 2, int(hy) + 3):
			for x in range(int(hx) - 2, int(hx) + 3):
				if pow(x + 0.5 - hx, 2) + pow(y + 0.5 - hy, 2) <= 4.4:
					put.call(x, y, white)
		put.call(int(cx - outer * rx * 0.35), int(cy + ry * 0.5), white)
		put.call(int(cx - outer * rx * 0.35) + 1, int(cy + ry * 0.5), white)
	if hero:
		# a wide, open grin
		var mouth := Color("#7a2a2e")
		for y in range(36, 40):
			for x in range(18, 31):
				var d := pow((x + 0.5 - 24.0) / 6.0, 2) + pow((y + 0.5 - 36.0) / 3.5, 2)
				if d <= 1.0 and y >= 36:
					put.call(x, y, Color("#e87a82") if y >= 38 and absf(x + 0.5 - 24.0) < 3.0 else mouth)
	else:
		# a small smile
		var lips := skin.darkened(0.55).lerp(Color("#9a3036"), 0.5)
		for x in range(20, 29):
			put.call(x, 38, lips)
		put.call(19, 37, lips)
		put.call(29, 37, lips)
		for x in range(22, 27):
			put.call(x, 39, lips.lerp(skin, 0.45))
	if bangs:
		# spiky bangs: a row of points hanging over the forehead, outlined at the tips, with one line of shine
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var tips := []
		var x := -3.0
		while x < N + 3:
			tips.append([x, rng.randf_range(11.0, 15.0)])
			x += rng.randf_range(6.0, 8.5)
		for xi in N:
			var reach := 9.0
			for t in tips:
				var half := 4.2
				var dx := absf(xi + 0.5 - float(t[0]))
				if dx < half:
					reach = maxf(reach, float(t[1]) - dx * (float(t[1]) - 9.0) / half)
			for y in int(reach):
				var c := hair
				if y == int(reach) - 1:
					c = hair.darkened(0.25)
				elif y == 5 or y == 6:
					c = hair.lightened(0.25)
				put.call(xi, y, c)
	var tex: Image = img.duplicate()
	tex.generate_mipmaps()
	return ImageTexture.create_from_image(tex)


static func _head(look: Dictionary, skin: Color, hair: Color, hatc: Color, outfit: String, style: int, has_hat: bool, hat_style: String, trim: Color, hero: bool) -> ArrayMesh:
	var b := LP.new()
	var c := HEAD_C
	var iris := Color(str(look.get("eyes", "#9a3a2a" if hero else EYE_COLORS[absi(JSON.stringify(look).hash()) % EYE_COLORS.size()])))
	var hooded: bool = outfit == "armor" or look.get("hood", false)
	b.textured("face", _face_tex(skin, hair, iris, hero, not hooded, JSON.stringify(look).hash()))
	b.ellipsoid(c, HEAD_R, skin, 10, 7, Callable(), "face", Rect2(-HEAD_R.x, c.y - HEAD_R.y, HEAD_R.x * 2.0, HEAD_R.y * 2.0), 0.3)
	b.tube(Vector3(0, -0.07, 0), Vector3(0, 0.08, 0), 0.075, 0.07, skin, 6)
	var hat_dark := hatc.darkened(0.3)
	if hooded:
		# a hood or helmet: a shell round the head, open at the face
		var opening := func(m: Vector3, n: Vector3) -> bool:
			return not (n.z > 0.45 and m.y < 0.4 and m.y > 0.02)
		b.ellipsoid(c + Vector3(0, 0.01, -0.01), HEAD_R + Vector3(0.04, 0.04, 0.04), hatc, 10, 7, opening)
		if outfit == "armor":
			b.chamfer_box(c + Vector3(0, 0.27, -0.02), Vector3(0.06, 0.08, 0.42), 0.02, hat_dark)
		return b.mesh(_mat())
	_hair(b, hair, style, hat_style == "cap")
	match hat_style:
		"cap":
			b.cloth("cap", _fabric_tex("canvas"))
			b.ellipsoid(c + Vector3(0, 0.07, -0.01), HEAD_R + Vector3(0.03, -0.03, 0.035), hatc, 10, 7, func(m, n): return m.y > 0.36, "", Rect2(), 0.45, "cap")
			b.chamfer_box(Vector3(0, 0.375, 0.33), Vector3(0.36, 0.03, 0.2), 0.03, hat_dark, "cap")
			b.chamfer_box(Vector3(0, 0.575, 0), Vector3(0.05, 0.03, 0.05), 0.01, hat_dark)
		"visor", "band":
			# a band round the forehead (hair still showing on top); a visor adds a bill and a little emblem
			b.tube(Vector3(0, 0.36, 0), Vector3(0, 0.425, 0), 0.283, 0.27, hatc, 10, 1.0, false, false)
			if hat_style == "visor":
				b.chamfer_box(Vector3(0, 0.385, 0.32), Vector3(0.32, 0.022, 0.15), 0.022, hat_dark)
				b.chamfer_box(Vector3(0, 0.395, 0.276), Vector3(0.08, 0.04, 0.02), 0.01, Color(str(look.get("badge", "#ffe070"))))
			else:
				# the knot and its two tails at the back
				b.ellipsoid(Vector3(0, 0.36, -0.29), Vector3(0.05, 0.045, 0.035), hat_dark, 6, 4)
				for sx in [-1.0, 1.0]:
					b.tube(Vector3(sx * 0.02, 0.35, -0.3), Vector3(sx * 0.06, 0.2, -0.34), 0.025, 0.012, hatc, 4)
		"soda":
			# a diner paper hat: a long, low peak running front to back, its edges striped
			var y0 := 0.45
			var y1 := 0.58
			var hw := 0.2
			var hl := 0.27
			for sz in [-1.0, 1.0]:
				var z: float = hl * sz
				b.tri("color", Vector3(-hw, y0, z), Vector3(hw, y0, z), Vector3(0, y1, z), [Vector3(0, 0, sz)], hatc, Vector3(0, 0, sz))
			for sx in [-1.0, 1.0]:
				var n := Vector3(sx, 1.5, 0).normalized()
				var a := Vector3(hw * sx, y0, -hl)
				var a2 := Vector3(hw * sx, y0, hl)
				var t1 := Vector3(0, y1, -hl)
				var t2 := Vector3(0, y1, hl)
				b.tri("color", a, a2, t2, [n], hatc, n)
				b.tri("color", a, t2, t1, [n], hatc, n)
				b.chamfer_box(Vector3((hw - 0.015) * sx, y0 + 0.015, 0), Vector3(0.03, 0.03, hl * 2.0 + 0.01), 0.008, trim)
		_:
			if has_hat:
				# a brimmed hat
				b.tube(Vector3(0, 0.45, 0), Vector3(0, 0.48, 0), 0.36, 0.36, hat_dark, 12)
				b.tube(Vector3(0, 0.47, 0), Vector3(0, 0.66, 0), 0.22, 0.22, hatc, 10, 0.9)
				b.tube(Vector3(0, 0.48, 0), Vector3(0, 0.53, 0), 0.226, 0.226, hat_dark, 10, 1.0, false, false)
	return b.mesh(_mat())


## Hair: a low-poly shell over the top and back of the head that stops above the eyes, styled four ways:
## 0 short, 1 a bob down to the chin, 2 spiky, 3 a ponytail. Under a cap, tufts poke out at the sides and back.
static func _hair(b: LP, hair: Color, style: int, capped: bool) -> void:
	var c := HEAD_C + Vector3(0, 0.005, -0.005)
	var r := HEAD_R + Vector3(0.025, 0.025, 0.028)
	var short := func(m: Vector3, n: Vector3) -> bool:
		# the shell stops at the top of the forehead; the bangs are painted on the face
		if m.y > 0.375:
			return true
		if m.z < -0.04 and m.y > 0.05:
			return true
		# over the ears, but behind the face
		return absf(m.x) > 0.19 and m.z < -0.03 and m.y > 0.2
	if style == 1:
		b.ellipsoid(c, r, hair, 10, 7, func(m, n): return short.call(m, n) or (m.y > -0.02 and (m.z < 0.0 or (absf(m.x) > 0.17 and m.z < 0.13))))
		b.ellipsoid(Vector3(0, 0.17, -0.1), Vector3(0.28, 0.2, 0.2), hair, 8, 5, func(m, n): return m.z < -0.08)
	else:
		b.ellipsoid(c, r, hair, 10, 7, short)
	match style:
		2:
			for i in 6:
				var a := TAU * i / 6.0 + 0.4
				var base := c + Vector3(sin(a) * 0.15, 0.2, cos(a) * 0.12 - 0.04)
				b.cone(base, base + Vector3(sin(a) * 0.1, 0.13, cos(a) * 0.06 - 0.04), 0.07, hair.lightened(0.05 * (i % 2)), 4)
		3:
			b.ellipsoid(Vector3(0, 0.36, -0.27), Vector3(0.045, 0.045, 0.04), hair.darkened(0.25), 6, 4)
			b.tube(Vector3(0, 0.35, -0.3), Vector3(0, 0.08, -0.36), 0.06, 0.05, hair, 6, 0.5)
	if capped:
		# spiky tufts escaping under the cap at the sides and back
		for sx in [-1.0, 1.0]:
			for k in 2:
				var base := Vector3(sx * 0.25, 0.25 + k * 0.08, -0.02 - k * 0.06)
				b.cone(base, base + Vector3(sx * 0.1, -0.03, -0.04), 0.045, hair, 4)
		for k in 3:
			var base := Vector3(-0.1 + k * 0.1, 0.22, -0.25)
			b.cone(base, base + Vector3(0, -0.06, -0.1), 0.05, hair, 4)


# ---------------------------------------------------------------- body
## Where the arms hang from: the shoulder corner (x out from the middle, y up from the hip).
const SHOULDER := Vector2(0.262, 0.475)
## How long an arm is, shoulder to fingertips.
const ARM_LEN := 0.5

static var _fabrics := {}


## The pattern's colour at a voxel, or null if it's empty.
static func _px(g: VM.Grid, x: int, y: int, z: int):
	var i := g.get_v(x, y, z)
	return null if i == 0 else g.palette[i]


## A tileable, nearly white weave (32 x 32) laid over a garment's colour: "knit" (shirts and polos: ribbed rows of
## stitches), "denim" (trousers: a diagonal twill with pale flecks), "tweed" (coats and robes: flecked herringbone),
## "canvas" (jackets, caps, bags: a basket weave).
static func _fabric(kind: String) -> Image:
	if _fabrics.has(kind):
		return _fabrics[kind]
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = kind.hash()
	for y in 32:
		for x in 32:
			var v := 0.92
			match kind:
				"knit":
					# fine ribs with a faint row of stitches every few rows
					v = 0.96 if x % 2 == 0 else 0.9
					if (y + (x / 2) % 2) % 3 == 0:
						v -= 0.03
				"denim":
					# a diagonal twill with the odd pale fleck
					v = 0.95 if (x + y) % 4 < 2 else 0.86
					if rng.randf() < 0.03:
						v = 0.99
				"tweed":
					# a small herringbone, flecked
					var zig := y if (x / 4) % 2 == 0 else 31 - y
					v = 0.95 if (x + zig) % 4 < 2 else 0.88
					if rng.randf() < 0.06:
						v -= 0.08
				"canvas":
					# a tight plain weave
					v = 0.95 if (x + y) % 2 == 0 else 0.89
			v = clampf(v + rng.randf_range(-0.015, 0.015), 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v))
	_fabrics[kind] = img
	return img


static func _fabric_tex(kind: String) -> ImageTexture:
	var img: Image = _fabric(kind).duplicate()
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## The fabric each outfit's top is made of ("" for none: armour stays smooth).
static func _top_fabric(outfit: String) -> String:
	match outfit:
		"coat", "robe":
			return "tweed"
		"jacket":
			return "canvas"
		"armor":
			return ""
	return "knit"


## A point on a rounded-square cross-section (a superellipse): t = 0 faces front (+z), increasing to the right.
static func _section(t: float, p := 2.8) -> Vector2:
	var sx := sin(t)
	var cz := cos(t)
	return Vector2(signf(sx) * pow(absf(sx), 2.0 / p), signf(cz) * pow(absf(cz), 2.0 / p))


## The torso, lofted through rings [y, half width, half depth]: a flared hem, a waist, a fuller chest and square-ish
## shoulders that slope in to the neck, with a rounded-square cross-section (not a tube). Its front wears the outfit
## pattern (collars, badges, jackets, aprons, straps) over the fabric; the sides and back are the shirt's fabric.
static func _torso(t: VM.Grid, fz: int, pack: bool, look: Dictionary, shirt: Color) -> ArrayMesh:
	var b := LP.new()
	var img := Image.create(8, 9, false, Image.FORMAT_RGBA8)
	# the shirt hangs loose over the belt, so the belt rows of the pattern show the shirt (its hem a shade darker)
	var belt := t.palette[3] as Color
	var buckle := t.palette[4] as Color
	for y in 9:
		for x in 8:
			var col = _px(t, x, y, fz)
			if col == null or (y < 2 and ((col as Color).is_equal_approx(belt) or (col as Color).is_equal_approx(buckle))):
				col = shirt.darkened(0.12) if y == 0 else shirt
			img.set_pixel(x, 8 - y, col)
	img.resize(32, 36, Image.INTERPOLATE_NEAREST)
	var fab := _top_fabric(str(look.get("outfit", "plain")))
	var key := "color"
	if str(look.get("outfit", "")) == "jacket":
		img = _jacket_front(look, shirt)
		key = "shirt"
		b.cloth(key, _fabric_tex(fab))
	elif fab != "":
		# the weave runs on under the outfit's front pattern, at the same scale as on the sides
		var weave := _fabric(fab)
		var k := (8 * VS) / LP.CLOTH_TILE
		for y in 36:
			for x in 32:
				var w := weave.get_pixel(int(x * k) % 32, int(y * k) % 32).r
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(c.r * w, c.g * w, c.b * w))
		key = "shirt"
		b.cloth(key, _fabric_tex(fab))
	img.generate_mipmaps()
	b.textured("front", ImageTexture.create_from_image(img))
	var hgt := 9 * VS
	# square shoulders: full width almost to the top, then flat across to the neck
	var rings := [[0.0, 0.29, 0.18], [0.15, 0.245, 0.15], [0.31, 0.27, 0.162], [0.44, 0.295, 0.156], [0.525, 0.283, 0.142], [0.556, 0.13, 0.09]]
	var n := 14
	var P := []
	var T := []
	for r in rings:
		var row := []
		var trow := []
		for i in n:
			var tt := TAU * float(i) / n
			var q := _section(tt, 3.3)
			row.append(Vector3(q.x * float(r[1]), float(r[0]), q.y * float(r[2])))
			trow.append(q)
		P.append(row)
		T.append(trow)
	# smooth normals: each vertex averages the quads around it
	var F := []
	for ri in rings.size() - 1:
		var frow := []
		for i in n:
			var j := (i + 1) % n
			var nq: Vector3 = (P[ri + 1][i] - P[ri][i]).cross(P[ri][j] - P[ri][i]).normalized()
			var mid: Vector3 = (P[ri][i] + P[ri][j] + P[ri + 1][i] + P[ri + 1][j]) / 4.0
			if nq.dot(Vector3(mid.x, 0, mid.z)) < 0.0:
				nq = -nq
			frow.append(nq)
		F.append(frow)
	var N := []
	for ri in rings.size():
		var nrow := []
		for i in n:
			var acc := Vector3.ZERO
			for fr in [ri - 1, ri]:
				if fr < 0 or fr >= F.size():
					continue
				acc += F[fr][i] + F[fr][(i - 1 + n) % n]
			nrow.append(acc.normalized())
		N.append(nrow)
	for ri in rings.size() - 1:
		for i in n:
			var j := (i + 1) % n
			var q := [P[ri][i], P[ri][j], P[ri + 1][j], P[ri + 1][i]]
			var nn := [N[ri][i], N[ri][j], N[ri + 1][j], N[ri + 1][i]]
			var out: Vector3 = F[ri][i]
			var ts := [T[ri][i], T[ri][j], T[ri + 1][j], T[ri + 1][i]]
			var front_face: bool = out.z > 0.35 and float(rings[ri][0]) < 0.5
			var uv := []
			for k in 4:
				var pk: Vector3 = q[k]
				if front_face:
					uv.append(Vector2(0.5 + (ts[k] as Vector2).x * 0.5, 1.0 - pk.y / hgt))
				else:
					var ang := TAU * float(i + (1 if k in [1, 2] else 0)) / n
					uv.append(Vector2(ang * 0.25, -pk.y) / LP.CLOTH_TILE)
			var sk := "front" if front_face else key
			var cc := Color.WHITE if front_face else shirt
			b.tri(sk, q[0], q[1], q[2], [nn[0], nn[1], nn[2]], cc, out, [uv[0], uv[1], uv[2]])
			b.tri(sk, q[0], q[2], q[3], [nn[0], nn[2], nn[3]], cc, out, [uv[0], uv[2], uv[3]])
	# the shirt's open hem, dark inside, and the neck hole closed off (the neck sits in it)
	for i in n:
		var j := (i + 1) % n
		b.tri("color", Vector3(0, 0.02, 0), P[0][i], P[0][j], [Vector3.DOWN], shirt.darkened(0.55), Vector3.DOWN)
		var last := rings.size() - 1
		b.tri(key, Vector3(0, 0.57, 0), P[last][i], P[last][j], [Vector3.UP], shirt, Vector3.UP)
	if pack:
		var pc := Color(str(look["backpack"]))
		b.cloth("bag", _fabric_tex("canvas"))
		b.chamfer_box(Vector3(0, 0.28, -0.225), Vector3(0.36, 0.34, 0.15), 0.04, pc, "bag")
		b.chamfer_box(Vector3(0, 0.42, -0.235), Vector3(0.37, 0.1, 0.17), 0.03, pc.lightened(0.2), "bag")
		b.chamfer_box(Vector3(0, 0.34, -0.31), Vector3(0.09, 0.05, 0.02), 0.01, Color("#ffd071"))
		for sx in [-1.0, 1.0]:
			b.chamfer_box(Vector3(sx * 0.13, 0.5, -0.03), Vector3(0.05, 0.035, 0.3), 0.01, pc.darkened(0.35))
	return b.mesh(_mat())


## The hero's open jacket, painted (32 x 36, the torso's front from the neck down to the hem): the jacket hangs open
## over a white shirt, a belt with a buckle shows between the shirt and the jeans, the collar and the opening's
## edges are a shade darker, there are pocket slits and a ribbed hem, and backpack straps run over the shoulders.
## The jacket has a canvas weave, the shirt a knit one.
static func _jacket_front(look: Dictionary, jacket: Color) -> Image:
	var img := Image.create(32, 36, false, Image.FORMAT_RGBA8)
	var tee := Color(str(look.get("tee", "#f4f0e8")))
	var belt := Color(str(look.get("belt", "#4a3020")))
	var jeans := Color(str(look.get("pants", "#3d5a8f")))
	var edge := jacket.darkened(0.28)
	var canvas := _fabric("canvas")
	var knit := _fabric("knit")
	for y in 36:
		# the opening: narrow at the collar, then straight down
		var half := 3.0 + minf(float(y), 8.0) * 0.25
		for x in 32:
			var dx := absf(x + 0.5 - 16.0)
			var col := jacket
			var weave := canvas
			if dx < half:
				weave = knit
				if y >= 33:
					col = jeans
				elif y >= 30:
					col = belt
					if dx < 2.0:
						col = Color("#c8c8d0") if not (dx < 1.0 and y == 31) else belt
				else:
					col = tee
					if y < 3:
						col = tee.darkened(0.08)
			elif dx < half + 1.0:
				col = edge
			else:
				# collar round the neck, pocket slits, ribbed hem
				if y < 3 and dx < 11.0:
					col = jacket.darkened(0.15)
				if y == 24 and (absf(dx - 10.0) < 3.0):
					col = edge
				if y >= 33:
					col = jacket.darkened(0.12 if x % 2 == 0 else 0.2)
			var w := weave.get_pixel(x % 32, y % 32).r
			img.set_pixel(x, y, Color(col.r * w, col.g * w, col.b * w))
	if look.has("backpack"):
		var strap := Color(str(look["backpack"])).darkened(0.35)
		for y in 20:
			for sx in [7, 24]:
				img.set_pixel(sx, y, strap)
				img.set_pixel(sx + 1, y, strap.darkened(0.1))
	return img


## Runs of one colour down a limb's pattern (bottom to top): [[first y, last y, colour], ...] for y in from..to.
static func _bands(g: VM.Grid, x: int, z: int, from: int, to: int) -> Array:
	var out := []
	for y in range(from, to + 1):
		var col = _px(g, x, y, z)
		if col == null:
			continue
		if not out.is_empty() and (out[out.size() - 1][2] as Color).is_equal_approx(col) and out[out.size() - 1][1] == y - 1:
			out[out.size() - 1][1] = y
		else:
			out.append([y, y, col])
	return out


## A limb lofted down its pattern's bands: each band is cut into short lengths so `radius(f)` (f = 0 at the bottom
## of the limb, 1 at the top) can shape it, with an oval cross-section.
static func _limb(b: LP, bands: Array, length: float, radius: Callable, depth: float, key_of: Callable, flare_end := 1.0) -> void:
	var top := 9 * VS
	var k := length / top
	for band in bands:
		var y0: int = band[0]
		var y1: int = band[1] + 1
		var col: Color = band[2]
		var steps := maxi(1, int(ceil((y1 - y0) / 2.0)))
		for st in steps:
			var fa := lerpf(float(y0), float(y1), float(st) / steps) / 9.0
			var fb := lerpf(float(y0), float(y1), float(st + 1) / steps) / 9.0
			var ra: float = radius.call(fa, col)
			var rb: float = radius.call(fb, col)
			if st == 0 and y0 > 0 and flare_end != 1.0 and ra >= 0.06:
				# the open end of a sleeve bells out
				ra *= flare_end
			var ya := (fa * 9.0 * VS - top) * k
			var yb := (fb * 9.0 * VS - top) * k
			b.tube(Vector3(0, ya, 0), Vector3(0, yb, 0), ra, ra * depth, col, 8, rb / ra, st == 0, st == steps - 1, null, key_of.call(col))


## An arm hanging from the shoulder corner (its origin), banded like the sleeve pattern: the sleeve narrows to the
## elbow and bells out at the cuff, bare skin (forearms under short sleeves, wrists) is slim. A rounded deltoid at
## the top, centred on the swing pivot, keeps it joined to the shoulder however it swings; a hand at the end.
static func _arm(g: VM.Grid, skin: Color, fabric: String) -> ArrayMesh:
	var b := LP.new()
	var cloth_key := "color"
	if fabric != "":
		cloth_key = "sleeve"
		b.cloth(cloth_key, _fabric_tex(fabric))
	var hand = _px(g, 0, 0, 1)
	var hand_col: Color = hand if hand != null else skin
	var bare := func(c: Color) -> bool: return c.is_equal_approx(skin) or c.is_equal_approx(hand_col)
	var radius := func(f: float, c: Color) -> float:
		if bare.call(c):
			return lerpf(0.042, 0.052, f)
		# shoulder 0.083, elbow 0.068, cuff 0.08
		return 0.068 + 0.06 * pow(f - 0.5, 2) + (0.012 if f > 0.7 else 0.0) * (f - 0.7) / 0.3
	var bands := _bands(g, 0, 1, 1, 8)
	_limb(b, bands, ARM_LEN, radius, 0.9, func(c): return "color" if bare.call(c) else cloth_key, 1.18)
	if not bands.is_empty():
		var sh: Color = bands[bands.size() - 1][2]
		b.ellipsoid(Vector3(0, -0.01, 0), Vector3(0.08, 0.072, 0.078), sh, 8, 5, Callable(), "", Rect2(), 0.45, "color" if bare.call(sh) else cloth_key)
	b.ellipsoid(Vector3(0, -ARM_LEN + 0.05, 0.005), Vector3(0.052, 0.06, 0.058), hand_col, 6, 4)
	return b.mesh(_mat())


## A leg from the hip (its origin): loose trousers banded like their pattern, full at the thigh, in at the knee and
## flaring a little over the shoe (a robe spreads into a skirt), and a shoe (sneakers get a white sole and toe cap).
static func _leg(g: VM.Grid, sneakers: bool, robe: bool) -> ArrayMesh:
	var b := LP.new()
	var top := 9 * VS
	b.cloth("trousers", _fabric_tex("tweed" if robe else "denim"))
	var radius := func(f: float, _c: Color) -> float:
		if robe:
			return lerpf(0.16, 0.115, f)
		return 0.088 + 0.07 * pow(f - 0.42, 2) + (0.012 if f < 0.2 else 0.0)
	var bands := _bands(g, 1, 1, 2, 8)
	_limb(b, bands, top, radius, 0.92, func(_c): return "trousers")
	if not bands.is_empty():
		# a hip joint on the swing pivot, under the shirt
		var hr: float = radius.call(1.0, Color.WHITE)
		b.ellipsoid(Vector3.ZERO, Vector3(hr, hr * 0.9, hr * 0.92), bands[bands.size() - 1][2], 8, 4, Callable(), "", Rect2(), 0.45, "trousers")
	var upper = _px(g, 1, 1, 1)
	var sole = _px(g, 1, 0, 1)
	var up_col: Color = upper if upper != null else Color("#2a2020")
	var sole_col: Color = sole if sole != null else up_col
	if sneakers:
		b.chamfer_box(Vector3(0, -top + 0.03, 0.04), Vector3(0.19, 0.06, 0.28), 0.02, sole_col)
		b.chamfer_box(Vector3(0, -top + 0.09, 0.025), Vector3(0.175, 0.08, 0.24), 0.04, up_col)
		b.chamfer_box(Vector3(0, -top + 0.075, 0.145), Vector3(0.13, 0.05, 0.05), 0.015, sole_col)
	else:
		b.chamfer_box(Vector3(0, -top + 0.06, 0.035), Vector3(0.18, 0.12, 0.27), 0.045, up_col)
	return b.mesh(_mat())


## Builds a rig. Children: Body (rotate for facing) > Torso, Head, ArmL, ArmR, LegL, LegR.
static func build(look: Dictionary) -> Node3D:
	var p := _parts(look)
	var root := Node3D.new()
	root.name = "Person"
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var hip := 9.0 * VS
	var torso := MeshInstance3D.new()
	torso.mesh = p["torso"]
	torso.position = Vector3(0, hip, 0)
	body.add_child(torso)
	var head := MeshInstance3D.new()
	head.name = "Head"
	head.mesh = p["head"]
	head.position = Vector3(0, hip + 9.0 * VS, 0)
	body.add_child(head)
	for side in [-1, 1]:
		var arm := MeshInstance3D.new()
		arm.name = "ArmL" if side < 0 else "ArmR"
		arm.mesh = p["arm"]
		arm.position = Vector3(side * SHOULDER.x, hip + SHOULDER.y, 0)
		body.add_child(arm)
		var leg := MeshInstance3D.new()
		leg.name = "LegL" if side < 0 else "LegR"
		leg.mesh = p["leg"]
		leg.position = Vector3(side * 1.75 * VS, hip, 0)
		body.add_child(leg)
	return root


static func face(rig: Node3D, dir: Vector2i) -> void:
	var body: Node3D = rig.get_node("Body")
	var ang := 0.0
	if dir == Vector2i(0, -1):
		ang = PI
	elif dir == Vector2i(1, 0):
		ang = PI / 2.0
	elif dir == Vector2i(-1, 0):
		ang = -PI / 2.0
	body.rotation.y = ang


## Walk cycle. phase in radians; amount 0 (standing) .. 1 (full stride).
static func animate(rig: Node3D, phase: float, amount: float) -> void:
	var body: Node3D = rig.get_node("Body")
	var swing := sin(phase) * 0.7 * amount
	body.get_node("LegL").rotation.x = swing
	body.get_node("LegR").rotation.x = -swing
	body.get_node("ArmL").rotation.x = -swing * 0.8
	body.get_node("ArmR").rotation.x = swing * 0.8
	body.position.y = absf(sin(phase)) * 0.04 * amount


static func height() -> float:
	return 26.0 * VS
