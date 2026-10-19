"""MagicaVoxel .vox -> Wavefront OBJ (+ MTL + 256x1 palette PNG) converter. Pure Python.

Handles multi-model scenes (nTRN/nGRP/nSHP transforms), greedy-meshes faces of the same colour,
and writes the same layout MagicaVoxel's own OBJ export uses (1 unit per voxel, Y up,
model centred on X/Z with its base at Y=0), so Godot imports it as a Mesh.

Usage: python vox2obj.py input.vox output_dir [name]
"""
import os
import struct
import sys
import zlib

SCALE = 0.1  # same as MagicaVoxel's OBJ export

DEFAULT_PALETTE = [
    0x00000000, 0xffffffff, 0xffccffff, 0xff99ffff, 0xff66ffff, 0xff33ffff, 0xff00ffff, 0xffffccff, 0xffccccff, 0xff99ccff, 0xff66ccff, 0xff33ccff, 0xff00ccff, 0xffff99ff, 0xffcc99ff, 0xff9999ff,
    0xff6699ff, 0xff3399ff, 0xff0099ff, 0xffff66ff, 0xffcc66ff, 0xff9966ff, 0xff6666ff, 0xff3366ff, 0xff0066ff, 0xffff33ff, 0xffcc33ff, 0xff9933ff, 0xff6633ff, 0xff3333ff, 0xff0033ff, 0xffff00ff,
    0xffcc00ff, 0xff9900ff, 0xff6600ff, 0xff3300ff, 0xff0000ff, 0xffffffcc, 0xffccffcc, 0xff99ffcc, 0xff66ffcc, 0xff33ffcc, 0xff00ffcc, 0xffffcccc, 0xffcccccc, 0xff99cccc, 0xff66cccc, 0xff33cccc,
    0xff00cccc, 0xffff99cc, 0xffcc99cc, 0xff9999cc, 0xff6699cc, 0xff3399cc, 0xff0099cc, 0xffff66cc, 0xffcc66cc, 0xff9966cc, 0xff6666cc, 0xff3366cc, 0xff0066cc, 0xffff33cc, 0xffcc33cc, 0xff9933cc,
    0xff6633cc, 0xff3333cc, 0xff0033cc, 0xffff00cc, 0xffcc00cc, 0xff9900cc, 0xff6600cc, 0xff3300cc, 0xff0000cc, 0xffffff99, 0xffccff99, 0xff99ff99, 0xff66ff99, 0xff33ff99, 0xff00ff99, 0xffffcc99,
    0xffcccc99, 0xff99cc99, 0xff66cc99, 0xff33cc99, 0xff00cc99, 0xffff9999, 0xffcc9999, 0xff999999, 0xff669999, 0xff339999, 0xff009999, 0xffff6699, 0xffcc6699, 0xff996699, 0xff666699, 0xff336699,
    0xff006699, 0xffff3399, 0xffcc3399, 0xff993399, 0xff663399, 0xff333399, 0xff003399, 0xffff0099, 0xffcc0099, 0xff990099, 0xff660099, 0xff330099, 0xff000099, 0xffffff66, 0xffccff66, 0xff99ff66,
    0xff66ff66, 0xff33ff66, 0xff00ff66, 0xffffcc66, 0xffcccc66, 0xff99cc66, 0xff66cc66, 0xff33cc66, 0xff00cc66, 0xffff9966, 0xffcc9966, 0xff999966, 0xff669966, 0xff339966, 0xff009966, 0xffff6666,
    0xffcc6666, 0xff996666, 0xff666666, 0xff336666, 0xff006666, 0xffff3366, 0xffcc3366, 0xff993366, 0xff663366, 0xff333366, 0xff003366, 0xffff0066, 0xffcc0066, 0xff990066, 0xff660066, 0xff330066,
    0xff000066, 0xffffff33, 0xffccff33, 0xff99ff33, 0xff66ff33, 0xff33ff33, 0xff00ff33, 0xffffcc33, 0xffcccc33, 0xff99cc33, 0xff66cc33, 0xff33cc33, 0xff00cc33, 0xffff9933, 0xffcc9933, 0xff999933,
    0xff669933, 0xff339933, 0xff009933, 0xffff6633, 0xffcc6633, 0xff996633, 0xff666633, 0xff336633, 0xff006633, 0xffff3333, 0xffcc3333, 0xff993333, 0xff663333, 0xff333333, 0xff003333, 0xffff0033,
    0xffcc0033, 0xff990033, 0xff660033, 0xff330033, 0xff000033, 0xffffff00, 0xffccff00, 0xff99ff00, 0xff66ff00, 0xff33ff00, 0xff00ff00, 0xffffcc00, 0xffcccc00, 0xff99cc00, 0xff66cc00, 0xff33cc00,
    0xff00cc00, 0xffff9900, 0xffcc9900, 0xff999900, 0xff669900, 0xff339900, 0xff009900, 0xffff6600, 0xffcc6600, 0xff996600, 0xff666600, 0xff336600, 0xff006600, 0xffff3300, 0xffcc3300, 0xff993300,
    0xff663300, 0xff333300, 0xff003300, 0xffff0000, 0xffcc0000, 0xff990000, 0xff660000, 0xff330000, 0xff0000ee, 0xff0000dd, 0xff0000bb, 0xff0000aa, 0xff000088, 0xff000077, 0xff000055, 0xff000044,
    0xff000022, 0xff000011, 0xff00ee00, 0xff00dd00, 0xff00bb00, 0xff00aa00, 0xff008800, 0xff007700, 0xff005500, 0xff004400, 0xff002200, 0xff001100, 0xffee0000, 0xffdd0000, 0xffbb0000, 0xffaa0000,
    0xff880000, 0xff770000, 0xff550000, 0xff440000, 0xff220000, 0xff110000, 0xffeeeeee, 0xffdddddd, 0xffbbbbbb, 0xffaaaaaa, 0xff888888, 0xff777777, 0xff555555, 0xff444444, 0xff222222, 0xff111111,
]


def _read_dict(data, off):
    n = struct.unpack_from('<i', data, off)[0]
    off += 4
    d = {}
    for _ in range(n):
        kl = struct.unpack_from('<i', data, off)[0]
        off += 4
        k = data[off:off + kl].decode('utf-8', 'replace')
        off += kl
        vl = struct.unpack_from('<i', data, off)[0]
        off += 4
        v = data[off:off + vl].decode('utf-8', 'replace')
        off += vl
        d[k] = v
    return d, off


def _rot_matrix(r):
    """Decode MagicaVoxel's packed rotation byte into a 3x3 matrix (rows)."""
    i1 = r & 3
    i2 = (r >> 2) & 3
    i3 = 3 - i1 - i2
    m = [[0, 0, 0], [0, 0, 0], [0, 0, 0]]
    m[0][i1] = -1 if (r >> 4) & 1 else 1
    m[1][i2] = -1 if (r >> 5) & 1 else 1
    m[2][i3] = -1 if (r >> 6) & 1 else 1
    return m


def parse_vox(path):
    data = open(path, 'rb').read()
    assert data[:4] == b'VOX ', 'not a vox file'
    off = 8
    models = []
    palette = None
    nodes = {}
    size = None

    def walk(off, end):
        nonlocal palette, size
        while off < end:
            cid = data[off:off + 4].decode('ascii', 'replace')
            n, m = struct.unpack_from('<ii', data, off + 4)
            body = off + 12
            if cid == 'SIZE':
                size = struct.unpack_from('<iii', data, body)
            elif cid == 'XYZI':
                cnt = struct.unpack_from('<i', data, body)[0]
                vox = []
                for i in range(cnt):
                    x, y, z, c = struct.unpack_from('<BBBB', data, body + 4 + i * 4)
                    vox.append((x, y, z, c))
                models.append((size, vox))
            elif cid == 'RGBA':
                palette = [struct.unpack_from('<BBBB', data, body + i * 4) for i in range(256)]
            elif cid == 'nTRN':
                nid = struct.unpack_from('<i', data, body)[0]
                _attr, o = _read_dict(data, body + 4)
                child, _res, _layer, nframes = struct.unpack_from('<iiii', data, o)
                o += 16
                frame = {}
                if nframes > 0:
                    frame, o = _read_dict(data, o)
                nodes[nid] = ('T', child, frame)
            elif cid == 'nGRP':
                nid = struct.unpack_from('<i', data, body)[0]
                _attr, o = _read_dict(data, body + 4)
                nch = struct.unpack_from('<i', data, o)[0]
                o += 4
                kids = list(struct.unpack_from('<%di' % nch, data, o))
                nodes[nid] = ('G', kids)
            elif cid == 'nSHP':
                nid = struct.unpack_from('<i', data, body)[0]
                _attr, o = _read_dict(data, body + 4)
                nm = struct.unpack_from('<i', data, o)[0]
                o += 4
                mids = []
                for _ in range(nm):
                    mid = struct.unpack_from('<i', data, o)[0]
                    o += 4
                    _mattr, o = _read_dict(data, o)
                    mids.append(mid)
                nodes[nid] = ('S', mids)
            if m > 0:
                walk(body + n, body + n + m)
            off = body + n + m
    # MAIN chunk
    n, m = struct.unpack_from('<ii', data, off + 4)
    walk(off + 12 + n, off + 12 + n + m)
    if palette is None:
        palette = []
        for v in DEFAULT_PALETTE:
            palette.append((v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff))
    # Note: palette index i (1..255) maps to palette[i-1]
    voxels = {}
    if nodes and 0 in nodes:
        def visit(nid, rot, trans):
            nd = nodes.get(nid)
            if nd is None:
                return
            if nd[0] == 'T':
                fr = nd[2]
                r = _rot_matrix(int(fr['_r'])) if '_r' in fr else [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
                t = [int(v) for v in fr['_t'].split()] if '_t' in fr else [0, 0, 0]
                # compose: new = rot * r ; trans = trans + rot * t
                nr = [[sum(rot[i][k] * r[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
                nt = [trans[i] + sum(rot[i][k] * t[k] for k in range(3)) for i in range(3)]
                visit(nd[1], nr, nt)
            elif nd[0] == 'G':
                for k in nd[1]:
                    visit(k, rot, trans)
            elif nd[0] == 'S':
                for mid in nd[1]:
                    if mid >= len(models):
                        continue
                    (sx, sy, sz), vox = models[mid]
                    # voxel centre relative to model centre
                    for (x, y, z, c) in vox:
                        px = x - sx // 2
                        py = y - sy // 2
                        pz = z - sz // 2
                        wx = rot[0][0] * px + rot[0][1] * py + rot[0][2] * pz + trans[0]
                        wy = rot[1][0] * px + rot[1][1] * py + rot[1][2] * pz + trans[1]
                        wz = rot[2][0] * px + rot[2][1] * py + rot[2][2] * pz + trans[2]
                        voxels[(wx, wy, wz)] = c
        visit(0, [[1, 0, 0], [0, 1, 0], [0, 0, 1]], [0, 0, 0])
    if not voxels:
        for (sx, sy, sz), vox in models:
            for (x, y, z, c) in vox:
                voxels[(x, y, z)] = c
    return voxels, palette


def greedy_quads(voxels):
    """Yield quads (corner, du, dv, normal, color) covering all visible faces.
    Coordinates are MagicaVoxel (x, y, z) with z up."""
    quads = []
    if not voxels:
        return quads
    xs = [p[0] for p in voxels]
    ys = [p[1] for p in voxels]
    zs = [p[2] for p in voxels]
    lo = (min(xs), min(ys), min(zs))
    hi = (max(xs), max(ys), max(zs))
    dims = [hi[i] - lo[i] + 1 for i in range(3)]
    for axis in range(3):
        u = (axis + 1) % 3
        v = (axis + 2) % 3
        slices = {}
        for (p, c) in voxels.items():
            slices.setdefault(p[axis] - lo[axis], []).append((p, c))
        for sign in (1, -1):
            for d in sorted(slices.keys()):
                # build mask for slice d on this axis
                mask = {}
                for (p, c) in slices[d]:
                    q = list(p)
                    q[axis] += sign
                    if tuple(q) in voxels:
                        continue
                    mask[(p[u] - lo[u], p[v] - lo[v])] = c
                if not mask:
                    continue
                used = set()
                for (a, b) in sorted(mask.keys(), key=lambda k: (k[1], k[0])):
                    if (a, b) in used:
                        continue
                    c = mask[(a, b)]
                    w = 1
                    while (a + w, b) in mask and mask[(a + w, b)] == c and (a + w, b) not in used:
                        w += 1
                    h = 1
                    done = False
                    while not done:
                        for k in range(w):
                            key = (a + k, b + h)
                            if key not in mask or mask[key] != c or key in used:
                                done = True
                                break
                        if not done:
                            h += 1
                    for i in range(w):
                        for j in range(h):
                            used.add((a + i, b + j))
                    corner = [0, 0, 0]
                    corner[axis] = d + lo[axis] + (1 if sign > 0 else 0)
                    corner[u] = a + lo[u]
                    corner[v] = b + lo[v]
                    du = [0, 0, 0]
                    du[u] = w
                    dv = [0, 0, 0]
                    dv[v] = h
                    nrm = [0, 0, 0]
                    nrm[axis] = sign
                    quads.append((corner, du, dv, nrm, c))
    return quads


def write_png(path, rgba_rows):
    h = len(rgba_rows)
    w = len(rgba_rows[0]) // 4
    raw = b''.join(b'\x00' + bytes(r) for r in rgba_rows)

    def chunk(t, d):
        c = struct.pack('>I', len(d)) + t + d
        return c + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
    open(path, 'wb').write(png)


def convert(src, out_dir, name=None):
    voxels, palette = parse_vox(src)
    name = name or os.path.splitext(os.path.basename(src))[0]
    os.makedirs(out_dir, exist_ok=True)
    quads = greedy_quads(voxels)
    xs = [p[0] for p in voxels]
    ys = [p[1] for p in voxels]
    zs = [p[2] for p in voxels]
    cx = (min(xs) + max(xs) + 1) / 2.0
    cy = (min(ys) + max(ys) + 1) / 2.0
    z0 = min(zs)

    def to_godot(p):
        # MagicaVoxel: x right, y forward, z up  ->  Godot: x right, y up, z toward camera (= -y)
        return ((p[0] - cx) * SCALE, (p[2] - z0) * SCALE, -(p[1] - cy) * SCALE)
    lines = ['# converted from %s by vox2obj.py' % os.path.basename(src), 'mtllib %s.mtl' % name, 'o %s' % name, 'usemtl palette']
    vlines, vtlines, vnlines, flines = [], [], [], []
    normals = {}
    uvs = {}
    vi = 0
    for (corner, du, dv, nrm, c) in quads:
        p0 = corner
        p1 = [corner[i] + du[i] for i in range(3)]
        p2 = [corner[i] + du[i] + dv[i] for i in range(3)]
        p3 = [corner[i] + dv[i] for i in range(3)]
        g = [to_godot(p) for p in (p0, p1, p2, p3)]
        gn = (nrm[0], nrm[2], -nrm[1])
        if gn not in normals:
            normals[gn] = len(normals) + 1
            vnlines.append('vn %d %d %d' % gn)
        if c not in uvs:
            uvs[c] = len(uvs) + 1
            vtlines.append('vt %.6f 0.5' % ((c - 0.5) / 256.0))
        for p in g:
            vlines.append('v %g %g %g' % p)
        # winding: make the face point along the normal (counter-clockwise when viewed from outside)
        a, b, cc, d = vi + 1, vi + 2, vi + 3, vi + 4
        e1 = [g[1][i] - g[0][i] for i in range(3)]
        e2 = [g[2][i] - g[0][i] for i in range(3)]
        cr = (e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0])
        dot = cr[0] * gn[0] + cr[1] * gn[1] + cr[2] * gn[2]
        order = (a, b, cc, d) if dot > 0 else (a, d, cc, b)
        n_i = normals[gn]
        t_i = uvs[c]
        flines.append('f ' + ' '.join('%d/%d/%d' % (k, t_i, n_i) for k in order))
        vi += 4
    open(os.path.join(out_dir, name + '.obj'), 'w').write('\n'.join(lines + vlines + vtlines + vnlines + flines) + '\n')
    open(os.path.join(out_dir, name + '.mtl'), 'w').write(
        'newmtl palette\nKd 1 1 1\nmap_Kd %s.png\n' % name)
    row = []
    for i in range(256):
        # texel i shows palette index i+1 (MagicaVoxel convention)
        r, g_, b, a = palette[i] if i < len(palette) else (255, 255, 255, 255)
        row += [r, g_, b, 255]
    write_png(os.path.join(out_dir, name + '.png'), [row])
    size = (max(xs) - min(xs) + 1, max(zs) - min(zs) + 1, max(ys) - min(ys) + 1)
    return {'voxels': len(voxels), 'quads': len(quads), 'size': size}


if __name__ == '__main__':
    info = convert(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
    print(info)
