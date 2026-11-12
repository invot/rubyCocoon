"""Cuts the Ruby Cocoon trailer from the clips recorded by tools/trailer/record_all.sh (build/trailer/raw/).

    python tools/trailer/make_trailer.py                       the whole trailer -> build/trailer/ruby_cocoon_trailer.mp4
    python tools/trailer/make_trailer.py --start 19 --end 29   one stretch -> build/trailer/part.mp4
    python tools/trailer/make_trailer.py --frame 20.3          one frame -> build/trailer/frame.png
    python tools/trailer/make_trailer.py --sheet               a still of every shot and card -> build/trailer/sheets/cut_*.jpg

The cut follows the music. Its first minute is the game's coast theme (136 beats a minute: `a(bar, beat)` is a time on
its bar lines), which stops on a hit for the story's turn; the finale is the boss theme (122 a minute, `b(bar, beat)`),
cut so its last chord lands on the title. Shots, cards and sounds are all listed in build_cut()."""
import argparse
import os
import subprocess
import sys
import time

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import compositor as C  # noqa: E402
from compositor import ColdCard, Disclaimer, Plate, Shot, Slam, Tagline  # noqa: E402

W, H, FPS = C.W, C.H, C.FPS
OUT = os.path.join(C.ROOT, "build", "trailer")
MUSIC = os.path.join(C.ROOT, "assets", "audio", "music")
SFX = os.path.join(C.ROOT, "sfx")
SR = 48000

# the coast theme, "Adventures in Adventureland": tempo and where its first beat falls (tools/trailer/beat_fit.py)
A_BEAT = 60.0 / 135.98
A_FIRST = 0.013
# the boss theme, "Rising Tide (faster)": sfx.gd TEMPOS. Its last two phrases and closing chord are used.
B_BEAT = 60.0 / 122.0
B_FROM = 0.014 + 448 * B_BEAT


def a(bar, beat=1.0):
    return A_FIRST + ((bar - 1) * 4 + (beat - 1)) * A_BEAT


# the coast theme's own hit, where the story turns and the music stops
HIT = a(34, 3)
# the finale's first bar
T_C = HIT + 12.1


def b(bar, beat=1.0):
    return T_C + ((bar - 1) * 4 + (beat - 1)) * B_BEAT


CHORD = b(9)
END = CHORD + 7.2


# where the tower scene is picked up: Gearhart on his way to the steel door, his line already in its bubble (the fade
# in starts a moment earlier, and must not reach back past the film's own cut at 24.17)
DOOR_FROM = 24.55


def build_cut():
    """Returns the shots in order, the cards, and the extra sounds (time, file, loudness)."""
    hatch_white, evolve_white, merge_white = 5.53, 3.68, 5.53
    shots = [
        # ---- a cold open: an egg under the core, its light swelling to white
        Shot("hatch_owl", hatch_white - a(3), 0.0, audio=0.7, note="hook: the egg"),
        # ---- the first morning of spring
        Shot("intro", 42.0, a(3), ("bloom", 0.9), audio=0.0, note="spring on the Coastal Path"),
        Shot("intro", 61.9, a(4, 3), ("fade", 0.5), zoom=(1.0, 1.10, 0.40, 0.40), audio=0.5, note="hero: my first beast, my own journey"),
        Shot("w_cove", 3.4, a(7), ("iris", 0.8), audio=0.35, note="Cocoon Cove, setting out"),
        Shot("w_bellerive", 2.25, a(9), ("wipe", 0.6), audio=0.35, note="Bellerive"),
        Shot("w_sundown", 2.25, a(10, 3), ("wipe_back", 0.6), audio=0.35, note="Sundown Gulch"),
        # ---- hatch
        Shot("hatch_embit", hatch_white - (a(14) - a(12)), a(12), ("fade", 0.5), audio=0.75, note="HATCH: the egg, the light, Embit"),
        Shot("hatch_frog", 5.78, a(15, 3), ("bloom", 0.5), audio=0.45, note="Tadlet hatches"),
        Shot("hatch_owl", 5.78, a(16, 2), ("bloom", 0.5), audio=0.45, note="Hootlet hatches"),
        # ---- battle
        Shot("b_trio", 3.7, a(17), fx="punch", audio=0.5, note="BATTLE: the ring"),
        Shot("b_first", 7.22, a(18), fx="punch", audio=0.6, note="Embit's Ember"),
        Shot("b_trio", 14.20, a(19), audio=0.6, note="a cast"),
        Shot("b_trio", 16.82, a(20), fx="flash", audio=0.6, note="extra effective"),
        Shot("b_arena", 3.05, a(21), fx="punch", audio=0.6, note="the arena: Tide Captain Marina"),
        Shot("b_first", 11.88, a(22), audio=0.6, note="the last hit: a puff of smoke"),
        # ---- grow
        Shot("evolve_dino", evolve_white - (a(24) - a(23)), a(23), ("fade", 0.4), audio=0.7, note="GROW: Embit becomes Cinderex"),
        # ---- merge
        Shot("merge_a", merge_white - (a(27) - a(25)), a(25), ("wipe", 0.6), audio=0.75, note="MERGE: Pyrosaur and Tempestrix"),
        Shot("merge_b", 5.62, a(28, 3), ("bloom", 0.5), audio=0.45, note="a second merge"),
        Shot("merge_c", 5.62, a(29, 3), ("bloom", 0.5), audio=0.45, note="a third"),
        Shot("b_arena", 19.5, a(30, 3), ("fade", 0.35), audio=0.55, note="the grown team"),
        # ---- the joke, and the turn: the film's last lines, cut off by the music's own hit
        Shot("intro", 80.45 - (HIT - a(31, 2)), a(31, 2), ("fade", 0.4), zoom=(1.0, 1.07, 0.5, 0.42), audio=0.5, note="hero: a whole season of adventure"),
        Shot("black", 0.0, HIT, audio=0.0, note="the music stops"),
        Shot("intro", DOOR_FROM, HIT + 0.45, ("fade", 0.7), audio=1.0, note="Gearhart at the steel door, then the cages"),
        Shot("intro", 37.55, HIT + 0.45 + (33.45 - DOOR_FROM), audio=0.8, note="the warehouse"),
        # ---- the finale
        Shot("w_cogsworth", 2.25, b(1), fx="flash", audio=0.3, note="Cogsworth"),
        Shot("b_robots", 2.9, b(2), fx="punch", audio=0.55, note="Gearhart's robots"),
        Shot("b_robots", 7.30, b(2, 3), audio=0.55, note="a robot's turn"),
        Shot("b_robots", 16.03, b(3), fx="flash", audio=0.55, note="Pyrosaur's Heat Wave"),
        Shot("w_gravenmoor", 2.25, b(4), audio=0.3, note="Gravenmoor"),
        Shot("b_ghost", 8.95, b(5), fx="punch", audio=0.55, note="ghost beasts"),
        Shot("b_ghost", 16.65, b(5, 3) - 0.02, audio=0.55, note="Overheat"),
        Shot("b_summon_fire", 15.1, b(6, 3), fx="flash", audio=0.7, note="Pyroclast answers your song"),
        # ---- the title, on the last chord
        Shot("title", 0.0, CHORD, ("bloom", 0.6), zoom=(1.0, 1.04, 0.5, 0.0), hold=4.15, audio=0.0, note="Ruby Cocoon"),
    ]
    for i, s in enumerate(shots):
        s.end = shots[i + 1].at if i + 1 < len(shots) else END
    warehouse = next(s for s in shots if s.note == "the warehouse")
    cards = [
        Plate(a(12) + 0.03, 1.72, "HATCH", "your first beast"),
        Plate(a(17), 1.72, "BATTLE", "on the elemental ring"),
        Plate(a(23), 1.62, "GROW", "through three forms"),
        Plate(a(25) + 0.05, 1.70, "MERGE", "two beasts into one"),
        ColdCard(warehouse.at + 0.15, 2.6, ["TRAINERS", "ARE", "VANISHING."], dim=0.74),
        Slam(b(1) + 0.10, 1.70, "FIND THEM."),
        Slam(b(4) + 0.10, 1.75, "STOP THE UMBRAL LEGION."),
        Tagline(CHORD + 2.5, ["HATCH", "BATTLE", "MERGE"]),
    ]
    gem = os.path.join(SFX, "04_Pickups_Items", "Pickups_Items_Gem_001.mp3")
    whoosh = os.path.join(SFX, "07_Transitions", "Transitions_WhooshIn_001.mp3")
    sounds = [(c.at + 0.06, gem, 0.34) for c in cards if isinstance(c, Plate)]
    sounds += [(s.at - s.tdur / 2.0, whoosh, 0.2) for s in shots if s.kind in ("iris", "wipe", "wipe_back")]
    sounds.append((CHORD + 2.5, gem, 0.4))
    return shots, cards, sounds


# ---------------------------------------------------------------------------------------------------------- picture
def render_frame(t, shots, cards, disclaimer, single=False):
    live = [s for i, s in enumerate(shots)
            if s.at - s.tdur / 2.0 <= t < s.end + (shots[i + 1].tdur / 2.0 if i + 1 < len(shots) else 0.0)]
    frames = []
    for s in live:
        f = s.frame(t, single)
        z = 1.0
        cx, cy = 0.5, 0.5
        if s.zoom is not None:
            k = C.smooth((t - s.at) / max(0.01, s.end - s.at))
            z = s.zoom[0] + (s.zoom[1] - s.zoom[0]) * k
            cx, cy = s.zoom[2], s.zoom[3]
        u = t - s.at
        if "punch" in s.fx and 0.0 <= u < 0.26:
            z *= 1.0 + 0.07 * (1.0 - C.out_cubic(u / 0.26))
        f = C.zoomed(f, z, cx, cy)
        if "flash" in s.fx and 0.0 <= u < 0.2:
            f = np.asarray(Image.blend(Image.fromarray(f), C._solid(C.WARM_WHITE), 0.7 * (1.0 - C.out_cubic(u / 0.2))))
        frames.append(f)
    if not frames:
        frame = np.zeros((H, W, 3), np.uint8)
    elif len(frames) == 1:
        frame = frames[0]
    else:
        inc = live[-1]
        p = (t - (inc.at - inc.tdur / 2.0)) / inc.tdur
        frame = C.transition(frames[-2], frames[-1], p, inc.kind, inc.centre)
    for c in cards:
        frame = c.base(frame, t)
    frame = np.array(frame)
    for c in cards:
        c.draw(frame, t)
    # up from black at the start, down to it at the end
    k = min(C.smooth(t / 0.7), C.smooth((END - t) / 0.9))
    if k < 0.999:
        frame = (frame.astype(np.float32) * k + 0.5).astype(np.uint8)
    disclaimer.draw(frame, min(C.smooth(t / 0.9), C.smooth((END - t) / 0.9)))
    for s in shots:
        if s.reader is not None and t >= s.end + 0.6:
            s.close()
    return frame


# ---------------------------------------------------------------------------------------------------------- sound
def load_audio(path, start=0.0, dur=None):
    cmd = ["ffmpeg", "-v", "error", "-ss", "%.4f" % max(start, 0.0)]
    if dur is not None:
        cmd += ["-t", "%.4f" % dur]
    cmd += ["-i", path, "-vn", "-ac", "2", "-ar", str(SR), "-f", "f32le", "-"]
    return np.frombuffer(subprocess.run(cmd, capture_output=True).stdout, np.float32).reshape(-1, 2)


def place(master, buf, t, gain=1.0, fade_in=0.012, fade_out=0.012):
    i = int(round(t * SR))
    if i < 0:
        buf = buf[-i:]
        i = 0
    n = min(len(buf), len(master) - i)
    if n <= 0:
        return
    env = np.ones(n, np.float32)
    fi, fo = min(n, int(fade_in * SR)), min(n, int(fade_out * SR))
    if fi > 0:
        env[:fi] = np.linspace(0, 1, fi) ** 2
    if fo > 0:
        env[n - fo:] *= np.linspace(1, 0, fo) ** 2
    master[i:i + n] += buf[:n] * (env * gain)[:, None]


def rms(buf):
    return float(np.sqrt((buf ** 2).mean()) + 1e-9)


def reverb(buf, seconds=3.4, seed=4):  # noqa: D401
    """A hall's tail: the sound smeared through fading noise, darker as it dies."""
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    tail = np.exp(-np.arange(n) / (SR * seconds / 4.5)).astype(np.float32)
    out = np.zeros((len(buf) + n - 1, 2), np.float32)
    for ch in range(2):
        ir = rng.standard_normal(n).astype(np.float32) * tail
        ir = np.convolve(ir, np.ones(24, np.float32) / 24.0, "same")
        size = 1 << int(np.ceil(np.log2(len(buf) + n)))
        out[:, ch] = np.fft.irfft(np.fft.rfft(buf[:, ch], size) * np.fft.rfft(ir, size), size)[:len(out)]
    return out / (np.abs(out).max() + 1e-9)


def build_audio(shots, sounds, path):
    master = np.zeros((int((END + 0.5) * SR), 2), np.float32)
    level = 0.185
    # the coast theme, from its first note to its hit; it rings a moment and is gone. Its opening bars are quiet on
    # the record: they are lifted a little, easing back as the tune builds
    coast = load_audio(os.path.join(MUSIC, "adventures_in_adventureland.mp3"), 0.0, HIT + 1.2).copy()
    lift = np.interp(np.arange(len(coast)) / SR, [0.0, 12.0, 16.5], [1.5, 1.5, 1.0]).astype(np.float32)
    coast *= lift[:, None]
    place(master, coast, 0.0, level / rms(coast[int(30 * SR):int(56 * SR)]), fade_in=0.3, fade_out=0.95)
    # under the tower: the film's own crypt music, far off
    crypt = load_audio(os.path.join(MUSIC, "ether_vox.mp3"), 24.0, T_C - HIT - 0.7)
    place(master, crypt, HIT + 0.6, 0.42 * level / rms(crypt), fade_in=2.2, fade_out=0.5)
    # the boss theme's last two phrases; its final chord rings on under the title
    boss = load_audio(os.path.join(MUSIC, "rising_tide_faster.mp3"), B_FROM)
    gain = 1.12 * level / rms(boss[:int(15 * SR)])
    place(master, boss, T_C, gain, fade_in=0.01, fade_out=0.3)
    chord = boss[int((CHORD - T_C) * SR):]
    place(master, reverb(chord, 6.0), CHORD + 0.02, 0.5, fade_out=2.5)
    # each shot's own sound effects (recorded without music)
    for s in shots:
        if s.audio <= 0.0 or s.clip in ("black", "white"):
            continue
        dur = s.end - s.at if s.hold is None else min(s.end - s.at, s.hold - s.src)
        buf = load_audio(os.path.join(C.RAW, s.clip + ".avi"), s.src, dur)
        place(master, buf, s.at, s.audio, fade_in=0.03, fade_out=0.08)
    for t, file, gain in sounds:
        place(master, load_audio(file), t, gain)
    # keep peaks in hand without flattening the mix: untouched below the knee, rounded off above it
    knee, top = 0.6, 0.88
    mag = np.abs(master)
    over = mag > knee
    master[over] = np.sign(master[over]) * (knee + (top - knee) * np.tanh((mag[over] - knee) / (top - knee)))
    out = (np.clip(master, -1, 1) * 32767).astype(np.int16)
    import wave
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(out.tobytes())
    return path


# ---------------------------------------------------------------------------------------------------------- output
def encode(out_path, frames, audio=None, audio_from=0.0):
    cmd = ["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % (W, H), "-r", str(FPS), "-i", "-"]
    if audio is not None:
        cmd += ["-ss", "%.4f" % audio_from, "-i", audio]
    cmd += ["-vf", "scale=in_range=full:out_range=tv:out_color_matrix=bt709,format=yuv420p", "-c:v", "libx264", "-preset", "slow", "-crf", "16",
            "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709", "-color_range", "tv"]
    if audio is not None:
        cmd += ["-c:a", "aac", "-b:a", "256k", "-shortest"]
    cmd += ["-movflags", "+faststart", out_path]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    n = 0
    t0 = time.time()
    for f in frames:
        proc.stdin.write(f.tobytes())
        n += 1
        if n % 600 == 0:
            print("  %d frames, %.1f a second" % (n, n / (time.time() - t0)), flush=True)
    proc.stdin.close()
    proc.wait()
    print("wrote %s: %d frames (%.1f s) in %.0f s" % (out_path, n, n / FPS, time.time() - t0))


def sheet(shots, cards, disclaimer):
    """A still from the middle of every shot, and from every card, with its time and what it is."""
    font = ImageFont.truetype("C:/Windows/Fonts/consolab.ttf", 15)
    marks = [((s.at + min(s.end, s.at + 6.0)) / 2.0, s.note) for s in shots if s.clip != "black"]
    marks += [(c.at + min(1.2, getattr(c, "dur", 3.0) * 0.7), "card") for c in cards]
    door = next(s for s in shots if s.note.startswith("Gearhart at"))
    marks += [(door.at + 2.4, "the door"), (door.at + 6.3, "the cages"), (CHORD + 1.5, "title: the dragon"), (END - 2.0, "title: the tagline")]
    marks.sort()
    tw, th, cols = 480, 270, 5
    os.makedirs(os.path.join(OUT, "sheets"), exist_ok=True)
    for page in range(0, len(marks), cols * 4):
        part = marks[page:page + cols * 4]
        img = Image.new("RGB", (cols * (tw + 4), ((len(part) + cols - 1) // cols) * (th + 4)), "black")
        for i, (t, note) in enumerate(part):
            im = Image.fromarray(render_frame(t, shots, cards, disclaimer, single=True)).resize((tw, th), Image.LANCZOS)
            d = ImageDraw.Draw(im)
            label = "%.2f %s" % (t, note)
            d.rectangle([0, 0, 8 + 8.3 * len(label), 20], fill=(0, 0, 0))
            d.text((4, 2), label, fill=(255, 230, 60), font=font)
            img.paste(im, ((i % cols) * (tw + 4), (i // cols) * (th + 4)))
        path = os.path.join(OUT, "sheets", "cut_%d.jpg" % (page // (cols * 4)))
        img.save(path, quality=84)
        print(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--start", type=float, default=0.0)
    ap.add_argument("--end", type=float, default=-1.0)
    ap.add_argument("--frame", type=float, default=-1.0)
    ap.add_argument("--sheet", action="store_true")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--audio", action="store_true", help="mix the sound again and lay it on the finished picture")
    ap.add_argument("--out", default="")
    args = ap.parse_args()
    shots, cards, sounds = build_cut()
    disclaimer = Disclaimer("PRE-RELEASE FOOTAGE  ·  NOT FINAL")
    os.makedirs(OUT, exist_ok=True)
    if args.list:
        for s in shots:
            print("%6.2f - %6.2f  %-16s from %6.2f  %-10s %s" % (s.at, s.end, s.clip, s.src, s.kind, s.note))
        print("hit %.2f, finale %.2f, title %.2f, end %.2f" % (HIT, T_C, CHORD, END))
        return
    if args.sheet:
        sheet(shots, cards, disclaimer)
        return
    if args.frame >= 0.0:
        path = args.out or os.path.join(OUT, "frame.png")
        Image.fromarray(render_frame(args.frame, shots, cards, disclaimer, single=True)).save(path)
        print(path)
        return
    if args.audio:
        final = os.path.join(OUT, "ruby_cocoon_trailer.mp4")
        audio = build_audio(shots, sounds, os.path.join(OUT, "trailer_audio.wav"))
        tmp = os.path.join(OUT, "remux.mp4")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", final, "-i", audio, "-map", "0:v", "-map", "1:a", "-c:v", "copy", "-c:a", "aac",
                        "-b:a", "256k", "-shortest", "-movflags", "+faststart", tmp], check=True)
        os.replace(tmp, final)
        print("new sound on", final)
        return
    whole = args.start <= 0.0 and args.end < 0.0
    end = END if args.end < 0.0 else min(args.end, END)
    audio = build_audio(shots, sounds, os.path.join(OUT, "trailer_audio.wav"))
    path = args.out or os.path.join(OUT, "ruby_cocoon_trailer.mp4" if whole else "part.mp4")
    first, last = int(round(args.start * FPS)), int(round(end * FPS))
    # a stretch starts cold: its shots open where they would be by then
    encode(path, (render_frame(f / FPS, shots, cards, disclaimer) for f in range(first, last)), audio, args.start)
    for s in shots:
        s.close()


if __name__ == "__main__":
    main()
