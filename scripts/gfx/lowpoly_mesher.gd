extends RefCounted
## A drop-in for voxel_mesher.gd's Grid that builds low-poly models instead of voxels.
##
## The beast, prop and people builders "draw" with boxes, ellipsoids and tubes in a voxel grid. This Grid keeps those
## drawing calls as shapes instead of filling cells, then build() turns every shape into a few polygons: boxes stay
## boxes, ellipsoids become faceted spheres and tubes become tapered cylinders with rounded ends (smooth shaded, like
## a PS1 or N64 model). What the voxels did with overlaps happens on the polygons:
##   - a face buried inside another solid shape is dropped;
##   - a later shape repaints the faces of earlier ones it covers (in voxels it overwrote those cells), and a shape
##     drawn with `only` just repaints, it adds nothing (spots, bellies, masks);
##   - paint_if() decides per face, from the voxel under the face's centre (stripes and speckles come out coarser).
## Coordinates, colours, glow and the pivot convention are the same as voxel_mesher.gd.

static var _mat_solid: StandardMaterial3D
static var _mat_glow: StandardMaterial3D

const BOX := 0
const ELL := 1
const CAP := 2


class Shape:
	var kind := BOX
	var a := Vector3.ZERO      # box min / ellipsoid centre / tube start
	var b := Vector3.ZERO      # box max / ellipsoid radii / tube end
	var ra := 0.0
	var rb := 0.0
	var c := 0
	var only := -1
	var order := 0
	var lo := Vector3.ZERO     # bounding box, for quick rejects
	var hi := Vector3.ZERO

	func bounds() -> void:
		match kind:
			BOX:
				lo = a
				hi = b
			ELL:
				lo = a - b
				hi = a + b
			CAP:
				var r := maxf(ra, rb)
				lo = Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z)) - Vector3.ONE * r
				hi = Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z)) + Vector3.ONE * r

	## Is p inside the shape, grown by `pad` voxels (negative shrinks it)?
	func has(p: Vector3, pad := 0.0) -> bool:
		if p.x < lo.x - pad or p.y < lo.y - pad or p.z < lo.z - pad or p.x > hi.x + pad or p.y > hi.y + pad or p.z > hi.z + pad:
			return false
		match kind:
			BOX:
				return true
			ELL:
				var d := (p - a) / Vector3(maxf(0.01, b.x + pad), maxf(0.01, b.y + pad), maxf(0.01, b.z + pad))
				return d.length_squared() <= 1.0
			_:
				var ab := b - a
				var t := clampf((p - a).dot(ab) / maxf(0.0001, ab.length_squared()), 0.0, 1.0)
				return p.distance_to(a + ab * t) <= lerpf(ra, rb, t) + pad
		return false


class Grid:
	var sx: int
	var sy: int
	var sz: int
	var palette: Array = [Color(0, 0, 0, 0)]
	var glow := {}
	var shapes: Array = []
	## [order, c, only, Callable]
	var painters: Array = []
	var _n := 0

	func _init(x: int, y: int, z: int) -> void:
		sx = x
		sy = y
		sz = z

	func add_color(col: Color, emissive := false) -> int:
		palette.append(col)
		var i := palette.size() - 1
		if emissive:
			glow[i] = true
		return i

	func inb(x: int, y: int, z: int) -> bool:
		return x >= 0 and y >= 0 and z >= 0 and x < sx and y < sy and z < sz

	func _add(s: Shape) -> void:
		s.order = _n
		_n += 1
		s.bounds()
		shapes.append(s)

	func set_v(x: int, y: int, z: int, col: int) -> void:
		if inb(x, y, z) and col != 0:
			box(x, y, z, x, y, z, col)

	## The colour at a voxel: the last solid shape covering its centre, repainted by later shapes (approximate).
	func get_v(x: int, y: int, z: int) -> int:
		var p := Vector3(x + 0.5, y + 0.5, z + 0.5)
		var col := 0
		for s in shapes:
			if s.c == 0 or not s.has(p):
				continue
			if s.only < 0 or s.only == col:
				col = s.c
		return col

	func box(x0: int, y0: int, z0: int, x1: int, y1: int, z1: int, col: int, only := -1) -> void:
		if col == 0:
			return
		var s := Shape.new()
		s.kind = BOX
		s.a = Vector3(mini(x0, x1), mini(y0, y1), mini(z0, z1))
		s.b = Vector3(maxi(x0, x1) + 1, maxi(y0, y1) + 1, maxi(z0, z1) + 1)
		s.c = col
		s.only = only
		_add(s)

	func ellipsoid(c3: Vector3, r: Vector3, col: int, only := -1) -> void:
		if col == 0:
			return
		var s := Shape.new()
		s.kind = ELL
		s.a = c3
		s.b = Vector3(maxf(r.x, 0.5), maxf(r.y, 0.5), maxf(r.z, 0.5))
		s.c = col
		s.only = only
		_add(s)

	## A tube from a to b, radius tapering from ra to rb.
	func capsule(a: Vector3, b: Vector3, ra: float, rb: float, col: int, only := -1) -> void:
		if col == 0:
			return
		var s := Shape.new()
		s.kind = CAP
		s.a = a
		s.b = b
		s.ra = maxf(ra, 0.5)
		s.rb = maxf(rb, 0.5)
		s.c = col
		s.only = only
		_add(s)

	func paint_if(col: int, only: int, pred: Callable) -> void:
		painters.append([_n, col, only, pred])
		_n += 1

	## Copies the half z < sz/2 onto the other half (for symmetric shapes).
	func mirror_z() -> void:
		var add := []
		for s in shapes:
			var cz: float = (s.lo.z + s.hi.z) / 2.0
			if cz >= sz / 2.0 - 0.25:
				continue
			var m := Shape.new()
			m.kind = s.kind
			m.c = s.c
			m.only = s.only
			match s.kind:
				BOX:
					m.a = Vector3(s.a.x, s.a.y, sz - s.b.z)
					m.b = Vector3(s.b.x, s.b.y, sz - s.a.z)
				ELL:
					m.a = Vector3(s.a.x, s.a.y, sz - s.a.z)
					m.b = s.b
				CAP:
					m.a = Vector3(s.a.x, s.a.y, sz - s.a.z)
					m.b = Vector3(s.b.x, s.b.y, sz - s.b.z)
					m.ra = s.ra
					m.rb = s.rb
			add.append(m)
		for m in add:
			_add(m)


static func materials() -> Array:
	if _mat_solid == null:
		_mat_solid = StandardMaterial3D.new()
		_mat_solid.vertex_color_use_as_albedo = true
		_mat_solid.vertex_color_is_srgb = true
		_mat_solid.roughness = 0.9
		_mat_solid.metallic_specular = 0.3
		_mat_glow = StandardMaterial3D.new()
		_mat_glow.vertex_color_use_as_albedo = true
		_mat_glow.vertex_color_is_srgb = true
		_mat_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return [_mat_solid, _mat_glow]


## Builds the model. `vsize` is the size of one voxel; the mesh is centred on X/Z with its bottom at y = 0 (unless
## `pivot` is given, in voxel units). `detail` scales how finely curves are cut.
static func build(g: Grid, vsize: float, pivot = null, detail := 1.0) -> ArrayMesh:
	var piv: Vector3 = pivot if pivot != null else Vector3(g.sx / 2.0, 0.0, g.sz / 2.0)
	# triangles: [p0, p1, p2, n0, n1, n2, colour index, shape order]
	var tris := []
	var solids := []
	for s in g.shapes:
		if s.only < 0:
			solids.append(s)
	for s in solids:
		var before := tris.size()
		match s.kind:
			BOX:
				_box_tris(s, tris)
			ELL:
				_ell_tris(s, tris, detail)
			CAP:
				_cap_tris(s, tris, detail)
		for i in range(before, tris.size()):
			tris[i][6] = s.c
			tris[i][7] = s.order
	# events in drawing order: later shapes and paints recolour what's already there
	var events := []
	for s in g.shapes:
		events.append([s.order, s])
	for p in g.painters:
		events.append([p[0], p])
	events.sort_custom(func(x, y): return x[0] < y[0])
	var keep := PackedByteArray()
	keep.resize(tris.size())
	keep.fill(1)
	var cents := PackedVector3Array()
	cents.resize(tris.size())
	for i in tris.size():
		var t: Array = tris[i]
		cents[i] = (t[0] + t[1] + t[2]) / 3.0
	for i in tris.size():
		# buried inside another solid shape: never seen
		var own: int = tris[i][7]
		for s in solids:
			if s.order != own and s.has(cents[i], -0.35):
				keep[i] = 0
				break
	for e in events:
		if e[1] is Shape:
			var s: Shape = e[1]
			for i in tris.size():
				if keep[i] == 0 or int(tris[i][7]) >= s.order:
					continue
				if (s.only < 0 or int(tris[i][6]) == s.only) and s.has(cents[i], 0.45):
					tris[i][6] = s.c
		else:
			var p: Array = e[1]
			for i in tris.size():
				if keep[i] == 0 or int(tris[i][7]) >= int(p[0]) or int(tris[i][6]) != int(p[2]):
					continue
				var q := cents[i]
				if (p[3] as Callable).call(int(floor(q.x)), int(floor(q.y)), int(floor(q.z))):
					tris[i][6] = p[1]
	var buckets := [[PackedVector3Array(), PackedVector3Array(), PackedColorArray()], [PackedVector3Array(), PackedVector3Array(), PackedColorArray()]]
	for i in tris.size():
		if keep[i] == 0:
			continue
		var t: Array = tris[i]
		var ci: int = t[6]
		var col: Color = g.palette[ci]
		var gl: bool = g.glow.has(ci)
		if not gl:
			# a faint per-face wobble in brightness, like hand-set vertex colours
			var j := 1.0 + (float(hash(i * 7919 + ci) % 1000) / 1000.0 - 0.5) * 0.05
			col = Color(minf(1.0, col.r * j), minf(1.0, col.g * j), minf(1.0, col.b * j), col.a)
		var bk: Array = buckets[1 if gl else 0]
		for k in 3:
			bk[0].append((t[k] - piv) * vsize)
			bk[1].append(t[3 + k])
			bk[2].append(col)
	var mesh := ArrayMesh.new()
	var mats := materials()
	for k in 2:
		var bk: Array = buckets[k]
		if bk[0].size() == 0:
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = bk[0]
		arrays[Mesh.ARRAY_NORMAL] = bk[1]
		arrays[Mesh.ARRAY_COLOR] = bk[2]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mats[k])
	return mesh


# ---------------------------------------------------------------- primitives (voxel space)
## Appends one triangle, wound so Godot draws its front (clockwise) on the side `face_n` points to.
static func _tri(out: Array, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, face_n: Vector3) -> void:
	if (b - a).cross(c - a).dot(face_n) > 0.0:
		out.append([a, c, b, na, nc, nb, 0, 0])
	else:
		out.append([a, b, c, na, nb, nc, 0, 0])


static func _box_tris(s: Shape, out: Array) -> void:
	var lo := s.a
	var hi := s.b
	var faces := [
		[Vector3(0, 1, 0), [Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]],
		[Vector3(0, -1, 0), [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z)]],
		[Vector3(0, 0, 1), [Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]],
		[Vector3(0, 0, -1), [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z)]],
		[Vector3(1, 0, 0), [Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, lo.y, hi.z)]],
		[Vector3(-1, 0, 0), [Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, hi.y, lo.z), Vector3(lo.x, hi.y, hi.z), Vector3(lo.x, lo.y, hi.z)]],
	]
	for f in faces:
		var n: Vector3 = f[0]
		var q: Array = f[1]
		_tri(out, q[0], q[1], q[2], n, n, n, n)
		_tri(out, q[0], q[2], q[3], n, n, n, n)


static func _ell_tris(s: Shape, out: Array, detail: float) -> void:
	var r := s.b
	var seg := clampi(int(round(maxf(r.x, r.z) * 1.4 * detail)) + 4, 6, 14)
	var rings := clampi(int(round(r.y * 1.0 * detail)) + 3, 4, 9)
	var pts := []
	var nrm := []
	for j in rings + 1:
		var v := PI * float(j) / rings
		var row := []
		var nrow := []
		for i in seg:
			var u := TAU * float(i) / seg
			var unit := Vector3(sin(v) * cos(u), cos(v), sin(v) * sin(u))
			row.append(s.a + unit * r)
			nrow.append((unit / r).normalized())
		pts.append(row)
		nrm.append(nrow)
	for j in rings:
		for i in seg:
			var i2 := (i + 1) % seg
			var a: Vector3 = pts[j][i]
			var b: Vector3 = pts[j][i2]
			var c: Vector3 = pts[j + 1][i2]
			var d: Vector3 = pts[j + 1][i]
			var fn := ((a + b + c + d) / 4.0 - s.a).normalized()
			if j != 0:
				_tri(out, a, b, c, nrm[j][i], nrm[j][i2], nrm[j + 1][i2], fn)
			if j != rings - 1:
				_tri(out, a, c, d, nrm[j][i], nrm[j + 1][i2], nrm[j + 1][i], fn)


static func _cap_tris(s: Shape, out: Array, detail: float) -> void:
	var axis := s.b - s.a
	var length := axis.length()
	var r := maxf(s.ra, s.rb)
	var seg := clampi(int(round(r * 1.6 * detail)) + 4, 6, 12)
	if length < 0.01:
		var e := Shape.new()
		e.kind = ELL
		e.a = s.a
		e.b = Vector3.ONE * r
		_ell_tris(e, out, detail)
		return
	var dir := axis / length
	var side := dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT).normalized()
	var up := side.cross(dir).normalized()
	var rings := [s.a, s.b]
	var radii := [s.ra, s.rb]
	for i in seg:
		var u0 := TAU * float(i) / seg
		var u1 := TAU * float(i + 1) / seg
		var o0 := side * cos(u0) + up * sin(u0)
		var o1 := side * cos(u1) + up * sin(u1)
		var a: Vector3 = rings[0] + o0 * radii[0]
		var b: Vector3 = rings[0] + o1 * radii[0]
		var c: Vector3 = rings[1] + o1 * radii[1]
		var d: Vector3 = rings[1] + o0 * radii[1]
		var fn := (o0 + o1).normalized()
		_tri(out, a, b, c, o0, o1, o1, fn)
		_tri(out, a, c, d, o0, o1, o0, fn)
	# rounded ends: low-poly half domes
	for end in 2:
		var e := Shape.new()
		e.kind = ELL
		e.a = rings[end]
		e.b = Vector3.ONE * float(radii[end])
		var before := out.size()
		_ell_tris(e, out, detail * 0.7)
		# keep only the half that faces away from the tube
		var keep := []
		var outward: Vector3 = -dir if end == 0 else dir
		for k in range(before, out.size()):
			var t: Array = out[k]
			if ((t[0] + t[1] + t[2]) / 3.0 - e.a).dot(outward) > -0.05:
				keep.append(t)
		out.resize(before)
		out.append_array(keep)
