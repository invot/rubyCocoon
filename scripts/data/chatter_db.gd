extends RefCounted
## Things townsfolk, house residents, trainers and mascots say. Each entry is one short conversation.
## "{player}" is replaced with the player's name.

## Anyone, anywhere.
const QUIRKY := [
	["I've been practising my 'wild beast appears' sound. BWAAAMP!", "...Did that scare you? It scared ME."],
	["My beast and I wear matching hats.", "Well, I wear a hat. He wears a bucket. It's the same energy."],
	["Psst. Want to know a secret?", "...I don't have one. I just really like saying 'psst'."],
	["I named my beast 'Lunch'.", "Now every time I call him, I get hungry. Rookie mistake."],
	["Some say the Redcoon was the very first beast.", "Others say it was a very confident potato. I'm in the potato camp."],
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
	["I once high-fived a Thunderhawk. My hair has been like this ever since."],
	["I'm training to be the world's best trainer trainer.", "I train trainers to train. My first student is a rock. We're making progress."],
	["Excuse me, have you seen a sock? Blue, slightly heroic, answers to 'Gerald'?"],
	["They say an egg dropped by a defeated beast is a gift.", "I got one once. It was a regular chicken egg. Delicious, though."],
	["Some people collect beasts. I collect beast sneezes. In jars.", "Don't open the green one."],
]

## Town-specific characters (keyed by town id).
const TOWNS := {
	"caccoon": [
		["The Redcoons nap on the rooftops here.", "I tried it once. The roof did not appreciate me."],
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
	["My grandpa merged a Burrowbun with a Zephyrling once. It had wings AND floppy ears!", "It couldn't fly. It just sort of... hopped majestically."],
	["Have you been up a Sky Tower? The big bird flies you anywhere you've been!", "I asked it to fly me to the moon. It gave me a look."],
	["My beast dropped an egg after a battle once. The Beast Center hatched it for free!", "Now I have two beasts and zero quiet mornings."],
	["I found a crystal shard behind the well. They say five of them make a shield!", "I made a very small hat out of mine instead. No regrets."],
	["Shh, the baby's sleeping.", "...The baby is my beast. It's twelve. It sleeps a LOT."],
	["Please don't open the cupboard. There's nothing in the cupboard.", "...", "Okay, there's a Wisplet in the cupboard. It pays rent."],
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
	["Not now! I've been on hold with the Sky Tower for three hours and the Thunderhawk just picked up!"],
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
const MASCOT := [
	"The %s chases its own tail. It's winning.",
	"The %s yawns, stretches, and pretends you don't exist. Classic mascot.",
	"The %s sniffs your bag suspiciously. It is convinced you have snacks.",
	"The %s strikes a heroic pose for the tourists. There are no tourists.",
	"The %s chirps happily. It seems to be this town's beloved mascot.",
	"The %s does a little dance. Nobody asked. Everybody's glad.",
]


static func pick(list: Array, rng: RandomNumberGenerator) -> Variant:
	return list[rng.randi_range(0, list.size() - 1)]


static func fill(lines: Array, player: String) -> Array:
	var out := []
	for l in lines:
		out.append(String(l).replace("{player}", player))
	return out
