"""Contact sheet of a clip, each frame stamped with its time, for choosing cuts.
python tools/trailer/sheet.py clip.avi out.jpg [--start 0] [--end 30] [--step 1.0] [--cols 6] [--w 400]"""
import argparse
import subprocess

from PIL import Image, ImageDraw, ImageFont


def main():
    p = argparse.ArgumentParser()
    p.add_argument("clip")
    p.add_argument("out")
    p.add_argument("--start", type=float, default=0.0)
    p.add_argument("--end", type=float, default=-1.0)
    p.add_argument("--step", type=float, default=1.0)
    p.add_argument("--cols", type=int, default=6)
    p.add_argument("--w", type=int, default=400)
    a = p.parse_args()
    w, h = a.w, a.w * 9 // 16
    dur = float(subprocess.check_output(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", a.clip]).strip())
    end = dur if a.end < 0 else min(a.end, dur)
    cmd = ["ffmpeg", "-v", "error", "-ss", str(a.start), "-t", str(end - a.start), "-i", a.clip,
           "-vf", "fps=%f,scale=%d:%d" % (1.0 / a.step, w, h), "-f", "rawvideo", "-pix_fmt", "rgb24", "-"]
    raw = subprocess.run(cmd, capture_output=True).stdout
    n = len(raw) // (w * h * 3)
    rows = (n + a.cols - 1) // a.cols
    sheet = Image.new("RGB", (a.cols * (w + 3), rows * (h + 3)), "black")
    font = ImageFont.truetype("C:/Windows/Fonts/consolab.ttf", 17)
    for i in range(n):
        im = Image.frombytes("RGB", (w, h), raw[i * w * h * 3:(i + 1) * w * h * 3])
        d = ImageDraw.Draw(im)
        label = "%.1f" % (a.start + i * a.step)
        d.rectangle([0, 0, 9 + 10 * len(label), 22], fill=(0, 0, 0))
        d.text((4, 2), label, fill=(255, 230, 60), font=font)
        sheet.paste(im, ((i % a.cols) * (w + 3), (i // a.cols) * (h + 3)))
    sheet.save(a.out, quality=82)
    print(a.out, n, "frames")


main()
