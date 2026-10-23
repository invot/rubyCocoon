extends SceneTree
## Regression checks use project-local save files, never player saves.

class TestState extends "res://scripts/autoload/game_state.gd":
	func save_dir() -> String:
		return "res://build/review_saves/"

var problems := 0

func check(ok: bool, label: String) -> void:
	print("ok " if ok else "FAIL ", label)
	if not ok:
		problems += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var gs := TestState.new()
	gs.new_game("Review")
	var b = gs.Beasts.create(21, 50)
	gs.party = [b]
	check(gs.party_element(["water"]) == b, "secondary element clears field obstacles")
	b.hp = 0
	check(gs.party_element(["water"]) == null, "fainted beasts cannot clear obstacles")
	check(gs.save_game(0), "first save succeeds")
	gs.gold = 1234
	check(gs.save_game(0), "replacement save succeeds")
	check(gs.load_game(0) and gs.gold == 1234, "replacement save loads correctly")
	check(not FileAccess.file_exists(gs.slot_path(0) + ".tmp"), "successful save consumes temporary file")
	var world = load("res://scripts/world/world.gd").new()
	world._wild_target = 5
	var state = root.get_node("GameState")
	state.incense_steps = 10
	state.incense_kind = -1
	check(world._effective_wild_target() == 0, "calm incense suppresses spawns")
	state.incense_steps = 0
	check(world._effective_wild_target() == 5, "calm expiration restores spawns")
	state.incense_steps = 10
	state.incense_kind = 1
	check(world._effective_wild_target() == 8, "lure incense increases spawns")
	state.incense_steps = 0
	check(world._effective_wild_target() == 5, "lure expiration restores normal target")
	var player := Node3D.new()
	world.player = player
	var shader := Shader.new()
	shader.code = "shader_type spatial; uniform vec4 hole;"
	var material := ShaderMaterial.new()
	material.shader = shader
	world.terrain_mats = [material]
	world._update_hole()
	check(material.get_shader_parameter("hole") == Vector4(0, 0, 0, 1), "shader initializes at origin")
	player.position.x = 2
	world._update_hole()
	check(material.get_shader_parameter("hole") == Vector4(2, 0, 0, 1), "shader follows player movement")
	var audio = root.get_node("Sfx")
	audio.music("home")
	audio.music("battle")
	audio.music("home")
	await create_timer(audio.FADE_TIME + 0.2).timeout
	check(audio._music_a.playing or audio._music_b.playing, "rapid music changes keep newest track playing")
	audio.music("")
	world.free()
	player.free()
	gs.free()
	print("REVIEW FIXES DONE: %d problem(s)" % problems)
	quit.call_deferred(1 if problems else 0)
