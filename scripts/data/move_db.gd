extends RefCounted
## All combat moves.
## kind: attack | heal | buff | debuff | status | shield | taunt | revive | cleanse | special
## target: enemy | enemies | ally | allies | self | ally_ko
## fx keys: status, chance, recoil, drain, crit, buff, self_buff, debuff, heal_pct, regen,
##          shield_pct, taunt, counter, vanish, wraith, cure, revive_pct, ignore_eva, pierce

const MOVES := {
	# ---------------- Neutral ----------------
	"tackle": {"name": "Tackle", "el": "neutral", "kind": "attack", "power": 35, "acc": 95, "target": "enemy", "desc": "A full-body charge."},
	"scratch": {"name": "Scratch", "el": "neutral", "kind": "attack", "power": 40, "acc": 100, "target": "enemy", "desc": "Rakes the foe with claws."},
	"bite": {"name": "Bite", "el": "neutral", "kind": "attack", "power": 55, "acc": 95, "target": "enemy", "fx": {"status": "fear", "chance": 0.15}, "desc": "May frighten the foe."},
	"headbutt": {"name": "Headbutt", "el": "neutral", "kind": "attack", "power": 70, "acc": 90, "target": "enemy", "fx": {"status": "stun", "chance": 0.1}, "desc": "May stun the foe."},
	"quick_strike": {"name": "Quick Strike", "el": "neutral", "kind": "attack", "power": 40, "acc": 100, "target": "enemy", "prio": 1, "desc": "Always strikes first."},
	"howl": {"name": "Howl", "el": "neutral", "kind": "buff", "target": "self", "fx": {"self_buff": {"atk": 1}}, "desc": "Raises own Attack."},
	"brace": {"name": "Brace", "el": "neutral", "kind": "buff", "target": "self", "fx": {"self_buff": {"def": 2}}, "desc": "Sharply raises own Defense."},

	# ---------------- Fire: offense tanks ----------------
	"ember": {"name": "Ember", "el": "fire", "kind": "attack", "power": 40, "acc": 100, "target": "enemy", "fx": {"status": "burn", "chance": 0.1}, "desc": "May burn."},
	"flame_fang": {"name": "Flame Fang", "el": "fire", "kind": "attack", "power": 60, "acc": 95, "target": "enemy", "fx": {"status": "burn", "chance": 0.15}, "desc": "Blazing bite. May burn."},
	"fire_spin": {"name": "Fire Spin", "el": "fire", "kind": "attack", "power": 35, "acc": 95, "target": "enemies", "fx": {"status": "burn", "chance": 0.1}, "desc": "Hits all foes. May burn."},
	"magma_skin": {"name": "Magma Skin", "el": "fire", "kind": "buff", "target": "self", "fx": {"self_buff": {"atk": 1, "def": 1}}, "desc": "Raises own Attack and Defense."},
	"searing_taunt": {"name": "Searing Taunt", "el": "fire", "kind": "taunt", "target": "self", "fx": {"taunt": 3, "self_buff": {"def": 1}}, "desc": "Draws foes' attacks for 3 turns."},
	"lava_slam": {"name": "Lava Slam", "el": "fire", "kind": "attack", "power": 80, "acc": 90, "target": "enemy", "fx": {"debuff": {"def": -1}, "chance": 0.3}, "desc": "May lower Defense."},
	"kindle": {"name": "Kindle", "el": "fire", "kind": "heal", "target": "self", "cd": 2, "fx": {"heal_pct": 0.25, "self_buff": {"atk": 1}}, "desc": "Heals 25% and raises Attack."},
	"heat_wave": {"name": "Heat Wave", "el": "fire", "kind": "attack", "power": 55, "acc": 90, "target": "enemies", "fx": {"status": "burn", "chance": 0.1}, "desc": "Scorches all foes."},
	"battle_roar": {"name": "Battle Roar", "el": "fire", "kind": "buff", "target": "allies", "cd": 2, "fx": {"buff": {"atk": 1}}, "desc": "Raises Attack of all allies."},
	"blaze_rush": {"name": "Blaze Rush", "el": "fire", "kind": "attack", "power": 95, "acc": 95, "target": "enemy", "fx": {"recoil": 0.25}, "desc": "Reckless charge. Takes recoil."},
	"phoenix_blaze": {"name": "Phoenix Blaze", "el": "fire", "kind": "attack", "power": 100, "acc": 90, "target": "enemy", "cd": 2, "fx": {"drain": 0.3}, "desc": "Absorbs 30% of damage dealt."},
	"overheat": {"name": "Overheat", "el": "fire", "kind": "attack", "power": 140, "acc": 90, "target": "enemy", "cd": 3, "fx": {"self_buff": {"atk": -2}}, "desc": "Huge blast. Lowers own Attack."},
	"inferno": {"name": "Inferno", "el": "fire", "kind": "attack", "power": 110, "acc": 85, "target": "enemies", "cd": 3, "fx": {"status": "burn", "chance": 0.25}, "desc": "Engulfs all foes."},

	# ---------------- Water: healers ----------------
	"water_jet": {"name": "Water Jet", "el": "water", "kind": "attack", "power": 40, "acc": 100, "target": "enemy", "desc": "A jet of water."},
	"mend": {"name": "Mend", "el": "water", "kind": "heal", "target": "ally", "fx": {"heal_pct": 0.35}, "desc": "Heals an ally 35%."},
	"bubble_burst": {"name": "Bubble Burst", "el": "water", "kind": "attack", "power": 35, "acc": 95, "target": "enemies", "fx": {"debuff": {"spd": -1}, "chance": 0.2}, "desc": "Hits all foes. May slow."},
	"aqua_veil": {"name": "Aqua Veil", "el": "water", "kind": "buff", "target": "ally", "fx": {"regen": 4}, "desc": "Ally regenerates for 4 turns."},
	"riptide": {"name": "Riptide", "el": "water", "kind": "attack", "power": 60, "acc": 95, "target": "enemy", "fx": {"debuff": {"spd": -1}, "chance": 0.5}, "desc": "Often lowers Speed."},
	"cleanse": {"name": "Cleanse", "el": "water", "kind": "cleanse", "target": "ally", "fx": {"heal_pct": 0.15, "cure": true}, "desc": "Cures status and heals a little."},
	"life_tide": {"name": "Life Tide", "el": "water", "kind": "attack", "power": 65, "acc": 95, "target": "enemy", "fx": {"drain": 0.5}, "desc": "Absorbs 50% of damage dealt."},
	"soothing_rain": {"name": "Soothing Rain", "el": "water", "kind": "heal", "target": "allies", "cd": 2, "fx": {"heal_pct": 0.25}, "desc": "Heals all allies 25%."},
	"tidal_crash": {"name": "Tidal Crash", "el": "water", "kind": "attack", "power": 85, "acc": 90, "target": "enemy", "desc": "A crushing wave."},
	"whirlpool": {"name": "Whirlpool", "el": "water", "kind": "attack", "power": 60, "acc": 90, "target": "enemies", "cd": 2, "fx": {"debuff": {"eva": -1}, "chance": 0.3}, "desc": "Traps all foes."},
	"revitalize": {"name": "Revitalize", "el": "water", "kind": "revive", "target": "ally_ko", "cd": 4, "fx": {"revive_pct": 0.4}, "desc": "Revives a fainted ally at 40%."},
	"hydro_cannon": {"name": "Hydro Cannon", "el": "water", "kind": "attack", "power": 115, "acc": 85, "target": "enemy", "cd": 2, "desc": "Massive water blast."},
	"tsunami": {"name": "Tsunami", "el": "water", "kind": "attack", "power": 100, "acc": 85, "target": "enemies", "cd": 4, "desc": "Floods all foes."},

	# ---------------- Earth: defenders ----------------
	"pebble_toss": {"name": "Pebble Toss", "el": "earth", "kind": "attack", "power": 40, "acc": 100, "target": "enemy", "desc": "Flings stones."},
	"fortify": {"name": "Fortify", "el": "earth", "kind": "buff", "target": "self", "fx": {"self_buff": {"def": 2, "spr": 1}}, "desc": "Sharply raises Defense, raises Spirit."},
	"mud_shot": {"name": "Mud Shot", "el": "earth", "kind": "attack", "power": 50, "acc": 95, "target": "enemy", "fx": {"status": "blind", "chance": 0.3}, "desc": "May blind."},
	"stone_wall": {"name": "Stone Wall", "el": "earth", "kind": "shield", "target": "ally", "fx": {"shield_pct": 0.3}, "desc": "Shields an ally for 30% of its HP."},
	"rock_slam": {"name": "Rock Slam", "el": "earth", "kind": "attack", "power": 75, "acc": 90, "target": "enemy", "desc": "Slams with rock."},
	"guardian": {"name": "Guardian", "el": "earth", "kind": "taunt", "target": "self", "fx": {"taunt": 3, "self_buff": {"def": 1}}, "desc": "Protects allies by drawing attacks."},
	"thorn_spikes": {"name": "Thorn Spikes", "el": "earth", "kind": "buff", "target": "self", "fx": {"counter": 3}, "desc": "Reflects 30% of damage taken for 3 turns."},
	"iron_root": {"name": "Iron Root", "el": "earth", "kind": "buff", "target": "self", "cd": 2, "fx": {"regen": 4, "self_buff": {"def": 1}}, "desc": "Regenerates and raises Defense."},
	"boulder_crush": {"name": "Boulder Crush", "el": "earth", "kind": "attack", "power": 90, "acc": 85, "target": "enemy", "fx": {"status": "stun", "chance": 0.2}, "desc": "May stun."},
	"bulwark": {"name": "Bulwark", "el": "earth", "kind": "buff", "target": "allies", "cd": 2, "fx": {"buff": {"def": 1}}, "desc": "Raises Defense of all allies."},
	"quake": {"name": "Quake", "el": "earth", "kind": "attack", "power": 70, "acc": 95, "target": "enemies", "cd": 2, "desc": "Shakes all foes."},
	"earthen_aegis": {"name": "Earthen Aegis", "el": "earth", "kind": "shield", "target": "allies", "cd": 4, "fx": {"shield_pct": 0.18}, "desc": "Shields all allies."},
	"landslide": {"name": "Landslide", "el": "earth", "kind": "attack", "power": 105, "acc": 85, "target": "enemies", "cd": 3, "desc": "Buries all foes."},

	# ---------------- Air: status & evasion ----------------
	"gust": {"name": "Gust", "el": "air", "kind": "attack", "power": 40, "acc": 100, "target": "enemy", "desc": "A sharp gust."},
	"blinding_dust": {"name": "Blinding Dust", "el": "air", "kind": "status", "acc": 85, "target": "enemy", "fx": {"status": "blind", "chance": 1.0}, "desc": "Blinds a foe."},
	"static_shock": {"name": "Static Shock", "el": "air", "kind": "attack", "power": 45, "acc": 100, "target": "enemy", "fx": {"status": "shock", "chance": 0.4}, "desc": "Often paralyzes."},
	"mirage": {"name": "Mirage", "el": "air", "kind": "buff", "target": "self", "fx": {"self_buff": {"eva": 2}}, "desc": "Sharply raises Evasion."},
	"wind_slash": {"name": "Wind Slash", "el": "air", "kind": "attack", "power": 60, "acc": 100, "target": "enemy", "fx": {"crit": 0.25}, "desc": "High critical chance."},
	"lullaby_breeze": {"name": "Lullaby Breeze", "el": "air", "kind": "status", "acc": 70, "target": "enemy", "fx": {"status": "sleep", "chance": 1.0}, "desc": "Puts a foe to sleep."},
	"toxic_wind": {"name": "Toxic Wind", "el": "air", "kind": "status", "acc": 80, "target": "enemies", "fx": {"status": "poison", "chance": 1.0}, "desc": "Poisons all foes."},
	"cyclone": {"name": "Cyclone", "el": "air", "kind": "attack", "power": 50, "acc": 95, "target": "enemies", "fx": {"status": "confuse", "chance": 0.15}, "desc": "Hits all foes. May confuse."},
	"tailwind": {"name": "Tailwind", "el": "air", "kind": "buff", "target": "allies", "cd": 2, "fx": {"buff": {"spd": 1}}, "desc": "Raises Speed of all allies."},
	"gale_feint": {"name": "Gale Feint", "el": "air", "kind": "attack", "power": 65, "acc": 100, "target": "enemy", "prio": 1, "fx": {"ignore_eva": true}, "desc": "Strikes first. Never misses."},
	"vanish": {"name": "Vanish", "el": "air", "kind": "special", "target": "self", "cd": 3, "fx": {"vanish": true}, "desc": "Evades every attack this turn."},
	"thunderclap": {"name": "Thunderclap", "el": "air", "kind": "attack", "power": 90, "acc": 90, "target": "enemy", "fx": {"status": "shock", "chance": 0.2}, "desc": "May paralyze."},
	"featherstorm": {"name": "Featherstorm", "el": "air", "kind": "attack", "power": 75, "acc": 90, "target": "enemies", "cd": 2, "fx": {"debuff": {"acc": -1}, "chance": 0.2}, "desc": "Hits all foes."},

	# ---------------- Ghost: Umbral Legion ----------------
	"shadow_claw": {"name": "Shadow Claw", "el": "ghost", "kind": "attack", "power": 80, "acc": 100, "target": "enemy", "fx": {"crit": 0.2}, "desc": "Rends with darkness."},
	"haunt": {"name": "Haunt", "el": "ghost", "kind": "status", "acc": 90, "target": "enemy", "fx": {"status": "haunt", "chance": 1.0}, "desc": "Curses a foe: damage each turn, no healing."},
	"grave_chill": {"name": "Grave Chill", "el": "ghost", "kind": "attack", "power": 60, "acc": 95, "target": "enemy", "fx": {"debuff": {"spd": -1}, "chance": 0.6}, "desc": "Often lowers Speed."},
	"soul_drain": {"name": "Soul Drain", "el": "ghost", "kind": "attack", "power": 70, "acc": 95, "target": "enemy", "fx": {"drain": 0.5}, "desc": "Steals life force."},
	"nightmare": {"name": "Nightmare", "el": "ghost", "kind": "attack", "power": 60, "acc": 90, "target": "enemy", "fx": {"status": "sleep", "chance": 0.3}, "desc": "May put a foe to sleep."},
	"dread_howl": {"name": "Dread Howl", "el": "ghost", "kind": "debuff", "acc": 100, "target": "enemies", "fx": {"debuff": {"atk": -1}, "status": "fear", "chance": 0.3}, "desc": "Lowers foes' Attack; may terrify."},
	"wraith_form": {"name": "Wraith Form", "el": "ghost", "kind": "buff", "target": "self", "cd": 3, "fx": {"self_buff": {"eva": 2}, "wraith": 3}, "desc": "Becomes untouchable by status."},
	"void_pulse": {"name": "Void Pulse", "el": "ghost", "kind": "attack", "power": 75, "acc": 95, "target": "enemies", "desc": "Hits all foes."},
	"phantom_rush": {"name": "Phantom Rush", "el": "ghost", "kind": "attack", "power": 110, "acc": 100, "target": "enemy", "cd": 2, "fx": {"ignore_eva": true, "pierce": true}, "desc": "Ignores evasion and shields."},
	"eclipse": {"name": "Eclipse", "el": "ghost", "kind": "attack", "power": 150, "acc": 90, "target": "enemies", "cd": 4, "desc": "Blots out the sun."},

	# ---------------- Signature moves: taught only by a town's mascot, to its own race (see SIGNATURE) ----------------
	"bandit_blaze": {"name": "Bandit Blaze", "el": "fire", "kind": "attack", "power": 150, "acc": 90, "target": "enemy", "cd": 3, "fx": {"status": "burn", "chance": 0.3}, "desc": "Cocoon Cove's masked whirl of flame. May burn."},
	"tidewater_torrent": {"name": "Tidewater Torrent", "el": "water", "kind": "attack", "power": 130, "acc": 90, "target": "enemy", "cd": 3, "fx": {"debuff": {"spd": -1}, "chance": 0.5}, "desc": "The whole harbour at once. Often lowers Speed."},
	"pearl_cannon": {"name": "Pearl Cannon", "el": "water", "kind": "attack", "power": 130, "acc": 90, "target": "enemy", "cd": 3, "fx": {"self_buff": {"def": 1}}, "desc": "Fires a polished pearl. Raises own Defense."},
	"kelp_maelstrom": {"name": "Kelp Maelstrom", "el": "water", "kind": "attack", "power": 130, "acc": 90, "target": "enemy", "cd": 3, "fx": {"debuff": {"eva": -1}, "chance": 0.4}, "desc": "A whirl of sea and kelp. May tangle the foe."},
	"sirocco": {"name": "Sirocco", "el": "air", "kind": "attack", "power": 115, "acc": 90, "target": "enemy", "cd": 3, "fx": {"status": "confuse", "chance": 0.3}, "desc": "The oasis's scorching desert wind. May confuse."},
	"tumbleweed_twister": {"name": "Tumbleweed Twister", "el": "air", "kind": "attack", "power": 115, "acc": 90, "target": "enemy", "cd": 3, "fx": {"crit": 0.3}, "desc": "A whirling frontier gale. High critical chance."},
	"motherlode": {"name": "Motherlode", "el": "earth", "kind": "attack", "power": 125, "acc": 90, "target": "enemy", "cd": 3, "fx": {"status": "stun", "chance": 0.25}, "desc": "A seam of solid ore, dropped from above. May stun."},
	"clockwork_crusher": {"name": "Clockwork Crusher", "el": "earth", "kind": "attack", "power": 125, "acc": 90, "target": "enemy", "cd": 3, "fx": {"pierce": true}, "desc": "Iron gears grind through any shield."},
	"caldera_burst": {"name": "Caldera Burst", "el": "fire", "kind": "attack", "power": 150, "acc": 90, "target": "enemy", "cd": 3, "fx": {"status": "burn", "chance": 0.3}, "desc": "Mount Cinder's heart, let loose. May burn."},
	"elder_grove": {"name": "Elder Grove", "el": "earth", "kind": "attack", "power": 125, "acc": 90, "target": "enemy", "cd": 3, "fx": {"drain": 0.3}, "desc": "Ancient roots that drink. Absorbs 30% of damage dealt."},
	"riverbend_rapids": {"name": "Riverbend Rapids", "el": "water", "kind": "attack", "power": 130, "acc": 90, "target": "enemy", "cd": 3, "fx": {"debuff": {"atk": -1}, "chance": 0.4}, "desc": "White water round every bend. May lower Attack."},
	"moonlit_gale": {"name": "Moonlit Gale", "el": "air", "kind": "attack", "power": 115, "acc": 90, "target": "enemy", "cd": 3, "fx": {"status": "sleep", "chance": 0.25}, "desc": "A silver wind off the moor. May lull the foe to sleep."},
}

## Each town's mascot (WorldDB.TOWNS "mascot", a race) teaches a beast of its own race this move once it has reached
## SIGNATURE_LEVEL: elemental, mightier than any move of its element a beast learns by levelling, and taught by nobody
## else (merging keeps it only for a beast of that race, see beasts.gd merge).
const SIGNATURE := {0: "bandit_blaze", 13: "tidewater_torrent", 20: "pearl_cannon", 14: "kelp_maelstrom", 45: "sirocco",
	37: "tumbleweed_twister", 32: "motherlode", 34: "clockwork_crusher", 7: "caldera_burst", 31: "elder_grove",
	21: "riverbend_rapids", 41: "moonlit_gale"}
const SIGNATURE_LEVEL := 40

## Ordered by strength; used to build learnsets.
const POOLS := {
	"fire": ["ember", "flame_fang", "magma_skin", "fire_spin", "searing_taunt", "lava_slam", "kindle", "heat_wave", "battle_roar", "blaze_rush", "phoenix_blaze", "overheat", "inferno"],
	"water": ["water_jet", "mend", "bubble_burst", "aqua_veil", "riptide", "cleanse", "life_tide", "soothing_rain", "tidal_crash", "whirlpool", "revitalize", "hydro_cannon", "tsunami"],
	"earth": ["pebble_toss", "fortify", "mud_shot", "stone_wall", "rock_slam", "guardian", "thorn_spikes", "iron_root", "boulder_crush", "bulwark", "quake", "earthen_aegis", "landslide"],
	"air": ["gust", "blinding_dust", "static_shock", "mirage", "wind_slash", "lullaby_breeze", "toxic_wind", "cyclone", "tailwind", "gale_feint", "vanish", "thunderclap", "featherstorm"],
	"ghost": ["shadow_claw", "haunt", "grave_chill", "soul_drain", "nightmare", "dread_howl", "wraith_form", "void_pulse", "phantom_rush", "eclipse"],
	"neutral": ["tackle", "scratch", "bite", "headbutt", "quick_strike", "howl", "brace"],
}

const STATUS_NAMES := {
	"burn": "Burned", "poison": "Poisoned", "sleep": "Asleep", "shock": "Paralyzed",
	"blind": "Blinded", "confuse": "Confused", "fear": "Afraid", "stun": "Stunned", "haunt": "Haunted",
}


static func get_move(id: String) -> Dictionary:
	return MOVES.get(id, MOVES["tackle"])


static func is_signature(id: String) -> bool:
	return SIGNATURE.values().has(id)


## MP an attack costs: elemental attacks cost about a tenth of their power (at least 2); regular (neutral) attacks
## and every non-attack move are free.
static func mp_cost(id: String) -> int:
	var m := get_move(id)
	if m.get("kind", "") != "attack" or String(m.get("el", "neutral")) == "neutral":
		return 0
	return maxi(2, int(round(float(m.get("power", 40)) / 10.0)))


static func power(id: String) -> int:
	return int(get_move(id).get("power", 0))


static func is_damaging(id: String) -> bool:
	return get_move(id).get("kind", "") == "attack"


static func tier(id: String) -> int:
	var m := get_move(id)
	var pool: Array = POOLS.get(m["el"], [])
	var i := pool.find(id)
	if i < 0:
		return 0
	return int(i * 5 / max(1, pool.size()))


static func summary(id: String) -> String:
	var m := get_move(id)
	var parts := []
	parts.append(m["el"].to_upper())
	if m.has("power"):
		parts.append("Pow %d" % m["power"])
	if m.has("acc"):
		parts.append("Acc %d" % m["acc"])
	var t: String = m.get("target", "enemy")
	var tnames := {"enemy": "1 foe", "enemies": "all foes", "ally": "1 ally", "allies": "all allies", "self": "self", "ally_ko": "fainted ally"}
	parts.append(tnames.get(t, t))
	if m.get("cd", 0) > 0:
		parts.append("Cooldown %d" % m["cd"])
	return "  ".join(parts) + "\n" + m.get("desc", "")
