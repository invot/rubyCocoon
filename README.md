# Ruby Cocoon

A voxel beast-training RPG for **Godot 4.7**. You hatch your first beast from an egg, battle to make it stronger, charm wild beasts with your flute, merge beasts into stronger ones, and stop the Umbral Legion and their ghost beasts.

## Running it

Open `D:\Games\RubyCaccoon\project.godot` in Godot 4.7 and press **F5**. You can also run it from a terminal:

```
"C:\Program Files\Godot\Godot_v4.7-stable_win64.exe" --path D:\Games\RubyCaccoon
```

## Controls

| Action | Keyboard | Gamepad | Touch (phones and tablets) |
|---|---|---|---|
| Move | Arrow keys | D-pad | D-pad, bottom left |
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
4. Scout Bram won't open the gate to the Coastal Path until you've done his **battle lesson**. It's a scripted three-round fight that teaches the slingshot, your beast's attack, **Defend** and items. You can only pick what he asks, you always win, and your beast reaches level 2.
5. Rebuild the washed-out footbridge on the Coastal Path (five logs) to reach Tidewater.
6. Uncle Rafe gives you the flute and teaches **Weaken** (walking you through the sheet music step by step) and **Capture I**. His lessons give you 30 seconds per song.
7. Arenas only let in trainers with a flute.

| Region | Towns | What happens |
|---|---|---|
| Coast | Cocoon Cove, Tidewater | Tidewater has the first arena, **Sparkwire Electronics** (shield points and beast slots), a Sky Tower and the ferry. |
| Isle of Tides | Shellhaven, Kelpwick | The two villages are feuding. Hear both chiefs, catch the smuggler on the Isle Trail who framed them, and they open the coral gate to the reef and the **Temple of Tides**. |
| Desert | Dustwell Oasis, Sundown Gulch (western town) | Bandits terrorise Sundown. Talk to the Sheriff, then beat Black Bart in the hideout to open the Dune Sea road. The **Temple of Winds** lies in the Dune Sea. |
| Mountains | Copperpick, Cogsworth (steampunk city) | CEO Magnus Gearhart is holding Cogsworth hostage and has sealed the road to the volcano. Fight up Gearhart Tower: each floor's robot sentries must fall before the stairs unlock. |
| Volcano | Emberfall | The **Temple of Flame** sits on the Caldera Road. |
| Jungle | Vinehollow | The village sells the finest gear in the land. The shaman needs the Sun, Moon and Earth relics; the ritual raises the hidden **Temple of Roots**. |
| River and moor | Riverbend, Gravenmoor | Gravenmoor is the Legion's town. Ghost beasts can be hatched and merged from here on. The gravedigger teaches the Requiem of Dusk. Commander Nyx guards the cathedral, and General Vexmora waits in the crypt beneath it. |

Every road between towns narrows to one bottleneck with a puzzle, getting harder as you go:

| Road | Puzzle |
|---|---|
| Coastal Path | A washed-out footbridge. Find the five logs lying along the path and lay them across the creek, one at a time. |
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

- **48 races**, 12 each of Fire, Water, Earth and Air. The weaknesses are: Fire to Air, Earth to Water, Water to Air, and Air to Fire.
- **Element roles**: Fire are offensive tanks, Water are healers, Earth are defenders, and Air handle status and evasion.
- **Eggs**:
  - A defeated wild beast has a **20%** chance to leave an egg at the end of the battle.
  - Trainers' beasts, robots and guardians never drop eggs.
  - Beast Centers hatch eggs into level 1 beasts.
  - Ghost beasts drop Shadow Eggs only after you reach Gravenmoor.
- **Temple guardians**: each elemental temple holds a legendary guardian: Abyssion, Zephyrax, Pyroclast and Terranox. Beating it gives a **Radiant Egg** of that element.
- **Merging** happens at Beast Centers, between two beasts at their level cap. A normal merge is 50/50. A legendary parent dominates at **80/20** and keeps its race. Ghost merging unlocks in Gravenmoor.
  - Beasts of neighbouring elements on the ring (Fire–Air, Air–Water, Water–Earth, Earth–Fire) merge into a **dual beast** of both elements. Opposite elements (Fire–Water, Air–Earth) can't merge.
- **Wild beasts** roam the routes in plain sight; there are no random encounters (the tall grass is still there).
  - Each beast sees in a cone in front of it, half as far if you're in tall grass, and hears you running nearby.
  - Beasts come running when they spot you. Only a lone beast hopelessly outmatched by your best one (8+ levels below it) bolts.
  - Marks: a yellow **!** when one spots you, a blue **!** when it's scared and fleeing, and **?** when it loses you. Nothing shows while it charges, or once it goes back to roaming.
  - Walk into one from behind before it spots you: a **sneak attack** (green spiral, it loses its first turn). Meet one face to face: a normal battle (blue spiral). Let one catch you from behind: an **ambush** (red spiral, you lose your first turn).
  - A beast no stronger than your best one usually (70%) roams with one or two more of its own kind, and the pack stands its ground. On roads with wild Lv 16+, stronger four-legged beasts, insects, birds and fish sometimes run in packs too.
  - Each road's trainers are stronger than any wild beast on it. The Coastal Path has the weakest beasts (Lv 1-2) and single-beast trainers.
- **Levelling** is slower than before: about twice as many wins per level.
- **MP**: elemental attacks cost MP (about a tenth of their power, at least 2); regular (neutral) attacks and every other move are free, and a regular attack is always there when MP runs out. MP comes back only from healing (the Beast Center machine, Mom, your bed) and items: Spirit Drop (15), Spirit Tonic (40), Spirit Elixir (all) from apothecaries, and Mint Tea at cafés.
- **The battle ring** (as in Jade Cocoon 2, `scripts/core/ring.gd`): every trainer stands in the middle of a ring of 8 slots.
  - The ring has a side per element, in this order round it: **Fire, Air, Water, Earth**. A side's middle slot holds a beast of that element; the **corner** between two sides holds a beast of either element, or a dual beast of both.
  - You carry as many beasts as you have **beast slots** wired up: 3 to start, up to 8. New beasts take a free slot they may stand in, joining the side most of your team stands on; move them round in **Start → Beasts → Battle ring**.
- **Battles** (`battle.gd`, `command_panel.gd`): one side of each ring faces the foe, and only its three beasts fight, using **that side's element** or plain (neutral) moves. A dual beast in a corner uses whichever of its elements faces the foe.
  - Each turn you choose your own action first (you always act first), then each beast's move, in stacked rows: ◄ ► change the action, A confirms, a move that needs a target then asks for one with ◄ ►, B goes back. **▲ on the top beast or ▼ on the bottom one turns the ring** to the next side with a beast standing on it.
  - Your actions: **slingshot**, **items** (potions, cures, revives, elemental bombs, sleep, poison, flash, nets, snares, weaken powder, haste, iron and war-drum tonics), a **flute song**, **Watch**, and **Run** (wild) or **Forfeit** (trainers). Each beast: a move, or **Defend** (half damage for the rest of the round; it goes first).
  - Your readouts (HP and MP) and a diagram of your ring are on the left, the foe's on the right. Winning plays *Android Sock Hop*. A beaten foe vanishes in a puff of smoke; your own fainted beasts lie on their pads. Damage numbers use BoldPixels.
- **Shield and the end of a battle**:
  - If the beast in the middle of the side facing the foe is down (or that slot is empty), its trainer can be **attacked directly**: each hit breaks one shield point. Turn your ring to a side whose middle still stands to cover yourself.
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
  - Climb a **Sky Tower**: Skykeeper Aria's ticket desk is in the lobby, and the stairs lead up to an open-air platform on the roof, where the Thunderhawk flies you to any town you've visited, for a fee.
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

- **App icon**: the game's own voxel Redcoon (with a cuter, icon-only face: big shiny eyes, a muzzle and pink ears) on a floating meadow island over a green valley. `python tools/make_icon.py` renders it with `tools/make_icon.gd` and writes Android's adaptive icon layers (background, foreground and a monochrome silhouette for themed icons) to `assets/icon/`, plus `icon.png` for the window.
- **World and props** come from the voxel packs in `voxelassets/`. They are converted to OBJ plus palette PNG by `tools/import_voxel_assets.py`, which uses `tools/vox2obj.py` for `.vox` files. The models are imported into `assets/voxel/` and listed in `scripts/data/voxel_manifest.gd`. To re-import:

  ```
  python tools/import_voxel_assets.py
  "C:\Program Files\Godot\Godot_v4.7-stable_win64.exe" --headless --path . --import
  ```

- **Beasts** are low-poly models from the PSX creature packs (`psx/Creatures`): fox, raccoon, otter, lion, owl,
  rattlesnake, mammoth, firefly, moth, clownfish, dragon and more (`RaceDB.FORMS`, one per race). `tools/import_psx_beasts.gd`
  bakes them into `assets/psx/beasts/` (turned to face +x, centred, scaled to one size), and `voxel_beast.gd` recolours
  each with the beast's own gene colours (mid tones take c1, dark tones a deep shade, light tones c2, eyes and claws
  keep theirs); ghosts are dusky and glow faintly. Merged beasts inherit one parent's form and mix the colours. Menu
  icons are rendered from the same models by `tools/make_beast_icons.gd` and recoloured the same way.
- **Gearhart robots** (`RaceDB.ROBOTS`) are PSX robots: the Clockwork Sentry with a wind-up key, the boiler-bodied
  Steam Mecha and the broad Iron Golem from Bricchi Games' Retro Robots, and the boxy Tank Walker from CokeEnthusiast's
  Robot guy (`RaceDB.ROBOT_MODELS`). `tools/import_psx_robots.gd` bakes them into `assets/psx/robots/` (T-posed arms
  swung down, turned to face +x like the beasts, 1 unit tall) with their own textures and glowing eyes and vents; they
  are listed in `voxel_manifest.gd`, and `tools/make_beast_icons.gd` renders their menu icons too.
- **Houses and most shops** are houses from the PS1 House Pack (100 low-poly houses, `tools/import_psx_houses.gd` →
  `assets/psx/houses/`): `house_models.gd` picks one per plot from the town style's list (weatherboard cottages on the
  coast, round thatched huts and stilt houses on the islands, terracotta huts in the desert, log cabins in the
  mountains, dark timber at the hot springs, stone on the moor), re-skins it in the style's own tiles, fits it to the
  plot and lines its front door up with the map's door. A house may lean over the hedges and trees beside and behind
  its plot (never over a walkable tile); those trees are left out. Shops, the dojo, museum and music hall add a
  striped awning and a sign board with their icon; houses get flower planters by the door; locked doors stay crimson.
  The Beast Center is a railcar diner with a curved steel roof and a sign on its roof.
- **Past the map's edge** a ring of scenery nobody can reach keeps every edge and corner hidden: a deep wood to the
  north and sides, only shrubs and rocks to the south (between the camera and the map), the sea running on past
  coasts, roads leading on through exits, and around towns a few larger houses of the town's style among the trees.
- **People, eggs, signs and obstacles** are built procedurally:
  - `voxel_person.gd` builds people with walk animations, including staff uniforms (collar, badge, short sleeves, optional half apron) and staff hats (visor, diner paper hat, headband).
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
| Beasts | Your battle ring (move beasts between its slots), your party and eggs. Each beast's page shows its element(s), its slot, stats, skills, traits and its family tree: the parents and grandparents that were merged into it. |
| Flute | Every song with its effect and mastery; press A to practise one. The Capture page shows your level and when the next one is ready to learn. Unknown songs show where to learn them. |
| Bag | Items grouped as care, battle items, beast gear, trainer gear, sheet music and tomes. |
| Bestiary | All 48 races with live voxel portraits and where to find them. |
| Map | The twelve towns, with the full world map on A. |
| Settings | Music and sound volume, text speed, the gem the menus are cut from, touch pad, key guide, fullscreen, save, credits and quit. |

## UI and audio

- **Cosy PS2-style UI in one colour**: soft rounded windows with a gentle gradient, a pale border and a drop shadow
  (`scripts/ui/cozy_box.gd`), drawn smooth at any screen scale. Every window, border, text, bar, tag and the selected
  row's pill is a shade of one **gem** the player picks in Start → Settings → Gem: **Ruby** (the default),
  **Sapphire**, **Emerald** or **Hematite** (slate grey). `UIKit.set_accent` derives the whole palette from the gem.
- **Fonts**: **BoldPixels** for body text, menus and dialogue; **Lunchtime Doubly So** only for headings (window and
  page titles, tabs' section headers, name plates, map names). Both are drawn on a 16-pixel grid, so every size is
  snapped to one where their pixels land on whole screen pixels (`UIKit.body_px` / `head_px`): on a 1080p screen body
  text is 32 screen pixels and dialogue 48. The desktop window opens at 1920x1080 for the same 1.5x scale as phones.
  Dialogue is three lines to a page. Text sits at the top of every text box.
- **Phones**: the touch pad is a joined cross-shaped d-pad with raised arrows, glossy domed A and B buttons that sink
  when pressed (BoldPixels letters), and Start / Pause pills, all tinted with the gem. While the Start book or the
  world map is open the d-pad and A/B step aside: rows, tabs and towns are tapped, and Start closes the book. The
  book's detail pane scrolls, so a tall page never runs under the buttons, and in battle the command menu takes the
  place of the battle text while it is open.
- The game starts straight into the title screen (no engine splash).
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
- **Obstacles** use `w j d o y l i | x m`, plus `n` (a washed-out footbridge, rebuilt from five logs laid one at a time) and `k` (a cliff that needs a winged beast).
- **Push puzzles**: `u` is a boulder (moves one tile), `e` an ice block (slides), `c` an icy floor. An anchor named `puzzle_exit` marks the tile that counts as solved; `puzzle_area` draws the maze walls plain.
- **Anchors** named `item:<id>` place a fixed item (the footbridge logs; one anchor letter can be used on several tiles, each with its own flag); `inspector`, `warden` and `sentinel` place the road blockers.
- **Story gates** use `&`.
- **Shards** use `*`.
- **Room templates**: in `interior_maps.gd`, `>` and `<` are stairs to the next and previous floor, and `K` is a kennel pen.

- **Towns** follow one plan: a main row of buildings with their backs to the tree line, a boulevard along their doors that the town's entrances lead straight onto, and a plaza with the statue in the middle. Shops sit around the plaza and houses at the ends. Big towns have a second row well to the south, behind deep back gardens (six rows behind two-storey shops).
  - The camera looks down from the south, so a roof, a tower or a tree hides whatever is just north of it. `python tools/town_check.py` traces the camera's line of sight to every walkable tile (with each building's real roof shape) and reports any tile where the path or the player would be hidden, plus any door, exit or person you can't reach.

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
  core/        beast.gd (a beast instance), beasts.gd (creation, merging, legendary dominance), ring.gd (the battle ring)
  gfx/         voxel_mesher (greedy mesher), voxel_beast, voxel_person, voxel_buildings, voxel_props, voxel_textures, voxel_assets
  world/       map_loader.gd (ASCII → map), world.gd (voxel overworld + interiors), map_gen.gd (tile types)
  battle/      battle.gd (ring battles, trainer turn, shields, egg drops), command_panel.gd (the stacked command rows)
  ui/          book_menu (Start book), list menu, dialog box, beast card, flute minigame, controls overlay (key guide / touch pad), pause
  data/        ... chatter_db (what townsfolk, residents, trainers and mascots say)
  autoload/    GameState (save data), Sfx (music + effects), Prefs (settings), UI, Story (quests), Places (shops, centers, music shop, Sky Towers), Menus
tools/         import_psx_beasts.gd, import_psx_robots.gd, make_beast_icons.gd, import_psx_houses.gd, import_psx_*.gd, import_voxel_assets.py, vox2obj.py, build_ui_assets.py, build_patterns.py, convert_audio.py, make_sfx.py, make_icon.py, make_web.py, voxel_lod.py, town_check.py, make_export_presets.py, check_maps.gd, debug/
```

## Developer test modes

```
godot --path . -- --scene=world:cogsworth --shot=C:/tmp/a.png            # screenshot any map (or world:cogsworth#10 for an interior)
godot --path . -- --scene=world:reef --spawn=33,10 --flags=island_peace  # spawn at a tile with story flags set
godot --path . -- --scene=battle --kind=robots --wait=5 --shot=C:/tmp/b.png
godot --headless --path . -- --scene=sim --n=10                          # simulated auto battles
godot --headless --path . -- --scene=flow                                # scripted run through the whole story
godot --path . -- --scene=knock                                         # knock on locked doors (a Tidewater house, the cathedral)
godot --path . -- --scene=skytower                                      # into a Sky Tower, up to the roof and away on the Thunderhawk
godot --path . -- --scene=gallery:nature:0 --shot=C:/tmp/g.png           # voxel asset gallery
godot --path . -- --scene=beasts:0 --shot=C:/tmp/v.png                   # beast gallery (pages 0-3, 4 = merges)
godot --path . -- --scene=world:tidewater --overview=1 --shot=C:/tmp/o.png   # a whole map from high above
godot --path . -- --scene=book:settings --gem=sapphire --shot=C:/tmp/s.png  # try a gem for one run
godot --path . --resolution 2400x1080 -- --touch --scene=battle --shot=C:/tmp/p.png   # a 20:9 phone
godot --path . -- --scene=book:beasts --shot=C:/tmp/m.png               # the Start book on a tab (trainer, beasts, flute, bag, bestiary, map, settings)
godot --path . -- --touch --scene=battle --shot=C:/tmp/t.png            # touch layout
godot --headless --path . -- --scene=tutorial --auto=1                  # Scout Bram's battle lesson through its real menus
godot --headless --path . -- --scene=capture                            # Capture rules, Uncle Rafe's lessons and the arena's flute rule
godot --headless --path . -- --scene=puzzles                            # solves every road puzzle (bridge, cliff, rockslide, ice, checkpoint, warden, sentinel)
godot --headless --path . -- --scene=wilds                              # roaming wild beasts: sneak attack, chase, ambush, flee
godot --path . -- --scene=marks --shot=C:/tmp/k.png                     # the !, blue ! and ? marks
godot --path . -- --scene=ring --keys=a,a,d,d,d --shot=C:/tmp/r.png      # a ring battle driven by keys (a b l r u d); --kind=wild, --foe_level, --foe_shield
godot --path . -- --scene=spiral --kind=ambush --wait=0.6 --shot=C:/tmp/s.png   # the battle spiral (sneak / wild / ambush)
godot --path . -- --scene=tap                                           # tap to walk, double-tap to run, tap to talk / enter
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
