extends Node
## Everything that happens inside buildings: shops, Beast Centers, arenas, temples and attractions.

const ItemDB = preload("res://scripts/data/item_db.gd")
const Ring = preload("res://scripts/core/ring.gd")
const LadderDB = preload("res://scripts/data/ladder_db.gd")
const MoveDB = preload("res://scripts/data/move_db.gd")
const SongDB = preload("res://scripts/data/song_db.gd")
const RaceDB = preload("res://scripts/data/race_db.gd")
const WorldDB = preload("res://scripts/data/world_db.gd")
const Beasts = preload("res://scripts/core/beasts.gd")
const PixelArt = preload("res://scripts/gfx/pixel_art.gd")
const UIKit = preload("res://scripts/ui/ui_kit.gd")
const MapGen = preload("res://scripts/world/map_gen.gd")
const Elements = preload("res://scripts/data/elements.gd")
const ChatterDB = preload("res://scripts/data/chatter_db.gd")

const KEEPERS := {
	"center": "Nurse Clover", "apothecary": "Apothecary Fen", "beast_gear": "Outfitter Hale",
	"trainer_gear": "Outfitter Juniper", "bookstore": "Librarian Quill", "cafe": "Barista Pim",
	"dojo": "Sensei Okra", "museum": "Curator Bell", "music_hall": "Maestro Lyre", "fortune": "Madame Opal",
	"electronics": "Volt", "skytower": "Skykeeper Aria", "music_shop": "Maestro Clef",
}
const SHIELD_COST := 5
const MAX_SHIELD := 4
const FLIGHT_COST := 120
const FLY_LEVEL := 40


func _tier(town: String) -> int:
	if WorldDB.is_town(town):
		return WorldDB.town_tier(town)
	var i := WorldDB.ROUTES.keys().find(town)
	return maxi(0, i)


func open(b: Dictionary, world) -> void:
	var town: String = b.get("town", world.map_id)
	var tier := _tier(town)
	var shop: String = b["shop"]
	match shop:
		"center":
			await beast_center(town)
		"apothecary":
			await UI.say(["Welcome! Potions, remedies, and a few things that go boom."], KEEPERS[shop])
			await shop_loop(b["name"], apothecary_stock(tier, town) + bait_stock(town))
		"electronics":
			await electronics(b)
		"skytower":
			await skytower_desk()
		"cafe":
			await UI.say(["Welcome to the café! Our snacks give beasts a boost in battle."], KEEPERS[shop])
			await shop_loop(b["name"], ["spicy_bun", "mint_tea", "honey_cake"])
		"beast_gear":
			await UI.say(["Gear for your beasts! Some pieces even teach them new tricks."], KEEPERS[shop])
			await shop_loop(b["name"], ItemDB.stock("gear", tier, town + ":bg", 8) + bait_stock(town))
		"trainer_gear":
			await UI.say(["Boots, hats, flutes... everything a trainer needs!"], KEEPERS[shop])
			await shop_loop(b["name"], ItemDB.stock("tgear", tier, town + ":tg", 7))
		"bookstore":
			await bookstore(b, town, tier)
		"arena":
			await arena(b, town)
		"dojo":
			await dojo()
		"museum":
			await museum()
		"music_hall":
			await music_hall()
		"music_shop":
			await music_shop()
		"fortune":
			await fortune()
		"house":
			await house(b)


# ================================================================ shops
func shop_loop(title: String, stock: Array) -> void:
	while true:
		var c: int = await UI.choose("%s   (%d gold)" % [title, GameState.gold], ["Buy", "Sell", "Leave"], {"anchor": "right", "width": 320})
		if c == 0:
			await _buy(stock)
		elif c == 1:
			await _sell()
		else:
			return


func _buy(stock: Array) -> void:
	var last := 0
	while true:
		var items := []
		for id in stock:
			var it := ItemDB.get_item(id)
			var p := GameState.price(int(it["price"]))
			var have := GameState.item_count(id)
			var desc: String = it.get("desc", "")
			if it["kind"] in ["gear", "tgear"]:
				desc += "\nEquipment. You own: %d" % have
			else:
				desc += "\nYou have: %d" % have
			items.append({"text": it["name"], "right": "%d g" % p, "desc": desc, "disabled": p > GameState.gold})
		var c: int = await UI.choose("Buy   —   %d gold" % GameState.gold, items, {"start": last, "width": 520})
		if c < 0:
			return
		last = c
		var id2: String = stock[c]
		var price := GameState.price(int(ItemDB.get_item(id2)["price"]))
		if GameState.gold < price:
			Sfx.play("error")
			continue
		GameState.gold -= price
		GameState.add_item(id2)
		Sfx.play("buy")
		UI.toast("Bought %s!" % ItemDB.item_name(id2))


func _sell() -> void:
	while true:
		var ids := []
		var items := []
		for id in GameState.inventory:
			var it := ItemDB.get_item(id)
			if int(it.get("price", 0)) <= 0:
				continue
			ids.append(id)
			items.append({"text": "%s  x%d" % [it["name"], GameState.item_count(id)], "right": "%d g" % (int(it["price"]) / 2), "desc": it.get("desc", "")})
		if ids.is_empty():
			await UI.say(["You have nothing to sell."])
			return
		var c: int = await UI.choose("Sell   —   %d gold" % GameState.gold, items, {"width": 520})
		if c < 0:
			return
		var id2: String = ids[c]
		GameState.remove_item(id2)
		GameState.gold += int(ItemDB.get_item(id2)["price"]) / 2
		Sfx.play("buy")


## The fishing bait sold in a town (ItemDB "sold_in"): worms on the islands, lures further on.
func bait_stock(town: String) -> Array:
	var out := []
	for id in ItemDB.ITEMS:
		if ItemDB.ITEMS[id]["kind"] == "bait" and town in ItemDB.ITEMS[id].get("sold_in", []):
			out.append(id)
	return out


## Care items (healing, cures, revives) plus a seeded selection of battle items for the trainer.
func apothecary_stock(tier: int, town: String) -> Array:
	var care := []
	var battle := []
	var spirit := []
	for id in ItemDB.ITEMS:
		var it: Dictionary = ItemDB.ITEMS[id]
		if it["kind"] != "use" or int(it["tier"]) > tier:
			continue
		if int(it["tier"]) >= 10 and tier < 12:
			continue
		if (it.has("mp") or it.has("mp_pct")) and not it.has("heal"):
			spirit.append(id)
		elif ItemDB.battle_kind(id) == "care" and not it.has("buff"):
			care.append(id)
		elif not it.has("incense") and not it.get("xp_level", false):
			battle.append(id)
	# late shops drop the weakest potions
	while care.size() > 6:
		care.remove_at(0)
	var rng := RandomNumberGenerator.new()
	rng.seed = (town + ":apo").hash()
	var picked := []
	var by_kind := {}
	for id in battle:
		var k := ItemDB.battle_kind(id)
		if not by_kind.has(k):
			by_kind[k] = []
		by_kind[k].append(id)
	# at least one of each kind, newest first, then random extras
	for k in by_kind:
		var list: Array = by_kind[k]
		picked.append(list[list.size() - 1 - rng.randi_range(0, mini(1, list.size() - 1))])
	var rest := battle.filter(func(x): return not picked.has(x))
	while picked.size() < 5 and not rest.is_empty():
		picked.append(rest.pop_at(rng.randi_range(0, rest.size() - 1)))
	if tier >= 1:
		picked.append("calm_incense")
	return care + spirit.slice(maxi(0, spirit.size() - 2)) + picked


func bookstore(b: Dictionary, town: String, tier: int) -> void:
	await UI.say(["Each tome teaches a beast a new move. A beast can only learn moves of its own element... or of its lineage!"], KEEPERS["bookstore"])
	var stock := ItemDB.tome_stock(tier, town + ":books")
	while true:
		var items := []
		for id in stock:
			var it := ItemDB.get_item(id)
			var p := GameState.price(int(it["price"]))
			items.append({"text": it["name"], "right": "%d g" % p, "desc": it["desc"], "disabled": p > GameState.gold})
		var c: int = await UI.choose("Bookstore   —   %d gold" % GameState.gold, items, {"width": 560})
		if c < 0:
			return
		var tome := ItemDB.get_item(stock[c])
		var mv: String = tome["move"]
		var price := GameState.price(int(tome["price"]))
		var learners := GameState.party.filter(func(x): return x.can_learn(mv) and not x.known.has(mv))
		if learners.is_empty():
			await UI.say(["None of the beasts with you can learn %s." % MoveDB.get_move(mv)["name"]], KEEPERS["bookstore"])
			continue
		var who = await Menus.pick_beast("Who should learn %s?" % MoveDB.get_move(mv)["name"], learners)
		if who == null:
			continue
		GameState.gold -= price
		Sfx.play("buy")
		await Menus.teach(who, mv)


# ================================================================ beast center
func beast_center(town: String) -> void:
	if WorldDB.is_town(town):
		GameState.last_center = town
	await UI.say(["Welcome to the Beast Center! I hatch eggs, and I look after storage and the merge altar.",
		"Healing's self-service: the machine in the corner. Beasts looking for a new home are in the kennel next door!"], KEEPERS["center"])
	if not GameState.eggs.is_empty() and GameState.party.is_empty():
		await hatchery()
	while true:
		var items := [
			{"text": "Hatchery", "right": "%d" % GameState.eggs.size(), "desc": "Hatch the eggs you're carrying in the incubator. Hatchlings start at Lv 1."},
			{"text": "Beast storage", "desc": "Deposit or withdraw beasts. (%d in storage)" % GameState.storage.size()},
			{"text": "Merge altar", "desc": "Merge two beasts that have reached their level limit into one stronger beast."},
			{"text": "Leave"},
		]
		var c: int = await UI.choose("Beast Center", items, {"anchor": "right", "width": 340})
		match c:
			0:
				await hatchery()
			1:
				await storage()
			2:
				await merge_altar(false)
			_:
				return


## The self-service healing machine in every Beast Center.
func heal_machine(world) -> void:
	if GameState.party.is_empty():
		Sfx.play("error")
		await UI.say(["BZZT. \"NO BEASTS DETECTED. PLEASE INSERT BEASTS.\""])
		return
	if not await UI.ask("A big soda-can healing machine. \"FREE REFILLS!\" Put your beasts in the slots?"):
		return
	await UI.say(["You slot your beasts into the machine..."])
	if world != null and is_instance_valid(world) and world.has_method("play_heal_fx"):
		await world.play_heal_fx(GameState.party.size())
	else:
		Sfx.play("heal")
	GameState.heal_party()
	for x in GameState.storage:
		x.heal_full()
	Sfx.play("levelup")
	await UI.say(["Ding! Your beasts pop out fully healed and fizzing with energy!"])


func hatchery() -> void:
	if GameState.eggs.is_empty():
		await UI.say(["You aren't carrying any eggs. Defeated wild beasts sometimes leave one behind!"], KEEPERS["center"])
		return
	while not GameState.eggs.is_empty():
		var items := []
		for e in GameState.eggs:
			var desc := "Something stirs inside..."
			match String(e["kind"]):
				"legendary":
					desc = "It glows with incredible power. A temple guardian's egg!"
				"ghost":
					desc = "Cold to the touch. Shadows swirl beneath the shell."
				_:
					desc = "A %s egg. It's warm and wobbly." % String(e["kind"])
			items.append({"text": GameState.egg_name(e), "right": String(e["kind"]).to_upper(), "desc": desc})
		var c: int = await UI.choose("Hatch which egg?", items, {"width": 460})
		if c < 0:
			return
		await UI.say(["Nurse Clover sets the egg in the incubator and twists the big brass dial...", "Whirrr... ding!", "Crack! It's hatching!"])
		Sfx.play("hatch")
		var w = GameState.main.world if GameState.main != null else null
		if w != null and is_instance_valid(w):
			w.play_hatch_fx()
		await get_tree().create_timer(0.6).timeout
		await UI.flash(Color("#fff4c0"), 1)
		var b := GameState.hatch(c)
		var first := not GameState.flag("has_starter")
		GameState.set_flag("has_starter")
		await UI.show_beast(b, "%s hatched!" % b.nickname)
		var lines := ["%s hatched from the egg! It's Lv 1, so train it up with care." % b.nickname]
		if first:
			lines.append("Your very first beast! Scout Bram is waiting by the east gate. He'll show you how battles work before you head out.")
			lines.append("If your beasts ever get tired, pop them in the healing machine over there. It's free!")
		if RaceDB.is_legendary(b.race):
			lines.append("A legendary beast! When it merges, about 80% of the child will come from it.")
		await UI.say(lines, KEEPERS["center"])


func storage() -> void:
	while true:
		var c: int = await UI.choose("Storage", [
			{"text": "Deposit", "desc": "Leave a beast here. Stored beasts are healed."},
			{"text": "Withdraw", "desc": "Take a beast with you: it stands on a free slot of your battle ring (room for %d)." % GameState.party_max()},
			{"text": "Back"}], {"anchor": "right", "width": 300})
		if c == 0:
			if GameState.party.size() <= 1:
				await UI.say(["You need to keep at least one beast with you."])
				continue
			var b = await Menus.pick_beast("Deposit which beast?", GameState.party)
			if b != null:
				GameState.party.erase(b)
				b.slot = -1
				b.heal_full()
				GameState.storage.append(b)
				UI.toast("%s was stored." % b.nickname)
		elif c == 1:
			if GameState.party.size() >= GameState.party_max():
				await UI.say(["Your party is full. Volt at Sparkwire Electronics can wire up more beast slots as your trainer level grows."])
				continue
			if GameState.storage.is_empty():
				await UI.say(["Storage is empty."])
				continue
			var b2 = await Menus.pick_beast("Withdraw which beast?", GameState.storage)
			if b2 != null:
				var k: int = GameState.free_slot_for(b2)
				if k < 0:
					await UI.say(["There's no free slot on your ring for a %s beast. Its side and corners are taken: store one of them first, or rearrange your ring in the Beasts page of your book." % b2.element_text()])
					continue
				GameState.storage.erase(b2)
				b2.slot = k
				GameState.party.append(b2)
				UI.toast("%s joined your party (%s)." % [b2.nickname, Ring.slot_name(k)])
		else:
			return


func merge_altar(temple: bool, keeper := "Nurse Clover") -> void:
	var ghost_ok := GameState.flag("ghost_merge")
	if GameState.all_beasts().is_empty():
		await UI.say(["You need beasts before you can merge them!"], keeper)
		return
	var ready := GameState.all_beasts().filter(func(x): return x.at_cap())
	if ready.size() < 2:
		await UI.say(["Merging needs two beasts that have reached their level limit.",
			"Rank 1 beasts top out at Lv 20, Rank 2 at Lv 40, Rank 3 at Lv 60, and so on.",
			"Beasts ready to merge right now: %d." % ready.size()], keeper)
		return
	await UI.say(["Choose two beasts. Their looks, moves, stats and passives will mix at random, and the new beast will rank up!"], keeper)
	var a = await Menus.pick_beast("First beast to merge", ready)
	if a == null:
		return
	var rest := ready.filter(func(x): return x != a)
	var b = await Menus.pick_beast("Merge %s with..." % a.nickname, rest, func(x): return Beasts.can_merge(a, x, ghost_ok))
	if b == null:
		return
	var why := Beasts.can_merge(a, b, ghost_ok)
	if why != "":
		await UI.say([why], keeper)
		return
	var rank: int = maxi(a.rank, b.rank) + 1
	if not await UI.ask("Merge %s and %s into one Rank %d beast? This can't be undone." % [a.nickname, b.nickname, rank], keeper):
		return
	Sfx.play("merge")
	await UI.flash(Color("#ffe8a0"), 4)
	var child := Beasts.merge(a, b, temple)
	GameState.replace_beast(a, child)
	GameState.remove_beast(b)
	if GameState.party.is_empty():
		GameState.storage.erase(child)
		child.slot = GameState.free_slot_for(child)
		GameState.party.append(child)
	GameState.fix_ring()
	GameState.caught[str(child.race)] = true
	await UI.show_beast(child, "A new beast is born: %s!" % child.nickname)
	var lines := ["%s and %s became %s! It is now Rank %d with a level limit of %d." % [a.nickname, b.nickname, child.nickname, child.rank, child.level_cap()]]
	if Beasts.dominance(a, b) != 0.5:
		lines.append("The legendary parent's blood ran strong: most of %s's traits came from it." % child.nickname)
	if child.element2 != "":
		lines.append("%s carries both %s! On your battle ring it can stand on the %s corner, or on either side, and fight with whichever of its elements faces the foe." % [child.nickname, child.element_text(), child.element_text()])
	await UI.say(lines, keeper)


# ================================================================ the kennel
## Kennel Keeper Pip: adopt a beast another trainer left behind, or leave one of yours for someone else to adopt.
func kennel(world, town: String) -> void:
	await UI.say(["Welcome to the kennel! Trainers leave beasts here when they can't keep them, and every one deserves a good home.",
		"Adopt one if you like, or leave one of yours and I'll find it a kind new trainer."], "Kennel Keeper Pip")
	while true:
		var c: int = await UI.choose("Kennel", [
			{"text": "Adopt a beast", "desc": "Give one of the beasts in the pens a new home."},
			{"text": "Drop off a beast", "desc": "Leave one of yours here for another trainer to adopt."},
			{"text": "Leave"}], {"anchor": "right", "width": 320})
		if c == 0:
			var pens: Array = GameState.kennel(town)
			var items := []
			var idx := []
			for i in pens.size():
				var b = pens[i]["beast"]
				if b == null:
					continue
				items.append({"text": b.nickname, "right": "Lv%d %s" % [b.level, b.rank_stars()], "icon": PixelArt.beast_texture(b.genes),
					"desc": ("Yours: waiting for a new trainer." if pens[i]["yours"] else "%s beast, left here by its trainer." % b.element.capitalize())})
				idx.append(i)
			if items.is_empty():
				await UI.say(["The pens are empty right now. New arrivals turn up all the time, so check back later!"], "Kennel Keeper Pip")
				continue
			var k: int = await UI.choose("Adopt which beast?", items, {"width": 460})
			if k >= 0:
				await kennel_pen(world, town, int(idx[k]))
		elif c == 1:
			await kennel_drop_off(world, town)
		else:
			return


## A beast in pen `i` (or an empty pen).
func kennel_pen(world, town: String, i: int) -> void:
	var pens: Array = GameState.kennel(town)
	if i < 0 or i >= pens.size() or pens[i]["beast"] == null:
		await UI.say(["An empty pen with fresh straw. A new arrival should turn up soon."])
		return
	var b = pens[i]["beast"]
	await UI.show_beast(b, b.nickname)
	if pens[i]["yours"]:
		if not await UI.ask("%s is waiting here for a new trainer. Take it back?" % b.nickname, "Kennel Keeper Pip"):
			return
	elif not await UI.ask("%s, Lv %d. Its trainer couldn't keep it. Give it a new home?" % [b.nickname, b.level], "Kennel Keeper Pip"):
		return
	pens[i]["beast"] = null
	pens[i]["yours"] = false
	pens[i]["since"] = GameState.play_time
	b.heal_full()
	var where := GameState.add_beast(b)
	b.origin = "trade"
	Sfx.play("capture")
	if world != null and is_instance_valid(world) and world.has_method("refresh_kennel"):
		world.refresh_kennel()
	await UI.say(["%s hops out of its pen and joins you%s! Take good care of it." % [b.nickname, " (it went to storage)" if where == "storage" else ""]], "Kennel Keeper Pip")


func kennel_drop_off(world, town: String) -> void:
	if GameState.all_beasts().size() <= 1:
		await UI.say(["You'd be all alone! Keep your beast with you."], "Kennel Keeper Pip")
		return
	var b = await Menus.pick_beast("Leave which beast?", GameState.all_beasts())
	if b == null:
		return
	if GameState.party.size() == 1 and GameState.party.has(b):
		await UI.say(["That's the only beast you're carrying! Take another one out of storage first."], "Kennel Keeper Pip")
		return
	if not await UI.ask("Leave %s here for another trainer to adopt? You won't get it back once someone takes it." % b.nickname, "Kennel Keeper Pip"):
		return
	var pens: Array = GameState.kennel(town)
	var slot := -1
	for i in pens.size():
		if pens[i]["beast"] == null:
			slot = i
			break
	if slot < 0:
		# the pens are full: the beast that's waited longest finds its new trainer first
		slot = 0
		for i in pens.size():
			if float(pens[i]["since"]) < float(pens[slot]["since"]):
				slot = i
	GameState.remove_beast(b)
	b.heal_full()
	b.abandoned = true
	pens[slot] = {"beast": b, "yours": true, "since": GameState.play_time}
	var gift: int = 20 + b.level * 5
	GameState.gold += gift
	Sfx.play("buy")
	if world != null and is_instance_valid(world) and world.has_method("refresh_kennel"):
		world.refresh_kennel()
	await UI.say(["%s settles into the straw. I'll find it a wonderful trainer, I promise." % b.nickname,
		"The kennel thanks you with %d gold for its keep... I mean, for your kindness!" % gift], "Kennel Keeper Pip")


## The Sky Tower: climb to the platform where a great bird flies you to any town you've visited.
## Skykeeper Aria's ticket desk in the Sky Tower's lobby.
func skytower_desk() -> void:
	await UI.say(["Welcome to the Sky Tower! The Thunderhawk is waiting on the roof. Take the stairs up and climb aboard.",
		"He'll carry you to any town you've visited, %d gold a flight." % FLIGHT_COST,
		"Raise an air beast of your own to Lv %d, and it'll be strong enough to carry you itself!" % FLY_LEVEL], KEEPERS["skytower"])


## The Thunderhawk on the Sky Tower's roof flies you to any town you've visited.
func skytower(b: Dictionary) -> void:
	var town: String = b.get("town", GameState.map_id)
	await UI.say(["The Thunderhawk ruffles its feathers and lowers a wing for you to climb aboard."])
	await fly_menu(town, FLIGHT_COST, "")


## Your own air beast (Lv FLY_LEVEL+) carrying you. Returns the beast or null.
func own_flyer():
	for x in GameState.party:
		if x.element == "air" and x.level >= FLY_LEVEL and x.hp > 0:
			return x
	return null


## Lets the player pick a visited town and flies there. Returns true if a flight happened.
func fly_menu(here: String, cost: int, who: String) -> bool:
	var dests := GameState.visited.filter(func(t): return t != here)
	if dests.is_empty():
		await UI.say(["You haven't visited any other towns yet."], who)
		return false
	var items := []
	for t in dests:
		var tower: bool = WorldDB.TOWNS[t]["shops"].has("skytower")
		items.append({"text": WorldDB.map_name(t), "right": ("%d g" % cost) if cost > 0 else "",
			"desc": ("Lands at the Sky Tower." if tower else "Lands near the Beast Center.") + "\n" + String(WorldDB.TOWNS[t]["blurb"]),
			"disabled": GameState.gold < cost})
	var c: int = await UI.choose("Fly to...   (%d gold)" % GameState.gold if cost > 0 else "Fly to...", items, {"width": 460})
	if c < 0:
		return false
	GameState.gold -= cost
	Sfx.play("fly")
	await UI.flash(Color("#e8f8ff"), 2)
	var dest: String = dests[c]
	GameState.main.goto_map(dest, "skytower")
	UI.toast("Flying to %s..." % WorldDB.map_name(dest), UIKit.GOLD)
	return true


# ================================================================ electronics
## Shield points and beast slots cost crystal shards; how many Volt can fit depends on your trainer level
## (GameState.shield_cap / slot_cap), which grows by beating trainers and climbing the arena ladder.
const SLOT_COST := 3


func electronics(b: Dictionary) -> void:
	var k: String = KEEPERS["electronics"]
	if not GameState.flag("met_volt"):
		GameState.set_flag("met_volt")
		await UI.say(["Welcome to Sparkwire Electronics! I'm Volt.",
			"See that wrist band of yours? It's a shield emitter. Right now it holds %d point." % GameState.max_shield,
			"In a ring battle, if the beast in the middle of the side facing your foe goes down, they can come straight for you. Each shield point blocks one hit. Take a hit with none left, and it's lights out.",
			"I can add shield points, and wire up more slots on your battle ring so you can carry more beasts. The better a trainer you are, the more I can fit: beat trainers and climb the arena ladder.",
			"Shield points are %d crystal shards each, beast slots %d." % [SHIELD_COST, SLOT_COST]], k)
	while true:
		var sh_cap := GameState.shield_cap()
		var sl_cap := GameState.slot_cap()
		var can_sh := GameState.shards >= SHIELD_COST and GameState.max_shield < sh_cap
		var can_sl := GameState.shards >= SLOT_COST and GameState.beast_slots < sl_cap
		var sh_desc := ""
		if GameState.max_shield >= MAX_SHIELD:
			sh_desc = "Your shield is fully upgraded!"
		elif GameState.max_shield >= sh_cap:
			sh_desc = "Shield %d / %d. Volt can't fit more until you're a Lv %d trainer (you're Lv %d)." % [GameState.max_shield, MAX_SHIELD, _level_for(func(): return GameState.shield_cap(), GameState.max_shield + 1), GameState.trainer_level]
		else:
			sh_desc = "Shield %d / %d. You have %d crystal shards." % [GameState.max_shield, MAX_SHIELD, GameState.shards]
		var sl_desc := ""
		if GameState.beast_slots >= GameState.PARTY_MAX:
			sl_desc = "All eight slots of your ring are wired up!"
		elif GameState.beast_slots >= sl_cap:
			sl_desc = "Beast slots %d / %d. Volt can wire another once you're a Lv %d trainer (you're Lv %d)." % [GameState.beast_slots, GameState.PARTY_MAX, _level_for(func(): return GameState.slot_cap(), GameState.beast_slots + 1), GameState.trainer_level]
		else:
			sl_desc = "Beast slots %d / %d: you can carry that many beasts on your ring. You have %d crystal shards." % [GameState.beast_slots, GameState.PARTY_MAX, GameState.shards]
		var items := [
			{"text": "Add a shield point", "right": "%d shards" % SHIELD_COST, "disabled": not can_sh, "desc": sh_desc},
			{"text": "Wire a beast slot", "right": "%d shards" % SLOT_COST, "disabled": not can_sl, "desc": sl_desc},
			{"text": "Buy gadgets", "desc": "Nets, flash powder and tonics for the trainer's turn in battle."},
			{"text": "Leave"},
		]
		var c: int = await UI.choose("Sparkwire Electronics  ·  Shards %d  ·  Trainer Lv %d" % [GameState.shards, GameState.trainer_level], items, {"anchor": "right", "width": 460})
		match c:
			0:
				if not can_sh:
					continue
				GameState.shards -= SHIELD_COST
				GameState.shards_spent += SHIELD_COST
				GameState.max_shield += 1
				GameState.recharge_shield()
				Sfx.play("levelup")
				await UI.flash(Color("#7af0ff"), 2)
				await UI.say(["Bzzt... click... done! Your shield now holds %d point%s." % [GameState.max_shield, "" if GameState.max_shield == 1 else "s"],
					"It recharges after every battle, so don't worry about wearing it out."], k)
			1:
				if not can_sl:
					continue
				GameState.shards -= SLOT_COST
				GameState.shards_spent += SLOT_COST
				GameState.beast_slots += 1
				Sfx.play("levelup")
				await UI.flash(Color("#7af0ff"), 2)
				await UI.say(["Zzzap! Another slot on your battle ring is live. You can carry %d beasts now." % GameState.beast_slots,
					"Pick one up from storage at any Beast Center. Remember: a side takes its own element, a corner either of its two."], k)
			2:
				await shop_loop("Gadgets", ["sticky_snare", "haste_tonic", "smoke_bomb", "flash_powder", "stun_net", "fire_bomb", "gale_bomb"])
			_:
				return


## The lowest trainer level at which cap() reaches `want` (for "come back at Lv N").
func _level_for(cap: Callable, want: int) -> int:
	var keep := GameState.trainer_level
	var lv := keep
	while lv < GameState.TRAINER_LEVEL_MAX:
		lv += 1
		GameState.trainer_level = lv
		if int(cap.call()) >= want:
			break
	GameState.trainer_level = keep
	return lv


# ================================================================ arena
func arena(b: Dictionary, town: String) -> void:
	if not WorldDB.ARENAS.has(town):
		await UI.say(["The arena is closed for repairs."])
		return
	var a: Dictionary = WorldDB.ARENAS[town]
	var leader := "%s %s" % [a["title"], a["leader"]]
	await UI.say(["Welcome to the %s! Our leader is %s." % [b["name"], leader]], "Arena Host")
	while true:
		var beaten: bool = GameState.crests.has(a["crest"])
		var lv: int = a["team"][0][1]
		var song := SongDB.get_song(a["song"])
		var desc := "Rematch for prize money. Levels ~%d." % (lv + 6)
		if not beaten:
			desc = "Leader's beasts are around Lv %d. Prize: %s, the song %s, and %d gold." % [lv, a["crest"], song["name"], a["gold"]]
		# (Tidewater: the coaches' lessons come first, see Story.ARENA_LESSONS)
		var ready: bool = beaten or Story.arena_lessons_done(town)
		if not ready:
			desc = "First, the arena's battle lessons: Coach Rory, then Coach Ondine, just inside the door."
		var items := [
			{"text": ("Rematch " if beaten else "Challenge ") + leader, "disabled": not ready, "desc": desc},
			{"text": "Arena ladder", "right": LadderDB.RANK_NAMES[_ladder_rank() - 1],
				"desc": "Climb the ladder of ring trainers. Beat every trainer of a rank to open the next; each rank you clear raises your trainer level (you're Lv %d) and earns a crystal shard." % GameState.trainer_level},
			{"text": "Leave"},
		]
		var c: int = await UI.choose(b["name"], items, {"anchor": "right", "width": 400})
		if c == 2 or c < 0:
			return
		if GameState.alive_party().is_empty():
			await UI.say(["Your beasts need healing before they can battle!"], "Arena Host")
			continue
		if c == 0:
			var res := await arena_challenge(town)
			if res != "win":
				return
		else:
			if not await ladder():
				return


# ================================================================ arena ladder
## The highest rank open to you: every rank below it is cleared.
func _ladder_rank() -> int:
	var r := 1
	while r < LadderDB.RANKS and _rank_cleared(r):
		r += 1
	return r


func _rank_cleared(r: int) -> bool:
	return (GameState.ladder.get(r, []) as Array).size() >= LadderDB.count(r)


## The ladder: your open rank's trainers first, then the earlier ranks' for rematches. Returns false after a battle
## you didn't win (you leave the arena).
func ladder() -> bool:
	var host := "Arena Host"
	if not GameState.flag("met_ladder"):
		GameState.set_flag("met_ladder")
		await UI.say(["The arena ladder! Ring trainers from all over battle here, rank by rank.",
			"Beat every trainer of your rank and the next rank opens up. Each rank you clear makes you a stronger trainer, and Volt at Sparkwire Electronics can do more for a stronger trainer: more beast slots, a bigger shield.",
			"Ladder battles are ring battles to the end: knock out a side's middle beast, then break the trainer's shield!"], host)
	while true:
		var top := _ladder_rank()
		var items := []
		var refs := []
		for r in range(top, 0, -1):
			for i in LadderDB.count(r):
				var o := LadderDB.opponent(r, i)
				var beaten: bool = (GameState.ladder.get(r, []) as Array).has(i)
				var lv := 0
				for t in o["team"]:
					lv += int(t[1])
				lv /= maxi(1, o["team"].size())
				items.append({"text": "%s %s" % [o["cls"], o["name"]], "right": ("✓  " if beaten else "") + "Lv %d" % lv,
					"desc": "%s.  %d beasts, %d shield point%s; favours the %s side of the ring.  Prize: %d gold%s." % [LadderDB.rank_name(r), o["team"].size(),
						o["shield"], "" if int(o["shield"]) == 1 else "s", String(o["theme"]).capitalize(), int(o["reward"]) / (2 if beaten else 1), " (rematch)" if beaten else ""]})
				refs.append([r, i])
		var c: int = await UI.choose("Arena ladder  ·  %s  ·  Trainer Lv %d" % [LadderDB.rank_name(top), GameState.trainer_level], items, {"anchor": "right", "width": 480, "rows": 7})
		if c < 0:
			return true
		if GameState.alive_party().is_empty():
			await UI.say(["Your beasts need healing before they can battle!"], host)
			continue
		var r2: int = refs[c][0]
		var i2: int = refs[c][1]
		var o2 := LadderDB.opponent(r2, i2)
		var again: bool = (GameState.ladder.get(r2, []) as Array).has(i2)
		var res := await Story.trainer_battle({"name": o2["name"], "cls": o2["cls"], "team": o2["team"], "arena": true, "look": o2["look"],
			"shield": o2["shield"], "reward": int(o2["reward"]) / (2 if again else 1), "defeat": "Well fought! See you higher up the ladder."})
		if res != "win":
			return false
		if again:
			continue
		var beaten2: Array = (GameState.ladder.get(r2, []) as Array).duplicate()
		beaten2.append(i2)
		GameState.ladder[r2] = beaten2
		if _rank_cleared(r2):
			Sfx.play("levelup")
			var before_slots := GameState.slot_cap()
			var before_shield := GameState.shield_cap()
			GameState.reach_trainer_level(r2 + 1)
			GameState.shards += 1
			var lines := ["You've cleared %s of the arena ladder!" % LadderDB.rank_name(r2),
				"You're a Lv %d trainer now. Here's a crystal shard for your trouble. (%d in your bag)" % [GameState.trainer_level, GameState.shards]]
			if GameState.slot_cap() > before_slots or GameState.shield_cap() > before_shield:
				lines.append("Volt at Sparkwire Electronics in Tidewater can now fit you with %s." % ("another beast slot and a shield point" if GameState.slot_cap() > before_slots and GameState.shield_cap() > before_shield
					else ("another beast slot" if GameState.slot_cap() > before_slots else "another shield point")))
			lines.append("%s is open!" % LadderDB.rank_name(r2 + 1) if r2 < LadderDB.RANKS else "You're the ladder's Champion! Come back for a rematch any time.")
			await UI.say(lines, host)
	return true


## The leader fight. Returns the battle result.
func arena_challenge(town: String) -> String:
	var a: Dictionary = WorldDB.ARENAS[town]
	var leader := "%s %s" % [a["title"], a["leader"]]
	var beaten: bool = GameState.crests.has(a["crest"])
	var song := SongDB.get_song(a["song"])
	if GameState.alive_party().is_empty():
		await UI.say(["Your beasts can barely stand. Heal them at the Beast Center first!"], leader)
		return "skip"
	if not beaten and await _lessons_first(town, leader):
		return "skip"
	var team := []
	for t in a["team"]:
		team.append([t[0], int(t[1]) + (6 if beaten else 0), false])
	await UI.say(["So you're the trainer from Cocoon Cove. Show me your bond with your beasts!" if not beaten else "Back for more? Let's go!"], leader)
	var res := await Story.trainer_battle({"name": a["leader"], "cls": a["title"], "team": team, "arena": true, "look": a.get("look", {}),
		"song": a.get("flute", ""), "flute_skill": 0.85, "encore": a.has("flute"), "boss": true,
		"reward": int(a["gold"]) if not beaten else int(a["gold"]) / 2, "defeat": "Splendid! You've earned my respect."})
	if res == "win" and not beaten:
		GameState.crests.append(a["crest"])
		GameState.learn_song(a["song"])
		Sfx.play("capture")
		await UI.say(["%s hands you the %s!" % [a["leader"], a["crest"]],
			"\"Take this song as well: the %s. %s\"" % [song["name"], SongDB.describe(a["song"])]], leader)
		UI.toast("Learned the song: %s!" % song["name"], UIKit.GOLD)
		await _miner_pass(town)
		await Story.on_crest()
	return res


## True (after saying so) while the arena's coaches still have lessons for you (Tidewater, see Story.ARENA_LESSONS).
func _lessons_first(town: String, leader: String) -> bool:
	if Story.arena_lessons_done(town):
		return false
	await UI.say(["Not so fast! Every challenger takes our coaches' lessons first: Coach Rory, then Coach Ondine. They're just inside the door."], leader)
	return true


## Copperpick's arena master signs the Miner's Pass for the Mine Road checkpoint.
func _miner_pass(town: String) -> void:
	if town != "copperpick" or GameState.item_count("miner_pass") > 0 or GameState.flag("mine_pass_ok"):
		return
	GameState.add_item("miner_pass")
	Sfx.play("item")
	await UI.say(["\"And here, take this: a Miner's Pass with my signature on it. Inspector Grubb will let you through the Mine Road checkpoint.\"",
		"You received the Miner's Pass!"], "Mine Foreman Gorran")


func leader_talk(b: Dictionary) -> void:
	var town: String = b["town"]
	if not WorldDB.ARENAS.has(town):
		return
	var a: Dictionary = WorldDB.ARENAS[town]
	var leader := "%s %s" % [a["title"], a["leader"]]
	var beaten: bool = GameState.crests.has(a["crest"])
	if beaten:
		await _miner_pass(town)
	elif await _lessons_first(town, leader):
		return
	var q := "Ready for our rematch?" if beaten else "I am %s, master of this arena. Do you challenge me for the %s?" % [leader, a["crest"]]
	if await UI.ask(q, leader):
		await arena_challenge(town)
	else:
		await UI.say(["Train well. I'll be waiting right here."], leader)


# ================================================================ temples
func temple_altar(b: Dictionary) -> void:
	var tk: String = b.get("temple", "water")
	var t: Dictionary = WorldDB.TEMPLES[tk]
	if not GameState.flag("guardian_" + tk):
		await UI.say(["An ancient altar. The %s's guardian still watches over it." % t["name"]])
		return
	await UI.say(["The altar of the %s glows softly. A warm light washes over your beasts." % t["name"]])
	GameState.heal_party()
	Sfx.play("heal")
	await UI.flash(Color(t["glow"]), 1)
	await UI.say(["Your beasts are fully restored."])


# ================================================================ music shop
## Brass & Reed Music in Cogsworth: one free performance (play it back to learn it), sheet music for sale.
func music_shop() -> void:
	if not GameState.has_flute():
		await UI.say(["A trainer without a flute? Tragic! Come back when you have one, and I'll fill it with music."], KEEPERS["music_shop"])
		return
	var k: String = KEEPERS["music_shop"]
	if not GameState.flag("met_maestro"):
		GameState.set_flag("met_maestro")
		await UI.say(["Welcome to Brass & Reed! I'm Maestro Clef, flautist to the finest beasts in Cogsworth.",
			"Songs aren't only for charming wild beasts, you know. The right melody lifts your team's spirits... or sours the foe's.",
			"I'll play any song in my book for you, free of charge. Once! Listen closely, then play it back. Get it right and it's yours.",
			"Miss it, and you'll need the sheet music. Practice makes perfect!"], k)
	while true:
		var free_left := not GameState.flag("maestro_free_song")
		var sheets := _owned_sheets()
		var c: int = await UI.choose("Brass & Reed Music   (%d gold)" % GameState.gold, [
			{"text": "Hear a song", "right": "free" if free_left else "used", "disabled": not free_left,
				"desc": "The Maestro plays a song from his book. Then play it back to learn it. Only once!" if free_left else "You've already had your free performance."},
			{"text": "Buy sheet music", "desc": "Learn songs at your own pace: play from the sheet (here or from your bag) until you get it right."},
			{"text": "Play from sheet music", "right": "%d" % sheets.size(), "desc": "Try to learn a song from sheet music you own.", "disabled": sheets.is_empty()},
			{"text": "Practice a song", "desc": "Raise your mastery: each star makes a song stronger, and a little longer."},
			{"text": "Leave"}], {"anchor": "right", "width": 360})
		match c:
			0:
				await _hear_song(k)
			1:
				var stock := []
				for sid in SongDB.shop_songs():
					if not GameState.knows_song(sid) and GameState.item_count("sheet_" + sid) == 0:
						stock.append("sheet_" + sid)
				if stock.is_empty():
					await UI.say(["You already own or know every song in my book. Bravo!"], k)
				else:
					await _buy(stock)
			2:
				var ids := []
				var items := []
				for id in sheets:
					ids.append(id)
					items.append({"text": ItemDB.item_name(id), "right": SongDB.tag(ItemDB.get_item(id)["song"]), "desc": ItemDB.get_item(id)["desc"]})
				var c2: int = await UI.choose("Play which sheet?", items, {"width": 520})
				if c2 >= 0:
					await play_sheet(ids[c2], k)
			3:
				await practice(k)
			_:
				Sfx.music(GameState.main.music_for(GameState.map_id))
				return


func _owned_sheets() -> Array:
	var out := []
	for id in GameState.inventory:
		if String(id).begins_with("sheet_"):
			out.append(id)
	return out


func _hear_song(k: String) -> void:
	var book := SongDB.shop_songs().filter(func(id): return not GameState.knows_song(id))
	if book.is_empty():
		await UI.say(["You already know every song in my book!"], k)
		return
	var items := []
	for sid in book:
		items.append({"text": SongDB.song_name(sid), "right": SongDB.tag(sid), "desc": SongDB.describe(sid)})
	var c: int = await UI.choose("Which song should the Maestro play?", items, {"width": 520})
	if c < 0:
		return
	var sid: String = book[c]
	if not await UI.ask("The %s? I'll only play for you once, so listen closely!" % SongDB.song_name(sid), k):
		return
	GameState.set_flag("maestro_free_song")
	await UI.say(["Maestro Clef lifts a gleaming brass flute..."])
	await UI.flute_ex(sid, "Listen closely: you'll play it back next", {"mode": "demo", "performer": "Maestro Clef"})
	await UI.say(["Now you! Play it back while it's still fresh in your mind."], k)
	if not await learn_attempts(sid, k):
		await UI.say(["The melody fades from your memory... If you want it, the sheet music is right here on the rack."], k)


## Play a song back until it's learned or the player gives up. Returns true if learned.
## `need`: the power (0..1) needed to pass; 0 means just finishing it. `first_opts` go to the minigame on the first try only.
func learn_attempts(sid: String, speaker := "", need := 0.0, first_opts := {}) -> bool:
	var extra := first_opts
	while true:
		var opts := {"mode": "learn", "goal": {"accuracy": need}}
		opts.merge(extra, true)
		extra = {}
		var r: Dictionary = await UI.flute_ex(sid, "Play it back to learn it", opts)
		Sfx.music(GameState.main.music_for(GameState.map_id))
		if not r["cancelled"] and String(r.get("failed", "")) == "" and float(r["acc"]) > 0.0 and float(r["acc"]) >= need:
			GameState.learn_song(sid)
			GameState.add_mastery(sid, 1)
			Sfx.play("levelup")
			UI.toast("Learned the song: %s!" % SongDB.song_name(sid), UIKit.GOLD)
			await UI.say(["Bravo! You learned the %s!" % SongDB.song_name(sid), SongDB.describe(sid)], speaker)
			return true
		var why: String = {"time": "Out of time!", "misses": "Too many wrong notes!"}.get(String(r.get("failed", "")), "Not quite.")
		if not await UI.ask("%s Try again?" % why, speaker):
			return false
	return false


## Learning from sheet music (from the music shop or the bag). The sheet is used up once the song is learned.
func play_sheet(id: String, speaker := "") -> void:
	var it := ItemDB.get_item(id)
	var sid: String = it["song"]
	if GameState.knows_song(sid):
		await UI.say(["You already know the %s." % SongDB.song_name(sid)])
		return
	await UI.say(["You unfold the sheet music for the %s and lift your flute..." % SongDB.song_name(sid)])
	if await learn_attempts(sid, speaker):
		GameState.remove_item(id)
	else:
		await UI.say(["You fold the sheet away. You can try again any time from your bag."])


# ================================================================ attractions
func dojo() -> void:
	await UI.say(["Train here and your beasts grow without the fuss of wild battles. It costs a little gold, of course."], KEEPERS["dojo"])
	while true:
		var list := GameState.party.filter(func(x): return not x.at_cap())
		if list.is_empty():
			await UI.say(["All your beasts have reached their level limit! Merge them to grow further."], KEEPERS["dojo"])
			return
		var b = await Menus.pick_beast("Train which beast? (cost: Lv × 40 gold)", list)
		if b == null:
			return
		var cost: int = b.level * 40
		if GameState.gold < cost:
			await UI.say(["That costs %d gold. Come back when you have it." % cost], KEEPERS["dojo"])
			continue
		if not await UI.ask("Train %s for %d gold?" % [b.nickname, cost], KEEPERS["dojo"]):
			continue
		GameState.gold -= cost
		var need: int = b.xp_for_level(b.level + 1) - b.xp
		var events: Array = b.gain_xp(need)
		await Menus.report_events(b, events)


func museum() -> void:
	var n := GameState.caught.size()
	await UI.say(["Welcome to the Bestiary Museum! You've recorded %d of 48 beast races." % n], KEEPERS["museum"])
	if GameState.party.is_empty():
		return
	var rewards := [[5, "potion", 3], [10, "revival_seed", 2], [20, "training_candy", 2], [30, "mega_potion", 5], [40, "golden_flute", 1], [48, "phoenix_plume", 1]]
	for r in rewards:
		var key := "museum_%d" % r[0]
		if n >= int(r[0]) and not GameState.flag(key):
			GameState.set_flag(key)
			GameState.add_item(r[1], int(r[2]))
			Sfx.play("buy")
			await UI.say(["For recording %d races, please accept %d × %s!" % [r[0], r[2], ItemDB.item_name(r[1])]], KEEPERS["museum"])
	await Menus.bestiary()


func music_hall() -> void:
	await UI.say(["Practice makes perfect! Each good performance raises your mastery of a song.",
		"Every star of mastery makes a song stronger and adds new notes to it. It makes charming easier, too."], KEEPERS["music_hall"])
	await practice(KEEPERS["music_hall"])


## One practice performance of a known song (from the book). Good play raises mastery.
func practice_once(sid: String, who := "") -> void:
	var acc: float = await UI.flute(sid, "Practice performance")
	Sfx.music(GameState.main.music_for(GameState.map_id))
	await _practice_result(sid, acc, who)


## Mastery from a practice performance, and what the listener says about it.
func _practice_result(sid: String, acc: float, who: String) -> void:
	var gain := 2 if acc >= 0.85 else (1 if acc >= 0.6 else 0)
	if gain > 0 and GameState.add_mastery(sid, gain):
		Sfx.play("levelup")
		var grew := "" if SongDB.capture_level(sid) > 0 else " The song grew to %d notes!" % SongDB.note_count(sid, GameState.song_level(sid))
		await UI.say(["Bravo! Your mastery of %s rose to %s.%s" % [SongDB.song_name(sid), "★".repeat(GameState.mastery_stars(sid)), grew]], who)
	elif gain > 0:
		await UI.say(["Nicely played! (%d%% power)" % int(round(acc * 100))], who)
	elif acc > 0.0:
		await UI.say(["You got through it (%d%% power). Faster, and with fewer slips!" % int(round(acc * 100))], who)
	else:
		await UI.say(["That one got away from you. Keep practising!"], who)


## Learning the next level of Capture (from the book, once a beast has reached the current cap).
func practice_next_capture() -> bool:
	var next := GameState.capture_level() + 1
	var sid := SongDB.capture_id(next)
	await UI.say(["You flip to a new page of your book and hum the first notes of %s..." % SongDB.song_name(sid)])
	if await learn_attempts(sid, ""):
		await UI.say(["%s now charms wild beasts up to Lv %d!" % [SongDB.song_name(sid), SongDB.CAPTURE_CAPS[next - 1]]])
		return true
	return false


## Practise known songs to raise mastery.
func practice(keeper: String) -> void:
	while true:
		if GameState.songs.is_empty():
			await UI.say(["Come back when you know a song!"], keeper)
			return
		var items := []
		for sid in GameState.songs:
			var s := SongDB.get_song(sid)
			var stars := GameState.mastery_stars(sid)
			items.append({"text": s["name"], "right": "★".repeat(stars) + "☆".repeat(5 - stars), "desc": SongDB.describe(sid)})
		var c: int = await UI.choose("Practice which song?", items, {"width": 520})
		if c < 0:
			return
		var sid2: String = GameState.songs[c]
		var acc: float = await UI.flute(sid2, "Practice performance")
		Sfx.music(GameState.main.music_for(GameState.map_id))
		await _practice_result(sid2, acc, keeper)


func fortune() -> void:
	if not await UI.ask("Shall I read your fortune? Only 100 gold...", KEEPERS["fortune"]):
		return
	if GameState.gold < 100:
		await UI.say(["The spirits do not work for free, dear."], KEEPERS["fortune"])
		return
	GameState.gold -= 100
	var rid: String = WorldDB.ROUTES.keys().pick_random()
	var r: Dictionary = WorldDB.ROUTES[rid]
	var names := []
	for x in r["races"]:
		names.append(RaceDB.race_name(x))
	var lines := ["I see... %s, on %s." % [", ".join(names), r["name"]]]
	if randf() < 0.5:
		GameState.lucky_battles = 3
		lines.append("And luck! Your next three battles will bring extra gold and experience.")
	else:
		lines.append(["A lonely beast waits in tall grass, abandoned by its trainer. Play kindly and it will follow you.",
			"Two become one, and one becomes more. Merge often, young trainer.",
			"An egg will come to you after a hard-won battle. Treasure it.",
			"Shadows gather in the far east, beyond the river. Keep your strongest beasts close."][randi() % 4])
	await UI.say(lines, KEEPERS["fortune"])


## Whether a building's door is locked: about a third of the houses, and the cathedral until its guard is beaten.
## Locked doors are painted a colour of their own (voxel_buildings.gd); all you can do is knock.
func door_locked(b: Dictionary) -> bool:
	match b["shop"]:
		"house":
			return house_locked(b)
		"cathedral":
			return not GameState.flag("tr_gravenmoor_gate")
	return false


func house_locked(b: Dictionary) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(b.get("seed", 0))
	return rng.randf() < 0.3


var _last_knock := -1


## Knocking on a locked door: three raps, then whoever's inside shouts something through it.
func knock(b: Dictionary) -> void:
	Sfx.play("knock")
	await get_tree().create_timer(0.85).timeout
	var cathedral: bool = b["shop"] == "cathedral"
	var lines: Array = ChatterDB.CATHEDRAL_DOOR if cathedral else ChatterDB.LOCKED_DOOR
	var i := randi() % lines.size()
	if i == _last_knock:
		i = (i + 1) % lines.size()
	_last_knock = i
	await UI.say(ChatterDB.fill(lines[i], GameState.player_name), "Legion Grunt" if cathedral else "Muffled Voice")
	if cathedral:
		await UI.say(["The cathedral doors are barred from the inside."])


func house(b: Dictionary, resident_seed := 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(b.get("seed", 0)) + resident_seed
	var talk: Array = ChatterDB.pick(ChatterDB.RESIDENTS, rng)
	await UI.say(ChatterDB.fill(talk, GameState.player_name), "Resident")
	var key := "house_gift_%s_%d" % [b.get("town", ""), int(b.get("seed", 0))]
	if rng.randf() < 0.4 and not GameState.flag(key):
		GameState.set_flag(key)
		var gift: String = ["potion", "remedy_herb", "revival_seed", "honey_cake"][rng.randi_range(0, 3)]
		GameState.add_item(gift)
		Sfx.play("buy")
		await UI.say(["Here, take this for your travels: a %s!" % ItemDB.item_name(gift)], "Resident")


# ================================================================ furniture
const BOOK_TITLES := [
	"\"Forty-Eight Beasts and Where to Find Them\", a field guide with a very worn cover.",
	"\"The Art of the Flute\": Keep the beat, and the beasts will keep you.",
	"\"Merging for Beginners\": Two beasts become one. Nobody knows which parts you'll get!",
	"\"A History of the Umbral Legion\": The pages about Nocthra have been torn out.",
	"\"Elemental Matchups\": Fire fears the wind. Water fears the wind too. Wind fears fire.",
	"\"Earth and Stone\": The best defence is a good Earth beast. Shield your friends!",
	"\"Cooking with Cindermoles\": Please don't.",
	"\"The Twelve Towns\", a travel guide. Someone has circled Cogsworth and written 'NEVER AGAIN'.",
	"\"Temples of the Four Winds\": Tides on the reef, Winds in the desert, Flame in the volcano, Roots in the jungle.",
	"\"Eggs and Hatchlings\": A fresh hatchling is weak, but it grows faster than any wild beast.",
	"\"Song of the Sea\", a collection of Tidewater sea shanties.",
	"\"Ghost Beasts: Myth or Menace?\" by a very nervous scholar.",
	"\"Building Worlds One Cube at a Time\" by S. Bizcuit. Someone has scribbled in the margin: NEVER GIVE UPPPPPP!!!",
]


## Something in a room was examined. `code` is the MapGen tile code.
## What you see when you look at a piece of furniture (see room_builder.gd KINDS).
const FURNITURE_LINES := {
	"counter": "A clean kitchen counter. Someone wiped it down this morning.",
	"kitchen_sink": "A few cups are drying by the sink.",
	"stove": "Something smells good. A pot's been on the stove all afternoon.",
	"fridge": "Leftovers, a carton of milk and a jar of beast treats.",
	"pantry": "Shelves of rice, beans and honey jars.",
	"toilet": "It's a toilet. It's very clean.",
	"bathtub": "A deep tub. A rubber Puddlepup floats in the corner.",
	"basin": "The tap drips, very slowly.",
	"washer": "The washing machine is humming through a spin cycle.",
	"sofa": "A comfy sofa, worn soft in all the right places.",
	"armchair": "Someone's favourite armchair.",
	"tv": "A cooking show is on. The chef is arguing with a Redcoon.",
	"chair": "A sturdy wooden chair.",
	"stool": "A stool.",
	"coffee_table": "A little table, ringed with old mug marks.",
	"wardrobe": "Clothes, neatly folded. Better leave them be.",
	"nightstand": "A lamp and a dog-eared book on the nightstand.",
	"dresser": "A dresser full of socks.",
	"desk": "Papers, pencils and a half-written letter.",
	"storage": "Shelves of boxes, all neatly labelled.",
	"boxes": "Cardboard boxes, taped shut.",
	"mop": "A mop and bucket.",
	"floor_lamp": "A tall lamp casts a warm glow.",
	"coat_stand": "Coats, scarves and an umbrella.",
	"trash": "The bin's nearly full.",
	"bunk": "A bunk bed. Top bunk's the best bunk.",
}


func prop(code: int, map: Dictionary, world, t: Vector2i) -> void:
	var b: Dictionary = map.get("building", {})
	var town: String = b.get("town", GameState.map_id)
	match code:
		MapGen.ALTAR:
			if b.get("shop", "") == "temple":
				await temple_altar(b)
			elif b.get("shop", "") in ["cathedral", "ceo_tower", "hideout"]:
				await UI.say(["A cold stone altar. Nothing happens."])
			else:
				await UI.say(["The merge altar hums softly. Two beasts that have reached their limit can become one here."])
				await merge_altar(false)
		MapGen.BOARD:
			await UI.say(["A cork board covered in notes: lost beasts, found beasts, and someone selling a slightly used flute."])
		MapGen.KENNEL:
			var pi: int = world.kennel_pens.find(t) if world != null and "kennel_pens" in world else -1
			await kennel_pen(world, town, pi)
		MapGen.HEALER:
			await heal_machine(world)
		MapGen.INCUBATOR:
			await UI.say(["The incubator hums, warm as toast. Nurse Clover hatches eggs in it."])
			if not GameState.eggs.is_empty():
				await hatchery()
		MapGen.TERMINAL:
			await UI.say(["A storage terminal. Beasts you deposit rest in comfort until you need them."])
			await storage()
		MapGen.EXHIBIT:
			var race: int = map.get("exhibits", {}).get(t, 0)
			var el := RaceDB.element(race)
			GameState.seen[str(race)] = true
			await UI.say(["Exhibit: %s, a %s beast (%s)." % [RaceDB.race_name(race), el, Elements.ROLE.get(el, "")],
				"Its passive trait is %s. %s" % [RaceDB.get_race(race)["passive"], RaceDB.PASSIVE_DESC.get(RaceDB.get_race(race)["passive"], "")]])
		MapGen.BOOKSHELF:
			var rng := RandomNumberGenerator.new()
			rng.seed = t.x * 31 + t.y * 17 + int(b.get("seed", 0))
			await UI.say([BOOK_TITLES[rng.randi_range(0, BOOK_TITLES.size() - 1)]])
		MapGen.SHELF:
			var what: String = {"apothecary": "jars of herbs, tonics and suspicious green potions", "beast_gear": "collars, charms and tiny boots",
				"trainer_gear": "hats, boots and polished flutes", "cafe": "jars of tea leaves and honey"}.get(b.get("shop", ""), "knick-knacks and keepsakes")
			await UI.say(["Shelves lined with %s." % what])
		MapGen.ORGAN:
			for i in 5:
				Sfx.flute_note([392.0, 440.0, 523.0, 587.0, 659.0][randi() % 5])
				await get_tree().create_timer(0.18).timeout
			await UI.say(["You play a few notes. It echoes beautifully through the hall."])
		MapGen.CRYSTAL:
			await UI.say(["Mist swirls inside the crystal ball... Did something just wink at you?"])
		MapGen.BED:
			if b.get("shop", "") == "home":
				await UI.say(["Your own bed! You lie down for a short nap..."])
				await UI.fade_out(0.4)
				GameState.heal_party()
				Sfx.play("heal")
				await get_tree().create_timer(0.4).timeout
				await UI.fade_in(0.4)
				await UI.say(["You feel refreshed. Your beasts are fully rested too!"])
			else:
				await UI.say(["Someone's neatly made bed. Better not mess it up."])
		MapGen.FIREPLACE:
			await UI.say(["A cozy fire crackles in the hearth."])
		MapGen.FOUNTAIN:
			await UI.say(["The water is cool and clear."])
		MapGen.PLANT:
			await UI.say(["A healthy potted plant. Someone waters it every day."])
		MapGen.COUNTER, MapGen.TABLE:
			pass
		MapGen.LOCKED:
			if map.get("staff_doors", {}).has(t):
				await UI.say(["A brass plate on the door: STAFF ONLY. It's locked."])
			else:
				await UI.say(["The door's locked."])
		MapGen.FURN:
			var line: String = FURNITURE_LINES.get(map.get("furniture", {}).get(t, ""), "")
			if line != "":
				await UI.say([line])
