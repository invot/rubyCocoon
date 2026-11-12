"""Prepare the supplied Small Barn for import_kennel_barn.gd; leave the ZIP untouched.

    python tools/prepare_kennel_barn.py "path/to/Small Barn.zip"
"""
from pathlib import Path
from zipfile import ZipFile
import sys


def prepare(archive: Path) -> None:
    out_dir = Path(__file__).resolve().parents[1] / "build" / "kennel_barn_source"
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / ".gdignore").touch()
    with ZipFile(archive) as source:
        # Only the mesh and its baked colour atlas are used; the roughness, metallic and emissive maps are not.
        for name in ("model_0.obj", "phong1_albedo.png"):
            (out_dir / name).write_bytes(source.read("collection/" + name))
    print("Prepared", out_dir)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    prepare(Path(sys.argv[1]))
