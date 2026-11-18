extends RefCounted
## Pure opt-in placement on copied maps. Nothing calls this in ordinary gameplay yet.
const Templates = preload("res://scripts/data/living_room_templates.gd")
const Rooms = preload("res://scripts/gfx/room_builder.gd")
const Gen = preload("res://scripts/world/map_gen.gd")
const Elev = preload("res://scripts/world/elevation.gd")
const Decor = preload("res://scripts/gfx/home_decor.gd")
const DIRS := [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT]
const REPLACE := ["sofa", "armchair", "coffee_table", "side_coffee_table", "rug", "table", "chair", "stool", "pouf", "basket", "plant", "floor_lamp", "cabinet", "bookshelf"]

static func turn(v: Vector2, quarters: int) -> Vector2:
	for i in posmod(quarters, 4):
		v = Vector2(-v.y, v.x)
	return v

static func oriented(index: int, quarters: int) -> Dictionary:
	var recipe: Dictionary = Templates.OPTIONS[index].duplicate(true)
	var original: Array = recipe["pieces"].duplicate(true)
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for p in recipe["pieces"]:
		var a := turn(Vector2(p[1], p[2]), quarters)
		var b := turn(Vector2(p[1] + p[3], p[2] + p[4]), quarters)
		var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y))
		var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y))
		p[1] = int(lo.x)
		p[2] = int(lo.y)
		p[3] = int(hi.x - lo.x)
		p[4] = int(hi.y - lo.y)
		p[5] = float(p[5]) - quarters * 90.0
		low = Vector2(minf(low.x, lo.x), minf(low.y, lo.y))
		high = Vector2(maxf(high.x, hi.x), maxf(high.y, hi.y))
	for p in recipe["pieces"]:
		p[1] -= int(low.x)
		p[2] -= int(low.y)
	var offsets := []
	for offset in recipe.get("offsets", []):
		for i in original.size():
			if original[i][1] == offset[0] and original[i][2] == offset[1]:
				var moved := turn(Vector2(offset[2], offset[3]), quarters)
				offsets.append([recipe["pieces"][i][1], recipe["pieces"][i][2], moved.x, moved.y])
	recipe["offsets"] = offsets
	recipe["size"] = Vector2i(high - low)
	recipe["quarters"] = quarters
	return recipe

static func candidates(source: Dictionary, index: int, quarters: int, protected_walls: Array = []) -> Array:
	var base := source.duplicate(true)
	base["room"]["home"] = true
	var studio := is_studio(base)
	if studio != (index in [0, 4]):
		return []
	_ensure_phone_visible(base)
	var movable_residents := []
	var kept_residents := []
	for n in base["npcs"]:
		if n.get("kind", "") == "resident" and not n["pos"] in base.get("anchors", {}).values():
			movable_residents.append(n)
		else:
			kept_residents.append(n)
	base["npcs"] = kept_residents
	var shelf_approaches := {}
	for p in protected_walls:
		for d in DIRS:
			shelf_approaches[p + d] = true
	var old_seats := []
	var dressing := []
	for part in Rooms.furniture_groups(base):
		if part["kind"] == "sofa":
			old_seats.append_array(part["tiles"])
		var shelf_blocker: bool = false # Bedside nightstands stay beside their beds.
		if not part["kind"] in REPLACE and not shelf_blocker:
			continue
		if part["kind"] in ["plant", "floor_lamp", "pouf", "basket", "bookshelf"]:
			dressing.append(part["kind"])
		for q in part["tiles"]:
			base["furniture"].erase(q)
			Gen.set_t(base, q.x, q.y, Gen.ITILE if base["floor"] == "tile" else Gen.IFLOOR)
		for field in ["furniture_yaws", "furniture_offsets", "furniture_tops"]:
			base["room"].get(field, {}).erase(part["tiles"][0])
	for y in base["h"]:
		for x in base["w"]:
			if Gen.get_t(base, x, y) == Gen.RUG:
				Gen.set_t(base, x, y, Gen.IFLOOR)
	base["room"].erase("rug_rects")
	if not _ensure_nightstands(base):
		return []
	var recipe := oriented(index, quarters)
	var protected := _protected(base, protected_walls)
	for slot in bedside_slots(base):
		protected[slot] = true
	var aim := Vector2(base["w"] * 0.5, base["h"] * 0.4)
	if not old_seats.is_empty():
		aim = Vector2.ZERO
		for q in old_seats:
			aim += Vector2(q) + Vector2(0.5, 0.5)
		aim /= old_seats.size()
	var plans := []
	var size: Vector2i = recipe["size"]
	for y in range(1, int(base["h"]) - size.y):
		for x in range(1, int(base["w"]) - size.x):
			var origin := Vector2i(x, y)
			var cells := {}
			var fits := true
			for p in recipe["pieces"]:
				for dy in int(p[4]):
					for dx in int(p[3]):
						var q := origin + Vector2i(p[1] + dx, p[2] + dy)
						if protected.has(q) or Gen.get_t(base, q.x, q.y) not in [Gen.IFLOOR, Gen.ITILE]:
							fits = false
						cells[q] = p[0]
			if not fits:
				continue
			var m := base.duplicate(true)
			var room: Dictionary = m["room"]
			room["home"] = true
			room["close_lounge"] = true
			room["living_template"] = {"id": recipe["id"], "quarters": quarters, "origin": origin, "studio": studio}
			room["furniture_yaws"] = room.get("furniture_yaws", {})
			room["furniture_offsets"] = room.get("furniture_offsets", {})
			room["furniture_tops"] = room.get("furniture_tops", {})
			m["living_cluster_tiles"] = cells.keys()
			for q in cells:
				m["furniture"][q] = cells[q]
				Gen.set_t(m, q.x, q.y, Gen.FURN)
			var translated := recipe.duplicate(true)
			for p in translated["pieces"]:
				p[1] += x
				p[2] += y
				var lo := Vector2i(p[1], p[2])
				room["furniture_yaws"][lo] = deg_to_rad(p[5])
				if p[0] == "side_coffee_table":
					room["furniture_tops"][lo] = [recipe["top"]]
			for offset in recipe["offsets"]:
				room["furniture_offsets"][origin + Vector2i(offset[0], offset[1])] = Vector2(offset[2], offset[3])
			var rug := _rug(m, Rect2i(origin, size))
			if not rug.has_area():
				continue
			room["rug_rects"] = [[rug.position.x, rug.position.y, rug.size.x, rug.size.y]]
			# A rug has a walkable placement seed, separate from the blocked furniture.
			var seed_found := false
			for ry in range(rug.position.y, rug.end.y):
				for rx in range(rug.position.x, rug.end.x):
					var q := Vector2i(rx, ry)
					if not seed_found and Gen.walkable(Gen.get_t(m, rx, ry)):
						m["furniture"][q] = "rug"
						Gen.set_t(m, rx, ry, Gen.RUG)
						seed_found = true
			if not seed_found or not side_table_problems(m).is_empty() or not _place_residents(m, movable_residents, protected) or not access_problems(m).is_empty():
				continue
			var centre := Vector2(origin) + Vector2(size) * 0.5
			plans.append({"map": m, "recipe": translated, "score": centre.distance_squared_to(aim), "dressing": dressing})
	plans.sort_custom(func(a, b): return a["score"] < b["score"])
	return plans

static func _ensure_phone_visible(m: Dictionary) -> void:
	# A phone over open floor was already suppressed by the home's waist-height rule.
	# Keep its complete stand/phone assembly, moving it to the nearest backed position
	# in these trial maps (the player's home already uses the position under its stairs).
	for old in m["furniture"].keys():
		if m["furniture"][old] != "phone" or not Rooms.behind_open(m, old, Vector2.ONE):
			continue
		var choices := []
		for y in range(1, int(m["h"]) - 1):
			for x in range(1, int(m["w"]) - 1):
				var p := Vector2i(x, y)
				if Gen.get_t(m, x, y) not in [Gen.IFLOOR, Gen.ITILE, Gen.RUG] or m["furniture"].has(p) or Rooms.behind_open(m, p, Vector2.ONE):
					continue
				if m["npcs"].any(func(n): return n["pos"] == p) or p in m["spawns"].values() or p in m.get("anchors", {}).values():
					continue
				choices.append(p)
		choices.sort_custom(func(a, b): return Vector2(a - old).length_squared() < Vector2(b - old).length_squared())
		if not choices.is_empty():
			var destination: Vector2i = choices[0]
			m["furniture"].erase(old)
			Gen.set_t(m, old.x, old.y, Gen.IFLOOR)
			m["furniture"][destination] = "phone"
			Gen.set_t(m, destination.x, destination.y, Gen.FURN)
			m["trial_phone_move"] = {"from": str(old), "to": str(destination)}

static func _protected(m: Dictionary, walls: Array) -> Dictionary:
	var out := {}
	for p in m["spawns"].values():
		out[p] = true
	for n in m["npcs"]:
		out[n["pos"]] = true
	for p in m.get("anchors", {}).values():
		out[p] = true
	for item in m["items"] + m.get("chests", []) + m.get("levers", []) + m.get("shards", []):
		out[item["pos"]] = true
	var stairs := Rooms.stair_ways_in(m)
	for p in stairs:
		for q in stairs[p]:
			out[q] = true
	var doors: Array = m["exits"].keys() + walls
	for y in m["h"]:
		for x in m["w"]:
			if Gen.get_t(m, x, y) == Gen.LOCKED:
				doors.append(Vector2i(x, y))
	for p in doors:
		for d in DIRS:
			if Gen.walkable(Gen.get_t(m, p.x + d.x, p.y + d.y)):
				out[p + d] = true
	return out

static func _rug(m: Dictionary, core: Rect2i) -> Rect2i:
	var best := Rect2i()
	var score := INF
	for size in [Vector2i(4, 3), Vector2i(3, 4), Vector2i(5, 4), Vector2i(4, 5), Vector2i(6, 5), Vector2i(5, 6)]:
		if size.x < core.size.x or size.y < core.size.y:
			continue
		for y in range(maxi(1, core.end.y - size.y), mini(core.position.y, int(m["h"]) - size.y - 1) + 1):
			for x in range(maxi(1, core.end.x - size.x), mini(core.position.x, int(m["w"]) - size.x - 1) + 1):
				var rect := Rect2i(Vector2i(x, y), size)
				var fits := true
				for ry in range(y, y + size.y):
					for rx in range(x, x + size.x):
						if Gen.get_t(m, rx, ry) in Rooms.RUG_BLOCKED or m["furniture"].get(Vector2i(rx, ry), "") in ["bed", "bunk"]:
							fits = false
				var distance: float = Vector2(rect.get_center() - core.get_center()).length_squared() + absf(size.x * size.y - (12.0 if is_studio(m) else 20.0)) * 0.35
				if fits and distance < score:
					best = rect
					score = distance
	return best

static func flood(m: Dictionary) -> Dictionary:
	var start: Vector2i = m["spawns"].get("entry", m["spawns"].values()[0])
	var blockers := {}
	for n in m["npcs"]:
		blockers[n["pos"]] = true
	for item in m["items"] + m.get("chests", []) + m.get("levers", []):
		blockers[item["pos"]] = true
	var stairs := Rooms.stair_ways_in(m)
	var seen := {start: true}
	var stack := [start]
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		for d in DIRS:
			var q: Vector2i = p + d
			if seen.has(q) or blockers.has(q) or not Gen.walkable(Gen.get_t(m, q.x, q.y)) or not Elev.joined(m, p, q):
				continue
			if stairs.has(q) and not p in stairs[q]:
				continue
			seen[q] = true
			stack.append(q)
	return seen

static func _beside(seen: Dictionary, tiles: Array) -> bool:
	for p in tiles:
		for d in DIRS:
			if seen.has(p + d):
				return true
	return false

static func access_problems(m: Dictionary, shelves: Array = []) -> Array[String]:
	var out: Array[String] = []
	var seen := flood(m)
	var stairs := Rooms.stair_ways_in(m)
	for p in m["spawns"].values():
		if p.x >= 0 and not seen.has(p):
			out.append("arrival unreachable at %s" % p)
	for p in m["exits"]:
		if not (stairs.has(p) and stairs[p].is_empty()) and not seen.has(p):
			out.append("door/stairs unreachable at %s" % p)
	for n in m["npcs"]:
		if not _beside(seen, [n["pos"]]):
			out.append("resident unreachable at %s" % n["pos"])
	for p in m.get("anchors", {}).values():
		if not seen.has(p) and not _beside(seen, [p]):
			out.append("story object unreachable at %s" % p)
	for item in m["items"] + m.get("chests", []) + m.get("levers", []) + m.get("shards", []):
		if not _beside(seen, [item["pos"]]):
			out.append("pickup unreachable at %s" % item["pos"])
	for part in Rooms.furniture_groups(m):
		if part["kind"] in ["phone", "mirror", "bed", "bookshelf", "storage", "dresser"] and not _beside(seen, part["tiles"]):
			out.append("%s unreachable at %s" % [part["kind"], part["tiles"][0]])
	for y in m["h"]:
		for x in m["w"]:
			var p := Vector2i(x, y)
			if Gen.get_t(m, x, y) == Gen.LOCKED and not _beside(seen, [p]):
				out.append("locked door unreachable at %s" % p)
	for p in shelves:
		if not _beside(seen, [p]):
			out.append("sliding shelf unreachable at %s" % p)
	return out


static func _place_residents(m: Dictionary, residents: Array, protected: Dictionary) -> bool:
	for original in residents:
		var choices := []
		for y in range(1, int(m["h"]) - 1):
			for x in range(1, int(m["w"]) - 1):
				var p := Vector2i(x, y)
				if Gen.walkable(Gen.get_t(m, x, y)) and not protected.has(p) and not m["npcs"].any(func(n): return n["pos"] == p):
					choices.append(p)
		choices.sort_custom(func(a, b): return Vector2(a - original["pos"]).length_squared() < Vector2(b - original["pos"]).length_squared())
		var placed := false
		for p in choices:
			var n: Dictionary = original.duplicate(true)
			n["pos"] = p
			m["npcs"].append(n)
			if access_problems(m).is_empty():
				placed = true
				break
			m["npcs"].pop_back()
		if not placed:
			return false
	return true


## A bed sharing the living-room floor makes this a studio, regardless of the building's name.
static func is_studio(m: Dictionary) -> bool:
	return m.get("furniture", {}).values().any(func(kind): return kind in ["bed", "bunk"])

const SIDE_TABLE_FAMILY := ["nightstand", "side_coffee_table", "cabinet", "bookshelf", "dresser", "storage", "phone"]

## Model width, decoration and mesh names do not distinguish neighbouring side/storage units.
static func side_table_problems(m: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var groups: Array = Rooms.furniture_groups(m).filter(func(p): return p["kind"] in SIDE_TABLE_FAMILY)
	for i in groups.size():
		for j in range(i + 1, groups.size()):
			var adjacent := false
			for a in groups[i]["tiles"]:
				for b in groups[j]["tiles"]:
					adjacent = adjacent or maxi(absi(a.x - b.x), absi(a.y - b.y)) <= 1
			if adjacent:
				out.append("Neighbouring side/storage furniture: %s at %s / %s at %s" % [groups[i]["kind"], groups[i]["tiles"][0], groups[j]["kind"], groups[j]["tiles"][0]])
	return out

## The two head-side positions of each bed; a side physically against a wall is a corner exemption.
static func bedside_slots(m: Dictionary) -> Array[Vector2i]:
	var slots: Array[Vector2i] = []
	for part in Rooms.furniture_groups(m):
		if not part["kind"] in ["bed", "bunk"]:
			continue
		var layout := Rooms.furniture_layout(m, part["kind"], part["tiles"])
		var back: Vector2i = layout["back"]
		if back == Vector2i.ZERO:
			continue
		var side := Vector2i(-back.y, back.x)
		var head: Array = part["tiles"].filter(func(q): return not (q + back) in part["tiles"])
		head.sort_custom(func(a, b): return Vector2(a).dot(Vector2(side)) < Vector2(b).dot(Vector2(side)))
		for p in [head[0] - side, head[-1] + side]:
			if Gen.get_t(m, p.x, p.y) in Rooms.WALLISH or Gen.get_t(m, p.x, p.y) == Gen.IVOID:
				continue
			slots.append(p)
	return slots

static func bedside_problems(m: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for p in bedside_slots(m):
		if m["furniture"].get(p, "") != "nightstand":
			out.append("Missing bedside nightstand at %s" % p)
	return out

static func _ensure_nightstands(m: Dictionary) -> bool:
	for p in bedside_slots(m):
		if m["furniture"].get(p, "") == "nightstand":
			continue
		if not Gen.walkable(Gen.get_t(m, p.x, p.y)) or m["npcs"].any(func(n): return n["pos"] == p) or p in m.get("anchors", {}).values():
			return false
		m["furniture"][p] = "nightstand"
		Gen.set_t(m, p.x, p.y, Gen.FURN)
	return true
