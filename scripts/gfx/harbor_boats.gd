extends RefCounted
## Harbour boats, built in code from VBld.Kit boxes and slabs (low-poly, flat bright paint, like the
## town): a paddle steamer, a shrimp trawler, a sloop, a skiff and a schooner under sail. Each is modelled along z,
## its bow towards +z (as the PSX pack's boats, so a map's "boats" yaw turns them the same way), with its waterline at
## y = 0 and its hull below it (world.gd _build_boats floats them there and scales them to their length).

const VBld = preload("res://scripts/gfx/voxel_buildings.gd")

const WHITE := Color("#f4f2ec")
const RED := Color("#c23a32")
const BLACK := Color("#2a2a2e")
const WOOD := Color("#9a6a42")
const SAIL := Color("#f2ead6")

const KINDS := ["steamboat", "trawler", "sloop", "skiff", "schooner", "motor_yacht", "motor_launch"]

static var _cache := {}


static func has(name: String) -> bool:
	return name in KINDS


static func mesh(name: String) -> ArrayMesh:
	if _cache.has(name):
		return _cache[name]
	var k := VBld.Kit.new()
	match name:
		"steamboat":
			_steamboat(k)
		"trawler":
			_trawler(k)
		"sloop":
			_sloop(k)
		"skiff":
			_skiff(k)
		"schooner":
			_schooner(k)
		"motor_yacht":
			_motor_yacht(k)
		"motor_launch":
			_motor_launch(k)
	_cache[name] = k.mesh()
	return _cache[name]


## A hull's outline (x/z): a square stern at -l/2, straight sides, and a bow narrowing to a point at +l/2 over the
## last `bow` of its length.
static func _outline(l: float, beam: float, bow: float, stern_round := 0.0) -> Array:
	var hb := beam / 2.0
	var pts := [Vector2(-hb, -l / 2.0 + stern_round), Vector2(-hb, l / 2.0 - bow), Vector2(-hb * 0.55, l / 2.0 - bow * 0.35),
		Vector2(0.0, l / 2.0), Vector2(hb * 0.55, l / 2.0 - bow * 0.35), Vector2(hb, l / 2.0 - bow), Vector2(hb, -l / 2.0 + stern_round)]
	if stern_round > 0.0:
		pts.append(Vector2(hb * 0.6, -l / 2.0))
		pts.append(Vector2(-hb * 0.6, -l / 2.0))
	return pts


## A hull: its sides from `draft` below the water up to `free` above it in the hull's colour with a band of `band`
## round its foot, and the deck on top.
static func _hull(k: VBld.Kit, pts: Array, draft: float, free: float, col: Color, band: Color, deck: Color, deck_tex := "planks") -> void:
	var c := Vector2.ZERO
	VBld._skirt(k, "color", pts, -draft, draft + 0.08, band, c)
	VBld._skirt(k, "color", pts, 0.08, free - 0.08, col, c)
	# a rubbing strake along the gunwale
	VBld._skirt(k, "color", VBld._grown(pts, 0.03), free - 0.1, 0.08, col.darkened(0.25), c)
	VBld._band(k, deck_tex, pts, VBld._fill(c, pts.size()), free - 0.02, deck)


## A thin rail round a rectangle (x0..x1, z0..z1) at height y, h tall, with posts.
static func _rails(k: VBld.Kit, x0: float, x1: float, z0: float, z1: float, y: float, h: float, col: Color) -> void:
	var corners := [Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1)]
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		VBld._beam(k, "color", a + Vector3(0, h, 0), b + Vector3(0, h, 0), 0.04, col)
		VBld._beam(k, "color", a + Vector3(0, h * 0.5, 0), b + Vector3(0, h * 0.5, 0), 0.025, col)
		var n := maxi(1, int(a.distance_to(b) / 0.5))
		for j in n:
			var p := a.lerp(b, float(j) / float(n))
			k.box("color", p + Vector3(0, h / 2.0, 0), Vector3(0.035, h, 0.035), col)


## A row of windows along a side of a cabin (x = side), from z0 to z1 at height y.
static func _windows(k: VBld.Kit, side: float, z0: float, z1: float, y: float, size: float, glass: Color) -> void:
	var n := maxi(1, int((z1 - z0) / (size * 2.0)))
	for i in n:
		var z := lerpf(z0, z1, (float(i) + 0.5) / float(n))
		k.box("glow", Vector3(side, y, z), Vector3(0.03, size, size * 0.9), glass)


## A paddle steamer, the river queen of the harbour: a white hull with a red foot, two tiers of white cabins with
## promenade decks and railings all round, a pilot house on top, two tall black stacks with crowned tops forward and a
## big red paddle wheel at the stern.
static func _steamboat(k: VBld.Kit) -> void:
	var l := 7.6
	var beam := 2.4
	_hull(k, _outline(l, beam, 1.5), 0.35, 0.45, WHITE, RED, Color("#b08a62"))
	var hw := beam / 2.0
	# the main cabin, set in from the hull for a promenade all round, under the boiler deck
	var cz0 := -l / 2.0 + 0.35
	var cz1 := l / 2.0 - 1.6
	k.box("color", Vector3(0, 0.45 + 0.6, (cz0 + cz1) / 2.0), Vector3(beam - 0.7, 1.2, cz1 - cz0), WHITE)
	for sx in [-1.0, 1.0]:
		_windows(k, sx * (beam - 0.7) / 2.0 + sx * 0.01, cz0 + 0.2, cz1 - 0.2, 1.15, 0.32, Color("#ffe8b0"))
	# columns and the boiler deck over it, reaching to the hull's edge
	var d1 := 1.75
	k.box("color", Vector3(0, d1, (cz0 + cz1) / 2.0 + 0.2), Vector3(beam - 0.1, 0.1, cz1 - cz0 + 0.8), WHITE.darkened(0.06))
	for sx in [-1.0, 1.0]:
		var z := cz0
		while z <= cz1 + 0.4:
			k.box("color", Vector3(sx * (hw - 0.1), 0.45 + (d1 - 0.45) / 2.0, z), Vector3(0.06, d1 - 0.45, 0.06), WHITE)
			z += 0.75
	_rails(k, -hw + 0.08, hw - 0.08, cz0 - 0.15, cz1 + 0.55, d1 + 0.05, 0.4, WHITE)
	# the texas deck's cabin, and its own deck
	var tz0 := cz0 + 0.6
	var tz1 := cz1 - 0.3
	k.box("color", Vector3(0, d1 + 0.5, (tz0 + tz1) / 2.0), Vector3(beam - 0.9, 0.9, tz1 - tz0), WHITE)
	for sx in [-1.0, 1.0]:
		_windows(k, sx * (beam - 0.9) / 2.0 + sx * 0.01, tz0 + 0.2, tz1 - 0.2, d1 + 0.55, 0.26, Color("#ffe8b0"))
	var d2 := d1 + 0.98
	k.box("color", Vector3(0, d2, (tz0 + tz1) / 2.0), Vector3(beam - 0.6, 0.08, tz1 - tz0 + 0.3), WHITE.darkened(0.06))
	_rails(k, -(beam - 0.6) / 2.0, (beam - 0.6) / 2.0, tz0 - 0.15, tz1 + 0.15, d2 + 0.04, 0.32, WHITE)
	# the pilot house, glazed all round, with a little roof
	var pz := tz1 - 0.6
	k.box("color", Vector3(0, d2 + 0.4, pz), Vector3(0.9, 0.72, 0.8), WHITE)
	for sx in [-1.0, 1.0]:
		k.box("glow", Vector3(sx * 0.46, d2 + 0.48, pz), Vector3(0.03, 0.32, 0.6), Color("#cfe4ee"))
	k.box("glow", Vector3(0, d2 + 0.48, pz + 0.41), Vector3(0.7, 0.32, 0.03), Color("#cfe4ee"))
	k.box("color", Vector3(0, d2 + 0.82, pz), Vector3(1.1, 0.08, 1.0), RED)
	# the stacks, forward of the pilot house, black with crowned tops and a gilt band
	for sx in [-1.0, 1.0]:
		var sp := Vector3(sx * 0.62, d1, cz1 + 0.05)
		VBld._column(k, "color", sp, 0.17, 3.3, 8, BLACK)
		VBld._column(k, "brass", sp + Vector3(0, 2.4, 0), 0.19, 0.1, 8, Color("#d8b040"))
		var crown := sp + Vector3(0, 3.3, 0)
		for i in 8:
			var a := TAU * float(i) / 8.0
			VBld._beam(k, "color", crown + Vector3(cos(a) * 0.15, 0, sin(a) * 0.15), crown + Vector3(cos(a) * 0.3, 0.35, sin(a) * 0.3), 0.06, BLACK)
	# the stern wheel: a red drum of paddles on two spoked rims, half in the water, under a little housing
	var wz := -l / 2.0 - 0.6
	var wr := 0.95
	var wy := 0.35
	for sx in [-1.0, 1.0]:
		var rim := []
		for i in 12:
			var a := TAU * float(i) / 12.0
			rim.append(Vector3(sx * 0.95, wy + sin(a) * wr, wz + cos(a) * wr))
		for i in 12:
			VBld._beam(k, "color", rim[i], rim[(i + 1) % 12], 0.06, RED.darkened(0.2))
			VBld._beam(k, "color", Vector3(sx * 0.95, wy, wz), rim[i], 0.04, RED.darkened(0.2))
	for i in 12:
		var a := TAU * float(i) / 12.0
		k.box("color", Vector3(0, wy + sin(a) * wr, wz + cos(a) * wr), Vector3(1.9, 0.08 + 0.12 * absf(cos(a)), 0.08 + 0.12 * absf(sin(a))), RED)
	k.box("color", Vector3(0, wy, wz), Vector3(2.1, 0.12, 0.12), BLACK)
	for sx in [-1.0, 1.0]:
		k.box("color", Vector3(sx * 1.05, 0.75, wz + 0.5), Vector3(0.1, 0.8, 0.1), WHITE)
		VBld._beam(k, "color", Vector3(sx * 1.05, 0.45, -l / 2.0 + 0.1), Vector3(sx * 1.05, wy + 0.05, wz), 0.1, WHITE.darkened(0.1))
	# a flag on the jackstaff at the bow
	VBld._column(k, "color", Vector3(0, 0.45, l / 2.0 - 0.3), 0.03, 1.1, 4, BLACK)
	VBld._pennant(k, Vector3(0, 1.55, l / 2.0 - 0.3), Color("#6a3a98"))


## A Gulf shrimp trawler: a white hull with a high flared bow and a teal foot, a wheelhouse forward, a mast with its
## two outrigger booms raised in a V, green nets hanging from them, and a cluttered stern.
static func _trawler(k: VBld.Kit) -> void:
	var l := 3.6
	var beam := 1.3
	_hull(k, _outline(l, beam, 0.9), 0.3, 0.5, WHITE, Color("#2e8a8a"), Color("#a08060"))
	# the bow raised a little higher
	k.box("color", Vector3(0, 0.6, l / 2.0 - 0.55), Vector3(0.6, 0.2, 0.5), WHITE)
	var wz := 0.6
	k.box("color", Vector3(0, 0.95, wz), Vector3(0.9, 0.95, 0.8), WHITE)
	k.box("glow", Vector3(0, 1.15, wz + 0.41), Vector3(0.7, 0.28, 0.03), Color("#cfe4ee"))
	for sx in [-1.0, 1.0]:
		k.box("glow", Vector3(sx * 0.46, 1.15, wz), Vector3(0.03, 0.26, 0.5), Color("#cfe4ee"))
	k.box("color", Vector3(0, 1.47, wz), Vector3(1.0, 0.08, 0.9), Color("#2e8a8a"))
	# the mast and the booms, raised in a V, with nets
	var mp := Vector3(0, 0.5, -0.1)
	VBld._column(k, "color", mp, 0.05, 2.6, 6, WHITE)
	for sx in [-1.0, 1.0]:
		var tip := mp + Vector3(sx * 1.25, 2.2, -0.15)
		VBld._beam(k, "color", mp + Vector3(0, 0.6, 0), tip, 0.06, Color("#d8d4cc"))
		VBld._beam(k, "color", mp + Vector3(0, 2.6, 0), tip, 0.02, BLACK)
		k.box("color", tip + Vector3(-sx * 0.12, -0.6, 0), Vector3(0.22, 1.1, 0.4), Color("#3a7a4a"))
		k.box("color", tip + Vector3(-sx * 0.12, -1.2, 0), Vector3(0.16, 0.2, 0.3), Color("#2e6a3e"))
	# the stern: a winch drum and a couple of crates
	k.box("color", Vector3(0, 0.62, -l / 2.0 + 0.5), Vector3(0.6, 0.22, 0.22), RED)
	k.box("planks", Vector3(0.35, 0.62, -l / 2.0 + 0.85), Vector3(0.28, 0.24, 0.28), WOOD)


## A little sloop moored with its sail furled: a white hull with a blue stripe, a small cabin, a mast and its boom with
## the sail bundled along it, a tiller.
static func _sloop(k: VBld.Kit) -> void:
	var l := 2.8
	var beam := 0.95
	_hull(k, _outline(l, beam, 0.9, 0.12), 0.22, 0.32, WHITE, Color("#2a5a9a"), Color("#c8a878"))
	VBld._skirt(k, "color", VBld._grown(_outline(l, beam, 0.9, 0.12), 0.01), 0.16, 0.06, Color("#2a5a9a"), Vector2.ZERO)
	k.box("color", Vector3(0, 0.45, 0.15), Vector3(0.6, 0.28, 0.8), WHITE.darkened(0.04))
	for sx in [-1.0, 1.0]:
		k.box("glow", Vector3(sx * 0.31, 0.47, 0.15), Vector3(0.02, 0.1, 0.4), Color("#cfe4ee"))
	var mp := Vector3(0, 0.3, 0.45)
	VBld._column(k, "color", mp, 0.035, 3.1, 6, Color("#d8d8d8"))
	VBld._beam(k, "color", mp + Vector3(0, 0.55, 0), Vector3(0, 0.85, -l / 2.0 + 0.2), 0.045, Color("#d8d8d8"))
	VBld._beam(k, "color", mp + Vector3(0, 0.66, -0.05), Vector3(0, 0.95, -l / 2.0 + 0.35), 0.12, SAIL)
	VBld._beam(k, "color", mp + Vector3(0, 3.0, 0), Vector3(0, 0.36, l / 2.0 - 0.05), 0.012, BLACK)
	VBld._beam(k, "color", mp + Vector3(0, 3.0, 0), Vector3(0, 0.36, -l / 2.0 + 0.05), 0.012, BLACK)
	k.box("planks", Vector3(0, 0.38, -l / 2.0 + 0.1), Vector3(0.05, 0.08, 0.5), WOOD)


## Shellhaven's white motor yacht: teak swim platform, blue glazing, shaded aft lounge and an open flybridge.
static func _motor_yacht(k: VBld.Kit) -> void:
	var navy := Color("#284e68")
	var teak := Color("#c6a478")
	var glass := Color("#547d91")
	var pts := _outline(7.2, 2.15, 2.0, 0.25)
	_hull(k, pts, 0.36, 0.65, WHITE, navy, teak)
	VBld._skirt(k, "color", VBld._grown(pts, 0.012), 0.35, 0.08, navy, Vector2.ZERO)
	k.box("planks", Vector3(0, 0.2, -3.55), Vector3(1.8, 0.12, 0.5), teak)
	# The cabin tapers into a sloping windshield rather than a square house front.
	var cabin := [Vector2(-0.79, -1.7), Vector2(-0.79, 0.7), Vector2(-0.53, 1.3),
		Vector2(0.53, 1.3), Vector2(0.79, 0.7), Vector2(0.79, -1.7)]
	VBld._skirt(k, "color", cabin, 0.65, 0.88, WHITE, Vector2.ZERO)
	VBld._skirt(k, "color", VBld._scaled(cabin, Vector2.ZERO, 1.015), 1.03, 0.37, glass, Vector2.ZERO)
	VBld._band(k, "color", cabin, VBld._fill(Vector2.ZERO, cabin.size()), 1.54, WHITE)
	k.box("color", Vector3(0, 1.59, -0.45), Vector3(1.9, 0.12, 3.9), WHITE)
	for sx in [-1.0, 1.0]:
		# Supports leave the aft deck open; white fenders hang along the berth sides.
		k.box("color", Vector3(sx * 0.85, 1.08, -2.3), Vector3(0.06, 0.95, 0.06), WHITE)
		_windows(k, sx * 1.065, -2.2, 0.9, 0.48, 0.16, navy)
		for z in [-2.4, 0.1]:
			VBld._column(k, "color", Vector3(sx * 1.08, 0.2, z), 0.09, 0.4, 8, WHITE)
		k.box("color", Vector3(sx * 0.69, 0.88, -2.4), Vector3(0.38, 0.28, 0.85), Color("#e3d2b2"))
	# Low bow sun pad, railings and a flybridge with two seats under a canvas canopy.
	k.box("color", Vector3(0, 0.74, 2.0), Vector3(1.1, 0.14, 0.9), Color("#e3d2b2"))
	_rails(k, -0.92, 0.92, -3.05, 1.45, 0.66, 0.3, WHITE)
	k.box("color", Vector3(0, 1.78, 0.45), Vector3(1.3, 0.35, 0.42), navy)
	for sx in [-1.0, 1.0]:
		k.box("color", Vector3(sx * 0.38, 1.83, -0.35), Vector3(0.4, 0.42, 0.5), WHITE)
		for z in [-1.4, 0.5]:
			k.box("color", Vector3(sx * 0.73, 2.12, z), Vector3(0.045, 1.0, 0.045), WHITE)
	k.box("color", Vector3(0, 2.64, -0.4), Vector3(1.65, 0.1, 2.4), Color("#c4dfdb"))
	VBld._column(k, "color", Vector3(0, 2.69, -0.8), 0.035, 0.5, 6, WHITE)
	VBld._pennant(k, Vector3(0, 3.19, -0.8), navy)


## A smaller varnished pleasure launch with cream upholstery, a wraparound windscreen and coral waterline.
static func _motor_launch(k: VBld.Kit) -> void:
	var coral := Color("#b96359")
	var teak := Color("#b58252")
	var pts := _outline(4.2, 1.45, 1.35, 0.18)
	_hull(k, pts, 0.25, 0.42, WHITE, coral, teak)
	VBld._skirt(k, "color", VBld._grown(pts, 0.015), 0.28, 0.06, coral, Vector2.ZERO)
	# Cockpit well and raised foredeck, with a curved three-panel windshield.
	k.box("color", Vector3(0, 0.43, -0.65), Vector3(1.12, 0.04, 1.85), Color("#5c655f"))
	k.box("planks", Vector3(0, 0.49, 0.97), Vector3(0.85, 0.12, 0.75), teak)
	for sx in [-1.0, 1.0]:
		k.box("color", Vector3(sx * 0.32, 0.61, -0.25), Vector3(0.42, 0.34, 0.48), SAIL)
		VBld._beam(k, "color", Vector3(sx * 0.59, 0.47, 0.02), Vector3(sx * 0.46, 0.88, 0.44), 0.045, WHITE)
		k.poly("color", [Vector3(sx * 0.6, 0.48, -0.2), Vector3(sx * 0.46, 0.88, 0.44),
			Vector3(sx * 0.46, 0.48, 0.64)], Vector3(sx, 0, 0), Color("#6a969e"))
	k.poly("color", [Vector3(-0.46, 0.48, 0.64), Vector3(-0.46, 0.88, 0.44),
		Vector3(0.46, 0.88, 0.44), Vector3(0.46, 0.48, 0.64)], Vector3(0, 0.45, 1).normalized(), Color("#6a969e"))
	VBld._beam(k, "color", Vector3(-0.46, 0.88, 0.44), Vector3(0.46, 0.88, 0.44), 0.04, WHITE)
	k.box("color", Vector3(0, 0.61, -1.3), Vector3(1.0, 0.32, 0.36), SAIL)
	k.box("planks", Vector3(0, 0.19, -2.12), Vector3(1.05, 0.09, 0.34), teak)


## A wooden skiff: an open boat of varnished planks with two thwarts and an outboard motor on the transom.
static func _skiff(k: VBld.Kit) -> void:
	var l := 2.0
	var beam := 0.75
	var pts := _outline(l, beam, 0.7)
	VBld._skirt(k, "planks", pts, -0.12, 0.38, WOOD, Vector2.ZERO)
	VBld._skirt(k, "planks", VBld._scaled(pts, Vector2.ZERO, 0.9), -0.05, 0.31, WOOD.darkened(0.2), Vector2.ZERO, true)
	VBld._band(k, "planks", VBld._scaled(pts, Vector2.ZERO, 0.9), VBld._fill(Vector2.ZERO, pts.size()), -0.04, WOOD.darkened(0.3))
	VBld._skirt(k, "color", VBld._grown(pts, 0.02), 0.2, 0.06, Color("#2e6a4a"), Vector2.ZERO)
	for z in [-0.3, 0.3]:
		k.box("planks", Vector3(0, 0.14, z), Vector3(beam * 0.85, 0.05, 0.18), WOOD.lightened(0.1))
	k.box("color", Vector3(0, 0.38, -l / 2.0 - 0.1), Vector3(0.22, 0.34, 0.24), BLACK)
	k.box("color", Vector3(0, 0.0, -l / 2.0 - 0.14), Vector3(0.06, 0.5, 0.08), BLACK)


## A schooner under sail out in the bay: a dark green hull with a gilt stripe, two masts with gaff sails and a jib
## set, a bowsprit and a little deckhouse.
static func _schooner(k: VBld.Kit) -> void:
	var l := 4.6
	var beam := 1.3
	var pts := _outline(l, beam, 1.4, 0.25)
	_hull(k, pts, 0.3, 0.42, Color("#24483a"), BLACK, Color("#c8a878"))
	VBld._skirt(k, "color", VBld._grown(pts, 0.012), 0.26, 0.05, Color("#e0b850"), Vector2.ZERO)
	k.box("color", Vector3(0, 0.6, -0.4), Vector3(0.7, 0.36, 0.9), WOOD)
	VBld._beam(k, "color", Vector3(0, 0.42, l / 2.0 - 0.1), Vector3(0, 0.62, l / 2.0 + 0.9), 0.06, WOOD)
	for m in [[0.7, 3.6], [-0.9, 3.9]]:
		var z: float = m[0]
		var h: float = m[1]
		VBld._column(k, "color", Vector3(0, 0.4, z), 0.045, h, 6, WOOD.darkened(0.2))
		# the gaff sail: from the mast back along the boom, its head on the gaff, filled a little to port
		var foot := 0.75
		var head := 0.4 + h * 0.86
		var aft := z - 1.35
		var pts2 := [Vector3(0, foot, z - 0.05), Vector3(0.18, foot + 0.1, aft), Vector3(0.24, head - 0.3, aft + 0.2), Vector3(0, head, z - 0.05)]
		k.poly("color", pts2, Vector3(1, 0, 0), SAIL)
		k.poly("color", pts2, Vector3(-1, 0, 0), SAIL.darkened(0.12))
		VBld._beam(k, "color", Vector3(0, foot, z), Vector3(0.18, foot + 0.1, aft), 0.04, WOOD)
	var jib := [Vector3(0, 0.62, l / 2.0 + 0.85), Vector3(0, 3.8, 0.75), Vector3(0.22, 0.9, 0.85)]
	k.poly("color", jib, Vector3(1, 0, 0), SAIL)
	k.poly("color", jib, Vector3(-1, 0, 0), SAIL.darkened(0.12))
	VBld._pennant(k, Vector3(0, 4.35, -0.9), RED)
