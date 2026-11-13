"""Publish a shrubs candidate revision: copy the generator in, hash every file, write READY.json LAST (atomically).

    python tools/blender/art_candidates/shrubs/finalize.py rev_001

A revision that already has READY.json is immutable: this refuses to run on it. It also refuses when a back-face
check render shows red or any exported mesh has open/non-manifold edges.
"""
import hashlib, json, os, shutil, sys, pathlib, datetime
from PIL import Image
import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[4]
REV = sys.argv[1] if len(sys.argv) > 1 else "rev_001"
D = ROOT / "build/art_candidates/shrubs" / REV
if (D / "READY.json").exists():
    raise SystemExit(f"{D} already published (READY.json exists); corrections go in a new revision")
HERE = pathlib.Path(__file__).resolve().parent
BROADLEAF = ROOT / "build/art_candidates/broadleaf/rev_003/READY.json"


def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def red_pixels(p):  # the check colour is magenta (no kit colour is): green far below both red and blue
    a = np.asarray(Image.open(p).convert("RGB")).astype(int)
    return int(((a[..., 0] - a[..., 1] > 100) & (a[..., 2] - a[..., 1] > 100)).sum())


rep = json.loads((D / "build_report.json").read_text())
cull = {t: red_pixels(D / f"renders/cull_{t}.png") for t in ("side", "below", "top")}
control = red_pixels(D / "renders/cull_control.png")
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

PROVISIONAL = {"bush": "300-1,800 (standards.md 5.3: rock or substantial shrub)",
               "hedge": "300-1,800 per piece (standards.md 5.3: substantial shrub)",
               "flower": "100-800 (standards.md 5.3: small repeated prop)",
               "fruit": "100-800 (standards.md 5.3: small repeated prop)"}
RANGE = {"bush": (300, 1800), "hedge": (300, 1800), "flower": (100, 800), "fruit": (100, 800)}
summary = {}
for n, m in rep["models"].items():
    lo, hi = RANGE[m["kind"]]
    summary[n] = dict(kind=m["kind"], label=m["label"], provisional_lod0_range=PROVISIONAL[m["kind"]],
                      lod0_within_range=lo <= m["lods"]["0"]["triangles"] <= hi,
                      lods={l: {k: d[k] for k in ("file", "triangles", "vertices", "materials", "textures",
                                                  "texture_files", "double_sided", "open_boundary_edges",
                                                  "nonmanifold_edges", "width_x", "depth_y", "height",
                                                  "bbox_min_zup", "bbox_max_zup", "parts")}
                            for l, d in m["lods"].items()})
    if "fruit_anchors_lod0" in m:
        summary[n]["fruit_anchors"] = dict(
            points=m["fruit_anchors_lod0"],
            note="centres (Z-up, model space) and radii of the fruit on the bush, for pick points at integration; "
                 "the same bush without fruit is bush_E_picked")

ready = dict(
    revision=REV,
    kind="art candidate: bushes, hedges, flowers and a fruit bush (preproduction for runbook 028)",
    supersedes=("rev_001 (approved 2026-11-13; left unchanged). rev_001's nine models are rebuilt from unchanged "
                "specs and their meshes are byte-identical; the shared atlas gains a fruit cell"),
    changes_from_previous=[
        "hedge_middle: a straight 1-tile hedge piece. Its body has a squared (superellipse, p = 6) footprint, "
        "resampled by arc length so the scallops stay even, and reaches about 0.2 past each tile edge, so middles "
        "laid end to end and the rounded-end hedge join without a notch; a run's last middle ends squared off.",
        "bush_E: a fruit bush with four large fruit (about 0.18-0.2 across) on its south side; bush_E_picked is the same "
        "bush without them, for after picking. Fruit centres are recorded as pick points (models.bush_E.fruit_anchors).",
        "fruit: the fruit on its own (stalk and leaf; 16 segments instead of the bush's 12, since it is seen closer), for holding, dropping or an item view.",
        "Atlas: a fruit cell (deep red underneath to orange-gold on top, a soft sheen band); other cells unchanged.",
    ],
    gameplay_requested=("The user wants the fruit pickable, and fed to beasts to restore HP like a Minor Potion "
                        "(item_db minor_potion: heal 40, target ally). That is runtime work for integration (Codex's "
                        "lane); this revision only supplies the art and pick points."),
    status="CANDIDATE, provisional. Not integrated; runbook 028 is NOT complete. Awaits the user's review, "
           "Codex's technical review, steps 011/022/023 (budgets, material presets, scale sheet) and 027 integration.",
    published=datetime.date.today().isoformat(),
    owner="Claude art-candidate lane (docs/visual_overhaul/parallel-handoff.md)",
    style_reference=dict(revision="broadleaf rev_003 (approved 2026-11-12)",
                         ready_sha256=sha(BROADLEAF) if BROADLEAF.exists() else None,
                         use="imported read-only for side-by-side previews; no rev_003 geometry or texture is in "
                             "this revision",
                         grammar="pillowy painted domes with scalloped hems; soft painted marks; no individual-leaf "
                                 "pattern; leaf palettes A/B/C reused from the approved broadleaf palettes"),
    provenance=dict(
        decision="procedural build: the existing bush_*/shrub_* assets are cut from the same Stylized Nature pack "
                 "as tree_oak (tools/prepare_stylized_nature.py), whose rework toward the dome grammar failed for "
                 "broadleaf; the kit is built directly in the approved rev_003 dome grammar instead",
        third_party_content="none: all geometry and the atlas are generated by this revision's script",
        credit_required="none for this revision (broadleaf rev_003's roroer credit applies to the trees only)",
        generator=dict(script="tools/blender/art_candidates/shrubs/shrubs_candidate.py", copied_to="source/generator/",
                       blender=rep["blender"], deterministic="fixed seeds, no time-dependent input",
                       command=('python tools/local_resource.py -- "C:/Program Files/Blender Foundation/Blender 4.2/'
                                'blender.exe" -b --factory-startup -P tools/blender/art_candidates/shrubs/'
                                f'shrubs_candidate.py -- --rev {REV}; python tools/blender/art_candidates/shrubs/'
                                f'make_sheets.py {REV}; python tools/blender/art_candidates/shrubs/finalize.py {REV}'))),
    scale=dict(units=rep["units"], hero_reference_height=rep["hero_reference_height"],
               notes=["Bushes stay inside about 0.9 x 0.85 so world.gd's fit-to-blocking-tile (0.9) barely rescales "
                      "them (bush_B is 1.0 wide and would be fitted to 0.9).",
                      "The rounded hedge spans 2 tiles (2.06 long, 0.81 deep, 0.96 high). hedge_middle covers 1 "
                      "tile and is 1.40 long so its ends overlap the neighbouring pieces.",
                      "bush_E is about 0.94 x 0.80 x 0.83; each fruit is about 0.18-0.2 across (radius 0.09-0.1).",
                      "Flower clumps are about 0.32-0.44 wide and 0.47-0.58 high (knee height on the hero), for "
                      "walk-through flower tiles."]),
    materials=dict(count_per_model=1, name="shrubs_kit", shared_by="every model and LOD",
                   texture="mesh/textures/shrubs_atlas.png (1024 RGB, one atlas for the kit)",
                   double_sided=False, alpha="none (closed opaque solids, no cards)",
                   filtering="linear magnification exported; anisotropic mipmaps must be set at integration",
                   smoothing="NOT smoothed; tools/smoothed.json untouched (smooth once at integration)"),
    budget_note="All budgets are provisional until runbook 011; no in-engine measurement was made.",
    models=summary,
    verification=dict(
        closed_solids="every model and LOD: 0 open boundary edges, 0 non-manifold edges after welding (build_report)",
        backface_check=dict(colour="magenta", flagged_pixels=cull, positive_control_flagged_pixels=control,
                            sheet="previews/cull_check.png"),
        local_model="qwen3.6-27b described the draft (red) back-face renders as having no red; superseded by the magenta pixel count, since coral tulips also read as red",
        not_done="no engine import, no in-game capture, no performance measurement, no 022/023 check"),
    limitations=[
        "LOD1 blossoms and daisy heads become five/eight-point stars (2 segments per petal); fine at distance only.",
        "There is no hedge corner piece yet; runs turn by ending one run and starting another.",
        "Where hedge_middle pieces overlap, the intersection shows as a faint crease in the skirt.",
        "Bush D's blossoms are separate small solids (about 140 triangles each at LOD0); a texture-only variant is "
        "cheaper if 011 budgets require it.",
        "Preview light and ground are Blender stand-ins; renders are not in-game evidence.",
    ],
    files=files,
)
tmp = D / "READY.json.tmp"
tmp.write_text(json.dumps(ready, indent=1))
os.replace(tmp, D / "READY.json")
print("READY", D / "READY.json", len(files), "files")
