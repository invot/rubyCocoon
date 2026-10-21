extends Node
## Everything about the current save: party, inventory, flags, progress.

const Beast = preload("res://scripts/core/beast.gd")
const Beasts = preload("res://scripts/core/beasts.gd")
const Ring = preload("res://scripts/core/ring.gd")
const RaceDB = preload("res://scripts/data/race_db.gd")
const ItemDB = preload("res://scripts/data/item_db.gd")
const SongDB = preload("res://scripts/data/song_db.gd")
const WorldDB = preload("res://scripts/data/world_db.gd")

const SAVE_DIR := "user://saves/"
## Automated test runs (main.gd --scene=...) save here instead, so they never touch a real save.
const TEST_SAVE_DIR := "user://test_saves/"
## the single save file from before save slots existed
const LEGACY_SAVE := "user://savegame.json"
const SLOT_COUNT := 10
## The most beasts a trainer can carry: one per slot of the battle ring (see ring.gd). A new trainer has room for
## BEAST_SLOTS_START; Volt at Sparkwire Electronics adds more as your trainer level grows.
const PARTY_MAX := 8
const BEAST_SLOTS_START := 3
## Trainer levels: earned by beating trainers (on the roads, and up the arena ladder). Each level lets Volt fit one more
## beast slot (up to 8) and, every other level, one more shield point (up to 4); both still cost crystal shards.
const TRAINER_LEVEL_MAX := 10
## shield points every trainer starts with (Volt adds more, up to 4)
const SHIELD_START := 1

var main: Node = null

var player_name := "Andrew"
## The hero as the character creator made them: "body" ("male" or "female"), "person" (their outfit, one of
## townfolk.gd HERO_OUTFITS), "hairdo" (one of its HAIRDOS) and "pack" (one of its packs, from 1; 0 none), and the
## colours of their "skin", "top", "trousers", "hair" and "eyes" (whatever's left out, as their body begins).
var hero := {}
var gold := 0
var party: Array = []
var storage: Array = []
var inventory := {}
var gear := {"flute": "", "head": "", "feet": "", "acc": ""}
## the bait on your fishing hook (an ItemDB "bait" item), "" for none: one is used up each time something bites
var bait := ""
var songs: Array = []
var song_mastery := {}
var crests: Array = []
var flags := {}
var visited: Array = []
var map_id := "caccoon"
var pos := Vector2i(-1, -1)
var facing := Vector2i(0, 1)
var last_center := "caccoon"
var seen := {}
var caught := {}
## Each town's kennel: [{"beast": Beast or null, "yours": bool, "since": play_time}] (not saved: it restocks).
var kennels := {}
var play_time := 0.0
var steps := 0
var incense_steps := 0
var incense_kind := 0
var lucky_battles := 0
## eggs waiting to hatch: [{"race": int, "kind": "fire|water|earth|air|ghost|legendary", "ghost": bool}]
var eggs: Array = []
var shards := 0
var shards_spent := 0
var max_shield := 0
var shield := 0
## how many beasts you can carry (3 to 8): the slots of your battle ring that are wired up
var beast_slots := BEAST_SLOTS_START
var trainer_level := 1
var trainer_xp := 0
## arena ladder: rank (1..LadderDB.RANKS) -> Array of the opponent indices beaten in it
var ladder := {}
## the side of your ring that faced the foe when your last battle ended (see ring.gd)
var ring_side := 0
## the save slot this game lives in (-1 until it's first saved)
var current_slot := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	_setup_input()


func _process(delta: float) -> void:
	play_time += delta


# ---------------------------------------------------------------- input
## Keyboard: arrows move (one of the four ways), A = action, S = back (hold to run), Space = Start, Shift = Pause.
## Gamepads: d-pad, A / B, Start, Back/Select (the left stick steers too, read by world.gd _stick_dir). Touch buttons
## send these same actions.
func _setup_input() -> void:
	_bind("move_up", [KEY_UP], [JOY_BUTTON_DPAD_UP])
	_bind("move_down", [KEY_DOWN], [JOY_BUTTON_DPAD_DOWN])
	_bind("move_left", [KEY_LEFT], [JOY_BUTTON_DPAD_LEFT])
	_bind("move_right", [KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT])
	_bind("interact", [KEY_A, KEY_ENTER, KEY_KP_ENTER], [JOY_BUTTON_A])
	_bind("run", [KEY_S], [JOY_BUTTON_B])
	_bind("menu", [KEY_SPACE], [JOY_BUTTON_START])
	_bind("pause", [KEY_SHIFT], [JOY_BUTTON_BACK])
	# flute notes: ←, →, A, B (S on the keyboard), ↑, ↓
	_bind("flute_1", [KEY_LEFT], [JOY_BUTTON_DPAD_LEFT])
	_bind("flute_2", [KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT])
	_bind("flute_3", [KEY_A, KEY_ENTER, KEY_KP_ENTER], [JOY_BUTTON_A])
	_bind("flute_4", [KEY_S], [JOY_BUTTON_B])
	_bind("flute_5", [KEY_UP], [JOY_BUTTON_DPAD_UP])
	_bind("flute_6", [KEY_DOWN], [JOY_BUTTON_DPAD_DOWN])
	_bind("ui_up", [KEY_UP], [JOY_BUTTON_DPAD_UP])
	_bind("ui_down", [KEY_DOWN], [JOY_BUTTON_DPAD_DOWN])
	_bind("ui_left", [KEY_LEFT], [JOY_BUTTON_DPAD_LEFT])
	_bind("ui_right", [KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT])
	_bind("ui_accept", [KEY_A, KEY_ENTER, KEY_KP_ENTER], [JOY_BUTTON_A])
	_bind("ui_cancel", [KEY_S, KEY_ESCAPE, KEY_BACKSPACE], [JOY_BUTTON_B])


## Replaces an action's events (Godot's defaults put Space on ui_accept, which is our Start key).
func _bind(action: String, keys: Array, pads := []) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	InputMap.action_erase_events(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for j in pads:
		var jb := InputEventJoypadButton.new()
		jb.button_index = j
		InputMap.action_add_event(action, jb)


# ---------------------------------------------------------------- new game
## How the hero is drawn (see voxel_person.gd).
func hero_look() -> Dictionary:
	var look := {"face": "hero"}
	look.merge(hero)
	return look


## The word for the hero that depends on whether they're a he or a she: hero_word("nephew", "niece").
func hero_word(male: String, female: String) -> String:
	return female if hero.get("body", "male") == "female" else male


func new_game(pname: String, look := {}) -> void:
	player_name = pname if pname.strip_edges() != "" else "Andrew"
	hero = look.duplicate()
	gold = 300
	party = []
	storage = []
	inventory = {"minor_potion": 5, "remedy_herb": 2, "spirit_drop": 3}
	# no flute yet: Uncle Rafe in Tidewater keeps your father's
	gear = {"flute": "", "head": "", "feet": "", "acc": ""}
	songs = []
	song_mastery = {}
	crests = []
	flags = {}
	visited = ["caccoon"]
	map_id = "caccoon"
	pos = Vector2i(-1, -1)
	last_center = "caccoon"
	seen = {}
	caught = {}
	kennels = {}
	play_time = 0.0
	steps = 0
	incense_steps = 0
	lucky_battles = 0
	eggs = []
	shards = 0
	shards_spent = 0
	# every trainer starts with one shield point: one blow survived when the middle of your ring falls
	max_shield = SHIELD_START
	shield = SHIELD_START
	beast_slots = BEAST_SLOTS_START
	trainer_level = 1
	trainer_xp = 0
	ladder = {}
	ring_side = 0
	current_slot = -1


# ---------------------------------------------------------------- beasts
## Takes a beast in: onto a free slot of your ring it may stand in, if you have room, else into storage.
func add_beast(b: Beast) -> String:
	b.abandoned = false
	b.status = ""
	caught[str(b.race)] = true
	seen[str(b.race)] = true
	if party.size() < party_max():
		var k := free_slot_for(b)
		if k >= 0:
			b.slot = k
			party.append(b)
			return "party"
	b.slot = -1
	storage.append(b)
	return "storage"


func remove_beast(b: Beast) -> void:
	party.erase(b)
	storage.erase(b)
	b.slot = -1


func replace_beast(old: Beast, new_b: Beast) -> void:
	var i := party.find(old)
	if i >= 0:
		party[i] = new_b
		new_b.slot = old.slot
		fix_ring()
		return
	i = storage.find(old)
	if i >= 0:
		storage[i] = new_b
		new_b.slot = -1
		return
	add_beast(new_b)


# ---------------------------------------------------------------- the battle ring
## How many beasts you can carry right now.
func party_max() -> int:
	return clampi(beast_slots, 1, PARTY_MAX)


## The party beast standing in a ring slot, or null.
func beast_at(k: int) -> Beast:
	for b in party:
		if b.slot == k:
			return b
	return null


## Your ring as {slot: beast}.
func ring() -> Dictionary:
	var out := {}
	for b in party:
		if b.slot >= 0:
			out[b.slot] = b
	return out


## The best free ring slot a beast may stand in, or -1.
func free_slot_for(b: Beast) -> int:
	var slots := Ring.preferred_slots(b, ring())
	return slots[0] if not slots.is_empty() else -1


## The ring editor's moves (ring_editor.gd): `b` (on your ring, or in storage) to `dest`, {"slot": k} on the ring or
## {"store": j} in storage (j = storage.size(): the empty cell at its end), trading places with whoever is there.
## Returns "" if it may go, else why not: it must be able to stand on its new slot, and anyone it trades places with
## on its old one; your ring holds party_max() beasts; and one beast always stays with you.
func ring_move_reason(b: Beast, dest: Dictionary) -> String:
	var carried := party.has(b)
	if dest.has("slot"):
		var k: int = dest["slot"]
		if carried and b.slot == k:
			return "%s already stands here." % b.nickname
		if not Ring.can_hold(b, k):
			return "A %s beast can't stand on the %s." % [b.element_text(), Ring.slot_name(k)]
		var o := beast_at(k)
		if o == null:
			if not carried and party.size() >= party_max():
				return "Your ring has room for %d beasts. Trade places with one of them, or have Volt at Sparkwire Electronics wire up another slot." % party_max()
			return ""
		if carried and not Ring.can_hold(o, b.slot):
			return "%s can't stand on the %s to trade places." % [o.nickname, Ring.slot_name(b.slot)]
		return ""
	var j: int = dest["store"]
	var q: Beast = storage[j] if j >= 0 and j < storage.size() else null
	if not carried:
		return "%s is already here." % b.nickname if q == b else ""
	if q == null:
		return "You need to keep at least one beast with you." if party.size() <= 1 else ""
	if not Ring.can_hold(q, b.slot):
		return "%s can't stand on the %s to trade places." % [q.nickname, Ring.slot_name(b.slot)]
	return ""


## Makes a ring editor move (see ring_move_reason). Returns "" or why it can't.
func ring_move(b: Beast, dest: Dictionary) -> String:
	var why := ring_move_reason(b, dest)
	if why != "":
		return why
	if dest.has("slot"):
		var k: int = dest["slot"]
		var o := beast_at(k)
		if party.has(b):
			if o != null:
				o.slot = b.slot
		else:
			var i := storage.find(b)
			if o != null:
				party.erase(o)
				o.slot = -1
				storage[i] = o
			else:
				storage.remove_at(i)
			party.append(b)
		b.slot = k
		return ""
	var j: int = dest["store"]
	var q: Beast = storage[j] if j < storage.size() else null
	if party.has(b):
		if q != null:
			q.slot = b.slot
			party[party.find(b)] = q
			storage[j] = b
		else:
			party.erase(b)
			storage.append(b)
		b.slot = -1
	else:
		# reordering storage
		var i := storage.find(b)
		if q != null:
			storage[i] = q
			storage[j] = b
		else:
			storage.remove_at(i)
			storage.append(b)
	return ""


## Makes the ring consistent: every party beast on its own slot it may stand in. Beasts that no longer fit (old saves,
## a merge that changed an element) are moved to a free legal slot; a beast with none goes to storage.
## Returns the beasts sent to storage.
func fix_ring() -> Array:
	var used := {}
	var homeless := []
	for b in party:
		if b.slot >= 0 and b.slot < Ring.SLOTS and not used.has(b.slot) and Ring.can_hold(b, b.slot):
			used[b.slot] = true
		else:
			homeless.append(b)
	var sent := []
	for b in homeless:
		b.slot = -1
		var placed := {}
		for x in party:
			if x.slot >= 0:
				placed[x.slot] = x
		var slots := Ring.preferred_slots(b, placed)
		if not slots.is_empty():
			b.slot = slots[0]
			used[b.slot] = true
		else:
			sent.append(b)
	for b in sent:
		party.erase(b)
		storage.append(b)
	while party.size() > party_max():
		var extra: Beast = party.pop_back()
		extra.slot = -1
		storage.append(extra)
		sent.append(extra)
	return sent


# ---------------------------------------------------------------- trainer level
## Total trainer XP needed to reach a trainer level.
static func trainer_xp_for(level: int) -> int:
	return 50 * (level - 1) * level


## Adds trainer XP; returns how many levels were gained.
func add_trainer_xp(amount: int) -> int:
	var before := trainer_level
	trainer_xp += maxi(0, amount)
	while trainer_level < TRAINER_LEVEL_MAX and trainer_xp >= trainer_xp_for(trainer_level + 1):
		trainer_level += 1
	return trainer_level - before


## Raises the trainer level to at least `level` (clearing an arena ladder rank does this). Returns levels gained.
func reach_trainer_level(level: int) -> int:
	level = mini(level, TRAINER_LEVEL_MAX)
	if level <= trainer_level:
		return 0
	var gained := level - trainer_level
	trainer_level = level
	trainer_xp = maxi(trainer_xp, trainer_xp_for(level))
	return gained


## The most shield points and beast slots Volt can fit at your trainer level.
func shield_cap() -> int:
	return mini(4, (trainer_level + 2) / 2)


func slot_cap() -> int:
	return mini(PARTY_MAX, 2 + trainer_level)


func all_beasts() -> Array:
	return party + storage


func has_beasts() -> bool:
	return not party.is_empty()


## True if some party beast of one of `elements` is awake (used for field moves).
func party_element(elements: Array) -> Beast:
	for b in party:
		if b.hp > 0 and b.element in elements:
			return b
	return null


## A healthy party beast with wings (or a bird), for flying up cliffs.
func party_flyer() -> Beast:
	for b in party:
		if b.hp > 0 and (String(b.genes.get("back", "")) == "wings" or String(b.genes.get("body", "")) == "bird"):
			return b
	return null


func alive_party() -> Array:
	return party.filter(func(b): return b.hp > 0)


func heal_party() -> void:
	for b in party:
		b.heal_full()


func mark_seen(b: Beast) -> void:
	seen[str(b.race)] = true


# ---------------------------------------------------------------- eggs & shield
func add_egg(race: int, ghost := false) -> void:
	var kind := RaceDB.element(race)
	if RaceDB.is_legendary(race):
		kind = "legendary"
	elif ghost:
		kind = "ghost"
	eggs.append({"race": race, "kind": kind, "ghost": ghost})


func egg_name(e: Dictionary) -> String:
	match String(e["kind"]):
		"legendary":
			return "Radiant %s Egg" % RaceDB.element(int(e["race"])).capitalize()
		"ghost":
			return "Shadow Egg"
	return "%s Egg" % String(e["kind"]).capitalize()


## Hatches egg `i` into a level-1 beast and adds it to the party/storage.
func hatch(i: int) -> Beast:
	var e: Dictionary = eggs[i]
	eggs.remove_at(i)
	var b := Beasts.create(int(e["race"]), 1, bool(e.get("ghost", false)))
	b.origin = "egg"
	b.heal_full()
	add_beast(b)
	return b


func recharge_shield() -> void:
	shield = max_shield


# ---------------------------------------------------------------- items
func item_count(id: String) -> int:
	return int(inventory.get(id, 0))


func add_item(id: String, n := 1) -> void:
	inventory[id] = item_count(id) + n


func remove_item(id: String, n := 1) -> bool:
	if item_count(id) < n:
		return false
	inventory[id] = item_count(id) - n
	if inventory[id] <= 0:
		inventory.erase(id)
	return true


func gear_fx(key: String) -> float:
	var total := 0.0
	for slot in gear:
		var id: String = gear[slot]
		if id != "":
			total += float(ItemDB.get_item(id).get("fx", {}).get(key, 0.0))
	return total


func price(base_price: int) -> int:
	return int(round(base_price * (1.0 - gear_fx("discount"))))


# ---------------------------------------------------------------- songs & capture
func has_flute() -> bool:
	return String(gear.get("flute", "")) != ""



## Learning a Capture level replaces the lower one.
func learn_song(id: String) -> bool:
	if songs.has(id):
		return false
	var lv := SongDB.capture_level(id)
	if lv > 0:
		if lv <= capture_level():
			return false
		songs = songs.filter(func(x): return SongDB.capture_level(String(x)) == 0)
	songs.append(id)
	return true


func knows_song(id: String) -> bool:
	if id == "capture":
		return capture_level() > 0
	return songs.has(id)


## The Capture level you know (0 = none yet).
func capture_level() -> int:
	var best := 0
	for x in songs:
		best = maxi(best, SongDB.capture_level(String(x)))
	return best


func capture_song() -> String:
	return SongDB.capture_id(capture_level()) if capture_level() > 0 else ""


## Highest level Capture can reach right now (0 if you don't know it).
func capture_cap() -> int:
	var lv := capture_level()
	return int(SongDB.CAPTURE_CAPS[lv - 1]) if lv > 0 else 0


## Level of your strongest beast in the party.
func best_level() -> int:
	var best := 0
	for b in party:
		best = maxi(best, b.level)
	return best


## True when a beast has reached your Capture cap and a higher level exists to practise.
func next_capture_ready() -> bool:
	var lv := capture_level()
	return lv > 0 and lv < SongDB.CAPTURE_CAPS.size() and best_level() >= capture_cap()


## Charming a beast stronger than all of yours needs a flawless performance.
func needs_flawless(b: Beast) -> bool:
	return b.level > best_level()


## Every Capture level shares one mastery.
func _mkey(song_id: String) -> String:
	return "capture" if SongDB.capture_level(song_id) > 0 else song_id


func mastery_stars(song_id: String) -> int:
	return clampi(int(song_mastery.get(_mkey(song_id), 0)) / 2, 0, 5)


func add_mastery(song_id: String, amount := 1) -> bool:
	## Returns true if a new star was earned.
	var before := mastery_stars(song_id)
	song_mastery[_mkey(song_id)] = int(song_mastery.get(_mkey(song_id), 0)) + amount
	return mastery_stars(song_id) > before


## A song's level: its Capture level, or 1 + mastery stars for every other song. Higher levels are longer and stronger.
func song_level(song_id: String) -> int:
	var cl := SongDB.capture_level(song_id)
	return cl if cl > 0 else 1 + mastery_stars(song_id)


## Extra share of time to play a song (better flutes).
func flute_time_bonus() -> float:
	return gear_fx("time")


func song_can_charm(song_id: String, b: Beast) -> String:
	var s := SongDB.get_song(song_id)
	if s["kind"] != "charm":
		return "That song doesn't charm beasts."
	if b.ghost and not s.get("ghost", false):
		return "Ghost beasts don't respond to ordinary songs."
	if not b.ghost and s.get("ghost", false):
		return "The Requiem only reaches ghost beasts."
	var cap := _charm_cap(song_id)
	if cap <= 0:
		return "You need to know Capture first."
	if b.level > cap:
		return "%s is too strong for %s (max Lv %d)." % [b.nickname, s["name"] if not s.get("ghost", false) else "your Capture level", cap]
	return ""


func _charm_cap(song_id: String) -> int:
	var s := SongDB.get_song(song_id)
	return capture_cap() if s.get("ghost", false) else int(s.get("max_level", 0))


## `mistakes` matters for beasts stronger than all of yours: only a flawless performance works on them.
func capture_chance(b: Beast, song_id: String, accuracy: float, mistakes := 0) -> float:
	if song_can_charm(song_id, b) != "":
		return 0.0
	if needs_flawless(b) and mistakes > 0:
		return 0.0
	var lvl_factor := 1.0 - 0.55 * float(b.level) / float(maxi(1, _charm_cap(song_id)))
	var hp_factor := 1.0 - 0.6 * b.hp_ratio()
	var c := clampf(accuracy, 0.0, 1.0) * lvl_factor * hp_factor * 1.6
	c *= 1.0 + 0.04 * mastery_stars(song_id) + gear_fx("capture")
	if b.abandoned:
		c += 0.35
	if b.status == "sleep":
		c *= 1.4
	elif b.status != "":
		c *= 1.15
	if mistakes == 0:
		c *= 1.2
	return clampf(c, 0.02, 0.95)


# ---------------------------------------------------------------- progress
func crest_count() -> int:
	return crests.size()


func flag(key: String) -> bool:
	return bool(flags.get(key, false))


func set_flag(key: String, v = true) -> void:
	flags[key] = v


func visit(map: String) -> void:
	if WorldDB.is_town(map) and not visited.has(map):
		visited.append(map)


# ---------------------------------------------------------------- kennels
## Pens in every Beast Center kennel.
const KENNEL_PENS := 4
## Seconds of play before an empty pen gets a new arrival (or a beast you dropped off finds a new trainer).
const KENNEL_RESTOCK := 240.0


## The kennel in `town`'s Beast Center. Beasts arrive near your party's level, so adopting one is a new friend, not
## a shortcut.
func kennel(town: String) -> Array:
	if not kennels.has(town):
		var pens := []
		for i in KENNEL_PENS:
			pens.append({"beast": kennel_beast(town) if i < KENNEL_PENS - 1 else null, "yours": false, "since": play_time})
		kennels[town] = pens
	for pen in kennels[town]:
		if play_time - float(pen["since"]) < KENNEL_RESTOCK:
			continue
		if pen["beast"] == null:
			pen["beast"] = kennel_beast(town)
			pen["yours"] = false
			pen["since"] = play_time
		elif pen["yours"]:
			# another trainer gave it a home
			pen["beast"] = null
			pen["yours"] = false
			pen["since"] = play_time
	return kennels[town]


## The average level of the beasts you carry.
func party_level() -> int:
	if party.is_empty():
		return 1
	var total := 0
	for b in party:
		total += b.level
	return int(round(float(total) / party.size()))


func kennel_beast(town: String) -> Beast:
	var races := []
	for rid in WorldDB.ROUTES:
		var r: Dictionary = WorldDB.ROUTES[rid]
		if r["from"] == town or r["to"] == town:
			races += r["races"]
	if races.is_empty():
		races = [0, 25, 38, 21]
	var b := Beasts.create(int(races.pick_random()), clampi(party_level() + randi_range(-2, 1), 1, 99))
	b.abandoned = true
	b.origin = "trade"
	return b


# ---------------------------------------------------------------- save / load
## Ten save slots, each a JSON file plus a PNG snapshot. A game remembers its slot: once it's been saved, every
## later save goes back into the same slot.
func save_dir() -> String:
	return TEST_SAVE_DIR if main != null and not main._test.is_empty() else SAVE_DIR


func slot_path(i: int) -> String:
	return save_dir() + "slot_%d.json" % (i + 1)


func slot_shot_path(i: int) -> String:
	return save_dir() + "slot_%d.png" % (i + 1)


func slot_exists(i: int) -> bool:
	return FileAccess.file_exists(slot_path(i))


func has_save() -> bool:
	_migrate_legacy()
	for i in SLOT_COUNT:
		if slot_exists(i):
			return true
	return false


func first_free_slot() -> int:
	for i in SLOT_COUNT:
		if not slot_exists(i):
			return i
	return -1


## The most recently saved slot (-1 if none).
func latest_slot() -> int:
	var best := -1
	var best_t := -1.0
	for i in SLOT_COUNT:
		if slot_exists(i):
			var t := float(slot_info(i).get("saved_at", 0.0))
			if t > best_t:
				best_t = t
				best = i
	return best


func _read_slot(i: int) -> Dictionary:
	if not slot_exists(i):
		return {}
	var f := FileAccess.open(slot_path(i), FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


## What the slot screens show: name, place, play time, saved date and a one-line summary.
func slot_info(i: int) -> Dictionary:
	var d := _read_slot(i)
	if d.is_empty():
		return {}
	var party_txt := []
	for bd in d.get("party", []):
		party_txt.append("%s Lv%d" % [String(bd.get("nickname", "?")), int(bd.get("level", 1))])
	var mid: String = d.get("map_id", "caccoon")
	var place: String = WorldDB.map_name(mid.get_slice("#", 0))
	var saved_at := float(d.get("saved_at", 0.0))
	return {
		"name": d.get("player_name", "Andrew"), "place": place, "play_time": float(d.get("play_time", 0.0)),
		"saved_at": saved_at, "date": Time.get_datetime_string_from_unix_time(int(saved_at) + int(Time.get_time_zone_from_system().get("bias", 0)) * 60, true).substr(0, 16) if saved_at > 0 else "",
		"crests": (d.get("crests", []) as Array).size(), "party": party_txt,
		"summary": "%s  ·  %d crest%s  ·  %s" % [d.get("player_name", "Andrew"), (d.get("crests", []) as Array).size(),
			"" if (d.get("crests", []) as Array).size() == 1 else "s", ", ".join(party_txt.slice(0, 3)) if not party_txt.is_empty() else "no beasts yet"],
	}


func slot_texture(i: int) -> Texture2D:
	var path := slot_shot_path(i)
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	return ImageTexture.create_from_image(img) if img != null else null


func copy_slot(from_i: int, to_i: int) -> bool:
	if not slot_exists(from_i) or from_i == to_i:
		return false
	DirAccess.make_dir_recursive_absolute(save_dir())
	var ok := DirAccess.copy_absolute(slot_path(from_i), slot_path(to_i)) == OK
	if FileAccess.file_exists(slot_shot_path(from_i)):
		DirAccess.copy_absolute(slot_shot_path(from_i), slot_shot_path(to_i))
	elif FileAccess.file_exists(slot_shot_path(to_i)):
		DirAccess.remove_absolute(slot_shot_path(to_i))
	return ok


func delete_slot(i: int) -> void:
	for path in [slot_path(i), slot_shot_path(i)]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if current_slot == i:
		current_slot = -1


## The old single save file becomes slot 1 the first time the slots are looked at.
func _migrate_legacy() -> void:
	if save_dir() != SAVE_DIR or not FileAccess.file_exists(LEGACY_SAVE):
		return
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var free := first_free_slot()
	if free >= 0 and DirAccess.copy_absolute(LEGACY_SAVE, slot_path(free)) == OK:
		DirAccess.remove_absolute(LEGACY_SAVE)


## Writes the game into `slot` (default: its own slot), with an optional snapshot image.
func save_game(slot := -2, shot: Image = null) -> bool:
	if slot == -2:
		slot = current_slot
	if slot < 0 or slot >= SLOT_COUNT:
		return false
	DirAccess.make_dir_recursive_absolute(save_dir())
	var d := {
		"version": 2,
		"player_name": player_name, "hero": hero, "gold": gold,
		"party": party.map(func(b): return b.to_dict()),
		"storage": storage.map(func(b): return b.to_dict()),
		"inventory": inventory, "gear": gear, "bait": bait, "songs": songs, "song_mastery": song_mastery,
		"crests": crests, "flags": flags, "visited": visited, "map_id": map_id,
		"pos": [pos.x, pos.y], "facing": [facing.x, facing.y], "last_center": last_center,
		"seen": seen, "caught": caught, "play_time": play_time, "steps": steps,
		"eggs": eggs, "shards": shards, "shards_spent": shards_spent, "max_shield": max_shield,
		"beast_slots": beast_slots, "trainer_level": trainer_level, "trainer_xp": trainer_xp, "ladder": ladder,
		"ring_side": ring_side,
		"saved_at": Time.get_unix_time_from_system(),
	}
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d))
	f.close()
	if shot != null:
		shot.save_png(slot_shot_path(slot))
	current_slot = slot
	return true


## Loads a slot (default: this game's slot, else the most recent save).
func load_game(slot := -2) -> bool:
	if slot == -2:
		slot = current_slot if current_slot >= 0 else latest_slot()
	var d := _read_slot(slot)
	if d.is_empty():
		return false
	new_game(d.get("player_name", "Andrew"), d.get("hero", {}))
	current_slot = slot
	gold = int(d.get("gold", 0))
	party = []
	for bd in d.get("party", []):
		party.append(Beasts.from_dict(bd))
	storage = []
	for bd in d.get("storage", []):
		storage.append(Beasts.from_dict(bd))
	inventory = {}
	var inv: Dictionary = d.get("inventory", {})
	for k in inv:
		inventory[k] = int(inv[k])
	gear = d.get("gear", gear)
	bait = String(d.get("bait", ""))
	songs = d.get("songs", [])
	song_mastery = {}
	var sm: Dictionary = d.get("song_mastery", {})
	for k in sm:
		song_mastery[k] = int(sm[k])
	crests = d.get("crests", [])
	flags = d.get("flags", {})
	visited = d.get("visited", ["caccoon"])
	map_id = d.get("map_id", "caccoon")
	var p: Array = d.get("pos", [-1, -1])
	pos = Vector2i(int(p[0]), int(p[1]))
	var fc: Array = d.get("facing", [0, 1])
	facing = Vector2i(int(fc[0]), int(fc[1]))
	last_center = d.get("last_center", "caccoon")
	seen = d.get("seen", {})
	caught = d.get("caught", {})
	play_time = float(d.get("play_time", 0.0))
	steps = int(d.get("steps", 0))
	eggs = []
	for e in d.get("eggs", []):
		eggs.append({"race": int(e["race"]), "kind": String(e["kind"]), "ghost": bool(e.get("ghost", false))})
	shards = int(d.get("shards", 0))
	shards_spent = int(d.get("shards_spent", 0))
	max_shield = maxi(SHIELD_START, int(d.get("max_shield", 0)))
	shield = max_shield
	trainer_level = int(d.get("trainer_level", 1))
	trainer_xp = int(d.get("trainer_xp", 0))
	ring_side = int(d.get("ring_side", 0))
	ladder = {}
	var ld: Dictionary = d.get("ladder", {})
	for k in ld:
		ladder[int(k)] = (ld[k] as Array).map(func(x): return int(x))
	# saves from before the battle ring: room for the beasts already carried
	beast_slots = int(d.get("beast_slots", clampi(party.size(), BEAST_SLOTS_START, PARTY_MAX)))
	fix_ring()
	return true


## Play time as hours:minutes:seconds.
func time_text(seconds := -1.0) -> String:
	var t := int(play_time if seconds < 0.0 else seconds)
	return "%d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60]
