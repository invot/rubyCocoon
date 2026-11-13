"""Prepare Google Fonts' CormorantSC-Bold.ttf for Godot TextMesh.

Usage: python tools/prepare_title_font.py original.ttf ui/CormorantSC-Bold.ttf
Requires fonttools and skia-pathops. Boolean-union overlapping glyph contours
without changing the design, metrics or weight; TextMesh cannot fill overlaps.
Source: https://github.com/google/fonts/tree/main/ofl/cormorantsc
License: ui/CormorantSC-OFL.txt (SIL OFL 1.1).
"""
import sys

from fontTools.ttLib import TTFont
from fontTools.ttLib.removeOverlaps import removeOverlaps


def main():
    font = TTFont(sys.argv[1])
    assert font['OS/2'].usWeightClass == 700, 'Expected Bold (700)'
    missing = [c for c in set('RUBY COCOONDEMO') if ord(c) not in font.getBestCmap()]
    assert not missing, f'Missing title glyphs: {missing}'
    removeOverlaps(font)
    font.save(sys.argv[2])
    print('Prepared Bold (700); all title and DEMO glyphs present.')


if __name__ == '__main__':
    main()
