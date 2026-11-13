"""Bakes the place-name banners: a wide strip of one of the user's SVG prints for every town and road, shown faintly
behind the place's name in the top-centre HUD (scripts/ui/top_bar.gd).

    python tools/place_banners/build.py [--no-raster] [map ids or room pattern names]

The prints (Unsplash, the user's own picks) are in tools/place_banners/svg/. Each is rasterised with Godot's own SVG
renderer (raster.gd) and cut to the strip one of two ways (BANNERS):
- "slice": [centre x, centre y, width] as fractions of the picture: a full-width band, its height following from the
  strip's 8:1 shape. Most places use this.
- "band": [centre y, height] as fractions of the picture's height: a much taller band (so a picture whose shapes a thin
  slice would lose stays recognisable), laid along the strip mirror-tiled outward from both ends, the right half a
  mirror of the left so both ends match and any seam falls in the faint middle. The user picked this for Mine Road,
  Caldera Road, Emberfall, Summit Pass and Moor Road (2026-11-13).
It is optionally recoloured to suit the place, and given an alpha strong at the ends and faint in the middle, where the
text sits. Output: assets/ui/place_banners/<map id>.png
(1280 x 160). Re-run `godot --headless --path . --import` afterwards. These are UI pictures: never smooth them.
"""
import colorsys
import os
import re
import subprocess
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SVG = os.path.join(HERE, "svg")
RAW = os.path.join(ROOT, "build", "place_banners", "raw")
OUT = os.path.join(ROOT, "assets", "ui", "place_banners")
GODOT = os.environ.get("GODOT", "C:/Program Files/Godot/Godot_v4.7-stable_win64.exe")
W, H = 1280, 160
# alpha: the ends (EDGE) and the middle (MID), easing between them over the middle part of each half
EDGE, MID = 1.0, 0.12
# (the mirrored strips' strong ends reach further in, so their shapes show)
BAND_MID, BAND_FROM, BAND_SPAN = 0.1, 0.28, 0.47

# map id -> source print, slice or band (see above), recolour
# recolour: {"hue": [[from_lo, from_hi, to, sat_mult], ...]} rotates a hue range (degrees) to a new hue;
#           {"map": [dark, mid, light]} maps lightness onto three colours (a duotone in the place's colours);
#           {"neutral": [amount, tint, strength]} drains `amount` of the colour toward grey, then warms it toward
#           `tint` (the neutral colours the user asked for on the busy town prints);
#           "flip": mirror the picture first, so its right side is what stands at the strip's ends.
BANNERS = {
	# Cocoon Cove: the sea, a green headland and its cottages (the pier cut away below)
	"caccoon": {"src": "public-domain-vectors-tun0Wh6Lhf0", "slice": [0.5, 0.35, 0.98]},
	# Coastal Path: rolling green hills and cypresses
	"route1": {"src": "betsy-nwankwo-UWyTrySvdiY", "slice": [0.5, 0.6, 0.98]},
	# Bellerive: a tumble of town houses, muted to stone and slate
	"tidewater": {"src": "anna-magenta-XUCfqIEudBU", "slice": [0.5, 0.36, 0.98],
		"recolor": {"neutral": [0.78, "#c8bca8", 0.35]}},
	# Shellhaven: its sunlit beach and palms
	"shellhaven": {"src": "public-domain-vectors-tKx5BWXzIIs", "slice": [0.5, 0.62, 0.98]},
	# Isle Trail: palms over a lagoon
	"route2": {"src": "public-domain-vectors-9YQ_zGxEw5o", "slice": [0.5, 0.27, 0.98]},
	# Kelpwick: the sun and a grove of palms along the shore (higher up the beach print than Shellhaven)
	"kelpwick": {"src": "public-domain-vectors-tKx5BWXzIIs", "slice": [0.5, 0.28, 0.98]},
	# Coral Reef: sea stacks over turquoise water
	"reef": {"src": "alghozy-PTdQdH_zIx4", "slice": [0.5, 0.42, 0.98]},
	# Dune Road: the dunes and cacti (the pyramids cut away above)
	"route3": {"src": "public-domain-vectors-je_vuu9qiS8", "slice": [0.5, 0.83, 0.98]},
	# Dustwell Oasis: the canyon floor with its scrub
	"dustwell": {"src": "alghozy-gOq_ruZyxns", "slice": [0.5, 0.8, 0.98]},
	# Mesa Trail: the red mesas' cliffs
	"route4": {"src": "alghozy-gOq_ruZyxns", "slice": [0.5, 0.36, 0.98], "flip": True},
	# Sunwall: sundown over the hills, the hills turned to warm adobe
	"sundown": {"src": "sadat-alam-protik-BEa-gD_If1s", "slice": [0.5, 0.55, 0.98],
		"recolor": {"hue": [[160, 220, 22, 0.75]]}},
	# Dune Sea: waves of sand under a pale sun
	"route5": {"src": "public-domain-vectors-je_vuu9qiS8", "slice": [0.5, 0.64, 0.98], "flip": True},
	# Copperpick: a mountain and pines, the slopes warmed to copper
	"copperpick": {"src": "aruthra-r-KQjfMLn4m2g", "slice": [0.5, 0.74, 0.98],
		"recolor": {"hue": [[190, 260, 24, 0.8]]}},
	# Mine Road: layered peaks in slate and rust
	"route6": {"src": "deep-bQs3iP_7JtA", "band": [0.65, 0.5],
		"recolor": {"hue": [[180, 230, 20, 0.45]]}},
	# Cogsworth: a crowded skyline of towers and domes, muted to brass and smoke
	"cogsworth": {"src": "anna-magenta-bWwscics7_c", "slice": [0.5, 0.5, 0.98],
		"recolor": {"neutral": [0.8, "#c8a468", 0.45]}},
	# Caldera Road: a burning peak and a river running through red hills
	"route7": {"src": "deep-j-oNlEbFrpU", "band": [0.55, 0.55]},
	# Emberfall: Mount Cinder under a glowing sky
	"emberfall": {"src": "anupam-raisim-kerketta-s8IbwuMEpjo", "band": [0.5, 0.55],
		"recolor": {"map": ["#3a1c18", "#a0584a", "#f4c8a0"]}},
	# Summit Pass: snowy peaks
	"route8": {"src": "deep-bQs3iP_7JtA", "band": [0.4, 0.45], "flip": True},
	# Vinehollow: deep jungle, vines and leaves
	"vinehollow": {"src": "public-domain-vectors-cXrUJ1jwOow", "slice": [0.5, 0.3, 0.98]},
	# Jungle Trail: big trees at either side of a clearing (the road below cut away)
	"route9": {"src": "public-domain-vectors-sYax9en4Mlo", "slice": [0.5, 0.3, 0.98],
		"recolor": {"hue": [[150, 200, 110, 0.9]]}},
	# Riverbend: a river winding through green hills
	"riverbend": {"src": "public-domain-vectors-ikJr5mSRjNs", "slice": [0.5, 0.55, 0.98]},
	# Moor Road: bare trees and reeds, in dusky violet
	"route10": {"src": "public-domain-vectors-IU2FvYtECSQ", "band": [0.58, 0.8], "flip": True,
		"recolor": {"map": ["#1c1828", "#625880", "#c8bed8"]}},
	# Gravenmoor: dead trees, bats and the moon
	"gravenmoor": {"src": "public-domain-vectors-IU2FvYtECSQ", "slice": [0.5, 0.34, 0.98]},
}


# ---------------------------------------------------------------- rooms
# Inside a building the bar shows a pattern instead (scripts/autoload/ui.gd ROOM_PATTERNS picks it by the building's
# kind), in one of ROOM_COLOURWAYS colourways picked by the building itself, so each building keeps its own colours.
# The user's interior prints (Unsplash) are in tools/place_banners/svg_rooms/. "swap" patterns are flat colours in the
# SVG: their colours, ranked light to dark, are swapped for a palette's (exact); "hue" ones (an embedded picture, or all
# gradients) are hue-shifted instead. Interiors are never mirrored (the user's direction, 2026-11-13): a pattern is a
# full-width "slice", or a taller band repeated side by side ("tile"). Output: assets/ui/place_banners/rooms/<pattern>_<n>.png.
SVG_ROOMS = os.path.join(HERE, "svg_rooms")
RAW_ROOMS = os.path.join(ROOT, "build", "place_banners", "raw_rooms")
SWAPPED = os.path.join(ROOT, "build", "place_banners", "rooms_svg")
RAW_SWAPPED = os.path.join(ROOT, "build", "place_banners", "raw_rooms_swapped")
OUT_ROOMS = os.path.join(OUT, "rooms")
# light to dark: sage, berry, sky, terracotta, lavender, citrus, mint & cherry, oat
ROOM_PALETTES = [
	["#f4efe6", "#e9c46a", "#8ab17d", "#2a9d8f", "#264653"],
	["#fbf3f0", "#f4a6b5", "#d0587e", "#7b2e5c", "#3b1f3a"],
	["#f2f7fb", "#a9d6e5", "#61a5c2", "#2c7da0", "#1b3a4b"],
	["#fbf1e6", "#f2b880", "#e07a5f", "#a5543d", "#3d2b2a"],
	["#f5f1fb", "#cdb4db", "#9d8cc4", "#6a5a9a", "#2f2a4a"],
	["#fffbea", "#ffd166", "#f4a261", "#7cb518", "#2b5329"],
	["#f1faf6", "#a8e6cf", "#ff8b94", "#3d9a8b", "#22333b"],
	["#f6f1ea", "#d9c7a7", "#b39b7a", "#7a6a58", "#3b342c"],
]
ROOM_COLOURWAYS = len(ROOM_PALETTES)
HUE_SHIFTS = [0, 45, 90, 140, 190, 235, 280, 325]
ROOMS = {
	# homes, cafes and cabins: playful blobs, hearts and crosses
	"blobs": {"src": "annie-spratt-Li656LKw4Js", "mode": "hue", "tile": [0.5, 0.42]},
	# fisheries, music and the water's places: wavy stripes
	"waves": {"src": "marchell-manuputty-m-RoRWg-TMU", "mode": "swap", "slice": [0.5, 0.5, 0.98]},
	# electronics, towers and arenas: gradient pills
	"pills": {"src": "pixeliota-wD12SN8E9jg", "mode": "hue", "tile": [0.45, 0.32]},
	# shops of goods, books and gear: rounded tiles and rings
	"tiles": {"src": "sandeep-kumar-p9eXyyZbXz0", "mode": "swap", "slice": [0.5, 0.5, 0.98]},
	# Beast Centers and halls of quiet: soft arches and circles
	"arches": {"src": "simple-wallpapers-uHcpox40aVs", "mode": "swap", "tile": [0.5, 0.42]},
	# apothecaries, kennels and the old places: flowers and leaves
	"garden": {"src": "sonika-agarwal-kn0eugZeHvc", "mode": "swap", "slice": [0.5, 0.5, 0.98]},
}
HEX6 = re.compile(r"#([0-9a-fA-F]{6})(?![0-9a-fA-F])")


def lum_hex(h: str) -> float:
	r, g, b = hex_rgb(h)
	return 0.299 * r + 0.587 * g + 0.114 * b


def swap_svgs() -> None:
	"""Writes each "swap" pattern's SVG once per palette, its colours swapped by lightness rank, and rasterises them."""
	os.makedirs(SWAPPED, exist_ok=True)
	for name, spec in ROOMS.items():
		if spec["mode"] != "swap":
			continue
		text = open(os.path.join(SVG_ROOMS, spec["src"] + "-unsplash.svg"), encoding="utf-8").read()
		cols = sorted({c.lower() for c in HEX6.findall(text)}, key=lambda c: -lum_hex(c))
		n = len(cols)
		slots = {2: [0, 2], 3: [0, 2, 4]}.get(n, [round(i * 4 / max(1, n - 1)) for i in range(n)])
		for k, pal in enumerate(ROOM_PALETTES):
			out = HEX6.sub(lambda m: pal[slots[cols.index(m.group(1).lower())]], text)
			open(os.path.join(SWAPPED, "%s_%d.svg" % (name, k)), "w", encoding="utf-8").write(out)
	for src, dst in ((SWAPPED, RAW_SWAPPED), (SVG_ROOMS, RAW_ROOMS)):
		os.makedirs(dst, exist_ok=True)
		subprocess.run([GODOT, "--headless", "--path", ROOT, "--script", "res://tools/place_banners/raster.gd", "--",
			src, dst, "2400"], check=True, stdout=subprocess.DEVNULL)


def bake_room(name: str, spec: dict, k: int) -> None:
	if spec["mode"] == "swap":
		im = Image.open(os.path.join(RAW_SWAPPED, "%s_%d.png" % (name, k))).convert("RGB")
	else:
		im = Image.open(os.path.join(RAW_ROOMS, spec["src"] + "-unsplash.png")).convert("RGB")
		if HUE_SHIFTS[k]:
			h, sat, v = im.convert("HSV").split()
			h = h.point(lambda x: (x + round(HUE_SHIFTS[k] * 256 / 360)) % 256)
			im = Image.merge("HSV", (h, sat, v)).convert("RGB")
	rgb = repeated(im, spec) if "tile" in spec else sliced(im, spec)
	prof = alpha_profile(BAND_MID, BAND_FROM, BAND_SPAN) if "tile" in spec else alpha_profile()
	rgba = np.dstack([np.clip(rgb, 0, 1), np.broadcast_to(prof[None, :], (H, W))])
	Image.fromarray((rgba * 255.0 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(OUT_ROOMS, "%s_%d.png" % (name, k)))


def raster() -> None:
	os.makedirs(RAW, exist_ok=True)
	subprocess.run([GODOT, "--headless", "--path", ROOT, "--script", "res://tools/place_banners/raster.gd", "--",
		SVG, RAW, "2400"], check=True, stdout=subprocess.DEVNULL)


def hex_rgb(h: str) -> np.ndarray:
	h = h.lstrip("#")
	return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32) / 255.0


def recolor(rgb: np.ndarray, spec: dict) -> np.ndarray:
	if "map" in spec:
		dark, mid, light = (hex_rgb(c) for c in spec["map"])
		lum = (rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32))[..., None]
		lo = dark + (mid - dark) * np.clip(lum * 2.0, 0, 1)
		return np.where(lum < 0.5, lo, mid + (light - mid) * np.clip(lum * 2.0 - 1.0, 0, 1))
	if "neutral" in spec:
		amount, tint, strength = spec["neutral"]
		lum = (rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32))[..., None]
		grey = rgb + (lum - rgb) * amount
		return grey + (grey * hex_rgb(tint) / 0.75 - grey) * strength
	out = rgb.copy()
	flat = out.reshape(-1, 3)
	hsv = np.array([colorsys.rgb_to_hsv(*p) for p in flat], dtype=np.float32)
	for lo, hi, to, sat in spec.get("hue", []):
		deg = hsv[:, 0] * 360.0
		m = (deg >= lo) & (deg <= hi) & (hsv[:, 1] > 0.08)
		hsv[m, 0] = to / 360.0
		hsv[m, 1] = np.clip(hsv[m, 1] * sat, 0, 1)
	flat[:] = np.array([colorsys.hsv_to_rgb(*p) for p in hsv], dtype=np.float32)
	return out


def alpha_profile(mid: float = MID, start: float = 0.25, span: float = 0.7) -> np.ndarray:
	x = np.abs(np.linspace(-1.0, 1.0, W, dtype=np.float32))
	t = np.clip((x - start) / span, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	return mid + (EDGE - mid) * t


def bake(map_id: str, spec: dict) -> None:
	im = Image.open(os.path.join(RAW, spec["src"] + "-unsplash.png")).convert("RGB")
	rgb = mirrored(im, spec) if "band" in spec else sliced(im, spec)
	if "recolor" in spec:
		rgb = recolor(rgb, spec["recolor"])
	prof = alpha_profile(BAND_MID, BAND_FROM, BAND_SPAN) if "band" in spec else alpha_profile()
	a = np.broadcast_to(prof[None, :], (H, W))
	rgba = np.dstack([np.clip(rgb, 0, 1), a])
	Image.fromarray((rgba * 255.0 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(OUT, map_id + ".png"))


def sliced(im: Image.Image, spec: dict) -> np.ndarray:
	iw, ih = im.size
	cx, cy, bw = spec["slice"]
	pw = bw * iw
	ph = pw * H / W
	x0 = max(0.0, min(iw - pw, cx * iw - pw / 2))
	y0 = max(0.0, min(ih - ph, cy * ih - ph / 2))
	band = im.crop((round(x0), round(y0), round(x0 + pw), round(y0 + ph))).resize((W, H), Image.LANCZOS)
	if spec.get("flip"):
		band = band.transpose(Image.FLIP_LEFT_RIGHT)
	return np.asarray(band, dtype=np.float32) / 255.0


def mirrored(im: Image.Image, spec: dict) -> np.ndarray:
	# (a hair off every side: some prints have a stray line at the edge of their canvas)
	iw, ih = im.size
	im = im.crop((iw // 100, ih // 100, iw - iw // 100, ih - ih // 100))
	if spec.get("flip"):
		im = im.transpose(Image.FLIP_LEFT_RIGHT)
	iw, ih = im.size
	cy, hf = spec["band"]
	bh = hf * ih
	y0 = max(0.0, min(ih - bh, cy * ih - bh / 2))
	tw = max(1, round(iw * H / bh))
	tile = np.asarray(im.crop((0, round(y0), iw, round(y0 + bh))).resize((tw, H), Image.LANCZOS), dtype=np.float32) / 255.0
	# the left half: the picture from the strip's left end inward, mirrored back and forth if it runs out; the right
	# half: the left half's mirror
	u = np.arange(W // 2) % (2 * tw)
	left = tile[:, np.where(u < tw, u, 2 * tw - 1 - u)]
	return np.concatenate([left, left[:, ::-1]], axis=1)


def repeated(im: Image.Image, spec: dict) -> np.ndarray:
	"""A taller band of a pattern ("tile": [centre y, height] as fractions of its height), repeated side by side like
	wallpaper (never mirrored: the user's direction for interiors), centred on the strip."""
	iw, ih = im.size
	cy, hf = spec["tile"]
	bh = hf * ih
	y0 = max(0.0, min(ih - bh, cy * ih - bh / 2))
	tw = max(1, round(iw * H / bh))
	tile = np.asarray(im.crop((0, round(y0), iw, round(y0 + bh))).resize((tw, H), Image.LANCZOS), dtype=np.float32) / 255.0
	off = (tw - (W // 2) % tw) % tw
	return tile[:, (np.arange(W) + off) % tw]


def main() -> None:
	if "--no-raster" not in sys.argv:
		raster()
		swap_svgs()
	os.makedirs(OUT_ROOMS, exist_ok=True)
	only = [a for a in sys.argv[1:] if not a.startswith("--")]
	for name, spec in ROOMS.items():
		if only and name not in only:
			continue
		for k in range(ROOM_COLOURWAYS):
			bake_room(name, spec, k)
		print("baked room pattern", name)
	for map_id, spec in BANNERS.items():
		if only and map_id not in only:
			continue
		bake(map_id, spec)
		print("baked", map_id)


if __name__ == "__main__":
	main()
