"""Makes game-ready copies of the music in music/ (128 kbps, long tracks trimmed to a loop).

The originals in music/ are left untouched; the game plays the copies in assets/audio/music/.
Needs ffmpeg on PATH.  Run from the project root:  python tools/convert_audio.py
Approved Sonniss effects: python tools/convert_audio.py --sfx-pack /path/to/bundle
"""
import argparse
import hashlib
import json
import os
import re
import subprocess
from pathlib import Path

SRC = 'music'
DST = 'assets/audio/music'
MAX_SECONDS = 300  # longer tracks are cut to 5 minutes with a gentle fade so they loop smoothly
FADE = 4


def slug(name):
    base = os.path.splitext(name)[0].lower()
    base = re.sub(r'[^a-z0-9]+', '_', base).strip('_')
    return base


def duration(path):
    out = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', path],
                         capture_output=True, text=True).stdout.strip()
    return float(out or 0)


def convert_effects(pack):
    root = Path(__file__).resolve().parent.parent
    manifest = json.loads((root / 'tools/sfx_sources.json').read_text(encoding='utf-8'))
    dst_dir = root / 'assets/audio/sfx'
    dst_dir.mkdir(parents=True, exist_ok=True)
    for effect in manifest:
        source_base = {'pack': Path(pack), 'project': root}[effect.get('source_root', 'pack')]
        src = source_base / effect['source']
        if hashlib.sha256(src.read_bytes()).hexdigest() != effect['source_sha256']:
            raise ValueError('Source differs from the approved recording: %s' % src)
        dst = dst_dir / effect['file']
        # Match the approved previews, including any excerpt and edge fades.
        filters = effect.get('edit_filters', []) + ['volume=%sdB' % effect['gain_db']]
        subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', str(src), '-map', '0:a:0',
                        '-vn', '-map_metadata', '-1', '-af', ','.join(filters),
                        '-ar', '44100', '-ac', '2', '-c:a', 'libvorbis', '-q:a', '5', str(dst)], check=True)
        print('%-30s %9d -> %7d bytes' % (effect['file'], src.stat().st_size, dst.stat().st_size))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sfx-pack', help='Convert only the approved effects from this source bundle')
    args = parser.parse_args()
    if args.sfx_pack:
        convert_effects(args.sfx_pack)
        return
    os.makedirs(DST, exist_ok=True)
    for f in sorted(os.listdir(SRC)):
        if not f.lower().endswith('.mp3'):
            continue
        src = os.path.join(SRC, f)
        dst = os.path.join(DST, slug(f) + '.mp3')
        if os.path.exists(dst) and os.path.getmtime(dst) >= os.path.getmtime(src):
            continue
        dur = duration(src)
        args = ['ffmpeg', '-y', '-v', 'error', '-i', src, '-vn', '-map_metadata', '-1', '-b:a', '128k', '-ar', '44100']
        if dur > MAX_SECONDS + 30:
            args += ['-t', str(MAX_SECONDS), '-af', 'afade=t=in:d=%d,afade=t=out:st=%d:d=%d' % (FADE, MAX_SECONDS - FADE, FADE)]
        subprocess.run(args + [dst], check=True)
        print('%-60s %6.1f MB -> %5.1f MB' % (f, os.path.getsize(src) / 1e6, os.path.getsize(dst) / 1e6))


if __name__ == '__main__':
    main()
