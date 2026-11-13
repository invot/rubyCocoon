extends RefCounted
## Loading-screen vignettes: staged moments in the real maps (beasts using their powers, people with their beasts),
## shot from a free cinematic camera with the interface hidden. Not gameplay views.
## godot --path . --resolution 1920x1080 -- --scene=loading-art --shots=res://build/loading_screens/raw/ --shot_w=0
##   [--only=owl,dock] picks vignettes; each saves <shots><name>_<cam>.png for every camera it lists.
const VPer = preload("res://scripts/gfx/voxel_person.gd")
const BeastModel = preload("res://scripts/gfx/beast_model.gd")
const RaceDB = preload("res://scripts/data/race_db.gd")
const MapGen = preload("res://scripts/world/map_gen.gd")

const AIR := Color("#c8fff0")
const WATER := Color("#5ac8ff")
const FIRE := Color("#ff7a3a")
const EARTH := Color("#7ae05a")
const KID1 := {"skin": "#f0c8a0", "hair": "#a06030", "hair_style": 1, "shirt": "#6aa84f", "pants": "#5a4a3a"}
const KID2 := {"skin": "#c08a60", "hair": "#303040", "shirt": "#3a6a9a", "pants": "#4a4a52", "hat": "#e8c040"}
const KID3 := {"skin": "#f8d8c0", "hair": "#e0c070", "hair_style": 1, "shirt": "#e8a0c0", "pants": "#6a5a8a"}
const KID4 := {"skin": "#8a5a3a", "hair": "#2a1a10", "shirt": "#e07a5a", "pants": "#3a4a6a"}

## Each vignette: map, the anchor tile ("start" or a Vector2i), its actors and its cameras. Actor offsets are in world
## units from the anchor's ground; "air" lifts an actor that far above the anchor instead of standing on the ground.
## People: look ("hero" or a look), face (Vector2i), pose (sit / kneel / hang / cheer / reach / talk / rod / run).
## Beasts: form, k (scale), yaw (degrees; 0 faces +x), cast (an element colour: glows as it lets its power go), mount.
## Cameras: [name, from offset, look-at offset, fov].
var VIGNETTES := {
	"owl": {"map": "route5", "at": "start", "actors": [
		{"form": "owl_3", "k": 3.2, "air": 6.0, "o": Vector3(0, 0, 0), "yaw": -30.0, "cast": AIR},
		{"look": "hero", "hang_under": 0, "face": Vector2i(1, 0), "pose": "hang", "drop": 0.5},
	], "focus": true, "cams": [
		["front", Vector3(3.4, 1.2, 3.4), Vector3(0, -0.3, 0), 50.0],
		["above", Vector3(-1.2, 3.2, 3.8), Vector3(0, -0.5, 0), 50.0],
		["below", Vector3(2.4, -1.6, 3.0), Vector3(0, 0.2, 0), 55.0],
	]},
	"dock": {"map": "caccoon", "at": Vector2i(40, 38), "actors": [], "dock": true, "cams": [
		["water", Vector3(0, 0.6, 7.5), Vector3(0, 0.9, 0), 40.0],
		["behind", Vector3(-3.0, 3.0, -4.5), Vector3(0.5, 0.2, 2.5), 45.0],
	]},
	# an Embit lighting the campfire for friends on the Coastal Path
	"campfire": {"map": "route1", "at": "start", "open": 0, "actors": [
		{"flame": true, "o": Vector3(0.1, 0, 0)},
		{"form": "dino_1", "k": 1.2, "o": Vector3(1.2, 0, 0), "yaw": 180.0, "cast": FIRE},
		{"look": "hero", "o": Vector3(-1.0, 0, -0.4), "face": Vector2i(1, 0), "pose": "sit", "seat": 0.0},
		{"look": KID3, "o": Vector3(-0.2, 0, 0.9), "face": Vector2i(0, -1), "pose": "cheer"},
		{"look": KID2, "o": Vector3(0.0, 0, -1.2), "face": Vector2i(0, 1), "pose": "kneel"},
		{"form": "owl_1", "k": 1.0, "o": Vector3(-1.8, 0, 0.6), "yaw": -60.0},
	], "cams": [
		["low", Vector3(-0.6, 0.45, 3.4), Vector3(0.3, 0.6, -0.2), 50.0],
		["over", Vector3(-3.2, 2.2, 2.4), Vector3(0.6, 0.4, -0.3), 45.0],
	]},
	# a Toadmiral's fountain over laughing children in Bellerive
	"fountain": {"map": "tidewater", "at": "start", "open": 0, "actors": [
		{"form": "frog_3", "k": 1.6, "o": Vector3(0, 0, -1.2), "yaw": -90.0, "cast": WATER},
		{"look": KID3, "o": Vector3(-1.1, 0, 0.4), "face": Vector2i(0, 1), "pose": "cheer"},
		{"look": KID4, "o": Vector3(1.0, 0, 0.6), "face": Vector2i(-1, -1), "pose": "run"},
		{"form": "crab_1", "k": 0.9, "o": Vector3(0.2, 0, 1.0), "yaw": 60.0},
	], "cams": [
		["worm", Vector3(0.4, 0.25, 3.6), Vector3(0, 1.6, -1.0), 55.0],
		["wide", Vector3(3.5, 2.0, 4.0), Vector3(0, 1.0, -0.6), 42.0],
	]},
	# a Crystusk heaving the earth up for its trainer on the Mine Road
	"boulder": {"map": "route6", "at": "start", "open": 0, "actors": [
		{"form": "boar_3", "k": 1.5, "o": Vector3(0.6, 0, 0), "yaw": 160.0, "cast": EARTH},
		{"look": "hero", "o": Vector3(-1.0, 0, 0.5), "face": Vector2i(1, 0), "pose": "reach"},
		{"form": "worm_1", "k": 0.9, "o": Vector3(-1.6, 0, -0.5), "yaw": 0.0},
	], "cams": [
		["hero", Vector3(-2.8, 0.9, 2.4), Vector3(0.6, 0.9, 0), 45.0],
		["beast", Vector3(2.8, 0.5, 2.6), Vector3(-0.2, 1.0, 0), 50.0],
	]},
	# a child riding on an Elderoot's shoulder through Vinehollow
	"grove": {"map": "vinehollow", "at": "start", "open": 0, "actors": [
		{"form": "tree_3", "k": 1.7, "o": Vector3(0, 0, 0), "yaw": -70.0, "cast": EARTH},
		{"look": KID1, "ride": 0, "face": Vector2i(0, 1), "pose": "cheer"},
		{"look": KID2, "o": Vector3(1.4, 0, 1.0), "face": Vector2i(-1, -1), "pose": "talk"},
	], "cams": [
		["up", Vector3(0.8, 0.3, 3.4), Vector3(0, 2.0, 0), 55.0],
		["side", Vector3(-3.5, 1.6, 3.0), Vector3(0, 1.6, 0), 42.0],
	]},
	# soaking in Emberfall with an Infernook warming the water
	"springs": {"map": "emberfall", "at": "start", "open": 0, "actors": [
		{"form": "marmot_3", "k": 1.3, "o": Vector3(0.9, 0, -0.4), "yaw": -120.0, "cast": FIRE},
		{"look": "hero", "o": Vector3(-0.6, 0, 0.2), "face": Vector2i(1, 0), "pose": "sit", "seat": 0.0},
		{"look": KID4, "o": Vector3(-1.4, 0, -0.6), "face": Vector2i(1, 1), "pose": "talk"},
		{"form": "frog_1", "k": 0.9, "o": Vector3(0.1, 0, 0.9), "yaw": -90.0},
	], "cams": [
		["close", Vector3(-1.6, 0.8, 2.6), Vector3(0.4, 0.6, -0.2), 45.0],
		["high", Vector3(2.5, 3.2, 3.0), Vector3(0, 0.3, -0.2), 45.0],
	]},
	# friendly sparring in Sunwall: a Saguaroar's fire against a Snapshell's water
	"spar": {"map": "sundown", "at": "start", "open": 0, "actors": [
		{"form": "cactus_3", "k": 1.4, "o": Vector3(-1.4, 0, 0), "yaw": 0.0, "cast": FIRE},
		{"form": "crab_2", "k": 1.3, "o": Vector3(1.4, 0, 0), "yaw": 180.0, "cast": WATER},
		{"look": "hero", "o": Vector3(-2.6, 0, 0.6), "face": Vector2i(1, 0), "pose": "cheer"},
		{"look": KID2, "o": Vector3(2.6, 0, 0.6), "face": Vector2i(-1, 0), "pose": "reach"},
	], "cams": [
		["between", Vector3(0, 0.35, 3.0), Vector3(0, 0.9, 0), 60.0],
		["over", Vector3(-3.8, 1.6, 1.8), Vector3(1.0, 0.7, 0), 42.0],
	]},
	# a Nocturna and a Galeberry lighting the way home across the moor
	"moor": {"map": "gravenmoor", "at": "start", "open": 0, "actors": [
		{"form": "bat_3", "k": 1.4, "air": 1.8, "o": Vector3(0.8, 0, -0.4), "yaw": -110.0, "cast": AIR},
		{"form": "berry_3", "k": 1.2, "o": Vector3(-0.9, 0, 0.3), "yaw": -60.0, "cast": AIR},
		{"look": "hero", "o": Vector3(0.0, 0, 0.6), "face": Vector2i(0, 1), "pose": "reach"},
	], "cams": [
		["low", Vector3(0.6, 0.4, 3.4), Vector3(0, 1.2, 0), 50.0],
	]},
	# racing a Gustowl along the sand
	"race": {"map": "route1", "at": "start", "open": 1, "actors": [
		{"look": "hero", "o": Vector3(0, 0, 0), "face": Vector2i(-1, 0), "pose": "run"},
		{"form": "owl_2", "k": 1.5, "air": 1.4, "o": Vector3(0.4, 0, -0.9), "yaw": 180.0, "cast": AIR},
		{"form": "dino_2", "k": 1.0, "o": Vector3(1.3, 0, 0.6), "yaw": 180.0},
	], "cams": [
		["chase", Vector3(-3.0, 0.5, 2.2), Vector3(0.3, 0.9, -0.2), 45.0],
	]},
}

var main: Node
var opts: Dictionary
var people: Array = []
var clock := 0.0

func run(root: Node, options: Dictionary) -> void:
	main = root
	opts = options
	var only: Array = Array(String(opts.get("only", "")).split(",", false))
	for name in VIGNETTES:
		if only.is_empty() or name in only:
			await stage(name, VIGNETTES[name])
	print("LOADING ART DONE")

func hold(t: float) -> void:
	var left := t
	while left > 0.0:
		await main.get_tree().process_frame
		var dt: float = main.get_process_delta_time()
		left -= dt
		clock += dt
		for p in people:
			if is_instance_valid(p):
				VPer.animate(p, float(p.get_meta("phase", 0.0)), float(p.get_meta("speed", 0.0)), clock)

func hide_ui() -> void:
	for n in main.get_tree().root.find_children("*", "CanvasLayer", true, false):
		n.visible = false

## The most open level ground on the map (room all round, and more to the south for the camera); `pick` takes the
## next best spot at least 10 tiles from the ones before it.
func open_spot(w: Node, pick: int) -> Vector2i:
	var m: Dictionary = w.map
	var ok := {}
	for y in int(m["h"]):
		for x in int(m["w"]):
			var q := Vector2i(x, y)
			if MapGen.get_t(m, x, y) in [MapGen.GRASS, MapGen.PATH, MapGen.FLOWERS, MapGen.PLAZA, MapGen.SAND] and w._walkable(q):
				ok[q] = w.tile_pos(q).y
	var scored: Array = []
	for q in ok:
		var n := 0
		for dy in range(-3, 6):
			for dx in range(-4, 5):
				var r: Vector2i = q + Vector2i(dx, dy)
				if ok.has(r) and absf(float(ok[r]) - float(ok[q])) < 0.05:
					n += 1
		scored.append([n, q])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	var taken: Array = []
	for e in scored:
		if taken.all(func(t): return (t as Vector2i).distance_to(e[1]) >= 10.0):
			taken.append(e[1])
			if taken.size() > pick:
				print("open spot ", e[1], " score ", e[0])
				return e[1]
	return w.player_pos

func ground(w: Node, at: Vector3, o: Vector3) -> Vector3:
	var p := at + o
	return Vector3(p.x, w.tile_pos(Vector2i(floori(p.x), floori(p.z))).y, p.z)

func person(w: Node, spec: Dictionary) -> Node3D:
	var look: Dictionary = spec["look"] if spec.get("look", "hero") is Dictionary else GameState.hero_look()
	var n: Node3D = VPer.build(look)
	w.add_child(n)
	VPer.face(n, spec.get("face", Vector2i(0, 1)))
	match String(spec.get("pose", "")):
		"sit":
			VPer.set_pose(n, "sit", float(spec.get("seat", 0.36)), true)
		"kneel":
			VPer.set_pose(n, "kneel", 0.0, true)
		"hang":
			n.set_meta("hang_w", 1.0)
		"cheer":
			n.set_meta("hang_w", 0.75)
		"reach":
			VPer.set_reach(n, 1.0)
		"talk":
			VPer.set_talking(n, true, true)
		"rod":
			VPer.set_ready(n, "rod", true)
		"run":
			n.set_meta("phase", 0.3)
			n.set_meta("speed", 4.5)
	if spec.has("yaw"):
		n.rotation.y = deg_to_rad(float(spec["yaw"]))
	people.append(n)
	return n

## A campfire's glow: a warm light and soft bright flame shapes (light effects only).
func flame(w: Node) -> Node3D:
	var n := Node3D.new()
	w.add_child(n)
	var light := OmniLight3D.new()
	light.light_color = Color("#ffa040")
	light.light_energy = 3.0
	light.omni_range = 4.0
	light.position = Vector3(0, 0.5, 0)
	n.add_child(light)
	for i in 3:
		var mi := MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = 0.16 - i * 0.04
		m.height = 0.7 - i * 0.15
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = [Color("#ff6a20"), Color("#ffb040"), Color("#fff0a0")][i]
		m.material = mat
		mi.mesh = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(0, 0.3 + i * 0.03, 0)
		n.add_child(mi)
	return n

func beast(w: Node, spec: Dictionary) -> Node3D:
	var r: Node3D = BeastModel.rig(RaceDB.genes(RaceDB.of_form(String(spec["form"]))), float(spec.get("k", 1.0)))
	w.add_child(r)
	r.rotation.y = deg_to_rad(float(spec.get("yaw", 0.0)))
	if spec.get("mount", false):
		BeastModel.pose_mounted(r)
	return r

func stage(name: String, v: Dictionary) -> void:
	UI.auto = true
	await main._do_goto(String(v["map"]), v["at"])
	var w: Node = main.world
	w.frozen = true
	await hold(2.5)
	w.player.visible = false
	if v.has("open"):
		w.player_pos = open_spot(w, int(v["open"]))
	var at: Vector3 = w.tile_pos(w.player_pos)
	var made: Array = []
	var casts: Array = []
	var actors: Array = v["actors"].duplicate(true)
	if v.get("dock", false):
		actors = dock_party(w)
	for spec in actors:
		var node: Node3D
		if spec.has("flame"):
			node = flame(w)
		elif spec.has("form"):
			node = beast(w, spec)
		else:
			node = person(w, spec)
		if spec.has("air"):
			node.position = at + spec.get("o", Vector3.ZERO) + Vector3(0, float(spec["air"]), 0)
		elif spec.has("ride"):
			# sitting up on a beast's shoulders
			var rb: Node3D = made[int(spec["ride"])]
			var top: float = BeastModel.bounds(rb).end.y * rb.scale.y
			node.position = rb.position + Vector3(0, top * float(spec.get("ride_at", 0.82)), 0)
		elif spec.has("hang_under"):
			# hanging by the hands from the beast's feet
			var b: Node3D = made[int(spec["hang_under"])]
			var bb: AABB = BeastModel.bounds(b)
			var feet := b.position + Vector3(0, bb.position.y * b.scale.y + 0.25, 0)
			node.position = feet - Vector3(0, VPer.height() * float(spec.get("drop", 1.1)), 0)
		else:
			node.position = ground(w, at, spec.get("o", Vector3.ZERO))
		made.append(node)
		if spec.has("cast"):
			casts.append([node, spec["cast"]])
	hide_ui()
	await hold(1.5)
	for i in actors.size():
		if String(actors[i].get("pose", "")) == "rod":
			var tip = VPer.rod_tip(made[i])
			if tip != null:
				var f: Vector2i = actors[i].get("face", Vector2i(0, 1))
				var line: MeshInstance3D = w._rod_mesh(tip, Vector3(tip.x + f.x * 1.6, at.y - 0.55, tip.z + f.y * 1.6), 0.008, Color("#f0f0f0"))
				w.add_child(line)
				made.append(line)
	# "focus": cameras frame the middle of everyone staged (beasts by their bounds, people at their chest)
	var base := at
	if v.get("focus", false):
		var sum := Vector3.ZERO
		for i in actors.size():
			var nd: Node3D = made[i]
			if actors[i].has("form"):
				sum += nd.position + BeastModel.bounds(nd).get_center() * nd.scale.y
			else:
				sum += nd.position + Vector3(0, 0.75, 0)
		base = sum / float(actors.size())
		print("focus ", base - at)
	var cam: Camera3D = w.cam
	w.cam_free = true
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	for c in v["cams"]:
		cam.fov = float(c[3])
		cam.position = base + c[1]
		cam.look_at(base + c[2], Vector3.UP)
		var wind := 0.0
		for pair in casts:
			wind = maxf(wind, BeastModel.pose_cast(pair[0], pair[1]))
		await hold(maxf(0.6, wind * 0.95))
		hide_ui()
		await RenderingServer.frame_post_draw
		main._save_shot(String(opts.get("shots", "res://build/loading_screens/raw/")) + name + "_" + String(c[0]) + ".png")
		await hold(1.2)
	for n in made:
		n.queue_free()
	people.clear()
	w.player.visible = true

## Four friends fishing off the end of the dock, with their water beasts splashing about: found from the dock's edge.
func dock_party(w: Node) -> Array:
	return [
		{"look": "hero", "o": Vector3(-1.0, 0, 0), "face": Vector2i(0, 1), "pose": "rod"},
		{"look": {"skin": "#c08a60", "hair": "#303040", "shirt": "#3a6a9a", "pants": "#4a4a52", "hat": "#e8c040"}, "o": Vector3(0.2, 0, 0), "face": Vector2i(0, 1), "pose": "sit", "seat": 0.05},
		{"look": {"skin": "#f8d8c0", "hair": "#e0c070", "hair_style": 1, "shirt": "#e8a0c0", "pants": "#6a5a8a"}, "o": Vector3(1.2, 0, 0), "face": Vector2i(0, 1), "pose": "cheer"},
		{"look": {"skin": "#8a5a3a", "hair": "#2a1a10", "shirt": "#e07a5a", "pants": "#3a4a6a"}, "o": Vector3(2.3, 0, 0), "face": Vector2i(0, 1), "pose": "rod"},
		{"form": "crab_1", "k": 0.9, "o": Vector3(0.7, 0, 0.3), "yaw": -90.0},
		{"form": "frog_2", "k": 1.1, "air": -0.4, "o": Vector3(1.6, 0, 1.6), "yaw": 120.0, "cast": WATER},
	]
