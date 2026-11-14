extends SceneTree
## Bakes Kay Lousberg's KayKit Dungeon Pack (CC0, see CREDITS.md) into game meshes:
##   godot --headless --path . --script res://tools/import_kaykit.gd
##   godot --headless --path . --script res://tools/smooth_textures.gd -- --only=res://assets/props/kaykit_
##   godot --headless --path . --script res://tools/smooth_textures.gd -- --only=res://assets/exteriors/kaykit_
##   godot --headless --path . --import
##
## The pack's glTF files (with their bin and dungeon_texture.png beside them) live in psx/kaykit_dungeon/, untouched.
##  - The treasure chests, as two meshes each so the lid can swing: assets/props/kaykit_chest[_gold]_base.res and
##    _lid.res. The lid is baked about its hinge (the lid mesh's own origin, along the back of the box); the base keeps
##    the hinge's position as its "hinge" meta. Both are scaled to CHEST_WIDTH across, front facing +z.
##  - The crates and barrels that replace the older packs' ones: each is sized to the height of the mesh it replaces
##    (so every caller keeps its scale), standing on y = 0 and centred on x/z, front facing +z.
## Materials sample the pack's colour atlas smoothly (linear, mipmapped, anisotropic).

const SRC := "res://psx/kaykit_dungeon/"
const CHEST_WIDTH := 0.7
## name of the baked mesh: [pack model, the older mesh whose height it takes]
const SWAPS := {
	"res://assets/exteriors/kaykit_crate.res": ["box_small", "res://assets/exteriors/crate.res"],
	"res://assets/exteriors/kaykit_crate_open.res": ["box_small_decorated", "res://assets/exteriors/crate_open.res"],
	"res://assets/exteriors/kaykit_barrel.res": ["barrel_large", "res://assets/exteriors/barrel.res"],
	"res://assets/exteriors/kaykit_keg.res": ["barrel_small", "res://assets/exteriors/keg.res"],
	"res://assets/exteriors/kaykit_cove_crate.res": ["box_large", "res://assets/exteriors/cove_crate.res"],
	"res://assets/exteriors/kaykit_cove_barrel.res": ["barrel_large_decorated", "res://assets/exteriors/cove_barrel.res"],
	"res://assets/props/kaykit_barrel.res": ["barrel_large", "res://assets/props/barrel.res"],
	"res://assets/props/kaykit_crates.res": ["crates_stacked", "res://assets/props/crates.res"],
}

## The street benches (two tiles, world.gd STREET_WIDE; the game uses the stool one): the pack has no bench, so a chair or stool is turned to face
## +z, scaled to SEAT_SCALE and slice-stretched to BENCH_WIDTH across: everything left of its middle moves left and
## everything right moves right, so the legs keep their size and only the seat (and the chair's back) grows longer.
## name of the baked mesh: [pack model, degrees to turn it about y]
const BENCHES := {
	"res://assets/exteriors/kaykit_bench.res": ["chair", 90.0],
	"res://assets/exteriors/kaykit_stool_bench.res": ["stool", 0.0],
}
const SEAT_SCALE := 0.9
const BENCH_WIDTH := 1.8

var _mats := {}


func _init() -> void:
	var fails := 0
	for kind in ["chest", "chest_gold"]:
		var sc := _load(kind)
		if sc == null:
			fails += 1
			continue
		var lid: MeshInstance3D = null
		var body: MeshInstance3D = null
		for mi in sc.find_children("*", "MeshInstance3D", true, false):
			if String(mi.name).ends_with("_lid"):
				lid = mi
			else:
				body = mi
		if lid == null or body == null:
			push_error("%s: no separate lid" % kind)
			fails += 1
			sc.free()
			continue
		var w := body.mesh.get_aabb().size.x
		var s := CHEST_WIDTH / w
		var body_xf := _xf_to(body, sc)
		var hinge := (_xf_to(lid, sc)).origin * s
		var base := _bake([[body, Transform3D(Basis().scaled(Vector3.ONE * s), Vector3.ZERO) * body_xf]])
		base.set_meta("hinge", hinge)
		# the lid about its own origin, the hinge
		var top := _bake([[lid, Transform3D(Basis().scaled(Vector3.ONE * s), Vector3.ZERO)]])
		# the chests' wood is painted a pale blue (their own atlas), the metal left as it is
		for m in [base, top]:
			for si in m.get_surface_count():
				m.surface_set_material(si, _chest_material(m.surface_get_material(si)))
		_save(base, "res://assets/props/kaykit_%s_base.res" % kind)
		_save(top, "res://assets/props/kaykit_%s_lid.res" % kind)
		print("%s: %.2f x %.2f, lid hinge %s" % [kind, base.get_aabb().size.x, base.get_aabb().size.y, hinge])
		sc.free()
	for out in SWAPS:
		var e: Array = SWAPS[out]
		var sc := _load(String(e[0]))
		if sc == null:
			fails += 1
			continue
		var old: Mesh = load(String(e[1])) if ResourceLoader.exists(String(e[1])) else null
		var parts := []
		var bb := AABB()
		var first := true
		for mi in sc.find_children("*", "MeshInstance3D", true, false):
			var xf := _xf_to(mi, sc)
			parts.append([mi, xf])
			var b: AABB = xf * (mi as MeshInstance3D).mesh.get_aabb()
			bb = b if first else bb.merge(b)
			first = false
		var h := old.get_aabb().size.y if old != null else 0.8
		var s := h / bb.size.y
		if old != null:
			# no wider than what it replaces (with a little give), so it keeps to its tile
			var ow := maxf(old.get_aabb().size.x, old.get_aabb().size.z) * 1.1
			s = minf(s, ow / maxf(bb.size.x, bb.size.z))
		var shift := Transform3D(Basis().scaled(Vector3.ONE * s), Vector3.ZERO) \
			* Transform3D(Basis(), -Vector3(bb.get_center().x, bb.position.y, bb.get_center().z))
		for p in parts:
			p[1] = shift * p[1]
		var mesh := _with_lods(_bake(parts))
		_save(mesh, out)
		print("%s <- %s: %.2f high (was %.2f)" % [out.get_file(), e[0], mesh.get_aabb().size.y, h])
		sc.free()
	for out in BENCHES:
		var e: Array = BENCHES[out]
		var sc := _load(String(e[0]))
		if sc == null:
			fails += 1
			continue
		var turn := Transform3D(Basis(Vector3.UP, deg_to_rad(float(e[1]))).scaled(Vector3.ONE * SEAT_SCALE), Vector3.ZERO)
		var parts := []
		for mi in sc.find_children("*", "MeshInstance3D", true, false):
			parts.append([mi, turn * _xf_to(mi, sc)])
		var mesh := _bake(parts)
		var half := mesh.get_aabb().size.x / 2.0
		mesh = _sliced(mesh, BENCH_WIDTH / 2.0 - half)
		_save(_with_lods(mesh), out)
		print("%s <- %s: %.2f x %.2f x %.2f" % [out.get_file(), e[0], mesh.get_aabb().size.x, mesh.get_aabb().size.y, mesh.get_aabb().size.z])
		sc.free()
	print("KAYKIT DONE: %d problem(s)" % fails)
	quit(1 if fails > 0 else 0)


func _load(name: String) -> Node:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var path := ProjectSettings.globalize_path(SRC + name + ".gltf")
	if doc.append_from_file(path, st) != OK:
		push_error("can't read " + path)
		return null
	return doc.generate_scene(st)


## [[MeshInstance3D, transform]] merged into one mesh, one surface per source material.
func _bake(parts: Array) -> ArrayMesh:
	var out := ArrayMesh.new()
	for p in parts:
		var inst: MeshInstance3D = p[0]
		var xf: Transform3D = p[1]
		for si in inst.mesh.get_surface_count():
			var arrays := inst.mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in verts.size():
				verts[i] = xf * verts[i]
			arrays[Mesh.ARRAY_VERTEX] = verts
			if arrays[Mesh.ARRAY_NORMAL] != null:
				var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				for i in ns.size():
					ns[i] = (xf.basis * ns[i]).normalized()
				arrays[Mesh.ARRAY_NORMAL] = ns
			for a in [Mesh.ARRAY_TANGENT, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS, Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1,
					Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
				arrays[a] = null
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			out.surface_set_material(out.get_surface_count() - 1, _material(inst.get_active_material(si)))
	return out


## The mesh with every vertex right of x = 0 moved `by` further right and every one left of it `by` further left.
func _sliced(m: ArrayMesh, by: float) -> ArrayMesh:
	var out := ArrayMesh.new()
	for si in m.get_surface_count():
		var arrays := m.surface_get_arrays(si)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in verts.size():
			verts[i].x += by * signf(verts[i].x)
		arrays[Mesh.ARRAY_VERTEX] = verts
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(si, m.surface_get_material(si))
	return out


## The pack's material: its colour atlas, sampled smoothly, matte.
func _material(src: Material) -> StandardMaterial3D:
	if _mats.has(src):
		return _mats[src]
	var m := StandardMaterial3D.new()
	m.roughness = 0.9
	m.metallic_specular = 0.25
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if src is BaseMaterial3D and (src as BaseMaterial3D).albedo_texture != null:
		m.albedo_texture = _atlas((src as BaseMaterial3D).albedo_texture)
	elif src is BaseMaterial3D:
		m.albedo_color = (src as BaseMaterial3D).albedo_color
	_mats[src] = m
	return m


## Every model shares the one colour atlas: saved once in its own file (smooth_textures.gd smooths it there), at
## ATLAS_SIZE, and referenced by every baked mesh.
const ATLAS := "res://assets/props/kaykit_atlas.res"
const ATLAS_SIZE := 512
var _atlas_tex: Texture2D = null


func _atlas(src: Texture2D) -> Texture2D:
	if _atlas_tex != null:
		return _atlas_tex
	var img := src.get_image().duplicate()
	if img.is_compressed():
		img.decompress()
	img.clear_mipmaps()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(ATLAS_SIZE, ATLAS_SIZE, Image.INTERPOLATE_LANCZOS)
	img.generate_mipmaps()
	_save(ImageTexture.create_from_image(img), ATLAS)
	_atlas_tex = load(ATLAS)
	return _atlas_tex


## The chests' copy of the atlas: its warm wood browns (hue under WOOD_HUE, not grey) turned CHEST_BLUE, keeping
## their light and shade; the grey metal and the yellow gold are untouched.
const CHEST_ATLAS := "res://assets/props/kaykit_chest_atlas.res"
const CHEST_BLUE := Color("#b9dcf2")
const WOOD_HUE := 0.105
var _chest_tex: Texture2D = null
var _chest_mats := {}


func _chest_material(src: Material) -> Material:
	if _chest_mats.has(src):
		return _chest_mats[src]
	var m := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
	if m.albedo_texture != null:
		if _chest_tex == null:
			var img: Image = m.albedo_texture.get_image().duplicate()
			if img.is_compressed():
				img.decompress()
			img.clear_mipmaps()
			img.convert(Image.FORMAT_RGBA8)
			# the atlas's brightest wood, so its shading maps onto the blue from light to shade
			var top := 0.0
			for y in img.get_height():
				for x in img.get_width():
					var c: Color = img.get_pixel(x, y)
					if c.h < WOOD_HUE and c.s > 0.25:
						top = maxf(top, c.v)
			for y in img.get_height():
				for x in img.get_width():
					var c: Color = img.get_pixel(x, y)
					if c.h < WOOD_HUE and c.s > 0.25:
						var k := clampf(c.v / maxf(top, 0.01), 0.0, 1.0)
						var b := CHEST_BLUE.darkened(0.42 * (1.0 - k))
						img.set_pixel(x, y, Color(b.r, b.g, b.b, c.a))
			img.generate_mipmaps()
			_save(ImageTexture.create_from_image(img), CHEST_ATLAS)
			_chest_tex = load(CHEST_ATLAS)
		m.albedo_texture = _chest_tex
	_chest_mats[src] = m
	return m


func _with_lods(m: ArrayMesh) -> ArrayMesh:
	var im := ImporterMesh.new()
	for s in m.get_surface_count():
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, m.surface_get_arrays(s), [], {}, m.surface_get_material(s))
	im.generate_lods(60.0, 25.0, [])
	return im.get_mesh()


func _xf_to(node: Node3D, top: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = node
	while cur != null and cur != top:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


func _save(m: Resource, path: String) -> void:
	var err := ResourceSaver.save(m, path, ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		push_error("can't save %s (%d)" % [path, err])
