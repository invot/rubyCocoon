extends Node3D
## The nightmare's dungeon and the later jail share their silhouette, distinct from the freight warehouse: a cell
## behind bars, and across the front of the dungeon a channel of dark water where Jared's ducks float.
## In the nightmare (opening.gd, dream_at) a crust of bread lies outside the bars and one of the ducks climbs out of
## the water, waddles over and eats it while the hero watches; in the jail a duck is Jared's helper (prison_escape.gd)
## and, the gate open, the ducks follow him and the hero out (walk_out).
const Person = preload("res://scripts/gfx/voxel_person.gd")
const Duck = preload("res://scripts/gfx/duck.gd")
const JARED_LOOK = preload("res://scripts/data/story_people.gd").LOOKS["Jared"]
## the water's surface in the channel, and where the channel runs (z, near and far edge)
const WATER_Y := -0.12
const CHANNEL := Vector2(3.4, 4.3)
## the ducks floating in the channel
const FLOATERS := [Vector3(0.6, WATER_Y, 3.9), Vector3(1.9, WATER_Y, 3.72), Vector3(-3.1, WATER_Y, 3.95)]
## the nightmare's crust of bread, just outside the bars in front of the hero
const BREAD_AT := Vector3(-0.8, 0.0, 1.22)
## the nightmare's hungry duck: from the water, up the channel's lip, over the floor to the bread (dream seconds)
const EATER_PATH := [Vector3(-2.35, WATER_Y, 3.9), Vector3(-2.1, WATER_Y, 3.48), Vector3(-1.95, 0.0, 3.2),
	Vector3(-0.82, 0.0, 1.47)]
const EATER_SWIM := 6.0
const EATER_HOP := 9.0
const EATER_WALK := 9.6
const EATER_EAT := 14.0
const EATER_FULL := 19.6
## when the voice in the dark behind the hero speaks up (they turn to it)
const VOICE := 24.0
## the walk out of the jail: the gate's gap to the dungeon's left side, then away
const OUT_PATH := [Vector3(-0.45, 0, 1.0), Vector3(-1.4, 0, 2.2), Vector3(-4.6, 0, 2.6)]
const OUT_SPEED := 1.3
var camera: Camera3D
var hero: Node3D
var jared: Node3D
## the jail's helper duck, which the player guides to the brass catch
var helper: Node3D
var ducks: Array = []
var eater: Node3D
var bread: Node3D
var gate: Node3D
var clock := 0.0
var nightmare := false
var _materials := {}
var _leaving := -1.0

func _ready() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("14131e")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("536080")
	env.ambient_light_energy = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	# the floor, cut through by the channel: the dungeon's floor behind it, a ledge in front, the channel's bed
	box(self, Vector3(0, -0.3, (-4.0 + CHANNEL.x) / 2.0), Vector3(8, 0.6, CHANNEL.x + 4.0), "777478")
	box(self, Vector3(0, -0.3, (CHANNEL.y + 5.2) / 2.0), Vector3(8, 0.6, 5.2 - CHANNEL.y), "777478")
	box(self, Vector3(0, -0.62, (CHANNEL.x + CHANNEL.y) / 2.0), Vector3(8, 0.2, CHANNEL.y - CHANNEL.x), "4a4852")
	var water := MeshInstance3D.new()
	var sheet := PlaneMesh.new()
	sheet.size = Vector2(7.6, CHANNEL.y - CHANNEL.x)
	water.mesh = sheet
	water.material_override = Duck.water(Color("#2a6878"))
	water.position = Vector3(0, WATER_Y, (CHANNEL.x + CHANNEL.y) / 2.0)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	for wall in [Vector3(0, 1.7, -3.9), Vector3(-3.9, 1.7, 0.6), Vector3(3.9, 1.7, 0.6)]:
		box(self, wall, Vector3(8, 3.4, 0.3) if wall.z < -3 else Vector3(0.3, 3.4, 9.2), "62606e")
	gate = Node3D.new()
	add_child(gate)
	for i in 17:
		box(gate, Vector3(-3.6 + i * 0.45, 1.3, 0.7), Vector3(0.055, 2.6, 0.055), "555c67")
	for y in [0.15, 1.3, 2.55]:
		box(gate, Vector3(0, y, 0.7), Vector3(7.5, 0.07, 0.07), "555c67")
	hero = Person.build(GameState.hero_look())
	add_child(hero)
	hero.position = Vector3(-0.45, 0, 0.15)
	Person.face(hero, Vector2i(0, 1))
	Person.set_reach(hero, 1.0)
	jared = Person.build(JARED_LOOK)
	add_child(jared)
	jared.position = Vector3(1.9, 0, -2.4)
	Person.face(jared, Vector2i(-1, 1))
	jared.visible = not nightmare
	for i in FLOATERS.size():
		var duck := _duck(FLOATERS[i], true)
		duck.rotation.y = [2.4, -1.9, 0.6][i]
		ducks.append(duck)
	if nightmare:
		# (the hero just stands at the bars, looking out at the bread)
		Person.set_reach(hero, 0.0)
		bread = (load("res://assets/props/bread_roll.glb") as PackedScene).instantiate()
		bread.scale = Vector3.ONE * 0.36
		bread.position = BREAD_AT
		add_child(bread)
		eater = _duck(EATER_PATH[0], true)
		dream_at(0.0)
	else:
		helper = _duck(Vector3(-1.25, 0.0, 1.8), false)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(-1.8, 2.6, 2.6)
	lamp.light_color = Color("b1b8df")
	lamp.light_energy = 1.4
	lamp.omni_range = 7
	add_child(lamp)
	# a cool glow off the water
	var pool_light := OmniLight3D.new()
	pool_light.position = Vector3(-0.6, 0.4, 3.9)
	pool_light.light_color = Color("6fa8c0")
	pool_light.light_energy = 0.5
	pool_light.omni_range = 3.5
	add_child(pool_light)
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.fov = 44
	camera.position = Vector3(-2.4, 2.7, 6.2)
	camera.look_at(Vector3(0, 0.8, 0))

func _duck(at: Vector3, floating: bool) -> Node3D:
	var duck: Node3D = Duck.new()
	duck.floating = floating
	duck.position = at
	add_child(duck)
	return duck

func _process(delta: float) -> void:
	clock += delta
	if _leaving >= 0.0:
		_leaving += delta
		_walk_out_frame()
		return
	Person.animate(hero, 0, 0, clock)
	Person.animate(jared, 0, 0, clock)

## The nightmare at `s` seconds in (opening.gd drives it, so a preview frame shows exactly that moment): the hungry
## duck paddles to the lip of the channel, hops up, waddles over to the bread and eats it, crumb by crumb.
func dream_at(s: float) -> void:
	if eater == null:
		return
	for i in ducks.size():
		var duck: Node3D = ducks[i]
		duck.position.x = FLOATERS[i].x + sin(s * 0.25 + i * 2.0) * 0.25
	var at: Vector3 = EATER_PATH[0]
	var way := Vector3(0.3, 0, -0.6)
	var clip := "Swim"
	if s >= EATER_SWIM and s < EATER_HOP:
		at = EATER_PATH[0].lerp(EATER_PATH[1], smoothstep(EATER_SWIM, EATER_HOP, s))
		way = EATER_PATH[1] - EATER_PATH[0]
	elif s >= EATER_HOP and s < EATER_WALK:
		var u := (s - EATER_HOP) / (EATER_WALK - EATER_HOP)
		at = EATER_PATH[1].lerp(EATER_PATH[2], u) + Vector3(0, sin(u * PI) * 0.18, 0)
		way = EATER_PATH[2] - EATER_PATH[1]
		clip = "Run"
	elif s >= EATER_WALK and s < EATER_EAT:
		at = EATER_PATH[2].lerp(EATER_PATH[3], (s - EATER_WALK) / (EATER_EAT - EATER_WALK))
		way = EATER_PATH[3] - EATER_PATH[2]
		clip = "Walk"
	elif s >= EATER_EAT:
		at = EATER_PATH[3]
		way = BREAD_AT - EATER_PATH[3]
		clip = "Eat" if s < EATER_FULL else "Idle"
	eater.position = at
	eater.face(way)
	if eater.floating != (s < EATER_HOP):
		eater.set_floating(s < EATER_HOP)
	eater.act(clip)
	# the bread gets smaller with every peck, and is gone by the time the duck's full
	var left := 1.0 - smoothstep(EATER_EAT + 0.4, EATER_FULL - 0.3, s)
	bread.scale = Vector3.ONE * 0.36 * maxf(left, 0.001)
	bread.visible = left > 0.02
	# the hero watches it all, eyes on the duck, until the voice speaks up from the dark behind them
	var look := eater.position - hero.position if s < VOICE else Vector3(1.6, 0, -2.6) - hero.position
	hero.get_node("Body").set_meta("yaw_to", atan2(look.x, look.z) if s >= EATER_HOP else 0.0)

## The gate's open: the hero and Jared walk out of the cell and away to the left, and the ducks follow them in a line
## (the helper first, the others climbing out of the water after it).
func walk_out() -> void:
	_leaving = 0.0
	Person.set_reach(hero, 0.0)
	for duck in ducks + [helper]:
		if duck != null:
			(duck as Node3D).set_floating(false)

func _walk_out_frame() -> void:
	_follow(hero, [Vector3(-0.45, 0, 0.15)] + OUT_PATH, _leaving * OUT_SPEED, true)
	_follow(jared, [Vector3(1.9, 0, -2.4), Vector3(0.4, 0, 0.3)] + OUT_PATH, maxf(0.0, _leaving - 0.6) * OUT_SPEED, true)
	var followers: Array = [helper] + ducks
	for i in followers.size():
		var duck: Node3D = followers[i]
		if duck == null:
			continue
		var start: Vector3 = duck.get_meta("start", duck.position)
		duck.set_meta("start", start)
		_follow(duck, [start, Vector3(start.x * 0.5 - 0.6, 0, 2.4)] + OUT_PATH.slice(1), maxf(0.0, _leaving - 1.6 - i * 0.5) * OUT_SPEED * 0.95, false)

## Moves `who` `dist` along `path`, walking (a person) or waddling (a duck) while it goes, and still at its end.
func _follow(who: Node3D, path: Array, dist: float, person: bool) -> void:
	var pos: Vector3 = path[0]
	var way := Vector3(0, 0, 1)
	var moving := false
	var left := dist
	for i in path.size() - 1:
		var a: Vector3 = path[i]
		var b: Vector3 = path[i + 1]
		var leg := a.distance_to(b)
		way = b - a
		if left <= leg:
			pos = a.lerp(b, left / maxf(leg, 0.001))
			moving = dist > 0.0
			break
		left -= leg
		pos = b
	who.position = pos
	if person:
		who.get_node("Body").set_meta("yaw_to", atan2(way.x, way.z))
		Person.animate(who, Person.phase_for(dist, OUT_SPEED), OUT_SPEED if moving else 0.0, clock)
	else:
		(who as Node3D).face(way)
		(who as Node3D).act("Walk" if moving else "Idle", 1.4)

func material(hex: String) -> Material:
	if _materials.has(hex):
		return _materials[hex]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(hex)
	mat.albedo_texture = load("res://assets/interiors/tex/floor_stone.png")
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.roughness = 0.85
	_materials[hex] = mat
	return mat

func box(parent: Node3D, at: Vector3, size: Vector3, hex: String) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return piece(parent, mesh, at, Vector3.ONE, hex)

func sphere(parent: Node3D, at: Vector3, size: Vector3, hex: String) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1
	mesh.height = 2
	mesh.radial_segments = 24
	mesh.rings = 12
	return piece(parent, mesh, at, size, hex)

func piece(parent: Node3D, mesh: Mesh, at: Vector3, size: Vector3, hex: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(hex)
	node.position = at
	node.scale = size
	parent.add_child(node)
	return node
