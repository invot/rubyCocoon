> **Folded into [runbook.md](runbook.md)**, the numbered chain to follow. This file is background; where they differ, the runbook wins on order and scope.

# Exploration and secrets

The user's direction, 12 November 2026: **Ruby Cocoon has two pillars, exploration and battling.** Roads become larger, winding and full of secrets, with silly and goofy puzzles, caves, shortcuts and cozy side paths. This file is the design. The work is done in the X steps at the bottom, and inside each biome's B steps in [steps.md](steps.md), so every road is laid out once and decorated once.

Every rule in AGENTS.md still holds:
- Eggs are the only way to get beasts.
- No wild beasts in towns.
- Whole-tile movement (with the optional eight-way setting, Phase M).
- Touch and keyboard parity.
- Speech goes in bubbles, signs in dark windows, and films are dialogue only.
- Lessons and story gates are protected.

The README's journey table changes as each road is rebuilt, and the README is updated in the same step.

## User decisions

| Topic | Decision |
|---|---|
| Road size | Roads grow to **about 3–4 times** their current walkable area: winding, with branches to caves, secrets and side areas that don't lead to towns. **The Coastal Path (first road out of Cocoon Cove) stays largely as it is**, as the tutorial |
| Required content | **Many puzzles are required.** Most roads need at least one of them solved to get through. Each road still has one clear main route, and the hint system keeps the next objective understandable |
| Shortcuts | Reaching the far end of a long route unlocks a **permanent shortcut** back toward its start (a bridge winch, a gate opened from the far side, a ladder or a lift) |
| Map edges | **Both fixes**: a band of cheap, unwalkable filler scenery (cliffs, forest, sea, dunes) past every edge, *and* a camera that eases to a stop before any real edge could show. This applies to towns and roads alike |
| Timing | Built **with each biome** (B steps): layout and secrets first, then that road's art composition |
| Element access | **Guaranteed.** Before any required puzzle needs an element (fire torches, water vine, statues), the story makes sure an egg of that element was reachable earlier |
| Critters | Snakes, monkeys and other talking animals are **talking critters**: world characters that are never fought, hatched or owned |

## Systems (built once, used everywhere)

### Larger maps
3–4× maps must stay inside the Phase P budgets: chunked ground, background loading, batched scenery and ground on disk (`ground_store.gd`). Re-measure loading and walking on the phone for the first enlarged road before enlarging more.

### Map edges never show
- Every map gets an edge band of filler: low-cost scenery suited to its biome, at least as deep as the camera can see beyond the edge. It is unwalkable.
- The camera clamps smoothly, so the player walks off-centre near an edge.
- A `check_maps` rule fails any map whose edge band is too thin for the gameplay camera.
- This applies to towns too.

### Caves
- **Cave maps** are reached from road branches. Each has an **elemental focus**: its wild beasts, palette, props and lighting follow that element.
- **Every cave has wild beasts.**
- Some caves (and some other places) are **dark**. A **fire beast lights torches**, which illuminates the area around each torch.
- Dark torch rooms are **required in the Temple of Flame**.

### GIANT beasts
A few GIANT caves exist in the whole game (**3–5 in total**), placed per road as the biomes are built. Each one:
- holds a **nest with a GIANT variant** of one species, plus **lots of the ordinary version** of that species in the cave;
- has a giant that is much stronger than the area's other beasts, larger in scale, and wears a **painted mud-and-moss overlay**: clean painted splotches, cave dust and scratches in the game's soft style, clearly feral but never gritty noise;
- **can be beaten once per cave**. The nest stays empty afterwards (saved flag);
- **always drops a special GIANT egg**. Its hatchling has **+50% stats** and a **visible difference** (for example a larger scale and a special trim or marking), saved on the beast with a default for old saves.

### The mole cave
One cave contains **five mole trainers**. Each insists, in its own silly way, that it is the **THIRD strongest mole**. Each has a small team and a goofy intro. Beating each mole **reveals a treasure behind it**. There is no giant, but the cave still has wild beasts and an elemental focus (earth suits it).

### Talking critters and snake swings
- **Friendly snakes** talk to you. Then they hang from a tree branch over a gap, and the hero swings across.
- This is a traversal link between two tiles: a short animation, no free movement. It works in both directions once the snake is befriended.

### Element interactions in the field
One shared "use a beast's element on this" interaction, extending today's brambles, lava and fog obstacles, drives:
- torches (fire);
- the Giant Vine (water);
- the Sleeping Statues;
- other obstacles.

### Magic butterflies
- Rare butterflies **heal your beasts' MP** when touched.
- They live only in certain areas (glades in the jungle, reef and moor, for example).
- A spot **refills after a while**: on a timer, or after leaving the map.

### Natural hot springs
- Hot springs sit **down a side path off the main path** on several roads.
- They **fully heal HP and MP** and give a **buff for the next battle only**, after a short cozy scene.

### Persistent mechanisms
Bridges, winches, elevators, waterwheels and opened doors are saved state, and they stay solved.

## Set pieces

The user named each of these. "Required" marks the ones proposed to sit on the main route. Placements marked *(proposed)* are the agent's suggestions, to be confirmed when that road is built.

| Set piece | Where | Required | Design |
|---|---|---|---|
| **Unreasonably Large Crayon statue** | The road to the Temple of Tides (Isle Trail / Coral Reef) | Yes | It replaces the villagers who stand across the road. **Kelpwick's elder** put it there to keep Shellhaven's tourists away from the temple. Locals grumble that any other shape would be easy to move, but a crayon? Impossible. **Beating Kelpwick's arena (Reef Warden Nerissa)** earns the elder's trust. The elder then explains that only a machine able to remove crayon-shaped statues can shift it, and that you'll need some sort of nerd or inventor, strongly hinting at the one in the second city (Bellerive). **Phoning Mom** afterwards, she says plainly that it's Volt. **Volt at Sparkwire Electronics** (Bellerive, the shield-point inventor) gives you his crayon-statue-erasing invention **for free** after a goofy scene, as a key item. Hints (`Story.next_goal()`) follow each stage |
| **The Overly Dramatic Door** | A path puzzle *(proposed: Mesa Trail or Moor Road)* | Yes | A huge stone door with an intimidating face claims only extraordinary wisdom may pass, then asks a riddle answerable only with Yes or No (the standard spoken Yes/No: A = Yes, B = No). Once the player has answered **both** yes and no (across tries), it admits it doesn't know the answer, is just lonely, and opens. Speech bubbles anchored to the door |
| **Monkey Exchange Program** | **Jungle Trail** | Yes | Monkeys block the path, demanding a bent spoon, a rotten fruit, an old shoe and an empty bottle. Each item comes from another monkey on the path, in a chain of trades. The final monkey wants nothing: it gives irrelevant relationship advice, then moves |
| **Friendly snakes** | Jungle *(and other forested roads, proposed)* | Some | Swing across gaps; see Systems |
| **The Giant Vine** | Beside a cliff *(proposed: Jungle or Reef)* | Optional or required per road | Water it with a water beast and it slowly climbs the rock face. Fully grown, it is a ladder |
| **The Forgotten Waterwheel** | An old mill beside a waterfall *(proposed: the River road)* | Optional, with secrets | Restarting the wheel powers a wooden elevator between two elevations and turns other machinery that opens small secrets. Waterfall sealing rules apply |
| **The Fallen Bridge** | A ravine *(proposed: Mesa Trail)* | No: it's the shortcut | A collapsed rope bridge hangs from one side. Reach the far side by the long route, repair the winch, and the bridge becomes a permanent shortcut to the entrance |
| **The Three Sleeping Statues** | *(proposed: Dune Sea or temple approach)* | Optional | Stone statues resembling three beast types. Each wakes briefly (opens its eyes) to the right elemental or creature interaction. All three awake reveals a reward |
| **The Shell Collector** | A beach *(proposed: Isle of Tides)* | Optional | Collect small shells on the beach and arrange them in a large empty shell to match the colours and shapes marked on the surrounding rocks. Completing it summons a **rare merchant critter** (not a wild beast) or reveals an item buried in the sand |
| **The Singing Cactus** | Desert road | Optional | A cactus sings only when you stand beside it **facing away**. Learn its song on the flute: a new **battle song** (effect decided when built, balanced against the existing songs) that also makes cacti dance in the field |
| **Natural hot springs** | Side paths on several roads | Optional | See Systems |
| **GIANT caves** | 3–5 roads | Optional | See Systems. One per element is suggested |
| **Mole cave** | A mountain or mine road *(proposed)* | Optional | See Systems |
| **Dark rooms** | Some caves; **required in the Temple of Flame** | Temple: yes | Fire-beast torches |
| **Beast Beauty Pageant** | **Cogsworth**, the cyberpunk city (see below) | Optional, repeatable | See below |

### Beast Beauty Pageant
- A **repeatable** mini-game with **ranked tiers** (for example Novice → Grand) and prizes (hat parts, items, crystal shards).
- **Dress-up:** pick a "pretty" hat and customise its **shape**, **colours** and **decorations**. The hat is worn only for the pageant.
- **Runway:** your beast competes against other beasts. Posing is a **rhythm attack** using the existing beat chain (`beat_chain.gd`, `beat_cue.gd`): the longer the on-beat chain, the higher the score and the better the pose. **The poses are the beast's existing attack poses** (`beast_model.gd` `pose_*`). It keeps the beat cue's minimal look, one press counting once, and touch, keyboard and gamepad parity.
- Opponents' scores are rolled from their tier.

### The cyberpunk city
The user says the cyberpunk city "currently does not look cyberpunk or like a city". Cogsworth is the only `"size": "city"` town, with the `steampunk` biome; Gearhart's office already overlooks a "neon city". **Confirmed by the user: Cogsworth becomes a proper dense cyberpunk city** (tall blocks, neon signage, layered streets) in its biome steps. Gearhart's steam gate and tower story stay. The README and the Steampunk row in `standards.md` §18 change when it is built.

## Steps

Each step takes about 1–2 hours and follows the session protocol in [README.md](README.md). Systems come first; then each road's content is built inside its biome block.

| Step | Goal | Done when |
|---|---|---|
| **X1** Map edges | Edge band and smooth camera clamp, plus a `check_maps` rule, on all current maps | No edge visible from any reachable spot in the shots of every town and road. **User approves.** (It can run any time after Phase P) |
| **X2** Big-map budget | Enlarge one non-tutorial road as a 3–4× blockout (grey layout) and measure load, walking and memory on the phone | Numbers within the P11 budgets, or a written fix, before more roads grow |
| **X3** Road layout method | A layout template: main route, 2–4 branches, a shortcut loop and a side hot spring; per-road plan sheets in `exploration-roads.md` | **User approves the method** on the X2 road |
| **X4** Caves | Cave map type, elemental focus tables, entry and exit, wild beasts | One test cave playable |
| **X5** Darkness and torches | Dark areas, fire-beast torch lighting, the shared element interaction | A torch test room. The Temple of Flame plan is updated |
| **X6** GIANT beasts | Giant variant, painted mud-and-moss overlay, nest, once-only flag, GIANT egg, +50% hatchling with a visible mark, save defaults | `quick` and save/load tests pass. **User approves the look** |
| **X7** Critters and snake swings | Talking-critter type and the swing traversal link | Swing works with touch and keys, in both directions |
| **X8** Butterflies and hot springs | MP-heal butterflies with respawn; hot spring full heal plus next-battle buff | Both tested with captures |
| **X9** Persistent mechanisms | Winch, bridge, elevator, waterwheel and door state saved | A save/load test covers them |
| **X10–X12** Pageant | X10 hat customiser (touch and keys); X11 runway and rhythm posing on the beat chain; X12 opponents, tiers, prizes and venue | **User approves** each |
| **X-content** | One set piece per step (crayon statue and Volt's invention, dramatic door, monkey chain (two steps), mole cave (two steps), vine, waterwheel, bridge, statues, shells, singing cactus and its song) | Placed in its road's biome block |

Per road (inside each B block in steps.md), before the biome's composition step:

- **B-`<b>`-X1** Road blockout at 3–4× (except the Coastal Path), with the elevation, diagonal edges (M4), branches and shortcut loop. Both map checkers pass. **User approves the layout from an overview plus gameplay shots.**
- **B-`<b>`-X2** That road's set pieces, caves and secrets, one per step, as listed in its plan sheet.
- **B-`<b>`-X3** Story hints, NPC lines and the README journey table updated for that road.
