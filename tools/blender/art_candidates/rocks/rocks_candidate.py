"""Rock family artwork candidate (preproduction for runbook 030; NOT integrated, 030 NOT complete).

    python tools/local_resource.py -- "C:/Program Files/Blender Foundation/Blender 4.2/blender.exe" -b \
        --factory-startup -P tools/blender/art_candidates/rocks/rocks_candidate.py -- --rev rev_001 [--no-render]

Then: python tools/blender/art_candidates/rocks/make_sheets.py rev_001
      python tools/blender/art_candidates/rocks/finalize.py rev_001      (writes READY.json last, atomically)

Writes only into build/art_candidates/rocks/<rev>/ and refuses a revision that already has READY.json.

030 asks for "a Blender rework of the rock meshes: designed broad planes, softened transitions, partly buried bases,
coast and grassland colours". Every shape is made twice with the same pipeline, from two point sets:
  * rework: the vertices of a cut from the supplied "Environment Pack - Stylized Rock" (build/nature_split, via
    tools/prepare_stylized_nature.py; the pack stays untouched), fitted to the shape's envelope;
  * procedural: a seeded spread of points on a rounded block.
  Pipeline: convex hull -> limited dissolve into a few broad planes -> two-segment bevel on every edge (softened
  transitions) -> base cut below the ground line and capped (partly buried) -> triangulate. Weighted normals keep
  the broad planes flat-shaded and round the bevels. Which set each shape ships with is chosen in SOURCE_CHOICE and
  recorded (rework_vs_rebuild renders show both).
Texture: per palette (grassland, coast) one 1024 atlas, a 512 cell per shape, baked in numpy from each texel's
position and plane: soft per-plane tone, light top planes, a pale painted edge on the bevels, darker contact at the
ground, broad smooth colour patches (no grain), moss on grassland tops, a wet band and salt-pale tops on the coast.
Units: 1 unit = 1 tile; origin = footprint centre on the ground line (z = 0); bases continue BURY below it.
"""
import bpy, bmesh, json, sys, math, pathlib, random
import numpy as np
from mathutils import Vector, Matrix

ROOT = pathlib.Path(__file__).resolve().parents[4]
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=None):
    return ARGS[ARGS.index(name) + 1] if name in ARGS else default


REV = arg("--rev", "rev_001")
OUT = ROOT / "build/art_candidates/rocks" / REV
TREES = ROOT / "build/art_candidates/broadleaf/rev_003/mesh"   # approved, read-only
SHRUBS = ROOT / "build/art_candidates/shrubs/rev_002/mesh"     # published, read-only
RENDER = "--no-render" not in ARGS
if (OUT / "READY.json").exists():
    raise SystemExit(f"{OUT} is published (READY.json); corrections go in a new revision")
for sub in ("mesh/textures", "source", "renders", "previews"):
    (OUT / sub).mkdir(parents=True, exist_ok=True)

HERO_H = 1.44
TEX, CELL = 1024, 512
BURY = 0.07  # how far each base continues below the ground line

# shape: envelope above ground (W, D, H), source cut for the rework, procedural seed / points / squareness
SHAPES = {
    "rock_A": dict(label="field boulder", W=0.9, D=0.8, H=0.62, source="field_rock", seed=3, n=12, sq=2.6,
                   sink=0.1),
    "rock_B": dict(label="tall boulder (cliff foot, shallow water)", W=0.82, D=0.76, H=0.92, source="mountain_1",
                   seed=8, n=12, sq=2.8, sink=0.1),
    "rock_C": dict(label="low outcrop (knee high)", W=1.36, D=0.92, H=0.4, source="mountain_0", seed=21, n=12,
                   sq=3.0, sink=0.24),
    "rock_D": dict(label="stone cluster (ankle high)", stones=[(-0.16, 0.04, 0.36, 0.3, 0.26, 31),
                                                               (0.17, -0.06, 0.26, 0.24, 0.18, 32),
                                                               (0.06, 0.2, 0.18, 0.16, 0.12, 33)],
                   source="rock_small"),
}
# rework where the pack's cut already has designed broad planes; procedural where it is a peak or spike
SOURCE_CHOICE = {"rock_A": "procedural", "rock_B": "rework", "rock_C": "rework", "rock_D": "procedural"}
CHOICE_REASON = {
    "rock_A": "the field_rock cut's hull rises to a peak (an accidental pyramid, standards 11); rebuilt",
    "rock_B": "the mountain_1 cut (a squat column) keeps broad, designed planes after the hull and bevel; reworked",
    "rock_C": "the mountain_0 cut (a broad layered slab) keeps its planes; reworked, its narrow underside sunk "
              "below the ground line so it rests rather than balances",
    "rock_D": "the rock_small cut is a thin spike; three rebuilt stones instead",
}
CELLS = {"rock_A": (0, 1), "rock_B": (1, 1), "rock_C": (0, 0), "rock_D": (1, 0)}  # (col, row from bottom)
PALETTES = {
    # grassland: cool warm-leaning grey stone, moss on the tops
    "grass": dict(dark=(98, 100, 104), mid=(140, 140, 138), light=(184, 180, 170), edge=(214, 208, 194),
                  patch=(150, 136, 118), contact=(78, 80, 78), moss=(100, 132, 76), moss_light=(126, 156, 86)),
    # coast: warmer sandy grey, a darker wet band low down, salt-pale tops
    "coast": dict(dark=(112, 102, 92), mid=(158, 146, 128), light=(204, 192, 170), edge=(230, 222, 204),
                  patch=(170, 150, 120), contact=(84, 84, 82), wet=(92, 98, 98), salt=(232, 228, 216)),
}


# ---------------------------------------------------------------------------------------------------------------
def source_points(name):
    d = json.loads((ROOT / f"build/nature_split/{name}.json").read_text())
    return [Vector((p[0], -p[2], p[1])) for p in d["v"]]  # Y-up -> Z-up


def fit_points(pts, W, D, H, sink=0.0):
    lo = Vector([min(p[k] for p in pts) for k in range(3)])
    hi = Vector([max(p[k] for p in pts) for k in range(3)])
    c = (lo + hi) / 2
    s = hi - lo
    out = []
    for p in pts:
        q = Vector(((p.x - c.x) / s.x * W, (p.y - c.y) / s.y * D, (p.z - lo.z) / s.z * (H + sink) - sink))
        out.append(q)
    return out


def block_points(W, D, H, n, seed, sq):
    """A seeded spread of points on a rounded block (superellipsoid), widest low down, flat-ish top."""
    rng = random.Random(seed)
    pts = []
    ga = math.pi * (3 - math.sqrt(5))
    for i in range(n):
        z = 1 - 2 * (i + 0.5) / n
        r = math.sqrt(max(0.0, 1 - z * z))
        a = ga * i + rng.uniform(-0.35, 0.35)
        x, y = r * math.cos(a), r * math.sin(a)
        e = 2 / sq
        x = math.copysign(abs(x) ** e, x)
        y = math.copysign(abs(y) ** e, y)
        zz = math.copysign(abs(z) ** e, z)
        j = rng.uniform(0.86, 1.06)
        widen = 1.0 + 0.12 * max(0.0, -zz)  # wider foot: sits, never balances
        top = min(1.0, 0.92 + 0.08 * rng.random())
        px = x * j * widen * W / 2
        py = y * j * widen * D / 2
        pz = (min(zz, top) * 0.5 + 0.5) * (H + BURY * 2) - BURY * 2
        pts.append(Vector((px, py, pz)))
    # a ring of foot points below ground keeps the base broad
    for k in range(6):
        a = 2 * math.pi * (k + rng.random() * 0.3) / 6
        pts.append(Vector((math.cos(a) * W * 0.47, math.sin(a) * D * 0.47, -BURY * 2)))
    return pts


def shell(pts, bevel, segs, dissolve_deg=16.0, plane_base=1, ridge_deg=22.0):
    """Hull -> broad planes -> bevelled edges -> base cut below the ground and capped. Returns a bmesh whose
    face layers say which broad plane a face belongs to ("plane", 0 = base cap) and whether it is a bevel strip."""
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in pts]
    res = bmesh.ops.convex_hull(bm, input=vs)
    for g in res.get("geom_interior", []) + res.get("geom_unused", []):
        if isinstance(g, bmesh.types.BMVert) and g.is_valid and not g.link_faces:
            bm.verts.remove(g)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-4)
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(dissolve_deg), verts=bm.verts[:], edges=bm.edges[:])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    pl = bm.faces.layers.int.new("plane")
    bv = bm.faces.layers.int.new("bev")
    for i, f in enumerate(bm.faces):
        f[pl] = plane_base + i
        f[bv] = 0
    if segs:
        ridges = [e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0) > math.radians(ridge_deg)]
        res = bmesh.ops.bevel(bm, geom=ridges + list({v for e in ridges for v in e.verts}), offset=bevel,
                              offset_type="OFFSET",
                              segments=segs, profile=0.5, affect="EDGES", clamp_overlap=True)
        for f in res["faces"]:
            f[bv] = 1
            f[pl] = 0
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, -BURY), plane_no=(0, 0, 1), clear_inner=True)
    bnd = [e for e in bm.edges if e.is_boundary]
    if bnd:
        for f in bmesh.ops.holes_fill(bm, edges=bnd, sides=0)["faces"]:
            f[pl] = 0
            f[bv] = 0
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def build_shape(key, spec, mode, segs):
    if key == "rock_D":
        bm_all = bmesh.new()
        me_tmp = bpy.data.meshes.new("tmp")
        for i, (x, y, w, d, h, seed) in enumerate(spec["stones"]):
            if mode == "rework":
                pts = fit_points(source_points(spec["source"]), w, d, h, BURY)
                pts = [p + Vector((x, y, 0)) for p in pts]
            else:
                pts = [p + Vector((x, y, 0)) for p in block_points(w, d, h, 10, seed, 2.6)]
            bm = shell(pts, 0.02 * (w / 0.3), segs, plane_base=100 * (i + 1))
            bm.to_mesh(me_tmp)
            bm.free()
            bm_all.from_mesh(me_tmp)
        bpy.data.meshes.remove(me_tmp)
        return bm_all
    if mode == "rework":
        pts = fit_points(source_points(spec["source"]), spec["W"], spec["D"], spec["H"], spec["sink"])
    else:
        pts = block_points(spec["W"], spec["D"], spec["H"], spec["n"], spec["seed"], spec["sq"])
    return shell(pts, 0.032 * min(spec.get("W", 1), 1.0) / 0.9, segs)


# ---------------------------------------------------------------------------------------------------------------
def smooth_field(seed, scale):
    """Broad smooth patches: a coarse random lattice, smoothstep-interpolated in 3D (no grain)."""
    rng = np.random.default_rng(seed)
    G = rng.random((9, 9, 9)).astype(np.float32)

    def f(P):
        q = (P / scale) % 8.0
        i = np.clip(np.floor(q).astype(int), 0, 7)
        t = q - i
        t = t * t * (3 - 2 * t)
        out = 0
        for dx in (0, 1):
            for dy in (0, 1):
                for dz in (0, 1):
                    w = (t[:, 0] if dx else 1 - t[:, 0]) * (t[:, 1] if dy else 1 - t[:, 1]) * (t[:, 2] if dz else 1 - t[:, 2])
                    out = out + w * G[i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz]
        return out
    return f


def c(t):
    return np.array(t, np.float32) / 255.0


def bake(objs_lod0, palette, seed):
    """Paint one atlas for a palette: every texel coloured from its point and plane on the LOD0 shape."""
    pal = PALETTES[palette]
    img = np.zeros((TEX, TEX, 3), np.float32)
    have = np.zeros((TEX, TEX), bool)
    patch = smooth_field(seed, 0.42)
    patch2 = smooth_field(seed + 7, 0.17)
    for key, ob in objs_lod0.items():
        me = ob.data
        uvl = me.uv_layers.active.data
        H = max(v.co.z for v in me.vertices)
        plane_tone = {}
        rng = random.Random(seed * 31 + sum(map(ord, key)))
        pa = me.attributes["plane"].data
        ba = me.attributes["bev"].data
        for poly in me.polygons:
            P3 = [me.vertices[i].co for i in poly.vertices]
            uv = np.array([uvl[li].uv[:] for li in poly.loop_indices], np.float64) * TEX
            n = poly.normal
            # broad planes (big faces) get a steady per-plane tone; bevel strips (small faces) a painted edge
            k = pa[poly.index].value
            if k not in plane_tone:
                plane_tone[k] = rng.uniform(-0.07, 0.07) if k else 0.0
            is_bevel = ba[poly.index].value == 1
            x0, x1 = max(int(uv[:, 0].min()) - 1, 0), min(int(uv[:, 0].max()) + 2, TEX)
            y0, y1 = max(int(uv[:, 1].min()) - 1, 0), min(int(uv[:, 1].max()) + 2, TEX)
            if x0 >= x1 or y0 >= y1:
                continue
            gx, gy = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
            (xa, ya), (xb, yb), (xc, yc) = uv[:3]
            den = (yb - yc) * (xa - xc) + (xc - xb) * (ya - yc)
            if abs(den) < 1e-12:
                continue
            l1 = ((yb - yc) * (gx - xc) + (xc - xb) * (gy - yc)) / den
            l2 = ((yc - ya) * (gx - xc) + (xa - xc) * (gy - yc)) / den
            l3 = 1 - l1 - l2
            m = (l1 >= -0.02) & (l2 >= -0.02) & (l3 >= -0.02)
            if not m.any():
                continue
            A, B, C = (np.array(p[:], np.float32) for p in P3[:3])
            P = (l1[m, None] * A + l2[m, None] * B + l3[m, None] * C).astype(np.float32)
            hz = np.clip(P[:, 2] / max(H, 1e-3), 0, 1)
            tone = 0.52 + 0.16 * n.z + 0.03 * (n.x - n.y) + plane_tone[k]
            tone = tone + 0.1 * (patch(P) - 0.5)
            col = np.where((tone < 0.5)[:, None],
                           c(pal["dark"]) * (1 - (tone / 0.5)[:, None]) + c(pal["mid"]) * (tone / 0.5)[:, None],
                           c(pal["mid"]) * (1 - ((tone - 0.5) / 0.5)[:, None]) + c(pal["light"]) * ((tone - 0.5) / 0.5)[:, None])
            pt = np.clip((patch2(P) - 0.55) * 3.0, 0, 1)[:, None] * 0.35  # broad warm patches
            col = col * (1 - pt) + c(pal["patch"]) * pt
            if is_bevel and n.z > -0.2:
                col = col * 0.78 + c(pal["edge"]) * 0.22
            contact = (1 - np.clip(P[:, 2] / 0.16 + 0.35, 0, 1))[:, None] * 0.7
            if palette == "grass":
                moss = np.clip((n.z - 0.45) / 0.35, 0, 1) * np.clip((hz - 0.35) / 0.4, 0, 1)
                moss = moss * np.clip((patch(P * 1.7 + 3.0) - 0.3) * 2.2, 0, 1)
                mcol = c(pal["moss"]) * (1 - hz[:, None] * 0.5) + c(pal["moss_light"]) * (hz[:, None] * 0.5)
                col = col * (1 - moss[:, None] * 0.7) + mcol * (moss[:, None] * 0.7)
            else:
                wet = np.clip((0.22 - P[:, 2]) / 0.14, 0, 1)[:, None] * 0.75
                col = col * (1 - wet) + c(pal["wet"]) * wet
                salt = (np.clip((n.z - 0.6) / 0.3, 0, 1) * np.clip((hz - 0.5) / 0.4, 0, 1))[:, None] * 0.5
                col = col * (1 - salt) + c(pal["salt"]) * salt
            col = col * (1 - contact) + c(pal["contact"]) * contact
            yy, xx = gy[m].astype(int), gx[m].astype(int)
            img[yy, xx] = np.clip(col, 0, 1)
            have[yy, xx] = True
    for _ in range(24):  # dilate islands so mipmaps never pull in empty space
        if have.all():
            break
        ps = np.pad(img * have[..., None], ((1, 1), (1, 1), (0, 0)))
        ph = np.pad(have.astype(np.float32), 1)
        s = ps[:-2, 1:-1] + ps[2:, 1:-1] + ps[1:-1, :-2] + ps[1:-1, 2:]
        cnt = ph[:-2, 1:-1] + ph[2:, 1:-1] + ph[1:-1, :-2] + ph[1:-1, 2:]
        new = ~have & (cnt > 0)
        img[new] = s[new] / cnt[new][:, None]
        have |= new
    img[~have] = img[have].mean(axis=0)
    rgba = np.concatenate([img, np.ones((TEX, TEX, 1), np.float32)], axis=2)
    im = bpy.data.images.new(f"rocks_{palette}", TEX, TEX, alpha=False)
    im.pixels.foreach_set(rgba.ravel())
    im.filepath_raw = str(OUT / f"mesh/textures/rocks_{palette}.png")
    im.file_format = "PNG"
    im.save()
    im.pack()
    return im


BEVEL_AREA = {}


def unwrap_into_cell(ob, key):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.03, area_weight=0.0, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    cx, cy = CELLS[key]
    g = 10 / TEX
    for d in ob.data.uv_layers.active.data:
        u, v = d.uv
        d.uv = ((cx * CELL) / TEX + g + u * (CELL / TEX - 2 * g), (cy * CELL) / TEX + g + v * (CELL / TEX - 2 * g))


def make_material(name, img):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Linear"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.9
    bsdf.inputs["Specular IOR Level"].default_value = 0.2
    mat.use_backface_culling = True
    return mat


def to_object(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def add_weighted_normals(ob):
    m = ob.modifiers.new("wn", "WEIGHTED_NORMAL")
    m.mode = "FACE_AREA"
    m.weight = 100
    m.keep_sharp = False


def decimate_copy(ob, name, ratio):
    me = ob.data.copy()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    d = o.modifiers.new("d", "DECIMATE")
    d.decimate_type = "COLLAPSE"
    d.ratio = ratio
    d.use_collapse_triangulate = True
    dg = bpy.context.evaluated_depsgraph_get()
    new = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
    o.modifiers.clear()
    o.data = new
    for p in new.polygons:
        p.use_smooth = True
    return o


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
    return dict(triangles=sum(len(p.vertices) - 2 for p in me.polygons), vertices=len(me.vertices),
                open_boundary_edges=boundary, nonmanifold_edges=nonman,
                width_x=round(hi[0] - lo[0], 4), depth_y=round(hi[1] - lo[1], 4),
                height_above_ground=round(hi[2], 4), buried_depth=round(-lo[2], 4),
                bbox_min_zup=[round(x, 4) for x in lo], bbox_max_zup=[round(x, 4) for x in hi])


def export(ob, path):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.gltf(filepath=str(path), use_selection=True, export_format="GLTF_SEPARATE",
                              export_texture_dir="textures", export_yup=True, export_apply=True,
                              export_normals=True, export_texcoords=True, export_materials="EXPORT")


# ---------------------------------------------------------------------------------------------------------------
def setup_render():
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE_NEXT"
    sc.eevee.taa_render_samples = 48
    sc.eevee.use_shadows = True
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Base Contrast"
    w = sc.world or bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.62, 0.72, 0.86, 1)
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
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


def import_ref(path, name):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    new = [o for o in bpy.data.objects if o not in before]
    ob = [o for o in new if o.type == "MESH"][0]
    for o in new:
        if o is not ob:
            bpy.data.objects.remove(o)
    ob.name = name
    ob.parent = None
    ob.location = (0, 0, 0)
    ob.rotation_mode = "XYZ"
    return ob


def inst(src, loc, rot=0.0, s=1.0):
    o = bpy.data.objects.new(f"i_{src.name}_{len(bpy.data.objects)}", src.data)
    bpy.context.scene.collection.objects.link(o)
    for m in src.modifiers:  # keep weighted normals on instances
        if m.type == "WEIGHTED_NORMAL":
            n = o.modifiers.new("wn", "WEIGHTED_NORMAL"); n.mode = m.mode; n.weight = m.weight
    o.location = loc
    o.rotation_mode = "XYZ"
    o.rotation_euler = (src.rotation_euler.x, src.rotation_euler.y, rot)
    o.scale = (s, s, s)
    return o


def renders(objects, compare, refs):
    sc, cam = setup_render()
    R = OUT / "renders"
    hero = bpy.data.objects["hero_ref"]
    pitch = math.atan2(7.0, 11.0)
    keys = list(SHAPES)
    # turntables per shape and palette (LOD0, 4 turns, ortho)
    cam.data.type = "ORTHO"
    for key in keys:
        for pal in PALETTES:
            ob = objects[(key, pal, 0)]
            big = key == "rock_C"
            cam.data.ortho_scale = 2.4 if big else 2.0
            sc.render.resolution_x, sc.render.resolution_y = (520, 440) if big else (440, 440)
            ob.location = (0, 0, 0)
            hero.location = (1.05 if big else 0.85, 0.5, 0)
            show_only([ob, hero])
            for i in range(4):
                ob.rotation_euler = (0, 0, math.radians(i * 90))
                aim(cam, Vector((0.25, -14, 3.9)), Vector((0.25, 0, 0.5)))
                render(R / f"turn_{key}_{pal}_{i}.png")
            ob.rotation_euler = (0, 0, 0)
    # LODs, gameplay pitch
    for key in keys:
        for lod in (0, 1):
            ob = objects[(key, "grass", lod)]
            ob.location = (0, 0, 0)
            cam.data.ortho_scale = 1.7 if key == "rock_C" else 1.25
            sc.render.resolution_x, sc.render.resolution_y = 360, 300
            show_only([ob])
            aim(cam, Vector((0, -math.cos(pitch) * 20, math.sin(pitch) * 20 + 0.25)), Vector((0, 0, 0.25)))
            render(R / f"lod_{key}_{lod}.png")
    # rework vs procedural, same pipeline, grass palette, gameplay pitch
    for key in keys:
        for mode in ("rework", "procedural"):
            ob = compare[(key, mode)]
            ob.location = (0, 0, 0)
            cam.data.ortho_scale = 1.7 if key == "rock_C" else 1.25
            sc.render.resolution_x, sc.render.resolution_y = 360, 300
            show_only([ob])
            aim(cam, Vector((0, -math.cos(pitch) * 20, math.sin(pitch) * 20 + 0.25)), Vector((0, 0, 0.25)))
            render(R / f"cmp_{key}_{mode}.png")
    # source cuts as supplied (fitted to the same envelopes), for the comparison sheet
    for key in keys:
        ob = compare[(key, "source")]
        ob.location = (0, 0, 0)
        cam.data.ortho_scale = 1.7 if key == "rock_C" else 1.25
        show_only([ob])
        aim(cam, Vector((0, -math.cos(pitch) * 20, math.sin(pitch) * 20 + 0.25)), Vector((0, 0, 0.25)))
        render(R / f"cmp_{key}_source.png")
    # back-face check (magenta), side / below / top, and an open positive control
    chk = bpy.data.materials.new("cull_check")
    chk.use_nodes = True
    nt = chk.node_tree
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    mix = nt.nodes.new("ShaderNodeMixShader")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (1, 0, 1, 1)
    em.inputs["Strength"].default_value = 3.0
    nt.links.new(geo.outputs["Backfacing"], mix.inputs[0])
    nt.links.new(nt.nodes["Principled BSDF"].outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], nt.nodes["Material Output"].inputs["Surface"])
    chk.use_backface_culling = False
    cam.data.type = "PERSP"
    cam.data.sensor_fit = "VERTICAL"
    cam.data.angle_y = math.radians(36)
    sc.render.resolution_x, sc.render.resolution_y = 1600, 900
    sc.view_settings.view_transform = "Standard"
    line = []
    for i, key in enumerate(keys):
        for j, lod in enumerate((0, 1)):
            o = inst(objects[(key, "grass", lod)], (i * 1.6 - 2.4, j * 1.6, 0))
            o.data = objects[(key, "grass", lod)].data.copy()
            o.data.materials[0] = chk
            line.append(o)
    show_only(line, ground=False)
    for tag, loc, tgt in [("side", (0, -7.5, 1.6), (0, 0.8, 0.3)), ("below", (0, -6.5, -2.4), (0, 0.8, 0.2)),
                          ("top", (0, -1.6, 8.0), (0, 0.8, 0.2))]:
        aim(cam, Vector(loc), Vector(tgt))
        render(R / f"cull_{tag}.png")
    for o in line:
        bpy.data.objects.remove(o)
    bm = shell(block_points(0.9, 0.8, 0.62, 13, 3, 2.6), 0.05, 2)
    for f in [f for f in bm.faces if all(v.co.z < -BURY + 1e-3 for v in f.verts)]:
        bm.faces.remove(f)  # the base cap removed: an open control
    ctl = to_object("cull_control", bm)
    ctl.data.materials.append(chk)
    show_only([ctl], ground=False)
    aim(cam, Vector((0, -3.0, -1.2)), Vector((0, 0, 0.2)))
    render(R / "cull_control.png")
    bpy.data.objects.remove(ctl)
    sc.view_settings.view_transform = "AgX"
    # mixed nature lineup: broadleaf rev_003, shrubs rev_002 and the rocks, front + gameplay pitch (ortho)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 7.2
    sc.render.resolution_x, sc.render.resolution_y = 2000, 760
    grp = [inst(refs["tree_A"], (-3.7, 0.7, 0)), inst(refs["bush_A"], (-2.1, 0.3, 0)),
           inst(refs["flower_daisy"], (-1.4, -0.2, 0))]
    x = -0.9
    for key in keys:
        w = 1.4 if key == "rock_C" else 0.95
        grp.append(inst(objects[(key, "grass", 0)], (x + w / 2, 0, 0)))
        grp.append(inst(objects[(key, "coast", 0)], (x + w / 2, 1.3, 0)))
        x += w + 0.25
    hero.location = (-2.85, -0.3, 0)
    show_only(grp + [hero])
    aim(cam, Vector((0.4, -16, 3.6)), Vector((0.4, 0, 0.9)))
    render(R / "lineup_front.png")
    aim(cam, Vector((0.4, -math.cos(pitch) * 22, math.sin(pitch) * 22 + 0.9)), Vector((0.4, 0.6, 0.9)))
    render(R / "lineup_game.png")
    for o in grp:
        bpy.data.objects.remove(o)
    # gameplay angle: the game camera (fov 36, offset 0,7,11). A grassland meadow edge and a coast strip.
    cam.data.type = "PERSP"
    cam.data.angle_y = math.radians(36)
    sc.render.resolution_x, sc.render.resolution_y = 1920, 1080
    scene = []
    for k, (tx, ty), r, s in [("tree_A", (-4, 5), 0.3, 1.0), ("tree_B", (-1, 6), 1.2, 1.05), ("tree_C", (3, 5), 2.0, 0.95),
                              ("tree_A", (5, 7), 4.0, 1.05), ("tree_B", (1, 8), 0.7, 0.95)]:
        scene.append(inst(refs[k], (tx, ty, 0), r, s))
    for k, (tx, ty), r in [("bush_A", (-3, 2), 0.4), ("bush_B", (-2, 3), 2.1), ("bush_D", (2, 3), 0.6),
                           ("bush_E", (3, 2), 0.2), ("flower_daisy", (1, 1), 0.3), ("flower_tulip_coral", (-1, 1), 1.0)]:
        scene.append(inst(refs[k], (tx + 0.5, ty + 0.5, 0), r))
    rng = random.Random(9)
    for key, (tx, ty), r in [("rock_A", (-1, 3), 0.5), ("rock_C", (0, 4), 2.0), ("rock_B", (4, 4), 1.1),
                             ("rock_D", (-4, 1), 0.8), ("rock_A", (5, 2), 3.0), ("rock_D", (1, 3), 2.2),
                             ("rock_C", (-6, 3), 4.0)]:
        scene.append(inst(objects[(key, "grass", 0)], (tx + 0.5, ty + 0.5, 0), r, rng.uniform(0.92, 1.08)))
    for key, (tx, ty), r in [("rock_C", (-3, -2), 0.3), ("rock_A", (-1, -2), 1.6), ("rock_D", (1, -2), 0.9),
                             ("rock_B", (3, -2), 2.4), ("rock_D", (5, -2), 4.1)]:
        scene.append(inst(objects[(key, "coast", 0)], (tx + 0.5, ty + 0.5, 0), r, rng.uniform(0.92, 1.08)))
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
    report = dict(revision=REV, generator="tools/blender/art_candidates/rocks/rocks_candidate.py",
                  blender=bpy.app.version_string, units="1 unit = 1 game tile; Z-up in .blend, Y-up in glTF; "
                  "origin = footprint centre on the ground line", buried_depth=BURY, hero_reference_height=HERO_H,
                  source_choice=SOURCE_CHOICE, choice_reason=CHOICE_REASON,
                  textures=dict(files=[f"mesh/textures/rocks_{p}.png" for p in PALETTES], size=TEX, cell=CELL,
                                layout={k: dict(col=c_[0], row_from_bottom=c_[1]) for k, c_ in CELLS.items()},
                                method="baked with numpy from texel position and plane (soft per-plane tone, "
                                       "painted bevel edges, contact shade, broad smooth patches, moss / wet band "
                                       "and salt); no grain",
                                smoothing="NOT smoothed (left for integration)"),
                  models={})
    base, compare = {}, {}
    for key, spec in SHAPES.items():
        for mode in ("rework", "procedural"):
            ob = to_object(f"cmp_{key}_{mode}", build_shape(key, spec, mode, 2))
            add_weighted_normals(ob)
            compare[(key, mode)] = ob
        base[key] = compare[(key, SOURCE_CHOICE[key])]
    # the source cut itself, fitted to the same envelope (no hull, no bevel) for the comparison
    for key, spec in SHAPES.items():
        d = json.loads((ROOT / f"build/nature_split/{spec['source']}.json").read_text())
        pts = [Vector((p[0], -p[2], p[1])) for p in d["v"]]
        if key == "rock_D":
            W, D, H = 0.36, 0.3, 0.26
        else:
            W, D, H = spec["W"], spec["D"], spec["H"]
        pts = fit_points(pts, W, D, H, BURY)
        bm = bmesh.new()
        for t in range(0, len(pts), 3):
            try:
                bm.faces.new([bm.verts.new(p) for p in pts[t:t + 3]])
            except ValueError:
                pass
        ob = to_object(f"cmp_{key}_source", bm)
        compare[(key, "source")] = ob
    # UVs into each shape's cell (LOD0), then LOD1 by collapse (UVs kept), then bake the two palettes
    for key, ob in base.items():
        unwrap_into_cell(ob, key)
    imgs = {pal: bake(base, pal, 50 + i) for i, pal in enumerate(PALETTES)}
    mats = {pal: make_material(f"rocks_{pal}", img) for pal, img in imgs.items()}
    objects = {}
    for key, ob in base.items():
        lod1 = decimate_copy(ob, f"{key}_lod1_src", 0.42)
        for lod, src in ((0, ob), (1, lod1)):
            for pal in PALETTES:
                o = bpy.data.objects.new(f"{key}_{pal}_lod{lod}", src.data.copy())
                bpy.context.scene.collection.objects.link(o)
                o.data.materials.clear()
                o.data.materials.append(mats[pal])
                add_weighted_normals(o)
                objects[(key, pal, lod)] = o
                path = OUT / f"mesh/{key}_{pal}_lod{lod}.gltf"
                export(o, path)
                rec = report["models"].setdefault(f"{key}_{pal}", dict(shape=key, palette=pal,
                                                                       label=f"{SHAPES[key]['label']}, {pal}",
                                                                       built_from=SOURCE_CHOICE[key], lods={}))
                rec["lods"][str(lod)] = dict(file=path.name, materials=1, textures=1, double_sided=False,
                                             texture_files=[f"textures/rocks_{pal}.png"], **mesh_stats(o))
    if RENDER:
        refs = {"tree_A": import_ref(TREES / "broadleaf_A_lod0.gltf", "ref_tree_A"),
                "tree_B": import_ref(TREES / "broadleaf_B_lod0.gltf", "ref_tree_B"),
                "tree_C": import_ref(TREES / "broadleaf_C_lod0.gltf", "ref_tree_C")}
        for n in ("bush_A", "bush_B", "bush_D", "bush_E", "flower_daisy", "flower_tulip_coral"):
            refs[n] = import_ref(SHRUBS / f"{n}_lod0.gltf", f"ref_{n}")
        renders(objects, compare, refs)
        for o in list(bpy.data.objects):
            if o.name.startswith("ref_"):
                bpy.data.objects.remove(o)
    for i, ((key, pal, lod), o) in enumerate(objects.items()):
        o.location = ((i // 4) * 1.8 - 3, (i % 4) * 1.6, 0)
        o.hide_render = False
    (OUT / "build_report.json").write_text(json.dumps(report, indent=1, default=str))
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "source/rocks_candidate.blend"), compress=True)
    print("ROCKS DONE", OUT)


main()
