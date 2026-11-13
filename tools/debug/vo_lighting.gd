extends "res://tools/debug/vo_perf.gd"
## 008b: old/approved/old indoor coverage and OculusKey on/off/on in real film stages.
## Harness-only overrides. Film animations advance at the same fixed dt on every target.
const WorldDB = preload("res://scripts/data/world_db.gd")
const Film = preload("res://scripts/ui/beast_cinematic.gd")
var _rooms := []


func run(main, opts: Dictionary) -> void:
	var options := opts.duplicate()
	options["passes"] = "3"
	options["duration"] = "0"
	await super.run(main, options)


func _route() -> void:
	if _rooms.is_empty():
		var largest := {"id": "caccoon#1", "area": 0}
		for id in WorldDB.TOWNS.keys() + WorldDB.ROUTES.keys():
			for building in MapLoader.load_map(id, {}).get("buildings", []):
				for floor_index in MapLoader.room_set(building).size():
					var room_id: String = MapLoader.floor_id(building["interior"], floor_index + 1)
					var room: Dictionary = MapLoader.load_map(room_id, {})
					var area: int = room["w"] * room["h"]
					if area > largest.area:
						largest = {"id": room_id, "area": area, "width": room["w"], "height": room["h"]}
		_rooms = [{"id": "caccoon#1", "label": "hero_house"}, {"id": largest.id, "label": "largest_interior", "inventory": largest}]
		print("VO LIGHTING largest generated building interior: ", JSON.stringify(largest))
	var approved := _passes.size() == 1
	for room in _rooms:
		await _indoor(room, approved)
	if _opts.get("part", "all") != "indoor":
		await _film("hatch", not approved)
		await _film("merge", not approved)


func _indoor(room: Dictionary, approved: bool) -> void:
	await _arrive(room.id, "entry")
	var world = _main.world
	var suns: Array[Node] = world.find_children("*", "DirectionalLight3D", true, false)
	if suns.size() != 1:
		_fail("indoor diagnostic requires exactly one sun")
		return
	var sun: DirectionalLight3D = suns[0]
	var original := {"distance": sun.directional_shadow_max_distance, "splits": sun.directional_shadow_mode}
	if not is_equal_approx(original.distance, 30.0) or original.splits != DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS:
		_fail("production indoor coverage is not the approved 30 / two splits")
		return
	if _opts.get("verify", "0") == "1":
		for quality in ["min", "max", "mid"]:
			Prefs.graphics_quality = quality
			Prefs.apply()
			await _main.get_tree().process_frame
			if sun.shadow_enabled != (quality != "min") or sun.directional_shadow_max_distance != 30.0 or sun.directional_shadow_mode != DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS:
				_fail("indoor quality change lost approved shadow coverage or authored enable state")
	sun.directional_shadow_max_distance = 30.0 if approved else 100.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if approved else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	await _main._wait(0.15)
	var positions := []
	for i in (3 if _opts.get("verify", "0") == "1" else 240):
		positions.append(world.player.position)
	var result := await _measure(room.label, world, world.cam, positions)
	result["experiment"] = {"kind": "indoor", "map": room.id, "distance": sun.directional_shadow_max_distance,
		"splits": sun.directional_shadow_mode, "inventory": room.get("inventory", {})}
	_segments[room.label] = result
	# Reachable cardinal tiles only. Coverage captures are outside the measured entry hold.
	if _opts.get("verify", "0") != "1":
		await _coverage(world, room.label)
	sun.directional_shadow_max_distance = original.distance
	sun.directional_shadow_mode = original.splits


func _coverage(world, label: String) -> void:
	var start: Vector2i = world.player_pos
	var reachable := [start]
	var seen := {start: true}
	var cursor := 0
	while cursor < reachable.size():
		var tile: Vector2i = reachable[cursor]
		cursor += 1
		for direction in DIRECTIONS:
			var next: Vector2i = tile + direction
			if not seen.has(next) and world._can_step(tile, next) and not world.doors.has(next) and not world.map["exits"].has(next):
				seen[next] = true
				reachable.append(next)
	for direction in DIRECTIONS:
		var target: Vector2i = start
		for tile in reachable:
			if Vector2(tile).dot(Vector2(direction)) > Vector2(target).dot(Vector2(direction)):
				target = tile
		world.player_pos = target
		world.player.position = world.tile_pos(target)
		# Settle the real following camera at each reachable extreme.
		for i in 90:
			world._process(DT)
		await _main._wait(0.1)
		await _capture(label + "_edge_" + str(direction))
	world.player_pos = start
	world.player.position = world.tile_pos(start)


func _film(kind: String, key_shadow: bool) -> void:
	var a := Beasts.create(0, 40)
	var b := Beasts.create(30, 40)
	var child := Beasts.merge(a, b, true)
	var film = Film.new().setup("hatch", a.growth_look(), a.growth_look(), {"race": 0}) if kind == "hatch" else load("res://scenes/MergeCinematic.tscn").instantiate().setup(a.growth_look(), b.growth_look(), child.growth_look())
	var update_mode: int = _main.view.render_target_update_mode
	_main.view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	UI.auto = false
	UI.push(film)
	film.set_process(false)
	var players: Array[Node] = film.find_children("*", "AnimationPlayer", true, false)
	for player: AnimationPlayer in players:
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	await _main.get_tree().process_frame
	await _main.get_tree().process_frame
	var stage: Node3D = film._stage
	var view: SubViewport = film._vp if kind == "hatch" else film._view
	var camera: Camera3D = film._cam if kind == "hatch" else film._camera
	var hatchery: Node3D = film._set if kind == "hatch" else film._hatchery
	var key: SpotLight3D = hatchery.get_node("OculusKey")
	key.shadow_enabled = key_shadow
	var captures := {294: "egg_in_tongs", 474: "reveal"} if kind == "hatch" else {120: "parents", 240: "mid", 450: "child"}
	var steps := []
	for i in (3 if _opts.get("verify", "0") == "1" else (504 if kind == "hatch" else 570)):
		steps.append(Vector3.ZERO)
	var advance := func():
		film._process(DT)
		for player: AnimationPlayer in players:
			player.advance(DT)
	var result := await _measure(kind, stage, camera, steps, advance, view, captures)
	if key.shadow_enabled != key_shadow:
		_fail("OculusKey diagnostic did not take effect")
	result["experiment"] = {"kind": kind, "key_shadow": key.shadow_enabled, "key_range": key.spot_range,
		"key_angle": key.spot_angle, "stage_scale": hatchery.scale.x, "elapsed": film.elapsed,
		"simulation_dt": DT, "captures": captures, "viewport_size": [view.size.x, view.size.y]}
	_segments[kind] = result
	key.shadow_enabled = true
	film.close()
	await _main.get_tree().process_frame
	_main.view.render_target_update_mode = update_mode
	UI.auto = true
