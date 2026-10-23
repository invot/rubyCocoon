extends RefCounted
## The telephone. Your dad is away working, and calling him is how the game is saved: you tell him how your journey
## is going, he cheers you on, and the game saves; then you can play on, or stop for now (back to the title screen).
## Saving never costs anything: the red phones in homes, Beast Centers, some shops, the arenas and some temple
## doorways are free to use. Only a payphone in the street takes FEE coins for the call, and without them there's no
## call (a phone indoors is free).
## The first time you go to leave home, the phone rings: Dad, calling to wish you luck (see Story.can_use_exit).

const FEE := 5

## What Dad says about where you've got to (Story.next_goal()).
const NEWS := {
	"egg": ["Elder Rowan's waiting with your egg? Then what are you doing talking to me? Off you go!"],
	"hatch": ["An egg! Take it to Nurse Clover at the Beast Center. Eggs like a warm incubator, not a warm pocket."],
	"path": ["The Coastal Path! I learned to battle on that path. Listen to the trainers out there. They know their stuff."],
	"bridge": ["Mending Old Hal's footbridge? Good. Always leave a road better than you found it."],
	"builder_egg": ["Old Hal never forgets a favour. Go and see him before you head on."],
	"flute": ["My old reed flute's waiting for you with your uncle Rafe in Tidewater. He'll make you practise. Practise anyway."],
	"rafe": ["Learn every song Rafe teaches you. Weaken first, then Capture. That's how I caught my Tempestrix. Allegedly."],
	"arena": ["Tidewater's arena! Listen to the coaches before you take on Marina. Nobody skips Rory's lesson. Nobody."],
	"marina": ["Marina's tough. Her beasts are all water, so bring something airy. And don't let her splash you first."],
	"ferry": ["The Isle of Tides! Those two villages have been squabbling since before I was born."],
	"chiefs": ["Hear both chiefs out before you take a side. There's always more to a feud than the first story."],
	"smuggler": ["Someone's stirring up trouble on the island? Keep your eyes open on the Isle Trail."],
	"peace": ["You found who did it? Go and tell the chiefs! You'll be the most popular kid on the island."],
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


## Uses the phone at `world`'s map: `fee` coins for a payphone. Calls Dad, who hears your news; the game is saved.
static func call_home(world, fee := 0) -> void:
	if world != null and world.get_node_or_null("Ringer") != null:
		await answer(world)
		return
	if fee > 0:
		if GameState.gold < fee:
			Sfx.play("error")
			await UI.say(["A payphone. It takes %d coins to make a call, and you only have %d." % [fee, GameState.gold],
				"The red phones in people's homes are free to use, and so is the one in every Beast Center."])
			return
		if not await UI.ask("A payphone. Put in %d coins to call Dad?" % fee):
			return
		GameState.gold -= fee
		Sfx.play("buy")
	elif not await UI.ask("A telephone. Call Dad?"):
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


## Saves, then: play on, or stop for now (back to the title screen)?
static func _save() -> void:
	GameState.set_flag("called_dad")
	if not await GameState.main.save_with_card():
		return
	var c: int = await UI.choose("Dad wrote it all down. Your journey is saved.", ["Keep playing", "Stop for now"], {"cancel": false})
	if c == 1:
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
