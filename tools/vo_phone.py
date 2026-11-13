"""Isolated Android performance export and recording. Never replaces the player's app.

python tools/vo_phone.py export
python tools/vo_phone.py run --serial <adb serial> --display <SurfaceFlinger display ID>
The workspace-local SDK needs platform-tools, build-tools 35.0.1 and platform android-35.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = "com.rubycocoon.vo_perf"
OUT = ROOT / "build/perf/vo/baseline-phone"
APK = ROOT / "build/android/RubyCocoon-perf.apk"
BENCH_REL = "bench/vo/002"
TARGET_PASSES = 0
RUN_METADATA = {"render_height": 720, "quality": "mid", "duration_target_s": 900}
EXTRA_ARGS = "-- --scene=vo-perf --duration=900 --render_height=720 --graphics_quality=mid " \
    "--report=user://bench/vo/002/report.json --shots=user://bench/vo/002/shots --shot_w=0 " \
    "--save_dir=user://bench/vo/002/saves/ --prefs_path=user://bench/vo/002/settings.cfg"


def call(command, **kwargs):
    return subprocess.run(command, cwd=ROOT, check=True, **kwargs)


def export(args):
    (ROOT / "build/tools").mkdir(parents=True, exist_ok=True)
    (ROOT / "build/tools/.gdignore").touch()
    (ROOT / "build/shots").mkdir(parents=True, exist_ok=True)
    (ROOT / "build/shots/.gdignore").touch()
    engine = ROOT / "build/tools/godot-perf/godot.exe"
    engine.parent.mkdir(parents=True, exist_ok=True)
    if not engine.exists() or engine.stat().st_mtime != Path(args.godot).stat().st_mtime:
        shutil.copy2(args.godot, engine)
    (engine.parent / "_sc_").touch()
    editor = engine.parent / "editor_data"
    editor.mkdir(exist_ok=True)
    roaming = Path(os.environ["APPDATA"]) / "Godot"
    template = roaming / "export_templates/4.7.stable/android_debug.apk"
    keystore = roaming / "keystores/debug.keystore"
    settings = {"export/android/android_sdk_path": str(Path(args.sdk).resolve()).replace("\\", "/"),
                "export/android/java_sdk_path": args.java.replace("\\", "/"),
                "export/android/debug_keystore": str(keystore).replace("\\", "/"),
                "export/android/debug_keystore_user": "androiddebugkey",
                "export/android/debug_keystore_pass": "android"}
    (editor / "editor_settings-4.7.tres").write_text(
        '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n' +
        '\n'.join(f'{key} = {json.dumps(value)}' for key, value in settings.items()) + '\n', encoding="utf-8")
    path = ROOT / "export_presets.cfg"
    original = path.read_bytes()
    source = original.decode("utf-8")
    first = re.search(r'\[preset\.0\][\s\S]*?(?=\[preset\.1\]|\Z)', source).group()
    index = max(int(value) for value in re.findall(r'\[preset\.(\d+)\]', source)) + 1
    clone = first.replace("[preset.0", f"[preset.{index}")
    excluded = json.loads(re.search(r'^exclude_filter=(.*)$', clone, re.M)[1])
    overrides = {
        "name": "Android Perf", "export_path": str(APK).replace("\\", "/"),
        "exclude_filter": ", ".join(value.strip() for value in excluded.split(",") if value.strip() != "tools/*"), "custom_template/debug": str(template).replace("\\", "/"),
        "package/unique_name": PACKAGE, "package/name": "Ruby Cocoon Perf",
        "command_line/extra_args": EXTRA_ARGS,
    }
    # Only the top-level name is overridden; version/name and package/name are separate options.
    for key, value in overrides.items():
        clone, count = re.subn(r'^' + re.escape(key) + r'=.*$', lambda _: key + '=' + json.dumps(value), clone, flags=re.M)
        if count != 1:
            raise RuntimeError(f"Expected one preset option {key}, found {count}")
    OUT.mkdir(parents=True, exist_ok=True)
    APK.parent.mkdir(parents=True, exist_ok=True)
    (OUT / "export-presets-original.cfg").write_bytes(original)
    (OUT / "export-preset-perf.cfg").write_text(clone, encoding="utf-8")
    path.write_bytes(original + b"\n" + clone.encode("utf-8"))
    try:
        with (OUT / "export.log").open("w", encoding="utf-8") as log:
            call([str(engine), "--headless", "--path", str(ROOT), "--export-debug", "Android Perf", str(APK)], stdout=log, stderr=subprocess.STDOUT)
    finally:
        path.write_bytes(original)
    print(f"APK {APK} ({APK.stat().st_size} bytes)", flush=True)
    print("SHA256 " + hashlib.sha256(APK.read_bytes()).hexdigest(), flush=True)


def record(args):
    adb = [str(Path(args.sdk) / "platform-tools/adb.exe"), "-s", args.serial]
    OUT.mkdir(parents=True, exist_ok=True)
    previous = []
    for pattern in ("device-*.png", "battery-*.txt", "temperatures.json", "report.json", "logcat.log"):
        previous.extend(OUT.glob(pattern))
    if previous and not args.attach:
        archive = OUT / ("attempt-before-" + time.strftime("%Y%m%d-%H%M%S"))
        archive.mkdir()
        for path in previous:
            assert path.parent.resolve() == OUT.resolve()
            shutil.copy2(path, archive / path.name)
            path.unlink()
    def read(*command):
        return call(adb + list(command), capture_output=True, text=True, encoding="utf-8", errors="replace").stdout
    metadata = {"package": PACKAGE, **RUN_METADATA,
                "model": read("shell", "getprop", "ro.product.model").strip(),
                "android": read("shell", "getprop", "ro.build.version.release").strip(),
                "soc": read("shell", "getprop", "ro.soc.model").strip(),
                "physical_size": read("shell", "wm", "size").strip()}
    (OUT / "device.json").write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    if not args.attach:
        call(adb + ["install", "-r", str(APK)])
        # This package is created exclusively by this tool; cold UI/cache behavior is part of the baseline.
        call(adb + ["shell", "pm", "clear", PACKAGE])
        print("PHONE APK installed; checking for an unlocked, awake screen", flush=True)
        for _ in range(180):
            policy = read("shell", "dumpsys", "window", "policy")
            if re.search(r'^\s*showing=false\s*$', policy, re.M) and "interactiveState=INTERACTIVE_STATE_AWAKE" in policy:
                break
            time.sleep(1)
        else:
            raise RuntimeError("Phone is locked; unlock it before starting the benchmark")
        activity = read("shell", "cmd", "package", "resolve-activity", "--brief", PACKAGE).strip().splitlines()[-1]
        if "/" not in activity:
            raise RuntimeError("Benchmark has no launch activity: " + activity)
        # Launch is deliberately separate from export so the user can unlock immediately beforehand.
        call(adb + ["shell", "am", "force-stop", PACKAGE])
        call(adb + ["shell", "run-as", PACKAGE, "rm", "-f", f"files/{BENCH_REL}/report.json"])
        call(adb + ["shell", "am", "start", "-n", activity])
        began = time.monotonic()
    else:
        saved = OUT / "temperatures.json"
        prior = json.loads(saved.read_text(encoding="utf-8"))
        elapsed = prior[-1]["elapsed_s"] + time.time() - saved.stat().st_mtime
        began = time.monotonic() - elapsed
        print(f"PHONE attaching to running benchmark at about {elapsed:.0f}s", flush=True)
        # The app may have completed and exited while USB observation was unavailable.
        # Recover its private checkpoint before requiring a live PID; never relaunch/clear it.
        completed_probe = subprocess.run(adb + ["shell", "run-as", PACKAGE, "cat", f"files/{BENCH_REL}/report.json"], capture_output=True)
        try:
            completed_data = json.loads(completed_probe.stdout) if completed_probe.returncode == 0 else {}
        except (json.JSONDecodeError, UnicodeDecodeError):
            completed_data = {}
        completed_passes = completed_data.get("passes", [])
        enough = (len(completed_passes) >= TARGET_PASSES if TARGET_PASSES else
                  bool(completed_passes) and completed_passes[-1].get("elapsed_s", 0) >= 900)
        if enough:
            (OUT / "report.json").write_bytes(completed_probe.stdout)
            if completed_data.get("problems") or completed_data.get("focus_losses"):
                raise RuntimeError("Recovered report is interrupted; preserve it as invalid evidence")
            previous_log = OUT / "logcat.log"
            previous_text = previous_log.read_text(encoding="utf-8", errors="replace") if previous_log.exists() else ""
            match = re.search(r'^\d\d-\d\d \d\d:\d\d:\d\d\.\d+\s+(\d+)\s+', previous_text, re.M)
            recovered_log = ""
            if match:
                recovered_log = read("logcat", "-d", "--pid=" + match[1], "-v", "threadtime")
                (OUT / "logcat-recovered.log").write_text(recovered_log, encoding="utf-8")
                if re.search(r'SCRIPT ERROR|\bE\s+godot\s*:\s*ERROR:', previous_text + recovered_log, re.I):
                    raise RuntimeError("Runtime error in recovered benchmark log")
            with (OUT / "phone-files.tar").open("wb") as archive:
                call(adb + ["exec-out", "run-as", PACKAGE, "tar", "-cf", "-", f"files/{BENCH_REL}"], stdout=archive)
            (OUT / "observer-recovery.json").write_text(json.dumps({"completed_checkpoint": True,
                "historical_logcat_nonempty": bool(recovered_log), "pid_from_previous_log": bool(match),
                "note": "USB gap; logcat ring buffer may not retain the entire interval"}, indent=2), encoding="utf-8")
            print("PHONE COMPLETED CHECKPOINT RECOVERED", flush=True)
            return
    pid = ""
    for _ in range(30):
        process = subprocess.run(adb + ["shell", "pidof", PACKAGE], capture_output=True, text=True)
        pid = process.stdout.strip()
        if pid: break
        time.sleep(.5)
    if not pid: raise RuntimeError("Benchmark did not start")
    log = (OUT / "logcat.log").open("a" if args.attach else "w", encoding="utf-8")
    logger = subprocess.Popen(adb + ["logcat", "--pid=" + pid, "-v", "threadtime"], stdout=log, stderr=subprocess.STDOUT)
    next_battery = 0
    next_shot = 45
    temperatures = prior if args.attach else []
    last_passes = 0
    try:
        while time.monotonic() - began < 1500:
            elapsed = time.monotonic() - began
            log.flush()
            with (OUT / "logcat.log").open("rb") as recent:
                recent.seek(max(0, recent.seek(0, 2) - 32768))
                tail = recent.read()
            if b"benchmark lost foreground focus" in tail or b"SCRIPT ERROR" in tail or b"E godot   : ERROR:" in tail:
                raise RuntimeError("Benchmark was interrupted or a script failed; inspect logcat before continuing")
            if elapsed >= next_battery:
                battery = read("shell", "dumpsys", "battery")
                (OUT / f"battery-{len(temperatures):02d}.txt").write_text(battery, encoding="utf-8")
                match = re.search(r'temperature:\s*(\d+)', battery)
                power_sources = [source for source in ("AC", "USB", "Wireless", "Dock") if source + " powered: true" in battery]
                temperatures.append({"elapsed_s": elapsed, "temperature_c": int(match[1])/10 if match else None,
                                     "charging": bool(power_sources), "power_sources": power_sources})
                (OUT / "temperatures.json").write_text(json.dumps(temperatures, indent=2), encoding="utf-8")
                next_battery = elapsed + 60
                print(f"PHONE {elapsed:.0f}s temperature={temperatures[-1]['temperature_c']}", flush=True)
            if args.display and elapsed >= next_shot:
                with (OUT / f"device-{int(elapsed):04d}.png").open("wb") as shot:
                    call(adb + ["exec-out", "screencap", "-d", args.display, "-p"], stdout=shot)
                next_shot += 180
            probe = subprocess.run(adb + ["shell", "run-as", PACKAGE, "cat", f"files/{BENCH_REL}/report.json"], capture_output=True)
            if probe.returncode == 0:
                try:
                    data = json.loads(probe.stdout)
                except (json.JSONDecodeError, UnicodeDecodeError):
                    # The app may be replacing a checkpoint while ADB reads it. Retry without restarting the app.
                    time.sleep(1)
                    continue
                (OUT / "report.json").write_bytes(probe.stdout)
                if len(data["passes"]) != last_passes:
                    last_passes = len(data["passes"])
                    print(f"PHONE passes={last_passes} active duration={data['passes'][-1]['elapsed_s']:.1f}s", flush=True)
                if data.get("focus_losses") or data.get("problems"):
                    raise RuntimeError("Benchmark lost focus or reported a problem; preserve partial report and unlock before retrying")
                if (TARGET_PASSES and len(data["passes"]) >= TARGET_PASSES) or (not TARGET_PASSES and data["passes"][-1]["elapsed_s"] >= 900):
                    break
            elif subprocess.run(adb + ["shell", "pidof", PACKAGE], capture_output=True).returncode != 0:
                connection = subprocess.run(adb + ["get-state"], capture_output=True, text=True)
                if connection.returncode or connection.stdout.strip() != "device":
                    raise ConnectionError("USB observation lost; preserve this attempt and use --attach if the benchmark is still running")
                raise RuntimeError("Benchmark exited before producing a report; inspect logcat")
            time.sleep(5)
        else:
            raise RuntimeError("Phone did not finish within 25 minutes; inspect lock state and logcat")
        # run-as access stays within this benchmark package's private files.
        archive = OUT / "phone-files.tar"
        with archive.open("wb") as f:
            call(adb + ["exec-out", "run-as", PACKAGE, "tar", "-cf", "-", f"files/{BENCH_REL}"], stdout=f)
        print("PHONE RECORDING COMPLETE", flush=True)
    finally:
        logger.terminate()
        logger.wait(timeout=10)
        log.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["export", "run"])
    parser.add_argument("--sdk", default=str(ROOT / "build/tools/android"))
    parser.add_argument("--godot", default=os.environ.get("GODOT", "C:/Program Files/Godot/Godot_v4.7-stable_win64.exe"))
    parser.add_argument("--java", default=os.environ.get("JAVA_HOME", "C:/Program Files/Eclipse Adoptium/jdk-17.0.20.101-hotspot"))
    parser.add_argument("--serial")
    parser.add_argument("--display")
    parser.add_argument("--attach", action="store_true", help="resume observation without reinstalling or restarting the app")
    options = parser.parse_args()
    if options.action == "run" and not options.serial: parser.error("--serial is required")
    export(options) if options.action == "export" else record(options)
