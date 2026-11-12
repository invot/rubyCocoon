"""Isolated, single-thread Web benchmark: python tools/vo_web.py export|serve.

Open http://127.0.0.1:8061/?vo_perf=1 in the built-in browser. Two full route passes
are collected in build/perf/vo/baseline-web/report.json. This is a local measurement
export, without the production download compression/partitioning stage.
"""
import argparse
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "build/web_perf"
OUT = ROOT / "build/perf/vo/baseline-web"


def export(godot):
    WEB.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    path = ROOT / "export_presets.cfg"
    original = path.read_bytes()
    source = original.decode("utf-8")
    clone = re.search(r'\[preset\.1\][\s\S]*?(?=\[preset\.2\]|\Z)', source)[0]
    index = max(map(int, re.findall(r'\[preset\.(\d+)\]', source))) + 1
    clone = clone.replace("[preset.1", f"[preset.{index}")
    excluded = json.loads(re.search(r'^exclude_filter=(.*)$', clone, re.M)[1])
    for key, value in {"name": "Web Perf", "export_path": str(WEB / "index.html").replace("\\", "/"),
                       "exclude_filter": ", ".join(x.strip() for x in excluded.split(",") if x.strip() != "tools/*")}.items():
        clone, count = re.subn(r'^' + re.escape(key) + r'=.*$', lambda _: key + '=' + json.dumps(value), clone, flags=re.M)
        if count != 1:
            raise RuntimeError(f"Expected one {key}, found {count}")
    (OUT / "export-preset-perf.cfg").write_text(clone, encoding="utf-8")
    path.write_bytes(original + b"\n" + clone.encode())
    try:
        with (OUT / "export.log").open("w", encoding="utf-8") as log:
            subprocess.run([godot, "--headless", "--path", str(ROOT), "--export-release", "Web Perf", str(WEB / "index.html")],
                           cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True)
    finally:
        path.write_bytes(original)
    html = WEB / "index.html"
    text = html.read_text(encoding="utf-8")
    setup = '''
window.voPerfReport = report => {
    const passes = report.passes.map(p => ({elapsed_s:p.elapsed_s, transitions:p.transitions,
        segments:Object.fromEntries(Object.entries(p.segments).map(([k,v]) => [k,{frame_ms:v.summary.frame_ms}]))}));
    console.log('VO PERF WEB ' + JSON.stringify({platform:report.platform,renderer:report.renderer,
        window:report.window,render_size:report.render_size,problems:report.problems,passes}));
    fetch('/vo-report', {method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(report)})
        .then(r => {if (!r.ok) throw Error(r.status);console.log('VO PERF WEB saved '+report.passes.length+' pass(es)');})
        .catch(e => console.error('VO PERF WEB save failed',e));
};
if (new URLSearchParams(location.search).get('vo_perf') === '1') {
    GODOT_CONFIG.args = ['--','--scene=vo-perf','--passes=2','--render_height=1080','--graphics_quality=mid',
        '--report=user://bench/vo/003/report.json','--save_dir=user://bench/vo/003/saves/',
        '--prefs_path=user://bench/vo/003/settings.cfg'];
}
'''
    text = text.replace('const engine = new Engine(GODOT_CONFIG);', setup + '\nconst engine = new Engine(GODOT_CONFIG);')
    text = text.replace('<script src="index.js"></script>', '<script src="web_fullscreen.js"></script>\n<script src="index.js"></script>')
    html.write_text(text, encoding="utf-8")
    shutil.copy2(ROOT / "tools/web_fullscreen.js", WEB / "web_fullscreen.js")
    shutil.copy2(ROOT / "ui/LeagueSpartan.ttf", WEB / "LeagueSpartan.ttf")
    shutil.copytree(ROOT / "build/web_music", WEB / "music", dirs_exist_ok=True, ignore=shutil.ignore_patterns("*.import"))
    print(f"Exported {WEB}", flush=True)


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(WEB), **kwargs)

    def do_POST(self):
        if self.path != "/vo-report":
            self.send_error(404)
            return
        size = int(self.headers.get("Content-Length", "0"))
        if not 0 < size <= 50_000_000:
            self.send_error(413)
            return
        report = json.loads(self.rfile.read(size))
        if report.get("platform") != "Web" or report.get("seed") != 12026:
            self.send_error(400)
            return
        OUT.mkdir(parents=True, exist_ok=True)
        temporary = OUT / "report.tmp"
        temporary.write_text(json.dumps(report, indent=2), encoding="utf-8")
        temporary.replace(OUT / "report.json")
        self.send_response(204)
        self.end_headers()
        print(f"Collected {len(report['passes'])} pass(es)", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["export", "serve"])
    parser.add_argument("--godot", default="C:/Program Files/Godot/Godot_v4.7-stable_win64.exe")
    args = parser.parse_args()
    if args.command == "export":
        export(args.godot)
    else:
        ThreadingHTTPServer(("127.0.0.1", 8061), Handler).serve_forever()
