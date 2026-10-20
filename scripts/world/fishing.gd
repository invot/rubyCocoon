extends RefCounted
## Fishing. With Fisher Gil's pole (from his shack in Tidewater), face any water and press A to cast. Where the water
## ripples (map "fish_spots", see map_loader.gd) something nearly always bites, and quickly; elsewhere only now and
## then. When the float dips, strike, then reel (ui/fishing_game.gd); land it and the water beast leaps out for a wild
## battle (catch it with the flute, or beat it). Bait on your hook (GameState.bait) is used up whenever something
## bites, and brings up stronger, rarer water beasts, sooner: worms from the islands, lures further on.

const Beasts = preload("res://scripts/core/beasts.gd")
const RaceDB = preload("res://scripts/data/race_db.gd")
const ItemDB = preload("res://scripts/data/item_db.gd")
const WorldDB = preload("res://scripts/data/world_db.gd")
const FishingGame = preload("res://scripts/ui/fishing_game.gd")

## The water beasts that bite, by bait (none, worms, spinner lure, glow lure).
const POOLS := [[21, 12, 20, 14], [14, 16, 15, 13, 22], [17, 19, 15, 18, 22], [18, 19, 23, 17]]
## how many levels above the place's own each bait brings them up
const BAIT_LEVELS := [0, 2, 5, 9]
## the chance something bites, at a ripple and in open water (each better bait adds a little)
const BITE_SPOT := 0.85
const BITE_OPEN := 0.3


## Casts from where you stand into water tile `tile`, and plays it out. lesson: Fisher Gil's first cast (something
## always bites, a gentler line, and his words). Returns the result: "landed", "nothing", "missed", "too_fast",
## "too_slow", "cancelled" or "" (you couldn't fish).
static func cast(world, tile: Vector2i, lesson := false, coach := "") -> String:
	if GameState.item_count("fishing_rod") <= 0:
		await UI.say(["The water sparkles. Something might live down there..."])
		return ""
	if GameState.alive_party().is_empty():
		await UI.say(["Your beasts are too tired to take on anything you'd reel in. Heal them first!"])
		return ""
	if GameState.bait != "" and GameState.item_count(GameState.bait) <= 0:
		GameState.bait = ""
	var tier := int(ItemDB.get_item(GameState.bait).get("bait", 0)) if GameState.bait != "" else 0
	var spot: bool = world.map.get("fish_spots", {}).has(tile)
	var beast = pick_beast(world.map, tier) if not lesson else Beasts.create(12, 3)
	var chance := 1.0 if lesson else (BITE_SPOT if spot else BITE_OPEN) + 0.05 * tier
	var bite := -1.0
	if randf() < chance:
		bite = 2.0 if lesson else randf_range(1.5, 4.0) * (0.7 if spot else 1.0) * (1.0 - 0.1 * tier)
	var strength := clampf(0.2 + 0.25 * tier + float(beast.level - GameState.best_level()) * 0.05, 0.0, 1.0)
	Sfx.play("slingshot", 0.1)
	var line: Node3D = world.fishing_line(tile)
	var res := ""
	if UI.auto:
		await world.get_tree().process_frame
		res = "landed" if bite >= 0.0 else "nothing"
	else:
		var g = FishingGame.new()
		g.setup({"bite": bite, "strength": strength, "lesson": lesson, "coach": coach,
			"on_nibble": func(): world.dip_line(line)})
		UI.push(g)
		var r: Dictionary = await g.done
		res = String(r.get("result", "cancelled"))
	if is_instance_valid(line):
		line.queue_free()
	# something bit: the bait is gone
	if res in ["landed", "missed", "too_fast", "too_slow"] and GameState.bait != "":
		GameState.remove_item(GameState.bait)
		if GameState.item_count(GameState.bait) <= 0:
			UI.toast("That was your last %s." % ItemDB.item_name(GameState.bait))
			GameState.bait = ""
	match res:
		"nothing":
			await UI.say(["Nothing's biting. Try where the water ripples."])
		"missed":
			await UI.say(["Too slow! Whatever it was let go of the line."])
		"too_fast":
			await UI.say(["Snap! The line pulled too tight, and the beast broke free."])
		"too_slow":
			await UI.say(["The line went slack, and the beast slipped off the hook."])
		"landed":
			await UI.say(["You reeled in a wild %s! It leaps out of the water!" % RaceDB.race_name(beast.race)])
			world.busy = true
			await Story.wild_battle(world, [beast], "wild", {"fishing": true})
	return res


## A water beast for this place and bait: one of the bait's pool, at the place's level plus the bait's.
static func pick_beast(map: Dictionary, tier: int):
	var pool: Array = POOLS[clampi(tier, 0, POOLS.size() - 1)]
	var level: int = area_level(map) + BAIT_LEVELS[clampi(tier, 0, BAIT_LEVELS.size() - 1)] + randi_range(-1, 1)
	return Beasts.create(int(pool[randi_range(0, pool.size() - 1)]), maxi(2, level))


## How strong the place's own beasts are: its wild beasts' levels, or for a town, the weakest road out of it.
static func area_level(map: Dictionary) -> int:
	var id: String = map.get("parent", map.get("id", ""))
	if WorldDB.ROUTES.has(id):
		var lv: Array = WorldDB.ROUTES[id]["lv"]
		return (int(lv[0]) + int(lv[1])) / 2
	var best := 99
	for r in WorldDB.ROUTES:
		var route: Dictionary = WorldDB.ROUTES[r]
		if route.get("from", "") == id or route.get("to", "") == id:
			best = mini(best, int(route["lv"][0]))
	return best if best < 99 else 5
