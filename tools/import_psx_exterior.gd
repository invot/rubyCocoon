extends SceneTree
## Bakes the pieces building fronts are made of into assets/exteriors/ (see CREDITS.md):
##   godot --headless --path . --script res://tools/import_psx_exterior.gd
##
## From Elegant Crow's Retro Modular House Pack: wall sections (plain, with windows, with doors) and shutters. The pack paints everything from one texture sheet; each piece is split in two surfaces, "wall"
## (the plank-wall parts of the sheet) and "trim" (frames, glass, doors, shutters). The game lays each building's own
## wall finish over "wall" (see house_builder.gd), so the same pieces serve plaster, brick, timber or adobe houses.
## Pieces stay in the pack's metres (a storey is 3 m), facing +z, standing on y = 0, centred on x; their back face
## lies on z = 0 (so a wall's outer face sits at z = thickness).
## From heyheythere's PSX Building Kit Free: the chimney.
## Street furniture from CyberThreat's Urban Props (benches, hydrants, bins, air conditioners, dumpsters), McSteeg's
## crates and barrels and valsekamerplant's hedges: each sized by its height in game units.

const B = preload("res://tools/psx_bake.gd")
const OUT := "res://assets/exteriors/"
const EC := "Environments/Retro Modular House Pack (Elegant Crow)/retro_modular_house/"
const HB := "Environments/PSX Building Kit Free - Modular House Sampler (heyheythere)/addons/psx_building_kit/models/"

const PIECES := {
	"wall_1": "models/walls/wall_3x1.fbx", "wall_2": "models/walls/wall_3x2.fbx",
	"win_1": "models/windows/single_windows/window_single_01.fbx",
	"win_2": "models/windows/single_windows/window_single_02.fbx",
	"win_3": "models/windows/single_windows/window_single_03.fbx",
	"win_4": "models/windows/single_windows/window_single_04.fbx",
	"win_small_1": "models/windows/small_single_windows/window_small_single_01.fbx",
	"win_small_2": "models/windows/small_single_windows/window_small_single_02.fbx",
	"win_small_3": "models/windows/small_single_windows/window_small_single_03.fbx",
	"win_double_1": "models/windows/double_windows/window_double_01.fbx",
	"win_double_2": "models/windows/double_windows/window_double_02.fbx",
	"win_double_3": "models/windows/double_windows/window_double_03.fbx",
	"win_double_4": "models/windows/double_windows/window_double_04.fbx",
	"door_1": "models/doors/single_doors/door_single_01.fbx", "door_2": "models/doors/single_doors/door_single_02.fbx",
	"door_3": "models/doors/single_doors/door_single_03.fbx", "door_4": "models/doors/single_doors/door_single_04.fbx",
	"door_5": "models/doors/single_doors/door_single_05.fbx", "door_6": "models/doors/single_doors/door_single_06.fbx",
	"door_7": "models/doors/single_doors/door_single_07.fbx", "door_8": "models/doors/single_doors/door_single_08.fbx",
	"shutters_open_1": "models/misc/window_shutters/shutters_single_open_01.fbx",
	"shutters_open_2": "models/misc/window_shutters/shutters_single_open_02.fbx",
	"shutters_small_1": "models/misc/window_shutters/shutters_small_single_open_01.fbx",
	"shutters_small_2": "models/misc/window_shutters/shutters_small_single_open_02.fbx",
}
const HB_PIECES := {"chimney": "chimney_model.glb"}

## Street furniture: name: [source under psx/, degrees to turn so it faces +z, height in game units].
const CT := "Props/Retro 3D Assets Pack - Urban Props #1 (CyberThreat)/"
const MC := "Props/PSX Dungeon Boxes and Barrels Pack (MCSTEEG)/Models/Crates_and_barrels_glb.glb#"
const VK := "Nature/PSX style modular hedges (valsekamerplant)/bushes_summer/"
const STREET := {
	"bench": [CT + "UrbanPack3 - Street Props/UrbanPack3 - Street Props.fbx#Bench", 0, 0.85],
	"hydrant": [CT + "UrbanPack1/UrbanPack1.fbx#FireHydrant_001", 0, 0.7],
	"trash_can": [CT + "UrbanPack1/UrbanPack1.fbx#TrashCan_001", 0, 0.9],
	"ac_unit": [CT + "UrbanPack3 - Street Props/UrbanPack3 - Street Props.fbx#ACUnit", 0, 0.6],
	"dumpster": [CT + "UrbanPack3 - Street Props/UrbanPack3 - Street Props.fbx#Dumpster_001", 0, 1.2],
	"crate": [MC + "Crate_1", 0, 0.62], "crate_open": [MC + "Crate_1_open", 0, 0.62],
	"barrel": [MC + "Barrel_1", 0, 0.85], "keg": [MC + "Barrel_2_keg", 0, 0.8],
	"hedge_round": [VK + "bush_full_overgrown_summer.glb", 0, 1.1],
}


func _init() -> void:
	var src := ProjectSettings.globalize_path("res://psx/")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var sheet := Image.load_from_file(src + EC + "textures/textures_mid.png")
	sheet.convert(Image.FORMAT_RGBA8)
	sheet.generate_mipmaps()
	var trim := StandardMaterial3D.new()
	trim.albedo_texture = ImageTexture.create_from_image(sheet)
	trim.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	trim.roughness = 0.95
	trim.resource_name = "trim"
	var wall := StandardMaterial3D.new()
	wall.resource_name = "wall"
	# both materials saved once and shared by every piece (rather than the sheet copied into each)
	ResourceSaver.save(trim, OUT + "trim_material.res", ResourceSaver.FLAG_COMPRESS)
	ResourceSaver.save(wall, OUT + "wall_material.res")
	trim = load(OUT + "trim_material.res")
	wall = load(OUT + "wall_material.res")
	for name in PIECES:
		var scene := B.load_model(src + EC + PIECES[name])
		if scene == null:
			push_error("could not load " + PIECES[name])
			continue
		var mesh := _split(scene, wall, trim)
		scene.free()
		var err := ResourceSaver.save(mesh, OUT + name + ".res", ResourceSaver.FLAG_COMPRESS)
		var bb := mesh.get_aabb()
		print("  %-16s %s  surfaces %d  %s" % [name, bb.size.snapped(Vector3.ONE * 0.01), mesh.get_surface_count(), "ok" if err == OK else "SAVE FAILED"])
	for name in HB_PIECES:
		var scene := B.load_model(src + HB + HB_PIECES[name])
		if scene == null:
			push_error("could not load " + HB_PIECES[name])
			continue
		var mesh := B.bake(scene, {"scale": 1.0})
		scene.free()
		# the kit's models name its texture sheet but don't carry it: give them the sheet, PSX-sized
		var kit_sheet := Image.load_from_file(src + HB.get_base_dir().get_base_dir() + "/atlas.png")
		if kit_sheet != null:
			kit_sheet.convert(Image.FORMAT_RGBA8)
			if kit_sheet.get_width() > 256:
				kit_sheet.resize(256, 256 * kit_sheet.get_height() / kit_sheet.get_width(), Image.INTERPOLATE_LANCZOS)
			kit_sheet.generate_mipmaps()
			var kt := ImageTexture.create_from_image(kit_sheet)
			for si in mesh.get_surface_count():
				var sm := mesh.surface_get_material(si) as BaseMaterial3D
				if sm != null and sm.albedo_texture == null:
					sm.albedo_texture = kt
					sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		var err := ResourceSaver.save(mesh, OUT + name + ".res", ResourceSaver.FLAG_COMPRESS)
		print("  %-16s %s  %s" % [name, mesh.get_aabb().size.snapped(Vector3.ONE * 0.01), "ok" if err == OK else "SAVE FAILED"])
	for name in STREET:
		var e: Array = STREET[name]
		var scene := B.load_model(src + e[0])
		if scene == null:
			push_error("could not load " + e[0])
			continue
		var mesh := B.bake(scene, {"scale": 1.0})
		scene.free()
		var hgt := mesh.get_aabb().size.y
		if hgt > 0.0001:
			scene = B.load_model(src + e[0])
			mesh = B.bake(scene, {"scale": float(e[2]) / hgt})
			scene.free()
		mesh = B.turned(mesh, float(e[1]))
		var err := ResourceSaver.save(mesh, OUT + name + ".res", ResourceSaver.FLAG_COMPRESS)
		print("  %-16s %s  %s" % [name, mesh.get_aabb().size.snapped(Vector3.ONE * 0.01), "ok" if err == OK else "SAVE FAILED"])
	quit()


## Where on the pack's texture sheet the plank wall is: the top left block and the strip down the right.
static func _is_wall(uv: Vector2) -> bool:
	var cu := int(floor(uv.x * 8.0))
	var cv := int(floor(uv.y * 8.0))
	return (cu < 4 and cv < 3) or (cu >= 6 and cv < 4)


## The piece's triangles in two surfaces, "wall" and "trim", centred on x, standing on y = 0, its back on z = 0.
func _split(scene: Node, wall: Material, trim: Material) -> ArrayMesh:
	var bb := AABB()
	var first := true
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		if inst.mesh != null:
			var b := B.xf_to(inst, scene) * inst.mesh.get_aabb()
			bb = b if first else bb.merge(b)
			first = false
	var shift := Transform3D(Basis(), -Vector3(bb.get_center().x, bb.position.y, bb.position.z))
	var parts := {"wall": [PackedVector3Array(), PackedVector3Array(), PackedVector2Array()],
		"trim": [PackedVector3Array(), PackedVector3Array(), PackedVector2Array()]}
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		if inst.mesh == null:
			continue
		var xf := shift * B.xf_to(inst, scene)
		for si in inst.mesh.get_surface_count():
			var arr := inst.mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ns = arr[Mesh.ARRAY_NORMAL]
			var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
			var idx = arr[Mesh.ARRAY_INDEX]
			if idx == null:
				idx = range(vs.size())
			for t in range(0, idx.size() - 2, 3):
				var c: Vector2 = (uvs[idx[t]] + uvs[idx[t + 1]] + uvs[idx[t + 2]]) / 3.0
				var part: Array = parts["wall" if _is_wall(c) else "trim"]
				for k in 3:
					var i: int = idx[t + k]
					part[0].append(xf * vs[i])
					part[1].append((xf.basis * (ns[i] if ns != null else Vector3.BACK)).normalized())
					part[2].append(uvs[i])
	var out := ArrayMesh.new()
	for key in ["wall", "trim"]:
		var p: Array = parts[key]
		if (p[0] as PackedVector3Array).is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = p[0]
		arrays[Mesh.ARRAY_NORMAL] = p[1]
		arrays[Mesh.ARRAY_TEX_UV] = p[2]
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_name(out.get_surface_count() - 1, key)
		out.surface_set_material(out.get_surface_count() - 1, wall if key == "wall" else trim)
	return out
