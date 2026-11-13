"""Seals a home decor candidate revision: copies the generators and sources in, hashes every file and writes
READY.json LAST (docs/visual_overhaul/parallel-handoff.md). A ready revision is immutable.

    python tools/blender/art_candidates/home_decor/finalize.py rev_001
"""
import datetime
import hashlib
import json
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
BASE = os.path.join(ROOT, "build", "art_candidates", "home_decor")


def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main():
    rev = sys.argv[1]
    out = os.path.join(BASE, rev)
    if os.path.exists(os.path.join(out, "READY.json")):
        sys.exit("%s is already published (READY.json exists); make a new revision" % rev)
    gen = os.path.join(out, "source", "generator")
    os.makedirs(gen, exist_ok=True)
    for f in ("paint_atlas.py", "art_masks.py", "build_kit.py", "make_sheets.py", "finalize.py", "schemes.json"):
        shutil.copy2(os.path.join(HERE, f), gen)
    svg_out = os.path.join(out, "source", "svg")
    os.makedirs(svg_out, exist_ok=True)
    svgs = sorted(os.listdir(os.path.join(BASE, "sources", "svg")))
    for f in svgs:
        shutil.copy2(os.path.join(BASE, "sources", "svg", f), svg_out)
    report = json.load(open(os.path.join(out, "build_report.json")))
    art = json.load(open(os.path.join(out, "textures", "art_layout.json")))
    files = {}
    for dp, _, fs in os.walk(out):
        for f in sorted(fs):
            if f.endswith(".import") or f == "READY.json":
                continue
            p = os.path.join(dp, f)
            files[os.path.relpath(p, out).replace("\\", "/")] = sha(p)
    pieces = report["pieces"]
    ready = {
        "asset_family": "home decor kit (lamps, plants, framed art, wall decor, trim, soft furnishings, tabletop)",
        "revision": rev,
        "status": "provisional candidate for user review; preproduction for runbook Phase H (037a-037c); NOT integrated, NOT approved",
        "created": datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
        "author": "Claude (art candidate lane, docs/visual_overhaul/parallel-handoff.md)",
        "user_direction_2026_11_12": [
            "homes are not cozy enough: lived in, lots of decor and art on the walls, complementary paint/floor/trim schemes",
            "rooms may be smaller or notched for character; passages to doors must stay clear",
            "assets in a variety of colours (chosen: tint masks), all homes with regional kits later",
            "beds and couches are already nice; lamps and plants do not fit and are replaced",
            "framed artwork uses ONLY the supplied recolourable SVG prints",
            "deep-IHWzHs98vQ8 (rocket) belongs in the player's bedroom",
            "one bolder neon/jewel-tone colourway for the art (jewel_pop)",
        ],
        "provenance": {
            "meshes_and_atlas": "built procedurally by the generator scripts; no third-party geometry or texture",
            "reference_packs_reviewed_not_used": "the user's 'Cozy Cartoon Rooms Interior 2.zip' and 'Interiors Cozy Cartoon Rooms 2.zip' (colourless OBJ collections; shapes and arrangements studied only)",
            "prints": {
                "source": "the user's Downloads, 20 SVG files from Unsplash (unsplash.com, Unsplash License: free use, no attribution required; credit the artists at integration as a courtesy)",
                "kept_at": "build/art_candidates/home_decor/sources/svg/ and source/svg/ in this revision (byte-identical copies)",
                "retired": "suchi-m-UexejPp9kR8, pixeliota-9kfPIIHCZNI, andrei-castanha-TvP1M-wJzLE (user asked to drop a couple to fit the last three; kept in sources/svg_retired/)",
                "sha256": {f: sha(os.path.join(svg_out, f)) for f in svgs},
                "render_fix": "suchi-m (retired) labelled its embedded PNGs data:img/png; art_masks.py reads it as data:image/png. Sources untouched.",
            },
            "game_furniture_in_previews": "build/art_candidates/home_decor/refs/*.glb exported from assets/interiors/*.res (unchanged) for scale and context only; not part of the kit",
        },
        "generator": {
            "scripts": "tools/blender/art_candidates/home_decor/ (copied to source/generator/)",
            "blender": "4.2 LTS, Cycles CPU for previews",
            "commands": [
                "python tools/blender/art_candidates/home_decor/paint_atlas.py build/art_candidates/home_decor/%s/textures" % rev,
                "python tools/blender/art_candidates/home_decor/art_masks.py build/art_candidates/home_decor/%s" % rev,
                "python tools/local_resource.py -- \"C:/Program Files/Blender Foundation/Blender 4.2/blender.exe\" -b --factory-startup -P tools/blender/art_candidates/home_decor/build_kit.py -- --rev %s" % rev,
                "python tools/blender/art_candidates/home_decor/make_sheets.py build/art_candidates/home_decor/%s" % rev,
                "python tools/blender/art_candidates/home_decor/finalize.py %s" % rev,
            ],
            "deterministic": True,
        },
        "scale": {"units": "1 unit = 1 tile", "hero_reference_height": 1.44, "wall_height": 2.8,
                  "up_axis": "Z in .blend, +Y in glTF",
                  "floor_pieces": "origin at base centre", "top_pieces": "origin at base centre (stand on a surface)",
                  "wall_pieces": "origin at the centre of the back face, facing glTF +Z (the game's inside for a back wall); place with room_builder _hang-style offsets",
                  "trim": "1-unit modules along X; scale X to fill a wall run; baseboard origin at the floor, crown at the ceiling line"},
        "materials": {
            "surface_0": "decor_atlas.png (1024, 40 cells of 128 px). Tint = vertex colour 'tint' (COLOR_0): R fabric, G ceramic/accent, B wood, A trim paint; 0 keeps the atlas colour. Albedo = atlas * mix(1, tint_c, mask_c) per channel. Glow cells shade_inner and bulb are meant to be weakly emissive.",
            "surface_1": "art_masks.png (1024, 5x4 cells of 192x256). colour = slot0*(1-R-G-B) + R*slot1 + G*slot2 + B*slot3; uv rect and slot colours per instance from art_layout.json (uv_portrait / uv_landscape / uv_square; colourways per scheme plus jewel_pop).",
            "textures": 2, "smoothing": "UNSMOOTHED. At integration smooth decor_atlas.png once with tools/smooth_textures.gd; never smooth art_masks.png (coverage masks).",
        },
        "colour_schemes": "source/generator/schemes.json (12 schemes: wall, wall_lower, trim, floor, rug, fabric, ceramic, accent)",
        "pieces": {n: {k: p[k] for k in ("category", "mount", "triangles", "size_xyz", "tint_regions", "place", "print", "note")} for n, p in pieces.items()},
        "totals": {"pieces": len(pieces), "triangles": sum(p["triangles"] for p in pieces.values()),
                   "max_piece_triangles": max(p["triangles"] for p in pieces.values())},
        "files": files,
        "not_done": [
            "no engine import, shader, builder or map change (Codex owns integration: runbook 037a-037c)",
            "previews are Blender candidate renders, not in-game evidence",
            "LODs not made: pieces are small interior props seen from one stage camera",
        ],
    }
    tmp = os.path.join(out, "READY.json.tmp")
    with open(tmp, "w") as f:
        json.dump(ready, f, indent=1)
    os.replace(tmp, os.path.join(out, "READY.json"))
    print("READY", rev, len(files), "files", ready["totals"])


if __name__ == "__main__":
    main()
