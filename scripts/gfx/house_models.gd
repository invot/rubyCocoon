extends RefCounted
## Houses from the PS1 House Pack (assets/houses, baked by tools/import_psx_houses.gd): L-plans, porches,
## dormers, round huts, stilt houses and terraces instead of boxes. Each town style has its own pick of houses and its
## own skins (the pack's tiles: weatherboard on the coast, cob and thatch on the islands, adobe in the desert, logs in
## the mountains, dark boarding at the hot springs, stone on the moor...), so a street reads as one place.
##
## plan() fits a house to a plot of the map: the house is scaled to the plot (a little taller than it is wide, so its
## door clears the hero's head), may lean over the hedges and trees beside and behind it (never over a tile anyone can
## walk on), and is slid and mirrored so its front door is on the plot's door tile. A porch's deck or a stoop in front
## of the door: plan() measures it (and how high a porch's posts reach) and lowers it to one easy step at the door's
## sill (MAX_STEP, see steps() and warped()); the house is set back on its plot by its depth, so the porch or the steps
## end where the plot does and never stand out over the path in front (world.gd raises any walkable tiles a deck still
## covers, so people step up onto it). Every porch has a roof on the tops of its posts (the pack's own, or
## porch_roof()'s).
## world.gd keeps trees off the tiles a house leans over. build() makes the node; backdrop() a larger house for the outskirts, past the map's edge.
## A house's local origin is the plot's centre at ground level; its front faces +z (as in voxel_buildings.gd).

const VP = preload("res://scripts/gfx/voxel_props.gd")

const DIR := "res://assets/houses/"
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
	# Youngster Kit's cabin on the Coastal Path
	"cabin": ["log-cabin", "single-pen", "a-frame"],
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
	"cabin": [["log_wall", "shake_wood", "trim_cream", "door_plank_rough", "deck_wood"]],
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
const DOOR_H := 1.8
const WARP_MAX := 1.3
## Fitted to a plot (narrower than it is tall), the pack's own front door comes out tall and thin: each house is given
## a front door of ordinary proportions instead (height to width), a little wider, set over the pack's (see
## _front_door).
const DOOR_ASPECT := 2.15
## the pack's front doors are this tall, and the ground storey ends this far above a door's top
const PACK_DOOR := 2.09
const STOREY_ABOVE_DOOR := 0.4
## A porch's deck or a stoop in front of the door is never more than one easy step up (in the world's units): a
## deeper one is squashed down to the door's sill, its posts reaching down to meet it (see warped()).
const MAX_STEP := 0.25
## A house set back behind its porch or front steps may lean back over the trees as far as there's room (not just 2.6 tiles), and
## if its plot is still too shallow, it's made shallower, front to back, down to this much of its scale across, before
## it's made any smaller (so a porch house still fits a plot of three rows).
const DEPTH_MIN := 0.85
const OUTSKIRT_SCALE := 0.74

## A porch roof (porch_roof()): the beam along the posts' tops, how thick the roof on it is, how far it reaches past
## the outermost posts, and the most it rises from the beam to the wall behind.
const PORCH_BEAM := 0.14
const PORCH_ROOF := 0.08
const PORCH_EAVE := 0.25
const PORCH_RISE := 0.45

static var _meshes := {}
static var _dressed := {}
static var _porches := {}
static var _porch_roofs := {}
static var _steps := {}
static var _mats := {}
static var _tile_cols := {}


static func available() -> bool:
	return ResourceLoader.exists(DIR + "cape-cod.res")


static func mesh(key: String) -> ArrayMesh:
	if not _meshes.has(key):
		_meshes[key] = load(DIR + key + ".res") if ResourceLoader.exists(DIR + key + ".res") else null
		if _meshes[key] == null:
			push_warning("model missing: " + DIR + key + ".res")
	return _meshes[key]


## Where the ground storey ends in a house's own space (a little above its front door).
static func ground_top(key: String) -> float:
	var m := mesh(key)
	var door: Vector3 = m.get_meta("door") if m != null and m.has_meta("door") else Vector3(0, PACK_DOOR / 2.0, 0)
	return door.y + PACK_DOOR / 2.0 + STOREY_ABOVE_DOOR


## A height in a house's own space after its ground storey is stretched `r` times (see warped()).
static func warp_y(y: float, g: float, r: float) -> float:
	return y * r if y <= g else g * r + (y - g)


## A house with its ground storey (below `g`) stretched `r` times taller, the rest lifted to sit on it, and its porch
## deck or stoop squashed down to `step` (in its own space, before the stretch) if it stands higher: anything on the
## deck up to its posts' tops (railings, the posts themselves) stretches to meet it, so the porch roof stays put
## (made once per house, stretch, step and porch roof). The house as dressed() makes it: its own door gone (build()
## puts one over the doorway), and a roof over its porch unless `roofed` is false.
static func warped(key: String, r: float, step := INF, roofed := true) -> ArrayMesh:
	var m := dressed(key, false, roofed)
	var st := steps(key)
	var squash: bool = not st.is_empty() and step < float(st["y"]) - 0.01
	if m == null or (r <= 1.001 and not squash):
		return m
	var ck := "%s@%.2f@%.2f@%s" % [key, r, step if squash else -1.0, roofed]
	if _meshes.has(ck):
		return _meshes[ck]
	var g := ground_top(key)
	var area: Rect2 = st.get("rect", Rect2()).grow(0.02)
	var deck := float(st.get("y", 0.0))
	var posts := maxf(float(porch(key).get("top", deck)), deck)
	var door_z := float((m.get_meta("door") as Vector3).z)
	var out := ArrayMesh.new()
	for si in m.get_surface_count():
		var arr := m.surface_get_arrays(si)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ns = arr[Mesh.ARRAY_NORMAL]
		for i in vs.size():
			var v := vs[i]
			if squash and v.z > door_z + 0.05 and v.y <= posts + 0.01 and area.has_point(Vector2(v.x, v.z)):
				v.y = v.y * step / deck if v.y <= deck else step + (v.y - deck) * (posts - step) / maxf(0.01, posts - deck)
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
## on each side, in tiles, over ground nobody walks on {"left", "right", "back"}; max_h: how tall it may stand (a house
## with a street not far behind it is kept low, so it never hides anyone walking there from the camera).
## Returns {key, skin, scale: Vector3, offset: Vector3, mirror, rect: Rect2 (local, x/z), door_at: Vector3 (the front
## door's centre), door_size: Vector2} or {} if none fits.
static func plan(b: Dictionary, style: String, room: Dictionary, shop := false, used := {}, max_h := INF) -> Dictionary:
	var w := float(b["w"])
	var d := float(b["d"])
	var door_lx := float(b["door"].x) + 0.5 - (float(b["x"]) + w / 2.0)
	var left := -w / 2.0 + 0.05 - minf(float(room.get("left", 0.0)), 1.6)
	var right := w / 2.0 - 0.05 + minf(float(room.get("right", 0.0)), 1.6)
	var back := d + minf(float(room.get("back", 0.0)), 2.6) - 0.1
	var back_set := d + float(room.get("back", 0.0)) - 0.1
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
		# a house with a porch or front steps stands back by their depth, its door that far inside the plot
		var ahead := front_depth(key)
		var behind := door.z - bb.position.z + ahead
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
			var depth_min := DEPTH_MIN if ahead > 0.0 else 1.0
			var deep := back_set if ahead > 0.0 else back
			if behind * s * depth_min > deep:
				s = deep / (behind * depth_min)
			# (front to back)
			var sz := minf(s, deep / behind)
			if s < 0.4:
				continue
			# too small a house for the people: its door would need its ground storey stretched out of shape
			var stretch := DOOR_H / (PACK_DOOR * minf(s * TALL, 1.0))
			if stretch > WARP_MAX:
				continue
			if warp_y(bb.end.y, ground_top(key), maxf(1.0, stretch)) * minf(s * TALL, 1.0) > max_h:
				continue
			# how well it fills the plot itself (leaning over the trees is allowed, not wanted), how close to its natural
			# scale it stays, how little its ground storey is stretched, and whether it has a shape of its own
			var fill := (hi - lo) * s / w
			var score := absf(s - PLOT_SCALE) * 2.0 + absf(1.05 - fill) * 0.8 + rng.randf() * 0.35 - (0.35 if key in CHARACTER else 0.0) 				+ maxf(0.0, stretch - 1.0) * 1.5
			if key == b.get("house_model", ""):
				score -= 10.0
			# towers of three storeys and more loom over a small square; a house already on this map less welcome
			score += maxf(0.0, bb.size.y * s * TALL - 5.6) * 0.35 + float(used.get(key, 0)) * 0.6
			scored.append({"key": key, "s": s, "mirror": mirror, "dx": dx, "door": door, "bb": bb, "lo": lo, "hi": hi, "ahead": ahead, "sz": sz, "score": score})
	if scored.is_empty():
		return {}
	scored.sort_custom(func(a, c): return a["score"] < c["score"])
	var pick: Dictionary = scored[0]
	var sv := float(pick["s"])
	var sy := minf(sv * TALL, 1.0)
	var sz := float(pick["sz"])
	# the ground storey stretched so the door clears every head
	var r := maxf(1.0, DOOR_H / (PACK_DOOR * sy))
	var g := ground_top(String(pick["key"]))
	var skins: Array = SKINS.get(style, SKINS["town"])
	var skin_index := int(b.get("house_skin", rng.randi_range(0, skins.size() - 1)))
	# the front door on the plot's front edge, or set back behind a porch or steps so they end there
	var front := d / 2.0 - 0.06 - float(pick["ahead"]) * sz
	var door_v: Vector3 = pick["door"]
	var offset := Vector3(door_lx - float(pick["dx"]) * sv, 0.0, front - door_v.z * sz)
	var mb: AABB = pick["bb"]
	var rect := Rect2(Vector2(offset.x + float(pick["lo"]) * sv, offset.z + mb.position.z * sz), Vector2((float(pick["hi"]) - float(pick["lo"])) * sv, mb.size.z * sz))
	# the pack's doorway once fitted, and the house's own door over it: standing on the same sill, just taller than the
	# doorway and as wide as an ordinary door that tall (door_at / door_size are the new door's)
	var hole := Vector2(0.93 * sv, PACK_DOOR * r * sy)
	var hole_y := warp_y(door_v.y, g, r) * sy
	var dh := maxf(hole.y + 0.05, DOOR_H)
	var dw := maxf(dh / DOOR_ASPECT, hole.x + 0.12)
	var out := {"key": pick["key"], "skin": skins[clampi(skin_index, 0, skins.size() - 1)], "scale": Vector3(sv, sy, sz),
		"offset": offset, "mirror": pick["mirror"], "rect": rect,
		"door_at": Vector3(door_lx, hole_y - hole.y / 2.0 + dh / 2.0, front + 0.02), "door_size": Vector2(dw, dh), "warp": r}
	# a deck or stoop in front of the door: in the plot's space, how high it stands (one easy step at most, level with
	# the door's sill), and for a porch how high its posts reach
	var st := steps(String(pick["key"]))
	if not st.is_empty():
		var sill := clampf(warp_y(door_v.y - PACK_DOOR / 2.0, g, r) * sy, 0.1, MAX_STEP)
		var deck_y := minf(warp_y(float(st["y"]), g, r) * sy, sill)
		# the same height in the house's own space, before the stretch (see warped())
		out["step"] = deck_y / (r * sy)
		out["steps"] = {"rect": _plot_rect(st["rect"], Vector2(sv, sz), offset, pick["mirror"]), "y": deck_y}
		var pc := porch(String(pick["key"]))
		if not pc.is_empty():
			out["porch"] = {"rect": _plot_rect(pc["rect"], Vector2(sv, sz), offset, pick["mirror"]), "y": deck_y, "top": warp_y(float(pc["top"]), g, r) * sy}
	return out


## A rect (x and z) in a house's own space -> the plot's, as plan() places the house (sc: its scale across and front
## to back).
static func _plot_rect(r2: Rect2, sc: Vector2, offset: Vector3, mirror: bool) -> Rect2:
	var xa := r2.position.x * sc.x * (-1.0 if mirror else 1.0) + offset.x
	var xb := r2.end.x * sc.x * (-1.0 if mirror else 1.0) + offset.x
	return Rect2(minf(xa, xb), offset.z + r2.position.y * sc.y, absf(xb - xa), r2.size.y * sc.y)


## The deck or stoop in front of a house's front door, measured from its mesh once (in its own space): the floors
## raised off the ground that reach well out from the door (not the sills, plinths and thresholds along the wall),
## with rect (x and z) and y (the top of the highest). {} if it has none.
static func steps(key: String) -> Dictionary:
	if _steps.has(key):
		return _steps[key]
	var out := {}
	var m := mesh(key)
	if m != null and m.has_meta("door"):
		var door: Vector3 = m.get_meta("door")
		var top := -1.0
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
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
				var nrm := (b - a).cross(c - a).normalized()
				if absf(nrm.y) < 0.85 or mid.y < 0.08 or mid.y > 1.6 or mid.z < door.z + 0.05:
					continue
				if maxf(a.z, maxf(b.z, c.z)) < door.z + 0.45:
					continue
				top = maxf(top, mid.y)
				for v in [a, b, c]:
					lo = Vector2(minf(lo.x, v.x), minf(lo.y, v.z))
					hi = Vector2(maxf(hi.x, v.x), maxf(hi.y, v.z))
		if top > 0.0:
			out = {"rect": Rect2(lo, hi - lo), "y": top}
	_steps[key] = out
	return out


## A house's porch, measured from its mesh once (in its own space): the deck in front of the door (rect: x and z; y:
## its top) and how high its posts reach (top). {} if it has none: no deck, or no posts (front steps aren't a porch;
## see steps() for those).
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


## How far a house's porch (its deck, its roof) or its front steps reach out in front of its front door, in its own
## space (0 if it has neither): plan() sets the house back that far.
static func front_depth(key: String) -> float:
	var st := steps(key)
	if st.is_empty():
		return 0.0
	var front := (st["rect"] as Rect2).end.y
	var pr := porch_roof(key)
	if not pr.is_empty():
		front = maxf(front, float(pr["front"]))
	return maxf(0.0, front - float((mesh(key).get_meta("door") as Vector3).z))


## The roof a porch needs when the pack left its posts bare (measured once, in the house's own space): a beam along
## the tops of the posts and on it a roof sloping gently up to the wall behind, as high as it can go there without
## covering a window or the trim over the door. {x0, x1: its ends; back: the wall; post_z: the posts' line; front: the
## deck's front edge; top: the posts' tops; rise} or {} for a house with no porch, or a porch already under a roof (the
## pack's own, or the storey above it).
static func porch_roof(key: String) -> Dictionary:
	if _porch_roofs.has(key):
		return _porch_roofs[key]
	var out := {}
	var m := mesh(key)
	var pc := porch(key)
	var st := steps(key)
	if m != null and not pc.is_empty() and not st.is_empty():
		var door: Vector3 = m.get_meta("door")
		var deck: Rect2 = st["rect"]
		var deck_y := float(st["y"])
		var top := float(pc["top"])
		var tris := _triangles(m)
		# the posts: tall narrow columns rising from the deck, out in front of the door
		var cols := {}
		for t in tris:
			if t[0] in ["shell", "inside", "glass", "roof", "door"]:
				continue
			for v in [t[1], t[2], t[3]]:
				if v.z < door.z + 0.3 or not deck.grow(0.1).has_point(Vector2(v.x, v.z)):
					continue
				var k := Vector2i(roundi(v.x / 0.3), roundi(v.z / 0.3))
				var c: Array = cols.get(k, [INF, -INF, Vector2.ZERO, 0])
				cols[k] = [minf(c[0], v.y), maxf(c[1], v.y), c[2] + Vector2(v.x, v.z), c[3] + 1]
		var posts := []
		for k in cols:
			var c: Array = cols[k]
			if float(c[0]) <= deck_y + 0.2 and float(c[1]) >= deck_y + 1.5:
				posts.append(c[2] / float(c[3]))
		# already under cover: something just over most of the posts' tops
		var covered := 0
		for p in posts:
			for t in tris:
				var low := minf(t[1].y, minf(t[2].y, t[3].y))
				if t[0] == "glass" or low < top - 0.3 or low > top + 1.2:
					continue
				if Geometry2D.point_is_inside_triangle(p, Vector2(t[1].x, t[1].z), Vector2(t[2].x, t[2].z), Vector2(t[3].x, t[3].z)):
					covered += 1
					break
		if not posts.is_empty() and covered * 2 < posts.size():
			var x0 := INF
			var x1 := -INF
			var post_z := -INF
			for p in posts:
				x0 = minf(x0, p.x)
				x1 = maxf(x1, p.x)
				post_z = maxf(post_z, p.y)
			x0 -= PORCH_EAVE
			x1 += PORCH_EAVE
			# the wall behind the porch: the front-most stretch of wall facing the street there, at the posts' height
			var back := door.z + 0.1
			var found := false
			for t in tris:
				if t[0] != "shell":
					continue
				var a: Vector3 = t[1]
				var n: Vector3 = (t[2] - a).cross(t[3] - a).normalized()
				var mid: Vector3 = (a + t[2] + t[3]) / 3.0
				var lo_y := minf(a.y, minf(t[2].y, t[3].y))
				var hi_y := maxf(a.y, maxf(t[2].y, t[3].y))
				if absf(n.z) < 0.9 or not _spans(t, x0, x1) or mid.z > post_z - 0.3 or lo_y > top + 0.2 or hi_y < top + 0.4:
					continue
				back = mid.z if not found else maxf(back, mid.z)
				found = true
			# up to the wall, but under its windows and the trim over the door
			var under := INF
			for t in tris:
				if t[0] in ["shell", "inside", "roof"]:
					continue
				var mid: Vector3 = (t[1] + t[2] + t[3]) / 3.0
				var low := minf(t[1].y, minf(t[2].y, t[3].y))
				if not _spans(t, x0, x1) or mid.z < back - 0.1 or mid.z > back + 0.6 or low < top + 0.05:
					continue
				under = minf(under, low)
			var rise := clampf(under - 0.1 - (top + PORCH_BEAM + PORCH_ROOF), 0.0, PORCH_RISE)
			out = {"x0": x0, "x1": x1, "back": back, "post_z": post_z, "front": maxf(deck.end.y, post_z + 0.15), "top": top, "rise": rise}
	_porch_roofs[key] = out
	return out


## True if triangle t ([part, a, b, c]) reaches across any of x0..x1.
static func _spans(t: Array, x0: float, x1: float) -> bool:
	return maxf(t[1].x, maxf(t[2].x, t[3].x)) > x0 and minf(t[1].x, minf(t[2].x, t[3].x)) < x1


## A mesh's triangles: [part, a, b, c] for each.
static func _triangles(m: ArrayMesh) -> Array:
	var out := []
	for si in m.get_surface_count():
		var role := String((m.surface_get_material(si) as StandardMaterial3D).resource_name)
		var arr := m.surface_get_arrays(si)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx = arr[Mesh.ARRAY_INDEX]
		if idx == null or (idx as PackedInt32Array).is_empty():
			idx = range(vs.size())
		for t in range(0, idx.size() - 2, 3):
			out.append([role, vs[idx[t]], vs[idx[t + 1]], vs[idx[t + 2]]])
	return out


## A house as the game shows it (made once per house and options): the pack's mesh with a roof over a porch the pack
## left open (porch_roof(); not for a shop, whose awning is its porch's roof), and without the pack's own front door
## and the frame round it, which stands proud of the wall and showed as a thin door inside the house's own (build()
## puts that over the doorway). keep_door: a house seen from afar, which gets no door of its own.
static func dressed(key: String, keep_door := false, roofed := true) -> ArrayMesh:
	var ck := "%s|%s|%s" % [key, keep_door, roofed]
	if _dressed.has(ck):
		return _dressed[ck]
	var m := mesh(key)
	var pr := porch_roof(key) if roofed else {}
	if m == null or not m.has_meta("door") or (keep_door and pr.is_empty()):
		_dressed[ck] = m
		return m
	var door: Vector3 = m.get_meta("door")
	var out := ArrayMesh.new()
	var mats := {}
	for si in m.get_surface_count():
		var arr := m.surface_get_arrays(si)
		var mat := m.surface_get_material(si)
		mats[String(mat.resource_name)] = mat
		if not keep_door and String(mat.resource_name) in ["door", "trim"]:
			arr = _without_door(arr, door)
			if (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).is_empty():
				continue
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_name(out.get_surface_count() - 1, m.surface_get_name(si))
		out.surface_set_material(out.get_surface_count() - 1, mat)
	if not pr.is_empty():
		_add_porch_roof(out, pr, mats)
	for k in m.get_meta_list():
		out.set_meta(k, m.get_meta(k))
	_dressed[ck] = out
	return out


## A surface's arrays without the triangles of the front door and its frame (every one lying wholly in the doorway
## and the frame round it: the pack's doors are 0.94 wide, their frames 1.2, standing up to 0.36 off the wall).
static func _without_door(arr: Array, door: Vector3) -> Array:
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx = arr[Mesh.ARRAY_INDEX]
	if idx == null or (idx as PackedInt32Array).is_empty():
		idx = PackedInt32Array(range(vs.size()))
	var keep := PackedInt32Array()
	for t in range(0, idx.size() - 2, 3):
		var near := true
		for j in 3:
			var dv: Vector3 = vs[idx[t + j]] - door
			if absf(dv.x) > 0.9 or dv.y < -1.25 or dv.y > 1.3 or dv.z < -0.45 or dv.z > 0.5:
				near = false
				break
		if not near:
			keep.append_array([idx[t], idx[t + 1], idx[t + 2]])
	arr[Mesh.ARRAY_INDEX] = keep
	return arr


## A porch roof (see porch_roof()) as two more surfaces of a house's mesh, in its roof and its trim: the beam lying on
## the posts' tops, and on it the roof, from the wall out to the deck's front edge.
static func _add_porch_roof(out: ArrayMesh, pr: Dictionary, mats: Dictionary) -> void:
	var x0 := float(pr["x0"])
	var x1 := float(pr["x1"])
	var back := float(pr["back"])
	var pz := float(pr["post_z"])
	var front := float(pr["front"])
	var y := float(pr["top"]) + PORCH_BEAM
	var k := float(pr["rise"]) / maxf(0.01, pz - back)
	# the roof's underside: on the beam at the posts' line, rising to the wall
	var yb := y + k * (pz - back)
	var yf := y - k * (front - pz)
	var t := PORCH_ROOF
	var roof := [[], [], []]
	var trim := [[], [], []]
	var slope := Vector3(0, front - back, yb - yf).normalized()
	var run := Vector2(front - back, yb - yf).length()
	_quad(roof, [Vector3(x0, yb + t, back), Vector3(x1, yb + t, back), Vector3(x1, yf + t, front), Vector3(x0, yf + t, front)], slope,
		[Vector2(x0, 0), Vector2(x1, 0), Vector2(x1, run), Vector2(x0, run)], 0.63)
	_quad(trim, [Vector3(x0, yb, back), Vector3(x1, yb, back), Vector3(x1, yf, front), Vector3(x0, yf, front)], -slope,
		[Vector2(x0, back), Vector2(x1, back), Vector2(x1, front), Vector2(x0, front)], 1.67)
	_quad(trim, [Vector3(x0, yf, front), Vector3(x1, yf, front), Vector3(x1, yf + t, front), Vector3(x0, yf + t, front)], Vector3.BACK,
		[Vector2(x0, yf), Vector2(x1, yf), Vector2(x1, yf + t), Vector2(x0, yf + t)], 1.67)
	for sx in [x0, x1]:
		_quad(trim, [Vector3(sx, yb, back), Vector3(sx, yf, front), Vector3(sx, yf + t, front), Vector3(sx, yb + t, back)], Vector3(signf(sx - (x0 + x1) / 2.0), 0, 0),
			[Vector2(back, yb), Vector2(front, yf), Vector2(front, yf + t), Vector2(back, yb + t)], 1.67)
	# the beam, its underside on the posts' tops (its top under the roof)
	var b0 := Vector3(x0 + 0.08, y - PORCH_BEAM, pz - 0.1)
	var b1 := Vector3(x1 - 0.08, y, pz + 0.1)
	_quad(trim, [Vector3(b0.x, b0.y, b1.z), Vector3(b1.x, b0.y, b1.z), Vector3(b1.x, b1.y, b1.z), Vector3(b0.x, b1.y, b1.z)], Vector3.BACK,
		[Vector2(b0.x, b0.y), Vector2(b1.x, b0.y), Vector2(b1.x, b1.y), Vector2(b0.x, b1.y)], 1.67)
	_quad(trim, [Vector3(b0.x, b0.y, b0.z), Vector3(b1.x, b0.y, b0.z), Vector3(b1.x, b0.y, b1.z), Vector3(b0.x, b0.y, b1.z)], Vector3.DOWN,
		[Vector2(b0.x, b0.z), Vector2(b1.x, b0.z), Vector2(b1.x, b1.z), Vector2(b0.x, b1.z)], 1.67)
	_quad(trim, [Vector3(b0.x, b0.y, b0.z), Vector3(b1.x, b0.y, b0.z), Vector3(b1.x, b1.y, b0.z), Vector3(b0.x, b1.y, b0.z)], Vector3.FORWARD,
		[Vector2(b0.x, b0.y), Vector2(b1.x, b0.y), Vector2(b1.x, b1.y), Vector2(b0.x, b1.y)], 1.67)
	for sx in [b0.x, b1.x]:
		_quad(trim, [Vector3(sx, b0.y, b0.z), Vector3(sx, b0.y, b1.z), Vector3(sx, b1.y, b1.z), Vector3(sx, b1.y, b0.z)], Vector3(signf(sx - (x0 + x1) / 2.0), 0, 0),
			[Vector2(b0.z, b0.y), Vector2(b1.z, b0.y), Vector2(b1.z, b1.y), Vector2(b0.z, b1.y)], 1.67)
	for part in [["roof", roof], ["trim", trim]]:
		if not mats.has(part[0]):
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = PackedVector3Array(part[1][0])
		arr[Mesh.ARRAY_NORMAL] = PackedVector3Array(part[1][1])
		arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array(part[1][2])
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_name(out.get_surface_count() - 1, "porch_" + String(part[0]))
		out.surface_set_material(out.get_surface_count() - 1, mats[part[0]])


## A quad (four corners in order round it) facing `n`, as two triangles wound the way Godot draws their front, into
## [vertices, normals, uvs]; uv: each corner's place in the texture, in metres, times `scale` (the pack's tiles repeat
## about this often per metre).
static func _quad(into: Array, c: Array, n: Vector3, uv: Array, scale: float) -> void:
	for tri in [[0, 1, 2], [0, 2, 3]]:
		var a: Vector3 = c[tri[0]]
		var b: Vector3 = c[tri[1]]
		var d: Vector3 = c[tri[2]]
		var order: Array = tri if (b - a).cross(d - a).dot(n) < 0.0 else [tri[0], tri[2], tri[1]]
		for i in order:
			into[0].append(c[i])
			into[1].append(n)
			into[2].append(uv[i] * scale)


## The node for a plan (see plan()). A locked house wears the crimson door every locked door in the game has.
static func build(p: Dictionary, locked := false) -> Node3D:
	var node := Node3D.new()
	var mi := MeshInstance3D.new()
	var m := warped(String(p["key"]), float(p.get("warp", 1.0)), float(p.get("step", INF)), p.get("porch_roof", true))
	mi.mesh = m
	var sc: Vector3 = p["scale"]
	if p.get("mirror", false):
		sc.x = -sc.x
	mi.scale = sc
	mi.position = p["offset"]
	_skin(mi, m, p["skin"], locked)
	node.add_child(mi)
	# (the door's tile: from the pack's mesh, as the dressed one has no door left)
	_front_door(node, p, mesh(String(p["key"])), locked)
	if p.get("planters", true):
		_planters(node, p)
	return node


## The house's front door (see DOOR_ASPECT): a frame in the colour of its trim, and the door itself in its door tile
## (crimson when locked, as every locked door is), standing just proud of the wall over the pack's narrow doorway
## (its own door and frame taken away, see dressed()). m: the pack's mesh, for the door's tile.
static func _front_door(node: Node3D, p: Dictionary, m: ArrayMesh, locked: bool) -> void:
	var c: Vector3 = p["door_at"]
	var ds: Vector2 = p["door_size"]
	var skin: Array = p["skin"]
	var frame := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(ds.x + 0.16, ds.y + 0.08, 0.06)
	var trim := "trim:" + String(skin[2])
	if not _mats.has(trim):
		var fm := StandardMaterial3D.new()
		fm.albedo_color = _tile_colour(String(skin[2]))
		fm.roughness = 0.9
		_mats[trim] = fm
	fb.material = _mats[trim]
	frame.mesh = fb
	frame.position = Vector3(c.x, c.y + 0.04, c.z + 0.02)
	node.add_child(frame)
	var leaf := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = ds
	for s in m.get_surface_count():
		var base := m.surface_get_material(s) as StandardMaterial3D
		if base != null and String(base.resource_name) == "door":
			q.material = _part_mat(base, "door", String(skin[3]), locked)
			break
	leaf.mesh = q
	leaf.position = Vector3(c.x, c.y, c.z + 0.06)
	node.add_child(leaf)
	# a brass knob on a plate, at hand height by the far edge (the pack's door tiles have none; a locked door's padlock
	# hangs there instead, see voxel_buildings.gd _door_lock)
	if not locked:
		if not _mats.has("brass"):
			var bm := StandardMaterial3D.new()
			bm.albedo_color = Color("#d8b050")
			bm.metallic = 0.6
			bm.roughness = 0.35
			_mats["brass"] = bm
		var at := Vector3(c.x + ds.x * 0.34, c.y - ds.y / 2.0 + 0.95, c.z + 0.06)
		for part in [[Vector3(0.06, 0.16, 0.02), 0.01], [Vector3(0.08, 0.08, 0.06), 0.03]]:
			var kb := BoxMesh.new()
			kb.size = part[0]
			kb.material = _mats["brass"]
			var knob := MeshInstance3D.new()
			knob.mesh = kb
			knob.position = at + Vector3(0, 0, float(part[1]))
			node.add_child(knob)


## A tile's average colour (the trim round a door is drawn plain, in its trim's colour).
static func _tile_colour(tile: String) -> Color:
	if _tile_cols.has(tile):
		return _tile_cols[tile]
	var col := Color("#e8e4dc")
	if ResourceLoader.exists(TILES + tile + ".res"):
		var img := (load(TILES + tile + ".res") as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		img.resize(4, 4, Image.INTERPOLATE_BILINEAR)
		var sum := Color(0, 0, 0, 0)
		for y in 4:
			for x in 4:
				sum += img.get_pixel(x, y)
		col = Color(sum.r / 16.0, sum.g / 16.0, sum.b / 16.0)
	_tile_cols[tile] = col
	return col


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
	var st: Dictionary = p.get("steps", {})
	for side in [-1.0, 1.0]:
		var x: float = door.x + side * (ds.x / 2.0 + 0.48)
		# on the porch's deck or the stoop, if the house has one there
		var floor_y := 0.0
		if not st.is_empty() and x > (st["rect"] as Rect2).position.x and x < (st["rect"] as Rect2).end.x:
			floor_y = float(st["y"])
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
	m = dressed(key, true)
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
		mi.set_surface_override_material(s, _part_mat(base, role, String(parts[role]), locked))


## A part of a house in one of the pack's tiles (made once per part, tile and lock).
static func _part_mat(base: StandardMaterial3D, role: String, tile: String, locked: bool) -> StandardMaterial3D:
	var key := "%s:%s:%s" % [role, tile, "locked" if locked and role == "door" else ""]
	if not _mats.has(key):
		var mat: StandardMaterial3D = base.duplicate()
		if ResourceLoader.exists(TILES + tile + ".res"):
			mat.albedo_texture = load(TILES + tile + ".res")
		if locked and role == "door":
			mat.albedo_texture = load(TILES + "door_dark.res") if ResourceLoader.exists(TILES + "door_dark.res") else mat.albedo_texture
			mat.albedo_color = LOCKED_DOOR.lightened(0.35)
		_mats[key] = mat
	return _mats[key]
