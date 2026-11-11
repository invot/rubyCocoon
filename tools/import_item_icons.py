"""Import selected supplied-pack icons, changing only explicit fixed-color variants.

python -m pip install --target build/icon_tools pillow
python tools/import_item_icons.py C:/Users/invot/Downloads/ItemsIcons_v1.0.zip
godot --headless --path . --import

Only the offline importer needs Pillow. Original silhouettes and pixel sizes are preserved.
"""
import json
from io import BytesIO
from pathlib import Path
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "build/icon_tools"))
from PIL import Image

MATERIALS = {
    "reed": ["#f2dca0", "#c9935a", "#6b4430"],
    "silver": ["#e8eef2", "#b2c2cd", "#6b8190"],
    "gold": ["#fff0a6", "#e8bc50", "#a87831"],
    "jade": ["#b4e1b2", "#4aa477", "#2b6551"],
}
COLOR_REGIONS = {
    "quest_taper_candles": [(255, 255, 255)],
    "weapons_smoke_bomb": [(107, 111, 128), (61, 61, 79), (162, 167, 181)],
    "potions_drawstring_pouch": [(143, 79, 168), (90, 47, 110), (232, 138, 194)],
    "armor_sun_medallion": [(232, 162, 58), (184, 106, 40), (247, 214, 90)],
    "armor_rune_stone_necklace": [(107, 111, 128), (61, 61, 79)],
    "armor_feather_charm": [(90, 184, 232), (47, 127, 196)],
    "armor_spiked_ring": [(107, 111, 128)],
    "armor_moon_pendant": [(95, 151, 217)],
    "armor_ranger_bracers": [(168, 113, 79), (110, 70, 48), (242, 220, 160)],
    "quest_hair_ribbon": [(232, 138, 194), (143, 79, 168)],
    "gems_royal_crown": [(232, 162, 58), (184, 106, 40), (247, 214, 90)],
}


def rgb(value):
    return tuple(bytes.fromhex(value.removeprefix("#")))


def recolor(image, variant, shape):
    """Fixed item palettes: retain outlines, glass, cork and highlights from the pack."""
    replace = {}
    if variant in MATERIALS:
        replace = dict(zip([(242, 220, 160), (201, 147, 90), (107, 68, 48)], map(rgb, MATERIALS[variant])))
    elif variant.startswith("#"):
        base = rgb(variant)
        shades = [base, tuple(round(c * 0.62) for c in base), tuple(round(c + (255 - c) * 0.4) for c in base)]
        regions = COLOR_REGIONS.get(shape, [(217, 74, 74), (140, 42, 58)])
        replace = dict(zip(regions, shades))
    if replace:
        image.putdata([replace.get(p[:3], p[:3]) + (p[3],) for p in image.get_flattened_data()])


def main():
    archive = Path(sys.argv[1])
    choices = json.loads((ROOT / "tools/item_icon_sources.json").read_text(encoding="utf-8"))
    output = ROOT / "assets/ui/items"
    output.mkdir(parents=True, exist_ok=True)
    provenance = {}
    with zipfile.ZipFile(archive) as pack:
        files = {Path(n).stem: n for n in pack.namelist() if "/icons/" in n and n.endswith(".png")}
        for item, choice in choices.items():
            if choice[0] == "@original":
                continue
            source = files[choice[0]]
            png = output / (item + ".png")
            if len(choice) > 1:
                image = Image.open(BytesIO(pack.read(source))).convert("RGBA")
                recolor(image, choice[1], choice[0])
                image.save(png)
            else:
                png.write_bytes(pack.read(source))
            provenance[item] = {"source": source, "palette": choice[1] if len(choice) > 1 else "original"}
        (ROOT / "licenses/Items Icons Mega Pack - License.txt").write_bytes(pack.read("ItemsIcons/LICENSE.txt"))
    (ROOT / "tools/item_icon_provenance.json").write_text(json.dumps(provenance, indent=2) + "\n", encoding="utf-8")
    print("Imported %d item icons; original shapes and dimensions are preserved." % len(provenance))


if __name__ == "__main__":
    main()
