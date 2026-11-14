"""Prepare/import/run an isolated Godot 4.8 backdrop streaming trial.

python tools/vo_streaming_trial.py prepare --attempt example
python tools/vo_streaming_trial.py import --attempt example
python tools/vo_streaming_trial.py run --attempt example --renderer mobile --mode streamed
Runs use the shared resource lock and native memory guard. No production imports change.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import sys

from godot_toolchain import default_godot
from look import model_lock
from run_guarded import run

ROOT = Path(__file__).resolve().parents[1]


def prepare(folder):
    folder.mkdir(parents=True, exist_ok=False)
    project = folder / "project"
    project.mkdir()
    (project / "project.godot").write_text('''config_version=5
[application]
config/name="010c streaming diagnostic"
run/main_scene="res://main.tscn"
config/features=PackedStringArray("4.8")
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/frame_pacing/android/swappy_mode=0
[rendering]
renderer/rendering_method="forward_plus"
textures/streaming/enabled=true
textures/streaming/inactivity_decay_rate_ms=1000
textures/vram_compression/import_s3tc_bptc=true
textures/vram_compression/import_etc2_astc=true
''', encoding="utf-8")
    (project / "main.tscn").write_text('''[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://trial.gd" id="1"]
[node name="Trial" type="Node3D"]
script=ExtResource("1")
''', encoding="utf-8")
    shutil.copy2(ROOT / "tools/debug/texture_streaming_trial.gd", project / "trial.gd")
    manifest = []
    for mode in ("regular", "streamed", "astc"):
        (project / mode).mkdir()
        for index in range(3):
            source = ROOT / "assets/battle/backdrops/coast.png"
            target = project / mode / f"coast_{index}.png"
            shutil.copy2(source, target)
            importer, kind = (("streamed_texture_2d", "StreamedTexture2D") if mode == "streamed"
                              else ("texture", "CompressedTexture2D"))
            sidecar = (f'[remap]\nimporter="{importer}"\ntype="{kind}"\n'
                       f'[deps]\nsource_file="res://{mode}/{target.name}"\n'
                       '[params]\ncompress/high_quality=false\ncompress/normal_map=2\n')
            if mode == "regular":
                sidecar += 'compress/mode=2\nmipmaps/generate=true\n'
            elif mode == "astc":
                sidecar = sidecar.replace('compress/high_quality=false', 'compress/high_quality=true')
                sidecar += 'compress/mode=2\ncompress/high_quality_mode=2\nmipmaps/generate=true\n'
            Path(str(target) + ".import").write_text(sidecar, encoding="utf-8")
            manifest.append({"source": source.relative_to(ROOT).as_posix(), "copy": target.relative_to(project).as_posix(),
                             "sha256": hashlib.sha256(target.read_bytes()).hexdigest()})
    (folder / "source-manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["prepare", "import", "run"])
    parser.add_argument("--attempt", required=True)
    parser.add_argument("--godot", default=default_godot())
    parser.add_argument("--renderer", choices=["forward_plus", "mobile", "gl_compatibility"], default="forward_plus")
    parser.add_argument("--mode", choices=["regular", "streamed", "astc"], default="streamed")
    args = parser.parse_args()
    if not args.attempt or any(c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-" for c in args.attempt):
        parser.error("Use a new plain attempt name")
    folder = ROOT / "build/perf/vo/010c" / args.attempt
    if args.action == "prepare":
        prepare(folder)
        return 0
    project = folder / "project"
    if not (project / "project.godot").is_file():
        raise FileNotFoundError("Prepare this attempt first")
    destination = folder / ("import" if args.action == "import" else f"{args.renderer}-{args.mode}")
    destination.mkdir(exist_ok=False)
    command = [args.godot, "--path", str(project), "--log-file", str(destination / "godot.log")]
    if args.action == "import":
        command += ["--headless", "--editor", "--import"]
    else:
        command += ["--rendering-method", args.renderer, "--resolution", "1280x720", "--",
                    f"--mode={args.mode}", f"--output={destination.as_posix()}"]
    (destination / "command.json").write_text(json.dumps(command, indent=2))
    with model_lock(timeout=7200), (destination / "stdout.log").open("w", encoding="utf-8") as log:
        code = run(command, timeout=180, stdout=log, stderr=log, log=log)
    text = (destination / "stdout.log").read_text(encoding="utf-8", errors="replace")
    if code or any(error in text for error in ("SCRIPT ERROR", "ERROR:", "Failed loading resource")):
        raise RuntimeError(f"Diagnostic failed; inspect {destination}")
    if args.action == "run":
        report = json.loads((destination / "report.json").read_text())
        if report["problems"] or report["renderer"] != args.renderer or report["mode"] != args.mode:
            raise RuntimeError("Diagnostic workload did not match")
        print(json.dumps({"path": str(destination), "renderer": report["renderer"], "formats": report["formats_sampling_supported"]}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
