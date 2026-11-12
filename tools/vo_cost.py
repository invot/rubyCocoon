"""Step 004 diagnostic runs. Serial jobs use the shared artwork/model resource lock.

python tools/vo_cost.py --renderer mobile
Does not replace the accepted 001-003 baselines or change runtime rendering.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
from look import model_lock

ROOT = Path(__file__).resolve().parents[1]


def run(renderer, build=False, eligibility=False, phases=False, attempt=""):
    step = "009a" if phases else "004"
    if attempt:
        if any(c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-" for c in attempt):
            raise ValueError("attempt must be a plain directory name")
        step += "/" + attempt
    folder = ROOT / f"build/perf/vo/{step}"
    folder.mkdir(parents=True, exist_ok=True)
    tag = "build-profile-verified" if build else ("material-eligibility" if eligibility else f"{renderer}-cost")
    report = folder / f"{tag}.json"
    if report.exists():
        raise FileExistsError(f"Preserve existing evidence: {report}")
    state = f"res://build/vo_state/{step}/{renderer}"
    cmd = [os.environ.get("GODOT", "C:/Program Files/Godot/Godot_v4.7-stable_win64.exe"),
           "--path", str(ROOT), "--rendering-method", renderer, "--resolution", "1920x1080", "--",
           "--scene=vo-perf", "--diagnose=1", "--render_height=1080", "--graphics_quality=mid",
           f"--report=res://build/perf/vo/{step}/{tag}.json",
           f"--save_dir={state}/saves/", f"--prefs_path={state}/settings.cfg"]
    if build:
        cmd = [cmd[0], "--headless", "--path", str(ROOT), "--", "--scene=build-profile",
               "--maps=route1,caccoon,caccoon#1,tidewater", "--diagnose=1",
               f"--report=res://build/perf/vo/{step}/{tag}.json",
               f"--save_dir={state}/saves/", f"--prefs_path={state}/settings.cfg"]
    if eligibility:
        cmd.append("--eligibility=1")
    if phases:
        cmd.extend(["--load_phases=1", "--passes=2"])
    print("Waiting for shared resource lock:", renderer, flush=True)
    with model_lock(timeout=3600), (folder / f"{tag}.log").open("w", encoding="utf-8") as log:
        print("Running", renderer, flush=True)
        result = subprocess.run(cmd, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=900)
    text = (folder / f"{tag}.log").read_text(encoding="utf-8")
    if result.returncode or any(e in text for e in ["SCRIPT ERROR", "ERROR:", "Failed loading resource"]):
        raise RuntimeError(f"Inspect {tag}.log")
    data = json.loads(report.read_text())
    if build:
        if set(data) != {"route1", "caccoon", "caccoon#1", "tidewater"} or "BUILD PROFILE DONE" not in text:
            raise RuntimeError("Incomplete build diagnostic")
    elif data["problems"] or len(data["segments"]) != 5:
        raise RuntimeError("Incomplete diagnostic route")
    print("DONE", renderer, flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--renderer", choices=["forward_plus", "mobile", "gl_compatibility"], default="mobile")
    parser.add_argument("--build", action="store_true")
    parser.add_argument("--eligibility", action="store_true")
    parser.add_argument("--phases", action="store_true")
    parser.add_argument("--attempt", default="", help="new evidence directory; never overwrites an earlier report")
    args = parser.parse_args()
    if sum([args.build, args.eligibility, args.phases]) > 1:
        parser.error("choose --build, --eligibility or --phases")
    run(args.renderer, args.build, args.eligibility, args.phases, args.attempt)
