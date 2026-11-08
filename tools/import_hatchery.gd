extends SceneTree
## Bakes the user-supplied hatchery OBJ packs, retaining their UVs and rebuilding missing material bindings.
## Extract the three original archives to psx/hatchery/{core,platform,room}/ first; originals stay untouched.
## --audit writes isolated parts to build/hatch_assets/ for the visual part audit.
const SRC := "res://psx/hatchery/"
const AUDIT := "res://build/hatch_assets/meshes/"
const OUT := "res://assets/interiors/"
const ROOM_PARTS := [0, 16, 39, 43, 61, 62, 63, 65, 66, 67, 68, 69, 82, 83, 84, 95, 96, 97]
var textures := {}


func _init() -> void:
	if not "--audit" in OS.get_cmdline_user_args():
		bake()
		quit()
		return
	DirAccess.make_dir_recursive_absolute(AUDIT)
	for group in ["core", "platform", "room"]:
		for file in DirAccess.get_files_at(SRC + group):
			if not file.ends_with(".obj"):
				continue
			var id := int(file.get_basename().trim_prefix("model_"))
			if group == "room" and not id in [0, 16, 39, 43, 61, 62, 63, 65, 66, 67, 68, 69, 77, 78, 82, 83, 84, 94, 95, 96, 97, 103]:
				continue
			var mesh := read_obj(SRC + group + "/" + file, group == "room")
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
	var room := ArrayMesh.new()
	var groups := {}
	for id in ROOM_PARTS:
		var mesh := read_obj(SRC + "room/model_%d.obj" % id, true)
		# The roundel frames and diffusers contain nested, nearly coplanar faces. Generic LOD reduction seals
		# their interior apertures, so retain those two low-draw-call layers and simplify the other architecture.
		var arrays := mesh.surface_get_arrays(0) if id in [95, 96] else reduce(mesh.surface_get_arrays(0), 9000 if id == 61 else 2500)
		var mat := material("room", id)
		var key := mat.resource_name
		if not groups.has(key):
			groups[key] = [SurfaceTool.new(), mat]
			groups[key][0].begin(Mesh.PRIMITIVE_TRIANGLES)
		append(groups[key][0], arrays, func(p): return (p - Vector3(0, 8.705, 0)) * 0.05)
	for entry in groups.values():
		entry[0].index()
		room.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, entry[0].commit_to_arrays())
		room.surface_set_material(room.get_surface_count() - 1, entry[1])
	save_mesh(room, "hatch_room")
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
		if id != 2:
			arrays = metal_uv(arrays)
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
		var arrays := metal_uv(reduce(arm.commit_to_arrays(), 9000))
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


func metal_uv(arrays: Array) -> Array:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv := PackedVector2Array()
	for p in v:
		uv.append(Vector2(atan2(p.z, p.x) / TAU, p.y * 1.3))
	arrays[Mesh.ARRAY_TEX_UV] = uv
	return arrays


func material(group: String, part: int) -> StandardMaterial3D:
	var audit := "--audit" in OS.get_cmdline_user_args()
	var tex := "Material_10_baseColor.png"
	if group == "platform":
		tex = "Material_Prop_SciFi_Platform_%s.png" % ["One", "Two", "Three", "Three"][mini(part, 3)]
	elif group == "room":
		tex = "Walls.tga.png"
		if part in [62, 63, 65, 66, 67, 68]:
			tex = "Floor.tga.png"
		elif part in [43, 77, 82, 83, 84]:
			tex = "Ceiling.tga.png"
		elif part in [0, 69, 97]:
			tex = "Entrance.tga.png"
		elif part in [16, 39, 61, 78, 94, 103]:
			tex = "seamless_metal.png"
		elif part == 96 and not audit:
			tex = "Swirled-Ice-Texture.png"
		if part in [62, 63]:
			tex = "Belt.tga.png"
	if group == "core" and part != 2 and not audit:
		tex = "seamless_metal.png"
	var path := SRC + group + "/" + tex
	if group == "core" and tex == "seamless_metal.png":
		path = SRC + "room/" + tex
	if not textures.has(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		var ratio := minf(1.0, 512.0 / maxf(img.get_width(), img.get_height()))
		img.resize(maxi(1, roundi(img.get_width() * ratio)), maxi(1, roundi(img.get_height() * ratio)), Image.INTERPOLATE_LANCZOS)
		img.generate_mipmaps()
		textures[path] = ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.resource_name = tex
	mat.albedo_texture = textures[path]
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.roughness = 0.72
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if not audit:
		mat.roughness = 0.8 if group == "platform" else 0.65
		mat.metallic = 0.22 if group == "core" else 0.08
		if group == "room":
			mat.albedo_color = Color("#789193") if part in [16, 39, 43, 61] else Color("#b6b4a2")
			if part == 96:
				mat.albedo_color = Color("#a7c9b1")
				mat.emission_enabled = true
				mat.emission_texture = mat.albedo_texture
				mat.emission = Color("#8bad99")
				mat.emission_energy_multiplier = 0.45
	return mat


func read_obj(path: String, z_up := false) -> ArrayMesh:
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
			if z_up:
				v = Vector3(v.x, v.z, -v.y)
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
