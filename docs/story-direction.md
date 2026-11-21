# Ruby Cocoon: antagonist and ending direction

Status: implemented locally on 17 November 2026; focused verification complete. Not pushed.
Updated: 17 November 2026.

Confirmed identity decisions (17 November): Jared is Vexmora, the scientist; Matt Gearheart is the industrialist and Jared’s older brother. The player remains a separately named protagonist. The nightmare tool pool is a spork, the player’s left sock, and a roll of toilet paper.

This document records the story decisions from the development discussion, distinguishes them from suggested connective material, and identifies continuity work against the current game. User-established beats below are the intended direction; suggested details and open questions are not settled canon.

## Established story beats

### The scientist and Marlyse

The main antagonist is a mad scientist whose mother, Marlyse, is dying. He had a terrible childhood, and she was all he had. His determination to save her motivates his research and his willingness to do terrible things.

He convinces the wealthy industrialist Gearheart to support the research. Ghost beasts are part of that research. Gearheart recognizes a way to make money from it, and the two enter an arrangement: the scientist pursues a cure while Gearheart pursues profit.

The scientist is staunchly opposed to Gearheart killing the protagonist. When Gearheart attempts it, the scientist uses his powers to stop him. This boundary does not absolve the scientist of the harm caused by his research.

At the end of the scientist's arc, Marlyse asks him to accept her death and recognize that everyone will die someday. The emotional resolution requires him to accept her wishes rather than keep deciding for her.

### The mothers meet, and Mom fights back

At some point, the player's mother and Marlyse meet and get along very well. They are distinct characters who develop a warm friendship. The exact circumstances and placement of their meeting remain to be decided.

At another point in the story, the player's mother puts on a hockey shirt, picks up a hockey stick, and beats up some goons. This is an established comic action beat; its location, trigger, and the goons' affiliation remain open.

### Gearheart's arrogance and the spirit-energy catastrophe

Gearheart extracts extraordinary quantities of spirit energy by running the machines far beyond their design limits. His apparent industrial success depends on equipment already in critical condition.

The machines must be shut down before they explode. A single machine's explosion could wipe out half the realm. The discovery that the entire island is full of these machines and stored spirit energy raises the threat to the entire world.

His downfall must follow from his own decisions: demanding greater output, dismissing limits, and refusing to relinquish the wealth or control represented by the stored energy. The danger is a consequence of his arrogance, rather than an unrelated disaster.

### Matt and Jared: the spaceships ending

Near the end, Gearheart is revealed to be Jared's older brother. His first name is Matt.

Their final confrontation takes place at their mother's home. They are about to fight to the death when they see toys in a box. The toys bring back a shared childhood memory.

They remember dinner at a nice restaurant. Matt tells young Jared to share his fries with their mother. Jared asks why. Matt explains that she could not afford to buy food for herself, so they need to share theirs with her.

In the present, instead of fighting, Gearheart asks his little brother to play spaceships with him.

The scene recalls Matt's capacity for care and sharing before his fixation on accumulation. Its emotional endpoint is the brothers choosing to stop fighting. It should retain the simple, vulnerable invitation rather than replace it with a speech explaining the theme.

### Revised intro: dungeon nightmare and remembered tool

After the opening warehouse cage reveal, replace the trainers-in-the-grass / Coastal Path scene with a close-up of the sleeping player's face in bed. Transition into their nightmare.

In the nightmare, the player is trapped in a poorly lit dungeon, standing at the bars of their cell. This is a different location from the warehouse holding the kidnapped trainers. A channel of dark water runs across the dungeon in front of the cell, with ducks floating in it. The player looks at a piece of bread lying outside the cell; one of the ducks spots it, climbs out of the water, waddles over and eats it. The film lingers here: a long, quiet watch of the duck before anyone speaks. The duck only quacks.

The player asks why there are ducks in a dungeon. From the dark behind them, an unseen voice says those are his ducks, adds a duck fact, and then:

> "I'll get us out of here, just give me a [tool]."

Select the tool name randomly from a pool of three. The three tools are a spork, the player’s left sock, and a roll of toilet paper. The unseen speaker’s name stays hidden (“A voice”), but “those are my ducks” is a deliberate hint for anyone who later meets Jared and his ducks.

End the nightmare and return to the player waking in bed. They remark on the odd dream and joke that it could only happen if some maniac put "ruin spring" on their calendar. Preserve this meaning; final dialogue wording remains to be written.

### Jared and his ducks

Jared has an affinity for ducks. He has befriended them wherever he has been, including the ducks in Matt’s old dungeon, and they follow him about. He knows a great many duck facts (a duck can sleep with one eye open; a duck’s webbed feet don’t feel the cold) and, being eccentric, sometimes just talks about ducks in the middle of more serious matters. Use it lightly: a fact or an aside, never a lecture, and never at the expense of a serious scene’s weight.

Ducks are animals, not talking critters or beasts: they never speak and are never caught, hatched or battled. They float on water and waddle on land. A duck next to the player only quacks (a sound, no speech bubble); each quack is pitched a semitone or two up or down at random. A few float by grassy banks on the roads (never in towns), and Jared’s are in the dungeon of the dream and of the jail.

### Later jail escape: memory or a difficult flute song

Later, the player is in jail with Jared. Remembering the tool named in the intro provides a way to bust out of the cell without performing the difficult flute song.

The alternative is a really difficult song that Jared composes directly in the dirt on the cell floor. The written notation uses button icons, some of which are cut in half, leaving the player to interpret the incomplete symbols when performing the song. Which icons are halved and the exact difficulty tuning remain to be decided.

Playing the song (“Jared’s Duck March”) coaxes one of Jared’s ducks into helping: the player guides it to the cell’s catch, and it unlocks the cell. Once the gate is open, the ducks follow Jared and the player out of the dungeon in a line. Both routes must lead to escape; the remembered tool clue bypasses the demanding musical challenge.

Implementation requirement: choose the tool once for the playthrough and persist it with the save. The later jail scene must use the same tool, without rerolling it on reload or when the intro is replayed. Define how skipped intros and older saves expose or initialize the clue so that the flute route remains available.

The tool pool, how the player supplies or selects the remembered tool, and the precise tool-based escape action are still open. Jared is Vexmora, the scientist; he is a separate character from the player.

## Suggested connective development

These are working proposals from the brainstorm, not additional confirmed decisions.

### A gradual moral decline for the scientist

His research initially buys Marlyse small amounts of time, making each further compromise easier to rationalize. Beast evolution, merging, and spectral persistence could inform his attempt to preserve a person's identity beyond bodily failure.

Gearheart funds the equipment and facilities, then gains leverage through ownership of the infrastructure sustaining the research. The scientist remains responsible for knowingly accepting harmful methods; Gearheart should not absorb all culpability.

Give Marlyse a presence before the farewell: conversations, letters, humor, preferences, and a desire to live. Acceptance need not mean that she is unafraid or indifferent to dying.

### Make the machinery warnings visible

Seed the failure through exhausted engineers, makeshift repairs, unreliable readings, and disabled or bypassed shutdowns. Gearheart interprets continued operation as proof that the engineers exaggerated the danger, although their interventions have prevented disaster.

One proposed explanation for the worldwide threat is a connected island network of extraction plants, pipelines, and reservoirs: one rupture triggers the others. Establish the actual propagation rule before the climax, so the escalation has understandable limits and causes.

The scientist could discover that Gearheart has concealed actual operating levels. Decide how much he already knew; this must not erase his responsibility for the underlying research.

### An active shutdown climax

The protagonist should materially contribute to preventing the catastrophe. A possible climax requires reaching controls, isolating plants, and releasing captive spirits while Gearheart overrides shutdowns to protect his investment.

The Requiem of Dusk could help the spirits resist coercion. Centralized command systems could become Gearheart's vulnerability because he insists on personally controlling everything.

The scientist's intervention against Gearheart could also require surrendering the experiment he believes will save Marlyse. Whether shutting down the network directly ends her treatment remains an open choice.

Resolve or contain the immediate explosion danger before the brothers sit down to play, or make Matt's surrender of the remaining shutdown control part of his decision to stop fighting.

### Preserve the quiet ending

Establish the toy spaceships and relevant family history earlier without revealing the entire ending. The exact timing of the brother reveal remains undecided.

The fries memory should show their mother's sacrifice through a small action. Avoid adding an explanatory monologue.

Matt offering a toy can begin reconciliation without guaranteeing forgiveness or erasing accountability. His later obligations could include surrendering control, helping repair the damage, and facing consequences.

Allow Marlyse's farewell and the brothers' reconciliation their own emotional space. Their exact sequence is not yet fixed.

## Historical continuity audit (before the 17 November implementation)

Reviewed against README.md, scripts/autoload/story.gd, and scripts/story/opening.gd on the main branch at f31a1b2a16d8c83b6ceaf55d0ea9c9d102d050f2.

| Current implementation | Required reconciliation |
| --- | --- |
| The opening currently cuts from the warehouse cages to trainers on the Coastal Path, then the bedroom. | Replace the grass scene with the sleeping-face close-up, separate dungeon nightmare, and wake-up joke. Add the three-option tool clue and its saved state. |
| The new jail beat describes the player being imprisoned with Jared. | Clarify whether Jared is a separate companion or the protagonist named in the brothers\u0027 ending; do not silently resolve the existing identity ambiguity. |
| Cogsworth is the city; the industrialist is Magnus Gearhart, and the company sign uses Gearheart Industries. | The new direction calls him Matt Gearheart. Confirm the surname spelling and how Magnus relates to Matt before changing dialogue, identifiers, or assets. Cogsworth remains the city unless separately changed. |
| General Vexmora leads the Umbral Legion and explicitly intends to take every town. | Vexmora is the proposed existing character to revise into the scientist. Replace or reinterpret conquest as a means of securing research resources, or give expansionist aims to Gearheart. The scientist's final name and title remain open. |
| The opening says Vexmora pays Gearhart by the trainer-beast bond; Wren says the Legion pays for captives. | Explain how this fits Gearheart initially funding the scientist. A proposed arrangement grants him exclusive research rights and commercial returns; current payment dialogue needs revision or an explicit accounting explanation. |
| Kidnapped trainers supply living bonds to command ghosts. | This can support the research premise, but define what extraction does to captives, why living bonds matter, and what the scientist knowingly authorizes. |
| Ghost beasts already exist in the world; Old Mort says the Legion drags them from the crypt and twists them. | Preserve pre-existing ghosts if desired: the scientist studies and exploits the phenomenon rather than necessarily inventing ghosts. |
| Gearhart is beaten at his tower before the final Vexmora encounter. The victory opens Caldera Road and enables the captive rescue. | Preserve the meaningful rescue and route progression while explaining Gearheart's return for the shutdown crisis and later confrontation at the mother's home. |
| The current finale is a Vexmora battle followed by the Legion's defeat and release of ghosts. | Add the machinery crisis, attempted killing and intervention, Marlyse's resolution, and the brothers' ending. Determine their order before revising completion flags. |
| The player chooses a name, and Mom appears at home and provides ongoing phone advice. | Decide whether Jared becomes a fixed protagonist name, a default/example name, or a personal name used in this particular story draft. Define why the older brother is absent and why the family connection is revealed late. |
| Marlyse and the brothers' shared mother have not been established in these reviewed story sources. | Marlyse and the player's mother are distinct characters who meet and get along very well. Establish their friendship without merging the scientist with either brother. |
| Ghost companions remain playable after the ending. | Liberation from coercion should remain compatible with willing ghost companions. Marlyse's choice need not establish that every ghost must disappear. |

## Decisions still needed before implementation

1. Resolved 17 November: Matt Gearheart. Preserve legacy internal IDs.
2. Resolved identity: Jared is Vexmora, the scientist. Stage the reveal while preserving existing progression.
3. Resolved: Jared is a separate NPC, Matt’s younger brother; the player remains customizable.
4. Place Marlyse's meeting and friendship with the player's mother, and decide where Mom's hockey-shirt-and-stick fight with the goons occurs.
5. Establish the cause of the brothers' estrangement and the timing of the reveal.
6. Define spirit-energy extraction, its effects on captives, and the island network's failure mechanism.
7. Order the attempted killing, scientist's intervention, shutdown, Marlyse's farewell, and home confrontation.
8. Establish that the immediate catastrophe is resolved or contained when the brothers play spaceships.
9. Tool pool resolved: a spork, the player’s left sock, a roll of toilet paper. Implement the clue interaction, tool-based escape and flute/duck controls.
10. Jared is Vexmora in the shared jail. The unseen nightmare speaker remains unspecified.

## Scope of this update

The original 16 November update was documentation only. The 17 November runtime implementation adds the saved nightmare clue, jail escape, mothers’ friendship, hockey fight, spirit-network shutdown and revised ending. Visible naming is Matt Gearheart; internal IDs remain compatible. See the checkpoint below.

## Confirmed decisions superseding earlier continuity questions

The 17 November answers resolve the tool pool, Jared/player ambiguity, Vexmora/scientist identity and Matt/Magnus naming. Use **Matt Gearheart** in visible names; retain existing internal IDs and save flags for compatibility. Jared/Vexmora is Matt’s younger brother, not the player. Their mother and Marlyse are therefore the same person; the player’s Mom remains distinct and befriends her. Existing references above to these identities being undecided are historical audit notes. The timing of their friendship, Mom’s fight, the machinery shutdown and the jail remain implementation design work; do not claim these scenes are present until their runtime, saves and tests are complete.

## Runtime implementation checkpoint — 17 November

- `opening.gd` now cuts from the cages to a sleeping-face shot, a separate dungeon where a duck eats bread outside the cell and the voice claims the ducks before the remembered tool line, then the wake-up joke. The tool phrase is red. Existing A/B/skip controls remain.
- `GameState.nightmare_tool` stores the index in saved flags; new journeys choose once and older saves derive a stable fallback. Skipped/replayed intros do not reroll it.
- `prison_escape.gd` provides the remembered-tool route and Jared’s difficult, partly erased Duck March, with a controllable duck and brass lock; the ducks follow Jared and the player out once the gate opens. Wrong answers, failed songs and returning from duck control do not consume items or block retrying.
- The finale preserves the captive-rescue prerequisite. Jared’s defeat unlocks three real controls in the crypt; their ordered saved state isolates intake, frees spirits and shuts down the island network before completion.
- `family_film.gd` stages the mothers’ friendship, Matt’s attempted killing and Jared’s intervention, Mom’s hockey fight, Marlyse’s acceptance, the home confrontation, the restaurant/fries memory and spaceships invitation. Holding B skips without losing progression.
- The existing Andrew/Jared wedding remains afterward. Previously completed saves remain completed. Ghost companions remain playable.
- The Dustwell water arc below supersedes the Mine Road mole cave and the four-member version of the band. The older diamond/cactus/concert arc and user-supplied “Table Banana” audio remain separate runbook backlog; no substitute lyrics or audio were invented.

Implementation choices made within the confirmed direction: the mothers meet while the player first reaches Cogsworth; Matt imprisons the player and Jared before the final scientist battle; three network trunk controls represent the island-wide shutdown. The diary and old General/Legion references are retained as prior in-world knowledge until the reveal. The unseen voice’s name plate remains “A voice” during the nightmare.

Validation: final isolated story suite 10/10 passed; final appearance, custom melody and film follow-up 6/6 passed. See docs/development-plan.md and build/shots/story_revision/ for evidence and the remaining legacy concert scope.

## Dustwell and the water mages

Rosa sells water while the well is dry and holds the Rubywave Five to their contract. Beneath the well, five beavers have sealed Dale behind their dam. Dale recognizes the guardian song and hears the water answer the hero. Breaking the source dam together restores the town well. Rosa releases the band when confronted, and the musicians take their own repertoire to Cogsworth.

Dale sends the hero back past Kelpwick to the Temple of Tides. Water opens the carved panel in the drained falls chamber. In their sanctuary, Keeper Nerine teaches Torrent. At the lip of Dustwell's north channel, Torrent raises the river and floats Captain Reed's boat. Boarding takes the hero to Sunwall in the full game. The demo offers credits or continued exploration.

Other trainers remember playing the guardian song perfectly and being refused. The missing trainers have a separate trail through the posters in Dustwell, the search in Sunwall and the rescue in Cogsworth.
