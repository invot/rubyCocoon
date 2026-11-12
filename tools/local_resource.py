"""Run a heavy local job without overlapping the shared model or another heavy job.

python tools/local_resource.py -- <Godot/Blender benchmark or render command>
Both agents use this for measured runs and artwork generation/renders. Model calls
already acquire the same lock through tools/look.py. Do not wrap a command that
itself calls look.py or server.py: that would request the same lock twice.
"""
import subprocess
import sys
from look import model_lock

if __name__ == "__main__":
    command = sys.argv[1:]
    if command[:1] == ["--"]:
        command = command[1:]
    if not command:
        raise SystemExit(__doc__)
    with model_lock(timeout=3600):
        raise SystemExit(subprocess.run(command).returncode)
