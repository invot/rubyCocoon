extends SceneTree
## Fixed UI glyph/decal art, generated without changing or smoothing the original design.
## godot --headless --path . --script res://tools/bake_battle_art.gd
func _initialize() -> void:
	var verify := "--verify" in OS.get_cmdline_user_args()
	var bad: int = load("res://scripts/battle/battle.gd").bake_art(verify)
	var sfx = load("res://scripts/autoload/sfx.gd").new()
	bad += sfx.bake_battle_tones(verify)
	sfx.free()
	print("BATTLE ART DONE: %d problem(s)" % bad)
	quit(bad)
