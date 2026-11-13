"""Turns the user's recolourable SVG prints into one runtime-recolourable mask atlas (art candidate).

    python tools/blender/art_candidates/home_decor/art_masks.py <rev_dir>

The user's direction (2026-11-12): framed artwork in homes and elsewhere uses ONLY
the SVG files (16 as of 2026-11-12) in build/art_candidates/home_decor/sources/svg/ (Unsplash).

For each SVG:
  1. collect every colour literal (fills, strokes, gradient stops, CSS classes);
  2. group them into at most four colour slots (deterministic k-means), sorted
     light -> dark; slot 0 (the lightest) is the "paper";
  3. for slots 1-3 write a variant SVG with that slot's colours white and every
     other colour black, and rasterise it with Godot's own SVG loader (ThorVG,
     the renderer the game uses);
  4. pack the three coverage images into R, G and B. Paper = 1 - R - G - B.
     Because each variant keeps the original layering, antialiasing and
     gradients, recolouring is exact for flat fills, and a gradient between two
     slots becomes a gradient between their new colours.

Every print is cover-cropped to a 3:4 cell (192 x 256). Landscape frames use its
centre 4:3 strip, round frames and hoops its centre square (see layout).

Outputs in <rev_dir>/textures/:
  art_masks.png        1024 x 1024 RGB slot masks (5 x 4 cells, 16 used)
  art_original.png     the same prints in their own colours (reference only)
  art_layout.json      cell rects, UV rects for 3:4, 4:3 and round crops, the
                       slot colours of the original, and per-scheme colourways
Colourways: the scheme palette (paper from trim, accent, fabric, ceramic,
wall_lower, floor and a deep ink) is matched to the print's slots by lightness
rank, so each print keeps its light/dark structure in every home.
"""
import json
import math
import os
import re
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
SRC = os.path.join(ROOT, "build", "art_candidates", "home_decor", "sources", "svg")
sys.path.insert(0, os.path.join(ROOT, "tools"))
from godot_toolchain import default_godot
GODOT = default_godot()
CW, CH = 192, 256
COLS, ROWS = 5, 4
HEX = re.compile(r"#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})(?![0-9a-fA-F])")

RASTER_GD = '''extends SceneTree
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	for f in DirAccess.get_files_at(a[0]):
		if not f.ends_with(".svg"):
			continue
		var text := FileAccess.get_file_as_string(a[0].path_join(f))
		var probe := Image.new()
		probe.load_svg_from_string(text, 1.0)
		var sc := float(a[2]) / minf(probe.get_width(), probe.get_height())
		var img := Image.new()
		img.load_svg_from_string(text, sc)
		img.save_png(a[1].path_join(f.get_basename() + ".png"))
	quit()
'''


RGBFN = re.compile(r"rgb\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)")
NAMED = re.compile(r'((?:fill|stroke|stop-color)\s*[=:]\s*"?)(white|black)', re.I)


def normalise(text):
    """rgb(...) and the named colours white/black become hex literals, so every colour can be slotted."""
    # some exporters label embedded PNGs "data:img/png"; Godot's ThorVG only reads the standard "data:image/png"
    text = text.replace("data:img/", "data:image/")
    text = RGBFN.sub(lambda m: "#%02x%02x%02x" % tuple(int(m.group(i)) for i in (1, 2, 3)), text)
    return NAMED.sub(lambda m: m.group(1) + ("#ffffff" if m.group(2).lower() == "white" else "#000000"), text)


def h2rgb(h):
    h = h.lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32)


def rgb2h(c):
    return "#%02x%02x%02x" % tuple(int(round(max(0, min(255, x)))) for x in c)


def lum(c):
    c = np.asarray(c, np.float32) / 255
    return float(0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2])


def kmeans(cols, k):
    cols = sorted(cols, key=lambda c: lum(h2rgb(c)))
    pts = np.array([h2rgb(c) for c in cols])
    k = min(k, len(cols))
    cent = np.array([pts[int(round(i * (len(pts) - 1) / max(1, k - 1)))] for i in range(k)])
    for _ in range(30):
        d = ((pts[:, None, :] - cent[None, :, :]) ** 2).sum(-1)
        lab = d.argmin(1)
        new = np.array([pts[lab == i].mean(0) if (lab == i).any() else cent[i] for i in range(k)])
        if np.allclose(new, cent):
            break
        cent = new
    order = sorted(range(k), key=lambda i: -lum(cent[i]))  # light -> dark
    remap = {o: n for n, o in enumerate(order)}
    return {c.lower(): remap[int(l)] for c, l in zip(cols, lab)}, [cent[o] for o in order]


def variant(text, slot_of, slot):
    def sub(m):
        c = ("#" + m.group(1)).lower()
        if len(c) == 4:
            c = "#" + "".join(ch * 2 for ch in c[1:])
        return "#ffffff" if slot_of.get(c) == slot else "#000000"
    return HEX.sub(sub, text)


def cover(img, w, h):
    iw, ih = img.size
    s = max(w / iw, h / ih)
    img = img.resize((max(w, round(iw * s)), max(h, round(ih * s))), Image.LANCZOS)
    x0, y0 = (img.width - w) // 2, (img.height - h) // 2
    return img.crop((x0, y0, x0 + w, y0 + h))


def raster(svg_dir, out_dir, short_side):
    gd = os.path.join(svg_dir, "_raster.gd")
    with open(gd, "w") as f:
        f.write(RASTER_GD)
    subprocess.run([GODOT, "--headless", "--script", gd, "--", svg_dir, out_dir, str(short_side)], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def scheme_palette(s):
    """Candidate colours of a scheme for prints, light to dark-ish."""
    trim, acc, fab, cer, low, floor = (h2rgb(s[k]) for k in ("trim", "accent", "fabric", "ceramic", "wall_lower", "floor"))
    paper = trim * 0.82 + acc * 0.18
    ink = floor * 0.42 + cer * 0.12
    return [("paper", paper), ("accent", acc), ("fabric", fab), ("ceramic", cer), ("wall_lower", low), ("floor", floor), ("ink", ink)]


# Art-only colourways, not tied to a room's scheme (user's request, 2026-11-12: one bolder, neon/jewel palette).
# Paper first, then the colours a print's slots may take.
ART_PALETTES = {
    "jewel_pop": [("paper", "#fbf3e4"), ("emerald", "#0f9d7a"), ("sapphire", "#2f4fd8"), ("ruby", "#d6245a"),
                  ("amethyst", "#8e3fd6"), ("gold", "#f6b81c"), ("neon_pink", "#ff4fa3"), ("cyan", "#19c9e6"),
                  ("ink", "#1d1640")],
}


def colourway(slot_cols, s, pal=None):
    """Pick distinct scheme colours for the print's slots: paper stays paper; the rest follow the print's
    lightness order (light -> dark) while keeping every pair of slots clearly apart in lightness."""
    import itertools
    pal = pal or scheme_palette(s)
    n = len(slot_cols)
    target = [lum(c) for c in slot_cols]
    best, best_cost = None, 1e9
    for combo in itertools.permutations(range(1, len(pal)), n - 1):
        cols = [pal[0][1]] + [pal[i][1] for i in combo]
        ls = [lum(c) for c in cols]
        cost = sum((ls[i] - target[i]) ** 2 for i in range(1, n))
        for i in range(n):
            for j in range(i + 1, n):
                gap = abs(ls[i] - ls[j])
                want = min(0.12, abs(target[i] - target[j]))
                if gap < want:
                    cost += (want - gap) * 4
        if cost < best_cost:
            best, best_cost = cols, cost
    return [rgb2h(c) for c in best] + [None] * (4 - n)


def main():
    rev = sys.argv[1]
    tex = os.path.join(rev, "textures")
    os.makedirs(tex, exist_ok=True)
    schemes = json.load(open(os.path.join(HERE, "schemes.json")))["schemes"]
    files = sorted(f for f in os.listdir(SRC) if f.endswith(".svg"))
    masks = Image.new("RGB", (1024, 1024), (0, 0, 0))
    orig = Image.new("RGB", (1024, 1024), (240, 232, 214))
    layout = {"masks": "art_masks.png", "original": "art_original.png", "size": 1024, "cell": [CW, CH],
              "about": "Paper = 1 - R - G - B. colour = paper*slot0 + R*slot1 + G*slot2 + B*slot3.", "prints": {}}
    with tempfile.TemporaryDirectory() as tmp:
        vdir, rdir = os.path.join(tmp, "v"), os.path.join(tmp, "r")
        os.makedirs(vdir), os.makedirs(rdir)
        meta = {}
        for f in files:
            name = f.split("-unsplash")[0]
            text = normalise(open(os.path.join(SRC, f), encoding="utf-8").read())
            cols = sorted({("#" + m).lower() if len(m) == 6 else "#" + "".join(ch * 2 for ch in m.lower()) for m in HEX.findall(text)})
            slot_of, cents = kmeans(cols, 4) if cols else ({}, [])
            meta[name] = (text, slot_of, cents)
            with open(os.path.join(vdir, name + "__orig.svg"), "w", encoding="utf-8") as o:
                o.write(text)
            # every colour white: anything left dark is an unfilled (default black) shape
            with open(os.path.join(vdir, name + "__all.svg"), "w", encoding="utf-8") as o:
                o.write(HEX.sub("#ffffff", text))
            for k in (1, 2, 3):
                with open(os.path.join(vdir, "%s__s%d.svg" % (name, k)), "w", encoding="utf-8") as o:
                    o.write(variant(text, slot_of, k))
        raster(vdir, rdir, 720)
        for i, (name, (text, slot_of, cents)) in enumerate(meta.items()):
            cx, cy = (i % COLS) * CW, (i // COLS) * CH

            def load(tag):
                p = os.path.join(rdir, "%s__%s.png" % (name, tag))
                im = Image.open(p).convert("RGBA")
                bg = Image.new("RGBA", im.size, (0, 0, 0, 255))
                return cover(Image.alpha_composite(bg, im).convert("RGB"), CW, CH)
            allw = np.asarray(load("all"), np.float32)[..., 0]
            unfilled = float((allw < 128).mean())
            if "<image" in text:
                # Raster artwork embedded in the SVG (fills can't be swapped): cluster the rendered pixels into
                # four slots, light -> dark, with soft weights so edges stay antialiased.
                px = np.asarray(load("orig"), np.float32).reshape(-1, 3)
                rng = np.random.default_rng(0)
                sample = px[rng.choice(len(px), min(6000, len(px)), replace=False)]
                order = np.argsort(sample @ np.array([0.2126, 0.7152, 0.0722]))
                cent = sample[order[np.linspace(0, len(order) - 1, 4).astype(int)]]
                for _ in range(30):
                    lab = ((sample[:, None] - cent[None]) ** 2).sum(-1).argmin(1)
                    cent = np.array([sample[lab == i].mean(0) if (lab == i).any() else cent[i] for i in range(4)])
                cent = cent[np.argsort([-lum(c) for c in cent])]
                d = np.sqrt(((px[:, None] - cent[None]) ** 2).sum(-1))
                wgt = np.exp(-(d - d.min(1, keepdims=True)) / 12.0)
                wgt /= wgt.sum(1, keepdims=True)
                chans = [(wgt[:, k] * 255).reshape(CH, CW) for k in (1, 2, 3)]
                cents = list(cent)
                slot_of = {"raster": 0}
                meta[name] = (text, slot_of, cents)
            else:
                chans = [np.asarray(load("s%d" % k), np.float32)[..., 0] for k in (1, 2, 3)]
            tot = sum(chans)
            over = np.maximum(tot - 255, 0)
            if over.max() > 0:  # keep R+G+B <= 1 (opacity overlaps)
                f = np.where(tot > 255, 255 / np.maximum(tot, 1), 1)
                chans = [c * f for c in chans]
            masks.paste(Image.fromarray(np.stack(chans, -1).clip(0, 255).astype(np.uint8)), (cx, cy))
            orig.paste(load("orig"), (cx, cy))
            pad = 2
            u0, v0, u1, v1 = (cx + pad) / 1024, (cy + pad) / 1024, (cx + CW - pad) / 1024, (cy + CH - pad) / 1024
            hh = (CW * 3 / 4) / 1024  # centre 4:3 strip of the 3:4 cell
            mid = (cy + CH / 2) / 1024
            sq = CW / 1024
            layout["prints"][name] = {
                "source": [f for f in files if f.startswith(name)][0],
                "px": [cx, cy, CW, CH],
                "uv_portrait": [u0, v0, u1, v1],
                "uv_landscape": [u0, mid - hh / 2, u1, mid + hh / 2],
                "uv_square": [u0, mid - sq / 2 + pad / 1024, u1, mid + sq / 2 - pad / 1024],
                "slots_original": [rgb2h(c) for c in cents] + [None] * (4 - len(cents)),
                "slot_count": len(cents),
                "source_colours": len(slot_of),
                "raster_embedded": "<image" in text,
                "unfilled_fraction": round(unfilled, 4),
                "colourways": {**{k: colourway(cents, s) for k, s in schemes.items()},
                               **{k: colourway(cents, None, [(n, h2rgb(c)) for n, c in v]) for k, v in ART_PALETTES.items()}},
            }
    masks.save(os.path.join(tex, "art_masks.png"))
    # preview-only: the whole atlas recoloured per scheme, for the Blender candidate renders
    rec = os.path.join(rev, "previews", "recoloured")
    os.makedirs(rec, exist_ok=True)
    m = np.asarray(masks, np.float32) / 255
    for sk in list(schemes) + list(ART_PALETTES):
        out = np.zeros((1024, 1024, 3), np.float32) + 128
        for p in layout["prints"].values():
            x, y, w, h = p["px"]
            cell = m[y:y + h, x:x + w]
            cols = [h2rgb(c) if c else np.zeros(3, np.float32) for c in p["colourways"][sk]]
            paper = np.clip(1 - cell.sum(-1, keepdims=True), 0, 1)
            out[y:y + h, x:x + w] = paper * cols[0] + cell[..., 0:1] * cols[1] + cell[..., 1:2] * cols[2] + cell[..., 2:3] * cols[3]
        Image.fromarray(out.clip(0, 255).astype(np.uint8)).save(os.path.join(rec, sk + ".png"))
    orig.save(os.path.join(tex, "art_original.png"))
    with open(os.path.join(tex, "art_layout.json"), "w") as f:
        json.dump(layout, f, indent=1)
    for n, p in layout["prints"].items():
        print("PRINT", n, "colours", p["source_colours"], "slots", p["slot_count"], "unfilled", p["unfilled_fraction"])


if __name__ == "__main__":
    main()
