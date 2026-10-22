extends SceneTree
## Debug: renders a summon's OBJ pieces (new beasts/<dir>) together, each piece with its own texture, looking
## side-on along the model's longest axis, optionally zoomed to a stretch of it (0 = the low end, 1 = the high end).
##   -- --dir=air --map=0:a.png,1:b.png,2: [--from=0 --to=0.2] [--yaw=deg] [--axis=y] --out=...
const OBJ = preload("res://tools/townfolk/obj.gd")


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var dir := "res://new beasts/%s/" % args["dir"]
	var vp := SubViewport.new()
	vp.size = Vector2i(int(args.get("w", "1600")), int(args.get("h", "900")))
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var holder := Node3D.new()
	vp.add_child(holder)
	var box := AABB()
	var first := true
	for pair in String(args["map"]).split(","):
		var n := int(pair.get_slice(":", 0))
		var tex := pair.get_slice(":", 1)
		var d := OBJ.read(n, dir)
		if d.is_empty():
			continue
		var v: PackedVector3Array = d["v"]
		var uv: PackedVector2Array = d["uv"]
		var tri: PackedInt32Array = d["tri"]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for t in range(0, tri.size(), 6):
			for k in [0, 2, 1]:
				var ti := tri[t + k * 2 + 1]
				var q: Vector2 = uv[ti] if ti >= 0 and ti < uv.size() else Vector2.ZERO
				st.set_uv(Vector2(q.x, 1.0 - q.y))
				var p := v[tri[t + k * 2]]
				st.add_vertex(p)
				if first:
					box = AABB(p, Vector3.ZERO)
					first = false
				box = box.expand(p)
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		var m := StandardMaterial3D.new()
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if tex != "":
			m.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(dir + tex)))
		else:
			m.albedo_color = Color.from_hsv(float(n) * 0.17, 0.6, 0.9)
		mi.material_override = m
		holder.add_child(mi)
	# lay the longest axis along screen x
	var sz := box.size
	var axis := String(args.get("axis", "y" if sz.y >= maxf(sz.x, sz.z) else ("x" if sz.x >= sz.z else "z")))
	match axis:
		"y":
			holder.rotation.z = -PI / 2.0
		"z":
			holder.rotation.y = PI / 2.0
	holder.rotation.x += deg_to_rad(float(args.get("roll", "0")))
	holder.rotation.y += deg_to_rad(float(args.get("yaw", "0")))
	var xf := holder.transform
	var wb := xf * box
	var from := float(args.get("from", "0"))
	var to := float(args.get("to", "1"))
	var x0 := wb.position.x + wb.size.x * from
	var x1 := wb.position.x + wb.size.x * to
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
	var aspect := float(vp.size.x) / vp.size.y
	cam.size = maxf((x1 - x0) / aspect, wb.size.y) * 1.08
	cam.far = wb.get_longest_axis_size() * 20.0
	cam.transform = Transform3D(Basis.IDENTITY, Vector3((x0 + x1) / 2.0, wb.get_center().y, wb.end.z + wb.get_longest_axis_size() * 4.0))
	vp.add_child(cam)
	cam.current = true
	print("box ", box, " axis ", axis)
	for i in 8:
		await process_frame
	vp.get_texture().get_image().save_png(String(args["out"]))
	quit()
