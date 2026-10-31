"""Shared pieces for the app icon (make_icon.py): rendering the game's models with tools/make_key_art.gd, and the 2D
finishing they get in the PS2-era box-art style: gradients, soft glows, glints, clouds, light rays and silhouettes."""
import math
import os
import random
import subprocess
import tempfile

from PIL import Image, ImageChops, ImageDraw, ImageFilter

GODOT = os.environ.get('GODOT', r'C:\Program Files\Godot\Godot_v4.7-stable_win64.exe')
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


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


def _filled(mask, rgba):
    lay = Image.new('RGBA', mask.size, rgba)
    lay.putalpha(mask)
    return lay


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
