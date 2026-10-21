"""Draws a baked form (bake.py --debug): from the front (x out of the screen; z runs right to left), the side (x to
the right) and above, each part in its own colour, each island numbered and each joint circled, with ticks every 0.1
units, to check and correct the labels in forms.json."""
import numpy as np
from PIL import Image, ImageDraw

COLOURS = {'body': (170, 170, 175), 'head': (230, 70, 70), 'arm_l': (70, 120, 240), 'arm_r': (70, 200, 240),
           'wing_l': (150, 80, 230), 'wing_r': (220, 110, 240), 'leg_fl': (90, 210, 90), 'leg_fr': (170, 230, 60),
           'leg_bl': (40, 140, 60), 'leg_br': (120, 160, 40), 'tail': (240, 160, 40), 'horn': (250, 230, 120),
           'eye': (255, 255, 255), 'deco': (140, 95, 60)}
# camera views in beast space (+x forward, +y up): rows are screen x, screen y and depth towards the viewer
VIEWS = [('front', np.array([[0, 0, -1], [0, 1, 0], [1, 0, 0]], float)),
         ('side', np.array([[1, 0, 0], [0, 1, 0], [0, 0, 1]], float)),
         ('top', np.array([[1, 0, 0], [0, 0, -1], [0, 1, 0]], float))]


def view_img(v, f, part, lab, parts, m, size, joints):
    p = v @ m.T
    lo, hi = p[:, :2].min(0), p[:, :2].max(0)
    s = (size - 24) / max(hi - lo)
    xy = (p[:, :2] - lo) * s + 12
    xy[:, 1] = size - xy[:, 1]
    tri = p[f]
    n = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
    n /= np.linalg.norm(n, axis=1, keepdims=True) + 1e-9
    light = np.array([0.3, 0.5, 0.8])
    light /= np.linalg.norm(light)
    shade = np.abs(n @ light) * 0.7 + 0.3
    img = Image.new('RGB', (size, size), (34, 30, 40))
    d = ImageDraw.Draw(img)
    for i in np.argsort(tri[:, :, 2].mean(1)):
        c = COLOURS[parts[part[i]]]
        d.polygon([tuple(xy[j]) for j in f[i]], fill=tuple(int(x * shade[i]) for x in c))
    for k in range(lab.max() + 1):
        if (lab == k).any():
            cen = xy[np.unique(f[lab == k])].mean(0)
            d.text((cen[0] - 4, cen[1] - 6), str(k), fill=(0, 0, 0))
            d.text((cen[0] - 5, cen[1] - 7), str(k), fill=(255, 255, 255))
    for j in joints.values():
        q = (np.array(j) @ m.T)[:2]
        x, y = (q - lo) * s + 12
        y = size - y
        d.ellipse([x - 3, y - 3, x + 3, y + 3], outline=(255, 255, 255))
    # ticks every 0.1 units along the view's two axes, for reading coordinates
    for t in np.arange(-2.0, 2.01, 0.1):
        x = (t - lo[0]) * s + 12
        y = size - ((t - lo[1]) * s + 12)
        big = abs(t * 10 - round(t * 10)) < 1e-6 and round(t * 10) % 5 == 0
        if 0 <= x < size:
            d.line([x, size - 1, x, size - (8 if big else 4)], fill=(200, 200, 90))
            if big:
                d.text((x + 2, size - 20), '%.1f' % t, fill=(200, 200, 90))
        if 0 <= y < size:
            d.line([0, y, 8 if big else 4, y], fill=(200, 200, 90))
            if big:
                d.text((10, y - 6), '%.1f' % t, fill=(200, 200, 90))
    return img


def form(v, f, part, lab, parts, path, name, joints, size=320):
    sheet = Image.new('RGB', (size * 3, size + 40), (20, 16, 24))
    d = ImageDraw.Draw(sheet)
    d.text((8, 6), name, fill=(255, 230, 120))
    x = 120
    for p in parts:
        if (np.array(parts)[part] == p).any():
            d.rectangle([x, 8, x + 10, 18], fill=COLOURS[p])
            d.text((x + 14, 6), p, fill=(220, 220, 220))
            x += 74
    for i, (vn, m) in enumerate(VIEWS):
        sheet.paste(view_img(v, f, part, lab, parts, m, size, joints), (i * size, 40))
        d.text((i * size + 8, 26), vn, fill=(160, 160, 160))
    sheet.save(path)
