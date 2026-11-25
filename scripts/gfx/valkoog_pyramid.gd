extends RefCounted
## Valkoog's outside (the Scaraba Desert's "valkoog" section, desert_sections.gd): the sand terraces of the stepped
## pyramid dressed as a sandstone monument, big but friendly, in the cosy painted standard
## (docs/visual_overhaul/standards.md): soft pillowed blocks, pale coping, a grand stair, a few jewel-toned banners and
## two warm braziers.
##
## dressing()  The terraces, worked out from the map's own levels inside the section's "pyramid" rectangle
##             (elevation.gd), so everything sits on the real cliff lines:
##   - each level's risers that face the camera's way (west, south, east) wear dressed blocks, every block a faint
##     shade of its own with soft joints between, standing T proud of the edge so the sand cliff's flutes stay hidden
##     behind them, under a pale coping along the landing's edge;
##   - every ramp up the middle is a flight of stone steps between low cheek walls, the landings between the flights
##     paved, and the forecourt before the doors and the apron at the stair's foot too; braziers burn on the newels at
##     the foot;
##   - banners hang on the risers either side of the stair, and on the lowest three a scarab is carved pushing a teal sun.
##   Nothing stands in the middle of a walkable tile: it all keeps to the cliff lines, the ramps and thin paving.
##   Built as a story object (desert_sights.gd) on a tile nobody can stand beside, its geometry offset back into the
##   map's own space; the meshes are remembered between visits.
## shrine()    The sanctuary on the summit: the air temple's building (voxel_buildings.gd), a stepped sandstone hall
##             with a pillared portal under a teal-inlaid lintel, its doors shut under a carved star until they open.

const VBld = preload("res://scripts/gfx/voxel_buildings.gd")
const BeastTemple = preload("res://scripts/gfx/beast_temple.gd")
const TempleLights = preload("res://scripts/gfx/temple_lights.gd")
const Elev = preload("res://scripts/world/elevation.gd")
const MapGen = preload("res://scripts/world/map_gen.gd")
const VT = preload("res://scripts/gfx/voxel_textures.gd")
const SurfaceFinish = preload("res://scripts/gfx/surface_finish.gd")
const ClothShader = preload("res://scripts/gfx/cloth_flutter.gdshader")

## How far the blocks stand out from a terrace's edge: the sand cliff's flutes reach about 0.17 (terrain_mesh.gd FLUTE
## with the desert's look), and stay behind them.
const T := 0.2
## The coping along a landing's edge: this far onto the landing, this far out past the blocks, this thick, its top this
## far above the landing.
const CAP_IN := 0.1
const CAP_OUT := 0.07
const CAP_H := 0.14
const CAP_UP := 0.035
## The blocks: about this long, this many courses to a level, joints this wide, edges rounded off this much.
const RUN := 0.95
const COURSES := 2
const JOINT := 0.022
const BEVEL := 0.03
## The stair: steps to a flight; cheek walls reaching this far out over the ramp's sides and in over its edge, standing
## this high above the steps.
const STEPS := 5
const CHEEK_OUT := 0.22
const CHEEK_IN := 0.1
const PARAPET := 0.32

const STONE := Color("#d9ab74")
const MORTAR := Color("#a47e56")
const CAP := Color("#f2dbad")
const STEP := Color("#ecd2a2")
const TEAL := Color("#7fe8d0")
## the banners and pennants, level by level: emerald, sapphire, amethyst, ruby, topaz
const JEWELS := [Color("#2f9e6e"), Color("#3264bc"), Color("#8a4cb8"), Color("#c8344c"), Color("#e8a632")]

static var _cache := {}
static var _shrines := {}
static var _cloth_mat: ShaderMaterial


## Cloth that stirs in the wind (cloth_flutter.gdshader): triangles with how freely each corner moves.
class Cloth:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()

	## A quad (corners in order round its edge) facing `nrm`, with each corner's freedom `w` and the flag's `phase`.
	func quad(pts: Array, w: Array, nrm: Vector3, col: Color, phase: float) -> void:
		tri([pts[0], pts[1], pts[2]], [w[0], w[1], w[2]], nrm, col, phase)
		tri([pts[0], pts[2], pts[3]], [w[0], w[2], w[3]], nrm, col, phase)

	func tri(pts: Array, w: Array, nrm: Vector3, col: Color, phase: float) -> void:
		var a: Vector3 = pts[0]
		var b: Vector3 = pts[1]
		var d: Vector3 = pts[2]
		# clockwise seen from the front, as the kit winds its faces
		var order := [0, 1, 2] if (b - a).cross(d - a).dot(nrm) < 0.0 else [0, 2, 1]
		for i in order:
			var p: Vector3 = pts[i]
			v.append(p)
			n.append(nrm)
			c.append(col)
			uv.append(Vector2(p.x + p.z, -p.y) * 1.5)
			uv2.append(Vector2(float(w[i]), phase))

	func mesh(mat: Material) -> ArrayMesh:
		var m := ArrayMesh.new()
		if v.is_empty():
			return m
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_COLOR] = c
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		m.surface_set_material(0, mat)
		return m


static func _cloth_material() -> ShaderMaterial:
	if _cloth_mat == null:
		_cloth_mat = ShaderMaterial.new()
		_cloth_mat.shader = ClothShader
		_cloth_mat.set_shader_parameter("cloth", VT.texture("banner"))
		_cloth_mat.set_shader_parameter("level", 1.0 / SurfaceFinish.mean("fabric"))
	return _cloth_mat


# ================================================================ the terraces
## The pyramid's dressing for `map`, from its section's `spec`: {"rect": [x, y, w, h] the tiles it covers, "anchor":
## [x, y] the tile its story object stands on}.
static func dressing(map: Dictionary, spec: Dictionary) -> Node3D:
	var rect := Rect2i(int(spec["rect"][0]), int(spec["rect"][1]), int(spec["rect"][2]), int(spec["rect"][3]))
	var anchor := Vector2i(int(spec["anchor"][0]), int(spec["anchor"][1]))
	var elev: Dictionary = map.get("elev", {})
	var key := "%s:%d:%d:%d" % [str(spec), hash(elev.get("lo", [])), hash(elev.get("hi", [])), hash(elev.get("dir", []))]
	if not _cache.has(key):
		_cache[key] = _build(map, rect)
	var parts: Dictionary = _cache[key]
	var root := Node3D.new()
	root.name = "ValkoogPyramid"
	var inner := Node3D.new()
	root.add_child(inner)
	# the story object stands on its anchor tile (world.gd tile_pos); the dressing is in the map's own space
	inner.position = -Vector3(anchor.x + 0.5, Elev.surface(map, anchor), anchor.y + 0.5)
	for m in [parts["solid"], parts["cloth"]]:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		inner.add_child(mi)
	var flames := []
	for at: Vector3 in parts["fires"]:
		var f := TempleLights.flame(at, 0.3)
		f.name = "Flame"
		inner.add_child(f)
		flames.append(f)
	if parts.has("light"):
		var l := TempleLights.light(parts["light"], 0.9, 3.4)
		inner.add_child(l)
	root.ready.connect(func(): _settle(root, inner, flames))
	return root


## Once the story object stands on its tile: the dressing back into the map's space (wherever world.gd put the object),
## and the braziers' flames licking up and settling, each in its own time.
static func _settle(root: Node3D, inner: Node3D, flames: Array) -> void:
	inner.position = -root.position
	for i in flames.size():
		var f: MeshInstance3D = flames[i]
		var base: Vector3 = f.scale
		var tw := f.create_tween().set_loops()
		tw.tween_property(f, "scale", base * Vector3(0.92, 1.16, 0.92), 0.38 + 0.07 * i).set_trans(Tween.TRANS_SINE)
		tw.tween_property(f, "scale", base, 0.45 + 0.05 * i).set_trans(Tween.TRANS_SINE)


static func _build(map: Dictionary, rect: Rect2i) -> Dictionary:
	var k := VBld.Kit.new()
	var cloth := Cloth.new()
	var levels := _levels(map, rect)
	for i in levels.size():
		var lv: Dictionary = levels[i]
		_riser(k, lv)
		var stair: Array = lv["stair"]
		if stair.is_empty():
			continue
		var zf: float = float(lv["z1"]) + T
		var y_mid: float = (float(lv["low"]) + float(lv["top"]) - CAP_H) / 2.0
		if i < 3:
			# a scarab rolling the sun, carved in the middle of each side of the lowest risers
			for x in [(float(lv["x0"]) + float(stair[0])) / 2.0, (float(stair[1]) + float(lv["x1"])) / 2.0]:
				_scarab(k, Vector3(x, y_mid, zf))
		if i > 0:
			# banners either side of the stair, a jewel to each level
			var col: Color = JEWELS[(i - 1) % JEWELS.size()]
			var y_rod: float = float(lv["top"]) - CAP_H + CAP_UP - 0.035
			for side in [-1, 1]:
				var x: float = float(stair[0]) - 0.62 if side < 0 else float(stair[1]) + 0.62
				_banner(k, cloth, Vector3(x, y_rod, zf + 0.05), 0.42, 0.7, col, float(i) * 1.7 + side)
	var flights := _flights(map, rect)
	var fires := []
	var light := Vector3.INF
	for f: Dictionary in flights:
		_flight(k, f)
	if not flights.is_empty():
		_paving(k, map, flights)
		# braziers on the newels at the foot of the lowest flight
		var low: Dictionary = flights[0]
		var y: float = float(low["low"]) + PARAPET + 0.35
		var z: float = float(low["row"]) + 0.8
		for x in [float(low["x0"]) + (CHEEK_IN - CHEEK_OUT) / 2.0, float(low["x1"]) - (CHEEK_IN - CHEEK_OUT) / 2.0]:
			_brazier(k, Vector3(x, y, z))
			fires.append(Vector3(x, y + 0.2, z))
		light = Vector3((float(low["x0"]) + float(low["x1"])) / 2.0, y + 0.6, z + 0.4)
	var out := {"solid": k.mesh(), "cloth": cloth.mesh(_cloth_material()), "fires": fires}
	if light != Vector3.INF:
		out["light"] = light
	return out


## The pyramid's levels, lowest first: each the box of tiles at or above it {"x0", "z0", "x1", "z1" (its edges), "top",
## "low" (the ground below its front), "stair": [x0, x1] the ramp cut into its front, or []}.
static func _levels(map: Dictionary, rect: Rect2i) -> Array:
	var boxes := {}
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var p := Vector2i(x, y)
			if Elev.ramp_dir(map, p) != Vector2i.ZERO or Elev.diagonal(map, p) != 0:
				continue
			var lvl := int(round(Elev.surface(map, p) / Elev.LEVEL_H))
			for k in range(1, lvl + 1):
				var b: Array = boxes.get(k, [x, y, x + 1, y + 1])
				boxes[k] = [mini(b[0], x), mini(b[1], y), maxi(b[2], x + 1), maxi(b[3], y + 1)]
	var ks := boxes.keys()
	ks.sort()
	var out := []
	for k in ks:
		var b: Array = boxes[k]
		var stair := []
		for x in range(int(b[0]), int(b[2])):
			if Elev.ramp_dir(map, Vector2i(x, int(b[3]))) == Vector2i(0, -1):
				stair = [x, x + 1] if stair.is_empty() else [stair[0], x + 1]
		out.append({"x0": int(b[0]), "z0": int(b[1]), "x1": int(b[2]), "z1": int(b[3]), "top": k * Elev.LEVEL_H,
			"low": Elev.surface(map, Vector2i(int(b[0]) - 1, int(b[3]) - 1)), "stair": stair})
	return out


## The flights: each run of ramps climbing north inside the rectangle, lowest first {"row", "x0", "x1", "low", "high"}.
static func _flights(map: Dictionary, rect: Rect2i) -> Array:
	var out := []
	for y in range(rect.end.y - 1, rect.position.y - 1, -1):
		var run := []
		for x in range(rect.position.x, rect.end.x + 1):
			var up := x < rect.end.x and Elev.ramp_dir(map, Vector2i(x, y)) == Vector2i(0, -1)
			if up:
				run.append(x)
			elif not run.is_empty():
				var p := Vector2i(int(run[0]), y)
				out.append({"row": y, "x0": int(run[0]), "x1": int(run[-1]) + 1, "low": Elev.edge(map, p, Vector2i(0, 1)),
					"high": Elev.edge(map, p, Vector2i(0, -1))})
				run = []
	return out


# ---------------------------------------------------------------- risers
## One level's risers: its west side, its front either side of the stair and its east side, as faces T out from its
## edges, each with its backing, its blocks and its coping. The corners are bonded: a full block on one face meets a
## half block on the other, turn and turn about up the courses.
static func _riser(k: VBld.Kit, lv: Dictionary) -> void:
	var ex0 := float(lv["x0"])
	var ex1 := float(lv["x1"])
	var ez0 := float(lv["z0"])
	var ez1 := float(lv["z1"])
	var x0 := ex0 - T
	var x1 := ex1 + T
	var zf := ez1 + T
	var y0 := float(lv["low"]) - 0.05
	var top := float(lv["top"])
	var y1 := top - CAP_H + CAP_UP
	var stair: Array = lv["stair"]
	# [start, end, outward, anchored at its start (the corner), which way its first course starts]
	var faces := [[Vector3(x0, 0, ez0), Vector3(x0, 0, zf), Vector3.LEFT, false, 0]]
	if stair.is_empty():
		faces.append([Vector3(x0, 0, zf), Vector3(x1, 0, zf), Vector3.BACK, true, 1])
	else:
		faces.append([Vector3(x0, 0, zf), Vector3(float(stair[0]), 0, zf), Vector3.BACK, true, 1])
		faces.append([Vector3(float(stair[1]), 0, zf), Vector3(x1, 0, zf), Vector3.BACK, false, 1])
	faces.append([Vector3(x1, 0, zf), Vector3(x1, 0, ez0), Vector3.RIGHT, true, 0])
	for f in faces:
		_face(k, f[0], f[1], f[2], y0, y1, bool(f[3]), int(f[4]))
	# the coping: the front's runs own the corners, the sides' stop where they start
	var cap_y0 := y1
	var cap_y1 := top + CAP_UP
	var reach := T + CAP_OUT
	if stair.is_empty():
		_coping(k, Vector3(ex0 - reach, 0, ez1), Vector3(ex1 + reach, 0, ez1), Vector3.BACK, cap_y0, cap_y1)
	else:
		_coping(k, Vector3(ex0 - reach, 0, ez1), Vector3(float(stair[0]), 0, ez1), Vector3.BACK, cap_y0, cap_y1)
		_coping(k, Vector3(float(stair[1]), 0, ez1), Vector3(ex1 + reach, 0, ez1), Vector3.BACK, cap_y0, cap_y1)
	_coping(k, Vector3(ex0, 0, ez0), Vector3(ex0, 0, ez1 - CAP_IN), Vector3.LEFT, cap_y0, cap_y1)
	_coping(k, Vector3(ex1, 0, ez1 - CAP_IN), Vector3(ex1, 0, ez0), Vector3.RIGHT, cap_y0, cap_y1)


## A face of blocks from a to b (at y 0, on the face's plane), facing `out`, from y0 to y1: a darker backing for the
## joints to show, then the blocks, laid from its anchored end (a if `from_a`, else b).
static func _face(k: VBld.Kit, a: Vector3, b: Vector3, out: Vector3, y0: float, y1: float, from_a: bool, parity: int) -> void:
	var length := a.distance_to(b)
	if length < 0.05:
		return
	var u := (b - a) / length
	var back := -0.04
	k.poly("color", [_p(a, u, out, 0.0, back, y0), _p(a, u, out, length, back, y0), _p(a, u, out, length, back, y1),
		_p(a, u, out, 0.0, back, y1)], out, MORTAR)
	for c in COURSES:
		var ya := lerpf(y0, y1, float(c) / COURSES)
		var yb := lerpf(y0, y1, float(c + 1) / COURSES)
		if c > 0:
			ya += JOINT / 2.0
		if c < COURSES - 1:
			yb -= JOINT / 2.0
		# breaks along the face, measured from its anchored end
		var breaks := [0.0]
		var at := RUN * (1.0 if (c + parity) % 2 == 0 else 0.5)
		while at < length - 0.001:
			breaks.append(at)
			at += RUN
		if length - float(breaks[-1]) < RUN * 0.35 and breaks.size() > 1:
			breaks.pop_back()
		breaks.append(length)
		for i in breaks.size() - 1:
			var s0: float = breaks[i]
			var s1: float = breaks[i + 1]
			if not from_a:
				var t := s0
				s0 = length - s1
				s1 = length - t
			var inner0 := s0 > 0.001
			var inner1 := s1 < length - 0.001
			var shade := absi(hash(Vector3i(int(round(a.x * 5.0 + a.z * 3.0)), c, i))) % 1000 / 1000.0
			var col := STONE.darkened(0.06 * (0.5 - shade)) if shade < 0.5 else STONE.lightened(0.06 * (shade - 0.5))
			_pillow(k, a, u, out, s0 + (JOINT / 2.0 if inner0 else 0.0), s1 - (JOINT / 2.0 if inner1 else 0.0), ya, yb,
				inner0, inner1, col)


## The point s along u from a, d out along n, at height y.
static func _p(a: Vector3, u: Vector3, n: Vector3, s: float, d: float, y: float) -> Vector3:
	return Vector3(a.x + u.x * s + n.x * d, y, a.z + u.z * s + n.z * d)


## One block: its face on the plane, its edges rounded back towards the wall (the ends only where it meets another
## block, so the corners stay crisp).
static func _pillow(k: VBld.Kit, a: Vector3, u: Vector3, n: Vector3, s0: float, s1: float, ya: float, yb: float,
		bev0: bool, bev1: bool, col: Color) -> void:
	var b := BEVEL
	var back := -BEVEL * 0.8
	var b0 := b if bev0 else 0.0
	var b1 := b if bev1 else 0.0
	var f00 := _p(a, u, n, s0 + b0, 0.0, ya + b)
	var f10 := _p(a, u, n, s1 - b1, 0.0, ya + b)
	var f11 := _p(a, u, n, s1 - b1, 0.0, yb - b)
	var f01 := _p(a, u, n, s0 + b0, 0.0, yb - b)
	var e00 := _p(a, u, n, s0, back, ya)
	var e10 := _p(a, u, n, s1, back, ya)
	var e11 := _p(a, u, n, s1, back, yb)
	var e01 := _p(a, u, n, s0, back, yb)
	k.poly("color", [f00, f10, f11, f01], n, col)
	k.poly("color", [e00, e10, f10, f00], (n - Vector3.UP).normalized(), col)
	k.poly("color", [f01, f11, e11, e01], (n + Vector3.UP).normalized(), col)
	if bev0:
		k.poly("color", [e00, f00, f01, e01], (n - u).normalized(), col)
	if bev1:
		k.poly("color", [f10, e10, e11, f11], (n + u).normalized(), col)


## Coping along a landing's edge from a to b, the landing on the far side of `out`: stones about a block long, each from
## CAP_IN onto the landing to T + CAP_OUT out over the blocks, their outer top edge rounded.
static func _coping(k: VBld.Kit, a: Vector3, b: Vector3, out: Vector3, y0: float, y1: float) -> void:
	var length := a.distance_to(b)
	if length < 0.05:
		return
	var u := (b - a) / length
	var pieces := maxi(1, int(round(length / 1.15)))
	for i in pieces:
		var s0 := length * i / pieces + (0.012 if i > 0 else 0.0)
		var s1 := length * (i + 1) / pieces - (0.012 if i < pieces - 1 else 0.0)
		var shade := 0.02 * float(absi(hash(Vector2i(int(round(a.x * 3.0 + a.z * 7.0)), i))) % 3 - 1)
		_bar(k, a, u, out, s0, s1, -CAP_IN, T + CAP_OUT, y0, y1, CAP.lightened(shade) if shade > 0 else CAP.darkened(-shade), 0.045)


## A stone bar from s0 to s1 along u (from a), from d0 to d1 out along n and from y0 to y1, its outer top edge rounded
## off by `ch`.
static func _bar(k: VBld.Kit, a: Vector3, u: Vector3, n: Vector3, s0: float, s1: float, d0: float, d1: float, y0: float,
		y1: float, col: Color, ch := 0.0) -> void:
	k.poly("color", [_p(a, u, n, s0, d0, y1), _p(a, u, n, s1, d0, y1), _p(a, u, n, s1, d1 - ch, y1), _p(a, u, n, s0, d1 - ch, y1)],
		Vector3.UP, col)
	if ch > 0.0:
		k.poly("color", [_p(a, u, n, s0, d1 - ch, y1), _p(a, u, n, s1, d1 - ch, y1), _p(a, u, n, s1, d1, y1 - ch),
			_p(a, u, n, s0, d1, y1 - ch)], (n + Vector3.UP).normalized(), col)
	k.poly("color", [_p(a, u, n, s0, d1, y0), _p(a, u, n, s1, d1, y0), _p(a, u, n, s1, d1, y1 - ch), _p(a, u, n, s0, d1, y1 - ch)],
		n, col)
	k.poly("color", [_p(a, u, n, s0, d0, y0), _p(a, u, n, s1, d0, y0), _p(a, u, n, s1, d0, y1), _p(a, u, n, s0, d0, y1)], -n, col)
	k.poly("color", [_p(a, u, n, s0, d0, y0), _p(a, u, n, s1, d0, y0), _p(a, u, n, s1, d1, y0), _p(a, u, n, s0, d1, y0)],
		Vector3.DOWN, col.darkened(0.3))
	for e in [[s0, -u], [s1, u]]:
		var s: float = e[0]
		var en: Vector3 = e[1]
		k.poly("color", [_p(a, u, n, s, d0, y0), _p(a, u, n, s, d1, y0), _p(a, u, n, s, d1, y1 - ch), _p(a, u, n, s, d0, y1 - ch)],
			en, col)
		if ch > 0.0:
			k.poly("color", [_p(a, u, n, s, d0, y1 - ch), _p(a, u, n, s, d1, y1 - ch), _p(a, u, n, s, d1 - ch, y1),
				_p(a, u, n, s, d0, y1)], en, col)


# ---------------------------------------------------------------- the stair
## A flight of steps over one ramp, between cheek walls with a sloping coping and a newel at their foot. Each tread
## stands at the ramp's height at its back edge, so a foot on the slope sinks a little into the step rather than floating.
static func _flight(k: VBld.Kit, f: Dictionary) -> void:
	var x0 := float(f["x0"])
	var x1 := float(f["x1"])
	var r := float(f["row"])
	var lo := float(f["low"])
	var hi := float(f["high"])
	var rise := (hi - lo) / STEPS
	var run := 1.0 / STEPS
	for i in STEPS:
		var zf := r + 1.0 - i * run
		var zb := zf - run
		var top := lo + (i + 1) * rise
		var body := top - 0.045 - (lo - 0.05)
		k.box("color", Vector3((x0 + x1) / 2.0, lo - 0.05 + body / 2.0, (zf + zb) / 2.0), Vector3(x1 - x0, body, run), STONE.lightened(0.05))
		_bar(k, Vector3(x0, 0, zb), Vector3.RIGHT, Vector3.BACK, 0.0, x1 - x0, 0.0, run + 0.03, top - 0.045, top,
			STEP.lightened(0.02 * (i % 2)), 0.025)
	for side in [-1, 1]:
		var xo := x0 - CHEEK_OUT if side < 0 else x1 + CHEEK_OUT
		var xi := x0 + CHEEK_IN if side < 0 else x1 - CHEEK_IN
		var out := Vector3(side, 0, 0)
		var col := STONE.darkened(0.03)
		# the wall: its two sides, its foot's end and its head's
		for x in [xo, xi]:
			k.poly("color", [Vector3(x, lo - 0.05, r), Vector3(x, lo - 0.05, r + 1.0), Vector3(x, lo + PARAPET, r + 1.0),
				Vector3(x, hi + PARAPET, r)], out if x == xo else -out, col)
		k.poly("color", [Vector3(xo, lo - 0.05, r + 1.0), Vector3(xi, lo - 0.05, r + 1.0), Vector3(xi, lo + PARAPET, r + 1.0),
			Vector3(xo, lo + PARAPET, r + 1.0)], Vector3.BACK, col)
		k.poly("color", [Vector3(xo, hi - 0.05, r), Vector3(xi, hi - 0.05, r), Vector3(xi, hi + PARAPET, r), Vector3(xo, hi + PARAPET, r)],
			Vector3.FORWARD, col)
		# a joint or two down its side, so it reads as laid stone
		for t in [0.5]:
			var zj := r + t
			var yj := lerpf(hi, lo, t) + PARAPET
			k.poly("color", [Vector3(xo + side * 0.004, lo + 0.02, zj - 0.01), Vector3(xo + side * 0.004, lo + 0.02, zj + 0.01),
				Vector3(xo + side * 0.004, yj - 0.04, zj + 0.01), Vector3(xo + side * 0.004, yj - 0.04, zj - 0.01)], out, MORTAR)
		# its coping, sloping with the steps
		var cw := 0.035
		var slope_n := Vector3(0, 1.0, hi - lo).normalized()
		var ya := hi + PARAPET
		var yb := lo + PARAPET
		var th := 0.07
		var xl := minf(xo, xi) - cw
		var xr := maxf(xo, xi) + cw
		k.poly("color", [Vector3(xl, ya + th, r - 0.02), Vector3(xr, ya + th, r - 0.02), Vector3(xr, yb + th, r + 1.0),
			Vector3(xl, yb + th, r + 1.0)], slope_n, CAP)
		for x in [xl, xr]:
			k.poly("color", [Vector3(x, ya, r - 0.02), Vector3(x, yb, r + 1.0), Vector3(x, yb + th, r + 1.0), Vector3(x, ya + th, r - 0.02)],
				Vector3(signf(x - (xo + xi) / 2.0), 0, 0), CAP.darkened(0.06))
		# the newel at its foot
		var nx := (xo + xi) / 2.0
		var nz := r + 0.8
		var ntop := lo + PARAPET + 0.28
		k.box("color", Vector3(nx, (lo - 0.05 + ntop) / 2.0, nz), Vector3(0.42, ntop - lo + 0.05, 0.42), STONE.lightened(0.02))
		_bar(k, Vector3(nx - 0.25, 0, nz - 0.25), Vector3.RIGHT, Vector3.BACK, 0.0, 0.5, 0.0, 0.5, ntop, ntop + 0.07, CAP, 0.03)


## The paving in the stair's channel: the landings between flights, the forecourt above the last (up to the building
## before it) and the apron at the foot of the first, in big flags with soft joints, a hair above the sand.
static func _paving(k: VBld.Kit, map: Dictionary, flights: Array) -> void:
	var areas := []
	for i in flights.size():
		var f: Dictionary = flights[i]
		var x0 := float(f["x0"]) - CHEEK_OUT
		var x1 := float(f["x1"]) + CHEEK_OUT
		if i == 0:
			areas.append([x0, x1, float(f["row"]) + 1.0, float(f["row"]) + 2.0, float(f["low"])])
		var z_top := float(f["row"])
		var z_end := z_top
		if i + 1 < flights.size():
			z_end = float(flights[i + 1]["row"]) + 1.0
		else:
			# up to whatever stands at the top: the doors' building
			var y := int(f["row"]) - 1
			while y > 0 and MapGen.walkable(MapGen.get_t(map, int(f["x0"]), y)) and absf(Elev.surface(map, Vector2i(int(f["x0"]), y)) - float(f["high"])) < 0.01:
				y -= 1
			z_end = float(y + 1)
		if z_end < z_top:
			areas.append([x0, x1, z_end, z_top, float(f["high"])])
	for a in areas:
		var ax0: float = a[0]
		var ax1: float = a[1]
		var az0: float = a[2]
		var az1: float = a[3]
		var y: float = a[4]
		var nx := maxi(1, int(round((ax1 - ax0) / 1.2)))
		var nz := maxi(1, int(round(az1 - az0)))
		for ix in nx:
			for iz in nz:
				var fx0 := lerpf(ax0, ax1, float(ix) / nx) + (0.012 if ix > 0 else 0.0)
				var fx1 := lerpf(ax0, ax1, float(ix + 1) / nx) - (0.012 if ix < nx - 1 else 0.0)
				var fz0 := lerpf(az0, az1, float(iz) / nz) + (0.012 if iz > 0 else 0.0)
				var fz1 := lerpf(az0, az1, float(iz + 1) / nz) - (0.012 if iz < nz - 1 else 0.0)
				var shade := 0.025 * float((ix + iz * 2) % 3 - 1)
				var col := STEP.lightened(shade) if shade > 0.0 else STEP.darkened(-shade)
				_bar(k, Vector3(fx0, 0, fz0), Vector3.RIGHT, Vector3.BACK, 0.0, fx1 - fx0, 0.0, fz1 - fz0, y - 0.06, y + 0.022, col, 0.015)


## A stone brazier bowl on a short stem, standing on a newel's cap at `at`, with its coals (the flame is added live).
static func _brazier(k: VBld.Kit, at: Vector3) -> void:
	BeastTemple._frustum(k, "color", at, 0.07, 0.06, 0.0, 0.12, STONE.darkened(0.1), 8)
	BeastTemple._frustum(k, "color", at, 0.12, 0.27, 0.12, 0.3, CAP.darkened(0.04), 10)
	BeastTemple._frustum(k, "color", at, 0.25, 0.22, 0.3, 0.33, CAP, 10)
	BeastTemple._frustum(k, "color", at, 0.21, 0.0, 0.26, 0.31, Color("#5a3424"), 10)


# ---------------------------------------------------------------- carvings and cloth
## A scarab rolling the sun on a round stone, set into a south-facing riser at `c` (the face's plane).
static func _scarab(k: VBld.Kit, c: Vector3) -> void:
	var z := c.z
	_disc(k, "color", Vector3(c.x, c.y, z + 0.018), 0.3, 0.3, 14, CAP.darkened(0.03))
	_disc(k, "color", Vector3(c.x, c.y, z + 0.026), 0.26, 0.26, 14, CAP.lightened(0.04))
	var body := STONE.darkened(0.16)
	# its legs, three a side, then the body, the line between its wing cases and its head
	for side in [-1, 1]:
		for j in 3:
			var y := c.y - 0.09 + j * 0.065
			var x0 := c.x + side * 0.08
			var x1 := c.x + side * (0.16 + 0.02 * (1 - absi(j - 1)))
			var y1 := y + (0.04 if j == 2 else (-0.04 if j == 0 else 0.0))
			k.poly("color", [Vector3(x0, y - 0.012, z + 0.032), Vector3(x1, y1 - 0.012, z + 0.032), Vector3(x1, y1 + 0.012, z + 0.032),
				Vector3(x0, y + 0.012, z + 0.032)], Vector3.BACK, body)
	_disc(k, "color", Vector3(c.x, c.y - 0.04, z + 0.04), 0.1, 0.13, 12, body)
	k.poly("color", [Vector3(c.x - 0.008, c.y - 0.16, z + 0.044), Vector3(c.x + 0.008, c.y - 0.16, z + 0.044),
		Vector3(c.x + 0.008, c.y + 0.07, z + 0.044), Vector3(c.x - 0.008, c.y + 0.07, z + 0.044)], Vector3.BACK, body.darkened(0.25))
	_disc(k, "color", Vector3(c.x, c.y + 0.11, z + 0.04), 0.065, 0.045, 10, body.lightened(0.05))
	# the sun it pushes, in teal, held up between its front legs
	for side in [-1, 1]:
		k.poly("color", [Vector3(c.x + side * 0.04, c.y + 0.1, z + 0.034), Vector3(c.x + side * 0.065, c.y + 0.11, z + 0.034),
			Vector3(c.x + side * 0.06, c.y + 0.2, z + 0.034), Vector3(c.x + side * 0.04, c.y + 0.19, z + 0.034)], Vector3.BACK, body)
	_disc(k, "glow", Vector3(c.x, c.y + 0.215, z + 0.042), 0.068, 0.068, 12, TEAL)


## A flat oval in a south-facing plane, as a fan.
static func _disc(k: VBld.Kit, mat: String, c: Vector3, rx: float, ry: float, sides: int, col: Color) -> void:
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		k.poly(mat, [c, c + Vector3(cos(a0) * rx, sin(a0) * ry, 0), c + Vector3(cos(a1) * rx, sin(a1) * ry, 0)], Vector3.BACK, col)


## A banner hanging from a rod at `top` (its middle, just in front of a south-facing riser), `w` wide and `h` long: the
## jewel `col` with a pale band near its foot and a swallowtail, stirring a little more the lower it hangs.
static func _banner(k: VBld.Kit, cloth: Cloth, top: Vector3, w: float, h: float, col: Color, phase: float) -> void:
	k.box("color", top + Vector3(0, 0.012, -0.01), Vector3(w + 0.1, 0.035, 0.035), Color("#6a4630"))
	for side in [-1, 1]:
		k.box("color", top + Vector3(side * (w / 2.0 + 0.06), 0.012, -0.01), Vector3(0.05, 0.05, 0.05), CAP)
	var rows := [0.0, 0.3, 0.6, 0.7, 0.78, 0.86]
	var pale := CAP.lightened(0.1)
	var wt := func(f: float) -> float: return pow(f, 1.3) * 0.5
	for j in rows.size() - 1:
		var fa: float = rows[j]
		var fb: float = rows[j + 1]
		var band := pale if j == 3 else col
		for i in 2:
			var xa := top.x - w / 2.0 + w * i / 2.0
			var xb := xa + w / 2.0
			cloth.quad([Vector3(xa, top.y - fa * h, top.z), Vector3(xb, top.y - fa * h, top.z), Vector3(xb, top.y - fb * h, top.z),
				Vector3(xa, top.y - fb * h, top.z)], [wt.call(fa), wt.call(fa), wt.call(fb), wt.call(fb)], Vector3.BACK, band, phase)
	# the swallowtail
	var y0 := top.y - 0.86 * h
	var yn := top.y - 0.93 * h
	var y1 := top.y - h
	cloth.quad([Vector3(top.x - w / 2.0, y0, top.z), Vector3(top.x, y0, top.z), Vector3(top.x, yn, top.z), Vector3(top.x - w / 2.0, y1, top.z)],
		[wt.call(0.86), wt.call(0.86), wt.call(0.93), wt.call(1.0)], Vector3.BACK, col, phase)
	cloth.quad([Vector3(top.x, y0, top.z), Vector3(top.x + w / 2.0, y0, top.z), Vector3(top.x + w / 2.0, y1, top.z), Vector3(top.x, yn, top.z)],
		[wt.call(0.86), wt.call(0.86), wt.call(1.0), wt.call(0.93)], Vector3.BACK, col, phase)


## A pennant flying east from the top of a pole at `p`: a long triangle, freer towards its tip.
static func _pennant(cloth: Cloth, p: Vector3, col: Color, phase: float, length := 0.72) -> void:
	var a := p
	var b := p + Vector3(0, -0.3, 0)
	var tip := p + Vector3(length, -0.13, 0)
	var parts := 4
	for i in parts:
		var t0 := float(i) / parts
		var t1 := float(i + 1) / parts
		var pts := [a.lerp(tip, t0), a.lerp(tip, t1), b.lerp(tip, t1), b.lerp(tip, t0)]
		var w := [t0, t1, t1, t0]
		if i == parts - 1:
			cloth.tri([pts[0], pts[1], pts[3]], [t0, t1, t0], Vector3.BACK, col, phase)
		else:
			cloth.quad(pts, w, Vector3.BACK, col if i % 2 == 0 else col.lightened(0.08), phase)


# ================================================================ the summit
## The air temple's building (a shop "temple" of temple "air"): fills `node` (centred on its plot, the summit's floor at
## y 0, its front +z) with the sanctuary. The doorway is two tiles wide and centred on the plot (on the stair), so the
## map's door tile stands in it; shut (`locked`) it holds stone doors under a carved star whose points glow.
static func shrine(node: Node3D, w: float, d: float, door_lx: float, locked: bool, glow: Color) -> void:
	var px := 0.0 if absf(door_lx) <= 0.5 else door_lx
	var key := "%.2f:%.2f:%.2f:%s" % [w, d, px, locked]
	if not _shrines.has(key):
		var k := VBld.Kit.new()
		var cloth := Cloth.new()
		_shrine_body(k, cloth, w, d, px, locked)
		_shrines[key] = [k.mesh(), cloth.mesh(_cloth_material())]
	for m in _shrines[key]:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		node.add_child(mi)
	# the temple's gem over its crown, as every elemental temple has, and a teal light at its door
	var gem := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.45, 0.75, 0.45)
	gem.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = glow
	gm.emission_enabled = true
	gm.emission = glow
	gm.emission_energy_multiplier = 2.5
	gem.material_override = gm
	gem.position = Vector3(0, 6.05, -0.2)
	gem.set_meta("spin", true)
	node.add_child(gem)
	var l := OmniLight3D.new()
	l.light_color = TEAL
	l.light_energy = 1.1
	l.omni_range = 3.8
	l.shadow_enabled = false
	l.position = Vector3(px, 1.5, d / 2.0 + 0.9)
	node.add_child(l)


static func _shrine_body(k: VBld.Kit, cloth: Cloth, w: float, d: float, px: float, locked: bool) -> void:
	var hw := w / 2.0 - 0.1
	var hd := d / 2.0 - 0.1
	# the podium, with a pale lip
	k.box("color", Vector3(0, 0.08, 0), Vector3(hw * 2.0, 0.26, hd * 2.0), STONE.darkened(0.06))
	k.box("color", Vector3(0, 0.2, 0), Vector3(hw * 2.0 + 0.08, 0.08, hd * 2.0 + 0.08), CAP)
	# a step up to the doors
	_bar(k, Vector3(px - 1.1, 0, hd - 0.02), Vector3.RIGHT, Vector3.BACK, 0.0, 2.2, 0.0, 0.2, -0.02, 0.12, STEP, 0.02)
	# the hall
	var hx := hw - 0.35
	var zf := hd - 0.55
	var zb := -hd + 0.3
	var y0 := 0.24
	var y1 := 2.9
	_walls(k, hx, zb, zf, y0, y1, [px - 1.32, px + 1.32])
	_cornice(k, hx, zb, zf, y1)
	# a frieze of teal tiles under the cornice, along the front and the sides
	var fy := y1 - 0.17
	for s in range(0, 13):
		var x := -hx + 0.25 + s * (2.0 * hx - 0.5) / 12.0
		if absf(x - px) < 1.6:
			continue
		k.box("glow", Vector3(x, fy, zf + 0.012), Vector3(0.09, 0.09, 0.012), TEAL)
	for side in [-1, 1]:
		for s in range(0, 7):
			var z := zb + 0.25 + s * (zf - zb - 0.5) / 6.0
			k.box("glow", Vector3(side * (hx + 0.012), fy, z), Vector3(0.012, 0.09, 0.09), TEAL)
	# the upper tier and its cornice, the crown, and a capstone tipped in teal
	_walls(k, hx - 0.75, zb + 0.4, zf - 0.5, y1 + 0.22, y1 + 1.08, [])
	_cornice(k, hx - 0.75, zb + 0.4, zf - 0.5, y1 + 1.08)
	var cy := y1 + 1.3
	_walls(k, 1.05, -0.85, 0.45, cy, cy + 0.45, [])
	k.box("color", Vector3(0, cy + 0.51, -0.2), Vector3(2.3, 0.12, 1.5), CAP)
	_pyramidion(k, Vector3(0, cy + 0.57, -0.2), 0.95, 0.62, 0.72)
	# the portal
	_portal(k, px, zf, y0, locked)
	# obelisks either side of it, on the podium
	for side in [-1, 1]:
		_obelisk(k, Vector3(side * (hx - 0.38), y0, zf + 0.3))
	# pennants flying from the hall's corners
	var i := 0
	for z in [zf + 0.08, zb - 0.08]:
		for side in [-1, 1]:
			var p := Vector3(side * (hx + 0.08), y1 + 0.22, z)
			k.box("color", p + Vector3(0, 0.7, 0), Vector3(0.05, 1.4, 0.05), Color("#6a4630"))
			k.box("color", p + Vector3(0, 1.43, 0), Vector3(0.09, 0.07, 0.09), CAP)
			_pennant(cloth, p + Vector3(0.025, 1.36, 0), JEWELS[(i * 2 + 1) % JEWELS.size()], float(i) * 2.1)
			i += 1


## Four block walls round a box (x within ±hx, z from zb to zf, y from y0 to y1) over a darker backing; `gap`: [x0, x1]
## left open in the front for the portal.
static func _walls(k: VBld.Kit, hx: float, zb: float, zf: float, y0: float, y1: float, gap: Array) -> void:
	var fronts := [[-hx, hx]] if gap.is_empty() else [[-hx, float(gap[0])], [float(gap[1]), hx]]
	var quads := []
	for f in fronts:
		quads.append([[Vector3(f[0], y0, zf), Vector3(f[1], y0, zf), Vector3(f[1], y1, zf), Vector3(f[0], y1, zf)], Vector3.BACK])
	quads.append([[Vector3(hx, y0, zf), Vector3(hx, y0, zb), Vector3(hx, y1, zb), Vector3(hx, y1, zf)], Vector3.RIGHT])
	quads.append([[Vector3(-hx, y0, zb), Vector3(-hx, y0, zf), Vector3(-hx, y1, zf), Vector3(-hx, y1, zb)], Vector3.LEFT])
	quads.append([[Vector3(hx, y0, zb), Vector3(-hx, y0, zb), Vector3(-hx, y1, zb), Vector3(hx, y1, zb)], Vector3.FORWARD])
	for q in quads:
		k.poly("color", q[0], q[1], MORTAR)
		BeastTemple._blocks_on(k, q[0], q[1], STONE.lightened(0.03), 0.45, 0.9)
	k.poly("color", [Vector3(-hx, y1, zb), Vector3(hx, y1, zb), Vector3(hx, y1, zf), Vector3(-hx, y1, zf)], Vector3.UP, STONE)


## A two-step cornice round the top of a box of walls at y.
static func _cornice(k: VBld.Kit, hx: float, zb: float, zf: float, y: float) -> void:
	var cz := (zb + zf) / 2.0
	k.box("color", Vector3(0, y + 0.06, cz), Vector3(hx * 2.0 + 0.16, 0.12, zf - zb + 0.16), CAP.darkened(0.04))
	k.box("color", Vector3(0, y + 0.16, cz), Vector3(hx * 2.0 + 0.3, 0.1, zf - zb + 0.3), CAP)


## A four-sided capstone on a base `hx` by `hz` round c, `h` tall, its tip in teal.
static func _pyramidion(k: VBld.Kit, c: Vector3, hx: float, hz: float, h: float) -> void:
	var apex := c + Vector3(0, h, 0)
	var corners := [c + Vector3(-hx, 0, hz), c + Vector3(hx, 0, hz), c + Vector3(hx, 0, -hz), c + Vector3(-hx, 0, -hz)]
	var tip := 0.3
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var nrm := (b - a).cross(apex - a).normalized()
		if nrm.dot((a + b) / 2.0 - c) < 0.0:
			nrm = -nrm
		var am := a.lerp(apex, 1.0 - tip)
		var bm := b.lerp(apex, 1.0 - tip)
		k.poly("color", [a, b, bm, am], nrm, CAP)
		k.poly("glow", [am, bm, apex], nrm, TEAL)


## The portal at x px in the front wall (zf): pilasters with teal inlay, a lintel with a teal band, a crest bearing a
## winged teal sun, and the doorway: stone doors under a carved star while `locked`, else the dark with a stair going up.
static func _portal(k: VBld.Kit, px: float, zf: float, y0: float, locked: bool) -> void:
	var pale := STONE.lightened(0.08)
	var yt := 2.62
	for side in [-1, 1]:
		var cx := px + side * 1.12
		var q := [Vector3(cx - 0.2, y0, zf + 0.4), Vector3(cx + 0.2, y0, zf + 0.4), Vector3(cx + 0.2, yt, zf + 0.4), Vector3(cx - 0.2, yt, zf + 0.4)]
		k.box("color", Vector3(cx, (y0 + yt) / 2.0, zf + 0.175), Vector3(0.4, yt - y0, 0.45), pale.darkened(0.08))
		BeastTemple._blocks_on(k, q, Vector3.BACK, pale, 0.44, 0.4)
		k.box("glow", Vector3(cx, (y0 + yt) / 2.0 + 0.1, zf + 0.414), Vector3(0.07, yt - y0 - 0.7, 0.01), TEAL)
	# the lintel and its teal band
	_bar(k, Vector3(px - 1.5, 0, zf - 0.05), Vector3.RIGHT, Vector3.BACK, 0.0, 3.0, 0.0, 0.53, yt, yt + 0.46, CAP, 0.05)
	k.box("glow", Vector3(px, yt + 0.21, zf + 0.485), Vector3(2.2, 0.1, 0.01), TEAL)
	# the crest over it: a winged sun
	k.box("color", Vector3(px, yt + 0.62, zf + 0.15), Vector3(1.5, 0.32, 0.36), CAP.darkened(0.05))
	_disc(k, "glow", Vector3(px, yt + 0.62, zf + 0.335), 0.12, 0.12, 14, TEAL)
	for side in [-1, 1]:
		for j in 3:
			var x0 := px + side * 0.16
			var x1 := px + side * (0.68 - j * 0.1)
			var y := yt + 0.7 - j * 0.07
			k.poly("color", [Vector3(x0, y - 0.025, zf + 0.335), Vector3(x1, y + 0.02 - j * 0.02, zf + 0.335), Vector3(x1, y + 0.05 - j * 0.02, zf + 0.335),
				Vector3(x0, y + 0.03, zf + 0.335)], Vector3.BACK, STONE.lightened(0.1 - j * 0.04))
	# the doorway: reveals and a soffit in shadowed stone
	var hw := 0.92
	var zd := zf - 0.5
	var shade := STONE.darkened(0.35)
	for side in [-1, 1]:
		# (a hair inside the pilasters' own faces, so the two never fight)
		var x := px + side * (hw - 0.004)
		k.poly("color", [Vector3(x, y0, zf + 0.4), Vector3(x, y0, zd), Vector3(x, yt, zd), Vector3(x, yt, zf + 0.4)], Vector3(-side, 0, 0), shade)
	k.poly("color", [Vector3(px - hw, yt, zd), Vector3(px + hw, yt, zd), Vector3(px + hw, yt, zf + 0.4), Vector3(px - hw, yt, zf + 0.4)], Vector3.DOWN, shade.darkened(0.2))
	k.poly("color", [Vector3(px - hw, y0 + 0.004, zd), Vector3(px + hw, y0 + 0.004, zd), Vector3(px + hw, y0 + 0.004, zf + 0.4),
		Vector3(px - hw, y0 + 0.004, zf + 0.4)], Vector3.UP, STEP.darkened(0.25))
	if locked:
		# two stone leaves, a great star carved across them, its five points glowing faintly
		var zl := zf - 0.1
		for side in [-1, 1]:
			var xa := px + side * 0.006
			var xb := px + side * hw
			k.poly("color", [Vector3(xa, y0, zl), Vector3(xb, y0, zl), Vector3(xb, yt, zl), Vector3(xa, yt, zl)], Vector3.BACK, STONE.darkened(0.06))
		k.box("color", Vector3(px, (y0 + yt) / 2.0, zl + 0.004), Vector3(0.014, yt - y0, 0.008), MORTAR.darkened(0.2))
		var sc := Vector3(px, 1.45, zl + 0.008)
		var pts := []
		for i in 10:
			var a := PI / 2.0 + i * PI / 5.0
			var rr := 0.62 if i % 2 == 0 else 0.26
			pts.append(sc + Vector3(cos(a) * rr, sin(a) * rr, 0))
		for i in 10:
			k.poly("color", [sc, pts[i], pts[(i + 1) % 10]], Vector3.BACK, STONE.darkened(0.3))
		for i in 5:
			var a := PI / 2.0 + i * TAU / 5.0
			_disc(k, "glow", sc + Vector3(cos(a) * 0.52, sin(a) * 0.52, 0.004), 0.045, 0.045, 8, TEAL)
	else:
		# open: the dark within, a stair climbing into it, and a faint teal light on its steps
		k.poly("color", [Vector3(px - hw, y0, zd), Vector3(px + hw, y0, zd), Vector3(px + hw, yt, zd), Vector3(px - hw, yt, zd)], Vector3.BACK, Color("#16110d"))
		for j in 3:
			var zs := zd + 0.42 - j * 0.14
			var st := 0.16 * (j + 1)
			k.box("color", Vector3(px, y0 + st / 2.0, zs), Vector3(hw * 2.0 - 0.02, st, 0.14), Color("#2c2219"))
			k.box("glow", Vector3(px, y0 + st - 0.006, zs + 0.071), Vector3(hw * 2.0 - 0.2, 0.012, 0.004), Color("#2f7a6c"))


## A slim obelisk on its plinth at `at`, its tip in teal.
static func _obelisk(k: VBld.Kit, at: Vector3) -> void:
	k.box("color", at + Vector3(0, 0.1, 0), Vector3(0.48, 0.2, 0.48), CAP)
	var y0 := at.y + 0.2
	var y1 := at.y + 1.95
	var r0 := 0.16
	var r1 := 0.11
	var col := STONE.lightened(0.07)
	var sides := [[Vector3.BACK, Vector3.RIGHT], [Vector3.RIGHT, Vector3.FORWARD], [Vector3.FORWARD, Vector3.LEFT], [Vector3.LEFT, Vector3.BACK]]
	for s in sides:
		var n: Vector3 = s[0]
		var u: Vector3 = s[1]
		var c0 := Vector3(at.x, y0, at.z) + n * r0
		var c1 := Vector3(at.x, y1, at.z) + n * r1
		k.poly("color", [c0 - u * r0, c0 + u * r0, c1 + u * r1, c1 - u * r1], (n + Vector3.UP * 0.03).normalized(), col)
	# a teal glyph down its face
	for j in 3:
		k.box("glow", Vector3(at.x, y0 + 0.45 + j * 0.38, at.z + lerpf(r0, r1, (0.45 + j * 0.38) / (y1 - y0)) + 0.004), Vector3(0.07, 0.07, 0.008), TEAL)
	_pyramidion(k, Vector3(at.x, y1, at.z), r1, r1, 0.26)
