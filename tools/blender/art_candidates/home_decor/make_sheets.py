"""Candidate review sheets for the home decor kit (no game files touched).

    python tools/blender/art_candidates/home_decor/make_sheets.py <rev_dir>

previews/art_colourways.png  every print: its own colours, then recoloured from the
                             art masks in four schemes (exactly the game's formula:
                             paper*(1-R-G-B) + R*slot1 + G*slot2 + B*slot3)
previews/sheet_<category>.png  the per-piece tiles from build_kit.py, labelled
previews/schemes.png         the scheme corner renders with their swatches
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))


def font(size):
    for p in ("C:/Windows/Fonts/segoeui.ttf", "C:/Windows/Fonts/arial.ttf"):
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def h2rgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32)


def recolour(mask_cell, slots):
    m = mask_cell.astype(np.float32) / 255
    cols = [h2rgb(c) if c else np.zeros(3, np.float32) for c in slots]
    paper = np.clip(1 - m.sum(-1, keepdims=True), 0, 1)
    out = paper * cols[0] + m[..., 0:1] * cols[1] + m[..., 1:2] * cols[2] + m[..., 2:3] * cols[3]
    return Image.fromarray(out.clip(0, 255).astype(np.uint8))


def art_sheet(rev):
    tex = os.path.join(rev, "textures")
    lay = json.load(open(os.path.join(tex, "art_layout.json")))
    masks = np.asarray(Image.open(os.path.join(tex, "art_masks.png")).convert("RGB"))
    orig = Image.open(os.path.join(tex, "art_original.png")).convert("RGB")
    show = ["seafoam_cottage", "lavender_honey", "forest_cabin", "jewel_pop"]
    prints = list(lay["prints"].items())
    cw, ch = lay["cell"]
    pad, head = 10, 34
    W = pad + (cw + pad) * (1 + len(show))
    H = head + (ch + pad) * len(prints) + pad
    sheet = Image.new("RGB", (W, H), (236, 230, 220))
    d = ImageDraw.Draw(sheet)
    f = font(17)
    for j, t in enumerate(["own colours"] + show):
        d.text((pad + j * (cw + pad), 8), t, fill=(60, 50, 45), font=f)
    for i, (name, p) in enumerate(prints):
        x, y, w, h = p["px"]
        y0 = head + i * (ch + pad)
        sheet.paste(orig.crop((x, y, x + w, y + h)), (pad, y0))
        for j, s in enumerate(show):
            sheet.paste(recolour(masks[y:y + h, x:x + w], p["colourways"][s]), (pad + (j + 1) * (cw + pad), y0))
    # two halves side by side keeps the sheet readable
    half = (len(prints) + 1) // 2
    top = sheet.crop((0, 0, W, head + half * (ch + pad)))
    bot = sheet.crop((0, head + half * (ch + pad), W, H))
    out = Image.new("RGB", (W * 2, top.height), (236, 230, 220))
    out.paste(top, (0, 0))
    out.paste(sheet.crop((0, 0, W, head)), (W, 0))
    out.paste(bot, (W, head))
    out.save(os.path.join(rev, "previews", "art_colourways.png"))


def tile_sheets(rev):
    rep = json.load(open(os.path.join(rev, "build_report.json")))["pieces"]
    tdir = os.path.join(rev, "previews", "tiles")
    if not os.path.isdir(tdir):
        return
    cats = {}
    for n, p in rep.items():
        cats.setdefault(p["category"], []).append(n)
    f, f2 = font(20), font(15)
    for cat, names in cats.items():
        cols = 5 if len(names) > 6 else len(names)
        rows = (len(names) + cols - 1) // cols
        T = 300
        sheet = Image.new("RGB", (cols * T, rows * (T + 48)), (236, 230, 220))
        d = ImageDraw.Draw(sheet)
        for i, n in enumerate(names):
            p = os.path.join(tdir, n + ".png")
            if not os.path.exists(p):
                continue
            x, y = (i % cols) * T, (i // cols) * (T + 48)
            sheet.paste(Image.open(p).convert("RGB").resize((T, T), Image.LANCZOS), (x, y))
            d.text((x + 8, y + T + 4), n, fill=(50, 42, 38), font=f)
            info = rep[n]
            d.text((x + 8, y + T + 27), "%d tris · %.2f×%.2f×%.2f" % (info["triangles"], *info["size_xyz"]), fill=(110, 100, 92), font=f2)
        sheet.save(os.path.join(rev, "previews", "sheet_%s.png" % cat))


def scheme_sheet(rev):
    sdir = os.path.join(rev, "previews", "schemes")
    schemes = json.load(open(os.path.join(HERE, "schemes.json")))["schemes"]
    if not os.path.isdir(sdir):
        return
    T, sw = 400, 26
    cols = 4
    names = [n for n in schemes if os.path.exists(os.path.join(sdir, "scheme_%s.png" % n))]
    rows = (len(names) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * T, rows * (int(T * 0.625) + 64)), (236, 230, 220))
    d = ImageDraw.Draw(sheet)
    f = font(18)
    keys = ["wall", "wall_lower", "trim", "floor", "rug", "fabric", "ceramic", "accent"]
    for i, n in enumerate(names):
        x, y = (i % cols) * T, (i // cols) * (int(T * 0.625) + 64)
        im = Image.open(os.path.join(sdir, "scheme_%s.png" % n)).convert("RGB").resize((T, int(T * 0.625)), Image.LANCZOS)
        sheet.paste(im, (x, y))
        d.text((x + 8, y + im.height + 4), schemes[n]["label"], fill=(50, 42, 38), font=f)
        for k, key in enumerate(keys):
            d.rectangle([x + 8 + k * (sw + 4), y + im.height + 30, x + 8 + k * (sw + 4) + sw, y + im.height + 30 + sw - 6],
                        fill=tuple(int(v) for v in h2rgb(schemes[n][key])), outline=(90, 80, 70))
    sheet.save(os.path.join(rev, "previews", "schemes.png"))


def crop_lineup(rev):
    """The lineup renders with a wide ortho frame; crop to the lit stage and enlarge it."""
    p = os.path.join(rev, "previews", "lineup_lamps_plants.png")
    raw = os.path.join(rev, "previews", "lineup_raw.png")
    if not os.path.exists(raw):
        if not os.path.exists(p):
            return
        os.replace(p, raw)
    im = Image.open(raw).convert("RGB")
    a = np.asarray(im, np.float32)
    diff = np.abs(a - a[5, 5]).sum(-1) > 18
    ys, xs = np.nonzero(diff)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    # keep the band where the pieces stand (lower part of the stage)
    y0 = max(y0, y1 - int((x1 - x0) * 0.22))
    c = im.crop((x0, y0, x1, y1))
    c = c.resize((c.width * 2, c.height * 2), Image.LANCZOS)
    d = ImageDraw.Draw(c)
    f = font(22)
    d.text((12, 8), "now in the game", fill=(70, 60, 55), font=f)
    d.text((int(c.width * 0.39), 8), "home decor candidate rev_001", fill=(70, 60, 55), font=f)
    d.text((12, 36), "red bar = hero height 1.44", fill=(150, 70, 60), font=font(16))
    c.save(p)


if __name__ == "__main__":
    rev = sys.argv[1]
    os.makedirs(os.path.join(rev, "previews"), exist_ok=True)
    art_sheet(rev)
    tile_sheets(rev)
    scheme_sheet(rev)
    crop_lineup(rev)
    print("sheets written")
