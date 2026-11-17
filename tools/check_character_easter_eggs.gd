extends SceneTree
## Name isolation, existing-save behavior, ending gate, and the playable wedding's finish/skip paths.
var Codex: GDScript
var CodexDB: GDScript
var Wedding: GDScript
var bad := 0
var ui: Node
var state: Node
var story: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	Codex = load("res://scripts/ui/codex.gd")
	CodexDB = load("res://scripts/data/codex_db.gd")
	Wedding = load("res://scripts/story/wedding.gd")
	ui = root.get_node("UI")
	state = root.get_node("GameState")
	story = root.get_node("Story")
	if "--touch" in OS.get_cmdline_user_args():
		var prefs := root.get_node("Prefs")
		prefs.input_mode = "screen"
		prefs.touch_controls = "on"
		ui.controls.refresh()
	ui.auto = true
	for name in ["Christiana", "christiana", " CHRISTIANA "]:
		state.new_game(name)
		_check(state.codex_name() == "Noodles", "Christiana's companion is Noodles")
		_check("I'm Noodles!" in CodexDB.plain("codex"), "introduction uses the name")
		_check(CodexDB.title("codex") == "Using Noodles", "journal topic uses the name")
		ui.auto_log.clear()
		await Codex.say(["[happy] I'm your Codex!"])
		_check(ui.auto_log[0].begins_with("Noodles:"), "speech bubble speaker uses the name")
	for name in ["Christina", "Christian", "Christiana Smith", "Andrew", "Jared", "Tester"]:
		state.new_game(name)
		_check(state.codex_name() == "Codex", "other journeys keep Codex: " + name)
		_check(CodexDB.title("codex") == "Using the Codex", "shared topic data remains unchanged")
	# Old saves already store the trainer's name; no new saved field is required.
	state.player_name = "Christiana"
	_check(state.codex_name() == "Noodles", "existing-save trainer name activates the name")
	for spec in [["Andrew", false, false], ["Andrew", true, true], [" andrew ", true, true], ["Jared", true, false], ["Andrewson", true, false], ["Christiana", true, false]]:
		state.new_game(spec[0])
		state.set_flag("game_cleared", spec[1])
		ui.auto_log.clear()
		await story._ending_easter_eggs()
		var married: bool = "you are married!" in " ".join(ui.auto_log)
		_check(married == spec[2], "wedding only follows Andrew's final victory")
	# Build the real stage and exercise the same modal that a player sees.
	ui.auto = false
	state.new_game("Andrew")
	var hero_before: Dictionary = state.hero.duplicate(true)
	var film = Wedding.new()
	ui.push(film)
	await process_frame
	_check(film._people.has("Andrew") and film._people.has("Jared"), "both grooms appear on stage")
	_check(film._people["Andrew"].scale.x > 1.0, "epilogue uses an adult-sized groom")
	film.beat = 8
	film._show_beat()
	film._process(0.1)
	_check(film._rings[0].visible and film._rings[1].visible, "rings are exchanged")
	_check(film._confetti[0].visible, "ceremony celebrates the marriage")
	if OS.has_environment("RUBY_WEDDING_SHOT"):
		film._dialogue.instant_text = true
		film._dialogue.shown = 99999.0
		film._dialogue.text_label.visible_characters = -1
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("RUBY_WEDDING_SHOT"))
	film.beat = Wedding.BEATS.size() - 1
	film._next_beat()
	_check(film.closed and not ui.stack.has(film), "ending returns control to the normal finale")
	await process_frame
	_check(not ui.controls.film_mode, "finishing restores the controls")
	film = Wedding.new()
	ui.push(film)
	await process_frame
	Input.action_press("ui_cancel")
	film._process(1.0)
	Input.action_release("ui_cancel")
	_check(film.closed and not ui.stack.has(film), "hold B skips the wedding")
	await process_frame
	_check(not ui.controls.film_mode and state.hero == hero_before, "skipping restores controls and preserves the hero")
	print("CHARACTER EASTER EGGS DONE: %d problem(s)" % bad)
	quit(1 if bad else 0)

func _check(ok: bool, message: String) -> void:
	if not ok:
		bad += 1
		print("FAIL ", message)
