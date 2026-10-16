"""Makes game-ready copies of the music in music/ (128 kbps, long tracks trimmed to a loop).

The originals in music/ are left untouched; the game plays the copies in assets/audio/music/.
Needs ffmpeg on PATH.  Run from the project root:  python tools/convert_audio.py
"""
import os
import re
import subprocess

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


def main():
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
