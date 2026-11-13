"""Isolated one-pass scene profile on a physical phone, with explicit renderer/quality."""
import argparse
from pathlib import Path
from look import model_lock
import vo_phone as phone
import vo_phone_sweep as sweep
from vo_budget import load_report, load_terrain_report
from vo_shadow_sweep import validate_segment
from vo_alpha import summarize as summarize_alpha
import json


def configure(args):
    if not args.tag or not all(c.isalnum() or c in "_-" for c in args.tag):
        raise ValueError("Use a new plain --tag for each experiment")
    sweep.configure(args.tag)
    phone.TARGET_PASSES = 6 if args.trial else (3 if args.scene == "alpha-film" or args.terrain_ab or args.noise_ab or args.lighting_ab else 1)
    phone.RUN_METADATA = {"quality":args.quality,"render_height":args.height,"expected_renderer":args.renderer,
                          "passes_target":phone.TARGET_PASSES,"scene":args.scene,"no_msaa":args.no_msaa,"no_shadows":args.no_shadows,"no_glow":args.no_glow}
    relative=phone.BENCH_REL
    phone.EXTRA_ARGS=(f"-- --scene=vo-budget --record=1 --graphics_quality={args.quality} --render_height={args.height} "
                      f"--report=user://{relative}/report.json --shots=user://{relative}/shots --shot_w=0 "
                      f"--save_dir=user://{relative}/saves/ --prefs_path=user://{relative}/settings.cfg")
    if args.scene == "alpha-film":
        phone.EXTRA_ARGS = phone.EXTRA_ARGS.replace("--scene=vo-budget --record=1", "--scene=vo-alpha --part=film")
    if args.trial:
        phone.EXTRA_ARGS += " --trial=suite"
    if args.no_msaa:
        phone.EXTRA_ARGS += " --diag_msaa=0"
    if args.no_shadows:
        phone.EXTRA_ARGS += " --shadow_sweep=off"
    if args.no_glow:
        phone.EXTRA_ARGS += " --diag_glow=0"
    if args.coastal_only:
        phone.EXTRA_ARGS += " --part=coastal"
    if args.terrain_ab:
        phone.EXTRA_ARGS += " --trial=terrain"
    if args.noise_ab:
        phone.EXTRA_ARGS += " --trial=noise"
    if args.lighting_ab:
        phone.EXTRA_ARGS += " --trial=lighting"


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action",choices=["export","run"])
    parser.add_argument("--tag",required=True)
    parser.add_argument("--renderer",choices=["mobile","gl_compatibility"],default="mobile")
    parser.add_argument("--quality",choices=["min","mid","max"],default="min")
    parser.add_argument("--height",type=int,choices=[540,720,1080],default=540)
    parser.add_argument("--serial",required=True)
    parser.add_argument("--attach",action="store_true")
    parser.add_argument("--scene",choices=["budget","alpha-film"],default="budget")
    parser.add_argument("--trial",action="store_true",help="Isolated baseline/foliage-hidden/terrain-hidden/unshaded/LOD4/baseline GPU attribution; no production changes")
    parser.add_argument("--no-msaa",action="store_true",help="Diagnostic override only; isolate MSAA-related device loss")
    parser.add_argument("--no-shadows",action="store_true",help="Diagnostic override only; isolate shadow-related device loss")
    parser.add_argument("--no-glow",action="store_true",help="Diagnostic override only; isolate glow-related device loss")
    parser.add_argument("--coastal-only",action="store_true",help="Three settled Coastal snapshots instead of the full route")
    parser.add_argument("--terrain-ab",action="store_true",help="Original/optimized/original terrain shader, identical scene and formulas")
    parser.add_argument("--noise-ab",action="store_true",help="Diagnostic analytic/lookup/analytic noise; changes noise placement, not adopted")
    parser.add_argument("--lighting-ab",action="store_true",help="Diagnostic pixel/vertex/pixel lighting; not a production preset change")
    parser.add_argument("--display",default="")
    parser.add_argument("--godot",default="C:/Program Files/Godot/Godot_v4.7-stable_win64.exe")
    parser.add_argument("--sdk",default=str(phone.ROOT/"build/tools/android"))
    parser.add_argument("--java",default="C:/Program Files/Eclipse Adoptium/jdk-17.0.20.101-hotspot")
    args=parser.parse_args()
    if sum([args.trial,args.terrain_ab,args.noise_ab,args.lighting_ab])>1:raise ValueError("Choose one trial")
    if args.scene == "alpha-film" and (args.trial or args.coastal_only or args.no_msaa or args.no_shadows or args.no_glow or args.terrain_ab or args.noise_ab or args.lighting_ab):
        raise ValueError("Alpha-film uses the selected preset unchanged; isolate overrides in budget diagnostics")
    configure(args)
    if args.action=="export":
        with model_lock(timeout=3600):phone.export(args,renderer=args.renderer)
    else:
        sweep.run(args)
        if args.scene == "alpha-film":
            summarize_alpha(phone.OUT/"report.json")
            raise SystemExit(0)
        data=load_terrain_report(phone.OUT/"report.json",noise=args.noise_ab,lighting=args.lighting_ab) if args.terrain_ab or args.noise_ab or args.lighting_ab else (json.loads((phone.OUT/"report.json").read_text()) if args.trial else load_report(phone.OUT/"report.json", {"coastal_path"} if args.coastal_only else None))
        if data["renderer"]!=args.renderer:raise ValueError("Renderer fallback")
        if args.trial and (data['problems'] or data['focus_losses'] or len(data['passes'])!=6):raise ValueError("Interrupted GPU trial")
        if args.trial:
            experiments=[p['segments']['coastal_path']['experiment'] for p in data['passes']]
            if [e['trial'] for e in experiments]!=['none','scenery_off','terrain_off','unshaded','lod4','none']:
                raise ValueError("GPU trial sequence changed")
            if any(e['visible_foliage_before_mask']!=experiments[0]['visible_foliage_before_mask'] for e in experiments):
                raise ValueError("Cached visibility leaked between GPU trials")
        for i,batch in enumerate(data['passes']):
            for scene,segment in batch['segments'].items():
                for sample in segment['samples']:validate_segment(sample['rendered'])
                print(i,scene,segment.get('experiment',{}),[{k:s['rendered']['summary'][k]['median'] for k in ['frame_ms','gpu_ms','draw_calls']} for s in segment['samples']],flush=True)
