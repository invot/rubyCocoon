"""Shrub, hedge and flower artwork candidate (preproduction for runbook 028; NOT integrated, 028 NOT complete).

    python tools/local_resource.py -- "C:/Program Files/Blender Foundation/Blender 4.2/blender.exe" -b \
        --factory-startup -P tools/blender/art_candidates/shrubs/shrubs_candidate.py -- --rev rev_001 [--no-render]

Then: python tools/blender/art_candidates/shrubs/make_sheets.py rev_001
      python tools/blender/art_candidates/shrubs/finalize.py rev_001      (writes READY.json last, atomically)

Writes only into build/art_candidates/shrubs/<rev>/ and refuses a revision that already has READY.json.

Visual grammar: the approved broadleaf rev_003 (pillowy painted domes with scalloped hems, soft painted marks, no
individual-leaf pattern). Everything here is built procedurally by this script; no third-party geometry or texture
goes into the delivered files. Broadleaf rev_003 glTFs are imported READ-ONLY for the side-by-side previews only.

Construction: every mass is a closed lathe ("puff"): a dome over a slight belly, a scalloped skirt whose rounded
tongues hang to the hem, and a tucked-in underside, so all materials are opaque and single-sided. Bushes and the
hedge are fused puffs; flowers are petal masses (lens-shaped radial-scalloped heads, tulip cups, pom heads) on
tapered stems over a small scalloped leaf mound. One painted 1024 atlas (numpy, deterministic: soft gradients and a
few faint scallop marks, no noise) is shared by the whole kit. Two LODs per model. Units: 1 unit = 1 tile, hero 1.44.
Blender Z-up; glTF export Y-up. Textures are NOT smoothed (the shared smoothing pass runs once at integration).
"""
import bpy, bmesh, json, sys, math, pathlib, random
import numpy as np
from mathutils import Vector, Matrix

ROOT = pathlib.Path(__file__).resolve().parents[4]
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=None):
    return ARGS[ARGS.index(name) + 1] if name in ARGS else default


REV = arg("--rev", "rev_001")
OUT = ROOT / "build/art_candidates/shrubs" / REV
TREES = ROOT / "build/art_candidates/broadleaf/rev_003/mesh"  # approved broadleaf, read-only
RENDER = "--no-render" not in ARGS
if (OUT / "READY.json").exists():
    raise SystemExit(f"{OUT} is published (READY.json); corrections go in a new revision")
for sub in ("mesh/textures", "source", "renders", "previews"):
    (OUT / sub).mkdir(parents=True, exist_ok=True)

HERO_H = 1.44
TEX = 1024
CELL = 256
GUT = 14  # texels of gutter inside each 256 cell (mipmaps never reach the neighbour)

# ---------------------------------------------------------------------------------------------------------------
# Palettes (sRGB). Leaf A/B/C are the approved broadleaf palettes (rev_001 -> rev_003), so bushes sit with the trees.
LEAF = {
    "leaf_A": dict(gap=(60, 104, 62), shadow=(66, 112, 64), mid=(92, 144, 70), light=(130, 176, 86), accent=(156, 186, 94)),
    "leaf_B": dict(gap=(80, 118, 60), shadow=(86, 126, 60), mid=(120, 160, 74), light=(160, 192, 98), accent=(184, 202, 112)),
    "leaf_C": dict(gap=(46, 90, 66), shadow=(52, 98, 68), mid=(72, 128, 80), light=(106, 158, 94), accent=(132, 172, 102)),
    # hedge: a clipped, slightly deeper and cooler green between A and C
    "leaf_H": dict(gap=(48, 94, 60), shadow=(56, 104, 62), mid=(80, 136, 74), light=(116, 166, 88), accent=(140, 178, 98)),
}
# petal ramps: base (where the petal meets the head) -> body -> tip
PETAL = {
    "blossom": dict(base=(206, 112, 140), body=(238, 156, 176), tip=(252, 214, 222)),
    "daisy":   dict(base=(214, 204, 192), body=(244, 240, 230), tip=(252, 250, 244)),
    "coral":   dict(base=(178, 64, 64), body=(226, 98, 82), tip=(248, 150, 120)),
    "butter":  dict(base=(204, 140, 44), body=(242, 188, 62), tip=(252, 222, 128)),
    "lilac":   dict(base=(122, 94, 166), body=(170, 136, 210), tip=(210, 188, 236)),
    "centre":  dict(base=(206, 140, 46), body=(238, 186, 64), tip=(250, 214, 104)),
    "stem":    dict(base=(70, 112, 58), body=(92, 142, 70), tip=(122, 166, 84)),
    # the pickable fruit: a deep warm red underneath ripening to sunny orange-gold on top
    "fruit":   dict(base=(184, 58, 50), body=(236, 112, 58), tip=(252, 184, 88)),
}
# atlas cells (col, row) with row 0 at the BOTTOM of the image (Blender UV origin)
CELLS = {"leaf_A": (0, 3), "leaf_B": (1, 3), "leaf_C": (2, 3), "leaf_H": (3, 3),
         "blossom": (0, 2), "daisy": (1, 2), "coral": (2, 2), "butter": (3, 2),
         "lilac": (0, 1), "centre": (1, 1), "stem": (2, 1), "fruit": (3, 1)}


def _c(t):
    return np.array(t, np.float32) / 255.0


def _ss(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def paint_foliage(pal, seed):
    """One 256 cell, u periodic (around a puff), v = 0 at the hem/underside, 1 at the dome top."""
    n = CELL - 2 * GUT
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    u, v = (x + 0.5) / n, (y + 0.5) / n
    sh, md, lt, ac, gp = (_c(pal[k]) for k in ("shadow", "mid", "light", "accent", "gap"))
    # body gradient: gap at the hem edge, shadow on the skirt, mid on the belly, light toward the top
    t1 = _ss(0.0, 0.16, v)[..., None]
    t2 = _ss(0.14, 0.55, v)[..., None]
    t3 = _ss(0.5, 0.95, v)[..., None]
    col = gp * (1 - t1) + sh * t1
    col = col * (1 - t2) + md * t2
    col = col * (1 - t3) + lt * t3
    # soft sky highlight on the upper shoulder
    hl = np.exp(-((v - 0.8) / 0.11) ** 2)[..., None] * 0.28
    col = col * (1 - hl) + ac * hl
    # a few faint painted scallop marks (shingle hems echoing the skirt), in staggered rows; periodic in u
    rng = random.Random(seed)
    for row, (vy, count, a, tone) in enumerate([(0.36, 5, 0.42, sh), (0.56, 4, 0.34, sh), (0.74, 3, 0.22, md)]):
        off = rng.uniform(0, 1)
        for k in range(count):
            cx = (k + off + 0.5 * (row % 2)) / count
            dx = ((u - cx + 0.5) % 1.0) - 0.5
            w = 0.36 / count  # half width of one scallop
            dy = v - vy
            # lower half of an ellipse outline: a "u" stroke
            e = np.sqrt((dx / w) ** 2 + (dy / (w * 1.05 * n / n)) ** 2)
            stroke = np.exp(-((e - 1.0) / 0.13) ** 2) * (dy < 0.02) * _ss(-1.3, -0.2, -np.abs(dx / w))
            stroke = stroke * (1 - _ss(0.0, 0.03, dy))
            # a lighter fill just inside the stroke gives the tongue a soft pillow
            fill = _ss(1.0, 0.55, e) * (dy < 0.0) * 0.5
            col = col * (1 - (stroke * a)[..., None]) + tone * (stroke * a)[..., None]
            col = col * (1 - (fill * 0.12)[..., None]) + lt * (fill * 0.12)[..., None]
    return col


def paint_fruit(pal):
    """Like a petal ramp (v 0 bottom -> 1 top) with a soft sheen band below the shoulder; periodic in u."""
    col = paint_petal(pal)
    n = CELL - 2 * GUT
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    v = (y + 0.5) / n
    sheen = (np.exp(-((v - 0.68) / 0.08) ** 2) * 0.22)[..., None]
    return col * (1 - sheen) + np.array([1.0, 0.93, 0.8], np.float32) * sheen


def paint_petal(pal):
    """v = 0 at the petal base (head centre / cup bottom), 1 at the tips; soft gradient, faint vein toward the tip."""
    n = CELL - 2 * GUT
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    u, v = (x + 0.5) / n, (y + 0.5) / n
    b, m, t = (_c(pal[k]) for k in ("base", "body", "tip"))
    t1 = _ss(0.0, 0.45, v)[..., None]
    t2 = _ss(0.45, 1.0, v)[..., None]
    col = b * (1 - t1) + m * t1
    col = col * (1 - t2) + t * t2
    return col


def build_atlas():
    canvas = np.zeros((TEX, TEX, 3), np.float32)
    have = np.zeros((TEX, TEX), bool)
    for i, (name, (cx, cy)) in enumerate(CELLS.items()):
        body = (paint_foliage(LEAF[name], 100 + i) if name in LEAF else
                paint_fruit(PETAL[name]) if name == "fruit" else paint_petal(PETAL[name]))
        x0, y0 = cx * CELL + GUT, cy * CELL + GUT
        n = CELL - 2 * GUT
        canvas[y0:y0 + n, x0:x0 + n] = body
        have[y0:y0 + n, x0:x0 + n] = True
        # gutters: extend the cell's edge texels outward (clamp), so mip levels stay inside the colour family
        canvas[cy * CELL:y0, x0:x0 + n] = body[0]
        canvas[y0 + n:(cy + 1) * CELL, x0:x0 + n] = body[-1]
        blk = canvas[cy * CELL:(cy + 1) * CELL]
        blk[:, cx * CELL:x0] = blk[:, x0:x0 + 1]
        blk[:, x0 + n:(cx + 1) * CELL] = blk[:, x0 + n - 1:x0 + n]
        have[cy * CELL:(cy + 1) * CELL, cx * CELL:(cx + 1) * CELL] = True
    canvas[~have] = canvas[have].mean(axis=0)
    rgba = np.concatenate([canvas, np.ones((TEX, TEX, 1), np.float32)], axis=2)  # rows bottom-up already
    img = bpy.data.images.new("shrubs_atlas", TEX, TEX, alpha=False)
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = str(OUT / "mesh/textures/shrubs_atlas.png")
    img.file_format = "PNG"
    img.save()
    img.pack()
    return img


def cell_uv(name, u, v):
    cx, cy = CELLS[name]
    n = CELL - 2 * GUT
    return ((cx * CELL + GUT + u * n) / TEX, (cy * CELL + GUT + min(max(v, 0.0), 1.0) * n) / TEX)


# ---------------------------------------------------------------------------------------------------------------
class Part:
    """A closed piece: shared vertices, per-loop UVs (so the u seam needs no split vertices)."""

    def __init__(self):
        self.V, self.F = [], []  # F: (vertex indices, [(u, v) per corner])

    def transform(self, M):
        self.V = [M @ Vector(p) for p in self.V]
        return self


def tongue(phase, power=0.6):
    """0 at a notch, 1 at the middle of a scallop tongue (phase in lobes)."""
    return ((1 - math.cos(2 * math.pi * phase)) / 2) ** power


def lathe(rings, N, region, top=None, bottom=None, phase0=0.0):
    """rings: list of fn(phi, j) -> (x, y, z, v). top/bottom: (x, y, z, v) poles. Faces wind outward (+ normals
    recalculated later). u runs once around; the seam column reuses vertex 0 with u = 1."""
    P = Part()
    idx = []
    for ring in rings:
        row = []
        for j in range(N):
            phi = 2 * math.pi * (j / N + phase0)
            x, y, z, v = ring(phi, j)
            P.V.append((x, y, z))
            row.append((len(P.V) - 1, v))
        idx.append(row)
    def uv(j, v):
        return cell_uv(region, j / N, v)
    for a, b in zip(idx, idx[1:]):
        for j in range(N):
            k = j + 1
            (a0, va0), (a1, va1) = a[j], a[k % N]
            (b0, vb0), (b1, vb1) = b[j], b[k % N]
            P.F.append(((a0, b0, b1, a1), [uv(j, va0), uv(j, vb0), uv(k, vb1), uv(k, va1)]))
    if top is not None:
        P.V.append(top[:3])
        t = len(P.V) - 1
        for j in range(N):
            k = j + 1
            (a0, va0), (a1, va1) = idx[0][j], idx[0][k % N]
            P.F.append(((t, a0, a1), [uv(j + 0.5, top[3]), uv(j, va0), uv(k, va1)]))
    if bottom is not None:
        P.V.append(bottom[:3])
        t = len(P.V) - 1
        for j in range(N):
            k = j + 1
            (a0, va0), (a1, va1) = idx[-1][j], idx[-1][k % N]
            P.F.append(((t, a1, a0), [uv(j + 0.5, bottom[3]), uv(k, va1), uv(j, va0)]))
    return P


def footprint(N, square, sx, sy, phase0):
    """Unit footprint points (x, y) for the N columns of a puff: an ellipse (sx, sy), or with `square` a
    superellipse |x|^p + |y|^p = 1 resampled by arc length, so a long clipped hedge keeps evenly spaced scallops
    and nearly full width up to its ends (pieces laid end to end then join without a waist)."""
    if not square:
        return [(sx * math.cos(2 * math.pi * (j / N + phase0)), sy * math.sin(2 * math.pi * (j / N + phase0)))
                for j in range(N)]
    M = 4096
    pts = []
    for i in range(M):
        t = 2 * math.pi * i / M
        c, s_ = math.cos(t), math.sin(t)
        pts.append((sx * math.copysign(abs(c) ** (2 / square), c), sy * math.copysign(abs(s_) ** (2 / square), s_)))
    cum = [0.0]
    for i in range(M):
        a, b = pts[i], pts[(i + 1) % M]
        cum.append(cum[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
    L, i = cum[-1], 0
    targets = sorted(((j / N + phase0) % 1.0 * L, j) for j in range(N))
    res = [None] * N
    for tgt, j in targets:
        while cum[i + 1] < tgt:
            i += 1
        f = (tgt - cum[i]) / max(cum[i + 1] - cum[i], 1e-12)
        a, b = pts[i], pts[(i + 1) % M]
        res[j] = (a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f)
    return res


def puff(R, top, hem, N, K, lobes, region, drop=0.35, flare=0.16, sx=1.0, sy=1.0, phase0=0.0, belly=0.38,
         square=None):
    """A pillowy dome with a scalloped skirt, closed underneath. Base footprint radius R (x scaled sx, y sy);
    `top` and `hem` are absolute heights; tongues reach `hem`, notches sit `drop` of the skirt higher."""
    fp = footprint(N, square, sx, sy, phase0)
    eq = hem + (top - hem) * belly
    Ht, Hl = top - eq, eq - hem
    rings = []
    for k in range(1, K + 1):
        th = (math.pi / 2) * k / K
        r, z, v = R * math.sin(th), eq + Ht * math.cos(th), 0.36 + 0.64 * math.cos(th)
        rings.append(lambda phi, j, r=r, z=z, v=v: (r * fp[j][0], r * fp[j][1], z, v))

    def lower(phi, j):  # a little belly below the equator, gently scalloped already
        t = tongue(j / (N / lobes))
        r = R * (1.0 + 0.03 * t)
        return r * fp[j][0], r * fp[j][1], eq - Hl * 0.42, 0.24

    def hem_ring(phi, j):
        t = tongue(j / (N / lobes))
        r = R * (0.97 + flare * t)
        z = hem + Hl * drop * (1 - t)
        return r * fp[j][0], r * fp[j][1], z, 0.06 + 0.06 * (1 - t)

    def under(phi, j):
        r = R * 0.6
        return r * fp[j][0], r * fp[j][1], hem + Hl * 0.42, 0.03

    rings += [lower, hem_ring, under]
    return lathe(rings, N, region, top=(0, 0, top, 1.0), bottom=(0, 0, hem + Hl * 0.5, 0.02), phase0=phase0)


def petal_head(R, thick, petals, N, region, cup=0.0):
    """A lens-shaped head whose rim is cut into rounded petal tongues (radially). Faces +Z; v 0 centre -> 1 tips."""
    def rim(phi, j):
        t = tongue(j / (N / petals), 0.5)
        r = R * (0.5 + 0.5 * t)
        return r * math.cos(phi), r * math.sin(phi), cup * R * t, 0.55 + 0.45 * t

    def mid_top(phi, j):
        r = R * 0.42
        return r * math.cos(phi), r * math.sin(phi), thick * 0.45, 0.3

    def mid_bot(phi, j):
        r = R * 0.38
        return r * math.cos(phi), r * math.sin(phi), -thick * 0.5, 0.25

    return lathe([mid_top, rim, mid_bot], N, region, top=(0, 0, thick * 0.6, 0.05), bottom=(0, 0, -thick * 0.6, 0.1))


def tulip_cup(R, H, petals, N, region):
    def ring(rf, zf, v, tip=0.0):
        def f(phi, j):
            t = tongue(j / (N / petals), 0.7) if tip else 0.0
            r = R * (rf + 0.06 * t * tip)
            return r * math.cos(phi), r * math.sin(phi), H * (zf + tip * 0.2 * t), v
        return f
    rings = [ring(0.5, 0.1, 0.12), ring(0.92, 0.36, 0.42), ring(1.0, 0.64, 0.7), ring(0.84, 0.86, 1.0, tip=1.0),
             ring(0.42, 0.8, 0.75)]
    # the first ring is the cup's foot, the last the inner rim: poles close the foot and dip into the cup
    return lathe(rings, N, region, top=(0, 0, 0, 0.0), bottom=(0, 0, H * 0.74, 0.6))


def fruit_body(R, N, K):
    """A round fruit, origin at its bottom, a soft dimple at the top. v 0 bottom -> 1 top (fruit cell)."""
    rings = []
    for k in range(1, K + 1):
        th = math.pi * k / (K + 1)
        z = R * (1 - math.cos(th)) * 0.94
        r = R * math.sin(th) * (1.0 + 0.05 * math.sin(th) ** 2)
        rings.append(lambda phi, j, r=r, z=z, v=k / (K + 1): (r * math.cos(phi), r * math.sin(phi), z, v))
    zt = R * (1 - math.cos(math.pi * K / (K + 1))) * 0.94
    return lathe(rings, N, "fruit", top=(0, 0, 0, 0.0), bottom=(0, 0, zt - 0.06 * R, 0.96))


def fruit_parts(R, lod, with_leaf=True, fine=False):
    """Fruit + short stalk + one leaf, origin at the fruit's centre, upright."""
    from mathutils import Euler
    N, K = ((16, 6) if lod == 0 else (10, 4)) if fine else ((12, 5) if lod == 0 else (8, 3))
    top = R * (1 - math.cos(math.pi * K / (K + 1))) * 0.94 - R * 0.94
    parts = [place(fruit_body(R, N, K), (0, 0, -R * 0.94))]
    parts.append(stem((0, 0, top - R * 0.1), (R * 0.12, 0, top + R * 0.42), R * 0.09, R * 0.07,
                      5 if lod == 0 else 3, "centre"))
    if with_leaf:
        lf = puff(R * 0.42, R * 0.12, -R * 0.12, 8, 1, 4, "leaf_A", drop=0.1, flare=0.0, sx=1.9, belly=0.5)
        q = Euler((0, math.radians(-28), math.radians(35)), "XYZ").to_quaternion()
        parts.append(place(lf, (R * 0.55, R * 0.25, top + R * 0.2), q))
    return parts


FRUIT_ANCHORS = {}


def fruits(name, spec, lod, host=0):
    """Large fruit hanging on the host puff, sunk a little into it, mostly on the south side (toward the camera)."""
    from mathutils import Euler
    parts, anchors = [], []
    hp = spec["puffs"][host]
    eq = hp.get("hem", 0.0) + (hp["top"] - hp.get("hem", 0.0)) * hp.get("belly", 0.38)
    for th_deg, ph_deg, s in spec.get("fruits", []):
        th, ph = math.radians(th_deg), math.radians(ph_deg)
        n = Vector((hp["R"] * math.sin(th) * math.cos(ph) * hp.get("sx", 1),
                    hp["R"] * math.sin(th) * math.sin(ph) * hp.get("sy", 1), (hp["top"] - eq) * math.cos(th)))
        R_ = spec["fruit_R"] * s
        c = Vector((hp["x"], hp["y"], eq)) + n + n.normalized() * R_ * 0.3
        q = Euler((0, 0, ph + math.pi / 2), "XYZ").to_quaternion()
        for P in fruit_parts(R_, lod, with_leaf=lod == 0):
            parts.append(place(P, c, q))
        anchors.append(dict(centre_zup=[round(c.x, 4), round(c.y, 4), round(c.z, 4)], radius=round(R_, 4)))
    FRUIT_ANCHORS[name] = anchors
    return parts


def stem(p0, p1, r0, r1, sides=5, region="stem"):
    """A thin tapered stem from p0 (base) to p1, closed at both ends (ends sit inside the mound and the head)."""
    p0, p1 = Vector(p0), Vector(p1)
    ax = (p1 - p0).normalized()
    q = ax.to_track_quat("Z", "Y")
    def ring(r, p, v):
        return lambda phi, j: tuple(p + q @ Vector((r * math.cos(phi), r * math.sin(phi), 0))) + (v,)
    return lathe([ring(r1, p1, 0.9), ring(r0, p0, 0.1)], sides, region, top=tuple(p1 + ax * r1) + (1.0,),
                 bottom=tuple(p0 - ax * r0) + (0.0,))


def place(P, loc=(0, 0, 0), rot=None, scale=1.0):
    M = Matrix.Translation(Vector(loc))
    if rot is not None:
        M = M @ rot.to_matrix().to_4x4()
    return P.transform(M @ Matrix.Scale(scale, 4))


# ---------------------------------------------------------------------------------------------------------------
# LOD detail: (segments per lobe around a puff, dome rings) ; flowers: (segments per petal, head lathe)
LOD_DETAIL = {0: dict(seg=4, K=4, small_K=3, fseg=3, stem_sides=5),
              1: dict(seg=2, K=3, small_K=2, fseg=2, stem_sides=3)}


def bush_puffs(spec, lod):
    d = LOD_DETAIL[lod]
    parts = []
    for i, p in enumerate(spec["puffs"]):
        lobes = p.get("lobes", 6)
        big = p["R"] >= 0.3
        K = min(p.get("K", 99), d["K"] if big else d["small_K"])
        P = puff(p["R"], p["top"], p.get("hem", 0.0), lobes * d["seg"], K, lobes,
                 spec["leaf"], drop=p.get("drop", 0.42), flare=p.get("flare", 0.16), sx=p.get("sx", 1.0),
                 sy=p.get("sy", 1.0), phase0=p.get("ph", 0.13 * i),
                 belly=p.get("belly", 0.38), square=p.get("square"))
        parts.append(place(P, (p["x"], p["y"], 0)))
    return parts


def blossoms(spec, lod, host):
    """Petal masses sitting on the main puff's upper surface, facing outward."""
    d = LOD_DETAIL[lod]
    parts = []
    hp = spec["puffs"][host]
    eq = hp.get("hem", 0.0) + (hp["top"] - hp.get("hem", 0.0)) * 0.38
    for th_deg, ph_deg, s in spec["blossoms"]:
        th, ph = math.radians(th_deg), math.radians(ph_deg)
        n = Vector((hp["R"] * math.sin(th) * math.cos(ph) * hp.get("sx", 1),
                    hp["R"] * math.sin(th) * math.sin(ph) * hp.get("sy", 1), (hp["top"] - eq) * math.cos(th)))
        pos = Vector((hp["x"], hp["y"], eq)) + n * 0.96
        nrm = Vector((n.x / hp["R"] ** 2, n.y / hp["R"] ** 2, n.z / (hp["top"] - eq) ** 2)).normalized()
        H = petal_head(0.07 * s, 0.03 * s, 5, 5 * d["fseg"], "blossom", cup=0.25)
        parts.append(place(H, pos, nrm.to_track_quat("Z", "Y")))
        if lod == 0:
            c = puff(0.02 * s, 0.026 * s, -0.004, 6, 1, 3, "centre", drop=0.1, flare=0.0)
            parts.append(place(c, pos + nrm * 0.02 * s, nrm.to_track_quat("Z", "Y")))
    return parts


def leaf_mound(R, H, lod, lobes=5, sx=1.0, sy=1.0, ph=0.0):
    d = LOD_DETAIL[lod]
    return puff(R, H, -0.01, lobes * (3 if lod == 0 else 2), 2 if lod == 0 else 1, lobes, "stem", drop=0.5,
                flare=0.1, sx=sx, sy=sy, phase0=ph)


def flower_clump(spec, lod):
    d = LOD_DETAIL[lod]
    parts = [leaf_mound(*spec["mound"], lod=lod)]
    for k, h in enumerate(spec["heads"]):
        x, y, z, lean = h
        base = Vector((x * 0.35, y * 0.35, 0.03))
        tipv = Vector((x, y, z))
        parts.append(stem(base, tipv, 0.016, 0.011, d["stem_sides"]))
        tilt = Euler_from(lean)
        kind = spec["kind"]
        if kind == "daisy":
            Hh = petal_head(0.12, 0.034, 7, 7 * d["fseg"], spec["petal"], cup=0.12)
            parts.append(place(Hh, tipv, tilt))
            c = puff(0.045, 0.036, -0.006, 8 if lod == 0 else 6, 1, 4, "centre", drop=0.1, flare=0.0)
            parts.append(place(c, tipv + tilt @ Vector((0, 0, 0.014)), tilt))
        elif kind == "tulip":
            C = tulip_cup(0.075, 0.15, 3, 3 * (4 if lod == 0 else 2), spec["petal"])
            parts.append(place(C, tipv - tilt @ Vector((0, 0, 0.01)), tilt))
        elif kind == "pom":
            Pm = puff(0.1, 0.09, -0.08, 6 * (3 if lod == 0 else 2), 2 if lod == 0 else 1, 6, spec["petal"],
                      drop=0.25, flare=0.05, belly=0.62)
            parts.append(place(Pm, tipv - tilt @ Vector((0, 0, 0.0)), tilt))
    return parts


def Euler_from(lean):
    """lean = (degrees toward the camera, i.e. -Y, sideways roll degrees)."""
    from mathutils import Euler
    return Euler((math.radians(-lean[0]), math.radians(lean[1]), 0), "XYZ").to_quaternion()


# ---------------------------------------------------------------------------------------------------------------
# The kit. Bush envelopes sit inside one tile (the game fits bushes to <= 0.9 of their blocking tile).
BUSHES = {
    "bush_A": dict(label="round puff bush", leaf="leaf_A", W=0.86, D=0.82, H=0.78, puffs=[
        dict(x=0.0, y=0.03, R=0.34, top=0.78, hem=0.08, lobes=6),
        dict(x=-0.25, y=-0.1, R=0.2, top=0.42, lobes=5, ph=0.2),
        dict(x=0.24, y=-0.13, R=0.21, top=0.46, lobes=5, ph=0.55),
        dict(x=0.06, y=0.24, R=0.22, top=0.5, lobes=5, ph=0.8)]),
    "bush_B": dict(label="low wide mound", leaf="leaf_B", W=0.9, D=0.78, H=0.56, puffs=[
        dict(x=-0.16, y=0.02, R=0.3, top=0.56, hem=0.04, lobes=6, sx=1.1),
        dict(x=0.2, y=0.06, R=0.27, top=0.5, hem=0.03, lobes=6, ph=0.4),
        dict(x=0.04, y=-0.2, R=0.2, top=0.34, lobes=5, ph=0.7)]),
    "bush_C": dict(label="tall upright bush", leaf="leaf_C", W=0.74, D=0.72, H=1.06, puffs=[
        dict(x=0.0, y=0.04, R=0.27, top=1.06, hem=0.04, lobes=6, belly=0.3),
        dict(x=-0.17, y=-0.04, R=0.18, top=0.78, hem=0.3, lobes=5, ph=0.3),
        dict(x=0.18, y=0.0, R=0.17, top=0.66, hem=0.22, lobes=5, ph=0.75),
        dict(x=0.02, y=-0.17, R=0.17, top=0.4, lobes=5, ph=0.5)]),
    "bush_D": dict(label="flowering bush (replaces the orange-dot bushes)", leaf="leaf_A", W=0.86, D=0.8, H=0.8,
                   puffs=[dict(x=0.02, y=0.02, R=0.35, top=0.78, hem=0.06, lobes=6, ph=0.4),
                          dict(x=-0.24, y=-0.14, R=0.19, top=0.4, lobes=5, ph=0.1),
                          dict(x=0.25, y=-0.08, R=0.2, top=0.44, lobes=5, ph=0.7)],
                   blossoms=[(20, 255, 1.35), (46, 300, 1.3), (50, 215, 1.25), (54, 15, 1.2), (40, 125, 1.2),
                             (66, 262, 1.25)]),
    # rev_002: a fruit bush whose large fruit can be picked; bush_E_picked is the same bush with the fruit gone
    "bush_E": dict(label="fruit bush (pickable fruit)", leaf="leaf_C", W=0.9, D=0.84, H=0.8, fruit_R=0.1,
                   puffs=[dict(x=0.0, y=0.03, R=0.36, top=0.8, hem=0.06, lobes=6, ph=0.2),
                          dict(x=-0.26, y=-0.1, R=0.2, top=0.42, lobes=5, ph=0.45),
                          dict(x=0.26, y=-0.06, R=0.19, top=0.4, lobes=5, ph=0.85)],
                   fruits=[(62, 250, 1.0), (52, 302, 0.95), (68, 204, 0.95), (30, 272, 0.9)]),
}
BUSHES["bush_E_picked"] = dict(BUSHES["bush_E"], label="fruit bush, picked (same bush without its fruit)", fruits=[])
HEDGE = {"hedge": dict(label="clipped hedge (2 tiles long, rounded ends)", leaf="leaf_H", W=1.96, D=0.8, H=0.96,
                       puffs=[dict(x=0.0, y=0.0, R=0.36, top=0.84, hem=0.0, lobes=14, sx=2.6, ph=0.0, belly=0.55,
                                   drop=0.36),
                              dict(x=-0.56, y=0.02, R=0.3, top=0.96, hem=0.44, lobes=5, sx=1.25, ph=0.33),
                              dict(x=0.02, y=-0.01, R=0.3, top=0.95, hem=0.44, lobes=5, sx=1.25, ph=0.66),
                              dict(x=0.58, y=0.01, R=0.3, top=0.93, hem=0.44, lobes=5, sx=1.2, ph=0.15)]),
         # rev_002: a straight middle piece, one tile long; its squared ends reach about 0.2 into each neighbour,
         # so runs of middles (and the rounded-end hedge) join without a notch; a run's last piece ends squared off
         "hedge_middle": dict(label="hedge, straight middle piece (1 tile, joins end to end)", leaf="leaf_H",
                              W=1.0, D=0.8, H=0.96,
                              puffs=[dict(x=0.0, y=0.0, R=0.36, top=0.84, hem=0.0, lobes=14, sx=1.72, ph=0.0,
                                          belly=0.55, drop=0.36, square=6, K=3),
                                     dict(x=-0.25, y=0.01, R=0.3, top=0.95, hem=0.44, lobes=5, sx=1.25, ph=0.4, K=3),
                                     dict(x=0.25, y=-0.01, R=0.3, top=0.94, hem=0.44, lobes=5, sx=1.25, ph=0.8,
                                          K=3)])}
FRUIT = {"fruit": dict(label="picked fruit (held, dropped or shown on its own)", R=0.1)}
FLOWERS = {
    "flower_daisy": dict(label="daisy clump", kind="daisy", petal="daisy", mound=(0.17, 0.12), heads=[
        (-0.1, -0.03, 0.34, (-30, -10)), (0.11, 0.03, 0.4, (-24, 12)), (0.0, 0.1, 0.28, (-36, 0))]),
    "flower_tulip_coral": dict(label="coral tulips", kind="tulip", petal="coral", mound=(0.15, 0.13), heads=[
        (-0.07, 0.0, 0.36, (-6, -6)), (0.08, 0.04, 0.42, (-4, 7)), (0.01, -0.06, 0.33, (-10, 0))]),
    "flower_tulip_butter": dict(label="butter tulips", kind="tulip", petal="butter", mound=(0.15, 0.13), heads=[
        (-0.06, 0.03, 0.4, (-5, -7)), (0.08, -0.02, 0.34, (-8, 6)), (-0.01, -0.07, 0.31, (-12, 0))]),
    "flower_pom_lilac": dict(label="lilac bellflowers", kind="pom", petal="lilac", mound=(0.17, 0.11), heads=[
        (-0.08, 0.02, 0.42, (-8, -8)), (0.1, 0.05, 0.44, (-6, 8)), (0.02, -0.07, 0.34, (-12, 0))]),
}


# ---------------------------------------------------------------------------------------------------------------
def to_object(name, parts, mat, fit=None):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    for P in parts:
        vs = [bm.verts.new(p) for p in P.V]
        new = []
        for ids, uvs in P.F:
            f = bm.faces.new([vs[i] for i in ids])
            for lp, uv in zip(f.loops, uvs):
                lp[uvl].uv = uv
            new.append(f)
        # every part is a closed shell: make its winding consistent and outward
        bmesh.ops.recalc_face_normals(bm, faces=new)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    if fit:
        lo = Vector([min(v.co[k] for v in me.vertices) for k in range(3)])
        hi = Vector([max(v.co[k] for v in me.vertices) for k in range(3)])
        size = hi - lo
        c = (lo + hi) / 2
        W, D, H = fit
        me.transform(Matrix.Translation((0, 0, 0)) @ Matrix.Diagonal((W / size.x, D / size.y, H / size.z, 1))
                     @ Matrix.Translation((-c.x, -c.y, -lo.z)))
    me.materials.append(mat)
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def make_material(img):
    mat = bpy.data.materials.new("shrubs_kit")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Linear"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85
    bsdf.inputs["Specular IOR Level"].default_value = 0.25
    mat.use_backface_culling = True  # closed solids: exported single-sided
    return mat


def mesh_stats(ob):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-6)
    boundary = sum(1 for e in bm.edges if e.is_boundary)
    nonman = sum(1 for e in bm.edges if not e.is_manifold and not e.is_boundary)
    bm.free()
    me = ob.data
    lo = [min(v.co[k] for v in me.vertices) for k in range(3)]
    hi = [max(v.co[k] for v in me.vertices) for k in range(3)]
    uv = me.uv_layers.active.data
    us = [uv[i].uv[0] for i in range(len(uv))]
    vs = [uv[i].uv[1] for i in range(len(uv))]
    return dict(triangles=sum(len(p.vertices) - 2 for p in me.polygons), vertices=len(me.vertices),
                open_boundary_edges=boundary, nonmanifold_edges=nonman,
                width_x=round(hi[0] - lo[0], 4), depth_y=round(hi[1] - lo[1], 4), height=round(hi[2] - lo[2], 4),
                bbox_min_zup=[round(x, 4) for x in lo], bbox_max_zup=[round(x, 4) for x in hi],
                uv_range=[round(min(us), 4), round(min(vs), 4), round(max(us), 4), round(max(vs), 4)])


def export(ob, path):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.gltf(filepath=str(path), use_selection=True, export_format="GLTF_SEPARATE",
                              export_texture_dir="textures", export_yup=True, export_apply=True,
                              export_normals=True, export_texcoords=True, export_materials="EXPORT")


# ---------------------------------------------------------------------------------------------------------------
def setup_render(res=(800, 1000)):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE_NEXT"
    sc.eevee.taa_render_samples = 48
    sc.eevee.use_shadows = True
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Base Contrast"
    w = sc.world or bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.62, 0.72, 0.86, 1)
    bg.inputs["Strength"].default_value = 0.9
    if "key" not in bpy.data.objects:
        sun = bpy.data.objects.new("key", bpy.data.lights.new("key", "SUN"))
        sun.data.energy = 3.6
        sun.data.color = (1.0, 0.94, 0.84)
        sun.data.angle = math.radians(9)
        sun.rotation_euler = (math.radians(48), 0, math.radians(-35))
        sc.collection.objects.link(sun)
        g = bpy.data.objects.new("preview_ground", bpy.data.meshes.new("ground"))
        bmg = bmesh.new()
        bmesh.ops.create_grid(bmg, x_segments=1, y_segments=1, size=30)
        bmg.to_mesh(g.data)
        bmg.free()
        gm = bpy.data.materials.new("preview_ground_grid")
        gm.use_nodes = True
        nt = gm.node_tree
        tc = nt.nodes.new("ShaderNodeTexCoord")
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(tc.outputs["Object"], sep.inputs[0])

        def line(axis):
            fr = nt.nodes.new("ShaderNodeMath"); fr.operation = "FRACT"
            nt.links.new(sep.outputs[axis], fr.inputs[0])
            sub = nt.nodes.new("ShaderNodeMath"); sub.operation = "SUBTRACT"; sub.inputs[1].default_value = 0.5
            nt.links.new(fr.outputs[0], sub.inputs[0])
            ab = nt.nodes.new("ShaderNodeMath"); ab.operation = "ABSOLUTE"
            nt.links.new(sub.outputs[0], ab.inputs[0])
            gt = nt.nodes.new("ShaderNodeMath"); gt.operation = "GREATER_THAN"; gt.inputs[1].default_value = 0.488
            nt.links.new(ab.outputs[0], gt.inputs[0])
            return gt
        mx = nt.nodes.new("ShaderNodeMath"); mx.operation = "MAXIMUM"
        nt.links.new(line("X").outputs[0], mx.inputs[0]); nt.links.new(line("Y").outputs[0], mx.inputs[1])
        mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"
        mix.inputs["A"].default_value = (0.42, 0.5, 0.36, 1)
        mix.inputs["B"].default_value = (0.33, 0.4, 0.29, 1)
        nt.links.new(mx.outputs[0], mix.inputs["Factor"])
        nt.links.new(mix.outputs["Result"], nt.nodes["Principled BSDF"].inputs["Base Color"])
        nt.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.95
        g.data.materials.append(gm)
        sc.collection.objects.link(g)
        hero = bpy.data.objects.new("hero_ref", bpy.data.meshes.new("hero_ref"))
        bmh = bmesh.new()
        bmesh.ops.create_uvsphere(bmh, u_segments=16, v_segments=10, radius=0.2)
        for vt in bmh.verts:
            vt.co.z = (vt.co.z + 0.2) / 0.4 * HERO_H
        bmh.to_mesh(hero.data)
        bmh.free()
        hm = bpy.data.materials.new("hero_ref_mat")
        hm.use_nodes = True
        hm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.85, 0.42, 0.18, 1)
        hero.data.materials.append(hm)
        sc.collection.objects.link(hero)
    cam = bpy.data.objects.get("cam") or bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    if cam.name not in sc.collection.objects:
        sc.collection.objects.link(cam)
    sc.camera = cam
    return sc, cam


def aim(cam, loc, target):
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()


def show_only(objs, ground=True):
    keep = set(o.name for o in objs) | {"key", "cam"} | ({"preview_ground"} if ground else set())
    for o in bpy.data.objects:
        o.hide_render = o.name not in keep


def render(path):
    bpy.context.scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def import_trees():
    """Approved broadleaf rev_003 LOD0, imported read-only for scale/style comparison (never re-exported)."""
    trees = {}
    for k in "ABC":
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(TREES / f"broadleaf_{k}_lod0.gltf"))
        new = [o for o in bpy.data.objects if o not in before]
        ob = [o for o in new if o.type == "MESH"][0]
        for o in new:
            if o is not ob:
                bpy.data.objects.remove(o)
        ob.name = f"ref_broadleaf_{k}"
        ob.parent = None
        ob.location, ob.rotation_mode = (0, 0, 0), "XYZ"
        trees[k] = ob
    return trees


def inst(src, loc, rot=0.0, s=1.0, name=None):
    o = bpy.data.objects.new(name or f"i_{src.name}_{len(bpy.data.objects)}", src.data)
    bpy.context.scene.collection.objects.link(o)
    o.location = loc
    o.rotation_mode = "XYZ"
    o.rotation_euler = (src.rotation_euler.x, src.rotation_euler.y, rot)
    o.scale = (s, s, s)
    return o


def renders(objects, trees):
    sc, cam = setup_render()
    R = OUT / "renders"
    hero = bpy.data.objects["hero_ref"]
    pitch = math.atan2(7.0, 11.0)
    names = list(BUSHES) + list(HEDGE) + list(FLOWERS) + list(FRUIT)

    def size(name):  # turntable ortho, res, hero x, target z; LOD ortho, res, target z
        if name == "hedge":
            return 3.4, (640, 480), 1.35, 0.55, 2.6, (560, 360), 0.45
        if name == "hedge_middle":
            return 2.4, (520, 480), 0.95, 0.55, 1.8, (480, 360), 0.45
        if name.startswith("bush"):
            return 2.0, (440, 480), 0.75, 0.6, 1.25, (360, 360), 0.45
        if name == "fruit":
            return 1.0, (440, 480), 0.4, 0.3, 0.42, (360, 360), 0.12
        return 1.5, (440, 480), 0.5, 0.42, 0.85, (360, 360), 0.26
    # turntables (LOD0, 4 azimuths, ortho, hero stand-in beside each)
    cam.data.type = "ORTHO"
    for name in names:
        ob = objects[(name, 0)]
        to, tres, hx, tz, _, _, _ = size(name)
        cam.data.ortho_scale = to
        sc.render.resolution_x, sc.render.resolution_y = tres
        ob.location = (0, 0, 0)
        hero.location = (hx, 0.5, 0)
        show_only([ob, hero])
        for i in range(4):
            ob.rotation_euler = (0, 0, math.radians(i * 90))
            aim(cam, Vector((0, -14, 3.6 + tz)), Vector((0.3 if name == "hedge" else 0.2 * to / 2.0, 0, tz)))
            render(R / f"turn_{name}_{i}.png")
        ob.rotation_euler = (0, 0, 0)
    # LODs at the gameplay pitch
    for name in names:
        for lod in (0, 1):
            ob = objects[(name, lod)]
            ob.location = (0, 0, 0)
            _, _, _, _, lo, lres, z = size(name)
            cam.data.ortho_scale = lo
            sc.render.resolution_x, sc.render.resolution_y = lres
            show_only([ob])
            aim(cam, Vector((0, -math.cos(pitch) * 20, math.sin(pitch) * 20 + z)), Vector((0, 0, z)))
            render(R / f"lod_{name}_{lod}.png")
    # back-face check: culling off, back faces glow magenta (no kit colour is magenta; closed solids show none)
    red = bpy.data.materials.new("cull_check")
    red.use_nodes = True
    nt = red.node_tree
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    mix = nt.nodes.new("ShaderNodeMixShader")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (1, 0, 1, 1)
    em.inputs["Strength"].default_value = 3.0
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images["shrubs_atlas"]
    bsdf = nt.nodes["Principled BSDF"]
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(geo.outputs["Backfacing"], mix.inputs[0])
    nt.links.new(bsdf.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], nt.nodes["Material Output"].inputs["Surface"])
    red.use_backface_culling = False
    cam.data.type = "PERSP"
    cam.data.sensor_fit = "VERTICAL"
    cam.data.angle_y = math.radians(36)
    sc.render.resolution_x, sc.render.resolution_y = 1600, 900
    lineup = []
    widths = [max(objects[(n, 0)].dimensions.x, 0.2) for n in names]
    total = sum(widths) + 0.22 * (len(names) - 1)
    xs, x = {}, -total / 2
    for n, w in zip(names, widths):
        xs[n] = x + w / 2
        x += w + 0.22
    back = max(1.0, total / 9.5)
    for name in names:
        o = inst(objects[(name, 0)], (xs[name], 0, 0))
        o.data = objects[(name, 0)].data.copy()
        o.data.materials[0] = red
        lineup.append(o)
    show_only(lineup, ground=False)
    sc.view_settings.view_transform = "Standard"  # keep the check colour pure
    for tag, loc, tgt in [("side", (0, -11.5, 2.0), (0, 0, 0.35)), ("below", (0, -10.5, -2.4), (0, 0, 0.4)),
                          ("top", (0, -3.2, 11.0), (0, 0, 0.2))]:
        aim(cam, Vector(loc) * back, Vector(tgt))
        render(R / f"cull_{tag}.png")
    for o in lineup:
        bpy.data.objects.remove(o)
    # positive control: the same puff with its underside left open must show red from below
    ctl = puff(0.34, 0.78, 0.08, 24, 4, 6, "leaf_A")
    ctl.F = [f for f in ctl.F if all(ctl.V[i][2] > 0.2 for i in f[0])]
    cob = to_object("cull_control", [ctl], red)
    show_only([cob], ground=False)
    aim(cam, Vector((0, -3.0, -0.9)), Vector((0, 0, 0.4)))
    render(R / "cull_control.png")
    bpy.data.objects.remove(cob)
    sc.view_settings.view_transform = "AgX"
    # side by side with the approved broadleaf rev_003 (same ortho scale, front view)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 6.2
    sc.render.resolution_x, sc.render.resolution_y = 1800, 760
    group = []
    group.append(inst(trees["A"], (-3.6, 0.6, 0)))
    for name, x in [("bush_A", -1.9), ("bush_B", -0.95), ("bush_C", 0.0), ("bush_D", 0.95)]:
        group.append(inst(objects[(name, 0)], (x, 0, 0)))
    group.append(inst(objects[("hedge", 0)], (2.45, 0.1, 0)))
    for name, x in [("flower_daisy", 3.75), ("flower_tulip_coral", 4.25), ("flower_tulip_butter", 4.7),
                    ("flower_pom_lilac", 5.15)]:
        group.append(inst(objects[(name, 0)], (x - 1.15, -0.25, 0)))
    hero.location = (-2.75, -0.2, 0)
    show_only(group + [hero])
    aim(cam, Vector((0.25, -16, 4.0)), Vector((0.25, 0, 1.3)))
    render(R / "lineup_front.png")
    aim(cam, Vector((0.25, -math.cos(pitch) * 22, math.sin(pitch) * 22 + 1.0)), Vector((0.25, 0, 1.0)))
    render(R / "lineup_game.png")
    for o in group:
        bpy.data.objects.remove(o)
    # rev_002 pieces beside broadleaf A: the fruit bush, picked, the fruit, and hedge runs
    group = [inst(trees["A"], (-3.6, 0.6, 0))]
    group += [inst(objects[("bush_E", 0)], (-1.9, 0, 0)), inst(objects[("bush_E_picked", 0)], (-0.85, 0, 0)),
              inst(objects[("fruit", 0)], (-0.1, -0.3, 0))]
    group += [inst(objects[("hedge_middle", 0)], (x, 0.1, 0)) for x in (0.9, 1.9, 2.9)]
    group += [inst(objects[("hedge", 0)], (4.73, 0.1, 0))]
    hero.location = (-2.75, -0.2, 0)
    show_only(group + [hero])
    cam.data.ortho_scale = 7.0
    sc.render.resolution_x, sc.render.resolution_y = 2000, 760
    aim(cam, Vector((0.6, -16, 4.0)), Vector((0.6, 0, 1.3)))
    render(R / "new_front.png")
    aim(cam, Vector((0.6, -math.cos(pitch) * 22, math.sin(pitch) * 22 + 1.0)), Vector((0.6, 0, 1.0)))
    render(R / "new_game.png")
    for o in group:
        bpy.data.objects.remove(o)
    # gameplay angle: the game camera (fov 36 vertical, offset (0,7,11) from the hero, looking at hero + 1 up).
    # Godot -Z (north) = Blender +Y. Trees behind, bushes on tile centres, a hedge along a garden, flower patches.
    cam.data.type = "PERSP"
    cam.data.angle_y = math.radians(36)
    sc.render.resolution_x, sc.render.resolution_y = 1920, 1080
    scene = []
    T = [("A", (-4, 5), 0.3, 1.0), ("B", (-1, 6), 1.2, 1.05), ("C", (3, 5), 2.0, 0.95), ("A", (5, 7), 4.0, 1.05),
         ("B", (1, 8), 0.7, 0.95), ("C", (-6, 8), 2.6, 1.0)]
    for k, (x, y), r, s in T:
        scene.append(inst(trees[k], (x, y, 0), r, s))
    B = [("bush_A", (-3, 2), 0.4), ("bush_B", (-2, 2), 2.1), ("bush_C", (-4, 3), 1.0), ("bush_D", (2, 2), 0.6),
         ("bush_A", (3, 2), 3.0), ("bush_B", (4, 3), 0.2), ("bush_D", (-5, 1), 2.4), ("bush_C", (5, 1), 4.2),
         ("bush_A", (-6, 4), 1.3), ("bush_B", (6, 4), 3.4), ("bush_E", (1, 2), 0.0), ("bush_E_picked", (-1, 2), 0.3)]
    for name, (x, y), r in B:
        scene.append(inst(objects[(name, 0)], (x + 0.5, y + 0.5, 0), r))
    # a hedge run along a garden edge: the rounded-end piece (tiles -4..-3) then four straight middles
    scene.append(inst(objects[("hedge", 0)], (-3.0, -1.5, 0), 0.0))
    for x in (-2, -1, 0, 1):
        scene.append(inst(objects[("hedge_middle", 0)], (x + 0.5, -1.5, 0), 0.0))
    F = [("flower_daisy", (1, -1)), ("flower_tulip_coral", (2, -1)), ("flower_tulip_butter", (3, -1)),
         ("flower_pom_lilac", (3, -2)), ("flower_daisy", (-1, 1)), ("flower_tulip_coral", (1, 1)),
         ("flower_pom_lilac", (-2, 0)), ("flower_tulip_butter", (4, 0))]
    rng = random.Random(5)
    for name, (x, y) in F:
        scene.append(inst(objects[(name, 0)], (x + 0.5 + rng.uniform(-0.15, 0.15), y + 0.5 + rng.uniform(-0.15, 0.15),
                                               0), rng.uniform(-0.6, 0.6), rng.uniform(0.85, 1.05)))
    hero.location = (0.5, 0.5, 0)
    show_only(scene + [hero])
    aim(cam, Vector((0.5, 0.5 - 11, 7)), Vector((0.5, 0.5, 1)))
    render(R / "gameplay.png")
    aim(cam, Vector((0.5, 0.5 - 11 * 0.55, 7 * 0.55)), Vector((0.5, 0.5, 0.6)))
    render(R / "gameplay_close.png")
    for o in scene:
        bpy.data.objects.remove(o)


# ---------------------------------------------------------------------------------------------------------------
def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    img = build_atlas()
    mat = make_material(img)
    objects, report = {}, dict(
        revision=REV, generator="tools/blender/art_candidates/shrubs/shrubs_candidate.py",
        blender=bpy.app.version_string, units="1 unit = 1 game tile; Z-up in .blend, Y-up in glTF; origin = "
        "footprint centre on the ground", hero_reference_height=HERO_H,
        texture=dict(file="mesh/textures/shrubs_atlas.png", size=TEX, cells=CELL, gutter_px=GUT,
                     layout={k: dict(col=c, row_from_bottom=r) for k, (c, r) in CELLS.items()},
                     method="painted procedurally with numpy (soft gradients, faint scallop marks; no noise)",
                     smoothing="NOT smoothed (left for integration)"),
        models={})
    report["revision_notes"] = "rev_002 adds hedge_middle, bush_E, bush_E_picked and fruit; rev_001's models are " \
        "rebuilt from unchanged specs (the atlas gains a fruit cell)"
    groups = [("bush", BUSHES), ("hedge", HEDGE), ("flower", FLOWERS), ("fruit", FRUIT)]
    for kind, table in groups:
        for name, spec in table.items():
            for lod in (0, 1):
                if kind == "flower":
                    parts = flower_clump(spec, lod)
                    fit = None
                elif kind == "fruit":
                    parts = [place(P, (0, 0, spec["R"] * 0.94)) for P in fruit_parts(spec["R"], lod, fine=True)]
                    fit = None
                else:
                    parts = bush_puffs(spec, lod)
                    if "blossoms" in spec:
                        parts += blossoms(spec, lod, 0)
                    if spec.get("fruits"):
                        parts += fruits(name, spec, lod)
                    fit = None
                ob = to_object(f"{name}_lod{lod}", parts, mat, fit)
                objects[(name, lod)] = ob
                path = OUT / f"mesh/{name}_lod{lod}.gltf"
                export(ob, path)
                rec = report["models"].setdefault(name, dict(kind=kind, label=spec["label"],
                                                             envelope_target=[spec.get("W"), spec.get("D"),
                                                                              spec.get("H")], lods={}))
                rec["lods"][str(lod)] = dict(file=path.name, materials=1, textures=1, double_sided=False,
                                             texture_files=["textures/shrubs_atlas.png"], parts=len(parts),
                                             **mesh_stats(ob))
    if RENDER:
        trees = import_trees()
        renders(objects, trees)
        for o in list(bpy.data.objects):
            if o.name.startswith("ref_broadleaf_"):
                bpy.data.objects.remove(o)
    for i, ((name, lod), ob) in enumerate(objects.items()):
        ob.location = ((i // 2) * 1.6 - 6, lod * 2.0, 0)
        ob.hide_render = False
    for name, anchors in FRUIT_ANCHORS.items():
        report["models"][name]["fruit_anchors_lod0"] = anchors  # pick points: fruit centres on the bush (Z-up)
    (OUT / "build_report.json").write_text(json.dumps(report, indent=1, default=str))
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "source/shrubs_candidate.blend"), compress=True)
    print("SHRUBS DONE", OUT)


main()
