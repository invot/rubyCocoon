"""Step 008 controlled shadow diagnostic; never changes production presets.

python tools/vo_shadow_sweep.py desktop --renderer mobile --attempt desktop-mobile-01
python tools/vo_shadow_sweep.py export
python tools/vo_shadow_sweep.py phone --serial ZY22K7BD2J
python tools/vo_shadow_sweep.py summary build/perf/vo/008/phone/report.json
All measured runs/export acquire the shared resource lock. Do not wrap them again.
"""
import argparse
import json
import math
import os
from pathlib import Path
import re
import statistics
import subprocess

from look import model_lock
import vo_phone as phone
import vo_phone_sweep as sweep

ROOT = phone.ROOT
SCENES = {"coastal_path", "cove_plaza", "hero_house", "rue_royale", "coast_battle"}


def light_configuration(entries, shadows=False):
    # Godot's unnamed-node IDs increase when the same room is rebuilt on later passes.
    normalized = []
    for light in entries:
        item = {k: v for k, v in light.items() if shadows or k != "shadows"}
        item["path"] = re.sub(r"@\d+(?=/|$)", "@AUTO", item["path"])
        normalized.append(json.dumps(item, sort_keys=True))
    return sorted(normalized)


def summarize(path):
    path = Path(path)
    data = json.loads(path.read_text(encoding="utf-8"))
    if data["problems"] or data["focus_losses"]:
        raise ValueError("Interrupted/failed shadow sweep is not measurement evidence")
    batches = data["passes"]
    if len(batches) != 3 or [p["shadows"] for p in batches] != [True, False, True]:
        raise ValueError("Expected exactly three shadow passes: on, off, on")
    settings = ["render_height", "render_size", "refresh_hz", "vsync", "max_fps", "quality"]
    for batch in batches:
        if batch["focus_losses"] or set(batch["segments"]) != SCENES:
            raise ValueError("Missing scenes or focus loss")
        if any(batch[key] != batches[0][key] for key in settings) or batch["quality"] != "mid":
            raise ValueError("Resolution, pacing or quality changed during shadow sweep")
        for scene, segment in batch["segments"].items():
            first = batches[0]["segments"][scene]
            lights = segment["diagnosis"]["lights"]
            if not batch["shadows"] and any(light["shadows"] for light in lights):
                raise ValueError("A light retained shadows during the off pass")
            if light_configuration(lights) != light_configuration(first["diagnosis"]["lights"]):
                raise ValueError("Light configuration changed during sweep")
            if batch["shadows"] and light_configuration(lights, True) != light_configuration(first["diagnosis"]["lights"], True):
                raise ValueError("Shadow flags did not restore")
            if segment["frames"] != first["frames"] or segment.get("tiles") != first.get("tiles"):
                raise ValueError("Route differs between shadow passes")
            for metric, trace in segment["trace"].items():
                if not trace or len(trace) != segment["frames"] or not all(math.isfinite(v) for v in trace):
                    raise ValueError("Missing or nonfinite trace: " + metric)
                ordered = sorted(trace)
                stats = {"median": statistics.median(trace), "p95": ordered[math.ceil(len(trace)*.95)-1],
                         "p99": ordered[math.ceil(len(trace)*.99)-1], "max": ordered[-1]}
                if not all(math.isclose(segment["summary"][metric][k], v, rel_tol=1e-9, abs_tol=1e-9)
                           for k, v in stats.items()):
                    raise ValueError("Summary does not match raw trace: " + metric)
    if not any(light["shadows"] for segment in batches[0]["segments"].values() for light in segment["diagnosis"]["lights"]):
        raise ValueError("Control pass has no shadow lights")
    result = {"source": str(path), "platform": data["platform"], "renderer": data["renderer"],
              "settings": {k: batches[0][k] for k in settings}, "scenes": {}}
    if data["platform"] == "Android":
        if data["renderer"] != "mobile" or not data["touch_controls_visible"] or not data["screen_keep_on"]:
            raise ValueError("Unexpected phone renderer, controls or keep-on state")
        if batches[0]["max_fps"] != 60 or batches[0]["render_height"] != 720:
            raise ValueError("Unexpected phone resolution/cap")
        folder = path.parent
        if (folder / "player-package-before.txt").read_bytes() != (folder / "player-package-after.txt").read_bytes():
            raise ValueError("Player package changed")
        log = (folder / "logcat.log").read_text(encoding="utf-8", errors="replace")
        if "SCRIPT ERROR" in log or re.search(r"E godot\s*: ERROR:", log):
            raise ValueError("Godot error in phone log")
        temperatures = json.loads((folder / "temperatures.json").read_text(encoding="utf-8"))
        readings = [t["temperature_c"] for t in temperatures if t["temperature_c"] is not None]
        result["temperatures"] = {"min_c": min(readings) if readings else None,
                                  "max_c": max(readings) if readings else None,
                                  "largest_gap_s": max((b["elapsed_s"] - a["elapsed_s"] for a, b in zip(temperatures, temperatures[1:])), default=0)}
    lines = ["<!-- Generated by tools/vo_shadow_sweep.py -->", "",
             f"{data['platform']} / {data['renderer']}. Bracketed on/off/on diagnostic; GPU delta includes all effects of disabling light shadows, not an isolated GPU-pass timer.", "",
             "Desktop Mobile-renderer results are desktop measurements. Zero GPU counters mean unavailable. Large bracket drift limits causal interpretation.", "",
             "| Scene | On GPU ms | Off GPU ms | Return on GPU ms | Mean on minus off ms | On GPU drift | Frame ms (on/off/on) |",
             "|---|---:|---:|---:|---:|---:|---|"]
    for scene in sorted(SCENES):
        metrics = [{k: v["median"] for k, v in p["segments"][scene]["summary"].items()} for p in batches]
        gpu = [m["gpu_ms"] for m in metrics]
        available = all(p["segments"][scene]["availability"]["gpu_timing"] for p in batches) and min(gpu) > 0
        delta = (gpu[0] + gpu[2]) / 2 - gpu[1] if available else None
        drift = (gpu[2] / gpu[0] - 1) * 100 if available else None
        result["scenes"][scene] = {"medians": metrics, "gpu_delta_ms": delta, "gpu_bracket_drift_percent": drift,
                                   "lights": batches[0]["segments"][scene]["diagnosis"]["lights"]}
        cells = [f"{v:.3f}" for v in gpu]
        lines.append(f"| {scene} | " + " | ".join(cells) + " | " +
                     (f"{delta:.3f} | {drift:+.1f}%" if available else "unavailable | unavailable") +
                     " | " + "/".join(f"{m['frame_ms']:.2f}" for m in metrics) + " |")
    path.with_name("validated-shadows.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    path.with_name("shadows.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines))
    return result


def configure_phone():
    sweep.configure("008")
    phone.RUN_METADATA = {"shadow_sweep": [True, False, True], "render_height": 720, "quality": "mid", "passes_target": 3}
    phone.EXTRA_ARGS = phone.EXTRA_ARGS.replace("--resolution_sweep=720,540,720", "--shadow_sweep=on,off,on")


def desktop(args):
    if not args.attempt or any(c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-" for c in args.attempt):
        raise ValueError("Use a new plain --attempt directory name")
    folder = ROOT / "build/perf/vo/008" / args.attempt
    if folder.exists():
        raise FileExistsError("Preserve previous attempts: " + str(folder))
    folder.mkdir(parents=True)
    state = f"res://build/vo_state/008/{args.attempt}"
    report = folder / "report.json"
    command = [args.godot, "--path", str(ROOT), "--rendering-method", args.renderer, "--resolution", "1920x1080", "--",
               "--scene=vo-perf", "--shadow_sweep=on,off,on", "--duration=0", "--graphics_quality=mid", "--render_height=720",
               f"--report={report.as_posix()}", f"--shots=res://build/shots/vo/008/{args.attempt}", "--shot_w=0",
               f"--save_dir={state}/saves/", f"--prefs_path={state}/settings.cfg"]
    (folder / "command.json").write_text(json.dumps(command, indent=2), encoding="utf-8")
    with model_lock(timeout=3600), (folder / "run.log").open("w", encoding="utf-8") as log:
        print("Running controlled desktop shadow sweep", flush=True)
        completed = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=900)
    text = (folder / "run.log").read_text(encoding="utf-8")
    if completed.returncode or any(s in text for s in ["SCRIPT ERROR", "ERROR:", "Failed loading resource"]) or "VO PERF DONE: 0 problem(s)" not in text:
        (folder / "INVALID.txt").write_text("Run failed; inspect run.log. Do not use as accepted evidence.\n", encoding="utf-8")
        raise RuntimeError("Shadow measurement failed; inspect " + str(folder))
    data = json.loads(report.read_text(encoding="utf-8"))
    if data["renderer"] != args.renderer or data["platform"] != "Windows":
        raise ValueError("Unexpected renderer/platform")
    summarize(report)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["desktop", "export", "phone", "summary"])
    parser.add_argument("report", nargs="?")
    parser.add_argument("--attempt", default="")
    parser.add_argument("--renderer", choices=["mobile", "forward_plus", "gl_compatibility"], default="mobile")
    parser.add_argument("--godot", default=os.environ.get("GODOT", "C:/Program Files/Godot/Godot_v4.7-stable_win64.exe"))
    parser.add_argument("--sdk", default=str(ROOT / "build/tools/android"))
    parser.add_argument("--java", default=os.environ.get("JAVA_HOME", "C:/Program Files/Eclipse Adoptium/jdk-17.0.20.101-hotspot"))
    parser.add_argument("--serial", default="ZY22K7BD2J")
    parser.add_argument("--display", default="")
    parser.add_argument("--attach", action="store_true")
    args = parser.parse_args()
    if args.action == "summary":
        if not args.report:
            parser.error("summary needs a report path")
        summarize(args.report)
    elif args.action == "desktop":
        desktop(args)
    else:
        configure_phone()
        if args.action == "export":
            with model_lock(timeout=3600):
                phone.export(args)
        else:
            sweep.run(args)
            summarize(phone.OUT / "report.json")
