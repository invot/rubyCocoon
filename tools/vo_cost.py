"""Step 004 diagnostic runs. Serial jobs use the shared artwork/model resource lock.

python tools/vo_cost.py --renderer mobile
Does not replace the accepted 001-003 baselines or change runtime rendering.
"""
import argparse
from contextlib import contextmanager
import json
import os
from pathlib import Path
import subprocess
from look import model_lock

ROOT = Path(__file__).resolve().parents[1]


@contextmanager
def cache_override(enabled, folder):
    if enabled is None:
        yield
        return
    path = ROOT / "override.cfg"
    if path.exists():
        raise RuntimeError("Existing override.cfg preserved; cannot apply temporary cache experiment")
    content = ("[rendering]\nshader_compiler/shader_cache/enabled=" + ("true" if enabled else "false") + "\n").encode()
    (folder / "requested-cache-override.cfg").write_bytes(content)
    with path.open("xb") as file:
        file.write(content)
    try:
        yield
    finally:
        if path.exists() and path.read_bytes() == content:
            path.unlink()
        else:
            raise RuntimeError("Temporary override.cfg changed externally; preserved for inspection")


def run(renderer, build=False, eligibility=False, phases=False, attempt="", step_override="", shots=False, load_only=False, shader_cache=None, driver="", warmup_shared=False, precompile=False, title_ready=False):
    step = step_override or ("009a" if phases else "004")
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
    if shots:
        cmd.extend([f"--shots=res://build/shots/vo/{step}/{renderer}", "--shot_w=0"])
    if load_only:
        cmd.append("--load_only=1")
    if warmup_shared:
        cmd.append("--warmup_shared=1")
    if title_ready and not precompile:
        cmd.append("--title_ready=1")
    if precompile:
        # the title's script loading first, then its shader precompile, as the title menu runs them
        cmd.extend(["--title_ready=1", "--precompile=1"])
    if driver:
        cmd[1:1] = ["--rendering-driver", driver]
    print("Waiting for shared resource lock:", renderer, flush=True)
    with model_lock(timeout=3600), cache_override(shader_cache, folder), (folder / f"{tag}.log").open("w", encoding="utf-8") as log:
        print("Running", renderer, flush=True)
        result = subprocess.run(cmd, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=900)
    text = (folder / f"{tag}.log").read_text(encoding="utf-8")
    if result.returncode or any(e in text for e in ["SCRIPT ERROR", "ERROR:", "Failed loading resource"]):
        raise RuntimeError(f"Inspect {tag}.log")
    data = json.loads(report.read_text())
    if build:
        if set(data) != {"route1", "caccoon", "caccoon#1", "tidewater"} or "BUILD PROFILE DONE" not in text:
            raise RuntimeError("Incomplete build diagnostic")
    elif data["problems"] or len(data["segments"]) != (0 if load_only else 5):
        raise RuntimeError("Incomplete diagnostic route")
    if shader_cache is not None and data["shader_cache_enabled"] != shader_cache:
        raise RuntimeError("Cache override did not take effect; report rejected")
    if precompile and not (data.get("title_precompile") or {}).get("drawn"):
        raise RuntimeError("Title precompile did not run; report rejected")
    if warmup_shared and not data.get("warmup_shared"):
        raise RuntimeError("Shared warm-up option did not take effect; report rejected")
    if driver and data["driver"] != driver:
        raise RuntimeError("Requested driver was not active; report rejected")
    print("DONE", renderer, flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--renderer", choices=["forward_plus", "mobile", "gl_compatibility"], default="mobile")
    parser.add_argument("--build", action="store_true")
    parser.add_argument("--eligibility", action="store_true")
    parser.add_argument("--phases", action="store_true")
    parser.add_argument("--attempt", default="", help="new evidence directory; never overwrites an earlier report")
    parser.add_argument("--step", choices=["009a", "009b"], default="")
    parser.add_argument("--shots", action="store_true")
    parser.add_argument("--load-only", action="store_true")
    parser.add_argument("--shader-cache", choices=["on", "off"], default=None)
    parser.add_argument("--driver", choices=["opengl3", "opengl3_angle"], default="")
    parser.add_argument("--warmup-shared", action="store_true", help="opt-in 009b exact-material/geometry-format warm-up")
    parser.add_argument("--precompile", action="store_true", help="009b: title script wait plus title shader precompile")
    parser.add_argument("--title-ready", action="store_true", help="009b: title script wait only (control for --precompile)")
    args = parser.parse_args()
    if sum([args.build, args.eligibility, args.phases]) > 1:
        parser.error("choose --build, --eligibility or --phases")
    if args.step and not args.phases:
        parser.error("--step requires --phases")
    if (args.load_only or args.shader_cache is not None) and not args.phases:
        parser.error("loading/cache experiments require --phases")
    cache = None if args.shader_cache is None else args.shader_cache == "on"
    if args.warmup_shared and not args.phases:
        parser.error("--warmup-shared requires --phases")
    run(args.renderer, args.build, args.eligibility, args.phases, args.attempt, args.step, args.shots, args.load_only, cache,
        args.driver, args.warmup_shared, args.precompile, args.title_ready)
