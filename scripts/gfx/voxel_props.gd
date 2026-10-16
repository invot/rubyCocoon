extends RefCounted
## Small procedural voxel props: grass tufts, flowers, eggs, crystal shards, item sacks,
## field obstacles and the wordless shop signs.

const VM = preload("res://scripts/gfx/voxel_mesher.gd")
const VS := 0.0625

static var _cache := {}


static func _cached(key: String, maker: Callable) -> ArrayMesh:
	if not _cache.has(key):
		_cache[key] = maker.call()
	return _cache[key]


# ---------------------------------------------------------------- plants
static func grass_tuft(base_hex: String, variant: int) -> ArrayMesh:
	return _cached("tuft:%s:%d" % [base_hex, variant], func():
		var g := VM.Grid.new(14, 12, 14)
		var base := Color(base_hex)
		var cols := [g.add_color(base), g.add_color(base.darkened(0.18)), g.add_color(base.lightened(0.15)), g.add_color(base.darkened(0.32))]
		var rng := RandomNumberGenerator.new()
		rng.seed = variant * 977 + base_hex.hash()
		for i in 22:
			var x := rng.randi_range(0, 13)
			var z := rng.randi_range(0, 13)
			var hgt := rng.randi_range(4, 11)
			var lean := Vector2(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.25, 0.25))
			var c: int = cols[rng.randi_range(0, 3)]
			for k in hgt:
				g.set_v(clampi(int(x + lean.x * k), 0, 13), k, clampi(int(z + lean.y * k), 0, 13), cols[2] if k >= hgt - 1 else c)
		return VM.build(g, VS))


static func flowers(variant: int) -> ArrayMesh:
	return _cached("flowers:%d" % variant, func():
		var g := VM.Grid.new(16, 5, 16)
		var stem := g.add_color(Color("#4a8a3a"))
		var petals := [g.add_color(Color("#ff5a6a")), g.add_color(Color("#ffe060")), g.add_color(Color("#ffffff")), g.add_color(Color("#a080ff")), g.add_color(Color("#ff9a3a"))]
		var mid := g.add_color(Color("#ffd040"))
		var rng := RandomNumberGenerator.new()
		rng.seed = variant * 313
		for i in 6:
			var x := rng.randi_range(1, 14)
			var z := rng.randi_range(1, 14)
			var h := rng.randi_range(1, 3)
			g.box(x, 0, z, x, h - 1, z, stem)
			var pc: int = petals[rng.randi_range(0, petals.size() - 1)]
			g.box(x - 1, h, z, x + 1, h, z, pc)
			g.box(x, h, z - 1, x, h, z + 1, pc)
			g.set_v(x, h, z, mid)
		return VM.build(g, VS))


static func bush(base_hex: String, variant: int) -> ArrayMesh:
	return _cached("bush:%s:%d" % [base_hex, variant], func():
		var g := VM.Grid.new(16, 13, 16)
		var base := Color(base_hex)
		var a := g.add_color(base)
		var b := g.add_color(base.darkened(0.2))
		var c := g.add_color(base.lightened(0.18))
		var rng := RandomNumberGenerator.new()
		rng.seed = variant * 71 + base_hex.hash()
		for i in 6:
			var p := Vector3(rng.randf_range(4, 12), rng.randf_range(3, 7), rng.randf_range(4, 12))
			g.ellipsoid(p, Vector3(rng.randf_range(3, 5), rng.randf_range(3, 5), rng.randf_range(3, 5)), [a, b][i % 2])
		g.paint_if(c, a, func(x, y, z): return (x / 2 * 7 + y / 2 * 3 + z / 2 * 5) % 7 == 0)
		return VM.build(g, VS))


# ---------------------------------------------------------------- eggs, shards, sacks
const EGG_COLORS := {
	"fire": ["#e8553a", "#ffd040"], "water": ["#3f8fe0", "#e8f4ff"], "earth": ["#9a6a40", "#7fc050"],
	"air": ["#e8f4f0", "#6ad8c0"], "ghost": ["#1d1626", "#b07cff"], "legendary": ["#f0c040", "#ffffff"],
}


static func egg(kind: String, accent_hex := "") -> ArrayMesh:
	return _cached("egg:%s:%s" % [kind, accent_hex], func():
		var g := VM.Grid.new(10, 13, 10)
		var cols: Array = EGG_COLORS.get(kind, EGG_COLORS["earth"])
		var shell := g.add_color(Color(cols[0]))
		var spot_glow: bool = kind in ["ghost", "legendary"]
		var spot := g.add_color(Color(accent_hex) if accent_hex != "" else Color(cols[1]), spot_glow)
		g.ellipsoid(Vector3(5, 6.2, 5), Vector3(4.6, 6.2, 4.6), shell)
		g.ellipsoid(Vector3(5, 4.8, 5), Vector3(4.9, 4.8, 4.9), shell)
		var rng := RandomNumberGenerator.new()
		rng.seed = kind.hash()
		for i in 9:
			var a := rng.randf() * TAU
			var y := rng.randf_range(2.5, 10.5)
			g.ellipsoid(Vector3(5 + cos(a) * 4.4, y, 5 + sin(a) * 4.4), Vector3(1.2, 1.2, 1.2), spot, shell)
		return VM.build(g, VS * 0.9))


static func shard() -> ArrayMesh:
	return _cached("shard", func():
		var g := VM.Grid.new(10, 14, 10)
		var a := g.add_color(Color("#7af0ff"), true)
		var b := g.add_color(Color("#c8fbff"), true)
		var base := g.add_color(Color("#5a6a7a"))
		g.ellipsoid(Vector3(5, 1, 5), Vector3(4, 1.2, 4), base)
		g.capsule(Vector3(5, 1, 5), Vector3(5, 12, 5), 2.2, 0.6, a)
		g.capsule(Vector3(3, 1, 4), Vector3(1.5, 7, 3), 1.5, 0.5, a)
		g.capsule(Vector3(7, 1, 6), Vector3(8.5, 8, 7), 1.5, 0.5, a)
		g.paint_if(b, a, func(x, y, z): return (x + y) % 4 == 0)
		return VM.build(g, VS))


static func sack() -> ArrayMesh:
	return _cached("sack", func():
		var g := VM.Grid.new(9, 9, 9)
		var a := g.add_color(Color("#c8503a"))
		var tie := g.add_color(Color("#ffe080"))
		g.ellipsoid(Vector3(4.5, 3.5, 4.5), Vector3(4, 3.5, 4), a)
		g.box(3, 7, 3, 5, 8, 5, a)
		g.box(3, 7, 3, 5, 7, 5, tie)
		return VM.build(g, VS))


## A log lying along x, `length` voxels long and `r` voxels thick: bark all round, pale rings at the cut ends.
static func log_mesh(length: int, r: float) -> ArrayMesh:
	return _cached("log:%d:%s" % [length, r], func():
		var d := int(ceil(r * 2.0))
		var g := VM.Grid.new(length, d, d)
		var bark := g.add_color(Color("#74502e"))
		var bark2 := g.add_color(Color("#5a3c22"))
		var ring := g.add_color(Color("#dcb87e"))
		var core := g.add_color(Color("#a8783e"))
		var c := d / 2.0
		for x in length:
			for y in d:
				for z in d:
					var rr := Vector2(y + 0.5 - c, z + 0.5 - c).length()
					if rr > r:
						continue
					var col := bark if (x / 3 + y * 2 + z) % 5 != 0 else bark2
					if x == 0 or x == length - 1:
						col = core if rr < r * 0.4 else (ring if rr < r - 0.9 else bark)
					g.set_v(x, y, z, col)
		return VM.build(g, VS))


static func relic(kind: String) -> ArrayMesh:
	return _cached("relic:" + kind, func():
		var g := VM.Grid.new(9, 12, 9)
		var col: String = {"sun": "#ffcf40", "moon": "#c8d8ff", "earth": "#5ad06a"}.get(kind, "#ffcf40")
		var a := g.add_color(Color(col), true)
		var stone := g.add_color(Color("#8a7a6a"))
		g.box(1, 0, 1, 7, 2, 7, stone)
		g.ellipsoid(Vector3(4.5, 6.5, 4.5), Vector3(3, 3.5, 3), a)
		return VM.build(g, VS))


static func signpost() -> ArrayMesh:
	return _cached("signpost", func():
		var g := VM.Grid.new(12, 16, 4)
		var wood := g.add_color(Color("#8a6038"))
		var board := g.add_color(Color("#b88a58"))
		var ink := g.add_color(Color("#4a3020"))
		g.box(5, 0, 1, 6, 12, 2, wood)
		g.box(0, 8, 2, 11, 14, 3, board)
		g.box(2, 12, 3, 9, 12, 3, ink)
		g.box(2, 10, 3, 7, 10, 3, ink)
		return VM.build(g, VS))


static func mist() -> ArrayMesh:
	return _cached("mist", func():
		var g := VM.Grid.new(16, 10, 16)
		var a := g.add_color(Color(0.55, 0.4, 0.85), true)
		var b := g.add_color(Color(0.35, 0.85, 0.75), true)
		var rng := RandomNumberGenerator.new()
		rng.seed = 404
		for i in 22:
			g.set_v(rng.randi_range(0, 15), rng.randi_range(0, 9), rng.randi_range(0, 15), a if i % 3 else b)
		return VM.build(g, VS))


# ---------------------------------------------------------------- obstacles
## kinds: boulder, vines, driftwood, sand, dust, lava, ice, chasm, barricade, gate
static func obstacle(kind: String, variant := 0) -> ArrayMesh:
	return _cached("obst:%s:%d" % [kind, variant], func(): return _make_obstacle(kind, variant))


static func _make_obstacle(kind: String, variant: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = kind.hash() + variant * 31
	match kind:
		"boulder":
			var g := VM.Grid.new(16, 15, 16)
			var a := g.add_color(Color("#8a8a86"))
			var b := g.add_color(Color("#6a6a68"))
			var crack := g.add_color(Color("#3a3a3a"))
			g.ellipsoid(Vector3(8, 6.5, 8), Vector3(7.5, 6.5, 7), a)
			g.ellipsoid(Vector3(6, 10, 7), Vector3(4.5, 4, 4.5), b)
			g.paint_if(crack, a, func(x, y, z): return absf(x - 8 - (y - 6) * 0.4) < 0.6 and z > 10)
			return VM.build(g, VS)
		"vines":
			var g := VM.Grid.new(16, 22, 10)
			var a := g.add_color(Color("#3a7a2a"))
			var b := g.add_color(Color("#5aa03a"))
			var thorn := g.add_color(Color("#c8c070"))
			var bloom := g.add_color(Color("#e85a8a"))
			for i in 14:
				var p := Vector3(rng.randf_range(0, 16), 0, rng.randf_range(2, 8))
				var q := Vector3(rng.randf_range(0, 16), rng.randf_range(10, 21), rng.randf_range(2, 8))
				g.capsule(p, q, 1.2, 0.7, a if i % 2 == 0 else b)
			g.paint_if(thorn, a, func(x, y, z): return (x * 5 + y * 3 + z) % 13 == 0)
			g.paint_if(bloom, b, func(x, y, z): return (x * 3 + y * 7 + z) % 29 == 0)
			return VM.build(g, VS)
		"driftwood":
			var g := VM.Grid.new(16, 10, 16)
			var a := g.add_color(Color("#b89a78"))
			var b := g.add_color(Color("#8a6a4a"))
			for i in 6:
				var y := 1.5 + i * 1.3
				var ang := rng.randf() * PI
				var d := Vector3(cos(ang), 0, sin(ang)) * 7.5
				g.capsule(Vector3(8, y, 8) - d, Vector3(8, y, 8) + d, 1.4, 1.2, a if i % 2 == 0 else b)
			return VM.build(g, VS)
		"sand":
			var g := VM.Grid.new(16, 9, 16)
			var a := g.add_color(Color("#e2c88a"))
			var b := g.add_color(Color("#cfb070"))
			g.ellipsoid(Vector3(8, 0, 8), Vector3(8, 8.5, 8), a)
			g.paint_if(b, a, func(x, y, z): return (x + y * 2) % 5 == 0)
			return VM.build(g, VS)
		"dust":
			var g := VM.Grid.new(16, 28, 16)
			var a := g.add_color(Color("#d8b880"))
			var b := g.add_color(Color("#b89860"))
			for i in 260:
				var t := rng.randf()
				var ang := t * TAU * 5.0 + rng.randf() * 0.6
				var r := 2.0 + t * 6.0
				g.set_v(int(8 + cos(ang) * r), int(t * 27), int(8 + sin(ang) * r), a if i % 3 else b)
			return VM.build(g, VS)
		"lava":
			var g := VM.Grid.new(16, 5, 16)
			var hot := g.add_color(Color("#ff7a20"), true)
			var core := g.add_color(Color("#ffe060"), true)
			var crust := g.add_color(Color("#3a2a28"))
			g.ellipsoid(Vector3(8, 0, 8), Vector3(8, 4, 8), hot)
			g.paint_if(core, hot, func(x, y, z): return (x * 3 + z * 5) % 11 == 0)
			g.paint_if(crust, hot, func(x, y, z): return (x * 7 + z * 3 + y) % 6 == 0 and y >= 2)
			return VM.build(g, VS)
		"ice":
			var g := VM.Grid.new(16, 22, 12)
			var a := g.add_color(Color("#bfe8ff"))
			var b := g.add_color(Color("#e8f8ff"))
			var c := g.add_color(Color("#8ac8f0"))
			for i in 6:
				var x := rng.randf_range(2, 14)
				g.capsule(Vector3(x, 0, 6), Vector3(x + rng.randf_range(-2, 2), rng.randf_range(12, 21), 6 + rng.randf_range(-2, 2)), 3.2, 1.2, [a, b, c][i % 3])
			return VM.build(g, VS)
		"chasm":
			var g := VM.Grid.new(16, 3, 16)
			var post := g.add_color(Color("#6a4a30"))
			var rope := g.add_color(Color("#c8a870"))
			g.box(0, 0, 0, 1, 2, 1, post)
			g.box(14, 0, 0, 15, 2, 1, post)
			g.box(0, 0, 14, 1, 2, 15, post)
			g.box(14, 0, 14, 15, 2, 15, post)
			g.box(0, 2, 1, 0, 2, 3, rope)
			g.box(15, 2, 12, 15, 2, 14, rope)
			return VM.build(g, VS)
		"broken_bridge":
			var g := VM.Grid.new(16, 4, 16)
			var a := g.add_color(Color("#7a5a36"))
			var b := g.add_color(Color("#5a3e24"))
			for x in range(0, 16, 2):
				if (x / 2 + variant) % 3 == 1:
					continue
				var z0 := 0 if (x / 2) % 2 == 0 else 5
				g.box(x, 1, z0, x, 1 + (x / 2) % 2, z0 + 8 + (x / 4) % 3, a if (x / 2) % 2 == 0 else b)
			g.box(0, 3, 0, 6, 3, 0, b)
			g.box(11, 2, 15, 15, 2, 15, b)
			return VM.build(g, VS)
		"rope_cliff":
			var g := VM.Grid.new(16, 22, 16)
			var r1 := g.add_color(Color("#8a8478"))
			var r2 := g.add_color(Color("#6e6a60"))
			var rope := g.add_color(Color("#c8a870"))
			g.box(0, 0, 0, 15, 19, 15, r1)
			g.paint_if(r2, r1, func(x, y, z): return (x * 3 + y * 5 + z * 7) % 9 == 0)
			for i in 10:
				var ang := i * TAU / 10.0
				g.set_v(int(8 + cos(ang) * 4), 20, int(8 + sin(ang) * 4), rope)
				g.set_v(int(8 + cos(ang) * 2.5), 21, int(8 + sin(ang) * 2.5), rope)
			g.box(12, 20, 2, 13, 21, 3, r2)
			return VM.build(g, VS)
		"rope_ladder":
			var g := VM.Grid.new(16, 2, 16)
			var rope := g.add_color(Color("#c8a870"))
			var rung := g.add_color(Color("#8a5a32"))
			g.box(3, 0, 0, 3, 0, 15, rope)
			g.box(12, 0, 0, 12, 0, 15, rope)
			for z in range(1, 16, 3):
				g.box(3, 1, z, 12, 1, z, rung)
			return VM.build(g, VS)
		"ice_block":
			var g := VM.Grid.new(16, 15, 16)
			var a := g.add_color(Color("#bfe8ff"))
			var b := g.add_color(Color("#e8f8ff"))
			var c := g.add_color(Color("#8ac8f0"))
			g.box(1, 0, 1, 14, 13, 14, a)
			g.paint_if(b, a, func(x, y, z): return y == 13 or x == 1 or z == 14)
			g.paint_if(c, a, func(x, y, z): return (x + y * 2 + z) % 11 == 0)
			return VM.build(g, VS)
		"bridge":
			var g := VM.Grid.new(16, 4, 16)
			var a := g.add_color(Color("#8a6a40"))
			var b := g.add_color(Color("#6a4a2a"))
			for x in range(0, 16, 2):
				g.box(x, 1, 0, x, 2, 15, a if (x / 2) % 2 == 0 else b)
			g.box(0, 3, 0, 15, 3, 0, b)
			g.box(0, 3, 15, 15, 3, 15, b)
			return VM.build(g, VS)
		"barricade":
			var g := VM.Grid.new(16, 18, 10)
			var a := g.add_color(Color("#8a5a32"))
			var tip := g.add_color(Color("#c8b090"))
			for i in 5:
				var x := 1.5 + i * 3.2
				g.capsule(Vector3(x, 0, 2), Vector3(x + 1, 16, 7), 1.3, 0.7, a)
				g.set_v(int(x + 1), 16, 7, tip)
			g.capsule(Vector3(0, 6, 5), Vector3(15, 7, 5), 1.0, 1.0, a)
			return VM.build(g, VS)
		"gate":
			var g := VM.Grid.new(16, 26, 4)
			var a := g.add_color(Color("#4a4a52"))
			var b := g.add_color(Color("#c8a040"))
			for x in range(1, 16, 3):
				g.box(x, 0, 1, x, 24, 2, a)
			g.box(0, 22, 1, 15, 23, 2, a)
			g.box(0, 8, 1, 15, 9, 2, a)
			g.box(6, 12, 0, 9, 17, 3, b)
			return VM.build(g, VS)
	return ArrayMesh.new()


# ---------------------------------------------------------------- shop signs (no words)
## Each icon is 12x12. Letters map to the colours below; '.' shows the board.
const ICON_COLORS := {
	"r": "#d83a3a", "w": "#f4f0e8", "g": "#4ad06a", "l": "#b8ffc8", "b": "#3a6ad8", "y": "#ffd040",
	"o": "#8a5a32", "s": "#d8dce8", "h": "#c8a040", "k": "#f0c8a0", "n": "#2a2a3a", "p": "#a040c0",
	"c": "#5ad0f0", "d": "#5a3a26", "e": "#e88a3a",
}
const ICONS := {
	"center": ["............", "...rr..rr...", "...rr..rr...", ".rr......rr.", ".rr......rr.", "....rrrr....", "...rrrrrr...", "..rrrrrrrr..", "..rrrrrrrr..", "...rrrrrr...", "............", "............"],
	"apothecary": ["....oooo....", ".....ww.....", ".....ww.....", "....wggw....", "...wggggw...", "..wggggggw..", "..wglggggw..", "..wggggggw..", "..wggggggw..", "...wwwwww...", "............", "............"],
	"beast_gear": ["..bbbbbbbb..", "..bwbbbbwb..", "..bbbbbbbb..", "..bbbyybbb..", "..bbyyyybb..", "..bbbyybbb..", "...bbbbbb...", "...bbbbbb...", "....bbbb....", ".....bb.....", "............", "............"],
	"trainer_gear": ["............", "....eeee....", "....eeee....", "....eeee....", "....eeee....", "....eeeee...", "....eeeeeee.", "...eeeeeeeee", "...ddddddddd", "............", "............", "............"],
	"bookstore": ["............", "............", ".rrr....rrr.", ".rwwwrrwwwr.", ".rwnnwwnnwr.", ".rwwwwwwwwr.", ".rwnnwwnnwr.", ".rwwwwwwwwr.", ".rrrrrrrrrr.", ".....rr.....", "............", "............"],
	"arena": ["s..........s", ".s........s.", "..s......s..", "...s....s...", "....s..s....", ".....ss.....", ".....ss.....", "....s..s....", "..hhs..shh..", "...h....h...", "..h......h..", "............"],
	"cafe": ["...w..w.....", "....w..w....", "...w..w.....", "............", "..eeeeeee...", "..eeeeeeeee.", "..eeeeeee.e.", "..eeeeeeeee.", "...eeeee....", ".ddddddddd..", "............", "............"],
	"dojo": ["............", "...kkkkkk...", "..kkkkkkkk..", "..kdkdkdkk..", "..kkkkkkkk..", "..kkkkkkk...", "...kkkkkk...", "....rrrr....", "....rrrr....", "....rrrr....", "............", "............"],
	"museum": [".....ww.....", "...wwwwww...", ".wwwwwwwwww.", "............", ".w..w..w..w.", ".w..w..w..w.", ".w..w..w..w.", ".w..w..w..w.", ".w..w..w..w.", "wwwwwwwwwwww", "............", "............"],
	"music_hall": ["......wwwww.", "......wwwww.", "......w...w.", "......w...w.", "......w...w.", "......w...w.", "...wwww.wwww", "..wwwwwwwwww", "..wwww..wwww", "...ww....ww.", "............", "............"],
	"fortune": ["............", "....pppp....", "..pp....pp..", ".p..cccc..p.", "p..ccnncc..p", "p..ccnncc..p", ".p..cccc..p.", "..pp....pp..", "....pppp....", "............", "............", "............"],
	"electronics": [".......yy...", "......yy....", ".....yy.....", "....yy......", "...yyyyyy...", "......yy....", ".....yy.....", "....yy......", "...yy.......", "..yy........", "............", "............"],
	"music_shop": ["..........w.", ".........ww.", "........w.w.", "....yy..w...", "...yyyy.....", "..yyyy......", ".yyky.......", "yyyy........", "yky.........", "yy..........", "............", "............"],
	"skytower": ["............", "wwwwww......", ".wwwwwww....", "..wwwwwwww..", "...wwwwwwwww", "....wwwwwww.", ".....wwww...", "......ww....", "............", "............", "............", "............"],
}


static func icon(shop: String) -> ArrayMesh:
	return _cached("icon:" + shop, func():
		var rows: Array = ICONS.get(shop, ICONS["center"])
		var g := VM.Grid.new(14, 14, 3)
		var board := g.add_color(Color("#3a2618"))
		var rim := g.add_color(Color("#c8a040"))
		g.box(0, 0, 0, 13, 13, 0, rim)
		g.box(1, 1, 0, 12, 12, 1, board)
		var cmap := {}
		for y in 12:
			var row: String = rows[y]
			for x in 12:
				var ch := row[x]
				if ch == ".":
					continue
				if not cmap.has(ch):
					cmap[ch] = g.add_color(Color(ICON_COLORS.get(ch, "#ffffff")))
				g.set_v(x + 1, 12 - y, 2, cmap[ch])
		return VM.build(g, 0.042, Vector3(7, 7, 1.5)))
