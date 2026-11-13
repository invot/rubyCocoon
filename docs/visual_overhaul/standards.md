> **Read [audit.md](audit.md) first.** It records the user's decisions of 12 November 2026, which override this document where they disagree (palette, ground motif, per-biome cliffs, remodelled people and beasts, performance first, interface softening only later, in Phase U). Work is done one step at a time from [steps.md](steps.md).

# Ruby Cocoon: Visual Standards and Whole-Game Overhaul Plan

Planning edition — 12 November 2026

This is a proposed production standard, based on the supplied Animal Crossing references, the project instructions, the current README, selected rendering code, and existing project screenshots. It authorizes no implementation by itself. No game code, assets, settings, or player saves were changed to prepare it. Existing captures were inspected; the game was not launched for this planning review.

## 1. The decision

Ruby Cocoon should look like a coherent, carefully made world: rounded, tactile, clean, inviting, and modern. Animal Crossing is the primary reference for environmental cohesion, material restraint, terrain edges, foliage, water, and soft light. Ruby Cocoon retains its own people, beasts, architecture, story, and combat identity.

The goal is not to make every object equally detailed. The goal is to make every object look as though the same art team designed it for the same camera, scale, lighting, and material system.

Every shipped visual asset and every rendered variant must be reviewed. Assets that meet the new standard may remain; others must be reworked or replaced until they pass. An asset's familiarity, source pack, previous approval, or working collision does not exempt its appearance.

One overhaul means one art direction, one inventory, one acceptance standard, and one completed release. Internally, the work must proceed in controlled stages so a mistake in the foundational style does not get replicated across the game.

### Confirmed direction

| Decision | Requirement |
|---|---|
| Human and beast proportions | Preserve current proportions and recognizable designs. Improve modeling, shading, textures, rigging, and animation without turning the cast into Animal Crossing characters. |
| Environments and materials | Move substantially toward the supplied Animal Crossing references: soft forms, controlled detail, natural transitions, tactile materials, coherent lighting. |
| Interface | Preserve the structure, control model, information hierarchy, and established screen flows. Soften materials, frames, and presentation through shared components. |
| Threat and atmosphere | Keep serious danger and dark moods. Express them through the same visual language rather than switching to gritty realism or retro horror. |
| Production | First adapt suitable existing assets using shared tools and selective custom work. If repeated adaptation fails, rebuild the asset with custom modeling and texture painting. |
| Minimum hardware | Preserve the README's requirements and supported rendering paths. Its requirements remain estimates until tested on representative hardware. |

### Priority when requirements compete

1. Gameplay readability, navigation, input access, and save compatibility remain intact.
2. The asset must meet the common visual standard.
3. The implementation must fit the target hardware.
4. Preserve useful source geometry and authoring effort where compatible with the first three requirements.

If an asset cannot satisfy both style and performance, simplify its design, construction, material count, or placement. Do not solve the problem by returning it to visible voxel forms or by quietly increasing the minimum requirements.

## 2. What to learn from the reference images

These observations concern the supplied pictures, not claims about Nintendo's internal technology.

**Forms are deliberate.** Trees read as crowns, leaves, trunks, and roots. Furniture reads as constructed objects. Buildings have substantial roofs, frames, and doors. Rock facets exist, but they describe designed stone forms rather than arbitrary decimation.

**Large shapes lead.** A tree's crown is visible before its leaves; a building's roof and entrance are visible before its shingles; a shoreline's curve is visible before its foam. Surface detail reinforces those large shapes.

**Materials have texture without becoming noisy.** Wood has restrained boards and grain; stone has broad color changes; foliage has organized leaf shapes. Large areas remain quiet enough for characters and interactions to stand out.

**Edges are treated consistently.** Cliffs have softened corners and a readable turf lip. Water meets banks continuously. Roots and furniture feet ground their objects. Roof and wall pieces feel connected.

**Light gives volume without crushing color.** Lit and shaded faces remain related. Contact shade helps objects sit on the ground. The night reference changes the mood while keeping the same shapes and material vocabulary.

**Repetition is controlled.** Related trees look related; variations do not introduce a new rendering style. Repeated materials retain a common feature scale.

Adopt these principles. Do not reproduce Nintendo's proprietary models, texture motifs, interface assets, characters, or recognizable compositions. In particular, Ruby Cocoon does not need Animal Crossing's triangular grass pattern to achieve equally coherent ground.

The winter portrait has a different framing and a visibly grainier finish than most landscape references. Use it for snow accumulation, warmth, and shape treatment; do not turn its apparent grain into a global texture requirement.

## 3. What the current project evidence tells us

This is a targeted planning review, not a complete current-build audit. Saved screenshots can lag the working tree. Filenames containing `voxel` or `psx` identify implementation history; they are not sufficient evidence that every asset using that code looks wrong.

Nevertheless, there are specific issues worth addressing:

| Evidence reviewed | Implication for the overhaul |
|---|---|
| README Art names Fortnite while the new request names Animal Crossing. | Replace the competing direction with this more precise brief during implementation. |
| README describes legacy PS1 house sources, PSX robots, and older legendary models alongside newer beasts and nature packs. | Audit each family together; source packs must lose their independent visual identities in the finished game. |
| Saved Coastal Path screenshot contains cube-like crowns, rounded crowns, strongly varied bush forms, spiky grass, and different ground-detail frequencies. | Select one foliage construction language and one surface-detail hierarchy. Recoloring alone will not reconcile silhouette differences. |
| Saved bedroom and Beast Center captures show relatively quiet walls/floors beside differently treated furnishings and characters. | Review complete compositions, including material response and edge construction, rather than only individual texture quality. |
| `surface_finish.gd` adds generic soft/brushed textures to otherwise bare materials. | A texture being present is a technical property; it does not establish an authored, appropriate material. |
| `beast_model.gd` documents both newer rigs and legacy rendering paths. | Keep the common entry point, but require every path to reach the same visual and animation standard. |
| `prefs.gd` deliberately uses nearest filtering when enlarging the final 3D image. README documents this pixel effect. | Smooth world textures alone cannot ensure a modern image at lower resolutions. The final image resolve must also be reviewed and changed as part of implementation. |
| Some older material builders still contain nearest-filter assignments. | Audit final runtime materials and their overrides. A text search alone cannot establish which assignments survive to the screen. |
| Existing texture audit allows certain procedural patterns and listed effects. | Reconcile its exemptions with the chosen standard; an exception must describe an intentional result, not a loophole. |
| Smoothing tools still contain comments describing a PS2-era target. | Update stale production instructions when the direction is adopted, and ensure their actual output supports the new target. |

No blanket smoothing, subdivision, saturation increase, or global shader can independently repair all these differences. Geometry, materials, lighting, composition, motion, and image reconstruction must agree.

## 4. The non-negotiable visual contract

The following requirements apply to everything that can appear in play, menus, films, portraits, or promotional in-engine renders.

1. **No visible voxel construction.** Natural forms must not read as stacked cubes, stepped blocks, or rectangular canopy masses.
2. **No retro rendering treatment.** No nearest-scaled 3D image, visible texture pixels, vertex snapping, affine warping, or deliberate PSX/PS2 degradation.
3. **No imported-pack identity.** An asset must look native beside approved Ruby Cocoon assets, regardless of its source.
4. **No accidental faceting.** Polygon boundaries must not create unintended angular silhouettes or patchy shading.
5. **No noisy substitute for material design.** Grain, speckle, black cracks, and contrasty random mottling cannot stand in for wood, stone, cloth, or foliage.
6. **No bare default-looking objects.** Physical surfaces require a designed texture or an approved texture-sampling material. Subtle is acceptable; arbitrary noise is not required.
7. **No disconnected construction.** Building pieces, doors, windows, banks, cliffs, waterfalls, furniture feet, and prop contacts must join convincingly.
8. **No quality cliff between systems.** Overworld, interiors, battles, films, icons, and portraits must represent the same world and same asset designs.
9. **No mood-based style exemptions.** A haunted tree and a cheerful tree follow the same modeling and material rules.
10. **No approval from automation alone.** Technical checks establish validity; visual review establishes aesthetic acceptance.

An explicitly faceted boulder, a wooden box, or a rectangular building is allowed. Their shape must be intentional, with suitable edges, shading, construction, and surface treatment. The prohibition concerns crude construction and accidental faceting, not every straight edge.

## 5. Shape language and modeling

### 5.1 Primary, secondary, and tertiary forms

Every asset must have three levels of information:

- **Primary:** the silhouette and major masses that make it recognizable in a thumbnail.
- **Secondary:** meaningful construction such as cushions, roof courses, branches, stone planes, clothing layers, and framed openings.
- **Tertiary:** restrained grain, stitching, subtle wear, veins, small grooves, and highlights.

Primary forms must remain readable when textures are removed. Secondary forms must survive normal gameplay distance. Tertiary detail may disappear at distance without changing the asset's identity.

As a working composition guide, aim for roughly 70% quiet surface, 20% broad material or construction variation, and 10% accents. This is an art-review heuristic, not a pixel-count formula. Important faces, signs, and patterned garments may need different distributions.

### 5.2 Edges and curvature

- Round exposed furniture, architectural trim, trunks, roots, and everyday props enough to catch a soft highlight where the camera can perceive one.
- Do not apply the same bevel width to every object. Compare edge thickness to object scale and the approved exemplars.
- A rounded object must not reveal a few large planar sides during ordinary play or a required close-up.
- Preserve designed hard edges: a door frame should not melt; a book should not look inflated; a masonry block should not become a pillow.
- Smooth normals must agree with the geometry. They cannot disguise a visibly angular outer contour.
- Eliminate unintended seams, inverted faces, broken tangents, shading wedges, floating pieces, and thin surfaces that disappear from reachable cameras.
- Avoid global subdivision of imported meshes. Rebuild or retopologize the relevant forms where subdivision would preserve bad proportions or create unnecessary geometry.

### 5.3 Consistent detail, not identical polygon counts

A person, a pebble, and a house should not use the same number of triangles. Allocate geometry according to screen size, silhouette curvature, deformation, visible repetition, and closest required camera.

**Provisional authoring ranges**, to be calibrated in the reference scenes:

| Class | Initial LOD0 planning range | Normal material target |
|---|---:|---:|
| Small repeated prop | 100–800 triangles | 1 |
| Chair, sign, medium prop | 400–2,000 | 1–2 |
| Rock or substantial shrub | 300–1,800 | 1–2 |
| Repeated tree | 1,000–3,000 | 1–2 |
| Main human character | 4,000–10,000 | 1–3 |
| Ordinary beast | 2,000–8,000 | 1–3 |
| Small building shell and major trim | 3,000–12,000 | 2–4 |
| Large landmark | Separate measured budget | Separate measured budget |

These are production starting points, not current measured asset counts, automatic pass/fail limits, or promises that a scene will run at 60 fps. Repeated trees may require lower counts. A silhouette-critical beast may justify more. Count complete rendered assets, including foliage cards, clothing, attachments, and duplicate render passes.

Start LOD validation with no more than approximately one reference-viewport pixel of silhouette displacement for prominent subjects, and two for distant scenery. Calibrate through motion tests at 1280×720. Reject visible popping, missing leaf masses, collapsing faces, or changes to an interaction's apparent location regardless of the numeric result.

## 6. Scale and construction

Keep one tile equal to one world unit and the hero approximately 1.44 units tall. Preserve current human and beast proportions; do not make the hero shorter to rescue an undersized building.

- Use the hero as the measuring reference in every building and furniture review.
- Ordinary exterior doors use the existing full-size reference: approximately 1.8 units tall and 0.85 wide; never below 1.7 tall. Preserve established taller regional door standards.
- Ground storeys must clear the full door and its trim. Use the existing 2.3–2.8-unit general storey range and documented regional exceptions.
- Door leaves, frames, windows, sills, shutters, signs, lamps, and awnings must physically belong to their wall.
- Door leaves should remain within about 0.1 units of the associated wall face, as required by the existing project rules.
- Furniture seats, table tops, handles, steps, railings, and counters must make sense beside the unchanged cast.
- Preserve authored footprints, interaction anchors, stairs, door alignment, battle pad positions, and navigation unless an explicitly reviewed layout change is necessary.
- A visual mesh may become rounder without silently enlarging collision or blocking a clear path.

Build an approved scale sheet containing the hero, another human body type, a familiar beast, door, chair, bench, counter, lamp, fence, window, and one-storey house. Every new asset family must be compared against it.

## 7. Texture standards

### 7.1 The finish

Textures should read as clean, gently painted material with broad, intelligible features. They may suggest craft, soft wear, and natural variation. They must not look like noisy photographs, smeared low-resolution pack art, or a flat color covered by generic grain.

- Prefer broad gradients and purposeful shapes over random high-frequency detail.
- Keep board seams, mortar, leaf divisions, and cloth patterns readable but subordinate to the object.
- Avoid pure-black material crevices. Deep black remains available for intentional eyes, lettering, holes, and graphic accents.
- Separate color design from illumination. Do not paint a strong directional sun into a texture that will be used under different lights.
- Restrained baked contact shading is acceptable when it does not double with runtime shade or darken movable joints.
- Use consistent feature scale: a brick, plank, leaf, or stitch must not change apparent size arbitrarily between adjacent objects.
- Avoid obvious mirrored grime, repeated stains, stretched UVs, triplanar projection seams, atlas bleeding, and repeated large spots.
- Flat, quiet painted areas are desirable. The texture requirement does not demand visible noise on every surface.

### 7.2 Resolution and texel density

Texture resolution is chosen from projected use and UV coverage. Merely giving every asset a 1024-pixel map would waste memory and still produce inconsistent detail.

Begin with approximately **128–256 source texels per world unit** for ordinary close world surfaces, then calibrate against the closest intended camera. Allow greater density for faces and readable graphics, and less for distant scenery. This is a proposed authoring baseline, not a measured current project value.

- Comparable neighboring surfaces should normally stay within a factor of two in useful texel density, and must have matching apparent material-feature size.
- Use shared 256–512 maps or atlas regions for small repeated props where adequate.
- Use 512–1024 maps for many unique characters, medium assets, or larger shared material sets, only when screen use warrants them.
- A 2048 map needs a demonstrated purpose, such as an efficiently packed building family or large hero asset. It is not a default quality setting.
- Do not require 4K world textures for the target look.
- Inspect imported/compressed textures, not just uncompressed authoring files.
- Count resident memory, mip chains, atlas occupancy, duplicated embedded images, and platform compression in the budget.

The ranges above are adjustable production defaults. A clean 256 map can pass; an ugly 2048 map fails.

### 7.3 Filtering and antialiasing

World albedo textures use the project's linear, mipmapped, anisotropic filtering convention. Sample data textures according to their data semantics; a nearest-filtered tile-ID map is not a visible pixel-art surface and must not be blindly changed.

The final 3D image must also reconstruct smoothly when rendered below display resolution. Replace the deliberately nearest-scaled world presentation during implementation with a measured smooth resolve suitable for the available renderers. Avoid solving pixels by making the entire image excessively blurry.

UI graphics need their own review. Existing crisp symbolic icons can stay crisp when they fit the softened interface. Do not apply a global world-texture rule to fonts, masks, lookup maps, or every canvas element.

Godot's image-import settings, including mipmaps and compression, affect the shipped result; authoring-file size alone is not a quality guarantee. See the official [image import documentation](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html).

### 7.4 Smoothing and source discipline

Keep original downloads untouched. Work from attributed, reproducible derivatives.

Use the existing smoothing pipeline and its managed record for applicable new or re-baked world textures. Never smooth the same output repeatedly, and never hand-edit `tools/smoothed.json` to force a pass. Preserve source hashes and processing history.

Smoothing removes unwanted frequencies; it cannot invent well-designed boards, repair bad UVs, create a rounded silhouette, or turn muddy shading into convincing painted material. If its output is muddy, repaint or rebuild from a clean source instead of adding more passes.

Review whether the current cleanup parameters suit each new material family before mass processing. If the pipeline needs adjustment, version that adjustment and regenerate affected derivatives from clean sources. Preserve the established exclusions and deliberate exceptions until they have been explicitly reviewed; do not run an indiscriminate batch over every image.

## 8. Shared material library

Extend the existing material/shader systems into a small approved library. Avoid a separate shader for each asset or a single generic finish that makes all objects look alike.

| Family | Required reading | Common failure |
|---|---|---|
| Painted timber | Warm broad grain, clear boards, softly treated edges | Black plank cracks or noisy bark used as furniture wood |
| Natural timber/bark | Large directional structure, gentle variation | Brown mottling with no relation to the trunk |
| Plaster/stucco | Broad color, subtle finish, restrained seams | Sandpaper noise or pure flat default material |
| Masonry/stone | Designed block or rock forms, modest crevice contrast | Dirty photographic stone or harsh polygon patches |
| Cloth | Soft diffuse response, readable folds and large patterns | Plastic glare, tiny weave that shimmers |
| Upholstery/rugs | Tactile but quiet, consistent binding and padding | Busy repeating fabric or paper-thin cushions |
| Foliage | Related greens, leaf-group structure, soft highlights | Random blobs, disconnected alpha scraps, plastic leaves |
| Ceramic | Clean broad highlights, substantial rim | Mirror glare or perfectly flat chalk |
| Metal | Broad controlled highlights; material-specific color | Noisy brushed patterns or mirror chrome everywhere |
| Skin/fur/scales | Soft volume; deliberate anatomy and markings | Uniform gloss or granular detail across the whole body |
| Water/ice | Controlled depth, transparency, highlights and motion | Glass slabs, hard seams, visual noise |
| Magic/emission | Shaped light and clear timing | Featureless overexposure hiding the asset |

Useful provisional roughness bands are approximately 0.7–0.95 for matte plaster, stone, cloth, and foliage; 0.45–0.8 for painted wood and subdued skin/fur; and 0.25–0.6 for glazed or polished accents. These are material-tuning starting points, not universal engine-independent values. Judge the rendered result under the shared light rig.

Do not give every beast a conspicuous satin finish. Species markings, fur, shell, metal, and scales should differ within a coherent rendering response. Preserve elemental and species identities.

In the eventual approval tool, distinguish **intentional approved use of a subtle shared finish** from **an automatically applied rescue finish**. An unreviewed rescue finish must not silently count as a completed asset.

## 9. Palette and color hierarchy

Use a common color philosophy with regional palettes, not one palette imposed on every biome.

- Build colors around readable light/middle/dark relationships.
- Keep most environmental colors below the visual intensity of important actors, interactables, elemental effects, and selected interface states.
- Use saturated color in organized masses, not maximum saturation everywhere.
- Prefer colored shadows over muddy gray or crushed black.
- Preserve separation between paths, walkable ground, obstacles, water, and elevation changes.
- Do not rely on hue alone to communicate interaction, weakness, danger, or selection.
- Make the gem an interface accent, not a global world tint. Ruby, Sapphire, Emerald, and Hematite must all work.
- Do not arbitrarily randomize a plant's hue. Use curated variants within a species and biome range.

For each biome, approve a palette sheet containing ground, path, cliff, masonry, timber, foliage, water, sky, shadow, practical lights, and two accent colors. Include the hero and a typical beast on the sheet to check separation.

Exact swatches should be chosen from in-engine exemplars. Inventing a finished set of hex values before seeing the material and lighting system would create false precision.

## 10. Terrain, cliffs, banks, and paths

The movement grid remains. The visible landscape must not expose it as a collection of stacked blocks.

- Round and vary exposed terrain contours at an appropriate scale while preserving the walkable tile centers and authored elevations.
- Use consistent turf thickness, bank treatment, cliff corner radii, and path-edge softness across biomes.
- Keep cliff strata broad and organized. Avoid a separately noisy texture on every vertical face.
- Paths must form coherent surfaces through corners, crossings, slopes, and town entrances.
- Transitions need intentional intermediate treatment: turf lip, packed earth, gravel shoulder, shoreline sand, moss, or a constructed border as appropriate.
- Do not use a narrow strip of randomly blended pixels to hide a fundamentally stepped contour.
- Natural slopes and cliffs differ from constructed retaining walls. Both share surface-detail scale and edge quality.
- Prevent texture stretching and direction changes at corners and ramps.
- Keep feet, doorsteps, NPC positions, and furniture contacts aligned with the actual surface.
- Preserve terrain dithering and wall fading used to keep the player visible; these functional effects are not retro decoration.

Test both the broad view and close gameplay crops. A map overview proves layout; it does not prove bank quality at the hero's feet.

## 11. Trees, shrubs, grass, flowers, and rocks

### Trees and shrubs

User refinement, 12 November 2026: the approved broadleaf direction is [rev_003](art_candidates/broadleaf.md):
simple pillowy crown domes with soft painted edges, without a projected pattern of individual leaves. Start later
tree/shrub families from that visual grammar while preserving regional species. The supplied Gostbento Low Poly
Nature Pack palms are rejected. This selects a look; it does not waive measured budgets, scale/material prerequisites,
real-game checks or the rule against crude block/primitive construction. Approved candidate files stay immutable.

Choose a common construction grammar: substantial tapered trunks and roots; rounded crown masses; designed leaf clusters; restrained supporting leaf texture. Species may vary in branching, crown shape, leaf size, and silhouette without changing rendering style.

- Remove cube-like canopy masses and crude stacked primitive forms.
- Avoid replacing every crown with the same smooth sphere. It needs organized, species-specific volume.
- Do not simulate all leaf structure with a harsh pattern projected over an unrelated blob.
- Keep the leaf-group scale coherent across trees, bushes, and hedges.
- Use a limited set of deliberate variants. Small rotation/scale changes supplement genuine variants; they do not replace them.
- Avoid dense layers of alpha foliage as the default solution on phones. Profile the complete stand of trees, not one isolated tree.
- Trunks must meet the ground with convincing roots or contact, without requiring a heap of distracting props.
- Preserve walkable clearances, collision, tutorial visibility, and camera fading.

### Grass and flowers

- Grass should form soft, readable clumps, with broad blades at useful scales.
- Ordinary ground cover must not become a field of needles competing with actors.
- Maintain the visual distinction and authored footprint of encounter/tall grass.
- Flowers need clear petal masses and stems without screen-space sparkle or excessive alpha layering.
- Placement should have grouped rhythm and quiet gaps. Filling every empty tile is not a polish strategy.

### Rocks

- Use deliberate broad planes and softened transitions, with texture that supports those planes.
- Related geological families must share grain scale and crevice contrast.
- Ground them partially into soil or use believable contact, without floating bases.
- Avoid balancing boulders, accidental pyramids, and a mix of extremely angular and inflated rocks without geological justification.

Review one mixed nature gallery with every species together. Approving trees in separate isolated screenshots makes contradictions easy to miss.

## 12. Water, waterfalls, snow, lava, and weather

### Water

Adopt a shared water family with biome-specific depth, tint, flow, and clarity. Aim for broad calm color masses, clear shallow/deep relationships, restrained highlights, and organized foam.

- Small waves should support the water's scale, rather than making a pond look like miniature ocean surf.
- Any caustic or light pattern remains secondary. Avoid a conspicuous geometric net across the whole sea.
- Foam must follow shores, obstacles, and motion. It should not resemble unrelated repeated white decals.
- Shoreline transitions, submerged terrain, bridge supports, and docks must agree on water level and contact.
- Eliminate hard plane cuts, sorting artifacts, disconnected shallows, and visible water-mesh boundaries.
- Keep fish, fishing indicators, crossings, and navigable banks readable.

### Waterfalls

Preserve and enforce the existing sealing rules. The upper river flows continuously over the lip; both sides tuck into rock; the falling surface sits against its cliff; the foot disappears into lower water and splash. No bare channel cut, slab thickness, gap behind the sheet, floating side edge, or raw ground may appear from any reachable gameplay camera.

Use flow shapes and foam to suggest motion. A waterfall must remain convincing before decorative rocks are placed around it.

### Other environmental states

- Snow, where present or later introduced, accumulates over shapes with rounded thickness and consistent coverage. It is not a flat white recolor.
- Lava preserves dangerous heat through coherent flow, bright controlled cores, and restrained emission. Nearby rock retains readable shape.
- Steam, mist, rain, and smoke use a common scale and softness. Avoid opaque particle curtains hiding gameplay.
- Weather does not introduce grain, posterization, or an unrelated post-processing look.

Do not add new seasons, weather systems, or gameplay hazards merely to satisfy this art plan. Apply these rules to existing content and future additions.

## 13. Buildings, landmarks, and regional identity

Keep the towns architecturally distinct. Cohesion comes from common craftsmanship, scale, material treatment, and lighting—not from giving every town the same cottage.

- Retain Cocoon Cove's maritime kit identity, Bellerive's Creole fronts and galleries, frontier/adobe forms, island buildings, mining architecture, industrial machinery, temple identity, and Gothic silhouettes where established.
- Rework source-pack geometry and texture density until neighboring buildings belong together.
- Roofs need substantial edges and organized courses or planes. Avoid wafer-thin roofs, arbitrary black seams, and tiny high-contrast shingles.
- Closed doors and opaque painted/reflected window glass seal every exterior. Exterior views must never reveal a room behind them.
- Seal walls, corners, eaves, roof joins, and replacement openings in geometry. Props and favorable cameras are not repairs.
- Porches, galleries, stalls, and arcades may remain intentionally open-air with no exposed enclosed room behind them.
- Maintain storefront functions and recognizable signs.
- Preserve the Beast Center's recognizable small temple design, including its stone, gold trim, blue door, and golden dome. Modernize its forms and finishes consistently inside and out.
- Keep kennels as roadside barns, not town buildings.
- Important entrances remain clear of foreground clutter and touch controls in gameplay framing.

Every building family needs a front, both sides, rear, roof-edge, and door/window inspection with the hero. Use reachable gameplay viewpoints as well as an inspection turntable.

## 14. Interiors and furniture

Keep the compact stage-room arrangement and existing interior staging rules. Improve the sense of crafted objects, material warmth, and local identity without obstructing play.

- Continue smooth wall colors or restrained wallpaper; use broad comfortable floor patterns and quiet rugs.
- Give beds, cushions, sofas, pillows, curtains, and upholstered seats meaningful volume and folds.
- Tables, shelving, drawers, and counters need designed edge thickness and construction. They must not read as untextured boxes wearing a front photograph.
- Keep wood scale consistent between furniture and floors; use different patterns deliberately, not accidentally.
- Put small props on real surfaces. Avoid floating books, lamps, bottles, and display objects.
- Add lived-in detail through a few purposeful groups, not scattered clutter on every surface.
- Keep tall furniture at the rear or sides, side-wall seating facing inward, and ordinary lounge seating facing the camera. Preserve motivated performance/altar seating exceptions.
- Keep omitted-fourth-wall television staging and existing clear entrances, counters, stair approaches, and service access.
- Preserve permitted rug footprints: 2×3, 3×4, 4×5, and 6×5 tiles, including rotation. Prefer 3×4 or larger; no square rugs or narrow runners.
- Preserve warm/cool room families and building-specific character.

Magic-service interiors must look magical rather than reverting to a mismatched machine pack. Do not alter the documented healing, storage, merging, or phone functions.

## 15. People, beasts, robots, ghosts, and merges

### People

Preserve current body proportions, heights, silhouettes, and character identities. Improve silhouette curvature, joint transitions, hair construction, clothing thickness, facial placement, and shading consistency.

- Hair reads as designed locks and masses; no accidental spiky voxel chunks.
- Clothes use the same broad material hierarchy as the rest of the world.
- Eyes, mouth, brows, and expression shapes remain readable at gameplay distance.
- Hands, feet, accessories, and headwear must not vary arbitrarily in model quality between NPCs.
- All creator body, skin, hair, clothing, and accessory options must receive review, including clipping combinations.
- Keep stable head anchors for speech and correct facing, scale, grounding, and interaction placement.

### Beasts

Keep species anatomy, current proportions, elemental identity, evolution relationships, and recognizable markings. Clean geometry and improve consistent surface response across every ordinary form, legendary, robot, ghost, and merge component.

- Preserve `beast_model.gd` as the shared presentation entry point.
- Keep approved species palettes in `beast_looks.gd`; avoid divergent preview-only color logic.
- Use soft dimensional shading with controlled highlights; do not let a legacy path retain a visibly different retro or flat-cel finish.
- Species can have sharper horns, armored plates, or fierce expressions. Soft rendering does not require removing danger or making every animal round and harmless.
- Ghosts remain recognizable versions of their beasts in black and purple with smoke. Use colored fill and controlled accents so their anatomy does not disappear into the background.
- Merges must visibly combine parents. Connections need intentional transitions, compatible materials, and acceptable deformation; a collection of visibly intersecting parts is not a finished merge.
- Every evolution stage must pass, including forms seen briefly.

There may be too many possible merge combinations to approve as individual authored assets. Review every source part and connector, then test systematic combinations across body kinds, extremes of size, mismatched limb counts, materials, and ghost states. Use reproducible generated cases and an explicit risk matrix. Do not claim exhaustive combination review from a handful of attractive examples.

### Robots and hostile characters

Rework them within the same construction and material library: designed metal plates, controlled edge radii, readable mechanical masses, purposeful wear, and restrained glowing elements. Preserve intimidating posture, scale relationships, and story functions. Do not use grit, pixelation, or disproportionately crude geometry as shorthand for menace.

## 16. Animation and visual effects

Consistency includes motion. A carefully modeled character still looks unfinished if it slides, snaps, floats, or moves with an unrelated style.

- Match foot travel to movement speed; keep planted feet stable through poses.
- Preserve measured body-specific animation for biped, quadruped, flyer, serpent, and blob forms.
- Use clear anticipation, action, and recovery without adding gameplay waits or changing attack timing incidentally.
- Avoid excessive squash or bounce that contradicts serious scenes and existing proportions.
- Synchronize hit reaction, impact effect, damage number, and sound timing.
- Check idle, walk, run, turn, talk, attack, cast, defend, block, hit, faint, summon, hatch, and merge states where applicable.
- Preserve ghosts' and merges' inherited poses through the common model interface.

Effects use broad, readable shapes with controlled lifetime and opacity. Share elemental colors, particle scales, glow behavior, and impact language. Keep the target arrow yellow across gems and preserve the minimal beat cue, safe-area placement, and one-input-one-hit behavior.

No effect may conceal a poor asset indefinitely, obscure a required choice, overwhelm faces, or wash the entire scene white. Inspect peak effects and their transition back to ordinary lighting. Measure simultaneous effects, not only isolated previews.

## 17. Lighting, atmosphere, and camera

### Shared lighting

Extend the existing outdoor and battle lighting systems. Use common material calibration and exposure relationships, with explicit mood profiles.

- A soft key establishes direction and form.
- Sky/fill light keeps shaded faces legible without flattening the scene.
- Contact shade grounds people, beasts, furniture, and major scenery.
- Highlights roll off without bleaching material color.
- Bloom is reserved for bright sources and intentional effects; the whole lawn must not glow.
- Ambient occlusion is optional polish. An asset must look finished on a supported preset without it.
- Avoid compensating for one bad texture with a unique light or exceptional exposure in its map.
- Different renderers may need calibrated parameter differences. The visual target must remain consistent.

Approve daylight, warm indoor, cool indoor, night/dark, and battle profiles. Existing story-specific lighting can remain distinct within those relationships.

### Serious dark places

Gravenmoor, hostile industry, caves, crypts, and danger scenes may be genuinely dark and threatening. Use deliberate silhouette, cooler fill, localized warm or magical light, fog depth, negative space, and composition. Maintain visible paths, interactable faces, and meaningful material separation.

Darkness must not excuse crushed detail, dirty textures, green-black mud, random noise, or flickering low-quality shadows. The supplied night reference is useful because the same trees and shore remain recognizable under a different mood.

### Camera

- Preserve the north-looking gameplay framing and navigation model unless separately redesigned.
- Evaluate detail at actual play distance, not only close inspection.
- Frame characters and architecture at a useful apparent scale; do not raise every camera to hide flaws.
- Maintain existing foreground fading and obstruction handling.
- Keep battle camera positions inside enclosed scenery and respect the named-shot director and minimum shot dwell.
- Inspect reverse views and close battle shots; they reveal seams hidden in ordinary overworld views.
- Use depth of field or blur only as optional accents. Never hide required detail or depend on them to make low-quality assets acceptable.

## 18. Biome standards

The current `WorldDB.BIOMES` contains 14 biome definitions. Generate the final coverage list from the data at implementation time; do not assume this count can never change.

| Biome | Distinctive direction | What must remain common |
|---|---|---|
| Coast | Warm sand, grassy shoulders, maritime timber, calm blue shallows | Turf/bank quality, leaf grammar, restrained wood and sand detail |
| Quarter / Bellerive | Creole fronts, galleries, paving, warm masonry and painted shutters | Human scale, edge treatment, material-feature scale |
| Island | Palms, generous leaf masses, beach stone, sun-warmed native construction | Water family, foliage response, clean roof and wall joins |
| Desert | Broad warm sand forms, substantial cactus shapes, adobe, oasis contrast | Smooth silhouettes, quiet surfaces, readable shade |
| Western | Weather-softened timber, frontier silhouettes, curated dry vegetation | Controlled wear, common wood response, full-size doors |
| Mesa | Broad terracotta strata, sculpted cliff planes, restrained dry accents | Rounded terrain transitions and coherent rock scale |
| Mountain | Designed stone masses, conifers, mining structures, cooler shade | No gritty rock substitution; consistent foliage and contact |
| Steampunk | Readable machinery, rounded cast-metal pieces, brick, brass accents | Controlled highlights, painted detail, clean construction |
| Volcano | Dark warm rock, broad fissures, dangerous lava, sparse silhouettes | Readable planes and paths; no noise-based grit |
| Hot spring | Warm stone, steam, inviting water, native timber and roofs | Shared water/material response, restrained particle opacity |
| Reef | Rich planted cliffs, clear water, native rock, sealed falls | Cohesive depth/foam, cliff joins, foliage detail hierarchy |
| Jungle | Layered broad foliage and vines, rich greens, filtered light | Clear routes, controlled density and overdraw, common leaf design |
| River | Gentle banks, freshwater vegetation, timber and river-town identity | Shared bank, water, furniture, and building quality |
| Moor | Restrained greens, violet/cool shade, Gothic forms, graves and dead trees | Soft craftsmanship, readable darkness, recognizable material families |

Each biome needs a real gameplay exemplar, material sheet, vegetation grouping, building example if present, interior if present, and battle counterpart. Temples, tower rooms, crypts, docks, arenas, and films also need coverage even when they do not map one-to-one to a biome.

Consistency does not mean the volcano becomes cheerful or the desert becomes grassy. It means they look built by the same artists.

## 19. Battle scenes and films

Battle scenery must use the same approved assets and materials as the world. Re-bake the murals from the approved regional set; old artwork can otherwise preserve the old style after its source models are fixed.

- Keep the continuous surround, curved floor blend, sealed room shells, and perimeter dressing.
- Preserve trees on land in fishing scenes and readable battle pads.
- Match physical props to their representation in murals; avoid duplicated trunks, scale changes, or obvious model-to-image joins.
- Test all named shots and foreground occlusion, including views through indoor columns.
- Keep only the intended fighters casting shadows under the current battle policy.
- Preserve cinematic action readability, ring turns, empty pads, and fainted beast poses.
- Rework ring, pad, glyph, summon, and targeting visuals within the same finish standard without changing combat rules.

Films use finished gameplay assets and the same material families. Keep spoken dialogue, stable head anchors, and the established touch film controls. An opening cinematic must not be more polished than the first playable street—or retain an older art style after the street improves.

## 20. Interface, icons, title, and presentation

Keep the existing layout structure, information hierarchy, input model, and accessibility. The requested change softens the presentation; it does not authorize replacing all screens or changing their functions.

- Extend `UIKit`, `frame_box.gd`, shared windows, and existing controls. Do not create independent per-screen styles.
- Retain the shared dark translucent window family and bright spoken-bubble distinction. Use subtler material variation and calmer ornament within that structure.
- Keep white borders and body text. Preserve the faint gem tint and all four palettes.
- Simplify or soften excessive ornament and frame weight consistently. Do not soften by blurring text, reducing contrast, or making focus ambiguous.
- Preserve League Spartan Regular/600 use and the intro/title logo's established font unless separately approved.
- Keep the existing battle bar structure and white shape/dark text presentation; harmonize its finish and framing with the revised shared UI.
- Review every icon family together: items, beasts, actions, map markers, prompts, rings, shop signs, and status graphics. Any retained crisp icon must have coherent line weight, palette, silhouette, and padding.
- Re-render beast portraits, menu icons, save placeholders, title scenes, and applicable key art after their source assets change.
- The application icon and title art must represent the new visual direction rather than advertise a contradictory retro treatment.
- Keep speech bubbles attached to stable speakers, door replies attached correctly, and system text in the appropriate dark windows.
- Preserve the 1280×720 reference viewport, expanding landscape aspect, safe areas, and readable phone layout.
- Preserve 32-unit interactive text, desktop rows of at least 56 units, and touch rows of at least 80 units through shared helpers.
- Keep focus, selection, pressed, and disabled states distinct by shape/contrast as well as color.
- Preserve touch cluster availability, enlarged hit/no-world-tap zones, one confirmation per input, and direct A/B Yes/No behavior.

The interface must look intentional beside the softer world while still serving battle clarity and phone usability. It does not need to imitate Animal Crossing's interface.

## 21. Performance contract

The README is the source of the current system requirements. At this review it describes, among other estimates:

- Android minimum: Android 9, ARM64, Snapdragon 660 class, 4 GB RAM, Adreno 512 class with required Vulkan support; suggested starting point 540p / Min.
- Android recommended: Snapdragon 865 class / Adreno 650 class or equivalent, 6 GB RAM; suggested 720p / Mid.
- Windows minimum: Core i3-6100 / Ryzen 3 1200 class, 4 GB RAM, HD Graphics 620 class with required Vulkan support; suggested 720p / Min, trying 540p if necessary.
- Mobile renderer on Android; Compatibility and single-threaded browser export; desktop's supported path as documented.
- Estimated storage and macOS requirements remain part of the compatibility review; do not silently expand the package or assume a macOS export already exists.

These are provisional requirements, not proven frame-rate guarantees. Preserve the existing mobile 60 fps goal, but distinguish a target from measured achievement. When a physical representative of the minimum class is unavailable, record that gap; a desktop Mobile-renderer result is not phone verification.

For 60 fps, the frame interval is approximately 16.67 ms. Establish CPU, GPU, resident-memory, texture-memory, draw-call, loading, and package-size budgets after profiling the reference scenes. Do not invent fixed global budgets from polygon counts alone.

Capture median, p95, p99, worst recurring spikes, and frame-time traces for repeatable routes, warmed battles, peak effects, and dense foliage. Separate cold loading/compilation from steady-state play. Run a sustained session long enough to observe thermal behavior on a real phone, initially at least 15 minutes, and record device temperature/throttling conditions when available.

Use a proposed investigation threshold of more than 5% regression in a repeatable frame-time metric against the accepted same-device baseline, while treating any new recurring visible hitch as a failure even below that percentage. Calibrate thresholds against measurement variability; the absolute target still matters.

Preserve chunking, shared resources, cached scenery, LODs, offline baking, bounded memory, and background loading. Avoid per-frame scene-wide material work and unnecessary shadow casters.

Godot documents that transparency can increase rendering cost and that its automatic instancing path is specific to Forward+. Keep the project's explicit mobile-compatible batching approach rather than assuming desktop behavior will carry over. See [Godot's 3D performance guidance](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html). Transparency and precision differences also need renderer-specific verification; see [3D rendering limitations](https://docs.godotengine.org/en/stable/tutorials/3d/3d_rendering_limitations.html).

Lower presets may reduce effect density, shadow quality, distant detail, and image resolution. They must retain approved silhouettes, material identity, readable faces, and smooth image reconstruction. The cozy style must not depend on optional bloom, SSAO, or desktop-only effects.

## 22. Inventory: how “everything” becomes auditable

Do not start by editing random ugly assets. Start with a complete inventory and dependency map.

The inventory must include meshes, all embedded materials and images inside `.res` files, imported scenes, shader-generated surfaces, procedural builders, terrain, vegetation, buildings, furniture, every character option, every beast family, merge parts, ghosts, robots, legendaries, vehicles, weapons, signs, pickups, puzzle objects, particles, skies, lighting profiles, UI, icons, portraits, murals, title presentation, and application art.

Track original sources separately from runtime derivatives. Unused downloaded source packs remain untouched and are marked **not shipped / not reachable**, with evidence. They are not silently included as “passed assets.” Any source later introduced into the game enters the approval process.

### Proposed inventory record

| Field | Purpose |
|---|---|
| Stable asset ID and family | Follow an asset through rebakes and renamed derivatives |
| Source, license, attribution | Preserve provenance and permissions |
| Runtime paths and embedded resources | Find what is actually rendered |
| Builder/importer and recipe version | Make the result reproducible |
| Source/output hashes | Detect changes after approval |
| Used by maps, rooms, films, menus, and battles | Establish impact and coverage |
| Variants, LODs, palettes, poses, story states | Prevent a base model from hiding unfinished variants |
| Triangles, surfaces, texture memory, shader family | Establish measurable cost |
| Scale, footprint, anchors, closest camera | Preserve gameplay integration |
| Review status and defect IDs | Make remaining work explicit |
| Reviewer, standard version, evidence links | Tie approval to an actual result |

Use statuses such as **unreviewed**, **rework**, **rebuild**, **ready for review**, **approved**, and **retired**. Missing metadata must mean unreviewed, never implicitly approved.

Maintain both an **asset ledger** and a **scene/state coverage ledger**. Assets can pass individually while their combined scene fails through density, lighting, layout, or mismatched scale.

Completeness is measured by approved applicable entries divided by all applicable entries, with separate counts for asset families, individual variants, scenes, and state coverage. Report remaining counts and defects, not only one flattering percentage.

## 23. Representative scenes before mass conversion

Approve a small set of finished in-engine references before touching every asset family. These scenes are the quality anchors for the entire overhaul, not a substitute for finishing the rest.

1. **Coastal Path:** hero, NPC, beast, varied trees, shrubs, tall grass, rock, sign, fence, path, cliff, and a water edge.
2. **Cocoon Cove street:** home/shop/Beast Center, doors and windows beside the hero, paving, props, and foliage.
3. **Home interior:** furniture, cloth, floor, rug, wallpaper, window light, and speech.
4. **Dark location:** Gravenmoor or a crypt, with serious mood, legible path, ghost, and practical light.
5. **Dry/industrial stress scene:** a desert/mesa sample plus a Cogsworth or Gearhart sample, proving that the rules survive outside green environments.
6. **Battle:** ordinary beast, legacy guardian or robot, ring/pads, effects, foreground scenery, mural, targeting UI, and several directed shots.
7. **Interface contact sheet:** title, book, dialogue, Yes/No, battle, and touch controls across four gems.

The initial material board should include timber, plaster, stone, cloth, foliage, skin/beast surfaces, metal, and water beside the unchanged hero proportions. Review it under neutral light and the relevant gameplay profiles.

Approve these references against the supplied inspiration and the written contract. Record exactly why they pass. Do not freeze the target based on a beautiful close-up that does not work in normal play.

## 24. Production method and fallback to custom assets

For every family:

1. Inspect its source and runtime appearance, including its worst variant.
2. Classify defects as design/silhouette, topology, normals, UVs, texture, material, scale, animation, placement, or lighting.
3. Decide what can genuinely be reused.
4. Adapt the family through its shared builder/importer where possible.
5. Compare the result against the approved exemplars in a mixed gallery and a real scene.
6. If it fails, make a targeted correction supported by evidence.
7. If adaptation repeatedly fails, switch to custom modeling/texture painting rather than stacking more filters and patches.

**Recommended stopping rule:** allow an initial adaptation and up to two focused revision rounds for a family. A third failure of the same fundamental shape or finish requirement triggers a rebuild decision. Rebuild immediately when the source cannot support the required silhouette, sealed construction, animation, UV layout, or attachment geometry without essentially being remade.

This is a proposed management rule implementing the user's preference, not an existing tool behavior. A minor last-mile defect does not require discarding an otherwise sound model. Record the reason for continuing or replacing it.

Custom assets must still use the shared scale sheet, material library, pipeline, performance limits, and runtime entry points. Custom does not automatically mean approved.

AI/procedural tools can draft textures, suggest variants, or flag differences. They must not decide final quality, invent missing geometry, approve licenses, or replace gameplay-view inspection. Keep generated textures free of stray lettering, incoherent seams, changing feature scale, and baked highlights inconsistent with the model.

## 25. Implementation sequence for one complete overhaul

### Stage A — Record and reconcile

Capture an unchanged baseline using isolated state. Create both ledgers and the dependency map. Record existing performance. Reconcile README/AGENTS references to Fortnite, retro image scaling, legacy art, interface softening, and any procedural-texture exceptions. Preserve unrelated work and original downloads.

**Exit:** scope, hardware contract, standards, baseline, and unresolved risks are visible.

### Stage B — Establish the finished target

Build the material board, scale sheet, and representative scenes. Tune the common geometry, palette, light, filtering, and material response. Validate on supported renderers and target-class hardware before replicating the method.

**Exit:** approved visual exemplars and calibrated authoring/performance defaults exist.

### Stage C — Fix shared production systems

Extend the existing terrain, foliage, people, beasts, building, furniture, material, lighting, UI, and quality systems. Add inventory/validation capabilities and versioned recipes. Correct final-image reconstruction. Keep caching, batching, and existing common entry points.

**Exit:** ordinary asset work follows a reliable common path; new content cannot silently use an unreviewed fallback.

### Stage D — Convert all families

Process terrain and natural materials, foliage and rocks, exterior families, interior families, cast and creator options, beasts and merge parts, robots/legendaries, props/vehicles/weapons/obstacles, effects, UI/icons, and presentation art. The precise order may follow dependency impact, but every ledger entry must be resolved.

**Exit:** every active family and required variant is approved or has a specific remaining defect.

### Stage E — Finish every scene

Audit every map, room, battle setting, film, and relevant story state. Correct density, lighting, material scale, joins, foreground obstructions, and placement. Regenerate ground derivatives, murals, icons, portraits, and applicable measurements after their inputs change.

**Exit:** no scene is relying on an old derivative or an unreviewed combination.

### Stage F — Whole-game acceptance

Run broad regression checks, the visual coverage matrix, real input checks, physical-device profiling, and a complete journey inspection. Resolve all release-blocking defects and verify asset hashes against approval evidence.

**Exit:** one coherent overhaul is ready. A polished first town does not satisfy this stage.

Do not promise a calendar date before the inventory and exemplar rebuilds reveal the actual work. Estimate by asset families and measured conversion/rebuild rates, with explicit allowance for review and dependent rebakes.

## 26. Acceptance gates

| Gate | Must establish | Evidence |
|---|---|---|
| Provenance | Known source and reproducible derivative | License, recipe, hashes |
| Geometry | Intended silhouette, correct scale, sealed required surfaces, sound normals | Neutral render, turntable/crops, measurements |
| Surface | Appropriate authored material, coherent density and feature scale | Material board, imported texture inspection |
| Integration | Works beside approved neighbors and in all required uses | Mixed gallery, gameplay scene, portraits/films/battle where used |
| Motion | Grounded movement, acceptable deformation, synchronized action | Short clips/pose sequences and relevant checks |
| Performance | Fits measured scene and hardware budgets | Same-device before/after results |
| Presentation | No clipping/overlap, usable touch and focus, consistent UI states | Desktop/phone captures and actual interaction checks |
| Coverage | No missing variants or stale derivatives | Ledgers, dependency report, approval fingerprints |

An asset passes only when all applicable gates pass. Averages must not hide a failure: excellent lighting cannot compensate for a voxel silhouette or a broken door.

For visual review, assign each category **fail**, **needs correction**, or **pass**, with a short reason and evidence. Optional numeric scores can help prioritization, but a high average is never an automatic acceptance rule.

### Severity

- **Release blocker:** unreviewed active family; visible prohibited style; broken navigation/input; holes in required shells/waterfalls; missing assets; major clipping; corrupted saves; failure on a supported renderer; unacceptable target-device performance.
- **Major:** obvious material mismatch, repeated texture patchiness, bad scale, visible LOD pop, wrong grounding, inconsistent animation, or a conspicuous scene-composition defect.
- **Minor:** small polish issue that does not undermine cohesion, legibility, function, or the approved reference quality.

No blockers or major visual defects remain at completion. Record minor defects explicitly; a minor label must not be used for an entire unconverted asset family.

## 27. Automated enforcement to add during implementation

The following capabilities are proposed work. They do not all exist today.

### Runtime and resource validation

- Enumerate all rendered resource paths, embedded materials/textures, and procedural recipes across the coverage harness.
- Require an approved material family and asset/recipe identifier for physical surfaces.
- Flag unapproved rescue finishes, missing textures, visible-world nearest filtering, absent mipmaps, excessive material counts, and unapproved shader variants.
- Distinguish visual textures from data maps, UI graphics, and permitted light/shade effects.
- Record actual runtime overrides; do not trust only source-resource settings.
- Check bounds, scale, door/attachment constraints, and expected anchors where meaningful.
- Track per-family/per-scene cost against calibrated budgets.
- Fail on unknown active assets and missing coverage entries.

### Approval invalidation

Tie approval to the standard version, source/output hash, builder recipe, material family version, and relevant renderer/profile.

A changed mesh invalidates its geometry and dependent scene evidence. A changed foliage shader invalidates affected foliage and scene reviews. Changed lighting invalidates the relevant mood/profile captures. A changed beast invalidates its icons, portraits, ghost derivatives, and affected animation/merge evidence. Do not require unrelated reviews to rerun when their inputs truly did not change.

### Images and review assistance

Generate fixed-camera contact sheets, close crops, turntables, and reproducible motion clips. Fix seeds, game state, camera, exposure, time, renderer, and quality settings for comparisons.

Use image differences to locate changes and missing content, not to determine whether art became better. An old screenshot is a regression reference, not the aesthetic goal. Never automatically replace the accepted baseline merely because an image changed.

Local vision-model feedback can flag likely problems. Its result is advisory. Always read harness build errors first and verify important observations directly.

### Enforcement in development

Run cheap resource/metadata checks on each affected change, family galleries when a family changes, and a broader scheduled/full audit when shared systems change. The completion report must expose unreviewed entries and failures, not quietly skip them.

## 28. Existing systems and checks to retain

Prefer extending these systems over building parallel implementations:

| Existing area | Role in the overhaul |
|---|---|
| `scripts/gfx/surface_finish.gd` | Shared finish handling; distinguish intentional materials from rescue treatment |
| `scripts/gfx/smooth_texture.gd`, `tools/smooth_textures.gd` | Reproducible cleanup and managed no-double-smoothing record |
| `scripts/gfx/voxel_assets.gd`, manifest, importers | Asset loading, shared meshes, family-level conversion; legacy names alone do not require a refactor |
| `terrain_mesh.gd`, `terrain.gdshader`, ground store | Terrain form, transitions, baked derivatives, elevation consistency |
| `foliage.gdshader` and nature importer | Shared leaf/bark response, coherent variants and LODs |
| `house_models.gd`, `cove_buildings.gd`, regional builders | Scale, attached openings, exterior sealing, regional construction |
| `voxel_person.gd` and people importers | Consistent people, creator variants, grounding and material response |
| `beast_model.gd`, rig/parts, `beast_looks.gd` | Common species presentation, ghosts, merges, poses and palettes |
| `outdoor_light.gd`, `stage_lighting.gd` | Shared calibration with regional/mood variants |
| `render_quality.gd`, `scripts/autoload/prefs.gd` | Coherent quality fallbacks and final-image reconstruction |
| `UIKit`, frames, windows, shared controls | Whole-interface softening without separate screen styles |
| `tools/debug/texture_audit.gd` | Technical surface coverage; extend with intentional-material and approval checks |
| Existing exterior/map/battle checks | Preserve functioning construction, navigation, camera and targeting rules |

### Existing command examples

Resolve the local Godot executable; `godot` below is a placeholder. `tools/run_tests.sh` accepts the `GODOT` override. The runner supplies isolated save/preferences defaults to every test. Direct Godot examples below explicitly isolate both. Step 001 records execution results under `build/perf/vo/001/commands/`; an example that fails is not evidence of visual acceptance.

```text
bash tools/run_tests.sh quick
bash tools/run_tests.sh exteriors
bash tools/run_tests.sh cove-exteriors
bash tools/run_tests.sh textures
bash tools/run_tests.sh battle-poses

godot --headless --path . --script res://tools/check_maps.gd -- --save_dir=res://build/visual_saves/ --prefs_path=res://build/visual_prefs/settings.cfg
python tools/town_check.py
godot --headless --path . --script res://tools/check_battle_visuals.gd -- --save_dir=res://build/visual_saves/ --prefs_path=res://build/visual_prefs/settings.cfg

godot --path . -- --scene=texture-audit --verify=1 --save_dir=res://build/visual_saves/ --report=res://build/visual_texture_audit.json --prefs_path=res://build/visual_prefs/settings.cfg
godot --path . -- --scene=newbeasts --anim=cycle --page=all --save_dir=res://build/visual_saves/ --prefs_path=res://build/visual_prefs/settings.cfg --shots=res://build/shots/visual_beasts --shot_w=0

godot --path . --resolution 1920x1080 -- --scene=interiors --shots=res://build/shots/visual_interiors --save_dir=res://build/visual_saves/ --prefs_path=res://build/visual_prefs/settings.cfg
godot --path . --resolution 2400x1080 -- --scene=interiors --touch --shots=res://build/shots/visual_interiors_touch --save_dir=res://build/visual_touch_saves/ --prefs_path=res://build/visual_prefs/settings.cfg

godot --path . --rendering-method mobile --resolution 1920x1080 -- --scene=battle-stage --shots=res://build/shots/visual_battle --shot_w=0 --save_dir=res://build/visual_saves/ --prefs_path=res://build/visual_prefs/settings.cfg
godot --path . --rendering-method mobile --resolution 2400x1080 -- --scene=battle-stage --touch --shots=res://build/shots/visual_battle_touch --shot_w=0 --save_dir=res://build/visual_touch_saves/ --prefs_path=res://build/visual_prefs/settings.cfg
```

Use the broader suite after changes spanning shared systems. For changed world-texture derivatives, run the established smoothing/import sequence at the appropriate scope. Re-bake measurements and derived assets using their existing tools when their inputs change. Keep original packs untouched.

Headless success does not establish visual quality. Check logs for script errors and missing resources, then inspect a real window and exercise relevant input. Never test by copying from, overwriting, migrating, or deleting actual player saves.

## 29. Visual coverage matrix

Build this matrix from actual content and rendering dependencies. Avoid multiplying every setting blindly when a targeted dependency-based selection gives equivalent coverage, but do not omit unique content or renderer behavior.

| Axis | Required coverage |
|---|---|
| Locations | Every outdoor map, distinct room template, unique building/landmark, battle setting, and film set |
| Story states | Initial/progressed states that alter geometry, dressing, obstacles, water, access, or actor placement |
| Cameras | Real gameplay, closest required shot, doors/windows beside hero, battle reverse/attacker/reaction/victory views |
| Display | 1920×1080 desktop; 2400×1080 landscape touch; 1280×720 when density/clearance is tight |
| Actual world resolution | Include the README's 540p and 720p starting presets; a 2400×1080 window alone does not test low-resolution reconstruction |
| Renderers | Supported desktop path, Mobile, and Compatibility/Web; real browser export as well as editor preview |
| Quality | Min/Mid/Max for affected systems, especially removed effects and AA/shadow differences |
| Gems | All four whenever shared UI/material styling changes |
| Characters | Every family, creator options, worst accessory combinations, key motion and facial states |
| Beasts | Every ordinary stage, legendary, robot, ghost family, merge-part family and systematic risky combinations |
| Interaction | Actual touch targets, focus navigation, scrolling, long labels, yes/no, target confirmation, and movement clearance when affected |
| Motion | Walk/run, foliage movement, water flow, LOD transitions, attack and peak effects |

Retain full-resolution captures under `build/shots/` during implementation, with scene ID, state, camera, seed, renderer, quality, world resolution, display resolution, device, revision, and standard version in a companion report. Keep failures as well as successes.

Do not update `docs/screenshots/` automatically. Refresh documentation deliberately after the new result is accepted.

## 30. Instructions for any implementation agent or artist

Use this as the brief for each implementation assignment:

> Apply the Ruby Cocoon visual standard to the named asset family and every dependent runtime use. Read the relevant README and project instructions first. Preserve current character/beast proportions, gameplay, save data, interaction anchors, regional identity, and the existing interface structure. Match the approved exemplars in silhouette, material-feature scale, surface response, edge treatment, and light. Update the inventory and affected scene/state coverage entries. Prefer the existing shared builder, material library, importer, and runtime entry point. Rework suitable sources; switch to custom modeling/painting after repeated failure of the same fundamental requirement. Do not declare completion from a texture-presence check, a headless pass, an isolated close-up, or advisory model feedback. Inspect the result in a real gameplay window at desktop and touch layouts, capture evidence, run affected checks, profile relevant costs, regenerate stale derivatives, and list every remaining defect. Unknown assets and missing evidence remain unapproved.

Every assignment must name the family, its dependants, relevant exemplar, expected evidence, and completion criteria. “Make this prettier” is not a sufficient production task.

Before marking a family complete, answer:

1. Does it match the same world when shown beside approved neighboring families?
2. Does it look finished at gameplay scale and its closest required camera?
3. Are every variant, LOD, material, pose, and relevant palette covered?
4. Are its derived icons, portraits, murals, and cached/baked resources current?
5. Does it work on supported renderers and meet the measured budget?
6. Are input, navigation, progression, and saves preserved?
7. Can another person reproduce the reviewed result from the recorded source and recipe?

If any answer is no, the family is not complete.

## 31. Definition of the completed overhaul

The overhaul is complete when:

- Every shipped/reachable visual family and required variant has an approval record tied to current inputs.
- Every location and applicable state has passed composition/integration review.
- No visible voxel, retro, patchy, unreviewed fallback, or incompatible source-pack treatment remains.
- People and beasts retain their intended proportions and identities while meeting the common rendering standard.
- Dark locations preserve serious danger without a different art style.
- Buildings, terrain, water, and waterfalls are continuous and sealed where required.
- Interface presentation is softened consistently through shared components, with existing structure and input behavior intact.
- Icons, portraits, murals, title/application art, documentation captures, and other derivatives match the accepted assets.
- Relevant technical checks and whole-game regression checks pass.
- Desktop, touch, Mobile, Compatibility/Web, and target-hardware evidence are recorded honestly; unavailable testing is explicitly unresolved.
- There are no blockers or major defects, and remaining minor polish items are named.

The practical test is to place a home interior, a sunny route, a desert street, an industrial battle, a haunted area, a character portrait, and the title/interface side by side. They should differ in subject and mood while unmistakably belonging to one game.

## 32. Planning sources and limitations

Project sources reviewed include README sections on Art, Mobile, UI, Tests, developer previews, and requirements; `AGENTS.md`; `docs/interior_staging.md`; selected performance documentation; and the shared surface, asset, lighting, terrain, foliage, beast, render-quality, preferences, and texture-audit implementations. Existing Coastal Path, Bellerive, bedroom, battle, and Beast Center captures were inspected alongside the twelve user-supplied references.

The local model was reachable for its availability check, but its large-input summary request returned HTTP 400; it supplied no findings used here. This planning document does not claim a comprehensive asset audit, current-build visual verification, phone benchmarking, or completed enforcement tooling.

The official Godot links support technical pipeline considerations. Numeric art ranges, review thresholds, and workflow rules in this document are proposed Ruby Cocoon production decisions; they are not claimed to be Nintendo practices or Godot guarantees. When implementation starts, resolve the local engine version and verify version-specific APIs before changing code.
