extends SceneTree
## Cuts the corners of the outdoor maps' cliffs into diagonals ("/" and "\" in a map's "heights", elevation.gd), so a
## cliff seldom turns through a right angle. A corner is cut on the tile at it: on high ground where the cliff turns
## round a point of it (two neighbouring sides drop to one lower level), else on the low ground in the nook of it (two
## neighbouring sides rise to one higher level). A cut tile can't be walked on, so only tiles that nothing needs are
## cut: grass, trees, hedges, flowers, rocks and open sea, never a road, a doorstep, someone's spot, a boat's mooring,
## an exit or the last way through to anything (every tile that could be reached still can be, with and without the
## story's gates open). A headland's point may drop to the sea, and the sea's nook under a cliff may be cut too: each
## half of the tile takes the ground (or water) of the tiles along its sides (terrain_mesh.gd).
##   godot --headless --path . --script res://tools/cliff_corners.gd                  report what it would cut
##   godot --headless --path . --script res://tools/cliff_corners.gd -- --write       cut them in the map files
##   ... -- caccoon route1                                                             only those maps
## Run tools/check_maps.gd and tools/town_check.py afterwards, and look at the maps: an authored "/" or "\" stays.

const MapGen = preload("res://scripts/world/map_gen.gd")
const MapLoader = preload("res://scripts/world/map_loader.gd")
const WorldDB = preload("res://scripts/data/world_db.gd")
const Elev = preload("res://scripts/world/elevation.gd")
const TownMaps = preload("res://scripts/data/maps/town_maps.gd")
const RouteMaps = preload("res://scripts/data/maps/route_maps.gd")
const Shoreline = preload("res://scripts/world/shoreline.gd")

const FILES := {"town": "res://scripts/data/maps/town_maps.gd", "route": "res://scripts/data/maps/route_maps.gd"}
## ground a cut may take
const SPARE := [MapGen.GRASS, MapGen.TREE, MapGen.BUSH, MapGen.ROCK, MapGen.FLOWERS, MapGen.SAND]
const WET := [MapGen.WATER, MapGen.LAVA, MapGen.SHALLOWS, MapGen.BRIDGE]
const SIDES := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const OPEN_FLAGS := {"has_starter": true, "island_peace": true, "bandits_cleared": true, "ceo_defeated": true,
	"ritual_done": true, "sluice_reef": true}


func _init() -> void:
	var write := false
	var only := []
	for a in OS.get_cmdline_user_args():
		if a == "--write":
			write = true
		else:
			only.append(a)
	var edits := {}
	var total := 0
	for id in TownMaps.MAPS.keys() + RouteMaps.MAPS.keys():
		if not only.is_empty() and not only.has(id):
			continue
		var src: Dictionary = TownMaps.MAPS.get(id, RouteMaps.MAPS.get(id, {}))
		if not src.has("heights"):
			continue
		var res := _cut(id, src)
		total += res["cuts"].size()
		print("%-12s cut %3d   left %s" % [id, res["cuts"].size(), res["left"]])
		if write and not res["cuts"].is_empty():
			edits[id] = res["rows"]
	print("corners cut: ", total)
	if write:
		for kind in FILES:
			var path: String = FILES[kind]
			var text := FileAccess.get_file_as_string(path)
			var changed := false
			for id in edits:
				if (TownMaps.MAPS if kind == "town" else RouteMaps.MAPS).has(id):
					text = _replace_heights(text, id, edits[id])
					changed = true
			if changed:
				var f := FileAccess.open(path, FileAccess.WRITE)
				f.store_string(text)
				f.close()
				print("wrote ", path)
	quit()


## The corners to cut in one map: {"cuts": [tile...], "rows": its new heights rows, "left": {reason: count}}.
func _cut(id: String, src: Dictionary) -> Dictionary:
	var rows: Array = src["heights"].duplicate()
	var maps := [MapLoader.load_map(id, {}), MapLoader.load_map(id, OPEN_FLAGS)]
	var m: Dictionary = maps[0]
	var w: int = m["w"]
	var h: int = m["h"]
	var lvl := func(p: Vector2i) -> int:
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
			return -1
		var c: String = String(rows[p.y])[p.x] if p.x < String(rows[p.y]).length() else "0"
		return int(c) if c.is_valid_int() else -1
	var busy := _busy(m)
	var left := {}
	var cuts := {}
	# per cut tile: the level along each of its sides (a cut beside another must agree with it there)
	var shows_of := {}
	var reach := []
	for mm in maps:
		reach.append(_reach(mm, {}))
	# points of high ground first, then nooks of low ground that don't meet one of those
	for pass_ in 2:
		for y in range(1, h - 1):
			for x in range(1, w - 1):
				var p := Vector2i(x, y)
				var l: int = lvl.call(p)
				if l < 0 or cuts.has(p):
					continue
				# the two neighbouring sides that drop (a point) or rise (a nook); the other two may step the other way
				var odd := []
				for k in 4:
					var n: int = lvl.call(p + SIDES[k])
					if n < 0:
						odd = []
						break
					if (n < l) if pass_ == 0 else (n > l):
						odd.append(k)
				if odd.size() != 2 or (odd[1] - odd[0]) % 2 == 0:
					continue
				var a: Vector2i = SIDES[odd[0]]
				var b: Vector2i = SIDES[odd[1]]
				var corner: int = lvl.call(p + a + b)
				# the level each side of the cut tile would show: its own along two, the far side's along the others
				# (elevation.gd: a point's low half the highest of them, a nook's high half the lowest)
				var na: int = lvl.call(p + a)
				var nb: int = lvl.call(p + b)
				var shows := {}
				for d in SIDES:
					shows[d] = l
				shows[a] = maxi(na, nb) if pass_ == 0 else mini(na, nb)
				shows[b] = shows[a]
				# two cuts side by side meet only where both show their own level (the ends of a ridge or a notch two
				# tiles wide), so neither's halves depend on the other's
				var clash := false
				for d in SIDES:
					var nl: int = lvl.call(p + d)
					if cuts.has(p + d) and not (shows[d] == l and shows_of[p + d][-d] == nl and nl == l):
						clash = true
				var why := ""
				# the tile across the corner is on the far side of the cliff too
				if corner < 0 or ((corner >= l) if pass_ == 0 else (corner <= l)):
					why = "uneven"
				elif clash:
					why = "staircase"
				elif x == 0 or y == 0 or x == w - 1 or y == h - 1:
					why = "edge"
				else:
					why = _unsafe(maps, p, pass_, [p + a, p + b], [p - a, p - b], p + a + b, busy)
				if why == "":
					for k in maps.size():
						if not _still_reached(maps[k], cuts, p, reach[k]):
							why = "only way through"
				if why != "":
					left[why] = left.get(why, 0) + 1
					continue
				# "/" runs from the tile's bottom-left corner to its top-right: its halves face north-west and south-east
				var nw_se := (a + b) in [Vector2i(-1, -1), Vector2i(1, 1)]
				cuts[p] = "/" if nw_se else "\\"
				shows_of[p] = shows
	for p in cuts:
		var r: String = rows[p.y]
		rows[p.y] = r.substr(0, p.x) + String(cuts[p]) + r.substr(p.x + 1)
	return {"cuts": cuts.keys(), "rows": rows, "left": left}


## Why tile p can't be cut ("" if it can): its ground, or something placed on it. pass_: 0 for a point of high ground
## (`odd` its two lower sides, `same` the others), 1 for a nook of low ground (`odd` its two higher sides). A point's low
## half may be sea, both its low sides being sea, and a nook may be sea under land: the half takes on its sides' ground.
func _unsafe(maps: Array, p: Vector2i, pass_: int, odd: Array, same: Array, corner: Vector2i, busy: Dictionary) -> String:
	for m in maps:
		var t := MapGen.get_t(m, p.x, p.y)
		if t in WET and not (pass_ == 1 and t == MapGen.WATER):
			return "water"
		if not t in SPARE and not t in WET:
			return "ground"
		var odd_wet := []
		for q: Vector2i in odd + [corner]:
			var c := MapGen.get_t(m, q.x, q.y)
			if c in [MapGen.BRIDGE, MapGen.SHALLOWS, MapGen.LAVA]:
				return "water"
			odd_wet.append(c in WET)
		# the high ground is dry land
		if pass_ == 1 and (odd_wet[0] or odd_wet[1]):
			return "water"
		if pass_ == 0:
			if odd_wet[0] != odd_wet[1]:
				return "water"
			for q: Vector2i in same:
				if MapGen.get_t(m, q.x, q.y) in WET:
					return "water"
		for q: Vector2i in [p] + odd + same:
			if Shoreline.contains(m, q.x + 0.5, q.y + 0.5):
				return "shore"
		if Elev.ramp_dir(m, p) != Vector2i.ZERO:
			return "ramp"
		for d in SIDES:
			if Elev.ramp_dir(m, p + d) != Vector2i.ZERO:
				return "ramp"
	if busy.has(p):
		return busy[p]
	return ""


## Tiles something is placed on or reserved for: {tile: what}.
func _busy(m: Dictionary) -> Dictionary:
	var out := {}
	for n in m["npcs"]:
		out[n["pos"]] = "person"
	for it in m["items"]:
		out[it["pos"]] = "item"
	for p in m["signs"]:
		out[p] = "sign"
	for k in m["anchors"]:
		out[m["anchors"][k]] = "anchor"
	for k in m["spawns"]:
		out[m["spawns"][k]] = "spawn"
	for p in m["obstacles"]:
		out[p] = "obstacle"
	for p in m["pushables"]:
		out[p] = "pushable"
	for s in m["shards"]:
		out[s if s is Vector2i else s.get("pos", Vector2i(-1, -1))] = "shard"
	for b in m["buildings"]:
		var door: Vector2i = b["door"]
		for d in [Vector2i.ZERO, Vector2i.DOWN, Vector2i.DOWN * 2]:
			out[door + d] = "doorstep"
	for r in m.get("prop_clearance", []):
		for y in range(int(r[1]), int(r[1]) + int(r[3])):
			for x in range(int(r[0]), int(r[0]) + int(r[2])):
				out[Vector2i(x, y)] = "kept clear"
	for sh in m.get("scenery_houses", []):
		for y in range(int(sh["y"]) - 1, int(sh["y"]) + int(sh["d"]) + 1):
			for x in range(int(sh["x"]) - 1, int(sh["x"]) + int(sh["w"]) + 1):
				out[Vector2i(x, y)] = "house"
	for key in ["fish_spots"]:
		for p in m.get(key, {}):
			if p is Vector2i:
				out[p] = "fishing"
	# boats moored in the water: [x, z, turn, model, length]
	for b in m.get("boats", []):
		var r := ceili(float(b[4]) / 2.0) + 1
		for y in range(floori(b[1]) - r, floori(b[1]) + r + 1):
			for x in range(floori(b[0]) - r, floori(b[0]) + r + 1):
				out[Vector2i(x, y)] = "boat"
	for key in ["over_water", "ledges"]:
		for p in m.get(key, {}):
			out[p] = key
	return out


## Every walkable tile reached from the map's start, with the cut tiles (and `extra`) closed.
func _reach(m: Dictionary, closed: Dictionary, extra := Vector2i(-99, -99)) -> Dictionary:
	var start: Vector2i = m["spawns"].get("start", m["spawns"].values()[0])
	var seen := {start: true}
	var q := [start]
	while not q.is_empty():
		var p: Vector2i = q.pop_back()
		for d in SIDES:
			var n: Vector2i = p + d
			if seen.has(n) or closed.has(n) or n == extra or n.x < 0 or n.y < 0 or n.x >= m["w"] or n.y >= m["h"]:
				continue
			if MapGen.walkable(MapGen.get_t(m, n.x, n.y)) and not m["obstacles"].has(n) and Elev.joined(m, p, n):
				seen[n] = true
				q.append(n)
	return seen


## Closing p as well as the cuts so far still reaches every tile reached before (but p).
func _still_reached(m: Dictionary, cuts: Dictionary, p: Vector2i, before: Dictionary) -> bool:
	var now := _reach(m, cuts, p)
	for q in before:
		if q != p and not cuts.has(q) and not now.has(q):
			return false
	return true


## The map's source text with map `id`'s "heights" rows replaced (keeping its line endings).
func _replace_heights(text: String, id: String, rows: Array) -> String:
	var at := text.find("\t\"%s\": {" % id)
	assert(at >= 0, "no map " + id)
	var hs := text.find("\"heights\": [", at)
	var start := text.find("\n", hs) + 1
	var nl := "\r\n" if text.substr(start - 2, 2) == "\r\n" else "\n"
	var end := start
	for r in rows:
		var line_end := text.find("\n", end)
		var line := text.substr(end, line_end - end).strip_edges()
		assert(line.begins_with("\""), "heights of %s: %s" % [id, line])
		end = line_end + 1
	var out := ""
	for r in rows:
		out += "\t\t\t\"%s\",%s" % [String(r).replace("\\", "\\\\"), nl]
	return text.substr(0, start) + out + text.substr(end)
