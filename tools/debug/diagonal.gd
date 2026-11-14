extends RefCounted
## Movement-core fixture. Public input and the setting are covered separately.
const Elev = preload("res://scripts/world/elevation.gd")
const MapGen = preload("res://scripts/world/map_gen.gd")
var bad := 0
var checks := 0
var main


class DoorProbe extends "res://scripts/world/world.gd":
	var entered := false
	func _enter_building(_building: Dictionary) -> void:
		entered = true


func run(host, opts: Dictionary) -> void:
	main = host
	for enabled in [false, true]:
		var w = DoorProbe.new()
		w.diagonal_movement = enabled
		w.map = {"w": 9, "h": 9, "grid": PackedInt32Array(), "exits": {}, "spawns": {}}
		w.map.grid.resize(81)
		w.map.grid.fill(MapGen.IFLOOR)
		w.player = Node3D.new()
		w.add_child(w.player)
		var body := Node3D.new()
		body.name = "Body"
		w.player.add_child(body)
		w.player_pos = Vector2i(1, 1)
		for d: Vector2i in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var a := Vector2i(4, 4)
			var x := a + Vector2i(d.x, 0)
			var y := a + Vector2i(0, d.y)
			var b := a + d
			_check(w._can_step(a, b), "open diagonal %s, core %s" % [d, enabled])
			for p in [x, y, b]:
				w.items[p] = {}
				_check(not w._can_step(a, b), "blocked tile %s, core %s" % [p, enabled])
				w.items.erase(p)
			w.stair_ways[x] = [a]
			_check(not w._can_step(a, b), "stairs stay cardinal")
			w.stair_ways.clear()
			w.doors[b] = {}
			_check(not w._can_step(a, b), "door approach stays cardinal")
			w.doors.clear()
			w.map.exits[b] = {}
			_check(not w._can_step(a, b), "exit approach stays cardinal")
			w.map.exits.clear()
			for p in [a, x, y, b]:
				_flat(w)
				var i: int = p.y * 9 + p.x
				w.map.elev.dir[i] = 1
				_check(not w._can_step(a, b), "ramp in square stays cardinal")
				w.map.elev.dir[i] = Elev.DIAG_NW
				_check(not w._can_step(a, b), "diagonal cliff square is blocked")
				_flat(w)
				w.map.elev.lo[i] = 1.0
				w.map.elev.hi[i] = 1.0
				_check(not w._can_step(a, b), "level mismatch is blocked")
			w.map.erase("elev")
			_reset(w, a)
			w.items[x] = {}
			var moved: bool = w._step(d, false)
			_check(moved == enabled and w.player_pos == (y if enabled else a), "sole free component slides only with core on")
			w.items[y] = {}
			_reset(w, a)
			_check(not w._step(d, false) and w.player_pos == a, "two blocked components refuse")
			w.items.clear()
			w.items[b] = {}
			_reset(w, a)
			_check(not w._step(d, false) and w.player_pos == a, "two open components do not pick an arbitrary slide")
			w.items.clear()
			_reset(w, a)
			_check(w._step(d, true) and w.facing == w._four_way(d), "diagonal has cardinal interaction facing")
			var duration: float = w._move_length / w.move_speed
			_reset(w, a)
			w._step(Vector2i.RIGHT, true)
			_check(is_equal_approx(duration / (w._move_length / w.move_speed), sqrt(2.0)), "diagonal duration is sqrt(2) at run speed")
			_reset(w, Vector2i(1, 1))
		_reset(w, Vector2i(3, 5))
		_check(w._step(Vector2i(1, -1), false), "diagonal reaches door frontage")
		w.doors[Vector2i(4, 3)] = {}
		w._step(Vector2i.UP, false)
		_check(w.entered, "cardinal door trigger works after diagonal arrival")
		w.doors.clear()
		_reset(w, Vector2i(1, 1))
		if enabled:
			await _walkers(w)
		w.free()
	# Real world: a completed diagonal counts once and finishes exactly at its centre.
	UI.auto = true
	await main._go("tidewater", "center")
	UI.auto = false
	var w = main.world
	w.frozen = true
	w.busy = true
	w.diagonal_movement = true
	var start := Vector2i(-1, -1)
	for y in range(2, int(w.map.h) - 2):
		for x in range(2, int(w.map.w) - 2):
			if w._can_step(Vector2i(x, y), Vector2i(x + 1, y + 1)):
				start = Vector2i(x, y)
				break
		if start.x >= 0:
			break
	_check(start.x >= 0, "real map has an open diagonal")
	if start.x >= 0:
		_reset(w, start)
		MapGen.set_t(w.map, start.x + 1, start.y + 1, MapGen.TALL)
		var steps: int = GameState.steps
		GameState.incense_steps = 10
		_check(w._step(Vector2i(1, 1), false), "step onto encounter grass starts")
		for i in 180:
			if not w.moving:
				break
			await main.get_tree().process_frame
		_check(not w.moving and w.player.position.is_equal_approx(w.tile_pos(start + Vector2i.ONE)), "released diagonal ends at destination centre")
		_check(GameState.steps == steps + 1 and GameState.incense_steps == 9, "grass arrival processes one step and incense tick")
		# Door triggers keep the existing north-facing cardinal approach after a diagonal.
		_check(w.facing == Vector2i.DOWN, "arrival leaves usable interaction facing")
	if opts.has("shot"):
		await main._wait(0.4)
		DirAccess.make_dir_recursive_absolute(String(opts.shot).get_base_dir())
		main._save_shot(String(opts.shot))
	print("DIAGONAL DONE: %d problem(s), %d checks" % [bad, checks])


func _walkers(w) -> void:
	var a := Vector2i(4, 4)
	var b := a + Vector2i.ONE
	var n := {"pos": a, "home": a, "node": Node3D.new()}
	w.add_child(n.node)
	n.node.position = w.tile_pos(a)
	w.npcs[a] = n
	_check(w._roam_free(b, a, n), "NPC accepts open diagonal")
	w.items[a + Vector2i.RIGHT] = {}
	_check(not w._roam_free(b, a, n), "NPC shares corner blocking")
	w.items.clear()
	w.npcs.erase(a)
	main.add_child(w)
	w.set_process(false)
	w.items[a + Vector2i.RIGHT] = {}
	await w.walk_npc_aside(n, [b], Vector2i.DOWN)
	_check(n.pos == a and n.node.position.is_equal_approx(w.tile_pos(a)), "scripted NPC rejects blocked diagonal")
	w.items.clear()
	await w.walk_npc_aside(n, [b], Vector2i.DOWN)
	_check(n.pos == b and n.node.position.is_equal_approx(w.tile_pos(b)), "scripted NPC diagonal ends at centre")
	w.busy = true
	n.node.position = w.tile_pos(a)
	n.walking = {"from": w.tile_pos(a), "to": w.tile_pos(b), "tile_from": a, "t": 0.0, "length": sqrt(2.0)}
	_check(w._npc_departing(a), "NPC reserves its source until arrival")
	w._animate_npcs(w.ROAM_STEP)
	_check(n.has("walking") and is_equal_approx(float(n.walking.t), 1.0 / sqrt(2.0)), "roaming NPC diagonal keeps ground speed")
	w._animate_npcs(w.ROAM_STEP * 0.5)
	_check(not n.has("walking") and n.node.position.is_equal_approx(w.tile_pos(b)), "roaming NPC rests at tile centre")
	w.npcs.clear()
	var beast := {"pos": a, "node": Node3D.new(), "moving": false, "speed": 2.0, "phase": 0.0, "followers": []}
	w.add_child(beast.node)
	var lead := Node3D.new()
	lead.name = "Lead"
	beast.node.add_child(lead)
	beast.node.position = w.tile_pos(a)
	w.wilds.append(beast)
	_check(w._wild_step(beast, Vector2i.ONE, 2.0), "beast accepts open diagonal")
	w._animate_wild(beast, 0.5)
	_check(beast.moving and is_equal_approx(float(beast.mt), 1.0 / sqrt(2.0)), "beast diagonal keeps ground speed")
	w._animate_wild(beast, 0.3)
	_check(not beast.moving and beast.node.position.is_equal_approx(w.tile_pos(b)), "beast rests at tile centre")
	beast.pos = a
	w.items[a + Vector2i.RIGHT] = {}
	_check(not w._wild_step(beast, Vector2i.ONE, 2.0), "beast shares corner blocking")
	w.items.clear()
	w.wilds.clear()
	main.remove_child(w)


func _flat(w) -> void:
	Elev.parse(w.map, ["000000000", "000000000", "000000000", "000000000", "000000000", "000000000", "000000000", "000000000", "000000000"])


func _reset(w, p: Vector2i) -> void:
	w.moving = false
	w.player_pos = p
	w.player.position = w.tile_pos(p)


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		bad += 1
	print("ok   " if ok else "FAIL ", label)
