> **Read [audit.md](audit.md) first.** It records the user's decisions of 12 November 2026, which override this document where they disagree (palette, ground motif, per-biome cliffs, remodelled people and beasts, performance first, interface softening only later, in Phase U). Work is done one step at a time from [steps.md](steps.md).

# Ruby Cocoon: Visual Enforcement Checklist

Companion to the Visual Standards and Whole-Game Overhaul Plan — 12 November 2026.

This checklist is a proposed production process. It does not claim the validation tools or completed asset inventory already exist.

## Direction to preserve

Animal Crossing-like environmental cohesion and restrained materials; Ruby Cocoon's current human/beast proportions and identities; serious danger and dark moods; the existing interface structure with softer shared presentation; the README's minimum requirements and renderer support.

Every active asset is reviewed. Suitable assets are adapted. Repeated fundamental failures move to custom modeling and texture painting. No code or asset work is authorized by this planning document alone.

## Before the overhaul starts

- [ ] Save an unchanged, reproducible visual and performance baseline using isolated test state.
- [ ] Build an asset ledger that includes embedded resources, procedural builders, variants, and LODs.
- [ ] Build a separate map/room/battle/film/story-state coverage ledger.
- [ ] Record source licenses, runtime uses, import recipes, hashes, and dependent derivatives.
- [ ] Mark unused downloaded sources separately; preserve them untouched.
- [ ] Approve material and scale sheets plus representative sunny, indoor, dark, dry/industrial, battle, and interface scenes.
- [ ] Calibrate geometry, texture, material, and performance budgets against these scenes and target-class hardware.
- [ ] Reconcile contradictory documentation: Fortnite target, deliberate nearest-scaled 3D output, legacy exceptions, and stale retro production notes.

## For every asset family

- [ ] Name the applicable exemplar and all runtime uses.
- [ ] Record the worst variants, closest required camera, motions, and material combinations.
- [ ] Check silhouette before texture polish.
- [ ] Remove visible voxel steps, unintended facets, broken normals, seams, and floating parts.
- [ ] Preserve scale, footprint, interaction anchors, navigation, and regional identity.
- [ ] Use approved materials with matching feature scale and restrained surface detail.
- [ ] Review actual imported/compressed textures and final runtime overrides.
- [ ] Distinguish intentionally subtle finishes from automatic rescue finishes.
- [ ] Verify LODs in motion and in a dense real scene.
- [ ] Review beside other approved families, not only in isolation.
- [ ] Review every required variant, pose, ghost state, creator option, or representative risky merge combination.
- [ ] Rebuild after an initial adaptation plus two targeted revision rounds fail the same fundamental requirement; rebuild earlier if the source cannot support the needed result.
- [ ] Regenerate dependent icons, portraits, murals, measurements, and baked/cached resources.
- [ ] Record evidence, checks, performance, remaining defects, and approval fingerprints.

## Visual rejection conditions

Reject an asset or scene if any of these appears in normal play or a required close-up:

- Visible cube-built nature, retro pixelation, or arbitrary low-sided curvature.
- Gritty photographic detail, patchy random mottling, harsh black material cracks, or smeared textures.
- Material-feature scale that clashes with neighboring objects.
- An obvious source-pack style mismatch.
- Unintended plastic shine or a generic finish standing in for material design.
- Building interiors visible from outside; detached doors/windows; broken roof or wall joins.
- Exposed water cuts, floating waterfall sides/lips, or visible gaps against cliffs.
- Sliding feet, floating bodies, mismatched poses, or conspicuous merge intersections.
- Lighting that hides faces, crushes paths, bleaches color, or relies on optional effects to look finished.
- Hidden choices, unclear focus, unreadable phone labels, or touch/input regressions.

Straight edges and deliberate rock planes are allowed when designed and consistently finished. Polygon count alone is never the aesthetic test.

## For every scene and applicable state

- [ ] Inspect the real gameplay camera, not just the map overview.
- [ ] Include close door/window/shoreline crops with the hero where relevant.
- [ ] Check density, quiet space, color hierarchy, material relationships, grounding, and route visibility.
- [ ] Include changed story geometry, obstacles, water levels, and dressing.
- [ ] Inspect battle reverse and action shots, foreground occlusion, enclosure, and peak effects.
- [ ] Review dark scenes with their intended threat and lighting intact.
- [ ] Check desktop 1920×1080 and 20:9 touch 2400×1080; use 1280×720 for tight layouts.
- [ ] Test actual low-resolution world rendering at the README's starting presets, including smooth enlargement.
- [ ] Exercise affected taps, navigation, scrolling, confirmation, movement, and target selection.
- [ ] Review all four gems when shared styling changes.
- [ ] Check supported renderer/preset combinations and a real browser export where relevant.
- [ ] Profile relevant costs on representative hardware; label desktop measurements honestly.
- [ ] Read logs for build/script/resource errors before interpreting images or model feedback.

## Technical checks

- [ ] Run the project's quick checks and affected named scenarios.
- [ ] Run both map checkers for map/layout changes.
- [ ] Run exterior and Cove-specific checks for relevant building work.
- [ ] Run texture coverage and relevant beast/battle checks.
- [ ] Run broader regression checks for shared-system changes.
- [ ] Use the managed smoothing/import pipeline for applicable new or re-baked world textures; never double-smooth or hand-edit its record.
- [ ] Keep captures in `build/shots/` and test state in isolated `build/` directories.
- [ ] Preserve player saves, unrelated edits, original packs, caching, chunking, and background loading.

## Approval rules

**All applicable gates must pass:** provenance, geometry, surface, integration, motion, performance, presentation, and coverage.

Approval records identify the standard version, source/output hashes, recipe, material version, reviewer, and evidence. Relevant changes invalidate dependent approvals. Unknown active assets remain unreviewed. Image differences and local vision-model feedback assist review; neither grants aesthetic approval.

No release blockers or major defects remain. Minor defects must be named and must not conceal unfinished families. Unavailable physical-device testing remains an explicit limitation.

## Completion report

Report approved/remaining counts separately for assets, variants, scenes, and states; unresolved defects; tested devices/renderers/presets; relevant checks; before/after performance; evidence locations; and any unavailable verification.

Finish with a side-by-side review of a home, route, desert, industrial battle, haunted location, portrait, title, and interface. They should retain distinct identities and moods while looking like one game.
