"""Prints a track's loudness over time and its likely tempo, for cutting the trailer to the music.
python tools/trailer/audio_probe.py assets/audio/music/track.mp3 [seconds]"""
import subprocess
import sys

import numpy as np

SR = 22050


def load(path, seconds=None):
    cmd = ["ffmpeg", "-v", "error", "-i", path] + (["-t", str(seconds)] if seconds else []) + ["-ac", "1", "-ar", str(SR), "-f", "f32le", "-"]
    return np.frombuffer(subprocess.run(cmd, capture_output=True).stdout, dtype=np.float32)


def onset_env(x, hop=512, win=1024):
    n = (len(x) - win) // hop
    idx = np.arange(win)[None, :] + hop * np.arange(n)[:, None]
    mag = np.abs(np.fft.rfft(x[idx] * np.hanning(win), axis=1))
    flux = np.maximum(0, np.diff(np.log1p(mag * 50), axis=0)).sum(axis=1)
    return flux, hop / SR


def tempo(env, dt, lo=60, hi=180):
    e = env - env.mean()
    ac = np.correlate(e, e, "full")[len(e) - 1:]
    best = []
    for bpm in np.arange(lo, hi, 0.5):
        lag = 60.0 / bpm / dt
        i = int(lag)
        v = ac[i] * (1 - (lag - i)) + ac[i + 1] * (lag - i)
        # a real tempo also lines up at two and four beats
        for m in (2, 4):
            j = int(lag * m)
            if j + 1 < len(ac):
                v += 0.5 * ac[j]
        best.append((v, bpm))
    best.sort(reverse=True)
    return best[:5]


def main():
    path = sys.argv[1]
    x = load(path, float(sys.argv[2]) if len(sys.argv) > 2 else None)
    print(path, "%.1f s" % (len(x) / SR))
    sec = len(x) // SR
    rms = np.sqrt((x[:sec * SR].reshape(sec, SR) ** 2).mean(axis=1))
    db = 20 * np.log10(rms + 1e-6)
    for i in range(0, sec, 20):
        print("%4d s: " % i + " ".join("%3d" % round(v) for v in db[i:i + 20]))
    env, dt = onset_env(x[:SR * 90])
    print("tempo candidates:", ["%.1f bpm (%.0f)" % (b, v) for v, b in tempo(env, dt)])


main()
