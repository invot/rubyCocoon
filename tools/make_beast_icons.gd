extends SceneTree
## Renders the menu icon of every PSX beast form (assets/psx/beasts/<form>.res) to assets/psx/beasts/icons/<form>.res,
## and of every Gearhart robot (assets/psx/robots/<key>.res) to assets/psx/robots/icons/<key>.res
## (an ImageTexture, so the game needs no import step):
## a three-quarter side view in the model's own colours, 48 x 48, with a soft dark outline. PixelArt.beast_texture
## recolours a beast's icon with its genes, the same way voxel_beast.gd recolours the model, so icon and model match;
## robots keep their own colours.
## Needs a window (it renders):
##   godot --path . --script res://tools/make_beast_icons.gd [-- form1 form2 ...]

## model folder: [icon folder, how far the model is turned towards the viewer from side on]
## (the robots stand upright, and read best from nearer the front)
const DIRS := {
	"res://assets/psx/beasts/": ["res://assets/psx/beasts/icons/", 0.45],
	"res://assets/psx/robots/": ["res://assets/psx/robots/icons/", 0.95],
}
const SIZE := 48
## rendered larger, then shrunk, for clean edges
const SS := 4


func _initialize() -> void:
	var only := OS.get_cmdline_user_args()
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE * SS, SIZE * SS)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.85
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 0.45
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	var mi := MeshInstance3D.new()
	vp.add_child(mi)
	# every model: [its file, its icon's file, its turn]
	var jobs := []
	for src in DIRS:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRS[src][0]))
		var names := []
		for f in DirAccess.get_files_at(src):
			if f.ends_with(".res"):
				names.append(f.get_basename())
		names.sort()
		for n in names:
			if only.is_empty() or only.has(n):
				jobs.append([src + n + ".res", DIRS[src][0] + n + ".res", DIRS[src][1]])
	if jobs.is_empty():
		quit()
		return
	# the very first render comes out empty: draw one throwaway frame first
	mi.mesh = load(jobs[0][0])
	cam.position = Vector3(0, 1.2, 4.0)
	for i in 6:
		await process_frame
	for job in jobs:
		var m: ArrayMesh = load(job[0])
		mi.mesh = m
		# turned a little towards the viewer, facing right
		mi.rotation = Vector3(0, -float(job[2]), 0)
		var bb := mi.transform * m.get_aabb()
		var c := bb.get_center()
		# flat models (birds in flight, crocodiles) are seen from higher up, so they show their shape
		var flat := m.get_aabb().size.y < 0.4 * maxf(m.get_aabb().size.x, m.get_aabb().size.z)
		cam.position = c + (Vector3(0.0, 3.2, 2.4) if flat else Vector3(0.0, 1.2, 4.0))
		cam.look_at(c, Vector3.UP)
		cam.size = (maxf(bb.size.x, bb.size.z) * 0.95 if flat else maxf(bb.size.y * 1.15, maxf(bb.size.x, bb.size.z) * 1.05)) + 0.08
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(SIZE, SIZE, Image.INTERPOLATE_BILINEAR)
		_finish(img)
		ResourceSaver.save(ImageTexture.create_from_image(img), job[1], ResourceSaver.FLAG_COMPRESS)
		print("  icon ", job[1])
	quit()


## Hard alpha (pixel-art edges) and a dark outline one pixel wide around the silhouette.
func _finish(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var solid := PackedByteArray()
	solid.resize(w * h)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a >= 0.45:
				solid[y * w + x] = 1
				img.set_pixel(x, y, Color(c.r / maxf(c.a, 0.01), c.g / maxf(c.a, 0.01), c.b / maxf(c.a, 0.01), 1.0))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			if solid[y * w + x] == 1:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and solid[q.y * w + q.x] == 1:
					img.set_pixel(x, y, Color(0.06, 0.04, 0.08, 0.9))
					break
