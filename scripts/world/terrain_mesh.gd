extends RefCounted
## The overworld ground as a low-poly height field instead of voxel blocks.
##
## Each tile is drawn from its own 3x3 vertices: at its centre, the middles of its edges and its corners (half a tile
## apart). A tile stands on its base (elevation.gd: a level, or a ramp's slope) and has a height of its own above it:
## 0 for ground, below 0 for river beds and lava, above 0 for rocks. An edge or corner takes whichever height of the
## tiles sharing it on the same level is closest to 0. So walkable ground stays flat where people stand, river beds
## slope down from their banks, and rocky tiles rise into faceted crags from the edge of the ground around them.
## A diagonal cliff's tile (elevation.gd "/" and "\") is two halves, each drawn on its own level from its own vertices,
## with the ground (and water) of the tiles along its sides.
## The grass is a pillow laid on the ground: its tiles stand LIFT above their level, and where they meet a path, sand or
## paving on the same level the turf rolls over the edge in a muffin top (TURF) with the soil tucked in under it, in a
## crisp line round the tile (the shader's wandering borders stop there). A convex corner of the grass is chamfered
## off to the middles of its sides, and a path's corner inside the grass filled the same way, so paths bend round the
## grass instead of stepping (_prepare_corners): a path laid as a stair of tiles runs as a straight diagonal.
## Where neighbouring tiles' edges don't meet (a cliff between two levels, the side of a ramp, a diagonal), a cliff face
## fills the gap, after the cosy island cliffs of life-sim games: the ground above rolls over its top in a rounded lip,
## and below it the rock stands in upright, rounded flutes, coloured and textured by the biome's look
## (WorldDB.CLIFF_LOOKS), darker towards its foot. Only grass rolls over a cliff's top: a path or sand at the edge
## meets the rock in a sharp edge. Faces meeting at a corner share their end, mitred, so the lip and the
## rock run on round it unbroken. In a town that wants them, the cliffs are straight stone retaining walls instead.
## Where a river runs over a cliff, it falls down it as a sheet of water, in front of smooth rock.
## The ground carries on MARGIN tiles past the map's edge (copying the edge tiles), so there is no drop-off.

const VT = preload("res://scripts/gfx/voxel_textures.gd")
const Elev = preload("res://scripts/world/elevation.gd")
const MapGen = preload("res://scripts/world/map_gen.gd")
const TerrainShader = preload("res://scripts/gfx/terrain.gdshader")
const WaterShader = preload("res://scripts/gfx/water.gdshader")
const Shoreline = preload("res://scripts/world/shoreline.gd")

const CHUNK := 16
const MARGIN := 16
## sRGB grey the ground textures average out at, in linear terms: dividing it out keeps each biome colour as authored.
const TEX_LEVEL := 0.71
## A cliff face is cut into rows about this tall...
const FACE_ROW := 0.5
## ...and into this many columns per unit along it (a flute is two or three columns across).
const FACE_COLS := 8.0
## How far a cliff's flutes stand out from it at most (times the look's "flutes"), at a whole level's drop.
const FLUTE := 0.13
## A fall sits inside a shallow cut in the cliff; the rock stays just behind its clear sheet.
const FALL_SETBACK := 0.16
const FALL_ROCK_SETBACK := 0.22
const FALL_LIP := 0.04
const CREST_TUCK := 0.08
const FALL_SIDE_INSET := 0.3
## The lip of ground rolling over a cliff's top, at a whole level's drop: its profile, (out, down) from the edge.
const LIP := [Vector2(0.0, 0.0), Vector2(0.065, -0.022), Vector2(0.11, -0.075), Vector2(0.115, -0.135), Vector2(0.08, -0.19)]
## the rock's top, tucked in under the lip, this far below the ground at a whole level's drop
const LIP_DEPTH := 0.22
## The grass stands this much above its level: a pillow on the ground, with paths, sand and paving at the level itself.
const LIFT := 0.1
## The turf's edge over lower ground at its level: its muffin top, (out, down) from the edge; under it the soil tucks in.
## How far it reaches out waves along the edge (TURF_WAVE: the least and most of this profile's reach), so the grass's
## outline is organic rather than ruled.
const TURF := [Vector2(0.0, 0.0), Vector2(0.045, -0.01), Vector2(0.08, -0.03), Vector2(0.095, -0.058), Vector2(0.085, -0.082)]
const TURF_WAVE := Vector2(0.5, 1.9)
## The shadow the turf's edge throws on the ground at its foot: a skirt lying on the ground this far out, dark at the
## foot and fading away (terrain.gdshader).
const TURF_SHADOW := 0.3
## A tile's corners (bits of `corners`), and which way each lies.
const NW := 1
const NE := 2
const SE := 4
const SW := 8
const CORNER_DIRS := {NW: Vector2i(-1, -1), NE: Vector2i(1, -1), SE: Vector2i(1, 1), SW: Vector2i(-1, 1)}
const SIDES := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
## the sides a diagonal tile's halves run along: [its high half's, its low half's]
const HALF_SIDES := {
	Elev.DIAG_NW: [[Vector2i(0, -1), Vector2i(-1, 0)], [Vector2i(0, 1), Vector2i(1, 0)]],
	Elev.DIAG_SE: [[Vector2i(0, 1), Vector2i(1, 0)], [Vector2i(0, -1), Vector2i(-1, 0)]],
	Elev.DIAG_NE: [[Vector2i(0, -1), Vector2i(1, 0)], [Vector2i(0, 1), Vector2i(-1, 0)]],
	Elev.DIAG_SW: [[Vector2i(0, 1), Vector2i(-1, 0)], [Vector2i(0, -1), Vector2i(1, 0)]]}
## a diagonal tile's corners, [its high half's, its low half's], round the tile in the order its water is drawn
const HALF_CORNERS := {
	Elev.DIAG_NW: [[Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)], [Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]],
	Elev.DIAG_SE: [[Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)], [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)]],
	Elev.DIAG_NE: [[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)], [Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]],
	Elev.DIAG_SW: [[Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)], [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)]]}

var w := 0
var h := 0
## per tile: index into VT.GROUND_LAYERS, centre height, and whether the surface is craggy rock
var layer := PackedByteArray()
var height := PackedFloat32Array()
var rough := PackedByteArray()
## per tile: 0 = dry, 1 = water surface, 2 = lava surface
var liquid := PackedByteArray()
## per tile: 1 where the ground stands LIFT above its level (the grass, and a doorstep on a building's grass)
var lifted := PackedByteArray()
## per tile: 1 under a building: its ground is lifted with the lawn it stands on, but holds a firm edge (a plinth
## rather than rolling turf), and no corner of it is cut
var firm := PackedByteArray()
## per tile: its cut (grass) or filled (path) corners, NW | NE | SE | SW, and the layer those corners show
var corners := PackedByteArray()
var corner_layer := PackedByteArray()
## Visual bed depth only. Collision and elevation continue to use the authored tiles.
var water_bed := PackedFloat32Array()
var seed := 0
## the map, for its levels and ramps (elevation.gd); flat without them
var elev_map := {}
## per tile (from elevation.gd): the height of its low edge and its high edge, and its ramp direction (0 = flat) or
## which half of a diagonal is the high one
var base_lo := PackedFloat32Array()
var base_hi := PackedFloat32Array()
var ramp := PackedByteArray()
## each diagonal tile's halves, by tile index: [high, low], each {"level", "top", "liquid", "layer"}
var halves := {}
## the ground's and the cliffs' materials, for the see-through patch (world.gd _update_hole)
var materials: Array[ShaderMaterial] = []
## cliffs drawn as straight dressed-stone walls instead of rock (see build)
var walls := false
## how deeply the cliffs are fluted (the look's "flutes")
var flutes := 1.0
## tile vertices worked out so far while generating (see _grid, _half_grid)
var _grids := {}
var _fall_offsets := {}
var _fall_water_offsets := {}
var _fall_sides := {}
var _fall_ends := {}

## The ground meshes of the last few maps, so that stepping out of a house or back along a road puts the same ground
## down again instead of generating it. Keyed by everything the shape depends on, so a changed map is built afresh.
const REMEMBERED_SHAPES := 3
static var _shapes := {}
static var _shape_order: Array[String] = []


func setup(width: int, depth: int, map_seed: int, m: Dictionary = {}) -> void:
	w = width
	h = depth
	seed = map_seed
	elev_map = m
	if Elev.has(m):
		base_lo = m["elev"]["lo"]
		base_hi = m["elev"]["hi"]
		ramp = m["elev"]["dir"]
	else:
		base_lo.resize(w * h)
		base_hi.resize(w * h)
		ramp.resize(w * h)
	layer.resize(w * h)
	height.resize(w * h)
	rough.resize(w * h)
	liquid.resize(w * h)
	lifted.resize(w * h)
	firm.resize(w * h)
	corners.resize(w * h)
	corner_layer.resize(w * h)


## Tile (x, y)'s ground: its layer (VT.GROUND_LAYERS), its own height above its level, whether it's craggy rock and
## what liquid lies on it; `lift` stands it LIFT above its level (the grass, see LIFT).
func set_tile(x: int, y: int, layer_name: String, top: float, is_rough := false, liquid_kind := 0, lift := false, is_firm := false) -> void:
	var i := x + y * w
	layer[i] = maxi(0, VT.GROUND_LAYERS.find(layer_name))
	height[i] = top
	rough[i] = 1 if is_rough else 0
	liquid[i] = liquid_kind
	lifted[i] = 1 if lift else 0
	firm[i] = 1 if is_firm else 0


## Whether ground layer l is grass (lifted turf with a rolling edge, rather than a doorstep's sharp one).
static func grassy_layer(l: int) -> bool:
	return VT.GROUND_LAYERS[l] in VT.GRASS_LAYERS


func _grassy(i: int) -> bool:
	return grassy_layer(layer[i]) and firm[i] == 0


## How far above its level tile p's ground stands: LIFT on the grass. (The lift the world gives people and props.)
func lift_at(p: Vector2i) -> float:
	return LIFT if lifted[_i(p.x, p.y)] == 1 else 0.0


func _i(x: int, y: int) -> int:
	return clampi(x, 0, w - 1) + clampi(y, 0, h - 1) * w


## Tile (tx, tz)'s diagonal (Elev.DIAG_NW...), or 0; only tiles on the map are cut.
func _diag(tx: int, tz: int) -> int:
	if tx < 0 or tz < 0 or tx >= w or tz >= h:
		return 0
	var code := int(ramp[tx + tz * w])
	return code if code >= Elev.DIAG_NW else 0


## The height of tile i's ground (before its own rise or dip) at (u, v) across it: flat, or a ramp's slope.
func _plane(i: int, u: float, v: float) -> float:
	return Elev._plane_of(base_lo[i], base_hi[i], ramp[i], u, v)


## Height of tile (tx, tz) at grid vertex (gx, gz), in half tiles (gx from 2 * tx to 2 * tx + 2): odd = the tile's
## centre, even = an edge.
func _vertex_y(tx: int, tz: int, gx: int, gz: int) -> float:
	var own := _i(tx, tz)
	var base := _plane(own, (gx - 2 * tx) / 2.0, (gz - 2 * tz) / 2.0)
	if lifted[own] == 0 and layer[own] in [VT.GROUND_LAYERS.find("sand"), VT.GROUND_LAYERS.find("bed")] \
			and is_zero_approx(base_lo[own]) and is_zero_approx(base_hi[own]) \
			and Shoreline.contains(elev_map, gx * 0.5, gz * 0.5):
		return base + Shoreline.bottom(elev_map, gx * 0.5, gz * 0.5)
	# a ramp is one smooth slope
	if ramp[own] != 0:
		return base
	var x0 := (gx - 1) / 2 if gx % 2 != 0 else gx / 2 - 1
	var x1 := x0 if gx % 2 != 0 else gx / 2
	var z0 := (gz - 1) / 2 if gz % 2 != 0 else gz / 2 - 1
	var z1 := z0 if gz % 2 != 0 else gz / 2
	var best := INF
	var craggy := false
	for nx in range(x0, x1 + 1):
		for nz in range(z0, z1 + 1):
			var i := _i(nx, nz)
			# only flat ground on the same level is drawn as one with this tile (and the grass pillow only with other
			# grass: beside lower ground it keeps its height to the edge, and steps down there)
			if ramp[i] != 0 or absf(base_lo[i] - base_lo[own]) > 0.01 or (lifted[own] == 1 and lifted[i] == 0):
				continue
			var v := _top(i)
			if absf(v) < absf(best):
				best = v
			if rough[i] == 1:
				craggy = true
	if craggy and best > 0.05:
		# break up the rock into facets; the noise is fixed per vertex so neighbouring chunks agree
		best += (_hash(gx, gz) - 0.4) * 0.35
	elif best < -0.05:
		best += (_hash(gx, gz) - 0.5) * 0.06
	return base + best + (LIFT if lifted[own] == 1 else 0.0)


## Tile i's own height above its base: its bed, under water.
func _top(i: int) -> float:
	return water_bed[i] if not water_bed.is_empty() and liquid[i] == 1 and height[i] < -0.05 else height[i]


## Tile (tx, tz)'s nine vertices, row by row from its north-west corner (remembered while generating).
func _grid(tx: int, tz: int) -> PackedVector3Array:
	var k := Vector3i(tx, tz, 0)
	if _grids.has(k):
		return _grids[k]
	var g := PackedVector3Array()
	g.resize(9)
	# Flat ground at height 0, nearly all of any map: _vertex_y always answers its own level, whatever its neighbours do.
	var own := _i(tx, tz)
	var level := ramp[own] == 0 and height[own] == 0.0 and not elev_map.has("shoreline")
	for j in 3:
		for i in 3:
			var gx := tx * 2 + i
			var gz := tz * 2 + j
			g[i + j * 3] = Vector3(gx * 0.5, base_lo[own] + (LIFT if lifted[own] == 1 else 0.0) if level else _vertex_y(tx, tz, gx, gz), gz * 0.5)
			g[i + j * 3] += _fall_offsets.get(Vector2i(gx, gz), Vector3.ZERO)
	_grids[k] = g
	return g


## Half `k` of diagonal tile (tx, tz) (0 the high one, 1 the low): nine vertices, as if it were a whole tile on its level
## (only those on its own side of the diagonal are drawn).
func _half_grid(tx: int, tz: int, k: int) -> PackedVector3Array:
	var key := Vector3i(tx, tz, k + 1)
	if _grids.has(key):
		return _grids[key]
	var half: Dictionary = halves[_i(tx, tz)][k]
	var g := PackedVector3Array()
	g.resize(9)
	for j in 3:
		for i in 3:
			var gx := tx * 2 + i
			var gz := tz * 2 + j
			g[i + j * 3] = Vector3(gx * 0.5, _half_vertex_y(tx, tz, gx, gz, half), gz * 0.5)
	_grids[key] = g
	return g


## As _vertex_y, for a vertex of a diagonal tile's half: flat ground on the half's level meets it there.
func _half_vertex_y(tx: int, tz: int, gx: int, gz: int, half: Dictionary) -> float:
	var level: float = half["level"]
	var best: float = half["top"]
	var up: int = half["lifted"]
	var x0 := (gx - 1) / 2 if gx % 2 != 0 else gx / 2 - 1
	var x1 := x0 if gx % 2 != 0 else gx / 2
	var z0 := (gz - 1) / 2 if gz % 2 != 0 else gz / 2 - 1
	var z1 := z0 if gz % 2 != 0 else gz / 2
	for nx in range(x0, x1 + 1):
		for nz in range(z0, z1 + 1):
			var i := _i(nx, nz)
			if (nx == tx and nz == tz) or ramp[i] != 0 or absf(base_lo[i] - level) > 0.01 or (up == 1 and lifted[i] == 0):
				continue
			var v := _top(i)
			if absf(v) < absf(best):
				best = v
	if best < -0.05:
		best += (_hash(gx, gz) - 0.5) * 0.06
	return level + best + (LIFT if up == 1 else 0.0)


## Tile (tx, tz)'s vertices along its side d: its own, or those of the half of a diagonal running along that side.
func _side(tx: int, tz: int, d: Vector2i) -> PackedVector3Array:
	var code := _diag(tx, tz)
	if code == 0:
		return _grid(tx, tz)
	return _half_grid(tx, tz, 0 if Elev.on_high_half(code, 0.5 + d.x * 0.5, 0.5 + d.y * 0.5) else 1)


## Each diagonal's halves: on its two levels, each with the ground of the tiles along its sides where those agree (the
## path below a cut corner, the sea round a headland), else the tile's own.
func _prepare_halves() -> void:
	halves = {}
	for z in h:
		for x in w:
			var code := _diag(x, z)
			if code == 0:
				continue
			var i := x + z * w
			var pair := []
			for k in 2:
				var s: Array = HALF_SIDES[code][k]
				var a := _i(x + s[0].x, z + s[0].y)
				var b := _i(x + s[1].x, z + s[1].y)
				var half := {"level": base_hi[i] if k == 0 else base_lo[i], "layer": layer[i], "liquid": liquid[i],
					"top": _top(i) if liquid[i] != 0 else 0.0, "lifted": 1 if lifted[a] == 1 and lifted[b] == 1 else 0}
				if layer[a] == layer[b]:
					half["layer"] = layer[a]
				if liquid[a] == liquid[b] and liquid[a] != liquid[i]:
					half["liquid"] = liquid[a]
					half["top"] = maxf(_top(a), _top(b)) if liquid[a] != 0 else 0.0
				pair.append(half)
			halves[i] = pair


## Whether tile q is flat ground on tile i's level (no ramp or diagonal, no bed or crag), dry.
func _flat_level(q: Vector2i, i: int) -> bool:
	var j := _i(q.x, q.y)
	return ramp[j] == 0 and height[j] == 0.0 and liquid[j] == 0 and absf(base_lo[j] - base_lo[i]) < 0.01


## The tiles' cut and filled corners. A grass tile's corner between two lower tiles (a path bending round it) is
## chamfered off to the middles of its two sides, at the lower ground's level; a path's corner between three grass
## tiles (bending inside them) is filled with grass the same way. Paths then bend in gentle octagons rather than
## steps, and a diagonal stair of path tiles runs as one straight diagonal. (The halves of a diagonal cliff's tile
## aren't touched, nor laid surfaces: a plaza's corners stay square.)
func _prepare_corners() -> void:
	corners.fill(0)
	var path_layers := [VT.GROUND_LAYERS.find("path"), VT.GROUND_LAYERS.find("sand")]
	for z in h:
		for x in w:
			var i := x + z * w
			corner_layer[i] = layer[i]
			if ramp[i] != 0 or liquid[i] != 0 or height[i] != 0.0:
				continue
			var mask := 0
			for bit: int in CORNER_DIRS:
				var d: Vector2i = CORNER_DIRS[bit]
				var a := Vector2i(x + d.x, z)
				var b := Vector2i(x, z + d.y)
				var c := Vector2i(x + d.x, z + d.y)
				if not _flat_level(a, i) or not _flat_level(b, i):
					continue
				var ia := _i(a.x, a.y)
				var ib := _i(b.x, b.y)
				if lifted[i] == 1:
					if _grassy(i) and lifted[ia] == 0 and lifted[ib] == 0:
						mask |= bit
						corner_layer[i] = layer[ia]
				elif layer[i] in path_layers and _flat_level(c, i):
					var ic := _i(c.x, c.y)
					if lifted[ia] == 1 and lifted[ib] == 1 and lifted[ic] == 1 and _grassy(ia) and _grassy(ib) and _grassy(ic):
						mask |= bit
						corner_layer[i] = layer[ia]
			corners[i] = mask


## The height of tile i's corner triangle where it's cut or filled: the lower ground's level, or the grass's lift.
func _corner_y(i: int) -> float:
	return base_lo[i] + (0.0 if lifted[i] == 1 else LIFT)


## A smooth wave along the ground, 0..1, continuous everywhere (so faces meeting at a corner agree): value noise at
## about a cycle a unit, with a finer ripple.
func _wave(p: Vector3) -> float:
	var v := _vnoise(p.x * 1.1, p.z * 1.1) * 0.7 + _vnoise(p.x * 2.9 + 7.3, p.z * 2.9 + 2.1) * 0.3
	return clampf(v, 0.0, 1.0)


func _vnoise(x: float, y: float) -> float:
	var ix := floori(x)
	var iy := floori(y)
	var fx := x - ix
	var fy := y - iy
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := _hash(ix, iy)
	var b := _hash(ix + 1, iy)
	var c := _hash(ix, iy + 1)
	var d := _hash(ix + 1, iy + 1)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


func _hash(a: int, b: int) -> float:
	var n := (a * 73856093) ^ (b * 19349663) ^ seed
	n = (n ^ (n >> 13)) * 1274126177
	return float((n ^ (n >> 16)) & 0xffff) / 65535.0


## Builds the ground, the cliffs, water and lava under `parent`. tints: one colour per VT.GROUND_LAYERS entry;
## look: the cliffs' (WorldDB.CLIFF_LOOKS); stone_walls: dressed stone (the "paving" layer) instead, straight up.
## slice_us: yield a frame after this long generating (0 = never).
func build(parent: Node3D, tints: Array, water_col: Color, look: Dictionary, stone_walls := false, slice_us := 0) -> void:
	walls = stone_walls
	flutes = float(look.get("flutes", 1.0))
	_lower_dock_beds()
	_prepare_water_bed()
	_prepare_halves()
	_prepare_corners()
	_prepare_fall_offsets()
	var mat := ShaderMaterial.new()
	mat.shader = TerrainShader
	mat.set_shader_parameter("layers", VT.ground_layers())
	# per tile: its ground layer, and for a diagonal its low half's layer and which half is high (terrain.gdshader)
	var kinds := Image.create(w + MARGIN * 2, h + MARGIN * 2, false, Image.FORMAT_RGB8)
	for y in kinds.get_height():
		for x in kinds.get_width():
			var i := _i(x - MARGIN, y - MARGIN)
			var code := _diag(x - MARGIN, y - MARGIN)
			if code != 0:
				kinds.set_pixel(x, y, Color(halves[i][0]["layer"] / 255.0, halves[i][1]["layer"] / 255.0, code / 255.0))
			elif corners[i] != 0 and x >= MARGIN and y >= MARGIN and x < w + MARGIN and y < h + MARGIN:
				kinds.set_pixel(x, y, Color(layer[i] / 255.0, corner_layer[i] / 255.0, (16 + corners[i]) / 255.0))
			else:
				kinds.set_pixel(x, y, Color(layer[i] / 255.0, layer[i] / 255.0, 0))
	mat.set_shader_parameter("kind_map", ImageTexture.create_from_image(kinds))
	mat.set_shader_parameter("map_origin", Vector2(-MARGIN, -MARGIN))
	mat.set_shader_parameter("map_size", Vector2(kinds.get_width(), kinds.get_height()))
	# plain vectors, already linear: a colour array would be converted from sRGB a second time
	var lin := PackedVector3Array()
	for c in tints:
		var l: Color = (c as Color).srgb_to_linear()
		lin.append(Vector3(l.r, l.g, l.b) / TEX_LEVEL)
	mat.set_shader_parameter("tints", lin)
	var soil := Color(look.get("soil", "#6a4a30")).srgb_to_linear()
	mat.set_shader_parameter("turf_soil", Vector3(soil.r, soil.g, soil.b))
	var cliff_mat: ShaderMaterial = mat.duplicate()
	cliff_mat.set_shader_parameter("cliff", true)
	cliff_mat.set_shader_parameter("rock_layer", VT.GROUND_LAYERS.find("paving" if walls else "rock"))
	var cl := Color(look.get("tint", "#a08a70")).srgb_to_linear()
	cliff_mat.set_shader_parameter("cliff_tint", Vector3(cl.r, cl.g, cl.b) / TEX_LEVEL)
	if not walls:
		cliff_mat.set_shader_parameter("cliff_tex", VT.texture("cliff_" + String(look.get("tex", "rock"))))
		cliff_mat.set_shader_parameter("cliff_textured", true)
		cliff_mat.set_shader_parameter("cliff_scale", Vector2(look.get("scale", [0.5, 0.5])[0], look.get("scale", [0.5, 0.5])[1]))
		for key in ["band", "moss"]:
			if look.has(key):
				var bc := Color(look[key][0]).srgb_to_linear()
				cliff_mat.set_shader_parameter("cliff_" + key, Vector4(bc.r, bc.g, bc.b, float(look[key][1])))
	materials = [mat, cliff_mat]
	var shape: Dictionary = await _shape(parent, slice_us)
	for chunk: Array in shape["chunks"]:
		_place(parent, chunk[0], mat)
		if chunk[1] != null:
			_place(parent, chunk[1], cliff_mat)
	_liquid(parent, shape["water"], 1, water_col)
	_liquid(parent, shape["lava"], 2, Color("#ff6a20"))


## This map's ground meshes: remembered from a recent visit if the ground hasn't changed since, else generated.
func _shape(parent: Node3D, slice_us: int) -> Dictionary:
	var key := str([w, h, seed, walls, flutes, hash(layer), hash(height), hash(rough), hash(liquid), hash(lifted), hash(firm), hash(base_lo),
		hash(base_hi), hash(ramp), hash(elev_map.get("shoreline", []))])
	if _shapes.has(key):
		_shape_order.erase(key)
		_shape_order.append(key)
		return _shapes[key]
	_grids = {}
	var x0 := -MARGIN
	var z0 := -MARGIN
	var x1 := w + MARGIN
	var z1 := h + MARGIN
	var slice := [Time.get_ticks_usec()]
	var faces: Dictionary = await _faces(parent, slice_us, slice)
	var chunks := []
	var cz := z0
	while cz < z1:
		var cx := x0
		while cx < x1:
			chunks.append(_chunk(cx, cz, mini(cx + CHUNK, x1), mini(cz + CHUNK, z1), faces.get(Vector2i(cx, cz), [])))
			if slice_us > 0 and Time.get_ticks_usec() - slice[0] >= slice_us:
				await parent.get_tree().process_frame
				slice[0] = Time.get_ticks_usec()
			cx += CHUNK
		cz += CHUNK
	_grids = {}
	var shape := {"chunks": chunks, "water": _liquid_mesh(1), "lava": _liquid_mesh(2)}
	_shapes[key] = shape
	_shape_order.append(key)
	while _shape_order.size() > REMEMBERED_SHAPES:
		_shapes.erase(_shape_order.pop_front())
	return shape


## A raised walking deck is not a raised body of water. Continue the neighbouring water under dock/bridge tiles.
## Copy the elevation arrays before editing: the map's movement heights and the planks keep their authored level.
func _lower_dock_beds() -> void:
	if not elev_map.has("grid"):
		return
	base_lo = base_lo.duplicate()
	base_hi = base_hi.duplicate()
	ramp = ramp.duplicate()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var queue := PackedInt32Array()
	for z in h:
		for x in w:
			var i := x + z * w
			if liquid[i] == 1 and not _over_water_deck(Vector2i(x, z)):
				seen[i] = 1
				queue.append(i)
	var cursor := 0
	while cursor < queue.size():
		var i := queue[cursor]
		cursor += 1
		var p := Vector2i(i % w, i / w)
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var q: Vector2i = p + d
			if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
				continue
			var j := q.x + q.y * w
			if seen[j] == 0 and liquid[j] == 1 and _over_water_deck(q):
				seen[j] = 1
				base_lo[j] = (base_lo[i] + base_hi[i]) * 0.5
				base_hi[j] = base_lo[j]
				ramp[j] = 0
				queue.append(j)


func _over_water_deck(p: Vector2i) -> bool:
	return MapGen.get_t(elev_map, p.x, p.y) == MapGen.BRIDGE or elev_map.get("over_water", {}).has(p)


## One flood fill at mesh creation, never per frame. Narrow streams stay shallow; open water gets a deeper bed, and so
## does water at the foot of a cliff: only a bank on the water's own level (a beach, a low shore) shelves.
## Using the same vertex smoothing as land keeps natural sloping banks, including around isolated rock tiles.
func _prepare_water_bed() -> void:
	water_bed = height.duplicate()
	var distance := PackedInt32Array()
	distance.resize(w * h)
	distance.fill(w + h)
	var queue := PackedInt32Array()
	for z in h:
		for x in w:
			var i := x + z * w
			if liquid[i] != 1 and not _cliff_over_water(x, z):
				distance[i] = 0
				queue.append(i)
	var cursor := 0
	while cursor < queue.size():
		var i := queue[cursor]
		cursor += 1
		var p := Vector2i(i % w, i / w)
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var q: Vector2i = p + d
			if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
				continue
			var j := q.x + q.y * w
			# (out across the water only: a cliff's own land behind it doesn't make its foot shallow)
			if liquid[j] == 1 and distance[j] > distance[i] + 1:
				distance[j] = distance[i] + 1
				queue.append(j)
	for i in w * h:
		if liquid[i] == 1 and height[i] < -0.05:
			water_bed[i] -= smoothstep(1.0, 6.0, float(distance[i])) * 1.8


## Whether dry tile (x, z) stands over water as a cliff: every water tile beside it is half a level or more below it.
## (A diagonal's land is its high half: its low half is the water at its foot.)
func _cliff_over_water(x: int, z: int) -> bool:
	var i := x + z * w
	var top: float = base_hi[i] if _diag(x, z) != 0 else base_lo[i]
	var wet := false
	for d in SIDES:
		var q: Vector2i = Vector2i(x, z) + d
		if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or liquid[q.x + q.y * w] != 1:
			continue
		wet = true
		var j: int = q.x + q.y * w
		if top - (base_lo[j] + base_hi[j]) * 0.5 < 0.5:
			return false
	return wet


func _place(parent: Node3D, mesh: ArrayMesh, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)


## A triangle list as a mesh. Much quicker than SurfaceTool, one vertex at a time, for a whole map's ground.
static func _triangles(verts: PackedVector3Array, normals: PackedVector3Array, colors := PackedColorArray(), uvs := PackedVector2Array(), uv2 := PackedVector2Array()) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	if not colors.is_empty():
		arrays[Mesh.ARRAY_COLOR] = colors
	if not uvs.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = uvs
	if not uv2.is_empty():
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## Every cliff face of the map (and past its edges), by the chunk whose tile it runs along: the face along each tile's
## east and south side where the ground parts, and along each diagonal. Then where faces meet with the same top, both
## ends are given one direction to stand out in (their mitre), so they join.
func _faces(parent: Node3D, slice_us: int, slice: Array) -> Dictionary:
	var out := {}
	var ends := {}
	var tall_ends := {}
	var all := []
	var x_end := w + MARGIN
	var z_end := h + MARGIN
	for tz in range(-MARGIN, z_end):
		for tx in range(-MARGIN, x_end):
			var found := []
			var code := _diag(tx, tz)
			if code != 0:
				var line := [2, 4, 6] if code in [Elev.DIAG_NW, Elev.DIAG_SE] else [0, 4, 8]
				var hg := _half_grid(tx, tz, 0)
				var lg := _half_grid(tx, tz, 1)
				var hs := Elev.high_spot(code) - Vector2(0.5, 0.5)
				found.append(_segment([hg[line[0]], hg[line[1]], hg[line[2]]], [lg[line[0]], lg[line[1]], lg[line[2]]],
					-Vector3(hs.x, 0, hs.y).normalized(), false))
			# east side: this tile's right column against the next tile's left one; south side: bottom row against top
			# (under a waterfall the rock stays smooth, behind the falling water)
			if tx + 1 < x_end:
				var g := _side(tx, tz, Vector2i.RIGHT)
				var e := _side(tx + 1, tz, Vector2i.LEFT)
				var flat := walls or _wet(tx, tz, Vector2i.RIGHT) and _wet(tx + 1, tz, Vector2i.LEFT)
				_side_faces(found, [g[2], g[5], g[8]], [e[0], e[3], e[6]], Vector3(1, 0, 0), flat,
					_side_info(tx, tz, Vector2i.RIGHT, [NE, SE]), _side_info(tx + 1, tz, Vector2i.LEFT, [NW, SW]),
					code == 0 and _diag(tx + 1, tz) == 0 and liquid[_i(tx, tz)] == 1 and liquid[_i(tx + 1, tz)] == 1)
			if tz + 1 < z_end:
				var g2 := _side(tx, tz, Vector2i.DOWN)
				var s := _side(tx, tz + 1, Vector2i.UP)
				var flat2 := walls or _wet(tx, tz, Vector2i.DOWN) and _wet(tx, tz + 1, Vector2i.UP)
				_side_faces(found, [g2[6], g2[7], g2[8]], [s[0], s[1], s[2]], Vector3(0, 0, 1), flat2,
					_side_info(tx, tz, Vector2i.DOWN, [SW, SE]), _side_info(tx, tz + 1, Vector2i.UP, [NW, NE]),
					code == 0 and _diag(tx, tz + 1) == 0 and liquid[_i(tx, tz)] == 1 and liquid[_i(tx, tz + 1)] == 1)
			# the chamfers of cut and filled corners: the turf's edge runs from the middle of one side to the other's
			if code == 0 and tx >= 0 and tz >= 0 and tx < w and tz < h and corners[tx + tz * w] != 0:
				var i := tx + tz * w
				var hi_y := base_lo[i] + LIFT
				for bit: int in CORNER_DIRS:
					if corners[i] & bit == 0:
						continue
					var d: Vector2i = CORNER_DIRS[bit]
					var m1 := Vector3(tx + 0.5 + 0.5 * d.x, hi_y, tz + 0.5)
					var m2 := Vector3(tx + 0.5, hi_y, tz + 0.5 + 0.5 * d.y)
					var mid := (m1 + m2) * 0.5
					var face_out := Vector3(d.x, 0, d.y).normalized() * (1.0 if lifted[i] == 1 else -1.0)
					found.append(_segment([m1, mid, m2], [Vector3(m1.x, base_lo[i], m1.z), Vector3(mid.x, base_lo[i], mid.z),
						Vector3(m2.x, base_lo[i], m2.z)], face_out, false, true, true))
			if found.is_empty():
				continue
			var ck := Vector2i(-MARGIN + floori(float(tx + MARGIN) / CHUNK) * CHUNK, -MARGIN + floori(float(tz + MARGIN) / CHUNK) * CHUNK)
			if not out.has(ck):
				out[ck] = []
			for f: Dictionary in found:
				out[ck].append(f)
				all.append(f)
				if f.get("waterfall", false):
					f["chunk"] = ck
				var tall := _face_drop(f) > LIFT + 0.03
				for k in [0, 2]:
					var key := _end_key(f["top"][k])
					ends[key] = ends.get(key, Vector3.ZERO) + (f["out"] as Vector3)
					if tall:
						tall_ends[key] = tall_ends.get(key, Vector3.ZERO) + (f["out"] as Vector3)
		if slice_us > 0 and Time.get_ticks_usec() - slice[0] >= slice_us:
			await parent.get_tree().process_frame
			slice[0] = Time.get_ticks_usec()
	# A waterfall crest's corners, where the banks' cliffs meet the channel's low grass edge.
	var crest_corners := {}
	for key: Vector2i in _fall_ends:
		var p: Vector3 = Vector3(key.x * 0.5, 0, key.y * 0.5) + (_fall_offsets.get(key, Vector3.ZERO) as Vector3)
		crest_corners[Vector2i(roundi(p.x * 4.0), roundi(p.z * 4.0))] = true
	for f: Dictionary in all:
		var dirs := []
		var o: Vector3 = f["out"]
		var low := _face_drop(f) <= LIFT + 0.03
		var cliff_ends := [false, false]
		for k in [0, 2]:
			var key := _end_key(f["top"][k])
			var m: Vector3 = ends[key]
			# At a crest corner the bank's cliff joins only other cliffs, and the channel's grass edge keeps to its own
			# line, so neither leans out over the falling water in a spike.
			if crest_corners.has(Vector2i(key.x, key.z)) and tall_ends.has(key):
				m = o if low else (tall_ends[key] as Vector3)
				cliff_ends[0 if k == 0 else 1] = low
			m = m.normalized() if m.length() > 0.2 else o
			# so that standing out by d along the mitre is d out from this face, as from the face it meets
			dirs.append(m / maxf(0.5, m.dot(o)))
		f["ends"] = dirs
		f["cliff_ends"] = cliff_ends
		# the rock behind the falling water runs on a little into each bank, behind the bank's own cliff, so no
		# crack opens between them
		if f.get("waterfall", false):
			for k in [0, 2]:
				var p: Vector3 = f["top"][k]
				var key := _end_key(p)
				if not crest_corners.has(Vector2i(key.x, key.z)):
					continue
				var away: Vector3 = p - (f["top"][1] as Vector3)
				away.y = 0.0
				if away.length() < 0.01:
					continue
				var q := p + away.normalized() * CREST_TUCK
				var ft: float = f["foot"][k]
				out[f["chunk"]].append({"top": [p, (p + q) * 0.5, q], "foot": [ft, ft, ft], "out": o, "flat": true,
					"turf": false, "waterfall": false, "ends": [o, o], "cliff_ends": [false, false]})
				# no falling water covers the rock this close to the bank (see _liquid_mesh)
				var bare: Array = f.get("bare_ends", [0.0, 0.0])
				bare[0 if k == 0 else 1] = FALL_SIDE_INSET
				f["bare_ends"] = bare
	return out


## How far a face drops at its deepest point.
static func _face_drop(f: Dictionary) -> float:
	var most := 0.0
	for k in 3:
		most = maxf(most, (f["top"][k] as Vector3).y - float(f["foot"][k]))
	return most


## Tile (tx, tz)'s side d, as the faces along it see it: for each half of the side (`bits`: the tile's corner at that
## half's end), whether that corner is cut or filled, the corner triangle's height then, and whether the ground along
## that half is turf (rolls over its edge) or a sharp edge.
func _side_info(tx: int, tz: int, d: Vector2i, bits: Array) -> Array:
	var i := _i(tx, tz)
	var code := _diag(tx, tz)
	var grassy := _grassy(i)
	if code != 0:
		grassy = grassy_layer(int(halves[i][0 if Elev.on_high_half(code, 0.5 + d.x * 0.5, 0.5 + d.y * 0.5) else 1]["layer"]))
	var on_map := code == 0 and tx >= 0 and tz >= 0 and tx < w and tz < h
	var out := []
	for b: int in bits:
		var cut := on_map and corners[i] & b != 0
		out.append({"cut": cut, "y": _corner_y(i) if cut else 0.0, "turf": (lifted[i] == 0) if cut else grassy})
	return out


## The faces along one side between two tiles: one for the whole side where neither tile's corners there are cut or
## filled, else one for each half of it whose ground parts (ga, ea: the two sides' three points along it).
func _side_faces(found: Array, ga: Array, ea: Array, toward: Vector3, flat: bool, ia: Array, ib: Array, waterfall := false) -> void:
	if not (ia[0]["cut"] or ia[1]["cut"] or ib[0]["cut"] or ib[1]["cut"]):
		if _edges_part(ga[0], ga[1], ga[2], ea[0], ea[1], ea[2]):
			var face := _segment(ga, ea, toward, flat, ia[0]["turf"], ib[0]["turf"])
			face["waterfall"] = waterfall
			found.append(face)
		return
	for hf in 2:
		var a := _half_pts(ga, hf, ia[hf])
		var b := _half_pts(ea, hf, ib[hf])
		if _edges_part(a[0], a[1], a[2], b[0], b[1], b[2]):
			var face := _segment(a, b, toward, flat, ia[hf]["turf"], ib[hf]["turf"])
			face["waterfall"] = waterfall
			found.append(face)


## Half `hf` of a side's three points as three of its own (at a cut or filled corner, at the corner triangle's height).
static func _half_pts(pts: Array, hf: int, info: Dictionary) -> Array:
	var p0: Vector3 = pts[hf]
	var p1: Vector3 = pts[hf + 1]
	if info["cut"]:
		p0.y = info["y"]
		p1.y = info["y"]
	return [p0, (p0 + p1) * 0.5, p1]


## Where a face's top ends, to find the faces meeting it there.
static func _end_key(p: Vector3) -> Vector3i:
	return Vector3i(roundi(p.x * 4.0), roundi(p.y * 16.0), roundi(p.z * 4.0))


## Whether tile (tx, tz)'s ground along its side d is under water (or lava).
func _wet(tx: int, tz: int, d: Vector2i) -> bool:
	var code := _diag(tx, tz)
	if code != 0:
		return int(halves[_i(tx, tz)][0 if Elev.on_high_half(code, 0.5 + d.x * 0.5, 0.5 + d.y * 0.5) else 1]["liquid"]) != 0
	return liquid[_i(tx, tz)] != 0


## A cliff face where one side's edge (vertices a, along it) stands above or below the other's (b, the same points),
## toward_b pointing from the first side to the second: {"top": the high side's three points, "foot": the low side's
## heights there, "out": the way the face looks (over the low side), "flat", "turf": whether the high side is grass
## (turf_a, turf_b: whether each side is)}.
static func _segment(a: Array, b: Array, toward_b: Vector3, flat: bool, turf_a := true, turf_b := true) -> Dictionary:
	var diff := 0.0
	for k in 3:
		diff += a[k].y - b[k].y
	var high := a if diff > 0.0 else b
	var low := b if diff > 0.0 else a
	return {"top": high, "foot": [low[0].y, low[1].y, low[2].y], "out": toward_b if diff > 0.0 else -toward_b, "flat": flat,
		"turf": turf_a if diff > 0.0 else turf_b}


## [the ground of tiles tx0..tx1, tz0..tz1, the cliff faces running along them (`faces`) or null]
func _chunk(tx0: int, tz0: int, tx1: int, tz1: int, faces: Array) -> Array:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	# (each tile is eight triangles)
	verts.resize((tx1 - tx0) * (tz1 - tz0) * 24)
	normals.resize(verts.size())
	var at := 0
	var shore_normals := {}
	for tz in range(tz0, tz1):
		for tx in range(tx0, tx1):
			var code := _diag(tx, tz)
			var g := _grid(tx, tz) if code == 0 else _half_grid(tx, tz, 0)
			var lg := g if code == 0 else _half_grid(tx, tz, 1)
			var own := _i(tx, tz)
			var mask := int(corners[own]) if code == 0 and tx >= 0 and tz >= 0 and tx < w and tz < h else 0
			for j in 2:
				for i in 2:
					var o := i + j * 3
					var q := i + j * 2
					if mask & [NW, NE, SW, SE][q] != 0:
						# a cut or filled corner: its triangle out to the middles of the sides at the other ground's
						# height, the rest of this quarter at the tile's own
						var cy := _corner_y(own)
						var c0: Vector3 = g[[o, o + 1, o + 3, o + 4][q]]
						var ma: Vector3 = g[[o + 1, o, o, o + 1][q]]
						var mb: Vector3 = g[[o + 3, o + 4, o + 4, o + 3][q]]
						var ctr: Vector3 = g[[o + 4, o + 3, o + 1, o][q]]
						_tri(verts, normals, at, Vector3(c0.x, cy, c0.z), Vector3(ma.x, cy, ma.z), Vector3(mb.x, cy, mb.z))
						at += 3
						_tri(verts, normals, at, ma, ctr, mb)
						at += 3
						continue
					# alternate the diagonal so slopes don't all crease the same way (and a diagonal cliff's line is
					# always a crease: it runs through the corners and the middle)
					var tris := [[o, o + 1, o + 4], [o, o + 4, o + 3]] if (tx * 2 + i + tz * 2 + j) % 2 == 0 else [[o, o + 1, o + 3], [o + 1, o + 4, o + 3]]
					for t: Array in tris:
						var src := g
						if code != 0:
							# the half the triangle's middle is on
							var cu := float(t[0] % 3 + t[1] % 3 + t[2] % 3) / 6.0
							var cv := float(t[0] / 3 + t[1] / 3 + t[2] / 3) / 6.0
							src = g if Elev.on_high_half(code, cu, cv) else lg
						_tri(verts, normals, at, src[t[0]], src[t[1]], src[t[2]])
						at += 3
					# A sandy slope needs continuous lighting as well as continuous heights.
					# Facet normals otherwise leave straight bands through the transparent water.
					if elev_map.has("shoreline") and lifted[own] == 0 and layer[own] in [VT.GROUND_LAYERS.find("sand"), VT.GROUND_LAYERS.find("bed")]:
						for k in 6:
							var v := verts[at - 6 + k]
							if Shoreline.contains(elev_map, v.x, v.z):
								var key := Vector2(v.x, v.z)
								if not shore_normals.has(key):
									var dx := Shoreline.bottom(elev_map, v.x - 0.05, v.z) - Shoreline.bottom(elev_map, v.x + 0.05, v.z)
									var dz := Shoreline.bottom(elev_map, v.x, v.z - 0.05) - Shoreline.bottom(elev_map, v.x, v.z + 0.05)
									shore_normals[key] = Vector3(dx, 0.1, dz).normalized()
								normals[at - 6 + k] = shore_normals[key]
	if faces.is_empty():
		return [_triangles(verts, normals), null]
	var fv := PackedVector3Array()
	var fn := PackedVector3Array()
	var fc := PackedColorArray()
	var fu := PackedVector2Array()
	var fi := PackedInt32Array()
	for f: Dictionary in faces:
		_face(fv, fn, fc, fu, fi, f)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = fv
	arrays[Mesh.ARRAY_NORMAL] = fn
	arrays[Mesh.ARRAY_COLOR] = fc
	arrays[Mesh.ARRAY_TEX_UV] = fu
	arrays[Mesh.ARRAY_INDEX] = fi
	var fm := ArrayMesh.new()
	fm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return [_triangles(verts, normals), fm]


## Whether two tiles' shared edge, three points on each side, comes apart enough to need a rock face between them.
func _edges_part(a0: Vector3, a1: Vector3, a2: Vector3, b0: Vector3, b1: Vector3, b2: Vector3) -> bool:
	return absf(a0.y - b0.y) >= 0.02 or absf(a1.y - b1.y) >= 0.02 or absf(a2.y - b2.y) >= 0.02


## One cliff face (see _faces): columns FACE_COLS to the unit along its top edge, each standing out a little in upright
## rounded flutes (grooves where two meet, and at its ends) and running down in rows to the ground below; over it the
## lip of the ground above. The ends stand out along their mitres, by the same amounts as the face they meet.
## COLOR: r how far down the rock (0 at its top, 1 at its foot), g 1 on the lip, b and a the way the face looks (x and z,
## from 0..1); UV: along the cliff and down from its top, in units.
func _face(fv: PackedVector3Array, fn: PackedVector3Array, fc: PackedColorArray, fu: PackedVector2Array, fi: PackedInt32Array, f: Dictionary) -> void:
	var top: Array = f["top"]
	var foot: Array = f["foot"]
	var out: Vector3 = f["out"]
	var flat: bool = f["flat"]
	var turf: bool = f.get("turf", true)
	var length := Vector2(top[2].x - top[0].x, top[2].z - top[0].z).length()
	var n := maxi(3, roundi(length * FACE_COLS) + 1)
	var along := Vector2(out.z, -out.x)
	var most := 0.0
	for k in 3:
		most = maxf(most, top[k].y - foot[k])
	var rows := clampi(ceili(most / FACE_ROW), 1, 10)
	# the grooves between the flutes: at both ends, and one or two in between
	var seed_k := int(round(top[0].x * 4.0)) * 31 + int(round(top[0].z * 4.0)) * 17
	var grooves := [0.0]
	var inner := 2 if length < 1.2 else 3
	for g in inner:
		grooves.append((g + 1.0 + (_hash(seed_k, 11 + g) - 0.5) * 0.45) / (inner + 1.0))
	grooves.append(1.0)
	var cols := []
	for k in n:
		var u := float(k) / (n - 1)
		var s := u * 2.0
		var i0 := mini(int(s), 1)
		var p: Vector3 = (top[i0] as Vector3).lerp(top[i0 + 1], s - i0)
		var ft: float = minf(lerpf(foot[i0], foot[i0 + 1], s - i0), p.y)
		var dir: Vector3 = f["ends"][0] if k == 0 else (f["ends"][1] if k == n - 1 else out)
		var bump := 0.0
		for g in grooves.size() - 1:
			if u >= grooves[g] and u <= grooves[g + 1]:
				var t: float = (u - grooves[g]) / maxf(0.001, grooves[g + 1] - grooves[g])
				bump = pow(sin(PI * t), 0.7) * (0.65 + 0.7 * _hash(seed_k + g, 5))
		var at_cliff: bool = (k == 0 and f.get("cliff_ends", [false, false])[0]) or (k == n - 1 and f.get("cliff_ends", [false, false])[1])
		# behind the falling water (not where the channel's banks leave the rock bare beside it) the rock is smoothed
		var bare: Array = f.get("bare_ends", [0.0, 0.0])
		var sheet: bool = f.get("waterfall", false) and u * length >= float(bare[0]) - 0.001 and (1.0 - u) * length >= float(bare[1]) - 0.001
		cols.append({"p": p, "foot": ft, "dir": dir, "bump": bump, "end": k == 0 or k == n - 1, "turf": turf, "cliff": at_cliff,
			"sheet": sheet})
	# the turf's edge over a path at its level: its muffin top (TURF), then the soil under it tucking in to the foot
	var turf_drop := LIFT + (absf(Shoreline.WADE_FLOOR) if elev_map.has("shoreline") else 0.0) + 0.03
	if turf and most <= turf_drop:
		var turf_base := fv.size()
		var prof := TURF.size() + 4
		for c: Dictionary in cols:
			var drop: float = c["p"].y - c["foot"]
			# how far this bit of the edge reaches out: a wave along it, with a little raggedness column to column
			var reach: float = lerpf(TURF_WAVE.x, TURF_WAVE.y, _wave(c["p"]))
			if not c["end"]:
				reach *= 0.94 + 0.12 * _hash(int(round(c["p"].x * 24.0)), int(round(c["p"].z * 24.0)))
			# at a waterfall crest's corner, roll over no further than the bank cliff's lip, with no shadow out over the drop
			var at_cliff: bool = c["cliff"]
			if at_cliff:
				reach = minf(reach, LIP[3].x / TURF[3].x)
			var dir: Vector3 = c["dir"]
			var dir_n := Vector3(dir.x, 0, dir.z).normalized()
			var pts: Array[Vector2] = []
			for l: Vector2 in TURF:
				pts.append(Vector2(l.x * reach, l.y))
			# the soil under it, tucking in to the foot
			pts.append(Vector2(0.02 + 0.03 * reach, -maxf(drop - 0.012, 0.04)))
			pts.append(Vector2(0.02, -(drop + 0.03)))
			# its shadow, a skirt lying on the ground from the foot out past the overhang
			var skirt := 0.012 - drop
			pts.append(Vector2(0.025, skirt))
			pts.append(Vector2(0.03 if at_cliff else 0.06 + TURF_SHADOW * (0.6 + 0.4 * _wave(c["p"] + Vector3(3.0, 0, 5.0))), skirt))
			for r in prof:
				var l: Vector2 = pts[r]
				var pt: Vector3 = c["p"] + dir * l.x + Vector3(0, l.y, 0)
				var nrm := Vector3.UP
				if r > 0 and r < TURF.size() + 2:
					var tng: Vector2 = pts[mini(r + 1, TURF.size() + 1)] - pts[r - 1]
					nrm = (dir_n * -tng.y + Vector3.UP * tng.x).normalized()
				fv.append(pt)
				fn.append(nrm)
				if r >= TURF.size() + 2:
					# the skirt: r 1 at the foot, 0 at its outer edge
					fc.append(Color(1.0 if r == TURF.size() + 2 else 0.0, 0.2, out.x * 0.5 + 0.5, out.z * 0.5 + 0.5))
				else:
					var soil := r >= TURF.size()
					fc.append(Color(float(r - TURF.size()) if soil else 0.0, 0.5 if soil else 1.0, out.x * 0.5 + 0.5, out.z * 0.5 + 0.5))
				fu.append(Vector2(c["p"].x * along.x + c["p"].z * along.y, c["p"].y - pt.y))
		_grid_tris(fi, turf_base, n, prof, fv, out)
		return
	# the lip: rows of LIP's profile, then one more where the rock's top tucks in under it (only grass rolls over the
	# edge: a path or sand at a cliff's edge meets the rock in a sharp edge)
	if not flat and turf:
		var lip_base := fv.size()
		for c: Dictionary in cols:
			var drop: float = c["p"].y - c["foot"]
			var lk := clampf(drop / 0.8, 0.25, 1.0)
			var rag := 1.0 if c["end"] else 0.85 + 0.3 * _hash(int(round(c["p"].x * 24.0)), int(round(c["p"].z * 24.0)))
			var dir: Vector3 = c["dir"]
			var dir_n := Vector3(dir.x, 0, dir.z).normalized()
			for r in LIP.size() + 1:
				var pt: Vector3 = c["p"]
				var nrm := Vector3.UP
				if r < LIP.size():
					var l: Vector2 = LIP[r]
					pt += dir * l.x * lk * rag + Vector3(0, l.y * lk * (rag if r == LIP.size() - 1 else 1.0), 0)
					if r > 0:
						var prev: Vector2 = LIP[r - 1]
						var nxt: Vector2 = LIP[mini(r + 1, LIP.size() - 1)] if r + 1 < LIP.size() else Vector2(0.0, -0.24)
						var tng := nxt - prev
						nrm = (dir_n * -tng.y + Vector3.UP * tng.x).normalized()
				else:
					pt = _rock_point(c, 0, rows, lk)
					nrm = -Vector3.UP * 0.4 + dir_n * 0.6
				fv.append(pt)
				fn.append(nrm.normalized())
				fc.append(Color(0.0, 1.0, out.x * 0.5 + 0.5, out.z * 0.5 + 0.5))
				fu.append(Vector2(c["p"].x * along.x + c["p"].z * along.y, c["p"].y - pt.y))
		_grid_tris(fi, lip_base, n, LIP.size() + 1, fv, out)
	# the rock
	var base := fv.size()
	for c: Dictionary in cols:
		var drop: float = c["p"].y - c["foot"]
		var lk := clampf(drop / 0.8, 0.25, 1.0)
		for r in rows + 1:
			var pt := _rock_point(c, r, rows, lk) if not flat else Vector3(c["p"].x, lerpf(c["p"].y, c["foot"], float(r) / rows), c["p"].z)
			fv.append(pt)
			fn.append(out)
			fc.append(Color(float(r) / rows, 0.08 if c["sheet"] else 0.0, out.x * 0.5 + 0.5, out.z * 0.5 + 0.5))
			fu.append(Vector2(c["p"].x * along.x + c["p"].z * along.y, c["p"].y - pt.y))
	_grid_tris(fi, base, n, rows + 1, fv, out)
	# smooth normals across the rock, from its neighbours in the grid, so the flutes look rounded
	if not flat:
		for k in n:
			for r in rows + 1:
				var i := base + k * (rows + 1) + r
				var a := fv[base + mini(k + 1, n - 1) * (rows + 1) + r] - fv[base + maxi(k - 1, 0) * (rows + 1) + r]
				var b := fv[base + k * (rows + 1) + mini(r + 1, rows)] - fv[base + k * (rows + 1) + maxi(r - 1, 0)]
				var nrm := b.cross(a).normalized()
				if nrm.dot(out) < 0.0:
					nrm = -nrm
				fn[i] = nrm if nrm.length_squared() > 0.5 else out
				# a face's ends lean the way of their mitre, as the face they meet does: no seam between them
				if k == 0 or k == n - 1:
					var dir: Vector3 = cols[k]["dir"]
					fn[i] = Vector3(dir.x, 0, dir.z).normalized()


## Column c of a face's rock at row r of `rows` (0 its top, under the lip): out along the column's direction by its
## flute, fullest a little below the middle, with a touch of unevenness inside the face. lk: how big the lip is.
func _rock_point(c: Dictionary, r: int, rows: int, lk: float) -> Vector3:
	var p: Vector3 = c["p"]
	var drop: float = p.y - c["foot"]
	var top_y := p.y - minf(LIP_DEPTH * lk, drop * 0.45) if c["turf"] else p.y
	var t := float(r) / rows
	var y := lerpf(top_y, c["foot"] - 0.04, t)
	var k := clampf(drop / 0.6, 0.0, 1.0) * flutes
	var d: float = FLUTE * k * (0.18 + c["bump"]) * (0.6 + 0.4 * sin(PI * minf(1.0, t * 1.4)))
	if not c["end"] and r > 0 and r < rows:
		d += (_hash(int(round(p.x * 24.0)) + r * 7, int(round(p.z * 24.0)) + r * 13) - 0.5) * 0.03 * k
	var at: Vector3 = p + (c["dir"] as Vector3) * d
	at.y = y
	return at


## Two triangles for each cell of a grid of `n` columns of `rows` vertices from index `base`, wound to face `out`.
static func _grid_tris(fi: PackedInt32Array, base: int, n: int, rows: int, fv: PackedVector3Array, out: Vector3) -> void:
	# which way round: test the first cell that isn't flat
	var flip := false
	for k in n - 1:
		var a := fv[base + k * rows]
		var b := fv[base + (k + 1) * rows]
		var c := fv[base + (k + 1) * rows + 1]
		var nrm := (c - a).cross(b - a)
		if nrm.length_squared() > 0.000001:
			flip = nrm.dot(out) < 0.0
			break
	for k in n - 1:
		for r in rows - 1:
			var i00 := base + k * rows + r
			var i10 := base + (k + 1) * rows + r
			var i11 := i10 + 1
			var i01 := i00 + 1
			if flip:
				fi.append_array([i00, i11, i10, i00, i01, i11])
			else:
				fi.append_array([i00, i10, i11, i00, i11, i01])


## One flat-shaded triangle (low-poly facets), wound to face up, written at index `at`.
func _tri(verts: PackedVector3Array, normals: PackedVector3Array, at: int, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (c - a).cross(b - a).normalized()
	if n.y < 0.0:
		var t := b
		b = c
		c = t
		n = -n
	verts[at] = a
	verts[at + 1] = b
	verts[at + 2] = c
	normals[at] = n
	normals[at + 1] = n
	normals[at + 2] = n


## Shared corner offsets carve the channel into both levels and their banks, keeping the bed and cliff sealed.
func _prepare_fall_offsets() -> void:
	_fall_offsets = {}
	_fall_sides = {}
	var ends := {}
	for z in range(-MARGIN, h + MARGIN):
		for x in range(-MARGIN, w + MARGIN):
			var i := _i(x, z)
			if liquid[i] != 1 or _diag(x, z) != 0:
				continue
			for d in [Vector2i.RIGHT, Vector2i.DOWN]:
				if x + d.x >= w + MARGIN or z + d.y >= h + MARGIN or _diag(x + d.x, z + d.y) != 0:
					continue
				var j := _i(x + d.x, z + d.y)
				var difference := (base_lo[i] + base_hi[i] - base_lo[j] - base_hi[j]) * 0.5
				if liquid[j] != 1 or absf(difference) < 0.05:
					continue
				var out := Vector3(d.x, 0, d.y) * signf(difference)
				var high := Vector2i(x, z) if difference > 0.0 else Vector2i(x + d.x, z + d.y)
				var side: Vector2i = d if difference > 0.0 else -d
				if not _fall_sides.has(high):
					_fall_sides[high] = []
				_fall_sides[high].append(side)
				for k in 3:
					var key := Vector2i(x * 2 + 2, z * 2 + k) if d.x == 1 else Vector2i(x * 2 + k, z * 2 + 2)
					var offset: Vector3 = _fall_offsets.get(key, Vector3.ZERO)
					if out.x != 0.0:
						offset.x = -out.x * FALL_ROCK_SETBACK
					if out.z != 0.0:
						offset.z = -out.z * FALL_ROCK_SETBACK
					_fall_offsets[key] = offset
					if k != 1:
						ends[key] = int(ends.get(key, 0)) + 1
	_fall_water_offsets = _fall_offsets.duplicate()
	_fall_ends = {}
	for key in ends:
		if ends[key] == 1:
			# The channel's end corners recede with the rest of the rock, so the notch runs straight across and the
			# banks bevel back to it (pulling them into the channel left a dirt spike at each end of the crest).
			_fall_ends[key] = true


func _water_corner(x: int, z: int, gx: int, gz: int, y: float) -> Vector3:
	var offset: Vector3 = _fall_water_offsets.get(Vector2i(gx, gz), Vector3.ZERO)
	var point := Vector3(gx * 0.5, y, gz * 0.5) + offset * (FALL_SETBACK / FALL_ROCK_SETBACK)
	if offset == Vector3.ZERO:
		return point
	# Leave exactly the lip's width for the joining strip on the high side; the lower pool reaches the sheet.
	for d: Vector2i in _fall_sides.get(Vector2i(x, z), []):
		if (d.x < 0 and gx != x * 2) or (d.x > 0 and gx != x * 2 + 2) or (d.y < 0 and gz != z * 2) or (d.y > 0 and gz != z * 2 + 2):
			continue
		if _fall_ends.has(Vector2i(gx, gz)):
			# beside the sheet the bank rises out of the water: stop just behind the rock's edge, so no sliver of
			# water stands in front of the rock (its contact foam drew a white line there)
			point = Vector3(gx * 0.5, y, gz * 0.5) + offset - Vector3(d.x, 0, d.y) * 0.02
		else:
			point -= Vector3(d.x, 0, d.y) * FALL_LIP
	return point


func _water_rim_uv(x: int, z: int, point: Vector3) -> Vector2:
	var distance := INF
	for d: Vector2i in _fall_sides.get(Vector2i(x, z), []):
		var out := Vector3(d.x, 0, d.y)
		var edge := Vector3(x + 0.5, point.y, z + 0.5) + out * (0.5 - FALL_SETBACK)
		distance = minf(distance, maxf(0.0, (edge - point).dot(out)))
	return Vector2(1, distance) if is_finite(distance) else Vector2.ZERO


## The water (kind 1) or lava (kind 2) surface, with a joined lip at every natural fall.
func _liquid_mesh(kind: int) -> ArrayMesh:
	var y0 := -0.12 if kind == 1 else -0.16
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	for tz in range(-MARGIN, h + MARGIN):
		for tx in range(-MARGIN, w + MARGIN):
			var i := _i(tx, tz)
			var code := _diag(tx, tz)
			if code != 0:
				for k in 2:
					if int(halves[i][k]["liquid"]) != kind:
						continue
					var hy: float = y0 + float(halves[i][k]["level"])
					for c: Vector2 in HALF_CORNERS[code][k]:
						verts.append(Vector3(tx + c.x, hy, tz + c.y))
						uvs.append(Vector2.ZERO)
				continue
			if liquid[i] != kind:
				continue
			var y := y0 + (base_lo[i] + base_hi[i]) / 2.0
			var a := Vector3(tx, y, tz)
			var b := Vector3(tx + 1, y, tz)
			var c := Vector3(tx + 1, y, tz + 1)
			var d := Vector3(tx, y, tz + 1)
			if kind == 1:
				a = _water_corner(tx, tz, tx * 2, tz * 2, y)
				b = _water_corner(tx, tz, tx * 2 + 2, tz * 2, y)
				c = _water_corner(tx, tz, tx * 2 + 2, tz * 2 + 2, y)
				d = _water_corner(tx, tz, tx * 2, tz * 2 + 2, y)
			verts.append_array([a, b, c, a, c, d])
			var ua := _water_rim_uv(tx, tz, a) if kind == 1 else Vector2.ZERO
			var ub := _water_rim_uv(tx, tz, b) if kind == 1 else Vector2.ZERO
			var uc := _water_rim_uv(tx, tz, c) if kind == 1 else Vector2.ZERO
			var ud := _water_rim_uv(tx, tz, d) if kind == 1 else Vector2.ZERO
			uvs.append_array([ua, ub, uc, ua, uc, ud])
	if verts.is_empty():
		return null
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	var uv2 := PackedVector2Array()
	uv2.resize(verts.size())
	uv2.fill(Vector2.ZERO)
	# waterfalls: where the surface steps down to the next tile's, a sheet of it falls from one to the other, just out
	# from the rock behind
	for tz in range(-MARGIN, h + MARGIN):
		for tx in range(-MARGIN, w + MARGIN):
			var i := _i(tx, tz)
			if liquid[i] != kind or _diag(tx, tz) != 0:
				continue
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var j := _i(tx + d.x, tz + d.y)
				if tx + d.x >= w + MARGIN or tz + d.y >= h + MARGIN or liquid[j] != kind or _diag(tx + d.x, tz + d.y) != 0:
					continue
				var ya := y0 + (base_lo[i] + base_hi[i]) / 2.0
				var yb := y0 + (base_lo[j] + base_hi[j]) / 2.0
				if absf(ya - yb) < 0.05:
					continue
				var out := Vector3(d.x, 0, d.y) * (1.0 if ya > yb else -1.0)
				var e0 := Vector3(tx + 1, 0, tz) if d.x == 1 else Vector3(tx, 0, tz + 1)
				var e1 := Vector3(tx + 1, 0, tz + 1)
				if kind == 1:
					e0 += (_fall_water_offsets.get(Vector2i(roundi(e0.x * 2), roundi(e0.z * 2)), Vector3.ZERO) as Vector3) * (FALL_SETBACK / FALL_ROCK_SETBACK)
					e1 += (_fall_water_offsets.get(Vector2i(roundi(e1.x * 2), roundi(e1.z * 2)), Vector3.ZERO) as Vector3) * (FALL_SETBACK / FALL_ROCK_SETBACK)
				else:
					e0 += out * 0.04
					e1 += out * 0.04
				var key0 := Vector2i(tx * 2 + 2, tz * 2) if d.x == 1 else Vector2i(tx * 2, tz * 2 + 2)
				var key1 := Vector2i(tx * 2 + 2, tz * 2 + 2)
				# At the channel's sides the bed slopes up out of the water, so the falling sheet starts where the
				# river above shows as water, no wider.
				if kind == 1:
					var along := Vector3(0, 0, 1) if d.x == 1 else Vector3(1, 0, 0)
					if _fall_ends.has(key0):
						e0 += along * FALL_SIDE_INSET
					if _fall_ends.has(key1):
						e1 -= along * FALL_SIDE_INSET
				var bank0 := e0 - out * FALL_LIP
				var bank1 := e1 - out * FALL_LIP
				if kind == 1:
					# the joining strip starts on the upper water's own edge, which steps back behind the rock at the ends
					var hi := Vector2i(tx, tz) if ya > yb else Vector2i(tx + d.x, tz + d.y)
					var w0 := _water_corner(hi.x, hi.y, key0.x, key0.y, 0.0)
					var w1 := _water_corner(hi.x, hi.y, key1.x, key1.y, 0.0)
					bank0 = w0.lerp(w1, FALL_SIDE_INSET if _fall_ends.has(key0) else 0.0)
					bank1 = w1.lerp(w0, FALL_SIDE_INSET if _fall_ends.has(key1) else 0.0)
				var crest_ends := Vector2(e0.x + e0.z + 0.08 if _fall_ends.has(key0) else -100000.0,
					e1.x + e1.z - 0.08 if _fall_ends.has(key1) else 100000.0)
				var top := maxf(ya, yb)
				var foot := minf(ya, yb)
				var q := [e0 + Vector3(0, top, 0), e1 + Vector3(0, top, 0), e1 + Vector3(0, foot, 0), e0 + Vector3(0, foot, 0)]
				verts.append_array([q[0], q[1], q[2], q[0], q[2], q[3]])
				uvs.append_array([Vector2(2, 0), Vector2(2, 0), Vector2(2, top - foot), Vector2(2, 0), Vector2(2, top - foot), Vector2(2, top - foot)])
				for k in 6:
					normals.append(out)
					uv2.append(crest_ends)
				if kind == 1:
					# Close the 4 cm stand-off from the rock with a crest lip. All three faces share the swell.
					var a := bank0 + Vector3.UP * top
					var b := bank1 + Vector3.UP * top
					verts.append_array([a, b, q[1], a, q[1], q[0]])
					for k in 6:
						normals.append(Vector3.UP)
						uvs.append(Vector2(2, 0))
						uv2.append(crest_ends)
	return _triangles(verts, normals, PackedColorArray(), uvs, uv2)


func _liquid(parent: Node3D, mesh: ArrayMesh, kind: int, col: Color) -> void:
	if mesh == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = WaterShader
	var lava := kind == 2
	mat.set_shader_parameter("frames", VT.frames("lava" if lava else "water"))
	mat.set_shader_parameter("frame_count", float(VT.LAVA_FRAMES if lava else VT.WATER_FRAMES))
	mat.set_shader_parameter("fps", 2.0 if lava else 6.0)
	mat.set_shader_parameter("tint", col)
	mat.set_shader_parameter("opacity", 1.0 if lava else 0.96)
	mat.set_shader_parameter("glow", 1.4 if lava else 0.0)
	mat.set_shader_parameter("fall_swell", not lava)
	mat.set_shader_parameter("fall_rim", not lava)
	mat.set_shader_parameter("drift", Vector2(0.01, 0.02) if lava else Vector2(0.0, 0.03))
	if not lava and elev_map.has("shoreline"):
		# This beach faces south: the wash and its quiet light pattern travel north towards the sand.
		mat.set_shader_parameter("drift", Vector2(0.0, -0.03))
		var r: Array = elev_map["shoreline"]
		mat.set_shader_parameter("shore", Vector4(r[0], r[1], r[2], r[3]))
		mat.set_shader_parameter("shore_levels", Vector3(Shoreline.WATER_Y, Shoreline.WADE_FLOOR, Shoreline.DEEP_FLOOR))
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 0.1
	parent.add_child(mi)


## The ground's height at (x, z), on the same triangles the mesh draws (for placing things on or over it after the
## build: lily pads keep their whole leaf over open water). INF on a diagonal or cut-corner tile, off the map, or by a
## waterfall, where the simple grid doesn't describe the ground; callers treat that as dry.
func ground_y(x: float, z: float) -> float:
	var tx := floori(x)
	var tz := floori(z)
	if tx < 0 or tz < 0 or tx >= w or tz >= h or _diag(tx, tz) != 0 or corners[_i(tx, tz)] != 0:
		return INF
	var fx := (x - tx) * 2.0
	var fz := (z - tz) * 2.0
	var i := mini(int(fx), 1)
	var j := mini(int(fz), 1)
	var u := fx - i
	var v := fz - j
	for gx in [tx * 2 + i, tx * 2 + i + 1]:
		for gz in [tz * 2 + j, tz * 2 + j + 1]:
			if _fall_offsets.has(Vector2i(gx, gz)):
				return INF
	var g := _grid(tx, tz)
	var o := i + j * 3
	var a := g[o].y
	var b := g[o + 1].y
	var c := g[o + 3].y
	var d := g[o + 4].y
	# the same alternating crease as _chunk
	if (tx * 2 + i + tz * 2 + j) % 2 == 0:
		return a + u * (b - a) + v * (d - b) if u >= v else a + v * (c - a) + u * (d - c)
	return a + u * (b - a) + v * (c - a) if u + v <= 1.0 else d + (1.0 - u) * (c - d) + (1.0 - v) * (b - d)
