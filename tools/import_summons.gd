extends SceneTree
## Bakes the five summon beasts from new beasts/{air,water,earth,fire,ghost} (OBJ pieces with loose PBR textures)
## into assets/summons/<element>.res: one ArrayMesh per summon, decimated for phones, standing on y = 0 with +y up and
## facing +z, its longest side one unit long, with its textures shrunk to 512 px and baked in.
## Which texture belongs to which piece was worked out by eye (tools/summons/_view.gd); the packs came without
## materials. The water dragon has no colour map at all, so its colours are painted per vertex over its AO map.
## Run:  godot --headless --path . --script res://tools/import_summons.gd [-- --only=air] [--preview=<png>]
## (--preview renders the baked summons side by side from the front and from above; needs a window, not --headless).

const OBJ = preload("res://tools/townfolk/obj.gd")
const SRC := "res://new beasts/"
const OUT := "res://assets/summons/"
const TEX_SIZE := 512

## up / fwd: which of the model's own axes ("x", "-y", ...) point up and forward; the bake turns them to +y and +z.
## groups: pieces that share a texture. color / emission / alpha are file names in the summon's folder (the emission
## map glows in its own colours, times glow_energy); tris is the triangle budget for the group; blend "add" for smoke cards;
## paint: per-vertex colours (multiplied with the color texture). coil: the model is posed dead straight (the sky
## serpent), so its spine is bent along a weaving, rising curve (_coil) to look like it's flying.
const SUMMONS := {
	"air": {"up": "z", "fwd": "-y", "coil": true, "groups": [
		{"pieces": [1, 2, 3], "color": "wire_143224087_Base_Color.png", "emission": "wire_143224087_Emissive.png", "glow_energy": 4.0, "tris": 14000},
		{"pieces": [4], "color": "wire_134006006_Base_Color.png", "tris": 2400},
		{"pieces": [0], "color": "wire_006134006_Base_Color.png", "emission": "wire_006134006_Emissive.png", "glow_energy": 3.0, "tris": 900},
	]},
	"water": {"up": "y", "fwd": "z", "groups": [
		{"pieces": [2], "color": "Dragon_Mixed_AO.png", "paint": "water", "tris": 14000},
		{"pieces": [0, 1], "color": "Dragon_Mixed_AO.png", "paint": "water_horns", "tris": 5000},
		{"pieces": [3], "color": "Dragon_Mixed_AO.png", "paint": "teeth", "tris": 300},
	]},
	"earth": {"up": "y", "fwd": "z", "groups": [
		{"pieces": [0], "color": "Old_God_Dragon_LP_Base_Body_BaseColor.png", "emission": "Old_God_Dragon_LP_Base_Body_Emissive.png", "glow_energy": 3.0, "tris": 12000},
		{"pieces": [1], "color": "Old_God_Dragon_LP_Base_Feather_BaseColor.png", "tris": 10000},
		{"pieces": [2], "color": "Old_God_Dragon_LP_Base_Eyes_BaseColor.png", "emission": "Old_God_Dragon_LP_Base_Eyes_Emissive.png", "glow_energy": 2.0, "tris": 1200},
	]},
	"fire": {"up": "z", "fwd": "-y", "groups": [
		{"pieces": [0], "color": "color.png", "alpha": "alpha.png", "tris": 10001},
	]},
	"ghost": {"up": "y", "fwd": "z", "groups": [
		{"pieces": [0, 1, 2, 3, 4], "color": "shoulders_color_copy.png", "emission": "shoulders_selfillummask_copy2.png", "glow_energy": 6.0, "tris": 10500},
		{"pieces": [5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19], "color": "cigarette-smoking-hypnosis.png", "blend": "add", "tint": "#6a3a9a59", "tris": 400},
	]},
}

var args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("preview"):
		await _preview(String(args["preview"]))
		quit()
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for el in SUMMONS:
		if args.has("only") and String(args["only"]) != el:
			continue
		var t0 := Time.get_ticks_msec()
		var mesh := _bake(el, SUMMONS[el])
		var err := ResourceSaver.save(mesh, OUT + el + ".res", ResourceSaver.FLAG_COMPRESS)
		var tris := 0
		for s in mesh.get_surface_count():
			tris += mesh.surface_get_array_index_len(s) / 3
		print("%-6s %6d triangles, %d surfaces -> %s (%s) in %.1f s" % [el, tris, mesh.get_surface_count(), OUT + el + ".res",
			error_string(err), (Time.get_ticks_msec() - t0) / 1000.0])
	quit()


func _bake(el: String, cfg: Dictionary) -> ArrayMesh:
	var dir := SRC + el + "/"
	var up := _axis(String(cfg["up"]))
	var fwd := _axis(String(cfg["fwd"]))
	var basis := Basis(up.cross(fwd), up, fwd).transposed()
	var surfaces := []
	var box := AABB()
	var first := true
	for g in cfg["groups"]:
		var d := _gather(dir, g["pieces"], basis, String(g.get("paint", "")))
		var arrays := _decimate(d, int(g["tris"]))
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for p in verts:
			if first:
				box = AABB(p, Vector3.ZERO)
				first = false
			box = box.expand(p)
		surfaces.append([arrays, _material(dir, g)])
	if cfg.get("coil", false):
		_coil(surfaces, box)
		first = true
		for sf in surfaces:
			for p in (sf[0][Mesh.ARRAY_VERTEX] as PackedVector3Array):
				if first:
					box = AABB(p, Vector3.ZERO)
					first = false
				box = box.expand(p)
	# stand it on y = 0, centred on x and z, longest side one unit
	var s := 1.0 / box.get_longest_axis_size()
	var off := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var mesh := ArrayMesh.new()
	for sf in surfaces:
		var arrays: Array = sf[0]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in verts.size():
			verts[i] = (verts[i] - off) * s
		arrays[Mesh.ARRAY_VERTEX] = verts
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, sf[1])
	return mesh


## The pieces as one indexed surface: corners sharing position, UV and normal become one vertex.
func _gather(dir: String, pieces: Array, basis: Basis, paint: String) -> Dictionary:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var has_normals := true
	for n in pieces:
		var d := OBJ.read(int(n), dir)
		if d.is_empty():
			push_warning("%smodel_%d.obj missing" % [dir, n])
			continue
		var v: PackedVector3Array = d["v"]
		var uv: PackedVector2Array = d["uv"]
		var nv: PackedVector3Array = d["n"]
		var tri: PackedInt32Array = d["tri"]
		var ntri: PackedInt32Array = d["ntri"]
		if nv.is_empty():
			has_normals = false
		var seen := {}
		for t in range(0, tri.size(), 6):
			for k in [0, 2, 1]:
				var vi := tri[t + k * 2]
				var ti := tri[t + k * 2 + 1]
				var ni := ntri[t / 2 + k] if not nv.is_empty() else -1
				var key := Vector3i(vi, ti, ni)
				var at: int = seen.get(key, -1)
				if at < 0:
					at = verts.size()
					seen[key] = at
					verts.append(basis * v[vi])
					var q: Vector2 = uv[ti] if ti >= 0 and ti < uv.size() else Vector2(0.5, 0.5)
					uvs.append(Vector2(q.x, 1.0 - q.y))
					norms.append((basis * nv[ni]).normalized() if ni >= 0 and ni < nv.size() else Vector3.UP)
				idx.append(at)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	if has_normals:
		arrays[Mesh.ARRAY_NORMAL] = norms
	else:
		var st := SurfaceTool.new()
		st.create_from_arrays(arrays)
		st.generate_normals()
		arrays = st.commit_to_arrays()
	if paint != "":
		arrays[Mesh.ARRAY_COLOR] = _paint(paint, arrays[Mesh.ARRAY_VERTEX])
	return {"arrays": arrays}


## Cuts a surface down to about `tris` triangles with Godot's mesh optimizer (ImporterMesh LODs), keeping only the
## vertices the chosen level still uses.
func _decimate(d: Dictionary, tris: int) -> Array:
	var arrays: Array = d["arrays"]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if idx.size() / 3 <= tris:
		return arrays
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	im.generate_lods(25.0, 60.0, [])
	var src := im.get_surface_arrays(0)
	var best: PackedInt32Array = src[Mesh.ARRAY_INDEX]
	for l in im.get_surface_lod_count(0):
		var li := im.get_surface_lod_indices(0, l)
		if li.size() / 3 >= tris * 0.85 and li.size() < best.size():
			best = li
	# keep only the vertices still in use
	var remap := {}
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	var nidx := PackedInt32Array()
	nidx.resize(best.size())
	var order := PackedInt32Array()
	for i in best.size():
		var o := best[i]
		var at: int = remap.get(o, -1)
		if at < 0:
			at = order.size()
			remap[o] = at
			order.append(o)
		nidx[i] = at
	for a in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_COLOR]:
		if src[a] == null:
			continue
		var from = src[a]
		var to = from.duplicate()
		to.resize(order.size())
		for i in order.size():
			to[i] = from[order[i]]
		out[a] = to
	out[Mesh.ARRAY_INDEX] = nidx
	return out


## Bends a model that lies straight along +z (head at +z) along a curve that weaves side to side and rises toward the
## head, keeping each vertex's offset from the spine (and turning its normal) in the curve's frame.
func _coil(surfaces: Array, box: AABB) -> void:
	var length := box.size.z
	var cx := box.get_center().x
	var cy := box.get_center().y
	# the curve, sampled by arc length
	var pts := PackedVector3Array()
	var acc := PackedFloat32Array()
	var n := 1200
	var total := 0.0
	for i in n + 1:
		var u := float(i) / n
		var p := Vector3(0.11 * sin(TAU * 1.6 * u), 0.2 * pow(u, 1.5) + 0.05 * sin(TAU * 1.1 * u + 1.0), 0.72 * u)
		if i > 0:
			total += p.distance_to(pts[i - 1])
		pts.append(p)
		acc.append(total)
	var k := length / total
	for sf in surfaces:
		var arrays: Array = sf[0]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		for vi in verts.size():
			var v := verts[vi]
			var along := clampf((v.z - box.position.z) / k, 0.0, total)
			var j := clampi(acc.bsearch(along), 1, n)
			var f := (along - acc[j - 1]) / maxf(0.000001, acc[j] - acc[j - 1])
			var c := pts[j - 1].lerp(pts[j], f) * k
			var t := (pts[j] - pts[j - 1]).normalized()
			var up := (Vector3.UP - t * Vector3.UP.dot(t)).normalized()
			var side := up.cross(t)
			verts[vi] = c + side * (v.x - cx) + up * (v.y - cy)
			if vi < norms.size():
				var nv := norms[vi]
				norms[vi] = (side * nv.x + up * nv.y + t * nv.z).normalized()
		arrays[Mesh.ARRAY_VERTEX] = verts
		if not norms.is_empty():
			arrays[Mesh.ARRAY_NORMAL] = norms


func _material(dir: String, g: Dictionary) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.roughness = 0.85
	m.albedo_texture = _texture(dir + String(g["color"]))
	if g.has("paint"):
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
	if g.has("alpha"):
		# the alpha map's brightness cuts holes (wing membranes)
		var col := _image(dir + String(g["color"]))
		var mask := _image(dir + String(g["alpha"]))
		mask.resize(col.get_width(), col.get_height(), Image.INTERPOLATE_BILINEAR)
		col.convert(Image.FORMAT_RGBA8)
		for y in col.get_height():
			for x in col.get_width():
				var c := col.get_pixel(x, y)
				c.a = mask.get_pixel(x, y).r
				col.set_pixel(x, y, c)
		m.albedo_texture = ImageTexture.create_from_image(col)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
	if g.has("emission"):
		# added to black, so only the map's own glowing spots light up
		m.emission_enabled = true
		m.emission = Color.BLACK
		m.emission_operator = BaseMaterial3D.EMISSION_OP_ADD
		m.emission_texture = _texture(dir + String(g["emission"]))
		m.emission_energy_multiplier = float(g.get("glow_energy", 1.0))
	if String(g.get("blend", "")) == "add":
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(String(g.get("tint", "#ffffff")))
		m.no_depth_test = false
		m.disable_receive_shadows = true
	return m


func _axis(a: String) -> Vector3:
	var v: Vector3 = {"x": Vector3.RIGHT, "y": Vector3.UP, "z": Vector3.BACK}[a.trim_prefix("-")]
	return -v if a.begins_with("-") else v


func _image(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	var w := img.get_width()
	var h := img.get_height()
	var k := float(TEX_SIZE) / maxf(w, h)
	if k < 1.0:
		img.resize(maxi(8, int(w * k)), maxi(8, int(h * k)), Image.INTERPOLATE_LANCZOS)
	return img


func _texture(path: String) -> ImageTexture:
	var img := _image(path)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Per-vertex colours for the water dragon, which only came with an AO map: a deep-blue body, wing membranes fading
## to bright blue with orange bands like the reference picture, purple horns and spines, white teeth.
func _paint(kind: String, verts: PackedVector3Array) -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(verts.size())
	var box := AABB(verts[0], Vector3.ZERO)
	for p in verts:
		box = box.expand(p)
	var c := box.get_center()
	for i in verts.size():
		var p := verts[i]
		match kind:
			"water":
				# the further out sideways, the more of a wing membrane it is
				var side := absf(p.x - c.x) / maxf(0.001, box.size.x * 0.5)
				var body := Color("#18307a")
				var wing := Color("#1e6ae0").lerp(Color("#3ad0ff"), clampf((side - 0.4) * 1.6, 0.0, 1.0))
				var band := 0.5 + 0.5 * sin(side * 24.0 + (p.y - c.y) * 4.0)
				wing = wing.lerp(Color("#ff7a12"), smoothstep(0.6, 0.85, band) * clampf((side - 0.25) * 3.0, 0.0, 1.0))
				wing = wing.lerp(Color("#ffb020"), clampf((side - 0.9) * 8.0, 0.0, 1.0))
				out[i] = body.lerp(wing, smoothstep(0.16, 0.34, side))
			"water_horns":
				out[i] = Color("#9a3ad8").lerp(Color("#ff9a1a"), clampf((p.y - box.position.y) / maxf(0.001, box.size.y), 0.0, 1.0))
			_:
				out[i] = Color("#f4f0e8")
	return out


## Renders the baked summons side by side: from the front (top row), the right side and above (bottom row).
func _preview(path: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(2000, 1200)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var i := 0
	for el in SUMMONS:
		var mesh: Mesh = load(OUT + el + ".res")
		var c := mesh.get_aabb().get_center()
		for row in 3:
			var piv := Node3D.new()
			piv.position = Vector3(i * 1.2, -row * 1.2, 0)
			vp.add_child(piv)
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.position = -c
			piv.add_child(mi)
			if row == 1:
				piv.rotation.y = -PI / 2.0
			elif row == 2:
				piv.rotation.x = PI / 2.0
		var l := Label3D.new()
		l.text = el
		l.font_size = 48
		l.pixel_size = 0.004
		l.position = Vector3(i * 1.2, 0.62, 0)
		vp.add_child(l)
		i += 1
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.36, 0.38, 0.44)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 3.7
	cam.position = Vector3(2.4, -1.15, 10)
	vp.add_child(cam)
	cam.current = true
	for k in 8:
		await process_frame
	vp.get_texture().get_image().save_png(path)
