extends RefCounted
## Where a map's construction time goes, phase by phase, and what the finished map asks of the renderer.
## Headless runs measure CPU work only; add a window for draw calls and primitives.
##   --maps=caccoon,tidewater   --report=res://build/build_profile.json
const Beasts = preload("res://scripts/core/beasts.gd")
const MapLoader = preload("res://scripts/world/map_loader.gd")

var report := {}


func run(main, opts: Dictionary) -> void:
	UI.auto = true
	for flag in ["intro_done", "tutorial_done", "ritual_done", "opening_seen"]:
		GameState.set_flag(flag)
	GameState.party = [Beasts.create(0, 10)]
	var tree: SceneTree = main.get_tree()
	load("res://scripts/gfx/surface_finish.gd").enabled = opts.get("finish", "1") == "1"
	var script = await main.wait_for_script(main.WORLD_PATH)
	for id in String(opts.get("maps", "caccoon,tidewater,cogsworth,route1")).split(","):
		if main.world != null:
			main.world.get_parent().remove_child(main.world)
			main.world.free()
			main.world = null
		script.clear_scenery_cache()
		for sh in main.THREAD_SHY:
			load(sh)
		var w = script.new()
		main.world = w
		main.view.add_child(w)
		var t := {}
		var clock := [Time.get_ticks_usec()]
		var lap := func(label: String) -> void:
			var now := Time.get_ticks_usec()
			t[label] = snappedf((now - clock[0]) / 1000.0, 0.1)
			clock[0] = now
		# The phases of World.build, one after another with nothing in between.
		w.set_process(false)
		w.map_id = id
		w.map = MapLoader.load_map(id, GameState.flags)
		w.biome = w.map["biome"].duplicate(true)
		if id.get_slice("#", 0) in ["kelpwick", "shellhaven"]:
			w.biome["style"] = "roundwood" if id.begins_with("kelpwick") else "resort"
		elif w.map.has("style"):
			w.biome["style"] = w.map["style"]
		w.interior = w.map["kind"] == "interior"
		for n in Story.extra_npcs(w.map):
			w.map["npcs"].append(n)
		lap.call("map data")
		if w.interior:
			w._build_room()
			lap.call("room")
		else:
			w._scenery_key = id + ":profile"
			w._build_environment()
			lap.call("environment")
			await w._build_terrain()
			lap.call("terrain")
			await w._plan_round_huts()
			await w._plan_houses()
			lap.call("house plans")
			await w._build_scatter()
			lap.call("scatter")
			await w._build_backdrop()
			lap.call("backdrop")
			w._build_buildings()
			lap.call("buildings list")
			if w.map["kind"] == "town":
				await w._build_street_props()
			lap.call("street props")
			w._build_statue()
			w._build_payphone()
			w._capture_scenery()
			w._build_obstacles()
			w.weapon_obstacles = w.WeaponObstacles.new()
			w.add_child(w.weapon_obstacles)
			w.weapon_obstacles.build(w)
			w._build_pushables()
			w._build_ripples()
			w._build_boats()
			lap.call("obstacles, boats")
		await w._build_npcs()
		lap.call("npcs")
		w._build_items()
		w._build_player()
		w._build_camera()
		lap.call("items, player")
		w.spawn_at("start" if w.map["spawns"].has("start") else w.map["spawns"].keys()[0])
		await w._spawn_wilds()
		lap.call("spawn, wilds")
		if not w.interior:
			# every building, as walking the whole map would load them
			var each := []
			for f in w.building_fades:
				var b := Time.get_ticks_usec()
				w._load_building(f)
				var ms := snappedf((Time.get_ticks_usec() - b) / 1000.0, 0.1)
				each.append(ms)
				if opts.get("buildings", "0") == "1":
					var st := _tree_stats(f["node"])
					print("    %6.1f ms  %-14s %-10s nodes %3d  meshes %3d  unique %3d  materials %3d  tris %6d  copies %d" % [ms, f["b"]["name"],
						f["b"]["shop"], st["nodes"], st["mesh instances"], st["unique meshes"], st["unique materials"], st["indexed tris"],
						f.get("fade_materials", {}).get("copies", {}).size()])
			lap.call("all buildings")
			each.sort()
			t["building count"] = each.size()
			if not each.is_empty():
				t["building median"] = each[each.size() / 2]
				t["building max"] = each.back()
		var total := 0.0
		for k in t:
			if not String(k).begins_with("building "):
				total += float(t[k])
		t["total"] = snappedf(total, 0.1)
		if opts.get("diagnose", "0") == "1":
			var began := Time.get_ticks_usec()
			load("res://scripts/gfx/surface_finish.gd").apply(w)
			t["finish pass ms"] = (Time.get_ticks_usec() - began) / 1000.0
			t["diagnosis"] = load("res://tools/debug/vo_cost.gd").inventory(w)
		t.merge(_tree_stats(w))
		w.set_process(true)
		w.frozen = true
		for i in 30:
			await tree.process_frame
		var rs := RenderingServer
		t["draw calls"] = rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		t["primitives"] = rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		t["objects"] = rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
		report[id] = t
		print("[build profile] ", id, " ", JSON.stringify(t))
	var path := String(opts.get("report", ""))
	if path != "":
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t"))
	UI.auto = false
	print("BUILD PROFILE DONE")


func _tree_stats(root: Node) -> Dictionary:
	var nodes := 0
	var instances := 0
	var multimeshes := 0
	var lights := 0
	var casters := 0
	var tris := 0
	var materials := {}
	var meshes := {}
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		nodes += 1
		if n is Light3D:
			lights += 1
		var mesh: Mesh = null
		var count := 1
		if n is MultiMeshInstance3D and n.multimesh != null:
			multimeshes += 1
			mesh = n.multimesh.mesh
			count = n.multimesh.instance_count
		elif n is MeshInstance3D:
			instances += 1
			mesh = n.mesh
		if mesh == null:
			continue
		if (n as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			casters += 1
		meshes[mesh] = true
		for s in mesh.get_surface_count():
			var mat: Material = n.get_active_material(s) if n is MeshInstance3D else (n.material_override if n.material_override != null else mesh.surface_get_material(s))
			materials[mat] = true
			tris += mesh.surface_get_array_index_len(s) / 3 * count if mesh is ArrayMesh and mesh.surface_get_array_index_len(s) > 0 else 0
	return {"nodes": nodes, "mesh instances": instances, "multimeshes": multimeshes, "lights": lights,
		"shadow casters": casters, "unique meshes": meshes.size(), "unique materials": materials.size(), "indexed tris": tris}
