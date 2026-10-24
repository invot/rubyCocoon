# Project rules: Ruby Cocoon

These are the shared project instructions for Codex and Claude. `CLAUDE.md` imports this file; keep the rules here so the two agents follow the same guidance.

Apply these rules throughout the repository. The user's explicit instructions take precedence. The design rules below come from `README.md`, especially Controls, The journey, Systems, Art, UI and audio, Mobile, Editing the maps, and Tests. The touch usability and verification requirements make those design goals concrete. When an intentional design change alters a documented rule, update the relevant documentation in the same change.

## Before editing

- Read the relevant README section and inspect the existing implementation before changing a system. This is a Godot 4.7 game written in GDScript, with no C#.
- Keep changes focused on the request. Preserve unrelated edits, downloaded source packs, and player data.
- Extend the existing shared components and data definitions before introducing a separate implementation. If documentation and behavior disagree, identify the discrepancy instead of silently inventing new design rules.

## Mobile and touch usability

- Treat phones and tablets as primary targets alongside desktop. Design within the existing 1280x720 reference viewport, landscape orientation, and expanding aspect ratio. Wide phones should gain usable space without stretching the art or clipping the interface.
- Use `UIKit` sizing helpers and shared constants in `scripts/ui/ui_kit.gd`. Interactive menu text uses 32 UI units; menu rows and page buttons must be at least 56 UI units tall on desktop and 80 on touch. These are logical UI units, not raw device pixels. Touch sizing must apply even when the on-screen pad is hidden, including the title screen.
- Keep labels readable at normal phone viewing size. Never shrink text, rows, or touch targets to fit more content. Ordinary mobile choice lists belong toward the center and show several rows, with up/down moving the selection and scrolling it into view; choices can also be tapped directly. Use book pagination or a scrolling detail pane for longer content.
- Keep the d-pad, A/B, Start, and Pause available with the mobile Start book and title menu. Modest overlap with menu borders or content is acceptable by the user's preference; keep essential choices and labels reachable. The full map and ring editor may still move the side controls aside. Respect device safe areas.
- Yes/No prompts bind A directly to Yes and B directly to No. On mobile, animate the existing A/B buttons wider and label them `A: Yes` / `B: No`, restoring their normal shape afterward. Do not put Yes and No in a separate paginated list. Long question pages may use A: Next before the decision page.
- Every new action must be usable with touch and with the existing keyboard/gamepad actions. Provide visible tap targets and a usable focus order; do not require hover, a right click, precise dragging, or a physical keyboard for ordinary play. Show clear selected, pressed, focused, and disabled states, with labels or shapes as well as color where needed.
- Preserve one confirmation per press or tap. A single input must not activate a newly opened screen or multiple battle choices. UI taps must not leak through into world movement. Respect the touch clusters' enlarged hit areas and no-world-tap zones.
- Preserve the cardinal d-pad behavior: only one direction at a time, including boundary touches. Keep multi-touch working for B plus movement and the flute's button/direction chords.

## Interface style

- Build screens with the shared `UIKit`, existing window components, and the travel book's established structure. Keep spacing, frames, icons, bars, and feedback consistent with nearby screens.
- Support both **Pixel** and **Classic**, all four gems (**Ruby**, **Sapphire**, **Emerald**, **Hematite**), and runtime changes to those settings. Pixel and Ruby remain the defaults unless the request changes them. Derive colors from `UIKit`; avoid hardcoded palettes in individual screens.
- In Pixel style, retain crisp white text and frames on near-black windows. The gem belongs behind the white in selections, tabs, buttons, tags, and name plates; it must not tint away the white linework. Keep pixel art sharp and aligned to whole screen pixels.
- In Classic style, retain the soft rounded windows, gentle gradients, pale borders, shadows, and shades of the selected gem. Do not mix unrelated visual styles into either theme.
- Use **BoldPixels** for body text, menu entries, and dialogue; use **Lunchtime Doubly So** only for headings, titles, tabs' section headers, name plates, and map names. Use `UIKit.body_px` / `head_px` for crisp sizing. Keep dialogue to three lines per page and text aligned at the top of its box.
- Keep battle bars, grids, targets, and battle text large. On touch layouts, keep commands and the player's grid above Start/Pause and clear of the side controls; retain direct tapping of bars and target tiles.

## Art and animation consistency

- The 3D world follows a smooth, cozy PS2-era look (think *Final Fantasy X* or *Jade Cocoon 2*) with the clean, soft, stylized finish of *Fortnite*: simple readable low-poly silhouettes, textured terrain and architecture, and flat, bright beast colors. Match nearby assets' scale, palette, texture density, lighting, and level of detail. Avoid introducing realistic materials or a different rendering style into a local feature. This direction covers buildings, environments, props, and furniture; the HUD and interface keep their own pixel and classic styles described under Interface style.
  - Textures read as clean and painted: soft gradients, gentle shading, and clear shapes (brick courses, boards, shingles, leaves) without grain, speckle, harsh black cracks, or visible texel blocks. Never sample world, terrain, building, prop, or furniture textures with nearest filtering; use `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC` (or `filter_linear_mipmap_anisotropic` in shaders). Pixel-art icons on shop signs and other graphic glyphs may stay sharp.
  - New or re-baked world textures go through `scripts/gfx/smooth_texture.gd` by running `tools/smooth_textures.gd` (then `godot --headless --path . --import`). It records what it smoothed in `tools/smoothed.json`; never smooth a texture twice or hand-edit that record.
  - Keep borders between ground layers soft and curving rather than stepped. Prefer warm, saturated, slightly softened colors over gritty or desaturated ones. Do not add PS1 artifacts such as vertex snapping, affine texture warping, color banding, or low-resolution rendering; functional dithers that keep the player visible (terrain `hole`, wall fading) stay.
  - Lighting stays soft: filmic tone mapping, gentle glow, ambient occlusion, and blurred shadows. Respect the mobile and web renderers when adding any effect.
- Reuse the established asset packs, importers, shaders, and procedural builders. Inspect the relevant README screenshots and an in-game view when choosing or changing art; filenames alone are not evidence that an asset fits.
- Use `scripts/gfx/beast_model.gd` as the common beast rendering entry point for the overworld, battles, and portraits. Keep line colors in `scripts/data/beast_looks.gd`. Ghosts remain recognizable versions of their beasts in black and purple with smoke, and merges must visibly combine their parents' parts.
- Preserve each region's architectural identity and the recognizable functions of buildings. Shops need their shop fronts and signs; Beast Centers keep their diner identity. New props and landmarks should look native to their town and remain readable from the gameplay camera.
- Keep characters grounded, correctly scaled, and facing the intended direction. Match movement animation to travel speed, avoid sliding feet or floating models, and preserve readable idle, walk, talk, and attack poses.

## World layout and navigation

- Preserve four-way, whole-tile movement and completion of a started step at the next tile's center. Keep keyboard, gamepad, and touch movement consistent.
- Respect elevation for movement, interaction, and line of sight. People, doorsteps, and buildings belong on level ground; ramps and stairs must be approached from their intended ends.
- Keep roads, exits, doors, NPCs, and puzzle targets visible and reachable. The camera looks north from the south: avoid tall objects just south of a path or other important walkable space, including on elevated ground. Preserve the existing wall/building fading and terrain dithering that keep the player visible.
- Follow the town layout and interior conventions in the README: accessible boulevards and plazas; compact stage rooms open toward the camera; visible windows; doors aligned with their actual entrances; stairs leading to reachable landings. Keep indoor NPCs facing the room or their table rather than a wall.
- Arrange interiors using [the staging rules](docs/interior_staging.md): side-wall furniture faces inward, other lounge seating faces the camera, and TVs are implied on the omitted fourth wall; tall furniture stays at the back or sides, low props leave the playing area readable, and door/stair approaches stay clear. Check the real gameplay view as well as the floor plan.
- Give interior walls smooth solid colors or subtle wallpaper, preserving each room's warm or cool color family. Avoid coarse, visibly pixelated wall textures.
- Keep interior floors and rugs smooth and cozy: warm wood boards, soft carpet, quiet tile or stone, and rugs with muted colors and simple borders. Preserve the Beast Centers' diner checkerboards. Avoid coarse, visibly pixelated floor and rug textures.
- Area rugs use 2x3, 3x4, 4x5 or 6x5 tile footprints (either orientation). Prefer 3x4 or larger; use 2x3 for tighter spaces, and never go smaller. Avoid actual squares and long, narrow runners. Fit rugs clear of walls, stairs and hazards without changing collision or movement tiles; furniture may stand on a rug.
- Preserve mandatory tutorial sightlines, story gates, and puzzle solutions. A decorative or layout edit must not let the player bypass a teacher, become trapped, or lose access to a required interaction.

## Game design and writing

- Preserve the egg, training, growth, flute capture, and merging loop; the elemental roles and battle ring; and the documented progression gates unless the request intentionally changes them. Do not adjust balance or unlock requirements incidentally to a UI or art task.
- Make the next objective understandable through the existing story and contextual hint systems. Keep hints in step with completed objectives and avoid revealing knowledge the hero has not learned yet.
- Keep guided lessons focused on the one action being taught, with the existing protections against losing or getting stuck. New interface choices must not break a lesson's restricted selections or automatic targeting.
- Use established character, beast, place, move, and item names. Match the surrounding dialogue's tone and keep player-facing wording clear, concise, and consistent with the current controls.

## Implementation, saves, and performance

- Put reusable rules and content in the existing `scripts/core/`, `scripts/data/`, and autoload systems as appropriate. Keep presentation in the relevant world, battle, graphics, or UI component. Avoid duplicating game rules inside a widget or preview scene.
- Preserve existing saves and settings when changing stored data. Supply sensible defaults for missing fields, and keep save slot identity, screenshots, and play time consistent. Saving remains the established phone call flow unless the request changes it.
- Keep mobile and web compatibility in mind: Mobile renderer on phones, Compatibility renderer and a single-threaded export on the web. Avoid effects or APIs that only work in the desktop renderer.
- Protect the mobile 60 fps target and quick title-screen response. Preserve chunked scenery, LODs, caching, and background loading. Avoid unnecessary per-frame allocations, map-wide rendering work, extra shadow casters, or blocking asset generation on the main thread. Measure relevant performance when making a costly rendering or loading change.
- Use the existing asset conversion pipeline, keep original downloads untouched, run `tools/smooth_textures.gd` on new or re-baked world assets, and rescan with `godot --headless --path . --import` after adding baked assets. Keep new assets' attribution and license information in `CREDITS.md` and `licenses/` as appropriate.

## Verification and screenshots

After implementing a player-facing feature or changing visible behavior, launch the game in a real window, inspect the changed feature, capture representative in-game screenshots, and show the screenshots to the user in the final response. Use isolated test state rather than player saves. Prefer the existing screenshot harness and add a focused preview scenario when needed. Report any inability to launch or capture honestly.

- Use focused `--scene=...` modes from the README. For save/load work, set an isolated `--save_dir=res://build/.../`. Do not overwrite, delete, copy from, or migrate real player saves for testing. Put temporary captures under `build/shots/`; update `docs/screenshots/` only when deliberately updating documentation.
- For UI changes, inspect the affected states at desktop 1920x1080 and a landscape 20:9 phone layout at 2400x1080 with `--touch`. Also check the 1280x720 reference viewport when space is tight. Exercise the actual taps, focus navigation, pagination, long labels, and empty/full lists relevant to the change. A large screenshot alone does not prove a touch target works.
- Check both UI styles and the four gem palettes when changing shared styling. Capture representative desktop and touch states for layout changes. Inspect captures for small text, clipping, overlap, hidden selections, and art mismatches before reporting success.
- Run checks appropriate to the change. For code/data changes, use `bash tools/run_tests.sh quick` and the affected named scenarios; use the broader suite for changes spanning systems. For map/layout changes, also run both map checkers:

  ```text
  godot --headless --path . --script res://tools/check_maps.gd
  python tools/town_check.py
  ```

- `godot` means the local Godot 4.7 executable; resolve its path rather than assuming it is on PATH. `tools/run_tests.sh` supports a `GODOT` override. See the README and the runner for available scenarios and invocation details.
- Check logs for script errors and missing resources. Headless checks do not replace the required windowed inspection of visible changes. Documentation-only changes need a review of links, commands, and consistency rather than launching the game.
- In the final response, state what changed, the relevant checks performed, and any unresolved limitations. Include the captured in-game screenshots for visible changes; never claim a device, interaction, test, or capture was verified if it was not.
