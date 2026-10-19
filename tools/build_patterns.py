"""Cuts the seamless 16x16 patterns the interiors use out of ui/seamless patterns/ into assets/textures/patterns/.

Each texture covers one world unit, so a bookcase shows shelves of books, a bed a quilt, a rug a woven kilim, and so on
(see world.gd).
Run from the project root:  python tools/build_patterns.py
"""
import os
from PIL import Image

SHEET = 'ui/seamless patterns/16x16px/16x16_SpriteSheet.png'
DST = 'assets/textures/patterns'
# name -> (row, column) in the 16x16 sheet
PICKS = {
    'books_0': (10, 18), 'books_1': (10, 19), 'books_2': (10, 20),
    'shelf_0': (23, 18), 'shelf_1': (23, 19), 'shelf_2': (23, 20),
    'planks': (9, 19), 'wood': (8, 7), 'crate': (10, 13),
    'quilt_0': (17, 8), 'quilt_1': (17, 13), 'quilt_2': (17, 17),
    'stove': (23, 21), 'metal': (23, 17),
    # woven rugs (world.gd RUG_PATTERNS picks the one closest to a room's rug colour)
    'rug_red': (18, 10), 'rug_wine': (18, 11), 'rug_gold': (18, 12), 'rug_tribal': (18, 13),
    'rug_blue': (18, 15), 'rug_navy': (18, 7), 'rug_green': (18, 19), 'rug_teal': (18, 20),
}


def main():
    os.makedirs(DST, exist_ok=True)
    sheet = Image.open(SHEET).convert('RGBA')
    for name, (r, c) in PICKS.items():
        tile = sheet.crop((c * 16, r * 16, c * 16 + 16, r * 16 + 16))
        tile.save(os.path.join(DST, name + '.png'))
    print('%d patterns written to %s' % (len(PICKS), DST))


if __name__ == '__main__':
    main()
