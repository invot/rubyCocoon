"""Export a dedicated Windows Compatibility build from the existing Windows preset.

python tools/vo_windows_compat.py
python tools/vo_windows_compat.py --benchmark
Normal export presets are restored byte-for-byte; this is not a Vulkan export.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
from look import model_lock
from godot_toolchain import default_godot, engine_version, template_path

ROOT = Path(__file__).resolve().parents[1]


def export(benchmark=False):
    with model_lock(timeout=3600):
        return _export(benchmark)


def _export(benchmark):
    godot = default_godot()
    path = ROOT / "export_presets.cfg"
    original = path.read_bytes()
    source = original.decode("utf-8").replace("\r\n", "\n")
    sections = re.findall(r'\[preset\.(\d+)\]\s*\n([\s\S]*?)(?=\n\[preset\.\d+\]\s*\n|\Z)', source)
    index, content = next((i,c) for i,c in sections if re.search(r'^name="Windows Desktop"$', c, re.M))
    next_index = max(int(i) for i,c in sections) + 1
    clone = f"[preset.{next_index}]\n\n" + content.replace(f"[preset.{index}.options]", f"[preset.{next_index}.options]")
    output = ROOT / ("build/windows-compat-bench/RubyCocoon.exe" if benchmark else "build/windows-compat/RubyCocoon.exe")
    folder = ROOT / "build/perf/vo/009b/windows-export"
    folder.mkdir(parents=True, exist_ok=True)
    output.parent.mkdir(parents=True, exist_ok=True)
    changes = {"name": "Windows Compatibility", "runnable": False,
               "custom_features": "compatibility_build", "export_path": str(output).replace("\\", "/")}
    for kind in ["debug", "release"]:
        template = template_path(godot, f"windows_{kind}_x86_64.exe")
        changes[f"custom_template/{kind}"] = template.as_posix()
    if benchmark:
        excluded = json.loads(re.search(r'^exclude_filter=(.*)$', clone, re.M)[1])
        changes["exclude_filter"] = ", ".join(v.strip() for v in excluded.split(",") if v.strip() != "tools/*")
    for key,value in changes.items():
        clone, count = re.subn(r'^' + re.escape(key) + r'=.*$', lambda _:key+"="+json.dumps(value), clone, flags=re.M)
        if count != 1:
            raise RuntimeError(f"Expected one {key} option, got {count}")
    (folder / "original-presets.cfg").write_bytes(original)
    (folder / "compatibility-preset.cfg").write_text(clone, encoding="utf-8")
    (folder / "engine-version.txt").write_text(engine_version(godot).full + "\n", encoding="utf-8")
    temporary = original + b"\n" + clone.encode("utf-8")
    path.write_bytes(temporary)
    try:
        with (folder / "export.log").open("w", encoding="utf-8") as log:
            subprocess.run([godot,
                            "--headless", "--path", str(ROOT), "--export-debug" if benchmark else "--export-release",
                            "Windows Compatibility", str(output)], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True)
    finally:
        if path.read_bytes() == temporary:
            path.write_bytes(original)
        else:
            raise RuntimeError("Export presets changed externally; preserved for inspection (original snapshot retained)")
    print(output)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--benchmark", action="store_true")
    export(parser.parse_args().benchmark)
