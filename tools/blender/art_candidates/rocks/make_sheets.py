"""Labelled preview sheets for a rocks candidate revision (system Python + Pillow).

    python tools/blender/art_candidates/rocks/make_sheets.py rev_001

Reads build/art_candidates/rocks/<rev>/renders and build_report.json; writes <rev>/previews/*.png.
Every sheet carries a banner saying it is a candidate Blender render, not an in-game capture.
"""
import json, sys, pathlib
from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[4]
REV = sys.argv[1] if len(sys.argv) > 1 else "rev_001"
D = ROOT / "build/art_candidates/rocks" / REV
if (D / "READY.json").exists():
    raise SystemExit("published revision is immutable")
R, P = D / "renders", D / "previews"
P.mkdir(exist_ok=True)
rep = json.loads((D / "build_report.json").read_text(encoding="utf-8"))
M = rep["models"]
SHAPES = sorted({m["shape"] for m in M.values()})
PALS = ["grass", "coast"]


def font(px, bold=False):
    n = "QuattrocentoSans-Bold.ttf" if bold else "QuattrocentoSans-Regular.ttf"
    for f in (ROOT / "assets").rglob(n):
        return ImageFont.truetype(str(f), px)
    f = pathlib.Path("C:/Windows/Fonts/arial.ttf")
    return ImageFont.truetype(str(f), px) if f.exists() else ImageFont.load_default()


BANNER = f"CANDIDATE PREVIEW  \u00b7  Blender render, NOT an in-game capture  \u00b7  rocks {REV}  \u00b7  provisional (pre-030)"


def sheet(body, title, out):
    W = max(body.width, 1400)
    top = Image.new("RGB", (W, 96), (24, 22, 26))
    d = ImageDraw.Draw(top)
    d.text((20, 10), title, fill=(255, 255, 255), font=font(30, True))
    d.text((20, 56), BANNER, fill=(240, 200, 120), font=font(22, True))
    o = Image.new("RGB", (W, body.height + 96), (24, 22, 26))
    o.paste(top, (0, 0))
    o.paste(body, ((W - body.width) // 2, 96))
    o.save(P / out)


def label(im, text, px=20):
    im = im.copy()
    d = ImageDraw.Draw(im)
    f = font(px, True)
    w = d.textlength(text, font=f)
    d.rectangle((6, 6, 20 + w, 14 + px + 6), fill=(24, 22, 26))
    d.text((13, 9), text, fill=(255, 255, 255), font=f)
    return im


def grid(ims, cols):
    w, h = max(i.width for i in ims), max(i.height for i in ims)
    rows = (len(ims) + cols - 1) // cols
    body = Image.new("RGB", (w * cols, h * rows), (24, 22, 26))
    for i, im in enumerate(ims):
        body.paste(im, ((i % cols) * w, (i // cols) * h))
    return body


def tri(shape, pal="grass", lod=0):
    return M[f"{shape}_{pal}"]["lods"][str(lod)]["triangles"]


# turntables: per shape a row of 4 turns, grassland then coast
for pal in PALS:
    rows = []
    for s in SHAPES:
        ims = [Image.open(R / f"turn_{s}_{pal}_{i}.png").resize((440, 440)) for i in range(4)]
        ims[0] = label(ims[0], f"{s}: {M[s + '_' + pal]['label']} · {tri(s, pal):,} tris")
        for i in range(1, 4):
            ims[i] = label(ims[i], f"{i * 90}°")
        rows.append(grid(ims, 4))
    sheet(grid(rows, 1), f"Turntables, {pal} palette: LOD0, 4 turns, beside the 1.44 hero stand-in (1-unit grid)",
          f"turntable_{pal}.png")

# rework vs procedural
ims = []
for s in SHAPES:
    for mode in ("source", "rework", "procedural"):
        tag = {"source": "pack cut as supplied", "rework": "rework (hull, planes, bevel)",
               "procedural": "procedural (same pipeline)"}[mode]
        chosen = "  ✓ chosen" if rep["source_choice"][s] == mode else ""
        ims.append(label(Image.open(R / f"cmp_{s}_{mode}.png"), f"{s} {tag}{chosen}", 16))
sheet(grid(ims, 3), "Rework vs rebuild: the pack's cut, its rework and the procedural build (untextured); one kept per shape",
      "rework_vs_rebuild.png")

# LODs
ims = [label(Image.open(R / f"lod_{s}_{l}.png"), f"{s} LOD{l} · {tri(s, 'grass', l):,}", 16)
       for s in SHAPES for l in (0, 1)]
sheet(grid(ims, 4), "LOD0 / LOD1 at the gameplay pitch, grassland (each enlarged to the same frame; not switch distances)",
      "lods.png")

# back-face check
ims = [label(Image.open(R / f"cull_{t}.png").resize((800, 450)), t) for t in ("side", "below", "top")]
ims.append(label(Image.open(R / "cull_control.png").resize((800, 450)), "positive control: base cap removed"))
sheet(grid(ims, 2), "Back-face check (culling off, back faces magenta): LOD0 and LOD1 show none; the open control does",
      "cull_check.png")

# mixed nature lineup and gameplay
sheet(grid([label(Image.open(R / "lineup_front.png"), "front, orthographic"),
            label(Image.open(R / "lineup_game.png"), "gameplay pitch, orthographic")], 1),
      "Mixed nature lineup (read-only refs: broadleaf rev_003 A, shrubs rev_002): rocks A-D, grassland front, coast behind",
      "beside_nature.png")
sheet(Image.open(R / "gameplay.png"),
      "Gameplay angle: game camera (fov 36, offset 0,7,11); grassland rocks among trees and shrubs, coast rocks in front",
      "gameplay_angle.png")
sheet(Image.open(R / "gameplay_close.png"), "Gameplay angle, closer (0.55 of the distance)", "gameplay_close.png")

# atlases side by side
a = [Image.open(D / f"mesh/textures/rocks_{p}.png").convert("RGB").resize((768, 768)) for p in PALS]
sheet(grid([label(a[0], "rocks_grass.png"), label(a[1], "rocks_coast.png")], 2),
      "Baked atlases (unsmoothed), 1024 each: one 512 cell per shape (A top left, B top right, C, D below)",
      "atlases.png")
print("sheets ->", P)
