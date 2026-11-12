"""Render the existing tree_oak derivative (read-only) for the broadleaf candidate's rework assessment.

blender -b --factory-startup -P tools/blender/art_candidates/broadleaf/inspect_source.py -- <out_dir>

Reads build/nature_split/tree_oak.json (made by tools/prepare_stylized_nature.py from the supplied
"Environment Pack - Stylized Nature" ZIP) and its palette texture. Nothing in the source is modified.
Writes source_views.png (front, side, gameplay angle) and source_report.json (triangle split by colour).
"""
import bpy, json, sys, math, pathlib
from mathutils import Vector

ROOT = pathlib.Path(__file__).resolve().parents[4]
SRC = ROOT / "build/nature_split/tree_oak.json"
out = ROOT / pathlib.Path(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else ROOT / "build/art_candidates/broadleaf/inspect"
out.mkdir(parents=True, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
d = json.loads(SRC.read_text())
tex_path = pathlib.Path(d["texture"].replace("res://", str(ROOT) + "/"))
img = bpy.data.images.load(str(tex_path))
W, H = img.size
px = list(img.pixels)


def sample(u, v):
    x = min(W - 1, max(0, int(u * W)))
    y = min(H - 1, max(0, int(v * H)))
    i = (y * W + x) * 4
    return px[i:i + 3]


verts, faces, cols = [], [], []
green = brown = 0
for t in range(0, len(d["v"]), 3):
    idx = []
    for k in range(3):
        p = d["v"][t + k]
        verts.append((p[0] * 3, -p[2] * 3, p[1] * 3))  # Godot Y-up -> Blender Z-up, 3 units tall
        idx.append(len(verts) - 1)
    faces.append(idx)
    uvc = [sum(d["uv"][t + k][j] for k in range(3)) / 3 for j in range(2)]
    c = sample(uvc[0], uvc[1])
    cols.append(c)
    if c[1] > c[0] and c[1] > c[2]:
        green += 1
    else:
        brown += 1
me = bpy.data.meshes.new("src_oak")
me.from_pydata(verts, [], faces)
me.update()
ca = me.color_attributes.new("col", "FLOAT_COLOR", "CORNER")
for fi, poly in enumerate(me.polygons):
    for li in poly.loop_indices:
        ca.data[li].color = (*cols[fi], 1.0)
ob = bpy.data.objects.new("src_oak", me)
bpy.context.scene.collection.objects.link(ob)
mat = bpy.data.materials.new("src")
mat.use_nodes = True
nt = mat.node_tree
attr = nt.nodes.new("ShaderNodeVertexColor")
attr.layer_name = "col"
nt.links.new(attr.outputs[0], nt.nodes["Principled BSDF"].inputs["Base Color"])
nt.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
me.materials.append(mat)

lo = [min(v[k] for v in verts) for k in range(3)]
hi = [max(v[k] for v in verts) for k in range(3)]
(out / "source_report.json").write_text(json.dumps({
    "source": str(SRC.relative_to(ROOT)), "triangles": len(faces), "green_tris": green, "other_tris": brown,
    "bbox_at_3_units_tall": [lo, hi]}, indent=1))

sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE_NEXT"
sc.render.resolution_x, sc.render.resolution_y = 512, 512
sc.world = bpy.data.worlds.new("w")
sc.world.color = (0.55, 0.62, 0.7)
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3.0
sun.rotation_euler = (math.radians(50), 0, math.radians(30))
sc.collection.objects.link(sun)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.type = "ORTHO"
cam.data.ortho_scale = 4.0
for name, (az, el) in {"front": (0, 5), "side": (90, 5), "game": (0, 52)}.items():
    a, e = math.radians(az), math.radians(el)
    cam.location = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * 12 + Vector((0, 0, 1.5))
    cam.rotation_euler = (Vector((0, 0, 1.5)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = str(out / f"source_{name}.png")
    bpy.ops.render.render(write_still=True)
print("done", out)
