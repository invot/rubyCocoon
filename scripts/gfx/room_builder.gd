extends RefCounted
## Builds the fixed parts of a building's interior from its map (see map_loader.gd _interior): the floors, thin walls
## with doorways, locked doors and windows, the furniture, the things hung on the walls and a light in each room.
## Everything is made of the PSX interior pack's pieces and textures (assets/psx/interior, baked by
## tools/import_psx_interior.gd).
##
## Rooms: the map's "zone_rows" give each tile's kind of room (see ZONES), so a kitchen gets tiles and a bedroom
## carpet and wallpaper; each side of a wall takes the finish of the room it faces.
## Walls run through the middle of their tiles, a fifth of a tile thick. Each row of walls is one mesh whose vertices
## know their tile, so the walls between the camera and the player can fade, tile by tile (see fade).
## Furniture: tiles with the same piece next to each other make one piece; it stands with its back to the wall it
## touches most, pushed right up against it, and faces into the room.

const MapGen = preload("res://scripts/world/map_gen.gd")
const DIR := "res://assets/psx/interior/"
## wall thickness, height, the top of a doorway, a window's sill and top
const T := 0.2
const H := 2.8
const DOOR_H := 1.95
const SILL := 0.85
const WIN_TOP := 2.07
## the front wall (nearest the camera) is only a low kerb
const FRONT_H := 0.3
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

## Furniture: kind: m = models to choose from (the best fit for the space is picked), free = stands in the room
## rather than against a wall, fill = stretched along the wall to fill its tiles, y = height stretch (the pack's tables
## are low), long = its long side goes against the wall, short = its short end does (beds: the headboard),
## top = small things that may stand on it.
const KINDS := {
	"counter": {"m": ["counter"], "fill": true, "top": ["cup", "bottle", "plate_2", "milk", "apple", "el_microwave", "el_toaster", "", ""]},
	"kitchen_sink": {"m": ["kitchen_sink"], "fill": true},
	"stove": {"m": ["stove"], "fill": true, "top": ["pan", "pot", ""]},
	"fridge": {"m": ["fridge"]},
	"pantry": {"m": ["pantry"]},
	"toilet": {"m": ["toilet"]},
	"bathtub": {"m": ["bathtub"], "long": true},
	"basin": {"m": ["basin", "vanity"]},
	"washer": {"m": ["washer"]},
	"sofa": {"m": ["sofa", "sofa_2"], "long": true},
	"armchair": {"m": ["armchair", "armchair_2"]},
	"tv": {"m": ["cabinet_low"], "top": ["tv"], "always_top": true},
	"chair": {"m": ["chair_wood", "chair_padded"], "chair": true, "single": true},
	"stool": {"m": ["chair_stool", "chair_wood"], "chair": true, "single": true},
	"coffee_table": {"m": ["coffee_table", "table_long"], "free": true, "top": ["books", "cup", "chessboard", "el_vase", ""]},
	"table": {"m": ["table_dining", "table_long", "table_round"], "free": true, "y": 1.45,
		"top": ["plate", "cup", "cup_2", "bottle_2", "books_2", "apple", ""]},
	"wardrobe": {"m": ["wardrobe"]},
	"nightstand": {"m": ["nightstand"], "top": ["table_lamp"], "always_top": true, "single": true},
	"dresser": {"m": ["dresser"], "top": ["teddy", "books", "radio", "el_lamp", "el_photo", "el_vase"]},
	"desk": {"m": ["desk"], "y": 1.65, "top": ["books", "pencils", "globe", "phone"]},
	"storage": {"m": ["shelves_metal", "shelves"], "long": true},
	"boxes": {"m": ["box_1", "box_2", "box_3", "pallet"], "single": true},
	"mop": {"m": ["bucket"], "with": "broom", "single": true},
	"floor_lamp": {"m": ["floor_lamp"], "lamp": true, "single": true},
	"coat_stand": {"m": ["coat_stand"], "single": true},
	"trash": {"m": ["trash_bin"], "single": true},
	"bed": {"m": ["bed_single", "bed_double"], "short": true},
	"bunk": {"m": ["bed_bunk"], "short": true},
	"plant": {"m": ["plant_small", "plant_tall", "plant_leafy", "el_tp_plants"], "single": true},
	"bookshelf": {"m": ["bookshelf"], "long": true},
	"shelf": {"m": ["shelves"], "long": true, "goods": true},
	"rug": {"m": ["carpet_1", "carpet_2", "carpet_3", "carpet_4"], "free": true, "rug": true},
	"bench": {"m": ["table_long"], "fill": true, "y": 0.9, "depth": 0.5},
	"booth": {"m": ["el_booth"], "fit": true, "chair": true, "tint": "#e05050"},
	"diner_table": {"m": ["el_diner_table"], "free": true, "fit": true, "top": ["cup", "plate", "el_flowers", "cup_2", ""]},
	"computer": {"m": ["desk"], "y": 1.65, "top": ["el_monitor"], "always_top": true},
}

static var _meshes := {}
static var _mats := {}


static func piece(name: String) -> Mesh:
	if not _meshes.has(name):
		_meshes[name] = load(DIR + name + ".res") if ResourceLoader.exists(DIR + name + ".res") else null
	return _meshes[name]


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
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	m.uv1_scale = Vector3(1.0 / SPAN, 1.0 / SPAN, 1.0) if tex != "checker" else Vector3(1.0, 1.0, 1.0)
	_mats[key] = m
	return m


## Quads collected per material, then made into one mesh.
class Mesher:
	var surf := {}
	var mats := {}
	## the centre of the wall tile being built (x, z), kept in each vertex's UV2 so the tile can fade on its own
	var tile := Vector2(-1, -1)

	## Corners in order round the quad; uv runs along u_dir and v_dir (world units) from the first corner's
	## projection onto them; shade darkens it (vertex colour).
	func quad(key: String, mat: Material, p: Array, n: Vector3, u_dir: Vector3, v_dir: Vector3, shade := 1.0) -> void:
		if not surf.has(key):
			surf[key] = [PackedVector3Array(), PackedVector3Array(), PackedVector2Array(), PackedColorArray(), PackedVector2Array()]
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
			a[4].append(tile)

	## One triangle (corners in any order), facing `n`.
	func tri(key: String, mat: Material, p: Array, n: Vector3, u_dir: Vector3, v_dir: Vector3, shade := 1.0) -> void:
		if not surf.has(key):
			surf[key] = [PackedVector3Array(), PackedVector3Array(), PackedVector2Array(), PackedColorArray(), PackedVector2Array()]
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
			a[4].append(tile)

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
			arrays[Mesh.ARRAY_TEX_UV2] = a[4]
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
## per row of walls: a node, and the mesher its walls go into
var rows := {}
var _row_meshers := {}
var floor_mesher := Mesher.new()
var lights: Array = []
var pick_seed := 0

## Fading walls (see fade): each wall tile's kind, "v" for a wall running away from the camera, "h" for the rest (the
## walls you walk through on your way towards the camera or away from it), and how opaque it is now
var wall_kind := {}
var fade_alpha := {}
## the doors, windows, plates and things hung on each wall tile, which fade with it
var _attached := {}
var _row_mi := {}
var _row_shadow := {}
var _row_tiles := {}
var _row_fading := {}
## each wall tile's opacity, one texel per tile, read by the walls' fade material
var _fade_img: Image
var _fade_tex: ImageTexture
var _fade_mats := {}
var _snap := true
## furniture at least this tall (metres) fades too (see add_prop): {nodes, x, z (its middle), half_w, a (opacity)}
const TALL := 1.2
var _props: Array = []


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
	var room: Dictionary = m.get("room", {})
	# the template's wall colour tints the wall textures a little
	rb.tint = Color.WHITE.lerp(Color(str(room.get("wall", "#ffffff"))), 0.35)
	rb.trim = Color(str(room.get("trim", "#5a3a26")))
	rb._floors()
	rb._walls()
	rb._furniture()
	rb._stalls()
	rb._counters()
	rb._wall_decor()
	rb._mats_at_doors()
	rb._lights()
	var fm := MeshInstance3D.new()
	fm.mesh = rb.floor_mesher.mesh()
	p.add_child(fm)
	for y in rb._row_meshers:
		var mi := MeshInstance3D.new()
		mi.mesh = (rb._row_meshers[y] as Mesher).mesh()
		(rb.rows[y] as Node3D).add_child(mi)
		rb._row_mi[y] = mi
		# while the row fades (see fade), this keeps its shadow on the floor
		var sh := MeshInstance3D.new()
		sh.mesh = mi.mesh
		sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		sh.visible = false
		(rb.rows[y] as Node3D).add_child(sh)
		rb._row_shadow[y] = sh
	rb._fade_img = Image.create(maxi(rb.w, 1), maxi(rb.h, 1), false, Image.FORMAT_R8)
	rb._fade_img.fill(Color(1, 0, 0))
	rb._fade_tex = ImageTexture.create_from_image(rb._fade_img)
	for t: Vector2i in rb.wall_kind:
		if not rb._row_tiles.has(t.y):
			rb._row_tiles[t.y] = []
		rb._row_tiles[t.y].append(t)
	return rb


# ---------------------------------------------------------------- fading walls
## In a cone opening from the player towards the camera, a wall ahead of the player is clear, about 70% opaque while
## they pass through it, and solid once it's behind them. Walls right beside the player, and the low front kerb,
## stay solid. The cone: CONE_BASE tiles either side at the player, widening by CONE_SLOPE per tile ahead, its edge
## softened over CONE_SOFT.
const CONE_BASE := 1.1
const CONE_SLOPE := 0.7
const CONE_SOFT := 0.6
const PASSING := 0.7
const FADE_SPEED := 3.0
const FADE_SHADER := preload("res://scripts/gfx/wall_fade.gdshader")


## How opaque wall tile `t` should be with the player at `p`.
func fade_target(t: Vector2i, p: Vector3) -> float:
	if t.y >= h - 1:
		return 1.0
	return _cone(absf(t.x + 0.5 - p.x), t.y + 0.5 - p.z, wall_kind[t])


## How opaque something `dx` tiles to the side of the player and `dz` ahead of them (towards the camera) should be:
## kind "h" for a wall you walk through, "v" for one you only ever pass beside (and tall furniture).
func _cone(dx: float, dz: float, kind: String) -> float:
	var a := 1.0
	if kind == "v":
		# running away from the camera: clear once it's ahead of the player, solid beside them
		a = clampf(1.0 - (dz - 0.4) / 0.5, 0.0, 1.0)
	elif dz >= 0.0:
		# ahead: clear, coming up to PASSING as the player steps into it
		a = PASSING * clampf(1.0 - dz / 0.8, 0.0, 1.0)
	else:
		# passed through: solid again as the player steps clear of it
		a = lerpf(PASSING, 1.0, clampf(-dz / 0.7, 0.0, 1.0))
	var half := CONE_BASE + maxf(dz, 0.0) * CONE_SLOPE
	return lerpf(a, 1.0, clampf((dx - half) / CONE_SOFT, 0.0, 1.0))


## Moves every wall tile's opacity towards where the player at `p` wants it (call every frame).
func fade(p: Vector3, delta: float) -> void:
	# the first call (on entering) sets them straight away
	var step := 1.0 if _snap else delta * FADE_SPEED
	_snap = false
	var changed := false
	var touched := {}
	for t: Vector2i in wall_kind:
		var target := fade_target(t, p)
		var a: float = fade_alpha.get(t, 1.0)
		if a == target:
			continue
		a = move_toward(a, target, step)
		fade_alpha[t] = a
		_fade_img.set_pixel(t.x, t.y, Color(a, 0, 0))
		changed = true
		touched[t.y] = true
		for gi in _attached.get(t, []):
			if is_instance_valid(gi):
				(gi as GeometryInstance3D).transparency = 1.0 - a
				(gi as GeometryInstance3D).visible = a > 0.02
	if changed:
		_fade_tex.update(_fade_img)
	# tall furniture: clear ahead of the player, solid beside and behind them, like a wall they pass beside
	for prop: Dictionary in _props:
		var dx := maxf(0.0, absf(float(prop["x"]) - p.x) - float(prop["half_w"]))
		var target := _cone(dx, float(prop["z"]) - p.z, "v")
		var pa: float = prop["a"]
		if pa == target:
			continue
		pa = move_toward(pa, target, step)
		prop["a"] = pa
		for gi in prop["nodes"]:
			if is_instance_valid(gi):
				(gi as GeometryInstance3D).transparency = 1.0 - pa
				(gi as GeometryInstance3D).visible = pa > 0.02
	for y in touched:
		var fading := false
		for t in _row_tiles.get(y, []):
			if fade_alpha.get(t, 1.0) < 0.999:
				fading = true
				break
		if fading != _row_fading.get(y, false):
			_row_fading[y] = fading
			_set_row_fading(y, fading)


## A row of walls with any tile fading draws with the fade material (the rest of the time, its own, opaque). The fade
## material is see-through, so casts no shadow: the row's shadow-only twin stands in meanwhile.
func _set_row_fading(y: int, on: bool) -> void:
	var mi: MeshInstance3D = _row_mi.get(y)
	if mi == null or mi.mesh == null:
		return
	(_row_shadow[y] as MeshInstance3D).visible = on
	for si in mi.mesh.get_surface_count():
		mi.set_surface_override_material(si, _fade_mat(mi.mesh.surface_get_material(si)) if on else null)


func _fade_mat(std: Material) -> Material:
	if _fade_mats.has(std):
		return _fade_mats[std]
	var sm := ShaderMaterial.new()
	sm.shader = FADE_SHADER
	var bm := std as BaseMaterial3D
	if bm != null:
		sm.set_shader_parameter("albedo_tex", bm.albedo_texture)
		sm.set_shader_parameter("albedo_color", bm.albedo_color)
		sm.set_shader_parameter("uv_scale", Vector2(bm.uv1_scale.x, bm.uv1_scale.y))
		sm.set_shader_parameter("roughness_v", bm.roughness)
	sm.set_shader_parameter("fade_map", _fade_tex)
	sm.set_shader_parameter("map_size", Vector2(w, h))
	_fade_mats[std] = sm
	return sm


## Makes a tall piece standing on tiles `lo` .. `lo + size` (with the things on it, `nodes`) fade like the walls.
func add_prop(nodes: Array, lo: Vector2i, size: Vector2) -> void:
	_props.append({"nodes": nodes, "x": lo.x + size.x / 2.0, "z": lo.y + size.y / 2.0, "half_w": size.x / 2.0 - 0.5, "a": 1.0})


## Puts `node` on wall tile (x, y): in its row, fading with the tile.
func _attach(x: int, y: int, node: Node3D) -> void:
	_row(y)
	(rows[y] as Node3D).add_child(node)
	var t := Vector2i(x, y)
	if not _attached.has(t):
		_attached[t] = []
	_attached[t].append(node)


# ---------------------------------------------------------------- rooms
func code(x: int, y: int) -> int:
	return MapGen.get_t(map, x, y)


func wallish(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h and code(x, y) in WALLISH


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
	var own: String = map.get("room", {}).get(what + "_tex", {}).get(z, "")
	if own != "":
		return own
	var opts: Array = ZONES.get(z, ZONES["shop"])[what]
	return opts[absi(hash(z + what) + pick_seed) % opts.size()]


func floor_mat(z: String) -> Material:
	return surface(_pick(z, "floor"), Color.WHITE, textures)


func wall_mat(z: String) -> Material:
	return surface(_pick(z, "wall"), tint if z in ["shop", "hall", "back", "office", "diner"] else Color.WHITE, textures)


func _floors() -> void:
	for y in h:
		for x in w:
			var c := code(x, y)
			if c in [MapGen.RING, MapGen.LAVA, MapGen.IVOID]:
				continue
			if not c in WALLISH:
				_floor_quad(x, y, 0.0, 0.0, 1.0, 1.0, zone(x, y))
				continue
			if c in DIAGS:
				# each half of the tile takes the floor of the room on its side of the diagonal
				for side in _diag_sides(x, y):
					var zz: String = side[1]
					if zz != "":
						_floor_tri(side[0], zz)
				continue
			# under a wall: each quarter takes the floor of the room beside it
			for q in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
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
				var z := zone(x + q.x, y)
				if z == "":
					z = zone(x, y + q.y)
				if z == "":
					z = zone(x + q.x, y + q.y)
				if z == "":
					continue
				_floor_quad(x, y, 0.0 if q.x < 0 else 0.5, 0.0 if q.y < 0 else 0.5, 0.5, 0.5, z)


func _floor_quad(x: int, y: int, ox: float, oz: float, sx: float, sz: float, z: String) -> void:
	var x0 := x + ox
	var z0 := y + oz
	floor_mesher.quad("floor_" + z, floor_mat(z), [Vector3(x0, 0, z0), Vector3(x0 + sx, 0, z0), Vector3(x0 + sx, 0, z0 + sz),
		Vector3(x0, 0, z0 + sz)], Vector3.UP, Vector3.RIGHT, Vector3.BACK)


func _floor_tri(pts: Array, z: String) -> void:
	floor_mesher.tri("floor_" + z, floor_mat(z), pts, Vector3.UP, Vector3.RIGHT, Vector3.BACK)


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
			var top := FRONT_H if y == h - 1 else H
			var e := wallish(x + 1, y)
			var wv := wallish(x - 1, y)
			var n := wallish(x, y - 1)
			var s := wallish(x, y + 1)
			var horiz := e or wv or (not n and not s)
			var vert := n or s
			# everything built for this tile from here on fades with it
			_row(y).tile = Vector2(x + 0.5, y + 0.5)
			wall_kind[Vector2i(x, y)] = "v" if vert and not horiz and not c in DIAGS else "h"
			if c in DIAGS:
				# corner to corner across the tile, each face finished like the room it faces
				var sides := _diag_sides(x, y)
				var p0 := Vector2(x, y + 1) if c == MapGen.IDIAG_A else Vector2(x, y)
				var p1 := Vector2(x + 1, y) if c == MapGen.IDIAG_A else Vector2(x + 1, y + 1)
				_slant(y, p0, p1, 0.0, top, sides[0][1], sides[1][1], c)
				continue
			if c == MapGen.IWALL:
				# a diagonal wall next door, corner to corner: carry it on to this tile's centre
				for q in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
					var dx: int = x + q.x
					var dy: int = y + q.y
					if code(dx, dy) in DIAGS and _diag_joins(dx, dy, x, y):
						var sides2 := _diag_sides(dx, dy)
						var ctr := Vector2(x + 0.5, y + 0.5)
						_slant(y, ctr, ctr + Vector2(q.x, q.y) * 0.5, 0.0, top, sides2[0][1], sides2[1][1], code(dx, dy))
			match c:
				MapGen.IWALL:
					_bars(x, y, 0.0, top, horiz, vert, e, wv, n, s)
				MapGen.IWINDOW:
					if top < H:
						_bars(x, y, 0.0, top, horiz, vert, e, wv, n, s)
					else:
						_bars(x, y, 0.0, SILL, horiz, vert, e, wv, n, s)
						_bars(x, y, WIN_TOP, top, horiz, vert, e, wv, n, s)
						_window(x, y, horiz)
				MapGen.IDOOR, MapGen.LOCKED:
					if top > DOOR_H:
						_bars(x, y, DOOR_H, top, horiz, vert, e, wv, n, s)
					_doorway(x, y, horiz, c == MapGen.LOCKED)


## The wall in tile (x, y) between heights y0 and y1: a bar along each line of wall through it, each face finished
## like the room it faces, with a skirting board along the bottom and a dark cut along the top.
func _bars(x: int, y: int, y0: float, y1: float, horiz: bool, vert: bool, e: bool, wv: bool, n: bool, s: bool) -> void:
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
					_skirting(m, Vector3(half[0], 0, zf), Vector3(half[1], 0, zf), nrm)
		if not vert:
			if not wv:
				_face(m, zone_side(x, y, Vector2i(-1, 0), Vector2i(0, -1)), [Vector3(xa, y0, cz - T / 2.0), Vector3(xa, y0, cz + T / 2.0),
					Vector3(xa, y1, cz + T / 2.0), Vector3(xa, y1, cz - T / 2.0)], Vector3.LEFT, Vector3.BACK)
			if not e:
				_face(m, zone_side(x, y, Vector2i(1, 0), Vector2i(0, -1)), [Vector3(xb, y0, cz - T / 2.0), Vector3(xb, y0, cz + T / 2.0),
					Vector3(xb, y1, cz + T / 2.0), Vector3(xb, y1, cz - T / 2.0)], Vector3.RIGHT, Vector3.BACK)
		m.quad("cut", cut, [Vector3(xa, y1, cz - T / 2.0), Vector3(xb, y1, cz - T / 2.0), Vector3(xb, y1, cz + T / 2.0), Vector3(xa, y1, cz + T / 2.0)],
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
					_skirting(m, Vector3(xf, 0, half[0]), Vector3(xf, 0, half[1]), nrm)
		if not horiz:
			if not n:
				_face(m, zone_side(x, y, Vector2i(0, -1), Vector2i(-1, 0)), [Vector3(cx - T / 2.0, y0, za0), Vector3(cx + T / 2.0, y0, za0),
					Vector3(cx + T / 2.0, y1, za0), Vector3(cx - T / 2.0, y1, za0)], Vector3.FORWARD, Vector3.RIGHT)
			if not s:
				_face(m, zone_side(x, y, Vector2i(0, 1), Vector2i(-1, 0)), [Vector3(cx - T / 2.0, y0, zb0), Vector3(cx + T / 2.0, y0, zb0),
					Vector3(cx + T / 2.0, y1, zb0), Vector3(cx - T / 2.0, y1, zb0)], Vector3.BACK, Vector3.RIGHT)
		m.quad("cut", cut, [Vector3(cx - T / 2.0, y1, za0), Vector3(cx + T / 2.0, y1, za0), Vector3(cx + T / 2.0, y1, zb0), Vector3(cx - T / 2.0, y1, zb0)],
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
	var off := nrm * 0.015
	var mat := surface("skirting", trim)
	var along := (b - a).normalized()
	m.quad("skirting", mat, [a + off, b + off, b + off + Vector3(0, 0.11, 0), a + off + Vector3(0, 0.11, 0)], nrm, along, Vector3.DOWN)


## A doorway: a wooden frame round the opening on both faces; a locked door shows its door, closed.
func _doorway(x: int, y: int, horiz: bool, locked: bool) -> void:
	var m := _row(y)
	var cx := x + 0.5
	var cz := y + 0.5
	var fr := surface("frame", trim)
	var top := minf(DOOR_H, FRONT_H if y == h - 1 else DOOR_H)
	if y == h - 1:
		return
	var along := Vector3.RIGHT if horiz else Vector3.BACK
	var across := Vector3.BACK if horiz else Vector3.RIGHT
	var c := Vector3(cx, 0, cz)
	for side in [-1.0, 1.0]:
		# the jambs (as deep as the wall, a little proud of it) and the head
		m.box("frame", fr, c + along * side * 0.46 + Vector3(0, top / 2.0, 0), _axes(along, 0.09, top + 0.0, T + 0.06, horiz))
	m.box("frame", fr, c + Vector3(0, top + 0.05, 0), _axes(along, 1.0, 0.1, T + 0.06, horiz))
	if locked:
		var door := MeshInstance3D.new()
		# white panelled doors at home, glazed wooden ones in shops and back rooms
		var homely := false
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if zone(x + d.x, y + d.y) in ["living", "bedroom", "bathroom", "kitchen"]:
				homely = true
		var dn := "door_1" if homely and not map.get("staff_doors", {}).has(Vector2i(x, y)) else "door_3"
		door.mesh = piece(dn)
		if door.mesh != null:
			var bb := door.mesh.get_aabb()
			door.scale = Vector3(0.84 / bb.size.x, (top - 0.02) / bb.size.y, 1.0)
			door.position = c
			door.rotation.y = 0.0 if horiz else PI / 2.0
			_attach(x, y, door)
		if map.get("staff_doors", {}).has(Vector2i(x, y)):
			# a small brass plate: STAFF ONLY
			for side in [-1.0, 1.0]:
				var lab := Label3D.new()
				lab.text = "STAFF ONLY"
				lab.font_size = 14
				lab.pixel_size = 0.006
				lab.modulate = Color("#2a1a10")
				lab.outline_size = 0
				lab.position = c + Vector3(0, 1.45, 0) + across * side * 0.12
				lab.rotation.y = (0.0 if horiz else PI / 2.0) + (0.0 if side > 0.0 else PI)
				var plate := MeshInstance3D.new()
				var pm := BoxMesh.new()
				pm.size = Vector3(0.5, 0.14, 0.02)
				plate.mesh = pm
				plate.material_override = surface("brass", Color("#d8b050"))
				plate.position = c + Vector3(0, 1.45, 0) + across * side * 0.11
				plate.rotation.y = lab.rotation.y
				_attach(x, y, plate)
				_attach(x, y, lab)


## A box's size given its length along `along`, height, and depth across.
func _axes(along: Vector3, length: float, height: float, depth: float, horiz: bool) -> Vector3:
	return Vector3(length, height, depth) if horiz else Vector3(depth, height, length)


## A window in the wall: the pack's frame, sky glowing beyond the glass, and curtains on the room side of a living
## room or bedroom.
func _window(x: int, y: int, horiz: bool) -> void:
	var c := Vector3(x + 0.5, 0, y + 0.5)
	# which side is the room?
	var inside := Vector2i(0, 1) if horiz else Vector2i(1, 0)
	if zone(x + inside.x, y + inside.y) == "":
		inside = -inside
	var z := zone(x + inside.x, y + inside.y)
	var yaw := atan2(float(inside.x), float(inside.y))
	var win := MeshInstance3D.new()
	win.mesh = piece("window_2" if z in ["living", "bedroom"] else "window")
	if win.mesh != null:
		var bb := win.mesh.get_aabb()
		win.scale = Vector3(0.98 / bb.size.x, (WIN_TOP - SILL) / bb.size.y, 1.6)
		win.position = c + Vector3(0, SILL, 0)
		win.rotation.y = yaw
		_attach(x, y, win)
	var sky := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.98, WIN_TOP - SILL)
	sky.mesh = q
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color("#cfe6ff")
	sm.emission_enabled = true
	sm.emission = Color("#bcdcff")
	sm.emission_energy_multiplier = 0.9
	sky.material_override = sm
	sky.position = c + Vector3(0, (SILL + WIN_TOP) / 2.0, 0) - Vector3(inside.x, 0, inside.y) * 0.04
	sky.rotation.y = yaw
	_attach(x, y, sky)
	if z in ["living", "bedroom"]:
		var cur := MeshInstance3D.new()
		cur.mesh = piece(["curtains_1", "curtains_2", "curtains_3", "curtains_4"][rng.randi_range(0, 3)])
		if cur.mesh != null:
			var cb := cur.mesh.get_aabb()
			cur.scale = Vector3(1.3 / cb.size.x, 1.0, 1.0)
			cur.position = c + Vector3(0, WIN_TOP + 0.25 - cb.size.y, 0) + Vector3(inside.x, 0, inside.y) * (T / 2.0 + 0.08)
			cur.rotation.y = yaw
			_attach(x, y, cur)
	# a radiator under the sill, now and then
	if z in ["living", "bedroom", "office", "hall"] and rng.randf() < 0.6:
		_hang("radiator", x, y, inside, 0.12, 0.0)


# ---------------------------------------------------------------- furniture
func _furniture() -> void:
	var furn: Dictionary = map.get("furniture", {})
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
		if (KINDS[kind].get("fill", false) or KINDS[kind].get("single", false)) and group.size() > 1:
			# a run of counters is a cabinet per tile; chairs, plants and lamps side by side are one each
			for q in group:
				_place(kind, [q])
		else:
			_place(kind, group)


func _place(kind: String, group: Array) -> void:
	var k: Dictionary = KINDS.get(kind, {})
	var lo := Vector2i(group[0])
	var hi := Vector2i(group[0])
	for q in group:
		lo = Vector2i(mini(lo.x, q.x), mini(lo.y, q.y))
		hi = Vector2i(maxi(hi.x, q.x), maxi(hi.y, q.y))
	var size := Vector2(hi.x - lo.x + 1, hi.y - lo.y + 1)
	var center := Vector3(lo.x + size.x / 2.0, 0, lo.y + size.y / 2.0)
	# the wall it backs onto: the side with the most wall along it
	var back := Vector2i.ZERO
	if not k.get("free", false):
		var best := 0
		for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
			var n := 0
			for q in group:
				var r: Vector2i = q + d
				if (wallish(r.x, r.y) or r.x < 0 or r.y < 0 or r.x >= w or r.y >= h) and not group.has(r):
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
	if back == Vector2i.ZERO and kind in ["sofa", "armchair"]:
		# a sofa out in the room faces the television
		var best_d := INF
		for q in map.get("furniture", {}):
			if map["furniture"][q] == "tv":
				var dv := Vector2(q - lo)
				if dv.length() < best_d:
					best_d = dv.length()
					back = -Vector2i(int(signf(dv.x)), 0) if absf(dv.x) > absf(dv.y) else -Vector2i(0, int(signf(dv.y)))
	if k.get("chair", false):
		# a chair faces the table beside it (its back away from it)
		for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var r: Vector2i = lo + d
			if map.get("furniture", {}).get(r, "") in ["table", "desk", "coffee_table", "diner_table"]:
				back = -d
				against = false
				break
	# the model turned so its back (-z) faces `back`
	var yaw := 0.0
	if back != Vector2i.ZERO:
		yaw = atan2(float(-back.x), float(-back.y))
	elif k.get("free", false) and size.y > size.x:
		yaw = PI / 2.0
	var along := absf(sin(yaw)) < 0.5
	var span := size.x if along else size.y
	var depth := size.y if along else size.x
	# room up to the wall's face beyond the tiles
	var reach := 0.5 - T / 2.0 if against else 0.0
	var mesh := _choose(k["m"], span, depth + reach)
	if mesh == null:
		return
	var bb := mesh.get_aabb()
	var sy := float(k.get("y", 1.0))
	var sc := Vector3.ONE
	if k.get("rug", false):
		sc = Vector3(span * 0.92 / bb.size.x, 1.0, depth * 0.92 / bb.size.z)
	elif k.get("fit", false):
		sc = Vector3(span * 0.94 / bb.size.x, 1.0, minf(1.0, (depth + reach) * 0.94 / bb.size.z))
	elif k.get("fill", false):
		sc = Vector3(span * 0.98 / bb.size.x, 1.0, minf(1.0, (depth + reach) * 0.95 / bb.size.z) * float(k.get("depth", 1.0)))
	else:
		var s := minf(1.0, minf(span * 0.96 / bb.size.x, (depth + reach) * 0.96 / bb.size.z))
		sc = Vector3(s, s, s)
	sc.y *= sy
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.scale = sc
	mi.rotation.y = yaw
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
	mi.position = pos
	parent.add_child(mi)
	# the piece and everything on it, to fade together if it's tall
	var pieces: Array = [mi]
	var top_y := bb.size.y * sc.y
	# things standing on it
	var tops: Array = k.get("top", [])
	if not tops.is_empty() and (k.get("always_top", false) or rng.randf() < 0.75):
		var n_items := 1 if k.get("always_top", false) else rng.randi_range(1, 1 + int(span * depth))
		for i in n_items:
			var name: String = tops[rng.randi_range(0, tops.size() - 1)] if not k.get("always_top", false) else tops[0]
			if name == "":
				continue
			var t := MeshInstance3D.new()
			t.mesh = piece(name)
			if t.mesh == null:
				continue
			var spread := Vector3(bb.size.x * sc.x * 0.3, 0, bb.size.z * sc.z * 0.25)
			var off := Vector3(rng.randf_range(-1, 1) * spread.x, 0, rng.randf_range(-1, 1) * spread.z) if not k.get("always_top", false) else Vector3.ZERO
			t.position = pos + Basis(Vector3.UP, yaw) * off + Vector3(0, top_y, 0)
			t.rotation.y = yaw + (rng.randf_range(-0.6, 0.6) if not k.get("always_top", false) else 0.0)
			parent.add_child(t)
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
	if top_y >= TALL:
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
	"apothecary": ["bottle", "bottle_2", "product_1", "product_3", "el_vase", "plant_small"],
	"bookstore": ["books", "books_2", "book", "el_photo", "el_vase"],
	"cafe": ["el_coffee_maker", "el_slush", "cup", "cup_2", "plate", "el_flowers"],
	"electronics": ["phone", "radio", "books_2", "product_2"],
	"music_shop": ["radio", "books", "el_photo"],
	"center": ["el_coffee", "cup", "plate_2", "el_flowers"],
	"beast_gear": ["product_2", "product_4", "box_3"],
	"trainer_gear": ["product_2", "book", "box_3"],
}


## Shop counters are store counters: the 6TWELVE shop's dark-wood counter with its glass-fronted displays of sweets,
## facing the customers (the open side, away from the staff), cut into pieces of three to six tiles along each run of
## counter tiles; a run of one or two tiles (the ends of a U round a desk) is a kitchen base unit with a marble top.
## On top: one till by the person working there, its keys and screen turned to them (a cash register; the electronics
## shop's terminal is a computer; the Beast Center's nurse has her coffee machine), and a few things from the trade.
const TILL := {"electronics": "el_monitor", "center": "el_coffee"}


func _counters() -> void:
	var shop: String = map.get("building", {}).get("shop", "")
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
			if pieces.is_empty():
				var sb := short_piece.get_aabb()
				for q in run:
					var mi2 := MeshInstance3D.new()
					mi2.mesh = short_piece
					mi2.scale = Vector3(1.0 / sb.size.x, 1.0 / sb.size.y, 0.9 / sb.size.z)
					mi2.rotation.y = yaw
					mi2.position = Vector3(q.x + 0.5, 0, q.y + 0.5)
					parent.add_child(mi2)
			for q in run:
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
				if mine:
					# by the keeper, at the back edge of the counter, its front (keys, screen) turned to them
					t.position = Vector3(q.x + 0.5, 1.0, q.y + 0.5) + back * Vector3(0, 0, -0.2)
					t.rotation.y = yaw + PI
				else:
					t.position = Vector3(q.x + 0.5, 1.0, q.y + 0.5) + back * Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.15, 0.05))
					t.rotation.y = yaw + rng.randf_range(-0.5, 0.5)
				parent.add_child(t)


## Of the models for a kind, the one that fills the space best (ties broken by chance).
func _choose(names: Array, span: float, depth: float) -> Mesh:
	var best: Mesh = null
	var best_d := INF
	for nm in names:
		var m := piece(nm)
		if m == null:
			continue
		var bb := m.get_aabb()
		# how much it must shrink, plus how much room it leaves empty
		var shrink := maxf(0.0, maxf(bb.size.x / span, bb.size.z / depth) - 1.0)
		var empty := absf(span - bb.size.x) / span + absf(depth - bb.size.z) / depth * 0.5
		var d := shrink * 3.0 + empty + rng.randf() * 0.15
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
func _hang(name: String, x: int, y: int, inside: Vector2i, up: float, side: float) -> void:
	var m := piece(name)
	if m == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = m
	var yaw := atan2(float(inside.x), float(inside.y))
	var bb := m.get_aabb()
	var c := Vector3(x + 0.5, up, y + 0.5) + Vector3(inside.x, 0, inside.y) * (T / 2.0 + bb.size.z / 2.0 + 0.005)
	c += Basis(Vector3.UP, yaw) * Vector3(side, 0, 0)
	mi.position = c
	mi.rotation.y = yaw
	if wall_kind.has(Vector2i(x, y)):
		_attach(x, y, mi)
	else:
		parent.add_child(mi)


## Paintings, clocks, mirrors, shelves and lights on the walls: along each room's back walls (the ones the camera
## looks at) and side walls, where nothing tall stands in front.
func _wall_decor() -> void:
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
				if c in [MapGen.SHELF, MapGen.BOOKSHELF, MapGen.BOARD, MapGen.TERMINAL, MapGen.HEALER, MapGen.FIREPLACE, MapGen.COUNTER] \
						or front_kind in ["fridge", "wardrobe", "pantry", "storage", "bookshelf", "shelf", "dresser", "coat_stand", "bunk"]:
					continue
				# never two things side by side
				if hung.has(Vector2i(x, y) + along) or hung.has(Vector2i(x, y) - along):
					continue
				var before := parent.get_child_count() + (rows[y] as Node3D).get_child_count() if rows.has(y) else parent.get_child_count()
				var roll := rng.randf()
				match z:
					"bathroom":
						if front_kind == "basin":
							_hang("mirror", x, y, inside, 1.15, 0.0)
						elif roll < 0.25:
							_hang("wall_shelf", x, y, inside, 1.5, 0.0)
					"kitchen":
						if front_kind in ["counter", "kitchen_sink"] and roll < 0.45:
							_hang("wall_shelf_2", x, y, inside, 1.25, 0.0)
						elif front_kind == "" and roll < 0.2:
							_hang("clock", x, y, inside, 1.75, 0.0)
					"back", "stone":
						if roll < 0.08:
							_hang("breaker_box", x, y, inside, 1.3, 0.0)
					_:
						if roll < 0.22:
							_hang(["painting_1", "painting_2", "painting_3", "painting_4", "painting_5"][rng.randi_range(0, 4)], x, y, inside, 1.35, 0.0)
						elif roll < 0.3:
							_hang("clock", x, y, inside, 1.8, 0.0)
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
					l.light_color = Color(ZONES.get(z, ZONES["shop"])["light"])
					l.light_energy = 0.7
					l.omni_range = maxf(size.x / nx, size.y / nz) * 0.9 + 2.0
					l.position = Vector3(lo.x + size.x * (i + 0.5) / nx, 2.4, lo.y + size.y * (j + 0.5) / nz)
					parent.add_child(l)
					lights.append(l)
