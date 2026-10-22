extends RefCounted
## Cliffs and ramps on the outdoor maps. A map's optional "heights" rows (scripts/data/maps/) give each tile a level,
## one character per tile, lined up with its "rows":
##   0-9       the ground's level there, LEVEL_H units per level (missing characters count as 0)
##   ^ v < >   a ramp rising that way (^ is north, up the map). A run of them in a line climbs evenly from the level
##             of the tile just before the run to the level of the tile just after it; runs side by side make a wide
##             ramp. Both ends must be levels (digits).
## Neighbouring tiles at different levels meet at a cliff nobody can climb (terrain_mesh.gd draws its rock face); a
## ramp is walked up and down only along its slope, and its sides are cliffs too. Maps without "heights" are flat.
## Everything stands on its tile's height: see world.gd tile_pos.

const LEVEL_H := 1.0
const RAMPS := {"^": Vector2i(0, -1), "v": Vector2i(0, 1), "<": Vector2i(-1, 0), ">": Vector2i(1, 0)}
## ramp directions by code (0 = flat ground)
const DIRS := [Vector2i.ZERO, Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]


## Reads `rows` (the map's "heights") into m["elev"]: per tile, the height of its low edge and its high edge (the
## same for flat ground) and its ramp direction. Problems (a ramp with no level at an end, rows of the wrong size)
## go into m["elev_problems"] for tools/check_maps.gd.
static func parse(m: Dictionary, rows: Array) -> void:
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
			if not ch.is_valid_int() and not RAMPS.has(ch):
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
		if not RAMPS.has(ch):
			lo[i] = int(ch) * LEVEL_H
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
		var a := int(low_ch) * LEVEL_H if low_ch.is_valid_int() else 0.0
		var b := int(high_ch) * LEVEL_H if high_ch.is_valid_int() else a + LEVEL_H
		for k in run.size():
			var j: int = run[k].x + run[k].y * w
			lo[j] = lerpf(a, b, float(k) / run.size())
			hi[j] = lerpf(a, b, float(k + 1) / run.size())
			dir[j] = DIRS.find(r)
	m["elev"] = {"lo": lo, "hi": hi, "dir": dir}
	if not problems.is_empty():
		m["elev_problems"] = problems


static func has(m: Dictionary) -> bool:
	return m.has("elev")


static func _i(m: Dictionary, p: Vector2i) -> int:
	return clampi(p.x, 0, m["w"] - 1) + clampi(p.y, 0, m["h"] - 1) * int(m["w"])


## The way tile p's ramp rises (ZERO for flat ground). Off the map, the nearest tile on it counts.
static func ramp_dir(m: Dictionary, p: Vector2i) -> Vector2i:
	if not m.has("elev"):
		return Vector2i.ZERO
	return DIRS[m["elev"]["dir"][_i(m, p)]]


## The ground's height in the middle of tile p.
static func surface(m: Dictionary, p: Vector2i) -> float:
	if not m.has("elev"):
		return 0.0
	var i := _i(m, p)
	return (m["elev"]["lo"][i] + m["elev"]["hi"][i]) / 2.0


## The height of tile p's ground at (u, v) across it (0..1 from its north-west corner): flat, or a ramp's slope.
static func plane(m: Dictionary, p: Vector2i, u: float, v: float) -> float:
	if not m.has("elev"):
		return 0.0
	var i := _i(m, p)
	var a: float = m["elev"]["lo"][i]
	var b: float = m["elev"]["hi"][i]
	match int(m["elev"]["dir"][i]):
		1:
			return lerpf(a, b, 1.0 - v)
		2:
			return lerpf(a, b, v)
		3:
			return lerpf(a, b, 1.0 - u)
		4:
			return lerpf(a, b, u)
	return a


## The ground's height at world point (x, z), along the slopes of the ramps.
static func height_at(m: Dictionary, x: float, z: float) -> float:
	var p := Vector2i(floori(x), floori(z))
	return plane(m, p, x - p.x, z - p.y)


## The height in the middle of tile p's edge on side d.
static func edge(m: Dictionary, p: Vector2i, d: Vector2i) -> float:
	return plane(m, p, 0.5 + d.x * 0.5, 0.5 + d.y * 0.5)


## True if you can walk between neighbouring tiles a and b without climbing or dropping: the ground meets level, and
## a ramp is only stepped onto or off along its slope (beside another ramp the same, it's one wide ramp).
static func joined(m: Dictionary, a: Vector2i, b: Vector2i) -> bool:
	if not m.has("elev"):
		return true
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
