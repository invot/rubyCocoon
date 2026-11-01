extends SceneTree
## Bakes Dustwell Oasis's street furniture from a downloaded pack (see CREDITS.md):
##   godot --headless --path . --script res://tools/import_western.gd -- "path/to/unzipped packs"
## then tools/smooth_textures.gd and --import, as for any baked scenery.
##
## The folder holds the pack unzipped into its own folder:
##   lpwestern/  Low Poly Western.zip: untextured models; its covered wagon and water trough become street furniture
##               (assets/exteriors/wagon.res, water_trough.res), painted here by part in flat, bright colours like the
##               rest of the town: a red wagon on yellow wheels, a wooden trough holding water.
## Every piece comes out in game units, centred on x/z and standing on y = 0.

const Bake = preload("res://tools/import_psx_models.gd")
const STREET := "res://assets/exteriors/"
## the wagon's and the trough's lengths on the street
const WAGON_LONG := 2.1
const TROUGH_LONG := 1.7

var _baker


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("usage: -- <folder holding lpwestern/>")
		quit(1)
		return
	var root: String = args[0]
	_baker = Bake.new()
	_wagon(root.path_join("lpwestern/collection/model_3.obj"))
	_trough(root.path_join("lpwestern/collection/model_4.obj"))
	_baker.free()
	quit()


# ---------------------------------------------------------------- street furniture
## The covered wagon: its four wheels (thin across the axle, as tall as they are long) yellow with dark hubs, the bed
## and its rails red, the shafts and running gear a darker wood.
func _wagon(path: String) -> void:
	var obj := _read(path)
	if obj.is_empty():
		return
	var off := _foot(obj)
	var parts := _parts(obj)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var box := _bounds(obj["v"], range(obj["v"].size()))
	# two tiles long
	var unit := WAGON_LONG / maxf(box.size.x, box.size.z)
	for p in parts:
		var bb := _bounds(obj["v"], p["verts"])
		var col := Color("#c8483a")
		var thin := bb.size.z < 0.3 * maxf(bb.size.x, bb.size.y)
		var round_ := absf(bb.size.x - bb.size.y) < 0.35 * maxf(bb.size.x, bb.size.y)
		if thin and round_ and bb.size.y > box.size.y * 0.25:
			col = Color("#f0b83c")
		elif bb.get_center().y < box.position.y + box.size.y * 0.35 or bb.size.y < box.size.y * 0.05 and bb.size.x > box.size.x * 0.5:
			col = Color("#7a4a2c")
		elif bb.size.y < box.size.y * 0.08 and maxf(bb.size.x, bb.size.z) < box.size.x * 0.12:
			col = Color("#3a2a24")
		_emit(st, obj, p["corners"], off, col, box, unit)
	_save_painted(st, STREET + "wagon.res")


## The water trough: an open plank box, with water standing a little below its rim.
func _trough(path: String) -> void:
	var obj := _read(path)
	if obj.is_empty():
		return
	var off := _foot(obj)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var box := _bounds(obj["v"], range(obj["v"].size()))
	var unit := TROUGH_LONG / maxf(box.size.x, box.size.z)
	_emit(st, obj, obj["corners"], off, Color("#9a5e34"), box, unit)
	var s: Vector3 = box.size * unit
	var y := s.y * 0.78
	var inset := minf(s.x, s.z) * 0.12
	var q := [Vector3(-s.x / 2 + inset, y, -s.z / 2 + inset), Vector3(s.x / 2 - inset, y, -s.z / 2 + inset),
		Vector3(s.x / 2 - inset, y, s.z / 2 - inset), Vector3(-s.x / 2 + inset, y, s.z / 2 - inset)]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_color(Color("#4aa8d8"))
		st.set_normal(Vector3.UP)
		st.add_vertex(q[i])
	_save_painted(st, STREET + "water_trough.res")


func _emit(st: SurfaceTool, obj: Dictionary, corners: Array, off: Vector3, col: Color, box: AABB, unit: float) -> void:
	for c in corners:
		var p: Vector3 = obj["v"][c[0]]
		# a little darker towards the ground, as the furniture is
		var t := clampf((p.y - box.position.y) / maxf(box.size.y, 0.001), 0.0, 1.0)
		st.set_color(col.darkened(0.18 * (1.0 - t)))
		if c[2] >= 0:
			st.set_normal(obj["n"][c[2]])
		st.add_vertex((p - off) * unit)


func _save_painted(st: SurfaceTool, path: String) -> void:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.85
	st.set_material(mat)
	st.index()
	_save(st.commit(), path)


func _save(mesh: ArrayMesh, path: String) -> void:
	var err := ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
	print("  %-44s %6d tris  %s  %s" % [path, _baker._tris(mesh), mesh.get_aabb().size.snapped(Vector3.ONE * 0.01), "ok" if err == OK else "SAVE FAILED"])


# ---------------------------------------------------------------- reading the packs
## An OBJ: positions, UVs, normals and its triangles' corners ([position, uv, normal] indices, -1 for none), wound
## the way Godot draws front faces.
func _read(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("could not read " + path)
		return {}
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var n := PackedVector3Array()
	var corners := []
	while not f.eof_reached():
		var s := f.get_line().split(" ", false)
		if s.is_empty():
			continue
		match s[0]:
			"v":
				v.append(Vector3(s[1].to_float(), s[2].to_float(), s[3].to_float()))
			"vt":
				uv.append(Vector2(s[1].to_float(), s[2].to_float()))
			"vn":
				n.append(Vector3(s[1].to_float(), s[2].to_float(), s[3].to_float()).normalized())
			"f":
				var face := []
				for k in range(1, s.size()):
					var bits := s[k].split("/")
					face.append([bits[0].to_int() - 1, bits[1].to_int() - 1 if bits.size() > 1 and bits[1] != "" else -1,
						bits[2].to_int() - 1 if bits.size() > 2 and bits[2] != "" else -1])
				for k in range(1, face.size() - 1):
					corners.append_array([face[0], face[k + 1], face[k]])
	return {"v": v, "uv": uv, "n": n, "corners": corners}


## Where the model's footprint centre meets the ground (pack units).
func _foot(obj: Dictionary) -> Vector3:
	var bb := _bounds(obj["v"], range(obj["v"].size()))
	return Vector3(bb.get_center().x, bb.position.y, bb.get_center().z)


func _bounds(v: PackedVector3Array, idx) -> AABB:
	var bb := AABB()
	var first := true
	for i in idx:
		if first:
			bb = AABB(v[i], Vector3.ZERO)
			first = false
		else:
			bb = bb.expand(v[i])
	return bb


## The model's separate pieces (triangles joined by shared positions): [{corners, verts}].
func _parts(obj: Dictionary) -> Array:
	var corners: Array = obj["corners"]
	# (an Array, so the lambda below changes the same one)
	var parent := []
	for i in obj["v"].size():
		parent.append(i)
	var find := func(x: int) -> int:
		while parent[x] != x:
			parent[x] = parent[parent[x]]
			x = parent[x]
		return x
	for t in corners.size() / 3:
		var a: int = find.call(corners[t * 3][0])
		for k in [1, 2]:
			var b: int = find.call(corners[t * 3 + k][0])
			if a != b:
				parent[b] = a
	var by := {}
	for t in corners.size() / 3:
		var r: int = find.call(corners[t * 3][0])
		if not by.has(r):
			by[r] = {"corners": [], "verts": {}}
		for k in 3:
			by[r]["corners"].append(corners[t * 3 + k])
			by[r]["verts"][corners[t * 3 + k][0]] = true
	var out := []
	for r in by:
		out.append({"corners": by[r]["corners"], "verts": by[r]["verts"].keys()})
	return out
