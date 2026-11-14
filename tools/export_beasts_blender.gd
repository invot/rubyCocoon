extends SceneTree
## Export the live roster, baking the game's procedural paint into portable textures.
const DB = preload("res://scripts/data/race_db.gd")
const Models = preload("res://scripts/gfx/beast_model.gd")
const Old = preload("res://scripts/gfx/voxel_beast.gd")
const Assets = preload("res://scripts/gfx/voxel_assets.gd")
const OUT = "res://build/beasts_blender/"
var bake_shader: Shader
var manifest: Array = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "intermediate"))
	var code: String = load("res://scripts/gfx/beast_toon.gdshader").code
	code = code.replace("render_mode diffuse_toon, specular_toon, cull_back;", "render_mode unshaded, cull_disabled;")
	# Godot's render-target convention already accounts for the vertical flip.
	# Base roster UV2 is exactly (object z, object y); regenerating it also
	# avoids xatlas discarding a custom attribute during its vertex remap.
	code = code.replace("face = UV2;", "face = VERTEX.zy;\n\tPOSITION = vec4(UV2 * 2.0 - 1.0, 0.0, 1.0);")
	code = code.replace("EMISSION = c * 0.35;", "EMISSION = vec3(0.0);")
	bake_shader = Shader.new()
	bake_shader.code = code
	var limit := 999
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--limit="):
			limit = int(arg.trim_prefix("--limit="))
	for id in DB.NORMAL_COUNT + DB.SPECIAL.size():
		if manifest.size() >= limit:
			break
		await export_one(id, false)
	for id in DB.NORMAL_COUNT:
		if manifest.size() >= limit:
			break
		await export_one(id, true)
	var f := FileAccess.open(OUT + "manifest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(manifest, "\t"))
	print("EXPORT_COMPLETE ", manifest.size())
	quit()

func export_one(id: int, ghost: bool) -> void:
	var title: String = DB.race_name(id)
	var stem := "%02d_%s%s" % [id, title.to_snake_case().replace(" ", "_"), "_ghost" if ghost else ""]
	var scene := Node3D.new()
	scene.name = title.replace(" ", "_") + ("_Ghost" if ghost else "")
	root.add_child(scene)
	var genes: Dictionary = DB.genes(id)
	genes["shade"] = 1.0 if ghost or id == 47 else 0.0
	var model: Node3D
	if Models.rigged(genes):
		model = Models.rig(genes)
		model.hold()
	elif genes.has("model"):
		model = Assets.instance(String(genes["model"]), 1.3 * float(genes["size"]))
	else:
		var mi := MeshInstance3D.new()
		mi.mesh = Old.mesh(genes)
		model = mi
	scene.add_child(model)
	for particles in model.find_children("*", "CPUParticles3D", true, false):
		particles.free()
	var meshes: Array = model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		meshes.append(model)
	var count := 0
	for mi: MeshInstance3D in meshes:
		if mi.material_override is ShaderMaterial:
			if not await bake(mi, stem + "_%d" % count):
				quit(1)
				return
		count += 1
	owners(scene, scene)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(scene, state)
	if err == OK:
		err = doc.write_to_filesystem(state, OUT + "intermediate/" + stem + ".glb")
	if err != OK:
		push_error("Export failed: " + stem)
		quit(1)
		return
	manifest.append({"race_id": id, "name": title, "ghost": ghost or id == 47, "file": stem + ".blend", "source": stem + ".glb", "rigged": Models.rigged(genes)})
	print("EXPORTED ", stem)
	scene.free()
	await process_frame

func owners(node: Node, owner_root: Node) -> void:
	for child in node.get_children():
		child.owner = owner_root
		owners(child, owner_root)

func bake(mi: MeshInstance3D, stem: String) -> bool:
	var original: ShaderMaterial = mi.material_override
	var mesh := ArrayMesh.new()
	for s in mi.mesh.get_surface_count():
		var a := mi.mesh.surface_get_arrays(s)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	var err := mesh.lightmap_unwrap(Transform3D.IDENTITY, 0.0015)
	if err != OK:
		push_error("UV unwrap failed: " + stem)
		return false
	var vp := SubViewport.new()
	vp.size = mesh.get_lightmap_size_hint().max(Vector2i(256, 256))
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var camera := Camera3D.new()
	cam_setup(camera)
	vp.add_child(camera)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0, 0, 0, 0)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	vp.add_child(env)
	var paint: ShaderMaterial = original.duplicate()
	paint.shader = bake_shader
	var flat := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		a[Mesh.ARRAY_BONES] = null
		a[Mesh.ARRAY_WEIGHTS] = null
		flat.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	var canvas := MeshInstance3D.new()
	canvas.mesh = flat
	canvas.material_override = paint
	canvas.extra_cull_margin = 100.0
	vp.add_child(canvas)
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	# Extend chart colours into the transparent gutter for clean filtered edges.
	img.fix_alpha_edges()
	var path := OUT + "intermediate/" + stem + ".png"
	img.save_png(path)
	var tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 0.85
	mat.resource_name = stem + "_paint"
	if float(original.get_shader_parameter("ghost")) > 0.5:
		mat.emission_enabled = true
		mat.emission = Color.WHITE
		mat.emission_texture = tex
		mat.emission_energy_multiplier = 0.35
	var portable := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		a[Mesh.ARRAY_TEX_UV] = a[Mesh.ARRAY_TEX_UV2]
		a[Mesh.ARRAY_TEX_UV2] = null
		a[Mesh.ARRAY_COLOR] = null
		a[Mesh.ARRAY_CUSTOM0] = null
		a[Mesh.ARRAY_TANGENT] = null
		portable.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		portable.surface_set_material(s, mat)
	mi.mesh = portable
	mi.material_override = null
	vp.free()
	return true

func cam_setup(camera: Camera3D) -> void:
	camera.position = Vector3(0, 0, 4)
	camera.current = true

