extends SceneTree
## Bakes Captain Gull's ferry, moored by Tidewater's long pier, from the ferry model in psx/ferry/ (see CREDITS.md)
## into assets/psx/models/ferry.res:
##   godot --headless --path . --script res://tools/import_psx_ferry.gd
##
## The model comes as 35 OBJ parts (about 1.5 million triangles) with no materials. Only the parts seen from outside
## are kept: the seats and floors under the cabin roof, the vents on it, the boards on its sides (they won't cut
## down), the stand it was shown on and its waterline ring are left out.
## Each part is cut down to PSX size and painted a flat colour: a white hull with a red bottom, a teak deck, blue
## stripes and dark glass. The bow points +z.

const SRC := "res://psx/ferry/"
const OUT := "res://assets/psx/models/ferry.res"
## part number: [what it is (its colour), most triangles kept]
const PARTS := {
	22: ["body", 3400],
	0: ["rail", 500],
	23: ["light", 60],
	26: ["stripe", 160],
	27: ["stripe", 16],
	29: ["stripe", 160],
	30: ["glass", 160],
	32: ["glass", 40],
}
const COLOURS := {
	"hull": Color("#f2f0ea"),
	"bottom": Color("#b8382e"),
	"deck": Color("#c49c6c"),
	"top": Color("#dedcd4"),
	"rail": Color("#b8bcc4"),
	"light": Color("#f0c040"),
	"stripe": Color("#2c5c9c"),
	"glass": Color("#22303e"),
}
## the body's red bottom paint reaches this high (pack units; it floats about 0.18 deep, so a band shows above water)
const BOOT := 0.24
## above this the body's upward faces are its cabin roof, below it its decks
const ROOF := 0.85


func _init() -> void:
	var groups := {}
	var bb := AABB()
	var first := true
	for part in PARTS:
		var e: Array = PARTS[part]
		var arrays := _read_obj(ProjectSettings.globalize_path(SRC + "model_%d.obj" % part))
		var full: int = (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		arrays = _cut(arrays, int(e[1]))
		print("  model_%-3d %-7s %6d -> %4d tris" % [part, e[0], full, (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3])
		for c in _painted(arrays, String(e[0])):
			if not groups.has(c[0]):
				groups[c[0]] = SurfaceTool.new()
				(groups[c[0]] as SurfaceTool).begin(Mesh.PRIMITIVE_TRIANGLES)
			var st: SurfaceTool = groups[c[0]]
			var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in c[1]:
				st.set_normal(n[i])
				st.add_vertex(v[i])
				bb = AABB(v[i], Vector3.ZERO) if first else bb.expand(v[i])
				first = false
	# centred on x/z, standing on y = 0
	var off := Vector3(bb.get_center().x, bb.position.y, bb.get_center().z)
	var mesh := ArrayMesh.new()
	for c in groups:
		var arrays := (groups[c] as SurfaceTool).commit_to_arrays()
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in v.size():
			v[i] -= off
		arrays[Mesh.ARRAY_VERTEX] = v
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _material(String(c)))
	var err := ResourceSaver.save(mesh, OUT, ResourceSaver.FLAG_COMPRESS)
	var tris := 0
	for s in mesh.get_surface_count():
		tris += (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	print("  %s  %d tris  %s  %s" % [OUT, tris, mesh.get_aabb().size.snapped(Vector3.ONE * 0.01), "ok" if err == OK else "SAVE FAILED"])
	quit()


## One OBJ part's vertices, normals and triangles (turned to Godot's clockwise winding).
func _read_obj(path: String) -> Array:
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var index := PackedInt32Array()
	var seen := {}
	var f := FileAccess.open(path, FileAccess.READ)
	while not f.eof_reached():
		var line := f.get_line()
		if line.begins_with("v "):
			var p := line.split(" ", false)
			pos.append(Vector3(float(p[1]), float(p[2]), float(p[3])))
		elif line.begins_with("vn "):
			var p := line.split(" ", false)
			nrm.append(Vector3(float(p[1]), float(p[2]), float(p[3])))
		elif line.begins_with("f "):
			var p := line.split(" ", false)
			var ids := PackedInt32Array()
			for k in range(1, p.size()):
				# one vertex per position and normal: the pack repeats vertices along its texture seams, and nothing here
				# is textured
				var parts := p[k].split("/")
				var at := pos[int(parts[0]) - 1]
				var nm := nrm[int(parts[2]) - 1] if parts.size() > 2 and parts[2] != "" else Vector3.UP
				var key := [at.snapped(Vector3.ONE * 0.00001), nm.snapped(Vector3.ONE * 0.01)]
				if not seen.has(key):
					seen[key] = verts.size()
					verts.append(at)
					norms.append(nm)
				ids.append(seen[key])
			for k in range(1, ids.size() - 1):
				index.append_array([ids[0], ids[k + 1], ids[k]])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = index
	return arrays


## The part cut down to about `most` triangles (its most detailed level of detail under that, or its least detailed).
func _cut(arrays: Array, most: int) -> Array:
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	im.generate_lods(25.0, 60.0, [])
	var pick: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for l in im.get_surface_lod_count(0):
		pick = im.get_surface_lod_indices(0, l)
		if pick.size() / 3 <= most:
			break
	var out := im.get_surface_arrays(0)
	out[Mesh.ARRAY_INDEX] = pick
	return out


## The part's triangles by colour: [[colour, vertex indices], ...]. The body is split into its red bottom, its decks,
## its cabin roof and its white sides; every other part is one colour.
func _painted(arrays: Array, what: String) -> Array:
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if what != "body":
		return [[what, index]]
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var by := {}
	for t in range(0, index.size(), 3):
		var a := v[index[t]]
		var b := v[index[t + 1]]
		var c := v[index[t + 2]]
		var mid := (a + b + c) / 3.0
		# clockwise front faces: this is the outward normal
		var up := (c - a).cross(b - a).normalized().y
		var col := "hull"
		if mid.y < BOOT:
			col = "bottom"
		elif up > 0.8:
			col = "top" if mid.y > ROOF else "deck"
		if not by.has(col):
			by[col] = []
		(by[col] as Array).append_array([index[t], index[t + 1], index[t + 2]])
	var out := []
	for col in by:
		out.append([col, PackedInt32Array(by[col])])
	return out


func _material(what: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = COLOURS[what]
	m.roughness = 0.35 if what == "glass" else 1.0
	m.metallic_specular = 0.6 if what in ["glass", "rail"] else 0.2
	return m
