"""Builds the game's family of clean painted wood textures from the fence's grain (assets/textures/surfaces/planks_v.png).

    python tools/build_wood_textures.py
    godot --headless --path . --script res://tools/smooth_textures.gd -- --only=res://assets/textures/surfaces/wood_
    godot --headless --path . --import

The supplied fence wears planks_v: soft, low-contrast streaks with no speckle, which the user picked as the look for all
of the game's wood. Each variant re-cuts that grain into boards of its own width, every board a strip of the fence's
grain from its own place and height, a touch lighter or darker than its neighbours, with soft seams between boards (and,
on decks, soft butt joints across them). Every texture tiles both ways, stays grey (the game tints it: voxel_textures.gd
WOOD) and keeps planks_v's average brightness, so a variant swaps in without changing a material's colour.
Each is written with vertical boards (<name>_v.png) and turned a quarter for horizontal boards (<name>.png).
"""
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SURF = os.path.join(ROOT, "assets", "textures", "surfaces")
SIZE = 128

# name: boards per tile (2 world units), seam depth, board-to-board brightness spread, grain contrast, butt joints
VARIANTS = {
    # wall boards: shacks, kit walls, stalls, signs (and the kit's old "planks")
    "wood_board": dict(boards=[34, 30, 32, 32], seam=0.16, spread=0.035, grain=1.0, joints=0, seed=11),
    # decks, docks and bridges: narrower boards with an end joint here and there
    "wood_deck": dict(boards=[26, 25, 26, 25, 26], seam=0.21, spread=0.04, grain=1.0, joints=1, seed=23),
    # beams, posts, trim and frames: two wide boards, almost seamless (and the kit's old "wood_dark")
    "wood_beam": dict(boards=[66, 62], seam=0.07, spread=0.025, grain=0.9, joints=0, seed=37),
    # sea-weathered boards for dock shacks and piers: a little more streak and variety, still clean
    "wood_drift": dict(boards=[30, 34, 28, 36], seam=0.19, spread=0.055, grain=1.15, joints=0, seed=51),
}


def blur1d(a, sigma, axis):
    r = int(sigma * 3) + 1
    k = np.exp(-0.5 * (np.arange(-r, r + 1) / sigma) ** 2)
    k /= k.sum()
    out = np.zeros_like(a)
    for i, w in enumerate(k):
        out += w * np.roll(a, i - r, axis=axis)
    return out


def build(src, boards, seam, spread, grain, joints, seed):
    rng = np.random.default_rng(seed)
    assert sum(boards) == SIZE
    mean = src.mean()
    out = np.zeros((SIZE, SIZE))
    shade = np.ones((SIZE, SIZE))
    x = 0
    for w in boards:
        # a strip of the fence's grain from its own column and height, stretched or squeezed to the board's width
        sx = rng.integers(0, SIZE)
        cols = (sx + np.linspace(0, rng.uniform(0.75, 1.1) * w, w, endpoint=False).astype(int)) % SIZE
        strip = np.roll(src[:, cols], rng.integers(0, SIZE), axis=0)
        if rng.random() < 0.5:
            strip = strip[::-1]
        strip = mean + (strip - strip.mean()) * grain
        out[:, x:x + w] = strip * (1.0 + rng.uniform(-spread, spread))
        # soft seam on the board's left edge (the tile's wrap closes the last one)
        for d in range(4):
            fall = seam * np.exp(-0.9 * d * d)
            shade[:, (x + d) % SIZE] -= fall * 0.65
            shade[:, (x - 1 - d) % SIZE] -= fall * 0.35
        # a butt joint across the board, at its own height
        for _ in range(joints):
            y = rng.integers(0, SIZE)
            for d in range(3):
                fall = seam * 0.8 * np.exp(-0.9 * d * d)
                shade[(y + d) % SIZE, x:x + w] -= fall * 0.6
                shade[(y - 1 - d) % SIZE, x:x + w] -= fall * 0.4
        x += w
    out = out * shade
    # soften once more so nothing reads as texels, then hold the fence's average brightness
    out = blur1d(blur1d(out, 0.8, 1), 1.2, 0)
    out = out - out.mean() + mean
    return np.clip(out, 0, 255)


def main():
    img = Image.open(os.path.join(SURF, "planks_v.png")).convert("RGBA")
    a = np.asarray(img).astype(float)
    src = a[:, :, :3].mean(axis=2)
    # the source's one bright fleck (and any like it) would repeat as dots on every board: hold each texel near its
    # neighbourhood
    soft = blur1d(blur1d(src, 2.0, 0), 2.0, 1)
    src = soft + np.clip(src - soft, -6.0, 6.0)
    for name, v in VARIANTS.items():
        g = build(src, **v).astype(np.uint8)
        rgba = np.dstack([g, g, g, np.full_like(g, 255)])
        vert = Image.fromarray(rgba, "RGBA")
        vert.save(os.path.join(SURF, name + "_v.png"))
        vert.transpose(Image.ROTATE_90).save(os.path.join(SURF, name + ".png"))
        print(name, "mean %.1f std %.1f" % (g.mean(), g.std()))
    return 0


if __name__ == "__main__":
    sys.exit(main())
