# 010c: Godot 4.8 migration evidence

13 November 2026. **Main checkout now uses Godot 4.8 beta 3; cutover checks pass.**
The user approved the fresh comparison screenshots and beta 3 target, with
adoption waiting for the remaining validation checks. The main 4.7 import cache
was preserved at `build/perf/vo/010c/main-rollback-47/.godot/` before importing
with 4.8. Main-tree checks pass **19/19**, both exported Windows renderer probes
pass, and the Python town checker reports zero problems. Broader 010c
performance/feature acceptance remains open.
The fresh `build/perf/vo/010c/integration-03/project/` candidate explicitly pins
project features, default editor and CI to **4.8 beta 3**, with Android Swappy mode
0. It includes the concurrent confirmation-UI work and crash-prevention fixes.
Its guarded import passed (898 MiB sampled peak private memory); targeted
integration checks are recorded separately. This does not establish accepted 011 budgets.

## Checkpoints and source preservation

- **010c-a:** toolchain selection, import compatibility and export smoke tests.
- **010c-b:** matched target comparisons, regression classification and small feature trials.
- **010c-c:** visual/release decision, adoption and active setup/CI documentation.

The user's supplied editor is `4.8.beta3.official.c51ff06e8`, matching the
[official beta 3 announcement](https://godotengine.org/article/dev-snapshot-godot-4-8-beta-3/).
The [4.8 migration guide draft](https://github.com/godotengine/godot-docs/pull/12421)
is not yet a published upgrade guide; its documentation URL did not resolve.
No new rendering feature or lighting change has been adopted. The beta target
and comparison visuals are approved; remaining target evidence is listed below.

Corrected, matched snapshots and their SHA256 manifest are under
`build/perf/vo/010c/import-settings-02/`: `project-47/`, `project-48/`,
`source-manifest.json`. Each copy has 2,491 tracked files, the two new toolchain
Python files, and **499 source `.import` sidecars**. Import caches are independent.
The task-start working-tree status is preserved in the manifest. No branch,
commit, reset, player-save/settings modification or source-pack modification was
performed. Concurrent edits to `AGENTS.md`, `confirm_prompt.gd` and
`tools/debug/mobile_menus.gd` are being preserved; the frozen snapshots do not
establish validation of later concurrent UI changes. Integrate and retest those
changes before cutover.

**Superseded attempt:** `build/perf/vo/010c/preflight-01/` omitted the ignored
`.import` sidecars. It established basic engine launch/export feasibility, but its
texture imports, package sizes, partial suite and first phone run are not matched
acceptance evidence. That suite was stopped, with its logs retained. Its phone
record is `build/perf/vo/010c-a71-48-min/phone/`; do not pool it with attempt 02.
The correction is documented in the migration plan to prevent repeating this error.

007's interrupted original-phone report is still unavailable: ADB exposes the A71,
not the original `ZY22K7BD2J` phone. This work does not close 007 or replace that
phone's temporary app. The user unlocked the A71 for these tests.

## Toolchain and fixes

`tools/godot_toolchain.py` resolves the selected editor's exact template version,
release tag and editor-settings minor version. The default now selects 4.8 beta 3.

- Android exports use version-specific portable editor directories, matching APK
  templates and `editor_settings-<major.minor>.tres`, and write `toolchain.json`
  with editor/template hashes. Windows console launchers are small wrappers; the
  portable exporter copies their full sibling editor, not the wrapper alone.
- The Compatibility exporter and Windows renderer probe select matching templates;
  a missing matching custom template fails instead of using a 4.7 template with 4.8.
- Previously pinned `vo_*` CLI defaults now respect `GODOT`; explicit `--godot`
  still takes precedence. Existing server, shell runner, image, key-art and
  production Web tools already supported that override.
- `prepare_windows_templates.py --godot ... --files ...` downloads selected entries
  from the official `godotengine/godot-builds` archive using HTTP ranges. It checks
  ZIP-entry CRCs and records SHA256s. The complete archive was **not** downloaded
  or SHA256-verified; the release's archive digest is provenance, not verification.
- 4.8 required workspace SDK additions: `build-tools;36.1.0`,
  `platforms;android-36`, `cmdline-tools;latest`. Existing 35.0.1/android-35 remain.
  No global SDK/editor settings were replaced.

25 Python tool/recovery checks pass, including four version/template/wrapper
isolation checks and five memory/timeout/logging guard checks. Syntax compilation
and `git diff --check` pass. Active launchers now share `default_godot()` (including
server, shell tests/image/trailer launchers and production Web); the final engine
default can be changed without replacing many unrelated version literals.

Two compatibility fixes are also prepared in the main checkout, still compatible
with 4.7:

- Headless `--scene` runs explicitly set `Window.size` to the reference viewport
  or the requested `--resolution`. The headless DisplayServer otherwise keeps a
  dummy 64×64 window even when passed a resolution flag. 4.8's new button touch
  clipping rejected legitimate fixture taps against that tiny rectangle. A
  minimal probe and the exact engine source confirm the cause; resizing the
  logical Window fixes the probe. Normal windowed/phone play is unaffected.
- Battle-ring artwork generators draw into RGBAF and explicitly truncate to the
  canonical RGBA8 bytes before mip generation. The exact engine sources show 4.7
  truncates channels and 4.8 rounds them. Without this adaptation all nine ring
  assets differ by at most one byte value. With it, the existing **byte-exact**
  battle-art verification passes on both engines, including all mip levels and
  audio. No baked asset was replaced, smoothed or accepted with a wider tolerance.

`compatibility-fixes.patch`, `post-import-fixes.json`, `touch-probe-*.log`,
`bake-probe-all-48.log` and `quantization-*.log` preserve the patch and diagnostics.
Final scripts/data/maps/beasts/battle-art/battle-visuals/battle-poses checks pass
**7/7 on each engine** (`final-compatibility-47.json`, `final-compatibility-48.json`).

## Exact editor/template identity

| Artifact | SHA256 |
|---|---|
| Supplied editor ZIP | `95d65bcad82e334357e0359d50cefdc2c1ba60fc849c32da14b7cf914277559e` |
| Full 4.8 Windows editor | `0467d13b5656fb324acc1292e579526fae2b5b2199217acbf1507c4fa97ace24` |
| Existing 4.7 Windows editor | `b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8` |
| 4.8 Windows debug template | `d80c4181b202419adfd941a3133601fdae8a5b9f9955e4c46fe6d78372e07afc` |
| 4.8 Windows release template | `2f099ad62fdef78223c5060ad09073ce1829008e3efab3045a6c93ff4e3e215d` |
| 4.8 Android debug template | `4cca923663ca0f9629a00835416eb9cfe85fc245c9b547b5d3c105fe16b42df4` |
| 4.8 single-thread Web release template | `28ed353223b034ebe5d7db654017806c45faed979d4d68a3bd05f537549ee750` |

Template provenance is in `build/tools/godot-windows-templates/4.8.beta3/`.
Android toolchain/APK hashes are in each attempt's `phone/toolchain.json` and export
output. These are debug benchmark APKs, not replacement player installs.

## Imports and unchanged-game rendering

The corrected 4.8 import changes **379 `.import` sidecars only**, adding exactly:

```text
compress/high_quality_mode=0
mipmaps/preserve_alpha_test_coverage=false
mipmaps/alpha_test_threshold=0.5
```

No tracked source file changed during import; custom settings, including backdrop
mipmaps, were retained. See `import-source-changes.json` and `import-settings.diff`.
No texture was smoothed again. Initial pre-import preload errors disappeared after
the first asset import; the second editor/import scan was clean.

Six matched Cove captures and their commands/logs are in
`import-settings-02/shots/` and `screenshots.json`: Forward+ and Compatibility at
1280×720/Mid/720p, and desktop Mobile at 2400×1080/Mid/540p with touch controls.
`comparison.png` puts 4.7 on the left and 4.8 on the right. These are a first visual
checkpoint, not approval or coverage of every required scene/profile. Both engines
warn that the pre-existing baked ground is stale and use the generator fallback.

The first Windows export smoke test launched both intended paths: Forward+/Vulkan
with shader caching, and Compatibility/OpenGL with `compatibility_build` and cache
off. Raw renderer reports are under
`preflight-01/project/build/perf/vo/011/010c-48/`; its default texture imports mean
these reports establish renderer routing only, not matched performance or visuals.

## Validation and known failures

The first corrected 4.8 suite completed **140 cases, 12 failures**, before the
headless-window fix. The complete rerun with that fix finished **140 cases, 13 failures**, recorded in
`suite-reference-window-48.json` and `project-48/build/reference-window-suite-logs/`.
The first run used three jobs; the rerun used six. Inspect actual logs as well as
local-model summaries. The Python town checker and both engines' GDScript map
checks pass. Later focused checks cover the artwork quantization fix separately.

The matched 4.7 control currently reproduces these failures:

| Check | Actual failing assertion / symptom |
|---|---|
| `bag-limit` | B does not decline the full-bag pickup directly |
| `performance` | Story changes do not invalidate cached scenery |
| `ground` | Stored ground fingerprint/geometry differs from current terrain code |
| `beast-growth` | Egg-overflow hatching and cinematic counts |
| `door-voices-touch` | Door replies at the bottom overlap touch exclusions |
| `battlecmd` | Beast action/target arrow/bar correspondence |

These pre-window-fix control failures are not demonstrated 4.8 regressions. They
prevent claiming a clean suite. The model described the performance failure as a
timing threshold; the log instead identifies cache invalidation. Use the log.
Matched controls pass scripts, data, maps, beasts, backdrop art/mipmaps, kennel UI,
mobile menus and arena ladder. Both lesson cases also reproduce on 4.7 (501/571 s).

After the window fix, kennel UI, mobile menus, arena ladder and speech-touch pass
on 4.8; 4.7 passes these plus its four fast checks (**8/8**). Bag-limit and growth
still fail. Both engines reproduce the locker scroll-rail and creator swatch
failures at the corrected viewport. Door-voices-touch now passes its 4.7 control.
The six-job 4.8 rerun's title mouse/gamepad failures both pass when rerun serially;
record them as load-sensitive, not as resolved by a gameplay change. Ring-editor
touch also reproduces on 4.7. Its fixture contained the runaway loop diagnosed
below. No legacy failure has been waived. The artwork failure subsequently passes
on both engines with explicit byte quantization; no comparison tolerance changed.

## Target and feature evidence still in progress

Matched A71 Mobile Min/720p attempts are `010c-a71-47-min-02/phone/` and
`010c-a71-48-min-02/phone/`, repeated in `*-min-03/phone/` using the same frozen APKs
with fresh benchmark state. Each completed one pass with zero benchmark problems
or focus losses. The workload matches: Vulkan Mobile, 1600×720 render size,
2400×1080 window, 60 Hz reported refresh, VSync enabled, 60 fps cap, screen input,
same scene/view counts and draw submissions. Texture memory differs by only 256
reported bytes per sampled scene. Raw medians/p95/p99/draw/memory values are in
`phone-comparison.json`; these are settled scene samples, not sustained play or
cold/warm first-visit acceptance.

| House view | 4.7 pass 1 / repeat, ms | 4.8 default pass 1 / repeat, ms |
|---|---|---|
| First | 33.6775 / 33.391 | 34.3855 / 34.364 |
| Second | 33.489 / 33.4595 | 49.9475 / 50.047 |
| Third | 33.5315 / 33.454 | 49.953 / 49.9775 |

The exact view indices should be read from the raw reports; table rows identify
the three ordered views. Two views consistently fall from about 30 fps to 20 fps
under the beta's defaults, while GPU medians stay near 24 ms. Outdoor medians are
mostly similar; this does not establish global performance parity. Battery
temperature ranges: initial 4.7 32.9–33.1°C, initial 4.8 33.1°C, repeat 4.7
33.2–33.5°C, repeat 4.8 33.6–34.2°C.

An upstream cause has been identified in both exact engine sources:
[Swappy mode mapping fix #123300](https://github.com/godotengine/godot/pull/123300).
4.7's effective default (enum 2) disabled automatic swap-interval/pipeline choices;
4.8's corrected enum 2 enables both. **4.8 enum 0** retains 4.7's effective calls.
The isolated `project-48-swappy0/` and `010c-a71-48-swappy0-04/phone/` tested that
candidate. Its validated 231.6 s pass had zero problems/focus losses and house
medians **33.5765 / 33.564 / 33.442 ms**, restoring the earlier ~30 fps cadence.
House p95 values were **49.111 / 47.29 / 48.772 ms**, comparable to the repeated
4.7 control's **49.422 / 49.732 / 48.585 ms**. GPU medians stayed near 23.5 ms.
Other settled scene medians/draw counts remain comparable; raw comparisons are
in `phone-swappy0-comparison.json`. Battery readings stayed at 35.2°C during this
pass. This single intervention pass is not sustained/multi-device acceptance.
The setting is in the fresh 4.8 integration candidate, not the main 4.7 project,
where enum 0 has the opposite effective behavior.

`phone-cleanup-final.json` and `phone-cleanup-swappy0.json` confirm removal of the
default-mode repeat and Swappy candidate benchmark apps, with player package
identity unchanged. The Swappy report and screenshots survived the host crash.

Both corrected production Web packages build through `tools/make_web.py`, including
the compressed loader, hashed parts, streamed music and icons. Logs are
`production-web47.log` and `production-web48.log`. Rounded gzip first-load payloads
are **122.4 MB (4.7)** and **121.8 MB (4.8)**; both have the same 117.2 MB raw pack.
The README's old ~18 MB estimate is not the size of this source snapshot. Do not
attribute the current asset payload to the engine migration.

The corrected production 4.8 Web package was opened in the in-app browser at a
private localhost origin: title → one A to character creation → click Confirm →
spoken prologue → hold B/S to skip → bedroom and Mom's speech. Captured console
errors/warnings were empty. This verifies a short real exported input/gameplay
path, not sustained browser performance. A separate 4.7 package was also opened.
The earlier superseded build's DOM timeout did not recur on this path. The old
SampleNode pause error has **not** been closed by this smoke test.

The tested binary exposes texture-streaming settings (off by default), contact
shadow settings (off by default), `Trail3D`, and the new import properties above.
This is API availability only, **not** a renderer support/performance matrix.
Streaming trials and ASTC device/renderer validation, sustained/matched native and Web
traces, cold/warm shader checks, dark/indoor/water/battle screenshots and actual
touch/gamepad acceptance remain required. No GI, new contact shadows, streaming,
ASTC profile or effects rollout was enabled.

### Offline ASTC profile checkpoint

`build/perf/vo/010c/feature-trials/` contains a standalone, guarded encoding trial
on three unchanged production images: coast backdrop (1024×512), grass (256×256)
and leaf (128×128), at full size with mipmaps. All 12 encode/decode calls return
OK; sampled private memory peaks at 134 MiB. Profiles 0/1/2/3 are Automatic,
Maximum Quality, Compressed and Maximum Compression. Actual formats are ASTC
4×4, 6×6 or 8×8 according to profile/image; Automatic is not one fixed block size.

| Image | 4×4 bytes / PSNR | 6×6 bytes / PSNR | 8×8 bytes / PSNR |
|---|---|---|---|
| coast | 699,088 / 53.85 dB | 314,992 / 26.27 dB | 174,816 / 43.41 dB |
| grass | 87,408 / 59.10 dB | 40,096 / 32.02 dB | 21,888 / 45.17 dB |
| leaf | 21,872 / 59.57 dB | 10,512 / 29.71 dB | 5,504 / 46.36 dB |

These are software round-trip metrics, not in-game appearance or hardware
support. The unexpectedly worse 6×6 reconstruction was investigated in the
follow-up below; the original table mixes image alignment and codec error. Keep
all production imports unchanged. No profile is
accepted from this trial; target GPU/fallback and visual checks belong to the
remaining feature evidence. Source images, importer settings and smoothing
records were not modified. See `compression.gd`, `compression.json` and log.

### ASTC round-trip follow-up (13 November)

Completed the offline anomaly investigation with `tools/astc_roundtrip_probe.gd`.
Final evidence: `build/perf/vo/010c/astc-roundtrip-04/roundtrip.json` and `godot.log`.
All **18** encode/decode cases pass (three assets × three explicit profiles ×
mipmaps off/on), under the shared resource lock and memory guard; sampled peak
private memory **137 MiB**. The quick suite passes **4/4**, with logs under
`astc-roundtrip-01/quick-logs/`. These are CPU/software checks, not renderer trials.

The exact beta3 [ASTC encoder source](https://github.com/godotengine/godot/blob/c51ff06e8836a70ea905701c081bf94124dcd6ce/modules/astcenc/image_compress_astcenc.cpp#L102-L110)
rounds dimensions up to the block size and **resizes with nearest interpolation**.
For 6×6, coast becomes 1026×516, grass 258×258 and leaf 132×132. These are resized
images, not merely padded borders: cropping the output leaves the old low scores.
Resizing the decoded output back improves them, but introduces another filter.
Comparing against the encoder's nearest-resized input isolates codec error:

| Image | 4×4 PSNR, dB | 6×6 PSNR, dB | 8×8 PSNR, dB |
|---|---|---|---|
| coast | 53.851 | 47.428 | 43.410 |
| grass | 59.102 | 49.540 | 45.167 |
| leaf | 59.565 | 50.159 | 46.357 |

Base-level results are identical with mipmaps enabled or disabled. This resolves
the anomalous codec-quality ordering; it does **not** validate lower mip quality,
GPU sampling, importer size restoration, normals/masks, ASTC device support or
fallbacks. The initial crop/padding hypothesis was rejected by the measurements.
The engine's nearest resize is a specific risk to check before adopting 6×6 for
painted textures. No source texture, import sidecar, smoothing record, production
setting or rollback cache changed. The local model was unreachable at task start;
this investigation used direct measurements and the pinned engine source.

Next 010c checkpoint: isolated streaming eligibility/support trial and target
validation listed above. Keep 010c open and 011 budgets provisional.

## Host crash recovery and safe continuation

Windows System event 2004 records virtual-memory exhaustion at 15:46, 15:55 and
15:57: one 4.7 Godot process consumed roughly 31–33 GB of private commit alongside
about 27 GB for `llama-server` and 7 GB for Firefox. A 4.7 Application event 1000
and the interrupted 4.8 export log record fatal/allocation failures. This is not
a demonstrated 4.8-only crash.

`ring_start.gd` had two synchronous unbounded loops waiting for `STORE_STOP`
after an earlier failed selection. With that destination absent, moving the
destination kept queuing audio commands without yielding a frame. Both loops now
use a bounded cycle, reject a missing destination and yield between moves. The
underlying selection assertions remain visible failures.

The guarded fixture now completes its two attempts in **24 s on 4.7 / 27 s on
4.8**, with sampled private peaks **292 / 308 MiB**, instead of growing to tens of
GB. See `post-crash/bounded-ring-*-verified.json` and the snapshots'
`build/post-crash-verified-logs/`.

`tools/run_guarded.py` provides a timeout and Windows cutoffs: 4 GiB process
private memory, at least 8 GiB available system commit and 4 GiB free RAM. Only the
owned test process tree is stopped. Console launchers are normalized to the full
editor so the monitored process carries the actual allocation. Tests are serial
by default; memory-cutoff failures do not retry. Child exit codes must also pass;
explicit Windows output handles retain the actual Godot logs. Five small-child
tests verify termination, preflight rejection, timeout, exit codes and output
capture without allocating large memory.

The interrupted Windows export was retried under this guard:
`project-48/build/perf/vo/011/010c-48-guarded-postcrash/results.json` confirms both
Forward+/Vulkan and Compatibility/OpenGL, with presets restored. Sampled private
peaks: 793 MiB for Forward+ export, 1,118 MiB for its runtime and 610 MiB for
Compatibility runtime. Both renderer probes pass. The current main 4.7 tree's
four fast checks also pass serially (`post-crash/main-47-quick.json`).

Do not rerun old archived unguarded suites/fixtures. Refresh the current runner,
guard and bounded ring fixture first. The pre-crash six-job run is not accepted
native timing evidence. `post-crash/recovery.json` preserves this checkpoint.

## Fresh pinned integration candidate

`build/perf/vo/010c/integration-03/` contains a new manifest from the combined
working tree, independent import cache, a local portable editor, project features
4.8, default editor 4.8 beta3, CI version 4.8/release beta3 and Android Swappy mode
0. The independent 4.7 project and cache are preserved. No publication or CI dispatch was triggered.

The guarded fresh import used a sampled peak of 898 MiB private memory. Its
**15/15 targeted checks pass in 2m33s**, serially: scripts, data, maps, beasts,
mobile/desktop menus, desktop/touch controllers, desktop/touch prologue,
byte-exact battle art, battle visual geometry, desktop/touch battle focus and ring
editor. See `integration-03/checks.json` and `project/build/integration-logs/`.
This verifies the current confirmation-UI integration in the candidate; further
concurrent edits after its manifest still need validation.

The local model's screenshot comparison claimed extra Start/Pause buttons in 4.8.
Direct inspection of `comparison.png` shows those buttons in both versions. Its
generic grass/shadow observations are not accepted measurements or new art changes.

## Main cutover and rollback

The main project features, launcher default and CI pins now select 4.8 beta 3.
Android Swappy mode 0 preserves the measured effective 4.7 pacing; do not copy
that enum value into a 4.7 project. CI explicitly installs Android platform 36
and build-tools 36.1.0. Active setup instructions name matching beta templates.
No publication or CI dispatch was triggered.

Main cutover logs are under `build/perf/vo/010c/main-48/`. The rollback cache is
`build/perf/vo/010c/main-rollback-47/.godot/`; the intact matched 4.7 source/cache
is `build/perf/vo/010c/import-settings-02/project-47/`, and its editor remains
`C:/Program Files/Godot/Godot_v4.7-stable_win64.exe`. Run 4.7 against that isolated
copy. Never point 4.7 at the main 4.8 cache. A main rollback must preserve the 4.8
cache separately, restore the 4.7 cache and revert only the engine feature/default/
CI pins and Android pacing override, preserving all unrelated work.

The first main import scanned generated `build/` source packs and exited after a
missing Blender configuration, leaving most imports absent despite exit code 0.
The first test was stopped when missing font resources exposed it. A tracked
`build/.gdignore` now excludes generated evidence, exports, source packs and
independent projects from the main asset scan; `.gitignore` admits only this marker.
The corrected import (`import-02.log`) produces all 499 asset imports without
reported errors, at a sampled peak of 990 MiB private memory.

`checks-02.log`, `test-logs-02/` and `cutover.json` record **19/19 passing in
3m27s**, serially, including both map checks, combined UI, controllers, prologue,
battle art/poses/focus and speech on desktop/touch. `town-check.log` separately
reports zero problems. `build/perf/vo/011/010c-main-48-final/results.json` verifies
actual Forward+/Vulkan and Compatibility/OpenGL exports using the exact beta3
editor and matching templates, with export presets restored byte-for-byte.
This is not a claim that the previously recorded 140-case suite is green.

The beta target and comparison visuals are approved. Keep step 010c in progress
until the remaining target/feature evidence above is resolved; do not accept 011
budgets or imply the known full-suite failures passed. Preserve 007's
original-phone recovery, provisional 011 work and all superseded raw records.
