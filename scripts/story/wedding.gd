extends "res://scripts/ui/modal.gd"
## Andrew's bonus ending: an adult wedding, years after the adventure. An isolated stage leaves the save untouched.
const Person = preload("res://scripts/gfx/voxel_person.gd")
const Kit = preload("res://scripts/ui/ui_kit.gd")
const Dialogue = preload("res://scripts/ui/cinematic_dialog.gd")
const BEATS := [
	["", "Years later, in Cocoon Cove..."],
	["Celebrant", "Andrew and Jared. A whole world of adventures, and you still found your way to each other."],
	["Andrew", "Turns out the best thing I found on my journey wasn't a treasure."],
	["Jared", "Good. Because I didn't bring a receipt."],
	["Celebrant", "Andrew, do you take Jared to be your husband, for all the adventures still to come?"],
	["Andrew", "I do. Every single one."],
	["Celebrant", "And Jared, do you choose Andrew, today and every day after?"],
	["Jared", "I do. Always."],
	["Celebrant", "Then it's official. Andrew and Jared, you are married!"],
	["", "Their next adventure began together. The beasts ate most of the cake."],
]
var beat := 0
var elapsed := 0.0
var _beat_time := 0.0
var _skip_hold := 0.0
var _previous_film_mode := false
var _view: SubViewport
var _stage: Node3D
var _camera: Camera3D
var _dialogue: Control
var _people := {}
var _rings: Array[MeshInstance3D] = []
var _confetti: Array[MeshInstance3D] = []
var _hint: Label


static func play() -> void:
	if UI.auto:
		for line in BEATS:
			await UI.say([line[1]], line[0])
		return
	await UI.play_film(load("res://scripts/story/wedding.gd").new())


func _ready() -> void:
	z_index = 1
	_previous_film_mode = UI.controls.film_mode
	UI.controls.set_film_mode(true)
	_view = SubViewport.new()
	_view.own_world_3d = true
	_view.handle_input_locally = false
	_view.msaa_3d = Viewport.MSAA_2X
	add_child(_view)
	var screen := TextureRect.new()
	screen.texture = _view.get_texture()
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	_stage = Node3D.new()
	_view.add_child(_stage)
	_build_garden()
	_hint = Kit.label("A: Next  ·  Hold B: Skip", 18, Color("#fff3db"))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hint.offset_top = 20
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	_layout()
	resized.connect(_layout)
	_show_beat()


func _exit_tree() -> void:
	if is_instance_valid(UI.controls):
		UI.controls.set_film_mode(_previous_film_mode)


func _layout() -> void:
	if _view != null:
		_view.size = Vector2i(maxi(1, int(size.x)), maxi(1, int(size.y)))


func _build_garden() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#e9c9b2")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#fff0de")
	env.ambient_light_energy = 0.45
	environment.environment = env
	_stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.light_color = Color("#ffe0af")
	sun.light_energy = 0.65
	sun.shadow_enabled = true
	_stage.add_child(sun)
	_box(Vector3(0, -0.12, 0.8), Vector3(14, 0.2, 14), Color("#82996c"))
	_box(Vector3(0, 0, 0.3), Vector3(3.6, 0.06, 4.6), Color("#e6d5b7"))
	_box(Vector3(0, 0.045, 2.0), Vector3(0.85, 0.025, 3.8), Color("#f1dfd2"))
	# A cream wedding arch, dressed with green leaves and small pink and gold flowers.
	for x in [-1.25, 1.25]:
		_box(Vector3(x, 1.2, -0.65), Vector3(0.12, 2.4, 0.12), Color("#fff0d8"))
	_box(Vector3(0, 2.4, -0.65), Vector3(2.65, 0.12, 0.12), Color("#fff0d8"))
	for i in 23:
		var x := lerpf(-1.3, 1.3, float(i) / 22.0)
		_sphere(Vector3(x, 2.35 + sin(float(i)) * 0.05, -0.6), 0.13, Color("#597b53"))
		if i % 2 == 0:
			_sphere(Vector3(x, 2.4, -0.49), 0.075, Color("#f0b5ac") if i % 4 == 0 else Color("#f8db88"))
	for x in [-1.6, 1.6]:
		for z in [-0.1, 1.3, 2.7]:
			_box(Vector3(x, 0.2, z), Vector3(0.35, 0.4, 0.35), Color("#c18b70"))
			for i in 5:
				_sphere(Vector3(x + sin(i * 2.4) * 0.15, 0.48 + float(i % 2) * 0.1, z + cos(i * 2.4) * 0.12), 0.10, Color("#e6adba"))
	var andrew := {"model": "tf30", "body": "male", "skin": GameState.hero.get("skin", "#e8c0a0"),
		"hair": GameState.hero.get("hair", "#6a4030"), "shirt": "#245e65", "pants": "#28373d", "pack": false, "glasses": false, "scale": 1.1}
	if GameState.hero.has("person"):
		andrew["face_person"] = GameState.hero["person"]
	_actor("Andrew", andrew, Vector3(-0.48, 0.06, 0), Vector2i(1, 0))
	_actor("Jared", {"model": "tf30", "body": "male", "skin": "#edc2a4", "hair": "#342b2c",
		"shirt": "#923e53", "pants": "#302d3a", "pack": false, "glasses": false, "scale": 1.1}, Vector3(0.48, 0.06, 0), Vector2i(-1, 0))
	_actor("Celebrant", {"outfit": "robe", "robe": "plain", "shirt": "#f0e5ce", "hair": "#b8b1a1", "skin": "#b57f62", "pack": false}, Vector3(0, 0.06, -0.85), Vector2i(0, 1))
	for i in 6:
		var x := -2.2 if i % 2 == 0 else 2.2
		var z := 1.3 + float(i / 2) * 0.9
		_box(Vector3(x, 0.3, z), Vector3(0.5, 0.6, 0.5), Color("#a2795b"))
		_box(Vector3(x, 0.72, z + 0.22), Vector3(0.5, 0.5, 0.08), Color("#a2795b"))
		var guest := _actor("Guest%d" % i, {"model": "tf%d" % [4, 7, 13, 29, 62, 74][i], "pack": false}, Vector3(x, 0.25, z), Vector2i(0, -1))
		Person.set_pose(guest, "sit", 0.36, true)
	for i in 2:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.035
		ring.outer_radius = 0.055
		var mi := _mesh(ring, Vector3(-0.06 if i == 0 else 0.06, 1.06, 0.1), Color("#e6bb5a"))
		mi.rotation_degrees.x = 75
		mi.visible = false
		_rings.append(mi)
	for i in 36:
		var piece := _box(Vector3.ZERO, Vector3(0.04, 0.02, 0.065), [Color("#e9acbc"), Color("#efd78e"), Color("#f9efe3")][i % 3])
		piece.visible = false
		_confetti.append(piece)
	_camera = Camera3D.new()
	_camera.fov = 42
	_camera.current = true
	_stage.add_child(_camera)
	_update_camera()


func _actor(actor_name: String, look: Dictionary, at: Vector3, facing: Vector2i) -> Node3D:
	var actor := Person.build(look)
	_stage.add_child(actor)
	actor.position = at
	Person.face(actor, facing)
	_people[actor_name] = actor
	if actor_name in ["Andrew", "Jared"]:
		var attachment := BoneAttachment3D.new()
		attachment.bone_name = "chest"
		var skeleton: Skeleton3D = actor.get_meta("skeleton")
		skeleton.add_child(attachment)
		var shirt := _box(Vector3.ZERO, Vector3(0.13, 0.19, 0.025), Color("#f4ede1"))
		shirt.reparent(attachment, false)
		shirt.position = Vector3(0, 0.07, 0.15)
		for x in [-0.035, 0.035]:
			var bow := _box(Vector3.ZERO, Vector3(0.06, 0.045, 0.03), Color("#292937"))
			bow.reparent(attachment, false)
			bow.position = Vector3(x, 0.15, 0.18)
	return actor


func _mesh(mesh: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	mi.material_override = mat
	mi.position = at
	_stage.add_child(mi)
	return mi


func _box(at: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	return _mesh(mesh, at, color)


func _sphere(at: Vector3, radius: float, color: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	_mesh(mesh, at, color)


func _show_beat() -> void:
	if is_instance_valid(_dialogue):
		_dialogue.queue_free()
	for person in _people.values():
		Person.set_talking(person, false)
	var line: Array = BEATS[beat]
	var actor: Node3D = _people.get(line[0], null)
	if actor != null:
		Person.set_talking(actor, true)
	_dialogue = Dialogue.new()
	_dialogue.setup([line[1]], line[0], null, actor)
	_dialogue.advance_requested.connect(_next_beat)
	add_child(_dialogue)
	_beat_time = 0.0


func _next_beat() -> void:
	if beat + 1 >= BEATS.size():
		close()
		return
	beat += 1
	_show_beat()


func _process(delta: float) -> void:
	elapsed += delta
	_beat_time += delta
	_skip_hold = _skip_hold + delta if Input.is_action_pressed("ui_cancel") else 0.0
	if _skip_hold >= 0.9:
		close()
		return
	_hint.text = "A: Next  ·  Hold B: Skip" if UI.controls.controller_guide() or UI.is_touch() else "Enter: Next  ·  Hold Esc: Skip"
	for actor_name in _people:
		var actor: Node3D = _people[actor_name]
		if actor_name in ["Andrew", "Jared"]:
			var reach := move_toward(float(actor.get_meta("reach_w", 0.0)), 1.0 if beat >= 5 else 0.0, delta * 2)
			Person.set_reach(actor, reach)
		Person.animate(actor, 0.0, 0.0)
	for i in _rings.size():
		_rings[i].visible = beat >= (5 if i == 0 else 7)
		var groom: Node3D = _people["Andrew" if i == 0 else "Jared"]
		var skeleton: Skeleton3D = groom.get_meta("skeleton")
		_rings[i].global_transform = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("r_hand")) * Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3.ZERO)
	for i in _confetti.size():
		var piece := _confetti[i]
		piece.visible = beat >= 8
		piece.position = Vector3(sin(float(i) * 2.4) * 1.8, 3.3 - fmod(_beat_time * 0.55 + float(i) * 0.09, 3.1), cos(float(i) * 1.8) * 0.8)
		piece.rotation = Vector3(elapsed + i, elapsed * 0.5, float(i))
	_update_camera()


func _update_camera() -> void:
	var close_shot := 1.0 - exp(-elapsed * 0.12)
	_camera.position = Vector3(0.7, 2.5, 5.8).lerp(Vector3(0.35, 1.95, 4.1), close_shot)
	_camera.look_at(Vector3(0, 1.05, 0))


func on_input(ev: InputEvent) -> void:
	if is_instance_valid(_dialogue):
		_dialogue.on_input(ev)


func _gui_input(ev: InputEvent) -> void:
	if (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
		_dialogue._advance()
		accept_event()
