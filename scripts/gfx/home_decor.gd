extends RefCounted
## The home decor kit (runbook 037a; tools/import_home_decor.gd bakes it into assets/interiors/home/): lamps, plants,
## framed prints, wall pieces, trim, cushions and tabletop things. Every piece is coloured by its room's scheme
## (assets/interiors/home/schemes.json): one atlas material per scheme, one print material per print, crop and
## colourway, all cached, so a room adds a handful of materials whatever it holds.
## Framed art shows only the user's SVG prints (art_layout.json); never put other artwork in a frame.

const DIR := "res://assets/interiors/home/"
const ATLAS := "res://assets/interiors/tex/home_decor_atlas.png"
const SHADER := preload("res://scripts/gfx/home_decor.gdshader")
const PRINT_SHADER := preload("res://scripts/gfx/home_print.gdshader")
const DEFAULT_SCHEME := "seafoam_cottage"
## The player's bedroom print (the user's choice, 2026-11-12).
const ROCKET := "deep-IHWzHs98vQ8"

static var _meshes := {}
static var _mats := {}
static var _schemes := {}
static var _prints := {}


static func schemes() -> Dictionary:
	if _schemes.is_empty():
		_schemes = JSON.parse_string(FileAccess.get_file_as_string(DIR + "schemes.json"))["schemes"]
	return _schemes


static func print_defs() -> Dictionary:
	if _prints.is_empty():
		_prints = JSON.parse_string(FileAccess.get_file_as_string(DIR + "art_layout.json"))["prints"]
	return _prints


static func scheme(name: String) -> Dictionary:
	return schemes().get(name, schemes()[DEFAULT_SCHEME])


static func mesh(name: String) -> Mesh:
	if not _meshes.has(name):
		_meshes[name] = load(DIR + name + ".res") if ResourceLoader.exists(DIR + name + ".res") else null
	return _meshes[name]


## The atlas material for a scheme (or explicit tints: fabric, ceramic, wood, trim).
static func atlas_material(scheme_name: String, over := {}) -> Material:
	var key := "atlas:%s:%s" % [scheme_name, str(over)]
	if not _mats.has(key):
		var s := scheme(scheme_name)
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("atlas", load(ATLAS))
		m.set_shader_parameter("fabric", Color(over.get("fabric", s["fabric"])))
		m.set_shader_parameter("ceramic", Color(over.get("ceramic", s["ceramic"])))
		m.set_shader_parameter("wood", Color(over.get("wood", s["floor"])))
		m.set_shader_parameter("trim", Color(over.get("trim", s["trim"])))
		_mats[key] = m
	return _mats[key]


## A print's material: `print_id` (art_layout.json), its `crop` (portrait, landscape, square), in a colourway (a
## scheme's name or "jewel_pop"), shown on a canvas whose UVs were made for `src` ("print:crop").
static func print_material(print_id: String, crop: String, colourway: String, src: String) -> Material:
	var key := "print:%s:%s:%s:%s" % [print_id, crop, colourway, src]
	if not _mats.has(key):
		var p: Dictionary = print_defs().get(print_id, print_defs().values()[0])
		var sp: PackedStringArray = src.split(":")
		var s: Dictionary = print_defs().get(sp[0], p)
		var cols: Array = p["colourways"].get(colourway, p["colourways"][DEFAULT_SCHEME])
		var m := ShaderMaterial.new()
		m.shader = PRINT_SHADER
		m.set_shader_parameter("masks", load(DIR + "art_masks.png"))
		# ("unit": a canvas whose UVs run 0..1 over the print, as framed_print makes them)
		var su: Array = [0.0, 0.0, 1.0, 1.0] if src == "unit" else s["uv_" + (sp[1] if sp.size() > 1 else crop)]
		var du: Array = p["uv_" + crop]
		m.set_shader_parameter("src", Vector4(su[0], su[1], su[2], su[3]))
		m.set_shader_parameter("dst", Vector4(du[0], du[1], du[2], du[3]))
		# (a print of fewer colours leaves its spare slots empty; their masks are empty too)
		for i in 4:
			var col = cols[i] if i < cols.size() else null
			m.set_shader_parameter("slot%d" % i, Color(col) if col is String else Color(cols[0]))
		_mats[key] = m
	return _mats[key]


## The print crop a framed piece shows (its default print's crop), or "" if it has no canvas.
static func crop_of(name: String) -> String:
	var m := mesh(name)
	if m == null or not m.has_meta("print") or m.get_meta("print") == null:
		return ""
	return String(m.get_meta("print")).get_slice(":", 1)


## A piece, coloured for `scheme_name`; framed pieces show `print_id` (else their own default print).
static func make(name: String, scheme_name: String, print_id := "", colourway := "", over := {}) -> MeshInstance3D:
	var m := mesh(name)
	if m == null:
		return null
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = m
	mi.set_surface_override_material(0, atlas_material(scheme_name, over))
	if m.get_surface_count() > 1:
		var src := String(m.get_meta("print", ""))
		var crop := src.get_slice(":", 1)
		var pid := print_id if print_id != "" else src.get_slice(":", 0)
		mi.set_surface_override_material(1, print_material(pid, crop, colourway if colourway != "" else scheme_name, src))
	return mi


## Prints for a room, seeded, never the same twice in one room.
static func pick_prints(seed: int, n: int, avoid := []) -> Array:
	var ids: Array = print_defs().keys().filter(func(k): return not k in avoid)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var out := []
	while out.size() < n and not ids.is_empty():
		out.append(ids.pop_at(rng.randi_range(0, ids.size() - 1)))
	return out


# ---------------------------------------------------------------- boxy framed prints (2026-11-15)
## The user's direction: paintings have thick, boxy frames, and come large enough to hold a wall on their own.
## A frame w wide and h tall (outer), its back on z = 0 facing +z, centred on x and y; the print sits a little back
## inside the frame. Painted frames take the scheme's trim, the others its wood.
static var _frame_meshes := {}
const WOOD_CELL := Vector2(0.4378, 0.3125)
const PAINT_CELL := Vector2(0.5625, 0.1875)


## The crop that suits a frame's shape.
static func crop_for(w: float, h: float) -> String:
	return "landscape" if w > h * 1.2 else ("portrait" if h > w * 1.15 else "square")


static func _box(st: SurfaceTool, c: Vector3, sz: Vector3, col: Color, uv: Vector2) -> void:
	var hx := sz / 2.0
	for f in [[Vector3.BACK, Vector3.RIGHT, Vector3.UP], [Vector3.UP, Vector3.RIGHT, Vector3.FORWARD], [Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
			[Vector3.RIGHT, Vector3.FORWARD, Vector3.UP], [Vector3.LEFT, Vector3.BACK, Vector3.UP]]:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var o := c + n * (hx * n).length() * 1.0
		var eu := (hx * u).abs().length()
		var ev := (hx * v).abs().length()
		var q := [o - u * eu - v * ev, o + u * eu - v * ev, o + u * eu + v * ev, o - u * eu + v * ev]
		var e1: Vector3 = q[1] - q[0]
		var e2: Vector3 = q[2] - q[0]
		# (Godot's front faces wind clockwise as seen from outside)
		var order := [0, 2, 1, 0, 3, 2] if e1.cross(e2).dot(n) > 0.0 else [0, 1, 2, 0, 2, 3]
		# the sides a little darker, so the frame's thickness reads
		var shade := 1.0 if n == Vector3.BACK else 0.82
		for k in order:
			st.set_color(col)
			st.set_normal(n)
			st.set_uv(uv + Vector2(0.0, 0.03 * (1.0 - shade)))
			st.add_vertex(q[k])


static func frame_mesh(w: float, h: float, painted: bool) -> ArrayMesh:
	var key := "%.2f:%.2f:%s" % [w, h, painted]
	if _frame_meshes.has(key):
		return _frame_meshes[key]
	var b := clampf(minf(w, h) * 0.12, 0.06, 0.13)
	var d := 0.07 if maxf(w, h) < 0.9 else 0.09
	var col := Color(0, 0, 0, 1) if painted else Color(0, 0, 1, 0)
	var uv := PAINT_CELL if painted else WOOD_CELL
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, Vector3(0, h / 2.0 - b / 2.0, d / 2.0), Vector3(w, b, d), col, uv)
	_box(st, Vector3(0, -h / 2.0 + b / 2.0, d / 2.0), Vector3(w, b, d), col, uv)
	_box(st, Vector3(-w / 2.0 + b / 2.0, 0, d / 2.0), Vector3(b, h - b * 2.0, d), col, uv)
	_box(st, Vector3(w / 2.0 - b / 2.0, 0, d / 2.0), Vector3(b, h - b * 2.0, d), col, uv)
	var mesh := st.commit()
	# the canvas, set back inside the frame
	var cw := w / 2.0 - b
	var ch := h / 2.0 - b
	var z := d * 0.45
	var cs := SurfaceTool.new()
	cs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var q := [Vector3(-cw, -ch, z), Vector3(cw, -ch, z), Vector3(cw, ch, z), Vector3(-cw, ch, z)]
	var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for k in [0, 2, 1, 0, 3, 2]:
		cs.set_normal(Vector3.BACK)
		cs.set_uv(uvs[k])
		cs.add_vertex(q[k])
	cs.commit(mesh)
	# the inner lip between frame and canvas
	_frame_meshes[key] = mesh
	return mesh


## A boxy framed print, w x h, coloured for `scheme_name`; `print_id` "" picks the frame's own default.
static func framed_print(w: float, h: float, print_id: String, scheme_name: String, colourway := "", painted := false, over := {}) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "FramedPrint"
	mi.mesh = frame_mesh(w, h, painted)
	mi.set_surface_override_material(0, atlas_material(scheme_name, over))
	var pid := print_id if print_id != "" else String(print_defs().keys()[0])
	mi.set_surface_override_material(1, print_material(pid, crop_for(w, h), colourway if colourway != "" else scheme_name, "unit"))
	return mi
