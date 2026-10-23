# Ruby Cocoon: credits

Code, procedural buildings, maps and writing were made for this project.
The downloaded packs themselves aren't kept in the repository (they were in `psx/`, `voxelassets/`, `ui/`,
`music/`, `sfx/`, `new models/` and `new beasts/`): only what the game uses is, converted into `assets/`, plus the two
fonts in `ui/` and the sound effects in `sfx/` the game plays. The licence files the packs came with are in
`licenses/`. To rebuild an asset with its `tools/` importer, download its pack again (the sources are listed below).
**Several packs came without licence files: check each source's terms before releasing the game.**

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
  Tidewater, baked by `tools/import_psx_ferry.gd`). *Changes made:* only the outside kept (the seats and floors
  under its roof, its roof vents, side boards, display stand and waterline ring left out), cut from about 1.5
  million to 4,400 triangles, painted flat colours (it came with no materials). It came with no credit, so it's
  Creative Commons.

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
- **Humble Gift - v1.3** by Humble Pixel (@Humblepixel), https://humblepixel.itch.io: the Start book's pages, their
  ornament frames, arrows and buttons in the Pixel style. Free for commercial use and may be modified; the asset files
  may not be redistributed or resold; credit appreciated, not required. *Changes made:* pieces cut out by
  `tools/build_pixel_ui.gd` into `assets/ui/pixel_ui.res` and turned to tones, so the game paints them dark in the
  player's gem with white lines.
- **1-bit UI** by BatuhanK (`ui/1-bit_UI_byBatuhanK.png`): the Pixel style's windows, plates, bars, stars, hearts,
  shields and round icons. *Changes made:* cut out by `tools/build_pixel_ui.gd` into `assets/ui/pixel_ui.res`, the
  near-black fill painted in the player's gem where something is picked out.
- Fonts: **BoldPixels** (body text, menus, dialogue) and **Lunchtime Doubly So** (headings); licence files not
  included, check the authors' terms.

## Music (`music/` → `assets/audio/music/`, re-encoded by `tools/convert_audio.py`)
Most tracks appear to be by **Kevin MacLeod (incompetech.com)**, licensed under Creative Commons
Attribution 4.0 (http://creativecommons.org/licenses/by/4.0/). Please confirm each one:
Adventures in Adventureland, Ancient Rite, At Launch, Derp Nugget, Desert City, Ether Vox,
Ethernight Club, Farting Around, Half Mystery, Hep Cats, Industrious Ferret, Journey To Ascend,
Magic Scout - Cottages, Magic Scout - Manor, Pleasant Porridge, Poofy Reel, Rising Tide,
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
