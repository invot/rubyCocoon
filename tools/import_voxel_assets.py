"""Curates the raw voxel pack (voxelassets/) into assets/voxel/ for Godot.

- .vox models are converted with vox2obj.py (same layout as MagicaVoxel's OBJ export)
- OBJ-only models are copied with clean names (their MTL is rewritten to match)
- every palette PNG gets a .import file forcing lossless, mipmap-free import, because
  VRAM compression would smear the 1-pixel palette colours
- writes assets/voxel/CREDITS.md
- makes half-resolution <name>_lo.obj versions of the most detailed trees (tools/voxel_lod.py)

Run from the project root:  python tools/import_voxel_assets.py
"""
import glob
import os
import re
import shutil
import sys

sys.path.insert(0, os.path.dirname(__file__))
import vox2obj  # noqa: E402
import voxel_lod  # noqa: E402

SRC = 'voxelassets'
DST = 'assets/voxel'

G = 'general/'
GO = G + 'Objects/'
GS = G + 'Stone Wall And Ground/'
GV = G + 'Village House Stuff/'
PT = 'path and terrain/obj/'
BI = 'beach island/Voxel Virgin Island - Free Sample-'
CS = 'country store/Obj/CountrySide-'
VL = 'village/'
GY = 'graveyard/Assets/SM-'
AT = 'ancient temple/'
DC = 'dungeon crawler/'

# (category, name, source path without extension)
ASSETS = [
    # ---- nature
    ('nature', 'tree_oak', GO + 'Tree'), ('nature', 'tree_big', GO + 'Tree_Big'), ('nature', 'tree_birch', GO + 'Tree_Birch'),
    ('nature', 'tree_pine', GO + 'Tree_Pine'), ('nature', 'stump', GO + 'Tree_trunk'), ('nature', 'flower_red', GO + 'Flower_Red'),
    ('nature', 'tree_round_1', VL + 'trees/tree1/tree1'), ('nature', 'tree_round_2', VL + 'trees/tree4/tree4'),
    ('nature', 'tree_round_3', VL + 'trees/tree5/tree5'),
    ('nature', 'palm', BI + '5-PalmTree_Medium-8'), ('nature', 'fern', BI + '8-Ferns-6'), ('nature', 'beach_rock', BI + '2-Rock_G-1'),
    ('nature', 'beach_grass', BI + '3-SmallGrass_B-11'), ('nature', 'coconut', BI + '0-CocoNut-0'),
    ('nature', 'shrub_1', CS + '0-Vegetation3'), ('nature', 'shrub_2', CS + '1-Vegetation2'), ('nature', 'shrub_3', CS + '6-Vegetation5'),
    ('nature', 'shrub_4', CS + '7-Vegetation4'), ('nature', 'field_rock', CS + '8-Rock'),
    ('nature', 'rock_big', VL + 'rocks/rock_big/rock_big'), ('nature', 'rock_small', VL + 'rocks/rock_small/rock_small'),
    ('nature', 'dead_tree', GY + '1-Tree'),
] + [('nature', 'mountain_%d' % i, 'nature pack/Obj/MountainRocks-%d' % i) for i in range(10)] + [
    ('nature', 'cactus_%d' % i, PT + 'Cactus/cactus-%d' % i) for i in (1, 2, 3)] + [
    ('nature', 'bush_%d' % i, PT + 'Bushes/bush-%d' % i) for i in (1, 2, 3)] + [
    ('nature', 'bones_%d' % i, PT + 'Bones/bones-%d' % i) for i in (1, 2, 3, 4)] + [
    ('nature', 'stone_%d' % i, PT + 'Stones/stone-%d' % i) for i in (1, 2, 3, 4, 5, 6)] + [
    ('nature', 'grass_tuft_%d' % i, GS + n) for i, n in enumerate(['F_G', 'F_G2', 'F_G3', 'F_G4', 'F_G5', 'F_G6'])] + [
    # ---- props
    ('props', 'barrel', GO + 'Barrel'), ('props', 'crate', GO + 'Crate'), ('props', 'crates', GO + 'Crates_Multiple'),
    ('props', 'market_stall', GO + 'Market Stall'), ('props', 'banner', GO + 'Banner'), ('props', 'campfire', GO + 'Fire'),
    ('props', 'campfire_blue', GO + 'Fire_Blue'), ('props', 'torch', GO + 'Torch_Long'), ('props', 'torch_blue', GO + 'Torch_Long_Blue'),
    ('props', 'grave_1', GO + 'Gravestone_1'), ('props', 'grave_2', GO + 'Gravestone_2'), ('props', 'grave_3', GO + 'Gravestone_3'),
    ('props', 'grave_1w', GO + 'Gravestone_1Weathered'), ('props', 'grave_2w', GO + 'Gravestone_2Weathered'), ('props', 'grave_3w', GO + 'Gravestone_3Weathered'),
    ('props', 'fishing_statue', GO + 'Fishing Statue_W_Rod'), ('props', 'mossy_statue', GO + 'Fishing Statue_W_Rod_Mossy'),
    ('props', 'sword_rusty', GO + 'Sword_Rusty'), ('props', 'skeleton', GO + 'corpse_skeleton'), ('props', 'book_open', GO + 'book_open'),
    ('props', 'draw_gate', GO + 'Draw Gate'), ('props', 'door', GO + 'Door_Reg'), ('props', 'blacksmith_sign', GO + 'Blacksmith Sign'),
    ('props', 'stone_pillar', GS + 'STN_PLR'), ('props', 'stone_pillar_dark', GS + 'STN_PLR_DARK'), ('props', 'stone_wall', GS + 'STN_WALL'),
    ('props', 'stone_wall_broken', GS + 'STN_WALL_BRKN'), ('props', 'stone_wall_dark', GS + 'STN_WALL_DARK_MID'),
    ('props', 'chimney', GV + 'CHIMNEY'),
    ('props', 'stand_green', VL + 'market_stands/market_stand_green/market_stand_green'),
    ('props', 'stand_red', VL + 'market_stands/market_stand_red/market_stand_red'),
    ('props', 'stand_yellow', VL + 'market_stands/market_stand_yellow/market_stand_yellow'),
    ('props', 'box_blue', VL + 'objects/box/box_blue/box_blue'), ('props', 'box_red', VL + 'objects/box/box_red/box_red'),
    ('props', 'box_green', VL + 'objects/box/box_green/box_green'), ('props', 'bridge', VL + 'objects/bridge/bridge'),
    ('props', 'fence', VL + 'objects/fence/fence'), ('props', 'lamp', VL + 'objects/lamp/lamp'),
    ('props', 'tomb_1', GY + '3-Tomb1'), ('props', 'tomb_2', GY + '4-Tomb2'), ('props', 'tomb_3', GY + '5-Tomb3'),
    ('props', 'raven', GY + '6-Raven'), ('props', 'iron_fence', GY + '7-Fence'), ('props', 'grave_pillar', GY + '8-Pillar'),
    ('props', 'ghost', GY + '2-Ghost'), ('props', 'spade', GY + '10-Spade'), ('props', 'gravedigger', GY + '11-Igor_wSpade'),
] + [('props', 'furniture_%d' % i, 'house interiors/House Interior Rooms - Free Sample-%d' % i) for i in range(18)] + [
    # ---- buildings and landmarks
] + [('buildings', 'adobe_%s' % n.lower(), 'desert town/' + n) for n in
     ['LargeBuilding01', 'SmallBuilding01', 'SmallBuilding02', 'SmallBuilding03', 'SmallBuilding04', 'TallBuilding01',
      'TallBuilding02', 'TallBuilding03', 'TinyBuilding01']] + [
    ('buildings', 'village_house_%d' % i, VL + 'buildings/building%d/building%d' % (i, i)) for i in range(1, 6)] + [
    ('buildings', 'country_house', CS + '5-House'),
] + [('buildings', 'gothic_%d' % i, 'gothic castle/SoulGothic_FreeSample_001-%d' % i) for i in range(9)] + [
    ('ancient', 'temple', AT + 'AncientTemple'), ('ancient', 'artifacts', AT + 'AncientArtifacts-0'), ('ancient', 'artifacts_small', AT + 'AncientArtifacts-1'),
    ('ancient', 'portal_stairs', AT + 'AncientCosmicPortal-0-Portal_Stairs'), ('ancient', 'portal_rings', AT + 'AncientCosmicPortal-1-Portal_Rings'),
    ('ancient', 'portal_arch', AT + 'AncientCosmicPortal-2-Portal_Arch'), ('ancient', 'crash_site', AT + 'AncientCrashSite'),
    ('ancient', 'statue_alien', AT + 'AncientReliques-0-Alient_Statue'), ('ancient', 'statue_hand', AT + 'AncientReliques-2-GiantStatue_Hand'),
    ('ancient', 'head_totem', AT + 'AncientReliques-3-Head_Totem'), ('ancient', 'column_ruin', AT + 'AncientReliques-4-Collumn_Ruin'),
    ('ancient', 'column', AT + 'AncientReliques-5-Collumn'), ('ancient', 'rock_statues', AT + 'AncientRockStatues'),
    ('ancient', 'treasure', AT + 'AncientTreasure'), ('ancient', 'pyramid', AT + 'PyramidShips'),
    ('dungeon', 'boss_room', DC + 'Boss Room'), ('dungeon', 'dragon_room', DC + 'Dragon Room'), ('dungeon', 'garden', DC + 'Garden'),
    ('dungeon', 'throne_room', DC + 'Kings Throne'), ('dungeon', 'chamber', DC + 'Princess  Chamber'), ('dungeon', 'stairs', DC + 'Stairs'),
    ('dungeon', 'corridor', DC + 'Thirsty Corridor'), ('dungeon', 'trapped_room', DC + 'TrappedRoom'), ('dungeon', 'treasure_room', DC + 'Treasure'),
    ('arena', 'boxing_gym', 'battle area/Boxing Gym - Free Sample'),
    ('robots', 'field_fighter', 'robots/FieldFighter'), ('robots', 'mecha', 'robots/Mecha01'),
    ('robots', 'mecha_golem', 'robots/MechaGolem'), ('robots', 'quad_tank', 'robots/QuadrupedTank'),
]

CREDITS = {
    'general': 'StickyBizcuit, "Voxel village/dungeon pack" (attribution requested; a hidden easter-egg reference to the author is required: see the NPC "Bizcuit" hiding in the north-west corner of Cocoon Cove, and the book "Building Worlds One Cube at a Time" on bookshelves)',
    'path and terrain': 'Kytric, "Voxel Path and Terrain" (CC0)',
    'beach island': '"Voxel Virgin Island - Free Sample"',
    'country store': '"CountrySide" free sample',
    'village': 'Voxel village pack (buildings, stands, props)',
    'graveyard': '"Voxel Graveyard" free sample',
    'gothic castle': '"SoulGothic" free sample',
    'ancient temple': 'Ancient temple / artifacts voxel pack',
    'dungeon crawler': 'Voxel dungeon crawler pack',
    'nature pack': 'Smokey\'s Voxel Nature Pack',
    'robots': 'Voxel robots pack',
    'house interiors': '"House Interior Rooms - Free Sample"',
    'desert town': 'Voxel desert town pack',
    'battle area': '"Boxing Gym - Free Sample"',
}

IMPORT_TEMPLATE = '''[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://{path}"

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/fix_alpha_border=false
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
'''


def find_source(base):
    """Prefer the artist's own OBJ export; convert the .vox only when no OBJ exists."""
    for cand in (base + '.obj', base + '.vox.obj'):
        p = os.path.join(SRC, cand)
        if os.path.exists(p):
            return p, '.obj'
    alt = glob.glob(os.path.join(SRC, glob.escape(base).replace('Obj/', '*/') + '.*'))
    for a in alt:
        if a.endswith('.obj'):
            return a, '.obj'
    p = os.path.join(SRC, base + '.vox')
    if os.path.exists(p):
        return p, '.vox'
    for a in alt:
        if a.endswith('.vox'):
            return a, '.vox'
    return None, None


def copy_obj(src_obj, out_dir, name):
    text = open(src_obj, encoding='utf-8', errors='replace').read()
    mtl_name = re.search(r'^mtllib (.+)$', text, re.M)
    folder = os.path.dirname(src_obj)
    png_src = None
    if mtl_name:
        mtl_path = os.path.join(folder, mtl_name.group(1).strip())
        if os.path.exists(mtl_path):
            mtl = open(mtl_path, encoding='utf-8', errors='replace').read()
            m = re.search(r'map_Kd (.+)$', mtl, re.M)
            if m:
                png_src = os.path.join(folder, m.group(1).strip())
    if png_src is None or not os.path.exists(png_src):
        cands = glob.glob(os.path.join(folder, '*.png'))
        png_src = cands[0] if cands else None
    text = re.sub(r'^mtllib .+$', 'mtllib %s.mtl' % name, text, flags=re.M)
    text = re.sub(r'^usemtl .+$', 'usemtl palette', text, flags=re.M)
    open(os.path.join(out_dir, name + '.obj'), 'w', encoding='utf-8').write(text)
    open(os.path.join(out_dir, name + '.mtl'), 'w').write('newmtl palette\nKd 1 1 1\nmap_Kd %s.png\n' % name)
    if png_src:
        shutil.copyfile(png_src, os.path.join(out_dir, name + '.png'))


def main():
    os.makedirs(DST, exist_ok=True)
    done = 0
    missing = []
    used_packs = set()
    for cat, name, base in ASSETS:
        src, ext = find_source(base)
        if src is None:
            missing.append(base)
            continue
        used_packs.add(base.split('/')[0])
        out_dir = os.path.join(DST, cat)
        os.makedirs(out_dir, exist_ok=True)
        if src.endswith('.vox') and not src.endswith('.vox.obj'):
            try:
                vox2obj.convert(src, out_dir, name)
            except Exception as e:  # fall back to an OBJ export if the vox can't be parsed
                obj = os.path.splitext(src)[0] + '.obj'
                if os.path.exists(obj):
                    copy_obj(obj, out_dir, name)
                else:
                    missing.append('%s (%s)' % (base, e))
                    continue
        else:
            copy_obj(src, out_dir, name)
        png = os.path.join(out_dir, name + '.png')
        if os.path.exists(png) and not os.path.exists(png + '.import'):
            rel = png.replace('\\', '/')
            open(png + '.import', 'w').write(IMPORT_TEMPLATE.format(path=rel))
        done += 1
    lines = ['# Voxel art credits', '', 'Models in this folder were converted from the packs in `voxelassets/` (kept outside the Godot import).', '']
    for k, v in CREDITS.items():
        if k in used_packs:
            lines.append('- **%s**: %s' % (k, v))
    lines += ['', 'Licences for the free samples are not included with the pack: check each source before releasing the game.']
    open(os.path.join(DST, 'CREDITS.md'), 'w').write('\n'.join(lines) + '\n')
    # runtime manifest: name -> res:// path
    man = ['extends RefCounted', '## Generated by tools/import_voxel_assets.py. Name -> converted voxel model.', '', 'const ASSETS := {']
    for cat, name, base in ASSETS:
        p = os.path.join(DST, cat, name + '.obj')
        if os.path.exists(p):
            man.append('\t"%s": "res://%s",' % (name, p.replace(os.sep, '/')))
    man.append('}')
    open('scripts/data/voxel_manifest.gd', 'w').write('\n'.join(man) + '\n')
    print('converted %d assets' % done)
    # lighter versions of the most detailed trees (voxel_assets.gd uses them)
    voxel_lod.make(voxel_lod.HEAVY)
    if missing:
        print('MISSING:', missing)


if __name__ == '__main__':
    main()
