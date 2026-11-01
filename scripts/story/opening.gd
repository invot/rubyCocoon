extends Node3D
## A self-contained, real-time prologue. No map visits, inventory or quest knowledge is granted here.
## The same timeline drives playback and deterministic screenshot previews.
##
## Two sets, built from the game's own pieces: Gearhart's office at the top of his tower by night (wood floor, brick,
## the company sign over the desk, crates and the freight lift), lit by the moon through the window wall, a desk lamp
## and a pool of light over the rug, with his freight room behind a steel door in its east wall; then the first
## morning of spring outside the hero's home in Cocoon Cove.
## The reveal is played straight: Gearhart sends his staff home with a pep talk about "freight", walks alone to the
## steel door and steps through. The music stops dead, a dread hit (sfx "dread"), and the room behind is lined with
## neon cages full of trainers (Lio, Bea and Orin among them, as the hero finds them later), with a bank of glass
## canisters at the far end, a beast floating in each.

const Person = preload("res://scripts/gfx/voxel_person.gd")
const Assets = preload("res://scripts/gfx/voxel_assets.gd")
const Props = preload("res://scripts/gfx/voxel_props.gd")
const BeastModel = preload("res://scripts/gfx/beast_model.gd")
const RaceDB = preload("res://scripts/data/race_db.gd")
const Kit = preload("res://scripts/ui/ui_kit.gd")
const Houses = preload("res://scripts/gfx/house_models.gd")
const Textures = preload("res://scripts/gfx/voxel_textures.gd")
const RoomBuilder = preload("res://scripts/gfx/room_builder.gd")
const CinematicDialog = preload("res://scripts/ui/cinematic_dialog.gd")
const CompanyBrand = preload("res://scripts/gfx/company_brand.gd")
const TrainerCell = preload("res://scripts/story/trainer_cell.gd")
const GEAR_LOOK := {"skin": "#e8c0a0", "hair": "#d8d8e0", "shirt": "#1a1a22", "pants": "#1a1a22", "hat": "#2a2a2a", "outfit": "coat"}
const ENGINEER_LOOK := {"skin": "#bc8868", "hair": "#49332d", "shirt": "#d6ae58", "pants": "#455469", "outfit": "apron", "glasses": false}
## Gearhart's staff besides Mara: a foreman in a hard hat and a clerk
const STAFF_LOOKS := [
	{"skin": "#e0b890", "hair": "#2a2420", "shirt": "#5a6a80", "pants": "#2e3440", "outfit": "uniform", "hat": "#d8a838"},
	{"skin": "#8a5a40", "hair": "#1a1414", "shirt": "#c8c0b0", "pants": "#3a3a48", "body": "female"},
]
## the other captives (Lio, Bea and Orin wear TrainerCell.LOOKS): trainers in travelling clothes, packs on
const CAPTIVE_LOOKS := [
	{"skin": "#f0d0b0", "hair": "#d8b060", "shirt": "#6aa070", "pants": "#4a4038", "body": "female", "pack": true},
	{"skin": "#9a6848", "hair": "#2a2020", "shirt": "#c86a4a", "pants": "#3a4a5a", "pack": true},
	{"skin": "#d8a880", "hair": "#6a3a2a", "shirt": "#7a7ac0", "pants": "#4a4a4a", "body": "female", "pack": true},
]
const LENGTH := 72.5
## Gearhart heads for the steel door; the cut into the freight room; the cut to spring
const DOOR := 23.5
const INSIDE := 28.5
const DAWN := 40.5
## start, end, speaker, subtitle, camera shot. Subtitles advance automatically; A also advances a beat.
const BEATS := [
	[0.0, 3.5, "", "", "wide"],
	[3.5, 10.0, "MAGNUS GEARHART", "Gather round, team. Tomorrow is the first day of spring, and new trainers fill every road.", "gear"],
	[10.0, 16.5, "ENGINEER MARA", "The new freight robots are ready, sir. The lifts run quiet, and every crate is sealed.", "staff"],
	[16.5, 23.5, "MAGNUS GEARHART", "Splendid! Our friend in Gravenmoor pays well for every delivery. Off home, all of you. Big day tomorrow.", "plan"],
	[23.5, 28.5, "MAGNUS GEARHART", "Now then. Let's look in on tonight's freight.", "door"],
	[28.5, 33.5, "TRAINER BEA", "Please, let us out! Give us back our beasts!", "reveal"],
	[33.5, 37.5, "MAGNUS GEARHART", "Every trainer boxed, every beast bottled. General Vexmora pays by the bond.", "tubes"],
	[37.5, 40.5, "", "", "cages"],
	[40.5, 46.0, "", "", "spring"],
	[46.0, 52.5, "", "Out of their burrows. Off to find food, a mate... or trouble.", "beasts"],
	[52.5, 58.5, "{player}", "Spring's here! My first beast. My own journey. I can hardly wait!", "hero"],
	[58.5, 64.5, "MOM", "Rowan's got your egg. Uncle Rafe has Dad's flute, over in Bellerive.", "mom"],
	[64.5, 72.5, "{player}", "A whole season of adventure! Unless some gloomy weirdo's put 'ruin spring' on his to-do list. Ha! Get a hobby!", "hero"],
]
## Where everyone stands in the office: Gearhart on the rug's east side, his staff in a huddle facing him.
const GEAR_AT := Vector3(4.4, 0, 0.6)
const STAFF_AT := [Vector3(1.5, 0, -0.6), Vector3(1.1, 0, 0.9), Vector3(1.7, 0, 2.3)]
## the steel door in the office's east wall, and the freight room behind it: its far (east) wall, the cages either
## side of the aisle (DOOR_Z), the canisters' bank across the far end
const DOOR_X := 10.1
const DOOR_Z := 2.6
const ROOM_END := 24.3
const CELL_XS := [12.7, 15.6, 18.5]
const CELL_Z := 3.0
const TUBE_X := 22.4
const TUBE_ZS := [-0.9, 0.85, 2.6, 4.35, 6.1]
## Gearhart's walk: from the rug to the door, down the aisle, and over to the canisters; when he sets off, how fast
const GEAR_PATH := [Vector3(4.4, 0, 0.6), Vector3(9.4, 0, 2.6), Vector3(19.6, 0, 2.6), Vector3(20.8, 0, 3.4)]
const GEAR_WALK := 24.0
const GEAR_SPEED := 1.25
## the staff head for the lift as the briefing ends
const STAFF_GO := 20.2
## when the steel door slides open
const DOOR_OPEN := 26.6
## the office's lights at full: the pool over the rug, the desk lamp, the neon by the crates; the freight room's
const SPOT_E := 3.2
const DESK_E := 1.6
const CAGE_E := 1.8
const ROOM_E := 1.6
## the spring morning: the hero's home (its front door facing north, up the path), the hero on the path before it
const HOME_AT := Vector3(3.5, 0, 10.0)
const HERO_AT := Vector3(3.5, 0, 5.6)

signal finished(skipped: bool)
var elapsed := 0.0
var preview := false
var running := false
var skipped := false
var stage: Node3D
var camera: Camera3D
var overlay: Control
var dialogue: Control
var location: Label
var location_sub: Label
var chapter: Label
var chapter_sub: Label
var chapter_panel: PanelContainer
var shade: ColorRect
var skip_button: Button
var next_button: Button
var people := {}
var beasts: Array = []
## the captive beasts floating in the canisters, and the bubbles rising past them
var bottled: Array = []
var bubbles: Array = []
var env: Environment
var moon: DirectionalLight3D
var spot: SpotLight3D
var desk_lamp: OmniLight3D
var cage_lamps: Array = []
## the freight room's own lamps (off until the door opens), and the light spilling through the door
var room_lamps: Array = []
var door_light: OmniLight3D
var door_panel: MeshInstance3D
## where Mom stands, at the front door
var mom_at := Vector3.ZERO
var _mats := {}
var _scene := ""
var _beat := -1
var _last_time := 0.0
var _done := false


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 43
	camera.current = true
	add_child(camera)
	_build_overlay()


func start(at := 0.0, hold := false) -> void:
	preview = hold
	elapsed = clampf(at, 0.0, LENGTH - 0.01)
	running = true
	_update_scene()
	_update_frame()


func _exit_tree() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()


func skip() -> void:
	if not running or _done:
		return
	skipped = true
	_complete()


func _complete() -> void:
	if _done:
		return
	running = false
	_done = true
	finished.emit(skipped)


func handle_input(event: InputEvent) -> void:
	if not running or event.is_echo():
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		skip()
	elif event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_next()


func _next() -> void:
	if is_instance_valid(dialogue):
		dialogue._advance()
	else:
		advance()


func advance() -> void:
	if not running or _done:
		return
	if _beat >= 0 and _beat < BEATS.size() - 1:
		elapsed = float(BEATS[_beat + 1][0])
		_update_scene()
		_update_frame()
	else:
		_complete()


func _process(delta: float) -> void:
	if not running:
		return
	if not preview:
		elapsed += delta
	if elapsed >= LENGTH:
		_complete()
		return
	_update_scene()
	_update_frame()


func _build_overlay() -> void:
	# Parent to the real UI, not the SubViewport. CanvasLayer.custom_viewport changes drawing, but does not
	# change the viewport used by descendant Control anchors (the old phone layout lost its bottom/right edges).
	overlay = Control.new()
	overlay.name = "CinematicUI"
	UI.root.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root := overlay
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Kit.make_theme()
	var top := MarginContainer.new()
	root.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_right = -24
	top.offset_top = 20
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)
	var place := Kit.banner_panel()
	place.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(place)
	var place_text := VBoxContainer.new()
	place.add_child(place_text)
	location = Kit.header("")
	location_sub = Kit.label("", Kit.BODY_SMALL, Kit.DIM)
	place_text.add_child(location)
	place_text.add_child(location_sub)
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(space)
	var buttons_panel := Kit.dark_panel()
	row.add_child(buttons_panel)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	buttons_panel.add_child(buttons)
	skip_button = Button.new()
	skip_button.text = "Skip intro  ·  Esc / B"
	skip_button.custom_minimum_size.y = Kit.row_h()
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.pressed.connect(skip)
	buttons.add_child(skip_button)
	next_button = Button.new()
	next_button.text = "Next  ·  A / Enter"
	next_button.custom_minimum_size.y = Kit.row_h()
	next_button.focus_mode = Control.FOCUS_NONE
	next_button.pressed.connect(_next)
	buttons.add_child(next_button)
	var center := CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chapter_panel = Kit.banner_panel(Vector2(760, 0))
	center.add_child(chapter_panel)
	var chapter_text := VBoxContainer.new()
	chapter_text.add_theme_constant_override("separation", 16)
	chapter_panel.add_child(chapter_text)
	chapter = Kit.header("", Kit.INK, Kit.HEAD_BIG)
	chapter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chapter_text.add_child(chapter)
	chapter_sub = Kit.label("", Kit.BODY_BIG, Kit.DIM)
	chapter_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chapter_text.add_child(chapter_sub)
	shade = ColorRect.new()
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _show_dialogue(beat: Array) -> void:
	if is_instance_valid(dialogue):
		overlay.remove_child(dialogue)
		dialogue.queue_free()
	dialogue = null
	if String(beat[3]) == "":
		return
	dialogue = CinematicDialog.new()
	dialogue.instant_text = preview
	dialogue.setup([String(beat[3])], String(beat[2]).replace("{player}", GameState.player_name.to_upper()))
	dialogue.advance_requested.connect(advance)
	overlay.add_child(dialogue)
	overlay.move_child(shade, overlay.get_child_count() - 1)


func _update_scene() -> void:
	var which := "tower" if elapsed < DAWN else "spring"
	if which == _scene:
		return
	_scene = which
	_beat = -1
	people = {}
	beasts = []
	bottled = []
	bubbles = []
	cage_lamps = []
	room_lamps = []
	if stage != null:
		remove_child(stage)
		stage.queue_free()
	stage = Node3D.new()
	add_child(stage)
	if which == "tower":
		_build_tower()
		# (the music stops dead as he steps into the freight room, see _reveal_sounds)
		Sfx.music("crypt" if elapsed < INSIDE else "")
		Sfx.ambience("machines")
	else:
		_build_spring()
		Sfx.music("coast")
		Sfx.ambience("wind")


# ================================================================ building blocks
## A material: a flat colour, or one of the interior pack's textures (room_builder.gd) laid on in world space, tinted;
## glowing ones are unshaded and feed the glow. Shared by everything of the same look.
func _mat(colour: String, tex := "", glow := false) -> StandardMaterial3D:
	var key := "%s:%s:%s" % [colour, tex, glow]
	if _mats.has(key):
		return _mats[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(colour)
	mat.roughness = 0.85
	if tex != "":
		mat.albedo_texture = load(RoomBuilder.DIR + "tex/" + tex + ".png") if ResourceLoader.exists(RoomBuilder.DIR + "tex/" + tex + ".png") else null
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_scale = Vector3.ONE / RoomBuilder.SPAN
	if glow:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(colour) * 1.6
	_mats[key] = mat
	return mat


func _box(pos: Vector3, size: Vector3, colour: String, glow := false, tex := "") -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _mat(colour, tex, glow)
	node.position = pos
	if glow:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.add_child(node)
	return node


func _asset(key: String, pos: Vector3, height: float) -> MeshInstance3D:
	var node := Assets.instance(key, height)
	node.position += pos
	stage.add_child(node)
	return node


## One of the interior pack's pieces (room_builder.gd), standing on `pos`, scaled to `height`, turned `yaw`.
func _piece(name: String, pos: Vector3, height: float, yaw := 0.0) -> MeshInstance3D:
	var mesh := RoomBuilder.piece(name)
	var node := MeshInstance3D.new()
	if mesh == null:
		return node
	node.mesh = mesh
	var bb := mesh.get_aabb()
	var s := height / maxf(0.001, bb.size.y)
	node.scale = Vector3.ONE * s
	node.rotation.y = yaw
	node.position = pos - Vector3(0, bb.position.y * s, 0)
	stage.add_child(node)
	return node


func _person(key: String, look: Dictionary, pos: Vector3, face := Vector2i(0, 1)) -> Node3D:
	var node := Person.build(look)
	node.position = pos
	Person.face(node, face)
	stage.add_child(node)
	people[key] = node
	return node


func _lamp(pos: Vector3, colour: String, energy: float, reach: float, shadow := false) -> OmniLight3D:
	var lamp := OmniLight3D.new()
	lamp.position = pos
	lamp.light_color = Color(colour)
	lamp.light_energy = energy
	lamp.omni_range = reach
	lamp.shadow_enabled = shadow
	stage.add_child(lamp)
	return lamp


func _environment(spring: bool) -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#d8c8a8" if spring else "#070914")
	if spring:
		var sky := Sky.new()
		var material := ProceduralSkyMaterial.new()
		material.sky_top_color = Color("#5d9bd0")
		material.sky_horizon_color = Color("#e6dcc6")
		material.ground_horizon_color = Color("#e6dcc6")
		material.ground_bottom_color = Color("#6a7a4a")
		material.sun_angle_max = 20.0
		sky.sky_material = material
		env.sky = sky
		env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c8d0c0" if spring else "#4a5288")
	env.ambient_light_energy = 0.6 if spring else 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.2
	env.glow_enabled = true
	env.glow_intensity = 0.55 if spring else 0.9
	env.glow_hdr_threshold = 1.1
	env.ssao_enabled = RenderingServer.get_current_rendering_method() != "mobile"
	env.ssao_radius = 0.65
	env.ssao_intensity = 1.5
	env.fog_enabled = true
	env.fog_density = 0.004 if spring else 0.018
	env.fog_light_color = Color("#e6dcc6" if spring else "#1c1838")
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1 if spring else 1.05
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	stage.add_child(world_env)


# ================================================================ the office, by night
func _build_tower() -> void:
	_environment(false)
	# the moon, low behind the window wall: its light falls through the windows across the floor
	moon = DirectionalLight3D.new()
	moon.light_color = Color("#8ea6ff")
	moon.light_energy = 0.55
	moon.rotation_degrees = Vector3(-24, 168, 0)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 30.0
	stage.add_child(moon)
	# the floor (Gearhart's office is wood with a red rug, as when the hero comes back for the captives), the ceiling,
	# and brick walls all round
	_box(Vector3(0, -0.25, 0.5), Vector3(20.4, 0.5, 15.4), "#7a6458", false, "floor_wood_2")
	_box(Vector3(0, 0.012, 0.6), Vector3(6.4, 0.025, 7.2), "#6a1626", false, "floor_carpet")
	_box(Vector3(0, 0.016, 0.6), Vector3(5.8, 0.025, 6.6), "#8a2234", false, "floor_carpet")
	_box(Vector3(0, 6.1, 0.5), Vector3(20.4, 0.2, 15.4), "#2a2430")
	var brick := "#6e5a62"
	_box(Vector3(-10.1, 3.0, 0.5), Vector3(0.3, 6.0, 15.4), brick, false, "wall_brick")
	# the east wall, with the steel door into the freight room
	_box(Vector3(DOOR_X, 3.0, -2.9), Vector3(0.3, 6.0, 8.6), brick, false, "wall_brick")
	_box(Vector3(DOOR_X, 3.0, 6.125), Vector3(0.3, 6.0, 4.65), brick, false, "wall_brick")
	_box(Vector3(DOOR_X, 4.7, DOOR_Z), Vector3(0.3, 2.6, 2.4), brick, false, "wall_brick")
	_box(Vector3(0, 3.0, 8.3), Vector3(20.4, 6.0, 0.3), brick, false, "wall_brick")
	# the window wall: a brick pier in the middle carrying the company's sign, two tall windows either side with
	# mullions, a sill below and a lintel above; the city's neon beyond
	_box(Vector3(0, 3.0, -7.15), Vector3(6.2, 6.0, 0.3), brick, false, "wall_brick")
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 9.6, 3.0, -7.15), Vector3(1.0, 6.0, 0.3), brick, false, "wall_brick")
		_box(Vector3(side * 6.1, 0.35, -7.15), Vector3(6.0, 0.7, 0.3), brick, false, "wall_brick")
		_box(Vector3(side * 6.1, 5.35, -7.15), Vector3(6.0, 1.3, 0.3), brick, false, "wall_brick")
		_box(Vector3(side * 6.1, 0.72, -7.0), Vector3(6.1, 0.08, 0.5), "#3a3240", false, "furniture_wood")
		for k in 4:
			_box(Vector3(side * (3.3 + k * 1.9), 2.7, -7.12), Vector3(0.12, 4.0, 0.14), "#22202a")
		_box(Vector3(side * 6.1, 2.7, -7.12), Vector3(6.0, 0.1, 0.14), "#22202a")
	var sign_board := CompanyBrand.sign_node(5.2)
	sign_board.position = Vector3(0, 4.3, -6.92)
	stage.add_child(sign_board)
	_skyline()
	# Gearhart's desk before the sign: a heavy wooden desk, a monitor, a lamp, a telephone; robots either side
	_box(Vector3(0, 0.5, -4.7), Vector3(3.6, 1.0, 1.2), "#4a2e22", false, "furniture_wood")
	_box(Vector3(0, 1.04, -4.7), Vector3(3.8, 0.08, 1.35), "#6a4430", false, "furniture_wood")
	_piece("el_monitor", Vector3(-0.9, 1.08, -4.85), 0.5)
	_piece("el_lamp", Vector3(1.25, 1.08, -4.9), 0.55)
	_piece("globe", Vector3(0.5, 1.08, -4.95), 0.4)
	desk_lamp = _lamp(Vector3(1.25, 1.7, -4.6), "#ffb870", DESK_E, 4.5)
	_piece("chair_slat", Vector3(0, 0, -5.8), 1.1)
	for side in [-1.0, 1.0]:
		var robot := _asset("robot_golem", Vector3(side * 4.4, 0, -4.2), 2.6)
		robot.rotation.y = -PI / 2
		_piece("bookshelf", Vector3(side * 9.5, 0, -2.5), 2.4, -side * PI / 2)
		_piece("plant_tall", Vector3(side * 2.6, 0, -6.4), 1.5)
	# crates of "freight" stacked along the sides under neon; the lift in the front wall (clear of the staff's way to
	# it and of Gearhart's to the steel door)
	for at in [Vector3(-7.3, 0, 2.6), Vector3(8.4, 0, 6.6)]:
		var crates := _asset("crates", at, 1.3)
		crates.rotation.y = 0.4 if at.x < 0 else -0.3
		_asset("barrel", at + Vector3(0.4 if at.x < 0 else -1.2, 0, 2.4 if at.x < 0 else 0.6), 0.9)
		cage_lamps.append(_lamp(at + Vector3(0, 2.4, 0), "#d75a9c", CAGE_E, 4.5))
	_lift(Vector3(5.0, 0, 8.1))
	_steel_door()
	_freight_room()
	# the pool of light over the rug, where the staff gather
	spot = SpotLight3D.new()
	spot.position = Vector3(2.4, 5.9, 0.8)
	spot.rotation_degrees = Vector3(-90, 0, 0)
	spot.light_color = Color("#ffe2c4")
	spot.light_energy = SPOT_E
	spot.spot_range = 9.0
	spot.spot_angle = 32.0
	spot.spot_attenuation = 0.6
	spot.shadow_enabled = true
	stage.add_child(spot)
	# Gearhart addressing his staff, the staff in a huddle before him
	_person("gear", GEAR_LOOK, GEAR_AT, Vector2i(-1, 0))
	_person("mara", ENGINEER_LOOK, STAFF_AT[0], Vector2i(1, 0))
	for i in STAFF_LOOKS.size():
		_person("staff%d" % i, STAFF_LOOKS[i], STAFF_AT[i + 1], Vector2i(1, 0))


## The city through the windows: dark blocks with rows of lit windows (one shared glowing material per colour), and
## the moon.
func _skyline() -> void:
	for i in 22:
		var x := float(i) * 2.6 - 27.0
		var h := 5.0 + fmod(float(i * 17), 9.0)
		var z := -15.0 - fmod(float(i * 7), 10.0)
		_box(Vector3(x, h * 0.5 - 3.0, z), Vector3(2.2, h, 2.6), "#121528")
		for j in int(h * 0.8):
			if (i * 5 + j * 3) % 4 == 0:
				continue
			_box(Vector3(x, j * 1.2 - 2.4, z + 1.32), Vector3(1.5, 0.12, 0.02), "#48a4ba" if (i + j) % 3 else "#ca548f", true)
	var disc := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 2.2
	sphere.height = 4.4
	disc.mesh = sphere
	disc.material_override = _mat("#c8d4ff", "", true)
	disc.position = Vector3(-9.0, 13.0, -40.0)
	stage.add_child(disc)


## The steel door into the freight room, shut in the east wall's doorway (it slides north into the wall to open),
## hazard stripes over it, a red lamp, and the light from the room beyond to spill through once it's open.
func _steel_door() -> void:
	door_panel = _box(Vector3(DOOR_X, 1.7, DOOR_Z), Vector3(0.12, 3.4, 2.4), "#5a6070")
	for k in 5:
		var stripe := _box(Vector3(DOOR_X - 0.17, 3.55, DOOR_Z - 1.0 + k * 0.5), Vector3(0.06, 0.24, 0.22), "#e0b020" if k % 2 == 0 else "#202020")
		stripe.rotation.x = 0.5
	_box(Vector3(DOOR_X - 0.2, 3.95, DOOR_Z), Vector3(0.12, 0.18, 0.5), "#ff5a3a", true)
	door_light = _lamp(Vector3(DOOR_X + 1.2, 2.2, DOOR_Z), "#e0609c", 0.0, 5.5)


## The freight room behind the office: bare concrete and steel, three neon cages either side of the aisle, a trainer
## in each, and across the far end a bank of glass canisters, a captured beast floating in each.
func _freight_room() -> void:
	var mid := (DOOR_X + ROOM_END) / 2.0
	var span := ROOM_END - DOOR_X
	var steel := "#3c414e"
	_box(Vector3(mid, -0.25, DOOR_Z), Vector3(span, 0.5, 10.2), "#6a6e78", false, "floor_stone")
	_box(Vector3(mid, 6.1, DOOR_Z), Vector3(span, 0.2, 10.2), "#1e2028")
	_box(Vector3(mid, 3.0, DOOR_Z - 4.95), Vector3(span, 6.0, 0.3), steel, false, "wall_plaster")
	_box(Vector3(mid, 3.0, DOOR_Z + 4.95), Vector3(span, 6.0, 0.3), steel, false, "wall_plaster")
	_box(Vector3(ROOM_END, 3.0, DOOR_Z), Vector3(0.3, 6.0, 10.2), steel, false, "wall_plaster")
	# a hazard line down either edge of the aisle
	for side in [-1.0, 1.0]:
		_box(Vector3((DOOR_X + TUBE_X) / 2.0, 0.006, DOOR_Z + side * 1.55), Vector3(TUBE_X - DOOR_X - 1.6, 0.012, 0.12), "#c8a030")
	# the cages, and who's in them: [cell, look, pose, how far they reach for the bars]
	var cells := []
	for side in [-1.0, 1.0]:
		for x in CELL_XS:
			cells.append(Vector3(x, 0, DOOR_Z + side * CELL_Z))
	for at in cells:
		_cell(at, -signf(at.z - DOOR_Z))
	var who := [
		[2, TrainerCell.LOOKS[1], "", 0.75], [0, TrainerCell.LOOKS[0], "kneel", 0.0], [4, TrainerCell.LOOKS[2], "", 0.5],
		[1, CAPTIVE_LOOKS[0], "kneel", 0.0], [3, CAPTIVE_LOOKS[1], "", 0.0], [5, CAPTIVE_LOOKS[2], "kneel", 0.0],
	]
	for i in who.size():
		var cell: Vector3 = cells[who[i][0]]
		var front := -signf(cell.z - DOOR_Z)
		var standing: bool = String(who[i][2]) == ""
		var at := cell + Vector3(0.3 * (1 if i % 2 else -1), 0, front * (0.75 if standing else 0.2))
		var captive := _person("captive%d" % i, who[i][1], at, Vector2i(0, int(front)))
		Person.set_pose(captive, who[i][2], 0.36, true)
		Person.set_reach(captive, who[i][3])
	# the canisters: Embit, Clawlet, Tadlet, Grubbit, Berrypuff, the captives' own partners
	var races := [0, 24, 27, 12, 36]
	for i in TUBE_ZS.size():
		_canister(Vector3(TUBE_X, 0, TUBE_ZS[i]), races[i])
	# the room's own light: pink over the cages, teal from the canisters, all off until the door opens
	for x in CELL_XS:
		room_lamps.append(_lamp(Vector3(x, 2.8, DOOR_Z), "#d75a9c", ROOM_E, 4.2))
	for z in [0.0, DOOR_Z, 5.2]:
		room_lamps.append(_lamp(Vector3(TUBE_X - 1.2, 2.0, z), "#5ad8d0", ROOM_E * 0.6, 3.4))


## One of the freight room's cages (like trainer_cell.gd's, full size): a steel floor and roof, neon posts at the
## corners, bars across the front (towards the aisle, `front` along z) and down the sides, a freight tag over it.
func _cell(at: Vector3, front: float) -> void:
	_box(at + Vector3(0, 0.12, 0), Vector3(2.6, 0.25, 2.6), "#454c60")
	_box(at + Vector3(0, 2.85, 0), Vector3(2.6, 0.18, 2.6), "#454c60")
	for dx in [-1.2, 1.2]:
		for dz in [-1.2, 1.2]:
			_box(at + Vector3(dx, 1.5, dz), Vector3(0.08, 2.7, 0.08), "#cf506e")
		for dz in [-0.4, 0.4]:
			_box(at + Vector3(dx, 1.5, dz), Vector3(0.035, 2.6, 0.035), "#6a7080")
	# (few, thin bars, so whoever's inside shows from the aisle; a neon strip along the top)
	for dx in [-0.6, 0.0, 0.6]:
		_box(at + Vector3(dx, 1.5, front * 1.2), Vector3(0.035, 2.6, 0.035), "#8a96a8")
	_box(at + Vector3(0, 0.6, front * 1.2), Vector3(2.4, 0.06, 0.06), "#6a7080")
	_box(at + Vector3(0, 2.72, front * 1.22), Vector3(2.4, 0.05, 0.05), "#60bdca", true)
	# a freight tag on the roof's edge (a lit plate: the film has no floating text)
	_box(at + Vector3(0, 3.1, front * 1.22), Vector3(0.9, 0.26, 0.04), "#3a2030")
	_box(at + Vector3(0, 3.1, front * 1.25), Vector3(0.7, 0.08, 0.02), "#f4b1c0", true)


## A glass canister on a steel base, a pipe from its cap up into the ceiling, full of glowing teal fluid, a beast
## floating inside (scaled to fit, turned towards the aisle) and bubbles rising past it.
func _canister(at: Vector3, race: int) -> void:
	var base := _cylinder(at + Vector3(0, 0.22, 0), 0.7, 0.45, _mat("#454c60"))
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_cylinder(at + Vector3(0, 2.62, 0), 0.68, 0.3, _mat("#454c60"))
	_cylinder(at + Vector3(0, 4.4, 0), 0.12, 3.3, _mat("#2c303a"))
	_cylinder(at + Vector3(0, 0.47, 0), 0.62, 0.05, _mat("#60bdca", "", true))
	var fluid := StandardMaterial3D.new()
	fluid.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fluid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fluid.albedo_color = Color(0.2, 0.6, 0.6, 0.16)
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.75, 0.95, 1.0, 0.16)
	glass.roughness = 0.05
	glass.metallic_specular = 1.0
	_cylinder(at + Vector3(0, 1.48, 0), 0.54, 1.98, fluid)
	_cylinder(at + Vector3(0, 1.48, 0), 0.6, 2.0, glass)
	var beast = BeastModel.rig(RaceDB.genes(race), 1.0)
	if beast != null:
		var bb: AABB = BeastModel.bounds(beast)
		var fit := 0.85 / maxf(0.01, maxf(bb.size.y, maxf(bb.size.x, bb.size.z)))
		beast.scale *= fit
		beast.rotation.y = PI
		beast.position = at + Vector3(0, 1.05 - bb.position.y * beast.scale.y, 0)
		beast.set_meta("rest_y", beast.position.y)
		stage.add_child(beast)
		bottled.append(beast)
	var bead := _mat("#c8fff8", "", true)
	for k in 3:
		var bubble := _cylinder(at + Vector3(0.3 * sin(k * 2.1), 0.6, 0.3 * cos(k * 2.1)), 0.035, 0.07, bead)
		bubble.set_meta("from", bubble.position)
		bubbles.append(bubble)


func _cylinder(pos: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.add_child(node)
	return node


## The freight lift's doors in the front wall: steel, hazard stripes round them, a lamp over them.
func _lift(at: Vector3) -> void:
	_box(at + Vector3(0, 1.6, 0), Vector3(3.0, 3.2, 0.12), "#5a6070")
	_box(at + Vector3(0, 1.6, -0.02), Vector3(0.05, 3.1, 0.12), "#2a2e38")
	for k in 7:
		var stripe := _box(at + Vector3(-1.4 + k * 0.47, 3.35, -0.04), Vector3(0.22, 0.24, 0.06), "#e0b020" if k % 2 == 0 else "#202020")
		stripe.rotation.z = 0.5
	_box(at + Vector3(0, 3.7, -0.08), Vector3(0.5, 0.18, 0.12), "#ff5a3a", true)


# ================================================================ spring
func _beast(race: int, pos: Vector3, size := 1.0) -> void:
	var beast = BeastModel.rig(RaceDB.genes(race), size)
	stage.add_child(beast)
	beast.position = pos
	beasts.append(beast)


func _build_spring() -> void:
	_environment(true)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#ffe6c4")
	sun.light_energy = 1.2
	sun.rotation_degrees = Vector3(-32, -140, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	stage.add_child(sun)
	var grass := _box(Vector3(0, -0.35, 0), Vector3(160, 0.6, 160), "#87975c")
	var ground_mat := grass.material_override as StandardMaterial3D
	ground_mat.albedo_texture = Textures.terrain("top_grass", "#8b9c69")
	ground_mat.albedo_color = Color.WHITE
	ground_mat.uv1_triplanar = true
	ground_mat.uv1_scale = Vector3.ONE * 0.8
	# the path from the front door north to the shore, and the sea beyond the beach
	var path := _box(Vector3(HOME_AT.x, -0.032, -4.0), Vector3(2.4, 0.035, 26), "#c6ae7e")
	var path_mat := path.material_override as StandardMaterial3D
	path_mat.albedo_texture = Textures.terrain("top_path", "#b5a181")
	path_mat.albedo_color = Color.WHITE
	path_mat.uv1_triplanar = true
	var beach := _box(Vector3(0, -0.04, -18.0), Vector3(160, 0.05, 6), "#e0cc98")
	var beach_mat := beach.material_override as StandardMaterial3D
	beach_mat.albedo_texture = Textures.terrain("top_sand", "#e0cc98")
	beach_mat.albedo_color = Color.WHITE
	beach_mat.uv1_triplanar = true
	_box(Vector3(0, -0.12, -46.0), Vector3(160, 0.08, 50), "#4f8fae")
	# the hero's home: a coastal cottage, its door at the end of the path, flowers by it
	var plan := Houses.plan({"w": 6, "d": 4, "door": Vector2i(3, 3), "x": 0, "y": 0, "seed": 26}, "coastal", {})
	if not plan.is_empty():
		var home := Houses.build(plan)
		home.rotation.y = PI
		home.position = HOME_AT + Vector3(0.5, 0, 0)
		stage.add_child(home)
		# (on the path just off the doorstep, clear of any porch)
		var door: Vector3 = plan["door_at"]
		mom_at = home.position + Vector3(-door.x, 0, -2.45)
	else:
		mom_at = HOME_AT + Vector3(0, 0, -2.6)
	# woods round the clearing (none between the camera and the people)
	for i in 26:
		var a := float(i) / 26.0 * TAU
		var r := 13.0 + fmod(float(i * 7), 5.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r * 0.8 + 3.0)
		if p.z < -4.0:
			continue
		_asset("tree_round_1" if i % 3 else "tree_birch", p, 5.0 + fmod(i * 1.7, 3.0))
	for x in [-8.0, 13.0]:
		_asset("tree_round_1", Vector3(x, 0, 14.5), 6.0)
	for i in 90:
		var x := sin(float(i) * 7.9) * 11.0
		var z := cos(float(i) * 2.7) * 9.0 + 0.5
		if absf(x - HOME_AT.x) < 1.6 or (absf(x - HOME_AT.x) < 5.0 and z > 6.5) or z < -5.0:
			continue
		var flowers := MeshInstance3D.new()
		flowers.mesh = Props.flowers(i % 5)
		flowers.position = Vector3(x, 0, z)
		flowers.scale = Vector3.ONE * 1.4
		stage.add_child(flowers)
	# bunting strung across the path on two poles, for the first day of the season
	_bunting(Vector3(HOME_AT.x - 2.2, 0, 3.0), Vector3(HOME_AT.x + 2.2, 0, 3.0))
	# a burrow by a rock, a stump with breakfast berries, and a pair of springtime flyers
	_asset("field_rock", Vector3(-2.2, 0, -0.4), 1.15)
	_box(Vector3(-2.2, 0.19, 0.23), Vector3(0.68, 0.4, 0.1), "#30372a")
	_asset("stump", Vector3(7.4, 0, 2.0), 0.55)
	for i in 7:
		_box(Vector3(7.4 + sin(i * 2.4) * 0.38, 0.62, 2.0 + cos(i * 2.4) * 0.3), Vector3.ONE * 0.13, "#bd5371")
	_beast(12, Vector3(-2.0, 0, 0.8), 1.4)
	_beast(0, Vector3(6.6, 0, 2.6), 1.3)
	_beast(30, Vector3(-1.0, 2.8, -3.3), 1.2)
	_beast(30, Vector3(1.0, 3.1, -4.3), 1.1)
	beasts[1].rotation.y = 0.7
	# the hero, dressed as the character creator made them, just out of the door; Mom on the doorstep (she has
	# their skin, hair and eyes)
	_person("hero", GameState.hero_look(), HERO_AT, Vector2i(0, -1))
	var mom_look := {"model": "tf62", "skin": "#f0c8a0", "hair": "#8a3a20", "shirt": "#e07a5a", "pants": "#4a3a6a"}
	var family: Dictionary = Person.Townfolk.outfit(GameState.hero_look())["colours"]
	for key in ["skin", "hair", "eyes"]:
		if family.has(key):
			mom_look[key] = "#" + (family[key] as Color).to_html(false)
	_person("mom", mom_look, mom_at, Vector2i(0, -1))


## Pennants on a sagging line between two poles.
func _bunting(a: Vector3, b: Vector3) -> void:
	var top := 2.9
	for p in [a, b]:
		_box(p + Vector3(0, top / 2.0, 0), Vector3(0.12, top, 0.12), "#8a6a48", false, "furniture_wood")
	var count := 9
	for i in count:
		var k := (float(i) + 0.5) / float(count)
		var at := a.lerp(b, k) + Vector3(0, top - 0.12 - sin(k * PI) * 0.45, 0)
		var flag := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.3, 0.38, 0.02)
		flag.mesh = prism
		flag.material_override = _mat(["#e1a871", "#7babc0", "#d8687a", "#f0e0b0"][i % 4])
		flag.rotation.z = PI
		flag.position = at - Vector3(0, 0.19, 0)
		stage.add_child(flag)
	var line := MeshInstance3D.new()
	var cord := CylinderMesh.new()
	cord.top_radius = 0.012
	cord.bottom_radius = 0.012
	cord.height = a.distance_to(b)
	line.mesh = cord
	line.material_override = _mat("#e8e0d0")
	line.rotation.z = PI / 2.0
	line.position = (a + b) / 2.0 + Vector3(0, top - 0.32, 0)
	stage.add_child(line)


# ================================================================ cameras
func _camera_shot(shot: String, progress: float) -> void:
	var pos := Vector3.ZERO
	var target := Vector3.ZERO
	match shot:
		"wide":
			pos = Vector3(-7.6, 4.6, 7.2).lerp(Vector3(-6.4, 4.0, 6.1), progress)
			target = Vector3(1.6, 0.9, -1.0)
		"gear":
			# over the staff's shoulders, on Gearhart
			pos = Vector3(0.0, 1.95, 1.75).lerp(Vector3(0.4, 1.9, 1.6), progress)
			target = GEAR_AT + Vector3(0, 0.5, 0)
		"staff":
			# over Gearhart's shoulder, on Mara and the others
			pos = Vector3(5.6, 1.7, 1.9).lerp(Vector3(5.2, 1.65, 1.6), progress)
			target = Vector3(1.4, 0.9, 0.9)
		"plan":
			pos = Vector3(-2.8, 3.0, 6.6).lerp(Vector3(-2.2, 2.8, 6.0), progress)
			target = Vector3(3.0, 0.9, 0.8)
		"door":
			# from behind, as he walks to the steel door and it slides open
			pos = Vector3(3.4, 2.7, 7.0).lerp(Vector3(4.6, 2.6, 6.8), progress)
			target = Vector3(8.4, 0.5, 2.2)
		"reveal":
			# from among the cages, back down the aisle to the door as he steps through
			pos = Vector3(20.6, 1.6, 1.5).lerp(Vector3(20.0, 1.55, 1.6), progress)
			target = people["gear"].position + Vector3(0, 1.0, 0) if people.has("gear") else Vector3(DOOR_X, 1.0, DOOR_Z)
		"tubes":
			# along the bank of canisters
			pos = Vector3(18.6, 1.7, -0.2).lerp(Vector3(19.0, 1.6, 0.5), progress)
			target = Vector3(TUBE_X, 1.3, 2.8)
		"cages":
			# across the aisle, into the cages, the canisters glowing beyond
			pos = Vector3(12.6, 2.4, 4.0).lerp(Vector3(12.2, 2.5, 4.2), progress)
			target = Vector3(18.0, 0.8, 0.2)
		"spring":
			pos = Vector3(-2.6, 5.4, -8.6).lerp(Vector3(-1.6, 4.6, -7.0), progress)
			target = Vector3(3.0, 0.4, 5.0)
		"beasts":
			pos = Vector3(2.4, 2.0, 5.4).lerp(Vector3(1.9, 1.8, 4.8), progress)
			target = Vector3(-1.7, 0.4, 0.8)
		"hero":
			pos = Vector3(2.2, 1.75, 2.0).lerp(Vector3(2.5, 1.7, 2.5), progress)
			target = HERO_AT + Vector3(0, 1.0, 0.8)
		"mom":
			pos = Vector3(4.9, 1.55, 4.0).lerp(Vector3(4.6, 1.5, 4.4), progress)
			target = mom_at + Vector3(0, 1.1, 0)
	camera.position = pos
	camera.look_at(target)


# ================================================================ the timeline
func _update_frame() -> void:
	var idx := 0
	for i in BEATS.size():
		if elapsed >= float(BEATS[i][0]):
			idx = i
	var beat: Array = BEATS[idx]
	if idx != _beat:
		_beat = idx
		_show_dialogue(beat)
		location.text = "COGSWORTH" if elapsed < DAWN else "COCOON COVE"
		location_sub.text = "Before dawn" if elapsed < DAWN else "Spring, day one"
		for key in people:
			Person.set_talking(people[key], (key == "gear" and beat[2] == "MAGNUS GEARHART") or (key == "captive0" and beat[2] == "TRAINER BEA") or (key == "mara" and beat[2] == "ENGINEER MARA") or (key == "hero" and beat[2] == "{player}") or (key == "mom" and beat[2] == "MOM"), true)
	var p := clampf((elapsed - float(beat[0])) / (float(beat[1]) - float(beat[0])), 0, 1)
	_camera_shot(String(beat[4]), p)
	chapter_panel.visible = idx == 0 or String(beat[4]) == "spring"
	chapter.text = "THE LAST NIGHT OF WINTER" if idx == 0 else "THE FIRST DAY OF SPRING"
	chapter_sub.text = "Gearhart Tower · Cogsworth" if idx == 0 else "The beasts are waking. Trainer season begins."
	# Slow fades to and from black around the cut to spring, with no flashing screen on the reveal.
	var fade := maxf(0, 1.0 - elapsed / 0.8)
	if elapsed < DAWN:
		fade = maxf(fade, clampf(1.0 - (DAWN - elapsed) / 1.1, 0, 1))
	else:
		fade = maxf(fade, clampf(1.0 - (elapsed - DAWN) / 0.7, 0, 1))
	fade = maxf(fade, clampf((elapsed - LENGTH + 0.65) / 0.65, 0, 1))
	shade.color = Color(0.025, 0.03, 0.06, fade)
	if _scene == "tower":
		_tower_frame()
	else:
		_spring_frame(beat)
	_last_time = elapsed


func _tower_frame() -> void:
	# the office's lights, until he's through the door; the freight room's, once it opens (each kept dark while
	# the camera's in the other room, so neither shines through the wall between)
	var open := smoothstep(DOOR_OPEN, DOOR_OPEN + 1.0, elapsed)
	var office := 1.0 if elapsed < INSIDE else 0.0
	var room := open if elapsed < INSIDE else 1.0
	spot.light_energy = SPOT_E * office * (1.0 - 0.3 * smoothstep(DOOR, DOOR + 2.0, elapsed))
	desk_lamp.light_energy = DESK_E * office
	for lamp in cage_lamps:
		(lamp as OmniLight3D).light_energy = CAGE_E * office
	for lamp in room_lamps:
		(lamp as OmniLight3D).light_energy = ROOM_E * room * (1.0 if elapsed >= INSIDE else 0.25)
	door_light.light_energy = 2.2 * open * office
	door_panel.position.z = DOOR_Z - 2.4 * open
	env.ambient_light_color = Color("#4a5288") if elapsed < INSIDE else Color("#3a3058")
	env.ambient_light_energy = 0.42 if elapsed < INSIDE else 0.34
	_gear_frame()
	_staff_frame()
	# the bottled beasts bob, limp, in the fluid
	for i in bottled.size():
		var beast: Node3D = bottled[i]
		beast.position.y = float(beast.get_meta("rest_y")) + sin(elapsed * 0.9 + i * 1.3) * 0.06
	for i in bubbles.size():
		var bubble: MeshInstance3D = bubbles[i]
		var from: Vector3 = bubble.get_meta("from")
		bubble.position = from + Vector3(0, fmod(elapsed * 0.45 + i * 0.37, 1.9), 0)
	for key in people:
		if String(key).begins_with("captive"):
			Person.animate(people[key], 0, 0, elapsed + float(String(key).right(1)))
	_reveal_sounds()


## Gearhart: addressing the staff from the rug, then the walk (GEAR_PATH) to the steel door, through it, down the
## aisle between the cages, and over to his canisters, where he stands admiring them.
func _gear_frame() -> void:
	var gear: Node3D = people["gear"]
	var dist := maxf(0.0, elapsed - GEAR_WALK) * GEAR_SPEED
	var pos: Vector3 = GEAR_PATH[0]
	var way := Vector3(-1, 0, 0)
	var left := dist
	var walking := false
	for i in GEAR_PATH.size() - 1 if dist > 0.0 else 0:
		var a: Vector3 = GEAR_PATH[i]
		var b: Vector3 = GEAR_PATH[i + 1]
		var leg := a.distance_to(b)
		if left <= leg:
			pos = a.lerp(b, left / leg)
			way = b - a
			walking = dist > 0.0
			break
		left -= leg
		pos = b
		way = b - a
	gear.position = pos
	var body: Node3D = gear.get_node("Body")
	var yaw := atan2(way.x, way.z)
	if not walking and dist > 0.0:
		# arrived: facing the canisters
		yaw = PI / 2.0
	body.set_meta("yaw_to", yaw)
	if preview or dist <= 0.0:
		body.rotation.y = yaw
	Person.animate(gear, Person.phase_for(dist, GEAR_SPEED), GEAR_SPEED if walking else 0.0, elapsed)


## The staff: listening, then off to the lift as he sends them home; gone once he's alone.
func _staff_frame() -> void:
	var lift := Vector3(5.0, 0, 7.4)
	for i in STAFF_AT.size():
		var key := "mara" if i == 0 else "staff%d" % (i - 1)
		var person: Node3D = people[key]
		person.visible = elapsed < DOOR
		var go := maxf(0.0, elapsed - STAFF_GO - i * 0.3) * 1.3
		var from: Vector3 = STAFF_AT[i]
		var way := lift - from
		person.position = from + way.normalized() * minf(go, way.length())
		if go > 0.0:
			var body: Node3D = person.get_node("Body")
			body.set_meta("yaw_to", atan2(way.x, way.z))
			if preview:
				body.rotation.y = atan2(way.x, way.z)
		Person.animate(person, Person.phase_for(go, 1.3), 1.3 if go > 0.0 else 0.0, elapsed)


func _reveal_sounds() -> void:
	if preview:
		return
	if elapsed >= DOOR_OPEN and _last_time < DOOR_OPEN:
		Sfx.play("door")
	if elapsed >= INSIDE and _last_time < INSIDE:
		# silence: the music stops dead on the cages
		Sfx.music("")
		Sfx.play("dread")


func _spring_frame(beat: Array) -> void:
	for key in people:
		Person.animate(people[key], 0, 0, elapsed)
	# the hero turns to Mom while she talks, then back
	Person.face(people["hero"], Vector2i(0, 1) if String(beat[4]) == "mom" else Vector2i(0, -1), not preview)
	var awake := clampf((elapsed - DAWN - 0.7) / 3.2, 0, 1)
	beasts[0].position = Vector3(-2.2, -0.2, 0.2).lerp(Vector3(-1.2, 0, 1.7), awake)
	beasts[0].state = "walk" if awake < 1 else "idle"
	for i in [2, 3]:
		beasts[i].position = Vector3(sin(elapsed * 0.3 + i) * 2.4 - 3.0, 2.9 + sin(elapsed * 0.8 + i) * 0.3, -1.0 + cos(elapsed * 0.3 + i) * 1.3)
