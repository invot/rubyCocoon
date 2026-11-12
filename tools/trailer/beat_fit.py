"""Fits a steady beat grid (tempo and the time of its first beat) to a stretch of a track.
python tools/trailer/beat_fit.py track.mp3 lo_bpm hi_bpm [start] [seconds]"""
import subprocess
import sys

import numpy as np

SR = 22050
HOP = 256


def main():
    path, lo, hi = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
    start = float(sys.argv[4]) if len(sys.argv) > 4 else 0.0
    secs = float(sys.argv[5]) if len(sys.argv) > 5 else 70.0
    x = np.frombuffer(subprocess.run(["ffmpeg", "-v", "error", "-ss", str(start), "-t", str(secs), "-i", path, "-ac", "1", "-ar", str(SR),
                                      "-f", "f32le", "-"], capture_output=True).stdout, dtype=np.float32)
    win = 1024
    n = (len(x) - win) // HOP
    idx = np.arange(win)[None, :] + HOP * np.arange(n)[:, None]
    mag = np.abs(np.fft.rfft(x[idx] * np.hanning(win), axis=1))
    env = np.maximum(0, np.diff(np.log1p(mag * 50), axis=0)).sum(axis=1)
    env = env - np.convolve(env, np.ones(43) / 43, "same")
    env = np.maximum(env, 0)
    dt = HOP / SR
    t = np.arange(len(env)) * dt
    best = (0, 0, 0)
    for bpm in np.arange(lo, hi, 0.02):
        period = 60.0 / bpm
        for phase in np.arange(0, period, 0.004):
            beats = np.arange(phase, t[-1], period)
            score = env[np.minimum((beats / dt).round().astype(int), len(env) - 1)].sum() / len(beats)
            if score > best[0]:
                best = (score, bpm, phase)
    print("%s from %.1f s: %.2f bpm, first beat at %.3f s (score %.1f, mean onset %.1f)" % (path, start, best[1], start + best[2], best[0], env.mean()))


main()
