# Shop floor and NPC circulation — 13 November 2026

Direct user request, separate from the numbered visual overhaul: reduce shop clutter, especially in the middle,
and let NPCs move without obstructing doors or people the player needs to talk to.

- Outfitter and electronics: retain two side exhibits instead of four spread across the floor.
- Bookstore: retain one low side display instead of three across the floor.
- Saloon: retain two occupied side tables and remove spare middle tables.
- Keep the existing roaming residents/visitors, seated patrons, service staff and story gates.
- Reject roaming destinations beside doors, locked doors, stairs, counters and other people, or on arrival tiles.
  Check that free neighbouring tiles remain connected around the NPC; narrow passages must stay open.
  Reserve both ends of an animated step, including the player's departure tile, and pause new roaming during UI.

Verification: map checks pass for 309 interiors; doorway, keyboard walking and touch walking pass.
`shop-paths` covers open floors, two kinds of passage, arrivals, counters, conversation approaches and moving actors;
the generated-room survey includes 58 roaming and 18 seated visitors. `counter-phones` passes 39 instances / 9 layouts;
one run reported a resource-in-use error during exit cleanup after its successful interaction checks.
The broader script check was blocked by an existing duplicate `b` declaration in `tools/debug/mobile_menus.gd:145`.
That file contains unrelated concurrent edits and was left unchanged by this task.

Real gameplay-camera screenshots, using isolated preferences and save directories:

- Before: `build/shots/shop_clear/before/{outfitter,bookstore,electronics,saloon}.png`
- After, desktop: `build/shots/shop_clear/after/` (same filenames).
- After, wide touch screen: `build/shots/shop_clear/touch/` (same filenames).

Visually inspected all four changed desktop rooms and the touch bookstore: open central floors, intact service
counters, accessible side doors and retained low side displays. Visual approval is pending.
