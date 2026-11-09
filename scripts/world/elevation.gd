extends RefCounted
## Cliffs and ramps on the outdoor maps. A map's optional "heights" rows (scripts/data/maps/) give each tile a level,
## one character per tile, lined up with its "rows":
##   0-9       the ground's level there, LEVEL_H units per level (missing characters count as 0)
##   ^ v < >   a ramp rising that way (^ is north, up the map). A run of them in a line climbs evenly from the level
##             of the tile just before the run to the level of the tile just after it; runs side by side make a wide
##             ramp. Both ends must be levels (digits).
##   / \       a cliff running diagonally across the tile, corner to corner ("/" from its bottom-left corner to its
##             top-right one, "\" from top-left to bottom-right; "\\" in a GDScript string). Each half of the tile is on
##             the level of the neighbours along its two sides: "/" splits it into a north-west and a south-east half,
##             "\" into a north-east and a south-west one. Nobody can walk on one; tools/cliff_corners.gd cuts a map's
##             cliff corners this way.
## Neighbouring tiles at different levels meet at a cliff nobody can climb (terrain_mesh.gd draws its rock face); a
## ramp is walked up and down only along its slope, and its sides are cliffs too. Maps without "heights" are flat.
## Everything stands on its tile's height: see world.gd tile_pos.

const LEVEL_H := 1.0
const RAMPS := {"^": Vector2i(0, -1), "v": Vector2i(0, 1), "<": Vector2i(-1, 0), ">": Vector2i(1, 0)}
## ramp directions by code (0 = flat ground)
const DIRS := [Vector2i.ZERO, Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
## Diagonal cliffs by code, after the ramps': which half of the tile is the high one.
const DIAG_NW := 5
const DIAG_SE := 6
const DIAG_NE := 7
const DIAG_SW := 8
## the sides each half of a "/" and a "\" tile runs along: [the first half's, the second's]
const HALVES := {"/": [[Vector2i(0, -1), Vector2i(-1, 0)], [Vector2i(0, 1), Vector2i(1, 0)]],
	"\\": [[Vector2i(0, -1), Vector2i(1, 0)], [Vector2i(0, 1), Vector2i(-1, 0)]]}
## the code when that first or second half is the high one
const HIGH_CODES := {"/": [DIAG_NW, DIAG_SE], "\\": [DIAG_NE, DIAG_SW]}


## Reads `rows` (the map's "heights") into m["elev"]: per tile, the height of its low edge and its high edge (the
## same for flat ground) and its ramp direction. Problems (a ramp with no level at an end, rows of the wrong size)
## go into m["elev_problems"] for tools/check_maps.gd. A room can set its own level height (level_h) and which digit is
## floor level y = 0 (top), so the rest sink below it.
static func parse(m: Dictionary, rows: Array, level_h := LEVEL_H, top := 0) -> void:
	var w: int = m["w"]
	var h: int = m["h"]
	var problems := []
	if rows.size() != h:
		problems.append("heights has %d rows, the map %d" % [rows.size(), h])
	var chars := []
	chars.resize(w * h)
	for y in h:
		var row: String = rows[y] if y < rows.size() else ""
		if row.length() != w and y < rows.size():
			problems.append("heights row %d is %d long, the map %d wide" % [y, row.length(), w])
		for x in w:
			var ch := row[x] if x < row.length() else "0"
			if not ch.is_valid_int() and not RAMPS.has(ch) and not HALVES.has(ch):
				problems.append("heights: '%s' at %d,%d" % [ch, x, y])
				ch = "0"
			chars[x + y * w] = ch
	var lo := PackedFloat32Array()
	var hi := PackedFloat32Array()
	var dir := PackedByteArray()
	lo.resize(w * h)
	hi.resize(w * h)
	dir.resize(w * h)
	for i in w * h:
		var ch: String = chars[i]
		if ch.is_valid_int():
			lo[i] = (int(ch) - top) * level_h
			hi[i] = lo[i]
	var at := func(p: Vector2i) -> String:
		return chars[p.x + p.y * w] if p.x >= 0 and p.y >= 0 and p.x < w and p.y < h else ""
	for i in w * h:
		var ch: String = chars[i]
		if not RAMPS.has(ch) or dir[i] != 0:
			continue
		var r: Vector2i = RAMPS[ch]
		var start := Vector2i(i % w, i / w)
		while at.call(start - r) == ch:
			start -= r
		var run := [start]
		while at.call(run[-1] + r) == ch:
			run.append(run[-1] + r)
		var low_ch: String = at.call(start - r)
		var high_ch: String = at.call(run[-1] + r)
		if not low_ch.is_valid_int() or not high_ch.is_valid_int():
			problems.append("ramp at %s needs a level at both ends" % start)
		var a := (int(low_ch) - top) * level_h if low_ch.is_valid_int() else 0.0
		var b := (int(high_ch) - top) * level_h if high_ch.is_valid_int() else a + level_h
		for k in run.size():
			var j: int = run[k].x + run[k].y * w
			lo[j] = lerpf(a, b, float(k) / run.size())
			hi[j] = lerpf(a, b, float(k + 1) / run.size())
			dir[j] = DIRS.find(r)
	_diagonals(chars, w, h, lo, hi, dir, problems)
	m["elev"] = {"lo": lo, "hi": hi, "dir": dir}
	if not problems.is_empty():
		m["elev_problems"] = problems


## Gives each diagonal ("/" or "\") its two levels: each half takes the level of the ground along its two sides (a
## diagonal neighbour's half along that side once it has one). The high half stands on the lowest level round it and
## the low half on the highest round it, so a corner between three levels still steps down from one to the next.
static func _diagonals(chars: Array, w: int, h: int, lo: PackedFloat32Array, hi: PackedFloat32Array, dir: PackedByteArray, problems: Array) -> void:
	var todo := []
	for i in w * h:
		if HALVES.has(chars[i]):
			todo.append(i)
	for _pass in 4:
		var waiting := []
		for i in todo:
			var p := Vector2i(i % w, i / w)
			var ch: String = chars[i]
			var sets := [[], []]
			var unknown := false
			for k in 2:
				for d: Vector2i in HALVES[ch][k]:
					var q := p + d
					if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
						continue
					var j := q.x + q.y * w
					if HALVES.has(chars[j]) and dir[j] == 0:
						unknown = true
						continue
					sets[k].append(_plane_of(lo[j], hi[j], dir[j], 0.5 - d.x * 0.5, 0.5 - d.y * 0.5))
			# wait for a neighbouring diagonal's levels while that's still to come
			if (unknown or sets[0].is_empty() or sets[1].is_empty()) and _pass < 3:
				waiting.append(i)
				continue
			if sets[0].is_empty() or sets[1].is_empty():
				problems.append("diagonal at %s needs ground on both sides" % p)
				sets[0] = sets[1] if sets[0].is_empty() else sets[0]
				sets[1] = sets[0] if sets[1].is_empty() else sets[1]
				if sets[0].is_empty():
					sets = [[1.0], [0.0]]
			var high := 0 if sets[0].min() > sets[1].max() else (1 if sets[1].min() > sets[0].max() else -1)
			if high < 0:
				problems.append("diagonal at %s: neither side of it is higher" % p)
				high = 0 if sets[0].max() >= sets[1].max() else 1
			hi[i] = sets[high].min()
			lo[i] = minf(sets[1 - high].max(), hi[i])
			dir[i] = HIGH_CODES[ch][high]
		todo = waiting
		if todo.is_empty():
			break


## True on the high half of a diagonal tile (code) at (u, v) across it; the line itself counts as high.
static func on_high_half(code: int, u: float, v: float) -> bool:
	match code:
		DIAG_NW:
			return u + v <= 1.0
		DIAG_SE:
			return u + v >= 1.0
		DIAG_NE:
			return u >= v
		DIAG_SW:
			return u <= v
	return true


## The height at (u, v) across a tile from its low and high edge heights and its code (a ramp's direction, a diagonal).
static func _plane_of(a: float, b: float, code: int, u: float, v: float) -> float:
	match code:
		1:
			return lerpf(a, b, 1.0 - v)
		2:
			return lerpf(a, b, v)
		3:
			return lerpf(a, b, 1.0 - u)
		4:
			return lerpf(a, b, u)
		DIAG_NW, DIAG_SE, DIAG_NE, DIAG_SW:
			return b if on_high_half(code, u, v) else a
	return a


static func has(m: Dictionary) -> bool:
	return m.has("elev")


static func _i(m: Dictionary, p: Vector2i) -> int:
	return clampi(p.x, 0, m["w"] - 1) + clampi(p.y, 0, m["h"] - 1) * int(m["w"])


## The way tile p's ramp rises (ZERO for flat ground and diagonals). Off the map, the nearest tile on it counts.
static func ramp_dir(m: Dictionary, p: Vector2i) -> Vector2i:
	if not m.has("elev"):
		return Vector2i.ZERO
	var code: int = m["elev"]["dir"][_i(m, p)]
	return DIRS[code] if code < DIRS.size() else Vector2i.ZERO


## Tile p's diagonal cliff (DIAG_NW..DIAG_SW: which half is high), or 0. Off the map: 0.
static func diagonal(m: Dictionary, p: Vector2i) -> int:
	if not m.has("elev") or p.x < 0 or p.y < 0 or p.x >= m["w"] or p.y >= m["h"]:
		return 0
	var code: int = m["elev"]["dir"][_i(m, p)]
	return code if code >= DIAG_NW else 0


## The middle of a diagonal tile's high half, from the tile's north-west corner (the middle of the tile otherwise):
## where anything standing on the tile stands.
static func high_spot(code: int) -> Vector2:
	match code:
		DIAG_NW:
			return Vector2(1.0, 1.0) / 3.0
		DIAG_SE:
			return Vector2(2.0, 2.0) / 3.0
		DIAG_NE:
			return Vector2(2.0, 1.0) / 3.0
		DIAG_SW:
			return Vector2(1.0, 2.0) / 3.0
	return Vector2(0.5, 0.5)


## The ground's height in the middle of tile p (on a diagonal, its high half's).
static func surface(m: Dictionary, p: Vector2i) -> float:
	if not m.has("elev"):
		return 0.0
	var i := _i(m, p)
	if m["elev"]["dir"][i] >= DIAG_NW:
		return m["elev"]["hi"][i]
	return (m["elev"]["lo"][i] + m["elev"]["hi"][i]) / 2.0


## The height of tile p's ground at (u, v) across it (0..1 from its north-west corner): flat, a ramp's slope, or
## either half of a diagonal.
static func plane(m: Dictionary, p: Vector2i, u: float, v: float) -> float:
	if not m.has("elev"):
		return 0.0
	var i := _i(m, p)
	return _plane_of(m["elev"]["lo"][i], m["elev"]["hi"][i], m["elev"]["dir"][i], u, v)


## The ground's height at world point (x, z), along the slopes of the ramps.
static func height_at(m: Dictionary, x: float, z: float) -> float:
	var p := Vector2i(floori(x), floori(z))
	return plane(m, p, x - p.x, z - p.y)


## The height in the middle of tile p's edge on side d.
static func edge(m: Dictionary, p: Vector2i, d: Vector2i) -> float:
	return plane(m, p, 0.5 + d.x * 0.5, 0.5 + d.y * 0.5)


## True if you can walk between neighbouring tiles a and b without climbing or dropping: the ground meets level, and
## a ramp is only stepped onto or off along its slope (beside another ramp the same, it's one wide ramp). Nobody steps
## onto or off a diagonal cliff's tile.
static func joined(m: Dictionary, a: Vector2i, b: Vector2i) -> bool:
	if not m.has("elev"):
		return true
	if diagonal(m, a) != 0 or diagonal(m, b) != 0:
		return false
	var d := b - a
	var ra := ramp_dir(m, a)
	var rb := ramp_dir(m, b)
	var across_a := ra != Vector2i.ZERO and ra != d and ra != -d
	var across_b := rb != Vector2i.ZERO and rb != d and rb != -d
	if across_a or across_b:
		var ia := _i(m, a)
		var ib := _i(m, b)
		return ra == rb and is_equal_approx(m["elev"]["lo"][ia], m["elev"]["lo"][ib]) and is_equal_approx(m["elev"]["hi"][ia], m["elev"]["hi"][ib])
	return absf(edge(m, a, d) - edge(m, b, -d)) < 0.01
