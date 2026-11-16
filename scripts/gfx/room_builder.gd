extends RefCounted
## Builds the fixed parts of a building's interior from its map (see map_loader.gd _interior): the floors, thin walls
## with doorways, locked doors and windows, the furniture, the things hung on the walls and a light in each room.
## Everything is made of the PSX interior pack's pieces and textures (assets/interiors, baked by
## tools/import_psx_interior.gd), and the beds, seats, tables and cabinets of the furniture pack (baked and coloured by
## tools/import_psx_furniture.gd).
##
## Rooms: the map's "zone_rows" give each tile's kind of room (see ZONES), so a kitchen gets tiles and a bedroom
## carpet and wallpaper; each side of a wall takes the finish of the room it faces.
## Walls run through the middle of their tiles, a fifth of a tile thick, one mesh to each row of them. There is no
## front wall: the room is open towards the camera like a stage set, its floor ending in a dark edge half way across
## the front row, where the side walls stop too. So no wall ever stands between the camera and the player, and walls
## never fade; only tall furniture does, when the player is behind it (see fade).
## Furniture: adjacent matching tiles make one piece. Wall furniture faces inward; freestanding lounge seating
## opens towards the camera (the TV lives on the omitted fourth wall). See docs/interior_staging.md.

const MapGen = preload("res://scripts/world/map_gen.gd")
const Elev = preload("res://scripts/world/elevation.gd")
const DIR := "res://assets/interiors/"
const SOFT_SURFACE = preload("res://scripts/gfx/interior_surface.gdshader")
const SurfaceFinish = preload("res://scripts/gfx/surface_finish.gd")
## Rectangular area rugs, in tile units; rotations are included when fitting a room.
const RUG_SIZES := [Vector2i(3, 2), Vector2i(4, 3), Vector2i(5, 4), Vector2i(6, 5)]
const RUG_BLOCKED := [MapGen.IWALL, MapGen.IWINDOW, MapGen.IDOOR, MapGen.LOCKED, MapGen.IDIAG_A, MapGen.IDIAG_B,
	MapGen.STAIRS_UP, MapGen.STAIRS_DOWN, MapGen.IVOID, MapGen.LAVA, MapGen.FOUNTAIN, MapGen.WATER]
## wall thickness, height, the top of a doorway, a window's sill and top
const T := 0.2
const H := 2.8
const DOOR_H := 1.95
const SILL := 0.85
const WIN_TOP := 2.07
## the head of an open doorway onto a balcony
const BALCONY_H := 2.2
## how far the garden in a balcony doorway's window box lies below the doorway's sill: about half a storey (the
## user's 2026-11-15 direction), so you look down onto it over the little balcony's railing
const BALCONY_DROP := 1.35
## how far the floor's front edge drops, below the open front of the room
const EDGE := 0.35
## how steeply a stage room's camera looks down at the least (world.gd CAM_OFFSET_ROOM; nearer, it looks down more):
## what's below the floor, further behind the front edge than its depth over this, is hidden by the floor
const VIEW_SLOPE := 4.6 / 8.2
## doors you can go through are painted blue, locked ones red
const DOOR_OPENS := preload("res://scripts/gfx/house_models.gd").OPEN_DOOR
const DOOR_LOCKED := preload("res://scripts/gfx/house_models.gd").LOCKED_DOOR
## one texture repeat, in world units (a pack module)
const SPAN := 2.8
const WALLISH := [MapGen.IWALL, MapGen.IWINDOW, MapGen.IDOOR, MapGen.LOCKED, MapGen.IDIAG_A, MapGen.IDIAG_B]
const DIAGS := [MapGen.IDIAG_A, MapGen.IDIAG_B]

## Kinds of room: floor and wall textures (each building picks one of each, so no two houses look alike), and the
## colour of their light.
const ZONES := {
	"living": {"floor": ["floor_wood", "floor_wood_2"], "wall": ["wall_paper_2", "wall_plaster_2"], "light": "#ffdcae"},
	"bedroom": {"floor": ["floor_wood", "floor_carpet"], "wall": ["wall_paper", "wall_paper_2", "wall_plaster"], "light": "#ffd8b0"},
	"kitchen": {"floor": ["floor_tiles", "floor_carpet_2"], "wall": ["wall_plaster_2", "wall_plaster"], "light": "#fff0d8"},
	"bathroom": {"floor": ["floor_carpet_2", "floor_tiles"], "wall": ["wall_tiles"], "light": "#f4f8ff"},
	"hall": {"floor": ["floor_wood_2", "floor_wood"], "wall": ["wall_plaster", "wall_paper_2"], "light": "#ffe4c0"},
	"shop": {"floor": ["floor_wood", "floor_wood_2"], "wall": ["wall_plaster", "wall_plaster_2"], "light": "#ffe6c4"},
	"back": {"floor": ["floor_stone"], "wall": ["wall_brick", "wall_plaster_3"], "light": "#f0e0c0"},
	"office": {"floor": ["floor_carpet_2", "floor_wood_2"], "wall": ["wall_plaster_3", "wall_plaster"], "light": "#f4f0e8"},
	"grand": {"floor": ["floor_marble"], "wall": ["wall_marble"], "light": "#fff0d8"},
	"wood": {"floor": ["floor_wood_2"], "wall": ["wall_wood"], "light": "#ffd8a8"},
	"stone": {"floor": ["floor_stone"], "wall": ["wall_brick"], "light": "#d8c8ff"},
	"diner": {"floor": ["checker"], "wall": ["wall_plaster"], "light": "#fff4e8"},
}
const ZONE_CHARS := {"l": "living", "b": "bedroom", "k": "kitchen", "a": "bathroom", "h": "hall", "s": "shop",
	"o": "back", "f": "office", "g": "grand", "w": "wood", "t": "stone", "d": "diner"}

## Furniture: kind: m = models to choose from (the best fit for the space is picked), same = pieces that go together
## through a building (its chairs; its sofa and armchair, listed in matching order) are the building's own pick of
## the list, free = stands in the room rather than against a wall, fill = stretched along the wall to fill its tiles,
## long = its long side goes against the wall, short = its short end does (beds: the headboard),
## top = small things that may stand on it.
const KINDS := {
	"fireplace": {"m": [], "long": true},
	"hot_tub": {"m": []}, "hot_tub_sign": {"m": []}, "ice_maker": {"m": []}, "plant_table": {"m": []},
	"luggage": {"m": []},
	"counter_gate": {"m": [], "free": true},
	"counter": {"m": ["counter"], "fill": true, "top": ["cup", "bottle", "plate_2", "milk", "apple", "el_microwave", "el_toaster", "", ""]},
	"kitchen_sink": {"m": ["kitchen_sink"], "fill": true},
	"stove": {"m": ["stove"], "fill": true, "top": ["pan", "pot", ""]},
	"fridge": {"m": ["fridge"]},
	"pantry": {"m": ["pantry"]},
	"toilet": {"m": ["toilet"]},
	"bathtub": {"m": ["bathtub"], "long": true},
	# (2026-11-15, the user's direction: furniture is boxy, stout and chubby, never thin legs or thin boards) a basin
	# is set into a cupboard (the kitchen's sink unit); the vanity stays
	"basin": {"m": ["kitchen_sink", "vanity"]},
	"washer": {"m": ["washer"]},
	"sofa": {"m": ["sofa_love", "sofa_box", "sofa_roll"], "long": true, "same": true},
	"armchair": {"m": ["armchair_roll", "armchair_club", "armchair_tub"], "same": true},
	"tv": {"m": ["tv_stand"], "top": ["tv"], "always_top": true},
	# KayKit Furniture Bits (tools/import_kaykit_furniture.gd): chairs, stools, tables, beds, the chest of drawers,
	# houseplants, lamps and rugs; their cloth takes a colour (fabric_material)
	"chair": {"m": ["kk_chair_A", "kk_chair_C", "kk_stool_wood"], "chair": true,
		"single": true, "same": true},
	"stool": {"m": ["kk_stool", "kk_stool_wood"], "chair": true, "single": true, "same": true},
	"coffee_table": {"m": ["kk_table_low"], "free": true, "top": ["home/vase_flowers", "home/books_stack", "home/tea_set", "home/candles", "home/bowl_fruit", "cup", ""]},
	"book_display": {"m": ["kk_table_low"], "free": true, "top": ["books"], "always_top": true},
	"table": {"m": ["kk_table_long", "kk_table_medium", "kk_table_small"], "free": true,
		"top": ["plate", "cup", "home/bowl_fruit", "home/tea_set", "home/vase_flowers", "books_2", ""]},
	# (2026-11-15) a nightstand is the small two-drawer cupboard; the wider chests of drawers are dressers. "alt" are
	# what stands there instead when the first choice would be the same model as the piece beside it (_place)
	"nightstand": {"m": ["kk_cabinet_small"], "alt": ["side_table"], "top": ["home/table_lamp_gourd"], "always_top": true, "single": true},
	"dresser": {"m": ["kk_drawers"], "alt": ["kk_cabinet_small"], "top": ["teddy", "home/books_stack", "home/table_lamp_gourd", "home/photo_standing", "home/vase_round", "home/plant_succulent", "home/candles"]},
	# (2026-11-15) a low cupboard, a pouf and a basket of blankets: low pieces that may stand anywhere, the front included
	"cabinet": {"m": ["kk_drawers", "kk_cabinet_small"], "single": true, "top": ["home/vase_flowers", "home/books_stack", "home/plant_succulent", "home/photo_standing"]},
	"pouf": {"m": ["home/pouf"], "single": true, "free": true},
	"basket": {"m": ["home/basket_blankets"], "single": true},
	# a chunky table, with a chest of drawers beside it where the desk has two tiles or more (desk_side)
	"desk": {"m": ["kk_table_small"], "desk_side": "kk_drawers", "top": ["books", "pencils", "globe", "home/books_stack"]},
	"storage": {"m": ["kk_cabinet_medium_dec"], "alt": ["kk_drawers"], "long": true},
	"boxes": {"m": ["box_1", "box_2", "box_3"], "single": true},
	# a kennel barn's hay bales (barn_builder.gd)
	"hay": {"m": ["hay_stack"], "single": true},
	"mop": {"m": ["bucket"], "with": "broom", "single": true},
	"floor_lamp": {"m": ["home/floor_lamp_drum", "home/floor_lamp_tripod"], "lamp": true, "single": true},
	"coat_stand": {"m": [], "single": true},
	"trash": {"m": ["trash_bin"], "single": true},
	"bed": {"m": ["kk_bed_single_A", "kk_bed_single_B", "kk_bed_double_A", "kk_bed_double_B"], "short": true},
	"bunk": {"m": ["kk_bed_single_A", "kk_bed_single_B"], "short": true},
	"plant": {"m": ["kk_cactus_medium_A", "kk_cactus_medium_B"], "single": true},
	"large_plant": {"m": ["home/plant_pillow_tall"], "height": 1.9, "free": true},
	# (a shop's bookshelves stay; in a home each tile of one is a small dressed cupboard, home_m)
	"bookshelf": {"m": ["bookshelf"], "home_m": ["kk_cabinet_small_dec"], "alt": ["kk_drawers", "kk_cabinet_small"], "long": true},
	"shelf": {"m": ["shelves"], "long": true, "goods": true},
	"rug": {"m": ["kk_rug_rect", "kk_rug_stripes", "kk_rug_oval"], "free": true, "rug": true},
	"bench": {"m": ["ext/kaykit_stool_bench"], "fill": true},
	"booth": {"m": ["el_booth"], "fit": true, "chair": true, "tint": "#e05050"},
	"diner_table": {"m": ["el_diner_table"], "free": true, "fit": true, "top": ["cup", "plate", "el_flowers", "cup_2", ""]},
	"computer": {"m": ["kk_table_small"], "top": ["el_monitor"], "always_top": true},
	# a red telephone, on a white placemat on a little chest of drawers (tools/make_side_table.gd), out from the wall so
	# you can walk right up to it: calling Dad saves the game, calling Mom gets you a hint (see phone.gd).
	# top_scale = how much bigger than the pack's size what stands on it is; mat = the colour of a mat under it
	"phone": {"m": ["side_table"], "top": ["phone_rotary"], "always_top": true, "single": true, "free": true,
		"top_scale": 1.3, "mat": "#f6f3ec"},
}

static var _meshes := {}
static var _mats := {}
## Smooth wall finishes replace the pack's coarse grain. Keep each material family's established colour.
const WALL_COLOURS := {
	"wall_paper": "#f0e4cf", "wall_paper_2": "#e9e4d6",
	"wall_plaster": "#eee7d9", "wall_plaster_2": "#f1e7d6", "wall_plaster_3": "#d9d9d4",
	"wall_tiles": "#e4ece9", "wall_marble": "#e7e5df", "wall_wood": "#b58b65", "wall_brick": "#a5a3aa",
}
static var _wall_papers := {}
## An ancient room (a temple's: "ancient" in its template, or any room whose key starts "temple"): smooth ashlar walls
## of the temple's stone, a heavy plinth and cornice instead of skirting, carved pilasters with flame sconces, stone
## portals instead of painted doors, worn stone flags underfoot and the warm light of the flames.
const SANDSTONE := Color("#cdb896")
const TempleLights = preload("res://scripts/gfx/temple_lights.gd")
const FLAME := Color("#ffb04a")
## the stone courses' height, and a pilaster every this many tiles along a wall
const COURSE := 0.7
const PILASTER_EVERY := 3


static func wall_surface(tex: String, colour: Color) -> Material:
	if tex == "ashlar":
		return _ashlar(colour)
	if tex == "blocks":
		return _blocks(colour)
	if tex == "kelpwood":
		return load("res://scripts/gfx/island_buildings.gd").wood_material()
	var key := "smooth_wall:%s:%s" % [tex, colour.to_html()]
	if _mats.has(key):
		return _mats[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(WALL_COLOURS.get(tex, "#eee7d9")) * colour
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	if tex in ["wall_paper", "wall_paper_2"]:
		# A small, smoothly filtered repeating stripe, shared across every building using this paper.
		if not _wall_papers.has(tex):
			var gradient := Gradient.new()
			gradient.offsets = PackedFloat32Array([0.0, 0.08, 0.12, 0.46, 0.50, 0.58, 0.62, 0.96, 1.0])
			var stripe := Color("#e4d7c1") if tex == "wall_paper" else Color("#d7ded4")
			gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE, stripe, stripe, Color.WHITE, Color.WHITE, stripe, stripe, Color.WHITE])
			var paper := GradientTexture2D.new()
			paper.width = 256
			paper.height = 16
			paper.fill_from = Vector2.ZERO
			paper.fill_to = Vector2.RIGHT
			paper.gradient = gradient
			_wall_papers[tex] = paper
		mat.albedo_texture = _wall_papers[tex]
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		mat.uv1_scale = Vector3(1.0 / 0.8, 1.0, 1.0)
	_mats[key] = mat
	return mat


## Smooth cut stone in `colour`, laid in courses: a faint soft joint every COURSE up the wall, nothing coarser.
static func _ashlar(colour: Color) -> Material:
	var key := "ashlar:" + colour.to_html()
	if _mats.has(key):
		return _mats[key]
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.05, 0.12, 0.88, 0.95, 1.0])
	var joint := Color(0.86, 0.84, 0.8)
	var lit := Color(1.0, 0.99, 0.97)
	gradient.colors = PackedColorArray([joint, Color.WHITE, lit, Color.WHITE, Color.WHITE, joint])
	var courses := GradientTexture2D.new()
	courses.width = 8
	courses.height = 64
	courses.fill_from = Vector2.ZERO
	courses.fill_to = Vector2.DOWN
	courses.gradient = gradient
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.albedo_texture = courses
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.uv1_scale = Vector3(1.0, 1.0 / COURSE, 1.0)
	_mats[key] = mat
	return mat


## The Beast Center's dressed stone blocks, the same as its outside (beast_temple.gd _blocks_on): courses BLOCK.y
## tall, blocks BLOCK.x long staggered course by course, soft darker joints between them and each block its own faint
## shade, painted smooth (no grain). The texture holds two courses of two blocks.
const BLOCK := Vector2(0.82, 0.42)


static func _blocks(colour: Color) -> Material:
	var key := "blocks:" + colour.to_html()
	if _mats.has(key):
		return _mats[key]
	var iw := 256
	var ih := 128
	var img := Image.create(iw, ih, false, Image.FORMAT_RGB8)
	var joint := 0.016 / (BLOCK.x * 2.0) * iw
	var shades := [0.98, 1.03, 1.0, 0.96, 1.02, 0.99]
	for y in ih:
		var row := y * 2 / ih
		var fy := float(y % (ih / 2)) + 0.5
		var dy := minf(fy, ih / 2.0 - fy) / (joint * 0.5)
		for x in iw:
			var sx := float(x) + (iw / 4.0 if row == 1 else 0.0)
			var fx := fmod(sx, iw / 2.0) + 0.5
			var dx := minf(fx, iw / 2.0 - fx) / joint
			var blk := int(sx / (iw / 2.0)) % 2 + row * 2
			# 0 in the joint, rising softly to 1 on the block's face
			var face := clampf(minf(dx, dy) - 0.6, 0.0, 1.0)
			var c: Color = Color.WHITE * float(shades[blk]) * lerpf(0.7, 1.0, face)
			c.a = 1.0
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.uv1_scale = Vector3(1.0 / (BLOCK.x * 2.0), 1.0 / (BLOCK.y * 2.0), 1.0)
	_mats[key] = mat
	return mat


static func piece(name: String) -> Mesh:
	if name == "hay_stack":
		return load("res://scripts/gfx/barn_builder.gd").hay_stack()
	if not _meshes.has(name):
		# "ext/..." is a street piece (assets/exteriors/): the town's bench
		var path := "res://assets/exteriors/" + name.substr(4) + ".res" if name.begins_with("ext/") else DIR + name + ".res"
		_meshes[name] = load(path) if ResourceLoader.exists(path) else null
		if _meshes[name] == null:
			push_warning("model missing: " + path)
	return _meshes[name]


## Cloth colours for the KayKit furniture's fabric (seats, blankets, a table lamp's foot): the old furniture's red,
## teal, green, mustard, blue, violet and rose.
const CLOTH := ["#d8584e", "#2f9a9a", "#5fae6a", "#e0a838", "#4f7fcf", "#9a6ac8", "#e88aa6"]


## The KayKit fabric material (assets/interiors/kaykit/fabric.tres: the pack's blue as plain grey) in `colour`.
static func fabric_material(colour: Color) -> Material:
	var key := "kk_fabric:" + colour.to_html()
	if not _mats.has(key):
		var mat: StandardMaterial3D = (load(DIR + "kaykit/fabric.tres") as StandardMaterial3D).duplicate()
		mat.albedo_color = colour
		_mats[key] = mat
	return _mats[key]


## Gives a KayKit piece's "fabric" surface (if it has one) `colour`.
static func tint_fabric(mi: MeshInstance3D, colour: Color) -> void:
	var mesh := mi.mesh as ArrayMesh
	if mesh == null:
		return
	for i in mesh.get_surface_count():
		if mesh.surface_get_name(i) == "fabric":
			mi.set_surface_override_material(i, fabric_material(colour))


## A surface material: one of the pack's textures (tiled once per SPAN of world units), tinted.
static func surface(tex: String, tint: Color, extra: Dictionary = {}) -> StandardMaterial3D:
	var key := "%s:%s" % [tex, tint.to_html()]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	var t: Texture2D = extra.get(tex, null)
	if t == null and ResourceLoader.exists(DIR + "tex/" + tex + ".png"):
		t = load(DIR + "tex/" + tex + ".png")
	m.albedo_texture = t
	m.albedo_color = tint
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	m.uv1_scale = Vector3(1.0 / SPAN, 1.0 / SPAN, 1.0) if tex != "checker" else Vector3(1.0, 1.0, 1.0)
	_mats[key] = m
	return m


## Quads collected per material, then made into one mesh.
class Mesher:
	var surf := {}
	var mats := {}

	## Corners in order round the quad; uv runs along u_dir and v_dir (world units) from the first corner's
	## projection onto them; shade darkens it (vertex colour).
	func quad(key: String, mat: Material, p: Array, n: Vector3, u_dir: Vector3, v_dir: Vector3, shade := 1.0) -> void:
		if not surf.has(key):
			surf[key] = [PackedVector3Array(), PackedVector3Array(), PackedVector2Array(), PackedColorArray()]
			mats[key] = mat
		var a: Array = surf[key]
		var tris := [p[0], p[1], p[2], p[0], p[2], p[3]]
		var a0: Vector3 = p[0]
		var b0: Vector3 = p[1]
		var c0: Vector3 = p[2]
		if (b0 - a0).cross(c0 - a0).dot(n) > 0.0:
			tris = [p[0], p[2], p[1], p[0], p[3], p[2]]
		var col := Color(shade, shade, shade)
		for v in tris:
			a[0].append(v)
			a[1].append(n)
			a[2].append(Vector2((v as Vector3).dot(u_dir), (v as Vector3).dot(v_dir)))
			a[3].append(col)

	## One triangle (corners in any order), facing `n`.
	func tri(key: String, mat: Material, p: Array, n: Vector3, u_dir: Vector3, v_dir: Vector3, shade := 1.0) -> void:
		if not surf.has(key):
			surf[key] = [PackedVector3Array(), PackedVector3Array(), PackedVector2Array(), PackedColorArray()]
			mats[key] = mat
		var a: Array = surf[key]
		var p0: Vector3 = p[0]
		var p1: Vector3 = p[1]
		var p2: Vector3 = p[2]
		var order := [p0, p1, p2] if (p1 - p0).cross(p2 - p0).dot(n) < 0.0 else [p0, p2, p1]
		var col := Color(shade, shade, shade)
		for v in order:
			a[0].append(v)
			a[1].append(n)
			a[2].append(Vector2((v as Vector3).dot(u_dir), (v as Vector3).dot(v_dir)))
			a[3].append(col)

	## An axis-aligned box's faces (no bottom), in one material.
	func box(key: String, mat: Material, c: Vector3, s: Vector3, shade := 1.0) -> void:
		var h := s * 0.5
		var x0 := c.x - h.x
		var x1 := c.x + h.x
		var y0 := c.y - h.y
		var y1 := c.y + h.y
		var z0 := c.z - h.z
		var z1 := c.z + h.z
		quad(key, mat, [Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1)], Vector3.UP, Vector3.RIGHT, Vector3.BACK, shade)
		quad(key, mat, [Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1)], Vector3.BACK, Vector3.RIGHT, Vector3.DOWN, shade * 0.95)
		quad(key, mat, [Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x0, y1, z0)], Vector3.FORWARD, Vector3.LEFT, Vector3.DOWN, shade * 0.9)
		quad(key, mat, [Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0)], Vector3.RIGHT, Vector3.FORWARD, Vector3.DOWN, shade * 0.92)
		quad(key, mat, [Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0)], Vector3.LEFT, Vector3.BACK, Vector3.DOWN, shade * 0.92)

	func mesh() -> ArrayMesh:
		var m := ArrayMesh.new()
		for key in surf:
			var a: Array = surf[key]
			if (a[0] as PackedVector3Array).is_empty():
				continue
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = a[0]
			arrays[Mesh.ARRAY_NORMAL] = a[1]
			arrays[Mesh.ARRAY_TEX_UV] = a[2]
			arrays[Mesh.ARRAY_COLOR] = a[3]
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			m.surface_set_material(m.get_surface_count() - 1, mats[key])
		return m


var map: Dictionary
var parent: Node3D
var rng := RandomNumberGenerator.new()
var w := 0
var h := 0
var tint := Color.WHITE
var textures := {}
var default_zone := "shop"
var trim := Color("#5a3a26")
var ancient := false
## a temple's room ("temple..."): ancient, and dark, lit by its torches
var temple := false
## an ancient room laid in dressed blocks rather than smooth ashlar (the Beast Center's, matching its outside)
var blocks := false
## a Spanish mission's finish (the template's "mission"): see _mission_decor
var mission := false
## an adobe house's finish (Sunwall's rooms, map_loader.gd _interior): see _adobe_decor
var adobe := false
## an ancient room's stone (SANDSTONE, touched by the template's wall colour)
var stone := SANDSTONE
## per row of walls: a node, and the mesher its walls go into
var rows := {}
var _row_meshers := {}
var floor_mesher := Mesher.new()
var lights: Array = []
var pick_seed := 0

## furniture at least this tall (metres) fades when the player is behind it (see add_prop): {nodes, x, z (its
## middle), half_w, a (opacity)}
const TALL := 1.2
var _props: Array = []
var _snap := true
## the doors you can go through, by their tile: {"node" (the leaf, on its hinge), "yaw" (its turn when open), "past"
## (what shows through the doorway once it's open; a front door has none)}; see open_door
var door_leaves := {}
## the lowest floor in the room, found once (see _lowest)
var _low_y := INF
## the model each furnished tile got (_place), so no piece stands beside one exactly like it
var _placed := {}
## what was set on top of each furnished tile
var _placed_tops := {}


## Builds everything into `p`. extra: textures by name to use instead of the pack's ("checker").
static func build(m: Dictionary, p: Node3D, seed: int, extra := {}) -> RefCounted:
	var rb = load("res://scripts/gfx/room_builder.gd").new()
	rb.map = m
	rb.parent = p
	rb.rng.seed = seed
	rb.pick_seed = seed
	rb.w = m["w"]
	rb.h = m["h"]
	rb.textures = extra
	rb.default_zone = m.get("zone_default", "shop")
	rb.home = is_home(m)
	rb.scheme = rb._pick_scheme()
	var room: Dictionary = m.get("room", {})
	# the template's wall colour tints the wall textures a little
	rb.tint = Color.WHITE.lerp(Color(str(room.get("wall", "#ffffff"))), 0.35)
	rb.trim = Color(str(room.get("trim", "#5a3a26")))
	rb.mission = room.get("mission", false)
	rb.adobe = room.get("adobe", false)
	rb.ancient = room.get("ancient", String(m.get("room_key", "")).begins_with("temple"))
	rb.temple = String(m.get("room_key", "")).begins_with("temple")
	rb.stone = SANDSTONE.lerp(Color(str(room.get("wall", "#cdb896"))), 0.22)
	rb.blocks = room.get("blocks", false)
	if rb.blocks:
		# (the template's own stone, as it is outside)
		rb.stone = Color(str(room.get("wall", "#b9b5ad")))
	if room.has("round"):
		# a round chamber builds itself (round_chamber.gd): only its doorways' stone portals here, in its round wall
		for e: Vector2i in m.get("exits", {}):
			rb._portal(e.x, e.y, e.y == 0 or e.y == rb.h - 1)
		for y in rb._row_meshers:
			var rmi := MeshInstance3D.new()
			rmi.mesh = (rb._row_meshers[y] as Mesher).mesh()
			(rb.rows[y] as Node3D).add_child(rmi)
		return rb
	if room.get("open", false):
		# Open decks keep their existing floor and railings; only add the shared stairwell.
		rb._stairs()
		var stairs := MeshInstance3D.new()
		stairs.mesh = rb.floor_mesher.mesh()
		p.add_child(stairs)
		return rb
	rb._floors()
	rb._levels()
	rb._daises()
	rb._stairs()
	rb._plan_cubbies()
	rb._window_boxes()
	rb._walls()
	rb._furniture()
	rb._rugs()
	rb._stalls()
	rb._counters()
	if room.get("art_walls", false):
		rb._art_walls()
	else:
		rb._wall_decor()
	if rb.mission:
		rb._mission_decor()
	if rb.adobe:
		rb._adobe_decor()
	if rb.ancient:
		rb._pilasters()
	rb._hotel_details()
	rb._lights()
	if room.has("wood"):
		rb._one_wood(p)
	var fm := MeshInstance3D.new()
	fm.mesh = rb.floor_mesher.mesh()
	p.add_child(fm)
	for y in rb._row_meshers:
		var mi := MeshInstance3D.new()
		mi.mesh = (rb._row_meshers[y] as Mesher).mesh()
		(rb.rows[y] as Node3D).add_child(mi)
	return rb


# ---------------------------------------------------------------- fading furniture
## Tall furniture between the camera and the player fades: clear once it's ahead of them (nearer the camera), solid
## beside and behind them. The clear part: CONE_BASE tiles either side at the player, widening by CONE_SLOPE per tile
## ahead, its edge softened over CONE_SOFT.
const CONE_BASE := 1.1
const CONE_SLOPE := 0.7
const CONE_SOFT := 0.6
const FADE_SPEED := 3.0


## How opaque something `dx` tiles to the side of the player and `dz` ahead of them (towards the camera) should be.
func _cone(dx: float, dz: float) -> float:
	var a := clampf(1.0 - (dz - 0.4) / 0.5, 0.0, 1.0)
	var half := CONE_BASE + maxf(dz, 0.0) * CONE_SLOPE
	return lerpf(a, 1.0, clampf((dx - half) / CONE_SOFT, 0.0, 1.0))


## Moves each tall piece's opacity towards where the player at `p` wants it (call every frame).
func fade(p: Vector3, delta: float) -> void:
	# the first call (on entering) sets them straight away
	var step := 1.0 if _snap else delta * FADE_SPEED
	_snap = false
	for prop: Dictionary in _props:
		var dx := maxf(0.0, absf(float(prop["x"]) - p.x) - float(prop["half_w"]))
		var target := _cone(dx, float(prop["z"]) - p.z)
		var pa: float = prop["a"]
		if pa == target:
			continue
		pa = move_toward(pa, target, step)
		prop["a"] = pa
		for gi in prop["nodes"]:
			if is_instance_valid(gi):
				(gi as GeometryInstance3D).transparency = 1.0 - pa
				(gi as GeometryInstance3D).visible = pa > 0.02


## Makes a tall piece standing on tiles `lo` .. `lo + size` (with the things on it, `nodes`) fade (see fade).
func add_prop(nodes: Array, lo: Vector2i, size: Vector2) -> void:
	_props.append({"nodes": nodes, "x": lo.x + size.x / 2.0, "z": lo.y + size.y / 2.0, "half_w": size.x / 2.0 - 0.5, "a": 1.0})


## Puts `node` on wall tile (x, y), in its row.
func _attach(_x: int, y: int, node: Node3D) -> void:
	_row(y)
	(rows[y] as Node3D).add_child(node)


# ---------------------------------------------------------------- rooms
func code(x: int, y: int) -> int:
	return MapGen.get_t(map, x, y)


func wallish(x: int, y: int) -> bool:
	return _walled(map, Vector2i(x, y))


## The kind of room a tile is in, or "" for walls and the outside.
func zone(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= w or y >= h or wallish(x, y) or code(x, y) == MapGen.IVOID:
		return ""
	var zr: Array = map.get("zone_rows", [])
	if y < zr.size() and x < String(zr[y]).length():
		var ch: String = String(zr[y])[x]
		if ZONE_CHARS.has(ch):
			return ZONE_CHARS[ch]
	return default_zone


## The room on side `d` of wall tile (x, y), towards `half` (the other way along the wall) if straight across is
## another wall.
func zone_side(x: int, y: int, d: Vector2i, half: Vector2i) -> String:
	var z := zone(x + d.x, y + d.y)
	if z == "":
		z = zone(x + d.x + half.x, y + d.y + half.y)
	if z == "":
		z = zone(x + half.x, y + half.y)
	return z if z != "" else default_zone


## This building's pick of a zone's textures: the template's own choice, else one of the zone's, by the building.
func _pick(z: String, what: String) -> String:
	if map.get("parent", "") == "kelpwick" and what == "wall":
		return "kelpwood"
	var own: String = map.get("room", {}).get(what + "_tex", {}).get(z, "")
	if own != "":
		return own
	var opts: Array = ZONES.get(z, ZONES["shop"])[what]
	return opts[absi(hash(z + what) + pick_seed) % opts.size()]


func floor_mat(z: String) -> Material:
	return floor_surface("floor_ancient" if ancient else _pick(z, "floor"))


static func floor_surface(tex: String) -> ShaderMaterial:
	var key := "soft_floor:" + tex
	if _mats.has(key):
		return _mats[key]
	var finish := 0
	var base := Color("#ba9068")
	var accent := Color("#d0aa7b")
	match tex:
		"floor_wood_2":
			base = Color("#a67b55")
			accent = Color("#c49a6d")
		"floor_carpet", "floor_carpet_2":
			finish = 1
			base = Color("#b6aaa0") if tex == "floor_carpet" else Color("#b4b9ad")
		"floor_tiles":
			finish = 2
			base = Color("#ded5c3")
			accent = Color("#c6bcaa")
		"floor_ring":
			finish = 1
			base = Color("#ccb890")
		"floor_ancient":
			finish = 3
			base = Color("#b9a98a")
			accent = Color("#a39274")
		"floor_terracotta":
			# a mission's glazed terracotta tiles
			finish = 2
			base = Color("#c7754f")
			accent = Color("#a9603f")
		"floor_marble", "floor_stone":
			finish = 3
			base = Color("#d8d3c9") if tex == "floor_marble" else Color("#a7a5a2")
			accent = base.darkened(0.12)
		"checker":
			finish = 4
			base = Color("#ece7db")
			accent = Color("#343337")
	var mat := ShaderMaterial.new()
	mat.shader = SOFT_SURFACE
	mat.set_shader_parameter("finish", finish)
	mat.set_shader_parameter("finish_tex", SurfaceFinish.texture("fabric" if finish == 1 else "soft"))
	mat.set_shader_parameter("finish_level", SurfaceFinish.mean("fabric" if finish == 1 else "soft"))
	mat.set_shader_parameter("base_colour", base)
	mat.set_shader_parameter("accent_colour", accent)
	_mats[key] = mat
	return mat


func wall_mat(z: String) -> Material:
	if ancient:
		return wall_surface("blocks" if blocks else "ashlar", stone)
	if home and not adobe and not mission:
		return _home_wall(_pick(z, "wall"))
	return wall_surface(_pick(z, "wall"), tint if adobe or z in ["shop", "hall", "back", "office", "diner"] else Color.WHITE)


## Whether (x, y) is part of a stage room's stairwell down: open, with no floor over it.
func _stairwell_at(x: int, y: int) -> bool:
	return has_flights(map) and code(x, y) == MapGen.STAIRS_DOWN


## Whether the point (px, pz) is over a stairwell down: in one of its tiles, or where it reaches on into the walls
## beside it and at its end (see _stair_fit).
func _over_well(px: float, pz: float) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var x: int = floori(px) + dx
			var y: int = floori(pz) + dy
			if not _stairwell_at(x, y):
				continue
			var run := _stair_run(x, y)
			var fit := _stair_fit(x, y, run)
			var d := Vector3(px - x - 0.5, 0, pz - y - 0.5)
			var across := d.dot(run[3])
			var up := d.dot(run[2])
			if across > float(fit[0]) and across < float(fit[1]) and up > -0.5 and up < 0.5 + float(fit[2]):
				return true
	return false


func _floors() -> void:
	var edge := surface("cut", Color("#2a221e"))
	for y in h:
		for x in w:
			var c := code(x, y)
			# (a pool of water is sunk below the floor: world.gd _build_room)
			# (in a room of several levels there's a floor under its water: tide_water.gd draws the water)
			if c in [MapGen.RING, MapGen.LAVA, MapGen.IVOID] or (c == MapGen.WATER and (not Elev.has(map) or map.get("room", {}).has("dais"))):
				continue
			if sunk_basin(map, Vector2i(x, y)):
				# (a wall fall's basin, sunk to the pool's floor: its water is the pool's)
				_floor_quad(x, y, 0.0, 0.0, 1.0, 1.0, zone(x, y), _lowest())
				continue
			if _sunk_detail(x, y):
				if map.get("room", {}).has("dais") and Elev.ramp_dir(map, Vector2i(x, y)) != Vector2i.ZERO:
					# (a platform's steps stand on the floor below; _steps builds them up from it)
					_floor_quad(x, y, 0.0, 0.0, 1.0, 1.0, zone(x, y), Elev.edge(map, Vector2i(x, y), -Elev.ramp_dir(map, Vector2i(x, y))))
				continue
			if y == h - 1:
				# the open front: the floor stops half way across the row, in a dark edge (under the end of a side
				# wall, only on the room's side of it)
				var z0 := zone(x, y) if not c in WALLISH else zone(x, y - 1)
				var x0 := 0.0
				var x1 := 1.0
				if z0 == "" and c in WALLISH:
					if zone(x + 1, y - 1) != "":
						z0 = zone(x + 1, y - 1)
						x0 = 0.5
					elif zone(x - 1, y - 1) != "":
						z0 = zone(x - 1, y - 1)
						x1 = 0.5
				if z0 == "":
					continue
				var front := Elev.surface(map, Vector2i(x, y))
				_floor_quad(x, y, x0, 0.0, x1 - x0, 0.5, z0, front)
				floor_mesher.quad("edge", edge, [Vector3(x + x0, front, y + 0.5), Vector3(x + x1, front, y + 0.5), Vector3(x + x1, _lowest() - EDGE, y + 0.5),
					Vector3(x + x0, _lowest() - EDGE, y + 0.5)], Vector3.BACK, Vector3.RIGHT, Vector3.DOWN)
				continue
			if _stairwell_at(x, y):
				# a hole in the floor: the stairs down go down into it (see world.gd _stairwell)
				continue
			if not c in WALLISH:
				var lv := Elev.surface(map, Vector2i(x, y))
				if map.get("room", {}).has("dais") and Elev.ramp_dir(map, Vector2i(x, y)) != Vector2i.ZERO:
					# (a platform's steps stand on the floor below; _steps builds them up from it)
					lv = Elev.edge(map, Vector2i(x, y), -Elev.ramp_dir(map, Vector2i(x, y)))
				_floor_quad(x, y, 0.0, 0.0, 1.0, 1.0, zone(x, y), lv)
				continue
			if c in DIAGS:
				# each half of the tile takes the floor of the room on its side of the diagonal
				for side in _diag_sides(x, y):
					var zz: String = side[1]
					if zz != "":
						_floor_tri(side[0], zz, _foot(x, y))
				continue
			# under a wall: each quarter takes the floor of the room beside it (none where a stairwell runs on up to
			# the wall)
			for q in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
				if _over_well(x + 0.5 + q.x * 0.25, y + 0.5 + q.y * 0.25):
					continue
				if code(x + q.x, y + q.y) in DIAGS and _diag_joins(x + q.x, y + q.y, x, y):
					# a diagonal wall carries on from this tile's centre to its corner: the quarter is cut in two
					var c0 := Vector3(x + 0.5, 0, y + 0.5)
					var k := c0 + Vector3(q.x, 0, q.y) * 0.5
					var za := zone(x + q.x, y)
					var zb := zone(x, y + q.y)
					if za != "":
						_floor_tri([c0, c0 + Vector3(q.x * 0.5, 0, 0), k], za)
					if zb != "":
						_floor_tri([c0, c0 + Vector3(0, 0, q.y * 0.5), k], zb)
					continue
				var from := Vector2i(x + q.x, y)
				var z := zone(from.x, from.y)
				if z == "":
					from = Vector2i(x, y + q.y)
					z = zone(from.x, from.y)
				if z == "":
					from = Vector2i(x + q.x, y + q.y)
					z = zone(from.x, from.y)
				if z == "":
					continue
				_floor_quad(x, y, 0.0 if q.x < 0 else 0.5, 0.0 if q.y < 0 else 0.5, 0.5, 0.5, z, Elev.surface(map, from))


func _floor_quad(x: int, y: int, ox: float, oz: float, sx: float, sz: float, z: String, lv := 0.0) -> void:
	var x0 := x + ox
	var z0 := y + oz
	# The hearth's two occupied squares replace the room finish with tile, never an overlay on wood.
	var hearth := code(x, y) == MapGen.FIREPLACE
	var key := "floor_hearth_tiles" if hearth else "floor_" + z
	var material := floor_surface("floor_tiles") if hearth else floor_mat(z)
	floor_mesher.quad(key, material, [Vector3(x0, lv, z0), Vector3(x0 + sx, lv, z0), Vector3(x0 + sx, lv, z0 + sz),
		Vector3(x0, lv, z0 + sz)], Vector3.UP, Vector3.RIGHT, Vector3.BACK)


func _floor_tri(pts: Array, z: String, lv := 0.0) -> void:
	var up := Vector3(0, lv, 0)
	floor_mesher.tri("floor_" + z, floor_mat(z), pts.map(func(q: Vector3) -> Vector3: return q + up), Vector3.UP, Vector3.RIGHT, Vector3.BACK)


# ---------------------------------------------------------------- rooms of several levels (a room's "heights")
## True for a tile _levels draws itself, not _floors: a flight of steps, or a metal lattice (and a stretch of path
## that sinks under a wall fall: tide_water.gd draws it).
func _sunk_detail(x: int, y: int) -> bool:
	var p := Vector2i(x, y)
	return Elev.ramp_dir(map, p) != Vector2i.ZERO or map.get("lattices", {}).has(p) or rising_path(map, p)


## True for a stretch of path a wall fall runs across (a water puzzle without lattices): it sinks under the water while
## the fall runs and rises again when it stops, so the room leaves an open shaft there for tide_water.gd's slab.
static func rising_path(m: Dictionary, p: Vector2i) -> bool:
	return m.get("fall_spots", {}).has(p) and m.get("lattices", {}).is_empty()


## True for the basin a wall fall lands in (a water puzzle without lattices): sunk to the room's lowest floor, so the
## pool's water fills it level with the rest.
static func sunk_basin(m: Dictionary, p: Vector2i) -> bool:
	return m.get("basins", {}).has(p) and not m.get("fall_spots", {}).is_empty() and m.get("lattices", {}).is_empty()


## True for a tile whose floor is down at the room's lowest, under a water puzzle's wall falls.
static func sunk_tile(m: Dictionary, p: Vector2i) -> bool:
	return rising_path(m, p) or sunk_basin(m, p)


## The lowest floor in the room.
func _lowest() -> float:
	if _low_y == INF:
		_low_y = 0.0
		for y in h:
			for x in w:
				_low_y = minf(_low_y, Elev.plane(map, Vector2i(x, y), 0.5, 0.5))
	return _low_y if Elev.has(map) else 0.0


## How far down the wall in tile (x, y) has to reach: the lowest floor next to it.
func _foot(x: int, y: int) -> float:
	if not Elev.has(map):
		return 0.0
	var foot := Elev.surface(map, Vector2i(x, y))
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var q := Vector2i(x + dx, y + dy)
			if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or code(q.x, q.y) in WALLISH or code(q.x, q.y) == MapGen.IVOID:
				continue
			var low := Elev.surface(map, q)
			if Elev.ramp_dir(map, q) != Vector2i.ZERO:
				low = minf(Elev.edge(map, q, Elev.ramp_dir(map, q)), Elev.edge(map, q, -Elev.ramp_dir(map, q)))
			if sunk_tile(map, q):
				low = _lowest()
			foot = minf(foot, low)
	return foot


## Where a room's levels meet: the stone faces of each drop with a pale coping along its top, flights of steps on its
## ramps, and metal lattices.
func _levels() -> void:
	if not Elev.has(map):
		return
	var face: Material = surface("drop", stone.darkened(0.2))
	var coping: Material = surface("coping", stone.lightened(0.14))
	var tread: Material = surface("tread", stone.lightened(0.04))
	if map.get("room", {}).has("dais"):
		# a platform's sides and steps are wood, its lip painted trim
		face = _rail_mat()
		coping = _trim_mat()
		tread = _rail_mat()
	var iron := surface("lattice", Color("#6f7f86"))
	var rim := surface("lattice_rim", Color("#b08840"))
	for y in h:
		for x in w:
			var p := Vector2i(x, y)
			if code(x, y) in WALLISH or code(x, y) == MapGen.IVOID:
				continue
			var c := Vector3(x + 0.5, 0, y + 0.5)
			if Elev.ramp_dir(map, p) != Vector2i.ZERO:
				_steps(p, c, tread)
				continue
			if map.get("lattices", {}).has(p):
				_lattice(p, c, iron, rim)
				continue
			if sunk_tile(map, p):
				continue
			var top := Elev.surface(map, p)
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = p + d
				if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or code(q.x, q.y) in WALLISH or code(q.x, q.y) == MapGen.IVOID:
					continue
				# (a lattice is open underneath, so the walkway it joins shows its end; so is the shaft a rising path
				# moves in, with no coping across the path where its slab meets it)
				var open_under: bool = map.get("lattices", {}).has(q) or rising_path(map, q)
				var low := _lowest() if open_under or sunk_basin(map, q) else Elev.edge(map, q, -d)
				# (the sides of steps inset into a platform run down to the floor they start from)
				if map.get("room", {}).has("dais") and Elev.ramp_dir(map, q) != Vector2i.ZERO:
					# (nothing where the steps arrive at the top, the user's direction: no trim on that threshold)
					if Elev.ramp_dir(map, q) == -d:
						continue
					low = Elev.edge(map, q, -Elev.ramp_dir(map, q))
				if low >= top - 0.01:
					continue
				var out := Vector3(d.x, 0, d.y)
				var along := Vector3(absf(d.y), 0, absf(d.x))
				# (carried on to the face of a wall it runs into)
				var a := c + out * 0.5 - along * (0.5 + _into_wall(p, q, -Vector2i(along.x, along.z)))
				var b := c + out * 0.5 + along * (0.5 + _into_wall(p, q, Vector2i(along.x, along.z)))
				if map.get("room", {}).get("balcony", false):
					low = maxf(low, top - 0.18)
				floor_mesher.quad("drop", face, [a + Vector3(0, low, 0), b + Vector3(0, low, 0), b + Vector3(0, top, 0), a + Vector3(0, top, 0)], out, along, Vector3.DOWN)
				if not open_under:
					floor_mesher.box("coping", coping, c + out * 0.47 + Vector3(0, top + 0.02, 0), Vector3(0.1, 0.05, 0.1) + along * 0.96)


## How far a drop between tiles p and q runs on past their side `s`: to the wall's face if both have a wall there.
func _into_wall(p: Vector2i, q: Vector2i, s: Vector2i) -> float:
	return 0.4 if code(p.x + s.x, p.y + s.y) in WALLISH and code(q.x + s.x, q.y + s.y) in WALLISH else 0.0


## A ramp's flight of steps, solid down to the floor below it, reaching back to the wall on either side.
func _steps(p: Vector2i, c: Vector3, tread: Material) -> void:
	var d := Elev.ramp_dir(map, p)
	var up := Vector3(d.x, 0, d.y)
	var across := Vector2i(absi(d.y), absi(d.x))
	var side := Vector3(across.x, 0, across.y)
	var lo := Elev.edge(map, p, -d)
	var hi := Elev.edge(map, p, d)
	var a := 0.5 + (0.4 if code(p.x - across.x, p.y - across.y) in WALLISH else 0.0)
	var b := 0.5 + (0.4 if code(p.x + across.x, p.y + across.y) in WALLISH else 0.0)
	if map.get("room", {}).has("dais"):
		# a platform's steps (the user's direction, 2026-11-15: steep, two big treads): rising over the middle of the tile, so whoever stands on its middle is level with them, with a short
		# landing at the top
		# (2026-11-15: larger still, the user's direction: two big steps up)
		var run := 0.6
		var k := 2
		# (the same boards as the floor, the user's direction)
		tread = floor_mat(zone(p.x, p.y))
		for i in k:
			var top := lerpf(lo, hi, float(i + 1) / k)
			var at := c + up * (-run / 2.0 + (i + 0.5) * run / k) + side * (b - a) / 2.0
			floor_mesher.box("tread", tread, at + Vector3(0, (top + lo) / 2.0, 0), up.abs() * (run / k) + side * (a + b) + Vector3(0, top - lo, 0))
		floor_mesher.box("tread", tread, c + up * (run / 2.0 + (0.5 - run / 2.0) / 2.0) + side * (b - a) / 2.0 + Vector3(0, (hi + lo) / 2.0, 0),
			up.abs() * (0.5 - run / 2.0) + side * (a + b) + Vector3(0, hi - lo, 0))
		return
	var n := 4
	for i in n:
		var t := lerpf(lo, hi, float(i + 1) / n)
		var at := c + up * (-0.5 + (i + 0.5) / n) + side * (b - a) / 2.0
		var height := t - _lowest()
		floor_mesher.box("tread", tread, at + Vector3(0, _lowest() + height / 2.0, 0), up.abs() * (1.0 / n) + side * (a + b) + Vector3(0, height, 0))


## A metal lattice in a walkway: a brass rim and crossed iron bars, the water showing through.
func _lattice(p: Vector2i, c: Vector3, iron: Material, rim: Material) -> void:
	var y := Elev.surface(map, p) - 0.03
	_floor_quad(p.x, p.y, 0.0, 0.0, 1.0, 1.0, zone(p.x, p.y), _lowest())
	for s in [-1.0, 1.0]:
		floor_mesher.box("lattice_rim", rim, c + Vector3(s * 0.45, y, 0), Vector3(0.1, 0.06, 1.0))
		floor_mesher.box("lattice_rim", rim, c + Vector3(0, y, s * 0.45), Vector3(1.0, 0.06, 0.1))
	for i in 5:
		var o := -0.32 + i * 0.16
		floor_mesher.box("lattice", iron, c + Vector3(o, y - 0.005, 0), Vector3(0.05, 0.05, 0.84))
		floor_mesher.box("lattice", iron, c + Vector3(0, y - 0.005, o), Vector3(0.84, 0.05, 0.05))


## A diagonal tile's two halves: [[three corners], the room's kind on that side]. "/" (IDIAG_A) splits the tile from
## its bottom-left to its top-right corner, "\\" (IDIAG_B) from its top-left to its bottom-right.
func _diag_sides(x: int, y: int) -> Array:
	var a := Vector3(x, 0, y)
	var b := Vector3(x + 1, 0, y)
	var c := Vector3(x + 1, 0, y + 1)
	var d := Vector3(x, 0, y + 1)
	if code(x, y) == MapGen.IDIAG_A:
		return [[[a, b, d], _first_zone([Vector2i(x - 1, y), Vector2i(x, y - 1)])],
			[[b, c, d], _first_zone([Vector2i(x + 1, y), Vector2i(x, y + 1)])]]
	return [[[a, b, c], _first_zone([Vector2i(x + 1, y), Vector2i(x, y - 1)])],
		[[a, c, d], _first_zone([Vector2i(x - 1, y), Vector2i(x, y + 1)])]]


func _first_zone(tiles: Array) -> String:
	for t in tiles:
		var z := zone(t.x, t.y)
		if z != "":
			return z
	return ""


## Whether the diagonal wall in tile (dx, dy) runs on into the wall tile (wx, wy) next to it corner to corner.
func _diag_joins(dx: int, dy: int, wx: int, wy: int) -> bool:
	if not wallish(wx, wy) or code(wx, wy) in DIAGS:
		return false
	var o := Vector2i(wx - dx, wy - dy)
	if code(dx, dy) == MapGen.IDIAG_A:
		return o == Vector2i(1, -1) or o == Vector2i(-1, 1)
	return o == Vector2i(1, 1) or o == Vector2i(-1, -1)


# ---------------------------------------------------------------- walls
func _row(y: int) -> Mesher:
	if not _row_meshers.has(y):
		_row_meshers[y] = Mesher.new()
		var n := Node3D.new()
		n.name = "WallRow%d" % y
		parent.add_child(n)
		rows[y] = n
	return _row_meshers[y]


func _walls() -> void:
	for y in h:
		for x in w:
			var c := code(x, y)
			if not c in WALLISH:
				continue
			if y == h - 1:
				# no front wall: only the walls running back from it come on, to the floor's front edge
				if wallish(x, y - 1) and not c in DIAGS:
					_bars(x, y, _foot(x, y), float(map.get("room", {}).get("wall_height", H)), false, true, false, false, true, false)
				continue
			var top := float(map.get("room", {}).get("wall_height", H))
			var e := wallish(x + 1, y)
			var wv := wallish(x - 1, y)
			var n := wallish(x, y - 1)
			var s := wallish(x, y + 1)
			var horiz := e or wv or (not n and not s)
			var vert := n or s
			if c in DIAGS:
				# corner to corner across the tile, each face finished like the room it faces
				var sides := _diag_sides(x, y)
				var p0 := Vector2(x, y + 1) if c == MapGen.IDIAG_A else Vector2(x, y)
				var p1 := Vector2(x + 1, y) if c == MapGen.IDIAG_A else Vector2(x + 1, y + 1)
				_slant(y, p0, p1, _foot(x, y), top, sides[0][1], sides[1][1], c)
				continue
			if c == MapGen.IWALL:
				# a diagonal wall next door, corner to corner: carry it on to this tile's centre
				for q in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
					var dx: int = x + q.x
					var dy: int = y + q.y
					if code(dx, dy) in DIAGS and _diag_joins(dx, dy, x, y):
						var sides2 := _diag_sides(dx, dy)
						var ctr := Vector2(x + 0.5, y + 0.5)
						_slant(y, ctr, ctr + Vector2(q.x, q.y) * 0.5, _foot(x, y), top, sides2[0][1], sides2[1][1], code(dx, dy))
			match c:
				MapGen.IWALL:
					if _cubbies.has(Vector2i(x, y)):
						_cubby_wall(x, y)
					else:
						_bars(x, y, _foot(x, y), top, horiz, vert, e, wv, n, s)
				MapGen.IWINDOW:
					if map.get("balcony_doors", {}).has(Vector2i(x, y)):
						var sill := Elev.surface(map, Vector2i(x, y))
						if sill > _foot(x, y):
							# (its dark top cut sinks under the floor carried through the doorway, so no seam shows)
							_bars(x, y, _foot(x, y), sill, horiz, vert, e, wv, n, s, 0.03)
						_bars(x, y, sill + BALCONY_H, top, horiz, vert, e, wv, n, s)
						_balcony_door(x, y, horiz)
					elif top < H:
						_bars(x, y, 0.0, top, horiz, vert, e, wv, n, s)
					elif map.get("room", {}).get("full_height_windows", false):
						_window(x, y, horiz)
					else:
						# (its dark cut sits under the sill, which caps it, rather than flickering in the sill's top)
						_bars(x, y, _foot(x, y), SILL + Elev.surface(map, Vector2i(x, y)), horiz, vert, e, wv, n, s, 0.06)
						_bars(x, y, WIN_TOP + Elev.surface(map, Vector2i(x, y)), top, horiz, vert, e, wv, n, s)
						_window(x, y, horiz)
				MapGen.IDOOR, MapGen.LOCKED:
					if top > DOOR_H:
						_bars(x, y, DOOR_H + Elev.surface(map, Vector2i(x, y)), top, horiz, vert, e, wv, n, s)
					_doorway(x, y, horiz, c == MapGen.LOCKED)


## The wall in tile (x, y) between heights y0 and y1: a bar along each line of wall through it, each face finished
## like the room it faces, with a skirting board along the bottom and a dark cut along the top (`cut_drop` below it,
## where something else caps the wall, such as a window's sill, so the two never share a plane and flicker).
func _bars(x: int, y: int, y0: float, y1: float, horiz: bool, vert: bool, e: bool, wv: bool, n: bool, s: bool, cut_drop := 0.0) -> void:
	var yc := y1 - cut_drop
	var m := _row(y)
	var cx := x + 0.5
	var cz := y + 0.5
	var cut := surface("cut", Color("#3a302a"))
	if horiz:
		var xa := float(x) if wv else cx - T / 2.0
		var xb := float(x + 1) if e else cx + T / 2.0
		for side in [-1, 1]:
			var zf: float = cz + side * T / 2.0
			var nrm := Vector3(0, 0, float(side))
			var dir := Vector2i(0, int(side))
			for half in [[xa, cx, Vector2i(-1, 0)], [cx, xb, Vector2i(1, 0)]]:
				var za := zone_side(x, y, dir, half[2])
				_face(m, za, [Vector3(half[0], y0, zf), Vector3(half[1], y0, zf), Vector3(half[1], y1, zf), Vector3(half[0], y1, zf)], nrm, Vector3.RIGHT)
				if y0 < 0.01:
					_skirting(m, Vector3(half[0], y0, zf), Vector3(half[1], y0, zf), nrm)
		if not vert:
			if not wv:
				_face(m, zone_side(x, y, Vector2i(-1, 0), Vector2i(0, -1)), [Vector3(xa, y0, cz - T / 2.0), Vector3(xa, y0, cz + T / 2.0),
					Vector3(xa, y1, cz + T / 2.0), Vector3(xa, y1, cz - T / 2.0)], Vector3.LEFT, Vector3.BACK)
			if not e:
				_face(m, zone_side(x, y, Vector2i(1, 0), Vector2i(0, -1)), [Vector3(xb, y0, cz - T / 2.0), Vector3(xb, y0, cz + T / 2.0),
					Vector3(xb, y1, cz + T / 2.0), Vector3(xb, y1, cz - T / 2.0)], Vector3.RIGHT, Vector3.BACK)
		m.quad("cut", cut, [Vector3(xa, yc, cz - T / 2.0), Vector3(xb, yc, cz - T / 2.0), Vector3(xb, yc, cz + T / 2.0), Vector3(xa, yc, cz + T / 2.0)],
			Vector3.UP, Vector3.RIGHT, Vector3.BACK)
	if vert:
		var za0 := float(y) if n else cz - T / 2.0
		var zb0 := float(y + 1) if s else cz + T / 2.0
		for side in [-1, 1]:
			var xf: float = cx + side * T / 2.0
			var nrm := Vector3(float(side), 0, 0)
			var dir := Vector2i(int(side), 0)
			for half in [[za0, cz, Vector2i(0, -1)], [cz, zb0, Vector2i(0, 1)]]:
				var zz := zone_side(x, y, dir, half[2])
				_face(m, zz, [Vector3(xf, y0, half[0]), Vector3(xf, y0, half[1]), Vector3(xf, y1, half[1]), Vector3(xf, y1, half[0])], nrm, Vector3.BACK)
				if y0 < 0.01:
					_skirting(m, Vector3(xf, y0, half[0]), Vector3(xf, y0, half[1]), nrm)
		if not horiz:
			if not n:
				_face(m, zone_side(x, y, Vector2i(0, -1), Vector2i(-1, 0)), [Vector3(cx - T / 2.0, y0, za0), Vector3(cx + T / 2.0, y0, za0),
					Vector3(cx + T / 2.0, y1, za0), Vector3(cx - T / 2.0, y1, za0)], Vector3.FORWARD, Vector3.RIGHT)
			if not s:
				_face(m, zone_side(x, y, Vector2i(0, 1), Vector2i(-1, 0)), [Vector3(cx - T / 2.0, y0, zb0), Vector3(cx + T / 2.0, y0, zb0),
					Vector3(cx + T / 2.0, y1, zb0), Vector3(cx - T / 2.0, y1, zb0)], Vector3.BACK, Vector3.RIGHT)
		m.quad("cut", cut, [Vector3(cx - T / 2.0, yc, za0), Vector3(cx + T / 2.0, yc, za0), Vector3(cx + T / 2.0, yc, zb0), Vector3(cx - T / 2.0, yc, zb0)],
			Vector3.UP, Vector3.RIGHT, Vector3.BACK)


## A stretch of diagonal wall between floor points p0 and p1 (x, z), from y0 to y1, T thick: a face each side, the
## first finished like `z_a` (the side the tile's first half lies on, see _diag_sides), the second like `z_b`, with
## skirting, and the dark cut along the top. Each end runs on a little, into the wall it meets.
func _slant(row: int, p0: Vector2, p1: Vector2, y0: float, y1: float, z_a: String, z_b: String, c: int) -> void:
	var m := _row(row)
	var dir := (p1 - p0).normalized()
	var a := p0 - dir * T * 0.5
	var b := p1 + dir * T * 0.5
	# the normal towards the first half: up-left for "/", up-right for "\\"
	var n2 := Vector2(-1, -1).normalized() if c == MapGen.IDIAG_A else Vector2(1, -1).normalized()
	if z_a == "":
		z_a = z_b
	if z_b == "":
		z_b = z_a
	if z_a == "":
		z_a = default_zone
		z_b = default_zone
	for side in [[n2, z_a], [-n2, z_b]]:
		var nn: Vector2 = side[0]
		var off := nn * T * 0.5
		var pa := Vector3(a.x + off.x, y0, a.y + off.y)
		var pb := Vector3(b.x + off.x, y0, b.y + off.y)
		var nrm := Vector3(nn.x, 0, nn.y)
		var along := (pb - pa).normalized()
		_face(m, side[1], [pa, pb, pb + Vector3(0, y1 - y0, 0), pa + Vector3(0, y1 - y0, 0)], nrm, along)
		if y0 < 0.01:
			_skirting(m, pa, pb, nrm)
	var cut := surface("cut", Color("#3a302a"))
	var o := Vector2(-dir.y, dir.x) * T * 0.5
	m.quad("cut", cut, [Vector3(a.x + o.x, y1, a.y + o.y), Vector3(b.x + o.x, y1, b.y + o.y), Vector3(b.x - o.x, y1, b.y - o.y),
		Vector3(a.x - o.x, y1, a.y - o.y)], Vector3.UP, Vector3.RIGHT, Vector3.BACK)


func _face(m: Mesher, z: String, p: Array, nrm: Vector3, along: Vector3) -> void:
	# a little darker low down, as if the light came from the ceiling
	m.quad("wall_" + z, wall_mat(z), p, nrm, along, Vector3.DOWN, 0.92)


func _skirting(m: Mesher, a: Vector3, b: Vector3, nrm: Vector3) -> void:
	if ancient:
		_plinth(m, a, b, nrm)
		return
	var off := nrm * 0.015
	var mat := surface("skirting", trim)
	var along := (b - a).normalized()
	m.quad("skirting", mat, [a + off, b + off, b + off + Vector3(0, 0.11, 0), a + off + Vector3(0, 0.11, 0)], nrm, along, Vector3.DOWN)


## An ancient wall's foot and head along a face from a to b: a plinth of darker stone, stepped out from the wall,
## and a cornice under the top with a thin glowing inlay of the temple's colour.
func _plinth(m: Mesher, a: Vector3, b: Vector3, nrm: Vector3) -> void:
	var foot := surface("plinth", stone.darkened(0.22))
	var head := surface("cornice", stone.lightened(0.06))
	var along := (b - a).normalized()
	# (a wall reaching down below the floor keeps its cornice under the top)
	var drop := -a.y
	for band in [[0.0, 0.34, 0.07, foot], [0.38, 0.42, 0.035, foot], [H - 0.42 + drop, H - 0.3 + drop, 0.06, head], [H - 0.3 + drop, H - 0.22 + drop, 0.09, head]]:
		var off: Vector3 = nrm * float(band[2])
		var y0: float = band[0]
		var y1: float = band[1]
		var mat: Material = band[3]
		m.quad("plinth" if mat == foot else "cornice", mat, [a + off + Vector3(0, y0, 0), b + off + Vector3(0, y0, 0), b + off + Vector3(0, y1, 0),
			a + off + Vector3(0, y1, 0)], nrm, along, Vector3.DOWN)
		m.quad("plinth" if mat == foot else "cornice", mat, [a + Vector3(0, y1, 0), b + Vector3(0, y1, 0), b + off + Vector3(0, y1, 0),
			a + off + Vector3(0, y1, 0)], Vector3.UP, along, nrm)
		m.quad("plinth" if mat == foot else "cornice", mat, [a + Vector3(0, y0, 0), b + Vector3(0, y0, 0), b + off + Vector3(0, y0, 0),
			a + off + Vector3(0, y0, 0)], Vector3.DOWN, along, nrm)
	var inlay := surface("inlay", _inlay_colour())
	inlay.emission_enabled = true
	inlay.emission = _inlay_colour()
	inlay.emission_energy_multiplier = 0.6
	var io := nrm * 0.065
	m.quad("inlay", inlay, [a + io + Vector3(0, H - 0.38 + drop, 0), b + io + Vector3(0, H - 0.38 + drop, 0), b + io + Vector3(0, H - 0.35 + drop, 0),
		a + io + Vector3(0, H - 0.35 + drop, 0)], nrm, along, Vector3.DOWN)


## The glow of a temple's inlays: its guardian's colour (the template's rug colour), brightened.
func _inlay_colour() -> Color:
	return Color(str(map.get("room", {}).get("rug", "#5ac8ff"))).lightened(0.35)


## Carved pilasters along an ancient room's walls, every PILASTER_EVERY tiles out from the middle of each wall, a
## flame burning on every other one: a KayKit torch in a temple (temple_lights.gd), a bronze bowl elsewhere; none beside a doorway or a window, and always in
## mirrored pairs. The temples are dark: the torches light them, at most MAX_TORCH_LIGHTS lit ones in a room (for
## the Mobile renderer's lights per mesh), spread evenly round it; the rest just burn.
const MAX_TORCH_LIGHTS := 6


func _pilasters() -> void:
	var col := surface("pilaster", stone.lightened(0.04))
	var cap := surface("pilaster_cap", stone.darkened(0.1))
	var bronze := surface("brass", Color("#b08840"))
	var flame := surface("flame", FLAME)
	flame.emission_enabled = true
	flame.emission = FLAME
	flame.emission_energy_multiplier = 2.4
	flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var torches := []
	# (a back wall with waterfalls down it has its pilasters behind the levers between them)
	var lever_posts := {}
	if not map.get("fall_spots", {}).is_empty() and map.get("lattices", {}).is_empty():
		for sw in map.get("switches", []):
			lever_posts[sw["pos"]] = true
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if code(x, y) in WALLISH or code(x, y) == MapGen.IVOID:
				continue
			for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]:
				var wx: int = x + d.x
				var wy: int = y + d.y
				if code(wx, wy) != MapGen.IWALL:
					continue
				if _cubbies.has(Vector2i(wx, wy)):
					continue
				var along_i := Vector2i(1, 0) if d.y != 0 else Vector2i(0, 1)
				# spaced out from the middle of the wall, so each wall's run is symmetrical
				var span := w if d.y != 0 else h
				var off2 := absi(2 * (x if d.y != 0 else y) - (span - 1))
				var stands: bool = off2 % (2 * PILASTER_EVERY) == (span - 1) % 2 * PILASTER_EVERY
				if d.y != 0 and not lever_posts.is_empty():
					stands = lever_posts.has(Vector2i(x, y))
				if not stands:
					continue
				# none beside an opening or where a round pillar stands against the wall, here or at its mirror image across
				# the room (so they go in pairs)
				if not _pilaster_fits(wx, wy, along_i) or not _pilaster_fits(w - 1 - wx, wy, along_i):
					continue
				if code(x, y) == MapGen.PILLAR or code(w - 1 - x, y) == MapGen.PILLAR:
					continue
				var m := _row(wy)
				# the wall's face (walls stand T thick in the middle of their tile), the pilaster built out from it, standing
				# on the floor on a square base, its capital under the cornice
				var face := Vector3(x + 0.5, 0, y + 0.5) + Vector3(d.x, 0, d.y) * (1.0 - T / 2.0)
				var out := -Vector3(d.x, 0, d.y)
				var wide := Vector3(along_i.x, 0, along_i.y)
				var low := _foot(x, y)
				m.box("pilaster", col, face + out * 0.12 + Vector3(0, (H - 0.3 + low) / 2.0, 0), wide * 0.42 + out.abs() * 0.24 + Vector3(0, H - 0.3 - low, 0))
				m.box("pilaster_cap", cap, face + out * 0.15 + Vector3(0, H - 0.36, 0), wide * 0.56 + out.abs() * 0.3 + Vector3(0, 0.12, 0))
				m.box("pilaster_cap", cap, face + out * 0.15 + Vector3(0, low + 0.2, 0), wide * 0.54 + out.abs() * 0.3 + Vector3(0, 0.4, 0))
				# (every other one out from the middle, the same either side)
				if off2 / PILASTER_EVERY / 2 % 2 == 1:
					continue
				# in a temple, a torch on the pilaster's face
				if temple:
					torches.append([x, y, face + out * 0.24 + Vector3(0, 1.3, 0), out])
					continue
				# elsewhere (the Beast Centers), a bronze bowl on a bracket, a flame in it
				m.box("brass", bronze, face + out * 0.34 + Vector3(0, 1.62, 0), wide * 0.08 + out.abs() * 0.22 + Vector3(0, 0.05, 0))
				m.box("brass", bronze, face + out * 0.46 + Vector3(0, 1.7, 0), wide * 0.24 + out.abs() * 0.24 + Vector3(0, 0.1, 0))
				m.box("flame", flame, face + out * 0.46 + Vector3(0, 1.84, 0), wide * 0.14 + out.abs() * 0.14 + Vector3(0, 0.2, 0))
				m.box("flame", flame, face + out * 0.46 + Vector3(0, 1.98, 0), wide * 0.07 + out.abs() * 0.07 + Vector3(0, 0.12, 0))
	var lit := {}
	var n := torches.size()
	for i in mini(n, MAX_TORCH_LIGHTS):
		lit[int(floor((i + 0.5) * n / float(mini(n, MAX_TORCH_LIGHTS))))] = true
	for i in n:
		var t: Array = torches[i]
		_attach(t[0], t[1], TempleLights.wall_torch(t[2], t[3], lit.has(i)))


## Whether wall tile (wx, wy) can carry a pilaster: plain wall, with no doorway or window either side of it along the
## wall.
func _pilaster_fits(wx: int, wy: int, along_i: Vector2i) -> bool:
	if code(wx, wy) != MapGen.IWALL:
		return false
	for o in [-1, 1]:
		var q: Vector2i = Vector2i(wx, wy) + along_i * o
		if code(q.x, q.y) in [MapGen.IDOOR, MapGen.LOCKED, MapGen.IWINDOW]:
			return false
	return true


## An ancient room's doorway: a stone portal, massive jambs and a lintel with the temple's glowing inlay, and the dark
## passage beyond (out to the open air it's left empty). No door: you walk straight through.
func _portal(x: int, y: int, horiz: bool) -> void:
	var m := _row(y)
	var c := Vector3(x + 0.5, Elev.surface(map, Vector2i(x, y)), y + 0.5)
	var along := Vector3.RIGHT if horiz else Vector3.BACK
	var dark := surface("portal_jamb", stone.darkened(0.12))
	var lintel := surface("portal_lintel", stone.lightened(0.05))
	for side in [-1.0, 1.0]:
		m.box("portal_jamb", dark, c + along * side * 0.47 + Vector3(0, DOOR_H / 2.0, 0), _axes(along, 0.2, DOOR_H, T + 0.24, horiz))
		m.box("portal_jamb", dark, c + along * side * 0.47 + Vector3(0, 0.15, 0), _axes(along, 0.3, 0.3, T + 0.34, horiz))
	m.box("portal_lintel", lintel, c + Vector3(0, DOOR_H + 0.14, 0), _axes(along, 1.34, 0.28, T + 0.3, horiz))
	m.box("portal_lintel", lintel, c + Vector3(0, DOOR_H + 0.34, 0), _axes(along, 1.06, 0.12, T + 0.22, horiz))
	var inlay := surface("inlay", _inlay_colour())
	inlay.emission_enabled = true
	inlay.emission = _inlay_colour()
	inlay.emission_energy_multiplier = 0.9
	m.box("inlay", inlay, c + Vector3(0, DOOR_H + 0.14, 0), _axes(along, 0.5, 0.06, T + 0.32, horiz))
	var ex: Dictionary = map.get("exits", {}).get(Vector2i(x, y), {})
	if not ex.is_empty() and not String(ex["to"]).contains("#"):
		return
	var past := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = _axes(along, 0.74, DOOR_H, 0.04, horiz)
	past.mesh = bm
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.albedo_color = Color("#14100c")
	past.material_override = pm
	past.position = c + Vector3(0, DOOR_H / 2.0, 0)
	_attach(x, y, past)


## A great stone door in an aqua-blue frame, engraved with waves round a glowing gem. It sinks into the floor to open
## (door_leaves "lift", see open_door), and locked it just stays shut.
func _stone_door(x: int, y: int, horiz: bool) -> void:
	var m := _row(y)
	var c := Vector3(x + 0.5, Elev.surface(map, Vector2i(x, y)), y + 0.5)
	var along := Vector3.RIGHT if horiz else Vector3.BACK
	var across := Vector3.BACK if horiz else Vector3.RIGHT
	var frame := surface("stone_door_frame", Color("#4fc4d6"))
	frame.emission_enabled = true
	frame.emission = Color("#4fc4d6")
	frame.emission_energy_multiplier = 0.45
	for side in [-1.0, 1.0]:
		m.box("stone_door_frame", frame, c + along * side * 0.5 + Vector3(0, DOOR_H / 2.0, 0), _axes(along, 0.16, DOOR_H, T + 0.3, horiz))
	m.box("stone_door_frame", frame, c + Vector3(0, DOOR_H + 0.08, 0), _axes(along, 1.16, 0.18, T + 0.3, horiz))
	var past := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = _axes(along, 0.84, DOOR_H, 0.04, horiz)
	past.mesh = bm
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.albedo_color = Color("#101820")
	past.material_override = pm
	past.position = c + Vector3(0, DOOR_H / 2.0, 0)
	past.visible = false
	_attach(x, y, past)
	var leaf := Node3D.new()
	leaf.position = c
	var lm := Mesher.new()
	var slab := surface("stone_door_slab", stone.darkened(0.08))
	var cut := surface("stone_door_cut", stone.darkened(0.42))
	var pale := surface("stone_door_pale", stone.lightened(0.1))
	lm.box("stone_door_slab", slab, Vector3(0, DOOR_H / 2.0, 0), _axes(along, 0.86, DOOR_H, T + 0.1, horiz))
	# engraved on both faces
	for face_side in [-1.0, 1.0]:
		var o: Vector3 = across * face_side * (T / 2.0 + 0.055)
		for r in [0.0, 1.0]:
			var inset: float = 0.08 + r * 0.1
			for s in [-1.0, 1.0]:
				lm.box("stone_door_cut", cut, o + along * s * (0.43 - inset) + Vector3(0, DOOR_H / 2.0, 0), _axes(along, 0.03, DOOR_H - inset * 2.0, 0.012, horiz))
				lm.box("stone_door_cut", cut, o + Vector3(0, DOOR_H / 2.0 + s * (DOOR_H / 2.0 - inset), 0), _axes(along, 0.86 - inset * 2.0, 0.03, 0.012, horiz))
		# rows of little waves
		for row in 4:
			var wy: float = 0.42 + row * 0.36
			if row == 2:
				continue
			for k in 4:
				var wx: float = -0.21 + k * 0.14
				lm.box("stone_door_pale", pale, o + along * wx + Vector3(0, wy, 0), _axes(along, 0.1, 0.03, 0.014, horiz))
				lm.box("stone_door_pale", pale, o + along * (wx + 0.05) + Vector3(0, wy + 0.05, 0), _axes(along, 0.05, 0.03, 0.014, horiz))
		var gem := surface("stone_door_gem", Color("#7fe8f4"))
		gem.emission_enabled = true
		gem.emission = Color("#7fe8f4")
		gem.emission_energy_multiplier = 1.4
		lm.box("stone_door_gem", gem, o + Vector3(0, 1.14, 0), _axes(along, 0.2, 0.2, 0.03, horiz))
	var mi := MeshInstance3D.new()
	mi.mesh = lm.mesh()
	leaf.add_child(mi)
	_attach(x, y, leaf)
	door_leaves[Vector2i(x, y)] = {"node": leaf, "yaw": 0.0, "past": past, "lift": -DOOR_H - 0.1, "base": c.y}


## A doorway: a wooden frame round the opening on both faces. An opening between parts of a room is just that; a door
## that leads out of the room (see map_loader.gd _interior) is painted blue, and a locked one red, so you can tell at a
## glance which doors open. The front door, out to the street, is glazed, with a bright window over it.
func _doorway(x: int, y: int, horiz: bool, locked: bool) -> void:
	if map.get("stone_doors", {}).has(Vector2i(x, y)):
		_stone_door(x, y, horiz)
		return
	if ancient and not locked:
		_portal(x, y, horiz)
		return
	var m := _row(y)
	var cx := x + 0.5
	var cz := y + 0.5
	var fr := surface("frame", trim)
	var top := DOOR_H
	var along := Vector3.RIGHT if horiz else Vector3.BACK
	var across := Vector3.BACK if horiz else Vector3.RIGHT
	var c := Vector3(cx, Elev.surface(map, Vector2i(x, y)), cz)
	for side in [-1.0, 1.0]:
		# the jambs (as deep as the wall, a little proud of it) and the head
		m.box("frame", fr, c + along * side * 0.46 + Vector3(0, top / 2.0, 0), _axes(along, 0.09, top + 0.0, T + 0.06, horiz))
	m.box("frame", fr, c + Vector3(0, top + 0.05, 0), _axes(along, 1.0, 0.1, T + 0.06, horiz))
	if map.get("open_doors", {}).has(Vector2i(x, y)):
		# A short, closed recess gives the open hallway depth without exposing the void beyond the set.
		var inside := _into_room_side(x, y, horiz)
		var tunnel := surface("wall_plaster", Color("#75624e"))
		_recess(x, y, inside, c.y, c.y + DOOR_H, 0.41, 0.35, true, tunnel)
		return
	var ex: Dictionary = map.get("exits", {}).get(Vector2i(x, y), {})
	if not ex.is_empty() or locked:
		var front := not ex.is_empty() and not String(ex["to"]).contains("#")
		if locked:
			_door_leaf(m, c, horiz, DOOR_LOCKED, front)
		else:
			_hinged_leaf(x, y, horiz, front)
		if front:
			_exit_banner(m, c + Vector3(0, top + 0.30, 0), horiz)
	if locked:
		if map.get("staff_doors", {}).has(Vector2i(x, y)):
			# a small brass plate: STAFF ONLY
			for side in [-1.0, 1.0]:
				var lab := Label3D.new()
				load("res://scripts/gfx/world_lettering.gd").apply(lab, "STAFF ONLY")
				lab.font_size = 14
				lab.pixel_size = 0.006
				lab.modulate = Color("#2a1a10")
				lab.outline_size = 0
				lab.position = c + Vector3(0, 1.45, 0) + across * side * 0.082
				lab.rotation.y = (0.0 if horiz else PI / 2.0) + (0.0 if side > 0.0 else PI)
				var plate := MeshInstance3D.new()
				var pm := BoxMesh.new()
				pm.size = Vector3(0.5, 0.14, 0.02)
				plate.mesh = pm
				plate.material_override = surface("brass", Color("#d8b050"))
				plate.position = c + Vector3(0, 1.45, 0) + across * side * 0.07
				plate.rotation.y = lab.rotation.y
				_attach(x, y, plate)
				_attach(x, y, lab)

	if mission and (ex.is_empty() or String(ex["to"]).contains("#")):
		_mission_door_arch(x, y, horiz)

## A door, closed in its doorway: a painted leaf with two raised panels and a brass knob on each face. A front door
## has a pane of glass in its upper half instead of a panel.
func _door_leaf(m: Mesher, c: Vector3, horiz: bool, col: Color, glazed: bool) -> void:
	var along := Vector3.RIGHT if horiz else Vector3.BACK
	var across := Vector3.BACK if horiz else Vector3.RIGHT
	var leaf := surface("door_paint", col)
	var panel := surface("door_paint", col.lightened(0.16))
	var brass := surface("brass", Color("#d8b050"))
	var key := "door_" + col.to_html(false)
	var hgt := DOOR_H - 0.03
	m.box(key, leaf, c + Vector3(0, hgt / 2.0, 0), _axes(along, 0.82, hgt, 0.07, horiz))
	for side in [-1.0, 1.0]:
		var face: Vector3 = across * side * 0.042
		m.box(key + "_panel", panel, c + face + Vector3(0, 0.52, 0), _axes(along, 0.56, 0.64, 0.02, horiz))
		if glazed:
			m.box("door_glass", _glass(), c + face + Vector3(0, 1.36, 0), _axes(along, 0.5, 0.62, 0.02, horiz))
			m.box("frame", surface("frame", trim), c + across * side * 0.06 + Vector3(0, 1.36, 0), _axes(along, 0.035, 0.62, 0.018, horiz))
		else:
			m.box(key + "_panel", panel, c + face + Vector3(0, 1.36, 0), _axes(along, 0.56, 0.68, 0.02, horiz))
		m.box("brass", brass, c + across * side * 0.06 + along * 0.29 + Vector3(0, 0.98, 0), Vector3(0.08, 0.08, 0.08))


## A door you can go through, in the doorway at (x, y): its leaf on a hinge of its own, on the jamb away from its knob,
## so it can swing open out of the room as you go through (open_door) and shut behind you as you come in (shut_door).
## Behind it, seen once it's open: a dim room, unless it's a front door, whose doorway is left empty.
func _hinged_leaf(x: int, y: int, horiz: bool, front: bool) -> void:
	var c := Vector3(x + 0.5, Elev.surface(map, Vector2i(x, y)), y + 0.5)
	var along := Vector3.RIGHT if horiz else Vector3.BACK
	# which side is the room? (the door swings away from it)
	var inside := Vector2i(0, 1) if horiz else Vector2i(1, 0)
	if zone(x + inside.x, y + inside.y) == "":
		inside = -inside
	var out := -Vector3(inside.x, 0, inside.y)
	var hinge := Node3D.new()
	hinge.position = c - along * 0.41 + out * 0.035
	var lm := Mesher.new()
	_door_leaf(lm, c - hinge.position, horiz, DOOR_OPENS, front)
	var leaf := MeshInstance3D.new()
	leaf.mesh = lm.mesh()
	hinge.add_child(leaf)
	_attach(x, y, hinge)
	# the way it turns: its free edge round towards the outside, not quite flat against the wall beyond
	var turn := 1.0 if (Basis(Vector3.UP, PI / 2.0) * along).dot(out) > 0.0 else -1.0
	var door := {"node": hinge, "yaw": turn * deg_to_rad(85.0)}
	door_leaves[Vector2i(x, y)] = door
	if front:
		return
	var past := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.2, DOOR_H + 0.2)
	past.mesh = q
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.albedo_color = Color("#3a2e24")
	past.material_override = pm
	past.position = c + out * (T / 2.0 + 0.02) + Vector3(0, DOOR_H / 2.0, 0)
	past.rotation.y = atan2(float(inside.x), float(inside.y))
	past.visible = false
	_attach(x, y, past)
	door["past"] = past


## Swings the door at tile `t` open over `secs` (see _hinged_leaf).
func open_door(t: Vector2i, secs := 0.35) -> void:
	var d: Dictionary = door_leaves.get(t, {})
	if d.is_empty():
		return
	if d.has("past"):
		(d["past"] as Node3D).visible = true
	var hinge: Node3D = d["node"]
	if d.has("lift"):
		hinge.create_tween().tween_property(hinge, "position:y", float(d["base"]) + float(d["lift"]), maxf(secs, 0.9)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		return
	hinge.create_tween().tween_property(hinge, "rotation:y", float(d["yaw"]), secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## The door at tile `t` (the one you've just come in by) standing open, swinging shut after `wait` over `secs`.
func shut_door(t: Vector2i, wait := 0.15, secs := 0.4) -> void:
	var d: Dictionary = door_leaves.get(t, {})
	if d.is_empty():
		return
	var hinge: Node3D = d["node"]
	var past: Node3D = d.get("past")
	if past != null:
		past.visible = true
	var tw := hinge.create_tween()
	if d.has("lift"):
		hinge.position.y = float(d["base"]) + float(d["lift"])
		tw.tween_interval(wait)
		tw.tween_property(hinge, "position:y", float(d["base"]), secs + 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		hinge.rotation.y = float(d["yaw"])
		tw.tween_interval(wait)
		tw.tween_property(hinge, "rotation:y", 0.0, secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if past != null:
		tw.tween_callback(func() -> void: past.visible = false)


## Woven geometric exit markers: several yarn palettes, stepped diamonds and a clear downward triangle.
## Mesh details share the room's batches; no texture generation or extra shadow casters.
func _exit_banner(m: Mesher, c: Vector3, horiz: bool) -> void:
	var palettes := [[Color("#804737"), Color("#d9b377"), Color("#426b70")],
		[Color("#365f69"), Color("#e2c599"), Color("#a55b3e")],
		[Color("#665475"), Color("#dbc89a"), Color("#819477")]]
	var palette: Array = palettes[absi(hash(str(map.get("building", {}).get("seed", 0)) + str(c))) % palettes.size()]
	var along := Vector3.RIGHT if horiz else Vector3.BACK
	var across := Vector3.BACK if horiz else Vector3.RIGHT
	m.box("banner_rod", surface("frame", trim), c+Vector3.UP*0.19, _axes(along, 0.92, 0.035, T+0.08, horiz))
	m.box("exit_cloth_"+str(palette[0]), surface("exit_cloth", palette[0]), c, _axes(along, 0.80, 0.34, T+0.04, horiz))
	for side in [-1.0, 1.0]:
		var face: Vector3 = c + across*side*(T/2.0+0.023)
		var ink := surface("exit_yarn", palette[1])
		for h in [-0.13, 0.13]:
			m.box("exit_yarn_"+str(palette[1]), ink, face+Vector3.UP*h, _axes(along, 0.75, 0.025, 0.005, horiz))
		for dx in [-0.29, 0.29]:
			var centre: Vector3 = face+along*dx
			m.quad("exit_diamond_"+str(palette[2]), surface("exit_diamond", palette[2]), [centre-Vector3.UP*0.095, centre+along*0.07, centre+Vector3.UP*0.095, centre-along*0.07], across*side, along, Vector3.UP)
		m.tri("exit_arrow_"+str(palette[1]), ink, [face-along*0.105+Vector3.UP*0.07, face+along*0.105+Vector3.UP*0.07, face-Vector3.UP*0.095], across*side, along, Vector3.UP)
		for dx in [-0.34, -0.23, -0.12, 0.0, 0.12, 0.23, 0.34]:
			m.box("exit_fringe_"+str(palette[1]), ink, face+along*dx-Vector3.UP*0.185, _axes(along, 0.015, 0.035, 0.005, horiz))


## Pale blue glass, softly lit by the day outside without clipping to a white panel.
func _glass() -> StandardMaterial3D:
	var g := surface("door_glass", Color("#82b8cd"))
	if not g.emission_enabled:
		g.emission_enabled = true
		g.emission = Color("#91c7db")
		g.emission_energy_multiplier = 0.12
	return g


## A box's size given its length along `along`, height, and depth across.
func _axes(along: Vector3, length: float, height: float, depth: float, horiz: bool) -> Vector3:
	return Vector3(length, height, depth) if horiz else Vector3(depth, height, length)


## A window in the wall: recessed into it, with its casing, deep sill and (in living rooms and bedrooms) curtains
## beside it (_recessed_window).
func _window(x: int, y: int, horiz: bool) -> void:
	# which side is the room?
	var inside := Vector2i(0, 1) if horiz else Vector2i(1, 0)
	if zone(x + inside.x, y + inside.y) == "":
		inside = -inside
	_recessed_window(x, y, inside)


## An open doorway onto a balcony (map_loader.gd "!"), seen from the room: no leaf, a frame round the opening and
## curtains drawn back either side. Beyond it lies the window box planned behind it (the user's 2026-11-15
## direction: the hotel's arched doorways look out into its nature); only where no box fits does it get its own tiled
## balcony, iron railing and sea under the sky, closed in at the sides and above so nothing past the room shows. You
## can't walk out: the tile stays wall.
func _balcony_door(x: int, y: int, horiz: bool) -> void:
	var m := _row(y)
	var c := Vector3(x + 0.5, Elev.surface(map, Vector2i(x, y)), y + 0.5)
	var inside := Vector2i(0, 1) if horiz else Vector2i(1, 0)
	if zone(x + inside.x, y + inside.y) == "":
		inside = -inside
	var z := zone(x + inside.x, y + inside.y)
	var into := Vector3(inside.x, 0, inside.y)
	var along := Vector3.RIGHT if horiz else Vector3.BACK
	var yaw := atan2(float(inside.x), float(inside.y))
	var fr := surface("frame", trim)
	for side in [-1.0, 1.0]:
		m.box("frame", fr, c + along * side * 0.46 + Vector3(0, BALCONY_H / 2.0, 0), _axes(along, 0.09, BALCONY_H, T + 0.06, horiz))
	m.box("frame", fr, c + Vector3(0, BALCONY_H + 0.05, 0), _axes(along, 1.0, 0.1, T + 0.06, horiz))
	var iron := surface("iron", Color("#2d2622"))
	if _box_of.has(Vector2i(x, y)):
		_juliet_balcony(m, x, y, z, c, -into, along, horiz, iron)
	else:
		m.box("frame", fr, c + Vector3(0, 0.02, 0), _axes(along, 0.86, 0.04, T + 0.02, horiz))
		_balcony_beyond(x, y, horiz, c, into, along, yaw, z, iron)
	# wide curtains hanging straight either side of the opening from an iron rod with knob ends, on the room side, in
	# a colour that stands out from the wall (never the wall's own: the user's 2026-11-16 rule)
	var drape := surface("drape_" + _curtain_colour(z).to_html(false), _curtain_colour(z))
	var rod := c + into * (T / 2.0 + 0.1)
	var rod_y := BALCONY_H + 0.2
	m.box("iron", iron, rod + Vector3(0, rod_y, 0), _axes(along, 1.62, 0.06, 0.06, horiz))
	for side in [-1.0, 1.0]:
		m.box("iron", iron, rod + along * side * 0.83 + Vector3(0, rod_y, 0), Vector3.ONE * 0.11)
		# (inner edge just over the door frame, outer edge 0.28 past it)
		var at: Vector3 = rod + along * side * 0.64
		m.box("drape", drape, at + Vector3(0, (rod_y - 0.03) / 2.0, 0), _axes(along, 0.28, rod_y - 0.03, 0.06, horiz))
	if mission:
		_mission_balcony_arch(x, y, horiz, into, z)


## A little balcony half a tile deep outside an open doorway that looks into a window box (the user's 2026-11-15
## direction): a stone slab on corbels whose top is the room's own floor, carried on through the doorway with no
## threshold or seam, running half a tile past the doorway at each end, with a wrought-iron railing round its open
## edges. Neighbouring doorways' balconies that meet join into one, with no railing between them. `c` is the
## doorway's foot at the wall's middle.
const JULIET_DEEP := 0.5
const JULIET_W := 2.0


func _juliet_balcony(m: Mesher, x: int, y: int, z: String, c: Vector3, out: Vector3, along: Vector3, horiz: bool, iron: Material) -> void:
	var stone := surface("balcony_stone", Color("#ebe1cf"))
	var face := c + out * (T / 2.0)
	var mid := face + out * (JULIET_DEEP / 2.0)
	var step := Vector2i(int(along.x), int(along.z))
	var balconies: Dictionary = map.get("balcony_doors", {})
	# (a doorway two tiles along has a balcony that meets this one; one tile along would overlap it, so each stops
	# at the middle between them)
	var lo := -0.5 if balconies.has(Vector2i(x, y) - step) else -JULIET_W / 2.0
	var hi := 0.5 if balconies.has(Vector2i(x, y) + step) else JULIET_W / 2.0
	var joined := {-1: lo > -JULIET_W / 2.0 or balconies.has(Vector2i(x, y) - step * 2),
		1: hi < JULIET_W / 2.0 or balconies.has(Vector2i(x, y) + step * 2)}
	var centre := (lo + hi) / 2.0
	var width := hi - lo
	m.box("balcony_stone", stone, mid + along * centre + Vector3(0, -0.09, 0), _axes(along, width, 0.16, JULIET_DEEP, horiz))
	for side in [-1.0, 1.0]:
		m.box("balcony_stone", stone, face + out * 0.17 + along * side * 0.5 + Vector3(0, -0.3, 0), _axes(along, 0.14, 0.26, 0.34, horiz))
	# the room's floor, from the wall's room face through the doorway to the balcony's edge (the floor's own texture,
	# mapped in world space like the room's, so it runs on unbroken)
	var inner := c - out * (T / 2.0)
	var a0 := inner + along * -0.5
	var a1 := inner + along * 0.5
	var b0 := face + along * lo
	var b1 := face + along * hi
	var lift := Vector3(0, 0.001, 0)
	var fm := floor_mat(z)
	floor_mesher.quad("floor_" + z, fm, [a0 + lift, a1 + lift, a1 + out * T + lift, a0 + out * T + lift], Vector3.UP, Vector3.RIGHT, Vector3.BACK)
	floor_mesher.quad("floor_" + z, fm, [b0 + lift, b1 + lift, b1 + out * JULIET_DEEP + lift, b0 + out * JULIET_DEEP + lift],
		Vector3.UP, Vector3.RIGHT, Vector3.BACK)
	# the railing, all wrought iron: a top rail and a bottom rail along the front, bars every 0.11
	var rail_h := 0.9
	var edge := face + out * (JULIET_DEEP - 0.04)
	m.box("iron", iron, edge + along * centre + Vector3(0, rail_h - 0.025, 0), _axes(along, width, 0.05, 0.06, horiz))
	m.box("iron", iron, edge + along * centre + Vector3(0, 0.1, 0), _axes(along, width, 0.035, 0.035, horiz))
	var bars := int(round(width / 0.11))
	for i in bars:
		var u := lo + (float(i) + 0.5) * width / float(bars)
		m.box("iron", iron, edge + along * u + Vector3(0, rail_h / 2.0, 0), _axes(along, 0.025, rail_h - 0.05, 0.025, horiz))
	for side in [-1, 1]:
		if joined[side]:
			continue
		var end := (hi if side > 0 else lo) - float(side) * 0.03
		m.box("iron", iron, edge + along * end + Vector3(0, rail_h / 2.0, 0), _axes(along, 0.05, rail_h, 0.05, horiz))
		var run: Vector3 = face + out * (JULIET_DEEP / 2.0) + along * end
		m.box("iron", iron, run + Vector3(0, rail_h - 0.025, 0), _axes(along, 0.06, 0.05, JULIET_DEEP, horiz))
		m.box("iron", iron, run + Vector3(0, 0.1, 0), _axes(along, 0.035, 0.035, JULIET_DEEP, horiz))
		for k in 3:
			m.box("iron", iron, face + out * (0.12 + 0.11 * float(k)) + along * end + Vector3(0, rail_h / 2.0, 0),
				_axes(along, 0.025, rail_h - 0.05, 0.025, horiz))


## Curtains in a colour that stands out from the room's wall: maroon against a light wall (the user's 2026-11-16
## choice), a warm cream against a dark one (never the wall's own colour, the user's 2026-11-16 rule).
func _curtain_colour(_z: String) -> Color:
	var wall := Color(str(map.get("room", {}).get("wall", "#fbf1e2")))
	return Color("#6e1f2b") if wall.get_luminance() > 0.5 else Color("#f3ead8")


## A balcony of its own beyond an open doorway that has no window box behind it.
func _balcony_beyond(x: int, y: int, horiz: bool, c: Vector3, into: Vector3, along: Vector3, yaw: float, z: String, iron: Material) -> void:
	var m := _row(y)
	# the balcony: its floor, its side walls and a ceiling, all in the room's wall finish but the tiles
	var out := -into
	var deep := 0.8
	var mid := c + out * (T / 2.0 + deep / 2.0)
	m.box("balcony_tile", surface("balcony_tile", Color("#d49a72")), mid + Vector3(0, 0.03, 0), _axes(along, 1.0, 0.06, deep, horiz))
	var wall := wall_mat(z)
	# (kept low, just over the doorway's head, so none of it shows above the back wall from the camera)
	var roof := BALCONY_H + 0.1
	for side in [-1.0, 1.0]:
		m.box("balcony_wall_" + z, wall, mid + along * side * 0.5 + Vector3(0, roof / 2.0, 0), _axes(along, 0.06, roof, deep, horiz))
	m.box("balcony_wall_" + z, wall, mid + Vector3(0, roof - 0.05, 0), _axes(along, 1.06, 0.1, deep, horiz))
	# an iron railing along its edge
	var rail := c + out * (T / 2.0 + deep - 0.12)
	m.box("iron", iron, rail + Vector3(0, 0.92, 0), _axes(along, 0.94, 0.05, 0.05, horiz))
	m.box("iron", iron, rail + Vector3(0, 0.12, 0), _axes(along, 0.94, 0.035, 0.035, horiz))
	for i in 9:
		m.box("iron", iron, rail + along * (-0.42 + 0.105 * float(i)) + Vector3(0, 0.5, 0), _axes(along, 0.025, 0.86, 0.025, horiz))
	# the sea and the sky beyond, glowing like a window's
	for part in [[0.0, 0.8, Color("#4fb3dc"), Color("#3a9cc8")], [0.8, BALCONY_H + 0.05, Color("#d4ecff"), Color("#bcdcff")]]:
		var view := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.94, float(part[1]) - float(part[0]))
		view.mesh = q
		var vm := StandardMaterial3D.new()
		vm.albedo_color = part[2]
		vm.emission_enabled = true
		vm.emission = part[3]
		vm.emission_energy_multiplier = 0.9
		view.material_override = vm
		view.position = c + out * (T / 2.0 + deep - 0.02) + Vector3(0, (float(part[0]) + float(part[1])) / 2.0, 0)
		view.rotation.y = yaw
		_attach(x, y, view)


# ---------------------------------------------------------------- a Spanish mission's finish (Hotel Mariposa)
const MISSION_WOOD := Color("#4a2c1a")
const MISSION_IRON := Color("#2d2622")
const DADO_TOP := 0.8
const DESK_TOP := 1.02


## Glazed blue-and-white azulejo tiles with ochre rings, for a mission room's dado: drawn once, soft-edged like the
## rest of the painted textures, four tiles to a metre.
static func azulejo_material() -> StandardMaterial3D:
	if _mats.has("azulejo"):
		return _mats["azulejo"]
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var base := Color("#f4efe3")
	var blue := Color("#2c5c9c")
	var ochre := Color("#d9a441")
	var grout := Color("#d8d0c0")
	for py in n:
		for px in n:
			var u := (px + 0.5) / n - 0.5
			var v := (py + 0.5) / n - 0.5
			var col := base
			var ring := absf(absf(u) + absf(v) - 0.28)
			var dot := Vector2(u, v).length()
			var corner := Vector2(0.5 - absf(u), 0.5 - absf(v)).length()
			var ink := maxf(1.0 - smoothstep(0.02, 0.045, ring), 1.0 - smoothstep(0.07, 0.1, dot))
			ink = maxf(ink, (1.0 - smoothstep(0.17, 0.2, corner)) * 0.85)
			col = col.lerp(blue, ink)
			col = col.lerp(ochre, 1.0 - smoothstep(0.015, 0.035, absf(corner - 0.25)))
			col = col.lerp(grout, smoothstep(0.465, 0.5, maxf(absf(u), absf(v))))
			img.set_pixel(px, py, col)
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.vertex_color_use_as_albedo = true
	m.uv1_scale = Vector3(4.0, 4.0, 1.0)
	m.roughness = 0.35
	_mats["azulejo"] = m
	return m


## A candle flame or lamp: a warm colour that glows.
static func flame_material() -> StandardMaterial3D:
	if _mats.has("mission_flame"):
		return _mats["mission_flame"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#ffe3a0")
	m.emission_enabled = true
	m.emission = Color("#ffc96a")
	m.emission_energy_multiplier = 1.6
	_mats["mission_flame"] = m
	return m


## A box `length` long along `along` (x or z), `height` high and `depth` deep across it.
func _along_box(m: Mesher, key: String, mat: Material, c: Vector3, along: Vector3, length: float, height: float, depth: float) -> void:
	m.box(key, mat, c, Vector3(length, height, depth) if absf(along.x) > 0.5 else Vector3(depth, height, length))


## A flat band round a half circle on a wall face, from radius r0 to r1 round `c` (r0 0: a filled half disc).
func _arch_band(m: Mesher, key: String, mat: Material, c: Vector3, along: Vector3, nrm: Vector3, r0: float, r1: float) -> void:
	for i in 12:
		var a0 := PI * float(i) / 12.0
		var a1 := PI * float(i + 1) / 12.0
		var d0 := along * cos(a0) + Vector3.UP * sin(a0)
		var d1 := along * cos(a1) + Vector3.UP * sin(a1)
		if r0 <= 0.0:
			m.tri(key, mat, [c, c + d0 * r1, c + d1 * r1], nrm, along, Vector3.UP)
		else:
			m.quad(key, mat, [c + d0 * r0, c + d1 * r0, c + d1 * r1, c + d0 * r1], nrm, along, Vector3.UP)


## A round arch over a doorway on both faces of its wall: a dark carved band with a painted-tile tympanum inside it.
func _mission_door_arch(x: int, y: int, horiz: bool) -> void:
	var m := _row(y)
	var along := Vector3.RIGHT if horiz else Vector3.BACK
	var across := Vector3.BACK if horiz else Vector3.RIGHT
	var wood := surface("mission_wood", MISSION_WOOD)
	for side in [-1.0, 1.0]:
		var c: Vector3 = Vector3(x + 0.5, DOOR_H + 0.1, y + 0.5) + across * side * (T / 2.0 + 0.012)
		_arch_band(m, "azulejo", azulejo_material(), c, along, across * side, 0.0, 0.42)
		_arch_band(m, "mission_wood", wood, c + across * side * 0.006, along, across * side, 0.42, 0.52)


## The round head of a balcony's open doorway, on the room side: the wall filling the corners over the arch, and a
## dark carved band round it.
func _mission_balcony_arch(x: int, y: int, horiz: bool, into: Vector3, z: String) -> void:
	var m := _row(y)
	var along := Vector3.RIGHT if horiz else Vector3.BACK
	var r := 0.46
	var c := Vector3(x + 0.5, Elev.surface(map, Vector2i(x, y)) + BALCONY_H - r, y + 0.5) + into * (T / 2.0 + 0.04)
	var wall := wall_mat(z)
	for i in 12:
		var a0 := PI * float(i) / 12.0
		var a1 := PI * float(i + 1) / 12.0
		var p0 := c + (along * cos(a0) + Vector3.UP * sin(a0)) * r
		var p1 := c + (along * cos(a1) + Vector3.UP * sin(a1)) * r
		m.quad("arch_fill_" + z, wall, [p0, p1, Vector3(p1.x, c.y + r, p1.z), Vector3(p0.x, c.y + r, p0.z)], into, along, Vector3.UP)
	_arch_band(m, "mission_wood", surface("mission_wood", MISSION_WOOD), c + into * 0.006, along, into, r - 0.02, r + 0.06)


## A Spanish mission's walls: a dado of glazed azulejo tiles round the room under a dark wooden rail, a carved crown
## along the top, and wrought-iron candle sconces along the side walls.
func _mission_decor() -> void:
	var tiles := azulejo_material()
	var wood := surface("mission_wood", MISSION_WOOD)
	var iron := surface("iron", MISSION_IRON)
	var balconies: Dictionary = map.get("balcony_doors", {})
	for y in h - 1:
		var m := _row(y)
		for x in w:
			if not code(x, y) in [MapGen.IWALL, MapGen.IWINDOW]:
				continue
			# Full-height glazing has only its own frames; room dado and cornice stop at its edges.
			if code(x, y) == MapGen.IWINDOW and map.get("room", {}).get("full_height_windows", false):
				continue
			# (a wall standing on a raised floor, like the hotel lobby's balcony wall, would put the dado and crown,
			# measured from the ground floor, across its foot and its doorways' thresholds)
			if Elev.surface(map, Vector2i(x, y)) > DADO_TOP:
				continue
			# over a balcony's open doorway only the crown carries on
			var open := balconies.has(Vector2i(x, y))
			for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
				if zone(x + d.x, y + d.y) == "":
					continue
				var nrm := Vector3(d.x, 0, d.y)
				var along := Vector3(absi(d.y), 0, absi(d.x))
				var lo := -0.5
				var hi := 0.5
				# carried on round an inside corner to the wall it meets
				for end in [-1, 1]:
					var q: Vector2i = Vector2i(x, y) + Vector2i(int(along.x), int(along.z)) * end
					if code(q.x, q.y) == MapGen.IWALL and zone(q.x + d.x, q.y + d.y) == "":
						if end < 0:
							lo -= 0.5 - T / 2.0 - 0.012
						else:
							hi += 0.5 - T / 2.0 - 0.012
				var base := Vector3(x + 0.5, 0, y + 0.5) + nrm * (T / 2.0 + 0.012)
				var a := base + along * lo
				var b := base + along * hi
				var mid := base + along * (lo + hi) / 2.0
				if not open:
					m.quad("azulejo", tiles, [a + Vector3.UP * 0.1, b + Vector3.UP * 0.1, b + Vector3.UP * DADO_TOP, a + Vector3.UP * DADO_TOP], nrm, along, Vector3.UP)
					_along_box(m, "mission_wood", wood, mid + Vector3.UP * DADO_TOP, along, hi - lo, 0.06, 0.05)
				_along_box(m, "mission_wood", wood, mid + Vector3.UP * (H - 0.07), along, hi - lo, 0.12, 0.07)
				_along_box(m, "mission_wood", wood, mid + Vector3.UP * (H - 0.2), along, hi - lo, 0.03, 0.04)
				# a sconce on every third tile of a side wall
				if d.x != 0 and code(x, y) == MapGen.IWALL and y % 3 == 1:
					var s := base + Vector3.UP * 1.75
					_along_box(m, "iron", iron, s, along, 0.1, 0.26, 0.03)
					m.box("iron", iron, s + nrm * 0.1 + Vector3.UP * 0.02, Vector3(0.12, 0.03, 0.12))
					m.box("iron", iron, s + nrm * 0.06 - Vector3.UP * 0.06, Vector3.ONE * 0.04)
					m.box("mission_flame", flame_material(), s + nrm * 0.1 + Vector3.UP * 0.1, Vector3(0.05, 0.13, 0.05))


const ADOBE_EARTH := Color("#c99a6c")
const ADOBE_WOOD := Color("#5e3c24")


## An adobe house's finish: a band of darker earth plaster along the foot of the walls under a slim wooden rail. (The
## vigas' log ends show only outside, adobe_town.gd.)
func _adobe_decor() -> void:
	var earth := (load("res://scripts/gfx/house_builder.gd")).wall_material("adobe", ADOBE_EARTH) as Material
	var wood := surface("mission_wood", ADOBE_WOOD)
	for y in h - 1:
		var m := _row(y)
		for x in w:
			if not code(x, y) in [MapGen.IWALL, MapGen.IWINDOW]:
				continue
			for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
				if zone(x + d.x, y + d.y) == "":
					continue
				var nrm := Vector3(d.x, 0, d.y)
				var along := Vector3(absi(d.y), 0, absi(d.x))
				var base := Vector3(x + 0.5, 0, y + 0.5) + nrm * (T / 2.0 + 0.012)
				var a := base - along * 0.5
				var b := base + along * 0.5
				if code(x, y) == MapGen.IWALL:
					m.quad("adobe_earth", earth, [a + Vector3.UP * 0.1, b + Vector3.UP * 0.1, b + Vector3.UP * 0.62, a + Vector3.UP * 0.62], nrm, along, Vector3.UP)
					_along_box(m, "mission_wood", wood, base + Vector3.UP * 0.64, along, 1.0, 0.05, 0.04)


## A mission lobby's reception desk in place of a shop's counters: panelled dark wood under a marble top, the
## counter's red phone, a brass bell and the guest book, and a board of room keys on the wall behind the clerk.
func _reception_desk() -> void:
	var wood := surface("mission_wood", MISSION_WOOD)
	var panel := surface("mission_panel", MISSION_WOOD.lightened(0.12))
	var marble := surface("marble_top", Color("#efe8dc"))
	var brass := surface("brass", Color("#d8b050"))
	var phone_at: Vector2i = map.get("counter_phone", Vector2i(-1, -1))
	var tiles := []
	for y in h:
		for x in w:
			if code(x, y) == MapGen.COUNTER:
				tiles.append(Vector2i(x, y))
	if tiles.is_empty():
		return
	var bell_done := false
	for q in tiles:
		var m := _row(q.y)
		var c := Vector3(q.x + 0.5, 0, q.y + 0.5)
		var face := Vector2i(0, 1)
		for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
			if MapGen.walkable(code(q.x + d.x, q.y + d.y)):
				face = d
				break
		# A straight reception run keeps every piece aligned, even beside a staff gate.
		var fixed_face: Array = map.get("room", {}).get("counter_facing", [])
		if fixed_face.size() == 2:
			face = Vector2i(int(fixed_face[0]), int(fixed_face[1]))
		var out := Vector3(face.x, 0, face.y)
		var along := Vector3(absi(face.y), 0, absi(face.x))
		_along_box(m, "mission_wood", wood, c + Vector3.UP * (DESK_TOP - 0.03) / 2.0, along, 1.0, DESK_TOP - 0.03, 0.8)
		_along_box(m, "mission_panel", panel, c + out * 0.41 + Vector3.UP * 0.5, along, 0.7, 0.55, 0.02)
		_along_box(m, "mission_wood", wood, c + out * 0.42 + Vector3.UP * 0.06, along, 1.0, 0.12, 0.04)
		_along_box(m, "marble_top", marble, c + Vector3.UP * (DESK_TOP - 0.025), along, 1.0, 0.05, 0.9)
		if q == phone_at:
			_counter_phone(c, atan2(float(face.x), float(face.y)), DESK_TOP)
		elif not bell_done and q.x >= w / 2 - 2:
			bell_done = true
			var bell := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.07
			sm.height = 0.07
			sm.is_hemisphere = true
			bell.mesh = sm
			bell.material_override = brass
			bell.position = c + out * 0.15 + Vector3.UP * DESK_TOP
			parent.add_child(bell)
			# the guest book, open
			for s in [-1.0, 1.0]:
				_along_box(m, "page", surface("page", Color("#f6f0e0")), c + along * (0.35 + s * 0.09) + Vector3.UP * (DESK_TOP + 0.015), along, 0.17, 0.02, 0.24)
	# the key board behind the clerk, on the back wall
	var board := Vector3(3.5, 1.55, 0.5 + T / 2.0 + 0.03)
	_row(0).box("mission_wood", wood, board, Vector3(1.4, 0.7, 0.05))
	for i in 5:
		for j in 2:
			_row(0).box("brass", brass, board + Vector3(-0.5 + 0.25 * i, 0.15 - 0.3 * j, 0.04), Vector3(0.05, 0.1, 0.02))


## An ancient room's counters (the Beast Center's temple): blocks of its dressed stone on a darker plinth, under a
## pale capstone with a thin glowing inlay of the temple's colour along the front, and the counter's red phone.
func _stone_counters() -> void:
	var body := surface("pilaster", stone.lightened(0.04))
	var foot := surface("plinth", stone.darkened(0.22))
	var cap := surface("cornice", stone.lightened(0.1))
	var inlay := surface("inlay", _inlay_colour())
	inlay.emission_enabled = true
	inlay.emission = _inlay_colour()
	inlay.emission_energy_multiplier = 0.8
	var phone_at: Vector2i = map.get("counter_phone", Vector2i(-1, -1))
	for y in h:
		for x in w:
			if code(x, y) != MapGen.COUNTER:
				continue
			var m := _row(y)
			var c := Vector3(x + 0.5, 0, y + 0.5)
			var face := Vector2i(0, 1)
			for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
				if MapGen.walkable(code(x + d.x, y + d.y)):
					face = d
					break
			var out := Vector3(face.x, 0, face.y)
			var along := Vector3(absi(face.y), 0, absi(face.x))
			_along_box(m, "plinth", foot, c + out * 0.02 + Vector3.UP * 0.08, along, 1.0, 0.16, 0.86)
			_along_box(m, "pilaster", body, c + Vector3.UP * 0.5, along, 1.0, 0.7, 0.78)
			_along_box(m, "cornice", cap, c + Vector3.UP * (DESK_TOP - 0.04), along, 1.0, 0.08, 0.9)
			_along_box(m, "inlay", inlay, c + out * 0.395 + Vector3.UP * 0.66, along, 1.0, 0.04, 0.01)
			if Vector2i(x, y) == phone_at:
				_counter_phone(c, atan2(float(face.x), float(face.y)), DESK_TOP)


# ---------------------------------------------------------------- stairs
## A house's stairs (a stage room's; a dungeon's are world.gd's stone steps): a flight up (>) or a stairwell down (<)
## along a row of three tiles, four steps to a tile, flush with the walls beside it. A flight up climbs to the top of
## the wall, towards the end that meets one: its treads and risers in the room's floor, its side in the room's wall
## finish, a handrail up its open side. A stairwell down is a hole in the floor (see _floors) with the flight going
## down in it from the top step, where you go in, and a rail along its open side and round its far end.
static func has_flights(m: Dictionary) -> bool:
	return m.get("stage", false) or m.get("stair_flights", false)


func _stairs() -> void:
	if not has_flights(map):
		return
	for y in h:
		for x in w:
			if code(x, y) == MapGen.STAIRS_UP:
				_flight(x, y)
			elif code(x, y) == MapGen.STAIRS_DOWN:
				_well(x, y)


## The flight that tile (x, y) is part of: [this tile's place along it counted from its foot, how many tiles long it
## is, the way it climbs (a unit step), the way across it] (see flight).
func _stair_run(x: int, y: int) -> Array:
	var f := flight(map, Vector2i(x, y))
	var up: Vector2i = f["up"]
	var foot: Vector2i = f["foot"]
	var place := (x - foot.x) * up.x + (y - foot.y) * up.y
	return [place, f["n"], Vector3(up.x, 0, up.y), Vector3(absi(up.y), 0, absi(up.x))]


## The flight of stairs (or the stairwell) in map `m` that tile `t` is part of: {"foot" and "top" (its end tiles),
## "up" (the way it climbs, a unit step), "n" (how many tiles long it is)}. It climbs towards the end that meets a wall
## (with none, the end further along the row or column).
static func flight(m: Dictionary, t: Vector2i) -> Dictionary:
	var c := MapGen.get_t(m, t.x, t.y)
	var along := Vector2i(1, 0) if MapGen.get_t(m, t.x - 1, t.y) == c or MapGen.get_t(m, t.x + 1, t.y) == c else Vector2i(0, 1)
	var a := t
	while MapGen.get_t(m, a.x - along.x, a.y - along.y) == c:
		a -= along
	var n := 1
	while MapGen.get_t(m, a.x + along.x * n, a.y + along.y * n) == c:
		n += 1
	var b: Vector2i = a + along * (n - 1)
	if not _walled(m, b + along) and _walled(m, a - along):
		return {"foot": b, "top": a, "up": -along, "n": n}
	return {"foot": a, "top": b, "up": along, "n": n}


## Where a stage room's stairs can be stepped onto from: {each stair tile: the tiles beside it you can step onto it
## from}, none for most of them. A flight up only from the tile before its foot (its handrail runs the whole of its open
## side, a wall the other); a stairwell down only from beside its top step on its open side (the rail runs round the
## rest), or past its top end if no wall is there. (See world.gd _can_step.)
static func stair_ways_in(m: Dictionary) -> Dictionary:
	var ways := {}
	if not has_flights(m):
		return ways
	for y in m["h"]:
		for x in m["w"]:
			var c := MapGen.get_t(m, x, y)
			if c != MapGen.STAIRS_UP and c != MapGen.STAIRS_DOWN:
				continue
			var t := Vector2i(x, y)
			var f := flight(m, t)
			var up: Vector2i = f["up"]
			var across := Vector2i(absi(up.y), absi(up.x))
			# the open side, towards the room: away from the wall it runs along (as the rail is, see _flight and _well)
			var open := across if _walled(m, t - across) else -across
			var from := []
			if c == MapGen.STAIRS_UP and t == f["foot"]:
				from.append(t - up if not _walled(m, t - up) else t + open)
			elif c == MapGen.STAIRS_DOWN and t == f["top"]:
				from.append(t + open)
				if not _walled(m, t + up):
					from.append(t + up)
			ways[t] = from
	return ways


## Whether tile `t` of map `m` is a wall (or a doorway or a window in one: WALLISH).
static func _walled(m: Dictionary, t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < m["w"] and t.y < m["h"] and MapGen.get_t(m, t.x, t.y) in WALLISH


## How a tile of a flight meets the walls round it: [where it starts and ends across the flight (from the tile's
## middle, along its `side`), how far its top end reaches on past the tile]. Against a wall it runs right up to the
## wall's face.
func _stair_fit(x: int, y: int, run: Array) -> Array:
	var rise: Vector3 = run[2]
	var side: Vector3 = run[3]
	var reach := 0.5 - T / 2.0
	var sd := Vector2i(int(side.x), int(side.z))
	var u := Vector2i(int(rise.x), int(rise.z))
	var a0 := -0.5 - (reach if wallish(x - sd.x, y - sd.y) else 0.0)
	var a1 := 0.5 + (reach if wallish(x + sd.x, y + sd.y) else 0.0)
	var top := reach if int(run[0]) == int(run[1]) - 1 and wallish(x + u.x, y + u.y) else 0.0
	return [a0, a1, top]


func _flight(x: int, y: int) -> void:
	var run := _stair_run(x, y)
	var place: int = run[0]
	var n: int = run[1]
	var rise: Vector3 = run[2]
	var side: Vector3 = run[3]
	var fit := _stair_fit(x, y, run)
	var a0: float = fit[0]
	var a1: float = fit[1]
	var mid := side * (a0 + a1) / 2.0
	var wide := side * (a1 - a0)
	var z := zone(x, y)
	var tread := floor_mat(z)
	var body := wall_mat(z)
	var c := Vector3(x + 0.5, 0, y + 0.5)
	var step_h := H / float(n * 4)
	for j in 4:
		var sy := (place * 4 + j + 1) * step_h
		# the top step runs on to the wall it climbs into
		var deep := 0.25 + (float(fit[2]) if j == 3 else 0.0)
		var at := c + mid + rise * (-0.5 + deep / 2.0 + j * 0.25)
		floor_mesher.box("stair_" + z, body, at + Vector3(0, (sy - 0.03) / 2.0, 0), wide + rise.abs() * deep + Vector3(0, sy - 0.03, 0))
		floor_mesher.box("floor_" + z, tread, at + Vector3(0, sy - 0.015, 0), wide + rise.abs() * (deep + 0.02) + Vector3(0, 0.03, 0))
		floor_mesher.box("floor_" + z, tread, c + mid + rise * (-0.5 + j * 0.25 - 0.005) + Vector3(0, sy - step_h / 2.0, 0),
			wide + rise.abs() * 0.01 + Vector3(0, step_h, 0))
	if place != 0:
		return
	# the handrail up the open side, from a newel post at the foot until it meets the top of the wall
	var open := (a1 - 0.05) if a0 < -0.5 else (a0 + 0.05)
	var wood := surface("frame", trim)
	var foot := c + side * open - rise * 0.45
	var slope := H / float(n)
	var last := (H - 0.95) / slope
	floor_mesher.box("frame", wood, foot + Vector3(0, 0.55, 0), Vector3(0.1, 1.1, 0.1))
	_beam("frame", wood, foot + Vector3(0, 1.05, 0), foot + rise * last + Vector3(0, last * slope + 0.95, 0), 0.035)
	var t := 0.25
	while t < last:
		var floor_y: float = (floorf(t / 0.25) + 1.0) * step_h
		floor_mesher.box("frame", wood, foot + rise * t + Vector3(0, (floor_y + t * slope + 0.95) / 2.0, 0),
			Vector3(0.04, t * slope + 0.95 - floor_y, 0.04))
		t += 0.25


func _well(x: int, y: int) -> void:
	var run := _stair_run(x, y)
	var place: int = run[0]
	var n: int = run[1]
	var rise: Vector3 = run[2]
	var side: Vector3 = run[3]
	var fit := _stair_fit(x, y, run)
	var a0: float = fit[0]
	var a1: float = fit[1]
	var mid := side * (a0 + a1) / 2.0
	var wide := side * (a1 - a0)
	var top: float = fit[2]
	var z := zone(x, y)
	var tread := floor_mat(z)
	var c := Vector3(x + 0.5, 0, y + 0.5)
	# as deep as the floor in front hides it (a shallow room, like a landing, would show the rest under its front edge)
	var bottom := -minf(H + 0.2, EDGE + (h - 1.5 - y) * VIEW_SLOPE)
	for j in 4:
		# counted from the top step down; darker the deeper
		var s := (n - 1 - place) * 4 + (3 - j)
		var ty := -(s + 1) * H / float(n * 4)
		if ty <= bottom:
			continue
		var shade := clampf(1.0 - float(s) / float(n * 4) * 1.3, 0.12, 1.0)
		var deep := 0.25 + (top if j == 3 else 0.0)
		var at := c + mid + rise * (-0.5 + deep / 2.0 + j * 0.25)
		floor_mesher.box("floor_" + z, tread, at + Vector3(0, (ty + bottom) / 2.0, 0), wide + rise.abs() * deep + Vector3(0, ty - bottom, 0), shade)
	# the wall it runs along, carried on down, and its far end (vertex shades are linear: 0.2 shows at about half)
	var back := a0 if a0 < -0.5 else a1
	floor_mesher.box("stair_" + z, wall_mat(z), c + side * back + rise * (top / 2.0) + Vector3(0, bottom / 2.0, 0),
		rise.abs() * (1.0 + top) + side * 0.04 + Vector3(0, -bottom, 0), 0.2)
	if place == 0:
		floor_mesher.box("stair_" + z, wall_mat(z), c + mid - rise * 0.5 + Vector3(0, bottom / 2.0, 0),
			wide + rise.abs() * 0.04 + Vector3(0, -bottom, 0), 0.16)
	if place == n - 1:
		# the riser from the landing (or the wall) down to the top step
		var step := H / float(n * 4)
		floor_mesher.box("floor_" + z if top == 0.0 else "stair_" + z, tread if top == 0.0 else wall_mat(z),
			c + mid + rise * (0.5 + top - 0.01) + Vector3(0, -step / 2.0, 0), wide + rise.abs() * 0.02 + Vector3(0, step, 0))
	# the rail: along the side towards the room, open at the top step, and round the far end, with a baluster every
	# eighth of a tile so it shows against the floor
	var wood := surface("frame", trim)
	var open := (a1 - 0.03) if a0 < -0.5 else (a0 + 0.03)
	if place == n - 1:
		floor_mesher.box("frame", wood, c + side * open - rise * 0.47 + Vector3(0, 0.5, 0), Vector3(0.08, 1.0, 0.08))
		return
	floor_mesher.box("frame", wood, c + side * open + Vector3(0, 0.85, 0), rise.abs() + side * 0.06 + Vector3(0, 0.06, 0))
	floor_mesher.box("frame", wood, c + side * open - rise * 0.45 + Vector3(0, 0.42, 0), Vector3(0.07, 0.85, 0.07))
	for k in range(1, 8):
		floor_mesher.box("frame", wood, c + side * open + rise * (-0.45 + k * 0.125) + Vector3(0, 0.41, 0), Vector3(0.04, 0.82, 0.04))
	if place == 0:
		var far := c - rise * 0.47
		var other := a0 + a1 - open
		floor_mesher.box("frame", wood, far + mid + Vector3(0, 0.85, 0), wide + rise.abs() * 0.06 + Vector3(0, 0.06, 0))
		floor_mesher.box("frame", wood, far + side * other + Vector3(0, 0.42, 0), Vector3(0.07, 0.85, 0.07))
		var gaps := maxi(roundi(absf(other - open) / 0.125), 1)
		for k in range(1, gaps):
			floor_mesher.box("frame", wood, far + side * lerpf(open, other, float(k) / gaps) + Vector3(0, 0.41, 0), Vector3(0.04, 0.82, 0.04))


## A bar at any slope. The optional bevelled form softens handrails and stout posts and caps both ends.
func _beam(key: String, mat: Material, a: Vector3, b: Vector3, r: float, bevelled := false, squash := 1.0) -> void:
	var dir := (b - a).normalized()
	var across := dir.cross(Vector3.UP)
	if across.length_squared() < 0.001:
		across = dir.cross(Vector3.RIGHT)
	var u := across.normalized() * r
	var v := u.cross(dir).normalized() * r * squash
	if bevelled:
		var corners := [u * 0.65 + v, u + v * 0.65, u - v * 0.65, u * 0.65 - v,
			-u * 0.65 - v, -u - v * 0.65, -u + v * 0.65, -u * 0.65 + v]
		for i in corners.size():
			var p: Vector3 = corners[i]
			var q: Vector3 = corners[(i + 1) % corners.size()]
			floor_mesher.quad(key, mat, [a + p, b + p, b + q, a + q], (p + q).normalized(), dir, (q - p).normalized())
			floor_mesher.tri(key, mat, [a, a + p, a + q], -dir, u.normalized(), v.normalized())
			floor_mesher.tri(key, mat, [b, b + p, b + q], dir, u.normalized(), v.normalized())
		return
	for f in [[u, v], [v, -u], [-u, -v], [-v, u]]:
		var p: Vector3 = f[0]
		var q: Vector3 = f[1]
		floor_mesher.quad(key, mat, [a + p - q, b + p - q, b + p + q, a + p + q], p.normalized(), dir, q.normalized())


# ---------------------------------------------------------------- furniture
static func furniture_groups(m: Dictionary) -> Array:
	var out := []
	var furn: Dictionary = m.get("furniture", {})
	var seen := {}
	for p in furn:
		if seen.has(p):
			continue
		var kind: String = furn[p]
		# the tiles of one piece: the same kind, side by side
		var group := []
		var stack := [p]
		seen[p] = true
		while not stack.is_empty():
			var q: Vector2i = stack.pop_back()
			group.append(q)
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var r: Vector2i = q + d
				if not seen.has(r) and furn.get(r, "") == kind:
					seen[r] = true
					stack.append(r)
		if (KINDS[kind].get("fill", false) or KINDS[kind].get("single", false) or (KINDS[kind].has("home_m") and is_home(m))) 				and group.size() > 1:
			# a run of counters is a cabinet per tile; chairs, plants and lamps side by side are one each
			for q in group:
				out.append({"kind": kind, "tiles": [q]})
		else:
			out.append({"kind": kind, "tiles": group})

	return out


func _furniture() -> void:
	for part in furniture_groups(map):
		if part["kind"] != "rug":
			_place(part["kind"], part["tiles"])


## Old r tiles locate an area rug; they no longer stretch a narrow carpet mesh along their bounding box.
## Fit one of the agreed tile sizes nearby, clear of walls, stairwells, hazards and other rugs.
static func rug_rectangles(m: Dictionary) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	for part in furniture_groups(m):
		if part["kind"] != "rug":
			continue
		var layout := furniture_layout(m, "rug", part["tiles"])
		var old_size: Vector2 = layout["size"]
		var old_center := Vector2(layout["lo"]) + old_size * 0.5
		var best := Rect2i()
		var best_score := INF
		for preset in RUG_SIZES:
			for size in [preset, Vector2i(preset.y, preset.x)]:
				for y in range(1, int(m["h"]) - int(size.y)):
					for x in range(1, int(m["w"]) - int(size.x)):
						var rect := Rect2i(Vector2i(x, y), size)
						var distance := (Vector2(rect.position) + Vector2(size) * 0.5).distance_squared_to(old_center)
						var shape := (Vector2(size) - old_size).length_squared()
						var target_area := maxi(12, (part["tiles"] as Array).size())
						var score := distance * 1.5 + shape * 0.2 + absf(size.x * size.y - target_area) * 0.8
						if score >= best_score or out.any(func(other): return other.intersects(rect)):
							continue
						var clear := true
						for ry in range(y, y + int(size.y)):
							for rx in range(x, x + int(size.x)):
								if MapGen.get_t(m, rx, ry) in RUG_BLOCKED:
									clear = false
						if clear:
							best = rect
							best_score = score
		if best.has_area():
			out.append(best)
	return out


## A room's runners ("runners": [[x, y, w, h], ...] in its template): long narrow rugs laid exactly where authored,
## such as the hotel lobby's from the front door to the hallway (the user's 2026-11-15 direction). Unlike area rugs
## they keep their own footprint; check_maps still keeps them clear of walls, stairs and hazards.
static func runner_rects(m: Dictionary) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	for r in m.get("room", {}).get("runners", []):
		out.append(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
	return out


## A soft, untextured colour (a placemat), shared by everything of that colour.
static func plain_material(colour: Color) -> StandardMaterial3D:
	var key := "plain:%s" % colour.to_html()
	if not _mats.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colour
		mat.roughness = 1.0
		_mats[key] = mat
	return _mats[key]


## Area rugs are the KayKit rugs (plain, striped or oval, the room's pick), stretched over their tiles a little in from
## the edges, in the room's rug colour (softened).
func _rugs() -> void:
	var colour := Color(str(map.get("room", {}).get("rug", "#a04040")))
	var names: Array = KINDS["rug"]["m"]
	var runners := runner_rects(map)
	for rect in rug_rectangles(map) + runners:
		# a runner is the plain rug, so its border isn't stretched into stripes or an oval along its length
		var pick: String = "kk_rug_rect" if rect in runners else names[absi(hash(str(map.get("room_key", "")) + str(rect.position))) % names.size()]
		var mesh := piece(pick)
		if mesh == null:
			continue
		var rug := MeshInstance3D.new()
		rug.name = "AreaRug"
		rug.mesh = mesh
		var bb := mesh.get_aabb()
		var lo := Vector2(rect.position) + Vector2(0.06, 0.06)
		var hi := Vector2(rect.end) - Vector2(0.06, 0.06)
		if rect in runners:
			# a runner's ends run on to the wall (or doorway) it meets, so it reaches from door to door
			var reach := 0.5 - T / 2.0
			if rect.size.x >= rect.size.y:
				lo.x -= reach if MapGen.get_t(map, rect.position.x - 1, rect.position.y) in RUG_BLOCKED else 0.0
				hi.x += reach if MapGen.get_t(map, rect.end.x, rect.position.y) in RUG_BLOCKED else 0.0
			else:
				lo.y -= reach if MapGen.get_t(map, rect.position.x, rect.position.y - 1) in RUG_BLOCKED else 0.0
				hi.y += reach if MapGen.get_t(map, rect.position.x, rect.end.y) in RUG_BLOCKED else 0.0
		var sz := hi - lo
		rug.scale = Vector3(sz.x / bb.size.x, 1.0, sz.y / bb.size.z)
		# softened toward undyed wool, as the rugs were before, so they stay muted
		tint_fabric(rug, colour.lerp(Color("#dfc9ac"), 0.3))
		rug.position = Vector3((lo.x + hi.x) * 0.5, 0.004, (lo.y + hi.y) * 0.5)
		rug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(rug)


## The placement used by both rendering and the map audit, without loading any meshes.
static func furniture_layout(m: Dictionary, kind: String, group: Array) -> Dictionary:
	var k: Dictionary = KINDS.get(kind, {})
	var lo := Vector2i(group[0])
	var hi := Vector2i(group[0])
	for q in group:
		lo = Vector2i(mini(lo.x, q.x), mini(lo.y, q.y))
		hi = Vector2i(maxi(hi.x, q.x), maxi(hi.y, q.y))
	var size := Vector2(hi.x - lo.x + 1, hi.y - lo.y + 1)
	# the wall it backs onto: the side with the most wall along it
	var back := Vector2i.ZERO
	if not k.get("free", false):
		var best := 0
		for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
			var n := 0
			for q in group:
				var r: Vector2i = q + d
				if (_walled(m, r) or r.x < 0 or r.y < 0 or r.x >= int(m["w"]) or r.y >= int(m["h"])) and not group.has(r):
					n += 1
			# beds go head first against the wall, long things side on
			var along_len := size.x if d.y != 0 else size.y
			var across_len := size.y if d.y != 0 else size.x
			if k.get("short", false) and along_len > across_len:
				n -= 100
			if k.get("long", false) and along_len < across_len:
				n -= 100
			if n > best:
				best = n
				back = d
	# backed against a wall: pushed right up to it
	var against := back != Vector2i.ZERO
	if kind in ["sofa", "armchair"] and back.x == 0:
		# Side-wall seats retain their inward facing; loose seats face the implied fourth-wall TV.
		back = Vector2i(0, -1)
		against = group.any(func(q): return _walled(m, q + back))

	var table_facing := false
	var lounge_table := Vector2i(-1, -1)
	if kind in ["sofa", "armchair"]:
		# Lounge seats face a nearby aligned coffee table, including across a one-tile aisle.
		var found_table := false
		for distance in [1, 2]:
			for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				for q in group:
					var target: Vector2i = q + d * distance
					if m.get("furniture", {}).get(target, "") != "coffee_table":
						continue
					if distance == 2 and MapGen.get_t(m, q.x + d.x, q.y + d.y) in RUG_BLOCKED:
						continue
					back = -d
					against = false
					found_table = true
					table_facing = true
					lounge_table = target
					break
				if found_table:
					break
			if found_table:
				break

	if k.get("chair", false):
		# a chair faces the table beside it (its back away from it)
		for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var r: Vector2i = lo + d
			if m.get("furniture", {}).get(r, "") in ["table", "desk", "coffee_table", "diner_table"]:
				back = -d
				against = false
				break
	# the model turned so its back (-z) faces `back`
	var yaw := 0.0
	if back != Vector2i.ZERO:
		yaw = atan2(float(-back.x), float(-back.y))
	elif k.get("free", false) and size.y > size.x:
		yaw = PI / 2.0
	yaw = float(m.get("room", {}).get("furniture_yaws", {}).get(lo, yaw))
	return {"lo": lo, "size": size, "back": back, "against": against, "yaw": yaw, "table_facing": table_facing,
		"lounge_table": lounge_table}


## Fixed-size hearth, its rear plane on the room-side face of the wall. Never stretch it.
func _fireplace(group: Array) -> void:
	var layout := furniture_layout(map, "fireplace", group)
	var lo: Vector2i = layout["lo"]
	var size: Vector2 = layout["size"]
	var back: Vector2i = layout["back"]
	if not layout["against"]:
		push_warning("Fireplace needs a solid wall: %s %s" % [map.get("room_key", ""), lo])
		return
	var room: Dictionary = map.get("room", {})
	var kit = load("res://scripts/gfx/fireplaces.gd")
	var style: String = room.get("fireplace_style", "fieldstone")
	var stone_colour := Color(str(room.get("fireplace_stone", kit.STONE.get(style, "#b9b1a0"))))
	var wood := Color(str(room.get("wood", KAYKIT_WOOD.to_html())))
	var mi: MeshInstance3D = kit.make(style, stone_colour, wood)
	mi.position = Vector3(lo.x + size.x / 2.0, dais_at(map, lo), lo.y + size.y / 2.0)
	var depth := size.y if back.y != 0 else size.x
	mi.position += Vector3(back.x, 0, back.y) * (depth / 2.0 + 0.5 - T / 2.0)
	mi.rotation.y = layout["yaw"]
	parent.add_child(mi)
	var glow := TempleLights.flame(Vector3(0, 0.26, 0.27), 0.13)
	glow.name = "HearthGlow"
	glow.add_to_group("untextured_fx")
	mi.add_child(glow)
	mi.add_child(TempleLights.light(Vector3(0, 0.5, 0.32), 0.65, 3.0))
	mi.set_meta("fireplace_tiles", group)


func _place(kind: String, group: Array) -> void:
	if kind == "fireplace":
		_fireplace(group)
		return
	if kind == "counter_gate":
		_counter_gate(group)
		return
	if kind in ["hot_tub", "hot_tub_sign", "ice_maker", "plant_table", "luggage"]:
		return # Built by _hotel_details.
	var k: Dictionary = KINDS.get(kind, {})
	var layout := furniture_layout(map, kind, group)
	var lo: Vector2i = layout["lo"]
	var size: Vector2 = layout["size"]
	var back: Vector2i = layout["back"]
	var against: bool = layout["against"]
	var yaw: float = layout["yaw"]
	var center := Vector3(lo.x + size.x / 2.0, 0, lo.y + size.y / 2.0)
	var along := absf(sin(yaw)) < 0.5
	var span := size.x if along else size.y
	var depth := size.y if along else size.x
	# room up to the wall's face beyond the tiles
	var reach := 0.5 - T / 2.0 if against else 0.0
	# in a home, anything the player can walk behind stays below their waist (and nothing fades)
	var front := home and behind_open(map, lo, size)
	var names: Array = k.get("home_m", k["m"]) if home else k["m"]
	if front:
		var low := names.filter(func(n): return piece(n) != null and piece(n).get_aabb().size.y <= WAIST)
		if not low.is_empty():
			names = low
	# (the user's rule, 2026-11-15) never two exactly alike side by side, chairs excepted: a model a neighbouring
	# piece already has gives way to another choice or an alternative ("alt"); a run of counters (fill) is one piece
	var near := _near_placed(group, "chair" in k or "fill" in k or kind == "armchair", _placed)
	var used_alt := false
	if not near.is_empty():
		var fresh := names.filter(func(n): return not n in near)
		if fresh.is_empty():
			fresh = k.get("alt", []).filter(func(n): return not n in near and piece(n) != null 				and (not front or piece(n).get_aabb().size.y <= WAIST))
			used_alt = not fresh.is_empty()
		if not fresh.is_empty():
			names = fresh
		elif home:
			push_warning("%s: two alike %s pieces side by side at %s" % [map.get("room_key", ""), kind, lo])
	var mesh := _choose(names, span, depth + reach, k.get("same", false))
	if mesh == null:
		return
	for n in names:
		if piece(n) == mesh:
			for q in group:
				_placed[q] = n
			break
	var bb := mesh.get_aabb()
	var sc := Vector3.ONE
	if k.get("rug", false):
		sc = Vector3(span * 0.92 / bb.size.x, 1.0, depth * 0.92 / bb.size.z)
	elif k.get("fit", false):
		sc = Vector3(span * 0.94 / bb.size.x, 1.0, minf(1.0, (depth + reach) * 0.94 / bb.size.z))
	elif k.get("fill", false):
		sc = Vector3(span * 0.98 / bb.size.x, 1.0, minf(1.0, (depth + reach) * 0.95 / bb.size.z))
	else:
		var s := minf(1.0, minf(span * 0.96 / bb.size.x, (depth + reach) * 0.96 / bb.size.z))
		sc = Vector3(s, s, s)
	# Authored tall planters keep their proportions within their blocked floor footprint.
	if k.has("height"):
		var s := minf(float(k["height"]) / bb.size.y, minf(span * 0.96 / bb.size.x, depth * 0.96 / bb.size.z))
		sc = Vector3.ONE * s
	if front and bb.size.y * sc.y > WAIST and bb.size.y * sc.y <= WAIST * WAIST_GIVE:
		# (an armchair's back a hand above the waist settles to it)
		sc.y *= WAIST / (bb.size.y * sc.y)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.scale = sc
	mi.rotation.y = yaw
	_decor_mats(mi)
	# the pack's cloth: a building's chairs and stools match; each bed has its own blanket
	var cloth_at := posmod(pick_seed, CLOTH.size()) if k.get("same", false) 		else absi(hash(str(map.get("building", {}).get("seed", 0)) + str(lo))) % CLOTH.size()
	tint_fabric(mi, Color(CLOTH[cloth_at]))
	if k.has("tint"):
		var tm := StandardMaterial3D.new()
		var src := mesh.surface_get_material(0) as BaseMaterial3D
		if src != null:
			tm = src.duplicate()
		tm.albedo_color = Color(k["tint"])
		mi.material_override = tm
	var pos := center
	if against:
		# right up against the wall
		var wall_face := center + Vector3(back.x, 0, back.y) * (depth / 2.0 + reach)
		pos = wall_face - Vector3(back.x, 0, back.y) * (bb.size.z * sc.z / 2.0 + 0.01)
	if k.get("rug", false):
		pos.y = 0.012
	# Authored offsets attach small pieces to non-grid surfaces, such as a stair's
	# enclosing wall, while their tile and interaction approach stay unchanged.
	var offset: Vector2 = map.get("room", {}).get("furniture_offsets", {}).get(lo, Vector2.ZERO)
	pos += Vector3(offset.x, 0, offset.y)
	pos.y += dais_at(map, lo)
	if k.has("height"):
		pos.y -= bb.position.y * sc.y
	mi.position = pos
	parent.add_child(mi)
	if k.has("desk_side") and span >= 1.8:
		# a desk two tiles long: the table at one end, a chest of drawers at the other
		var shift := Basis(Vector3.UP, yaw) * Vector3(-(span / 2.0 - 0.5), 0, 0)
		mi.position += shift
		pos += shift
		var dr := _stand(k["desk_side"], mi.position - shift * 2.0, yaw)
		if dr != null and against:
			# its back to the wall too
			dr.position += Vector3(back.x, 0, back.y) * ((bb.size.z * sc.z - dr.mesh.get_aabb().size.z) / 2.0)
	# the piece and everything on it, to fade together if it's tall
	var pieces: Array = [mi]
	var top_y := bb.size.y * sc.y
	# things standing on it
	var tops: Array = k.get("top", [])
	if used_alt and tops.is_empty():
		# a plain cupboard standing in for a dressed one gets a few things on it
		tops = KINDS["cabinet"]["top"]
	var near_tops := _near_placed(group, false, _placed_tops)
	if tops.size() > 1:
		tops = tops.filter(func(n): return not n in near_tops)
	if not tops.is_empty() and (k.get("always_top", false) or used_alt or rng.randf() < 0.75):
		var n_items := 1 if k.get("always_top", false) else rng.randi_range(1, 1 + int(span * depth))
		for i in n_items:
			var name: String = tops[rng.randi_range(0, tops.size() - 1)] if not k.get("always_top", false) else tops[0]
			if name == "":
				continue
			for q in group:
				_placed_tops[q] = name
			var t := MeshInstance3D.new()
			t.mesh = piece(name)
			if t.mesh == null:
				continue
			if front and top_y + t.mesh.get_aabb().size.y > WAIST:
				# (nothing on a piece at the front rises past the waist either)
				t.free()
				continue
			var spread := Vector3(bb.size.x * sc.x * 0.3, 0, bb.size.z * sc.z * 0.25)
			var off := Vector3(rng.randf_range(-1, 1) * spread.x, 0, rng.randf_range(-1, 1) * spread.z) if not k.get("always_top", false) else Vector3.ZERO
			t.scale = Vector3.ONE * float(k.get("top_scale", 1.0))
			var lift := 0.0
			if k.has("mat"):
				# a thin mat under it, a little bigger than it all round but never past the table's edges
				var foot := t.mesh.get_aabb().size * t.scale
				var mat := MeshInstance3D.new()
				var mb := BoxMesh.new()
				mb.size = Vector3(minf(foot.x + 0.1, bb.size.x * sc.x - 0.08), 0.008, minf(foot.z + 0.08, bb.size.z * sc.z - 0.06))
				mat.mesh = mb
				mat.material_override = plain_material(Color(k["mat"]))
				mat.position = pos + Basis(Vector3.UP, yaw) * off + Vector3(0, top_y + 0.004, 0)
				mat.rotation.y = yaw
				mat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				parent.add_child(mat)
				pieces.append(mat)
				lift = 0.008
			t.position = pos + Basis(Vector3.UP, yaw) * off + Vector3(0, top_y + lift, 0)
			t.rotation.y = yaw + (rng.randf_range(-0.6, 0.6) if not k.get("always_top", false) else 0.0)
			tint_fabric(t, Color(CLOTH[absi(hash(str(pos) + name)) % CLOTH.size()]))
			_decor_mats(t)
			parent.add_child(t)
			if kind == "phone":
				# it shakes when it rings
				t.add_to_group("phones")
			pieces.append(t)
	if k.has("with"):
		var t2 := MeshInstance3D.new()
		t2.mesh = piece(k["with"])
		if t2.mesh != null:
			t2.position = pos + Basis(Vector3.UP, yaw) * Vector3(0.3, 0, -0.1)
			t2.rotation = Vector3(0, yaw, 0.15)
			parent.add_child(t2)
			pieces.append(t2)
	if k.get("goods", false):
		pieces.append_array(_goods(pos, yaw, bb, sc))
	if home:
		pieces.append_array(_dress(kind, mi, bb, sc))
	elif top_y >= TALL and not map.get("room", {}).get("no_fade", false):
		# ("no_fade" rooms, such as the hotel lobby, keep every piece solid: the user's 2026-11-15 direction)
		add_prop(pieces, lo, size)
	if k.get("lamp", false):
		var l := OmniLight3D.new()
		l.light_color = Color("#ffcf8a")
		l.light_energy = 0.6
		l.omni_range = 2.6
		l.position = pos + Vector3(0, top_y - 0.1, 0)
		parent.add_child(l)


## A bathroom with more than one toilet has stalls: a partition either side of each toilet, out from the wall it backs
## onto, and a stall door left a little open. (One toilet: the room is small and has none.)
func _stalls() -> void:
	var furn: Dictionary = map.get("furniture", {})
	var toilets := []
	for q in furn:
		if furn[q] == "toilet":
			toilets.append(q)
	if toilets.size() < 2:
		return
	var panel := StandardMaterial3D.new()
	panel.albedo_color = Color("#c9ccd2")
	panel.roughness = 0.6
	for q: Vector2i in toilets:
		# only alongside other toilets in the same room
		var room := _room_of(q)
		var n := 0
		for o in toilets:
			if room.has(o):
				n += 1
		if n < 2:
			continue
		var back := Vector2i.ZERO
		for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
			if wallish(q.x + d.x, q.y + d.y):
				back = d
				break
		if back == Vector2i.ZERO:
			continue
		var out := Vector3(-back.x, 0, -back.y)
		var side := Vector3(out.z, 0, -out.x)
		var wall := Vector3(q.x + 0.5, 0, q.y + 0.5) - out * (0.5 - T / 2.0)
		var deep := 1.0 - T / 2.0
		var pieces := []
		for s in [-1.0, 1.0]:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.05, 1.7, deep) if out.x == 0 else Vector3(deep, 1.7, 0.05)
			bm.material = panel
			mi.mesh = bm
			mi.position = wall + out * deep / 2.0 + side * s * 0.47 + Vector3(0, 0.95, 0)
			parent.add_child(mi)
			pieces.append(mi)
		# the door, hinged on one partition and swung a little open into the room
		var door := MeshInstance3D.new()
		var db := BoxMesh.new()
		db.size = Vector3(0.84, 1.5, 0.04)
		db.material = panel
		door.mesh = db
		var hinge := wall + out * deep + side * 0.47
		var yaw := atan2(out.x, out.z) + 0.6
		door.rotation.y = yaw
		door.position = hinge + Basis(Vector3.UP, yaw) * Vector3(-0.42, 0, 0) + Vector3(0, 0.95, 0)
		parent.add_child(door)
		pieces.append(door)
		add_prop(pieces, q, Vector2.ONE)


## The tiles of the room `q` is in: everything reachable without crossing a wall or a doorway.
func _room_of(q: Vector2i) -> Dictionary:
	var seen := {q: true}
	var stack := [q]
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var r: Vector2i = p + d
			if seen.has(r) or r.x < 0 or r.y < 0 or r.x >= w or r.y >= h or wallish(r.x, r.y):
				continue
			seen[r] = true
			stack.append(r)
	return seen


## What stands on each shop's counter, besides the till: a few things from its trade.
const COUNTER_GOODS := {
	"apothecary": ["bottle", "bottle_2", "product_1", "product_3", "el_vase", "kk_cactus_small_A"],
	"bookstore": ["books", "books_2", "book", "el_photo", "el_vase"],
	"cafe": ["el_coffee_maker", "el_slush", "cup", "cup_2", "plate", "el_flowers"],
	"electronics": ["phone", "radio", "books_2", "product_2"],
	"music_shop": ["radio", "books", "el_photo"],
	"center": ["cup", "plate_2", "el_flowers"],
	"beast_gear": ["product_2", "product_4", "box_3"],
	"trainer_gear": ["product_2", "book", "box_3"],
}


## Shop counters are store counters: the 6TWELVE shop's dark-wood counter with its glass-fronted displays of sweets,
## facing the customers (the open side, away from the staff), cut into pieces of three to six tiles along each run of
## counter tiles; a run of one or two tiles (the ends of a U round a desk) is a kitchen base unit with a marble top.
## On top: one till by the person working there, its keys and screen turned to them (a cash register; the electronics
## shop's terminal is a computer; the Beast Center's nurse has none: anything there hid her face), and a few things
## from the trade.
const TILL := {"electronics": "el_monitor", "center": ""}
## How high things stand on the counters: the display counter's glass worktop (its model also has a small raised
## block up to 1.0, so its bounding box is no guide), and the single base unit, which is scaled to 1.0 tall.
const DISPLAY_TOP := 0.795
const BASE_UNIT_TOP := 1.0
## Where along the display counter model (x, in its own units) that raised block stands: nothing is set down on it.
const DISPLAY_BLOCK := Vector2(0.41, 1.07)


func _counters() -> void:
	if mission:
		_reception_desk()
		return
	if ancient:
		_stone_counters()
		return
	var shop: String = map.get("building", {}).get("shop", "")
	if shop in ["center", "arena"]:
		_reception_desk()
		return
	var goods: Array = COUNTER_GOODS.get(shop, ["product_1", "books", "cup"])
	var keeper := Vector2i(-99, -99)
	for n in map.get("npcs", []):
		if n.get("kind", "") in ["keeper", "guide", "receptionist"] or n.get("role", "") == "keeper":
			keeper = n["pos"]
			break
	var long_piece := piece("el_display")
	var short_piece := piece("counter")
	if long_piece == null or short_piece == null:
		return
	var till_done := false
	var done := {}
	for y in h:
		for x in w:
			if code(x, y) != MapGen.COUNTER or done.has(Vector2i(x, y)):
				continue
			# the customer side: open floor away from the keeper, preferring the side towards the camera
			var face := Vector2i(0, 1)
			for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if MapGen.walkable(code(q.x, q.y)) and q.distance_to(keeper) >= 1.1:
					face = d
					break
			# the whole run along the counter's face: east for a counter facing north or south, south otherwise
			var step := Vector2i(1, 0) if face.y != 0 else Vector2i(0, 1)
			var run := [Vector2i(x, y)]
			while true:
				var nx: Vector2i = run[-1] + step
				if code(nx.x, nx.y) != MapGen.COUNTER or done.has(nx):
					break
				# a tile whose open side faces another way starts a run of its own
				var open := nx + face
				if not MapGen.walkable(code(open.x, open.y)) and code(open.x, open.y) != MapGen.COUNTER:
					break
				run.append(nx)
			for q in run:
				done[q] = true
			var yaw := atan2(float(face.x), float(face.y))
			# pieces of about four tiles (never under three) for a long run; short runs are single base units
			var pieces := []
			if run.size() >= 3:
				var k := maxi(1, int(round(run.size() / 4.5)))
				var at := 0
				for pi in k:
					var len := (run.size() - at) / (k - pi)
					pieces.append([at, len])
					at += len
			var along := Vector3(step.x, 0, step.y)
			# each display counter's raised block, as [its middle, half its length] along the run
			var blocks := []
			for pc in pieces:
				var a: int = pc[0]
				var n: int = pc[1]
				var c := Vector3(run[a].x + 0.5, 0, run[a].y + 0.5) + Vector3(step.x, 0, step.y) * (n - 1) / 2.0
				var bb := long_piece.get_aabb()
				var mi := MeshInstance3D.new()
				mi.mesh = long_piece
				mi.scale = Vector3(n * 0.99 / bb.size.x, 1.0, 0.92 / bb.size.z)
				mi.rotation.y = yaw
				mi.position = c
				parent.add_child(mi)
				var mid := c + Basis(Vector3.UP, yaw) * Vector3((DISPLAY_BLOCK.x + DISPLAY_BLOCK.y) / 2.0 * mi.scale.x, 0, 0)
				blocks.append([mid.dot(along), (DISPLAY_BLOCK.y - DISPLAY_BLOCK.x) / 2.0 * mi.scale.x])
			var ends := Vector2(Vector3(run[0].x + 0.5, 0, run[0].y + 0.5).dot(along), Vector3(run[-1].x + 0.5, 0, run[-1].y + 0.5).dot(along))
			if pieces.is_empty():
				var sb := short_piece.get_aabb()
				for q in run:
					var mi2 := MeshInstance3D.new()
					mi2.mesh = short_piece
					mi2.scale = Vector3(1.0 / sb.size.x, 1.0 / sb.size.y, 0.9 / sb.size.z)
					mi2.rotation.y = yaw
					mi2.position = Vector3(q.x + 0.5, 0, q.y + 0.5)
					parent.add_child(mi2)
			var top := DISPLAY_TOP if not pieces.is_empty() else BASE_UNIT_TOP
			for q in run:
				if map.get("counter_phone", Vector2i(-1, -1)) == q:
					var spot := Vector3(q.x + 0.5, 0, q.y + 0.5)
					_counter_phone(spot + along * _off_block(spot.dot(along), 0.28, blocks, ends), yaw, top)
					continue
				var item := ""
				var mine := false
				if not till_done and q.distance_to(keeper) < 1.5:
					item = TILL.get(shop, "mall_register")
					till_done = true
					mine = true
				elif rng.randf() < 0.45:
					item = goods[rng.randi_range(0, goods.size() - 1)]
				if item == "" or piece(item) == null:
					continue
				var t := MeshInstance3D.new()
				t.mesh = piece(item)
				var back := Basis(Vector3.UP, yaw)
				var half := maxf(t.mesh.get_aabb().size.x, t.mesh.get_aabb().size.z) / 2.0
				if mine:
					# by the keeper, at the back edge of the counter, its front (keys, screen) turned to them; slid along
					# past the counter's raised block if it would stand in it
					t.position = Vector3(q.x + 0.5, top, q.y + 0.5) + back * Vector3(0, 0, -0.2)
					t.position += along * _off_block(t.position.dot(along), half, blocks, ends)
					t.rotation.y = yaw + PI
				else:
					t.position = Vector3(q.x + 0.5, top, q.y + 0.5) + back * Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.15, 0.05))
					t.rotation.y = yaw + rng.randf_range(-0.5, 0.5)
					# goods never stand in the raised block
					if _off_block(t.position.dot(along), half, blocks, ends) != 0.0:
						t.free()
						continue
				parent.add_child(t)


## How far along a counter run something `half` wide at `at` must slide to clear the display counters' raised blocks
## ([middle, half length] along the run), staying between the run's end tiles (`ends`); 0 if it's already clear.
static func _off_block(at: float, half: float, blocks: Array, ends: Vector2) -> float:
	for blk in blocks:
		var gap := half + float(blk[1]) + 0.03
		var d := at - float(blk[0])
		if absf(d) >= gap:
			continue
		var lo := minf(ends.x, ends.y)
		var hi := maxf(ends.x, ends.y)
		# out the nearer side, unless that runs off the end of the counter
		var push := (gap - d) if d >= 0.0 else (-gap - d)
		if at + push < lo or at + push > hi:
			push = (-gap - d) if d >= 0.0 else (gap - d)
		return push
	return 0.0


## The red telephone on a counter (the room's "counter_phone"), on a white mat like the one on its usual table and
## turned to the customers. It shakes with the others when it rings.
func _counter_phone(at: Vector3, yaw: float, top: float) -> void:
	var t := MeshInstance3D.new()
	t.mesh = piece("phone_rotary")
	if t.mesh == null:
		return
	t.scale = Vector3.ONE * float(KINDS["phone"].get("top_scale", 1.0))
	var foot := t.mesh.get_aabb().size * t.scale
	var mat := MeshInstance3D.new()
	var mb := BoxMesh.new()
	mb.size = Vector3(foot.x + 0.1, 0.008, foot.z + 0.08)
	mat.mesh = mb
	mat.material_override = plain_material(Color(KINDS["phone"]["mat"]))
	mat.position = Vector3(at.x, top + 0.004, at.z)
	mat.rotation.y = yaw
	mat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mat)
	t.position = Vector3(at.x, top + 0.008, at.z)
	t.rotation.y = yaw
	t.add_to_group("phones")
	parent.add_child(t)
	if map.get("room", {}).get("counter_phone_plant", false):
		var offset := Basis(Vector3.UP, yaw) * Vector3(0.7, 0, 0)
		var plant := _stand("home/plant_succulent", Vector3(at.x, top, at.z) + offset, yaw)
		if plant != null:
			var bb := plant.mesh.get_aabb()
			plant.scale = Vector3.ONE * (0.38 / bb.size.y)
			plant.position.y -= bb.position.y * plant.scale.y


## Of the models for a kind, the one that fills the space best. Ties go to chance, or with `same`, to the building's
## own pick of the list (pick_seed), so its chairs match and its sofa and armchair do.
## The models (_placed) or things on top (_placed_tops) of the pieces already standing on the tiles around a group, the
## diagonals included; none for chairs, which may stand in matching rows.
func _near_placed(group: Array, chair: bool, of: Dictionary) -> Array:
	var out := []
	if chair:
		return out
	for q in group:
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				var r: Vector2i = q + Vector2i(dx, dy)
				if not r in group and of.has(r) and not of[r] in out:
					out.append(of[r])
	return out


func _choose(names: Array, span: float, depth: float, same := false) -> Mesh:
	var best: Mesh = null
	var best_d := INF
	for i in names.size():
		var m := piece(names[i])
		if m == null:
			continue
		var bb := m.get_aabb()
		# how much it must shrink, plus how much room it leaves empty
		var shrink := maxf(0.0, maxf(bb.size.x / span, bb.size.z / depth) - 1.0)
		var empty := absf(span - bb.size.x) / span + absf(depth - bb.size.z) / depth * 0.5
		var tie := (0.0 if posmod(i - pick_seed, names.size()) == 0 else 0.1) if same else rng.randf() * 0.15
		var d := shrink * 3.0 + empty + tie
		if d < best_d:
			best_d = d
			best = m
	return best


## Goods on a shop's shelves: rows of packets and bottles at each shelf. Returns them.
func _goods(pos: Vector3, yaw: float, bb: AABB, sc: Vector3) -> Array:
	var out := []
	var basis := Basis(Vector3.UP, yaw)
	var width := bb.size.x * sc.x
	for shelf_y in [0.06, 0.36, 0.66]:
		var x := -width / 2.0 + 0.12
		while x < width / 2.0 - 0.1:
			var t := MeshInstance3D.new()
			t.mesh = piece(["product_1", "product_2", "product_3", "product_4", "bottle_2"][rng.randi_range(0, 4)])
			if t.mesh != null:
				t.position = pos + basis * Vector3(x, bb.size.y * sc.y * shelf_y, 0.0)
				t.rotation.y = yaw
				parent.add_child(t)
				out.append(t)
			x += rng.randf_range(0.1, 0.18)
	return out


# ---------------------------------------------------------------- on the walls
## Hangs a piece on the wall of tile (x, y), facing `inside` (the room side), `up` metres up, shifted `side` along.
func _hang(name: String, x: int, y: int, inside: Vector2i, up: float, side: float) -> MeshInstance3D:
	var m := piece(name)
	if m == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = m
	var yaw := atan2(float(inside.x), float(inside.y))
	var bb := m.get_aabb()
	var c := Vector3(x + 0.5, up, y + 0.5) + Vector3(inside.x, 0, inside.y) * (T / 2.0 + bb.size.z / 2.0 + 0.005)
	c += Basis(Vector3.UP, yaw) * Vector3(side, 0, 0)
	mi.position = c
	mi.rotation.y = yaw
	if wallish(x, y):
		_attach(x, y, mi)
	else:
		parent.add_child(mi)
	return mi


## Marks a just-hung clock (`--scene=interiors` counts them: one per room at most); true when there is one.
func _mark_clock(mi: Node3D) -> bool:
	if mi == null:
		return false
	mi.set_meta("wall_clock", true)
	return true


## A barn's lantern on wall tile (x, y), on its face towards `inside` (barn_builder.gd).
func _lantern(x: int, y: int, inside: Vector2i) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = load("res://scripts/gfx/barn_builder.gd").lantern()
	mi.position = Vector3(x + 0.5, 1.75, y + 0.5) + Vector3(inside.x, 0, inside.y) * (T / 2.0 + 0.005)
	mi.rotation.y = atan2(float(inside.x), float(inside.y))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_attach(x, y, mi)


## Paintings, clocks, mirrors, shelves and lights on the walls: along each room's back walls (the ones the camera
## looks at) and side walls, where nothing tall stands in front.
func _wall_decor() -> void:
	if home:
		_home_wall_decor()
		return
	var furn: Dictionary = map.get("furniture", {})
	var hung := {}
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if code(x, y) != MapGen.IWALL:
				continue
			for inside in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
				var r: Vector2i = Vector2i(x, y) + inside
				var z := zone(r.x, r.y)
				if z == "" or z == "diner":
					continue
				# only on a straight stretch of wall, with nothing tall in front
				var along := Vector2i(inside.y, inside.x)
				if not (wallish(x + along.x, y + along.y) and wallish(x - along.x, y - along.y)):
					continue
				var front_kind: String = furn.get(r, "")
				var c := code(r.x, r.y)
				if c in [MapGen.SHELF, MapGen.BOOKSHELF, MapGen.BOARD, MapGen.TERMINAL, MapGen.HEALER, MapGen.FIREPLACE, MapGen.COUNTER,
						MapGen.STAIRS_UP, MapGen.STAIRS_DOWN] \
						or front_kind in ["fridge", "wardrobe", "pantry", "storage", "bookshelf", "shelf", "coat_stand", "bunk"]:
					continue
				# never two things side by side, nor over a window's curtains
				if hung.has(Vector2i(x, y) + along) or hung.has(Vector2i(x, y) - along) or _by_window.has(Vector2i(x, y)):
					continue
				var before := parent.get_child_count() + (rows[y] as Node3D).get_child_count() if rows.has(y) else parent.get_child_count()
				var roll := rng.randf()
				if map.get("room", {}).get("barn", false):
					# a kennel barn: lanterns along the walls, no pictures
					if (x + y) % 3 == 0:
						_lantern(x, y, inside)
						hung[Vector2i(x, y)] = true
					continue
				match z:
					"bathroom":
						if front_kind == "basin":
							_hang("mirror", x, y, inside, 1.15, 0.0)
						elif roll < 0.25:
							_hang("wall_shelf", x, y, inside, 1.5, 0.0)
					"kitchen":
						if front_kind in ["counter", "kitchen_sink"] and roll < 0.45:
							_hang("wall_shelf_2", x, y, inside, 1.25, 0.0)
						elif front_kind == "" and roll < 0.2 and not _clock_hung:
							_clock_hung = _mark_clock(_hang("clock", x, y, inside, 1.75, 0.0))
					"back", "stone":
						if roll < 0.08:
							_hang("breaker_box", x, y, inside, 1.3, 0.0)
					_:
						if roll < 0.22:
							_hang(["painting_1", "painting_2", "painting_3", "painting_4", "painting_5"][rng.randi_range(0, 4)], x, y, inside, 1.35, 0.0)
						elif roll < 0.3 and not _clock_hung:
							_clock_hung = _mark_clock(_hang("clock", x, y, inside, 1.8, 0.0))
						elif roll < 0.38:
							_hang("wall_light", x, y, inside, 1.6, 0.0)
				var after := parent.get_child_count() + (rows[y] as Node3D).get_child_count() if rows.has(y) else parent.get_child_count()
				if after > before:
					hung[Vector2i(x, y)] = true


## A doormat inside the front door.
func _mats_at_doors() -> void:
	var done := {}
	for y in h:
		for x in w:
			if code(x, y) != MapGen.MAT or done.has(Vector2i(x, y)):
				continue
			var n := 1
			while code(x + n, y) == MapGen.MAT:
				done[Vector2i(x + n, y)] = true
				n += 1
			var mi := MeshInstance3D.new()
			mi.mesh = piece("doormat")
			if mi.mesh != null:
				var bb := mi.mesh.get_aabb()
				mi.scale = Vector3(minf(1.6, n * 0.8) / bb.size.x, 1.0, 0.55 / bb.size.z)
				mi.position = Vector3(x + n / 2.0, 0.012, y - 0.2)
				parent.add_child(mi)
	# a front door in a side wall: its mat lies on the floor just inside, along the wall
	for t: Vector2i in map.get("front_doors", []):
		var mi2 := MeshInstance3D.new()
		mi2.mesh = piece("doormat")
		if mi2.mesh == null:
			continue
		var into := Vector2i(0, 1)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]:
			if not wallish(t.x + d.x, t.y + d.y) and code(t.x + d.x, t.y + d.y) != MapGen.IVOID:
				into = d
				break
		var bb2 := mi2.mesh.get_aabb()
		mi2.scale = Vector3(0.8 / bb2.size.x, 1.0, 0.55 / bb2.size.z)
		mi2.rotation.y = atan2(float(into.x), float(into.y))
		mi2.position = Vector3(t.x + 0.5, 0.012, t.y + 0.5) + Vector3(into.x, 0, into.y) * 0.62
		parent.add_child(mi2)


# ---------------------------------------------------------------- lights
## A warm light near the ceiling of each room (each run of floor between walls of one kind of room).
func _lights() -> void:
	var seen := {}
	for y in h:
		for x in w:
			var p := Vector2i(x, y)
			if seen.has(p) or wallish(x, y) or code(x, y) == MapGen.IVOID:
				continue
			var z := zone(x, y)
			var tiles := []
			var stack := [p]
			seen[p] = true
			while not stack.is_empty():
				var q: Vector2i = stack.pop_back()
				tiles.append(q)
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var r: Vector2i = q + d
					if r.x >= 0 and r.y >= 0 and r.x < w and r.y < h and not seen.has(r) and not wallish(r.x, r.y) and zone(r.x, r.y) == z:
						seen[r] = true
						stack.append(r)
			var lo := Vector2(INF, INF)
			var hi := Vector2(-INF, -INF)
			for q in tiles:
				lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
				hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
			var size := hi - lo + Vector2.ONE
			# big rooms get a light every few tiles
			var nx := maxi(1, int(round(size.x / 6.0)))
			var nz := maxi(1, int(round(size.y / 6.0)))
			for i in nx:
				for j in nz:
					var l := OmniLight3D.new()
					l.light_color = Color(ZONES.get(z, ZONES["shop"])["light"]) if not ancient else Color("#ffc890")
					# (a temple is dark: its torches light it, over a faint fill)
					l.light_energy = 0.7 if not temple else 0.18
					l.omni_range = maxf(size.x / nx, size.y / nz) * 0.9 + 2.0
					l.position = Vector3(lo.x + size.x * (i + 0.5) / nx, 2.4, lo.y + size.y * (j + 0.5) / nz)
					parent.add_child(l)
					lights.append(l)


# ---------------------------------------------------------------- homes (2026-11-15 interiors pass)
## Rooms that are someone's home (by template key): their decor comes from the home decor kit in the room's colour
## scheme (home_decor.gd), their walls take the scheme's paint, they get cubbies and closets in their walls, and
## nothing in them fades: anything the player can walk behind is no taller than the hero's waist (WAIST).
const HOME_KEYS := ["home", "house_two", "house_up", "studio_a", "studio_b", "uncle_home", "kit_cabin", "shack"]
## The hero is about 1.44 tall; this is about their waist. Furniture with walkable floor straight behind it (north)
## stays below it in a home, so it never hides the player and never needs fading.
const WAIST := 0.85
## A piece at most this much taller than WAIST is lowered to it at the front (armchairs, 0.90); taller ones may not
## stand there.
const WAIST_GIVE := 1.12
## A window: the hole through the wall (half its width) and how deep the glass sits behind the room-side face (the
## wall is T thick; the reveal carries on behind it, where nothing else is); the painted casing round it.
const WIN_HALF := 0.36
const WIN_DEPTH := 0.3
const CASING := 0.07
## A small cubby in a wall (a shelf niche) and a closet (a floor-to-head recess with shelves).
const CUBBY := {"half": 0.3, "y0": 0.98, "y1": 1.62, "depth": 0.3}
const CLOSET := {"y1": 2.08, "depth": 0.48}
## how thick a closet's shelves are: chunky, never thin boards
const SHELF_T := 0.09
## A raised platform (the user's direction, 2026-11-15: mostly in cafes, large, along a whole side or in a corner of
## the room, with railings and steps where you walk up). A template's "dais": [{"rect": [x, y, w, h], "steps":
## [[x, y], ...]}, ...]: the rect is one step up (DAIS_H), walked on like any floor (map_loader.gd makes it the room's
## "heights"); each step tile, on its edge, is cut into it and rises from the floor beside it. Railings run along its edges over open floor, except
## at the steps. People on it sit on floor cushions (map_loader.gd).
const DAIS_H := 0.3
const HomeDecor = preload("res://scripts/gfx/home_decor.gd")

var home := false
var scheme := HomeDecor.DEFAULT_SCHEME
## wall tiles holding a cubby or a closet: {Vector2i: {"inside": Vector2i, "kind": "cubby" or "closet", "x0", "w"}}
var _cubbies := {}
var tide_panel: MeshInstance3D
var tide_cubby_light: OmniLight3D
## Every occupied wall tile addresses its shared sliding leaf.
var shelf_doors := {}
## wall tiles beside a window (its curtains hang over them)
var _by_window := {}
## true once a clock hangs in this room: never more than one clock on a room's walls (the user's 2026-11-15 rule)
var _clock_hung := false
var _prints_used := []


static func is_home(m: Dictionary) -> bool:
	if m.get("room", {}).get("home", false):
		return true
	var key := String(m.get("room_key", ""))
	for k in HOME_KEYS:
		if key == k or key.begins_with(k + "_"):
			return true
	return false


## The room's colour scheme: the template's own ("scheme"), else one of the schemes made for its kind of room,
## picked from the building's seed.
func _pick_scheme() -> String:
	var own := String(map.get("room", {}).get("scheme", ""))
	if own != "":
		return own
	var kind := default_zone if default_zone in ["living", "bedroom", "kitchen", "bathroom", "hall"] else "living"
	var opts := []
	var all := HomeDecor.schemes()
	for k in all:
		if kind in all[k]["rooms"]:
			opts.append(k)
	opts.sort()
	return opts[posmod(pick_seed, opts.size())] if not opts.is_empty() else HomeDecor.DEFAULT_SCHEME


func _sch(what: String) -> Color:
	return Color(HomeDecor.scheme(scheme)[what])


## A home's painted wall: the scheme's paint (keeping the room's stripe where it has wallpaper).
func _home_wall(tex: String) -> Material:
	var base := Color(WALL_COLOURS.get(tex, "#eee7d9"))
	var want := _sch("wall")
	return wall_surface(tex, Color(want.r / base.r, want.g / base.g, want.b / base.b))


## Whether the player can stand straight behind (north of) a piece on tiles lo .. lo + size: walkable floor in any
## of its columns just beyond its back. Such a piece would hide them, so in a home it stays below WAIST.
static func behind_open(m: Dictionary, lo: Vector2i, size: Vector2) -> bool:
	for x in range(lo.x, lo.x + int(size.x)):
		if MapGen.get_t(m, x, lo.y - 1) in [MapGen.IFLOOR, MapGen.ITILE, MapGen.RUG, MapGen.MAT]:
			return true
	return false


## Every piece in a home that rises above WAIST with floor behind it (tools/check_maps.gd reports these).
static func front_tall(m: Dictionary) -> Array:
	var out := []
	if not is_home(m):
		return out
	for part in furniture_groups(m):
		var kind: String = part["kind"]
		if kind == "rug":
			continue
		var layout := furniture_layout(m, kind, part["tiles"])
		if not behind_open(m, layout["lo"], layout["size"]):
			continue
		var lowest := INF
		for n in KINDS[kind].get("home_m", KINDS[kind]["m"]):
			var mesh := piece(n)
			if mesh != null:
				lowest = minf(lowest, mesh.get_aabb().size.y)
		if lowest > WAIST * WAIST_GIVE:
			out.append("%s at %s (%.2f tall)" % [kind, layout["lo"], lowest])
	return out


## The kit's materials on a piece from assets/interiors/home/ (others are left as they are).
func _decor_mats(mi: MeshInstance3D) -> void:
	if mi.mesh == null or not "/home/" in mi.mesh.resource_path:
		return
	var name := mi.mesh.resource_path.get_file().get_basename()
	var made := HomeDecor.make(name, scheme, _next_print() if mi.mesh.get_surface_count() > 1 else "", _colourway())
	if made == null:
		return
	for i in mi.mesh.get_surface_count():
		mi.set_surface_override_material(i, made.get_surface_override_material(i))
	made.free()


## Prints never repeat in a room; only the player's bedroom shows the rocket (over the bed).
func _next_print() -> String:
	var avoid: Array = _prints_used.duplicate()
	avoid.append(HomeDecor.ROCKET)
	var got := HomeDecor.pick_prints(pick_seed + _prints_used.size() * 7919, 1, avoid)
	if got.is_empty():
		# (a room with more frames than there are prints starts again, in a new order)
		_prints_used.clear()
		got = HomeDecor.pick_prints(pick_seed + 104729, 1, [HomeDecor.ROCKET])
		if got.is_empty():
			return ""
	_prints_used.append(got[0])
	return got[0]


## Roughly one home in four (and the player's own room) shows its prints in the bold jewel colourway.
func _colourway() -> String:
	return "jewel_pop" if posmod(pick_seed, 4) == 0 or String(map.get("room_key", "")) == "home_bed" else scheme


## A decor piece hung on the room face of wall tile (x, y) facing `inside`, its origin `up` high and `side` along.
func _hang_decor(name: String, x: int, y: int, inside: Vector2i, up: float, side: float, print_id := "", sc := 1.0) -> MeshInstance3D:
	var mi := HomeDecor.make(name, scheme, print_id if print_id != "" else (_next_print() if HomeDecor.crop_of(name) != "" else ""), _colourway())
	if mi == null:
		return null
	var yaw := atan2(float(inside.x), float(inside.y))
	mi.position = Vector3(x + 0.5, up, y + 0.5) + Vector3(inside.x, 0, inside.y) * (T / 2.0 + 0.004) \
		+ Basis(Vector3.UP, yaw) * Vector3(side, 0, 0)
	mi.rotation.y = yaw
	mi.scale = Vector3.ONE * sc
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_attach(x, y, mi)
	return mi


## A small thing (a decor piece or a pack piece) standing at `at`, turned `yaw`.
func _stand(name: String, at: Vector3, yaw: float, sc := 1.0) -> MeshInstance3D:
	var mesh := piece(name)
	if mesh == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.rotation.y = yaw
	mi.scale = Vector3.ONE * sc
	_decor_mats(mi)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------- openings in walls
## A hole through wall tile (x, y) from height y0 to y1, `half` wide either side of the tile's middle, lined `depth`
## deep from the room-side face (past the wall's back, where nothing else is): the wall either side of the hole on
## both faces, and the reveal (both sides and the head; the bottom and back too if `closed`) in `lining`.
func _recess(x: int, y: int, inside: Vector2i, y0: float, y1: float, half: float, depth: float, closed: bool, lining: Material = null, span := 1) -> void:
	var m := _row(y)
	var z := zone(x + inside.x, y + inside.y)
	if z == "":
		z = default_zone
	var mat: Material = lining if lining != null else wall_mat(z)
	# (a lining of its own gets its own surface: the mesher keeps one material per key)
	var key := "recess" if lining == null else "recess_%d" % lining.get_instance_id()
	var along := Vector3(absf(float(inside.y)), 0, absf(float(inside.x)))
	var inward := Vector3(inside.x, 0, inside.y)
	# (a hole `span` tiles wide is centred on the run of tiles from (x, y) on)
	var c := Vector3(x + 0.5, 0, y + 0.5) + along * (span - 1) * 0.5
	var up := Vector3.UP
	for f in [[c + inward * T / 2.0, inward], [c - inward * T / 2.0, -inward]]:
		var o: Vector3 = f[0]
		for s in [-1.0, 1.0]:
			var a: Vector3 = o + along * s * span * 0.5
			var b: Vector3 = o + along * s * half
			_face(m, z, [a + up * y0, b + up * y0, b + up * y1, a + up * y1], f[1], along)
	var face := c + inward * T / 2.0
	var back := face - inward * depth
	for s in [-1.0, 1.0]:
		var p: Vector3 = face + along * s * half
		var q: Vector3 = back + along * s * half
		m.quad(key, mat, [p + up * y0, q + up * y0, q + up * y1, p + up * y1], -along * s, inward, Vector3.DOWN, 0.86)
	m.quad(key, mat, [face - along * half + up * y1, face + along * half + up * y1, back + along * half + up * y1,
		back - along * half + up * y1], Vector3.DOWN, along, inward, 0.8)
	if closed:
		m.quad(key, mat, [face - along * half + up * y0, face + along * half + up * y0, back + along * half + up * y0,
			back - along * half + up * y0], Vector3.UP, along, inward, 0.95)
		m.quad(key, mat, [back - along * half + up * y0, back + along * half + up * y0, back + along * half + up * y1,
			back - along * half + up * y1], inward, along, Vector3.DOWN, 0.82)


## A painted casing round a hole in wall tile (x, y): two jambs and a head on the room face, `half` from the middle
## (and a foot under it if `with_foot`).
func _casing(x: int, y: int, inside: Vector2i, y0: float, y1: float, half: float, with_foot: bool) -> void:
	var m := _row(y)
	var mat := _trim_mat()
	var along := Vector3(absf(float(inside.y)), 0, absf(float(inside.x)))
	var inward := Vector3(inside.x, 0, inside.y)
	var face := Vector3(x + 0.5, 0, y + 0.5) + inward * (T / 2.0 + 0.014)
	var horiz := inside.y != 0
	var foot := CASING if with_foot else 0.0
	for s in [-1.0, 1.0]:
		m.box("casing", mat, face + along * s * (half + CASING / 2.0) + Vector3.UP * ((y0 - foot) + y1) / 2.0,
			_axes(along, CASING, y1 - y0 + foot, 0.03, horiz))
	m.box("casing", mat, face + Vector3.UP * (y1 + CASING / 2.0), _axes(along, half * 2.0 + CASING * 2.0, CASING, 0.03, horiz))
	if with_foot:
		m.box("casing", mat, face + Vector3.UP * (y0 - CASING / 2.0), _axes(along, half * 2.0 + CASING * 2.0, CASING, 0.03, horiz))


## Painted trim: the scheme's in a home, else a light version of the room's trim.
func _trim_mat() -> Material:
	return surface("window_frame", _sch("trim") if home else trim.lightened(0.55))


# ---------------------------------------------------------------- window boxes
## Every window looks out into a sealed box of its region's nature (the user's direction, 2026-11-15): as deep, and
## carrying on as far past its end windows (never behind a door), as its windows' size asks (BOX_SIZES; BOX_DEEP and
## BOX_PAST are the largest), with a grass floor, the region's own
## pre-blurred landscape (tools/bake_window_views.gd) round its back and ends, and its outsides and lid black like the
## room's background (world.gd) so none of it shows from the camera.
const BOX_DEEP := 3
const BOX_PAST := 2
const BOX_BLACK := Color("#0d0a10")
## how far a box's plants and rocks keep from its walls (the room's wall and its landscape)
const BOX_CLEAR := 0.05
const VIEWS := "res://assets/interiors/window_views/"
## how much of the landscape's height (from its foot) shows, and how many units one repeat of it spans
const VIEW_SHOWN := 0.7
const VIEW_SPAN := 8.0
const BOX_ROCKS := ["rock_small", "stone_2", "stone_3"]
const BOX_TUFTS := ["grass_leaf_0", "grass_leaf_1", "grass_leaf_2"]
const BOX_DRY := ["desert", "mesa", "western", "volcano"]
const VA = preload("res://scripts/gfx/voxel_assets.gd")
## window tiles that look out into a box (their glass is clear)
var _boxed := {}
## the boxes' plants, rocks and fences: mesh -> transforms, batched once per room
var _box_props := {}


## The window box rules (docs/interior_staging.md rule 13): a box's depth and how far it carries on past its end
## windows follow the size of its windows. A full-height window shows a lot of ground and wants the full depth; an
## ordinary window shows less and may have a shallower box. Each prefers its `deep` and, where other rooms or boxes are
## in the way, makes do with less, down to `min`; below that the window has no box (and the checker says so, unless no
## camera position can see through it: tools/check_maps.gd _window_box_check).
const BOX_SIZES := {
	"tall": {"deep": 3, "min": 2, "past": 2},
	"window": {"deep": 2, "min": 1, "past": 1},
}
## the box planned behind each boxed window tile: {start, n, out, deep}
var _box_of := {}


## The size of window this room has (see BOX_SIZES).
func _window_size() -> String:
	return "tall" if map.get("room", {}).get("full_height_windows", false) else "window"


## Plans the window boxes, back walls first (side walls' boxes stop where they meet them), marking the windows they
## serve in _boxed. Returns [{start, n, out, deep, base}], one per box.
func _plan_boxes() -> Array:
	var boxes := []
	if float(map.get("room", {}).get("wall_height", H)) < H:
		return boxes
	var size: Dictionary = BOX_SIZES[_window_size()]
	var balconies: Dictionary = map.get("balcony_doors", {})
	var claimed := {}
	for out: Vector2i in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var along := Vector2i(absi(out.y), absi(out.x))
		for y in h - 1:
			for x in w:
				var t := Vector2i(x, y)
				if _boxed.has(t) or not _box_window(t, out, balconies):
					continue
				# the deepest box (up to the size's own) that fits behind this window
				var deep := int(size["deep"])
				while deep >= int(size["min"]) and not _box_cells_free(t, out, claimed, deep):
					deep -= 1
				if deep < int(size["min"]):
					continue
				# from this window (the first on its wall line) back up to `past` tiles, and on past the last window
				var past := int(size["past"])
				var start := t
				for i in past:
					var q := start - along
					if not _box_line_ok(q, out, balconies, claimed, deep):
						break
					start = q
				var finish := t
				var last := t
				var windows := [t]
				var q2 := t + along
				while (q2 - last).length() <= past and _box_line_ok(q2, out, balconies, claimed, deep):
					finish = q2
					if _box_window(q2, out, balconies):
						last = q2
						windows.append(q2)
					q2 += along
				var n := int((finish - start).length()) + 1
				for i in n:
					var p: Vector2i = start + along * i
					if _outside(p):
						claimed[p] = true
					for k in range(1, deep + 1):
						claimed[p + out * k] = true
				# (a balcony doorway's garden lies half a storey below its sill, under its little balcony)
				var sill := Elev.surface(map, t)
				var drop := BALCONY_DROP if windows.any(func(wt): return balconies.has(wt)) else 0.0
				var box := {"start": start, "n": n, "out": out, "deep": deep, "base": sill - drop, "sill": sill}
				for wt in windows:
					_boxed[wt] = true
					_box_of[wt] = box
				boxes.append(box)
	return _merge_boxes(boxes)


## Boxes on the same wall line that meet end to end become one box (the user's 2026-11-15 direction: a run of the
## hotel's doorways two tiles apart planned a little box behind each, their ends showing between them). The merged box
## takes the shallower depth and the lower floor.
func _merge_boxes(boxes: Array) -> Array:
	var merged := true
	while merged:
		merged = false
		for i in boxes.size():
			for j in boxes.size():
				if i == j:
					continue
				var a: Dictionary = boxes[i]
				var b: Dictionary = boxes[j]
				var out: Vector2i = a["out"]
				if b["out"] != out:
					continue
				var along := Vector2i(absi(out.y), absi(out.x))
				var a_end: Vector2i = a["start"] + along * int(a["n"])
				if b["start"] != a_end:
					continue
				a["n"] = int(a["n"]) + int(b["n"])
				a["deep"] = mini(int(a["deep"]), int(b["deep"]))
				a["base"] = minf(float(a["base"]), float(b["base"]))
				a["sill"] = maxf(float(a.get("sill", a["base"])), float(b.get("sill", b["base"])))
				for t in _box_of.keys():
					if _box_of[t] == b:
						_box_of[t] = a
				boxes.remove_at(j)
				merged = true
				break
			if merged:
				break
	return boxes


## Every outward-looking window of map `m`, by tile: {"out" (the side the outside is on), "back" (on the back wall),
## "box" (its planned box, or null)}. For the checker; builds nothing.
static func window_boxes_of(m: Dictionary) -> Dictionary:
	var rb = load("res://scripts/gfx/room_builder.gd").new()
	rb.map = m
	rb.w = m["w"]
	rb.h = m["h"]
	rb.default_zone = m.get("zone_default", "shop")
	rb._plan_boxes()
	var found := {}
	var balconies: Dictionary = m.get("balcony_doors", {})
	for y in rb.h:
		for x in rb.w:
			var t := Vector2i(x, y)
			if rb.code(x, y) != MapGen.IWINDOW:
				continue
			for out: Vector2i in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]:
				if rb.zone(x + out.x, y + out.y) == "" and rb.zone(x - out.x, y - out.y) != "":
					found[t] = {"out": out, "back": out.y != 0, "outside": rb._outside(t + out), "box": rb._box_of.get(t)}
					break
	return found


## Builds the planned window boxes.
func _window_boxes() -> void:
	for box in _plan_boxes():
		_window_box(box["start"], box["n"], box["out"], box["base"], box["deep"], box["sill"])
	if _box_props.is_empty():
		return
	var batch := Node3D.new()
	batch.name = "WindowBoxNature"
	parent.add_child(batch)
	for mesh: Mesh in _box_props:
		var xfs: Array = _box_props[mesh]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.add_child(mmi)


## Outside the room (off the map or void).
func _outside(p: Vector2i) -> bool:
	return p.x < 0 or p.y < 0 or p.x >= w or p.y >= h or code(p.x, p.y) == MapGen.IVOID


## A window (or a balcony's open doorway, which looks into a box too) with the room on its inside and the outside on
## side `out`.
func _box_window(p: Vector2i, out: Vector2i, balconies: Dictionary) -> bool:
	return code(p.x, p.y) == MapGen.IWINDOW and zone(p.x + out.x, p.y + out.y) == "" \
		and zone(p.x - out.x, p.y - out.y) != "" and _outside(p + out)


## The `deep` tiles outside wall tile `p` are all outside the room and in no other box.
func _box_cells_free(p: Vector2i, out: Vector2i, claimed: Dictionary, deep := BOX_DEEP) -> bool:
	for k in range(1, deep + 1):
		var q := p + out * k
		if claimed.has(q) or not _outside(q):
			return false
	return true


## A box may carry on along its wall line over `p`: plain wall, a window facing the same way, or the outside, never a
## door or a diagonal, with free outside tiles beyond it.
func _box_line_ok(p: Vector2i, out: Vector2i, balconies: Dictionary, claimed: Dictionary, deep := BOX_DEEP) -> bool:
	if claimed.has(p):
		return false
	if not (_outside(p) or code(p.x, p.y) == MapGen.IWALL or _box_window(p, out, balconies)):
		return false
	return _box_cells_free(p, out, claimed, deep)


## One window box `box_deep` tiles deep behind wall tiles `start` .. `start + along * (n - 1)`, its floor at height
## `base`. Below `sill` (where a balcony doorway's garden lies lower than the room) its front is the building's
## plastered wall all along, so nothing under the room shows.
func _window_box(start: Vector2i, n: int, out: Vector2i, base: float, box_deep := BOX_DEEP, sill := NAN) -> void:
	var biome: Dictionary = map.get("biome", {})
	var bid := String(biome.get("id", "coast"))
	var along := Vector3(absi(out.y), 0, absi(out.x))
	var o3 := Vector3(out.x, 0, out.y)
	var up := Vector3.UP
	var tall := float(map.get("room", {}).get("wall_height", H)) - base
	var len_u := float(n)
	var deep := float(box_deep)
	var origin := Vector3(start.x + 0.5, base, start.y + 0.5) + o3 * (T / 2.0) - along * 0.5
	var at := func(u: float, v: float, hh: float) -> Vector3: return origin + along * u + o3 * v + up * hh
	var grass := SurfaceTool.new()
	var view := SurfaceTool.new()
	var black := SurfaceTool.new()
	for st: SurfaceTool in [grass, view, black]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var white := Color.WHITE
	var flat := [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]
	# the grass floor, one repeat of its texture per two tiles
	_st_quad(grass, [at.call(0.0, 0.0, 0.0), at.call(len_u, 0.0, 0.0), at.call(len_u, deep, 0.0), at.call(0.0, deep, 0.0)],
		[Vector2(0, 0), Vector2(len_u / 2.0, 0), Vector2(len_u / 2.0, deep / 2.0), Vector2(0, deep / 2.0)], up, white)
	# the landscape round the inside: up one end, along the back and down the other, continuous round the corners;
	# black on the outside of each
	var s0 := float(start.x + start.y) - deep
	var v_top := 1.0 - VIEW_SHOWN
	var sides := [[0.0, 0.0, 0.0, deep, along], [0.0, deep, len_u, deep, -o3], [len_u, deep, len_u, 0.0, -along]]
	var run := 0.0
	for seg in sides:
		var p0: Vector3 = at.call(seg[0], seg[1], 0.0)
		var p1: Vector3 = at.call(seg[2], seg[3], 0.0)
		var span := p0.distance_to(p1)
		var u0 := (s0 + run) / VIEW_SPAN
		var u1 := (s0 + run + span) / VIEW_SPAN
		var quad := [p0, p1, p1 + up * tall, p0 + up * tall]
		_st_quad(view, quad, [Vector2(u0, 1.0), Vector2(u1, 1.0), Vector2(u1, v_top), Vector2(u0, v_top)], seg[4], white)
		_st_quad(black, quad, flat, -(seg[4] as Vector3), white)
		run += span
	# a black lid, and black across the box's front everywhere but its windows (behind the walls' own faces, and
	# closing the gaps at the room's corners and wherever it runs on past the room)
	_st_quad(black, [at.call(0.0, 0.0, tall), at.call(len_u, 0.0, tall), at.call(len_u, deep, tall), at.call(0.0, deep, tall)], flat, up, white)
	var low := 0.0 if is_nan(sill) else maxf(0.0, sill - base)
	var facade := SurfaceTool.new()
	facade.begin(Mesh.PRIMITIVE_TRIANGLES)
	if low > 0.0:
		_st_quad(facade, [at.call(0.0, 0.0, 0.0), at.call(len_u, 0.0, 0.0), at.call(len_u, 0.0, low), at.call(0.0, 0.0, low)],
			[Vector2(0, 0), Vector2(len_u, 0), Vector2(len_u, low), Vector2(0, low)], -o3, white)
	for i in n:
		if not _boxed.has(start + Vector2i(int(along.x), int(along.z)) * i):
			_st_quad(black, [at.call(float(i), 0.0, low), at.call(float(i + 1), 0.0, low), at.call(float(i + 1), 0.0, tall),
				at.call(float(i), 0.0, tall)], flat, -o3, white)
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = load("res://assets/textures/surfaces/ground_grass.png")
	# the region's own grass (the texture is grey), a little parched in dry regions
	var turf := Color(str(biome.get("ground", "#7cc05a")))
	gm.albedo_color = Color("#8cb85a").lerp(turf, 0.35) if bid in BOX_DRY else turf.lightened(0.08)
	gm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	gm.roughness = 1.0
	var vm := StandardMaterial3D.new()
	var tex_path := VIEWS + bid + ".png"
	vm.albedo_texture = load(tex_path if ResourceLoader.exists(tex_path) else VIEWS + "coast.png")
	vm.albedo_color = Color("#e6ece6")
	vm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	vm.texture_repeat = true
	vm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var bm := surface("wall_plaster", BOX_BLACK).duplicate() as StandardMaterial3D
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mesh := ArrayMesh.new()
	var parts := [[grass, gm], [view, vm], [black, bm]]
	if low > 0.0:
		parts.append([facade, wall_mat(default_zone)])
	for pair in parts:
		(pair[0] as SurfaceTool).commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, pair[1])
	var mi := MeshInstance3D.new()
	mi.name = "WindowBox"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	_box_nature(start, n, out, at, biome, box_deep)


## The region's nature in a window box, the same every visit: small trees at the back, its shrubs, tufts and the odd
## rock nearer, and sometimes a stretch of its fence across the middle.
func _box_nature(start: Vector2i, n: int, out: Vector2i, at: Callable, biome: Dictionary, box_deep := BOX_DEEP) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%s:%d:%d:%d:%d" % [map.get("room_key", ""), start.x, start.y, out.x, out.y])
	var trees := []
	for tw in biome.get("trees", [["tree_oak", 1]]):
		if String(tw[0]) != "stump":
			for k in int(tw[1]):
				trees.append(String(tw[0]))
	if trees.is_empty():
		trees = ["tree_oak"]
	var shrubs: Array = biome.get("shrubs", []).filter(func(s): return String(s).begins_with("bush") or String(s).begins_with("shrub"))
	if shrubs.is_empty():
		shrubs = ["bush_1", "bush_3"]
	var fenced := n >= 3 and box_deep >= 2 and r.randf() < 0.4
	# across the middle of the second row, a little nearer in a shallow box
	var fence_v := 1.9 if box_deep >= 3 else 1.4
	var f0 := r.randi_range(0, maxi(0, n - 3))
	var f1 := r.randi_range(mini(f0 + 2, n - 1), n - 1)
	if fenced:
		var style := "iron_fence" if String(biome.get("id", "")) in ["moor", "quarter"] else "fence"
		var FenceModels = load("res://scripts/gfx/fence_models.gd")
		var horiz := out.y != 0
		for i in range(f0, f1 + 1):
			var mask := 0
			if i > f0:
				mask |= 1 if horiz else 4
			if i < f1:
				mask |= 2 if horiz else 8
			_box_prop(FenceModels.tile(style, mask), Transform3D(Basis(), at.call(float(i) + 0.5, fence_v, 0.0)))
	for i in n:
		for j in box_deep:
			if fenced and i >= f0 and i <= f1 and j == 1:
				continue
			var roll := r.randf()
			var name := ""
			var size := 0.0
			if j == box_deep - 1 and roll < 0.5:
				name = trees[r.randi_range(0, trees.size() - 1)]
				size = r.randf_range(1.4, 2.3)
			elif roll < 0.5:
				name = shrubs[r.randi_range(0, shrubs.size() - 1)]
				size = r.randf_range(0.35, 0.75)
			elif roll < 0.75:
				name = BOX_TUFTS[r.randi_range(0, 2)]
				size = r.randf_range(0.2, 0.35)
			elif roll < 0.83:
				name = BOX_ROCKS[r.randi_range(0, 2)]
				size = r.randf_range(0.15, 0.3)
			else:
				continue
			var s := VA.fit_scale(name, size)
			var yaw := r.randf() * TAU
			var u := float(i) + 0.5 + r.randf_range(-0.3, 0.3)
			var v := float(j) + 0.5 + r.randf_range(-0.25, 0.25)
			# its whole footprint stays inside the box, clear of the room's wall (a wide shrub fitted by its height
			# would poke through it into the room) and of the landscape round it: smaller where it can't fit
			var bb := VA.aabb(name)
			var reach := Vector2(bb.size.x, bb.size.z).length() / 2.0 + Vector2(bb.get_center().x, bb.get_center().z).length()
			var room_for := minf(float(box_deep), float(n)) / 2.0 - BOX_CLEAR
			if reach * s > room_for:
				s = room_for / reach
			var rr := reach * s + BOX_CLEAR
			u = clampf(u, rr, float(n) - rr)
			v = clampf(v, rr, float(box_deep) - rr)
			var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s)
			_box_prop(VA.mesh(name), Transform3D(basis, at.call(u, v, -bb.position.y * s)))


func _box_prop(mesh: Mesh, xf: Transform3D) -> void:
	if not _box_props.has(mesh):
		_box_props[mesh] = []
	_box_props[mesh].append(xf)


static var _pane_glass: ShaderMaterial


## All interior panes share the same soft, screen-wide reflection over the view behind them.
func _clear_pane(x: int, y: int, c: Vector3, inside: Vector2i, width: float, height: float) -> void:
	var pane := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	pane.mesh = quad
	if _pane_glass == null:
		_pane_glass = ShaderMaterial.new()
		_pane_glass.shader = preload("res://scripts/gfx/interior_glass.gdshader")
		_pane_glass.set_shader_parameter("glass_shimmer", preload("res://assets/textures/surfaces/glass_shimmer.png"))
	pane.material_override = _pane_glass
	pane.position = c
	pane.rotation.y = atan2(float(inside.x), float(inside.y))
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_attach(x, y, pane)


## Floor-to-ceiling glazing with a continuous, existing island landscape beyond the recessed panes. Windows along a
## wall pair up, each two tiles wide (a lone tile left at a run's end stays one wide), in stout, chunky frames: a
## thick frame round the glass, a deep kick rail along the floor and a broad casing on the room face, with a
## stocky pier of wall between neighbours.
const NATURE_PIER := 0.1
const NATURE_FRAME := 0.15


func _nature_window(x: int, y: int, inside: Vector2i) -> void:
	var step := Vector2i(absi(inside.y), absi(inside.x))
	var k := 0
	while _full_glass(Vector2i(x, y) - step * (k + 1)):
		k += 1
	if k % 2 == 1:
		return  # the second tile of a pair: built with the first
	var span := 2 if _full_glass(Vector2i(x, y) + step) else 1
	var inward := Vector3(inside.x, 0, inside.y)
	var along := Vector3(absf(float(inside.y)), 0, absf(float(inside.x)))
	var horiz := inside.y != 0
	var half := span * 0.5 - NATURE_PIER
	# the reveal is lined in the frame's wood, so no plaster shows round the glass: one solid wooden frame
	_recess(x, y, inside, 0.0, H, half, WIN_DEPTH, false, surface("window_frame", trim.lightened(0.22)), span)
	var mid := Vector3(x + 0.5, 0, y + 0.5) + along * (span - 1) * 0.5
	var c := mid + Vector3.UP * (H / 2.0) + inward * (T / 2.0 - WIN_DEPTH)
	_clear_pane(x, y, c, inside, half * 2.0, H)
	var m := _row(y)
	var frame := surface("window_frame", trim.lightened(0.22))
	var f := NATURE_FRAME
	var fc := c + inward * 0.07
	# the frame round the glass: thick jambs, a head under the ceiling and a deep kick rail along the floor
	for side in [-1.0, 1.0]:
		m.box("window_frame", frame, fc + along * side * (half - f / 2.0), _axes(along, f, H, 0.14, horiz))
	m.box("window_frame", frame, fc + Vector3.UP * (H / 2.0 - f / 2.0), _axes(along, half * 2.0, f, 0.14, horiz))
	m.box("window_frame", frame, fc + Vector3.UP * (-H / 2.0 + 0.11) + inward * 0.02, _axes(along, half * 2.0, 0.22, 0.18, horiz))
	# a broad casing on the room face, its jambs meeting the neighbour's over the pier between them
	var face := mid + inward * (T / 2.0 + 0.025)
	var cas := surface("window_frame", trim)
	for side in [-1.0, 1.0]:
		m.box("window_casing", cas, face + along * side * (half + NATURE_PIER / 2.0) + Vector3.UP * (H / 2.0),
			_axes(along, NATURE_PIER + 0.02, H, 0.05, horiz))


## Tile `p` holds a floor-to-ceiling window (the room's full-height glazing).
func _full_glass(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < w and p.y < h and code(p.x, p.y) == MapGen.IWINDOW \
		and map.get("room", {}).get("full_height_windows", false) and not map.get("balcony_doors", {}).has(p)


## A recessed window (the user's direction, 2026-11-15): the glass sits back in the wall at the end of a reveal, a
## deep sill runs out under it into the room, a painted casing frames it, and curtains (living rooms and bedrooms)
## hang from a rod above it, either side of it, never across the glass or the reveal.
func _recessed_window(x: int, y: int, inside: Vector2i) -> void:
	if map.get("room", {}).get("full_height_windows", false):
		_nature_window(x, y, inside)
		return
	var m := _row(y)
	var z := zone(x + inside.x, y + inside.y)
	var horiz := inside.y != 0
	var along := Vector3(absf(float(inside.y)), 0, absf(float(inside.x)))
	var inward := Vector3(inside.x, 0, inside.y)
	var base_y := Elev.surface(map, Vector2i(x, y))
	# Line the whole opening in the frame finish, as with full-height windows. Leaving the reveal in the wall
	# material exposes a strip of wallpaper inside the casing, especially when viewed from the side.
	var frame := _trim_mat()
	_recess(x, y, inside, SILL + base_y, WIN_TOP + base_y, WIN_HALF, WIN_DEPTH, false, frame)
	var c := Vector3(x + 0.5, base_y, y + 0.5)
	var back := c + inward * (T / 2.0 - WIN_DEPTH)
	var mid := (SILL + WIN_TOP) / 2.0
	var tall := WIN_TOP - SILL
	if not _boxed.has(Vector2i(x, y)):
		# Keep a painted view where a real outside box cannot fit; glazing still goes over it.
		m.box("window_pane", _glass(), back + Vector3.UP * mid, _axes(along, WIN_HALF * 2.0, tall, 0.02, horiz))
		var pane := back + inward * 0.012
		var hills := surface("window_hills", Color("#739c87"))
		m.tri("window_hills", hills, [pane - along * WIN_HALF + Vector3.UP * (SILL + 0.02), pane + along * WIN_HALF + Vector3.UP * (SILL + 0.02),
			pane - along * 0.1 + Vector3.UP * (SILL + 0.38)], inward, along, Vector3.UP)
	_clear_pane(x, y, back + inward * 0.018 + Vector3.UP * mid, inside, WIN_HALF * 2.0, tall)
	# the sash: a frame round the glass and its cross bars, just in front of it
	var sash := back + inward * 0.03
	for s in [-1.0, 1.0]:
		m.box("window_frame", frame, sash + along * s * (WIN_HALF - 0.03) + Vector3.UP * mid, _axes(along, 0.06, tall, 0.05, horiz))
		m.box("window_frame", frame, sash + Vector3.UP * (mid + s * (tall / 2.0 - 0.03)), _axes(along, WIN_HALF * 2.0, 0.06, 0.05, horiz))
	m.box("window_frame", frame, sash + Vector3.UP * mid, _axes(along, 0.035, tall, 0.04, horiz))
	m.box("window_frame", frame, sash + Vector3.UP * (mid + 0.1), _axes(along, WIN_HALF * 2.0, 0.035, 0.04, horiz))
	# the deep sill, from the glass out past the casing into the room
	var sill_d := WIN_DEPTH + 0.1
	m.box("window_frame", frame, c + inward * (T / 2.0 - WIN_DEPTH + sill_d / 2.0) + Vector3.UP * (SILL - 0.025),
		_axes(along, WIN_HALF * 2.0 + 0.16, 0.05, sill_d, horiz))
	_casing(x, y, inside, SILL + base_y, WIN_TOP + base_y, WIN_HALF, false)
	if home and rng.randf() < 0.6:
		# a little plant or a bud vase on the sill
		var yaw := atan2(float(inside.x), float(inside.y))
		_stand(["home/plant_succulent", "home/vase_bud", "home/plant_succulent"][rng.randi_range(0, 2)],
			c + inward * (T / 2.0 - 0.08) + along * rng.randf_range(-0.18, 0.18) + Vector3.UP * SILL, yaw)
	if z in ["living", "bedroom"]:
		# windows side by side share one rod, hung by the first of them, with a panel at each outer end
		var step := Vector2i(absi(inside.y), absi(inside.x))
		if code(x - step.x, y - step.y) != MapGen.IWINDOW:
			var n := 1
			while code(x + step.x * n, y + step.y * n) == MapGen.IWINDOW:
				n += 1
			_curtains(x, y, inside, n)


## Curtains for a run of `n` recessed windows from (x, y): a turned rod above their casings and a pleated panel
## either side of the run, never over the glass.
func _curtains(x: int, y: int, inside: Vector2i, n := 1) -> void:
	var step := Vector2i(absi(inside.y), absi(inside.x))
	_by_window[Vector2i(x, y) - step] = true
	_by_window[Vector2i(x, y) + step * n] = true
	var mi := MeshInstance3D.new()
	mi.mesh = _curtain_mesh(WIN_HALF + CASING + (n - 1) * 0.5, WIN_TOP + 0.2, SILL - 0.16)
	var cloth := _sch("fabric") if home else Color(CLOTH[absi(hash(str(map.get("room_key", "")))) % CLOTH.size()])
	mi.material_override = HomeDecor.atlas_material(scheme, {"fabric": "#" + cloth.to_html(false)})
	mi.position = Vector3(x + 0.5, Elev.surface(map, Vector2i(x, y)), y + 0.5) + Vector3(inside.x, 0, inside.y) * (T / 2.0 + 0.07) 		+ Vector3(step.x, 0, step.y) * (n - 1) * 0.5
	mi.rotation.y = atan2(float(inside.x), float(inside.y))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_attach(x, y, mi)


static var _curtain_meshes := {}
## The decor atlas's pleated-cloth and turned-wood cells (assets/interiors/home/ layout; x0, y0, x1, y1).
const PLEAT_UV := [0.1309, 0.0059, 0.2441, 0.1191]
const WOOD_UV := [0.1309, 0.2559, 0.2441, 0.3691]


## Adds a quad (corners in order) facing `n` to `st`, every corner with vertex colour `col` and the uv given.
static func _st_quad(st: SurfaceTool, q: Array, uvs: Array, n: Vector3, col: Color) -> void:
	var e1: Vector3 = (q[1] as Vector3) - q[0]
	var e2: Vector3 = (q[2] as Vector3) - q[0]
	# (Godot's front faces wind clockwise as seen from outside)
	var order := [0, 2, 1, 0, 3, 2] if e1.cross(e2).dot(n) > 0.0 else [0, 1, 2, 0, 2, 3]
	for k in order:
		st.set_color(col)
		st.set_normal(n)
		st.set_uv(uvs[k])
		st.add_vertex(q[k])


## The rod and two pleated panels, facing +z, centred on x = 0, in the decor kit's atlas (the panels tinted by its
## fabric channel, the rod by its wood): the panels hang beside x = +-inner (the casing's outer edge), top to foot.
static func _curtain_mesh(inner: float, top: float, foot: float) -> ArrayMesh:
	var key := "%.3f:%.3f:%.3f" % [inner, top, foot]
	if _curtain_meshes.has(key):
		return _curtain_meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var panel_w := 0.3
	var folds := 6
	var red := Color(1, 0, 0, 0)
	var blue := Color(0, 0, 1, 0)
	for s in [-1.0, 1.0]:
		var x0: float = s * (inner - 0.04)
		var x1: float = s * (inner - 0.04 + panel_w)
		for i in folds * 2:
			var ta := float(i) / float(folds * 2)
			var tb := float(i + 1) / float(folds * 2)
			var za := 0.035 if i % 2 == 0 else 0.0
			var zb := 0.0 if i % 2 == 0 else 0.035
			var xa := lerpf(x0, x1, ta)
			var xb := lerpf(x0, x1, tb)
			# the hem flares out a little
			var flare: float = 0.03 * s
			var q := [Vector3(xa, top, za), Vector3(xb, top, zb), Vector3(xb + flare * tb, foot, zb), Vector3(xa + flare * ta, foot, za)]
			var uvs := [Vector2(lerpf(PLEAT_UV[0], PLEAT_UV[2], ta), PLEAT_UV[1]), Vector2(lerpf(PLEAT_UV[0], PLEAT_UV[2], tb), PLEAT_UV[1]),
				Vector2(lerpf(PLEAT_UV[0], PLEAT_UV[2], tb), PLEAT_UV[3]), Vector2(lerpf(PLEAT_UV[0], PLEAT_UV[2], ta), PLEAT_UV[3])]
			var n: Vector3 = ((q[1] as Vector3) - q[0]).cross((q[3] as Vector3) - q[0]).normalized()
			if n.z < 0.0:
				n = -n
			_st_quad(st, q, uvs, n, red)
			var qb := q.map(func(v): return v + Vector3(0, 0, -0.004))
			_st_quad(st, qb, uvs, -n, red)
	# the rod (a square bar) and a knob on each end
	var half := inner + panel_w + 0.06
	var r := 0.022
	var rod := Vector3(0, top + 0.02, 0.02)
	var mid_uv := Vector2(lerpf(WOOD_UV[0], WOOD_UV[2], 0.5), lerpf(WOOD_UV[1], WOOD_UV[3], 0.5))
	var wood_uvs := [mid_uv, mid_uv, mid_uv, mid_uv]
	for f in [[Vector3.UP, Vector3.BACK], [Vector3.BACK, Vector3.DOWN], [Vector3.DOWN, Vector3.FORWARD], [Vector3.FORWARD, Vector3.UP]]:
		var n2: Vector3 = f[0]
		var side: Vector3 = f[1]
		var o: Vector3 = rod + n2 * r
		_st_quad(st, [o - Vector3(half, 0, 0) - side * r, o + Vector3(half, 0, 0) - side * r, o + Vector3(half, 0, 0) + side * r,
			o - Vector3(half, 0, 0) + side * r], wood_uvs, n2, blue)
	for s in [-1.0, 1.0]:
		var cc: Vector3 = rod + Vector3(s * (half + 0.035), 0, 0)
		var e := 0.04
		for f in [[Vector3.UP, Vector3.RIGHT, Vector3.BACK], [Vector3.DOWN, Vector3.RIGHT, Vector3.BACK], [Vector3.BACK, Vector3.RIGHT, Vector3.UP],
				[Vector3.FORWARD, Vector3.RIGHT, Vector3.UP], [Vector3.RIGHT, Vector3.BACK, Vector3.UP], [Vector3.LEFT, Vector3.BACK, Vector3.UP]]:
			var n3: Vector3 = f[0]
			var u: Vector3 = f[1]
			var v: Vector3 = f[2]
			var o3: Vector3 = cc + n3 * e
			_st_quad(st, [o3 - u * e - v * e, o3 + u * e - v * e, o3 + u * e + v * e, o3 - u * e + v * e], wood_uvs, n3, blue)
	var mesh := st.commit()
	_curtain_meshes[key] = mesh
	return mesh


# ---------------------------------------------------------------- cubbies and closets
## Picks the wall cubbies and closets before the walls are built: closets where the template asks for them
## ("closets": [[x, y, w], ...], a run of back-wall tiles), and in a home a cubby or two on plain stretches of back
## wall with nothing tall before them, away from windows, doors and each other.
func _plan_cubbies() -> void:
	if map.get("puzzle", "") == "maze":
		var tile: Vector2i = preload("res://scripts/data/tide_puzzles.gd").CUBBY_TILE
		_cubbies[tile] = {"inside": Vector2i.DOWN, "kind": "tide"}
	for cl in map.get("room", {}).get("closets", []):
		for i in int(cl[2]):
			_cubbies[Vector2i(int(cl[0]) + i, int(cl[1]))] = {"inside": Vector2i(0, 1), "kind": "closet", "x0": int(cl[0]), "w": int(cl[2])}
	if not home or map.get("room", {}).get("cubbies", -1) == 0:
		return
	var furn: Dictionary = map.get("furniture", {})
	var cands := []
	for y in range(0, h - 2):
		for x in range(2, w - 2):
			if code(x, y) != MapGen.IWALL or zone(x, y + 1) == "":
				continue
			var ok := true
			for dx in [-1, 0, 1]:
				if code(x + dx, y) != MapGen.IWALL or _cubbies.has(Vector2i(x + dx, y)):
					ok = false
			for dx in [-2, 2]:
				if code(x + dx, y) in [MapGen.IWINDOW, MapGen.IDOOR, MapGen.LOCKED] or _cubbies.has(Vector2i(x + dx, y)):
					ok = false
			var front: String = furn.get(Vector2i(x, y + 1), "")
			if front in ["wardrobe", "fridge", "pantry", "storage", "bookshelf", "shelf", "bunk", "coat_stand", "bed", "floor_lamp", "plant"] \
					or code(x, y + 1) in [MapGen.STAIRS_UP, MapGen.STAIRS_DOWN, MapGen.SHELF, MapGen.BOOKSHELF, MapGen.FIREPLACE, MapGen.BED]:
				ok = false
			if ok:
				cands.append(Vector2i(x, y))
	var want := int(map.get("room", {}).get("cubbies", 1 if w < 12 else 2))
	var r := RandomNumberGenerator.new()
	r.seed = pick_seed * 31 + 7
	var placed := 0
	while placed < want and not cands.is_empty():
		var t: Vector2i = cands.pop_at(r.randi_range(0, cands.size() - 1))
		if [-2, -1, 1, 2].any(func(dx): return _cubbies.has(t + Vector2i(dx, 0))):
			continue
		_cubbies[t] = {"inside": Vector2i(0, 1), "kind": "cubby", "x0": t.x, "w": 1}
		placed += 1


## A sealed stone recess using the shared cubby geometry; its panel sinks below the raised walkway.
func _tide_cubby(x: int, y: int) -> void:
	var low := Elev.surface(map, Vector2i(x, y + 1))
	var high := low + 1.55
	_bars(x, y, _foot(x, y), low, true, false, true, true, false, false)
	_bars(x, y, high, H, true, false, true, true, false, false)
	_recess(x, y, Vector2i.DOWN, low, high, 0.46, 0.7, true, _ashlar(stone.darkened(0.32)))
	var box := BoxMesh.new()
	box.size = Vector3(0.92, high - low, 0.12)
	box.material = wall_mat(default_zone)
	tide_panel = MeshInstance3D.new()
	tide_panel.name = "SecretSluicePanel"
	tide_panel.mesh = box
	tide_panel.position = Vector3(x + 0.5, (low + high) / 2.0, y + 0.64)
	tide_panel.visible = not map.get("tide_cubby_open", false)
	parent.add_child(tide_panel)
	tide_cubby_light = OmniLight3D.new()
	tide_cubby_light.position = Vector3(x + 0.5, low + 1.0, y + 1.05)
	tide_cubby_light.light_color = Color("#ffda82")
	tide_cubby_light.light_energy = 2.0 if map.get("tide_cubby_open", false) else 0.0
	tide_cubby_light.omni_range = 3.0
	parent.add_child(tide_cubby_light)


func reveal_tide_cubby() -> void:
	if not is_instance_valid(tide_panel):
		return
	var tw := parent.create_tween()
	tw.tween_property(tide_panel, "position:y", tide_panel.position.y - 1.6, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(tide_cubby_light, "light_energy", 2.0, 1.2)
	await tw.finished
	tide_panel.hide()


## The wall of a cubby's or closet's tile, with its hole, lining and contents (from _walls, for that tile).
func _cubby_wall(x: int, y: int) -> void:
	var cb: Dictionary = _cubbies[Vector2i(x, y)]
	if cb["kind"] == "tide":
		_tide_cubby(x, y)
		return
	var inside: Vector2i = cb["inside"]
	var e := wallish(x + 1, y)
	var wv := wallish(x - 1, y)
	var lining := _trim_mat()
	var c := Vector3(x + 0.5, 0, y + 0.5)
	var inward := Vector3(inside.x, 0, inside.y)
	var yaw := atan2(float(inside.x), float(inside.y))
	if cb["kind"] == "cubby":
		_bars(x, y, _foot(x, y), CUBBY["y0"], true, false, e, wv, false, false)
		_bars(x, y, CUBBY["y1"], H, true, false, e, wv, false, false)
		_recess(x, y, inside, CUBBY["y0"], CUBBY["y1"], CUBBY["half"], CUBBY["depth"], true, lining)
		_casing(x, y, inside, CUBBY["y0"], CUBBY["y1"], CUBBY["half"], true)
		var things: Array = [["home/books_stack", "home/vase_round"], ["home/plant_succulent", "home/candles"], ["home/vase_bud", "home/books_stack"],
			["home/photo_standing", "home/plant_succulent"]][posmod(x * 7 + y + pick_seed, 4)]
		for i in things.size():
			_stand(things[i], c + inward * (T / 2.0 - CUBBY["depth"] * 0.5) + Vector3.RIGHT * (-0.13 + 0.26 * i) + Vector3.UP * CUBBY["y0"], yaw)
		_shelf_door(x, y, 1, CUBBY["half"] * 2.0, CUBBY["y0"], CUBBY["y1"], lining)
		return
	# a closet: the wall above it, and a recess down to the floor across its tiles (the end tiles carry the wall
	# beside the opening and the recess's sides; the first tile the casing round the whole of it)
	var x0: int = cb["x0"]
	var cw: int = cb["w"]
	var y1: float = CLOSET["y1"]
	var depth: float = CLOSET["depth"]
	_bars(x, y, y1, H, true, false, e, wv, false, false)
	var m := _row(y)
	var face := c + inward * T / 2.0
	var back := face - inward * depth
	var lo_x := float(x) + (0.12 if x == x0 else 0.0)
	var hi_x := float(x + 1) - (0.12 if x == x0 + cw - 1 else 0.0)
	var zr := zone(x, y + 1) if zone(x, y + 1) != "" else default_zone
	for f in [[face, inward], [c - inward * T / 2.0, -inward]]:
		var o: Vector3 = f[0]
		if x == x0:
			_face(m, zr, [Vector3(x, 0, o.z), Vector3(lo_x, 0, o.z), Vector3(lo_x, y1, o.z), Vector3(x, y1, o.z)], f[1], Vector3.RIGHT)
		if x == x0 + cw - 1:
			_face(m, zr, [Vector3(hi_x, 0, o.z), Vector3(x + 1, 0, o.z), Vector3(x + 1, y1, o.z), Vector3(hi_x, y1, o.z)], f[1], Vector3.RIGHT)
	if x == x0:
		m.quad("recess", lining, [Vector3(lo_x, 0, face.z), Vector3(lo_x, 0, back.z), Vector3(lo_x, y1, back.z), Vector3(lo_x, y1, face.z)],
			Vector3.RIGHT, Vector3.BACK, Vector3.DOWN, 0.86)
	if x == x0 + cw - 1:
		m.quad("recess", lining, [Vector3(hi_x, 0, face.z), Vector3(hi_x, 0, back.z), Vector3(hi_x, y1, back.z), Vector3(hi_x, y1, face.z)],
			Vector3.LEFT, Vector3.BACK, Vector3.DOWN, 0.86)
	m.quad("recess", lining, [Vector3(lo_x, y1, face.z), Vector3(hi_x, y1, face.z), Vector3(hi_x, y1, back.z), Vector3(lo_x, y1, back.z)],
		Vector3.DOWN, Vector3.RIGHT, Vector3.BACK, 0.8)
	m.quad("recess", lining, [Vector3(lo_x, 0, back.z), Vector3(hi_x, 0, back.z), Vector3(hi_x, y1, back.z), Vector3(lo_x, y1, back.z)],
		inward, Vector3.RIGHT, Vector3.DOWN, 0.82)
	m.quad("recess_floor", lining, [Vector3(lo_x, 0.002, face.z), Vector3(hi_x, 0.002, face.z), Vector3(hi_x, 0.002, back.z),
		Vector3(lo_x, 0.002, back.z)], Vector3.UP, Vector3.RIGHT, Vector3.BACK)
	var shelf := _trim_mat()
	var levels := [0.0, 0.62, 1.12, 1.6]
	for sy in levels.slice(1):
		# (chunky boards, the user's direction: nothing thin)
		m.box("closet_shelf", shelf, Vector3((lo_x + hi_x) / 2.0, sy, (face.z + back.z) / 2.0), Vector3(hi_x - lo_x, SHELF_T, depth))
	if x == x0:
		var mid := float(x0) + cw / 2.0
		var fz := face.z + inward.z * 0.014
		for s in [-1.0, 1.0]:
			m.box("casing", shelf, Vector3(mid + s * (cw / 2.0 - 0.12 + CASING / 2.0), y1 / 2.0, fz), Vector3(CASING, y1, 0.03))
		m.box("casing", shelf, Vector3(mid, y1 + CASING / 2.0, fz), Vector3(cw - 0.24 + CASING * 2.0, CASING, 0.03))
		_shelf_door(x0, y, cw, cw - 0.24, 0.04, y1, shelf)
	# what's kept in it: blankets and books low down, pots and boxes higher up
	var shelf_things := [["home/basket_blankets"], ["kk_book_set"], ["home/books_stack", "home/plant_succulent"], ["box_1"]]
	var mid_z := (face.z + back.z) / 2.0
	for li in levels.size():
		if x == x0 and li == 2 and not shelf_doors[Vector2i(x0, y)].reward.is_empty():
			continue
		var items: Array = shelf_things[(li + x) % shelf_things.size()]
		for i in items.size():
			var ax := lerpf(lo_x + 0.2, hi_x - 0.2, (i + 0.5) / float(items.size()))
			var it := _stand(items[i], Vector3(ax, levels[li] + (SHELF_T / 2.0 if li > 0 else 0.0) + 0.002, mid_z), yaw)
			if it != null:
				var bb := it.mesh.get_aabb()
				var fit := minf(1.0, minf((hi_x - lo_x - 0.12) / maxf(bb.size.x, 0.01), (depth - 0.06) / maxf(bb.size.z, 0.01)))
				fit = minf(fit, 0.44 / maxf(bb.size.y, 0.01))
				it.scale = Vector3.ONE * fit


## The wood framing a shelf's sliding glass: the room's furniture wood, set apart from the wall as picture frames are
## (_frame_wood), on the floor boards' grain.
func _glass_frame_wood() -> Material:
	var base := surface("floor_wood", Color.WHITE)
	var toned := _wood_tone(base.albedo_texture, _frame_wood()) if base.albedo_texture != null else null
	if toned == null:
		return surface("floor_wood", _frame_wood().lightened(0.3))
	var m := (toned as ShaderMaterial).duplicate() as ShaderMaterial
	m.set_shader_parameter("uv_scale", Vector2(base.uv1_scale.x, base.uv1_scale.y))
	return m


## Keep glazing separate from the static wall batches, so only its leaf moves. Its rails and the leaf's frame are wood.
func _shelf_door(x: int, y: int, columns: int, width: float, bottom: float, top: float, wood: Material) -> void:
	var door := preload("res://scripts/gfx/shelf_door.gd").new()
	parent.add_child(door)
	var glass := _glass().duplicate() as StandardMaterial3D
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color.a = 0.24
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	door.setup(Vector3(x + columns / 2.0, 0, y + 0.5 + T / 2.0 + 0.045), width, bottom, top, wood, glass)
	for dx in columns:
		var tile := Vector2i(x + dx, y)
		door.tiles.append(tile)
		shelf_doors[tile] = door
	# Stable, modest finds; revisiting never rerolls a shelf. Authors can override or disable a find.
	var tile := Vector2i(x, y)
	var item := String(map.get("room", {}).get("shelf_items", {}).get(tile,
		"minor_potion" if posmod(pick_seed + x * 7 + y * 13, 4) == 0 else ""))
	if item != "":
		var room_id := "%s@%s" % [map.get("building", {}).get("interior", map.get("parent", "")), map.get("floor_num", 1)]
		var flag := "shelf:%s:%d:%d" % [room_id, x, y]
		door.stock(item, flag, tile, piece("bottle"), surface("window_frame", Color("#d7ab58")), 1.12 + SHELF_T / 2.0 + 0.002 if top > 2.0 else bottom)


# ---------------------------------------------------------------- platforms
## A room's platforms as "heights" rows (elevation.gd): their tiles at level 1, their steps ramps rising onto them.
static func dais_heights(room: Dictionary, w: int, h: int) -> Array:
	var grid := []
	for y in h:
		var row := []
		row.resize(w)
		row.fill("0")
		grid.append(row)
	for d in room.get("dais", []):
		var r := _dais_rect(d)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if x >= 0 and y >= 0 and x < w and y < h:
					grid[y][x] = "1"
		for st in d.get("steps", []):
			var t := Vector2i(int(st[0]), int(st[1]))
			# the way up: into the platform. Steps are inset (the user's direction, 2026-11-15): a step tile on the
			# platform's edge is cut into it, rising from the open floor beside it; one just outside rises onto it
			# (a step that could rise two ways climbs east or west, so its treads lie along the floor's boards, which
			# run north-south: the user's rule, 2026-11-15)
			var dir := Vector2i.ZERO
			# (a step may name its way up, "^" "v" "<" ">", where the open floor is on one side only: the hotel spa's
			# corner step beside the pool climbs north from the floor, not west out of the water)
			var named := {"^": Vector2i(0, -1), "v": Vector2i(0, 1), "<": Vector2i(-1, 0), ">": Vector2i(1, 0)}
			for q in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
				if st.size() > 2:
					dir = named.get(str(st[2]), Vector2i.ZERO)
					break
				if r.has_point(t) and r.has_point(t + q) and not r.has_point(t - q):
					dir = q
				elif not r.has_point(t) and r.has_point(t + q):
					dir = q
			grid[t.y][t.x] = {Vector2i(0, -1): "^", Vector2i(0, 1): "v", Vector2i(-1, 0): "<", Vector2i(1, 0): ">"}.get(dir, "0")
	return grid.map(func(row): return "".join(row))


static func _dais_rect(d) -> Rect2i:
	var r: Array = d["rect"] if d is Dictionary else d
	return Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))


## How high a platform raises tile `t` (0 off them, the middle of a step on one).
static func dais_at(m: Dictionary, t: Vector2i) -> float:
	if not m.get("room", {}).has("dais"):
		return 0.0
	return Elev.surface(m, t)


## Every indoor platform shares the lobby's continuous bevelled wooden balustrade.
func _daises() -> void:
	var wood := _rail_mat()
	for d in map.get("room", {}).get("dais", []):
		var r := _dais_rect(d)
		var steps := {}
		for st in d.get("steps", []):
			steps[Vector2i(int(st[0]), int(st[1]))] = true
		var edges := {}
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var t := Vector2i(x, y)
				if steps.has(t):
					continue
				for q in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
					var o: Vector2i = t + q
					if r.has_point(o) or steps.has(o) or not code(o.x, o.y) in [MapGen.IFLOOR, MapGen.ITILE, MapGen.RUG, MapGen.MAT, MapGen.FURN]:
						continue
					var key := Vector3i(q.x, q.y, x if q.x != 0 else y)
					if not edges.has(key):
						edges[key] = []
					edges[key].append(y if q.x != 0 else x)
		for key: Vector3i in edges:
			var spans: Array = edges[key]
			spans.sort()
			var first := int(spans[0])
			var last := first
			for i in range(1, spans.size() + 1):
				if i < spans.size() and int(spans[i]) == last + 1:
					last = int(spans[i])
					continue
				var fixed := float(key.z) + 0.5 + float(key.x if key.x != 0 else key.y) * 0.42
				# (a run that ends beside a wall carries on into the wall's face, so no gap shows between them)
				var before := Vector2i(key.z, first - 1) if key.x != 0 else Vector2i(first - 1, key.z)
				var after := Vector2i(key.z, last + 1) if key.x != 0 else Vector2i(last + 1, key.z)
				var start := float(first) - (0.5 - T / 2.0 if code(before.x, before.y) in WALLISH else 0.0)
				var end := float(last + 1) + (0.5 - T / 2.0 if code(after.x, after.y) in WALLISH else 0.0)
				var a := Vector3(fixed, DAIS_H, start) if key.x != 0 else Vector3(start, DAIS_H, fixed)
				var b := Vector3(fixed, DAIS_H, end) if key.x != 0 else Vector3(end, DAIS_H, fixed)
				_indoor_railing(a, b, wood)
				if i < spans.size():
					first = int(spans[i])
					last = first


## The warm wood of platforms' railings, steps and sides.
func _rail_mat() -> Material:
	var room: Dictionary = map.get("room", {})
	if room.has("wood"):
		# (recoloured exactly as the room's furniture is, so they match)
		var base := surface("floor_wood", Color.WHITE)
		var toned := _wood_tone(base.albedo_texture, Color(str(room["wood"]))) if base.albedo_texture != null else null
		if toned != null:
			var m := (toned as ShaderMaterial).duplicate() as ShaderMaterial
			m.set_shader_parameter("uv_scale", Vector2(base.uv1_scale.x, base.uv1_scale.y))
			return m
	return surface("floor_wood", Color(str(room.get("wood", "#b07a4c"))))


# ---------------------------------------------------------------- one wood for a room
## A room whose template names a "wood" (the cafe: the user's direction, 2026-11-15, all its wood one colour except
## the floor) has every wooden piece's wood tones recoloured to it (wood_tone.gdshader): tables, stools, counters,
## shelves and cabinets; railings and frames take it directly (_rail_mat, _hang_frame).
const WOOD_PIECES := ["kk_table", "kk_stool", "kk_chair", "kk_shelf", "kk_cabinet", "kk_drawers", "kaykit_stool_bench",
	"interiors/counter.res", "interiors/shelves.res", "interiors/el_display.res"]
const WOOD_SHADER := preload("res://scripts/gfx/wood_tone.gdshader")
static var _wood_refs := {}


func _one_wood(node: Node) -> void:
	var wood := Color(str(map["room"]["wood"]))
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		if mesh == null or not WOOD_PIECES.any(func(k): return k in mesh.resource_path):
			continue
		for i in mesh.get_surface_count():
			if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_name(i) == "fabric":
				continue
			var mat = mi.get_surface_override_material(i)
			if mat == null:
				mat = mesh.surface_get_material(i)
			if mat is StandardMaterial3D and mat.albedo_texture != null:
				var toned := _wood_tone(mat.albedo_texture, wood)
				if toned != null:
					mi.set_surface_override_material(i, toned)


## A texture recoloured to `wood` (cached), or null if it has no wood in it.
static func _wood_tone(tex: Texture2D, wood: Color) -> Material:
	var key := "wood:%s:%s" % [tex.get_rid().get_id(), wood.to_html()]
	if _mats.has(key):
		return _mats[key]
	if not _wood_refs.has(tex):
		_wood_refs[tex] = _wood_ref(tex)
	var ref: float = _wood_refs[tex]
	var m: ShaderMaterial = null
	if ref > 0.0:
		m = ShaderMaterial.new()
		m.shader = WOOD_SHADER
		m.set_shader_parameter("albedo_tex", tex)
		m.set_shader_parameter("wood", wood)
		m.set_shader_parameter("ref", ref)
	_mats[key] = m
	return m


## The usual (linear) brightness of a texture's wood tones, by the shader's own measure; 0 if it has none.
static func _wood_ref(tex: Texture2D) -> float:
	var img := tex.get_image()
	if img == null:
		return 0.0
	if img.is_compressed():
		img.decompress()
	var step := maxi(1, int(sqrt(img.get_width() * img.get_height() / 4096.0)))
	var sum := 0.0
	var wsum := 0.0
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			var c := img.get_pixel(x, y).srgb_to_linear()
			var hh := c.h
			var wt := smoothstep(0.005, 0.03, hh) * (1.0 - smoothstep(0.12, 0.16, hh)) * smoothstep(0.25, 0.4, c.s) * smoothstep(0.01, 0.03, c.v)
			sum += wt * (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b)
			wsum += wt
	return sum / wsum if wsum > 1.0 else 0.0


# ---------------------------------------------------------------- dressing a home
## Cushions, throws and quilts on a home's seats and beds (mi: the piece as placed, its box bb at scale sc).
func _dress(kind: String, mi: MeshInstance3D, bb: AABB, sc: Vector3) -> Array:
	var out := []
	var yaw := mi.rotation.y
	var basis := Basis(Vector3.UP, yaw)
	var wdt := bb.size.x * sc.x
	var dep := bb.size.z * sc.z
	var hgt := bb.size.y * sc.y
	var at := mi.position
	match kind:
		"sofa":
			for s in [-1.0, 1.0]:
				out.append(_stand("home/cushion_square", at + basis * Vector3(s * wdt * 0.22, hgt * 0.48, -dep * 0.14), yaw))
			out.append(_stand("home/throw_blanket", at + basis * Vector3(wdt * 0.4, hgt * 0.74, 0.0), yaw))
		"armchair":
			out.append(_stand("home/cushion_square", at + basis * Vector3(0, hgt * 0.48, -dep * 0.14), yaw))
		"bed":
			# a patchwork quilt across the foot of the bed, lying on the covers (the mattress's top and sides measured
			# from the bed's own mesh, not guessed from its height, which counts the headboard) and hanging down both
			# sides of the bed most of the way to its frame, its fold rolled along the edge nearest the pillow
			var z := bb.size.z * 0.3
			var top := _surface_top(mi.mesh, bb.get_center().x, z - 0.2, z + 0.2, bb.size.x * 0.35)
			var half := _surface_side(mi.mesh, top * 0.7, z, bb)
			var q := MeshInstance3D.new()
			q.mesh = draped_quilt(half * sc.x, top * sc.y * 0.6, 0.6 * sc.z)
			q.material_override = HomeDecor.atlas_material(scheme)
			q.position = at + basis * Vector3(0, top * sc.y, z * sc.z)
			q.rotation.y = yaw
			q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(q)
			out.append(q)
	return out.filter(func(n): return n != null)


## How far out from its middle a mesh's side stands at height y and depth z (in its own units): a bed's mattress.
static func _surface_side(mesh: Mesh, y: float, z: float, bb: AABB) -> float:
	var key := "side:%s:%.2f:%.2f" % [mesh.get_rid().get_id(), y, z]
	if _tops.has(key):
		return _tops[key]
	var tm := mesh.generate_triangle_mesh()
	var side := bb.size.x * 0.5
	var hit := tm.intersect_ray(Vector3(bb.end.x + 1.0, y, z), Vector3.LEFT)
	if not hit.is_empty():
		side = float(hit["position"].x) - bb.get_center().x
	_tops[key] = side
	return side


## A patchwork quilt draped over a bed (half: the mattress's half-width, drop: how far it hangs down each side,
## depth: along the bed), as one soft sweep: its top on y = 0 across the mattress, rounding over the edges and down
## both sides, a little flared at the hem, with rounded hems front and back and a rolled fold along the back (-z).
## Built in the home decor atlas's patchwork cell, fabric-tinted (vertex colour red), so it takes the room's scheme.
static var _quilts := {}
const QUILT_CELL := Rect2(0.758, 0.009, 0.109, 0.107)
static func draped_quilt(half: float, drop: float, depth: float) -> ArrayMesh:
	var key := "%.3f:%.3f:%.3f" % [half, drop, depth]
	if _quilts.has(key):
		return _quilts[key]
	const TH := 0.045  # the cloth's thickness
	const R := 0.07  # how round it falls over the mattress's edges
	const FLARE := 0.03  # how far the hem stands out from the bed's side
	var hx := half + TH * 0.5 + 0.012
	var y0 := TH * 0.5 + 0.003
	# the cloth's middle line across the bed, from the left hem up, over and down to the right hem
	var path: Array[Vector2] = []
	var hang := maxf(drop - R, 0.02)
	for i in 6:
		var t := 1.0 - i / 6.0
		path.append(Vector2(-hx - FLARE * t * t, y0 - R - hang * t))
	for i in 7:
		var a := PI - (PI * 0.5) * i / 6.0
		path.append(Vector2(-hx + R + R * cos(a), y0 - R + R * sin(a)))
	for i in range(1, 8):
		path.append(Vector2(lerpf(-hx + R, hx - R, i / 8.0), y0))
	for i in 7:
		var a := PI * 0.5 - (PI * 0.5) * i / 6.0
		path.append(Vector2(hx - R + R * cos(a), y0 - R + R * sin(a)))
	for i in range(1, 7):
		var t := i / 6.0
		path.append(Vector2(hx + FLARE * t * t, y0 - R - hang * t))
	# a round cross-section along the bed, as (out, z, normal out, normal z): the slab with rounded hems
	var slab := []
	var hz := depth * 0.5 - TH * 0.5
	for i in 9:
		var a := -PI * 0.5 + PI * i / 8.0
		slab.append([TH * 0.5 * sin(a), hz + TH * 0.5 * cos(a), sin(a), cos(a)])
	for i in 9:
		var a := PI * 0.5 + PI * i / 8.0
		slab.append([TH * 0.5 * sin(a), -hz + TH * 0.5 * cos(a), sin(a), cos(a)])
	var roll := []
	var rr := 0.05
	for i in 13:
		var a := TAU * i / 12.0
		roll.append([TH * 0.5 + rr * 0.55 + rr * sin(a), -depth * 0.5 + rr + rr * cos(a), sin(a), cos(a)])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_sweep(st, path, slab, true, depth)
	_sweep(st, path, roll, true, depth)
	st.generate_tangents()
	var mesh := st.commit()
	_quilts[key] = mesh
	return mesh


## A loop (rows of out, z, normal out, normal z, closed) swept along a path across the bed, as quads; the open ends
## at the hems capped flat when `cap`.
static func _sweep(st: SurfaceTool, path: Array[Vector2], loop: Array, cap: bool, depth: float) -> void:
	var lens := [0.0]
	for i in range(1, path.size()):
		lens.append(lens[i - 1] + path[i].distance_to(path[i - 1]))
	var total: float = lens[-1]
	var ups := []
	for i in path.size():
		var t := (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		ups.append(Vector2(-t.y, t.x))
	var vert := func(i: int, k: int) -> Array:
		var n: Vector2 = ups[i]
		var l: Array = loop[k]
		var o: float = l[0]
		var p := Vector3(path[i].x + n.x * o, path[i].y + n.y * o, float(l[1]))
		var nn: Vector3 = (Vector3(n.x, n.y, 0) * float(l[2]) + Vector3(0, 0, float(l[3]))).normalized()
		var uv: Vector2 = QUILT_CELL.position + Vector2(float(lens[i]) / total * QUILT_CELL.size.x, (l[1] / depth + 0.5) * QUILT_CELL.size.x * depth / total)
		return [p, nn, uv]
	var put := func(v: Array) -> void:
		st.set_color(Color(1, 0, 0, 0))
		st.set_normal(v[1])
		st.set_uv(v[2])
		st.add_vertex(v[0])
	for i in path.size() - 1:
		for k in loop.size():
			var k2 := (k + 1) % loop.size()
			var a: Array = vert.call(i, k)
			var b: Array = vert.call(i + 1, k)
			var c: Array = vert.call(i + 1, k2)
			var d: Array = vert.call(i, k2)
			for v in [a, d, c, a, c, b]:
				put.call(v)
	if not cap:
		return
	for end in [0, path.size() - 1]:
		var n3 := Vector3((path[1] - path[0]).x, (path[1] - path[0]).y, 0).normalized() * -1.0 if end == 0 else Vector3((path[end] - path[end - 1]).x, (path[end] - path[end - 1]).y, 0).normalized()
		var mid := Vector3(path[end].x, path[end].y, 0)
		for k in loop.size():
			var a: Array = vert.call(end, k)
			var b: Array = vert.call(end, (k + 1) % loop.size())
			var tri := [mid, a[0], b[0]] if end == 0 else [mid, b[0], a[0]]
			for p in tri:
				put.call([p, n3, a[2]])


## The highest point of `mesh`'s top surface (in its own units) under a patch around (x, z0..z1), x ± half: what
## something laid on it rests on. Cached per mesh and patch.
static var _tops := {}
static func _surface_top(mesh: Mesh, x: float, z0: float, z1: float, half: float) -> float:
	var key := "%s:%.2f:%.2f:%.2f:%.2f" % [mesh.get_rid().get_id(), x, z0, z1, half]
	if _tops.has(key):
		return _tops[key]
	var tm := mesh.generate_triangle_mesh()
	var top := 0.0
	for i in 5:
		for j in 3:
			var p := Vector3(x + half * (i / 2.0 - 1.0), mesh.get_aabb().end.y + 1.0, lerpf(z0, z1, j / 2.0))
			var hit := tm.intersect_ray(p, Vector3.DOWN)
			if not hit.is_empty():
				top = maxf(top, float(hit["position"].y))
	_tops[key] = top
	return top


## A home's walls, dressed generously (the user's direction: shelves, paintings and the like): a big framed print
## centred over each bed and sofa against a back wall (the rocket over the bed in the player's own room), a mirror
## over a dresser, a dressed shelf over a desk, and on the other plain stretches of back wall a lone large print where
## three tiles are free, gallery pairs, clocks, dressed shelves and hanging plants; the side walls, seen at an angle,
## get flatter pieces. Paintings are boxy prints in thick frames (HomeDecor.framed_print); shelves are KayKit's chunky
## ones with a varied handful of things on them (_dressed_shelf). Nothing goes over a window's curtains, a cubby, or
## behind anything tall.
func _home_wall_decor() -> void:
	var furn: Dictionary = map.get("furniture", {})
	var hung := {}
	var mine := String(map.get("room_key", "")) == "home_bed"
	var up := Vector2i(0, 1)
	for part in furniture_groups(map):
		var kind: String = part["kind"]
		if not kind in ["bed", "sofa", "bunk"]:
			continue
		var layout := furniture_layout(map, kind, part["tiles"])
		if layout["back"] != Vector2i(0, -1) or not layout["against"]:
			continue
		var lo: Vector2i = layout["lo"]
		var size: Vector2 = layout["size"]
		var cx := lo.x + size.x / 2.0
		var tx := int(floor(cx))
		var ty := lo.y - 1
		if not [tx - 1, tx, tx + 1].all(func(q): return code(q, ty) == MapGen.IWALL and not _cubbies.has(Vector2i(q, ty)) and not _by_window.has(Vector2i(q, ty))):
			continue
		var side := cx - (tx + 0.5)
		if kind == "bunk":
			_hang_decor("bunting", tx, ty, up, 2.25, side)
		elif mine and kind == "bed":
			_hang_frame(tx, ty, up, 1.8, side, 0.66, 0.86, HomeDecor.ROCKET)
		elif kind == "bed":
			if size.x >= 2.0:
				_hang_frame(tx, ty, up, 1.75, side, 1.2, 0.84)
				_hang_decor("wall_sconce", tx, ty, up, 1.55, side - size.x / 2.0 - 0.18)
				_hang_decor("wall_sconce", tx, ty, up, 1.55, side + size.x / 2.0 + 0.18)
			else:
				_hang_frame(tx, ty, up, 1.75, side, 0.62, 0.8)
		else:
			_hang_frame(tx, ty, up, 1.72, side, 1.2, 0.84)
			_hang_frame(tx, ty, up, 1.76, side - 0.98, 0.42, 0.54)
			_hang_frame(tx, ty, up, 1.76, side + 0.98, 0.42, 0.54)
		for q in [tx - 1, tx, tx + 1]:
			hung[Vector2i(q, ty)] = true
	var r := RandomNumberGenerator.new()
	r.seed = pick_seed * 13 + 5
	var low_front := ["", "sofa", "armchair", "dresser", "cabinet", "basket", "pouf", "chair", "table", "coffee_table"]
	for y in range(0, h - 1):
		for x in range(0, w):
			if code(x, y) != MapGen.IWALL or hung.has(Vector2i(x, y)) or _cubbies.has(Vector2i(x, y)) or _by_window.has(Vector2i(x, y)):
				continue
			for inside in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
				var t: Vector2i = Vector2i(x, y) + inside
				if zone(t.x, t.y) == "":
					continue
				var along := Vector2i(inside.y, inside.x)
				if not (wallish(x + along.x, y + along.y) and wallish(x - along.x, y - along.y)):
					continue
				# (back walls are dressed tile by tile; the side walls, seen at an angle, every other tile)
				if inside.y != 1 and (hung.has(Vector2i(x, y) + along) or hung.has(Vector2i(x, y) - along)):
					continue
				var front_kind: String = furn.get(t, "")
				var c := code(t.x, t.y)
				if c in [MapGen.SHELF, MapGen.BOOKSHELF, MapGen.BOARD, MapGen.TERMINAL, MapGen.FIREPLACE, MapGen.COUNTER, MapGen.STAIRS_UP,
						MapGen.STAIRS_DOWN] or front_kind in ["fridge", "wardrobe", "pantry", "storage", "bookshelf", "shelf", "bunk",
						"floor_lamp", "plant"]:
					continue
				var got: Node3D = null
				var roll := r.randf()
				if inside.y == 1:
					match front_kind:
						"dresser", "cabinet":
							got = _hang_decor("mirror_arch", x, y, inside, 1.55, 0.0) if roll < 0.4 else _dressed_shelf(x, y, inside, 1.32, 0.0, false)
						"desk", "computer":
							got = _dressed_shelf(x, y, inside, 1.45, 0.0, false)
						"counter", "kitchen_sink", "stove":
							got = _dressed_shelf(x, y, inside, 1.5, 0.0, false) if roll < 0.6 else _hang_decor("plant_hanging", x, y, inside, 2.1, 0.0)
						"basin":
							got = _hang_decor("mirror_arch", x, y, inside, 1.5, 0.0)
						_:
							# three free tiles in a row: now and then a large print that holds the wall on its own, or a
							# long dressed shelf over two of them
							var run3 := true
							for dx in [1, 2]:
								var q := Vector2i(x + dx, y)
								if code(q.x, q.y) != MapGen.IWALL or _cubbies.has(q) or _by_window.has(q) or hung.has(q) \
										or not furn.get(q + inside, "") in low_front or code(q.x, q.y + 1) in [MapGen.STAIRS_UP, MapGen.STAIRS_DOWN]:
									run3 = false
							if run3 and roll < 0.45:
								if roll < 0.3:
									var tall := r.randf() < 0.35
									got = _hang_frame(x, y, inside, 1.62, 1.0, 0.95 if tall else 1.55, 1.2 if tall else 1.05)
									for dx in [0, 1, 2]:
										hung[Vector2i(x + dx, y)] = true
								else:
									got = _dressed_shelf(x, y, inside, 1.3, 0.5, true)
									hung[Vector2i(x + 1, y)] = true
								hung[Vector2i(x, y)] = true
								break
							roll = r.randf()
							if hung.has(Vector2i(x - 1, y)) and hung.has(Vector2i(x - 2, y)) and roll > 0.9:
								# (now and then a gap, so the wall breathes)
								break
							if roll < 0.26:
								_hang_frame(x, y, inside, 1.62, -0.17, 0.44, 0.58)
								got = _hang_frame(x, y, inside, 1.7, 0.25, 0.32, 0.42)
							elif roll < 0.4 and not _clock_hung:
								got = _hang_decor("wall_clock", x, y, inside, 1.85, 0.0)
								_clock_hung = _mark_clock(got)
							elif roll < 0.6:
								got = _dressed_shelf(x, y, inside, 1.3, 0.0, false)
							elif roll < 0.74:
								got = _hang_frame(x, y, inside, 1.62, 0.0, 0.6, 0.6)
							elif roll < 0.86:
								got = _hang_decor("plant_hanging", x, y, inside, 2.1, 0.0)
							else:
								got = _hang_decor("tapestry", x, y, inside, 1.85, 0.0)
				elif roll < 0.8:
					var pick: String = ["woven_plate", "frame_s", "wall_sconce", "frame_sq", "frame_p", "plant_hanging"][r.randi_range(0, 5)]
					match pick:
						"frame_s":
							got = _hang_frame(x, y, inside, 1.62, 0.0, 0.34, 0.44)
						"frame_sq":
							got = _hang_frame(x, y, inside, 1.62, 0.0, 0.5, 0.5)
						"frame_p":
							got = _hang_frame(x, y, inside, 1.62, 0.0, 0.48, 0.64)
						_:
							got = _hang_decor(pick, x, y, inside, {"wall_sconce": 1.6, "plant_hanging": 2.1}.get(pick, 1.62), 0.0)
				if got != null:
					hung[Vector2i(x, y)] = true
				break


## A boxy framed print fw x fh hung on wall tile (x, y) facing `inside`, its middle `up` high and `side` along; a new
## print each time unless one is given. Every frame is the room's furniture wood (_frame_wood), never the floor's,
## the wall's or the trim's colour (the user's rule, 2026-11-15).
func _hang_frame(x: int, y: int, inside: Vector2i, up: float, side: float, fw: float, fh: float, print_id := "") -> MeshInstance3D:
	var over := {"wood": _frame_wood().to_html(false)}
	var mi := HomeDecor.framed_print(fw, fh, print_id if print_id != "" else _next_print(), scheme, _colourway(), false, over)
	var yaw := atan2(float(inside.x), float(inside.y))
	mi.position = Vector3(x + 0.5, up, y + 0.5) + Vector3(inside.x, 0, inside.y) * (T / 2.0 + 0.004) \
		+ Basis(Vector3.UP, yaw) * Vector3(side, 0, 0)
	mi.rotation.y = yaw
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_attach(x, y, mi)
	return mi


## KayKit Furniture Bits' own warm brown wood (the middle of furniture.png's wood swatch).
const KAYKIT_WOOD := Color("#a3624a")
## How far apart in luminance a picture frame and its wall must be, so the frame stands out from the paint.
const FRAME_CONTRAST := 0.28


## A picture frame's wood: the room's furniture wood (its template's "wood", else KayKit's), never the floor's. Where
## that is too near the wall's paint it is deepened (on a pale wall) or lightened (on a dark one) until it contrasts.
func _frame_wood() -> Color:
	var room: Dictionary = map.get("room", {})
	var wood := Color(str(room["wood"])) if room.has("wood") else KAYKIT_WOOD
	if not home:
		return wood
	var wl := _sch("wall").get_luminance()
	for i in 6:
		if absf(wood.get_luminance() - wl) >= FRAME_CONTRAST:
			break
		wood = wood.darkened(0.2) if wl >= 0.45 else wood.lightened(0.2)
	return wood


## Things that can stand on a dressed shelf (the user's direction: plenty of variety).
const SHELF_THINGS := ["home/books_stack", "kk_book_set", "home/vase_round", "home/vase_bud", "home/plant_succulent",
	"home/candles", "home/photo_standing", "teddy", "home/bowl_fruit", "home/tea_set", "kk_pillow_A", "books", "globe",
	"kk_cactus_small_A", "kk_cactus_small_B", "home/vase_flowers", "box_1"]


## One of KayKit's chunky wall shelves (the long one over two tiles, else the short one), hung on wall tile (x, y)
## `up` high and `side` along, with a few things on it picked from SHELF_THINGS so no two shelves look alike.
func _dressed_shelf(x: int, y: int, inside: Vector2i, up: float, side: float, long: bool) -> MeshInstance3D:
	var base := _hang("kk_shelf_bare_large" if long else "kk_shelf_bare_small", x, y, inside, up, side)
	if base == null:
		return null
	tint_fabric(base, _sch("fabric"))
	var bb := base.mesh.get_aabb()
	var yaw := base.rotation.y
	var basis := Basis(Vector3.UP, yaw)
	# the board's top, between its two end blocks
	var inner := bb.size.x / 2.0 - 0.12
	var top := bb.size.y * 0.42
	var rr := RandomNumberGenerator.new()
	rr.seed = hash(Vector3i(x, y, pick_seed))
	var pool: Array = SHELF_THINGS.duplicate()
	var n := rr.randi_range(2, 4) if long else rr.randi_range(1, 2)
	for i in n:
		var at := lerpf(-inner, inner, (i + 0.5) / float(n))
		var name: String = pool.pop_at(rr.randi_range(0, pool.size() - 1))
		var mesh := piece(name)
		if mesh == null:
			continue
		var mb := mesh.get_aabb()
		# it fits its share of the board, the shelf's depth, and stays small
		var fit := minf(1.0, minf((inner * 2.0 / n) / maxf(mb.size.x, 0.01), (bb.size.z * 0.9) / maxf(mb.size.z, 0.01)))
		fit = minf(fit, 0.42 / maxf(mb.size.y, 0.01))
		var it := _stand(name, base.position + basis * Vector3(at + rr.randf_range(-0.03, 0.03), 0, 0) + Vector3(0, top, 0),
			yaw + rr.randf_range(-0.25, 0.25), fit)
		if it != null:
			tint_fabric(it, Color(CLOTH[rr.randi_range(0, CLOTH.size() - 1)]))
	return base


## A closed pair of staff-only wooden leaves; its fixture tiles supply the movement barrier.
func _counter_gate(group: Array) -> void:
	var layout := furniture_layout(map, "counter_gate", group)
	var lo: Vector2i = layout["lo"]
	var size: Vector2 = layout["size"]
	var c := Vector3(lo.x + size.x * 0.5, 0, lo.y + size.y * 0.5)
	var wood := _rail_mat()
	var panel := surface("floor_wood", MISSION_WOOD.lightened(0.12))
	var iron := surface("wall_plaster", Color("#554534"))
	var top := DESK_TOP - 0.14
	# The hotel has two-tile north/south passages. Single-tile gates beside
	# a side wall (or behind a desk) close east/west gaps instead.
	var across := size.x > size.y or (size == Vector2.ONE and not wallish(lo.x, lo.y - 1) and not wallish(lo.x, lo.y + 1))
	var turn := Basis(Vector3.UP, PI / 2.0 if across else 0.0)
	var span := (size.x if across else size.y) - 0.12
	for side in [-1.0, 1.0]:
		var z: float = side * span * 0.25
		var leaf := Vector3(0.14, top - 0.12, span * 0.5 - 0.025)
		floor_mesher.box("counter_gate_wood", wood, c + turn * Vector3(0, (top + 0.12) * 0.5, z), leaf if not across else Vector3(leaf.z, leaf.y, leaf.x))
		for face in [-1.0, 1.0]:
			var inset := Vector3(0.018, 0.4, span * 0.5 - 0.22)
			floor_mesher.box("counter_gate_panel", panel, c + turn * Vector3(face * 0.076, 0.48, z), inset if not across else Vector3(inset.z, inset.y, inset.x))
		_beam("counter_gate_cap", wood, c + turn * Vector3(0, top - 0.04, z - span * 0.25 + 0.02), c + turn * Vector3(0, top - 0.04, z + span * 0.25 - 0.02), 0.095, true)
		for y in [0.28, 0.68]:
			floor_mesher.box("counter_gate_hinge", iron, c + turn * Vector3(0.08, y, side * (span * 0.5 - 0.09)), Vector3(0.16, 0.1, 0.04) if across else Vector3(0.04, 0.1, 0.16))


## Guests' cases, neatly stacked against the back wall (the user's 2026-11-15 direction): chunky painted suitcases,
## biggest at the bottom and squared up, each with a darker strap and a handle, in a few travel colours.
const LUGGAGE_COLOURS := ["#a8693f", "#3f8a8c", "#d9a441", "#8c3b3b", "#3b4f7a", "#e3d3b4"]
## [width, height, depth] of each case from the bottom up; a tile picks one of these stacks
const LUGGAGE_STACKS := [
	[[0.84, 0.3, 0.58], [0.7, 0.26, 0.5], [0.52, 0.22, 0.4]],
	[[0.8, 0.32, 0.6], [0.62, 0.28, 0.48]],
	[[0.86, 0.28, 0.56], [0.74, 0.26, 0.5], [0.6, 0.24, 0.44], [0.44, 0.2, 0.34]],
]


func _luggage_stack(x: int, y: int) -> void:
	var strap := surface("wall_plaster", Color("#4a2c1a"))
	var stack: Array = LUGGAGE_STACKS[absi(x * 7 + y * 3) % LUGGAGE_STACKS.size()]
	# against the wall behind the tile (the balcony wall's face for the lobby)
	var back := float(y) + T / 2.0 + 0.04
	var base := 0.0
	for i in stack.size():
		var size := Vector3(stack[i][0], stack[i][1], stack[i][2])
		var colour := Color(LUGGAGE_COLOURS[absi(x * 5 + i * 2 + y) % LUGGAGE_COLOURS.size()])
		var c := Vector3(float(x) + 0.5, base + size.y * 0.5, back + size.z * 0.5)
		floor_mesher.box("luggage_" + colour.to_html(), surface("wall_plaster", colour), c, size)
		# two straps round the case, a little proud of it, and a handle on the front face
		for side in [-0.27, 0.27]:
			floor_mesher.box("luggage_strap", strap, c + Vector3(size.x * side, 0, 0), Vector3(0.07, size.y + 0.02, size.z + 0.02))
		floor_mesher.box("luggage_strap", strap, c + Vector3(0, 0, size.z * 0.5 + 0.02), Vector3(0.2, 0.06, 0.05))
		base += size.y

## Hotel fixtures share the room's painted, texture-sampling surfaces.
func _hotel_details() -> void:
	var room: Dictionary = map.get("room", {})
	if not String(map.get("room_key", "")).begins_with("hotel_"):
		return
	# Larger framed prints use the shared art builder, with authored spans clear of doors and windows.
	for art in room.get("paintings", []):
		_hang_frame(int(art[0]), int(art[1]), Vector2i(int(art[2]), int(art[3])),
			float(art[4]), float(art[5]), float(art[6]), float(art[7]))
	var ivory := surface("wall_plaster", Color("#eee3cd"))
	var dark := surface("wall_plaster", Color("#414951"))
	var tile := surface("floor_tiles", Color("#a3c8c2"))
	if room.get("balcony", false):
		var wood := surface("floor_wood", MISSION_WOOD)
		# Reception's separate rear counter sits below shelves and framed paintings on the balcony wall.
		for x in [6.8, 13.2]:
			var shelf := _stand("home/floating_shelf", Vector3(x, 1.85, 4.12), 0, 1.6)
			if shelf != null:
				_stand("home/books_stack", Vector3(x - 0.28, 1.93, 4.2), 0, 0.9)
				_stand("home/vase_flowers", Vector3(x + 0.4, 1.93, 4.2), 0, 0.9)
		for x in [9.0, 11.0]:
			var painting := _hang_frame(int(x), 4, Vector2i.DOWN, 1.78, 0, 1.8, 1.2)
			painting.position = Vector3(x, 1.78, 4.12)
		var paper := surface("wall_plaster", Color("#f6f0e5"))
		for x in [8.0, 11.4]:
			for sheet in 9:
				floor_mesher.box("reception_papers", paper, Vector3(x + sin(float(sheet)) * 0.025, DESK_TOP + 0.004 + float(sheet) * 0.007, 4.5 + cos(float(sheet)) * 0.018), Vector3(0.62, 0.006, 0.43))
		floor_mesher.box("balcony_wall", ivory, Vector3(10.5, 1.35, 4.0), Vector3(19.8, 2.7, T))
		# Seal the floor, rear and side walls beneath the open balcony; no void shows between its columns.
		for y in range(1, 4):
			for x in range(1, 20):
				_floor_quad(x, y, 0, 0, 1, 1, "hall", 0)
		floor_mesher.box("hotel_ivory", ivory, Vector3(10.5, 1.35, 0.5), Vector3(20, 2.7, T))
		for x in [0.5, 20.5]:
			floor_mesher.box("hotel_ivory", ivory, Vector3(x, 1.35, 2.25), Vector3(T, 2.7, 3.5))
		floor_mesher.box("hotel_ivory", ivory, Vector3(10.5, 2.58, 2.25), Vector3(19.8, 0.18, 3.5))
		var rail_wood := _rail_mat()
		# Unbroken, bevelled wooden rails meet the stair rails at the two stout landing posts.
		_indoor_railing(Vector3(1.0, 2.7, 4.0), Vector3(16.04, 2.7, 4.0), rail_wood)
		_indoor_railing(Vector3(17.96, 2.7, 4.0), Vector3(20.0, 2.7, 4.0), rail_wood)
		for x in [3.5, 9.5, 14.5]:
			floor_mesher.box("hotel_ivory", ivory, Vector3(x, 1.28, 3.8), Vector3(0.25, 2.56, 0.25))
		# One continuous sloped beam per side, following the five-tile flight rather than little stepped pieces.
		for x in [16.04, 17.96]:
			_indoor_railing(Vector3(x, 2.7, 4.0), Vector3(x, 0, 9.0), rail_wood)

	for fixture in room.get("fixtures", []):
		if fixture[2] == "plant_table":
			var c := Vector3(float(fixture[0]) + 0.5, 2.7, float(fixture[1]) + 0.5)
			var table := _stand("kk_table_small", c, 0, 0.7)
			if table != null:
				var bb := table.mesh.get_aabb()
				table.position.y -= bb.position.y * table.scale.y
				var top := table.position.y + bb.end.y * table.scale.y
				var name: String = ["home/plant_pillow_tall", "home/plant_pillow_round"][int(fixture[0]) % 2]
				var plant := _stand(name, Vector3(c.x, top, c.z), 0)
				if plant != null:
					var pb := plant.mesh.get_aabb()
					plant.scale = Vector3.ONE * (0.85 / pb.size.y)
					plant.position.y -= pb.position.y * plant.scale.y
			continue
		if fixture[2] == "luggage":
			_luggage_stack(int(fixture[0]), int(fixture[1]))
			continue
		if fixture[2] == "hot_tub_sign":
			# on the platform's front railing, facing the camera
			preload("res://scripts/gfx/hotel_spa.gd").plaque(parent, Vector2i(int(fixture[0]), int(fixture[1])), DAIS_H, ivory)
			continue
		if fixture[2] != "ice_maker":
			continue
		var c := Vector3(float(fixture[0]) + 0.5, 0, float(fixture[1]) + 0.5)
		floor_mesher.box("hotel_ivory", ivory, c + Vector3(0, 0.62, 0), Vector3(0.86, 1.24, 0.76))
		floor_mesher.box("hotel_iron", dark, c + Vector3(0, 0.7, 0.39), Vector3(0.56, 0.38, 0.025))
		floor_mesher.box("hotel_tile", tile, c + Vector3(0, 0.47, 0.45), Vector3(0.62, 0.07, 0.16))
		floor_mesher.box("hotel_iron", dark, c + Vector3(0.26, 1.08, 0.39), Vector3(0.12, 0.07, 0.03))
	if map.get("room_key", "") == "hotel_pool":
		# The spa stands on the same walkable dais used by room floors and movement.
		preload("res://scripts/gfx/hotel_spa.gd").build(parent, Vector3(3, DAIS_H, 2), tile, ivory)
	if room.has("pool_ladder"):
		_pool_ladder(Vector2i(int(room["pool_ladder"][0]), int(room["pool_ladder"][1])))
	for treadmill in room.get("treadmills", []):
		var c := Vector3(float(treadmill[0]) + 0.5, 0, float(treadmill[1]) + 0.5)
		floor_mesher.box("hotel_ivory", ivory, c + Vector3(0, 0.08, 0.1), Vector3(0.95, 0.16, 1.85))
		floor_mesher.box("hotel_iron", dark, c + Vector3(0, 0.18, 0.1), Vector3(0.7, 0.04, 1.55))
		for side in [-1, 1]:
			floor_mesher.box("hotel_ivory", ivory, c + Vector3(side * 0.43, 0.68, -0.7), Vector3(0.07, 1.2, 0.07))
		floor_mesher.box("hotel_iron", dark, c + Vector3(0, 1.25, -0.7), Vector3(0.92, 0.2, 0.32))


## A swimming pool's steel ladder on water tile `p` (a template's "pool_ladder"), against the pool's edge toward the
## floor beside it: two stout rails rising out of the water and arching over the coping onto the deck, with rungs
## below the surface. It stands within the edge's half tile, so the deck in front stays walkable.
func _pool_ladder(p: Vector2i) -> void:
	var out := Vector2i.ZERO
	for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
		if code(p.x + d.x, p.y + d.y) != MapGen.WATER and not code(p.x + d.x, p.y + d.y) in WALLISH:
			out = d
			break
	if out == Vector2i.ZERO:
		return
	var steel: StandardMaterial3D = surface("wall_plaster", Color("#c4cfd6"))
	steel.metallic = 0.55
	steel.roughness = 0.35
	var o := Vector3(out.x, 0, out.y)
	var side := Vector3(absf(out.y), 0, absf(out.x))
	var edge := Vector3(p.x + 0.5, 0, p.y + 0.5) + o * 0.5
	for s in [-0.24, 0.24]:
		var at: Vector3 = edge + side * s
		var pts := [at - o * 0.14 + Vector3(0, -0.5, 0), at - o * 0.14 + Vector3(0, 0.62, 0), at - o * 0.08 + Vector3(0, 0.76, 0),
			at + o * 0.08 + Vector3(0, 0.76, 0), at + o * 0.16 + Vector3(0, 0.62, 0), at + o * 0.16 + Vector3(0, 0.0, 0)]
		for i in pts.size() - 1:
			_beam("pool_ladder", steel, pts[i], pts[i + 1], 0.045, true)
		# a round foot plate where the rail meets the deck
		_beam("pool_ladder", steel, at + o * 0.16, at + o * 0.16 + Vector3(0, 0.03, 0), 0.08, true)
	for y in [-0.42, -0.22, 0.0]:
		_beam("pool_ladder", steel, edge - o * 0.14 - side * 0.24 + Vector3(0, y, 0), edge - o * 0.14 + side * 0.24 + Vector3(0, y, 0), 0.04, true, 0.6)


## The shared indoor balustrade: a continuous solid handrail, a lower rail, broad slats and capped, stout posts.
## Both level and sloping runs share the same bevelled, texture-sampling wood and closed ends.
func _indoor_railing(a: Vector3, b: Vector3, wood: Material) -> void:
	var length := a.distance_to(b)
	_beam("hotel_wood_rail", wood, a + Vector3.UP * 0.98, b + Vector3.UP * 0.98, 0.17, true, 0.7)
	_beam("hotel_wood_rail", wood, a + Vector3.UP * 0.24, b + Vector3.UP * 0.24, 0.075, true, 0.75)
	var posts := maxi(1, ceili(length / 1.6))
	for i in range(posts + 1):
		var base := a.lerp(b, float(i) / posts)
		_beam("hotel_wood_rail", wood, base, base + Vector3.UP * 1.08, 0.145, true)
		_beam("hotel_wood_rail", wood, base + Vector3.UP * 1.06, base + Vector3.UP * 1.18, 0.19, true)
	var slats := maxi(2, ceili(length / 0.44))
	for i in range(1, slats):
		var t := float(i) / slats
		var nearest_post := absf(t * posts - roundf(t * posts)) * length / posts
		if nearest_post < 0.22:
			continue
		var base := a.lerp(b, t)
		_beam("hotel_wood_rail", wood, base + Vector3.UP * 0.24, base + Vector3.UP * 0.9, 0.065, true)


## A room whose walls are covered in art (a template's "art_walls", the user's direction for the café, 2026-11-15):
## every free stretch of back and side wall gets boxy framed prints hung salon-style at varied heights, a large one
## across two tiles now and then, nothing over windows, doors, curtains or tall furniture.
func _art_walls() -> void:
	var furn: Dictionary = map.get("furniture", {})
	var hung := {}
	var r := RandomNumberGenerator.new()
	r.seed = pick_seed * 17 + 3
	for y in range(0, h - 1):
		for x in range(0, w):
			var t0 := Vector2i(x, y)
			if code(x, y) != MapGen.IWALL or hung.has(t0) or _cubbies.has(t0) or _by_window.has(t0):
				continue
			for inside in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
				var t: Vector2i = t0 + inside
				if zone(t.x, t.y) == "":
					continue
				var along := Vector2i(inside.y, inside.x)
				if not (wallish(x + along.x, y + along.y) and wallish(x - along.x, y - along.y)):
					continue
				# beside a door or window: a narrow frame, set away from the opening
				var away := 0.0
				for sgn in [-1, 1]:
					if code(x + along.x * sgn, y + along.y * sgn) in [MapGen.IWINDOW, MapGen.IDOOR, MapGen.LOCKED]:
						away -= sgn * 0.14 * (1.0 if (along.x > 0 or along.y > 0) else -1.0)
				if code(t.x, t.y) in [MapGen.SHELF, MapGen.BOOKSHELF, MapGen.BOARD, MapGen.FIREPLACE, MapGen.STAIRS_UP, MapGen.STAIRS_DOWN] 						or furn.get(t, "") in ["fridge", "wardrobe", "pantry", "storage", "bookshelf", "shelf", "floor_lamp"]:
					continue
				# (over a tall plant the art hangs a little higher)
				var high := 0.2 if code(t.x, t.y) == MapGen.PLANT or furn.get(t, "") == "plant" else 0.0
				if away != 0.0:
					var lift0 := Elev.surface(map, t) if Elev.has(map) else 0.0
					_hang_frame(x, y, inside, 2.0 + lift0, away, 0.3, 0.4)
					_hang_frame(x, y, inside, 1.5 + lift0, away, 0.34, 0.44)
					hung[t0] = true
					break
				# the floor under it may be a platform: the art goes up with it
				var lift := (Elev.surface(map, t) if Elev.has(map) else 0.0) + high
				var next := t0 + along
				var pair_free: bool = code(next.x, next.y) == MapGen.IWALL and not hung.has(next) and not _by_window.has(next) 					and wallish(next.x + along.x, next.y + along.y) and not code(next.x + along.x, next.y + along.y) in [MapGen.IWINDOW, MapGen.IDOOR, MapGen.LOCKED] 					and not furn.get(next + inside, "") in ["fridge", "wardrobe", "pantry", "storage", "bookshelf", "shelf", "floor_lamp", "plant"] 					and not code(next.x + inside.x, next.y + inside.y) in [MapGen.SHELF, MapGen.BOOKSHELF]
				var roll := r.randf()
				# (a side wall's "along" runs south, so a two-tile piece's middle is half a tile that way)
				var half := 0.5 if (along.x > 0 or along.y > 0) else -0.5
				if pair_free and roll < 0.3 and high == 0.0:
					var wide := r.randf() < 0.6
					_hang_frame(x, y, inside, 1.72 + lift, half, 1.35 if wide else 0.95, 0.95 if wide else 1.2)
					hung[next] = true
				elif roll < 0.75:
					# a stacked pair: a small landscape over a portrait
					_hang_frame(x, y, inside, 2.02 + lift, r.randf_range(-0.12, 0.12), 0.48, 0.36)
					_hang_frame(x, y, inside, 1.48 + lift, r.randf_range(-0.12, 0.12), 0.42, 0.56)
				elif roll < 0.9:
					_hang_frame(x, y, inside, r.randf_range(1.6, 1.8) + lift, r.randf_range(-0.1, 0.1), 0.56, 0.74)
				else:
					_hang_frame(x, y, inside, 1.7 + lift, 0.0, 0.6, 0.6)
				hung[t0] = true
				break


func _into_room_side(x: int, y: int, horiz: bool) -> Vector2i:
	var inside := Vector2i.DOWN if horiz else Vector2i.RIGHT
	return -inside if zone(x + inside.x, y + inside.y) == "" else inside
