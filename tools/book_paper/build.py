"""Bakes the Start book's paper grain (assets/ui/book/paper_grain.png).

A 512x512 tileable greyscale texture centred on mid-grey: soft, low-frequency mottling (like the gentle
clouding of good writing paper) with a few very faint horizontal fibres. No speckle or per-pixel noise:
everything is band-limited in the frequency domain, which also makes it tile seamlessly. The book's
shader (scripts/ui/book_paper.gdshader) tints it tan and uses it only as a faint brightness change.

    python tools/book_paper/build.py
"""
import os

import numpy as np
from PIL import Image

N = 512
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "ui", "book", "paper_grain.png")


def band(rng, lo, hi, stretch_x=1.0):
	"""White noise filtered to wavelengths between N/hi and N/lo pixels (periodic, so it tiles)."""
	f = np.fft.fft2(rng.standard_normal((N, N)))
	fy = np.fft.fftfreq(N)[:, None] * N
	fx = np.fft.fftfreq(N)[None, :] * N / stretch_x
	r = np.sqrt(fx * fx + fy * fy)
	# a soft (Gaussian-edged) annulus rather than a hard cut, so nothing rings
	mask = np.exp(-((np.log(np.maximum(r, 1e-6)) - np.log(np.sqrt(lo * hi))) ** 2) / (2 * 0.45 ** 2))
	mask[0, 0] = 0.0
	out = np.real(np.fft.ifft2(f * mask))
	return out / (np.std(out) + 1e-9)


def main():
	rng = np.random.default_rng(7)
	clouds = 0.65 * band(rng, 2, 5) + 0.35 * band(rng, 6, 14)
	# fibres: noise stretched along x, much fainter than the clouds
	fibres = band(rng, 30, 70, stretch_x=10.0)
	g = 0.5 + 0.11 * clouds + 0.035 * fibres
	g = np.clip(g, 0.0, 1.0)
	os.makedirs(os.path.dirname(OUT), exist_ok=True)
	Image.fromarray((g * 255.0 + 0.5).astype(np.uint8), "L").save(OUT, optimize=True)
	print("wrote", os.path.normpath(OUT), "range", round(float(g.min()), 3), round(float(g.max()), 3))


if __name__ == "__main__":
	main()
