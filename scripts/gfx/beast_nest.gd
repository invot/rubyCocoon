extends RefCounted
## The raised nest a temple's guardian rests in: a round bowl of woven sticks, 3 tiles across, on a thick wall of
## sticks laid round and round with a lipped rim of heaped sticks, a few strays poking out. A solid core under the
## sticks keeps the floor from showing through. One mesh (one draw call), on the soft wood grain the kit's beams use,
## each stick tinted its own brown; built once and cached. Origin: the middle of the nest at floor level.

const VT = preload("res://scripts/gfx/voxel_textures.gd")

## the nest's outer radius at its foot, its rim's inner radius, the height of the bowl's floor (where the guardian
## lies) and of the top of its rim
const R_OUT := 1.42
const R_IN := 1.02
const FLOOR_H := 0.36
const LIP_H := 0.66
## the tiles it covers round its middle tile
const TILES := [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]
const BROWNS := ["#7a5530", "#8f6a40", "#6a4728", "#a07a4a", "#5e4026", "#86603a"]
const CORE := Color("#4a321e")
const SIDES := 6

static var _mesh: ArrayMesh


static func mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7311
	_core(st)
	# the wall: rings of sticks laid round the outside, each a short chord tilted a little
	var rows := 7
	for j in rows:
		var f := float(j) / (rows - 1)
		var h := lerpf(0.06, LIP_H - 0.14, f)
		var r := _wall_r(h) + 0.035
		var n := 20
		var off := rng.randf() * TAU
		for i in n:
			var a := off + TAU * i / n + rng.randf_range(-0.08, 0.08)
			var half := rng.randf_range(0.2, 0.28)
			var tilt := rng.randf_range(-0.09, 0.09)
			var p0 := _ring(a - half, r, h - tilt)
			var p1 := _ring(a + half, r, h + tilt)
			_stick(st, p0, p1, rng.randf_range(0.03, 0.045), rng)
	# the rim: sticks heaped round the top, from the inner edge to the outer, in a thick lip
	var lip_r := [R_IN + 0.04, (R_IN + _wall_r(LIP_H - 0.1)) / 2.0, _wall_r(LIP_H - 0.1) + 0.02]
	for k in lip_r.size():
		var n := 26
		var off := rng.randf() * TAU
		for i in n:
			var a := off + TAU * i / n + rng.randf_range(-0.06, 0.06)
			var half := rng.randf_range(0.16, 0.24)
			var h := LIP_H - 0.06 + (0.03 if k == 1 else 0.0) + rng.randf_range(-0.03, 0.03)
			var tilt := rng.randf_range(-0.05, 0.05)
			var r: float = lip_r[k] + rng.randf_range(-0.03, 0.03)
			_stick(st, _ring(a - half, r + rng.randf_range(-0.05, 0.05), h - tilt), _ring(a + half, r, h + tilt), rng.randf_range(0.035, 0.05), rng)
	# sticks lying across the rim, inner edge to outer
	for i in 22:
		var a := rng.randf() * TAU
		var p0 := _ring(a, R_IN - 0.05, LIP_H - 0.1)
		var p1 := _ring(a + rng.randf_range(-0.25, 0.25), _wall_r(LIP_H - 0.12) + 0.12, LIP_H - 0.02 + rng.randf_range(-0.03, 0.04))
		_stick(st, p0, p1, rng.randf_range(0.025, 0.04), rng)
	# strays poking out of the wall
	for i in 14:
		var a := rng.randf() * TAU
		var h := rng.randf_range(0.12, LIP_H - 0.18)
		var p0 := _ring(a, _wall_r(h) - 0.05, h)
		var p1 := _ring(a + rng.randf_range(-0.5, 0.5), _wall_r(h) + rng.randf_range(0.22, 0.34), h + rng.randf_range(-0.1, 0.12))
		_stick(st, p0, p1, rng.randf_range(0.018, 0.028), rng)
	# the bowl's floor: sticks lying every which way under the guardian
	for i in 18:
		var c := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, R_IN - 0.35)
		var d := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.25, 0.4)
		_stick(st, Vector3(c.x - d.x, FLOOR_H + 0.02, c.y - d.y), Vector3(c.x + d.x, FLOOR_H + 0.03, c.y + d.y), rng.randf_range(0.025, 0.035), rng)
	st.generate_tangents()
	_mesh = st.commit()
	var mat := VT.kit_material("wood_dark")
	_mesh.surface_set_material(0, mat)
	return _mesh


## The core's outer radius at height h: sloping in from the foot to the rim.
static func _wall_r(h: float) -> float:
	var t := clampf(h / LIP_H, 0.0, 1.0)
	return lerpf(R_OUT - 0.04, R_OUT - 0.24, t * t)


static func _ring(a: float, r: float, h: float) -> Vector3:
	return Vector3(cos(a) * r, h, sin(a) * r)


## The solid bowl under the sticks: turned from a profile (outer wall, rounded rim, inner wall, floor).
static func _core(st: SurfaceTool) -> void:
	var prof := [Vector2(0.0, FLOOR_H), Vector2(R_IN - 0.25, FLOOR_H), Vector2(R_IN - 0.06, FLOOR_H + 0.08),
		Vector2(R_IN, LIP_H - 0.16), Vector2(R_IN + 0.08, LIP_H - 0.06)]
	for i in 5:
		var h := LIP_H - 0.06 - (LIP_H - 0.06) * i / 4.0
		prof.append(Vector2(_wall_r(h), h))
	var segs := 36
	var col := CORE
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		for j in prof.size() - 1:
			var p: Vector2 = prof[j]
			var q: Vector2 = prof[j + 1]
			var v := [_ring(a0, p.x, p.y), _ring(a1, p.x, p.y), _ring(a1, q.x, q.y), _ring(a0, q.x, q.y)]
			var n: Vector3 = (v[1] - v[0]).cross(v[3] - v[0])
			if n.length() < 1e-6:
				n = ((v[2] as Vector3) - v[0]).cross((v[3] as Vector3) - v[0])
			# (faces outward and up: wind them so)
			var up := Vector3(cos((a0 + a1) / 2.0), 0, sin((a0 + a1) / 2.0)) * (q.y - p.y) - Vector3.UP * (q.x - p.x)
			if n.dot(up) < 0.0:
				v = [v[0], v[3], v[2], v[1]]
				n = -n
			n = n.normalized()
			for t in [[0, 1, 2], [0, 2, 3]]:
				for k in t:
					st.set_color(col)
					st.set_normal(n)
					st.set_uv(Vector2((a0 if k in [0, 3] else a1) * 2.0, (p.y if k < 2 else q.y) * 3.0))
					st.add_vertex(v[k])


## One stick from a to b: a tapered tube, its grain along its length, in its own brown.
static func _stick(st: SurfaceTool, a: Vector3, b: Vector3, r: float, rng: RandomNumberGenerator) -> void:
	var col := Color(String(BROWNS[rng.randi() % BROWNS.size()])).lightened(rng.randf_range(-0.05, 0.08))
	var z := (b - a).normalized()
	var x := (Vector3.UP if absf(z.y) < 0.9 else Vector3.RIGHT).cross(z).normalized()
	var y := z.cross(x)
	var len := a.distance_to(b)
	var r1 := r * rng.randf_range(0.6, 0.8)
	var spin := rng.randf() * TAU
	var v0 := rng.randf() * 4.0
	for i in SIDES:
		var t0 := spin + TAU * i / SIDES
		var t1 := spin + TAU * (i + 1) / SIDES
		var d0 := x * cos(t0) + y * sin(t0)
		var d1 := x * cos(t1) + y * sin(t1)
		var quad := [[a + d0 * r, d0, Vector2(v0, float(i) / SIDES)], [b + d0 * r1, d0, Vector2(v0 + len * 2.0, float(i) / SIDES)],
			[b + d1 * r1, d1, Vector2(v0 + len * 2.0, float(i + 1) / SIDES)], [a + d1 * r, d1, Vector2(v0, float(i + 1) / SIDES)]]
		for k in [0, 2, 1, 0, 3, 2]:
			st.set_color(col)
			st.set_normal(quad[k][1])
			st.set_uv(quad[k][2])
			st.add_vertex(quad[k][0])
		# the cut ends, a shade paler
		for e in [[a, -z, r, d0, d1], [b, z, r1, d0, d1]]:
			var c: Vector3 = e[0]
			var n: Vector3 = e[1]
			var rr: float = e[2]
			var tri: Array = [c, c + (e[3] as Vector3) * rr, c + (e[4] as Vector3) * rr]
			if ((tri[1] as Vector3) - tri[0]).cross((tri[2] as Vector3) - tri[0]).dot(n) > 0.0:
				tri = [tri[0], tri[2], tri[1]]
			for p in tri:
				st.set_color(col.lightened(0.25))
				st.set_normal(n)
				st.set_uv(Vector2(p.x, p.z) * 4.0)
				st.add_vertex(p)
