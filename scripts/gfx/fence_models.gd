extends RefCounted
## Shared supplied fence sections, joined at corners and junctions and batched by the world.
const VA = preload("res://scripts/gfx/voxel_assets.gd")
## Sections cut from a longer supplied fence (tools/prepare_fences.py): their cut ends are open, so every end left
## free is closed with a face of its own.
const CUT_SECTIONS := ["stone_fence", "fence"]
## Solid walls among them, joined at bends by clipping at full size (the picket fence keeps its half-length sections,
## which put a post at the corner).
const SOLID_JOINS := ["stone_fence"]
const EPS := 0.0001
static var _meshes := {}
static var _sources := {}


## Tile's fence: `mask` the neighbours its run carries on to (bits: left, right, up, down).
static func tile(style: String, mask: int) -> ArrayMesh:
	var key := "%s:%d" % [style, mask]
	if _meshes.has(key):
		return _meshes[key]
	var straight := mask in [0, 1, 2, 3, 4, 8, 12]
	_meshes[key] = _cut_tile(style, mask) if style in SOLID_JOINS or (style in CUT_SECTIONS and straight) else _scaled_tile(style, mask)
	return _meshes[key]


static func _scaled_tile(style: String, mask: int) -> ArrayMesh:
	var source: Mesh = VA.mesh(style)
	var arms := mask
	if arms in [0, 1, 2]:
		arms = 3
	elif arms in [4, 8]:
		arms = 12
	var directions := [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if arms in [3, 12]:
		st.append_from(source, 0, Transform3D(Basis(Vector3.UP, 0 if arms == 3 else PI / 2), Vector3.ZERO))
	else:
		# Half-length sections meet at the centre, so bends never leave diagonal gaps.
		for i in 4:
			if arms & (1 << i):
				var yaw: float = [PI, 0.0, PI / 2, -PI / 2][i]
				st.append_from(source, 0, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(0.5, 1, 0.5)), directions[i] * 0.25))
	st.set_material(source.surface_get_material(0))
	st.index()
	return st.commit()


## A cut section's tile at the run's own scale. Straight runs are the whole section (a lone end closed where it stops).
## At a bend or junction the east-west piece passes through, reaching just across the north-south arms, and those
## arms stop at its faces; every end that meets nothing is closed, so no fence is ever hollow from outside.
static func _cut_tile(style: String, mask: int) -> ArrayMesh:
	var src := _source(style)
	var left := mask & 1 != 0
	var right := mask & 2 != 0
	var up := mask & 4 != 0
	var down := mask & 8 != 0
	var zmin: float = src["zmin"]
	var zmax: float = src["zmax"]
	# [yaw, from, to (along the section's own x), close the near end, close the far end]
	var pieces := []
	if not (up or down):
		pieces.append([0.0, -0.5, 0.5, not left, not right])
	elif not (left or right):
		# turned a quarter: the section's +x runs north (up), its -x south (down)
		pieces.append([PI / 2, -0.5, 0.5, not down, not up])
	else:
		# the turned arms span the section's own z across x, so the through piece reaches exactly over them
		pieces.append([0.0, -0.5 if left else zmin, 0.5 if right else zmax, not left, not right])
		if up:
			pieces.append([PI / 2, -zmin, 0.5, true, false])
		if down:
			pieces.append([PI / 2, -0.5, -zmax, false, true])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for piece in pieces:
		var basis := Basis(Vector3.UP, piece[0])
		var cut := _clip(src["tris"], piece[1], piece[2])
		var tris: Array = cut["tris"]
		if piece[3]:
			tris += _cap(cut["lo"], -1.0, src)
		if piece[4]:
			tris += _cap(cut["hi"], 1.0, src)
		for t: Array in tris:
			for v: Array in t:
				st.set_normal(basis * (v[1] as Vector3))
				st.set_uv(v[2])
				if src["colors"]:
					st.set_color(v[3])
				st.add_vertex(basis * (v[0] as Vector3))
	st.set_material(src["material"])
	st.index()
	return st.commit()


## The section's triangles as [position, normal, uv, colour] corners, its cross-section's z extent, the way its
## texture runs along it (for the end faces) and which winding faces outward.
static func _source(style: String) -> Dictionary:
	if _sources.has(style):
		return _sources[style]
	var mesh: Mesh = VA.mesh(style)
	var a := mesh.surface_get_arrays(0)
	var pos: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var nrm = a[Mesh.ARRAY_NORMAL]
	var uvs = a[Mesh.ARRAY_TEX_UV]
	var cols = a[Mesh.ARRAY_COLOR]
	var idx = a[Mesh.ARRAY_INDEX]
	var order: Array = range(pos.size()) if idx == null else Array(idx)
	var tris := []
	var winding := 0.0
	var along := Vector2.ZERO
	var weight := 0.0
	for k in range(0, order.size() - 2, 3):
		var t := []
		for c in 3:
			var i: int = order[k + c]
			t.append([pos[i], nrm[i] if nrm != null else Vector3.UP, uvs[i] if uvs != null else Vector2.ZERO,
				cols[i] if cols != null else Color.WHITE])
		tris.append(t)
		var e1: Vector3 = t[1][0] - t[0][0]
		var e2: Vector3 = t[2][0] - t[0][0]
		var face := e1.cross(e2)
		winding += face.dot(t[0][1] + t[1][1] + t[2][1])
		# on the long sides, how far the texture moves per unit along the section
		if absf(face.normalized().z) > 0.7:
			var det := e1.x * e2.y - e1.y * e2.x
			if absf(det) > 0.0001:
				var du1: Vector2 = t[1][2] - t[0][2]
				var du2: Vector2 = t[2][2] - t[0][2]
				var gx := (du1 * e2.y - du2 * e1.y) / det
				along += Vector2(absf(gx.x), absf(gx.y)) * face.length()
				weight += face.length()
	var src := {"tris": tris, "colors": cols != null, "material": mesh.surface_get_material(0),
		"winding": signf(winding), "along": along / weight if weight > 0.0 else Vector2(0, 0.3)}
	# the cross-section's width, measured through the middle (past the supplied cut's zero-area strip connectors,
	# which reach out to stray points)
	var solid := tris.filter(func(t: Array) -> bool: return (t[1][0] - t[0][0]).cross(t[2][0] - t[0][0]).length() > 0.00001)
	var middle: Array = _clip(solid, -EPS * 10.0, EPS * 10.0)["hi"]
	src["zmin"] = INF
	src["zmax"] = -INF
	for seg: Array in middle:
		for v: Array in seg:
			src["zmin"] = minf(src["zmin"], v[0].z)
			src["zmax"] = maxf(src["zmax"], v[0].z)
	if not is_finite(src["zmin"]):
		src["zmin"] = -0.1
		src["zmax"] = 0.1
	_sources[style] = src
	return src


## The triangles' parts between x = lo and x = hi, with the edges left along each of those two planes.
static func _clip(tris: Array, lo: float, hi: float) -> Dictionary:
	var out := []
	var at_lo := []
	var at_hi := []
	for t: Array in tris:
		var poly := _keep(_keep(t, lo, 1.0), hi, -1.0)
		if poly.size() < 3:
			continue
		for i in range(1, poly.size() - 1):
			out.append([poly[0], poly[i], poly[i + 1]])
		for i in poly.size():
			var a: Array = poly[i]
			var b: Array = poly[(i + 1) % poly.size()]
			if absf(a[0].x - lo) < EPS and absf(b[0].x - lo) < EPS:
				at_lo.append([a, b])
			if absf(a[0].x - hi) < EPS and absf(b[0].x - hi) < EPS:
				at_hi.append([a, b])
	return {"tris": out, "lo": at_lo, "hi": at_hi}


## The part of polygon `poly` on side `s` of the plane x = c (s = 1 keeps x >= c), corners on the plane put on it.
static func _keep(poly: Array, c: float, s: float) -> Array:
	var res := []
	for i in poly.size():
		var a: Array = poly[i]
		var b: Array = poly[(i + 1) % poly.size()]
		var da: float = s * (a[0].x - c)
		var db: float = s * (b[0].x - c)
		if da >= -EPS:
			if absf(da) < EPS:
				a = a.duplicate()
				a[0] = Vector3(c, a[0].y, a[0].z)
			res.append(a)
		if (da > EPS and db < -EPS) or (da < -EPS and db > EPS):
			var f := da / (da - db)
			var p: Vector3 = (a[0] as Vector3).lerp(b[0], f)
			res.append([Vector3(c, p.y, p.z), (a[1] as Vector3).lerp(b[1], f).normalized(), (a[2] as Vector2).lerp(b[2], f),
				(a[3] as Color).lerp(b[3], f)])
	return res


## A face closing the section where it was cut (the edges `segs` left along the cut, facing `outward` along x): each
## outline the edges make is filled, its texture carried on across the end as it runs along the sides.
static func _cap(segs: Array, outward: float, src: Dictionary) -> Array:
	var points := {}
	var links := {}
	for seg: Array in segs:
		var ka := _key(seg[0][0])
		var kb := _key(seg[1][0])
		if ka == kb:
			continue
		points[ka] = seg[0]
		points[kb] = seg[1]
		for pair in [[ka, kb], [kb, ka]]:
			if not links.has(pair[0]):
				links[pair[0]] = []
			if not pair[1] in links[pair[0]]:
				links[pair[0]].append(pair[1])
	var out := []
	var used := {}
	for start in links:
		if used.has(start):
			continue
		var loop := [start]
		used[start] = true
		var here = start
		while true:
			var step = null
			for k in links[here]:
				if not used.has(k):
					step = k
					break
			if step == null:
				break
			loop.append(step)
			used[step] = true
			here = step
		if loop.size() < 3:
			continue
		var outline := PackedVector2Array()
		for k in loop:
			outline.append(Vector2(points[k][0].z, points[k][0].y))
		var fill := Geometry2D.triangulate_polygon(outline)
		if fill.is_empty():
			# an outline that crosses itself: close its hull instead
			var hull := Geometry2D.convex_hull(outline)
			outline = hull.slice(0, hull.size() - 1)
			loop = []
			for p in outline:
				loop.append(_nearest(points, p))
			fill = Geometry2D.triangulate_polygon(outline)
		var zlow := INF
		for p in outline:
			zlow = minf(zlow, p.x)
		for i in range(0, fill.size(), 3):
			var tri := []
			for c in 3:
				var v: Array = points[loop[fill[i + c]]]
				var uv: Vector2 = v[2] + src["along"] * (v[0].z - zlow)
				tri.append([v[0], Vector3(outward, 0, 0), uv, v[3]])
			var face: Vector3 = (tri[1][0] - tri[0][0]).cross(tri[2][0] - tri[0][0])
			if signf(face.x) * src["winding"] != outward:
				tri = [tri[0], tri[2], tri[1]]
			out.append(tri)
	return out


static func _key(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.z * 2000.0), roundi(p.y * 2000.0))


static func _nearest(points: Dictionary, p: Vector2) -> Vector2i:
	var best: Vector2i = points.keys()[0]
	var best_d := INF
	for k: Vector2i in points:
		var d: float = Vector2(points[k][0].z, points[k][0].y).distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = k
	return best
