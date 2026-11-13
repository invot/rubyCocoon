"""Verify Windows export defaults with actual executables, without renderer command overrides."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import argparse
from look import model_lock
from godot_toolchain import default_godot, engine_version, template_path
from run_guarded import run as run_guarded

ROOT = Path(__file__).resolve().parents[1]
GODOT = default_godot()


def run(attempt):
    path = ROOT/"export_presets.cfg"
    if not attempt or not all(c.isalnum() or c in "_-" for c in attempt):raise ValueError("Use a plain new attempt")
    out = ROOT/"build/perf/vo/011"/attempt
    out.mkdir(parents=True,exist_ok=False)
    with model_lock(timeout=3600):
        original = path.read_bytes()
        (out/"original-presets.cfg").write_bytes(original)
        text = original.decode("utf-8").replace("\r\n","\n")
        sections = re.findall(r'\[preset\.(\d+)\]\s*\n([\s\S]*?)(?=\n\[preset\.\d+\]\s*\n|\Z)',text)
        index, content = next((i,c) for i,c in sections if re.search(r'^name="Windows Desktop"$',c,re.M))
        number = max(int(i) for i,c in sections)+1
        results = []
        for tag, features, expected in [("forward","","forward_plus"),("compat","compatibility_build","gl_compatibility")]:
            folder = out/tag
            folder.mkdir()
            exe = ROOT/f"build/exports/vo011/{attempt}/{tag}/RubyCocoon.exe"
            exe.parent.mkdir(parents=True,exist_ok=True)
            clone = f"[preset.{number}]\n\n"+content.replace(f"[preset.{index}.options]",f"[preset.{number}.options]")
            changes = {"name":"VO Export Probe", "custom_features":features, "export_path":exe.as_posix(),
                       "custom_template/debug":template_path(GODOT, "windows_debug_x86_64.exe").as_posix()}
            for key,value in changes.items():
                clone,count=re.subn(r'^'+re.escape(key)+r'=.*$',lambda _:key+"="+json.dumps(value),clone,flags=re.M)
                if count!=1:raise ValueError("Missing preset field "+key)
            temporary=original+b"\n"+clone.encode()
            (folder/"preset.cfg").write_text(clone,encoding="utf8")
            path.write_bytes(temporary)
            try:
                with (folder/"export.log").open("w") as log:
                    command=[GODOT,"--headless","--path",str(ROOT),"--export-debug","VO Export Probe",str(exe)]
                    code=run_guarded(command,timeout=180,stdout=log,stderr=log,log=log)
                    if code:raise subprocess.CalledProcessError(code,command)
            finally:
                if path.read_bytes()!=temporary:raise RuntimeError("Concurrent preset edit; preserve original snapshot")
                path.write_bytes(original)
            log_path=folder/"runtime.log"
            command=[str(exe),"--log-file",str(log_path),"--","--scene=vo-renderer",
                     f"--prefs_path=user://bench/vo/011/export-{tag}/settings.cfg",f"--save_dir=user://bench/vo/011/export-{tag}/saves/"]
            (folder/"command.json").write_text(json.dumps(command,indent=2))
            code=run_guarded(command,timeout=90)
            if code:raise subprocess.CalledProcessError(code,command)
            log=log_path.read_text(encoding="utf8")
            if "SCRIPT ERROR" in log or "Failed loading resource" in log:raise RuntimeError("Export probe failed")
            line=next(line for line in log.splitlines() if line.startswith("VO RENDERER "))
            data=json.loads(line.removeprefix("VO RENDERER "))
            if data["renderer"]!=expected or data["compatibility_build"]!=bool(features):raise ValueError("Wrong export renderer")
            data["executable_sha256"]=hashlib.sha256(exe.read_bytes()).hexdigest()
            data["editor_version"]=engine_version(GODOT).full
            pack=exe.with_suffix(".pck")
            data["pack_sha256"]=hashlib.sha256(pack.read_bytes()).hexdigest() if pack.exists() else None
            results.append(data)
        (out/"results.json").write_text(json.dumps({"presets_restored":path.read_bytes()==original,"exports":results},indent=2))
        (out/"original-presets.cfg").write_bytes(original)
        print(json.dumps(results),flush=True)


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--attempt",required=True)
    run(parser.parse_args().attempt)
