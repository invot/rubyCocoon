"""011: explicit budget recording/generation; tests never rewrite reviewed limits."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import subprocess
import time

from look import model_lock
from vo_shadow_sweep import validate_segment

ROOT = Path(__file__).resolve().parents[1]
LEDGER = ROOT / "docs/visual_overhaul/ledger"
METRICS = ["geometry_nodes", "surface_submissions", "source_triangles", "distinct_materials",
           "transparent_surfaces", "texture_rgba8_mip_bytes"]
SCENES = {"coastal_path", "cove_plaza", "hero_house", "rue_royale", "coast_battle"}


def load_terrain_report(path, noise=False, lighting=False):
    data=json.loads(Path(path).read_text(encoding="utf-8"))
    if data.get("benchmark")!="budget-011" or data['problems'] or data['focus_losses'] or len(data['passes'])!=3:
        raise ValueError("Incomplete terrain A/B/A")
    batches=data['passes']
    settings=['render_height','render_size','quality','vsync','max_fps']
    experiments=[]
    for batch in batches:
        if batch['focus_losses'] or set(batch['segments'])!={'coastal_path'} or any(batch[k]!=batches[0][k] for k in settings):
            raise ValueError("Terrain controls/settings differ")
        segment=batch['segments']['coastal_path']
        experiments.append(segment['experiment'])
        if len(segment['samples'])!=3 or segment['tiles']!=batches[0]['segments']['coastal_path']['tiles']:
            raise ValueError("Terrain route differs")
        for sample in segment['samples']:
            validate_segment(sample['rendered'])
            if sample['rendered']['frames']!=120:raise ValueError("Terrain samples changed")
    if lighting:
        if [e['trial'] for e in experiments]!=['pixel','vertex','pixel'] or experiments[1]['materials']<=0 or experiments[1]['shaders']<=0:
            raise ValueError("Vertex lighting controls did not take effect")
    elif noise:
        if [e['trial'] for e in experiments]!=['analytic','lookup','analytic'] or any(e['materials']<=0 for e in experiments):
            raise ValueError("Noise lookup controls did not take effect")
    elif [e['trial'] for e in experiments]!=['original','optimized','original'] or experiments[0]['shader_sha256']!=experiments[2]['shader_sha256'] or experiments[0]['shader_sha256']==experiments[1]['shader_sha256']:
        raise ValueError("Terrain shader controls did not take effect")
    return data


def load_report(path, expected_scenes=None):
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    if data.get("benchmark") != "budget-011" or data["problems"] or data["focus_losses"] or len(data["passes"]) != 1:
        raise ValueError("Incomplete/interrupted budget record: " + str(path))
    segments = data["passes"][0]["segments"]
    if set(segments) != (SCENES if expected_scenes is None else expected_scenes):
        raise ValueError("Budget route scenes changed")
    for name, segment in segments.items():
        if len(segment["samples"]) != (1 if name == "coast_battle" else 3):
            raise ValueError("Missing budget samples")
        for sample in segment["samples"]:
            source = sample["source"]
            if source["unsupported_textures"] or not source.get("scope"):
                raise ValueError("Incomplete source inventory")
            for metric in METRICS:
                value = source[metric]
                if not isinstance(value, (int, float)) or not math.isfinite(value) or value < 0:
                    raise ValueError("Invalid source metric: " + metric)
            if source["source_triangles"] == 0 or source["distinct_materials"] == 0:
                raise ValueError("Empty source scene")
    return data


def record(args):
    if not args.attempt or not all(c.isalnum() or c in "_-" for c in args.attempt):
        raise ValueError("Use a new plain --attempt")
    out = ROOT / "build/perf/vo/011" / args.attempt
    out.mkdir(exist_ok=False, parents=True)
    command = [args.godot, "--path", str(ROOT), "--resolution", "2400x1080" if args.touch else "1920x1080",
               "--log-file", str(out/"godot.log")]
    if args.headless:
        command.append("--headless")
    else:
        command += ["--rendering-method", args.renderer, "--disable-vsync"]
    command += ["--", "--scene=vo-budget", "--record=1", "--graphics_quality=mid", "--render_height=720",
                "--report="+str(out/"report.json"), f"--save_dir=res://build/vo_state/011/{args.attempt}/saves/",
                f"--prefs_path=res://build/vo_state/011/{args.attempt}/settings.cfg"]
    if not args.headless:
        command.append("--await_focus=1")
    if args.touch:
        command.append("--touch")
    if args.trial:
        command += ["--trial="+args.trial,f"--shots=res://build/shots/vo/011/{args.attempt}","--shot_w=0"]
    (out/"command.json").write_text(json.dumps(command, indent=2))
    with model_lock(timeout=3600), (out/"stdout.log").open("w") as log:
        print("Recording 011 " + args.attempt, flush=True)
        process = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
        deadline = time.monotonic()+600
        while process.poll() is None:
            time.sleep(.5)
            text = (out/"godot.log").read_text(encoding="utf-8", errors="replace") if (out/"godot.log").exists() else ""
            if "SCRIPT ERROR" in text or "Failed loading resource" in text or time.monotonic()>deadline:
                process.kill() # Only this diagnostic child.
                process.wait()
                break
    text = (out/"godot.log").read_text(encoding="utf-8")
    errors = [line for line in text.splitlines() if "SCRIPT ERROR" in line or "Failed loading resource" in line or
              ("ERROR:" in line and "resources still in use at exit" not in line)]
    if process.returncode or errors or "VO BUDGET DONE: 0 problem(s)" not in text:
        (out/"INVALID.txt").write_text("Inspect godot.log; not accepted budget evidence\n")
        raise RuntimeError("Budget record failed: " + str(out))
    data = load_terrain_report(out/"report.json", noise=args.trial=="noise",lighting=args.trial=="lighting") if args.trial else load_report(out/"report.json")
    if not args.headless and data["renderer"] != args.renderer:
        raise ValueError("Unexpected renderer fallback")
    print("Validated " + str(out/"report.json"), flush=True)


def generate(args):
    profiles = {}
    provenance = []
    lines = ["<!-- Generated explicitly by tools/vo_budget.py; never refreshed by tests. -->", "# Measured budgets (011)", "",
             "The hardware requirements are unchanged. The Galaxy A71 is a near-minimum test device, not a new specification.",
             "007's original-phone recovery remains open; its missing measurements are not treated as passes.", "",
             "## Frame targets and art headroom", "",
             "| Hardware class | Goal | Frame interval | Work target (20% reserve) |", "|---|---:|---:|---:|",
             "| Snapdragon 660 class | 30 fps | 33.333 ms | 26.667 ms |",
             "| Snapdragon 865 class | 60 fps | 16.667 ms | 13.333 ms |",
             "| PC | 60 fps | 16.667 ms | 13.333 ms |", "",
             "These are goals, not measured guarantees. GPU and CPU timers overlap and must not be summed.",
             "The prior razr 2024 outdoor GPU times are already near/exceed the 30-fps work allowance; no net outdoor art-cost growth is authorized by this ledger.",
             "A71 Mobile/Vulkan produced a device-loss crash; its Compatibility trial is tracked separately, not passed off as a Mobile result.", "",
             "## Headless structural regression ceilings", "",
             "The guard counts the entire fixture subtree, including hidden geometry, base-LOD triangles and full batch/particle capacity.",
             "Dummy RenderingServer does not preserve usable MultiMesh transforms/bounds. These limits therefore do not claim in-view draws or GPU cost.",
             "Ceilings use a 5% count tolerance for regression noise; this is not extra rendering headroom or permission to expand art cost.",
             "Texture MiB means declared RGBA8-equivalent with a full mip chain, deduplicated by texture resource, not actual compression/residency.", "",
             "| Profile / scene | Geometry nodes | Surface submissions | Base source triangles | Materials | Transparent-source surfaces | Texture equivalent MiB |",
             "|---|---:|---:|---:|---:|---:|---:|"]
    for profile, filename in [("desktop16x9", args.desktop), ("touch20x9", args.touch_report)]:
        path = Path(filename)
        data = load_report(path)
        scenes = data["passes"][0]["segments"]
        profiles[profile] = {}
        for scene, segment in sorted(scenes.items()):
            if any(not s["source"]["scope"].startswith("whole subtree") for s in segment["samples"]):
                raise ValueError("Expected headless whole-subtree baseline")
            maxima = {k:max(s["source"][k] for s in segment["samples"]) for k in METRICS}
            cap = {k:math.ceil(value*1.05) for k,value in maxima.items()}
            profiles[profile][scene] = cap
            lines.append(f"| {profile} / {scene} | {cap['geometry_nodes']} | {cap['surface_submissions']} | {cap['source_triangles']} | {cap['distinct_materials']} | {cap['transparent_surfaces']} | {cap['texture_rgba8_mip_bytes']/1048576:.2f} |")
        provenance.append({"profile":profile,"path":path.resolve().relative_to(ROOT).as_posix(),"sha256":hashlib.sha256(path.read_bytes()).hexdigest()})
    lines += ["", "## Rendered scene evidence", "",
              "Static settled start/midpoint/end holds, 120 frames each, Mid/720p. Desktop Mobile remains desktop evidence.",
              "Draws/primitives are renderer totals. Materials/transparent surfaces are conservative source/frustum estimates, not transparent-pass counters.",
              "Texture memory is RenderingServer's process/cache counter at the snapshot, not incremental scene residency; zero means unavailable.", "",
              "| Renderer / scene | Max median draws | Max median primitives | Max visible source materials | Max transparent-source surfaces | Max texture counter MiB | Max median GPU ms | Max p95 frame ms |",
              "|---|---:|---:|---:|---:|---:|---:|---:|"]
    for filename in args.rendered:
        path = Path(filename)
        data = load_report(path)
        for scene, segment in sorted(data["passes"][0]["segments"].items()):
            samples = segment["samples"]
            if any(not s["rendered"] for s in samples):
                raise ValueError("Rendered evidence contains no render samples")
            def peak(metric, stat="median"):
                return max(s["rendered"]["summary"][metric][stat] for s in samples)
            memory = max(s.get("texture_memory_bytes",0) for s in samples)
            lines.append(f"| {data['renderer']} / {scene} | {peak('draw_calls'):.1f} | {peak('primitives'):.0f} | {max(s['source']['distinct_materials'] for s in samples)} | {max(s['source']['transparent_surfaces'] for s in samples)} | {memory/1048576:.2f} | {peak('gpu_ms'):.3f} | {peak('frame_ms','p95'):.3f} |")
        provenance.append({"renderer":data["renderer"],"path":path.resolve().relative_to(ROOT).as_posix(),"sha256":hashlib.sha256(path.read_bytes()).hexdigest()})
    lines += ["", "## Use in later overhaul steps", "",
              "Every later step must cite this file and its scene/profile. Run vo-budget and vo-budget-touch after structural changes.",
              "Re-measure actual GPU/frame/pacing on the target device before accepting visual growth. A passing headless guard does not certify fps, memory residency, shadow cost, loading, free-play AI or untested shots.",
              "Never regenerate limits to make a failing test pass without reviewing the changed workload and updating its evidence.", "",
              "Detailed renderer-export verification, A71 stability and unresolved evidence are recorded in ../011-budgets.md.", "",
              "## Provenance", "", *[f"- `{p['path']}` — SHA256 `{p['sha256']}`" for p in provenance], ""]
    LEDGER.mkdir(exist_ok=True, parents=True)
    (LEDGER/"budgets.json").write_text(json.dumps({"schema":1,"tolerance":.05,"scope":"headless whole-subtree source capacity","profiles":profiles,"provenance":provenance},indent=2)+"\n")
    (LEDGER/"budgets.md").write_text("\n".join(lines),encoding="utf-8")
    print("Generated reviewed-candidate budgets.md / budgets.json",flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    rec = sub.add_parser("record")
    rec.add_argument("--attempt",required=True)
    rec.add_argument("--headless",action="store_true")
    rec.add_argument("--touch",action="store_true")
    rec.add_argument("--trial",choices=["terrain","noise","lighting"],default="")
    rec.add_argument("--renderer",choices=["forward_plus","mobile","gl_compatibility"],default="forward_plus")
    rec.add_argument("--godot",default="C:/Program Files/Godot/Godot_v4.7-stable_win64.exe")
    gen = sub.add_parser("generate")
    gen.add_argument("--desktop",required=True)
    gen.add_argument("--touch-report",required=True)
    gen.add_argument("--rendered",nargs="*",default=[])
    args = parser.parse_args()
    record(args) if args.action == "record" else generate(args)
