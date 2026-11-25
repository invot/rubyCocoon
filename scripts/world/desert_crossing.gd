extends RefCounted
## The Scaraba Desert in play (desert_layout.gd is the director; this is the hero's side of it): walking in, crossing a
## seam, the joins' star rings, and the walk-off at the edge (docs/scaraba-implementation-plan.md WP2, U9).
## The joins' locks are star_locks.gd; the sections' set pieces are desert_sights.gd.
const Layout = preload("res://scripts/world/desert_layout.gd")
const MapLoader = preload("res://scripts/world/map_loader.gd")
const WorldDB = preload("res://scripts/data/world_db.gd")
const VPer = preload("res://scripts/gfx/voxel_person.gd")
const StarLocks = preload("res://scripts/world/star_locks.gd")
const Sights = preload("res://scripts/world/desert_sights.gd")
## A walk-off's note, shown once the hero is back.
static var _lost_note := ""
## The walk-off: seconds the hero walks on alone, and when the fade begins.
const WALK_OFF := 2.6
const WALK_FADE := 1.3


## The save's layout, made with a seed of its own the first time the hero walks in.
static func state() -> Dictionary:
	if not GameState.flags.get(Layout.KEY, null) is Dictionary:
		GameState.flags[Layout.KEY] = Layout.make(randi())
	var st: Dictionary = GameState.flags[Layout.KEY]
	Layout.live = st
	return st


static func _store(st: Dictionary) -> void:
	GameState.flags[Layout.KEY] = st
	Layout.live = st


## Before a map is built (main._do_goto): into the desert from outside, the end walked in at; anywhere else, the
## rings' half-touched progress is let go.
static func arrive(id: String, spawn) -> void:
	if id != Layout.ROUTE:
		StarLocks.clear_progress()
		if _lost_note != "":
			var note := _lost_note
			_lost_note = ""
			GameState.main.get_tree().create_timer(1.2).timeout.connect(func(): UI.toast(note))
		return
	_store(Layout.arrive(state(), spawn, GameState.flags))


## A ring touched partway: the walk-off waits for it.
static func half_solved() -> bool:
	return StarLocks.half_solved()


## From Story.can_use_exit: a seam (on into the next section, or the edge), the edge's far side (the walk-off), or
## the oasis gate into Scaraba. Returns false to stay put.
static func use_exit(world, ex: Dictionary) -> bool:
	if world.map_id != Layout.ROUTE:
		return true
	if ex.has("desert"):
		var step := int(ex["desert"])
		_store(Layout.cross(state(), step, GameState.flags))
		var m := MapLoader.load_map(Layout.ROUTE, GameState.flags)
		# walking north you come in at the section's south end, and the other way round
		var side := "south" if step > 0 else "north"
		ex["spawn"] = m["spawns"].get(side, m["spawns"]["start"])
		ex["face"] = Vector2i(0, -step)
		return true
	if ex.get("desert_edge", false):
		return await _walk_off(world, ex)
	if ex["to"] == "sundown":
		GameState.set_flag("desert_crossed")
	return true


## The edge: the camera holds, the hero walks on alone off the screen, and after a fade they're back where they came
## into the desert, with everything they found and solved. Never mid-ring (a battle, a menu or a scene can't reach an
## exit: they stop the walk first, and the edge has no wild beasts).
static func _walk_off(world, ex: Dictionary) -> bool:
	if half_solved():
		await Story.say(["Behind you, the ring of stones still hums, waiting for the rest of the star. Better finish it first."])
		return false
	var st := state()
	var dir := Vector2i(0, -1 if int(st["dir"]) > 0 else 1)
	var from := Layout.return_to(st)
	UI.controls.release_touch_inputs()
	world.cam_free = true
	var hero: Node3D = world.player
	VPer.face(hero, dir)
	var start := hero.position
	var speed: float = world.move_speed
	var t := 0.0
	var faded := false
	while t < WALK_OFF and is_instance_valid(world) and is_instance_valid(hero):
		await world.get_tree().process_frame
		var dt: float = world.get_process_delta_time()
		t += dt
		hero.position = start + Vector3(dir.x, 0, dir.y) * speed * t
		world.anim_t += VPer.phase_for(dt * speed, speed)
		world._stride = speed
		if t >= WALK_FADE and not faded:
			faded = true
			UI.fade_out(WALK_OFF - WALK_FADE)
	# the desert starts over from the end they came in at
	st = st.duplicate(true)
	st["edge"] = false
	st["at"] = 0 if from == "route4" else st["list"].size() - 1
	_store(st)
	_lost_note = "The dunes all look alike. Somehow you've wandered back to %s." % _place(from)
	var edges := WorldDB.town_edges(from) if WorldDB.TOWNS.has(from) else WorldDB.route_edges(from)
	var side := "north" if from == "route4" else "south"
	for d in edges:
		if edges[d] == Layout.ROUTE:
			side = d
	ex["to"] = from
	ex["spawn"] = side
	ex["face"] = Vector2i(0, 1) if side == "north" else Vector2i(0, -1)
	return true


static func _place(id: String) -> String:
	return ("the " if WorldDB.ROUTES.has(id) else "") + WorldDB.map_name(id)


# ================================================================ star locks (star_locks.gd)
## The current section's lock: its five points and its tablet (Story.extra_npcs), and the section's own people and
## things (desert_sights.gd).
static func ring_npcs(map: Dictionary) -> Array:
	if map.get("id", "") != Layout.ROUTE:
		return []
	var out := Sights.objects(map)
	var ring: Dictionary = map.get("desert_ring", {})
	if not ring.is_empty():
		out.append_array(StarLocks.objects(ring))
	return out


## Talking to one of the desert's objects (Story.talk).
static func talk(world, n: Dictionary) -> void:
	match String(n["id"]):
		"star_point":
			await StarLocks.touch(world, n)
		"star_tablet":
			await StarLocks.read_tablet(world, n)
		"star_duck":
			# (an ordinary duck: it only quacks)
			var duck: Node3D = (n["node"] as Node3D).get_node_or_null("Duck") if n.get("node", null) != null else null
			if duck != null:
				duck.quack()
		_:
			await Sights.talk(world, n)



## Valkoog's doors, shut (Places.knock): a star is cut across them, and its points light in the star's order, then
## they wait for a gust no water stone can make. Reading them sets valkoog_read (the twins open them: WP4, WP6).
static func valkoog_doors(world) -> void:
	var first := not GameState.flag("valkoog_read")
	GameState.set_flag("valkoog_read")
	for i in Layout.STAR.size():
		Sfx.flute_note(StarLocks.NOTES[int(Layout.STAR[i]) - 1])
		await GameState.main.get_tree().create_timer(0.35).timeout
	# with the twins along, their stones are the gust the doors were waiting for (WP6)
	if GameState.flag("met_twins") and not GameState.flag("twins_home") and not GameState.flag("guardian_air"):
		GameState.set_flag("valkoog_open")
		Sfx.secret_chime()
		await Story.say(["Tam and Saffi put their stones together and blow. The star on the doors flares through its order and holds, burning.",
			"With a long grinding of sand, Valkoog's doors swing inward. A stair runs up beyond them into the dark."])
		if world != null and GameState.main != null:
			await GameState.main.reload_map()
		return
	await Story.say(["A great star is carved across the doors. As you touch them, its points glow one by one: one, three, five, two, four, and the top again.",
		"Then nothing. The doors seem to be waiting for something. A breath of wind, maybe, stronger than any you can make."]
		if first else ["The star on the doors glows through its order and fades. They're still waiting for a wind."])
	if first and GameState.has_stone("water"):
		await Story.say(["You hold up the water stone. A little mist drifts from it, and the doors ignore it completely."])
