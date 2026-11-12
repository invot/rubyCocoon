"""Publish a broadleaf candidate revision: copy the generator sources in, hash every file, write READY.json LAST.

    python tools/blender/art_candidates/broadleaf/finalize.py rev_001

READY.json is written to a temporary name and atomically renamed, after every other file exists. A revision that
already has READY.json is immutable: this refuses to run on it.
"""
import hashlib, json, os, shutil, sys, pathlib, datetime

ROOT = pathlib.Path(__file__).resolve().parents[4]
REV = sys.argv[1] if len(sys.argv) > 1 else "rev_001"
D = ROOT / "build/art_candidates/broadleaf" / REV
if (D / "READY.json").exists():
    raise SystemExit(f"{D} already published (READY.json exists); corrections go in a new revision")
HERE = pathlib.Path(__file__).resolve().parent


def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


REV_NOTES = {
    "rev_002": dict(
        supersedes="rev_001 (approved candidate; left unchanged)",
        changes_from_previous=[
            "Crown leaf mapping: rev_001's per-face switch between a top planar projection and a cylindrical side "
            "wrap (a visible band of changing leaf direction and stretch) is replaced by one baked atlas per variant "
            "and LOD (smart-UV islands, 1024/512/256). Each texel samples the SAME approved rev_001 leaf tile at the "
            "same world scale through three planar projections (X side, Y side, top), height-blended on a leaf mask "
            "so whole leaves interlock with no line. The cylindrical wrap was dropped because it also sheared leaves "
            "in the valleys between lobes. Leaf and bark artwork is byte-identical to rev_001 (bake sources in "
            "source/art; bark ships unchanged).",
            "Materials export single-sided (glTF doubleSided absent = false); Blender backface culling on.",
            "Trunk base capped (a downward fan at ground contact): +12/+8/+6 triangles by LOD.",
            "Remaining open tube ends (trunk top, branch bases, branch tips) are measured to lie inside the crown or "
            "trunk that hides them (nearest-surface test, per-ring min depth in counts.*.lods.*.open_ends).",
            "Silhouettes, scale, proportions, root flare, palette and LOD triangle targets unchanged.",
        ],
        verification=dict(
            backface_check="renders/cull_* and previews/cull_check_*.png: culling off, back faces emit red; "
                           "no red in any view (underside, roots, branch junctions, top) for LOD0 at 0/180 deg, LOD1, LOD2",
            seam_check="previews/seam_compare_*.png, seam_crop_A.png, gameplay_compare.png: rev_001 imported read-only "
                       "from its glTF and rendered with identical cameras",
            texture_identity="source/art/leaf_*.png and mesh/textures/bark.png SHA-256 equal rev_001's leaf_*/bark",
            local_model="qwen3.6-27b asked to list differences on the seam crop pair; it reported none, which "
                        "direct inspection contradicts (rev_001's band is visible); answer overridden",
            not_done="no engine import, no in-game capture, no performance measurement"),
    ),
}
LIMITS = {
    "rev_002": [
        "Crown texel density is about 190-210 px/unit at LOD0 (rev_001's tiles gave about 320); leaves read slightly "
        "softer in close crops. Per-variant crown atlases add 9 crown textures (3 per variant: 1024, 512, 256) where "
        "rev_001 shared three 512 leaf tiles: more texture memory, to be weighed at integration (011 budgets).",
        "Small cross-fades remain where three projections meet on strongly curved valleys; no straight line remains.",
        "Hidden open ends remain at trunk top and branch ends (inside the crown/trunk by >= ~0.05 units); capping them "
        "would add only unseen triangles. Trees on steep or uneven ground could expose the capped base, not an opening.",
        "Leaf rows and bark banding are unchanged by design (approved artwork).",
        "Preview lighting/ground are Blender stand-ins; renders are not in-game evidence. Explicit LOD glTFs are not wired "
        "into Godot's LOD pipeline; not checked against 022/023.",
    ],
}

gen = D / "source/generator"
gen.mkdir(parents=True, exist_ok=True)
for f in sorted(HERE.glob("*.py")):
    shutil.copy2(f, gen / f.name)

rep = json.loads((D / "build_report.json").read_text())
src_json = ROOT / rep["source"]["path"]
if src_json.suffix == ".glb":  # a supplied third-party source travels with the revision, unmodified
    (D / "source/original").mkdir(parents=True, exist_ok=True)
    shutil.copy2(src_json, D / "source/original" / src_json.name)
src_tex = ROOT / "build/nature_source/Stylized Nature/collection/Texture_BaseColor_v02.png"
files = {}
for p in sorted(D.rglob("*")):
    if p.is_file() and p.name not in ("READY.json", "READY.json.tmp"):
        files[p.relative_to(D).as_posix()] = dict(sha256=sha(p), bytes=p.stat().st_size)

summary = {}
for k, v in rep["variants"].items():
    summary[k] = dict(label=v["label"], lods={l: dict(triangles=d["triangles"], crown_triangles=d["crown_triangles"],
                                                      trunk_triangles=d["trunk_triangles"], vertices=d["vertices"],
                                                      materials=d["materials"], textures=d["textures"],
                                                      texture_files=d["texture_files"], file=d["file"],
                                                      height=d["height"], width_x=d["width_x"], depth_y=d["depth_y"],
                                                      **{k: d[k] for k in ("double_sided", "open_ends",
                                                                           "crown_texel_density_px_per_unit",
                                                                           "crown_uv_coverage", "crown_texture_size",
                                                                           "open_boundary_edges", "trunk_base_cap",
                                                                           "shells", "crown_source_triangles")
                                                         if k in d})
                                                  for l, d in v["lods"].items()})

OVERRIDES = {
    "rev_003": dict(
        decision="rework of a user-supplied CC-BY-4.0 model (user's choice, 2026-11-12)",
        decision_reason=("User feedback on rev_002: individual painted leaves look silly; crowns should be pillowy and "
                         "simple. The user supplied reference models and chose to rework roroer's 'Stylized tree' "
                         "(painted dome shells with scalloped hems) rather than use it only as a style reference."),
        source_provenance=dict(
            model=dict(title="Stylized tree", author="roroer (https://sketchfab.com/roroer)",
                       source="https://sketchfab.com/3d-models/stylized-tree-6ba26deef34249ddb8694888b47db449",
                       license="CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)",
                       supplied_as="the user's Downloads/stylized_tree.glb (left untouched)",
                       kept_at="build/art_candidates/broadleaf/sources/stylized_tree_roroer/stylized_tree.glb and "
                               "source/original/stylized_tree.glb in this revision",
                       sha256=sha(src_json), triangles=rep["source"]["triangles"]),
            credit_required=("At integration add to CREDITS.md / licenses/: 'Stylized tree' by roroer "
                             "(https://sketchfab.com/3d-models/stylized-tree-6ba26deef34249ddb8694888b47db449), "
                             "CC BY 4.0, modified: recoloured, root flare added, rearranged into three variants, "
                             "decimated into LODs."),
            modifications=["texture recoloured by luminance to the approved rev_001 leaf/bark palettes (painting kept)",
                           "trunk: welded, rings added low, root flare fins, base capped, girth 0.82",
                           "dome groups rearranged/scaled per variant (A as modelled, B centre stretched, "
                           "C an extra right-hand group turned 150 degrees), fitted to the approved envelopes",
                           "welded and collapse-decimated to LOD0/1/2"],
            other_supplied_assets_reviewed=[
                "stylized_hand_painted_tree (Satendra Saraswat, CC-BY-4.0)",
                "free_download_low_poly_nature_pack (Gostbento, CC-BY-4.0; palms rejected by the user; alpha leaf cards)",
                "stylized_pine_tree_tree (Batuhan13, CC-BY-4.0)", "coconut_tree (sujirour, CC-BY-4.0)",
                "forester_wooden_house (RacKrab, CC-BY-4.0)", "none of these is used in rev_003"]),
        generator=dict(script="tools/blender/art_candidates/broadleaf/broadleaf_rework.py (imports "
                              "broadleaf_candidate.py for shared render/check helpers)",
                       copied_to="source/generator/", blender=rep["blender"], deterministic=True,
                       command=('python tools/local_resource.py -- "C:/Program Files/Blender Foundation/Blender 4.2/'
                                'blender.exe" -b --factory-startup -P tools/blender/art_candidates/broadleaf/'
                                f'broadleaf_rework.py -- --rev {REV} --compare-rev rev_002; python tools/blender/'
                                f'art_candidates/broadleaf/make_sheets.py {REV}; python tools/blender/art_candidates/'
                                f'broadleaf/finalize.py {REV}')),
        normals="as modelled (source normals kept; recomputed by Blender on the flared, decimated trunk)",
        double_sided=dict(trunk=False, crown=True,
                          why=("the crown shells' scalloped hems are single open sheets by design; an inner-skin "
                               "variant that allowed single-sided rendering took LOD0 over 3,900 triangles, so the "
                               "crown material is two-sided and the trunk single-sided with its base capped")),
        budget=dict(provisional_lod0_target="1,000-3,000 triangles (standards.md 5.3, repeated tree)",
                    lod0_within_target=all(1000 <= v["lods"]["0"]["triangles"] <= 3000 for v in summary.values()),
                    materials_per_tree="2 (trunk single-sided + crown two-sided) sharing one 1024 texture per variant",
                    alpha="none (opaque shells, no alpha cards)",
                    note="Budgets are provisional until runbook 011; no in-engine measurement was made."),
        supersedes="offered in place of rev_002 for the user's review; rev_001 and rev_002 stay unchanged",
        verification=dict(
            backface_check=("previews/cull_check_*.png (culling off, back faces red): the trunk shows none and its "
                            "base cap faces down; the crown shows red only on skirt undersides (two-sided by design); "
                            "LOD1/LOD2 top views show a few small decimation slivers"),
            not_done="no engine import, no in-game capture, no performance measurement"),
    ),
}
LIMITS["rev_003"] = [
    "Crown is two-sided (open scalloped hems); its GPU cost versus skinned shells was not measured.",
    "LOD1/LOD2 collapse decimation leaves a few small flipped slivers on dome tops and slightly pointed tops (C LOD2).",
    "The rework is a CC-BY-4.0 derivative: the credit in source_provenance.credit_required must be added at integration.",
    "Silhouettes differ from the approved rev_001 lobed crowns (domes, with side domes on arms), by the user's direction.",
    "Preview lighting/ground are Blender stand-ins; explicit LOD glTFs are not wired into Godot; not checked against "
    "022/023.",
]

ready = dict(
    asset_family="broadleaf tree",
    revision=REV,
    status="provisional candidate for user review; preproduction for runbook 027; NOT integrated, NOT approved",
    created=datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
    author="Claude (art candidate lane, docs/visual_overhaul/parallel-handoff.md)",
    decision="rebuild (procedural, Blender script) after a recorded rework attempt",
    decision_reason=("The tree_oak derivative is two stacked faceted domes (3,612 of 3,780 triangles) with an open "
                     "hole in the crown, loose floating fragments and flat palette-swatch UVs. Cleanup + voxel remesh "
                     "+ smoothing closes the hole but keeps the stacked-primitive silhouette, with no leaf clusters, "
                     "root flare or usable texture layout, so it cannot reach the 027 silhouette by rework."),
    source_provenance=dict(
        derivative=dict(path=rep["source"]["path"], sha256=sha(src_json), triangles=rep["source"]["triangles"],
                        produced_by=rep["source"]["produced_by"]),
        derivative_texture=dict(path=str(src_tex.relative_to(ROOT)).replace("\\", "/"), sha256=sha(src_tex))
        if src_json.suffix == ".json" else None,
        pack="Environment Pack - Stylized Nature (supplied ZIP; see CREDITS.md and licenses/supplied_environment_packs.md)",
        used_in_output="none: the delivered meshes and textures are generated from scratch by the script; the source "
                       "only informed the envelope (width/height about 0.85) and was used for the rework evidence",
        pack_modified=False),
    generator=dict(script="tools/blender/art_candidates/broadleaf/broadleaf_candidate.py",
                   copied_to="source/generator/", blender=rep["blender"], deterministic=True,
                   command=('python tools/local_resource.py -- "C:/Program Files/Blender Foundation/Blender 4.2/'
                            'blender.exe" -b --factory-startup -P tools/blender/art_candidates/broadleaf/'
                            f'broadleaf_candidate.py -- --rev {REV}; python tools/blender/art_candidates/broadleaf/'
                            f'make_sheets.py {REV}; python tools/blender/art_candidates/broadleaf/finalize.py {REV}')),
    scale=dict(units="1 unit = 1 game tile/world unit", hero_reference_height=rep["hero_reference_height"],
               origin="trunk base centre on the ground (z=0 / y=0)", up_axis="Z in .blend, +Y in glTF",
               note=("The game fits trees by bounding-box height (world.gd: 2.0-3.7 units, girth 0.86-1.16); the "
                     "authored heights 2.8-3.4 set proportions. Envelope width/height 0.82-0.98 vs 0.857 for the "
                     "current oak.")),
    counts=summary,
    budget=dict(provisional_lod0_target="1,000-3,000 triangles (standards.md 5.3, repeated tree)",
                lod0_within_target=all(1000 <= v["lods"]["0"]["triangles"] <= 3000 for v in summary.values()),
                materials_per_tree="2 (crown + shared bark)", alpha="none (solid crown, no alpha cards)",
                note="Budgets are provisional until runbook 011; no in-engine measurement was made."),
    textures=dict(rep["textures"], filtering_intent="linear + mipmaps + anisotropic (world texture rule)",
                  smoothing_status="UNSMOOTHED. Not run through tools/smooth_textures.gd; tools/smoothed.json untouched. "
                                   "Smooth once at integration."),
    normals="custom split normals: crown 45% geometric + 55% crown-ellipsoid (softened foliage shading); trunk analytic",
    double_sided=False if REV != "rev_001" else True,
    **REV_NOTES.get(REV, {}),
    known_limitations=LIMITS.get(REV) or [
        "Leaf UVs switch from a top planar projection to a side wrap where the surface slope passes about 52 degrees; "
        "a moderate leaf discontinuity and some stretching show along that band in close views (gameplay crop).",
        "Leaf pattern is regular (shingled rows); review whether it should be more clustered.",
        "Preview lighting/ground are Blender stand-ins, not the game's outdoor light; renders are not in-game evidence.",
        "glTF LODs are separate files; how the engine consumes explicit LODs is for integration to decide.",
        "Not checked against step 022 material presets or step 023 scale sheet (not done yet).",
    ],
    files=files,
)
ready.update(OVERRIDES.get(REV, {}))
tmp = D / "READY.json.tmp"
tmp.write_text(json.dumps(ready, indent=1))
os.replace(tmp, D / "READY.json")
print("published", D / "READY.json", len(files), "files")
