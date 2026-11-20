extends RefCounted
## Build a shallow eye surface on the measured socket. Its rim and upper lid share one contour.
## UV.x below -2 identifies the fitted surface. The original mesh keeps its coat and sculpted lids.
const SEGMENTS := 40
const RINGS := 4

static func attach(source: ArrayMesh, form: String, eyes: Array) -> ArrayMesh:
	if eyes.is_empty():
		return source
	var arrays := source.surface_get_arrays(0)
	var source_count: int = arrays[Mesh.ARRAY_VERTEX].size()
	for i in eyes.size():
		_add_eye(arrays, source_count, eyes[i], i, 1.0 if i % 2 == 0 else -1.0)
	_relax_brows(arrays, eyes, int(form.get_slice("_", 1)))
	var mesh := ArrayMesh.new()
	mesh.resource_name = form
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _add_eye(a: Array, source_count: int, e: Array, socket_index: int, side: float) -> void:
	var axis := Vector3(sqrt(1.0 - e[4] * e[4]), 0, side * e[4])
	var across := Vector3(-e[4], 0, side * axis.x)
	var origin := Vector3(0, e[1], e[7]) + across * float(e[0])
	var centre := Vector2(0, 0.5 * (minf(1, e[8]) - 1.0))
	var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var nearest := 0
	var best := INF
	var socket := origin + axis * float(e[10])
	for i in source_count:
		var distance := verts[i].distance_squared_to(socket)
		if distance < best:
			best = distance
			nearest = i
	var first := verts.size()
	var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS].slice(nearest * 4, nearest * 4 + 4)
	var bones: PackedInt32Array = a[Mesh.ARRAY_BONES].slice(nearest * 4, nearest * 4 + 4)
	
	# Each spoke ends at the first intersection with the elliptical rim or the upper lid.
	for ring in range(RINGS + 1):
		for j in (1 if ring == 0 else SEGMENTS):
			var ray := Vector2.from_angle(TAU * j / SEGMENTS)
			var projection := centre.dot(ray)
			var distance := -projection + sqrt(projection * projection + 1.0 - centre.length_squared())
			var toward_lid := ray.y - float(e[9]) * ray.x
			if toward_lid > 0.001:
				distance = minf(distance, (float(e[8]) - centre.y) / toward_lid)
			var p := centre + ray * distance * float(ring) / RINGS
			var depth: float = (e[10] + e[11] * p.x + e[12] * p.y
				+ e[13] * p.x * p.x + e[14] * p.x * p.y + e[15] * p.y * p.y)
			var point: Vector3 = origin + across * (p.x * e[2]) + Vector3.UP * (p.y * e[3]) + axis * depth
			a[Mesh.ARRAY_VERTEX].append(point)
			a[Mesh.ARRAY_NORMAL].append(axis)
			if a[Mesh.ARRAY_TANGENT] != null:
				a[Mesh.ARRAY_TANGENT].append_array(PackedFloat32Array([across.x, 0.0, across.z, side]))
			a[Mesh.ARRAY_COLOR].append(Color(12.0 / 15.0, 0, socket_index / 7.0, 0.5 + point.x * 0.5))
			a[Mesh.ARRAY_TEX_UV].append(Vector2(p.x - 4.0, p.y))
			a[Mesh.ARRAY_TEX_UV2].append(Vector2(point.z, point.y))
			a[Mesh.ARRAY_BONES].append_array(bones)
			a[Mesh.ARRAY_WEIGHTS].append_array(weights)
	var indices: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	for ring in RINGS:
		for j in SEGMENTS:
			var k := (j + 1) % SEGMENTS
			var start := first + 1 + ring * SEGMENTS
			var left := start + (j if side > 0 else k)
			var right := start + (k if side > 0 else j)
			if ring == 0:
				indices.append_array(PackedInt32Array([first, left, right]))
			else:
				indices.append_array(PackedInt32Array([left - SEGMENTS, left, right, left - SEGMENTS, right, right - SEGMENTS]))
	a[Mesh.ARRAY_INDEX] = indices

## Raise the inner brow of a younger form in bind space, including the skin and its new eye surface.
## This is done once when the form mesh is cached, before it is animated or used as a merge donor.
static func _relax_brows(arrays: Array, eyes: Array, stage: int) -> void:
	if stage >= 3:
		return
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var lift := PackedFloat32Array()
	lift.resize(verts.size())
	for i in eyes.size():
		var e: Array = eyes[i]
		var side := 1.0 if i % 2 == 0 else -1.0
		var cosine := sqrt(1.0 - e[4] * e[4])
		for j in verts.size():
			var v := verts[j]
			var lateral := (v.z - float(e[7])) * side
			var u := (cosine * lateral - float(e[4]) * v.x - float(e[0])) / float(e[2])
			var y := (v.y - float(e[1])) / float(e[3])
			var reach := 1.0 - smoothstep(1.1, 2.2, Vector2(u, y).length())
			if reach <= 0:
				continue
			var depth := cosine * v.x + float(e[4]) * lateral
			var front := smoothstep(e[5] - e[2], e[5], depth) * (1.0 - smoothstep(e[6], e[6] + e[2], depth))
			lift[j] += (3 - stage) * 0.5 * reach * front * float(e[3]) * clampf(0.20 - float(e[9]) * u, -0.55, 0.85)
	for j in verts.size():
		verts[j].y += lift[j]
	arrays[Mesh.ARRAY_VERTEX] = verts
