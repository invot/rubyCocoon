extends SceneTree
## Verifies every map and every building interior:
## exits, doors, trainers, items and people reachable (up and down ramps, never over a cliff: elevation.gd; onto a
## house's stairs only at their open end: RoomBuilder.stair_ways_in); all of a
## town's shops present; outdoors, nothing tall (a tree or a building) within HIDE_ROWS tiles south of a road or a
## person, where it would hide them from the camera (further on higher ground); buildings, doorsteps and people on
## level ground; and no way past a teacher without crossing their line of sight (see _slip_past).
## Run: godot --headless --path . --script res://tools/check_maps.gd

const MapGen = preload("res://scripts/world/map_gen.gd")
const MapLoader = preload("res://scripts/world/map_loader.gd")
const WorldDB = preload("res://scripts/data/world_db.gd")
const Elev = preload("res://scripts/world/elevation.gd")
const RoomBuilder = preload("res://scripts/gfx/room_builder.gd")

## The camera looks north from the south: a tree or a building this many tiles (or fewer) south of a road, a bridge,
## the plaza or someone standing about stands between them and the camera. (Trees in a map's last three rows are drawn
## as shrubs, see world.gd _build_scatter, so they don't count.)
const HIDE_ROWS := 3
const TALL := [MapGen.TREE, MapGen.BUILDING, MapGen.DOOR]
const ROADS := [MapGen.PATH, MapGen.PLAZA, MapGen.BRIDGE]
## The story's way-openers, all done: every map is checked as it is at the start and with these set.
const CLEARED := {"has_starter": true, "island_peace": true, "bandits_cleared": true, "ceo_defeated": true, "ritual_done": true,
	"sluice_reef": true, "tides_lever_1": true, "tides_lever_2": true, "tides_lever_3": true}


func _init() -> void:
	var ids := WorldDB.TOWNS.keys() + WorldDB.ROUTES.keys()
	var bad := 0
	var rooms := 0
	var cleared := CLEARED
	for flags in [{}, cleared]:
		for id in ids:
			var m := MapLoader.load_map(id, flags)
			var problems := _check(m)
			if WorldDB.TOWNS.has(id):
				var shops := []
				for b in m["buildings"]:
					shops.append(b["shop"])
				for s in WorldDB.TOWNS[id]["shops"]:
					if s != "house" and not shops.has(s):
						problems.append("missing shop " + s)
			for b in m["buildings"]:
				var floors := MapLoader.room_set(b).size()
				for f in range(1, floors + 1):
					var im := MapLoader.load_map(MapLoader.floor_id(b["interior"], f), flags)
					rooms += 1
					for p in _check(im):
						problems.append("[%s F%d] %s" % [b["name"], f, p])
					if im["exits"].is_empty():
						problems.append("[%s F%d] interior has no way out" % [b["name"], f])
			if problems.size() > 0:
				bad += 1
				print(id, " ", flags.keys(), ": ", problems)
			elif flags.is_empty():
				print("%-12s ok  %dx%d  buildings %d  npcs %d  trainers %d  exits %d" % [id, m["w"], m["h"], m["buildings"].size(), m["npcs"].size(),
					m["npcs"].filter(func(n): return n.get("kind", "") == "trainer").size(), m["exits"].size()])
	print("interiors checked: ", rooms)
	print("MAPS WITH PROBLEMS: ", bad)
	quit()


func _check(m: Dictionary) -> Array:
	var problems := []
	var start: Vector2i = m["spawns"].get("start", m["spawns"].values()[0])
	var seen := _flood(m, start)
	if m["kind"] == "interior":
		for door in m.get("front_doors", []):
			if door.x != 0 and door.x != int(m["w"]) - 1:
				problems.append("entrance must be in a visible side wall: %s" % door)
		for door in m["exits"]:
			if door.y == int(m["h"]) - 1:
				problems.append("entrance on the missing front wall: %s" % door)
		# Locked rooms still need an accessible doorway, so the player can read/knock on them.
		for y in int(m["h"]):
			for x in int(m["w"]):
				if MapGen.get_t(m, x, y) != MapGen.LOCKED:
					continue
				var reachable := false
				for d in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
					reachable = reachable or seen.has(Vector2i(x, y) + d)
				# Staff-only doors can open into enclosed service areas, behind the counter.
				if not reachable and not m.get("staff_doors", {}).has(Vector2i(x, y)):
					problems.append("locked door at %s has no reachable approach" % Vector2i(x, y))
	for k in m["spawns"]:
		if m["spawns"][k].x < 0:
			continue
		if not seen.has(m["spawns"][k]):
			problems.append("spawn %s %s unreachable" % [k, m["spawns"][k]])
	# (a house's stairs are gone onto at their open end only, so only that tile of them need be reached)
	var stairs := RoomBuilder.stair_ways_in(m)
	for e in m["exits"]:
		if stairs.has(e) and (stairs[e] as Array).is_empty():
			continue
		if not seen.has(e):
			problems.append("exit %s unreachable" % e)
		# a door through to another of the building's rooms comes out at that room's door back (a way back that a
		# drained pool opens counts)
		var to_spawn = m["exits"][e].get("spawn", "")
		if typeof(to_spawn) == TYPE_STRING and String(to_spawn).begins_with("from_") \
				and not MapLoader.load_map(m["exits"][e]["to"], {})["spawns"].has(to_spawn) \
				and not MapLoader.load_map(m["exits"][e]["to"], CLEARED)["spawns"].has(to_spawn):
			problems.append("door %s: %s has no door back" % [e, m["exits"][e]["to"]])
	# a telephone (calling Dad saves the game) must be somewhere you can stand beside
	var phones: Array = m.get("furniture", {}).keys().filter(func(f): return m["furniture"][f] == "phone")
	if m.has("payphone"):
		phones.append(m["payphone"])
	if m.has("counter_phone"):
		phones.append(m["counter_phone"])
	for f in phones:
		var ok := false
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			ok = ok or seen.has(f + d) and Elev.joined(m, f + d, f)
		if not ok:
			problems.append("phone at %s can't be reached" % f)
	for b in m["buildings"]:
		var front: Vector2i = b["door"] + Vector2i(0, 1)
		if not seen.has(front):
			problems.append("door of %s unreachable" % b["name"])
	for n in m["npcs"]:
		if m["kind"] == "interior" and MapLoader.faces_wall(m, n["pos"], n.get("facing", Vector2i(0, 1))):
			problems.append("%s at %s faces a wall" % [n.get("name", n.get("kind", "npc")), n["pos"]])
		# next to them, or across a counter from them (staff always stand behind one)
		var adj := false
		var walled_in := true
		for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var q: Vector2i = n["pos"] + d
			# (beside them on their level: nobody talks up or down a cliff)
			if seen.has(q) and Elev.joined(m, q, n["pos"]):
				adj = true
				walled_in = false
			elif MapGen.get_t(m, q.x, q.y) in [MapGen.COUNTER, MapGen.CRYSTAL, MapGen.TABLE] and seen.has(q + d):
				adj = true
		var staff: bool = n.get("kind", "") == "keeper" or n.get("id", "") in ["center_guide", "kennel_keeper", "receptionist"]
		# (staff who walk about the room, like the Beast Center's guide, are meant to be walked up to)
		# The Sky Tower ticket desk is intentionally a straight counter with open ends.
		var at: Vector2i = n["pos"]
		var open_desk: bool = m.get("room_key", "") == "skytower" and MapGen.get_t(m, at.x, at.y + 1) == MapGen.COUNTER
		if m["kind"] == "interior" and staff and not walled_in and not n.get("roam", false) and not open_desk:
			problems.append("%s at %s can be walked up to; staff belong behind a counter" % [n.get("name", "keeper"), n["pos"]])
		if not adj:
			problems.append("%s at %s unreachable" % [n.get("kind", "npc"), n["pos"]])
	for sh in m.get("shards", []):
		var adj3 := false
		for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			if seen.has(sh["pos"] + d) and Elev.joined(m, sh["pos"] + d, sh["pos"]):
				adj3 = true
		if not adj3:
			problems.append("shard at %s unreachable" % sh["pos"])
	if m["kind"] != "interior":
		problems.append_array(_hidden(m))
		problems.append_array(_levels(m))
	else:
		problems.append_array(_windows(m))
		problems.append_array(_beds(m))
		problems.append_array(_staging(m))
		problems.append_array(_rugs(m))
	problems.append_array(_slip_past(m))
	var groups := {}
	for q in m.get("obstacles", {}):
		groups[m["obstacles"][q]["flag"]] = m["obstacles"][q]
	for f in groups:
		var touch := false
		for q in groups[f]["tiles"]:
			for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
				var r: Vector2i = q + d
				if seen.has(r) and not m["obstacles"].has(r) and Elev.joined(m, r, q):
					touch = true
		if not touch:
			problems.append("obstacle %s can't be reached" % groups[f]["name"])
	# levers and treasure chests (Story.extra_npcs): each in reach, and no lever behind the water it drains
	for lv in m.get("levers", []):
		var own := {}
		for q in m.get("flood_wet", {}):
			if m["flood_wet"][q] == lv["flag"]:
				own[q] = true
		var dry_way := _flood(m, start, own) if not own.is_empty() else seen
		if not _beside(m, dry_way, lv["pos"]):
			problems.append("lever %s at %s can't be reached without crossing its own water" % [lv["flag"], lv["pos"]])
	for ch in m.get("chests", []):
		if not _beside(m, seen, ch["pos"]):
			problems.append("chest at %s unreachable" % ch["pos"])
	for it in m["items"]:
		var adj2 := false
		for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			if seen.has(it["pos"] + d) and Elev.joined(m, it["pos"] + d, it["pos"]):
				adj2 = true
		if not adj2:
			problems.append("item at %s unreachable" % it["pos"])
	return problems


## Roads (and their bridges and the washed-out ones), and the people on the map, with something tall just south of
## them: one problem per stretch of road, naming its tiles.
func _hidden(m: Dictionary) -> Array:
	var spots := {}
	for y in m["h"]:
		for x in m["w"]:
			var c := MapGen.get_t(m, x, y)
			if c in ROADS or (c == MapGen.OBSTACLE and m["obstacles"].has(Vector2i(x, y)) and m["obstacles"][Vector2i(x, y)]["kind"] == "broken_bridge"):
				spots[Vector2i(x, y)] = "road"
	for n in m["npcs"]:
		spots[n["pos"]] = n.get("name", n.get("kind", "someone"))
	# the story's people (teachers, chiefs, the mascot...) stand on the map's anchors
	for a in m.get("anchors", {}):
		if not a in ["puzzle_exit", "dock"]:
			spots[m["anchors"][a]] = a
	var hidden := {}
	for p in spots:
		# (something on higher ground hides you from further away: the camera looks down about 0.64 a tile)
		var reach := HIDE_ROWS + ceili(maxf(0.0, _highest_south(m, p, HIDE_ROWS + 6) - Elev.surface(m, p)) / 0.64)
		for dy in range(1, reach + 1):
			var q: Vector2i = p + Vector2i(0, dy)
			var c := MapGen.get_t(m, q.x, q.y)
			var rise := maxf(0.0, Elev.surface(m, q) - Elev.surface(m, p))
			if dy > HIDE_ROWS + ceili(rise / 0.64):
				continue
			if q.y < m["h"] and c in TALL and not (c == MapGen.TREE and (q.y >= m["h"] - 3 or _low_wood(m, q))):
				hidden[p] = q
				break
	var out := []
	var people := []
	var road := []
	for p in hidden:
		if spots[p] == "road":
			road.append(p)
		else:
			people.append("%s at %s hidden by %s" % [spots[p], p, "a tree" if MapGen.get_t(m, hidden[p].x, hidden[p].y) == MapGen.TREE else "a building"])
	if not road.is_empty():
		road.sort()
		out.append("road hidden behind something tall at %s" % ", ".join(road.map(func(t): return "%d,%d" % [t.x, t.y])))
	out.append_array(people)
	return out


## A room's wall with a door through to another room in it (one that opens or a locked one; not the front door, out
## to the street) has no windows; and every stage room (a house's or a shop's) has windows in at least one wall.
func _windows(m: Dictionary) -> Array:
	var out := []
	var w: int = m["w"]
	var h: int = m["h"]
	# the back wall and the two side walls (the bottom row is the open front)
	var walls := {"back": [], "left": [], "right": []}
	for x in w:
		walls["back"].append(Vector2i(x, 0))
	for y in h - 1:
		walls["left"].append(Vector2i(0, y))
		walls["right"].append(Vector2i(w - 1, y))
	var lit := 0
	for k in walls:
		var doors := 0
		var windows := 0
		for p in walls[k]:
			var c := MapGen.get_t(m, p.x, p.y)
			if c == MapGen.LOCKED or c == MapGen.IDOOR and not m.get("front_doors", []).has(p):
				doors += 1
			elif c == MapGen.IWINDOW:
				windows += 1
		if doors > 0 and windows > 0:
			out.append("%s has windows in its %s wall, beside a door to another room" % [m.get("room_key", m["id"]), k])
		elif windows > 0:
			lit += 1
	if m.get("stage", false) and lit == 0:
		out.append("%s has no wall with windows" % m.get("room_key", m["id"]))
	return out


## Every area rug has an approved rectangular footprint, with no lost rugs or covered stairwells/walls.
func _rugs(m: Dictionary) -> Array:
	var out := []
	var expected := RoomBuilder.furniture_groups(m).filter(func(part): return part["kind"] == "rug").size()
	var rugs := RoomBuilder.rug_rectangles(m)
	if rugs.size() != expected:
		out.append("%s: only %d of %d area rugs fit" % [m.get("room_key", m["id"]), rugs.size(), expected])
	for rug in rugs:
		if not rug.size in RoomBuilder.RUG_SIZES and not Vector2i(rug.size.y, rug.size.x) in RoomBuilder.RUG_SIZES:
			out.append("area rug has an unapproved footprint: %s" % rug)
		for y in range(rug.position.y, rug.end.y):
			for x in range(rug.position.x, rug.end.x):
				if MapGen.get_t(m, x, y) in RoomBuilder.RUG_BLOCKED:
					out.append("area rug covers a wall, stair or hazard at %s" % Vector2i(x, y))
	return out


## End-on staging: see docs/interior_staging.md. Uses the renderer's grouping and facing decisions.
func _staging(m: Dictionary) -> Array:
	var out := []
	var label: String = m.get("room_key", m["id"])
	for part in RoomBuilder.furniture_groups(m):
		var kind: String = part["kind"]
		var layout := RoomBuilder.furniture_layout(m, kind, part["tiles"])
		var lo: Vector2i = layout["lo"]
		var size: Vector2 = layout["size"]
		var back: Vector2i = layout["back"]
		if kind in ["sofa", "armchair"] and back == Vector2i(0, 1):
			out.append("%s's %s at %s turns away from the camera" % [label, kind, lo])
		if kind == "armchair":
			for side in [Vector2i.LEFT, Vector2i.RIGHT]:
				var wall: Vector2i = lo + side
				if RoomBuilder._walled(m, wall) and back != side:
					out.append("%s's side-wall armchair at %s must face into the room" % [label, lo])
		if not m.get("stage", false):
			continue
		if kind == "tv":
			out.append("%s's TV belongs on the implied fourth wall" % label)
		# Tall casework belongs upstage or in the side wings, never across the playing area.
		if kind in ["bookshelf", "shelf", "wardrobe", "storage", "pantry", "fridge", "bunk"]:
			if lo.y > 1 and lo.x > 1 and lo.x + size.x < int(m["w"]) - 1:
				out.append("%s's %s at %s blocks the central stage; use the back or side wall" % [label, kind, lo])
			if back == Vector2i(0, 1):
				out.append("%s's %s at %s presents its back to the camera" % [label, kind, lo])
		# A dining/desk chair can be in profile or face the audience; tables must be staged around that.
		if RoomBuilder.KINDS[kind].get("chair", false) and back == Vector2i(0, 1):
			out.append("%s's chair at %s faces away; move it to the side or behind its table" % [label, lo])
	if m.get("stage", false):
		for y in range(2, int(m["h"]) - 1):
			for x in range(2, int(m["w"]) - 2):
				if MapGen.get_t(m, x, y) in [MapGen.ORGAN, MapGen.PILLAR]:
					out.append("%s's tall scenery at %s belongs upstage or at the sides" % [label, Vector2i(x, y)])
		for n in m["npcs"]:
			if n.get("sit", false) and n.get("facing", Vector2i.ZERO) == Vector2i(0, -1):
				out.append("%s's seated patron at %s has their back to the camera" % [label, n["pos"]])
	return out


## Every bed (and bunk) has a wall at its head: one along a short end of it, as RoomBuilder._place stands it. A bed
## with none (two tiles side by side along the back wall, say) is shrunk to fit its tiles the wrong way round.
func _beds(m: Dictionary) -> Array:
	var out := []
	var furn: Dictionary = m.get("furniture", {})
	var seen := {}
	for p in furn:
		if seen.has(p) or not RoomBuilder.KINDS.get(furn[p], {}).get("short", false):
			continue
		var group := []
		var stack := [p]
		seen[p] = true
		while not stack.is_empty():
			var q: Vector2i = stack.pop_back()
			group.append(q)
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not seen.has(q + d) and furn.get(q + d, "") == furn[p]:
					seen[q + d] = true
					stack.append(q + d)
		var lo: Vector2i = group[0]
		var hi: Vector2i = group[0]
		for q in group:
			lo = Vector2i(mini(lo.x, q.x), mini(lo.y, q.y))
			hi = Vector2i(maxi(hi.x, q.x), maxi(hi.y, q.y))
		var size := hi - lo + Vector2i.ONE
		var headed := false
		for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
			# (the side's length against the piece's length away from it: a head is a short end, or any side of a square)
			if (size.x if d.y != 0 else size.y) > (size.y if d.y != 0 else size.x):
				continue
			for q in group:
				var r: Vector2i = q + d
				if not group.has(r) and (MapGen.get_t(m, r.x, r.y) in RoomBuilder.WALLISH or r.x < 0 or r.y < 0):
					headed = true
		if not headed:
			out.append("%s's %s at %s (%dx%d) has no wall at its head" % [m.get("room_key", m["id"]), furn[p], lo, size.x, size.y])
	return out


## The highest ground within `rows` tiles south of p.
func _highest_south(m: Dictionary, p: Vector2i, rows: int) -> float:
	var top := Elev.surface(m, p)
	for dy in range(1, rows + 1):
		if p.y + dy < m["h"]:
			top = maxf(top, Elev.surface(m, p + Vector2i(0, dy)))
	return top


## Cliffs and ramps (elevation.gd): the heights rows read cleanly; every building on one level, with the tile in front
## of its door on that level too (not a ramp); people, items and signs on level ground, not on a ramp.
func _levels(m: Dictionary) -> Array:
	var out: Array = m.get("elev_problems", []).duplicate()
	if not Elev.has(m):
		return out
	for b in m["buildings"]:
		var door: Vector2i = b["door"]
		var lv := Elev.surface(m, door)
		var bad := false
		for y in range(int(b["y"]), int(b["y"]) + int(b["d"])):
			for x in range(int(b["x"]), int(b["x"]) + int(b["w"])):
				var q := Vector2i(x, y)
				bad = bad or Elev.ramp_dir(m, q) != Vector2i.ZERO or not is_equal_approx(Elev.surface(m, q), lv)
		var front := door + Vector2i(0, 1)
		if bad:
			out.append("%s at %s,%s stands on more than one level" % [b["name"], b["x"], b["y"]])
		elif not Elev.joined(m, door, front) or Elev.ramp_dir(m, front) != Vector2i.ZERO:
			out.append("%s's door at %s isn't on the level of the ground in front of it" % [b["name"], door])
	var spots := []
	for n in m["npcs"]:
		spots.append(n["pos"])
	for it in m["items"]:
		spots.append(it["pos"])
	spots.append_array(m["signs"].keys())
	if m.has("payphone"):
		spots.append(m["payphone"])
	for p in spots:
		if Elev.ramp_dir(m, p) != Vector2i.ZERO:
			out.append("something stands on the ramp at %s" % p)
	return out


## The teachers (WorldDB.LESSON_TRAINERS, ARENA_LESSONS) must stop you: outdoors, every way from one of the map's
## exits to another crosses each one's line of sight (as world.gd _check_trainer_sight sees it); indoors, they see you
## where you come in (world.gd spot_you).
func _slip_past(m: Dictionary) -> Array:
	var out := []
	var town: String = m.get("parent", m["id"])
	for t in WorldDB.LESSON_TRAINERS + WorldDB.ARENA_LESSONS:
		if not m.get("anchors", {}).has(t["anchor"]) or String(t.get("town", town)) != town:
			continue
		var p: Vector2i = m["anchors"][t["anchor"]]
		var who := "%s %s at %s" % [t["cls"], t["name"], p]
		# the teacher's own tile and what they can see from it
		var sight := {p: true}
		for i in range(1, int(t.get("sight", 4)) + 1):
			var q: Vector2i = p + Vector2i(t["facing"]) * i
			if not MapGen.walkable(MapGen.get_t(m, q.x, q.y)) or m["npcs"].any(func(n): return n["pos"] == q) 					or not Elev.joined(m, q - Vector2i(t["facing"]), q):
				break
			sight[q] = true
		if m["kind"] == "interior":
			if not sight.has(m["spawns"].get("entry", p)):
				out.append("%s doesn't see you come in" % who)
			continue
		# the map's ways in and out (an exit's tiles, side by side)
		var ways := {}
		for e in m["exits"]:
			var k := "%s %s" % [m["exits"][e]["to"], m["exits"][e]["spawn"]]
			if not ways.has(k):
				ways[k] = []
			ways[k].append(e)
		for w in ways:
			if sight.has(ways[w][0]):
				continue
			var seen := _flood(m, ways[w][0], sight)
			for v in ways:
				if v != w and (ways[v] as Array).any(func(e): return seen.has(e)):
					out.append("%s can be walked past, from %s to %s" % [who, ways[w][0], ways[v][0]])
	return out


## True if one of the tiles beside p, on its level, is in `seen`.
func _beside(m: Dictionary, seen: Dictionary, p: Vector2i) -> bool:
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		if seen.has(p + d) and Elev.joined(m, p + d, p):
			return true
	return false


## The tiles you can reach from start (avoid: tiles to keep off as well as the people and items).
func _flood(m: Dictionary, start: Vector2i, avoid := {}) -> Dictionary:
	var seen := {start: true}
	var q := [start]
	var blockers := avoid.duplicate()
	for n in m["npcs"]:
		if not n.get("vanish", false):
			blockers[n["pos"]] = true
	for it in m["items"] + m.get("levers", []) + m.get("chests", []):
		blockers[it["pos"]] = true
	var stairs := RoomBuilder.stair_ways_in(m)
	while not q.is_empty():
		var p: Vector2i = q.pop_front()
		for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var n: Vector2i = p + d
			if seen.has(n) or blockers.has(n) or not Elev.joined(m, p, n) or (stairs.has(n) and not p in stairs[n]):
				continue
			var c := MapGen.get_t(m, n.x, n.y)
			# obstacles and story gates can be cleared, and floods drained, so the area behind them counts as reachable
			if MapGen.walkable(c) or c == MapGen.OBSTACLE or c == MapGen.GATE or m.get("flood_wet", {}).has(n):
				seen[n] = true
				q.append(n)
	return seen


## Whether `p` is in one of the map's "low_trees" areas, whose tree tiles grow only low thickets of shrubs.
func _low_wood(m: Dictionary, p: Vector2i) -> bool:
	for r in m.get("low_trees", []):
		if Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])).has_point(p):
			return true
	return false
