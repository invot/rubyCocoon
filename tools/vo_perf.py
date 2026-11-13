"""Run the visual-overhaul desktop baseline serially, then check repeatability.

python tools/vo_perf.py
python tools/vo_perf.py --renderers mobile --tag experiment
Never run a second benchmark or a test suite concurrently with this script.
"""
import argparse
from godot_toolchain import default_godot
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import statistics
import sys

ROOT = Path(__file__).resolve().parents[1]
CONFIGS = {
    "forward": ("forward_plus", "1920x1080", False),
    "mobile": ("mobile", "1920x1080", False),
    "compat": ("gl_compatibility", "1920x1080", False),
    "mobile-touch": ("mobile", "2400x1080", True),
}
ERRORS = ("SCRIPT ERROR", "ERROR:", "Failed loading resource", "Resource file not found")


def compare(first, second):
    """Reject a different workload even if a frame cap makes its medians identical."""
    problems = []
    for key in ("schema", "route_version", "seed", "renderer", "window", "render_size", "touch",
                "quality", "render_height", "vsync", "max_fps", "simulation_dt", "frames_per_tile",
                "processor", "gpu", "driver", "engine"):
        if first[key] != second[key]:
            problems.append(f"configuration differs: {key}")
    for key in ("input_mode", "touch_controls_visible"):
        if first.get(key) != second.get(key):
            problems.append(f"configuration differs: {key}")
    if first["segments"].keys() != second["segments"].keys():
        return {}, problems + ["segment set differs"]
    rows = {}
    for name, segment in second["segments"].items():
        before = first["segments"][name]
        if before["frames"] != segment["frames"] or before.get("tiles") != segment.get("tiles"):
            problems.append(f"{name}: scripted route differs")
        a = before["summary"]["frame_ms"]["median"]
        b = segment["summary"]["frame_ms"]["median"]
        change = abs(b - a) / a * 100 if a > 0 else float("inf")
        rows[name] = {"first_median_ms": a, "second_median_ms": b, "difference_percent": change}
        if change > 5:
            problems.append(f"{name}: median differs by {change:.2f}% (limit 5%)")
    return rows, problems


def validate(data, config):
    renderer, size, touch = CONFIGS[config]
    if data["problems"] or data["renderer"] != renderer or data["window"] != [int(x) for x in size.split("x")] or data["touch"] != touch:
        raise RuntimeError(f"{config}: failed route or incorrect renderer/window/touch mode")
    if touch and (data.get("input_mode") != "screen" or not data.get("touch_controls_visible")):
        raise RuntimeError("touch controls were not visible; a connected controller may have replaced screen input")
    expected = {"coastal_path", "cove_plaza", "hero_house", "rue_royale", "coast_battle"}
    if set(data["segments"]) != expected or data["segments"]["coast_battle"]["frames"] != 240:
        raise RuntimeError("missing segment or incorrect warmed battle length")
    for name, segment in data["segments"].items():
        if segment["frames"] <= 0 or len(segment["worst_five"]) != 5:
            raise RuntimeError(f"{name}: missing samples")
        if any(len(trace) != segment["frames"] for trace in segment["trace"].values()):
            raise RuntimeError(f"{name}: incomplete trace")
        frames = segment["trace"]["frame_ms"]
        if [row["ms"] for row in segment["worst_five"]] != sorted(frames, reverse=True)[:5]:
            raise RuntimeError(f"{name}: worst-frame ranking is incorrect")
        for metric, trace in segment["trace"].items():
            ordered = sorted(trace)
            expected_stats = {"median": statistics.median(ordered), "p95": ordered[math.ceil(len(trace) * .95) - 1],
                              "p99": ordered[math.ceil(len(trace) * .99) - 1], "max": max(ordered)}
            if any(not math.isclose(segment["summary"][metric][key], value, rel_tol=1e-9, abs_tol=1e-9)
                   for key, value in expected_stats.items()):
                raise RuntimeError(f"{name}: incorrect {metric} statistics")


def run(args):
    os.chdir(ROOT)
    reports = ROOT / "build/perf/vo" / args.tag
    reports.mkdir(parents=True, exist_ok=True)
    marker = reports / "repeatability.json"
    if marker.exists():
        marker.unlink()
    evidence_key = "001" if args.tag == "baseline-desktop" else args.tag
    summary = {}
    failed = False
    for config in args.renderers:
        renderer, size, touch = CONFIGS[config]
        canonical = reports / f"{config}.json"
        if canonical.exists():
            canonical.unlink()
        runs = []
        for index in range(args.runs):
            phase = "before" if index == 0 else "after" if index == 1 else f"repeat-{index + 1}"
            folder = ROOT / "build/perf/vo" / evidence_key / phase
            folder.mkdir(parents=True, exist_ok=True)
            report = folder / f"{config}.json"
            # Prevent a stale successful report from hiding a failed launch.
            if report.exists():
                report.unlink()
            shots = f"res://build/shots/vo/{evidence_key}/{phase}/{config}"
            state = f"res://build/vo_state/{args.tag}/{config}"
            command = [args.godot, "--path", str(ROOT), "--rendering-method", renderer,
                       "--resolution", size, "--", "--scene=vo-perf", "--render_height=1080",
                       "--graphics_quality=mid", f"--report=res://{report.relative_to(ROOT).as_posix()}",
                       f"--shots={shots}", "--shot_w=0", f"--save_dir={state}/saves/",
                       f"--prefs_path={state}/settings.cfg", f"--window_title=Ruby Cocoon - perf {config} {index + 1}"]
            if touch:
                command.append("--touch")
            print(f"RUN {config} {index + 1}/{args.runs}", flush=True)
            log = folder / f"{config}.log"
            with log.open("w", encoding="utf-8") as output:
                result = subprocess.run(command, stdout=output, stderr=subprocess.STDOUT, timeout=900)
            text = log.read_text(encoding="utf-8", errors="replace")
            if result.returncode or any(error in text for error in ERRORS) or "VO PERF DONE: 0 problem(s)" not in text:
                raise RuntimeError(f"benchmark failed; inspect {log}")
            data = json.loads(report.read_text(encoding="utf-8"))
            validate(data, config)
            shutil.copy2(report, reports / f"{config}-run{index + 1}.json")
            runs.append(data)
        rows, problems = compare(runs[-2], runs[-1])
        summary[config] = {"segments": rows, "problems": problems}
        failed |= bool(problems)
        if not problems:
            shutil.copy2(reports / f"{config}-run{args.runs}.json", canonical)
        print(json.dumps({config: summary[config]}, indent=2), flush=True)
    marker.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    return int(failed)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=default_godot())
    parser.add_argument("--renderers", nargs="+", choices=CONFIGS, default=list(CONFIGS))
    parser.add_argument("--runs", type=int, default=2)
    parser.add_argument("--tag", default="baseline-desktop")
    options = parser.parse_args()
    if options.runs < 2 or not options.tag or any(c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-" for c in options.tag):
        parser.error("--runs must be at least 2; --tag must be a plain directory name")
    sys.exit(run(options))
