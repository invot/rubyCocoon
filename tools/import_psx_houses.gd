extends SceneTree
## Bakes the houses of the PS1 House Pack (psx/Environments/PS1 House Pack ... (najjar320)/glb) into
## assets/psx/houses/<key>.res, and its 64 px texture tiles into assets/psx/houses/tiles/<tile>.res.
##   godot --headless --path . --script res://tools/import_psx_houses.gd [-- key1 key2 ...]
##
## Each house becomes one ArrayMesh, one surface per material, every material named for the part it dresses ("shell",
## "roof", "trim", "door", "extras", "glass", or "inside" for the rooms behind the walls) and pointing at the shared
## tile textures, so house_models.gd can re-skin a house in a town's own materials by swapping tiles. The front door
## (the "_door" object) is turned to face +z; the mesh keeps the pack's metres, stands on y = 0 and is centred on x/z.
## Meta: "door" (Vector3, the front door's centre), "tiles" ({part: tile name} as the pack dressed it).

const SRC := "Environments/PS1 House Pack — 100 Low Poly Houses, Textured Inside and Out (najjar320)/"
const OUT := "res://assets/psx/houses/"
const TILES := OUT + "tiles/"
const PARTS := ["shell", "roof", "trim", "door", "extras", "glass"]


func _init() -> void:
	var src := ProjectSettings.globalize_path("res://psx/") + SRC
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TILES))
	# the tiles first, each a resource of its own that every house shares
	var tiles := {}
	var td := DirAccess.open(src + "textures")
	for f in td.get_files():
		if not f.ends_with(".png") or f.contains("_3x3"):
			continue
		var img := Image.load_from_file(src + "textures/" + f)
		img.convert(Image.FORMAT_RGBA8)
		img.generate_mipmaps()
		var t := ImageTexture.create_from_image(img)
		var path := TILES + f.get_basename() + ".res"
		ResourceSaver.save(t, path, ResourceSaver.FLAG_COMPRESS)
		tiles[f.get_basename()] = load(path)
	print("  %d tiles" % tiles.size())
	var only := OS.get_cmdline_user_args()
	var gd := DirAccess.open(src + "glb")
	var files := gd.get_files()
	files.sort()
	for f in files:
		var key := f.get_basename()
		if not f.ends_with(".glb") or (not only.is_empty() and not only.has(key)):
			continue
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_file(src + "glb/" + f, st) != OK:
			push_error("could not load " + f)
			continue
		var sc := doc.generate_scene(st)
		var mesh := _bake(sc, key, tiles)
		sc.free()
		if mesh == null:
			continue
		var err := ResourceSaver.save(mesh, OUT + key + ".res", ResourceSaver.FLAG_COMPRESS)
		print("  %-18s %s door %s  %s" % [key, mesh.get_aabb().size, mesh.get_meta("door", null), "ok" if err == OK else "SAVE FAILED"])
	quit()


func _bake(sc: Node, key: String, tiles: Dictionary) -> ArrayMesh:
	var parts := []
	var door_box := AABB()
	var has_door := false
	for mi in sc.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		var part := String(inst.name).trim_prefix(key + "_")
		if not part in PARTS:
			part = "extras"
		var xf := _xf_to(inst, sc)
		for s in inst.mesh.get_surface_count():
			var arrays := inst.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in verts.size():
				verts[i] = xf * verts[i]
			arrays[Mesh.ARRAY_VERTEX] = verts
			if arrays[Mesh.ARRAY_NORMAL] != null:
				var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				for i in ns.size():
					ns[i] = (xf.basis * ns[i]).normalized()
				arrays[Mesh.ARRAY_NORMAL] = ns
			arrays[Mesh.ARRAY_TANGENT] = null
			var mat := inst.get_active_material(s)
			var tile := String(mat.resource_name if mat else "").trim_prefix("PS1_")
			var role := part
			# the rooms behind the walls: concrete walls and ceilings, tiled floors
			if part == "shell" and tile in ["concrete_smooth", "floor_tile"]:
				role = "inside"
			if part == "glass" or tile == "House_Glass":
				role = "glass"
			parts.append({"arrays": arrays, "role": role, "tile": tile})
			if part == "door":
				for v in verts:
					door_box = AABB(v, Vector3.ZERO) if not has_door else door_box.expand(v)
					has_door = true
	if parts.is_empty():
		return null
	# turn the house so its front door faces +z
	var yaw := 0.0
	var bb := AABB()
	var first := true
	for p in parts:
		for v in (p["arrays"][Mesh.ARRAY_VERTEX] as PackedVector3Array):
			bb = AABB(v, Vector3.ZERO) if first else bb.expand(v)
			first = false
	if has_door:
		var dc := door_box.get_center() - bb.get_center()
		# the door leaf is thin across the wall it sits in
		if door_box.size.x < door_box.size.z:
			yaw = -PI / 2.0 if dc.x > 0.0 else PI / 2.0
		else:
			yaw = 0.0 if dc.z > 0.0 else PI
	var basis := Basis(Vector3.UP, yaw)
	var turned := AABB()
	first = true
	for c in 8:
		var v := basis * (bb.get_endpoint(c) - bb.get_center())
		turned = AABB(v, Vector3.ZERO) if first else turned.expand(v)
		first = false
	var shift := Vector3(0, -turned.position.y, 0)
	var mesh := ArrayMesh.new()
	var used := {}
	for p in parts:
		var arrays: Array = p["arrays"]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in verts.size():
			verts[i] = basis * (verts[i] - bb.get_center()) + shift
		arrays[Mesh.ARRAY_VERTEX] = verts
		if arrays[Mesh.ARRAY_NORMAL] != null:
			var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in ns.size():
				ns[i] = basis * ns[i]
			arrays[Mesh.ARRAY_NORMAL] = ns
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _material(String(p["role"]), String(p["tile"]), tiles))
		if p["role"] in PARTS:
			used[p["role"]] = p["tile"]
	if has_door:
		mesh.set_meta("door", basis * (door_box.get_center() - bb.get_center()) + shift)
	mesh.set_meta("tiles", used)
	return mesh


func _material(role: String, tile: String, tiles: Dictionary) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = role
	m.roughness = 1.0
	m.metallic_specular = 0.15
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	if role == "glass":
		# dark panes with a hint of sky
		m.albedo_color = Color("#2a3a4a")
		m.roughness = 0.25
		m.metallic_specular = 0.8
		return m
	if tiles.has(tile):
		m.albedo_texture = tiles[tile]
	else:
		m.albedo_color = Color(0.7, 0.7, 0.7)
	m.set_meta("tile", tile)
	return m


func _xf_to(node: Node3D, top: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = node
	while cur != null and cur != top:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf
