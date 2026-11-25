extends RefCounted
## The Scaraba Desert's layout director (docs/scaraba-implementation-plan.md WP2). The desert (WorldDB route5) is not one
## baked map: it is a chain of authored sections (desert_sections.gd), south to north, from the Mesa Trail's seam to
## Scaraba's oasis gate. A save's seed picks the middle among equivalent optional sections; the opening, the joins,
## Valkoog's approach and the oasis gate are always there, in that order.
##
## One section stands at a time, as the map "route5" (MapLoader.load_map asks source() for it): its north and south
## edges are seams into the next and the previous section, crossed behind a short fade (desert_crossing.gd). A join's
## onward seam leads on only once its star ring is solved. Until then, walking on past it leads into the edge: open
## sand, at whose far side the hero walks off and is returned to the map they came from.
##
## State, in the save's flags[KEY]: {"seed", "list": [section id], "variants": [variant id per slot], "at": slot,
## "dir": 1 walking north / -1 south, "from": "route4" or "sundown", "edge": in the edge, "back": the slot it opened off}.
## Everything here is pure (no autoloads), so map audits can assemble any section.
const Sections = preload("res://scripts/data/maps/desert_sections.gd")
## the star locks' faces (star_locks.gd VARIANTS; not preloaded there, so map audits need no autoloads)
const LOCK_VARIANTS := ["ring", "pillars", "ducks", "bells"]
const ROUTE := "route5"
const KEY := "desert_layout"
## The order of every slot: "*" is the seed's optional sections (two in the first, one or two in the second).
const SKELETON := ["opening", "*", "join_a", "valkoog", "join_b", "*", "oasis_gate"]
## The star rule (outline §2): points one to five clockwise from the top, touched 1, 3, 5, 2, 4 and the top again.
const STAR := [1, 3, 5, 2, 4, 1]
## Where a ring's five stones stand round its centre.
const STAR_POINTS := {1: Vector2i(0, -3), 2: Vector2i(3, -1), 3: Vector2i(2, 2), 4: Vector2i(-2, 2), 5: Vector2i(-3, -1)}
## The map the hero came from when nothing else says: a desert entered by a save or a debug jump.
const DEFAULT_FROM := "route4"
## The state a game in progress is using (desert_crossing.gd keeps it): for a map loaded without its flags.
static var live := {}


static func optional_sections() -> Array:
	var out := []
	for id in Sections.SECTIONS:
		if "optional" in Sections.SECTIONS[id]["tags"]:
			out.append(id)
	out.sort()
	return out


## A fresh desert from a seed: the same seed always gives the same list.
static func make(seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pool := optional_sections()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	var first := mini(2, maxi(pool.size() - 1, 0))
	var second := 1 + rng.randi_range(0, 1)
	var list := []
	var stars := 0
	for slot in SKELETON:
		if slot != "*":
			list.append(slot)
			continue
		var take := first if stars == 0 else second
		for k in take:
			if not pool.is_empty():
				list.append(pool.pop_front())
		stars += 1
	var variants := []
	variants.resize(list.size())
	variants.fill("")
	# each join's lock takes one of the faces, no two the same
	var faces := LOCK_VARIANTS.duplicate()
	var locks := {}
	for id in list:
		if not ring_of(id).is_empty():
			locks[id] = faces.pop_at(rng.randi_range(0, faces.size() - 1))
	return {"seed": seed, "list": list, "variants": variants, "locks": locks, "at": 0, "dir": 1, "from": DEFAULT_FROM, "edge": false, "back": 0}


## The face of `section`'s lock in this desert (a layout saved before there were faces: one from its seed).
static func lock_variant(st: Dictionary, section: String) -> String:
	var locks: Dictionary = st.get("locks", {})
	if locks.has(section):
		return String(locks[section])
	return LOCK_VARIANTS[posmod(hash(str(st.get("seed", 0)) + section), LOCK_VARIANTS.size())]


## The layout `flags` holds (or the live one, or seed 0's).
static func state(flags: Dictionary) -> Dictionary:
	var st = flags.get(KEY, null)
	if not st is Dictionary or not st.has("list"):
		st = live if live.has("list") else make(0)
	return st


static func current(st: Dictionary) -> String:
	return "edge" if bool(st.get("edge", false)) else String(st["list"][clampi(int(st["at"]), 0, st["list"].size() - 1)])


static func ring_of(section: String) -> Dictionary:
	return Sections.SECTIONS.get(section, {}).get("ring", {})


## A ring stays answered once solved; a hero who has reached the town has answered every ring on the way.
static func ring_open(ring_id: String, flags: Dictionary) -> bool:
	return bool(flags.get("star_ring_" + ring_id, false)) or bool(flags.get("desert_crossed", false))


## The variant a section takes when walked into now: the first whose flag is set ("" for its plain rows). A variant
## may instead give "unless": it stands until that flag is set (Valkoog's storm-haze, which the released wind lifts).
static func variant_for(section: String, flags: Dictionary) -> String:
	for v in Sections.SECTIONS.get(section, {}).get("variants", []):
		var need := String(v.get("flag", ""))
		var unless := String(v.get("unless", ""))
		if unless != "" and bool(flags.get(unless, false)):
			continue
		if need != "" and not bool(flags.get(need, false)):
			continue
		if need == "" and unless == "":
			continue
		return String(v["id"])
	return ""


## The current section's source for MapLoader._parse: its rows with its variant's tiles, and flags of its own
## (an item or a trainer in one section is not the same one in another).
static func source(flags: Dictionary) -> Dictionary:
	var st := state(flags)
	# (the section being built is the live one: a room of its building, reloaded without the save's flags, rebuilds
	# the same desert)
	live = st
	return section_source(current(st), _variant_now(st), lock_variant(st, current(st)))


static func section_source(section: String, variant := "", lock := "ring") -> Dictionary:
	var src: Dictionary = Sections.SECTIONS[section].duplicate(true)
	# the lock's own ground (the duck pond's water)
	if src.has("ring") and lock == "ducks":
		var c := Vector2i(int(src["ring"]["center"][0]), int(src["ring"]["center"][1]))
		var rows: Array = src["rows"]
		for dy in range(-1, 2):
			var r: String = rows[c.y + dy]
			rows[c.y + dy] = r.substr(0, c.x - 1) + "~~~" + r.substr(c.x + 2)
	if src.has("ring"):
		src["ring"]["variant"] = lock
	for v in src.get("variants", []):
		if String(v["id"]) != variant:
			continue
		var rows: Array = src["rows"]
		for key in v.get("tiles", {}):
			var x := int(String(key).get_slice(",", 0))
			var y := int(String(key).get_slice(",", 1))
			var r: String = rows[y]
			rows[y] = r.substr(0, x) + String(v["tiles"][key]) + r.substr(x + 1)
		if v.has("signs"):
			src["signs"] = v["signs"]
		# (and any other property of its own: the approach's haze, map flags and the like)
		for key in v:
			if key in ["id", "flag", "unless", "tiles", "sights", "signs"]:
				continue
			src[key] = v[key]
	src["flag_id"] = ROUTE + "_" + section
	src["desert_section"] = section
	src["desert_variant"] = variant
	return src


static func _variant_now(st: Dictionary) -> String:
	if bool(st.get("edge", false)):
		return ""
	var v: Array = st.get("variants", [])
	var at := int(st["at"])
	return String(v[at]) if at < v.size() and v[at] != null else ""


## After parsing: the section's edges become seams. Their arrival tiles are worked out when they're crossed
## (desert_crossing.gd), so a placeholder "spawn" stands in. The first section's south edge stays the Mesa Trail's
## and the last one's north edge Scaraba's. In the edge, the way you came is a seam back, and the far side walks off.
static func fit_exits(m: Dictionary, flags: Dictionary) -> void:
	var st := state(flags)
	var n: int = st["list"].size()
	var at := int(st["at"])
	m["desert_section"] = current(st)
	m["desert_variant"] = _variant_now(st)
	# its set pieces (desert_sights.gd), and any its variant adds
	var sights: Array = Sections.SECTIONS.get(current(st), {}).get("sights", []).duplicate()
	for v in Sections.SECTIONS.get(current(st), {}).get("variants", []):
		if String(v["id"]) == m["desert_variant"]:
			sights.append_array(v.get("sights", []))
	m["desert_sights"] = sights
	var ring := ring_of(current(st))
	m["desert_ring"] = {} if ring.is_empty() else ring.merged({"variant": lock_variant(st, current(st))})
	for t: Vector2i in m["exits"].keys():
		var north := t.y == 0
		if not north and t.y != int(m["h"]) - 1:
			continue
		if bool(st.get("edge", false)):
			var onward_north := int(st["dir"]) > 0
			if north == onward_north:
				m["exits"][t] = {"to": ROUTE, "spawn": t, "desert_edge": true}
			else:
				m["exits"][t] = {"to": ROUTE, "spawn": t, "desert": -int(st["dir"])}
		elif north and at < n - 1:
			m["exits"][t] = {"to": ROUTE, "spawn": t, "desert": 1}
		elif not north and at > 0:
			m["exits"][t] = {"to": ROUTE, "spawn": t, "desert": -1}
	if bool(st.get("edge", false)):
		# nothing wild out where the road gives out: the walk-off never meets a battle
		m["encounter"] = {}


## Walking into the desert from outside, by `spawn`: its south end from the Mesa Trail, its north end from Scaraba,
## Valkoog's approach for "start". A tile (a save, a reload) keeps the section the hero stands in.
static func arrive(st: Dictionary, spawn, flags: Dictionary) -> Dictionary:
	var out := st.duplicate(true)
	if typeof(spawn) != TYPE_STRING and typeof(spawn) != TYPE_STRING_NAME:
		return out
	var list: Array = out["list"]
	match String(spawn):
		"south":
			out.merge({"at": 0, "dir": 1, "from": "route4", "edge": false}, true)
		"north":
			out.merge({"at": list.size() - 1, "dir": -1, "from": "sundown", "edge": false}, true)
		"start":
			out.merge({"at": maxi(list.find("valkoog"), 0), "dir": 1, "edge": false}, true)
		_:
			# (a section's own name: straight to it, for a screenshot or a debug jump)
			if not list.has(String(spawn)):
				return out
			out.merge({"at": list.find(String(spawn)), "dir": 1, "edge": false}, true)
	out["variants"][int(out["at"])] = variant_for(current(out), flags)
	return out


## Crossing a seam: `step` 1 north, -1 south. On past a join whose ring isn't solved (in the way the hero was going)
## is the edge; back from the edge is the join it opened off, still facing on. Only the section walked into takes a new variant.
static func cross(st: Dictionary, step: int, flags: Dictionary) -> Dictionary:
	var out := st.duplicate(true)
	var list: Array = out["list"]
	if bool(st.get("edge", false)):
		# (still going the way they were: on past the join again is the edge again)
		out.merge({"edge": false, "at": int(st["back"])}, true)
		return out
	var at := int(st["at"])
	var ring := ring_of(String(list[at]))
	if not ring.is_empty() and not ring_open(String(ring["id"]), flags) and step == int(st["dir"]):
		out.merge({"edge": true, "back": at, "dir": step}, true)
		return out
	var next := clampi(at + step, 0, list.size() - 1)
	out.merge({"at": next, "dir": step}, true)
	out["variants"][next] = variant_for(String(list[next]), flags)
	return out


## Where a walk-off returns the hero: the map they came in from, at its edge facing the desert.
static func return_to(st: Dictionary) -> String:
	var from := String(st.get("from", DEFAULT_FROM))
	return from if from in ["route4", "sundown"] else DEFAULT_FROM


## The list's promises (outline §2): the opening first and the oasis gate last, Valkoog between two joins, every id a
## known section, none twice, and a variant for every slot. Returns the problems found.
static func problems(st: Dictionary) -> Array:
	var out := []
	var list: Array = st.get("list", [])
	if list.is_empty() or list[0] != "opening":
		out.append("the desert doesn't start at the opening")
	if list.is_empty() or list[-1] != "oasis_gate":
		out.append("the desert doesn't end at the oasis gate")
	var a := list.find("join_a")
	var v := list.find("valkoog")
	var b := list.find("join_b")
	if a < 0 or v < 0 or b < 0 or not (a < v and v < b):
		out.append("Valkoog isn't between its two joins: %s" % [list])
	for id in list:
		if not Sections.SECTIONS.has(id):
			out.append("unknown section " + str(id))
		elif list.count(id) > 1:
			out.append("section twice: " + str(id))
		elif "edge" in Sections.SECTIONS[id]["tags"]:
			out.append("the edge is in the list")
	if st.get("variants", []).size() != list.size():
		out.append("a variant per slot")
	return out
