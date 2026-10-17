extends RefCounted
## A small low-poly mesh builder for hand-shaped models (people): ellipsoids, tapered tubes, chamfered boxes and
## cones, vertex-coloured and smooth or flat shaded, plus surfaces that carry a painted texture (faces, shirt fronts).
## Godot's front faces wind clockwise; every primitive here winds its triangles to face outwards.

var _surf := {}
var _tex := {}
var _detail := {}

## World units one repeat of a fabric texture covers.
const CLOTH_TILE := 0.3


## Triangles added under `key` use `tex` (painted pixel art, sampled sharp) instead of vertex colours.
func textured(key: String, tex: Texture2D) -> void:
	_tex[key] = tex


## Triangles added under `key` keep their vertex colours with `tex` (a nearly white fabric weave) over them.
func cloth(key: String, tex: Texture2D) -> void:
	_detail[key] = tex


func _s(key: String) -> Array:
	if not _surf.has(key):
		_surf[key] = [PackedVector3Array(), PackedVector3Array(), PackedColorArray(), PackedVector2Array()]
	return _surf[key]


## One triangle facing `out` (wound to suit). n: three normals (smooth) or one (flat); uv optional.
func tri(key: String, a: Vector3, b: Vector3, c: Vector3, n: Array, col: Color, out: Vector3, uv: Array = []) -> void:
	var s := _s(key)
	var p := [a, b, c]
	var nn := n if n.size() == 3 else [n[0], n[0], n[0]]
	var uu := uv if uv.size() == 3 else [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	var order := [0, 1, 2] if (b - a).cross(c - a).dot(out) < 0.0 else [0, 2, 1]
	for i in order:
		s[0].append(p[i])
		s[1].append(nn[i])
		s[2].append(col)
		s[3].append(uu[i])


## An ellipsoid. `keep(center, normal) -> bool` can drop triangles (domes, shells with openings);
## `tex_key` + `tex_rect` (x, y, w, h in local units, front view) map the triangles facing +z onto a texture.
func ellipsoid(c: Vector3, r: Vector3, col: Color, segs := 10, rings := 7, keep := Callable(), tex_key := "", tex_rect := Rect2(), front := 0.45, key := "color") -> void:
	var pts := []
	var nrm := []
	for j in rings + 1:
		var v := PI * float(j) / rings
		var row := []
		var nrow := []
		for i in segs:
			var u := TAU * float(i) / segs + PI / segs
			var unit := Vector3(sin(v) * sin(u), cos(v), sin(v) * cos(u))
			row.append(c + unit * r)
			nrow.append((unit / r).normalized())
		pts.append(row)
		nrm.append(nrow)
	for j in rings:
		for i in segs:
			var i2 := (i + 1) % segs
			var quads := []
			if j != 0:
				quads.append([[j, i], [j, i2], [j + 1, i2]])
			if j != rings - 1:
				quads.append([[j, i], [j + 1, i2], [j + 1, i]])
			for t in quads:
				var a: Vector3 = pts[t[0][0]][t[0][1]]
				var b: Vector3 = pts[t[1][0]][t[1][1]]
				var d: Vector3 = pts[t[2][0]][t[2][1]]
				var mid := (a + b + d) / 3.0
				var fn := (mid - c).normalized()
				if keep.is_valid() and not keep.call(mid, fn):
					continue
				var ns := [nrm[t[0][0]][t[0][1]], nrm[t[1][0]][t[1][1]], nrm[t[2][0]][t[2][1]]]
				if tex_key != "" and fn.z > front:
					var uv := []
					for p in [a, b, d]:
						uv.append(Vector2((p.x - tex_rect.position.x) / tex_rect.size.x, 1.0 - (p.y - tex_rect.position.y) / tex_rect.size.y))
					tri(tex_key, a, b, d, ns, Color.WHITE, fn, uv)
				else:
					var angs := []
					for p in [a, b, d]:
						angs.append(atan2((p - c).x, (p - c).z))
					# keep a triangle on the back seam from wrapping round the whole texture
					if angs.max() - angs.min() > PI:
						for k in 3:
							if angs[k] < 0.0:
								angs[k] += TAU
					var uv := []
					var pts3 := [a, b, d]
					for k in 3:
						uv.append(Vector2(float(angs[k]) * maxf(r.x, r.z), -(pts3[k] - c).y) / CLOTH_TILE)
					tri(key, a, b, d, ns, col, fn, uv)


## A tube from a to b with an elliptic cross-section (radius rx across, rz front to back) tapering by `taper`
## (end radius = start * taper), `sides` sided, smooth shaded, with optional flat end caps.
func tube(a: Vector3, b: Vector3, rx: float, rz: float, col: Color, sides := 6, taper := 1.0, cap_a := true, cap_b := true, col_b = null, key := "color") -> void:
	var axis := (b - a).normalized()
	var side := Vector3.RIGHT if absf(axis.dot(Vector3.RIGHT)) < 0.9 else Vector3.BACK
	side = (side - axis * side.dot(axis)).normalized()
	var fwd := axis.cross(side).normalized()
	if fwd.dot(Vector3.BACK) < 0.0 and absf(axis.y) > 0.5:
		fwd = -fwd
	var ring_a := []
	var ring_b := []
	var nr := []
	for i in sides:
		var ang := TAU * float(i) / sides + PI / sides
		var o := side * cos(ang) * rx + fwd * sin(ang) * rz
		ring_a.append(a + o)
		ring_b.append(b + o * taper)
		nr.append((side * cos(ang) / rx + fwd * sin(ang) / rz).normalized())
	var cb: Color = col if col_b == null else col_b
	# fabric coordinates: round the tube by arc length, along it by distance (both in CLOTH_TILE repeats)
	var around := TAU * (rx + rz) / 2.0 / CLOTH_TILE
	var along := a.distance_to(b) / CLOTH_TILE
	var v0 := a.y / CLOTH_TILE
	for i in sides:
		var j := (i + 1) % sides
		var out: Vector3 = (nr[i] + nr[j]).normalized()
		var u0 := around * float(i) / sides
		var u1 := around * float(i + 1) / sides
		var uv := [Vector2(u0, -v0), Vector2(u1, -v0), Vector2(u1, -v0 - along), Vector2(u0, -v0 - along)]
		tri(key, ring_a[i], ring_a[j], ring_b[j], [nr[i], nr[j], nr[j]], col, out, [uv[0], uv[1], uv[2]])
		tri(key, ring_a[i], ring_b[j], ring_b[i], [nr[i], nr[j], nr[i]], cb, out, [uv[0], uv[2], uv[3]])
	if cap_a:
		for i in sides:
			tri(key, a, ring_a[i], ring_a[(i + 1) % sides], [-axis], col, -axis)
	if cap_b:
		for i in sides:
			tri(key, b, ring_b[i], ring_b[(i + 1) % sides], [axis], cb, axis)


## A box with its corners cut off at `bev` (flat shaded): eight-sided faces and a small triangle at each corner,
## chunky but not blocky.
func chamfer_box(c: Vector3, size: Vector3, bev: float, col: Color, key := "color") -> void:
	var h := size / 2.0
	bev = minf(bev, minf(h.x, minf(h.y, h.z)) * 0.9)
	# each corner becomes three points, one pulled in along each axis
	var corners := []
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var sg := Vector3(sx, sy, sz)
				var corner := c + sg * h
				var pts := []
				for ax in 3:
					var inset := Vector3.ZERO
					inset[ax] = sg[ax] * bev
					pts.append(corner - inset)
				corners.append([sg, pts])
	for e in corners:
		var n: Vector3 = (e[0] as Vector3).normalized()
		tri(key, e[1][0], e[1][1], e[1][2], [n], col, n, [_box_uv(e[1][0], n), _box_uv(e[1][1], n), _box_uv(e[1][2], n)])
	# each face is the octagon of the corner points lying in its plane (those not pulled in along its axis)
	for ax in 3:
		for s in [-1.0, 1.0]:
			var n := Vector3.ZERO
			n[ax] = s
			var a1 := (ax + 1) % 3
			var a2 := (ax + 2) % 3
			var ring := []
			for e in corners:
				if (e[0] as Vector3)[ax] != s:
					continue
				for k in 3:
					if k != ax:
						ring.append(e[1][k])
			var mid := c + n * h
			ring.sort_custom(func(p, q): return atan2((p - mid)[a2], (p - mid)[a1]) < atan2((q - mid)[a2], (q - mid)[a1]))
			for i in ring.size():
				var p2: Vector3 = ring[(i + 1) % ring.size()]
				tri(key, mid, ring[i], p2, [n], col, n, [_box_uv(mid, n), _box_uv(ring[i], n), _box_uv(p2, n)])


## Fabric coordinates on a flat face: the face's own plane, in CLOTH_TILE repeats.
static func _box_uv(p: Vector3, n: Vector3) -> Vector2:
	var ax := absf(n.x)
	var ay := absf(n.y)
	var az := absf(n.z)
	if ay >= ax and ay >= az:
		return Vector2(p.x, p.z) / CLOTH_TILE
	if ax >= az:
		return Vector2(p.z, -p.y) / CLOTH_TILE
	return Vector2(p.x, -p.y) / CLOTH_TILE


## A cone (or pyramid with few sides) from a base circle at `base` pointing to `tip`.
func cone(base: Vector3, tip: Vector3, r: float, col: Color, sides := 5) -> void:
	var axis := (tip - base).normalized()
	var side := Vector3.RIGHT if absf(axis.dot(Vector3.RIGHT)) < 0.9 else Vector3.BACK
	side = (side - axis * side.dot(axis)).normalized()
	var fwd := axis.cross(side)
	var ring := []
	for i in sides:
		var ang := TAU * float(i) / sides
		ring.append(base + (side * cos(ang) + fwd * sin(ang)) * r)
	for i in sides:
		var j := (i + 1) % sides
		var mid: Vector3 = (ring[i] + ring[j]) / 2.0
		var out := (mid - base).normalized() + axis * 0.3
		tri("color", ring[i], ring[j], tip, [out.normalized()], col, out)
		tri("color", base, ring[j], ring[i], [-axis], col, -axis)


func mesh(base_mat: Material) -> ArrayMesh:
	var m := ArrayMesh.new()
	for key in _surf:
		var s: Array = _surf[key]
		if s[0].size() == 0:
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = s[0]
		arrays[Mesh.ARRAY_NORMAL] = s[1]
		arrays[Mesh.ARRAY_COLOR] = s[2]
		arrays[Mesh.ARRAY_TEX_UV] = s[3]
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mat: Material = base_mat
		if _detail.has(key):
			var dm := StandardMaterial3D.new()
			dm.albedo_texture = _detail[key]
			dm.vertex_color_use_as_albedo = true
			dm.vertex_color_is_srgb = true
			dm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
			dm.roughness = 0.95
			dm.metallic_specular = 0.25
			mat = dm
		elif _tex.has(key):
			var tm := StandardMaterial3D.new()
			tm.albedo_texture = _tex[key]
			tm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
			tm.roughness = 0.9
			tm.metallic_specular = 0.3
			mat = tm
		m.surface_set_material(m.get_surface_count() - 1, mat)
	return m
