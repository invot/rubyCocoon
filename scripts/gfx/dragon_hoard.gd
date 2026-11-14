extends RefCounted
## A temple guardian's hoard (the only gold coins in the game): heaps of KayKit's coins and coin stacks, golden arms,
## trunks, candles, keys and plates (tools/import_kaykit.gd --hoard), clustered on the tiles a chamber lists as
## "hoard" (interior_maps.gd) and scattered in the nest's four corners. Every piece is merged into one mesh on the
## pack's shared atlas: one draw call for the whole room, casting no shadow.

const DIR := "res://assets/props/kaykit_hoard_"

## What can lie on a hoard tile: a few clusters, picked per tile. [piece, x, z, yaw (or NAN for any), scale]
const CLUSTERS := [
	# a heap of gold with stacks and loose coins round it
	[["coin_stack_large", 0.0, -0.05, NAN, 1.0], ["coin_stack_small", 0.32, 0.25, NAN, 1.0], ["coin", -0.32, 0.3, NAN, 1.0],
		["coin", 0.05, 0.38, NAN, 1.0], ["coin", -0.38, -0.2, NAN, 1.0]],
	# a trunk with a candle, coins spilling in front
	[["trunk_large_A", 0.0, -0.12, 0.0, 1.0], ["candle_triple", 0.36, -0.22, NAN, 1.0], ["coin_stack_small", -0.25, 0.3, NAN, 1.0],
		["coin", 0.2, 0.32, NAN, 1.0], ["coin", 0.0, 0.42, NAN, 1.0]],
	# golden arms leaning on a stack of gold
	[["coin_stack_medium", 0.1, -0.2, NAN, 1.0], ["sword_shield_gold", -0.05, 0.05, 0.0, 0.9], ["coin", 0.33, 0.32, NAN, 1.0],
		["coin", -0.3, 0.35, NAN, 1.0], ["candle_lit", -0.38, -0.3, NAN, 1.0]],
	# plates, keys and small trunks
	[["trunk_medium_B", -0.18, -0.15, 0.3, 1.0], ["plate_stack", 0.25, -0.05, NAN, 1.0], ["keyring", 0.05, 0.3, NAN, 0.55],
		["coin_stack_small", -0.3, 0.3, NAN, 1.0], ["candle_melted", 0.38, -0.35, NAN, 1.0]],
	# a pile of stacks
	[["coin_stack_medium", -0.18, -0.12, NAN, 1.0], ["coin_stack_small", 0.24, -0.18, NAN, 1.0], ["trunk_small_C", 0.2, 0.25, -0.4, 1.0],
		["coin", -0.25, 0.32, NAN, 1.0], ["coin", 0.0, 0.1, NAN, 1.0]],
]
## In each of the nest's corners (beyond its round foot): a little gold.
const CORNER := [["coin_stack_small", 0.0, 0.0, NAN, 0.9], ["coin", 0.22, -0.12, NAN, 1.0], ["coin", -0.12, 0.2, NAN, 1.0]]

static var _pieces := {}


## The hoard for a chamber: `tiles` are hoard tiles' middles and `corners` the nest's corner spots (world positions,
## standing on their floor); `seed` picks the clusters.
static func mesh(tiles: Array, corners: Array, seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat: Material = null
	var last := -1
	for p: Vector3 in tiles:
		var k := rng.randi() % CLUSTERS.size()
		if k == last:
			k = (k + 1) % CLUSTERS.size()
		last = k
		# turned a quarter now and then, but the arms always face the camera (south)
		var turn := (rng.randi() % 4) * PI / 2.0
		mat = _cluster(st, CLUSTERS[k], p, turn, rng, mat)
	for p: Vector3 in corners:
		mat = _cluster(st, CORNER, p, rng.randf() * TAU, rng, mat)
	var out := st.commit()
	if out.get_surface_count() > 0 and mat != null:
		out.surface_set_material(0, mat)
	return out


static func _cluster(st: SurfaceTool, pieces: Array, at: Vector3, turn: float, rng: RandomNumberGenerator, mat: Material) -> Material:
	for e in pieces:
		var m := _piece(String(e[0]))
		if m == null:
			continue
		var yaw: float = e[3]
		var faces_camera := String(e[0]).begins_with("sword_shield")
		var spin := 0.0 if faces_camera else turn
		var off := Basis(Vector3.UP, spin) * Vector3(float(e[1]), 0.0, float(e[2]))
		yaw = rng.randf() * TAU if is_nan(yaw) else yaw + rng.randf_range(-0.25, 0.25) + spin
		var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * float(e[4])), at + off)
		for s in m.get_surface_count():
			st.append_from(m, s, xf)
			if mat == null:
				mat = m.surface_get_material(s)
	return mat


static func _piece(name: String) -> ArrayMesh:
	if not _pieces.has(name):
		_pieces[name] = load(DIR + name + ".res") if ResourceLoader.exists(DIR + name + ".res") else null
	return _pieces[name]
