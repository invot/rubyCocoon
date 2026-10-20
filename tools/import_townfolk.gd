extends SceneTree
## Bakes the townsfolk from the "townfolk collection" kit (new models/townfolk collection: 770 OBJ pieces in
## centimetres and one swatch texture, no rig) into assets/townfolk/ (see scripts/gfx/townfolk.gd):
##   godot --headless --path . --script res://tools/import_townfolk.gd
##
## The kit is 80 people, each a run of pieces in the files' order (arms, legs, neck, head, hair, hat, glasses, top,
## bottoms, shoes...; every run starts at its legs, or the bare arms just before them), all on one body in a T pose.
## Each distinct piece becomes a part (assets/townfolk/parts/<n>.res): a mesh in metres (the legs drawn longer, see
## townfolk.gd fit), skinned to the shared skeleton by where each vertex sits on the body (see _weights), with its
## colour slots (see _colour). townfolk.json
## lists the parts (kind) and the people (their parts and tags), "extras": parts for outfits of our own (the
## trainers' camo jacket, see _extras), by name, and "packs": the packs to wear on the back (see _packs).
## The swatch texture doesn't line up with the pieces (the kit's material files are missing), so only its colours'
## families are used: which triangles are the skin, the eyes, a shirt's main colour or its trim.

const OBJ = preload("res://tools/townfolk/obj.gd")
const TF = preload("res://scripts/gfx/townfolk.gd")
const OUT := "res://assets/townfolk/"
const TEXTURE := "65588_STYLIZED_CHARACTERS_TEXTURE.png"
## The kit's people in costume (animal hoods, helmets, a crown...): not for the everyday townsfolk.
const NOVELTY := [24, 38, 42, 47, 48, 49, 50, 51, 53, 55, 64, 65, 70]
## Pieces that are hair though they sit like a hat (two buns).
const HAIR_PIECES := [307]
## The kit's pieces the trainers' camo outfit is made of (townfolk.gd outfit "camo"): its boots as they are; a plain
## long-sleeved top and long trousers padded out into a jacket and combat trousers (see _extras): [piece, padding cm].
const CAMO_PIECES := {"camo_boots": 677}
const CAMO_PADDED := {"camo_jacket": [691, 1.8, "top"], "camo_trousers": [762, 1.0, "bottom"]}
## The packs, from new models/backpack (its OBJ pieces lie in a row on the ground, fronts to +x; no colours, so each
## piece is given one): name, pieces (the first the body, coloured as the look's "pack" says), the others' colours,
## the body's own colour, how it's worn ("back": up between the shoulders on two shoulder straps; "sling": lower
## down, on a strap across the chest), its size (height in the kit's cm, or width if "wide"), and how high its top
## sits. (Left out: the telescope, a drawstring sack too finely made for a phone, and a bedroll pack that hangs off
## its own loop.)
const PACK_DIR := "res://new models/backpack/"
const PACKS := [
	{"name": "Rucksack", "pieces": [16, 17], "trim": ["#4a3624"], "colour": "#6a7a4a", "wear": "back", "size": 40.0, "top": 98.0},
	{"name": "Hiking pack", "pieces": [28, 27, 30, 29], "trim": ["#a8442e", "#c89a3a", "#2e3e4e"], "colour": "#3e6a8a", "wear": "back", "size": 44.0, "top": 99.0},
	{"name": "Day pack", "pieces": [23, 24], "trim": ["#8a2a2a"], "colour": "#c84040", "wear": "back", "size": 36.0, "top": 97.0},
	{"name": "Gadget pack", "pieces": [34, 33, 31, 32], "trim": ["#3a3a40", "#8a9aa0", "#e0c050"], "colour": "#c86a30", "wear": "back", "size": 36.0, "top": 97.0},
	{"name": "Sling bag", "pieces": [22, 21], "trim": ["#2a2a34"], "colour": "#4a6aa0", "wear": "sling", "size": 38.0, "top": 92.0},
	{"name": "Satchel", "pieces": [14, 15, 13], "trim": ["#6a4226", "#c8b060"], "colour": "#8a5a32", "wear": "sling", "size": 22.0, "top": 74.0},
	{"name": "Messenger bag", "pieces": [10, 12, 11], "trim": ["#5a4630", "#c8b060"], "colour": "#3e5a3a", "wear": "sling", "size": 24.0, "top": 75.0},
	{"name": "Duffel bag", "pieces": [1, 0], "trim": ["#c8a040"], "colour": "#2e4a6a", "wear": "sling", "size": 44.0, "wide": true, "top": 84.0},
]
## Where a worn pack's back meets the wearer (z, the kit's cm: just behind a padded jacket).
const PACK_BACK := -15.0
## The straps' colour.
const STRAP := "#3a2e26"

var img: Image
var pieces := {}


func _init() -> void:
	img = Image.load_from_file(ProjectSettings.globalize_path(OBJ.DIR + TEXTURE))
	for n in range(4, 769):
		var text := FileAccess.get_file_as_string(OBJ.DIR + "model_%d.obj" % n)
		if text == "":
			continue
		var d := OBJ.read(n)
		var box := AABB(d["v"][0], Vector3.ZERO)
		for p in d["v"]:
			box = box.expand(p)
		pieces[n] = {"d": d, "box": box, "key": text.substr(text.find("\nv ")).md5_text()}
	var groups := _groups()
	print("people: ", groups.size())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "parts"))
	var parts := []
	var by_key := {}
	var people := []
	for gi in groups.size():
		var ids := []
		var tags := {}
		for n in groups[gi]:
			var pc: Dictionary = pieces[n]
			var kind := "hair" if n in HAIR_PIECES else _kind(pc["box"])
			if not by_key.has(pc["key"]):
				by_key[pc["key"]] = parts.size()
				parts.append({"kind": kind, "file": "p%03d" % parts.size(), "piece": n})
			var id: int = by_key[pc["key"]]
			ids.append(id)
			tags[kind] = true
			# hair down past the chin (a bob, or longer)
			if kind == "hair" and (pc["box"] as AABB).position.y < 97.0:
				tags["long_hair"] = true
			if kind == "top" and (pc["box"] as AABB).position.y < 35.0:
				tags["dress"] = true
			if kind in ["top", "bottom"] and _skirt(pc["d"], pc["box"]):
				tags["skirt"] = true
			if kind == "top" and (pc["box"] as AABB).end.x > 55.0:
				tags["sleeves"] = true
		if gi in NOVELTY:
			tags["novelty"] = true
		people.append({"parts": ids, "tags": tags.keys()})
	var extras := {}
	for name in CAMO_PIECES:
		extras[name] = by_key[pieces[CAMO_PIECES[name]]["key"]]
	for e in _extras():
		extras[e["name"]] = parts.size()
		parts.append({"kind": e["kind"], "file": "p%03d" % parts.size(), "made": e})
	var packs := []
	for pk in PACKS:
		var ids := []
		for e in _packs(pk):
			ids.append(parts.size())
			parts.append({"kind": e["kind"], "file": "p%03d" % parts.size(), "made": e})
		packs.append({"name": pk["name"], "parts": ids, "colour": pk["colour"]})
	for i in parts.size():
		var part: Dictionary = parts[i]
		var mesh := _bake(part["made"] if part.has("made") else pieces[part["piece"]], part["kind"])
		ResourceSaver.save(mesh, OUT + "parts/" + part["file"] + ".res", ResourceSaver.FLAG_COMPRESS)
	var out := FileAccess.open(OUT + "townfolk.json", FileAccess.WRITE)
	out.store_string(JSON.stringify({"parts": parts.map(func(p: Dictionary) -> Dictionary: return {"kind": p["kind"], "file": p["file"]}),
		"people": people, "extras": extras, "packs": packs}, "\t"))
	out.close()
	print("parts: ", parts.size())
	quit()


## Parts of our own, made here in the kit's centimetres for the trainers' camo jacket: [{"name", "kind", "d" (as
## obj.gd reads a piece, with "slots": each triangle's colour slot), "box"}].
##   jacket and trousers: CAMO_PADDED's kit pieces puffed out (each vertex pushed out along its normal; not the hands);
##   collar: the jacket's big padded collar, standing up round the neck to the jaw, highest at the back and flaring
##   out wide, open at the front with its ends turned out (camo outside, plain inside, see townfolk.gdshader slot 8);
##   belt: a dark belt round the waist with a grey buckle.
func _extras() -> Array:
	var out := []
	for name in CAMO_PADDED:
		var spec: Array = CAMO_PADDED[name]
		var d: Dictionary = (pieces[spec[0]]["d"] as Dictionary).duplicate(true)
		var v: PackedVector3Array = d["v"]
		var nv := PackedVector3Array()
		nv.resize(v.size())
		var tri: PackedInt32Array = d["tri"]
		var ntri: PackedInt32Array = d["ntri"]
		for c in ntri.size():
			if ntri[c] >= 0:
				nv[tri[c * 2]] += d["n"][ntri[c]]
		for i in v.size():
			v[i] += nv[i].normalized() * float(spec[1]) * (1.0 - smoothstep(46.0, 50.0, absf(v[i].x)))
		d["v"] = v
		# all of it the jacket's (or trousers') colour, for the camo; a jacket's hands bare
		var slots := []
		for t in range(0, tri.size(), 6):
			var at := (v[tri[t]] + v[tri[t + 2]] + v[tri[t + 4]]) / 3.0
			slots.append([1, 1.0] if spec[2] == "top" and absf(at.x) > 51.5 else [4 if spec[2] == "top" else 5, 1.0])
		d["slots"] = slots
		var box := AABB(v[0], Vector3.ZERO)
		for p in v:
			box = box.expand(p)
		out.append({"name": name, "kind": spec[2], "d": d, "box": box})
	# the collar: rows from its foot on the shoulders to its rim, round from one front end to the other
	var m := _Mesh.new()
	var th0 := 0.78
	var rows := 6
	var cols := 22
	var ring := func(th: float, v: float, inset: float) -> Vector3:
		var top := 102.0 + 10.0 * (1.0 - cos(th)) / 2.0
		var y := lerpf(88.0, top, v)
		var e := pow(v, 1.15)
		var rx := lerpf(17.0, 27.5, e) - inset
		var rz := lerpf(13.5, 25.0, e) - inset
		# the front ends turn outward toward the rim
		var turn := 1.0 + 0.3 * v * (smoothstep(th0 + 0.7, th0, th) + smoothstep(TAU - th0 - 0.7, TAU - th0, th))
		return Vector3(sin(th) * rx * turn, y, cos(th) * rz * turn + 1.0)
	var outer := []
	var inner := []
	for r in rows + 1:
		var o := []
		var i := []
		for c in cols + 1:
			var th := lerpf(th0, TAU - th0, c / float(cols))
			o.append(ring.call(th, r / float(rows), 0.0))
			i.append(ring.call(th, r / float(rows), 2.6))
		outer.append(o)
		inner.append(i)
	for r in rows:
		for c in cols:
			# outside facing out, inside facing in (toward the neck)
			m.quad(outer[r][c], outer[r][c + 1], outer[r + 1][c + 1], outer[r + 1][c], [4, 1.0])
			m.quad(inner[r][c + 1], inner[r][c], inner[r + 1][c], inner[r + 1][c + 1], [8, 1.06])
	for c in cols:
		# the rim
		m.quad(outer[rows][c], outer[rows][c + 1], inner[rows][c + 1], inner[rows][c], [8, 1.12])
	for r in rows:
		# the two front edges
		m.quad(inner[r][0], outer[r][0], outer[r + 1][0], inner[r + 1][0], [8, 1.06])
		m.quad(outer[r][cols], inner[r][cols], inner[r + 1][cols], outer[r + 1][cols], [8, 1.06])
	out.append({"name": "camo_collar", "kind": "collar", "d": m.data(), "box": m.bounds()})
	# the belt: a band round the waist, over the jacket's hem and the trousers' top
	var b := _Mesh.new()
	var seg := 28
	var band := func(k: int, y: float) -> Vector3:
		var th := TAU * k / seg
		return Vector3(sin(th) * 21.6, y, cos(th) * 17.8 + 1.2)
	var dark := [0, 1.0, Color("#26262a")]
	for k in seg:
		var a0: Vector3 = band.call(k, 56.0)
		var a1: Vector3 = band.call(k + 1, 56.0)
		var b0: Vector3 = band.call(k, 61.5)
		var b1: Vector3 = band.call(k + 1, 61.5)
		b.quad(a0, a1, b1, b0, dark)
		# its top and bottom edges, a little ledge back to the body
		b.quad(b0, b1, b1 * Vector3(0.93, 1, 0.93), b0 * Vector3(0.93, 1, 0.93), dark)
		b.quad(a1, a0, a0 * Vector3(0.93, 1, 0.93), a1 * Vector3(0.93, 1, 0.93), dark)
	# the buckle, in front
	b.box(Vector3(0, 58.75, 19.0 + 1.2), Vector3(6.0, 5.0, 1.4), [0, 1.0, Color("#8a8a82")])
	out.append({"name": "camo_belt", "kind": "belt", "d": b.data(), "box": b.bounds()})
	return out


## Triangles made here, as obj.gd reads a piece: counter-clockwise from the front, flat-shaded, each with its slot.
class _Mesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var tri := PackedInt32Array()
	var ntri := PackedInt32Array()
	var slots := []

	## a, b, c, d counter-clockwise as seen from the side facing out
	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, slot: Array) -> void:
		_tri(a, b, c, slot)
		_tri(a, c, d, slot)

	func _tri(a: Vector3, b: Vector3, c: Vector3, slot: Array) -> void:
		var nn := (b - a).cross(c - a)
		if nn.length_squared() < 1e-8:
			return
		n.append(nn.normalized())
		for p in [a, b, c]:
			v.append(p)
			tri.append(v.size() - 1)
			tri.append(0)
			ntri.append(n.size() - 1)
		slots.append(slot)

	func box(c: Vector3, s: Vector3, slot: Array) -> void:
		var h := s / 2.0
		var p := func(x: float, y: float, z: float) -> Vector3: return c + Vector3(x * h.x, y * h.y, z * h.z)
		quad(p.call(-1, -1, 1), p.call(1, -1, 1), p.call(1, 1, 1), p.call(-1, 1, 1), slot)
		quad(p.call(1, -1, -1), p.call(-1, -1, -1), p.call(-1, 1, -1), p.call(1, 1, -1), slot)
		quad(p.call(1, -1, 1), p.call(1, -1, -1), p.call(1, 1, -1), p.call(1, 1, 1), slot)
		quad(p.call(-1, -1, -1), p.call(-1, -1, 1), p.call(-1, 1, 1), p.call(-1, 1, -1), slot)
		quad(p.call(-1, 1, 1), p.call(1, 1, 1), p.call(1, 1, -1), p.call(-1, 1, -1), slot)

	## A flat strap along a path, `width` across and `thick` through, lying on the body (its flat facing out from the
	## body's middle line).
	func ribbon(path: Array, width: float, thick: float, slot: Array) -> void:
		var rows := []
		for i in path.size():
			var p: Vector3 = path[i]
			var t: Vector3 = (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
			var out := Vector3(p.x, 0, p.z).normalized() if Vector2(p.x, p.z).length() > 0.01 else Vector3.BACK
			out = (out - t * out.dot(t)).normalized()
			var side := t.cross(out).normalized()
			var h := thick / 2.0
			var w := width / 2.0
			rows.append([p + out * h - side * w, p + out * h + side * w, p - out * h + side * w, p - out * h - side * w])
		for i in rows.size() - 1:
			var a: Array = rows[i]
			var b: Array = rows[i + 1]
			for k in 4:
				var k2 := (k + 1) % 4
				quad(a[k], a[k2], b[k2], b[k], slot)

	func data() -> Dictionary:
		return {"v": v, "uv": PackedVector2Array([Vector2(0.5, 0.5)]), "n": n, "tri": tri, "ntri": ntri, "slots": slots}

	func bounds() -> AABB:
		var b := AABB(v[0], Vector3.ZERO)
		for p in v:
			b = b.expand(p)
		return b


## A pack's parts, worn (see PACKS), in the kit's centimetres: [{"name", "kind" ("pack" or "strap"), "d", "box"}]. Its
## pieces turned to face backward, scaled to its size, centred behind the wearer with its back against them and its
## top at its height; and its straps: over both shoulders and down the chest ("back"), or one from the left
## shoulder across the chest to the right hip and round the back ("sling", the pack hanging off it behind).
func _packs(pk: Dictionary) -> Array:
	var ds := []
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	# the body's own back (where nine in ten of its points are in front of it: its own strap loops, sticking out
	# further, tuck into the wearer)
	var back_z := PackedFloat32Array()
	for n in pk["pieces"]:
		var d := OBJ.read(int(n), PACK_DIR)
		# its front (+x) to the back (-z), its width (z) across
		var v: PackedVector3Array = d["v"]
		var nn: PackedVector3Array = d["n"]
		for i in v.size():
			v[i] = Vector3(v[i].z, v[i].y, -v[i].x)
			lo = lo.min(v[i])
			hi = hi.max(v[i])
			if ds.is_empty():
				back_z.append(v[i].z)
		for i in nn.size():
			nn[i] = Vector3(nn[i].z, nn[i].y, -nn[i].x)
		d["v"] = v
		d["n"] = nn
		# (no UVs: the pack has no texture)
		var tri0: PackedInt32Array = d["tri"]
		for i in range(1, tri0.size(), 2):
			tri0[i] = 0
		d["tri"] = tri0
		d["uv"] = PackedVector2Array([Vector2(0.5, 0.5)])
		ds.append(d)
	back_z.sort()
	var back: float = back_z[int(back_z.size() * 0.9)]
	var size := hi - lo
	var s: float = float(pk["size"]) / (size.x if pk.get("wide", false) else size.y)
	s = minf(s, 44.0 / size.x)
	var sling: bool = pk["wear"] == "sling"
	# behind the back: the middle across (a sling pack a little to the right), its back against the wearer
	var at := Vector3((-6.0 if sling else 0.0) - (lo.x + hi.x) / 2.0 * s, float(pk["top"]) - hi.y * s, PACK_BACK - back * s)
	var out := []
	for k in ds.size():
		var d: Dictionary = ds[k]
		var v: PackedVector3Array = d["v"]
		for i in v.size():
			v[i] = v[i] * s + at
		d["v"] = v
		var slots := []
		var tri: PackedInt32Array = d["tri"]
		var colour := [9, 1.0] if k == 0 else [0, 1.0, Color(pk["trim"][k - 1])]
		for t in range(0, tri.size(), 6):
			slots.append(colour)
		d["slots"] = slots
		out.append({"name": "%s %d" % [pk["name"], k], "kind": "pack", "d": d, "box": _bounds(v)})
	var bottom := float(pk["top"]) - size.y * s
	var m := _Mesh.new()
	var strap := [0, 1.0, Color(STRAP)]
	if sling:
		# round the body from the left shoulder down across the front to the right hip, and back up behind
		var c := Vector3(-2.5, 77.5, 0.5)
		var u := Vector3(15.5, 19.5, 0).normalized()
		var path := []
		for i in 33:
			var t := TAU * i / 32.0
			path.append(c + u * 24.9 * cos(t) + Vector3(0, 0, 17.0) * sin(t))
		m.ribbon(path, 3.6, 1.0, strap)
	else:
		for side in [-1.0, 1.0]:
			# from the pack's top over the shoulder and down the chest, under the arm and back to its bottom
			var path := [Vector3(side * 7.0, float(pk["top"]) - 2.0, PACK_BACK - 0.5), Vector3(side * 12.0, 95.0, -10.0),
				Vector3(side * 13.0, 97.5, 0.0), Vector3(side * 13.0, 94.0, 12.0), Vector3(side * 13.5, 84.0, 17.0),
				Vector3(side * 14.5, 72.0, 17.5), Vector3(side * 19.0, 66.0, 6.0), Vector3(side * 16.0, maxf(bottom + 3.0, 64.0), PACK_BACK + 0.5)]
			m.ribbon(path, 4.0, 1.2, strap)
	out.append({"name": pk["name"] + " straps", "kind": "strap", "d": m.data(), "box": m.bounds()})
	return out


func _bounds(v: PackedVector3Array) -> AABB:
	var b := AABB(v[0], Vector3.ZERO)
	for p in v:
		b = b.expand(p)
	return b


## The kit's people: runs of pieces, each starting at its legs (or at the bare arms just before them).
func _groups() -> Array:
	var out := []
	var cur := []
	var ns := pieces.keys()
	ns.sort()
	for i in ns.size():
		var n: int = ns[i]
		var b: AABB = pieces[n]["box"]
		var starts: bool = _is_legs(b) and not (cur.size() == 1 and _is_bare_arms(pieces[cur[0]]["box"]) and cur[0] == n - 1)
		if _is_bare_arms(b) and i + 1 < ns.size() and _is_legs(pieces[ns[i + 1]]["box"]):
			starts = true
		if cur.is_empty() or starts:
			cur = []
			out.append(cur)
		cur.append(n)
	return out


func _is_legs(b: AABB) -> bool:
	return b.position.y < 7.0 and b.end.y > 30.0 and b.end.y < 60.0 and b.size.x < 38.0 and b.end.z < 16.0


## The bare arms, hands and shoulders (two cuts of them), as opposed to sleeves.
func _is_bare_arms(b: AABB) -> bool:
	return absf(b.end.x - 65.3) < 0.3 and b.position.y > 75.0 and b.position.y < 82.5 and b.end.y > 93.5 and b.end.y < 96.0


## What a piece is, from where it sits on the body.
func _kind(b: AABB) -> String:
	var hx := maxf(-b.position.x, b.end.x)
	if _is_bare_arms(b):
		return "arms"
	if _is_legs(b):
		return "legs"
	if b.position.y > 85.0 and b.end.y < 106.0 and hx < 14.0:
		return "neck"
	if absf(b.position.y - 99.3) < 0.6 and absf(b.end.y - 165.6) < 0.6 and absf(hx - 40.8) < 0.6:
		return "head"
	if b.position.y > 69.0 and b.position.y < 102.0 and b.end.y > 165.0 and b.end.y < 171.0 and hx > 33.5 and hx < 37.5:
		return "hair"
	if b.position.y < 1.5 and b.end.y < 35.0:
		return "shoes"
	if b.end.z < 0.0:
		return "back"
	if b.position.y >= 99.0 or b.end.y > 140.0:
		# glasses, masks and the like in front of the face; hats on top; costume heads down over the shoulders
		if b.position.z > 5.0 or (b.position.y > 104.0 and b.end.y < 145.0):
			return "glasses"
		return "hat" if b.position.y >= 99.0 else "hood"
	if b.end.y > 110.0:
		return "hood"
	return "top" if b.end.y > 80.0 else "bottom"


## Whether a piece hangs as a skirt (or a coat's tails) rather than going round each leg: down at its hem there's
## cloth across the middle both in front and behind (a pair of shorts has only its seam there).
func _skirt(d: Dictionary, b: AABB) -> bool:
	# (a top ends at the waist, round the body: only cloth hanging below the crotch counts)
	if b.position.y > 44.0:
		return false
	var front := false
	var back := false
	for p in d["v"]:
		if absf(p.x) < 2.5 and p.y < b.position.y + 5.0:
			front = front or p.z > 8.0
			back = back or p.z < -8.0
	return front and back


## A part's mesh: its triangles in metres, the pack's normals, each vertex weighted to the bones and each triangle
## given its colour slot. Smaller versions (LODs) for far away.
func _bake(pc: Dictionary, kind: String) -> ArrayMesh:
	var d: Dictionary = pc["d"]
	var tri: PackedInt32Array = d["tri"]
	var ntri: PackedInt32Array = d["ntri"]
	# (a dress or robe hangs as a skirt below the waist too)
	var skirt: bool = kind in ["top", "bottom"] and (_skirt(d, pc["box"]) or (kind == "top" and (pc["box"] as AABB).position.y < 35.0))
	# each triangle's swatch colour and area
	var cols := []
	var areas := []
	for t in range(0, tri.size(), 6):
		var c := Vector2.ZERO
		for k in 3:
			c += d["uv"][tri[t + k * 2 + 1]]
		cols.append(_swatch(c / 3.0))
		var a: Vector3 = d["v"][tri[t]]
		var b: Vector3 = d["v"][tri[t + 2]]
		var e: Vector3 = d["v"][tri[t + 4]]
		areas.append((b - a).cross(e - a).length() / 2.0)
	var slots: Array = d["slots"] if d.has("slots") else _colour(kind, cols, areas, d, tri)
	# a sleeve's hands (the kit draws them in a grey) are bare, unless they're bright gloves
	if kind == "top":
		for ti in cols.size():
			var at := (d["v"][tri[ti * 6]] + d["v"][tri[ti * 6 + 2]] + d["v"][tri[ti * 6 + 4]]) / 3.0 as Vector3
			if absf(at.x) > 51.5 and (cols[ti] as Color).s < 0.45:
				slots[ti] = [1, 1.0]
	var names := []
	for b in TF.BONES:
		names.append(b[0])
	var weights := {}
	var st := SurfaceTool.new()
	st.set_skin_weight_count(SurfaceTool.SKIN_4_WEIGHTS)
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# each vertex's place at rest (CUSTOM0), for patterns that stay put on the cloth as it moves (the camo)
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_HALF)
	for ti in cols.size():
		var t := ti * 6
		# (a slot can bring a colour of its own: the whites of the eyes)
		var src: Color = slots[ti][2] if slots[ti].size() > 2 else cols[ti]
		st.set_color(src.srgb_to_linear())
		st.set_uv2(Vector2(slots[ti][0], slots[ti][1]))
		# wound the other way round: the OBJ's front faces are counter-clockwise
		for k in [0, 2, 1]:
			var vi := tri[t + k * 2]
			var p: Vector3 = d["v"][vi]
			if not weights.has(vi):
				weights[vi] = _top4(_weights(p, kind, skirt), names)
			st.set_bones(weights[vi][0])
			st.set_weights(weights[vi][1])
			var ni := ntri[ti * 3 + k]
			st.set_normal(d["n"][ni] if ni >= 0 and ni < d["n"].size() else Vector3.UP)
			var at := TF.fit(p)
			st.set_custom(0, Color(at.x, at.y, at.z, 0.0))
			st.add_vertex(at)
	st.index()
	var arrays := st.commit_to_arrays()
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, null, kind, Mesh.ARRAY_CUSTOM_RGBA_HALF << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	im.generate_lods(25.0, 60.0, [])
	return im.get_mesh()


## The commonest texel in a little square round a UV (so a UV on the line between two swatches reads as one).
func _swatch(uv: Vector2) -> Color:
	var cx := clampi(int(uv.x * img.get_width()), 0, img.get_width() - 1)
	var cy := clampi(int(uv.y * img.get_height()), 0, img.get_height() - 1)
	var counts := {}
	var best := Color.WHITE
	var most := 0
	for dy in range(-6, 7, 2):
		for dx in range(-6, 7, 2):
			var c := img.get_pixel(clampi(cx + dx, 0, img.get_width() - 1), clampi(cy + dy, 0, img.get_height() - 1))
			var k := c.to_rgba32()
			counts[k] = int(counts.get(k, 0)) + 1
			if counts[k] > most:
				most = counts[k]
				best = c
	return best


## Each triangle's [slot, lightness] (see townfolk.gdshader), or [slot, lightness, its own colour]:
##   the bare arms, legs and neck: skin;
##   the head: skin, but for its eyes and brows (the purples: the eye colour, keeping their light and dark; the reds by
##   the eyes, the lashes, darker), the whites of its eyes (see _eye_whites) and its mouth (the reds lower down, kept);
##   hair: the hair colour all over, a little lighter or darker as the kit shaded it;
##   a top, bottoms, shoes or hat: its main colour (the family of colours covering most of it) takes the slot, as much
##   lighter or darker as it was than that family's average (stripes stay stripes); its other colours are kept;
##   glasses, costume hoods and things on the back keep the kit's colours.
func _colour(kind: String, cols: Array, areas: Array, d: Dictionary, tri: PackedInt32Array) -> Array:
	var out := []
	match kind:
		"arms", "legs", "neck":
			for c in cols:
				out.append([1, 1.0])
		"head":
			var eye_v := _mean_v(cols, areas, func(c: Color) -> bool: return _is_eye(c))
			var whites := _eye_whites(cols, d, tri)
			for i in cols.size():
				var c: Color = cols[i]
				if _is_eye(c):
					out.append([3, clampf(c.v / eye_v, 0.45, 1.12)])
				elif _is_lash(c, _centre(d, tri, i)):
					out.append([3, 0.6])
				elif c.s > 0.4 and (c.h < 0.05 or c.h > 0.92):
					out.append([0, 1.0])
				elif whites[i]:
					out.append([0, 1.0, Color.WHITE])
				else:
					out.append([1, 1.0])
		"hair":
			var mean := _mean_l(cols, areas, func(_c: Color) -> bool: return true)
			for c in cols:
				out.append([2, clampf(1.0 + 0.25 * (c.get_luminance() / mean - 1.0), 0.84, 1.06)])
		"top", "bottom", "shoes", "hat":
			var slot: int = {"top": 4, "bottom": 5, "shoes": 6, "hat": 7}[kind]
			var fam := {}
			for i in cols.size():
				var f := _family(cols[i])
				fam[f] = float(fam.get(f, 0.0)) + float(areas[i])
			var main: int = fam.keys()[0]
			for f in fam:
				if fam[f] > fam[main]:
					main = f
			var mean := _mean_l(cols, areas, func(c: Color) -> bool: return _same(_family(c), main))
			for c in cols:
				if _same(_family(c), main):
					out.append([slot, clampf(1.0 + 0.5 * (c.get_luminance() / mean - 1.0), 0.7, 1.2)])
				else:
					out.append([0, 1.0])
		_:
			for c in cols:
				out.append([0, 1.0])
	return out


func _is_eye(c: Color) -> bool:
	return c.s > 0.3 and c.h > 0.68 and c.h < 0.92


## The pinks at the eyes' corners (the lashes), as opposed to the mouth below them.
func _is_lash(c: Color, at: Vector3) -> bool:
	return c.s > 0.4 and (c.h < 0.05 or c.h > 0.92) and at.y > 112.0 and absf(at.x) > 3.5


func _centre(d: Dictionary, tri: PackedInt32Array, i: int) -> Vector3:
	return (d["v"][tri[i * 6]] + d["v"][tri[i * 6 + 2]] + d["v"][tri[i * 6 + 4]]) / 3.0


## Which of a head's triangles are the whites of its eyes (the kit has none: it paints its eyes three ways, the
## face's own skin showing between the paint). Each eye is found on the front of the face drawn flat: its paint (the
## purples, and the reds at its corners) in patches, the brow the patch above the rest. An open eye, a big round
## iris or a small dot of a pupil under the upper lid's arc: the skin inside the outline round the lid and iris
## together is the white, and the iris's pale blue sparkles are white too. Shut (a thin arc): none. A triangle is
## white when all of it is.
const EYE_CELL := 0.5
func _eye_whites(cols: Array, d: Dictionary, tri: PackedInt32Array) -> Array:
	var lo := Vector2(-32.0, 104.0)
	var nx := int(64.0 / EYE_CELL)
	var ny := int(46.0 / EYE_CELL)
	var paint := PackedByteArray()
	paint.resize(nx * ny)
	var front := []
	for i in cols.size():
		var a: Vector3 = d["v"][tri[i * 6]]
		var b: Vector3 = d["v"][tri[i * 6 + 2]]
		var c: Vector3 = d["v"][tri[i * 6 + 4]]
		# the front of the face: facing forward, out in front (the OBJ winds counter-clockwise)
		var n := (b - a).cross(c - a)
		var on := n.z > 0.0 and n.normalized().z > 0.3 and (a.z + b.z + c.z) / 3.0 > 15.0
		front.append(on)
		var at := (a + b + c) / 3.0
		if on and (_is_eye(cols[i]) or _is_lash(cols[i], at)) and at.y > 111.0 and absf(at.x) > 1.5:
			_fill_tri(paint, [a, b, c], lo, nx, ny, 1)
	var hulls := []
	for side in [-1, 1]:
		var patches := _patches(paint, nx, ny, side)
		# highest first; the brow is the top one: above an iris (or pupil) and its lid, or above a shut eye's arc with a
		# gap between them (a cross brow slants down beside the lid)
		patches.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return p["box"].end.y > q["box"].end.y)
		if patches.size() >= 3 or (patches.size() == 2 and ((patches[0]["box"] as Rect2).position.y - (patches[1]["box"] as Rect2).end.y) * EYE_CELL > 1.0):
			patches.pop_front()
		if patches.is_empty():
			continue
		var low: Dictionary = patches.back()
		var size: Vector2 = (low["box"] as Rect2).size * EYE_CELL
		var solid: bool = (low["pts"] as PackedVector2Array).size() >= 0.5 * (low["box"] as Rect2).get_area()
		# a big round iris (a shut eye's arc and lashes are as big, but long and low), or a solid dot of a pupil under
		# its lid (not a shut eye's lashes)
		var round := size.x >= 7.0 and size.y >= 7.0 and size.x < 1.6 * size.y
		var dot := patches.size() >= 2 and size.x < 7.0 and size.y < 7.0 and size.x >= 2.5 and size.y >= 3.0 and solid
		if not round and not dot:
			continue
		var pts := PackedVector2Array()
		for p in patches:
			pts.append_array(p["pts"])
		hulls.append(Geometry2D.convex_hull(pts))
	var out := []
	for i in cols.size():
		var white := false
		if front[i]:
			var cen := _centre(d, tri, i)
			for h in hulls:
				var all := true
				for k in 4:
					var p: Vector3 = cen if k == 3 else (d["v"][tri[i * 6 + k * 2]] as Vector3).lerp(cen, 0.25)
					all = all and Geometry2D.is_point_in_polygon(Vector2(p.x, p.y), h)
				white = white or all
		out.append(white)
	return out


## The patches of paint on one side of the face (side -1 or 1, by x), each {"pts": its cells' middles (face
## centimetres), "box": its bounds in cells}; paint less than a cell apart is one patch.
func _patches(paint: PackedByteArray, nx: int, ny: int, side: int) -> Array:
	var lo := Vector2(-32.0, 104.0)
	var seen := PackedByteArray()
	seen.resize(nx * ny)
	var out := []
	for y in ny:
		for x in nx:
			var k := y * nx + x
			var px := lo.x + (x + 0.5) * EYE_CELL
			if paint[k] == 0 or seen[k] == 1 or signf(px) != side:
				continue
			var pts := PackedVector2Array()
			var box := Rect2(x, y, 0, 0)
			var q := [Vector2i(x, y)]
			seen[k] = 1
			while not q.is_empty():
				var c: Vector2i = q.pop_back()
				pts.append(lo + (Vector2(c) + Vector2(0.5, 0.5)) * EYE_CELL)
				box = box.expand(Vector2(c))
				for dy in range(-2, 3):
					for dx in range(-2, 3):
						var r := c + Vector2i(dx, dy)
						if r.x < 0 or r.y < 0 or r.x >= nx or r.y >= ny:
							continue
						var kr := r.y * nx + r.x
						if paint[kr] == 1 and seen[kr] == 0 and signf(lo.x + (r.x + 0.5) * EYE_CELL) == side:
							seen[kr] = 1
							q.append(r)
			if pts.size() >= 3:
				box.size += Vector2.ONE
				out.append({"pts": pts, "box": box})
	return out


## Marks the cells of a grid (cell EYE_CELL, from `lo`) whose middles a triangle covers, seen from the front.
func _fill_tri(grid: PackedByteArray, pts: Array, lo: Vector2, nx: int, ny: int, v: int) -> void:
	var a := Vector2(pts[0].x, pts[0].y)
	var b := Vector2(pts[1].x, pts[1].y)
	var c := Vector2(pts[2].x, pts[2].y)
	var x0 := clampi(int((minf(a.x, minf(b.x, c.x)) - lo.x) / EYE_CELL), 0, nx - 1)
	var x1 := clampi(int((maxf(a.x, maxf(b.x, c.x)) - lo.x) / EYE_CELL), 0, nx - 1)
	var y0 := clampi(int((minf(a.y, minf(b.y, c.y)) - lo.y) / EYE_CELL), 0, ny - 1)
	var y1 := clampi(int((maxf(a.y, maxf(b.y, c.y)) - lo.y) / EYE_CELL), 0, ny - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var p := lo + Vector2(x + 0.5, y + 0.5) * EYE_CELL
			if Geometry2D.point_is_inside_triangle(p, a, b, c):
				grid[y * nx + x] = v


## Which family of colours: -1 the greys (white to black), else one of 12 hues.
func _family(c: Color) -> int:
	return -1 if c.s < 0.18 or c.v < 0.12 else int(roundf(c.h * 12.0)) % 12


func _same(f: int, main: int) -> bool:
	if f == main:
		return true
	return f >= 0 and main >= 0 and (absi(f - main) == 1 or absi(f - main) == 11)


func _mean_l(cols: Array, areas: Array, keep: Callable) -> float:
	var s := 0.0
	var a := 0.0
	for i in cols.size():
		if keep.call(cols[i]):
			s += (cols[i] as Color).get_luminance() * float(areas[i])
			a += float(areas[i])
	return maxf(s / a, 0.02) if a > 0.0 else 0.5


func _mean_v(cols: Array, areas: Array, keep: Callable) -> float:
	var s := 0.0
	var a := 0.0
	for i in cols.size():
		if keep.call(cols[i]):
			s += (cols[i] as Color).v * float(areas[i])
			a += float(areas[i])
	return maxf(s / a, 0.02) if a > 0.0 else 0.5


## How much each bone moves a vertex (at `p`, in the kit's centimetres), from where it is on the body:
##   on the head (the head, hair, hats, glasses): the head;
##   shoes: the foot;
##   out past the shoulder (the bare arms, and a top's sleeves): along the arm, blending over each joint;
##   below the waist: along the leg on its side (skirts and coat tails mostly with the hips, a little with the legs);
##   otherwise up the body, from the hips to the head.
func _weights(p: Vector3, kind: String, skirt: bool) -> Dictionary:
	var ax := absf(p.x)
	var side := "l_" if p.x >= 0.0 else "r_"
	match kind:
		"head", "hair", "hat", "glasses":
			return {"head": 1.0}
		"collar":
			# with the chest, its top a little with the neck (not the head: the head is drawn smaller)
			var w := smoothstep(90.0, 104.0, p.y) * 0.5
			return {"chest": 1.0 - w, "neck": w}
		"pack", "strap":
			return {"chest": 1.0}
		"shoes":
			return {side + "foot": 1.0}
	if kind in ["arms", "top"] and ax > 14.0 and p.y > 74.0 and p.y < 99.0:
		var arm := _chain(ax, ["body", side + "arm", side + "forearm", side + "hand"], [17.0, 37.0, 50.5], [3.0, 3.0, 1.5])
		var out := {}
		for b in arm:
			if b == "body":
				for t in _torso(p.y):
					out[t] = float(out.get(t, 0.0)) + arm[b] * _torso(p.y)[t]
			else:
				out[b] = float(out.get(b, 0.0)) + arm[b]
		return out
	if p.y < 52.0 and kind in ["legs", "top", "bottom"]:
		if skirt:
			var leg: float = clampf((50.0 - p.y) / 40.0, 0.0, 0.5) * smoothstep(2.0, 8.0, ax)
			var hips := _torso(p.y)
			var o := {}
			for t in hips:
				o[t] = hips[t] * (1.0 - leg)
			o[side + "thigh"] = float(o.get(side + "thigh", 0.0)) + leg
			return o
		# the two legs meet in the middle (a pair of shorts' seam)
		var lf := clampf(0.5 + p.x / 3.0, 0.0, 1.0)
		var out := {}
		for s in [["l_", lf], ["r_", 1.0 - lf]]:
			if s[1] <= 0.0:
				continue
			var leg := _chain(-p.y, ["hips", s[0] + "thigh", s[0] + "shin", s[0] + "foot"], [-48.0, -28.0, -9.0], [3.0, 3.0, 2.0])
			for b in leg:
				out[b] = float(out.get(b, 0.0)) + leg[b] * float(s[1])
		return out
	return _torso(p.y)


## Up the body: the hips, spine, chest, neck and head, blending over each joint.
func _torso(y: float) -> Dictionary:
	return _chain(y, ["hips", "spine", "chest", "neck", "head"], [62.0, 76.0, 92.0, 101.0], [4.0, 4.0, 3.0, 2.0])


## Weights along a chain of bones: bones[0] before at[0], bones[i] from at[i - 1] to at[i], the last beyond; each
## joint blends over +-blend[i] around it.
func _chain(s: float, bones: Array, at: Array, blend: Array) -> Dictionary:
	var out := {}
	var carry := 1.0
	for i in bones.size():
		var t: float = smoothstep(at[i] - blend[i], at[i] + blend[i], s) if i < at.size() else 0.0
		var w := carry * (1.0 - t)
		if w > 0.0:
			out[bones[i]] = float(out.get(bones[i], 0.0)) + w
		carry *= t
	return out


## The four bones moving a vertex most, as [bone indices, weights adding up to 1].
func _top4(w: Dictionary, names: Array) -> Array:
	var keys := w.keys()
	keys.sort_custom(func(a, b) -> bool: return w[a] > w[b])
	var bones := PackedInt32Array([0, 0, 0, 0])
	var ws := PackedFloat32Array([0, 0, 0, 0])
	var tot := 0.0
	for i in mini(4, keys.size()):
		bones[i] = names.find(keys[i])
		ws[i] = w[keys[i]]
		tot += ws[i]
	for i in 4:
		ws[i] /= maxf(tot, 1e-6)
	return [bones, ws]
