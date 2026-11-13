"""Render the supplied Stylized Rock pack's rocks as the game uses them (read-only), for the rework decision.

    python tools/local_resource.py -- "<blender.exe>" -b --factory-startup \
        -P tools/blender/art_candidates/rocks/inspect_source.py

Reads build/nature_split/<name>.json (cut by tools/prepare_stylized_nature.py; the pack stays untouched) and writes
build/art_candidates/rocks/inspect/. The 18 rock names share 7 distinct cuts (prepare_stylized_nature.py repeats
six boxes); one of each is rendered.
"""
import bpy, bmesh, json, math, pathlib
from mathutils import Vector

ROOT = pathlib.Path(__file__).resolve().parents[4]
OUT = ROOT / "build/art_candidates/rocks/inspect"
OUT.mkdir(parents=True, exist_ok=True)
UNIQUE = ["field_rock", "beach_rock", "rock_big", "rock_small", "mountain_6", "mountain_1", "mountain_0"]


def load(name):
    d = json.loads((ROOT / f"build/nature_split/{name}.json").read_text())
    v, uv = d["v"], d["uv"]
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    lay = bm.loops.layers.uv.new("UVMap")
    for t in range(0, len(v), 3):
        vs = [bm.verts.new((p[0], -p[2], p[1])) for p in v[t:t + 3]]  # Y-up -> Z-up
        try:
            f = bm.faces.new(vs)
        except ValueError:
            continue
        for lp, k in zip(f.loops, range(t, t + 3)):
            lp[lay].uv = (uv[k][0], uv[k][1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
    bm.to_mesh(me)
    bm.free()
    tex = ROOT / d["texture"].replace("res://", "")
    img = bpy.data.images.load(str(tex), check_existing=True)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    t = mat.node_tree.nodes.new("ShaderNodeTexImage")
    t.image = img
    mat.node_tree.links.new(t.outputs["Color"], mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE_NEXT"
    sc.view_settings.view_transform = "AgX"
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.62, 0.72, 0.86, 1)
    sun = bpy.data.objects.new("key", bpy.data.lights.new("key", "SUN"))
    sun.data.energy = 3.6; sun.rotation_euler = (math.radians(48), 0, math.radians(-35))
    sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = "ORTHO"
    sc.render.resolution_x, sc.render.resolution_y = 1800, 520
    report = {}
    for i, n in enumerate(UNIQUE):
        ob = load(n)
        ob.location = (i * 1.4 - 4.2, 0, 0)
        report[n] = dict(triangles=len(ob.data.polygons), dims=[round(x, 3) for x in ob.dimensions])
    cam.data.ortho_scale = 10.5
    pitch = math.atan2(7.0, 11.0)
    for tag, loc in [("front", Vector((0, -20, 0.5))),
                     ("game", Vector((0, -math.cos(pitch) * 20, math.sin(pitch) * 20 + 0.4)))]:
        cam.location = loc
        cam.rotation_euler = (Vector((0, 0, 0.4)) - loc).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = str(OUT / f"source_{tag}.png")
        bpy.ops.render.render(write_still=True)
    (OUT / "source_report.json").write_text(json.dumps(report, indent=1))
    print("INSPECT DONE", report)


main()
