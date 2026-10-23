extends SceneTree
## Bakes the telephones from the phone packs in psx/phones/ (see CREDITS.md): the red rotary phone that stands in
## homes, Beast Centers, some shops, the arenas and some temple doorways (assets/interiors/phone_rotary.res), and
## the red payphone on a post by each town's square (assets/exteriors/payphone.res):
##   godot --headless --path . --script res://tools/import_psx_phones.gd
##
## Both come out low-poly and plain so they read at a glance, PS1-style: the cords left off, the meshes cut down to a
## few hundred triangles, and no textures: each vertex takes the colour of the pack's texture under it (sampled from a
## shrunk copy, so small print and scratches melt away), and every red is the same bright red, so a phone is easy to
## spot in any room.

const B = preload("res://tools/psx_bake.gd")
const SRC := "res://psx/phones/"
const RED := Color("#d8262a")
## game units per pack metre: the phones are drawn big enough to see beside the townsfolk
const ROTARY_SCALE := 1.35
const PAY_SCALE := 2.3


func _init() -> void:
	var root := ProjectSettings.globalize_path(SRC)
	_rotary(root + "antique_1930s_rotary_telephones.glb")
	_payphone(root + "source/telefone publico antigo.fbx", root + "textures/")
	quit()


## The red one of the pack's five rotary phones, its cord left off: the one piece reaching out past the base's left.
func _rotary(path: String) -> void:
	var sc := B.load_model(path)
	if sc == null:
		push_error("could not load " + path)
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for mi in sc.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		if not String(inst.get_parent().name).contains("Emergency Red"):
			continue
		var mat := inst.get_active_material(0) as BaseMaterial3D
		var img := _shrunk(mat.albedo_texture.get_image() if mat != null and mat.albedo_texture != null else null)
		var pieces := _pieces(inst.mesh, B.xf_to(inst, sc))
		var left := INF
		for p in pieces:
			left = minf(left, (p["box"] as AABB).position.x)
		for p in pieces:
			if (p["box"] as AABB).position.x <= left + 0.001:
				continue
			_add(st, p, img, func(c: Color) -> Color: return c)
	sc.free()
	_save(st, Transform3D(Basis().scaled(Vector3.ONE * ROTARY_SCALE), Vector3.ZERO), 700, "res://assets/interiors/phone_rotary.res")


## The pack's coin phone (its cord left off), its orange turned red, on a grey post under a little red hood.
func _payphone(path: String, tex: String) -> void:
	var sc := B.load_model(path)
	if sc == null:
		push_error("could not load " + path)
		return
	# the FBX doesn't find its textures: they go by material
	var imgs := {"Telephone": _shrunk(Image.load_from_file(tex + "telephone_base.png")),
		"Telephone 2": _shrunk(Image.load_from_file(tex + "telephone2_base.png"))}
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var box := AABB()
	var first := true
	for mi in sc.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		if String(inst.name) == "Fio":
			continue
		var mat := inst.get_active_material(0)
		var img: Image = imgs.get(mat.resource_name if mat != null else "", null)
		for p in _pieces(inst.mesh, B.xf_to(inst, sc)):
			_add(st, p, img, _redden)
			box = p["box"] if first else box.merge(p["box"])
			first = false
	sc.free()
	# its buttons face -z: turned round, scaled, and lifted onto the post
	var s := PAY_SCALE
	var lift := 0.85 - box.position.y * s
	var xf := Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * s), Vector3(0, lift, 0)) \
		* Transform3D(Basis(), -Vector3(box.get_center().x, 0, box.get_center().z))
	var top := lift + box.size.y * s
	var depth := box.size.z * s
	# the post behind the phone, its foot, and the hood over it
	_box(st, Vector3(0, top / 2.0 - 0.02, -depth / 2.0 - 0.06), Vector3(0.16, top + 0.04, 0.1), Color("#5a5c62"), xf.affine_inverse())
	_box(st, Vector3(0, top + 0.05, -0.02), Vector3(box.size.x * s + 0.16, 0.08, depth + 0.22), RED, xf.affine_inverse())
	_box(st, Vector3(0, 0.03, -depth / 2.0 - 0.06), Vector3(0.36, 0.06, 0.3), Color("#4a4c52"), xf.affine_inverse())
	_save(st, xf, 900, "res://assets/exteriors/payphone.res")


## A mesh's triangles in joined-up pieces (corners at the same spot join), each with its box, in the scene's space:
## [{tris: [[pos, normal, uv] x 3], box}].
func _pieces(mesh: Mesh, xf: Transform3D) -> Array:
	var out := []
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(v.size()))
		var weld := {}
		var up := []
		var corner := PackedInt32Array()
		for i in v.size():
			var k := Vector3i((xf * v[i] * 4000.0).round())
			if not weld.has(k):
				weld[k] = up.size()
				up.append(up.size())
			corner.append(weld[k])
		for t in idx.size() / 3:
			var a := _root(up, corner[idx[t * 3]])
			for k in range(1, 3):
				var b := _root(up, corner[idx[t * 3 + k]])
				if a != b:
					up[b] = a
		var groups := {}
		for t in idx.size() / 3:
			var r := _root(up, corner[idx[t * 3]])
			if not groups.has(r):
				groups[r] = {"tris": [], "box": AABB(xf * v[idx[t * 3]], Vector3.ZERO)}
			var tri := []
			for k in 3:
				var i := idx[t * 3 + k]
				var p := xf * v[i]
				groups[r]["box"] = (groups[r]["box"] as AABB).expand(p)
				tri.append([p, (xf.basis * n[i]).normalized() if i < n.size() else Vector3.UP, uv[i] if i < uv.size() else Vector2.ZERO])
			groups[r]["tris"].append(tri)
		out.append_array(groups.values())
	return out


static func _root(up: Array, a: int) -> int:
	while up[a] != a:
		up[a] = up[up[a]]
		a = up[a]
	return a


## A piece's triangles into `st`, each corner coloured from `img` (white without one), through `tint`.
func _add(st: SurfaceTool, piece: Dictionary, img: Image, tint: Callable) -> void:
	for tri in piece["tris"]:
		for c in tri:
			var col := Color.WHITE
			if img != null:
				var uv: Vector2 = c[2]
				col = img.get_pixel(clampi(int(fposmod(uv.x, 1.0) * img.get_width()), 0, img.get_width() - 1),
					clampi(int(fposmod(uv.y, 1.0) * img.get_height()), 0, img.get_height() - 1))
			st.set_color(tint.call(col))
			st.set_normal(c[1])
			st.add_vertex(c[0])


## A plain box into `st` (given in the finished piece's space; `back` takes it into the pack's, where the phone is).
func _box(st: SurfaceTool, c: Vector3, s: Vector3, col: Color, back: Transform3D) -> void:
	var h := s / 2.0
	for f in [[Vector3.RIGHT, Vector3.BACK, Vector3.UP], [Vector3.LEFT, Vector3.FORWARD, Vector3.UP],
			[Vector3.UP, Vector3.RIGHT, Vector3.BACK], [Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD],
			[Vector3.BACK, Vector3.LEFT, Vector3.UP], [Vector3.FORWARD, Vector3.RIGHT, Vector3.UP]]:
		var nrm: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var o := c + nrm * h
		var du := u * h
		var dv := v * h
		var q := [o - du - dv, o + du - dv, o + du + dv, o - du + dv]
		for k in [0, 2, 1, 0, 3, 2]:
			st.set_color(col)
			st.set_normal((back.basis * nrm).normalized())
			st.add_vertex(back * (q[k] as Vector3))


## The texture shrunk to 48 px, so only its broad colours are left.
static func _shrunk(img: Image) -> Image:
	if img == null:
		return null
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.clear_mipmaps()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(48, 48, Image.INTERPOLATE_LANCZOS)
	return img


## The coin phone's orange paint, made the phones' red.
static func _redden(c: Color) -> Color:
	if c.s > 0.35 and (c.h < 0.12 or c.h > 0.94):
		return Color.from_hsv(RED.h, RED.s, clampf(c.v * 1.05, 0.45, 0.9))
	return c


## The triangles at the game's size (`xf` from the pack's space), cut down to at most about `most` triangles, standing
## on y = 0, centred on x/z, with a plain vertex-coloured material.
func _save(st: SurfaceTool, xf: Transform3D, most: int, path: String) -> void:
	var arrays := st.commit_to_arrays()
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bb := AABB()
	for i in v.size():
		v[i] = xf * v[i]
		n[i] = (xf.basis * n[i]).normalized()
		bb = AABB(v[i], Vector3.ZERO) if i == 0 else bb.expand(v[i])
	var off := Vector3(bb.get_center().x, bb.position.y, bb.get_center().z)
	for i in v.size():
		v[i] -= off
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	var st2 := SurfaceTool.new()
	st2.create_from_arrays(arrays)
	st2.index()
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, st2.commit_to_arrays())
	im.generate_lods(25.0, 60.0, [])
	var full: PackedInt32Array = im.get_surface_arrays(0)[Mesh.ARRAY_INDEX]
	var pick := full
	for l in im.get_surface_lod_count(0):
		pick = im.get_surface_lod_indices(0, l)
		if pick.size() / 3 <= most:
			break
	var out := im.get_surface_arrays(0)
	out[Mesh.ARRAY_INDEX] = pick
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.55
	m.metallic_specular = 0.45
	mesh.surface_set_material(0, m)
	var err := ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
	print("  %-48s %5d -> %4d tris  %s  %s" % [path, full.size() / 3, pick.size() / 3, mesh.get_aabb().size.snapped(Vector3.ONE * 0.01),
		"ok" if err == OK else "SAVE FAILED"])
