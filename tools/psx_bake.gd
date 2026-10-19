extends RefCounted
## Shared helpers for the tools that bake pack models into game meshes (see import_psx_interior.gd): loading a model
## straight from the downloaded packs, merging it into one mesh with PSX materials (textures shrunk, sampled sharp),
## turning it, and giving it levels of detail.


## "file.fbx#Node" loads just that node (and what hangs under it) out of a bigger scene, keeping where the scene put it.
## FBX textures are looked for in a "Textures"/"textures" folder beside or above the file.
static func load_model(p: String) -> Node:
	var node_name := ""
	# a node name after the last "#" (folder names may have a "#" in them too)
	var cut := p.rfind("#")
	if cut >= 0 and not "/" in p.substr(cut) and not "." in p.substr(cut):
		node_name = p.substr(cut + 1)
		p = p.substr(0, cut)
	var ext := p.get_extension().to_lower()
	var sc: Node = null
	if ext in ["glb", "gltf"]:
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_file(p, st) == OK:
			sc = doc.generate_scene(st)
	elif ext == "fbx":
		# textures named relative to the model first; if none load, from the pack's texture folder
		for base in ["", tex_dir(p)]:
			var doc := FBXDocument.new()
			var st := FBXState.new()
			if doc.append_from_file(p, st, 0, base) == OK:
				if sc != null:
					sc.free()
				sc = doc.generate_scene(st)
				if _textured(sc) or base == "" and tex_dir(p) == "":
					break
	if sc == null or node_name == "":
		return sc
	var found: Node = null
	for n in sc.find_children("*", "", true, false):
		if String(n.name) == node_name:
			found = n
			break
	if found == null or not found is Node3D:
		sc.free()
		return null
	# keep it where the scene had it: its transform up to the root, applied to a copy under a fresh root
	var xf := xf_to(found as Node3D, sc)
	var root := Node3D.new()
	var copy: Node3D = (found as Node3D).duplicate()
	root.add_child(copy)
	copy.transform = xf
	sc.free()
	return root


## Whether any of the scene's materials found its texture.
static func _textured(sc: Node) -> bool:
	for mi in sc.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for si in m.mesh.get_surface_count():
			var mat := m.get_active_material(si) as BaseMaterial3D
			if mat != null and mat.albedo_texture != null:
				return true
	return false


## A "Textures" folder in the model's own folder or up to two above it (not further: that could be the collection's
## own "Textures" category). Empty means textures are looked up beside the model, as the file names them.
static func tex_dir(p: String) -> String:
	var d := p.get_base_dir()
	for i in 3:
		for name in ["Textures", "textures"]:
			if DirAccess.dir_exists_absolute(d + "/" + name):
				return d + "/" + name
		d = d.get_base_dir()
	return ""


## All the scene's meshes in one ArrayMesh, scaled by `scale`, centred on X/Z and standing on y = 0, with PSX
## materials (see psx_material).
static func bake(scene: Node, opt: Dictionary) -> ArrayMesh:
	var out := ArrayMesh.new()
	var mats := {}
	var bb := AABB()
	var first := true
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		if inst.mesh != null:
			var b := xf_to(inst, scene) * inst.mesh.get_aabb()
			bb = b if first else bb.merge(b)
			first = false
	var s := float(opt.get("scale", 1.0))
	var shift := Transform3D(Basis().scaled(Vector3.ONE * s), Vector3.ZERO) \
		* Transform3D(Basis(), -Vector3(bb.get_center().x, bb.position.y, bb.get_center().z))
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		var m: Mesh = inst.mesh
		if m == null:
			continue
		var xf := shift * xf_to(inst, scene)
		for si in m.get_surface_count():
			var arrays := m.surface_get_arrays(si)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in verts.size():
				verts[i] = xf * verts[i]
			arrays[Mesh.ARRAY_VERTEX] = verts
			if arrays[Mesh.ARRAY_NORMAL] != null:
				var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				for i in ns.size():
					ns[i] = (xf.basis * ns[i]).normalized()
				arrays[Mesh.ARRAY_NORMAL] = ns
			# no skinning, tangents, blend shapes or custom channels in the baked copy
			for a in [Mesh.ARRAY_TANGENT, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS, Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1,
					Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
				arrays[a] = null
			var src_mat: Material = inst.get_active_material(si)
			if not mats.has(src_mat):
				mats[src_mat] = psx_material(src_mat, opt)
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			out.surface_set_material(out.get_surface_count() - 1, mats[src_mat])
	return out


## A material's texture as a PSX-sized image (no larger than `side`), or null.
static func psx_image(src: Material, side: int) -> Image:
	if not src is BaseMaterial3D or (src as BaseMaterial3D).albedo_texture == null:
		return null
	var img := (src as BaseMaterial3D).albedo_texture.get_image()
	if img == null:
		return null
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.clear_mipmaps()
	img.convert(Image.FORMAT_RGBA8)
	if maxi(img.get_width(), img.get_height()) > side:
		var k := float(side) / maxi(img.get_width(), img.get_height())
		img.resize(maxi(1, int(img.get_width() * k)), maxi(1, int(img.get_height() * k)), Image.INTERPOLATE_LANCZOS)
	return img


## options: gain = brighten the texture, max_tex = largest texture side (128).
static func psx_material(src: Material, opt: Dictionary) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.roughness = 1.0
	m.metallic_specular = 0.2
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	if src is BaseMaterial3D:
		var b := src as BaseMaterial3D
		m.albedo_color = b.albedo_color
		m.vertex_color_use_as_albedo = b.vertex_color_use_as_albedo
		var img := psx_image(src, int(opt.get("max_tex", 128)))
		if img != null:
			var gain := float(opt.get("gain", 1.0))
			var cut := false
			for y in img.get_height():
				for x in img.get_width():
					var c := img.get_pixel(x, y)
					if c.a < 0.5:
						cut = true
					if gain != 1.0:
						img.set_pixel(x, y, Color(minf(1.0, c.r * gain), minf(1.0, c.g * gain), minf(1.0, c.b * gain), c.a))
			img.generate_mipmaps()
			m.albedo_texture = ImageTexture.create_from_image(img)
			if cut or b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				m.alpha_scissor_threshold = 0.5
				m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if b.emission_enabled:
			m.emission_enabled = true
			m.emission = b.emission
			m.emission_energy_multiplier = b.emission_energy_multiplier
			m.emission_texture = m.albedo_texture if b.emission_texture != null else null
	return m


## The mesh turned `deg` degrees about y, centred again on x/z.
static func turned(m: ArrayMesh, deg: float) -> ArrayMesh:
	if absf(deg) < 0.01:
		return m
	var basis := Basis(Vector3.UP, deg_to_rad(deg))
	var out := ArrayMesh.new()
	var bb := AABB()
	var first := true
	var all := []
	for s in m.get_surface_count():
		var arrays := m.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in verts.size():
			verts[i] = basis * verts[i]
			bb = AABB(verts[i], Vector3.ZERO) if first else bb.expand(verts[i])
			first = false
		arrays[Mesh.ARRAY_VERTEX] = verts
		if arrays[Mesh.ARRAY_NORMAL] != null:
			var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in ns.size():
				ns[i] = basis * ns[i]
			arrays[Mesh.ARRAY_NORMAL] = ns
		all.append([arrays, m.surface_get_material(s)])
	var off := Vector3(bb.get_center().x, 0, bb.get_center().z)
	for e in all:
		var verts: PackedVector3Array = e[0][Mesh.ARRAY_VERTEX]
		for i in verts.size():
			verts[i] -= off
		e[0][Mesh.ARRAY_VERTEX] = verts
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, e[0])
		out.surface_set_material(out.get_surface_count() - 1, e[1])
	return out


static func with_lods(m: ArrayMesh) -> ArrayMesh:
	var im := ImporterMesh.new()
	for s in m.get_surface_count():
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, m.surface_get_arrays(s), [], {}, m.surface_get_material(s))
	im.generate_lods(60.0, 25.0, [])
	return im.get_mesh()


static func xf_to(node: Node3D, top: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = node
	while cur != null and cur != top:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


static func tris(m: ArrayMesh) -> int:
	var t := 0
	for s in m.get_surface_count():
		var arr := m.surface_get_arrays(s)
		var idx = arr[Mesh.ARRAY_INDEX]
		t += (idx.size() if idx != null else arr[Mesh.ARRAY_VERTEX].size()) / 3
	return t
