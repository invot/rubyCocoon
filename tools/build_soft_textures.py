"""Paints the clean, seamless finishes for 3D surfaces that used to be bare flat colour, into assets/textures/surfaces/.

Each is nearly white (just under 1, so a surface keeps the colour it had as a flat colour), tinted by the meshes' own
colours, and soft:
gentle low-frequency variation, never grain, speckle or visible texels (AGENTS.md, Art and animation consistency).
They tile seamlessly because every pattern is built from whole periods of the image.
  soft     a smooth painted finish, for painted wood, plastic, plaster and anything without a material of its own
  fabric   a soft woven cloth, for clothes, cushions, beds and curtains
  brushed  soft brushed metal, for brass, tin, iron and machines
  satin    a faint satin sheen, for skin, beasts and smooth glossy things
Run from the project root:  python tools/build_soft_textures.py
then  godot --headless --path . --import
"""
import os
import numpy as np
from PIL import Image

DST = 'assets/textures/surfaces'
SIZE = 256


def periodic_noise(rng, size, low, high, aniso=(1.0, 1.0)):
    """Seamless noise keeping only spatial frequencies between low and high cycles per image (anisotropic by aniso)."""
    white = rng.standard_normal((size, size))
    f = np.fft.fft2(white)
    fy = np.fft.fftfreq(size)[:, None] * size / aniso[1]
    fx = np.fft.fftfreq(size)[None, :] * size / aniso[0]
    r = np.sqrt(fx * fx + fy * fy)
    band = np.exp(-((r / high) ** 2)) * (1.0 - np.exp(-((r / max(low, 0.01)) ** 2)))
    out = np.real(np.fft.ifft2(f * band))
    out -= out.mean()
    return out / (np.abs(out).max() + 1e-9)


def finish(v, amount):
    """Values around 0 scaled to +/- amount, peaking at white, as grey RGBA."""
    v = np.clip(1.0 - amount + v * amount, 0.0, 1.0)
    g = (v * 255.0 + 0.5).astype(np.uint8)
    return Image.fromarray(np.dstack([g, g, g, np.full_like(g, 255)]), 'RGBA')


def soft(rng):
    # broad, painterly mottling with a whisper of brushwork
    v = 0.75 * periodic_noise(rng, SIZE, 0.5, 3.0) + 0.25 * periodic_noise(rng, SIZE, 2.0, 7.0, (1.0, 0.45))
    return finish(v, 0.08)


def fabric(rng):
    y, x = np.mgrid[0:SIZE, 0:SIZE] / SIZE * 2.0 * np.pi
    threads = 48
    weave = 0.5 * (np.sin(x * threads) * np.sign(np.sin(y * threads / 2.0)) + np.sin(y * threads) * np.sign(np.cos(x * threads / 2.0)))
    v = 0.35 * weave + 0.65 * periodic_noise(rng, SIZE, 0.5, 4.0)
    return finish(v, 0.10)


def brushed(rng):
    streaks = periodic_noise(rng, SIZE, 1.0, 40.0, (1.0, 0.04))
    broad = periodic_noise(rng, SIZE, 0.5, 2.5)
    return finish(0.55 * streaks + 0.45 * broad, 0.09)


def satin(rng):
    return finish(periodic_noise(rng, SIZE, 0.5, 2.0), 0.045)


def main():
    os.makedirs(DST, exist_ok=True)
    for i, (name, fn) in enumerate([('soft', soft), ('fabric', fabric), ('brushed', brushed), ('satin', satin)]):
        img = fn(np.random.default_rng(1000 + i))
        img.save(os.path.join(DST, name + '.png'))
        a = np.asarray(img)[..., 0] / 255.0
        print('%-8s mean %.3f  range %.3f-%.3f' % (name, a.mean(), a.min(), a.max()))


if __name__ == '__main__':
    main()
