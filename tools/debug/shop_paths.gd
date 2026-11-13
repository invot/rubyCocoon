extends RefCounted
## Deterministic navigation regressions, without loading or saving player state.
const World = preload("res://scripts/world/world.gd")
const MG = preload("res://scripts/world/map_gen.gd")
const ML = preload("res://scripts/world/map_loader.gd")
const DB = preload("res://scripts/data/world_db.gd")
var bad := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		bad += 1
		print("FAIL ", label)

func run(_main, _opts: Dictionary) -> void:
	var w = World.new()
	var grid := PackedInt32Array()
	grid.resize(81)
	grid.fill(MG.IFLOOR)
	w.map = {"w": 9, "h": 9, "grid": grid, "exits": {}, "spawns": {}}
	w.interior = true
	w.player_pos = Vector2i(0, 0)
	var origin := Vector2i(4, 3)
	var target := Vector2i(4, 4)
	var n := {"pos": origin, "home": origin}
	w.npcs[origin] = n
	check(w._roam_free(target, origin, n), "visitor can stroll on open floor")
	w.map["exits"][Vector2i(5, 4)] = {}
	check(not w._roam_free(target, origin, n), "door approach stays empty")
	w.map["exits"].clear()
	w.map["spawns"]["entry"] = target
	check(not w._roam_free(target, origin, n), "arrival tile stays empty")
	w.map["spawns"].clear()
	MG.set_t(w.map, 5, 4, MG.COUNTER)
	check(not w._roam_free(target, origin, n), "service counter approach stays empty")
	MG.set_t(w.map, 5, 4, MG.LOCKED)
	check(not w._roam_free(target, origin, n), "locked door approach stays empty")
	MG.set_t(w.map, 5, 4, MG.IFLOOR)
	w.npcs[Vector2i(5, 4)] = {"pos": Vector2i(5, 4)}
	check(not w._roam_free(target, origin, n), "conversation approach stays empty")
	w.npcs.erase(Vector2i(5, 4))
	w.moving = true
	w.move_from = w.tile_pos(target)
	check(not w._roam_free(target, origin, n), "player departure tile stays reserved")
	w.moving = false
	n["walking"] = {"tile_from": target}
	check(not w._walkable(target), "NPC departure tile stays reserved")
	n.erase("walking")
	for x in 9:
		if x != 4:
			MG.set_t(w.map, x, 4, MG.IWALL)
	check(not w._roam_free(target, origin, n), "one-tile passage cannot be occupied")
	w.npcs.erase(origin)
	origin = Vector2i(3, 4)
	n["pos"] = origin
	n["home"] = origin
	w.npcs[origin] = n
	MG.set_t(w.map, 3, 4, MG.IFLOOR)
	check(not w._roam_free(target, origin, n), "two open areas retain their connecting passage")
	for x in 9:
		MG.set_t(w.map, x, 4, MG.IFLOOR)
	check(w._roam_free(target, origin, n), "open route becomes usable again")
	var actor := Node3D.new()
	n["node"] = actor
	n["roam"] = true
	n["roam_t"] = 0.0
	w._roam(0.0)
	check(n.has("walking") and n["pos"] != origin, "visitor still takes an animated grid step")
	check(not w._walkable(origin) and not w._walkable(n["pos"]), "moving visitor reserves both ends")
	n.erase("walking")
	check(w._walkable(origin), "departure tile is released on arrival")
	actor.free()
	w.free()
	# Verify generated stores, including all regional variants, keep staff/seated patrons fixed.
	var roaming := 0
	var seated := 0
	for town in DB.TOWNS:
		for b in ML.load_map(town, {})["buildings"]:
			for floor_index in ML.room_set(b).size():
				var m := ML.load_map(ML.floor_id(b["interior"], floor_index + 1), {})
				for person in m["npcs"]:
					if person.get("kind", "") == "keeper":
						check(not person.get("roam", false), "staff stay at their counters")
					if person.get("kind", "") == "villager":
						if person.get("sit", false):
							seated += 1
							check(not person.get("roam", false), "seated patrons keep their seats")
						elif person.get("roam", false):
							roaming += 1
	check(roaming > 0 and seated > 0, "generated roaming and seated patrons covered")
	print("SHOP PATHS DONE: %d problem(s), %d roaming / %d seated patrons" % [bad, roaming, seated])
