extends SceneTree
## Debug: prints early-game stats for hatchlings vs. route 1 wild beasts.
func _init() -> void:
	var Beasts = load("res://scripts/core/beasts.gd")
	# the four starters as hatchlings, then the Coastal Path's wild beasts and a growing Embit
	for spec in [[0, 1], [24, 1], [12, 1], [30, 1], [15, 1], [0, 3], [27, 4], [36, 4], [0, 5], [0, 20]]:
		var b = Beasts.create(spec[0], spec[1])
		print("%-12s L%d hp %d atk %d def %d spr %d spd %d xp_next %d moves %s" % [b.nickname, b.level, b.max_hp(), b.stat("atk"), b.stat("def"), b.stat("spr"), b.stat("spd"), b.xp_for_level(b.level + 1), b.moves])
	quit()
