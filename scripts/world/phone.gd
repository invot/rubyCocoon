extends RefCounted
## The telephone. Your dad is away working, and calling him is how the game is saved: you tell him how your journey
## is going, he cheers you on, and asks whether to save; then whether to play on, or return to the title screen.
## Away from home you can call Mom instead: she passes on a tip about what to do next (ChatterDB.MOM_TIPS) and says
## whether your beasts are strong enough for where you are (level_advice). At home she's in the room, so the phone
## there only calls Dad.
## Saving never costs anything: the red phones in homes, Beast Centers, some shops, the arenas and some temple
## doorways are free to use. Only a payphone in the street takes FEE coins for the call, and without them there's no
## call (a phone indoors is free).
## The first time you go to leave home, the phone rings: Dad, calling to wish you luck (see Story.can_use_exit).

const WorldDB = preload("res://scripts/data/world_db.gd")
const ChatterDB = preload("res://scripts/data/chatter_db.gd")
const InteriorMaps = preload("res://scripts/data/maps/interior_maps.gd")

const FEE := 5
## Your beasts' average level next to the wild beasts' range (level_advice): below the bottom of it by more than
## WAY_BELOW is far too strong for them; above the top by more than ABOVE, they could press on.
const WAY_BELOW := 2
const ABOVE := 2

## Which of MOM_TIPS she passes on next (they take turns; -1: not yet, and the first call of a session starts anywhere).
static var _tip_turn := -1

## What Dad says about where you've got to (Story.next_goal()).
const NEWS := {
	"egg": ["Elder Rowan's waiting with your egg? Then what are you doing talking to me? Off you go!"],
	"hatch": ["An egg! Take it to Nurse Clover at the Beast Center. Eggs like a warm incubator, not a warm pocket."],
	"path": ["The Coastal Path! I learned to battle on that path. Listen to the trainers out there. They know their stuff."],
	"bridge": ["Mending Old Hal's footbridge? Good. Always leave a road better than you found it."],
	"builder_egg": ["Old Hal never forgets a favour. Go and see him before you head on."],
	"flute": ["My old reed flute's waiting for you with your uncle Rafe in Bellerive. He'll make you practise. Practise anyway."],
	"rafe": ["Learn every song Rafe teaches you. Weaken first, then Capture. That's how I caught my Tempestrix. Allegedly."],
	"arena": ["Bellerive's arena! Listen to the coaches before you take on Marina. Nobody skips Rory's lesson. Nobody."],
	"marina": ["Marina's tough. Her beasts are all water, so bring something airy. And don't let her splash you first."],
	"ferry": ["The Isle of Tides! Those two villages have been squabbling since before I was born."],
	"chiefs": ["Hear both chiefs out before you take a side. There's always more to a feud than the first story."],
	"warden": ["Prove you're no tourist? Ha! Beat that Reef Warden and show them how a Cocoon Cove trainer treats a temple."],
	"temple": ["The Temple of Tides, out on the reef... Be careful in there, kiddo."],
	"desert": ["The desert's no picnic. Carry water, and watch out for bandits around Sundown."],
	"bandits": ["Black Bart's gang? The sheriff could use a hand. Just... be careful, all right?"],
	"winds": ["The Temple of Winds! You're further from home than I ever got at your age."],
	"mine": ["Beat Foreman Gorran and he'll sign your Miner's Pass. He respects a good battle."],
	"gearhart": ["Gearhart Tower? Those robots don't play fair. Beat every sentry on a floor and the stairs open."],
	"rescue": ["Those trainers are still waiting for you. Use Gearhart's command seal at the top-floor freight control. Get them home, kiddo."],
	"flame": ["The Temple of Flame. Bring a water beast, and a lot to drink."],
	"jungle": ["Vinehollow's jungle! Shaman Ayo's an old friend of mine. Help her if you can."],
	"relics": ["The three relics... They could be anywhere. Ask around. People love to tell you what they've seen."],
	"roots": ["A temple that rises out of the ground? I'd give a lot to see that. Tell me all about it."],
	"gravenmoor": ["Gravenmoor... the Umbral Legion. I won't pretend I'm not worried. But I believe in you."],
	"vexmora": ["Vexmora's down in that crypt. This is it, kiddo. Whatever happens, I'm proud of you."],
	"done": ["You did it! Everyone at work's heard about you. I'm coming home soon, and I want to hear every bit of it."],
}


## Uses the phone at `world`'s map: `fee` coins for a payphone. Calls Dad, who hears your news (the game is saved), or,
## away from home, Mom, for a tip.
static func call_home(world, fee := 0) -> void:
	if world != null and world.get_node_or_null("Ringer") != null:
		await answer(world)
		return
	if fee > 0 and GameState.gold < fee:
		Sfx.play("error")
		await UI.say(["A payphone. It takes %d coins to make a call, and you only have %d." % [fee, GameState.gold],
			"The red phones in people's homes are free to use, and so is the one in every Beast Center."])
		return
	var who := 0
	var what := "A payphone. A call costs %d coins." % fee if fee > 0 else "A telephone."
	if _at_home(world):
		if not await UI.ask("A telephone. Call Dad?"):
			return
	else:
		who = await UI.choose(what + " Who will you call?", ["Call Dad (save)", "Call Mom (advice)"])
		if who < 0:
			return
	if fee > 0:
		GameState.gold -= fee
		Sfx.play("buy")
	if who == 1:
		await call_mom(world)
		return
	Sfx.play("phone_ring")
	await UI.say(["You dial home... It rings, and rings... Click!"])
	var lines := ["%s! How's my favourite trainer?" % GameState.player_name]
	lines.append_array(NEWS.get(Story.next_goal(), []))
	lines.append(_tally())
	lines.append(["Keep at it. I'm proud of you.", "Look after your beasts, and they'll look after you.",
		"Work's busy, but hearing from you is the best part of my day."][randi() % 3])
	await UI.say(lines, "Dad")
	await _save()


## Calls Mom: she passes on a tip about what to do next, then what she makes of your beasts' levels. Nothing is saved.
static func call_mom(world) -> void:
	Sfx.play("phone_ring")
	await UI.say(["You dial home... It rings twice... Click!"])
	var lines := ["Hello? Oh, %s! It's so good to hear your voice." % GameState.player_name]
	lines.append_array(mom_tip())
	lines.append_array(level_advice(world))
	lines.append(["Call me any time, sweetie. And eat something green!", "Don't forget to call your father too. He loves hearing from you.",
		"Look after yourself out there. Love you!"][randi() % 3])
	await UI.say(lines, "Mom")


## Mom's next tip for what you're doing now (ChatterDB.MOM_TIPS, by Story.next_goal()): they take turns, call by call.
static func mom_tip() -> Array:
	var tips: Array = ChatterDB.MOM_TIPS.get(Story.next_goal(), [])
	if tips.is_empty():
		return []
	if _tip_turn < 0:
		_tip_turn = randi() % tips.size()
	_tip_turn += 1
	return ChatterDB.fill(tips[(_tip_turn - 1) % tips.size()], GameState.player_name)


## What Mom makes of your beasts' levels (their average, GameState.party_level), from your father's old trainer guide:
## next to the wild beasts where you are, or, with none here, where your next battles are (ChatterDB.MOM_AHEAD).
## Nothing before you have a beast, or with nowhere to compare.
static func level_advice(world) -> Array:
	if GameState.party.is_empty():
		return []
	var ahead := _ahead(world)
	if ahead.is_empty():
		return []
	var lo: int = ahead[1]
	var hi: int = ahead[2]
	var avg := GameState.party_level()
	var levels := "Lv %d" % lo if lo == hi else "Lv %d to %d" % [lo, hi]
	var lines := ["I've got your father's old trainer guide here. It says %s are %s, and yours are about Lv %d." % [ahead[0], levels, avg]]
	if avg < lo - WAY_BELOW:
		lines.append("They're far too strong for you just now, sweetie! Train somewhere easier first, and keep plenty of potions handy.")
	elif avg < lo:
		lines.append("They're a little strong for you. Win a few more battles first, and keep some potions handy.")
	elif avg > hi + ABOVE:
		lines.append("You're stronger than you need to be! Don't dawdle on my account. You could press on.")
	else:
		lines.append("That's just right. You're exactly where you ought to be.")
	return lines


## [who, lowest level, highest level]: the wild beasts on this map (once they're out: the Coastal Path's only after the
## flute), else where your next battles are; [] if neither.
static func _ahead(world) -> Array:
	var enc: Dictionary = world.map.get("encounter", {}) if world != null else {}
	if not enc.is_empty() and not (enc.get("after_flute", false) and not GameState.has_flute()):
		return ["the wild beasts %s" % _place(world), int(enc["lv"][0]), int(enc["lv"][1])]
	var to: String = ChatterDB.MOM_AHEAD.get(Story.next_goal(), "")
	if WorldDB.ROUTES.has(to):
		var r: Dictionary = WorldDB.ROUTES[to]
		if r.get("after_flute", false) and not GameState.has_flute():
			return []
		return ["the wild beasts on the %s" % r["name"], int(r["lv"][0]), int(r["lv"][1])]
	if WorldDB.ARENAS.has(to):
		var a: Dictionary = WorldDB.ARENAS[to]
		var lvs: Array = a["team"].map(func(s): return int(s[1]))
		return ["%s %s's beasts" % [a["title"], a["leader"]], lvs.min(), lvs.max()]
	if InteriorMaps.ROOMS.get(to, {}).has("encounter"):
		var lv: Array = InteriorMaps.ROOMS[to]["encounter"]["lv"]
		return ["the wild beasts in the crypt" if to.begins_with("crypt") else "the wild beasts there", int(lv[0]), int(lv[1])]
	return []


## Where you are, for Mom: "on the Coastal Path", "in the Temple of Tides", "round Bellerive".
static func _place(world) -> String:
	var m: Dictionary = world.map
	if m.get("kind", "") == "interior":
		if String(m.get("room_key", "")).begins_with("crypt"):
			return "in the crypt"
		var n := String(m.get("name", ""))
		return ("in the " if n.begins_with("Temple") else "in ") + n
	if WorldDB.ROUTES.has(world.map_id):
		return "on the " + String(WorldDB.ROUTES[world.map_id]["name"])
	return "round " + WorldDB.map_name(world.map_id)


## In your own home, where Mom is in the room.
static func _at_home(world) -> bool:
	return world != null and world.map.get("building", {}).get("shop", "") == "home"


## The phone ringing on your first morning: Dad, calling from work to wish you luck.
static func answer(world) -> void:
	stop_ringing(world)
	Sfx.play("door_close")
	await UI.say(["You pick up the phone."])
	await UI.say(["Hello? %s? It's Dad!" % GameState.player_name,
		"I'm still away up north for work, but I couldn't miss today. Your very own beast! I wish I could be there.",
		"Listen: call me whenever you can. Any phone will do. Every home has one, and so does every Beast Center.",
		"The red payphones by the town squares take five coins, mind.",
		"Tell me everything, and I'll write it all down for you. That way your adventure's never lost.",
		"Now go on. Elder Rowan's waiting, and so is the whole world. I'm so proud of you, kiddo."], "Dad")
	GameState.set_flag("called_dad")
	await _save()


## Dad asks before saving, then asks whether to keep playing, even if you declined the save.
static func _save() -> void:
	GameState.set_flag("called_dad")
	if await UI.ask("Would you like me to save your journey?", "Dad"):
		if not await GameState.main.save_with_card():
			return
	if not await UI.ask("Do you want to continue playing?", "Dad"):
		await UI.say(["\"Talk soon, kiddo.\" Click."])
		GameState.main.back_to_title()


## What Dad hears about your team.
static func _tally() -> String:
	var n := GameState.all_beasts().size()
	var crests := GameState.crests.size()
	var s := "%d beast%s" % [n, "" if n == 1 else "s"]
	if crests > 0:
		return "%s and %d crest%s! You're really doing it." % [s, crests, "" if crests == 1 else "s"]
	return "%s with you already? That's a fine start." % s if n > 0 else "No beast yet? It won't be long now."


## Sets the phones in the room ringing: shaking on their stands, the bell going every couple of seconds.
static func ring(world) -> void:
	if world.get_node_or_null("Ringer") == null:
		var r := Ringer.new()
		r.name = "Ringer"
		world.add_child(r)


static func stop_ringing(world) -> void:
	var r: Node = world.get_node_or_null("Ringer")
	if r != null:
		r.name = "RingerDone"
		r.queue_free()
	for p in world.get_tree().get_nodes_in_group("phones"):
		(p as Node3D).rotation.z = 0.0


class Ringer extends Node:
	var _t := 0.0
	var _next := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= _next:
			Sfx.play("phone_ring")
			_next = _t + 2.6
		var on := fmod(_t, 2.6) < 1.0
		for p in get_tree().get_nodes_in_group("phones"):
			(p as Node3D).rotation.z = sin(_t * 60.0) * 0.07 if on else 0.0
