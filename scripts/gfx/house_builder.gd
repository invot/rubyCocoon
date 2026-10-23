extends RefCounted
## Houses and shops built from the PSX house pack's own wall sections (assets/exteriors, baked by
## tools/import_psx_exterior.gd): real doors, windows with frames and glass, shutters, corner posts and railings,
## with each building's wall finish (plaster, brick, timber, adobe, planks, stone) laid over the pack's walls in world
## space, so every piece of a front carries the same wall, and a pitched, hipped, flat or false-front roof from
## voxel_buildings.gd on top.
## A building's local origin is the centre of its footprint at ground level; the front faces +Z.
##
## Fronts are laid out across each storey: the door on its tile, then the spans either side filled with windows where
## there's room and plain wall where there isn't; the sides get a window each on deep buildings; the back is plain.
## Houses have one or two storeys, shops a shop front (wide display windows, an awning and a sign board) under one
## storey of rooms.

const VT = preload("res://scripts/gfx/voxel_textures.gd")
const DIR := "res://assets/exteriors/"
## a storey's height and how far the walls stand in from the footprint's edge
const STOREY := 2.8
const INSET := 0.1
## the pack's pieces are a 3 m storey; this squashes them to STOREY
const SY := STOREY / 3.0
## wall thickness (the pack's walls are 0.2 m)
const THICK := 0.2

static var _meshes := {}
static var _wall_mats := {}


static func piece(name: String) -> Mesh:
	if not _meshes.has(name):
		_meshes[name] = load(DIR + name + ".res") if ResourceLoader.exists(DIR + name + ".res") else null
		if _meshes[name] == null:
			push_warning("model missing: " + DIR + name + ".res")
	return _meshes[name]


## A wall finish: one of the game's PSX surface textures, tinted, mapped in world space so it runs on unbroken across
## every piece of a front (and lines up with the gable ends the roof builder draws).
static func wall_material(kind: String, col: Color) -> StandardMaterial3D:
	var key := "%s:%s" % [kind, col.to_html()]
	if _wall_mats.has(key):
		return _wall_mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = VT.texture(kind)
	m.albedo_color = col
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_triplanar_sharpness = 8.0
	m.uv1_scale = Vector3.ONE / VT.PSX_SPAN
	m.roughness = 0.95
	_wall_mats[key] = m
	return m


var node: Node3D
var w := 0.0
var d := 0.0
var rng := RandomNumberGenerator.new()
var walls: Array = []
var wall_mat: Material
var upper_mat: Material
var _mm := {}


## Puts one piece on a wall: `side` is the wall (front +z, back -z, right +x, left -x), `along` the position of the
## piece's centre along that wall (x for front and back, z for the sides), `width` the span it fills, `y0` its foot.
## `mat` is the wall finish laid over its "wall" surface.
func place(name: String, side: Vector2i, along: float, width: float, y0: float, mat: Material, natural := 0.0) -> void:
	var m := piece(name)
	if m == null:
		return
	var pw := m.get_aabb().size.x
	var yaw := atan2(float(side.x), float(side.y))
	var basis := Basis(Vector3.UP, yaw).scaled_local(Vector3(width / pw, SY, 1.0))
	var line := (d / 2.0 - INSET - THICK) if side.y != 0 else (w / 2.0 - INSET - THICK)
	var origin := Vector3(side.x * line, y0, side.y * line)
	if side.y != 0:
		origin.x = along
	else:
		origin.z = along
	_add(m, Transform3D(basis, origin), mat)


## Puts one piece on a wall at any angle: the wall's outer face runs from `a` to `b` (x/z), its outside away from
## `centre`, `h` tall from `y0` (a storey, or less). Round towers, curved shop fronts and the arena's oval are built
## of these: neighbouring pieces meet at their outer corners, so a ring of them closes without gaps.
func span(name: String, a: Vector2, b: Vector2, y0: float, mat: Material, centre := Vector2.ZERO, h := STOREY) -> void:
	var m := piece(name)
	if m == null:
		return
	var along := b - a
	var n := Vector2(along.y, -along.x).normalized()
	var mid := (a + b) / 2.0
	if n.dot(mid - centre) < 0.0:
		n = -n
	var basis := Basis(Vector3.UP, atan2(n.x, n.y)).scaled_local(Vector3(along.length() / m.get_aabb().size.x, h / 3.0, 1.0))
	_add(m, Transform3D(basis, Vector3(mid.x - n.x * THICK, y0, mid.y - n.y * THICK)), mat)


func _add(m: Mesh, xf: Transform3D, mat: Material) -> void:
	# gathered by mesh and finish
	var k := "%d:%d" % [m.get_instance_id(), mat.get_instance_id() if mat != null else 0]
	if not _mm.has(k):
		_mm[k] = {"mesh": m, "mat": mat, "xf": []}
	(_mm[k]["xf"] as Array).append(xf)


func finish() -> void:
	for k in _mm:
		var e: Dictionary = _mm[k]
		var xfs: Array = e["xf"]
		for xf in xfs:
			var mi := MeshInstance3D.new()
			mi.mesh = e["mesh"]
			mi.transform = xf
			if e["mat"] != null:
				for s in (e["mesh"] as Mesh).get_surface_count():
					if (e["mesh"] as Mesh).surface_get_name(s) == "wall":
						mi.set_surface_override_material(s, e["mat"])
			node.add_child(mi)


## Fills a span of wall [a, b] (along it) on one storey with windows where they fit, plain wall where they don't.
## `kinds`: the window pieces to use, by width in pack metres {2: [...], 3: [...]}.
func fill(side: Vector2i, a: float, b: float, y0: float, mat: Material, kinds: Dictionary, shutters: bool) -> void:
	var span := b - a
	if span < 0.05:
		return
	if span < 0.95 or kinds.is_empty():
		place("wall_2" if span > 1.4 else "wall_1", side, (a + b) / 2.0, span, y0, mat)
		return
	# as many windows as fit at about 2 m apiece (or 3 m for the wide ones), each centred in its share of the span
	var wide: bool = kinds.has(3) and span >= 2.6
	var unit := 2.7 if wide else 1.85
	var n := maxi(1, int(round(span / unit)))
	var share := span / n
	var list: Array = kinds[3] if wide else kinds[2]
	var pick: String = list[rng.randi_range(0, list.size() - 1)]
	for i in n:
		var c := a + share * (i + 0.5)
		place(pick, side, c, share, y0, mat)
		if shutters and not wide:
			_shutters(side, c, share, y0, pick.begins_with("win_small"))


## Open shutters either side of a window (the pack's own), a little in front of the wall.
func _shutters(side: Vector2i, along: float, share: float, y0: float, small: bool) -> void:
	var m := piece("shutters_small_1" if small else ["shutters_open_1", "shutters_open_2"][rng.randi_range(0, 1)])
	if m == null:
		return
	var bb := m.get_aabb()
	var yaw := atan2(float(side.x), float(side.y))
	var sx := minf(1.0, share * 0.95 / bb.size.x)
	var basis := Basis(Vector3.UP, yaw).scaled_local(Vector3(sx, SY, 1.0))
	var line := d / 2.0 - INSET if side.y != 0 else w / 2.0 - INSET
	# the shutters hang beside the window opening: about halfway up a full window, higher on a small one
	var y := y0 + (0.55 if not small else 1.45) * SY
	var origin := Vector3(side.x * line, y, side.y * line)
	if side.y != 0:
		origin.x = along
	else:
		origin.z = along
	_add(m, Transform3D(basis, origin - Basis(Vector3.UP, yaw) * Vector3(0, 0, bb.position.z)), null)


## A corner post at each corner of a storey, hiding where the walls meet: boxes in the trim colour, into `k`
## (a voxel_buildings Kit).
func corners(k, y0: float, h: float, trim: Color) -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := Vector3(sx * (w / 2.0 - INSET - THICK / 2.0), y0 + h / 2.0, sz * (d / 2.0 - INSET - THICK / 2.0))
			k.box("planks", p, Vector3(THICK + 0.1, h, THICK + 0.1), trim)


## One storey's four walls. `front`: true lays out the front with the door (ground floor) or windows; the spans either
## side of `door_lx` (or the whole front when there's no door here) take windows.
func storey(y0: float, mat: Material, door: String, door_lx: float, kinds: Dictionary, shutters: bool, side_windows: bool) -> void:
	var x0 := -w / 2.0 + INSET + THICK
	var x1 := w / 2.0 - INSET - THICK
	if door != "":
		var dw := minf(1.8, 2.0 * minf(door_lx - x0, x1 - door_lx))
		dw = maxf(dw, 1.15)
		place(door, Vector2i(0, 1), door_lx, dw, y0, mat)
		fill(Vector2i(0, 1), x0, door_lx - dw / 2.0, y0, mat, kinds, shutters)
		fill(Vector2i(0, 1), door_lx + dw / 2.0, x1, y0, mat, kinds, shutters)
	else:
		fill(Vector2i(0, 1), x0, x1, y0, mat, kinds, shutters)
	# the back: plain
	place("wall_2", Vector2i(0, -1), 0.0, x1 - x0, y0, mat)
	# the sides: a window in the middle of a deep side
	var z0 := -d / 2.0 + INSET + THICK
	var z1 := d / 2.0 - INSET - THICK
	for sx in [-1, 1]:
		var side := Vector2i(sx, 0)
		if side_windows and z1 - z0 >= 2.2:
			var c := (z0 + z1) / 2.0
			fill(side, z0, c - 0.8, y0, mat, {}, false)
			place("win_small_1", side, c, 1.6, y0, mat)
			fill(side, c + 0.8, z1, y0, mat, {}, false)
		else:
			place("wall_2", side, (z0 + z1) / 2.0, z1 - z0, y0, mat)
