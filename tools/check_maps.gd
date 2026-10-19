extends SceneTree
## Verifies every map and every building interior:
## exits, doors, trainers, items and people reachable; all of a town's shops present; and outdoors, nothing tall
## (a tree or a building) within HIDE_ROWS tiles south of a road or a person, where it would hide them from the camera.
## Run: godot --headless --path . --script res://tools/check_maps.gd

const MapGen = preload("res://scripts/world/map_gen.gd")
const MapLoader = preload("res://scripts/world/map_loader.gd")
const WorldDB = preload("res://scripts/data/world_db.gd")

## The camera looks north from the south: a tree or a building this many tiles (or fewer) south of a road, a bridge,
## the plaza or someone standing about stands between them and the camera. (Trees in a map's last three rows are drawn
## as shrubs, see world.gd _build_scatter, so they don't count.)
const HIDE_ROWS := 3
const TALL := [MapGen.TREE, MapGen.BUILDING, MapGen.DOOR]
const ROADS := [MapGen.PATH, MapGen.PLAZA, MapGen.BRIDGE]


func _init() -> void:
	var ids := WorldDB.TOWNS.keys() + WorldDB.ROUTES.keys()
	var bad := 0
	var rooms := 0
	var cleared := {"has_starter": true, "island_peace": true, "bandits_cleared": true, "ceo_defeated": true, "ritual_done": true}
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
	for k in m["spawns"]:
		if m["spawns"][k].x < 0:
			continue
		if not seen.has(m["spawns"][k]):
			problems.append("spawn %s %s unreachable" % [k, m["spawns"][k]])
	for e in m["exits"]:
		if not seen.has(e):
			problems.append("exit %s unreachable" % e)
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
			if seen.has(q):
				adj = true
				walled_in = false
			elif MapGen.get_t(m, q.x, q.y) in [MapGen.COUNTER, MapGen.CRYSTAL, MapGen.TABLE] and seen.has(q + d):
				adj = true
		var staff: bool = n.get("kind", "") == "keeper" or n.get("id", "") in ["center_guide", "kennel_keeper", "receptionist"]
		# (staff who walk about the room, like the Beast Center's guide, are meant to be walked up to)
		if m["kind"] == "interior" and staff and not walled_in and not n.get("roam", false):
			problems.append("%s at %s can be walked up to; staff belong behind a counter" % [n.get("name", "keeper"), n["pos"]])
		if not adj:
			problems.append("%s at %s unreachable" % [n.get("kind", "npc"), n["pos"]])
	for sh in m.get("shards", []):
		var adj3 := false
		for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			if seen.has(sh["pos"] + d):
				adj3 = true
		if not adj3:
			problems.append("shard at %s unreachable" % sh["pos"])
	if m["kind"] != "interior":
		problems.append_array(_hidden(m))
	var groups := {}
	for q in m.get("obstacles", {}):
		groups[m["obstacles"][q]["flag"]] = m["obstacles"][q]
	for f in groups:
		var touch := false
		for q in groups[f]["tiles"]:
			for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
				var r: Vector2i = q + d
				if seen.has(r) and not m["obstacles"].has(r):
					touch = true
		if not touch:
			problems.append("obstacle %s can't be reached" % groups[f]["name"])
	for it in m["items"]:
		var adj2 := false
		for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			if seen.has(it["pos"] + d):
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
		for dy in range(1, HIDE_ROWS + 1):
			var q: Vector2i = p + Vector2i(0, dy)
			var c := MapGen.get_t(m, q.x, q.y)
			if q.y < m["h"] and c in TALL and not (c == MapGen.TREE and q.y >= m["h"] - 3):
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


func _flood(m: Dictionary, start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var q := [start]
	var blockers := {}
	for n in m["npcs"]:
		if not n.get("vanish", false):
			blockers[n["pos"]] = true
	for it in m["items"]:
		blockers[it["pos"]] = true
	while not q.is_empty():
		var p: Vector2i = q.pop_front()
		for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var n: Vector2i = p + d
			if seen.has(n) or blockers.has(n):
				continue
			var c := MapGen.get_t(m, n.x, n.y)
			# obstacles and story gates can be cleared, so the area behind them counts as reachable
			if MapGen.walkable(c) or c == MapGen.OBSTACLE or c == MapGen.GATE:
				seen[n] = true
				q.append(n)
	return seen
