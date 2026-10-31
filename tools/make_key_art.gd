extends SceneTree
## Renders the pieces of the app icon and the boot splash (tools/make_icon.py, tools/make_splash.py), each on
## transparency in its own SubViewport, as <out>/<name>.png:
##   spirit       the water summon, evenly lit (the icon's ghostly spirit in the dusk sky)
##   shrub        a shrub (the icon's foreground silhouette)
##   dragon       the fire summon, dramatically lit: a warm key, a ruby rim (the splash's centrepiece)
##   <form>       the line's first forms that float in the splash's bubbles (crab_1, owl_1, ...)
## Run (needs a window, not --headless):
##   godot --path . --script res://tools/make_key_art.gd -- --out=C:/tmp/key_art [--only=spirit,shrub]

const Model = preload("res://scripts/gfx/beast_model.gd")
const VB = preload("res://scripts/gfx/voxel_beast.gd")

const BUBBLE_FORMS := ["crab_1", "owl_1", "berry_1", "bat_1", "tree_1", "frog_1", "cactus_1", "marmot_1", "beetle_1"]

var out := "user://key_art"
var only := []


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--only="):
			only = a.substr(7).split(",")
	_run.call_deferred()


func _want(n: String) -> bool:
	return only.is_empty() or n in only


func _run() -> void:
	root.size = Vector2i(320, 180)
	DirAccess.make_dir_recursive_absolute(out)
	if _want("spirit"):
		await _summon("water", "spirit", PI / 2.0 + 1.1, false, Vector3(0.0, -0.1, 1.0))
	if _want("dragon"):
		await _summon("fire", "dragon", PI / 2.0 + 0.55, true, Vector3(0.0, 0.05, 1.0))
	if _want("shrub"):
		await _shrub()
	for f in BUBBLE_FORMS:
		if _want(f):
			await _beast(f)
	quit()


func _stage(size: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_8X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	return vp


func _env(vp: SubViewport, ambient: Color, energy: float) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = energy
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.2
	env.ssao_enabled = true
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)


func _light(vp: SubViewport, col: Color, energy: float, rot: Vector3, shadow := false) -> void:
	var l := DirectionalLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.rotation_degrees = rot
	l.shadow_enabled = shadow
	l.shadow_blur = 2.0
	vp.add_child(l)


## A camera along `dir` from the box's centre, near enough that the box fills `fill` of the frame.
func _fit(vp: SubViewport, box: AABB, dir: Vector3, fov: float, fill: float) -> void:
	var cam := Camera3D.new()
	cam.fov = fov
	vp.add_child(cam)
	var r := box.size.length() * 0.5
	cam.position = box.get_center() + dir.normalized() * (r / tan(deg_to_rad(fov) * 0.5) / fill)
	cam.look_at(box.get_center(), Vector3.UP)
	cam.current = true


func _save(vp: SubViewport, n: String) -> void:
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out.path_join(n + ".png"))
	print("rendered ", n)
	vp.queue_free()
	await process_frame


func _summon(element: String, n: String, turn: float, drama: bool, dir: Vector3) -> void:
	var vp := _stage(Vector2i(2400, 2400))
	if drama:
		_env(vp, Color("#40303a"), 0.5)
		_light(vp, Color("#ffe0b8"), 1.7, Vector3(-28, -50, 0), true)
		_light(vp, Color("#ff4050"), 2.6, Vector3(-12, 165, 0))
		_light(vp, Color("#8ab8ff"), 0.8, Vector3(-8, 65, 0))
	else:
		_env(vp, Color("#ffffff"), 0.9)
		_light(vp, Color("#ffe8d0"), 1.0, Vector3(-35, -40, 0))
		_light(vp, Color("#ffffff"), 0.6, Vector3(-10, 140, 0))
	var mi := MeshInstance3D.new()
	mi.mesh = VB.summon_mesh(element, 3.0)
	mi.rotation.y = turn
	vp.add_child(mi)
	_fit(vp, mi.transform * mi.get_aabb(), dir, 26.0, 1.15)
	await _save(vp, n)


func _shrub() -> void:
	var vp := _stage(Vector2i(1200, 1200))
	_env(vp, Color("#ffffff"), 1.0)
	var mi := MeshInstance3D.new()
	mi.mesh = load("res://assets/nature/shrub_2.res")
	vp.add_child(mi)
	_fit(vp, mi.get_aabb(), Vector3(0.0, 0.05, 1.0), 26.0, 1.0)
	await _save(vp, "shrub")


## A beast as the game draws it, three-quarters on, softly lit with a pale rim.
func _beast(form: String) -> void:
	var vp := _stage(Vector2i(1400, 1400))
	_env(vp, Color("#fff4e8"), 0.65)
	_light(vp, Color("#fff0d8"), 1.25, Vector3(-42, -35, 0), true)
	_light(vp, Color("#d8ecff"), 0.7, Vector3(-20, 150, 0))
	_light(vp, Color("#ffffff"), 0.35, Vector3(-5, 20, 0))
	var r: Node3D = Model.rig({"form": form}, 1.0)
	r.rotation.y = -PI / 2.0 + 0.4
	vp.add_child(r)
	r.hold()
	_fit(vp, r.transform * Model.bounds(r), Vector3(0.0, 0.32, 1.0), 24.0, 0.98)
	await _save(vp, form)
