"""Step 010a: isolated 720p/540p/720p phone measurement using the existing exporter/recorder.

python tools/vo_phone_sweep.py export
python tools/vo_phone_sweep.py run --serial ZY22K7BD2J
Already acquires the shared lock; do not wrap in local_resource.py.
"""
import argparse
import os
from pathlib import Path
import subprocess
from look import model_lock
import vo_phone as phone

ROOT = phone.ROOT


def configure(step):
    """Evidence folder, package file and isolated on-device state per step (010a baseline, 010b after the resolve)."""
    phone.OUT = ROOT / f"build/perf/vo/{step}/phone"
    phone.APK = ROOT / f"build/android/RubyCocoon-perf-{step}.apk"
    phone.BENCH_REL = f"bench/vo/{step}"
    phone.TARGET_PASSES = 3
    phone.RUN_METADATA = {"resolution_sweep": [720, 540, 720], "quality": "mid", "passes_target": 3}
    phone.EXTRA_ARGS = "-- --scene=vo-perf --resolution_sweep=720,540,720 --passes=3 --duration=0 "         f"--render_height=720 --graphics_quality=mid --report=user://bench/vo/{step}/report.json "         f"--shots=user://bench/vo/{step}/shots --shot_w=0 --save_dir=user://bench/vo/{step}/saves/ "         f"--prefs_path=user://bench/vo/{step}/settings.cfg"


configure("010a")


def run(args):
    adb = [str(Path(args.sdk) / "platform-tools/adb.exe"), "-s", args.serial]
    phone.OUT.mkdir(parents=True, exist_ok=True)
    if (phone.OUT / "report.json").exists() and not args.attach:
        raise FileExistsError("Preserve existing evidence; use --attach only for observer recovery")
    with model_lock(timeout=3600):
        before = subprocess.run(adb + ["shell", "pm", "path", "com.rubycocoon.x"], capture_output=True, text=True, check=True).stdout
        (phone.OUT / "player-package-before.txt").write_text(before, encoding="utf-8")
        with (phone.OUT / "display-before.txt").open("w", encoding="utf-8") as file:
            phone.call(adb + ["shell", "dumpsys", "display"], stdout=file)
        try:
            phone.record(args)
        finally:
            # Stop only this tool's temporary package, restoring normal app keep-on behavior even on errors.
            subprocess.run(adb + ["shell", "am", "force-stop", phone.PACKAGE], check=False)
            after = subprocess.run(adb + ["shell", "pm", "path", "com.rubycocoon.x"], capture_output=True, text=True, check=True).stdout
            (phone.OUT / "player-package-after.txt").write_text(after, encoding="utf-8")
            if after != before:
                raise RuntimeError("Player package identity changed; inspect package snapshots")
        if args.attach:
            print("Observer recovery complete")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["export", "run"])
    parser.add_argument("--sdk", default=str(ROOT / "build/tools/android"))
    parser.add_argument("--godot", default=os.environ.get("GODOT", "C:/Program Files/Godot/Godot_v4.7-stable_win64.exe"))
    parser.add_argument("--java", default=os.environ.get("JAVA_HOME", "C:/Program Files/Eclipse Adoptium/jdk-17.0.20.101-hotspot"))
    parser.add_argument("--serial", default="ZY22K7BD2J")
    parser.add_argument("--display", default="")
    parser.add_argument("--attach", action="store_true")
    parser.add_argument("--step", choices=["010a", "010b"], default="010a")
    args = parser.parse_args()
    configure(args.step)
    if args.action == "export":
        with model_lock(timeout=3600):
            phone.export(args)
    else:
        run(args)
