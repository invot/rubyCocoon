extends SceneTree
## Bakes the furniture, doors, windows and wall and floor textures for building interiors from the packs in psx/
## into assets/interiors/ (see CREDITS.md).
##   godot --headless --path . --script res://tools/import_psx_interior.gd [-- name ...]
##
## Every piece comes out at the game's scale (a pack unit is about 0.75 m; the game's people stand 0.94 units to the
## metre), merged into one mesh with PSX materials, centred on X/Z, standing on y = 0 and turned to face +z, its back
## to -z: the game sets it against a wall by turning it so. Wall and floor textures are saved as PNGs for the room
## builder to tile.

const B = preload("res://tools/psx_bake.gd")
const OUT := "res://assets/interiors/"
const DV := "Environments/PSX modular house interior pack. (DissonantVoid)/"
## pack units to game units
const SCALE := 0.7

## name: [source under DV, degrees to turn so it faces +z]. The pack's kitchen units, bathroom pieces and wall
## hangings face +x; everything else faces +z already.
const PIECES := {
	# kitchen
	"counter": ["props/cabinetLow.glb", -90], "counter_corner": ["props/cabinetLowCorner.glb", -90],
	"kitchen_sink": ["props/cabinetSink.glb", -90], "pantry": ["props/cabinetHigh.glb", -90],
	"stove": ["props/oven.glb", -90], "fridge": ["props/fridge.glb", -90],
	# bathroom
	"toilet": ["props/toilet.glb", -90], "bathtub": ["props/bathtub.glb", -90], "vanity": ["props/bathroomSink.glb", -90],
	"basin": ["props/bathroomSink2.glb", -90], "washer": ["props/washingMachine.glb", -90],
	"mirror": ["props/mirror.glb", -90], "mirror_wide": ["props/mirror2.glb", -90], "toilet_paper": ["props/toiletPaper.glb", 0],
	# bedroom (beds, nightstands and dressers come from the furniture pack: see import_psx_furniture.gd)
	"wardrobe": ["props/cabinetBig.glb", 0], "teddy": ["props/teddybear.glb", 0],
	# living (so do the sofas, armchairs, tables, chairs and desks)
	"tv": ["props/tv.glb", 0], "bookshelf": ["props/bookshelf.glb", 0], "shelves": ["props/shelves.glb", 0], "shelves_metal": ["props/shelves2.glb", 0],
	"floor_lamp": ["props/lamp.glb", 0], "table_lamp": ["props/tableLamp.glb", 0], "coat_stand": ["props/hanger2.glb", 0],
	"plant_small": ["props/plant.glb", 0], "plant_leafy": ["props/plant2.glb", 0], "plant_tall": ["props/plant3.glb", 0],
	"globe": ["props/globe.glb", 0], "radio": ["props/radio.glb", 0], "chessboard": ["props/chessboard.glb", 0],
	"carpet_1": ["props/carpet.glb", 0], "carpet_2": ["props/carpet2.glb", 0], "carpet_3": ["props/carpet3.glb", 0],
	"carpet_4": ["props/carpet4.glb", 0], "doormat": ["props/doormat.glb", 0],
	# walls
	"painting_1": ["props/painting.glb", -90], "painting_2": ["props/painting2.glb", -90], "painting_3": ["props/painting3.glb", -90],
	"painting_4": ["props/painting4.glb", -90], "painting_5": ["props/painting5.glb", -90], "clock": ["props/clock.glb", -90],
	"radiator": ["props/radiator.glb", -90], "wall_shelf": ["props/wallShelf.glb", -90], "wall_shelf_2": ["props/wallShelf4.glb", -90],
	"wall_light": ["props/wallLight.glb", -90], "breaker_box": ["props/breakerBox.glb", -90],
	"curtains_1": ["props/windowCurtains.glb", 0], "curtains_2": ["props/windowCurtains2.glb", 0],
	"curtains_3": ["props/windowCurtains3.glb", 0], "curtains_4": ["props/windowCurtains4.glb", 0],
	# back rooms
	"box_1": ["props/box.glb", 0], "box_2": ["props/box2.glb", 0], "box_3": ["props/box3.glb", 0],
	"pallet": ["props/pallet.glb", 0], "bucket": ["props/bucket.glb", 0], "broom": ["props/broom.glb", 0],
	"ladder": ["props/ladder.glb", 0], "trash_bin": ["props/trashBin.glb", 0], "trash_bag": ["props/trashBag.glb", 0],
	# things on tables and counters
	"cup": ["props/cup.glb", 0], "cup_2": ["props/cup3.glb", 0], "plate": ["props/plate.glb", 0], "plate_2": ["props/plate3.glb", 0],
	"pan": ["props/pan.glb", 0], "pot": ["props/pot.glb", 0], "bottle": ["props/bottle.glb", 0], "bottle_2": ["props/bottle2.glb", 0],
	"milk": ["props/milkCarton.glb", 0], "books": ["props/bookStack.glb", 0], "books_2": ["props/bookStack3.glb", 0],
	"book": ["props/book.glb", 0], "phone": ["props/phone.glb", 0], "pencils": ["props/pencilCup.glb", 0], "apple": ["props/apple.glb", 0],
	"product_1": ["props/product.glb", 0], "product_2": ["props/product3.glb", 0], "product_3": ["props/product4.glb", 0],
	"product_4": ["props/product5.glb", 0],
	# doors and windows (the door leaf and the window face +z already)
	"door_1": ["geometry/doorWood.glb", 0], "door_2": ["geometry/doorWood2.glb", 0], "door_3": ["geometry/doorWood3.glb", 0],
	"window": ["geometry/WindowWood.glb", 0], "window_2": ["geometry/windowWood3.glb", 0],
}

## Shop, diner and kitchen fittings from Elbolilloduro's environment packs (each a node out of the pack's scene) and
## the till from heyheythere's PSX Mall Kit:
## name: [source under psx/Environments, degrees to turn so it faces +z, height in game units]. The packs' own scales
## differ, so each is sized by its height. (The diner's vending machine and soda fountain are left out: they carry a
## real drinks brand.)
const EB := "Environments/"
const FITTINGS := {
	"mall_register": ["PSX Mall Kit Free - Supermarket Kit Sampler (heyheythere)/glb/register.glb", 0, 0.3],
	"el_display": ["6TWELVE (Elbolilloduro)/Models/6twelve.fbx#Mostrator", -90, 1.0],
	"el_booth": ["DINER (Elbolilloduro)/Models/Objects.fbx#Seat", -90, 1.05],
	"el_diner_table": ["DINER (Elbolilloduro)/Models/Objects.fbx#Table", 0, 0.74],
	"el_coffee_maker": ["6TWELVE (Elbolilloduro)/Models/6twelve.fbx#Coffee_maker", 0, 0.42],
	"el_monitor": ["6TWELVE (Elbolilloduro)/Models/6twelve.fbx#Monitor", 65, 0.4],
	"el_slush": ["Gas station (Elbolilloduro)/Models/Gas_station_Props.fbx#ice_slush_machine", 0, 0.62],
	"el_microwave": ["Trailer Park (Elbolilloduro)/Models/Trailer_Park_Props.fbx#Microwave", -90, 0.28],
	"el_toaster": ["Trailer Park (Elbolilloduro)/Models/Trailer_Park_Props.fbx#Toaster", 0, 0.2],
	"el_flowers": ["Trailer Park (Elbolilloduro)/Models/Trailer_Park_Props.fbx#Flowers", 0, 0.5],
	"el_vase": ["Trailer Park (Elbolilloduro)/Models/Trailer_Park_Props.fbx#Vase_01", 0, 0.3],
	"el_photo": ["Trailer Park (Elbolilloduro)/Models/Trailer_Park_Props.fbx#Photo_frame_02", 0, 0.18],
	"el_lamp": ["Trailer Park (Elbolilloduro)/Models/Trailer_Park_Props.fbx#Lamp", 0, 0.55],
	"el_tp_plants": ["Trailer Park (Elbolilloduro)/Models/Trailer_Park_Props.fbx#Plants", 0, 0.7],
}

## Surface textures, from the pack's wall and floor tiles: name: source under DV.
const TEXTURES := {
	"wall_plaster": "geometry/wallPlaster.glb", "wall_plaster_2": "geometry/wallPlaster2.glb",
	"wall_plaster_3": "geometry/wallPlaster3.glb", "wall_paper": "geometry/wallWallpaper.glb",
	"wall_paper_2": "geometry/wallWallpaper2.glb", "wall_tiles": "geometry/wallTiles.glb", "wall_wood": "geometry/wallWood.glb",
	"wall_brick": "geometry/wallBrick.glb", "wall_marble": "geometry/wallMarble.glb",
	"floor_wood": "geometry/floorWood.glb", "floor_wood_2": "geometry/floorWood2.glb", "floor_tiles": "geometry/floorTiles.glb",
	"floor_carpet": "geometry/floorCarpet.glb", "floor_carpet_2": "geometry/floorCarpet2.glb",
	"floor_stone": "geometry/floorStone.glb", "floor_marble": "geometry/floorMarble.glb",
}


func _init() -> void:
	var src := ProjectSettings.globalize_path("res://psx/") + DV
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "tex"))
	var only := OS.get_cmdline_user_args()
	var sizes := {}
	for name in PIECES:
		if not only.is_empty() and not only.has(name) and not only.has("pieces"):
			continue
		var e: Array = PIECES[name]
		var scene := B.load_model(src + e[0])
		if scene == null:
			push_error("could not load " + e[0])
			continue
		var mesh := B.bake(scene, {"scale": SCALE})
		scene.free()
		mesh = B.turned(mesh, float(e[1]))
		if B.tris(mesh) > 400:
			mesh = B.with_lods(mesh)
		var err := ResourceSaver.save(mesh, OUT + name + ".res", ResourceSaver.FLAG_COMPRESS)
		var bb := mesh.get_aabb()
		sizes[name] = [snappedf(bb.size.x, 0.01), snappedf(bb.size.y, 0.01), snappedf(bb.size.z, 0.01)]
		print("  %-16s %5d tris  %s  %s" % [name, B.tris(mesh), bb.size.snapped(Vector3.ONE * 0.01), "ok" if err == OK else "SAVE FAILED"])
	var root := ProjectSettings.globalize_path("res://psx/")
	for name in FITTINGS:
		if not only.is_empty() and not only.has(name) and not only.has("fittings"):
			continue
		var e: Array = FITTINGS[name]
		var scene := B.load_model(root + EB + e[0])
		if scene == null:
			push_error("could not load " + e[0])
			continue
		var mesh := B.bake(scene, {"scale": 1.0})
		scene.free()
		var hgt := mesh.get_aabb().size.y
		if hgt > 0.0001 and e.size() > 2:
			scene = B.load_model(root + EB + e[0])
			mesh = B.bake(scene, {"scale": float(e[2]) / hgt})
			scene.free()
		mesh = B.turned(mesh, float(e[1]))
		if name == "el_display":
			mesh = close_display_end(mesh)
		if B.tris(mesh) > 400:
			mesh = B.with_lods(mesh)
		var err := ResourceSaver.save(mesh, OUT + name + ".res", ResourceSaver.FLAG_COMPRESS)
		var bb := mesh.get_aabb()
		print("  %-16s %5d tris  %s  %s" % [name, B.tris(mesh), bb.size.snapped(Vector3.ONE * 0.01), "ok" if err == OK else "SAVE FAILED"])
	for name in TEXTURES:
		if not only.is_empty() and not only.has(name) and not only.has("textures"):
			continue
		var scene := B.load_model(src + TEXTURES[name])
		if scene == null:
			push_error("could not load " + TEXTURES[name])
			continue
		var img: Image = null
		for mi in scene.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			for si in m.mesh.get_surface_count():
				img = B.psx_image(m.get_active_material(si), 128)
				if img != null:
					break
			if img != null:
				break
		scene.free()
		if img == null:
			push_error("no texture in " + TEXTURES[name])
			continue
		var err := img.save_png(ProjectSettings.globalize_path(OUT + "tex/" + name + ".png"))
		print("  %-16s %dx%d  %s" % [name, img.get_width(), img.get_height(), "ok" if err == OK else "SAVE FAILED"])
	quit()


## The 6TWELVE display has no left end, exposed towards the camera in the arena lobby.
## Mirror its right end, including the countertop edge, keeping the wood texture and UVs.
static func close_display_end(mesh: ArrayMesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	var bb := mesh.get_aabb()
	for si in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for i in range(0, indices.size(), 3):
			if absf(verts[indices[i]].x - bb.end.x) > 0.0001 \
					or absf(verts[indices[i + 1]].x - bb.end.x) > 0.0001 \
					or absf(verts[indices[i + 2]].x - bb.end.x) > 0.0001:
				continue
			# Reflection reverses winding; reverse it again to keep the new end facing out.
			for corner in [0, 2, 1]:
				var j: int = indices[i + corner]
				var v := verts[j]
				v.x = bb.position.x + bb.end.x - v.x
				indices.append(verts.size())
				verts.append(v)
				normals.append(Vector3(-normals[j].x, normals[j].y, normals[j].z))
				uv.append(uv[j])
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		# Regenerate tangents for the reflected vertices, as in B.bake().
		arrays[Mesh.ARRAY_TANGENT] = null
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_INDEX] = indices
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(si, mesh.surface_get_material(si))
	return out
