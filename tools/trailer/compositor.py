"""The trailer's picture engine: reads the recorded clips, joins them with soft transitions, and draws the title cards
and the pre-release disclaimer over them. The cut itself (which clip when, which card where) is in make_trailer.py."""
import math
import os
import subprocess

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H, FPS = 1920, 1080, 60
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RAW = os.path.join(ROOT, "build", "trailer", "raw")
FONT = os.path.join(ROOT, "ui", "LeagueSpartan.ttf")

# the game's own colours: the ruby gem (ui_kit.gd ACCENTS), warm cream for words, a warm near-black behind them
RUBY = (210, 31, 44)
CREAM = (255, 244, 222)
INK = (28, 11, 15)
WARM_WHITE = (255, 250, 238)


# ---------------------------------------------------------------------------------------------------------- easing
def clamp01(x):
    return 0.0 if x < 0.0 else (1.0 if x > 1.0 else x)


def smooth(x):
    x = clamp01(x)
    return x * x * (3.0 - 2.0 * x)


def out_cubic(x):
    x = clamp01(x)
    return 1.0 - (1.0 - x) ** 3


def in_out_cubic(x):
    x = clamp01(x)
    return 4 * x * x * x if x < 0.5 else 1 - (-2 * x + 2) ** 3 / 2


def out_back(x, s=1.9):
    x = clamp01(x) - 1.0
    return 1.0 + x * x * ((s + 1.0) * x + s)


# ---------------------------------------------------------------------------------------------------------- clips
class Reader:
    """Frames of one clip, in order, from `src` seconds in. A solid colour stands in for the clips "black"/"white"."""

    def __init__(self, clip, src):
        self.proc = None
        self.last = None
        # asked for from before its start, a clip waits on its first frame until its time comes
        self.wait = int(round(max(0.0, -src) * FPS))
        if clip in ("black", "white"):
            self.last = np.full((H, W, 3), 0 if clip == "black" else 255, np.uint8)
            if clip == "white":
                self.last[:] = WARM_WHITE
            return
        path = os.path.join(RAW, clip + ".avi")
        if not os.path.exists(path):
            raise SystemExit("missing clip: " + path)
        self.proc = subprocess.Popen(["ffmpeg", "-v", "error", "-ss", "%.4f" % max(src, 0.0), "-i", path, "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
                                     stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, bufsize=W * H * 3 * 2)

    def next(self):
        if self.proc is None:
            return self.last
        if self.wait > 0 and self.last is not None:
            self.wait -= 1
            return self.last
        buf = self.proc.stdout.read(W * H * 3)
        if len(buf) == W * H * 3:
            self.last = np.frombuffer(buf, np.uint8).reshape(H, W, 3)
        elif self.last is None:
            self.last = np.zeros((H, W, 3), np.uint8)
        return self.last

    def close(self):
        if self.proc is not None:
            self.proc.stdout.close()
            self.proc.kill()
            self.proc.wait()
            self.proc = None


class Shot:
    """One stretch of a clip. `at` is when it cuts in on the trailer, `src` where in the clip that moment is.
    trans: (kind, seconds), centred on the cut: cut, fade, bloom (through warm white), dip (through black), iris, wipe,
    wipe_back. zoom: (from, to, x, y), a slow push towards a point. fx: "punch" (a quick settle on the cut), "flash".
    hold: the clip's time at which the picture stops (the rest of the shot stays on that frame). audio: the clip's own
    sound effects, 0 for none."""

    def __init__(self, clip, src, at, trans=("cut", 0.0), zoom=None, fx="", hold=None, audio=0.6, centre=(0.5, 0.5), note=""):
        self.clip, self.src, self.at = clip, float(src), float(at)
        self.kind, self.tdur = trans
        self.zoom, self.fx, self.hold, self.audio, self.centre, self.note = zoom, fx, hold, audio, centre, note
        self.end = 0.0
        self.reader = None
        self.held = None

    def frame(self, t, single=False):
        src_t = self.src + (t - self.at)
        if self.hold is not None and src_t >= self.hold:
            if self.held is None:
                r = Reader(self.clip, self.hold)
                self.held = r.next().copy()
                r.close()
            return self.held
        if single:
            r = Reader(self.clip, src_t)
            f = r.next()
            r.close()
            return f
        if self.reader is None:
            self.reader = Reader(self.clip, src_t)
        return self.reader.next()

    def close(self):
        if self.reader is not None:
            self.reader.close()
            self.reader = None


def zoomed(frame, z, cx, cy):
    if abs(z - 1.0) < 0.0005:
        return frame
    bw, bh = W / z, H / z
    left = min(max(cx * W - bw / 2, 0), W - bw)
    top = min(max(cy * H - bh / 2, 0), H - bh)
    return np.asarray(Image.fromarray(frame).resize((W, H), Image.BICUBIC, box=(left, top, left + bw, top + bh)))


# ---------------------------------------------------------------------------------------------------------- transitions
_YY, _XX = np.mgrid[0:H, 0:W].astype(np.float32)
_dist_cache = {}


def _dist(cx, cy):
    key = (round(cx, 3), round(cy, 3))
    if key not in _dist_cache:
        _dist_cache.clear()
        _dist_cache[key] = np.sqrt((_XX - cx * W) ** 2 + (_YY - cy * H) ** 2)
    return _dist_cache[key]


_SLANT = (_XX / W + 0.22 * _YY / H) / 1.22


def _solid(colour):
    return Image.new("RGB", (W, H), colour)


def transition(a, b, p, kind, centre=(0.5, 0.5)):
    """a going out, b coming in, p from 0 to 1."""
    if kind == "fade":
        return np.asarray(Image.blend(Image.fromarray(a), Image.fromarray(b), smooth(p)))
    if kind in ("bloom", "dip"):
        mid = _solid(WARM_WHITE if kind == "bloom" else (0, 0, 0))
        if p < 0.5:
            return np.asarray(Image.blend(Image.fromarray(a), mid, smooth(p * 2.0)))
        return np.asarray(Image.blend(mid, Image.fromarray(b), smooth(p * 2.0 - 1.0)))
    af = a.astype(np.float32)
    bf = b.astype(np.float32)
    glow_colour = np.array(CREAM, np.float32)
    if kind == "iris":
        # a soft-edged circle opening from the middle of the action, a thin cream ring of light on its rim
        d = _dist(*centre)
        far = math.hypot(max(centre[0], 1 - centre[0]) * W, max(centre[1], 1 - centre[1]) * H) + 90.0
        r = far * in_out_cubic(p)
        feather = 46.0
        m = np.clip((r - d) / feather + 0.5, 0.0, 1.0)[..., None]
        ring = np.exp(-((d - r) / 9.0) ** 2)[..., None] * 0.75 * math.sin(math.pi * clamp01(p)) ** 0.6
    else:
        # a soft slanted wipe, like a page of the travel book turning, with light along its edge
        s = _SLANT if kind == "wipe" else 1.0 - _SLANT
        f = 0.085
        e = -f + (1.0 + 2.0 * f) * in_out_cubic(p)
        m = np.clip((e - s) / f * 0.5 + 0.5, 0.0, 1.0)[..., None]
        ring = np.exp(-((s - e) / 0.012) ** 2)[..., None] * 0.6 * math.sin(math.pi * clamp01(p)) ** 0.6
    out = af + (bf - af) * m
    out += (glow_colour - out) * ring
    return np.clip(out + 0.5, 0, 255).astype(np.uint8)


# ---------------------------------------------------------------------------------------------------------- sprites
_fonts = {}


def font(size, weight):
    key = (size, weight)
    if key not in _fonts:
        f = ImageFont.truetype(FONT, size)
        f.set_variation_by_axes([weight])
        _fonts[key] = f
    return _fonts[key]


class Sprite:
    """A picture with see-through parts, ready to lay over a frame: colour (already multiplied by its opacity) and
    opacity, both float. ox, oy: where its anchor is inside it."""

    def __init__(self, img, ox=0.0, oy=0.0):
        arr = np.asarray(img.convert("RGBA")).astype(np.float32)
        self.a = arr[..., 3:4] / 255.0
        self.rgb = arr[..., :3] * self.a
        self.h, self.w = arr.shape[:2]
        self.ox, self.oy = ox, oy
        self.img = img

    def scaled(self, s):
        if abs(s - 1.0) < 0.004:
            return self
        w, h = max(1, int(round(self.w * s))), max(1, int(round(self.h * s)))
        return Sprite(self.img.resize((w, h), Image.BICUBIC), self.ox * s, self.oy * s)


def blit(frame, spr, x, y, op=1.0, crop=None):
    """Lays a sprite on the frame with its anchor at (x, y). crop: (left, right) in sprite pixels, to reveal part."""
    if op <= 0.003:
        return
    x0 = int(round(x - spr.ox))
    y0 = int(round(y - spr.oy))
    sl, sr = (0, spr.w) if crop is None else (max(0, int(crop[0])), min(spr.w, int(crop[1])))
    if sr <= sl:
        return
    fx0, fx1 = max(x0 + sl, 0), min(x0 + sr, W)
    fy0, fy1 = max(y0, 0), min(y0 + spr.h, H)
    if fx1 <= fx0 or fy1 <= fy0:
        return
    a = spr.a[fy0 - y0:fy1 - y0, fx0 - x0:fx1 - x0] * op
    rgb = spr.rgb[fy0 - y0:fy1 - y0, fx0 - x0:fx1 - x0] * op
    reg = frame[fy0:fy1, fx0:fx1].astype(np.float32)
    reg = reg * (1.0 - a) + rgb
    frame[fy0:fy1, fx0:fx1] = np.clip(reg + 0.5, 0, 255).astype(np.uint8)


def _shadowed(img, colour=INK, blur=14, strength=0.75, dy=6):
    """Puts a soft warm shadow under a drawn layer."""
    alpha = img.getchannel("A")
    sh = Image.new("RGBA", img.size, colour + (0,))
    sh.putalpha(alpha.filter(ImageFilter.GaussianBlur(blur)).point(lambda v: int(min(255, v * strength * 1.6))))
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.alpha_composite(sh, (0, dy))
    out.alpha_composite(img)
    return out


def text_sprite(text, size, weight, colour=CREAM, tracking=0.0, shadow=True, pad=40, anchor="mm"):
    """A line of text as one sprite, and its width. anchor: l/m/r across; m (middle of the capitals) or b (baseline)."""
    f = font(size, weight)
    asc, desc = f.getmetrics()
    widths = [f.getlength(ch) + tracking for ch in text]
    tw = int(math.ceil(sum(widths) - tracking))
    img = Image.new("RGBA", (tw + pad * 2, asc + desc + pad * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    x = float(pad)
    for ch, wd in zip(text, widths):
        d.text((x, pad), ch, font=f, fill=colour + (255,))
        x += wd
    if shadow:
        img = _shadowed(img)
    cap = f.getbbox("H")
    mid = pad + (cap[1] + cap[3]) / 2.0
    ox = pad if anchor[0] == "l" else (pad + tw if anchor[0] == "r" else pad + tw / 2.0)
    return Sprite(img, ox, mid if anchor[1] == "m" else pad + asc), tw


def letter_sprites(text, size, weight, colour=CREAM, tracking=0.0, pad=44):
    """Each letter of a word as its own sprite, with where it stands from the word's middle, so they can come in
    one after another. Also the word's width."""
    f = font(size, weight)
    asc, desc = f.getmetrics()
    widths = [f.getlength(ch) + tracking for ch in text]
    tw = sum(widths) - tracking
    cap = f.getbbox("H")
    mid = pad + (cap[1] + cap[3]) / 2.0
    out = []
    x = -tw / 2.0
    for ch, wd in zip(text, widths):
        if ch != " ":
            cw = int(math.ceil(f.getlength(ch)))
            img = Image.new("RGBA", (cw + pad * 2, asc + desc + pad * 2), (0, 0, 0, 0))
            ImageDraw.Draw(img).text((pad, pad), ch, font=f, fill=colour + (255,))
            out.append((Sprite(_shadowed(img, blur=16, strength=0.8, dy=8), pad, mid), x))
        x += wd
    return out, tw


def gem_sprite(size=92):
    """The ruby: a faceted gem in the game's red, with a soft glow under it."""
    s = 4
    w = size * s
    h = int(size * 0.86) * s
    pad = 34 * s
    img = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def pt(x, y):
        return (pad + x * w, pad + y * h)

    girdle = 0.36
    top = [pt(0.22, 0.0), pt(0.78, 0.0)]
    rim = [pt(0.0, girdle), pt(0.30, girdle), pt(0.70, girdle), pt(1.0, girdle)]
    tip = pt(0.5, 1.0)
    light, mid, base, dark, deep = (255, 150, 150), (240, 78, 88), RUBY, (158, 18, 32), (112, 10, 24)
    # the crown: left slope, table, right slope
    d.polygon([top[0], rim[1], rim[0]], fill=mid + (255,))
    d.polygon([top[0], top[1], rim[2], rim[1]], fill=light + (255,))
    d.polygon([top[1], rim[3], rim[2]], fill=base + (255,))
    # the pavilion: three facets down to the point
    d.polygon([rim[0], rim[1], tip], fill=base + (255,))
    d.polygon([rim[1], rim[2], tip], fill=mid + (255,))
    d.polygon([rim[2], rim[3], tip], fill=dark + (255,))
    for p0, p1 in [(rim[1], tip), (rim[2], tip), (rim[0], rim[3]), (top[0], rim[1]), (top[1], rim[2])]:
        d.line([p0, p1], fill=deep + (150,), width=s)
    outline = [top[0], top[1], rim[3], tip, rim[0]]
    d.line(outline + [outline[0]], fill=CREAM + (255,), width=int(2.4 * s), joint="curve")
    # a glint on the table
    d.polygon([pt(0.30, 0.07), pt(0.46, 0.07), pt(0.40, 0.27), pt(0.33, 0.27)], fill=(255, 255, 255, 190))
    glow = Image.new("RGBA", img.size, RUBY + (0,))
    glow.putalpha(img.getchannel("A").filter(ImageFilter.GaussianBlur(11 * s)).point(lambda v: int(v * 0.75)))
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.alpha_composite(glow)
    out.alpha_composite(img)
    out = out.resize((out.width // s, out.height // s), Image.LANCZOS)
    return Sprite(out, out.width / 2.0, out.height / 2.0)


def sparkle_sprite(size=150):
    """A four-pointed glint."""
    s = 3
    n = size * s
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = n / 2.0
    thin = n * 0.035
    d.polygon([(c, 0), (c + thin, c - thin), (n, c), (c + thin, c + thin), (c, n), (c - thin, c + thin), (0, c), (c - thin, c - thin)],
              fill=(255, 252, 240, 255))
    soft = img.filter(ImageFilter.GaussianBlur(2.2 * s))
    halo = img.filter(ImageFilter.GaussianBlur(9 * s))
    out = Image.alpha_composite(halo, soft)
    out = out.resize((size, size), Image.LANCZOS)
    return Sprite(out, size / 2.0, size / 2.0)


def flourish_sprite(length=330, right=True):
    """A thin cream rule ending in a little diamond, drawn outwards from the gem."""
    s = 3
    hgt = 30
    img = Image.new("RGBA", ((length + 40) * s, hgt * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    y = hgt * s / 2.0
    x0, x1 = 20 * s, (20 + length) * s
    d.line([(x0, y), (x1 - 16 * s, y)], fill=CREAM + (235,), width=int(2.5 * s))
    cx = x1 - 8 * s
    r = 6.5 * s
    d.polygon([(cx - r, y), (cx, y - r), (cx + r, y), (cx, y + r)], fill=CREAM + (255,))
    d.ellipse([x0 - 3 * s, y - 3 * s, x0 + 3 * s, y + 3 * s], fill=CREAM + (255,))
    img = _shadowed(img, blur=5 * s, strength=0.6, dy=3 * s)
    img = img.resize((length + 40, hgt), Image.LANCZOS)
    if not right:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    return Sprite(img, 20 if right else length + 20, hgt / 2.0)


def band_sprite(height=360, strength=0.6, colour=INK):
    """A soft dark band across the screen, for words laid straight over the action."""
    ramp = np.sin(np.linspace(0, math.pi, height)) ** 1.6
    alpha = np.repeat((ramp * strength * 255)[:, None], W, axis=1).astype(np.uint8)
    img = Image.new("RGBA", (W, height), colour + (0,))
    img.putalpha(Image.fromarray(alpha))
    return Sprite(img, 0, height / 2.0)


_veil = None


def soften(frame, e, dim=0.5, blur=1.0):
    """The game's own window look at full size: the scene behind goes out of focus and dims warmly. e: 0 to 1."""
    global _veil
    if e <= 0.002:
        return frame
    if _veil is None:
        # darker towards the corners
        d = np.sqrt(((_XX - W / 2) / (W / 2)) ** 2 + ((_YY - H / 2) / (H / 2)) ** 2)
        k = np.clip(1.0 - 0.55 * np.clip(d - 0.35, 0, 1), 0.2, 1.0)[..., None]
        _veil = Image.fromarray(np.clip(np.array(INK, np.float32) * (0.6 + 0.9 * k), 0, 255).astype(np.uint8))
    im = Image.fromarray(frame)
    small = im.reduce(4).filter(ImageFilter.GaussianBlur(5.0 * blur))
    big = small.resize((W, H), Image.BILINEAR)
    out = Image.blend(im, big, min(1.0, e * 1.7))
    return np.asarray(Image.blend(out, _veil, dim * e))


# ---------------------------------------------------------------------------------------------------------- cards
class Plate:
    """A feature's title card: the footage softens behind it, the ruby pops in with a glint, two rules draw outwards,
    the word's letters rise one after another and a line of small type follows."""

    def __init__(self, at, dur, word, sub, y=0.47):
        self.at, self.dur, self.y = at, dur, y * H
        self.letters, self.word_w = letter_sprites(word, 236, 800, tracking=10)
        self.sub, _ = text_sprite(sub, 62, 500, tracking=3.0)
        self.gem = gem_sprite(92)
        self.spark = sparkle_sprite(190)
        self.rule_r = flourish_sprite(330, True)
        self.rule_l = flourish_sprite(330, False)

    def env(self, t):
        u = t - self.at
        if u < 0 or u > self.dur:
            return 0.0
        return min(smooth(u / 0.32), smooth((self.dur - u) / 0.30))

    def base(self, frame, t):
        return soften(frame, self.env(t))

    def draw(self, frame, t):
        u = t - self.at
        if u < 0 or u > self.dur:
            return
        out = smooth((self.dur - u) / 0.26)
        lift = (1.0 - out) * -26.0
        cx = W / 2.0
        gy = self.y - 196 + lift
        # the rules, drawn outwards from the gem
        k = out_cubic((u - 0.10) / 0.50)
        if k > 0:
            n = int(self.rule_r.w * k)
            blit(frame, self.rule_r, cx + 62, gy, out, crop=(0, n))
            blit(frame, self.rule_l, cx - 62, gy, out, crop=(self.rule_l.w - n, self.rule_l.w))
        # the ruby, with a glint as it lands and a slow twinkle after
        g = out_back((u - 0.04) / 0.34, 2.6)
        if g > 0.02:
            blit(frame, self.gem.scaled(g), cx, gy, out * clamp01((u - 0.04) / 0.10))
        sp = (u - 0.16) / 0.55
        if 0.0 < sp < 1.0:
            blit(frame, self.spark.scaled(0.35 + 1.0 * out_cubic(sp)), cx + 20, gy - 16, out * math.sin(math.pi * sp) ** 0.8)
        tw = (u - 0.9) / 0.5
        if 0.0 < tw < 1.0:
            blit(frame, self.spark.scaled(0.42), cx - 26, gy + 4, out * 0.8 * math.sin(math.pi * tw))
        # the word, letter by letter
        for i, (spr, x) in enumerate(self.letters):
            v = (u - 0.14 - i * 0.045) / 0.36
            if v <= 0:
                continue
            blit(frame, spr, cx + x, self.y + (1.0 - out_back(v, 2.2)) * 64.0 + lift, out * clamp01(v * 2.6))
        v = (u - 0.52) / 0.40
        if v > 0:
            blit(frame, self.sub, cx, self.y + 172 + (1.0 - out_cubic(v)) * 18.0 + lift, out * smooth(v))


class ColdCard:
    """The story's turn: plain white words arriving one at a time, nothing cosy about them."""

    def __init__(self, at, dur, words, y=0.5, size=96, gap=0.42, dim=0.5):
        self.at, self.dur, self.gap, self.dim = at, dur, gap, dim
        f = font(size, 600)
        space = f.getlength(" ") + 26
        parts = [text_sprite(w, size, 600, colour=(255, 255, 255), tracking=9.0, anchor="lm") for w in words]
        total = sum(tw for _, tw in parts) + space * (len(parts) - 1)
        x = W / 2.0 - total / 2.0
        self.items = []
        for spr, tw in parts:
            self.items.append((spr, x))
            x += tw + space
        self.y = y * H

    def env(self, t):
        u = t - self.at
        if u < 0 or u > self.dur:
            return 0.0
        return min(smooth(u / 0.5), smooth((self.dur - u) / 0.4))

    def base(self, frame, t):
        e = self.env(t)
        if e <= 0.002:
            return frame
        return np.asarray(Image.blend(Image.fromarray(frame), _solid((4, 6, 12)), self.dim * e))

    def draw(self, frame, t):
        u = t - self.at
        if u < 0 or u > self.dur:
            return
        out = smooth((self.dur - u) / 0.35)
        for i, (spr, x) in enumerate(self.items):
            v = (u - 0.25 - i * self.gap) / 0.45
            if v > 0:
                blit(frame, spr, x, self.y, out * smooth(v))


class Slam:
    """The finale's short lines: big cream words that land on the beat over the action, a ruby bar under them."""

    def __init__(self, at, dur, text, y=0.70, size=150):
        self.at, self.dur, self.y = at, dur, y * H
        self.text, self.tw = text_sprite(text, size, 800, tracking=6.0, pad=56)
        if self.tw > W * 0.84:
            # a long line: as large as fits with a margin either side
            self.text, self.tw = text_sprite(text, int(size * W * 0.84 / self.tw), 800, tracking=6.0, pad=56)
        self.band = band_sprite(430, 0.62)
        bar = Image.new("RGBA", (int(self.tw * 0.42) + 40, 54), (0, 0, 0, 0))
        ImageDraw.Draw(bar).rounded_rectangle([20, 20, bar.width - 20, 32], radius=6, fill=RUBY + (255,))
        self.bar = Sprite(_shadowed(bar, blur=8, strength=0.7, dy=4), bar.width / 2.0, 26)

    def base(self, frame, t):
        return frame

    def draw(self, frame, t):
        u = t - self.at
        if u < 0 or u > self.dur:
            return
        out = smooth((self.dur - u) / 0.18)
        k = out_cubic(u / 0.16)
        blit(frame, self.band, 0, self.y + 10, out * smooth(u / 0.12))
        blit(frame, self.text.scaled(1.0 + 0.22 * (1.0 - k)), W / 2.0, self.y, out * clamp01(u / 0.07))
        bw = out_cubic((u - 0.10) / 0.30)
        if bw > 0:
            half = self.bar.w / 2.0
            blit(frame, self.bar, W / 2.0, self.y + 118, out, crop=(half - half * bw, half + half * bw))


class Tagline:
    """Under the game's own title: the three things you do, arriving one after another between two rules."""

    def __init__(self, at, words, y=0.80, size=74):
        self.at, self.y = at, y * H
        dot = text_sprite("·", size, 800, colour=(246, 92, 100), anchor="lm", shadow=True)
        gap = 34.0
        parts = []
        for i, w in enumerate(words):
            parts.append(text_sprite(w, size, 700, tracking=11.0, anchor="lm"))
            if i < len(words) - 1:
                parts.append(dot)
        total = sum(tw for _, tw in parts) + gap * (len(parts) - 1)
        x = W / 2.0 - total / 2.0
        self.items = []
        for spr, tw in parts:
            self.items.append((spr, x))
            x += tw + gap
        self.half = total / 2.0
        self.rule_r = flourish_sprite(200, True)
        self.rule_l = flourish_sprite(200, False)
        self.band = band_sprite(300, 0.5)

    def base(self, frame, t):
        return frame

    def draw(self, frame, t):
        u = t - self.at
        if u < 0:
            return
        blit(frame, self.band, 0, self.y + 6, smooth(u / 0.6))
        for i, (spr, x) in enumerate(self.items):
            v = (u - i * 0.16) / 0.42
            if v > 0:
                blit(frame, spr, x, self.y + (1.0 - out_back(v, 1.8)) * 30.0, smooth(v * 1.6))
        k = out_cubic((u - 0.75) / 0.6)
        if k > 0:
            n = int(self.rule_r.w * k)
            blit(frame, self.rule_r, W / 2.0 + self.half + 26, self.y, 1.0, crop=(0, n))
            blit(frame, self.rule_l, W / 2.0 - self.half - 26, self.y, 1.0, crop=(self.rule_l.w - n, self.rule_l.w))


class Disclaimer:
    """Along the bottom of every frame: this is pre-release footage."""

    def __init__(self, text):
        label, tw = text_sprite(text, 30, 500, colour=(255, 255, 255), tracking=2.8, shadow=False, pad=8)
        w, h = tw + 64, 54
        s = 3
        pill = Image.new("RGBA", (w * s, h * s), (0, 0, 0, 0))
        d = ImageDraw.Draw(pill)
        d.rounded_rectangle([s, s, w * s - s, h * s - s], radius=h * s // 2, fill=(14, 10, 12, 150), outline=(255, 255, 255, 105), width=int(1.6 * s))
        pill = pill.resize((w, h), Image.LANCZOS)
        pill.alpha_composite(label.img, (int(round(w / 2.0 - label.ox)), int(round(h / 2.0 - label.oy + 1))))
        self.spr = Sprite(pill, w / 2.0, h / 2.0)

    def draw(self, frame, op=1.0):
        blit(frame, self.spr, W / 2.0, H - 50, op)
