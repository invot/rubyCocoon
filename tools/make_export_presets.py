"""Writes export_presets.cfg with the Android and Web presets.

Both leave out everything the game never loads:
  - sound effects that scripts/autoload/sfx.gd doesn't reference,
  - voxel models (scripts/data/voxel_manifest.gd) that no script names,
  - the full-resolution copy of each model that has a half-resolution _lo version (voxel_assets.gd only ever
    loads the _lo one),
  - the original music/ folder and the raw UI kits (the game uses the converted copies in assets/).
The Web preset also leaves out the music: in the browser each track is downloaded when it's first needed (see
Sfx._web_music and tools/make_web.py), so the game itself starts after a much smaller download.
Run from the project root:  python tools/make_export_presets.py
"""
import glob
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def rel(path):
    return os.path.relpath(path, ROOT).replace('\\', '/')


def unused_sfx():
    code = open(os.path.join(ROOT, 'scripts/autoload/sfx.gd'), encoding='utf-8').read()
    used = set(re.findall(r'res://(sfx/[^"]+)', code))
    out = []
    for dp, dn, fn in os.walk(os.path.join(ROOT, 'sfx')):
        for f in fn:
            r = rel(os.path.join(dp, f))
            if not f.endswith('.import') and r not in used:
                out.append(r)
    return used, sorted(out)


def unused_models():
    """Model files no script loads. Model names only ever appear as string literals (biome lists, races, story
    NPCs, buildings), so a model whose name is never quoted in a script is never used."""
    man = open(os.path.join(ROOT, 'scripts/data/voxel_manifest.gd'), encoding='utf-8').read()
    assets = dict(re.findall(r'"([^"]+)": "res://([^"]+)"', man))
    code = ''
    for f in glob.glob(os.path.join(ROOT, 'scripts/**/*.gd'), recursive=True):
        if not f.endswith('voxel_manifest.gd'):
            code += open(f, encoding='utf-8').read()
    quoted = set(re.findall(r'"([A-Za-z0-9_]+)"', code))
    out = []
    for name, path in sorted(assets.items()):
        if name not in quoted:
            out.append(path)
    return len(assets), out


COMMON = ['music/*', 'ui/Complete_UI_Book_Styles_Pack_Free_v1.0/*', 'ui/DEMO_Fantasy_RPG_UI_doboui/*',
          'ui/set1/*', 'ui/set2/*', 'ui/seamless patterns/*', 'tools/*', 'build/*']

# iPhone home-screen support: full-screen launch and the page colour (Godot adds the apple-touch-icon link itself;
# tools/make_web.py swaps in a square icon and writes the manifest)
WEB_HEAD = ('<meta name="apple-mobile-web-app-capable" content="yes">'
            '<meta name="mobile-web-app-capable" content="yes">'
            '<meta name="apple-mobile-web-app-title" content="Ruby Cocoon">'
            '<meta name="theme-color" content="#2f2424">'
            '<link rel="manifest" href="manifest.webmanifest">')

HEADER = '''[preset.%(i)d]

name="%(name)s"
platform="%(name)s"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter="assets/ui/ui_manifest.json"
exclude_filter="%(exclude)s"
export_path="%(path)s"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.%(i)d.options]

'''

ANDROID = '''custom_template/debug=""
custom_template/release=""
gradle_build/use_gradle_build=false
gradle_build/gradle_build_directory=""
gradle_build/android_source_template=""
gradle_build/compress_native_libraries=false
gradle_build/export_format=0
gradle_build/min_sdk=""
gradle_build/target_sdk=""
architectures/armeabi-v7a=false
architectures/arm64-v8a=true
architectures/x86=false
architectures/x86_64=false
version/code=1
version/name="0.1.0"
package/unique_name="com.rubycocoon.game"
package/name="Ruby Cocoon"
package/signed=true
package/app_category=2
package/retain_data_on_uninstall=false
package/exclude_from_recents=false
package/show_in_android_tv=false
package/show_in_app_library=true
package/show_as_launcher_app=false
launcher_icons/main_192x192="res://assets/icon/icon_main.png"
launcher_icons/adaptive_foreground_432x432="res://assets/icon/icon_foreground.png"
launcher_icons/adaptive_background_432x432="res://assets/icon/icon_background.png"
launcher_icons/adaptive_monochrome_432x432="res://assets/icon/icon_monochrome.png"
graphics/opengl_debug=false
xr_features/xr_mode=0
screen/immersive_mode=true
screen/support_small=true
screen/support_normal=true
screen/support_large=true
screen/support_xlarge=true
user_data_backup/allow=false
command_line/extra_args=""
apk_expansion/enable=false
apk_expansion/SALT=""
apk_expansion/public_key=""
permissions/custom_permissions=PackedStringArray()
'''

WEB = '''custom_template/debug=""
custom_template/release=""
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=true
html/export_icon=true
html/custom_html_shell=""
html/head_include="%(head)s"
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=false
progressive_web_app/enabled=false
progressive_web_app/ensure_cross_origin_isolation_headers=true
progressive_web_app/offline_page=""
progressive_web_app/display=1
progressive_web_app/orientation=0
progressive_web_app/icon_144x144=""
progressive_web_app/icon_180x180=""
progressive_web_app/icon_512x512=""
progressive_web_app/background_color=Color(0, 0, 0, 1)
threads/emscripten_pool_size=8
threads/godot_pool_size=4
'''


def main():
    used, sfx = unused_sfx()
    n_models, models = unused_models()
    common = COMMON + sfx + models
    out = HEADER % {'i': 0, 'name': 'Android', 'exclude': ', '.join(common), 'path': 'build/android/RubyCocoon-debug.apk'} + ANDROID
    out += '\n' + HEADER % {'i': 1, 'name': 'Web', 'exclude': ', '.join(common + ['assets/audio/music/*']),
                           'path': 'build/web/index.html'} + WEB % {'head': WEB_HEAD.replace('"', '\\"')}
    with open(os.path.join(ROOT, 'export_presets.cfg'), 'w', encoding='utf-8') as f:
        f.write(out)
    print('export_presets.cfg written: %d sfx used (%d left out), %d of %d model files left out'
          % (len(used), len(sfx), len(models), n_models))


if __name__ == '__main__':
    main()
