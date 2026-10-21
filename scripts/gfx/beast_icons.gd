extends SubViewport
## Renders the new beasts' menu icons (beast_rig.gd): a three-quarter view from the front, facing right, on a clear
## background, shrunk to SIZE with hard edges and a dark outline, as tools/make_beast_icons.gd draws the PSX ones.
## tools/make_new_beast_icons.gd renders every form's, and its ghost's, to assets/beasts/icons/; PixelArt.beast_texture
## has a merge's rendered here the first time it's shown (paint()), showing its frame's icon till then.

const BeastModel = preload("res://scripts/gfx/beast_model.gd")
const SIZE := 48
## rendered larger, then shrunk, for clean edges
const SS := 4
## how far the beast is turned towards the viewer from side on
const TURN := 0.6

var _cam: Camera3D
## [genes, the texture its icon goes into] still to paint, in turn
var _jobs := []
var _busy := false


func _init() -> void:
	size = Vector2i(SIZE * SS, SIZE * SS)
	transparent_bg = true
	own_world_3d = true
	msaa_3d = Viewport.MSAA_4X
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 0.8
	add_child(sun)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(_cam)


## The icon of these genes (a beast drawn with a rig), SIZE x SIZE, or null where nothing renders (headless). A
## coroutine: it takes a few frames.
func render(genes: Dictionary) -> Image:
	var r: Node3D = BeastModel.rig(genes)
	if r == null:
		return null
	r.scale = Vector3.ONE
	r.rotation.y = -TURN
	# held in its first pose, the smoke round a ghost left out (it would only blur at this size)
	r.set_process(false)
	if r.smoke != null:
		r.smoke.hide()
	add_child(r)
	# framed by its pieces as they stand
	var bb := AABB()
	var first := true
	for mi in r.find_children("*", "MeshInstance3D", true, false):
		var xf: Transform3D = r.transform * r.pivot.transform * r.skel.transform * (mi as MeshInstance3D).transform
		var b: AABB = xf * (mi as MeshInstance3D).get_aabb()
		bb = b if first else bb.merge(b)
		first = false
	var c := bb.get_center()
	var off := Vector3(0.0, 1.2, 4.0)
	# (set as a transform: the viewport may not be in the tree yet)
	_cam.transform = Transform3D(Basis.looking_at(-off, Vector3.UP), c + off)
	_cam.size = maxf(bb.size.y * 1.12, maxf(bb.size.x, bb.size.z) * 1.02) + 0.06
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for i in 3:
		await RenderingServer.frame_post_draw
	var img := get_texture().get_image()
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	r.queue_free()
	if img == null or img.is_empty():
		return null
	img.convert(Image.FORMAT_RGBA8)
	img.resize(SIZE, SIZE, Image.INTERPOLATE_BILINEAR)
	finish(img)
	return img


## Paints the icon of these genes into tex once it's rendered (one at a time, in the order asked).
func paint(genes: Dictionary, tex: ImageTexture) -> void:
	_jobs.append([genes, tex])
	if _busy:
		return
	_busy = true
	while not _jobs.is_empty():
		var job: Array = _jobs.pop_front()
		var img := await render(job[0])
		if img != null and is_instance_valid(job[1]):
			(job[1] as ImageTexture).update(img)
	_busy = false


## Hard alpha (pixel-art edges) and a dark outline one pixel wide around the silhouette.
static func finish(img: Image) -> void:
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
