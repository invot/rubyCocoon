"""Lists a clip's camera cuts, white flashes and black stretches, for choosing where the trailer cuts in and out.
python tools/trailer/cuts.py build/trailer/raw/clip.avi [more clips]"""
import subprocess
import sys

import numpy as np

W, H = 64, 36


def probe(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-vf", "scale=%d:%d" % (W, H), "-f", "rawvideo", "-pix_fmt", "gray", "-"],
                         capture_output=True).stdout
    f = np.frombuffer(raw, np.uint8).reshape(-1, H, W).astype(np.float32)
    luma = f.mean(axis=(1, 2))
    diff = np.abs(np.diff(f, axis=0)).mean(axis=(1, 2))
    t = lambda i: "%.2f" % (i / 60.0)
    cuts = [i + 1 for i in range(len(diff)) if diff[i] > 22 and (i == 0 or diff[i] > 3 * diff[i - 1] + 4)]
    white = []
    i = 0
    while i < len(luma):
        if luma[i] > 235:
            j = i
            while j < len(luma) and luma[j] > 235:
                j += 1
            white.append("%s-%s (peak %s)" % (t(i), t(j), t(i + int(np.argmax(luma[i:j])))))
            i = j
        i += 1
    black = []
    i = 0
    while i < len(luma):
        if luma[i] < 6:
            j = i
            while j < len(luma) and luma[j] < 6:
                j += 1
            if j - i > 6:
                black.append("%s-%s" % (t(i), t(j)))
            i = j
        i += 1
    print("%s: %.1f s" % (path.replace("\\", "/").split("/")[-1], len(f) / 60.0))
    print("  cuts:", " ".join(t(c) for c in cuts))
    if white:
        print("  white:", ", ".join(white))
    if black:
        print("  black:", ", ".join(black))


for p in sys.argv[1:]:
    probe(p)
