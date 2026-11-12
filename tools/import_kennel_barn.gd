extends SceneTree
## Bakes the supplied Small Barn (licenses/kennel_barn.md) into the kennel barn the roads' kennels are built from
## (scripts/gfx/barn_builder.gd). Prepare build/kennel_barn_source with tools/prepare_kennel_barn.py first:
##   godot --headless --path . --script res://tools/import_kennel_barn.gd
##   godot --headless --path . --import
## The model's colour atlas is flat paint with a fine canvas grain, and its boards and shingles are modelled, so the
## bake keeps no texture: each triangle goes to a surface by the colour it was painted (paint, trim, roof, detail),
## and the builder colours those per region. The barn is turned to face +z, its doors centred on x = 0, fitted to
## four tiles across, and its ground storey stretched so the barn doors stand DOOR_TOP tall (AGENTS.md, "Building
## exteriors and scale"). Its length is baked as one unit (front at z = +0.5): the builder stretches it to the plot.
const SRC := "res://build/kennel_barn_source/"
const OUT := "res://assets/exteriors/kennel_barn.res"
## the barn's width in tiles' units, the height its door tops are stretched to, and where they are in the source
const WIDTH := 3.86
const DOOR_TOP := 2.1
const SRC_DOOR_TOP := 11.0
## the source's front wall plane (its doors and frames stand out in front of it); how much of that relief is kept
const SRC_WALL_Z := -15.2
const RELIEF := 0.45


func _init() -> void:
	var vs := []
	var uvs := []
	var ns := []
	var tris := []
	for l in FileAccess.get_file_as_string(SRC + "model_0.obj").split("\n"):
		var p := l.strip_edges().split(" ", false)
		if p.size() < 3:
			continue
		match p[0]:
			"v":
				vs.append(Vector3(float(p[1]), float(p[2]), float(p[3])))
			"vt":
				uvs.append(Vector2(float(p[1]), 1.0 - float(p[2])))
			"vn":
				ns.append(Vector3(float(p[1]), float(p[2]), float(p[3])))
			"f":
				var idx := []
				for c in range(1, p.size()):
					var e := p[c].split("/")
					idx.append([int(e[0]) - 1, int(e[1]) - 1, int(e[2]) - 1])
				for t in range(1, idx.size() - 1):
					tris.append([idx[0], idx[t], idx[t + 1]])
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for v: Vector3 in vs:
		lo = lo.min(v)
		hi = hi.max(v)
	var image := Image.load_from_file(SRC + "phong1_albedo.png")
	image.resize(1024, 1024, Image.INTERPOLATE_LANCZOS)
	var sx := WIDTH / (hi.x - lo.x)
	var cx := (hi.x + lo.x) / 2.0
	var low_k := DOOR_TOP / SRC_DOOR_TOP
	var length := hi.z - SRC_WALL_Z
	var names := ["paint", "trim", "roof", "detail"]
	var tools := []
	for n in names:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools.append(st)
	var counts := [0, 0, 0, 0]
	for t in tris:
		var uv: Vector2 = (uvs[t[0][1]] + uvs[t[1][1]] + uvs[t[2][1]]) / 3.0
		var col := image.get_pixel(clampi(int(uv.x * 1024.0), 0, 1023), clampi(int(uv.y * 1024.0), 0, 1023))
		var a: Vector3 = vs[t[0][0]]
		var face_n := ((vs[t[1][0]] as Vector3) - a).cross((vs[t[2][0]] as Vector3) - a).normalized()
		var kind := 3
		var shade := Color.WHITE
		if col.r > 0.45 and col.g < col.r * 0.6:
			kind = 0
		elif col.get_luminance() > 0.5 and col.s < 0.25:
			kind = 1
		elif col.v < 0.22 and absf(face_n.y) > 0.12:
			kind = 2
		else:
			# brass brackets, iron handles, and the dark behind the cupola's slats: their own colours, lifted a little
			shade = Color(col.r, col.g, col.b).lightened(0.08)
			if col.v < 0.22:
				shade = Color("#3a3230")
		counts[kind] += 1
		var st: SurfaceTool = tools[kind]
		for c in [0, 2, 1]:
			var v: Vector3 = vs[t[c][0]]
			var n: Vector3 = ns[t[c][2]]
			var z := v.z
			if z < SRC_WALL_Z:
				z = SRC_WALL_Z + (z - SRC_WALL_Z) * RELIEF
			var y := v.y * low_k if v.y <= SRC_DOOR_TOP else DOOR_TOP + (v.y - SRC_DOOR_TOP) * sx
			st.set_color(shade)
			st.set_normal(Vector3(-n.x, n.y, -n.z))
			# turned to face +z; the wall plane is the front (z = 0.5), the doors' relief stands just in front of it
			st.add_vertex(Vector3(-(v.x - cx) * sx, y, 0.5 - (z - SRC_WALL_Z) / length))
	var mesh := ArrayMesh.new()
	for i in names.size():
		if counts[i] == 0:
			continue
		var material := StandardMaterial3D.new()
		material.resource_name = names[i]
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = true
		material.roughness = 0.9
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_color = [Color("#c8483c"), Color("#f4ecdc"), Color("#5a5058"), Color.WHITE][i]
		var st: SurfaceTool = tools[i]
		st.set_material(material)
		st.index()
		st.commit(mesh)
		mesh.surface_set_name(mesh.get_surface_count() - 1, names[i])
	ResourceSaver.save(mesh, OUT, ResourceSaver.FLAG_COMPRESS)
	print("KENNEL BARN BAKED: ", tris.size(), " triangles ", counts, " size ", mesh.get_aabb())
	quit()
