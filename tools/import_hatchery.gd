extends SceneTree
## Bakes the hatchery: the painted stone vault (tools/hatchery_chamber.gd) and the user-supplied platform and core OBJ
## packs, whose materials are rebuilt and repainted. Extract the two original archives to psx/hatchery/{core,platform}/
## first; originals stay untouched. --audit writes isolated parts to build/hatch_assets/ for the visual part audit;
## --conduit rebakes only the wire column, --room the column and vault, and --tongs only the tongs. --roundels bakes
## only the merge film's chamber from psx/hatchery/room/ and its white-and-steel cores.
const Chamber = preload("res://tools/hatchery_chamber.gd")
const SRC := "res://psx/hatchery/"
const AUDIT := "res://build/hatch_assets/meshes/"
const OUT := "res://assets/interiors/"
const BRONZE := [Color("#3a2f24"), Color("#8a7358"), Color("#dcc7a2")]
const STONE := [Color("#40414b"), Color("#94939c"), Color("#e3dfd6")]
const BRASS := [Color("#4d3b22"), Color("#a07f4a"), Color("#e6cd92")]
const STEEL_PAINT := [Color("#3a424b"), Color("#9ea9b3"), Color("#dfe5ea")]
const WHITE_STEEL_PAINT := [Color("#59626b"), Color("#c7ced4"), Color("#f4f6f8")]
## The merge chamber's shell, from the source's walls and ceiling. Its floor, console and rotor, the struts and cables
## around them and the doorway are left out.
const ROUNDEL_WALLS := [95]
const ROUNDEL_CEILING := [82, 83, 84]
## The source's windows. Only their positions are used.
const ROUNDEL_WINDOWS := 96
const WINDOW_RADIUS := 0.775
## The new panes sit this far behind the face of the wall, at the back of the hole, and are a little wider than it.
## Each is a disc, since a square's corners would poke into the neighbouring windows.
const PANE_DEPTH := 0.5
const PANE_RADIUS := 0.8
const PANE_SIDES := 24
const PANE_GLOW := 0.6
const BOTTLE_CELL := 192
const BOTTLE_KINDS := 4
## Dark, middle and bright glass, all in aquas and blues.
const BOTTLE_TINTS := [
	[Color("#021e26"), Color("#0b7f8c"), Color("#b4fbf2")],
	[Color("#02172f"), Color("#1160a4"), Color("#a6e2fa")],
	[Color("#062f38"), Color("#2ba5a4"), Color("#e8fffa")],
]
## The stone floor runs on to here, behind every wall.
const ROUNDEL_FLOOR_REACH := 19.0
## Baked shading, the way a PS2 room was lit: facets turned towards this are palest, and the walls darken towards the
## ceiling, the floor and their corners, so their shape still reads in a dim room.
const WALL_KEY := Vector3(0.5, 0.0, 0.87)
const WALL_TOP := 7.5
const CORNER_REACH := 1.6
## The inside of a window's hole, from the face of the wall back to the glass.
const RECESS_RIM := Color(0.34, 0.4, 0.42)
const RECESS_DEEP := Color(0.05, 0.1, 0.12)
## The source's floor level, and a scale that leaves all three plinths clear of the walls.
const ROUNDEL_SOURCE_FLOOR := -10.495
const ROUNDEL_SCALE := 0.0575
## Walls nearer the camera than this are always behind it, so they are not baked.
const ROUNDEL_FRONT := 4.5
var textures := {}


func _init() -> void:
	if not "--audit" in OS.get_cmdline_user_args():
		bake()
		quit()
		return
	DirAccess.make_dir_recursive_absolute(AUDIT)
	for group in ["core", "platform"]:
		for file in DirAccess.get_files_at(SRC + group):
			if not file.ends_with(".obj"):
				continue
			var id := int(file.get_basename().trim_prefix("model_"))
			var mesh := read_obj(SRC + group + "/" + file)
			var mat := material(group, id)
			mesh.surface_set_material(0, mat)
			ResourceSaver.save(mesh, AUDIT + "%s_%d.res" % [group, id], ResourceSaver.FLAG_COMPRESS)
			print("audit ", group, " ", id, " ", mesh.get_aabb())
	quit()


func bake() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	if "--tongs" in OS.get_cmdline_user_args():
		bake_tongs()
		return
	if "--roundels" in OS.get_cmdline_user_args():
		bake_roundels()
		bake_steel_core()
		return
	save_mesh(Chamber.conduit(), "hatch_conduit")
	if "--conduit" in OS.get_cmdline_user_args():
		return
	save_mesh(Chamber.build(), "hatch_room")
	ResourceSaver.save(Chamber.mist(), OUT + "hatch_mist.res", ResourceSaver.FLAG_COMPRESS)
	if "--room" in OS.get_cmdline_user_args():
		return
	var platform := read_obj(SRC + "platform/model_0.obj")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(145.946, -38.738, 288.512)
	append(st, platform.surface_get_arrays(0), func(p): return (p - center) * 0.016 + Vector3(0, 1.07, 0),
		func(p): return not (p.y > 0 and Vector2(p.x - center.x, p.z - center.z).length() < 55))
	st.index()
	platform = st.commit()
	platform.surface_set_material(0, material("platform", 0))
	save_mesh(platform, "hatch_platform")
	var core := ArrayMesh.new()
	for id in [2, 3, 4]:
		var mesh := read_obj(SRC + "core/model_%d.obj" % id)
		var arrays := reduce(mesh.surface_get_arrays(0), 4000 if id == 2 else 6000)
		core.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		core.surface_set_material(core.get_surface_count() - 1, material("core", id))
	save_mesh(core, "hatch_core")
	bake_tongs()


func bake_roundels() -> void:
	# The source is Z-up with its doorway on -X. This stands it upright and turns the doorway behind the camera.
	var turn := Basis(Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0))
	var place := func(p: Vector3) -> Vector3:
		return turn * p * ROUNDEL_SCALE - Vector3.UP * ROUNDEL_SOURCE_FLOOR * ROUNDEL_SCALE
	var wall := shell_triangles(ROUNDEL_WALLS, place)
	var facets := wall_facets(wall)
	var room := ArrayMesh.new()
	add_shell(room, wall, facets, "roundel_wall")
	add_shell(room, shell_triangles(ROUNDEL_CEILING, place), {}, "roundel_ceiling")
	add_panes(room, world_triangles(reduce(read_obj(SRC + "room/model_%d.obj" % ROUNDEL_WINDOWS).surface_get_arrays(0), 16000), place), facets)
	var stone := StandardMaterial3D.new()
	stone.resource_name = "roundel_floor"
	Chamber.floor_beyond(ROUNDEL_FLOOR_REACH).add_to(room, stone)
	save_mesh(room, "hatch_roundels")


func world_triangles(arrays: Array, place: Callable) -> PackedVector3Array:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var out := PackedVector3Array()
	if arrays[Mesh.ARRAY_INDEX] == null:
		for p in v:
			out.append(place.call(p))
	else:
		for at: int in arrays[Mesh.ARRAY_INDEX]:
			out.append(place.call(v[at]))
	return out


func shell_triangles(parts: Array, place: Callable) -> PackedVector3Array:
	var tris := PackedVector3Array()
	for id in parts:
		tris.append_array(world_triangles(read_obj(SRC + "room/model_%d.obj" % id).surface_get_arrays(0), place))
	return tris


## The Beast Centers' plaster, with its light and shade painted into the vertices. `facets` is empty for the ceiling.
func add_shell(room: ArrayMesh, tris: PackedVector3Array, facets: Dictionary, title: String) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in range(0, tris.size(), 3):
		if (tris[t] + tris[t + 1] + tris[t + 2]).z / 3.0 >= ROUNDEL_FRONT:
			continue
		var n := room_normal(tris[t], tris[t + 1], tris[t + 2])
		var flat := is_wall_face(tris[t], n) and facets.has(facet_key(n))
		for at in winding(tris[t], tris[t + 1], tris[t + 2], n):
			var p := tris[t + at]
			st.set_color(wall_shade(p, n, facets) if flat else recess_shade(p, facets))
			st.set_normal(n)
			st.set_uv(Vector2.ZERO)
			st.add_vertex(p)
	st.index()
	room.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
	var mat := StandardMaterial3D.new()
	mat.resource_name = title
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.albedo_texture = load(OUT + "tex/wall_plaster.png")
	mat.albedo_color = Color("#f1f6f3")
	mat.vertex_color_use_as_albedo = true
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * 0.28
	mat.roughness = 0.9
	room.surface_set_material(room.get_surface_count() - 1, mat)


func room_normal(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var n := (b - a).cross(c - a).normalized()
	return -n if n.dot(Vector3(-a.x, 0.0, -a.z)) < 0.0 else n


## False for the sides of a window's hole, which lie across the wall.
func is_wall_face(p: Vector3, n: Vector3) -> bool:
	return absf(n.y) < 0.5 and absf(n.dot(Vector3(p.x, 0.0, p.z).normalized())) > 0.72


## The three corners in the order that makes the face look along `n`: Godot's front faces are clockwise.
func winding(a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> Array:
	return [0, 2, 1] if (b - a).cross(c - a).dot(n) > 0.0 else [0, 1, 2]


func facet_key(n: Vector3) -> Vector3i:
	return Vector3i((n * 20.0).round())


## Each flat stretch of wall: which way it faces, how far it runs each way, and where its face is along that direction.
func wall_facets(tris: PackedVector3Array) -> Dictionary:
	var facets := {}
	for t in range(0, tris.size(), 3):
		var n := room_normal(tris[t], tris[t + 1], tris[t + 2])
		if not is_wall_face(tris[t], n):
			continue
		var key := facet_key(n)
		if not facets.has(key):
			facets[key] = {"normal": n, "low": INF, "high": -INF, "face": -INF}
		var facet: Dictionary = facets[key]
		var along := n.cross(Vector3.UP).normalized()
		for at in 3:
			facet.low = minf(facet.low, tris[t + at].dot(along))
			facet.high = maxf(facet.high, tris[t + at].dot(along))
			facet.face = maxf(facet.face, tris[t + at].dot(n))
	return facets


## The main stretch of wall that faces most nearly along `direction`.
func facing_facet(direction: Vector3, facets: Dictionary) -> Dictionary:
	var best := {}
	var closest := -INF
	for facet: Dictionary in facets.values():
		if facet.high - facet.low > 2.0 and facet.normal.dot(direction) > closest:
			closest = facet.normal.dot(direction)
			best = facet
	return best


func wall_shade(p: Vector3, n: Vector3, facets: Dictionary) -> Color:
	var facet: Dictionary = facets[facet_key(n)]
	var along := p.dot(n.cross(Vector3.UP).normalized())
	var facing := lerpf(0.5, 1.0, clampf(n.dot(WALL_KEY), 0.0, 1.0))
	var upward := lerpf(1.0, 0.3, smoothstep(0.8, WALL_TOP, p.y))
	var foot := lerpf(0.45, 1.0, smoothstep(0.0, 0.9, p.y))
	var corner := lerpf(0.4, 1.0, smoothstep(0.0, CORNER_REACH, minf(along - facet.low, facet.high - along)))
	var shade := facing * upward * foot * corner
	return Color(shade * 0.95, shade, shade, 1.0)


## Darker the further into the wall it goes, so the holes read as deep.
func recess_shade(p: Vector3, facets: Dictionary) -> Color:
	if facets.is_empty():
		return RECESS_DEEP
	var facet := facing_facet(Vector3(-p.x, 0.0, -p.z).normalized(), facets)
	return RECESS_RIM.lerp(RECESS_DEEP, smoothstep(0.0, PANE_DEPTH, facet.face - p.dot(facet.normal)))


## A disc of bottle-bottom glass at the back of each window, its pattern turned at random. It stops where a window is cut
## off by the floor, the ceiling or a corner.
func add_panes(room: ArrayMesh, tris: PackedVector3Array, facets: Dictionary) -> void:
	var windows := find_windows(tris, facets)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bag := []
	for i in windows.size():
		bag.append(i % (BOTTLE_KINDS * BOTTLE_TINTS.size()))
	for i in range(bag.size() - 1, 0, -1):
		var swap := rng.randi_range(0, i)
		var held: int = bag[i]
		bag[i] = bag[swap]
		bag[swap] = held
	var grid := Vector2(BOTTLE_KINDS, BOTTLE_TINTS.size())
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in windows.size():
		var at: Vector3 = windows[i][0]
		var into: Vector3 = windows[i][1]
		var near: Vector2 = windows[i][2]
		var far: Vector2 = windows[i][3]
		var across := into.cross(Vector3.UP).normalized()
		var spin := rng.randf() * TAU
		var cell := Vector2(bag[i] % BOTTLE_KINDS, bag[i] / BOTTLE_KINDS)
		var flat: Array[Vector2] = [Vector2.ZERO.clamp(near, far)]
		for k in PANE_SIDES:
			flat.append((Vector2.from_angle(TAU * k / PANE_SIDES) * PANE_RADIUS).clamp(near, far))
		var corners: Array[Vector3] = []
		var uvs: Array[Vector2] = []
		for c in flat:
			corners.append(at + across * c.x + Vector3.UP * c.y)
			uvs.append((cell + Vector2(0.5, 0.5) + c.rotated(spin) / (PANE_RADIUS * 2.0)) / grid)
		for k in PANE_SIDES:
			var tri := [0, k + 1, (k + 1) % PANE_SIDES + 1]
			for m in winding(corners[tri[0]], corners[tri[1]], corners[tri[2]], into):
				st.set_normal(into)
				st.set_uv(uvs[tri[m]])
				st.add_vertex(corners[tri[m]])
	st.index()
	room.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
	var mat := StandardMaterial3D.new()
	mat.resource_name = "roundel_panel"
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.albedo_texture = bottle_glass()
	mat.albedo_color = Color(0.5, 0.5, 0.5)
	mat.roughness = 0.35
	mat.emission_enabled = true
	# Godot adds this colour to the emission texture, so anything but black would wash the glass out.
	mat.emission = Color.BLACK
	mat.emission_texture = mat.albedo_texture
	mat.emission_energy_multiplier = PANE_GLOW
	room.surface_set_material(room.get_surface_count() - 1, mat)


## Each separate piece of the source's window part as [the middle of its pane, the direction into the room, and the
## limits of the window measured from that middle].
func find_windows(tris: PackedVector3Array, facets: Dictionary) -> Array:
	var parent := []
	parent.resize(tris.size())
	for i in tris.size():
		parent[i] = i
	var seen := {}
	for i in tris.size():
		if i % 3 != 0:
			parent[window_root(parent, i)] = window_root(parent, i - i % 3)
		var key := Vector3i((tris[i] * 2000.0).round())
		if seen.has(key):
			parent[window_root(parent, i)] = window_root(parent, seen[key])
		else:
			seen[key] = i
	var pieces := {}
	for t in range(0, tris.size(), 3):
		var root := window_root(parent, t)
		if not pieces.has(root):
			pieces[root] = []
		pieces[root].append(t)
	var windows := []
	for faces: Array in pieces.values():
		var window := place_pane(tris, faces, facets)
		if window[0].z < ROUNDEL_FRONT:
			windows.append(window)
	return windows


func window_root(parent: Array, start: int) -> int:
	var at := start
	while parent[at] != at:
		parent[at] = parent[parent[at]]
		at = parent[at]
	return at


func place_pane(tris: PackedVector3Array, faces: Array, facets: Dictionary) -> Array:
	var box := AABB(tris[faces[0]], Vector3.ZERO)
	for t: int in faces:
		box = box.expand(tris[t]).expand(tris[t + 1]).expand(tris[t + 2])
	var mid := box.get_center()
	var inward := Vector3(-mid.x, 0.0, -mid.z).normalized()
	var facing := Vector3.ZERO
	for t: int in faces:
		var face := (tris[t + 1] - tris[t]).cross(tris[t + 2] - tris[t])
		facing += face if face.dot(inward) > 0.0 else -face
	var into := Vector3(facing.x, 0.0, facing.z).normalized()
	var across := into.cross(Vector3.UP).normalized()
	var flat := PackedVector2Array()
	for t: int in faces:
		for k in 3:
			flat.append(Vector2(tris[t + k].dot(across), tris[t + k].y))
	var centre := window_centre(flat)
	var box2 := Rect2(flat[0], Vector2.ZERO)
	for p in flat:
		box2 = box2.expand(p)
	box2 = box2.grow(0.02)
	var face: float = facing_facet(into, facets).face
	return [across * centre.x + Vector3.UP * centre.y + into * (face - PANE_DEPTH), into, box2.position - centre, box2.end - centre]


## The middle of a window, even one cut off by the floor, the ceiling or a corner: a cut window is widest along its cut.
func window_centre(flat: PackedVector2Array) -> Vector2:
	var box := Rect2(flat[0], Vector2.ZERO)
	for p in flat:
		box = box.expand(p)
	var mid := box.get_center()
	var centre := mid
	var widest := flat[0]
	var tallest := flat[0]
	for p in flat:
		if absf(p.x - mid.x) > absf(widest.x - mid.x):
			widest = p
		if absf(p.y - mid.y) > absf(tallest.y - mid.y):
			tallest = p
	if box.size.y < WINDOW_RADIUS * 2.0 - 0.02:
		centre.y = box.end.y - WINDOW_RADIUS if widest.y < mid.y else box.position.y + WINDOW_RADIUS
	if box.size.x < WINDOW_RADIUS * 2.0 - 0.02:
		centre.x = box.end.x - WINDOW_RADIUS if tallest.x < mid.x else box.position.x + WINDOW_RADIUS
	return centre


## A sheet of bottle bottoms: one column for each kind of base and one row for each colour of glass.
func bottle_glass() -> ImageTexture:
	var img := Image.create(BOTTLE_CELL * BOTTLE_KINDS, BOTTLE_CELL * BOTTLE_TINTS.size(), false, Image.FORMAT_RGBA8)
	for row in BOTTLE_TINTS.size():
		for kind in BOTTLE_KINDS:
			for y in BOTTLE_CELL:
				for x in BOTTLE_CELL:
					var p := (Vector2(x, y) + Vector2(0.5, 0.5)) * 2.0 / BOTTLE_CELL - Vector2.ONE
					img.set_pixel(kind * BOTTLE_CELL + x, row * BOTTLE_CELL + y, ramp(bottle_shade(p, kind, row), BOTTLE_TINTS[row]))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func bump(x: float, at: float, width: float) -> float:
	return exp(-pow((x - at) / width, 2.0))


## How bright the glass is at `p`, from the middle of the base out to 1 at its lip.
func bottle_shade(p: Vector2, kind: int, row: int) -> float:
	var a := p.angle()
	# A little wobble, because no two bottles were blown alike.
	var r := p.length() * (1.0 + 0.012 * sin(a * 3.0 + kind + row) + 0.006 * sin(a * 5.0 - row * 2.0))
	var l := 0.0
	match kind:
		0: # A deep punt: the base dishes down to a dark dimple with a bright edge.
			l = lerpf(0.26, 0.6, smoothstep(0.32, 0.82, r)) + 0.55 * bump(r, 0.31, 0.05)
			l = lerpf(0.1, l, smoothstep(0.16, 0.27, r)) + 0.7 * bump(r, 0.0, 0.055)
		1: # Fine concentric rings around a small nipple.
			l = lerpf(0.3, 0.46, r) + 0.45 * pow(0.5 + 0.5 * cos(r * TAU * 8.5), 5.0) * smoothstep(0.04, 0.16, r)
			l += 0.6 * bump(r, 0.0, 0.07)
		2: # A pressed starburst inside a plain band.
			l = 0.32 + 0.55 * pow(absf(cos(a * 9.0)), 4.0) * (1.0 - smoothstep(0.12, 0.64, r))
			l += 0.45 * bump(r, 0.69, 0.035) + 0.55 * bump(r, 0.0, 0.07)
		3: # A ring of raised beads between two thin lines.
			var step := TAU / 18.0
			var bead := Vector2.from_angle(round(a / step) * step) * 0.62
			l = lerpf(0.3, 0.44, smoothstep(0.0, 0.5, r)) + 0.65 * bump(p.distance_to(bead), 0.0, 0.05)
			l += 0.35 * bump(r, 0.42, 0.02) + 0.3 * bump(r, 0.82, 0.02) + 0.5 * bump(r, 0.0, 0.09)
	# Light catching one side of the thick glass, with the other side in shade.
	var side := (p / maxf(r, 0.001)).dot(Vector2(-0.6, -0.8))
	l += 0.34 * pow(maxf(side, 0.0), 2.0) * bump(r, 0.74, 0.12) - 0.14 * maxf(-side, 0.0) * smoothstep(0.3, 0.8, r)
	# The thick lip, and a dark line where it meets the wall.
	l = lerpf(l, 0.88, bump(r, 0.9, 0.045))
	l *= 1.0 - 0.9 * smoothstep(0.955, 0.985, r)
	# Deep glass: most of the disc stays dark, and only its ridges and lip catch the light.
	return pow(clampf(l, 0.0, 1.0), 1.6)


## The TCM Core in white and steel for the merge film, at far less detail: three hang in the frame, and it only sees them
## from a distance.
func bake_steel_core() -> void:
	var core := ArrayMesh.new()
	for id in [2, 3, 4]:
		var arrays := reduce(read_obj(SRC + "core/model_%d.obj" % id).surface_get_arrays(0), 2500 if id == 2 else 1500)
		core.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mat := steel_material()
		if id == 2:
			mat.uv1_triplanar = false
			mat.uv1_scale = Vector3.ONE
			mat.albedo_texture = painted(SRC + "core/Material_10_baseColor.png", WHITE_STEEL_PAINT)
			mat.resource_name = "steel_body"
		core.surface_set_material(core.get_surface_count() - 1, mat)
	save_mesh(core, "hatch_steel_core")
	for i in 3:
		var tong := ArrayMesh.new()
		tong.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, reduce(load(OUT + "hatch_tong_%d.res" % i).surface_get_arrays(0), 1500))
		tong.surface_set_material(0, steel_material())
		save_mesh(tong, "hatch_steel_tong_%d" % i)
	var source: Mesh = load(OUT + "hatch_conduit.res")
	var conduit := ArrayMesh.new()
	for si in source.get_surface_count():
		var wire: bool = source.surface_get_material(si).resource_name == "conduit_wire"
		conduit.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, reduce(source.surface_get_arrays(si), 2500 if wire else 1200))
		conduit.surface_set_material(si, source.surface_get_material(si) if wire else steel_material())
	save_mesh(conduit, "hatch_steel_conduit")


func steel_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.resource_name = "steel"
	if not textures.has("steel"):
		var metal: Image = Chamber.metal().get_image()
		if metal.is_compressed():
			metal.decompress()
		metal.convert(Image.FORMAT_RGBA8)
		textures["steel"] = paint(metal, STEEL_PAINT)
	mat.albedo_texture = textures["steel"]
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * 1.5
	mat.roughness = 0.4
	mat.metallic = 0.15
	return mat


func painted(path: String, stops: Array) -> ImageTexture:
	var key := path + str(stops)
	if not textures.has(key):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		img.convert(Image.FORMAT_RGBA8)
		var ratio := minf(1.0, 512.0 / maxf(img.get_width(), img.get_height()))
		img.resize(maxi(1, roundi(img.get_width() * ratio)), maxi(1, roundi(img.get_height() * ratio)), Image.INTERPOLATE_LANCZOS)
		textures[key] = paint(img, stops)
	return textures[key]


## Keeps an image's light and shade, in new colours.
func paint(img: Image, stops: Array) -> ImageTexture:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var out := ramp(clampf(c.get_luminance() * 1.4, 0.0, 1.0), stops)
			img.set_pixel(x, y, Color(out.r, out.g, out.b, c.a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func bake_tongs() -> void:
	# Split the actual three articulated source arms into their radial sectors, keeping their hinged geometry.
	var arms := read_obj(SRC + "core/model_1.obj")
	var source := arms.surface_get_arrays(0)
	var angles := [deg_to_rad(90), deg_to_rad(-40), deg_to_rad(-135)]
	var manifest := []
	for i in 3:
		var a: float = angles[i]
		var pivot := Vector3(cos(a) * 0.52, -0.85, sin(a) * 0.52)
		var basis := Basis(Vector3.UP, PI * 0.5 - a)
		var arm := SurfaceTool.new()
		arm.begin(Mesh.PRIMITIVE_TRIANGLES)
		append(arm, source, func(p): return basis.inverse() * (p - pivot), func(p):
			var nearest := 0
			var best := -INF
			for k in 3:
				var dot := Vector2(p.x, p.z).dot(Vector2(cos(angles[k]), sin(angles[k])))
				if dot > best:
					best = dot
					nearest = k
			return nearest == i, basis.inverse())
		arm.index()
		var arrays := reduce(arm.commit_to_arrays(), 9000)
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, material("core", 1))
		save_mesh(mesh, "hatch_tong_%d" % i)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var min_y := mesh.get_aabb().position.y
		var tip := Vector3.ZERO
		var count := 0
		for p in v:
			if p.y < min_y + 0.025:
				tip += p
				count += 1
		tip /= maxi(1, count)
		manifest.append({"angle": PI * 0.5 - a, "pivot": [pivot.x, pivot.y, pivot.z], "tip": [tip.x, tip.y, tip.z]})
	var f := FileAccess.open(OUT + "hatch_tongs.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(manifest, "\t"))
	print("HATCHERY BAKE DONE")


func save_mesh(mesh: ArrayMesh, name: String) -> void:
	var err := ResourceSaver.save(mesh, OUT + name + ".res", ResourceSaver.FLAG_COMPRESS)
	var tris := 0
	for i in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(i)
		tris += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null else arrays[Mesh.ARRAY_VERTEX].size()) / 3
	print("baked %s: %d triangles, %d surfaces, %s" % [name, tris, mesh.get_surface_count(), error_string(err)])


func append(st: SurfaceTool, arrays: Array, transform: Callable, keep := Callable(), normal_basis := Basis.IDENTITY) -> void:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if idx.is_empty():
		idx.resize(v.size())
		for i in idx.size():
			idx[i] = i
	for tri in range(0, idx.size(), 3):
		var mid := (v[idx[tri]] + v[idx[tri + 1]] + v[idx[tri + 2]]) / 3.0
		if keep.is_valid() and not keep.call(mid):
			continue
		for j in 3:
			var at := idx[tri + j]
			st.set_normal(normal_basis * n[at])
			if uv.size() > at:
				st.set_uv(uv[at])
			else:
				st.set_uv(Vector2(v[at].x, v[at].y) * 0.03)
			st.add_vertex(transform.call(v[at]))


func reduce(arrays: Array, budget: int) -> Array:
	if arrays[Mesh.ARRAY_INDEX] == null:
		var idx := PackedInt32Array()
		idx.resize(arrays[Mesh.ARRAY_VERTEX].size())
		for i in idx.size():
			idx[i] = i
		arrays[Mesh.ARRAY_INDEX] = idx
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	im.generate_lods(25.0, 60.0, [])
	var picked: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for l in im.get_surface_lod_count(0):
		if picked.size() > 0 and picked.size() / 3 <= budget:
			break
		picked = im.get_surface_lod_indices(0, l)
	var result := im.get_surface_arrays(0)
	result[Mesh.ARRAY_INDEX] = picked
	return result


func material(group: String, part: int) -> StandardMaterial3D:
	var audit := "--audit" in OS.get_cmdline_user_args()
	var mat := StandardMaterial3D.new()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.72
	if group == "core" and part != 2 and not audit:
		# The frame and tongs have no usable UVs; projecting the cast metal avoids the old seams and diamond plate.
		mat.resource_name = "cast_bronze"
		mat.albedo_texture = Chamber.metal()
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3.ONE * 1.5
		mat.roughness = 0.55
		mat.metallic = 0.12
		return mat
	var tex := "Material_10_baseColor.png"
	if group == "platform":
		tex = "Material_Prop_SciFi_Platform_%s.png" % ["One", "Two", "Three", "Three"][mini(part, 3)]
	var path := SRC + group + "/" + tex
	if not textures.has(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		img.convert(Image.FORMAT_RGBA8)
		var ratio := minf(1.0, 512.0 / maxf(img.get_width(), img.get_height()))
		img.resize(maxi(1, roundi(img.get_width() * ratio)), maxi(1, roundi(img.get_height() * ratio)), Image.INTERPOLATE_LANCZOS)
		if not audit:
			repaint(img, group)
		img.generate_mipmaps()
		textures[path] = ImageTexture.create_from_image(img)
	mat.resource_name = tex
	mat.albedo_texture = textures[path]
	if not audit:
		mat.roughness = 0.82 if group == "platform" else 0.6
		mat.metallic = 0.12 if group == "core" else 0.0
	return mat


## Keeps the source atlas's panels and shading but replaces its colours: the core becomes warm bronze; the platform
## becomes pale stone, with its saturated green and violet trim turned to brass.
func repaint(img: Image, group: String) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var l := clampf(c.get_luminance() * 1.4, 0.0, 1.0)
			var out := ramp(l, BRONZE) if group == "core" else ramp(l, STONE).lerp(ramp(l, BRASS), smoothstep(0.22, 0.5, c.s))
			img.set_pixel(x, y, Color(out.r, out.g, out.b, c.a))


func ramp(l: float, stops: Array) -> Color:
	return stops[0].lerp(stops[1], l * 2.0) if l < 0.5 else stops[1].lerp(stops[2], l * 2.0 - 1.0)


func read_obj(path: String) -> ArrayMesh:
	var pos := PackedVector3Array()
	var norms := PackedVector3Array()
	var uv := PackedVector2Array()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var f := FileAccess.open(path, FileAccess.READ)
	while not f.eof_reached():
		var line := f.get_line()
		var p := line.split(" ", false)
		if p.is_empty():
			continue
		if p[0] in ["v", "vn"]:
			var v := Vector3(float(p[1]), float(p[2]), float(p[3]))
			if p[0] == "v":
				pos.append(v)
			else:
				norms.append(v)
		elif p[0] == "vt":
			uv.append(Vector2(float(p[1]), 1.0 - float(p[2])))
		elif p[0] == "f":
			for k in range(2, p.size() - 1):
				for at in [1, k + 1, k]:
					var ids := p[at].split("/")
					if ids.size() > 1 and ids[1] != "":
						st.set_uv(uv[int(ids[1]) - 1])
					if ids.size() > 2 and ids[2] != "":
						st.set_normal(norms[int(ids[2]) - 1])
					st.add_vertex(pos[int(ids[0]) - 1])
	st.index()
	return st.commit()
