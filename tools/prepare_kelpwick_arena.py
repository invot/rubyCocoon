"""Extract the supplied Stylized House, removing its antenna and original door."""
from pathlib import Path
from collections import defaultdict
import json
import math
import struct
import sys


def prepare(path):
    raw = Path(path).read_bytes()
    length = struct.unpack_from("<I", raw, 12)[0]
    gltf = json.loads(raw[20:20 + length])
    binary = raw[28 + length:]
    out = Path(__file__).resolve().parents[1] / "build" / "arena_source"
    out.mkdir(parents=True, exist_ok=True)
    (out / ".gdignore").touch()

    def accessor(index):
        a = gltf["accessors"][index]
        view = gltf["bufferViews"][a["bufferView"]]
        count = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a["type"]]
        fmt = {5126: "f", 5125: "I", 5123: "H", 5121: "B"}[a["componentType"]]
        start = view.get("byteOffset", 0) + a.get("byteOffset", 0)
        stride = view.get("byteStride", struct.calcsize(fmt) * count)
        return [struct.unpack_from("<" + fmt * count, binary, start + i * stride) for i in range(a["count"])]

    primitive = gltf["meshes"][0]["primitives"][0]
    # This export's first two matrices cancel their axis changes; the mesh-node transform remains.
    matrix = gltf["nodes"][3]["matrix"]
    vertices = [tuple((sum(matrix[j*4+i] * p[j] for j in range(3)) + matrix[12+i]) * 0.01 for i in range(3))
                for p in accessor(primitive["attributes"]["POSITION"])]
    normals = []
    for normal in accessor(primitive["attributes"]["NORMAL"]):
        n = [sum(matrix[j*4+i] * normal[j] for j in range(3)) for i in range(3)]
        size = math.sqrt(sum(v*v for v in n))
        normals.append([v / size for v in n])
    indices = [i[0] for i in accessor(primitive["indices"])]
    parent = list(range(len(vertices)))

    def root(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    welded = {}
    for i, p in enumerate(vertices):
        key = tuple(round(value, 5) for value in p)
        if key in welded:
            parent[root(i)] = root(welded[key])
        else:
            welded[key] = i
    for i in range(0, len(indices), 3):
        for offset in (1, 2):
            parent[root(indices[i+offset])] = root(indices[i])
    groups = defaultdict(set)
    for i in indices:
        groups[root(i)].add(i)
    removed = set()
    for group, points in groups.items():
        lo = [min(vertices[i][axis] for i in points) for axis in range(3)]
        hi = [max(vertices[i][axis] for i in points) for axis in range(3)]
        antenna = hi[0] < -0.28 and lo[1] > 0.09 and lo[2] > -0.1 and hi[2] < 0.1
        door = lo[0] > -0.09 and hi[0] < 0.055 and lo[1] >= -0.17 and hi[1] <= -0.04 and lo[2] > 0.379 and hi[2] < 0.402
        if antenna or door:
            removed.add(group)
            print("Removed", "antenna" if antenna else "door", group, len(points), "vertices")
    kept = [indices[i + corner] for i in range(0, len(indices), 3) if root(indices[i]) not in removed for corner in (0, 2, 1)]
    data = {"v": vertices, "n": normals, "uv": accessor(primitive["attributes"]["TEXCOORD_0"]), "idx": kept}
    (out / "model.json").write_text(json.dumps(data))
    image = gltf["images"][0]
    view = gltf["bufferViews"][image["bufferView"]]
    start = view.get("byteOffset", 0)
    (out / "colour.png").write_bytes(binary[start:start + view["byteLength"]])
    (out / "attribution.json").write_text(json.dumps(gltf["asset"].get("extras", {}), indent=2))
    print("Prepared", len(kept) // 3, "triangles")


if __name__ == "__main__":
    prepare(sys.argv[1])
