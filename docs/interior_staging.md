# Interior staging

Ruby Cocoon's interiors use an end-on stage: the audience is the gameplay camera south of the room, looking north.
Upstage means the north/back wall; downstage means the open south/front edge. These are game layout rules adapted
from theatre practice, rather than a claim that theatre always requires furniture to face straight forward.

## Research basis

The [American Association of Community Theatre's set designer guidance](https://aact.org/set-designer) calls for
sets that support entrances, movement, the production's style and the audience's understanding of the setting.
[David Vegh's Theatre Blocking 101, published by the Educational Theatre Association](https://dramatics.org/blocking-101/)
connects readable stage pictures with clear focus, varied spacing, angles and sightlines. His advice to inspect
the picture from the audience is especially useful for this game's fixed camera.

The rules below translate those principles into cardinal tile movement, small rooms and a single camera.

## Arrangement rules

1. **Compose from the camera.** Judge the room from its actual gameplay view, including a wide phone. A correct
   floor plan alone is insufficient. Show useful faces, cushions, shelves and displays, rather than furniture backs.
   Preserve the existing cutaway walls, windows, room scale and regional materials.
2. **Keep lounge seating open.** Furniture against a side wall faces inward towards the room's center. Rear-wall and
   freestanding sofas and armchairs face south towards the camera. In a living room, assume the
   television is against the omitted fourth wall on the camera side; do not draw a rear-wall TV or orient seating
   towards one. Prefer the sofa upstage, with a low coffee table downstage and an open tile between them. Small
   armchairs can occupy a side wing and face across the room. Do not put an armchair across the foreground of a bedroom.
3. **Put height behind the action.** Bookcases, stock shelves, wardrobes, refrigerators and bunks belong at the back
   or side walls. In compact stage rooms, their footprints must touch the back furniture row or a side furniture
   column. Place organs and columns there too. Use low displays in the middle or foreground; do not use fading as
   a substitute for arranging ordinary rooms well.
4. **Make functional groups.** Pair beds with their headboards against a wall and nightstands beside their heads;
   keep desks with chairs and coffee tables with lounge seating. Dining and desk chairs face the adjacent table,
   either in profile or towards the audience. Avoid a chair downstage of its table looking north. Neutral tables
   and rugs have no required facing. Keep the existing furniture scale and matching upholstery.
5. **Give each room a readable focus.** Service rooms focus on their staff and counter; living rooms on their seating;
   bedrooms on the bed; galleries on their exhibits. Show display beasts facing the camera. Frame important people
   with scenery instead of placing columns directly in front of them. Retain each room's purpose and identity.
6. **Leave a playing area and entrances.** Keep at least a tile-wide connected route between entrances, room doors,
   stair approaches and essential interactions. Respect NPC occupancy, counters and the existing movement rules.
   Leave service staff enclosed behind their counters, patrons reachable, phone stands approachable and stair
   landings clear. The Sky Tower ticket desk is a straight counter with open ends; keep Aria behind its front
   row and the red staff door clear. Existing map checks remain authoritative for reachability and tutorial sightlines.
7. **Open people towards the audience.** Standing residents prefer south, or a side if a visible wall prevents it.
   Seated patrons face their table. Keep story characters' authored facing, automatic lessons and roaming intact.
   Talking and movement can still turn people naturally.
8. **Keep motivated exceptions.** Music-hall and cathedral audience benches face the performance or altar; their low
   silhouettes leave the room visible. Arenas retain their ring and spectators around it. Dungeon columns, mist,
   obstacles and stairs retain their authored navigation and encounters; inspect their whole layout and retain
   existing occluder fading. These exceptions do not justify obstructing ordinary houses or shops.
9. **Dress homes generously, service rooms with restraint.** Small books, cups and lamps belong on existing surfaces.
   Homes look lived in (the user's direction, 2026-11-12): art and decor on the walls, cushions and throws on the
   seating and beds, a lamp beside each seating group and bed, plants in corners. The tile in front of every door
   and both stair ends stays empty, and a one-tile route still links every entrance and interaction. Shops and
   service rooms keep their seeded dressing on counters and perimeter shelves, with an open central floor.
   Keep merchandise displays to the sides and café/saloon seating in small side groups; do not add tall clutter near service staff's faces or essential
   controls. Rooms may have notches and alcoves for character (runbook 037c); see
   `docs/visual_overhaul/runbook.md` Phase H.

Unseated visitors and residents may stroll. Roaming destinations must leave arrivals, door and stair approaches,
service counters and conversation spaces clear, and must not cut the only route through a passage. Both ends of
an NPC's step stay reserved until arrival. Seated patrons and service staff remain in their authored positions.
`bash tools/run_tests.sh shop-paths` checks these navigation rules.

Walls use smooth solid finishes or subtle, filtered striped wallpaper instead of the pack's coarse wall textures.
The wood, stone and grand-room finishes retain their familiar warm or cool colour families as solid surfaces.
Floors use smooth warm oak boards, soft carpet, muted tile or stone; the Beast Centers' temple
has smooth stone flags under walls of the grey blocks their outside is built of. The roof deck and arena ring use the same smooth finish system. Area rugs have a muted wool colour,
broad binding and a simple inset border, with a 3x4 preferred minimum and 2x3 for tighter spaces. The allowed tile
footprints are 2x3, 3x4, 4x5 and 6x5, including rotations; no square rugs or narrow runners. Their placement follows
the old rug tiles, fitting around walls, stairs and hazards and allowing furniture to stand on the rug. Entrance
thresholds are clear of miniature decorative mats. Existing collision and walking tiles are preserved.

Wallpaper is a small cached procedural texture. Floor and rug patterns are antialiased shader finishes, with no
new image assets; furniture and pixel UI retain their existing textures.

## Room audit — 24 October 2026

All 40 current templates were rendered through the real world renderer, including the earth temple after the jungle ritual.
The normal map checker also visits every generated building in both initial and progressed states. Repeated houses
and shop types inherit the template changes and share the renderer's placement rules.

| Templates | Result / arrangement |
| --- | --- |
| `home`, `house_two`, `house_up` | Sofa moved upstage, coffee table downstage with an open tile; TV implied on fourth wall. Stairs, phone and doors retained. |
| `studio_a`, `uncle_home` | Bed and lounge remain distinct groups; sofa upstage, low table below it; rear TV removed. Rafe's story anchor retained. |
| `studio_b` | Rear TV removed; side dining chairs retained; side-wall armchair faces inward. |
| `home_mom` | Armchair moved out of the bedroom foreground to the side, facing inward. Bed and nightstands retained. |
| `home_bed`, `house_two_bed`, `house_up_bed` | Bed heads, nightstands and wall storage already suitable; desk chair in profile. |
| `home_hall`, `house_up_hall` | Clear landing and door approaches retained; narrow side furniture already suitable. |
| `bookstore` | One low display at the right side; central floor open and tall shelving retained upstage. |
| `museum` | Two central columns moved upstage; exhibit paths opened; display beasts face camera. |
| `music_shop` | Organ moved from playing area to back wall; low visitor bench retained. |
| `center` | Rear relic bays (cradle stone, healing font, reliquary, merge altar) behind the nurse's stone counter, open circulation; side waiting chairs remain low. The kennel is a separate barn (`kennel_barn`). |
| `apothecary`, `outfitter`, `electronics` | Rear stock and customer-facing counters retained; outfitter/electronics displays reduced to the two side edges, with beasts facing camera. |
| `arena` | Combined lobby/master hall retained: rear reception, clear lesson arrival route, ring and low perimeter benches. |
| `cafe` | Rear counter and tables with patrons in profile retained. |
| `saloon` | Two occupied table groups at the sides; spare central tables removed. |
| `dojo` | Rear sensei desk, side columns and clear training mat retained. |
| `music_hall` | Rear organ and desk retained; patron shifted out of the only cross-aisle so the left seating/restroom remain reachable. Low audience benches are a functional exception. |
| `fortune` | Fortune teller framed by rear plants, crystal table and open rug retained. |
| `fishery` | Rear crates, storage and pole anchor retained; table and chair in profile. |
| `kit_cabin` | Bed, rear fireplace/storage and side dining chairs retained; freestanding armchair faces camera. |
| `shack` | Added later: wardrobe, bed and nightstand at the back wall, storage and crates at the sides, a side chair in profile at its table, and the three starter-gear sacks on open floor clear of the door. |
| `skytower`, `skytower_top` | Ticket desk, side benches, stair approaches and landing retained. |
| `hideout` | Boss focus and low tables/benches retained, with encounter positions unchanged. |
| `ceo_1`, `ceo_2`, `ceo_3`, `ceo_4` | Reception, sentry floors and executive/captive staging retained; exhibits now face camera. Dungeon column obstacles retained. |
| `temple_air`, `temple_fire`, `temple_earth` | Guardian focus, side columns, song-stone groups and clear central approach retained. |
| `temple_tides_hall`, `temple_tides_falls`, `temple_tides_maze` | Walkways kept clear of anything tall; the first puzzle room's falls run down its back wall, and the maze's fade when you walk behind them. |
| `temple_tides_song`, `temple_water` | Stones in a row with a clear way to the back door; the octagon's path runs straight to the guardian's island. |
| `cathedral`, `crypt_1`, `crypt_2` | Altar focus, low pews and dungeon/encounter geometry retained. |

## Repeatable verification

`tools/check_maps.gd` checks every instantiated room in initial and progressed states, including exits, people,
phones, beds, stair approaches, windows and mandatory teacher sightlines. Its staging checks use the renderer's
actual furniture groups and facing decisions, and reject visible stage TVs, reversed lounge/dining seating,
central tall casework, and central stage columns/organs. Locked room doors must also have a reachable approach;
staff-only doors behind service counters are exempt. Visual checks are still needed for mesh shape, prop
dressing, projected overlap and subjective composition.

```text
bash tools/run_tests.sh quick
bash tools/run_tests.sh doorway coaches walk walk-touch tidewater-arrival rescue phone
godot --headless --path . --script res://tools/check_maps.gd
python tools/town_check.py
godot --path . --resolution 1920x1080 -- --scene=interiors --shots=res://build/shots/interiors
godot --path . --resolution 2400x1080 -- --scene=interiors --touch --shots=res://build/shots/interiors_touch
```

The tour uses fresh test state without loading or writing player saves. It bypasses on-enter story events so a
lesson or boss cannot replace the room under inspection. `--rooms=home,bookstore` selects templates;
`--overview=1` captures whole-room surveys of larger dungeons with a pulled-back camera. Normal captures use the
gameplay camera. Generated captures belong in `build/shots/`, not documentation screenshots.
