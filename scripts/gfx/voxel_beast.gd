extends RefCounted
## Builds a low-poly model of a beast from its body-part genes (the same genes merging mixes).
## The parts are drawn as shapes in a voxel-sized grid (lowpoly_mesher.gd turns them into smooth polygons): rounded
## bodies and heads, tapered legs with paws, plate-like fins, glossy eyes.
## Model space: the beast faces +X, stands on y = 0, centred on X/Z.

const VM = preload("res://scripts/gfx/lowpoly_mesher.gd")

const SX := 32
const SY := 32
const SZ := 22
const CZ := 11.0
const VSIZE := 0.058

static var _cache := {}


static func mesh(genes: Dictionary) -> ArrayMesh:
	var key := JSON.stringify(genes)
	if _cache.has(key):
		return _cache[key]
	var g := grid(genes)
	var m := VM.build(g, VSIZE * float(genes.get("size", 1.0)), null, 1.35)
	_cache[key] = m
	return m


## Height of the model in world units.
static func height(genes: Dictionary) -> float:
	return mesh(genes).get_aabb().end.y


static func _anchors(body: String) -> Dictionary:
	match body:
		"biped":
			return {"head": Vector3(15, 24, CZ), "hr": 5.5, "tail": Vector3(9, 10, CZ), "back": Vector3(11, 17, CZ), "hw": 5.0, "torso": AABB(Vector3(9, 7, 6), Vector3(11, 15, 10))}
		"bird":
			return {"head": Vector3(21, 16, CZ), "hr": 4.6, "tail": Vector3(6, 11, CZ), "back": Vector3(13, 14, CZ), "hw": 6.0, "torso": AABB(Vector3(6, 5, 6), Vector3(17, 11, 10))}
		"serpent":
			return {"head": Vector3(25, 15, CZ), "hr": 5.0, "tail": Vector3(3, 3, CZ), "back": Vector3(14, 8, CZ), "hw": 7.0, "torso": AABB(Vector3(2, 0, 4), Vector3(22, 12, 14))}
		"blob":
			return {"head": Vector3(19, 13, CZ), "hr": 7.0, "tail": Vector3(5, 8, CZ), "back": Vector3(14, 17, CZ), "hw": 8.0, "torso": AABB(Vector3(5, 0, 3), Vector3(21, 18, 16))}
		"insect":
			return {"head": Vector3(22, 10, CZ), "hr": 4.2, "tail": Vector3(2, 8, CZ), "back": Vector3(12, 12, CZ), "hw": 6.0, "torso": AABB(Vector3(2, 4, 6), Vector3(18, 9, 10))}
		"fish":
			return {"head": Vector3(21, 14, CZ), "hr": 5.2, "tail": Vector3(4, 13, CZ), "back": Vector3(14, 19, CZ), "hw": 7.0, "torso": AABB(Vector3(4, 7, 7), Vector3(21, 13, 8))}
		"golem":
			return {"head": Vector3(16, 24, CZ), "hr": 4.6, "tail": Vector3(6, 9, CZ), "back": Vector3(13, 20, CZ), "hw": 7.0, "torso": AABB(Vector3(5, 6, 4), Vector3(18, 15, 14))}
	return {"head": Vector3(24, 19, CZ), "hr": 5.6, "tail": Vector3(6, 13, CZ), "back": Vector3(15, 16, CZ), "hw": 7.0, "torso": AABB(Vector3(6, 6, 5), Vector3(19, 11, 12))}


static func grid(gn: Dictionary) -> VM.Grid:
	var g := VM.Grid.new(SX, SY, SZ)
	var shade: float = float(gn.get("shade", 0.0))
	var c1 := Color(str(gn.get("c1", "#888888")))
	var c2 := Color(str(gn.get("c2", "#cccccc")))
	var c3 := Color(str(gn.get("c3", "#ffffff")))
	var eye_c := Color("#f8f6ee")
	var pupil_c := Color("#161018")
	if shade > 0.0:
		c1 = c1.lerp(Color("#17111f"), shade)
		c2 = c2.lerp(Color("#2a2038"), shade)
		c3 = c3.lerp(Color("#b07cff"), shade)
	var C1 := g.add_color(c1)
	var C2 := g.add_color(c2)
	var C3 := g.add_color(c3)
	var EYE := g.add_color(Color("#ff4f8b") if shade > 0.3 else eye_c, shade > 0.3)
	var PUP := g.add_color(Color("#ffd8e8") if shade > 0.3 else pupil_c, shade > 0.3)
	var DARK := g.add_color(c1.darkened(0.6))
	var C2D := g.add_color(c2.darkened(0.3))
	var CORE := g.add_color(Color("#fff2a0"), true)
	var FLAME := g.add_color(c3.lightened(0.15), true)
	var WISP := g.add_color(Color(0.65, 0.42, 1.0), true)
	var pal := {"c1": C1, "c2": C2, "c3": C3, "eye": EYE, "pup": PUP, "dark": DARK, "c2d": C2D, "core": CORE, "flame": FLAME, "wisp": WISP}
	var rng := RandomNumberGenerator.new()
	rng.seed = JSON.stringify(gn).hash()
	var body: String = gn.get("body", "quad")
	var a := _anchors(body)
	_tail(g, String(gn.get("tail", "none")), a["tail"], pal)
	_body(g, body, pal)
	_pattern(g, String(gn.get("pattern", "plain")), a["torso"], pal, rng)
	_back(g, String(gn.get("back", "none")), a["back"], a["hw"], pal, body)
	var ears: String = gn.get("ears", "none")
	if ears in ["pointed", "round", "long", "fins", "crest", "leaf"]:
		_ears(g, ears, a["head"], a["hr"], pal)
	_head(g, String(gn.get("head", "round")), a["head"], a["hr"], String(gn.get("pattern", "plain")), pal)
	if ears in ["horns", "antenna"]:
		_ears(g, ears, a["head"], a["hr"], pal)
	if shade > 0.3:
		for i in int(10 * shade):
			var p := Vector3i(rng.randi_range(2, SX - 3), rng.randi_range(4, SY - 2), rng.randi_range(2, SZ - 3))
			if g.get_v(p.x, p.y, p.z) == 0 and g.get_v(p.x, p.y - 2, p.z) != 0:
				g.ellipsoid(Vector3(p) + Vector3(0.5, 0.5, 0.5), Vector3(0.6, 0.9, 0.6), WISP, -1, true)
	return g


static func _body(g: VM.Grid, body: String, p: Dictionary) -> void:
	var c1: int = p["c1"]
	match body:
		"quad":
			for lx in [10.0, 19.0]:
				for lz in [7.5, 14.5]:
					g.capsule(Vector3(lx, 8.5, lz), Vector3(lx + 0.4, 1.4, lz), 1.9, 1.4, c1)
					g.ellipsoid(Vector3(lx + 0.7, 0.9, lz), Vector3(1.9, 0.9, 1.5), p["dark"])
			g.ellipsoid(Vector3(15, 10.5, CZ), Vector3(9, 4.8, 5.2), c1)
			g.ellipsoid(Vector3(21, 14, CZ), Vector3(3.6, 4.2, 3.5), c1)
		"biped":
			for lz in [8.5, 13.5]:
				g.capsule(Vector3(13.5, 9, lz), Vector3(13.8, 1.6, lz), 2.1, 1.6, c1)
				g.ellipsoid(Vector3(14.6, 1.0, lz), Vector3(2.4, 1.0, 1.6), p["dark"])
			g.ellipsoid(Vector3(14, 14, CZ), Vector3(5.5, 7, 5), c1)
			g.capsule(Vector3(14, 18, CZ - 5), Vector3(17, 11, CZ - 6.5), 1.5, 1.3, c1)
			g.capsule(Vector3(14, 18, CZ + 5), Vector3(17, 11, CZ + 6.5), 1.5, 1.3, c1)
		"bird":
			for lz in [9.0, 13.0]:
				g.capsule(Vector3(13, 7, lz), Vector3(13.5, 0.8, lz), 0.6, 0.5, p["c3"])
				for toe in [-0.9, 0.0, 0.9]:
					g.capsule(Vector3(13.5, 0.6, lz), Vector3(15.6, 0.5, lz + toe * 1.4), 0.5, 0.4, p["c3"])
			g.ellipsoid(Vector3(13, 10, CZ), Vector3(8, 5, 5), c1)
		"serpent":
			for i in 26:
				var t := i / 25.0
				var pos := Vector3(3 + t * 19.0, 2.5 + t * 6.0, CZ + sin(t * PI * 2.0) * 4.0)
				var r := 2.2 + t * 2.4
				g.ellipsoid(pos, Vector3(r, r, r), c1)
			g.capsule(Vector3(22, 8, CZ), Vector3(24, 13, CZ), 4.0, 3.8, c1)
		"blob":
			g.ellipsoid(Vector3(14, 8.5, CZ), Vector3(10, 8.5, 8), c1)
			g.ellipsoid(Vector3(9, 1, CZ - 4), Vector3(2.5, 1.2, 2), p["dark"])
			g.ellipsoid(Vector3(9, 1, CZ + 4), Vector3(2.5, 1.2, 2), p["dark"])
			g.ellipsoid(Vector3(19, 1, CZ - 4), Vector3(2.5, 1.2, 2), p["dark"])
			g.ellipsoid(Vector3(19, 1, CZ + 4), Vector3(2.5, 1.2, 2), p["dark"])
		"insect":
			for lx in [11, 15, 19]:
				g.capsule(Vector3(lx, 7, CZ - 2), Vector3(lx - 1, 0, CZ - 7), 0.8, 0.7, p["dark"])
				g.capsule(Vector3(lx, 7, CZ + 2), Vector3(lx - 1, 0, CZ + 7), 0.8, 0.7, p["dark"])
			g.ellipsoid(Vector3(8, 8, CZ), Vector3(6, 4.5, 4.5), c1)
			g.ellipsoid(Vector3(15, 8, CZ), Vector3(4, 3.5, 3.5), c1)
		"fish":
			g.ellipsoid(Vector3(14, 13, CZ), Vector3(10, 6, 4), c1)
			g.ellipsoid(Vector3(13, 7, CZ), Vector3(3, 2, 1), p["c2"])
			g.ellipsoid(Vector3(16, 12, CZ - 4.5), Vector3(3, 1.2, 2), p["c2"])
			g.ellipsoid(Vector3(16, 12, CZ + 4.5), Vector3(3, 1.2, 2), p["c2"])
		"golem":
			for lz in [7.5, 14.5]:
				g.capsule(Vector3(12, 9, lz), Vector3(12.3, 2.2, lz), 3.0, 2.6, c1)
				g.ellipsoid(Vector3(13.2, 1.4, lz), Vector3(3.6, 1.4, 2.8), p["dark"])
			g.ellipsoid(Vector3(13, 14, CZ), Vector3(8.5, 7.5, 7), c1)
			# broad, rocky shoulders
			g.ellipsoid(Vector3(13, 15.5, CZ), Vector3(7, 4, 8), c1)
			g.capsule(Vector3(13, 18, CZ - 8), Vector3(15, 6, CZ - 9), 2.6, 2.4, c1)
			g.capsule(Vector3(13, 18, CZ + 8), Vector3(15, 6, CZ + 9), 2.6, 2.4, c1)
		_:
			_body(g, "quad", p)


static func _pattern(g: VM.Grid, pattern: String, tr: AABB, p: Dictionary, rng: RandomNumberGenerator) -> void:
	var c1: int = p["c1"]
	var c2: int = p["c2"]
	var x0 := int(tr.position.x)
	var x1 := int(tr.end.x)
	var y0 := int(tr.position.y)
	var y1 := int(tr.end.y)
	match pattern:
		"spots":
			for i in 9:
				var c := Vector3(rng.randi_range(x0 + 1, x1 - 1), rng.randi_range(y0 + 2, y1), rng.randi_range(2, SZ - 3))
				g.ellipsoid(c, Vector3(1.6, 1.6, 1.6), c2, c1)
		"stripes":
			g.paint_if(c2, c1, func(x, y, _z): return x >= x0 and x <= x1 and y >= y0 and (x % 4) == 0)
		"belly":
			var by := y0 + (y1 - y0) * 0.38
			g.paint_if(c2, c1, func(x, y, _z): return x >= x0 + 2 and x <= x1 and y <= by and y >= 2)
		"rings":
			g.paint_if(c2, c1, func(x, y, _z): return x >= x0 and x <= x1 and (y % 4) == 1)


static func _head(g: VM.Grid, head: String, hc: Vector3, r: float, pattern: String, p: Dictionary) -> void:
	var c1: int = p["c1"]
	match head:
		"pointy":
			g.ellipsoid(hc, Vector3(r, r * 0.9, r * 0.92), c1)
			g.capsule(hc + Vector3(r - 1.5, -1.0, 0), hc + Vector3(r + 3.5, -1.5, 0), 2.6, 1.2, c1)
			g.ellipsoid(Vector3(hc.x + r + 3.6, hc.y - 1.5, CZ), Vector3(0.7, 0.6, 0.8), p["dark"])
		"beak":
			g.ellipsoid(hc, Vector3(r, r, r * 0.95), c1)
			g.capsule(hc + Vector3(r - 1.5, -0.5, 0), hc + Vector3(r + 4.0, -1.5, 0), 2.2, 0.8, p["c3"])
		"horned":
			g.ellipsoid(hc, Vector3(r, r * 0.95, r * 0.95), c1)
			g.capsule(hc + Vector3(-1, r - 1, -2.5), hc + Vector3(-4, r + 4, -4), 1.3, 0.6, p["c3"])
			g.capsule(hc + Vector3(-1, r - 1, 2.5), hc + Vector3(-4, r + 4, 4), 1.3, 0.6, p["c3"])
		"snout":
			g.ellipsoid(hc, Vector3(r, r, r * 0.95), c1)
			g.ellipsoid(hc + Vector3(r + 0.5, -1.8, 0), Vector3(3, 2.2, 2.6), p["c2"])
			g.ellipsoid(Vector3(hc.x + r + 3.2, hc.y - 1.0, CZ), Vector3(0.6, 0.7, 1.4), p["dark"])
		"flat":
			g.ellipsoid(hc + Vector3(0, 0.5, 0), Vector3(r + 1.5, r - 1.5, r + 0.8), c1)
		_:
			g.ellipsoid(hc, Vector3(r, r, r), c1)
	if pattern == "mask":
		g.paint_if(p["c2"], c1, func(x, y, _z): return absf(y - hc.y) <= 1.5 and x >= hc.x - r * 0.2 and Vector2(x - hc.x, y - hc.y).length() <= r + 1)
	# eyes on both sides, near the front, laid on the head's surface: a white, a big dark pupil and a glint
	for side in [-1.0, 1.0]:
		var dir := Vector3(0.62, 0.16, side * 0.77).normalized()
		var ec := hc + dir * r * 0.93
		g.ellipsoid(ec, Vector3(1.15, 1.55, 0.75), p["eye"], -1, true)
		g.ellipsoid(ec + dir * 0.45 + Vector3(0.25, -0.1, 0), Vector3(0.8, 1.15, 0.55), p["pup"], -1, true)
		g.ellipsoid(ec + dir * 0.85 + Vector3(0.35, 0.45, 0), Vector3(0.3, 0.3, 0.3), p["eye"], -1, true)
	if head != "beak":
		g.ellipsoid(Vector3(hc.x + r - 0.2, hc.y - r * 0.5, CZ), Vector3(0.7, 0.55, 0.9), p["dark"], -1, true)


static func _ears(g: VM.Grid, ears: String, hc: Vector3, r: float, p: Dictionary) -> void:
	var top := hc.y + r * 0.8
	match ears:
		"pointed":
			for side in [-1, 1]:
				for k in 5:
					var rr := 2.2 - k * 0.42
					g.ellipsoid(Vector3(hc.x - 1, top + k, hc.z + side * r * 0.5), Vector3(rr, 0.6, rr * 0.7), p["c1"])
				g.ellipsoid(Vector3(hc.x - 0.6, top + 1.2, hc.z + side * r * 0.5), Vector3(0.9, 1.0, 0.6), p["c2"])
		"round":
			for side in [-1, 1]:
				g.ellipsoid(Vector3(hc.x - 1, top + 1, hc.z + side * r * 0.6), Vector3(1.4, 2.2, 2.2), p["c1"])
				g.ellipsoid(Vector3(hc.x - 0.2, top + 1, hc.z + side * r * 0.6), Vector3(0.6, 1.4, 1.4), p["c2"])
		"long":
			for side in [-1, 1]:
				g.capsule(Vector3(hc.x - 1, top, hc.z + side * 2.0), Vector3(hc.x - 3, top + 7, hc.z + side * 3.0), 1.4, 1.1, p["c1"])
		"fins":
			for side in [-1, 1]:
				g.ellipsoid(Vector3(hc.x - 2.5, hc.y + 1.5, hc.z + side * (r + 0.2)), Vector3(3.2, 2.6, 0.55), p["c2"])
				g.ellipsoid(Vector3(hc.x - 4.0, hc.y + 3.2, hc.z + side * (r - 0.2)), Vector3(1.6, 1.8, 0.5), p["c2"])
		"horns":
			for side in [-1, 1]:
				g.capsule(Vector3(hc.x - 1, top, hc.z + side * 2.5), Vector3(hc.x - 4, top + 5, hc.z + side * 4.5), 1.3, 0.6, p["c3"])
		"antenna":
			for side in [-1, 1]:
				g.capsule(Vector3(hc.x, top, hc.z + side * 2.0), Vector3(hc.x - 1, top + 6, hc.z + side * 3.0), 0.5, 0.5, p["dark"])
				g.ellipsoid(Vector3(hc.x - 1, top + 6.5, hc.z + side * 3.0), Vector3(1.3, 1.3, 1.3), p["c3"])
		"crest":
			for k in 4:
				var x := hc.x + 1.5 - k * 2.2
				g.capsule(Vector3(x, top - 0.5, CZ), Vector3(x - 1.5, top + 3.5 - absf(k - 1.5), CZ), 1.1, 0.5, p["c3"])
		"leaf":
			g.ellipsoid(Vector3(hc.x - 1, top + 2.5, hc.z - 1.5), Vector3(1.6, 3.2, 0.7), p["c2"])
			g.ellipsoid(Vector3(hc.x - 2, top + 1.5, hc.z + 2), Vector3(2.8, 1.4, 0.7), p["c2"])


static func _tail(g: VM.Grid, tail: String, t: Vector3, p: Dictionary) -> void:
	match tail:
		"fluffy":
			g.ellipsoid(t + Vector3(-3.5, 3.5, 0), Vector3(3.5, 5.5, 3.5), p["c1"])
			g.paint_if(p["c2"], p["c1"], func(x, y, _z): return x <= t.x - 1 and y >= t.y - 2 and (y % 3) == 0)
		"flame":
			for k in 7:
				var rr := 3.0 - k * 0.38
				g.ellipsoid(t + Vector3(-1.5 - k * 0.7, k * 1.4, 0), Vector3(rr, 1.2, rr), p["flame"])
			g.ellipsoid(t + Vector3(-2.5, 2.5, 0), Vector3(1.2, 2.5, 1.2), p["core"])
		"fin":
			# a forked tail fin
			g.capsule(t, t + Vector3(-3, 0, 0), 1.6, 1.0, p["c1"])
			g.ellipsoid(t + Vector3(-5, 2.6, 0), Vector3(2.8, 3.2, 0.6), p["c2"])
			g.ellipsoid(t + Vector3(-5, -2.2, 0), Vector3(2.6, 2.8, 0.6), p["c2"])
		"spike":
			g.capsule(t, t + Vector3(-8, -1, 0), 2.2, 0.8, p["c1"])
			for k in 3:
				g.capsule(t + Vector3(-2 - k * 2, 1, 0), t + Vector3(-3 - k * 2, 3.5, 0), 0.9, 0.4, p["c3"])
		"long":
			g.capsule(t, t + Vector3(-6, 2, 0), 1.3, 1.0, p["c1"])
			g.capsule(t + Vector3(-6, 2, 0), t + Vector3(-8, 7, 0), 1.0, 0.8, p["c1"])
			g.ellipsoid(t + Vector3(-8, 7.5, 0), Vector3(1.5, 1.5, 1.5), p["c3"])
		"feather":
			for k in 3:
				g.ellipsoid(t + Vector3(-4, 1 + k * 1.6, (k - 1) * 2.4), Vector3(4.5, 1.0, 1.2), p["c2"] if k != 1 else p["c3"])
		"leaf":
			g.ellipsoid(t + Vector3(-4, 1.5, 0), Vector3(4.5, 1.0, 2.5), p["c2"])
			g.capsule(t, t + Vector3(-8, 1.5, 0), 0.5, 0.5, p["c2d"])


static func _back(g: VM.Grid, back: String, b: Vector3, hw: float, p: Dictionary, body: String) -> void:
	match back:
		"wings":
			for side in [-1, 1]:
				var root := Vector3(b.x, b.y, CZ + side * 3.5)
				for k in 6:
					g.ellipsoid(root + Vector3(-1.5 - k * 0.4, 2.5 + k * 1.3, side * (2.0 + k * 1.1)), Vector3(4.5 - k * 0.3, 0.8, 1.6), p["c2"])
				g.capsule(root + Vector3(1, 3, side * 2), root + Vector3(-2, 10, side * 8), 0.6, 0.6, p["c3"])
		"spikes":
			for k in 4:
				var x := b.x - hw + 2 + k * (hw * 2 - 4) / 3.0
				g.capsule(Vector3(x, b.y - 1, CZ), Vector3(x - 1, b.y + 4, CZ), 1.8, 0.4, p["c3"])
		"shell":
			g.ellipsoid(b + Vector3(0, -1, 0), Vector3(hw, 5, 6), p["c2"])
			g.paint_if(p["c2d"], p["c2"], func(x, y, z): return (x + z) % 5 == 0 or y % 4 == 0)
		"crystals":
			for k in 3:
				var x := b.x - 4 + k * 4
				g.capsule(Vector3(x, b.y - 1, CZ + (k - 1) * 2), Vector3(x, b.y + 5 - (k % 2) * 2, CZ + (k - 1) * 2), 1.6, 0.5, p["c3"])
		"leaves":
			for k in 4:
				g.ellipsoid(Vector3(b.x - 5 + k * 3.4, b.y + 1.5, CZ + (k % 2) * 2 - 1), Vector3(2.4, 0.8, 1.6), p["c2"])
		"flames":
			for k in 3:
				var x := b.x - 4 + k * 4
				for j in 5:
					g.ellipsoid(Vector3(x - j * 0.3, b.y + j * 1.2, CZ), Vector3(2.0 - j * 0.35, 0.9, 2.0 - j * 0.35), p["flame"])
				g.ellipsoid(Vector3(x, b.y + 1, CZ), Vector3(0.7, 0.7, 0.7), p["core"])
		"fin":
			# a swept-back dorsal fin
			g.ellipsoid(Vector3(b.x - 0.5, b.y + 2.5, CZ), Vector3(4.2, 3.8, 0.6), p["c2"])
			g.ellipsoid(Vector3(b.x - 2.5, b.y + 5.0, CZ), Vector3(2.0, 1.8, 0.5), p["c2"])
