extends SceneTree
## Renders labelled source-part contact sheets, rather than choosing assets by their numbered filenames.
const CELL := 300
var vp: SubViewport


func _initialize() -> void:
	var group := String(OS.get_cmdline_user_args()[0])
	var ids := [0, 1, 2, 3, 4] if group == "core" else [0, 1, 2, 3]
	var columns := 4
	var sheet := Image.create(CELL * columns, CELL * ceili(float(ids.size()) / columns), false, Image.FORMAT_RGBA8)
	vp = SubViewport.new()
	vp.size = Vector2i(CELL, CELL)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_2X
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#4d6475")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 25, 0)
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 24)
	label.position = Vector2(8, 8)
	vp.add_child(label)
	for j in 8:
		await process_frame
	for i in ids.size():
		var mesh = load("res://build/hatch_assets/meshes/%s_%d.res" % [group, ids[i]])
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		vp.add_child(mi)
		var bb: AABB = mesh.get_aabb()
		var r := maxf(bb.size.x, maxf(bb.size.y, bb.size.z))
		cam.size = r * 1.25
		cam.near = r * 0.001
		cam.far = r * 20
		cam.position = bb.get_center() + Vector3(0.7, 0.65, 1.0).normalized() * r * 4
		cam.look_at(bb.get_center())
		label.text = "%s %d" % [group, ids[i]]
		for j in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, CELL, CELL), Vector2i(i % columns, i / columns) * CELL)
		mi.free()
	sheet.save_png("res://build/shots/hatch_parts_%s.png" % group)
	quit()
