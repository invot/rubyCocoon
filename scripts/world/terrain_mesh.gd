extends RefCounted
## The overworld ground as a low-poly height field instead of voxel blocks.
##
## Vertices sit at every tile centre and on every tile edge (half a tile apart). A tile's centre has the tile's own
## height (0 for ground, below 0 for river beds and lava, above 0 for rocks), and an edge or corner takes whichever
## neighbouring height is closest to 0. So walkable ground stays flat where people stand, river beds slope down from
## their banks, and rocky tiles rise into faceted crags from the edge of the ground around them.
## The ground carries on MARGIN tiles past the map's edge (copying the edge tiles), so there is no drop-off.

const VT = preload("res://scripts/gfx/voxel_textures.gd")
const TerrainShader = preload("res://scripts/gfx/terrain.gdshader")
const WaterShader = preload("res://scripts/gfx/water.gdshader")

const CHUNK := 16
const MARGIN := 16
## sRGB grey the ground textures average out at, in linear terms: dividing it out keeps each biome colour as authored.
const TEX_LEVEL := 0.71

var w := 0
var h := 0
## per tile: index into VT.GROUND_LAYERS, centre height, and whether the surface is craggy rock
var layer := PackedByteArray()
var height := PackedFloat32Array()
var rough := PackedByteArray()
## per tile: 0 = dry, 1 = water surface, 2 = lava surface
var liquid := PackedByteArray()
var seed := 0


func setup(width: int, depth: int, map_seed: int) -> void:
	w = width
	h = depth
	seed = map_seed
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


## Height of grid vertex (gx, gz), in half tiles: odd = a tile centre, even = a tile edge.
func _vertex_y(gx: int, gz: int) -> float:
	var xs := [(gx - 1) / 2] if gx % 2 != 0 else [gx / 2 - 1, gx / 2]
	var zs := [(gz - 1) / 2] if gz % 2 != 0 else [gz / 2 - 1, gz / 2]
	var best := INF
	var craggy := false
	for tx in xs:
		for tz in zs:
			var i := _i(tx, tz)
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
	return best


func _hash(a: int, b: int) -> float:
	var n := (a * 73856093) ^ (b * 19349663) ^ seed
	n = (n ^ (n >> 13)) * 1274126177
	return float((n ^ (n >> 16)) & 0xffff) / 65535.0


## Builds the ground, water and lava under `parent`. tints: one colour per VT.GROUND_LAYERS entry.
func build(parent: Node3D, tints: Array, water_col: Color) -> void:
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
	var x0 := -MARGIN
	var z0 := -MARGIN
	var x1 := w + MARGIN
	var z1 := h + MARGIN
	var cz := z0
	while cz < z1:
		var cx := x0
		while cx < x1:
			_chunk(parent, mat, cx, cz, mini(cx + CHUNK, x1), mini(cz + CHUNK, z1))
			cx += CHUNK
		cz += CHUNK
	_liquid(parent, 1, water_col)
	_liquid(parent, 2, Color("#ff6a20"))


func _chunk(parent: Node3D, mat: Material, tx0: int, tz0: int, tx1: int, tz1: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cache := {}
	for gz in range(tz0 * 2, tz1 * 2):
		for gx in range(tx0 * 2, tx1 * 2):
			var p := [_vtx(gx, gz, cache), _vtx(gx + 1, gz, cache), _vtx(gx + 1, gz + 1, cache), _vtx(gx, gz + 1, cache)]
			# alternate the diagonal so slopes don't all crease the same way
			if (gx + gz) % 2 == 0:
				_tri(st, p[0], p[1], p[2])
				_tri(st, p[0], p[2], p[3])
			else:
				_tri(st, p[0], p[1], p[3])
				_tri(st, p[1], p[2], p[3])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)


func _vtx(gx: int, gz: int, cache: Dictionary) -> Vector3:
	var k := Vector2i(gx, gz)
	if not cache.has(k):
		cache[k] = Vector3(gx * 0.5, _vertex_y(gx, gz), gz * 0.5)
	return cache[k]


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


## The water (kind 1) or lava (kind 2) surface: one quad per tile, carried on past the map's edge too.
func _liquid(parent: Node3D, kind: int, col: Color) -> void:
	var y := -0.12 if kind == 1 else -0.16
	var verts := PackedVector3Array()
	for tz in range(-MARGIN, h + MARGIN):
		for tx in range(-MARGIN, w + MARGIN):
			if liquid[_i(tx, tz)] != kind:
				continue
			var a := Vector3(tx, y, tz)
			var b := Vector3(tx + 1, y, tz)
			var c := Vector3(tx + 1, y, tz + 1)
			var d := Vector3(tx, y, tz + 1)
			verts.append_array([a, b, c, a, c, d])
	if verts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
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
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
