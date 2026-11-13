extends RefCounted
## Closed, translucent yellow 3D arrows: a slim, flattened rectangular shaft ending in an elongated four-sided pyramid.
## Hard-edged (each face has its own normals); swept rings prevent gaps at bends. No camera-facing ribbons or alpha layers.
const YELLOW := Color("#ffcf24")
const OPACITY := 0.58
const STEPS := 36
## Half sizes: the wide face lies across the arc (facing up along the curve), the thin one in its plane.
const SHAFT_HALF_WIDTH := 0.09
const SHAFT_HALF_THICK := 0.028
const HEAD_HALF_WIDTH := 0.21
const HEAD_HALF_THICK := 0.085
const HEAD_LENGTH := 0.7


static func material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/battle/target_arrow.gdshader")
	mat.set_shader_parameter("yellow", Vector3(YELLOW.r, YELLOW.g, YELLOW.b))
	mat.set_shader_parameter("opacity", OPACITY)
	return mat


static func build(from: Vector3, targets: Array) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for target: Vector3 in targets:
		_append(vertices, normals, uvs, indices, from, target)
	var mesh := ArrayMesh.new()
	if vertices.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _point(a: Vector3, c: Vector3, b: Vector3, t: float) -> Vector3:
	return a * (1.0 - t) * (1.0 - t) + c * (2.0 * t * (1.0 - t)) + b * t * t


static func _triangle(vertices: PackedVector3Array, indices: PackedInt32Array, a: int, b: int, c: int, outward: Vector3) -> void:
	# Godot front faces wind clockwise. Keep all faces outward, including the caps and arrow's shoulder.
	indices.append(a)
	if (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).dot(outward) < 0.0:
		indices.append(b)
		indices.append(c)
	else:
		indices.append(c)
		indices.append(b)


## The four corners of a rectangular section. Face k spans corners k and k + 1 and faces _face_normal(k).
static func _corners(at: Vector3, side: Vector3, up: Vector3, half_width: float, half_thick: float) -> Array[Vector3]:
	return [at + side * half_width + up * half_thick, at - side * half_width + up * half_thick,
		at - side * half_width - up * half_thick, at + side * half_width - up * half_thick]


static func _face_normal(k: int, side: Vector3, up: Vector3) -> Vector3:
	return [up, -side, -up, side][k]


## A flat polygon with its own vertices, so its edges stay sharp.
static func _face(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, points: Array[Vector3], normal: Vector3) -> void:
	var first := vertices.size()
	for point in points:
		vertices.append(point)
		normals.append(normal)
		uvs.append(Vector2(-1.0, 0.0)) # Caps, shoulder and head stay plain yellow.
	for i in range(1, points.size() - 1):
		_triangle(vertices, indices, first, first + i, first + i + 1, normal)


static func _append(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, from: Vector3, to: Vector3) -> void:
	if from.distance_squared_to(to) < 0.0001:
		return
	var distance := from.distance_to(to)
	var shaft_width := minf(SHAFT_HALF_WIDTH, distance * 0.12)
	var shaft_thick := shaft_width * SHAFT_HALF_THICK / SHAFT_HALF_WIDTH
	var head_width := minf(HEAD_HALF_WIDTH, distance * 0.3)
	var head_thick := head_width * HEAD_HALF_THICK / HEAD_HALF_WIDTH
	var head_length := minf(HEAD_LENGTH, distance * 0.4)
	var bend_axis := Vector3.RIGHT if absf((to - from).normalized().dot(Vector3.UP)) > 0.85 else Vector3.UP
	var rise := distance * 0.35 if distance < 1.0 else 1.2 + distance * 0.2
	var control := (from + to) * 0.5 + bend_axis * rise
	var side := (to - from).cross(control - from).normalized()
	# Find the arrowhead's base on the same curve, with a consistent world-space head length.
	var end_t := 0.98
	while end_t > 0.3 and _point(from, control, to, end_t).distance_to(to) < head_length:
		end_t -= 0.005
	var base := _point(from, control, to, end_t)
	var head_direction := (to - base).normalized()
	var head_up := side.cross(head_direction).normalized()
	# The shaft: rectangular rings swept along the curve. Each face has its own pair of vertices per ring,
	# shaded smoothly along the bend and sharply across the corners.
	var start := vertices.size()
	var first_ring: Array[Vector3] = []
	var last_ring: Array[Vector3] = []
	var travelled := 0.0
	var previous := from
	for step in STEPS + 1:
		var t := end_t * float(step) / STEPS
		var at := _point(from, control, to, t)
		travelled += at.distance_to(previous)
		previous = at
		var tangent := ((control - from) * (1.0 - t) + (to - control) * t).normalized()
		if step == STEPS:
			tangent = head_direction
		var up := side.cross(tangent).normalized()
		var ring := _corners(at, side, up, shaft_width, shaft_thick)
		if step == 0:
			first_ring = ring
		last_ring = ring
		for k in 4:
			var normal := _face_normal(k, side, up)
			vertices.append(ring[k])
			normals.append(normal)
			uvs.append(Vector2(0.0, travelled))
			vertices.append(ring[(k + 1) % 4])
			normals.append(normal)
			uvs.append(Vector2(1.0, travelled))
	for step in STEPS:
		for k in 4:
			var a := start + step * 8 + k * 2
			var b := a + 1
			var c := b + 8
			var d := a + 8
			_triangle(vertices, indices, a, b, c, normals[a])
			_triangle(vertices, indices, a, c, d, normals[a])
	_face(vertices, normals, uvs, indices, first_ring, -(control - from).normalized())
	# A flat shoulder steps out from the shaft's end to the pyramid's wider rectangular base.
	var outer := _corners(base, side, head_up, head_width, head_thick)
	for k in 4:
		var next := (k + 1) % 4
		_face(vertices, normals, uvs, indices, [last_ring[k], last_ring[next], outer[next], outer[k]], -head_direction)
		var slope := (outer[next] - outer[k]).cross(to - outer[k]).normalized()
		if slope.dot(_face_normal(k, side, head_up)) < 0.0:
			slope = -slope
		_face(vertices, normals, uvs, indices, [outer[k], outer[next], to], slope)
