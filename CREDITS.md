# Ruby Cocoon: credits

**Cocoon Cove layout proposals:** *Towns* and *WholeHouseFBX* by
[loafbrr](https://sketchfab.com/loafbrr), CC BY 4.0. Extracted scenery meshes, LODs,
resized and smoothed textures. See [source links and licence](licenses/pirate_cove.md).

Code, procedural buildings, maps and writing were made for this project.
The supplied fences replace the former PSX fence meshes and Bellerive's procedural garden ironwork:
**Low Poly wood fence on grass** by cattleya (CC BY 4.0), **Iron Fence** by BaseCubeRo
(CC BY-NC-SA 4.0), and the supplied **Low Poly stone fence on grass** archive (no creator or license included).
Display lawns were removed, reusable sections fitted to tiles, and textures smoothed.
See [source details, embedded licenses and conversion notes](licenses/supplied_fences.md).
The procedural exterior windows (`scripts/gfx/cartoon_windows.gd`) use the supplied **Stylized Cartoon Windows**
by Canino3d and **Windows Pack** by Midox as visual references. Both identify CC BY 4.0 in their GLB metadata;
no meshes or textures from either pack are redistributed. See [window reference provenance](licenses/window_references.md).
Kelpwick's stilt huts are adapted from the user-supplied **Low poly stylized tribal tropical hut** archive:
its mesh and painted wood, plaster, windows and thatch, with pastel plaster, solid wooden doors, stilts and stairs.
The wooden fences share the huts' painted timber texture.
See [source details and conversion notes](licenses/tribal_hut.md).
Kelpwick's arena uses **Stylized House** by [Kesenkai](https://sketchfab.com/kesenkai),
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), supplied as `stylized_house.glb`.
The TV antenna and original door are removed; the model is fitted to its plot and given the huts' solid wood door.
See [source and conversion details](licenses/kelpwick_arena.md).
The procedural harbour pleasure boats and shallow-water footstep sounds (`tools/make_sfx.py`) are original project assets.
The battle mural textures (`assets/battle/backdrops/`) are rendered derivatives of the regional scenery already
credited below, baked by `tools/bake_battle_backdrops.gd` and passed through the shared smoothing pipeline.
See [battle backdrop provenance](licenses/battle_backdrops.md). The translucent yellow targeting arrow is original procedural geometry.
The pre-baked battle ring graphics (`assets/ui/battle/`) and encounter sweeps (`assets/audio/battle/`) are generated
from the project's existing battle and sound code by `tools/bake_battle_art.gd`. House measurements
(`assets/houses/measurements.res`) are geometry metadata derived from the credited house models below; their meshes
and textures are unchanged.
The downloaded packs themselves aren't kept in the repository (they were in `psx/`, `voxelassets/`, `ui/`,
`music/`, `sfx/`, `new models/` and `new beasts/`): only what the game uses is, converted into `assets/`, plus the two
fonts in `ui/` and the sound effects in `sfx/` the game plays. The licence files the packs came with are in
`licenses/`. To rebuild an asset with its `tools/` importer, download its pack again (the sources are listed below).
**Several packs came without licence files: check each source's terms before releasing the game.**

## Supplied stylized environment collections

- **Environment Pack - Stylized Nature**, **Environment Pack - Grass**, and **Environment Pack - Stylized Rock**,
  supplied by the user as three ZIP archives. No author, source URL or license document was included in those
  archives; no license or creator is inferred. See `licenses/supplied_environment_packs.md` for the provenance record.
  `tools/prepare_stylized_nature.py` extracts selected showcase objects; `tools/import_stylized_nature.gd` preserves
  their normals/UVs, centers and normalizes them, bakes their textures, and generates LODs. Some yellow foliage is
  recolored green. Grass uses the pack's simpler solid-blade clumps. The shared texture smoothing pass supplies the game's soft finish. Original downloads are untouched.

## Western packs (Dustwell Oasis and the desert roads)

- **Stylized Desert Cliffs Asset Pack**, **Low Poly Western**, **Western Pack: Hand Painted House Set (Low Poly)**,
  **Western Town Buildings LowPoly Package**, **Western Saloon** and **Western Diorama - Low Poly**, supplied by the user
  as six ZIP archives of OBJ and PNG files. None names an author or a licence, so (the user's rule) they are recorded
  as Creative Commons; see `licenses/supplied_environment_packs.md`.
- `tools/import_western.gd` bakes the covered wagon and water trough of Low Poly Western, painted by part, into
  `assets/exteriors/wagon.res` and `water_trough.res`. The cliff pack was tried and dropped (the desert keeps the
  terrain's own cliffs). The other packs were the reference for Dustwell's
  buildings (false fronts, boardwalk porches, the saloon's balcony and batwing doors, the barred jail), which
  `scripts/gfx/frontier_builder.gd` builds from the game's own wall pieces. Original downloads are untouched.

## Cliff textures (`assets/textures/surfaces/cliff_*.png`)

The cliffs themselves are the terrain's own, built from the maps' heights (`scripts/world/terrain_mesh.gd`); these
packs only gave their rock its texture. `tools/import_cliffs.gd` crops a stretch of rock face from each pack's
colour texture, turns it grey (the game colours it per biome, `WorldDB.CLIFF_LOOKS`), makes it tile seamlessly and
bakes it at 512 px or less; `tools/smooth_textures.gd` then softens it. No meshes are used. Original downloads are
untouched.
- **Sandstone | Cliff** by YadroGames (https://sketchfab.com/erroratten), licensed under CC BY 4.0
  (https://creativecommons.org/licenses/by/4.0/), in two versions:
  https://sketchfab.com/3d-models/sandstone-cliff-f525eb2600e34f78b6e2811d678ce246 (`cliff_rock.png`, the warm
  fluted rock of the coast, rivers and jungle) and
  https://sketchfab.com/3d-models/sandstone-cliff-49722e53941c46339b0cfd74bfcb5669 (`cliff_sandstone.png`, the
  desert, western and mesa cliffs).
- **Stylized Cliff-Faces**, supplied by the user as a ZIP of OBJ and PNG files (`cliff_slate.png`, from
  `CliffFaces_Set01_Diffuse.png`: the mountain, volcano, hot spring, moor and steampunk cliffs). It came with no
  credit, so it's Creative Commons; see `licenses/supplied_environment_packs.md`.
- Looked at and not used: **[Free] Layered Cliffs** by SimplePolygon (CC BY 4.0), **Cliff_Stylized** by acipa1234
  (CC BY-SA 4.0) and **Modular cliff** (supplied as a ZIP, no credit).

## PSX art (`psx/` → `assets/nature/`, `props/`, `boats/`, `robots/`, `houses/`, `exteriors/`, `interiors/`, `textures/surfaces/`)
The low-poly PS1-style world. The packs were downloaded into `psx/` (not part of the game; see
`psx/Jade Coccon index.csv`). `tools/build_psx_textures.gd` and `tools/import_psx_models.gd` make the
copies the game uses. *Changes made to all of them:* textures shrunk to 128 px or less and, for the
surface textures, turned grey so the game can colour them per town and biome; some models brightened,
desaturated or recoloured; each model's meshes merged into one, with automatic levels of detail.
- **3D Retro Medieval/Fantasy Building Kit** by chilly_durango, CC0,
  https://chilly-durango.itch.io/medieval-building-parts (wall, wood, cobble and paving textures).
- **Mini Texture Pack 2: Rooftops** by Screaming Brain Studios, CC0,
  https://screamingbrainstudios.itch.io/mini-texture-pack-2-rooftops (roof and bamboo textures).
- **RetroGround Free** by Binbun3D, licensed under CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/),
  https://binbun3d.itch.io/retroground-free (ground textures).
- **FOXTEX** by Foxhead, CC0, https://foxh3ad.itch.io/foxtexcom (water and lava animation frames).
- **Retro PSX Style Tree Pack** by Elegant Crow, CC0, https://elegantcrow.itch.io/psx-retro-style-tree-pack (trees).
- **PSX Forest Free** by heyheythere - https://heyheythere.itch.io/psx-forest-free - CC BY 4.0
  (bushes, fern, boulder, dead tree, stump, fence, log, campfire).
- **PSX Cemetery Kit Free** by heyheythere - https://heyheythere.itch.io/psx-cemetery-kit-free - CC BY 4.0
  (headstones, celtic cross, tomb, gas lamp, iron gate, stone wall and pier).
- **PSX Castle Kit Free** by heyheythere - https://heyheythere.itch.io/psx-castle-kit-free - CC BY 4.0
  (cask, crate, banner, torch, round pillar; a door and banners for a castle-keep
  arena, no longer in the game).
- **PSX Western Town Kit Free** by heyheythere - https://heyheythere.itch.io/psx-western-town-kit-free - CC BY 4.0
  (tumbleweed).
- **PSX The Island Pack** by Caliber Creations, https://caliberuk.itch.io/psx-the-island-pack (palms, beach
  plants, rocks, rowboats). Free for games, including commercial ones; the raw files may not be redistributed.
- **Ferry**, a passenger motor boat in 35 OBJ parts downloaded into `psx/ferry/` (Captain Gull's ferry at
  Bellerive, baked by `tools/import_psx_ferry.gd`). *Changes made:* only the outside kept (the seats and floors
  under its roof, its roof vents, side boards, display stand and waterline ring left out), cut from about 1.5
  million to 4,400 triangles, painted flat colours (it came with no materials). It came with no credit, so it's
  Creative Commons.
- **Water Temple Island**, a temple on an island in 22 OBJ parts downloaded into `psx/water_temple/` (the Temple of
  Tides, baked by `tools/import_psx_tide_temple.gd`). *Changes made:* only the temple kept (the island, its trees and
  rocks, the sea dome, the courtyard's carved paving, the fountain's jet, the roof's fretted rim, the grand stair and
  the foundation below ground left out), cut from about 80,000 to 5,300 triangles, and laid with the game's own mossy
  stone textures (it came without materials); a gatehouse and plants are added in the game. It came with no credit, so it's
  Creative Commons. A Minecraft jungle temple pack, downloaded at the same time, was used only as a layout reference.

### Towns and buildings (`assets/houses/`, `assets/exteriors/`, `assets/interiors/`)
Made by `tools/import_psx_houses.gd`, `tools/import_psx_exterior.gd`, `tools/import_psx_interior.gd`,
`tools/import_psx_furniture.gd` and `tools/import_psx_phones.gd`.
*Changes made:* models merged, centred, turned to face one way and scaled to the game's people; textures shrunk to
128 px or less; houses re-skinned per town from the pack's own tiles; wall sections split so each building's own wall
finish shows through; counters, booths and street furniture stretched to fit their tiles; the furniture pack's
untextured pieces cut out of its showrooms, sized to their tiles and coloured part by part (frames, bedding,
upholstery) over a wood grain and cloth weave of our own.
- **PS1 House Pack - 100 Low Poly Houses, Textured Inside and Out** by najjar320,
  https://najjar320.itch.io/ps1-house-pack-100-low-poly-houses (the houses and shops). Free for commercial use; credit
  appreciated, not required; the files may not be redistributed.
- **PSX modular house interior pack** by DissonantVoid, https://dissonantvoid.itch.io/psx-retro-interior-pack
  (kitchens, bathrooms, wardrobes, shelves, lamps, ornaments, doors, windows, wall and floor textures). Free for
  commercial use; the files may not be redistributed.
- **Furniture pack** by Anker's Assets, CC0, https://ankersassets.itch.io/ (six OBJ showrooms, `model_0.obj` to
  `model_5.obj`, with no textures, downloaded into `psx/furniture/`: the beds, bunk beds, sofas, armchairs, chairs,
  tables, desks, nightstands, dresser, TV stand and bench).
- **Antique 1930s Rotary Telephones** by Mad_Lobster_Workshop (https://sketchfab.com/Mad_Lobster_Workshop),
  https://sketchfab.com/3d-models/antique-1930s-rotary-telephones-c08787c11a494006afbc50a435e7c4c8, downloaded as
  `psx/phones/antique_1930s_rotary_telephones.glb` (the red phone in homes, Beast Centers, shops, arenas and temple
  doorways, baked by `tools/import_psx_phones.gd`). *Changes made:* the red one of the five taken, its cord left off,
  cut from about 9,600 to 600 triangles, its texture replaced by flat colours sampled from it. The file's licence
  says only "COPYRIGHT TO Mad_Lobster_Workshop": **check the terms before release.**
- **Old public telephone** ("telefone publico antigo"), downloaded into `psx/phones/source/` with its textures (the
  payphone by each town's square, on a post and hood of our own, baked by `tools/import_psx_phones.gd`). *Changes
  made:* its cord left off, its orange painted red, cut from about 18,600 to 500 triangles, flat colours sampled from
  its textures. It came with no credit, so it's Creative Commons.
- **Retro Modular House Pack** by Elegant Crow, CC0, https://elegantcrow.itch.io/retro-modular-house-pack (wall
  sections with doors, windows and shutters: shop fronts and the landmarks).
- **DINER**, **6TWELVE** and **Trailer Park** by Elbolilloduro, https://elbolilloduro.itch.io (shop counters, diner
  booths and tables, coffee machines, kitchen appliances, lamps, plants and ornaments). Free for commercial use; the
  files may not be re-uploaded.
- **PSX Mall Kit Free** by heyheythere - https://heyheythere.itch.io/psx-mall-kit-free - CC BY 4.0 (the till).
- **PSX Building Kit Free** by heyheythere - https://heyheythere.itch.io/psx-building-kit-free - CC BY 4.0 (chimney).
- **Retro 3D Assets Pack - Urban Props #1**: 3D Model by Conor McKenna (CyberThreat/Aphelios),
  https://cyberthreat.itch.io/retro-3d-style-assets-pack-1-urban-props, licensed under CC BY 4.0
  (https://creativecommons.org/licenses/by/4.0/) (benches, bins, hydrants, air conditioners, dumpsters).
- **PSX Dungeon Boxes and Barrels Pack** by Games by McSteeg, https://mcsteeg.itch.io (crates and barrels). Free for
  commercial use; the files may not be redistributed.
- **PSX style modular hedges** by valsekamerplant, CC0, https://valsekamerplant.itch.io/psx-style-hedges.
- **Stasis Chamber** by KieranEdwards (https://sketchfab.com/KieranEdwards),
  https://sketchfab.com/3d-models/stasis-chamber-0d09b5d0355d4727bd601015f394de3f, licensed under CC BY 4.0
  (https://creativecommons.org/licenses/by/4.0/) (the Beast Centers' healing machine, downloaded as
  `psx/stasis_chamber.glb` and baked by `tools/import_psx_stasis.gd`). *Changes made:* cut from about 18,500 to
  2,900 triangles; normal and metal maps left off; textures shrunk to 128 px; the glass made to glow while it heals;
  a lamp per beast added round its foot.
- **FREE Castle and Fort Builder Pack** by Games by McSteeg, https://mcsteeg.itch.io/castle-and-fort-builder-pack
  (walls, round towers, battlements, cone roofs and windows for a castle-keep arena, the rubble stone warmed to
  sandstone; no longer in the game). Free for personal and
  commercial games; may not be redistributed as your own.
- **FREE PSX Alone in the Dusk** by EmaceArt (Maciej EmacArt),
  https://emaceart.itch.io/alone-in-the-dusk-psx-environment-asset-kit (a rooftop billboard and a utility pole for the
  electronics shop; no longer in the game). EmacEArt Asset
  License: free for personal and commercial use, credit not required; the files may not be resold or passed on as
  standalone files.

### Beasts (`assets/psx/beasts/`, made by `tools/import_psx_beasts.gd` and `tools/make_beast_icons.gd`)
*Changes made:* models turned, centred and scaled to one size; textures shrunk to 128 px; every model is
recoloured in the game with each beast's own colours (and its menu icon rendered from it and recoloured the same way).
- **Everything Library 01 - Animals** by David OReilly, https://davidoreilly.itch.io/everything-library-animals
  (most of the beasts).
- **LowPoly Animated Monsters** by Quaternius, CC0, https://quaternius.itch.io/lowpoly-animated-monsters
  (the dragon and the slime).
- **PS1/PSX Fish Pack** by CursedLake, https://cursedlake.itch.io/ps1psx-fish-pack (clownfish, catfish, perch).
- **Fish - PolyPack Asset** by ALSTRA INFINITE, https://alstrainfinite.itch.io/fish (the shark).
- **PS1/PSX style alpaca & capybara models** by obliviist,
  https://obliviist.itch.io/ps1psx-style-alpaca-capybara-models.

### Robots (`assets/robots/`, made by `tools/import_psx_robots.gd` and `tools/make_beast_icons.gd`)
*Changes made:* models merged, turned, centred and scaled to one size; the T-posed arms swung down to the sides;
textures shrunk to 128 px; menu icons rendered from them.
- **Retro Robots without Rig - PSX Asset** by Bricchi Games, https://bricchi-games.itch.io/retro-robots, licensed
  under CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/) (Clockwork Sentry, Steam Mecha, Iron Golem).
- **Low poly Robot guy** by CokeEnthusiast, https://cokeenthusiast.itch.io/low-poly-robot-guy (Tank Walker). No
  licence is given on the page, and the author notes its texture was made with ChatGPT: check before release.

### Townsfolk and the hero (`assets/townfolk/`, made by `tools/import_townfolk.gd`)
*Changes made:* the kit's 80 people split into their parts (each distinct piece kept once) and rigged on one
skeleton of our own, weighted by where each part sits on the body; the legs drawn longer and the heads smaller;
recoloured by a shader (skin, hair, eyes, clothes) from each person's look, the kit's own colours kept on the
details; whites added to the eyes. The game poses the skeleton itself (walk, run, idle, talk, sit).
- **Townfolk collection** (a stylized characters kit; its texture is `65588_STYLIZED_CHARACTERS_TEXTURE.png`),
  downloaded into `new models/townfolk collection/`. Its author, source and licence still need recording here:
  check before release.
- The trainers' camo jacket (collar, belt, padded sleeves and trousers) is made by `tools/import_townfolk.gd` on the
  kit's own pieces, after the look of the "camo-jacket duo" models in `new models/camo-jacket duo/` (none of their
  meshes or textures are used).
- **Backpacks** (`new models/backpack/`): eight of its packs and bags, turned to sit on the back, scaled to the
  townsfolk, coloured (the pack has no textures) and given shoulder or cross-body straps of our own. Its author,
  source and licence still need recording here: check before release.

### People, before the townsfolk (`assets/psx/people/`, made by `tools/import_psx_people.gd`; no longer used)
*Changes made:* textures shrunk to 256 px; each face moved onto a front-facing texture of its own with anime eyes
painted in; the hero's texture repainted (red jacket over a white shirt, belt, jeans, red sneakers). The game poses
the skeletons itself.
- **Characters PSX** by Elbolilloduro, https://elbolilloduro.itch.io/characters-psx (the townsfolk, Beast Center
  staff and Umbral Legion). Free for commercial use; the files may not be re-uploaded.
- **Male Character | PSX / PS1** by yugg0, https://yugg0.itch.io/male (the hero), on a base mesh by Vinrax.

## Hatchery cinematic (`assets/interiors/hatch_*`)

- **Sci-Fi Platforms** — user-supplied `Sci-Fi Platforms.zip`: the lower platform, with its source UVs and texture.
- **TCM Core (Virlance)** — user-supplied `TCM Core (Virlance).zip`: the overhead core and its three articulated tongs.

The stone vault, lanterns and the core's column of metal and wires are original to this project, built and painted
by `tools/hatchery_chamber.gd`.

*Changes made:* selected geometry centred and scaled, source material bindings rebuilt (the archives contain no
MTL files), the core recoloured to bronze and the platform to stone and brass, meshes simplified, textures filtered
through the game's smoothing pipeline, and lights, fog, the core's inner light and the tong animation added. `tools/prepare_hatchery.py` and
`tools/import_hatchery.gd` reproduce the bake. Author/source-page and licence metadata were not included in these
archives; see `licenses/hatchery_assets.md` for the provenance record and outstanding attribution fields.

The merge cinematic's chamber (`assets/interiors/hatch_roundels.res`) uses the walls, ceiling and ceiling cables of
*War Doctor's TARDIS Interior (Old)*, with its floor, glass, console, struts and doorway removed. Its plaster is
the Beast Centers', its flagstones continue the hatch's, and its bottle-bottom glass and corner columns are made by the bake.
That archive also included no author, source page or licence. The film's TCM Cores are simplified, white-and-steel
repaints of the hatch's.

## Voxel art (`voxelassets/`; no longer in the game)
The voxel models were all replaced by the PSX ones above and removed. They came from, among others:
- **StickyBizcuit**: village/dungeon pack. The required easter egg is the hidden NPC "Bizcuit" in the
  north-west corner of Cocoon Cove, plus the book "Building Worlds One Cube at a Time".
- **Kytric**: Voxel Path and Terrain (CC0).
- **Maria Starko** and other free samples (see the voxel credits).

## UI (`ui/` → `assets/ui/`, built by `tools/build_ui_assets.py`)
- **Complete UI Book Styles Pack (Free), Travel Book Lite** by Crusenho Agus Hennihuno,
  https://crusenho.itch.io. *Changes made:* sprites cropped and scaled up for the menus.
- **Fantasy RPG UI Pack (Demo)** by dobo_ui, https://dobo-ui.itch.io/fantasy-rpg-ui-pack.
  *Changes made:* pixelated and recoloured to the TravelBook palette (dialogue scroll, name plate,
  ribbons, buttons, toggles, arrows, icons).
- **set1 / set2** pixel UI sheet (bars, stars, crests): author not included with the files.
  *Changes made:* crest gems recoloured per arena.
- **Fantasy UI Borders** by Kenney (https://kenney.nl), CC0 (`licenses/Kenney Fantasy UI Borders - License.txt`):
  every window's, row's and item slot's border and the section divider (`assets/ui/kenney/`: panel-border-010, -008,
  -001 and divider-003, the pack's white line art). *Changes made:* none to the files; `scripts/ui/frame_box.gd` draws
  them as nine-patches over the blurred box.
- Fonts: **League Spartan** by The League Spartan Project Authors (interface text and painted signs), from Google
  Fonts under the SIL Open Font License (`licenses/League Spartan - OFL.txt`), unchanged;
  **Lunchtime Doubly So** (the original 3D intro/title logo); licence file not included, check the author's terms.

## Music (`music/` → `assets/audio/music/`, re-encoded by `tools/convert_audio.py`)
*Pennsylvania Rose* by **Kevin MacLeod** (album *Scoring: Aspiring*, 2007, per the supplied MP3's metadata)
is Cocoon Cove's town theme. User-supplied source: `Pennsylvania Rose.mp3`; game copy:
`assets/audio/music/pennsylvania_rose.mp3` (128 kbps, 44.1 kHz). No licence accompanied this file;
its licence still needs recording.

Most tracks appear to be by **Kevin MacLeod (incompetech.com)**, licensed under Creative Commons
Attribution 4.0 (http://creativecommons.org/licenses/by/4.0/). Please confirm each one:
Adventures in Adventureland, Ancient Rite, At Launch, Derp Nugget, Desert City, Ether Vox,
Ethernight Club, Farting Around, Half Mystery, Hep Cats, Industrious Ferret, Journey To Ascend,
Magic Scout - Cottages, Magic Scout - Manor, Nerves (the title screen), Pleasant Porridge, Poofy Reel, Rising Tide,
Rising Tide (faster), Screen Saver, Unanswered Questions, Wholesome, Wind of the Rainforest
(trimmed to a 5-minute loop).

From Pixabay (Pixabay Content License):
- "The Return of the 8-bit Era" by DJARTMUSIC
- "Retro Egyptian Theme" by Howling Hound Music
- two "Retro Arcade Game Music" tracks by Monume

## Sound effects (`sfx/`)
Menu, combat, pickup, environment, feedback, transition, creature and magic effects, plus the
BitCrushHits, Coin, Explosion, Hit, Jump, PowerUp, Select, Shoot, RetroTextures and UI Samples packs.
Sources and licences were not included with the files: check them before release.

### Sonniss GDC 2026 (`assets/audio/sfx/`)

- **Cinematic Sound Design — Paper Foley**: *Encyclopedia Glossy Page Turn Muted* (book and battle page turns).
- **Epic Stock Media — Fantasy Game 2 — Sound Kit for Enchanted Realms**: *Action Inventory Open Flip Cloth
  Canvas Bag Slide Light 02* (opening beast arrangement).
- **CB Sounddesign — APPlicable Sounds**: *Kalimba 3 Up* (gifts, ring placement and attaching bait).
- **Cinematic Sound Design — User Interface**: *Interface Plucks Happy* (healing).
- **Cinematic Sound Design — Hybrid Game & UI Elements**: *Foley Coin Flip Single Fast* (payments).
- **Epic Stock Media — HD Lock And Mechanism Sound Design Kit**: *Click Deep Mechanism Latch Button Nearfield
  Thunk 02* (puzzle levers and the hatchery mechanism).
- **Alexander Kopeikin — Emotion and Magic**: *magic, energy flow, astonishment-001* (merging/evolution,
  shrine ritual and departing summons; 3.4-second excerpt).
- **344 Audio — Cinematic Fight Vol. 1**: *4 x Punch, Body 02* (ordinary battle impacts; first punch, 0.6 seconds).
- **Cinematic Sound Design — Ultra Transitions & Impacts**: *Woosh Sweep Slide Infographics Basic* (missed attacks).
- **Cinematic Sound Design — Interface & Infographics**: *Interface Accept Glassy Snap* (menu confirmations),
  *Interface Pop High Short* (0.075-second dialogue syllable, with the game's per-speaker pitch variation
  plus the approved three-semitone lift).
- **Cinematic Sound Design — UI Interaction Elements**: *Deny Muted* (unavailable or invalid actions, and failed
  capture, flute and fishing attempts).
- **Just Sound Effects — Rocky Coast of Norway**: *Soft Waves Cliffs* (Shellhaven surf).
- **344 Audio — East Coast America Vol. 1**: *Forest Crickets, Birds, Connecticut 02* (Coastal Path nature).
- **Cinematic Sound Design — Sci-Fi Drones**: *Roomtone Space Ship Interior Muted* (Gearhart Tower and intro).
- **CB Sounddesign — APPlicable Sounds**: *Bird Flutes 3* (egg reveal).
- **InMotionAudio — USA Hotel**: *USALightSwitch On05* (settings toggles and pause opening).
- **Jake Fielding — Cinematic Horn Braams**: *Huge-32* (0.8-second boss-encounter variation).
- **344 Audio — Ghostly Presences Vol. 1**: *Evil Spell Ambience* (moor exteriors).
- **Epic Stock Media — Strange Game Ambient Loops 3**: *Dark Loop Mystic Forest Tonal Steady Synth*
  (cathedral interiors).
- **Alexander Kopeikin — Emotion and Magic**: *magic, energy flow, astral travel-015* (merge cinematic swell; 4.2-second excerpt).
- **Epic Stock Media — Elemental Mutation Whooshes and Impacts**: *Impact Electric Tonal Deep Movement Motion Hiss
  Glitch 01* (merge cinematic, beasts vanishing; 2.4-second excerpt).
- **Epic Stock Media — Fantasy Game 2 — Sound Kit for Enchanted Realms**: *Magic Light Spell Enchantment Potion Effect
  Tonal Bright 03* (merge cinematic reveal; 3-second excerpt).

User-supplied Sonniss.com GDC 2026 Game Audio Bundle, under the
[Sonniss GDC bundle licence](https://sonniss.com/gdc-bundle-license/).
*Changes made:* gain adjusted and converted to 44.1 kHz stereo Ogg Vorbis. Approved excerpts, edge fades and
the five ambient loops' one-second crossfades are recorded in the conversion manifest.
See `licenses/sonniss_gdc2026.md` and `tools/sfx_sources.json` for provenance and conversion details.

### Existing game audio reused (`assets/audio/sfx/`)

*Environment_CrateBreak_001.mp3*, formerly the hatch reveal, now supplies the approved 0.22-second
critical-hit excerpt, with a fast decay and gain adjustment. Its original source and licence remain part of the
unidentified existing SFX collection above; this recording did not come from the Sonniss bundle.

*Dread_Hit.wav*, generated by the game's `tools/make_sfx.py`, supplies a second boss-encounter variation:
a 0.7-second excerpt with a shortened tail. The complete intro dread hit remains unchanged.
