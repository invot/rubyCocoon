extends Node3D
## A self-contained, real-time prologue. No map visits, inventory or quest knowledge is granted here.
## The same timeline drives playback and deterministic screenshot previews.

const Person = preload("res://scripts/gfx/voxel_person.gd")
const Assets = preload("res://scripts/gfx/voxel_assets.gd")
const Props = preload("res://scripts/gfx/voxel_props.gd")
const BeastModel = preload("res://scripts/gfx/beast_model.gd")
const RaceDB = preload("res://scripts/data/race_db.gd")
const Kit = preload("res://scripts/ui/ui_kit.gd")
const Houses = preload("res://scripts/gfx/house_models.gd")
const Textures = preload("res://scripts/gfx/voxel_textures.gd")
const CinematicDialog = preload("res://scripts/ui/cinematic_dialog.gd")
const CompanyBrand = preload("res://scripts/gfx/company_brand.gd")
const VEX_LOOK := {"skin": "#c8b0b8", "hair": "#e0e0f0", "shirt": "#1a1024", "pants": "#120c18", "hat": "#6a2a9a", "outfit": "armor"}
const GEAR_LOOK := {"skin": "#e8c0a0", "hair": "#d8d8e0", "shirt": "#1a1a22", "pants": "#1a1a22", "hat": "#2a2a2a", "outfit": "coat"}
const ENGINEER_LOOK := {"skin": "#bc8868", "hair": "#49332d", "shirt": "#d6ae58", "pants": "#455469", "outfit": "apron"}
const LENGTH := 68.0
const MURDER := 33.5
const DAWN := 36.0
## start, end, speaker, subtitle, camera shot. Subtitles advance automatically; A also advances a beat.
const BEATS := [
	[0.0, 3.5, "", "", "wide"],
	[3.5, 10.0, "MAGNUS GEARHART", "First day of spring. Beasts wake. New trainers fill the roads.", "gear"],
	[10.0, 16.5, "MAGNUS GEARHART", "My robots collect them. My freight lifts hide the cages.", "plan"],
	[16.5, 23.5, "GENERAL VEXMORA", "Send them to Gravenmoor. Their bonds will teach my ghost beasts to obey. Leave their flutes behind.", "vex"],
	[23.5, 30.0, "ENGINEER MARA", "I built transports. Not cages. I won't help you take those trainers.", "mara"],
	[30.0, 33.5, "GENERAL VEXMORA", "Then you won't see spring.", "vex"],
	[33.5, 36.0, "", "", "murder"],
	[36.0, 41.5, "", "", "spring"],
	[41.5, 48.0, "", "Out of their burrows. Off to find food, a mate... or trouble.", "beasts"],
	[48.0, 54.0, "{player}", "Spring's here! My first beast. My own journey. I can hardly wait!", "hero"],
	[54.0, 60.0, "MOM", "Rowan's got your egg. Uncle Rafe has Dad's flute, over in Tidewater.", "hero"],
	[60.0, 68.0, "{player}", "A whole season of adventure! Unless some gloomy weirdo's put 'ruin spring' on his to-do list. Ha! Get a hobby!", "hero"],
]

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
var blade: MeshInstance3D
var victim: Node3D
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
	if stage != null:
		remove_child(stage)
		stage.queue_free()
	stage = Node3D.new()
	add_child(stage)
	if which == "tower":
		_build_tower()
		Sfx.music("crypt")
		Sfx.ambience("machines")
	else:
		_build_spring()
		Sfx.music("coast")
		Sfx.ambience("wind")


func _environment(spring: bool) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#e7bc94" if spring else "#101325")
	if spring:
		var sky := Sky.new()
		var material := ProceduralSkyMaterial.new()
		material.sky_top_color = Color("#87b4c4")
		material.sky_horizon_color = Color("#edc9aa")
		material.ground_horizon_color = Color("#edc9aa")
		sky.sky_material = material
		env.sky = sky
		env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#bac5b1" if spring else "#a2a6cf")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.2
	env.ssao_enabled = true
	env.ssao_radius = 0.65
	env.ssao_intensity = 1.5
	if spring:
		env.fog_enabled = true
		env.fog_density = 0.004
		env.fog_light_color = Color("#edc9aa")
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	stage.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#ffe2bd" if spring else "#98b9ff")
	sun.light_energy = 1.15 if spring else 1.1
	sun.rotation_degrees = Vector3(-28, -35, 0)
	sun.shadow_enabled = true
	stage.add_child(sun)


func _box(pos: Vector3, size: Vector3, colour: String, glow := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(colour)
	mat.roughness = 0.8
	if glow:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.emission = Color(colour)
	mesh.material = mat
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	stage.add_child(node)
	return node


func _asset(key: String, pos: Vector3, height: float) -> MeshInstance3D:
	var node := Assets.instance(key, height)
	node.position += pos
	stage.add_child(node)
	return node


func _person(key: String, look: Dictionary, pos: Vector3, face := Vector2i(0, 1)) -> Node3D:
	var node := Person.build(look)
	node.position = pos
	Person.face(node, face)
	stage.add_child(node)
	people[key] = node
	return node


func _build_tower() -> void:
	_environment(false)
	_box(Vector3(0, -0.25, 0), Vector3(27, 0.5, 24), "#202435")
	for x in range(-12, 14, 2):
		_box(Vector3(x, 0.006, 0), Vector3(0.025, 0.015, 23), "#414858")
	_box(Vector3(0, 0.012, 0.1), Vector3(3.3, 0.02, 10), "#4a203c")
	# A window wall with a neon skyline beyond it; empty shipping cages in the foreground.
	for x in [-11, -5, 1, 7, 12]:
		_box(Vector3(x, 3.1, -7), Vector3(0.22, 6.2, 0.24), "#374356")
	_box(Vector3(0, 6, -7), Vector3(27, 0.3, 0.4), "#374356")
	for i in 18:
		var x := float(i) * 2.5 - 21.0
		var h := 3.5 + fmod(float(i * 17), 7.0)
		var z := -16.0 - fmod(float(i * 7), 9.0)
		_box(Vector3(x, h * 0.5 - 2, z), Vector3(2, h, 2.5), "#171b30")
		for j in int(h):
			_box(Vector3(x, j - 1.0, z + 1.27), Vector3(1.4, 0.09, 0.02), "#48a4ba" if i % 3 else "#ca548f", true)
	_box(Vector3(0, 1, -4.6), Vector3(6, 2, 1.4), "#353044")
	_box(Vector3(0, 2.05, -4.6), Vector3(6.3, 0.15, 1.65), "#b18c59")
	var company_sign := CompanyBrand.sign_node()
	company_sign.position = Vector3(0, 4.4, -6.72)
	stage.add_child(company_sign)
	# The plaque is fastened to the window structure, with a visible rail behind it.
	_box(Vector3(0, 4.4, -6.95), Vector3(10.2, 0.18, 0.25), "#374356")
	_person("vex", VEX_LOOK, Vector3(-1.35, 0, 0), Vector2i(1, 1))
	_person("gear", GEAR_LOOK, Vector3(2.3, 0, -2.9), Vector2i(-1, 1))
	victim = _person("mara", ENGINEER_LOOK, Vector3(0.9, 0, 1.4), Vector2i(-1, -1))
	for x in [-5.3, 5.3]:
		var robot := _asset("robot_golem", Vector3(x, 0, -1.8), 2.8)
		robot.rotation.y = -PI / 2
	for x in [-7.3, 7.3]:
		_box(Vector3(x, 0.12, 3), Vector3(2.8, 0.25, 2.8), "#454c60")
		_box(Vector3(x, 2.85, 3), Vector3(2.8, 0.18, 2.8), "#454c60")
		for dx in [-1.25, 1.25]:
			for dz in [-1.25, 1.25]:
				_box(Vector3(x + dx, 1.5, 3 + dz), Vector3(0.08, 2.7, 0.08), "#cf506e", true)
		for dx in [-0.65, 0, 0.65]:
			_box(Vector3(x + dx, 1.5, 4.25), Vector3(0.04, 2.7, 0.04), "#60bdca", true)
	blade = _box(Vector3(0.25, 1.05, 1.025), Vector3(0.08, 0.09, 1.9), "#e4a6ff", true)
	blade.rotation.y = 1.1
	blade.visible = false
	for x in [-7, 7]:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(x, 2.5, 3)
		lamp.light_color = Color("#d75a9c")
		lamp.light_energy = 2.0
		lamp.omni_range = 7
		stage.add_child(lamp)


func _beast(race: int, pos: Vector3, size := 1.0) -> void:
	var beast = BeastModel.rig(RaceDB.genes(race), size)
	stage.add_child(beast)
	beast.position = pos
	beasts.append(beast)


func _build_spring() -> void:
	_environment(true)
	var grass := _box(Vector3(0, -0.35, 0), Vector3(160, 0.6, 160), "#87975c")
	var ground_mat := grass.mesh.material as StandardMaterial3D
	ground_mat.albedo_texture = Textures.terrain("top_grass", "#8b9c69")
	ground_mat.albedo_color = Color.WHITE
	ground_mat.uv1_triplanar = true
	ground_mat.uv1_scale = Vector3.ONE * 0.8
	var path := _box(Vector3(0, -0.032, 2.5), Vector3(3, 0.035, 27), "#c6ae7e")
	var path_mat := path.mesh.material as StandardMaterial3D
	path_mat.albedo_texture = Textures.terrain("top_path", "#b5a181")
	path_mat.albedo_color = Color.WHITE
	path_mat.uv1_triplanar = true
	_box(Vector3(20, -0.1, -14), Vector3(28, 0.08, 40), "#709eaa")
	for i in 18:
		var x := sin(float(i) * 4.3) * 16.0
		var z := -6.0 - fmod(float(i * 7), 17.0)
		_asset("tree_round_1" if i % 2 else "tree_birch", Vector3(x, 0, z), 5.0 + fmod(i * 1.7, 3.0))
	for i in 75:
		var x := sin(float(i) * 7.9) * 11.0
		var z := cos(float(i) * 2.7) * 11.0 - 1.0
		if absf(x) < 1.7:
			continue
		var flowers := MeshInstance3D.new()
		flowers.mesh = Props.flowers(i % 5)
		flowers.position = Vector3(x, 0, z)
		flowers.scale = Vector3.ONE * 1.4
		stage.add_child(flowers)
	# A little burrow, breakfast berries and a pair of springtime flyers.
	_asset("field_rock", Vector3(-4.1, 0, -0.5), 1.15)
	_box(Vector3(-4.1, 0.19, 0.13), Vector3(0.68, 0.4, 0.1), "#30372a")
	_asset("stump", Vector3(3.2, 0, 0.5), 0.55)
	for i in 7:
		_box(Vector3(3.2 + sin(i * 2.4) * 0.38, 0.62, 0.5 + cos(i * 2.4) * 0.3), Vector3.ONE * 0.13, "#bd5371")
	_beast(12, Vector3(-3.8, 0, 0.8), 1.4)
	_beast(0, Vector3(2.5, 0, 1.1), 1.3)
	_beast(30, Vector3(-1.8, 2.8, -3.3), 1.2)
	_beast(30, Vector3(0.5, 3.1, -4.3), 1.1)
	beasts[1].rotation.y = 0.7
	# The hero's actual custom appearance, already dressed for the season.
	_person("hero", GameState.hero_look(), Vector3(0, 0, 4.4), Vector2i(0, -1))
	var mom_look := {"model": "tf62", "skin": "#f0c8a0", "hair": "#8a3a20", "shirt": "#e07a5a", "pants": "#4a3a6a"}
	var family: Dictionary = Person.Townfolk.outfit(GameState.hero_look())["colours"]
	for key in ["skin", "hair", "eyes"]:
		if family.has(key):
			mom_look[key] = "#" + (family[key] as Color).to_html(false)
	_person("mom", mom_look, Vector3(3.7, 0, 6.0), Vector2i(-1, 0))
	# Cottage and spring bunting at the edge of the clearing.
	var rng := RandomNumberGenerator.new()
	rng.seed = 26
	var house: Array = Houses.backdrop("coastal", rng)
	var cottage: Node3D = house[0]
	cottage.scale = Vector3.ONE * 3.8 / float(house[1])
	cottage.rotation.y = -PI / 2
	cottage.position = Vector3(7.5, 0, 7.7)
	stage.add_child(cottage)
	for x in [-12, -7, 0, 14]:
		_asset("tree_round_1", Vector3(x, 0, 14), 5.8)
	for i in 8:
		_box(Vector3(-3.5 + i, 3.7 - sin(i * PI / 7) * 0.5, 4.9), Vector3(0.25, 0.35, 0.02), "#e1a871" if i % 2 else "#7babc0")


func _camera_shot(shot: String, progress: float) -> void:
	var pos := Vector3.ZERO
	var target := Vector3.ZERO
	match shot:
		"wide":
			pos = Vector3(11, 6.8, 16).lerp(Vector3(9, 5.6, 14), progress)
			target = Vector3(0, 1.5, -1)
		"mara":
			pos = Vector3(-3.7, 2.9, 6.5).lerp(Vector3(-3.2, 2.5, 5.7), progress)
			target = Vector3(0.5, 1.2, 1.2)
		"vex":
			pos = Vector3(3.5, 2.7, 6).lerp(Vector3(2.7, 2.25, 5.3), progress)
			target = Vector3(-1.3, 1.05, 0)
		"murder":
			pos = Vector3(4.5, 3.5, 7.3)
			target = Vector3(-0.15, 0.9, 0.6)
		"gear":
			pos = Vector3(-3.3, 3.4, 5).lerp(Vector3(-2.4, 3.0, 4.3), progress)
			target = Vector3(2.1, 1.3, -2.9)
		"plan":
			pos = Vector3(-3, 4.2, 12.4).lerp(Vector3(-2.5, 3.6, 11.2), progress)
			target = Vector3(0.8, 1.25, -0.5)
		"spring":
			pos = Vector3(-11, 7.8, 15).lerp(Vector3(-8, 5.7, 12), progress)
			target = Vector3(0, 1.0, -1)
		"beasts":
			pos = Vector3(-7, 3.9, 8).lerp(Vector3(-5.8, 3.0, 6.7), progress)
			target = Vector3(0, 1.0, 0)
		"hero":
			pos = Vector3(-1.8, 2.6, -2.0).lerp(Vector3(-1.3, 2.25, -0.9), progress)
			target = Vector3(1.0, 1.1, 4.6)
	camera.position = pos
	camera.look_at(target)


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
	# Gentle cuts, with no flashing screen on the killing blow.
	var fade := maxf(0, 1.0 - elapsed / 0.8)
	fade = maxf(fade, clampf(1.0 - absf(elapsed - DAWN) / 0.65, 0, 1))
	fade = maxf(fade, clampf((elapsed - LENGTH + 0.65) / 0.65, 0, 1))
	shade.color = Color(0.025, 0.03, 0.06, fade)
	if _scene == "tower":
		var strike := clampf((elapsed - MURDER - 0.2) / 0.4, 0, 1)
		var fall := smoothstep(0.0, 1.0, clampf((elapsed - MURDER - 0.65) / 0.85, 0, 1))
		people["vex"].position = Vector3(-1.35, 0, 0).lerp(Vector3(-0.5, 0, 0.65), strike)
		blade.visible = elapsed >= MURDER + 0.2 and elapsed < MURDER + 1.0
		victim.rotation.z = -PI * 0.5 * fall
		victim.position = Vector3(0.9 + fall * 0.5, fall * 0.24, 1.4 + fall * 0.3)
		if elapsed >= MURDER + 0.6 and _last_time < MURDER + 0.6 and not preview:
			Sfx.play("miss")
			Sfx.play("crit")
		if elapsed >= MURDER + 1.4 and _last_time < MURDER + 1.4 and not preview:
			Sfx.play("faint")
		for key in people:
			# Mara remains motionless after the murder; no battle or revival cue.
			Person.animate(people[key], 0, 0, MURDER + 0.65 if key == "mara" and elapsed >= MURDER + 0.65 else elapsed)
	else:
		for key in people:
			Person.animate(people[key], 0, 0, elapsed)
		var awake := clampf((elapsed - DAWN - 0.7) / 3.2, 0, 1)
		beasts[0].position = Vector3(-4.1, -0.2, 0.2).lerp(Vector3(-3.1, 0, 1.7), awake)
		beasts[0].state = "walk" if awake < 1 else "idle"
		for i in [2, 3]:
			beasts[i].position = Vector3(sin(elapsed * 0.3 + i) * 2.4, 2.7 + sin(elapsed * 0.8 + i) * 0.3, -3.5 + cos(elapsed * 0.3 + i) * 1.3)
	_last_time = elapsed
