"""Render user-supplied reference GLBs (read-only) for the broadleaf candidate lane.

blender -b --factory-startup -P tools/blender/art_candidates/broadleaf/inspect_refs.py -- <out_dir> <a.glb> [<b.glb> ...]

Each file is imported into an empty scene, scaled to about 3 units tall, and rendered front-on and at the game
camera's pitch. Nothing is written next to the source files.
"""
import bpy, sys, math, pathlib
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
out = pathlib.Path(args[0])
out.mkdir(parents=True, exist_ok=True)
for path in args[1:]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    lo = Vector([min(p[k] for p in pts) for k in range(3)])
    hi = Vector([max(p[k] for p in pts) for k in range(3)])
    size = hi - lo
    s = 3.0 / max(size.z, max(size.x, size.y) * 0.75)
    root = bpy.data.objects.new("root", None)
    bpy.context.scene.collection.objects.link(root)
    for o in list(bpy.data.objects):
        if o.parent is None and o is not root:
            o.parent = root
    root.scale = (s, s, s)
    root.location = (-(lo.x + hi.x) / 2 * s, -(lo.y + hi.y) / 2 * s, -lo.z * s)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE_NEXT"
    sc.eevee.taa_render_samples = 32
    sc.render.resolution_x, sc.render.resolution_y = 640, 640
    sc.view_settings.view_transform = "AgX"
    sc.world = bpy.data.worlds.new("w")
    sc.world.use_nodes = True
    sc.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.62, 0.72, 0.86, 1)
    sun = bpy.data.objects.new("key", bpy.data.lights.new("key", "SUN"))
    sun.data.energy, sun.data.angle = 3.6, math.radians(9)
    sun.data.color = (1.0, 0.94, 0.84)
    sun.rotation_euler = (math.radians(48), 0, math.radians(-35))
    sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = max(3.6, max(size.x, size.y) * s * 1.15)
    pitch = math.atan2(6.0, 11.0)
    tgt = Vector((0, 0, min(1.5, size.z * s / 2)))
    name = pathlib.Path(path).stem
    for view, loc in {"front": Vector((0, -20, 1.5)),
                      "game": Vector((0, -math.cos(pitch) * 20, math.sin(pitch) * 20 + 1.5))}.items():
        cam.location = loc
        cam.rotation_euler = (tgt - loc).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = str(out / f"{name}_{view}.png")
        bpy.ops.render.render(write_still=True)
    print("REF", name, "size", tuple(round(x, 3) for x in size), "scale", round(s, 4))
