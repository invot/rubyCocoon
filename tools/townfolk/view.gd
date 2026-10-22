extends SceneTree
## Renders the baked townsfolk (scripts/gfx/townfolk.gd) in a grid, coloured from a few sample looks, to check a bake:
##   godot --path . --script res://tools/townfolk/view.gd -- --out=sheet.png [--from=0 --count=20 --cols=10]
##   [--w= --h= --size= (pixels, and the camera's height in metres)] [--yaw=deg] [--pose (arms lowered)]
##   [--faces=1.36 (close on the faces, at that height)] [--plain (the kit's own colours)]
const TF = preload("res://scripts/gfx/townfolk.gd")
const SKINS := ["#f2c9a6", "#e0ac84", "#c68a62", "#9a6440", "#6e4428", "#f6d8c0"]
const HAIRS := ["#3a2618", "#1c1410", "#7a4a26", "#d8a850", "#a8402a", "#e8e4dc", "#5a3a28"]
const TOPS := ["#3a6ab0", "#c84a3a", "#4a8a4a", "#e8c050", "#7a4a9a", "#e8e8e8", "#2a3a5a", "#d07a3a"]
const BOTTOMS := ["#3a4a6a", "#5a4030", "#2a2a2a", "#6a7a8a", "#8a6a4a", "#3a5a3a"]
const SHOES := ["#5a3a24", "#2a2a2a", "#e8e8e8", "#8a2a2a", "#3a4a7a"]
func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var people: Array = TF.data()["people"]
	var first := int(args.get("from", "0"))
	var count := mini(int(args.get("count", "20")), people.size() - first)
	var cols := int(args.get("cols", "10"))
	var vp := SubViewport.new()
	vp.size = Vector2i(int(args.get("w", "2000")), int(args.get("h", "900")))
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var yaw := deg_to_rad(float(args.get("yaw", "0")))
	var rigs := []
	for gi in count:
		var i := first + gi
		var c := {"skin": Color(SKINS[i % SKINS.size()]), "hair": Color(HAIRS[i % HAIRS.size()]), "eyes": Color("#4a2e1c"),
			"top": Color(TOPS[i % TOPS.size()]), "bottom": Color(BOTTOMS[i % BOTTOMS.size()]), "shoes": Color(SHOES[i % SHOES.size()])}
		if args.has("plain"):
			c = {}
		var m := TF.assemble(people[i]["parts"], c)
		var holder := Node3D.new()
		holder.position = Vector3((gi % cols) * 1.5, -(gi / cols) * 2.1, 0)
		holder.rotation.y = yaw
		holder.add_child(m)
		vp.add_child(holder)
		rigs.append(m)
		var l := Label3D.new()
		l.text = str(i)
		l.font_size = 64
		l.pixel_size = 0.003
		l.outline_size = 12
		l.position = holder.position + Vector3(0, -0.14, 0.4)
		vp.add_child(l)
	if args.has("pose"):
		# arms down, a bend at the elbows (roughly: the game's own poses are voxel_person.gd's)
		for m in rigs:
			var sk: Skeleton3D = m.get_node("Skeleton")
			for s in [["l_", -1.0], ["r_", 1.0]]:
				sk.set_bone_pose_rotation(sk.find_bone(s[0] + "arm"), Quaternion(Vector3.BACK, s[1] * 1.25))
				sk.set_bone_pose_rotation(sk.find_bone(s[0] + "forearm"), Quaternion(Vector3.RIGHT, -0.3))
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.45, 0.5, 0.55)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.55
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 25, 0)
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var rows := ceili(count / float(cols))
	cam.size = float(args.get("size", str(rows * 2.1 + 0.2)))
	cam.far = 100
	var mid := Vector3((cols - 1) * 0.75, 0.85 - (rows - 1) * 1.05, 0)
	if args.has("faces"):
		mid.y = float(args["faces"]) - (rows - 1) * 1.05
	cam.transform = Transform3D(Basis.IDENTITY, mid + Vector3(0, 0, 20))
	vp.add_child(cam)
	cam.current = true
	for i in 8:
		await process_frame
	vp.get_texture().get_image().save_png(String(args["out"]))
	quit()
