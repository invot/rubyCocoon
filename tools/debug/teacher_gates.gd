extends RefCounted
## First run along the Coastal Path: no lesson taken yet, a fresh hatchling, the footbridge first broken and then
## mended. For each teacher, every tile the hero can reach from Cocoon Cove without stepping into that teacher's line of
## sight is flooded with the real world's movement rule (world.gd _can_step), and the teacher's sight is traced exactly
## as world.gd _check_trainer_sight does. Nothing past a teacher (Bellerive's exit, or before the bridge is mended the
## footbridge and Hal's log pile) may be reachable that way. A Cocoon Cove teacher is checked against Bellerive's exit,
## and those west of the creek against the crossing too. Ranger Holt, the last, also stands before the kennel barn.
## godot --headless --path . -- --scene=teacher-gates --save_dir=res://build/teacher_gates_saves/
const ML = preload("res://scripts/world/map_loader.gd")
const Elev = preload("res://scripts/world/elevation.gd")
const MapGen = preload("res://scripts/world/map_gen.gd")
const Beasts = preload("res://scripts/core/beasts.gd")
var bad := 0

func check(ok: bool, message: String) -> void:
	print("ok " if ok else "FAIL ", message)
	if not ok:
		bad += 1

func run(main, _opts: Dictionary) -> void:
	UI.auto = true
	GameState.set_flag("intro_done")
	GameState.set_flag("has_starter")
	if GameState.party.is_empty():
		GameState.add_beast(Beasts.create(0, 3))
	for lesson in ["screen", "turns", "slingshot", "items", "ring"]:
		GameState.set_flag("lesson_" + lesson, false)
	var bridge_flag := ""
	for obstacle in ML.load_map("route1", {})["obstacles"].values():
		if obstacle["kind"] == "broken_bridge":
			bridge_flag = obstacle["flag"]
	check(bridge_flag != "", "the Coastal Path has its broken footbridge")
	for mended in [false, true]:
		GameState.set_flag(bridge_flag, mended)
		await main._go("route1", Vector2i(0, 8))
		await main._wait(0.6)
		var world = main.world
		var label := "bridge mended" if mended else "bridge broken"
		var west := []
		var east := []
		for e in world.map["exits"]:
			if world.map["exits"][e]["to"] == "caccoon":
				west.append(e)
			else:
				east.append(e)
		var bridge := []
		var logpile: Vector2i = world.map["anchors"].get("logpile", Vector2i(-1, -1))
		for e in world.map["obstacles"]:
			bridge.append(e)
		check(not west.is_empty() and not east.is_empty(), "%s: exits west and east" % label)
		var teachers := []
		for p in world.npcs:
			if world.npcs[p].has("lesson") and world.npcs[p].get("kind", "") == "trainer":
				teachers.append(p)
		check(teachers.size() == 5, "%s: all five teachers are standing (%d)" % [label, teachers.size()])
		# with every teacher out of the way, Bellerive must be reachable at all once the bridge is mended
		var open := _flood(world, west, {})
		if mended:
			check(east.any(func(e): return open.has(e)), "%s: Bellerive is reachable" % label)
		else:
			check(not east.any(func(e): return open.has(e)), "%s: the creek blocks the way to Bellerive" % label)
		for p in teachers:
			var n: Dictionary = world.npcs[p]
			var sight := _sight(world, p, n)
			var seen := _flood(world, west, sight)
			var who := "%s: %s %s at %s (sees %d tiles)" % [label, n.get("cls", ""), n.get("name", ""), p, sight.size() - 1]
			if mended:
				check(not east.any(func(e): return seen.has(e)), "%s can't be walked past to Bellerive" % who)
				# the last teacher stops you before you reach the kennel barn's doors
				if n.get("lesson", "") == "ring":
					var barn: Array = world.doors.keys().filter(func(d): return world.doors[d].get("shop", "") == "kennel")
					check(not barn.is_empty(), "%s: the kennel barn has its doors" % label)
					check(not barn.any(func(d): return _beside(world, seen, d)), "%s can't be walked past to the kennel barn" % who)
			elif p.x < 28:
				# west of the creek: the crossing and the logs for it lie past them
				var reached := bridge.filter(func(b): return _beside(world, seen, b))
				check(reached.is_empty(), "%s can't be walked past to the footbridge" % who)
				if logpile.x >= 0:
					check(not _beside(world, seen, logpile), "%s can't be walked past to Hal's log pile" % who)
	UI.auto = false
	print("TEACHER GATES DONE: %d problem(s)" % bad)


## The tiles the teacher sees, and their own, as world.gd _check_trainer_sight walks it.
func _sight(world, p: Vector2i, n: Dictionary) -> Dictionary:
	var out := {p: true}
	var f: Vector2i = n.get("facing", Vector2i(0, 1))
	for i in range(1, int(n.get("sight", 4)) + 1):
		var q: Vector2i = p + f * i
		if not Elev.joined(world.map, q - f, q):
			break
		out[q] = true
		if not MapGen.walkable(MapGen.get_t(world.map, q.x, q.y)) or world.npcs.has(q):
			break
	return out


## Everything reachable from the starts by real steps, never entering `avoid`.
func _flood(world, starts: Array, avoid: Dictionary) -> Dictionary:
	var seen := {}
	var q := []
	for s in starts:
		if not avoid.has(s):
			seen[s] = true
			q.append(s)
	var i := 0
	while i < q.size():
		var p: Vector2i = q[i]
		i += 1
		for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var nb: Vector2i = p + d
			if seen.has(nb) or avoid.has(nb) or not world._can_step(p, nb):
				continue
			seen[nb] = true
			q.append(nb)
	return seen


func _beside(world, seen: Dictionary, p: Vector2i) -> bool:
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		if seen.has(p + d):
			return true
	return false
