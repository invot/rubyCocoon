extends SceneTree
## Renders furniture pieces from assets/interiors/ in rows, from the front and above like the game's camera, with a
## person-sized post (1.77 tall) at the start of each row for scale. Needs a window (it renders):
##   godot --path . --script res://tools/debug/furniture_sheet.gd -- <out.png> name,name,... [name,name,...]
## Each argument after the image is a row.

const W := 1600


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		print("usage: -- <out.png> name,name,... [name,name,...]")
		quit(1)
		return
	var holder := Node3D.new()
	var z := 0.0
	var right := 0.0
	for row in args.slice(1):
		var x := 0.0
		var post := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.2
		cap.height = 1.77
		post.mesh = cap
		post.position = Vector3(x + 0.2, 0.885, z)
		holder.add_child(post)
		x += 0.7
		var deepest := 0.0
		for name in String(row).split(","):
			var m: Mesh = load("res://assets/interiors/%s.res" % name)
			if m == null:
				print("missing ", name)
				continue
			var bb := m.get_aabb()
			var mi := MeshInstance3D.new()
			mi.mesh = m
			mi.position = Vector3(x - bb.position.x, 0, z)
			holder.add_child(mi)
			x += bb.size.x + 0.35
			deepest = maxf(deepest, bb.size.z)
		right = maxf(right, x)
		z += deepest + 0.6
	var vp := SubViewport.new()
	var hgt := int(W * clampf(z / right * 0.9 + 0.15, 0.3, 1.2))
	vp.size = Vector2i(W, hgt)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#5a5048")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#fff4e8")
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 25, 0)
	sun.light_energy = 0.9
	vp.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(right + 4, z + 4)
	floor_mi.mesh = pm
	floor_mi.position = Vector3(right / 2.0, 0, z / 2.0 - 0.5)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("#a08060")
	floor_mi.material_override = fm
	vp.add_child(floor_mi)
	vp.add_child(holder)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = right * 1.04
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	vp.add_child(cam)
	var c := Vector3(right / 2.0, 0.4, z / 2.0 - 0.6)
	var eye := c + Vector3(0, 0.75, 1).normalized() * 40.0
	cam.transform = Transform3D(Basis.looking_at(c - eye, Vector3.UP), eye)
	cam.far = 200.0
	for f in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(String(args[0]))
	print("saved ", args[0], " ", img.get_size())
	quit()
