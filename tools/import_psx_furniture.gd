extends SceneTree
## Bakes the beds, sofas, armchairs, chairs, tables, desks and cabinets that furnish building interiors from the
## furniture pack in psx/furniture/ into assets/psx/interior/ (see CREDITS.md), coloured to suit the game:
##   godot --headless --path . --script res://tools/import_psx_furniture.gd [-- name ...]
##
## The pack is six OBJ showrooms (model_0.obj .. model_5.obj), every piece set out apart from the next, with no
## textures: all the UVs of a part point at one spot of a palette texture the pack doesn't include. So a piece is cut
## out of its showroom by where it stands and split into its parts (meshes joined up; a mesh whose palette spots lie
## in different places, like a sheet turned down over a blanket, splits by spot), and every part takes a colour by
## what it is: a bed's frame, mattress, blanket, turned-down sheet or pillow; a seat's upholstery, cushions or legs; a
## table's wood or knobs. What a part is comes from its shape and where it sits in the piece (see _roles). The colours
## go in the vertices, over a fine wood grain or cloth weave (box-mapped, sampled sharp like the other PSX pieces),
## darkening towards the floor.
##
## Every piece is sized to fill the tiles it stands on, as the room builder only ever shrinks furniture: a bed is a
## little over two tiles long so a person fits on it, a sofa two tiles wide. Like import_psx_interior.gd's pieces they
## come out centred on x/z, standing on y = 0, facing +z with their back to -z (the pack's own way round).

const B = preload("res://tools/psx_bake.gd")
const SRC := "res://psx/furniture/"
const OUT := "res://assets/psx/interior/"

## name: {m: the showroom (model_<m>.obj), at: where the piece stands in it (x, z, width, depth, in pack units),
## kind: bed, seat, chair or case (see _roles), size: [width, height, depth] in game units, col: colours by role
## (over ROLES'), iron: its frame is painted metal, not wood}.
## Pieces that go together share colours: each sofa with an armchair and a set of chairs, by their place in
## room_builder.gd's lists (red, green, teal, mustard).
const PIECES := {
	# single beds: a tile wide, two long
	"bed_oak": {"m": 2, "at": Rect2(-265.1, -953.5, 68.5, 172.2), "kind": "bed", "size": [0.94, 1.1, 2.15],
		"col": {"frame": "#c98f55", "blanket": "#d8584e"}},
	"bed_spindle": {"m": 3, "at": Rect2(-1075.2, -959.3, 68.1, 158.0), "kind": "bed", "size": [0.94, 1.1, 2.15],
		"col": {"frame": "#f2ebe0", "blanket": "#4f7fcf"}},
	"bed_house": {"m": 3, "at": Rect2(648.7, -685.6, 68.1, 153.2), "kind": "bed", "size": [0.94, 1.1, 2.15],
		"col": {"frame": "#7fb8e0", "blanket": "#f0c050"}},
	"bed_iron": {"m": 1, "at": Rect2(89.1, -686.2, 72.5, 155.3), "kind": "bed", "size": [0.94, 1.1, 2.15],
		"col": {"frame": "#3a3840", "blanket": "#5fae6a"}, "iron": true},
	# double beds: two tiles by two
	"bed_double_slat": {"m": 1, "at": Rect2(112.7, -956.0, 123.4, 175.1), "kind": "bed", "size": [1.84, 1.1, 2.2],
		"col": {"frame": "#8b5a3a", "blanket": "#4f7fcf"}},
	"bed_double_panel": {"m": 2, "at": Rect2(-158.1, -953.5, 123.7, 172.2), "kind": "bed", "size": [1.84, 1.1, 2.2],
		"col": {"frame": "#d9a86c", "blanket": "#9a6ac8"}},
	"bed_double_wave": {"m": 1, "at": Rect2(1042.4, -685.5, 139.2, 158.5), "kind": "bed", "size": [1.84, 1.1, 2.2],
		"col": {"frame": "#f2ebe0", "blanket": "#f09ab4"}},
	"bed_double_iron": {"m": 0, "at": Rect2(-83.2, -686.3, 128.0, 155.3), "kind": "bed", "size": [1.84, 1.1, 2.2],
		"col": {"frame": "#ece8e0", "blanket": "#3fa8a8"}, "iron": true},
	# bunk beds
	"bunk_oak": {"m": 1, "at": Rect2(-195.5, -682.8, 73.0, 153.0), "kind": "bed", "size": [0.94, 1.85, 2.15],
		"col": {"frame": "#c98f55", "blanket": "#d8584e"}},
	"bunk_ladder": {"m": 0, "at": Rect2(-1077.5, -681.1, 73.0, 157.2), "kind": "bed", "size": [0.94, 1.85, 2.15],
		"col": {"frame": "#dcb27a", "blanket": "#4f7fcf"}},
	# sofas, two tiles wide, and armchairs to match
	"sofa_love": {"m": 3, "at": Rect2(-1171.0, 635.5, 73.8, 44.5), "kind": "seat", "size": [1.84, 0.85, 0.88],
		"col": {"fabric": "#c8463c"}},
	"sofa_box": {"m": 4, "at": Rect2(623.6, 114.4, 81.0, 43.2), "kind": "seat", "size": [1.84, 0.85, 0.88],
		"col": {"fabric": "#5a9a5e"}},
	"sofa_cottage": {"m": 2, "at": Rect2(-226.0, 275.3, 85.5, 42.7), "kind": "seat", "size": [1.84, 0.95, 0.88],
		"col": {"fabric": "#2f9a9a", "legs": "#c98f55"}},
	"sofa_roll": {"m": 4, "at": Rect2(-40.3, 455.0, 82.0, 43.1), "kind": "seat", "size": [1.84, 0.95, 0.88],
		"col": {"fabric": "#e0a838"}},
	"armchair_roll": {"m": 3, "at": Rect2(198.6, 455.2, 58.7, 44.8), "kind": "seat", "size": [0.92, 0.9, 0.86],
		"col": {"fabric": "#c8463c"}},
	"armchair_club": {"m": 4, "at": Rect2(-100.8, 454.6, 48.0, 43.1), "kind": "seat", "size": [0.92, 0.9, 0.86],
		"col": {"fabric": "#5a9a5e"}},
	"armchair_cottage": {"m": 3, "at": Rect2(-295.1, 276.5, 50.7, 42.7), "kind": "seat", "size": [0.92, 0.9, 0.86],
		"col": {"fabric": "#2f9a9a", "legs": "#c98f55"}},
	"armchair_tub": {"m": 4, "at": Rect2(990.7, 456.2, 57.4, 44.5), "kind": "seat", "size": [0.92, 0.9, 0.86],
		"col": {"fabric": "#e0a838"}},
	# dining chairs
	"chair_spindle": {"m": 4, "at": Rect2(749.6, 275.8, 38.3, 44.6), "kind": "chair", "size": [0.48, 0.88, 0.52],
		"col": {"wood": "#c98f55", "cushion": "#d8584e"}},
	"chair_ladder": {"m": 4, "at": Rect2(984.5, 275.5, 44.6, 44.0), "kind": "chair", "size": [0.5, 0.88, 0.52],
		"col": {"wood": "#f2ebe0", "cushion": "#2f9a9a"}},
	"chair_ring": {"m": 4, "at": Rect2(-1395.7, 457.6, 37.1, 43.9), "kind": "chair", "size": [0.48, 0.88, 0.52],
		"col": {"wood": "#8b5a3a", "cushion": "#5fae6a"}},
	"chair_slat": {"m": 5, "at": Rect2(689.1, 275.3, 38.3, 44.6), "kind": "chair", "size": [0.48, 0.88, 0.52],
		"col": {"wood": "#dcb27a", "cushion": "#e0a838"}},
	# tables
	"table_trestle": {"m": 5, "at": Rect2(247.3, -230.2, 123.2, 66.3), "kind": "case", "size": [1.5, 0.74, 0.9],
		"col": {"wood": "#c98f55"}},
	"table_curve": {"m": 5, "at": Rect2(-1075.2, -229.7, 130.7, 65.3), "kind": "case", "size": [1.5, 0.74, 0.88],
		"col": {"wood": "#8b5a3a"}},
	"table_pedestal": {"m": 4, "at": Rect2(-1384.8, -229.8, 64.1, 64.1), "kind": "case", "size": [0.95, 0.74, 0.95],
		"col": {"wood": "#f2ebe0"}},
	"table_small": {"m": 4, "at": Rect2(936.7, -410.4, 47.0, 47.4), "kind": "case", "size": [0.8, 0.74, 0.8],
		"col": {"wood": "#dcb27a"}},
	"coffee_shelf": {"m": 5, "at": Rect2(-20.5, -230.8, 126.8, 67.5), "kind": "case", "size": [1.25, 0.42, 0.66],
		"col": {"wood": "#c98f55"}},
	"coffee_square": {"m": 5, "at": Rect2(129.7, -245.2, 96.3, 96.2), "kind": "case", "size": [0.85, 0.4, 0.85],
		"col": {"wood": "#8b5a3a"}},
	# desks and cabinets
	"desk_writing": {"m": 4, "at": Rect2(-402.4, -219.4, 75.2, 44.6), "kind": "case", "size": [0.95, 0.74, 0.56],
		"col": {"wood": "#c98f55"}},
	"desk_sled": {"m": 5, "at": Rect2(454.4, -218.8, 59.4, 43.4), "kind": "case", "size": [0.9, 0.74, 0.6],
		"col": {"wood": "#f2ebe0"}},
	"nightstand": {"m": 4, "at": Rect2(936.7, -410.4, 47.0, 47.4), "kind": "case", "size": [0.5, 0.62, 0.48],
		"col": {"wood": "#c98f55"}},
	"dresser": {"m": 4, "at": Rect2(305.3, -53.1, 119.0, 39.2), "kind": "case", "size": [0.98, 0.72, 0.48],
		"col": {"wood": "#c98f55"}},
	"tv_stand": {"m": 5, "at": Rect2(-214.0, -53.4, 155.9, 36.4), "kind": "case", "size": [0.98, 0.45, 0.45],
		"col": {"wood": "#8b5a3a"}},
	"bench_slats": {"m": 5, "at": Rect2(61.9, 929.6, 169.3, 39.6), "kind": "case", "size": [1.0, 0.45, 0.42],
		"col": {"wood": "#c98f55"}},
}

## role: [material (wood: a grain; cloth: a weave; plain), its colour unless the piece says]. A cushion with no colour
## of its own is its seat's fabric, a shade lighter.
const ROLES := {
	"frame": ["wood", "#c98f55"], "wood": ["wood", "#c98f55"], "legs": ["wood", "#7a4e30"], "knob": ["plain", "#d8b04a"],
	"mattress": ["cloth", "#f4efe4"], "base": ["cloth", "#e2d8c6"], "pillow": ["cloth", "#fffcf4"],
	"fold": ["cloth", "#f8f4ec"], "blanket": ["cloth", "#d8584e"], "fabric": ["cloth", "#4a6fb8"], "cushion": ["cloth", ""],
}
## one repeat of the grain and of the weave, in game units
const WOOD_REPEAT := 0.6
const CLOTH_REPEAT := 0.35

var _showrooms := {}
var _mats := {}


func _init() -> void:
	var only := OS.get_cmdline_user_args()
	_mats = _materials()
	for name in PIECES:
		if not only.is_empty() and not only.has(name):
			continue
		var e: Dictionary = PIECES[name]
		var d := _showroom(int(e["m"]))
		if d.is_empty():
			push_error("could not read model_%d.obj" % int(e["m"]))
			continue
		var tris := _cut(d, e["at"])
		if tris.is_empty():
			push_error("nothing stands at %s in model_%d.obj" % [e["at"], int(e["m"])])
			continue
		var box := _box(d, tris)
		var parts := []
		for p in _joined(d, tris):
			parts.append_array(_split(d, p))
		var infos := parts.map(func(p): return _info(d, p, box))
		var roles := _roles(String(e["kind"]), infos)
		var mesh := _bake(d, parts, roles, box, e)
		var n := B.tris(mesh)
		if n > 400:
			mesh = B.with_lods(mesh)
		var err := ResourceSaver.save(mesh, OUT + name + ".res", ResourceSaver.FLAG_COMPRESS)
		var count := {}
		for r in roles:
			count[r] = count.get(r, 0) + 1
		print("  %-18s %5d tris  %s  %s  %s" % [name, n, mesh.get_aabb().size.snapped(Vector3.ONE * 0.01), count,
			"ok" if err == OK else "SAVE FAILED"])
	quit()


# ---------------------------------------------------------------- reading the pack
## A showroom: per vertex its position, normal and palette spot (u and v to a thousandth, as one number), and its
## triangles (three vertex numbers each), less the degenerate ones that stitch the pack's strips together. (The pack's
## faces use the same number for a corner's position, UV and normal.)
func _showroom(m: int) -> Dictionary:
	if _showrooms.has(m):
		return _showrooms[m]
	var f := FileAccess.open(SRC + "model_%d.obj" % m, FileAccess.READ)
	if f == null:
		return {}
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var spot := PackedInt32Array()
	var faces := PackedInt32Array()
	while not f.eof_reached():
		var line := f.get_line()
		if line.length() < 4:
			continue
		var p := line.split(" ", false)
		match p[0]:
			"v":
				pos.append(Vector3(p[1].to_float(), p[2].to_float(), p[3].to_float()))
			"vn":
				nrm.append(Vector3(p[1].to_float(), p[2].to_float(), p[3].to_float()).normalized())
			"vt":
				spot.append(roundi(p[1].to_float() * 1000.0) * 100000 + roundi(p[2].to_float() * 1000.0))
			"f":
				for k in range(1, 4):
					faces.append(p[k].get_slice("/", 0).to_int() - 1)
	var tris := PackedInt32Array()
	for t in faces.size() / 3:
		var a := faces[t * 3]
		var b := faces[t * 3 + 1]
		var c := faces[t * 3 + 2]
		if (pos[b] - pos[a]).cross(pos[c] - pos[a]).length_squared() > 1e-8:
			tris.append_array([a, b, c])
	var d := {"pos": pos, "nrm": nrm, "spot": spot, "tris": tris}
	_showrooms[m] = d
	return d


## The triangles (by number) standing in `at` (pieces stand well apart, so a little either side is safe).
func _cut(d: Dictionary, at: Rect2) -> Array:
	var pos: PackedVector3Array = d["pos"]
	var tris: PackedInt32Array = d["tris"]
	var r := at.grow(2.0)
	var out := []
	for t in tris.size() / 3:
		var c := (pos[tris[t * 3]] + pos[tris[t * 3 + 1]] + pos[tris[t * 3 + 2]]) / 3.0
		if r.has_point(Vector2(c.x, c.z)):
			out.append(t)
	return out


func _box(d: Dictionary, tris: Array) -> AABB:
	var pos: PackedVector3Array = d["pos"]
	var t3: PackedInt32Array = d["tris"]
	var bb := AABB(pos[t3[int(tris[0]) * 3]], Vector3.ZERO)
	for t in tris:
		for k in 3:
			bb = bb.expand(pos[t3[t * 3 + k]])
	return bb


## The piece's triangles in joined-up meshes (corners at the same spot join).
func _joined(d: Dictionary, tris: Array) -> Array:
	var pos: PackedVector3Array = d["pos"]
	var t3: PackedInt32Array = d["tris"]
	var weld := {}
	var up := []
	var corner := PackedInt32Array()
	for t in tris:
		for k in 3:
			var key := Vector3i((pos[t3[t * 3 + k]] * 100.0).round())
			if not weld.has(key):
				weld[key] = up.size()
				up.append(up.size())
			corner.append(weld[key])
	for i in tris.size():
		var a := _root(up, corner[i * 3])
		for k in range(1, 3):
			var b := _root(up, corner[i * 3 + k])
			if a != b:
				up[b] = a
	var groups := {}
	for i in tris.size():
		var r := _root(up, corner[i * 3])
		if not groups.has(r):
			groups[r] = []
		groups[r].append(tris[i])
	return groups.values()


static func _root(up: Array, a: int) -> int:
	while up[a] != a:
		up[a] = up[up[a]]
		a = up[a]
	return a


## A mesh whose palette spots lie in different places (a sheet turned down over a blanket) splits by spot; spots
## scattered over the same place (a two-tone blanket) stay together.
func _split(d: Dictionary, part: Array) -> Array:
	var by := {}
	for t in part:
		var s := _spot(d, t)
		if not by.has(s):
			by[s] = []
		by[s].append(t)
	if by.size() < 2:
		return [part]
	var size := _box(d, part).size
	var keep := []
	var out := []
	for s in by:
		var g: Array = by[s]
		if g.size() >= 12 and g.size() >= part.size() * 0.1:
			var gs := _box(d, g).size
			if minf(gs.x / maxf(size.x, 1e-6), gs.z / maxf(size.z, 1e-6)) < 0.75:
				out.append(g)
				continue
		keep.append_array(g)
	if not keep.is_empty():
		out.append(keep)
	return out


## A triangle's palette spot: the one most of its corners have.
func _spot(d: Dictionary, t: int) -> int:
	var spot: PackedInt32Array = d["spot"]
	var t3: PackedInt32Array = d["tris"]
	var a := spot[t3[t * 3]]
	var b := spot[t3[t * 3 + 1]]
	return a if a == b or a == spot[t3[t * 3 + 2]] else b


# ---------------------------------------------------------------- what each part is
## What the rules go by: a part's box as fractions of the piece's (lo, hi, span), its size in pack units (abs), the
## piece's largest side (big), and how much of it faces up (the area facing up over its box's footprint).
func _info(d: Dictionary, part: Array, piece: AABB) -> Dictionary:
	var pos: PackedVector3Array = d["pos"]
	var t3: PackedInt32Array = d["tris"]
	var bb := _box(d, part)
	var up := 0.0
	for t in part:
		var a := pos[t3[t * 3]]
		var n := (pos[t3[t * 3 + 1]] - a).cross(pos[t3[t * 3 + 2]] - a)
		if n.y > 0.7 * n.length():
			up += n.length() / 2.0
	var lo := (bb.position - piece.position) / piece.size
	var hi := (bb.end - piece.position) / piece.size
	return {"lo": lo, "hi": hi, "span": hi - lo, "abs": bb.size, "big": maxf(piece.size.x, maxf(piece.size.y, piece.size.z)),
		"up": up / maxf(bb.size.x * bb.size.z, 1e-6)}


func _roles(kind: String, parts: Array) -> Array:
	match kind:
		"bed":
			return _bed_roles(parts)
		"seat", "chair":
			return parts.map(func(p): return _seat_role(p, kind == "chair"))
	return parts.map(func(p): return "knob" if _longest(p) < 0.07 * float(p["big"]) else "wood")


## A bed: its mattresses are the flat slabs that span it (a slab right under another is the base under a
## mattress; one on the floor is the bed's own box). What lies over a mattress is bedding: a pillow at the head, the
## sheet turned down below it, and the blanket down to the foot. The rest is the frame.
func _bed_roles(parts: Array) -> Array:
	var roles := []
	var slabs := []
	for i in parts.size():
		roles.append("frame")
		var s: Vector3 = parts[i]["span"]
		if float(parts[i]["up"]) > 0.6 and s.x > 0.6 and s.z > 0.8 and s.y < 0.3:
			slabs.append(i)
	var mattresses := []
	for i in slabs:
		var p: Dictionary = parts[i]
		if float(p["lo"].y) < 0.04:
			continue
		roles[i] = "mattress"
		for j in slabs:
			if j != i and parts[j]["lo"].y > p["lo"].y and parts[j]["lo"].y - p["hi"].y < 0.06:
				roles[i] = "base"
		if roles[i] == "mattress":
			mattresses.append(p)
	for i in parts.size():
		if roles[i] != "frame":
			continue
		var p: Dictionary = parts[i]
		var lo: Vector3 = p["lo"]
		var hi: Vector3 = p["hi"]
		var s: Vector3 = p["span"]
		for m in mattresses:
			var mlo: Vector3 = m["lo"]
			var mhi: Vector3 = m["hi"]
			var mw: float = m["span"].x
			if lo.x < mlo.x - 0.08 or hi.x > mhi.x + 0.08 or hi.y < mhi.y - 0.01 or hi.y > mhi.y + 0.2:
				continue
			if lo.y >= mhi.y - 0.06 and lo.z > 0.03 and hi.z < 0.3 and s.z > 0.08 and s.x > 0.15 and s.x < 0.75 * mw + 0.01 \
					and s.y > 0.04 and s.y < 0.2:
				roles[i] = "pillow"
			elif s.x >= 0.75 * mw and lo.z > 0.15 and hi.z < 0.65 and s.y < 0.6:
				roles[i] = "fold"
			elif s.x >= 0.75 * mw and lo.z > 0.15 and hi.z > 0.8 and s.z > 0.4 and s.y < 0.6:
				roles[i] = "blanket"
			else:
				continue
			break
	return roles


## A seat: legs are what stands below the seat, and long thin rails; a cushion lies flat on the seat; the rest is
## upholstery (on a chair, wood).
func _seat_role(p: Dictionary, chair: bool) -> String:
	var lo: Vector3 = p["lo"]
	var s: Vector3 = p["span"]
	var sides: Array = [p["abs"].x, p["abs"].y, p["abs"].z]
	sides.sort()
	if p["hi"].y < 0.3 or not chair and sides[1] < 0.06 * float(p["big"]) and sides[2] > 0.2 * float(p["big"]):
		return "legs" if not chair else "wood"
	if chair:
		var flat := float(p["up"]) > 0.5 and s.x > 0.6 and s.z > 0.5 and lo.y > 0.3 and lo.y < 0.7 and s.y < 0.2
		return "cushion" if flat else "wood"
	if float(p["up"]) > 0.5 and lo.y > 0.15 and lo.y < 0.6 and s.y < 0.35 and s.z > 0.35 and s.x < 0.75:
		return "cushion"
	return "fabric"


func _longest(p: Dictionary) -> float:
	var a: Vector3 = p["abs"]
	return maxf(a.x, maxf(a.y, a.z))


# ---------------------------------------------------------------- the mesh
## The piece at the game's size and colours: one surface per material, colours in the vertices (each part a shade
## off its neighbours so they read apart, darker near the floor), UVs box-mapped.
func _bake(d: Dictionary, parts: Array, roles: Array, box: AABB, e: Dictionary) -> ArrayMesh:
	var pos: PackedVector3Array = d["pos"]
	var nrm: PackedVector3Array = d["nrm"]
	var t3: PackedInt32Array = d["tris"]
	var size: Array = e["size"]
	var sc := Vector3(float(size[0]) / box.size.x, float(size[1]) / box.size.y, float(size[2]) / box.size.z)
	var origin := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var col: Dictionary = e.get("col", {})
	var sts := {}
	for i in parts.size():
		var role: String = roles[i]
		var mat: String = ROLES[role][0]
		if e.get("iron", false) and mat == "wood":
			mat = "plain"
		var c := _colour(role, col)
		var shade := 1.0 + (float((i * 7919) % 13) / 12.0 - 0.5) * 0.08
		if not sts.has(mat):
			sts[mat] = SurfaceTool.new()
			(sts[mat] as SurfaceTool).begin(Mesh.PRIMITIVE_TRIANGLES)
		var st: SurfaceTool = sts[mat]
		var repeat := WOOD_REPEAT if mat == "wood" else CLOTH_REPEAT
		for t in parts[i]:
			var p := []
			var n := []
			# the pack winds its faces anticlockwise; Godot's front faces are clockwise
			for k in [0, 2, 1]:
				var vi := t3[t * 3 + k]
				p.append((pos[vi] - origin) * sc)
				n.append((nrm[vi] / sc).normalized())
			var fn: Vector3 = ((p[1] - p[0]) as Vector3).cross(p[2] - p[0]).abs()
			for k in 3:
				var v: Vector3 = p[k]
				var uv: Vector2 = Vector2(v.x, v.y) if fn.z >= fn.x and fn.z >= fn.y else (Vector2(v.z, v.y) if fn.x >= fn.y else Vector2(v.x, v.z))
				var f := shade * lerpf(0.72, 1.0, clampf(v.y / 0.25, 0.0, 1.0))
				st.set_color(Color(c.r * f, c.g * f, c.b * f))
				st.set_normal(n[k])
				st.set_uv(uv / repeat)
				st.add_vertex(v)
	var mesh := ArrayMesh.new()
	for mat in ["wood", "cloth", "plain"]:
		if sts.has(mat):
			var st: SurfaceTool = sts[mat]
			st.index()
			st.commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, _mats[mat])
	return mesh


func _colour(role: String, col: Dictionary) -> Color:
	if col.has(role):
		return Color(col[role])
	if role == "cushion":
		return _colour("fabric", col).lightened(0.12)
	if role == "legs" and col.has("frame"):
		return Color(col["frame"])
	return Color(ROLES[role][1])


## The materials every piece shares, saved beside them so the pieces point at them rather than each keep a copy: wood
## (a grain), cloth (a weave) and plain (painted iron, brass), all coloured by their vertices.
func _materials() -> Dictionary:
	var out := {}
	for kind in ["wood", "cloth", "plain"]:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.roughness = 1.0 if kind != "plain" else 0.55
		m.metallic_specular = 0.2 if kind != "plain" else 0.45
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		if kind != "plain":
			var img := _grain() if kind == "wood" else _weave()
			img.generate_mipmaps()
			m.albedo_texture = ImageTexture.create_from_image(img)
		var path := OUT + "furniture_%s.res" % kind
		var err := ResourceSaver.save(m, path, ResourceSaver.FLAG_COMPRESS)
		if err != OK:
			push_error("could not save " + path)
		m.take_over_path(path)
		out[kind] = m
	return out


## Wood grain, faint: gently wavy streaks across a 64 px tile that repeats without a seam, speckled a little.
static func _grain() -> Image:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for y in 64:
		for x in 64:
			var u := float(x) / 64.0
			var ring := float(y) / 64.0 * 4.0 + 0.08 * sin(TAU * u) + 0.04 * sin(TAU * u * 3.0 + 1.3)
			var g := 0.93 + 0.035 * sin(TAU * ring) + rng.randf_range(-0.02, 0.02)
			img.set_pixel(x, y, Color(g, g, g))
	return img


## Cloth: a fine checked weave, speckled a little.
static func _weave() -> Image:
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for y in 32:
		for x in 32:
			var g := 0.93 + (0.03 if (x + y) % 2 == 0 else -0.03) + rng.randf_range(-0.02, 0.02)
			img.set_pixel(x, y, Color(g, g, g))
	return img
