extends Node3D
## A self-contained, real-time prologue. No map visits, inventory or quest knowledge is granted here.
## The same timeline drives playback and deterministic screenshot previews.
##
## Two sets, built from the game's own pieces: Gearhart's office at the top of his tower by night (the room the hero
## frees the captives from later: wood floor, brick, the company sign over the desk, freight cages and the lift),
## lit by the moon through the window wall, a desk lamp and a pool of light over the rug; then the first morning of
## spring outside the hero's home in Cocoon Cove.
## The murder is played straight, never slapstick: the lights die, Vexmora calls up a ghost beast that passes through
## Mara, Mara sinks to one knee and falls out of sight while the camera holds on Vexmora, and the last shot is
## Vexmora walking away from her without a glance while Gearhart backs off. No flash, no smack: silence, then a dread
## hit (sfx "ghost", "dread").

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
const VEX_LOOK := {"skin": "#c8b0b8", "hair": "#e0e0f0", "shirt": "#1a1024", "pants": "#120c18", "hat": "#6a2a9a", "outfit": "armor", "eyes": "#a838e0"}
const GEAR_LOOK := {"skin": "#e8c0a0", "hair": "#d8d8e0", "shirt": "#1a1a22", "pants": "#1a1a22", "hat": "#2a2a2a", "outfit": "coat"}
const ENGINEER_LOOK := {"skin": "#bc8868", "hair": "#49332d", "shirt": "#d6ae58", "pants": "#455469", "outfit": "apron", "glasses": false}
const LENGTH := 72.5
const MURDER := 33.5
const DAWN := 40.5
## start, end, speaker, subtitle, camera shot. Subtitles advance automatically; A also advances a beat.
const BEATS := [
	[0.0, 3.5, "", "", "wide"],
	[3.5, 10.0, "MAGNUS GEARHART", "First day of spring. Beasts wake. New trainers fill the roads.", "gear"],
	[10.0, 16.5, "MAGNUS GEARHART", "My robots collect them. My freight lifts hide the cages.", "plan"],
	[16.5, 23.5, "GENERAL VEXMORA", "Send them to Gravenmoor. Their bonds will teach my ghost beasts to obey. Leave their flutes behind.", "vex"],
	[23.5, 30.0, "ENGINEER MARA", "I built transports. Not cages. I won't help you take those trainers.", "mara"],
	[30.0, 33.5, "GENERAL VEXMORA", "Then you won't see spring.", "threat"],
	[33.5, 40.5, "", "", "murder"],
	[40.5, 46.0, "", "", "spring"],
	[46.0, 52.5, "", "Out of their burrows. Off to find food, a mate... or trouble.", "beasts"],
	[52.5, 58.5, "{player}", "Spring's here! My first beast. My own journey. I can hardly wait!", "hero"],
	[58.5, 64.5, "MOM", "Rowan's got your egg. Uncle Rafe has Dad's flute, over in Tidewater.", "mom"],
	[64.5, 72.5, "{player}", "A whole season of adventure! Unless some gloomy weirdo's put 'ruin spring' on his to-do list. Ha! Get a hobby!", "hero"],
]
## Where everyone stands in the office: Vexmora and Mara face each other across the rug, Gearhart by his desk.
const VEX_AT := Vector3(-1.4, 0, -0.2)
const MARA_AT := Vector3(0.9, 0, 1.6)
const GEAR_AT := Vector3(2.4, 0, -3.0)
## the murder, in seconds after MURDER: the ghost rises, lunges (passing through Mara at HIT), Mara kneels, slumps,
## and the camera cuts away to Vexmora as she falls (FALL); then the last, high shot (AFTER)
const RISE := 0.2
const LUNGE := 1.2
const HIT := 1.5
const KNEEL := 1.75
const FALL := 3.4
const AFTER := 5.0
## the office's lights at full: the pool over the rug, the desk lamp, the cages' neon
const SPOT_E := 3.2
const DESK_E := 1.6
const CAGE_E := 1.8
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
var victim: Node3D
var ghost: Node3D
## the rolled-up plans Mara drops
var plans: MeshInstance3D
var env: Environment
var moon: DirectionalLight3D
var spot: SpotLight3D
var desk_lamp: OmniLight3D
var vex_light: OmniLight3D
var cage_lamps: Array = []
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
	cage_lamps = []
	ghost = null
	if stage != null:
		remove_child(stage)
		stage.queue_free()
	stage = Node3D.new()
	add_child(stage)
	if which == "tower":
		_build_tower()
		# (the music stops dead as the ghost rises, see _murder_sounds)
		Sfx.music("crypt" if elapsed < MURDER else "")
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
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
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
	env.ssao_enabled = true
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
	_box(Vector3(10.1, 3.0, 0.5), Vector3(0.3, 6.0, 15.4), brick, false, "wall_brick")
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
	# the freight cages along the sides, empty for now, crates of "freight" beside them; the lift in the front wall
	for x in [-7.3, 7.3]:
		_cage(Vector3(x, 0, 2.6))
		cage_lamps.append(_lamp(Vector3(x, 2.4, 2.6), "#d75a9c", CAGE_E, 6.0))
		var crates := _asset("crates", Vector3(x + (1.9 if x < 0 else -1.9), 0, 5.4), 1.3)
		crates.rotation.y = 0.4 if x < 0 else -0.3
		_asset("barrel", Vector3(x, 0, 5.8), 0.9)
	_lift(Vector3(5.0, 0, 8.1))
	# the pool of light over the rug, where it happens
	spot = SpotLight3D.new()
	spot.position = Vector3(-0.2, 5.9, 0.8)
	spot.rotation_degrees = Vector3(-90, 0, 0)
	spot.light_color = Color("#ffe2c4")
	spot.light_energy = SPOT_E
	spot.spot_range = 9.0
	spot.spot_angle = 32.0
	spot.spot_attenuation = 0.6
	spot.shadow_enabled = true
	stage.add_child(spot)
	# Vexmora's own cold light: nothing until she calls up her ghost
	vex_light = _lamp(VEX_AT + Vector3(0.5, 0.55, 0.5), "#9b5cff", 0.0, 6.0)
	_person("vex", VEX_LOOK, VEX_AT, Vector2i(1, 1))
	_person("gear", GEAR_LOOK, GEAR_AT, Vector2i(-1, 1))
	victim = _person("mara", ENGINEER_LOOK, MARA_AT, Vector2i(-1, -1))
	# her plans, rolled up under her arm until she drops them
	plans = MeshInstance3D.new()
	var roll := CylinderMesh.new()
	roll.top_radius = 0.06
	roll.bottom_radius = 0.06
	roll.height = 0.55
	plans.mesh = roll
	plans.material_override = _mat("#a8c8e8")
	plans.visible = false
	stage.add_child(plans)
	# the ghost Vexmora calls up: a Nocturna, in black and purple, wrapped in smoke
	var genes := RaceDB.genes(35)
	genes["shade"] = 1.0
	ghost = BeastModel.rig(genes, 1.0)
	if ghost != null:
		ghost.visible = false
		stage.add_child(ghost)


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


## A freight cage like the ones the captives are kept in later (trainer_cell.gd), empty.
func _cage(at: Vector3) -> void:
	_box(at + Vector3(0, 0.12, 0), Vector3(2.8, 0.25, 2.8), "#454c60")
	_box(at + Vector3(0, 2.85, 0), Vector3(2.8, 0.18, 2.8), "#454c60")
	for dx in [-1.25, 1.25]:
		for dz in [-1.25, 1.25]:
			_box(at + Vector3(dx, 1.5, dz), Vector3(0.08, 2.7, 0.08), "#cf506e", true)
	for dx in [-0.65, 0, 0.65]:
		_box(at + Vector3(dx, 1.5, 1.25), Vector3(0.04, 2.7, 0.04), "#60bdca", true)


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
			target = Vector3(0.6, 0.9, -2.0)
		"gear":
			pos = Vector3(0.1, 1.5, 0.2).lerp(Vector3(0.5, 1.45, -0.3), progress)
			target = GEAR_AT + Vector3(0, 0.7, 0)
		"plan":
			pos = Vector3(3.0, 2.0, -1.2).lerp(Vector3(3.6, 1.9, -0.4), progress)
			target = Vector3(6.4, 0.9, 4.6)
		"vex":
			pos = Vector3(0.8, 1.4, 2.0).lerp(Vector3(0.45, 1.35, 1.6), progress)
			target = VEX_AT + Vector3(0, 0.8, 0)
		"mara":
			pos = Vector3(-2.7, 1.7, -0.8).lerp(Vector3(-2.45, 1.65, -0.55), progress)
			target = MARA_AT + Vector3(0, 0.6, 0)
		"threat":
			pos = Vector3(0.45, 1.0, 1.6).lerp(Vector3(-0.15, 1.05, 1.0), progress)
			target = VEX_AT + Vector3(0, 0.95, 0)
		"murder":
			_murder_camera()
			return
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


## The murder's shots: behind Mara at Vexmora as the ghost rises; on Mara as it passes through her and she sinks
## down; on Vexmora's face as Mara falls (out of sight); then high above, Vexmora walking away.
func _murder_camera() -> void:
	var m := elapsed - MURDER
	var pos: Vector3
	var target: Vector3
	if m < LUNGE + 0.05:
		var k := m / (LUNGE + 0.05)
		pos = Vector3(1.3, 1.35, 3.5).lerp(Vector3(1.1, 1.3, 3.2), k)
		target = VEX_AT + Vector3(-0.3, 1.0, -0.4)
	elif m < FALL:
		var k := (m - LUNGE) / (FALL - LUNGE)
		pos = Vector3(-0.9, 1.3, 0.3).lerp(Vector3(-0.6, 1.1, 0.6), k)
		target = MARA_AT + Vector3(0.25, lerpf(0.75, 0.4, smoothstep(KNEEL - LUNGE, FALL - LUNGE, m - LUNGE)), 0.25)
	elif m < AFTER:
		var k := (m - FALL) / (AFTER - FALL)
		pos = Vector3(0.2, 0.95, 1.3).lerp(Vector3(0.0, 1.0, 1.05), k)
		target = VEX_AT + Vector3(-0.15, 1.0, 0)
	else:
		var k := (m - AFTER) / (DAWN - MURDER - AFTER)
		pos = Vector3(-3.6, 4.6, 6.2).lerp(Vector3(-3.4, 5.3, 7.0), k)
		target = Vector3(0.0, 0.3, 0.6)
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
			Person.set_talking(people[key], (key == "gear" and beat[2] == "MAGNUS GEARHART") or (key == "vex" and beat[2] == "GENERAL VEXMORA") or (key == "mara" and beat[2] == "ENGINEER MARA") or (key == "hero" and beat[2] == "{player}") or (key == "mom" and beat[2] == "MOM"), true)
	var p := clampf((elapsed - float(beat[0])) / (float(beat[1]) - float(beat[0])), 0, 1)
	_camera_shot(String(beat[4]), p)
	chapter_panel.visible = idx == 0 or String(beat[4]) == "spring"
	chapter.text = "THE LAST NIGHT OF WINTER" if idx == 0 else "THE FIRST DAY OF SPRING"
	chapter_sub.text = "Gearhart Tower · Cogsworth" if idx == 0 else "The beasts are waking. Trainer season begins."
	# Slow fades to and from black around the cut to spring, with no flashing screen on the killing blow.
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
	var m := elapsed - MURDER
	# the threat: the pool of light over the rug begins to fail as she speaks
	var dim := clampf((elapsed - 30.0) / 3.5, 0, 1) * 0.25
	# the murder: everything but the moon goes dark, and Vexmora's cold light rises as the ghost does
	var dark := smoothstep(0.0, LUNGE, m)
	var after := smoothstep(HIT, HIT + 0.4, m)
	# a failing bulb: two soft dips, never a strobe
	var flick := 1.0 - 0.35 * maxf(0.0, sin(m * 9.0)) * (1.0 - smoothstep(0.4, 1.4, absf(m - 0.7)))
	spot.light_energy = SPOT_E * lerpf(1.0 - dim, 0.15, dark) * lerpf(1.0, 0.5, after) * (flick if m > 0.0 else 1.0)
	# (what's left of the pool of light falls on Mara, where she lies)
	spot.light_energy = maxf(spot.light_energy, SPOT_E * 0.3 * smoothstep(FALL, AFTER, m))
	desk_lamp.light_energy = DESK_E * lerpf(1.0, 0.35, dark)
	for lamp in cage_lamps:
		(lamp as OmniLight3D).light_energy = CAGE_E * lerpf(1.0, 0.25, dark)
	env.ambient_light_color = Color("#4a5288").lerp(Color("#3a2458"), dark)
	env.ambient_light_energy = lerpf(0.42, 0.3, dark)
	var glow := smoothstep(RISE, LUNGE, m) * 3.2 + 2.4 * maxf(0.0, 1.0 - absf(m - HIT) / 0.5) - smoothstep(FALL, DAWN - MURDER, m) * 2.0
	vex_light.light_energy = maxf(0.0, glow) if m > 0.0 else 0.0
	# Vexmora reaches out to call the ghost, and lowers her hand once Mara has fallen; then turns her back and walks
	# away towards the windows
	var vex: Node3D = people["vex"]
	var reach := smoothstep(0.0, 0.7, m) * (1.0 - smoothstep(FALL + 0.2, FALL + 0.9, m))
	Person.set_reach(vex, reach if m > 0.0 else 0.0)
	var walk_t := clampf(m - AFTER - 0.3, 0.0, 1.9)
	var vex_pos := VEX_AT + Vector3(0, 0, -walk_t * 0.95)
	vex.position = vex_pos
	vex_light.position = vex_pos + Vector3(0.5, 0.55, 0.5)
	Person.face(vex, Vector2i(0, -1) if m > AFTER + 0.1 else Vector2i(1, 1), not preview)
	var walking := m > AFTER + 0.3 and m < AFTER + 2.2
	Person.animate(vex, Person.phase_for(walk_t * 0.95, 0.95), 0.95 if walking else 0.0, elapsed)
	# Gearhart backs off towards his desk once it's done, and stays well away
	var gear: Node3D = people["gear"]
	var back := smoothstep(HIT + 0.2, HIT + 1.2, m)
	gear.position = GEAR_AT + Vector3(0.35, 0, -0.55) * back
	# (stepping backwards: the walk runs in reverse, so his feet stay planted)
	Person.animate(gear, -Person.phase_for(back * 0.65, 0.6), 0.6 if back > 0.0 and back < 1.0 else 0.0, elapsed)
	_mara_frame(m)
	_ghost_frame(m)
	_murder_sounds(m)


## Mara: staggers back as the ghost passes through her and drops her plans, sinks to one knee, slumps forward... and
## (after the cut to Vexmora) lies still on the rug.
func _mara_frame(m: float) -> void:
	var hit := smoothstep(HIT - 0.05, HIT + 0.3, m)
	var away := Vector3(1, 0, 1).normalized()
	var at := MARA_AT + away * 0.3 * hit
	victim.position = at
	if m < FALL:
		victim.rotation = Vector3(0, 0, 0)
		Person.face(victim, Vector2i(-1, -1))
		var kneel := smoothstep(KNEEL, KNEEL + 0.75, m)
		Person.set_pose(victim, "kneel" if kneel > 0.0 else "")
		victim.set_meta("kneel_w", kneel)
		# folding forward over her knee as her strength goes
		var slump := smoothstep(FALL - 0.6, FALL, m) * 0.35
		victim.rotation = Vector3(0, 0, 0)
		victim.get_node("Body").rotation.x = slump
		Person.animate(victim, 0.0, 0.0, elapsed)
	else:
		# face down on the floor where she fell, quite still
		Person.set_pose(victim, "")
		victim.set_meta("kneel_w", 0.0)
		victim.get_node("Body").rotation = Vector3.ZERO
		Person.face(victim, Vector2i(0, 1))
		victim.rotation = Vector3(PI / 2.0 - 0.06, atan2(-away.x, -away.z), 0.18)
		victim.position = at + Vector3(0, 0.15, 0) + away * 0.1
		Person.animate(victim, 0.0, 0.0, MURDER + FALL)
	# the plans: under her arm, dropped as she's struck, rolling away across the floor
	plans.visible = m > HIT - 0.02
	var drop := smoothstep(HIT, HIT + 0.3, m)
	var roll := smoothstep(HIT + 0.3, HIT + 1.6, m)
	var held := MARA_AT + Vector3(0.15, 0.75, 0.05)
	var landed := MARA_AT + Vector3(0.5, 0.06, 0.4)
	plans.position = held.lerp(landed, drop) + Vector3(0.9, 0, 0.55) * roll
	plans.rotation = Vector3(PI / 2.0 * drop, -0.6, roll * 9.0)


## The ghost: rises out of the floor behind Vexmora, lunges straight through Mara, and wheels back to hover at
## Vexmora's shoulder, following her as she leaves.
func _ghost_frame(m: float) -> void:
	if ghost == null:
		return
	ghost.visible = m > RISE
	if not ghost.visible:
		return
	var rise_at := VEX_AT + Vector3(-0.9, 0.0, -1.0)
	var past := MARA_AT + Vector3(1.4, 0.7, 1.4)
	var vex_pos: Vector3 = people["vex"].position
	var home := vex_pos + Vector3(-0.85, 0.75 + sin(elapsed * 2.0) * 0.08, -0.7)
	var pos: Vector3
	var look := Vector3(1, 0, 1)
	var s := 1.0
	if m < LUNGE:
		var k := smoothstep(RISE, LUNGE, m)
		pos = rise_at + Vector3(0, lerpf(-0.6, 1.0, k), 0)
		s = lerpf(0.3, 1.0, k)
	elif m < HIT + 0.3:
		var k := (m - LUNGE) / (HIT + 0.3 - LUNGE)
		pos = (rise_at + Vector3(0, 1.0, 0)).lerp(past, k * k)
		look = past - rise_at
	elif m < FALL:
		var k := smoothstep(HIT + 0.3, FALL, m)
		pos = past.lerp(home, k) + Vector3(0, sin(k * PI) * 1.2, 0)
		look = home - past
	else:
		pos = home
		look = Vector3(1, 0, 1) if m < AFTER + 0.3 else Vector3(0, 0, -1)
	ghost.position = pos
	ghost.scale = Vector3.ONE * s
	ghost.rotation.y = atan2(-look.z, look.x)
	if m >= LUNGE and _last_time - MURDER < LUNGE and not preview:
		ghost.attack()


func _murder_sounds(m: float) -> void:
	if preview:
		return
	var was := _last_time - MURDER
	if m >= 0.0 and was < 0.0:
		# silence: the music stops dead
		Sfx.music("")
		Sfx.ambience("")
	if m >= RISE and was < RISE:
		Sfx.play("ghost")
	if m >= LUNGE and was < LUNGE:
		Sfx.play("growl")
	if m >= HIT and was < HIT:
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
