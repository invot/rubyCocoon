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
	["I tried to soothe a wild beast with my kazoo.", "It soothed ME instead. I live in a bush now. Part-time."],
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
		["First day of spring! The Embits woke up hungry. One tried to eat the trainer-season bunting."],
		["The Embits nap on the rooftops here.", "I tried it once. The roof did not appreciate me."],
		["Elder Rowan has been 'about to retire' for forty years.", "Every year he says 'just one more trainer'. That's you! Congratulations, you're his excuse."],
		["Welcome to Cocoon Cove: population small, naps large."],
	],
	"tidewater": [
		["I'm a sailor! Well, I've seen a boat.", "From a distance. It was very nautical."],
		["The ferry captain says the sea is 'moody'.", "I say it's just wet. We don't talk anymore."],
		["Sparkwire Electronics fixed my toaster! Now it plays music.", "It doesn't toast anymore. But what a voice."],
		["The café on the riverfront sells beignets. Wear dark clothes and you'll leave covered in sugar.", "Wear light clothes and nobody will ever know."],
		["Every balcony on Rue Royale has a fern on it. I asked why.", "The ferns wouldn't say."],
		["Miss Odile feeds the wild beasts in the park candy corn, and they follow her round like ducklings.", "I tried it. They followed me round like a bill collector."],
		["Somebody plays the trumpet on the promenade every evening.", "Badly. Lovingly, but badly."],
	],
	"shellhaven": [
		["We took a day trip to Kelpwick. So rustic! They cook over actual fire.", "I asked for a menu and they handed me a fish."],
		["I brought home a little carving from the temple steps. Well, from the temple. Well, it was part of the temple.", "It looks lovely on the mantelpiece. Much better than on some old wall."],
	],
	"kelpwick": [
		["Resort folk call our huts 'charming'. They say it the way you'd talk about a puppy.", "We built these huts to stand a hundred storms. Their hotel needs a new coat of paint every spring."],
		["I dive for pearls! Today I found a spoon.", "It's a very shiny spoon. I'm calling it a pearl."],
	],
	"dustwell": [
		["This oasis is the only water for miles. I drink it very, very politely."],
		["Sand gets everywhere. EVERYWHERE.", "I found some in a dream once."],
	],
	"sundown": [
		["The wall's older than my grandma's grandma.", "It's kept out sandstorms, bandits and one very determined goat."],
		["Every evening the watch rings the gate bell, and the whole town climbs onto the roofs to see the sun go down."],
		["Mud, straw and sunshine. That's all a house needs.", "Well. And a door. Doors are nice."],
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

## Gravenmoor's weather and occupation, noticed by the people living in it.
const GRAVENMOOR_FOG := [
	["When did this fog roll into town? I've had the lamps lit since breakfast.", "If you're looking for Old Mort, he's over in the graveyard. He never seems to mind it."],
	["I can barely see the next lamp. I'm following their glow all the way home."],
	["I thought that shape in the fog was my neighbour. Then it floated through the fence.", "Old Mort knows what to do with ghosts. I'd ask him before going out on the moor."],
	["I used to hear the Beast Center's bell from here. Now I listen for Legion boots before I open my door."],
]
const GRAVENMOOR_PEACE := [
	["Still can't see the next lamp, but at least I can walk home without worrying about the Legion."],
	["That ghost's back at my fence. I think it likes the lamplight.", "I'll ask Old Mort what to feed it."],
]

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

## Permanent residents behind the red exterior doors, keyed by saved building
## identity so revisiting or rearranging a town never changes who answers.
const DOOR_VOICES := {
	"caccoon#4": ["Shh! I'm teaching a crab to knock. It keeps applauding itself."],
	"tidewater#7": ["I'm baking a cake shaped like the ferry!", "It won't fit through the door. Neither will the captain."],
	"shellhaven#5": ["I ordered a sea view, but the sea keeps looking back. I'm closing the curtains!"],
	"dustwell#1": ["Can't open up! I'm sorting sand into indoor sand and outdoor sand."],
	"dustwell#6": ["My cactus needs a hug. I've made a terrible mistake."],
	"sundown#5": ["Quiet! I'm counting the beams in my ceiling. I lost my place at four hundred and twelve."],
	"sundown#10": ["I'm practising my dramatic entrance. Come back when I've learnt the exit."],
	"cogsworth#3": ["I built an automatic door opener!", "Unfortunately, it's on the other side of the door."],
	"cogsworth#6": ["My clockwork kettle learned to whistle. Now it wants a flute solo."],
	"vinehollow#6": ["I'm hiding from my houseplant. I promised it a bigger pot and it heard me."],
	"gravenmoor#0": ["The Umbral Legion is rehearsing its evil laugh!", "No, Trevor, that's a hiccup. From the top!"],
}

## Indoor red doors keep a reply tied to the room and its purpose, too. Puzzle
## stone doors use their existing inscriptions rather than these painted doors.
const ROOM_DOOR_VOICES := {
	"apothecary": "One moment! The soap says to lather, rinse, repeat. It never says when to stop!",
	"outfitter": "This hat fits perfectly! Now I just need a door that fits the hat.",
	"bookstore": "I'm alphabetising the dust jackets. The dust is refusing to cooperate.",
	"arena": "And the winner is... me! Sorry, still practising. Please clap through the door.",
	"cafe": "I ordered a small coffee. I'm waiting to become small enough to drink it.",
	"saloon": "I've shuffled so slowly I think these cards have learned patience.",
	"dojo": "These socks are training on their own. One just earned a black belt.",
	"museum": "The sign said don't feed the exhibits. Nobody said the exhibits couldn't feed ME!",
	"music_hall": "I'm warming up my voice. The mirror has asked for an encore.",
	"music_shop": "Three notes down! Only every other note in music left to learn.",
	"studio_a": "I'm singing a duet with the drain. It's got a lovely gurgle.",
	"studio_b": "My soup's too shy to simmer while anyone's watching.",
	"house_two": "I dropped my toast butter-side up. Nobody move! We're making history.",
	"house_up": "The radio said to turn up the beet. Now there's a vegetable on the table.",
	"house_up_hall": "I was going to get out of the bath, but my rubber duck called a meeting.",
	"uncle_home": "I polished the kettle with flute polish. Now it only boils in tune.",
	"home": "The biscuits are cooling! Stop knocking, you'll make them nervous.",
	"home_hall": "I'm teaching the dripping tap a rhythm. It's got excellent timing.",
	"electronics": "I'm fixing the hand dryer. It keeps applauding before I'm finished.",
	"hotel_lobby": "Room service! Wait... I'm in the kitchen. Why am I announcing myself?",
	"hotel_suite": "I'm folding the towels into beasts. One of them wants its own room.",
	"ceo_1": "This meeting could have been a note. The note could have been a nap.",
	"ceo_2": "I'm filing the files about filing. Please file your complaint under 'files'.",
	"ceo_3": "I labelled every spare cog. Now none of them will turn without a name badge.",
}
const STAFF_DOOR_VOICES := {
	"apothecary": "I'm counting remedies. Every time I sneeze, I have to start over!",
	"outfitter": "Staff only! Unless you're a coat hanger. We're terribly short of coat hangers.",
	"bookstore": "I'm repairing a book about glue. It's become rather attached to me.",
	"arena": "I'm polishing the trophies. My reflection just challenged me to a rematch.",
	"cafe": "I'm teaching the spoons to stir themselves. So far they've formed a band.",
	"dojo": "The training dummy is on its lunch break. It brought a wooden sandwich.",
	"museum": "I'm dating a fossil. Not like THAT! I'm finding out how old it is!",
	"music_hall": "The curtain's stuck. We're calling it a very long intermission.",
	"music_shop": "I'm tuning a triangle. It's a surprisingly complicated instrument.",
	"electronics": "The spare parts have gone missing. I suspect they're building something.",
	"saloon": "I'm cleaning the glasses. This one keeps saying it can see perfectly well!",
	"jail": "I'm checking the bars. One of them is a very convincing breadstick.",
	"skytower": "I'm ironing the windsock. The wind keeps putting the wrinkles back.",
	"cathedral": "I'm dusting the cobwebs. The spiders say it's their day off.",
}

## Fallback for new authored houses; the shipped red doors each have their own voice above.
const LOCKED_DOOR := [
	["Can't come to the door! I'm three notes into a sixteen-note Battle Hymn and my fingers are SWEATING."],
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
	"demo_dance": ["Lucille teaches rhythm attacks from trainer level 4 at Dustwell's DANCE studio. The road beyond town opens in the full game."],
	"demo_freeplay": ["You've learned rhythm attacks! Keep exploring and battling in the demo. Jasper's slippers and the road beyond Dustwell are in the full game."],
	"dance": ["Jasper won't leave Dustwell's north road without his shoes. Instructor Lucille has them at the DANCE studio, at the west end of Main Street. She teaches rhythm attacks from trainer level 4."],
	"dance_shoes": ["Lucille gave you Jasper's shoes? Take them to him by Dustwell's north road so you can reach Sunwall."],
	"egg": ["Elder Rowan's waiting in the plaza with a beast egg for you. She's been polishing it all morning. It's very shiny now.",
		"Big day, huh? Go and see Elder Rowan in the plaza. She's got something round and important for you.",
		"I'd hurry to the plaza if I were you. Last time Elder Rowan waited, she knitted a whole sweater. For a Pyrosaur."],
	"hatch": ["An egg! Nurse Clover at the Beast Center can hatch that for you. It's right across from the square: the little stone temple with the red paw print over the door.",
		"Eggs don't hatch in your pocket, you know! The Beast Center's the little stone temple by the square, with the paw-print sign.",
		"The Beast Center's cradle stone is warm and cosy. Your egg would love it. Just across the road from the statue: the little stone temple with the crystal on its roof."],
	"path": ["Heading down the Coastal Path? The trainers out there teach every newcomer how battling works. Listen to them!",
		"Scout Bram's stepped out of the east road for you. Follow the trail, and the trainers along it will show you the ropes.",
		"My first battles were on the Coastal Path. A camper taught me everything. Then a fisher taught me everything again, but slower.",
		"The footbridge on the Coastal Path washed out. Old Hal the builder lives in the log cabin by the creek. Ask him about it!"],
	"bridge": ["Old Hal's lending you his logs? They're stacked by his door. Lay them across the footbridge's old posts.",
		"Logs don't lay themselves! Take Hal's to the footbridge's posts by the creek.",
		"Once that footbridge on the Coastal Path is mended, Bellerive's just a stroll away."],
	"builder_egg": ["You mended the footbridge? Go and tell Old Hal! He's been talking about an egg he found after the storm.",
		"Hal the builder never forgets a favour. Pop into his cabin by the creek before you head on."],
	"flute": ["Bellerive's at the far end of the Coastal Path. Look for the golden flute sign on your uncle Rafe's house by the west entrance.",
		"I hear Rafe in Bellerive has been polishing a reed flute for years. Waiting for someone, maybe? Someone like you?",
		"Your uncle in Bellerive is keeping your father's flute. Go and get it!"],
	"rafe": ["Rafe's lessons are worth finishing. A trainer without songs is just a person with a pet.",
		"Go back and see your uncle. He's got songs to teach you. He hums them in the street. It's very distracting."],
	"arena": ["Bellerive's arena gives every new trainer battle lessons before they face Tide Captain Marina. Coach Rory and Coach Ondine wait just inside the door. You can't miss them. They won't let you.",
		"Want to sail to the Isle of Tides? Captain Gull only takes trainers with Marina's Wave Crest. Start with the arena's coaches!",
		"Coach Rory yells a lot, but he knows teamwork. Coach Ondine knows elements. Between them, Marina won't know what hit her."],
	"marina": ["Tide Captain Marina's waiting in the arena's ring. Her beasts are all water... and water hates air.",
		"Win Marina's Wave Crest and Captain Gull will happily sail you to the Isle of Tides.",
		"Marina's beasts are all water. Bring something airy. Or something with a lot of confidence."],
	"ferry": ["Captain Gull's ferry sails from Bellerive's long pier to the Isle of Tides. The islanders are having a terrible squabble, I hear.",
		"The Isle of Tides! Take the ferry from the pier. Bring a sweater. And a referee: Shellhaven and Kelpwick are at each other's throats.",
		"Tried your flute on a wild beast yet? Weaken it, beat it, and it might leave you an egg. Then catch the ferry from the pier. The island's waiting."],
	"chiefs": ["The resort folk only tell one side. Chief Coralie in Kelpwick, east along the Isle Trail, tells the other.",
		"Kelpwick walled off the reef, and Shellhaven's furious about it. Go and hear Chief Coralie out, along the Isle Trail."],
	"warden": ["Kelpwick's villagers only let real trainers through to the reef. Beat Reef Warden Nerissa in the great hut and they'll know you're no tourist.",
		"Nerissa's beasts are all water, and water is weak to air. The great hut has a machine to restore your beasts, too."],
	"temple": ["The reef path past Kelpwick is open! The Temple of Tides is out across the reef. Its guardian keeps the sea, and some say the desert winds, all riled up.",
		"Calm the Temple of Tides and the sandstorms on the Dune Road might settle. That's what my aunt says. She's usually right about weather.",
		"Past Kelpwick and over the reef stands the Temple of Tides. Bring waterproof courage."],
	"desert": ["The Dune Road north of Bellerive is open again! Dustwell Oasis is lovely. Sunwall beyond it is... more walls than lovely. And bandits.",
		"The sandstorms have settled! Head north from Bellerive into the desert. I hear the captain of Sunwall's watch could use a hand."],
	"bandits": ["The Jackals hole up in a hideout near Sunwall. Somebody ought to give them what for.",
		"Captain Dalton's watch can't chase the Jackals across the dunes alone. You look like you could."],
	"winds": ["With the Jackals gone, the Dune Sea road is open. They say the Temple of Winds stands out in those dunes.",
		"North of Sunwall, over the Dune Sea, lies Copperpick. And somewhere in the dunes, the Temple of Winds."],
	"mine": ["The Mine Road out of Copperpick is closed without a Miner's Pass. Foreman Gorran signs them if you beat him at the Copperpick Arena.",
		"Want to reach Cogsworth? You'll need a Miner's Pass. Copperpick's arena is where you earn one."],
	"gearhart": ["Gearhart's robots are taking trainers. Climb his tower in Cogsworth and find the freight cages.",
		"Gearhart Tower is crawling with robot sentries. Beat every one on a floor and the stairs open up."],
	"rescue": ["Gearhart's defeated, but the trainers still need you! Use the Freight Lock Control on his tower's top floor.",
		"The top-floor console opens the freight cages with Gearhart's command seal. Don't leave those trainers behind!"],
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
	"vexmora": ["General Vexmora waits in the crypt beneath the cathedral. This is it. Go and get him!",
		"The Legion's general is down in the crypt. Everyone's counting on you. No pressure!"],
	"done": ["You saved us all! Now, about that sweater I knitted you...",
		"The whole land's talking about you. Mostly good things. One bad thing, about your hat."],
}

## What Mom passes on when you call her from a phone away from home (phone.gd call_mom), by Story.next_goal(): one tip
## a call, taking turns. Each is something she saw on the TV news, something Grandma wants you to know, or a call from
## someone who saw you do something you've already done, with advice for the road ahead. Each tip is its lines.
const MOM_TIPS := {
	"demo_dance": [["Grandma says Lucille teaches rhythm attacks from trainer level 4 at Dustwell's DANCE studio. You can learn them in the demo!"],
		["Dustwell's DANCE studio is at the west end of Main Street. Trainer battles and arena ranks help you reach level 4."]],
	"demo_freeplay": [["You've learned rhythm attacks! Keep exploring and training, sweetie. Jasper's slippers and the road beyond Dustwell are in the full game."],
		["There's still time to train your beasts, try the arenas or explore the roads you've visited. Enjoy your rhythm attacks!"]],
	"dance": [["Grandma wants you to know that Instructor Lucille teaches rhythm attacks at Dustwell's dance studio. Reach trainer level 4, then show her you can keep a beat to get Jasper's shoes back."],
		["I saw Dustwell's dance studio on the TV news. It's at the west end of Main Street, under the DANCE sign."],
		["Grandma says Lucille only teaches trainers of level 4 or more. Trainer battles and arena ranks will get you there."]],
	"dance_shoes": [["Grandma wants you to know that Jasper is still waiting by Dustwell's north road. Return his dance shoes and he'll let you through."],
		["Grandma says borrowed shoes should always go back to their owner. Jasper's by the road to Sunwall."],
		["Grandma wants to know if Jasper's got his shoes yet. Take them to Dustwell's north road before you head on."]],
	"egg": [["I was watching TV, and the news said trainer season starts today! Elder Rowan's giving out eggs in the plaza. That's you, sweetie. Go and see her!"],
		["Grandma wants you to know that every egg is different. Fire beasts hit hard, water beasts heal, earth beasts protect and air beasts play tricks.", "Pick the one that feels like you."],
		["Scout Bram called me. He said he saw you set off from home this morning, all grown up!", "He wanted you to know that if you ever want to get past him on the east road, you'll need a beast of your own. Elder Rowan has an egg for you."]],
	"hatch": [["Grandma wants you to know that eggs don't hatch in a pocket. Nurse Clover keeps an incubator beside her counter at the Beast Center.", "That's the little stone temple with the paw print over the door."],
		["Elder Rowan called me. She said she saw you choose your egg, and she's ever so proud!", "She wanted you to know that if your beasts ever need healing, the font at any Beast Center is free. Or come home to me!"],
		["I was watching TV, and the news said Scout Bram won't let anyone onto the Coastal Path without a beast of their own. So hatch that egg first, sweetie."]],
	"path": [["I was watching TV, and the news said the trainers on the Coastal Path give every new trainer a lesson.", "You can't lose a lesson, so just listen and do what they say."],
		["Nurse Clover called me. She said she saw you hatch your very first beast!", "She wanted you to know that if your beasts are ever worn out, the healing font at the Beast Center is free, any time."],
		["Grandma wants you to know that a storm washed out the footbridge on the Coastal Path. Old Hal the builder lives in the log cabin by the creek.", "She says he's grumpy, but ask him nicely."]],
	"bridge": [["Old Hal called me. He said he liked the look of you when you came by his cabin.", "He wanted you to know that if you ever need logs, they're stacked by his door. Lay them across the footbridge's old posts."],
		["I was watching TV, and the news said the footbridge on the Coastal Path is the only way through to Bellerive. Lay Hal's logs across its old posts and you're away!"],
		["Grandma wants you to know: always leave a road better than you found it. Mend that footbridge, sweetie."]],
	"builder_egg": [["Old Hal called me. He said he saw you mend his footbridge, good as new!", "He wanted you to know that if you're ever passing, pop back into his cabin. He's got something round for you."],
		["Grandma wants you to know that a good deed always comes back to you. Go and see Old Hal before you head on."],
		["I was watching TV, and the news said the footbridge on the Coastal Path is open again! The builder's looking for whoever mended it."]],
	"flute": [["I was watching TV, and the news said Bellerive's at the far end of the Coastal Path. Your uncle Rafe's house is the one with the golden flute sign over the door."],
		["Picnicker Mae called me. Mae saw you pass every lesson on the Coastal Path!", "Mae wanted you to know that if you ever get lost in Bellerive, Neighbor Nell by the west entrance knows where everyone lives."],
		["Grandma wants you to know that your father's flute is waiting with Uncle Rafe in Bellerive. She says Rafe was always the patient one. Mostly."]],
	"rafe": [["Grandma wants you to know: finish Rafe's lesson. Play Weaken on a wild beast, then beat it. Sometimes they leave an egg behind."],
		["Neighbor Nell called me! Nell saw you go into Rafe's house.", "Nell wanted you to know that if you ever need to brush up on a song, you can practise it on the Flute page of your Start book."],
		["I was watching TV, and the news said wild beasts are out on the roads again now trainer season's here.", "Creep up on one from behind and you'll catch it napping!"]],
	"arena": [["I was watching TV, and the news said Bellerive's arena gives every new trainer lessons before they can face Tide Captain Marina.", "Coach Rory and Coach Ondine are just inside the door."],
		["Uncle Rafe called me. He said he heard you play Weaken like you were born to it!", "He wanted you to know that if you ever want more eggs, there's a park full of wild beasts on the way to the arena."],
		["Grandma wants you to know that fire is weak to air, air to fire, water to air, and earth to water. She's written it on a tea towel for you."]],
	"marina": [["I was watching TV, and the news said Tide Captain Marina's beasts are water beasts, and water is weak to air. Put an air beast on the side facing her!"],
		["Uncle Rafe called me. He said that little Codex of yours never stops talking!", "He wanted you to know that if you ever need to protect yourself, keep the middle beast of the side facing the foe standing. If it falls, the other trainer can hit you."],
		["Grandma wants you to know that Marina's beasts are tougher than anything on the Coastal Path.", "Win some battles in Bellerive's park first, and take plenty of potions."]],
	"ferry": [["I was watching TV, and the news said Captain Gull's ferry sails from Bellerive's long pier to the Isle of Tides. Show him your Wave Crest."],
		["Tide Captain Marina called me! She said she saw you win her Wave Crest.", "She wanted you to know that if you ever need to get somewhere quickly, the great bird on Bellerive's Sky Tower flies you to any town you've visited."],
		["Grandma wants you to know that the two villages on the Isle of Tides are squabbling. Hear both sides before you pick one."]],
	"chiefs": [["Grandma wants you to know that a feud always has two sides. Chief Marlo's in Shellhaven and Chief Coralie's in Kelpwick, along the Isle Trail."],
		["I was watching TV, and the news said thorny brambles have grown across the Isle Trail. A fire beast can burn them, or an air beast can slice them down."],
		["Captain Gull called me. He said he saw you sail over without turning green once!", "He wanted you to know that if you ever take up fishing, you can buy Wriggly Worms on the islands. They bring the bigger water beasts."]],
	"warden": [["I was watching TV, and the news said Kelpwick has sealed off the Temple of Tides because tourists keep pocketing bits of it. Shameful!"],
		["Grandma wants you to know that Reef Warden Nerissa's beasts are water beasts, and water is weak to air."],
		["Chief Coralie called me. Coralie saw you listen to both sides, like a proper grown-up.", "Coralie wanted you to know that the great hut has a machine to restore your beasts, so heal up before you face Nerissa."]],
	"temple": [["I was watching TV, and the news said Kelpwick has opened the reef path at last. The Temple of Tides is out across the reef."],
		["Grandma wants you to know that a temple's guardian can't be beaten, only captured.", "The stones inside teach you its song: wear the guardian down, then play it."],
		["Chief Coralie called me! Coralie heard you beat Nerissa fair and square.", "Coralie wanted you to know that if you ever want more beasts, wild ones sometimes leave an egg behind after a battle. Any Beast Center can hatch it."]],
	"desert": [["I was watching TV, and the news said the sandstorms on the Dune Road have died down. It runs north from Bellerive to Dustwell Oasis."],
		["Grandma wants you to know that there's a cliff on the Dune Road with a rope ladder coiled at the top. A beast with wings can fly up and drop it down for you.",
			"And on the Mesa Trail, push the boulders until a path opens. If you get stuck, walk away and come back, and they'll be where they started."],
		["Uncle Rafe called me. He said he heard you captured the guardian of the Temple of Tides!", "He wanted you to know that if you ever need help in a tough battle, play the temple's song and the guardian will come. It costs a shield point."]],
	"bandits": [["I was watching TV, and the news said the Jackal gang is holed up in a hideout near Sunwall. The captain of the watch is asking for help."],
		["Captain Dalton in Sunwall called me. He saw you walk through the gate like a real hero,", "and wanted you to know that if you ever need potions for the Jackals, Sunwall's apothecary has plenty."],
		["Grandma wants you to know that bandits fight dirty. Heal your beasts before you go into that hideout, and bring your strongest team."]],
	"winds": [["I was watching TV, and the news said the road across the Dune Sea is open now the Jackals are gone. The Temple of Winds stands out in those dunes."],
		["Grandma wants you to know that air beasts are weak to fire. Take a fire beast into the Temple of Winds."],
		["Captain Dalton in Sunwall called me! He saw you send the Jackals packing,", "and wanted you to know that if you ever want more beasts in your ring, Volt at Sparkwire Electronics in Bellerive wires up more beast slots for crystal shards."]],
	"mine": [["I was watching TV, and the news said the Mine Road out of Copperpick is closed to anyone without a Miner's Pass.", "Foreman Gorran signs them, but only for trainers who beat him in his arena."],
		["Grandma wants you to know that Foreman Gorran brings earth and fire beasts. Water beats earth and air beats fire, so take a bit of both."],
		["Uncle Rafe called me. He said he heard you captured the guardian of the Temple of Winds!", "He wanted you to know that if you ever want new songs, flute trainers will teach you theirs: beat them, then play the song back without a single mistake."]],
	"gearhart": [["I was watching TV, and the news said trainers have been going missing, and folk in Cogsworth blame the robots at Gearhart Tower."],
		["Grandma wants you to know that in Gearhart Tower, the stairs only open once every robot sentry on that floor is beaten."],
		["Foreman Gorran called me. He said he saw you win your Miner's Pass fair and square!", "He wanted you to know that if you ever need a stronger beast, Kennel Keeper Pip's barns out on the roads have beasts other trainers left behind, waiting for a home."]],
	"rescue": [["I was watching TV, and the news said Gearhart's been beaten! But the missing trainers are still locked in his freight cages."],
		["Grandma wants you to know that the Freight Lock Control is on the top floor of Gearhart's tower. His command seal opens the cages."],
		["A lady from Cogsworth called me. She said she saw you beat Gearhart!", "She wanted you to know that if you ever need more shield points, Volt at Sparkwire Electronics in Bellerive sells them for crystal shards."]],
	"flame": [["I was watching TV, and the news said the Caldera Road's open now Gearhart's beaten. There's a stream of lava across it, but a water beast can cool it."],
		["Grandma wants you to know that fire beasts are weak to air. Take an air beast into the Temple of Flame."],
		["One of the trainers you freed called me! They saw you open the freight cages.", "They wanted you to know that if you ever need MP back in a hurry, apothecaries sell Spirit Drops, and cafés make Mint Tea."]],
	"jungle": [["I was watching TV, and the news said Vinehollow, over the Summit Pass, sells the finest gear in the land. And their shaman's looking for a capable trainer."],
		["Grandma wants you to know that on the Summit Pass, the ice blocks slide until they hit something. Think before you push!"],
		["A hiker on the Caldera Road called me. He said he saw you come out of the Temple of Flame with its guardian!", "He wanted you to know that once you have an air beast of Lv 40, you can fly from anywhere outdoors. Just pick a town on the Map in your Start book."]],
	"relics": [["Grandma wants you to know that the Sun Relic is hidden in Vinehollow itself, the Moon Relic is on the Summit Pass, and the Earth Relic is on the Jungle Trail."],
		["I was watching TV, and the news said the ritual in Vinehollow needs all three relics on the old shrine. Then something big is meant to happen!"],
		["Shaman Ayo called me. She said she saw you take on her quest without blinking.", "She wanted you to know that if you ever lose track, she'll tell you which relics are still out there."]],
	"roots": [["I was watching TV, and the news said a temple rose right out of the ground on the Jungle Trail! It was on the evening news."],
		["Grandma wants you to know that earth beasts are weak to water. Take a water beast into the Temple of Roots."],
		["Shaman Ayo called me! She said she saw you finish the ritual.", "She wanted you to know that if you ever need a beast to grow past its level limit, merge two final-form beasts at their limit on a Beast Center's altar."]],
	"gravenmoor": [["I was watching TV, and the news said a fog bank has rolled over the Moor Road. An air beast can blow it away."],
		["Grandma wants you to know that ghosts have no weakness. Old Mort the gravedigger in Gravenmoor knows a song that soothes them."],
		["A lady in Riverbend called me. She said she saw you come out of the Temple of Roots with its guardian!", "She wanted you to know that if you ever face Commander Nyx, bring strong, merged beasts."]],
	"vexmora": [["I was watching TV, and the news said Commander Nyx has fallen! General Vexmora's hiding in the crypt beneath the cathedral."],
		["Grandma wants you to know that the crypt has a guardian too, a ghost called Nocthrax. The crypt's stones teach its song, just like the temples."],
		["Old Mort called me. Mort saw you beat Commander Nyx!", "Mort wanted you to know that if you ever beat a ghost, it may leave a Shadow Egg, and Nurse Clover can hatch it."]],
	"done": [["I was watching TV, and you were on the news! The whole land's talking about you, sweetie."],
		["Grandma wants you to know she's knitting you a sweater with your face on it. Act surprised."],
		["The receptionist at Bellerive's arena called me. She said she saw you on the news!", "She wanted you to know that if you ever want a challenge, every arena's ladder has ten ranks of trainers to beat."]],
}

## Where your next battles are, by Story.next_goal(), for what Mom makes of your beasts' levels when there are no wild
## beasts where you are (phone.gd level_advice): a road (WorldDB.ROUTES), an arena master (WorldDB.ARENAS, by town) or
## a room with wild beasts (InteriorMaps.ROOMS). Nothing before the flute: the Coastal Path has only its teachers.
const MOM_AHEAD := {
	"demo_dance": "route3", "demo_freeplay": "route3",
	"rafe": "route1", "arena": "tidewater", "marina": "tidewater", "ferry": "route2", "chiefs": "route2", "warden": "kelpwick",
	"temple": "reef", "desert": "route3", "dance": "route3", "dance_shoes": "route4", "bandits": "route4", "winds": "route5", "mine": "copperpick",
	"gearhart": "route6", "rescue": "route6", "flame": "route7", "jungle": "route8", "relics": "route9", "roots": "route9",
	"gravenmoor": "route10", "vexmora": "crypt_1",
}


static func pick(list: Array, rng: RandomNumberGenerator) -> Variant:
	return list[rng.randi_range(0, list.size() - 1)]


static func fill(lines: Array, player: String) -> Array:
	var out := []
	for l in lines:
		out.append(String(l).replace("{player}", player))
	return out
