"""Synthesises the game's own sound effects into sfx/Custom/ (16-bit mono WAV, no dependencies).

  Defeat_Puff.wav  a soft smack and a puff of air: a beast vanishing in a cloud of smoke (sfx.gd "defeat")
  Faint_Thud.wav   a soft cartoon thud: one of your beasts keeling over (sfx.gd "faint")
  Door_Knock.wav   three raps on a wooden door: knocking on a locked house (sfx.gd "knock")
  Phone_Ring.wav   one ring of an old bell telephone: the clapper rattling between two bells (sfx.gd "phone_ring")

Run from the project root:  python tools/make_sfx.py
"""
import math
import os
import random
import struct
import wave

RATE = 22050
DST = 'sfx/Custom'


def lowpass(xs, cutoff):
    """One-pole low-pass; `cutoff` may be a number or a function of the sample index."""
    out, y = [], 0.0
    for i, x in enumerate(xs):
        fc = cutoff(i) if callable(cutoff) else cutoff
        a = 1.0 - math.exp(-2.0 * math.pi * fc / RATE)
        y += a * (x - y)
        out.append(y)
    return out


def thump(n, f0, f1, tau, amp):
    """A pitch-dropping sine with a fast decay: the 'body' of a smack or a thud."""
    out, ph = [], 0.0
    for i in range(n):
        t = i / RATE
        f = f1 + (f0 - f1) * math.exp(-t / 0.04)
        ph += 2.0 * math.pi * f / RATE
        out.append(amp * math.sin(ph) * math.exp(-t / tau))
    return out


def write(name, xs):
    peak = max(abs(x) for x in xs) or 1.0
    xs = [x / peak * 0.85 for x in xs]
    # short fade-out so the tail never clicks
    for i in range(min(200, len(xs))):
        xs[-1 - i] *= i / 200.0
    os.makedirs(DST, exist_ok=True)
    with wave.open(os.path.join(DST, name), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1.0, min(1.0, x)) * 32767)) for x in xs))
    print('wrote', os.path.join(DST, name), '%.2fs' % (len(xs) / RATE))


def puff():
    rnd = random.Random(7)
    n = int(RATE * 0.5)
    noise = [rnd.uniform(-1.0, 1.0) for _ in range(n)]
    # a breathy 'pfff': the noise darkens as the cloud spreads out
    air = lowpass(lowpass(noise, lambda i: 2600.0 * math.exp(-i / RATE / 0.18) + 350.0), 3000.0)
    env = [min(1.0, (i / RATE) / 0.018) * math.exp(-(i / RATE) / 0.11) for i in range(n)]
    air = [a * e * 2.2 for a, e in zip(air, env)]
    # the smack: a quick crack of bright noise over a low pitch-dropping thump
    body = thump(n, 190.0, 95.0, 0.05, 0.75)
    crack = [noise[i] * math.exp(-(i / RATE) / 0.004) * 0.5 if i < RATE * 0.03 else 0.0 for i in range(n)]
    crack = [c - p for c, p in zip(crack, [0.0] + crack[:-1])]
    return [a + b + c for a, b, c in zip(air, body, crack)]


def thud():
    rnd = random.Random(11)
    n = int(RATE * 0.35)
    body = thump(n, 150.0, 70.0, 0.07, 1.0)
    dust = lowpass([rnd.uniform(-1, 1) for _ in range(n)], 900.0)
    dust = [d * math.exp(-(i / RATE) / 0.06) * 0.9 for i, d in enumerate(dust)]
    return [b + d for b, d in zip(body, dust)]


def knock():
    """Knock-knock-knock: each rap is a few damped wooden resonances plus a short click of a knuckle."""
    rnd = random.Random(23)
    n = int(RATE * 0.62)
    out = [0.0] * n
    # (start in seconds, loudness): a little uneven, like a real hand
    for start, amp in [(0.0, 1.0), (0.165, 0.82), (0.32, 0.95)]:
        s0 = int(start * RATE)
        ln = int(RATE * 0.16)
        modes = [(165.0, 0.045, 1.0), (310.0, 0.03, 0.55), (590.0, 0.018, 0.35), (1180.0, 0.008, 0.18)]
        click = lowpass([rnd.uniform(-1, 1) for _ in range(ln)], 4500.0)
        prev = 0.0
        for i in range(ln):
            t = i / RATE
            v = 0.0
            for f, tau, a in modes:
                # the wood's pitch sags a touch right after the hit
                v += a * math.sin(2.0 * math.pi * f * (t - 0.004 * (1.0 - math.exp(-t / 0.01)))) * math.exp(-t / tau)
            c = click[i] * math.exp(-t / 0.0025)
            v += (c - prev) * 1.6
            prev = c
            if s0 + i < n:
                out[s0 + i] += v * amp * min(1.0, t / 0.0008)
    return out


def ring():
    """Brrring: an old phone's clapper rattling between its two bells, twenty strikes a second, for just under a
    second, each bell a few bright, slightly out-of-tune partials that keep ringing between strikes."""
    n = int(RATE * 1.05)
    out = [0.0] * n
    bells = [(1040.0, [(1.0, 1.0), (2.76, 0.45), (5.4, 0.22)]), (1310.0, [(1.0, 1.0), (2.76, 0.4), (5.4, 0.2)])]
    strikes = int(0.9 * 20)
    for k in range(strikes):
        f0, partials = bells[k % 2]
        s0 = int(k / 20.0 * RATE)
        amp = 0.85 + 0.15 * math.sin(k * 1.7)
        for i in range(s0, n):
            t = (i - s0) / RATE
            if t > 0.35:
                break
            v = 0.0
            for mul, a in partials:
                v += a * math.sin(2.0 * math.pi * f0 * mul * t) * math.exp(-t / (0.09 / mul))
            out[i] += v * amp * min(1.0, t / 0.0006)
    # a little lowpass so it isn't shrill through a phone speaker
    return lowpass(out, 5200.0)


if __name__ == '__main__':
    write('Defeat_Puff.wav', puff())
    write('Faint_Thud.wav', thud())
    write('Door_Knock.wav', knock())
    write('Phone_Ring.wav', ring())
