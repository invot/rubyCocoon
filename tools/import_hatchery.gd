extends SceneTree
## Bakes the hatchery: the painted stone vault (tools/hatchery_chamber.gd) and the user-supplied platform and core OBJ
## packs, whose materials are rebuilt and repainted. Extract the two original archives to psx/hatchery/{core,platform}/
## first; originals stay untouched. --audit writes isolated parts to build/hatch_assets/ for the visual part audit;
## --conduit rebakes only the wire column, --room the column and vault, and --tongs only the tongs.
const Chamber = preload("res://tools/hatchery_chamber.gd")
const SRC := "res://psx/hatchery/"
const AUDIT := "res://build/hatch_assets/meshes/"
const OUT := "res://assets/interiors/"
const BRONZE := [Color("#3a2f24"), Color("#8a7358"), Color("#dcc7a2")]
const STONE := [Color("#40414b"), Color("#94939c"), Color("#e3dfd6")]
const BRASS := [Color("#4d3b22"), Color("#a07f4a"), Color("#e6cd92")]
var textures := {}


func _init() -> void:
	if not "--audit" in OS.get_cmdline_user_args():
		bake()
		quit()
		return
	DirAccess.make_dir_recursive_absolute(AUDIT)
	for group in ["core", "platform"]:
		for file in DirAccess.get_files_at(SRC + group):
			if not file.ends_with(".obj"):
				continue
			var id := int(file.get_basename().trim_prefix("model_"))
			var mesh := read_obj(SRC + group + "/" + file)
			var mat := material(group, id)
			mesh.surface_set_material(0, mat)
			ResourceSaver.save(mesh, AUDIT + "%s_%d.res" % [group, id], ResourceSaver.FLAG_COMPRESS)
			print("audit ", group, " ", id, " ", mesh.get_aabb())
	quit()


func bake() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	if "--tongs" in OS.get_cmdline_user_args():
		bake_tongs()
		return
	save_mesh(Chamber.conduit(), "hatch_conduit")
	if "--conduit" in OS.get_cmdline_user_args():
		return
	save_mesh(Chamber.build(), "hatch_room")
	ResourceSaver.save(Chamber.mist(), OUT + "hatch_mist.res", ResourceSaver.FLAG_COMPRESS)
	if "--room" in OS.get_cmdline_user_args():
		return
	var platform := read_obj(SRC + "platform/model_0.obj")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(145.946, -38.738, 288.512)
	append(st, platform.surface_get_arrays(0), func(p): return (p - center) * 0.016 + Vector3(0, 1.07, 0),
		func(p): return not (p.y > 0 and Vector2(p.x - center.x, p.z - center.z).length() < 55))
	st.index()
	platform = st.commit()
	platform.surface_set_material(0, material("platform", 0))
	save_mesh(platform, "hatch_platform")
	var core := ArrayMesh.new()
	for id in [2, 3, 4]:
		var mesh := read_obj(SRC + "core/model_%d.obj" % id)
		var arrays := reduce(mesh.surface_get_arrays(0), 4000 if id == 2 else 6000)
		core.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		core.surface_set_material(core.get_surface_count() - 1, material("core", id))
	save_mesh(core, "hatch_core")
	bake_tongs()


func bake_tongs() -> void:
	# Split the actual three articulated source arms into their radial sectors, keeping their hinged geometry.
	var arms := read_obj(SRC + "core/model_1.obj")
	var source := arms.surface_get_arrays(0)
	var angles := [deg_to_rad(90), deg_to_rad(-40), deg_to_rad(-135)]
	var manifest := []
	for i in 3:
		var a: float = angles[i]
		var pivot := Vector3(cos(a) * 0.52, -0.85, sin(a) * 0.52)
		var basis := Basis(Vector3.UP, PI * 0.5 - a)
		var arm := SurfaceTool.new()
		arm.begin(Mesh.PRIMITIVE_TRIANGLES)
		append(arm, source, func(p): return basis.inverse() * (p - pivot), func(p):
			var nearest := 0
			var best := -INF
			for k in 3:
				var dot := Vector2(p.x, p.z).dot(Vector2(cos(angles[k]), sin(angles[k])))
				if dot > best:
					best = dot
					nearest = k
			return nearest == i, basis.inverse())
		arm.index()
		var arrays := reduce(arm.commit_to_arrays(), 9000)
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, material("core", 1))
		save_mesh(mesh, "hatch_tong_%d" % i)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var min_y := mesh.get_aabb().position.y
		var tip := Vector3.ZERO
		var count := 0
		for p in v:
			if p.y < min_y + 0.025:
				tip += p
				count += 1
		tip /= maxi(1, count)
		manifest.append({"angle": PI * 0.5 - a, "pivot": [pivot.x, pivot.y, pivot.z], "tip": [tip.x, tip.y, tip.z]})
	var f := FileAccess.open(OUT + "hatch_tongs.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(manifest, "\t"))
	print("HATCHERY BAKE DONE")


func save_mesh(mesh: ArrayMesh, name: String) -> void:
	var err := ResourceSaver.save(mesh, OUT + name + ".res", ResourceSaver.FLAG_COMPRESS)
	var tris := 0
	for i in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(i)
		tris += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null else arrays[Mesh.ARRAY_VERTEX].size()) / 3
	print("baked %s: %d triangles, %d surfaces, %s" % [name, tris, mesh.get_surface_count(), error_string(err)])


func append(st: SurfaceTool, arrays: Array, transform: Callable, keep := Callable(), normal_basis := Basis.IDENTITY) -> void:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if idx.is_empty():
		idx.resize(v.size())
		for i in idx.size():
			idx[i] = i
	for tri in range(0, idx.size(), 3):
		var mid := (v[idx[tri]] + v[idx[tri + 1]] + v[idx[tri + 2]]) / 3.0
		if keep.is_valid() and not keep.call(mid):
			continue
		for j in 3:
			var at := idx[tri + j]
			st.set_normal(normal_basis * n[at])
			if uv.size() > at:
				st.set_uv(uv[at])
			else:
				st.set_uv(Vector2(v[at].x, v[at].y) * 0.03)
			st.add_vertex(transform.call(v[at]))


func reduce(arrays: Array, budget: int) -> Array:
	if arrays[Mesh.ARRAY_INDEX] == null:
		var idx := PackedInt32Array()
		idx.resize(arrays[Mesh.ARRAY_VERTEX].size())
		for i in idx.size():
			idx[i] = i
		arrays[Mesh.ARRAY_INDEX] = idx
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	im.generate_lods(25.0, 60.0, [])
	var picked: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for l in im.get_surface_lod_count(0):
		if picked.size() > 0 and picked.size() / 3 <= budget:
			break
		picked = im.get_surface_lod_indices(0, l)
	var result := im.get_surface_arrays(0)
	result[Mesh.ARRAY_INDEX] = picked
	return result


func material(group: String, part: int) -> StandardMaterial3D:
	var audit := "--audit" in OS.get_cmdline_user_args()
	var mat := StandardMaterial3D.new()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.72
	if group == "core" and part != 2 and not audit:
		# The frame and tongs have no usable UVs; projecting the cast metal avoids the old seams and diamond plate.
		mat.resource_name = "cast_bronze"
		mat.albedo_texture = Chamber.metal()
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3.ONE * 1.5
		mat.roughness = 0.55
		mat.metallic = 0.12
		return mat
	var tex := "Material_10_baseColor.png"
	if group == "platform":
		tex = "Material_Prop_SciFi_Platform_%s.png" % ["One", "Two", "Three", "Three"][mini(part, 3)]
	var path := SRC + group + "/" + tex
	if not textures.has(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		img.convert(Image.FORMAT_RGBA8)
		var ratio := minf(1.0, 512.0 / maxf(img.get_width(), img.get_height()))
		img.resize(maxi(1, roundi(img.get_width() * ratio)), maxi(1, roundi(img.get_height() * ratio)), Image.INTERPOLATE_LANCZOS)
		if not audit:
			repaint(img, group)
		img.generate_mipmaps()
		textures[path] = ImageTexture.create_from_image(img)
	mat.resource_name = tex
	mat.albedo_texture = textures[path]
	if not audit:
		mat.roughness = 0.82 if group == "platform" else 0.6
		mat.metallic = 0.12 if group == "core" else 0.0
	return mat


## Keeps the source atlas's panels and shading but replaces its colours: the core becomes warm bronze; the platform
## becomes pale stone, with its saturated green and violet trim turned to brass.
func repaint(img: Image, group: String) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var l := clampf(c.get_luminance() * 1.4, 0.0, 1.0)
			var out := ramp(l, BRONZE) if group == "core" else ramp(l, STONE).lerp(ramp(l, BRASS), smoothstep(0.22, 0.5, c.s))
			img.set_pixel(x, y, Color(out.r, out.g, out.b, c.a))


func ramp(l: float, stops: Array) -> Color:
	return stops[0].lerp(stops[1], l * 2.0) if l < 0.5 else stops[1].lerp(stops[2], l * 2.0 - 1.0)


func read_obj(path: String) -> ArrayMesh:
	var pos := PackedVector3Array()
	var norms := PackedVector3Array()
	var uv := PackedVector2Array()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var f := FileAccess.open(path, FileAccess.READ)
	while not f.eof_reached():
		var line := f.get_line()
		var p := line.split(" ", false)
		if p.is_empty():
			continue
		if p[0] in ["v", "vn"]:
			var v := Vector3(float(p[1]), float(p[2]), float(p[3]))
			if p[0] == "v":
				pos.append(v)
			else:
				norms.append(v)
		elif p[0] == "vt":
			uv.append(Vector2(float(p[1]), 1.0 - float(p[2])))
		elif p[0] == "f":
			for k in range(2, p.size() - 1):
				for at in [1, k + 1, k]:
					var ids := p[at].split("/")
					if ids.size() > 1 and ids[1] != "":
						st.set_uv(uv[int(ids[1]) - 1])
					if ids.size() > 2 and ids[2] != "":
						st.set_normal(norms[int(ids[2]) - 1])
					st.add_vertex(pos[int(ids[0]) - 1])
	st.index()
	return st.commit()
