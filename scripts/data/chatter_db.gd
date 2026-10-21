extends RefCounted
## Things townsfolk, house residents, trainers and mascots say. Each entry is one short conversation.
## "{player}" is replaced with the player's name.

## Anyone, anywhere.
const QUIRKY := [
	["I've been practising my 'wild beast appears' sound. BWAAAMP!", "...Did that scare you? It scared ME."],
	["My beast and I wear matching hats.", "Well, I wear a hat. He wears a bucket. It's the same energy."],
	["Psst. Want to know a secret?", "...I don't have one. I just really like saying 'psst'."],
	["I named my beast 'Lunch'.", "Now every time I call him, I get hungry. Rookie mistake."],
	["Some say the Pyrosaur was the very first beast.", "Others say it was a very confident potato. I'm in the potato camp."],
	["I counted every blade of grass in town. Then the wind blew.", "...Three. Four. Five..."],
	["Shh! I'm practising being a statue for the plaza.", "...", "Darn. I blinked."],
	["My grandma merged two beasts and got one that only speaks in sneezes.", "Bless you, Grandma's beast. Bless you forever."],
	["Have you ever looked at an egg and thought, 'that egg is judging me'?", "No? Just me, then. Carry on."],
	["I'm not lost. I'm exploring this exact spot. Very thoroughly.", "For three days."],
	["I tried to charm a wild beast with my kazoo.", "It charmed ME instead. I live in a bush now. Part-time."],
	["Do you think beasts dream?", "Mine dreams it's a slightly bigger version of itself. Ambitious little thing."],
	["Theory: the Sky Tower bird is just three small birds in a trench coat.", "Hang on. Birds don't wear coats. ...Do they?"],
	["My shoes are on the wrong feet on purpose. It confuses the wild beasts.", "And me. Mostly me."],
	["Every morning I shout 'GOOD MORNING' at the sea.", "One day it'll answer. One day."],
	["Shh! I'm hiding from my beast. We're playing hide and seek.", "It's been winning since Tuesday."],
	["Is that a flute? Can you play 'Happy Birthday'?", "It's not my birthday. I just like to be prepared."],
	["I keep a diary of every cloud I see.", "Today's cloud looked like a cloud. Very disappointing entry."],
	["I'm the official town puddle inspector.", "That puddle over there? Exquisite. Five stars. Would splash again."],
	["They say merging mixes two beasts' best traits.", "So I merged my sandwich with my other sandwich. Now I have lunch."],
	["Rumour has it if you spin around ten times in tall grass, you meet a wild beast.", "Rumour also has it you fall over. Both rumours are true."],
	["I'm writing a book called 'Beasts I Have Petted'.", "Chapter one: all of them. Chapter two: more of them."],
	["Ever notice nobody in town locks their doors?", "I've been inside eleven houses today. Lovely curtains, all of them."],
	["My beast learned a new move: Stare Menacingly.", "It's not very effective. It is VERY unsettling, though."],
	["I'm saving up for a Golden Flute. So far I have... one button.", "It's a nice button."],
	["{player}! I KNEW it was you. I never forget a face.", "...Who are you again?"],
	["Hello! I'm doing a survey. Do you like surveys?", "Great, that's the survey. Thank you for your time."],
	["My beast ate my homework. I don't have homework. I'm forty-two.", "I don't know where it found homework."],
	["I've decided to become mysterious.", "...", "How am I doing? Be honest."],
	["Wild beasts are just tame beasts that haven't met the right snack yet. That's my philosophy."],
	["I once high-fived a Tempestrix. My hair has been like this ever since."],
	["I'm training to be the world's best trainer trainer.", "I train trainers to train. My first student is a rock. We're making progress."],
	["Excuse me, have you seen a sock? Blue, slightly heroic, answers to 'Gerald'?"],
	["They say an egg dropped by a defeated beast is a gift.", "I got one once. It was a regular chicken egg. Delicious, though."],
	["Some people collect beasts. I collect beast sneezes. In jars.", "Don't open the green one."],
]

## Town-specific characters (keyed by town id).
const TOWNS := {
	"caccoon": [
		["The Embits nap on the rooftops here.", "I tried it once. The roof did not appreciate me."],
		["Elder Rowan has been 'about to retire' for forty years.", "Every year he says 'just one more trainer'. That's you! Congratulations, you're his excuse."],
		["Welcome to Cocoon Cove: population small, naps large."],
	],
	"tidewater": [
		["I'm a sailor! Well, I've seen a boat.", "From a distance. It was very nautical."],
		["The ferry captain says the sea is 'moody'.", "I say it's just wet. We don't talk anymore."],
		["Sparkwire Electronics fixed my toaster! Now it plays music.", "It doesn't toast anymore. But what a voice."],
	],
	"shellhaven": [
		["Kelpwick folk put PINEAPPLE on their fish pie.", "Unforgivable. Unforgivable and delicious. But mostly unforgivable."],
		["I've been feuding with Kelpwick for ten years. I don't remember why.", "I think it started over a hat."],
	],
	"kelpwick": [
		["Shellhaven folk think seaweed is a vegetable.", "...It is a vegetable. Don't tell them I said that."],
		["I dive for pearls! Today I found a spoon.", "It's a very shiny spoon. I'm calling it a pearl."],
	],
	"dustwell": [
		["This oasis is the only water for miles. I drink it very, very politely."],
		["Sand gets everywhere. EVERYWHERE.", "I found some in a dream once."],
	],
	"sundown": [
		["Yeehaw!", "Sorry. It just slips out. Happens about forty times a day."],
		["I'm the fastest draw in the west.", "Draw what? Mostly ducks. I'm very good at ducks."],
		["This town ain't big enough for the both of us.", "...Kidding! There's loads of room. Want a biscuit?"],
	],
	"copperpick": [
		["I dig holes for a living. Then I fill them back in.", "Job security."],
		["Mining tip: if the rock says 'ouch', it's not a rock. Apologise and walk away."],
	],
	"cogsworth": [
		["I invented a machine that makes tea!", "It also makes noise. Mostly noise. The tea is just a rumour."],
		["Everything in this city ticks. The clocks, the pipes, the trams...", "Even me, if I eat too many beans."],
		["Gearhart put a meter on the air. I've been holding my breath since Monday.", "...", "...okay that was a lie. Please don't tell him."],
	],
	"emberfall": [
		["The hot springs here cure everything!", "Except my fear of hot springs. Ironic, really."],
		["I boiled an egg in the spring once. It hatched. We're friends now. Awkward."],
	],
	"vinehollow": [
		["The jungle whispers secrets to those who listen.", "Mostly it whispers 'bring snacks'."],
		["I'm a vine. ...What? No, I'm a person. I've just been out here a long time."],
	],
	"riverbend": [
		["I've been fishing this river twenty years. Caught one fish.", "We're friends now. I let him go every Sunday, and he comes back every Monday."],
		["Did you know rivers only flow one way? I've been checking. Still one way."],
	],
	"gravenmoor": [
		["Spooky? Nah. The ghosts here are lovely.", "One of them helps me with my crosswords. It knows every word for 'ominous'."],
		["I'm not scared of the Legion.", "I'm scared of the gravedigger's soup. He calls it 'Surprise'. It's never a nice surprise."],
	],
}

## Residents in houses.
const RESIDENTS := [
	["Oh! A visitor! Quick, everyone act natural!", "...I live alone. I panicked."],
	["Welcome to my home! Please wipe your feet. And your hands. And your opinions about my wallpaper."],
	["My grandpa merged a Crystusk with a Tempestrix once. It had wings AND tusks!", "It couldn't fly. It just sort of... trotted majestically."],
	["Have you been up a Sky Tower? The big bird flies you anywhere you've been!", "I asked it to fly me to the moon. It gave me a look."],
	["My beast dropped an egg after a battle once. The Beast Center hatched it for free!", "Now I have two beasts and zero quiet mornings."],
	["I found a crystal shard behind the well. They say five of them make a shield!", "I made a very small hat out of mine instead. No regrets."],
	["Shh, the baby's sleeping.", "...The baby is my beast. It's twelve. It sleeps a LOT."],
	["Please don't open the cupboard. There's nothing in the cupboard.", "...", "Okay, there's a Flittle in the cupboard. It pays rent."],
	["I'm learning the flute! Listen!", "♪ Fweeeee-HONK ♪", "...I'm learning."],
	["Earth beasts can protect the whole team. I always bring one along.", "Mostly to carry my snacks. Very sturdy snack carriers."],
	["You can stay for tea! I only have hot water and good intentions, though."],
]

## Shouted through a locked front door when you knock.
const LOCKED_DOOR := [
	["Can't come to the door! I'm three notes into Capture XI and my fingers are SWEATING."],
	["Nobody's home!", "...This is a recording. Beep."],
	["Go away, I'm in my pajamas! The ones with little beasts on them. They're very dignified."],
	["If you're selling eggs, I've already got forty-eight. One of them is wiggling. Send help."],
	["Shh! My beast JUST fell asleep. Knock again and you're babysitting."],
	["Can't talk, I'm in the middle of a merge!", "Oh no. Oh no, it has eight legs now. Come back later!"],
	["Mom? I SAID I'd tidy my room after this battle!", "...Oh. You're not Mom. Awkward."],
	["Is it the Umbral Legion? Tell them I already gave at the office!"],
	["Leave it on the step! Unless it's cake. If it's cake, slide it under the door. Slowly."],
	["Who's there?", "...No, see, YOU'RE meant to say who's there. Nobody knows how knocking works any more."],
	["I can't open up, my beast is guarding the door. He's very fierce. He's licking the doorknob right now."],
	["Sorry! I'm having a bubble bath with my water beast. It's mostly beast at this point."],
	["Is that {player}? Wait right there, I'll find a pen for an autograph!", "...", "...I can't find a pen. Bye!"],
	["No visitors! We have a very important nap scheduled. It's a family tradition."],
	["Not now! I've been on hold with the Sky Tower for three hours and the Tempestrix just picked up!"],
	["I can't find my key! I've looked everywhere except where I left it, which is probably where it is."],
]

## Shouted through the barred doors of Gravenmoor Cathedral.
const CATHEDRAL_DOOR := [
	["Go away! The Umbral Legion is closed for a very evil private event. Totally normal. Nothing to see."],
	["What's the password?", "...Wrong! It was 'please'. Nobody ever says please."],
	["We're not in! Leave a message after the spooky noise.", "OooOOOooooo... beep."],
	["Who dares knock upon the doors of shadow?!", "...Oh, it's a kid. Shoo! We're doing a ritual. It's very scary. There are candles."],
]

## Route trainers.
const OPENERS := [
	"Our eyes met! By ancient law, we must now battle!", "I've been training all day. Mostly napping. But training-adjacent!",
	"My beasts are itching for a fight! ...Literally. Do you have any ointment?", "Hey! Show me what your beasts can do!",
	"You look like a worthy opponent! Or a lost tourist. Let's find out!", "Battle me! I've been standing here for hours. My legs hurt.",
	"I've never lost a battle! ...Today. It's still early.", "Prepare yourself! I practised a cool pose for this!",
]
const DEFEATS := [
	"Wow, you're strong! Can I have your autograph? On my sad little face?", "I need more training... and possibly a nap.",
	"Your beasts work so well together! Mine just argue.", "Good battle! I'm going to go stand dramatically in the rain now.",
	"I lost? But I did the cool pose!", "Defeated by a beginner... I'll tell everyone you were a professional.",
]

## Mascots doing mascot things ("%s" is the mascot's name).
## Townsfolk on their mascot's signature move (see MoveDB.SIGNATURE): {mascot}, {move} and {lv} are filled in.
const MASCOT_MOVE := [
	"Read the plaque on our statue? Our {mascot} teaches {move} to any {mascot} of Lv {lv}. My {mascot} is Lv 3. We're working on it.",
	"I asked our {mascot} to teach ME {move}. It looked at me like I'd asked a fish to climb a ladder. Only another {mascot} can learn it.",
	"Rumour has it our {mascot} knows {move}. It only shows a fellow {mascot}, and only one of Lv {lv} or more. Very exclusive club.",
	"A {mascot} at Lv {lv} can learn {move} from ours. It's the strongest move a {mascot} will ever know. Ours mostly uses it to open coconuts.",
	"Our mascot won't teach {move} to just anyone. It has to be a {mascot}, Lv {lv} or better. I tried a fake moustache. It didn't fall for it.",
	"Every town's mascot has a secret move for its own kind. Ours is {move}. Bring a Lv {lv} {mascot} and watch the fireworks!",
]
const MASCOT := [
	"The %s chases its own tail. It's winning.",
	"The %s yawns, stretches, and pretends you don't exist. Classic mascot.",
	"The %s sniffs your bag suspiciously. It is convinced you have snacks.",
	"The %s strikes a heroic pose for the tourists. There are no tourists.",
	"The %s chirps happily. It seems to be this town's beloved mascot.",
	"The %s does a little dance. Nobody asked. Everybody's glad.",
]


## Casual hints about what to do next, by Story.next_goal(): townsfolk add one to whatever else they say, so what they
## talk about moves on as soon as you've done it.
const HINTS := {
	"egg": ["Elder Rowan's waiting in the plaza with a beast egg for you. She's been polishing it all morning. It's very shiny now.",
		"Big day, huh? Go and see Elder Rowan in the plaza. She's got something round and important for you.",
		"I'd hurry to the plaza if I were you. Last time Elder Rowan waited, she knitted a whole sweater. For a Pyrosaur."],
	"hatch": ["An egg! Nurse Clover at the Beast Center can hatch that for you. It's right across from the square: red-and-white awning, red paw print over the door.",
		"Eggs don't hatch in your pocket, you know! The Beast Center's the one by the square with the striped awning and the paw-print sign.",
		"The Beast Center's incubator is warm and cosy. Your egg would love it. Just across the road from the statue, under the red-and-white awning."],
	"path": ["Heading down the Coastal Path? The trainers out there teach every newcomer how battling works. Listen to them!",
		"Scout Bram's opened the east gate for you. Follow the trail, and the trainers along it will show you the ropes.",
		"My first battles were on the Coastal Path. A camper taught me everything. Then a fisher taught me everything again, but slower.",
		"The footbridge on the Coastal Path washed out. Old Hal the builder lives in the log cabin by the creek. Ask him about it!"],
	"bridge": ["Old Hal's lending you his logs? They're stacked by his door. Lay them across the footbridge's old posts.",
		"Logs don't lay themselves! Take Hal's to the footbridge's posts by the creek.",
		"Once that footbridge on the Coastal Path is mended, Tidewater's just a stroll away."],
	"builder_egg": ["You mended the footbridge? Go and tell Old Hal! He's been talking about an egg he found after the storm.",
		"Hal the builder never forgets a favour. Pop into his cabin by the creek before you head on."],
	"flute": ["Tidewater's at the far end of the Coastal Path. Your uncle Rafe lives right by its west gate.",
		"I hear Rafe in Tidewater has been polishing a reed flute for years. Waiting for someone, maybe? Someone like you?",
		"Your uncle in Tidewater is keeping your father's flute. Go and get it!"],
	"rafe": ["Rafe's lessons are worth finishing. Weaken AND Capture! A trainer without songs is just a person with a pet.",
		"Go back and see your uncle. He's got songs to teach you. He hums them in the street. It's very distracting."],
	"arena": ["Tidewater's arena gives every new trainer battle lessons before they face Tide Captain Marina. Coach Rory and Coach Ondine wait just inside the door. You can't miss them. They won't let you.",
		"Want to sail to the Isle of Tides? Captain Gull only takes trainers with Marina's Wave Crest. Start with the arena's coaches!",
		"Coach Rory yells a lot, but he knows teamwork. Coach Ondine knows elements. Between them, Marina won't know what hit her."],
	"marina": ["Done with the coaches? Then Tide Captain Marina's waiting in the arena's ring. Her beasts are all water... and water hates air.",
		"Win Marina's Wave Crest and Captain Gull will happily sail you to the Isle of Tides.",
		"Marina's beasts are all water. Bring something airy. Or something with a lot of confidence."],
	"ferry": ["Captain Gull's ferry sails from Tidewater's long pier to the Isle of Tides. The islanders are having a terrible squabble, I hear.",
		"The Isle of Tides! Take the ferry from the pier. Bring a sweater. And a referee: Shellhaven and Kelpwick are at each other's throats.",
		"Tried your flute on a wild beast yet? Weaken first, then Capture. Then catch the ferry from the pier. The island's waiting."],
	"chiefs": ["Heard one side of the island feud? Better hear the other too. Chief Marlo's in Shellhaven, Chief Coralie's in Kelpwick, along the Isle Trail.",
		"Two villages, two chiefs, one big misunderstanding. Talk to both of them!"],
	"smuggler": ["Someone's been skulking about the Isle Trail with a sack of nets. Suspicious, if you ask me. Nobody ever asks me.",
		"If neither village did it, who did? I'd look along the Isle Trail. Smugglers love a trail."],
	"peace": ["You caught the smuggler? Go and tell one of the chiefs! They'll want to hear it from you.",
		"The chiefs are still glaring at each other. Go and tell them what you found!"],
	"temple": ["The coral gate's open past Kelpwick! The Temple of Tides is out across the reef. Its guardian keeps the sea, and some say the desert winds, all riled up.",
		"Calm the Temple of Tides and the sandstorms on the Dune Road might settle. That's what my aunt says. She's usually right about weather.",
		"Past Kelpwick and over the reef stands the Temple of Tides. Bring waterproof courage."],
	"desert": ["The Dune Road north of Tidewater is open again! Dustwell Oasis is lovely. Sundown Gulch beyond it is... less lovely. Bandits.",
		"The sandstorms have settled! Head north from Tidewater into the desert. I hear Sundown's sheriff could use a hand."],
	"bandits": ["Black Bart's gang holes up in a hideout near Sundown Gulch. Somebody ought to give them what for.",
		"The sheriff in Sundown can't handle Black Bart alone. You look like you could."],
	"winds": ["With Black Bart gone, the Dune Sea road is open. They say the Temple of Winds stands out in those dunes.",
		"North of Sundown, over the Dune Sea, lies Copperpick. And somewhere in the dunes, the Temple of Winds."],
	"mine": ["The Mine Road out of Copperpick is closed without a Miner's Pass. Foreman Gorran signs them if you beat him at the Copperpick Arena.",
		"Want to reach Cogsworth? You'll need a Miner's Pass. Copperpick's arena is where you earn one."],
	"gearhart": ["Magnus Gearhart has Cogsworth under his thumb, and he's sealed the road to the volcano. Someone should climb that tower of his.",
		"Gearhart Tower is crawling with robot sentries. Beat every one on a floor and the stairs open up."],
	"flame": ["The Caldera Road's open now that Gearhart's beaten! The Temple of Flame waits on the way to Emberfall. Bring a water beast for the lava.",
		"Past Cogsworth, up the Caldera Road, the Temple of Flame. Sunscreen recommended."],
	"jungle": ["Over the Summit Pass lies Vinehollow, deep in the jungle. Their shaman's been looking for a capable trainer.",
		"Vinehollow sells the finest gear in the land. And their shaman has a job for someone brave."],
	"relics": ["Shaman Ayo needs the Sun, Moon and Earth relics. They're scattered far and wide. Keep your eyes peeled!",
		"Found any relics yet? The shaman in Vinehollow is counting on you."],
	"roots": ["The ritual raised the Temple of Roots on the Jungle Trail! Go and see it before the vines take it back.",
		"There's a temple on the Jungle Trail that wasn't there last week. You should probably go and poke it."],
	"gravenmoor": ["Past Riverbend, the Moor Road leads to Gravenmoor, the Umbral Legion's town. Old Mort the gravedigger knows a song that soothes ghosts.",
		"Commander Nyx guards Gravenmoor Cathedral. Bring strong, merged beasts. Ghosts have no weakness."],
	"vexmora": ["General Vexmora waits in the crypt beneath the cathedral. This is it. Go and get her!",
		"The Legion's general is down in the crypt. Everyone's counting on you. No pressure!"],
	"done": ["You saved us all! Now, about that sweater I knitted you...",
		"The whole land's talking about you. Mostly good things. One bad thing, about your hat."],
}


static func pick(list: Array, rng: RandomNumberGenerator) -> Variant:
	return list[rng.randi_range(0, list.size() - 1)]


static func fill(lines: Array, player: String) -> Array:
	var out := []
	for l in lines:
		out.append(String(l).replace("{player}", player))
	return out
