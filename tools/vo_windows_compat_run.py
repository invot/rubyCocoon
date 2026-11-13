"""Validate the actual exported Compatibility profile with isolated benchmark state."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
from look import model_lock

ROOT = Path(__file__).resolve().parents[1]


def run(tag, precompile=False):
    if not re.fullmatch(r"[A-Za-z0-9_-]+", tag):
        raise ValueError("Expected a plain attempt name")
    relative = f"bench/vo/009b/{tag}"
    source = Path(os.environ["APPDATA"]) / "Godot/app_userdata/Ruby Cocoon" / relative
    folder = ROOT / "build/perf/vo/009b" / tag
    if (source / "report.json").exists() or (folder / "gl_compatibility-cost.json").exists():
        raise FileExistsError("Preserve existing evidence; choose a new --attempt")
    folder.mkdir(parents=True, exist_ok=True)
    cmd = [str(ROOT / "build/windows-compat-bench/RubyCocoon.exe"), "--resolution", "1920x1080", "--",
           "--scene=vo-perf", "--diagnose=1", "--load_phases=1", "--load_only=1", "--title_ready=1", "--passes=2",
           "--render_height=1080", "--graphics_quality=mid", f"--report=user://{relative}/report.json",
           f"--shots=user://{relative}/shots", "--shot_w=0", f"--save_dir=user://{relative}/saves/",
           f"--prefs_path=user://{relative}/settings.cfg"] + (["--precompile=1"] if precompile else [])
    with model_lock(timeout=3600), (folder / "gl_compatibility-cost.log").open("w", encoding="utf-8") as log:
        result = subprocess.run(cmd, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=300)
    if (source / "report.json").exists():
        shutil.copy2(source / "report.json", folder / "gl_compatibility-cost.json")
    if (source / "shots").exists():
        shutil.copytree(source / "shots", ROOT / "build/shots/vo/009b" / tag / "gl_compatibility")
    text = (folder / "gl_compatibility-cost.log").read_text()
    if result.returncode or any(e in text for e in ["SCRIPT ERROR", "ERROR:", "Failed loading resource"]):
        raise RuntimeError("Exported benchmark failed; inspect retained log/report")
    data = json.loads((folder / "gl_compatibility-cost.json").read_text())
    assert data["renderer"] == "gl_compatibility" and data["driver"] == "opengl3"
    assert data["shader_cache_enabled"] is False and data["title_script_ready"] is True
    assert data["problems"] == 0 and not data["focus_losses"] and len(data["passes"]) == 2
    if precompile:
        assert data["title_precompile"].get("drawn"), "title precompile did not run"
        print("Title precompile:", data["title_precompile"])
    print("Export profile verified; title-script wait ms:", data["title_script_wait_ms"])
    print([(i+1,t["map"],round(t["continuous_black_ms"],1)) for i,p in enumerate(data["passes"]) for t in p["transitions"]])


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--attempt", default="exported-compat-title-ready")
    parser.add_argument("--precompile", action="store_true", help="009b: title shader precompile before the route")
    args = parser.parse_args()
    run(args.attempt, args.precompile)
