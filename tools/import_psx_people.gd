extends SceneTree
## Bakes the PSX people from the character packs in psx/ into assets/psx/people/<id>.scn (see CREDITS.md).
##   godot --headless --path . --script res://tools/import_psx_people.gd [-- id ...]
##
## Every rigged townsperson of "Characters PSX" (Elbolilloduro) that suits the game, plus the hero (yugg0's "Male
## Character"), is kept as it is: its skeleton, skinned mesh and texture, the texture shrunk to PSX size and sampled
## sharp. Each gets anime eyes painted into a face texture of its own (see _face). The scene stands on y = 0, faces +z,
## and remembers its height in metres (meta "height"), its bones by role (meta "bones") and its skeleton (meta
## "skeleton").
## The hero's texture is repainted to his outfit (see _hero_texture).
## people.json lists every person baked: group, whether a woman, height, and the colours of the shirt, trousers, skin
## and hair (read off the texture), so the game can pick the closest person for a look.

const OUT := "res://assets/psx/people/"
const EL := "Characters/Characters PSX (Elbolilloduro)/Characters_psx_1.2/"
## People keep twice the texture size of the scenery (whose textures are 128 px), so their faces read in close-ups.
const TEX_SIZE := 256
## Left out: the pack's horror cast (the Killer_M folder: masked killers, monsters) isn't scanned at all; these don't
## suit a cozy game (swimwear and lingerie, shirtless, hazmat suits and a gas mask) or carry a real sports team's logo.
const EXCLUDE := ["56_female_exotic_dancer", "56_female_exotic_dancer_01", "57_female", "male_56", "male_55", "27_hm",
	"27_female_hm", "28_hm", "28_female_hm"]
## No anime eyes painted on these faces: they wear sunglasses.
const NO_EYES := ["25_female_police", "26_female_police"]
## The older townsfolk (white or grey hair).
const ELDERS := ["29", "30", "31", "32", "29_female", "30_female", "31_female", "32_female", "51_female", "male_43",
	"male_50", "male_51"]

var baked := {}


func _init() -> void:
	var src := ProjectSettings.globalize_path("res://psx/")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var only := OS.get_cmdline_user_args()
	var jobs := []
	for group in ["Male", "Female"]:
		var dir: String = src + EL + "Models/Rig/" + group + "/"
		for f in DirAccess.get_files_at(dir):
			if f.get_extension().to_lower() != "fbx":
				continue
			var id: String = f.get_basename().to_lower().replace("character_", "")
			if id in EXCLUDE:
				continue
			jobs.append({"id": id, "fbx": dir + f, "tex": src + EL + "Textures/" + f.get_basename() + ".png", "group": _group(id)})
	jobs.append({"id": "hero", "fbx": src + "Characters/Male Character - PSX - PS1 (yugg0)/MaleCharacter.fbx",
		"tex": src + "Characters/Male Character - PSX - PS1 (yugg0)/MaleCharacter_Texture.png", "group": "hero"})
	# a partial bake updates the list
	if not only.is_empty() and FileAccess.file_exists(OUT + "people.json"):
		baked = JSON.parse_string(FileAccess.get_file_as_string(OUT + "people.json"))
	for j in jobs:
		if not only.is_empty() and not only.has(j["id"]):
			continue
		var ok := _bake(j)
		print("  %-26s %s" % [j["id"], "ok" if ok else "FAILED"])
	var f := FileAccess.open(OUT + "people.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(baked, "\t"))
	f.close()
	if only.is_empty():
		# drop scenes of people no longer baked
		for fn in DirAccess.get_files_at(OUT):
			if fn.ends_with(".scn") and not baked.has(fn.get_basename()):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(OUT + fn))
				print("  removed ", fn)
	quit()


## Which crowd a character belongs to, by its file name.
func _group(id: String) -> String:
	for k in ["police", "firefighter", "doctor", "sheriff"]:
		if id.contains(k):
			return k
	if id in ELDERS:
		return "elder"
	return "town"


func _bake(j: Dictionary) -> bool:
	var doc := FBXDocument.new()
	var st := FBXState.new()
	if doc.append_from_file(j["fbx"], st) != OK:
		return false
	var scene: Node3D = doc.generate_scene(st)
	# no baked animations: the game poses the bones itself
	for ap in scene.find_children("*", "AnimationPlayer", true, false):
		ap.get_parent().remove_child(ap)
		ap.free()
	var img := Image.load_from_file(j["tex"])
	if img == null:
		return false
	img.convert(Image.FORMAT_RGBA8)
	if j["id"] == "hero":
		_hero_texture(img)
	var sks := scene.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return false
	var sk: Skeleton3D = sks[0]
	var map: Dictionary = MIXAMO if sk.find_bone("mixamorig_Head") >= 0 else RIGIFY
	# the body measured from its own vertices in the rest pose: the soles, the head's chin, nose and crown
	var m := _measure(scene, sk, map)
	var tris := _tris(scene, sk)
	var pal := _palette(sk, map, m, tris, img)
	# the face gets a texture of its own, facing front, with the eyes painted in (see _face)
	var face_img: Image = null if j["id"] in NO_EYES else _face(scene, sk, m, j, img)
	if img.get_width() > TEX_SIZE:
		img.resize(TEX_SIZE, TEX_SIZE, Image.INTERPOLATE_LANCZOS)
	var mat := _material(img)
	var face_mat := _material(face_img) if face_img != null else mat
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var mm := mi as MeshInstance3D
		for si in mm.mesh.get_surface_count():
			mm.set_surface_override_material(si, face_mat if mm.mesh.surface_get_name(si) == "face" else mat)
	var hips: Vector3 = _xf_to(sk, scene) * sk.get_bone_global_rest(sk.find_bone(map["hips"])).origin
	# stand on y = 0, centred over the hips
	var holder := Node3D.new()
	holder.name = "Person"
	holder.add_child(scene)
	var shift := Vector3(hips.x, m["ground"], hips.z)
	scene.position -= shift
	holder.set_meta("height", m["crown"] - m["ground"])
	holder.set_meta("eye", m["eye_y"] - m["ground"])
	holder.set_meta("bones", map)
	holder.set_meta("skeleton", holder.get_path_to(sk))
	_own(holder, holder)
	var packed := PackedScene.new()
	if packed.pack(holder) != OK:
		return false
	var err := ResourceSaver.save(packed, OUT + j["id"] + ".scn", ResourceSaver.FLAG_COMPRESS)
	baked[j["id"]] = {"group": j["group"], "female": String(j["id"]).contains("female"),
		"height": snappedf(m["crown"] - m["ground"], 0.001), "palette": pal}
	holder.free()
	return err == OK


## The bones the game moves, by role, for the two kinds of rig in the packs.
const MIXAMO := {"hips": "mixamorig_Hips", "head": "mixamorig_Head", "head_end": "mixamorig_HeadTop_End",
	"l_arm": "mixamorig_LeftArm", "r_arm": "mixamorig_RightArm", "l_forearm": "mixamorig_LeftForeArm",
	"r_forearm": "mixamorig_RightForeArm", "l_thigh": "mixamorig_LeftUpLeg", "r_thigh": "mixamorig_RightUpLeg",
	"l_shin": "mixamorig_LeftLeg", "r_shin": "mixamorig_RightLeg", "l_foot": "mixamorig_LeftToeBase", "r_foot": "mixamorig_RightToeBase"}
const RIGIFY := {"hips": "pelvis", "head": "head", "head_end": "head_end", "l_arm": "upper_arm_left",
	"r_arm": "upper_arm_right", "l_forearm": "forearm_left", "r_forearm": "forearm_right", "l_thigh": "thigh_left",
	"r_thigh": "thigh_right", "l_shin": "shin.L", "r_shin": "shin.R", "l_foot": "foot_left_end", "r_foot": "foot_right_end"}
## An eye's half-width and half-height, in head heights.
const EYE_W := 0.07
const EYE_H := 0.038
## Iris colours: browns, hazel, grey-blue and green, as people have.
const EYE_COLORS := ["#5a3a22", "#6a4a2a", "#3e2a1c", "#4a6680", "#56704e", "#7a6a3a", "#4a3a2e"]


## The body's rest-pose vertices in the scene's space (y up, facing +z, whatever space the skeleton uses), each tagged
## with whether its main bone is the head (or a bone under it), and from them: the ground under the soles, the
## head's chin and crown, the front of the face (its front-most point below the brow, so no cap brim) and the eye
## line.
func _measure(scene: Node3D, sk: Skeleton3D, map: Dictionary) -> Dictionary:
	var hb := sk.find_bone(map["head"])
	var heads := {hb: true}
	var stack := [hb]
	while not stack.is_empty():
		var bn: int = stack.pop_back()
		for c in sk.get_bone_children(bn):
			heads[c] = true
			stack.append(c)
	var pts := []
	var ground := INF
	var chin := INF
	var crown := -INF
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var mm := mi as MeshInstance3D
		if mm.skin == null or mm.mesh == null:
			continue
		var mxf := _xf_to(mm, scene)
		for si in mm.mesh.get_surface_count():
			var arr := mm.mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones = arr[Mesh.ARRAY_BONES]
			var ws = arr[Mesh.ARRAY_WEIGHTS]
			if bones == null or vs.is_empty():
				continue
			var per: int = bones.size() / vs.size()
			for i in vs.size():
				var best := 0
				for k in per:
					if ws[i * per + k] > ws[i * per + best]:
						best = k
				var bind: int = bones[i * per + best]
				var bone := mm.skin.get_bind_bone(bind)
				if bone < 0:
					bone = sk.find_bone(mm.skin.get_bind_name(bind))
				var p := mxf * sk.get_bone_global_rest(bone) * mm.skin.get_bind_pose(bind) * vs[i]
				ground = minf(ground, p.y)
				var is_head := heads.has(bone)
				pts.append([p, is_head])
				if is_head:
					chin = minf(chin, p.y)
					crown = maxf(crown, p.y)
	var nose := Vector3(0, 0, -INF)
	for q in pts:
		var p: Vector3 = q[0]
		if q[1] and p.y < chin + 0.45 * (crown - chin) and p.z > nose.z:
			nose = p
	# the eyes sit a little below halfway up the head, hair and all (checked against the glasses some wear)
	var hh := crown - chin
	var eye_y := chin + 0.48 * hh
	return {"pts": pts, "heads": heads, "ground": ground, "chin": chin, "crown": crown, "nose": nose, "eye_y": eye_y}


## Every skinned triangle in the rest pose, in the scene's space: its corners, their texture coordinates, and the
## main bone of its first corner.
func _tris(scene: Node3D, sk: Skeleton3D) -> Array:
	var out := []
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var mm := mi as MeshInstance3D
		if mm.skin == null or mm.mesh == null:
			continue
		var mxf := _xf_to(mm, scene)
		for si in mm.mesh.get_surface_count():
			var arr := mm.mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var uvs = arr[Mesh.ARRAY_TEX_UV]
			var bones = arr[Mesh.ARRAY_BONES]
			var ws = arr[Mesh.ARRAY_WEIGHTS]
			if bones == null or uvs == null or vs.is_empty():
				continue
			var per: int = bones.size() / vs.size()
			var idx = arr[Mesh.ARRAY_INDEX]
			if idx == null:
				idx = range(vs.size())
			var pos := PackedVector3Array()
			var bone_of := PackedInt32Array()
			pos.resize(vs.size())
			bone_of.resize(vs.size())
			for i in vs.size():
				var best := 0
				for k in per:
					if ws[i * per + k] > ws[i * per + best]:
						best = k
				var bind: int = bones[i * per + best]
				var bone := mm.skin.get_bind_bone(bind)
				if bone < 0:
					bone = sk.find_bone(mm.skin.get_bind_name(bind))
				bone_of[i] = bone
				pos[i] = mxf * sk.get_bone_global_rest(bone) * mm.skin.get_bind_pose(bind) * vs[i]
			for t in range(0, idx.size() - 2, 3):
				var i0: int = idx[t]
				var i1: int = idx[t + 1]
				var i2: int = idx[t + 2]
				out.append({"p": PackedVector3Array([pos[i0], pos[i1], pos[i2]]),
					"uv": PackedVector2Array([uvs[i0], uvs[i1], uvs[i2]]), "bone": bone_of[i0]})
	return out


## The colours someone wears, read off the texture under the body's faces (weighted by their size): the shirt over
## the spine and upper arms, the trousers over the thighs and shins, the skin of the cheeks and the hair on top.
func _palette(sk: Skeleton3D, map: Dictionary, m: Dictionary, tris: Array, img: Image) -> Dictionary:
	var hb := sk.find_bone(map["head"])
	var hips := sk.find_bone(map["hips"])
	var parts := {}
	# the spine between the hips and the neck
	var neck := sk.get_bone_parent(hb)
	var b := sk.get_bone_parent(neck)
	while b >= 0 and b != hips:
		parts[b] = "shirt"
		b = sk.get_bone_parent(b)
	for role in ["l_arm", "r_arm"]:
		var ab := sk.find_bone(map[role])
		parts[ab] = "shirt"
		var sh := sk.get_bone_parent(ab)
		if sh != neck and sh != hips:
			parts[sh] = "shirt"
	for role in ["l_thigh", "r_thigh", "l_shin", "r_shin"]:
		parts[sk.find_bone(map[role])] = "pants"
	parts[hb] = "head"
	var hh: float = m["crown"] - m["chin"]
	var nose: Vector3 = m["nose"]
	var eye_y: float = m["eye_y"]
	var sums := {"shirt": [Vector3.ZERO, 0.0], "pants": [Vector3.ZERO, 0.0], "skin": [Vector3.ZERO, 0.0], "hair": [Vector3.ZERO, 0.0]}
	var w := img.get_width()
	var h := img.get_height()
	for t in tris:
		var part: String = parts.get(t["bone"], "")
		if part == "":
			continue
		var p: PackedVector3Array = t["p"]
		var c := (p[0] + p[1] + p[2]) / 3.0
		if part == "head":
			if c.y > eye_y + 0.3 * hh:
				part = "hair"
			elif c.y < eye_y and c.y > m["chin"] + 0.15 * hh and c.z > nose.z - 0.3 * hh and absf(c.x - nose.x) < 0.25 * hh:
				part = "skin"
			else:
				continue
		var area := (p[1] - p[0]).cross(p[2] - p[0]).length()
		var uvs: PackedVector2Array = t["uv"]
		var uv := (uvs[0] + uvs[1] + uvs[2]) / 3.0
		var px := posmod(int(uv.x * w), w)
		var py := posmod(int(uv.y * h), h)
		var col := Vector3.ZERO
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var cc := img.get_pixel(clampi(px + dx, 0, w - 1), clampi(py + dy, 0, h - 1))
				col += Vector3(cc.r, cc.g, cc.b) / 9.0
		sums[part][0] += col * area
		sums[part][1] += area
	var out := {}
	for k in sums:
		var tot: float = sums[k][1]
		var v: Vector3 = sums[k][0] / tot if tot > 0.0 else Vector3(0.5, 0.5, 0.5)
		out[k] = Color(v.x, v.y, v.z).to_html(false)
	return out


func _material(img: Image) -> StandardMaterial3D:
	img.generate_mipmaps()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.roughness = 0.95
	mat.metallic_specular = 0.2
	return mat


## Texels per head height on the face's own texture: an eye comes out about a dozen texels across.
const FACE_TEXELS := 64.0


## Gives the front of the face a texture of its own, laid out as seen from the front, and paints anime eyes into it.
## The packs lay faces out every which way (some as two side views, turned on the atlas), which leaves too few, or
## skewed, texels where the eyes go. So the face's front-facing triangles (between the chin and the brow, out to the
## cheeks) move into a new surface named "face" whose texture coordinates are a straight front projection, and its
## texture is filled from the full-size original through each triangle's old coordinates (so the face looks as it did),
## then the eyes are painted texel by texel (see _eye_color), a touch bigger than the model's own, on the eye line
## either side of the nose. Returns the face texture, or null if there was no face to move.
func _face(scene: Node3D, sk: Skeleton3D, m: Dictionary, j: Dictionary, src: Image) -> Image:
	var hh: float = m["crown"] - m["chin"]
	var nose: Vector3 = m["nose"]
	var eye_y: float = m["eye_y"]
	var heads: Dictionary = m["heads"]
	var k := FACE_TEXELS / hh
	var x0 := nose.x - 0.5 * hh
	var y1 := eye_y + 0.5 * hh
	var y0: float = m["chin"] - 0.05 * hh
	var fw := int(ceil(hh * k))
	var fh := int(ceil((y1 - y0) * k))
	var proj := func(q: Vector3) -> Vector2:
		return Vector2((q.x - x0) * k, (y1 - q.y) * k)
	var face := Image.create(fw, fh, false, Image.FORMAT_RGBA8)
	var filled := PackedByteArray()
	filled.resize(fw * fh)
	var ssize := Vector2(src.get_width(), src.get_height())
	var moved := 0
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var mm := mi as MeshInstance3D
		if mm.skin == null or not (mm.mesh is ArrayMesh) or (mm.mesh as ArrayMesh).get_blend_shape_count() > 0:
			continue
		var mesh := mm.mesh as ArrayMesh
		var mxf := _xf_to(mm, scene)
		var keep := []
		var faces := []
		for si in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(si)
			var flags := mesh.surface_get_format(si) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var uvs = arr[Mesh.ARRAY_TEX_UV]
			var bones = arr[Mesh.ARRAY_BONES]
			var ws = arr[Mesh.ARRAY_WEIGHTS]
			for c in range(Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM3 + 1):
				arr[c] = null
			if bones == null or uvs == null or vs.is_empty():
				keep.append([arr, flags])
				continue
			var per: int = bones.size() / vs.size()
			var idx = arr[Mesh.ARRAY_INDEX]
			if idx == null:
				idx = PackedInt32Array(range(vs.size()))
			var pos := PackedVector3Array()
			var head := PackedByteArray()
			pos.resize(vs.size())
			head.resize(vs.size())
			for i in vs.size():
				var best := 0
				for c in per:
					if ws[i * per + c] > ws[i * per + best]:
						best = c
				var bind: int = bones[i * per + best]
				var bone := mm.skin.get_bind_bone(bind)
				if bone < 0:
					bone = sk.find_bone(mm.skin.get_bind_name(bind))
				head[i] = 1 if heads.has(bone) else 0
				pos[i] = mxf * sk.get_bone_global_rest(bone) * mm.skin.get_bind_pose(bind) * vs[i]
			var rest := PackedInt32Array()
			var mine := PackedInt32Array()
			for t in range(0, idx.size() - 2, 3):
				var a: int = idx[t]
				var b: int = idx[t + 1]
				var c: int = idx[t + 2]
				var on := head[a] == 1 and head[b] == 1 and head[c] == 1
				if on:
					# front-facing, and inside the face's box
					var n := (pos[b] - pos[a]).cross(pos[c] - pos[a]).normalized()
					var cc := (pos[a] + pos[b] + pos[c]) / 3.0
					on = absf(n.z) > 0.35 and cc.z > nose.z - 0.3 * hh and absf(cc.x - nose.x) < 0.36 * hh \
						and cc.y > m["chin"] + 0.04 * hh and cc.y < eye_y + 0.36 * hh
					for q in [pos[a], pos[b], pos[c]]:
						var f: Vector2 = proj.call(q)
						on = on and f.x >= 0.0 and f.y >= 0.0 and f.x <= fw and f.y <= fh
				if on:
					mine.append_array([a, b, c])
				else:
					rest.append_array([a, b, c])
			if mine.is_empty():
				keep.append([arr, flags])
				continue
			arr[Mesh.ARRAY_INDEX] = rest
			keep.append([arr, flags])
			# the face's own surface: its vertices copied, with front-projected texture coordinates
			var remap := {}
			var order := PackedInt32Array()
			var fidx := PackedInt32Array()
			for v in mine:
				if not remap.has(v):
					remap[v] = order.size()
					order.append(v)
				fidx.append(remap[v])
			var farr := []
			farr.resize(Mesh.ARRAY_MAX)
			for a in Mesh.ARRAY_MAX:
				if a == Mesh.ARRAY_INDEX or arr[a] == null:
					continue
				var src_arr = arr[a]
				var each: int = src_arr.size() / vs.size()
				var out = src_arr.duplicate()
				out.resize(order.size() * each)
				for n in order.size():
					for e in each:
						out[n * each + e] = src_arr[order[n] * each + e]
				farr[a] = out
			var fuv := PackedVector2Array()
			for v in order:
				fuv.append((proj.call(pos[v]) as Vector2) / Vector2(fw, fh))
			farr[Mesh.ARRAY_TEX_UV] = fuv
			farr[Mesh.ARRAY_INDEX] = fidx
			faces.append([farr, flags])
			moved += mine.size() / 3
			# fill the face texture from the original, through each triangle's old coordinates
			for t in range(0, mine.size(), 3):
				var q := [proj.call(pos[mine[t]]), proj.call(pos[mine[t + 1]]), proj.call(pos[mine[t + 2]])]
				var o := [uvs[mine[t]] * ssize, uvs[mine[t + 1]] * ssize, uvs[mine[t + 2]] * ssize]
				_fill(face, filled, q, o, src)
		if faces.is_empty():
			continue
		mesh.clear_surfaces()
		for sf in keep + faces:
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sf[0], [], {}, sf[1])
		for f in faces.size():
			mesh.surface_set_name(keep.size() + f, "face")
	if moved == 0:
		return null
	_dilate(face, filled, 2)
	# the eyes, on the face's own texels
	var female: bool = j["group"] in ["female", "dancer"] or String(j["id"]).contains("female")
	var iris := Color(EYE_COLORS[absi(String(j["id"]).hash()) % EYE_COLORS.size()])
	if j["id"] == "hero":
		iris = Color("#5a3020")
	# a little bigger than life: about a seventh of the head wide, an eye's width apart
	var rx := EYE_W * hh
	var ry := EYE_H * hh
	var spread := 0.14 * hh
	for ty in fh:
		for tx in fw:
			var x := x0 + (tx + 0.5) / k
			var y := y1 - (ty + 0.5) / k
			for side in [-1.0, 1.0]:
				# u runs out from the nose towards the outer corner, v down the face
				var base := face.get_pixel(tx, ty)
				var col := _eye_color((x - (nose.x + side * spread)) * side / rx, (eye_y - y) / ry, iris, female, base)
				if col != base:
					face.set_pixel(tx, ty, col)
	return face


## Fills the texels of one triangle (corners q, in texels) from the source image at the matching points of its old
## texture coordinates (corners o, in source pixels), averaging a 2 x 2 patch there.
func _fill(img: Image, filled: PackedByteArray, q: Array, o: Array, src: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var q0: Vector2 = q[0]
	var q1: Vector2 = q[1]
	var q2: Vector2 = q[2]
	var den := (q1.y - q2.y) * (q0.x - q2.x) + (q2.x - q1.x) * (q0.y - q2.y)
	if absf(den) < 1e-6:
		return
	var sw := src.get_width()
	var sh := src.get_height()
	for py in range(maxi(0, int(floor(minf(q0.y, minf(q1.y, q2.y))))), mini(h, int(ceil(maxf(q0.y, maxf(q1.y, q2.y)))) + 1)):
		for px in range(maxi(0, int(floor(minf(q0.x, minf(q1.x, q2.x))))), mini(w, int(ceil(maxf(q0.x, maxf(q1.x, q2.x)))) + 1)):
			var sx := px + 0.5
			var sy := py + 0.5
			var b0 := ((q1.y - q2.y) * (sx - q2.x) + (q2.x - q1.x) * (sy - q2.y)) / den
			var b1 := ((q2.y - q0.y) * (sx - q2.x) + (q0.x - q2.x) * (sy - q2.y)) / den
			var b2 := 1.0 - b0 - b1
			if b0 < -0.01 or b1 < -0.01 or b2 < -0.01:
				continue
			var at: Vector2 = o[0] * b0 + o[1] * b1 + o[2] * b2
			var ix := posmod(int(floor(at.x - 0.5)), sw)
			var iy := posmod(int(floor(at.y - 0.5)), sh)
			var c := (src.get_pixel(ix, iy) + src.get_pixel((ix + 1) % sw, iy) + src.get_pixel(ix, (iy + 1) % sh)
				+ src.get_pixel((ix + 1) % sw, (iy + 1) % sh)) / 4.0
			img.set_pixel(px, py, Color(c.r, c.g, c.b, 1.0))
			filled[py * w + px] = 1


## Grows the filled texels outwards a few times, so sampling at the island's edges finds face colours, not black.
func _dilate(img: Image, filled: PackedByteArray, times: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for n in times:
		var add := []
		for y in h:
			for x in w:
				if filled[y * w + x] == 1:
					continue
				var sum := Color(0, 0, 0, 0)
				var cnt := 0
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + d.x
					var ny: int = y + d.y
					if nx >= 0 and ny >= 0 and nx < w and ny < h and filled[ny * w + nx] == 1:
						sum += img.get_pixel(nx, ny)
						cnt += 1
				if cnt > 0:
					add.append([x, y, sum / cnt])
		for a in add:
			img.set_pixel(a[0], a[1], a[2])
			filled[a[1] * w + a[0]] = 1


## The colour of an eye at (u, v) over the face's own colour `base`: u across the eye (-1 inner corner, 1 outer), v down
## it (-1 top, 1 bottom); outside the eye `base` comes back as it was. Drawn plainly, as a lifelike eye a touch larger
## than life: an almond, its top arching highest a little towards the nose, a flatter bottom; a round iris tucked
## under the upper lid, a darker rim, a dark pupil and one glint; whites shaded towards the corners and under the lid;
## a fine dark upper lash line (fuller at the outer corner, more so on women), a soft lower lid and a faint crease.
func _eye_color(u: float, v: float, iris: Color, female: bool, base: Color) -> Color:
	if u < -1.0 or u > 1.2:
		return base
	var uu := clampf(u, -1.0, 1.0)
	var arc := sqrt(1.0 - uu * uu)
	var top := -arc * (1.0 - 0.1 * uu)
	var bot := 0.62 * arc
	var lash := (0.34 + 0.3 * maxf(0.0, uu)) * (1.25 if female else 1.0)
	if absf(u) <= 1.0 and v >= top and v <= bot:
		# the iris is round on the face: its radius half the eye's half-width, in both directions
		var ri := 0.5
		var rv := ri * EYE_W / EYE_H
		var cv := -0.2
		var d := sqrt(pow(u / ri, 2) + pow((v - cv) / rv, 2))
		if d <= 1.0:
			if absf(u - 0.16) < 0.14 and absf(v - cv + 0.32) < 0.26:
				return Color("#f4f0ea")
			if d < 0.42:
				return iris.darkened(0.82)
			var c := iris.darkened(0.45) if d > 0.8 else iris.lerp(iris.lightened(0.15), clampf((v - cv) / rv, 0.0, 1.0))
			# the lid's shadow over the top of the iris
			return c.darkened(0.3) if v < top + 0.35 else c
		var white := Color("#ece6de").lerp(base, 0.2 + 0.3 * absf(u))
		return white.darkened(0.18) if v < top + 0.35 else white
	if absf(u) <= 1.0 and v < top and v >= top - lash:
		return base.darkened(0.78).lerp(Color("#2a1c18"), 0.5)
	# the lash line runs a little past the outer corner
	if u > 1.0 and v >= -0.3 - lash and v <= -0.3 + (0.1 if female else 0.0):
		return base.darkened(0.7).lerp(Color("#2a1c18"), 0.4)
	if absf(u) <= 1.0 and v > bot and v <= bot + 0.35:
		return base.darkened(0.14)
	if absf(u) <= 0.9 and v < top - lash and v >= top - lash - 0.6:
		return base.darkened(0.07)
	return base


func _own(n: Node, owner_node: Node) -> void:
	for c in n.get_children():
		c.owner = owner_node
		_own(c, owner_node)


func _xf_to(node: Node3D, top: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = node
	while cur != null and cur != top:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


## The hero's outfit painted over yugg0's texture (256 x 256; regions read off the texture): his red polo becomes a
## red jacket hanging open over a white shirt, its hem down over the waistband, where a brown belt with a silver
## buckle shows in the opening; the black trousers become blue jeans; the bare forearms get the jacket's long
## sleeves and darker cuffs; the brown shoes become red sneakers with white soles. Shading is kept throughout.
func _hero_texture(img: Image) -> void:
	var red := Color("#b8283a")
	var white := Color("#f2efe8")
	var denim := Color("#34507e")
	var leather := Color("#4a3020")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bg := func(c: Color) -> bool:
		return absf(c.r - c.g) < 0.04 and absf(c.g - c.b) < 0.04 and c.r > 0.26 and c.r < 0.4
	var shade := func(base: Color, c: Color, mean: float) -> Color:
		var k := clampf(c.get_luminance() / mean, 0.7, 1.25)
		return Color(clampf(base.r * k, 0, 1), clampf(base.g * k, 0, 1), clampf(base.b * k, 0, 1), c.a)
	# the shirt panels' mean brightness, to keep the folds' shading when recolouring
	var torso_mean := 0.22
	var pants_mean := 0.1
	for y in 256:
		for x in 256:
			var c := img.get_pixel(x, y)
			if bg.call(c):
				continue
			var front := x < 71 and y < 96
			var back := x >= 71 and x < 143 and y < 96
			if front:
				# the jacket hangs open: a white shirt down the middle, darker lapel edges either side
				var dx := absf(x - 35.0)
				if y > 22 and dx < 10.0:
					img.set_pixel(x, y, shade.call(white, c, torso_mean) if c.r > 0.3 else white.darkened(0.08))
				elif y > 18 and dx < 12.0:
					img.set_pixel(x, y, red.darkened(0.3))
				else:
					img.set_pixel(x, y, shade.call(red, c, torso_mean))
			elif back:
				img.set_pixel(x, y, shade.call(red, c, torso_mean))
			elif x < 143 and y >= 96 and y < 122:
				# the waistband: the jacket's hem over it, the belt in the opening at the front, jeans below
				var dx2 := absf(x - 35.0)
				if y < 102 and not (x < 71 and dx2 < 11.0):
					img.set_pixel(x, y, red.darkened(0.12 if (x + y) % 2 == 0 else 0.2))
				elif y < 103 and x < 71:
					img.set_pixel(x, y, Color("#c8c8d0") if dx2 < 2.0 else leather.lightened(0.05 * float((x * 3) % 2)))
				else:
					img.set_pixel(x, y, shade.call(denim, c, pants_mean))
			elif x < 96 and y >= 110:
				img.set_pixel(x, y, shade.call(denim, c, pants_mean))
			elif x >= 92 and x < 177 and y >= 110 and not (x > 145 and y < 118):
				# the arms: red all the way down now, with a darker cuff near the wrist
				if y > 236:
					img.set_pixel(x, y, red.darkened(0.25))
				elif c.r > c.b + 0.08:
					img.set_pixel(x, y, shade.call(red, c, 0.25) if y < 165 else red.darkened(rng.randf_range(0.0, 0.08)))
			elif x >= 166 and y >= 210 and c.r > c.b + 0.05:
				# sneakers: red uppers, white soles and laces
				var l := c.get_luminance()
				img.set_pixel(x, y, white if l > 0.42 or y > 250 or (y > 232 and y < 236) else shade.call(Color("#d8283a"), c, 0.25))
