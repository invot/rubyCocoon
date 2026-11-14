"""Paints the soft cloud sky that window glass reflects (scripts/gfx/window_glass.gdshader) into
assets/textures/surfaces/glass_sky.png: greyscale, seamless, broad pillowy clouds (white) on clear sky (black), with
no grain or speckle. The shader colours it, so it stays the same in every town.
Run from the project root:
  python tools/build_glass_texture.py
  godot --headless --path . --script res://tools/smooth_textures.gd -- --only=res://assets/textures/surfaces/glass_sky.png
  godot --headless --path . --import
"""
import os
import numpy as np
from PIL import Image

DST = 'assets/textures/surfaces/glass_sky.png'
SIZE = 256


def periodic_noise(rng, size, low, high, aniso=(1.0, 1.0)):
    white = rng.standard_normal((size, size))
    f = np.fft.fft2(white)
    fy = np.fft.fftfreq(size)[:, None] * size / aniso[1]
    fx = np.fft.fftfreq(size)[None, :] * size / aniso[0]
    r = np.sqrt(fx * fx + fy * fy)
    band = np.exp(-((r / high) ** 2)) * (1.0 - np.exp(-((r / max(low, 0.01)) ** 2)))
    out = np.real(np.fft.ifft2(f * band))
    out -= out.mean()
    return out / (np.abs(out).max() + 1e-9)


def main():
    rng = np.random.default_rng(3100)
    # wide, flat-bottomed cloud banks: stretched sideways, a little finer detail on their tops
    v = 0.7 * periodic_noise(rng, SIZE, 0.8, 3.5, (1.0, 0.55)) + 0.3 * periodic_noise(rng, SIZE, 2.0, 7.0, (1.0, 0.6))
    v = (v - v.min()) / (v.max() - v.min())
    c = np.clip((v - 0.45) / 0.3, 0.0, 1.0)
    c = c * c * (3 - 2 * c)
    g = (c * 255.0 + 0.5).astype(np.uint8)
    Image.fromarray(np.dstack([g, g, g, np.full_like(g, 255)]), 'RGBA').save(DST)
    print('glass_sky mean %.3f' % (c.mean()))


if __name__ == '__main__':
    main()
