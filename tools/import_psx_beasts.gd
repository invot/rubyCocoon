extends SceneTree
## Bakes the beast models from the PSX creature packs in psx/Creatures into assets/psx/beasts/<form>.res.
##   godot --headless --path . --script res://tools/import_psx_beasts.gd [-- form1 form2 ...]
##
## Each model is merged into one ArrayMesh in the game's beast space: facing +x, standing on y = 0, centred on x/z
## and scaled so its larger measure (its height, or 0.62 of its length) is 1 unit. voxel_beast.gd recolours
## it with each beast's gene colours, so every surface keeps its colours where the recolouring can read them: in
## vertex colours (the Everything Library animals and flat-coloured models) or in a small texture (the textured
## packs). Flying models carry the meta "hover" (how high they float above the ground, in model units).
## Which race uses which form: RaceDB.FORMS. Credits: CREDITS.md.

const OUT := "res://assets/psx/beasts/"
const CR := "Creatures/"
const EL := "Everything Library 01 - ANIMALS (David)/EverythingLibrary_Animals_001.fbx"
const QM := "LowPoly Animated Monsters (Quaternius)/FBX/"
const FP := "PS1-PSX Fish Pack (CursedLake)/GLB/"
const AC := "PS1-PSX style alpaca & capybara models (obliviist)/"

## form: [source file under psx/Creatures, options]
## options: node = the Everything Library animal (its node name, or "Node/mesh" for one of its variants),
##          yaw = degrees to turn it so it faces +x, hover = flies (how high, in units of its own size),
##          tex = texture for a model whose file names none, keep_dark = luminance kept as is (eyes, claws)
const FORMS := {
	# ---- mammals
	"raccoon": [EL, {"node": "Raccoon"}],
	"red_fox": [EL, {"node": "RedFox"}],
	"kit_fox": [EL, {"node": "KitFox"}],
	"arctic_fox": [EL, {"node": "ArcticFox"}],
	"aardvark": [EL, {"node": "Aardvark"}],
	"dobermann": [EL, {"node": "Dobermann"}],
	"puppy": [EL, {"node": "LabradorPuppy"}],
	"bobcat": [EL, {"node": "Bobcat"}],
	"lion": [EL, {"node": "Lion/alt604"}],
	"tiger": [EL, {"node": "Tiger"}],
	"otter": [EL, {"node": "Otter"}],
	"red_panda": [EL, {"node": "RedPanda"}],
	"rabbit": [EL, {"node": "Rabbit"}],
	"hedgehog": [EL, {"node": "Hedgehog"}],
	"armadillo": [EL, {"node": "Armadillo"}],
	"boar": [EL, {"node": "Boar"}],
	"bison": [EL, {"node": "Bison"}],
	"muskox": [EL, {"node": "Muskox"}],
	"rhino": [EL, {"node": "Rhino"}],
	"bighorn": [EL, {"node": "BighornSheep/alt606"}],
	"elk": [EL, {"node": "RockyMountainElk/alt608"}],
	"gorilla": [EL, {"node": "Gorilla/alt587"}],
	"sloth": [EL, {"node": "Sloth"}],
	"mammoth": [EL, {"node": "WoolyMammoth"}],
	"capybara": [CR + AC + "capybara_model/capybara.obj", {"tex": CR + AC + "capybara_model/capybara1_texture.png"}],
	"alpaca": [CR + AC + "alpaca_model/alpaca.obj", {"tex": CR + AC + "alpaca_model/alpaca1_texture.png"}],
	# ---- reptiles and amphibians
	"rattlesnake": [EL, {"node": "Rattlesnake"}],
	"coral_snake": [EL, {"node": "CoralSnake"}],
	"crocodile": [EL, {"node": "Crocodile"}],
	"alligator": [EL, {"node": "Alligator"}],
	"komodo": [EL, {"node": "KomodoDragon"}],
	"iguana": [EL, {"node": "RockIguana"}],
	"tortoise": [EL, {"node": "Tortoise"}],
	"frog": [EL, {"node": "GreenFrog"}],
	"toad": [EL, {"node": "Toad"}],
	"dragon": [CR + QM + "Dragon.fbx", {"src_root": true}],
	# ---- birds
	"eagle": [EL, {"node": "Eagle", "hover": 0.9}],
	"condor": [EL, {"node": "Condor", "hover": 1.0}],
	"dove": [EL, {"node": "Dove", "hover": 0.8}],
	"snowy_owl": [EL, {"node": "SnowyOwl", "hover": 0.8}],
	"falcon": [EL, {"node": "Falcon", "hover": 0.9}],
	"ptarmigan": [EL, {"node": "Ptarmigan"}],
	# ---- small flyers and crawlers
	"firefly": [EL, {"node": "Firefly", "hover": 0.6}],
	"moth": [EL, {"node": "Moth", "hover": 0.7}],
	"butterfly": [EL, {"node": "MonarchButterfly", "hover": 0.8}],
	"bat": [EL, {"node": "VampireBat", "hover": 0.8}],
	"scorpion": [EL, {"node": "EmperorScorpion"}],
	"snail": [EL, {"node": "Snail"}],
	"slime": [CR + QM + "Slime.fbx", {"src_root": true}],
	# ---- fish (they swim through the air a little above the ground)
	"clownfish": [CR + FP + "Clownfish.glb", {"src_root": true, "hover": 0.5, "yaw": 180.0}],
	"catfish": [CR + FP + "Catfish.glb", {"src_root": true, "hover": 0.5, "yaw": 180.0}],
	"perch": [CR + FP + "Perch.glb", {"src_root": true, "hover": 0.5, "yaw": 180.0}],
	"shark": [CR + "Fish - PolyPack Asset (ALSTRA INFINITE)/SharkV1.fbx", {"src_root": true, "hover": 0.4,
		"tex": CR + "Fish - PolyPack Asset (ALSTRA INFINITE)/PolyPackFish.png", "yaw": 0.0}],
}

var _el_scene: Node = null


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var only := OS.get_cmdline_user_args()
	var src := ProjectSettings.globalize_path("res://psx/")
	for form in FORMS:
		if not only.is_empty() and not only.has(form):
			continue
		var e: Array = FORMS[form]
		var opt: Dictionary = e[1]
		var parts := []
		if e[0] == EL:
			parts = _el_parts(src + CR + EL, String(opt["node"]))
		else:
			parts = _file_parts(src + String(e[0]), opt, src)
		if parts.is_empty():
			push_error("nothing found for " + form)
			continue
		var mesh := _bake(parts, opt)
		if opt.has("hover"):
			mesh.set_meta("hover", float(opt["hover"]))
		var err := ResourceSaver.save(mesh, OUT + form + ".res", ResourceSaver.FLAG_COMPRESS)
		print("  %-16s %5d tris  %s  %s" % [form, _tris(mesh), mesh.get_aabb().size, "ok" if err == OK else "SAVE FAILED"])
	if _el_scene:
		_el_scene.free()
	quit()


# ---------------------------------------------------------------- sources
## [{arrays, material, xf}] for one animal of the Everything Library ("Name" or "Name/mesh").
func _el_parts(path: String, which: String) -> Array:
	if _el_scene == null:
		var d := FBXDocument.new()
		var st := FBXState.new()
		d.append_from_file(path, st)
		_el_scene = d.generate_scene(st)
	var node_name := which.get_slice("/", 0)
	var mesh_name := which.get_slice("/", 1) if "/" in which else ""
	var out := []
	for mi in _el_scene.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		# most animals are a node holding their meshes; a few (the frogs) are a mesh in a shared node
		var hit := inst.get_parent().name == node_name and (mesh_name == "" or inst.name == mesh_name)
		if not hit and inst.name != node_name:
			continue
		# an animal with variants (Lion/alt604, alt605) without a mesh named: take the first one only
		if mesh_name == "" and String(inst.name).begins_with("alt") and not out.is_empty():
			continue
		out.append_array(_mesh_parts(inst, _el_scene))
	return out


func _file_parts(path: String, opt: Dictionary, src: String) -> Array:
	var ext := path.get_extension().to_lower()
	if ext == "obj":
		return _obj_parts(path, src + String(opt.get("tex", "")) if opt.has("tex") else "")
	var sc: Node = null
	if ext in ["glb", "gltf"]:
		var d := GLTFDocument.new()
		var st := GLTFState.new()
		if d.append_from_file(path, st) == OK:
			sc = d.generate_scene(st)
	elif ext == "fbx":
		var d2 := FBXDocument.new()
		var st2 := FBXState.new()
		if d2.append_from_file(path, st2) == OK:
			sc = d2.generate_scene(st2)
	if sc == null:
		return []
	var out := []
	var tex: Texture2D = null
	if opt.has("tex"):
		tex = ImageTexture.create_from_image(Image.load_from_file(src + String(opt["tex"])))
	for mi in sc.find_children("*", "MeshInstance3D", true, false):
		var parts := _mesh_parts(mi as MeshInstance3D, sc)
		if tex != null:
			for p in parts:
				if p["mat"] is BaseMaterial3D and (p["mat"] as BaseMaterial3D).albedo_texture == null:
					var m: BaseMaterial3D = (p["mat"] as BaseMaterial3D).duplicate()
					m.albedo_texture = tex
					m.albedo_color = Color.WHITE
					p["mat"] = m
		out.append_array(parts)
	sc.free()
	return out


## The surfaces of a mesh instance, with their arrays moved into the scene root's space.
func _mesh_parts(inst: MeshInstance3D, top: Node) -> Array:
	var out := []
	if inst.mesh == null:
		return out
	var xf := _xf_to(inst, top)
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
		out.append({"arrays": arrays, "mat": inst.get_active_material(s)})
	return out


## A minimal Wavefront OBJ reader (v, vt, vn, f, usemtl; faces fanned into triangles), one part per material.
func _obj_parts(path: String, tex_path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var vs: Array[Vector3] = []
	var vts: Array[Vector2] = []
	var vns: Array[Vector3] = []
	var groups := {}
	var cur := "default"
	var mtl_tex := {}
	var mtl_file := ""
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		var bits := line.split(" ", false)
		if bits.is_empty():
			continue
		match bits[0]:
			"mtllib":
				mtl_file = path.get_base_dir() + "/" + line.substr(7).strip_edges()
			"v":
				vs.append(Vector3(float(bits[1]), float(bits[2]), float(bits[3])))
			"vt":
				vts.append(Vector2(float(bits[1]), 1.0 - float(bits[2])))
			"vn":
				vns.append(Vector3(float(bits[1]), float(bits[2]), float(bits[3])))
			"usemtl":
				cur = bits[1] if bits.size() > 1 else "default"
			"f":
				if not groups.has(cur):
					groups[cur] = []
				var corners := []
				for k in range(1, bits.size()):
					var idx := bits[k].split("/")
					corners.append([int(idx[0]) - 1, int(idx[1]) - 1 if idx.size() > 1 and idx[1] != "" else -1, int(idx[2]) - 1 if idx.size() > 2 and idx[2] != "" else -1])
				for k in range(1, corners.size() - 1):
					groups[cur].append_array([corners[0], corners[k], corners[k + 1]])
	if mtl_file != "" and FileAccess.file_exists(mtl_file):
		var mf := FileAccess.open(mtl_file, FileAccess.READ)
		var name := ""
		while not mf.eof_reached():
			var l := mf.get_line().strip_edges()
			if l.begins_with("newmtl"):
				name = l.substr(7).strip_edges()
			elif l.begins_with("map_Kd"):
				mtl_tex[name] = mtl_file.get_base_dir() + "/" + l.substr(7).strip_edges().get_file()
	var out := []
	for g in groups:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		var pv := PackedVector3Array()
		var pn := PackedVector3Array()
		var puv := PackedVector2Array()
		for c in groups[g]:
			pv.append(vs[c[0]])
			puv.append(vts[c[1]] if c[1] >= 0 and c[1] < vts.size() else Vector2.ZERO)
			pn.append(vns[c[2]] if c[2] >= 0 and c[2] < vns.size() else Vector3.UP)
		# OBJ winds counter-clockwise; Godot's front faces are clockwise
		for i in range(0, pv.size(), 3):
			var t := pv[i + 1]
			pv[i + 1] = pv[i + 2]
			pv[i + 2] = t
			var tn := pn[i + 1]
			pn[i + 1] = pn[i + 2]
			pn[i + 2] = tn
			var tu := puv[i + 1]
			puv[i + 1] = puv[i + 2]
			puv[i + 2] = tu
		arrays[Mesh.ARRAY_VERTEX] = pv
		arrays[Mesh.ARRAY_NORMAL] = pn
		arrays[Mesh.ARRAY_TEX_UV] = puv
		var m := StandardMaterial3D.new()
		var tp: String = tex_path if tex_path != "" else String(mtl_tex.get(g, ""))
		if tp != "" and FileAccess.file_exists(tp):
			m.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(tp))
		out.append({"arrays": arrays, "mat": m})
	return out


# ---------------------------------------------------------------- bake
## Merges the parts into the beast's mesh: colours into vertex colours or a small texture, then turned, centred and
## scaled into beast space.
func _bake(parts: Array, opt: Dictionary) -> ArrayMesh:
	var bb := AABB()
	var first := true
	for p in parts:
		for v in (p["arrays"][Mesh.ARRAY_VERTEX] as PackedVector3Array):
			bb = AABB(v, Vector3.ZERO) if first else bb.expand(v)
			first = false
	# the Everything Library and the other packs look down +z: turn that to +x
	var yaw := deg_to_rad(float(opt.get("yaw", 90.0)))
	var basis := Basis(Vector3.UP, yaw)
	var turned := AABB()
	first = true
	for c in 8:
		var v := basis * (bb.get_endpoint(c) - bb.get_center())
		turned = AABB(v, Vector3.ZERO) if first else turned.expand(v)
		first = false
	var length := maxf(turned.size.x, turned.size.z)
	var k := 1.0 / maxf(turned.size.y, 0.62 * length)
	var out := ArrayMesh.new()
	for p in parts:
		var arrays: Array = p["arrays"]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in verts.size():
			var v := basis * (verts[i] - bb.get_center())
			verts[i] = Vector3(v.x, v.y - turned.position.y, v.z) * k
		arrays[Mesh.ARRAY_VERTEX] = verts
		if arrays[Mesh.ARRAY_NORMAL] != null:
			var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in ns.size():
				ns[i] = basis * ns[i]
			arrays[Mesh.ARRAY_NORMAL] = ns
		arrays[Mesh.ARRAY_TANGENT] = null
		arrays[Mesh.ARRAY_BONES] = null
		arrays[Mesh.ARRAY_WEIGHTS] = null
		var mat := _beast_material(p["mat"], arrays)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(out.get_surface_count() - 1, mat)
	return out


## A PSX material for one surface. Vertex-coloured surfaces keep their colours in ARRAY_COLOR; flat-coloured ones
## get their colour written there too; textured ones keep a texture of at most 128 px. Transparent parts (insect
## wings) become alpha-scissor cutouts drawn from both sides.
func _beast_material(src: Material, arrays: Array) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.roughness = 1.0
	m.metallic_specular = 0.2
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.vertex_color_use_as_albedo = true
	# the packs' vertex colours (and the gene colours written over them) are sRGB
	m.vertex_color_is_srgb = true
	var n: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var b := src as BaseMaterial3D
	var has_vc: bool = arrays[Mesh.ARRAY_COLOR] != null and b != null and b.vertex_color_use_as_albedo
	var tex: Texture2D = b.albedo_texture if b != null else null
	if tex != null:
		var img := tex.get_image().duplicate()
		if img.is_compressed():
			img.decompress()
		img.clear_mipmaps()
		img.convert(Image.FORMAT_RGBA8)
		if maxi(img.get_width(), img.get_height()) > 128:
			var s := 128.0 / maxi(img.get_width(), img.get_height())
			img.resize(maxi(1, int(img.get_width() * s)), maxi(1, int(img.get_height() * s)), Image.INTERPOLATE_LANCZOS)
		var cut := false
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a < 0.5:
					cut = true
		img.generate_mipmaps()
		m.albedo_texture = ImageTexture.create_from_image(img)
		if cut:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.5
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if not has_vc:
		# the material's own colour (white under a texture) in every vertex
		var col := Color.WHITE if tex != null else (b.albedo_color if b != null else Color(0.7, 0.7, 0.7))
		var cols := PackedColorArray()
		cols.resize(n)
		cols.fill(Color(col, 1.0))
		arrays[Mesh.ARRAY_COLOR] = cols
	if b != null and (b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or String(b.resource_name).contains("Transp") or String(b.resource_name).contains("Wings") or String(b.resource_name).contains("DblSided")):
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if b != null and b.emission_enabled:
		m.emission_enabled = true
		m.emission = b.emission
	return m


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
