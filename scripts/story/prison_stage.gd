extends Node3D
## The nightmare's dungeon and the later jail share their silhouette, distinct from the freight warehouse.
const Person = preload("res://scripts/gfx/voxel_person.gd")
const JARED_LOOK = preload("res://scripts/data/story_people.gd").LOOKS["Jared"]
var camera: Camera3D
var hero: Node3D
var jared: Node3D
var mouse: Node3D
var gate: Node3D
var clock := 0.0
var nightmare := false
var _materials := {}

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
	box(self, Vector3(0, -0.15, 0), Vector3(8, 0.3, 8), "777478")
	for wall in [Vector3(0, 1.7, -3.9), Vector3(-3.9, 1.7, 0), Vector3(3.9, 1.7, 0)]:
		box(self, wall, Vector3(8, 3.4, 0.3) if wall.z < -3 else Vector3(0.3, 3.4, 8), "62606e")
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
	mouse = mouse_model()
	add_child(mouse)
	mouse.position = Vector3(-1.25, 0.05, 1.8)
	for i in 3:
		var food := sphere(self, Vector3(-1.3 + i * 0.08, 0.06, 2.06), Vector3(0.09, 0.06, 0.08), "647342")
		food.rotation.y = i
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(-1.8, 2.6, 2.6)
	lamp.light_color = Color("b1b8df")
	lamp.light_energy = 1.4
	lamp.omni_range = 7
	add_child(lamp)
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.fov = 44
	camera.position = Vector3(-2.4, 2.7, 6.2)
	camera.look_at(Vector3(0, 0.8, 0))

func _process(delta: float) -> void:
	clock += delta
	Person.animate(hero, 0, 0, clock)
	Person.animate(jared, 0, 0, clock)
	if nightmare:
		mouse.rotation.y = sin(clock * 2.0) * 0.06

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

func mouse_model() -> Node3D:
	var root := Node3D.new()
	sphere(root, Vector3(0, 0.14, 0), Vector3(0.16, 0.13, 0.25), "9a9192")
	sphere(root, Vector3(0, 0.18, 0.22), Vector3(0.1, 0.09, 0.14), "9a9192")
	for x in [-0.09, 0.09]:
		sphere(root, Vector3(x, 0.28, 0.17), Vector3(0.065, 0.08, 0.025), "d79ba2")
		sphere(root, Vector3(x * 0.7, 0.21, 0.29), Vector3.ONE * 0.017, "24212c")
	sphere(root, Vector3(0, 0.18, 0.35), Vector3.ONE * 0.027, "d79ba2")
	for i in 9:
		sphere(root, Vector3(sin(i * 0.3) * 0.11, 0.045, -0.2 - i * 0.045), Vector3(0.02, 0.018, 0.035), "ce9299")
	return root
