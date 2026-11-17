extends "res://scripts/ui/modal.gd"
## Remembered-clue escape or a difficult flute performance followed by controlling the mouse.
const Stage = preload("res://scripts/story/prison_stage.gd")
const MARCH := [[0], [2, 1], [3], [4], [2, 0], [1], [5], [3, 1], [0], [2, 4], [3, 5], [2]]
const ROCKS := [Vector2i(2, 0), Vector2i(3, 1), Vector2i(4, 2), Vector2i(5, 1)]
const LOCK := Vector2i(6, 0)
var stage: Node3D
var view: SubViewport
var mode := "choice"
var mouse_tile := Vector2i(2, 1)
var _cooldown := 0.0
var _old_pause := true

static func play() -> void:
	if GameState.flag("jail_escaped"):
		return
	if UI.auto:
		GameState.set_flag("jail_escaped")
		return
	await UI.play_film(load("res://scripts/story/prison_escape.gd").new())

func _ready() -> void:
	_old_pause = UI.allow_pause
	UI.allow_pause = false
	view = SubViewport.new()
	view.own_world_3d = true
	view.handle_input_locally = false
	add_child(view)
	stage = Stage.new()
	view.add_child(stage)
	var screen := TextureRect.new()
	screen.texture = view.get_texture()
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	resized.connect(_layout)
	_layout()
	for p in ROCKS:
		stage.sphere(stage, tile_position(p), Vector3(0.25, 0.2, 0.2), "676271")
	stage.box(stage, tile_position(LOCK) + Vector3(0, 0.18, 0), Vector3(0.2, 0.38, 0.16), "b48a48")
	_write_song()
	_begin.call_deferred()

func _exit_tree() -> void:
	UI.top_bar.dismiss("jail")
	UI.allow_pause = _old_pause

func _layout() -> void:
	view.size = Vector2i(maxi(1, int(size.x)), maxi(1, int(size.y)))

func _begin() -> void:
	await UI.say(["Matt locked us in his old dungeon. He can't have us touching the machinery.",
		"I can coax that mouse into helping. Let me write a song in the dirt...",
		"Some of the marks have rubbed off. Or perhaps you have another idea?"], "Jared", null, stage.jared)
	_choose()

func _choose() -> void:
	mode = "choice"
	while not closed and mode == "choice":
		var c: int = await UI.choose("Escape the cell", ["Remember the tool", "Play Jared's song"])
		if c == 0:
			var pick: int = await UI.choose("What did the voice ask for?", GameState.NIGHTMARE_TOOLS)
			if pick == GameState.nightmare_tool():
				var lines := ["A spork! Its handle will lift the catch through that gap.",
					"Your left sock! Pull it into a loop and we'll snag the catch through the bars.",
					"A roll of toilet paper! Twist it into a cord, loop it over the catch, and pull."]
				await UI.say([lines[pick]], "Jared", null, stage.jared)
				await _escape("tool")
				return
			if pick >= 0:
				await UI.say(["That won't reach this catch. Think back, or try the song. We have time to try again."], "Jared", null, stage.jared)
		elif c == 1:
			var result: Dictionary = await UI.flute_ex("dread", "Composed in the dirt · Some symbols are incomplete", {"mode": "play", "level": 5, "dirt_sheet": true, "melody": MARCH, "time_limit": 18.0})
			if not result.get("cancelled", false) and float(result.get("acc", 0.0)) > 0.0:
				mode = "mouse"
				mouse_tile = Vector2i(2, 1)
				stage.mouse.position = tile_position(mouse_tile)
				stage.camera.position = Vector3(0, 4.6, 5.8)
				stage.camera.look_at(Vector3(0, 0, 1.8))
				UI.top_bar.post("Move the mouse · A: Unlock · B: Return", null, {"key": "jail", "replace": true, "hold": 120.0})
			else:
				await UI.say(["Let's try again. Or use that tool you remember."], "Jared", null, stage.jared)

func tile_position(tile: Vector2i) -> Vector3:
	return Vector3(-2.7 + tile.x * 0.8, 0.05, 1.2 + tile.y * 0.6)

func _process(delta: float) -> void:
	if mode != "mouse" or UI.stack.back() != self:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	if _cooldown > 0:
		return
	for pair in [["ui_left", Vector2i.LEFT], ["ui_right", Vector2i.RIGHT], ["ui_up", Vector2i.UP], ["ui_down", Vector2i.DOWN]]:
		if Input.is_action_pressed(pair[0]):
			move_mouse(pair[1])
			_cooldown = 0.18
			break

func move_mouse(direction: Vector2i) -> bool:
	var next := mouse_tile + direction
	if absi(direction.x) + absi(direction.y) != 1 or next.x < 0 or next.x > 6 or next.y < 0 or next.y > 3 or next in ROCKS:
		return false
	mouse_tile = next
	stage.mouse.position = tile_position(next)
	stage.mouse.rotation.y = atan2(direction.x, direction.y)
	return true

func on_input(ev: InputEvent) -> void:
	if mode != "mouse" or ev.is_echo():
		return
	if ev.is_action_pressed("ui_cancel"):
		_choose.call_deferred()
	elif ev.is_action_pressed("interact") or ev.is_action_pressed("ui_accept"):
		if mouse_tile == LOCK:
			_escape("mouse")
		else:
			UI.toast("Guide the mouse to the brass catch.")

func _escape(route: String) -> void:
	mode = "opening"
	GameState.set_flag("jail_escaped")
	GameState.set_flag("jail_escape_" + route)
	var tween := create_tween()
	tween.tween_property(stage.gate, "position:y", 2.8, 0.8)
	await tween.finished
	await UI.say(["It's open. Come on. We have to shut those machines down."], "Jared", null, stage.jared)
	close(true)

func _write_song() -> void:
	# Prompts lie directly on the dungeon floor, including rubbed-away halves.
	var prompts = preload("res://scripts/ui/flute_game.gd").PROMPTS
	for i in MARCH.size():
		for j in MARCH[i].size():
			var tex: Texture2D = prompts[MARCH[i][j]]
			var node := MeshInstance3D.new()
			var mesh := PlaneMesh.new()
			mesh.size = Vector2(0.24, 0.24)
			node.mesh = mesh
			var mat := StandardMaterial3D.new()
			if i % 3 == 1:
				var half := AtlasTexture.new()
				half.atlas = tex
				half.region = Rect2(Vector2.ZERO, tex.get_size() * Vector2(0.5, 1.0))
				tex = half
				mesh.size.x *= 0.5
			mat.albedo_texture = tex
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			node.material_override = mat
			node.position = Vector3(-0.9 + (i % 6) * 0.35, 0.02 + j * 0.001, -1.2 + (i / 6) * 0.45 + j * 0.16)
			stage.add_child(node)
