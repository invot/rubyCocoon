extends RefCounted
## Renderer-independent building occlusion. --scene=building-fade [--town=tidewater]
const WorldDB = preload("res://scripts/data/world_db.gd")
const MapGen = preload("res://scripts/world/map_gen.gd")
var bad := 0


func run(main, opts: Dictionary) -> void:
	UI.auto = true
	var towns: Array = [String(opts["town"])] if opts.has("town") else WorldDB.TOWN_ORDER
	for town in towns:
		await main._go(town, "start")
		var world = main.world
		world.set_process(false)
		var found := false
		for f in world.building_fades:
			var box: AABB = world._fade_box(f["meshes"])
			for y in range(maxi(0, floori(box.position.z) - 12), mini(world.map["h"], ceili(box.end.z))):
				for x in range(maxi(0, floori(box.position.x)), mini(world.map["w"], ceili(box.end.x))):
					var tile := Vector2i(x, y)
					if not MapGen.walkable(MapGen.get_t(world.map, x, y)) or world.doors.has(tile):
						continue
					world.spawn_at(tile)
					if world.player_pos != tile:
						continue
					world.cam.position = world.player.position + world.CAM_OFFSET
					world.cam.look_at(world.player.position + Vector3(0, world.CAM_LOOK_Y, 0))
					world._fade_buildings(1.0)
					if f.get("opacity", 1.0) > 0.08:
						continue
					found = true
					var cache: Dictionary = f["fade_materials"]
					_check(not cache["bindings"].is_empty(), "%s: occluding %s at %s has fading surfaces" % [town, f["b"]["name"], tile])
					for binding in cache["bindings"]:
						var mat: BaseMaterial3D = binding["mesh"].get_active_material(binding["surface"])
						_check(mat == binding["faded"] and mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA
							and is_equal_approx(mat.albedo_color.a, binding["original"].albedo_color.a * 0.07), "surface opacity works without instance transparency")
					# Move into the clear: fade back through the actual occlusion update.
					world.player.position = box.end + Vector3(10, 0, 10)
					world.cam.position = world.player.position + world.CAM_OFFSET
					world._fade_buildings(1.0)
					_check(f["opacity"] == 1.0, "clearing the building restores opacity")
					for binding in cache["bindings"]:
						_check(binding["mesh"].get_active_material(binding["surface"]) == binding["original"], "original material restored without changing shared assets")
					break
				if found:
					break
			if found:
				break
		if found:
			_check(true, "%s: a real walkable tile behind a building was checked" % town)
		# Some layouts deliberately leave no path behind their buildings. Still exercise each town's real materials
		# with a controlled sightline through the building, including buildings that share cached source materials.
		var tested := 0
		for f in world.building_fades:
			var box: AABB = world._fade_box(f["meshes"])
			if box.size == Vector3.ZERO:
				continue
			world.player.position = Vector3(box.get_center().x, box.position.y, box.position.z - 1.5)
			world.cam.position = Vector3(box.get_center().x, box.get_center().y, box.end.z + 2.0)
			world._fade_buildings(1.0)
			_check(f.get("opacity", 1.0) < 0.08, "%s: %s fades on a blocked sightline" % [town, f["b"]["name"]])
			_check(not f.get("fade_materials", {}).get("bindings", []).is_empty(), "building has material opacity bindings")
			var originals := {}
			for binding in f.get("fade_materials", {}).get("bindings", []):
				var original: BaseMaterial3D = binding["original"]
				originals[original] = original.albedo_color
				var mat: BaseMaterial3D = binding["mesh"].get_active_material(binding["surface"])
				_check(mat == binding["faded"] and mat != original and mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA
					and is_equal_approx(mat.albedo_color.a, original.albedo_color.a * 0.07), "surface receives an isolated fade material")
			world.player.position = box.end + Vector3(10, 0, 10)
			world.cam.position = world.player.position + world.CAM_OFFSET
			world._fade_buildings(1.0)
			_check(f["opacity"] == 1.0, "clearing the building restores opacity")
			for binding in f.get("fade_materials", {}).get("bindings", []):
				_check(binding["mesh"].get_active_material(binding["surface"]) == binding["original"]
					and binding["original"].albedo_color == originals[binding["original"]], "original material restored without changing shared assets")
			tested += 1
		_check(tested > 0, "%s: audited %d buildings" % [town, tested])
	print("BUILDING FADE DONE: %d problem(s)" % bad)


func _check(ok: bool, label: String) -> void:
	if not ok:
		bad += 1
		print("FAIL ", label)
	elif not label.begins_with("surface") and not label.begins_with("original"):
		print("ok   ", label)
