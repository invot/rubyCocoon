# Hotel spa and lobby review — 15 November 2026

Targeted user-requested changes, outside the numbered overhaul sequence.

- Healing spring on a walkable raised deck in the pool room's back-left corner; inset steps and clear entrance, with the hallway door moved down the left wall to keep its approach clear.
- Pink water uses the shared water shader, animated frame resources and pool opacity (0.84), with the ordinary ripple, drift and absorption settings. Only its palette differs. Soft rising steam remains.
- Steam sign fixed on the outside of the front balustrade, right of the steps. Delapouite's Steam SVG from the existing game-icons.net pack, baked through the shared icon pipeline; credit in CREDITS.md. World lettering follows the shared glyph alphabet; inspecting it reads “Healing spring. Fully restores your party's HP and MP.”
- Two guests in the swimming pool, placed beside reachable pool edges. No couch in the pool room.
- Full-height windows: shallow sealed garden box, existing island landscape behind real small bush meshes, screen-sampling glass with shine and explicit blur taps for Compatibility as well as Forward+. Black box roof; room dado and cornice stop at the glazing.
- Every indoor dais uses the lobby's continuous bevelled wooden balustrade helper, capped posts and broad slats.
- Lobby left coffee table moved in front of the couch, armchair on the table's right.

## Verification

- Desktop and touch `island-updates`: 0 problems, including walking up/down spa steps, real tub tap healing HP/MP, swimmers remaining in water, couch absence and clear ground-level gym approach.
- Quick scripts, data and beasts checks passed in `build/spa_final_quick_logs`. A transient counter-gate parse failure from concurrent work was already corrected before that run.
- `python tools/town_check.py`: 0 problems.
- Final full map audit: 323 interiors checked, 0 problems (`build/spa_maps_final.log`). Earlier runs flagged three table-facing seats; a concurrent audit update now recognises those intentional arrangements. No swimming guest reachability failures remain.
- Windowed desktop 1920×1080, 20:9 touch layout 2400×1080 and Compatibility 1280×720 inspected. These are desktop captures, not phone hardware measurements. No shader/runtime errors in the captures; the existing ObjectDB exit warning remains.

## Visual review

- Before: `build/shots/hot_tub_before.png`
- Pool desktop: `build/shots/hot_tub_final.png`
- Pool wide touch: `build/shots/hot_tub_final_phone.png`
- Compatibility: `build/shots/hot_tub_compatibility.png`
- Lobby seating: `build/shots/hotel_lobby_seating_final.png`

Awaiting the user's visual review; no later overhaul step started.
