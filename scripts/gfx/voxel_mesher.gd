extends RefCounted
## A dense voxel grid with simple drawing tools, and a greedy mesher that turns it into a
## vertex-coloured ArrayMesh (plus a second, unshaded surface for glowing voxels).

const FACE_SHADE := {Vector3i(0, 1, 0): 1.0, Vector3i(0, -1, 0): 0.62, Vector3i(1, 0, 0): 0.86,
	Vector3i(-1, 0, 0): 0.86, Vector3i(0, 0, 1): 0.94, Vector3i(0, 0, -1): 0.78}

static var _mat_solid: StandardMaterial3D
static var _mat_glow: StandardMaterial3D


class Grid:
	var sx: int
	var sy: int
	var sz: int
	var cells: PackedInt32Array
	var palette: Array = [Color(0, 0, 0, 0)]
	var glow := {}

	func _init(x: int, y: int, z: int) -> void:
		sx = x
		sy = y
		sz = z
		cells = PackedInt32Array()
		cells.resize(x * y * z)
		cells.fill(0)

	func add_color(c: Color, emissive := false) -> int:
		palette.append(c)
		var i := palette.size() - 1
		if emissive:
			glow[i] = true
		return i

	func inb(x: int, y: int, z: int) -> bool:
		return x >= 0 and y >= 0 and z >= 0 and x < sx and y < sy and z < sz

	func set_v(x: int, y: int, z: int, c: int) -> void:
		if inb(x, y, z):
			cells[x + sx * (y + sy * z)] = c

	func get_v(x: int, y: int, z: int) -> int:
		if not inb(x, y, z):
			return 0
		return cells[x + sx * (y + sy * z)]

	func box(x0: int, y0: int, z0: int, x1: int, y1: int, z1: int, c: int, only := -1) -> void:
		for z in range(maxi(0, mini(z0, z1)), mini(sz, maxi(z0, z1) + 1)):
			for y in range(maxi(0, mini(y0, y1)), mini(sy, maxi(y0, y1) + 1)):
				for x in range(maxi(0, mini(x0, x1)), mini(sx, maxi(x0, x1) + 1)):
					if only < 0 or get_v(x, y, z) == only:
						cells[x + sx * (y + sy * z)] = c

	func ellipsoid(c3: Vector3, r: Vector3, c: int, only := -1) -> void:
		r = Vector3(maxf(r.x, 0.5), maxf(r.y, 0.5), maxf(r.z, 0.5))
		for z in range(maxi(0, int(floor(c3.z - r.z))), mini(sz, int(ceil(c3.z + r.z)) + 1)):
			for y in range(maxi(0, int(floor(c3.y - r.y))), mini(sy, int(ceil(c3.y + r.y)) + 1)):
				for x in range(maxi(0, int(floor(c3.x - r.x))), mini(sx, int(ceil(c3.x + r.x)) + 1)):
					var d := Vector3((x + 0.5 - c3.x) / r.x, (y + 0.5 - c3.y) / r.y, (z + 0.5 - c3.z) / r.z)
					if d.length_squared() <= 1.0 and (only < 0 or get_v(x, y, z) == only):
						cells[x + sx * (y + sy * z)] = c

	## A tube from a to b, radius tapering from ra to rb.
	func capsule(a: Vector3, b: Vector3, ra: float, rb: float, c: int, only := -1) -> void:
		var n := int(ceil(a.distance_to(b) * 2.0)) + 1
		for i in n + 1:
			var t := float(i) / float(n)
			var p := a.lerp(b, t)
			var r := lerpf(ra, rb, t)
			ellipsoid(p, Vector3(r, r, r), c, only)

	func paint_if(c: int, only: int, pred: Callable) -> void:
		for z in sz:
			for y in sy:
				for x in sx:
					var i := x + sx * (y + sy * z)
					if cells[i] == only and pred.call(x, y, z):
						cells[i] = c

	func mirror_z() -> void:
		## Copies the half z < sz/2 onto the other half (for symmetric shapes).
		for z in sz / 2:
			for y in sy:
				for x in sx:
					var v := cells[x + sx * (y + sy * z)]
					if v != 0:
						cells[x + sx * (y + sy * (sz - 1 - z))] = v


static func materials() -> Array:
	if _mat_solid == null:
		_mat_solid = StandardMaterial3D.new()
		_mat_solid.vertex_color_use_as_albedo = true
		_mat_solid.vertex_color_is_srgb = true
		_mat_solid.roughness = 0.95
		_mat_solid.metallic_specular = 0.25
		_mat_glow = StandardMaterial3D.new()
		_mat_glow.vertex_color_use_as_albedo = true
		_mat_glow.vertex_color_is_srgb = true
		_mat_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return [_mat_solid, _mat_glow]


## Greedy-meshes the grid. `vsize` is the size of one voxel; the mesh is centred on X/Z
## with its bottom at y = 0 (unless `pivot` is given, in voxel units).
static func build(g: Grid, vsize: float, pivot = null) -> ArrayMesh:
	var piv: Vector3 = pivot if pivot != null else Vector3(g.sx / 2.0, 0.0, g.sz / 2.0)
	var buckets := [[PackedVector3Array(), PackedVector3Array(), PackedColorArray()], [PackedVector3Array(), PackedVector3Array(), PackedColorArray()]]
	var dims := [g.sx, g.sy, g.sz]
	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		var du: int = dims[u]
		var dv: int = dims[v]
		for dir in [1, -1]:
			var nrm := Vector3i.ZERO
			nrm[axis] = dir
			var shade: float = FACE_SHADE[nrm]
			for d in dims[axis]:
				var mask := PackedInt32Array()
				mask.resize(du * dv)
				var any := false
				var p := Vector3i.ZERO
				p[axis] = d
				for j in dv:
					p[v] = j
					for i in du:
						p[u] = i
						var c := g.cells[p.x + g.sx * (p.y + g.sy * p.z)]
						if c == 0:
							mask[i + j * du] = 0
							continue
						var q := p
						q[axis] += dir
						if g.get_v(q.x, q.y, q.z) != 0:
							mask[i + j * du] = 0
						else:
							mask[i + j * du] = c
							any = true
				if not any:
					continue
				for j in dv:
					var i := 0
					while i < du:
						var c := mask[i + j * du]
						if c == 0:
							i += 1
							continue
						var w := 1
						while i + w < du and mask[i + w + j * du] == c:
							w += 1
						var h := 1
						var stop := false
						while j + h < dv and not stop:
							for k in w:
								if mask[i + k + (j + h) * du] != c:
									stop = true
									break
							if not stop:
								h += 1
						for jj in h:
							for ii in w:
								mask[i + ii + (j + jj) * du] = 0
						# quad corners in voxel space
						var base := Vector3.ZERO
						base[axis] = d + (1 if dir > 0 else 0)
						base[u] = i
						base[v] = j
						var eu := Vector3.ZERO
						eu[u] = w
						var ev := Vector3.ZERO
						ev[v] = h
						var a := (base - piv) * vsize
						var b := (base + eu - piv) * vsize
						var cc := (base + eu + ev - piv) * vsize
						var dd := (base + ev - piv) * vsize
						var col: Color = g.palette[c]
						var glow: bool = g.glow.has(c)
						if not glow:
							col = Color(col.r * shade, col.g * shade, col.b * shade, col.a)
						var bucket: Array = buckets[1 if glow else 0]
						var n3 := Vector3(nrm)
						# Godot's front faces wind clockwise
						var cr := (b - a).cross(cc - a)
						var tri: Array
						if cr.dot(n3) < 0.0:
							tri = [a, b, cc, a, cc, dd]
						else:
							tri = [a, cc, b, a, dd, cc]
						for vtx in tri:
							bucket[0].append(vtx)
							bucket[1].append(n3)
							bucket[2].append(col)
						i += w
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
