extends RefCounted
## Step 009b prototype: the shader combinations the Compatibility renderer compiles on first sight, for the title
## screen to compile ahead of time (scripts/gfx/shader_precompile.gd).
##   --scene=shader-manifest [--maps=route1,caccoon] [--rooms=1] [--out=res://assets/shaders/compat_warmup.scn]
## Builds every town and road (and, with --rooms=1, every interior floor) headless, then records each distinct
## (lighting set-up, material shader, instance kind, shadow casting) once. Materials are copied with every texture
## swapped for one tiny placeholder: the compiled program depends on which shader and features a material uses,
## not on the images in it. The output is a scene with one branch per lighting set-up; nothing is rendered here.
const Beasts = preload("res://scripts/core/beasts.gd")
const MapLoader = preload("res://scripts/world/map_loader.gd")
const WorldDB = preload("res://scripts/data/world_db.gd")
const VT = preload("res://scripts/gfx/voxel_textures.gd")
const VoxelAssets = preload("res://scripts/gfx/voxel_assets.gd")

var _placeholder: ImageTexture
var _configs := {}  # signature -> {"env", "sun", "omni", "spot", "entries": {sig: entry}, "maps": []}
var _skipped := {}
var _mesh_counts := {"geometry": 0}


func run(main, opts: Dictionary) -> void:
	UI.auto = true
	for flag in ["intro_done", "tutorial_done", "ritual_done", "opening_seen"]:
		GameState.set_flag(flag)
	GameState.party = [Beasts.create(0, 10)]
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.8, 0.8, 0.8))
	_placeholder = ImageTexture.create_from_image(img)
	_placeholder.resource_name = "warmup_placeholder"
	var ids: Array = []
	if opts.has("maps"):
		ids = Array(String(opts["maps"]).split(","))
	else:
		ids = WorldDB.TOWNS.keys() + WorldDB.ROUTES.keys()
		if opts.get("rooms", "1") == "1":
			var rooms := []
			for id in ids:
				for b in MapLoader.load_map(id, GameState.flags)["buildings"]:
					for f in range(1, MapLoader.room_set(b).size() + 1):
						rooms.append(MapLoader.floor_id(b["interior"], f))
			ids += rooms
	var started := Time.get_ticks_msec()
	for id in ids:
		var interior: bool = MapLoader.load_map(id, GameState.flags)["kind"] == "interior"
		await main._load_world(id, "entry" if interior else "center")
		_collect(id, main.world)
	var out := String(opts.get("out", "res://assets/shaders/compat_warmup.scn"))
	var summary := _save(out)
	summary["maps"] = ids.size()
	summary["seconds"] = (Time.get_ticks_msec() - started) / 1000.0
	summary["skipped_classes"] = _skipped
	print("SHADER MANIFEST ", JSON.stringify(summary))
	var report := String(opts.get("report", ""))
	if report != "":
		DirAccess.make_dir_recursive_absolute(report.get_base_dir())
		var f := FileAccess.open(report, FileAccess.WRITE)
		f.store_string(JSON.stringify(summary, "\t"))
		f.close()
	print("SHADER MANIFEST DONE")


func _collect(id: String, world: Node3D) -> void:
	var env: Environment = null
	var sun: DirectionalLight3D = null
	var omni: OmniLight3D = null
	var spot: SpotLight3D = null
	for we in world.find_children("*", "WorldEnvironment", true, false):
		env = we.environment
		break
	for light in world.find_children("*", "Light3D", true, false):
		if light is DirectionalLight3D and sun == null:
			sun = light
		elif light is OmniLight3D and (omni == null or (light.shadow_enabled and not omni.shadow_enabled)):
			omni = light
		elif light is SpotLight3D and spot == null:
			spot = light
	var sig := str([world.interior, _env_sig(env), _light_sig(sun), _light_sig(omni), _light_sig(spot)])
	if not _configs.has(sig):
		_configs[sig] = {"env": env, "sun": sun.duplicate() if sun else null, "omni": omni.duplicate() if omni else null,
			"spot": spot.duplicate() if spot else null, "entries": {}, "maps": []}
	var config: Dictionary = _configs[sig]
	config["maps"].append(id)
	for gi in world.find_children("*", "GeometryInstance3D", true, false):
		_mesh_counts["geometry"] += 1
		var kind := ""
		var mesh: Mesh = null
		if gi is MeshInstance3D:
			kind = "mesh"
			mesh = gi.mesh
		elif gi is MultiMeshInstance3D and gi.multimesh != null:
			var mm: MultiMesh = gi.multimesh
			kind = "multimesh:%d:%d:%d" % [int(mm.use_colors), int(mm.use_custom_data), mm.transform_format]
			mesh = mm.mesh
		elif gi is CPUParticles3D:
			kind = "multimesh:1:1:1"
			mesh = gi.mesh
		elif gi is Label3D:
			# signs: drawn with the engine's shared 2D-in-3D materials, chosen by these properties
			var lsig := ["label", gi.billboard, gi.shaded, gi.double_sided, gi.no_depth_test, gi.fixed_size, gi.alpha_cut,
				gi.texture_filter, gi.alpha_antialiasing_mode, gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF]
			if not config["entries"].has(str(lsig)):
				config["entries"][str(lsig)] = {"label": lsig}
			continue
		else:
			_skipped[gi.get_class()] = _skipped.get(gi.get_class(), 0) + 1
			continue
		if mesh == null:
			continue
		var shadow: bool = gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mats := []
		for s in mesh.get_surface_count():
			var m: Material = gi.material_override
			if m == null and gi is MeshInstance3D:
				m = gi.get_surface_override_material(s)
			if m == null:
				m = mesh.surface_get_material(s)
			mats.append(m)
		if gi.material_overlay != null:
			mats.append(gi.material_overlay)
		for m in mats:
			if m == null:
				continue
			var msig := _mat_sig(m)
			if msig == "":
				continue
			var key := str([msig, kind, shadow])
			if not config["entries"].has(key):
				config["entries"][key] = {"material": m, "kind": kind, "shadow": shadow}


func _env_sig(env: Environment) -> String:
	if env == null:
		return "none"
	var sky := ""
	if env.sky != null and env.sky.sky_material != null:
		sky = _mat_sig(env.sky.sky_material)
	return str([env.background_mode, env.ambient_light_source, env.reflected_light_source, env.fog_enabled, env.fog_mode,
		env.volumetric_fog_enabled, env.glow_enabled, env.tonemap_mode, env.adjustment_enabled,
		env.adjustment_color_correction != null, env.ssao_enabled, env.sdfgi_enabled, sky])


func _light_sig(light: Light3D) -> String:
	if light == null:
		return "none"
	var s := [light.get_class(), light.shadow_enabled, light.light_bake_mode]
	if light is DirectionalLight3D:
		s += [light.directional_shadow_mode, light.directional_shadow_blend_splits]
	elif light is OmniLight3D:
		s += [light.omni_shadow_mode]
	return str(s)


func _mat_sig(m: Material) -> String:
	var s := ""
	if m is BaseMaterial3D:
		s = VT._kind_of(m)
	elif m is ShaderMaterial and m.shader != null:
		s = m.shader.resource_path if m.shader.resource_path != "" else "code:%d" % m.shader.code.hash()
	else:
		return ""
	if m.next_pass != null:
		s += "+" + _mat_sig(m.next_pass)
	return s


## A copy that compiles to the same program, its textures swapped for the placeholder.
func _sanitized(m: Material) -> Material:
	var c: Material = m.duplicate()
	if c is BaseMaterial3D:
		for i in BaseMaterial3D.TEXTURE_MAX:
			if c.get_texture(i) != null:
				c.set_texture(i, _placeholder)
	elif c is ShaderMaterial:
		if c.shader.resource_path == "":
			# Built in code: the builder's own Shader object must be reused at run time, or the title would compile a
			# separate copy of the same program.
			if c.shader == VoxelAssets.two_sided_foliage():
				c.set_meta("warmup_shader", "two_sided_foliage")
		for u in c.shader.get_shader_uniform_list():
			var v = c.get_shader_parameter(u["name"])
			if v is Texture:
				c.set_shader_parameter(u["name"], _placeholder_like(v))
	if m.next_pass != null:
		c.next_pass = _sanitized(m.next_pass)
	return c


## A placeholder for `t`: the shared tiny 2D texture, or nothing for texture arrays, cubemaps and 3D textures (headless
## runs can't save their layers; an unbound sampler compiles the same program and draws the shader's default).
func _placeholder_like(t: Texture) -> Texture:
	return _placeholder if t is Texture2D else null


func _save(path: String) -> Dictionary:
	var root := Node3D.new()
	root.name = "CompatWarmup"
	var tri := _triangle()
	var summary := {"configs": [], "entries": 0, "geometry_scanned": _mesh_counts["geometry"]}
	var cached := {}
	var index := 0
	# the lighting set-ups most maps use first, so an early menu choice still leaves them compiled
	var order: Array = _configs.keys()
	order.sort_custom(func(a, b): return _configs[a]["maps"].size() > _configs[b]["maps"].size())
	for sig in order:
		var config: Dictionary = _configs[sig]
		var branch := Node3D.new()
		branch.name = "Config%d" % index
		index += 1
		root.add_child(branch)
		branch.owner = root
		if config["env"] != null:
			var we := WorldEnvironment.new()
			we.name = "Environment"
			var env: Environment = config["env"].duplicate()
			if env.sky != null:
				env.sky = env.sky.duplicate()
				if env.sky.sky_material != null:
					env.sky.sky_material = _sanitized(env.sky.sky_material)
			we.environment = env
			branch.add_child(we)
			we.owner = root
		var lights := []
		for key in ["sun", "omni", "spot"]:
			var light: Light3D = config[key]
			if light == null:
				continue
			light.name = key.capitalize()
			branch.add_child(light)
			light.owner = root
			lights.append(key)
		# Specks: drawn once each, in front of the precompile camera. With a local light, every speck also has a twin
		# outside its range, so both the lit and the unlit programs compile.
		var groups := ["Lit", "Unlit"] if config["omni"] != null or config["spot"] != null else ["Unlit"]
		for g in groups.size():
			var group := Node3D.new()
			group.name = groups[g]
			group.position = Vector3(-1.2 if groups[g] == "Lit" else 1.2, 0, -4.0)
			branch.add_child(group)
			group.owner = root
			var n := 0
			for key in config["entries"]:
				var e: Dictionary = config["entries"][key]
				if e.has("label"):
					var l: Array = e["label"]
					var label := Label3D.new()
					label.text = "a"
					label.pixel_size = 0.002
					label.billboard = l[1]
					label.shaded = l[2]
					label.double_sided = l[3]
					label.no_depth_test = l[4]
					label.fixed_size = l[5]
					label.alpha_cut = l[6]
					label.texture_filter = l[7]
					label.alpha_antialiasing_mode = l[8]
					label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if l[9] else 						GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					label.position = Vector3((n % 20) * 0.05 - 0.5, (n / 20) * 0.05 - 0.5, 0)
					label.visible = false
					group.add_child(label)
					label.owner = root
					n += 1
					continue
				var mat: Material = cached.get(e["material"])
				if mat == null:
					mat = _sanitized(e["material"])
					cached[e["material"]] = mat
				var speck: GeometryInstance3D
				if e["kind"] == "mesh":
					var mi := MeshInstance3D.new()
					mi.mesh = tri
					speck = mi
				else:
					var parts: PackedStringArray = String(e["kind"]).split(":")
					var mm := MultiMesh.new()
					mm.transform_format = int(parts[3]) as MultiMesh.TransformFormat
					mm.use_colors = parts[1] == "1"
					mm.use_custom_data = parts[2] == "1"
					mm.mesh = tri
					mm.instance_count = 1
					var mmi := MultiMeshInstance3D.new()
					mmi.multimesh = mm
					speck = mmi
				speck.material_override = mat
				speck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if e["shadow"] else \
					GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				speck.position = Vector3((n % 20) * 0.05 - 0.5, (n / 20) * 0.05 - 0.5, 0)
				speck.visible = false
				group.add_child(speck)
				speck.owner = root
				n += 1
		if groups.size() > 1:
			# the local light sits on the lit group; the unlit group is well outside its range
			for key in ["omni", "spot"]:
				var light: Light3D = branch.get_node_or_null(key.capitalize())
				if light != null:
					light.transform = Transform3D(Basis.IDENTITY, Vector3(-1.2, 0, -3.2))
					if light is OmniLight3D:
						light.omni_range = 1.5
					else:
						light.spot_range = 1.5
						light.spot_angle = 80.0
		summary["entries"] += config["entries"].size()
		summary["configs"].append({"name": branch.name, "entries": config["entries"].size(), "lights": lights,
			"groups": groups, "maps": config["maps"].size(), "example_maps": config["maps"].slice(0, 4)})
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, path, ResourceSaver.FLAG_COMPRESS)
	summary["save_error"] = err
	summary["path"] = path
	root.free()
	return summary


## One small triangle with every vertex attribute a material might read (normal, tangent, UV, UV2, colour).
func _triangle() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0, 0, 0), Vector3(0.04, 0, 0), Vector3(0, 0.04, 0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_TANGENT] = PackedFloat32Array([1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)])
	arrays[Mesh.ARRAY_TEX_UV2] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)])
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.resource_name = "warmup_triangle"
	return mesh
