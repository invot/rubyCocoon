"""Paints clean, seamless wall finishes into assets/textures/surfaces/: plaster, stone, stone_dark and brick.

The older versions were smoothed pack textures that read as blotchy grey mottling on the buildings (the arena's
limestone, the stucco fronts). These are painted instead: even blocks with softly rounded edges, a lit top edge and a
shaded foot, quiet mortar and a whisper of broad colour variation, never grain, speckle or dark cracks (AGENTS.md, Art
and animation consistency). They are greyscale, tinted by each wall's colour, and keep the old files' average
brightness so every building keeps its colour. One repeat covers 2 world units (voxel_textures.gd PSX_SPAN).
Run from the project root:
  python tools/build_wall_textures.py
  godot --headless --path . --script res://tools/smooth_textures.gd -- --only=res://assets/textures/surfaces/
  godot --headless --path . --import
"""
import os
import numpy as np
from PIL import Image

DST = 'assets/textures/surfaces'
SIZE = 256


def periodic_noise(rng, size, low, high, aniso=(1.0, 1.0)):
    """Seamless noise keeping only spatial frequencies between low and high cycles per image."""
    white = rng.standard_normal((size, size))
    f = np.fft.fft2(white)
    fy = np.fft.fftfreq(size)[:, None] * size / aniso[1]
    fx = np.fft.fftfreq(size)[None, :] * size / aniso[0]
    r = np.sqrt(fx * fx + fy * fy)
    band = np.exp(-((r / high) ** 2)) * (1.0 - np.exp(-((r / max(low, 0.01)) ** 2)))
    out = np.real(np.fft.ifft2(f * band))
    out -= out.mean()
    return out / (np.abs(out).max() + 1e-9)


def blocks(rng, rows, cols, mortar, radius, shade, mortar_level, jitter, stagger=0.5, wide=None):
    """Running-bond blocks: `rows` courses of `cols` blocks (both whole numbers, so the image tiles), each softly
    rounded, lit along its top and shaded along its foot. Returns values around 1 (block) and mortar_level."""
    y, x = (np.mgrid[0:SIZE, 0:SIZE] + 0.5) / SIZE
    row_h = 1.0 / rows
    row = np.floor(y * rows).astype(int)
    v_in = y * rows - row  # 0 top .. 1 foot of the course
    col_w = 1.0 / cols
    shift = (row % 2) * stagger * col_w
    if wide is not None:
        # some courses split differently, so the stone doesn't read as a grid
        shift = shift + (np.take(wide, row % len(wide)) * col_w)
    u = (x + shift) % 1.0
    col = np.floor(u * cols).astype(int)
    h_in = u * cols - col
    # distance (in texture units) from the block's edges, as a rounded box
    px = (np.minimum(h_in, 1.0 - h_in)) * col_w
    py = (np.minimum(v_in, 1.0 - v_in)) * row_h
    half = mortar / 2.0
    r = radius
    qx = r - (px - half)
    qy = r - (py - half)
    inside = np.minimum(px, py) - half  # plain distance into the block
    corner = r - np.sqrt(np.maximum(qx, 0) ** 2 + np.maximum(qy, 0) ** 2)
    d = np.where((qx > 0) & (qy > 0), corner, inside)
    # soft edge, a few pixels wide, so the mortar is never a hard line
    edge = 1.5 / SIZE
    cover = np.clip(d / edge + 0.5, 0.0, 1.0)
    cover = cover * cover * (3 - 2 * cover)
    # each block a touch lighter or darker, a gentle top-lit gradient, a lit top lip and shaded foot
    ids = (row * 131 + col * 17) % 997
    tone = 1.0 + jitter * (np.sin(ids * 12.9898) * 0.5 + np.cos(ids * 4.1414) * 0.5)
    lip = np.clip(1.0 - (py - half) / (row_h * 0.22), 0.0, 1.0) * (v_in < 0.5)
    foot = np.clip(1.0 - (py - half) / (row_h * 0.30), 0.0, 1.0) * (v_in >= 0.5)
    block = tone * (1.0 + shade * (0.5 - v_in) * 0.35 + shade * 0.6 * lip ** 2 - shade * foot ** 2)
    return block * cover + mortar_level * (1.0 - cover)


def to_image(v, mean):
    """Greyscale values scaled to an average of `mean`, as RGBA."""
    v = v * (mean / v.mean())
    g = (np.clip(v, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)
    return Image.fromarray(np.dstack([g, g, g, np.full_like(g, 255)]), 'RGBA')


def plaster(rng):
    v = 1.0 + 0.035 * periodic_noise(rng, SIZE, 0.5, 2.5) + 0.012 * periodic_noise(rng, SIZE, 2.0, 6.0, (1.0, 0.5))
    return to_image(v, 0.858)


def stone(rng):
    # four courses of cut limestone per repeat (half a world unit each), two or three blocks a course
    v = blocks(rng, rows=4, cols=2, mortar=0.010, radius=0.018, shade=0.10, mortar_level=0.80, jitter=0.035,
        wide=[0.0, 0.5, 0.25, 0.75])
    v = v * (1.0 + 0.02 * periodic_noise(rng, SIZE, 0.5, 3.0))
    return to_image(v, 0.825)


def stone_dark(rng):
    v = blocks(rng, rows=5, cols=3, mortar=0.012, radius=0.016, shade=0.12, mortar_level=0.76, jitter=0.05,
        wide=[0.0, 0.4, 0.15, 0.6, 0.3])
    v = v * (1.0 + 0.025 * periodic_noise(rng, SIZE, 0.5, 3.0))
    return to_image(v, 0.844)


def brick(rng):
    v = blocks(rng, rows=10, cols=4, mortar=0.012, radius=0.010, shade=0.10, mortar_level=0.84, jitter=0.04)
    v = v * (1.0 + 0.02 * periodic_noise(rng, SIZE, 0.5, 3.0))
    return to_image(v, 0.847)


def main():
    os.makedirs(DST, exist_ok=True)
    for i, (name, fn) in enumerate([('plaster', plaster), ('stone', stone), ('stone_dark', stone_dark), ('brick', brick)]):
        img = fn(np.random.default_rng(2000 + i))
        img.save(os.path.join(DST, name + '.png'))
        a = np.asarray(img)[..., 0] / 255.0
        print('%-10s mean %.3f  range %.3f-%.3f' % (name, a.mean(), a.min(), a.max()))


if __name__ == '__main__':
    main()
