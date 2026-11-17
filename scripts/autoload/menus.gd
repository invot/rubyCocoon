extends Node
## Pause menu and beast management screens.

const ItemDB = preload("res://scripts/data/item_db.gd")
const MoveDB = preload("res://scripts/data/move_db.gd")
const SongDB = preload("res://scripts/data/song_db.gd")
const RaceDB = preload("res://scripts/data/race_db.gd")
const Elements = preload("res://scripts/data/elements.gd")
const PixelArt = preload("res://scripts/gfx/pixel_art.gd")
const UIKit = preload("res://scripts/ui/ui_kit.gd")
const ItemUse = preload("res://scripts/core/item_use.gd")
const Beast = preload("res://scripts/core/beast.gd")
## The travel book (the world map is its Map tab) isn't preloaded (it'd slow the start): main.gd loads it in the
## background once the title is up, and it's fetched when first opened.
const BOOK_PATH := "res://scripts/ui/book_menu.gd"


## The Start menu: the travel book.
func pause_menu(world, start_tab := "", journal_tour := false) -> void:
	if UI.auto:
		return
	var book = GameState.main.loaded_script(BOOK_PATH).new()
	book.journal_tour = journal_tour
	book.setup(world, start_tab)
	UI.push(book)
	await book.done


## The Beast Center's and kennels' storage: the book's Beasts page alone, with your stored beasts beside the ring
## (book_menu.storage_mode, beasts_page.gd). The only place to change which beasts you carry.
func storage_screen() -> void:
	if UI.auto:
		return
	var book = GameState.main.loaded_script(BOOK_PATH).new()
	book.storage_mode = true
	book.setup(GameState.main.world if GameState.main != null else null, "beasts")
	UI.push(book)
	await book.done


func eggs_menu() -> void:
	if GameState.eggs.is_empty():
		await UI.say(["You aren't carrying any eggs. Defeated wild beasts sometimes leave one behind (about 1 in 5)."])
		return
	var items := []
	for e in GameState.eggs:
		items.append({"text": GameState.egg_name(e), "right": String(e["kind"]).to_upper(),
			"icon": GameState.EggLooks.icon(e), "desc": "Take it to any Beast Center to hatch it. Hatchlings start at Lv 1."})
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
				if e["active"]:
					lines.append("%s learned %s!" % [who, mn])
				else:
					# its slots are full: say what came before, then let the player choose
					if not lines.is_empty():
						Sfx.play("levelup")
						await UI.say(lines)
						lines = []
					await decide_learn(b, e["move"])
			"cap":
				lines.append("%s reached its level limit! It's ready to merge." % who)
	if not lines.is_empty():
		Sfx.play("levelup")
		await UI.say(lines)


## Teaches a move right away, asking which move to forget if its slots for that kind of move are full.
func teach(b, mv: String) -> void:
	var mn: String = MoveDB.get_move(mv)["name"]
	var res: String = b.learn(mv)
	if res == "new" or res == "":
		Sfx.play("levelup")
		await UI.say(["%s learned %s!" % [b.nickname, mn]])
		return
	await decide_learn(b, mv)


## The forget menu's cards are this wide (UI units): the new move on the left, the list in the middle, the highlighted
## move it already knows on the right, greyed out (or the boost instead, for "Don't learn").
const CARD_W := 300
## Letting a move go raises one stat for good instead (Beast.boosts): attacks Attack, heals and cures Spirit, anything
## else Defense.
const SKIP_BOOST := 2


static func skip_stat(mv: String) -> String:
	match String(MoveDB.get_move(mv).get("kind", "")):
		"attack":
			return "atk"
		"heal", "cleanse":
			return "spr"
	return "def"


## A card's caption line: small dim words on the left, an optional tag on the right.
func _card_caption(text: String, tag: Control = null) -> HBoxContainer:
	var row := HBoxContainer.new()
	var cap := UIKit.label(text, 18, UIKit.DIM)
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(cap)
	if tag != null:
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(tag)
	return row


func _card_col() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.custom_minimum_size.x = CARD_W
	return col


func _card_desc(col: VBoxContainer, text: String) -> void:
	col.add_child(UIKit.divider(0.0, "none"))
	var desc := UIKit.label(text, 24, UIKit.TEXT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = CARD_W
	col.add_child(desc)


## A move's card: its element, icon and name, what it costs, who it reaches, its power, accuracy and cooldown, and what
## it does. `faded`: greyed out (a move it already knows, beside the forget menu).
func move_card(id: String, caption := "New move", faded := false) -> Control:
	var m := MoveDB.get_move(id)
	var col := _card_col()
	var el := String(m.get("el", "neutral"))
	col.add_child(_card_caption(caption, UIKit.element_tag(el, 18) if el != "neutral" else UIKit.tag("Plain", UIKit.DIM, 18)))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	col.add_child(top)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ActionIcons = load("res://scripts/battle/action_icons.gd")
	var icon_kind = ActionIcons.for_move(id)
	icon.draw.connect(func(): ActionIcons.draw(icon, icon_kind, icon.size / 2.0, 18.0))
	top.add_child(icon)
	var name_label := UIKit.header(String(m["name"]), UIKit.HEAD, UIKit.HEAD_BIG)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(name_label)
	col.add_child(UIKit.divider(0.0, "none"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 0)
	col.add_child(grid)
	var reach := MoveDB.target_name(id)
	var rows := [["MP cost", MoveDB.mp_text(id)], ["Targets", reach.substr(0, 1).to_upper() + reach.substr(1)]]
	if m.has("power"):
		rows.append(["Power", str(m["power"])])
	if m.has("acc"):
		rows.append(["Accuracy", "%d%%" % int(m["acc"])])
	if int(m.get("cd", 0)) > 0:
		rows.append(["Cooldown", "%d turns" % int(m["cd"])])
	for r in rows:
		var k := UIKit.label(String(r[0]), 32, UIKit.DIM)
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(k)
		var v := UIKit.label(String(r[1]), 32, UIKit.INK)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(v)
	_card_desc(col, String(m.get("desc", "")))
	if faded:
		col.set_meta("faded", true)
	return col


## The card on the right while "Don't learn" is highlighted: the stat it raises instead, from its value now to its
## value after.
func boost_card(b, mv: String) -> Control:
	var st := skip_stat(mv)
	var col := _card_col()
	col.add_child(_card_caption("Instead"))
	col.add_child(UIKit.header("%s +%d" % [Beast.STAT_NAMES[st], SKIP_BOOST], UIKit.HEAD, UIKit.HEAD_BIG))
	col.add_child(UIKit.divider(0.0, "none"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var k := UIKit.label(Beast.STAT_NAMES[st], 32, UIKit.INK)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(k)
	var now: int = b.stat(st)
	row.add_child(UIKit.label(str(now), 32, UIKit.DIM))
	row.add_child(load("res://scripts/ui/soft_arrow.gd").make(Vector2.RIGHT, UIKit.DIM, Vector2(UIKit.body_px(32) * 0.9, UIKit.body_px(32) * 1.2)))
	row.add_child(UIKit.label(str(now + SKIP_BOOST), 32, UIKit.INK))
	_card_desc(col, "%s keeps its moves, never learns %s, and raises its %s by %d for good." % [b.nickname,
		MoveDB.get_move(mv)["name"], Beast.STAT_NAMES[st], SKIP_BOOST])
	return col


## Cards stacked in one place, only the shown one visible; the place keeps the biggest card's size, so the window
## doesn't change size as the highlight moves.
func _card_stack(cards: Array) -> MarginContainer:
	var stack := MarginContainer.new()
	stack.custom_minimum_size.x = CARD_W
	for c in cards:
		stack.add_child(c)
	return stack


static func _show_card(stack: Control, card: Control) -> void:
	for c in stack.get_children():
		c.modulate.a = (0.45 if c.has_meta("faded") else 1.0) if c == card else 0.0


## `b` wants to learn `mv` but that kind of slot is full: the player picks a move to forget for good, or lets the new
## one go and raises a stat for good instead (SKIP_BOOST). Returns true if it learned it.
func decide_learn(b, mv: String) -> bool:
	var mn: String = MoveDB.get_move(mv)["name"]
	var group: String = b.slot_group(mv)
	var kind := "plain" if group == "plain" else group.capitalize()
	var current: Array = b.slot_moves(group)
	var st := skip_stat(mv)
	while true:
		# the new move's card on the left, the moves it knows in the middle (each with its MP cost), and on the right the
		# highlighted one's card greyed out, or the stat it raises instead while "Don't learn" is highlighted
		var items := []
		for m in current:
			items.append({"text": MoveDB.get_move(m)["name"], "right": MoveDB.mp_text(m)})
		items.append({"text": "Don't learn %s" % mn})
		var opts := {"width": 300}
		if not UI.auto:
			var new_card := move_card(mv)
			var boost := boost_card(b, mv)
			var olds: Array = current.map(func(m): return move_card(m, "Forget", true))
			var right := _card_stack(olds + [boost])
			opts["left_pane"] = new_card
			opts["side_pane"] = right
			opts["on_focus"] = func(i: int):
				_show_card(right, olds[i] if i < olds.size() else boost)
			_show_card(right, olds[0] if not olds.is_empty() else boost)
		var c: int = await UI.choose("%s wants to learn %s.\nIts %s slots are full. Forget which?" % [b.nickname, mn, kind], items, opts)
		if c < 0 or c >= current.size():
			if UI.auto or await UI.ask("Let %s go and raise %s's %s instead?" % [mn, b.nickname, Beast.STAT_NAMES[st]]):
				b.boosts[st] = int(b.boosts.get(st, 0)) + SKIP_BOOST
				Sfx.play("levelup")
				await UI.say(["%s did not learn %s. Its %s rose by %d instead!" % [b.nickname, mn, Beast.STAT_NAMES[st], SKIP_BOOST]])
				return false
			continue
		var old: String = current[c]
		var on: String = MoveDB.get_move(old)["name"]
		if not await UI.ask("Forget %s for good and learn %s?" % [on, mn]):
			continue
		b.replace_move(old, mv)
		Sfx.play("levelup")
		await UI.say(["%s forgot %s and learned %s!" % [b.nickname, on, mn]])
		return true
	return false


# ---------------------------------------------------------------- party
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
	var wearing := ItemDB.item_name(b.equip) if b.equip != "" else "nothing"
	if ids.is_empty():
		await UI.say(["%s is wearing %s. You don't have any beast gear to change it. Outfitters sell it!" % [b.nickname, wearing]])
		return
	var c: int = await UI.choose("%s is wearing %s.\nEquip it with..." % [b.nickname, wearing], items, {"width": 480})
	if c < 0:
		return
	var id2: String = ids[c]
	ItemUse.put_gear_on(id2, b)
	Sfx.play("select")
	UI.toast("%s equipped %s." % [b.nickname, ItemDB.item_name(id2)] if id2 != "" else "Unequipped.", "item:" + id2 if id2 != "" else b)


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
	var why := ItemUse.beast_block(id, b)
	if why != "":
		await UI.say([why if not it.has("revive_pct") else "It won't have any effect."])
		return
	if it.has("revive_pct"):
		GameState.remove_item(id)
		b.hp = maxi(1, int(b.max_hp() * float(it["revive_pct"])))
		Sfx.play("heal")
		await UI.say(["%s was revived!" % b.nickname])
		return
	if it.get("xp_level", false):
		GameState.remove_item(id)
		var events: Array = b.gain_xp(b.xp_for_level(b.level + 1) - b.xp)
		await report_events(b, events)
		return
	GameState.remove_item(id)
	var before: int = b.hp
	var before_mp: int = b.mp
	b.hp = mini(b.max_hp(), b.hp + int(it.get("heal", 0)) + int(b.max_hp() * float(it.get("heal_pct", 0.0))))
	b.mp = mini(b.max_mp(), b.mp + int(it.get("mp", 0)) + int(ceil(b.max_mp() * float(it.get("mp_pct", 0.0)))))
	var cured: bool = it.get("cure", false) and b.status != ""
	if it.get("cure", false):
		b.status = ""
		b.status_turns = 0
	Sfx.play("heal")
	var said := []
	if b.hp > before:
		said.append("%d HP" % (b.hp - before))
	if b.mp > before_mp:
		said.append("%d MP" % (b.mp - before_mp))
	if not said.is_empty():
		await UI.say(["%s recovered %s." % [b.nickname, " and ".join(said)]])
	elif cured:
		await UI.say(["%s feels better!" % b.nickname])


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
				ItemUse.put_gear_on(id2, b2)
				UI.toast("%s equipped %s." % [b2.nickname, it2["name"]], "item:" + id2)
		"sheet":
			await Places.play_sheet(id2)
		"bait":
			if GameState.item_count("fishing_rod") <= 0:
				await UI.say(["You'll need a fishing pole to use bait."])
			elif GameState.bait == id2:
				GameState.bait = ""
				UI.toast("You took the %s off your hook." % it2["name"], "item:" + id2)
			else:
				GameState.bait = id2
				Sfx.play("pickup")
				UI.toast("%s on your hook! It stays on until something bites." % it2["name"], "item:" + id2)
		"tgear":
			ItemUse.put_trainer_gear_on(id2)
			Sfx.play("confirm")
			UI.toast("Equipped %s." % it2["name"], "item:" + id2)
		"tome":
			await UI.say(["Tomes are read at a bookstore, where the librarian helps your beast learn the move."])


# ---------------------------------------------------------------- trainer
func trainer_menu() -> void:
	await pause_menu(null, "trainer")


## Choose trainer gear for one slot.
func equip_trainer_slot(slot2: String) -> void:
	if slot2 == "weapon":
		var owned := ItemDB.WEAPONS.filter(func(id): return GameState.item_count(id) > 0)
		var choice: int = await UI.choose("Equip weapon", owned.map(func(id): return {"text": ItemDB.item_name(id), "desc": ItemDB.get_item(id)["desc"]}))
		if choice >= 0 and GameState.equip_weapon(owned[choice]):
			Sfx.play("confirm")
		return
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
	var nid: String = ids[c2]
	if nid != "" and nid != "reed_flute":
		GameState.remove_item(nid)
	if old != "" and old != "reed_flute":
		GameState.receive_item(old)
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


## The world map is the Start book's Map tab.
func world_map() -> void:
	if not GameState.flags.get("world_map", true):
		await UI.say(["Librarian Quill has a free world map for you at Cocoon Cove Library, beside the path from home to the square."])
		return
	await pause_menu(GameState.main.world if GameState.main else null, "map")

