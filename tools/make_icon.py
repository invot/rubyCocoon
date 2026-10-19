"""Makes the app icon: renders the voxel Redcoon scene (tools/make_icon.gd) and cuts it into icon files.

  assets/icon/icon_background.png  432 x 432  Android adaptive icon background: sky, clouds, the valley and hills
  assets/icon/icon_foreground.png  432 x 432  Android adaptive icon foreground: the floating island and the Redcoon
  assets/icon/icon_monochrome.png  432 x 432  Android 13+ themed icon: the Redcoon's silhouette
  assets/icon/icon_main.png        192 x 192  legacy launcher icon: both layers, as a rounded square
  assets/icon/icon_square.png      512 x 512  the same, square and unrounded (web home-screen icons; iOS rounds it)
  icon.png                         256 x 256  the project / window icon (project.godot config/icon)

The scene is framed so the island sits inside the adaptive icon's safe zone (the middle 66 of its 108 dp), so no
launcher mask shape cuts into it. Run from the project root (opens a Godot window for a moment):
  python tools/make_icon.py
"""
import os
import subprocess
import tempfile

from PIL import Image, ImageChops, ImageDraw

GODOT = r'C:\Program Files\Godot\Godot_v4.7-stable_win64.exe'
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'icon')


def visible(img, size):
    """The visible middle of an adaptive icon (72 of 108 dp), `size` pixels square."""
    w = img.width
    m = int(round(w * 18 / 108))
    return img.crop((m, m, w - m, w - m)).resize((size, size), Image.LANCZOS)


def rounded(img, size, radius=0.22):
    """The visible middle of an adaptive icon as a rounded square of `size` pixels."""
    img = visible(img, size)
    mask = Image.new('L', (size * 4, size * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size * 4 - 1, size * 4 - 1), radius=int(size * 4 * radius), fill=255)
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask.resize((size, size), Image.LANCZOS))
    return out


def main():
    tmp = tempfile.mkdtemp(prefix='rc_icon_')
    base = os.path.join(tmp, 'icon').replace('\\', '/')
    subprocess.run([GODOT, '--path', ROOT, '--resolution', '1024x1024', '--script', 'res://tools/make_icon.gd', '--', '--out=' + base], check=True)
    full = Image.open(base + '_full.png').convert('RGBA')
    fg = Image.open(base + '_fg.png').convert('RGBA')
    bg = Image.open(base + '_bg.png').convert('RGBA')
    os.makedirs(OUT, exist_ok=True)
    bg.convert('RGB').resize((432, 432), Image.LANCZOS).save(os.path.join(OUT, 'icon_background.png'))
    fg.resize((432, 432), Image.LANCZOS).save(os.path.join(OUT, 'icon_foreground.png'))
    # themed icon: the Redcoon's silhouette in white, fitted inside the safe zone
    # (the dark mask and pupils are cut out of it, so it reads as a raccoon rather than a blob)
    m = Image.open(base + '_mono.png').convert('RGBA')
    r, g, b, alpha = m.split()
    bright = ImageChops.lighter(ImageChops.lighter(r, g), b).point(lambda v: 255 if v > 80 else 0)
    a = ImageChops.multiply(alpha, bright)
    a = a.crop(m.getchannel('A').getbbox())
    s = 432 * 0.52 / max(a.size)
    a = a.resize((int(a.width * s), int(a.height * s)), Image.LANCZOS)
    mono = Image.new('RGBA', (432, 432), (255, 255, 255, 0))
    glyph = Image.new('RGBA', a.size, (255, 255, 255, 255))
    glyph.putalpha(a)
    mono.paste(glyph, ((432 - a.width) // 2, (432 - a.height) // 2), glyph)
    mono.save(os.path.join(OUT, 'icon_monochrome.png'))
    rounded(full, 192).save(os.path.join(OUT, 'icon_main.png'))
    rounded(full, 256).save(os.path.join(ROOT, 'icon.png'))
    visible(full, 512).convert('RGB').save(os.path.join(OUT, 'icon_square.png'))
    print('wrote', OUT, 'and icon.png')


if __name__ == '__main__':
    main()
