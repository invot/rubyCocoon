# Battle mural artwork

`assets/battle/backdrops/*.png` contains 14 repeating, rendered mural textures for the regions in
`scripts/data/world_db.gd` (`BIOMES`). `tools/bake_battle_backdrops.gd` renders the existing, game-ready scenery
chosen by those definitions; `tools/smooth_textures.gd` supplies their soft finish and mipmaps.
The original downloaded packs are not modified or copied into this folder.

These are rendered derivatives, retaining the attribution and terms of their source assets in [CREDITS.md](../CREDITS.md):

- **Retro PSX Style Tree Pack**, Elegant Crow, CC0 — trees.
- **PSX Forest Free**, heyheythere, CC BY 4.0 — dead trees, stumps, woodland rocks and logs.
- **PSX Cemetery Kit Free**, heyheythere, CC BY 4.0 — headstones and tombs in the moor background.
- **PSX Castle Kit Free**, heyheythere, CC BY 4.0 — barrels and crates in the steampunk background.
- **PSX Western Town Kit Free**, heyheythere, CC BY 4.0 — tumbleweed.
- **PSX The Island Pack**, Caliber Creations — palms and beach rocks; the existing project credit records its game-use terms.
- The cacti and the simple landscape colours are original project procedural artwork.

The source selections are recorded by `WorldDB.BIOMES` and `scripts/data/voxel_manifest.gd`; the original model
import paths and conversion options are in `tools/import_psx_models.gd`. No new third-party download is introduced.
