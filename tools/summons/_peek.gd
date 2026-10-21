extends SceneTree
## Debug: renders a summon's OBJ pieces (new beasts/<dir>), one row per texture tried (and a row of plain grey),
## each piece in its own column, to see which texture each piece uses.
##   -- --dir=air --tex=a.png,b.png [--pieces=0,1] [--flip=1] [--yaw=deg] --out=...
const OBJ = preload("res://tools/townfolk/obj.gd")
func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var dir := "res://new beasts/%s/" % args["dir"]
	var texs: Array = Array(String(args.get("tex", "")).split(",", false))
	texs.append("")
	var pieces := []
	if args.has("pieces"):
		pieces = Array(String(args["pieces"]).split(",")).map(func(s): return int(s))
	else:
		for f in DirAccess.get_files_at(dir):
			if f.begins_with("model_") and f.ends_with(".obj"):
				pieces.append(int(f.get_slice("_", 1).get_basename()))
		pieces.sort()
	var vp := SubViewport.new()
	vp.size = Vector2i(int(args.get("w", "2400")), int(args.get("h", "1200")))
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var mats := []
	for t in texs:
		var m := StandardMaterial3D.new()
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if t != "":
			m.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(dir + t)))
		else:
			m.albedo_color = Color(0.7, 0.7, 0.7)
		mats.append(m)
	var flip: bool = args.get("flip", "1") == "1"
	var yaw := deg_to_rad(float(args.get("yaw", "0")))
	var cell := 0.0
	var meshes := []
	for n in pieces:
		var d := OBJ.read(n, dir)
		var v: PackedVector3Array = d["v"]
		var box := AABB(v[0], Vector3.ZERO)
		for p in v:
			box = box.expand(p)
		cell = maxf(cell, box.get_longest_axis_size())
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var tri: PackedInt32Array = d["tri"]
		var uv: PackedVector2Array = d["uv"]
		for t in range(0, tri.size(), 6):
			for k in [0, 2, 1]:
				var ti := tri[t + k * 2 + 1]
				var q: Vector2 = uv[ti] if ti >= 0 and ti < uv.size() else Vector2.ZERO
				st.set_uv(Vector2(q.x, 1.0 - q.y) if flip else q)
				st.add_vertex(v[tri[t + k * 2]] - box.get_center())
		st.generate_normals()
		meshes.append(st.commit())
	cell *= 1.1
	for r in mats.size():
		for c in meshes.size():
			var mi := MeshInstance3D.new()
			mi.mesh = meshes[c]
			mi.material_override = mats[r]
			mi.position = Vector3(c * cell, -r * cell, 0)
			mi.rotation.y = yaw
			vp.add_child(mi)
			var l := Label3D.new()
			l.text = "%d" % pieces[c] if r == 0 else ""
			l.font_size = 64
			l.pixel_size = cell * 0.003
			l.outline_size = 12
			l.position = Vector3(c * cell, cell * 0.45, cell)
			vp.add_child(l)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.4, 0.42, 0.46)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.8
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 25, 0)
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var cols := meshes.size()
	var rows := mats.size()
	cam.size = maxf(rows * cell, cols * cell * float(vp.size.y) / vp.size.x) * 1.05
	cam.far = cell * 200
	cam.transform = Transform3D(Basis.IDENTITY, Vector3((cols - 1) * cell / 2.0, -(rows - 1) * cell / 2.0, cell * 50))
	vp.add_child(cam)
	cam.current = true
	for i in 8:
		await process_frame
	vp.get_texture().get_image().save_png(String(args["out"]))
	quit()
