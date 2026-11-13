"""Resolve templates from the selected editor, pinned to the tested Godot 4.8 beta 3 toolchain."""
from dataclasses import dataclass
from functools import lru_cache
import os
from pathlib import Path
import re
import subprocess

DEFAULT_GODOT = "C:/Program Files/Godot/Godot_v4.8-beta3_win64.exe"
ROOT = Path(__file__).resolve().parents[1]


def default_godot():
    if "GODOT" in os.environ:
        return os.environ["GODOT"]
    if os.name != "nt":
        return "godot"
    editor = Path(DEFAULT_GODOT)
    release = editor.stem.removeprefix("Godot_v").removesuffix("_win64")
    portable = ROOT / "build/tools" / ("godot-" + release) / editor.name
    return str(portable) if portable.is_file() else DEFAULT_GODOT


def editor_binary(godot):
    """Windows console launchers need their sibling; copy the full editor for portable runs."""
    path = Path(godot).resolve()
    if path.name.endswith("_console.exe"):
        path = path.with_name(path.name.removesuffix("_console.exe") + ".exe")
    if not path.is_file():
        raise FileNotFoundError(f"Missing editor binary: {path}")
    return path


@dataclass(frozen=True)
class EngineVersion:
    full: str
    minor: str
    templates: str
    release: str


def parse_version(output):
    value = output.strip()
    match = re.fullmatch(r"(\d+\.\d+(?:\.\d+)?)\.(stable|beta\d+|rc\d+|dev\d+)\.[\w.]+", value)
    if not match:
        raise ValueError(f"Unrecognized Godot version: {value!r}")
    version, status = match.groups()
    return EngineVersion(value, ".".join(version.split(".")[:2]),
                         f"{version}.{status}", f"{version}-{status}")


@lru_cache(maxsize=8)
def engine_version(godot):
    result = subprocess.run([str(godot), "--version"], check=True, capture_output=True,
                            text=True, timeout=20)
    return parse_version(result.stdout)


def template_path(godot, filename):
    """Never fall back to another editor version's custom template."""
    version = engine_version(godot)
    candidates = [ROOT / "build/tools/godot-windows-templates" / version.templates / filename]
    if os.environ.get("APPDATA"):
        candidates.append(Path(os.environ["APPDATA"]) / "Godot/export_templates" / version.templates / filename)
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    raise FileNotFoundError(f"Missing {version.templates} template {filename}; checked: " +
                            ", ".join(map(str, candidates)))


if __name__ == "__main__":
    print(default_godot())
