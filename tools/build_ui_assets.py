"""Builds the game's pixel-art UI textures in assets/ui/ from the kits in ui/.

* TravelBook (ui/Complete_UI_Book_Styles_Pack_Free_v1.0) and set1 are already pixel art: cropped and
  scaled up with nearest-neighbour so each art pixel is 3-4 screen pixels.
* doboui (ui/DEMO_Fantasy_RPG_UI_doboui) is smooth high-res art: it is pixelated (box-downscaled, hard
  alpha) and recoloured into the warm storybook palette of the TravelBook, then scaled up the same way.

Run from the project root:  python tools/build_ui_assets.py   (needs Pillow)
"""
import colorsys
import json
import os
from PIL import Image

UI = 'ui'
BOOK = UI + '/Complete_UI_Book_Styles_Pack_Free_v1.0/01_TravelBookLite'
BOOK_SHEET = BOOK + '/Spritesheet/UI_TravelBook_Spritesheet01a.png'
DOBO = UI + '/DEMO_Fantasy_RPG_UI_doboui'
SET1 = UI + '/set1'
OUT = 'assets/ui'

# ---- the warm storybook palette (sampled from the TravelBook) ----
P = {
    'outline': '#493333', 'ink': '#2f2424',
    'page': '#ffd7a8', 'page_hi': '#ffe3c6', 'page_shade': '#dea974', 'page_deep': '#c7895d', 'select': '#e5b67f',
    'cover': '#b75b5f', 'cover_dark': '#9c4351', 'cover_hi': '#d47a74',
    'gold': '#ffd071', 'orange': '#ffa34d', 'ember': '#e5673c',
    'slot_dark': '#381e1f', 'slot': '#45292a', 'slot_mid': '#634041', 'slot_hi': '#825f60',
    'frame': '#c6b09b', 'frame_dark': '#8a7868',
    'heart': '#d43e3e', 'leaf': '#7ca04a', 'sky': '#5a8ac0',
}
RAMPS = {
    # darkest -> lightest
    'parchment': ['outline', 'page_deep', 'page_shade', 'select', 'page', 'page_hi'],
    'maroon': ['outline', 'cover_dark', 'cover', 'cover_hi', 'gold', 'page_hi'],
    'brown': ['ink', 'slot_dark', 'slot', 'slot_mid', 'slot_hi', 'frame'],
    'gold': ['outline', 'ember', 'orange', 'gold', 'page_hi'],
    'pearl': ['outline', 'page_shade', 'page', 'page_hi'],
}

manifest = {}


def hexc(h):
    h = P.get(h, h).lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def scale(im, k):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def save(name, im, k, margins=None, note=''):
    os.makedirs(OUT, exist_ok=True)
    big = scale(im, k)
    big.save(os.path.join(OUT, name + '.png'))
    entry = {'size': [big.width, big.height], 'scale': k}
    if margins is not None:
        entry['margins'] = [m * k for m in margins]  # left, top, right, bottom in screen pixels
    manifest[name] = entry


def crop_sheet(path, box):
    return Image.open(path).convert('RGBA').crop(box)


def book(name):
    return Image.open('%s/Sprites/UI_TravelBook_%s.png' % (BOOK, name)).convert('RGBA')


def harden(im, threshold=110):
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255 if a >= threshold else 0)
    return im


def pixelate(path, art_w, art_h=None):
    src = Image.open(path).convert('RGBA')
    if art_h is None:
        art_h = max(1, round(src.height * art_w / src.width))
    # premultiply so transparent edges don't darken the colours
    small = src.resize((art_w, art_h), Image.BOX)
    return harden(small)


def lum(c):
    r, g, b = c[:3]
    return (0.299 * r + 0.587 * g + 0.114 * b) / 255.0


def recolor_ramp(im, ramp, gamma=1.0, bias=0.0):
    """Maps each pixel's (normalised) brightness onto a palette ramp."""
    cols = [hexc(c) for c in RAMPS[ramp]] if isinstance(ramp, str) else [hexc(c) for c in ramp]
    px = im.load()
    ls = [lum(px[x, y]) for y in range(im.height) for x in range(im.width) if px[x, y][3] > 0]
    if not ls:
        return im
    lo, hi = min(ls), max(ls)
    for y in range(im.height):
        for x in range(im.width):
            c = px[x, y]
            if c[3] == 0:
                continue
            t = (lum(c) - lo) / max(1e-6, hi - lo)
            t = min(1.0, max(0.0, t ** gamma + bias))
            px[x, y] = cols[min(len(cols) - 1, int(t * len(cols)))]
    return im


def recolor_hue(im, rules, default_ramp):
    """Per-pixel: saturated pixels whose hue is in a rule's range use that rule's ramp."""
    px = im.load()
    out = im.copy()
    opx = out.load()
    for y in range(im.height):
        for x in range(im.width):
            c = px[x, y]
            if c[3] == 0:
                continue
            h, l, s = colorsys.rgb_to_hls(c[0] / 255, c[1] / 255, c[2] / 255)
            ramp = default_ramp
            for (h0, h1, min_s, r) in rules:
                if s >= min_s and h0 <= h * 360 <= h1:
                    ramp = r
            cols = [hexc(k) for k in RAMPS[ramp]]
            opx[x, y] = cols[min(len(cols) - 1, int(l * len(cols)))]
    return out


def outline(im, color='outline'):
    """Adds a 1px outline around opaque pixels (keeps pixelated shapes readable)."""
    im = im.copy()
    w, h = im.size
    big = Image.new('RGBA', (w + 2, h + 2), (0, 0, 0, 0))
    big.paste(im, (1, 1))
    px = big.load()
    c = hexc(color)
    solid = {(x, y) for y in range(h + 2) for x in range(w + 2) if px[x, y][3] > 0}
    for (x, y) in list(solid):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n not in solid and 0 <= n[0] < w + 2 and 0 <= n[1] < h + 2:
                px[n] = c
    return big


def set1(sheet, comp):
    comps = json.load(open(os.path.join(os.path.dirname(__file__), 'set1_components.json')))
    x, y, w, h = comps[str(sheet)][comp]
    return Image.open('%s/0%d.png' % (SET1, sheet)).convert('RGBA').crop((x, y, x + w, y + h))


def tint(im, ramp):
    return recolor_ramp(im.copy(), ramp)


# =====================================================================================
def build_book():
    sheet = BOOK_SHEET
    save('book_cover', book('BookCover01a'), 4, [12, 12, 12, 12])
    save('book_page_left', book('BookPageLeft01a'), 4)
    save('book_page_right', book('BookPageRight01a'), 4)
    save('banner', crop_sheet(sheet, (64, 208, 288, 240)), 3, [8, 8, 8, 8])
    save('slot', book('Slot01a'), 3, [3, 3, 3, 3])
    save('slot_sel', book('Slot01b'), 3, [3, 3, 3, 3])
    save('slot_off', book('Slot01c'), 3, [3, 3, 3, 3])
    save('frame', book('Frame01a'), 3, [3, 3, 3, 3])
    save('frame_sel', book('FrameSelect01a'), 3, [3, 3, 3, 3])
    save('frame_sel2', book('FrameSelect01b'), 3, [3, 3, 3, 3])
    save('textfield', book('Popup01a'), 4, [4, 4, 4, 4])
    save('textfield_small', book('Popup01a'), 3, [4, 4, 4, 4])
    save('button_dark', crop_sheet(sheet, (65, 497, 95, 527)), 3, [4, 4, 4, 4])
    save('cursor', book('Cursor01c'), 3)
    save('cursor_alt', book('Cursor01d'), 3)
    save('bar_frame_book', book('Bar01a'), 3, [2, 1, 2, 1])
    save('marker', book('Marker01a'), 4, [3, 3, 3, 0])
    save('toggle_on', book('Toggle03a'), 4)
    save('toggle_off', book('Toggle03b'), 4)
    save('point', book('Point01a'), 4)
    save('page_line', crop_sheet(sheet, (64, 264, 96, 266)), 3)
    save('slot_corner', crop_sheet(sheet, (65, 385, 95, 415)), 3)
    icons = {
        'icon_heart': 'IconHeart01a', 'icon_heart_half': 'IconHeart01e', 'icon_heart_empty': 'IconHeart01i',
        'icon_energy': 'IconEnergy01a', 'icon_energy_empty': 'IconEnergy01g', 'icon_star': 'IconStar01a',
        'icon_star_half': 'IconStar01c', 'icon_star_empty': 'IconStar01e', 'icon_coin': 'IconCoin01a',
        'icon_gear': 'IconGear01a', 'icon_home': 'IconHome01a', 'icon_arrow': 'IconArrow01a', 'icon_restart': 'IconRestart01a',
        'icon_play': 'IconPlay01a', 'icon_pause': 'IconPause01a', 'icon_tick': 'IconTick01a', 'icon_cross': 'IconCross01a',
    }
    for name, src in icons.items():
        save(name, book(src), 3)
    small = {'icon_swords': (131, 676, 9, 9), 'icon_moneybag': (148, 676, 8, 9), 'icon_wrench': (163, 676, 9, 9),
             'icon_notes': (180, 676, 7, 9), 'icon_heart_small': (131, 692, 9, 9), 'icon_chest': (148, 692, 9, 9),
             'icon_club': (163, 692, 9, 9), 'icon_ring': (179, 692, 9, 9), 'icon_key': (130, 708, 11, 6),
             'icon_quill': (148, 706, 9, 9), 'icon_map': (163, 706, 9, 9)}
    for name, (x, y, w, h) in small.items():
        save(name, crop_sheet(sheet, (x - 1, y - 1, x + w + 1, y + h + 1)), 3)
    for d in ('Up', 'Down', 'Left', 'Right'):
        save('pad_' + d.lower(), book('GamepadDPad%s01a' % d), 4)
    for k in ('A', 'B', 'X', 'Y', 'Menu', 'View'):
        save('pad_' + k.lower(), book('Gamepad%s01a' % k), 4)


def build_set1():
    # bronze bar frame + fill colours (HP / XP bars)
    save('bar_frame', set1(4, 68), 3, [4, 3, 4, 3])
    save('bar_frame_slim', set1(4, 41), 3, [5, 3, 5, 3])
    for name, comp in (('bar_fill_red', 55), ('bar_fill_blue', 62), ('bar_fill_gold', 69), ('bar_fill_green', 75)):
        save(name, set1(4, comp), 3)
    save('pill_bronze', set1(0, 49), 3, [8, 6, 8, 6])
    save('star', set1(0, 66), 2)
    save('star_empty', set1(0, 62), 2)
    save('star_big', set1(0, 85), 3)
    save('star_big_empty', set1(0, 81), 3)
    save('heart', set1(0, 69), 3)
    save('heart_half', set1(0, 68), 3)
    save('heart_empty', set1(0, 67), 3)
    # crest gems (recoloured per arena) and their empty outlines
    gem = set1(1, 9)  # grey gem: recolour with each crest's ramp
    crest_ramps = {
        'crest_wave': ['outline', '#2a5a9a', '#4a8ad0', '#8ac8f0', '#e8f8ff'],
        'crest_coral': ['outline', '#a03a5a', '#e06a8a', '#f8a8b8', '#fff0f0'],
        'crest_spur': ['outline', '#8a4a20', '#c87a3a', '#f0b070', '#fff0d0'],
        'crest_ore': ['outline', '#5a5a64', '#8a8a96', '#c0c0c8', '#f4f4f8'],
        'crest_cog': ['outline', '#7a5a20', '#c8a040', '#f0d070', '#fff8d8'],
        'crest_flame': ['outline', '#9a2a1a', '#e05a2a', '#ffa040', '#fff0b0'],
        'crest_vine': ['outline', '#2a6a2a', '#4aa040', '#a0e070', '#f0ffe0'],
        'crest_river': ['outline', '#1a6a7a', '#30a8b8', '#80e0e8', '#f0ffff'],
    }
    for name, ramp in crest_ramps.items():
        save(name, recolor_ramp(gem.copy(), ramp), 2)
    save('crest_empty', recolor_ramp(set1(1, 3), ['outline', 'slot_mid', 'slot_hi', 'frame']), 2)
    save('crest_winged', recolor_ramp(set1(1, 11), 'gold'), 2)


def build_dobo():
    d = DOBO
    # parchment scroll dialogue box
    dia = recolor_ramp(pixelate(d + '/Dialogues/Dialogue2.png', 294), ['page_shade', 'select', 'page', 'page', 'page_hi'], gamma=2.2)
    save('dialogue', outline(dia), 4, [11, 6, 11, 6])
    # speaker name plate: maroon with gold rim
    plate = recolor_ramp(pixelate(d + '/Dialogues/DialogueCharacterName2.png', 62),
                         ['cover_dark', 'cover', 'cover', 'cover_hi', 'gold', 'page_hi'], gamma=1.0)
    save('nameplate', plate, 4, [8, 6, 8, 6])
    # ribbon header for page titles
    rib = recolor_ramp(pixelate(d + '/Headers/Header2_ultramarine.png', 136), 'maroon', gamma=0.8)
    save('ribbon', rib, 4, [14, 4, 14, 8])
    rib_small = recolor_ramp(pixelate(d + '/Headers/Header2_ultramarine.png', 104), 'maroon', gamma=0.8)
    save('ribbon_small', rib_small, 3, [12, 4, 12, 7])
    # dark-brown panel (battle HUD)
    modal = recolor_ramp(pixelate(d + '/Modals/Modal12.png', 100), ['ink', 'slot_dark', 'slot', 'slot', 'slot_mid', 'slot_hi', 'frame'], gamma=0.6)
    save('panel_brown', outline(modal, 'ink'), 3, [7, 7, 7, 7])
    # beast card for the book
    card = recolor_hue(pixelate(d + '/Cards/Card1_blue.png', 57), [(180, 260, 0.25, 'maroon')], 'brown')
    save('card', card, 4, [6, 22, 6, 6])
    # buttons
    long_b = pixelate(d + '/Buttons/PatternButtons/PatternLongButton2_purple.png', 76)
    save('button_long', recolor_ramp(long_b.copy(), 'maroon', gamma=0.9), 3, [6, 4, 6, 4])
    save('button_long_sel', recolor_ramp(long_b.copy(), 'gold', gamma=0.9), 3, [6, 4, 6, 4])
    round_b = pixelate(d + '/Buttons/PatternButtons/PatternButton3_purple.png', 26)
    save('button_round', recolor_ramp(round_b.copy(), 'maroon', gamma=0.9), 4)
    save('button_round_alt', recolor_ramp(round_b.copy(), 'brown', gamma=0.9), 4)
    save('button_round_down', recolor_ramp(round_b.copy(), 'gold', gamma=0.9), 4)
    sq = pixelate(d + '/Buttons/SquareButtons/SquareButton3_purple.png', 22)
    save('button_square', recolor_ramp(sq.copy(), 'brown', gamma=0.9), 4)
    save('button_square_down', recolor_ramp(sq.copy(), 'gold', gamma=0.9), 4)
    pill = pixelate(d + '/Buttons/Button7_purple.png', 30)
    save('button_pill', recolor_ramp(pill.copy(), 'brown', gamma=0.9), 3)
    save('button_pill_down', recolor_ramp(pill.copy(), 'gold', gamma=0.9), 3)
    # toggles
    save('switch_on', recolor_hue(pixelate(d + '/Controls/Toggle1_darkBlue.png', 30), [], 'gold'), 3)
    save('switch_off', recolor_ramp(pixelate(d + '/Controls/Toggle2_darkBlue.png', 30), 'brown'), 3)
    # page-turn arrows
    save('arrow_down', recolor_ramp(pixelate(d + '/Controls/Arrow3_pearl.png', 13), 'gold'), 3)
    save('arrow_up', recolor_ramp(pixelate(d + '/Controls/Arrow4_pearl.png', 13), 'gold'), 3)
    # separator line
    sep = recolor_ramp(pixelate(d + '/Dialogues/Separator3.png', 150, 5), ['page_deep', 'page_shade', 'outline'])
    save('separator', sep, 3, [6, 0, 6, 0])
    # menu icons (outline set), recoloured warm
    icons = {'tab_settings': 16, 'tab_home': 18, 'tab_save': 3, 'tab_bag': 43, 'tab_battle': 53,
             'tab_trainer': 78, 'tab_beasts': 80, 'tab_back': 85, 'tab_close': 94, 'tab_more': 96, 'tab_talk': 9}
    for name, num in icons.items():
        path = '%s/Icons/Icons_outline/Outline_64px/IconOutline%d_64px.png' % (d, num)
        im = pixelate(path, 16)
        im = recolor_hue(im, [(0, 25, 0.35, 'maroon'), (330, 360, 0.35, 'maroon'), (40, 70, 0.35, 'gold'),
                               (70, 170, 0.35, 'gold')], 'pearl')
        save(name, im, 3)


if __name__ == '__main__':
    build_book()
    build_set1()
    build_dobo()
    with open(os.path.join(OUT, 'ui_manifest.json'), 'w') as f:
        json.dump(manifest, f, indent=1, sort_keys=True)
    print('built %d UI textures in %s' % (len(manifest), OUT))
