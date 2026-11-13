"""Read-only technical check of an immutable READY broadleaf delivery; writes outside candidate ownership."""
import hashlib
import json
from pathlib import Path
import struct
import math
from collections import Counter
import argparse

ROOT = Path(__file__).resolve().parents[1]
REV = ROOT / "build/art_candidates/broadleaf/rev_001"
OUT = ROOT / "build/perf/vo/art-review/broadleaf-rev_001.json"


def accessor(gltf, index):
    entry = gltf["accessors"][index]
    view = gltf["bufferViews"][entry["bufferView"]]
    path = REV / "mesh" / gltf["buffers"][view["buffer"]]["uri"]
    assert path.resolve().is_relative_to(REV.resolve())
    raw = path.read_bytes()
    fmt = {5126: "f", 5125: "I", 5123: "H", 5121: "B"}[entry["componentType"]]
    width = {"VEC3": 3, "VEC2": 2, "SCALAR": 1}[entry["type"]]
    fmt = "<" + fmt * width
    stride = view.get("byteStride", struct.calcsize(fmt))
    offset = view.get("byteOffset", 0) + entry.get("byteOffset", 0)
    return [struct.unpack_from(fmt, raw, offset + i * stride) for i in range(entry["count"])]


def main():
    global REV, OUT
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--revision", default="rev_001", choices=["rev_001", "rev_002", "rev_003"])
    args = parser.parse_args()
    REV = ROOT / "build/art_candidates/broadleaf" / args.revision
    OUT = ROOT / "build/perf/vo/art-review" / ("broadleaf-" + args.revision + ".json")
    ready = json.loads((REV / "READY.json").read_text())
    result = {"revision": ready["revision"], "manifest_sha256": hashlib.sha256((REV / "READY.json").read_bytes()).hexdigest(),
              "hash_mismatches": [], "geometry": {}, "provenance_hashes": {}, "textures": {}}
    for name, expected in ready["files"].items():
        path = REV / name
        assert path.resolve().is_relative_to(REV.resolve())
        raw = path.read_bytes()
        if len(raw) != expected["bytes"] or hashlib.sha256(raw).hexdigest() != expected["sha256"]:
            result["hash_mismatches"].append(name)
    result["files_checked"] = len(ready["files"])
    provenance = ready["source_provenance"]
    for name in ["derivative", "derivative_texture"]:
        if name in provenance:
            entry = provenance[name]
            result["provenance_hashes"][name] = hashlib.sha256((ROOT / entry["path"]).read_bytes()).hexdigest() == entry["sha256"]
    if "model" in provenance:
        result["provenance_hashes"]["original_model"] = hashlib.sha256((REV / "source/original/stylized_tree.glb").read_bytes()).hexdigest() == provenance["model"]["sha256"]
    for path in sorted((REV / "mesh/textures").glob("*.png")):
        raw = path.read_bytes()
        assert raw[:8] == b"\x89PNG\r\n\x1a\n" and raw[12:16] == b"IHDR"
        width, height, depth, color = struct.unpack_from(">IIBB", raw, 16)
        result["textures"][path.name] = {"size": [width, height], "bit_depth": depth, "png_color_type": color}
    for path in sorted((REV / "mesh").glob("*.gltf")):
        gltf = json.loads(path.read_text())
        triangles = 0
        invalid_indices = 0
        degenerates = 0
        bad_normals = 0
        bad_uvs = 0
        attributes_missing = []
        bounds = []
        topology = []
        for mesh in gltf["meshes"]:
            for prim in mesh["primitives"]:
                attrs = prim["attributes"]
                attributes_missing.extend(k for k in ["POSITION", "NORMAL", "TEXCOORD_0"] if k not in attrs)
                positions = accessor(gltf, attrs["POSITION"])
                normals = accessor(gltf, attrs["NORMAL"])
                uvs = accessor(gltf, attrs["TEXCOORD_0"])
                indices = [v[0] for v in accessor(gltf, prim["indices"])]
                assert prim.get("mode", 4) == 4 and len(indices) % 3 == 0
                triangles += len(indices) // 3
                invalid_indices += sum(i >= len(positions) for i in indices)
                bad_normals += sum(not all(math.isfinite(x) for x in n) or abs(sum(x*x for x in n) - 1) > .01 for n in normals)
                bad_uvs += sum(not all(math.isfinite(x) for x in uv) for uv in uvs)
                bounds.extend(positions)
                edges = Counter()
                opposed_normals = 0
                for i in range(0, len(indices), 3):
                    a, b, c = [positions[k] for k in indices[i:i+3]]
                    u, v = [b[j]-a[j] for j in range(3)], [c[j]-a[j] for j in range(3)]
                    cross = [u[1]*v[2]-u[2]*v[1], u[2]*v[0]-u[0]*v[2], u[0]*v[1]-u[1]*v[0]]
                    degenerates += sum(x*x for x in cross) < 1e-16
                    normal = [sum(normals[k][j] for k in indices[i:i+3]) for j in range(3)]
                    opposed_normals += sum(cross[j] * normal[j] for j in range(3)) < -1e-10
                    welded = [tuple(round(x, 6) for x in p) for p in [a, b, c]]
                    for left, right in [(0, 1), (1, 2), (2, 0)]:
                        edges[tuple(sorted([welded[left], welded[right]]))] += 1
                topology.append({"material": prim["material"], "position_welded_boundary_edges": sum(n == 1 for n in edges.values()),
                                 "position_welded_nonmanifold_edges": sum(n > 2 for n in edges.values()),
                                 "faces_opposing_vertex_normals": opposed_normals})
        result["geometry"][path.name] = {"triangles": triangles, "materials": len(gltf["materials"]),
            "invalid_indices": invalid_indices, "degenerate_triangles": degenerates, "invalid_normals": bad_normals,
            "invalid_uvs": bad_uvs, "missing_attributes": attributes_missing,
            "local_position_bounds": [[min(p[j] for p in bounds) for j in range(3)], [max(p[j] for p in bounds) for j in range(3)]],
            "node_transforms": gltf["nodes"], "double_sided": [m.get("doubleSided", False) for m in gltf["materials"]],
            "topology_by_primitive": topology,
            "alpha_modes": [m.get("alphaMode", "OPAQUE") for m in gltf["materials"]], "samplers": gltf.get("samplers", []),
            "textured": ["baseColorTexture" in m.get("pbrMetallicRoughness", {}) for m in gltf["materials"]]}
    result["manifest_count_mismatches"] = []
    for variant in ready["counts"].values():
        for lod in variant["lods"].values():
            actual = result["geometry"][lod["file"]]
            if actual["triangles"] != lod["triangles"] or actual["materials"] != lod["materials"]:
                result["manifest_count_mismatches"].append(lod["file"])
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"files_checked": result["files_checked"], "hash_mismatches": result["hash_mismatches"],
        "provenance_hashes": result["provenance_hashes"], "counts": {k:v["triangles"] for k,v in result["geometry"].items()}}, indent=2))


if __name__ == "__main__":
    main()
