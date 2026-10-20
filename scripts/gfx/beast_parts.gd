extends RefCounted
## The new beasts' models (assets/beasts/<form>.res, tools/import_new_beasts.gd) as beast_rig.gd builds them: what
## each one holds, how a merge of two is put together from their parts, and how a look (beast_looks.gd) sets the toon
## shader's colours.
## A merge: one parent gives the frame (the body, and every part the other doesn't give), the other some of its parts
## (head, arms, wings, tail, legs), each set where the frame's own was, or where it would be on the frame's body.

const Looks = preload("res://scripts/data/beast_looks.gd")
const DIR := "res://assets/beasts/"
const PARTS := Looks.PARTS
## the parts a merge can take from the parent that doesn't give the frame
const GROUPS := {"head": ["head"], "arms": ["arm_l", "arm_r"], "wings": ["wing_l", "wing_r"], "tail": ["tail"],
	"legs": ["leg_fl", "leg_fr", "leg_bl", "leg_br"]}

## per form: {mesh, arrays, joints, parents, kind, lo, hi} (lo/hi: each part's bounds)
static var _forms := {}


## How a merge of a and b is put together: {frame, colours, head/arms/wings/tail/legs: the form each comes from}.
## The parent that isn't the frame gives at least one part (two, when it can): a head only onto a frame with a head
## of its own (a face drawn on the body stays the body's), legs only for as many legs.
static func merge_recipe(a: String, b: String, seed_n: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	var frame := a if rng.randf() < 0.5 else b
	var other := b if frame == a else a
	var r := {"frame": frame, "colours": a if rng.randf() < 0.5 else b}
	var fi := info(frame)
	var oi := info(other)
	var can := []
	for g in GROUPS:
		if not has_group(oi, g):
			continue
		if g == "head" and not has_group(fi, "head"):
			continue
		if g == "legs" and (has_group(fi, "legs") != has_group(oi, "legs") or fi["lo"].has("leg_bl") != oi["lo"].has("leg_bl")):
			continue
		can.append(g)
	var order := can.duplicate()
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	var want := mini(order.size(), 2 + (1 if rng.randf() < 0.35 else 0))
	for i in want:
		r[order[i]] = other
	return r


static func has_group(fi: Dictionary, g: String) -> bool:
	for p in GROUPS[g]:
		if fi["lo"].has(p):
			return true
	return false


static func info(f: String) -> Dictionary:
	if _forms.has(f):
		return _forms[f]
	var m: ArrayMesh = load(DIR + f + ".res")
	var arrays := m.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var lo := {}
	var hi := {}
	for i in verts.size():
		var p: String = PARTS[clampi(roundi(cols[i].r * 15.0), 0, PARTS.size() - 1)]
		if not lo.has(p):
			lo[p] = verts[i]
			hi[p] = verts[i]
		else:
			lo[p] = (lo[p] as Vector3).min(verts[i])
			hi[p] = (hi[p] as Vector3).max(verts[i])
	var d := {"mesh": m, "arrays": arrays, "joints": m.get_meta("joints", {}), "parents": m.get_meta("parents", {}),
		"kind": String(m.get_meta("body", "quad")), "lo": lo, "hi": hi}
	_forms[f] = d
	return d


## The frame's joints, and where each part it lacks would join its body (socket()).
static func joints(fi: Dictionary) -> Dictionary:
	var blo: Vector3 = fi["lo"].get("body", Vector3.ZERO)
	var bhi: Vector3 = fi["hi"].get("body", Vector3(0.2, 0.5, 0.2))
	var out := {}
	for p in PARTS:
		out[p] = fi["joints"].get(p, socket(p, blo, bhi))
	return out


## The meshes a beast (recipe: {frame}, or a merge_recipe()) is built from: [{mesh, face}], face: the form whose
## painted eyes it carries ("" for none: a piece without the face).
static func pieces(recipe: Dictionary, frame_joints: Dictionary) -> Array:
	var frame: String = recipe["frame"]
	var fi := info(frame)
	var given := {}
	for g in GROUPS:
		if recipe.has(g) and recipe[g] != frame:
			for p in GROUPS[g]:
				given[p] = recipe[g]
	var donors := [frame]
	for p in given:
		if not given[p] in donors:
			donors.append(given[p])
	var out := []
	for donor in donors:
		var di := info(donor)
		var keep := {}
		var moves := {}
		for p in PARTS:
			if given.get(p, frame) != donor:
				continue
			keep[p] = true
			if donor != frame:
				moves[p] = move(p, fi, di, frame_joints)
		var mesh := cut(di, keep, moves)
		if mesh == null:
			continue
		var face_here: bool = keep.has("head") or not di["lo"].has("head")
		out.append({"mesh": mesh, "face": donor if face_here else ""})
	return out


## Where a part the frame lacks would join it, on its body's bounds.
static func socket(p: String, blo: Vector3, bhi: Vector3) -> Vector3:
	var c := (blo + bhi) / 2.0
	var hw := (bhi.z - blo.z) / 2.0
	var side := -1.0 if p.ends_with("_l") else 1.0
	match p:
		"head":
			return Vector3(lerpf(c.x, bhi.x, 0.6), bhi.y * 0.92, 0.0)
		"arm_l", "arm_r":
			return Vector3(lerpf(c.x, bhi.x, 0.25), lerpf(blo.y, bhi.y, 0.6), side * hw * 0.85)
		"wing_l", "wing_r":
			return Vector3(lerpf(c.x, blo.x, 0.2), lerpf(blo.y, bhi.y, 0.8), side * hw * 0.6)
		"tail":
			return Vector3(lerpf(c.x, blo.x, 0.9), lerpf(blo.y, bhi.y, 0.35), 0.0)
	return c


## How a part a merge takes from donor `di` is set onto the frame `fi` (fj: its joints()): [donor's joint, the
## frame's socket, scale].
## Limbs and tails keep their size against the body halfway; legs are made as long as the frame's, so it stands;
## a head keeps its size against the frame's head halfway.
static func move(p: String, fi: Dictionary, di: Dictionary, fj: Dictionary) -> Array:
	var dj: Dictionary = di["joints"]
	var g := ""
	for k in GROUPS:
		if p in GROUPS[k]:
			g = k
	var src: Vector3 = dj.get(p, Vector3.ZERO)
	var s := 1.0
	var fsz := extent(fi, "body")
	var dsz := extent(di, "body")
	if g == "head":
		fsz = extent(fi, "head")
		dsz = extent(di, "head")
	if g == "legs":
		s = clampf((fj[p] as Vector3).y / maxf(src.y, 0.02), 0.5, 2.0)
	elif dsz > 0.001:
		s = clampf(sqrt(fsz / dsz), 0.6, 1.6)
	return [src, fj[p], s]


static func extent(fi: Dictionary, p: String) -> float:
	if not fi["lo"].has(p):
		return 0.0
	var e: Vector3 = fi["hi"][p] - fi["lo"][p]
	return maxf(e.x, maxf(e.y, e.z))


## The donor's mesh cut down to the parts in `keep` (by the bone each vertex is fixed to, so horns and eyes go with
## the part they're on), those in `moves` set onto the frame ([from, to, scale]).
static func cut(di: Dictionary, keep: Dictionary, moves: Dictionary) -> ArrayMesh:
	var arrays: Array = di["arrays"]
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var n := verts.size()
	var all := true
	var take := PackedInt32Array()
	take.resize(n)
	var count := 0
	for i in n:
		var p: String = PARTS[bones[i * 4]]
		if keep.has(p):
			take[i] = count
			count += 1
		else:
			take[i] = -1
			all = false
	if count == 0:
		return null
	if all and moves.is_empty():
		return di["mesh"]
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	var nv := PackedVector3Array()
	var nn := PackedVector3Array()
	var nc := PackedColorArray()
	var nu := PackedVector2Array()
	var nu2 := PackedVector2Array()
	var nb := PackedInt32Array()
	var nw := PackedFloat32Array()
	var src_n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var src_c: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var src_u: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var src_u2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var src_w: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	for i in n:
		if take[i] < 0:
			continue
		var p: String = PARTS[bones[i * 4]]
		var v := verts[i]
		if moves.has(p):
			var m: Array = moves[p]
			v = (m[1] as Vector3) + (v - (m[0] as Vector3)) * float(m[2])
		nv.append(v)
		nn.append(src_n[i])
		nc.append(src_c[i])
		nu.append(src_u[i])
		nu2.append(src_u2[i])
		for k in 4:
			nb.append(bones[i * 4 + k])
			nw.append(src_w[i * 4 + k])
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var ni := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		var a := take[idx[t]]
		var b := take[idx[t + 1]]
		var c := take[idx[t + 2]]
		if a >= 0 and b >= 0 and c >= 0:
			ni.append_array([a, b, c])
	out[Mesh.ARRAY_VERTEX] = nv
	out[Mesh.ARRAY_NORMAL] = nn
	out[Mesh.ARRAY_COLOR] = nc
	out[Mesh.ARRAY_TEX_UV] = nu
	out[Mesh.ARRAY_TEX_UV2] = nu2
	out[Mesh.ARRAY_BONES] = nb
	out[Mesh.ARRAY_WEIGHTS] = nw
	out[Mesh.ARRAY_INDEX] = ni
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return mesh


## Sets the toon shader's colours from a look (beast_looks.gd), with painted eyes ([] for none).
static func paint(mat: ShaderMaterial, look: Dictionary, eyes: Array) -> void:
	var col: Dictionary = look.get("col", {})
	var tips: Dictionary = look.get("tip", {})
	var stripes: Dictionary = look.get("stripes", {})
	var bands: Dictionary = look.get("bands", {})
	var belly: Array = look.get("belly", [])
	var body := Color(String(col.get("body", "#c8c8c8")))
	var pc := PackedVector3Array()
	var tc := PackedVector3Array()
	var sc := PackedVector3Array()
	var tf := PackedFloat32Array()
	var tt := PackedFloat32Array()
	var ts := PackedFloat32Array()
	var sn := PackedFloat32Array()
	var bn := PackedFloat32Array()
	var bo := PackedFloat32Array()
	for p in PARTS:
		var g: String = Looks.GROUP[p]
		var c := Color(String(col[g])) if col.has(g) else body
		pc.append(lin(c))
		var tip: Array = tips.get(g, [])
		tc.append(lin(Color(String(tip[0]))) if not tip.is_empty() else lin(c))
		tf.append(float(tip[1]) if not tip.is_empty() else 2.0)
		ts.append(float(tip[2]) if not tip.is_empty() else 0.0)
		tt.append(float(tip[3]) if tip.size() > 3 else 1.01)
		var st: Array = stripes.get(g, bands.get(g, []))
		sc.append(lin(Color(String(st[0]))) if not st.is_empty() else lin(c))
		sn.append(float(stripes[g][1]) if stripes.has(g) else 0.0)
		bn.append(float(bands[g][1]) if bands.has(g) else 0.0)
		bo.append(1.0 if belly.size() > 2 and g in belly[2] else 0.0)
	mat.set_shader_parameter("part_col", pc)
	mat.set_shader_parameter("tip_col", tc)
	mat.set_shader_parameter("tip_from", tf)
	mat.set_shader_parameter("tip_to", tt)
	mat.set_shader_parameter("tip_soft", ts)
	mat.set_shader_parameter("stripe_col", sc)
	mat.set_shader_parameter("stripes", sn)
	mat.set_shader_parameter("bands", bn)
	mat.set_shader_parameter("belly_on", bo)
	if belly.size() > 1:
		mat.set_shader_parameter("belly_col", lin(Color(String(belly[0]))))
		mat.set_shader_parameter("belly_from", float(belly[1]))
	var head := Color(String(col["head"])) if col.has("head") else body
	var lid := Color(String(look["lid"])) if look.has("lid") else head.darkened(0.3)
	mat.set_shader_parameter("lid_col", lin(lid))
	if eyes.size() >= 8:
		mat.set_shader_parameter("eye_pos", Vector4(eyes[0], eyes[1], eyes[2], eyes[3]))
		mat.set_shader_parameter("eye_style", Vector4(eyes[4], eyes[5], eyes[6], eyes[7]))
	else:
		mat.set_shader_parameter("eye_pos", Vector4(0, 0, 0, 9))
		mat.set_shader_parameter("eye_style", Vector4(0, 0, 0.5, 0))


static func lin(c: Color) -> Vector3:
	var l := c.srgb_to_linear()
	return Vector3(l.r, l.g, l.b)

