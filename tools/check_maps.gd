extends SceneTree
## Verifies every map and every building interior:
## exits, doors, trainers, items and people reachable; all of a town's shops present.
## Run: godot --headless --path . --script res://tools/check_maps.gd

const MapGen = preload("res://scripts/world/map_gen.gd")
const MapLoader = preload("res://scripts/world/map_loader.gd")
const WorldDB = preload("res://scripts/data/world_db.gd")


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
