extends SceneTree
## Bakes the PSX models the game uses from the downloaded packs in psx/ into assets/psx/models/<name>.res.
##   godot --headless --path . --script res://tools/import_psx_models.gd
##
## Each model's meshes are merged into one mesh (one surface per material) and its textures shrunk to PSX size
## (128 px at most, mipmapped, sampled nearest) and stored inside the .res, so the game needs no import settings.
## Textures with see-through pixels become alpha-scissor cutouts, drawn from both sides (leaves, fences, palms).
## The names match the ones the game already asks for (see voxel_manifest.gd); credits are in CREDITS.md.

const OUT := "res://assets/psx/models/"
const EC := "Nature/Retro PSX Style Tree Pack (Elegant Crow)/models/"
const HF := "Nature/PSX Forest Free - Woodland Sampler (heyheythere)/glb/"
const HC := "Environments/PSX Cemetery Kit Free - Churchyard Sampler (heyheythere)/glb/"
const HK := "Environments/PSX Castle Kit Free - Retro FPS Castle Hall Sampler (heyheythere)/glb/"
const HW := "Environments/PSX Western Town Kit Free - Wild West Sampler (heyheythere)/glb/"
const RI := "Nature/PSX The Island Pack (Rob)/gltf/"

## name: [source (relative to psx/), options]
## options: gain = brighten the texture (1 = as is), sat = keep this much of its saturation (1 = all),
##          tint = multiply its colour, max_tex = largest texture side
const MODELS := {
	# ---- trees
	"tree_pine": [EC + "tree02.fbx", {"gain": 1.25}],
	"tree_birch": [EC + "tree16.fbx", {"gain": 1.1}],
	"tree_oak": [EC + "tree19.fbx", {"gain": 1.3}],
	"tree_big": [EC + "tree17.fbx", {"gain": 1.35}],
	"tree_round_1": [EC + "tree15.fbx", {"gain": 1.15}],
	"tree_round_2": [EC + "tree22.fbx", {"gain": 1.3}],
	"palm": [RI + "SM_TI_Palm_Tree_1.gltf", {"gain": 1.15}],
	"dead_tree": [HF + "tree_dead.glb", {}],
	"stump": [HF + "stump.glb", {}],
	# ---- shrubs (solid models: from this camera, flat crossed cards would read as stars)
	"shrub_1": [HF + "bush.glb", {"gain": 1.15}],
	"shrub_2": [RI + "SM_TI_Beach_Cabbage_0.gltf", {"gain": 1.1}],
	"shrub_3": [HF + "bush.glb", {"gain": 1.3, "tint": Color("#d8f0b0")}],
	"shrub_4": [HF + "fern.glb", {}],
	"bush_1": [HF + "bush.glb", {"gain": 1.5, "sat": 0.15, "tint": Color("#d8b878")}],
	"bush_2": [HF + "bush.glb", {"gain": 1.6, "sat": 0.1, "tint": Color("#e8d090")}],
	"bush_3": [HF + "bush.glb", {"gain": 1.2, "sat": 0.45, "tint": Color("#c8d0a8")}],
	# ---- rocks (the island rocks are dark, so they are lifted and greyed a little)
	"field_rock": [HF + "boulder.glb", {}],
	"beach_rock": [RI + "SM_TI_Rock_2.gltf", {"gain": 1.6, "tint": Color("#e8dccc")}],
	"rock_big": [RI + "SM_TI_Rock_0.gltf", {"gain": 1.6, "tint": Color("#d8d0c8")}],
	"rock_small": [RI + "SM_TI_Rock_5.gltf", {"gain": 1.6, "tint": Color("#d8d0c8")}],
	"mountain_0": [RI + "SM_TI_RockBlock_0.gltf", {"gain": 1.5, "tint": Color("#d0c8c0")}],
	"mountain_1": [RI + "SM_TI_Rock_1.gltf", {"gain": 1.1, "tint": Color("#a89088")}],
	"mountain_2": [RI + "SM_TI_RockBlock_1.gltf", {"gain": 1.5, "tint": Color("#d0c8c0")}],
	"mountain_3": [RI + "SM_TI_Rock_3.gltf", {"gain": 1.6, "tint": Color("#f0c0a0")}],
	"mountain_4": [RI + "SM_TI_RockBlock_2.gltf", {"gain": 1.5, "tint": Color("#d0c8c0")}],
	"mountain_5": [RI + "SM_TI_Rock_4.gltf", {"gain": 1.5, "tint": Color("#d0c8c0")}],
	"mountain_6": [RI + "SM_TI_Rock_6.gltf", {"gain": 1.6, "tint": Color("#f0c0a0")}],
	"mountain_7": [RI + "SM_TI_Rock_7.gltf", {"gain": 1.5, "tint": Color("#d0c8c0")}],
	"mountain_8": [RI + "SM_TI_Rock_8.gltf", {"gain": 1.0, "tint": Color("#8a7870")}],
	"stone_1": [HF + "boulder.glb", {"tint": Color("#a8a8b0")}],
	"stone_2": [RI + "SM_TI_Rock_5.gltf", {"gain": 1.7, "tint": Color("#f0e0c8")}],
	"stone_3": [RI + "SM_TI_Rock_2.gltf", {"gain": 1.0, "tint": Color("#8a7870")}],
	"stone_4": [RI + "SM_TI_Rock_2.gltf", {"gain": 1.7, "tint": Color("#f0d0b0")}],
	"stone_5": [RI + "SM_TI_Rock_5.gltf", {"gain": 1.0, "tint": Color("#8a7870")}],
	"bones_1": [HW + "tumbleweed.glb", {}],
	"bones_2": [HW + "tumbleweed.glb", {"tint": Color("#e8d8b0")}],
	"bones_3": [HW + "tumbleweed.glb", {"tint": Color("#c8a878")}],
	# ---- props
	"fence": [HF + "fence.glb", {}],
	"iron_fence": [HC + "gate_wicket.glb", {}],
	"lamp": [HC + "lamp_post.glb", {}],
	"barrel": [HK + "cask.glb", {}],
	"crates": [HK + "crate_castle.glb", {}],
	"banner": [HK + "banner_red.glb", {}],
	"torch": [HK + "torch_wall.glb", {}],
	"stone_pillar": [HK + "pillar_round.glb", {"gain": 1.15}],
	"stone_pillar_dark": [HK + "pillar_round.glb", {"tint": Color("#8a8090")}],
	"stone_wall": [HC + "wall_stone.glb", {}],
	"grave_1w": [HC + "headstone_military.glb", {}],
	"grave_2w": [HC + "celtic_cross.glb", {}],
	"tomb_2": [HC + "tomb_chest.glb", {}],
	"mossy_statue": [HC + "pier_stone.glb", {"tint": Color("#a8c098")}],
	"campfire": [HF + "campfire.glb", {}],
	"log": [HF + "log.glb", {}],
}


func _init() -> void:
	var src := ProjectSettings.globalize_path("res://psx/")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var only := OS.get_cmdline_user_args()
	for name in MODELS:
		if not only.is_empty() and not only.has(name):
			continue
		var e: Array = MODELS[name]
		var scene := _load(src + e[0])
		if scene == null:
			push_error("could not load " + e[0])
			continue
		var mesh := _bake(scene, e[1])
		scene.free()
		if _tris(mesh) > 300:
			mesh = _with_lods(mesh)
		var err := ResourceSaver.save(mesh, OUT + name + ".res", ResourceSaver.FLAG_COMPRESS)
		print("  %-16s %5d tris  %s" % [name, _tris(mesh), "ok" if err == OK else "SAVE FAILED"])
	quit()


func _load(p: String) -> Node:
	var ext := p.get_extension().to_lower()
	var sc: Node = null
	if ext in ["glb", "gltf"]:
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_file(p, st) == OK:
			sc = doc.generate_scene(st)
	elif ext == "fbx":
		var doc := FBXDocument.new()
		var st := FBXState.new()
		if doc.append_from_file(p, st) == OK:
			sc = doc.generate_scene(st)
	if sc != null:
		_sibling_texture(sc, p)
	return sc


## FBX files that name no texture: use ../textures/<model name>.png (the Elegant Crow trees keep them there).
func _sibling_texture(sc: Node, p: String) -> void:
	var base := p.get_file().get_basename()
	var tex_path := ""
	for c in [p.get_base_dir().get_base_dir() + "/textures/" + base + ".png", p.get_base_dir() + "/" + base + ".png"]:
		if FileAccess.file_exists(c):
			tex_path = c
			break
	if tex_path == "":
		return
	for mi in sc.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		for si in m.get_surface_count():
			var mat = m.surface_get_material(si)
			if mat is BaseMaterial3D and mat.albedo_texture != null:
				continue
			var nm := StandardMaterial3D.new()
			nm.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(tex_path))
			m.surface_set_material(si, nm)


## All the scene's meshes in one ArrayMesh, in the scene root's space, with PSX materials. The result is centred on
## X/Z and stands on y = 0 (what the game expects; doing it here keeps the levels of detail made afterwards).
func _bake(scene: Node, opt: Dictionary) -> ArrayMesh:
	var out := ArrayMesh.new()
	var mats := {}
	var bb := AABB()
	var first := true
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		if inst.mesh != null:
			var b := _xf_to(inst, scene) * inst.mesh.get_aabb()
			bb = b if first else bb.merge(b)
			first = false
	var shift := Transform3D(Basis(), -Vector3(bb.get_center().x, bb.position.y, bb.get_center().z))
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		var m: Mesh = inst.mesh
		if m == null:
			continue
		var xf := shift * _xf_to(inst, scene)
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
			# no skinning, tangents or blend shapes in the baked copy
			arrays[Mesh.ARRAY_TANGENT] = null
			arrays[Mesh.ARRAY_BONES] = null
			arrays[Mesh.ARRAY_WEIGHTS] = null
			var src_mat: Material = inst.get_active_material(si)
			if not mats.has(src_mat):
				mats[src_mat] = _psx_material(src_mat, opt)
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			out.surface_set_material(out.get_surface_count() - 1, mats[src_mat])
	return out


func _psx_material(src: Material, opt: Dictionary) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.roughness = 1.0
	m.metallic_specular = 0.2
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	var tint: Color = opt.get("tint", Color.WHITE)
	if src is BaseMaterial3D:
		var b := src as BaseMaterial3D
		m.albedo_color = b.albedo_color * tint
		m.vertex_color_use_as_albedo = b.vertex_color_use_as_albedo
		if b.albedo_texture != null:
			var img := b.albedo_texture.get_image()
			if img != null:
				img = img.duplicate()
				if img.is_compressed():
					img.decompress()
				img.clear_mipmaps()
				img.convert(Image.FORMAT_RGBA8)
				var side := int(opt.get("max_tex", 128))
				if maxi(img.get_width(), img.get_height()) > side:
					var k := float(side) / maxi(img.get_width(), img.get_height())
					img.resize(maxi(1, int(img.get_width() * k)), maxi(1, int(img.get_height() * k)), Image.INTERPOLATE_LANCZOS)
				var gain := float(opt.get("gain", 1.0))
				var sat := float(opt.get("sat", 1.0))
				var cut := false
				for y in img.get_height():
					for x in img.get_width():
						var c := img.get_pixel(x, y)
						if c.a < 0.5:
							cut = true
						if sat != 1.0:
							var l := c.get_luminance()
							c = Color(l, l, l, c.a).lerp(c, sat)
						if gain != 1.0 or sat != 1.0:
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
	else:
		m.albedo_color = tint
	return m


## The same mesh with automatic levels of detail: far away (most of the screen at this camera) the dense rocks and
## palms draw a fraction of their triangles.
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


func _tris(m: ArrayMesh) -> int:
	var t := 0
	for s in m.get_surface_count():
		var arr := m.surface_get_arrays(s)
		var idx = arr[Mesh.ARRAY_INDEX]
		t += (idx.size() if idx != null else arr[Mesh.ARRAY_VERTEX].size()) / 3
	return t
