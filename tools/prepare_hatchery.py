"""Extract the user-supplied hatchery sources without modifying their original archives.

Usage: python tools/prepare_hatchery.py "path/to/downloads"
Then run tools/import_hatchery.gd, tools/smooth_textures.gd -- --only=res://assets/interiors/hatch_, and --import.
"""
from pathlib import Path
import argparse
import zipfile

PACKS = {
    "core": "TCM Core (Virlance).zip",
    "platform": "Sci-Fi Platforms.zip",
    "room": "War Doctor's TARDIS Interior (Old).zip",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("downloads", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    for group, name in PACKS.items():
        target = root / "psx" / "hatchery" / group
        target.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(args.downloads / name) as pack:
            for entry in pack.infolist():
                filename = Path(entry.filename).name
                if not entry.is_dir() and filename.endswith((".obj", ".png")):
                    (target / filename).write_bytes(pack.read(entry))
        print(f"Prepared {group}: {target}")


if __name__ == "__main__":
    main()
