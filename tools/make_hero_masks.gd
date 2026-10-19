extends SceneTree
## Bakes the recolour masks for the bodies the hero can have (voxel_person.gd HERO_BODIES), so the character
## creator's colours can be painted on in the game:
##   godot --headless --path . --script res://tools/make_hero_masks.gd
## For each body, <id>_recolour.res: a resource whose metadata holds "body" and "face", masks the size of its body
## and face textures, each texel saying what it is (0 nothing, 1 top, 2 trousers, 3 hair, 4 iris), and "colours",
## the colour each part has now (voxel_person.gd dress() keeps a texel's shading relative to it).
## Which part of the body a texel paints comes from the bone its triangle hangs from (head, body and arms, legs,
## feet); within that, its colour against the palette people.json keeps (so a white tee under the jacket, the
## shoes and the skin stay as they are). The irises are the colours tools/import_psx_people.gd painted them in.

const DIR := "res://assets/psx/people/"
const BODIES := ["hero", "50_female"]
const MASK_STEP := 50
## the iris colours the people importer paints with
const IRISES := ["#5a3020", "#5a3a22", "#6a4a2a", "#3e2a1c", "#4a6680", "#56704e", "#7a6a3a", "#4a3a2e"]

var pal := {}


func _initialize() -> void:
	pal = JSON.parse_string(FileAccess.get_file_as_string(DIR + "people.json"))
	for id in BODIES:
		_bake(id)
	quit()


func _bake(id: String) -> void:
	var root: Node3D = (load(DIR + id + ".scn") as PackedScene).instantiate()
	var sk: Skeleton3D = root.get_node(root.get_meta("skeleton"))
	var bones: Dictionary = root.get_meta("bones")
	var parts := _parts(sk, bones)
	var p: Dictionary = pal[id]["palette"]
	var col := {"top": Color(p["shirt"]), "trousers": Color(p["pants"]), "hair": Color(p["hair"]), "skin": Color(p["skin"])}
	# the body texture (shared by every part but the face) and the face's own: one mask each, labelled from every mesh
	var body_img: Image = null
	var face_img: Image = null
	var body_mask: Image = null
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	for mi in meshes:
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for si in m.mesh.get_surface_count():
			var mat := m.get_surface_override_material(si) as StandardMaterial3D
			if mat == null or mat.albedo_texture == null:
				continue
			var img := mat.albedo_texture.get_image()
			if img.is_compressed():
				img.decompress()
			if m.mesh.surface_get_name(si) == "face":
				face_img = img
			elif body_img == null:
				body_img = img
	body_mask = Image.create(body_img.get_width(), body_img.get_height(), false, Image.FORMAT_RGBA8)
	body_mask.fill(Color(0, 0, 0, 1))
	for mi in meshes:
		var m := mi as MeshInstance3D
		if m.mesh == null or m.skin == null:
			continue
		for si in m.mesh.get_surface_count():
			if m.mesh.surface_get_name(si) != "face":
				_body_mask(m, si, sk, parts, body_img, body_mask, col)
	_tidy(body_mask, 3)
	_grow(body_mask, body_img, col)
	var res := Resource.new()
	res.set_meta("body", _labels(body_mask))
	print(id, " body mask ", body_img.get_size(), " labelled: ", _counts(body_mask))
	if face_img != null:
		var face_mask := Image.create(face_img.get_width(), face_img.get_height(), false, Image.FORMAT_RGBA8)
		face_mask.fill(Color(0, 0, 0, 1))
		_face_mask(face_img, face_mask, col)
		_tidy(face_mask, 3)
		res.set_meta("face", _labels(face_mask))
		print(id, " face mask ", face_img.get_size(), " labelled: ", _counts(face_mask))
	var out := {}
	for k in ["top", "trousers", "hair"]:
		out[k] = col[k].to_html(false)
	out["eyes"] = col.get("eyes", Color("#5a3020")).to_html(false)
	res.set_meta("colours", out)
	ResourceSaver.save(res, DIR + id + "_recolour.res", ResourceSaver.FLAG_COMPRESS)
	print(id, " source colours ", out)
	root.free()


## Each bone's part of the body: 1 head (and neck), 2 body and arms, 3 legs, 4 feet.
func _parts(sk: Skeleton3D, bones: Dictionary) -> Dictionary:
	var parts := {}
	for i in sk.get_bone_count():
		parts[i] = 2
	var mark := func(start: int, part: int) -> void:
		var stack := [start]
		while not stack.is_empty():
			var b: int = stack.pop_back()
			parts[b] = part
			for c in sk.get_bone_children(b):
				stack.append(c)
	for side in ["l", "r"]:
		mark.call(sk.find_bone(bones[side + "_thigh"]), 3)
		var toe := sk.find_bone(bones[side + "_foot"])
		var ankle := sk.get_bone_parent(toe)
		mark.call(ankle if ankle != sk.find_bone(bones[side + "_shin"]) else toe, 4)
	var head := sk.find_bone(bones["head"])
	mark.call(head, 1)
	parts[sk.get_bone_parent(head)] = 1
	return parts


## Labels the texels a body surface paints: the triangle's part (by its strongest bone), then the texel's colour.
func _body_mask(m: MeshInstance3D, si: int, sk: Skeleton3D, parts: Dictionary, img: Image, mask: Image, col: Dictionary) -> void:
	var arr := m.mesh.surface_get_arrays(si)
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var bns = arr[Mesh.ARRAY_BONES]
	var wts = arr[Mesh.ARRAY_WEIGHTS]
	var idx = arr[Mesh.ARRAY_INDEX]
	if idx == null or (idx as PackedInt32Array).is_empty():
		idx = range(uvs.size())
	var per: int = (bns as Array).size() / maxi(1, uvs.size()) if bns != null else 0
	var size := Vector2(img.get_width(), img.get_height())
	for t in range(0, idx.size() - 2, 3):
		var votes := {}
		for k in 3:
			var v: int = idx[t + k]
			var best := 0
			for j in per:
				if wts[v * per + j] > wts[v * per + best]:
					best = j
			var bind: int = bns[v * per + best]
			var bone := m.skin.get_bind_bone(bind)
			if bone < 0:
				bone = sk.find_bone(m.skin.get_bind_name(bind))
			var part: int = parts.get(bone, 2)
			votes[part] = int(votes.get(part, 0)) + 1
		var part2 := 2
		for k in votes:
			if votes[k] >= 2:
				part2 = k
		var a := _wrap(uvs[idx[t]]) * size
		var b := _wrap(uvs[idx[t + 1]]) * size
		var c := _wrap(uvs[idx[t + 2]]) * size
		var lo := Vector2i(floori(minf(a.x, minf(b.x, c.x))), floori(minf(a.y, minf(b.y, c.y))))
		var hi := Vector2i(ceili(maxf(a.x, maxf(b.x, c.x))), ceili(maxf(a.y, maxf(b.y, c.y))))
		for y in range(maxi(0, lo.y), mini(int(size.y), hi.y + 1)):
			for x in range(maxi(0, lo.x), mini(int(size.x), hi.x + 1)):
				if not _inside(Vector2(x + 0.5, y + 0.5), a, b, c):
					continue
				var px := img.get_pixel(x, y)
				var label := 0
				match part2:
					1:
						if _hair(px, col):
							label = 3
					2:
						if _near(px, col["top"]):
							label = 1
						elif _near(px, col["trousers"]):
							label = 2
					3:
						if _near(px, col["trousers"]):
							label = 2
				if label > 0:
					mask.set_pixel(x, y, Color8(label * MASK_STEP, 0, 0, 255))


## The face's own texture: its hair (a fringe, the brows) and the irises painted on it.
func _face_mask(img: Image, mask: Image, col: Dictionary) -> void:
	# the whites of the eyes: an iris is only ever beside them (and the hair, a fringe, above them)
	var near_white := {}
	var eyes_top := img.get_height()
	for y in img.get_height():
		for x in img.get_width():
			var w := img.get_pixel(x, y)
			if w.v > 0.72 and w.s < 0.22:
				eyes_top = mini(eyes_top, y)
				for dy in range(-3, 4):
					for dx in range(-3, 4):
						near_white[Vector2i(x + dx, y + dy)] = true
	# which iris colour this face was painted with: the one whose shades turn up most beside them
	var best_n := 0
	var best: Array = []
	var best_c := Color("#5a3020")
	for hex in IRISES:
		var shades := _iris_shades(Color(hex))
		var n := 0
		for y in img.get_height():
			for x in img.get_width():
				if near_white.has(Vector2i(x, y)) and _matches(img.get_pixel(x, y), shades):
					n += 1
		if n > best_n:
			best_n = n
			best = shades
			best_c = Color(hex)
	col["eyes"] = best_c
	for y in img.get_height():
		for x in img.get_width():
			var px := img.get_pixel(x, y)
			if not best.is_empty() and near_white.has(Vector2i(x, y)) and _matches(px, best):
				mask.set_pixel(x, y, Color8(4 * MASK_STEP, 0, 0, 255))
			elif y < eyes_top - 3 and _hair(px, col):
				# (not the lashes and pupils round the eyes)
				mask.set_pixel(x, y, Color8(3 * MASK_STEP, 0, 0, 255))


## The shades an iris is painted in (see the people importer's _eye_color): its rim, its gradient and the lid's shadow.
func _iris_shades(iris: Color) -> Array:
	var out := [iris.darkened(0.45), iris.darkened(0.45).darkened(0.3)]
	for i in 11:
		var c := iris.lerp(iris.lightened(0.15), i / 10.0)
		out.append(c)
		out.append(c.darkened(0.3))
	return out


func _matches(c: Color, shades: Array) -> bool:
	for s in shades:
		var sc: Color = s
		if absf(c.r - sc.r) < 0.02 and absf(c.g - sc.g) < 0.02 and absf(c.b - sc.b) < 0.02:
			return true
	return false


## A texel of hair: on dark hair, anything nearer the hair's darkness than the skin's lightness (only hair and skin
## share a head); otherwise a shade of the hair's colour that isn't skin.
func _hair(c: Color, col: Dictionary) -> bool:
	if c.a < 0.5:
		return false
	var hair: Color = col["hair"]
	if hair.v < 0.3:
		return c.v < (hair.v + (col["skin"] as Color).v) / 2.0
	return _near(c, hair) and not _near(c, col["skin"])


## Grows the labels over the seams of the texture's pieces: a texel just outside every triangle (sampled at a
## piece's edge all the same) takes the label of a neighbour it looks like.
func _grow(mask: Image, img: Image, col: Dictionary) -> void:
	var ref := {1: col["top"], 2: col["trousers"]}
	var w := mask.get_width()
	var h := mask.get_height()
	for _pass in 2:
		var add := {}
		for y in h:
			for x in w:
				if roundi(mask.get_pixel(x, y).r * 255.0 / MASK_STEP) != 0:
					continue
				var px := img.get_pixel(x, y)
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = Vector2i(x, y) + d
					if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
						continue
					var l := roundi(mask.get_pixel(n.x, n.y).r * 255.0 / MASK_STEP)
					if (l == 3 and _hair(px, col)) or (ref.has(l) and _near(px, ref[l])):
						add[Vector2i(x, y)] = l
						break
		for q in add:
			mask.set_pixel(q.x, q.y, Color8(add[q] * MASK_STEP, 0, 0, 255))


## Cleans up a label: specks of it too small to be what it labels (a nostril, a seam) dropped, and the gaps inside it
## (texels it mostly surrounds) filled.
func _tidy(mask: Image, label: int, min_size := 12) -> void:
	var w := mask.get_width()
	var h := mask.get_height()
	var is_l := func(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < w and y < h and roundi(mask.get_pixel(x, y).r * 255.0 / MASK_STEP) == label
	var seen := {}
	for y in h:
		for x in w:
			if seen.has(Vector2i(x, y)) or not is_l.call(x, y):
				continue
			var comp := [Vector2i(x, y)]
			seen[Vector2i(x, y)] = true
			var i := 0
			while i < comp.size():
				var q: Vector2i = comp[i]
				i += 1
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = q + d
					if not seen.has(n) and is_l.call(n.x, n.y):
						seen[n] = true
						comp.append(n)
			if comp.size() < min_size:
				for q in comp:
					mask.set_pixel(q.x, q.y, Color(0, 0, 0, 1))
	for _pass in 2:
		var fill := []
		for y in h:
			for x in w:
				if roundi(mask.get_pixel(x, y).r * 255.0 / MASK_STEP) != 0:
					continue
				var n := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if (dx != 0 or dy != 0) and is_l.call(x + dx, y + dy):
							n += 1
				if n >= 5:
					fill.append(Vector2i(x, y))
		for q in fill:
			mask.set_pixel(q.x, q.y, Color8(label * MASK_STEP, 0, 0, 255))


## Whether a texel is a shade of a palette colour: the same hue (for a colour with any saturation) or a pale, greyish
## shade near its brightness (for a nearly white or grey one).
func _near(c: Color, ref: Color) -> bool:
	if c.a < 0.5:
		return false
	if ref.s > 0.22:
		var dh := absf(c.h - ref.h)
		dh = minf(dh, 1.0 - dh)
		return dh < 0.07 and c.s > ref.s * 0.45 and c.v > ref.v * 0.35 and c.v < minf(1.0, ref.v * 2.2)
	return c.s < ref.s + 0.12 and c.v > ref.v * 0.55 and c.v < ref.v * 1.45 + 0.05


func _wrap(uv: Vector2) -> Vector2:
	return Vector2(fposmod(uv.x, 1.0), fposmod(uv.y, 1.0))


func _inside(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 := (p - b).cross(a - b)
	var d2 := (p - c).cross(b - c)
	var d3 := (p - a).cross(c - a)
	var neg := d1 < 0 or d2 < 0 or d3 < 0
	var pos := d1 > 0 or d2 > 0 or d3 > 0
	return not (neg and pos)


## A mask as the game reads it: one byte a texel, the label itself.
func _labels(mask: Image) -> Image:
	var out := PackedByteArray()
	out.resize(mask.get_width() * mask.get_height())
	for y in mask.get_height():
		for x in mask.get_width():
			out[y * mask.get_width() + x] = roundi(mask.get_pixel(x, y).r * 255.0 / MASK_STEP)
	return Image.create_from_data(mask.get_width(), mask.get_height(), false, Image.FORMAT_L8, out)


func _counts(mask: Image) -> Dictionary:
	var out := {}
	for y in mask.get_height():
		for x in mask.get_width():
			var l := roundi(mask.get_pixel(x, y).r * 255.0 / MASK_STEP)
			if l > 0:
				out[l] = int(out.get(l, 0)) + 1
	return out
