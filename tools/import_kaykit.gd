extends SceneTree
## Bakes Kay Lousberg's KayKit Dungeon Pack (CC0, see CREDITS.md) into game meshes:
##   godot --headless --path . --script res://tools/import_kaykit.gd
##   godot --headless --path . --script res://tools/smooth_textures.gd -- --only=res://assets/props/kaykit_
##   godot --headless --path . --script res://tools/smooth_textures.gd -- --only=res://assets/exteriors/kaykit_
##   godot --headless --path . --import
## `-- --chests` re-bakes only the chests (then smooth with --only=res://assets/props/kaykit_chest).
## `-- --hoard` bakes only the dragons' hoards (HOARD), on the shared atlas already baked and smoothed.
##
## The pack's glTF files (with their bin and dungeon_texture.png beside them) live in psx/kaykit_dungeon/, untouched.
##  - The treasure chest (the plain one; the pack's gold-filled one is never baked), as two meshes so the lid can swing:
##    assets/props/kaykit_chest_base.res and
##    _lid.res. The lid is baked about its hinge (the lid mesh's own origin, along the back of the box); the base keeps
##    the hinge's position as its "hinge" meta. Both are scaled to CHEST_WIDTH across, front facing +z. Their wood
##    is deep blue planks (kaykit_chest_planks.res, painted here), the metal and gold the pack's atlas.
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

## The hoards heaped round the temple guardians' nests (world.gd _dress_hoard): gold coins, stacks of them, golden
## arms, trunks, candles, keys and plates. The only gold coins in the game. Each is baked at the chests' scale (so
## they keep the pack's sizes next to each other) times its factor here, standing on y = 0, centred on x/z, as
## assets/props/kaykit_hoard_<name>.res.
const HOARD := {"coin": 1.6, "coin_stack_small": 1.3, "coin_stack_medium": 1.3, "coin_stack_large": 1.3,
	"sword_shield_gold": 1.0, "sword_shield": 1.0, "trunk_large_A": 1.0, "trunk_medium_B": 1.0, "trunk_small_C": 1.0,
	"candle_triple": 1.0, "candle_lit": 1.0, "candle_melted": 1.0, "keyring": 1.3, "plate_stack": 1.0, "keg_decorated": 1.0}
## The temples' lights (world.gd, room_builder.gd, round_chamber.gd): the wall torch, the standing torch and the thin
## candle, baked like the hoard (as assets/props/kaykit_hoard_<name>.res too, so one --hoard pass bakes them all).
const LIGHTS := {"torch_mounted": 1.0, "torch_lit": 1.0, "candle_thin_lit": 1.0}

var _mats := {}


func _init() -> void:
	var fails := 0
	if "--hoard" in OS.get_cmdline_user_args():
		fails += _bake_hoard()
		print("KAYKIT DONE: %d problem(s)" % fails)
		quit(1 if fails > 0 else 0)
		return
	for kind in ["chest"]:
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
		# the chests' wood becomes deep blue planks (its own surface), the metal and gold keep the atlas
		var hinge_meta = base.get_meta("hinge")
		base = _planked(base)
		base.set_meta("hinge", hinge_meta)
		top = _planked(top)
		_save(base, "res://assets/props/kaykit_%s_base.res" % kind)
		_save(top, "res://assets/props/kaykit_%s_lid.res" % kind)
		print("%s: %.2f x %.2f, lid hinge %s" % [kind, base.get_aabb().size.x, base.get_aabb().size.y, hinge])
		sc.free()
	if "--chests" in OS.get_cmdline_user_args():
		print("KAYKIT DONE: %d problem(s)" % fails)
		quit(1 if fails > 0 else 0)
		return
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


func _bake_hoard() -> int:
	var fails := 0
	# the chests' scale: CHEST_WIDTH across the chest's box
	var chest := _load("chest")
	var w := 1.0
	for mi in chest.find_children("*", "MeshInstance3D", true, false):
		if not String(mi.name).ends_with("_lid"):
			w = (mi as MeshInstance3D).mesh.get_aabb().size.x
	chest.free()
	var all := HOARD.merged(LIGHTS)
	for name in all:
		var sc := _load(String(name))
		if sc == null:
			fails += 1
			continue
		var parts := []
		var bb := AABB()
		var first := true
		for mi in sc.find_children("*", "MeshInstance3D", true, false):
			var xf := _xf_to(mi, sc)
			parts.append([mi, xf])
			var b: AABB = xf * (mi as MeshInstance3D).mesh.get_aabb()
			bb = b if first else bb.merge(b)
			first = false
		var s: float = CHEST_WIDTH / w * float(all[name])
		var shift := Transform3D(Basis().scaled(Vector3.ONE * s), Vector3.ZERO) 			* Transform3D(Basis(), -Vector3(bb.get_center().x, bb.position.y, bb.get_center().z))
		for p in parts:
			p[1] = shift * p[1]
		var mesh := _bake(parts)
		_save(mesh, "res://assets/props/kaykit_hoard_%s.res" % name)
		print("hoard %s: %.2f x %.2f x %.2f" % [name, mesh.get_aabb().size.x, mesh.get_aabb().size.y, mesh.get_aabb().size.z])
		sc.free()
	return fails


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
	# a chests-only bake keeps the shared (already smoothed) atlas the other meshes use
	if ("--chests" in OS.get_cmdline_user_args() or "--hoard" in OS.get_cmdline_user_args()) and ResourceLoader.exists(ATLAS):
		_atlas_tex = load(ATLAS)
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


## The chests' wood: every triangle whose atlas colour is the pack's warm wood brown (hue under WOOD_HUE, not grey)
## moves to its own surface, painted with CHEST_PLANKS (deep blue boards, each the chest's full length, with soft grooves and grain) mapped
## triplanar in the mesh's own space, PLANK_SCALE tiles per unit, so the boards run across the chest and stay put
## as the lid swings. The grey metal and the yellow gold keep the shared atlas.
const CHEST_PLANKS := "res://assets/props/kaykit_chest_planks.res"
const PLANK_SCALE := 2.0
const PLANK_PX := 256
const PLANK_ROWS := 4
const CHEST_BLUE := Color("#1c4176")
const WOOD_HUE := 0.105
var _planks_tex: Texture2D = null
var _plank_mat: StandardMaterial3D = null
var _atlas_imgs := {}


func _planked(m: ArrayMesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	var wood := {}
	for k in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV]:
		wood[k] = []
	for si in m.get_surface_count():
		var mat := m.surface_get_material(si) as BaseMaterial3D
		var img := _atlas_image(mat)
		var a := m.surface_get_arrays(si)
		var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = a[Mesh.ARRAY_NORMAL] if a[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var uvs: PackedVector2Array = a[Mesh.ARRAY_TEX_UV] if a[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(verts.size()))
		var keep := {Mesh.ARRAY_VERTEX: [], Mesh.ARRAY_NORMAL: [], Mesh.ARRAY_TEX_UV: []}
		for t in range(0, idx.size(), 3):
			var tri := [idx[t], idx[t + 1], idx[t + 2]]
			var is_wood := false
			if img != null and uvs.size() > 0:
				var c_uv: Vector2 = (uvs[tri[0]] + uvs[tri[1]] + uvs[tri[2]]) / 3.0
				var px := Vector2i(posmod(int(c_uv.x * img.get_width()), img.get_width()), posmod(int(c_uv.y * img.get_height()), img.get_height()))
				var c := img.get_pixelv(px)
				is_wood = c.h < WOOD_HUE and c.s > 0.25 and c.v < 0.9
			var dst: Dictionary = wood if is_wood else keep
			for i in tri:
				dst[Mesh.ARRAY_VERTEX].append(verts[i])
				dst[Mesh.ARRAY_NORMAL].append(norms[i] if norms.size() > 0 else Vector3.UP)
				dst[Mesh.ARRAY_TEX_UV].append(uvs[i] if uvs.size() > 0 else Vector2.ZERO)
		if keep[Mesh.ARRAY_VERTEX].size() > 0:
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays(keep))
			out.surface_set_material(out.get_surface_count() - 1, mat)
	if wood[Mesh.ARRAY_VERTEX].size() > 0:
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays(wood))
		out.surface_set_material(out.get_surface_count() - 1, _planks_material())
	return out


## Plain per-corner lists as surface arrays.
func _arrays(d: Dictionary) -> Array:
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = PackedVector3Array(d[Mesh.ARRAY_VERTEX])
	a[Mesh.ARRAY_NORMAL] = PackedVector3Array(d[Mesh.ARRAY_NORMAL])
	a[Mesh.ARRAY_TEX_UV] = PackedVector2Array(d[Mesh.ARRAY_TEX_UV])
	return a


func _atlas_image(mat: BaseMaterial3D) -> Image:
	if mat == null or mat.albedo_texture == null:
		return null
	if not _atlas_imgs.has(mat.albedo_texture):
		var img: Image = mat.albedo_texture.get_image().duplicate()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		_atlas_imgs[mat.albedo_texture] = img
	return _atlas_imgs[mat.albedo_texture]


func _planks_material() -> StandardMaterial3D:
	if _plank_mat != null:
		return _plank_mat
	if _planks_tex == null:
		_save(ImageTexture.create_from_image(_paint_planks()), CHEST_PLANKS)
		_planks_tex = load(CHEST_PLANKS)
	var m := StandardMaterial3D.new()
	m.albedo_texture = _planks_tex
	m.roughness = 0.85
	m.metallic_specular = 0.3
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.uv1_triplanar = true
	m.uv1_world_triplanar = false
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3.ONE * PLANK_SCALE
	_plank_mat = m
	return m


## A tile of deep blue boards, painted: PLANK_ROWS rows running across, each a slightly different blue with a soft
## lit top and shaded bottom, gentle long grain streaks and soft dark grooves between rows. No joints along a
## row, so each plank runs the full length of the chest. It tiles both ways.
func _paint_planks() -> Image:
	var n := PLANK_PX
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var row_h := n / PLANK_ROWS
	var rng := RandomNumberGenerator.new()
	rng.seed = 7041
	var tones := []
	var phases := []
	for r in PLANK_ROWS:
		tones.append(rng.randf_range(-0.1, 0.1))
		phases.append([rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU])
	var groove := CHEST_BLUE.darkened(0.65)
	for y in n:
		var r := y / row_h
		var fy := float(y % row_h) / row_h
		for x in n:
			var fx := float(x) / n
			var ph: Array = phases[r]
			# long soft grain: low-frequency waves along the board
			var grain := 0.5 * sin(fy * TAU * 3.0 + sin(fx * TAU * 2.0 + ph[0]) * 1.2 + ph[1]) 				+ 0.5 * sin(fy * TAU * 7.0 + sin(fx * TAU + ph[2]) * 2.0)
			var c := CHEST_BLUE
			c = c.lightened(tones[r]) if tones[r] > 0.0 else c.darkened(-tones[r])
			c = c.lightened(0.06 * grain) if grain > 0.0 else c.darkened(-0.06 * grain)
			# lit top edge, shaded bottom edge of each board
			c = c.lightened(0.16 * smoothstep(0.3, 0.0, fy))
			c = c.darkened(0.22 * smoothstep(0.7, 1.0, fy))
			# the groove between rows, soft
			var g := maxf(smoothstep(0.08, 0.0, fy), smoothstep(0.92, 1.0, fy))
			c = c.lerp(groove, g)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
	img.generate_mipmaps()
	return img


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
