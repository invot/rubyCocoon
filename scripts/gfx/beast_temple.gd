extends RefCounted
## The Beast Center: the same small temple in every town (it works by magic, not machines; see room_builder.gd's
## ancient rooms and world.gd's relics for its inside). A squat eight-sided drum of grey stone on a plinth, a broad
## base course round its foot; at the front a gabled portal, its sloping eaves trimmed in gold and set with teal
## tiles, a pointed niche high in the gable, the Center's sign board with the pawprint, and the arched doorway with
## teal inlays round a closed wooden door. On top, stepped terracotta tiers, a little red drum ringed with posts and a
## golden thatched dome, crowned with a crest of coral petals round a teal jewel.
##
## Sealed all round like every building (AGENTS.md "Building exteriors and scale"): a closed shell with capped tops,
## the door a closed leaf set just inside its arch, at least house_models.gd DOOR_H tall.

const VBld = preload("res://scripts/gfx/voxel_buildings.gd")
const VP = preload("res://scripts/gfx/voxel_props.gd")
const HouseModels = preload("res://scripts/gfx/house_models.gd")

const STONE := Color("#b9b5ad")
const STONE_DARK := Color("#9c978e")
const TERRACOTTA := Color("#c4664c")
const RED := Color("#a8443a")
const GOLD := Color("#d8a848")
const THATCH := Color("#d6aa52")
const TEAL := Color("#5ccfc4")
const SLATE := Color("#4a4e58")
const CORAL := Color("#e0785a")
## The door is blue, like every front door you can walk through.
const DOOR_BLUE := Color("#3a68b8")

## The doorway: a full-size door (house_models.gd DOOR_H, 1.8) with room to spare, under a round arch.
const DOOR_W := 1.0
const DOOR_TALL := 2.05
## How tall the drum's wall stands above the plinth.
const WALL := 3.3
const PLINTH := 0.28

static var _cache := {}


## The temple for a building dictionary (w, d, door, x, seed, low). Sets b["height"] to its wall's top.
static func build(b: Dictionary) -> Node3D:
	var w: float = b["w"]
	var d: float = b["d"]
	var door_lx: float = float(b["door"].x) + 0.5 - (float(b["x"]) + w / 2.0)
	var low: bool = b.get("low", false)
	b["height"] = PLINTH + WALL
	var key := "%d:%d:%.2f:%s" % [int(w * 10), int(d * 10), door_lx, low]
	var node := Node3D.new()
	var meshes: Array = _cache.get(key, [])
	if meshes.is_empty():
		var k := VBld.Kit.new()
		var leaf := VBld.Kit.new()
		_shell(k, leaf, w, d, door_lx, low)
		meshes = [k.mesh(), leaf.mesh()]
		_cache[key] = meshes
	for m in meshes:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		node.add_child(mi)
	var front := _front(d)
	# the pawprint on the sign board
	var icon := MeshInstance3D.new()
	icon.mesh = VP.icon("center")
	icon.scale = Vector3.ONE * 0.8
	icon.position = Vector3(door_lx, PLINTH + DOOR_TALL + 0.62, front + PORTAL_DEPTH + 0.09)
	node.add_child(icon)
	var l := OmniLight3D.new()
	l.light_color = Color("#ffd8a0")
	l.light_energy = 0.7
	l.omni_range = 3.5
	l.position = Vector3(door_lx, 1.6, d / 2.0 + 0.6)
	node.add_child(l)
	return node


const PORTAL_DEPTH := 0.32


## The drum's front face (z), set back so its portal stands within the plot.
static func _front(d: float) -> float:
	return d / 2.0 - 0.1 - PORTAL_DEPTH


## The eight corners of a chamfered rectangle (half sizes hx, hz, corners cut by c), in order round it, at height y.
static func _ring(hx: float, hz: float, c: float, y: float, cz := 0.0) -> Array:
	return [Vector3(-hx + c, y, hz + cz), Vector3(hx - c, y, hz + cz), Vector3(hx, y, hz - c + cz), Vector3(hx, y, -hz + c + cz),
		Vector3(hx - c, y, -hz + cz), Vector3(-hx + c, y, -hz + cz), Vector3(-hx, y, -hz + c + cz), Vector3(-hx, y, hz - c + cz)]


## Mortar shows between the blocks: this much darker than the stone.
const MORTAR := 0.3


## Lays smooth stone blocks over a wall face (its corners: bottom left, bottom right, top right, top left, as seen
## from outside, facing `n`): courses `row` tall, blocks about `run` long and staggered course by course, each a
## touch proud of the face with a narrow joint round it where the darker mortar face shows, and each its own faint
## shade of `col`, so the wall reads as dressed blocks without any grainy texture.
static func _blocks_on(k: VBld.Kit, q: Array, n: Vector3, col: Color, row := 0.42, run := 0.82) -> void:
	var p00: Vector3 = q[0]
	var p10: Vector3 = q[1]
	var p11: Vector3 = q[2]
	var p01: Vector3 = q[3]
	var tall := ((p01 - p00).length() + (p11 - p10).length()) / 2.0
	var wide := ((p10 - p00).length() + (p11 - p01).length()) / 2.0
	if tall < 0.05 or wide < 0.05:
		return
	var rows := maxi(1, int(round(tall / row)))
	var cols := maxi(1, int(round(wide / run)))
	var out := n.normalized() * 0.012
	var gap_v := 0.016 / tall
	var gap_u := 0.016 / wide
	for r in rows:
		var v0 := float(r) / rows + gap_v
		var v1 := float(r + 1) / rows - gap_v
		# every other course starts half a block along
		var shift := 0.5 if r % 2 == 1 else 0.0
		var edges := [0.0]
		for c in range(1, cols + 1):
			var e := (c - shift) / cols
			if e > 0.0 and e < 1.0:
				edges.append(e)
		edges.append(1.0)
		for i in edges.size() - 1:
			var u0: float = edges[i] + (gap_u if i > 0 else 0.0)
			var u1: float = edges[i + 1] - (gap_u if i < edges.size() - 2 else 0.0)
			if u1 - u0 < 0.02:
				continue
			var h := absi(hash(Vector3i(r, i, int(p00.x * 7.0 + p00.z * 13.0)))) % 1000 / 1000.0
			var bc := col.darkened(0.05 * h) if h < 0.5 else col.lightened(0.05 * (h - 0.5))
			var pts := []
			for uv in [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]:
				var lo: Vector3 = p00.lerp(p10, uv.x)
				var hi: Vector3 = p01.lerp(p11, uv.x)
				pts.append(lo.lerp(hi, uv.y) + out)
			k.poly("color", pts, n, bc)


## A closed eight-sided block from y0 to y1, its top ring smaller by `shrink` (a step or a batter), capped on top.
static func _block(k: VBld.Kit, mat: String, hx: float, hz: float, c: float, y0: float, y1: float, col: Color, shrink := 0.0, cz := 0.0, blocks := false) -> void:
	var lo := _ring(hx, hz, c, y0, cz)
	var hi := _ring(hx - shrink, hz - shrink, maxf(0.05, c - shrink * 0.4), y1, cz)
	for i in 8:
		var a: Vector3 = lo[i]
		var b: Vector3 = lo[(i + 1) % 8]
		var mid := (a + b) / 2.0 - Vector3(0, 0, cz)
		var n := Vector3(mid.x, 0, mid.z).normalized() + Vector3(0, shrink / maxf(0.01, y1 - y0) * 0.5, 0)
		var face := [a, b, hi[(i + 1) % 8], hi[i]]
		if blocks:
			k.poly(mat, face, n, col.darkened(MORTAR))
			_blocks_on(k, face, n, col)
		else:
			k.poly(mat, face, n, col)
	# the top, as a fan from its middle
	var top := Vector3(0, y1, cz)
	for i in 8:
		k.poly(mat, [top, hi[i], hi[(i + 1) % 8]], Vector3.UP, col.lightened(0.04))


## A round band (n sides) from radius r0 at y0 to r1 at y1, capped on top when r1 > 0.
static func _frustum(k: VBld.Kit, mat: String, c: Vector3, r0: float, r1: float, y0: float, y1: float, col: Color, sides := 12) -> void:
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p := [c + Vector3(cos(a0) * r0, y0, sin(a0) * r0), c + Vector3(cos(a1) * r0, y0, sin(a1) * r0),
			c + Vector3(cos(a1) * r1, y1, sin(a1) * r1), c + Vector3(cos(a0) * r1, y1, sin(a0) * r1)]
		var am := (a0 + a1) / 2.0
		var n := Vector3(cos(am), (r0 - r1) / maxf(0.01, y1 - y0), sin(am))
		if r1 <= 0.001:
			k.poly(mat, [p[0], p[1], p[2]], n, col)
		else:
			k.poly(mat, p, n, col)
	if r1 > 0.001:
		for i in sides:
			var a0 := TAU * i / sides
			var a1 := TAU * (i + 1) / sides
			k.poly(mat, [c + Vector3(0, y1, 0), c + Vector3(cos(a0) * r1, y1, sin(a0) * r1), c + Vector3(cos(a1) * r1, y1, sin(a1) * r1)], Vector3.UP, col)
	# the underside, so a band that overhangs (an eave) is never seen through from below
	if r0 > r1:
		for i in sides:
			var a0 := TAU * i / sides
			var a1 := TAU * (i + 1) / sides
			k.poly(mat, [c + Vector3(0, y0, 0), c + Vector3(cos(a1) * r0, y0, sin(a1) * r0), c + Vector3(cos(a0) * r0, y0, sin(a0) * r0)], Vector3.DOWN, col.darkened(0.3))


static func _shell(k: VBld.Kit, leaf: VBld.Kit, w: float, d: float, door_lx: float, low: bool) -> void:
	var hx := w / 2.0 - 0.12
	var front := _front(d)
	var back := -d / 2.0 + 0.12
	var hz := (front - back) / 2.0
	var cz := (front + back) / 2.0
	var ch := minf(hx, hz) * 0.42
	# the plinth and the broad base course round the drum's foot
	_block(k, "color", hx + 0.08, hz + 0.08, ch + 0.04, 0.0, PLINTH, STONE_DARK, 0.0, cz)
	_block(k, "color", hx, hz, ch, PLINTH, PLINTH + 1.05, STONE.darkened(0.04), 0.0, cz, true)
	# the drum, battered in a little, and a course above it
	_block(k, "color", hx - 0.1, hz - 0.1, ch - 0.04, PLINTH + 1.05, PLINTH + WALL, STONE, 0.06, cz, true)
	var top := PLINTH + WALL
	_block(k, "color", hx - 0.08, hz - 0.08, ch - 0.04, top, top + 0.16, STONE.lightened(0.06), 0.0, cz)
	top += 0.16
	# the stepped terracotta tiers
	var s := 0.6 if low else 1.0
	var rx := hx - 0.35
	var rz := hz - 0.35
	for i in 3:
		var h := 0.24 * s
		_block(k, "color", rx, rz, minf(rx, rz) * 0.42, top, top + h, TERRACOTTA.darkened(i * 0.05), 0.0, cz)
		top += h
		rx -= 0.28
		rz -= 0.28
	# the little red drum ringed with posts, and the golden thatched dome over it in two layers
	var r := clampf(minf(rx, rz) * 0.85, 0.6, 1.3)
	var c := Vector3(0, 0, cz)
	_frustum(k, "color", c, r, r, top, top + 0.55 * s, RED, 12)
	for i in 12:
		var a := TAU * (i + 0.5) / 12.0
		k.box("planks", c + Vector3(cos(a) * (r + 0.03), top + 0.275 * s, sin(a) * (r + 0.03)), Vector3(0.1, 0.55 * s, 0.1), GOLD.darkened(0.25))
	top += 0.55 * s
	_frustum(k, "color", c, r + 0.4, r * 0.75, top - 0.06, top + 0.3 * s, THATCH.darkened(0.06), 14)
	_frustum(k, "color", c, r * 0.8, r * 0.38, top + 0.24 * s, top + 0.62 * s, THATCH, 14)
	_frustum(k, "color", c, r * 0.4, 0.12, top + 0.58 * s, top + 0.78 * s, THATCH.lightened(0.06), 14)
	top += 0.78 * s
	# the crest: coral petals round a teal jewel
	var crest := c + Vector3(0, top + 0.28, 0.02)
	k.box("color", c + Vector3(0, top + 0.06, 0), Vector3(0.22, 0.12, 0.22), TERRACOTTA)
	for i in 8:
		var a := TAU * i / 8.0
		var tip := crest + Vector3(cos(a) * 0.3, sin(a) * 0.3, 0)
		var side := Vector3(-sin(a), cos(a), 0) * 0.08
		k.poly("color", [crest + side, tip, crest - side], Vector3(0, 0, 1), CORAL)
		k.poly("color", [crest + side, crest - side, tip], Vector3(0, 0, -1), CORAL.darkened(0.15))
	k.box("glow", crest + Vector3(0, 0, 0.02), Vector3(0.14, 0.14, 0.1), TEAL)
	_portal(k, leaf, door_lx, front, hx)


## The front portal on the drum's face: pilasters either side of the arched doorway, the gable over it with its
## gold-trimmed, tile-set eaves and pointed niche, and the sign board between door and niche.
static func _portal(k: VBld.Kit, leaf: VBld.Kit, x: float, front: float, hx: float) -> void:
	var hw := clampf(1.45, 1.1, hx - 0.25)
	var x0 := clampf(x, -hx + hw, hx - hw)
	var zf := front + PORTAL_DEPTH
	var y0 := PLINTH
	var eave := y0 + 3.05
	var peak := eave + hw * 0.62
	# the portal's body: a slab of stone standing out from the drum, up to its eaves, with its gable end
	var pc := STONE.lightened(0.04)
	k.box("color", Vector3(x0, (y0 + eave) / 2.0, front + PORTAL_DEPTH / 2.0 - 0.05), Vector3(hw * 2.0, eave - y0, PORTAL_DEPTH + 0.1), pc.darkened(MORTAR))
	_blocks_on(k, [Vector3(x0 - hw, y0, zf), Vector3(x0 + hw, y0, zf), Vector3(x0 + hw, eave, zf), Vector3(x0 - hw, eave, zf)], Vector3(0, 0, 1), pc)
	for sx: float in [-1.0, 1.0]:
		var ex := x0 + sx * hw
		_blocks_on(k, [Vector3(ex, y0, zf if sx > 0 else front - 0.05), Vector3(ex, y0, front - 0.05 if sx > 0 else zf),
			Vector3(ex, eave, front - 0.05 if sx > 0 else zf), Vector3(ex, eave, zf if sx > 0 else front - 0.05)], Vector3(sx, 0, 0), pc, 0.42, 0.4)
	k.poly("color", [Vector3(x0 - hw, eave, zf), Vector3(x0 + hw, eave, zf), Vector3(x0, peak, zf)], Vector3(0, 0, 1), STONE.lightened(0.04))
	for sx: float in [-1.0, 1.0]:
		k.poly("color", [Vector3(x0 + sx * hw, eave, zf), Vector3(x0, peak, zf), Vector3(x0, peak, front - 0.05), Vector3(x0 + sx * hw, eave, front - 0.05)],
			Vector3(sx * (peak - eave), hw, 0), STONE)
	# pilasters at its corners
	for sx: float in [-1.0, 1.0]:
		k.box("color", Vector3(x0 + sx * (hw - 0.14), (y0 + eave) / 2.0, zf + 0.04), Vector3(0.3, eave - y0, 0.1), STONE_DARK)
		k.box("color", Vector3(x0 + sx * (hw - 0.14), y0 + 0.15, zf + 0.06), Vector3(0.38, 0.3, 0.14), STONE_DARK.darkened(0.1))
	# the eaves: a gold board down each slope with a slate band of teal tiles inside it, sticking out past the gable
	for sx: float in [-1.0, 1.0]:
		var a := Vector3(x0, peak + 0.12, zf + 0.06)
		var b := Vector3(x0 + sx * (hw + 0.35), eave - 0.3, zf + 0.06)
		var along: Vector3 = (b - a).normalized()
		var up: Vector3 = Vector3(-along.y, along.x, 0).normalized()
		if up.y < 0.0:
			up = -up
		var gold_out := 0.2
		k.poly("color", [a + up * gold_out, b + up * gold_out, b - up * 0.24, a - up * 0.24], Vector3(0, 0, 1), GOLD)
		k.poly("color", [a + up * gold_out + Vector3(0, 0, -0.12), b + up * gold_out + Vector3(0, 0, -0.12), b + up * gold_out, a + up * gold_out], up, GOLD.darkened(0.1))
		k.poly("color", [a - up * 0.24, b - up * 0.24, b - up * 0.24 + Vector3(0, 0, -0.12), a - up * 0.24 + Vector3(0, 0, -0.12)], -up, GOLD.darkened(0.25))
		k.poly("color", [b + up * gold_out, b - up * 0.24, b - up * 0.24 + Vector3(0, 0, -0.12), b + up * gold_out + Vector3(0, 0, -0.12)], along, GOLD.darkened(0.15))
		k.poly("color", [a + up * 0.1 + Vector3(0, 0, 0.012), b + up * 0.1 + Vector3(0, 0, 0.012), b - up * 0.14 + Vector3(0, 0, 0.012), a - up * 0.14 + Vector3(0, 0, 0.012)], Vector3(0, 0, 1), SLATE)
		var n := 6
		for i in n:
			var t := (i + 0.6) / float(n + 0.4)
			var p: Vector3 = a.lerp(b, t) - up * 0.02 + Vector3(0, 0, 0.022)
			k.poly("glow", [p - along * 0.07 + up * 0.07, p + along * 0.07 + up * 0.07, p + along * 0.07 - up * 0.07, p - along * 0.07 - up * 0.07], Vector3(0, 0, 1), TEAL.darkened(0.15))
	# a gold boss at the peak
	k.box("color", Vector3(x0, peak - 0.1, zf + 0.08), Vector3(0.3, 0.3, 0.1), GOLD.lightened(0.05))
	k.box("glow", Vector3(x0, peak - 0.1, zf + 0.135), Vector3(0.14, 0.14, 0.01), TEAL.darkened(0.15))
	# the pointed niche in the gable, framed in gold
	var ny := eave - 0.05
	k.box("color", Vector3(x0, ny, zf + 0.02), Vector3(0.62, 0.8, 0.04), GOLD.darkened(0.1))
	k.poly("color", [Vector3(x0 - 0.31, ny + 0.4, zf + 0.04), Vector3(x0 + 0.31, ny + 0.4, zf + 0.04), Vector3(x0, ny + 0.7, zf + 0.04)], Vector3(0, 0, 1), GOLD.darkened(0.1))
	k.box("color", Vector3(x0, ny - 0.02, zf + 0.045), Vector3(0.36, 0.62, 0.01), STONE_DARK.darkened(0.25))
	k.poly("color", [Vector3(x0 - 0.18, ny + 0.29, zf + 0.05), Vector3(x0 + 0.18, ny + 0.29, zf + 0.05), Vector3(x0, ny + 0.5, zf + 0.05)], Vector3(0, 0, 1), STONE_DARK.darkened(0.25))
	# the sign board over the door, terracotta with a darker rim (the pawprint goes on it: see build)
	var sy := y0 + DOOR_TALL + 0.62
	k.box("color", Vector3(x, sy, zf + 0.04), Vector3(1.5, 0.5, 0.08), TERRACOTTA.darkened(0.25))
	k.box("color", Vector3(x, sy, zf + 0.07), Vector3(1.36, 0.38, 0.03), TERRACOTTA.lightened(0.08))
	k.box("color", Vector3(x, sy - 0.33, zf + 0.03), Vector3(2.2, 0.1, 0.06), TERRACOTTA.darkened(0.1))
	# the arch round the door: slate voussoirs with teal tiles set in them, a keystone at the top
	var rad := DOOR_W / 2.0
	var spring := y0 + DOOR_TALL - rad
	k.box("color", Vector3(x - rad - 0.11, (y0 + spring) / 2.0, zf + 0.04), Vector3(0.22, spring - y0, 0.1), SLATE)
	k.box("color", Vector3(x + rad + 0.11, (y0 + spring) / 2.0, zf + 0.04), Vector3(0.22, spring - y0, 0.1), SLATE)
	for sx: float in [-1.0, 1.0]:
		for i in 3:
			k.box("glow", Vector3(x + sx * (rad + 0.11), y0 + 0.35 + i * 0.45, zf + 0.095), Vector3(0.08, 0.22, 0.01), TEAL.darkened(0.15))
	var seg := 8
	for i in seg:
		var a0 := PI * i / seg
		var a1 := PI * (i + 1) / seg
		var c := Vector3(x, spring, zf + 0.09)
		var p := [c + Vector3(cos(a0) * rad, sin(a0) * rad, 0), c + Vector3(cos(a0) * (rad + 0.22), sin(a0) * (rad + 0.22), 0),
			c + Vector3(cos(a1) * (rad + 0.22), sin(a1) * (rad + 0.22), 0), c + Vector3(cos(a1) * rad, sin(a1) * rad, 0)]
		k.poly("color", p, Vector3(0, 0, 1), SLATE if i % 2 == 0 else SLATE.lightened(0.08))
		if i in [1, 6]:
			var m: Vector3 = c + Vector3(cos((a0 + a1) / 2.0), sin((a0 + a1) / 2.0), 0) * (rad + 0.11) + Vector3(0, 0, 0.005)
			k.poly("glow", [m + Vector3(-0.05, -0.05, 0), m + Vector3(0.05, -0.05, 0), m + Vector3(0.05, 0.05, 0), m + Vector3(-0.05, 0.05, 0)], Vector3(0, 0, 1), TEAL.darkened(0.15))
	k.box("color", Vector3(x, spring + rad + 0.1, zf + 0.1), Vector3(0.24, 0.28, 0.12), STONE_DARK)
	# the door: a closed blue leaf of boards in the arch, rounded at its head, with iron straps and a brass ring; it
	# stands just proud of the portal's face, inside the jambs and voussoirs that stand further out
	var dz := zf + 0.03
	leaf.box("color", Vector3(x, (y0 + spring) / 2.0, dz), Vector3(DOOR_W, spring - y0, 0.06), DOOR_BLUE)
	for i in seg:
		var a0 := PI * i / seg
		var a1 := PI * (i + 1) / seg
		var c := Vector3(x, spring, dz + 0.031)
		leaf.poly("color", [c, c + Vector3(cos(a0) * rad, sin(a0) * rad, 0), c + Vector3(cos(a1) * rad, sin(a1) * rad, 0)], Vector3(0, 0, 1), DOOR_BLUE)
	# the joints between its boards
	for bx: float in [-0.25, 0.0, 0.25]:
		var bh := sqrt(maxf(0.0, rad * rad - bx * bx))
		leaf.box("color", Vector3(x + bx, (y0 + spring + bh) / 2.0, dz + 0.033), Vector3(0.025, spring + bh - y0, 0.006), DOOR_BLUE.darkened(0.3))
	for yy: float in [0.45, 1.35]:
		leaf.box("tin", Vector3(x, y0 + yy, dz + 0.04), Vector3(DOOR_W - 0.08, 0.06, 0.02), Color("#3a3a40"))
	leaf.box("brass", Vector3(x + 0.3, y0 + 1.0, dz + 0.05), Vector3(0.08, 0.08, 0.04), Color("#c8a040"))
	# a half-round step before the door
	_frustum(k, "color", Vector3(x, 0, zf + 0.05), 0.85, 0.8, 0.0, 0.12, STONE_DARK.lightened(0.05), 10)
	# the planters of agaves either side, against the drum's base course
	for sx: float in [-1.0, 1.0]:
		var px := x0 + sx * (hw + 0.55)
		if absf(px) > hx - 0.3:
			continue
		k.box("color", Vector3(px, PLINTH + 0.18, front + 0.22), Vector3(0.7, 0.36, 0.4), STONE_DARK)
		k.box("color", Vector3(px, PLINTH + 0.37, front + 0.22), Vector3(0.6, 0.02, 0.3), Color("#5a3e2a"))
		# (each leaf both sides, so it shows from any angle)
		for j in 7:
			var a := TAU * j / 7.0 + 0.3
			var base := Vector3(px, PLINTH + 0.38, front + 0.22)
			var l0 := base + Vector3(cos(a + 0.5) * 0.06, 0, sin(a + 0.5) * 0.04)
			var l1 := base + Vector3(cos(a - 0.5) * 0.06, 0, sin(a - 0.5) * 0.04)
			var tip := base + Vector3(cos(a) * 0.3, 0.42, sin(a) * 0.16)
			var lc := Color("#6aa880") if j % 2 == 0 else Color("#88b878")
			k.poly("color", [l0, l1, tip], Vector3(cos(a), 0.4, sin(a)), lc)
			k.poly("color", [l1, l0, tip], -Vector3(cos(a), 0.4, sin(a)), lc.darkened(0.15))
