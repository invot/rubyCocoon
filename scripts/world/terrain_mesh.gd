extends RefCounted
## The overworld ground as a low-poly height field instead of voxel blocks.
##
## Each tile is drawn from its own 3x3 vertices: at its centre, the middles of its edges and its corners (half a tile
## apart). A tile stands on its base (elevation.gd: a level, or a ramp's slope) and has a height of its own above it:
## 0 for ground, below 0 for river beds and lava, above 0 for rocks. An edge or corner takes whichever height of the
## tiles sharing it on the same level is closest to 0. So walkable ground stays flat where people stand, river beds
## slope down from their banks, and rocky tiles rise into faceted crags from the edge of the ground around them.
## Where neighbouring tiles' edges don't meet (a cliff between two levels, the side of a ramp), a rock face fills the
## gap, bulging out a little here and there, with a lip of the ground above along its top (or, in a town that wants
## them, a straight stone retaining wall). Where a river runs over a cliff, it falls down it as a sheet of water.
## The ground carries on MARGIN tiles past the map's edge (copying the edge tiles), so there is no drop-off.

const VT = preload("res://scripts/gfx/voxel_textures.gd")
const Elev = preload("res://scripts/world/elevation.gd")
const TerrainShader = preload("res://scripts/gfx/terrain.gdshader")
const WaterShader = preload("res://scripts/gfx/water.gdshader")
const Shoreline = preload("res://scripts/world/shoreline.gd")

const CHUNK := 16
const MARGIN := 16
## sRGB grey the ground textures average out at, in linear terms: dividing it out keeps each biome colour as authored.
const TEX_LEVEL := 0.71
## A cliff face is cut into rows about this tall, so it can bulge.
const FACE_ROW := 0.45

var w := 0
var h := 0
## per tile: index into VT.GROUND_LAYERS, centre height, and whether the surface is craggy rock
var layer := PackedByteArray()
var height := PackedFloat32Array()
var rough := PackedByteArray()
## per tile: 0 = dry, 1 = water surface, 2 = lava surface
var liquid := PackedByteArray()
var seed := 0
## the map, for its levels and ramps (elevation.gd); flat without them
var elev_map := {}
## per tile (from elevation.gd): the height of its low edge and its high edge, and its ramp direction (0 = flat)
var base_lo := PackedFloat32Array()
var base_hi := PackedFloat32Array()
var ramp := PackedByteArray()
## the ground's and the cliffs' materials, for the see-through patch (world.gd _update_hole)
var materials: Array[ShaderMaterial] = []
## cliffs drawn as straight dressed-stone walls instead of rock (see build)
var walls := false


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


func set_tile(x: int, y: int, layer_name: String, top: float, is_rough := false, liquid_kind := 0) -> void:
	var i := x + y * w
	layer[i] = maxi(0, VT.GROUND_LAYERS.find(layer_name))
	height[i] = top
	rough[i] = 1 if is_rough else 0
	liquid[i] = liquid_kind


func _i(x: int, y: int) -> int:
	return clampi(x, 0, w - 1) + clampi(y, 0, h - 1) * w


## The height of tile i's ground (before its own rise or dip) at (u, v) across it: flat, or a ramp's slope.
func _plane(i: int, u: float, v: float) -> float:
	match ramp[i]:
		1:
			return lerpf(base_lo[i], base_hi[i], 1.0 - v)
		2:
			return lerpf(base_lo[i], base_hi[i], v)
		3:
			return lerpf(base_lo[i], base_hi[i], 1.0 - u)
		4:
			return lerpf(base_lo[i], base_hi[i], u)
	return base_lo[i]


## Height of tile (tx, tz) at grid vertex (gx, gz), in half tiles (gx from 2 * tx to 2 * tx + 2): odd = the tile's
## centre, even = an edge.
func _vertex_y(tx: int, tz: int, gx: int, gz: int) -> float:
	var own := _i(tx, tz)
	var base := _plane(own, (gx - 2 * tx) / 2.0, (gz - 2 * tz) / 2.0)
	if Shoreline.contains(elev_map, gx * 0.5, gz * 0.5):
		return base + Shoreline.bottom(elev_map, gx * 0.5, gz * 0.5)
	# a ramp is one smooth slope
	if ramp[own] != 0:
		return base
	var xs := [(gx - 1) / 2] if gx % 2 != 0 else [gx / 2 - 1, gx / 2]
	var zs := [(gz - 1) / 2] if gz % 2 != 0 else [gz / 2 - 1, gz / 2]
	var best := INF
	var craggy := false
	for nx in xs:
		for nz in zs:
			var i := _i(nx, nz)
			# only flat ground on the same level is drawn as one with this tile
			if ramp[i] != 0 or absf(base_lo[i] - base_lo[own]) > 0.01:
				continue
			var v := height[i]
			if absf(v) < absf(best):
				best = v
			if rough[i] == 1:
				craggy = true
	if craggy and best > 0.05:
		# break up the rock into facets; the noise is fixed per vertex so neighbouring chunks agree
		best += (_hash(gx, gz) - 0.4) * 0.35
	elif best < -0.05:
		best += (_hash(gx, gz) - 0.5) * 0.06
	return base + best


## Tile (tx, tz)'s nine vertices, row by row from its north-west corner (cached).
func _grid(tx: int, tz: int, cache: Dictionary) -> PackedVector3Array:
	var k := Vector2i(tx, tz)
	if cache.has(k):
		return cache[k]
	var g := PackedVector3Array()
	for j in 3:
		for i in 3:
			var gx := tx * 2 + i
			var gz := tz * 2 + j
			g.append(Vector3(gx * 0.5, _vertex_y(tx, tz, gx, gz), gz * 0.5))
	cache[k] = g
	return g


func _hash(a: int, b: int) -> float:
	var n := (a * 73856093) ^ (b * 19349663) ^ seed
	n = (n ^ (n >> 13)) * 1274126177
	return float((n ^ (n >> 16)) & 0xffff) / 65535.0


## Builds the ground, the cliffs, water and lava under `parent`. tints: one colour per VT.GROUND_LAYERS entry;
## cliff_col: the rock of the cliff faces; stone_walls: dressed stone (the "paving" layer) instead, straight up.
func build(parent: Node3D, tints: Array, water_col: Color, cliff_col := Color("#8a8478"), stone_walls := false) -> void:
	walls = stone_walls
	var mat := ShaderMaterial.new()
	mat.shader = TerrainShader
	mat.set_shader_parameter("layers", VT.ground_layers())
	var kinds := Image.create(w + MARGIN * 2, h + MARGIN * 2, false, Image.FORMAT_R8)
	for y in kinds.get_height():
		for x in kinds.get_width():
			kinds.set_pixel(x, y, Color(layer[_i(x - MARGIN, y - MARGIN)] / 255.0, 0, 0))
	mat.set_shader_parameter("kind_map", ImageTexture.create_from_image(kinds))
	mat.set_shader_parameter("map_origin", Vector2(-MARGIN, -MARGIN))
	mat.set_shader_parameter("map_size", Vector2(kinds.get_width(), kinds.get_height()))
	# plain vectors, already linear: a colour array would be converted from sRGB a second time
	var lin := PackedVector3Array()
	for c in tints:
		var l: Color = (c as Color).srgb_to_linear()
		lin.append(Vector3(l.r, l.g, l.b) / TEX_LEVEL)
	mat.set_shader_parameter("tints", lin)
	var cliff_mat: ShaderMaterial = mat.duplicate()
	cliff_mat.set_shader_parameter("cliff", true)
	var cl := cliff_col.srgb_to_linear()
	cliff_mat.set_shader_parameter("cliff_tint", Vector3(cl.r, cl.g, cl.b) / TEX_LEVEL)
	cliff_mat.set_shader_parameter("rock_layer", VT.GROUND_LAYERS.find("paving" if walls else "rock"))
	materials = [mat, cliff_mat]
	var x0 := -MARGIN
	var z0 := -MARGIN
	var x1 := w + MARGIN
	var z1 := h + MARGIN
	var cz := z0
	while cz < z1:
		var cx := x0
		while cx < x1:
			_chunk(parent, mat, cliff_mat, cx, cz, mini(cx + CHUNK, x1), mini(cz + CHUNK, z1), x1, z1)
			cx += CHUNK
		cz += CHUNK
	_liquid(parent, 1, water_col)
	_liquid(parent, 2, Color("#ff6a20"))


## The ground of tiles tx0..tx1, tz0..tz1, and the cliff faces along their east and south edges (up to the last
## tile drawn at all, x_end and z_end).
func _chunk(parent: Node3D, mat: Material, cliff_mat: Material, tx0: int, tz0: int, tx1: int, tz1: int, x_end: int, z_end: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := SurfaceTool.new()
	faces.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any_face := false
	var cache := {}
	for tz in range(tz0, tz1):
		for tx in range(tx0, tx1):
			var g := _grid(tx, tz, cache)
			for j in 2:
				for i in 2:
					var p := [g[i + j * 3], g[i + 1 + j * 3], g[i + 1 + (j + 1) * 3], g[i + (j + 1) * 3]]
					# alternate the diagonal so slopes don't all crease the same way
					if (tx * 2 + i + tz * 2 + j) % 2 == 0:
						_tri(st, p[0], p[1], p[2])
						_tri(st, p[0], p[2], p[3])
					else:
						_tri(st, p[0], p[1], p[3])
						_tri(st, p[1], p[2], p[3])
			# east edge: this tile's right column against the next tile's left one; south edge: bottom row against top
			# (under a waterfall the rock stays smooth, behind the falling water)
			var wet := liquid[_i(tx, tz)] != 0
			if tx + 1 < x_end:
				var e := _grid(tx + 1, tz, cache)
				var flat := walls or wet and liquid[_i(tx + 1, tz)] != 0
				any_face = _face(faces, [g[2], g[5], g[8]], [e[0], e[3], e[6]], Vector3(1, 0, 0), flat) or any_face
			if tz + 1 < z_end:
				var s := _grid(tx, tz + 1, cache)
				var flat2 := walls or wet and liquid[_i(tx, tz + 1)] != 0
				any_face = _face(faces, [g[6], g[7], g[8]], [s[0], s[1], s[2]], Vector3(0, 0, 1), flat2) or any_face
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	if any_face:
		var fm := MeshInstance3D.new()
		fm.mesh = faces.commit()
		fm.material_override = cliff_mat
		fm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		parent.add_child(fm)


## The rock face where one tile's edge (vertices a, along it) stands above or below its neighbour's (b, the same
## points), toward_b pointing from the first tile to the second. Cut into columns a quarter tile apart and rows about
## FACE_ROW tall; the inner vertices bulge out a little unless `flat`. Returns false if the edges meet (no face).
func _face(st: SurfaceTool, a: Array, b: Array, toward_b: Vector3, flat := false) -> bool:
	var diff := 0.0
	var most := 0.0
	for k in 3:
		diff += a[k].y - b[k].y
		most = maxf(most, absf(a[k].y - b[k].y))
	if most < 0.02:
		return false
	# the face looks out over the lower side
	var high := a if diff > 0.0 else b
	var low := b if diff > 0.0 else a
	var out := toward_b if diff > 0.0 else -toward_b
	var cols := []
	for k in 5:
		var s := k / 2.0
		var i0 := mini(int(s), 1)
		var f := s - i0
		var top: Vector3 = (high[i0] as Vector3).lerp(high[i0 + 1], f)
		var foot: float = lerpf(low[i0].y, low[i0 + 1].y, f)
		cols.append([top, minf(foot, top.y)])
	var rows := clampi(ceili(most / FACE_ROW), 1, 10)
	var grid := []
	for k in 5:
		var top: Vector3 = cols[k][0]
		var drop: float = top.y - float(cols[k][1])
		var bulge_k := clampf(drop / 0.6, 0.0, 1.0)
		var col := []
		for r in rows + 1:
			var p := top
			p.y = lerpf(top.y, float(cols[k][1]), float(r) / rows)
			if r > 0 and r < rows and k > 0 and k < 4 and not flat:
				var hx := int(round(top.x * 4.0)) * 31 + r * 7
				var hz := int(round(top.z * 4.0)) * 17 + r * 13
				p += out * (0.04 + _hash(hx, hz) * 0.15) * bulge_k
				p.y += (_hash(hz, hx) - 0.5) * 0.12 * bulge_k
			col.append(p)
		grid.append(col)
	for k in 4:
		for r in rows:
			var shade_a := lerpf(1.0, 0.6, float(r) / rows)
			var shade_b := lerpf(1.0, 0.6, float(r + 1) / rows)
			var lip_a := 1.0 if r == 0 else 0.0
			var p00: Vector3 = grid[k][r]
			var p10: Vector3 = grid[k + 1][r]
			var p11: Vector3 = grid[k + 1][r + 1]
			var p01: Vector3 = grid[k][r + 1]
			var ca := Color(shade_a, lip_a, 0)
			var cb := Color(shade_b, 0, 0)
			_face_tri(st, out, [p00, p10, p11], [ca, ca, cb])
			_face_tri(st, out, [p00, p11, p01], [ca, cb, cb])
	return true


## One flat-shaded triangle of a cliff face, wound to face `out`; COLOR carries its shading (r) and lip (g).
func _face_tri(st: SurfaceTool, out: Vector3, p: Array, c: Array) -> void:
	var n: Vector3 = (p[2] - p[0]).cross(p[1] - p[0])
	if n.length_squared() < 0.000001:
		return
	n = n.normalized()
	if n.dot(out) < 0.0:
		p = [p[0], p[2], p[1]]
		c = [c[0], c[2], c[1]]
		n = -n
	st.set_normal(n)
	for k in 3:
		st.set_color(c[k])
		st.add_vertex(p[k])


## One flat-shaded triangle (low-poly facets), wound to face up.
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (c - a).cross(b - a).normalized()
	if n.y < 0.0:
		var t := b
		b = c
		c = t
		n = -n
	st.set_normal(n)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


## The water (kind 1) or lava (kind 2) surface: one quad per tile on its level, carried on past the map's edge too.
func _liquid(parent: Node3D, kind: int, col: Color) -> void:
	var y0 := -0.12 if kind == 1 else -0.16
	var verts := PackedVector3Array()
	for tz in range(-MARGIN, h + MARGIN):
		for tx in range(-MARGIN, w + MARGIN):
			if liquid[_i(tx, tz)] != kind:
				continue
			var i := _i(tx, tz)
			var y := y0 + (base_lo[i] + base_hi[i]) / 2.0
			var a := Vector3(tx, y, tz)
			var b := Vector3(tx + 1, y, tz)
			var c := Vector3(tx + 1, y, tz + 1)
			var d := Vector3(tx, y, tz + 1)
			verts.append_array([a, b, c, a, c, d])
	if verts.is_empty():
		return
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	# waterfalls: where the surface steps down to the next tile's, a sheet of it falls from one to the other, just out
	# from the rock behind
	for tz in range(-MARGIN, h + MARGIN):
		for tx in range(-MARGIN, w + MARGIN):
			var i := _i(tx, tz)
			if liquid[i] != kind:
				continue
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var j := _i(tx + d.x, tz + d.y)
				if tx + d.x >= w + MARGIN or tz + d.y >= h + MARGIN or liquid[j] != kind:
					continue
				var ya := y0 + (base_lo[i] + base_hi[i]) / 2.0
				var yb := y0 + (base_lo[j] + base_hi[j]) / 2.0
				if absf(ya - yb) < 0.05:
					continue
				var out := Vector3(d.x, 0, d.y) * (1.0 if ya > yb else -1.0)
				var e0 := Vector3(tx + 1, 0, tz) if d.x == 1 else Vector3(tx, 0, tz + 1)
				var e1 := Vector3(tx + 1, 0, tz + 1)
				e0 += out * 0.04
				e1 += out * 0.04
				var top := maxf(ya, yb)
				var foot := minf(ya, yb)
				var q := [e0 + Vector3(0, top, 0), e1 + Vector3(0, top, 0), e1 + Vector3(0, foot, 0), e0 + Vector3(0, foot, 0)]
				verts.append_array([q[0], q[1], q[2], q[0], q[2], q[3]])
				for k in 6:
					normals.append(out)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = WaterShader
	var lava := kind == 2
	mat.set_shader_parameter("frames", VT.frames("lava" if lava else "water"))
	mat.set_shader_parameter("frame_count", float(VT.LAVA_FRAMES if lava else VT.WATER_FRAMES))
	mat.set_shader_parameter("fps", 2.0 if lava else 6.0)
	mat.set_shader_parameter("tint", col)
	mat.set_shader_parameter("opacity", 1.0 if lava else 0.84)
	mat.set_shader_parameter("glow", 1.4 if lava else 0.0)
	mat.set_shader_parameter("drift", Vector2(0.01, 0.02) if lava else Vector2(0.0, 0.03))
	if not lava and elev_map.has("shoreline"):
		var r: Array = elev_map["shoreline"]
		mat.set_shader_parameter("shore", Vector4(r[0], r[1], r[2], r[3]))
		mat.set_shader_parameter("shore_levels", Vector3(Shoreline.WATER_Y, Shoreline.WADE_FLOOR, Shoreline.DEEP_FLOOR))
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
