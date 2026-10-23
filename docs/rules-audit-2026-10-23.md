# Project rules audit — October 23, 2026

The game does **not** pass all of the shared rules yet. The automated gameplay scenarios pass after retries, but windowed inspection and runtime measurements expose touch layout, sizing, theme, and renderer issues. This audit changes no gameplay code.

## Test environment and evidence

- Godot 4.7 stable, Windows, AMD Radeon RX 9060 XT.
- Desktop window at 1920x1080; touch previews at 2400x1080 (20:9) and 1280x720.
- Windowed Forward+, Mobile, and Compatibility renderer checks. The phone previews run on the desktop; they are not physical phone tests.
- Fresh harness state and isolated test saves. The additional audit runs use `res://build/rules_audit/saves/`; the existing regression script uses its own project-local `build/review_saves/`. No player saves were used.
- Thirty full-size PNG captures, runtime button measurements, and logs are in `build/rules_audit/`. That directory is ignored by Git; these are local audit artifacts.
- The initial sandboxed Godot launches crashed before tests began. The same script check succeeded outside the sandbox, and the substantive runs below were performed there. Those startup crashes are not counted as game test failures.
- Bash was unavailable. `build/rules_audit/run_suite.py` read the 28 scenario definitions directly from `tools/run_tests.sh`, ran the same Godot arguments with three workers and up to two attempts, and retained the output. It also applied a stricter check for engine `ERROR:` lines, including shutdown cleanup errors.

Key evidence: [functional summary](../build/rules_audit/suite-summary.json), [full suite results](../build/rules_audit/suite-results.json), [touch assertions](../build/rules_audit/touch-probe.json), [capture matrix](../build/rules_audit/capture-results.json), [follow-up captures](../build/rules_audit/followup-results.json).

## Confirmed failures

### 1. Character creation overlaps the touch controls

At 1280x720 with `--touch`, the d-pad covers part of Confirm and the character preview. A/B overlap the lower color choices on the right. The creator does not move the side controls aside as the book and ring editor do. Some color choices therefore cannot be tapped cleanly without hitting the on-screen controls.

Evidence: [1280x720 creator](../build/rules_audit/phone-maker-small.png), [2400x1080 creator](../build/rules_audit/phone-maker.png), [measured controls](../build/rules_audit/phone-maker-small.json).

Relevant implementation: `scripts/ui/hero_maker.gd`, especially `_ready()` and `_row()`. Hide the side pad while using the creator's direct controls and arrange the content in pages or groups that leave Confirm and Start/Pause clear.

### 2. Several touch controls fall below the 80-unit target

Measurements are logical UI units from the running control rectangles, not screenshot pixels or source minimums:

| Control | Observed size | Rule / implication |
|---|---:|---|
| Creator Confirm, arrows, body choices | 53 high | Below the touch minimum |
| Creator color swatches | Usually 40 wide by 45 high | Small, closely packed tap targets |
| Ring editor Done | 57 high | Below the touch minimum |
| Pixel book tabs | 71 high | Below the general touch target goal; the stricter written row/page-button rule does not explicitly name tabs |

The creator had 56 visible buttons below 80 units in height. Increasing every row without restructuring the screen would cause more overflow; pagination or grouped choices are needed.

Evidence: [creator measurements](../build/rules_audit/phone-maker-small.json), [ring measurements](../build/rules_audit/phone-ring.json), [book measurements](../build/rules_audit/phone-beasts.json).

Relevant implementation: `scripts/ui/hero_maker.gd:37` (`CHIP`), `:168` (row minimum), `:213` (`_button`); `scripts/ui/ring_editor.gd:87` (Done); `scripts/ui/book_menu.gd:34` / `:126` (tabs).

### 3. Disabling the pad also reduces phone menu sizes

With `--touch` still active, setting the touch pad preference to Off in memory reduced `UIKit.row_h()` from 80 to 61 units. The rendered menu rows and page buttons use that reduced size. The rules require mobile sizing even when the on-screen pad is hidden.

`scripts/ui/ui_kit.gd:228` determines touch sizing from `Prefs.touch_enabled()`, which returns false for the Off preference. The screen's input capability and the pad's visibility need separate decisions.

Evidence: [pad-off preview](../build/rules_audit/phone-pad-off.png), [pad-off measurements](../build/rules_audit/phone-pad-off.json). The preference was changed only in memory for this test and was not saved.

### 4. Pixel flute headings use the gem as text color

The Pixel flute screen renders “Tidewater Shanty” in dark ruby text on the near-black panel. This violates the white-text Pixel rule and makes the heading less readable. `scripts/ui/flute_game.gd:326` draws the song name with `UIKit.ACCENT`; result and coach headings also use the accent directly at `:466` and `:479`.

Evidence: [flute screen](../build/rules_audit/phone-flute.png). Use the shared style-aware text/plate treatment while preserving the meaningful note and timer colors.

### 5. The world requests an effect unsupported by the Mobile renderer

Every sampled Mobile-renderer world launch reported:

> Screen-space ambient occlusion (SSAO) is only available when using the Forward+ or Compatibility renderers.

`scripts/world/world.gd:290` enables SSAO without checking the renderer. The world still renders, but the setup is not cleanly compatible with the intended mobile rendering path. Gate this effect by renderer capability.

Evidence: [Mobile renderer log](../build/rules_audit/phone-battle-engine.log). The separate native Compatibility-renderer world sample rendered successfully; that does not verify a browser export.

### 6. Shutdown leaks prevent a clean suite pass

All 28 scenarios eventually produced their expected gameplay success markers with no script, missing-resource, or explicit assertion failures in their successful attempts. However, **15 final scenario logs reported leaked objects and resources still in use at exit**. Only 13 were clean under the audit's stricter error check.

The affected final logs were: egg-sales, intro, rescue, walk, walk-touch, ringedit, coaches, mascot, arena-entry, phone, doorway, temple-water, temple-air, lessons, and temple-earth. The existing shell runner does not treat these cleanup messages as failures. The logs establish shutdown lifecycle problems; they do not establish memory growth during a long play session.

The ghost temple also failed its actual capture outcome on its first attempt (`captured false`, returned to Gravenmoor), then succeeded on the second (`captured true`). This needs investigation as a nondeterministic test/gameplay outcome. A passing retry is not evidence that the first failure was harmless.

Evidence: [scenario summary](../build/rules_audit/suite-summary.json), [first ghost attempt](../build/rules_audit/logs/temple-ghost-1.log), [second ghost attempt](../build/rules_audit/logs/temple-ghost-2.log).

## Coverage against the shared rules

| Rule area | Result | Evidence and limits |
|---|---|---|
| Godot scripts and data references | Pass | 123 scripts compiled; data and beast checks passed. |
| Maps, exits, doors, elevation, tutorial placement | Pass in automated coverage | Godot map checker passed; Python visibility/reachability checker found zero problems in all 12 towns; 171 maps/interiors built with zero porch obstructions. |
| Cardinal walking and input parity | Pass in exercised cases | Keyboard and synthetic gamepad/touch scenarios passed, including direction changes, tile centers, cliffs, ramps, and pad boundary touches. No physical controller was used. |
| Touch run, release, world taps, and flute chords | Pass | All five additional windowed assertions passed using `InputEventScreenTouch`, including two simultaneous touch contacts. |
| Battle confirmations and ring rules | Pass in automated coverage | Battle command and ring editor success markers passed. Windowed command and target screens were readable and clear of side controls; Done sizing fails separately. |
| General touch layout and sizing | Fail | Creator overlap, undersized controls, and pad-off row shrinkage described above. The title New Game target and sampled standard list/page buttons with the pad enabled met the size requirement. |
| Pagination and long lists | Pass in sampled screens | Desktop Next and direct tab selection were clicked in the real window. Touch book pages and the tenth save slot were rendered with reachable paging controls. This does not cover every possible label or list length. |
| Save flow and previews | Pass in exercised cases | Phone, save-ui, save-ui-touch, and save regression markers passed; thumbnail-less saves showed the intended placeholder, and the last slot retained its correct preview. Existing player saves and every historical save version were not tested. |
| Themes and gems | Partial | Both styles in all four gems were rendered and visually compared; an open book rebuilt after a runtime style change. Frames, selections, and book layouts were consistent in those samples. Pixel flute headings fail. Runtime gem changes through the real Settings menu were not exercised. |
| Art, region identity, and animation | Partial visual coverage | Town exterior, Beast Center interior, battle, beast models, portraits, and creator samples retained the established low-poly art. No missing model/texture errors appeared in successful runs. Every region, merge appearance, animation phase, and character combination was not visually inspected. |
| Story, capture, growth, puzzles, and guided lessons | Pass with caveats | Full automated flow reached its completion marker; all lessons and guardian scenarios eventually succeeded. Additional tap-to-interact, flute lesson, bridge, cliff, rockslide, ice, checkpoint, warden, and sentinel diagnostics completed successfully. Automated accelerated play does not establish normal difficulty, pacing, or every line's writing quality; ghost capture was nondeterministic. |
| Mobile and web performance/compatibility | Partial | Mobile and native Compatibility renderers launched. Mobile SSAO configuration fails; physical phone performance and the actual browser build remain unverified. |
| Safe areas and physical ergonomics | Unverified | No device cutout/safe-area handling was found in the inspected UI code. A desktop rectangle cannot establish notch clearance, thumb reach, or behavior on an actual phone. |
| Licensing and distribution | Unverified | This audit added no art/audio and did not export or publish. It did not re-audit third-party licenses, release packages, or source-pack provenance. |
| Agent working practices | Followed for this audit | Gameplay code and unrelated edits were preserved; test saves were isolated; real windows were used; captures were inspected. These process rules are not properties a game binary can permanently pass. |

The old headless `tapzone` diagnostic did not move on its “open ground” probe, so it was not counted as a passing world-tap test. A focused windowed probe using the camera's actual screen position then passed for open ground and pad blocking. See [windowed touch results](../build/rules_audit/touch-probe.json).

## Performance sample

The existing performance scene was run at 2400x1080 with `--rendering-method mobile --touch` on the desktop GPU. It averaged 60 frames per map after a short warm-up:

| Map | Draw calls | Primitives | Average frame time |
|---|---:|---:|---:|
| Tidewater | 423 | 382,771 | 16.7 ms |
| Coastal Path | 357 | 291,693 | 16.7 ms |
| Cogsworth | 428 | 229,550 | 16.7 ms |
| Cocoon Cove Beast Center | 118 | 172,995 | 16.7 ms |

This is a short, capped desktop sample. It does not measure phone GPU performance, thermal throttling, startup time on a phone, frame-time percentiles, or a long play session. [Performance log](../build/rules_audit/perf-mobile.log).

## Reproduce the main visible findings

Run from the project root, replacing `godot` with the local Godot 4.7 executable. These existing harness modes use fresh test state:

```text
godot --path . --windowed --resolution 1280x720 --rendering-method mobile -- --touch --scene=maker --shot=res://build/shots/creator_touch.png --shot_w=0
godot --path . --windowed --resolution 2400x1080 --rendering-method mobile -- --touch --scene=ringedit --shot=res://build/shots/ring_touch.png --shot_w=0
godot --path . --windowed --resolution 2400x1080 --rendering-method mobile -- --touch --scene=flute --shot=res://build/shots/flute_touch.png --shot_w=0
```

The local `build/rules_audit/` scripts retain the complete capture matrix, exact windowed touch assertions, pad-off reproduction, and measurement logic. No fixes were made during this audit; the failures above remain open.
