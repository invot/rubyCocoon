extends RefCounted
## Flute songs. Three kinds:
##   "effect" songs are played as the trainer's turn in any battle. They raise your beasts' stats, heal or cure
##            them, or lower the foes' stats and lull them into sleep, poison, confusion...
##            The better you play, the stronger the effect.
##   "charm"  songs win a wild beast over. The main one is Capture, which grows in levels (capture1, capture2, ...):
##            Capture N charms beasts up to CAPTURE_CAPS[N - 1], and only beasts no stronger than your strongest
##            beast, unless you play it flawlessly. When one of your beasts reaches the cap, the next level can be
##            practised from the Start book. The Requiem of Dusk charms ghost beasts by the same rules.
##   "summon" songs are the temples' own songs, taught by each temple's singing stones (Places.song_stone). Played to
##            the temple's guardian once it's worn down, the song captures it; from then on it calls the guardian
##            into any battle (the Summon command), once per battle, for a shield point. Each starts as long as its
##            temple's stone puzzle ("min_notes") and grows with mastery like the others.
## Playing: see flute_game.gd. A song is sheet music of 4 to 16 notes that you memorise and play back against the clock.
## Higher levels are longer, add ↑ then ↓ above the first four notes, and finally chords (A or B with a direction).
## Learning: Uncle Rafe in Tidewater hands over your father's flute and teaches Weaken and Capture I. Arena masters teach strong battle
## songs. The music shop in Cogsworth plays one song for free (once) and sells sheet music. A few rival trainers
## play their own songs in battle; play one back without a single mistake after the battle and it's yours.
##
## Effect keys: target (enemy, enemies, ally, allies), buff / debuff {stat: stages}, status + chance,
## heal_pct, cure. "shop": sold as sheet music in Cogsworth (price).

const SONGS := {
	# ---------------- effect songs ----------------
	"weaken": {"name": "Weaken", "kind": "effect", "target": "enemies", "debuff": {"def": -1},
		"bpm": 84, "tier": 0, "root": 72, "from": "Uncle Rafe in Tidewater"},
	"jig": {"name": "Swift Jig", "kind": "effect", "target": "allies", "buff": {"spd": 1},
		"bpm": 96, "tier": 1, "root": 76, "from": "Bard Tamsin on the Coastal Path / Cogsworth music shop", "shop": 700},
	"hymn": {"name": "Battle Hymn", "kind": "effect", "target": "allies", "buff": {"atk": 1},
		"bpm": 92, "tier": 2, "root": 69, "from": "Cogsworth music shop", "shop": 1100},
	"chorale": {"name": "Iron Chorale", "kind": "effect", "target": "allies", "buff": {"def": 1},
		"bpm": 80, "tier": 2, "root": 67, "from": "Cogsworth music shop", "shop": 1100},
	"mending": {"name": "Mending Melody", "kind": "effect", "target": "allies", "heal_pct": 0.22,
		"bpm": 82, "tier": 3, "root": 74, "from": "Cogsworth music shop / Bard Oriel on Summit Pass", "shop": 1600},
	"canon": {"name": "Cleansing Canon", "kind": "effect", "target": "allies", "cure": true, "heal_pct": 0.06,
		"bpm": 88, "tier": 2, "root": 71, "from": "Cogsworth music shop", "shop": 1000},
	"minuet": {"name": "Mirage Minuet", "kind": "effect", "target": "allies", "buff": {"eva": 1},
		"bpm": 100, "tier": 4, "root": 77, "from": "Jungle Huntress Aeris (Vinehollow Arena)"},
	"lullaby": {"name": "Drowsy Lullaby", "kind": "effect", "target": "enemies", "status": "sleep", "chance": 0.3,
		"bpm": 72, "tier": 2, "root": 69, "from": "Reef Warden Nerissa (Kelpwick Arena) / Cogsworth music shop", "shop": 1400},
	"sluggish": {"name": "Sluggish Waltz", "kind": "effect", "target": "enemies", "debuff": {"spd": -1},
		"bpm": 78, "tier": 1, "root": 65, "from": "Cogsworth music shop", "shop": 800},
	"dazzle": {"name": "Dazzling Trill", "kind": "effect", "target": "enemies", "debuff": {"acc": -1},
		"bpm": 104, "tier": 2, "root": 79, "from": "Bard Wren on the Dune Road / Cogsworth music shop", "shop": 1000},
	"venom": {"name": "Venom Serenade", "kind": "effect", "target": "enemy", "status": "poison", "chance": 0.7,
		"bpm": 90, "tier": 3, "root": 66, "from": "Bard Silas on the Mesa Trail"},
	"static": {"name": "Static Polka", "kind": "effect", "target": "enemy", "status": "shock", "chance": 0.6,
		"bpm": 110, "tier": 4, "root": 73, "from": "Chief Engineer Volta (Cogsworth Arena)"},
	"discord": {"name": "Discord", "kind": "effect", "target": "enemies", "status": "confuse", "chance": 0.35,
		"bpm": 108, "tier": 5, "root": 68, "from": "Commander Nyx"},
	"dread": {"name": "Dread March", "kind": "effect", "target": "enemies", "debuff": {"atk": -1}, "status": "fear", "chance": 0.25,
		"bpm": 96, "tier": 6, "root": 64, "from": "General Vexmora"},
	# ---------------- arena songs: strong battle songs taught by the arena masters ----------------
	"shanty": {"name": "Tidewater Shanty", "kind": "effect", "target": "allies", "buff": {"atk": 1, "spd": 1},
		"bpm": 90, "tier": 1, "root": 74, "from": "Tide Captain Marina (Tidewater Arena)"},
	"coral": {"name": "Coral Hymn", "kind": "effect", "target": "allies", "buff": {"def": 1}, "heal_pct": 0.15,
		"bpm": 94, "tier": 2, "root": 71, "from": "Reef Warden Nerissa (Kelpwick Arena)"},
	"reel": {"name": "Sundown Reel", "kind": "effect", "target": "enemies", "debuff": {"spd": -1, "acc": -1},
		"bpm": 102, "tier": 3, "root": 76, "from": "Gunslinger Rosa (Sundown Gulch Arena)"},
	"dirge": {"name": "Copperpick Dirge", "kind": "effect", "target": "enemies", "debuff": {"atk": -1, "def": -1},
		"bpm": 106, "tier": 4, "root": 67, "from": "Mine Foreman Gorran (Copperpick Arena)"},
	"anvil": {"name": "Anvil March", "kind": "effect", "target": "allies", "buff": {"atk": 1, "def": 1},
		"bpm": 112, "tier": 5, "root": 69, "from": "Chief Engineer Volta (Cogsworth Arena)"},
	"waltz": {"name": "Ember Waltz", "kind": "effect", "target": "enemies", "status": "burn", "chance": 0.45,
		"bpm": 116, "tier": 6, "root": 77, "from": "Forgemaster Brann (Emberfall Arena)"},
	"fanfare": {"name": "Jungle Fanfare", "kind": "effect", "target": "allies", "buff": {"atk": 1, "def": 1, "spd": 1},
		"bpm": 122, "tier": 7, "root": 72, "from": "Jungle Huntress Aeris (Vinehollow Arena)"},
	"anthem": {"name": "River Anthem", "kind": "effect", "target": "allies", "heal_pct": 0.3, "cure": true, "buff": {"spr": 1},
		"bpm": 128, "tier": 8, "root": 74, "from": "River Ranger Skye (Riverbend Arena)"},
	# ---------------- charm songs (Capture is generated per level, see get_song) ----------------
	"requiem": {"name": "Requiem of Dusk", "kind": "charm", "bpm": 100, "tier": 7, "from": "the Gravenmoor gravedigger", "root": 69, "ghost": true},
	# ---------------- temple songs: capture the temple's guardian, then summon it (see WorldDB.TEMPLES) ----------------
	"song_tides": {"name": "Song of Tides", "kind": "summon", "summon": "water", "target": "enemies", "min_notes": 4,
		"bpm": 84, "tier": 2, "root": 72, "from": "the singing stones of the Temple of Tides"},
	"song_winds": {"name": "Song of Winds", "kind": "summon", "summon": "air", "target": "enemies", "min_notes": 5,
		"bpm": 96, "tier": 4, "root": 76, "from": "the singing stones of the Temple of Winds"},
	"song_flame": {"name": "Song of Flame", "kind": "summon", "summon": "fire", "target": "enemies", "min_notes": 6,
		"bpm": 104, "tier": 5, "root": 69, "from": "the singing stones of the Temple of Flame"},
	"song_roots": {"name": "Song of Roots", "kind": "summon", "summon": "earth", "target": "enemies", "min_notes": 7,
		"bpm": 92, "tier": 6, "root": 67, "from": "the singing stones of the Temple of Roots"},
	"song_dusk": {"name": "Nocturne of the Crypt", "kind": "summon", "summon": "ghost", "target": "enemies", "min_notes": 8,
		"bpm": 98, "tier": 7, "root": 66, "ghost": true, "from": "the singing stones of Gravenmoor's crypt"},
}
## Display order. "capture" stands for whichever Capture level you know.
const ORDER := ["weaken", "jig", "hymn", "chorale", "mending", "canon", "minuet", "lullaby", "sluggish", "dazzle", "venom", "static", "discord", "dread",
	"shanty", "coral", "reel", "dirge", "anvil", "waltz", "fanfare", "anthem", "capture", "requiem",
	"song_tides", "song_winds", "song_flame", "song_roots", "song_dusk"]

## Capture levels: Capture N charms wild beasts up to this level.
const CAPTURE_CAPS := [5, 10, 15, 20, 25, 30, 40, 50, 60, 75, 100]
const ROMAN := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI"]

## A performance scores 0..1 ("accuracy"): the timer colour it finished in (green 1.0 ... red 0.5) times a little less for
## each wrong note. Running out of time or three wrong notes scores 0.
## Below this the melody falls flat and an effect song does nothing (only failed songs).
const FLAT_ACCURACY := 0.3
## At or above this an effect song is "stirring": doubled stat changes, better status odds (finished in the green, no slips).
const GREAT_ACCURACY := 0.9

# ---------------- the flute minigame: sheet music to memorise and play back ----------------
## Buttons. On the staff (bottom line up) they sit ← → A B, then ↓ and ↑ above them.
const BTN_LEFT := 0
const BTN_RIGHT := 1
const BTN_A := 2
const BTN_B := 3
const BTN_UP := 4
const BTN_DOWN := 5
## staff step of each button: 0 = bottom line, 1 = the space above it, 2 = the next line...
const BTN_STEP := [0, 1, 2, 3, 5, 4]
## the pitch of each staff step: E4 F4 G4 A4 B4 C5
const STEP_MIDI := [64, 65, 67, 69, 71, 72]
const MIN_NOTES := 4
const MAX_NOTES := 16
const BASE_TIME := 10.0
## the uncle's lessons give beginners more time
const TUTORIAL_TIME := 30.0
const TIME_PER_NOTE := 1.25
## Songs other than Capture level up with mastery: level = 1 + mastery stars.
const MASTERY_LEVELS := 6
## How far towards its top level a song has to be before ↑, then ↓, then chords join it.
const UNLOCK_UP := 0.35
const UNLOCK_DOWN := 0.55
const UNLOCK_CHORDS := 0.75
## Share of chords among a level's new notes once chords are unlocked.
const CHORD_SHARE := 0.3
const STAT_SHORT := {"atk": "ATK", "def": "DEF", "spr": "SPR", "spd": "SPD", "eva": "EVA", "acc": "ACC"}
const STATUS_WORD := {"sleep": "sleep", "poison": "poison", "shock": "paralysis", "confuse": "confusion", "fear": "fear", "blind": "blindness", "burn": "burns"}


static func get_song(id: String) -> Dictionary:
	if id.begins_with("capture"):
		var n := clampi(capture_level(id), 1, CAPTURE_CAPS.size())
		return {"name": "Capture " + ROMAN[n - 1], "kind": "charm", "max_level": CAPTURE_CAPS[n - 1], "capture": n,
			"bpm": 80 + n * 4, "tier": mini(8, n - 1), "root": 72 + (n % 3),
			"from": "Uncle Rafe in Tidewater taught you Capture I. Each new level is practised from the Flute page of your book"}
	return SONGS.get(id, SONGS["weaken"])


static func capture_id(level: int) -> String:
	return "capture%d" % level


## 0 if `id` isn't a Capture song.
static func capture_level(id: String) -> int:
	return int(id.substr(7)) if id.begins_with("capture") and id.length() > 7 else 0


## ORDER with "capture" replaced by the Capture level in `known` (Capture I if none is known).
static func ordered(known: Array) -> Array:
	var cap := capture_id(1)
	for k in known:
		if capture_level(String(k)) > capture_level(cap):
			cap = String(k)
	return ORDER.map(func(id): return cap if id == "capture" else id)


static func song_name(id: String) -> String:
	return get_song(id)["name"]


static func is_charm(id: String) -> bool:
	return get_song(id)["kind"] == "charm"


static func is_summon(id: String) -> bool:
	return get_song(id)["kind"] == "summon"


## The temple song that captures and summons the guardian of `temple` ("water", ..., "ghost"), or "".
static func summon_song(temple: String) -> String:
	for id in SONGS:
		if String(SONGS[id].get("summon", "")) == temple:
			return id
	return ""


static func shop_songs() -> Array:
	return ORDER.filter(func(id): return SONGS.has(id) and SONGS[id].has("shop"))


## A short tag for menus, e.g. "DEF↓ foes" or "≤ Lv 14".
static func tag(id: String) -> String:
	var s := get_song(id)
	if s["kind"] == "charm":
		return "ghosts" if s.get("ghost", false) else "≤ Lv %d" % s["max_level"]
	if s["kind"] == "summon":
		return "SUMMON"
	var bits := []
	for k in s.get("buff", {}):
		bits.append(STAT_SHORT.get(k, k) + "↑")
	for k in s.get("debuff", {}):
		bits.append(STAT_SHORT.get(k, k) + "↓")
	if s.has("status"):
		bits.append(String(s["status"]).to_upper())
	if s.has("heal_pct"):
		bits.append("HEAL")
	if s.get("cure", false):
		bits.append("CURE")
	var who: String = {"enemies": "foes", "enemy": "foe", "allies": "team", "ally": "ally"}.get(s["target"], "")
	return "%s %s" % [" ".join(bits.slice(0, 2)), who]


## One-line description of what a song does.
static func describe(id: String) -> String:
	var s := get_song(id)
	if s["kind"] == "charm":
		if s.get("ghost", false):
			return "Charms a wild ghost beast, up to your Capture level. Only ghosts listen to it."
		return "Charms a wild beast up to Lv %d, if one of your beasts is at least as strong. Play it flawlessly to charm a stronger one!" % s["max_level"]
	if s["kind"] == "summon":
		return "A temple's own song. Play it to the temple's guardian once it's worn down, and the guardian is yours. After that it calls the guardian into battle (Summon) to strike every foe at once: once per battle, for one shield point."
	var who: String = {"enemies": "every foe", "enemy": "one foe", "allies": "every beast on your team", "ally": "one of your beasts"}.get(s["target"], "")
	var parts := []
	for k in s.get("buff", {}):
		parts.append("raises the %s of %s" % [STAT_SHORT.get(k, k), who])
	for k in s.get("debuff", {}):
		parts.append("lowers the %s of %s" % [STAT_SHORT.get(k, k), who])
	if s.has("status"):
		parts.append("may inflict %s on %s" % [STATUS_WORD.get(s["status"], s["status"]), who])
	if s.has("heal_pct"):
		parts.append("heals %s" % who)
	if s.get("cure", false):
		parts.append("cures their ailments")
	var text := ", ".join(parts)
	return text.substr(0, 1).to_upper() + text.substr(1) + ". Play it well for a stronger effect."


## The note one button plays (its staff position's pitch). The Requiem sounds a fourth lower.
static func note_freq(id: String, btn: int) -> float:
	var midi: int = STEP_MIDI[BTN_STEP[btn]] - (5 if get_song(id).get("ghost", false) else 0)
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


## A song's top level: Capture has one level per Capture song, every other song levels up with mastery.
static func max_level(id: String) -> int:
	return CAPTURE_CAPS.size() if capture_level(id) > 0 else MASTERY_LEVELS


## How far along a song is towards its top level, 0..1.
static func _progress(id: String, level: int) -> float:
	return clampf(float(level - 1) / float(max_level(id) - 1), 0.0, 1.0)


## How many notes a song has at a level: 4 at level 1 (a temple song as many as its stones sang), 16 at its top level.
static func note_count(id: String, level: int) -> int:
	var first := int(get_song(id).get("min_notes", MIN_NOTES))
	return first + int(round(_progress(id, level) * (MAX_NOTES - first)))


## Which extra notes a song uses at a level: {"up", "down", "chords"}.
static func unlocks(id: String, level: int) -> Dictionary:
	var p := _progress(id, level) if level >= 1 else -1.0
	return {"up": p >= UNLOCK_UP - 0.001, "down": p >= UNLOCK_DOWN - 0.001, "chords": p >= UNLOCK_CHORDS - 0.001}


## Seconds to play a song of `count` notes: 10 for four (30 in a lesson), 5 more for every four more.
static func time_limit(count: int, base := BASE_TIME) -> float:
	return base + float(count - MIN_NOTES) * TIME_PER_NOTE


## The melody at a level: an Array of notes, each an Array of buttons (two buttons = a chord).
## Levelling up keeps the start of the song and adds new notes at the end, using whatever the new level unlocked.
static func melody(id: String, level: int) -> Array:
	level = clampi(level, 1, max_level(id))
	var rng := RandomNumberGenerator.new()
	rng.seed = ("capture" if capture_level(id) > 0 else id).hash()
	var out := []
	for lv in range(1, level + 1):
		var u := unlocks(id, lv)
		var before := unlocks(id, lv - 1)
		var pool := [BTN_LEFT, BTN_RIGHT, BTN_A, BTN_B]
		if u["up"]:
			pool.append(BTN_UP)
		if u["down"]:
			pool.append(BTN_DOWN)
		var start := out.size()
		for i in range(start, note_count(id, lv)):
			out.append(_random_note(rng, pool, u["chords"] and rng.randf() < CHORD_SHARE, out))
		# whatever this level unlocked shows up in its new notes
		var fresh := range(start, out.size())
		for key in ["up", "down", "chords"]:
			if u[key] and not before[key] and not fresh.is_empty():
				var at: int = fresh.pop_at(rng.randi_range(0, fresh.size() - 1))
				match key:
					"up":
						out[at] = [BTN_UP]
					"down":
						out[at] = [BTN_DOWN]
					_:
						out[at] = _random_note(rng, pool, true, out.slice(0, at))
	return out


static func _random_note(rng: RandomNumberGenerator, pool: Array, chord: bool, so_far: Array) -> Array:
	if chord:
		var dirs := pool.filter(func(b): return b != BTN_A and b != BTN_B)
		return [BTN_A if rng.randf() < 0.5 else BTN_B, dirs[rng.randi_range(0, dirs.size() - 1)]]
	var b: int = pool[rng.randi_range(0, pool.size() - 1)]
	# never the same note three times running
	var n := so_far.size()
	if n >= 2 and so_far[n - 1] == [b] and so_far[n - 2] == [b]:
		b = pool[(pool.find(b) + rng.randi_range(1, pool.size() - 1)) % pool.size()]
	return [b]
