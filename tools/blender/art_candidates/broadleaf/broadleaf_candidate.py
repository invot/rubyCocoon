"""Provisional broadleaf-tree artwork candidate (preproduction for runbook step 027; NOT integrated).

rev_002 changes (rev_001 stays as published): each crown gets its own baked atlas (smart-UV islands) in which the
approved leaf tile is height-blended between the side wrap and the top projection, so the rev_001 top/side band
(a hard UV switch) becomes interlocking whole leaves; materials export single-sided; the trunk base is capped and
the remaining open tube ends are tested to lie inside the crown or trunk.

    python tools/local_resource.py -- "<blender.exe>" -b --factory-startup \
        -P tools/blender/art_candidates/broadleaf/broadleaf_candidate.py -- --rev rev_001 [--no-render]

Writes everything into build/art_candidates/broadleaf/<rev>/ and refuses to touch a revision that already has
READY.json. Run make_sheets.py (labels/contact sheets) and finalize.py (hashes + READY.json, written last) after.

Stages, all deterministic (fixed seeds, no time-dependent input):
  1. Rework attempt: the existing tree_oak derivative (build/nature_split/tree_oak.json, from the supplied
     "Environment Pack - Stylized Nature", read-only) is voxel-remeshed, smoothed and decimated to the target
     budget and rendered, as the evidence for the rework-vs-rebuild decision.
  2. Rebuild: three broadleaf variants (A round, B tall, C wide). Tapered trunk with root flare and a few
     branches, crown of rounded leaf-cluster lobes (metaball union -> voxel remesh -> smooth -> decimate),
     per-lobe planar leaf UVs (leaves hang the same way on every lobe), softened crown normals.
  3. One painted 1024 atlas (three leaf quadrants + bark), generated here with numpy: soft gradients and
     organized overlapping leaf shapes, no noise. Unsmoothed: the shared smoothing pass runs at integration.
  4. LOD0/LOD1/LOD2 per variant, glTF (separate, shared atlas), a .blend source scene, build_report.json.
  5. Candidate preview renders (turntable, gameplay angle, LODs, source/rework comparison).
Units: 1 Blender unit = 1 game tile/world unit; hero reference 1.44 tall. Blender Z-up, glTF export Y-up.
"""
import bpy, bmesh, json, sys, math, pathlib, random
import numpy as np
from mathutils import Vector, Matrix

ROOT = pathlib.Path(__file__).resolve().parents[4]
SRC_JSON = ROOT / "build/nature_split/tree_oak.json"
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=None):
    return ARGS[ARGS.index(name) + 1] if name in ARGS else default


REV = arg("--rev", "rev_001")
COMPARE = arg("--compare-rev", "rev_001")  # a published revision, imported read-only for matched seam renders
OUT = ROOT / "build/art_candidates/broadleaf" / REV
RENDER = "--no-render" not in ARGS
if (OUT / "READY.json").exists():
    raise SystemExit(f"{OUT} is a published (immutable) revision; use a new --rev")
for sub in ["", "mesh", "mesh/textures", "renders", "source"]:
    (OUT / sub).mkdir(parents=True, exist_ok=True)

HERO_H = 1.44
TEX = 512  # every map is a seamless 512 tile
LEAF_TILE = 1.6  # world units per leaf tile (8 leaves across: about 0.2 units per leaf)
BARK_TILE_V = 2.0  # world units per bark tile up the trunk; once around the trunk

# ---------------------------------------------------------------------------------------------------------------
# Variants. Heights/widths keep the existing oak's envelope (width/height 0.857 at any height); the game fits each
# tree to a height of 2.0-3.7 by its bounding box (world.gd), so these heights set proportion, not final size.
VARIANTS = {
    "A": dict(label="round oak", H=3.0, W=2.55, D=2.4, crown_bottom=1.02, base_r=0.19, top_r=0.12, roots=5,
              lean=(0.05, 0.02), leaf="leaf_A", seed=11, ring=6, top=3, low=2, ring_r=0.47, flat=1.0),
    "B": dict(label="tall linden", H=3.4, W=2.3, D=2.2, crown_bottom=1.22, base_r=0.17, top_r=0.105, roots=4,
              lean=(-0.12, 0.04), leaf="leaf_B", seed=23, ring=5, top=4, low=2, ring_r=0.42, flat=1.25),
    "C": dict(label="wide chestnut", H=2.8, W=2.75, D=2.55, crown_bottom=0.88, base_r=0.21, top_r=0.13, roots=6,
              lean=(0.03, -0.03), leaf="leaf_C", seed=37, ring=7, top=4, low=3, ring_r=0.5, flat=0.85),
}
LODS = {0: dict(crown=1650, sides=14, rings=8, branches=True, tex=1024),
        1: dict(crown=620, sides=8, rings=5, branches=True, tex=512),
        2: dict(crown=190, sides=6, rings=3, branches=False, tex=256)}

# Painted palettes (sRGB 0-255). Gentle, slightly warm greens with clear light/shade steps; never neon.
LEAF_PAL = {
    "leaf_A": dict(gap=(60, 104, 62), shadow=(66, 112, 64), mid=(92, 144, 70), light=(130, 176, 86), accent=(156, 186, 94)),
    "leaf_B": dict(gap=(80, 118, 60), shadow=(86, 126, 60), mid=(120, 160, 74), light=(160, 192, 98), accent=(184, 202, 112)),
    "leaf_C": dict(gap=(46, 90, 66), shadow=(52, 98, 68), mid=(72, 128, 80), light=(106, 158, 94), accent=(132, 172, 102)),
}
BARK_PAL = dict(groove=(96, 68, 54), base=(128, 92, 68), light=(160, 120, 88), warm=(150, 104, 72))


# ---------------------------------------------------------------------------------------------------------------
# Texture painting (numpy). Every map tiles seamlessly in both directions (painted on a 3x3 canvas with periodic
# parameters, middle tile kept). Canvas row 0 is the TOP of the image; flipped when written (Blender is bottom-up).
def _c(t):
    return np.array(t, np.float32) / 255.0


def _smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def paint_leaves(S, pal, seed):
    rng = np.random.default_rng(seed)
    C = 3 * S
    yy, xx = np.mgrid[0:C, 0:C].astype(np.float32)
    field = np.zeros((C, C), np.float32)  # broad soft tonal patches, periodic
    for _ in range(6):
        cx, cy = rng.uniform(0, S, 2)
        rad = rng.uniform(S * 0.16, S * 0.28)
        amp = rng.uniform(-1, 1)
        for ox in range(-1, 4):
            for oy in range(-1, 4):
                field += amp * np.exp(-((xx - cx - ox * S) ** 2 + (yy - cy - oy * S) ** 2) / (2 * rad * rad))
    field /= max(float(np.abs(field).max()), 1e-6)
    img = np.empty((C, C, 3), np.float32)
    img[:] = _c(pal["gap"])
    hb = np.zeros((C, C), np.float32)  # leaf height mask (1 at the stem end, 0 in the gaps), for blending only
    cols, rows = 8, 12
    dx, dy = S / cols, S / rows
    a, b = 0.42 * dx, 0.86 * dy  # half-width / half-length of a leaf
    params = {}
    for r in range(rows):
        for k in range(cols):
            params[(r, k)] = (rng.uniform(-3, 3), rng.uniform(-2.5, 2.5), rng.uniform(-0.22, 0.22),
                              rng.uniform(0.92, 1.06), rng.normal(0, 0.07), rng.random(), rng.random())
    for R in range(3 * rows + 1, -2, -1):  # bottom rows first: upper leaves overlap the tops of the leaves below
        for K in range(-1, 3 * cols + 1):
            jx, jy, ang, sz, tn, r1, r2 = params[(R % rows, K % cols)]
            cx = K * dx + (dx / 2 if R % 2 else 0.0) + jx
            cy = R * dy + jy
            tone = float(np.clip(0.5 + 0.5 * field[int(np.clip(cy, 0, C - 1)), int(np.clip(cx, 0, C - 1))] + tn, 0, 1))
            col = _c(pal["mid"]) * (1 - tone) + _c(pal["light"]) * tone
            if r1 < 0.035:
                col = _c(pal["accent"])
            elif r2 < 0.06:
                col = _c(pal["shadow"]) * 0.6 + col * 0.4
            x0, x1 = int(max(cx - 1.3 * a, 0)), int(min(cx + 1.3 * a, C))
            y0, y1 = int(max(cy - 1.2 * b, 0)), int(min(cy + 1.2 * b + 8, C))
            if x0 >= x1 or y0 >= y1:
                continue
            lx = xx[y0:y1, x0:x1] - cx
            ly = yy[y0:y1, x0:x1] - cy
            ca, sa = math.cos(ang), math.sin(ang)
            ux = ca * lx + sa * ly
            uy = -sa * lx + ca * ly

            def leaf_d(px, py):  # signed distance-ish to a broad leaf hanging tip-down
                t = (py / (b * sz) + 1) / 2
                hw = a * sz * np.sin(np.pi * np.clip(t, 0, 1) ** 0.62)
                d = np.abs(px) - hw
                d = np.where((t < 0) | (t > 1), 4.0 + np.abs(t - 0.5) * 8, d)
                return d, t

            ds, _ = leaf_d(ux, uy - 5.0)  # soft drop shadow onto the leaves already painted below
            sh = _smooth(4.0, -2.0, ds) * 0.13
            patch = img[y0:y1, x0:x1]
            patch *= (1 - sh)[..., None]
            d, t = leaf_d(ux, uy)
            m = _smooth(0.9, -0.9, d)
            shade = 1.08 - 0.17 * np.clip(t, 0, 1) ** 1.2  # lighter at the stem, a little darker at the tip
            shade = shade + np.where(ux < 0, 0.03, -0.02)  # folded halves
            rim = _smooth(-3.0, 0.0, d) * 0.035
            rib = _smooth(1.5, 0.3, np.abs(ux)) * _smooth(0.08, 0.22, t) * _smooth(0.88, 0.7, t) * 0.07
            leafc = col[None, None, :] * (shade - rim + rib)[..., None]
            patch[:] = patch * (1 - m[..., None]) + leafc * m[..., None]
            hp = hb[y0:y1, x0:x1]
            hp[:] = hp * (1 - m) + m * (1.0 - 0.45 * np.clip(t, 0, 1))
    return np.clip(img[S:2 * S, S:2 * S], 0, 1), hb[S:2 * S, S:2 * S]


def paint_bark(S, pal, seed):
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    groove, base, light, warm = (_c(pal[k]) for k in ("groove", "base", "light", "warm"))
    edges = [0.0]
    while edges[-1] < S:
        edges.append(edges[-1] + rng.uniform(46, 84))
    edges = np.array(edges) * (S / edges[-1])  # wraps exactly: seamless around the trunk
    img = np.zeros((S, S, 3), np.float32)
    for i in range(len(edges) - 1):
        x0, x1 = edges[i], edges[i + 1]
        sel = (xx >= x0) & (xx < x1)
        p = np.sin(np.pi * (xx - x0) / (x1 - x0))
        body = groove * (1 - _smooth(0.0, 0.42, p))[..., None] + base * _smooth(0.0, 0.42, p)[..., None]
        body = body + (light - base) * (p ** 2 * 0.55)[..., None]
        tint = rng.uniform(0, 0.35)
        body = body * (1 - tint * 0.3) + warm * (tint * 0.3)
        brk = np.zeros((S, S), np.float32)  # long plates broken by soft horizontal checks (periodic in y)
        yb = rng.uniform(0, 120)
        while yb < S:
            dyp = np.minimum(np.abs(yy - yb), S - np.abs(yy - yb))
            brk = np.maximum(brk, np.exp(-(dyp ** 2) / (2 * 6.0 ** 2)))
            yb += rng.uniform(110, 210)
        body = body * (1 - 0.16 * brk * _smooth(0.15, 0.6, p))[..., None]
        img = np.where(sel[..., None], body, img)
    return np.clip(img, 0, 1)


def save_texture(name, canvas, sub="mesh/textures", keep=True):
    S = canvas.shape[0]
    rgba = np.concatenate([canvas, np.ones((S, S, 1), np.float32)], axis=2)[::-1]  # bottom-up
    img = bpy.data.images.new(name, S, S, alpha=False)
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = str(OUT / sub / f"{name}.png")
    img.file_format = "PNG"
    img.save()
    if not keep:
        bpy.data.images.remove(img)
        return None
    img.pack()
    return img


def build_textures():
    """The approved rev_001 leaf tiles (same seeds, same pixels) become bake sources in source/art; bark ships."""
    leaves = {}
    for k, seed in [("leaf_A", 101), ("leaf_B", 202), ("leaf_C", 303)]:
        rgb, h = paint_leaves(TEX, LEAF_PAL[k], seed)
        save_texture(k, rgb, "source/art", keep=False)
        save_texture(k + "_height", np.repeat(h[..., None], 3, axis=2), "source/art", keep=False)
        leaves[k] = (rgb, h)
    return leaves, save_texture("bark", paint_bark(TEX, BARK_PAL, 404))


# ---------------------------------------------------------------------------------------------------------------
# Crown bake: every texel of the crown's own atlas is placed on the surface (rasterised in UV space), then coloured
# from the approved leaf tile through three planar projections at rev_001's leaf scale (X side, Y side, top),
# height-blended so whole leaves from one projection interlock with whole leaves from the next instead of meeting
# along a line. (rev_001's cylindrical side wrap was dropped: it shears leaves in the valleys between lobes.)
def sample_tile(tile, u, v):
    S = tile.shape[0]
    t = tile if tile.ndim == 3 else tile[..., None]
    x = (u % 1.0) * S - 0.5
    y = (1.0 - (v % 1.0)) * S - 0.5  # canvas row 0 is the top (v = 1)
    x0 = np.floor(x).astype(np.int64)
    y0 = np.floor(y).astype(np.int64)
    fx = (x - x0)[:, None]
    fy = (y - y0)[:, None]
    x0 %= S
    y0 %= S
    x1 = (x0 + 1) % S
    y1 = (y0 + 1) % S
    return (t[y0, x0] * (1 - fx) * (1 - fy) + t[y0, x1] * fx * (1 - fy)
            + t[y1, x0] * (1 - fx) * fy + t[y1, x1] * fx * fy)


BLEND = dict(top_from=0.42, top_to=0.82, side_power=4.0, height_k=0.5, depth=0.05)


def bake_crown(P, F, UV, N, center, k_u, rgb, h, res):
    R2 = res * 2  # 2x2 supersampling, box-filtered down
    pos = np.zeros((R2, R2, 3), np.float32)
    nor = np.zeros((R2, R2, 3), np.float32)
    fill = np.zeros((R2, R2), bool)
    for fi in range(len(F)):
        ia, ib, ic = F[fi]
        xs = UV[fi, :, 0] * R2
        ys = (1.0 - UV[fi, :, 1]) * R2
        x0, x1 = max(int(np.floor(xs.min())) - 1, 0), min(int(np.ceil(xs.max())) + 1, R2)
        y0, y1 = max(int(np.floor(ys.min())) - 1, 0), min(int(np.ceil(ys.max())) + 1, R2)
        if x0 >= x1 or y0 >= y1:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
        (xa, xb, xc), (ya, yb, yc) = xs, ys
        den = (yb - yc) * (xa - xc) + (xc - xb) * (ya - yc)
        if abs(den) < 1e-12:
            continue
        l1 = ((yb - yc) * (gx - xc) + (xc - xb) * (gy - yc)) / den
        l2 = ((yc - ya) * (gx - xc) + (xa - xc) * (gy - yc)) / den
        l3 = 1 - l1 - l2
        m = (l1 >= -0.02) & (l2 >= -0.02) & (l3 >= -0.02)
        if not m.any():
            continue
        pp = l1[..., None] * P[ia] + l2[..., None] * P[ib] + l3[..., None] * P[ic]
        nn = l1[..., None] * N[ia] + l2[..., None] * N[ib] + l3[..., None] * N[ic]
        inner = m & ~fill[y0:y1, x0:x1] | ((l1 >= 0) & (l2 >= 0) & (l3 >= 0))
        pos[y0:y1, x0:x1][inner] = pp[inner]
        nor[y0:y1, x0:x1][inner] = nn[inner]
        fill[y0:y1, x0:x1] |= m
    p = pos[fill]
    n = nor[fill]
    n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-6)
    cx, cy = center[0], center[1]
    x, y, z = p[:, 0] - cx, p[:, 1] - cy, p[:, 2]
    T = LEAF_TILE
    # three planar projections at the approved leaf scale: two sides (leaves hanging down, u flipped on the far
    # faces so leaves are never mirrored) and the top/underside; no projection is used where it would stretch
    sx = np.where(n[:, 0] >= 0, 1.0, -1.0)
    sy = np.where(n[:, 1] >= 0, -1.0, 1.0)
    projs = [((sx * y) / T, z / T), ((sy * x) / T, z / T), (x / T, y / T)]
    wt = _smooth(BLEND["top_from"], BLEND["top_to"], np.abs(n[:, 2]))
    wx, wy = np.abs(n[:, 0]) ** BLEND["side_power"], np.abs(n[:, 1]) ** BLEND["side_power"]
    side = (1 - wt) / np.maximum(wx + wy, 1e-6)
    weights = [wx * side, wy * side, wt]
    a = [w + BLEND["height_k"] * sample_tile(h, u, vv)[:, 0] for w, (u, vv) in zip(weights, projs)]
    ma = np.maximum(np.maximum(a[0], a[1]), a[2]) - BLEND["depth"]
    b = [np.maximum(ai - ma, 0) for ai in a]
    col = sum(sample_tile(rgb, u, vv) * bi[:, None] for bi, (u, vv) in zip(b, projs)) / (b[0] + b[1] + b[2])[:, None]
    big = np.zeros((R2, R2, 3), np.float32)
    big[fill] = col
    acc = big.reshape(res, 2, res, 2, 3).sum(axis=(1, 3))
    cnt = fill.reshape(res, 2, res, 2).sum(axis=(1, 3)).astype(np.float32)
    have = cnt > 0
    img = np.zeros((res, res, 3), np.float32)
    img[have] = acc[have] / cnt[have][:, None]
    for _ in range(64):  # dilate past the island borders so mipmaps don't pull in empty texels
        if have.all():
            break
        ps = np.pad(img * have[..., None], ((1, 1), (1, 1), (0, 0)))
        ph = np.pad(have.astype(np.float32), 1)
        ssum = ps[:-2, 1:-1] + ps[2:, 1:-1] + ps[1:-1, :-2] + ps[1:-1, 2:]
        scnt = ph[:-2, 1:-1] + ph[2:, 1:-1] + ph[1:-1, :-2] + ph[1:-1, 2:]
        new = ~have & (scnt > 0)
        img[new] = ssum[new] / scnt[new][:, None]
        have |= new
    img[~have] = img[have].mean(axis=0)
    coverage = float(fill.mean())
    return np.clip(img, 0, 1), coverage


def smart_uv(verts, faces):
    me = bpy.data.meshes.new("uvtmp")
    me.from_pydata([tuple(v) for v in verts], [], [tuple(f) for f in faces])
    me.update()
    me.uv_layers.new(name="UVMap")
    ob = bpy.data.objects.new("uvtmp", me)
    bpy.context.scene.collection.objects.link(ob)
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(70), island_margin=0.02, area_weight=0.0,
                             correct_aspect=True, scale_to_bounds=False)
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(rotate=True, margin=0.012)  # tighter packing: more texels per unit
    bpy.ops.object.mode_set(mode="OBJECT")
    uv = np.zeros((len(faces), 3, 2), np.float64)
    data = me.uv_layers.active.data
    for fi, poly in enumerate(me.polygons):
        for k, li in enumerate(poly.loop_indices):
            uv[fi, k] = data[li].uv
    bpy.data.objects.remove(ob)
    bpy.data.meshes.remove(me)
    return uv


# ---------------------------------------------------------------------------------------------------------------
# Geometry helpers: parts are accumulated as plain lists, then turned into one mesh.
class Part:
    def __init__(self):
        self.verts, self.faces, self.uvs, self.normals, self.mats = [], [], [], [], []  # per face corner / face

    def add_tri(self, ids, uvs, nrm, mat=0):
        self.mats.append(mat)
        self.faces.append(tuple(ids))
        self.uvs.append(tuple(uvs))
        self.normals.append(tuple(nrm))


def tube(part, path, radii, sides, rings_v, flare=None, cap_bottom=False):
    """Loft a tube through `path` points with radii; analytic radial normals; cylindrical bark UVs.
    Returns the vertex ids of its first and last rings (open unless capped)."""
    base = len(part.verts)
    n = len(path)
    ring_frames = []
    for i in range(n):
        p = path[i]
        t = (path[min(i + 1, n - 1)] - path[max(i - 1, 0)]).normalized()
        ref = Vector((1, 0, 0)) if abs(t.x) < 0.9 else Vector((0, 1, 0))
        u = (ref - t * ref.dot(t)).normalized()
        w = t.cross(u)
        ring_frames.append((p, t, u, w))
    for i, (p, t, u, w) in enumerate(ring_frames):
        for j in range(sides + 1):
            th = 2 * math.pi * j / sides
            r = radii[i] * (flare(i, th) if flare else 1.0)
            d = u * math.cos(th) + w * math.sin(th)
            part.verts.append(p + d * r)
    nrm = {}
    for i in range(n):
        for j in range(sides + 1):
            p, t, u, w = ring_frames[i]
            a = part.verts[base + i * (sides + 1) + j]
            # normal from the neighbouring ring points (handles taper and root flare)
            jn, jp = (j + 1) % (sides + 1), (j - 1) % (sides + 1)
            if j == sides:
                jn, jp = 1, sides - 1
            if j == 0:
                jn, jp = 1, sides - 1
            i0, i1 = max(i - 1, 0), min(i + 1, n - 1)
            tang = part.verts[base + i * (sides + 1) + jn] - part.verts[base + i * (sides + 1) + jp]
            up = part.verts[base + i1 * (sides + 1) + j] - part.verts[base + i0 * (sides + 1) + j]
            nv = tang.cross(up).normalized()
            if nv.dot(a - p) < 0:
                nv = -nv
            nrm[(i, j)] = nv
    for i in range(n - 1):
        for j in range(sides):
            a = base + i * (sides + 1) + j
            b, c, d = a + 1, a + sides + 1, a + sides + 2
            uv = lambda ii, jj: (jj / sides, rings_v[ii])
            part.add_tri((a, b, d), (uv(i, j), uv(i, j + 1), uv(i + 1, j + 1)),
                         (nrm[(i, j)], nrm[(i, j + 1)], nrm[(i + 1, j + 1)]), 1)
            part.add_tri((a, d, c), (uv(i, j), uv(i + 1, j + 1), uv(i + 1, j)),
                         (nrm[(i, j)], nrm[(i + 1, j + 1)], nrm[(i + 1, j)]), 1)
    first = [base + j for j in range(sides)]
    last = [base + (n - 1) * (sides + 1) + j for j in range(sides)]
    if cap_bottom:  # a fan facing down along -t at the first ring (the trunk's ground contact)
        c0 = len(part.verts)
        part.verts.append(ring_frames[0][0].copy())
        down = -ring_frames[0][1]
        for j in range(sides):
            a, b = base + j, base + j + 1
            part.add_tri((c0, b, a), ((0.5, rings_v[0]), ((j + 1) / sides, rings_v[0]), (j / sides, rings_v[0])),
                         (down, down, down), 1)
        first = []
    return first, last


def crown_lobes(v):
    rng = random.Random(v["seed"])
    lobes = [(Vector((0, 0, 0.05)), 0.62)]
    for k in range(v["ring"]):
        ang = 2 * math.pi * k / v["ring"] + rng.uniform(-0.25, 0.25)
        rr = v["ring_r"] * rng.uniform(0.92, 1.08)
        lobes.append((Vector((math.cos(ang) * rr, math.sin(ang) * rr, rng.uniform(-0.1, 0.12))), rng.uniform(0.4, 0.5)))
    for k in range(v["top"]):
        ang = 2 * math.pi * k / v["top"] + rng.uniform(0, 1.0)
        rr = rng.uniform(0.18, 0.3)
        lobes.append((Vector((math.cos(ang) * rr, math.sin(ang) * rr, 0.42 * v["flat"] + rng.uniform(-0.05, 0.05))),
                      rng.uniform(0.38, 0.46)))
    for k in range(v["low"]):
        ang = 2 * math.pi * (k + 0.5) / v["low"] + rng.uniform(-0.3, 0.3)
        rr = rng.uniform(0.32, 0.42)
        lobes.append((Vector((math.cos(ang) * rr, math.sin(ang) * rr, -0.3)), rng.uniform(0.34, 0.4)))
    return lobes


def eval_mesh(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    return me


def crown_base_mesh(name, v):
    """High-resolution crown surface: metaball union of the lobes, voxel-remeshed and smoothed."""
    mb = bpy.data.metaballs.new(name + "_mb")
    mb.resolution = mb.render_resolution = 0.03
    mb.threshold = 0.6
    lobes = crown_lobes(v)
    for c, r in lobes:
        e = mb.elements.new()
        e.co = c
        e.radius = r
        e.stiffness = 3.2  # high stiffness keeps lobes distinct instead of one smooth ball
    mob = bpy.data.objects.new(name + "_mb", mb)
    bpy.context.scene.collection.objects.link(mob)
    me = eval_mesh(mob)
    bpy.data.objects.remove(mob)
    ob = bpy.data.objects.new(name + "_hi", me)
    bpy.context.scene.collection.objects.link(ob)
    rm = ob.modifiers.new("remesh", "REMESH")
    rm.mode = "VOXEL"
    rm.voxel_size = 0.025
    sm = ob.modifiers.new("smooth", "SMOOTH")
    sm.factor, sm.iterations = 0.5, 6
    me2 = eval_mesh(ob)
    bpy.data.objects.remove(ob)
    return me2, lobes


def decimated(me, target_tris):
    ob = bpy.data.objects.new("dec_tmp", me)
    bpy.context.scene.collection.objects.link(ob)
    bm = bmesh.new()
    bm.from_mesh(me)
    tris = sum(len(f.verts) - 2 for f in bm.faces)
    bm.free()
    dm = ob.modifiers.new("dec", "DECIMATE")
    dm.decimate_type = "COLLAPSE"
    dm.ratio = min(1.0, target_tris / max(tris, 1))
    dm.use_collapse_triangulate = True
    out = eval_mesh(ob)
    bpy.data.objects.remove(ob)
    return out


def build_crown(part, v, base_me, lobes, lod):
    """Decimate, place, UV per lobe, soften normals. Returns the crown placement for reporting."""
    me = decimated(base_me.copy(), LODS[lod]["crown"])
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    lo = Vector([min(vt.co[k] for vt in bm.verts) for k in range(3)])
    hi = Vector([max(vt.co[k] for vt in bm.verts) for k in range(3)])
    size = hi - lo
    Hc = v["H"] - v["crown_bottom"]
    sx, sy, sz = v["W"] / size.x, v["D"] / size.y, Hc / size.z
    cx = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    top = Vector((v["lean"][0], v["lean"][1], v["crown_bottom"]))

    def place(p):
        q = p - cx
        return Vector((q.x * sx, q.y * sy, q.z * sz)) + top

    sl = (sx * sy * sz) ** (1 / 3)
    plobes = [(place(c), r * sl) for c, r in lobes]
    center = top + Vector((0, 0, Hc * 0.5))
    ell = Vector((v["W"] / 2, v["D"] / 2, Hc / 2))
    base = len(part.verts)
    vmap = {}
    for vt in bm.verts:
        vmap[vt.index] = len(part.verts)
        part.verts.append(place(vt.co))
    # geometry normals of the placed mesh (non-uniform scale), smooth per vertex
    acc = {i: Vector() for i in vmap.values()}
    for f in bm.faces:
        ids = [vmap[vt.index] for vt in f.verts]
        a, b, c = (part.verts[i] for i in ids)
        fn = (b - a).cross(c - a)
        for i in ids:
            acc[i] += fn
    # Leaf placement keeps rev_001's world scale (one tile per LEAF_TILE): side wrap with a whole number of tiles
    # around, top/underside projected from above. rev_002 bakes both into the crown's own atlas, height-blended.
    R_avg = (v["W"] + v["D"]) / 4
    n_around = max(3, round(2 * math.pi * R_avg / LEAF_TILE))
    k_u = n_around / (2 * math.pi)
    ids_all = [[vmap[vt.index] for vt in f.verts] for f in bm.faces]
    local = np.array([[i - base for i in ids] for ids in ids_all], np.int64)
    P = np.array([tuple(part.verts[i]) for i in range(base, len(part.verts))], np.float32)
    G = np.array([tuple(acc[i].normalized()) for i in range(base, len(part.verts))], np.float32)
    UV = smart_uv(P, local)
    rgb, hgt = LEAVES[v["leaf"]]
    tex, coverage = bake_crown(P, local, UV, G, (center.x, center.y), k_u, rgb, hgt, LODS[lod]["tex"])
    area3, areauv = 0.0, 0.0
    for fi, ids in enumerate(ids_all):
        a3, b3, c3 = (part.verts[i] for i in ids)
        area3 += (b3 - a3).cross(c3 - a3).length / 2
        (ua, va), (ub, vb), (uc, vc) = UV[fi]
        areauv += abs((ub - ua) * (vc - va) - (uc - ua) * (vb - va)) / 2
        nrms = []
        for i in ids:
            p = part.verts[i]
            g = acc[i].normalized()
            e = p - center
            soft = Vector((e.x / ell.x ** 2, e.y / ell.y ** 2, e.z / ell.z ** 2)).normalized()
            nrms.append((g * 0.45 + soft * 0.55).normalized())
        part.add_tri(ids, [tuple(x) for x in UV[fi]], nrms, 0)
    density = LODS[lod]["tex"] * math.sqrt(areauv / area3)
    bm.free()
    bpy.data.meshes.remove(me)
    return dict(lobes=len(lobes), crown_height=Hc, texture=tex, texel_density=round(density, 1),
                uv_coverage=round(areauv, 4), surface_area=round(area3, 3))


def build_trunk(part, v, lod, lobes_placed):
    L = LODS[lod]
    rng = random.Random(v["seed"] * 7)
    th_top = v["crown_bottom"] + 0.35 * (v["H"] - v["crown_bottom"])
    zs = [th_top * f for f in [0.0, 0.035, 0.09, 0.18, 0.32, 0.5, 0.72, 1.0][:: max(1, 8 // L["rings"])]]
    if zs[-1] != th_top:
        zs.append(th_top)
    lean = Vector((v["lean"][0], v["lean"][1], 0))
    path = [Vector((0, 0, z)) + lean * (z / th_top) ** 2 for z in zs]
    radii = [v["top_r"] + (v["base_r"] - v["top_r"]) * (1 - (z / th_top)) ** 1.6 for z in zs]
    phase = rng.uniform(0, 2 * math.pi)
    nroots = v["roots"]
    root_amp = [rng.uniform(0.75, 1.2) for _ in range(nroots)]

    def flare(i, th):
        z = zs[i]
        k = (th - phase) * nroots / (2 * math.pi)
        idx = int(math.floor(k + 0.5)) % nroots
        bump = max(0.0, math.cos(2 * math.pi * (k - math.floor(k + 0.5)))) ** 2.2 * root_amp[idx]
        return 1.0 + math.exp(-z / 0.09) * (0.45 + 1.25 * bump) + math.exp(-z / 0.32) * 0.22 * bump

    rings_v = [z / BARK_TILE_V for z in zs]
    f0 = len(part.faces)
    _, top_ring = tube(part, path, radii, L["sides"], rings_v, flare, cap_bottom=True)
    trunk_faces = (f0, len(part.faces))
    open_ends = [("trunk top", top_ring, "crown")]
    if L["branches"]:
        lower = sorted(lobes_placed, key=lambda l: l[0].z)[: 3 if lod == 0 else 2]
        for lc, lr in lower:
            s = path[-2] + (path[-1] - path[-2]) * 0.3
            d = lc - s
            end = s + d * 0.75
            mid = s + d * 0.4 + Vector((0, 0, 0.12))
            bpath = [s, mid, end]
            blen = [0.0, (mid - s).length, (mid - s).length + (end - mid).length]
            b0, b1 = tube(part, bpath, [v["top_r"] * 0.55, v["top_r"] * 0.42, v["top_r"] * 0.3], 6 if lod == 0 else 5,
                          [(th_top * 0.8 + x) / BARK_TILE_V for x in blen])
            open_ends += [("branch base", b0, "trunk"), ("branch tip", b1, "crown")]
    return dict(trunk_top=th_top, trunk_faces=trunk_faces, open_ends=open_ends)


def open_end_report(part, tinfo):
    """Every remaining open tube end must lie inside the solid that hides it (crown or trunk): nearest-surface test."""
    from mathutils.bvhtree import BVHTree
    crown = BVHTree.FromPolygons(part.verts, [f for f, m in zip(part.faces, part.mats) if m == 0])
    t0, t1 = tinfo["trunk_faces"]
    trunk = BVHTree.FromPolygons(part.verts, part.faces[t0:t1])
    out = []
    for name, ring, where in tinfo["open_ends"]:
        bvh = crown if where == "crown" else trunk
        depths = []
        for i in ring:
            q = part.verts[i]
            loc, nrm, _, dist = bvh.find_nearest(q)
            depths.append(dist if (q - loc).dot(nrm) < 0 else -dist)
        out.append(dict(end=name, inside=where, ring_vertices=len(ring), all_inside=min(depths) > 0,
                        min_depth=round(min(depths), 4)))
    return out


def part_to_object(part, name, mats):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(p) for p in part.verts], [], part.faces)
    uvl = me.uv_layers.new(name="UVMap")
    loops_n = []
    for fi, poly in enumerate(me.polygons):
        for k, li in enumerate(poly.loop_indices):
            uvl.data[li].uv = part.uvs[fi][k]
            loops_n.append(part.normals[fi][k])
    me.update()
    for poly in me.polygons:
        poly.use_smooth = True
    for poly, m in zip(me.polygons, part.mats):
        poly.material_index = m
    me.normals_split_custom_set([tuple(n) for n in loops_n])
    for mat in mats:
        me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def make_material(name, img):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Linear"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85
    mat.use_backface_culling = True  # closed solids: exported single-sided (glTF doubleSided false)
    bsdf.inputs["Specular IOR Level"].default_value = 0.25
    return mat


# ---------------------------------------------------------------------------------------------------------------
def load_source(scale_h=3.0):
    d = json.loads(SRC_JSON.read_text())
    verts, faces = [], []
    for t in range(0, len(d["v"]), 3):
        ids = []
        for k in range(3):
            p = d["v"][t + k]
            verts.append((p[0] * scale_h, -p[2] * scale_h, p[1] * scale_h))
            ids.append(len(verts) - 1)
        faces.append(ids)
    me = bpy.data.meshes.new("source_oak")
    me.from_pydata(verts, [], faces)
    uvl = me.uv_layers.new(name="UVMap")
    for fi, poly in enumerate(me.polygons):
        for k, li in enumerate(poly.loop_indices):
            u, vv = d["uv"][faces[fi][k]]
            uvl.data[li].uv = (u, vv)
    me.update()
    img = bpy.data.images.load(d["texture"].replace("res://", str(ROOT) + "/"))
    mat = bpy.data.materials.new("source_palette")
    mat.use_nodes = True
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    mat.node_tree.links.new(tex.outputs["Color"], mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    me.materials.append(mat)
    ob = bpy.data.objects.new("source_oak", me)
    bpy.context.scene.collection.objects.link(ob)
    return ob, len(faces)


def rework_attempt(src):
    """Best-effort rework of the derivative: close holes/loose bits and round the facets, at the target budget."""
    bm = bmesh.new()
    bm.from_mesh(src.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.004)
    # drop loose fragments (the floating leaf scraps), keep the big islands
    seen, islands = set(), []
    for f in bm.faces:
        if f in seen:
            continue
        stack, isl = [f], []
        seen.add(f)
        while stack:
            g = stack.pop()
            isl.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h not in seen:
                        seen.add(h)
                        stack.append(h)
        islands.append(isl)
    bmesh.ops.delete(bm, geom=[f for isl in islands if len(isl) < 40 for f in isl], context="FACES")
    bmesh.ops.holes_fill(bm, edges=bm.edges[:], sides=0)
    me0 = bpy.data.meshes.new("rework_clean")
    bm.to_mesh(me0)
    bm.free()
    ob = bpy.data.objects.new("rework_oak", me0)
    bpy.context.scene.collection.objects.link(ob)
    rm = ob.modifiers.new("remesh", "REMESH")
    rm.mode, rm.voxel_size = "VOXEL", 0.03
    sm = ob.modifiers.new("smooth", "SMOOTH")
    sm.factor, sm.iterations = 0.5, 4
    me = eval_mesh(ob)
    bpy.data.objects.remove(ob)
    me2 = decimated(me, 2000)
    ob = bpy.data.objects.new("rework_oak", me2)
    bpy.context.scene.collection.objects.link(ob)
    for p in me2.polygons:
        p.use_smooth = True
    m = bpy.data.materials.new("rework_grey")
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.35, 0.55, 0.3, 1)
    me2.materials.append(m)
    return ob, len(me2.polygons)


def tri_count(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


# ---------------------------------------------------------------------------------------------------------------
def setup_render(res=(800, 1000)):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE_NEXT"
    sc.eevee.taa_render_samples = 48
    sc.eevee.use_shadows = True
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.film_transparent = False
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
        # 1-unit grid lines: |fract(x)-0.5| near 0.5
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
            vt.co.z = (vt.co.z + 0.2) / 0.4 * HERO_H  # a 0.4-wide figure at hero height
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
    cam.rotation_euler = (target - loc).to_track_quat("-Z", "Y").to_euler()


def show_only(objs, ground=True):
    keep = set(o.name for o in objs) | {"key", "cam"} | ({"preview_ground"} if ground else set())
    for o in bpy.data.objects:
        o.hide_render = o.name not in keep


def render(path):
    bpy.context.scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


# ---------------------------------------------------------------------------------------------------------------
def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    report = dict(revision=REV, generator="tools/blender/art_candidates/broadleaf/broadleaf_candidate.py",
                  blender=bpy.app.version_string, units="1 unit = 1 game tile; Z-up in .blend, Y-up in glTF",
                  hero_reference_height=HERO_H,
                  textures=dict(crown="one baked atlas per variant and LOD (1024 / 512 / 256), mesh/textures/crown_<V>_lod<N>.png",
                                bark="mesh/textures/bark.png, 512 seamless tile (unchanged from rev_001)",
                                bake_sources="source/art/leaf_<A|B|C>.png (the approved rev_001 tiles, identical "
                                             "pixels) and leaf_<A|B|C>_height.png (blend mask only)",
                                leaf_tile_world_units=LEAF_TILE, bark_tile_world_units_v=BARK_TILE_V, blend=BLEND,
                                smoothing="NOT smoothed (left for integration)"),
                  variants={})
    global LEAVES
    LEAVES, bark_img = build_textures()
    mats = {"bark": make_material("broadleaf_bark", bark_img)}

    src, src_tris = load_source()
    rew, rew_tris = rework_attempt(src)
    report["source"] = dict(path=str(SRC_JSON.relative_to(ROOT)).replace("\\", "/"), triangles=src_tris,
                            produced_by="tools/prepare_stylized_nature.py (Environment Pack - Stylized Nature, model_0, tree_oak box)",
                            texture="build/nature_source/Stylized Nature/collection/Texture_BaseColor_v02.png (flat palette swatches)")
    report["rework_attempt"] = dict(triangles=rew_tris, method="merge by distance, delete islands under 40 faces, fill holes, voxel remesh 0.03, smooth, decimate to 2000",
                                    result="closes the crown hole and drops loose fragments, but stays two stacked domes; "
                                           "no leaf clusters, no root flare, short cut trunk; palette UVs carry no leaf texture")

    objects = {}
    for key, v in VARIANTS.items():
        base_me, lobes = crown_base_mesh("crown_" + key, v)
        for lod in LODS:
            part = Part()
            info = build_crown(part, v, base_me, lobes, lod)
            # placed lobes again for branch targets (same transform as build_crown)
            lo = Vector([min(vt.co[k] for vt in base_me.vertices) for k in range(3)])
            hi = Vector([max(vt.co[k] for vt in base_me.vertices) for k in range(3)])
            size = hi - lo
            Hc = v["H"] - v["crown_bottom"]
            s = Vector((v["W"] / size.x, v["D"] / size.y, Hc / size.z))
            cx = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
            top = Vector((v["lean"][0], v["lean"][1], v["crown_bottom"]))
            placed = [(Vector(((c - cx).x * s.x, (c - cx).y * s.y, (c - cx).z * s.z)) + top, r) for c, r in lobes]
            tinfo = build_trunk(part, v, lod, placed)
            ends = open_end_report(part, tinfo)
            cimg = save_texture(f"crown_{key}_lod{lod}", info["texture"])
            cmat = make_material(f"broadleaf_crown_{key}_lod{lod}", cimg)
            ob = part_to_object(part, f"broadleaf_{key}_lod{lod}", [cmat, mats["bark"]])
            objects[(key, lod)] = ob
            bb = [Vector(c) for c in ob.bound_box]
            mn = [min(c[k] for c in bb) for k in range(3)]
            mx = [max(c[k] for c in bb) for k in range(3)]
            path = OUT / f"mesh/broadleaf_{key}_lod{lod}.gltf"
            bpy.ops.object.select_all(action="DESELECT")
            ob.select_set(True)
            bpy.context.view_layer.objects.active = ob
            bpy.ops.export_scene.gltf(filepath=str(path), use_selection=True, export_format="GLTF_SEPARATE",
                                      export_texture_dir="textures", export_yup=True, export_apply=True,
                                      export_normals=True, export_texcoords=True, export_materials="EXPORT",
                                      export_image_format="AUTO")
            rec = report["variants"].setdefault(key, dict(label=v["label"], params={k: v[k] for k in v}, lods={}))
            rec["lods"][str(lod)] = dict(triangles=tri_count(ob), vertices=len(ob.data.vertices), materials=2,
                                         textures=2, texture_files=[f"textures/crown_{key}_lod{lod}.png", "textures/bark.png"],
                                         double_sided=False, open_ends=ends,
                                         crown_texel_density_px_per_unit=info["texel_density"],
                                         crown_uv_coverage=info["uv_coverage"],
                                         crown_texture_size=LODS[lod]["tex"],
                                         crown_triangles=sum(1 for m in part.mats if m == 0),
                                         trunk_triangles=sum(1 for m in part.mats if m == 1), file=path.name,
                                         bbox_min_zup=[round(x, 4) for x in mn], bbox_max_zup=[round(x, 4) for x in mx],
                                         height=round(mx[2] - mn[2], 4), width_x=round(mx[0] - mn[0], 4),
                                         depth_y=round(mx[1] - mn[1], 4), lobes=info["lobes"],
                                         trunk_top=round(tinfo["trunk_top"], 3))
        bpy.data.meshes.remove(base_me)

    # Lay the variants out side by side in the source scene (export used their own origins).
    for (key, lod), ob in objects.items():
        ob.location = (("A", "B", "C").index(key) * 4.0 - 4.0, lod * 5.0, 0)
    src.location = (-9.0, 0, 0)
    rew.location = (-13.0, 0, 0)

    if RENDER:
        renders(objects, src, rew)
        checks(objects)
        for (key, lod), ob in objects.items():
            ob.location = (("A", "B", "C").index(key) * 4.0 - 4.0, lod * 5.0, 0)
        src.location = (-9.0, 0, 0)
        rew.location = (-13.0, 0, 0)
        for o in bpy.data.objects:
            o.hide_render = False

    (OUT / "build_report.json").write_text(json.dumps(report, indent=1))
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "source/broadleaf_candidate.blend"), compress=True)
    print("BROADLEAF DONE", OUT)


def renders(objects, src, rew):
    sc, cam = setup_render()
    R = OUT / "renders"
    hero = bpy.data.objects["hero_ref"]
    # turntables: LOD0, 8 azimuths, low elevation, orthographic, hero reference beside it
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 4.6
    sc.render.resolution_x, sc.render.resolution_y = 520, 600
    for key in VARIANTS:
        ob = objects[(key, 0)]
        ob.location = (0, 0, 0)
        hero.location = (1.75, 0.6, 0)
        show_only([ob, hero])
        for i in range(8):
            a = math.radians(i * 45)
            ob.rotation_euler = (0, 0, a)
            aim(cam, Vector((0, -14, 2.9)), Vector((0.35, 0, 1.55)))
            render(R / f"turn_{key}_{i}.png")
        ob.rotation_euler = (0, 0, 0)
    # LOD sheet: gameplay pitch, orthographic
    pitch = math.atan2(6.0, 11.0)
    cam.data.ortho_scale = 4.4
    sc.render.resolution_x, sc.render.resolution_y = 480, 480
    for key in VARIANTS:
        for lod in LODS:
            ob = objects[(key, lod)]
            ob.location = (0, 0, 0)
            show_only([ob])
            aim(cam, Vector((0, -math.cos(pitch) * 20, math.sin(pitch) * 20 + 1.5)), Vector((0, 0, 1.5)))
            render(R / f"lod_{key}_{lod}.png")
    # source / rework / candidate comparison (front, same ortho scale)
    cam.data.ortho_scale = 4.6
    sc.render.resolution_x, sc.render.resolution_y = 520, 600
    for name, ob in [("source", src), ("rework", rew), ("A", objects[("A", 0)])]:
        ob.location = (0, 0, 0)
        show_only([ob, hero])
        aim(cam, Vector((0, -14, 2.9)), Vector((0.35, 0, 1.55)))
        render(R / f"compare_{name}.png")
        aim(cam, Vector((0, -math.cos(pitch) * 20, math.sin(pitch) * 20 + 1.5)), Vector((0.35, 0, 1.5)))
        render(R / f"compare_{name}_game.png")
    # gameplay-angle grove: the game's camera (fov 36 vertical, offset (0, 7, 11) from the target, looking at
    # target + 1 up). Godot -Z (north) is Blender +Y. Trees on tile centres, a tile apart, as woods are planted.
    cam.data.type = "PERSP"
    cam.data.sensor_fit = "VERTICAL"
    cam.data.angle_y = math.radians(36)
    sc.render.resolution_x, sc.render.resolution_y = 1920, 1080
    grove = []
    spots = [("A", (-3, 3), 0.3, 1.0), ("B", (0, 4), 1.2, 1.1), ("C", (3, 3), 2.0, 0.92), ("A", (-5, 6), 4.0, 1.1),
             ("C", (-1, 7), 5.0, 1.05), ("B", (2, 7), 0.7, 0.95), ("A", (5, 6), 2.6, 0.9), ("B", (-4, -1), 3.3, 0.85),
             ("C", (4, -1), 1.7, 0.9)]
    for i, (key, (x, y), rot, s) in enumerate(spots):
        src_ob = objects[(key, 0)]
        inst = bpy.data.objects.new(f"grove_{i}", src_ob.data)
        sc.collection.objects.link(inst)
        inst.location = (x, y, 0)
        inst.rotation_euler = (0, 0, rot)
        inst.scale = (s, s, s)
        grove.append(inst)
    hero.location = (0, 0, 0)
    show_only(grove + [hero])
    aim(cam, Vector((0, -11, 7)), Vector((0, 0, 1)))
    render(R / "gameplay_grove.png")
    for o in grove:
        bpy.data.objects.remove(o)



def checks(objects):
    """Backface check (culling off, back faces glow red: any red = wrong winding or a visible hole) and matched seam
    close-ups against the published comparison revision (imported read-only from its glTF)."""
    sc, cam = setup_render()
    R = OUT / "renders"
    dbg = bpy.data.materials.new("backface_check")
    dbg.use_nodes = True
    dbg.use_backface_culling = False
    nt = dbg.node_tree
    out = nt.nodes["Material Output"]
    front = nt.nodes["Principled BSDF"]
    front.inputs["Base Color"].default_value = (0.55, 0.62, 0.5, 1)
    back = nt.nodes.new("ShaderNodeEmission")
    back.inputs["Color"].default_value = (1, 0, 0, 1)
    back.inputs["Strength"].default_value = 3.0
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(geo.outputs["Backfacing"], mix.inputs[0])
    nt.links.new(front.outputs[0], mix.inputs[1])
    nt.links.new(back.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    cam.data.type = "ORTHO"
    sc.render.resolution_x, sc.render.resolution_y = 360, 360
    for key, v in VARIANTS.items():
        for lod in LODS:
            ob = objects[(key, lod)]
            ob.location = (0, 0, 0)
            saved = list(ob.data.materials)
            for i in range(len(saved)):
                ob.data.materials[i] = dbg
            views = {"under": (4.6, Vector((0, -9, -4)), Vector((0, 0, 1.6)), False),
                     "roots": (1.6, Vector((0, -9, 1.6)), Vector((0, 0, 0.3)), True),
                     "junction": (2.2, Vector((0, -9, -1.5)), Vector((v["lean"][0], 0, v["crown_bottom"])), False),
                     "top": (3.4, Vector((0, -1, 14)), Vector((0, 0, 1.5)), False)}
            for az in ((0, 180) if lod == 0 else (0,)):
                ob.rotation_euler = (0, 0, math.radians(az))
                for name, (scale, loc, tgt, ground) in views.items():
                    cam.data.ortho_scale = scale
                    show_only([ob], ground)
                    aim(cam, loc, tgt)
                    render(R / f"cull_{key}_lod{lod}_{name}_{az}.png")
            ob.rotation_euler = (0, 0, 0)
            for i, m in enumerate(saved):
                ob.data.materials[i] = m
    # positive control: the source oak has an open crown, so its inside must show red through the hole
    srcob = bpy.data.objects.get("source_oak")
    if srcob:
        srcob.location = (0, 0, 0)
        saved = list(srcob.data.materials)
        srcob.data.materials[0] = dbg
        cam.data.ortho_scale = 4.6
        show_only([srcob])
        aim(cam, Vector((0, -14, 2.9)), Vector((0.35, 0, 1.55)))
        render(R / "cull_control_source.png")
        srcob.data.materials[0] = saved[0]
    # matched seam close-ups: gameplay pitch and fov, 6.5 units from the crown, three turns of the tree
    cmp_dir = ROOT / "build/art_candidates/broadleaf" / COMPARE
    if not (cmp_dir / "READY.json").exists():
        print("no published comparison revision", COMPARE)
        return
    cam.data.type = "PERSP"
    cam.data.sensor_fit = "VERTICAL"
    cam.data.angle_y = math.radians(36)
    sc.render.resolution_x, sc.render.resolution_y = 640, 640
    off = Vector((0, -11, 7)).normalized() * 5.2
    for key, v in VARIANTS.items():
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(cmp_dir / f"mesh/broadleaf_{key}_lod0.gltf"))
        old = [o for o in bpy.data.objects if o not in before and o.type == "MESH"][0]
        old.rotation_mode = "XYZ"  # glTF import uses quaternions; the turns below set Euler angles
        new = objects[(key, 0)]
        tgt = Vector((v["lean"][0], v["lean"][1], v["crown_bottom"] + 0.55 * (v["H"] - v["crown_bottom"])))
        for tag, ob in ((COMPARE, old), (REV, new)):
            ob.location = (0, 0, 0)
            for rot in (0, 120, 240):
                ob.rotation_euler = (0, 0, math.radians(rot))
                show_only([ob])
                aim(cam, tgt + off, tgt)
                render(R / f"seam_{key}_{rot}_{tag}.png")
            ob.rotation_euler = (0, 0, 0)
        bpy.data.objects.remove(old)

if __name__ == "__main__":  # importable by broadleaf_rework.py for its shared render helpers
    main()
