extends SceneTree
## Bake the supplied fences through the shared material and scenery LOD pipeline.
## Run prepare_fences.py first, then this script, smooth_textures.gd and --import.
const Bake = preload("res://tools/psx_bake.gd")
const SOURCE := "res://build/fences_source/"


func _init() -> void:
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	for name in ["fence", "stone_fence"]:
		if only != "" and only != name:
			continue
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE + name + ".json"))
		var mat := StandardMaterial3D.new()
		if name == "fence":
			# Reuse the huts' already-smoothed timber, with grain fitted per board by prepare_fences.py.
			mat.albedo_texture = load("res://assets/exteriors/tribal_hut_wood.res")
		else:
			var img := Image.load_from_file(d["texture"])
			img.resize(512, 512, Image.INTERPOLATE_LANCZOS)
			mat.albedo_texture = ImageTexture.create_from_image(img)
		mat.roughness = 0.95
		# Thin pickets and rails otherwise collect dark, jagged tree-shadow patches.
		# Keep the painted texture and directional lighting, without receiving shadow maps.
		mat.disable_receive_shadows = true
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(0, d["v"].size(), 3):
			for j in [0, 2, 1]:
				var p: Array = d["v"][i + j]
				var uv: Array = d["uv"][i + j]
				var n: Array = d["n"][i + j]
				st.set_uv(Vector2(uv[0], uv[1]))
				st.set_normal(Vector3(n[0], n[1], n[2]).normalized())
				st.add_vertex(Vector3(p[0], p[1], p[2]))
		st.set_material(mat)
		st.index()
		_save(Bake.with_lods(st.commit()), name)
	if only == "" or only == "iron_fence":
		_iron_fence()
	quit()


func _save(mesh: ArrayMesh, name: String) -> void:
	var err := ResourceSaver.save(mesh, "res://assets/props/" + name + ".res", ResourceSaver.FLAG_COMPRESS)
	assert(err == OK, "Could not save " + name)
	print("FENCE BAKED: ", name, " ", mesh.get_aabb())


# ---------------------------------------------------------------- iron fence
## The iron fence: a low plinth (the stone fence's upper half set on the ground, its stone a warm grey) under a stout
## railing, stone piers carrying thick posts with ball finials. Two meshes share one material and texture atlas (the
## stone on the left half, painted iron on the right): `iron_fence_base`, a cut section joined at corners like the
## stone fence, and `iron_fence`, the posted railing. Both stand with their foot at y = 0, sunk below the ground in the
## world (fence_models.gd SINK), so the plinth stays seated where a run crosses from paving onto the raised grass.
const PLINTH_DEPTH := 0.65  # the stone fence is 0.35 deep: thinned to a plinth
const PLINTH_CUT := 0.25  # the stone fence's height kept above this
const PIER := 0.13
const PIER_CAP := 0.15
const PIER_TOP := 0.482  # level with the plinth's top, under the bottom rail (fence_models.gd POSTED "below")
## The stone fence's texture on its long faces: turned a quarter (height runs along -u, length along v) at this many
## texture widths per unit; the piers' sides take the same cobbles at the same size.
const STONE_DENSITY := 0.316
const POST := 0.045


func _iron_fence() -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE + "stone_fence.json"))
	var stone := Image.load_from_file(d["texture"])
	stone.convert(Image.FORMAT_RGBA8)
	stone.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	var atlas := Image.create(1024, 512, false, Image.FORMAT_RGBA8)
	for y in 512:
		for x in 512:
			var c := stone.get_pixel(x, y)
			# warm grey: the stone's light and shade kept, its rosy colour all but taken out, a slight brown left in
			var l := c.r * 0.3 + c.g * 0.55 + c.b * 0.15
			var grey := Color(l * 1.04, l * 0.99, l * 0.92)
			atlas.set_pixel(x, y, grey.lerp(c, 0.12).lightened(0.04))
			atlas.set_pixel(512 + x, y, _iron_paint(x / 511.0, y / 511.0))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(atlas)
	mat.roughness = 0.9
	# Thin bars otherwise collect dark, jagged tree-shadow patches.
	mat.disable_receive_shadows = true
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# the plinth: the stone fence's top half, its foot at y = 0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, d["v"].size(), 3):
		var tri := []
		for j in [0, 2, 1]:
			tri.append([_v3(d["v"][i + j]), _v3(d["n"][i + j]), Vector2(d["uv"][i + j][0], d["uv"][i + j][1])])
		for poly in _above(tri, PLINTH_CUT):
			for k in range(1, poly.size() - 1):
				for v: Array in [poly[0], poly[k], poly[k + 1]]:
					var n: Vector3 = v[1]
					st.set_normal(Vector3(n.x, n.y, n.z / PLINTH_DEPTH).normalized())
					st.set_uv(Vector2(v[2].x * 0.5, v[2].y))
					var q: Vector3 = v[0]
					st.add_vertex(Vector3(q.x, q.y - PLINTH_CUT, q.z * PLINTH_DEPTH))
	st.set_material(mat)
	st.index()
	_save(Bake.with_lods(st.commit()), "iron_fence_base")
	# the railing, post to post (posts at x = ±0.5)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var plinth_top := 0.72 - PLINTH_CUT
	var cobble := Rect2(0.44, 0.08, 0.18, 0.15)
	var slab := Rect2(0.52, 0.6, 0.17, 0.2)
	for x in [-0.5, 0.5]:
		_box(st, Vector3(x, (PIER_TOP - 0.04) * 0.5, 0), Vector3(PIER, (PIER_TOP - 0.04) * 0.5, PIER), cobble, true)
		_box(st, Vector3(x, PIER_TOP - 0.025, 0), Vector3(PIER_CAP, 0.025, PIER_CAP), slab)
		_box(st, Vector3(x, (PIER_TOP + 0.9) * 0.5, 0), Vector3(POST, (0.9 - PIER_TOP) * 0.5, POST), Rect2())
		_box(st, Vector3(x, 0.915, 0), Vector3(0.06, 0.015, 0.06), Rect2())
		_ball(st, Vector3(x, 0.975, 0), 0.05)
	# the bottom rail rests on the piers' caps; the bars run on down to the plinth
	_box(st, Vector3(0, PIER_TOP + 0.025, 0), Vector3(0.5, 0.025, 0.025), Rect2())
	_box(st, Vector3(0, 0.805, 0), Vector3(0.5, 0.025, 0.025), Rect2())
	for k in range(1, 8):
		var x := -0.5 + k * 0.125
		_box(st, Vector3(x, (plinth_top + 0.87) * 0.5, 0), Vector3(0.017, (0.87 - plinth_top) * 0.5, 0.017), Rect2())
		_ball(st, Vector3(x, 0.875, 0), 0.027)
	st.set_material(mat)
	st.index()
	_save(Bake.with_lods(st.commit()), "iron_fence")


## Painted iron: a soft charcoal with a little warmth, lighter towards the top and along a gentle sheen down the middle.
func _iron_paint(u: float, v: float) -> Color:
	var base := Color(0.27, 0.25, 0.235).lerp(Color(0.14, 0.13, 0.125), v)
	return base.lightened(0.10 * exp(-pow((u - 0.5) / 0.18, 2.0)))


func _v3(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


## The part of triangle `tri` ([position, normal, uv] corners) at or above y = c, as a polygon.
func _above(tri: Array, c: float) -> Array:
	var res := []
	for i in 3:
		var a: Array = tri[i]
		var b: Array = tri[(i + 1) % 3]
		var da: float = a[0].y - c
		var db: float = b[0].y - c
		if da >= 0.0:
			res.append(a)
		if (da > 0.0 and db < 0.0) or (da < 0.0 and db > 0.0):
			var f := da / (da - db)
			res.append([(a[0] as Vector3).lerp(b[0], f), (a[1] as Vector3).lerp(b[1], f).normalized(),
				(a[2] as Vector2).lerp(b[2], f)])
	return [res] if res.size() >= 3 else []


## UV in the atlas: a stone region (left half), or the iron paint (right half) when `region` is empty, shaded by height
## and by which way the face turns.
func _uv(region: Rect2, p: Vector3, n: Vector3, a: float, b: float) -> Vector2:
	if region.size == Vector2.ZERO:
		var turn := 0.5 + 0.35 * clampf(n.x * 0.6 + n.y * 0.5 - n.z * 0.4, -1.0, 1.0)
		return Vector2(0.5 + 0.5 * (0.1 + 0.8 * turn), clampf(0.05 + 0.9 * (1.0 - p.y), 0.05, 0.95))
	return Vector2((region.position.x + region.size.x * a) * 0.5, region.position.y + region.size.y * b)


## A triangle wound clockwise as seen from the side its normals face (Godot's front faces).
func _tri(st: SurfaceTool, ps: Array, ns: Array, uvs: Array) -> void:
	var order := [0, 1, 2]
	if ((ps[1] - ps[0]) as Vector3).cross(ps[2] - ps[0]).dot(ns[0] + ns[1] + ns[2]) > 0.0:
		order = [0, 2, 1]
	for i in order:
		st.set_normal(ns[i])
		st.set_uv(uvs[i])
		st.add_vertex(ps[i])


func _box(st: SurfaceTool, c: Vector3, h: Vector3, region: Rect2, walled := false) -> void:
	for axis in 3:
		for s in [-1.0, 1.0]:
			var n := Vector3.ZERO
			n[axis] = s
			var u := (axis + 1) % 3
			var w := (axis + 2) % 3
			var corners := []
			var uvs := []
			for q in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
				var p := c + n * h[axis]
				p[u] += q[0] * h[u]
				p[w] += q[1] * h[w]
				corners.append(p)
				if walled and axis != 1:
					# a side laid like the plinth's wall: each face from its own stretch of the cobbles
					var along: float = (p.z - c.z if axis == 0 else p.x - c.x) + PIER
					var turn := 0.02 * (axis * 2 + int(s > 0.0))
					uvs.append(Vector2((region.end.x - STONE_DENSITY * p.y) * 0.5,
						region.position.y + turn + STONE_DENSITY * along))
				else:
					uvs.append(_uv(region if not walled else Rect2(0.52, 0.6, 0.17, 0.2), p, n, (q[0] + 1) * 0.5, (q[1] + 1) * 0.5))
			_tri(st, [corners[0], corners[1], corners[2]], [n, n, n], [uvs[0], uvs[1], uvs[2]])
			_tri(st, [corners[0], corners[2], corners[3]], [n, n, n], [uvs[0], uvs[2], uvs[3]])


func _ball(st: SurfaceTool, c: Vector3, r: float) -> void:
	var rings := 5
	var segs := 8
	var pts := []
	for i in rings + 1:
		var row := []
		var lat := PI * i / rings
		for j in segs:
			var lon := TAU * j / segs
			row.append(Vector3(sin(lat) * cos(lon), cos(lat), sin(lat) * sin(lon)))
		pts.append(row)
	for i in rings:
		for j in segs:
			var k := (j + 1) % segs
			var quad := [pts[i][j], pts[i][k], pts[i + 1][k], pts[i + 1][j]]
			var ps := []
			var uvs := []
			for n: Vector3 in quad:
				ps.append(c + n * r)
				uvs.append(_uv(Rect2(), c + n * r, n, 0, 0))
			if i > 0:
				_tri(st, [ps[0], ps[1], ps[2]], [quad[0], quad[1], quad[2]], [uvs[0], uvs[1], uvs[2]])
			if i < rings - 1:
				_tri(st, [ps[0], ps[2], ps[3]], [quad[0], quad[2], quad[3]], [uvs[0], uvs[2], uvs[3]])
