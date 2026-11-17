# Ruby Cocoon: antagonist and ending direction

Status: planned narrative revision; not implemented in gameplay.
Updated: 16 November 2026.

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

## Continuity against the current repository

Reviewed against README.md, scripts/autoload/story.gd, and scripts/story/opening.gd on the main branch at f31a1b2a16d8c83b6ceaf55d0ea9c9d102d050f2.

| Current implementation | Required reconciliation |
| --- | --- |
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

1. Confirm Gearheart/Gearhart spelling and Matt/Magnus naming.
2. Confirm whether the scientist is Vexmora and whether his General title and the Legion remain.
3. Define Jared's relationship to player naming and the protagonist's established family.
4. Place Marlyse's meeting and friendship with the player's mother, and decide where Mom's hockey-shirt-and-stick fight with the goons occurs.
5. Establish the cause of the brothers' estrangement and the timing of the reveal.
6. Define spirit-energy extraction, its effects on captives, and the island network's failure mechanism.
7. Order the attempted killing, scientist's intervention, shutdown, Marlyse's farewell, and home confrontation.
8. Establish that the immediate catastrophe is resolved or contained when the brothers play spaceships.

## Scope of this update

Documentation only. Existing dialogue, character names, quests, maps, save flags, and ending behavior have not been changed by this document.
