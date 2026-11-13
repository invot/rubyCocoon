"""007: transparency attribution, merge zero-alpha draws and separate MSAA/FXAA trial.

All measurements share the project resource lock. Desktop Mobile is not phone evidence.
"""
import argparse
from godot_toolchain import default_godot
import json
from pathlib import Path
import subprocess
import time

from look import model_lock
import vo_phone as phone
import vo_phone_sweep as sweep
from vo_scenery import focus_trace
from vo_shadow_sweep import validate_segment

ROOT = phone.ROOT


def summarize(path):
    path = Path(path)
    data = json.loads(path.read_text(encoding="utf-8"))
    if data["benchmark"] != "alpha-007" or data["problems"] or data["focus_losses"] or len(data["passes"]) != 3:
        raise ValueError("Incomplete/interrupted alpha experiment")
    batches = data["passes"]
    names = set(batches[0]["segments"])
    field = {"coastal_path", "cove_plaza", "hero_house", "rue_royale", "coast_battle"}
    if names not in [{"merge"}, {"coastal_path", "merge"}, field, field | {"merge"}]:
        raise ValueError("Missing alpha scenes")
    settings = ["render_height", "render_size", "refresh_hz", "vsync", "max_fps", "quality"]
    rows = []
    for i, batch in enumerate(batches):
        if batch["focus_losses"] or set(batch["segments"]) != names or any(batch[k] != batches[0][k] for k in settings):
            raise ValueError("Route/settings/focus changed")
        for name, segment in batch["segments"].items():
            validate_segment(segment)
            exp = segment["alpha_experiment"]
            if exp["candidate"] != (i == 1):
                raise ValueError("Candidate control mismatch")
            if exp["part"] == "aa":
                if exp["msaa"] != (0 if i == 1 else 1) or exp["screen_aa"] != (1 if i == 1 else 0):
                    raise ValueError("Effective AA differs from request")
            elif exp["msaa"] != (0 if batch["quality"] == "min" else 1) or exp["screen_aa"] != 0:
                raise ValueError("Unexpected baseline AA")
            if name == "merge":
                if segment["frames"] != 570 or abs(segment["film_elapsed"] - 9.5) > .002:
                    raise ValueError("Merge simulation changed")
                if "fixed seed" not in segment.get("particle_playback", ""):
                    raise ValueError("Preliminary wall-clock particles; use deterministic playback for accepted timing")
                if segment["zero_alpha_candidate"] != (i == 1 and exp["part"] != "aa"):
                    raise ValueError("Merge candidate did not take effect")
            else:
                tiles = segment.get("tiles", [])
                if tiles != batches[0]["segments"][name].get("tiles", []):
                    raise ValueError("Field route changed")
                expected_frames = (len(tiles)-1)*14 if len(tiles)>1 else 240
                if segment["frames"] != expected_frames:
                    raise ValueError("Standard field/battle sample count changed")
    for name in sorted(names):
        segments = [p["segments"][name] for p in batches]
        columns = ["/".join(f"{s['summary'][k]['median']:.3f}" for s in segments)
                   for k in ["frame_ms", "gpu_ms", "tick_cpu_ms", "render_cpu_ms", "draw_calls", "primitives"]]
        rows.append("| " + name + " | " + " | ".join(columns) + " |")
    lines = [f"{data['platform']} / {data['renderer']}; control/candidate/control.",
             f"Settings: { {k:batches[0][k] for k in settings} }", "",
             "| Scene | Frame ms | GPU ms | Tick CPU ms | Render CPU ms | Draws | Primitives |",
             "|---|---|---|---|---|---|---|", *rows]
    path.with_name("alpha.md").write_text("\n".join(lines)+"\n", encoding="utf-8")
    path.with_name("validated-alpha.json").write_text(json.dumps({"valid": True, "scenes": sorted(names)}, indent=2)+"\n")
    print("\n".join(lines), flush=True)


def configure_phone(part, device_tag=""):
    sweep.configure("007-v2" + ("-aa" if part == "aa" else ""))
    if device_tag:
        if not all(c.isalnum() or c in "_-" for c in device_tag):
            raise ValueError("Use a plain device tag")
        phone.OUT = phone.OUT.with_name("phone-" + device_tag)
    phone.RUN_METADATA = {"experiment": "alpha-007 " + part, "quality": "mid", "passes_target": 3}
    phone.EXTRA_ARGS = phone.EXTRA_ARGS.replace("--scene=vo-perf", "--scene=vo-alpha --part="+part).replace("--resolution_sweep=720,540,720 ", "")


def desktop(args):
    if not args.attempt or not all(c.isalnum() or c in "_-" for c in args.attempt):
        raise ValueError("Use a new plain attempt name")
    out = ROOT / "build/perf/vo/007" / args.attempt
    out.mkdir(parents=True, exist_ok=False)
    state = f"res://build/vo_state/007/{args.attempt}"
    command = [args.godot, "--path", str(ROOT), "--rendering-method", args.renderer,
               "--resolution", "2400x1080" if args.touch else "1920x1080", "--log-file", str(out/"godot.log"), "--",
               "--scene=vo-alpha", "--part="+args.part, "--await_focus=1", "--graphics_quality=mid", "--render_height=720",
               "--report="+str(out/"report.json"), f"--shots=res://build/shots/vo/007/{args.attempt}", "--shot_w=0",
               f"--save_dir={state}/saves/", f"--prefs_path={state}/settings.cfg"]
    if args.touch:
        command.append("--touch")
    (out/"command.json").write_text(json.dumps(command, indent=2))
    with model_lock(timeout=3600), focus_trace(out), (out/"stdout.log").open("w") as log:
        print("Running 007; keep the diagnostic game focused", flush=True)
        process = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
        (out/"process.json").write_text(json.dumps({"pid":process.pid}))
        deadline = time.monotonic()+1200
        while process.poll() is None:
            time.sleep(.5)
            text = (out/"godot.log").read_text(encoding="utf-8", errors="replace") if (out/"godot.log").exists() else ""
            if "SCRIPT ERROR" in text or "Failed loading resource" in text or time.monotonic()>deadline:
                process.kill()  # Only the diagnostic child launched here.
                process.wait()
                break
    text = (out/"godot.log").read_text(encoding="utf-8")
    errors = [line for line in text.splitlines() if "SCRIPT ERROR" in line or "Failed loading resource" in line or
              ("ERROR:" in line and "resources still in use at exit" not in line)]
    if process.returncode or errors or "VO PERF DONE: 0 problem(s)" not in text:
        (out/"INVALID.txt").write_text("Not accepted timing evidence; inspect godot.log\n")
        raise RuntimeError("007 run failed: "+str(out))
    if json.loads((out/"report.json").read_text())["renderer"] != args.renderer:
        raise ValueError("Renderer fallback")
    summarize(out/"report.json")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["desktop", "export", "phone", "summary"])
    parser.add_argument("report", nargs="?")
    parser.add_argument("--part", choices=["suite", "field", "film", "aa"], default="suite")
    parser.add_argument("--attempt", default="")
    parser.add_argument("--renderer", choices=["mobile", "forward_plus", "gl_compatibility"], default="mobile")
    parser.add_argument("--touch", action="store_true")
    parser.add_argument("--godot", default=default_godot())
    parser.add_argument("--sdk", default=str(ROOT/"build/tools/android"))
    parser.add_argument("--java", default="C:/Program Files/Eclipse Adoptium/jdk-17.0.20.101-hotspot")
    parser.add_argument("--serial", default="ZY22K7BD2J")
    parser.add_argument("--display", default="")
    parser.add_argument("--attach", action="store_true")
    parser.add_argument("--device-tag", default="", help="Separate evidence folders for a different physical phone; reuse the frozen APK")
    args = parser.parse_args()
    if args.action == "desktop":
        desktop(args)
    elif args.action == "summary":
        summarize(args.report)
    else:
        configure_phone(args.part, args.device_tag)
        if args.action == "export":
            with model_lock(timeout=3600):
                phone.export(args)
        else:
            previous = ROOT / "build/perf/vo/007-v2" / ("phone-"+args.device_tag if args.device_tag else "phone") / "cleanup.json"
            if args.part == "aa" and previous.exists() and json.loads(previous.read_text()).get("recover_observer_if_still_running"):
                raise RuntimeError("Recover the preceding phone observer with --part=suite --attach before starting another package")
            sweep.run(args)
            summarize(phone.OUT/"report.json")
