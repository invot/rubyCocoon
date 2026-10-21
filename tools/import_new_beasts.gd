extends SceneTree
## Turns the baked new beasts (tools/new_beasts/bake.py: tools/new_beasts/out/<form>.json) into the game's meshes,
## assets/beasts/<form>.res.
##   python tools/new_beasts/bake.py "path/to/new beasts"
##   godot --headless --path . --script res://tools/import_new_beasts.gd [-- form1 form2 ...]
##
## Each mesh is in beast space (facing +x, standing on y = 0, its larger measure 1 unit) and skinned to one bone per
## part (bake.py PARTS, in that order): every vertex follows its part's bone by its weight and the part's parent's
## by the rest, so a limb bends where it grows out of the body; horns and eyes follow the part they're on. What the toon shader (scripts/gfx/beast_toon.gdshader)
## paints by is in the vertex colour: r = the part (index / 15), g = tip (or an eye's pupil), b = belly, a = how far
## forward it is (x / 2 + 0.5); UV = the part's pattern (round its upright axis, height) and UV2 = (z, y), where
## painted eyes are placed. Meta: "parts" (names), "joints" ({part: Vector3}), "parents" ({part: part}), "body" (its
## kind: quad, biped, flyer, serpent or blob).

const SRC := "res://tools/new_beasts/out/"
const OUT := "res://assets/beasts/"


func _init() -> void:
	var only := OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var n := 0
	for fn in DirAccess.get_files_at(SRC):
		if not fn.ends_with(".json"):
			continue
		var form := fn.get_basename()
		if not only.is_empty() and not form in only:
			continue
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SRC + fn))
		var mesh := build(d)
		var err := ResourceSaver.save(mesh, OUT + form + ".res", ResourceSaver.FLAG_COMPRESS)
		print("%-12s %5d verts  %s" % [form, mesh.surface_get_array_len(0), "saved" if err == OK else "ERROR %d" % err])
		n += 1
	print("new beasts imported: ", n)
	quit()


static func build(d: Dictionary) -> ArrayMesh:
	var parts: Array = d["parts"]
	var pv: Array = d["verts"]
	var pn: Array = d["normals"]
	var vpart: Array = d["vpart"]
	var attach: Array = d["attach"]
	var weight: Array = d["weight"]
	var tip: Array = d["tip"]
	var belly: Array = d["belly"]
	var pat: Array = d["pattern"]
	var parents: Dictionary = d["parents"]
	var count := vpart.size()
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	verts.resize(count)
	norms.resize(count)
	cols.resize(count)
	uv.resize(count)
	uv2.resize(count)
	bones.resize(count * 4)
	weights.resize(count * 4)
	for i in count:
		var p := Vector3(pv[i * 3], pv[i * 3 + 1], pv[i * 3 + 2])
		verts[i] = p
		var nn := Vector3(pn[i * 3], pn[i * 3 + 1], pn[i * 3 + 2])
		norms[i] = nn.normalized() if nn.length() > 0.001 else Vector3.UP
		var k := int(vpart[i])
		cols[i] = Color(float(k) / 15.0, float(tip[i]), float(belly[i]), clampf(p.x * 0.5 + 0.5, 0.0, 1.0))
		uv[i] = Vector2(pat[i * 2], pat[i * 2 + 1])
		uv2[i] = Vector2(p.z, p.y)
		var b := int(attach[i])
		var parent := parts.find(String(parents.get(parts[b], "body")))
		var w := float(weight[i]) if b != 0 else 1.0
		bones[i * 4] = b
		bones[i * 4 + 1] = maxi(parent, 0)
		weights[i * 4] = w
		weights[i * 4 + 1] = 1.0 - w
	# the source winds its faces anticlockwise; Godot's front faces wind clockwise
	var faces: Array = d["faces"]
	var idx := PackedInt32Array()
	idx.resize(faces.size())
	for t in range(0, faces.size(), 3):
		idx[t] = int(faces[t])
		idx[t + 1] = int(faces[t + 2])
		idx[t + 2] = int(faces[t + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var joints := {}
	for k in d["joints"]:
		var j: Array = d["joints"][k]
		joints[k] = Vector3(j[0], j[1], j[2])
	mesh.set_meta("parts", parts)
	mesh.set_meta("joints", joints)
	mesh.set_meta("parents", parents)
	mesh.set_meta("body", String(d.get("body", "quad")))
	return mesh
