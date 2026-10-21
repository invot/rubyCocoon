extends RefCounted
## The new beasts' models (assets/beasts/<form>.res, tools/import_new_beasts.gd) as beast_rig.gd builds them: what
## each one holds, how a merge of two is put together from their parts, and how a look (beast_looks.gd) sets the toon
## shader's colours.
## A merge: one parent gives the frame (the body, and every part the other doesn't give), the other some of its parts
## (head, arms, wings, tail, legs), each set where the frame's own was, or where it would grow out of the frame's body.
## The models are many overlapping pieces, their parts labelled by boxes, so for merging each part first takes the
## rest of the pieces it's most of (regions()): a claw its arm, a hoof its leg, a head its jaw.

const Looks = preload("res://scripts/data/beast_looks.gd")
const DIR := "res://assets/beasts/"
const PARTS := Looks.PARTS
## the parts a merge can take from the parent that doesn't give the frame
const GROUPS := {"head": ["head"], "arms": ["arm_l", "arm_r"], "wings": ["wing_l", "wing_r"], "tail": ["tail"],
	"legs": ["leg_fl", "leg_fr", "leg_bl", "leg_br"]}
## a part takes the rest of each piece of the model it's at least this much of (but not the piece the body's middle
## is in), and gives up its vertices on one it's less of, unless that's where most of it is
const GROW := 0.2
## how far above its joint a leg grows, and how near the body a part that grew touches it
const LEG_GROW := 0.12
const TOUCH := 0.03
## how far into the frame's body a part given it is set (but legs), and how deep in its body a part's joint can be
## (attach())
const SINK := 0.03
const DEEP := 0.1
## what the labels still get wrong for merging, per form: "slight": groups too slight to swap (the owl's head is only
## its ear tufts, its face being on its body; the cactus's legs are nubs under it); "move": [part, from, lo, hi]: the
## vertices of part `from` in that box are `part`'s (the beetle's beak is its head's, its hands are labelled feet
## and so is the ridge down its back; the crab's front legs are labelled back legs);
## "join": [part, lo, hi]: the pieces of only body in that box are `part`'s (the crab's legs' upper joints)
const FIX := {
	"owl_3": {"slight": ["head"]},
	"cactus_3": {"slight": ["legs"]},
	"beetle_3": {"move": [["head", "body", Vector3(0.15, 0.5, -0.12), Vector3(0.4, 0.7, 0.12)],
		["arm_l", "leg_fl", Vector3(0.1, 0.1, -0.3), Vector3(0.3, 0.32, -0.1)],
		["arm_r", "leg_fr", Vector3(0.1, 0.1, 0.1), Vector3(0.3, 0.32, 0.3)],
		["body", "leg_fl", Vector3(-0.4, 0.0, -0.02), Vector3(-0.07, 0.7, 0.02)],
		["body", "leg_fr", Vector3(-0.4, 0.0, -0.02), Vector3(-0.07, 0.7, 0.02)]]},
	"crab_3": {"move": [["leg_fl", "leg_bl", Vector3(-0.17, -1.0, -1.0), Vector3(1.0, 1.0, 1.0)],
		["leg_fr", "leg_br", Vector3(-0.17, -1.0, -1.0), Vector3(1.0, 1.0, 1.0)]],
		"join": [["leg_fl", Vector3(-0.17, -0.01, -0.4), Vector3(0.05, 0.27, -0.05)],
		["leg_fr", Vector3(-0.17, -0.01, 0.05), Vector3(0.05, 0.27, 0.4)],
		["leg_bl", Vector3(-0.4, -0.01, -0.4), Vector3(-0.17, 0.27, -0.05)],
		["leg_br", Vector3(-0.4, -0.01, 0.05), Vector3(-0.17, 0.27, 0.4)]]},
}

## per form: {form, mesh, arrays, joints, parents, kind, lo, hi} (lo/hi: each part's bounds), and once it's merged,
## regions()
static var _forms := {}


## How a merge of a and b is put together: {frame, colours, head/arms/wings/tail/legs: the form each comes from}.
## The parent that isn't the frame gives two of its parts (three now and then; one if it has no more), bigger ones
## and ones the frame lacks likelier: a head only onto a frame with a head of its own (a face drawn on the body stays
## the body's), legs only onto legs. Which parent gives the frame turns round, mostly, when that lets the other give
## more; and the other mostly gives the colours too when it gives only one part. Everything in it is a String, so it
## keeps as it is (in a merged beast's genes).
static func merge_recipe(a: String, b: String, seed_n: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	var frame := a if rng.randf() < 0.5 else b
	var other := b if frame == a else a
	var can := givable(info(other), info(frame))
	var back := givable(info(frame), info(other))
	if can.size() < mini(2, back.size()) and (can.is_empty() or rng.randf() < 0.7):
		var was := frame
		frame = other
		other = was
		can = back
	var want := mini(can.size(), 2 + (1 if rng.randf() < 0.35 else 0))
	var r := {"frame": frame, "colours": other if rng.randf() < (0.5 if want > 1 else 0.75) else frame}
	for i in want:
		var total := 0.0
		for g in can:
			total += float(can[g])
		var x := rng.randf() * total
		var pick: String = can.keys()[can.size() - 1]
		for g in can:
			x -= float(can[g])
			if x <= 0.0:
				pick = g
				break
		r[pick] = other
		can.erase(pick)
	return r


## What donor `di` can give frame `fi` (info()s): {group: how likely}, by its size against the donor's body, and more
## for what the frame lacks; legs only of about the frame's length (stretched much, they'd look like stilts).
static func givable(di: Dictionary, fi: Dictionary) -> Dictionary:
	var out := {}
	var slight_d: Array = FIX.get(di["form"], {}).get("slight", [])
	var slight_f: Array = FIX.get(fi["form"], {}).get("slight", [])
	for g in GROUPS:
		if not has_group(di, g) or g in slight_d:
			continue
		var lacks: bool = not has_group(fi, g) or g in slight_f
		if lacks and (g == "head" or g == "legs"):
			continue
		if g == "legs" and not legs_fit(fi, di):
			continue
		var big := 0.0
		for p in GROUPS[g]:
			big = maxf(big, size(di, p))
		out[g] = clampf(big / maxf(size(di, "body"), 0.05), 0.2, 1.2) * (1.5 if lacks else 1.0)
	return out


## Whether the donor's legs, stretched to the frame's (leg_stretch()), keep about their shape, and are no more than
## half as thin as the frame's (or they'd look like stilts).
static func legs_fit(fi: Dictionary, di: Dictionary) -> bool:
	var s := clampf(sqrt(size(fi, "body") / maxf(size(di, "body"), 0.05)), 0.6, 1.6)
	for p in GROUPS["legs"]:
		if fi["clo"].has(p):
			var src := leg_from(p, di)
			if src == "":
				return false
			var sy := leg_stretch(p, src, fi, di)
			if sy < 0.5 or sy > 2.0 or girth(di, src) * clampf(s, sy * 0.8, sy * 1.25) < 0.5 * girth(fi, p):
				return false
	return true


## How thick a part is (by regions()): its larger measure across.
static func girth(fi: Dictionary, p: String) -> float:
	var e: Vector3 = fi["chi"][p] - fi["clo"][p]
	return maxf(e.x, e.z)


static func has_group(fi: Dictionary, g: String) -> bool:
	regions(fi)
	for p in GROUPS[g]:
		if fi["clo"].has(p):
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
	var d := {"form": f, "mesh": m, "arrays": arrays, "joints": m.get_meta("joints", {}),
		"parents": m.get_meta("parents", {}), "kind": String(m.get_meta("body", "quad")), "lo": lo, "hi": hi}
	_forms[f] = d
	return d


## Each vertex's part for merging, in fi: "cut" (by the bone it's fixed to, so horns and eyes go with the part
## they're on), each part's bounds by it ("clo", "chi") and where it joins the body ("cj": its joint, or for a part
## that grew, the middle of where it touches the body).
## A part grows to the rest of each piece of the model it's at least GROW of, as the bat's wing tips to the arms they
## end, unless that's the body's middle piece (its middle in the piece's bounds); a piece two parts share goes
## vertex by vertex to the nearer. A leg grows only a little above its joint (LEG_GROW), so it keeps its length: a
## haunch stays the body's.
static func regions(fi: Dictionary) -> void:
	if fi.has("cut"):
		return
	var arrays: Array = fi["arrays"]
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var n := verts.size()
	var lab := PackedInt32Array()
	lab.resize(n)
	var root := PackedInt32Array()
	root.resize(n)
	var blo := Vector3(INF, INF, INF)
	var bhi := -blo
	for i in n:
		lab[i] = bones[i * 4]
		root[i] = i
		if lab[i] == 0:
			blo = blo.min(verts[i])
			bhi = bhi.max(verts[i])
	var mid := (blo + bhi) / 2.0
	var fix: Dictionary = FIX.get(fi["form"], {})
	for fx in fix.get("move", []):
		var to := PARTS.find(fx[0])
		var from := PARTS.find(fx[1])
		for i in n:
			if lab[i] == from and verts[i].clamp(fx[2], fx[3]) == verts[i]:
				lab[i] = to
	# the pieces: vertices joined by triangles
	for t in range(0, idx.size(), 3):
		var top := []
		for k in 3:
			var a := idx[t + k]
			while root[a] != a:
				root[a] = root[root[a]]
				a = root[a]
			top.append(a)
		root[top[1]] = top[0]
		root[top[2]] = top[0]
	var piece := {}
	var cells := {}
	for i in n:
		var a := i
		while root[a] != a:
			a = root[a]
		root[i] = a
		if not piece.has(a):
			piece[a] = []
		piece[a].append(i)
		var c := Vector3i((verts[i] / TOUCH).floor())
		if not cells.has(c):
			cells[c] = []
		cells[c].append(i)
	# a piece of only body in a box of "join" is that part's
	for fx in fix.get("join", []):
		for key in piece:
			var vs: Array = piece[key]
			var inside := true
			for i in vs:
				inside = inside and lab[i] == 0 and verts[i].clamp(fx[1], fx[2]) == verts[i]
			if inside:
				for i in vs:
					lab[i] = PARTS.find(fx[0])
	var total := {}
	for i in n:
		total[lab[i]] = total.get(lab[i], 0) + 1
	var cut := lab.duplicate()
	for key in piece:
		var vs: Array = piece[key]
		var count := {}
		var plo: Vector3 = verts[vs[0]]
		var phi := plo
		for i in vs:
			count[lab[i]] = count.get(lab[i], 0) + 1
			plo = plo.min(verts[i])
			phi = phi.max(verts[i])
		# a part's few vertices on a piece that's mostly another's (and that's not where most of the part is) are
		# that one's
		var most: int = count.keys()[0]
		for k in count:
			if count[k] > count[most]:
				most = k
		for i in vs:
			if count[lab[i]] < GROW * vs.size() and count[lab[i]] < 0.5 * total[lab[i]]:
				cut[i] = most
		if not count.has(0) or mid.clamp(plo, phi) == mid:
			continue
		var grow := []
		for k in count:
			if k != 0 and count[k] >= GROW * vs.size():
				grow.append(k)
		if grow.is_empty():
			continue
		for i in vs:
			if cut[i] != 0:
				continue
			var best: int = grow[0]
			if grow.size() > 1:
				var near := INF
				for j in vs:
					if lab[j] in grow and verts[i].distance_squared_to(verts[j]) < near:
						near = verts[i].distance_squared_to(verts[j])
						best = lab[j]
			if PARTS[best].begins_with("leg_") and fi["joints"].has(PARTS[best]) \
					and verts[i].y > (fi["joints"][PARTS[best]] as Vector3).y + LEG_GROW:
				continue
			cut[i] = best
	# and a piece of only body that touches a part but no other piece of the body (teeth in a claw, a fist on an arm)
	for key in piece:
		var vs: Array = piece[key]
		var touch := {}
		for i in vs:
			if cut[i] != 0:
				touch[-1] = true
				break
			var c := Vector3i((verts[i] / TOUCH).floor())
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					for dz in [-1, 0, 1]:
						for j in cells.get(c + Vector3i(dx, dy, dz), []):
							if root[j] != key and verts[i].distance_to(verts[j]) < TOUCH:
								touch[cut[j]] = true
		if touch.size() == 1 and not touch.has(0) and not touch.has(-1):
			for i in vs:
				cut[i] = touch.keys()[0]
	var clo := {}
	var chi := {}
	var sum := {}
	var grown := {}
	for i in n:
		var p: String = PARTS[cut[i]]
		if not clo.has(p):
			clo[p] = verts[i]
			chi[p] = verts[i]
		clo[p] = (clo[p] as Vector3).min(verts[i])
		chi[p] = (chi[p] as Vector3).max(verts[i])
		sum[p] = sum.get(p, 0) + 1
		if cut[i] != bones[i * 4]:
			grown[p] = grown.get(p, 0) + 1
	# where the parts that grew touch what's left of the body: vertices less than TOUCH from it
	var near_body := {}
	for i in n:
		if cut[i] == 0:
			var c := Vector3i((verts[i] / TOUCH).floor())
			if not near_body.has(c):
				near_body[c] = []
			near_body[c].append(i)
	var cj := {}
	for p in clo:
		if p == "body":
			continue
		if fi["joints"].has(p) and (p.begins_with("leg_") or grown.get(p, 0) < 0.1 * float(sum[p])):
			cj[p] = fi["joints"][p]
			continue
		var k := PARTS.find(p)
		var at := Vector3.ZERO
		var m := 0
		var inner := Vector3.ZERO
		var closest := INF
		for i in n:
			if cut[i] != k:
				continue
			if verts[i].distance_to(mid) < closest:
				closest = verts[i].distance_to(mid)
				inner = verts[i]
			var c := Vector3i((verts[i] / TOUCH).floor())
			var touch := false
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					for dz in [-1, 0, 1]:
						for j in near_body.get(c + Vector3i(dx, dy, dz), []):
							if not touch and verts[i].distance_to(verts[j]) < TOUCH:
								touch = true
			if touch:
				at += verts[i]
				m += 1
		cj[p] = at / float(m) if m >= 3 else inner
	fi["cut"] = cut
	fi["clo"] = clo
	fi["chi"] = chi
	fi["cj"] = cj


## A part's size (its larger measure) by regions().
static func size(fi: Dictionary, p: String) -> float:
	regions(fi)
	if not fi["clo"].has(p):
		return 0.0
	var e: Vector3 = fi["chi"][p] - fi["clo"][p]
	return maxf(e.x, maxf(e.y, e.z))


## The frame's joints, where each of its parts meets its parent (those it lacks: its body's middle). For a merge,
## pieces() then sets those of the parts it's given.
static func joints(fi: Dictionary) -> Dictionary:
	var blo: Vector3 = fi["lo"].get("body", Vector3.ZERO)
	var bhi: Vector3 = fi["hi"].get("body", Vector3(0.2, 0.5, 0.2))
	var out := {}
	for p in PARTS:
		out[p] = fi["joints"].get(p, (blo + bhi) / 2.0)
	return out


## The meshes a beast (recipe: {frame}, or a merge_recipe()) is built from: [{mesh, face}], face: the form whose
## painted eyes it carries ("" for none: a piece without the face). For a merge it also moves frame_joints (joints())
## of the parts given to where each now joins the frame, so the bones built at them bend those parts there.
static func pieces(recipe: Dictionary, frame_joints: Dictionary) -> Array:
	var frame: String = recipe["frame"]
	var fi := info(frame)
	# each part the frame is given: [donor, its part set there]
	var given := {}
	for g in GROUPS:
		if not recipe.has(g) or recipe[g] == frame:
			continue
		var donor := String(recipe[g])
		var di := info(donor)
		regions(fi)
		regions(di)
		for p in GROUPS[g]:
			var src: String = p
			if g == "legs":
				src = leg_from(p, di) if fi["clo"].has(p) else ""
			if di["clo"].has(src):
				given[p] = [donor, src]
	if given.is_empty():
		return [{"mesh": fi["mesh"], "face": frame}]
	var keep := {}
	for p in PARTS:
		if not given.has(p):
			keep[p] = true
	var out := []
	var mesh := cut(fi, keep, {})
	if mesh != null:
		out.append({"mesh": mesh, "face": frame if keep.has("head") or not fi["clo"].has("head") else ""})
	var donors := []
	for p in given:
		if not given[p][0] in donors:
			donors.append(given[p][0])
	for donor in donors:
		var di := info(donor)
		var moves := {}
		for p in given:
			if given[p][0] == donor:
				moves[p] = move(p, given[p][1], fi, di)
				frame_joints[p] = moves[p][2]
		mesh = cut(di, {}, moves)
		if mesh != null:
			out.append({"mesh": mesh, "face": donor if moves.has("head") else ""})
	return out


## The donor's leg set at the frame's leg p: the one on the same side, at the same end if it has one.
static func leg_from(p: String, di: Dictionary) -> String:
	if di["clo"].has(p):
		return p
	var o := p.replace("_f", "_b") if p.begins_with("leg_f") else p.replace("_b", "_f")
	return o if di["clo"].has(o) else ""


## Where a part the frame lacks would grow out of its body (by regions()), on its surface: arms from its sides
## at the shoulders, wings from its back, a tail from its rump, a head on top (for a body longer than it's tall:
## arms low at the front, wings on top).
static func socket(fi: Dictionary, p: String) -> Vector3:
	regions(fi)
	var blo: Vector3 = fi["clo"].get("body", Vector3.ZERO)
	var bhi: Vector3 = fi["chi"].get("body", Vector3(0.2, 0.5, 0.2))
	var c := (blo + bhi) / 2.0
	var e := bhi - blo
	var side := -1.0 if p.ends_with("_l") else 1.0
	var upright := e.y > e.x
	var at := c
	var out := Vector3.UP
	match p:
		"head":
			at = Vector3(lerpf(c.x, bhi.x, 0.5), c.y, 0.0)
		"arm_l", "arm_r":
			at = Vector3(lerpf(c.x, bhi.x, 0.3 if upright else 0.55), lerpf(blo.y, bhi.y, 0.62 if upright else 0.45), 0.0)
			out = Vector3(0.0, 0.0, side)
		"wing_l", "wing_r":
			at = Vector3(c.x if upright else lerpf(c.x, blo.x, 0.15), lerpf(blo.y, bhi.y, 0.75) if upright else c.y,
				side * e.z * 0.25)
			out = Vector3.LEFT if upright else Vector3.UP
		"tail":
			at = Vector3(c.x, lerpf(blo.y, bhi.y, 0.3 if upright else 0.45), 0.0)
			out = Vector3.LEFT
		_:
			return c
	return surface(fi, at, out, maxf(e.x, maxf(e.y, e.z)))


## Where a form's part p joins the outside of its body (by regions()): out from its joint to the body's surface,
## sideways for arms and wings, up for a head, back for a tail (a leg, or a joint outside the body or deeper in it
## than DEEP, where that would be some other bit of it: the joint), so a part set from one form's onto another's sinks
## into the body as deep as it did.
static func attach(fi: Dictionary, p: String) -> Vector3:
	var j: Vector3 = fi["cj"][p]
	if p.begins_with("leg_"):
		return j
	var out := Vector3(0.0, 0.0, -1.0 if p.ends_with("_l") else 1.0)
	if p == "head" or p == "tail":
		out = Vector3.UP if p == "head" else Vector3.LEFT
	var at := surface(fi, j, out, size(fi, "body"))
	return at if (at - j).dot(out) > 0.0 and (at - j).dot(out) < DEEP else j


## A form's body surface (by regions()) out from `at` along `out`: its farthest vertex that way, near that line.
static func surface(fi: Dictionary, at: Vector3, out: Vector3, big: float) -> Vector3:
	var verts: PackedVector3Array = fi["arrays"][Mesh.ARRAY_VERTEX]
	var cut: PackedInt32Array = fi["cut"]
	for r in [0.06, 0.12, 0.25]:
		var far := -INF
		for i in verts.size():
			if cut[i] != 0:
				continue
			var d := verts[i] - at
			var along := d.dot(out)
			if along > far and (d - out * along).length() < r * big:
				far = along
		if far > -INF:
			return at + out * far
	return at


## How the donor's part `src` is set onto the frame's part `p` (where the frame's own joined it, or a socket() on its
## body): [src, from (where it joins the donor: attach()), to, scale]. Limbs, wings and tails keep their size
## against the body halfway (wings new to the frame a little bigger, to be seen, but never much bigger than they
## were), a head a little against the frame's head (but no bigger than its body), on its neck; legs are stretched
## to the frame's (leg_stretch()), their feet on the ground; and nothing else reaches into the ground: it's made
## smaller, then set higher.
static func move(p: String, src: String, fi: Dictionary, di: Dictionary) -> Array:
	var from := attach(di, src)
	var to := attach(fi, p) if fi["cj"].has(p) else socket(fi, p)
	var s := clampf(sqrt(size(fi, "body") / maxf(size(di, "body"), 0.05)), 0.6, 1.6)
	var low: float = (di["clo"][src] as Vector3).y
	if p == "head":
		var dh := maxf(size(di, "head"), 0.05)
		s = minf(clampf(pow(size(fi, "head") / dh, 0.3), 0.7, 1.4), 0.8 * size(fi, "body") / dh)
		# set on the neck, not hanging from it (a boar's, low in front of its chest)
		from.y = minf(from.y, lerpf(low, (di["chi"][src] as Vector3).y, 0.2))
	elif p.begins_with("wing_"):
		s = minf(s * (1.2 if not fi["clo"].has(p) else 1.0), 1.1)
	elif p.begins_with("leg_"):
		var sy := leg_stretch(p, src, fi, di)
		var sx := clampf(s, sy * 0.8, sy * 1.25)
		return [src, from, Vector3(to.x, (from.y - low) * sy, to.z + apart(p, src, di, from.z, to.z, sx)),
			Vector3(sx, sy, sx)]
	# a little into the body, so the seam's hidden
	var mid: Vector3 = (fi["clo"]["body"] + fi["chi"]["body"]) / 2.0
	to = to.move_toward(mid, SINK)
	to.z += apart(p, src, di, from.z, to.z, s)
	var reach := from.y - low
	if reach > 0.01 and to.y - reach * s < 0.01:
		s = maxf((to.y - 0.01) / reach, s * 0.7)
		to.y = maxf(to.y, 0.01 + reach * s)
	return [src, from, to, Vector3(s, s, s)]


## How far to the side to set the donor's part `src` on the frame's part p (at `to`, scaled by `sz` across) so it
## doesn't reach over the middle into its pair (a crab's claws, curled in, on a narrow body): at most a little.
static func apart(p: String, src: String, di: Dictionary, from: float, to: float, sz: float) -> float:
	if not p.ends_with("_l") and not p.ends_with("_r"):
		return 0.0
	var side := -1.0 if p.ends_with("_l") else 1.0
	var inner: float = (di["chi"][src] if side < 0.0 else di["clo"][src]).z
	return clampf(0.02 - side * (to + (inner - from) * sz), 0.0, 0.06) * side


## How much the donor's leg `src` is stretched up and down to be the frame's leg p: from its foot on the ground to
## the frame's joint for it, and at least up into the frame's body over it (hip()).
static func leg_stretch(p: String, src: String, fi: Dictionary, di: Dictionary) -> float:
	var from: Vector3 = di["cj"][src]
	var low: float = (di["clo"][src] as Vector3).y
	var top: float = (di["chi"][src] as Vector3).y
	var to: Vector3 = fi["cj"][p]
	return maxf(to.y / maxf(from.y - low, 0.02), (hip(fi, to) + 0.04) / maxf(top - low, 0.02))


## The underside of the frame's body over its leg's joint `at` (by regions(): its lowest vertex near above it), or
## the joint where the body is lower.
static func hip(fi: Dictionary, at: Vector3) -> float:
	var verts: PackedVector3Array = fi["arrays"][Mesh.ARRAY_VERTEX]
	var cut: PackedInt32Array = fi["cut"]
	for r in [0.04, 0.08, 0.15]:
		var low := INF
		for i in verts.size():
			if cut[i] == 0 and Vector2(verts[i].x - at.x, verts[i].z - at.z).length() < r:
				low = minf(low, verts[i].y)
		if low < INF:
			return maxf(low, at.y)
	return at.y


## The model cut down for a merge (by regions()): the frame keeps the parts in `keep` ({part: true}) as they are;
## a donor gives each in `moves` ({the frame's part: move()}), with the ring of triangles round it where it grew out
## of its own body (so the seam overlaps the frame's rather than gapes), set onto the frame and bent by the frame's
## bone for it, from where it joins (fixed) to a third of its size out (following it).
static func cut(di: Dictionary, keep: Dictionary, moves: Dictionary) -> ArrayMesh:
	var arrays: Array = di["arrays"]
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var src_n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var src_c: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var src_u: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var src_u2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var src_w: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var lab: PackedInt32Array = di["cut"]
	var n := verts.size()
	var nv := PackedVector3Array()
	var nn := PackedVector3Array()
	var nc := PackedColorArray()
	var nu := PackedVector2Array()
	var nu2 := PackedVector2Array()
	var nb := PackedInt32Array()
	var nw := PackedFloat32Array()
	var ni := PackedInt32Array()
	var take := PackedInt32Array()
	take.resize(n)
	if moves.is_empty():
		for i in n:
			take[i] = -1
			if not keep.has(PARTS[lab[i]]):
				continue
			take[i] = nv.size()
			nv.append(verts[i])
			nn.append(src_n[i])
			nc.append(src_c[i])
			nu.append(src_u[i])
			nu2.append(src_u2[i])
			for k in 4:
				nb.append(bones[i * 4 + k])
				nw.append(src_w[i * 4 + k])
		for t in range(0, idx.size(), 3):
			if take[idx[t]] >= 0 and take[idx[t + 1]] >= 0 and take[idx[t + 2]] >= 0:
				ni.append_array([take[idx[t]], take[idx[t + 1]], take[idx[t + 2]]])
	for p in moves:
		var m: Array = moves[p]
		var part := PARTS.find(m[0])
		var from: Vector3 = m[1]
		var to: Vector3 = m[2]
		var sc: Vector3 = m[3]
		var bone := PARTS.find(p)
		var reach := maxf(size(di, m[0]) * 0.3, 0.02)
		take.fill(-1)
		for t in range(0, idx.size(), 3):
			if lab[idx[t]] != part and lab[idx[t + 1]] != part and lab[idx[t + 2]] != part:
				continue
			for k in 3:
				var i := idx[t + k]
				if take[i] < 0:
					take[i] = nv.size()
					var w := smoothstep(0.0, reach, verts[i].distance_to(from)) if lab[i] == part else 0.0
					nv.append(to + (verts[i] - from) * sc)
					nn.append((src_n[i] / sc).normalized())
					nc.append(src_c[i])
					nu.append(src_u[i])
					nu2.append(src_u2[i])
					nb.append_array([bone, 0, 0, 0])
					nw.append_array([w, 1.0 - w, 0.0, 0.0])
				ni.append(take[i])
	if ni.is_empty():
		return null
	var out := []
	out.resize(Mesh.ARRAY_MAX)
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


## Sets the toon shader's colours from a look (beast_looks.gd), with painted eyes: a look's "eyes" (a pair, or an
## array of pairs, one for each face; [] for none).
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
	# the shader's three pairs: [z, y, radius, front x, lid, brow, pupil, look up, (mirror z)] each, radius 0: none
	var pairs: Array = eyes if not eyes.is_empty() and eyes[0] is Array else [eyes]
	var ep := PackedVector4Array()
	var es := PackedVector4Array()
	var em := PackedFloat32Array()
	for i in 3:
		var e: Array = pairs[i] if i < pairs.size() else []
		if e.size() >= 8:
			ep.append(Vector4(e[0], e[1], e[2], e[3]))
			es.append(Vector4(e[4], e[5], e[6], e[7]))
			em.append(float(e[8]) if e.size() > 8 else 0.0)
		else:
			ep.append(Vector4(0, 0, 0, 9))
			es.append(Vector4(0, 0, 0.5, 0))
			em.append(0.0)
	mat.set_shader_parameter("eye_pos", ep)
	mat.set_shader_parameter("eye_style", es)
	mat.set_shader_parameter("eye_mid", em)


static func lin(c: Color) -> Vector3:
	var l := c.srgb_to_linear()
	return Vector3(l.r, l.g, l.b)

