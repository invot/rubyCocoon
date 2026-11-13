"""006 web suite. Export, then serve while holding the shared measurement lock.

Open http://127.0.0.1:8066/?vo_perf=1 in the in-app browser. The collector stops
five seconds after receiving all three passes; original baseline files are untouched.
"""
import argparse
from godot_toolchain import default_godot
import base64
from http.server import ThreadingHTTPServer
import json
from pathlib import Path
import re
import threading

from look import model_lock
import vo_web

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build/perf/vo/006/web"
WEB = ROOT / "build/web_perf_006"
vo_web.OUT = OUT
vo_web.WEB = WEB
vo_web.BENCH_REL = "bench/vo/006"
vo_web.EXTRA_ARGS = ["--scene=vo-scenery", "--part=suite", "--web_images=1", "--duration=0",
                     "--shots=user://bench/vo/006/shots", "--shot_w=0"]


class Handler(vo_web.Handler):
    def do_POST(self):
        if self.path == "/vo-image":
            size = int(self.headers.get("Content-Length", "0"))
            if not 0 < size < 20_000_000:
                self.send_error(413)
                return
            data = json.loads(self.rfile.read(size))
            if not re.fullmatch(r"[A-Za-z0-9_-]+", data["name"]):
                self.send_error(400)
                return
            image = base64.b64decode(data["image"], validate=True)
            if not image.startswith(b"\x89PNG\r\n\x1a\n"):
                self.send_error(400)
                return
            shots = ROOT / "build/shots/vo/006" / OUT.name
            shots.mkdir(parents=True, exist_ok=True)
            (shots / (data["name"] + ".png")).write_bytes(image)
            self.send_response(204)
            self.end_headers()
            return
        super().do_POST()
        if self.path == "/vo-report" and (OUT / "report.json").exists():
            data = json.loads((OUT / "report.json").read_text(encoding="utf-8"))
            if len(data.get("passes", [])) == 3:
                threading.Timer(5, self.server.shutdown).start()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["export", "serve"])
    parser.add_argument("--godot", default=default_godot())
    parser.add_argument("--attempt", default="01")
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9_-]+", args.attempt):
        raise ValueError("Use a plain attempt name")
    OUT = ROOT / "build/perf/vo/006" / ("web_" + args.attempt)
    WEB = ROOT / ("build/web_perf_006_" + args.attempt)
    vo_web.OUT = OUT
    vo_web.WEB = WEB
    vo_web.BENCH_REL = "bench/vo/006/web_" + args.attempt
    vo_web.EXTRA_ARGS = [arg for arg in vo_web.EXTRA_ARGS if not arg.startswith("--shots=")]
    vo_web.EXTRA_ARGS.append("--shots=user://" + vo_web.BENCH_REL + "/shots")
    with model_lock(timeout=3600):
        if args.action == "export":
            if (WEB / "index.html").exists():
                raise FileExistsError("Preserve the existing web experiment")
            vo_web.export(args.godot)
            path = WEB / "index.html"
            html = path.read_text(encoding="utf-8")
            bridge = "window.voPerfImage = (name,image) => fetch('/vo-image',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({name,image})});\n"
            path.write_text(html.replace("window.voPerfReport =", bridge + "window.voPerfReport ="), encoding="utf-8")
        else:
            if (OUT / "report.json").exists():
                raise FileExistsError("Preserve the existing web report")
            print("WEB SCENERY READY: http://127.0.0.1:8066/?vo_perf=1", flush=True)
            with ThreadingHTTPServer(("127.0.0.1", 8066), Handler) as server:
                server.serve_forever()
