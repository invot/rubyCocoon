extends RefCounted
## The Codex's topics: what the little robot head explains (scripts/ui/codex.gd). Picnicker Mae gives you the Codex
## after the Coastal Path's last lesson ("has_codex"); from then on it chimes in during battle the first time something
## new comes up (flag "codex_seen_<id>"), and answers questions from its battle row (Codex ?), from a tap on it, or from
## the Codex page of the Start book. It only answers what you're eligible to know: a topic about something you don't
## have yet (the bat, a flute, a summon...) stays hidden until you do (see eligible()).
##
## lines: each one bubble, beginning with its mood in brackets (codex_head.gd MOODS), so the brows change with every
## bubble. Keep each line to one bubble (three lines of speech).

## Topic groups, in the order the Codex lists them.
const GROUPS := ["Battle basics", "Your team", "Moves", "Gear and songs"]

const TOPICS := {
	"codex": {"title": "Using the Codex", "group": "Battle basics", "lines": [
		"[happy] I'm your Codex! When something new comes up in battle, I'll chime in.",
		"[proud] To ask me anything in battle, tap me or pick Codex beside your trainer. Asking never uses your turn.",
		"[curious] Outside battle, find me on the Codex page of your Start book."]},
	"attack": {"title": "Attacking", "group": "Battle basics", "lines": [
		"[neutral] Choose your own action first, then each beast's move. Left and right change a choice, A picks it, B goes back.",
		"[determined] Then aim with left and right and confirm with A. On touch, tap a foe to aim and tap it again to confirm.",
		"[curious] HP is health. MP powers elemental moves; plain moves are free, so you can always fight."]},
	"defend": {"title": "Defending", "group": "Battle basics", "lines": [
		"[worried] Big hit coming? Choose Defend for that beast.",
		"[proud] A defending beast takes half damage until your side's next turn, and Defend always goes first."]},
	"turns": {"title": "Who goes first", "group": "Battle basics", "lines": [
		"[neutral] Everyone chooses first, then the two sides take turns. Faster beasts and a higher trainer level go first.",
		"[curious] On your side's turn, your own action comes before your beasts move."]},
	"items": {"title": "Items", "group": "Battle basics", "lines": [
		"[happy] Pick Items beside your trainer to use something from your bag. That's your action for the round.",
		"[neutral] Potions heal HP, Spirit Drops bring back MP, and there are cures, bombs and tonics too. Apothecaries sell them."]},
	"slingshot": {"title": "Your slingshot", "group": "Battle basics", "lines": [
		"[determined] Slingshot fires a stone at a foe, or at a trainer left open to attack.",
		"[neutral] Watch skips your own action and lets your beasts handle the round."]},
	"run": {"title": "Run and Forfeit", "group": "Battle basics", "lines": [
		"[worried] Run tries to escape a wild battle.",
		"[neutral] Against a trainer it's Forfeit instead. It counts as a loss, but you keep your gold and can try again."]},
	"guard": {"title": "Guarding your trainer", "group": "Your team", "lines": [
		"[determined] The beast in the middle of the side facing the foe guards its trainer.",
		"[excited] Knock out the foe's middle beast, and the trainer behind it is open to attack!",
		"[worried] Every hit on a trainer breaks one shield point. A trainer hit with no shield left loses. Shields recharge after every battle."]},
	"team": {"title": "Choosing for each beast", "group": "Your team", "lines": [
		"[excited] Every standing beast on the side facing the foe gets its own move each round!",
		"[neutral] After your own action, up and down switch between your beasts' bars. Left and right pick each one's move.",
		"[curious] With several foes, left and right choose who to aim at. The arrows show who each move will hit."]},
	"move": {"title": "Moving your beasts", "group": "Your team", "lines": [
		"[neutral] Move uses a beast's turn to change its ring slot. Pick a lit pad with up and down, then A.",
		"[worried] If your middle beast faints, you're open to attack! Move a corner beast into the middle to guard you again.",
		"[curious] A beast can swap places with a fainted one. Only one beast can Move each round."]},
	"ring": {"title": "Turning the ring", "group": "Your team", "lines": [
		"[curious] Your ring has a side for each element, in this order: Fire, Air, Water, Earth. Only the side facing the foe fights.",
		"[excited] To turn it, choose your own action first, then press up past the top beast or down past the bottom one.",
		"[happy] Turning is free! The new side then chooses its moves. Keep a standing beast in its middle."]},
	"elements": {"title": "Elements", "group": "Your team", "lines": [
		"[curious] Fire is weak to air, earth to water, water to air, and air to fire. A weak beast takes double damage!",
		"[neutral] A beast hit with its own element shrugs some off. Only the element of the side facing the foe can be used.",
		"[excited] While aiming, a red burst means the foe is weak to that move; a shield means it resists."]},
	"retarget": {"title": "When a target falls", "group": "Moves", "seen": true, "lines": [
		"[surprised] If an attack's target falls first, it aims at another standing foe. With none left, it can hit an open trainer.",
		"[neutral] A heal goes to the ally with the least HP left. A revive stays on its chosen beast."]},
	"passives": {"title": "Abilities and gear", "group": "Moves", "seen": true, "lines": [
		"[happy] Abilities and worn gear work by themselves. They never use a turn.",
		"[curious] The Beasts page of your Start book explains each beast's abilities and gear."]},
	"accuracy": {"title": "Accuracy", "group": "Moves", "seen": true, "lines": [
		"[worried] Some moves can miss. Accuracy is the hit chance, and evasion makes a target harder to hit.",
		"[neutral] A miss still spends the move's MP, so read its description first."]},
	"cooldown": {"title": "Recharging moves", "group": "Moves", "seen": true, "lines": [
		"[neutral] Some moves need to recharge. Their menu shows how many turns are left.",
		"[happy] Pick another move while you wait. Plain attacks cost no MP."]},
	"support": {"title": "Helping your beasts", "group": "Moves", "seen": true, "lines": [
		"[happy] Some moves help your own beasts. Choose the move, aim at an ally and confirm with A.",
		"[proud] Healing restores HP, and a revive brings back a fainted beast."]},
	"all_targets": {"title": "Moves that hit everyone", "group": "Moves", "seen": true, "lines": [
		"[excited] This kind of move reaches everyone the arrows show. Confirm the whole group once with A."]},
	"status": {"title": "Status effects", "group": "Moves", "seen": true, "lines": [
		"[worried] Status effects can hurt a beast or stop it acting. The top bar says what a move does.",
		"[neutral] Cure items and cleansing moves remove them. Defend only reduces damage."]},
	"stats": {"title": "Boosts and drops", "group": "Moves", "seen": true, "lines": [
		"[curious] Boosts make a beast's stats stronger; drops make them weaker. They last for this battle.",
		"[neutral] A move's description names the stats it changes."]},
	"recoil": {"title": "Recoil and drain", "group": "Moves", "seen": true, "lines": [
		"[worried] Recoil hurts the beast using the move too. Check its HP first.",
		"[happy] Drain works the other way: it heals the user from the damage dealt."]},
	"protection": {"title": "Protective moves", "group": "Moves", "seen": true, "lines": [
		"[determined] Protective moves can absorb hits, draw attacks or strike back. The top bar says how long they last."]},
	"flute": {"title": "The flute in battle", "group": "Gear and songs", "needs": "flute", "lines": [
		"[excited] Pick Flute beside your trainer and play a song! Faster, cleaner playing makes a stronger effect.",
		"[curious] Weaken makes a foe drop its guard, so your beasts hit harder. Playing is your action for the round.",
		"[neutral] No song makes a wild beast yours. New beasts only ever hatch from eggs."]},
	"eggs": {"title": "Eggs", "group": "Gear and songs", "lines": [
		"[happy] Beat a wild beast and now and then it leaves an egg behind. Eggs are how your team grows!",
		"[curious] Kennels on the roads have beasts to adopt, too."]},
	"rhythm": {"title": "Rhythm attacks", "group": "Gear and songs", "needs": "rhythm", "lines": [
		"[excited] Your weapons chain hits to the music! Choose a weapon and its target, and a white ring appears.",
		"[determined] Press A, or tap the ring, each time the spinning notch meets the mark at the top.",
		"[proud] A miss ends the chain, but hits already landed count. Fill every pip and the last hit is critical!"]},
	"summon": {"title": "Summons", "group": "Gear and songs", "needs": "summon", "lines": [
		"[excited] A temple guardian answers your flute! Pick Summon beside your trainer and play its song through.",
		"[neutral] It strikes every foe at once. A summon costs one shield point and answers once per battle.",
		"[proud] Better playing makes the summon stronger."]},
	"boomerang": {"title": "Boomerang", "group": "Gear and songs", "needs": "boomerang", "lines": [
		"[excited] Your Boomerang sweeps every foe facing you in one throw. Confirm all its targets together.",
		"[neutral] Each extra target takes a slightly softer hit."]},
	"bat": {"title": "Bat", "group": "Gear and songs", "needs": "bat", "lines": [
		"[determined] Your Bat hits one foe harder than your other weapons. Pick it beside your trainer, aim, then A."]},
}

## Little noises the Codex sometimes starts a bubble with.
const BEEPS := ["Beep boop!", "Boop!", "Bleep bloop!", "Bzzt!", "Whirr...", "Ding!", "Beep!", "Blip blip!"]


static func has_codex() -> bool:
	return GameState.flag("has_codex")


## Whether you know enough to be told about `id`: you own the thing it's about (needs), and for the move rules
## ("seen": true), you've met one in battle (the Codex chimed in about it).
static func eligible(id: String) -> bool:
	if not has_codex() or not TOPICS.has(id):
		return false
	var t: Dictionary = TOPICS[id]
	if t.get("seen", false) and not GameState.flag("codex_seen_" + id):
		return false
	match String(t.get("needs", "")):
		"flute":
			return GameState.has_flute()
		"rhythm":
			return GameState.flag("dance_lesson_done") and GameState.trainer_level >= 4
		"summon":
			return not GameState.summons.is_empty()
		"boomerang", "bat":
			return GameState.weapons().has(String(t["needs"]))
	return true


## The topics you may ask about, grouped: [{"group": name, "ids": [...]}, ...] (empty groups left out).
static func menu() -> Array:
	var out := []
	for g in GROUPS:
		var ids := []
		for id in TOPICS:
			if String(TOPICS[id]["group"]) == g and eligible(String(id)):
				ids.append(id)
		if not ids.is_empty():
			out.append({"group": g, "ids": ids})
	return out


static func title(id: String) -> String:
	return String(TOPICS.get(id, {}).get("title", id))


## A topic's lines as [mood, text] pairs.
static func lines(id: String) -> Array:
	return TOPICS.get(id, {}).get("lines", []).map(func(l): return parse(String(l)))


## "[mood] text" -> [mood, text] ("" mood when there's none).
static func parse(line: String) -> Array:
	if line.begins_with("["):
		var e := line.find("]")
		if e > 0:
			return [line.substr(1, e - 1), line.substr(e + 1).strip_edges()]
	return ["", line]


## The topic's words without their moods, for the book's page.
static func plain(id: String) -> String:
	return "\n\n".join(lines(id).map(func(p): return String(p[1])))
