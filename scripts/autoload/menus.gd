extends Node
## Pause menu and beast management screens.

const ItemDB = preload("res://scripts/data/item_db.gd")
const MoveDB = preload("res://scripts/data/move_db.gd")
const SongDB = preload("res://scripts/data/song_db.gd")
const RaceDB = preload("res://scripts/data/race_db.gd")
const Elements = preload("res://scripts/data/elements.gd")
const PixelArt = preload("res://scripts/gfx/pixel_art.gd")
const UIKit = preload("res://scripts/ui/ui_kit.gd")
## The travel book and the world map aren't preloaded (they'd slow the start): main.gd loads them in the background
## once the title is up, and they're fetched when first opened.
const BOOK_PATH := "res://scripts/ui/book_menu.gd"
const MAP_PATH := "res://scripts/ui/world_map_view.gd"


## The Start menu: the travel book.
func pause_menu(world, start_tab := "") -> void:
	if UI.auto:
		return
	var book = GameState.main.loaded_script(BOOK_PATH).new()
	book.setup(world, start_tab)
	UI.push(book)
	await book.done


func eggs_menu() -> void:
	if GameState.eggs.is_empty():
		await UI.say(["You aren't carrying any eggs. Defeated wild beasts sometimes leave one behind (about 1 in 5)."])
		return
	var items := []
	for e in GameState.eggs:
		items.append({"text": GameState.egg_name(e), "right": String(e["kind"]).to_upper(), "desc": "Take it to any Beast Center to hatch it. Hatchlings start at Lv 1."})
	await UI.choose("Eggs (%d)" % GameState.eggs.size(), items, {"width": 460})


# ---------------------------------------------------------------- beast pickers
func beast_item(b, reason := "") -> Dictionary:
	var limit := "Ready to merge!" if b.at_cap() else "Lv limit %d" % b.level_cap()
	# (a beast that hasn't grown into its final form yet: the level it next grows at)
	var grow := RaceDB.EVOLVE.filter(func(l): return l > b.level and RaceDB.stage(b.race) < 3)
	if not b.at_cap() and not grow.is_empty():
		limit += "  ·  grows up at Lv %d" % grow[0]
	var desc := "%s %s  Rank %s  HP %d/%d\n%s" % [b.element.capitalize(), Elements.ROLE.get(b.element, ""), b.rank_stars(), maxi(0, b.hp), b.max_hp(), reason if reason != "" else limit]
	return {"text": b.nickname, "right": "Lv %d" % b.level if b.hp > 0 else "fainted", "icon": PixelArt.beast_texture(b.genes),
		"desc": desc, "disabled": reason != ""}


## Returns the chosen beast or null. `check` (optional) returns "" if allowed, otherwise a reason.
func pick_beast(title: String, list: Array, check := Callable()):
	if list.is_empty():
		return null
	var items := []
	for b in list:
		var reason: String = check.call(b) if check.is_valid() else ""
		items.append(beast_item(b, reason))
	var c: int = await UI.choose(title, items, {"width": 460})
	if c < 0 or c >= list.size():
		return null
	return list[c]


## The messages for Beast.gain_xp's events. A beast that grew into its next form on the way is called by its old name
## until then ("Cinderex grew to Lv 40!", "Cinderex grew into Pyrosaur!").
func report_events(b, events: Array) -> void:
	var lines := []
	var evo: Array = events.filter(func(e): return e["type"] == "evolve")
	var who: String = evo[0]["from"] if not evo.is_empty() else b.nickname
	for e in events:
		match e["type"]:
			"level":
				lines.append("%s grew to Lv %d!" % [who, e["level"]])
			"evolve":
				lines.append("%s grew into %s!" % [e["from"], e["to"]])
				who = e["to"]
				GameState.caught[str(b.race)] = true
				GameState.seen[str(b.race)] = true
			"learn":
				var mn: String = MoveDB.get_move(e["move"])["name"]
				lines.append(("%s learned %s!" % [who, mn]) if e["active"] else ("%s can now use %s. Swap it in from the Moves menu." % [who, mn]))
			"cap":
				lines.append("%s reached its level limit! It's ready to merge." % who)
	if not lines.is_empty():
		Sfx.play("levelup")
		await UI.say(lines)


## Teaches a move right away, asking which move to replace if needed.
func teach(b, mv: String) -> void:
	var mn: String = MoveDB.get_move(mv)["name"]
	var res: String = b.learn(mv)
	if res == "new" or res == "":
		Sfx.play("levelup")
		await UI.say(["%s learned %s!" % [b.nickname, mn]])
		return
	var items := []
	for m in b.moves:
		items.append({"text": MoveDB.get_move(m)["name"], "desc": "Forget this move (it stays remembered and can be swapped back later).\n" + MoveDB.summary(m)})
	items.append({"text": "Keep current moves", "desc": "%s will remember %s for later." % [b.nickname, mn]})
	var c: int = await UI.choose("%s wants to use %s. Replace which move?" % [b.nickname, mn], items, {"width": 520})
	if c >= 0 and c < b.moves.size():
		b.moves[c] = mv
		Sfx.play("levelup")
		await UI.say(["%s is now using %s!" % [b.nickname, mn]])
	else:
		await UI.say(["%s will remember %s." % [b.nickname, mn]])


# ---------------------------------------------------------------- party
func party_menu() -> void:
	while true:
		var b = await pick_beast("Your beasts", GameState.party)
		if b == null:
			return
		await beast_options(b)


func beast_options(b) -> void:
	while true:
		var i := GameState.party.find(b)
		var c: int = await UI.choose(b.nickname, [
			{"text": "Summary", "desc": "Stats, passives and moves."},
			{"text": "Moves", "desc": "Choose which 4 known moves to use (%d known)." % b.known.size()},
			{"text": "Gear", "desc": "Equipped: %s" % (ItemDB.item_name(b.equip) if b.equip != "" else "nothing")},
			{"text": "Use item", "desc": "Use a potion or candy on %s." % b.nickname},
			{"text": "Move to front", "desc": "The first three beasts start each battle.", "disabled": i <= 0},
			{"text": "Back"}], {"anchor": "right", "width": 300})
		match c:
			0:
				await UI.show_beast(b)
			1:
				await manage_moves(b)
			2:
				await equip_beast(b)
			3:
				await use_item_on(b)
			4:
				GameState.party.erase(b)
				GameState.party.insert(0, b)
				UI.toast("%s moved to the front." % b.nickname)
			_:
				return


func manage_moves(b) -> void:
	while true:
		var items := []
		for m in b.moves:
			var md := MoveDB.get_move(m)
			items.append({"text": md["name"], "right": md["el"].to_upper(), "desc": MoveDB.summary(m)})
		if b.moves.size() < 4:
			items.append({"text": "(empty slot)", "desc": "Add a remembered move here."})
		var c: int = await UI.choose("%s's moves — pick one to change" % b.nickname, items, {"width": 520})
		if c < 0:
			return
		var spare: Array = b.known.filter(func(m): return not b.moves.has(m))
		if spare.is_empty():
			await UI.say(["%s doesn't remember any other moves." % b.nickname])
			continue
		var items2 := []
		for m in spare:
			var md2 := MoveDB.get_move(m)
			items2.append({"text": md2["name"], "right": md2["el"].to_upper(), "desc": MoveDB.summary(m)})
		var c2: int = await UI.choose("Replace with...", items2, {"width": 520})
		if c2 < 0:
			continue
		if c >= b.moves.size():
			b.moves.append(spare[c2])
		else:
			b.moves[c] = spare[c2]
		Sfx.play("select")


func equip_beast(b) -> void:
	var ids := []
	var items := []
	for id in GameState.inventory:
		var it := ItemDB.get_item(id)
		if it.get("kind", "") == "gear":
			ids.append(id)
			items.append({"text": "%s  x%d" % [it["name"], GameState.item_count(id)], "desc": it.get("desc", "")})
	if b.equip != "":
		ids.append("")
		items.append({"text": "Unequip %s" % ItemDB.item_name(b.equip), "desc": "Return it to your bag."})
	if ids.is_empty():
		await UI.say(["You don't have any beast gear. Outfitters sell it!"])
		return
	var c: int = await UI.choose("Equip %s with..." % b.nickname, items, {"width": 480})
	if c < 0:
		return
	if b.equip != "":
		GameState.add_item(b.equip)
	var id2: String = ids[c]
	if id2 != "":
		GameState.remove_item(id2)
	var old_max: int = b.max_hp()
	b.equip = id2
	b.hp = clampi(b.hp + (b.max_hp() - old_max), 0 if b.hp <= 0 else 1, b.max_hp())
	Sfx.play("select")
	UI.toast("%s equipped %s." % [b.nickname, ItemDB.item_name(id2)] if id2 != "" else "Unequipped.")


func use_item_on(b) -> void:
	var ids := []
	var items := []
	for id in GameState.inventory:
		var it := ItemDB.get_item(id)
		if it.get("kind", "") == "use" and not it.get("battle_only", false) and not it.has("incense"):
			ids.append(id)
			items.append({"text": "%s  x%d" % [it["name"], GameState.item_count(id)], "desc": it.get("desc", "")})
	if ids.is_empty():
		await UI.say(["You have nothing to use."])
		return
	var c: int = await UI.choose("Use on %s" % b.nickname, items, {"width": 460})
	if c < 0:
		return
	await apply_field_item(ids[c], b)


func apply_field_item(id: String, b) -> void:
	var it := ItemDB.get_item(id)
	if it.has("revive_pct"):
		if b.hp > 0:
			await UI.say(["It won't have any effect."])
			return
		GameState.remove_item(id)
		b.hp = maxi(1, int(b.max_hp() * float(it["revive_pct"])))
		Sfx.play("heal")
		await UI.say(["%s was revived!" % b.nickname])
		return
	if it.get("xp_level", false):
		if b.at_cap():
			await UI.say(["%s is at its level limit. Merge it to grow further!" % b.nickname])
			return
		GameState.remove_item(id)
		var events: Array = b.gain_xp(b.xp_for_level(b.level + 1) - b.xp)
		await report_events(b, events)
		return
	if b.hp <= 0:
		await UI.say(["%s has fainted. It needs reviving first." % b.nickname])
		return
	if (it.has("mp") or it.has("mp_pct")) and not it.has("heal") and not it.has("heal_pct"):
		if b.mp >= b.max_mp():
			await UI.say(["%s's MP is already full." % b.nickname])
			return
		GameState.remove_item(id)
		var before_mp: int = b.mp
		b.mp = mini(b.max_mp(), b.mp + int(it.get("mp", 0)) + int(ceil(b.max_mp() * float(it.get("mp_pct", 0.0)))))
		Sfx.play("heal")
		await UI.say(["%s recovered %d MP." % [b.nickname, b.mp - before_mp]])
		return
	if b.hp >= b.max_hp():
		await UI.say(["%s is already at full health." % b.nickname])
		return
	GameState.remove_item(id)
	var before: int = b.hp
	b.hp = mini(b.max_hp(), b.hp + int(it.get("heal", 0)) + int(b.max_hp() * float(it.get("heal_pct", 0.0))))
	Sfx.play("heal")
	await UI.say(["%s recovered %d HP." % [b.nickname, b.hp - before]])


# ---------------------------------------------------------------- bag
func bag_menu() -> void:
	await pause_menu(null, "bag")


## Uses / equips an item from the bag (from the book's Bag page).
func use_bag_item(id2: String) -> void:
	var it2 := ItemDB.get_item(id2)
	match it2.get("kind", ""):
		"use":
			if it2.get("battle_only", false):
				await UI.say(["That can only be used in battle."])
			elif it2.has("incense"):
				GameState.remove_item(id2)
				GameState.incense_kind = int(it2["incense"])
				GameState.incense_steps = 150
				Sfx.play("buff")
				await UI.say(["You lit the %s. Its scent drifts on the breeze..." % it2["name"]])
			else:
				var b = await pick_beast("Use %s on..." % it2["name"], GameState.party)
				if b != null:
					await apply_field_item(id2, b)
		"gear":
			var b2 = await pick_beast("Equip %s on..." % it2["name"], GameState.party)
			if b2 != null:
				if b2.equip != "":
					GameState.add_item(b2.equip)
				GameState.remove_item(id2)
				b2.equip = id2
				b2.hp = mini(b2.hp, b2.max_hp())
				UI.toast("%s equipped %s." % [b2.nickname, it2["name"]])
		"sheet":
			await Places.play_sheet(id2)
		"tgear":
			var slot: String = it2["slot"]
			if GameState.gear[slot] != "" and GameState.gear[slot] != "reed_flute":
				GameState.add_item(GameState.gear[slot])
			GameState.remove_item(id2)
			GameState.gear[slot] = id2
			Sfx.play("confirm")
			UI.toast("Equipped %s." % it2["name"])
		"tome":
			await UI.say(["Tomes are read at a bookstore, where the librarian helps your beast learn the move."])


# ---------------------------------------------------------------- trainer
func trainer_menu() -> void:
	await pause_menu(null, "trainer")


## Choose trainer gear for one slot.
func equip_trainer_slot(slot2: String) -> void:
	var ids := []
	var opts := []
	for id in GameState.inventory:
		var it := ItemDB.get_item(id)
		if it.get("kind", "") == "tgear" and it.get("slot", "") == slot2:
			ids.append(id)
			opts.append({"text": it["name"], "desc": it.get("desc", "")})
	if slot2 == "flute" and GameState.gear["flute"] != "reed_flute" and GameState.flag("reed_flute"):
		ids.append("reed_flute")
		opts.append({"text": "Reed Flute", "desc": ItemDB.get_item("reed_flute")["desc"]})
	elif slot2 != "flute" and GameState.gear[slot2] != "":
		ids.append("")
		opts.append({"text": "Unequip", "desc": "Return it to your bag."})
	if ids.is_empty():
		await UI.say(["You don't have any gear for that slot. Trainer outfitters sell it."])
		return
	var c2: int = await UI.choose("Equip", opts, {"width": 440})
	if c2 < 0:
		return
	var old: String = GameState.gear[slot2]
	if old != "" and old != "reed_flute":
		GameState.add_item(old)
	var nid: String = ids[c2]
	if nid != "" and nid != "reed_flute":
		GameState.remove_item(nid)
	GameState.gear[slot2] = nid
	Sfx.play("confirm")


func songs_menu() -> void:
	if GameState.songs.is_empty():
		await UI.say(["You don't know any songs yet."])
		return
	var items := []
	for sid in SongDB.ordered(GameState.songs):
		if not GameState.songs.has(sid):
			continue
		var s := SongDB.get_song(sid)
		var stars := GameState.mastery_stars(sid)
		items.append({"text": s["name"], "right": SongDB.tag(sid),
			"desc": "%s\nMastery %s. Source: %s." % [SongDB.describe(sid), "★".repeat(stars) + "☆".repeat(5 - stars), s["from"]]})
	await UI.choose("Songs (%d of %d)" % [GameState.songs.size(), SongDB.ORDER.size()], items, {"width": 520})


func world_map() -> void:
	if UI.auto:
		return
	var v = GameState.main.loaded_script(MAP_PATH).new()
	v.setup(GameState.map_id)
	UI.push(v)
	await v.done


func bestiary() -> void:
	await pause_menu(GameState.main.world if GameState.main else null, "bestiary")
