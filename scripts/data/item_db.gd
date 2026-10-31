extends RefCounted
## Items. kind: use (consumable), gear (beast equipment), tgear (trainer equipment).
## tier: the earliest shop tier (0-11, by town progression) that stocks the item.
## found: never stocked by a shop, only found lying about (starter gear in the cliff and harbour shacks).

const MoveDB = preload("res://scripts/data/move_db.gd")
const SongDB = preload("res://scripts/data/song_db.gd")

const ITEMS := {
	# ---------------- consumables ----------------
	## In battle the trainer uses items. "target": ally, ally_ko, allies, enemy, enemies.
	# MP: elemental attacks spend it; only these (and healing at a Beast Center or at home) bring it back
	"spirit_drop": {"name": "Spirit Drop", "kind": "use", "price": 80, "tier": 0, "mp": 15, "target": "ally", "desc": "Restores 15 MP."},
	"spirit_tonic": {"name": "Spirit Tonic", "kind": "use", "price": 220, "tier": 3, "mp": 40, "target": "ally", "desc": "Restores 40 MP."},
	"spirit_elixir": {"name": "Spirit Elixir", "kind": "use", "price": 600, "tier": 6, "mp_pct": 1.0, "target": "ally", "desc": "Fully restores MP."},
	"minor_potion": {"name": "Minor Potion", "kind": "use", "price": 30, "tier": 0, "heal": 40, "target": "ally", "desc": "Restores 40 HP."},
	"potion": {"name": "Potion", "kind": "use", "price": 90, "tier": 2, "heal": 120, "target": "ally", "desc": "Restores 120 HP."},
	"mega_potion": {"name": "Mega Potion", "kind": "use", "price": 260, "tier": 5, "heal": 350, "target": "ally", "desc": "Restores 350 HP."},
	"full_restore": {"name": "Full Restore", "kind": "use", "price": 700, "tier": 8, "heal_pct": 1.0, "cure": true, "target": "ally", "desc": "Fully restores HP and cures status."},
	"remedy_herb": {"name": "Remedy Herb", "kind": "use", "price": 40, "tier": 0, "cure": true, "target": "ally", "desc": "Cures any status ailment."},
	"revival_seed": {"name": "Revival Seed", "kind": "use", "price": 400, "tier": 1, "revive_pct": 0.5, "target": "ally_ko", "desc": "Revives a fainted beast at 50% HP."},
	"phoenix_feather": {"name": "Phoenix Feather", "kind": "use", "price": 1600, "tier": 10, "revive_pct": 1.0, "target": "ally_ko", "desc": "Revives a fainted beast at full HP."},
	"elixir": {"name": "Grove Elixir", "kind": "use", "price": 2400, "tier": 10, "heal_pct": 1.0, "cure": true, "target": "allies", "battle_only": true, "desc": "Fully heals and cures every beast in battle."},
	"calm_incense": {"name": "Calm Incense", "kind": "use", "price": 120, "tier": 1, "field_only": true, "incense": -1, "desc": "Wild beasts avoid you for 150 steps."},
	"lure_incense": {"name": "Lure Incense", "kind": "use", "price": 120, "tier": 1, "field_only": true, "incense": 1, "desc": "Attracts wild beasts for 150 steps."},
	"spicy_bun": {"name": "Spicy Bun", "kind": "use", "price": 60, "tier": 99, "battle_only": true, "buff": {"atk": 1}, "target": "ally", "desc": "Battle snack. Raises one beast's Attack."},
	"mint_tea": {"name": "Mint Tea", "kind": "use", "price": 60, "tier": 99, "battle_only": true, "buff": {"spr": 1}, "heal": 20, "mp": 10, "target": "ally", "desc": "Battle drink. Raises Spirit, restores 20 HP and 10 MP."},
	"honey_cake": {"name": "Honey Cake", "kind": "use", "price": 150, "tier": 99, "heal": 200, "target": "ally", "desc": "Restores 200 HP."},
	"training_candy": {"name": "Training Candy", "kind": "use", "price": 500, "tier": 99, "field_only": true, "xp_level": true, "desc": "Grants one level (up to the level limit)."},
	# elemental bombs: damage is a share of the target's max HP, times the element matchup
	"fire_bomb": {"name": "Fire Bomb", "kind": "use", "price": 80, "tier": 0, "battle_only": true, "bomb": {"el": "fire", "pct": 0.16}, "target": "enemy", "desc": "Fire damage to one foe. Great against air beasts."},
	"tide_bomb": {"name": "Tide Bomb", "kind": "use", "price": 80, "tier": 0, "battle_only": true, "bomb": {"el": "water", "pct": 0.16}, "target": "enemy", "desc": "Water damage to one foe. Great against earth beasts."},
	"stone_bomb": {"name": "Stone Bomb", "kind": "use", "price": 80, "tier": 1, "battle_only": true, "bomb": {"el": "earth", "pct": 0.16}, "target": "enemy", "desc": "Earth damage to one foe."},
	"gale_bomb": {"name": "Gale Bomb", "kind": "use", "price": 80, "tier": 1, "battle_only": true, "bomb": {"el": "air", "pct": 0.16}, "target": "enemy", "desc": "Air damage to one foe. Great against fire and water beasts."},
	"inferno_flask": {"name": "Inferno Flask", "kind": "use", "price": 450, "tier": 7, "battle_only": true, "bomb": {"el": "fire", "pct": 0.14}, "target": "enemies", "desc": "Fire damage to every foe."},
	"tsunami_flask": {"name": "Tsunami Flask", "kind": "use", "price": 450, "tier": 7, "battle_only": true, "bomb": {"el": "water", "pct": 0.14}, "target": "enemies", "desc": "Water damage to every foe."},
	"quake_flask": {"name": "Quake Flask", "kind": "use", "price": 450, "tier": 7, "battle_only": true, "bomb": {"el": "earth", "pct": 0.14}, "target": "enemies", "desc": "Earth damage to every foe."},
	"cyclone_flask": {"name": "Cyclone Flask", "kind": "use", "price": 450, "tier": 7, "battle_only": true, "bomb": {"el": "air", "pct": 0.14}, "target": "enemies", "desc": "Air damage to every foe."},
	# status and debuffs on the enemy
	"poison_dart": {"name": "Poison Dart", "kind": "use", "price": 70, "tier": 1, "battle_only": true, "status": "poison", "chance": 0.9, "target": "enemy", "desc": "Poisons one foe."},
	"sleep_powder": {"name": "Sleep Powder", "kind": "use", "price": 120, "tier": 2, "battle_only": true, "status": "sleep", "chance": 0.7, "target": "enemy", "desc": "70% chance to put one foe to sleep. Sleeping beasts are easier to charm!"},
	"flash_powder": {"name": "Flash Powder", "kind": "use", "price": 160, "tier": 3, "battle_only": true, "status": "blind", "chance": 0.6, "target": "enemies", "desc": "May blind every foe."},
	"stun_net": {"name": "Stun Net", "kind": "use", "price": 220, "tier": 5, "battle_only": true, "status": "stun", "chance": 0.85, "target": "enemy", "desc": "Tangles one foe so it loses its next turn."},
	"sticky_snare": {"name": "Sticky Snare", "kind": "use", "price": 90, "tier": 1, "battle_only": true, "debuff": {"spd": -2}, "target": "enemy", "desc": "Sharply slows one foe."},
	"weaken_powder": {"name": "Weaken Powder", "kind": "use", "price": 150, "tier": 3, "battle_only": true, "debuff": {"atk": -1}, "target": "enemies", "desc": "Lowers every foe's Attack."},
	"rust_dust": {"name": "Rust Dust", "kind": "use", "price": 150, "tier": 4, "battle_only": true, "debuff": {"def": -1}, "target": "enemies", "desc": "Lowers every foe's Defense."},
	# team buffs
	"haste_tonic": {"name": "Haste Tonic", "kind": "use", "price": 140, "tier": 1, "battle_only": true, "buff": {"spd": 1}, "target": "allies", "desc": "Speeds up every beast in battle."},
	"iron_tonic": {"name": "Iron Tonic", "kind": "use", "price": 160, "tier": 3, "battle_only": true, "buff": {"def": 1}, "target": "allies", "desc": "Raises every beast's Defense."},
	"war_drum": {"name": "War Drum", "kind": "use", "price": 200, "tier": 4, "battle_only": true, "buff": {"atk": 1}, "target": "allies", "desc": "Raises every beast's Attack."},
	"smoke_bomb": {"name": "Smoke Bomb", "kind": "use", "price": 130, "tier": 2, "battle_only": true, "buff": {"eva": 1}, "target": "allies", "desc": "Raises every beast's Evasion."},
	"titan_tonic": {"name": "Titan Tonic", "kind": "use", "price": 1800, "tier": 10, "battle_only": true, "buff": {"atk": 1, "def": 1, "spd": 1}, "target": "allies", "desc": "Raises Attack, Defense and Speed of every beast."},

	# ---------------- beast gear ----------------
	"rope_collar": {"name": "Rope Collar", "kind": "gear", "price": 150, "tier": 0, "found": true, "mods": {"atk": 0.05}, "desc": "A plain braided collar. +5% Attack."},
	"cloth_band": {"name": "Cloth Band", "kind": "gear", "price": 150, "tier": 0, "found": true, "mods": {"def": 0.05}, "desc": "A soft starter band. +5% Defense."},
	"twine_anklet": {"name": "Twine Anklet", "kind": "gear", "price": 150, "tier": 0, "found": true, "mods": {"spd": 0.05}, "desc": "A light braided anklet. +5% Speed."},
	"power_collar": {"name": "Power Collar", "kind": "gear", "price": 600, "tier": 1, "mods": {"atk": 0.10}, "desc": "+10% Attack."},
	"stone_band": {"name": "Stone Band", "kind": "gear", "price": 600, "tier": 1, "mods": {"def": 0.12}, "desc": "+12% Defense."},
	"swift_anklet": {"name": "Swift Anklet", "kind": "gear", "price": 600, "tier": 1, "mods": {"spd": 0.12}, "desc": "+12% Speed."},
	"sage_bead": {"name": "Sage Bead", "kind": "gear", "price": 600, "tier": 1, "mods": {"spr": 0.12}, "desc": "+12% Spirit."},
	"vital_belt": {"name": "Vital Belt", "kind": "gear", "price": 700, "tier": 2, "mods": {"hp": 0.12}, "desc": "+12% max HP."},
	"lucky_clover": {"name": "Lucky Clover", "kind": "gear", "price": 800, "tier": 1, "fx": {"xp": 0.25}, "desc": "+25% experience."},
	"ember_charm": {"name": "Ember Charm", "kind": "gear", "price": 900, "tier": 3, "fx": {"boost_fire": 0.2}, "desc": "Fire moves deal +20%."},
	"tide_charm": {"name": "Tide Charm", "kind": "gear", "price": 900, "tier": 3, "fx": {"boost_water": 0.2}, "desc": "Water moves deal +20%."},
	"stone_charm": {"name": "Stone Charm", "kind": "gear", "price": 900, "tier": 3, "fx": {"boost_earth": 0.2}, "desc": "Earth moves deal +20%."},
	"gale_charm": {"name": "Gale Charm", "kind": "gear", "price": 900, "tier": 3, "fx": {"boost_air": 0.2}, "desc": "Air moves deal +20%."},
	"tide_pendant": {"name": "Tide Pendant", "kind": "gear", "price": 900, "tier": 2, "fx": {"heal_boost": 0.25}, "desc": "Healing given is 25% stronger."},
	"thorn_collar": {"name": "Thorn Collar", "kind": "gear", "price": 1100, "tier": 4, "fx": {"thorns": 0.12}, "desc": "Attackers take 12% of the damage back."},
	"feather_cloak": {"name": "Feather Cloak", "kind": "gear", "price": 1100, "tier": 4, "fx": {"eva": 1}, "desc": "Starts battles with raised Evasion."},
	"quick_claw": {"name": "Quick Claw", "kind": "gear", "price": 1200, "tier": 5, "fx": {"quick": 0.25}, "desc": "Sometimes acts first."},
	"shade_ward": {"name": "Shade Ward", "kind": "gear", "price": 1500, "tier": 6, "fx": {"ghost_resist": 0.3}, "desc": "Takes 30% less damage from ghost moves."},
	"phoenix_plume": {"name": "Phoenix Plume", "kind": "gear", "price": 2500, "tier": 8, "fx": {"phoenix": true}, "desc": "Revives once per battle at 25% HP."},
	"tidal_tiara": {"name": "Tidal Tiara", "kind": "gear", "price": 1200, "tier": 2, "grants": "mend", "desc": "Grants the move Mend."},
	"granite_greaves": {"name": "Granite Greaves", "kind": "gear", "price": 1200, "tier": 3, "grants": "guardian", "desc": "Grants the move Guardian."},
	"blaze_bracer": {"name": "Blaze Bracer", "kind": "gear", "price": 1500, "tier": 5, "grants": "battle_roar", "desc": "Grants the move Battle Roar."},
	"gale_ribbon": {"name": "Gale Ribbon", "kind": "gear", "price": 1500, "tier": 5, "grants": "tailwind", "desc": "Grants the move Tailwind."},
	"verdant_crown": {"name": "Verdant Crown", "kind": "gear", "price": 5200, "tier": 10, "mods": {"hp": 0.15, "def": 0.15, "spr": 0.15}, "desc": "Jungle relic. +15% HP, Defense and Spirit."},
	"sunfang_amulet": {"name": "Sunfang Amulet", "kind": "gear", "price": 5200, "tier": 10, "mods": {"atk": 0.2, "spd": 0.1}, "desc": "Jungle relic. +20% Attack, +10% Speed."},
	"storm_gauntlet": {"name": "Storm Gauntlet", "kind": "gear", "price": 2200, "tier": 7, "grants": "thunderclap", "desc": "Grants the move Thunderclap."},

	# ---------------- trainer gear ----------------
	# key items for the road puzzles
	# ---------------- fishing (see scripts/world/fishing.gd) ----------------
	"fishing_rod": {"name": "Fishing Pole", "kind": "key", "price": 0, "tier": 99,
		"desc": "Fisher Gil's spare pole. Face the water and press A to cast. Rippling water is where the fish are."},
	## bait: put on your hook from the bag; it stays on until something bites. Better bait brings up stronger,
	## rarer water beasts and bites sooner. sold_in: the towns whose apothecary or outfitter stocks it.
	"worm_bait": {"name": "Wriggly Worms", "kind": "bait", "bait": 1, "price": 25, "tier": 99, "sold_in": ["shellhaven", "kelpwick"],
		"desc": "Plain old worms. Water beasts of the shallows can't resist them."},
	"spinner_lure": {"name": "Spinner Lure", "kind": "bait", "bait": 2, "price": 70, "tier": 99, "sold_in": ["copperpick", "cogsworth", "emberfall"],
		"desc": "A flashy brass lure that twirls in the water. Draws up bigger water beasts."},
	"glow_lure": {"name": "Glow Lure", "kind": "bait", "bait": 3, "price": 180, "tier": 99, "sold_in": ["riverbend", "gravenmoor"],
		"desc": "It shines in the deep like a little moon. The rarest water beasts rise to it."},
	"bridge_log": {"name": "Log", "kind": "key", "price": 0, "tier": 99, "desc": "A sturdy log from a tree the storm knocked down. Five of them would bridge the creek on the Coastal Path."},
	"bridge_planks": {"name": "Bridge Planks", "kind": "key", "price": 0, "tier": 99, "desc": "A bundle of sturdy planks, just right for patching a footbridge."},
	"miner_pass": {"name": "Miner's Pass", "kind": "key", "price": 0, "tier": 99, "desc": "Signed by Foreman Gorran. Lets you through the Mine Road checkpoint."},
	"reed_flute": {"name": "Reed Flute", "kind": "tgear", "slot": "flute", "price": 0, "tier": 99, "fx": {}, "desc": "A simple flute. Plays the songs you know."},
	"silver_flute": {"name": "Silver Flute", "kind": "tgear", "slot": "flute", "price": 1500, "tier": 3, "fx": {"time": 0.1, "capture": 0.05}, "desc": "10% more time to play each song, +5% capture."},
	"golden_flute": {"name": "Golden Flute", "kind": "tgear", "slot": "flute", "price": 4000, "tier": 7, "fx": {"time": 0.2, "capture": 0.1}, "desc": "20% more time to play each song, +10% capture."},
	"worn_cap": {"name": "Worn Cap", "kind": "tgear", "slot": "head", "price": 120, "tier": 0, "found": true, "fx": {"capture": 0.03}, "desc": "A faded old trainer's cap. +3% capture chance."},
	"old_sneakers": {"name": "Old Sneakers", "kind": "tgear", "slot": "feet", "price": 150, "tier": 0, "found": true, "fx": {"speed": 0.1}, "desc": "Scuffed but comfy. Walk 10% faster."},
	"explorer_hat": {"name": "Explorer Hat", "kind": "tgear", "slot": "head", "price": 800, "tier": 1, "fx": {"capture": 0.05}, "desc": "+5% capture chance."},
	"sage_hood": {"name": "Sage Hood", "kind": "tgear", "slot": "head", "price": 1500, "tier": 4, "fx": {"xp": 0.1}, "desc": "Party gains +10% experience."},
	"hiking_boots": {"name": "Hiking Boots", "kind": "tgear", "slot": "feet", "price": 600, "tier": 1, "fx": {"speed": 0.25}, "desc": "Walk 25% faster."},
	"wind_sandals": {"name": "Wind Sandals", "kind": "tgear", "slot": "feet", "price": 1800, "tier": 5, "fx": {"speed": 0.45}, "desc": "Walk 45% faster."},
	"calm_lantern": {"name": "Calm Lantern", "kind": "tgear", "slot": "acc", "price": 900, "tier": 2, "fx": {"encounter": -0.4}, "desc": "40% fewer wild encounters."},
	"lure_charm": {"name": "Lure Charm", "kind": "tgear", "slot": "acc", "price": 900, "tier": 3, "fx": {"encounter": 0.4, "abandoned": 0.03}, "desc": "More encounters, more abandoned beasts."},
	"jade_flute": {"name": "Jade Flute", "kind": "tgear", "slot": "flute", "price": 9000, "tier": 10, "fx": {"time": 0.3, "capture": 0.18}, "desc": "Carved in Vinehollow. 30% more time to play each song, +18% capture."},
	"canopy_boots": {"name": "Canopy Boots", "kind": "tgear", "slot": "feet", "price": 4500, "tier": 10, "fx": {"speed": 0.6}, "desc": "Walk 60% faster."},
	"merchant_badge": {"name": "Merchant Badge", "kind": "tgear", "slot": "acc", "price": 2000, "tier": 4, "fx": {"discount": 0.1}, "desc": "10% off in every shop."},
}

const SLOT_NAMES := {"flute": "Flute", "head": "Head", "feet": "Feet", "acc": "Accessory"}


static func get_item(id: String) -> Dictionary:
	if id.begins_with("tome_"):
		return tome(id.substr(5))
	if id.begins_with("sheet_"):
		return sheet(id.substr(6))
	return ITEMS.get(id, {"name": id, "kind": "none", "price": 0, "desc": ""})


static func item_name(id: String) -> String:
	return get_item(id).get("name", id)


static func tome(move_id: String) -> Dictionary:
	var m := MoveDB.get_move(move_id)
	var price := 300 + int(m.get("power", 60)) * 8 + MoveDB.tier(move_id) * 150
	return {
		"name": "Tome: " + m["name"], "kind": "tome", "move": move_id, "price": price,
		"tier": MoveDB.tier(move_id) * 2, "desc": "Teaches %s.\n%s" % [m["name"], MoveDB.summary(move_id)],
	}


## Sheet music: play it back well enough (from the bag or at the music shop) to learn the song.
static func sheet(song_id: String) -> Dictionary:
	var s := SongDB.get_song(song_id)
	return {"name": "Sheet Music: " + s["name"], "kind": "sheet", "song": song_id, "price": int(s.get("shop", 1000)),
		"desc": "%s
Read it, then play it back to learn it." % SongDB.describe(song_id)}


## Items from `kind` stocked at shop tier `t`, deterministic per shop seed.
static func stock(kind: String, t: int, seed_key: String, max_count := 8) -> Array:
	var premium := []
	var out := []
	for id in ITEMS:
		var it: Dictionary = ITEMS[id]
		if it["kind"] != kind or int(it["tier"]) > t or it.get("found", false):
			continue
		if int(it["tier"]) >= 10:
			if t >= 12:
				premium.append(id)
		else:
			out.append(id)
	var keep := max_count - premium.size()
	if out.size() > keep:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_key.hash()
		while out.size() > keep:
			# drop cheap early items first in late-game shops
			var i := rng.randi_range(0, out.size() - 1)
			if t >= 6 and rng.randf() < 0.6:
				i = rng.randi_range(0, mini(3, out.size() - 1))
			out.remove_at(i)
	return premium + out


## Battle items the trainer can use, by kind (for shop variety).
static func battle_kind(id: String) -> String:
	var it := get_item(id)
	if it.has("bomb"):
		return "bomb"
	if it.has("status") or it.has("debuff"):
		return "hex"
	if it.get("target", "") == "allies" and it.has("buff"):
		return "tonic"
	return "care"


static func tome_stock(t: int, seed_key: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_key.hash()
	var out := []
	for el in ["fire", "water", "earth", "air", "neutral"]:
		var pool: Array = MoveDB.POOLS[el]
		var cands := []
		for mv in pool:
			if MoveDB.tier(mv) * 2 <= t + 1:
				cands.append(mv)
		cands.shuffle()
		for i in mini(2, cands.size()):
			out.append("tome_" + cands[i])
	return out
