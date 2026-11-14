"""Blender 4.2+: convert the exported roster into packed, individually editable .blend files.

blender --background --python tools/blender/save_beasts.py -- build/beasts_blender
Use --verify to reopen every saved file; --preview renders a representative sample.
"""
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def bounds():
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    objects = [o.evaluated_get(depsgraph) for o in scene.objects if o.type == 'MESH']
    points = [o.matrix_world @ v.co for o in objects for v in o.data.vertices]
    lo = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    hi = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    return (lo + hi) / 2, max(hi - lo)


def preview(path):
    scene = bpy.context.scene
    center, extent = bounds()
    camera_data = bpy.data.cameras.new('Preview camera')
    camera = bpy.data.objects.new('Preview camera', camera_data)
    scene.collection.objects.link(camera)
    camera.location = center + Vector((2.8, -4.0, 2.1)) * extent
    camera.rotation_euler = (center - camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera_data.type = 'ORTHO'
    camera_data.ortho_scale = extent * 1.5
    scene.camera = camera
    for name, offset, energy, size in [('Key', (1, -3, 4), 400, 4), ('Fill', (-3, 0, 2), 180, 4)]:
        data = bpy.data.lights.new(name, 'AREA')
        data.energy = energy * extent * extent
        data.shape = 'DISK'
        data.size = size * extent
        obj = bpy.data.objects.new(name, data)
        scene.collection.objects.link(obj)
        obj.location = center + Vector(offset) * extent
        obj.rotation_euler = (center - obj.location).to_track_quat('-Z', 'Y').to_euler()
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 16
    scene.render.resolution_x = 480
    scene.render.resolution_y = 480
    scene.render.resolution_percentage = 100
    if scene.world is None:
        scene.world = bpy.data.worlds.new('Preview world')
    scene.world.color = (0.25, 0.25, 0.25)
    scene.render.image_settings.file_format = 'PNG'
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


args = sys.argv[sys.argv.index('--') + 1:]
folder = Path(args[0]).resolve()
scene = bpy.context.scene
roster = json.loads((folder / 'manifest.json').read_text())
report = []
for entry in roster:
    target = folder / entry['file']
    if '--verify' in args:
        bpy.ops.wm.open_mainfile(filepath=str(target))
    else:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(folder / 'intermediate' / entry['source']))
        scene = bpy.context.scene
        scene.name = entry['name'] + (' Ghost' if entry['ghost'] else '')
        scene['race_id'] = entry['race_id']
        scene['source_project'] = 'Ruby Cocoon'
        scene['export_notes'] = 'Resting model with baked game paint. Godot runtime animations and particle smoke are not included.'
        scene.view_settings.view_transform = 'Standard'
        center, extent = bounds()
        # Make the packed paint visible immediately in the solid viewport, too.
        for material in bpy.data.materials:
            if material.use_nodes:
                for node in material.node_tree.nodes:
                    if node.type == 'TEX_IMAGE':
                        material.node_tree.nodes.active = node
                        break
        for screen in bpy.data.screens:
            for area in screen.areas:
                if area.type == 'VIEW_3D':
                    area.spaces.active.shading.color_type = 'TEXTURE'
                    area.spaces.active.region_3d.view_distance = extent * 2.5
                    area.spaces.active.region_3d.view_location = center
                    area.spaces.active.region_3d.view_rotation = Vector((2.8, -4, 2.1)).to_track_quat('Z', 'Y')
        bpy.ops.file.pack_all()
        bpy.context.preferences.filepaths.save_version = 0
        bpy.ops.wm.save_as_mainfile(filepath=str(target), compress=True)
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    armatures = [o for o in bpy.context.scene.objects if o.type == 'ARMATURE']
    assert meshes and sum(len(o.data.polygons) for o in meshes), entry
    assert not entry['rigged'] or armatures, entry
    assert all(image.packed_file for image in bpy.data.images if image.source == 'FILE'), entry
    report.append(dict(file=entry['file'], meshes=len(meshes), triangles=sum(len(o.data.polygons) for o in meshes),
                       bones=sum(len(o.data.bones) for o in armatures), packed_images=sum(bool(i.packed_file) for i in bpy.data.images)))
    print('VERIFIED' if '--verify' in args else 'SAVED', entry['file'], flush=True)
    if '--preview' in args and entry['file'].startswith(('00_', '27_', '30_', '39_', '43_', '47_')):
        preview(folder / 'previews' / (target.stem + '.png'))
(folder / ('verification.json' if '--verify' in args else 'conversion.json')).write_text(json.dumps(report, indent=2))
print('COMPLETE', len(report), flush=True)
