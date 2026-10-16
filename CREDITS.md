# Ruby Cocoon: credits

Code, procedural voxel beasts, people and buildings, maps and writing were made for this project.
Third-party assets live in their original folders (`voxelassets/`, `ui/`, `music/`, `sfx/`);
the game uses converted copies in `assets/`. **Several packs came without licence files: check
each source's terms before releasing the game.**

## PSX art (`psx/` → `assets/psx/`)
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
  (cask, crate, banner, torch, round pillar).
- **PSX Western Town Kit Free** by heyheythere - https://heyheythere.itch.io/psx-western-town-kit-free - CC BY 4.0
  (tumbleweed).
- **PSX The Island Pack** by Caliber Creations, https://caliberuk.itch.io/psx-the-island-pack (palms, beach
  plants, rocks). Free for games, including commercial ones; the raw files may not be redistributed.

## Voxel art (`voxelassets/` → `assets/voxel/`)
See `assets/voxel/CREDITS.md` for the full list. Highlights:
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
- Fonts: **Ticketing** and **BoldPixels** (licence files not included; check the authors' terms).

## Music (`music/` → `assets/audio/music/`, re-encoded by `tools/convert_audio.py`)
Most tracks appear to be by **Kevin MacLeod (incompetech.com)**, licensed under Creative Commons
Attribution 4.0 (http://creativecommons.org/licenses/by/4.0/). Please confirm each one:
Adventures in Adventureland, Ancient Rite, At Launch, Derp Nugget, Desert City, Ether Vox,
Ethernight Club, Farting Around, Half Mystery, Industrious Ferret, Journey To Ascend,
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
