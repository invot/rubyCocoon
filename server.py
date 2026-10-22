"""A small server on this machine for running Ruby Cocoon's tests with the help of the vision model in Bionic
(qwen3-vl-8b-instruct, as tools/look.py uses it): it runs the tests and takes screenshots here, then has the model
read the logs of the tests that failed and look at the pictures, so what comes back is a few short lines instead of
long logs and big images.

  python server.py                 listens on http://127.0.0.1:5000 (SERVER_PORT changes the port)

  GET  /bionic/health              whether Bionic's server answers and the model is there
  POST /bionic/run                 {"tool": ..., "params": {...}}, one of:
    tests  {"names": ["flow", "maps"]}, {"names": "quick"} or {} for everything (6-8 minutes): tools/run_tests.sh's
           summary, and for each test that failed the model's two-sentence reading of its log
    shot   {"scene": "world:caccoon#1@2", "args": {"spawn": "entry", "crop": "0.4,0.2,0.8,0.6"},
            "question": "Is there a radiator under the window?"}: a screenshot from the game's test harness (saved
           in build/shots/, named by "name" or the scene), and the model's answer when there's a question
    look   {"image": "build/shots/a.png", "question": "..."}: the model's answer about a picture already taken
    ask    {"text": "..."}: the model's answer to a plain question

  curl -s -X POST http://127.0.0.1:5000/bionic/run -H "Content-Type: application/json" -d "{\"tool\": \"tests\", \"params\": {\"names\": \"quick\"}}"

Bionic's own tools (run_python, its MCP servers) only exist inside its chat window, where the model calls them, so
nothing outside can call them: the model is reached through Bionic's OpenAI-style server (LOOK_URL, LOOK_MODEL).
GODOT and GIT_BASH say where Godot and Git's bash are, if not in the usual places.
"""
import importlib.util
import json
import os
import re
import shutil
import subprocess
import urllib.request

from flask import Flask, jsonify, request

ROOT = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("look", os.path.join(ROOT, "tools", "look.py"))
qwen = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(qwen)

GODOT = os.environ.get("GODOT", "C:/Program Files/Godot/Godot_v4.7-stable_win64.exe")
# Git's bash, which the test script needs (on Windows a bare "bash" can be WSL's, which can't see Godot)
GIT_BASH = os.environ.get("GIT_BASH") or next(
    (p for p in ["C:/Program Files/Git/bin/bash.exe", "C:/Program Files (x86)/Git/bin/bash.exe"] if os.path.exists(p)),
    shutil.which("bash"))
SHOTS = os.path.join(ROOT, "build", "shots")
## what a test name, a harness argument's name, or a screenshot's name may be made of
WORD = re.compile(r"^[A-Za-z0-9_\-]+$")
SCENE = re.compile(r"^[A-Za-z0-9_:#@,\-]+$")

app = Flask(__name__)


def _run(cmd, timeout):
    return subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace",
                          timeout=timeout)


def _model(fn, *args):
    """The model's answer, or why there isn't one (the tests' results still come back when Bionic is closed)."""
    try:
        return fn(*args)
    except Exception as e:
        return "(no answer from the model at %s: %s)" % (qwen.URL, e)


def explain(log, name):
    """The model's short reading of a failed test's log: the lines that went wrong, and how the log ends."""
    try:
        with open(log, encoding="utf-8", errors="replace") as f:
            lines = f.read().splitlines()
    except OSError:
        return ""
    keep = []
    for i, line in enumerate(lines):
        if re.search(r"ERROR|FAIL|Error|missing|problem|captured false", line) and "0 problem" not in line:
            keep += lines[i:i + 3]
    excerpt = "\n".join(keep[:60] + ["..."] + lines[-30:])[-6000:]
    return _model(qwen.ask, "These lines are from the log of a Godot game's test called '%s', which failed. In at "
                  "most two sentences, say what went wrong and where (the script and line if the log shows them). "
                  "Don't suggest a fix.\n\n%s" % (name, excerpt), 150)


def tests(params):
    names = params.get("names", [])
    if isinstance(names, str):
        names = names.split()
    if not all(isinstance(n, str) and WORD.match(n) for n in names):
        raise ValueError("test names are words like flow or maps-built")
    if not GIT_BASH:
        raise RuntimeError("Git's bash wasn't found: set GIT_BASH")
    p = _run([GIT_BASH, "tools/run_tests.sh", *names], 1800)
    summary = [line for line in p.stdout.splitlines() if line.strip()]
    failures = []
    for line in summary:
        m = re.match(r"^FAIL\s+(\S+)\s+\d+s\s?(.*?)\s+\(log: (.+)\)$", line)
        if m:
            name, detail, log = m.groups()
            failures.append({"test": name, "detail": detail, "log": log,
                             "model": explain(os.path.join(ROOT, log), name)})
    if not summary:
        summary = p.stderr.splitlines()[-10:]
    return {"passed": p.returncode == 0, "summary": summary, "failures": failures}


def shot(params):
    scene = str(params.get("scene", ""))
    if not SCENE.match(scene):
        raise ValueError("scene is the harness's --scene, like world:caccoon or world:caccoon#1@2")
    args = dict(params.get("args", {}))
    args.setdefault("wait", "2.5")
    for k, v in args.items():
        if not WORD.match(k) or not SCENE.match(str(v).replace(".", "")):
            raise ValueError("harness arguments are name: value pairs like spawn: entry or crop: 0.4,0.2,0.8,0.6")
    name = str(params.get("name") or re.sub(r"[^A-Za-z0-9_]+", "_", scene).strip("_"))
    if not WORD.match(name):
        raise ValueError("name is a word: the screenshot is saved as build/shots/<name>.png")
    os.makedirs(SHOTS, exist_ok=True)
    path = os.path.join(SHOTS, name + ".png")
    if os.path.exists(path):
        os.remove(path)
    cmd = [GODOT, "--path", ROOT, "--", "--scene=" + scene, "--shot=" + path.replace("\\", "/")]
    p = _run(cmd + ["--%s=%s" % (k, v) for k, v in args.items()], 300)
    out = p.stdout + p.stderr
    errors = [line for line in out.splitlines() if "SCRIPT ERROR" in line or "ERROR:" in line][:5]
    if not os.path.exists(path):
        raise RuntimeError("no screenshot came out: %s" % ("; ".join(errors) or out.strip()[-300:]))
    result = {"path": os.path.relpath(path, ROOT).replace("\\", "/"), "errors": errors}
    if params.get("question"):
        result["answer"] = _model(qwen.look, path, str(params["question"]), int(params.get("max_tokens", 200)))
    return result


def look(params):
    image = os.path.join(ROOT, str(params["image"]))
    if not os.path.isfile(image):
        raise ValueError("no picture at %s" % params["image"])
    return {"answer": qwen.look(image, str(params["question"]), int(params.get("max_tokens", 200)))}


def ask(params):
    return {"answer": qwen.ask(str(params["text"]), int(params.get("max_tokens", 200)))}


TOOLS = {"tests": tests, "shot": shot, "look": look, "ask": ask}


@app.route('/bionic/health', methods=['GET'])
def health():
    try:
        with urllib.request.urlopen(qwen.URL.replace("/chat/completions", "/models"), timeout=5) as r:
            models = [m["id"] for m in json.load(r)["data"]]
        return jsonify({"model": qwen.MODEL, "loaded": qwen.MODEL in models, "models": models}), 200
    except Exception as e:
        return jsonify({"model": qwen.MODEL, "loaded": False, "error": str(e)}), 503


@app.route('/bionic/run', methods=['POST'])
def run_bionic():
    data = request.get_json(silent=True) or {}
    tool = TOOLS.get(data.get('tool'))
    if tool is None:
        return jsonify({"error": "tool is one of: " + ", ".join(TOOLS)}), 400
    try:
        return jsonify(tool(data.get('params') or {})), 200
    except (KeyError, ValueError, TypeError) as e:
        return jsonify({"error": "bad params: %s" % e}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == '__main__':
    # only this machine: the tools run Godot and the test scripts
    app.run(host='127.0.0.1', port=int(os.environ.get("SERVER_PORT", "5000")))
