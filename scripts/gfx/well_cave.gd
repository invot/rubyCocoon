extends RefCounted
## The Dustwell Well's caves (interior_maps.gd "well_*" rooms, docs/dustwell-water-arc.md), built for room_builder.gd
## _cavern: a floor on each level, the Modular Terrain Collection's cliff pieces (tools/import_modular_cliffs.gd,
## assets/nature/well_*.res) wherever a level drops to the next and round every rock wall, bottomless cracks, leaning
## ladders on the one-tile ramps with the cliff behind them, TheMelon's rope bridges (or what's left), mine-timber door
## frames with hanging lamps, and cut stone along the room's "masonry_cols". The rock wears cliff_rock_wide.png
## (tools/bake_wide_cliff.py: the cliffs' texture, spread wider so big walls don't repeat). Everything stands on
## elevation.gd's heights, so it matches where people walk.

const MapGen = preload("res://scripts/world/map_gen.gd")
const Elev = preload("res://scripts/world/elevation.gd")
const HotelSpa = preload("res://scripts/gfx/hotel_spa.gd")
const TempleLights = preload("res://scripts/gfx/temple_lights.gd")
## a torch on the back wall about every this many tiles, this high over the floor
const TORCH_GAP := 6.0
## how thick the mist over the floors is, of the fields' mist (field_mist.gdshader)
const MIST := 0.175
const TORCH_Y := 1.25
## how far the cut stone's face stands from its tile's middle (the KayKit wall's half thickness)
const STONE_FACE := 0.19
## the KayKit Dungeon Pack 1.1's dirt floors (tools/import_kaykit.gd --well-floors), 4 units to a tile
const DIRT_LARGE := preload("res://assets/interiors/kaykit_floor_dirt_large.res")
const DIRT_ROCKY := preload("res://assets/interiors/kaykit_floor_dirt_large_rocky.res")
const DIRT_SMALL := [preload("res://assets/interiors/kaykit_floor_dirt_small_a.res"),
	preload("res://assets/interiors/kaykit_floor_dirt_small_b.res"), preload("res://assets/interiors/kaykit_floor_dirt_small_c.res"),
	preload("res://assets/interiors/kaykit_floor_dirt_small_d.res")]

## how far below the lowest floor a crack's rock faces reach: they darken as they go, onto a black floor, so its
## bottom is lost in the dark
const ABYSS_DEPTH := 1.6
## the rock walls stand this high above the highest floor beside them
const WALL_H := 2.4
## the rock wall behind the rope ladder up to the town
const SHAFT_H := 4.0
## how far the entrance's rope ladder rises above the top of the rock behind it
const LADDER_OVER := 1.2
## the cliffs' grey (WorldDB.CLIFF_LOOKS "tint" for the outdoor ones) and how deeply they're fluted
const ROCK_TINT := "#9c9a98"
const FLUTES := 1.2
static var _rock_tex: ImageTexture
const WOOD := Color("#8a5c38")
## the rope bridge's pieces (tools/import_rope_bridge.gd): one end's posts, and the deck and ropes 1 long, stretched to
## each span
const BRIDGE_POSTS := preload("res://assets/props/rope_bridge_posts.res")
const BRIDGE_DECK := preload("res://assets/props/rope_bridge_deck.res")
const BRIDGE_ROPES := preload("res://assets/props/rope_bridge_ropes.res")
const ROPE := Color("#c9ab78")

var rb
var map: Dictionary
var w := 0
var h := 0
var floors := preload("res://scripts/gfx/room_builder.gd").Mesher.new()
var rock: StandardMaterial3D
var cave_floor: Material
## the flat dirt floor (_quad, _tri), in the KayKit tile's material
var _flat := SurfaceTool.new()
var wood: StandardMaterial3D
var rope: StandardMaterial3D
var abyss_y := -INF
var _black: StandardMaterial3D
var _painted: StandardMaterial3D
var _masonry := {}
## each rock wall tile's top
var _top := {}
## each column's front-most floor row: rock in front of it is never built (no walls or cliffs at a map's front)
var _front := {}
## the cliff faces gathered by _drop, and the ways the faces meeting at each top corner look (for their mitres)
var _faces := []
var _corner_outs := {}
var cliff_mat: ShaderMaterial
## black quads closing the rock where the room doesn't see it (_rock_side), built with the roof
var _blacks := []
## the ledges' edges, for their rocky lips (_rims): [a, b, out], at the floor's height
var _rim_edges := []
## the dirt floor's pieces, by mesh: the transform of each
var _dirt_tiles := {}
## where torches could hang: the feet of the back walls' faces, looking at the camera
var _spots := []


static func build(builder) -> void:
	var c = load("res://scripts/gfx/well_cave.gd").new()
	c.rb = builder
	c.map = builder.map
	c.w = builder.w
	c.h = builder.h
	c._go()


func _go() -> void:
	rock = StandardMaterial3D.new()
	rock.albedo_texture = rock_texture()
	rock.albedo_color = Color("#959ba2")
	rock.roughness = 1.0
	rock.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	rock.uv1_triplanar = true
	rock.uv1_scale = Vector3.ONE * 0.19
	rock.vertex_color_use_as_albedo = true
	cliff_mat = _cliff_material()
	_painted = StandardMaterial3D.new()
	_painted.vertex_color_use_as_albedo = true
	_painted.roughness = 0.95
	cave_floor = DIRT_LARGE.surface_get_material(0)
	_flat.begin(Mesh.PRIMITIVE_TRIANGLES)
	_bed.begin(Mesh.PRIMITIVE_TRIANGLES)
	wood =StandardMaterial3D.new()
	wood.albedo_color = WOOD
	wood.roughness = 0.9
	rope = StandardMaterial3D.new()
	rope.albedo_color = ROPE
	rope.roughness = 1.0
	_black = StandardMaterial3D.new()
	_black.albedo_color = Color("#0d0a10")
	_black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var room: Dictionary = map.get("room", {})
	if room.get("abyss", false) and Elev.has(map):
		abyss_y = INF
		for y in h:
			for x in w:
				if MapGen.get_t(map, x, y) == MapGen.IVOID:
					abyss_y = minf(abyss_y, Elev.surface(map, Vector2i(x, y)))
	_pit_level()
	if room.has("masonry_cols"):
		var cols: Array = room["masonry_cols"]
		for y in h:
			for x in range(int(cols[0]), int(cols[1]) + 1):
				if _wall(Vector2i(x, y)) and not _exit(Vector2i(x, y)):
					_masonry[Vector2i(x, y)] = true
	for x in w:
		var last := -1
		for y in h:
			if not rb.wallish(x, y):
				last = y
		_front[x] = last
	_wall_tops()
	_floors()
	_cliffs()
	var fm := MeshInstance3D.new()
	fm.mesh = floors.mesh()
	rb.parent.add_child(fm)
	_walls()
	_ladders()
	_bridges()
	_arches()
	_doorways()
	_flush()
	_rims()
	_spa()
	_ravines()
	_torches()
	_clutter()
	_floor_rocks()
	_roof()


## The cliffs' rock texture spread wide (cliff_rock_wide.png), brightened like TempleProps.grey_cliff_texture.
static func rock_texture() -> ImageTexture:
	if _rock_tex == null:
		var img: Image = load("res://assets/textures/surfaces/cliff_rock_wide.png").get_image().duplicate()
		if img.is_compressed():
			img.decompress()
		img.clear_mipmaps()
		img.convert(Image.FORMAT_RGBA8)
		img.adjust_bcs(1.35, 1.0, 0.0)
		img.generate_mipmaps()
		_rock_tex = ImageTexture.create_from_image(img)
	return _rock_tex


# ---------------------------------------------------------------- what a tile is
func _code(p: Vector2i) -> int:
	return MapGen.get_t(map, p.x, p.y)


func _inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < w and p.y < h


func _exit(p: Vector2i) -> bool:
	return map.get("exits", {}).has(p)


## Rock (or cut stone): a wall tile that isn't a doorway.
func _wall(p: Vector2i) -> bool:
	return _inside(p) and rb.wallish(p.x, p.y) and not _exit(p) and not _code(p) in [MapGen.IDIAG_A, MapGen.IDIAG_B]


func _diag_wall(p: Vector2i) -> bool:
	return _inside(p) and _code(p) in [MapGen.IDIAG_A, MapGen.IDIAG_B]


## The crack's floor: PIT_DEPTH under the lowest floor at its rim (pit_rim), not bottomless, so the bridges cross
## a shallow pit with dirt at its foot.
const PIT_DEPTH := 2.0
var pit_y := -INF
var pit_rim := -INF
## The ravines' bed: grey flagstones (the user's 2026-11-23 call: a stone floor under the bridges, walls round them)
const BED_TEX := preload("res://assets/textures/surfaces/stone.png")
const BED_TINT := Color("#8f8d8a")
var _bed := SurfaceTool.new()
var _bed_n := 0
## the bends' bed halves, [tile, corners], for their water
var _ravine_halves := []


func _pit_level() -> void:
	if abyss_y == -INF:
		return
	var rim := INF
	for y in h:
		for x in w:
			var p := Vector2i(x, y)
			if not _abyss(p):
				continue
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var q: Vector2i = p + d
				if _inside(q) and not rb.wallish(q.x, q.y) and _code(q) != MapGen.IVOID:
					rim = minf(rim, Elev.surface(map, q))
	pit_rim = rim if rim < INF else abyss_y + ABYSS_DEPTH
	# (a room can sink its ravine less: Dale's landing, whose stream runs just under its banks)
	pit_y = pit_rim - float(map.get("room", {}).get("pit_depth", PIT_DEPTH))


## A crack's tile: a gap on the room's lowest ("abyss") level, down to the pit's floor.
func _abyss(p: Vector2i) -> bool:
	return _inside(p) and abyss_y > -INF and _code(p) == MapGen.IVOID and not map["bridges"].has(p) \
		and Elev.surface(map, p) <= abyss_y + 0.01


func _bridge(p: Vector2i) -> bool:
	return map.get("bridges", {}).has(p)


func _ramp(p: Vector2i) -> bool:
	return Elev.ramp_dir(map, p) != Vector2i.ZERO


## The floor under a bridge tile: the level beyond its ends' sides (the great chamber's floor 4), or the abyss.
func _under(p: Vector2i) -> float:
	for d in [Vector2i.DOWN, Vector2i.UP]:
		var q: Vector2i = p + d
		if _inside(q) and not _wall(q) and not _bridge(q) and not _abyss(q) and not _diag_wall(q):
			return Elev.surface(map, q)
	return pit_y


## Where the ground at tile q's edge facing back along -d is, for a face dropping to it.
func _low_side(q: Vector2i, d: Vector2i) -> float:
	if _abyss(q):
		return pit_y
	if _bridge(q):
		return _under(q)
	if _ramp(q):
		var r := Elev.ramp_dir(map, q)
		return minf(Elev.edge(map, q, r), Elev.edge(map, q, -r))
	return Elev.edge(map, q, -d)


# ---------------------------------------------------------------- floors and drops
func _floors() -> void:
	for y in h:
		for x in w:
			var p := Vector2i(x, y)
			if _abyss(p):
				# (the ravine's stone bed)
				_bed_quad(p)
				continue
			if _stone(p) or _stone_door(p):
				# the cut stone stands along the middle of its tiles: the floor runs on under it
				_dirt_quarters(p, _foot(p) if _wall(p) else _door_level(p))
				continue
			if _wall(p):
				continue
			if _diag_wall(p):
				_diag_wall_floor(p)
				continue
			if _exit(p):
				continue
			if _bridge(p):
				var under := _under(p)
				if under > pit_y + 0.01:
					_quad(p, under)
				else:
					# (over a ravine: its stone bed runs on under the bridge)
					_bed_quad(p)
				continue
			if _ramp(p):
				var r := Elev.ramp_dir(map, p)
				_quad(p, Elev.edge(map, p, -r))
				continue
			var dg := Elev.diagonal(map, p)
			if dg != 0:
				_diag_ledge(p, dg)
				continue
			_dirt(p, Elev.surface(map, p))
	var flat := MeshInstance3D.new()
	flat.mesh = _flat.commit()
	flat.material_override = cave_floor
	rb.parent.add_child(flat)
	if _bed_n > 0:
		var bed := MeshInstance3D.new()
		_bed.generate_normals()
		bed.mesh = _bed.commit()
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = BED_TEX
		mat.albedo_color = BED_TINT
		mat.roughness = 0.9
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		bed.material_override = mat
		bed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rb.parent.add_child(bed)
	for mesh: Mesh in _dirt_tiles:
		var xfs: Array = _dirt_tiles[mesh]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rb.parent.add_child(mmi)


## A tile of the KayKit pack's dirt floor at height y: mostly a whole tile of it (some of it pebbly), now and then four
## small pieces, each turned at random so the pattern doesn't line up.
func _dirt(p: Vector2i, y: float) -> void:
	if _edge_tile(p, y):
		# (at an edge, flat: the KayKit tile's sides would show past it)
		_quad(p, y)
		return
	var pick := absi(p.x * 92821 + p.y * 68917) % 20
	var turn := Basis(Vector3.UP, PI * 0.5 * (absi(p.x * 7 + p.y * 13) % 4))
	var c := Vector3(p.x + 0.5, y, p.y + 0.5)
	if pick < 2:
		for k in 4:
			var piece: Mesh = DIRT_SMALL[(pick + k + p.x) % DIRT_SMALL.size()]
			var off := Vector3(0.25 if k % 2 else -0.25, 0, 0.25 if k >= 2 else -0.25)
			_dirt_at(piece, Transform3D(Basis(Vector3.UP, PI * 0.5 * ((k + p.y) % 4)).scaled(Vector3.ONE * 0.25), c + off))
		return
	# (the pebbly tile only now and then: the user's 2026-11-22 call)
	var big: Mesh = DIRT_ROCKY if pick == 2 else DIRT_LARGE
	_dirt_at(big, Transform3D(turn.scaled(Vector3.ONE * 0.25), c))


## The dirt under a cut-stone tile: only its quarters on the room's side of the wall, so no floor shows past the wall's
## back or the map's edge.
func _dirt_quarters(p: Vector2i, y: float) -> void:
	for qz in [-1, 1]:
		for qx in [-1, 1]:
			if not (_open_side(p + Vector2i(qx, 0)) or _open_side(p + Vector2i(0, qz)) or _open_side(p + Vector2i(qx, qz))):
				continue
			var cx: float = p.x + 0.5 + qx * 0.25
			var cz: float = p.y + 0.5 + qz * 0.25
			if _edge_tile(p, y):
				_flat_quad(Vector3(cx - 0.25, y, cz - 0.25), Vector3(cx + 0.25, y, cz + 0.25))
				continue
			var piece: Mesh = DIRT_SMALL[absi(p.x * 3 + p.y * 5 + qx + qz * 2) % DIRT_SMALL.size()]
			_dirt_at(piece, Transform3D(Basis(Vector3.UP, PI * 0.5 * (absi(p.x + qx + p.y) % 4)).scaled(Vector3.ONE * 0.25),
				Vector3(p.x + 0.5 + qx * 0.25, y, p.y + 0.5 + qz * 0.25)))


## A floor tile at height y with an edge beside it (the map's end, rock left unbuilt, a crack, a drop, a ladder, a hole
## of a doorway), where the floor must stop flat rather than show a tile's sides.
func _edge_tile(p: Vector2i, y: float) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var q := p + Vector2i(dx, dy)
			if not _inside(q) or _hidden(q) or _abyss(q) or _bridge(q) or _ramp(q) or (_exit(q) and not _stone_door(q)):
				return true
			if _code(q) == MapGen.IVOID:
				return true
			if not rb.wallish(q.x, q.y) and Elev.plane(map, q, 0.5, 0.5) < y - 0.01:
				return true
	return false


## How the KayKit dirt tile's top maps its atlas across the tile: [the uv at its (0, 0) corner, along x, along z]. The
## flat floor (at edges, on the diagonal ledges, under ladders) wears the tile's own material mapped the same way, so
## it meets the dirt tiles without a seam.
static var _dirt_map := []


static func _dirt_uv(local: Vector2) -> Vector2:
	if _dirt_map.is_empty():
		var arrays := DIRT_LARGE.surface_get_arrays(0)
		var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var corners := [Vector2(-2, -2), Vector2(2, -2), Vector2(-2, 2)]
		var found := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
		for k in 3:
			var best := INF
			for i in mini(vs.size(), uvs.size()):
				if ns[i].y < 0.9:
					continue
				var dd := Vector2(vs[i].x, vs[i].z).distance_squared_to(corners[k])
				if dd < best:
					best = dd
					found[k] = uvs[i]
		_dirt_map = [found[0], found[1] - found[0], found[2] - found[0]]
	return _dirt_map[0] + _dirt_map[1] * local.x + _dirt_map[2] * local.y


func _dirt_at(mesh: Mesh, xf: Transform3D) -> void:
	if not _dirt_tiles.has(mesh):
		_dirt_tiles[mesh] = []
	_dirt_tiles[mesh].append(xf)


## A ravine tile's stone bed (stone.png's flagstones, a slab about a tile long), at the pit's floor.
func _bed_quad(p: Vector2i) -> void:
	_bed_tri(p, [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)])
	_bed_tri(p, [Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)])


func _bed_tri(p: Vector2i, corners: Array) -> void:
	var pts := []
	for c: Vector2 in corners:
		pts.append(Vector3(p.x + c.x, pit_y, p.y + c.y))
	var up: bool = ((pts[1] as Vector3) - pts[0]).cross((pts[2] as Vector3) - pts[0]).y > 0.0
	for k in ([0, 2, 1] if up else [0, 1, 2]):
		_bed.set_uv(Vector2(pts[k].x, pts[k].z) * 0.5)
		_bed.add_vertex(pts[k])
	_bed_n += 1


func _quad(p: Vector2i, y: float) -> void:
	_flat_quad(Vector3(p.x, y, p.y), Vector3(p.x + 1, y, p.y + 1))


## A flat rectangle of dirt from corner a to corner b (at a's height).
func _flat_quad(a: Vector3, b: Vector3) -> void:
	var c := [Vector3(a.x, a.y, a.z), Vector3(b.x, a.y, a.z), Vector3(b.x, a.y, b.z), Vector3(a.x, a.y, b.z)]
	var origin := Vector2(floorf(a.x + 0.001), floorf(a.z + 0.001))
	for k in [0, 1, 2, 0, 2, 3]:
		_flat.set_normal(Vector3.UP)
		_flat.set_uv(_dirt_uv(Vector2(c[k].x, c[k].z) - origin))
		_flat.add_vertex(c[k])


## A doorway's floor: level with the room beside it.
func _door_level(p: Vector2i) -> float:
	for d in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
		var q: Vector2i = p + d
		if _inside(q) and not rb.wallish(q.x, q.y) and _code(q) != MapGen.IVOID:
			return Elev.surface(map, q)
	return 0.0


## The corners of a diagonal tile's halves: [first half, second half] as (u, v) across the tile.
const HALF_CORNERS := {
	Elev.DIAG_NW: [[Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)], [Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]],
	Elev.DIAG_SE: [[Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)], [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)]],
	Elev.DIAG_NE: [[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)], [Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]],
	Elev.DIAG_SW: [[Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)], [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)]],
}


## A diagonal ledge: its high half's floor, its low half's (none over a crack), and the rock face between them.
func _diag_ledge(p: Vector2i, dg: int) -> void:
	var i: int = p.x + p.y * w
	var hi: float = map["elev"]["hi"][i]
	var lo: float = map["elev"]["lo"][i]
	var halves: Array = HALF_CORNERS[dg]
	var low_open := abyss_y > -INF and lo <= abyss_y + 0.01
	_tri(p, halves[0], hi)
	if not low_open:
		_tri(p, halves[1], lo)
	var line: Array = [Vector2(1, 0), Vector2(0, 1)] if dg in [Elev.DIAG_NW, Elev.DIAG_SE] else [Vector2(0, 0), Vector2(1, 1)]
	var bottom := pit_y if low_open else lo
	var mid_low: Vector2 = (halves[1][0] + halves[1][1] + halves[1][2]) / 3.0
	var mid_line: Vector2 = (line[0] + line[1]) / 2.0
	var out := Vector3(mid_low.x - mid_line.x, 0, mid_low.y - mid_line.y).normalized()
	var a := Vector3(p.x + line[0].x, 0, p.y + line[0].y)
	var b := Vector3(p.x + line[1].x, 0, p.y + line[1].y)
	_drop(a, b, bottom, hi, out, (b - a).normalized())
	_rim_edges.append([a + Vector3(0, hi, 0), b + Vector3(0, hi, 0), out])


func _tri(p: Vector2i, corners: Array, y: float) -> void:
	var pts := []
	for c: Vector2 in corners:
		pts.append(Vector3(p.x + c.x, y, p.y + c.y))
	# (wound to face up whichever way the corners came)
	var up: bool = ((pts[1] as Vector3) - pts[0]).cross((pts[2] as Vector3) - pts[0]).y > 0.0
	for k in ([0, 2, 1] if up else [0, 1, 2]):
		_flat.set_normal(Vector3.UP)
		_flat.set_uv(_dirt_uv(Vector2(pts[k].x - p.x, pts[k].z - p.y)))
		_flat.add_vertex(pts[k])


## A diagonal rock wall's floor half: the triangle on the room's side of it.
func _diag_wall_floor(p: Vector2i) -> void:
	var half := _diag_open_half(p)
	if half.is_empty():
		return
	var y := Elev.surface(map, p)
	var by_ravine := false
	var found := false
	for d in [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
		var q: Vector2i = p + d
		by_ravine = by_ravine or _abyss(q)
		if _inside(q) and not rb.wallish(q.x, q.y) and not _abyss(q):
			y = Elev.surface(map, q) if not _ramp(q) else y
			found = true
			break
	if by_ravine and not found:
		# (a bend in a ravine: its stone bed, and its water once it runs)
		_bed_tri(p, half)
		_ravine_halves.append([p, half])
		return
	_tri(p, half, y)


## The open (floor) half of a diagonal rock wall, as corners, or [] if neither half is.
func _diag_open_half(p: Vector2i) -> Array:
	var a := _code(p) == MapGen.IDIAG_A
	# "/" splits it into a north-west and a south-east half; "\" into a north-east and a south-west one
	var options: Array = [[[Vector2i.UP, Vector2i.LEFT], [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)]],
		[[Vector2i.DOWN, Vector2i.RIGHT], [Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]]] if a else \
		[[[Vector2i.UP, Vector2i.RIGHT], [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)]],
		[[Vector2i.DOWN, Vector2i.LEFT], [Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]]]
	var best := []
	var best_n := 0
	for o in options:
		var n := 0
		for d: Vector2i in o[0]:
			var q := p + d
			if _inside(q) and not rb.wallish(q.x, q.y):
				n += 1
		if n > best_n:
			best_n = n
			best = o[1]
	return best


## The cliff down from each tile (floor or rock wall) to a lower neighbour: a level below, a crack, the floor under a
## bridge. Rock walls are only their faces towards the room: nothing behind them, on top of them or at the map's front.
func _cliffs() -> void:
	var sides := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	for y in h:
		for x in w:
			var p := Vector2i(x, y)
			if not _solid(p) or _hidden(p) or _stone(p):
				continue
			var fade := _wall(p)
			for d: Vector2i in sides:
				var q: Vector2i = p + d
				if fade:
					_rock_side(p, d)
				# (nor into a doorway: it's a hole flush with the wall's face, _doorways)
				if not _inside(q) or _hidden(q) or _diag_wall(q) or (fade and _wall(q)) or _stone(q) or _exit(q):
					continue
				var top := _edge_top(p, d)
				if _closed_crack(q):
					# (inside the crack running back into the rock: kept under its roof, so nothing pokes out over the back)
					top -= SUNK
				var low := _low_at(q, d)
				if _open_front(q):
					# a crack running out of the map's front: nothing hangs towards the camera, and its sides only
					# go as deep as the floor in front of them hides (but rock where it ends at the back always shows
					# its face, so a black gap never opens there, nor behind its waterfall: _ravine_water)
					if d == Vector2i.DOWN and not fade:
						continue
				if top - low < 0.01:
					continue
				var out := Vector3(d.x, 0, d.y)
				var along := Vector3(absf(d.y), 0, absf(d.x))
				var c := Vector3(x + 0.5, 0, y + 0.5) + out * 0.5
				# beside a doorway or across a ladder's tile the rock stands plain, so nothing juts into the way
				var flat := _ramp(q) and Elev.ramp_dir(map, q) != d and Elev.ramp_dir(map, q) != -d
				_drop(c - along * 0.5, c + along * 0.5, low, top, out, along, fade, flat)
				# (a floor's edge over a drop gets a rocky lip; not at a ladder or a bridge's end)
				if not fade and not _ramp(p) and not _ramp(q) and not _bridge(q) and not _bridge(p) and top - low > 0.3:
					_rim_edges.append([c - along * 0.5 + Vector3(0, top, 0), c + along * 0.5 + Vector3(0, top, 0), out])


## Rock at the map's front: the front row, and in front of the front-most floor in its column and the ones beside it.
## It isn't built, so nothing stands between the camera and the room.
func _hidden(p: Vector2i) -> bool:
	if not _inside(p) or not rb.wallish(p.x, p.y) or _exit(p):
		return false
	if p.y >= h - 1:
		return true
	var front := -1
	for x in [p.x - 1, p.x, p.x + 1]:
		front = maxi(front, _front.get(x, -1))
	return p.y > front


## True when nothing but a crack or unbuilt rock lies from q to the map's front: no cliff hangs towards the camera there.
func _open_front(q: Vector2i) -> bool:
	for y in range(q.y, h):
		var t := Vector2i(q.x, y)
		if not (_abyss(t) or _hidden(t) or _bridge(t) or _wall(t) or _diag_wall(t) or _code(t) == MapGen.IVOID):
			return false
	return true


## Closes rock tile p's side towards d where no cliff faces the room, so its inside never shows: black where the map
## ends (its sides, or rock left unbuilt at the front) and where it stands above the rock next to it; rock where it
## meets cut stone (whose face stands back along its tiles' middle).
func _rock_side(p: Vector2i, d: Vector2i) -> void:
	var q := p + d
	var top: float = _top.get(p, WALL_H)
	var out := Vector3(d.x, 0, d.y)
	var along := Vector3(absf(d.y), 0, absf(d.x))
	var e := Vector3(p.x + 0.5, 0, p.y + 0.5) + out * 0.5
	var a := e - along * 0.5
	var b := e + along * 0.5
	if not _inside(q) or _hidden(q):
		_black_quad(a, b, _foot(p) - 0.3, top)
	elif _stone(q) or _stone_diag(q) or _stone_door(q):
		_drop(a, b, _foot(p), top, out, along, true, true)
	elif (_wall(q) or _diag_wall(q)) and top > float(_top.get(q, top)) + 0.01:
		_black_quad(a, b, _top[q], top)


func _black_quad(a: Vector3, b: Vector3, low: float, top: float) -> void:
	_blacks.append([Vector3(a.x, low, a.z), Vector3(b.x, low, b.z), Vector3(b.x, top, b.z), Vector3(a.x, top, a.z)])


## Rock, or a floor a cliff can drop from (not a gap, a doorway, a ladder or a bridge).
func _solid(p: Vector2i) -> bool:
	if _wall(p):
		return true
	return _inside(p) and not (_abyss(p) or _bridge(p) or _ramp(p) or _diag_wall(p) or _exit(p))


func _edge_top(p: Vector2i, d: Vector2i) -> float:
	return _top[p] if _top.has(p) else Elev.edge(map, p, d)


## Where the ground at tile q is, seen from its neighbour back along -d: a wall's top, or _low_side.
func _low_at(q: Vector2i, d: Vector2i) -> float:
	if _wall(q):
		return _top.get(q, 0.0)
	return _low_side(q, d)


## A cliff face from `low` up to `top` along a..b, looking `out`: gathered now and built in _flush, the way the
## outdoor cliffs are (terrain_mesh.gd _face: fluted columns in rows, darker towards the foot), once every face's ends
## are known so neighbouring faces lean together at their corners. `fade`: rising round a wall, so it can fade when it
## hides the hero; `flat`: plain rock with no flutes.
func _drop(a: Vector3, b: Vector3, low: float, top: float, out: Vector3, along: Vector3, fade := false, flat := false) -> void:
	var ta := Vector3(a.x, top, a.z)
	var tb := Vector3(b.x, top, b.z)
	if fade and out == Vector3.BACK and top - low >= 1.8 and low > pit_y + 0.01:
		_spots.append(Vector3((a.x + b.x) * 0.5, low, a.z))
	_faces.append({"top": [ta, ta.lerp(tb, 0.5), tb], "foot": [low, low, low], "out": out, "flat": flat, "turf": false,
		"fade": fade, "at": Vector2i(floori((a.x + b.x) * 0.5 - out.x * 0.25), floori((a.z + b.z) * 0.5 - out.z * 0.25))})
	for pt: Vector3 in [ta, tb]:
		var k := _corner_key(pt)
		_corner_outs[k] = _corner_outs.get(k, Vector3.ZERO) + out


func _corner_key(pt: Vector3) -> Vector3i:
	return Vector3i(roundi(pt.x * 8.0), roundi(pt.y * 8.0), roundi(pt.z * 8.0))


## Builds the gathered faces, one mesh per 3x2 tiles (the ones rising round walls can fade when they hide the hero).
func _flush() -> void:
	var terrain = preload("res://scripts/world/terrain_mesh.gd").new()
	terrain.flutes = FLUTES
	terrain.seed = int(map.get("room_key", "well").hash()) & 0xffff
	var batches := {}
	for f: Dictionary in _faces:
		var ends := []
		for pt: Vector3 in [f["top"][0], f["top"][2]]:
			var sum: Vector3 = _corner_outs.get(_corner_key(pt), f["out"])
			ends.append(sum.normalized() if sum.length() > 0.01 else f["out"])
		f["ends"] = ends
		var key := Vector3i(f["at"].x / 3, f["at"].y / 2, 1 if f["fade"] else 0)
		if not batches.has(key):
			batches[key] = [PackedVector3Array(), PackedVector3Array(), PackedColorArray(), PackedVector2Array(), PackedInt32Array()]
		var b: Array = batches[key]
		terrain._face(b[0], b[1], b[2], b[3], b[4], f)
	for key: Vector3i in batches:
		var b: Array = batches[key]
		if b[4].is_empty():
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = b[0]
		arr[Mesh.ARRAY_NORMAL] = b[1]
		arr[Mesh.ARRAY_COLOR] = _darkened(b[0], b[2])
		arr[Mesh.ARRAY_TEX_UV] = b[3]
		arr[Mesh.ARRAY_INDEX] = b[4]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(0, cliff_mat)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		rb.parent.add_child(mi)
	_faces.clear()


## Into a crack, the rock goes on darkening below its rim (the shader darkens it by COLOR.r, down the face).
func _darkened(vs: PackedVector3Array, cs: PackedColorArray) -> PackedColorArray:
	if abyss_y == -INF:
		return cs
	var out := cs.duplicate()
	for i in vs.size():
		if vs[i].y < pit_rim:
			var c := out[i]
			# (only gently now the ravines are lit, so their walls show down to the stone bed)
			c.r = maxf(c.r, lerpf(0.6, 0.4, clampf((vs[i].y - pit_y) / PIT_DEPTH, 0.0, 1.0)))
			out[i] = c
	return out


## The outdoor cliffs' material (terrain.gdshader, as terrain_mesh.gd build sets it), in grey, wearing the wide rock.
func _cliff_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/gfx/terrain.gdshader")
	mat.set_shader_parameter("cliff", true)
	mat.set_shader_parameter("cliff_textured", true)
	mat.set_shader_parameter("cliff_tex", load("res://assets/textures/surfaces/cliff_rock_wide.png"))
	mat.set_shader_parameter("cliff_scale", Vector2(0.225, 0.225))
	var cl := Color(ROCK_TINT).srgb_to_linear()
	mat.set_shader_parameter("cliff_tint", Vector3(cl.r, cl.g, cl.b) / 0.71)
	return mat


# ---------------------------------------------------------------- walls
## Each rock wall's top: WALL_H over the highest floor beside it (diagonals too), so the walls step down with the
## levels; rock with no floor beside it takes its neighbours' height. (Rock at the front isn't built: _hidden.)
func _wall_tops() -> void:
	var todo := []
	for y in h:
		for x in w:
			var p := Vector2i(x, y)
			if not (_wall(p) or _diag_wall(p)):
				continue
			var best := -INF
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var q := p + Vector2i(dx, dy)
					if not _inside(q) or _wall(q) or _diag_wall(q) or _abyss(q) or _code(q) == MapGen.IVOID:
						continue
					var s := _door_level(q) if _exit(q) else Elev.surface(map, q)
					best = maxf(best, s)
			if best > -INF:
				_top[p] = best + WALL_H
			else:
				todo.append(p)
	while not todo.is_empty():
		var left := []
		for p: Vector2i in todo:
			var best := -INF
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if _top.has(p + d):
					best = maxf(best, _top[p + d])
			if best > -INF:
				_top[p] = best
			else:
				left.append(p)
		if left.size() == todo.size():
			for p: Vector2i in left:
				_top[p] = WALL_H
			break
		todo = left
	var tall := float(map.get("room", {}).get("tall_back", 0.0))
	if tall > 0.0:
		_raise_back(tall)


## A great chamber's rock rises higher towards its back ("tall_back" metres at most over WALL_H), in broad steps that
## wander along the wall, and steps down along its sides towards the front.
const BACK_STEP := 0.8


func _raise_back(tall: float) -> void:
	var first := h
	var last := 0
	for y in h:
		for x in w:
			if not rb.wallish(x, y) and _code(Vector2i(x, y)) != MapGen.IVOID:
				first = mini(first, y)
				last = maxi(last, y)
	for p: Vector2i in _top.keys():
		if _stone(p) or _stone_diag(p):
			continue
		var t := smoothstep(0.2, 1.0, clampf(float(last - p.y) / maxf(1.0, float(last - first)), 0.0, 1.0))
		_top[p] += snappedf(tall * t * (0.55 + 0.6 * _wander(p.x)), BACK_STEP)


## Smooth value noise along x, 0..1, changing over a few tiles.
static func _wander(x: int) -> float:
	var f := x / 4.5
	var i := floori(f)
	var a := fposmod(sin(i * 12.9898) * 43758.5453, 1.0)
	var b := fposmod(sin((i + 1) * 12.9898) * 43758.5453, 1.0)
	return lerpf(a, b, smoothstep(0.0, 1.0, f - i))


## The top of the well shaft up to the town: SHAFT_H over its floor, and always a little above the rock beside it.
func _shaft_top(p: Vector2i) -> float:
	var t := _door_level(p) + SHAFT_H
	for side in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		t = maxf(t, float(_top.get(p + side, -INF)) + BACK_STEP)
	return t


## How low a wall tile reaches: down to the lowest floor beside it (diagonals too), or into a crack.
func _foot(p: Vector2i) -> float:
	var foot := INF
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var q := p + Vector2i(dx, dy)
			if not _inside(q) or _wall(q):
				continue
			if _abyss(q):
				foot = minf(foot, pit_y)
			elif _bridge(q):
				foot = minf(foot, _under(q))
			elif _ramp(q):
				foot = minf(foot, _low_side(q, Vector2i.ZERO))
			else:
				foot = minf(foot, Elev.plane(map, q, 0.5, 0.5) if Elev.diagonal(map, q) == 0 else map["elev"]["lo"][q.x + q.y * w])
	return foot if foot < INF else 0.0


## The cut stone, and the diagonal walls' cliffs. Rock is only ever its faces towards the room (_cliffs): no tops,
## nothing behind or above the back of the map.
func _walls() -> void:
	for y in h:
		for x in w:
			var p := Vector2i(x, y)
			if _hidden(p):
				continue
			if _stone(p):
				_cut_stone(p)
			elif _stone_diag(p):
				_diag_stone(p)
			elif _diag_wall(p):
				_diag_cliff(p)


## True for a wall tile with the room (not more wall) on one of its four sides.
func _faces_room(p: Vector2i) -> bool:
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var q: Vector2i = p + d
		if _inside(q) and not rb.wallish(q.x, q.y) and not _abyss(q):
			return true
	return false


## A diagonal rock wall: a cliff face along the diagonal, looking into its open half.
func _diag_cliff(p: Vector2i) -> void:
	var open := _diag_open_half(p)
	if open.is_empty():
		return
	var a := _code(p) == MapGen.IDIAG_A
	var line: Array = [Vector2(1, 0), Vector2(0, 1)] if a else [Vector2(0, 0), Vector2(1, 1)]
	var mid_open: Vector2 = (open[0] + open[1] + open[2]) / 3.0
	var mid_line: Vector2 = (line[0] + line[1]) / 2.0
	var out := Vector3(mid_open.x - mid_line.x, 0, mid_open.y - mid_line.y).normalized()
	var l0 := Vector3(p.x + line[0].x, 0, p.y + line[0].y)
	var l1 := Vector3(p.x + line[1].x, 0, p.y + line[1].y)
	_drop(l0, l1, _foot(p), _top.get(p, WALL_H) - (SUNK if _deep(p) else 0.0), out, (l1 - l0).normalized(), true)


## A cut-stone wall tile (the stretches with straight walls and square niches): the KayKit Dungeon Pack's wall piece
## that fits how the wall runs through it, a run, corner, T, crossing or end (RoomBuilder._dungeon_wall), joined to the
## cut stone, doorways and rock walls beside it, standing from the floor up along the tile's middle.
func _cut_stone(p: Vector2i) -> void:
	if _inside(p + Vector2i.DOWN) and not rb.wallish(p.x, p.y + 1) and _code(p + Vector2i.DOWN) != MapGen.IVOID:
		# (torches hang on the cut stone too, on its face towards the room)
		_spots.append(Vector3(p.x + 0.5, _foot(p), p.y + 0.5 + STONE_FACE - 0.16))
	# (a wall running out to the map's front carries on to the floor's front edge rather than stopping short)
	var s := _joins(p + Vector2i.DOWN) or (_hidden(p + Vector2i.DOWN) and _joins(p + Vector2i.UP))
	rb._dungeon_wall(p.x, p.y, _foot(p), _top[p], _joins(p + Vector2i.UP), _joins(p + Vector2i.RIGHT), s,
		_joins(p + Vector2i.LEFT))


## A cut-stone tile that's built: in the masonry's columns, with the room beside it (corners too), not at the front.
func _stone(p: Vector2i) -> bool:
	if not _masonry.has(p) or _hidden(p):
		return false
	# (beside a crack or a bridge it's rock, whose faces know how to drop into the dark)
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if _abyss(p + Vector2i(dx, dy)) or _bridge(p + Vector2i(dx, dy)):
				return false
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var q := p + Vector2i(dx, dy)
			if _inside(q) and not rb.wallish(q.x, q.y) and not _abyss(q):
				return true
	return false


## A doorway through the cut stone (its columns), rather than through rock.
func _stone_door(p: Vector2i) -> bool:
	if not _exit(p) or not map.get("room", {}).has("masonry_cols"):
		return false
	var cols: Array = map["room"]["masonry_cols"]
	return p.x >= int(cols[0]) and p.x <= int(cols[1])


## Whether the cut stone runs on into tile q: more of it, a doorway through it, or the rock wall it meets.
func _joins(q: Vector2i) -> bool:
	return _stone(q) or _stone_door(q) or _stone_diag(q) or (_wall(q) and not _hidden(q) and _faces_room(q))


## A diagonal wall within the cut stone's columns: cut stone too, turned along the diagonal.
func _stone_diag(p: Vector2i) -> bool:
	if not _diag_wall(p) or _hidden(p) or not map.get("room", {}).has("masonry_cols"):
		return false
	var cols: Array = map["room"]["masonry_cols"]
	return p.x >= int(cols[0]) and p.x <= int(cols[1])


## The KayKit wall run turned along a diagonal tile, corner to corner, so the straight stone beside it meets its ends.
func _diag_stone(p: Vector2i) -> void:
	var turn := PI / 4.0 if _code(p) == MapGen.IDIAG_A else -PI / 4.0
	var foot := _foot(p)
	var mi := MeshInstance3D.new()
	mi.mesh = preload("res://assets/interiors/kaykit_dungeon_wall.res")
	mi.transform = Transform3D(Basis(Vector3.UP, turn).scaled_local(Vector3(sqrt(2.0) * 0.25 + 0.04, (_top.get(p, WALL_H) - foot) / 4.0, 0.25)),
		Vector3(p.x + 0.5, foot, p.y + 0.5))
	rb.parent.add_child(mi)


# ---------------------------------------------------------------- ladders, bridges, doorways, the spa, lamps
## A wooden ladder on each one-tile ramp, leaning from the lower floor up to the ledge it climbs.
func _ladders() -> void:
	for y in h:
		for x in w:
			var p := Vector2i(x, y)
			if not _ramp(p):
				continue
			var r := Elev.ramp_dir(map, p)
			var foot := Vector3(x + 0.5, Elev.edge(map, p, -r), y + 0.5) - Vector3(r.x, 0, r.y) * 0.5
			var top := Vector3(x + 0.5, Elev.edge(map, p, r) + 0.28, y + 0.5) + Vector3(r.x, 0, r.y) * 0.5
			var across := Vector3(absf(r.y), 0, absf(r.x))
			if map.get("room", {}).get("stone_stairs", false):
				# (Dale's landing: a stone stairway down to the stream, walked, not climbed)
				_stone_steps(p, Vector2(r), Elev.edge(map, p, -r), Elev.edge(map, p, r), 4)
				continue
			if p in map.get("fallen_ladders", []):
				_broken_ladder_top(foot, top, across)
			else:
				rb.parent.add_child(ladder(foot, top, across, wood))


## A fallen ladder's top: its hooks still caught on the ledge, the rails snapped off a few rungs down with splinters
## jutting from the breaks, so the gap reads as a ladder to mend from above.
func _broken_ladder_top(foot: Vector3, top: Vector3, across: Vector3) -> void:
	var up := top - foot
	var stub_foot := top - up * 0.3
	rb.parent.add_child(ladder(stub_foot, top, across, wood))
	var dir := up.normalized()
	var basis := _along(dir, across)
	for s: float in [-0.3, 0.3]:
		# a splinter skewed off each snapped rail
		var brk := stub_foot + across * s
		var sp := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(0.035, 0.22, 0.035)
		sp.mesh = m
		sp.material_override = wood
		sp.transform = Transform3D(basis.rotated(basis.z.normalized(), 0.45 * signf(s)), brk - dir * 0.09)
		rb.parent.add_child(sp)
	# the hooks over the lip, bright rope lashings so they catch the eye from the ledge
	for s: float in [-0.3, 0.3]:
		_box(top + across * s + Vector3(0, 0.02, 0), Vector3(0.12, 0.1, 0.12), rope)


## A ladder from `foot` to `top`, `across` its width: two rails and rungs every 0.24.
static func ladder(foot: Vector3, top: Vector3, across: Vector3, mat: Material) -> Node3D:
	var node := Node3D.new()
	var up := top - foot
	var length := up.length()
	var basis := _along(up.normalized(), across)
	for s in [-0.3, 0.3]:
		var rail := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(0.07, length, 0.07)
		rail.mesh = m
		rail.material_override = mat
		rail.transform = Transform3D(basis, foot + up * 0.5 + across * s)
		node.add_child(rail)
	var n := int(length / 0.24)
	for i in range(1, n + 1):
		var rung := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(0.6, 0.05, 0.05)
		rung.mesh = m
		rung.material_override = mat
		rung.transform = Transform3D(basis, foot + up * (float(i) / (n + 1)))
		node.add_child(rung)
	return node


## A basis whose y runs along `up` and whose x runs `across`.
static func _along(up: Vector3, across: Vector3) -> Basis:
	var x := across.normalized()
	var z := x.cross(up).normalized()
	return Basis(x, up, z)


## The rope bridges: TheMelon's rope bridge (tools/import_rope_bridge.gd), one half of it stretched over the whole gap
## between posts at each end. Broken as Story.WELL_BRIDGES says: the one that needs wood keeps only its ropes; the
## ones that need rope hang down each side of the gap, half the bridge from each end's posts; Dale's, pulled up from
## the far side, hangs whole down the gap from the posts at his end.
func _bridges() -> void:
	var by_flag := {}
	for p: Vector2i in map.get("bridges", {}):
		by_flag[map["bridges"][p]] = by_flag.get(map["bridges"][p], []) + [p]
	for flag in by_flag:
		var tiles: Array = by_flag[flag]
		tiles.sort()
		var first: Vector2i = tiles[0]
		var last: Vector2i = tiles[-1]
		var y := Elev.surface(map, first)
		var mended := MapGen.walkable(_code(first))
		var west := Vector3(first.x, y, first.y + 0.5)
		var east := Vector3(last.x + 1, y, last.y + 0.5)
		var span := east.x - west.x
		# each end's posts face across the gap
		var face := {west: Basis.IDENTITY, east: Basis(Vector3.UP, PI)}
		for end: Vector3 in face:
			_bridge_piece(BRIDGE_POSTS, Transform3D(face[end], end))
		var need := _bridge_need(flag)
		if mended or need == "well_wood":
			var run := Transform3D(Basis.from_scale(Vector3(span, 1.0, 1.0)), west)
			_bridge_piece(BRIDGE_ROPES, run)
			if mended:
				_bridge_piece(BRIDGE_DECK, run)
		elif need == "well_rope":
			# gnawed through in the middle: each half hangs from its posts down the side of the gap, its ropes slack
			# along the planks, a little off the rock
			var hang := Basis(Vector3.BACK, -1.42) * Basis.from_scale(Vector3(span * 0.5, 0.25, 1.0))
			for end: Vector3 in face:
				var xf := Transform3D(face[end] * hang, end + face[end] * Vector3(0.06, 0, 0))
				_bridge_piece(BRIDGE_ROPES, xf)
				_bridge_piece(BRIDGE_DECK, xf)
		else:
			# pulled up from the far side (Dale's): the whole bridge hangs down the gap from his end's posts
			var far := east
			var dale = map.get("anchors", {}).get("dale", null)
			if dale is Vector2i and absf(dale.x + 0.5 - west.x) < absf(dale.x + 0.5 - east.x):
				far = west
			var drop := Basis(Vector3.BACK, -1.42) * Basis.from_scale(Vector3(span, 0.25, 1.0))
			var xf := Transform3D(face[far] * drop, far + face[far] * Vector3(0.06, 0, 0))
			_bridge_piece(BRIDGE_ROPES, xf)
			_bridge_piece(BRIDGE_DECK, xf)


## What mends a bridge (Story.WELL_BRIDGES): looked up at run time, so the map checks, which run without the
## autoloads, still compile this script.
func _bridge_need(flag: String) -> String:
	var story := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Story")
	if story == null:
		return ""
	var bridges: Dictionary = story.get_script().get_script_constant_map().get("WELL_BRIDGES", {})
	return String(bridges.get(flag, {}).get("item", ""))


## One baked rope bridge piece, in the cave's wood and rope (the posts' second surface is their rope knots).
func _bridge_piece(mesh: ArrayMesh, xf: Transform3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = xf
	if mesh == BRIDGE_ROPES:
		mi.material_override = rope
	else:
		mi.set_surface_override_material(0, wood)
		if mesh.get_surface_count() > 1:
			mi.set_surface_override_material(1, rope)
	rb.parent.add_child(mi)


func _box(at: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = mat
	mi.position = at
	rb.parent.add_child(mi)


## Doorways: dark tunnel mouths in the rock. The way up to the town is a rope ladder up the back wall; a locked door
## (Dibble's, until Nub's key turns in it) is boarded with planks.
func _doorways() -> void:
	for p: Vector2i in map.get("exits", {}):
		var ex: Dictionary = map["exits"][p]
		if ex.get("steps", false):
			_step_door(p)
			continue
		var y := _door_level(p)
		var dark := StandardMaterial3D.new()
		dark.albedo_color = Color("#0b0809")
		dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var back := _away(p)
		var b3 := Vector3(back.x, 0, back.y)
		var along := Vector3(absf(back.y), 0, absf(back.x))
		# the wall's face across the doorway: the rock's edge, or the cut stone's face along its middle
		var e := Vector3(p.x + 0.5, 0, p.y + 0.5) - b3 * (STONE_FACE if _stone_door(p) else 0.5)
		if not String(ex.get("to", "")).contains("#"):
			# the rope ladder up the well shaft to the town, hanging down the rock face, flush with the wall
			var shaft := _shaft_top(p)
			_drop(e - along * 0.5, e + along * 0.5, y, shaft, -b3, along)
			# it runs on up past the top of the rock behind and beside it, so it plainly climbs out of the cave
			var wall_top := shaft
			for d in [Vector2i(back.y, back.x), -Vector2i(back.y, back.x)]:
				wall_top = maxf(wall_top, float(_top.get(p + d, -INF)))
			var foot := Vector3(e.x, y, e.z) - b3 * 0.42
			rb.parent.add_child(ladder(foot, foot + Vector3(0, wall_top - y + LADDER_OVER, 0) + b3 * 0.3, along, rope))
			continue
		# a black hole in the wall's face, flush with it, the wall carried on over it
		_box(Vector3(e.x, y + 1.0, e.z) - b3 * 0.01, Vector3(0.98 if back.y != 0 else 0.02, 2.0, 0.02 if back.y != 0 else 0.98), dark)
		if _stone_door(p):
			if _top.get(p + Vector2i(back.y, back.x), y) > y + 2.0 or _top.get(p - Vector2i(back.y, back.x), y) > y + 2.0:
				var top: float = maxf(_top.get(p + Vector2i(back.y, back.x), y), _top.get(p - Vector2i(back.y, back.x), y))
				rb._dungeon_wall(p.x, p.y, y + 2.0, top, back.x != 0, back.y != 0, back.x != 0, back.y != 0)
			continue
		var over := -INF
		for d in [Vector2i(back.y, back.x), -Vector2i(back.y, back.x)]:
			over = maxf(over, _top.get(p + d, -INF))
		if over > y + 2.0:
			_drop(e - along * 0.5, e + along * 0.5, y + 2.0, over, -b3, along)
		if ex.has("locked_by"):
			var door := Vector3(e.x, y, e.z) - b3 * 0.07
			for i in 4:
				var off := (i - 1.5) * 0.23
				_box(door + Vector3(0, 0.9, 0) + (Vector3(0, 0, off) if back.x != 0 else Vector3(off, 0, 0)),
					Vector3(0.1, 1.8, 0.21) if back.x != 0 else Vector3(0.21, 1.8, 0.1), wood)
			_box(door + Vector3(0, 1.0, 0), Vector3(0.14, 0.1, 0.1) if back.x != 0 else Vector3(0.1, 0.1, 0.14), rope)


## The way out of the room through a doorway tile: its side with no floor.
func _away(p: Vector2i) -> Vector2i:
	for d in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
		var q: Vector2i = p + d
		if not _inside(q) or rb.wallish(q.x, q.y):
			var back: Vector2i = p - d
			if _inside(back) and not rb.wallish(back.x, back.y):
				return d
	return Vector2i.UP


## Cut stone for the stairways (_step_door, _stone_steps): the ravines' flagstones, a shade lighter.
var _steps_mat: StandardMaterial3D


func _step_stone() -> StandardMaterial3D:
	if _steps_mat == null:
		_steps_mat = StandardMaterial3D.new()
		_steps_mat.albedo_texture = BED_TEX
		_steps_mat.albedo_color = Color("#a8a39c")
		_steps_mat.roughness = 0.9
		_steps_mat.uv1_triplanar = true
		_steps_mat.uv1_scale = Vector3.ONE * 0.9
		_steps_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return _steps_mat


## Steps across tile p from `low` (at its edge back along `up`) to `high` (at its edge along `up`): `n` stone blocks,
## each running on to the high end, so their sides close the flight.
func _stone_steps(p: Vector2i, up: Vector2, low: float, high: float, n: int, base := -INF) -> void:
	var c := Vector3(p.x + 0.5, 0, p.y + 0.5)
	var u := Vector3(up.x, 0, up.y)
	var across := Vector3(absf(up.y), 0, absf(up.x))
	var foot := minf(low, base) if base > -INF else low - 0.05
	for j in n:
		var top := low + (high - low) * float(j + 1) / float(n)
		var from := -0.5 + float(j) / float(n)
		var mid := c + u * ((from + 0.5) / 2.0)
		_box(Vector3(mid.x, (top + foot) / 2.0, mid.z), across * 0.98 + u.abs() * (0.5 - from) + Vector3(0, top - foot, 0), _step_stone())


## A stairway down through the floor (the room's "step_doors": the one under Dale's chest): a hole in the floor with
## stone steps going down in it towards the back (so the camera, looking in over the front, sees down them), rock round
## its sides and back, and a faint blue light from the water below, walked down into (world.gd _down_steps).
const STEP_DEPTH := 1.25
func _step_door(p: Vector2i) -> void:
	var y := _door_level(p)
	_stone_steps(p, Vector2(0, 1), y - STEP_DEPTH, y, 5, y - STEP_DEPTH - 0.6)
	# (the cheeks: rock on its sides and at its back, down past the bottom step)
	var low := y - STEP_DEPTH - 0.6
	for side in [[Vector3(p.x - 0.04, 0, p.y + 0.5), Vector3(0.1, 0, 1.0)], [Vector3(p.x + 1.04, 0, p.y + 0.5), Vector3(0.1, 0, 1.0)],
			[Vector3(p.x + 0.5, 0, p.y - 0.04), Vector3(1.18, 0, 0.1)]]:
		var at: Vector3 = side[0]
		var size: Vector3 = side[1]
		_box(Vector3(at.x, (y + low) / 2.0, at.z), size + Vector3(0, y - low, 0), rock)
	# a stout wooden rail along its back and front, as round a house's stairwell, open towards the room (you go in from
	# the east): posts at its corners and one between, a rail across their tops
	for z: float in [p.y + 0.06, p.y + 0.94]:
		for x: float in [p.x + 0.08, p.x + 0.5, p.x + 0.94]:
			_box(Vector3(x, y + 0.4, z), Vector3(0.1, 0.8, 0.1), wood)
		_box(Vector3(p.x + 0.51, y + 0.82, z), Vector3(0.96, 0.08, 0.12), wood)
	# (closed in black along the room's front edge, as under the rest of the floor: nothing hangs below the front)
	_box(Vector3(p.x + 0.5, (y - 0.02 + low) / 2.0, p.y + 1.0 + 0.02), Vector3(1.3, y - 0.02 - low, 0.04), _black)
	var glow := OmniLight3D.new()
	glow.light_color = Color("#8fc8e8")
	glow.light_energy = 0.5
	glow.omni_range = 2.2
	glow.light_volumetric_fog_energy = 0.0
	glow.shadow_enabled = false
	glow.position = Vector3(p.x + 0.5, y - STEP_DEPTH + 0.3, p.y + 0.25)
	rb.parent.add_child(glow)


## Dale's hot spring: the hotel's pink healing pool (its "hot_tub" fixtures, Places.prop) in the rock.
func _spa() -> void:
	var tub := []
	for p: Vector2i in map.get("furniture", {}):
		if map["furniture"][p] == "hot_tub":
			tub.append(p)
	if tub.is_empty():
		return
	var mid := Vector2.ZERO
	for p: Vector2i in tub:
		mid += Vector2(p) + Vector2(0.5, 0.5)
	mid /= tub.size()
	var tile := StandardMaterial3D.new()
	tile.albedo_color = Color("#e6dccd")
	var ivory := StandardMaterial3D.new()
	ivory.albedo_color = Color("#f4ede0")
	HotelSpa.build(rb.parent, Vector3(mid.x, Elev.surface(map, tub[0]), mid.y), tile, ivory)
	for p: Vector2i in map.get("furniture", {}):
		if map["furniture"][p] == "hot_tub_sign":
			HotelSpa.plaque_on(rb.parent, HotelSpa.wall_plaque_at(p, Elev.surface(map, tub[0])), ivory)
	var glow := OmniLight3D.new()
	glow.light_color = Color("#ffc2d8")
	glow.light_energy = 0.6
	glow.omni_range = 4.0
	glow.light_volumetric_fog_energy = 0.0
	glow.position = Vector3(mid.x, Elev.surface(map, tub[0]) + 1.4, mid.y)
	rb.parent.add_child(glow)


## The ravines under the rope bridges: a soft light down in each, so their stone beds and rock walls show, and once Dale
## has taught Water (map "well_flowing", the well restored) a stream running along them out of the rock towards the
## front, fed where a ravine ends at the back wall by a waterfall down it (bridge 4's, in Dale's room).
const WATER_DEPTH := 0.7
const RAVINE_LIGHT := 0.75
const RAVINE_RANGE := 4.0
const FALL_WIDE_MAX := 1.7


func _ravines() -> void:
	if pit_y == -INF:
		return
	var flowing: bool = map.get("well_flowing", false)
	# each ravine: its open tiles (not the stretches roofed over in the rock), joined across its bridges
	var seen := {}
	for y in h:
		for x in w:
			var start := Vector2i(x, y)
			if seen.has(start) or not _abyss(start) or _closed_crack(start):
				continue
			var tiles := []
			var todo := [start]
			seen[start] = true
			while not todo.is_empty():
				var p: Vector2i = todo.pop_back()
				tiles.append(p)
				for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var q: Vector2i = p + d
					if not seen.has(q) and ((_abyss(q) and not _closed_crack(q)) or _bridge(q)):
						seen[q] = true
						todo.append(q)
			var mid := Vector3.ZERO
			var n := 0
			for p: Vector2i in tiles:
				if _abyss(p):
					mid += Vector3(p.x + 0.5, 0, p.y + 0.5)
					n += 1
			if n == 0:
				continue
			mid /= n
			var glow := OmniLight3D.new()
			glow.light_color = Color("#8fc8e8") if flowing else Color("#cfc4b2")
			glow.light_energy = RAVINE_LIGHT * (0.6 if flowing else 1.0)
			glow.omni_range = RAVINE_RANGE
			glow.omni_attenuation = 0.8
			glow.light_volumetric_fog_energy = 0.0
			glow.shadow_enabled = false
			glow.position = Vector3(mid.x, pit_y + (1.9 if flowing else 1.3), mid.z)
			rb.parent.add_child(glow)
	if flowing:
		_ravine_water()


func _ravine_water() -> void:
	var water := ShaderMaterial.new()
	water.shader = preload("res://scripts/gfx/water.gdshader")
	water.set_shader_parameter("frames", preload("res://scripts/gfx/voxel_textures.gd").frames("water"))
	water.set_shader_parameter("frame_count", float(preload("res://scripts/gfx/voxel_textures.gd").WATER_FRAMES))
	water.set_shader_parameter("fps", 6.0)
	water.set_shader_parameter("tint", Color("#1f6f9e"))
	water.set_shader_parameter("shallow_tint", Color("#1d5f7c"))
	water.set_shader_parameter("opacity", 0.9)
	water.set_shader_parameter("glow", 0.0)
	water.set_shader_parameter("froth", 0.12)
	# (running out towards the front: the pattern moves against the drift)
	var drift: Array = map.get("room", {}).get("ravine_drift", [0.0, -0.55])
	water.set_shader_parameter("drift", Vector2(float(drift[0]), float(drift[1])))
	var wy := pit_y + WATER_DEPTH
	var verts := PackedVector3Array()
	var tris := []
	for y in h:
		for x in w:
			var p := Vector2i(x, y)
			if _abyss(p) or (_bridge(p) and _under(p) <= pit_y + 0.01):
				tris.append([p, [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)]])
				tris.append([p, [Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]])
	tris.append_array(_ravine_halves)
	for t: Array in tris:
		var p: Vector2i = t[0]
		var pts := []
		for c: Vector2 in t[1]:
			pts.append(Vector3(p.x + c.x, wy, p.y + c.y))
		var up: bool = ((pts[1] as Vector3) - pts[0]).cross((pts[2] as Vector3) - pts[0]).y > 0.0
		for k in ([0, 2, 1] if up else [0, 1, 2]):
			verts.append(pts[k])
	if verts.is_empty():
		return
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var sheet := MeshInstance3D.new()
	sheet.mesh = am
	sheet.material_override = water
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rb.parent.add_child(sheet)
	# a waterfall down the back wall wherever an open ravine ends against it (not one running on into the rock)
	var runs := {}
	for x in w:
		for y in range(1, h):
			var p := Vector2i(x, y)
			if _abyss(p) and not _closed_crack(p) and _wall(p + Vector2i.UP) and not _deep(p + Vector2i.UP):
				runs[y] = runs.get(y, []) + [x]
	for y: int in runs:
		var xs: Array = runs[y]
		xs.sort()
		var x0: int = xs[0]
		var x1: int = xs[-1] + 1
		var top: float = -INF
		for x in range(x0, x1):
			top = maxf(top, float(_top.get(Vector2i(x, y - 1), -INF)))
		if top == -INF:
			continue
		_waterfall(Vector3((x0 + x1) * 0.5, top, y), minf(float(x1 - x0) * 0.85, FALL_WIDE_MAX), wy, water)


## A sheet of water pouring from the top of the rock face at `at` (its foot's middle, z on the face), hugging the wall,
## then curving out into the stream at wy, foam where it lands (tide_water.gd _build_wall_fall's shape).
func _waterfall(at: Vector3, wide: float, wy: float, water: ShaderMaterial) -> void:
	var fall: ShaderMaterial = water.duplicate()
	fall.set_shader_parameter("opacity", 0.92)
	fall.set_shader_parameter("fall_swell", true)
	fall.set_shader_parameter("fall_rim", true)
	fall.set_shader_parameter("drift", Vector2(0.0, -1.2))
	fall.set_shader_parameter("fall_stretch", 4.5)
	fall.set_shader_parameter("froth", 0.3)
	var low := wy - at.y
	var profile: Array[Vector2] = [Vector2(0.12, 0.0), Vector2(0.16, -0.4), Vector2(0.14, -1.5), Vector2(0.16, low + 0.34),
		Vector2(0.28, low + 0.1), Vector2(0.5, low)]
	var half := wide / 2.0
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i in profile.size() - 1:
		var a := profile[i]
		var b := profile[i + 1]
		var n := Vector3(0, b.x - a.x, a.y - b.y).normalized()
		for v: Vector3 in [Vector3(-half, a.y, a.x), Vector3(half, a.y, a.x), Vector3(half, b.y, b.x),
				Vector3(-half, a.y, a.x), Vector3(half, b.y, b.x), Vector3(-half, b.y, b.x)]:
			verts.append(v)
			normals.append(n)
			uvs.append(Vector2(2.0, profile[0].y - v.y))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.material_override = fall
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	rb.parent.add_child(mi)
	var foam := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.5
	disc.bottom_radius = 0.5
	disc.height = 0.02
	disc.radial_segments = 16
	disc.rings = 1
	foam.mesh = disc
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.albedo_color = Color(0.94, 0.98, 1.0, 0.72)
	foam.material_override = fm
	foam.position = Vector3(at.x, wy + 0.03, at.z + 0.55)
	foam.scale = Vector3(wide + 0.3, 1.0, 0.7)
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rb.parent.add_child(foam)


## Wall torches (TempleLights.wall_torch, KayKit's) on the back walls' faces, one about every TORCH_GAP tiles along each
## level, and one thin layer of mist lying over each level's own floor. The caves are dark otherwise (world.gd _build_room).
func _torches() -> void:
	_spots.sort_custom(func(a: Vector3, b: Vector3): return a.x < b.x)
	var placed := []
	for at: Vector3 in _spots:
		var near := false
		for q: Vector3 in placed:
			if absf(q.y - at.y) < 1.0 and Vector2(q.x - at.x, q.z - at.z).length() < TORCH_GAP:
				near = true
				break
		if near:
			continue
		placed.append(at)
		var torch := TempleLights.wall_torch(at + Vector3(0, TORCH_Y, 0.16), Vector3.BACK, true, 1.5, 6.5)
		# the torches are the caves' hero lights: they carve bright pockets in the volumetric mist
		for l in torch.find_children("*", "OmniLight3D", true, false):
			(l as OmniLight3D).light_volumetric_fog_energy = TORCH_FOG
		rb.parent.add_child(torch)
	if not foggy(String(map.get("room_key", ""))):
		return
	var levels := {}
	for y in h:
		for x in w:
			var p := Vector2i(x, y)
			if rb.wallish(x, y) or _code(p) == MapGen.IVOID or _ramp(p):
				continue
			var s := snappedf(Elev.surface(map, p), 0.1)
			if not levels.has(s):
				levels[s] = []
			levels[s].append(p)
	# mist over each level, laid only on that level's own floor tiles and fading out towards their edges, so it never runs
	# into the walls, over a drop or off the map's front: a volumetric FogVolume on Forward+ (dungeon_floor_fog.gdshader),
	# and one layer of the fields' drifting mist (field_mist.gdshader) where FogVolumes don't render (Mobile, Compatibility)
	var volumetric := RenderingServer.get_current_rendering_method() == "forward_plus"
	var noise := FastNoiseLite.new()
	noise.seed = 719
	noise.frequency = 0.025
	noise.fractal_octaves = 3
	var clouds: ImageTexture = null if volumetric else ImageTexture.create_from_image(noise.get_seamless_image(256, 256))
	for s in levels:
		var mine := {}
		for p: Vector2i in levels[s]:
			mine[p] = true
		var cover := Image.create(w, h, false, Image.FORMAT_RGBA8)
		cover.fill(Color.BLACK)
		for p: Vector2i in levels[s]:
			var inner := true
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					if not mine.has(p + Vector2i(dx, dy)):
						inner = false
			if inner:
				cover.set_pixelv(p, Color.WHITE)
		cover.resize(w * 8, h * 8, Image.INTERPOLATE_CUBIC)
		cover.generate_mipmaps()
		if volumetric:
			_fog_volume(float(s), levels[s], ImageTexture.create_from_image(cover))
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for p: Vector2i in levels[s]:
			var y := float(s) + 0.15
			var c := [Vector3(p.x, y, p.y), Vector3(p.x + 1, y, p.y), Vector3(p.x + 1, y, p.y + 1), Vector3(p.x, y, p.y + 1)]
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_uv(Vector2(c[k].x / w, c[k].z / h))
				st.add_vertex(c[k])
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://scripts/gfx/field_mist.gdshader")
		mat.set_shader_parameter("coverage", ImageTexture.create_from_image(cover))
		mat.set_shader_parameter("clouds", clouds)
		mat.set_shader_parameter("layer", 0.0)
		mat.set_shader_parameter("fringe_floor", 0.0)
		mat.set_shader_parameter("opacity", MIST * (1.8 if RenderingServer.get_current_rendering_method() == "gl_compatibility" else 1.0))
		var mist := MeshInstance3D.new()
		mist.mesh = st.commit()
		mist.material_override = mat
		mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rb.parent.add_child(mist)


## The rooms around Dale the wizard (his workroom, where you meet him, and his bedroom) have clear air: no mist.
const CLEAR_ROOMS := ["well_dale", "well_bedroom"]
## the caves' mist: its volumetric FogVolumes' slate tint, how thick it lies at the floor, and how high it rises
const FOG_TINT := Color("#4a5866")
const FOG_DENSITY := 1.4
const FOG_HEIGHT := 2.0
## how much of the cave's ambient light the mist takes in, and the faint glow of its own
const FOG_AMBIENT := 1.5
const FOG_GLOW := Color("#55626e")
## the torches' share of the volumetric mist's light (their halos)
const TORCH_FOG := 4.0
static var _fog_noise: NoiseTexture3D


## Whether a well room has mist.
static func foggy(key: String) -> bool:
	return key.begins_with("well_") and not key in CLEAR_ROOMS


## The well's caves' Environment fog (world.gd _build_room): on Forward+, a thin volumetric haze packed into the caves'
## short sightlines, scattering forwards around the torches; the floor mist itself is _fog_volume's. None in CLEAR_ROOMS.
static func environment_fog(env: Environment, key: String) -> void:
	if not foggy(key) or RenderingServer.get_current_rendering_method() != "forward_plus":
		return
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.008
	env.volumetric_fog_length = 40.0
	env.volumetric_fog_anisotropy = 0.7
	env.volumetric_fog_albedo = FOG_TINT
	env.volumetric_fog_emission = Color.BLACK
	# (the caves are so dark that mist lit only by the torches reads as nothing: it takes in the cave's dim ambient too)
	env.volumetric_fog_ambient_inject = FOG_AMBIENT


## One level's floor mist on Forward+: a FogVolume box over the level's floor tiles, at least 1.5 high (thinner boxes
## flicker between the froxels), its density masked by `cover` (the level's tiles over the whole map) and drifting noise.
func _fog_volume(floor_y: float, tiles: Array, cover: Texture2D) -> void:
	var lo := Vector2i(w, h)
	var hi := Vector2i(-1, -1)
	for p: Vector2i in tiles:
		lo = Vector2i(mini(lo.x, p.x), mini(lo.y, p.y))
		hi = Vector2i(maxi(hi.x, p.x), maxi(hi.y, p.y))
	hi += Vector2i.ONE
	var size := Vector2(hi - lo)
	if _fog_noise == null:
		var fn := FastNoiseLite.new()
		fn.seed = 719
		fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		fn.frequency = 0.03
		fn.fractal_octaves = 3
		_fog_noise = NoiseTexture3D.new()
		_fog_noise.width = 64
		_fog_noise.height = 64
		_fog_noise.depth = 64
		_fog_noise.seamless = true
		_fog_noise.noise = fn
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/gfx/dungeon_floor_fog.gdshader")
	mat.set_shader_parameter("fog_color", FOG_TINT)
	mat.set_shader_parameter("emission_color", FOG_GLOW)
	mat.set_shader_parameter("base_density", FOG_DENSITY)
	mat.set_shader_parameter("noise_tex", _fog_noise)
	mat.set_shader_parameter("coverage", cover)
	mat.set_shader_parameter("cover_rect", Vector4(float(lo.x) / w, float(lo.y) / h, size.x / w, size.y / h))
	var fog := FogVolume.new()
	fog.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	fog.size = Vector3(size.x, FOG_HEIGHT, size.y)
	fog.position = Vector3(lo.x + size.x * 0.5, floor_y + FOG_HEIGHT * 0.5, lo.y + size.y * 0.5)
	fog.material = mat
	rb.parent.add_child(fog)


## The KayKit pack's barrels, boxes, kegs and broken tables (tools/import_kaykit.gd WELL_CLUTTER) left about the caves:
## a little heap against the back wall now and then, clear of doorways, ladders, bridges, chests, people and spawns.
const CLUTTER_SCALE := 0.33
const CLUTTER := [
	[["barrel_large", Vector2(-0.18, 0.0), 0.3], ["barrel_small", Vector2(0.24, 0.12), 1.1]],
	[["box_stacked", Vector2(0.0, 0.0), 0.2]],
	[["box_large", Vector2(-0.12, 0.0), 0.15], ["box_small", Vector2(0.3, 0.14), 0.9]],
	[["keg", Vector2(0.0, 0.0), 0.0]],
	[["table_medium_broken", Vector2(0.0, 0.1), 2.6]],
	[["barrel_small_stack", Vector2(0.0, 0.0), 0.0]],
	[["table_long_broken", Vector2(0.0, 0.12), 1.57], ["box_small", Vector2(-0.34, 0.0), 0.4]],
]


func _clutter() -> void:
	if not map.get("room", {}).get("cavern", false):
		return
	var keep := {}
	for p: Vector2i in map.get("exits", {}):
		keep[p] = true
	for p in map.get("spawns", {}).values():
		if p is Vector2i:
			keep[p] = true
	for p in map.get("anchors", {}).values():
		if p is Vector2i:
			keep[p] = true
	for p in map.get("furniture", {}):
		keep[p] = true
	# (never on or beside a treasure chest, a lying item or anyone standing about)
	for list: String in ["chests", "items", "npcs"]:
		for e in map.get(list, []):
			if e is Dictionary and e.get("pos") is Vector2i:
				keep[e["pos"]] = true
	_keep = keep
	var n := 0
	for y in range(1, h):
		for x in w:
			var p := Vector2i(x, y)
			if not _solid(p) or _wall(p) or not _wall(p + Vector2i.UP) or (x * 31 + y * 17) % 7 != 0:
				continue
			var clear := true
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var q := p + Vector2i(dx, dy)
					if keep.has(q) or _ramp(q) or _bridge(q) or _exit(q):
						clear = false
			if not clear:
				continue
			var floor_y := Elev.surface(map, p)
			for item: Array in CLUTTER[(x * 5 + y * 3 + n) % CLUTTER.size()]:
				var mi := MeshInstance3D.new()
				mi.mesh = load("res://assets/props/kaykit_well_%s.res" % item[0])
				var off: Vector2 = item[1]
				mi.transform = Transform3D(Basis(Vector3.UP, float(item[2]) + (x % 3) * 0.2).scaled(Vector3.ONE * CLUTTER_SCALE),
					Vector3(x + 0.5 + off.x, floor_y, y + 0.36 + off.y))
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				rb.parent.add_child(mi)
			_taken[p] = true
			n += 1


## A rocky lip along each ledge's edge, rolling from the floor over the cliff's top so no gap shows between them, in
## lengths that swell and shrink, with now and then a big rock sitting on the edge.
const RIM := [Vector2(-0.13, -0.01), Vector2(-0.05, 0.035), Vector2(0.04, 0.045), Vector2(0.1, 0.0), Vector2(0.13, -0.1),
	Vector2(0.11, -0.22)]
const BOULDERS := ["rock_big", "stone_1", "field_rock"]


func _rims() -> void:
	if _rim_edges.is_empty():
		return
	var mat := rock.duplicate() as StandardMaterial3D
	mat.vertex_color_use_as_albedo = false
	# (the cliffs' grey, not the lighter loose rock)
	mat.albedo_color = Color("#7d8288")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# (faceted, like broken rock)
	st.set_smooth_group(-1)
	var n_edge := 0
	for e: Array in _rim_edges:
		var out: Vector3 = e[2]
		var along := ((e[1] as Vector3) - (e[0] as Vector3)).normalized()
		# (a little past each end, so the lips meet round a corner)
		var a: Vector3 = (e[0] as Vector3) - along * 0.12
		var b: Vector3 = (e[1] as Vector3) + along * 0.12
		var steps := 7
		var top_y: float = (e[0] as Vector3).y
		var cols := []
		for k in steps + 1:
			var at := a.lerp(b, float(k) / steps)
			var swell := 0.8 + 0.5 * _hash01(roundi(at.x * 8.0), roundi(at.z * 8.0))
			var col := []
			for ri in RIM.size():
				var r: Vector2 = RIM[ri]
				# (each point knocked about a little, the ends of a length left alone so the lengths meet)
				var jo := 0.0
				var jy := 0.0
				if ri > 0 and ri < RIM.size() - 1:
					jo = (_hash01(roundi(at.x * 16.0) + ri * 5, roundi(at.z * 16.0)) - 0.5) * 0.08
					jy = (_hash01(roundi(at.z * 16.0) + ri * 3, roundi(at.x * 16.0) + 7) - 0.5) * 0.05
				col.append(at + out * (r.x * (swell if r.x > 0.0 else 1.0) + jo) + Vector3(0, r.y * (swell if r.y > 0.0 else 1.0) + jy, 0))
			cols.append(col)
		for k in steps:
			for r in RIM.size() - 1:
				var q := [cols[k][r], cols[k + 1][r], cols[k + 1][r + 1], cols[k][r + 1]]
				# (wound clockwise seen from above and outside, so it faces up and out)
				var up: bool = ((q[1] as Vector3) - q[0]).cross((q[3] as Vector3) - q[0]).dot(Vector3.UP + out) > 0.0
				for i in ([0, 2, 1, 0, 3, 2] if up else [0, 1, 2, 0, 2, 3]):
					# (dressed as the cliff faces are, for the cliffs' material: COLOR r how far down the rock, b and a the way it
					# looks; UV along the edge and down from its top)
					var v: Vector3 = q[i]
					var down := clampf((top_y - v.y) / 2.0, 0.0, 1.0)
					st.set_color(Color(down, 0.0, out.x * 0.5 + 0.5, out.z * 0.5 + 0.5))
					st.set_uv(Vector2(v.x * absf(along.x) + v.z * absf(along.z), top_y - v.y + 0.02))
					st.add_vertex(q[i])
		# now and then a big rock on the edge, mostly over the drop
		var mid := (a + b) * 0.5
		if _hash01(roundi(mid.x * 4.0) + 3, roundi(mid.z * 4.0) + 11) < 0.16:
			var mi := MeshInstance3D.new()
			mi.mesh = load("res://assets/nature/%s.res" % BOULDERS[n_edge % BOULDERS.size()])
			var size := 0.42 + 0.25 * _hash01(roundi(mid.x * 5.0), roundi(mid.z * 3.0))
			mi.transform = Transform3D(Basis(Vector3.UP, TAU * _hash01(roundi(mid.z * 6.0), roundi(mid.x * 2.0))).scaled(Vector3.ONE * size),
				mid + along * (_hash01(roundi(mid.x * 9.0), 5) - 0.5) * 0.4 + out * 0.12 - Vector3(0, 0.08, 0))
			mi.material_override = mat
			rb.parent.add_child(mi)
			n_edge += 1
	st.generate_normals()
	var rim := MeshInstance3D.new()
	rim.mesh = st.commit()
	rim.material_override = cliff_mat
	rb.parent.add_child(rim)


static func _hash01(x: int, y: int) -> float:
	return fposmod(sin(x * 12.9898 + y * 78.233) * 43758.5453, 1.0)


## Large rocks lying on the floor against the natural rock walls, now and then: never by cut stone, a doorway, a ladder,
## a bridge, a drop, a chest, an item, anyone, or the clutter, and tucked against the wall. Each is solid: its tile goes
## in the map's "scenery_blocks" (world.gd _walkable), so a rock only lies where open floor stands in front of it
## and to both sides, and every way through stays open.
var _keep := {}
var _taken := {}


func _floor_rocks() -> void:
	map["scenery_blocks"] = {}
	if not map.get("room", {}).get("cavern", false):
		return
	var mat := rock.duplicate() as StandardMaterial3D
	mat.vertex_color_use_as_albedo = false
	mat.albedo_color = Color("#7d8288")
	var n := 0
	for y in h:
		for x in w:
			var p := Vector2i(x, y)
			if not _solid(p) or _wall(p) or _hidden(p) or _ramp(p) or Elev.diagonal(map, p) != 0:
				continue
			var floor_y := Elev.surface(map, p)
			if _edge_tile(p, floor_y) or _hash01(x * 3 + 17, y * 5 + 3) > 0.13:
				continue
			# the rock wall it leans on (straight, natural rock), at the same level
			var lean := Vector2i.ZERO
			for d in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
				if _wall(p + d) and not _stone(p + d) and not _masonry.has(p + d):
					lean = d
					break
			if lean == Vector2i.ZERO:
				continue
			var clear := true
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var q := p + Vector2i(dx, dy)
					if _masonry.has(q) or _stone(q) or _stone_door(q) or _stone_diag(q) or _exit(q) or _bridge(q) or _ramp(q):
						clear = false
					elif absi(dx) <= 1 and absi(dy) <= 1 and (_keep.has(q) or _taken.has(q)):
						clear = false
			# (open floor at its level in front of it and to both sides, so it never closes a way through)
			var side := Vector2i(absi(lean.y), absi(lean.x))
			for q: Vector2i in [p - lean, p - lean + side, p - lean - side, p + side, p - side]:
				if not _inside(q) or rb.wallish(q.x, q.y) or not _solid(q) or _ramp(q) or _exit(q) or _keep.has(q) or _taken.has(q) \
					or map["scenery_blocks"].has(q) or absf(Elev.surface(map, q) - floor_y) > 0.01:
					clear = false
			if not clear:
				continue
			map["scenery_blocks"][p] = true
			var mi := MeshInstance3D.new()
			mi.mesh = load("res://assets/nature/%s.res" % BOULDERS[n % BOULDERS.size()])
			var size := 0.85 + 0.3 * _hash01(x + 5, y * 7)
			var at := Vector3(x + 0.5, floor_y - 0.05, y + 0.5) + Vector3(lean.x, 0, lean.y) * (0.5 - size * 0.42)
			mi.transform = Transform3D(Basis(Vector3.UP, TAU * _hash01(y + 2, x * 3)).scaled(Vector3.ONE * size), at)
			mi.material_override = mat
			rb.parent.add_child(mi)
			_taken[p] = true
			n += 1


## A black roof in the backdrop's colour over the rock and cut stone round the room, from the top of their faces back
## ROOF_OUT tiles past the map's back and sides, and black walls closing its left and right ends, so the backs and
## sides of the cliff faces never show.
const ROOF_OUT := 2
const BACKDROP := Color("#0d0a10")


func _roof() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BACKDROP
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var high := -INF
	var low := INF
	for t in _top.values():
		high = maxf(high, t)
	for y in h:
		for x in w:
			if not rb.wallish(x, y) and _code(Vector2i(x, y)) != MapGen.IVOID:
				low = minf(low, Elev.surface(map, Vector2i(x, y)))
	if abyss_y > -INF:
		low = minf(low, pit_y)
	if high == -INF:
		return
	var front := h - 1
	for y in range(-ROOF_OUT, front):
		for x in range(-ROOF_OUT, w + ROOF_OUT):
			var at := Vector2i(clampi(x, 0, w - 1), clampi(y, 0, h - 1))
			var inside := at == Vector2i(x, y)
			if inside and _closed_crack(at):
				var ct := -INF
				for side in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					ct = maxf(ct, _top.get(at + side, -INF))
				if ct > -INF:
					# (down on the sunk rock's tops inside, so the crack is a closed tunnel seen through its mouth)
					ct -= SUNK
					var cc := [Vector3(x, ct + 0.01, y), Vector3(x + 1, ct + 0.01, y), Vector3(x + 1, ct + 0.01, y + 1), Vector3(x, ct + 0.01, y + 1)]
					for k in [0, 1, 2, 0, 2, 3]:
						st.add_vertex(cc[k])
				continue
			if not (_wall(at) or _diag_wall(at) or _exit(at)) or _hidden(at):
				continue
			var t: float = _top.get(at, high)
			if _exit(at):
				# over a doorway: as high as the wall carried over it (the shaft's top over the way up to the town)
				t = -INF
				for side in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					t = maxf(t, _top.get(at + side, -INF))
				if not String(map["exits"][at].get("to", "")).contains("#"):
					t = maxf(t, _shaft_top(at))
				if t == -INF:
					continue
			if inside and _diag_wall(at) and _deep(at):
				t -= SUNK
			if inside and _diag_wall(at) and not _deep(at):
				var open := _diag_open_half(at)
				var a := _code(at) == MapGen.IDIAG_A
				var halves: Array = [[Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)], [Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]] if a 					else [[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)], [Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]]
				var closed: Array = halves[1] if open == halves[0] else halves[0]
				for k in [0, 2, 1]:
					st.add_vertex(Vector3(x + closed[k].x, t + 0.01, y + closed[k].y))
				continue
			# over cut stone, only from its face back (its face stands along the tile's middle)
			var x0 := float(x)
			var x1 := x + 1.0
			var z0 := float(y)
			var z1 := y + 1.0
			if inside and (_stone(at) or _stone_door(at)):
				var inset := 0.5 - STONE_FACE
				x0 += inset if _open_side(at + Vector2i.LEFT) else 0.0
				x1 -= inset if _open_side(at + Vector2i.RIGHT) else 0.0
				z0 += inset if _open_side(at + Vector2i.UP) else 0.0
				z1 -= inset if _open_side(at + Vector2i.DOWN) else 0.0
			var c := [Vector3(x0, t + 0.01, z0), Vector3(x1, t + 0.01, z0), Vector3(x1, t + 0.01, z1), Vector3(x0, t + 0.01, z1)]
			for k in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(c[k])
	for lid: Array in _arch_lids:
		var a: Vector3 = lid[0]
		var b: Vector3 = lid[1]
		var lc := [Vector3(a.x, a.y, a.z), Vector3(b.x, a.y, a.z), Vector3(b.x, a.y, b.z), Vector3(a.x, a.y, b.z)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(lc[k])
	for q: Array in _blacks:
		for k in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(q[k])
	# a black curtain under the floor's front edge, so nothing dropping into a crack shows below the front
	for x in w:
		var fy := -1
		for y in h:
			if not rb.wallish(x, y) and (_code(Vector2i(x, y)) != MapGen.IVOID or _abyss(Vector2i(x, y))):
				fy = y
		if fy < 0:
			continue
		var edge := INF
		for dx in range(0, w):
			for sx in [x - dx, x + dx]:
				var f := Vector2i(sx, fy)
				if _inside(f) and not rb.wallish(f.x, f.y) and not _abyss(f) and not _bridge(f) and _code(f) != MapGen.IVOID:
					edge = minf(edge, Elev.surface(map, f))
			if edge < INF:
				break
		if edge == INF:
			continue
		var z := fy + 1.005
		var cv := [Vector3(x, low - 0.5, z), Vector3(x + 1, low - 0.5, z), Vector3(x + 1, edge - 0.01, z), Vector3(x, edge - 0.01, z)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(cv[k])
	# the black walls at the left and right ends, from below the lowest floor up to the roof
	for side in [-ROOF_OUT, w + ROOF_OUT]:
		var a := Vector3(side, low - 0.5, -ROOF_OUT)
		var b := Vector3(side, low - 0.5, front)
		var c := Vector3(side, high + 0.02, front)
		var d := Vector3(side, high + 0.02, -ROOF_OUT)
		for v in ([a, b, c, a, c, d] if side < 0 else [a, c, b, a, d, c]):
			st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rb.parent.add_child(mi)


## How far the rock inside a crack running back into the rock stays under the roof over it.
const SUNK := 0.45


## Rock with no floor beside it (corners too), only a crack running back into it: its face sunk, roofed whole.
func _deep(p: Vector2i) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var q := p + Vector2i(dx, dy)
			if _inside(q) and not rb.wallish(q.x, q.y) and not _abyss(q) and _code(q) != MapGen.IVOID:
				return false
	return true


## A rocky arch where a crack runs back into the rock behind the room (the room's "arches": [left x, the back edge's z,
## width]): the cave's rock across the crack from the rim's height up to the rock's top, its foot arching up in the
## middle, unevenly. Behind it the black roof at its top runs ARCH_BACK tiles back, so nothing over the crack behind
## the arch shows.
const ARCH_BACK := 5
var _arch_lids := []


func _arches() -> void:
	for arch: Array in map.get("room", {}).get("arches", []):
		var x0 := int(arch[0])
		var z := int(arch[1])
		var wide := int(arch[2])
		var top := -INF
		for k in range(x0 - 1, x0 + wide + 1):
			for dz in [-1, 0]:
				top = maxf(top, _top.get(Vector2i(k, z + dz), -INF))
		if top == -INF or pit_y == -INF:
			continue
		var spring := minf(pit_rim + 0.7, top - 0.8)
		var crown := minf(pit_rim + 1.5, top - 0.4)
		# (in six lengths, its foot rising off-centre and wandering a little, like rock worn away rather than cut)
		var parts := 6
		var feet := []
		for i in parts * 2 + 1:
			var t := float(i) / (parts * 2)
			var lift := pow(maxf(0.0, sin(PI * pow(t, 1.25))), 0.6)
			var wobble := (fposmod(sin((i + x0 * 7 + z * 13) * 12.9898) * 43758.5453, 1.0) - 0.5) * 0.35
			feet.append(spring + (crown - spring) * lift + (wobble if i > 0 and i < parts * 2 else 0.0))
		for i in parts:
			var ta := Vector3(x0 + wide * float(i) / parts, top, z)
			var tb := Vector3(x0 + wide * float(i + 1) / parts, top, z)
			_faces.append({"top": [ta, ta.lerp(tb, 0.5), tb], "foot": [feet[i * 2], feet[i * 2 + 1], feet[i * 2 + 2]],
				"out": Vector3.BACK, "flat": false, "turf": false, "fade": true, "at": Vector2i(x0 + int(wide * float(i) / parts), z)})
			for pt: Vector3 in [ta, tb]:
				var k := _corner_key(pt)
				_corner_outs[k] = _corner_outs.get(k, Vector3.ZERO) + Vector3.BACK
		# (the roof over the crack behind it, a tile wider each side)
		_arch_lids.append([Vector3(x0 - 1, top + 0.02, z - ARCH_BACK), Vector3(x0 + wide + 1, top + 0.02, z - 0.02)])


## A stretch of crack running back into the rock, with no floor beside it (corners too): roofed over like the rock.
func _closed_crack(p: Vector2i) -> bool:
	if not _abyss(p):
		return false
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var q := p + Vector2i(dx, dy)
			if _inside(q) and not rb.wallish(q.x, q.y) and not _abyss(q) and _code(q) != MapGen.IVOID:
				return false
	return true


## Whether tile q, beside a cut-stone tile, is open floor (where the stone's face looks).
func _open_side(q: Vector2i) -> bool:
	return _inside(q) and not rb.wallish(q.x, q.y) and _code(q) != MapGen.IVOID
