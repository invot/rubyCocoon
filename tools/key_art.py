"""Shared pieces for the app icon (make_icon.py) and the boot splash (make_splash.py): rendering the game's beasts and
summons with tools/make_key_art.gd, and the 2D finishing they get in the PS2-era box-art style: gradients, soft glows,
glints, glass bubbles, silhouettes and the gold-on-ruby logo in the game's heading font."""
import math
import os
import random
import subprocess
import tempfile

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

GODOT = os.environ.get('GODOT', r'C:\Program Files\Godot\Godot_v4.7-stable_win64.exe')
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HEAD = os.path.join(ROOT, 'ui', 'lunchds.ttf')


def render(names):
    """Renders the named pieces (see make_key_art.gd) into a temporary folder and returns a loader for them: each
    piece cropped to what it covers. Opens a Godot window for a moment."""
    tmp = tempfile.mkdtemp(prefix='rc_key_art_').replace('\\', '/')
    subprocess.run([GODOT, '--path', ROOT, '--script', 'res://tools/make_key_art.gd', '--', '--out=' + tmp,
                    '--only=' + ','.join(names)], check=True)

    def piece(n):
        im = Image.open(os.path.join(tmp, n + '.png')).convert('RGBA')
        return im.crop(im.getchannel('A').getbbox())
    return piece


def hexc(h, a=255):
    """'#rrggbb' or '#rrggbbaa' as an RGBA tuple."""
    h = h.lstrip('#')
    if len(h) == 8:
        a = int(h[6:8], 16)
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a


def fit(im, w=None, h=None):
    k = min(w / im.width if w else 1e9, h / im.height if h else 1e9)
    return im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.LANCZOS)


def vgrad(w, h, stops):
    """A vertical gradient through (position 0..1, '#hex') stops; above the first and below the last it holds."""
    im = Image.new('RGBA', (1, h))
    px = im.load()
    stops = [(p, hexc(c)) for p, c in stops]
    for y in range(h):
        t = y / max(1, h - 1)
        col = stops[0][1] if t <= stops[0][0] else stops[-1][1]
        for a, b in zip(stops, stops[1:]):
            if a[0] <= t <= b[0]:
                k = (t - a[0]) / max(1e-6, b[0] - a[0])
                col = tuple(int(a[1][j] + (b[1][j] - a[1][j]) * k) for j in range(4))
                break
        px[0, y] = col
    return im.resize((w, h), Image.BILINEAR)


def radial_mask(w, h, power=1.0, gain=1.0):
    """255 at the centre falling to 0 at the edge of the ellipse filling w x h."""
    # (radial_gradient climbs to 255 at the corners: 181 at the edge of the inscribed circle)
    g = Image.radial_gradient('L').point(lambda v: int(255 * max(0.0, 1 - v / 181.0))).resize((w, h), Image.BILINEAR)
    return g.point(lambda v: int(min(255, 255 * gain * (v / 255) ** power)))


def glow(base, cx, cy, r, color, alpha=1.0, power=1.6, sx=1.0):
    w, h = int(r * 2 * sx), int(r * 2)
    lay = Image.new('RGBA', (w, h), hexc(color))
    lay.putalpha(radial_mask(w, h, power, alpha))
    base.alpha_composite(lay, (int(cx - w / 2), int(cy - h / 2)))


def screen(base, lay, pos=(0, 0)):
    """Screen-blends lay (by its alpha) over base at pos."""
    full = Image.new('RGBA', base.size, (0, 0, 0, 0))
    full.alpha_composite(lay, pos)
    rgb = Image.composite(full.convert('RGB'), Image.new('RGB', base.size, (0, 0, 0)), full.getchannel('A'))
    out = ImageChops.screen(base.convert('RGB'), rgb).convert('RGBA')
    out.putalpha(base.getchannel('A'))
    base.paste(out, (0, 0))


def tint(im, color):
    """im's shape filled with one colour."""
    out = Image.new('RGBA', im.size, hexc(color))
    out.putalpha(im.getchannel('A'))
    return out


def shadow_of(im, blur, color='#000000', alpha=0.6):
    """im's shape blurred and coloured, on a canvas grown by the returned padding on every side."""
    pad = blur * 3
    a = Image.new('L', (im.width + pad * 2, im.height + pad * 2), 0)
    a.paste(im.getchannel('A'), (pad, pad))
    a = a.filter(ImageFilter.GaussianBlur(blur)).point(lambda v: int(v * alpha))
    out = Image.new('RGBA', a.size, hexc(color))
    out.putalpha(a)
    return out, pad


def outer_glow(base, im, pos, blur, color, alpha):
    g, pad = shadow_of(im, blur, color, alpha)
    base.alpha_composite(g, (pos[0] - pad, pos[1] - pad))


def sparkle(base, x, y, s, color='#ffffff', alpha=255):
    """A soft four-point star of radius s."""
    pad = int(s * 1.2)
    w = pad * 2 + 1
    m = Image.new('L', (w * 4, w * 4), 0)
    d = ImageDraw.Draw(m)
    c, S = w * 2, s * 4
    t = max(2, S // 9)
    d.polygon([(c, c - S), (c + t, c), (c, c + S), (c - t, c)], fill=255)
    d.polygon([(c - S, c), (c, c - t), (c + S, c), (c, c + t)], fill=255)
    d.ellipse((c - t * 2, c - t * 2, c + t * 2, c + t * 2), fill=255)
    m = m.resize((w, w), Image.LANCZOS)
    a = ImageChops.lighter(m.filter(ImageFilter.GaussianBlur(max(1, s / 10))), m.filter(ImageFilter.GaussianBlur(max(2, s / 4))))
    lay = Image.new('RGBA', (w, w), hexc(color))
    lay.putalpha(a.point(lambda v: int(v * alpha / 255)))
    base.alpha_composite(lay, (int(x - pad), int(y - pad)))


def dust(base, n, box, seed, colors=('#ffffff',), smin=1.0, smax=4.0, amax=180):
    """Motes of light (or stars) scattered over box."""
    rng = random.Random(seed)
    lay = Image.new('RGBA', base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    for _ in range(n):
        x, y = rng.uniform(box[0], box[2]), rng.uniform(box[1], box[3])
        r = rng.uniform(smin, smax)
        d.ellipse((x - r, y - r, x + r, y + r), fill=hexc(rng.choice(colors), int(rng.uniform(40, amax))))
    base.alpha_composite(lay.filter(ImageFilter.GaussianBlur(1.2)))
    base.alpha_composite(lay)


def vignette(base, strength=0.55, color='#000000'):
    w, h = base.size
    m = ImageChops.invert(radial_mask(int(w * 1.25), int(h * 1.45), 0.9))
    x0, y0 = (m.width - w) // 2, (m.height - h) // 2
    lay = Image.new('RGBA', (w, h), hexc(color))
    lay.putalpha(m.crop((x0, y0, x0 + w, y0 + h)).point(lambda v: int(v * strength)))
    base.alpha_composite(lay)


def circle_mask(d, ss=4):
    m = Image.new('L', (d * ss, d * ss), 0)
    ImageDraw.Draw(m).ellipse((0, 0, d * ss - 1, d * ss - 1), fill=255)
    return m.resize((d, d), Image.LANCZOS)


def bubble(d, content=None, tint_c='#9fd8ff', fill_frac=0.74, blur=0):
    """A glassy bubble d across holding a beast: a faint fill, the beast, a thin iridescent rim, a crescent highlight
    with a glint, and a soft bounce of light along the bottom."""
    out = Image.new('RGBA', (d, d), (0, 0, 0, 0))
    disc = circle_mask(d)
    fill = Image.new('RGBA', (d, d), hexc(tint_c))
    fill.putalpha(ImageChops.multiply(radial_mask(d, d, 0.6).point(lambda v: int(26 + (255 - v) * 0.12)), disc))
    out.alpha_composite(fill)
    if content is not None:
        c = fit(content, int(d * fill_frac), int(d * fill_frac))
        inner = Image.new('RGBA', (d, d), (0, 0, 0, 0))
        inner.alpha_composite(c, ((d - c.width) // 2, int(d * 0.52 - c.height / 2)))
        inner.putalpha(ImageChops.multiply(inner.getchannel('A'), disc))
        out.alpha_composite(inner)
    rim = ImageChops.invert(radial_mask(d, d, 1.0)).point(lambda v: int(255 * max(0.0, (v / 255 - 0.9) / 0.1) ** 2.0))
    rim = ImageChops.multiply(rim, disc)
    for col, dx, dy in (('#ffb0e8', -0.02, 0.03), ('#a8fff0', 0.03, -0.02), ('#ffffff', 0, 0)):
        lay = Image.new('RGBA', (d, d), hexc(col))
        a = ImageChops.offset(rim, int(dx * d), int(dy * d)).point(lambda v: int(v * (0.4 if col == '#ffffff' else 0.3)))
        lay.putalpha(ImageChops.multiply(a, disc))
        out.alpha_composite(lay)
    hl = Image.new('L', (d * 2, d * 2), 0)
    hd = ImageDraw.Draw(hl)
    hd.ellipse((d * 0.30, d * 0.18, d * 1.05, d * 0.62), fill=210)
    hd.ellipse((d * 0.42, d * 0.30, d * 1.15, d * 0.78), fill=0)
    hl = hl.rotate(28, center=(d * 0.7, d * 0.5)).resize((d, d), Image.LANCZOS).filter(ImageFilter.GaussianBlur(d / 70))
    lay = Image.new('RGBA', (d, d), (255, 255, 255, 255))
    lay.putalpha(ImageChops.multiply(hl, disc))
    out.alpha_composite(lay)
    sparkle(out, d * 0.27, d * 0.24, max(4, int(d * 0.07)), alpha=230)
    bl = Image.new('L', (d, d), 0)
    ImageDraw.Draw(bl).ellipse((d * 0.22, d * 0.80, d * 0.78, d * 0.97), fill=90)
    lay = Image.new('RGBA', (d, d), hexc('#ffd0e0'))
    lay.putalpha(ImageChops.multiply(bl.filter(ImageFilter.GaussianBlur(d / 30)), disc))
    out.alpha_composite(lay)
    return out.filter(ImageFilter.GaussianBlur(blur)) if blur else out


def dilate(mask, r):
    """A mask grown by about r, with rounded corners."""
    return mask.filter(ImageFilter.GaussianBlur(r)).point(lambda v: 255 if v > 30 else 0).filter(ImageFilter.GaussianBlur(1))


def logo(width, glow_c='#ff5030', glow_a=0.0):
    """RUBY COCOON in the heading font as a PS2-era logo, `width` pixels wide: gold with a dark horizon band across its
    middle, bevelled, inside a ruby stroke, extruded downwards, with glints and a drop shadow (and a coloured glow if
    glow_a > 0). Drawn at about twice the size and scaled down."""
    f = ImageFont.truetype(HEAD, 300)
    text = 'RUBY COCOON'
    bb = ImageDraw.Draw(Image.new('L', (8, 8))).textbbox((0, 0), text, font=f, stroke_width=5)
    pad = 120
    w, h = bb[2] - bb[0] + pad * 2, bb[3] - bb[1] + pad * 2 + 40
    tm = Image.new('L', (w, h), 0)
    ImageDraw.Draw(tm).text((pad - bb[0], pad - bb[1]), text, font=f, fill=255, stroke_width=5, stroke_fill=255)
    tm = tm.filter(ImageFilter.GaussianBlur(1.2))
    tb = tm.getbbox()
    th = tb[3] - tb[1]
    dark, ruby, line = dilate(tm, 20), dilate(tm, 14), dilate(tm, 5)
    out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    depth = 26
    for k in range(depth, 0, -1):
        t = k / depth
        lay = Image.new('RGBA', (w, h), (int(70 - 48 * t), int(8 - 4 * t), int(18 - 10 * t), 255))
        lay.putalpha(ImageChops.offset(dark, 0, k))
        out.alpha_composite(lay)
    out.alpha_composite(_filled(dark, hexc('#1c0508')))
    rl = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    rl.paste(vgrad(w, th + 40, [(0, '#ff6070'), (0.5, '#d01836'), (1, '#6a0618')]), (0, tb[1] - 20))
    rl.putalpha(ruby)
    out.alpha_composite(rl)
    out.alpha_composite(_filled(line, hexc('#2a0a0c')))
    gl = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    gl.paste(vgrad(w, th, [(0, '#fffbe6'), (0.36, '#ffe070'), (0.5, '#c06a14'), (0.53, '#e89422'), (0.8, '#ffd458'),
                           (1, '#fff2b0')]), (0, tb[1]))
    gl.putalpha(tm)
    out.alpha_composite(gl)
    # bevel: light along the upper-left edges, shade along the lower-right
    soft = tm.filter(ImageFilter.GaussianBlur(5))
    hi = ImageChops.subtract(soft, ImageChops.offset(soft, 4, 5)).point(lambda v: min(255, v * 3))
    lo = ImageChops.subtract(soft, ImageChops.offset(soft, -4, -5)).point(lambda v: min(255, v * 2))
    out.alpha_composite(_filled(ImageChops.multiply(hi, tm), (255, 255, 240, 255)))
    out.alpha_composite(_filled(ImageChops.multiply(lo, tm), (110, 40, 0, 255)))
    sparkle(out, tb[0] + th * 0.25, tb[1] + th * 0.12, int(th * 0.22))
    sparkle(out, tb[0] + (tb[2] - tb[0]) * 0.71, tb[1] + th * 0.1, int(th * 0.16), alpha=235)
    sh, sp = shadow_of(out, 22, '#000000', 0.55)
    full = Image.new('RGBA', (w + sp * 2, h + sp * 2), (0, 0, 0, 0))
    if glow_a > 0:
        g, gp = shadow_of(out, 60, glow_c, glow_a)
        full.alpha_composite(g, (sp - gp, sp - gp))
    full.alpha_composite(sh, (0, 18))
    full.alpha_composite(out, (sp, sp))
    return fit(full.crop(full.getchannel('A').getbbox()), w=width)


def _filled(mask, rgba):
    lay = Image.new('RGBA', mask.size, rgba)
    lay.putalpha(mask)
    return lay


def silhouette_rim(im, color, rim='#ff9a50', rim_a=0.8, px=4):
    """A silhouette in one colour with a thin warm rim of light along its top edges."""
    s = tint(im, color)
    a = im.getchannel('A')
    edge = ImageChops.subtract(a, ImageChops.offset(a, 0, px)).point(lambda v: int(v * rim_a))
    s.alpha_composite(_filled(edge.filter(ImageFilter.GaussianBlur(1)), hexc(rim)))
    return s


def clouds(w, h, seed, n, box, rmin, rmax, top, bottom, alpha=200, blur=26):
    """Soft cloud banks over box, shaded from `top` above to `bottom` below."""
    rng = random.Random(seed)
    m = Image.new('L', (w, h), 0)
    d = ImageDraw.Draw(m)
    for _ in range(n):
        x, y = rng.uniform(box[0], box[2]), rng.uniform(box[1], box[3])
        r = rng.uniform(rmin, rmax)
        d.ellipse((x - r * 1.9, y - r * 0.6, x + r * 1.9, y + r * 0.6), fill=alpha)
    col = vgrad(w, h, [(box[1] / h, top), (min(1.0, box[3] / h + 0.05), bottom)])
    col.putalpha(m.filter(ImageFilter.GaussianBlur(blur)))
    return col


def rays(base, cx, cy, color, n, length, seed, alpha=60, spread=math.pi * 2):
    """Soft beams of light fanning out from (cx, cy), centred on straight up."""
    rng = random.Random(seed)
    w, h = base.size
    m = Image.new('L', (w, h), 0)
    d = ImageDraw.Draw(m)
    for i in range(n):
        a = -math.pi / 2 + (i / n - 0.5) * spread + rng.uniform(-0.05, 0.05)
        wd = rng.uniform(0.02, 0.05)
        ln = length * rng.uniform(0.6, 1.0)
        d.polygon([(cx, cy), (cx + math.cos(a - wd) * ln, cy + math.sin(a - wd) * ln),
                   (cx + math.cos(a + wd) * ln, cy + math.sin(a + wd) * ln)], fill=int(rng.uniform(0.4, 1) * alpha))
    fade = Image.new('L', (w, h), 0)
    fade.paste(radial_mask(int(length * 2), int(length * 2), 1.2), (int(cx - length), int(cy - length)))
    base.alpha_composite(_filled(ImageChops.multiply(m.filter(ImageFilter.GaussianBlur(10)), fade), hexc(color)))


def hill_y(x, box):
    """The top edge of the ellipse in box (x0, y0, x1, y1) at x."""
    cx, cy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
    rx, ry = (box[2] - box[0]) / 2, (box[3] - box[1]) / 2
    return cy - ry * math.sqrt(max(0.0, 1 - ((x - cx) / rx) ** 2))


def ruby(w):
    """A cut ruby seen from the side, w wide: a table and crown over a pointed pavilion, each facet its own shade."""
    S = 4
    W, H = w * S, int(w * 1.05) * S
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    g = H * 0.32  # the girdle
    tl, tr = W * 0.27, W * 0.73
    facets = [
        ([(tl, 0), (tr, 0), (W * 0.62, g), (W * 0.38, g)], '#ff6a80'),
        ([(0, g), (tl, 0), (W * 0.38, g)], '#e8304a'),
        ([(W, g), (tr, 0), (W * 0.62, g)], '#b81030'),
        ([(0, g), (W * 0.38, g), (W * 0.5, H)], '#a00c26'),
        ([(W * 0.38, g), (W * 0.62, g), (W * 0.5, H)], '#d81a3a'),
        ([(W * 0.62, g), (W, g), (W * 0.5, H)], '#780818'),
    ]
    for pts, col in facets:
        d.polygon(pts, fill=hexc(col))
    d.polygon([(W * 0.33, H * 0.03), (W * 0.5, H * 0.03), (W * 0.44, g * 0.9), (W * 0.36, g * 0.9)], fill=(255, 220, 228, 170))
    return im.resize((w, int(w * 1.05)), Image.LANCZOS)


def rounded(img, size, radius=0.22):
    """img as a rounded square, size pixels."""
    img = img.convert('RGBA').resize((size, size), Image.LANCZOS)
    m = Image.new('L', (size * 4, size * 4), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size * 4 - 1, size * 4 - 1), radius=int(size * 4 * radius), fill=255)
    img.putalpha(m.resize((size, size), Image.LANCZOS))
    return img
