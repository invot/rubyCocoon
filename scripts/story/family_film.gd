extends "res://scripts/ui/modal.gd"
## Dialogue-led scenes in real game rooms. All sequences share input, safe bubbles, and film controls.
const Person = preload("res://scripts/gfx/voxel_person.gd")
const Dialogue = preload("res://scripts/ui/cinematic_dialog.gd")
const MapLoader = preload("res://scripts/world/map_loader.gd")
const PrisonStage = preload("res://scripts/story/prison_stage.gd")
const LINES := {
	"friendship": [
		["Mom", "You must be Marlyse. I brought soup. And enough bread to feed a small arena."],
		["Marlyse", "Then you and I are going to get along beautifully."],
		["Mom", "Your son said you don't get many visitors."],
		["Marlyse", "My Jared thinks he can cure everything if he just works harder. He was such a lonely little boy."],
		["Mom", "You were there for him."],
		["Marlyse", "Always. I wish he'd sit with me now instead of chasing another miracle."],
		["Mom", "Then I'll keep you company until he learns. More soup?"],
		["Marlyse", "Only if you stay for cards. I cheat terribly."],
	],
	"arrest": [
		["Jared", "Vexmora is the name I hid behind. My name is Jared. Marlyse is my mother. She's dying."],
		["Jared", "Ghosts endure without living bodies. I thought their bonds might teach me how to save her."],
		["Matt", "And I paid for every experiment. Exclusive rights. You find a cure; I sell the energy."],
		["Jared", "I let you take those trainers. I knew what the machines did to them. I can't pretend I didn't."],
		["Matt", "That child has cost me enough. One less witness, one less problem."],
		["Jared", "NO! You will not kill them!"],
		["Matt", "Still so sentimental, little brother. Fine. Both of you can think it over in a cell."],
	],
	"hockey": [
		["Goon", "Nobody touches Mr. Gearheart's controls. Nobody leaves this room."],
		["Mom", "Marlyse, hold my coat. It's hockey night."],
		["Marlyse", "You wore the shirt under it?"],
		["Mom", "I like to be prepared."],
		["Goon", "Is that a hockey stick?"],
		["Mom", "Off the controls. NOW."],
		["Goon", "All right! All right! We're going!"],
		["Mom", "Go on, sweetheart. Shut that thing down. I'll keep the bench warm."],
	],
	"farewell": [
		["Jared", "Mother... I shut the treatment down too. I don't know how to save you now."],
		["Marlyse", "Jared. Look at me. I'm here."],
		["Jared", "You were all I had. I couldn't bear to lose you."],
		["Marlyse", "I know. But everyone dies someday. Even people we love more than anything."],
		["Marlyse", "Please stop trying to make that decision for me. Let me have the time I have, with you."],
		["Jared", "No more cages. No more experiments on anyone. I promise."],
		["Mom", "We'll stay. Both of us."],
		["Marlyse", "Good. Bring the cards. And don't let me win."],
	],
	"home": [
		["Matt", "You took everything from me, Jared."],
		["Jared", "You nearly killed everyone. If this ends in a fight, then let's finish it."],
		["Matt", "Wait. That box... Those are our ships."],
		["Jared", "Mother kept them? All this time?"],
	],
	"memory": [
		["Matt", "Jared. Share your fries with Mum."],
		["Jared", "Why? Aren't these mine?"],
		["Matt", "She couldn't afford food for herself. We need to share ours."],
		["Jared", "Oh. Here, Mum. You can have the big ones."],
		["Marlyse", "Thank you, my loves."],
	],
	"spaceships": [
		["Matt", "Little brother... Will you play spaceships with me?"],
		["Jared", "You can have the blue one."],
		["Matt", "I'll unlock the rest of the plants. Wren can have the keys. All of them."],
		["Jared", "And then we answer for what we did."],
		["Matt", "Yes. And then we answer for it."],
	],
}
const LOOKS = preload("res://scripts/data/story_people.gd").LOOKS

var chapter := "friendship"
var beat := 0
var ready_scene := false
var view: SubViewport
var world: Node3D
var camera: Camera3D
var actors := {}
var dialogue: Control
var _skip := 0.0
var _elapsed := 0.0
var _held := false
var _skip_posted := false
var _skip_track: ColorRect
var _skip_fill: ColorRect
var _prior_film := false
var _prior_pause := true
var _props: Node3D

static func play(which: String) -> void:
	if UI.auto:
		for line in LINES[which]:
			await UI.say([line[1]], line[0])
		return
	var film = load("res://scripts/story/family_film.gd").new()
	film.chapter = which
	await UI.play_film(film)

func _ready() -> void:
	_prior_film = UI.controls.film_mode
	_prior_pause = UI.allow_pause
	UI.allow_pause = false
	UI.controls.set_film_mode(true)
	view = SubViewport.new()
	view.own_world_3d = true
	view.handle_input_locally = false
	add_child(view)
	var screen := TextureRect.new()
	screen.texture = view.get_texture()
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	resized.connect(_layout)
	_layout()
	_build.call_deferred()

func _layout() -> void:
	view.size = Vector2i(maxi(1, int(size.x)), maxi(1, int(size.y)))

func _exit_tree() -> void:
	UI.top_bar.dismiss("family-film")
	if is_instance_valid(world):
		world.keep_shaders()
	if is_instance_valid(UI.controls) and UI.controls.is_inside_tree():
		UI.controls.set_film_mode(_prior_film)
	UI.allow_pause = _prior_pause

func _build() -> void:
	var map_id := MapLoader.interior_of("cogsworth", "cafe" if chapter == "memory" else "house")
	if chapter in ["arrest", "hockey"]:
		map_id = MapLoader.interior_of("gravenmoor", "cathedral") + "@3"
	var holder := Node3D.new()
	view.add_child(holder)
	world = await GameState.main.build_set(map_id, holder)
	world.player.visible = false
	for npc in world.npcs.values():
		npc["node"].visible = false
	world.cam_free = true
	camera = world.cam
	var cast := []
	for line in LINES[chapter]:
		if line[0] not in cast:
			cast.append(line[0])
	if chapter == "arrest":
		cast.append("Hero")
	if chapter == "hockey":
		cast.append("Goon Two")
	var center := Vector2i(world.map["w"] / 2, world.map["h"] / 2)
	var tiles := []
	for y in range(1, world.map["h"] - 1):
		for x in range(1, world.map["w"] - 1):
			var p := Vector2i(x, y)
			if preload("res://scripts/world/map_gen.gd").walkable(preload("res://scripts/world/map_gen.gd").get_t(world.map, x, y)) and not world.map.get("furniture", {}).has(p):
				tiles.append(p)
	tiles.sort_custom(func(a, b): return a.distance_squared_to(center) < b.distance_squared_to(center))
	var origin: Vector3 = world.tile_pos(tiles[0])
	for i in cast.size():
		var who: String = cast[i]
		var look: Dictionary = GameState.hero_look() if who == "Hero" else LOOKS["Goon" if who == "Goon Two" else who].duplicate()
		if who == "Mom":
			var yours: Dictionary = preload("res://scripts/gfx/townfolk.gd").outfit(GameState.hero_look())["colours"]
			for key in ["skin", "hair", "eyes"]:
				if yours.has(key):
					look[key] = "#" + (yours[key] as Color).to_html(false)
		if chapter == "memory":
			look["scale"] = 0.65 if who in ["Matt", "Jared"] else 1.0
			look["hair"] = "#5b3e32" if who in ["Matt", "Jared"] else "#675344"
		if chapter == "hockey" and who == "Mom":
			look["shirt"] = "#b93646"
		var actor := Person.build(look)
		holder.add_child(actor)
		actor.position = origin + Vector3((i - (cast.size() - 1) * 0.5) * 1.2, 0, 0)
		Person.face(actor, Vector2i(0, 1))
		actors[who] = actor
	_props = Node3D.new()
	holder.add_child(_props)
	var painter := PrisonStage.new()
	if chapter == "memory":
		painter.box(_props, origin + Vector3(0, 0.55, 0.6), Vector3(2.6, 0.1, 0.8), "b28c65")
		for x in [-1.1, 1.1]:
			painter.box(_props, origin + Vector3(x, 0.25, 0.6), Vector3(0.12, 0.5, 0.55), "9c7959")
		for i in 2:
			var plate := origin + Vector3(-0.65 + i * 1.3, 0.62, 0.65)
			painter.sphere(_props, plate, Vector3(0.28, 0.025, 0.23), "eee4cf")
			for j in 7:
				var fry := painter.box(_props, plate + Vector3((j % 3) * 0.06 - 0.06, 0.04, (j / 3) * 0.05 - 0.05), Vector3(0.04, 0.04, 0.2), "e5c56b")
				fry.rotation.y = j * 0.4
	if chapter in ["home", "spaceships"]:
		for at in [Vector3(0, 0.1, 0), Vector3(-0.4, 0.35, 0), Vector3(0.4, 0.35, 0), Vector3(0, 0.35, -0.3), Vector3(0, 0.35, 0.3)]:
			painter.box(_props, origin + Vector3(0, 0, 0.8) + at, Vector3(0.85 if at.x == 0 else 0.06, 0.1 if at.y < 0.2 else 0.5, 0.65 if at.z == 0 else 0.06), "aa845f")
		for i in 2:
			var ship := Node3D.new()
			_props.add_child(ship)
			ship.position = origin + Vector3(-0.2 + i * 0.4, 0.42, 0.8)
			painter.sphere(ship, Vector3.ZERO, Vector3(0.08, 0.08, 0.22), "739bb5" if i == 0 else "b76d72")
			painter.box(ship, Vector3(0, -0.02, 0.05), Vector3(0.32, 0.04, 0.14), "c5c4ab")
	if chapter == "hockey":
		var stick := BoneAttachment3D.new()
		stick.bone_name = "r_hand"
		(actors["Mom"].get_meta("skeleton") as Skeleton3D).add_child(stick)
		painter.box(stick, Vector3(0, -0.5, 0), Vector3(0.045, 1.3, 0.045), "c5ac7e")
		painter.box(stick, Vector3(0.16, -1.12, 0), Vector3(0.36, 0.12, 0.055), "b2976c")
		var jersey := BoneAttachment3D.new()
		jersey.bone_name = "chest"
		(actors["Mom"].get_meta("skeleton") as Skeleton3D).add_child(jersey)
		for y in [-0.1, -0.04]:
			painter.box(jersey, Vector3(0, y, 0.14), Vector3(0.34, 0.035, 0.025), "eee5d2")
	painter.free()
	camera.fov = 40
	camera.position = origin + Vector3(0.2, 3.0, 7.8 if cast.size() > 3 else 6.5)
	camera.look_at(origin + Vector3(0, 1.0, 0))
	ready_scene = true
	_skip_track = ColorRect.new()
	_skip_track.color = Color(1, 1, 1, 0.22)
	_skip_track.size = Vector2(260, 6)
	_skip_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_skip_track)
	_skip_fill = ColorRect.new()
	_skip_fill.color = Color.WHITE
	_skip_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip_track.add_child(_skip_fill)
	_hint()
	_show()

func _hint() -> void:
	var keys: bool = not UI.is_touch() and not UI.controls.controller_guide()
	UI.top_bar.post("Enter: Next · Hold Esc: Skip" if keys else "A: Next · Hold B: Skip", null, {"sub": world.map["name"], "key": "family-film", "replace": true, "hold": 4.0})

func _show() -> void:
	if is_instance_valid(dialogue):
		dialogue.queue_free()
	var line: Array = LINES[chapter][beat]
	for who in actors:
		Person.set_talking(actors[who], who == line[0])
	dialogue = Dialogue.new()
	dialogue.setup([line[1]], line[0], null, actors.get(line[0]))
	dialogue.advance_requested.connect(_next)
	add_child(dialogue)
	if chapter == "hockey" and beat >= 5:
		Person.set_reach(actors["Mom"], 1.0)
		Person.set_action(actors["Mom"], "swing")
		for who in ["Goon", "Goon Two"]:
			Person.set_pose(actors[who], "kneel", 0.36, true)
		if beat == 5:
			Sfx.play("hit")
	if chapter == "arrest" and beat == 5:
		Person.set_reach(actors["Jared"], 1.0)
		Person.set_pose(actors["Matt"], "kneel", 0.36, true)
		Sfx.play("cast")
		var protection := OmniLight3D.new()
		actors["Jared"].add_child(protection)
		protection.position.y = 1.0
		protection.light_color = Color("b6b0eb")
		protection.light_energy = 2.0
		protection.omni_range = 4.0
	if chapter == "spaceships":
		for who in ["Matt", "Jared"]:
			Person.set_pose(actors[who], "sit", 0.05, true)

func _next() -> void:
	if beat + 1 >= LINES[chapter].size():
		close()
	else:
		beat += 1
		_show()

func _process(delta: float) -> void:
	if not ready_scene:
		return
	_elapsed += delta
	for actor in actors.values():
		Person.animate(actor, 0, 0, _elapsed)
	_skip_track.visible = _held and _skip >= 0.35
	_skip_track.position = Vector2((size.x - 260.0) / 2.0, UI.top_bar.bottom() + 8.0)
	_skip_fill.size = Vector2(260.0 * clampf((_skip - 0.35) / 0.65, 0, 1), 6)
	if _held:
		_skip += delta
		if _skip >= 0.35 and not _skip_posted:
			_skip_posted = true
			UI.top_bar.post("Keep holding to skip", null, {"key": "family-film", "replace": true, "hold": 1.0})
		if _skip >= 1.0:
			close()

func on_input(ev: InputEvent) -> void:
	if not ready_scene or ev.is_echo():
		return
	if ev.is_action_pressed("ui_cancel"):
		_held = true
		_skip = 0
		_skip_posted = false
	elif ev.is_action_released("ui_cancel"):
		_held = false
		if _skip < 0.35:
			dialogue._advance()
	elif ev.is_action_pressed("interact") or ev.is_action_pressed("ui_accept"):
		dialogue._advance()
