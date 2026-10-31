extends SceneTree
## Bakes the Temple of Tides, on its isle off the Coral Reef, from the water temple island model in
## psx/water_temple/ (see CREDITS.md) into assets/houses/tide_temple.res:
##   godot --headless --path . --script res://tools/import_psx_tide_temple.gd
##
## The model comes as 22 OBJ parts with no materials: an island, its trees and rocks, a sea dome round it, and the
## temple. Only the temple is kept: its stepped platform, the grand stair up the front (+z, towards the camera) to
## its door, the sanctuary with its arcade, roof and dome, its windows, and the courtyard's flower beds. The parts
## hidden inside the sanctuary are left out, and so are the courtyard's carved paving, its beds' fretwork, the
## fountain's jet and the roof's fretted rim (about 50,000 triangles of flat detail that won't cut down; the
## platform's own top shows instead), and the foundation below the ground line. Each part is cut down to PS2 size and laid with ruin_stone.gdshader: weathered sandstone, pale
## walls and a verdigris roof and dome, all of it mossy and hung with vines.

const SRC := "res://psx/water_temple/"
const OUT := "res://assets/houses/tide_temple.res"
## part number: [what it is (its colour), most triangles kept]
const PARTS := {
	5: ["platform", 6000],
	6: ["bed", 300],
	10: ["door", 80],
	11: ["wall", 900],
	13: ["roof", 300],
	15: ["stair", 300],
	20: ["dome", 500],
	21: ["glass", 60],
}
## what: [texture, tint, moss on the tops, vines down the sides]
const LOOKS := {
	"stone": ["stone", Color("#d2bf98"), 0.55, 0.4],
	"step": ["stone", Color("#dccaa4"), 0.5, 0.2],
	"paving": ["ground_paving", Color("#cdbd98"), 0.45, 0.0],
	"wall": ["plaster", Color("#e6dcc6"), 0.6, 0.45],
	"bed": ["ground_grass", Color("#7a9a58"), 0.95, 0.6],
	"stair": ["stone", Color("#dccaa4"), 0.35, 0.1],
	"door": ["wood_dark", Color("#3a4a44"), 0.2, 0.3],
	"roof": ["slate", Color("#5aa8a0"), 0.5, 0.35],
	"dome": ["slate", Color("#64b4aa"), 0.4, 0.3],
}
const GLASS := Color("#9ae0f4")
## the ground line: the foot of the platform's lowest step (the pack's foundation and footings run on below it)
const GROUND := -0.2
## the platform's top: its upward faces above this are paving, below it the treads of its steps
const DECK := 2.2
## above this the platform part is the dome's drum and the sanctuary's arcade: white walls
const DRUM := 4.4


func _init() -> void:
	var groups := {}
	var bb := AABB()
	var first := true
	for part in PARTS:
		var e: Array = PARTS[part]
		var arrays := _read_obj(ProjectSettings.globalize_path(SRC + "model_%d.obj" % part))
		var full: int = (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		arrays = _cut(arrays, int(e[1]))
		print("  model_%-3d %-8s %6d -> %4d tris" % [part, e[0], full, (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3])
		arrays = _trimmed(arrays)
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
	# centred on x/z, standing on the ground line
	var off := Vector3(bb.get_center().x, GROUND, bb.get_center().z)
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
				# one vertex per position and normal (nothing here is textured)
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


## The part without what's below the ground.
func _trimmed(arrays: Array) -> Array:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var keep := PackedInt32Array()
	for t in range(0, index.size(), 3):
		var a := v[index[t]]
		var b := v[index[t + 1]]
		var c := v[index[t + 2]]
		if maxf(a.y, maxf(b.y, c.y)) < GROUND - 0.05:
			continue
		keep.append_array([index[t], index[t + 1], index[t + 2]])
	arrays[Mesh.ARRAY_INDEX] = keep
	return arrays


## The part's triangles by colour: [[colour, vertex indices], ...]. The platform is split into its paving, the
## treads of its steps, its sandstone sides, and the white drum and arcade above; every other part is one colour.
func _painted(arrays: Array, what: String) -> Array:
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if what != "platform":
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
		var col := "stone"
		if mid.y > DRUM:
			col = "wall"
		elif up > 0.8:
			col = "paving" if mid.y > DECK else "step"
		if not by.has(col):
			by[col] = []
		(by[col] as Array).append_array([index[t], index[t + 1], index[t + 2]])
	var out := []
	for col in by:
		out.append([col, PackedInt32Array(by[col])])
	return out


func _material(what: String) -> Material:
	if what == "glass":
		var g := StandardMaterial3D.new()
		g.albedo_color = GLASS
		g.roughness = 0.35
		g.metallic_specular = 0.6
		g.cull_mode = BaseMaterial3D.CULL_DISABLED
		return g
	var look: Array = LOOKS[what]
	return load("res://scripts/gfx/voxel_buildings.gd").ruin_stone(look[0], look[1], look[2], look[3])
