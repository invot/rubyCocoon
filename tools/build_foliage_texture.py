"""Paints the leaf texture the trees, bushes and grass tufts wear (scripts/gfx/foliage.gdshader): overlapping rounded
leaves, each a soft shape lit along its upper rim with a little shade under the leaf above it. Grey only (the plants
keep their own colours; the shader lightens and darkens them by it), seamless, clean and painted with no grain.

    python tools/build_foliage_texture.py
    godot --headless --path . --script res://tools/smooth_textures.gd
    godot --headless --path . --import

It writes assets/textures/surfaces/foliage.png at 128 px; smooth_textures.gd then enlarges it like the other surfaces.
"""
import os

import numpy as np
from PIL import Image

SIZE = 128
SUPER = 4
LEAVES = 150
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures", "surfaces", "foliage.png")


def main():
    rng = np.random.default_rng(4107)
    s = SIZE * SUPER
    ys, xs = np.mgrid[0:s, 0:s].astype(np.float32)
    tone = np.full((s, s), 0.36, np.float32)
    for _ in range(LEAVES):
        cx, cy = rng.uniform(0, s, 2)
        r = rng.uniform(8.5, 15.0) * SUPER
        squash = rng.uniform(0.72, 1.0)
        turn = rng.uniform(-0.9, 0.9)
        base = rng.uniform(0.42, 0.66)
        # wrapped offsets from the leaf's middle, turned and squashed into its own oval
        dx = (xs - cx + s / 2) % s - s / 2
        dy = (ys - cy + s / 2) % s - s / 2
        u = dx * np.cos(turn) + dy * np.sin(turn)
        v = (-dx * np.sin(turn) + dy * np.cos(turn)) / squash
        d = np.sqrt(u * u + v * v) / r
        # the shade it lays on the leaves under it, a little below
        dy2 = (ys - (cy + r * 0.28) + s / 2) % s - s / 2
        u2 = dx * np.cos(turn) + dy2 * np.sin(turn)
        v2 = (-dx * np.sin(turn) + dy2 * np.cos(turn)) / squash
        d2 = np.sqrt(u2 * u2 + v2 * v2) / r
        tone *= 1.0 - 0.2 * np.clip((1.12 - d2) / 0.3, 0.0, 1.0)
        # the leaf: lighter towards its upper rim, deeper at its foot, a soft edge
        inside = np.clip((1.0 - d) / 0.08, 0.0, 1.0)
        lit = base + 0.16 * np.clip(-v / r, -1.0, 1.0) * d + 0.05 * (1.0 - d)
        tone = tone * (1.0 - inside) + lit * inside
    img = Image.fromarray(np.uint8(np.clip(tone, 0.0, 1.0) * 255.0), "L").resize((SIZE, SIZE), Image.LANCZOS)
    arr = np.asarray(img, np.float32) / 255.0
    # centred on mid grey, so a plant keeps its colour on average
    arr = np.clip(0.5 + (arr - arr.mean()) * 1.25, 0.0, 1.0)
    Image.fromarray(np.uint8(arr * 255.0), "L").convert("RGB").save(OUT)
    print("wrote", os.path.normpath(OUT), "mean %.3f min %.3f max %.3f" % (arr.mean(), arr.min(), arr.max()))


if __name__ == "__main__":
    main()
