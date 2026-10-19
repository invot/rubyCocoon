extends RefCounted
## Houses from the PS1 House Pack (assets/psx/houses, baked by tools/import_psx_houses.gd): L-plans, porches,
## dormers, round huts, stilt houses and terraces instead of boxes. Each town style has its own pick of houses and its
## own skins (the pack's tiles: weatherboard on the coast, cob and thatch on the islands, adobe in the desert, logs in
## the mountains, dark boarding at the hot springs, stone on the moor...), so a street reads as one place.
##
## plan() fits a house to a plot of the map: the house is scaled to the plot (a little taller than it is wide, so its
## door clears the hero's head), may lean over the hedges and trees beside and behind it (never over a tile anyone can
## walk on), and is slid and mirrored so its front door is on the plot's door tile. A porch reaches out over the street
## in front: plan() measures its deck (and how high its posts reach), and world.gd raises those tiles so people step up
## onto it (see porch()). world.gd keeps trees off the tiles
## a house leans over. build() makes the node; backdrop() a larger house for the outskirts, past the map's edge.
## A house's local origin is the plot's centre at ground level; its front faces +z (as in voxel_buildings.gd).

const VP = preload("res://scripts/gfx/voxel_props.gd")

const DIR := "res://assets/psx/houses/"
const TILES := DIR + "tiles/"
const LOCKED_DOOR := Color("#b3262c")

## The houses each style builds on its plots (small ones: a plot is 4 or 5 tiles wide) and, larger, on its outskirts.
## plan() steers away from the tall narrow ones (townhouse, tower house) unless the style is all towers.
const PLOT_HOUSES := {
	"coastal": ["cape-cod", "i-house", "central-hallway", "gable-front", "side-hall", "row-cottage", "saltbox", "storey-and-half", "double-pen", "tiny-house", "townhouse", "foursquare"],
	"island": ["rondavel", "roundhouse", "stilt-house", "queenslander", "tiny-house", "trullo", "yurt"],
	"adobe": ["trullo", "rondavel", "single-pen", "mews", "tiny-house", "izba", "roundhouse"],
	"western": ["single-pen", "log-cabin", "double-pen", "saddlebag", "tiny-house", "gable-front", "side-hall", "central-hallway", "dacha"],
	"mining": ["log-cabin", "izba", "a-frame", "single-pen", "dacha", "double-pen", "foursquare", "saltbox"],
	"steampunk": ["townhouse", "row-cottage", "tower-house", "mews", "side-hall", "gable-front", "i-house", "foursquare", "central-hallway"],
	"hotspring": ["machiya", "mews", "single-pen", "tiny-house", "izba", "dacha", "central-hallway"],
	"jungle": ["roundhouse", "rondavel", "stilt-house", "queenslander", "tiny-house", "yurt", "trullo"],
	"town": ["hall-parlor", "mews", "storey-and-half", "cape-cod", "gambrel", "hip-dormers", "i-house", "side-hall", "gable-front", "row-cottage", "saltbox", "central-hallway", "foursquare", "dacha"],
	"gothic": ["tower-house", "townhouse", "side-hall", "mews", "gable-front", "georgian-cottage", "saltbox", "foursquare"],
}
const OUTSKIRT_HOUSES := {
	"coastal": ["colonial", "cape-cod", "saltbox", "queen-anne", "foursquare", "eaves-front", "north-shore", "l-plan", "t-plan", "gable-and-wing", "colonial-wing", "charleston-single"],
	"island": ["stilt-house", "queenslander", "longhouse", "roundhouse", "rondavel", "patio-house", "courtyard"],
	"adobe": ["pueblo", "riad", "patio-house", "courtyard", "trullo", "u-plan", "h-plan", "atrium-house", "z-plan"],
	"western": ["ranch", "dogtrot", "barndominium", "log-cabin", "saddlebag", "double-pen", "l-plan", "t-plan", "california-ranch", "z-plan"],
	"mining": ["chalet", "a-frame", "izba", "dacha", "log-cabin", "barndominium", "l-plan-two", "t-plan", "cross-plan"],
	"steampunk": ["mansard", "federal", "maisonette-stack", "terrace", "tower-house", "townhouse", "h-plan", "u-plan", "l-plan-two", "semi-detached"],
	"hotspring": ["machiya", "siheyuan", "longhouse", "mews", "courtyard", "patio-house"],
	"jungle": ["stilt-house", "roundhouse", "longhouse", "queenslander", "rondavel", "courtyard", "patio-house", "pinwheel"],
	"town": ["queen-anne", "gable-and-wing", "manor", "hip-dormers", "villa", "storey-and-half", "l-plan", "cross-plan", "t-plan", "pinwheel", "u-plan"],
	"gothic": ["manor", "mansard", "tower-house", "georgian-house", "palladian", "h-plan", "l-plan-two", "cross-plan"],
}
## Skins: shell (walls), roof, trim (frames), door, extras (steps, decks, chimneys), all tiles of the pack.
const SKINS := {
	"coastal": [["clapboard_white", "asphalt_shingle", "trim_charcoal", "door_green", "stone_step"],
		["clapboard_blue", "slate_grey", "trim_white", "door_dark", "stone_step"],
		["clapboard_green", "shake_wood", "trim_cream", "door_oak", "deck_wood"],
		["weatherboard_pale", "metal_roof", "trim_forest", "door_blue", "deck_wood"],
		["clapboard_ochre", "slate_grey", "trim_white", "door_blue", "stone_step"]],
	"island": [["cob_lime", "thatch_straw", "trim_wood_dark", "door_plank_rough", "deck_wood"],
		["weatherboard_pale", "thatch_straw", "trim_forest", "door_green", "deck_wood"],
		["cladding_timber", "thatch_straw", "trim_wood_dark", "door_oak", "deck_wood"]],
	"adobe": [["adobe_earth", "mud_roof", "trim_wood_dark", "door_plank_rough", "adobe_earth"],
		["render_ochre", "pantile_terracotta", "trim_white", "door_blue", "stone_step"],
		["render_white", "pantile_brown", "trim_navy", "door_blue", "stone_step"]],
	"western": [["log_wall", "shake_wood", "trim_cream", "door_plank_rough", "deck_wood"],
		["cladding_timber", "metal_roof", "trim_wood_dark", "door_dark", "deck_wood"],
		["clapboard_ochre", "metal_roof", "trim_white", "door_oak", "deck_wood"],
		["boarding_dark", "shake_wood", "trim_cream", "door_plank_rough", "deck_wood"]],
	"mining": [["log_wall", "shake_wood", "trim_cream", "door_plank_rough", "stone_step"],
		["metal_rib", "metal_roof", "trim_white", "door_dark", "concrete_step"],
		["boarding_dark", "metal_roof", "trim_cream", "door_oak", "stone_step"]],
	"steampunk": [["brick_red", "slate_grey", "trim_cream", "door_dark", "stone_step"],
		["ashlar_grey", "slate_grey", "trim_charcoal", "door_dark", "stone_step"],
		["brick_buff", "slate_grey", "trim_charcoal", "door_green", "stone_step"],
		["clapboard_grey", "slate_grey", "trim_white", "door_blue", "stone_step"]],
	"hotspring": [["boarding_dark", "tile_grey", "trim_cream", "door_oak", "stone_step"],
		["halftimber_dark", "tile_grey", "trim_white", "door_dark", "stone_step"],
		["render_white", "tile_grey", "trim_wood_dark", "door_oak", "stone_step"]],
	"jungle": [["cob_lime", "thatch_straw", "trim_wood_dark", "door_plank_rough", "deck_wood"],
		["boarding_dark", "thatch_straw", "trim_cream", "door_oak", "deck_wood"],
		["weatherboard_pale", "thatch_straw", "trim_forest", "door_green", "deck_wood"]],
	"town": [["halftimber_dark", "pantile_brown", "trim_white", "door_oak", "stone_step"],
		["batten_cream", "pantile_brown", "trim_forest", "door_green", "stone_step"],
		["stucco_cream", "tile_grey", "trim_navy", "door_blue", "stone_step"],
		["clapboard_green", "shake_wood", "trim_cream", "door_oak", "deck_wood"]],
	"gothic": [["stone_rubble", "slate_grey", "trim_white", "door_dark", "stone_step"],
		["ashlar_grey", "slate_grey", "trim_charcoal", "door_dark", "stone_step"],
		["clapboard_grey", "slate_grey", "trim_charcoal", "door_dark", "stone_step"]],
}
## Houses with a shape of their own (porches, wings, dormers, round walls, stilts, L and T plans, courtyards): picked
## over plain boxes.
const CHARACTER := ["central-hallway", "foursquare", "yurt", "l-plan", "l-plan-two", "t-plan", "cross-plan", "u-plan",
	"h-plan", "z-plan", "pinwheel", "patio-house", "courtyard", "colonial-wing", "charleston-single", "california-ranch",
	"atrium-house", "siheyuan", "cape-cod", "saltbox", "gambrel", "gable-and-wing", "queen-anne", "hip-dormers", "storey-and-half",
	"rondavel", "roundhouse", "trullo", "stilt-house", "queenslander", "a-frame", "chalet", "log-cabin", "dogtrot", "izba",
	"machiya", "mews", "tower-house", "dacha", "eaves-front", "colonial", "pyramidal", "georgian-cottage"]
## Shops (a wider plot, and a shop front added to the house) may also use these.
const SHOP_HOUSES := {
	"coastal": ["eaves-front", "colonial", "gambrel", "hip-dormers"],
	"island": ["queenslander", "stilt-house", "longhouse"],
	"adobe": ["riad", "patio-house", "pueblo"],
	"western": ["dogtrot", "saddlebag", "double-pen"],
	"mining": ["chalet", "dacha", "a-frame"],
	"steampunk": ["mansard", "federal", "georgian-house"],
	"hotspring": ["machiya", "longhouse"],
	"jungle": ["queenslander", "longhouse"],
	"town": ["hip-dormers", "gable-and-wing", "storey-and-half", "gambrel"],
	"gothic": ["georgian-house", "mansard", "georgian-cottage"],
}
## How a house is scaled on a plot: the width it is fitted at, and how much taller than that it stands (its doors
## then clear the hero's head without the house looking stretched).
const PLOT_SCALE := 0.66
const TALL := 1.28
## Fitted to a plot, a house comes out smaller than life next to the people: its ground storey (up to a little above
## the door) is stretched a little taller so the front door stands DOOR_H high, clear of every head; the storeys above
## keep their proportions (see warped()). A house that would need more than WARP_MAX isn't used on that plot.
const DOOR_H := 1.85
const WARP_MAX := 1.3
## the pack's front doors are this tall, and the ground storey ends this far above a door's top
const PACK_DOOR := 2.09
const STOREY_ABOVE_DOOR := 0.4
const OUTSKIRT_SCALE := 0.74

static var _meshes := {}
static var _porches := {}
static var _mats := {}


static func available() -> bool:
	return ResourceLoader.exists(DIR + "cape-cod.res")


static func mesh(key: String) -> ArrayMesh:
	if not _meshes.has(key):
		_meshes[key] = load(DIR + key + ".res") if ResourceLoader.exists(DIR + key + ".res") else null
	return _meshes[key]


## Where the ground storey ends in a house's own space (a little above its front door).
static func ground_top(key: String) -> float:
	var m := mesh(key)
	var door: Vector3 = m.get_meta("door") if m != null and m.has_meta("door") else Vector3(0, PACK_DOOR / 2.0, 0)
	return door.y + PACK_DOOR / 2.0 + STOREY_ABOVE_DOOR


## A height in a house's own space after its ground storey is stretched `r` times (see warped()).
static func warp_y(y: float, g: float, r: float) -> float:
	return y * r if y <= g else g * r + (y - g)


## A house with its ground storey (below `g`) stretched `r` times taller, the rest lifted to sit on it (made once per
## house and stretch).
static func warped(key: String, r: float) -> ArrayMesh:
	var m := mesh(key)
	if m == null or r <= 1.001:
		return m
	var ck := "%s@%.2f" % [key, r]
	if _meshes.has(ck):
		return _meshes[ck]
	var g := ground_top(key)
	var out := ArrayMesh.new()
	for si in m.get_surface_count():
		var arr := m.surface_get_arrays(si)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ns = arr[Mesh.ARRAY_NORMAL]
		for i in vs.size():
			var v := vs[i]
			if v.y <= g and ns != null:
				# the stretch tilts the normals of anything sloped in the ground storey
				var n: Vector3 = ns[i]
				ns[i] = Vector3(n.x, n.y / r, n.z).normalized()
			vs[i] = Vector3(v.x, warp_y(v.y, g, r), v.z)
		arr[Mesh.ARRAY_VERTEX] = vs
		if ns != null:
			arr[Mesh.ARRAY_NORMAL] = ns
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_name(si, m.surface_get_name(si))
		out.surface_set_material(si, m.surface_get_material(si))
	for k in m.get_meta_list():
		out.set_meta(k, m.get_meta(k))
	_meshes[ck] = out
	return out


## The house for a plot. b: the map's building (w, d, door, x, seed); room: how far the house may lean past the plot
## on each side, in tiles, over ground nobody walks on {"left", "right", "back"}.
## Returns {key, skin, scale: Vector3, offset: Vector3, mirror, rect: Rect2 (local, x/z), door_at: Vector3 (the front
## door's centre), door_size: Vector2} or {} if none fits.
static func plan(b: Dictionary, style: String, room: Dictionary, shop := false, used := {}) -> Dictionary:
	var w := float(b["w"])
	var d := float(b["d"])
	var door_lx := float(b["door"].x) + 0.5 - (float(b["x"]) + w / 2.0)
	var left := -w / 2.0 + 0.05 - minf(float(room.get("left", 0.0)), 1.6)
	var right := w / 2.0 - 0.05 + minf(float(room.get("right", 0.0)), 1.6)
	var back := d + minf(float(room.get("back", 0.0)), 2.6) - 0.1
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%d:%d:%d" % [int(b.get("seed", 0)), int(b["x"]), int(b["y"])]).hash()
	var scored := []
	var keys: Array = PLOT_HOUSES.get(style, PLOT_HOUSES["town"]).duplicate()
	if shop:
		keys.append_array(SHOP_HOUSES.get(style, []))
	for key in keys:
		var m := mesh(key)
		if m == null or not m.has_meta("door"):
			continue
		var bb := m.get_aabb()
		var door: Vector3 = m.get_meta("door")
		var behind := door.z - bb.position.z
		# the widest the house can be, given the room either side of the door
		for mirror in [false, true]:
			var dx: float = -door.x if mirror else door.x
			var lo: float = bb.position.x if not mirror else -bb.end.x
			var hi: float = bb.end.x if not mirror else -bb.position.x
			# scale so the door lands on the plot's door tile and both sides fit
			var s := PLOT_SCALE
			if door_lx + (lo - dx) * s < left:
				s = (door_lx - left) / maxf(0.01, dx - lo)
			if door_lx + (hi - dx) * s > right:
				s = minf(s, (right - door_lx) / maxf(0.01, hi - dx))
			if behind * s > back:
				s = minf(s, back / behind)
			if s < 0.4:
				continue
			# too small a house for the people: its door would need its ground storey stretched out of shape
			var stretch := DOOR_H / (PACK_DOOR * minf(s * TALL, 1.0))
			if stretch > WARP_MAX:
				continue
			# how well it fills the plot itself (leaning over the trees is allowed, not wanted), how close to its natural
			# scale it stays, how little its ground storey is stretched, and whether it has a shape of its own
			var fill := (hi - lo) * s / w
			var score := absf(s - PLOT_SCALE) * 2.0 + absf(1.05 - fill) * 0.8 + rng.randf() * 0.35 - (0.35 if key in CHARACTER else 0.0) 				+ maxf(0.0, stretch - 1.0) * 1.5
			# towers of three storeys and more loom over a small square; a house already on this map less welcome
			score += maxf(0.0, bb.size.y * s * TALL - 5.6) * 0.35 + float(used.get(key, 0)) * 0.6
			scored.append({"key": key, "s": s, "mirror": mirror, "dx": dx, "door": door, "bb": bb, "lo": lo, "hi": hi, "score": score})
	if scored.is_empty():
		return {}
	scored.sort_custom(func(a, c): return a["score"] < c["score"])
	var pick: Dictionary = scored[0]
	var sv := float(pick["s"])
	var sy := minf(sv * TALL, 1.0)
	# the ground storey stretched so the door clears every head
	var r := maxf(1.0, DOOR_H / (PACK_DOOR * sy))
	var g := ground_top(String(pick["key"]))
	var skins: Array = SKINS.get(style, SKINS["town"])
	var front := d / 2.0 - 0.06
	var door_v: Vector3 = pick["door"]
	var offset := Vector3(door_lx - float(pick["dx"]) * sv, 0.0, front - door_v.z * sv)
	var mb: AABB = pick["bb"]
	var rect := Rect2(Vector2(offset.x + float(pick["lo"]) * sv, offset.z + mb.position.z * sv), Vector2((float(pick["hi"]) - float(pick["lo"])) * sv, mb.size.z * sv))
	var out := {"key": pick["key"], "skin": skins[rng.randi_range(0, skins.size() - 1)], "scale": Vector3(sv, sy, sv),
		"offset": offset, "mirror": pick["mirror"], "rect": rect,
		"door_at": Vector3(door_lx, warp_y(door_v.y, g, r) * sy, front + 0.02), "door_size": Vector2(0.93 * sv, PACK_DOOR * r * sy), "warp": r}
	# a porch: its deck, in the plot's space, how high it stands, and how high its posts reach
	var pc := porch(String(pick["key"]))
	if not pc.is_empty():
		var r2: Rect2 = pc["rect"]
		var xa := r2.position.x * sv * (-1.0 if pick["mirror"] else 1.0) + offset.x
		var xb := r2.end.x * sv * (-1.0 if pick["mirror"] else 1.0) + offset.x
		out["porch"] = {"rect": Rect2(minf(xa, xb), offset.z + r2.position.y * sv, absf(xb - xa), r2.size.y * sv),
			"y": warp_y(float(pc["y"]), g, r) * sy, "top": warp_y(float(pc["top"]), g, r) * sy}
	return out


## A house's porch, measured from its mesh once (in its own space): the deck in front of the door (rect: x and z; y:
## its top) and how high its posts reach (top). {} if it has none: no deck, or no posts (front steps aren't a porch).
static func porch(key: String) -> Dictionary:
	if _porches.has(key):
		return _porches[key]
	var out := {}
	var m := mesh(key)
	if m != null and m.has_meta("door"):
		var door: Vector3 = m.get_meta("door")
		var deck_y := -1.0
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		var verts := []
		for si in m.get_surface_count():
			var arr := m.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx = arr[Mesh.ARRAY_INDEX]
			if idx == null or (idx as PackedInt32Array).is_empty():
				idx = range(vs.size())
			for t in range(0, idx.size() - 2, 3):
				var a: Vector3 = vs[idx[t]]
				var b: Vector3 = vs[idx[t + 1]]
				var c: Vector3 = vs[idx[t + 2]]
				var mid := (a + b + c) / 3.0
				if mid.z < door.z + 0.05:
					continue
				verts.append(a)
				verts.append(b)
				verts.append(c)
				var nrm := (b - a).cross(c - a).normalized()
				# a floor in front of the door, raised off the ground: the deck (and its steps)
				if absf(nrm.y) > 0.85 and mid.y > 0.08 and mid.y < 1.0:
					deck_y = maxf(deck_y, mid.y)
					for v in [a, b, c]:
						lo = Vector2(minf(lo.x, v.x), minf(lo.y, v.z))
						hi = Vector2(maxf(hi.x, v.x), maxf(hi.y, v.z))
		if deck_y > 0.0 and hi.y - door.z > 0.3:
			# the posts: narrow columns of geometry rising from the deck (anything up at the roof left out)
			var bins := {}
			for v in verts:
				if v.z < door.z + 0.3 or v.y > deck_y + 4.0:
					continue
				var k := roundi(v.x / 0.25)
				var bn: Array = bins.get(k, [INF, -INF])
				bins[k] = [minf(bn[0], v.y), maxf(bn[1], v.y)]
			var tops := []
			for k in bins:
				if float(bins[k][0]) <= deck_y + 0.15 and float(bins[k][1]) >= deck_y + 1.5:
					tops.append(float(bins[k][1]))
			if not tops.is_empty():
				tops.sort()
				out = {"rect": Rect2(lo, hi - lo), "y": deck_y, "top": tops[tops.size() / 2]}
	_porches[key] = out
	return out


## The node for a plan (see plan()). A locked house wears the crimson door every locked door in the game has.
static func build(p: Dictionary, locked := false) -> Node3D:
	var node := Node3D.new()
	var mi := MeshInstance3D.new()
	var m := warped(String(p["key"]), float(p.get("warp", 1.0)))
	mi.mesh = m
	var sc: Vector3 = p["scale"]
	if p.get("mirror", false):
		sc.x = -sc.x
	mi.scale = sc
	mi.position = p["offset"]
	_skin(mi, m, p["skin"], locked)
	node.add_child(mi)
	if p.get("planters", true):
		_planters(node, p)
	return node


## Two wooden planters of flowers either side of the front door.
static func _planters(node: Node3D, p: Dictionary) -> void:
	var door: Vector3 = p["door_at"]
	var ds: Vector2 = p["door_size"]
	var box := BoxMesh.new()
	box.size = Vector3(0.62, 0.24, 0.26)
	if not _mats.has("planter"):
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color("#7a5232")
		wood.roughness = 1.0
		_mats["planter"] = wood
	box.material = _mats["planter"]
	var seed := int(absf(door.x) * 100.0) + int(p["key"].hash())
	# on the porch's deck, if the house has one
	var floor_y := float(p.get("porch", {}).get("y", 0.0))
	for side in [-1.0, 1.0]:
		var x: float = door.x + side * (ds.x / 2.0 + 0.48)
		var b := MeshInstance3D.new()
		b.mesh = box
		b.position = Vector3(x, floor_y + 0.12, door.z + 0.16)
		node.add_child(b)
		var f := MeshInstance3D.new()
		f.mesh = VP.flowers(posmod(seed + int(side), 4))
		f.scale = Vector3(0.6, 0.9, 0.24)
		f.position = Vector3(x, floor_y + 0.24, door.z + 0.16)
		node.add_child(f)


## A larger house for the outskirts (past the edge of a town map, behind its hedges): no plot to fit, so it keeps its
## own proportions. Returns the node and its footprint radius.
static func backdrop(style: String, rng: RandomNumberGenerator) -> Array:
	var keys: Array = OUTSKIRT_HOUSES.get(style, OUTSKIRT_HOUSES["town"])
	var key: String = keys[rng.randi_range(0, keys.size() - 1)]
	var m := mesh(key)
	if m == null:
		return [null, 0.0]
	var skins: Array = SKINS.get(style, SKINS["town"])
	var node := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = m
	var s := OUTSKIRT_SCALE * rng.randf_range(0.9, 1.05)
	mi.scale = Vector3(s, s * 1.08, s)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_skin(mi, m, skins[rng.randi_range(0, skins.size() - 1)], false)
	node.add_child(mi)
	var bb := m.get_aabb()
	return [node, maxf(bb.size.x, bb.size.z) * s * 0.5]


static func _skin(mi: MeshInstance3D, m: ArrayMesh, skin: Array, locked: bool) -> void:
	var parts := {"shell": skin[0], "roof": skin[1], "trim": skin[2], "door": skin[3], "extras": skin[4]}
	for s in m.get_surface_count():
		var base := m.surface_get_material(s) as StandardMaterial3D
		var role := String(base.resource_name)
		if not parts.has(role):
			continue
		var tile := String(parts[role])
		# a log house keeps logs for its "extras" (chimney) only if it has no step tile of its own
		var key := "%s:%s:%s" % [role, tile, "locked" if locked and role == "door" else ""]
		if not _mats.has(key):
			var mat: StandardMaterial3D = base.duplicate()
			if ResourceLoader.exists(TILES + tile + ".res"):
				mat.albedo_texture = load(TILES + tile + ".res")
			if locked and role == "door":
				mat.albedo_texture = load(TILES + "door_dark.res") if ResourceLoader.exists(TILES + "door_dark.res") else mat.albedo_texture
				mat.albedo_color = LOCKED_DOOR.lightened(0.35)
			_mats[key] = mat
		mi.set_surface_override_material(s, _mats[key])
