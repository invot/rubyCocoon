# Home decor kit: artwork candidate

**Status:** **rev_001 approved by the user as the home decor candidate on 2026-11-12.** Preproduction for runbook **Phase H (037a–037c)**
and 038; **not integrated**. Integration waits for steps 022/023 (material presets, scale sheet), 036/037, the
user's approval of a revision, and Codex's technical review.
**Owner:** Claude's art-candidate lane ([parallel-handoff.md](../parallel-handoff.md)). Codex reviews published
revisions in its own review file and owns integration.

## The brief (the user, 2026-11-12)

- Interiors, especially homes, are not cozy enough. Homes should look lived in, with lots of decor and art on
  their walls. Rooms can be smaller or have notches taken out of them for character, while keeping passages to
  doors clear.
- Make the home assets; they come in a variety of colours, look detailed and cozy, and match the decor.
  Complementary colour schemes cover wall paint, floors and trim.
- The beds and couches are already nice. The lamps and plants are not in line with the visuals.
- Framed artwork in homes **and elsewhere** uses only the supplied recolourable SVG prints. Nothing else.
- `deep-IHWzHs98vQ8` (the rocket) belongs in the player's bedroom.
- One art palette should be bolder: neon or jewel tones.

Decisions taken with the user: deliver a candidate kit plus runbook steps (no game files changed); colour
through tint masks; all homes, with regional touches added in each region block.

## References studied

The two zips (*Cozy Cartoon Rooms Interior 2*, *Interiors Cozy Cartoon Rooms 2*) are OBJ collections without
colour (their texture is blank white); many files are duplicated camera/light rigs. Rendered in clay
(`refs` renders in the session scratchpad), they showed what makes the rooms cozy, and nothing was copied:

- gallery walls: 3–6 frames of mixed sizes and shapes clustered over seating, plus round plates and clocks;
- picture ledges, corner and floating shelves carrying small objects;
- baseboards, crown mouldings and wainscot panels: every wall has trim top and bottom;
- rugs layered under furniture groups, cushions and throws on every seat, baskets and poufs on the floor;
- rooms that are not plain boxes: alcoves, window seats and stair cupboards.

## What rev_001 contains

`build/art_candidates/home_decor/rev_001/` (`READY.json` lists every file, hash, count and the provenance).

| Family | Pieces |
|---|---|
| Lamps | `floor_lamp_drum`, `floor_lamp_tripod`, `table_lamp_gourd`, `table_lamp_mushroom`, `wall_sconce` |
| Plants | `plant_pillow_round`, `plant_pillow_tall`, `plant_paddle`, `plant_blades`, `plant_hanging`, `plant_succulent`, `vase_flowers`, `plant_stand` |
| Wall art and decor | `frame_landscape_large`, `frame_landscape_small`, `frame_portrait`, `frame_portrait_small`, `frame_round`, `woven_plate`, `embroidery_hoop`, `picture_ledge`, `wall_clock`, `mirror_arch`, `floating_shelf`, `tapestry`, `bunting` |
| Trim | `baseboard`, `crown_moulding`, `chair_rail`, `wainscot_beadboard`, `wainscot_panel` (1-unit modules) |
| Soft furnishings | `cushion_square`, `cushion_bolster`, `throw_blanket`, `quilt_fold`, `pouf`, `basket_blankets` |
| Tabletop | `vase_round`, `vase_bud`, `bowl_fruit`, `books_stack`, `candles`, `tea_set`, `photo_standing` |

- **Style.** Plants use the approved tree language (pillowy painted domes, no single leaves); lamps have turned
  wood, ceramic gourds and soft pleated shades; everything is rounded and bevelled. No grain, speckle or
  pixelated texels; every surface is textured (AGENTS.md "Art and animation consistency").
- **Files.** `mesh/home_decor_kit.glb` (one node per piece), `source/home_decor_kit.blend`, `textures/`
  (`decor_atlas.png`, `art_masks.png`, `art_original.png`, `layout.json`, `art_layout.json`), `previews/`.
- **Scale.** One unit is one tile; the hero is 1.44. Floor lamps stand about 1.45, the tall plant 1.36; art over
  a sofa is about two-thirds of its width. Wall pieces' origins sit on their back face.
- **Counts.** 44 pieces, 26,870 triangles in all; the heaviest is `plant_pillow_tall` (2,292), most pieces are
  under 600. Two textures (1024 each) and one material per surface for the whole kit. Per-piece numbers are in
  `READY.json` and on the sheets. No LODs: these are small props seen from one stage camera.
- **Known preview limits.** Wall ends in the Blender previews render as dark strips (preview lighting; the game
  builds its own walls). The game's own sofas and beds keep their current colours in the previews.

## Colours: tint masks and schemes

- **Tint masks.** One 1024 atlas of painted cells. Cells meant to change colour are painted in soft greys; each
  mesh's vertex colour says which tint applies: **R** fabric (shades, cushions, throws, quilts), **G**
  ceramic/accent (pots, vases, clocks), **B** wood (stems, frames, shelves; matches the floor), **A** trim paint
  (painted frames, baseboards, crown, wainscot). Albedo = atlas × mix(1, tint, mask). One material for the whole
  kit, so it batches.
- **Schemes.** `tools/blender/art_candidates/home_decor/schemes.json` holds twelve schemes, each with wall,
  lower wall, trim, floor, rug, fabric, ceramic and accent colours and the room kinds they suit. They pair a
  quiet wall with a complementary fabric and a split-complement ceramic: Seafoam cottage, Apricot sunroom,
  Butter & cornflower, Rose & moss, Lavender & honey, Sky & terracotta, Forest cabin, Mint & cherry, Peach &
  teal, Oat & olive, Dusk study, and the regional Adobe & turquoise. `previews/schemes.png` shows a sofa corner
  in each.

## Framed art: the user's SVG prints

- **Only the user's prints.** 20 SVGs (Unsplash) in `build/art_candidates/home_decor/sources/svg/`. To fit the
  last three into the 20-cell atlas, three were retired at the user's request: `suchi-m-UexejPp9kR8` (it embeds
  PNG images, so it recolours muddily), `pixeliota-9kfPIIHCZNI` (transparent, gradient-heavy) and
  `andrei-castanha-TvP1M-wJzLE` (its gradient sphere loses its shape). They stay in `sources/svg_retired/`.
- **Recolourable at runtime.** `art_masks.py` groups each print's colours into four slots (light to dark),
  renders each slot's coverage with Godot's own SVG renderer, and packs three slots into RGB; the fourth is the
  remainder ("paper"). The shader then paints `slot0×(1−R−G−B) + R×slot1 + G×slot2 + B×slot3`: exact for flat
  fills, and gradients between slots stay gradients. One 1024 texture holds all 20 prints (192×256 cells).
- **Colourways.** Each print gets a colourway per scheme, matched by lightness rank with a minimum contrast
  between slots, so it keeps its light/dark structure in every home; plus **`jewel_pop`** (emerald, sapphire,
  ruby, amethyst, gold, neon pink and cyan on cream with deep indigo ink), the bold palette the user asked for.
  `previews/art_colourways.png` shows every print in its own colours, three schemes and `jewel_pop`.
- **Crops.** Portrait frames use the whole 3:4 cell, landscape frames its centre 4:3 strip, round frames and
  hoops its centre square. A frame shows a different print by moving its canvas UVs to that print's rect.
- **Placements.** `deep-IHWzHs98vQ8` (the rocket) hangs centred over the bed in the player's bedroom
  (`home_bed`). Woven plates are plain weave; the clock face uses dots (no lettering on world objects).

## Previews (candidate renders, not in-game evidence)

- `previews/vignette_*`: three stage rooms from the gameplay camera (world.gd `CAM_OFFSET_ROOM`, fov 44) with
  the game's own sofas, beds, nightstands, dresser, wardrobe, bookshelf, windows and doors (exported unchanged
  to `build/art_candidates/home_decor/refs/`): a living room, a bedroom (the player's, with the rocket print)
  and a den with an alcove and a notched corner, each in two schemes.
- `previews/lineup_lamps_plants.png`: the game's current lamps and plants beside the new ones and a 1.44 hero
  marker.
- `previews/sheet_<family>.png`: every piece with its triangle count and size.

## Integration (Codex), in short

Runbook 037a imports the kit and adds the shared tint/print shader, replaces lamps and plants everywhere and
dresses homes; 037b turns the schemes into data and adds trim; 037c adds notches and alcoves with the route
rules; 038 composes Reference 3. Smooth `decor_atlas.png` once; never smooth `art_masks.png`. Credit the
Unsplash artists in `CREDITS.md` as a courtesy (the Unsplash License needs no attribution).

## Revisions

| Revision | Published | Notes |
|---|---|---|
| rev_001 | 2026-11-12 | First kit: 44 pieces, 12 schemes, 20 prints with scheme and `jewel_pop` colourways. **Approved by the user as the candidate on 2026-11-12** |

Published revisions never change; corrections go in the next revision.
