extends SceneTree
## Debug: prints early-game stats for hatchlings vs. route 1 wild beasts.
func _init() -> void:
	var Beasts = load("res://scripts/core/beasts.gd")
	for spec in [[1, 1], [12, 1], [24, 1], [36, 1], [0, 1], [0, 3], [21, 4], [38, 4], [1, 3], [1, 5]]:
		var b = Beasts.create(spec[0], spec[1])
		print("%-12s L%d hp %d atk %d def %d spr %d spd %d xp_next %d moves %s" % [b.nickname, b.level, b.max_hp(), b.stat("atk"), b.stat("def"), b.stat("spr"), b.stat("spd"), b.xp_for_level(b.level + 1), b.moves])
	quit()
