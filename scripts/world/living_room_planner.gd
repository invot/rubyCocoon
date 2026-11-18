extends RefCounted
## Pure opt-in placement on copied maps. Nothing calls this in ordinary gameplay yet.
const Templates = preload("res://scripts/data/living_room_templates.gd")
const Rooms = preload("res://scripts/gfx/room_builder.gd")
const Gen = preload("res://scripts/world/map_gen.gd")
const Elev = preload("res://scripts/world/elevation.gd")
const DIRS := [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT]
static var diagnostics := {}
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
	diagnostics = {"stage": "start", "fit": 0, "rug": 0, "seed": 0, "access": 0}
	var base := source.duplicate(true)
	base["room"]["home"] = true
	var studio := is_studio(base)
	if studio != (index in Templates.STUDIO_LAYOUTS):
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
	var old_seats := []
	var dressing := []
	for part in Rooms.furniture_groups(base):
		if part["kind"] == "sofa":
			old_seats.append_array(part["tiles"])
		if not part["kind"] in REPLACE:
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
		diagnostics["stage"] = "nightstands"
		return []
	if not _stage_bedroom_storage(base):
		diagnostics["stage"] = "bedroom storage"
		return []
	if not _prepare_cubbies(base):
		diagnostics["stage"] = "cubbies"
		return []
	diagnostics["stage"] = "placement"
	base["bed_rug_rects"] = bed_rugs(base)
	diagnostics["bedroom"] = str(_bedroom_area(base))
	diagnostics["bed_rugs"] = str(base["bed_rug_rects"])
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
			diagnostics["fit"] += 1
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
			if not facing_allowed(m, translated):
				continue
			var rug := _rug(m, Rect2i(origin, size))
			if not rug.has_area():
				continue
			diagnostics["rug"] += 1
			var rugs: Array = [rug] + m["bed_rug_rects"]
			room["rug_rects"] = rugs.map(func(r): return [r.position.x, r.position.y, r.size.x, r.size.y])
			if studio:
				var divider := _studio_divider(m, rug)
				if not divider.has_area():
					continue
				m["studio_divider"] = [divider.position.x, divider.position.y, divider.size.x, divider.size.y]
			var seeds_ok := true
			for rect: Rect2i in rugs:
				var seed_found := false
				for ry in range(rect.position.y, rect.end.y):
					for rx in range(rect.position.x, rect.end.x):
						var q := Vector2i(rx, ry)
						if not seed_found and Gen.walkable(Gen.get_t(m, rx, ry)) and not m["furniture"].has(q):
							m["furniture"][q] = "rug"
							Gen.set_t(m, rx, ry, Gen.RUG)
							seed_found = true
				seeds_ok = seeds_ok and seed_found
			if seeds_ok:
				diagnostics["seed"] += 1
			var placement_protected := _protected(m, protected_walls)
			if not seeds_ok:
				continue
			var side_issues := side_table_problems(m)
			if not side_issues.is_empty():
				diagnostics["last"] = side_issues
				continue
			if not _place_residents(m, movable_residents, placement_protected):
				diagnostics["last"] = "resident relocation"
				continue
			var access_issues := access_problems(m)
			if not access_issues.is_empty():
				diagnostics["last"] = access_issues
				continue
			diagnostics["access"] += 1
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
	for p in divider_tiles(m):
		out[p] = true
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
	var doors: Array = m["exits"].keys() + walls + m["room"].get("cubby_sources", {}).keys()
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
				if fits and (not is_studio(m) or _studio_divider(m, rect).has_area()) and distance < score:
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
	shelves = shelves.duplicate()
	shelves.append_array(m["room"].get("cubby_sources", {}).keys())
	var seen := flood(m)
	for p in divider_tiles(m):
		if not seen.has(p) or m["furniture"].has(p) or m["npcs"].any(func(n): return n["pos"] == p):
			out.append("Studio dividing passage is obstructed at %s" % p)
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
		if part["kind"] in ["phone", "mirror", "bed", "nightstand", "bookshelf", "storage", "dresser"] and not _beside(seen, part["tiles"]):
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


static func _prepare_cubbies(m: Dictionary) -> bool:
	var remapped := {}
	for original in m["room"].get("trial_cubby_origins", []):
		var choices := []
		for x in range(2, int(m["w"]) - 2):
			var p := Vector2i(x, 0)
			if not [x - 1, x, x + 1].all(func(cx): return Gen.get_t(m, cx, 0) == Gen.IWALL):
				continue
			if not Gen.walkable(Gen.get_t(m, x, 1)) or m["furniture"].has(Vector2i(x, 1)):
				continue
			if remapped.keys().any(func(q): return absi(q.x - x) <= 2):
				continue
			if m["room"].get("closets", []).any(func(c): return x >= c[0] - 1 and x <= c[0] + c[2]):
				continue
			choices.append(p)
		choices.sort_custom(func(a, b): return Vector2(a - original).length_squared() < Vector2(b - original).length_squared())
		if choices.is_empty():
			return false
		remapped[choices[0]] = original
	m["room"]["cubby_sources"] = remapped
	return true


static func _bounds(tiles: Array) -> Rect2i:
	if tiles.is_empty():
		return Rect2i()
	var lo := Vector2i(tiles[0])
	var hi := lo
	for p in tiles:
		lo = Vector2i(mini(lo.x, p.x), mini(lo.y, p.y))
		hi = Vector2i(maxi(hi.x, p.x), maxi(hi.y, p.y))
	return Rect2i(lo, hi - lo + Vector2i.ONE)

static func _stage_bedroom_storage(m: Dictionary) -> bool:
	var anchor_tiles := []
	var storage := []
	for part in Rooms.furniture_groups(m):
		if part["kind"] in ["bed", "bunk", "nightstand"]:
			anchor_tiles.append_array(part["tiles"])
		elif part["kind"] in ["dresser", "storage"]:
			storage.append(part)
	if anchor_tiles.is_empty():
		return true
	var bedroom := _bounds(anchor_tiles)
	for part in storage:
		for q in part["tiles"]:
			m["furniture"].erase(q)
			Gen.set_t(m, q.x, q.y, Gen.IFLOOR)
	for part in storage:
		var choices := []
		for size in [Vector2i(2, 1), Vector2i(1, 2)]:
			for y in range(1, int(m["h"]) - size.y):
				for x in range(1, int(m["w"]) - size.x):
					if x < bedroom.position.x or x + size.x > bedroom.end.x:
						continue
					var cells := []
					var valid := true
					for dy in size.y:
						for dx in size.x:
							var q := Vector2i(x + dx, y + dy)
							valid = valid and Gen.get_t(m, q.x, q.y) in [Gen.IFLOOR, Gen.ITILE] and not m["furniture"].has(q) and not q in m["spawns"].values()
							cells.append(q)
					var storage_layout := Rooms.furniture_layout(m, part["kind"], cells)
					if not valid or not storage_layout["against"] or storage_layout["back"] == Vector2i.DOWN:
						continue
					var merged := bedroom.merge(Rect2i(Vector2i(x, y), size))
					var score: float = merged.size.x * merged.size.y + Vector2(cells[0] - part["tiles"][0]).length_squared() * 0.02
					choices.append({"tiles": cells, "score": score})
		choices.sort_custom(func(a, b): return a["score"] < b["score"])
		var placed := false
		for candidate in choices:
			for q in candidate["tiles"]:
				m["furniture"][q] = part["kind"]
				Gen.set_t(m, q.x, q.y, Gen.FURN)
			if side_table_problems(m).is_empty() and access_problems(m).is_empty():
				placed = true
				break
			for q in candidate["tiles"]:
				m["furniture"].erase(q)
				Gen.set_t(m, q.x, q.y, Gen.IFLOOR)
		if not placed:
			return false
	return true

static func bed_rugs(m: Dictionary) -> Array:
	var rugs := []
	for part in Rooms.furniture_groups(m):
		if not part["kind"] in ["bed", "bunk"]:
			continue
		var tiles: Array = part["tiles"].duplicate()
		for slot in bedside_slots(m):
			if part["tiles"].any(func(p): return maxi(absi(slot.x - p.x), absi(slot.y - p.y)) <= 1):
				tiles.append(slot)
		var core := _bounds(tiles)
		var best := Rect2i()
		var score := INF
		for size in [Vector2i(3, 2), Vector2i(2, 3), Vector2i(4, 3), Vector2i(3, 4), Vector2i(5, 4), Vector2i(4, 5)]:
			if size.x < core.size.x or size.y < core.size.y:
				continue
			for y in range(maxi(1, core.end.y - size.y), mini(core.position.y, int(m["h"]) - size.y - 1) + 1):
				for x in range(maxi(1, core.end.x - size.x), mini(core.position.x, int(m["w"]) - size.x - 1) + 1):
					var rect := Rect2i(Vector2i(x, y), size)
					var valid := true
					for ry in range(y, y + size.y):
						for rx in range(x, x + size.x):
							valid = valid and not Gen.get_t(m, rx, ry) in Rooms.RUG_BLOCKED
					var distance: float = size.x * size.y + Vector2(rect.get_center() - core.get_center()).length_squared()
					if valid and distance < score and not rugs.any(func(other): return other.intersects(rect)):
						best = rect
						score = distance
		if best.has_area():
			rugs.append(best)
	return rugs

static func _bedroom_area(m: Dictionary) -> Rect2i:
	var tiles := []
	for p in m["furniture"]:
		if m["furniture"][p] in ["bed", "bunk", "nightstand", "dresser", "storage"]:
			tiles.append(p)
	var area := _bounds(tiles)
	for rug: Rect2i in m.get("bed_rug_rects", []):
		area = area.merge(rug)
	return area

static func _studio_divider(m: Dictionary, living: Rect2i) -> Rect2i:
	var bed := _bedroom_area(m)
	var start := Vector2i(mini(bed.position.x, living.position.x), mini(bed.position.y, living.position.y))
	var end := Vector2i(maxi(bed.end.x, living.end.x), maxi(bed.end.y, living.end.y))
	var strip := Rect2i()
	if living.position.x >= bed.end.x + 1:
		strip = Rect2i(bed.end.x, start.y, 1, end.y - start.y)
	elif bed.position.x >= living.end.x + 1:
		strip = Rect2i(bed.position.x - 1, start.y, 1, end.y - start.y)
	elif living.position.y >= bed.end.y + 1:
		strip = Rect2i(start.x, bed.end.y, end.x - start.x, 1)
	elif bed.position.y >= living.end.y + 1:
		strip = Rect2i(start.x, bed.position.y - 1, end.x - start.x, 1)
	if not strip.has_area():
		return strip
	for y in range(strip.position.y, strip.end.y):
		for x in range(strip.position.x, strip.end.x):
			if Gen.get_t(m, x, y) not in [Gen.IFLOOR, Gen.ITILE]:
				return Rect2i()
	return strip

static func divider_tiles(m: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r: Array = m.get("studio_divider", [])
	if r.size() == 4:
		for y in range(r[1], r[1] + r[3]):
			for x in range(r[0], r[0] + r[2]):
				out.append(Vector2i(x, y))
	return out

## The couch defines the group's main viewing direction. +z is the omitted front wall.
## Side-facing and north-facing groups must look inward toward the room's centre.
static func facing_allowed(m: Dictionary, recipe: Dictionary) -> bool:
	for p in recipe["pieces"]:
		if p[0] != "sofa":
			continue
		var angle := deg_to_rad(float(p[5]))
		var forward := Vector2(sin(angle), cos(angle))
		if forward.y > 0.7:
			return true
		var offset: Vector2 = m["room"].get("furniture_offsets", {}).get(Vector2i(p[1], p[2]), Vector2.ZERO)
		var sofa := Vector2(p[1] + p[3] / 2.0, p[2] + p[4] / 2.0) + offset
		return forward.dot(Vector2(m["w"] / 2.0, m["h"] / 2.0) - sofa) > 0.15
	return false
