"""Copy the input prompts the game uses out of Kenney's Input Prompts pack (CC0) into assets/ui/input_prompts/.

Usage: python tools/input_prompts/build.py "path/to/kenney_input-prompts_1.5"
Then: godot --headless --path . --import  (the .import files set each icon's SVG scale; see SCALES below)

Only the Vector SVGs are used, so the pad stays crisp at any size. Besides plain copies it writes:
- <name>_solid.svg for every pad button: just its outer shape with the lettering filled in, which the pad's
  shader (scripts/ui/prompt_tint.gdshader) uses to colour the letter separately from the button.
- xbox_button_pause.svg (and _outline, _solid): the Xbox START pill with the PAUSE lettering of the keyboard's
  Pause key, so the touch pad's Pause button matches its Start button.
"""
import os
import re
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, 'assets', 'ui', 'input_prompts')

DIRS = ['up', 'down', 'left', 'right']
ICONS = {
    'Xbox Series': ['xbox_dpad', 'xbox_dpad_none'] + ['xbox_dpad_' + d for d in DIRS] + ['xbox_dpad_%s_outline' % d for d in DIRS]
    + [b + v for b in ['xbox_button_a', 'xbox_button_b', 'xbox_button_start', 'xbox_button_back', 'xbox_button_menu',
                       'xbox_button_view'] for v in ['', '_outline']],
    'PlayStation Series': ['playstation_dpad_none'] + ['playstation_dpad_%s_outline' % d for d in DIRS]
    + [b + v for b in ['playstation_button_cross', 'playstation_button_circle', 'playstation5_button_options',
                       'playstation5_button_create', 'playstation4_button_options', 'playstation4_button_share',
                       'playstation3_button_start', 'playstation3_button_select'] for v in ['', '_outline']],
    'Nintendo Switch': ['switch_dpad_none'] + ['switch_dpad_%s_outline' % d for d in DIRS]
    + [b + v for b in ['switch_button_a', 'switch_button_b', 'switch_button_plus', 'switch_button_minus']
       for v in ['', '_outline']],
    'Keyboard & Mouse': [k + v for k in ['keyboard_a', 'keyboard_s', 'keyboard_space', 'keyboard_shift', 'keyboard_escape']
                         + ['keyboard_arrow_' + d for d in DIRS] for v in ['', '_outline']],
}
## the touch pad's own buttons, which get a _solid copy for the shader
SOLIDS = ['xbox_button_a', 'xbox_button_b', 'xbox_button_start', 'xbox_button_pause']

PATH_RE = re.compile(r'(<path [^>]*\bd=")([^"]*)(")')


def subpaths(d):
    return [p.strip() for p in re.split(r'(?=M)', d) if p.strip()]


def bbox(sub):
    nums = [float(n) for n in re.findall(r'-?\d+(?:\.\d+)?', sub)]
    xs, ys = nums[0::2], nums[1::2]
    return min(xs), min(ys), max(xs), max(ys)


def area(sub):
    x0, y0, x1, y1 = bbox(sub)
    return (x1 - x0) * (y1 - y0)


def read(path):
    return open(path, encoding='utf-8').read()


def with_d(svg, d, evenodd=True):
    rule = ' fill-rule="evenodd"' if evenodd else ''
    return PATH_RE.sub(lambda m: m.group(1)[:-3] + rule + ' d="' + d + m.group(3), svg, count=1)


def path_d(svg):
    return PATH_RE.search(svg).group(2)


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    pack = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)
    for family, names in ICONS.items():
        for name in names:
            src = os.path.join(pack, family, 'Vector', name + '.svg')
            if not os.path.isfile(src):
                sys.exit('missing in the pack: ' + src)
            shutil.copy(src, os.path.join(OUT, name + '.svg'))
    # Pause: the START pill's outer shape (and, outlined, its ring) with the Pause key's lettering, which sits in the
    # same place on its key (x 15..49, y 27..37) as START does on its pill.
    vec = lambda fam, n: read(os.path.join(pack, fam, 'Vector', n + '.svg'))
    for variant in ['', '_outline']:
        start = vec('Xbox Series', 'xbox_button_start' + variant)
        key = vec('Keyboard & Mouse', 'keyboard_pause' + variant)
        letters = [s for s in subpaths(path_d(key)) if bbox(s)[1] >= 20 and bbox(s)[3] <= 44]
        shell = [s for s in subpaths(path_d(start)) if not (bbox(s)[1] >= 20 and bbox(s)[3] <= 44)]
        open(os.path.join(OUT, 'xbox_button_pause' + variant + '.svg'), 'w', encoding='utf-8').write(
            with_d(start, ' '.join(shell + letters)))
    # Solid copies: only the largest subpath (the button's outline), so the lettering is filled in.
    for name in SOLIDS:
        svg = read(os.path.join(OUT, name + '.svg'))
        outer = max(subpaths(path_d(svg)), key=area)
        open(os.path.join(OUT, name + '_solid.svg'), 'w', encoding='utf-8').write(with_d(svg, outer, evenodd=False))
    shutil.copy(os.path.join(pack, 'License.txt'), os.path.join(ROOT, 'licenses', 'Kenney Input Prompts - License.txt'))
    print('wrote', len(os.listdir(OUT)), 'files to', OUT)


if __name__ == '__main__':
    main()
