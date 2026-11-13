"""Separate step 009b Web loading evidence; preserves step 003's export/report.

python tools/vo_web_firstvisit.py export --attempt before
python tools/vo_web_firstvisit.py serve --attempt before
Then open http://127.0.0.1:8062/?vo_perf=1 in the in-app browser.
Serving holds the shared resource lock and exits after receiving a report.
"""
import argparse
import json
import re
import time
import vo_web
from look import model_lock


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['export', 'serve'])
    parser.add_argument('--attempt', required=True)
    parser.add_argument('--shared-warmup', action='store_true', help='opt-in exact-material/geometry-format experiment')
    parser.add_argument('--precompile', action='store_true', help='title shader precompile after the title script wait')
    parser.add_argument('--godot', default='C:/Program Files/Godot/Godot_v4.7-stable_win64.exe')
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9_-]+', args.attempt):
        parser.error('Expected a plain attempt name')
    vo_web.WEB = vo_web.ROOT / f'build/web_perf_009b_{args.attempt}'
    vo_web.OUT = vo_web.ROOT / f'build/perf/vo/009b/web-{args.attempt}'
    vo_web.BENCH_REL = f'bench/vo/009b/web-{args.attempt}'
    vo_web.EXTRA_ARGS = ['--load_only=1', '--load_phases=1', '--diagnose=1', '--title_ready=1']
    if args.shared_warmup:
        vo_web.EXTRA_ARGS.append('--warmup_shared=1')
    if args.precompile:
        vo_web.EXTRA_ARGS.append('--precompile=1')
    report = vo_web.OUT / 'report.json'
    if report.exists():
        raise FileExistsError('Preserve existing evidence; choose a new attempt')
    with model_lock(timeout=3600):
        if args.command == 'export':
            if (vo_web.WEB / 'index.html').exists():
                raise FileExistsError('Export exists; choose a new attempt')
            vo_web.export(args.godot)
            return
        if not (vo_web.WEB / 'index.html').exists():
            raise FileNotFoundError('Export this attempt first')
        deadline = time.monotonic() + 600
        # Sequential requests avoid racing report writes. Asset fetching remains local.
        from http.server import HTTPServer
        with HTTPServer(('127.0.0.1', 8062), vo_web.Handler) as server:
            server.timeout = 1
            print('Resource lock held; open http://127.0.0.1:8062/?vo_perf=1', flush=True)
            while time.monotonic() < deadline:
                server.handle_request()
                if report.exists():
                    latest = json.loads(report.read_text(encoding='utf-8'))
                    # The harness checkpoints after each pass, then sends the final report again.
                    if latest.get('problems') or len(latest.get('passes', [])) >= 2:
                        break
        if not report.exists():
            raise TimeoutError('No report received within ten minutes')
        data = json.loads(report.read_text(encoding='utf-8'))
        if data.get('problems') or data.get('focus_losses') or len(data.get('passes', [])) != 2:
            raise RuntimeError('Web run rejected; retained report requires inspection')
        assert data['loading_only'] and data['title_script_ready']
        for batch in data['passes']:
            assert not batch['focus_losses'] and not batch['segments']
            assert [t['map'] for t in batch['transitions']] == ['route1', 'caccoon', 'caccoon#1', 'tidewater']
        print('Two Web loading passes collected; inspect browser errors separately', flush=True)


if __name__ == '__main__':
    main()
