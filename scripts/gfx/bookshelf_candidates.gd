extends RefCounted
## Approved bookcase mesh authoring source; tools/bake_bookshelf_candidates.gd --production.
const Rooms = preload("res://scripts/gfx/room_builder.gd")
const Decor = preload("res://scripts/gfx/home_decor.gd")
const THICK := 0.09
const BEVEL := 0.011
const OPTIONS := [
	["01-tall", "Tall classic", 0.96, 1.86, 0.46, 4],
	["02-low", "Low drawer console", 1.76, 1.02, 0.70, 1],
	["03-library", "Double library", 1.76, 1.86, 0.46, 4],
	["04-cubbies", "Staggered cubbies", 1.42, 1.42, 0.46, 3],
]
var surfaces: Array = []
var materials: Array[Material] = []
var material_slots := {}

func build(index: int, colour := Color("ad7954"), dressed := true) -> ArrayMesh:
	surfaces = [SurfaceTool.new(), SurfaceTool.new()]
	var atlas: Texture2D = load("res://assets/interiors/kaykit/furniture.png")
	materials = [Rooms._wood_tone(atlas, colour), Rooms._wood_tone(atlas, colour.darkened(0.12))]
	material_slots = {}
	for s in surfaces:
		s.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spec: Array = OPTIONS[index]
	var w: float = spec[2]
	var h: float = spec[3]
	var d: float = spec[4]
	var rows: int = spec[5]
	# User refinement: lighter boards, retaining the softened KayKit construction.
	var base := 0.5069 if index == 1 else 0.0
	var frame_h := h - base
	_box(Vector3(THICK, frame_h, d), Vector3((-w + THICK) / 2, base + frame_h / 2, 0), 0)
	_box(Vector3(THICK, frame_h, d), Vector3((w - THICK) / 2, base + frame_h / 2, 0), 0)
	var caps: Array = [THICK / 2, h - THICK / 2] if index != 1 else [h - THICK / 2]
	for y in caps:
		_box(Vector3(w - 2 * THICK, THICK, d), Vector3(0, y, 0), 0)
	_box(Vector3(w - 2 * THICK, frame_h - THICK, 0.045), Vector3(0, base + (frame_h - THICK) / 2, -d / 2 + 0.0225), 1)
	if index == 1:
		var drawers := _one_drawer_row(Rooms.piece("kk_drawers"))
		var drawer_scale := Vector3(w / drawers.get_aabb().size.x, 1, 1)
		_append(drawers, Transform3D(Basis.IDENTITY.scaled(drawer_scale), Vector3.ZERO), true, colour)
	var clear_h := (h - (rows + 1) * THICK) / rows if index != 1 else h - base - THICK
	for row in rows:
		var bottom := THICK + row * (clear_h + THICK) if index != 1 else base
		if row > 0:
			_box(Vector3(w - 2 * THICK, THICK, d - 0.015), Vector3(0, bottom - THICK / 2, 0), 0)
		var split := 0.0
		var divided := index == 2 or (index == 3 and row != 1)
		if index == 3:
			split = -0.18 if row == 0 else 0.18
		if divided:
			_box(Vector3(THICK, clear_h, d - 0.035), Vector3(split, bottom + clear_h / 2, -0.008), 0)
		if dressed:
			var spans: Array = [[-w / 2 + THICK, w / 2 - THICK]]
			if divided:
				spans = [[-w / 2 + THICK, split - THICK / 2], [split + THICK / 2, w / 2 - THICK]]
			for bay in spans.size():
				var span: Array = spans[bay]
				_dress(span[0], span[1], bottom, clear_h, d, index, row, bay)
	var result := ArrayMesh.new()
	for i in surfaces.size():
		surfaces[i].set_material(materials[i])
		surfaces[i].commit(result)
		result.surface_set_name(i, ["frame_and_shelves", "back"][i] if i < 2 else "contents_%d" % i)
	return result

## Remove KayKit's upper drawer face and its two knobs, then close that row's
## vertical interval in the surrounding carcass. Keep the lower face and handles.
func _one_drawer_row(source: Mesh) -> ArrayMesh:
	var result := ArrayMesh.new()
	for si in source.get_surface_count():
		var a := source.surface_get_arrays(si)
		var points: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var ids: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		if ids.is_empty():
			ids = PackedInt32Array(range(points.size()))
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for start in range(0, ids.size(), 3):
			var lo := points[ids[start]]
			var hi := lo
			for j in 3:
				lo = lo.min(points[ids[start + j]])
				hi = hi.max(points[ids[start + j]])
			if lo.y >= 0.3801 and hi.y <= 0.5137 and lo.z >= 0.2328:
				continue
			for j in 3:
				var k := ids[start + j]
				var p := points[k]
				if p.y >= 0.5135:
					p.y -= 0.1601
				st.set_normal(a[Mesh.ARRAY_NORMAL][k])
				st.set_uv(a[Mesh.ARRAY_TEX_UV][k])
				st.add_vertex(p)
		st.set_material(source.surface_get_material(si))
		st.commit(result)
	return result

func _dress(left: float, right: float, bottom: float, height: float, depth: float, design: int, row: int, bay: int) -> void:
	var width := right - left
	var centre := (left + right) / 2
	var variant := (design + row + bay) % 4
	if design == 1 or width > 0.9:
		_prop("kk_book_set", centre - width * 0.22, bottom, width * 0.48, height, depth)
		_prop("home/vase_round", centre + width * 0.15, bottom, width * 0.18, height * 0.85, depth)
		_prop("kk_cactus_small_A", centre + width * 0.36, bottom, width * 0.19, height * 0.9, depth)
	elif variant == 0:
		_prop("kk_book_set", centre, bottom, width * 0.83, height, depth)
	elif variant == 1:
		_prop("home/books_stack", centre - width * 0.24, bottom, width * 0.42, height, depth)
		_prop("kk_cactus_small_A", centre + width * 0.22, bottom, width * 0.42, height * 0.9, depth)
	elif variant == 2:
		_prop("home/vase_round", centre - width * 0.23, bottom, width * 0.34, height * 0.85, depth)
		_prop("home/photo_standing", centre + width * 0.2, bottom, width * 0.39, height * 0.9, depth)
	else:
		_prop("home/candles", centre - width * 0.2, bottom, width * 0.44, height, depth)
		_prop("home/books_stack", centre + width * 0.25, bottom, width * 0.38, height, depth)

func _prop(name: String, x: float, bottom: float, width: float, height: float, depth: float) -> void:
	var mesh := Rooms.piece(name)
	var bb := mesh.get_aabb()
	var fit := minf(1, minf(width / bb.size.x, minf((height - 0.025) / bb.size.y, (depth - 0.09) / bb.size.z)))
	var origin := Vector3(x - bb.get_center().x * fit, bottom - bb.position.y * fit, depth * 0.12 - bb.get_center().z * fit)
	var overrides: Array = []
	if name.begins_with("home/"):
		var instance := Decor.make(name.trim_prefix("home/"), "seafoam_cottage")
		for si in mesh.get_surface_count():
			overrides.append(instance.get_surface_override_material(si))
		instance.free()
	_append(mesh, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * fit), origin), false, Color.WHITE, overrides)

func _box(size: Vector3, origin: Vector3, surface: int) -> void:
	var half := size / 2
	var radius := minf(BEVEL, minf(size.x, minf(size.y, size.z)) / 3)
	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		for sign_axis in [-1.0, 1.0]:
			var us := [-half[u], -half[u] + radius, half[u] - radius, half[u]]
			var vs := [-half[v], -half[v] + radius, half[v] - radius, half[v]]
			for a in 3:
				for b in 3:
					var corners: Array = []
					for ij in [Vector2i(a, b), Vector2i(a + 1, b), Vector2i(a + 1, b + 1), Vector2i(a, b + 1)]:
						var q := Vector3.ZERO
						q[axis] = sign_axis * half[axis]
						q[u] = us[ij.x]
						q[v] = vs[ij.y]
						var inner := q.clamp(-half + Vector3.ONE * radius, half - Vector3.ONE * radius)
						var normal := (q - inner).normalized()
						corners.append([origin + inner + normal * radius, normal, Vector2(0.29 + (q[u] / size[u] + 0.5) * 0.055, 0.025 + (q[v] / size[v] + 0.5) * 0.19)])
					# Godot's front face is clockwise, viewed from outside.
					var order := [0, 2, 1, 0, 3, 2] if sign_axis > 0 else [0, 1, 2, 0, 2, 3]
					for k in order:
						surfaces[surface].set_normal(corners[k][1])
						surfaces[surface].set_uv(corners[k][2])
						surfaces[surface].add_vertex(corners[k][0])

func _append(mesh: Mesh, transform: Transform3D, recolour := false, colour := Color.WHITE, overrides: Array = []) -> void:
	for si in mesh.get_surface_count():
		var mat: Material = overrides[si] if si < overrides.size() else mesh.surface_get_material(si)
		if recolour and mat is BaseMaterial3D:
			mat = Rooms._wood_tone(mat.albedo_texture, colour)
		var key := mat.get_instance_id()
		if not material_slots.has(key):
			material_slots[key] = surfaces.size()
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			surfaces.append(tool)
			materials.append(mat)
		var slot: int = material_slots[key]
		var arrays := mesh.surface_get_arrays(si)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		for j in (indices.size() if not indices.is_empty() else vertices.size()):
			var k := indices[j] if not indices.is_empty() else j
			surfaces[slot].set_normal((transform.basis.inverse().transposed() * normals[k]).normalized())
			surfaces[slot].set_uv(uvs[k])
			surfaces[slot].set_color(colours[k] if not colours.is_empty() else Color.WHITE)
			surfaces[slot].add_vertex(transform * vertices[k])
