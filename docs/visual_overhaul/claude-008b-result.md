# 008b: Claude's visual review and recommendations

Status: **approved by the user on 2026-11-12** ("Approve and continue"). Integration and measurement belong to Codex (§"For Codex to integrate"). No production code, lighting or art has been changed yet.
Answers [claude-008b-handoff.md](claude-008b-handoff.md); diagnosis in [008-shadow-budget.md](008-shadow-budget.md).

## How the candidates were rendered

`build/vo008b/candidate.tscn` (throwaway, under `build/`) runs the unchanged `main.tscn` and overrides only the
requested light/caster properties from `--cand_*` arguments, logging what it changed to `build/vo008b/cand.log`.
Windowed Mobile renderer, Mid, isolated `--prefs_path`/`--save_dir`, through `tools/local_resource.py`.
These are desktop captures for visual judgement, not performance evidence.

Captures: `build/shots/vo/008b/`. Review boards: `008b_indoor_board.png`, `008b_indoor_rejected.png`,
`cove_lamp_crop.png`, plus on/off crops of the phone run (`path_center.png`, `cove_center.png`,
`rue_royale_full.png`, `hero_house_full.png`).

## 1. Outdoors (Path, Cove, Rue Royale): keep the current casters (no-op)

From the phone on/off pairs at gameplay scale:

- **Buildings and large trees** cast the shade that gives each scene its depth (the Path house's shadow across the
  lane, the Cove houses' shadows over the plaza edge). Without them the scenes go flat. Keep.
- **People**: the light shadow carries the direction; contact shadows keep feet planted when it's off, but the
  people read as lit differently from the buildings beside them. Keep.
- **Street lamps** (`assets/props/lamp.res`, four batches in Cove): tested shadowless. The lamp's base loses all
  contact and it becomes the one upright object with no shadow pointing away from the sun, so it looks pasted on
  (`cove_lamp_crop.png`). Keep lamps casting. Not checked: shimmer of the thin pole's shadow while the camera
  moves; Codex can check this in the moving route if it's a concern.
- **Signs / rails / pier pieces**: small and low; their shadows are hardly visible at gameplay scale and I saw no
  problem either way. No change recommended without a measured saving that justifies one.
- **30 units / 2 splits** outdoors covers everything visible in these views. No change.

Recommendation: no outdoor caster or distance change. The shadow cost difference measured on the phone
(1.6-3.7 ms) mostly comes from the casters that matter visually, and removing all of them didn't fix the 30 fps
pacing anyway.

## 2. Indoors: 100 units / 4 splits → 30 units / 2 splits (candidate for approval)

`world.gd` indoor sun (around line 5185) leaves the engine defaults (100 / four splits). Recommended settings,
the same as the world and battle suns:

```gdscript
sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
sun.directional_shadow_max_distance = 30.0
```

Only for the interior path (`not open_air`); open-air roofs already go through `OutdoorLight`.

- **Hero's house, touch 2400×1080 and desktop 1920×1080**: the hero, Mom, armchair, table and window shadows
  are all kept; edges are a little crisper; nothing is clipped at the room's front or back edges.
- **Beast Center (a wide room)**: identical coverage at 30.
- **Rejected 20 units / 2 splits**: the hero's shadow by the front door disappears, because the camera is further
  than 20 units from the front of the room. 30 is the smallest of those tried that covers the room
  (`008b_indoor_rejected.png`).
- Not checked: very large interiors (arena halls, towers). The camera follows the hero, so coverage depends on the
  camera's distance rather than the room's size, but Codex should spot-check the largest interior.
- The phone house timing was unstable, so the saving still needs its own measurement.

## 3. Hatch and merge stage: no change; cost experiment requested

The hatch film at 4.9 s (`hatch_on.png`): the egg, tongs and mechanism read clearly in the misty, dark chamber,
with light pooled on the subject (as the film mood rules require). OculusKey is the only shadow caster.
My attempt to switch its shadow off for a comparison didn't take effect (no log entry), and the merge capture at
6 s landed in the film's white flash, so I have **no valid on/off film pair**. I'm not recommending any change
to the films' lights.

Requested from Codex: a focused cost run of the hatch and merge films (peak frames, including `enlarge()` for
merge) with OculusKey's shadow on/off, and matched captures at the egg-in-tongs, hatch reveal and merge
mid-frames. I'll judge those visually before any light layer is removed.

## For Codex to integrate

1. Indoor sun: 30 / 2 splits as above (after user approval). Measure on desktop (fresh attempt) and phone.
2. Spot-check the largest interior for clipped shadows at 30.
3. Film cost experiment as in §3.
4. Run quick, vo-shadow-route, battle-stage.
