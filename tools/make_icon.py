"""Makes the app icon: the water summon rising as a ghostly spirit in a dusk sky over a dark hill, where a ruby glows on
the crest. The summon and the shrub are rendered from the game's models (tools/make_key_art.gd); the rest is painted in
tools/key_art.py. Writes:

  assets/icon/icon_background.png  432 x 432  Android adaptive icon background: the sky, its clouds and the spirit
  assets/icon/icon_foreground.png  432 x 432  Android adaptive icon foreground: the hill, the shrub and the ruby's glow
  assets/icon/icon_monochrome.png  432 x 432  Android 13+ themed icon: the spirit's silhouette
  assets/icon/icon_main.png        192 x 192  legacy launcher icon: both layers, as a rounded square
  assets/icon/icon_square.png      512 x 512  the same, square and unrounded (web home-screen icons; iOS rounds it)
  icon.png                         256 x 256  the project / window icon (project.godot config/icon)

It is laid out on the adaptive icon's whole 108 dp, the picture in the visible middle 72 and the sky and hill running on
into the margin, so launcher masks and parallax never show an edge. Run from the project root (opens a Godot window
for a moment):
  python tools/make_icon.py
"""
import math
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter

import key_art as K

OUT = os.path.join(K.ROOT, 'assets', 'icon')
V = 1024  # the visible middle
F = V * 108 // 72  # the whole adaptive canvas
O = (F - V) // 2


def spirit(im, height, alpha):
    """The summon as a pale blue ghost, fading out towards its feet."""
    s = K.fit(im, h=height)
    g = s.convert('L').point(lambda v: int(90 + v * 0.75))
    col = Image.merge('RGBA', (g.point(lambda v: int(v * 0.78)), g.point(lambda v: int(v * 0.9)), g, s.getchannel('A')))
    fade = K.vgrad(1, s.height, [(0.5, '#ffffff'), (1, '#000000')]).convert('L').resize(s.size)
    col.putalpha(ImageChops.multiply(s.getchannel('A'), fade).point(lambda v: int(v * alpha)))
    return col.filter(ImageFilter.GaussianBlur(1.5))


def layers(piece):
    """The background and foreground, F pixels square."""
    sky = [(0, '#0c1038'), (0.25, '#1f2a6e'), (0.5, '#4a4a9a'), (0.64, '#a8608a'), (0.74, '#ff9a50'), (0.80, '#ffd890'),
           (0.84, '#fff0c0')]
    bg = K.vgrad(F, F, [((O + p * V) / F, c) for p, c in sky])
    K.dust(bg, int(F * (O + V * 0.38) / 3400), (0, 0, F, O + V * 0.38), 11, ('#ffffff', '#cfe0ff'), 0.6, 1.8, 200)
    bg.alpha_composite(K.clouds(F, F, 4, 40, (0, O + 480, F, O + 760), 40, 110, '#6a4a8a', '#ffb070', 170, 30))
    sp = spirit(piece('spirit'), 760, 0.62)
    K.screen(bg, sp, ((F - sp.width) // 2 + 10, O + 70))

    fg = Image.new('RGBA', (F, F), (0, 0, 0, 0))
    box = (O - V * 0.5, O + V * 0.81, O + V * 1.5, O + V * 1.6)
    m = Image.new('L', (F * 2, F * 2), 0)
    d = ImageDraw.Draw(m)
    d.ellipse(tuple(v * 2 for v in box), fill=255)
    d.rectangle((0, (box[1] + box[3]), F * 2, F * 2), fill=255)
    hill = Image.new('RGBA', (F, F), (0, 0, 0, 0))
    hill.putalpha(m.resize((F, F), Image.LANCZOS))
    fg.alpha_composite(K.silhouette_rim(hill, '#120a1c', '#ffa060', 0.9, 4))
    sh = K.fit(piece('shrub'), h=170)
    sx = O + int(V * 0.74)
    fg.alpha_composite(K.silhouette_rim(sh, '#0c0614', '#ff9a50', 0.6, 3), (sx, int(K.hill_y(sx + sh.width / 2, box)) + 14 - sh.height))
    # the ruby on the crest, its light fanning up into the sky
    x = O + V // 2
    gem = K.ruby(100)
    top = int(K.hill_y(x, box) - gem.height * 0.62)
    gy = top + gem.height * 0.3
    K.rays(fg, x, gy, '#ffc890', 18, 560, 4, 55, math.pi * 1.2)
    K.glow(fg, x, gy, 240, '#ff8a50', 0.5, 1.8)
    K.glow(fg, x, gy, 120, '#ff3050', 0.75, 1.6)
    fg.alpha_composite(gem, (x - gem.width // 2, top))
    K.glow(fg, x, gy, 44, '#ffd8d0', 0.8, 1.4)
    K.sparkle(fg, x - 10, top + 16, 52)
    return bg, fg


def visible(img, size):
    """The visible middle of an adaptive icon (72 of 108 dp), `size` pixels square."""
    return img.crop((O, O, F - O, F - O)).resize((size, size), Image.LANCZOS)


def main():
    piece = K.render(['spirit', 'shrub'])
    bg, fg = layers(piece)
    full = bg.copy()
    full.alpha_composite(fg)
    os.makedirs(OUT, exist_ok=True)
    bg.convert('RGB').resize((432, 432), Image.LANCZOS).save(os.path.join(OUT, 'icon_background.png'))
    fg.resize((432, 432), Image.LANCZOS).save(os.path.join(OUT, 'icon_foreground.png'))
    # themed icon: the spirit's silhouette in white, fitted inside the safe zone
    a = piece('spirit').getchannel('A').point(lambda v: 255 if v > 100 else 0)
    s = 432 * 0.56 / max(a.size)
    a = a.resize((int(a.width * s), int(a.height * s)), Image.LANCZOS)
    glyph = Image.new('RGBA', a.size, (255, 255, 255, 255))
    glyph.putalpha(a)
    mono = Image.new('RGBA', (432, 432), (255, 255, 255, 0))
    mono.paste(glyph, ((432 - a.width) // 2, (432 - a.height) // 2), glyph)
    mono.save(os.path.join(OUT, 'icon_monochrome.png'))
    K.rounded(visible(full, 768), 192).save(os.path.join(OUT, 'icon_main.png'))
    K.rounded(visible(full, 768), 256).save(os.path.join(K.ROOT, 'icon.png'))
    visible(full, 512).convert('RGB').save(os.path.join(OUT, 'icon_square.png'))
    print('wrote', OUT, 'and icon.png')


if __name__ == '__main__':
    main()
