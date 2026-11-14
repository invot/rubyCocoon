extends SceneTree
## Bakes the KayKit Furniture Bits pack (Kay Lousberg, CC0; the glTF folder copied to psx/kaykit_furniture/, see
## CREDITS.md) into assets/interiors/kk_*.res: the houseplants (cacti), lamps, chairs and stools, beds, tables, the long
## chest of drawers that stands for every dresser, and the area rugs.
##   godot --headless --path . --script res://tools/import_kaykit_furniture.gd -- --textures
##   godot --headless --path . --import
##   godot --headless --path . --script res://tools/import_kaykit_furniture.gd
##
## The pack paints everything from one atlas of soft gradient swatches. The first pass writes that atlas (halved) to
## assets/interiors/kaykit/furniture.png, and beside it fabric.png: the same atlas as plain light-to-shade grey, so
## the pack's blue cloth can be any colour. The second bakes each piece into one mesh: surface 0 ("base") is
## everything else on the atlas, surface 1 ("fabric"), where a piece has any, is every triangle painted from the blue
## swatch, sampling fabric.png, for room_builder.gd to tint (RoomBuilder.fabric_material). Pieces come out like the
## other interior pieces: centred on x/z, standing on y = 0, facing +z with their back to -z (the pack's own way
## round), at the size given (width, height, depth in game units, so one tile is 1.0).
##
## The atlas is already smooth gradient swatches, so it is not run through tools/smooth_textures.gd (softening
## would only bleed neighbouring swatches into each other); its folder is outside that tool's list.

const B = preload("res://tools/psx_bake.gd")
const SRC := "res://psx/kaykit_furniture/"
const OUT := "res://assets/interiors/"
const TEX_DIR := "res://assets/interiors/kaykit/"
## The blue swatch on the atlas (u and v from the top-left, as glTF has them).
const BLUE := Rect2(0.25, 0.25, 0.25, 0.25)
## How much of the swatch's own light-to-shade the grey fabric keeps (1 = all of it).
const FABRIC_SHADE := 0.6

## name: [the pack's model, size (width, height, depth)].
const PIECES := {
	# houseplants: potted cacti, a floor-standing pair and a small pair for tables and counters
	"kk_cactus_medium_A": ["cactus_medium_A", [0.72, 0.68, 0.69]],
	"kk_cactus_medium_B": ["cactus_medium_B", [0.72, 0.68, 0.69]],
	"kk_cactus_small_A": ["cactus_small_A", [0.3, 0.33, 0.3]],
	"kk_cactus_small_B": ["cactus_small_B", [0.3, 0.33, 0.3]],
	# lamps
	"kk_lamp_standing": ["lamp_standing", [0.68, 1.71, 0.68]],
	"kk_lamp_table": ["lamp_table", [0.42, 0.43, 0.42]],
	# chairs (A, B and C with cloth seats, A and B also in plain wood) and stools
	"kk_chair_A": ["chair_A", [0.5, 0.84, 0.57]],
	"kk_chair_B": ["chair_B", [0.5, 0.84, 0.57]],
	"kk_chair_C": ["chair_C", [0.5, 0.8, 0.63]],
	"kk_chair_A_wood": ["chair_A_wood", [0.5, 0.84, 0.57]],
	"kk_chair_B_wood": ["chair_B_wood", [0.5, 0.84, 0.57]],
	"kk_stool": ["chair_stool", [0.5, 0.42, 0.5]],
	"kk_stool_wood": ["chair_stool_wood", [0.5, 0.42, 0.5]],
	# beds: singles a tile wide and two long, doubles two by two
	"kk_bed_single_A": ["bed_single_A", [0.94, 0.72, 2.12]],
	"kk_bed_single_B": ["bed_single_B", [0.94, 0.72, 2.12]],
	"kk_bed_double_A": ["bed_double_A", [1.84, 0.72, 2.15]],
	"kk_bed_double_B": ["bed_double_B", [1.84, 0.72, 2.15]],
	# tables, and the low one for coffee tables
	"kk_table_small": ["table_small", [0.86, 0.74, 0.86]],
	"kk_table_medium": ["table_medium", [1.4, 0.74, 1.4]],
	"kk_table_long": ["table_medium_long", [1.6, 0.74, 1.06]],
	"kk_table_low": ["table_low", [1.25, 0.38, 0.78]],
	# the long chest of drawers (every dresser stands on one tile against a wall)
	"kk_drawers": ["cabinet_medium", [0.96, 0.62, 0.48]],
	# area rugs (room_builder.gd stretches them over their tiles)
	"kk_rug_rect": ["rug_rectangle_B", [3.0, 0.025, 2.0]],
	"kk_rug_stripes": ["rug_rectangle_stripes_B", [3.0, 0.025, 2.0]],
	"kk_rug_oval": ["rug_oval_B", [3.0, 0.025, 2.0]],
}


func _init() -> void:
	if "--textures" in OS.get_cmdline_user_args():
		_textures()
	else:
		_bake_all()
	quit()


func _textures() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEX_DIR))
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC + "furniturebits_texture.png"))
	img.convert(Image.FORMAT_RGB8)
	img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_LANCZOS)
	img.save_png(TEX_DIR + "furniture.png")
	# the blue swatch's lightest point is white; the rest falls off with its own shading, a little gentler
	var top := 0.0
	var w := img.get_width()
	var h := img.get_height()
	for y in range(int(BLUE.position.y * h), int(BLUE.end.y * h)):
		for x in range(int(BLUE.position.x * w), int(BLUE.end.x * w)):
			top = maxf(top, img.get_pixel(x, y).get_luminance())
	var grey := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var v := 1.0 - (1.0 - clampf(img.get_pixel(x, y).get_luminance() / top, 0.0, 1.0)) * FABRIC_SHADE
			grey.set_pixel(x, y, Color(v, v, v))
	grey.save_png(TEX_DIR + "fabric.png")
	print("wrote ", TEX_DIR, "furniture.png and fabric.png; now run godot --headless --path . --import")


func _material(tex: String, path: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(TEX_DIR + tex)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.roughness = 0.9
	m.metallic_specular = 0.25
	ResourceSaver.save(m, path)
	return load(path)


func _bake_all() -> void:
	if not ResourceLoader.exists(TEX_DIR + "furniture.png"):
		push_error("run with -- --textures first, then --import")
		return
	var base := _material("furniture.png", TEX_DIR + "base.tres")
	var fabric := _material("fabric.png", TEX_DIR + "fabric.tres")
	var only := OS.get_cmdline_user_args()
	for name in PIECES:
		if not only.is_empty() and not name in only:
			continue
		var mesh := _bake(PIECES[name][0], PIECES[name][1], base, fabric)
		if mesh == null:
			push_error("could not bake " + name)
			continue
		var err := ResourceSaver.save(mesh, OUT + name + ".res", ResourceSaver.FLAG_COMPRESS)
		print("%s: %s, %d tris, %d surfaces%s" % [name, mesh.get_aabb().size, B.tris(mesh), mesh.get_surface_count(),
			"" if err == OK else " SAVE FAILED"])


func _bake(model: String, size: Array, base: Material, fabric: Material) -> ArrayMesh:
	var scene := B.load_model(ProjectSettings.globalize_path(SRC + model + ".gltf"))
	if scene == null:
		return null
	# every triangle in the model's own space, sorted into base and fabric
	var parts := [[PackedVector3Array(), PackedVector3Array(), PackedVector2Array()],
		[PackedVector3Array(), PackedVector3Array(), PackedVector2Array()]]
	var bb := AABB()
	var first := true
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		if inst.mesh == null:
			continue
		var xf := B.xf_to(inst, scene)
		for si in inst.mesh.get_surface_count():
			var arrays := inst.mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var ids = arrays[Mesh.ARRAY_INDEX]
			if ids == null or (ids as PackedInt32Array).is_empty():
				ids = PackedInt32Array(range(vs.size()))
			for i in range(0, ids.size(), 3):
				var uv: Vector2 = (uvs[ids[i]] + uvs[ids[i + 1]] + uvs[ids[i + 2]]) / 3.0
				var part: Array = parts[1 if BLUE.has_point(uv) else 0]
				for j in 3:
					var v: Vector3 = xf * vs[ids[i + j]]
					bb = AABB(v, Vector3.ZERO) if first else bb.expand(v)
					first = false
					part[0].append(v)
					part[1].append((xf.basis * ns[ids[i + j]]).normalized())
					part[2].append(uvs[ids[i + j]])
	scene.free()
	var k := Vector3(float(size[0]) / bb.size.x, float(size[1]) / bb.size.y, float(size[2]) / bb.size.z)
	var shift := Vector3(bb.get_center().x, bb.position.y, bb.get_center().z)
	var mesh := ArrayMesh.new()
	for p in 2:
		var vs: PackedVector3Array = parts[p][0]
		if vs.is_empty():
			continue
		var ns: PackedVector3Array = parts[p][1]
		for i in vs.size():
			vs[i] = (vs[i] - shift) * k
			# normals of a stretched shape lean the other way
			ns[i] = (ns[i] / k).normalized()
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in vs.size():
			st.set_normal(ns[i])
			st.set_uv(parts[p][2][i])
			st.add_vertex(vs[i])
		st.index()
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, fabric if p == 1 else base)
		mesh.surface_set_name(mesh.get_surface_count() - 1, "fabric" if p == 1 else "base")
	return mesh
