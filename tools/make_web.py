"""Builds the web version into build/web/, ready to upload to Cloudflare Pages as it is.

  1. Exports the "Web" preset (tools/make_export_presets.py) into build/web_export/.
  2. Gzips the engine (index.wasm) and the game data (index.pck) and stores them as parts under data/, named by
     their content hash and split to stay under Cloudflare Pages' 25 MiB-per-file limit. A small script added to
     index.html stitches the parts back together and unzips them in the browser when Godot's loader asks for the
     files, so the player downloads about a third of the bytes.
  3. Encodes the music as small Ogg Vorbis files under music/; the game fetches each track the first time it's
     needed (Sfx._web_music) instead of making the player download all of it up front.
  4. Adds the square home-screen icon, a web app manifest and Cloudflare's _headers (long caching for the hashed
     parts and the music).

Needs Godot's web export templates and ffmpeg on PATH. Run from the project root:  python tools/make_web.py
Then upload build/web/ (Cloudflare dashboard > Workers & Pages > Create > Pages > Upload assets), or run
  npx wrangler pages deploy build/web --project-name ruby-cocoon
"""
import gzip
import hashlib
import json
import os
import shutil
import subprocess

from PIL import Image

GODOT = r'C:\Program Files\Godot\Godot_v4.7-stable_win64.exe'
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXPORT = os.path.join(ROOT, 'build', 'web_export')
OUT = os.path.join(ROOT, 'build', 'web')
MUSIC_SRC = os.path.join(ROOT, 'assets', 'audio', 'music')
MUSIC_CACHE = os.path.join(ROOT, 'build', 'web_music')
PART = 24 * 1024 * 1024
PACKED = {'index.wasm': 'application/wasm', 'index.pck': 'application/octet-stream'}

SHIM = '''<script>
// Ruby Cocoon (tools/make_web.py): index.wasm and index.pck are stored gzipped, in parts under data/. When Godot's
// loader fetches them, fetch the parts, join them and unzip them on the fly.
(function () {
	const PACKED = %s;
	const realFetch = window.fetch.bind(window);
	window.fetch = function (input, init) {
		const url = typeof input === 'string' ? input : input.url;
		const p = PACKED[url.split('?')[0].split('/').pop()];
		if (!p) {
			return realFetch(input, init);
		}
		if (typeof DecompressionStream === 'undefined') {
			return Promise.reject(new Error('This browser is too old to run Ruby Cocoon. Please update it (iOS 16.4 / Safari 16.4 or newer).'));
		}
		const parts = p.parts.map(function (u) { return realFetch(u); });
		let i = 0;
		const joined = new ReadableStream({
			async pull(controller) {
				try {
					if (i >= parts.length) {
						controller.close();
						return;
					}
					const r = await parts[i++];
					if (!r.ok) {
						throw new Error('Failed loading ' + r.url);
					}
					const reader = r.body.getReader();
					for (;;) {
						const chunk = await reader.read();
						if (chunk.done) {
							break;
						}
						controller.enqueue(chunk.value);
					}
				} catch (e) {
					controller.error(e);
				}
			},
		});
		const body = joined.pipeThrough(new DecompressionStream('gzip'));
		return Promise.resolve(new Response(body, { status: 200, headers: { 'Content-Type': p.type, 'Content-Length': String(p.size) } }));
	};
}());
</script>
'''

HEADERS = '''/data/*
  Cache-Control: public, max-age=31536000, immutable
/music/*
  Cache-Control: public, max-age=604800
/index.html
  Cache-Control: no-cache
/
  Cache-Control: no-cache
'''


def export():
    shutil.rmtree(EXPORT, ignore_errors=True)
    os.makedirs(EXPORT)
    subprocess.run([GODOT, '--headless', '--path', ROOT, '--export-release', 'Web', os.path.join(EXPORT, 'index.html')], check=True)


def pack(name, packed):
    data = open(os.path.join(EXPORT, name), 'rb').read()
    gz = gzip.compress(data, 9, mtime=0)
    tag = hashlib.sha256(gz).hexdigest()[:12]
    parts = []
    for k in range(0, len(gz), PART):
        rel = 'data/%s.%s.%d.bin' % (name.replace('.', '-'), tag, k // PART)
        open(os.path.join(OUT, rel), 'wb').write(gz[k:k + PART])
        parts.append(rel)
    packed[name] = {'parts': parts, 'size': len(data), 'type': PACKED[name]}
    print('%-11s %5.1f MB -> %4.1f MB gzipped in %d part(s)' % (name, len(data) / 1e6, len(gz) / 1e6, len(parts)))
    return len(gz)


def music():
    """Ogg Vorbis copies of the music (about 64 kbps), encoded once and kept in build/web_music/."""
    os.makedirs(MUSIC_CACHE, exist_ok=True)
    total = 0
    for f in sorted(os.listdir(MUSIC_SRC)):
        if not f.endswith('.mp3'):
            continue
        src = os.path.join(MUSIC_SRC, f)
        dst = os.path.join(MUSIC_CACHE, f[:-4] + '.ogg')
        if not os.path.exists(dst) or os.path.getmtime(dst) < os.path.getmtime(src):
            subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', src, '-vn', '-map_metadata', '-1', '-c:a', 'libvorbis', '-q:a', '0', dst], check=True)
        total += os.path.getsize(dst)
    shutil.copytree(MUSIC_CACHE, os.path.join(OUT, 'music'))
    print('music       %d tracks, %.1f MB (each downloaded only when the game first plays it)' % (len(os.listdir(MUSIC_CACHE)), total / 1e6))


def icons():
    sq = Image.open(os.path.join(ROOT, 'assets', 'icon', 'icon_square.png')).convert('RGB')
    sq.resize((180, 180), Image.LANCZOS).save(os.path.join(OUT, 'index.apple-touch-icon.png'))
    sq.resize((192, 192), Image.LANCZOS).save(os.path.join(OUT, 'icon-192.png'))
    sq.save(os.path.join(OUT, 'icon-512.png'))
    manifest = {
        'name': 'Ruby Cocoon', 'short_name': 'Ruby Cocoon', 'start_url': './index.html', 'scope': './',
        'display': 'fullscreen', 'orientation': 'landscape', 'background_color': '#03041a', 'theme_color': '#03041a',
        'icons': [{'src': 'icon-192.png', 'sizes': '192x192', 'type': 'image/png'},
                  {'src': 'icon-512.png', 'sizes': '512x512', 'type': 'image/png'}],
    }
    open(os.path.join(OUT, 'manifest.webmanifest'), 'w', encoding='utf-8').write(json.dumps(manifest, indent=1))


def main():
    export()
    shutil.rmtree(OUT, ignore_errors=True)
    os.makedirs(os.path.join(OUT, 'data'))
    packed = {}
    first = sum(pack(n, packed) for n in PACKED)
    for f in os.listdir(EXPORT):
        if f not in PACKED:
            shutil.copy(os.path.join(EXPORT, f), os.path.join(OUT, f))
    html = open(os.path.join(OUT, 'index.html'), encoding='utf-8').read()
    html = html.replace('<script src="index.js"></script>', SHIM % json.dumps(packed) + '\t\t<script src="index.js"></script>', 1)
    assert 'realFetch' in html, 'could not add the loader script to index.html'
    open(os.path.join(OUT, 'index.html'), 'w', encoding='utf-8').write(html)
    music()
    icons()
    open(os.path.join(OUT, '_headers'), 'w', encoding='utf-8').write(HEADERS)
    biggest = max(os.path.getsize(os.path.join(dp, f)) for dp, dn, fn in os.walk(OUT) for f in fn)
    assert biggest <= 25 * 1024 * 1024, 'a file is over Cloudflare Pages\' 25 MiB limit'
    print('first load  %.1f MB; largest file %.1f MB; ready to upload: %s' % (first / 1e6, biggest / 1e6, OUT))


if __name__ == '__main__':
    main()
