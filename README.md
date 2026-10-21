# Ruby Cocoon

A voxel beast-training RPG for **Godot 4.7**. You hatch your first beast from an egg, battle to make it stronger as it grows into its second and third forms, charm wild beasts with your flute, merge grown beasts into new ones built from both, and stop the Umbral Legion and their ghost beasts.

## Running it

Open `D:\Games\RubyCaccoon\project.godot` in Godot 4.7 and press **F5**. You can also run it from a terminal:

```
"C:\Program Files\Godot\Godot_v4.7-stable_win64.exe" --path D:\Games\RubyCaccoon
```

## Controls

| Action | Keyboard | Gamepad | Touch (phones and tablets) |
|---|---|---|---|
| Move (one of the four ways, a whole tile at a time) | Arrow keys (with two held, you keep going the way you were walking, else the newest one counts) | D-pad or left stick (the way it's pushed further) | D-pad, bottom left (one arrow at a time) |
| Action: talk, confirm, use a beast on an obstacle | A (or Enter) | A | A, bottom right |
| Back; hold to run | S (or Esc) | B | B, bottom right |
| Start: the travel book menu | Space | Start | START, bottom centre |
| Pause | Shift | Back / Select | PAUSE, bottom centre |
| Flute notes (Esc / Pause stops a song) | ← → A S, then ↑ ↓ | ← → A B, then ↑ ↓ | ← → A B, then ↑ ↓ |
| Walk somewhere / run there / use something | Click / double-click / click it | | Tap / double-tap / tap it |

On desktop, a key guide slides up along the bottom of the screen while the Start book is open, and hides again
during play. On phones and tablets the on-screen buttons take its place. You can switch either off in **Start → Settings**.

Tap (or click) anywhere in the world to walk there; double-tap to run. Tap a person, a door, a sign, an item or a
wild beast to walk up to it and use it; if you're already next to it, you use it straight away.

## The journey

You start at home in **Cocoon Cove** on the coast with no beasts, no flute and no songs.
1. Mom tells you that your father's flute is waiting with **Uncle Rafe** in Tidewater, the next town east.
2. Elder Rowan lets you choose one of four elemental eggs.
3. The Beast Center hatches it into a **level 1** beast.
4. Scout Bram keeps the gate to the Coastal Path shut until you have a beast of your own.
5. The **Coastal Path** is the tutorial: a winding trail through the woods with five teachers on it (`world_db.gd`
   LESSON_TRAINERS, battle.gd LESSONS). Each looks straight across the trail where you can't slip past, so you always
   walk into their line of sight and they come over and stop you; you never need to talk to them first. Youngster Kit
   watches the trail where it reaches the creek. Each gives a guided battle, and so do the arena's coaches and
   the flute lesson (`battle.gd` LESSONS): every bar and every menu has just the one thing to pick, the one being
   taught (◄ ► stay put, and the teacher says what to do), the target and the beast to heal are chosen for you, and
   you can't lose: your beasts are healed first and always keep at least 1 HP, and nobody can run, forfeit or hit
   you. Your beast grows a level or so. Camper Tilly: the battle screen and
   fighting. Fisher Dale: turns, speed and Defend. Youngster Kit, on the trail by the creek: your own turn (slingshot, Watch, Run and Forfeit).
   Picnicker Mae: items (she gives you three Minor Potions). Ranger Holt: the ring, its middle beast, shields and
   striking an open trainer. Until you have a flute there are no wild beasts on the path, only its teachers.
6. Mend the washed-out footbridge on the Coastal Path to reach Tidewater (the sign only says there's a footbridge ahead
   and a builder's cabin by the creek). Old Hal the builder, in the cabin just west of it, is too tired to rebuild it
   himself: once you've talked to him you can take the logs stacked by his door and lay them across the creek. Go back
   in and he gives you a beast egg (a Seashelly) to hatch at Tidewater's Beast Center. Mended, it's a plank footbridge
   with railings.
7. Uncle Rafe gives you the flute and teaches **Weaken** (walking you through the sheet music step by step) and **Capture I**. His lessons give you 30 seconds per song.
8. The first lone wild beast you meet after that is a guided battle too: Rafe's advice walks you through playing Weaken on it, then Capture (it always joins if you play the song through).
9. Arenas only take trainers with a flute.
10. Tidewater's arena teaches you to battle properly before you may face its master (`world_db.gd` ARENA_LESSONS,
    battle.gd LESSONS "team" and "elements"). Both coaches stand just inside the door and see you as you walk in.
    **Coach Rory** stops you first and shows you fighting with a whole side of your ring (the arena's practice beasts
    fill your empty slots for the lesson). Then **Coach Ondine**, who doesn't notice you until you've had Rory's
    lesson, steps in with elemental weaknesses: her beast is weak to the element of the side facing it (with your earth
    side facing, you borrow the arena's air practice team, since nothing is weak to earth). Only then can you challenge
    **Tide Captain Marina**, and Captain Gull's ferry to the Isle of Tides only takes trainers with her Wave Crest.
11. The journey runs in one line: the Dune Road north of Tidewater stays shut by sandstorms until you've beaten the guardian of the Temple of Tides on the Isle of Tides.

Townsfolk and residents add a casual hint about what to do next to whatever else they say (`chatter_db.gd` HINTS, by
`Story.next_goal()`), so what they talk about moves on as soon as you've done it.

| Region | Towns | What happens |
|---|---|---|
| Coast | Cocoon Cove, Tidewater | Tidewater has the first arena (its coaches' lessons, then Tide Captain Marina, whose Wave Crest the ferry asks for), **Sparkwire Electronics** (shield points and beast slots), a Sky Tower and the ferry. |
| Isle of Tides | Shellhaven, Kelpwick | The two villages are feuding. Hear both chiefs, catch the smuggler on the Isle Trail who framed them, and they open the coral gate to the reef and the **Temple of Tides**. |
| Desert | Dustwell Oasis, Sundown Gulch (western town) | Bandits terrorise Sundown. Talk to the Sheriff, then beat Black Bart in the hideout to open the Dune Sea road. The **Temple of Winds** lies in the Dune Sea. |
| Mountains | Copperpick, Cogsworth (steampunk city) | CEO Magnus Gearhart is holding Cogsworth hostage and has sealed the road to the volcano. Fight up Gearhart Tower: each floor's robot sentries must fall before the stairs unlock. |
| Volcano | Emberfall | The **Temple of Flame** sits on the Caldera Road. |
| Jungle | Vinehollow | The village sells the finest gear in the land. The shaman needs the Sun, Moon and Earth relics; the ritual raises the hidden **Temple of Roots**. |
| River and moor | Riverbend, Gravenmoor | Gravenmoor is the Legion's town. Ghost beasts can be hatched and merged from here on. The gravedigger teaches the Requiem of Dusk. Commander Nyx guards the cathedral, and General Vexmora waits in the crypt beneath it. |

Every road between towns narrows to one bottleneck with a puzzle, getting harder as you go:

| Road | Puzzle |
|---|---|
| Coastal Path | A washed-out footbridge. Old Hal the builder, in the cabin beside it, lends you the logs stacked by his door; lay them across the creek, then he gives you an egg. |
| Isle Trail | Thorny brambles. A fire beast burns them; an air beast slices them down. |
| Dune Road | A sheer cliff with a rope ladder coiled at the top. A beast with wings flies up and drops it. |
| Mesa Trail | A rockslide: push the boulders around until a path opens. |
| Dune Sea | Black Bart's barricade. Beat the bandit gang in their hideout. |
| Mine Road | The mine checkpoint. Foreman Gorran signs a Miner's Pass when you beat him at the Copperpick Arena. |
| Caldera Road | Gearhart's steam gate, then a stream of lava that a water beast cools. |
| Summit Pass | A frozen pond of ice blocks that slide until they hit something. |
| Jungle Trail | The Jungle Warden blocks the crossing until you beat him. |
| Moor Road | A fog bank that an air beast blows away, then a Legion sentinel to defeat. |

Leave a push puzzle and come back to reset it; once solved, the blocks stay where you left them. Smaller elemental
obstacles (driftwood, sand drifts, boulders, dust storms, ravines) still turn up off the main road.

## Systems

- **Fishing** (`scripts/world/fishing.gd`, `scripts/ui/fishing_game.gd`). Fisher Gil fishes off the deck of his rusty
  tin shack on Tidewater's docks. Talk to him and he offers his spare pole, leaning in the shack (take it before asking
  and you're told stealing is bad). Come back out with it and he stops you for a first cast: something always bites,
  the line is gentler, and he has you try again until you land it. After that, face any water and press A to cast.
  Where the water ripples (each map's `fish_spots`, plus a few picked along its shores) something nearly always bites,
  and quickly; anywhere else only now and then. When the float dips, tap A to strike, then reel: each tap pulls the
  line tighter and it slackens on its own; tap it up into the bright zone and keep it there with steady taps until the
  catch meter fills. Too fast and the line snaps, too slow and the beast slips off. Land it and it leaps out for a
  wild battle on a plank dock with the beast out on the water (`battle.gd` _fishing_scenery). Bait (put on your hook
  from the bag, worn until something bites) brings stronger, rarer water beasts, sooner: Wriggly Worms on the islands
  (Shellhaven, Kelpwick), a Spinner Lure from Copperpick, Cogsworth and Emberfall, a Glow Lure from Riverbend and
  Gravenmoor. Captain Gull's ferry is moored by the long pier, and Gil's rowboat by his shack (map `boats`).

- **13 beast lines** of three forms each (`race_db.gd` LINES): Fire has the spiky dino (Embit, Cinderex, Pyrosaur),
  the cactus (Pricklet, Spinesear, Saguaroar) and the pink imp (Impkin, Scampyre, Infernook); Earth the beetle
  (Grubbit, Shellhorn, Rhinoclad), the armoured boar (Tuskit, Bristlehog, Crystusk) and the tree (Saplet, Barkbrute,
  Elderoot); Water the crab (Clawlet, Snapshell, Crustacor) and the frog (Tadlet, Croakus, Toadmiral); Air the owl
  (Hootlet, Gustowl, Tempestrix), the bat (Flittle, Duskwing, Nocturna) and the berries (Berrypuff, Bramblume,
  Galeberry). Two lines are of two elements: the scorpion (Nipskit, Scorchpin, Calderak) is Fire and Earth, and the
  worm that is an eel in the sea (Wrigglet, Mudwhip, Abyssel) Earth and Water. The weaknesses are: Fire to Air, Earth
  to Water, Water to Air, and Air to Fire.
- **Growing up**: a beast hatches as its line's first form and grows into the second at **Lv 20** and the third at
  **Lv 40** (`RaceDB.EVOLVE`, `Beast.evolve`): bigger, stronger, with the new form's name (unless it has a name of its
  own). It keeps its moves, and a line learns the same moves at every form. Wild and trainers' beasts are whatever form
  their level gives.
- **Element roles**: Fire are offensive tanks, Water are healers, Earth are defenders, and Air handle status and evasion.
- **Eggs**:
  - A defeated wild beast has a **20%** chance to leave an egg at the end of the battle.
  - Trainers' beasts, robots and guardians never drop eggs.
  - Beast Centers hatch eggs into level 1 beasts, the first form of the egg's line.
  - Ghost beasts drop Shadow Eggs only after you reach Gravenmoor.
- **Temple guardians**: each elemental temple holds a legendary guardian: Abyssion, Zephyrax, Pyroclast and Terranox. Beating it gives a **Radiant Egg** of that element.
- **Merging** happens at Beast Centers, between two beasts grown into their final form and at their level limit: **Lv
  40** at rank 1, and each merge raises the limit by 20 (`Beast.level_cap`). A normal merge is 50/50. The new beast is
  put together from both parents' models (`beast_parts.gd`): one gives its frame, the other some of its parts (its
  head, arms, wings, tail or legs, each set where the frame's own were), and it is painted in one parent's colours. A
  legendary parent dominates at **80/20** and keeps its race. Ghost merging unlocks in Gravenmoor.
- **Ghost beasts** aren't beasts of their own: they're the same beasts in black and purple, glowing faintly and
  wrapped in smoke.
  - Beasts of neighbouring elements on the ring (Fire–Air, Air–Water, Water–Earth, Earth–Fire) merge into a **dual beast** of both elements. Opposite elements (Fire–Water, Air–Earth) can't merge.
- **Everyone moves one of the four ways** on the tile grid, a whole tile at a time: you, strolling townsfolk and wild
  beasts. A step, once started, always ends in the middle of the next tile (whatever you let go of or press on the
  way), so you always stop lined up with people, doors and items. With two arrows held you keep walking the way you
  were going, else the newest arrow counts (`world.gd` _key_dir).
- **Town mascots and their signature moves**: every town has a mascot beast roaming its square and a statue of it
  beside, cast in bronze (the coast and the isles), silver (desert to mountains) or gold (the far towns). The mascot
  teaches a beast of its own line, once it reaches **Lv 40**, the town's signature move: an elemental attack mightier
  than any move of its element learnt by levelling (`world_db.gd` TOWNS "signature", `move_db.gd` SIGNATURE, e.g. the
  Pyrosaur's Bandit Blaze in Cocoon Cove; the frogs' Toadmiral is the mascot of both Tidewater and Riverbend, and
  teaches each town's own move). Nobody else teaches it, and a merge keeps it only for a beast of that line. The statue's plaque explains it, and townsfolk bring it up now and then (`chatter_db.gd` MASCOT_MOVE).
- **Wild beasts** roam the routes in plain sight; there are no random encounters (the tall grass is still there).
  - Each beast sees in a cone in front of it, half as far if you're in tall grass, and hears you running nearby.
  - Beasts come running when they spot you. Only a lone beast hopelessly outmatched by your best one (8+ levels below it) bolts.
  - Marks: a yellow **!** when one spots you, a blue **!** when it's scared and fleeing, and **?** when it loses you. Nothing shows while it charges, or once it goes back to roaming.
  - Walk into one from behind before it spots you: a **sneak attack** (green spiral, it loses its first turn). Meet one face to face: a normal battle (blue spiral). Let one catch you from behind: an **ambush** (red spiral, you lose your first turn).
  - Groups grow slowly through the game (`Story.pack_cap`): beasts roam alone on the early roads (always on the Coastal Path), in pairs from wild Lv 7, and in threes only from Lv 16. Within that, a beast no stronger than your best one usually (70%) roams with more of its own kind, and the pack stands its ground; on roads with wild Lv 16+, stronger four-legged beasts, flyers and serpents sometimes run in packs too.
  - Each road's trainers are stronger than any wild beast on it. The early levels climb slowly: Coastal Path Lv 2-4, Isle Trail 4-7, Coral Reef 7-10, the Temple of Tides 8-11 (its guardian Lv 12, with one helper), Dune Road 10-13.
- **Levelling** is slower than before: about twice as many wins per level.
- **MP**: elemental attacks cost MP (about a tenth of their power, at least 2); regular (neutral) attacks and every other move are free, and a regular attack is always there when MP runs out. MP comes back only from healing (the Beast Center machine, Mom, your bed) and items: Spirit Drop (15), Spirit Tonic (40), Spirit Elixir (all) from apothecaries, and Mint Tea at cafés.
- **The battle ring** (as in Jade Cocoon 2, `scripts/core/ring.gd`): every trainer stands in the middle of a ring of 8 slots.
  - The ring has a side per element, in this order round it: **Fire, Air, Water, Earth**. A side's middle slot holds a beast of that element; the **corner** between two sides holds a beast of either element, or a dual beast of both.
  - You carry as many beasts as you have **beast slots** wired up: 3 to start, up to 8. New beasts take a free slot they may stand in, joining the side most of your team stands on.
  - **Arranging your beasts** (`ring_editor.gd`, **Start → Beasts → Battle ring & storage**, anywhere outside battle): your ring's eight slots round you, the side facing the foe at the top, and your storage as a grid beside it. Tap a beast (or move to it with the d-pad and press A) to pick it up: only the cells it may go to light up, the rest darken. A slot it can stand on, trading places with whoever is there if they can stand on its old one; a stored beast, swapping with it; or storage's empty cell. A stored beast only takes an empty slot while your ring has room, and one beast always stays with you (`GameState.ring_move_reason` has the rules). Tap it again (or B) to put it back down. Beast Centers' storage terminals still heal a beast you deposit; the book doesn't.
- **Battles** (`battle.gd`, `command_panel.gd`, `battle_bars.gd`, `ring_grid.gd`): one side of each ring faces the foe, and only its three beasts fight, using **that side's element** or plain (neutral) moves. A dual beast in a corner uses whichever of its elements faces the foe.
  - The camera looks over your shoulder: you stand at the bottom right, the foe at the top left. Every slot is an ornate hexagonal pad with a glowing sigil of its element(s); the side facing the foe glows brighter.
  - The HUD is kept to JC2's: the foe's ring as a slanted 3x3 grid at the top left (a wild pack: a line of three tiles), yours at the bottom right, and one line of battle text at the top. Each grid tile is a slot: a beast's icon (with a small HP bar) stands on it, a fainted beast's icon is crossed out, and empty slots are faded. The trainer stands on the middle tile; the foe's shield points are blue orbs under its grid.
  - Beside your grid are the **move bars**, one per beast on the side facing the foe, level with its row: its level, then the move it will use, with its HP and MP underneath. If the move costs MP, the part of the MP bar it would spend slowly flashes. Your own bar comes first, on its own: while you choose your action it stands level with your grid's centre cell (which glows), trimmed in gold, showing your trainer level and action; once you move on, the beasts' bars take its place. Your shield points are blue orbs under your grid.
  - Each round you choose your own action first, then each beast's move from the top: ◄ ► change it, A confirms, and then **every move aimed at someone has its target picked**, even with just one foe (◄ ► and A: a foe on the side facing you, or their trainer when that side's middle beast is down); a move that hits them all shows them all to confirm. A move isn't set until its target is, and the round only begins once every beast facing the foe is set. B goes back. One press of A is one confirm (on a phone, too). ▲ ▼ move between your beasts; **▲ on the top beast (or on your own bar, once your action is chosen) turns the ring (and the grid) anticlockwise, ▼ on the bottom one clockwise**, to the next side with a beast standing on it.
  - **The ring turns by itself** when a battle starts to a side with a beast standing in its middle (the side you last faced if it has one, else the nearest), and at the start of your turn when everyone on the side facing the foe is down. The bars, the grids and the battle text are drawn large (1.4x on desktops, 1.5x on phones). Phones (`--touch`): the bars and your grid stand centred just above START and PAUSE, clear of the d-pad and A and B; bars and the foe's tiles can be tapped.
  - **Choosing a target** (for every attack, the slingshot and items): a card for each target lines up at the top (`target_cards.gd`): its icon, name, level and element, and its HP (a trainer: their shield points), with ★ WEAK when the move hits its element hard. The one aimed at wears a bright, pulsing frame in the gem and the others dim; in the field a **glowing arc** in the gem runs from the beast choosing (or you) over to it, ending in an arrowhead with pulses running along it, a pulsing ring lies at its feet, a large arrow hangs over it, and the other beasts you could aim at darken. A move that hits them all frames every card, with an arc and a ring for each. ◄ ► (keys or d-pad) move along the cards, a tap on a card (or a foe's tile) aims at it (a second tap confirms), and A confirms.
  - **Move**: instead of its move, a beast on the side facing the foe can step over to another slot of the ring (choose the slot with ▲ ▼, as you would a target; its card says who's there). Any slot it can stand on that's empty, or holds a fainted beast (they trade places); the side it moves to then turns to face the foe. It may not leave the side facing the foe without a beast standing in its middle (so the beast guarding you stays put, but a corner beast can step into a fallen middle beast's place). One beast moves each round, last in your side's turn, so the others' moves land first. Foe trainers Move too: when the beast in the middle of the side facing you falls, one of that side's beasts steps into a slot that covers its trainer again, unless turning the ring to a side whose middle beast stands would keep more of their beasts fighting (`battle.gd` _ai_shift).
  - Then the two sides take their turns, the **faster side first**: the speed of its beasts facing the foe, helped by its trainer's level. Within a side's turn, the trainer acts first, then its beasts by priority and speed. You never see what the foe has chosen: it happens on its turn (a trainer may turn its ring then too).
  - Your actions: **slingshot**, **items** (potions, cures, revives, elemental bombs, sleep, poison, flash, nets, snares, weaken powder, haste, iron and war-drum tonics), a **flute song**, **Watch**, and **Run** (wild) or **Forfeit** (trainers). Each beast: a move, **Defend** (half damage until its side's next turn), or **Move** (to another slot).
  - Winning plays *Android Sock Hop*. A beaten foe vanishes in a puff of smoke; your own fainted beasts lie on their pads. Damage numbers use BoldPixels.
- **Shield and the end of a battle**:
  - If the beast in the middle of the side facing the foe is down (or that slot is empty), its trainer can be **attacked directly**: each hit breaks one shield point. Turn your ring to a side whose middle still stands to cover yourself, or have a corner beast Move into the fallen one's place.
  - A trainer battle ends only when a trainer is hit with no shield left, or someone forfeits. Wild beasts have no trainer: beat them all to win. If you're the one hit with no shield left, you wake up at the nearest Beast Center you've visited.
  - Every trainer starts with 1 shield point; trainers on the roads have 0 to 3, depending on their strength. The shield recharges after every battle.
- **Trainer level**: beating trainers earns trainer XP, and clearing a rank of the **arena ladder** raises your trainer level to at least that rank + 1. The ladder (`ladder_db.gd`) is the same at every arena: ten ranks of three or four ring trainers each; beat them all to open the next rank. Each rank cleared earns a crystal shard; beaten trainers can be fought again.
- **Sparkwire Electronics** (Volt, Tidewater): **shield points** (5 crystal shards each, up to 4) and **beast slots** (3 shards each, up to 8). How many Volt can fit depends on your trainer level: one more slot per level, one more shield point every other level.
- **Flute songs** are a sheet-music game.
  - The song plays once while its notes light up on the staff. Each line and space is a button: ← → A B from the bottom up.
  - Then the clock starts. Play the notes in order: the sheet stays up the whole time, with the notes you've played lit.
  - You have 10 seconds for four notes and 5 more for every four more (30 seconds in Uncle Rafe's lessons). The bar shrinks without numbers, going green, then yellow, orange and red. The colour you finish in sets the song's power: full in the green, about half in the red.
  - Each wrong note breaks one of three hearts and costs a little power. Lose all three, or run out of time, and the song fails.
  - Songs start at 4 notes and grow to 16 as they level up. Capture levels up through Capture I to XI; every other song levels up with mastery stars. Bigger songs add ↑, then ↓, and finally chords (A or B pressed together with a direction).
  - Uncle Rafe walks you through it step by step on the sheet the first time.
  - There are two kinds of song:
  - **Battle songs** work in any battle.
    - Some lift your team: Swift Jig, Battle Hymn, Iron Chorale, Mending Melody, Cleansing Canon, Mirage Minuet.
    - Others hinder the foe: Weaken, Sluggish Waltz, Dazzling Trill, Drowsy Lullaby, Venom Serenade, Static Polka, Discord, Dread March.
    - A great performance doubles stat changes and raises status odds. Mastery stars make songs stronger too.
  - **Capture** is the charm song, and it grows in levels.
    - Capture I charms wild beasts up to Lv 5. Later levels reach Lv 10, 15, 20, 25, 30, 40, 50, 60, 75 and 100.
    - It only works on beasts no stronger than your strongest beast. A **flawless** performance (no missed or wrong notes) can charm a stronger one.
    - The worse you play, the lower the chance.
    - When one of your beasts reaches the cap, you're told the next level is ready. You learn it by practising it on the Flute page of the Start book.
  - The **Requiem of Dusk** follows the same rules for ghost beasts.
  - Other trainers' beasts can't be charmed.
  - The **arena masters** teach strong combined battle songs, such as Tidewater Shanty (ATK and SPD up) and River Anthem (heal, cure, SPR up).
- **Learning songs**:
  - **Brass & Reed Music** in Cogsworth: Maestro Clef plays one song from his book for free, once. Play it back from memory to learn it. He also sells sheet music, which you can practise from your bag until you get it right.
  - **Flute trainers** play their own songs in battle: four route bards, three arena masters, Commander Nyx and General Vexmora. Win, then play the song back **without a single mistake** to learn it. Bards and arena masters will battle again for an encore.
- **Fast travel**:
  - Climb a **Sky Tower**: Skykeeper Aria's ticket desk is in the lobby, and the stairs lead up to an open-air platform on the roof, where the Tempestrix flies you to any town you've visited, for a fee.
  - Once you own an air beast of **Lv 40+**, pick *Fly* on the Trainer page of the Start book to travel from anywhere outdoors.
- **Beast Centers** all look the same: a 1950s roadside diner with the pawprint sign by the door. Each machine has its own bay along the back wall.
  - The **healing machine** is a giant soda can with a black glass window and a slot per beast. Use it yourself, any time, for free.
  - The **storage terminal** and the **merge altar** each have a bay of their own.
  - Nurse Clover at the counter hatches eggs in the **incubator** beside her (it sparkles when an egg hatches), and runs storage and the merge altar. Saving is done from the Start book.
  - Through the side door is the **kennel**. Kennel Keeper Pip looks after beasts other trainers left behind; they wait in the pens behind his counter, close to your party's level. Adopt one, or drop one of yours off for another trainer (Pip thanks you with a little gold). Tapping a pen walks you over to Pip. Empty pens fill up again after a few minutes of play.
  - Guide Dottie walks about the room by the entrance and explains how it all works.
  - All three wear the Beast Center uniform: a white polo with red collar and cuffs, a name badge and a diner paper hat (Pip adds a green apron).
- **Saving**: ten save slots.
  - A new game takes the first empty slot the first time you save; after that every save goes back into the same slot.
  - Each save keeps a snapshot of that moment (the world without the UI) and your play time, shown right after you save.
  - The title screen's **Load Game** lists the slots with their snapshots; you can load, copy or delete them there.
- **Shops** differ per town. Small towns have a few; cities have many. Each building has a wordless voxel sign fixed flat to its front above the door, showing what it is (houses have none).
  - Everyone who works in a shop stands behind a counter and wears their shop's uniform: a polo in the shop's colour with a contrasting collar and cuffs, short sleeves, a name badge and usually a visor (the sensei and the fortune teller wear headbands, the music hall's usher a pillbox hat).
- **Locked doors**: about a third of houses are locked, and so is Gravenmoor Cathedral until its Legion guard is beaten. Locked doors are crimson with iron straps and a brass padlock in every town. Try one and you knock (knock-knock-knock), and whoever is inside shouts something silly through it.

## Art: voxels

- **App icon**: the game's old voxel Redcoon, from before the 13 lines (with a cuter, icon-only face: big shiny eyes, a muzzle and pink ears) on a floating meadow island over a green valley. `python tools/make_icon.py` renders it with `tools/make_icon.gd` and writes Android's adaptive icon layers (background, foreground and a monochrome silhouette for themed icons) to `assets/icon/`, plus `icon.png` for the window.
- **World and props** come from the voxel packs in `voxelassets/`. They are converted to OBJ plus palette PNG by `tools/import_voxel_assets.py`, which uses `tools/vox2obj.py` for `.vox` files. The models are imported into `assets/voxel/` and listed in `scripts/data/voxel_manifest.gd`. To re-import:

  ```
  python tools/import_voxel_assets.py
  "C:\Program Files\Godot\Godot_v4.7-stable_win64.exe" --headless --path . --import
  ```

- **Beasts** are the 39 untextured models of the "new beasts" folder (three to a line), painted and animated in the
  game:
  - `python tools/new_beasts/bake.py "path/to/new beasts"` cuts each form out of its .obj (some files hold a whole
    line side by side), turns it to face +x standing on y = 0, scales it to one size, drops the stray triangles the
    source meshes carry between parts, and labels each face with a part of the body (body, head, arms, wings, legs,
    tail, horns, eyes; `tools/new_beasts/forms.json` holds each form's corrections) and each part with its joint.
    `--debug out_dir` draws every form with its parts coloured. Then
    `godot --headless --path . --script res://tools/import_new_beasts.gd` makes `assets/beasts/<form>.res`, skinned to
    one bone per part.
  - `beast_toon.gdshader` paints them flat and bright by part, as the creature packs they came from were painted: each
    part's colour, tips (hands, feet, claws, spikes), stripes and bands, a belly patch, and painted cartoon eyes;
    `scripts/data/beast_looks.gd` holds each line's colours. A ghost is the same beast in black and purple.
  - `beast_rig.gd` builds a beast on its skeleton and moves it by hand: a bouncy idle, walking (a trot on four legs,
    a waddle on two, a wriggle, a hop, flying), lying down, and attacking; ghosts trail smoke. `beast_parts.gd` puts
    merged beasts together from their parents' parts.
  - The four legendary guardians are still the PSX creature models (`assets/psx/beasts/`, recoloured by
    `voxel_beast.gd`).
- **Gearhart robots** (`RaceDB.ROBOTS`) are PSX robots: the Clockwork Sentry with a wind-up key, the boiler-bodied
  Steam Mecha and the broad Iron Golem from Bricchi Games' Retro Robots, and the boxy Tank Walker from CokeEnthusiast's
  Robot guy (`RaceDB.ROBOT_MODELS`). `tools/import_psx_robots.gd` bakes them into `assets/psx/robots/` (T-posed arms
  swung down, turned to face +x like the beasts, 1 unit tall) with their own textures and glowing eyes and vents; they
  are listed in `voxel_manifest.gd`, and `tools/make_beast_icons.gd` renders their menu icons too.
- **Houses and most shops** are houses from the PS1 House Pack (100 low-poly houses, `tools/import_psx_houses.gd` →
  `assets/psx/houses/`): `house_models.gd` picks one per plot from the town style's list (weatherboard cottages on the
  coast, round thatched huts and stilt houses on the islands, terracotta huts in the desert, log cabins in the
  mountains, dark timber at the hot springs, stone on the moor), re-skins it in the style's own tiles, fits it to the
  plot and lines its front door up with the map's door. A porch's deck or a stoop in front of the door is squashed down
  to one easy step at the door's sill (at most 0.25, `house_models.gd` steps(), MAX_STEP), its posts stretching to
  meet it, and people step up onto it. A house may lean over the hedges and trees beside and behind
  its plot (never over a walkable tile); those trees are left out. Shops, the dojo, museum and music hall add a
  striped awning and a sign board with their icon; houses get flower planters by the door; locked doors stay crimson.
  The Beast Center is a railcar diner with a curved steel roof and a sign on its roof.
- **Landmarks** are built from the wall sections of the Retro Modular House Pack (`assets/psx/exterior`: doors,
  windows and frames, laid round any outline by `HouseBuilder.span`), each with a shape of its own and its door on
  the map's door tile: the **arena** is an oval stadium (an arcade below, a parapet, open stands round a sand ring, a
  striped awning and pennants) behind a crenellated gatehouse between two turrets, in each region's stone;
  **Sparkwire Electronics** is a streamlined shop with a curved glass corner, a wrap-round canopy, a drum carrying a
  blade sign, a satellite dish and a radio mast; the **Sky Tower** is an eight-sided lookout in the town's finish,
  stepping in as it rises, with a gallery, a glazed lantern under a pointed roof and the Tempestrix on the rail.
  Gearhart Tower is stepped brick with a clock and a spire; Gravenmoor Cathedral a dark nave between two spired towers.
- **Inside**, walls between the camera and you fade rather than sink (`room_builder.gd` `fade`): in a cone opening from
  you towards the camera, a wall ahead of you is clear, about 70% opaque while you pass through its doorway, and solid
  once it's behind you. Walls right beside you stay solid; doors, windows and pictures fade with their wall.
- **Past the map's edge** a ring of scenery nobody can reach keeps every edge and corner hidden: a deep wood to the
  north and sides, only shrubs and rocks to the south (between the camera and the map), the sea running on past
  coasts, roads leading on through exits, and around towns a few larger houses of the town's style among the trees.
  Nothing tall stands across a road leading out, or just south of one down the sides, so every way out stays in
  plain sight.
- **People, eggs, signs and obstacles** are built procedurally:
  - `voxel_person.gd` builds people from the townfolk kit (`townfolk.gd`, `assets/townfolk/`, baked by `tools/import_townfolk.gd`): 80 people made of the kit's parts on one shared skeleton, coloured by `townfolk.gdshader` from each look's skin, hair, shirt, trousers and hat (the hero in the outfit, hairdo and colours the character creator gave them). Townsfolk pick the kit person who suits their look (a woman for long hair, robes, long sleeves for coats, a hat only if the look has one). Trainers out on the roads (and the arena ladder) wear `outfit: "camo"`: a padded jacket with a big upturned collar and a belt, combat trousers and boots, green or brown camo (`townfolk.gdshader` patches it in cells laid on the body at rest, so the pattern stays on the cloth), and a pack. Everyone can wear a pack (`look.pack`, one of `Townfolk.packs()`); the hero picks theirs in the character creator. People talk with their hands while they speak to you (`set_talking`) and sit on a chair at a table (`set_pose`; `world.gd seat`). The walk is built on the animators' walk-cycle rules: the cadence follows the speed and the stride lengthens with it, so planted feet don't skate; each foot is placed (heel strike, roll, toe-off, a lift through the swing) and the knee bends just enough to reach it; the hips settle as a foot lands, twist with the stride while the chest twists back; arms swing against the legs and trail them a little; a stroll (NPCs) blends into the hero's jog (more lean, a moment in the air, elbows pumping) and a sprint. People turn smoothly to a new facing, ease into and out of their pace, and stand with an idle (breathing, shifting weight, looking about). `--scene=hero --pose=walk --speed=4.6` shows a stride (`--phase`, `--model=tf<n>` for one of the kit's people); `--pose=talk` and `--pose=sit` show the others; `--trainer=<seed>` four camo trainers; `--packs=<n> --view=0|1` the hero in four packs from behind or the side. `tools/townfolk/view.gd` renders the baked people in a grid.
  - `voxel_buildings.gd` uses ten architectural styles. Shops never look like houses: they have a shop front at street level (display windows, a sign board with the shop's icon and a striped awning in its colour), and in most towns a flat above. Tidewater's are brick with a flat roof behind a parapet; Cogsworth's darker brick with pipes; Riverbend's and Gravenmoor's have a jettied upper floor; Sundown's a false front and a balcony; Dustwell's adobe with beam ends; Emberfall's a tiled skirt roof; the island and jungle villages have open market stalls; Copperpick has tin shops with false fronts. Out west, only shops wear false fronts.
  - `voxel_props.gd` builds the shop icons, eggs, shards, relics and obstacles.
- The terrain is made of textured voxel blocks; water and lava sit one step lower.
- Furniture uses pixel patterns from `ui/seamless patterns/`: bookcases full of books, goods shelves, quilted beds, stove-front fireplaces, plank counters and benches, wood tables, metal terminals and woven kilim rugs with a dark border (each room gets the kilim closest to its rug colour). `tools/build_patterns.py` cuts them into `assets/textures/patterns/`.
- Rugs (and wood or tile floors) carry on under anyone standing on them and under furniture.
- People indoors face the middle of the room, or the table they're sitting at; they never stare at a wall.

## The Start book (menu)

Press **Start** (Space) to open the travel book. Its bookmark tabs:

| Tab | What's in it |
|---|---|
| Trainer | Your portrait, gold, shield and shards, arena crests, trainer gear, Fly and Save. |
| Beasts | Your battle ring and storage (tap a beast, then where it should go: see Arranging your beasts), your party and eggs. Each beast's page shows its element(s), its slot, stats, skills, traits and its family tree: the parents and grandparents that were merged into it. |
| Flute | Every song with its effect and mastery; press A to practise one. The Capture page shows your level and when the next one is ready to learn. Unknown songs show where to learn them. |
| Bag | Items grouped as care, battle items, beast gear, trainer gear, sheet music and tomes. |
| Bestiary | All 39 forms with live portraits and where to find them. |
| Map | The twelve towns, with the full world map on A. |
| Settings | Save (first), music and sound volume, text speed, the gem the menus are cut from, the style (Pixel or Classic), touch pad, key guide, fullscreen, save, credits and quit. |

## UI and audio

- **Two looks**, picked in Start → Settings → Style (`UIKit.set_style`, kept as `Prefs.ui_style`):
  - **Pixel** (the default): the 1-bit kit's crisp white frames on near-black windows, every pixel of them two UI
    pixels (three screen pixels on a 1080p phone). Text and lines are plain white; the **gem** goes behind the white,
    never into it: the selected row, the open tab, the chosen battle bar, the target aimed at, tags, name plates,
    New Game and the held touch buttons are filled with it. The Start book is two of Humble Gift's paper pages, dark
    with the gem and lined in white, each with its ornament frame and its title written into the gap atop it: the left
    page unfolds as the book opens, and the right one slides out from behind it whenever a tab opens. The touch pad,
    bars, battle bars, target cards, ring tiles and the key guide are drawn the same way. Its pieces are cut from the
    two kits by `tools/build_pixel_ui.gd` into `assets/ui/pixel_ui.res`, stored as tones (fill, mid, line) that
    `UIKit.piece` paints in any colours.
  - **Classic**: soft rounded windows with a gentle gradient, a pale border and a drop shadow
    (`scripts/ui/cozy_box.gd`), drawn smooth at any screen scale, every window, border, text, bar and tag a shade of
    the gem.
  The gem is picked in Start → Settings → Gem: **Ruby** (the default), **Sapphire**, **Emerald** or **Hematite** (slate
  grey). `UIKit.set_accent` derives the whole palette from the gem (and the style).
- **Fonts**: **BoldPixels** for body text, menus and dialogue; **Lunchtime Doubly So** only for headings (window and
  page titles, tabs' section headers, name plates, map names). Both are drawn on a 16-pixel grid, so every size is
  snapped to one where their pixels land on whole screen pixels (`UIKit.body_px` / `head_px`): on a 1080p screen body
  text is 32 screen pixels and dialogue 48. The desktop window opens at 1920x1080 for the same 1.5x scale as phones.
  Dialogue is three lines to a page. Text sits at the top of every text box.
- **Phones**: a joined cross-shaped d-pad with raised arrows, for getting about (hold B to run), battles and the flute
  game alike. Each arm answers in its own quarter of the pad (a wedge from the middle out past its arrow), and only one
  arrow is held at a time, so a thumb on the line between two arms still walks one of the four ways. With it, glossy
  domed A and B buttons that sink when pressed (BoldPixels letters), and Start / Pause pills, all tinted with
  the gem. While the Start book or the
  world map is open the d-pad and A/B step aside: rows, tabs and towns are tapped, and Start closes the book.
  Anything that runs past one page (either of the book's pages, a long menu) gets **◄ Prev** and **Next ►** buttons
  with "page / pages" at its foot, each turning a whole page (`scripts/ui/pager.gd`), so all of it can be reached
  with taps alone. The
  book's detail pane scrolls, so a tall page never runs under the buttons, and in battle the command menu takes the
  place of the battle text while it is open.
- The game starts straight into the title screen (no engine splash). With no save yet, **New Game** is a big, glowing
  pill in the gem with no box round it: a thick pale border inside a dark edge, a soft glow that breathes, a slow pulse
  and a band of light sweeping across it every few seconds (`list_menu.gd` "bare"; on desktops a plain Quit sits under
  it).
- The title's menu comes up first, on the splash colour; the town behind it is built a moment later and fades in. The world and battle scripts, the travel book and the world map (the slowest scripts to compile) aren't preloaded: they load in the background while the menu is up (`main.gd` _title_backdrop, `loaded_script`). The touch pad's faces, painted pixel by pixel (a second or more on a phone), are painted on a worker thread the first time and kept in `user://touch_pad/` for each gem, so later launches load them straight away (`controls_overlay.gd`).
- **Music**:
  - Normal battles use *Rising Tide*; bosses use *Rising Tide (faster)*. Bosses are temple guardians, arena masters, Smuggler Rook, Black Bart, Gearhart, Nyx and Vexmora.
  - Tidewater plays *Andreas Theme*; Gearhart Tower plays *Krampus Workshop*.
  - Every region and kind of room has its own track; see `TRACKS` in `scripts/autoload/sfx.gd` and `MAP_MUSIC` / `ROOM_MUSIC` in `world_db.gd`.
  - Desert, mountain, moor and some interiors add an ambient loop.
  - `tools/convert_audio.py` makes 128 kbps copies in `assets/audio/music/`, trimming the 59-minute rainforest track to a 5-minute loop. The originals in `music/` are untouched.
- **Sound effects** from `sfx/` cover:
  - menus, the book's page turns, dialogue voices (pitched per speaker) and footsteps
  - hits (metal clangs for robots), the slingshot, bombs and the shield
  - pickups, doors, hatching, merging, flights, field moves, level-ups and the victory jingle
  - `tools/make_sfx.py` synthesises the game's own: the smack-and-puff when a foe is beaten and the soft thud when one of yours faints, and the knock on a locked door (`sfx/Custom/`)

## Mobile

- **Performance**: outdoors, every batch of trees, grass, flowers and ground blocks is split into 8x8-tile chunks, so only what's near the camera gets drawn (a map-wide batch was drawn in full every frame, then again for every shadow layer). The sun uses two shadow layers out to 30 units; trees deep in a wood, grass tufts and flowers cast no shadow; street lamps only light up in gloomy places like Gravenmoor; phones are capped at a steady 60 fps.
- The most detailed pack models (the palm, dead tree, big/oak/birch/round trees and the mountain rocks) have half-resolution `_lo.obj` versions made by `tools/voxel_lod.py` (also run by `import_voxel_assets.py`): about a quarter of the triangles, and from the game's camera they look the same. A busy town went from about 5.8 million triangles a frame to about 0.7 million. `godot --path . --rendering-method mobile -- --scene=perf --detail=1` prints what each map costs; `--scene=lod` shows the models side by side.
- The project uses the Mobile renderer on phones and tablets, sensor-landscape orientation, ETC2/ASTC textures, and an expanding aspect, so wide phones get extra width instead of black bars.
- On touch devices the d-pad, A/B and Start/Pause buttons appear automatically. They send the same input actions as the keyboard, so every screen and the flute minigame work with them. Dialogue boxes and menus stay clear of the buttons.
- Each button answers taps a little outside its drawn edge. The arrows are silent; A and B click softly at a low pitch, with B two notes below A.
- Tap the world to walk, double-tap to run, and tap things to use them (see Controls). Taps on or near the on-screen buttons never count as world taps: each cluster (the whole d-pad including its middle, A and B, Start and Pause) has a no-tap zone around it.
- To try the touch layout on desktop:

  ```
  godot --path . -- --touch
  ```

## Web version (iPhone and any browser)

`python tools/make_web.py` builds a version that runs in the browser into `build/web/`, ready to host on Cloudflare
Pages. It needs Godot's web export templates (`web_nothreads_*.zip` in `%APPDATA%\Godot\export_templates\4.7.stable\`)
and ffmpeg.

- **Small download**: about 18 MB before the title screen. The engine and game data are gzipped and stored as
  parts under `data/` (Cloudflare Pages takes files of up to 25 MiB); a small script in `index.html` joins and unzips
  them in the browser. Both exports leave out unused sound effects, unused voxel models and the full-size copies of
  models that have a `_lo` version (`tools/make_export_presets.py`).
- **Music on demand**: the web build doesn't contain the music. Each track is a small Ogg file under `music/`
  (about 1.3 MB) that the game downloads the first time it plays it, then keeps.
- It uses Godot's Compatibility renderer (WebGL 2), single-threaded, so it needs no special server headers. It needs
  Safari / iOS 16.4 or newer (or any current browser).
- **Deploy**: in the Cloudflare dashboard, go to Workers & Pages > Create > Pages > Upload assets, name the project and
  drop in the `build/web` folder. Or from a terminal (Node.js, after `npx wrangler login`):

  ```
  npx wrangler pages deploy build/web --project-name ruby-cocoon
  ```

  The site is then at `https://ruby-cocoon.pages.dev` (or whatever you named it). `_headers` caches the data parts
  forever (their names change whenever the game does) and the music for a week.
- **On an iPhone**: open the site in Safari, then Share > Add to Home Screen. It gets the app icon and opens full
  screen, in landscape.
- To try it locally: `python -m http.server 8060 --directory build/web`, then open http://localhost:8060.

## Editing the maps

The maps are plain text in `scripts/data/maps/`. Each string is one row of tiles, and the legend is at the top of each file.

- **Buildings** are solid rectangles of one letter, for example:
  - `C` Beast Center, `X` electronics, `V` Sky Tower
  - `I` Gearhart Tower, `B` cathedral, `J` hideout, `Q` temple
- **Obstacles** use `w j d o y l i | x m`, plus `n` (a washed-out footbridge, mended with the logs stacked by Old Hal's door) and `k` (a cliff that needs a winged beast).
- `b` is Youngster Kit's log cabin on the Coastal Path (room `kit_cabin` in `interior_maps.gd`, where an `anchors` entry puts Kit by the fire).
- **Push puzzles**: `u` is a boulder (moves one tile), `e` an ice block (slides), `c` an icy floor. An anchor named `puzzle_exit` marks the tile that counts as solved; `puzzle_area` draws the maze walls plain.
- **Anchors** named `item:<id>` place a fixed item (one anchor letter can be used on several tiles, each with its own flag); `inspector`, `warden` and `sentinel` place the road blockers. Room templates can have `anchors` too.
- **Story gates** use `&`.
- **Shards** use `*`.
- **Room templates**: in `interior_maps.gd`, `>` and `<` are stairs to the next and previous floor, and `K` is a kennel pen.

- **Towns** follow one plan: a main row of buildings with their backs to the tree line, a boulevard along their doors that the town's entrances lead straight onto, and a plaza with the statue in the middle. Shops sit around the plaza and houses at the ends. Big towns have a second row well to the south, behind deep back gardens (six rows behind two-storey shops).
  - The camera looks down from the south, so a roof, a tower or a tree hides whatever is just north of it. `python tools/town_check.py` traces the camera's line of sight to every walkable tile (with each building's real roof shape) and reports any tile where the path or the player would be hidden, plus any door, exit or person you can't reach.

- **Nothing tall between a road and the camera**: `check_maps.gd` flags any tree or building up to three tiles south of a road, a bridge, the plaza or anyone standing about (trees in a map's last three rows are drawn as shrubs, so they don't count). Use bushes, rocks, fences, water or tall grass there instead. On the Coastal Path everything south of the trail is low.
- **No slipping past a teacher**: `check_maps.gd` also walks every way from each of a map's exits to the others and
  flags a teacher (`world_db.gd` LESSON_TRAINERS, ARENA_LESSONS) whose line of sight (straight ahead, 4 tiles, up to
  the first wall or person) it can get past without crossing, and indoors one who doesn't see the tile you come in on.
  Teachers notice you as you arrive on a map and after another teacher's lesson, not only when you step into their
  sight (`world.gd` spot_you).

After editing, run the map checkers (the Godot one also flags anyone indoors who faces a wall):

```
godot --headless --path . --script res://tools/check_maps.gd
python tools/town_check.py
```

## Project layout

```
scripts/
  data/        race_db, move_db, item_db, song_db, world_db (towns, routes, temples, obstacles, biomes), voxel_manifest
  data/maps/   hand-made ASCII maps: towns, routes, room templates
  core/        beast.gd (a beast instance, growing up), beasts.gd (creation, merging, legendary dominance), ring.gd (the battle ring)
  gfx/         beast_rig, beast_parts, beast_toon.gdshader (the beasts), voxel_mesher (greedy mesher), voxel_beast, voxel_person, voxel_buildings, voxel_props, voxel_textures, voxel_assets
  data/        ... beast_looks (each beast line's colours)
  world/       map_loader.gd (ASCII → map), world.gd (voxel overworld + interiors), map_gen.gd (tile types)
  battle/      battle.gd (ring battles, trainer turn, shields, egg drops), command_panel.gd (the stacked command rows)
  ui/          book_menu (Start book), list menu, dialog box, beast card, flute minigame, controls overlay (key guide / touch pad), pause
  data/        ... chatter_db (what townsfolk, residents, trainers and mascots say)
  autoload/    GameState (save data), Sfx (music + effects), Prefs (settings), UI, Story (quests), Places (shops, centers, music shop, Sky Towers), Menus
tools/         new_beasts/ (bake.py, forms.json, debug_draw.py), import_new_beasts.gd, import_psx_beasts.gd, import_psx_robots.gd, make_beast_icons.gd, import_psx_houses.gd, import_psx_*.gd, import_voxel_assets.py, vox2obj.py, build_ui_assets.py, build_patterns.py, convert_audio.py, make_sfx.py, make_icon.py, make_web.py, voxel_lod.py, town_check.py, make_export_presets.py, check_maps.gd, debug/
```

## Developer test modes

```
godot --path . -- --scene=world:cogsworth --shot=C:/tmp/a.png            # screenshot any map (or world:cogsworth#10 for an interior)
godot --path . -- --scene=world:reef --spawn=33,10 --flags=island_peace  # spawn at a tile with story flags set
godot --path . -- --scene=battle --kind=robots --wait=5 --shot=C:/tmp/b.png
godot --path . --resolution 2400x1080 -- --touch --scene=battle --keys=r,r,r,a,a --tapcard=2 --shot=C:/tmp/t.png   # aiming a move: the target cards (tap card 2)
godot --headless --path . -- --scene=sim --n=10                          # simulated auto battles
godot --headless --path . -- --scene=flow                                # scripted run through the whole story
godot --path . -- --scene=knock                                         # knock on locked doors (a Tidewater house, the cathedral)
godot --path . -- --scene=skytower                                      # into a Sky Tower, up to the roof and away on the Tempestrix
godot --path . -- --scene=gallery:nature:0 --shot=C:/tmp/g.png           # voxel asset gallery
godot --path . -- --scene=beasts:0 --shot=C:/tmp/v.png                   # beast gallery (pages 0-3, 4 = merges)
godot --path . -- --scene=world:tidewater --overview=1 --shot=C:/tmp/o.png   # a whole map from high above
godot --path . -- --scene=book:settings --gem=sapphire --shot=C:/tmp/s.png  # try a gem for one run (--style=cozy / pixel: a style)
godot --path . -- --scene=book:map --flip=cozy --wait=1 --shot=C:/tmp/f.png   # Settings > Style changed with the book open
godot --headless --path . --script res://tools/build_pixel_ui.gd          # cut the Pixel style's pieces from the two UI kits
godot --path . --resolution 2400x1080 -- --touch --scene=battle --shot=C:/tmp/p.png   # a 20:9 phone
godot --path . -- --scene=book:beasts --shot=C:/tmp/m.png               # the Start book on a tab (trainer, beasts, flute, bag, bestiary, map, settings)
godot --path . -- --touch --scene=battle --shot=C:/tmp/t.png            # touch layout
godot --headless --path . -- --scene=tutorial --lesson=ring --auto=1    # one Coastal Path teacher's guided battle (screen, turns, slingshot, items, ring)
godot --headless --path . -- --scene=tutorial --lesson=elements --auto=1  # a Tidewater arena coach's lesson (team, elements; --egg=24 starts with an earth beast)
godot --path . -- --scene=fishing --taps=4.6 --snap=10 --shot=C:/tmp/f.png  # Gil's lesson (--lesson=0: a cast at a ripple, --bait=worm_bait)
godot --path . -- --scene=battle --kind=fishing --shot=C:/tmp/d.png        # a reeled-in beast's battle: the dock and the water
godot --path . -- --scene=battlecmd --touch                             # the battle's command panel: one A is one confirm, every move's target picked (arcs, all-foe moves), ▲ turns the ring, Move (yours and a foe trainer's), the ring turning by itself ("BATTLE COMMANDS DONE: 0 problem(s)"); --stop=arc|all|move --shot=C:/tmp/b.png
godot --path . -- --scene=ringedit --touch                              # the ring editor: who may go where on the ring and in and out of storage, lit cells, taps ("RING EDIT DONE: 0 problem(s)")
godot --headless --path . -- --scene=lessons                            # every guided battle played by a button masher, with one beast and with two: one thing to pick on every bar and menu, nobody down, all won ("lessons DONE: 0 problem(s)")
godot --headless --path . -- --scene=coaches                            # a new trainer walks the Coastal Path to Tidewater and into its arena talking to no one: every teacher must stop them, in order ("coaches DONE: 0 problem(s)")
godot --headless --path . -- --scene=flutelesson                        # the guided Weaken-then-Capture of the first wild beast after the flute
godot --headless --path . -- --scene=mascot                             # mascots' signature moves: the rules, teaching at Lv 39 / 40, another line, a merge
godot --headless --path . --script res://tools/check_beasts.gd           # every form's name, elements and model; growing up at Lv 20 and 40; merging only final forms ("BEASTS CHECK DONE: 0 problem(s)")
godot --path . -- --scene=newbeasts --lines=dino,owl --shot=C:/tmp/n.png  # the beasts side by side, a column per line (--stages=1,3, --anim=idle|walk|lie|attack, --ghost=1, --view=three|side|front, --zoom, --merge=dino_3+owl_3 --seeds=1,2,3)
godot --path . -- --scene=mascot --plaque=1 --pages=2 --shot=C:/tmp/q.png   # read Cocoon Cove's statue plaque
godot --headless --path . -- --scene=capture                            # Capture rules, Uncle Rafe's lessons and the arena's flute rule
godot --headless --path . -- --scene=puzzles                            # solves every road puzzle (bridge, cliff, rockslide, ice, checkpoint, warden, sentinel)
godot --headless --path . -- --scene=wilds                              # roaming wild beasts: sneak attack, chase, ambush, flee
godot --path . -- --scene=marks --shot=C:/tmp/k.png                     # the !, blue ! and ? marks
godot --path . -- --scene=ring --keys=a,a,d,d,d --shot=C:/tmp/r.png      # a ring battle driven by keys (a b l r u d); --kind=wild, --foe_level, --foe_shield
godot --path . -- --scene=spiral --kind=ambush --wait=0.6 --shot=C:/tmp/s.png   # the battle spiral (sneak / wild / ambush)
godot --path . -- --scene=tap                                           # tap to walk, double-tap to run, tap to talk / enter
godot --path . -- --scene=walk4 --touch                                 # four-way walking: two keys at once, a turn mid-step, gamepad d-pad and stick, B to run, the touch d-pad, tap to walk and a porch; every stop on a tile's centre ("WALK TEST DONE: 0 problem(s)")
godot --path . -- --scene=tapzone                                       # taps near the touch controls don't walk you anywhere
godot --path . -- --scene=saves --card=1 --shot=C:/tmp/c.png            # save slots and the "Game saved!" card
godot --path . -- --scene=heal --shot=C:/tmp/h.png                      # the Beast Center healing machine (--what=hatch for the incubator)
godot --path . -- --scene=defeat --at=0.2 --shot=C:/tmp/d.png           # a beaten foe's puff of smoke and a damage number
godot --path . -- --scene=hero --shot=C:/tmp/h.png                      # the hero from four sides
```

## Credits

See **CREDITS.md**; the same list is in the game under Start → Settings → Credits.
- Most of the music appears to be Kevin MacLeod's (CC BY 4.0), which requires attribution.
- The TravelBook UI licence asks for credit and a note of changes.
- StickyBizcuit's voxel pack asks for a hidden easter egg: look for Bizcuit in Cocoon Cove.
- Several packs (some voxel samples, the fonts, set1 and the sound effects) came without licence files. Check each source's terms before releasing the game.
