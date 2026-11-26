extends RefCounted
## Valkoog's wind puzzles: the rules only (no nodes, no autoloads), so the world, the debug scene and the map audit
## all read the same answer. air_temple.gd builds the pieces, runs the room and draws the wind.
##
## A room's "wind" (interior_maps.gd) names its pieces by id; each stands on the anchor "wind_<id>" in its rows:
##   vent      a stone mouth that always breathes, "dir" (^ v < >)
##   fan       a bronze fan that turns a quarter clockwise when you push it, sending any wind that reaches it on
##             its own way ("dir")
##   jar       a big sand jar: the twins' gust slides it the way you face until something stops it. Wind stops at it.
##   pinwheel  spins while wind reaches it
##   stone     a wind-stone, asleep ("dir" when it wakes) until the hero casts Gust into it (saved: its flag)
##   vane      a bronze sail standing on the diagonal, "/" or "\": wind turns a quarter round it; pushed, it flips
##   updraft   a grate in the floor: wind that reaches it rises from it, and stepping on it lifts you to "to"
## Two rooms' kinds of wind (the plan's two sets of puzzles):
##   breath  (the keepers' halls, floors 1-4): soft streams you walk through. They spin pinwheels and, fed into the
##           room's sand curtain ("gate"), keep it standing. The curtain stills once every pinwheel it "needs"
##           spins and no wind feeds it.
##   gale    (the climb to the dragon): a gale carries anyone who steps into it to where it ends, over chasms (" ")
##           and round its vanes; one that ends over a chasm sets you back where you stepped in.
const MapGen = preload("res://scripts/world/map_gen.gd")

const DIRS := {"^": Vector2i(0, -1), "v": Vector2i(0, 1), "<": Vector2i(-1, 0), ">": Vector2i(1, 0)}
const CW := {"^": ">", ">": "v", "v": "<", "<": "^"}
## A vane's turn: tilt -> the way the wind comes -> the way it leaves.
const VANE := {"/": {">": "^", "<": "v", "^": ">", "v": "<"}, "\\": {">": "v", "<": "^", "^": "<", "v": ">"}}
## Pieces wind passes through (turned), and pieces it stops at.
const PASS := ["fan", "vane"]
const SINKS := ["pinwheel", "updraft"]
## Pieces you can stand on (an updraft's grate); every other piece is solid.
const FLOORED := ["updraft"]


static func way(d: String) -> Vector2i:
	return DIRS.get(d, Vector2i.ZERO)


static func dir_of(v: Vector2i) -> String:
	for k in DIRS:
		if DIRS[k] == v:
			return k
	return "v"


## The room's pieces: id -> {"kind", "at", and the spec's own keys}, placed on their anchors.
static func pieces(map: Dictionary) -> Dictionary:
	var spec: Dictionary = map.get("room", {}).get("wind", {}).get("pieces", {})
	var anchors: Dictionary = map.get("anchors", {})
	var out := {}
	for id in spec:
		var an := "wind_" + String(id)
		if not anchors.has(an):
			continue
		var pc: Dictionary = (spec[id] as Dictionary).duplicate()
		pc["id"] = String(id)
		pc["at"] = anchors[an]
		if pc.has("to") and anchors.has("wind_" + String(pc["to"])):
			pc["to_tile"] = anchors["wind_" + String(pc["to"])]
		out[String(id)] = pc
	return out


## The room's rules: "kind" (breath or gale), its curtain ("gate": {"at": anchor, "needs": [pinwheel ids], "fed":
## true}), and a solved flag.
static func rules(map: Dictionary) -> Dictionary:
	return map.get("room", {}).get("wind", {})


static func gate_tile(map: Dictionary) -> Vector2i:
	var g: Dictionary = rules(map).get("gate", {})
	return map.get("anchors", {}).get("wind_" + String(g.get("at", "")), Vector2i(-1, -1))


## Each piece's starting state: a fan's or vent's way, a vane's tilt, a jar's tile, whether a stone is awake
## (`flags`: GameState.flags, for the stones already woken).
static func fresh(pcs: Dictionary, flags: Dictionary) -> Dictionary:
	var st := {}
	for id in pcs:
		var pc: Dictionary = pcs[id]
		match String(pc["kind"]):
			"fan", "vent":
				st[id] = String(pc.get("dir", "v"))
			"vane":
				st[id] = String(pc.get("tilt", "/"))
			"jar":
				st[id] = pc["at"]
			"stone":
				st[id] = bool(flags.get(String(pc.get("flag", "")), false))
	return st


## Where each piece stands now (a jar where it's been slid to).
static func where(pcs: Dictionary, st: Dictionary, id: String) -> Vector2i:
	if String(pcs[id]["kind"]) == "jar":
		return st.get(id, pcs[id]["at"])
	return pcs[id]["at"]


static func occupied(pcs: Dictionary, st: Dictionary) -> Dictionary:
	var occ := {}
	for id in pcs:
		occ[where(pcs, st, id)] = id
	return occ


## What stops the wind (and a sliding jar) on the map itself: walls, pillars, furniture, doorways and stairs. A chasm
## (IVOID) doesn't: wind blows straight over it.
static func solid_tile(map: Dictionary, p: Vector2i) -> bool:
	if p.x < 0 or p.y < 0 or p.x >= int(map["w"]) or p.y >= int(map["h"]):
		return true
	var c := MapGen.get_t(map, p.x, p.y)
	if c == MapGen.IVOID:
		return false
	if c in [MapGen.STAIRS_UP, MapGen.STAIRS_DOWN]:
		return true
	if map.get("exits", {}).has(p):
		return true
	return not MapGen.walkable(c)


static func chasm(map: Dictionary, p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < int(map["w"]) and p.y < int(map["h"]) and MapGen.get_t(map, p.x, p.y) == MapGen.IVOID


## Where the wind blows: {"paths": [{"from": id, "tiles": [tile...], "dirs": [way leaving each tile...]}],
## "tiles": {tile: true}, "spun": {pinwheel or updraft id: true}, "fed": whether it reaches the curtain}.
## Each path runs from its source (not counted) to the last tile before what stops it; a fan's or vane's tile is on
## the path where the wind turns through it.
static func blow(map: Dictionary, pcs: Dictionary, st: Dictionary) -> Dictionary:
	var occ := occupied(pcs, st)
	var gate := gate_tile(map)
	var out := {"paths": [], "tiles": {}, "spun": {}, "fed": false}
	for id in pcs:
		var pc: Dictionary = pcs[id]
		var kind := String(pc["kind"])
		if kind == "stone" and not bool(st.get(id, false)):
			continue
		if kind not in ["vent", "stone"]:
			continue
		var d := String(st.get(id, pc.get("dir", "v"))) if kind == "vent" else String(pc.get("dir", "v"))
		var p: Vector2i = pc["at"]
		var path := {"from": id, "tiles": [], "dirs": []}
		var seen := {}
		while true:
			var q: Vector2i = p + way(d)
			var k := Vector3i(q.x, q.y, "^v<>".find(d))
			if seen.has(k):
				break
			seen[k] = true
			if q == gate:
				out["fed"] = true
				break
			if occ.has(q):
				var o: String = occ[q]
				var ok := String(pcs[o]["kind"])
				if ok in PASS:
					d = String(st[o]) if ok == "fan" else String(VANE[String(st[o])][d])
					path["tiles"].append(q)
					path["dirs"].append(d)
					p = q
					continue
				if ok in SINKS:
					out["spun"][o] = true
				break
			if solid_tile(map, q):
				break
			path["tiles"].append(q)
			path["dirs"].append(d)
			p = q
		for t in path["tiles"]:
			out["tiles"][t] = true
		out["paths"].append(path)
	return out


## Whether the room's curtain still stands: a pinwheel it needs isn't spinning, or wind still feeds it.
static func gate_up(map: Dictionary, pcs: Dictionary, st: Dictionary, wind := {}) -> bool:
	var g: Dictionary = rules(map).get("gate", {})
	if g.is_empty():
		return false
	if wind.is_empty():
		wind = blow(map, pcs, st)
	for need in g.get("needs", []):
		if not wind["spun"].has(String(need)):
			return true
	return bool(g.get("fed", false)) and bool(wind["fed"])


## Whether tile p is free for a piece to slide onto (or the hero to stand on): floor, no piece, not the shut curtain.
static func open_tile(map: Dictionary, pcs: Dictionary, st: Dictionary, p: Vector2i, occ := {}) -> bool:
	if occ.is_empty():
		occ = occupied(pcs, st)
	if solid_tile(map, p) or chasm(map, p):
		return false
	if occ.has(p) and not String(pcs[occ[p]]["kind"]) in FLOORED:
		return false
	if p == gate_tile(map):
		return false
	return true


## Where a jar gusted the way `d` comes to rest: on along `d` until the next tile isn't free (or is `hero`, or the
## edge of a chasm).
static func slide(map: Dictionary, pcs: Dictionary, st: Dictionary, id: String, d: Vector2i, hero := Vector2i(-99, -99)) -> Vector2i:
	var occ := occupied(pcs, st)
	var at: Vector2i = where(pcs, st, id)
	while true:
		var q: Vector2i = at + d
		if q == hero or not open_tile(map, pcs, st, q, occ) or (occ.has(q)):
			break
		at = q
	return at


## A gale's ride from tile `p` (on its path): {"ride": [tiles passed, ending where you land], "land": tile, "drop":
## true if it ends over a chasm (you're set back to `from`)}. Empty if `p` isn't on a gale, or is where one ends.
static func ride(map: Dictionary, pcs: Dictionary, st: Dictionary, p: Vector2i, from: Vector2i, wind := {}) -> Dictionary:
	if String(rules(map).get("kind", "breath")) != "gale":
		return {}
	if wind.is_empty():
		wind = blow(map, pcs, st)
	var occ := occupied(pcs, st)
	for path in wind["paths"]:
		var tiles: Array = path["tiles"]
		var i := tiles.find(p)
		if i < 0 or i == tiles.size() - 1:
			continue
		var end: Vector2i = tiles.back()
		var rest := tiles.slice(i + 1)
		if chasm(map, end) or occ.has(end):
			return {"ride": rest, "land": from, "drop": true, "dirs": (path["dirs"] as Array).slice(i)}
		return {"ride": rest, "land": end, "drop": false, "dirs": (path["dirs"] as Array).slice(i)}
	return {}


# ---------------------------------------------------------------- the solver (the twins' hints, the tests)
## Tiles the hero can stand on, from `hero`, with the room in state `st` (gales carry them as they would in play),
## each step from p onto q tested by `walk` (floor_walk: the map's floor and levels, without the pieces).
static func region(map: Dictionary, pcs: Dictionary, st: Dictionary, hero: Vector2i, walk: Callable) -> Dictionary:
	var wind := blow(map, pcs, st)
	var occ := occupied(pcs, st)
	var gate_shut := gate_up(map, pcs, st, wind)
	var gt := gate_tile(map)
	var stand := {hero: true}
	var tried := {}
	var todo: Array[Vector2i] = [hero]
	while not todo.is_empty():
		var p: Vector2i = todo.pop_back()
		for d in DIRS.values():
			var q: Vector2i = p + d
			if tried.has(q) or stand.has(q) or not walk.call(p, q):
				continue
			if occ.has(q) and not String(pcs[occ[q]]["kind"]) in FLOORED:
				continue
			if q == gt and gate_shut:
				continue
			tried[q] = true
			var r := ride(map, pcs, st, q, p, wind)
			var to: Vector2i = q if r.is_empty() else r["land"]
			if not stand.has(to):
				stand[to] = true
				todo.append(to)
	return stand


## Every move the hero can make from `hero`: [label, new state, where the hero then stands]. `reach`: the hero's
## region, if it's known already.
static func moves(map: Dictionary, pcs: Dictionary, st: Dictionary, hero: Vector2i, walk: Callable, reach := {}) -> Array:
	if reach.is_empty():
		reach = region(map, pcs, st, hero, walk)
	var out := []
	for id: String in pcs:
		var kind := String(pcs[id]["kind"])
		if kind not in ["fan", "vane", "stone", "jar"] or (kind == "stone" and bool(st[id])):
			continue
		var q := where(pcs, st, id)
		for dn in DIRS:
			var d: Vector2i = DIRS[dn]
			var p: Vector2i = q - d
			if not reach.has(p):
				continue
			var ns := st.duplicate()
			match kind:
				"fan":
					ns[id] = CW[String(st[id])]
				"vane":
					ns[id] = "\\" if String(st[id]) == "/" else "/"
				"stone":
					ns[id] = true
				"jar":
					var to := slide(map, pcs, st, id, d, p)
					if to == q:
						continue
					ns[id] = to
			var r := ride(map, pcs, ns, p, p)
			out.append(["%s %s %s" % [kind, id, dn], ns, p if r.is_empty() else r["land"]])
	return out


## What solve() answers when it gives up before it knows (more than `limit` layouts tried): not stuck, just unsure.
const UNSURE := "unsure"


## The least moves that solve the room from here, null if none can, or UNSURE past `limit` layouts. `done` says when
## it's solved: (state, region) -> bool. A breath room's regions (no gales to carry you) depend only on where its jars
## stand and whether its curtain's up, so each is found once and kept for every tile in it.
static func solve(map: Dictionary, pcs: Dictionary, st: Dictionary, hero: Vector2i, walk: Callable, done: Callable, limit := 6000):
	var gale := String(rules(map).get("kind", "breath")) == "gale"
	var steps := {}
	var walk_once := func(p: Vector2i, q: Vector2i) -> bool:
		var k := Vector4i(p.x, p.y, q.x, q.y)
		if not steps.has(k):
			steps[k] = walk.call(p, q)
		return steps[k]
	var shut := {}
	var areas := {}
	# [the region, its first tile in reading order (the hero's place in the layout's key)]
	var area := func(s: Dictionary, sk: String, h: Vector2i) -> Array:
		var lay := ""
		if not gale:
			if not shut.has(sk):
				shut[sk] = gate_up(map, pcs, s)
			lay = _jars(pcs, s) + ("|up" if shut[sk] else "")
			if areas.has(lay) and (areas[lay] as Dictionary).has(h):
				return areas[lay][h]
		var reg := region(map, pcs, s, h, walk_once)
		var low := h
		for t: Vector2i in reg:
			if t.y < low.y or (t.y == low.y and t.x < low.x):
				low = t
		var found := [reg, low]
		if not gale:
			if not areas.has(lay):
				areas[lay] = {}
			for t in reg:
				areas[lay][t] = found
		return found
	var sk0 := str(st.values())
	var queue := [[st, hero, [], sk0]]
	var seen := {sk0 + "@" + str((area.call(st, sk0, hero) as Array)[1]): true}
	var head := 0
	while head < queue.size():
		var item: Array = queue[head]
		head += 1
		var s: Dictionary = item[0]
		var h: Vector2i = item[1]
		var here: Array = area.call(s, item[3], h)
		if done.call(s, here[0]):
			return item[2]
		for mv in moves(map, pcs, s, h, walk_once, here[0]):
			var sk := str((mv[1] as Dictionary).values())
			var k: String = sk + "@" + str((area.call(mv[1], sk, mv[2]) as Array)[1])
			if seen.has(k):
				continue
			seen[k] = true
			if seen.size() > limit:
				return UNSURE
			queue.append([mv[1], mv[2], (item[2] as Array) + [mv[0]], sk])
	return null


static func _jars(pcs: Dictionary, s: Dictionary) -> String:
	var out := ""
	for id in pcs:
		if String(pcs[id]["kind"]) == "jar":
			out += str(s[id])
	return out


## The solver's walk test, a step from p onto q: floor (not a chasm), inside the room, on the same level
## (elevation.gd), not an exit, and not one of `blocked` (the twins, the keepers: people standing about).
static func floor_walk(map: Dictionary, blocked := {}) -> Callable:
	var Elev = load("res://scripts/world/elevation.gd")
	return func(p: Vector2i, q: Vector2i) -> bool:
		if q.x < 0 or q.y < 0 or q.x >= int(map["w"]) or q.y >= int(map["h"]) or blocked.has(q):
			return false
		if not MapGen.walkable(MapGen.get_t(map, q.x, q.y)) or map.get("exits", {}).has(q):
			return false
		return Elev.joined(map, p, q)


## When the room counts as solved: a breath room once its curtain is still; a gale room once its goal ("goal":
## updraft id, powered and beside a tile you can reach; or "reach": an anchor you can stand on) is reached.
static func done_test(map: Dictionary, pcs: Dictionary) -> Callable:
	var r := rules(map)
	if r.has("gate"):
		return func(s: Dictionary, _reach: Dictionary) -> bool: return not gate_up(map, pcs, s)
	if r.has("goal"):
		var goal := String(r["goal"])
		return func(s: Dictionary, reach: Dictionary) -> bool:
			if not blow(map, pcs, s)["spun"].has(goal):
				return false
			var at: Vector2i = pcs[goal]["at"]
			for d in DIRS.values():
				if reach.has(at + d):
					return true
			return false
	var target: Vector2i = map.get("anchors", {}).get("wind_" + String(r.get("reach", "")), Vector2i(-1, -1))
	return func(_s: Dictionary, reach: Dictionary) -> bool: return reach.has(target)
