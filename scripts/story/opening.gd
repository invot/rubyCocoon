extends Node3D
## A self-contained, real-time prologue. No map visits, inventory or quest knowledge is granted here.
## The same timeline drives playback and deterministic screenshot previews.
##
## Three sets. Gearhart's office at the top of his tower by night, built here from the game's own pieces (wood floor,
## brick and panelling under timber beams, the company sign over the desk, turning brass gears, his new robots lined
## up before the windows onto the neon city, crates and the freight lift), with his freight warehouse behind a steel
## door in its east wall. Then the real Coastal Path at dawn and the hero's real bedroom, built by the world itself
## as film sets (main.gd build_set), so the film shows the very places the game starts in.
## The reveal is played straight: Gearhart sends his staff home with a pep talk about "freight", walks alone to the
## steel door and steps through. The music stops dead, a dread hit (sfx "dread"), and behind it is a warehouse under
## cool hanging lamps: a concrete shed with a truss roof, shipping containers, racks and crates, and down its aisle
## rusted iron cages full of trainers (Lio, Bea and Orin among them, as the hero finds them later), their beasts in
## smaller cages on pallets at the far end. Then spring, out on the Coastal Path where the wild beasts live (there
## are none in towns): Scout Bram and Camper Tilly on the trail, watching them come out of the tall grass; and the
## hero up in their bedroom, Mom calling from downstairs. The game starts right there.
##
## Everything is told by people talking: spoken lines use the game's white speech bubbles over whoever speaks
## (cinematic_dialog.gd), and there is no narration or title card. A turns the page, and so does a tap of B; holding
## B (Esc, Start) skips the film. The top-centre HUD names those controls for the first seconds of each scene, then
## slides away. On a phone only the pad's plain A and B show (controls_overlay.gd set_film_mode): nothing can move,
## so the d-pad steps aside.

const Person = preload("res://scripts/gfx/voxel_person.gd")
const Assets = preload("res://scripts/gfx/voxel_assets.gd")
const BeastModel = preload("res://scripts/gfx/beast_model.gd")
const RaceDB = preload("res://scripts/data/race_db.gd")
const Kit = preload("res://scripts/ui/ui_kit.gd")
const RoomBuilder = preload("res://scripts/gfx/room_builder.gd")
const CinematicDialog = preload("res://scripts/ui/cinematic_dialog.gd")
const CompanyBrand = preload("res://scripts/gfx/company_brand.gd")
const TrainerCell = preload("res://scripts/story/trainer_cell.gd")
const MapGen = preload("res://scripts/world/map_gen.gd")
const MapLoader = preload("res://scripts/world/map_loader.gd")
const WorldDB = preload("res://scripts/data/world_db.gd")
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
const LENGTH := 80.5
## Gearhart heads for the steel door; the cut into the warehouse; the cut to spring; the cut up to the bedroom
const DOOR := 23.5
const INSIDE := 28.5
const DAWN := 40.5
const ROOM := 60.5
## start, end, who speaks, the line, camera shot. Lines advance automatically; A also advances a beat. Each line
## fits one page of a speech bubble (three lines), since nothing turns a page for the audience.
const BEATS := [
	[0.0, 3.5, "", "", "wide"],
	[3.5, 10.0, "gear", "Gather round, team. Tomorrow is the first day of spring, and new trainers fill every road.", "gear"],
	[10.0, 16.5, "mara", "The new freight robots are ready, sir. The lifts run quiet, and every crate is sealed.", "staff"],
	[16.5, 20.2, "gear", "Splendid! Our friend in Gravenmoor pays well for every delivery.", "plan"],
	[20.2, 23.5, "gear", "Off home, all of you. Big day tomorrow.", "leave"],
	[23.5, 28.5, "gear", "Now then. Let's look in on tonight's freight.", "door"],
	[28.5, 33.5, "bea", "Please, let us out! Give us back our beasts!", "reveal"],
	[33.5, 37.5, "gear", "Every trainer caged, every beast crated. General Vexmora pays by the bond.", "crates"],
	[37.5, 40.5, "", "", "cages"],
	[40.5, 44.0, "", "", "spring"],
	[44.0, 49.5, "bram", "Look at that, Tilly! First morning of spring, and the beasts are out of their burrows already.", "neighbours"],
	[49.5, 55.0, "tilly", "A whole winter asleep. Now they're off to find food, a mate... or trouble.", "beasts"],
	[55.0, 60.5, "bram", "Which makes it trainer season. Elder Rowan has an egg waiting for somebody back in town.", "egg"],
	[60.5, 66.5, "hero", "Spring's here! My first beast. My own journey. I can hardly wait!", "hero"],
	[66.5, 72.5, "mom", "Up already? Rowan's got your egg, and Uncle Rafe has Dad's flute, over in Bellerive!", "mom"],
	[72.5, 76.0, "hero", "A whole season of adventure!", "joke"],
	[76.0, 80.5, "hero", "Unless some gloomy weirdo's put 'ruin spring' on his to-do list. Ha! Get a hobby!", "home"],
]
## the names on the speech bubbles (the hero's is the player's), and which figure on the set each speaker is; Mom
## calls from downstairs, so hers is the stationary bubble of a voice off screen
const SPEAKERS := {"gear": "Magnus Gearhart", "mara": "Engineer Mara", "bea": "Trainer Bea", "mom": "Mom",
	"tilly": "Camper Tilly", "bram": "Scout Bram"}
const ACTORS := {"gear": "gear", "mara": "mara", "bea": "captive0", "hero": "hero", "tilly": "tilly", "bram": "bram"}
## each scene's place, under the controls in the top-centre HUD, which stays up this long as the scene begins
const PLACES := {"tower": "Gearhart Tower · Cogsworth", "route": "Coastal Path", "room": "Your Home · Cocoon Cove"}
const HUD_HOLD := 4.0
## how long B (Esc, Start) is held to skip the film; let go sooner than TAP and B turned the page instead
const SKIP_HOLD := 1.0
const TAP := 0.35
## Where everyone stands in the office: Gearhart on the rug's east side, his staff in a huddle facing him.
const GEAR_AT := Vector3(4.4, 0, 0.6)
const STAFF_AT := [Vector3(1.5, 0, -0.6), Vector3(1.1, 0, 0.9), Vector3(1.7, 0, 2.3)]
## the steel door in the office's east wall, and the freight warehouse behind it: its far (east) wall, how far its
## long walls stand from the aisle (DOOR_Z), its eaves and ridge, the trainers' cages either side of the aisle, the
## beasts' cages in a row across the far end
const DOOR_X := 10.1
const DOOR_Z := 2.6
const ROOM_END := 28.0
const HALF := 7.4
const EAVE := 5.4
const RIDGE := 8.4
const CELL_XS := [12.7, 15.6, 18.5]
const CELL_Z := 3.0
const TUBE_X := 22.4
const TUBE_ZS := [-0.9, 0.85, 2.6, 4.35, 6.1]
const CAGE := "res://assets/props/iron_cage.res"
## Gearhart's walk: from the rug to the door, down the aisle, and over to the beasts' cages; when he sets off, how fast
const GEAR_PATH := [Vector3(4.4, 0, 0.6), Vector3(9.4, 0, 2.6), Vector3(19.6, 0, 2.6), Vector3(20.8, 0, 3.4)]
const GEAR_WALK := 24.0
const GEAR_SPEED := 1.25
## the staff head for the lift as the briefing ends
const STAFF_GO := 20.2
const LIFT_AT := Vector3(5.0, 0, 8.1)
## when the steel door slides open
const DOOR_OPEN := 26.6
## the office's lights at full: the pool over the rug, the desk lamp, the neon by the crates, the hanging lamps; the
## warehouse's softer white lamps
const SPOT_E := 3.4
const DESK_E := 1.7
const CAGE_E := 1.8
const HANG_E := 1.5
const ROOM_E := 2.2
## the office's woods, brick and brass; the warehouse's concrete and steel
const BRICK := "#7a646c"
const PANEL := "#4a3026"
const BEAM := "#3a2a24"
const BRASS := "#c08c3c"
const CONCRETE := "#7e7d79"
const STEEL := "#565c66"
## The roomy shoulder inside the Coastal Path's western bend. The trainers stand clear of the grass and banks;
## beasts have their own lawn beside them. All shots face inland, away from the route entrance and map boundary.
const TILLY_AT := Vector3(19.6, 0, 8.4)
const BRAM_AT := Vector3(17.8, 0, 8.4)
const BURROW := Vector3(16.1, 0, 6.4)
const LAWN := Vector3(16.0, 0, 9.2)
const FLYERS_AT := Vector3(17.0, 0, 6.0)

signal finished(skipped: bool)
var elapsed := 0.0
var preview := false
var running := false
var skipped := false
## true while a set is being built (the real places take a moment): the clock stands still behind the black
var loading := false
var stage: Node3D
var camera: Camera3D
var overlay: Control
var dialogue: Control
var shade: ColorRect
## how far through the hold B is: a thin bar under the top-centre HUD
var skip_track: ColorRect
var skip_meter: ColorRect
var people := {}
var beasts: Array = []
## the captive beasts in their cages
var crated: Array = []
## the office wall's turning gears
var gears: Array = []
var env: Environment
var moon: DirectionalLight3D
var spot: SpotLight3D
var desk_lamp: OmniLight3D
var cage_lamps: Array = []
var hang_lamps: Array = []
## the warehouse's own lamps and the beams under them (off until the door opens), and the light spilling through
## the door
var room_lamps: Array = []
var room_beams: Array = []
var door_light: OmniLight3D
var door_panel: MeshInstance3D
## the real place standing in as the set (the Coastal Path, then the bedroom), and the view the game itself will
## open on in the bedroom
var set_world: Node3D
var _home_view := Transform3D.IDENTITY
var _home_fov := 44.0
var _mats := {}
var _scene := ""
var _beat := -1
var _shot := ""
## the beat whose line is up
var _spoken := -1
var _last_time := 0.0
var _done := false
var _skip_wanted := false
## how long B has been held (below zero: it isn't), and whether letting go early turns the page
var _hold := -1.0
var _hold_taps := false


func _ready() -> void:
	_build_overlay()
	UI.controls.set_film_mode(true)


func start(at := 0.0, hold := false) -> void:
	preview = hold
	elapsed = clampf(at, 0.0, LENGTH - 0.01)
	running = true
	_step()


func _exit_tree() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	if is_instance_valid(UI.controls):
		UI.controls.set_film_mode(false)
	if is_instance_valid(set_world):
		set_world.keep_shaders()


func skip() -> void:
	if not running or _done:
		return
	skipped = true
	if loading:
		# a set is half built: the film ends the moment it's done
		_skip_wanted = true
		return
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
		if _hold < 0.0:
			_hold = 0.0
			_hold_taps = event.is_action("ui_cancel")
	elif event.is_action_released("ui_cancel") or event.is_action_released("menu"):
		if _hold >= 0.0:
			var tapped := _hold < TAP and _hold_taps
			_hold = -1.0
			if tapped:
				_next()
	elif event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_next()


func _next() -> void:
	if is_instance_valid(dialogue):
		dialogue._advance()
	else:
		advance()


func advance() -> void:
	if not running or _done or loading:
		return
	if _beat >= 0 and _beat < BEATS.size() - 1:
		elapsed = float(BEATS[_beat + 1][0])
		_step()
	else:
		_complete()


func _process(delta: float) -> void:
	if not running:
		return
	if _hold >= 0.0:
		var before := _hold
		_hold += delta
		if before < TAP and _hold >= TAP:
			# held past a tap: the HUD says to keep holding, and the bar under it starts to fill
			_post_hint(true)
		if _hold >= SKIP_HOLD:
			_hold = -1.0
			skip()
	skip_track.visible = _hold >= TAP
	skip_track.position = Vector2(roundf((overlay.size.x - skip_track.size.x) / 2.0), UI.top_bar.bottom() + 8.0)
	skip_meter.anchor_right = clampf((_hold - TAP) / (SKIP_HOLD - TAP), 0.0, 1.0)
	if loading or not running:
		return
	if not preview:
		elapsed += delta
	if elapsed >= LENGTH:
		_complete()
		return
	_step()


## One frame of the film: the set for this moment (built first if it isn't standing), then everyone on it.
func _step() -> void:
	var which := _scene_at(elapsed)
	if which != _scene:
		_change_scene(which)
		return
	_update_frame()


func _scene_at(t: float) -> String:
	return "tower" if t < DAWN else "route" if t < ROOM else "room"


func _build_overlay() -> void:
	# Parent to the real UI, not the SubViewport. CanvasLayer.custom_viewport changes drawing, but does not
	# change the viewport used by descendant Control anchors (the old phone layout lost its bottom/right edges).
	overlay = Control.new()
	overlay.name = "CinematicUI"
	UI.root.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.theme = Kit.make_theme()
	# (the dialogue goes in under the shade; the film's controls are named in the top-centre HUD, see _post_hint)
	shade = ColorRect.new()
	overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.color = Color(0.025, 0.03, 0.06, 1)
	skip_track = ColorRect.new()
	skip_track.color = Color(1, 1, 1, 0.22)
	skip_track.size = Vector2(260, 6)
	skip_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skip_track.visible = false
	overlay.add_child(skip_track)
	skip_meter = ColorRect.new()
	skip_meter.color = Color.WHITE
	skip_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skip_track.add_child(skip_meter)
	skip_meter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skip_meter.anchor_right = 0.0


## The film's controls, in the top-centre HUD over the scene's place: up for the first seconds of each scene, then
## it slides away; back while B is held, to say keep holding.
func _post_hint(holding := false) -> void:
	var keys: bool = not UI.is_touch() and not UI.controls.controller_guide()
	var text := "Enter: Next  ·  Hold Esc: Skip" if keys else "A: Next  ·  Hold B: Skip"
	if holding:
		text = "Keep holding Esc to skip" if keys else "Keep holding B to skip"
	UI.top_bar.post(text, UI.Glyphs.tex("town" if _scene == "room" else "pin"),
		{"sub": String(PLACES.get(_scene, "")), "key": "film", "replace": true, "hold": SKIP_HOLD if holding else HUD_HOLD})


func _show_dialogue(beat: Array) -> void:
	if is_instance_valid(dialogue):
		overlay.remove_child(dialogue)
		dialogue.queue_free()
	dialogue = null
	if String(beat[3]) == "":
		return
	var who := String(beat[2])
	var speaker: String = GameState.player_name if who == "hero" else String(SPEAKERS.get(who, ""))
	dialogue = CinematicDialog.new()
	dialogue.instant_text = preview
	dialogue.setup([String(beat[3])], speaker, null, people.get(ACTORS.get(who, ""), null))
	dialogue.advance_requested.connect(advance)
	overlay.add_child(dialogue)
	overlay.move_child(dialogue, 0)


## Out with the set that's standing and up with the next, in the dark: the cut is always made on a black screen.
func _change_scene(which: String) -> void:
	loading = true
	_scene = which
	_beat = -1
	_spoken = -1
	_shot = ""
	_show_dialogue([0, 0, "", "", ""])
	shade.color.a = 1.0
	people = {}
	beasts = []
	crated = []
	gears = []
	cage_lamps = []
	hang_lamps = []
	room_lamps = []
	room_beams = []
	if is_instance_valid(set_world):
		set_world.keep_shaders()
	set_world = null
	if stage != null:
		remove_child(stage)
		stage.queue_free()
	stage = Node3D.new()
	add_child(stage)
	match which:
		"tower":
			_build_tower()
			# (the music stops dead as he steps into the warehouse, see _reveal_sounds)
			Sfx.music("crypt" if elapsed < INSIDE else "")
			Sfx.ambience("machines")
		"route":
			set_world = await GameState.main.build_set("route1", stage)
			if not _still_wanted(which):
				return
			await _dress_route()
		"room":
			var home := MapLoader.interior_of("caccoon", "home")
			set_world = await GameState.main.build_set(MapLoader.wake_room(home), stage)
			if not _still_wanted(which):
				return
			_dress_room()
	if not _still_wanted(which):
		return
	if which != "tower":
		# each place's own music, so the game carries on from the film without a change of tune
		var place: String = set_world.map_id
		Sfx.music(GameState.main.music_for(place))
		Sfx.ambience(GameState.main.ambience_for(place))
	loading = false
	if _skip_wanted:
		_complete()
		return
	# the controls, as the scene begins (not when a preview opens part-way through it)
	if elapsed - float({"tower": 0.0, "route": DAWN, "room": ROOM}[which]) < HUD_HOLD:
		_post_hint()
	_update_frame()


## False once the film has been taken down (or moved on) while a set was building.
func _still_wanted(which: String) -> bool:
	return is_inside_tree() and not _done and _scene == which


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


func _cylinder(pos: Vector3, radius: float, height: float, mat: Material, top := -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top < 0.0 else top
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


## A pipe or cable from a to b.
func _rod(a: Vector3, b: Vector3, radius: float, colour: String) -> MeshInstance3D:
	var node := _cylinder((a + b) / 2.0, radius, a.distance_to(b), _mat(colour))
	(node.mesh as CylinderMesh).radial_segments = 10
	var along := (b - a).normalized()
	if absf(along.dot(Vector3.UP)) < 0.999:
		node.basis = Basis(Quaternion(Vector3.UP, along))
	return node


func _asset(key: String, pos: Vector3, height: float, yaw := 0.0) -> MeshInstance3D:
	var node := Assets.instance(key, height)
	node.position += pos
	node.rotation.y = yaw
	stage.add_child(node)
	return node


## One of the interior pack's pieces (room_builder.gd), standing on `pos`, scaled to `height`, turned `yaw` (its
## front faces +z at zero).
func _piece(name: String, pos: Vector3, height: float, yaw := 0.0) -> MeshInstance3D:
	var mesh := RoomBuilder.piece(name)
	if name in ["el_lamp", "table_lamp", "floor_lamp"]:
		mesh = RoomBuilder.lamp_mesh(name, absi(hash(str(pos))) % 5)
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


## A lamp hung from the ceiling (at `top`) on a cord: a dark metal shade and a glowing bulb at `at`.
func _hanging_lamp(at: Vector3, top: float, glow: String, wide := 0.42) -> void:
	_box(Vector3(at.x, (top + at.y + 0.3) / 2.0, at.z), Vector3(0.03, top - at.y - 0.3, 0.03), "#15151a")
	_cylinder(at + Vector3(0, 0.2, 0), wide, 0.26, _mat("#22242c"), 0.07)
	_cylinder(at + Vector3(0, 0.06, 0), wide * 0.72, 0.03, _mat(glow, "", true))


func _environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#070914")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#5c64a0")
	env.ambient_light_energy = 0.66
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.2
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_hdr_threshold = 1.1
	env.ssao_enabled = RenderingServer.get_current_rendering_method() != "mobile"
	env.ssao_radius = 0.65
	env.ssao_intensity = 1.5
	# a dark, tinted mist that lets the far walls fall away without hiding their shape
	env.fog_enabled = true
	env.fog_density = 0.016
	env.fog_light_color = Color("#1c1838")
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	stage.add_child(world_env)


# ================================================================ the office, by night
func _build_tower() -> void:
	_environment()
	camera = Camera3D.new()
	camera.fov = 43
	stage.add_child(camera)
	camera.make_current()
	# the moon, low behind the window wall: its light falls through the windows across the floor
	moon = DirectionalLight3D.new()
	moon.light_color = Color("#8ea6ff")
	moon.light_energy = 0.9
	moon.rotation_degrees = Vector3(-24, 168, 0)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 30.0
	stage.add_child(moon)
	_office_shell()
	_window_wall()
	_skyline()
	_office_ceiling()
	_office_walls()
	_office_furniture()
	_lift(LIFT_AT)
	_steel_door()
	_freight_room()
	# the pool of light over the rug, where the staff gather, from the big lamp hung over it
	_hanging_lamp(Vector3(2.4, 4.7, 0.8), 6.0, "#ffe2c4", 0.62)
	spot = SpotLight3D.new()
	spot.position = Vector3(2.4, 4.6, 0.8)
	spot.rotation_degrees = Vector3(-90, 0, 0)
	spot.light_color = Color("#ffe2c4")
	spot.light_energy = SPOT_E
	spot.spot_range = 8.0
	spot.spot_angle = 40.0
	spot.spot_attenuation = 0.6
	spot.shadow_enabled = true
	stage.add_child(spot)
	# Gearhart addressing his staff, the staff in a huddle before him
	_person("gear", GEAR_LOOK, GEAR_AT, Vector2i(-1, 0))
	_person("mara", ENGINEER_LOOK, STAFF_AT[0], Vector2i(1, 0))
	for i in STAFF_LOOKS.size():
		_person("staff%d" % i, STAFF_LOOKS[i], STAFF_AT[i + 1], Vector2i(1, 0))


## The floor (Gearhart's office is wood with a red rug, as when the hero comes back for the captives), the ceiling,
## and brick walls all round; the east wall has the doorway into the warehouse.
func _office_shell() -> void:
	_box(Vector3(0, -0.25, 0.5), Vector3(20.4, 0.5, 15.4), "#86705f", false, "floor_wood_2")
	# the rug: a dark border, the red field, a thin gold line inside it
	_box(Vector3(0.6, 0.012, 0.8), Vector3(8.4, 0.025, 6.6), "#5a1220", false, "floor_carpet")
	_box(Vector3(0.6, 0.017, 0.8), Vector3(7.7, 0.025, 5.9), "#8e2436", false, "floor_carpet")
	for k in 2:
		_box(Vector3(0.6, 0.031, 0.8 + (k * 2 - 1) * 2.6), Vector3(7.0, 0.004, 0.07), "#c89a4a")
		_box(Vector3(0.6 + (k * 2 - 1) * 3.5, 0.031, 0.8), Vector3(0.07, 0.004, 5.27), "#c89a4a")
	_box(Vector3(0, 6.1, 0.5), Vector3(20.4, 0.2, 15.4), "#2c2630")
	_box(Vector3(-10.1, 3.0, 0.5), Vector3(0.3, 6.0, 15.4), BRICK, false, "wall_brick")
	_box(Vector3(DOOR_X, 3.0, -2.9), Vector3(0.3, 6.0, 8.6), BRICK, false, "wall_brick")
	_box(Vector3(DOOR_X, 3.0, 6.125), Vector3(0.3, 6.0, 4.65), BRICK, false, "wall_brick")
	_box(Vector3(DOOR_X, 4.7, DOOR_Z), Vector3(0.3, 2.6, 2.4), BRICK, false, "wall_brick")
	_box(Vector3(0, 3.0, 8.3), Vector3(20.4, 6.0, 0.3), BRICK, false, "wall_brick")


## The window wall: a brick pier in the middle carrying the company's sign, two tall windows either side with
## mullions, a stone sill below and an arched brick lintel above; the city's neon beyond.
func _window_wall() -> void:
	_box(Vector3(0, 3.0, -7.15), Vector3(6.2, 6.0, 0.3), BRICK, false, "wall_brick")
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 9.6, 3.0, -7.15), Vector3(1.0, 6.0, 0.3), BRICK, false, "wall_brick")
		_box(Vector3(side * 6.1, 0.35, -7.15), Vector3(6.0, 0.7, 0.3), BRICK, false, "wall_brick")
		_box(Vector3(side * 6.1, 5.35, -7.15), Vector3(6.0, 1.3, 0.3), BRICK, false, "wall_brick")
		_box(Vector3(side * 6.1, 0.74, -7.0), Vector3(6.2, 0.1, 0.56), "#8a8490")
		_box(Vector3(side * 6.1, 4.74, -7.02), Vector3(6.2, 0.16, 0.4), "#5a4a52")
		for k in 4:
			_box(Vector3(side * (3.3 + k * 1.9), 2.7, -7.12), Vector3(0.12, 4.0, 0.14), "#1c1a22")
		for y in [1.7, 2.7, 3.7]:
			_box(Vector3(side * 6.1, y, -7.12), Vector3(6.0, 0.08, 0.12), "#1c1a22")
		# heavy curtains drawn back to the window's outer edge
		_box(Vector3(side * 8.85, 2.8, -6.86), Vector3(0.5, 4.1, 0.16), "#5a1826", false, "floor_carpet")
		_box(Vector3(side * 3.35, 2.8, -6.86), Vector3(0.5, 4.1, 0.16), "#5a1826", false, "floor_carpet")
		_box(Vector3(side * 6.1, 4.92, -6.84), Vector3(6.3, 0.12, 0.12), BRASS)
	var sign_board := CompanyBrand.sign_node(5.2)
	sign_board.position = Vector3(0, 4.3, -6.92)
	stage.add_child(sign_board)
	# two brass lamps wash the sign from below
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 1.9, 2.72, -6.86), Vector3(0.34, 0.1, 0.22), BRASS)
		_box(Vector3(side * 1.9, 2.8, -6.84), Vector3(0.24, 0.04, 0.14), "#ffd8a0", true)


## The city through the windows: two ranks of dark blocks with rows of lit windows (one shared glowing material per
## colour), warning beacons on the tallest, stars, and the moon.
func _skyline() -> void:
	for i in 22:
		var x := float(i) * 2.6 - 27.0
		var h := 5.0 + fmod(float(i * 17), 9.0)
		var z := -15.0 - fmod(float(i * 7), 10.0)
		_box(Vector3(x, h * 0.5 - 3.0, z), Vector3(2.2, h, 2.6), "#141830")
		for j in int(h * 0.8):
			if (i * 5 + j * 3) % 4 == 0:
				continue
			_box(Vector3(x, j * 1.2 - 2.4, z + 1.32), Vector3(1.5, 0.12, 0.02), "#48a4ba" if (i + j) % 3 else "#ca548f", true)
		if i % 4 == 1:
			_box(Vector3(x, h - 2.4, z), Vector3(0.08, 1.2, 0.08), "#141830")
			_box(Vector3(x, h - 1.75, z), Vector3(0.16, 0.16, 0.16), "#ff4a3a", true)
	# the far rank: taller, dimmer, a few windows lit
	for i in 16:
		var x := float(i) * 5.2 - 40.0
		var h := 14.0 + fmod(float(i * 11), 12.0)
		_box(Vector3(x, h * 0.5 - 4.0, -36.0 - fmod(float(i * 5), 8.0)), Vector3(4.2, h, 3.0), "#0e1124")
		for j in int(h * 0.35):
			if (i + j * 2) % 3:
				_box(Vector3(x + fmod(float(j * 7), 2.4) - 1.2, j * 2.4 - 1.0, -34.4 - fmod(float(i * 5), 8.0)), Vector3(0.9, 0.2, 0.02), "#3a6a8a", true)
	for i in 46:
		_box(Vector3(sin(i * 12.9) * 46.0, 9.0 + fmod(float(i * 37), 24.0), -58.0), Vector3.ONE * (0.1 + 0.08 * (i % 3)), "#c8d4ff", true)
	var disc := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 2.6
	sphere.height = 5.2
	disc.mesh = sphere
	disc.material_override = _mat("#c8d4ff", "", true)
	disc.position = Vector3(-9.0, 13.0, -42.0)
	stage.add_child(disc)


## Timber beams under the ceiling on two steel joists, copper pipes along the west wall, and the hanging lamps.
func _office_ceiling() -> void:
	for i in 6:
		_box(Vector3(0, 5.78, -5.6 + i * 2.5), Vector3(20.0, 0.4, 0.32), BEAM, false, "furniture_wood")
	for x in [-5.2, 5.2]:
		_box(Vector3(x, 5.5, 0.5), Vector3(0.26, 0.24, 15.0), "#2c2e36")
	_rod(Vector3(-9.72, 5.2, -6.9), Vector3(-9.72, 5.2, 8.1), 0.09, "#a8623a")
	_rod(Vector3(-9.74, 4.94, -6.9), Vector3(-9.74, 4.94, 8.1), 0.05, "#8a8e98")
	_rod(Vector3(-9.72, 5.2, 7.6), Vector3(-9.72, 0.0, 7.6), 0.09, "#a8623a")
	for z in [-4.4, 0.4, 5.6]:
		_box(Vector3(-9.72, 5.2, z), Vector3(0.24, 0.24, 0.1), "#6a4a34")
	for at in [Vector3(-3.6, 4.3, 3.4), Vector3(-3.6, 4.3, -2.4), Vector3(7.2, 4.3, -1.2)]:
		_hanging_lamp(at, 6.0, "#ffd9a8")
		hang_lamps.append(_lamp(at - Vector3(0, 0.3, 0), "#ffc890", HANG_E, 7.5))


## Dark wood panelling to waist height round the room, brick piers with a lit sconce on each, and the west wall's
## turning brass gears.
func _office_walls() -> void:
	# [centre, length] along z for the side walls, along x for the front wall (clear of the doorway and the lift)
	for run in [[-9.9, 0.5, 15.0, true], [9.9, -2.95, 8.3, true], [9.9, 6.0, 4.4, true], [-3.5, 8.1, 13.0, false], [8.3, 8.1, 3.4, false]]:
		var along_z: bool = run[3]
		var at := Vector3(run[0], 0.62, run[1])
		var size := Vector3(0.14, 1.24, run[2]) if along_z else Vector3(run[2], 1.24, 0.14)
		_box(at, size, PANEL, false, "furniture_wood")
		_box(at + Vector3(0, 0.66, 0), size * Vector3(1.6, 0.07, 1.0) if along_z else size * Vector3(1.0, 0.07, 1.6), "#6a4634")
	for side in [-1.0, 1.0]:
		for z in [-4.7, 0.2, 5.9] if side < 0 else [-4.7, -0.3]:
			_box(Vector3(side * 9.78, 3.0, z), Vector3(0.5, 6.0, 0.8), "#6c5860", false, "wall_brick")
			_box(Vector3(side * 9.46, 2.75, z), Vector3(0.14, 0.42, 0.2), BRASS)
			_box(Vector3(side * 9.36, 2.86, z), Vector3(0.16, 0.22, 0.16), "#ffd0a0", true)
	# three gears in mesh on the west wall, their teeth turning into one another
	_gear(Vector3(-9.82, 3.55, 2.2), 1.3, 14, 0.32)
	_gear(Vector3(-9.82, 4.5, 4.05), 0.8, 9, -0.52)
	_gear(Vector3(-9.82, 3.55, 4.95), 0.5, 6, 0.83)


## A brass gear on the west wall, turning about its axle at `speed` (see _tower_frame).
func _gear(at: Vector3, radius: float, teeth: int, speed: float) -> void:
	var spin := Node3D.new()
	spin.position = at
	spin.set_meta("speed", speed)
	stage.add_child(spin)
	gears.append(spin)
	# built flat round its own axis, then stood against the wall
	var flat := Node3D.new()
	flat.rotation.z = PI / 2.0
	spin.add_child(flat)
	var parts := [
		[radius * 0.9, 0.1, BRASS], [radius * 0.66, 0.13, "#3a2c24"], [radius * 0.24, 0.22, "#e0b060"],
	]
	for part in parts:
		var disc := _cylinder(Vector3.ZERO, part[0], part[1], _mat(part[2]))
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		stage.remove_child(disc)
		flat.add_child(disc)
	for i in teeth:
		var tooth := _box(Vector3.ZERO, Vector3(radius * 0.26, 0.1, radius * 0.24), BRASS)
		stage.remove_child(tooth)
		flat.add_child(tooth)
		tooth.rotation.y = TAU * i / teeth
		tooth.position = Vector3(cos(-tooth.rotation.y), 0, sin(-tooth.rotation.y)) * radius * 0.96
	for i in 3:
		var spoke := _box(Vector3.ZERO, Vector3(radius * 1.3, 0.16, radius * 0.13), BRASS)
		stage.remove_child(spoke)
		flat.add_child(spoke)
		spoke.rotation.y = PI * i / 3.0


## Gearhart's desk before the sign, his new robots lined up on lit plinths before the windows, books, a drafting
## table, and crates of "freight" under neon along the sides (clear of the staff's way to the lift and of Gearhart's
## to the steel door).
func _office_furniture() -> void:
	_box(Vector3(0, 0.5, -4.7), Vector3(3.6, 1.0, 1.2), "#4a2e22", false, "furniture_wood")
	_box(Vector3(0, 1.04, -4.7), Vector3(3.8, 0.08, 1.35), "#6a4430", false, "furniture_wood")
	_box(Vector3(0, 0.5, -4.08), Vector3(3.0, 0.7, 0.04), "#5c3a2a", false, "furniture_wood")
	_piece("el_monitor", Vector3(-0.9, 1.08, -4.85), 0.5)
	_piece("el_lamp", Vector3(1.25, 1.08, -4.9), 0.55)
	_piece("globe", Vector3(0.5, 1.08, -4.95), 0.4)
	_piece("phone_rotary", Vector3(-1.5, 1.08, -4.5), 0.2)
	_piece("books", Vector3(1.55, 1.08, -4.35), 0.24, 0.5)
	desk_lamp = _lamp(Vector3(1.25, 1.7, -4.6), "#ffb870", DESK_E, 4.5)
	_piece("chair_slat", Vector3(0, 0, -5.8), 1.1)
	for side in [-1.0, 1.0]:
		_asset("robot_golem", Vector3(side * 3.2, 0, -5.0), 2.6, -side * 0.35)
		_piece("plant_tall", Vector3(side * 2.3, 0, -6.4), 1.5)
		# the new freight robots, a pair either side, each on a plinth edged in light
		for k in 2:
			var at := Vector3(side * (5.6 + k * 2.1), 0, -5.7)
			_box(at + Vector3(0, 0.14, 0), Vector3(1.3, 0.28, 1.3), "#2e323c")
			_box(at + Vector3(0, 0.2, 0.66), Vector3(1.1, 0.06, 0.03), "#60bdca", true)
			_asset(["robot_clockwork", "robot_steam", "robot_walker", "robot_clockwork"][k + (2 if side > 0 else 0)], at + Vector3(0, 0.28, 0), 1.9, -side * 0.25)
		for z in [-2.7, -1.4]:
			_piece("bookshelf", Vector3(side * 9.45, 0, z), 2.5, -side * PI / 2)
	# the drafting table by the east wall, a blueprint pinned to it under a lamp, and the filing drawers
	_piece("table_trestle", Vector3(7.7, 0, -3.3), 0.95, PI / 2)
	_box(Vector3(7.7, 0.975, -3.3), Vector3(0.7, 0.012, 1.2), "#3a70b8")
	for k in 3:
		_box(Vector3(7.5 + k * 0.2, 0.983, -3.3), Vector3(0.02, 0.004, 1.0), "#cfe2ff")
	_piece("el_lamp", Vector3(7.95, 0.97, -3.85), 0.5)
	_piece("dresser", Vector3(9.5, 0, 0.75), 1.25, -PI / 2)
	_piece("coat_stand", Vector3(2.7, 0, 7.6), 1.9)
	_piece("plant_tall", Vector3(7.4, 0, 7.5), 1.6)
	_piece("armchair_club", Vector3(-8.3, 0, -5.4), 1.05, 0.9)
	_piece("floor_lamp", Vector3(-9.1, 0, -6.3), 1.8)
	for at in [Vector3(-7.6, 0, 2.6), Vector3(8.5, 0, 6.6)]:
		var west: bool = at.x < 0
		_asset("crates", at, 1.4, 0.4 if west else -0.3)
		_asset("crates", at + Vector3(-1.2 if west else 0.2, 0, -1.5 if west else -1.6), 1.0, 1.1)
		_asset("barrel", at + Vector3(0.5 if west else -1.3, 0, 1.6 if west else 0.5), 0.9)
		cage_lamps.append(_lamp(at + Vector3(0, 2.4, 0), "#d75a9c", CAGE_E, 4.5))
		_box(at + Vector3(-1.9 if west else 1.25, 2.3, 0), Vector3(0.05, 0.08, 1.6), "#f07ab4", true)


## The steel door into the warehouse, shut in the east wall's doorway (it slides north into the wall to open) in
## a heavy steel frame, hazard stripes over it, a red lamp, and the light from the room beyond to spill through
## once it's open.
func _steel_door() -> void:
	door_panel = _box(Vector3(DOOR_X, 1.7, DOOR_Z), Vector3(0.12, 3.4, 2.4), "#5a6070")
	for k in 3:
		var rib := _box(Vector3(-0.07, -0.9 + k * 0.9, 0), Vector3(0.04, 0.1, 2.2), "#3c414e")
		stage.remove_child(rib)
		door_panel.add_child(rib)
	for side in [-1.0, 1.0]:
		_box(Vector3(DOOR_X - 0.1, 1.75, DOOR_Z + side * 1.3), Vector3(0.36, 3.5, 0.22), "#2e323c")
	_box(Vector3(DOOR_X - 0.1, 3.5, DOOR_Z), Vector3(0.36, 0.22, 2.82), "#2e323c")
	for k in 5:
		var stripe := _box(Vector3(DOOR_X - 0.3, 3.5, DOOR_Z - 1.0 + k * 0.5), Vector3(0.06, 0.2, 0.22), "#e0b020" if k % 2 == 0 else "#202020")
		stripe.rotation.x = 0.5
	_box(Vector3(DOOR_X - 0.2, 3.95, DOOR_Z), Vector3(0.12, 0.18, 0.5), "#ff5a3a", true)
	door_light = _lamp(Vector3(DOOR_X + 1.2, 2.2, DOOR_Z), "#fff0dc", 0.0, 5.5)


## The freight warehouse behind the office (after a plain low-poly warehouse the user supplied as a reference): a
## long concrete shed under a steel truss roof, a band of factory windows high in each long wall, a roller door in
## its far end, and hard white lamps hung low over the aisle. Rusted iron cages stand either side of the aisle, a
## trainer in each; across the far end their beasts sit in smaller cages on pallets. The game's own crates, barrels,
## racks and boxes fill the rest, with shipping containers along the walls.
func _freight_room() -> void:
	var mid := (DOOR_X + ROOM_END) / 2.0
	var span := ROOM_END - DOOR_X
	_box(Vector3(mid, -0.25, DOOR_Z), Vector3(span, 0.5, HALF * 2.0 + 0.6), "#7a7b7e", false, "floor_stone")
	_warehouse_shell(mid, span)
	_warehouse_roof(mid, span)
	# painted lines down either edge of the aisle, worn yellow
	for side in [-1.0, 1.0]:
		_box(Vector3((DOOR_X + TUBE_X) / 2.0, 0.006, DOOR_Z + side * 1.42), Vector3(TUBE_X - DOOR_X - 1.6, 0.012, 0.14), "#c8a030")
	# the cages, and who's in them: [cell, look, pose, how far they reach for the bars]
	var cells := []
	for side in [-1.0, 1.0]:
		for x in CELL_XS:
			cells.append(Vector3(x, 0, DOOR_Z + side * CELL_Z))
	for at in cells:
		_cage(at, 1.15)
	var who := [
		[2, TrainerCell.LOOKS[1], "", 0.75], [0, TrainerCell.LOOKS[0], "kneel", 0.0], [4, TrainerCell.LOOKS[2], "", 0.5],
		[1, CAPTIVE_LOOKS[0], "kneel", 0.0], [3, CAPTIVE_LOOKS[1], "", 0.0], [5, CAPTIVE_LOOKS[2], "kneel", 0.0],
	]
	for i in who.size():
		var cell: Vector3 = cells[who[i][0]]
		var front := -signf(cell.z - DOOR_Z)
		var standing: bool = String(who[i][2]) == ""
		var at := cell + Vector3(0.3 * (1 if i % 2 else -1), 0.09, front * (0.8 if standing else 0.2))
		var captive := _person("captive%d" % i, who[i][1], at, Vector2i(0, int(front)))
		Person.set_pose(captive, who[i][2], 0.36, true)
		Person.set_reach(captive, who[i][3])
	# the beasts, each in a small cage on a pallet: Embit, Clawlet, Tadlet, Grubbit, Berrypuff, the captives' partners
	var races := [0, 24, 27, 12, 36]
	for i in TUBE_ZS.size():
		_beast_crate(Vector3(TUBE_X, 0, TUBE_ZS[i]), races[i])
	_warehouse_goods()
	# Soft white pools from the lamps hung over the aisle, and one over the beasts; all off until the
	# door opens. Shadows from every lamp only off the phone renderer, where one keeps the bars' shadows on the floor.
	var phone := RenderingServer.get_current_rendering_method() == "mobile"
	var hung := []
	for x in CELL_XS:
		hung.append(Vector3(x, 4.5, DOOR_Z))
	hung.append(Vector3(TUBE_X - 0.5, 4.5, DOOR_Z))
	for i in hung.size():
		var at: Vector3 = hung[i]
		_hanging_lamp(at, RIDGE - 0.2, "#fff6e0", 0.55)
		var lamp := SpotLight3D.new()
		lamp.position = at
		lamp.rotation_degrees = Vector3(-90, 0, 0)
		lamp.light_color = Color("#fff4e2")
		lamp.light_energy = ROOM_E
		lamp.spot_range = 7.0
		lamp.spot_angle = 44.0
		lamp.spot_attenuation = 0.5
		lamp.spot_angle_attenuation = 0.35
		lamp.shadow_enabled = not phone or i == 1
		stage.add_child(lamp)
		room_lamps.append(lamp)
		# the beam itself, faint in the dusty air
		var beam := _cylinder(Vector3(at.x, at.y / 2.0, at.z), 2.6, at.y, _beam_material(), 0.35)
		room_beams.append(beam)


## The warehouse's walls: concrete with a dark painted band along the bottom, a row of factory windows high in each
## long wall (dark frames, the night's blue behind the panes), a skin over the office's brick round the steel door,
## the roller door in the far end, and the gable over each end.
func _warehouse_shell(mid: float, span: float) -> void:
	for side in [-1.0, 1.0]:
		var wall_z: float = DOOR_Z + side * (HALF + 0.15)
		var face: float = wall_z - side * 0.16
		_box(Vector3(mid, EAVE / 2.0, wall_z), Vector3(span, EAVE, 0.3), CONCRETE, false, "wall_plaster")
		_box(Vector3(mid, 0.7, face), Vector3(span, 1.4, 0.03), "#56605c")
		_box(Vector3(mid, 1.43, face), Vector3(span, 0.07, 0.04), "#c8a030")
		for k in 5:
			var x := DOOR_X + 2.0 + k * 3.45
			_box(Vector3(x, 3.75, face), Vector3(2.5, 1.7, 0.06), "#22252b")
			_box(Vector3(x, 3.75, face - side * 0.03), Vector3(2.3, 1.5, 0.02), "#111a2e", true)
			for j in [-0.58, 0.0, 0.58]:
				_box(Vector3(x + j, 3.75, face - side * 0.05), Vector3(0.05, 1.5, 0.03), "#22252b")
			_box(Vector3(x, 3.75, face - side * 0.05), Vector3(2.3, 0.05, 0.03), "#22252b")
			_box(Vector3(x, 2.86, face - side * 0.06), Vector3(2.6, 0.08, 0.14), "#8c8a86")
		# buttresses between the windows, to give the long walls some depth
		for k in 6:
			_box(Vector3(DOOR_X + 0.28 + k * 3.45, EAVE / 2.0, face - side * 0.1), Vector3(0.45, EAVE, 0.22), "#96948e", false, "wall_plaster")
	# the office's side: concrete over the brick, round the steel door
	var skin := DOOR_X + 0.2
	_box(Vector3(skin, EAVE / 2.0, (DOOR_Z - HALF + DOOR_Z - 1.2) / 2.0), Vector3(0.12, EAVE, HALF - 1.2), CONCRETE, false, "wall_plaster")
	_box(Vector3(skin, EAVE / 2.0, (DOOR_Z + HALF + DOOR_Z + 1.2) / 2.0), Vector3(0.12, EAVE, HALF - 1.2), CONCRETE, false, "wall_plaster")
	_box(Vector3(skin, (EAVE + 3.4) / 2.0, DOOR_Z), Vector3(0.12, EAVE - 3.4, 2.4), CONCRETE, false, "wall_plaster")
	_box(Vector3(DOOR_X + 0.28, 3.95, DOOR_Z), Vector3(0.12, 0.18, 0.5), "#ff5a3a", true)
	# the far end, and its roller door between hazard-striped posts
	_box(Vector3(ROOM_END, EAVE / 2.0, DOOR_Z), Vector3(0.3, EAVE, HALF * 2.0 + 0.6), CONCRETE, false, "wall_plaster")
	_box(Vector3(ROOM_END - 0.18, 1.9, DOOR_Z), Vector3(0.08, 3.8, 4.6), "#6c727a")
	for k in 12:
		_box(Vector3(ROOM_END - 0.24, 0.2 + k * 0.31, DOOR_Z), Vector3(0.04, 0.05, 4.6), "#50555e")
	for side in [-1.0, 1.0]:
		_box(Vector3(ROOM_END - 0.24, 1.95, DOOR_Z + side * 2.45), Vector3(0.2, 3.9, 0.3), "#2e323c")
		for k in 6:
			_box(Vector3(ROOM_END - 0.35, 0.3 + k * 0.6, DOOR_Z + side * 2.45), Vector3(0.03, 0.3, 0.31), "#e0b020")
	_box(Vector3(ROOM_END - 0.24, 3.92, DOOR_Z), Vector3(0.2, 0.24, 5.2), "#2e323c")
	for x in [DOOR_X + 0.2, ROOM_END]:
		var gable := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(HALF * 2.0 + 0.6, RIDGE - EAVE + 0.1, 0.3 if x == ROOM_END else 0.12)
		gable.mesh = prism
		gable.material_override = _mat(CONCRETE, "wall_plaster")
		gable.rotation.y = PI / 2.0
		gable.position = Vector3(x, EAVE + (RIDGE - EAVE + 0.1) / 2.0, DOOR_Z)
		stage.add_child(gable)


## The roof: two slopes of dark sheet on purlins, carried by a steel truss every few steps down the shed.
func _warehouse_roof(mid: float, span: float) -> void:
	var rise := RIDGE - EAVE
	var pitch := atan2(rise, HALF + 0.3)
	var slope := Vector2(HALF + 0.3, rise).length()
	for side in [-1.0, 1.0]:
		var sheet := _box(Vector3(mid, (EAVE + RIDGE) / 2.0 + 0.12, DOOR_Z + side * (HALF + 0.3) / 2.0), Vector3(span + 0.4, 0.12, slope + 0.2), "#3a4046")
		sheet.rotation.x = side * pitch
		for f in [0.2, 0.5, 0.8]:
			_rod(Vector3(DOOR_X + 0.3, RIDGE - rise * f - 0.02, DOOR_Z + side * (HALF + 0.3) * f), Vector3(ROOM_END - 0.2, RIDGE - rise * f - 0.02, DOOR_Z + side * (HALF + 0.3) * f), 0.05, "#4a5058")
	for k in 6:
		var x := DOOR_X + 1.2 + k * 3.1
		_rod(Vector3(x, EAVE, DOOR_Z - HALF), Vector3(x, EAVE, DOOR_Z + HALF), 0.07, STEEL)
		_rod(Vector3(x, EAVE, DOOR_Z), Vector3(x, RIDGE - 0.12, DOOR_Z), 0.05, STEEL)
		for side in [-1.0, 1.0]:
			_rod(Vector3(x, EAVE, DOOR_Z + side * HALF), Vector3(x, RIDGE - 0.12, DOOR_Z), 0.07, STEEL)
			_rod(Vector3(x, EAVE, DOOR_Z), Vector3(x, EAVE + rise * 0.5 - 0.1, DOOR_Z + side * HALF * 0.5), 0.045, STEEL)
			_rod(Vector3(x, EAVE, DOOR_Z + side * HALF * 0.5), Vector3(x, EAVE + rise * 0.5 - 0.1, DOOR_Z + side * HALF * 0.5), 0.045, STEEL)


## What the warehouse holds, all from the game's own props: shipping containers and steel racks along the long walls
## behind the cages, stacks of crates and barrels, pallets of boxes, and the odds and ends by the door.
func _warehouse_goods() -> void:
	var north := DOOR_Z - HALF
	var south := DOOR_Z + HALF
	_container(Vector3(19.2, 0, north + 1.5), "#b65a30", 0.0)
	_container(Vector3(19.6, 2.5, north + 1.55), "#3f6470", 0.04)
	_container(Vector3(13.2, 0, south - 1.5), "#44566e", 0.0)
	_container(Vector3(25.6, 0, south - 2.7), "#8a8f55", PI / 2.0)
	# steel racks on the north wall, stocked with boxes
	for k in 3:
		var x := 11.4 + k * 1.75
		_piece("shelves_metal", Vector3(x, 0, north + 0.6), 2.5)
		for shelf in [0.75, 1.5]:
			_piece(["box_1", "box_2", "box_3"][k], Vector3(x - 0.3, shelf, north + 0.6), 0.42, 0.3 * k)
			_piece(["box_3", "box_1", "box_2"][k], Vector3(x + 0.35, shelf, north + 0.62), 0.36, -0.2 * k)
	# crates, barrels and pallets of boxes
	for goods in [[Vector3(18.6, 0, south - 1.3), 1.5, 0.3], [Vector3(20.4, 0, south - 1.1), 1.1, -0.5], [Vector3(25.8, 0, north + 1.3), 1.6, 0.9],
			[Vector3(24.6, 0, north + 3.0), 1.1, 0.2], [Vector3(11.2, 0, south - 4.6), 1.2, 0.0]]:
		_asset("crates", goods[0], goods[1], goods[2])
	for at in [Vector3(22.2, 0, south - 0.9), Vector3(23.1, 0, south - 1.0), Vector3(22.7, 0, south - 1.8), Vector3(11.0, 0, north + 3.2), Vector3(26.9, 0, north + 4.4)]:
		_asset("barrel", at, 1.0)
	for k in 3:
		var at := Vector3(24.8 + k * 0.1, 0, south - 5.2 - k * 1.5) if k < 2 else Vector3(16.9, 0, north + 0.9)
		_piece("pallet", at, 0.16, 0.2 * k)
		_piece("box_2", at + Vector3(-0.25, 0.16, 0.1), 0.6, 0.2)
		_piece("box_1", at + Vector3(0.3, 0.16, -0.15), 0.5, -0.3)
		_piece("box_3", at + Vector3(0.0, 0.7, 0.0), 0.4, 0.5)
	_piece("breaker_box", Vector3(DOOR_X + 0.34, 1.3, DOOR_Z + 2.2), 0.6, PI / 2.0)
	_piece("ladder", Vector3(17.6, 0, DOOR_Z - HALF + 0.5), 2.6)
	_piece("broom", Vector3(DOOR_X + 0.5, 0, DOOR_Z + 3.4), 1.4, PI / 2.0)
	_piece("bucket", Vector3(DOOR_X + 0.9, 0, DOOR_Z + 3.9), 0.36)


## A shipping container, its long side along x (turned `yaw`), standing on `at`: a ribbed steel box in one painted
## colour, darker frame rails, and doors with locking bars at one end.
func _container(at: Vector3, colour: String, yaw: float) -> void:
	var box := Node3D.new()
	box.position = at
	box.rotation.y = yaw
	stage.add_child(box)
	var dark := Color(colour).darkened(0.35).to_html(false)
	var parts := [_box(Vector3(0, 1.25, 0), Vector3(5.6, 2.5, 2.3), colour)]
	for k in 18:
		for side in [-1.0, 1.0]:
			parts.append(_box(Vector3(-2.55 + k * 0.3, 1.25, side * 1.16), Vector3(0.12, 2.2, 0.04), "#" + dark))
	for y in [0.07, 2.43]:
		for side in [-1.0, 1.0]:
			parts.append(_box(Vector3(0, y, side * 1.16), Vector3(5.66, 0.16, 0.08), "#" + dark))
	for side in [-1.0, 1.0]:
		parts.append(_box(Vector3(2.82, 1.25, side * 0.3), Vector3(0.04, 2.2, 0.06), "#8a8e96"))
		parts.append(_box(Vector3(2.82, 1.25, side * 0.85), Vector3(0.04, 2.2, 0.06), "#8a8e96"))
	parts.append(_box(Vector3(2.81, 1.25, 0), Vector3(0.03, 2.3, 0.04), "#" + dark))
	for part in parts:
		stage.remove_child(part)
		box.add_child(part)


## One of the rusted iron cages (assets/props/iron_cage.res, tools/import_iron_cage.gd), standing on `at`.
func _cage(at: Vector3, size: float) -> MeshInstance3D:
	var cage := MeshInstance3D.new()
	cage.mesh = load(CAGE)
	if not _mats.has("cage"):
		# the pack's rusted iron, deepened to dark, warm metal under the hard lamps
		var iron := (cage.mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
		iron.albedo_color = Color("#8e7b70")
		_mats["cage"] = iron
	cage.material_override = _mats["cage"]
	cage.scale = Vector3.ONE * size
	cage.position = at
	stage.add_child(cage)
	return cage


## A captured beast in a small iron cage on a pallet, turned to the aisle.
func _beast_crate(at: Vector3, race: int) -> void:
	_piece("pallet", at, 0.16)
	_cage(at + Vector3(0, 0.16, 0), 0.62)
	var beast = BeastModel.rig(RaceDB.genes(race), 1.0)
	if beast != null:
		var bb: AABB = BeastModel.bounds(beast)
		var fit := 0.72 / maxf(0.01, maxf(bb.size.y, maxf(bb.size.x, bb.size.z)))
		beast.scale *= fit
		beast.rotation.y = -PI / 2.0
		beast.position = at + Vector3(0, 0.22 - bb.position.y * beast.scale.y, 0)
		stage.add_child(beast)
		crated.append(beast)


## The faint cone of a hanging lamp's beam in the air: brighter looked through from the side, never solid.
func _beam_material() -> StandardMaterial3D:
	if _mats.has("beam"):
		return _mats["beam"]
	var beam := StandardMaterial3D.new()
	beam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Compatibility's additive blend adds the full RGB even with a tiny alpha, washing out the room.
	# Alpha blending keeps the dust faint on both web and Mobile without hiding the captives.
	beam.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	beam.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.albedo_color = Color(1.0, 0.96, 0.86, 0.006)
	_mats["beam"] = beam
	return beam


## The freight lift's doors in the front wall: steel in a heavy frame, hazard stripes over them, a lamp above.
func _lift(at: Vector3) -> void:
	_box(at + Vector3(0, 1.6, 0), Vector3(3.0, 3.2, 0.12), "#5a6070")
	_box(at + Vector3(0, 1.6, -0.02), Vector3(0.05, 3.1, 0.12), "#2a2e38")
	for side in [-1.0, 1.0]:
		_box(at + Vector3(side * 1.6, 1.7, -0.06), Vector3(0.22, 3.4, 0.3), "#2e323c")
	_box(at + Vector3(0, 3.32, -0.06), Vector3(3.42, 0.2, 0.3), "#2e323c")
	for k in 7:
		var stripe := _box(at + Vector3(-1.4 + k * 0.47, 3.6, -0.06), Vector3(0.22, 0.24, 0.06), "#e0b020" if k % 2 == 0 else "#202020")
		stripe.rotation.z = 0.5
	_box(at + Vector3(0, 3.95, -0.08), Vector3(0.5, 0.18, 0.12), "#ff5a3a", true)
	_box(at + Vector3(1.95, 1.3, -0.08), Vector3(0.2, 0.3, 0.06), "#2e323c")
	_box(at + Vector3(1.95, 1.36, -0.12), Vector3(0.08, 0.08, 0.02), "#7ad890", true)


# ================================================================ spring: the real places as sets
## The Coastal Path at dawn, as the world built it: the open shoulder inside its western bend. The wild beasts are
## out of the grass beside the trail, and two early risers are there to say what's going on: Camper Tilly and Scout
## Bram, come out from his gate. The world's own camera films
## it, so whatever it builds for a view is built for the film's.
func _dress_route() -> void:
	camera = set_world.cam
	set_world.player.visible = false
	for npc in set_world.npcs.values():
		var node: Node3D = npc.get("node", null)
		if is_instance_valid(node):
			node.visible = false
	var tilly_look: Dictionary = WorldDB.LESSON_TRAINERS[0]["look"]
	_person("tilly", tilly_look, _ground(TILLY_AT), Vector2i(0, 1))
	_person("bram", Story.GUARD_LOOK, _ground(BRAM_AT), Vector2i(0, 1))
	# a Grubbit out of the tall grass, an Embit sunning itself by the trail, a Berrypuff at the grass's edge, two flyers
	_beast(12, BURROW, 1.3)
	_beast(0, Vector3(18.5, 0, 6.3), 1.2, 0.9)
	_beast(36, Vector3(15.6, 0, 8.0), 1.1, 0.4)
	_beast(30, FLYERS_AT + Vector3(-0.8, 2.6, 0), 1.1)
	_beast(30, FLYERS_AT + Vector3(0.8, 3.0, -1.0), 1.0)
	# everything any view shows, standing before the scene comes up
	for shot in ["spring", "neighbours", "beasts", "egg"]:
		for p in [0.0, 1.0]:
			_camera_shot(shot, p)
			for i in 40:
				set_world._fade_buildings(10.0, 99)
				if set_world.visible_buildings_ready():
					break
				await get_tree().process_frame
				if not is_instance_valid(set_world):
					return


## A beast on the route at `at` (in its tiles; its y above the ground there).
func _beast(race: int, at: Vector3, size := 1.0, yaw := 0.0) -> void:
	var beast = BeastModel.rig(RaceDB.genes(race), size)
	stage.add_child(beast)
	beast.position = _ground(at)
	beast.rotation.y = yaw
	beasts.append(beast)


## The spot `at` on the route, standing on the ground there (its y is how far above it).
func _ground(at: Vector3) -> Vector3:
	var ground: Vector3 = set_world.tile_pos(Vector2i(floori(at.x), floori(at.z)))
	return Vector3(at.x, ground.y + at.y, at.z)


## The hero's own bedroom, as the world built it, on the first morning: the hero up beside the bed (the world's own
## figure of them, as the character creator made them), the sun through the windows.
func _dress_room() -> void:
	camera = set_world.cam
	var hero: Node3D = set_world.player
	hero.position = set_world.tile_pos(set_world.map["spawns"]["wake"])
	Person.face(hero, Vector2i(0, 1))
	people["hero"] = hero
	# the view the game opens on, for the film to settle into
	set_world.cam_free = false
	set_world.cam_target = hero.position
	set_world._place_camera(true)
	_home_view = camera.transform
	_home_fov = camera.fov
	set_world.cam_free = true
	# morning sun through each window in the back wall: a warm glow, and shafts slanting down to the floor
	var w: int = set_world.map["w"]
	var shafts := SurfaceTool.new()
	shafts.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lit := false
	for x in w:
		if not _is_window(x):
			continue
		lit = true
		var left := x + 0.14
		var right := x + 0.86
		var top := Color(1.0, 0.86, 0.56, 0.2)
		var low := Color(1.0, 0.86, 0.56, 0.0)
		# each side of the shaft, and the patch of sun it lays on the floor
		for edge in [left, right]:
			_quad(shafts, [Vector3(edge, 2.0, 1.02), Vector3(edge, 0.9, 1.02), Vector3(edge + 0.34, 0.03, 1.9), Vector3(edge + 0.74, 0.03, 2.9)], [top, top, low, low])
		_quad(shafts, [Vector3(left, 2.0, 1.02), Vector3(right, 2.0, 1.02), Vector3(right + 0.74, 0.03, 2.9), Vector3(left + 0.74, 0.03, 2.9)], [top, top, low, low])
		var sun := Color(1.0, 0.82, 0.5, 0.22)
		_quad(shafts, [Vector3(left + 0.34, 0.03, 1.9), Vector3(right + 0.34, 0.03, 1.9), Vector3(right + 0.74, 0.03, 2.9), Vector3(left + 0.74, 0.03, 2.9)], [sun, sun, sun, sun])
		_lamp(Vector3(x + 0.5, 1.7, 1.6), "#ffd09a", 0.9, 4.0)
	if lit:
		var beams := MeshInstance3D.new()
		beams.mesh = shafts.commit()
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.vertex_color_use_as_albedo = true
		glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		glow.cull_mode = BaseMaterial3D.CULL_DISABLED
		beams.material_override = glow
		beams.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stage.add_child(beams)


## True if the bedroom's back wall has a window over tile column x.
func _is_window(x: int) -> bool:
	return MapGen.get_t(set_world.map, x, 0) == MapGen.IWINDOW


func _quad(st: SurfaceTool, points: Array, colours: Array) -> void:
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_color(colours[i])
		st.add_vertex(points[i])


# ================================================================ cameras
## Speakers stand in the lower half of each view, the set above them: their speech bubbles fit over their heads.
func _camera_shot(shot: String, progress: float) -> void:
	if not is_instance_valid(camera):
		return
	var pos := Vector3.ZERO
	var target := Vector3.ZERO
	match shot:
		"wide":
			pos = Vector3(-7.4, 4.9, 7.4).lerp(Vector3(-6.2, 4.2, 6.4), progress)
			target = Vector3(1.6, 1.6, -1.6)
		"gear":
			# past the staff's shoulders, on Gearhart, the steel door behind him
			pos = Vector3(-1.4, 2.0, 2.9).lerp(Vector3(-1.0, 1.95, 2.7), progress)
			target = GEAR_AT + Vector3(0, 2.0, -0.2)
		"staff":
			# over Gearhart's shoulder, on Mara and the others, the gears turning behind them
			pos = Vector3(6.6, 2.0, -1.7).lerp(Vector3(6.2, 1.95, -1.5), progress)
			target = Vector3(1.3, 2.0, 0.9)
		"plan":
			# from the front of the room: the briefing under the lamp, the sign and the city behind
			pos = Vector3(1.0, 2.3, 7.6).lerp(Vector3(1.6, 2.2, 7.0), progress)
			target = Vector3(3.2, 2.5, -2.0)
		"leave":
			# from by the desk, as the staff file out to the lift
			pos = Vector3(-2.6, 2.5, -3.2).lerp(Vector3(-2.0, 2.4, -3.0), progress)
			target = Vector3(4.4, 1.9, 3.2)
		"door":
			# from behind, as he walks to the steel door and it slides open
			pos = Vector3(3.2, 2.8, 7.2).lerp(Vector3(4.4, 2.7, 7.0), progress)
			target = Vector3(8.6, 2.0, 2.2)
		"reveal":
			# from among the cages, back down the aisle to the door as he steps through
			pos = Vector3(21.8, 2.3, 2.9).lerp(Vector3(21.4, 2.25, 2.9), progress)
			target = Vector3(15.0, 2.0, 1.2)
		"crates":
			# over the beasts' cages, as he comes down the aisle to them
			pos = Vector3(24.8, 2.6, 1.4).lerp(Vector3(24.6, 2.55, 1.5), progress)
			target = Vector3(17.0, 1.9, 2.7)
		"cages":
			# high from by the door: the whole warehouse, the cages down the aisle, the beasts beyond
			pos = Vector3(10.7, 4.1, 2.2).lerp(Vector3(11.3, 3.9, 2.3), progress)
			target = Vector3(19.5, 0.9, 2.7)
		"spring":
			camera.fov = 40.0
			pos = Vector3(18.4, 7.4, 17.0).lerp(Vector3(18.0, 6.4, 15.5), progress)
			target = Vector3(17.8, 0.9, 7.5)
		"neighbours":
			camera.fov = 36.0
			pos = Vector3(18.0, 3.6, 14.7).lerp(Vector3(18.2, 3.4, 14.3), progress)
			target = Vector3(18.7, 1.8, 8.4)
		"beasts":
			# A three-quarter view across the lawn, still facing the inland woods rather than the west exit.
			camera.fov = 40.0
			pos = Vector3(20.8, 4.3, 15.2).lerp(Vector3(20.5, 4.1, 14.9), progress)
			target = Vector3(17.8, 1.4, 7.7)
		"egg":
			camera.fov = 36.0
			pos = Vector3(17.2, 3.5, 14.5).lerp(Vector3(17.4, 3.3, 14.1), progress)
			target = Vector3(18.5, 1.8, 8.4)
		# (the bedroom is a stage room, open at the front with nothing over its walls: long lenses from out front
		# look down into it without seeing past them)
		"hero":
			camera.fov = 24.0
			pos = Vector3(5.0, 4.8, 9.8).lerp(Vector3(4.8, 4.7, 9.4), progress)
			target = Vector3(4.2, 1.3, 2.5)
		"mom":
			# across the room to the bedroom door, and the voice from downstairs
			camera.fov = 26.0
			pos = Vector3(3.0, 4.9, 10.5).lerp(Vector3(3.3, 4.8, 10.3), progress)
			target = Vector3(6.0, 0.8, 2.6)
		"joke":
			camera.fov = 20.0
			pos = Vector3(4.0, 4.4, 9.4).lerp(Vector3(3.9, 4.3, 9.1), progress)
			target = Vector3(3.7, 1.3, 2.5)
		"home":
			# back and up, into the view the game opens on
			var close := Transform3D(Basis.IDENTITY, Vector3(3.9, 4.3, 9.1)).looking_at(Vector3(3.7, 1.3, 2.5))
			var out := smoothstep(0.1, 0.9, progress)
			camera.transform = close.interpolate_with(_home_view, out)
			camera.fov = lerpf(20.0, _home_fov, out)
			return
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
		var speaking: String = ACTORS.get(String(beat[2]), "")
		for key in people:
			Person.set_talking(people[key], key == speaking, true)
	var p := clampf((elapsed - float(beat[0])) / (float(beat[1]) - float(beat[0])), 0, 1)
	_camera_shot(String(beat[4]), p)
	if _scene == "tower":
		_tower_frame()
	elif _scene == "route":
		_route_frame(String(beat[4]))
	else:
		_room_frame(String(beat[4]))
	# (the bubble goes up once everyone's where this moment has them, so it finds its speaker's head)
	if _spoken != idx:
		_spoken = idx
		_show_dialogue(beat)
	_shot = String(beat[4])
	shade.color = Color(0.025, 0.03, 0.06, _fade_at(elapsed))
	_last_time = elapsed


## How dark the screen is: slow fades to and from black at each end and round each cut to another place, with no
## flashing screen on the reveal.
func _fade_at(t: float) -> float:
	var fade := maxf(0.0, 1.0 - t / 0.8)
	fade = maxf(fade, _dip(t, DAWN, 1.1, 0.9))
	fade = maxf(fade, _dip(t, ROOM, 0.5, 0.5))
	return maxf(fade, clampf((t - LENGTH + 0.65) / 0.65, 0, 1))


func _dip(t: float, cut: float, before: float, after: float) -> float:
	return clampf(1.0 - (cut - t) / before, 0, 1) if t < cut else clampf(1.0 - (t - cut) / after, 0, 1)


func _tower_frame() -> void:
	# the office's lights, until he's through the door; the warehouse's, once it opens (each kept dark while
	# the camera's in the other room, so neither shines through the wall between)
	var open := smoothstep(DOOR_OPEN, DOOR_OPEN + 1.0, elapsed)
	var office := 1.0 if elapsed < INSIDE else 0.0
	var room := open if elapsed < INSIDE else 1.0
	spot.light_energy = SPOT_E * office * (1.0 - 0.3 * smoothstep(DOOR, DOOR + 2.0, elapsed))
	desk_lamp.light_energy = DESK_E * office
	for lamp in cage_lamps:
		(lamp as OmniLight3D).light_energy = CAGE_E * office
	for lamp in hang_lamps:
		(lamp as OmniLight3D).light_energy = HANG_E * office * (1.0 - 0.5 * smoothstep(DOOR, DOOR + 2.0, elapsed))
	for lamp in room_lamps:
		(lamp as Light3D).light_energy = ROOM_E * room * (1.0 if elapsed >= INSIDE else 0.3)
	for beam in room_beams:
		(beam as Node3D).visible = room > 0.2
	door_light.light_energy = 2.2 * open * office
	door_panel.position.z = DOOR_Z - 2.4 * open
	# (the warehouse has no colour of its own: grey air, and whatever the lamps reach)
	env.ambient_light_color = Color("#5c64a0") if elapsed < INSIDE else Color("#5a6068")
	env.ambient_light_energy = 0.66 if elapsed < INSIDE else 0.5
	env.fog_light_color = Color("#1c1838") if elapsed < INSIDE else Color("#15171b")
	for gear in gears:
		(gear as Node3D).rotation.x = elapsed * float(gear.get_meta("speed"))
	_gear_frame()
	_staff_frame()
	for key in people:
		if String(key).begins_with("captive"):
			Person.animate(people[key], 0, 0, elapsed + float(String(key).right(1)))
	_reveal_sounds()


## Gearhart: addressing the staff from the rug, then the walk (GEAR_PATH) to the steel door, through it, down the
## aisle between the cages, and over to the beasts' cages, where he stands admiring them.
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
		# arrived: facing the beasts' cages
		yaw = PI / 2.0
	body.set_meta("yaw_to", yaw)
	if preview or dist <= 0.0:
		body.rotation.y = yaw
	Person.animate(gear, Person.phase_for(dist, GEAR_SPEED), GEAR_SPEED if walking else 0.0, elapsed)


## The staff: listening, then off to the lift as he sends them home; gone once he's alone.
func _staff_frame() -> void:
	var lift := LIFT_AT - Vector3(0, 0, 0.7)
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


## The Coastal Path: the Grubbit trundles out of the tall grass and down onto the trail, the flyers wheel over it,
## and Bram turns to Tilly while she talks.
func _route_frame(shot: String) -> void:
	if shot != _shot:
		# a cut: what this view shows stands at once, rather than fading in as it does when you walk up to it
		set_world._fade_buildings(10.0, 99)
	Person.face(people["bram"], Vector2i(1, 0) if shot == "beasts" else Vector2i(0, 1), not preview and shot == _shot)
	for key in people:
		Person.animate(people[key], 0, 0, elapsed + (0.7 if key == "bram" else 0.0))
	var awake := clampf((elapsed - DAWN - 1.0) / 7.5, 0, 1)
	var grub = beasts[0]
	grub.position = _ground(BURROW.lerp(LAWN, awake))
	grub.rotation.y = atan2(LAWN.x - BURROW.x, LAWN.z - BURROW.z)
	grub.state = "walk" if awake < 1.0 else "idle"
	for i in [3, 4]:
		var turn: float = elapsed * 0.3 + i * 2.2
		beasts[i].position = _ground(FLYERS_AT + Vector3(sin(turn) * 1.6, 2.7 + sin(elapsed * 0.8 + i) * 0.3, cos(turn) * 1.2))
		beasts[i].rotation.y = turn + PI / 2.0


## The bedroom: the hero by the bed, turning to the door while Mom calls up the stairs, then back.
func _room_frame(shot: String) -> void:
	var hero: Node3D = people["hero"]
	Person.face(hero, Vector2i(1, 0) if shot == "mom" else Vector2i(0, 1), not preview and shot == _shot)
	Person.animate(hero, 0, 0, elapsed)
