"""Prepare the supplied tropical hut for import_tribal_hut.gd; leave the ZIP untouched."""
from pathlib import Path
from zipfile import ZipFile
import json
import sys


def prepare(archive: Path) -> None:
    out_dir = Path(__file__).resolve().parents[1] / "build" / "hut_source"
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / ".gdignore").touch()
    with ZipFile(archive) as source:
        # model_0 omits one roof sector; model_1 and model_2 contain the complete roof.
        for name in ("Color.png", "Alpha.png", "model_1.obj"):
            (out_dir / name).write_bytes(source.read("collection/" + name))
    lines = (out_dir / "model_1.obj").read_text().splitlines()
    vertices = [list(map(float, line.split()[1:4])) for line in lines if line.startswith("v ")]
    uvs = [list(map(float, line.split()[1:3])) for line in lines if line.startswith("vt ")]
    normals = [list(map(float, line.split()[1:4])) for line in lines if line.startswith("vn ")]
    faces = [
        [[int(index) - 1 if index else -1 for index in corner.split("/")] for corner in line.split()[1:]]
        for line in lines if line.startswith("f ")
    ]
    data = {"v": [], "uv": [], "n": [], "roof": []}
    for face in faces:
        points = [vertices[corner[0]] for corner in face]
        # Replace the source fabric panel, including its painted lintel, with a sealed wood door.
        if (max(p[2] for p in points) - min(p[2] for p in points) < 0.01
                and abs(points[0][2] - 196.27645) < 0.1
                and max(abs(p[0] + 0.6173) for p in points) < 40):
            continue
        a, b, c = points
        cross = [
            (b[1]-a[1])*(c[2]-a[2]) - (b[2]-a[2])*(c[1]-a[1]),
            (b[2]-a[2])*(c[0]-a[0]) - (b[0]-a[0])*(c[2]-a[2]),
            (b[0]-a[0])*(c[1]-a[1]) - (b[1]-a[1])*(c[0]-a[0]),
        ]
        if sum(component * component for component in cross) < 1e-8:
            continue
        roof = max(p[1] for p in points) > 110 or (
            min(p[1] for p in points) > 33
            and max((p[0]*p[0] + p[2]*p[2])**0.5 for p in points) > 225
        )
        for corner in face:
            data["v"].append(vertices[corner[0]])
            data["uv"].append(uvs[corner[1]])
            data["n"].append(normals[corner[2]])
        data["roof"].append(roof)
    (out_dir / "mesh.json").write_text(json.dumps(data))
    print(f"Prepared {len(data['roof'])} triangles ({sum(data['roof'])} roof triangles)")


if __name__ == "__main__":
    prepare(Path(sys.argv[1]))
