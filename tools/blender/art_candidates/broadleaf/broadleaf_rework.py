"""Broadleaf candidate rev_003+: a rework of a user-supplied CC-BY-4.0 model (preproduction for runbook 027).

    python tools/local_resource.py -- "<blender.exe>" -b --factory-startup \
        -P tools/blender/art_candidates/broadleaf/broadleaf_rework.py -- --rev rev_003 --compare-rev rev_002

Source (read-only, kept as supplied with its SHA-256 in READY.json):
    build/art_candidates/broadleaf/sources/stylized_tree_roroer/stylized_tree.glb
    "Stylized tree" by roroer, https://sketchfab.com/3d-models/stylized-tree-6ba26deef34249ddb8694888b47db449
    CC-BY-4.0 (credit required at integration).
User direction (2026-11-12): fewer individual leaves, pillowy and simple crowns; rework this model (not a style
reference). What the rework does:
  * keeps the model's painted dome shells (scalloped skirts, soft painted leaf marks) and trunk with its arms;
  * recolours its texture to the approved rev_001 A/B/C leaf palettes and bark palette by luminance mapping (the
    painting is preserved; near-black trunk shading is lifted to the bark groove colour);
  * adds the approved root flare at the trunk base (extra rings, flared fins) and caps the base;
  * arranges / scales the dome groups per variant (A round, B tall, C wide) and decimates to the provisional budget;
  * exports single-sided, one material and one texture per variant, three LODs.
Render/check helpers are shared with broadleaf_candidate.py (imported; its main() does not run).
"""
import bpy, bmesh, json, sys, math, pathlib, random
import numpy as np
from mathutils import Vector, Matrix

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import broadleaf_candidate as bc  # noqa: E402  (parses --rev / --compare-rev and owns OUT)

ROOT, OUT, REV = bc.ROOT, bc.OUT, bc.REV
SRC = ROOT / "build/art_candidates/broadleaf/sources/stylized_tree_roroer/stylized_tree.glb"
GROUPS = {"centre": ["Cylinder.002", "Cylinder.004", "Cylinder.005"], "right": ["Cylinder", "Cylinder.001"],
          "left_front": ["Cylinder.006", "Cylinder.007"], "left_back": ["Cylinder.008", "Cylinder.009"]}
# per variant: overall envelope (from the approved rev_001 variants), the centre stack's vertical stretch, how far
# the side groups move out (1 = as modelled) and up, and extra groups copied from an existing one and turned.
VARIANTS = {
    "A": dict(label="round oak", H=3.0, W=2.55, D=2.4, leaf="leaf_A", centre_z=1.0, side_out=1.0, side_up=0.0,
              extra=[], roots=5, seed=11),
    "B": dict(label="tall linden", H=3.4, W=2.3, D=2.2, leaf="leaf_B", centre_z=1.15, side_out=0.85, side_up=0.1,
              extra=[], roots=4, seed=23),
    "C": dict(label="wide chestnut", H=2.8, W=2.75, D=2.55, leaf="leaf_C", centre_z=0.82, side_out=1.12, side_up=-0.04,
              extra=[("right", 150.0)], roots=6, seed=37),
}
LODS = {0: dict(crown=2150, trunk=1.0), 1: dict(crown=800, trunk=0.55), 2: dict(crown=380, trunk=0.3)}
TRUNK_XY = 0.82  # slimmer than modelled, closer to the game's trunks beside the 1.44 hero


def mesh_world(ob):
    me = ob.data.copy()
    me.transform(ob.matrix_world)
    return me


def load_source():
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(SRC))
    bpy.context.view_layer.update()
    obs = [o for o in bpy.data.objects if o not in before]
    pieces = {}
    for o in obs:
        if o.type == "MESH":
            base = o.name.split("_Material")[0]
            pieces[base] = mesh_world(o)
    src_img = [o for o in obs if o.type == "MESH"][0].data.materials[0].node_tree.nodes
    img = [n for n in src_img if n.type == "TEX_IMAGE"][0].image
    for o in obs:
        bpy.data.objects.remove(o)
    # normalise: trunk base centre at the origin, 1 unit = tile scale (heights are fitted per variant later)
    tb = pieces["Tree base"]
    zs = [v.co.z for v in tb.vertices]
    z0 = min(zs)
    low = [v.co for v in tb.vertices if v.co.z < z0 + 0.05 * (max(zs) - z0)]
    cx = sum(p.x for p in low) / len(low)
    cy = sum(p.y for p in low) / len(low)
    allz = [v.co.z for m in pieces.values() for v in m.vertices]
    k = 1.0 / (max(allz) - z0)
    M = Matrix.Scale(k, 4) @ Matrix.Translation((-cx, -cy, -z0))
    for m in pieces.values():
        m.transform(M)
    return pieces, img


# ---------------------------------------------------------------------------------------------------------------
def uv_mask(me, W, H, grow=6):
    """Texels covered by a mesh's UV triangles (image rows bottom-up, as Blender stores pixels), grown a little."""
    m = np.zeros((H, W), bool)
    uvl = me.uv_layers.active.data
    for poly in me.polygons:
        uv = np.array([uvl[li].uv[:] for li in poly.loop_indices], np.float64)
        for k in range(1, len(uv) - 1):
            t = uv[[0, k, k + 1]] * [W, H]
            x0, x1 = max(int(t[:, 0].min()) - 1, 0), min(int(t[:, 0].max()) + 2, W)
            y0, y1 = max(int(t[:, 1].min()) - 1, 0), min(int(t[:, 1].max()) + 2, H)
            if x0 >= x1 or y0 >= y1:
                continue
            gx, gy = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
            (xa, ya), (xb, yb), (xc, yc) = t
            den = (yb - yc) * (xa - xc) + (xc - xb) * (ya - yc)
            if abs(den) < 1e-12:
                continue
            l1 = ((yb - yc) * (gx - xc) + (xc - xb) * (gy - yc)) / den
            l2 = ((yc - ya) * (gx - xc) + (xa - xc) * (gy - yc)) / den
            m[y0:y1, x0:x1] |= (l1 >= -0.05) & (l2 >= -0.05) & (1 - l1 - l2 >= -0.05)
    for _ in range(grow):
        q = np.pad(m, 1)
        m = m | q[:-2, 1:-1] | q[2:, 1:-1] | q[1:-1, :-2] | q[1:-1, 2:]
    return m


def remap_texture(img, leaf_pal, bark_pal, size, bark_mask):
    W, H = img.size
    px = np.array(img.pixels[:], np.float32).reshape(H, W, 4)[..., :3]
    lum = px @ np.array([0.299, 0.587, 0.114], np.float32)
    white = (px.min(axis=2) > 0.93) & ~bark_mask
    brown = bark_mask & ~(px.min(axis=2) > 0.93)
    green = ~brown & ~white

    def ramp(t, cols):
        cols = [np.array(c, np.float32) / 255.0 for c in cols]
        t = np.clip(t, 0, 1)[..., None]
        lo = cols[0] * (1 - t * 2) + cols[1] * (t * 2)
        hi = cols[1] * (2 - t * 2) + cols[2] * (t * 2 - 1)
        return np.where(t < 0.5, lo, hi)

    def norm(mask):
        v = lum[mask]
        a, b = np.percentile(v, 3), np.percentile(v, 97)
        return (lum - a) / max(b - a, 1e-4)

    out = np.zeros_like(px)
    tg = norm(green)
    out[green] = ramp(tg, [leaf_pal["shadow"], leaf_pal["mid"], leaf_pal["light"]])[green]
    tb = norm(brown)
    out[brown] = ramp(0.12 + 0.88 * tb, [bark_pal["groove"], bark_pal["base"], bark_pal["light"]])[brown]
    have = ~white
    for _ in range(48):  # fill the unused (white) atlas space from its neighbours so mipmaps never pull in white
        if have.all():
            break
        ps = np.pad(out * have[..., None], ((1, 1), (1, 1), (0, 0)))
        ph = np.pad(have.astype(np.float32), 1)
        s = ps[:-2, 1:-1] + ps[2:, 1:-1] + ps[1:-1, :-2] + ps[1:-1, 2:]
        c = ph[:-2, 1:-1] + ph[2:, 1:-1] + ph[1:-1, :-2] + ph[1:-1, 2:]
        new = ~have & (c > 0)
        out[new] = s[new] / c[new][:, None]
        have |= new
    out[~have] = out[have].mean(axis=0)
    if size != W:
        o2 = bpy.data.images.new("tmp_resize", W, H, alpha=False)
        o2.pixels.foreach_set(np.concatenate([out, np.ones((H, W, 1), np.float32)], 2).ravel())
        o2.scale(size, size)
        out = np.array(o2.pixels[:], np.float32).reshape(size, size, 4)[..., :3]
        bpy.data.images.remove(o2)
    return out[::-1]  # bc.save_texture expects canvas rows top-first


# ---------------------------------------------------------------------------------------------------------------
CAP_INFO = {}


def flared_trunk(me, v):
    """Add rings low on the trunk, flare them into root fins (the approved rev_001 flare), cap the base."""
    bm = bmesh.new()
    bm.from_mesh(me)
    # glTF import splits vertices along UV seams; weld them (UVs stay per corner) so the base ring is one loop
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
    zmax = max(vt.co.z for vt in bm.verts)
    base = [vt for vt in bm.verts if vt.co.z < 0.02]
    r0 = max((Vector((vt.co.x, vt.co.y)).length for vt in base), default=0.06)
    for z in (0.012, 0.03, 0.055, 0.09):
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, z), plane_no=(0, 0, 1))
    rng = random.Random(v["seed"] * 7)
    phase = rng.uniform(0, 2 * math.pi)
    n = v["roots"]
    amp = [rng.uniform(0.75, 1.2) for _ in range(n)]
    for vt in bm.verts:
        z = vt.co.z
        if z > 0.16:
            continue
        d = Vector((vt.co.x, vt.co.y))
        if d.length < 1e-6 or d.length > r0 * 2.2:
            continue
        th = math.atan2(d.y, d.x)
        k = (th - phase) * n / (2 * math.pi)
        idx = int(math.floor(k + 0.5)) % n
        bump = max(0.0, math.cos(2 * math.pi * (k - math.floor(k + 0.5)))) ** 2.2 * amp[idx]
        f = 1.0 + math.exp(-z / 0.05) * (0.22 + 0.85 * bump) + math.exp(-z / 0.12) * 0.12 * bump
        vt.co.x, vt.co.y = d.x * f, d.y * f
        if z < 0.004:
            vt.co.z = 0.0
    # cap the base: the open boundary loop lowest on the trunk is flattened onto the ground and filled
    bnd = [e for e in bm.edges if e.is_boundary]
    loops, seen = [], set()
    for e in bnd:
        if e in seen:
            continue
        st, lp = [e], []
        seen.add(e)
        while st:
            g = st.pop()
            lp.append(g)
            for vt in g.verts:
                for h in vt.link_edges:
                    if h.is_boundary and h not in seen:
                        seen.add(h)
                        st.append(h)
        loops.append(lp)
    CAP_INFO.clear()
    ground_loops = [lp for lp in loops if max(vt.co.z for e in lp for vt in e.verts) < 0.02]
    if ground_loops:
        low = max(ground_loops, key=len)
        for e in low:
            for vt in e.verts:
                vt.co.z = 0.0
        res = bmesh.ops.holes_fill(bm, edges=low, sides=0)
        CAP_INFO.update(loops=len(loops), base_loop_edges=len(low), cap_faces=len(res["faces"]))
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    for f in bm.faces:  # the base cap and anything else lying on the ground faces down
        if all(vt.co.z < 0.005 for vt in f.verts):
            f.normal_update()
            if f.normal.z > 0:
                f.normal_flip()
    out = bpy.data.meshes.new("trunk")
    bm.to_mesh(out)
    bm.free()
    return out


def decimate(me, ratio):
    if ratio >= 0.999:
        return me
    ob = bpy.data.objects.new("dec", me)
    bpy.context.scene.collection.objects.link(ob)
    w = ob.modifiers.new("w", "WELD")  # glTF splits vertices at UV seams; collapsing unwelded seams tears holes
    w.merge_threshold = 1e-5
    m = ob.modifiers.new("d", "DECIMATE")
    m.decimate_type = "COLLAPSE"
    m.ratio = ratio
    m.use_collapse_triangulate = True
    out = bc.eval_mesh(ob)
    bpy.data.objects.remove(ob)
    return out


def tris(me):
    return sum(len(p.vertices) - 2 for p in me.polygons)


def build_variant(key, v, pieces, lod, mats):
    """Place the pieces for one variant/LOD and return one joined, fitted object."""
    parts = []
    trunk = flared_trunk(pieces["Tree base"], v)
    trunk.transform(Matrix.Diagonal((TRUNK_XY, TRUNK_XY, 1.0, 1.0)))
    parts.append(("trunk", decimate(trunk, LODS[lod]["trunk"])))
    cap = dict(CAP_INFO)
    centre_pts = [vt.co for name in GROUPS["centre"] for vt in pieces[name].vertices]
    cz0 = min(p.z for p in centre_pts)
    ctr = Vector((sum(p.x for p in centre_pts) / len(centre_pts), sum(p.y for p in centre_pts) / len(centre_pts), 0))
    placed = []
    for g, names in GROUPS.items():
        for name in names:
            placed.append((g, name, 0.0))
    for g, turn in v["extra"]:
        for name in GROUPS[g]:
            placed.append((g + "_copy", name, turn))
    shells = []
    for g, name, turn in placed:
        me = pieces[name].copy()
        if g == "centre":
            me.transform(Matrix.Translation((0, 0, cz0)) @ Matrix.Diagonal((1, 1, v["centre_z"], 1))
                         @ Matrix.Translation((0, 0, -cz0)))
        else:
            pts = [vt.co for vt in me.vertices]
            c = sum(pts, Vector()) / len(pts)
            off = Vector((c.x - ctr.x, c.y - ctr.y, 0)) * (v["side_out"] - 1) + Vector((0, 0, v["side_up"]))
            M = Matrix.Translation(off)
            if turn:
                M = Matrix.Translation(ctr) @ Matrix.Rotation(math.radians(turn), 4, "Z") @ Matrix.Translation(-ctr) @ M
            me.transform(M)
        shells.append(me)
    crown_src = sum(tris(m) for m in shells)
    # The skirts are single open sheets by design (scalloped hems); the crown material is two-sided instead of
    # duplicating them (an inner-skin experiment doubled the crown's triangles). The trunk stays single-sided.
    ratio = min(1.0, LODS[lod]["crown"] / crown_src)
    for me in shells:
        parts.append(("crown", decimate(me, ratio)))
    bm = bmesh.new()
    for _, me in parts:
        bm.from_mesh(me)  # appends
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    joined = bpy.data.meshes.new(f"broadleaf_{key}_lod{lod}")
    bm.to_mesh(joined)
    bm.free()
    # fit the approved envelope: height H, crown width W x depth D (trunk keeps its own girth ratio)
    lo = Vector([min(vt.co[k] for vt in joined.vertices) for k in range(3)])
    hi = Vector([max(vt.co[k] for vt in joined.vertices) for k in range(3)])
    size = hi - lo
    sx, sy, sz = v["W"] / size.x, v["D"] / size.y, v["H"] / size.z
    joined.transform(Matrix.Diagonal((sx, sy, sz, 1)))
    lo = Vector([min(vt.co[k] for vt in joined.vertices) for k in range(3)])
    joined.transform(Matrix.Translation((0, 0, -lo.z)))
    joined.materials.clear()
    joined.materials.append(mats[0])  # trunk, single-sided
    joined.materials.append(mats[1])  # crown, two-sided
    n_trunk = sum(len(m.polygons) for n, m in parts if n == "trunk")
    for i, p in enumerate(joined.polygons):
        p.material_index = 0 if i < n_trunk else 1
        p.use_smooth = True
    ob = bpy.data.objects.new(f"broadleaf_{key}_lod{lod}", joined)
    bpy.context.scene.collection.objects.link(ob)
    return ob, dict(trunk_base_cap=cap, crown_source_triangles=crown_src, shells=len(shells),
                    crown_triangles=sum(tris(m) for n, m in parts if n == "crown"),
                    trunk_triangles=sum(tris(m) for n, m in parts if n == "trunk"))


def open_edges(ob):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
    n = sum(1 for e in bm.edges if e.is_boundary)
    bm.free()
    return n


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    pieces, src_img = load_source()
    report = dict(revision=REV, generator="tools/blender/art_candidates/broadleaf/broadleaf_rework.py",
                  blender=bpy.app.version_string, units="1 unit = 1 game tile; Z-up in .blend, Y-up in glTF",
                  hero_reference_height=bc.HERO_H, variants={},
                  source=dict(path=str(SRC.relative_to(ROOT)).replace("\\", "/"),
                              triangles=sum(tris(m) for m in pieces.values()), label="roroer source",
                              produced_by="Sketchfab download supplied by the user (Downloads/stylized_tree.glb)"),
                  rework_attempt=dict(triangles=0, label=f"{bc.COMPARE} A (procedural)"),
                  compare_title="Source vs previous revision vs rework: roroer's model (as supplied, normalised) | "
                                f"{bc.COMPARE} A | {REV} A",
                  cull_note="trunk single-sided (must show no red); crown two-sided by design, red = skirt undersides",
                  textures=dict(per_variant="one 1024 texture per variant (crown + bark), shared by its 3 LODs",
                                method="source texture luminance mapped to the approved palettes; unused atlas "
                                       "space filled from neighbours",
                                smoothing="NOT smoothed (left for integration)"))
    objects = {}
    bark = uv_mask(pieces["Tree base"], *src_img.size)
    for key, v in VARIANTS.items():
        canvas = remap_texture(src_img, bc.LEAF_PAL[v["leaf"]], bc.BARK_PAL, 1024, bark)
        img = bc.save_texture(f"broadleaf_{key}", canvas)
        mat = bc.make_material(f"broadleaf_{key}_trunk", img)
        cmat = bc.make_material(f"broadleaf_{key}_crown", img)
        cmat.use_backface_culling = False  # open scalloped skirts: two-sided by design
        for lod in bc.LODS:
            ob, info = build_variant(key, v, pieces, lod, (mat, cmat))
            objects[(key, lod)] = ob
            path = OUT / f"mesh/broadleaf_{key}_lod{lod}.gltf"
            bpy.ops.object.select_all(action="DESELECT")
            ob.select_set(True)
            bpy.context.view_layer.objects.active = ob
            bpy.ops.export_scene.gltf(filepath=str(path), use_selection=True, export_format="GLTF_SEPARATE",
                                      export_texture_dir="textures", export_yup=True, export_apply=True,
                                      export_normals=True, export_texcoords=True, export_materials="EXPORT")
            bb = [Vector(c) for c in ob.bound_box]
            mn = [min(c[k] for c in bb) for k in range(3)]
            mx = [max(c[k] for c in bb) for k in range(3)]
            rec = report["variants"].setdefault(key, dict(label=v["label"], params=v, lods={}))
            rec["lods"][str(lod)] = dict(triangles=tris(ob.data), vertices=len(ob.data.vertices), materials=2,
                                         textures=1, texture_files=[f"textures/broadleaf_{key}.png"],
                                         double_sided={"trunk": False, "crown": True}, open_boundary_edges=open_edges(ob), file=path.name,
                                         bbox_min_zup=[round(x, 4) for x in mn], bbox_max_zup=[round(x, 4) for x in mx],
                                         height=round(mx[2] - mn[2], 4), width_x=round(mx[0] - mn[0], 4),
                                         depth_y=round(mx[1] - mn[1], 4), **info)
    # source copy (as supplied, normalised) and the compared revision's A for the comparison sheet
    bm = bmesh.new()
    for m in pieces.values():
        bm.from_mesh(m)
    sme = bpy.data.meshes.new("roroer_source")
    bm.to_mesh(sme)
    bm.free()
    sme.transform(Matrix.Scale(3.0, 4))
    sme.materials.append(bc.make_material("roroer_source", src_img))
    src = bpy.data.objects.new("roroer_source", sme)
    bpy.context.scene.collection.objects.link(src)
    cmp_dir = ROOT / "build/art_candidates/broadleaf" / bc.COMPARE
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(cmp_dir / "mesh/broadleaf_A_lod0.gltf"))
    prev = [o for o in bpy.data.objects if o not in before and o.type == "MESH"][0]
    prev.rotation_mode = "XYZ"
    report["rework_attempt"]["triangles"] = len(prev.data.polygons)
    bc.load_source()  # the tree_oak derivative: positive control for the backface check (open crown)
    bc.VARIANTS = {k: dict(bc.VARIANTS[k], **{"H": v["H"]}) for k, v in VARIANTS.items()}
    bc.renders(objects, src, prev)
    bc.checks(objects)
    for (key, lod), ob in objects.items():
        ob.location = (("A", "B", "C").index(key) * 4.0 - 4.0, lod * 5.0, 0)
        ob.rotation_euler = (0, 0, 0)
    for o in bpy.data.objects:
        o.hide_render = False
    (OUT / "build_report.json").write_text(json.dumps(report, indent=1, default=str))
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "source/broadleaf_candidate.blend"), compress=True)
    print("BROADLEAF DONE", OUT)


main()
