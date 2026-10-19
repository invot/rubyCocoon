extends Node3D
## The voxel overworld: block terrain, voxel trees/props from the asset pack, procedural voxel
## buildings, people and beasts. Also renders building interiors (map kind "interior").

const MapGen = preload("res://scripts/world/map_gen.gd")
const MapLoader = preload("res://scripts/world/map_loader.gd")
const Terrain = preload("res://scripts/world/terrain_mesh.gd")
const WorldDB = preload("res://scripts/data/world_db.gd")
const RaceDB = preload("res://scripts/data/race_db.gd")
const ItemDB = preload("res://scripts/data/item_db.gd")
const VA = preload("res://scripts/gfx/voxel_assets.gd")
const VB = preload("res://scripts/gfx/voxel_beast.gd")
const VP = preload("res://scripts/gfx/voxel_props.gd")
const VPer = preload("res://scripts/gfx/voxel_person.gd")
const VBld = preload("res://scripts/gfx/voxel_buildings.gd")
const HouseModels = preload("res://scripts/gfx/house_models.gd")
const RoomBuilder = preload("res://scripts/gfx/room_builder.gd")
const VT = preload("res://scripts/gfx/voxel_textures.gd")
const PixelArt = preload("res://scripts/gfx/pixel_art.gd")
const UIKit = preload("res://scripts/ui/ui_kit.gd")

## The camera sits behind and above the player, looking down at about 32 degrees outdoors and 29 indoors (lower and
## closer than a top-down view, so walls and buildings are seen from the front, as in the PS2 games).
const CAM_OFFSET := Vector3(0, 7.0, 11.0)
const CAM_OFFSET_ROOM := Vector3(0, 4.6, 8.2)
## the point the camera looks at, above the player's feet
const CAM_LOOK_Y := 1.0
## Rugs are woven kilims from the seamless pattern sheet (tools/build_patterns.py): each room gets the one closest to
## its rug colour.
const RUG_PATTERNS := {"rug_red": "#c8283a", "rug_wine": "#7a2030", "rug_gold": "#d8901a", "rug_tribal": "#a83020",
	"rug_blue": "#2a7ac0", "rug_navy": "#2a2a48", "rug_green": "#4a8a3a", "rug_teal": "#1a8a7a"}
const PROP_CODES := [MapGen.ALTAR, MapGen.BOARD, MapGen.TERMINAL, MapGen.EXHIBIT, MapGen.BOOKSHELF, MapGen.SHELF,
	MapGen.ORGAN, MapGen.CRYSTAL, MapGen.BED, MapGen.FIREPLACE, MapGen.FOUNTAIN, MapGen.PLANT, MapGen.COUNTER, MapGen.TABLE,
	MapGen.HEALER, MapGen.INCUBATOR, MapGen.KENNEL, MapGen.FURN, MapGen.LOCKED]

var map: Dictionary
var map_id := ""
var biome: Dictionary
var demo := false
var interior := false

var player: Node3D
var player_pos := Vector2i.ZERO
var facing := Vector2i(0, 1)
var moving := false
var move_from := Vector3.ZERO
var move_to := Vector3.ZERO
var move_t := 0.0
var move_speed := 4.5
var anim_t := 0.0
## 0..1: how far into the walk cycle the limbs are swinging (eases in instead of snapping)
var _stride := 0.0
var cam: Camera3D
var cam_target := Vector3.ZERO
var busy := false
var frozen := false

var npcs := {}
var items := {}
var shards := {}
var doors := {}
var obstacle_nodes := {}
## push-puzzle blocks: tile -> {"kind": "boulder" / "ice", "node"}
var pushables := {}
var rock_tops := {}
## Tiles a house from the PSX pack leans over (trees and hedges beside or behind its plot): nothing grows there.
var house_cover := {}
## Test harness: the camera is placed by hand (main.gd --overview) and stops following the player.
var cam_free := false
var building_fades: Array = []
var water_mats: Array = []
var spinners: Array = []
var bobbers: Array = []
## Beast Center machines: "healer" / "incubator" -> {"node", "window", "slots", "dome", "pos"}
var machines := {}
var _time := 0.0
var _demo_t := 0.0


func build(id: String) -> void:
	map_id = id
	ground_h = {}
	map = MapLoader.load_map(id, GameState.flags)
	biome = map["biome"]
	interior = map["kind"] == "interior"
	for n in Story.extra_npcs(map):
		map["npcs"].append(n)
	if interior:
		_build_room()
		refresh_kennel()
	else:
		_build_environment()
		_build_terrain()
		_plan_houses()
		_build_scatter()
		_build_backdrop()
		_build_buildings()
		if map["kind"] == "town":
			_build_street_props()
		_build_statue()
		_build_obstacles()
		_build_pushables()
	_build_npcs()
	_build_items()
	_build_player()
	_build_camera()
	_spawn_wilds.call_deferred()


func spawn_at(key, face := Vector2i.ZERO) -> void:
	var p := Vector2i(-1, -1)
	if typeof(key) == TYPE_VECTOR2I:
		p = key
	elif map["spawns"].has(key):
		p = map["spawns"][key]
	if p.x < 0 or not _walkable(p):
		p = map["spawns"].get("start", map["spawns"].values()[0] if map["spawns"].size() > 0 else Vector2i(map["w"] / 2, map["h"] / 2))
	player_pos = p
	match str(key):
		"north":
			facing = Vector2i(0, 1)
		"south":
			facing = Vector2i(0, -1)
		"west":
			facing = Vector2i(1, 0)
		"east":
			facing = Vector2i(-1, 0)
		"entry":
			facing = Vector2i(0, -1)
		"wake":
			facing = Vector2i(0, 1)
		_:
			facing = GameState.facing if typeof(key) == TYPE_VECTOR2I else Vector2i(0, 1)
	if face != Vector2i.ZERO:
		facing = face
	# (a game saved while walking eight ways may still face a diagonal)
	facing = _four_way(facing)
	player.position = tile_pos(player_pos)
	VPer.face(player, facing)
	cam_target = player.position
	_place_camera(true)


func tile_pos(p: Vector2i) -> Vector3:
	return Vector3(p.x + 0.5, float(ground_h.get(p, 0.0)), p.y + 0.5)


## Tiles raised off the ground, by how much: a porch's deck or a stoop (see house_models.gd steps()), stepped up onto.
var ground_h := {}


# ================================================================ helpers
func _tex_mat(t: Texture2D, world_triplanar := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = t
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.roughness = 1.0
	if world_triplanar:
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
	return m


## Outdoors, batches are split into CHUNK x CHUNK tile squares so the camera (and each shadow pass) only draws the
## squares it can see. One map-wide batch would be drawn in full every frame, however little of it is on screen.
const CHUNK := 8


func _multimesh(mesh: Mesh, xforms: Array, mat: Material = null, shadows := true) -> MultiMeshInstance3D:
	if xforms.is_empty():
		return null
	if interior:
		return _multimesh_one(mesh, xforms, mat, shadows)
	var groups := {}
	for xf in xforms:
		var o: Vector3 = (xf as Transform3D).origin
		var key := Vector2i(floori(o.x / CHUNK), floori(o.z / CHUNK))
		if not groups.has(key):
			groups[key] = []
		groups[key].append(xf)
	var first: MultiMeshInstance3D = null
	for key in groups:
		var mi := _multimesh_one(mesh, groups[key], mat, shadows)
		if first == null:
			first = mi
	return first


func _multimesh_one(mesh: Mesh, xforms: Array, mat: Material, shadows: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	if mat:
		mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _xf(pos: Vector3, rot_y := 0.0, s := 1.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, rot_y).scaled(Vector3(s, s, s)), pos)


func _voxel_rot(rng: RandomNumberGenerator) -> float:
	return rng.randi_range(0, 3) * PI / 2.0


func _sandy() -> bool:
	return biome["id"] in ["desert", "mesa", "western"]


# ================================================================ environment
func _build_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(biome["sky_top"])
	sm.sky_horizon_color = Color(biome["sky_hz"])
	sm.ground_bottom_color = Color(biome["side"]).darkened(0.4)
	sm.ground_horizon_color = Color(biome["sky_hz"])
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(biome["sky_top"]).lerp(Color(biome["ground"]), 0.35)
	env.ambient_light_energy = biome["amb"]
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.2
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_hdr_threshold = 0.9
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.6
	env.fog_enabled = true
	env.fog_light_color = Color(biome["sky_hz"])
	env.fog_density = float(biome.get("fog", 0.0015))
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(biome["sun"])
	sun.light_energy = biome["sun_e"]
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	# two shadow splits over what the camera can actually see (four splits out to 45 drew every tree five times)
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 30.0
	sun.rotation_degrees = Vector3(-52, 28, 0)
	add_child(sun)


# ================================================================ terrain
## The ground is one low-poly height field (terrain_mesh.gd): flat where people walk, sloping down into river beds
## and lava, rising into faceted rock. Town walls and push-puzzle rocks stand on it as stone blocks.
func _build_terrain() -> void:
	var w: int = map["w"]
	var h: int = map["h"]
	var t := Terrain.new()
	t.setup(w, h, map_id.hash())
	var planks := []
	var walls := []
	var puzzle_rocks := []
	var log_tiles := {}
	for tiles in map.get("log_bridges", []):
		for q in tiles:
			log_tiles[q] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = map_id.hash()
	for y in h:
		for x in w:
			var c := MapGen.get_t(map, x, y)
			var center := Vector3(x + 0.5, 0, y + 0.5)
			var top := 0.0
			var kind := "grass"
			var liquid := 0
			var craggy := false
			if c in [MapGen.LAMP, MapGen.SIGN]:
				# a lamp post or a signpost stands on whatever ground is around it
				c = MapLoader._infer_floor(map, Vector2i(x, y))
			match c:
				MapGen.PATH, MapGen.DOOR:
					kind = "path"
				MapGen.PLAZA, MapGen.STATUE:
					kind = "plaza"
				MapGen.SAND:
					kind = "sand"
				MapGen.ICE:
					kind = "ice"
				MapGen.WATER, MapGen.BRIDGE:
					top = -0.42
					kind = "bed"
					liquid = 1
					if c == MapGen.BRIDGE and not log_tiles.has(Vector2i(x, y)):
						planks.append(_xf(center + Vector3(0, 0.03, 0)))
				MapGen.LAVA:
					top = -0.3
					kind = "lava_bed"
					liquid = 2
				MapGen.ROCK:
					top = rng.randf_range(0.9, 1.5)
					kind = "rock"
					craggy = true
					if map.has("puzzle_area") and (map["puzzle_area"] as Rect2i).has_point(Vector2i(x, y)):
						# a maze wall: a squared-off stone block on flat ground, so the maze reads clearly
						top = 1.0
						puzzle_rocks.append(center)
					rock_tops[Vector2i(x, y)] = top
				MapGen.WALL:
					kind = "paving"
					walls.append(center)
				MapGen.OBSTACLE:
					var grp: Dictionary = map["obstacles"].get(Vector2i(x, y), {})
					if grp.get("kind", "") == "broken_bridge":
						top = -0.42
						kind = "bed"
						liquid = 1
					elif grp.get("kind", "") == "chasm":
						top = -1.6
						kind = "rock"
						craggy = true
					elif grp.get("kind", "") == "sand":
						kind = "sand"
			if _sandy() and kind == "grass":
				kind = "sand"
			var ground_top := 0.0 if c == MapGen.WALL or puzzle_rocks.has(center) else top
			t.set_tile(x, y, kind, ground_top, craggy and ground_top > 0.0 or c == MapGen.OBSTACLE and kind == "rock", liquid)
	# the crags take on a little of the local soil: grey on the coast, ochre in the desert, near black by the volcano
	var rock_hex := Color("#8a8478").lerp(Color(biome["side"]).lightened(0.15), 0.55).to_html(false) if biome["id"] != "volcano" else "#4a3e3a"
	var tints := []
	for layer in VT.GROUND_LAYERS:
		tints.append(Color({"grass": biome["ground"], "path": biome["path"], "plaza": biome["plaza"], "sand": biome["sand"],
			"rock": rock_hex, "bed": Color(biome["sand"]).darkened(0.35).to_html(false), "lava_bed": "#3a2a28",
			"paving": "#9a948a", "ice": "#cfeaf6"}[layer]))
	t.build(self, tints, Color(biome["water"]))
	var wk := VBld.Kit.new()
	wk.box("stone", Vector3(0, 0.8, 0), Vector3(1.0, 1.6, 1.0), Color("#b8b0a0"))
	wk.box("stone", Vector3(0, 1.66, 0), Vector3(1.06, 0.12, 1.06), Color("#cfc7b6"))
	var wx := []
	for c in walls:
		wx.append(_xf(c))
	_multimesh(wk.mesh(), wx)
	var rk := VBld.Kit.new()
	rk.box("ground_rock", Vector3(0, 0.45, 0), Vector3(0.96, 0.9, 0.96), Color(rock_hex))
	rk.box("ground_rock", Vector3(0.04, 0.95, -0.03), Vector3(0.8, 0.12, 0.8), Color(rock_hex).lightened(0.08))
	var rx := []
	for c in puzzle_rocks:
		rx.append(_xf(c, _voxel_rot(rng)))
	_multimesh(rk.mesh(), rx)
	var pb := BoxMesh.new()
	pb.size = Vector3(1.0, 0.1, 1.0)
	# a plain box has no vertex colours, so the plank texture gets its wood colour here
	var pm: StandardMaterial3D = VT.material("planks").duplicate()
	pm.vertex_color_use_as_albedo = false
	pm.albedo_color = Color("#a8784a")
	_multimesh(pb, planks, pm, true)


# ================================================================ backdrop
## What lies past the edge of the map, so no edge or corner of it ever shows: the ground running on (the terrain
## itself carries on Terrain.MARGIN tiles), and a ring of scenery nobody can reach, dressed to suit the edge it borders:
##   land edges: a deep wood of the biome's trees to the north and the sides (lower detail: no shadows past the first
##   row), only shrubs, bushes and rocks to the south, between the camera and the map, so nothing hides the player;
##   beaches: a few palms or rocks; water and lava: nothing (the sea runs on); exits: kept clear, so the road leads on.
## Around towns, a few larger houses of the town's style stand among the trees beyond the edge (house_models.gd).
## Then big hills on the horizon to the north, softened by the fog.
const RING := 15


func _build_backdrop() -> void:
	var w: float = map["w"]
	var h: float = map["h"]
	var rng := RandomNumberGenerator.new()
	rng.seed = map_id.hash() + 99
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(w + 120.0, h + 120.0)
	ground.mesh = plane
	var layer := "top_sand" if _sandy() else "top_grass"
	var gm := _tex_mat(VT.terrain(layer, String(biome["sand"] if _sandy() else biome["ground"])), true)
	ground.material_override = gm
	# below the water and lava beds (the terrain itself carries on MARGIN tiles past the edge): any higher and it
	# covers every sea and river on the map
	ground.position = Vector3(w / 2.0, -0.7, h / 2.0)
	add_child(ground)
	var trees: Array = biome["trees"]
	var shrubs: Array = biome["shrubs"]
	var rocks: Array = biome["rocks"]
	var by_asset := {}
	var taken := {}
	if map["kind"] == "town":
		_outskirt_houses(rng, taken)
	var iw := int(w)
	var ih := int(h)
	for tz in range(-RING, ih + RING):
		for tx in range(-RING, iw + RING):
			if tx >= 0 and tz >= 0 and tx < iw and tz < ih:
				continue
			if taken.has(Vector2i(tx, tz)):
				continue
			var depth := maxi(maxi(-tx, tx - iw + 1), maxi(-tz, tz - ih + 1))
			var edge := MapGen.get_t(map, clampi(tx, 0, iw - 1), clampi(tz, 0, ih - 1))
			if edge in [MapGen.WATER, MapGen.LAVA, MapGen.BRIDGE]:
				continue
			# an exit: the road leads on, clear
			if MapGen.walkable(edge) and edge != MapGen.SAND:
				continue
			# just south of a road leading out at the sides, low things only too, so the road stays in plain sight
			var south := tz >= ih or _side_road_behind(tx, tz)
			var c := Vector3(tx + 0.5 + rng.randf_range(-0.3, 0.3), 0.0, tz + 0.5 + rng.randf_range(-0.3, 0.3))
			var shadow := depth <= 1
			if edge == MapGen.SAND:
				# a beach running on: a palm or a rock here and there
				if rng.randf() < 0.1:
					_ring_rock(by_asset, rocks, c, rng, 0.5, 0.9)
				elif rng.randf() < 0.12 and not south:
					_ring_tree(by_asset, trees, c, rng, 2.4, 3.4, shadow)
				continue
			if south:
				# between the camera and the map: low things only
				if depth > 9:
					continue
				var roll := rng.randf()
				if roll < 0.5:
					_ring_shrub(by_asset, shrubs, c, rng, 0.6, 1.1)
				elif roll < 0.62:
					_ring_rock(by_asset, rocks, c, rng, 0.5, 0.8)
				continue
			if trees.is_empty():
				# open country (the desert): rocks and scrub
				if rng.randf() < 0.25:
					_ring_rock(by_asset, rocks, c, rng, 0.7, 1.4)
				elif rng.randf() < 0.2:
					_ring_shrub(by_asset, shrubs, c, rng, 0.5, 0.9)
				continue
			# a wood: thick near the map, a little thinner deep in (the fog takes over there)
			if rng.randf() < (0.8 if depth <= 6 else 0.6):
				_ring_tree(by_asset, trees, c, rng, 2.4, 4.0, shadow)
			elif depth <= 2 and rng.randf() < 0.5:
				_ring_shrub(by_asset, shrubs, c, rng, 0.6, 1.0)
	for name in by_asset:
		_multimesh(VA.mesh(String(name).trim_suffix(SHADOWLESS)), by_asset[name], null, not String(name).ends_with(SHADOWLESS))
	# hills on the horizon
	var hills := ["mountain_0", "mountain_2", "mountain_4", "mountain_6", "mountain_8"]
	var hx := -20.0
	while hx < w + 20.0:
		var name: String = hills[rng.randi_range(0, hills.size() - 1)]
		var mi := MeshInstance3D.new()
		mi.mesh = VA.mesh(name)
		if mi.mesh != null:
			var bb2: AABB = mi.mesh.get_aabb()
			var sc2 := rng.randf_range(14.0, 22.0) / maxf(bb2.size.x, 0.01)
			mi.scale = Vector3(sc2, sc2 * rng.randf_range(0.6, 1.0), sc2)
			mi.position = Vector3(hx, -bb2.position.y * mi.scale.y - 0.5, rng.randf_range(-48.0, -36.0))
			mi.rotation.y = rng.randf() * TAU
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
		hx += rng.randf_range(12.0, 18.0)


## True past the east or west edge within three rows south of a road leading out on that side (the camera looks north,
## so anything tall there would stand in front of it).
func _side_road_behind(tx: int, tz: int) -> bool:
	var iw: int = map["w"]
	if tx >= 0 and tx < iw:
		return false
	var ex := 0 if tx < 0 else iw - 1
	for dz in range(1, 4):
		var e := MapGen.get_t(map, ex, tz - dz)
		if tz - dz >= 0 and MapGen.walkable(e) and e != MapGen.SAND:
			return true
	return false


func _ring_tree(by_asset: Dictionary, trees: Array, c: Vector3, rng: RandomNumberGenerator, lo: float, hi: float, shadow: bool) -> void:
	if trees.is_empty():
		return
	var name := _pick_weighted(trees, rng)
	var bb := VA.aabb(name)
	var sc := VA.fit_scale(name, rng.randf_range(lo, hi))
	_add_asset(by_asset, name if shadow else name + SHADOWLESS, _xf(c - Vector3(0, bb.position.y * sc, 0), rng.randf() * TAU, sc))


func _ring_shrub(by_asset: Dictionary, shrubs: Array, c: Vector3, rng: RandomNumberGenerator, lo: float, hi: float) -> void:
	if shrubs.is_empty():
		return
	var name: String = shrubs[rng.randi_range(0, shrubs.size() - 1)]
	var sc := VA.fit_scale(name, rng.randf_range(lo, hi))
	_add_asset(by_asset, name + SHADOWLESS, _xf(c - Vector3(0, VA.aabb(name).position.y * sc, 0), rng.randf() * TAU, sc))


func _ring_rock(by_asset: Dictionary, rocks: Array, c: Vector3, rng: RandomNumberGenerator, lo: float, hi: float) -> void:
	if rocks.is_empty():
		return
	var name: String = rocks[rng.randi_range(0, rocks.size() - 1)]
	var sc := VA.fit_scale(name, -1.0, rng.randf_range(lo, hi))
	_add_asset(by_asset, name + SHADOWLESS, _xf(c - Vector3(0, VA.aabb(name).position.y * sc, 0), rng.randf() * TAU, sc))


## A few of the town's larger houses just past the north edge and the sides, behind the trees, so the town seems to
## carry on beyond what you can walk; their tiles are marked in `taken` so no tree grows through them.
func _outskirt_houses(rng: RandomNumberGenerator, taken: Dictionary) -> void:
	if not HouseModels.available():
		return
	var style: String = biome.get("style", "town")
	var w: int = map["w"]
	var h: int = map["h"]
	var spots := []
	# along the north, every 9 tiles or so, a few tiles back
	var x := rng.randi_range(2, 6)
	while x < w - 2:
		spots.append(Vector2(x, -rng.randf_range(5.0, 7.0)))
		x += rng.randi_range(8, 12)
	# down the sides, beside the northern half of the town
	for side in [-1, 1]:
		var z := rng.randf_range(2.0, 5.0)
		while z < h * 0.55:
			spots.append(Vector2(-5.5 if side < 0 else w + 5.5, z))
			z += rng.randf_range(9.0, 12.0)
	for p in spots:
		var made := HouseModels.backdrop(style, rng)
		var node: Node3D = made[0]
		if node == null:
			continue
		var r: float = made[1]
		# not over the sea or a road out of town: every edge tile along the house's width (and a tile more) must be
		# woodland; down the sides, nor in front of a road leading out (the camera looks north, so a house a little south
		# of a road hides it)
		var clear := true
		var lo := int(floor((p.x if p.y < 0.0 else p.y) - r - 1.0))
		var hi := int(ceil((p.x if p.y < 0.0 else p.y) + r + 1.0))
		for i in range(lo, hi + 1):
			var et := Vector2i(clampi(i, 0, w - 1), 0) if p.y < 0.0 else Vector2i(0 if p.x < 0.0 else w - 1, clampi(i, 0, h - 1))
			var edge := MapGen.get_t(map, et.x, et.y)
			if edge in [MapGen.WATER, MapGen.LAVA, MapGen.BRIDGE, MapGen.SAND] or MapGen.walkable(edge):
				clear = false
		if p.y >= 0.0:
			for z in range(maxi(0, int(p.y - r - 10.0)), mini(h, int(p.y) + 1)):
				var e2 := MapGen.get_t(map, 0 if p.x < 0.0 else w - 1, z)
				if MapGen.walkable(e2) and e2 != MapGen.SAND:
					clear = false
		if not clear:
			node.free()
			continue
		node.position = Vector3(p.x, 0.0, p.y)
		# facing the town
		if p.y < 0.0:
			node.rotation.y = 0.0
		else:
			node.rotation.y = PI / 2.0 if p.x < 0.0 else -PI / 2.0
		add_child(node)
		for tz in range(int(p.y - r - 1.0), int(p.y + r + 2.0)):
			for tx in range(int(p.x - r - 1.0), int(p.x + r + 2.0)):
				taken[Vector2i(tx, tz)] = true


# ================================================================ scatter: grass, trees, rocks, props
func _pick_weighted(list: Array, rng: RandomNumberGenerator) -> String:
	var total := 0
	for e in list:
		total += int(e[1])
	var r := rng.randi_range(1, maxi(1, total))
	for e in list:
		r -= int(e[1])
		if r <= 0:
			return e[0]
	return list[0][0]


const SHADOWLESS := "|noshadow"


## True if anyone could walk within `r` tiles of (x, y).
func _open_ground_near(x: int, y: int, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if (dx != 0 or dy != 0) and MapGen.walkable(MapGen.get_t(map, x + dx, y + dy)):
				return true
	return false


func _add_asset(by_asset: Dictionary, name: String, xf: Transform3D) -> void:
	if not by_asset.has(name):
		by_asset[name] = []
	by_asset[name].append(xf)


func _build_scatter() -> void:
	var w: int = map["w"]
	var h: int = map["h"]
	var rng := RandomNumberGenerator.new()
	rng.seed = map_id.hash() + 7
	var tuft_hex: String = biome["tuft"]
	var tufts := [[], [], []]
	var flowers := [[], []]
	var by_asset := {}
	var bushes := []
	var fences := []
	var lamps := []
	var signs := []
	var ladders := []
	var trees: Array = biome["trees"]
	var rocks: Array = biome["rocks"]
	var shrubs: Array = biome["shrubs"]
	for y in h:
		for x in w:
			var c := MapGen.get_t(map, x, y)
			var center := Vector3(x + 0.5, 0, y + 0.5)
			if house_cover.has(Vector2i(x, y)):
				# a house leans over this tree or hedge
				continue
			match c:
				MapGen.TALL:
					for k in 2:
						tufts[rng.randi_range(0, 2)].append(_xf(center + Vector3(rng.randf_range(-0.22, 0.22), 0, -0.2 + k * 0.38), _voxel_rot(rng), rng.randf_range(0.9, 1.15)))
				MapGen.FLOWERS:
					flowers[rng.randi_range(0, 1)].append(_xf(center, _voxel_rot(rng)))
				MapGen.TREE:
					var name := _pick_weighted(trees, rng)
					var hgt := rng.randf_range(2.2, 3.1)
					if y >= h - 3:
						name = shrubs[rng.randi_range(0, shrubs.size() - 1)]
						hgt = rng.randf_range(0.7, 1.0)
					var bb := VA.aabb(name)
					var s := VA.fit_scale(name, hgt)
					if maxf(bb.size.x, bb.size.z) * s > 2.4:
						s = 2.4 / maxf(bb.size.x, bb.size.z)
					# deep in a wood, a tree's shadow only falls on other trees: only trees near open ground cast one
					var key := name if _open_ground_near(x, y, 2) else name + SHADOWLESS
					_add_asset(by_asset, key, _xf(center + Vector3(rng.randf_range(-0.1, 0.1), -bb.position.y * s, rng.randf_range(-0.1, 0.1)), _voxel_rot(rng), s))
				MapGen.BUSH:
					bushes.append(_xf(center, _voxel_rot(rng), rng.randf_range(0.8, 1.1)))
				MapGen.ROCK:
					if rng.randf() < 0.35 and not (map.has("puzzle_area") and (map["puzzle_area"] as Rect2i).has_point(Vector2i(x, y))):
						var rn: String = rocks[rng.randi_range(0, rocks.size() - 1)]
						var top: float = rock_tops.get(Vector2i(x, y), 1.0)
						var s2 := VA.fit_scale(rn, -1.0, rng.randf_range(0.7, 1.0))
						_add_asset(by_asset, rn, _xf(center + Vector3(0, top - VA.aabb(rn).position.y * s2, 0), _voxel_rot(rng), s2))
				MapGen.GRASS:
					# town lawns: a patch of flowers here and there (only to look at; you can walk through them)
					if map["kind"] == "town" and rng.randf() < 0.07 and not _sandy():
						flowers[rng.randi_range(0, 1)].append(_xf(center + Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2)), _voxel_rot(rng), rng.randf_range(0.6, 0.9)))
					elif rng.randf() < 0.05 and not shrubs.is_empty():
						var sn: String = shrubs[rng.randi_range(0, shrubs.size() - 1)]
						var s3 := VA.fit_scale(sn, rng.randf_range(0.35, 0.6))
						_add_asset(by_asset, sn, _xf(center + Vector3(rng.randf_range(-0.3, 0.3), -VA.aabb(sn).position.y * s3, rng.randf_range(-0.3, 0.3)), _voxel_rot(rng), s3))
				MapGen.FENCE:
					fences.append(Vector2i(x, y))
				MapGen.LAMP:
					lamps.append(center)
				MapGen.ROPE:
					ladders.append(_xf(center + Vector3(0, 0.01, 0)))
				MapGen.SIGN:
					signs.append(center)
	for i in 3:
		# grass tufts are too small to need shadows
		_multimesh(VP.grass_tuft(tuft_hex, i), tufts[i], null, false)
	for i in 2:
		_multimesh(VP.flowers(i), flowers[i], null, false)
	_multimesh(VP.bush(Color(tuft_hex).darkened(0.12).to_html(false), 0), bushes)
	for name in by_asset:
		_multimesh(VA.mesh(String(name).trim_suffix(SHADOWLESS)), by_asset[name], null, not String(name).ends_with(SHADOWLESS))
	var fence_name := "iron_fence" if biome["id"] == "moor" else "fence"
	var fx := []
	var fs := VA.fit_scale(fence_name, -1.0, 1.05)
	for p in fences:
		var horiz := MapGen.get_t(map, p.x - 1, p.y) == MapGen.FENCE or MapGen.get_t(map, p.x + 1, p.y) == MapGen.FENCE
		fx.append(_xf(tile_pos(p) - Vector3(0, VA.aabb(fence_name).position.y * fs, 0), 0.0 if horiz else PI / 2.0, fs))
	_multimesh(VA.mesh(fence_name), fx)
	var lx := []
	# gas lamps a head and more above the people
	var ls := VA.fit_scale("lamp", 2.8)
	var gloomy: bool = float(biome.get("sun_e", 1.3)) < 1.0
	for c in lamps:
		lx.append(_xf(c, 0.0, ls))
		if not gloomy:
			continue
		var l := OmniLight3D.new()
		l.light_color = Color("#ffd090")
		l.light_energy = 0.7
		l.omni_range = 4.0
		l.position = c + Vector3(0, 2.6, 0)
		add_child(l)
	_multimesh(VA.mesh("lamp"), lx)
	var sx := []
	for c in signs:
		sx.append(_xf(c))
	_multimesh(VP.signpost(), sx)
	_multimesh(VP.obstacle("rope_ladder"), ladders, null, false)


# ================================================================ buildings
## Plans every house (and scenery building) as a house from the PSX pack (house_models.gd), before the trees go in:
## a house may lean a little over the hedges and trees beside its plot and further over the wood behind it, so its
## L-plan, porch or wing has room, but never over a tile anyone can walk on. Those tiles stay clear of trees.
func _plan_houses() -> void:
	if not HouseModels.available():
		return
	var style: String = biome.get("style", "town")
	var used := {}
	for b in map["buildings"]:
		var shop: bool = b["shop"] in VBld.COMMERCIAL or b["shop"] in VBld.SIGNED_HOUSES
		if not b["shop"] in ["house", "home", "decor", "cabin"] and not shop:
			continue
		var x0: int = b["x"]
		var y0: int = b["y"]
		var w: int = b["w"]
		var d: int = b["d"]
		var room := {"left": _lean_room(x0 - 1, -1, y0, y0 + d - 1), "right": _lean_room(x0 + w, 1, y0, y0 + d - 1), "back": 0.0}
		var back := 0
		while back < 3 and _leanable_row(y0 - back - 1, x0, x0 + w - 1):
			back += 1
		room["back"] = float(back)
		var o := Vector2(float(x0) + float(w) / 2.0, float(y0) + float(d) / 2.0)
		var plan := {}
		# the house must stand only on its plot and on trees, hedges and rocks: if it would reach a path or another
		# building (leaning sideways and back at once), plan again with less room
		for attempt in 4:
			# (Kit's cabin is always a log cabin, whatever the road's style)
			plan = HouseModels.plan(b, "cabin" if b["shop"] == "cabin" else style, room, shop, used)
			if plan.is_empty() or _house_fits(plan["rect"], o, b):
				break
			room["back"] = maxf(0.0, float(room["back"]) - 1.0)
			room["left"] = minf(float(room["left"]), 0.45)
			room["right"] = minf(float(room["right"]), 0.45)
			plan = {}
		if plan.is_empty():
			continue
		b["house_plan"] = plan
		used[plan["key"]] = int(used.get(plan["key"], 0)) + 1
		# a porch's deck or a stoop lifts the tiles it covers: people step up onto it
		var pc: Dictionary = plan.get("steps", {})
		if not pc.is_empty():
			var pr: Rect2 = pc["rect"]
			for ty in range(floori(o.y + pr.position.y), ceili(o.y + pr.end.y)):
				for tx in range(floori(o.x + pr.position.x), ceili(o.x + pr.end.x)):
					var tc := Vector2(tx + 0.5, ty + 0.5) - o
					if pr.grow(-0.05).has_point(tc) and MapGen.walkable(MapGen.get_t(map, tx, ty)):
						ground_h[Vector2i(tx, ty)] = float(pc["y"])
		var r: Rect2 = plan["rect"]
		for ty in range(floori(o.y + r.position.y + 0.15), ceili(o.y + r.end.y - 0.15)):
			for tx in range(floori(o.x + r.position.x + 0.15), ceili(o.x + r.end.x - 0.15)):
				var c := MapGen.get_t(map, tx, ty)
				if c in [MapGen.TREE, MapGen.BUSH]:
					house_cover[Vector2i(tx, ty)] = true


## True if a planned house (rect: local to the plot's centre o) covers only its own plot and leanable tiles.
func _house_fits(r: Rect2, o: Vector2, b: Dictionary) -> bool:
	var plot := Rect2i(int(b["x"]), int(b["y"]), int(b["w"]), int(b["d"]))
	for ty in range(floori(o.y + r.position.y + 0.15), ceili(o.y + r.end.y - 0.15)):
		for tx in range(floori(o.x + r.position.x + 0.15), ceili(o.x + r.end.x - 0.15)):
			if plot.has_point(Vector2i(tx, ty)):
				continue
			# the door row's front edge may poke a step out over the street
			if ty >= plot.end.y:
				continue
			if not _leanable(tx, ty):
				return false
	return true


## How far a house may lean sideways from column x outwards (step -1 or 1) over trees and hedges: the whole run of
## leanable columns if open country lies beyond, but only half of it if another building stands there.
func _lean_room(x: int, step: int, y0: int, y1: int) -> float:
	var n := 0
	while n < 3 and _leanable_cols(x + n * step, y0, y1):
		n += 1
	if n == 0:
		return 0.0
	var beyond := x + n * step
	var next_is_building := false
	for y in range(y0, y1 + 1):
		if MapGen.get_t(map, beyond, y) in [MapGen.BUILDING, MapGen.DOOR]:
			next_is_building = true
	return float(n) * 0.5 - 0.1 if next_is_building else float(n) - 0.3


## True if nobody can walk on any tile of column x from row y0 to y1 (trees, hedges, rocks, or off the map).
func _leanable_cols(x: int, y0: int, y1: int) -> bool:
	for y in range(y0, y1 + 1):
		if not _leanable(x, y):
			return false
	return true


func _leanable_row(y: int, x0: int, x1: int) -> bool:
	for x in range(x0, x1 + 1):
		if not _leanable(x, y):
			return false
	return true


func _leanable(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= map["w"] or y >= map["h"]:
		return true
	return MapGen.get_t(map, x, y) in [MapGen.TREE, MapGen.BUSH, MapGen.ROCK]


func _build_buildings() -> void:
	var style: String = biome.get("style", "town")
	for b in map["buildings"]:
		if b["shop"] != "decor":
			doors[b["door"]] = b
		if b["shop"] in VBld.COMMERCIAL:
			b["height"] = VBld.shop_height(style)
		var node := _building_node(b, style)
		var meshes := []
		for c in node.find_children("*", "GeometryInstance3D", true, false):
			meshes.append(c)
		building_fades.append({"b": b, "meshes": meshes, "node": node})
		if b["shop"] == "skytower" and node.has_node("Bird"):
			bobbers.append([node.get_node("Bird"), (node.get_node("Bird") as Node3D).position.y, 1.3])
		for c in node.get_children():
			if c.has_meta("spin"):
				spinners.append(c)


## Street furniture from the packs (assets/psx/exterior) on the open ground beside the town's buildings: benches,
## bins, planters and crates outside shops, rain barrels, flower pots and hedges by houses, crates, barrels and
## dumpsters down the sides, air conditioners on city shop walls. Each takes a grass or plaza tile that touches a
## building's front or side (never the door's own row in front of it), and only if every street, door and way out of
## town can still be reached without it; the tile then stops being walkable.
const STREET_DIR := "res://assets/psx/exterior/"
const STREET_FRONT_SHOP := ["bench", "bench", "trash_can", "crate", "barrel", "planter", "hydrant"]
const STREET_FRONT_HOUSE := ["planter", "barrel", "hedge_round", "bench", "crate", "planter"]
const STREET_SIDE := ["barrel", "crate", "crate_open", "keg", "hedge_round", "barrel"]


func _street_mesh(name: String) -> Mesh:
	if name == "planter":
		return load("res://assets/psx/interior/plant_tall.res") if ResourceLoader.exists("res://assets/psx/interior/plant_tall.res") else null
	return load(STREET_DIR + name + ".res") if ResourceLoader.exists(STREET_DIR + name + ".res") else null


## Tiles anyone can reach from the town's start, walking.
func _reachable(start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var stack := [start]
	while not stack.is_empty():
		var q: Vector2i = stack.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var r: Vector2i = q + d
			if not seen.has(r) and r.x >= 0 and r.y >= 0 and r.x < map["w"] and r.y < map["h"] and MapGen.walkable(MapGen.get_t(map, r.x, r.y)):
				seen[r] = true
				stack.append(r)
	return seen


func _build_street_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = map_id.hash() + 31
	var style: String = biome.get("style", "town")
	var city: bool = WorldDB.TOWNS.get(map_id, {}).get("size", "") in ["town", "city"]
	var start: Vector2i = map["spawns"].get("start", map["spawns"].get("center", Vector2i(map["w"] / 2, map["h"] / 2)))
	if not MapGen.walkable(MapGen.get_t(map, start.x, start.y)):
		return
	var before := _reachable(start)
	# what must stay reachable: the tile in front of every door, every exit, every person and item
	var keep := []
	for b in map["buildings"]:
		keep.append(Vector2i(b["door"]) + Vector2i(0, 1))
	for t in map["exits"]:
		keep.append(t)
	for n in map["npcs"]:
		keep.append(n["pos"])
	for it in map["items"]:
		keep.append(it["pos"])
	keep = keep.filter(func(q): return before.has(q))
	var taken := {}
	for q in keep:
		taken[q] = true
	var placed := []
	for b in map["buildings"]:
		if b["shop"] in ["decor", "hideout", "temple"]:
			continue
		var commercial: bool = b["shop"] in VBld.COMMERCIAL or b["shop"] in ["center", "electronics", "arena", "museum", "music_hall", "dojo"]
		var bx: int = b["x"]
		var by: int = b["y"]
		var bw: int = b["w"]
		var bd: int = b["d"]
		var door: Vector2i = b["door"]
		var cands := []
		# along the front, either side of the door's own column
		for x in range(bx, bx + bw):
			if absi(x - door.x) >= 1:
				cands.append([Vector2i(x, by + bd), Vector2i(0, 1), "front"])
		# down both sides
		for y in range(by, by + bd):
			cands.append([Vector2i(bx - 1, y), Vector2i(-1, 0), "side"])
			cands.append([Vector2i(bx + bw, y), Vector2i(1, 0), "side"])
		var n_front := 0
		for c in cands:
			var t: Vector2i = c[0]
			if taken.has(t) or not MapGen.get_t(map, t.x, t.y) in [MapGen.GRASS, MapGen.PLAZA, MapGen.SAND]:
				continue
			if rng.randf() > (0.55 if c[2] == "front" else 0.35):
				continue
			if c[2] == "front" and n_front >= 2:
				continue
			# would it cut anything off?
			var was := MapGen.get_t(map, t.x, t.y)
			MapGen.set_t(map, t.x, t.y, MapGen.STREET_PROP)
			var after := _reachable(start)
			var ok := after.size() == before.size() - 1 if before.has(t) else after.size() == before.size()
			for q in keep:
				if not after.has(q):
					ok = false
					break
			if not ok:
				MapGen.set_t(map, t.x, t.y, was)
				continue
			before = after
			taken[t] = true
			var list: Array = STREET_SIDE if c[2] == "side" else (STREET_FRONT_SHOP if commercial else STREET_FRONT_HOUSE)
			var name: String = list[rng.randi_range(0, list.size() - 1)]
			if name == "hydrant" and not city:
				name = "trash_can"
			if c[2] == "side" and commercial and city and rng.randf() < 0.3:
				name = "dumpster"
			placed.append([t, c[1], name])
			if c[2] == "front":
				n_front += 1
	for e in placed:
		var t: Vector2i = e[0]
		var face: Vector2i = e[1]
		var mesh := _street_mesh(e[2])
		if mesh == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var bb := mesh.get_aabb()
		# its back to the building, a little away from the wall
		mi.rotation.y = atan2(float(face.x), float(face.y)) + (rng.randf_range(-0.25, 0.25) if e[2] in ["barrel", "crate", "crate_open", "keg", "planter"] else 0.0)
		var fit := minf(1.0, 0.92 / maxf(bb.size.x, bb.size.z))
		mi.scale = Vector3.ONE * fit
		mi.position = tile_pos(t) - Vector3(face.x, 0, face.y) * maxf(0.0, 0.5 - bb.size.z * fit / 2.0 - 0.05)
		add_child(mi)
		# a second crate on top now and then
		if e[2] in ["crate", "crate_open"] and rng.randf() < 0.4:
			var top := MeshInstance3D.new()
			top.mesh = _street_mesh("crate")
			top.scale = mi.scale * 0.85
			top.rotation.y = mi.rotation.y + rng.randf_range(-0.6, 0.6)
			top.position = mi.position + Vector3(0, bb.size.y * fit, 0)
			add_child(top)
	# air conditioners on the side walls of shops in bigger towns
	if city:
		var ac := _street_mesh("ac_unit")
		for b in map["buildings"]:
			if ac == null or not (b["shop"] in VBld.COMMERCIAL or b["shop"] in ["center", "electronics"]) or rng.randf() < 0.4:
				continue
			for sx in [-1, 1]:
				if rng.randf() < 0.5:
					continue
				var mi2 := MeshInstance3D.new()
				mi2.mesh = ac
				mi2.rotation.y = sx * PI / 2.0
				var x: float = float(b["x"]) + (float(b["w"]) + 0.02 if sx > 0 else -0.02) - sx * 0.1
				mi2.position = Vector3(x + sx * ac.get_aabb().size.z / 2.0, 1.9 + rng.randf_range(0, 2.4), float(b["y"]) + float(b["d"]) * rng.randf_range(0.3, 0.7))
				add_child(mi2)


## Builds and places one building; a locked door gets painted differently.
func _building_node(b: Dictionary, style: String) -> Node3D:
	var node: Node3D
	if b["shop"] == "decor":
		node = _decor_building(b, style)
	else:
		b["locked"] = Places.door_locked(b)
		node = VBld.build(b, style)
	node.position = Vector3(float(b["x"]) + float(b["w"]) / 2.0, 0, float(b["y"]) + float(b["d"]) / 2.0)
	add_child(node)
	return node


## Rebuilds any building whose door was unlocked since the map was built (the cathedral, once its guard falls).
func refresh_locks() -> void:
	if interior:
		return
	var style: String = biome.get("style", "town")
	for f in building_fades:
		var b: Dictionary = f["b"]
		if b["shop"] == "decor" or Places.door_locked(b) == bool(b.get("locked", false)):
			continue
		(f["node"] as Node3D).queue_free()
		var node := _building_node(b, style)
		f["node"] = node
		f["meshes"] = node.find_children("*", "GeometryInstance3D", true, false)


## Scenery houses nobody lives in: built like every other house in the town's style.
func _decor_building(b: Dictionary, style: String) -> Node3D:
	var bb := b.duplicate()
	bb["shop"] = "house"
	return VBld.build(bb, style)


func _build_statue() -> void:
	var st: Dictionary = map["statue"]
	if st.is_empty():
		return
	var p: Vector2i = st["pos"]
	var center := Vector3(p.x + 1.0, 0, p.y + 1.0)
	var k := VBld.Kit.new()
	k.box("stone", Vector3(0, 0.3, 0), Vector3(1.8, 0.6, 1.8), Color("#c8c0b0"))
	k.box("stone", Vector3(0, 0.65, 0), Vector3(1.5, 0.1, 1.5), Color("#e8c060"))
	var ped := MeshInstance3D.new()
	ped.mesh = k.mesh()
	ped.position = center
	add_child(ped)
	var mi := MeshInstance3D.new()
	mi.mesh = VB.mesh(RaceDB.genes(int(st["race"])))
	mi.scale = Vector3(1.5, 1.5, 1.5)
	mi.rotation.y = -PI / 2.0 + 0.4
	mi.position = center + Vector3(0, 0.7, 0)
	add_child(mi)


func _build_obstacles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = map_id.hash() + 3
	for p in map["obstacles"]:
		var grp: Dictionary = map["obstacles"][p]
		var kind: String = grp["kind"]
		if kind == "broken_bridge":
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = VP.obstacle(kind if kind != "fog" else "dust", rng.randi_range(0, 1))
		mi.position = tile_pos(p) + (Vector3(0, -1.6, 0) if kind == "chasm" else (Vector3(0, -0.13, 0) if kind == "broken_bridge" else Vector3.ZERO))
		if kind in ["boulder", "driftwood", "sand"]:
			mi.rotation.y = _voxel_rot(rng)
		if kind == "fog":
			mi.material_override = _fog_mat()
		if kind in ["dust", "fog"]:
			spinners.append(mi)
		add_child(mi)
		obstacle_nodes[p] = mi
	_build_log_bridges()
	for p in map.get("gate_tiles", []):
		var g := MeshInstance3D.new()
		g.mesh = VP.obstacle("gate")
		g.position = tile_pos(p)
		add_child(g)
		obstacle_nodes[p] = g


# ---------------------------------------------------------------- the log footbridge (Coastal Path)
## Logs laid across a creek side by side, each one fetched from along the path (see Story._item_obstacle).
var _log_bridge_nodes := {}


func _build_log_bridges() -> void:
	for tiles in map.get("log_bridges", []):
		_lay_logs(tiles, _logs_needed(), "")
	var seen := {}
	for p in map["obstacles"]:
		var grp: Dictionary = map["obstacles"][p]
		if grp["kind"] == "broken_bridge" and not seen.has(grp["flag"]):
			seen[grp["flag"]] = true
			_lay_logs(grp["tiles"], int(GameState.flags.get(grp["flag"] + "_logs", 0)), grp["flag"])


func _logs_needed() -> int:
	return int(WorldDB.OBSTACLES["n"].get("need", 5))


func _bridge_rect(tiles: Array) -> Rect2i:
	var r := Rect2i(tiles[0], Vector2i.ONE)
	for q in tiles:
		r = r.expand(q).expand(q + Vector2i.ONE)
	return r


## Log `i`: logs span the creek in the direction you cross it and lie side by side. Returns [transform, length].
func _log_slot(tiles: Array, i: int) -> Array:
	var r := _bridge_rect(tiles)
	var n := _logs_needed()
	var y := -0.38
	if MapGen.get_t(map, r.position.x - 1, r.position.y) != MapGen.WATER:
		# crossed east-west: each log runs along x
		var step := float(r.size.y) / n
		return [Transform3D(Basis.IDENTITY, Vector3(r.position.x + r.size.x / 2.0, y, r.position.y + step * (i + 0.5))), r.size.x * 16 + 2]
	var step2 := float(r.size.x) / n
	return [Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(r.position.x + step2 * (i + 0.5), y, r.position.y + r.size.y / 2.0)), r.size.y * 16 + 2]


func _lay_logs(tiles: Array, placed: int, key: String) -> void:
	var holder := Node3D.new()
	add_child(holder)
	if key != "":
		_log_bridge_nodes[key] = holder
	# a stout post at each corner of the old bridge
	var r := _bridge_rect(tiles)
	var k := VBld.Kit.new()
	for cx in [r.position.x, r.end.x]:
		for cz in [r.position.y, r.end.y]:
			k.box("color", Vector3(cx, 0.0, cz), Vector3(0.22, 0.9, 0.22), Color("#5a3c22"))
	var posts := MeshInstance3D.new()
	posts.mesh = k.mesh()
	holder.add_child(posts)
	for i in mini(placed, _logs_needed()):
		var slot := _log_slot(tiles, i)
		var lg := MeshInstance3D.new()
		lg.mesh = VP.log_mesh(int(slot[1]), 3.4)
		lg.transform = slot[0]
		holder.add_child(lg)


## Drops log number `placed` into its place with a bounce.
func place_bridge_log(grp: Dictionary, placed: int) -> void:
	var holder: Node3D = _log_bridge_nodes.get(grp["flag"], null)
	if holder == null:
		return
	var slot := _log_slot(grp["tiles"], placed - 1)
	var lg := MeshInstance3D.new()
	lg.mesh = VP.log_mesh(int(slot[1]), 3.4)
	lg.transform = slot[0]
	lg.position.y += 1.6
	holder.add_child(lg)
	var tw := create_tween()
	tw.tween_property(lg, "position:y", (slot[0] as Transform3D).origin.y, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await tw.finished


func _fog_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.88, 0.95, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _build_pushables() -> void:
	for p in map.get("pushables", {}):
		var info: Dictionary = map["pushables"][p]
		var mi := MeshInstance3D.new()
		mi.mesh = VP.obstacle("boulder" if info["kind"] == "boulder" else "ice_block")
		mi.position = tile_pos(p)
		add_child(mi)
		info["node"] = mi
		pushables[p] = info


func _push_free(q: Vector2i) -> bool:
	if q.x < 1 or q.y < 1 or q.x >= map["w"] - 1 or q.y >= map["h"] - 1:
		return false
	if not MapGen.walkable(MapGen.get_t(map, q.x, q.y)):
		return false
	return not (npcs.has(q) or items.has(q) or shards.has(q) or pushables.has(q) or map["exits"].has(q) or q == player_pos or _beast_at(q) != null)


## Pushes the block at `at` one tile along `d` (ice slides until it hits something). Returns true if it moved.
func _push(at: Vector2i, d: Vector2i) -> bool:
	var info: Dictionary = pushables[at]
	var dest := at + d
	if not _push_free(dest):
		return false
	var ice: bool = info["kind"] == "ice"
	if ice:
		while _push_free(dest + d):
			dest += d
	pushables.erase(at)
	pushables[dest] = info
	var node: Node3D = info["node"]
	var tiles := (dest - at).length()
	var tw := create_tween()
	tw.tween_property(node, "position", tile_pos(dest), 0.22 if not ice else 0.09 * tiles + 0.08).set_trans(Tween.TRANS_SINE if not ice else Tween.TRANS_LINEAR)
	Sfx.play("smash" if not ice else "ice", 0.1)
	return true


## A solved push puzzle: remember where the blocks ended up.
func _check_puzzle_solved() -> void:
	var exit_p = map.get("anchors", {}).get("puzzle_exit", null)
	if exit_p == null or player_pos != exit_p or GameState.flag("puzzle_" + map_id):
		return
	GameState.set_flag("puzzle_" + map_id)
	var arr := []
	for q in pushables:
		arr.append([q.x, q.y, pushables[q]["kind"]])
	GameState.set_flag("pushed_" + map_id, arr)
	Sfx.play("levelup")
	UI.toast("You cleared a way through!", UIKit.ACCENT)


## Removes an obstacle group after a beast clears it.
func clear_obstacle(grp: Dictionary) -> void:
	var info: Dictionary = WorldDB.OBSTACLES[grp["char"]]
	for q in grp["tiles"]:
		map["obstacles"].erase(q)
		MapGen.set_t(map, q.x, q.y, MapLoader.CLEAR_TO.get(info["clear"], MapGen.PATH))
		if obstacle_nodes.has(q):
			var n: Node3D = obstacle_nodes[q]
			obstacle_nodes.erase(q)
			var tw := create_tween()
			tw.tween_property(n, "scale", Vector3(0.05, 0.05, 0.05), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tw.tween_callback(n.queue_free)
		if grp["kind"] == "broken_bridge":
			pass
		elif info["clear"] == "bridge":
			var br := MeshInstance3D.new()
			br.mesh = VP.obstacle("bridge")
			br.position = tile_pos(q) + Vector3(0, -0.12, 0)
			add_child(br)
		elif info["clear"] == "rope":
			var lad := MeshInstance3D.new()
			lad.mesh = VP.obstacle("rope_ladder")
			lad.position = tile_pos(q) + Vector3(0, 0.01, 0)
			lad.scale = Vector3(1, 1, 0.05)
			add_child(lad)
			var tw2 := create_tween()
			tw2.tween_property(lad, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


# ================================================================ characters
func _beast_node(genes: Dictionary, scale := 1.0) -> Node3D:
	var root := Node3D.new()
	var mi: MeshInstance3D
	if genes.has("model"):
		mi = VA.instance(String(genes["model"]), 1.7 * scale)
	else:
		mi = MeshInstance3D.new()
		mi.mesh = VB.mesh(genes)
		# the PSX beasts are slim next to the old chunky ones: a little larger, so they read from the overworld camera
		var k := scale * (1.3 if genes.has("form") else 1.0)
		mi.scale = Vector3(k, k, k)
	mi.name = "Model"
	root.add_child(mi)
	return root


func _build_npcs() -> void:
	for n in map["npcs"]:
		if n.get("hidden", false):
			continue
		if n.get("kind", "") == "trainer" and n.get("vanish", false) and GameState.flag(n.get("flag", "")):
			continue
		if n.get("kind", "") == "guardian" and GameState.flag(n.get("flag", "")):
			continue
		if n.has("gone_flag") and GameState.flag(n["gone_flag"]):
			continue
		var p: Vector2i = n["pos"]
		if n.get("kind", "") not in ["trainer", "guardian"] and (not MapGen.walkable(MapGen.get_t(map, p.x, p.y)) or npcs.has(p)):
			p = _free_tile_near(p)
			n["pos"] = p
		var node: Node3D
		if n.get("beast_genes", null) != null:
			node = _beast_node(n["beast_genes"], 1.7 if n.get("big", false) else 1.0)
			node.rotation.y = -PI / 2.0
		elif n.has("robot_body"):
			node = _beast_node({"model": n["robot_body"]}, 0.95)
			node.rotation.y = -PI / 2.0
		elif n.has("mesh"):
			node = Node3D.new()
			var mi := MeshInstance3D.new()
			mi.mesh = n["mesh"]
			node.add_child(mi)
		elif n.has("asset"):
			node = Node3D.new()
			node.add_child(VA.instance(String(n["asset"]), float(n.get("asset_h", 1.6))))
		else:
			node = VPer.build(n.get("look", {}))
			VPer.face(node, n.get("facing", Vector2i(0, 1)))
		node.position = tile_pos(p)
		add_child(node)
		n["node"] = node
		n["home"] = p
		npcs[p] = n
		if n.has("mesh"):
			bobbers.append([node, 0.1, 2.0])
		if n.get("kind", "") == "trainer" and not GameState.flag(n.get("flag", "")):
			var mark := Label3D.new()
			mark.text = "!"
			mark.font_size = 72
			mark.modulate = Color("#ffd040") if not n.get("legion", false) else Color("#c080ff")
			mark.outline_size = 12
			mark.pixel_size = 0.01
			mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			mark.position = Vector3(0, 1.65, 0)
			mark.visible = false
			node.add_child(mark)
			n["mark"] = mark
		if n.get("story", false):
			# someone with something to tell you: a glowing crystal over their head, spinning slowly and bobbing
			var st := MeshInstance3D.new()
			st.mesh = _story_crystal()
			st.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var top := 2.0 if n.get("beast_genes", null) == null else 2.8
			st.position = Vector3(0, top, 0)
			node.add_child(st)
			n["story_mark"] = st
			spinners.append(st)
			bobbers.append([st, top, 2.6])


func _free_tile_near(p: Vector2i) -> Vector2i:
	for r in range(1, 7):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var q := p + Vector2i(dx, dy)
				if MapGen.walkable(MapGen.get_t(map, q.x, q.y)) and not npcs.has(q) and not map["exits"].has(q) and not doors.has(q - Vector2i(0, 1)):
					return q
	return p


func _build_items() -> void:
	for it in map["items"]:
		if GameState.flag(it["flag"]):
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = VP.sack() if it["item"] != "bridge_log" else VP.log_mesh(15, 2.8)
		mi.position = tile_pos(it["pos"])
		if it["item"] == "bridge_log":
			mi.rotation.y = 0.5 + (it["pos"].x * 7 + it["pos"].y * 3) % 5 * 0.4
		add_child(mi)
		it["node"] = mi
		items[it["pos"]] = it
	for sh in map.get("shards", []):
		if GameState.flag(sh["flag"]):
			continue
		var node := Node3D.new()
		var mi2 := MeshInstance3D.new()
		mi2.mesh = VP.shard()
		node.add_child(mi2)
		node.position = tile_pos(sh["pos"])
		var l := OmniLight3D.new()
		l.light_color = Color("#7af0ff")
		l.light_energy = 0.6
		l.omni_range = 2.2
		l.position = Vector3(0, 0.5, 0)
		node.add_child(l)
		add_child(node)
		sh["node"] = node
		shards[sh["pos"]] = sh
		spinners.append(mi2)


func _build_player() -> void:
	player = VPer.build(GameState.hero_look())
	add_child(player)


func _build_camera() -> void:
	cam = Camera3D.new()
	cam.fov = 36 if not interior else 44
	# no depth-of-field: the PSX look keeps every pixel sharp and lets the fog soften the distance
	add_child(cam)
	cam.current = true


func _place_camera(instant := false) -> void:
	# a battle can take the world out of the tree halfway through a frame
	if cam_free or not cam.is_inside_tree():
		return
	var w: float = map["w"]
	var h: float = map["h"]
	var t := cam_target
	if interior:
		# follows the player round the room, but stops short of showing much beyond its walls
		t.x = w / 2.0 if w <= 11.0 else clampf(t.x, 5.5, w - 5.5)
		t.z = h / 2.0 if h <= 7.0 else clampf(t.z, 3.0, h - 2.0)
		var want_r := t + CAM_OFFSET_ROOM
		cam.position = want_r if instant else cam.position.lerp(want_r, 0.15)
		cam.look_at(cam.position - CAM_OFFSET_ROOM + Vector3(0, CAM_LOOK_Y, 0), Vector3.UP)
		return
	t.x = clampf(t.x, 7.0, maxf(7.0, w - 7.0))
	t.z = clampf(t.z, 4.0, maxf(4.0, h - 2.5))
	var want := t + CAM_OFFSET
	cam.position = want if instant else cam.position.lerp(want, 0.12)
	cam.look_at(cam.position - CAM_OFFSET + Vector3(0, CAM_LOOK_Y, 0), Vector3.UP)


# ================================================================ movement
func _walkable(p: Vector2i) -> bool:
	if p.x < 0 or p.y < 0 or p.x >= map["w"] or p.y >= map["h"]:
		return false
	if not MapGen.walkable(MapGen.get_t(map, p.x, p.y)):
		return false
	if npcs.has(p) or items.has(p) or shards.has(p) or pushables.has(p):
		return false
	return true


func _process(delta: float) -> void:
	_time += delta
	for m in water_mats:
		if m is BaseMaterial3D:
			m.uv1_offset = Vector3(sin(_time * 0.5) * 0.04, _time * 0.025, 0)
	for sp in spinners:
		if is_instance_valid(sp):
			sp.rotation.y = _time * 1.4
	for b in bobbers:
		if is_instance_valid(b[0]):
			var n: Node3D = b[0]
			n.position.y = float(b[1]) + sin(_time * float(b[2])) * 0.08
	if demo:
		_demo_t += delta
		cam_target = Vector3(map["w"] / 2.0 + sin(_demo_t * 0.15) * 6.0, 0, map["h"] / 2.0 + 2.0)
		_place_camera()
		return
	if player == null:
		return
	_animate_npcs(delta)
	_fade_buildings(delta)
	if interior and room_walls != null:
		room_walls.fade(player.position, delta)
	_update_wilds(delta)
	_note_keys()
	if moving:
		# the legs keep pace with the ground (a step every half turn of the phase)
		anim_t += VPer.phase_for(delta * move_speed, move_speed)
		move_t += delta * move_speed
		if move_t >= 1.0:
			# a step always lands on the middle of its tile, whatever was let go of or pressed on the way
			var spill := move_t - 1.0
			player.position = tile_pos(player_pos)
			moving = false
			_on_step_done()
			# keep walking without a stop between tiles when the next step is ready right away (keys or a tapped path)
			if not moving and not busy and not frozen and not UI.busy() and _next_step():
				move_t = minf(spill, 0.5)
				player.position = move_from.lerp(move_to, move_t)
		else:
			player.position = move_from.lerp(move_to, move_t)
			# easing into the pace (_stride is the speed the legs show)
			_stride = move_toward(_stride, move_speed, delta * 30.0)
	elif not busy and not frozen and not UI.busy():
		_read_input()
	if not moving:
		# easing back to standing, then breathing and looking about
		_stride = move_toward(_stride, 0.0, delta * 25.0)
	VPer.animate(player, anim_t, _stride)
	cam_target = player.position
	_place_camera()


func _fade_buildings(delta: float) -> void:
	var pp := Vector2(player.position.x, player.position.z)
	for f in building_fades:
		var b: Dictionary = f["b"]
		var by: float = b["y"]
		var bx: float = b["x"]
		var tall := 12.0 if b["shop"] in ["ceo_tower", "skytower", "cathedral"] else 7.5
		var occl: bool = pp.y < by + 0.5 and pp.y > by - tall and pp.x > bx - 1.0 and pp.x < bx + float(b["w"]) + 1.0
		var target := 0.9 if occl else 0.0
		for gi in f["meshes"]:
			if is_instance_valid(gi) and gi.transparency != target:
				gi.transparency = move_toward(gi.transparency, target, delta * 3.0)


func _read_input() -> void:
	if Input.is_action_just_pressed("menu"):
		_open_menu()
		return
	if Input.is_action_just_pressed("interact"):
		_interact()
		return
	_next_step()


## Starts the next step: held direction keys first, else the next tile of a tapped path.
## Returns true if the player started moving.
func _next_step() -> bool:
	var d := _key_dir()
	if d != Vector2i.ZERO:
		_clear_path()
	elif not _path.is_empty():
		return _follow_path()
	else:
		_walk_dir = Vector2i.ZERO
		return false
	return _step(d, Input.is_action_pressed("run"))


## Faces `d` (one of the four ways) and walks one tile that way if possible. Returns true if a step started.
func _step(d: Vector2i, run: bool) -> bool:
	facing = d
	VPer.face(player, facing, true)
	_walk_dir = Vector2i.ZERO
	var target := player_pos + d
	if d == Vector2i(0, -1) and doors.has(target):
		_enter_building(doors[target])
		return false
	var wb = _beast_at(target)
	if wb != null:
		_bump_wild(wb)
		return false
	if pushables.has(target) and not _push(target, d):
		return false
	if _walkable(target):
		_begin_step(target, run)
		_walk_dir = d
		return true
	return false


## One whole tile, from the middle of this one to the middle of the next, at the hero's jog (a sprint while running).
func _begin_step(target: Vector2i, run: bool) -> void:
	moving = true
	move_t = 0.0
	move_from = tile_pos(player_pos)
	move_to = tile_pos(target)
	player_pos = target
	move_speed = 4.6 * (1.0 + GameState.gear_fx("speed")) * (1.7 if run else 1.0)


func _on_step_done() -> void:
	GameState.steps += 1
	_check_puzzle_solved()
	var under := MapGen.get_t(map, player_pos.x, player_pos.y)
	Sfx.play("step_grass" if under in [MapGen.GRASS, MapGen.TALL, MapGen.FLOWERS, MapGen.SAND, MapGen.MIST] else "step_stone", 0.12)
	if GameState.incense_steps > 0:
		GameState.incense_steps -= 1
		if GameState.incense_steps == 0:
			UI.toast("The incense wore off.")
	if map["exits"].has(player_pos):
		var ex: Dictionary = map["exits"][player_pos]
		busy = true
		var ok: bool = await Story.can_use_exit(self, ex)
		busy = false
		if not ok:
			var back := player_pos - facing
			if _walkable(back):
				player_pos = back
				player.position = tile_pos(back)
			facing = -facing
			VPer.face(player, facing)
			return
		if interior:
			Sfx.play("door_close")
		GameState.main.goto_map(ex["to"], ex["spawn"], ex.get("face", Vector2i.ZERO))
		return
	if await _check_trainer_sight():
		return


func _check_trainer_sight() -> bool:
	if GameState.party.is_empty():
		return false
	for p in npcs.keys():
		var n: Dictionary = npcs[p]
		if n.get("kind", "") != "trainer" or GameState.flag(n.get("flag", "")):
			continue
		var f: Vector2i = n.get("facing", Vector2i(0, 1))
		for i in range(1, int(n.get("sight", 4)) + 1):
			var q: Vector2i = p + f * i
			if q == player_pos:
				busy = true
				await _trainer_approach(n, p, i)
				busy = false
				return true
			if not MapGen.walkable(MapGen.get_t(map, q.x, q.y)) or npcs.has(q):
				break
	return false


func _trainer_approach(n: Dictionary, p: Vector2i, dist: int) -> void:
	var mark: Label3D = n.get("mark", null)
	if mark:
		mark.visible = true
	Sfx.play("encounter")
	await get_tree().create_timer(0.6).timeout
	if mark:
		mark.visible = false
	var f: Vector2i = n["facing"]
	var node: Node3D = n["node"]
	var cur := p
	node.set_meta("posed", true)
	# a jog: a tile every 0.22 s, the legs keeping pace
	var per_tile := VPer.phase_for(1.0, 1.0 / 0.22)
	for i in dist - 1:
		var nxt := cur + f
		var tw := create_tween()
		tw.tween_property(node, "position", tile_pos(nxt), 0.22)
		if node.has_node("Body"):
			tw.parallel().tween_method(func(ph: float): VPer.animate(node, ph, 1.0 / 0.22), i * per_tile, (i + 1) * per_tile, 0.22)
		await tw.finished
		cur = nxt
	node.remove_meta("posed")
	if node.has_node("Body"):
		VPer.animate(node, 0.0, 0.0)
	npcs.erase(p)
	npcs[cur] = n
	n["pos"] = cur
	facing = -f
	VPer.face(player, facing)
	await Story.talk(self, n)


func _interact() -> void:
	var t := _facing_tile()
	var wb = _beast_at(t)
	if wb != null:
		_bump_wild(wb)
		return
	busy = true
	if npcs.has(t):
		var n: Dictionary = npcs[t]
		_face_npc(n, -facing)
		await Story.talk(self, n)
	elif doors.has(t):
		await _enter_building(doors[t])
	elif items.has(t):
		await _pickup(items[t])
	elif shards.has(t):
		await _pickup_shard(shards[t])
	elif map.get("obstacles", {}).has(t):
		await Story.field_move(self, map["obstacles"][t])
	elif _counter_like(t) and _across_counter(t) != Vector2i(-999, -999):
		var n2: Dictionary = npcs[_across_counter(t)]
		_face_npc(n2, -facing)
		await Story.talk(self, n2)
	elif map["signs"].has(t):
		await UI.say([map["signs"][t]])
	elif MapGen.get_t(map, t.x, t.y) == MapGen.STATUE:
		var race: int = map["statue"]["race"]
		await UI.say(["A statue of %s, guardian of %s." % [RaceDB.race_name(race), map["name"]],
			WorldDB.TOWNS.get(map_id, {}).get("blurb", "")])
	elif interior and MapGen.get_t(map, t.x, t.y) in PROP_CODES:
		await Places.prop(MapGen.get_t(map, t.x, t.y), map, self, t)
	elif MapGen.get_t(map, t.x, t.y) == MapGen.WATER:
		await UI.say(["The water sparkles. Something might live down there..."])
	busy = false


func _facing_tile() -> Vector2i:
	return player_pos + facing


## The person standing behind a counter tile: straight across, or one step to either side.
func _across_counter(t: Vector2i) -> Vector2i:
	var f := t - player_pos
	if f.x != 0 and f.y != 0:
		return Vector2i(-999, -999)
	var side := Vector2i(f.y, f.x)
	for q in [t + f, t + f + side, t + f - side]:
		if npcs.has(q):
			return q
	return Vector2i(-999, -999)


func _counter_like(t: Vector2i) -> bool:
	return MapGen.get_t(map, t.x, t.y) in [MapGen.COUNTER, MapGen.CRYSTAL, MapGen.TABLE]


func _enter_building(b: Dictionary) -> void:
	var was_busy := busy
	busy = true
	if Places.door_locked(b):
		await Places.knock(b)
		busy = was_busy
		return
	if not await Story.can_enter(self, b):
		busy = was_busy
		return
	busy = was_busy
	Sfx.play("door")
	GameState.facing = Vector2i(0, -1)
	GameState.main.goto_map(b["interior"], "entry")


func _face_npc(n: Dictionary, f: Vector2i, smooth := false) -> void:
	var node: Node3D = n.get("node", null)
	if node == null or not node.has_node("Body"):
		return
	# the nearer of the four ways
	n["facing"] = _four_way(f)
	VPer.face(node, n["facing"], smooth)


func _pickup(it: Dictionary) -> void:
	GameState.set_flag(it["flag"])
	GameState.add_item(it["item"])
	var node: Node3D = it["node"]
	node.queue_free()
	items.erase(it["pos"])
	Sfx.play("item")
	await UI.say(["You found a %s!" % ItemDB.item_name(it["item"])])


func _pickup_shard(sh: Dictionary) -> void:
	GameState.set_flag(sh["flag"])
	GameState.shards += 1
	var node: Node3D = sh["node"]
	node.queue_free()
	shards.erase(sh["pos"])
	Sfx.play("shard")
	await UI.say(["You found a crystal shard! (%d in your bag)" % GameState.shards,
		"Five shards buy a shield upgrade at Sparkwire Electronics in Tidewater." if GameState.shards < 5 else "You have enough for a shield upgrade at Sparkwire Electronics in Tidewater!"])


func _open_menu() -> void:
	busy = true
	GameState.pos = player_pos
	GameState.facing = facing
	await Menus.pause_menu(self)
	busy = false


func _animate_npcs(delta: float) -> void:
	var arrived := []
	for p in npcs:
		var n: Dictionary = npcs[p]
		var node: Node3D = n.get("node", null)
		if node == null:
			continue
		if n.get("beast_genes", null) != null or n.has("robot_body"):
			var m: Node3D = node.get_node_or_null("Model")
			if m:
				m.position.y = absf(sin(_time * 2.6 + p.x)) * 0.06
		if n.has("walking"):
			# a step across the room, legs and arms swinging
			var wk: Dictionary = n["walking"]
			wk["t"] = minf(1.0, float(wk["t"]) + delta / ROAM_STEP)
			node.position = (wk["from"] as Vector3).lerp(wk["to"], wk["t"])
			# a stroll, the legs keeping pace with the ground from one tile to the next
			n["phase"] = float(n.get("phase", 0.0)) + VPer.phase_for(delta / ROAM_STEP, 1.0 / ROAM_STEP)
			n["gait"] = move_toward(float(n.get("gait", 0.0)), 1.0 / ROAM_STEP, delta * 12.0)
			VPer.animate(node, n["phase"], n["gait"])
			if float(wk["t"]) >= 1.0:
				arrived.append(n)
		elif not node.has_meta("posed") and node.position.distance_squared_to(player.position) < 300.0:
			# standing about (near enough to see): settling from a walk, then breathing, shifting weight, looking round
			n["gait"] = move_toward(float(n.get("gait", 0.0)), 0.0, delta * 8.0)
			VPer.animate(node, float(n.get("phase", 0.0)), n["gait"])
	for n in arrived:
		n.erase("walking")
		if (n["node"] as Node3D).position.distance_squared_to(player.position) >= 300.0:
			n["gait"] = 0.0
			VPer.animate(n["node"], 0.0, 0.0)
	if not busy and not frozen:
		_roam(delta)
	if busy:
		return
	if randf() < delta * 0.6:
		var keys := npcs.keys()
		if keys.is_empty():
			return
		var n2: Dictionary = npcs[keys[randi() % keys.size()]]
		if n2.get("wander", false):
			var dirs := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]
			if interior:
				# indoors people glance around the room, never at a wall or the corner behind them
				var p2: Vector2i = n2["pos"]
				var to := Vector2(map["w"] - 1, map["h"] - 1) / 2.0 - Vector2(p2)
				dirs = dirs.filter(func(d): return not MapLoader.faces_wall(map, p2, d) and Vector2(d).dot(to) >= -0.01)
			if not dirs.is_empty():
				_face_npc(n2, dirs[randi() % dirs.size()])


## Visitors in a room (n["roam"]) walk about it: every few seconds one takes a step to a free floor tile near where it
## started. Never into a doorway, onto the mat by the door, onto the stairs, next to something you use (a counter, a
## machine, a shelf) or another person, nor onto or next to the player, so nobody stands in your way for long.
const ROAM_STEP := 0.6
const ROAM_LEASH := 4
const ROAM_FLOORS := [MapGen.IFLOOR, MapGen.ITILE, MapGen.RUG]


func _roam(delta: float) -> void:
	var moves := []
	for p in npcs:
		var n: Dictionary = npcs[p]
		if not n.get("roam", false) or n.has("walking") or n.get("node", null) == null:
			continue
		n["roam_t"] = float(n.get("roam_t", randf_range(1.0, 4.0))) - delta
		if float(n["roam_t"]) > 0.0:
			continue
		n["roam_t"] = randf_range(2.0, 5.0)
		var dirs := FOUR_WAYS.duplicate()
		dirs.shuffle()
		for d in dirs:
			var t: Vector2i = p + d
			if _roam_free(t, p, n):
				moves.append([p, t, d])
				break
	for mv in moves:
		var n2: Dictionary = npcs[mv[0]]
		npcs.erase(mv[0])
		npcs[mv[1]] = n2
		n2["pos"] = mv[1]
		_face_npc(n2, mv[2], true)
		n2["walking"] = {"from": tile_pos(mv[0]), "to": tile_pos(mv[1]), "t": 0.0}


## The four ways anyone can step: everyone walks the grid, one whole tile at a time.
const FOUR_WAYS := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]


## The nearer of the four ways to `d` (down for none).
static func _four_way(d: Vector2i) -> Vector2i:
	if d == Vector2i.ZERO:
		return Vector2i(0, 1)
	return Vector2i(signi(d.x), 0) if absi(d.x) > absi(d.y) else Vector2i(0, signi(d.y))


func _roam_free(t: Vector2i, from: Vector2i, n: Dictionary) -> bool:
	if not MapGen.get_t(map, t.x, t.y) in ROAM_FLOORS or map["exits"].has(t):
		return false
	var home: Vector2i = n.get("home", from)
	if absi(t.x - home.x) + absi(t.y - home.y) > ROAM_LEASH:
		return false
	if npcs.has(t) or items.has(t) or shards.has(t) or t == player_pos:
		return false
	for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
		var q: Vector2i = t + d
		if q == player_pos or (npcs.has(q) and q != from):
			return false
		if MapGen.get_t(map, q.x, q.y) in PROP_CODES and MapGen.get_t(map, q.x, q.y) != MapGen.FURN:
			return false
	return true


func remove_npc(n: Dictionary) -> void:
	var node: Node3D = n.get("node", null)
	if node:
		var tw := create_tween()
		tw.tween_property(node, "scale", Vector3(0.05, 0.05, 0.05), 0.4)
		tw.tween_callback(node.queue_free)
	npcs.erase(n["pos"])


## The crystal over a person with news: a cut gem, four long facets tapering down to a point under a short crown,
## warm gold, a little see-through, glowing softly.
static var _crystal_mesh: ArrayMesh


static func _story_crystal() -> ArrayMesh:
	if _crystal_mesh != null:
		return _crystal_mesh
	var ring := []
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		ring.append(Vector3(cos(a) * 0.15, 0.0, sin(a) * 0.15))
	var crown := Vector3(0, 0.09, 0)
	var tip := Vector3(0, -0.36, 0)
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	var cs := PackedColorArray()
	for i in 4:
		var r0: Vector3 = ring[i]
		var r1: Vector3 = ring[(i + 1) % 4]
		# each face flat-shaded, wound to face outwards; the lower facets a shade deeper than the crown
		for tri in [[crown, r1, r0, Color(1.0, 0.96, 0.7)], [tip, r0, r1, Color(0.82, 0.58, 0.16) if i % 2 == 0 else Color(1.0, 0.8, 0.32)]]:
			var p0: Vector3 = tri[0]
			var p1: Vector3 = tri[1]
			var p2: Vector3 = tri[2]
			var nrm := (p1 - p0).cross(p2 - p0).normalized()
			if nrm.dot((p0 + p1 + p2) / 3.0) < 0.0:
				var t := p1
				p1 = p2
				p2 = t
				nrm = -nrm
			for v in [p0, p1, p2]:
				vs.append(v)
				ns.append(nrm)
				cs.append(tri[3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vs
	arrays[Mesh.ARRAY_NORMAL] = ns
	arrays[Mesh.ARRAY_COLOR] = cs
	_crystal_mesh = ArrayMesh.new()
	_crystal_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1.0, 0.9, 0.55, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic = 0.3
	m.roughness = 0.15
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	m.emission_enabled = true
	m.emission = Color("#ffcf4a")
	m.emission_energy_multiplier = 0.45
	m.rim_enabled = true
	m.rim = 0.6
	_crystal_mesh.surface_set_material(0, m)
	return _crystal_mesh


func refresh_npc_marks() -> void:
	for p in npcs:
		var n: Dictionary = npcs[p]
		if n.has("story_mark"):
			n["story_mark"].visible = Story.npc_has_news(n)


# ================================================================ tap to move
## Tap a spot to walk there, double-tap to run. Tap something you can use (a person, a door, a sign, a wild beast...)
## to walk up to it and use it; if you're already next to it, you use it straight away.
const DOUBLE_TAP := 0.35
var _path: Array = []
var _path_run := false
var _path_goal := Vector2i(-999, -999)
var _last_tap_ms := -10000
var _last_tap_tile := Vector2i(-999, -999)
var _tap_ring: MeshInstance3D


## The direction keys (or d-pad arrows) held down, oldest first: with two at once you keep walking the way you were
## going, else the newest one counts (_note_keys, _key_dir).
const DIR_ACTIONS := {"move_up": Vector2i(0, -1), "move_down": Vector2i(0, 1), "move_left": Vector2i(-1, 0), "move_right": Vector2i(1, 0)}
var _held: Array = []
## the way the last step went, while the walk goes on (zero once you stop or bump into something)
var _walk_dir := Vector2i.ZERO


func _note_keys() -> void:
	for a in DIR_ACTIONS:
		var d: Vector2i = DIR_ACTIONS[a]
		if not Input.is_action_pressed(a):
			_held.erase(d)
		elif not d in _held:
			_held.append(d)


## The way the keys (or the d-pad, or a gamepad's left stick) are steering: one of the four, or zero.
func _key_dir() -> Vector2i:
	if _held.is_empty():
		return _stick_dir()
	if _walk_dir in _held:
		return _walk_dir
	return _held.back()


## A gamepad's left stick steers along whichever axis it's pushed further; the axis you're walking along holds until
## the other is clearly further.
func _stick_dir() -> Vector2i:
	var v := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if v.length() < 0.35:
		return Vector2i.ZERO
	var x_wins := absf(v.x) * (1.25 if _walk_dir.x != 0 else 1.0) > absf(v.y) * (1.25 if _walk_dir.y != 0 else 1.0)
	return Vector2i(int(signf(v.x)), 0) if x_wins else Vector2i(0, int(signf(v.y)))


func _clear_path() -> void:
	_path = []
	_path_goal = Vector2i(-999, -999)
	if _tap_ring:
		_tap_ring.visible = false


## Screen point -> the tile under it (on the ground plane).
func _tile_under(screen: Vector2) -> Vector2i:
	if cam == null:
		return Vector2i(-999, -999)
	var o := cam.project_ray_origin(screen)
	var n := cam.project_ray_normal(screen)
	if absf(n.y) < 0.001:
		return Vector2i(-999, -999)
	var t := -o.y / n.y
	var hit := o + n * t
	return Vector2i(int(floor(hit.x)), int(floor(hit.z)))


## Is there something to use on this tile? Returns "npc", "beast", "door", "item", "thing" or "".
func _usable(t: Vector2i) -> String:
	if npcs.has(t):
		return "npc"
	if _beast_at(t) != null:
		return "beast"
	if doors.has(t):
		return "door"
	if items.has(t) or shards.has(t):
		return "item"
	var c := MapGen.get_t(map, t.x, t.y)
	if map.get("obstacles", {}).has(t) or map["signs"].has(t) or c == MapGen.STATUE or (interior and c in PROP_CODES and c not in [MapGen.TABLE]):
		return "thing"
	return ""


func tap_at(screen: Vector2) -> void:
	if player == null or busy or frozen or UI.busy() or cam == null:
		return
	var t := _tile_under(screen)
	var now := Time.get_ticks_msec()
	var double := now - _last_tap_ms < int(DOUBLE_TAP * 1000.0) and Vector2(t - _last_tap_tile).length() <= 1.5
	_last_tap_ms = now
	_last_tap_tile = t
	# people, beasts, items and buildings stand up out of the ground: test the ray against their shapes first
	var hit := _pick(screen)
	if not hit.is_empty():
		_go_use(hit["tile"], hit["kind"], double)
		return
	if t.x < 0 or t.y < 0 or t.x >= map["w"] or t.y >= map["h"]:
		return
	var kind := _usable(t)
	if kind != "":
		_go_use(t, kind, double)
		return
	if MapGen.walkable(MapGen.get_t(map, t.x, t.y)):
		_walk_to([t], Vector2i(-999, -999), double)


## The nearest usable thing the tap ray passes through: {"tile", "kind"} or {}.
func _pick(screen: Vector2) -> Dictionary:
	var o := cam.project_ray_origin(screen)
	var n := cam.project_ray_normal(screen)
	var best := {}
	var best_d := INF
	var boxes := []
	for p in npcs:
		boxes.append([AABB(Vector3(p.x + 0.15, 0, p.y + 0.15), Vector3(0.7, 1.9, 0.7)), p, "npc"])
	for w in wilds:
		var wp: Vector3 = (w["node"] as Node3D).position
		boxes.append([AABB(wp - Vector3(0.4, 0, 0.4), Vector3(0.8, 1.3, 0.8)), w["pos"], "beast"])
	for p in items:
		boxes.append([AABB(Vector3(p.x + 0.2, 0, p.y + 0.2), Vector3(0.6, 0.7, 0.6)), p, "item"])
	for p in shards:
		boxes.append([AABB(Vector3(p.x + 0.2, 0, p.y + 0.2), Vector3(0.6, 0.9, 0.6)), p, "item"])
	for b in map["buildings"]:
		if b["shop"] == "decor":
			continue
		boxes.append([AABB(Vector3(float(b["x"]), 0, float(b["y"])), Vector3(float(b["w"]), float(b.get("height", 2.4)) + 1.2, float(b["d"]))), b["door"], "door"])
	for bx in boxes:
		var hit_p = (bx[0] as AABB).intersects_ray(o, n)
		if hit_p == null:
			continue
		var d := ((hit_p as Vector3) - o).length()
		if d < best_d:
			best_d = d
			best = {"tile": bx[1], "kind": bx[2]}
	return best


func _building_at(t: Vector2i) -> Dictionary:
	if MapGen.get_t(map, t.x, t.y) != MapGen.BUILDING and MapGen.get_t(map, t.x, t.y) != MapGen.DOOR:
		return {}
	for b in map["buildings"]:
		if b["shop"] == "decor":
			continue
		if t.x >= int(b["x"]) and t.x < int(b["x"]) + int(b["w"]) and t.y >= int(b["y"]) and t.y < int(b["y"]) + int(b["d"]):
			return b
	return {}


## Walk next to `t` and use it (doors are walked into; wild beasts are bumped into).
func _go_use(t: Vector2i, kind: String, run: bool) -> void:
	# the kennel's pens are behind Pip's counter: tapping one goes to ask Pip
	if interior and MapGen.get_t(map, t.x, t.y) == MapGen.KENNEL:
		for p in npcs:
			if npcs[p].get("id", "") == "kennel_keeper":
				t = p
				kind = "npc"
	var spots := []
	if kind == "door":
		spots = [t + Vector2i(0, 1)]
	else:
		for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
			spots.append(t + d)
			# people behind a counter are reached from the other side of it
			if _counter_like(t + d):
				spots.append(t + d * 2)
	if player_pos in spots:
		_use_from_here(t, kind)
		return
	_walk_to(spots, t, run)


func _use_from_here(t: Vector2i, kind: String) -> void:
	var d := t - player_pos
	if absi(d.x) + absi(d.y) == 2:
		d /= 2
	facing = d
	VPer.face(player, facing)
	_clear_path()
	if kind == "door" or kind == "beast":
		_step(d, false)
	else:
		_interact()


## Finds a path to the nearest of `goals` and starts following it.
func _walk_to(goals: Array, use_tile: Vector2i, run: bool) -> void:
	var goal_set := {}
	for g in goals:
		if g == player_pos or _walkable(g):
			goal_set[g] = true
	if goal_set.is_empty():
		return
	var prev := {player_pos: player_pos}
	var queue := [player_pos]
	var found := Vector2i(-999, -999)
	var qi := 0
	while qi < queue.size() and qi < 2500:
		var p: Vector2i = queue[qi]
		qi += 1
		if goal_set.has(p):
			found = p
			break
		for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
			var q: Vector2i = p + d
			if prev.has(q) or not _walkable(q) or _beast_at(q) != null or (map["exits"].has(q) and not goal_set.has(q)):
				continue
			prev[q] = p
			queue.append(q)
	if found.x == -999:
		return
	var path := []
	var cur := found
	while cur != player_pos:
		path.push_front(cur)
		cur = prev[cur]
	_path = path
	_path_run = run
	_path_goal = use_tile
	_show_tap_ring(found if use_tile.x == -999 else use_tile)
	if _path.is_empty() and use_tile.x != -999:
		_use_from_here(use_tile, _usable(use_tile) if _usable(use_tile) != "" else "door")
	elif not moving:
		_follow_path()


func _follow_path() -> bool:
	if _path.is_empty():
		return false
	var nxt: Vector2i = _path.pop_front()
	var d := nxt - player_pos
	if absi(d.x) + absi(d.y) != 1:
		_clear_path()
		return false
	var ok := _step(d, _path_run)
	if not ok:
		_clear_path()
		return false
	if _path.is_empty():
		var goal := _path_goal
		if goal.x != -999:
			# use it once this last step lands
			_path_goal = Vector2i(-999, -999)
			_arrive_use.call_deferred(goal)
		elif _tap_ring:
			_tap_ring.visible = false
	return true


func _arrive_use(goal: Vector2i) -> void:
	while moving:
		await get_tree().process_frame
	if busy or frozen or UI.busy():
		return
	var kind := _usable(goal)
	if kind == "" and not _building_at(goal).is_empty():
		kind = "door"
	if kind != "":
		_use_from_here(goal, kind)
	if _tap_ring:
		_tap_ring.visible = false


func _show_tap_ring(t: Vector2i) -> void:
	if _tap_ring == null:
		_tap_ring = MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.28
		tm.outer_radius = 0.4
		tm.rings = 12
		tm.ring_segments = 6
		_tap_ring.mesh = tm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("#ffd040")
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_tap_ring.material_override = m
		_tap_ring.scale = Vector3(1, 0.3, 1)
		add_child(_tap_ring)
	_tap_ring.position = tile_pos(t) + Vector3(0, 0.05, 0)
	_tap_ring.visible = true


# ================================================================ wild beasts in the open
## Wild beasts roam in plain sight. Each one sees in a cone in front of it (half as far when you're in tall grass) and
## hears you running close by. Beasts about as strong as your best one or stronger (Lv >= best - 1) come running when
## they spot you; weaker ones bolt.
##   yellow "!"  it spotted you        blue "!"  it's scared and fleeing        "?"  it lost you
##   (nothing while it charges at you, and nothing once it gives up and goes back to roaming)
## Walk into one from behind before it spots you: a sneak attack (green spiral, it loses its first turn).
## Meet one face to face: a normal battle (blue). Let one catch you from behind: an ambush (red, you lose your first turn).
const WILD_SIGHT := 5.0
const WILD_HEAR := 3.0
const WILD_LEASH := 7
const WILD_WANDER_SPEED := 2.2
const WILD_CHASE_SPEED := 3.6
const WILD_FLEE_SPEED := 3.9
## A lone beast only runs from you when your best beast is at least this many levels above it.
const WILD_FLEE_GAP := 8
const MARK_SPOTTED := Color("#ffd040")
const MARK_SCARED := Color("#4aa8ff")
const MARK_LOST := Color("#fff4d0")
const SIGHT_BLOCKERS := [MapGen.TREE, MapGen.ROCK, MapGen.WALL, MapGen.BUILDING, MapGen.BUSH, MapGen.IWALL, MapGen.OBSTACLE, MapGen.GATE]

var wilds: Array = []
var _wild_cands: Array = []
var _wild_target := 0
var _wild_respawn := 15.0
var _wild_think := 0.0


func _spawn_wilds() -> void:
	if demo or map.get("encounter", {}).is_empty() or player == null:
		return
	# the Coastal Path has only its teachers until you have a flute
	if map["encounter"].get("after_flute", false) and not GameState.has_flute():
		return
	_wild_cands = []
	for y in map["h"]:
		for x in map["w"]:
			var c := MapGen.get_t(map, x, y)
			if (interior and c == MapGen.MIST) or (not interior and c in [MapGen.TALL, MapGen.GRASS, MapGen.SAND, MapGen.FLOWERS]):
				_wild_cands.append(Vector2i(x, y))
	if _wild_cands.is_empty():
		return
	var target := clampi(_wild_cands.size() / 24, 3, 7)
	target = int(round(target * (1.0 + GameState.gear_fx("encounter"))))
	if GameState.incense_steps > 0:
		target = 0 if GameState.incense_kind < 0 else target + 3
	_wild_target = target
	for i in target:
		_spawn_wild(6.0)


func _spawn_wild(min_dist: float) -> void:
	for attempt in 40:
		var p: Vector2i = _wild_cands[randi() % _wild_cands.size()]
		if Vector2(p - player_pos).length() < min_dist or not _wild_free(p, {}):
			continue
		# they like the tall grass best
		if not interior and MapGen.get_t(map, p.x, p.y) != MapGen.TALL and randf() < 0.4:
			continue
		var foes: Array = Story.roll_wild(map)
		if foes.is_empty():
			return
		var dirs := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]
		var w := {"beasts": foes, "pos": p, "home": p, "facing": dirs[randi() % 4], "state": "wander", "t": randf_range(0.5, 2.5),
			"moving": false, "from": tile_pos(p), "to": tile_pos(p), "mt": 0.0, "speed": WILD_WANDER_SPEED, "lost": 0.0, "phase": randf() * TAU}
		_make_wild_node(w)
		wilds.append(w)
		return


func _make_wild_node(w: Dictionary) -> void:
	var root := Node3D.new()
	var lead = w["beasts"][0]
	var body := _beast_node(lead.genes, 0.72)
	body.name = "Lead"
	root.add_child(body)
	var followers := []
	for i in range(1, w["beasts"].size()):
		var f := _beast_node(w["beasts"][i].genes, 0.62)
		f.position = Vector3(-0.45, 0, 0.28 if i == 1 else -0.28)
		root.add_child(f)
		followers.append(f)
	w["followers"] = followers
	var mark := Label3D.new()
	mark.font = load("res://ui/BoldPixels.ttf")
	mark.font_size = 64
	mark.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mark.outline_size = 12
	mark.outline_modulate = Color("#2a1a1a")
	mark.pixel_size = 0.01
	mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mark.no_depth_test = true
	mark.position = Vector3(0, 2.2, 0)
	mark.visible = false
	root.add_child(mark)
	w["mark"] = mark
	root.position = tile_pos(w["pos"])
	add_child(root)
	w["node"] = root
	_face_wild(w)


func _face_wild(w: Dictionary) -> void:
	var d: Vector2i = w["facing"]
	(w["node"] as Node3D).rotation.y = atan2(-float(d.y), float(d.x))


func _set_mark(w: Dictionary, text: String, col := Color.WHITE) -> void:
	var m: Label3D = w["mark"]
	m.visible = text != ""
	m.text = text
	m.modulate = col


## The roaming wild beast on tile `q`, if any.
func _beast_at(q: Vector2i):
	for w in wilds:
		if w["pos"] == q:
			return w
	return null


func _wild_free(p: Vector2i, w: Dictionary) -> bool:
	if p.x < 1 or p.y < 1 or p.x >= map["w"] - 1 or p.y >= map["h"] - 1 or p == player_pos:
		return false
	var c := MapGen.get_t(map, p.x, p.y)
	if not MapGen.walkable(c) or (interior and c != MapGen.MIST) or c == MapGen.DOOR or c == MapGen.ICE:
		return false
	# wild beasts keep out of the push puzzles
	if map.has("puzzle_area") and (map["puzzle_area"] as Rect2i).grow(1).has_point(p):
		return false
	if npcs.has(p) or items.has(p) or shards.has(p) or pushables.has(p) or map["exits"].has(p) or doors.has(p - Vector2i(0, 1)):
		return false
	for o in wilds:
		if o != w and o["pos"] == p:
			return false
	return true


## Packs and fair fights come straight at you; only a lone, hopelessly outmatched beast runs away.
func _wild_bold(w: Dictionary) -> bool:
	return (w["beasts"] as Array).size() > 1 or int(w["beasts"][0].level) > GameState.best_level() - WILD_FLEE_GAP


## True if the beast can see (or hear) the player right now.
func _wild_sees(w: Dictionary) -> bool:
	if GameState.incense_steps > 0 and GameState.incense_kind < 0:
		return false
	var to := Vector2(player_pos - w["pos"])
	var dist := to.length()
	if dist < 0.5:
		return true
	if moving and move_speed > 6.0 and dist <= WILD_HEAR:
		return true
	var sight := WILD_SIGHT
	if MapGen.get_t(map, player_pos.x, player_pos.y) == MapGen.TALL:
		sight *= 0.5
	if dist > sight:
		return false
	if to.normalized().dot(Vector2(w["facing"]).normalized()) < 0.35:
		return false
	return _line_clear(w["pos"], player_pos)


func _line_clear(a: Vector2i, b: Vector2i) -> bool:
	var steps := int(ceil(Vector2(b - a).length() * 2.0))
	for i in range(1, steps):
		var p := Vector2(a).lerp(Vector2(b), float(i) / float(steps)).round()
		var q := Vector2i(int(p.x), int(p.y))
		if q == a or q == b:
			continue
		if MapGen.get_t(map, q.x, q.y) in SIGHT_BLOCKERS:
			return false
	return true


func _wild_step(w: Dictionary, d: Vector2i, speed: float) -> bool:
	w["facing"] = d
	_face_wild(w)
	var q: Vector2i = w["pos"] + d
	if not _wild_free(q, w):
		return false
	w["from"] = (w["node"] as Node3D).position
	w["to"] = tile_pos(q)
	w["pos"] = q
	w["mt"] = 0.0
	w["moving"] = true
	w["speed"] = speed
	return true


## Steps towards (sign 1) or away from (sign -1) the player, one of the four ways. Returns false if boxed in.
func _wild_step_rel(w: Dictionary, sgn: int, speed: float) -> bool:
	var best := []
	var best_d := INF
	var here := Vector2(player_pos - w["pos"]).length()
	for d in FOUR_WAYS:
		var q: Vector2i = w["pos"] + d
		if not _wild_free(q, w) and not (sgn > 0 and q == player_pos):
			continue
		var dist := Vector2(player_pos - q).length() * float(sgn)
		if sgn < 0 and -dist <= here - 0.01:
			continue
		if dist < best_d - 0.01:
			best = [d]
			best_d = dist
		elif absf(dist - best_d) <= 0.01:
			best.append(d)
	if best.is_empty():
		return false
	var d2: Vector2i = best[randi() % best.size()]
	if w["pos"] + d2 == player_pos:
		w["facing"] = d2
		_face_wild(w)
		return false
	return _wild_step(w, d2, speed)


func _animate_wild(w: Dictionary, delta: float) -> void:
	var node: Node3D = w["node"]
	if w["moving"]:
		w["mt"] = float(w["mt"]) + delta * float(w["speed"])
		if float(w["mt"]) >= 1.0:
			node.position = w["to"]
			w["moving"] = false
		else:
			node.position = (w["from"] as Vector3).lerp(w["to"], float(w["mt"]))
	var hop := 0.12 if w["moving"] else 0.04
	var spd := 9.0 if w["moving"] else 2.6
	var lead: Node3D = node.get_node("Lead")
	lead.position.y = absf(sin(_time * spd + float(w["phase"]))) * hop
	for i in (w["followers"] as Array).size():
		var f: Node3D = w["followers"][i]
		f.position.y = absf(sin(_time * spd + float(w["phase"]) + 1.3 + i)) * hop


func _update_wilds(delta: float) -> void:
	for w in wilds:
		_animate_wild(w, delta)
	if busy or frozen or UI.busy() or GameState.main == null or GameState.main.in_battle:
		return
	if _wild_target > 0:
		_wild_respawn -= delta
		if _wild_respawn <= 0.0:
			_wild_respawn = randf_range(12.0, 20.0)
			if wilds.size() < _wild_target and not _wild_cands.is_empty():
				_spawn_wild(9.0)
	_wild_think -= delta
	var think := _wild_think <= 0.0
	if think:
		_wild_think = 0.12
	for w in wilds.duplicate():
		if busy:
			return
		w["t"] = float(w["t"]) - delta
		match String(w["state"]):
			"wander":
				if think and _wild_sees(w):
					_wild_spotted(w)
				elif not w["moving"] and float(w["t"]) <= 0.0:
					w["t"] = randf_range(1.2, 3.4)
					var d: Vector2i = FOUR_WAYS[randi() % FOUR_WAYS.size()]
					if randf() < 0.35:
						w["facing"] = d
						_face_wild(w)
					elif Vector2(w["pos"] + d - w["home"]).length() <= WILD_LEASH:
						_wild_step(w, d, WILD_WANDER_SPEED)
			"alert":
				if float(w["t"]) <= 0.0:
					if _wild_bold(w):
						w["state"] = "chase"
						_set_mark(w, "")
					else:
						w["state"] = "flee"
						_set_mark(w, "!", MARK_SCARED)
					w["lost"] = 0.0
			"chase":
				if not w["moving"]:
					var gap := absi(w["pos"].x - player_pos.x) + absi(w["pos"].y - player_pos.y)
					if gap == 1 and not moving:
						var to_beast: Vector2i = w["pos"] - player_pos
						_wild_encounter(w, "wild" if Vector2(facing).dot(Vector2(to_beast)) > 0.0 else "ambush")
						return
					_wild_step_rel(w, 1, WILD_CHASE_SPEED)
				if think:
					_wild_track(w, 2.5, 11.0)
			"flee":
				if not w["moving"]:
					_wild_step_rel(w, -1, WILD_FLEE_SPEED)
				if think:
					_wild_track(w, 1.6, 9.0)
			"search":
				if float(w["t"]) <= 0.0:
					w["state"] = "wander"
					w["home"] = w["pos"]
					_set_mark(w, "")
			"stunned":
				if float(w["t"]) <= 0.0:
					w["state"] = "wander"
					w["home"] = w["pos"]


func _wild_spotted(w: Dictionary) -> void:
	w["state"] = "alert"
	w["t"] = 0.6
	var d: Vector2i = player_pos - w["pos"]
	w["facing"] = Vector2i(signi(d.x), 0) if absi(d.x) >= absi(d.y) else Vector2i(0, signi(d.y))
	_face_wild(w)
	_set_mark(w, "!", MARK_SPOTTED)
	Sfx.play("notify")


## Keeps track of whether a chasing / fleeing beast can still see you; after `give_up` seconds out of sight (or once
## you're `far` away) it loses you.
func _wild_track(w: Dictionary, give_up: float, far: float) -> void:
	var dist := Vector2(player_pos - w["pos"]).length()
	if dist <= 2.0 or _wild_sees(w) or _line_clear(w["pos"], player_pos) and dist <= WILD_SIGHT:
		w["lost"] = 0.0
	else:
		w["lost"] = float(w["lost"]) + 0.12
	if float(w["lost"]) >= give_up or dist > far:
		w["state"] = "search"
		w["t"] = 1.3
		_set_mark(w, "?", MARK_LOST)


## You walked into a beast (or pressed A at it): a sneak attack if it hadn't noticed you, else a normal battle.
func _bump_wild(w: Dictionary) -> void:
	if busy:
		return
	var unaware: bool = String(w["state"]) in ["wander", "search", "stunned"] and not _wild_sees(w)
	_wild_encounter(w, "sneak" if unaware else "wild")


func _wild_encounter(w: Dictionary, kind: String) -> void:
	if busy:
		return
	busy = true
	_set_mark(w, "")
	var d: Vector2i = player_pos - w["pos"]
	w["facing"] = Vector2i(signi(d.x), 0) if absi(d.x) >= absi(d.y) else Vector2i(0, signi(d.y))
	_face_wild(w)
	if kind == "ambush":
		# you spin round in surprise
		facing = -w["facing"]
		VPer.face(player, facing)
	var res: String = await Story.wild_battle(self, w["beasts"], kind)
	busy = false
	if not is_inside_tree():
		return
	var left: Array = (w["beasts"] as Array).filter(func(b): return b.hp > 0)
	if res == "run" and not left.is_empty():
		w["state"] = "stunned"
		w["t"] = 4.0
	else:
		_remove_wild(w)


func _remove_wild(w: Dictionary) -> void:
	wilds.erase(w)
	var node: Node3D = w["node"]
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector3(0.05, 0.05, 0.05), 0.3)
	tw.tween_callback(node.queue_free)


# ================================================================ Beast Center machines
## A black-and-white diner floor, two checks per tile.
func _checker_tex() -> Texture2D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	for y in 8:
		for x in 8:
			var on := (x / 4 + y / 4) % 2 == 0
			img.set_pixel(x, y, Color("#f2f2ee") if on else Color("#2a2a30"))
	return ImageTexture.create_from_image(img)


func _flat_mat(col: Color, glow := 0.0, metal := 0.0, rough := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metal
	m.roughness = rough
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = glow
	return m


## The healing machine: a giant voxel soda can with a black glass window and a row of beast slots.
# ---------------------------------------------------------------- the kennel
## Pen tiles in reading order (pen i shows beast i of the town's kennel) and the beasts standing in them.
var kennel_pens: Array = []
## The room's walls (room_builder.gd): the ones between the camera and the player fade out of the way (see its fade).
var room_walls = null
var _kennel_nodes: Array = []


func kennel_town() -> String:
	return String(map.get("building", {}).get("town", map.get("parent", "")))


## Puts each kennel beast in its pen (call again after adopting or dropping one off).
func refresh_kennel() -> void:
	for n in _kennel_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_kennel_nodes = []
	if kennel_pens.is_empty():
		return
	var pens: Array = GameState.kennel(kennel_town())
	for i in mini(pens.size(), kennel_pens.size()):
		var b = pens[i].get("beast", null)
		if b == null:
			continue
		var node := _beast_node(b.genes, 0.62)
		node.position = tile_pos(kennel_pens[i]) + Vector3(0, 0.12, -0.05)
		node.rotation.y = -PI / 2.0
		add_child(node)
		_kennel_nodes.append(node)


func _build_healer(center: Vector3) -> void:
	var root := Node3D.new()
	root.position = center
	add_child(root)
	var k := VBld.Kit.new()
	var red := Color("#d8283a")
	var white := Color("#f4f4f4")
	var silver := Color("#c8ccd4")
	# a voxel cylinder: columns of a 0.1-unit grid inside a circle
	var r := 0.42
	for gx in range(-4, 5):
		for gz in range(-4, 5):
			var p := Vector2(gx * 0.1, gz * 0.1)
			if p.length() > r:
				continue
			var cx := p.x
			var cz := p.y
			k.box("color", Vector3(cx, 0.06, cz), Vector3(0.1, 0.12, 0.1), silver)
			k.box("color", Vector3(cx, 0.5, cz), Vector3(0.1, 0.76, 0.1), red)
			# the white swoosh round the middle
			var band := 0.92 + sin(atan2(cz, cx) * 2.0) * 0.06
			k.box("color", Vector3(cx, band, cz), Vector3(0.1, 0.1, 0.1), white)
			k.box("color", Vector3(cx, 1.3, cz), Vector3(0.1, 0.62, 0.1), red)
			k.box("color", Vector3(cx, 1.66, cz), Vector3(0.1, 0.1, 0.1), silver)
	k.box("color", Vector3(0, 1.74, 0.0), Vector3(0.36, 0.06, 0.36), silver)
	k.box("color", Vector3(0.0, 1.79, 0.1), Vector3(0.16, 0.04, 0.08), silver.darkened(0.2))
	var body := MeshInstance3D.new()
	body.mesh = k.mesh()
	root.add_child(body)
	# the black glass window (glows while healing)
	var win := MeshInstance3D.new()
	var wb := BoxMesh.new()
	wb.size = Vector3(0.5, 0.5, 0.06)
	win.mesh = wb
	var wm := _flat_mat(Color("#0c0c12"), 0.0, 0.6, 0.1)
	win.material_override = wm
	win.position = Vector3(0, 1.28, r + 0.03)
	root.add_child(win)
	# one slot per party beast
	var slots := []
	for i in 6:
		var s := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(0.09, 0.05, 0.05)
		s.mesh = sb
		s.material_override = _flat_mat(Color("#1a1a1e"))
		s.position = Vector3(-0.23 + i * 0.092, 0.72, r + 0.03)
		root.add_child(s)
		slots.append(s)
	var l := OmniLight3D.new()
	l.light_color = Color("#7affd0")
	l.light_energy = 0.0
	l.omni_range = 2.5
	l.position = Vector3(0, 1.3, 0.7)
	root.add_child(l)
	machines["healer"] = {"node": root, "window": win, "slots": slots, "light": l}


## The incubator: a brass base with a glass dome and an egg inside.
func _build_incubator(center: Vector3) -> void:
	var root := Node3D.new()
	root.position = center
	add_child(root)
	var k := VBld.Kit.new()
	k.box("brass", Vector3(0, 0.35, 0), Vector3(0.7, 0.7, 0.7), Color("#c8a040"))
	k.box("color", Vector3(0, 0.72, 0), Vector3(0.78, 0.06, 0.78), Color("#8a6a2a"))
	k.box("glow", Vector3(0.22, 0.45, 0.36), Vector3(0.1, 0.1, 0.02), Color("#ff5a3a"))
	k.box("glow", Vector3(0.06, 0.45, 0.36), Vector3(0.1, 0.1, 0.02), Color("#7aff7a"))
	k.box("color", Vector3(-0.15, 0.45, 0.36), Vector3(0.18, 0.12, 0.02), Color("#2a2a30"))
	var egg_k := VBld.Kit.new()
	for i in 6:
		var wdt: float = [0.14, 0.22, 0.26, 0.26, 0.22, 0.14][i]
		egg_k.box("color", Vector3(0, 0.8 + i * 0.06, 0), Vector3(wdt, 0.06, wdt), Color("#fff4dc") if i % 3 != 1 else Color("#ffb070"))
	var base := MeshInstance3D.new()
	base.mesh = k.mesh()
	root.add_child(base)
	var egg := MeshInstance3D.new()
	egg.mesh = egg_k.mesh()
	root.add_child(egg)
	var dome := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(0.6, 0.55, 0.6)
	dome.mesh = dm
	var gm := _flat_mat(Color(0.7, 0.95, 1.0, 0.28), 0.0, 0.2, 0.05)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dome.material_override = gm
	dome.position = Vector3(0, 1.03, 0)
	root.add_child(dome)
	machines["incubator"] = {"node": root, "dome": dome, "egg": egg}


func _sparkles(at: Vector3, col: Color, amount := 60, life := 1.2, radius := 0.6) -> void:
	var p := CPUParticles3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.07, 0.07)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	qm.material = mat
	p.mesh = qm
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.75
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3(0, 1, 0)
	p.spread = 70.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 2.0
	p.gravity = Vector3(0, -1.5, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var ramp := Gradient.new()
	ramp.set_color(0, col.lightened(0.4))
	ramp.set_color(1, Color(col, 0.0))
	p.color_ramp = ramp
	p.position = at
	add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.5).timeout.connect(p.queue_free)


## Plays when an egg hatches at the counter: the incubator glows and sparkles.
func play_hatch_fx() -> void:
	if not machines.has("incubator"):
		return
	var m: Dictionary = machines["incubator"]
	var node: Node3D = m["node"]
	_sparkles(node.position + Vector3(0, 1.0, 0), Color("#ffd870"), 90, 1.4, 0.45)
	_sparkles(node.position + Vector3(0, 1.0, 0), Color("#ffffff"), 40, 0.9, 0.3)
	var l := OmniLight3D.new()
	l.light_color = Color("#ffe08a")
	l.light_energy = 3.0
	l.omni_range = 3.0
	l.position = node.position + Vector3(0, 1.2, 0.3)
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, 1.2)
	tw.tween_callback(l.queue_free)
	var egg: Node3D = m["egg"]
	var tw2 := create_tween()
	for i in 4:
		tw2.tween_property(egg, "rotation:z", 0.25 if i % 2 == 0 else -0.25, 0.07)
	tw2.tween_property(egg, "rotation:z", 0.0, 0.07)


## The healing animation: each party beast's slot lights up, the window glows, sparkles fly.
func play_heal_fx(count: int) -> void:
	if not machines.has("healer"):
		return
	var m: Dictionary = machines["healer"]
	var node: Node3D = m["node"]
	var slots: Array = m["slots"]
	var lit := _flat_mat(Color("#7affd0"), 2.5)
	for i in mini(count, slots.size()):
		(slots[i] as MeshInstance3D).material_override = lit
		Sfx.play_tone("blip", 1.0 + i * 0.12, 4.0)
		await get_tree().create_timer(0.22).timeout
	var win: MeshInstance3D = m["window"]
	var wm: StandardMaterial3D = win.material_override
	wm.emission_enabled = true
	wm.emission = Color("#5affc8")
	var light: OmniLight3D = m["light"]
	Sfx.play("heal")
	for t in 3:
		var tw := create_tween()
		tw.tween_property(wm, "emission_energy_multiplier", 3.0, 0.25)
		tw.parallel().tween_property(light, "light_energy", 1.6, 0.25)
		tw.tween_property(wm, "emission_energy_multiplier", 0.4, 0.25)
		tw.parallel().tween_property(light, "light_energy", 0.3, 0.25)
		_sparkles(node.position + Vector3(0, 1.3, 0.5), Color("#7affd0"), 25, 0.9, 0.25)
		await tw.finished
	wm.emission_enabled = false
	light.light_energy = 0.0
	for s in slots:
		(s as MeshInstance3D).material_override = _flat_mat(Color("#1a1a1e"))
	_sparkles(node.position + Vector3(0, 1.0, 0.4), Color("#ffffff"), 50, 1.0, 0.5)


# ================================================================ interiors
## A scenery model (voxel_manifest.gd) stretched to `size` (width, height, depth), standing on the floor at `center`.
func _room_model(name: String, center: Vector3, size: Vector3) -> Node3D:
	var m: Mesh = VA.mesh(name)
	if m == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = m
	var bb := m.get_aabb()
	mi.scale = Vector3(size.x / maxf(bb.size.x, 0.001), size.y / maxf(bb.size.y, 0.001), size.z / maxf(bb.size.z, 0.001))
	mi.position = center - Vector3(bb.get_center().x * mi.scale.x, bb.position.y * mi.scale.y, bb.get_center().z * mi.scale.z)
	add_child(mi)
	return mi


## The same for a piece of the interior pack (assets/psx/interior).
func _room_model_interior(name: String, center: Vector3, size: Vector3) -> Node3D:
	var m := RoomBuilder.piece(name)
	if m == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = m
	var bb := m.get_aabb()
	mi.scale = Vector3(size.x / maxf(bb.size.x, 0.001), size.y / maxf(bb.size.y, 0.001), size.z / maxf(bb.size.z, 0.001))
	mi.position = center - Vector3(bb.get_center().x * mi.scale.x, bb.position.y * mi.scale.y, bb.get_center().z * mi.scale.z)
	add_child(mi)
	return mi


## The kilim closest in colour to `col`.
func _rug_pattern(col: Color) -> String:
	var best := "rug_red"
	var best_d := INF
	for k in RUG_PATTERNS:
		var c := Color(RUG_PATTERNS[k])
		var d := Vector3(c.r - col.r, c.g - col.g, c.b - col.b).length_squared() + pow(wrapf(c.h - col.h + 0.5, 0.0, 1.0) - 0.5, 2.0) * 0.5
		if d < best_d:
			best_d = d
			best = k
	return best


## Under an open-air roof: the deck's edge, the tower dropping away beneath it, and the town far below
## (fields, rooftops and trees in the haze, with a few clouds drifting past at eye level).
func _build_tower_drop(k: VBld.Kit, w: int, h: int, deck_col: Color, rng: RandomNumberGenerator) -> void:
	var st: Dictionary = VBld.STYLES.get(biome.get("style", "town"), VBld.STYLES["town"])
	var mid := Vector3(w / 2.0, 0, h / 2.0)
	var drop := 8.0
	k.box("planks", mid + Vector3(0, -0.15, 0), Vector3(w, 0.3, h), deck_col.darkened(0.3))
	k.box(String(st["wall"][0]), mid + Vector3(0, -drop / 2.0 - 0.3, 0), Vector3(w - 3.0, drop, h - 3.0), Color(st["wall"][1]))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var corner := mid + Vector3(sx * (w - 3.0) / 2.0, -drop / 2.0 - 0.3, sz * (h - 3.0) / 2.0)
			k.box("color", corner, Vector3(0.3, drop, 0.3), Color(st["trim"]))
			# a bracket under each corner of the deck
			k.box("color", corner + Vector3(sx * 0.6, drop / 2.0 - 0.5, sz * 0.6), Vector3(1.2, 0.2, 0.2), Color(st["trim"]))
	k.box("color", mid + Vector3(0, -drop - 0.4, 0), Vector3(140, 0.2, 140), Color(biome["ground"]))
	for i in 70:
		var a := rng.randf() * TAU
		var r := rng.randf_range(8.0, 40.0)
		var p := mid + Vector3(cos(a) * r, -drop - 0.3, sin(a) * r)
		if rng.randf() < 0.45:
			var roof := Color(st["roof"][1]).lerp(Color.from_hsv(rng.randf(), 0.4, 0.7), 0.3)
			k.box("color", p + Vector3(0, 0.4, 0), Vector3(1.6, 0.8, 1.4), Color(st["wall"][1]))
			k.box("color", p + Vector3(0, 0.95, 0), Vector3(1.8, 0.3, 1.6), roof)
		else:
			k.box("color", p + Vector3(0, 0.6, 0), Vector3(1.0, 1.2, 1.0), Color(biome["ground"]).darkened(0.35))
	for i in 7:
		var a2 := rng.randf() * TAU
		var r2 := rng.randf_range(7.0, 14.0)
		var cp := mid + Vector3(cos(a2) * r2, rng.randf_range(-4.5, -1.5), sin(a2) * r2)
		for j in 3:
			k.box("color", cp + Vector3(j * 0.7 - 0.7, rng.randf_range(-0.1, 0.2), rng.randf_range(-0.3, 0.3)), Vector3(1.1, 0.45, 0.8), Color("#f4f8ff"))


func _build_room() -> void:
	var room: Dictionary = map["room"]
	var b: Dictionary = map["building"]
	var w: int = map["w"]
	var h: int = map["h"]
	var key: String = map["room_key"]
	var wall_col := Color(str(room.get("wall", "#e8d8c0")))
	var rug_col := Color(str(room.get("rug", "#a04040")))
	var dark: bool = key.begins_with("crypt") or key in ["hideout", "temple_fire"]
	# an open-air room (the Sky Tower's roof): sky and sunshine, railings instead of walls
	var open_air: bool = room.get("open", false)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0d0a10")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#fff0dc") if not dark else Color("#8a7aa8")
	env.ambient_light_energy = 0.55 if not dark else 0.35
	if open_air:
		var sky := Sky.new()
		var sm := ProceduralSkyMaterial.new()
		sm.sky_top_color = Color(biome["sky_top"])
		sm.sky_horizon_color = Color(biome["sky_hz"])
		sm.ground_bottom_color = Color(biome["ground"]).darkened(0.2)
		sm.ground_horizon_color = Color(biome["sky_hz"])
		sky.sky_material = sm
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.ambient_light_color = Color(biome["sky_top"]).lerp(Color("#fff0dc"), 0.5)
		env.ambient_light_energy = biome["amb"]
		# haze only on the town far below, not on the platform
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_DEPTH
		env.fog_light_color = Color(biome["sky_hz"])
		env.fog_density = 0.75
		env.fog_depth_begin = 18.0
		env.fog_depth_end = 70.0
		env.fog_sky_affect = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.2
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_hdr_threshold = 1.15
	env.ssao_enabled = true
	env.ssao_intensity = 1.8
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#ffe8c8") if not open_air else Color(biome["sun"])
	sun.light_energy = (0.45 if not dark else 0.15) if not open_air else float(biome["sun_e"])
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-60, 20, 0)
	add_child(sun)
	# floors, walls, doors, windows, furniture and a light per room (an open-air roof keeps its deck and railings)
	room_walls = null
	if not open_air:
		room_walls = RoomBuilder.build(map, self, int(b["seed"]), {"checker": _checker_tex()})
	var k := VBld.Kit.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1, 1)
	var floors := {"wood": [], "tile": [], "rug": [], "ring": [], "lava": []}
	var stone_floor: bool = dark or key.begins_with("temple") or key == "cathedral"
	var main_floor := "tile" if map["floor"] == "tile" or stone_floor else "wood"
	var wall_tex := "plaster" if not dark else "stone_dark"
	if key.begins_with("temple") or key == "cathedral":
		wall_tex = "stone"
	elif key.begins_with("ceo"):
		wall_tex = "brick"
	var rng := RandomNumberGenerator.new()
	rng.seed = int(b["seed"])
	var mist := []
	var dk := Color("#5a3a26")
	var lw := Color("#a8784a")
	var stone := Color("#b8b0a0") if not dark else Color("#6a6670")
	# the Beast Center diner: red vinyl and chrome instead of wood
	var diner: bool = room.get("checker", false)
	var vinyl := Color("#d8283a")
	var chrome := Color("#e0e4ea")
	for y in h:
		for x in w:
			var c := MapGen.get_t(map, x, y)
			var center := Vector3(x + 0.5, 0, y + 0.5)
			var fxf := _xf(center + Vector3(0, 0.01, 0))
			match c:
				MapGen.IWALL, MapGen.IWINDOW when open_air:
					# the platform's edge: deck boards, a low curb, a post and rails to the next posts along
					floors["wood"].append(fxf)
					k.box("planks", center + Vector3(0, 0.08, 0), Vector3(1.0, 0.16, 1.0), wall_col.darkened(0.15))
					k.box("color", center + Vector3(0, 0.5, 0), Vector3(0.1, 0.8, 0.1), wall_col.darkened(0.35))
					for d in [Vector2i(1, 0), Vector2i(0, 1)]:
						if MapGen.get_t(map, x + d.x, y + d.y) in [MapGen.IWALL, MapGen.IWINDOW]:
							var along := Vector3(d.x, 0, d.y)
							for ry in [0.45, 0.85]:
								k.box("color", center + along * 0.5 + Vector3(0, ry, 0), Vector3(0.06, 0.06, 0.06) + along * 0.94, wall_col.darkened(0.35))
					continue
				MapGen.IWALL, MapGen.IWINDOW, MapGen.IDOOR, MapGen.LOCKED, MapGen.FURN, MapGen.IVOID, MapGen.IDIAG_A, MapGen.IDIAG_B:
					continue
				MapGen.RUG, MapGen.MAT:
					if not open_air:
						continue
					floors["rug"].append(fxf)
					# a dark woven border round the edge of each rug
					for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						if MapGen.get_t(map, x + d.x, y + d.y) != c:
							var along := Vector3(absf(d.y), 0, absf(d.x))
							k.box("color", center + Vector3(d.x * 0.45, 0.018, d.y * 0.45), Vector3(0.1, 0.02, 0.1) + along * 0.9, rug_col.darkened(0.45))
					continue
				MapGen.RING:
					floors["ring"].append(fxf)
					continue
				MapGen.IFLOOR:
					if open_air:
						floors["tile" if stone_floor else "wood"].append(fxf)
					continue
				MapGen.ITILE:
					if open_air:
						floors["tile"].append(fxf)
					continue
				MapGen.MIST:
					if open_air:
						floors[main_floor].append(fxf)
					mist.append(_xf(center, _voxel_rot(rng)))
					continue
				MapGen.LAVA:
					floors["lava"].append(_xf(center + Vector3(0, -0.05, 0)))
					continue
				MapGen.STAIRS_UP:
					if open_air:
						floors[main_floor].append(fxf)
					for i in 4:
						var sy := (i + 1) * 0.18
						k.box("stone", center + Vector3(0, sy / 2.0, 0.375 - i * 0.25), Vector3(1, sy, 0.25), stone)
					continue
				MapGen.STAIRS_DOWN:
					if open_air:
						floors[main_floor].append(fxf)
					k.box("color", center + Vector3(0, 0.015, 0), Vector3(0.9, 0.02, 0.9), Color("#1a1420"))
					for i in 3:
						k.box("stone", center + Vector3(0, 0.03, -0.3 + i * 0.3), Vector3(0.9, 0.04, 0.12), stone.darkened(0.4))
					continue
			# the room builder draws the floor under everything else, and the furniture
			if not open_air:
				if c in MapLoader.FURNITURE_CODES or map.get("furniture", {}).has(Vector2i(x, y)):
					continue
			else:
				# furniture stands on the floor around it
				match MapLoader.floor_around(map, Vector2i(x, y), -1):
					MapGen.RUG:
						floors["rug"].append(fxf)
					MapGen.IFLOOR:
						floors["tile" if stone_floor else "wood"].append(fxf)
					MapGen.ITILE:
						floors["tile"].append(fxf)
					_:
						floors[main_floor].append(fxf)
			match c:
				MapGen.HEALER:
					_build_healer(center)
				MapGen.INCUBATOR:
					_build_incubator(center)
				MapGen.KENNEL:
					# a straw bed behind a little picket fence; the beast in it comes from the town's kennel
					k.box("color", center + Vector3(0, 0.05, -0.05), Vector3(0.9, 0.1, 0.8), Color("#e0c060"))
					k.box("color", center + Vector3(0, 0.11, -0.05), Vector3(0.7, 0.04, 0.6), Color("#c8a040"))
					for side in [-1, 1]:
						k.box("pat_wood", center + Vector3(side * 0.46, 0.25, 0), Vector3(0.06, 0.5, 0.9), Color.WHITE)
					for px in [-0.36, -0.12, 0.12, 0.36]:
						k.box("pat_wood", center + Vector3(px, 0.2, 0.44), Vector3(0.08, 0.4, 0.06), Color.WHITE)
					k.box("pat_wood", center + Vector3(0, 0.3, 0.44), Vector3(0.9, 0.06, 0.05), Color.WHITE)
					kennel_pens.append(Vector2i(x, y))
				MapGen.COUNTER when open_air:
					if diner:
						k.box("color", center + Vector3(0, 0.475, 0), Vector3(1.0, 0.95, 0.9), vinyl)
						k.box("color", center + Vector3(0, 0.2, 0.46), Vector3(1.0, 0.12, 0.02), chrome)
						k.box("tin", center + Vector3(0, 0.98, 0), Vector3(1.02, 0.08, 0.95), chrome)
					elif open_air:
						k.box("pat_planks", center + Vector3(0, 0.475, 0), Vector3(1.0, 0.95, 0.9), Color.WHITE)
						k.box("pat_wood", center + Vector3(0, 0.98, 0), Vector3(1.02, 0.08, 0.95), Color.WHITE)
				MapGen.SHELF:
					k.box("planks", center + Vector3(0, 0.95, -0.2), Vector3(1.0, 1.9, 0.55), dk)
					k.box("pat_shelf_%d" % rng.randi_range(0, 2), center + Vector3(0, 0.95, 0.085), Vector3(0.9, 1.8, 0.02), Color.WHITE)
				MapGen.BOOKSHELF:
					k.box("planks", center + Vector3(0, 1.15, -0.18), Vector3(1.0, 2.3, 0.6), dk)
					# rows of books from the seamless pattern sheet
					k.box("pat_books_%d" % rng.randi_range(0, 2), center + Vector3(0, 1.12, 0.125), Vector3(0.92, 2.16, 0.02), Color.WHITE)
				MapGen.TABLE:
					k.box("pat_wood" if not diner else "tin", center + Vector3(0, 0.7, 0), Vector3(0.9, 0.08, 0.9), Color.WHITE if not diner else chrome)
					k.box("color", center + Vector3(0, 0.33, 0), Vector3(0.12, 0.66, 0.12), dk if not diner else chrome.darkened(0.3))
					if rng.randf() < 0.6:
						k.box("color", center + Vector3(rng.randf_range(-0.2, 0.2), 0.83, rng.randf_range(-0.2, 0.2)), Vector3(0.16, 0.18, 0.16), Color.from_hsv(rng.randf(), 0.5, 0.9))
				MapGen.STOOL:
					k.box("pat_wood", center + Vector3(0, 0.225, 0), Vector3(0.4, 0.45, 0.4), Color.WHITE)
				MapGen.PLANT:
					k.box("color", center + Vector3(0, 0.2, 0), Vector3(0.45, 0.4, 0.45), Color("#b0603a"))
					var pm := MeshInstance3D.new()
					pm.mesh = VP.bush("#4f9a3a", 1)
					pm.scale = Vector3(0.55, 0.7, 0.55)
					pm.position = center + Vector3(0, 0.4, 0)
					add_child(pm)
				MapGen.BED:
					k.box("planks", center + Vector3(0, 0.175, 0), Vector3(0.95, 0.35, 0.95), dk)
					k.box("pat_quilt_%d" % rng.randi_range(0, 2), center + Vector3(0, 0.43, 0.08), Vector3(0.9, 0.18, 0.75), Color.WHITE)
					k.box("color", center + Vector3(0, 0.45, -0.33), Vector3(0.7, 0.14, 0.22), Color("#f4f0e8"))
				MapGen.FIREPLACE:
					k.box("stone", center + Vector3(0, 0.75, -0.15), Vector3(1.0, 1.5, 0.7), stone)
					k.box("pat_stove", center + Vector3(0, 0.5, 0.21), Vector3(0.8, 1.0, 0.03), Color.WHITE)
					var fl := OmniLight3D.new()
					fl.light_color = Color("#ff9a50")
					fl.light_energy = 1.4
					fl.omni_range = 4.5
					fl.position = center + Vector3(0, 0.6, 0.6)
					add_child(fl)
				MapGen.ALTAR:
					k.box("stone", center + Vector3(0, 0.45, 0), Vector3(0.95, 0.9, 0.95), stone)
					var gem := MeshInstance3D.new()
					var prism := PrismMesh.new()
					prism.size = Vector3(0.35, 0.5, 0.35)
					gem.mesh = prism
					var gc := Color(b.get("glow", "#ffd870"))
					var gmat := StandardMaterial3D.new()
					gmat.albedo_color = gc
					gmat.emission_enabled = true
					gmat.emission = gc
					gmat.emission_energy_multiplier = 3.0
					gem.material_override = gmat
					gem.position = center + Vector3(0, 1.35, 0)
					add_child(gem)
					spinners.append(gem)
					var al := OmniLight3D.new()
					al.light_color = gc
					al.light_energy = 1.2
					al.omni_range = 3.5
					al.position = center + Vector3(0, 1.4, 0.3)
					add_child(al)
				MapGen.BOARD:
					k.box("planks", center + Vector3(0, 1.3, -0.42), Vector3(1.0, 1.4, 0.1), lw)
					for i in 5:
						k.box("color", center + Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(0.8, 1.8), -0.36), Vector3(0.22, 0.26, 0.02), Color("#f4eedc"))
				MapGen.TERMINAL when open_air:
					k.box("tin", center + Vector3(0, 0.75, -0.1), Vector3(0.8, 1.5, 0.6), Color("#8a96a8"))
				MapGen.PILLAR:
					# the castle kit's round stone pillar, floor to ceiling (fading like the walls when it's in the way)
					var pil := _room_model("stone_pillar_dark" if dark else "stone_pillar", center, Vector3(0.7, 2.85, 0.7))
					if pil != null and room_walls != null:
						room_walls.add_prop([pil], Vector2i(x, y), Vector2.ONE)
				MapGen.EXHIBIT:
					# a short round stone plinth (the same pillar, cut down) with the beast on top
					_room_model("stone_pillar_dark" if dark else "stone_pillar", center, Vector3(0.72, 0.7, 0.72))
					var race: int = map["exhibits"].get(Vector2i(x, y), 0)
					var ex := MeshInstance3D.new()
					ex.mesh = VB.mesh(RaceDB.genes(race))
					ex.scale = Vector3(0.45, 0.45, 0.45)
					ex.rotation.y = -PI / 2.0
					ex.position = center + Vector3(0, 0.7, 0)
					add_child(ex)
				MapGen.ORGAN:
					k.box("planks", center + Vector3(0, 0.65, -0.1), Vector3(1.0, 1.3, 0.7), Color("#2a1a1a"))
					k.box("color", center + Vector3(0, 0.9, 0.3), Vector3(1.0, 0.06, 0.25), Color("#f4f0e8"))
				MapGen.BENCH:
					if diner:
						k.box("color", center + Vector3(0, 0.225, 0), Vector3(1.0, 0.45, 0.7), vinyl)
						k.box("color", center + Vector3(0, 0.62, 0), Vector3(1.0, 0.5, 0.18), vinyl.darkened(0.1))
					else:
						k.box("pat_planks", center + Vector3(0, 0.225, 0), Vector3(1.0, 0.45, 0.7), Color.WHITE)
				MapGen.FOUNTAIN:
					k.box("stone", center + Vector3(0, 0.175, 0), Vector3(1.0, 0.35, 1.0), stone)
					k.box("glow", center + Vector3(0, 0.36, 0), Vector3(0.8, 0.05, 0.8), Color("#4aa8ff"))
				MapGen.CRYSTAL:
					# a round table under a violet cloth, the crystal ball glowing on a little stand
					var tm: Node3D = _room_model_interior("table_round", center, Vector3(0.95, 0.78, 0.95))
					if tm != null:
						var cloth := StandardMaterial3D.new()
						cloth.albedo_color = Color("#5a2a7a")
						cloth.roughness = 0.9
						(tm as MeshInstance3D).material_override = cloth
					var ball := MeshInstance3D.new()
					var sph := SphereMesh.new()
					sph.radius = 0.17
					sph.height = 0.34
					sph.radial_segments = 10
					sph.rings = 6
					ball.mesh = sph
					var bm := StandardMaterial3D.new()
					bm.albedo_color = Color("#9affff")
					bm.emission_enabled = true
					bm.emission = Color("#5adcff")
					bm.emission_energy_multiplier = 1.6
					ball.material_override = bm
					ball.position = center + Vector3(0, 0.98, 0)
					add_child(ball)
					var cl := OmniLight3D.new()
					cl.light_color = Color("#7affff")
					cl.light_energy = 0.6
					cl.omni_range = 2.2
					cl.position = center + Vector3(0, 1.1, 0)
					add_child(cl)
	if open_air:
		_build_tower_drop(k, w, h, wall_col, rng)
	var mi := MeshInstance3D.new()
	mi.mesh = k.mesh()
	add_child(mi)
	_multimesh(plane, floors["wood"], _tex_mat(PixelArt.room_texture("floor_wood", wall_col)), false)
	var tile_tex: Texture2D = PixelArt.room_texture("floor_tile", wall_col)
	if room.get("checker", false):
		tile_tex = _checker_tex()
	if dark:
		tile_tex = VT.terrain("top_plaza", "#5a5664")
	elif stone_floor:
		tile_tex = VT.terrain("top_plaza", wall_col.lerp(Color("#a8a49a"), 0.5).to_html(false))
	_multimesh(plane, floors["tile"], _tex_mat(tile_tex), false)
	_multimesh(plane, floors["rug"], _tex_mat(load(VT.PATTERN_DIR + _rug_pattern(rug_col) + ".png")), false)
	_multimesh(plane, floors["ring"], _tex_mat(VT.terrain("top_sand", "#d8c090")), false)
	var lm := _tex_mat(VT.terrain("lava", "#ff6a20"))
	lm.emission_enabled = true
	lm.emission_texture = lm.albedo_texture
	lm.emission_energy_multiplier = 1.6
	water_mats.append(lm)
	_multimesh(plane, floors["lava"], lm, false)
	var mm := _multimesh(VP.mist(), mist, null, false)
	if mm:
		bobbers.append([mm, 0.05, 1.1])
