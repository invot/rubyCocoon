"""Paints the home decor kit's two texture atlases (art candidate, not a runtime asset).

    python tools/blender/art_candidates/home_decor/paint_atlas.py <out_dir>

decor_atlas.png  1024x1024, an 8x8 grid of 128 px material cells. Cells in the
                 tintable families (fabric, ceramic/paint, wood, trim) are painted
                 in soft neutral greys; the game multiplies them by a colour-scheme
                 tint chosen per house through the mesh's vertex-colour mask
                 (R fabric, G ceramic/accent, B wood, A trim paint). Every other
                 cell (leaves, brass, terracotta, glass...) carries its own colour.
Framed artwork is NOT painted here: by the user's direction (2026-11-12) it comes
only from the supplied SVG prints (art_masks.py).
layout.json      Every cell's pixel rect and UV rect, family and tint channel.

Style: soft gradients, clear shapes, no grain, speckle or hard black lines
(AGENTS.md "Art and animation consistency"). Shapes are drawn at 4x and
downsampled, then lightly blurred. Deterministic: no randomness without a seed.
"""
import json
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

CELL = 128
GRID = 8
SS = 4  # supersampling for drawn shapes


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


# ---------------------------------------------------------------- numpy helpers
def grid(w, h):
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    return x / max(1, w - 1), y / max(1, h - 1)


def smooth(t):
    t = np.clip(t, 0, 1)
    return t * t * (3 - 2 * t)


def to_img(arr):
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")


def grey(v):
    """A grey field (0..1) to an RGB array (neutral, slightly warm so tints stay cosy)."""
    v = np.clip(v, 0, 1)
    return np.stack([v * 255, v * 253, v * 250], -1)


def vgrad(w, h, top, bottom):
    _, y = grid(w, h)
    return top + (bottom - top) * smooth(y)


# ---------------------------------------------------------------- material cells
def cell_linen(w, h):
    x, y = grid(w, h)
    v = 0.93 - 0.08 * smooth(y) + 0.015 * np.sin(x * math.pi * 10) * np.sin(y * math.pi * 10)
    return grey(v)


def cell_pleats(w, h):
    x, y = grid(w, h)
    p = 0.5 + 0.5 * np.cos(x * math.pi * 2 * 12)
    v = 0.86 + 0.08 * p ** 2 - 0.06 * smooth(y)
    # piping at top and bottom hems
    hem = (y < 0.07) | (y > 0.93)
    v = np.where(hem, 0.8 + 0.08 * np.cos((y - 0.5) * math.pi), v)
    return grey(v)


def cell_stripe(w, h):
    x, y = grid(w, h)
    s = smooth((np.abs(((x * 4) % 1.0) - 0.5) - 0.18) * 14)
    v = 0.95 - 0.28 * (1 - s) - 0.05 * smooth(y)
    return grey(v)


def cell_gingham(w, h):
    x, y = grid(w, h)
    a = smooth((np.abs(((x * 4) % 1.0) - 0.5) - 0.25) * 16)
    b = smooth((np.abs(((y * 4) % 1.0) - 0.5) - 0.25) * 16)
    v = 0.96 - 0.17 * (1 - a) - 0.17 * (1 - b)
    return grey(v)


def cell_dots(w, h):
    x, y = grid(w, h)
    fx, fy = (x * 5) % 1.0, (y * 5 + 0.5 * (np.floor(x * 5) % 2)) % 1.0
    d = np.hypot(fx - 0.5, fy - 0.5)
    v = 0.92 - 0.3 * (1 - smooth((d - 0.16) * 18)) - 0.04 * smooth(y)
    return grey(v)


def cell_knit(w, h):
    x, y = grid(w, h)
    col = (x * 6) % 1.0
    row = (y * 8 + np.where(np.floor(x * 6) % 2 == 0, 0.0, 0.5)) % 1.0
    # rounded V stitches
    vv = np.abs(col - 0.5) * 2
    stitch = 1 - smooth((np.abs(row - (0.35 + 0.4 * vv)) - 0.12) * 9)
    v = 0.78 + 0.16 * stitch - 0.04 * smooth(y)
    return grey(v)


def cell_patchwork(w, h):
    x, y = grid(w, h)
    rng = np.array([[0.95, 0.78, 0.88, 0.7], [0.74, 0.92, 0.68, 0.9], [0.86, 0.66, 0.96, 0.8], [0.7, 0.88, 0.76, 0.93]])
    ix = np.clip((x * 4).astype(int), 0, 3)
    iy = np.clip((y * 4).astype(int), 0, 3)
    v = rng[iy, ix]
    seam = (np.minimum(np.abs(((x * 4) % 1) - 0.5), np.abs(((y * 4) % 1) - 0.5)))
    v = v - 0.06 * (1 - smooth((0.5 - np.maximum(np.abs(((x * 4) % 1) - 0.5), np.abs(((y * 4) % 1) - 0.5))) * 30))
    return grey(v)


def cell_velvet(w, h):
    x, y = grid(w, h)
    v = 0.9 - 0.14 * smooth(y) + 0.04 * np.cos((x - 0.3) * math.pi * 2)
    return grey(v)


def cell_glaze(w, h):
    x, y = grid(w, h)
    v = 0.94 - 0.16 * smooth(y) + 0.06 * np.exp(-((x - 0.3) / 0.08) ** 2)
    return grey(v)


def cell_glaze_band(w, h):
    x, y = grid(w, h)
    v = 0.93 - 0.12 * smooth(y)
    band = np.exp(-((y - 0.22) / 0.05) ** 2) + 0.6 * np.exp(-((y - 0.32) / 0.025) ** 2)
    v = v - 0.22 * band + 0.05 * np.exp(-((x - 0.3) / 0.08) ** 2)
    return grey(v)


def cell_fluted(w, h):
    x, y = grid(w, h)
    p = 0.5 + 0.5 * np.cos(x * math.pi * 2 * 10)
    v = 0.84 + 0.12 * p - 0.1 * smooth(y)
    return grey(v)


def cell_painted_wood(w, h):
    x, y = grid(w, h)
    v = 0.92 - 0.06 * smooth(y) + 0.02 * np.sin(y * math.pi * 3 + x * 2)
    return grey(v)


def cell_eggshell(w, h):
    x, y = grid(w, h)
    return grey(0.95 - 0.05 * smooth(y))


def cell_beadboard(w, h):
    x, y = grid(w, h)
    g = np.abs(((x * 6) % 1.0) - 0.5) * 2
    v = 0.95 - 0.16 * (1 - smooth((g - 0.86) * -20 + 1)) - 0.04 * smooth(y)
    groove = 1 - smooth((1 - g) * 18)
    v = 0.95 - 0.18 * groove - 0.05 * smooth(y)
    return grey(v)


def cell_panel(w, h):
    x, y = grid(w, h)
    dx = np.minimum(x - 0.12, 0.88 - x)
    dy = np.minimum(y - 0.14, 0.86 - y)
    d = np.minimum(dx, dy)
    v = 0.95 - 0.04 * smooth(y)
    v = v - 0.14 * np.exp(-(d / 0.02) ** 2) + 0.05 * np.exp(-((d + 0.035) / 0.015) ** 2)
    return grey(v)


def cell_wood_grain(w, h):
    x, y = grid(w, h)
    lines = 0.5 + 0.5 * np.sin((x * 9 + 0.6 * np.sin(y * 5 + x * 3)) * math.pi)
    v = 0.86 + 0.07 * lines - 0.06 * smooth(y)
    return grey(v)


def cell_wood_turned(w, h):
    x, y = grid(w, h)
    rings = 0.5 + 0.5 * np.sin(y * math.pi * 14)
    v = 0.84 + 0.07 * rings + 0.05 * np.exp(-((x - 0.3) / 0.1) ** 2)
    return grey(v)


def cell_wood_planks(w, h):
    x, y = grid(w, h)
    board = (y * 4) % 1.0
    seam = 1 - smooth(np.minimum(board, 1 - board) * 30)
    lines = 0.5 + 0.5 * np.sin((x * 6 + y * 3 + 0.3 * np.sin(x * 9)) * math.pi)
    shade = np.array([0.9, 0.84, 0.88, 0.82])[np.clip((y * 4).astype(int), 0, 3)]
    v = shade + 0.04 * lines - 0.14 * seam
    return grey(v)


def cell_frame_wood(w, h):
    x, y = grid(w, h)
    lines = 0.5 + 0.5 * np.sin((x * 14 + 0.4 * np.sin(y * 6)) * math.pi)
    v = 0.84 + 0.06 * lines + 0.08 * np.exp(-((y - 0.3) / 0.12) ** 2)
    return grey(v)


def coloured(w, h, top, bottom, hl=None, hlx=0.3):
    x, y = grid(w, h)
    a, b = np.array(hexc(top), np.float32), np.array(hexc(bottom), np.float32)
    t = smooth(y)[..., None]
    arr = a + (b - a) * t
    if hl:
        c = np.array(hexc(hl), np.float32)
        k = np.exp(-((x - hlx) / 0.09) ** 2)[..., None] * 0.55
        arr = arr + (c - arr) * k
    return arr


def cell_brass(w, h):
    return coloured(w, h, "#f2cf7c", "#a77a3a", "#fff1c2")


def cell_iron(w, h):
    return coloured(w, h, "#5a5552", "#36322f", "#8a8480")


def cell_terracotta(w, h):
    arr = coloured(w, h, "#d98a5f", "#a85a3c", "#f0b48d")
    x, y = grid(w, h)
    band = np.exp(-((y - 0.16) / 0.05) ** 2)[..., None]
    return arr * (1 - 0.18 * band)


def cell_basket(w, h):
    x, y = grid(w, h)
    over = np.sin(x * math.pi * 12) * np.sin(y * math.pi * 10)
    a = np.array(hexc("#e4c08a"), np.float32)
    b = np.array(hexc("#b98a50"), np.float32)
    t = (0.5 + 0.5 * over)[..., None]
    return (a * t + b * (1 - t)) * (1 - 0.12 * smooth(y))[..., None]


def leaf_pillow(top, mid, low, scallop=True):
    def f(w, h):
        x, y = grid(w, h)
        a, b, c = (np.array(hexc(k), np.float32) for k in (top, mid, low))
        t = smooth(y)[..., None]
        arr = np.where(t < 0.5, a + (b - a) * (t * 2), b + (c - b) * (t * 2 - 1))
        if scallop:
            # soft scalloped "leaf cluster" bands, organised, no individual leaves
            s = 0.5 + 0.5 * np.cos((x * 3 + 0.5 * np.floor(y * 3)) * math.pi * 2)
            band = (y * 3) % 1.0
            edge = np.exp(-((band - (0.85 - 0.08 * s)) / 0.09) ** 2)[..., None]
            arr = arr * (1 - 0.06 * edge)
        return arr
    return f


def cell_paddle_leaf(w, h):
    x, y = grid(w, h)
    arr = coloured(w, h, "#86b862", "#3f7a45")
    vein = np.exp(-((x - 0.5) / 0.025) ** 2)[..., None]
    side = np.exp(-((np.abs(x - 0.5) - (y * 0.5) % 0.25 * 1.2) / 0.02) ** 2)[..., None] * 0.4
    light = np.array(hexc("#b9dc8a"), np.float32)
    return arr * (1 - 0.3 * vein - 0.0 * side) + light * 0.3 * vein + light * 0.1 * side


def cell_snake_blade(w, h):
    x, y = grid(w, h)
    arr = coloured(w, h, "#7fa865", "#3d6b45")
    bands = 0.5 + 0.5 * np.sin((y * 9 + 0.4 * np.sin(x * 6)) * math.pi)
    rim = np.exp(-((np.minimum(x, 1 - x)) / 0.06) ** 2)
    arr = arr * (1 - 0.12 * bands)[..., None]
    return arr + (np.array(hexc("#d9d88a"), np.float32) - arr) * (0.7 * rim)[..., None]


def cell_succulent(w, h):
    return coloured(w, h, "#b6d3b0", "#6d9a80", "#e0efd8")


def cell_flower_dome(w, h):
    arr = leaf_pillow("#9cc471", "#6a9d55", "#4b7a45")(w, h)
    img = to_img(arr).resize((w * SS, h * SS))
    d = ImageDraw.Draw(img)
    rnd = random.Random(7)
    cols = ["#f4a6a0", "#fbe3c2", "#f7c95c", "#e88fae", "#ffffff"]
    for _ in range(26):
        cx, cy = rnd.uniform(0, w) * SS, rnd.uniform(0, h * 0.8) * SS
        r = rnd.uniform(5, 9) * SS
        c = hexc(rnd.choice(cols))
        for k in range(5):
            a = k / 5 * math.tau
            px, py = cx + math.cos(a) * r * 0.55, cy + math.sin(a) * r * 0.55
            d.ellipse([px - r * 0.45, py - r * 0.45, px + r * 0.45, py + r * 0.45], fill=c)
        d.ellipse([cx - r * 0.3, cy - r * 0.3, cx + r * 0.3, cy + r * 0.3], fill=hexc("#f6d36a"))
    return np.asarray(img.resize((w, h), Image.LANCZOS), np.float32)


def cell_soil(w, h):
    x, y = grid(w, h)
    arr = coloured(w, h, "#7a5a40", "#5e4330")
    moss = 0.5 + 0.5 * np.sin(x * 7) * np.sin(y * 5 + 1)
    return arr * (1 - 0.08 * moss)[..., None] + np.array(hexc("#7e9a5a"), np.float32) * 0.12 * moss[..., None]


def cell_shade_inner(w, h):
    return coloured(w, h, "#fff4d6", "#ffd99a")


def cell_candle(w, h):
    return coloured(w, h, "#fbf4e6", "#e8dcc4", "#ffffff")


def cell_book_spines(w, h):
    img = Image.new("RGB", (w * SS, h * SS))
    d = ImageDraw.Draw(img)
    cols = ["#b5584a", "#4f7d8a", "#d6a24a", "#6d8f5e", "#8a6aa0", "#e7d9bf", "#c97a5a", "#3f5f7f"]
    x = 0
    i = 0
    while x < w * SS:
        bw = (10 + (i * 7) % 9) * SS
        c = hexc(cols[i % len(cols)])
        d.rectangle([x, 0, x + bw, h * SS], fill=c)
        for yy in (0.18, 0.78):
            d.rectangle([x + 2 * SS, int(h * SS * yy), x + bw - 2 * SS, int(h * SS * yy) + 3 * SS], fill=lerp(c, (255, 240, 200), 0.45))
        x += bw
        i += 1
    arr = np.asarray(img.resize((w, h), Image.LANCZOS), np.float32)
    x2, y2 = grid(w, h)
    return arr * (1 - 0.12 * smooth(y2))[..., None]


def cell_fruit(w, h):
    img = Image.new("RGB", (w * SS, h * SS), hexc("#e48a3c"))
    d = ImageDraw.Draw(img)
    for i, c in enumerate(["#e48a3c", "#d9534a", "#f2c94c", "#9cc15a"]):
        d.rectangle([i * w * SS // 4, 0, (i + 1) * w * SS // 4, h * SS], fill=hexc(c))
    arr = np.asarray(img.resize((w, h), Image.LANCZOS), np.float32)
    x, y = grid(w, h)
    hl = np.exp(-(((x * 4) % 1 - 0.35) / 0.12) ** 2 - ((y - 0.3) / 0.15) ** 2)
    return arr * (1 - 0.2 * smooth(y))[..., None] + 70 * hl[..., None]


def cell_mirror(w, h):
    x, y = grid(w, h)
    arr = coloured(w, h, "#e7f0f2", "#a9c3cc")
    streak = np.exp(-(((x + y * 0.6) - 0.55) / 0.05) ** 2) + 0.6 * np.exp(-(((x + y * 0.6) - 0.72) / 0.025) ** 2)
    return arr + 60 * streak[..., None]


def cell_paper(w, h):
    return coloured(w, h, "#fbf6ea", "#ece2cc")


def cell_rope(w, h):
    x, y = grid(w, h)
    tw = 0.5 + 0.5 * np.sin((x * 3 + y * 10) * math.pi)
    a = np.array(hexc("#efe0c2"), np.float32)
    b = np.array(hexc("#c9b088"), np.float32)
    return a * tw[..., None] + b * (1 - tw[..., None])


def cell_bulb(w, h):
    return coloured(w, h, "#fffaf0", "#ffe7b0")


def cell_clock_face(w, h):
    img = Image.new("RGB", (w * SS, h * SS), (250, 247, 240))
    d = ImageDraw.Draw(img)
    cx, cy, r = w * SS / 2, h * SS / 2, w * SS * 0.42
    for k in range(12):
        a = k / 12 * math.tau
        rr = 5 * SS if k % 3 == 0 else 3 * SS
        px, py = cx + math.sin(a) * r * 0.85, cy - math.cos(a) * r * 0.85
        d.ellipse([px - rr, py - rr, px + rr, py + rr], fill=(120, 116, 112))
    for ang, ln, wd in ((math.radians(300), 0.5, 4), (math.radians(60), 0.72, 3)):
        d.line([cx, cy, cx + math.sin(ang) * r * ln, cy - math.cos(ang) * r * ln], fill=(90, 86, 82), width=wd * SS)
    d.ellipse([cx - 4 * SS, cy - 4 * SS, cx + 4 * SS, cy + 4 * SS], fill=(90, 86, 82))
    return np.asarray(img.resize((w, h), Image.LANCZOS), np.float32)


def cell_skin(w, h):
    return coloured(w, h, "#f2c9a6", "#d9a47e")


CELLS = [
    # name, painter, family, tint channel (None = fixed colour)
    ("fabric_linen", cell_linen, "fabric", "R"),
    ("fabric_pleats", cell_pleats, "fabric", "R"),
    ("fabric_stripe", cell_stripe, "fabric", "R"),
    ("fabric_gingham", cell_gingham, "fabric", "R"),
    ("fabric_dots", cell_dots, "fabric", "R"),
    ("fabric_knit", cell_knit, "fabric", "R"),
    ("fabric_patchwork", cell_patchwork, "fabric", "R"),
    ("fabric_velvet", cell_velvet, "fabric", "R"),
    ("ceramic_glaze", cell_glaze, "ceramic", "G"),
    ("ceramic_band", cell_glaze_band, "ceramic", "G"),
    ("ceramic_fluted", cell_fluted, "ceramic", "G"),
    ("paint_wood", cell_painted_wood, "paint", "A"),
    ("paint_eggshell", cell_eggshell, "paint", "A"),
    ("paint_beadboard", cell_beadboard, "paint", "A"),
    ("paint_panel", cell_panel, "paint", "A"),
    ("clock_face", cell_clock_face, "fixed", None),
    ("wood_grain", cell_wood_grain, "wood", "B"),
    ("wood_turned", cell_wood_turned, "wood", "B"),
    ("wood_planks", cell_wood_planks, "wood", "B"),
    ("wood_frame", cell_frame_wood, "wood", "B"),
    ("brass", cell_brass, "fixed", None),
    ("iron", cell_iron, "fixed", None),
    ("terracotta", cell_terracotta, "fixed", None),
    ("basket", cell_basket, "fixed", None),
    ("leaf_green", leaf_pillow("#9fcd73", "#68a050", "#3f7443"), "foliage", None),
    ("leaf_sage", leaf_pillow("#b7cf98", "#83a777", "#557a5c"), "foliage", None),
    ("leaf_deep", leaf_pillow("#7fb46a", "#4d8650", "#2f5f40"), "foliage", None),
    ("leaf_paddle", cell_paddle_leaf, "foliage", None),
    ("leaf_blade", cell_snake_blade, "foliage", None),
    ("leaf_succulent", cell_succulent, "foliage", None),
    ("flower_dome", cell_flower_dome, "foliage", None),
    ("soil", cell_soil, "fixed", None),
    ("shade_inner", cell_shade_inner, "glow", None),
    ("candle", cell_candle, "fixed", None),
    ("book_spines", cell_book_spines, "fixed", None),
    ("fruit", cell_fruit, "fixed", None),
    ("mirror", cell_mirror, "fixed", None),
    ("paper", cell_paper, "fixed", None),
    ("rope", cell_rope, "fixed", None),
    ("bulb", cell_bulb, "glow", None),
    ("petal_pink", lambda w, h: coloured(w, h, "#ffc2c6", "#e8848f"), "foliage", None),
    ("petal_cream", lambda w, h: coloured(w, h, "#fffaf0", "#efdcc0"), "foliage", None),
    ("petal_yellow", lambda w, h: coloured(w, h, "#ffe58a", "#f0b840"), "foliage", None),
]


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    layout = {"atlas": "decor_atlas.png", "size": 1024, "cells": {}}
    atlas = Image.new("RGB", (1024, 1024), (128, 128, 128))
    for i, (name, fn, fam, ch) in enumerate(CELLS):
        cx, cy = (i % GRID) * CELL, (i // GRID) * CELL
        arr = fn(CELL, CELL)
        img = to_img(arr) if isinstance(arr, np.ndarray) else arr
        img = img.filter(ImageFilter.GaussianBlur(0.6))
        atlas.paste(img, (cx, cy))
        pad = 6
        layout["cells"][name] = {
            "index": i, "px": [cx, cy, CELL, CELL], "family": fam, "tint": ch,
            "uv": [(cx + pad) / 1024, (cy + pad) / 1024, (cx + CELL - pad) / 1024, (cy + CELL - pad) / 1024],
        }
    atlas.save(os.path.join(out, "decor_atlas.png"))

    with open(os.path.join(out, "layout.json"), "w") as f:
        json.dump(layout, f, indent=1)
    print("painted", len(CELLS), "cells")


if __name__ == "__main__":
    main()
