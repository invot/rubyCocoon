"""Checks every town map for paths the camera can't see.

The camera sits above and south of the player (world.gd CAM_OFFSET), so anything tall south of a tile can hide it:
a roof, a tower, a tree. For every walkable tile this traces the line from the camera (centred on that tile, as it is
when the player stands there) down to the tile and reports the tiles whose path (feet) or player (waist) is hidden.
Everything stands on its tile's level (the map's "heights", elevation.gd); the ground itself never hides anyone,
since high ground between the camera and the player dissolves around them (terrain.gdshader).
It also checks that every door, exit and person can be reached, up and down ramps but never over a cliff.

Run from the project root:  python tools/town_check.py [town ...]
"""
import math
import re
import sys
from collections import deque

SRC = 'scripts/data/maps/town_maps.gd'
CAM = (9.6, 11.2)          # world.gd CAM_OFFSET (up, south)
FEET, WAIST = 0.2, 0.7     # heights tested on each tile
WALK = set('.,:gf_=') | set('@v^<>$*123456789P')
ENTITY = set('@v^<>$*123456789P')
# field obstacles and story gates can be cleared, so what lies behind them counts as reachable
CLEARABLE = set('wjdoylim|xnk&')
BLD = 'CAGOKRYMUNEHZQXVIBJhDs'
SHOP = {'C': 'center', 'A': 'apothecary', 'G': 'beast_gear', 'O': 'trainer_gear', 'K': 'bookstore', 'R': 'arena',
        'Y': 'dojo', 'M': 'museum', 'U': 'music_hall', 'N': 'fortune', 'E': 'cafe', 'H': 'house', 'Z': 'home',
        'Q': 'temple', 'X': 'electronics', 'V': 'skytower', 'I': 'ceo_tower', 'B': 'cathedral', 'J': 'hideout',
        'h': 'decor', 'D': 'music_shop', 's': 'shack'}
# town -> building style (world_db.gd BIOMES)
STYLE = {'caccoon': 'coastal', 'tidewater': 'coastal', 'shellhaven': 'island', 'kelpwick': 'island',
         'dustwell': 'adobe', 'sundown': 'western', 'copperpick': 'mining', 'cogsworth': 'steampunk',
         'emberfall': 'hotspring', 'vinehollow': 'jungle', 'riverbend': 'town', 'gravenmoor': 'gothic'}
ROOF = {'coastal': 'gable', 'island': 'hip', 'adobe': 'flat', 'western': 'western', 'mining': 'shed',
        'steampunk': 'gable', 'hotspring': 'pagoda', 'jungle': 'hip', 'town': 'gable', 'gothic': 'steep'}
STILTS = {'island', 'jungle'}
# shops (voxel_buildings.gd SHOP_LOOKS): style -> (floors, roof)
COMMERCIAL = {'apothecary', 'beast_gear', 'trainer_gear', 'bookstore', 'cafe', 'music_shop', 'fortune'}
SHOP_LOOKS = {'coastal': (2, 'flat'), 'steampunk': (2, 'flat'), 'town': (2, 'gable'), 'gothic': (2, 'steep'),
              'western': (2, 'false_front'), 'adobe': (2, 'flat'), 'mining': (1, 'false_front'), 'hotspring': (2, 'pagoda'),
              'island': (1, 'hip'), 'jungle': (1, 'hip')}
DIRS = ((1, 0), (-1, 0), (0, 1), (0, -1))


def load_towns():
    """name -> (rows, heights rows or None)"""
    src = open(SRC, encoding='utf-8').read()
    towns = {}
    for m in re.finditer(r'^\t"(\w+)": \{\n(.*?)^\t\},', src, re.S | re.M):
        body = m.group(2)
        rows = re.search(r'^\t\t"rows": \[\n(.*?)\t\t\],', body, re.S | re.M)
        hts = re.search(r'^\t\t"heights": \[\n(.*?)\t\t\],', body, re.S | re.M)
        towns[m.group(1)] = (re.findall(r'"([^"]*)"', rows.group(1)),
                             re.findall(r'"([^"]*)"', hts.group(1)) if hts else None)
    return towns


RAMPS = {'^': (0, -1), 'v': (0, 1), '<': (-1, 0), '>': (1, 0)}


class Levels:
    """elevation.gd's levels and ramps: each tile's low and high edge heights and its ramp direction."""

    def __init__(self, w, h, hrows):
        self.w, self.h = w, h
        self.lo, self.hi, self.dir = {}, {}, {}

        def ch(x, y):
            if not (0 <= x < w and 0 <= y < h):
                return ''
            return hrows[y][x] if hrows and y < len(hrows) and x < len(hrows[y]) else '0'

        for y in range(h):
            for x in range(w):
                c = ch(x, y)
                if c.isdigit():
                    self.lo[x, y] = self.hi[x, y] = float(c)
        for y in range(h):
            for x in range(w):
                c = ch(x, y)
                if c not in RAMPS or (x, y) in self.dir:
                    continue
                r = RAMPS[c]
                s = (x, y)
                while ch(s[0] - r[0], s[1] - r[1]) == c:
                    s = (s[0] - r[0], s[1] - r[1])
                run = [s]
                while ch(run[-1][0] + r[0], run[-1][1] + r[1]) == c:
                    run.append((run[-1][0] + r[0], run[-1][1] + r[1]))
                a = ch(s[0] - r[0], s[1] - r[1])
                b = ch(run[-1][0] + r[0], run[-1][1] + r[1])
                a = float(a) if a.isdigit() else 0.0
                b = float(b) if b.isdigit() else a + 1.0
                for k, t in enumerate(run):
                    self.lo[t] = a + (b - a) * k / len(run)
                    self.hi[t] = a + (b - a) * (k + 1) / len(run)
                    self.dir[t] = r

    def _c(self, p):
        return (min(max(p[0], 0), self.w - 1), min(max(p[1], 0), self.h - 1))

    def surface(self, p):
        p = self._c(p)
        return (self.lo[p] + self.hi[p]) / 2

    def edge(self, p, d):
        p = self._c(p)
        r = self.dir.get(p)
        if r is None:
            return self.lo[p]
        if d == r:
            return self.hi[p]
        if d == (-r[0], -r[1]):
            return self.lo[p]
        return (self.lo[p] + self.hi[p]) / 2

    def joined(self, a, b):
        d = (b[0] - a[0], b[1] - a[1])
        ca, cb = self._c(a), self._c(b)
        ra, rb = self.dir.get(ca), self.dir.get(cb)

        def across(r):
            return r is not None and r != d and r != (-d[0], -d[1])

        if across(ra) or across(rb):
            return ra == rb and self.lo[ca] == self.lo[cb] and self.hi[ca] == self.hi[cb]
        return abs(self.edge(a, d) - self.edge(b, (-d[0], -d[1]))) < 0.01


def buildings(rows):
    h, w = len(rows), len(rows[0])
    seen, out = set(), []
    for y in range(h):
        for x in range(w):
            c = rows[y][x]
            if c in BLD and (x, y) not in seen:
                x1 = x
                while x1 + 1 < w and rows[y][x1 + 1] == c:
                    x1 += 1
                y1 = y
                while y1 + 1 < h and rows[y1 + 1][x] == c:
                    y1 += 1
                for yy in range(y, y1 + 1):
                    for xx in range(x, x1 + 1):
                        seen.add((xx, yy))
                out.append((c, x, y, x1 - x + 1, y1 - y + 1))
    return out


def roof_height(style, shop, w, d, lx, lz):
    """Height of a building's top at local position (lx, lz) from its centre, or 0 outside it."""
    ax, az = abs(lx), abs(lz)
    if shop == 'center':
        return 2.32 if ax <= (w - 0.2) / 2 and az <= (d - 0.3) / 2 else 0.0
    if shop == 'arena':
        if ax > w / 2 or az > d / 2:
            return 0.0
        if ax >= w / 2 - 0.75 and az >= d / 2 - 0.8:
            return 4.2
        return 3.3
    if shop == 'skytower':
        if ax <= (w - 0.8) / 2 and az <= (d - 0.8) / 2:
            return 8.6
        return 7.4 if ax <= (w + 0.4) / 2 and az <= (d + 0.4) / 2 else 0.0
    if shop == 'electronics':
        return 2.95 if ax <= w / 2 and az <= (d - 0.1) / 2 else 0.0
    if shop == 'ceo_tower':
        best = 0.0
        y = 0.0
        for tw, td, th in ((w - 0.2, d - 0.3, 4.0), (w - 1.2, d - 1.0, 4.0), (w - 2.0, d - 1.6, 3.5), (w - 2.8, d - 2.2, 2.5)):
            y += th
            if ax <= tw / 2 and az <= td / 2:
                best = y
        if ax >= w / 2 - 0.8 and ax <= w / 2 - 0.2 and abs(lz + d / 2 - 0.6) <= 0.3:
            best = max(best, 11.0)
        return best
    if shop == 'cathedral':
        best = 0.0
        if ax <= (w - 2.4) / 2 + 0.15 and abs(lz + 0.4) <= (d - 1.1 + 0.5) / 2:
            best = 5.0 + gable(d - 1.1, lz + 0.4, 0.42)
        for sx in (-1, 1):
            if abs(lx - sx * (w / 2 - 0.75)) <= 0.75 and abs(lz - (d / 2 - 0.9)) <= 0.75:
                best = max(best, 10.4)
        return best
    if shop in ('hideout', 'temple', 'decor'):
        return 3.0 if ax <= w / 2 and az <= d / 2 else 0.0
    lift = 0.45 if style in STILTS else 0.0
    if shop in COMMERCIAL:
        # a shop front, often with a flat above it
        floors, rt = SHOP_LOOKS[style]
        top = lift + 0.16 + 2.3 + (1.9 if floors == 2 else 0.0)
        if rt == 'flat':
            return top + 0.56 if ax <= (w + 0.1) / 2 and az <= (d + 0.1) / 2 else 0.0
        if rt == 'false_front':
            if ax > (w + 0.1) / 2 or az > d / 2:
                return 0.0
            return top + 1.3 if lz >= (d - 0.3) / 2 - 0.15 else top + 0.12
        if rt in ('gable', 'steep'):
            dj = d + 0.22
            if ax > (w + 0.3) / 2 or az > (dj + 0.5) / 2:
                return 0.0
            return top + gable(dj, lz, 0.22 if rt == 'gable' else 0.42)
    else:
        # an ordinary house
        top = lift + 0.16 + (2.6 if d >= 4 else 2.2)
        rt = ROOF[style]
        if rt == 'western' and shop in ('house', 'home'):
            # out west only shops wear false fronts
            rt = 'gable'
    if rt in ('gable', 'steep'):
        if ax > (w + 0.3) / 2 or az > (d + 0.5) / 2:
            return 0.0
        return top + gable(d, lz, 0.22 if rt == 'gable' else 0.42)
    if ax > w / 2 or az > d / 2:
        return 0.0
    if rt == 'hip' or rt == 'pagoda':
        layers = 6 if rt == 'hip' else 4
        best = top
        for i in range(layers):
            f = 1.0 - i / layers
            ex = 0.45 if rt == 'hip' else (0.6 if i == 0 else 0.3)
            if ax <= ((w + ex) * f + 0.2) / 2 and az <= ((d + ex) * f + 0.2) / 2:
                best = top + i * 0.24 + 0.21
        return best
    if rt == 'flat':
        return top + 0.45
    if rt == 'western':
        # a tall false front along the street side
        return top + 1.17 if lz >= d / 2 - 0.2 else top + 0.12
    return top + 0.45


def gable(d, lz, rise):
    steps = math.ceil(d / 2 / 0.25) + 1
    best = 0.0
    for i in range(steps):
        depth = d + 0.5 - i * 0.5
        if depth <= 0.1:
            break
        if abs(lz) <= depth / 2:
            best = i * rise + 0.17
    return best


def height_map(rows, style, lv):
    """Callable (wx, wz) -> height of whatever stands there, on its level."""
    h, w = len(rows), len(rows[0])
    cells = {}
    for c, x, y, bw, bd in buildings(rows):
        for yy in range(y - 1, y + bd + 1):
            for xx in range(x - 1, x + bw + 1):
                cells.setdefault((xx, yy), []).append(('b', SHOP[c], x + bw / 2, y + bd / 2, bw, bd, lv.surface((x, y))))
    for y in range(h):
        for x in range(w):
            c = rows[y][x]
            base = lv.surface((x, y))
            if c == 'T' and y < h - 3:
                for yy in (y - 1, y, y + 1):
                    for xx in (x - 1, x, x + 1):
                        cells.setdefault((xx, yy), []).append(('t', x + 0.5, y + 0.5, base))
            elif c == 'W':
                cells.setdefault((x, y), []).append(('r', 1.6 + base))
            elif c == '#':
                cells.setdefault((x, y), []).append(('r', 1.3 + base))
            elif c == 'S' and (x == 0 or rows[y][x - 1] != 'S') and (y == 0 or rows[y - 1][x] != 'S'):
                # the mascot statue: a low plinth with the beast standing in the middle
                for yy in (y, y + 1):
                    for xx in (x, x + 1):
                        cells.setdefault((xx, yy), []).append(('s', x + 1.0, y + 1.0, base))

    def at(wx, wz):
        best = 0.0
        for o in cells.get((math.floor(wx), math.floor(wz)), ()):
            if o[0] == 'b':
                rh = roof_height(style, o[1], o[4], o[5], wx - o[2], wz - o[3])
                if rh > 0:
                    best = max(best, rh + o[6])
            elif o[0] == 't':
                if abs(wx - o[1]) <= 0.8 and abs(wz - o[2]) <= 0.8:
                    best = max(best, 3.0 + o[3])
            elif o[0] == 's':
                dx, dz = abs(wx - o[1]), abs(wz - o[2])
                if dx <= 0.55 and dz <= 0.55:
                    best = max(best, 2.2 + o[3])
                elif dx <= 0.9 and dz <= 0.9:
                    best = max(best, 0.7 + o[3])
            else:
                best = max(best, o[1])
        return best
    return at


def hidden(at, x, y, ht, ground=0.0):
    """Is the point at height ht over tile (x, y) hidden from the camera centred on that tile? (ground: the tile's
    level, which the camera rises with)"""
    px, pz = x + 0.5, y + 0.5
    steps = 120
    for i in range(1, steps):
        s = i / steps
        wy = ht + (ground + CAM[0] - ht) * s
        wz = pz + CAM[1] * s
        if wy > 25:
            break
        if at(px, wz) > wy:
            return True
    return False


def check(name, rows, hrows=None):
    h, w = len(rows), len(rows[0])
    problems = []
    bad_rows = [i for i, r in enumerate(rows) if len(r) != w]
    if bad_rows:
        return ['rows of different widths: %s' % bad_rows]
    style = STYLE.get(name, 'town')
    lv = Levels(w, h, hrows)
    at = height_map(rows, style, lv)
    blind, half = [], []
    for y in range(h):
        for x in range(w):
            if rows[y][x] not in WALK:
                continue
            g = lv.surface((x, y))
            if hidden(at, x, y, WAIST + g, g):
                blind.append((x, y))
            elif hidden(at, x, y, FEET + g, g):
                half.append((x, y))
    if blind:
        problems.append('player hidden at %s' % blind)
    if half:
        problems.append('path hidden at %s' % half)
    # reachability: doors, exits and people
    walk = lambda p: 0 <= p[0] < w and 0 <= p[1] < h and (rows[p[1]][p[0]] in WALK or rows[p[1]][p[0]] in CLEARABLE)
    keys = []
    for c, x, y, bw, bd in buildings(rows):
        if c != 'h':
            keys.append(('door %s' % SHOP[c], (x + bw // 2, y + bd)))
    for y in range(h):
        for x in range(w):
            if rows[y][x] in ENTITY:
                keys.append(('entity %s' % rows[y][x], (x, y)))
            if (x in (0, w - 1) or y in (0, h - 1)) and rows[y][x] in WALK:
                keys.append(('exit', (x, y)))
    start = next((p for _, p in keys if walk(p)), None)
    seen = set()
    if start:
        seen.add(start)
        q = deque([start])
        while q:
            px, py = q.popleft()
            for dx, dy in DIRS:
                n = (px + dx, py + dy)
                if n not in seen and walk(n) and lv.joined((px, py), n):
                    seen.add(n)
                    q.append(n)
    for label, p in keys:
        if label.startswith('entity') and rows[p[1]][p[0]] in '@v^<>$*123456789':
            if not any((p[0] + dx, p[1] + dy) in seen and lv.joined((p[0] + dx, p[1] + dy), p)
                       for dx, dy in DIRS + ((0, 0),)):
                problems.append('%s at %s unreachable' % (label, p))
        elif p not in seen:
            problems.append('%s at %s unreachable' % (label, p))
    return problems


def main():
    towns = load_towns()
    names = sys.argv[1:] or list(towns)
    total = 0
    for n in names:
        probs = check(n, *towns[n])
        total += len(probs)
        print('%-11s %s' % (n, 'ok' if not probs else ''))
        for p in probs:
            print('    ' + p)
    print('problems:', total)


if __name__ == '__main__':
    main()
