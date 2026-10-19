extends SceneTree
## Renders a model from four sides (front = +z, right = +x, back, three-quarter) into one PNG, to see what a pack
## model looks like and which way it faces. Needs a window (it renders):
##   godot --path . --script res://tools/debug/preview_model.gd -- <model> <out.png> [node name]
## <model> is a .fbx/.glb/.obj under psx/ (path relative to psx/) or a res:// mesh (.res/.tres). With a node name,
## only that MeshInstance3D is drawn.

const CELL := 256


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		print("usage: -- <model> <out.png> [node]")
		quit(1)
		return
	var holder := Node3D.new()
	var src: Variant = _load(String(args[0]))
	if src == null:
		print("could not load ", args[0])
		quit(1)
		return
	var only := String(args[2]) if args.size() > 2 else ""
	var bb := AABB()
	var first := true
	if src is Mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = src
		holder.add_child(mi)
		bb = (src as Mesh).get_aabb()
	else:
		var top := src as Node
		for n in top.find_children("*", "MeshInstance3D", true, false):
			var inst := n as MeshInstance3D
			if inst.mesh == null or (only != "" and String(inst.name) != only):
				continue
			var xf := _xf_to(inst, top)
			var mi := MeshInstance3D.new()
			mi.mesh = inst.mesh
			mi.transform = xf
			holder.add_child(mi)
			var b := xf * inst.mesh.get_aabb()
			bb = b if first else bb.merge(b)
			first = false
	var vp := SubViewport.new()
	vp.size = Vector2i(CELL, CELL)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#6a7a8a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	vp.add_child(sun)
	vp.add_child(holder)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	var c := bb.get_center()
	var r := maxf(bb.size.x, maxf(bb.size.y, bb.size.z))
	cam.size = r * 1.15
	cam.near = r * 0.01
	cam.far = r * 20.0
	# the very first render comes out empty: draw a few throwaway frames first
	cam.position = c + Vector3(0, 0, r * 4.0)
	for f in 6:
		await process_frame
	var sheet := Image.create(CELL * 4, CELL, false, Image.FORMAT_RGBA8)
	var dirs := [Vector3(0, 0.15, 1), Vector3(1, 0.15, 0), Vector3(0, 0.15, -1), Vector3(0.7, 0.5, 0.7)]
	for i in dirs.size():
		var d: Vector3 = (dirs[i] as Vector3).normalized()
		cam.position = c + d * r * 4.0
		cam.look_at(c, Vector3.UP)
		for f in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, CELL, CELL), Vector2i(i * CELL, 0))
	sheet.save_png(String(args[1]))
	print("aabb ", bb, "  -> ", args[1])
	quit()


func _load(rel: String) -> Variant:
	if rel.begins_with("res://"):
		return load(rel)
	var p := ProjectSettings.globalize_path("res://psx/") + rel
	var ext := p.get_extension().to_lower()
	if ext in ["glb", "gltf"]:
		var d := GLTFDocument.new()
		var st := GLTFState.new()
		if d.append_from_file(p, st) == OK:
			return d.generate_scene(st)
	elif ext == "fbx":
		var d2 := FBXDocument.new()
		var st2 := FBXState.new()
		if d2.append_from_file(p, st2) == OK:
			return d2.generate_scene(st2)
	elif ext == "obj":
		return _obj(p)
	return null


## A bare-bones OBJ reader (positions, uvs, normals, one material) with the texture next to it, if any.
func _obj(path: String) -> Mesh:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var vs := PackedVector3Array()
	var uvs := PackedVector2Array()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		var p := line.split(" ", false)
		if p.is_empty():
			continue
		match p[0]:
			"v":
				vs.append(Vector3(float(p[1]), float(p[2]), float(p[3])))
			"vt":
				uvs.append(Vector2(float(p[1]), 1.0 - float(p[2])))
			"f":
				var idx := []
				for k in range(1, p.size()):
					idx.append(p[k].split("/"))
				for k in range(1, idx.size() - 1):
					for tri in [idx[0], idx[k + 1], idx[k]]:
						if tri.size() > 1 and tri[1] != "":
							st.set_uv(uvs[int(tri[1]) - 1])
						st.add_vertex(vs[int(tri[0]) - 1])
	st.generate_normals()
	var m := st.commit()
	var dir := path.get_base_dir()
	for ext in ["png", "bmp", "jpg", "tga"]:
		for fn in DirAccess.get_files_at(dir):
			if fn.get_extension().to_lower() == ext:
				var img := Image.load_from_file(dir + "/" + fn)
				if img != null:
					var mat := StandardMaterial3D.new()
					mat.albedo_texture = ImageTexture.create_from_image(img)
					mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
					m.surface_set_material(0, mat)
					return m
	return m


func _xf_to(node: Node3D, top: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = node
	while cur != null and cur != top:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf
