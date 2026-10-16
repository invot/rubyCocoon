extends RefCounted
## Small low-poly props: grass tufts, flowers, eggs, crystal shards, item sacks, field obstacles and the wordless
## shop signs. Most are drawn with the voxel-style Grid of lowpoly_mesher.gd, which turns the shapes into polygons;
## grass and flowers are cut-out cards and the shop icons a pixel-art texture, the way PS1 games drew them.

const VM = preload("res://scripts/gfx/lowpoly_mesher.gd")
const VS := 0.0625

static var _cache := {}


static func _cached(key: String, maker: Callable) -> ArrayMesh:
	if not _cache.has(key):
		_cache[key] = maker.call()
	return _cache[key]


# ---------------------------------------------------------------- cut-out cards
## A see-through pixel texture on crossed upright cards (grass, flowers): `planes` cards turned evenly around the
## middle, `w` wide and `h` tall, standing on y = 0.
static func _cards(img: Image, planes: int, w: float, h: float, tint := Color.WHITE) -> ArrayMesh:
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.albedo_color = tint
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 1.0
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	for p in planes:
		var ang := PI * float(p) / planes + 0.3
		var d := Vector3(cos(ang), 0, sin(ang)) * (w / 2.0)
		var a := -d
		var b := d
		var quad := [[a, Vector2(0, 1)], [b, Vector2(1, 1)], [b + Vector3(0, h, 0), Vector2(1, 0)], [a + Vector3(0, h, 0), Vector2(0, 0)]]
		for k in [0, 1, 2, 0, 2, 3]:
			verts.append(quad[k][0])
			uvs.append(quad[k][1])
			# lit as if facing up, so a card looks the same from both sides and matches the ground under it
			normals.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, m)
	return mesh


# ---------------------------------------------------------------- plants
static func grass_tuft(base_hex: String, variant: int) -> ArrayMesh:
	return _cached("tuft:%s:%d" % [base_hex, variant], func():
		var base := Color(base_hex)
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var rng := RandomNumberGenerator.new()
		rng.seed = variant * 977 + base_hex.hash()
		var shades := [base, base.darkened(0.18), base.lightened(0.12), base.darkened(0.3)]
		for i in 18:
			var x := rng.randf_range(2, 29)
			var hgt := rng.randi_range(12, 31)
			var lean := rng.randf_range(-0.35, 0.35)
			var c: Color = shades[rng.randi_range(0, 3)]
			for k in hgt:
				var px := clampi(int(x + lean * k), 0, 31)
				img.set_pixel(px, 31 - k, base.lightened(0.2) if k >= hgt - 2 else c.darkened(0.15 * (1.0 - float(k) / hgt)))
				if k < hgt / 3:
					img.set_pixel(clampi(px + 1, 0, 31), 31 - k, c.darkened(0.1))
		return _cards(img, 3, 0.62, 0.6))


## A patch of flowers: blooms painted on a card lying just above the ground (the camera looks down on them), with
## a few short upright cards of stems and blooms among them for depth.
static func flowers(variant: int) -> ArrayMesh:
	return _cached("flowers:%d" % variant, func():
		var petals := [Color("#ff5a6a"), Color("#ffe060"), Color("#ffffff"), Color("#a080ff"), Color("#ff9a3a")]
		var rng := RandomNumberGenerator.new()
		rng.seed = variant * 313
		var flat := Image.create(20, 20, false, Image.FORMAT_RGBA8)
		flat.fill(Color(0, 0, 0, 0))
		# four or five blooms, each a little pixel daisy about a sixth of a tile across
		var spots := [Vector2i(4, 4), Vector2i(14, 5), Vector2i(9, 10), Vector2i(4, 15), Vector2i(15, 15)]
		for i in spots.size():
			if i == 4 and variant % 2 == 0:
				continue
			var p: Vector2i = spots[i] + Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
			var pc: Color = petals[rng.randi_range(0, petals.size() - 1)]
			for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -2), Vector2i(0, 2), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
				var q: Vector2i = p + d
				if q.x >= 0 and q.y >= 0 and q.x < 20 and q.y < 20:
					flat.set_pixel(q.x, q.y, pc if absi(d.x) + absi(d.y) <= 1 else pc.darkened(0.12))
			flat.set_pixel(p.x, p.y, Color("#ffd040"))
		var up := Image.create(32, 16, false, Image.FORMAT_RGBA8)
		up.fill(Color(0, 0, 0, 0))
		for i in 3:
			var x := rng.randi_range(4, 27)
			var top := rng.randi_range(4, 9)
			for y in range(top, 16):
				up.set_pixel(x, y, Color("#4a8a3a"))
			var pc: Color = petals[rng.randi_range(0, petals.size() - 1)]
			for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				up.set_pixel(x + d.x, top + d.y, pc)
			up.set_pixel(x, top, Color("#ffd040"))
		var mesh := _cards(up, 2, 0.7, 0.22)
		var lying := _cards(flat, 1, 0.95, 0.95)
		# turn the second card flat: it lies 2 cm above the ground
		var arrays := lying.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var axis := Vector3(cos(0.3), 0, sin(0.3))
		for i in verts.size():
			var v := verts[i]
			verts[i] = Vector3(v.x, 0.02, v.z) + axis.cross(Vector3.UP) * (v.y - 0.475)
		arrays[Mesh.ARRAY_VERTEX] = verts
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(1, lying.surface_get_material(0))
		return mesh)


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


## Low-poly cacti: 0 a saguaro with two arms, 1 a saguaro with one, 2 a barrel cactus in flower.
static func cactus(variant: int) -> ArrayMesh:
	return _cached("cactus:%d" % variant, func():
		var g := VM.Grid.new(20, 34, 20)
		var green := g.add_color(Color("#5aa046"))
		var dark := g.add_color(Color("#3f7e34"))
		var ribs := func(x, y, z): return (x + z) % 3 == 0
		if variant == 2:
			g.ellipsoid(Vector3(10, 6, 10), Vector3(6.5, 6.5, 6.5), green)
			g.paint_if(dark, green, ribs)
			var bloom := g.add_color(Color("#ff6a9a"))
			g.ellipsoid(Vector3(10, 12.5, 10), Vector3(2.2, 1.2, 2.2), bloom)
			return VM.build(g, VS)
		g.capsule(Vector3(10, 0, 10), Vector3(10, 30, 10), 2.8, 2.5, green)
		var arms := [[1.0, 13.0, 21.0]] if variant == 1 else [[1.0, 11.0, 19.0], [-1.0, 16.0, 25.0]]
		for arm in arms:
			var sx: float = arm[0]
			g.capsule(Vector3(10, arm[1], 10), Vector3(10 + sx * 6.0, arm[1], 10), 1.9, 1.9, green)
			g.capsule(Vector3(10 + sx * 6.0, arm[1], 10), Vector3(10 + sx * 6.0, arm[2], 10), 1.9, 1.7, green)
		g.paint_if(dark, green, ribs)
		return VM.build(g, VS))


## The old shrine's carved stone head: a mossy block with a heavy brow, deep eyes and a grim mouth, on a plinth.
static func totem(_variant: int) -> ArrayMesh:
	return _cached("totem", func():
		var g := VM.Grid.new(16, 30, 16)
		var stone := g.add_color(Color("#9a9080"))
		var dark := g.add_color(Color("#5a5248"))
		var moss := g.add_color(Color("#6a8a4a"))
		var eye := g.add_color(Color("#ffd870"), true)
		g.box(1, 0, 1, 14, 3, 14, dark)
		g.box(3, 4, 3, 12, 27, 12, stone)
		g.ellipsoid(Vector3(8, 27.5, 8), Vector3(5.2, 2.2, 5.2), stone)
		# brow, nose and mouth on the front (+z)
		g.box(2, 19, 11, 13, 21, 13, stone)
		g.box(7, 13, 12, 8, 19, 14, stone)
		g.box(5, 9, 12, 10, 10, 13, dark)
		g.box(4, 16, 12, 6, 18, 12, dark)
		g.box(9, 16, 12, 11, 18, 12, dark)
		g.box(5, 17, 13, 5, 17, 13, eye)
		g.box(10, 17, 13, 10, 17, 13, eye)
		g.paint_if(moss, stone, func(x, y, z): return y < 9 or (x * 5 + y * 3 + z * 7) % 11 == 0)
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


## A log lying along x, `length` voxels long and `r` voxels thick: a faceted bark tube with pale rings and a darker
## core on its sawn ends. Centred on X/Z, resting on y = 0, like the voxel log it replaces.
static func log_mesh(length: int, r: float) -> ArrayMesh:
	return _cached("log:%d:%s" % [length, r], func():
		var seg := 7
		var half := length * VS / 2.0
		var rad := r * VS
		var bark := [Color("#74502e"), Color("#5a3c22")]
		var verts := PackedVector3Array()
		var normals := PackedVector3Array()
		var cols := PackedColorArray()
		var ring := []
		for i in seg:
			var a := TAU * i / seg
			ring.append(Vector2(cos(a), sin(a)))
		var add := func(p: Vector3, n: Vector3, c: Color) -> void:
			verts.append(p + Vector3(0, rad, 0))
			normals.append(n)
			cols.append(c)
		for i in seg:
			var o0: Vector2 = ring[i]
			var o1: Vector2 = ring[(i + 1) % seg]
			var n0 := Vector3(0, o0.x, o0.y)
			var n1 := Vector3(0, o1.x, o1.y)
			var c: Color = bark[i % 2]
			var p := [Vector3(-half, o0.x * rad, o0.y * rad), Vector3(half, o0.x * rad, o0.y * rad), Vector3(half, o1.x * rad, o1.y * rad), Vector3(-half, o1.x * rad, o1.y * rad)]
			for k in [0, 2, 1, 0, 3, 2]:
				add.call(p[k], n0 if k in [0, 1] else n1, c)
			# the sawn ends: pale growth ring round a darker heart
			for e in [-1.0, 1.0]:
				var nx := Vector3(e, 0, 0)
				var mid := Vector3(half * e, 0, 0)
				var q0 := Vector3(half * e, o0.x * rad, o0.y * rad)
				var q1 := Vector3(half * e, o1.x * rad, o1.y * rad)
				var tri := [mid, q0, q1] if e > 0 else [mid, q1, q0]
				add.call(tri[0], nx, Color("#a8783e"))
				add.call(tri[1], nx, Color("#dcb87e"))
				add.call(tri[2], nx, Color("#dcb87e"))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = cols
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, VM.materials()[0])
		return mesh)


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
			# a whirl of dust: tubes winding up and out, widening like a funnel
			var g := VM.Grid.new(16, 28, 16)
			var a := g.add_color(Color("#d8b880"))
			var b := g.add_color(Color("#b89860"))
			for strand in 3:
				var prev := Vector3.ZERO
				for i in 9:
					var t := float(i) / 8.0
					var ang := t * TAU * 1.6 + strand * TAU / 3.0
					var r := 1.5 + t * 6.0
					var p := Vector3(8 + cos(ang) * r, t * 26.0, 8 + sin(ang) * r)
					if i > 0:
						g.capsule(prev, p, 0.8 + t * 1.2, 0.8 + t * 1.4, a if strand != 1 else b)
					prev = p
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
			# a sheer crag with a rope ladder coiled on top
			var g := VM.Grid.new(16, 22, 16)
			var r1 := g.add_color(Color("#8a8478"))
			var r2 := g.add_color(Color("#6e6a60"))
			var rope := g.add_color(Color("#c8a870"))
			g.box(1, 0, 1, 14, 17, 14, r1)
			g.ellipsoid(Vector3(8, 18, 8), Vector3(7.2, 2.6, 7.2), r1)
			g.ellipsoid(Vector3(4, 9, 13), Vector3(3.5, 8, 2.5), r2)
			g.ellipsoid(Vector3(13, 6, 5), Vector3(2.5, 6, 3.5), r2)
			for i in 8:
				var a0 := i * TAU / 8.0
				var a1 := (i + 1) * TAU / 8.0
				g.capsule(Vector3(8 + cos(a0) * 3.5, 20.6, 8 + sin(a0) * 3.5), Vector3(8 + cos(a1) * 3.5, 20.6, 8 + sin(a1) * 3.5), 0.7, 0.7, rope)
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


## A shop's sign: its pixel-art icon painted on a board with a brass rim (a texture, as on the PS1), centred on its
## middle, the painted face towards +z.
static func icon(shop: String) -> ArrayMesh:
	return _cached("icon:" + shop, func():
		var rows: Array = ICONS.get(shop, ICONS["center"])
		var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
		img.fill(Color("#c8a040"))
		img.fill_rect(Rect2i(1, 1, 12, 12), Color("#3a2618"))
		for y in 12:
			var row: String = rows[y]
			for x in 12:
				var ch := row[x]
				if ch != ".":
					img.set_pixel(x + 1, y + 1, Color(ICON_COLORS.get(ch, "#ffffff")))
		var m := StandardMaterial3D.new()
		m.albedo_texture = ImageTexture.create_from_image(img)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.roughness = 0.9
		var s := 14 * 0.042 / 2.0
		var d := 0.063
		var mesh := ArrayMesh.new()
		var front := [Vector3(-s, -s, d), Vector3(s, -s, d), Vector3(s, s, d), Vector3(-s, s, d)]
		var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		var verts := PackedVector3Array()
		var uvs := PackedVector2Array()
		for k in [0, 2, 1, 0, 3, 2]:
			verts.append(front[k])
			uvs.append(uv[k])
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		var normals := PackedVector3Array()
		normals.resize(6)
		normals.fill(Vector3(0, 0, 1))
		arrays[Mesh.ARRAY_NORMAL] = normals
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, m)
		# the board's edges and back, in the rim's brass
		var g := VM.Grid.new(14, 14, 3)
		var rim := g.add_color(Color("#a8802e"))
		g.box(0, 0, 0, 13, 13, 2, rim)
		var body := VM.build(g, 0.042, Vector3(7, 7, 1.5))
		for si in body.get_surface_count():
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, body.surface_get_arrays(si))
			mesh.surface_set_material(mesh.get_surface_count() - 1, body.surface_get_material(si))
		return mesh)
