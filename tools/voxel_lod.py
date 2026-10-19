"""Makes lighter versions of the most detailed voxel models: <name>_lo.obj at half the voxel resolution.

A few pack models are far finer than the rest (the palm tree is 63 voxels tall, the dead tree 66 wide), so they cost
6,000-16,000 triangles each, where the other trees cost 600-3,000. Rebuilt with voxels twice the size they match the
other trees' chunkiness and cost about a quarter as much. voxel_assets.gd loads the _lo version whenever one exists.

How: the model's visible faces are turned back into voxels (each face belongs to the voxel behind it), the inside is
filled, every 2x2x2 block becomes one voxel (in its most common surface colour) if at least two of its eight are
solid, and the result is greedy-meshed like tools/vox2obj.py does.

Run from the project root:  python tools/voxel_lod.py [name ...]   (default: the models listed in HEAVY)
"""
import collections
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import vox2obj  # noqa: E402

DIR = 'assets/voxel/nature'
HEAVY = ['palm', 'dead_tree', 'tree_big', 'tree_oak', 'tree_birch', 'tree_round_3',
         'mountain_0', 'mountain_1', 'mountain_2', 'mountain_3', 'mountain_4', 'mountain_5', 'mountain_6', 'mountain_7',
         'mountain_8', 'mountain_9']
FACTOR = 2
KEEP = 2      # voxels out of FACTOR^3 that make a block solid

EPS = 1e-4


def _parse(path):
    vs, vts, vns, faces = [], [], [], []
    for line in open(path, encoding='utf-8', errors='replace'):
        t = line.split()
        if not t:
            continue
        if t[0] == 'v':
            vs.append(tuple(float(x) for x in t[1:4]))
        elif t[0] == 'vt':
            vts.append(tuple(float(x) for x in t[1:3]))
        elif t[0] == 'vn':
            vns.append(tuple(float(x) for x in t[1:4]))
        elif t[0] == 'f':
            corners = []
            for c in t[1:]:
                parts = c.split('/')
                corners.append((int(parts[0]) - 1, int(parts[1]) - 1 if len(parts) > 1 and parts[1] else -1,
                                int(parts[2]) - 1 if len(parts) > 2 and parts[2] else -1))
            faces.append(corners)
    return vs, vts, vns, faces


def _sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _inside(poly, x, y):
    """Point in a convex polygon (edges count as inside)."""
    sgn = 0
    for i in range(len(poly)):
        (x1, y1), (x2, y2) = poly[i], poly[(i + 1) % len(poly)]
        c = (x2 - x1) * (y - y1) - (y2 - y1) * (x - x1)
        if abs(c) < 1e-9:
            continue
        s = 1 if c > 0 else -1
        if sgn == 0:
            sgn = s
        elif s != sgn:
            return False
    return True


def voxels_of(path):
    vs, vts, vns, faces = _parse(path)
    unit = None
    for f in faces:
        for i in range(len(f)):
            p, q = vs[f[i][0]], vs[f[(i + 1) % len(f)][0]]
            for k in range(3):
                d = abs(p[k] - q[k])
                if d > EPS and (unit is None or d < unit):
                    unit = d
    lo = [min(v[k] for v in vs) for k in range(3)]
    g = lambda x, k: round((x - lo[k]) / unit)
    # which way the export winds front faces
    ccw = 0
    for f in faces[:200]:
        pts = [vs[c[0]] for c in f]
        n = _cross(_sub(pts[1], pts[0]), _sub(pts[2], pts[0]))
        if f[0][2] >= 0:
            nn = vns[f[0][2]]
            ccw += 1 if sum(a * b for a, b in zip(n, nn)) > 0 else -1
    surface = {}
    for f in faces:
        pts = [vs[c[0]] for c in f]
        n = _cross(_sub(pts[1], pts[0]), _sub(pts[2], pts[0]))
        if f[0][2] >= 0 and vns[f[0][2]] != (0.0, 0.0, 0.0):
            n = vns[f[0][2]] if ccw >= 0 else tuple(-x for x in vns[f[0][2]])
        axis = max(range(3), key=lambda k: abs(n[k]))
        if abs(n[axis]) < EPS:
            continue
        sign = 1 if n[axis] > 0 else -1
        u, v = (axis + 1) % 3, (axis + 2) % 3
        poly = [(g(p[u], u), g(p[v], v)) for p in pts]
        layer = g(pts[0][axis], axis)
        for a in range(min(p[0] for p in poly), max(p[0] for p in poly)):
            for b in range(min(p[1] for p in poly), max(p[1] for p in poly)):
                if _inside(poly, a + 0.5, b + 0.5):
                    cell = [0, 0, 0]
                    cell[axis] = layer - 1 if sign > 0 else layer
                    cell[u], cell[v] = a, b
                    surface[tuple(cell)] = f[0][1]
    return surface, unit, lo, vts


def fill_inside(surface):
    """Everything the outside air can't reach is solid."""
    xs, ys, zs = zip(*surface.keys())
    lo = (min(xs) - 1, min(ys) - 1, min(zs) - 1)
    hi = (max(xs) + 1, max(ys) + 1, max(zs) + 1)
    air = {lo}
    todo = [lo]
    while todo:
        x, y, z = todo.pop()
        for d in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)):
            q = (x + d[0], y + d[1], z + d[2])
            if q in air or q in surface or not all(lo[k] <= q[k] <= hi[k] for k in range(3)):
                continue
            air.add(q)
            todo.append(q)
    solid = set(surface)
    for x in range(lo[0], hi[0] + 1):
        for y in range(lo[1], hi[1] + 1):
            for z in range(lo[2], hi[2] + 1):
                if (x, y, z) not in air:
                    solid.add((x, y, z))
    return solid


def downsample(surface, solid):
    blocks = collections.defaultdict(list)
    for p in solid:
        blocks[tuple(c // FACTOR for c in p)].append(p)
    out = {}
    for b, ps in blocks.items():
        if len(ps) < KEEP:
            continue
        cols = collections.Counter(surface[p] for p in ps if p in surface)
        if cols:
            out[b] = cols.most_common(1)[0][0]
        else:
            out[b] = None
    # blocks made only of inside voxels take a neighbour's colour (they're hidden anyway)
    for b in [k for k, c in out.items() if c is None]:
        out[b] = next((out[n] for n in ((b[0] + 1, b[1], b[2]), (b[0] - 1, b[1], b[2]), (b[0], b[1] + 1, b[2]),
                                         (b[0], b[1] - 1, b[2]), (b[0], b[1], b[2] + 1), (b[0], b[1], b[2] - 1))
                       if out.get(n) is not None), next(c for c in out.values() if c is not None))
    return out


def write(name, blocks, unit, lo, vts):
    quads = vox2obj.greedy_quads(blocks)
    size = unit * FACTOR
    lines = ['# half-resolution version of %s.obj, made by tools/voxel_lod.py' % name, 'mtllib %s.mtl' % name, 'o %s_lo' % name, 'usemtl palette']
    vl, tl, nl, fl = [], [], [], []
    normals, uvs = {}, {}
    vi = 0
    for (corner, du, dv, nrm, c) in quads:
        pts = [corner, [corner[i] + du[i] for i in range(3)], [corner[i] + du[i] + dv[i] for i in range(3)],
               [corner[i] + dv[i] for i in range(3)]]
        world = [tuple(lo[k] + p[k] * size for k in range(3)) for p in pts]
        n = tuple(nrm)
        if n not in normals:
            normals[n] = len(normals) + 1
            nl.append('vn %d %d %d' % n)
        if c not in uvs:
            uvs[c] = len(uvs) + 1
            tl.append('vt %.6f %.6f' % vts[c])
        for p in world:
            vl.append('v %.6f %.6f %.6f' % p)
        e1 = _sub(world[1], world[0])
        e2 = _sub(world[2], world[0])
        cr = _cross(e1, e2)
        dot = sum(a * b for a, b in zip(cr, n))
        order = (vi + 1, vi + 2, vi + 3, vi + 4) if dot > 0 else (vi + 1, vi + 4, vi + 3, vi + 2)
        fl.append('f ' + ' '.join('%d/%d/%d' % (k, uvs[c], normals[n]) for k in order))
        vi += 4
    open(os.path.join(DIR, name + '_lo.obj'), 'w').write('\n'.join(lines + vl + tl + nl + fl) + '\n')
    return len(quads) * 2


def make(names):
    for name in names:
        path = os.path.join(DIR, name + '.obj')
        if not os.path.exists(path):
            continue
        before = sum(len(f) - 2 for f in _parse(path)[3])
        surface, unit, lo, vts = voxels_of(path)
        blocks = downsample(surface, fill_inside(surface))
        tris = write(name, blocks, unit, lo, vts)
        print('%-14s %6d -> %5d triangles' % (name, before, tris))


if __name__ == '__main__':
    make(sys.argv[1:] or HEAVY)
