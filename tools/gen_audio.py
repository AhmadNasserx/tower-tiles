#!/usr/bin/env python3
"""Procedurally generates every sound effect and music loop used by the game.

Run from the repository root:
    python3 tools/gen_audio.py

Sound effects are written as small mono WAV files (fast to trigger, no decode
cost on the web). Music loops are encoded to OGG Vorbis with ffmpeg so the web
build stays small.
"""
import os
import subprocess
import wave

import numpy as np

SR = 22050
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")
rng = np.random.default_rng(7)


# ---------------------------------------------------------------- primitives
def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def phase_from_freq(freq):
    return 2 * np.pi * np.cumsum(freq) / SR


def glide(f0, f1, dur, curve=1.0):
    x = np.linspace(0, 1, int(dur * SR)) ** curve
    return f0 + (f1 - f0) * x


def osc(freq, shape="sine", duty=0.5):
    if np.isscalar(freq):
        raise ValueError("pass an array of frequencies")
    ph = phase_from_freq(freq)
    if shape == "sine":
        return np.sin(ph)
    frac = (ph / (2 * np.pi)) % 1.0
    if shape == "square":
        return np.where(frac < duty, 1.0, -1.0)
    if shape == "saw":
        return 2 * frac - 1
    if shape == "tri":
        return 2 * np.abs(2 * frac - 1) - 1
    raise ValueError(shape)


def const(f, dur):
    return np.full(int(dur * SR), float(f))


def noise(dur):
    return rng.uniform(-1, 1, int(dur * SR))


def env(n, attack=0.005, decay=None, sustain=1.0, release=0.05, curve=3.0):
    """Attack / exponential-ish decay envelope of length n samples."""
    e = np.ones(n)
    a = max(1, int(attack * SR))
    a = min(a, n)
    e[:a] = np.linspace(0, 1, a)
    if decay is None:
        r = max(1, min(int(release * SR), n - a))
        e[n - r:] *= np.linspace(1, 0, r) ** 1.5
    else:
        rest = n - a
        x = np.linspace(0, 1, rest)
        e[a:] = sustain + (1 - sustain) * (1 - x) ** curve
        e[a:] *= (1 - x) ** 0.5
    return e


def lowpass(x, cutoff):
    """One-pole lowpass; cutoff may be scalar or per-sample array."""
    cutoff = np.broadcast_to(np.asarray(cutoff, dtype=float), x.shape)
    a = 1 - np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a[i] * (x[i] - acc)
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def bandpass(x, lo, hi):
    return lowpass(highpass(x, lo), hi)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def seq(*parts, gap=0.0):
    out = []
    for p in parts:
        out.append(p)
        if gap:
            out.append(np.zeros(int(gap * SR)))
    return np.concatenate(out)


def pad(x, dur):
    return np.concatenate([x, np.zeros(int(dur * SR))])


def norm(x, peak=0.85):
    m = np.max(np.abs(x))
    return x if m == 0 else x / m * peak


def soft_clip(x, drive=1.5):
    return np.tanh(x * drive) / np.tanh(drive)


def note_hz(n):
    """MIDI note number to Hz."""
    return 440.0 * 2 ** ((n - 69) / 12)


def tone(f, dur, shape="sine", duty=0.5, **env_kw):
    sig = osc(const(f, dur), shape, duty)
    return sig * env(len(sig), **env_kw)


def write_wav(name, x, peak=0.85):
    x = norm(np.asarray(x, dtype=float), peak)
    # tiny fade to avoid clicks
    f = min(64, len(x) // 4)
    x[:f] *= np.linspace(0, 1, f)
    x[-f:] *= np.linspace(1, 0, f)
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    path = os.path.join(ROOT, "sfx", name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


# ---------------------------------------------------------------- effects
def meow(f_start, f_peak, f_end, dur, bright=1.0):
    n = int(dur * SR)
    x = np.linspace(0, 1, n)
    # rise then fall
    f0 = np.where(x < 0.35, f_start + (f_peak - f_start) * (x / 0.35) ** 0.7,
                  f_peak + (f_end - f_peak) * np.clip((x - 0.35) / 0.65, 0, 1) ** 1.3)
    f0 *= 1 + 0.015 * np.sin(2 * np.pi * 6 * x * dur)
    ph = phase_from_freq(f0)
    # "m-e-o-w": formant moves from closed (m) to open (e/a) to round (o/w)
    formant = np.interp(x, [0, 0.15, 0.45, 1.0], [500, 1500 * bright, 1100, 600])
    sig = np.zeros(n)
    for h in range(1, 14):
        fh = f0 * h
        weight = np.exp(-((fh - formant) / (450 + 150 * bright)) ** 2) + 0.25 / h
        sig += weight * np.sin(ph * h)
    amp = np.interp(x, [0, 0.12, 0.7, 1.0], [0, 1, 0.8, 0])
    return sig * amp


def boof(pitch=1.0):
    d = 0.16
    f = glide(260 * pitch, 140 * pitch, d, 0.6)
    ph = phase_from_freq(f)
    sig = sum(np.sin(ph * h) * (0.9 / h) for h in range(1, 7))
    sig = lowpass(sig, glide(2200, 500, d))
    e = env(len(sig), attack=0.004, decay=True, curve=2.0)
    n = bandpass(noise(0.05), 300, 1800) * env(int(0.05 * SR), decay=True) * 0.4
    return mix(sig * e, n)


def make_sfx():
    # Yarn kitty: soft "thwip" pop
    s = mix(osc(glide(950, 280, 0.09, 0.5), "sine") * env(int(0.09 * SR), decay=True),
            highpass(noise(0.03), 2000) * env(int(0.03 * SR), decay=True) * 0.35)
    write_wav("shoot_yarn", s, 0.6)

    # Fish cannon: deep thunk + puff
    s = mix(osc(glide(190, 55, 0.22, 0.4), "sine") * env(int(0.22 * SR), decay=True, curve=2),
            lowpass(noise(0.2), 900) * env(int(0.2 * SR), decay=True, curve=4) * 0.8)
    write_wav("shoot_fish", soft_clip(s, 2.0), 0.8)

    # Laser pointer: short bright zap
    d = 0.14
    f = glide(1800, 900, d) * (1 + 0.05 * np.sin(2 * np.pi * 60 * t_axis(d)))
    s = osc(f, "saw") * env(int(d * SR), decay=True, curve=1.5)
    write_wav("zap", lowpass(s, 4000), 0.35)

    # Hiss box: airy hiss with a little growl
    d = 0.45
    s = mix(highpass(noise(d), 2500) * env(int(d * SR), attack=0.03, decay=True, curve=1.2),
            osc(glide(140, 90, d), "saw") * env(int(d * SR), attack=0.02, decay=True) * 0.15)
    write_wav("hiss", s, 0.55)

    # Hits
    s = mix(osc(glide(520, 260, 0.05), "square", 0.3) * env(int(0.05 * SR), decay=True) * 0.4,
            bandpass(noise(0.04), 800, 5000) * env(int(0.04 * SR), decay=True))
    write_wav("hit", s, 0.45)
    s = mix(tone(1568, 0.22, decay=True, curve=2), tone(2349, 0.22, decay=True, curve=2) * 0.6,
            bandpass(noise(0.05), 1500, 8000) * env(int(0.05 * SR), decay=True) * 0.6)
    write_wav("crit", s, 0.5)

    # Fish splash impact
    d = 0.35
    s = mix(lowpass(noise(d), glide(3000, 300, d)) * env(int(d * SR), decay=True, curve=2),
            osc(glide(120, 40, 0.25), "sine") * env(int(0.25 * SR), decay=True) * 0.8)
    write_wav("splash", soft_clip(s, 1.6), 0.7)

    # Dog defeated: little boof + yip variants
    write_wav("die", seq(boof(1.0), np.zeros(200)), 0.55)
    yip = osc(glide(900, 1400, 0.08, 0.5), "tri") * env(int(0.08 * SR), decay=True)
    write_wav("die2", boof(1.35), 0.55)
    write_wav("yip", lowpass(yip, 3000), 0.4)

    # Coin
    s = seq(tone(988, 0.05, "square", 0.25, release=0.01),
            tone(1319, 0.22, "square", 0.25, decay=True, curve=2))
    write_wav("coin", lowpass(s, 5000), 0.3)

    # Build: thud + sparkle
    thud = osc(glide(160, 60, 0.18), "sine") * env(int(0.18 * SR), decay=True)
    spark = seq(*[tone(note_hz(n), 0.06, "tri", decay=True) for n in (72, 76, 79, 84)])
    write_wav("build", mix(thud, np.concatenate([np.zeros(int(0.05 * SR)), spark * 0.5])), 0.7)

    # Upgrade: rising arpeggio
    s = seq(*[tone(note_hz(n), 0.07, "square", 0.25, decay=True, curve=1.5) for n in (67, 71, 74, 79, 83)])
    s = mix(s, np.concatenate([np.zeros(int(0.28 * SR)), tone(note_hz(86), 0.35, "tri", decay=True)]))
    write_wav("upgrade", lowpass(s, 6000), 0.45)

    # Sell: descending coins
    s = seq(*[tone(note_hz(n), 0.06, "square", 0.25, decay=True) for n in (84, 79, 76)])
    write_wav("sell", lowpass(s, 5000), 0.35)

    # Lost a life: sad meow
    write_wav("life_lost", meow(520, 640, 380, 0.6, 0.8), 0.7)
    # Happy meows
    write_wav("meow", meow(480, 820, 640, 0.42, 1.1), 0.6)
    write_wav("meow2", meow(600, 900, 760, 0.3, 1.2), 0.6)
    # Angry cat hiss + yowl for boss arrival reaction
    write_wav("yowl", mix(meow(400, 700, 300, 0.9, 0.7), highpass(noise(0.9), 3000) * 0.15 * env(int(0.9 * SR), decay=True)), 0.7)

    # Paw slam: whoosh + boom
    whoosh = bandpass(noise(0.25), 300, 2500) * np.linspace(0, 1, int(0.25 * SR)) ** 2
    boom = mix(osc(glide(90, 28, 0.8, 0.5), "sine") * env(int(0.8 * SR), decay=True, curve=2),
               lowpass(noise(0.6), glide(2500, 150, 0.6)) * env(int(0.6 * SR), decay=True, curve=3) * 0.9)
    write_wav("slam", soft_clip(seq(whoosh * 0.4, boom), 2.5), 0.95)

    # Wave start: two-note horn
    def horn(n, d):
        f = const(note_hz(n), d)
        return lowpass(osc(f, "saw") * 0.6 + osc(f * 1.005, "square", 0.4) * 0.4, 1800) * env(int(d * SR), attack=0.02, release=0.08)
    write_wav("wave_start", seq(horn(60, 0.16), horn(67, 0.38), gap=0.02), 0.6)

    # Wave clear jingle
    s = seq(*[tone(note_hz(n), 0.09, "square", 0.25, decay=True, curve=1.4) for n in (72, 76, 79)],
            tone(note_hz(84), 0.4, "square", 0.25, decay=True))
    write_wav("wave_clear", lowpass(s, 5000), 0.45)

    # Victory fanfare
    mel = [(72, .15), (72, .15), (72, .15), (76, .45), (74, .15), (77, .15), (79, .7)]
    lead = seq(*[horn(n, d) for n, d in mel])
    bass = seq(*[tone(note_hz(n), d, "tri", release=0.05) for n, d in [(48, .45), (53, .6), (55, .85)]])
    write_wav("victory", mix(lead, bass * 0.7), 0.7)

    # Defeat
    mel = [(67, .3), (66, .3), (65, .3), (64, .9)]
    s = seq(*[tone(note_hz(n), d, "tri", release=0.1) for n, d in mel])
    write_wav("defeat", mix(s, seq(*[tone(note_hz(n - 24), d, "tri", release=0.1) for n, d in mel]) * 0.6), 0.6)

    # UI
    write_wav("click", mix(tone(1200, 0.035, "square", 0.3, decay=True), highpass(noise(0.01), 3000) * 0.3), 0.3)
    write_wav("hover", tone(1800, 0.025, "sine", decay=True), 0.15)
    write_wav("error", tone(130, 0.18, "square", 0.5, release=0.04), 0.3)

    # Perk / magic shimmer
    parts = []
    for i, n in enumerate((72, 76, 79, 83, 86, 88, 91)):
        p = np.zeros(int(i * 0.045 * SR))
        parts.append(np.concatenate([p, tone(note_hz(n), 0.35, "sine", decay=True, curve=2) * 0.7]))
    write_wav("perk", mix(*parts), 0.5)

    # Boss arrival: low growl alarm
    d = 1.3
    t = t_axis(d)
    growl = osc(const(55, d) * (1 + 0.03 * np.sin(2 * np.pi * 3 * t)), "saw") * (0.6 + 0.4 * np.sin(2 * np.pi * 7 * t))
    alarm = osc(np.where((t * 4) % 1 < 0.5, 440.0, 330.0), "square", 0.5) * 0.25
    write_wav("boss", soft_clip(lowpass(growl, 900) + lowpass(alarm, 2000), 1.5) * env(int(d * SR), attack=0.05, release=0.3), 0.75)

    # Zoomies: whoosh up
    d = 0.6
    s = mix(bandpass(noise(d), 600, glide(1000, 6000, d)) * env(int(d * SR), attack=0.1, release=0.2),
            osc(glide(300, 1400, d, 2), "tri") * env(int(d * SR), attack=0.05, release=0.15) * 0.4)
    write_wav("zoomies", s, 0.6)

    # Pulse tower ring
    write_wav("pulse", osc(glide(300, 120, 0.25), "sine") * env(int(0.25 * SR), decay=True) +
              bandpass(noise(0.25), 400, 2000) * env(int(0.25 * SR), decay=True) * 0.3, 0.45)

    # Combo tick (pitched up in engine)
    write_wav("combo", tone(1047, 0.12, "tri", decay=True), 0.4)

    # Countdown tick
    write_wav("tick", tone(880, 0.05, "sine", decay=True), 0.3)

    # Heal (poodle)
    s = seq(tone(note_hz(84), 0.06, "sine", decay=True), tone(note_hz(91), 0.12, "sine", decay=True))
    write_wav("heal", s, 0.25)

    # Snore for the fat cat
    d = 0.8
    s = lowpass(noise(d), 500) * (np.sin(np.linspace(0, np.pi, int(d * SR))) ** 2)
    write_wav("snore", s, 0.35)

    # Cash register for fat cat payout
    s = seq(tone(note_hz(88), 0.05, "square", 0.25, decay=True), tone(note_hz(93), 0.05, "square", 0.25, decay=True),
            mix(tone(note_hz(96), 0.3, "sine", decay=True), tone(note_hz(100), 0.3, "sine", decay=True) * 0.5))
    write_wav("cash", s, 0.4)


# ---------------------------------------------------------------- music
def drum_kick():
    d = 0.22
    return osc(glide(150, 42, d, 0.4), "sine") * env(int(d * SR), attack=0.001, decay=True, curve=2.5)


def drum_snare():
    d = 0.16
    return mix(bandpass(noise(d), 900, 7000) * env(int(d * SR), attack=0.001, decay=True, curve=3),
               osc(glide(240, 160, 0.08), "tri") * env(int(0.08 * SR), decay=True) * 0.5)


def drum_hat(open_=False):
    d = 0.18 if open_ else 0.04
    return highpass(noise(d), 6000) * env(int(d * SR), attack=0.001, decay=True, curve=3)


def place(buf, sig, start):
    """Add sig into buf at start sample, wrapping around for seamless loops."""
    n = len(buf)
    end = start + len(sig)
    if end <= n:
        buf[start:end] += sig
    else:
        k = n - start
        buf[start:] += sig[:k]
        buf[: end - n] += sig[k:]


def render_song(bpm, bars, chords, melody_fn, drums=True, lead_shape="square", lead_duty=0.25,
                arp=True, bass_shape="tri", swing=0.0, lead_gain=0.32):
    beat = 60.0 / bpm
    steps_per_bar = 16
    step = beat / 4
    total = int(bars * 4 * beat * SR)
    bass = np.zeros(total)
    lead = np.zeros(total)
    harm = np.zeros(total)
    kit = np.zeros(total)

    def at(bar, s16):
        t = (bar * steps_per_bar + s16) * step
        if swing and s16 % 2 == 1:
            t += step * swing
        return int(t * SR)

    kick, snare, hat, ohat = drum_kick(), drum_snare(), drum_hat(), drum_hat(True)
    for bar in range(bars):
        root, quality = chords[bar % len(chords)]
        third = 3 if quality == "m" else 4
        tones = [root, root + third, root + 7, root + 12]
        # bass: root on beats with octave bounce
        for s16, off, d in ((0, 0, 0.35), (6, 12, 0.12), (8, 0, 0.3), (14, 7, 0.12)):
            n = tone(note_hz(root - 12 + off), d * beat * 2, bass_shape, decay=True, curve=1.2)
            place(bass, n, at(bar, s16))
        # arpeggio chords
        if arp:
            for s16 in range(0, 16, 2):
                n = tones[(s16 // 2) % 4] + 12
                a = tone(note_hz(n), step * 1.6, "square", 0.125, decay=True, curve=2.5)
                place(harm, a, at(bar, s16))
        else:
            for k, n in enumerate(tones[:3]):
                p = tone(note_hz(n + 12), beat * 4, "tri", attack=0.15, release=0.6)
                place(harm, p, at(bar, 0))
        if drums:
            for s16 in range(16):
                if s16 in (0, 8) or (s16 == 10 and bar % 2 == 1):
                    place(kit, kick, at(bar, s16))
                if s16 in (4, 12):
                    place(kit, snare * 0.8, at(bar, s16))
                if s16 % 2 == 0:
                    place(kit, hat * (0.35 if s16 % 4 else 0.5), at(bar, s16))
                if s16 == 14 and bar % 4 == 3:
                    place(kit, ohat * 0.4, at(bar, s16))
        # melody
        for s16, n, length in melody_fn(bar, tones):
            d = length * step
            sig = osc(const(note_hz(n), d) * (1 + 0.004 * np.sin(2 * np.pi * 5.5 * t_axis(d))), lead_shape, lead_duty)
            sig *= env(len(sig), attack=0.008, decay=True, curve=1.3, sustain=0.4)
            place(lead, sig, at(bar, s16))

    lead = lowpass(lead, 3500)
    harm = lowpass(harm, 2600)
    out = bass * 0.55 + harm * 0.14 + lead * lead_gain + kit * 0.5
    # light stereo-free "room": a couple of short echoes on lead/harm
    echo = np.zeros(total)
    dly = int(beat * 0.75 * SR)
    src = lead * lead_gain * 0.35 + harm * 0.08
    echo[dly:] += src[:-dly]
    echo[2 * dly:] += src[: -2 * dly] * 0.5
    out += lowpass(echo, 2000)
    return soft_clip(norm(out, 0.9), 1.2)


def battle_melody():
    # C major pentatonic-ish motifs, deterministic but varied
    scale = [72, 74, 76, 79, 81, 84, 86, 88]
    motifs = [
        [(0, 0, 2), (2, 2, 2), (4, 3, 3), (8, 4, 2), (10, 3, 2), (12, 2, 4)],
        [(0, 4, 3), (4, 3, 1), (6, 2, 2), (8, 0, 4), (12, 1, 2), (14, 2, 2)],
        [(0, 5, 2), (2, 4, 2), (4, 3, 2), (6, 4, 2), (8, 5, 4), (12, 7, 4)],
        [(0, 3, 2), (2, 2, 2), (4, 0, 4), (10, 1, 2), (12, 0, 4)],
    ]

    def fn(bar, tones):
        phrase = motifs[bar % 4] if bar < 8 else motifs[(bar + 2) % 4]
        out = []
        for s16, idx, ln in phrase:
            n = scale[min(idx + (1 if bar >= 8 and bar % 2 == 0 else 0), len(scale) - 1)]
            out.append((s16, n, ln))
        return out
    return fn


def menu_melody():
    scale = [67, 69, 72, 74, 76, 79, 81]
    pattern = [[(0, 2, 6), (8, 4, 6)], [(0, 3, 4), (6, 2, 4), (12, 1, 4)],
               [(0, 4, 6), (8, 5, 8)], [(0, 3, 6), (8, 2, 8)]]

    def fn(bar, tones):
        return [(s, scale[i], ln) for s, i, ln in pattern[bar % 4]]
    return fn


def write_ogg(name, x):
    tmp = os.path.join(ROOT, "music", name + ".tmp.wav")
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    out = os.path.join(ROOT, "music", name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "2", out], check=True)
    os.remove(tmp)


def make_music():
    # C - Am - F - G, then F - G - Em - Am variation
    chords = [(60, ""), (57, "m"), (53, ""), (55, ""), (60, ""), (57, "m"), (53, ""), (55, ""),
              (53, ""), (55, ""), (52, "m"), (57, "m"), (53, ""), (55, ""), (60, ""), (55, "")]
    battle = render_song(140, 16, chords, battle_melody(), drums=True, swing=0.12)
    write_ogg("battle", battle)

    calm = [(60, ""), (55, ""), (57, "m"), (53, "")]
    menu = render_song(92, 8, calm, menu_melody(), drums=False, lead_shape="tri", arp=True,
                       bass_shape="sine", lead_gain=0.4)
    write_ogg("menu", menu)

    boss_chords = [(57, "m"), (57, "m"), (53, ""), (52, "")] * 2
    boss = render_song(152, 8, boss_chords, battle_melody(), drums=True, lead_shape="saw", lead_gain=0.22)
    write_ogg("boss", boss)


if __name__ == "__main__":
    os.makedirs(os.path.join(ROOT, "sfx"), exist_ok=True)
    os.makedirs(os.path.join(ROOT, "music"), exist_ok=True)
    make_sfx()
    make_music()
    print("audio generated in", os.path.abspath(ROOT))
