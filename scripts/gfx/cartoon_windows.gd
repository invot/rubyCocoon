extends RefCounted
## Exterior window dressing inspired by the supplied cartoon window packs. Geometry is cached with each house or
## wall piece: broad bevelled surrounds, a projecting cap and sill, thick mullions and painted blue glass.
## No textures, transparency, per-frame work or additional shadow casters are needed.

class Shape:
	static var _materials := {}
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var xf := Transform3D.IDENTITY

	func face(points: Array, normal: Vector3, colour: Color) -> void:
		for i in range(1, points.size() - 1):
			var order := [0, i, i + 1]
			if (points[i] - points[0]).cross(points[i + 1] - points[0]).dot(normal) > 0.0:
				order = [0, i + 1, i]
			for j in order:
				vertices.append(xf * points[j])
				normals.append((xf.basis * normal).normalized())
				colours.append(colour)

	## An extruded, bevelled rectangle. Its softened edges catch light without high-poly rounded mouldings.
	func block(c: Vector3, size: Vector3, colour: Color, bevel: float) -> void:
		var half := size * 0.5
		var b := minf(bevel, minf(half.x, half.y) * 0.45)
		var back := []
		var front := []
		for p in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
			back.append(c + Vector3(p.x, p.y, -half.z))
			front.append(c + Vector3(p.x - signf(p.x) * b, p.y - signf(p.y) * b, half.z))
		face(front, Vector3.BACK, colour)
		face(back, Vector3.FORWARD, colour.darkened(0.15))
		for i in 4:
			var j := (i + 1) % 4
			var n: Vector3 = (front[j] - back[i]).cross(back[j] - back[i]).normalized()
			var middle: Vector3 = (back[i] + back[j] + front[i] + front[j]) / 4.0 - c
			if n.dot(middle) < 0.0:
				n = -n
			face([back[i], back[j], front[j], front[i]], n, colour.darkened(0.08))

	func crown(w: float, y: float, rise: float, colour: Color) -> void:
		var front := []
		var back := []
		for i in 7:
			var x := w * (float(i) / 6.0 - 0.5)
			var p := Vector3(x, y + sin(PI * float(i) / 6.0) * rise, 0.18)
			front.append(p)
			back.append(Vector3(p.x, p.y, 0.02))
		face(front, Vector3.BACK, colour)
		for i in 6:
			var n: Vector3 = Vector3(front[i].y - front[i + 1].y, front[i + 1].x - front[i].x, 0).normalized()
			face([back[i], front[i], front[i + 1], back[i + 1]], n, colour.lightened(0.08))

	func slab(outline: Array, z0: float, z1: float, colour: Color) -> void:
		var front := []
		var back := []
		for p in outline:
			front.append(Vector3(p.x, p.y, z1))
			back.append(Vector3(p.x, p.y, z0))
		face(front, Vector3.BACK, colour)
		for i in outline.size():
			var j := (i + 1) % outline.size()
			var edge: Vector2 = outline[j] - outline[i]
			face([back[i], back[j], front[j], front[i]], Vector3(edge.y, -edge.x, 0).normalized(), colour.darkened(0.12))

	func surface(mesh: ArrayMesh, role: String) -> void:
		if vertices.is_empty():
			return
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = vertices
		arr[Mesh.ARRAY_NORMAL] = normals
		arr[Mesh.ARRAY_COLOR] = colours
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var si := mesh.get_surface_count() - 1
		mesh.surface_set_name(si, role)
		mesh.surface_set_material(si, material(role))

	func material(role: String) -> StandardMaterial3D:
		if not _materials.has(role):
			var mat := StandardMaterial3D.new()
			mat.resource_name = role
			mat.vertex_color_use_as_albedo = true
			mat.roughness = 0.88
			_materials[role] = mat
		return _materials[role]


## Find separate solid glass panes in a baked model. Shared positions join triangles even at split normals/UVs.
## The largest vertical face gives each opening's actual wall direction, including diagonal hut walls and dormers.
static func openings(mesh: Mesh, roles: Array, cove := false) -> Array:
	var result := []
	for si in mesh.get_surface_count():
		var mat := mesh.surface_get_material(si) as StandardMaterial3D
		if mat == null:
			continue
		var col := mat.albedo_color
		var is_glass := col.b > col.r + 0.08 and col.g > col.r + 0.07 and col.r < 0.6
		if not (is_glass if cove else String(mat.resource_name) in roles):
			continue
		var arr := mesh.surface_get_arrays(si)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ids = arr[Mesh.ARRAY_INDEX]
		if ids == null or (ids as PackedInt32Array).is_empty():
			ids = PackedInt32Array(range(vs.size()))
		var groups := []
		var at := {}
		for ti in range(0, ids.size(), 3):
			var points := [vs[ids[ti]], vs[ids[ti + 1]], vs[ids[ti + 2]]]
			var touching := []
			for p in points:
				var key: Vector3 = p.snappedf(0.001)
				if at.has(key) and not touching.has(at[key]):
					touching.append(at[key])
			var group: int = groups.size() if touching.is_empty() else touching[0]
			if touching.is_empty():
				groups.append([])
			for other in touching.slice(1):
				for p in groups[other]:
					at[(p as Vector3).snappedf(0.001)] = group
				groups[group].append_array(groups[other])
				groups[other] = []
			groups[group].append_array(points)
			for p in points:
				at[(p as Vector3).snappedf(0.001)] = group
		for points in groups:
			if points.is_empty():
				continue
			var normal := Vector3.ZERO
			var largest := 0.0
			var centre := Vector3.ZERO
			for p in points:
				centre += p
			centre /= float(points.size())
			for ti in range(0, points.size(), 3):
				var n: Vector3 = (points[ti + 1] - points[ti]).cross(points[ti + 2] - points[ti])
				if absf(n.normalized().y) < 0.15 and n.length_squared() > largest:
					normal = n.normalized()
					largest = n.length_squared()
			if normal == Vector3.ZERO:
				continue
			if normal.dot(Vector3(centre.x, 0, centre.z)) < 0.0:
				normal = -normal
			var tangent := Vector3.UP.cross(normal).normalized()
			var lo := Vector3(INF, INF, INF)
			var hi := Vector3(-INF, -INF, -INF)
			for p in points:
				var local := Vector3(tangent.dot(p), p.y, normal.dot(p))
				lo = lo.min(local)
				hi = hi.max(local)
			var size := hi - lo
			if size.x < 0.15 or size.y < 0.15:
				continue
			result.append({"p": tangent * (lo.x + hi.x) * 0.5 + Vector3.UP * (lo.y + hi.y) * 0.5 + normal * hi.z,
				"n": normal, "w": size.x, "h": size.y})
	# Some modular pieces have separate front/back glass faces. Only dress the outer face of that opening.
	var unique := []
	for candidate in result:
		var duplicate := false
		for existing in unique:
			var delta: Vector3 = candidate["p"] - existing["p"]
			var n: Vector3 = existing["n"]
			if n.dot(candidate["n"]) > 0.999 and delta.cross(n).length() < 0.01 and absf(delta.dot(n)) < 0.08 \
					and absf(candidate["w"] - existing["w"]) < 0.01 and absf(candidate["h"] - existing["h"]) < 0.01:
				if delta.dot(n) > 0.0:
					existing["p"] = candidate["p"]
				duplicate = true
				break
		if not duplicate:
			unique.append(candidate)
	return unique


## Add all surrounds as two surfaces in the existing mesh, retaining its wall infill, anchors and fading behaviour.
static func dress(mesh: ArrayMesh, roles: Array, cove := false, trim := Color("#eee1bf"), stone := false) -> ArrayMesh:
	var windows := openings(mesh, roles, cove)
	if windows.is_empty():
		return mesh
	var out := ArrayMesh.new()
	for si in mesh.get_surface_count():
		var mat := mesh.surface_get_material(si) as StandardMaterial3D
		var role := String(mat.resource_name) if mat != null else ""
		# Remove the old panes and their proud trim; the new opaque backing seals the opening.
		var arr := mesh.surface_get_arrays(si)
		if role in roles or role == "trim" or (cove and mat != null and mat.albedo_texture == null):
			arr = _without_surrounds(arr, windows)
			if (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).is_empty():
				continue
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var index := out.get_surface_count() - 1
		out.surface_set_name(index, mesh.surface_get_name(si))
		out.surface_set_material(index, mat)
	for key in mesh.get_meta_list():
		out.set_meta(key, mesh.get_meta(key))
	var frame := Shape.new()
	var glass := Shape.new()
	for window in windows:
		# The old glass stood slightly proud of its wall; the replacement's solid back meets that wall.
		window["p"] -= window["n"] * (0.07 if cove else 0.025)
		if stone:
			_stone(frame, glass, window, trim)
		else:
			_draw(frame, glass, window, trim)
	frame.surface(out, "window_frame")
	glass.surface(out, "window_glass")
	return out


static func _without_surrounds(arr: Array, windows: Array) -> Array:
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ids = arr[Mesh.ARRAY_INDEX]
	if ids == null or (ids as PackedInt32Array).is_empty():
		ids = PackedInt32Array(range(vs.size()))
	var keep := PackedInt32Array()
	for ti in range(0, ids.size(), 3):
		var cut := false
		for window in windows:
			var n: Vector3 = window["n"]
			var t := Vector3.UP.cross(n).normalized()
			var near := true
			for j in 3:
				var delta: Vector3 = vs[ids[ti + j]] - window["p"]
				if absf(delta.dot(t)) > float(window["w"]) / 2.0 + 0.2 or absf(delta.y) > float(window["h"]) / 2.0 + 0.2 \
						or delta.dot(n) < -0.16 or delta.dot(n) > 0.4:
					near = false
					break
			if near:
				cut = true
				break
		if not cut:
			keep.append_array([ids[ti], ids[ti + 1], ids[ti + 2]])
	arr[Mesh.ARRAY_INDEX] = keep
	return arr


## The same design for the existing procedural building kit, batched into its coloured surface.
static func paint(kit, p: Vector3, n: Vector3, w: float, h: float, trim: Color, glass_colour: Color) -> void:
	var frame := Shape.new()
	var glass := Shape.new()
	_draw(frame, glass, {"p": p, "n": n, "w": w, "h": h, "glass": glass_colour}, trim)
	var arr: Array = kit._arrays("color")
	for shape in [frame, glass]:
		arr[0].append_array(shape.vertices)
		arr[1].append_array(shape.normals)
		arr[2].append_array(shape.colours)
		for i in shape.vertices.size():
			arr[3].append(Vector2.ZERO)


static func _draw(frame: Shape, glass: Shape, window: Dictionary, trim: Color) -> void:
	var n: Vector3 = window["n"]
	var xf := Transform3D(Basis(Vector3.UP.cross(n).normalized(), Vector3.UP, n), window["p"])
	frame.xf = xf
	glass.xf = xf
	var w := float(window["w"])
	var h := float(window["h"])
	var rail := clampf(minf(w, h) * 0.12, 0.065, 0.17)
	# The solid backing covers the old fine frame and reflection marks, rather than leaving them visible underneath.
	frame.block(Vector3(0, 0, 0.055), Vector3(w + rail * 2.0, h + rail * 2.0, 0.12), trim.darkened(0.32), 0.025)
	var blue: Color = window.get("glass", Color("#498caa"))
	for row in 2:
		var y0 := -h / 2.0 + h * row / 2.0
		var y1 := y0 + h / 2.0
		glass.face([Vector3(-w / 2.0, y0, 0.122), Vector3(w / 2.0, y0, 0.122), Vector3(w / 2.0, y1, 0.122), Vector3(-w / 2.0, y1, 0.122)], Vector3.BACK, blue.lightened(0.12 if row == 1 else 0.0))
	for side in [-1.0, 1.0]:
		frame.block(Vector3(side * (w + rail) / 2.0, 0, 0.125), Vector3(rail, h + rail * 1.5, 0.18), trim, rail * 0.22)
	frame.block(Vector3(0, h / 2.0 + rail * 0.55, 0.13), Vector3(w + rail * 3.2, rail * 1.3, 0.23), trim.lightened(0.08), rail * 0.28)
	if h > w * 1.15:
		frame.crown(w + rail * 2.7, h / 2.0 + rail, rail * 1.15, trim)
	frame.block(Vector3(0, -h / 2.0 - rail * 0.6, 0.15), Vector3(w + rail * 3.7, rail * 1.45, 0.32), trim, rail * 0.3)
	for side in [-1.0, 1.0]:
		frame.block(Vector3(side * w * 0.35, -h / 2.0 - rail * 1.5, 0.085), Vector3(rail * 0.9, rail * 0.9, 0.16), trim.darkened(0.08), rail * 0.18)
	frame.block(Vector3(0, 0, 0.15), Vector3(rail * 0.58, h, 0.065), trim, rail * 0.12)
	frame.block(Vector3(0, h * 0.02, 0.15), Vector3(w, rail * 0.62, 0.065), trim, rail * 0.12)
	# Broad graphic glints, clipped inside individual panes; no transparent or reflective material is required.
	for side in [-1.0, 1.0]:
		var x: float = side * w * 0.25
		var y := h * (0.25 if side < 0 else -0.25)
		var rw := w * 0.23
		var rh := minf(h * 0.18, w * 0.25)
		glass.face([Vector3(x - rw / 2.0, y - rh / 2.0, 0.125), Vector3(x - rw / 2.0 + rail * 0.45, y - rh / 2.0, 0.125), Vector3(x + rw / 2.0, y + rh / 2.0, 0.125), Vector3(x + rw / 2.0 - rail * 0.45, y + rh / 2.0, 0.125)], Vector3.BACK, Color("#a8d9df"))


## Masonry arenas use a real round arch: broad wedge stones, an oversized keystone and coursed stone jambs.
static func _stone(frame: Shape, glass: Shape, window: Dictionary, stone: Color) -> void:
	var n: Vector3 = window["n"]
	var xf := Transform3D(Basis(Vector3.UP.cross(n).normalized(), Vector3.UP, n), window["p"])
	frame.xf = xf
	glass.xf = xf
	var w := float(window["w"])
	var h := float(window["h"])
	var rail := clampf(minf(w, h) * 0.17, 0.085, 0.23)
	var radius := w / 2.0
	var spring := h / 2.0 - radius
	frame.block(Vector3(0, 0, 0.055), Vector3(w + rail * 2.0, h + rail * 2.0, 0.12), stone.darkened(0.25), 0.02)
	var pane := [Vector3(-radius, -h / 2.0, 0.122), Vector3(radius, -h / 2.0, 0.122)]
	for i in 13:
		var a := PI * float(i) / 12.0
		pane.append(Vector3(cos(a) * radius, spring + sin(a) * radius, 0.122))
	glass.face(pane, Vector3.BACK, Color("#386c86"))
	for i in 7:
		var a := PI * float(i) / 7.0 + 0.012
		var b := PI * float(i + 1) / 7.0 - 0.012
		var outer := radius + rail * (1.35 if i == 3 else 1.0)
		var c := Vector2(0, spring)
		frame.slab([c + Vector2(cos(a), sin(a)) * radius, c + Vector2(cos(a), sin(a)) * outer,
			c + Vector2(cos(b), sin(b)) * outer, c + Vector2(cos(b), sin(b)) * radius], 0.04, 0.24 if i == 3 else 0.2, stone.lightened(0.08 if i % 2 == 0 else 0.0))
	var stem := h - radius
	for side in [-1.0, 1.0]:
		for row in 3:
			frame.block(Vector3(side * (radius + rail / 2.0), -h / 2.0 + stem * (row + 0.5) / 3.0, 0.12), Vector3(rail, stem / 3.0 - 0.018, 0.2), stone.lightened(0.04 if row % 2 == 0 else 0.0), rail * 0.12)
	frame.block(Vector3(0, -h / 2.0 - rail * 0.5, 0.15), Vector3(w + rail * 3.0, rail * 1.15, 0.32), stone.lightened(0.05), rail * 0.2)
	frame.block(Vector3(0, 0, 0.15), Vector3(rail * 0.5, h, 0.075), stone, rail * 0.1)
	frame.block(Vector3(0, spring, 0.15), Vector3(w, rail * 0.5, 0.075), stone, rail * 0.1)
