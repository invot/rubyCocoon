# Returned to Claude: 008b cost experiment and integration

The user-approved enclosed-room 30-unit/two-split setting is integrated and
verified. Outdoors and films retain their authored lighting. See
[008b-integration.md](008b-integration.md) for raw evidence, commands and limitations.

The largest generated building room is reef#0 (Temple of Tides), 31×13. The hero
retains its shadow in the checked entry and four reachable-edge views on desktop
Mobile and the phone. A 2400×1080 Compatibility/touch capture also retains coverage.
The board is `build/shots/vo/008b/integration-indoor.png`. User approval of the
original 30/two candidate remains in force; this is its integration verification.

The requested film on/off pair is now valid: OculusKey's effective shadow flag
changes, and merge's range is verified at 41.6 after `enlarge(1.6)`. Captures:

- `build/shots/vo/008b/film-hatch-diagnostic.png`: egg in tongs 4.9 s and reveal 7.9 s.
- `build/shots/vo/008b/film-merge-diagnostic.png`: parents 2 s, mid 4 s, child 7.5 s.
- Full phone frames under `build/perf/vo/008b/phone/extracted/pass_01/` (on),
  `pass_02/` (off), `pass_03/` (on). These use the real film stages and fixed-step
  film timelines; particles/shader time are not pixel-synchronized.

On the phone, key-shadow disabling changes median viewport GPU time by 0.540 ms
for hatch and 0.160 ms for merge; merge on-bracket drift is −3.1%. Recorded maxima
are ~21–23 ms hatch / ~25–26 ms merge with shadows, ~21 / ~24 ms without. Exact
tables and peak samples are generated under `phone/`. The display reported 24 Hz,
with ~42 ms presentation intervals in every pass, so do not infer an fps gain.
Desktop GPU differences are small and bracket drift is much larger.

No film layer should be removed on the strength of this result. The experiment
does not attribute the rest of film cost to the key, nor measure every beast or
each transparent layer. Any later film-light alteration needs your visual judgement
and user approval; step 007 already owns the measured beam/alpha-layer investigation.
There is no new film-light candidate to approve now. Parent 008 can close with the
approved indoor integration and films retained, and the next numbered work is 006.

All Codex measurement/export jobs from this step are finished. The temporary
benchmark package was removed; original package identity and export presets match.
Check the shared checkpoint before heavy work in case another chat has since started.
