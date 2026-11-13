"""Isolated one-pass scene profile on a physical phone, with explicit renderer/quality."""
import argparse
from pathlib import Path
from look import model_lock
import vo_phone as phone
import vo_phone_sweep as sweep
from vo_budget import load_report
from vo_shadow_sweep import validate_segment
import json


def configure(args):
    if not args.tag or not all(c.isalnum() or c in "_-" for c in args.tag):
        raise ValueError("Use a new plain --tag for each experiment")
    sweep.configure(args.tag)
    phone.TARGET_PASSES = 5 if args.trial else 1
    phone.RUN_METADATA = {"quality":args.quality,"render_height":args.height,"expected_renderer":args.renderer,"passes_target":1}
    relative=phone.BENCH_REL
    phone.EXTRA_ARGS=(f"-- --scene=vo-budget --record=1 --graphics_quality={args.quality} --render_height={args.height} "
                      f"--report=user://{relative}/report.json --shots=user://{relative}/shots --shot_w=0 "
                      f"--save_dir=user://{relative}/saves/ --prefs_path=user://{relative}/settings.cfg")
    if args.trial:
        phone.EXTRA_ARGS += " --trial=suite"


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action",choices=["export","run"])
    parser.add_argument("--tag",required=True)
    parser.add_argument("--renderer",choices=["mobile","gl_compatibility"],default="mobile")
    parser.add_argument("--quality",choices=["min","mid","max"],default="min")
    parser.add_argument("--height",type=int,choices=[540,720,1080],default=540)
    parser.add_argument("--serial",required=True)
    parser.add_argument("--attach",action="store_true")
    parser.add_argument("--trial",action="store_true",help="Isolated baseline/foliage-hidden/unshaded/LOD4/baseline GPU attribution; no production changes")
    parser.add_argument("--display",default="")
    parser.add_argument("--godot",default="C:/Program Files/Godot/Godot_v4.7-stable_win64.exe")
    parser.add_argument("--sdk",default=str(phone.ROOT/"build/tools/android"))
    parser.add_argument("--java",default="C:/Program Files/Eclipse Adoptium/jdk-17.0.20.101-hotspot")
    args=parser.parse_args()
    configure(args)
    if args.action=="export":
        with model_lock(timeout=3600):phone.export(args,renderer=args.renderer)
    else:
        sweep.run(args)
        data=json.loads((phone.OUT/"report.json").read_text()) if args.trial else load_report(phone.OUT/"report.json")
        if data["renderer"]!=args.renderer:raise ValueError("Renderer fallback")
        if args.trial and (data['problems'] or data['focus_losses'] or len(data['passes'])!=5):raise ValueError("Interrupted GPU trial")
        for i,batch in enumerate(data['passes']):
            for scene,segment in batch['segments'].items():
                for sample in segment['samples']:validate_segment(sample['rendered'])
                print(i,scene,segment.get('experiment',{}),[{k:s['rendered']['summary'][k]['median'] for k in ['frame_ms','gpu_ms','draw_calls']} for s in segment['samples']],flush=True)
