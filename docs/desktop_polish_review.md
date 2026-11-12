# Desktop usability and performance review

Implemented from the November 11 playtest feedback. Changes are local source changes, not a deployed web update.

## Player-facing changes

- Shared typography uses bundled triangle, gender and star glyphs. Symbol fallback metrics match League Spartan, fixing the inflated line heights. Direction-key hints use triangles. Hematite headings and values are lighter.
- Character creation uses a smaller preview and bounded scrolling pages; Confirm clears the desktop key guide. Beast summaries stay within the viewport, scroll with keys or the shared rail, and retain a reachable Close button.
- Spoken desktop questions show two reply bubbles immediately below the speech bubble. A/B answer directly; the chosen answer gains a border, the other disappears, and feedback lasts 0.35 seconds. Touch retains the existing widened A/B controls. Written prompts use framed buttons.
- Speech pagination preserves complete sentences. An unusually long single sentence gets a taller bubble. Pickups interrupt arrival notices immediately and use short Bag hints.
- The settings guide follows the selected input method at runtime; the controller drawing appears only for Controller.
- Home's phone is against the staircase wall. Locked interior doors give a locked observation without an invented occupant. Elder Rowan's dialogue no longer reveals ghosts or the Umbral Legion.
- The player's Cove house is red with a blue door. Non-enterable scenery houses have red doors. Cove dock lightposts are removed and their tiles are traversable deck. Existing cargo remains visibly occupied, and the dock navigation checks pass.
- Cove paving has a grass verge at the waterfront. Beast Center front infill no longer protrudes through the roof, and frontage props leave a wider door approach.
- Interior windows have opaque blue painted glass, frames, mullions and reflections. Exit markers are geometric woven banners with a central downward triangle. Lamps retain their original shapes with five shade palettes and separate fittings. Ordinary house furnishing cannot choose wooden pallets.
- The first Coastal Path has no weapon fixtures or their coaches; battle teachers, the footbridge and story gates remain.
- Battle grass uses broad light/dark patches and soft dirt areas instead of the dark grass tufts. Batched bushes sit outside the fighting lane. The HUD mask samples the final camera transform and uses matching antialiasing. Outline shaders skip interior pixels.
- Level rewards show the actual before/after values and deltas for HP, MP, Attack, Defense, Spirit and Speed, revealing one line at a time during the cinematic.
- The no-floating-text rule and the updated dialogue/layout conventions are recorded in AGENTS.md and README.md.

## Performance measurements

Native desktop, Godot 4.7 Compatibility renderer, AMD Radeon RX 9060 XT, 1920x1080 window, 1080p/Mid. These are desktop measurements, not browser or phone hardware measurements. Final timings include concurrent ground-cache work present in the shared workspace; they measure the combined working tree.

The latest outdoor static set survives a room trip. Actors and interactions rebuild; fresh layout and door-lock fingerprints invalidate stale sets. Only one detached set is retained. Building arrival fades bind material overrides only when their rendering state changes.

Second-pass timings from `build/perf_before.json` and `build/perf_final.json`:

| Transition | Black hold before | Black hold after | Total before | Total after |
| --- | ---: | ---: | ---: | ---: |
| Home to Cocoon Cove | 254.1 ms | 32.8 ms | 789.0 ms | 568.4 ms |
| Beast Center to Cocoon Cove | 131.7 ms | 34.2 ms | 732.3 ms | 567.9 ms |
| Beast Center to Bellerive | 230.5 ms | 33.8 ms | 848.9 ms | 566.4 ms |
| Enter Coastal Path | 525.4 ms | 102.4 ms | 1082.0 ms | 634.9 ms |

Median world CPU ticks on the directed behind-building path fell from 0.314 to 0.254 ms in the Cove and 0.502 to 0.383 ms in Bellerive. Median frame intervals remain about 16.6 ms. This does **not** eliminate first-use stalls: the cold Cove transition still took about 22.7 seconds, and the Bellerive path still had a 576 ms worst frame (render CPU about 574 ms). Cold rendering work remains an unresolved performance limit.

## Verification

- Full 116-scenario run, followed by focused reruns of failures: latest results are 116/116 passing. See `build/validation_summary.json`; this is an aggregate of the full run and reruns, not a second full-suite run. The air-guardian autoplay failed in the full run and passed its focused rerun without a combat change.
- Quick script/data/map/beast checks, affected speech/creator/growth/menu/cache checks, exterior sealing and Cove aperture checks pass. Both map audits pass: 293 interiors checked by Godot and zero problems from `tools/town_check.py`.
- Windowed captures inspected at 1920x1080, 1280x720 and simulated 2400x1080 touch layout. Creator arrows/swatches/tabs, focus scrolling, direct A/B replies and beast detail scrolling are exercised by injected real input events in the harness. All four gem palettes were captured.
- Representative captures: `build/shots/polish-final/`, `build/shots/polish-phone-final/`, `build/shots/polish-reference/`, `build/shots/creator-phone/` and `build/shots/settings-review/`.
- No exported browser session or physical phone timing was verified. Existing shutdown ObjectDB/resource warnings remain in several harness logs; no missing-resource or script errors remain in the passing checks.
