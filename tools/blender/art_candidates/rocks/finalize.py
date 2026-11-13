"""Publish a rocks candidate revision: copy the generator in, hash every file, write READY.json LAST (atomically).

    python tools/blender/art_candidates/rocks/finalize.py rev_001

Refuses an already published revision, any back-face render showing magenta, a control that doesn't, and any
open or non-manifold mesh.
"""
import hashlib, json, os, shutil, sys, pathlib, datetime
from PIL import Image
import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[4]
REV = sys.argv[1] if len(sys.argv) > 1 else "rev_001"
D = ROOT / "build/art_candidates/rocks" / REV
if (D / "READY.json").exists():
    raise SystemExit(f"{D} already published (READY.json exists); corrections go in a new revision")
HERE = pathlib.Path(__file__).resolve().parent


def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def flagged(p):  # the check colour is magenta: green far below both red and blue
    a = np.asarray(Image.open(p).convert("RGB")).astype(int)
    return int(((a[..., 0] - a[..., 1] > 100) & (a[..., 2] - a[..., 1] > 100)).sum())


rep = json.loads((D / "build_report.json").read_text(encoding="utf-8"))
cull = {t: flagged(D / f"renders/cull_{t}.png") for t in ("side", "below", "top")}
control = flagged(D / "renders/cull_control.png")
bad = [f"{n} lod{l}" for n, m in rep["models"].items() for l, d in m["lods"].items()
       if d["open_boundary_edges"] or d["nonmanifold_edges"]]
if any(cull.values()) or control == 0 or bad:
    raise SystemExit(f"checks failed: cull={cull} control={control} open/nonmanifold={bad}")

gen = D / "source/generator"
gen.mkdir(parents=True, exist_ok=True)
for f in sorted(HERE.glob("*.py")):
    shutil.copy2(f, gen / f.name)
files = {}
for p in sorted(D.rglob("*")):
    if p.is_file() and p.name not in ("READY.json", "READY.json.tmp") and p.suffix != ".import":
        files[p.relative_to(D).as_posix()] = dict(sha256=sha(p), bytes=p.stat().st_size)

summary = {}
for n, m in rep["models"].items():
    t0 = m["lods"]["0"]["triangles"]
    summary[n] = dict(shape=m["shape"], palette=m["palette"], label=m["label"], built_from=m["built_from"],
                      provisional_lod0_range="300-1,800 (standards.md 5.3: rock or substantial shrub)",
                      lod0_at_or_under_max=t0 <= 1800, lod0_under_range_min=t0 < 300,
                      lods={l: {k: d[k] for k in ("file", "triangles", "vertices", "materials", "textures",
                                                  "texture_files", "double_sided", "open_boundary_edges",
                                                  "nonmanifold_edges", "width_x", "depth_y", "height_above_ground",
                                                  "buried_depth", "bbox_min_zup", "bbox_max_zup")}
                            for l, d in m["lods"].items()})

ready = dict(
    revision=REV,
    kind="art candidate: rock family, grassland and coast palettes (preproduction for runbook 030)",
    status="CANDIDATE, provisional. Not integrated; runbook 030 is NOT complete. Awaits the user's review, "
           "Codex's technical review, steps 011/022/023 (budgets, material presets, scale sheet) and the mixed "
           "nature gallery (028).",
    published=datetime.date.today().isoformat(),
    owner="Claude art-candidate lane (docs/visual_overhaul/parallel-handoff.md)",
    style_reference=dict(
        companions="broadleaf rev_003 (approved) and shrubs rev_002, imported read-only for the mixed lineup and "
                   "gameplay previews; none of their geometry or textures is in this revision",
        standard="standards.md 11 Rocks: broad planes, softened transitions, partly buried, no balancing boulders, "
                 "accidental pyramids or mixed angular/inflated shapes"),
    provenance=dict(
        decision="per shape: rework where the supplied cut has designed broad planes, rebuild where it is a peak or "
                 "spike (both through the same hull/plane/bevel pipeline; previews/rework_vs_rebuild.png)",
        choice=rep["source_choice"], reasons=rep["choice_reason"],
        source_pack=dict(name="Environment Pack - Stylized Rock (supplied by the user as a ZIP)",
                         licence="none included; recorded in CREDITS.md and licenses/supplied_environment_packs.md "
                                 "(the user's rule: a pack with no credit or licence is treated as Creative Commons)",
                         used="vertex positions of the mountain_1 and mountain_0 cuts (build/nature_split, via "
                              "tools/prepare_stylized_nature.py) as hull input for rock_B and rock_C; no pack "
                              "texture, UV or face is used; the pack stays untouched",
                         cut_sha256={n: sha(ROOT / f"build/nature_split/{n}.json")
                                     for n in ("mountain_1", "mountain_0", "field_rock", "rock_small")}),
        generator=dict(script="tools/blender/art_candidates/rocks/rocks_candidate.py", copied_to="source/generator/",
                       blender=rep["blender"], deterministic="fixed seeds, no time-dependent input",
                       command=('python tools/local_resource.py -- "C:/Program Files/Blender Foundation/Blender 4.2/'
                                'blender.exe" -b --factory-startup -P tools/blender/art_candidates/rocks/'
                                f'rocks_candidate.py -- --rev {REV}; python tools/blender/art_candidates/rocks/'
                                f'make_sheets.py {REV}; python tools/blender/art_candidates/rocks/finalize.py {REV}'))),
    scale=dict(units=rep["units"], hero_reference_height=rep["hero_reference_height"], buried_depth=rep["buried_depth"],
               notes=["Each base continues 0.07 below the ground line (z = 0) and is capped, so a rock set at its "
                      "origin reads as partly buried; the game currently re-anchors rocks by their AABB bottom "
                      "(world.gd), which would lift them by 0.07 unless integration anchors at the origin.",
                      "The game fits rocks with VA.fit_scale, so the authored size sets proportion; envelopes: A "
                      "0.81 x 0.76 x 0.59, B 0.81 x 0.76 x 0.91, C 1.35 x 0.92 x 0.40 (knee high), D 0.60 x 0.42 x "
                      "0.23."]),
    materials=dict(count_per_model=1, names=["rocks_grass", "rocks_coast"],
                   textures=rep["textures"]["files"], size="1024 RGB each, a 512 cell per shape",
                   double_sided=False, alpha="none (closed opaque solids)",
                   normals="weighted normals (face area) applied at export: broad planes shade flat, bevels round",
                   filtering="linear magnification exported; anisotropic mipmaps must be set at integration",
                   smoothing="NOT smoothed; tools/smoothed.json untouched (smooth once at integration)"),
    budget_note="All budgets are provisional until runbook 011; no in-engine measurement was made. rock_A's LOD0 "
                "sits below the planning range's minimum, which is a planning floor, not a requirement.",
    models=summary,
    verification=dict(
        closed_solids="every model and LOD: 0 open boundary edges, 0 non-manifold edges after welding",
        backface_check=dict(colour="magenta", flagged_pixels=cull, positive_control_flagged_pixels=control,
                            sheet="previews/cull_check.png"),
        not_done="no engine import, no in-game capture, no performance measurement, no 022/023 check"),
    limitations=[
        "rock_A (procedural) shows a few thin plane joins converging on its shoulder; the planes are flat but "
        "small there.",
        "The coast palette's wet band is subtle at gameplay distance; integration may darken it against real water.",
        "The two palettes share geometry; a coast rock may want barnacle or tide-line detail in a later revision.",
        "Horizon hills (mountain_*) and cliff faces are not part of this family.",
        "Preview light and ground are Blender stand-ins; renders are not in-game evidence.",
    ],
    files=files,
)
tmp = D / "READY.json.tmp"
tmp.write_text(json.dumps(ready, indent=1, ensure_ascii=False), encoding="utf-8")
os.replace(tmp, D / "READY.json")
print("READY", D / "READY.json", len(files), "files")
