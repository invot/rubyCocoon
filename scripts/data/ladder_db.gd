extends RefCounted
## The arena ladder: a roster of trainers in ten ranks, the same at every arena. Beat every trainer of a rank to open
## the next one; each rank cleared raises your trainer level to at least rank + 1 (see GameState.reach_trainer_level)
## and earns a crystal shard. Beaten trainers can be fought again for gold and trainer XP.
## Opponents are made from fixed seeds, so the roster never changes: each favours one side of the ring (an element
## and its neighbours, so its middle and both corners are filled) and brings more beasts, higher levels and more
## shield points rank by rank.

const RaceDB = preload("res://scripts/data/race_db.gd")
const WorldDB = preload("res://scripts/data/world_db.gd")
const MapGen = preload("res://scripts/world/map_gen.gd")
const Ring = preload("res://scripts/core/ring.gd")

const RANKS := 10
const RANK_NAMES := ["Novice", "Rookie", "Bronze", "Silver", "Gold", "Platinum", "Jade", "Ruby", "Master", "Champion"]
const CLASSES := ["Ring Novice", "Ring Rookie", "Bronze Duelist", "Silver Duelist", "Gold Duelist", "Platinum Ace",
	"Jade Ace", "Ruby Ace", "Ring Master", "Champion"]
## opponents per rank
const COUNT := [3, 3, 3, 3, 3, 4, 4, 4, 4, 4]
## beasts per opponent, and their shield points, by rank
const TEAM := [2, 3, 3, 4, 4, 5, 6, 6, 7, 8]
const SHIELD := [0, 0, 1, 1, 1, 2, 2, 3, 3, 4]


static func rank_name(rank: int) -> String:
	return "Rank %d · %s" % [rank, RANK_NAMES[clampi(rank - 1, 0, RANKS - 1)]]


static func count(rank: int) -> int:
	return COUNT[clampi(rank - 1, 0, RANKS - 1)]


## Opponent i (0-based) of a rank: {name, cls, team: [[race, level]], shield, reward, look, theme}.
static func opponent(rank: int, i: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7700 + rank * 97 + i * 13
	var theme: String = Ring.ORDER[rng.randi_range(0, 3)]
	var side := Ring.side_index(theme)
	var near: Array = [Ring.side_element(side - 1), Ring.side_element(side + 1)]
	var n: int = TEAM[clampi(rank - 1, 0, RANKS - 1)]
	var lv := 3 + 6 * (rank - 1) + i
	var team := []
	# the middle and both corners of the favoured side first, then the opposite side and the neighbours' middles
	var opp := Ring.side_element(side + 2)
	var wants := [theme, near[0], near[1], opp, near[0], near[1], opp, near[0]]
	for k in n:
		var el: String = wants[k]
		var pool := []
		for r in RaceDB.NORMAL_COUNT:
			if RaceDB.element(r) == el:
				pool.append(r)
		team.append([pool[rng.randi_range(0, pool.size() - 1)], lv + rng.randi_range(-1, 1)])
	var names: Array = WorldDB.TRAINER_NAMES
	return {"name": names[(rank * 7 + i * 3 + rng.randi_range(0, 3)) % names.size()], "cls": CLASSES[clampi(rank - 1, 0, RANKS - 1)],
		"team": team, "shield": SHIELD[clampi(rank - 1, 0, RANKS - 1)], "reward": 80 * rank + 30 * i,
		"look": MapGen.random_look(rng).merged({"outfit": "camo"}), "theme": theme}
