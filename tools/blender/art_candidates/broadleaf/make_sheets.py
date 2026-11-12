"""Labelled preview sheets for a broadleaf candidate revision (system Python + Pillow).

    python tools/blender/art_candidates/broadleaf/make_sheets.py rev_001

Reads build/art_candidates/broadleaf/<rev>/renders and build_report.json; writes <rev>/previews/*.png.
Every sheet carries a banner saying it is a candidate Blender render, not an in-game capture.
"""
import json, sys, pathlib
from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[4]
REV = sys.argv[1] if len(sys.argv) > 1 else "rev_001"
D = ROOT / "build/art_candidates/broadleaf" / REV
if (D / "READY.json").exists():
    raise SystemExit("published revision is immutable")
R, P = D / "renders", D / "previews"
P.mkdir(exist_ok=True)
rep = json.loads((D / "build_report.json").read_text())
FONT = ROOT / "assets/fonts/LeagueSpartan-SemiBold.ttf"


def font(px):
    for f in [FONT, *sorted((ROOT / "assets").rglob("LeagueSpartan*.ttf")), pathlib.Path("C:/Windows/Fonts/arial.ttf")]:
        if pathlib.Path(f).exists():
            return ImageFont.truetype(str(f), px)
    return ImageFont.load_default()


BANNER = f"CANDIDATE PREVIEW  ·  Blender render, NOT an in-game capture  ·  broadleaf {REV}  ·  provisional (pre-027)"


def sheet(body, title, out):
    W = body.width
    f1, f2 = font(30), font(22)
    top = Image.new("RGB", (W, 96), (24, 22, 26))
    d = ImageDraw.Draw(top)
    d.text((20, 12), title, fill=(255, 255, 255), font=f1)
    d.text((20, 56), BANNER, fill=(240, 200, 120), font=f2)
    o = Image.new("RGB", (W, body.height + 96), (24, 22, 26))
    o.paste(top, (0, 0))
    o.paste(body, (0, 96))
    o.save(P / out)


def label(im, text, px=22):
    im = im.copy()
    d = ImageDraw.Draw(im)
    f = font(px)
    w = d.textlength(text, font=f)
    d.rectangle((8, 8, 24 + w, 16 + px + 8), fill=(24, 22, 26))
    d.text((16, 12), text, fill=(255, 255, 255), font=f)
    return im


V = rep["variants"]
for key, v in V.items():
    ims = [label(Image.open(R / f"turn_{key}_{i}.png"), f"{i * 45}°") for i in range(8)]
    w, h = ims[0].size
    body = Image.new("RGB", (w * 4, h * 2))
    for i, im in enumerate(ims):
        body.paste(im, ((i % 4) * w, (i // 4) * h))
    l0 = v["lods"]["0"]
    sheet(body, f"Variant {key} ({v['label']}) turntable, LOD0 {l0['triangles']} tris, "
                f"{l0['height']:.2f} x {l0['width_x']:.2f} units; orange figure = hero height 1.44, grid = 1 unit",
          f"turntable_{key}.png")

g = Image.open(R / "gameplay_grove.png")
sheet(g, "Gameplay angle: game camera (fov 36, offset 0,7,11, look 1 up), LOD0 trees on tile centres; "
         "orange figure = hero 1.44", "gameplay_angle.png")
sheet(g.crop((760, 30, 1400, 390)).resize((1280, 720), Image.LANCZOS),
      "Gameplay angle, 2x crop of the centre trees (crown surface, trunk base)", "gameplay_angle_crop.png")

w, h = 480, 480
body = Image.new("RGB", (w * 3, h * 3))
for r, key in enumerate("ABC"):
    for lod in range(3):
        n = V[key]["lods"][str(lod)]["triangles"]
        body.paste(label(Image.open(R / f"lod_{key}_{lod}.png"), f"{key} LOD{lod}: {n} tris"), (lod * w, r * h))
sheet(body, "LODs at the gameplay pitch (orthographic): LOD0 / LOD1 / LOD2", "lods.png")

src_t = rep["source"]["triangles"]
rew_t = rep["rework_attempt"]["triangles"]
a_t = V["A"]["lods"]["0"]["triangles"]
cells = [("compare_source", f"{rep['source'].get('label', 'existing tree_oak derivative')} ({src_t} tris)"),
         ("compare_rework", f"{rep['rework_attempt'].get('label', 'rework attempt, geometry only')} ({rew_t} tris)"),
         ("compare_A", f"{REV} candidate A ({a_t} tris)")]
w, h = 520, 600
body = Image.new("RGB", (w * 3, h + w))
for i, (n, t) in enumerate(cells):
    body.paste(label(Image.open(R / f"{n}.png"), t, 18), (i * w, 0))
    body.paste(label(Image.open(R / f"{n}_game.png").resize((w, w)), "gameplay pitch", 18), (i * w, h))
sheet(body, rep.get("compare_title", "Rework vs rebuild: source keeps two stacked domes after cleanup; rebuild adds "
                                    "lobes, leaves, root flare"), "rework_vs_rebuild.png")

if (D / "mesh/textures/broadleaf_A.png").exists():  # rev_003+ rework: one recoloured texture per variant
    src_tex = ROOT / "build/art_candidates/broadleaf/sources/stylized_tree_roroer/texture_0.png"
    body = Image.new("RGB", (512 * 4, 512))
    if src_tex.exists():
        body.paste(label(Image.open(src_tex).convert("RGB").resize((512, 512), Image.LANCZOS),
                         "source texture (roroer, as supplied)", 18), (0, 0))
    for i, k in enumerate("ABC"):
        im = Image.open(D / f"mesh/textures/broadleaf_{k}.png").convert("RGB").resize((512, 512), Image.LANCZOS)
        body.paste(label(im, f"broadleaf_{k}.png (recoloured, unsmoothed)", 18), ((i + 1) * 512, 0))
    sheet(body, "Textures: the source's painting recoloured to the approved A/B/C leaf and bark palettes",
          "textures.png")
    tex = []
elif (D / "mesh/textures/leaf_A.png").exists():  # rev_001 layout: shared tiling leaf textures
    tex = [("mesh/textures/leaf_A.png", "leaf_A"), ("mesh/textures/leaf_B.png", "leaf_B"),
           ("mesh/textures/leaf_C.png", "leaf_C"), ("mesh/textures/bark.png", "bark")]
    title = "Painted textures (generated in the Blender script, seamless tiles)"
else:  # rev_002+: baked crown atlases; the approved tiles are bake sources
    tex = [(f"mesh/textures/crown_{k}_lod0.png", f"crown_{k}_lod0 (baked)") for k in "ABC"] +           [("mesh/textures/bark.png", "bark tile")]
    title = "Textures: baked crown atlases (LOD0 1024) and the bark tile; all unsmoothed"
if tex:
    body = Image.new("RGB", (512 * 4, 512 + 512))
    for i, (t, name) in enumerate(tex):
        im = Image.open(D / t).convert("RGB")
        body.paste(label(im.resize((512, 512), Image.LANCZOS), f"{name}", 18), (i * 512, 0))
        if "crown" in t:
            src = Image.open(D / f"source/art/leaf_{t.split('crown_')[1][0]}.png").convert("RGB")
            body.paste(label(src, "bake source: approved rev_001 tile", 18), (i * 512, 512))
        else:
            tiled = Image.new("RGB", (512, 512))
            small = im.resize((256, 256), Image.LANCZOS)
            for x in range(2):
                for y in range(2):
                    tiled.paste(small, (x * 256, y * 256))
            body.paste(label(tiled, "2x2 tiling check", 18), (i * 512, 512))
    sheet(body, title, "textures.png")

# rev_002+: matched seam close-ups against the comparison revision, culling checks, matched gameplay crop
seams = sorted(R.glob("seam_A_0_*.png"))
if seams:
    cmp_rev = [x.stem.split("seam_A_0_")[1] for x in seams if not x.stem.endswith(REV)][0]
    for key in "ABC":
        body = Image.new("RGB", (640 * 2, 640 * 3))
        for r, rot in enumerate((0, 120, 240)):
            for c, tag in enumerate((cmp_rev, REV)):
                body.paste(label(Image.open(R / f"seam_{key}_{rot}_{tag}.png"), f"{tag}, tree turned {rot}°", 20),
                           (c * 640, r * 640))
        sheet(body, f"Seam check {key}: {cmp_rev} (left) vs {REV} (right), same camera "
                    f"(gameplay pitch/fov)", f"seam_compare_{key}.png")
    box = (150, 140, 480, 400)
    body = Image.new("RGB", (990 * 2, 780))
    for c, tag in enumerate((cmp_rev, REV)):
        body.paste(label(Image.open(R / f"seam_A_0_{tag}.png").crop(box).resize((990, 780), Image.LANCZOS),
                         f"{tag}: 3x crop of the top/side band", 22), (c * 990, 0))
    sheet(body, f"Seam close crop, variant A: {cmp_rev} (left) vs {REV} (right)", "seam_crop_A.png")
    old = ROOT / "build/art_candidates/broadleaf" / cmp_rev / "renders/gameplay_grove.png"
    if old.exists():
        crop = (760, 30, 1400, 390)
        body = Image.new("RGB", (1280 * 2, 720))
        for c, (tag, f) in enumerate(((cmp_rev, old), (REV, R / "gameplay_grove.png"))):
            body.paste(label(Image.open(f).crop(crop).resize((1280, 720), Image.LANCZOS), tag, 24), (c * 1280, 0))
        sheet(body, f"Gameplay angle, matched 2x crop: {cmp_rev} (left) vs {REV} (right)", "gameplay_compare.png")
    views = ["under", "roots", "junction", "top"]
    for key in "ABC":
        rows = [("lod0", 0), ("lod0", 180), ("lod1", 0), ("lod2", 0)]
        body = Image.new("RGB", (360 * 4, 360 * 4))
        for r, (lod, az) in enumerate(rows):
            for c, vname in enumerate(views):
                body.paste(label(Image.open(R / f"cull_{key}_{lod}_{vname}_{az}.png"), f"{lod.upper()} {vname} {az}°", 16),
                           (c * 360, r * 360))
        sheet(body, f"Backface check {key}: culling off, back faces RED; " +
              rep.get("cull_note", "none = correct winding, no openings"), f"cull_check_{key}.png")
    ctrl = R / "cull_control_source.png"
    if ctrl.exists():
        body = Image.new("RGB", (520 * 2, 520))
        body.paste(label(Image.open(ctrl).resize((520, 520)), "control: source oak (open crown)", 18), (0, 0))
        body.paste(label(Image.open(R / "cull_A_lod0_under_0.png").resize((520, 520)), f"{REV} A LOD0 underside", 18),
                   (520, 0))
        sheet(body, "Backface check control: red shows where back faces are seen", "cull_control.png")
print("sheets written to", P)
