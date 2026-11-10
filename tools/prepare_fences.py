"""Extract the supplied fence sections without their display lawns.

python tools/prepare_fences.py [directory containing the three supplied downloads]
Original downloads stay untouched; intermediate files live under ignored build/.
"""
import json
import math
from pathlib import Path
import struct
import sys
import zipfile

from split_nature import read

SOURCE = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / 'Downloads'
OUT = Path('build/fences_source')
OUT.mkdir(parents=True, exist_ok=True)


def glb(path):
    data = path.read_bytes()
    size = struct.unpack_from('<I', data, 12)[0]
    return json.loads(data[20:20 + size]), data[28 + size:]


def accessor(doc, binary, index):
    a = doc['accessors'][index]
    view = doc['bufferViews'][a['bufferView']]
    count = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3}[a['type']]
    fmt = '<' + {5126: 'f', 5123: 'H', 5125: 'I'}[a['componentType']] * count
    stride = view.get('byteStride', struct.calcsize(fmt))
    offset = view.get('byteOffset', 0) + a.get('byteOffset', 0)
    return [struct.unpack_from(fmt, binary, offset + i * stride) for i in range(a['count'])]


def clipped(vertices, axis, boundary, above):
    result = []
    for i, end in enumerate(vertices):
        start = vertices[i - 1]
        a = start[0][axis] >= boundary if above else start[0][axis] <= boundary
        b = end[0][axis] >= boundary if above else end[0][axis] <= boundary
        if a != b:
            t = (boundary - start[0][axis]) / (end[0][axis] - start[0][axis])
            result.append(tuple(tuple(x + (y - x) * t for x, y in zip(p, q)) for p, q in zip(start, end)))
        if b:
            result.append(end)
    return result


def export(name, verts, uvs, normals, faces, box, texture, height):
    triangles = []
    for face in faces:
        points = [verts[c[0]] for c in face]
        # The supplied OBJ includes degenerate strip connectors between distant pieces.
        if max(math.dist(points[i], points[(i + 1) % 3]) for i in range(3)) > 125:
            continue
        poly = [(verts[c[0]], uvs[c[1]], normals[c[2]]) for c in face]
        for axis, lo, hi in [(0, box[0], box[1]), (1, box[2], box[3])]:
            if poly:
                poly = clipped(poly, axis, lo, True)
            if poly:
                poly = clipped(poly, axis, hi, False)
        for i in range(1, len(poly) - 1):
            triangles.append([poly[0], poly[i], poly[i + 1]])
    assert triangles, name
    all_points = [c[0] for t in triangles for c in t]
    low = [min(p[k] for p in all_points) for k in range(3)]
    high = [max(p[k] for p in all_points) for k in range(3)]
    output = {'v': [], 'uv': [], 'n': [], 'texture': texture}
    for tri in triangles:
        for p, uv, n in tri:
            # Sources are Z-up; the game is Y-up, with fences running along X.
            output['v'].append([(p[0] - (low[0] + high[0]) / 2) / (high[0] - low[0]),
                                (p[2] - low[2]) * height / (high[2] - low[2]),
                                -(p[1] - (low[1] + high[1]) / 2) / (high[0] - low[0])])
            output['uv'].append([uv[0], 1 - uv[1]])
            output['n'].append([n[0] * (high[0] - low[0]), n[2] * (high[2] - low[2]) / height,
                                -n[1] * (high[0] - low[0])])
    (OUT / (name + '.json')).write_text(json.dumps(output), encoding='utf-8')
    print(name, len(triangles), 'triangles')


doc, binary = glb(SOURCE / 'low_poly_wood_fence_on_grass.glb')
p = doc['meshes'][1]['primitives'][0]
v = accessor(doc, binary, p['attributes']['POSITION'])
uv = accessor(doc, binary, p['attributes']['TEXCOORD_0'])
n = accessor(doc, binary, p['attributes']['NORMAL'])
indices = [c[0] for c in accessor(doc, binary, p['indices'])]
faces = [[(c, c, c) for c in indices[i:i + 3]] for i in range(0, len(indices), 3)]
view = doc['bufferViews'][doc['images'][1]['bufferView']]
(OUT / 'wood.png').write_bytes(binary[view.get('byteOffset', 0):view.get('byteOffset', 0) + view['byteLength']])
export('fence', v, uv, n, faces, (-129.33, -79.33, 93.0, 102.0),
       'res://build/fences_source/wood.png', 0.78)

with zipfile.ZipFile(SOURCE / 'Low Poly stone fence on grass.zip') as archive:
    for name in ['model_1.obj', 'fence1.png']:
        (OUT / name).write_bytes(archive.read('collection/' + name))
v, uv, n, faces = read(OUT / 'model_1.obj')
export('stone_fence', v, uv, n, faces, (-165, -90, 80, 109),
       'res://build/fences_source/fence1.png', 0.72)
(OUT / 'iron_fence.glb').write_bytes((SOURCE / 'iron_fence.glb').read_bytes())
