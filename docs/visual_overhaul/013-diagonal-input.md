# 013 — Diagonal movement setting and input

Updated 15 November 2026. **Waiting for visual approval.** Implementation,
automated UI checks and A71 live-input verification are complete. The user explicitly
requested 013 while 012's Rue Royale texture-budget gate remained open. This
authorizes the setting/input work; it does not approve higher artwork budgets or
mark 012 complete.

## Behavior

Start → Settings now has **Diagonal movement: Off / On**, using the existing
32-unit row typography and 56/80-unit desktop/touch sizing. Off is the default
for both new and older settings files; malformed stored values safely default
Off. The value persists with the other controls preferences and applies at
runtime without interrupting a started step.

With On, two arrow keys or physical d-pad directions combine, the stick selects
one of eight directions, and a thumb in a touch-pad corner presses its two
adjacent arms. Sliding into and out of a corner releases the appropriate axis.
Both lit arms use the existing pad artwork. The enlarged touch shapes remain
inside the existing no-tap exclusion square. Off preserves cardinal key/pad
priority and limits the stick to cardinal movement; this intentionally replaces
the prior always-eight-way stick default, as the runbook requires. The stick's
radial deadzone remains. Menus retain cardinal touch navigation, while flute
chords and B plus movement remain multi-touch.

The existing shared movement core supplies corner/elevation protections, sliding
and equal ground speed. `--diagonal_core=1` remains a developer-only way to pin
core collision rules independently of the public input preference.

## UI corrections found during verification

Adding another setting exposed a selected-row visibility issue when switching
Input modes resized the book. Focus visibility is now finalized after container
layout settles. At 1280×720, the pad's expanded no-tap zone also blocked the
selected row's center despite little visual overlap. The book now includes
enough trailing scroll space to bring focused rows above that full exclusion
zone. That trailing space is preserved during rebuilds so the scroll range does
not briefly clamp and move the row under the pointer. Text, rows and the controls
retain their normal sizes and positions.

## Tests

- `build/perf/vo/013/after/final-verified.json`: **10/10 pass in 1m40s** — controllers,
  controllers-touch, video-settings, video-settings-touch, mobile-menus,
  desktop-menus, scripts, and all three diagonal-input layouts.
- The final fixture passes **33 desktop checks** and **63 checks in each touch
  layout**. It covers old/malformed settings, persistence, runtime changes,
  opposite-key cancellation, keyboard run + diagonal movement, releasing a
  started diagonal after switching Off, stick/deadzone, physical d-pad, touch
  corner boundaries, thumb slides, B + movement, flute chords, Settings taps,
  focus, stable scroll position during toggles, and absence of world movement
  from menu input. The one-step fixture holds the field frozen until injected
  events are available, then invokes its normal dispatcher once, preventing
  slow device frames from starting an extra held-key step in the fixture.
- `after/regression.json`: the earlier broad 18-case run passed quick (4/4),
  both core fixtures (212 checks each), walk and walk-touch, and the input/UI
  scenarios except the subsequently corrected desktop controller focus issue.
  The final UI run above verifies that correction. Both budget profiles still
  reject Rue Royale's texture inventory: **22,334,841 > 19,781,566 bytes** at
  all three positions. No limits or rendering assets were changed by 013.
- `after/reference.json` separately passes the small touch input fixture and
  script compilation. Native 2400×1080 and corrected 1280×720 captures also run
  the full 63-check touch fixture successfully. All three native capture
  profiles were regenerated from the final code.
- `git diff --check` passes for this change.

All saves/preferences are isolated under `res://build/vo013_*` or the dedicated
Android test package's `user://bench/vo/013/` tree. The player's app and save
files are not used. No full-suite, physical-controller pairing or device
frame-rate claim is made.

Early focused runs caught a malformed-value comparison; explicit type checking
fixed it. One UI run had passing individual result files but an invalid shell
summary because the runner was edited during execution. It is superseded by
the stable final 10/10 run, not counted as passing evidence.

## Visual evidence and live checks

- Baseline Settings: `build/shots/vo/013/before/settings_ruby.png` (1920×1080).
- Desktop: `build/shots/vo/013/desktop/`.
- Wide touch: `build/shots/vo/013/touch-wide/` (2400×1080).
- Reference touch: `build/shots/vo/013/touch-reference/` (1280×720).
- Each profile includes Ruby, Sapphire, Emerald and Hematite. Baseline and new
  fixtures use different towns; these images compare Settings layout, not art.

The Windows computer-use helper initially returned **“Computer Use app approval
timed out.”** The user subsequently approved access. OS-level inputs were sent
only to the returned isolated Godot preview window; its saved preference was
observed On and the book was opened/closed. A completed diagonal tile step was
not established by that preliminary preview; routed event tests above remain
the precise preliminary movement evidence. The final Android OS checks below
independently establish real key/tap behavior and centred movement.

The A71 was disconnected and then rebooted during testing. USB transport was
revalidated against SM-A715F and serial R58N22FFRCB; no global ADB reset or phone
lock-setting change was made. The user reported the screen sleeping, so the
Android fixture now uses the existing temporary `screen_set_keep_on(true)`
mechanism while it runs, restoring the previous state when it exits. Android
also releases the window flag when the isolated test app is stopped.

**Final A71 run:** SM-A715F, Android 13, beta3 Mobile renderer; **63/63 checks pass,
no script errors** (`phone/device.json`, `phone/logcat.log`). Keep-awake was
reported true during the active test. The final isolated package was removed;
package enumeration confirms it is absent. The ordinary player packages and
phone lock/screen-timeout settings remain unchanged.

`phone/os-input.json` and `phone/live-logcat.log` record bounded Android OS-level
checks after confirming the test app is foreground: one tap toggles Off, Right
toggles On, Space closes the book, and Right+Down walks from `(40, 3)` to `(41, 5)`
and stops exactly at the tile centre. A started cardinal step can finish before
the diagonal, as required. These use OS input injection, not a physically paired
keyboard/controller. The collector stops before OS input if the fixture fails
or another app becomes foreground.

Earlier device attempts interrupted by sleep/disconnection are invalidated.
Another attempt encountered an extra indent in concurrent `battle.gd` edits;
only that indent was corrected, then all 319 scripts compiled. Vendor Vulkan/
gralloc initialization messages remain in Android logs; no device FPS or clean
driver-log claim is made. The final script-error check is clean.

## Local-model assistance

The project model identified the existing `_send` mutual-exclusion path, and
summarized the malformed-value, focus and budget failures. These were checked
against the actual source and logs. `after/capture-review.txt` reports no selected
row/help text clipping or overlap; direct inspection agrees. Representative
Sapphire desktop, Emerald wide touch and Hematite reference captures were
inspected directly, alongside Ruby. No screenshot-review suggestion changed art.

## Review checkpoint

### Requested control-opacity refinement, 15 November

The user requested more transparent controls over the open book, then about 40%
opacity when the screen is no longer being touched. Active controls now use
55% opacity while any Start book remains on the UI stack, and full opacity
outside it. After two seconds without a touch they fade to 40%. A touch anywhere
brightens them immediately and performs its normal action; any held finger keeps
them active, including B plus movement and flute chords. Hit areas and no-tap
zones are unchanged. The pad's fill shader now honors inherited opacity as well
as the lettering, using the same vertex-tint pattern as the existing prompt shader.

`build/perf/book-controls-opacity/states.log` and the paired images in
`build/shots/book-controls-opacity/states/` record actual windowed states:
book idle **0.40**, book active/held **0.55**, field active/held **1.00**, field
idle **0.40**. Held captures wait longer than the idle delay. Wide-phone Mobile
renderer captures in all four gems are in `build/shots/book-controls-opacity/wide/`.
The local-model readability review suggested making the controls opaque again
and claimed overlap with the selected row; those suggestions were rejected
against the explicit user request and the directly inspected screenshots.
The selected row is clear; underlying text shows through the pad as requested.

An unrelated new decor helper used `prints()` internally, which resolves to
Godot's void-returning built-in. Renaming that helper to `print_defs()` and its
internal calls restored compilation without changing artwork. Some menu runs
also overlapped unfinished room-decor edits; those logs are retained separately
from the final verification in `build/perf/book-controls-opacity/`.
The last focused run passes all four menu/touch scenarios. Its separate global
script scan found a missing `Beasts` preload in the concurrently extended
`mechanic_lessons.gd` fixture; the preload was added without changing its test
logic, and the compilation recheck is recorded in `script-final.json`.
That recheck passes. This opacity-only follow-up was rendered at 1280×720 in a
real window and at 2400×1080 with the desktop Mobile renderer; it was not
re-exported to Android. The A71 results earlier in this report cover the setting
and input implementation before this visual refinement.

The new row and complete On/Off value fit at all three sizes without text
shrinking. Captures use the existing book, pad and gem styles. Step 013 awaits
the user's visual approval; step 014 has not begun. The unrelated Rue Royale
budget failures remain recorded in 012 and are not waived by these UI results.
