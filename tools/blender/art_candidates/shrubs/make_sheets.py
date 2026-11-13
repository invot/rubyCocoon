"""Labelled preview sheets for a shrubs candidate revision (system Python + Pillow).



    python tools/blender/art_candidates/shrubs/make_sheets.py rev_001



Reads build/art_candidates/shrubs/<rev>/renders and build_report.json; writes <rev>/previews/*.png.

Every sheet carries a banner saying it is a candidate Blender render, not an in-game capture.

"""

import json, sys, pathlib

from PIL import Image, ImageDraw, ImageFont



ROOT = pathlib.Path(__file__).resolve().parents[4]

REV = sys.argv[1] if len(sys.argv) > 1 else "rev_001"

D = ROOT / "build/art_candidates/shrubs" / REV

if (D / "READY.json").exists():

    raise SystemExit("published revision is immutable")

R, P = D / "renders", D / "previews"

P.mkdir(exist_ok=True)

rep = json.loads((D / "build_report.json").read_text())

M = rep["models"]





def font(px, bold=False):

    names = ["QuattrocentoSans-Bold.ttf" if bold else "QuattrocentoSans-Regular.ttf"]

    for n in names:

        for f in (ROOT / "assets").rglob(n):

            return ImageFont.truetype(str(f), px)

    for f in [pathlib.Path("C:/Windows/Fonts/arial.ttf")]:

        if f.exists():

            return ImageFont.truetype(str(f), px)

    return ImageFont.load_default()





BANNER = f"CANDIDATE PREVIEW  ·  Blender render, NOT an in-game capture  ·  shrubs {REV}  ·  provisional (pre-028)"





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





def label(im, text, px=22):

    im = im.copy()

    d = ImageDraw.Draw(im)

    f = font(px, True)

    w = d.textlength(text, font=f)

    d.rectangle((8, 8, 24 + w, 16 + px + 8), fill=(24, 22, 26))

    d.text((16, 11), text, fill=(255, 255, 255), font=f)

    return im





def grid(ims, cols):

    w, h = max(i.width for i in ims), max(i.height for i in ims)

    rows = (len(ims) + cols - 1) // cols

    body = Image.new("RGB", (w * cols, h * rows), (24, 22, 26))

    for i, im in enumerate(ims):

        body.paste(im, ((i % cols) * w, (i // cols) * h))

    return body





def tri(name, lod):

    return M[name]["lods"][str(lod)]["triangles"]





# turntables: one row of 4 views per model

for group, names, title in [

    ("bushes", [n for n in M if M[n]["kind"] in ("bush", "hedge")], "Turntables: bushes and hedges, LOD0, 4 turns, beside the 1.44 hero stand-in (1-unit grid)"),

    ("flowers", [n for n in M if M[n]["kind"] in ("flower", "fruit")], "Turntables: flower clumps and the fruit, LOD0, 4 turns, beside the 1.44 hero stand-in (1-unit grid)")]:

    rows = []

    for n in names:

        ims = [Image.open(R / f"turn_{n}_{i}.png") for i in range(4)]

        ims[0] = label(ims[0], f"{n}: {M[n]['label'].split(' (')[0]}  ·  {tri(n, 0):,} tris")

        for i in range(1, 4):

            ims[i] = label(ims[i], f"{i * 90}°")

        rows.append(grid(ims, 4))

    W = max(r.width for r in rows)

    body = Image.new("RGB", (W, sum(r.height for r in rows)), (24, 22, 26))

    y = 0

    for r in rows:

        body.paste(r, (0, y))

        y += r.height

    if body.width > 2200:

        body = body.resize((2200, int(body.height * 2200 / body.width)), Image.LANCZOS)

    sheet(body, title, f"turntable_{group}.png")



# LODs: every model's LOD0 and LOD1 at 300 px high, flowed into rows

ims = []

for n in M:

    for lod in (0, 1):

        im = Image.open(R / f"lod_{n}_{lod}.png")

        im = im.resize((300 * im.width // im.height, 300))

        ims.append(label(im, f"{n} LOD{lod} · {tri(n, lod):,}", 18))

rows, row, w = [], [], 0

for im in ims:

    if row and w + im.width > 2400:

        rows.append(row); row, w = [], 0

    row.append(im); w += im.width

rows.append(row)

W = max(sum(i.width for i in r) for r in rows)

body = Image.new("RGB", (W, 300 * len(rows)), (24, 22, 26))

for k, r in enumerate(rows):

    x = 0

    for im in r:

        body.paste(im, (x, 300 * k)); x += im.width

sheet(body, "LOD0 / LOD1 at the gameplay pitch (each enlarged to the same frame; not switch distances)", "lods.png")



# back-face check

ims = [label(Image.open(R / f"cull_{t}.png").resize((800, 450)), t) for t in ("side", "below", "top")]

ims.append(label(Image.open(R / "cull_control.png").resize((800, 450)), "positive control: underside removed"))

sheet(grid(ims, 2), "Back-face check (culling off, back faces magenta): the kit at LOD0 shows none; the open control does",

      "cull_check.png")



# beside broadleaf rev_003

f = Image.open(R / "lineup_front.png")

g = Image.open(R / "lineup_game.png")

sheet(grid([label(f, "front, orthographic"), label(g, "gameplay pitch, orthographic")], 1),

      "Beside approved broadleaf rev_003 A (read-only): hero, bushes A-D, hedge, daisy, coral/butter tulips, bellflowers",

      "beside_broadleaf.png")

sheet(Image.open(R / "gameplay.png"),

      "Gameplay angle: game camera (fov 36, offset 0,7,11, look 1 up); broadleaf rev_003 trees behind; orange = hero 1.44",

      "gameplay_angle.png")

sheet(Image.open(R / "gameplay_close.png"),

      "Gameplay angle, closer (0.55 of the distance): a hedge run (rounded piece + straight middles), bushes, flowers",

      "gameplay_close.png")



if (R / "new_front.png").exists():

    sheet(grid([label(Image.open(R / "new_front.png"), "front, orthographic"),

                label(Image.open(R / "new_game.png"), "gameplay pitch, orthographic")], 1),

          "New in this revision, beside broadleaf rev_003 A: fruit bush, picked twin, the fruit, 3 straight middles + rounded hedge",

          "new_pieces.png")



# atlas

a = Image.open(D / "mesh/textures/shrubs_atlas.png").convert("RGB")

d = ImageDraw.Draw(a)

fnt = font(18, True)

for name, c in rep["texture"]["layout"].items():

    x, y = c["col"] * 256, (3 - c["row_from_bottom"]) * 256

    d.rectangle((x + 4, y + 4, x + 12 + d.textlength(name, font=fnt), y + 28), fill=(24, 22, 26))

    d.text((x + 8, y + 6), name, fill=(255, 255, 255), font=fnt)

sheet(a, "Shared 1024 atlas (unsmoothed): foliage cells v = hem to top; petal cells v = base to tip", "atlas.png")

print("sheets ->", P)

