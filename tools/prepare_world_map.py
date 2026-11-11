"""Bake decorative cartography from the supplied Fantasy Map Assets Lite pack.

Run with Pillow: python tools/prepare_world_map.py. UI artwork, not world textures:
the original pack exports in assets/ui/world_map remain unchanged by this bake.
Coordinates share WorldDB.MAP_POS; routes and interactive markers stay in Godot.
"""
from pathlib import Path
import random
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1] / "assets/ui/world_map"
SCALE = 2
ORIGIN = (-100, -140)
SIZE = (1040, 760)
art = Image.new("RGBA", tuple(v * SCALE for v in SIZE))
draw = ImageDraw.Draw(art)


def point(p):
    return tuple(round((v - o) * SCALE) for v, o in zip(p, ORIGIN))


def coast(points):
    # Fractal bays and headlands, with a crisp silhouette and no ink outline.
    rng = random.Random(481 + len(points))

    def subdivide(a, b, depth):
        if depth == 0:
            return [point(a)]
        dx, dy = b[0]-a[0], b[1]-a[1]
        length = max(1, (dx*dx+dy*dy)**0.5)
        offset = rng.uniform(-1, 1) * min(15, length*0.18)
        mid = ((a[0]+b[0])/2-dy/length*offset,
               (a[1]+b[1])/2+dx/length*offset)
        return subdivide(a, mid, depth-1) + subdivide(mid, b, depth-1)

    edge = []
    for i, a in enumerate(points):
        edge.extend(subdivide(a, points[(i+1) % len(points)], 4))
    draw.polygon(edge, fill=(239, 222, 178, 165))


# The mainland follows the actual towns, with a gulf and a separate Isle of Tides.
coast([(-60,-90),(60,-108),(165,-75),(280,-100),(405,-110),(475,-80),
       (575,-95),(690,-80),(760,-95),(875,-35),(855,40),(890,95),
       (875,205),(825,245),(755,230),(705,270),(625,280),(565,305),
       (510,280),(465,330),(405,305),(355,360),(335,405),(280,460),
       (215,455),(165,475),(115,450),(40,472),(-20,450),(-55,385),
       (-30,330),(-70,255),(-45,165),(-70,80)])
coast([(355,465),(385,435),(440,440),(475,425),(530,450),(585,425),
       (635,440),(665,485),(630,520),(585,515),(540,540),(480,515),
       (440,535),(395,515),(360,520),(340,495)])
coast([(738,463),(768,447),(793,457),(808,478),(780,491),(752,485)])


def stamp(name, p, width, alpha=120):
    im = Image.open(ROOT / (name + '.png')).convert('RGBA')
    im.thumbnail((int(width*SCALE), int(width*SCALE)), Image.Resampling.LANCZOS)
    # Preserve the supplied black linework in warm, quiet cartographic ink.
    ink = Image.new('RGBA', im.size, (72, 57, 35, 0))
    ink.putalpha(im.getchannel('A').point(lambda a: a*alpha//255))
    x, y = point(p)
    art.alpha_composite(ink, (x-im.width//2, y-im.height//2))


for x,y,w in [(130,15,92),(245,-20,95),(315,-65,80),(495,-65,90),
              (310,110,78),(450,35,67)]:
    stamp('range' if w>75 else 'mountain', (x,y), w, 130)
for x,y in [(20,75),(50,110),(25,135),(275,150),(290,180),(730,30),
            (760,70),(800,35),(785,105),(690,145)]:
    stamp('pine',(x,y),25,95)
for x,y in [(555,35),(565,80),(705,-15),(700,55),(540,145),(670,200)]:
    stamp('tree',(x,y),31,100)
for x,y in [(65,245),(240,260),(265,300),(295,355)]:
    stamp('cactus',(x,y),26,100)
for x,y in [(475,480),(520,495),(570,475)]:
    stamp('tree',(x,y),22,75)
for y in range(300,541,60):
    for x in range(420,901,95):
        if (y<410 and x>500) or x>710 or (y>540):
            stamp('waves',(x+(y%23),y),34,70)
stamp('compass',(820,375),105,175)

# A river downstream of Riverbend, drawn as a fine engraved double bank.
river=[point(p) for p in [(615,235),(635,248),(620,260),(635,274),(625,284)]]
draw.line(river,fill=(82,113,109,150),width=6,joint='curve')
art.save(ROOT/'cartography.png', optimize=True)
