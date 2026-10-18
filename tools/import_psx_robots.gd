extends SceneTree
## Bakes the Gearhart robots from the PSX robot packs in psx/Characters into assets/psx/robots/<key>.res.
##   godot --headless --path . --script res://tools/import_psx_robots.gd [-- key1 key2 ...]
##
## Each robot becomes one ArrayMesh in the game's beast space: facing +x, standing on y = 0, centred on x/z and
## 1 unit tall (battle.gd and world.gd scale it to its size). The packs model them in a T-pose without a rig, so the
## arms are swung down to the sides. Its colour texture is cut to 128 px with sharp sampling like the beasts; a
## glow map lights its eyes and vents. Which race wears which robot: RaceDB.ROBOT_MODELS. Menu icons:
## tools/make_beast_icons.gd. Credits: CREDITS.md.

const OUT := "res://assets/psx/robots/"
const RR := "Characters/Retro Robots without Rig - PSX Asset (Free) (Bricchi Games)/Retro Robots/"
const RG := "Characters/Low poly Robot guy (CokeEnthusiast)/"

## key: [model under psx/, options]
## options: node = the mesh to take from a file holding several, tex = colour texture, glow = glow map,
##          glow_k = how bright it glows, arms = [where the shoulder is (fraction of the half width), degrees to
##          swing the arms down]; the packs' robots face +z, and are turned to face +x
const ROBOTS := {
	# the wind-up key on its back: Clockwork Sentry
	"robot_clockwork": [RR + "Robots.fbx", {"node": "Robot 3", "tex": RR + "Textures/Robot 3/Base Texture 256x256.png",
		"glow": RR + "Textures/Robot 3/Emissive map 256x256.png", "glow_k": 0.55, "arms": [0.34, 62.0]}],
	# a boiler on legs: Steam Mecha
	"robot_steam": [RR + "Robots.fbx", {"node": "Robot 2", "tex": RR + "Textures/Robot 2/Base Texture 256x256.png",
		"glow": RR + "Textures/Robot 2/Emissive map 256x256.png", "glow_k": 1.4}],
	# broad iron shoulders: Iron Golem
	"robot_golem": [RR + "Robots.fbx", {"node": "Robot 1", "tex": RR + "Textures/Robot 1/Base Texture 256x256.png",
		"glow": RR + "Textures/Robot 1/Emissive map 256x256.png", "glow_k": 1.4, "arms": [0.32, 64.0]}],
	# a squat, heavy-footed box: Tank Walker
	"robot_walker": [RG + "robot.obj", {"tex": RG + "robot.bmp"}],
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var only := OS.get_cmdline_user_args()
	var src := ProjectSettings.globalize_path("res://psx/")
	var scenes := {}
	for key in ROBOTS:
		if not only.is_empty() and not only.has(key):
			continue
		var e: Array = ROBOTS[key]
		var file: String = src + String(e[0])
		var opt: Dictionary = e[1]
		var parts := []
		if file.get_extension().to_lower() == "obj":
			parts = _obj_parts(file)
		else:
			if not scenes.has(file):
				scenes[file] = _load_fbx(file)
			var sc: Node = scenes[file]
			if sc == null:
				push_error("could not load " + file)
				continue
			for mi in sc.find_children("*", "MeshInstance3D", true, false):
				if String(mi.name) == String(opt.get("node", mi.name)):
					parts.append_array(_mesh_parts(mi, sc))
		if parts.is_empty():
			push_error("nothing to bake for " + key)
			continue
		var mesh := _bake(parts, opt, src)
		var err := ResourceSaver.save(mesh, OUT + key + ".res", ResourceSaver.FLAG_COMPRESS)
		print("  %-16s %5d tris  %s  %s" % [key, _tris(mesh), mesh.get_aabb().size, "ok" if err == OK else "SAVE FAILED"])
	for f in scenes:
		if scenes[f] != null:
			(scenes[f] as Node).free()
	quit()


func _load_fbx(path: String) -> Node:
	var d := FBXDocument.new()
	var st := FBXState.new()
	if d.append_from_file(path, st) != OK:
		return null
	return d.generate_scene(st)


## The mesh's surfaces with the scene's transforms applied: [arrays, ...].
func _mesh_parts(inst: MeshInstance3D, top: Node) -> Array:
	var xf := _xf_to(inst, top)
	var out := []
	for s in inst.mesh.get_surface_count():
		var arrays := inst.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in verts.size():
			verts[i] = xf * verts[i]
		arrays[Mesh.ARRAY_VERTEX] = verts
		if arrays[Mesh.ARRAY_NORMAL] != null:
			var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in ns.size():
				ns[i] = (xf.basis * ns[i]).normalized()
			arrays[Mesh.ARRAY_NORMAL] = ns
		out.append(arrays)
	return out


## An OBJ's triangles (one surface; the robot packs use one material per model).
func _obj_parts(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var vs: Array[Vector3] = []
	var vts: Array[Vector2] = []
	var vns: Array[Vector3] = []
	var pv := PackedVector3Array()
	var pn := PackedVector3Array()
	var puv := PackedVector2Array()
	while not f.eof_reached():
		var bits := f.get_line().strip_edges().split(" ", false)
		if bits.is_empty():
			continue
		match bits[0]:
			"v":
				vs.append(Vector3(float(bits[1]), float(bits[2]), float(bits[3])))
			"vt":
				vts.append(Vector2(float(bits[1]), 1.0 - float(bits[2])))
			"vn":
				vns.append(Vector3(float(bits[1]), float(bits[2]), float(bits[3])))
			"f":
				var corners := []
				for k in range(1, bits.size()):
					corners.append(bits[k].split("/"))
				# OBJ winds counter-clockwise; Godot's front faces are clockwise
				for k in range(1, corners.size() - 1):
					for c in [corners[0], corners[k + 1], corners[k]]:
						pv.append(vs[int(c[0]) - 1])
						puv.append(vts[int(c[1]) - 1] if c.size() > 1 and c[1] != "" else Vector2.ZERO)
						pn.append(vns[int(c[2]) - 1] if c.size() > 2 and c[2] != "" else Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pv
	arrays[Mesh.ARRAY_NORMAL] = pn
	arrays[Mesh.ARRAY_TEX_UV] = puv
	return [arrays]


## Arms down, turned to face +x, centred, standing on y = 0 and 1 unit tall, with the robot's PSX material.
func _bake(parts: Array, opt: Dictionary, src: String) -> ArrayMesh:
	var bb := _bounds(parts)
	if opt.has("arms"):
		_arms_down(parts, bb, float(opt["arms"][0]), float(opt["arms"][1]))
		bb = _bounds(parts)
	# +z (the packs' front) to +x
	var basis := Basis(Vector3.UP, PI / 2.0)
	var k := 1.0 / maxf(0.0001, bb.size.y)
	var base := Vector3(bb.get_center().x, bb.position.y, bb.get_center().z)
	var mat := _material(src + String(opt.get("tex", "")), src + String(opt.get("glow", "")), float(opt.get("glow_k", 1.4)))
	var out := ArrayMesh.new()
	for arrays in parts:
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in verts.size():
			verts[i] = basis * ((verts[i] - base) * k)
		arrays[Mesh.ARRAY_VERTEX] = verts
		if arrays[Mesh.ARRAY_NORMAL] != null:
			var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in ns.size():
				ns[i] = basis * ns[i]
			arrays[Mesh.ARRAY_NORMAL] = ns
		arrays[Mesh.ARRAY_TANGENT] = null
		arrays[Mesh.ARRAY_BONES] = null
		arrays[Mesh.ARRAY_WEIGHTS] = null
		arrays[Mesh.ARRAY_COLOR] = null
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(out.get_surface_count() - 1, mat)
	return out


func _bounds(parts: Array) -> AABB:
	var bb := AABB()
	var first := true
	for arrays in parts:
		for v in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			bb = AABB(v, Vector3.ZERO) if first else bb.expand(v)
			first = false
	return bb


## Swings a T-pose's arms down to the robot's sides. Everything further out than the shoulder (`shoulder` of the
## half width from the middle) and above the hips turns about the shoulder, the turn growing over the first stretch
## past it so the shoulder bends rather than tears.
func _arms_down(parts: Array, bb: AABB, shoulder: float, deg: float) -> void:
	var cx := bb.get_center().x
	var half := bb.size.x * 0.5
	var sx := half * shoulder
	var hips := bb.position.y + bb.size.y * 0.45
	# the shoulder's height: the middle of the arms
	var sum := 0.0
	var n := 0
	for arrays in parts:
		for v in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			if absf(v.x - cx) > half * 0.6:
				sum += v.y
				n += 1
	var sy := sum / maxf(1.0, float(n))
	var bend := half * 0.12
	for arrays in parts:
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var ns = arrays[Mesh.ARRAY_NORMAL]
		for i in verts.size():
			var v := verts[i]
			var dx := v.x - cx
			if absf(dx) <= sx or v.y < hips:
				continue
			var w := clampf((absf(dx) - sx) / bend, 0.0, 1.0)
			var a := deg_to_rad(deg) * w * (-1.0 if dx > 0.0 else 1.0)
			var pivot := Vector3(cx + signf(dx) * sx, sy, v.z)
			var rot := Basis(Vector3.BACK, a)
			verts[i] = pivot + rot * (v - pivot)
			if ns != null:
				ns[i] = rot * (ns[i] as Vector3)
		arrays[Mesh.ARRAY_VERTEX] = verts
		if ns != null:
			arrays[Mesh.ARRAY_NORMAL] = ns


## The robot's skin: its colour texture at 128 px, sharp, with the glow map lit on top.
func _material(tex: String, glow: String, glow_k: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.roughness = 0.85
	m.metallic_specular = 0.45
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.albedo_texture = _small(tex)
	var g := _small(glow)
	if g != null:
		m.emission_enabled = true
		# the glow map is added to the emission colour: black, so only the map glows
		m.emission = Color.BLACK
		m.emission_texture = g
		m.emission_energy_multiplier = glow_k
	return m


func _small(path: String) -> Texture2D:
	if path.get_extension() == "" or not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	img.convert(Image.FORMAT_RGBA8)
	if maxi(img.get_width(), img.get_height()) > 128:
		img.resize(128, 128, Image.INTERPOLATE_LANCZOS)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _xf_to(node: Node3D, top: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = node
	while cur != null and cur != top:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


func _tris(m: ArrayMesh) -> int:
	var t := 0
	for s in m.get_surface_count():
		var arr := m.surface_get_arrays(s)
		var idx = arr[Mesh.ARRAY_INDEX]
		t += (idx.size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return t
