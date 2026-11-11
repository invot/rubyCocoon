extends RefCounted
## Authored road fixtures. Stable names, rather than list indices, keep old solves intact when maps are edited.
const MG = preload("res://scripts/world/map_gen.gd")
const Elev = preload("res://scripts/world/elevation.gd")
const ItemDB = preload("res://scripts/data/item_db.gd")
const TYPES := {"bullseye": "slingshot", "bell": "slingshot", "switches": "boomerang", "cracked_rock": "bat", "stump": "bat"}
## Measured between all targets, barriers, rewards and tap approaches, not just the fixture centres.
const MIN_SPACING := 12.0


static func footprint(o: Dictionary) -> Array:
	var tiles: Array = [o["use_from"]]
	tiles.append_array(o["targets"])
	tiles.append_array(o.get("blocks", []))
	if o.has("reward"):
		tiles.append(o["reward"]["pos"])
	return tiles


static func distance_between(a: Dictionary, b: Dictionary) -> float:
	var nearest := INF
	for p: Vector2i in footprint(a):
		for q: Vector2i in footprint(b):
			nearest = minf(nearest, Vector2(p).distance_to(Vector2(q)))
	return nearest


static func flag_for(map_id: String, id: String) -> String:
	return "weapon_%s_%s" % [map_id, id]


static func place(m: Dictionary, definitions: Array, flags: Dictionary) -> void:
	m["weapon_obstacles"] = []
	m["weapon_targets"] = {}
	for definition in definitions:
		var o: Dictionary = definition.duplicate(true)
		o["flag"] = flag_for(m["id"], o["id"])
		o["weapon"] = TYPES.get(o["type"], "")
		o["solved"] = bool(flags.get(o["flag"], false))
		o["floors"] = {}
		for p in o.get("blocks", []):
			o["floors"][p] = MG.get_t(m, p.x, p.y)
			MG.set_t(m, p.x, p.y, (MG.ROPE if o.get("effect", "") == "ladder" else o["floors"][p]) if o["solved"] else MG.OBSTACLE)
		for p in o["targets"]:
			# A smashed rock/stump leaves its original floor; posts stay solid after use.
			if (o["weapon"] != "bat" or not o["solved"]) and MG.walkable(MG.get_t(m, p.x, p.y)):
				MG.set_t(m, p.x, p.y, MG.OBSTACLE)
			if not o["solved"]:
				m["weapon_targets"][p] = o
		var reward: Dictionary = o.get("reward", {})
		if not reward.is_empty():
			m["chests"].append({"pos": reward["pos"], "item": reward["item"], "flag": o["flag"] + "_chest", "hidden_until": o["flag"]})
		m["weapon_obstacles"].append(o)


static func solve(m: Dictionary, o: Dictionary) -> void:
	o["solved"] = true
	for p in o["targets"]:
		m["weapon_targets"].erase(p)
	for p in o.get("blocks", []):
		MG.set_t(m, p.x, p.y, MG.ROPE if o.get("effect", "") == "ladder" else o["floors"][p])


## The authored firing tile is the tap destination; A also works from any clear cardinal approach in range.
static func can_use(m: Dictionary, o: Dictionary, from: Vector2i, facing: Vector2i) -> bool:
	if o["solved"] or not MG.walkable(MG.get_t(m, from.x, from.y)):
		return false
	var ordered := shot_targets(o, from)
	var delta: Vector2i = ordered[0] - from
	var direction := Vector2i(signi(delta.x), signi(delta.y))
	if delta == Vector2i.ZERO or (delta.x != 0 and delta.y != 0) or facing != direction:
		return false
	if o["weapon"] == "bat":
		return absi(delta.x) + absi(delta.y) == 1 and Elev.joined(m, from, o["targets"][0])
	var previous := from
	for target: Vector2i in ordered:
		var line: Vector2i = target - previous
		if (target - from).length() > 7.0 or (line.x != 0 and line.y != 0) or Vector2i(signi(line.x), signi(line.y)) != direction or not clear_shot(m, previous, target, ordered):
			return false
		previous = target
	return true


static func shot_targets(o: Dictionary, from: Vector2i) -> Array:
	var ordered: Array = o["targets"].duplicate()
	if Vector2(from).distance_squared_to(ordered.back()) < Vector2(from).distance_squared_to(ordered.front()):
		ordered.reverse()
	return ordered


## Sample the projectile above the ground, including intermediate cliff faces. Water is a valid gap, trees aren't.
static func clear_shot(m: Dictionary, from: Vector2i, to: Vector2i, allowed_targets := []) -> bool:
	if MG.get_t(m, to.x, to.y) in [MG.TREE, MG.ROCK, MG.WALL, MG.BUILDING, MG.DOOR, MG.GATE]:
		return false
	var a := Vector3(from.x + 0.5, Elev.surface(m, from) + 1.15, from.y + 0.5)
	var b := Vector3(to.x + 0.5, Elev.surface(m, to) + 1.15, to.y + 0.5)
	var steps := maxi(1, ceili(a.distance_to(b) * 12.0))
	for i in range(1, steps):
		var v := a.lerp(b, float(i) / steps)
		var p := Vector2i(floori(v.x), floori(v.z))
		if p == from or p == to:
			continue
		if Elev.height_at(m, v.x, v.z) >= v.y - 0.08:
			return false
		if m.get("npcs", []).any(func(n): return n["pos"] == p and n.get("hidden_until", "") == ""):
			return false
		if m.get("weapon_targets", {}).has(p) and p not in allowed_targets:
			return false
		if MG.get_t(m, p.x, p.y) in [MG.TREE, MG.ROCK, MG.WALL, MG.BUILDING, MG.DOOR, MG.GATE, MG.OBSTACLE] and p not in allowed_targets:
			# The ladder being released lies below the shot.
			if MG.get_t(m, p.x, p.y) != MG.OBSTACLE or not m.get("weapon_obstacles", []).any(func(o): return o.get("effect", "") == "ladder" and p in o.get("blocks", [])):
				return false
	return true


static func hint(o: Dictionary, seen: bool) -> String:
	var descriptions := {"bullseye": "A bullseye waits beyond the gap.", "bell": "A bell hangs above the ledge.",
		"switches": "The switches line up across the water.", "cracked_rock": "Deep cracks run through this rock.", "stump": "This old stump is split down the middle."}
	var line: String = descriptions.get(o["type"], "Something blocks the way.")
	return line + (" You need the %s." % ItemDB.item_name(o["weapon"]) if seen else "")
