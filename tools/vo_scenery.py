"""006a: isolated original/restored/original LODs and 8/4/8 or 8/16/8 chunk trials.

Uses the project's shared resource lock. Desktop Mobile is not phone evidence.
python tools/vo_scenery.py desktop --part lod --renderer mobile --attempt mobile-lod-01
"""
import argparse
import json
from pathlib import Path
import subprocess
import os
import threading
import time
from contextlib import contextmanager

from look import model_lock
import vo_phone as phone
import vo_phone_sweep as sweep
from vo_shadow_sweep import validate_segment

ROOT = phone.ROOT


@contextmanager
def focus_trace(folder):
    """Process IDs only: diagnose competing game windows without recording window titles."""
    records = []
    stop = threading.Event()
    def watch():
        if os.name != "nt":
            return
        import ctypes
        from ctypes import wintypes
        user = ctypes.WinDLL("user32", use_last_error=True)
        user.GetForegroundWindow.restype = wintypes.HWND
        user.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
        previous = None
        while not stop.wait(.25):
            pid = wintypes.DWORD()
            user.GetWindowThreadProcessId(user.GetForegroundWindow(), ctypes.byref(pid))
            if pid.value != previous:
                records.append({"monotonic_s": time.monotonic(), "pid": pid.value})
                previous = pid.value
    worker = threading.Thread(target=watch, daemon=True)
    worker.start()
    try:
        yield
    finally:
        stop.set()
        worker.join()
        (folder / "foreground-pids.json").write_text(json.dumps(records, indent=2), encoding="utf-8")


def summarize(path):
    path = Path(path)
    data = json.loads(path.read_text(encoding="utf-8"))
    for name in ["godot.log", "logcat.log"]:
        log_path = path.parent / name
        if log_path.exists():
            log = log_path.read_text(encoding="utf-8", errors="replace")
            if "SCRIPT ERROR" in log or "Failed loading resource" in log:
                raise ValueError("Runtime script/resource errors in " + name)
    if data["problems"] or data["focus_losses"] or len(data["passes"]) != 3:
        raise ValueError("Incomplete/interrupted scenery experiment")
    batches = data["passes"]
    names = set(batches[0]["segments"])
    suite_names = {f"{part}_{scene}" for part in ["chunks4", "chunks16", "occlusion", "distance"] for scene in ["route1", "caccoon", "tidewater"]} | {"pads_riverbend", "isolated_creole"}
    if names not in [{"route1", "caccoon", "tidewater"}, {"tidewater"}, {"riverbend"}, {"isolated_creole"}, suite_names]:
        raise ValueError("Unexpected scenery scenes")
    settings = ["render_height", "render_size", "refresh_hz", "vsync", "max_fps", "quality"]
    for index, batch in enumerate(batches):
        if batch["focus_losses"] or set(batch["segments"]) != names:
            raise ValueError("Scenery route/focus changed")
        if any(batch[key] != batches[0][key] for key in settings):
            raise ValueError("Settings changed during experiment")
        for name, segment in batch["segments"].items():
            validate_segment(segment)
            if segment["frames"] != 240 or segment["experiment"]["candidate"] != (index == 1):
                raise ValueError("Scenery controls did not take effect")
            experiment = segment["experiment"]
            if experiment["part"] == "occlusion" and experiment["viewport_occlusion"] != (index == 1):
                raise ValueError("The actual 3D viewport's occlusion state is wrong")
            if experiment["part"] == "pads":
                margins = experiment["pad_margins"]
                if not margins or any(abs(m - (.07 if index == 1 else 0)) > 1e-6 for m in margins):
                    raise ValueError("Pad-bounds controls did not take effect")
                missing = experiment["effective_bounds"]["shader_underbound"]
                if bool(missing) != (index != 1):
                    raise ValueError("Pad shader coverage disagrees with the selected margin")
            if segment.get("tiles", []) != batches[0]["segments"][name].get("tiles", []):
                raise ValueError("Route differs between controls")
            if name != "isolated_creole" and not segment["experiment"]["bounds"]["renderer_bounds_available"]:
                raise ValueError("Headless bounds are not renderer measurements")
    rows = []
    result = {"platform": data["platform"], "renderer": data["renderer"], "scenes": {}}
    for name in sorted(names):
        segments = [p["segments"][name] for p in batches]
        summaries = [s["summary"] for s in segments]
        result["scenes"][name] = {"summaries": summaries, "experiments": [s["experiment"] for s in segments],
                                  "availability": [s["availability"] for s in segments]}
        values = ["/".join(f"{s[key]['median']:.3f}" for s in summaries) for key in ["frame_ms", "gpu_ms", "tick_cpu_ms", "render_cpu_ms", "draw_calls", "primitives"]]
        rows.append("| " + name + " | " + " | ".join(values) + " |")
    lines = ["<!-- Generated by tools/vo_scenery.py -->", "", f"{data['platform']} / {data['renderer']}, control/candidate/control.",
             f"Settings: { {key: batches[0][key] for key in settings} }", "",
             "| Scene | Frame ms | GPU ms | Tick CPU ms | Render CPU ms | Draws | Primitives |", "|---|---|---|---|---|---|---|", *rows]
    path.with_name("validated-scenery.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    path.with_name("scenery.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines), flush=True)
    return result


def desktop(args):
    if not args.attempt or any(c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-" for c in args.attempt):
        raise ValueError("Use a new plain --attempt name")
    folder = ROOT / "build/perf/vo/006" / args.attempt
    folder.mkdir(parents=True, exist_ok=False)
    state = f"res://build/vo_state/006/{args.attempt}"
    report = folder / "report.json"
    log_path = folder / "godot.log"
    command = [args.godot, "--path", str(ROOT), "--rendering-method", args.renderer,
               "--resolution", "2400x1080" if args.touch else "1920x1080", "--log-file", log_path.as_posix(), "--",
               "--scene=" + ("vo-mesh-merger" if args.part == "merger" else "vo-scenery"), f"--part={args.part}", "--graphics_quality=mid", "--render_height=1080",
               f"--report={report.as_posix()}", f"--shots=res://build/shots/vo/006/{args.attempt}", "--shot_w=0",
               f"--save_dir={state}/saves/", f"--prefs_path={state}/settings.cfg"]
    if args.touch:
        command.append("--touch")
    if args.maps:
        command.append("--maps=" + args.maps)
    (folder / "command.json").write_text(json.dumps(command, indent=2), encoding="utf-8")
    with model_lock(timeout=3600), (folder / "stdout.log").open("w", encoding="utf-8") as log:
        print("Running scenery experiment; keep the game focused", flush=True)
        with focus_trace(folder):
            process = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
            (folder / "process.json").write_text(json.dumps({"pid": process.pid}), encoding="utf-8")
            deadline = time.monotonic() + 900
            while process.poll() is None:
                time.sleep(.5)
                text = log_path.read_text(encoding="utf-8", errors="replace") if log_path.exists() else ""
                if "SCRIPT ERROR" in text or "Failed loading resource" in text or time.monotonic() > deadline:
                    process.kill()  # Only the diagnostic child launched immediately above.
                    process.wait()
                    break
            completed = process
    log = log_path.read_text(encoding="utf-8")
    errors = [line for line in log.splitlines() if "SCRIPT ERROR" in line or "Failed loading resource" in line or
              ("ERROR:" in line and "resources still in use at exit" not in line)]
    if completed.returncode or errors or "VO PERF DONE: 0 problem(s)" not in log:
        (folder / "INVALID.txt").write_text("Not accepted evidence; inspect godot.log\n", encoding="utf-8")
        raise RuntimeError("Scenery run failed: " + str(folder))
    if json.loads(report.read_text(encoding="utf-8"))["renderer"] != args.renderer:
        raise ValueError("Renderer fallback")
    summarize(report)


def configure_phone(part="lod"):
    step = {"occlusion": "006b", "distance": "006c", "pads": "006a-pads", "merger": "006d", "suite": "006-suite"}.get(part, "006a")
    sweep.configure(step)
    phone.RUN_METADATA = {"experiment": part + " control/candidate/control", "quality": "mid", "passes_target": 3}
    phone.EXTRA_ARGS = phone.EXTRA_ARGS.replace("--scene=vo-perf", "--scene=vo-scenery --part=" + part).replace("--resolution_sweep=720,540,720 ", "")
    if part == "merger":
        phone.EXTRA_ARGS = phone.EXTRA_ARGS.replace("--scene=vo-scenery", "--scene=vo-mesh-merger")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["desktop", "export", "phone", "summary"])
    parser.add_argument("report", nargs="?")
    parser.add_argument("--part", choices=["lod", "chunks4", "chunks16", "occlusion", "distance", "pads", "merger", "suite"], default="lod")
    parser.add_argument("--renderer", choices=["forward_plus", "mobile", "gl_compatibility"], default="mobile")
    parser.add_argument("--attempt", default="")
    parser.add_argument("--touch", action="store_true")
    parser.add_argument("--maps", default="")
    parser.add_argument("--godot", default="C:/Program Files/Godot/Godot_v4.7-stable_win64.exe")
    parser.add_argument("--sdk", default=str(ROOT / "build/tools/android"))
    parser.add_argument("--java", default="C:/Program Files/Eclipse Adoptium/jdk-17.0.20.101-hotspot")
    parser.add_argument("--serial", default="ZY22K7BD2J")
    parser.add_argument("--display", default="")
    parser.add_argument("--attach", action="store_true")
    args = parser.parse_args()
    if args.action == "desktop":
        desktop(args)
    elif args.action == "summary":
        summarize(args.report)
    else:
        configure_phone(args.part)
        if args.action == "export":
            with model_lock(timeout=3600):
                phone.export(args)
        else:
            sweep.run(args)
            summarize(phone.OUT / "report.json")
