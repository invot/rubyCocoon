"""Bakes the new beast models (13 evolution lines of 3, from the "new beasts" folder) for the game.

    python tools/new_beasts/bake.py "path/to/new beasts" [--debug out_dir] [form ...]

For each form in forms.json: loads its .obj, cuts its figure out of the files that hold a whole line side by side,
turns it to the game's beast space (facing +x, standing on y = 0, centred on x/z), scales it so its larger measure
(its height, or 0.62 of its length) is 1 unit, and drops the stray long triangles the source meshes carry between
their parts. Each face is then labelled a part of the body (label(), with forms.json's corrections) and each part
gets its joint (rig()). Writes tools/new_beasts/out/<form>.json, which tools/import_new_beasts.gd turns into
assets/beasts/<form>.res. With --debug, also draws each form with its parts coloured (out_dir/<form>.png).
"""
import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
# the parts a beast is made of: they move on their own when it's animated, and are what merging mixes
# (deco: what isn't the beast's own but goes with it, as the dirt round a worm in its hole: it stays still)
PARTS = ['body', 'head', 'arm_l', 'arm_r', 'wing_l', 'wing_r', 'leg_fl', 'leg_fr', 'leg_bl', 'leg_br', 'tail', 'horn', 'eye',
         'deco']


def load_obj(path):
    verts, norms, faces = [], [], []
    vn_of = {}
    for line in open(path, errors='replace'):
        if line.startswith('v '):
            verts.append([float(x) for x in line.split()[1:4]])
        elif line.startswith('vn '):
            norms.append([float(x) for x in line.split()[1:4]])
        elif line.startswith('f '):
            corners = [t.split('/') for t in line.split()[1:]]
            idx = [int(c[0]) - 1 for c in corners]
            for c in corners:
                if len(c) > 2 and c[2]:
                    vn_of[int(c[0]) - 1] = int(c[2]) - 1
            for i in range(1, len(idx) - 1):
                faces.append([idx[0], idx[i], idx[i + 1]])
    v = np.array(verts, float)
    n = np.zeros_like(v)
    if norms:
        nn = np.array(norms, float)
        for vi, ni in vn_of.items():
            n[vi] = nn[ni]
    return v, n, np.array(faces, int)


def orient(v, up, yaw):
    """To beast space: facing +x, y up, z to the side. up "z": the source stands on z and faces -y; "y": it stands
    on y and faces +z. yaw: degrees more to turn it (about y)."""
    if up == 'z':
        v = np.stack([-v[:, 1], v[:, 2], -v[:, 0]], 1)
    else:
        v = np.stack([v[:, 2], v[:, 1], -v[:, 0]], 1)
    if yaw:
        a = math.radians(yaw)
        c, s = math.cos(a), math.sin(a)
        v = np.stack([v[:, 0] * c + v[:, 2] * s, v[:, 1], -v[:, 0] * s + v[:, 2] * c], 1)
    return v


def long_edges(v, f, k=5.0):
    """The stray triangles: any with an edge over k times the median edge."""
    t = v[f]
    e = np.max([np.linalg.norm(t[:, a] - t[:, b], axis=1) for a, b in [(0, 1), (1, 2), (2, 0)]], axis=0)
    return e > np.median(e) * k


def split_line(v, f, n, which):
    """The faces of figure `which` (0 = the smallest) of the n standing side by side: after orienting they stand
    along z, the smallest at +z. Cut at the widest empty gaps between them."""
    f = f[~long_edges(v, f)]
    zs = np.sort(-v[np.unique(f), 2])
    gaps = np.diff(zs)
    big = np.argsort(gaps)[-(n - 1):]
    cuts = np.sort(zs[big] + gaps[big] / 2)
    cent = -v[f].mean(1)[:, 2]
    lo = cuts[which - 1] if which > 0 else -1e9
    hi = cuts[which] if which < n - 1 else 1e9
    return f[(cent > lo) & (cent < hi)]


def compact(v, n, f):
    used = np.unique(f)
    remap = -np.ones(len(v), int)
    remap[used] = np.arange(len(used))
    return v[used], n[used], remap[f]


def normalise(v):
    lo, hi = v.min(0), v.max(0)
    v = v - np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2])
    size = max(hi[1] - lo[1], 0.62 * max(hi[0] - lo[0], hi[2] - lo[2]))
    return v / size


def pieces(v, f):
    """Each face's piece (connected through vertices at the same place), numbered biggest first."""
    key = np.round(v / 1e-4).astype(np.int64)
    _, weld = np.unique(key, axis=0, return_inverse=True)
    weld = weld.ravel()
    parent = np.arange(weld.max() + 1)

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    for t in weld[f]:
        a = find(t[0])
        parent[find(t[1])] = a
        parent[find(t[2])] = a
    lab = np.array([find(weld[t[0]]) for t in f])
    _, inv, cnt = np.unique(lab, return_inverse=True, return_counts=True)
    order = np.argsort(-cnt)
    rank = np.empty_like(order)
    rank[order] = np.arange(len(order))
    return rank[inv.ravel()]


def stats(v, f, lab):
    out = []
    for k in range(lab.max() + 1):
        fv = v[np.unique(f[lab == k])]
        out.append({'n': int((lab == k).sum()), 'c': fv.mean(0), 'lo': fv.min(0), 'hi': fv.max(0)})
    return out


def weld(v):
    """Each vertex's welded index (vertices at the same place share one)."""
    key = np.round(v / 1e-4).astype(np.int64)
    _, w = np.unique(key, axis=0, return_inverse=True)
    return w.ravel()


def islands(f, w, sel):
    """Connected groups of the selected faces (through welded vertices): a label per face, -1 if not selected."""
    parent = np.arange(w.max() + 1)

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    for t in w[f[sel]]:
        a = find(t[0])
        parent[find(t[1])] = a
        parent[find(t[2])] = a
    out = -np.ones(len(f), int)
    roots = {}
    for i in np.nonzero(sel)[0]:
        r = find(w[f[i][0]])
        out[i] = roots.setdefault(r, len(roots))
    return out


def label(v, f, lab, st, spec):
    """Each face's part. The body's core (the "core" ellipsoid of forms.json, [x, y, z, rx, ry, rz], or a guess from
    the most central big piece) is the body; everything sticking out of it falls apart into islands, each classed by
    where it sticks out: down to the ground a leg, sideways an arm (or a wing, on a flyer), backwards a tail, up and
    to the front the head, and small ones horns (spikes, ears, beaks). That first guess is then corrected by place:
    forms.json's "regions" ([{part, x>, x<, y>, y<, z>, z<, |z|>, |z|<, r>, r<, from}]; r: from the upright axis), in
    order, each give the faces in their box to a part; they leave the horns guessed alone unless "from" names them ("from": only faces first
    guessed as one of these parts)."""
    kind = spec.get('body', 'quad')
    h = v[:, 1].max()
    big = [k for k in range(len(st)) if st[k]['n'] >= 0.05 * len(f)]

    def central(k):
        c = st[k]['c']
        return abs(c[2]) * 2.0 + abs(c[1] - h * 0.45) + abs(c[0]) * 0.5 - math.log(st[k]['n']) * 0.05
    body = min(big, key=central)
    if 'core' in spec:
        c0, r0 = np.array(spec['core'][:3]), np.array(spec['core'][3:])
    else:
        b = st[body]
        c0, r0 = (b['lo'] + b['hi']) / 2, (b['hi'] - b['lo']) * 0.45
    fc = v[f].mean(1)
    core = (lab == body) & (np.sum(((fc - c0) / r0) ** 2, 1) <= 1.0)
    if core.sum() < 0.05 * len(f):
        # (a core that misses the body piece: the whole piece is the body)
        core = lab == body
    w = weld(v)
    isl = islands(f, w, ~core)
    part = np.zeros(len(f), int)
    names = {}
    for k in range(isl.max() + 1):
        sel = isl == k
        n = int(sel.sum())
        iv = v[np.unique(f[sel])]
        c, lo = iv.mean(0), iv.min(0)
        d = c - c0
        side = 'l' if c[2] < 0 else 'r'
        if n < spec.get('horn_size', 0.03) * len(f):
            p = 'horn'
        elif lo[1] < h * 0.08 and c[1] < c0[1]:
            p = 'leg_' + ('f' if c[0] > c0[0] or kind != 'quad' else 'b') + side
        elif d[1] > abs(d[2]) and d[1] > -d[0] and c[1] > c0[1]:
            p = 'head'
        elif -d[0] > abs(d[2]) and -d[0] > abs(d[1]):
            p = 'tail'
        elif kind == 'flyer' and (iv[:, 2].max() - iv[:, 2].min()) > r0[2]:
            p = 'wing_' + side
        else:
            p = 'arm_' + side
        names[k] = p
        part[sel] = PARTS.index(p)
    guess = part.copy()
    horn = PARTS.index('horn')
    for r in spec.get('regions', []):
        if 'from' in r:
            sel = np.isin(guess, [PARTS.index(p) for p in r['from']])
        else:
            sel = guess != horn
        for key, val in r.items():
            if key in ('part', 'from'):
                continue
            if key[0] == 'r':
                q = np.hypot(fc[:, 0], fc[:, 2])
            else:
                ax = {'x': 0, 'y': 1, 'z': 2}[key.strip('|<>')]
                q = np.abs(fc[:, ax]) if key.startswith('|') else fc[:, ax]
            sel &= (q > val) if key.endswith('>') else (q < val)
        part[sel] = PARTS.index(r['part'])
    return part, isl, names


def nearest(a, b):
    """The closest pair between point sets a and b: (distance, point of a, point of b); inf if either is empty."""
    if len(a) == 0 or len(b) == 0:
        return math.inf, None, None
    a, b = a[::max(1, len(a) // 400)], b[::max(1, len(b) // 400)]
    dd = np.linalg.norm(a[:, None, :] - b[None, :, :], axis=2)
    i, j = np.unravel_index(np.argmin(dd), dd.shape)
    return dd[i, j], a[i], b[j]


def split_seams(v, n, f, part, cut=0.25):
    """Frees a limb where the source welds it to the body (or another part) away from where it joins: an arm
    hanging against the side, a tail lying along the back. Those shared vertices get a copy of their own for the
    limb's faces, so the limb can swing away there instead of stretching the faces between. (Near its joint, the
    first `cut` of its length, it stays welded and bends.)"""
    body = np.unique(f[part == 0])
    body_c = v[body].mean(0) if len(body) else v.mean(0)
    v, n, f = v.copy(), n.copy(), f.copy()
    for p in range(len(PARTS)):
        if PARTS[p].split('_')[0] not in ('arm', 'wing', 'leg', 'tail'):
            continue
        mine = part == p
        pv = np.unique(f[mine])
        if len(pv) < 9:
            continue
        others = np.unique(f[~mine & (part != PARTS.index('horn')) & (part != PARTS.index('eye'))])
        shared = np.intersect1d(pv, others)
        if not len(shared):
            continue
        near, ax, length = limb_axis(v[pv], body_c)
        far = shared[(v[shared] - near) @ ax / max(length, 1e-6) > cut]
        if not len(far):
            continue
        copy = {int(vi): len(v) + i for i, vi in enumerate(far)}
        v = np.concatenate([v, v[far]])
        n = np.concatenate([n, n[far]])
        sub = f[mine]
        for vi, ci in copy.items():
            sub[sub == vi] = ci
        f[mine] = sub
    return v, n, f


def limb_axis(pts, toward):
    """A limb's length: its main axis, from the end nearest `toward` (where it joins) to the far end: (the near end,
    the axis outwards, the length)."""
    c = pts.mean(0)
    ax = np.linalg.svd(pts - c, full_matrices=False)[2][0]
    t = (pts - c) @ ax
    a, b = c + ax * np.percentile(t, 3), c + ax * np.percentile(t, 97)
    if np.linalg.norm(b - toward) < np.linalg.norm(a - toward):
        a, b, ax = b, a, -ax
    return a, ax, np.linalg.norm(b - a)


def rig(v, f, part):
    """Each part's joint (where it meets its parent: the body, or the head for horns and eyes on it), each vertex's
    part and how much it follows it (1 away from the joint, easing to 0 where it grows out of its parent, so a limb
    cut out of one surface bends there rather than tears; a separate shell follows its part fully), and the part each
    vertex is fixed to (its own, but for horns and eyes)."""
    w = weld(v)
    # a vertex on the seam between parts belongs to the one nearest the body: horns, then limbs, then the head
    order = sorted(set(part.tolist()), key=lambda p: (0 if PARTS[p] in ('horn', 'deco') else 2 if PARTS[p] == 'head' else 3 if PARTS[p] == 'body' else 1))
    vpart = np.zeros(len(v), int)
    for p in order:
        vpart[f[part == p].ravel()] = p
    on = {}
    for t, p in zip(f, part):
        for vi in t:
            on.setdefault(w[vi], set()).add(int(p))
    joints, parents = {}, {}
    weight = np.ones(len(v))
    body_c = v[vpart == 0].mean(0) if (vpart == 0).any() else v.mean(0)
    head_i = PARTS.index('head')
    for p in order:
        if PARTS[p] == 'body':
            continue
        pv = np.nonzero(vpart == p)[0]
        if len(pv) == 0:
            pv = np.unique(f[part == p])
        parent = 0
        if PARTS[p] in ('horn', 'eye'):
            dh = nearest(v[pv], v[vpart == head_i])[0]
            db = nearest(v[pv], v[vpart == 0])[0]
            parent = head_i if dh < db else 0
        # where it grows out of another part: the vertices it shares with it
        border = np.unique(f[part == p])
        border = [vi for vi in border if len(on[w[vi]]) > 1]
        if border:
            joint = v[border].mean(0)
            d = np.min(np.linalg.norm(v[pv][:, None, :] - v[border][None, ::max(1, len(border) // 200), :], axis=2), 1)
            size = np.ptp(v[pv], 0).max()
            weight[pv] = np.clip(d / max(size * 0.25, 1e-3), 0.0, 1.0) ** 0.7 if PARTS[p] != 'deco' else 1.0
        else:
            # a separate shell: its joint is its point nearest the parent
            _, a, b = nearest(v[pv], v[vpart == parent])
            if a is None:
                _, a, b = nearest(v[pv], v[vpart != p])
            joint = (a + b) / 2 if a is not None else v[pv].mean(0)
        if PARTS[p].split('_')[0] in ('arm', 'wing', 'leg', 'tail') and len(pv) > 8:
            # a limb turns at the end of its length nearest the body (a shoulder, a hip, the root of a tail or a
            # wing), not where it happens to touch the body (an elbow against its side, a shell sunk into it), and
            # follows its own bone more the further out along it
            near, ax, length = limb_axis(v[pv], body_c)
            along = (joint - near) @ ax / max(length, 1e-6)
            if not border or along > 0.12:
                joint = near + ax * length * 0.06
            t = (v[pv] - joint) @ ax / max(length, 1e-6)
            weight[pv] = np.clip(t / 0.2, 0.0, 1.0) ** 0.7 if border else 1.0
        joints[PARTS[p]] = np.round(joint, 4).tolist() if PARTS[p] not in joints else joints[PARTS[p]]
        parents[PARTS[p]] = PARTS[parent]
    # horns and eyes don't move by themselves: each piece of them is fixed to the part it's on (a spike on the back
    # to the body, one on a claw to its arm), which is also what it goes with when merging moves that part
    attach = vpart.copy()
    others = [q for q in order if PARTS[q] not in ('horn', 'eye', 'deco')]
    for p in (PARTS.index('horn'), PARTS.index('eye')):
        isl = islands(f, w, part == p)
        for k in range(isl.max() + 1):
            fv = np.unique(f[isl == k])
            iv = fv[vpart[fv] == p]
            # the part it grows out of (whose vertices its faces share), else the nearest
            grown = [q for q in vpart[fv].tolist() if q in others]
            if len(iv) and grown:
                attach[iv] = max(set(grown), key=grown.count)
                weight[iv] = 1.0
            elif len(iv) and others:
                attach[iv] = min(others, key=lambda q: nearest(v[iv], v[vpart == q])[0])
                weight[iv] = 1.0
    return vpart, attach, weight, joints, parents


def smooth_normals(v, f, n, vpart, iters=14):
    """The normals blurred over each part's surface (welded, neighbour to neighbour, `iters` times), so what's
    painted by them (the belly patch) has smooth edges rather than following every facet."""
    w = weld(v)
    nw = np.zeros((w.max() + 1, 3))
    np.add.at(nw, w, n)
    pw = np.zeros(w.max() + 1, int)
    pw[w] = vpart
    edges = np.concatenate([f[:, [0, 1]], f[:, [1, 2]], f[:, [2, 0]]])
    a, b = w[edges[:, 0]], w[edges[:, 1]]
    same = pw[a] == pw[b]
    a, b = a[same], b[same]
    for _ in range(iters):
        acc = nw.copy()
        np.add.at(acc, a, nw[b])
        np.add.at(acc, b, nw[a])
        nw = acc / np.maximum(np.linalg.norm(acc, axis=1, keepdims=True), 1e-9)
    return nw[w]


def shading(v, f, n, vpart, joints):
    """What the toon shader paints by, per vertex: tip (0 at its part's joint to 1 at the far end: hands, feet,
    claws and the tips of spikes take their own colour from some way along), belly (how much it faces forward and
    down, by its smoothed normal: a belly patch) and pattern (around its part's upright axis, 0..1, and its height:
    stripes and bands). An eye's tip is how much it looks forward instead (its pupil)."""
    tip = np.zeros(len(v))
    pat = np.zeros((len(v), 2))
    for p in set(vpart.tolist()):
        sel = vpart == p
        pv = v[sel]
        c = pv.mean(0)
        pat[sel, 0] = (np.arctan2(pv[:, 2] - c[2], pv[:, 0] - c[0]) / (2 * math.pi)) % 1.0
        pat[sel, 1] = pv[:, 1]
        name = PARTS[p]
        if name == 'eye':
            tip[sel] = np.clip(n[sel][:, 0], 0.0, 1.0)
        elif name in joints:
            d = np.linalg.norm(pv - np.array(joints[name]), axis=1)
            tip[sel] = d / max(d.max(), 1e-6)
    fwd = np.array([1.0, -0.55, 0.0])
    fwd /= np.linalg.norm(fwd)
    belly = np.clip(smooth_normals(v, f, n, vpart) @ fwd * 0.5 + 0.5, 0.0, 1.0)
    return tip, belly, pat


def bake(src, name, spec, debug_dir=None):
    v, n, f = load_obj(os.path.join(src, spec['src']))
    v = orient(v, spec.get('up', 'z'), spec.get('yaw', 0))
    n = orient(n, spec.get('up', 'z'), spec.get('yaw', 0))
    if 'of' in spec:
        f = split_line(v, f, spec['of'], spec['which'])
    f = f[~long_edges(v, f)]
    v, n, f = compact(v, n, f)
    v = normalise(v)
    if 'ground' in spec:
        # (one standing in a hole: what's below the ground goes)
        f = f[v[f].mean(1)[:, 1] > spec['ground']]
        v, n, f = compact(v, n, f)
    lab = pieces(v, f)
    st = stats(v, f, lab)
    part, isl, names = label(v, f, lab, st, spec)
    v, n, f = split_seams(v, n, f, part)
    vpart, attach, weight, joints, parents = rig(v, f, part)
    if 'ground' in spec:
        lo = np.array([0.0, spec['ground'], 0.0])
        ext = np.ptp(v, 0)
        size = 1.0 / max(v[:, 1].max() - lo[1], 0.62 * max(ext[0], ext[2]))
        v = (v - lo) * size
        joints = {k: np.round((np.array(j) - lo) * size, 4).tolist() for k, j in joints.items()}
    tip, belly, pat = shading(v, f, n, vpart, joints)
    out = {'name': name, 'verts': np.round(v, 5).ravel().tolist(), 'normals': np.round(n, 4).ravel().tolist(),
           'faces': f.ravel().tolist(), 'vpart': vpart.tolist(), 'attach': attach.tolist(), 'weight': np.round(weight, 3).tolist(),
           'tip': np.round(tip, 3).tolist(), 'belly': np.round(belly, 3).tolist(), 'pattern': np.round(pat, 4).ravel().tolist(),
           'parts': PARTS, 'joints': joints, 'parents': parents, 'body': spec.get('body', 'quad')}
    json.dump(out, open(os.path.join(HERE, 'out', name + '.json'), 'w'))
    print('%-12s faces %5d  islands %2d  %s' % (name, len(f), isl.max() + 1, ' '.join('%d:%s' % (k, names[k]) for k in sorted(names))))
    if debug_dir:
        import debug_draw
        debug_draw.form(v, f, part, isl, PARTS, os.path.join(debug_dir, name + '.png'), name, joints)


def main():
    args = [a for a in sys.argv[1:]]
    debug_dir = None
    if '--debug' in args:
        i = args.index('--debug')
        debug_dir = args[i + 1]
        del args[i:i + 2]
        os.makedirs(debug_dir, exist_ok=True)
    src, only = args[0], args[1:]
    forms = json.load(open(os.path.join(HERE, 'forms.json')))
    os.makedirs(os.path.join(HERE, 'out'), exist_ok=True)
    for name, spec in forms.items():
        if not name.startswith('_') and (not only or name in only):
            bake(src, name, spec, debug_dir)


if __name__ == '__main__':
    sys.path.insert(0, HERE)
    main()
