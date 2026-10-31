"""Makes the boot splash and the title screen's art from one picture, 1920 x 1080: the fire summon spreading its wings
over a dark ruby glow, the lines' first forms floating round it in glass bubbles, and the gold RUBY COCOON logo across
the top, with the lower middle left calm for the title's menu. The summon and the beasts are rendered from the game's
models (tools/make_key_art.gd); the rest is painted in tools/key_art.py. Writes:

  assets/icon/title_backdrop.png  the picture without the logo (scripts/ui/title_art.gd covers the title with it)
  assets/icon/title_logo.png      the logo alone, at the picture's scale (title_art.gd lays it over the backdrop)
  assets/icon/boot_splash.png     the two together (project.godot application/boot_splash)

Both cover the screen the same way (stretch mode Cover), so the boot splash gives way to the title without a jump; a
20:9 phone loses the top and bottom tenth, so the logo keeps below y 108. Run from the project root (opens a Godot
window for a moment):
  python tools/make_splash.py
"""
import os

import key_art as K

OUT = os.path.join(K.ROOT, 'assets', 'icon')
W, H = 1920, 1080
LOGO_W = 1100
LOGO_TOP = 150  # the logo's top edge, centred across the picture (title_art.gd LOGO_TOP)
# the bubbles: what floats in each (None: an empty one), its centre, its size and how far out of focus it is
BUBBLES = [
    ('crab_1', 260, 340, 280, 0), ('owl_1', 1660, 330, 250, 0), ('berry_1', 1600, 720, 210, 0), ('bat_1', 290, 760, 200, 0),
    ('tree_1', 560, 560, 130, 2), ('frog_1', 1360, 560, 140, 2), ('cactus_1', 100, 560, 110, 3), ('marmot_1', 1830, 540, 110, 3),
    (None, 690, 470, 64, 1), (None, 1240, 460, 56, 1), (None, 1420, 960, 90, 3), ('beetle_1', 520, 950, 130, 3),
]


def main():
    piece = K.render(['dragon'] + [b[0] for b in BUBBLES if b[0]])
    im = K.vgrad(W, H, [(0, '#0a0508'), (1, '#140810')])
    K.glow(im, 960, 520, 980, '#8a1030', 0.95, 1.05, 1.5)
    K.glow(im, 960, 470, 460, '#ff5040', 0.3, 1.4, 1.2)
    K.dust(im, 260, (0, 0, W, H), 21, ('#ffd0d8', '#ffffff', '#ffb080'), 0.8, 3, 160)
    dr = K.fit(piece('dragon'), h=980)
    at = ((W - dr.width) // 2 + 30, 60)
    K.outer_glow(im, dr, at, 50, '#ff3040', 0.35)
    im.alpha_composite(dr, at)
    for n, cx, cy, d, blur in BUBBLES:
        im.alpha_composite(K.bubble(d, piece(n) if n else None, blur=blur), (cx - d // 2, cy - d // 2))
    K.vignette(im, 0.6)
    os.makedirs(OUT, exist_ok=True)
    im.convert('RGB').save(os.path.join(OUT, 'title_backdrop.png'), optimize=True)
    lg = K.logo(LOGO_W, glow_c='#ff5030', glow_a=0.35)
    lg.save(os.path.join(OUT, 'title_logo.png'), optimize=True)
    im.alpha_composite(lg, ((W - lg.width) // 2, LOGO_TOP))
    im.convert('RGB').save(os.path.join(OUT, 'boot_splash.png'), optimize=True)
    for n in ('title_backdrop', 'title_logo', 'boot_splash'):
        print('wrote', n, '(%d KB)' % (os.path.getsize(os.path.join(OUT, n + '.png')) // 1024))


if __name__ == '__main__':
    main()
