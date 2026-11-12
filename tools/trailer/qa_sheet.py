"""Stills from the finished trailer at chosen times, to check transitions and cards as they were rendered.
python tools/trailer/qa_sheet.py out.jpg 10.2 10.4 10.6 ...   (or a range: 10.2:11.0:0.2)"""
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

VIDEO = "build/trailer/ruby_cocoon_trailer.mp4"
w, h, cols = 400, 225, 6
times = []
for arg in sys.argv[2:]:
    if ":" in arg:
        a, b, step = (float(v) for v in arg.split(":"))
        while a <= b + 1e-6:
            times.append(round(a, 3))
            a += step
    else:
        times.append(float(arg))
font = ImageFont.truetype("C:/Windows/Fonts/consolab.ttf", 16)
sheet = Image.new("RGB", (cols * (w + 3), ((len(times) + cols - 1) // cols) * (h + 3)), "black")
for i, t in enumerate(times):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-ss", "%.3f" % t, "-i", VIDEO, "-frames:v", "1", "-vf", "scale=%d:%d" % (w, h), "-f", "rawvideo",
                          "-pix_fmt", "rgb24", "-"], capture_output=True).stdout
    if len(raw) < w * h * 3:
        continue
    im = Image.frombytes("RGB", (w, h), raw)
    d = ImageDraw.Draw(im)
    label = "%.2f" % t
    d.rectangle([0, 0, 10 + 9 * len(label), 20], fill=(0, 0, 0))
    d.text((4, 2), label, fill=(255, 230, 60), font=font)
    sheet.paste(im, ((i % cols) * (w + 3), (i // cols) * (h + 3)))
sheet.save(sys.argv[1], quality=84)
print(sys.argv[1], len(times), "frames")
