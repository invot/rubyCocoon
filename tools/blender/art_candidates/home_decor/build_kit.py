"""Home decor kit: art candidate builder (Blender 4.2, background).

    python tools/local_resource.py -- "<blender.exe>" -b --factory-startup \
        -P tools/blender/art_candidates/home_decor/build_kit.py -- --rev rev_001 [--quick]

Reads the atlases painted by paint_atlas.py (in <rev>/textures/), builds every
piece from simple rounded primitives, writes the tint mask into each mesh's
vertex colours (R fabric, G ceramic/accent, B wood, A trim paint; 0 = keep the
atlas colour), exports one glTF with every piece as its own named node, saves
the .blend, and renders candidate previews:

  previews/catalog_<category>.png   every piece, labelled, in one scheme, with a
                                    1.44-unit hero-height marker
  previews/vignette_<room>.png      three stage rooms from the gameplay camera
                                    (world.gd CAM_OFFSET_ROOM 0/4.6/8.2, fov 44)
                                    with the game's own beds/sofas (exported refs)
  previews/schemes.png              one corner in all colour schemes

Units: 1 = one tile; up = Blender +Z (glTF +Y). Floor pieces: origin at the base
centre. Wall pieces: origin at the centre of the back face, the piece facing -Y
(glTF +Z, the game's "inside" for a back wall). Previews are candidates, never
evidence of in-game integration.
"""
import bpy
import bmesh
import json
import math
import os
import sys
from mathutils import Vector, Matrix

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
REV = args[args.index("--rev") + 1] if "--rev" in args else "rev_001"
QUICK = "--quick" in args
OUT = os.path.join(ROOT, "build", "art_candidates", "home_decor", REV)
TEX = os.path.join(OUT, "textures")
REFS = os.path.join(ROOT, "build", "art_candidates", "home_decor", "refs")
HERE = os.path.dirname(os.path.abspath(__file__))
LAYOUT = json.load(open(os.path.join(TEX, "layout.json")))
ART = json.load(open(os.path.join(TEX, "art_layout.json")))  # the user's SVG prints (art_masks.py)
RECOLOURED = os.path.join(OUT, "previews", "recoloured")
SCHEMES = json.load(open(os.path.join(HERE, "schemes.json")))["schemes"]

REGION = {"none": (0, 0, 0, 0), "fabric": (1, 0, 0, 0), "ceramic": (0, 1, 0, 0), "wood": (0, 0, 1, 0), "trim": (0, 0, 0, 1)}
CELL_REGION = {"R": "fabric", "G": "ceramic", "B": "wood", "A": "trim", None: "none"}


# ------------------------------------------------------------------ mesh helpers
class Part:
    """A bmesh piece with one atlas cell (or a canvas) and a tint region."""

    def __init__(self, bm, cell, canvas=False):
        self.bm, self.cell, self.canvas = bm, cell, canvas
        self.hard = False  # boxes keep crisp creases; everything round is shaded fully smooth


def cell_uv(cell, canvas=False):
    if canvas:
        name, crop = cell.split(":")
        u0, y0, u1, y1 = ART["prints"][name]["uv_" + crop]
        return u0, 1 - y1, u1, 1 - y0
    u0, y0, u1, y1 = LAYOUT["cells"][cell]["uv"]
    return u0, 1 - y1, u1, 1 - y0  # Blender v is up


def region_of(cell, canvas=False):
    if canvas:
        return "none"
    return CELL_REGION[LAYOUT["cells"][cell]["tint"]]


def set_uv_box(bm, cell, canvas=False, flip=False):
    """Box projection of the part into its cell (no tiling: the cell is stretched over the part)."""
    u0, v0, u1, v1 = cell_uv(cell, canvas)
    uv = bm.loops.layers.uv.verify()
    co = [v.co for v in bm.verts]
    mn = Vector((min(c.x for c in co), min(c.y for c in co), min(c.z for c in co)))
    mx = Vector((max(c.x for c in co), max(c.y for c in co), max(c.z for c in co)))
    sz = mx - mn
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for l in f.loops:
            p = l.vert.co - mn
            if ax == 2:
                a, b = p.x / max(sz.x, 1e-5), p.y / max(sz.y, 1e-5)
            elif ax == 1:
                a, b = p.x / max(sz.x, 1e-5), p.z / max(sz.z, 1e-5)
            else:
                a, b = p.y / max(sz.y, 1e-5), p.z / max(sz.z, 1e-5)
            if flip:
                a, b = b, a
            l[uv].uv = (u0 + (u1 - u0) * a, v0 + (v1 - v0) * b)


def lathe(profile, seg, cell, closed=False, cap_top=True, cap_bottom=True, canvas=False):
    """Revolve [(r, z), ...] (bottom to top) about Z. u wraps around, v runs up the profile."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.verify()
    u0, v0, u1, v1 = cell_uv(cell, canvas)
    lens = [0.0]
    for i in range(1, len(profile)):
        lens.append(lens[-1] + math.dist(profile[i], profile[i - 1]))
    total = max(lens[-1], 1e-6)
    rings = []
    for (r, z) in profile:
        ring = []
        for j in range(seg + 1):
            a = j / seg * math.tau
            ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), z)))
        rings.append(ring)
    n = len(profile)
    rows = n if not closed else n + 1
    for i in range(rows - 1):
        ra, rb = rings[i % n], rings[(i + 1) % n]
        va = lens[i] / total if i < n else 1.0
        vb = lens[i + 1] / total if i + 1 < n else 1.0
        for j in range(seg):
            f = bm.faces.new((ra[j], ra[j + 1], rb[j + 1], rb[j]))
            for l, (uu, vv) in zip(f.loops, ((j / seg, va), ((j + 1) / seg, va), ((j + 1) / seg, vb), (j / seg, vb))):
                l[uv].uv = (u0 + (u1 - u0) * uu, v0 + (v1 - v0) * vv)
    cu, cv = (u0 + u1) / 2, (v0 + v1) / 2
    for idx, flag, rev in ((0, cap_bottom, True), (n - 1, cap_top, False)):
        if closed or not flag or profile[idx][0] < 1e-5:
            continue
        ring = rings[idx][:seg]
        c = bm.verts.new((0, 0, profile[idx][1]))
        for j in range(seg):
            vs = (c, ring[(j + 1) % seg], ring[j]) if rev else (c, ring[j], ring[(j + 1) % seg])
            f = bm.faces.new(vs)
            for l in f.loops:
                p = l.vert.co
                rr = max(profile[idx][0], 1e-5)
                l[uv].uv = (cu + (u1 - u0) * 0.45 * p.x / rr, cv + (v1 - v0) * 0.45 * p.y / rr)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return Part(bm, cell, canvas)


def rbox(sx, sy, sz, cell, bevel=0.02, segs=2, canvas=False):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * sx, v.co.y * sy, v.co.z * sz + sz / 2))
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=min(bevel, sx / 2.2, sy / 2.2, sz / 2.2), segments=segs,
                        profile=0.5, affect='EDGES', clamp_overlap=True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    set_uv_box(bm, cell, canvas)
    part = Part(bm, cell, canvas)
    part.hard = True
    return part


def blob(rx, ry, rz, cell, seed=0, lump=0.08, subdiv=None):
    """A pillowy lumpy dome/ball (the approved tree language: soft domes, no single leaves)."""
    bm = bmesh.new()
    if subdiv is None:
        subdiv = 3 if max(rx, ry, rz) >= 0.09 else 2
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
    for v in bm.verts:
        d = v.co.normalized()
        k = 1 + lump * (math.sin(d.x * 3.1 + seed) * math.sin(d.y * 2.7 + seed * 1.7) + 0.6 * math.sin(d.z * 4.3 + seed * 0.7))
        v.co = Vector((d.x * rx * k, d.y * ry * k, d.z * rz * k))
    uv = bm.loops.layers.uv.verify()
    u0, v0, u1, v1 = cell_uv(cell)
    for f in bm.faces:
        for l in f.loops:
            d = l.vert.co
            a = abs(math.atan2(d.y, d.x)) / math.pi  # mirrored: no wrap seam
            b = 0.5 + 0.5 * max(-1, min(1, d.z / max(rz, 1e-5)))
            l[uv].uv = (u0 + (u1 - u0) * a, v0 + (v1 - v0) * b)
    return Part(bm, cell)


def quad(w, h, cell, canvas=False, rounded=0.0):
    """A flat panel in the XZ plane facing -Y, centred on the origin."""
    bm = bmesh.new()
    vs = [bm.verts.new((-w / 2, 0, -h / 2)), bm.verts.new((w / 2, 0, -h / 2)), bm.verts.new((w / 2, 0, h / 2)), bm.verts.new((-w / 2, 0, h / 2))]
    f = bm.faces.new(vs)
    uv = bm.loops.layers.uv.verify()
    u0, v0, u1, v1 = cell_uv(cell, canvas)
    for l, (a, b) in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
        l[uv].uv = (u0 + (u1 - u0) * a, v0 + (v1 - v0) * b)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if f.normal.y > 0:
        bmesh.ops.reverse_faces(bm, faces=[f])
    return Part(bm, cell, canvas)


def disc(r, cell, seg=24, canvas=False):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.verify()
    u0, v0, u1, v1 = cell_uv(cell, canvas)
    c = bm.verts.new((0, 0, 0))
    ring = [bm.verts.new((r * math.cos(j / seg * math.tau), 0, r * math.sin(j / seg * math.tau))) for j in range(seg)]
    for j in range(seg):
        f = bm.faces.new((c, ring[(j + 1) % seg], ring[j]))
        for l in f.loops:
            p = l.vert.co
            l[uv].uv = (u0 + (u1 - u0) * (0.5 + 0.5 * p.x / r), v0 + (v1 - v0) * (0.5 + 0.5 * p.z / r))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if bm.faces[0].normal.y > 0:
        bmesh.ops.reverse_faces(bm, faces=list(bm.faces))
    return Part(bm, cell, canvas)


def torus(R, r, cell, seg=24, ring=8):
    prof = [(R + r * math.cos(k / ring * math.tau), r * math.sin(k / ring * math.tau)) for k in range(ring)]
    return lathe(prof, seg, cell, closed=True, cap_top=False, cap_bottom=False)


def xf(part, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    m = Matrix.Translation(Vector(loc)) @ Matrix.Rotation(rot[2], 4, 'Z') @ Matrix.Rotation(rot[1], 4, 'Y') @ \
        Matrix.Rotation(rot[0], 4, 'X') @ Matrix.Diagonal(Vector((*scale, 1)))
    bmesh.ops.transform(part.bm, matrix=m, verts=part.bm.verts)
    if scale[0] * scale[1] * scale[2] < 0:
        bmesh.ops.reverse_faces(part.bm, faces=part.bm.faces)
    return part


def tube(r0, r1, h, cell, seg=10):
    return lathe([(r0, 0), (r1, h)], seg, cell)


# ------------------------------------------------------------------ materials
def image(name):
    p = os.path.join(TEX, name)
    for im in bpy.data.images:
        if im.filepath == p:
            return im
    return bpy.data.images.load(p)


def export_material(name, img):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = image(img)
    nt.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.8
    return m


def hexrgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def preview_material(name, img, scheme, emissive=False):
    """Atlas * mix(1, tint, mask) per channel, for candidate renders only (the game does this in a shader)."""
    s = SCHEMES[scheme]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.75
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = image(img)
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "tint"
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(attr.outputs["Color"], sep.inputs["Color"])
    cur = t.outputs["Color"]
    for fac, key in ((sep.outputs[0], "fabric"), (sep.outputs[1], "ceramic"), (sep.outputs[2], "floor"), (attr.outputs["Alpha"], "trim")):
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = 'RGBA'
        mix.blend_type = 'MULTIPLY'
        nt.links.new(fac, mix.inputs["Factor"])
        nt.links.new(cur, mix.inputs[6])
        mix.inputs[7].default_value = (*hexrgb(s[key]), 1)
        cur = mix.outputs[2]
    nt.links.new(cur, bsdf.inputs["Base Color"])
    return m


def art_preview_material(scheme):
    """Preview only: the prints already recoloured for `scheme` (art_masks.py). The game recolours in a shader."""
    key = "art_" + scheme
    if key in bpy.data.materials:
        return bpy.data.materials[key]
    m = bpy.data.materials.new(key)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.85
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = bpy.data.images.load(os.path.join(RECOLOURED, scheme + ".png"))
    nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
    return m


def with_print(name, print_crop):
    """A copy of a framed piece showing another print: its canvas UVs moved from one print's rect to another's
    (in the game: the same remap as the canvas material's uv offset/scale)."""
    src = bpy.data.objects[name].data
    key = name + "@" + print_crop
    if key in bpy.data.meshes:
        return key
    me = src.copy()
    me.name = key
    old = [PIECES[name]["print"]]
    a0, b0, a1, b1 = cell_uv(old[0], True)
    n0, m0, n1, m1 = cell_uv(print_crop, True)
    uv = me.uv_layers.active.data
    for poly in me.polygons:
        if poly.material_index != 1:
            continue
        for li in poly.loop_indices:
            u, v = uv[li].uv
            fu, fv = (u - a0) / max(a1 - a0, 1e-6), (v - b0) / max(b1 - b0, 1e-6)
            uv[li].uv = (n0 + (n1 - n0) * fu, m0 + (m1 - m0) * fv)
    ob = bpy.data.objects.new(key, me)
    KIT.objects.link(ob)
    PIECES_ALIAS[key] = name
    return key


# ------------------------------------------------------------------ assembly
PIECES = {}
PIECES_ALIAS = {}


def piece(name, category, parts, place, note=""):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    col = bm.loops.layers.color.new("tint")
    uvl = bm.loops.layers.uv.verify()
    mat_idx = []
    for p in parts:
        for e in p.bm.edges:
            e.smooth = not (p.hard and len(e.link_faces) == 2 and e.calc_face_angle(0) > math.radians(40))
        tmp = bpy.data.meshes.new("tmp")
        p.bm.to_mesh(tmp)
        n0 = len(bm.faces)
        bm.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
        reg = REGION[region_of(p.cell, p.canvas)]
        bm.faces.ensure_lookup_table()
        for f in bm.faces[n0:]:
            f.material_index = 1 if p.canvas else 0
            for l in f.loops:
                l[col] = reg
        p.bm.free()
    bm.to_mesh(me)
    bm.free()
    me.materials.append(MAT_ATLAS)
    me.materials.append(MAT_CANVAS)
    for poly in me.polygons:
        poly.use_smooth = True
    me.color_attributes.active_color = me.color_attributes["tint"]
    try:
        me.color_attributes.render_color_index = me.color_attributes.active_color_index
    except Exception:
        pass
    ob = bpy.data.objects.new(name, me)
    KIT.objects.link(ob)
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    bb = [Vector(c) for c in ob.bound_box]
    size = Vector((max(c.x for c in bb) - min(c.x for c in bb), max(c.y for c in bb) - min(c.y for c in bb), max(c.z for c in bb) - min(c.z for c in bb)))
    regions = set()
    for i, c in enumerate(me.color_attributes["tint"].data):
        v = tuple(round(x) for x in c.color)
        for k, r in REGION.items():
            if v == r:
                regions.add(k)
    mount = "wall" if place.startswith("wall") else ("top" if place.startswith("top") else "floor")
    PIECES[name] = {"category": category, "mount": mount, "triangles": tris, "size_xyz": [round(size.x, 3), round(size.y, 3), round(size.z, 3)],
                    "place": place, "tint_regions": sorted(regions - {"none"}), "canvas": any(p.canvas for p in parts), "note": note,
                    "print": next((p.cell for p in parts if p.canvas), None)}
    return ob


# --------------------------------------------------------------- the pieces
def pot(r, h, cell="ceramic_band", lip=0.015, soil=True):
    prof = [(r * 0.72, 0), (r * 0.78, 0.01), (r * 0.98, h * 0.75), (r, h * 0.92), (r + lip, h * 0.95), (r + lip, h), (r * 0.92, h), (r * 0.9, h * 0.94)]
    parts = [lathe(prof, 20, cell, cap_top=False)]
    if soil:
        parts.append(xf(lathe([(r * 0.9, 0), (0.0, 0.004)], 20, "soil"), (0, 0, h * 0.9)))
    return parts


def build_lamps():
    # floor lamp with a rounded drum shade on a turned wooden stem
    p = [lathe([(0.17, 0), (0.17, 0.025), (0.15, 0.045), (0.05, 0.06), (0.0, 0.065)], 24, "wood_turned"),
         lathe([(0.028, 0.05), (0.022, 0.4), (0.03, 0.45), (0.02, 0.5), (0.018, 1.12), (0.026, 1.16), (0.0, 1.17)], 12, "wood_turned"),
         xf(lathe([(0.0, 0), (0.035, 0.0), (0.035, 0.06), (0.0, 0.06)], 10, "brass"), (0, 0, 1.13)),
         xf(lathe([(0.23, 0), (0.24, 0.015), (0.235, 0.27), (0.215, 0.29)], 28, "fabric_pleats", cap_top=False, cap_bottom=False), (0, 0, 1.17)),
         xf(lathe([(0.225, 0), (0.205, 0.285)], 28, "shade_inner", cap_top=False, cap_bottom=False), (0, 0, 1.17), scale=(1, -1, 1)),
         xf(lathe([(0.045, 0), (0.05, 0.05), (0.0, 0.1)], 10, "bulb"), (0, 0, 1.2))]
    piece("floor_lamp_drum", "lamps", p, "floor: beside a sofa arm or armchair, in a back corner; never in a walking lane",
          "1.46 tall: shade top just above the hero's head (1.44). Shade = fabric tint; stem/base = wood tint.")
    # tripod floor lamp
    p = []
    for k in range(3):
        a = k / 3 * math.tau + 0.4
        leg = tube(0.022, 0.016, 1.18, "wood_grain", 8)
        tilt = 0.14
        xf(leg, (0, 0, 0), (tilt, 0, 0))
        xf(leg, (math.cos(a) * 0.17, math.sin(a) * 0.17, 0), (0, 0, a - math.pi / 2))
        p.append(leg)
    p += [xf(lathe([(0.05, 0), (0.05, 0.05), (0.0, 0.05)], 12, "brass"), (0, 0, 1.12)),
          xf(lathe([(0.24, 0), (0.25, 0.012), (0.12, 0.24), (0.11, 0.25)], 28, "fabric_linen", cap_top=False, cap_bottom=False), (0, 0, 1.15)),
          xf(lathe([(0.235, 0), (0.105, 0.245)], 28, "shade_inner", cap_top=False, cap_bottom=False), (0, 0, 1.15), scale=(1, -1, 1)),
          xf(lathe([(0.045, 0), (0.05, 0.05), (0.0, 0.1)], 10, "bulb"), (0, 0, 1.17))]
    piece("floor_lamp_tripod", "lamps", p, "floor: reading corner beside an armchair, back or side wall",
          "Splayed wooden legs, cone linen shade.")
    # gourd table lamp
    p = [lathe([(0.045, 0), (0.06, 0.012), (0.085, 0.06), (0.09, 0.1), (0.07, 0.15), (0.04, 0.19), (0.03, 0.21), (0.035, 0.225), (0.0, 0.23)], 20, "ceramic_glaze"),
         xf(lathe([(0.012, 0), (0.012, 0.05), (0.0, 0.05)], 8, "brass"), (0, 0, 0.225)),
         xf(lathe([(0.13, 0), (0.135, 0.01), (0.09, 0.15), (0.085, 0.16)], 24, "fabric_pleats", cap_top=False, cap_bottom=False), (0, 0, 0.25)),
         xf(lathe([(0.125, 0), (0.08, 0.155)], 24, "shade_inner", cap_top=False, cap_bottom=False), (0, 0, 0.25), scale=(1, -1, 1))]
    piece("table_lamp_gourd", "lamps", p, "top: nightstand, dresser, side table, desk (replaces table_lamp / el_lamp)",
          "0.41 tall. Base = ceramic tint, shade = fabric tint.")
    # mushroom lamp
    p = [lathe([(0.06, 0), (0.065, 0.015), (0.03, 0.03), (0.025, 0.16), (0.0, 0.17)], 18, "ceramic_glaze"),
         xf(lathe([(0.0, 0.0), (0.13, 0.0), (0.14, 0.02), (0.12, 0.07), (0.07, 0.11), (0.0, 0.125)], 24, "ceramic_fluted"), (0, 0, 0.16)),
         xf(lathe([(0.125, 0), (0.0, 0.0)], 24, "shade_inner", cap_top=False, cap_bottom=False), (0, 0, 0.158))]
    piece("table_lamp_mushroom", "lamps", p, "top: kids' nightstands, desks, shelves", "A cute ribbed dome; all ceramic tint.")
    # wall sconce
    p = [xf(rbox(0.12, 0.03, 0.2, "wood_frame", 0.01), (0, 0.015, -0.1)),
         xf(tube(0.012, 0.012, 0.16, "brass", 8), (0, 0.03, 0.0), (math.radians(-80), 0, 0)),
         xf(lathe([(0.1, 0), (0.105, 0.01), (0.07, 0.13), (0.065, 0.14)], 20, "fabric_linen", cap_top=False, cap_bottom=False), (0, 0.17, 0.02)),
         xf(lathe([(0.095, 0), (0.06, 0.135)], 20, "shade_inner", cap_top=False, cap_bottom=False), (0, 0.17, 0.02), scale=(1, -1, 1))]
    for pp in p:
        xf(pp, (0, 0, 0), (0, 0, 0), (1, -1, 1))
    piece("wall_sconce", "lamps", p, "wall: either side of a bed head or a mirror, 1.6 up; replaces wall_light in homes", "")


def build_plants():
    # round pillow plant
    p = pot(0.15, 0.22)
    for k, (x, y, z, r) in enumerate(((0, 0, 0.36, 0.17), (0.1, 0.05, 0.3, 0.12), (-0.1, 0.04, 0.31, 0.12), (0.03, -0.1, 0.3, 0.12), (-0.02, 0.1, 0.45, 0.1))):
        p.append(xf(blob(r, r, r * 0.85, "leaf_green", k * 1.3), (x, y, z)))
    piece("plant_pillow_round", "plants", p, "floor or top: corners, beside dressers, on low tables (replaces plant_small)",
          "Pot = ceramic tint. Pillowy domes like the approved trees.")
    # tall pillow (fiddle/topiary) plant
    p = pot(0.2, 0.3)
    p.append(xf(tube(0.03, 0.022, 0.9, "wood_turned", 8), (0, 0, 0.26)))
    for k, (x, y, z, r) in enumerate(((0, 0, 1.16, 0.2), (0.14, 0.04, 1.02, 0.15), (-0.13, 0.03, 0.98, 0.15), (0.0, -0.12, 1.06, 0.14),
                                      (0.08, 0.02, 0.72, 0.13), (-0.08, -0.03, 0.66, 0.12))):
        p.append(xf(blob(r, r, r * 0.9, "leaf_deep", 2 + k), (x, y, z)))
    piece("plant_pillow_tall", "plants", p, "floor: a back corner or beside tall furniture, never mid-room (replaces plant_tall)",
          "1.36 tall: reads as height behind the action.")
    # paddle-leaf plant
    p = pot(0.17, 0.26, "terracotta")
    for k in range(9):
        a = k / 9 * math.tau + (0.3 if k % 2 else 0)
        h = 0.45 + 0.22 * ((k * 7) % 5) / 4
        tilt = 0.35 + 0.25 * (k % 3) / 2
        stem = tube(0.008, 0.006, h, "leaf_blade", 6)
        xf(stem, (0, 0, 0.22), (tilt, 0, a))
        tip = Vector((0, 0, h))
        tip.rotate(Matrix.Rotation(tilt, 3, 'X'))
        tip.rotate(Matrix.Rotation(a, 3, 'Z'))
        leaf = blob(0.07, 0.02, 0.12, "leaf_paddle", k, lump=0.02, subdiv=2)
        xf(leaf, (tip.x, tip.y, tip.z + 0.22), (tilt * 0.8, 0, a))
        p += [stem, leaf]
    piece("plant_paddle", "plants", p, "floor: a side wall corner or by a window (replaces plant_leafy)",
          "Rounded paddle leaves, no holes or fronds; terracotta pot.")
    # snake plant
    p = pot(0.11, 0.2, "ceramic_fluted")
    for k in range(7):
        a = k / 7 * math.tau
        h = 0.38 + 0.18 * ((k * 3) % 4) / 3
        blade = lathe([(0.03, 0), (0.036, h * 0.4), (0.026, h * 0.8), (0.0, h)], 6, "leaf_blade")
        xf(blade, (0, 0, 0), (0, 0, 0), (1, 0.35, 1))
        xf(blade, (math.cos(a) * 0.04, math.sin(a) * 0.04, 0.17), (0.1 * math.sin(a), 0.1 * math.cos(a), a))
        p.append(blade)
    piece("plant_blades", "plants", p, "floor or top: narrow spots (beside a door frame clear of its approach, bathroom, hall)", "")
    # hanging plant on a wall bracket
    p = [xf(rbox(0.04, 0.03, 0.16, "wood_frame", 0.01), (0, 0.015, -0.08)),
         xf(rbox(0.03, 0.22, 0.03, "wood_frame", 0.01), (0, 0.13, 0.04)),
         xf(tube(0.004, 0.004, 0.2, "rope", 6), (0, 0.22, -0.16)),
         ]
    pp = pot(0.1, 0.12, "ceramic_glaze")
    for q in pp:
        xf(q, (0, 0.22, -0.3))
    p += pp
    p.append(xf(blob(0.12, 0.11, 0.08, "leaf_sage", 9), (0, 0.22, -0.17)))
    for side, n in ((-1, 5), (1, 4), (0.15, 3)):
        for k in range(n):
            t = k / max(1, n - 1)
            p.append(xf(blob(0.055 - 0.015 * t, 0.05 - 0.012 * t, 0.075 - 0.01 * t, "leaf_sage", k + 3 * n, 0.05, 2),
                        (side * (0.085 + 0.02 * t), 0.22 + 0.02 * side, -0.24 - k * 0.085)))
    for q in p:
        xf(q, (0, 0, 0), (0, 0, 0), (1, -1, 1))
    piece("plant_hanging", "plants", p, "wall: bracket at 2.0 up beside a window or in a kitchen; trailing domes", "")
    # small succulent
    p = pot(0.06, 0.08, "terracotta")
    for k in range(7):
        a = k / 7 * math.tau
        p.append(xf(blob(0.02, 0.035, 0.015, "leaf_succulent", k, 0.02, 1), (math.cos(a) * 0.03, math.sin(a) * 0.03, 0.09), (0.5, 0, a + math.pi / 2)))
    p.append(xf(blob(0.02, 0.02, 0.02, "leaf_succulent", 3, 0.02, 1), (0, 0, 0.1)))
    piece("plant_succulent", "plants", p, "top: shelves, windowsills, desks", "")
    # flowers in a vase
    p = [lathe([(0.05, 0), (0.065, 0.03), (0.07, 0.1), (0.04, 0.17), (0.035, 0.2), (0.042, 0.215), (0.03, 0.215)], 18, "ceramic_glaze", cap_top=False)]
    for k, (x, y, z, r) in enumerate(((0, 0, 0.27, 0.09), (0.07, 0.02, 0.24, 0.065), (-0.07, 0.01, 0.24, 0.065))):
        p.append(xf(blob(r, r, r * 0.8, "leaf_green", k + 5, 0.05), (x, y, z)))
    for k, (x, y, z, cell) in enumerate(((0, -0.02, 0.36, "petal_pink"), (0.07, -0.04, 0.31, "petal_cream"), (-0.075, -0.03, 0.31, "petal_yellow"),
                                         (0.035, 0.05, 0.34, "petal_cream"), (-0.035, 0.05, 0.345, "petal_pink"), (0.1, 0.03, 0.27, "petal_pink"),
                                         (-0.1, 0.02, 0.27, "petal_cream"))):
        bloom = blob(0.036, 0.036, 0.026, cell, k, 0.0, 2)
        for v in bloom.bm.verts:  # five soft petals
            a_ = math.atan2(v.co.y, v.co.x)
            v.co.x *= 1 + 0.22 * math.cos(5 * a_)
            v.co.y *= 1 + 0.22 * math.cos(5 * a_)
        p.append(xf(bloom, (x, y, z), (-0.5, 0, 0)))
        p.append(xf(blob(0.011, 0.011, 0.008, "petal_yellow" if cell != "petal_yellow" else "petal_cream", k), (x, y - 0.012, z + 0.012), (-0.5, 0, 0)))
    piece("vase_flowers", "plants", p, "top: dining/coffee tables, dressers, counters (replaces el_flowers/el_vase in homes)", "")
    # plant stand
    p = [xf(rbox(0.3, 0.3, 0.03, "wood_planks", 0.01), (0, 0, 0.5)), xf(rbox(0.26, 0.26, 0.02, "wood_planks", 0.01), (0, 0, 0.12))]
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(xf(tube(0.016, 0.012, 0.53, "wood_grain", 8), (sx * 0.12, sy * 0.12, 0)))
    for q in pot(0.1, 0.14, "ceramic_band"):
        p.append(xf(q, (0, 0, 0.53)))
    for k, (x, y, z, r) in enumerate(((0, 0, 0.75, 0.12), (0.08, 0.02, 0.7, 0.09), (-0.08, 0.03, 0.7, 0.09))):
        p.append(xf(blob(r, r, r * 0.85, "leaf_green", k + 11), (x, y, z)))
    piece("plant_stand", "plants", p, "floor: side-wall wings, hall corners", "Wooden stand (wood tint) with a pot on top.")


def frame_parts(w, h, depth, bar, cell_frame, canvas, mat=0.0, round_r=0.0):
    """A picture frame on the wall (back at y=0, facing -Y) with its canvas set back inside."""
    parts = []
    if round_r > 0:
        ring = torus(round_r, bar / 2, cell_frame, 28, 8)
        xf(ring, (0, -depth / 2, 0), (math.pi / 2, 0, 0))
        parts.append(ring)
        parts.append(xf(disc(round_r, "paper"), (0, -0.004, 0)))
        parts.append(xf(disc(round_r - bar * 0.3, canvas, 28, canvas=True), (0, -0.008, 0)))
        return parts
    for (cx, cz, sx, sz) in ((0, h / 2 - bar / 2, w, bar), (0, -h / 2 + bar / 2, w, bar), (-w / 2 + bar / 2, 0, bar, h - 2 * bar + 0.002), (w / 2 - bar / 2, 0, bar, h - 2 * bar + 0.002)):
        b = rbox(sx, depth, sz, cell_frame, bevel=min(0.012, bar / 3), segs=2)
        xf(b, (cx, -depth / 2, cz - sz / 2))
        parts.append(b)
    parts.append(xf(quad(w - bar, h - bar, "paper"), (0, -0.006, 0)))
    iw, ih = w - 2 * bar - 2 * mat, h - 2 * bar - 2 * mat
    parts.append(xf(quad(iw, ih, canvas, canvas=True), (0, -0.01, 0)))
    return parts


def build_wall_art():
    piece("frame_landscape_large", "wall_art", frame_parts(1.04, 0.8, 0.045, 0.06, "wood_frame", "deep-WQ5YDICQb3M:landscape"),
          "wall: centred over a sofa or bed head, 1.55 up (centre)", "Prints: any of art_layout.json's prints, its uv_landscape crop.")
    piece("frame_landscape_small", "wall_art", frame_parts(0.6, 0.47, 0.035, 0.04, "paint_wood", "deep-K92pByP9tPQ:landscape", 0.035),
          "wall: gallery cluster", "Painted frame (trim tint) with a paper mat.")
    piece("frame_portrait", "wall_art", frame_parts(0.42, 0.56, 0.035, 0.035, "paint_wood", "royyan-wijaya-xfWHBCwMeQQ:portrait", 0.035),
          "wall: gallery cluster, hall, beside doors", "Prints: uv_portrait crop.")
    piece("frame_portrait_small", "wall_art", frame_parts(0.3, 0.4, 0.03, 0.03, "wood_frame", "deep-isf0PELGzBE:portrait", 0.025),
          "wall: gallery cluster, above desks and nightstands", "")
    piece("frame_round", "wall_art", frame_parts(0, 0, 0.03, 0.035, "ceramic_glaze", "deep-g5Jfpcd9VCo:square", round_r=0.24),
          "wall: gallery cluster accent", "Prints: uv_square crop.")
    # woven plate: a shallow dish
    p = [xf(lathe([(0.0, 0.0), (0.16, 0.0), (0.2, 0.025), (0.21, 0.03), (0.2, 0.032), (0.16, 0.008), (0.0, 0.008)], 28, "basket"), (0, 0, 0), (math.pi / 2, 0, 0)),
         xf(lathe([(0.0, 0.0), (0.155, 0.0), (0.155, 0.002), (0.0, 0.002)], 28, "basket"), (0, -0.008, 0), (math.pi / 2, 0, 0))]
    piece("woven_plate", "wall_art", p, "wall: in threes over a dining table or bench, 1.5-1.8 up", "Plain basket weave (no print).")
    p = [xf(torus(0.15, 0.012, "wood_turned", 28, 6), (0, -0.015, 0), (math.pi / 2, 0, 0)),
         xf(rbox(0.04, 0.02, 0.03, "brass", 0.006), (0, -0.015, 0.155)),
         xf(disc(0.148, "robin-granqvist-BiX562ApuHI:square", 28, canvas=True), (0, -0.012, 0))]
    piece("embroidery_hoop", "wall_art", p, "wall: bedrooms, kids' rooms, kitchens, in pairs", "A print's centre square, framed in a hoop.")
    # picture ledge with leaning frames
    p = [xf(rbox(1.1, 0.1, 0.03, "wood_planks", 0.008), (0, -0.05, 0)),
         xf(rbox(1.1, 0.012, 0.045, "wood_planks", 0.004), (0, -0.095, 0.02))]
    for (x, w, h, can) in ((-0.33, 0.3, 0.38, "deep-0ECAhyBYxhE:portrait"), (0.02, 0.36, 0.28, "robin-granqvist-olP9nSZefas:landscape"), (0.34, 0.22, 0.3, "simple-wallpapers-xzYpQyYH3FA:portrait")):
        fp = frame_parts(w, h, 0.02, 0.022, "paint_wood" if x < 0 else "wood_frame", can, 0.015)
        for q in fp:
            xf(q, (0, 0, h / 2))
            xf(q, (0, 0, 0), (math.radians(-8), 0, 0))
            xf(q, (x, -0.035, 0.03))
        p += fp
    p.append(xf(lathe([(0.03, 0), (0.035, 0.05), (0.015, 0.1), (0.018, 0.11), (0.0, 0.11)], 14, "ceramic_glaze"), (0.5, -0.05, 0.03)))
    piece("picture_ledge", "wall_art", p, "wall: over a bed head, sofa or desk, 1.4 up (the shelf)", "Three leaning frames and a bud vase.")
    # wall clock: round, no numerals
    p = [xf(lathe([(0.0, 0.0), (0.2, 0.0), (0.21, 0.02), (0.205, 0.045), (0.19, 0.05), (0.0, 0.05)], 28, "ceramic_glaze"), (0, 0, 0), (math.pi / 2, 0, 0)),
         xf(disc(0.17, "clock_face", 28), (0, -0.051, 0))]
    piece("wall_clock", "wall_art", p, "wall: kitchens, halls, living rooms, 1.8 up (replaces clock)", "Dots instead of numerals (no lettering on world objects).")
    # arched mirror
    arch = []
    w, h = 0.5, 0.82
    bar = 0.045
    for (cx, cz, sx, sz) in ((0, -h / 2 + bar / 2, w, bar), (-w / 2 + bar / 2, -0.05, bar, h - w / 2 - bar), (w / 2 - bar / 2, -0.05, bar, h - w / 2 - bar)):
        b = rbox(sx, 0.04, sz, "paint_wood", 0.012)
        xf(b, (cx, -0.02, cz - sz / 2 if sx == w else -h / 2 + bar))
        arch.append(b)
    top = torus(w / 2 - bar / 2, bar / 2, "paint_wood", 24, 6)
    bmesh.ops.delete(top.bm, geom=[v for v in top.bm.verts if v.co.y < -1e-4], context='VERTS')
    xf(top, (0, -0.02, h / 2 - w / 2), (math.pi / 2, 0, 0))
    arch.append(top)
    glass = quad(w - bar * 1.6, h - w / 2, "mirror")
    xf(glass, (0, -0.008, -0.05 - (w / 2) / 2 + 0.03))
    arch.append(glass)
    dome = disc(w / 2 - bar * 0.8, "mirror", 24)
    bmesh.ops.delete(dome.bm, geom=[v for v in dome.bm.verts if v.co.z < -1e-4], context='VERTS')
    xf(dome, (0, -0.008, h / 2 - w / 2))
    arch.append(dome)
    piece("mirror_arch", "wall_art", arch, "wall: above a dresser or basin, in halls; never opposite the camera's view of the hero", "Painted (trim) frame.")
    # floating shelf with things
    p = [xf(rbox(0.9, 0.2, 0.04, "wood_planks", 0.01), (0, -0.1, 0))]
    p.append(xf(lathe([(0.04, 0), (0.055, 0.05), (0.04, 0.12), (0.025, 0.15), (0.03, 0.16), (0.0, 0.16)], 14, "ceramic_glaze"), (-0.32, -0.1, 0.04)))
    for i, (x, hh) in enumerate(((-0.14, 0.17), (-0.1, 0.19), (-0.06, 0.16))):
        p.append(xf(rbox(0.035, 0.14, hh, "book_spines", 0.004), (x, -0.1, 0.04)))
    p.append(xf(rbox(0.16, 0.12, 0.035, "book_spines", 0.004), (0.12, -0.1, 0.04)))
    p.append(xf(rbox(0.13, 0.11, 0.03, "book_spines", 0.004), (0.12, -0.1, 0.075), (0, 0, 0.2)))
    for q in pot(0.05, 0.07, "terracotta"):
        p.append(xf(q, (0.32, -0.1, 0.04)))
    for k in range(5):
        a = k / 5 * math.tau
        p.append(xf(blob(0.018, 0.03, 0.013, "leaf_succulent", k, 0.02, 1), (0.32 + math.cos(a) * 0.025, -0.1 + math.sin(a) * 0.025, 0.115), (0.5, 0, a + math.pi / 2)))
    piece("floating_shelf", "wall_art", p, "wall: over desks, counters, beside windows, 1.45 up (the shelf)", "")
    # tapestry: a cloth on a rod
    p = [xf(tube(0.012, 0.012, 0.72, "wood_turned", 8), (-0.36, -0.03, 0.36), (0, math.pi / 2, 0)),
         xf(lathe([(0.0, 0), (0.02, 0.0), (0.02, 0.03), (0.0, 0.03)], 8, "wood_turned"), (-0.38, -0.03, 0.36), (0, math.pi / 2, 0)),
         xf(lathe([(0.0, 0), (0.02, 0.0), (0.02, 0.03), (0.0, 0.03)], 8, "wood_turned"), (0.35, -0.03, 0.36), (0, math.pi / 2, 0))]
    cloth = rbox(0.6, 0.012, 0.78, "fabric_patchwork", 0.004)
    xf(cloth, (0, -0.02, -0.44))
    p.append(cloth)
    for k in range(7):
        p.append(xf(lathe([(0.008, 0), (0.004, 0.06), (0.0, 0.065)], 6, "rope"), (-0.27 + k * 0.09, -0.02, -0.44), (math.pi, 0, 0)))
    piece("tapestry", "wall_art", p, "wall: a broad back wall over a bench or bed, 1.7 up (the rod)", "Patchwork cloth = fabric tint; swap to stripe/gingham cells.")
    # bunting
    p = [xf(tube(0.003, 0.003, 1.4, "rope", 5), (-0.7, -0.01, 0), (0, math.pi / 2, 0))]
    for k in range(8):
        x = -0.6 + k * 0.17
        sag = -0.06 * math.sin((k + 0.5) / 8 * math.pi)
        f = bmesh.new()
        uv = f.loops.layers.uv.verify()
        cell = "fabric_dots" if k % 2 else "ceramic_glaze"
        u0, v0, u1, v1 = cell_uv(cell)
        for yy, order in ((-0.003, (0, 1, 2)), (0.003, (0, 2, 1))):
            vs = [f.verts.new((-0.065, yy, 0)), f.verts.new((0.065, yy, 0)), f.verts.new((0, yy, -0.14))]
            face = f.faces.new([vs[i] for i in order])
            for l in face.loops:
                c = l.vert.co
                l[uv].uv = (u0 + (u1 - u0) * (c.x / 0.13 + 0.5), v0 + (v1 - v0) * (1 + c.z / 0.14))
        part = Part(f, cell)
        xf(part, (x, -0.01, sag))
        p.append(part)
    piece("bunting", "wall_art", p, "wall: kids' rooms, across a back wall at 2.2 up", "Alternating fabric/ceramic tints; no lettering.")


def build_trim():
    pr = [(0.0, 0.0), (0.03, 0.0), (0.03, 0.09), (0.022, 0.1), (0.022, 0.11), (0.012, 0.12), (0.0, 0.12)]

    def extrude(profile, length, cell, name, place, note):
        bm = bmesh.new()
        uv = bm.loops.layers.uv.verify()
        u0, v0, u1, v1 = cell_uv(cell)
        a = [bm.verts.new((-length / 2, -d, z)) for d, z in profile]
        b = [bm.verts.new((length / 2, -d, z)) for d, z in profile]
        n = len(profile)
        for i in range(n - 1):
            f = bm.faces.new((a[i], b[i], b[i + 1], a[i + 1]))
            for l, (uu, vv) in zip(f.loops, ((0, i / (n - 1)), (1, i / (n - 1)), (1, (i + 1) / (n - 1)), (0, (i + 1) / (n - 1)))):
                l[uv].uv = (u0 + (u1 - u0) * uu, v0 + (v1 - v0) * vv)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        for f in bm.faces:
            if f.normal.y > 0.5:
                pass
        piece(name, "trim", [Part(bm, cell)], place, note)

    extrude(pr, 1.0, "paint_eggshell", "baseboard", "wall: along every wall's foot, 1-unit modules (scale X to fit runs)", "Trim tint. Replaces the thin dark skirting.")
    crown = [(0.0, 0.0), (0.012, 0.0), (0.02, 0.02), (0.045, 0.06), (0.07, 0.1), (0.075, 0.11), (0.0, 0.11)]
    extrude([(d, -z) for d, z in crown[::-1]], 1.0, "paint_eggshell", "crown_moulding", "wall: along the top of back and side walls (origin at the ceiling line)", "")
    rail = [(0.0, 0.0), (0.018, 0.0), (0.025, 0.012), (0.025, 0.035), (0.018, 0.045), (0.0, 0.045)]
    extrude(rail, 1.0, "paint_eggshell", "chair_rail", "wall: 0.9 up, tops a wainscot or splits two paints", "")
    # wainscot modules
    p = [xf(rbox(1.0, 0.02, 0.88, "paint_beadboard", 0.002), (0, -0.01, 0)), xf(rbox(1.0, 0.035, 0.04, "paint_eggshell", 0.008), (0, -0.0175, 0.86))]
    piece("wainscot_beadboard", "trim", p, "wall: lower wall, 1-unit modules, under a chair rail (bedrooms, kitchens, bathrooms)", "")
    p = [xf(rbox(1.0, 0.02, 0.88, "paint_panel", 0.002), (0, -0.01, 0)), xf(rbox(1.0, 0.035, 0.04, "paint_eggshell", 0.008), (0, -0.0175, 0.86))]
    piece("wainscot_panel", "trim", p, "wall: lower wall, 1-unit modules (living rooms, halls)", "")


def build_soft():
    def puffed(sx, sy, sz, cell, bevel, puff):
        """A rounded box whose faces bulge: cushions, folded quilts, throws."""
        part = rbox(sx, sy, sz, cell, bevel, 3)
        part.hard = False
        bmesh.ops.subdivide_edges(part.bm, edges=[e for e in part.bm.edges if e.calc_length() > max(sx, sy, sz) * 0.3], cuts=3, use_grid_fill=True)
        for v in part.bm.verts:
            u, w = v.co.x / (sx / 2), (v.co.z - sz / 2) / (sz / 2)
            k = max(0.0, 1 - u * u) * max(0.0, 1 - w * w)
            v.co.y *= 1 + puff * k
        set_uv_box(part.bm, cell)
        return part
    p = [xf(puffed(0.4, 0.13, 0.38, "fabric_stripe", 0.05, 0.6), (0, 0, 0), (math.radians(-12), 0, 0))]
    piece("cushion_square", "soft", p, "on sofas/armchairs/beds: 2-3 per sofa, against the back", "Pattern: any fabric cell (linen, stripe, gingham, dots, knit, velvet).")
    p = [xf(lathe([(0.0, 0), (0.08, 0.005), (0.1, 0.03), (0.105, 0.2), (0.1, 0.37), (0.08, 0.395), (0.0, 0.4)], 18, "fabric_velvet"), (-0.2, 0, 0.1), (0, math.pi / 2, 0))]
    piece("cushion_bolster", "soft", p, "on sofa arms and bed heads", "")
    # throw blanket draped over an arm: a soft slab on top, one hanging down the outside, a rolled fold between
    top = puffed(0.48, 0.34, 0.04, "fabric_knit", 0.018, 0.0)
    xf(top, (0, 0.0, 0.0))
    fall = puffed(0.48, 0.04, 0.42, "fabric_knit", 0.018, 0.0)
    xf(fall, (0, 0.18, -0.4))
    roll = lathe([(0.0, 0.0), (0.034, 0.005), (0.04, 0.03), (0.04, 0.45), (0.034, 0.475), (0.0, 0.48)], 14, "fabric_knit")
    xf(roll, (-0.24, 0.165, 0.005), (0, math.pi / 2, 0))
    part = [top, fall, roll]
    for q in part:
        xf(q, (0, -0.15, 0.0))
    piece("throw_blanket", "soft", part, "on a sofa arm or armchair seat edge (origin on the arm top)", "Chunky knit, fabric tint.")
    p = [xf(rbox(1.5, 0.5, 0.08, "fabric_patchwork", 0.035, 3), (0, 0, 0)), xf(rbox(1.5, 0.12, 0.1, "fabric_patchwork", 0.04, 3), (0, 0.24, -0.06))]
    piece("quilt_fold", "soft", p, "on a bed's foot (double: as is; single: scale X 0.55)", "Patchwork, fabric tint.")
    p = [lathe([(0.0, 0), (0.2, 0.005), (0.25, 0.06), (0.26, 0.16), (0.24, 0.27), (0.18, 0.3), (0.0, 0.31)], 24, "fabric_knit")]
    piece("pouf", "soft", p, "floor: in front of an armchair or by a bed side, never in a lane", "")
    p = [lathe([(0.17, 0), (0.2, 0.02), (0.23, 0.32), (0.235, 0.34), (0.22, 0.34), (0.2, 0.05), (0.0, 0.05)], 22, "basket", cap_top=False)]
    for k, (x, y) in enumerate(((-0.06, 0.03), (0.07, -0.02), (0.0, 0.08))):
        p.append(xf(lathe([(0.0, 0), (0.06, 0.0), (0.065, 0.03), (0.065, 0.3), (0.06, 0.33), (0.0, 0.33)], 12, "fabric_knit" if k != 1 else "fabric_stripe"),
                    (x, y, 0.06), (0.15 * (k - 1), 0.1, 0)))
    piece("basket_blankets", "soft", p, "floor: beside a sofa end or at a bed foot, against a wall", "")


def build_tabletop():
    p = [lathe([(0.04, 0), (0.07, 0.03), (0.085, 0.09), (0.06, 0.16), (0.035, 0.19), (0.04, 0.21), (0.03, 0.21)], 18, "ceramic_band", cap_top=False)]
    piece("vase_round", "tabletop", p, "top: shelves, dressers, coffee tables", "")
    p = [lathe([(0.035, 0), (0.045, 0.02), (0.04, 0.2), (0.025, 0.26), (0.022, 0.3), (0.028, 0.31), (0.018, 0.31)], 14, "ceramic_fluted", cap_top=False),
         xf(tube(0.004, 0.003, 0.18, "leaf_blade", 5), (0, 0, 0.28), (0.15, 0, 0)), xf(blob(0.03, 0.03, 0.03, "flower_dome", 1, 0.03, 1), (0, -0.03, 0.46))]
    piece("vase_bud", "tabletop", p, "top: windowsills, nightstands, shelves", "")
    p = [lathe([(0.0, 0), (0.07, 0), (0.13, 0.05), (0.14, 0.07), (0.13, 0.07), (0.07, 0.015), (0.0, 0.015)], 22, "ceramic_glaze")]
    for k, (x, y, z) in enumerate(((0, 0, 0.06), (0.06, 0.02, 0.05), (-0.05, 0.04, 0.05), (0.01, -0.06, 0.05), (0.0, 0.01, 0.1))):
        p.append(xf(blob(0.04, 0.04, 0.04, "fruit", k, 0.05, 1), (x, y, z)))
    piece("bowl_fruit", "tabletop", p, "top: dining tables, counters", "")
    p = []
    for i, (w, h, d, rot) in enumerate(((0.26, 0.04, 0.19, 0.0), (0.24, 0.035, 0.17, 0.15), (0.21, 0.03, 0.15, -0.1))):
        p.append(xf(rbox(w, d, h, "book_spines", 0.005), (0, 0, sum(x[1] for x in ((0.26, 0.04), (0.24, 0.035), (0.21, 0.03))[:i])), (0, 0, rot)))
    piece("books_stack", "tabletop", p, "top: coffee tables, nightstands, desks", "")
    p = [xf(rbox(0.26, 0.12, 0.015, "wood_planks", 0.006), (0, 0, 0))]
    for (x, h) in ((-0.06, 0.12), (0.05, 0.08)):
        p.append(xf(lathe([(0.03, 0), (0.03, h), (0.0, h)], 14, "candle"), (x, 0, 0.015)))
        p.append(xf(lathe([(0.0, 0), (0.008, 0.01), (0.0, 0.03)], 6, "bulb"), (x, 0, 0.015 + h)))
    piece("candles", "tabletop", p, "top: coffee tables, mantels, dressers", "Flame tips are glow cells.")
    p = [lathe([(0.04, 0), (0.07, 0.02), (0.08, 0.06), (0.06, 0.1), (0.03, 0.11), (0.0, 0.11)], 18, "ceramic_glaze"),
         xf(lathe([(0.012, 0), (0.0, 0.02)], 6, "ceramic_glaze"), (0, 0, 0.11)),
         xf(tube(0.012, 0.006, 0.09, "ceramic_glaze", 6), (0.07, 0, 0.04), (0, 0.9, 0)),
         xf(torus(0.03, 0.007, "ceramic_glaze", 12, 6), (-0.08, 0, 0.06), (math.pi / 2, 0, 0))]
    for x in (0.14, -0.15):
        p.append(xf(lathe([(0.025, 0), (0.03, 0.04), (0.027, 0.045), (0.0, 0.01)], 12, "ceramic_band", cap_top=False), (x, 0.04, 0)))
    piece("tea_set", "tabletop", p, "top: kitchen tables, coffee tables", "")
    p = frame_parts(0.16, 0.2, 0.02, 0.018, "wood_frame", "balaji-krishnamurty-KxjJTr35lls:portrait", 0.012)
    for q in p:
        xf(q, (0, 0, 0.1))
        xf(q, (0, 0, 0), (math.radians(-12), 0, 0))
    p.append(xf(rbox(0.02, 0.08, 0.1, "wood_frame", 0.004), (0, 0.04, 0), (math.radians(20), 0, 0)))
    piece("photo_standing", "tabletop", p, "top: nightstands, dressers, desks, shelves (replaces el_photo)", "")


# ------------------------------------------------------------------ preview scene helpers
def clear_scene():
    for ob in list(bpy.data.objects):
        if ob.name not in PIECES and ob.name not in PIECES_ALIAS:
            bpy.data.objects.remove(ob)


def link_copy(name, loc, rot_z=0.0, scale=(1, 1, 1), coll=None, mat=None):
    src = bpy.data.objects[name]
    ob = bpy.data.objects.new(name + "_i", src.data)
    ob.location = loc
    ob.rotation_euler = (0, 0, rot_z)
    ob.scale = scale
    (coll or bpy.context.scene.collection).objects.link(ob)
    if mat:
        ob.material_slots[0].link = 'OBJECT'
        ob.material_slots[0].material = mat[0]
        ob.material_slots[1].link = 'OBJECT'
        ob.material_slots[1].material = mat[1]
    return ob


def import_ref(name, loc, rot_z=0.0, coll=None):
    p = os.path.join(REFS, name + ".glb")
    if not os.path.exists(p):
        return None
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=p)
    new = [o for o in bpy.data.objects if o not in before]
    root = bpy.data.objects.new(name + "_ref", None)
    (coll or bpy.context.scene.collection).objects.link(root)
    for o in new:
        if o.parent is None:
            o.parent = root
    root.location = loc
    root.rotation_euler = (0, 0, rot_z)
    return root


def flat_mat(name, hexcol, rough=0.85):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*hexrgb(hexcol), 1)
    b.inputs["Roughness"].default_value = rough
    return m


def floor_mat(scheme):
    """Preview-only floor: soft boards tinted with the scheme's floor colour (the game has its own floor shader)."""
    s = SCHEMES[scheme]
    m = bpy.data.materials.new("floor_" + scheme)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.7
    tc = nt.nodes.new("ShaderNodeTexCoord")
    br = nt.nodes.new("ShaderNodeTexBrick")
    br.inputs["Scale"].default_value = 1.0
    br.inputs["Mortar Size"].default_value = 0.012
    br.inputs["Brick Width"].default_value = 2.4
    br.inputs["Row Height"].default_value = 0.25
    br.offset = 0.4
    base = hexrgb(s["floor"])
    br.inputs["Color1"].default_value = (*base, 1)
    br.inputs["Color2"].default_value = (*(c * 0.88 for c in base), 1)
    br.inputs["Mortar"].default_value = (*(c * 0.62 for c in base), 1)
    nt.links.new(tc.outputs["Object"], br.inputs["Vector"])
    nt.links.new(br.outputs["Color"], b.inputs["Base Color"])
    return m


def rug_mat(scheme):
    s = SCHEMES[scheme]
    m = bpy.data.materials.new("rug_" + scheme)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.95
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    # border band near the edges (generated coords 0..1)
    def edge(axis):
        m1 = nt.nodes.new("ShaderNodeMath"); m1.operation = 'SUBTRACT'; m1.inputs[0].default_value = 0.5
        nt.links.new(sep.outputs[axis], m1.inputs[1])
        a = nt.nodes.new("ShaderNodeMath"); a.operation = 'ABSOLUTE'; nt.links.new(m1.outputs[0], a.inputs[0])
        return a
    mx = nt.nodes.new("ShaderNodeMath"); mx.operation = 'MAXIMUM'
    nt.links.new(edge(0).outputs[0], mx.inputs[0]); nt.links.new(edge(1).outputs[0], mx.inputs[1])
    band = nt.nodes.new("ShaderNodeMapRange")
    band.inputs["From Min"].default_value = 0.38; band.inputs["From Max"].default_value = 0.39
    nt.links.new(mx.outputs[0], band.inputs["Value"])
    band2 = nt.nodes.new("ShaderNodeMapRange")
    band2.inputs["From Min"].default_value = 0.43; band2.inputs["From Max"].default_value = 0.44
    nt.links.new(mx.outputs[0], band2.inputs["Value"])
    mixa = nt.nodes.new("ShaderNodeMix"); mixa.data_type = 'RGBA'
    rug = hexrgb(s["rug"])
    mixa.inputs[6].default_value = (*rug, 1)
    mixa.inputs[7].default_value = (*(c * 0.72 for c in rug), 1)
    nt.links.new(band.outputs[0], mixa.inputs["Factor"])
    mixb = nt.nodes.new("ShaderNodeMix"); mixb.data_type = 'RGBA'
    nt.links.new(mixa.outputs[2], mixb.inputs[6])
    mixb.inputs[7].default_value = (*(min(1, c * 1.12 + 0.03) for c in rug), 1)
    nt.links.new(band2.outputs[0], mixb.inputs["Factor"])
    nt.links.new(mixb.outputs[2], b.inputs["Base Color"])
    return m


def box_obj(name, size, loc, mat, coll):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    ob.location = loc
    me.materials.append(mat)
    coll.objects.link(ob)
    return ob


def room_shell(coll, scheme, outline, wainscot=None):
    """outline: list of wall segments (x0, y0, x1, y1, inside_normal) in tile units; floor: list of rects."""
    pass


def setup_render(w, h, samples):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.film_transparent = False
    sc.view_settings.view_transform = 'AgX'
    sc.view_settings.look = 'AgX - Medium High Contrast'
    try:
        sc.view_settings.look = 'AgX - Base Contrast'
    except Exception:
        pass


def world(col, strength, seen=None):
    """Ambient light of `col`; the camera sees `seen` instead (the game's black void round a stage room)."""
    wd = bpy.data.worlds.new("w")
    wd.use_nodes = True
    nt = wd.node_tree
    bg = nt.nodes["Background"]
    bg.inputs[0].default_value = (*hexrgb(col), 1)
    bg.inputs[1].default_value = strength
    if seen:
        lp = nt.nodes.new("ShaderNodeLightPath")
        bg2 = nt.nodes.new("ShaderNodeBackground")
        bg2.inputs[0].default_value = (*hexrgb(seen), 1)
        mix = nt.nodes.new("ShaderNodeMixShader")
        nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs[0])
        nt.links.new(bg.outputs[0], mix.inputs[1])
        nt.links.new(bg2.outputs[0], mix.inputs[2])
        nt.links.new(mix.outputs[0], nt.nodes["World Output"].inputs[0])
    bpy.context.scene.world = wd


def add_light(kind, loc, energy, color="#ffffff", size=1.0, rot=(0, 0, 0), coll=None):
    l = bpy.data.lights.new("l", kind)
    l.energy = energy
    l.color = hexrgb(color)
    if kind == 'AREA':
        l.size = size
    elif kind in ('POINT', 'SPOT'):
        l.shadow_soft_size = size
    ob = bpy.data.objects.new("l", l)
    ob.location = loc
    ob.rotation_euler = rot
    (coll or bpy.context.scene.collection).objects.link(ob)
    return ob


def camera_at(target, offset=(0, -8.2, 4.6), fov=44, ortho=None):
    cam = bpy.data.cameras.new("cam")
    cam.sensor_fit = 'VERTICAL'
    cam.angle_y = math.radians(fov)
    if ortho:
        cam.type = 'ORTHO'
        cam.ortho_scale = ortho
    ob = bpy.data.objects.new("cam", cam)
    bpy.context.scene.collection.objects.link(ob)
    t = Vector(target)
    ob.location = t + Vector(offset)
    ob.rotation_euler = (t - ob.location).to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.camera = ob
    return ob


def render(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


# ------------------------------------------------------------------ vignettes
def wall_seg(coll, x0, y0, x1, y1, scheme, wains=None, H=2.8, T=0.2):
    """A wall along a segment; returns direction vectors. Walls run through tile edges here (preview)."""
    s = SCHEMES[scheme]
    L = math.dist((x0, y0), (x1, y1))
    ang = math.atan2(y1 - y0, x1 - x0)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    wm = MATS.setdefault("wall_" + scheme, flat_mat("wall_" + scheme, s["wall"], 0.9))
    ob = box_obj("wall", (L + T, T, H), (cx, cy, H / 2), wm, coll)
    ob.rotation_euler = (0, 0, ang)
    return ang, L


def place_run(coll, name, x0, y0, x1, y1, inside, z, scheme_mats, depth_off=0.1):
    """Lay 1-unit trim modules along a wall's inner face."""
    L = math.dist((x0, y0), (x1, y1))
    n = max(1, round(L))
    dx, dy = (x1 - x0) / L, (y1 - y0) / L
    yaw = math.atan2(-inside[0], inside[1]) + math.pi  # piece faces -Y; turn it to face `inside`
    for i in range(n):
        t = (i + 0.5) * L / n
        px, py = x0 + dx * t + inside[0] * depth_off, y0 + dy * t + inside[1] * depth_off
        link_copy(name, (px, py, z), yaw, (L / n, 1, 1), coll, scheme_mats)


def face_yaw(inside):
    # pieces face -Y; rotate so they face `inside` (a unit vector in XY)
    return math.atan2(inside[0], -inside[1])


def hang(coll, name, x, y, z, inside, mats, off=0.1, art=None):
    if art:
        name = with_print(name, art)
    return link_copy(name, (x + inside[0] * off, y + inside[1] * off, z), face_yaw(inside), coll=coll, mat=mats)


def vignette(kind, scheme, path, samples):
    clear_scene()
    coll = bpy.context.scene.collection
    s = SCHEMES[scheme]
    mats = (preview_material("pv_" + scheme, "decor_atlas.png", scheme), art_preview_material(scheme))
    trim_m = MATS.setdefault("trim_" + scheme, flat_mat("trim_" + scheme, s["trim"], 0.6))
    lower_m = MATS.setdefault("lower_" + scheme, flat_mat("lower_" + scheme, s["wall_lower"], 0.85))
    floor_m = floor_mat(scheme)
    edge_m = MATS.setdefault("edge", flat_mat("edge", "#3a2c24"))
    wall_m = MATS.setdefault("wall_" + scheme, flat_mat("wall_" + scheme, s["wall"], 0.9))
    world("#ffe6c8", 0.55, "#0d0b0a")

    def window(x, y, inside, curtains=True):
        yaw = face_yaw(inside)
        r = import_ref("window", (x + inside[0] * 0.1, y + inside[1] * 0.1, 0.85), yaw, coll)
        if curtains:
            import_ref("curtains_2", (x + inside[0] * 0.18, y + inside[1] * 0.18, 2.32 - 1.733), yaw, coll)

    def door(x, y, inside):
        import_ref("door_1", (x + inside[0] * 0.1, y + inside[1] * 0.1, 0), face_yaw(inside), coll)

    def floor_rect(x0, y0, x1, y1):
        box_obj("floor", (x1 - x0, y1 - y0, 0.35), ((x0 + x1) / 2, (y0 + y1) / 2, -0.175), floor_m, coll)

    def wall(x0, y0, x1, y1, inside, wains=False, base=True, crown=True):
        wall_seg(coll, x0, y0, x1, y1, scheme)
        off = 0.1
        if wains:
            L = math.dist((x0, y0), (x1, y1))
            n = max(1, round(L))
            dx, dy = (x1 - x0) / L, (y1 - y0) / L
            for i in range(n):
                t = (i + 0.5) * L / n
                link_copy(wains, (x0 + dx * t + inside[0] * off, y0 + dy * t + inside[1] * off, 0.0), face_yaw(inside), (L / n, 1, 1), coll, mats)
        if base:
            place_run(coll, "baseboard", x0, y0, x1, y1, inside, 0.0, mats, off)
        if crown:
            place_run(coll, "crown_moulding", x0, y0, x1, y1, inside, 2.8, mats, off)

    if kind == "living":
        W, D = 8.0, 5.0
        floor_rect(0, 0, W, D)
        wall(0, D, W, D, (0, -1), "wainscot_panel")
        wall(0, 0, 0, D, (1, 0))
        wall(W, 0, W, D, (-1, 0))
        rug = box_obj("rug", (4.0, 3.0, 0.01), (3.8, 2.4, 0.006), rug_mat(scheme), coll)
        import_ref("sofa_cottage", (3.8, D - 0.6, 0), 0)
        import_ref("armchair_club", (0.75, 2.6, 0), -math.pi / 2)
        import_ref("coffee_square", (3.8, 2.6, 0), 0)
        import_ref("bookshelf", (7.0, D - 0.3, 0), 0)
        for x, rz in ((3.45, 0.15), (4.15, -0.15)):
            link_copy("cushion_square", (x, D - 0.62, 0.45), rz, coll=coll, mat=mats)
        link_copy("cushion_bolster", (2.98, D - 0.55, 0.52), 0, coll=coll, mat=mats)
        link_copy("throw_blanket", (4.75, D - 0.45, 0.62), -math.pi / 2, coll=coll, mat=mats)
        link_copy("floor_lamp_drum", (2.5, D - 0.42, 0), 0, coll=coll, mat=mats)
        window(1.35, D, (0, -1))
        door(W, 2.4, (-1, 0))
        link_copy("candles", (4.05, 2.4, 0.4), 0.3, coll=coll, mat=mats)
        link_copy("photo_standing", (6.75, D - 0.3, 1.18), -0.2, coll=coll, mat=mats)
        link_copy("vase_round", (7.3, D - 0.3, 1.18), 0, coll=coll, mat=mats)
        link_copy("plant_pillow_tall", (0.45, D - 0.45, 0), 0, coll=coll, mat=mats)
        link_copy("plant_paddle", (7.5, 0.9, 0), 0, coll=coll, mat=mats)
        link_copy("basket_blankets", (5.3, D - 0.4, 0), 0, coll=coll, mat=mats)
        link_copy("books_stack", (3.6, 2.6, 0.4), 0.2, coll=coll, mat=mats)
        link_copy("vase_flowers", (4.0, 2.65, 0.4), 0, coll=coll, mat=mats)
        # gallery wall over the sofa
        g = D - 0.1
        hang(coll, "frame_landscape_large", 3.8, D, 1.75, (0, -1), mats)
        hang(coll, "frame_portrait", 2.95, D, 1.78, (0, -1), mats, art="deep-hzLpphmacLc:portrait")
        hang(coll, "frame_round", 4.75, D, 1.95, (0, -1), mats)
        hang(coll, "frame_portrait_small", 4.7, D, 1.45, (0, -1), mats, art="deep-3YErd7Gwol0:portrait")
        hang(coll, "frame_landscape_small", 2.95, D, 2.38, (0, -1), mats, art="marchell-manuputty-m-RoRWg-TMU:landscape")
        hang(coll, "wall_clock", 6.0, D, 1.95, (0, -1), mats)
        hang(coll, "floating_shelf", 0.1, 2.6, 1.55, (1, 0), mats)
        hang(coll, "woven_plate", 0.1, 3.6, 1.9, (1, 0), mats)
        hang(coll, "woven_plate", 0.1, 4.05, 1.6, (1, 0), mats)
        hang(coll, "mirror_arch", W, 3.6, 1.6, (-1, 0), mats)
        hang(coll, "plant_hanging", W, 1.1, 2.2, (-1, 0), mats)
        hang(coll, "wall_sconce", W, 3.05, 1.7, (-1, 0), mats)
        target = (W / 2, D / 2 - 0.3, 0.6)
        lamp_pts = [(2.5, D - 0.42, 1.3)]
    elif kind == "bedroom":
        W, D = 7.0, 5.0
        floor_rect(0, 0, W, D)
        wall(0, D, W, D, (0, -1), "wainscot_beadboard")
        wall(0, 0, 0, D, (1, 0), "wainscot_beadboard")
        wall(W, 0, W, D, (-1, 0), "wainscot_beadboard")
        box_obj("rug", (3.0, 4.0, 0.01), (3.5, 2.3, 0.006), rug_mat(scheme), coll)
        import_ref("bed_double_panel", (3.5, D - 1.15, 0), 0)
        import_ref("nightstand", (2.2, D - 0.35, 0), 0)
        import_ref("nightstand", (4.8, D - 0.35, 0), 0)
        import_ref("dresser", (W - 0.35, 1.7, 0), math.pi / 2)
        import_ref("wardrobe", (0.3, 3.9, 0), -math.pi / 2)
        link_copy("quilt_fold", (3.5, D - 2.0, 0.62), 0, coll=coll, mat=mats)
        for x in (3.1, 3.9):
            link_copy("cushion_square", (x, D - 0.4, 0.6), 0, coll=coll, mat=mats)
        link_copy("table_lamp_gourd", (2.2, D - 0.35, 0.62), 0, coll=coll, mat=mats)
        link_copy("table_lamp_gourd", (4.8, D - 0.35, 0.62), 0, coll=coll, mat=mats)
        link_copy("photo_standing", (4.95, D - 0.3, 0.62), 0.3, coll=coll, mat=mats)
        link_copy("vase_flowers", (W - 0.35, 1.4, 0.72), 0, coll=coll, mat=mats)
        link_copy("candles", (W - 0.35, 2.05, 0.72), math.pi / 2, coll=coll, mat=mats)
        link_copy("plant_blades", (6.75, D - 0.35, 0), 0, coll=coll, mat=mats)
        link_copy("plant_succulent", (5.5, D - 0.13, 1.23), 0, coll=coll, mat=mats)
        link_copy("pouf", (5.3, 2.4, 0), 0, coll=coll, mat=mats)
        link_copy("basket_blankets", (0.4, 1.0, 0), 0, coll=coll, mat=mats)
        # the player's bedroom print (user's choice, 2026-11-12): deep-IHWzHs98vQ8, centred over the bed
        link_copy(with_print("frame_portrait", "deep-IHWzHs98vQ8:portrait"), (3.5, D - 0.1, 1.95), 0, (1.35, 1, 1.35), coll, mats)
        hang(coll, "picture_ledge", 6.0, D, 1.2, (0, -1), mats)
        hang(coll, "wall_sconce", 1.75, D, 1.65, (0, -1), mats)
        hang(coll, "wall_sconce", 5.25, D, 1.65, (0, -1), mats)
        hang(coll, "mirror_arch", W, 1.7, 1.55, (-1, 0), mats)
        hang(coll, "embroidery_hoop", 0.75, D, 1.75, (0, -1), mats)
        hang(coll, "embroidery_hoop", 1.15, D, 1.45, (0, -1), mats, art="deep-WQ5YDICQb3M:square")
        window(0, 2.6, (1, 0))
        door(W, 3.6, (-1, 0))
        hang(coll, "frame_portrait", 0, 1.6, 1.6, (1, 0), mats, art="deep-j-oNlEbFrpU:portrait")
        hang(coll, "frame_portrait_small", 0, 1.05, 1.75, (1, 0), mats, art="royyan-wijaya-IqxGxkuk088:portrait")
        target = (W / 2, D / 2 - 0.3, 0.6)
        lamp_pts = [(2.2, D - 0.35, 0.95), (4.8, D - 0.35, 0.95)]
    else:  # notched den: an alcove in the back wall and a corner notch at the front left
        W, D = 8.0, 5.0
        floor_rect(0, 0, W, D)
        floor_rect(3.0, D, 6.0, D + 1.5)       # the alcove
        # back wall with the alcove opening (x 3..6); the back-left corner is a closet notch (x 0..2, y 3.4..5)
        wall(2.0, D, 3.0, D, (0, -1), "wainscot_panel")
        wall(6.0, D, W, D, (0, -1), "wainscot_panel")
        wall(3.0, D + 1.5, 6.0, D + 1.5, (0, -1), "wainscot_panel")
        wall(3.0, D, 3.0, D + 1.5, (1, 0), "wainscot_panel")
        wall(6.0, D, 6.0, D + 1.5, (-1, 0), "wainscot_panel")
        wall(0, 0, 0, 3.4, (1, 0))
        wall(0, 3.4, 2.0, 3.4, (0, -1), "wainscot_panel")
        wall(2.0, 3.4, 2.0, D, (1, 0), "wainscot_panel")
        wall(W, 0, W, D, (-1, 0))
        box_obj("notch_block", (2.0, 1.6, 2.8), (1.0, 4.2, 1.4), wall_m, coll)
        box_obj("rug", (3.0, 2.0, 0.01), (4.5, D + 0.15, 0.006), rug_mat(scheme), coll)
        import_ref("armchair_club", (4.1, D + 0.85, 0), 0)
        import_ref("side_table", (5.2, D + 1.1, 0), 0)
        import_ref("bookshelf", (7.0, D - 0.3, 0), 0)
        import_ref("table_pedestal", (1.6, 2.0, 0), 0)
        import_ref("chair_spindle", (0.8, 2.0, 0), -math.pi / 2)
        import_ref("chair_spindle", (2.4, 2.0, 0), math.pi / 2)
        link_copy("floor_lamp_tripod", (3.45, D + 1.15, 0), 0, coll=coll, mat=mats)
        link_copy("throw_blanket", (4.55, D + 0.95, 0.6), -math.pi / 2, coll=coll, mat=mats)
        link_copy("cushion_square", (4.1, D + 1.15, 0.45), 0, coll=coll, mat=mats)
        link_copy("tea_set", (5.2, D + 1.1, 0.7), 0, coll=coll, mat=mats)
        link_copy("bowl_fruit", (1.6, 2.0, 0.74), 0, coll=coll, mat=mats)
        link_copy("plant_stand", (2.65, D - 0.35, 0), 0, coll=coll, mat=mats)
        door(W, 1.1, (-1, 0))
        window(0, 1.4, (1, 0))
        link_copy("plant_pillow_round", (0.4, 3.0, 0), 0, coll=coll, mat=mats)
        link_copy("pouf", (4.1, D + 0.15, 0), 0, coll=coll, mat=mats)
        hang(coll, "tapestry", 4.5, D + 1.5, 1.95, (0, -1), mats)
        hang(coll, "frame_landscape_small", 1.25, 3.4, 1.7, (0, -1), mats, art="pixeliota-X3F-M3I7TuM:landscape")
        hang(coll, "frame_round", 0.45, 3.4, 1.85, (0, -1), mats)
        hang(coll, "frame_portrait_small", 2.5, D, 1.75, (0, -1), mats, art="deep-5-dZ-bHPMAY:portrait")
        hang(coll, "woven_plate", 2.0, 4.0, 1.75, (1, 0), mats)
        hang(coll, "woven_plate", 2.0, 4.55, 1.5, (1, 0), mats)
        hang(coll, "frame_landscape_large", W, 2.6, 1.65, (-1, 0), mats, art="anna-magenta-ua598LHEvBE:landscape")
        hang(coll, "wall_clock", 0, 2.6, 2.0, (1, 0), mats)
        target = (W / 2, D / 2 - 0.1, 0.6)
        lamp_pts = [(3.45, D + 1.15, 1.25)]
    # the dark edge under the open front, like the game's stage rooms
    box_obj("front_edge", (20, 0.4, 0.4), (4, -0.2, -0.2), edge_m, coll)
    add_light('AREA', (target[0], target[1] - 3.0, 4.8), 520, "#fff1dc", 6.0, (math.radians(35), 0, 0))
    add_light('AREA', (target[0] - 2.0, target[1] + 1.0, 2.7), 120, "#ffe3c0", 4.0, (0, 0, 0))
    for lp in lamp_pts:
        add_light('POINT', lp, 35, "#ffcf8a", 0.15)
    camera_at(target, fov=44)
    render(path)


def schemes_sheet(path_dir, samples):
    """A sofa corner in every scheme, small, to compare palettes."""
    out = []
    for sch in SCHEMES:
        clear_scene()
        coll = bpy.context.scene.collection
        s = SCHEMES[sch]
        mats = (preview_material("pv_" + sch, "decor_atlas.png", sch), art_preview_material(sch))
        world("#ffe6c8", 0.55, "#0d0b0a")
        box_obj("floor", (5, 3.5, 0.3), (2.5, 1.75, -0.15), floor_mat(sch), coll)
        wall_seg(coll, 0, 3.5, 5, 3.5, sch)
        wall_seg(coll, 0, 0, 0, 3.5, sch)
        for i in range(5):
            link_copy("wainscot_panel", (i + 0.5, 3.4, 0), 0, coll=coll, mat=mats)
            link_copy("baseboard", (i + 0.5, 3.4, 0), 0, coll=coll, mat=mats)
        for i in range(3):
            link_copy("wainscot_panel", (0.1, i + 0.5 + 0.5, 0), face_yaw((1, 0)), coll=coll, mat=mats)
        box_obj("rug", (3.0, 2.0, 0.01), (2.6, 1.7, 0.006), rug_mat(sch), coll)
        import_ref("sofa_love", (2.6, 2.95, 0), 0)
        link_copy("cushion_square", (2.3, 2.93, 0.43), 0.1, coll=coll, mat=mats)
        link_copy("throw_blanket", (3.55, 3.05, 0.6), -math.pi / 2, coll=coll, mat=mats)
        link_copy("floor_lamp_drum", (1.2, 3.1, 0), 0, coll=coll, mat=mats)
        link_copy("plant_pillow_round", (4.3, 3.05, 0), 0, coll=coll, mat=mats)
        link_copy("vase_flowers", (2.6, 1.7, 0.01), 0, coll=coll, mat=mats)
        hang(coll, "frame_landscape_small", 2.25, 3.5, 1.7, (0, -1), mats)
        hang(coll, "frame_round", 3.05, 3.5, 1.8, (0, -1), mats)
        hang(coll, "wall_clock", 0, 2.2, 1.8, (1, 0), mats)
        add_light('AREA', (2.5, -1.5, 4.5), 380, "#fff1dc", 5.0, (math.radians(35), 0, 0))
        add_light('POINT', (1.2, 3.1, 1.3), 25, "#ffcf8a", 0.15)
        camera_at((2.4, 1.9, 0.7), (0, -6.2, 3.5), 44)
        p = os.path.join(path_dir, "scheme_%s.png" % sch)
        render(p)
        out.append((sch, p))
    return out


def tiles(out_dir, scheme="seafoam_cottage"):
    """One framed render per piece (make_sheets.py lays them out with labels)."""
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene
    sc.render.resolution_x = sc.render.resolution_y = 420
    for n, info in PIECES.items():
        clear_scene()
        coll = sc.collection
        mats = (preview_material("pv_t", "decor_atlas.png", scheme), art_preview_material(scheme))
        world("#ece6dd", 1.0)
        sx, sy, sz = info["size_xyz"]
        wall = info["mount"] == "wall"
        ob = link_copy(n, (0, 0, 0), 0, coll=coll, mat=mats)
        bb = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
        mn = Vector([min(c[i] for c in bb) for i in range(3)])
        mx = Vector([max(c[i] for c in bb) for i in range(3)])
        ctr = (mn + mx) / 2
        size = max((mx - mn).length, 0.12)
        box_obj("ground", (6, 6, 0.02), (0, 0, mn.z - 0.01), flat_mat("g", "#ddd5c8"), coll)
        if wall:
            box_obj("wallp", (6, 0.05, 6), (0, 0.03, ctr.z), flat_mat("w", "#f1e9dc"), coll)
            off = Vector((0.25, -1.0, 0.3))
        else:
            off = Vector((0.55, -1.0, 0.62))
        add_light('SUN', (0, 0, 5), 2.6, "#fff4e4", 0.0, (math.radians(45), math.radians(12), math.radians(-30)))
        camera_at(tuple(ctr), tuple(off.normalized() * size * 1.9), 30)
        render(os.path.join(out_dir, n + ".png"))


def lineup(path, scheme="seafoam_cottage"):
    """Old lamps and plants beside the new ones, with a hero-height (1.44) marker."""
    clear_scene()
    coll = bpy.context.scene.collection
    mats = (preview_material("pv_l", "decor_atlas.png", scheme), art_preview_material(scheme))
    world("#ece6dd", 1.0)
    old = ["floor_lamp", "table_lamp", "plant_small", "plant_tall", "plant_leafy"]
    new = ["floor_lamp_drum", "floor_lamp_tripod", "table_lamp_gourd", "table_lamp_mushroom", "plant_pillow_round",
           "plant_pillow_tall", "plant_paddle", "plant_blades", "plant_stand", "vase_flowers", "plant_succulent"]
    x = 0.0
    hm = flat_mat("hero", "#e05a4f", 0.6)
    box_obj("hero_h", (0.05, 0.05, 1.44), (x, 0.3, 0.72), hm, coll)
    x += 0.6
    for n in old:
        r = import_ref(n, (x, 0, 0), 0, coll)
        x += 0.7
    x += 0.6
    box_obj("divider", (0.03, 2.0, 0.01), (x - 0.4, 0, 0.005), flat_mat("dv", "#9a8f80"), coll)
    for n in new:
        w = max(PIECES[n]["size_xyz"][0], 0.25)
        link_copy(n, (x + w / 2, 0, 0), 0, coll=coll, mat=mats)
        x += w + 0.35
    box_obj("ground", (x + 6, 6, 0.02), (x / 2, 1, -0.01), flat_mat("g", "#ddd5c8"), coll)
    box_obj("back", (x + 6, 0.05, 4), (x / 2, 2.0, 2.0), flat_mat("w", "#f1e9dc"), coll)
    add_light('SUN', (0, 0, 5), 2.6, "#fff4e4", 0.0, (math.radians(45), math.radians(12), math.radians(-30)))
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = 2000, 640
    camera_at((x / 2 - 0.3, 0, 0.62), (0, -14, 3.2), 30, ortho=x + 0.4)
    render(path)


# ------------------------------------------------------------------ main
def main():
    os.makedirs(os.path.join(OUT, "mesh"), exist_ok=True)
    os.makedirs(os.path.join(OUT, "previews"), exist_ok=True)
    os.makedirs(os.path.join(OUT, "source"), exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    global KIT, MAT_ATLAS, MAT_CANVAS, MATS
    MATS = {}
    KIT = bpy.data.collections.new("home_decor_kit")
    bpy.context.scene.collection.children.link(KIT)
    MAT_ATLAS = export_material("decor_atlas", "decor_atlas.png")
    MAT_CANVAS = export_material("art_masks", "art_masks.png")
    build_lamps()
    build_plants()
    build_wall_art()
    build_trim()
    build_soft()
    build_tabletop()
    # export the kit: every piece its own node at the origin
    for ob in bpy.data.objects:
        ob.select_set(ob.name in PIECES)
    glb = os.path.join(OUT, "mesh", "home_decor_kit.glb")
    kw = dict(filepath=glb, export_format='GLB', use_selection=True, export_apply=True, export_yup=True,
              export_texcoords=True, export_normals=True, export_materials='EXPORT')
    try:
        bpy.ops.export_scene.gltf(**kw, export_vertex_color='ACTIVE', export_all_vertex_colors=False)
    except TypeError:
        bpy.ops.export_scene.gltf(**kw, export_colors=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "source", "home_decor_kit.blend"))
    report = {"pieces": PIECES}
    # previews (hide the kit masters)
    KIT.hide_render = True
    samples = 12 if QUICK else 48
    setup_render(1600, 900, samples)
    if "--den-only" in args:
        setup_render(1600, 900, samples)
        for sch in ("forest_cabin", "adobe_turquoise"):
            vignette("den", sch, os.path.join(OUT, "previews", "vignette_den_%s.png" % sch), samples)
        with open(os.path.join(OUT, "build_report.json"), "w") as f:
            json.dump(report, f, indent=1)
        print("BUILT", len(PIECES), "pieces (den previews only)")
        return
    tiles(os.path.join(OUT, "previews", "tiles"))
    lineup(os.path.join(OUT, "previews", "lineup_lamps_plants.png"))
    setup_render(1600 if not QUICK else 800, 900 if not QUICK else 450, samples)
    for kind, sch in (("living", "seafoam_cottage"), ("bedroom", "lavender_honey"), ("den", "forest_cabin"),
                      ("living", "dusk_study"), ("bedroom", "mint_cherry"), ("den", "adobe_turquoise")):
        vignette(kind, sch, os.path.join(OUT, "previews", "vignette_%s_%s.png" % (kind, sch)), samples)
    setup_render(640, 400, max(12, samples // 2))
    os.makedirs(os.path.join(OUT, "previews", "schemes"), exist_ok=True)
    schemes_sheet(os.path.join(OUT, "previews", "schemes"), samples)
    with open(os.path.join(OUT, "build_report.json"), "w") as f:
        json.dump(report, f, indent=1)
    print("BUILT", len(PIECES), "pieces")


main()
