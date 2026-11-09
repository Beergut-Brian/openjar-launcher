#!/usr/bin/env python3
"""Regenerate every launcher sound from parameters. Standard library + ffmpeg only.

    python3 assets/audio/tools/make_cues.py                       # all cues
    python3 assets/audio/tools/make_cues.py ui_move_1 launch      # just these files
    python3 assets/audio/tools/make_cues.py --spectrograms handoff/spectrograms
    python3 assets/audio/tools/make_cues.py --keep-wav /tmp/oj-wav

Every sound is synthesised here (additive partials, filtered noise), seeded so the output is
reproducible. WAV sources go to a temp dir and never into git. Each file is then encoded to
Ogg Vorbis q5 at 44.1 kHz and loudness-normalised with ffmpeg:
  - SFX of 0.6 s or more: -16 LUFS integrated.
  - shorter SFX: the cue looped 10x is measured, so "as loud as the rest while it sounds";
    a per-cue trim lets frequent cues (ui_move) sit a little lower.
  - music: -20 LUFS, under the SFX.
  - everything: true peak at or below -1 dBTP (checked after encoding).
Nothing is allowed above 9.5 kHz in the synths (partials are dropped, noise is low-passed):
small ears and TV tweeters both hate fizz up there.
"""
import argparse
import math
import os
import random
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import wave

SR = 44100
TAU = 2.0 * math.pi
PARTIAL_CEILING = 9500.0

AUDIO_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_TARGET = -16.0
MUSIC_TARGET = -20.0
TP_CEILING = -1.0
SHORT_CUE = 0.6


# ---------------------------------------------------------------- primitives

def midi(n):
    return 440.0 * 2.0 ** ((n - 69) / 12.0)


def silence(sec):
    return [0.0] * int(round(sec * SR))


def mix(dst, src, at=0.0, gain=1.0, wrap=False):
    """Add src into dst at `at` seconds. wrap=True folds overhang back to the start (loops)."""
    o = int(round(at * SR))
    n = len(dst)
    if wrap:
        for i, s in enumerate(src):
            dst[(o + i) % n] += s * gain
    else:
        for i in range(max(0, -o), min(len(src), n - o)):
            dst[o + i] += src[i] * gain
    return dst


def osc(dur, freq, partials=((1, 1.0, 1.0),), decay=None, attack=0.002, amp=None):
    """Additive oscillator. freq: Hz or f(t). partials: (ratio, gain, decay_scale); partial k
    decays as exp(-t * decay_scale / decay). amp: optional overall envelope f(t).
    Partials above PARTIAL_CEILING are skipped."""
    n = int(dur * SR)
    out = [0.0] * n
    ph = [0.0] * len(partials)
    fixed = not callable(freq)
    for i in range(n):
        t = i / SR
        f = freq if fixed else freq(t)
        s = 0.0
        for k, (r, g, ds) in enumerate(partials):
            fk = f * r
            ph[k] += TAU * fk / SR
            if fk < PARTIAL_CEILING:
                s += (g if decay is None else g * math.exp(-t * ds / decay)) * math.sin(ph[k])
        a = min(1.0, t / attack) if attack > 0 else 1.0
        if amp is not None:
            a *= amp(t)
        out[i] = s * a
    return fades(out, 0.0, 0.003)   # never stop a ringing partial dead


def noise(sec, rng):
    return [rng.uniform(-1.0, 1.0) for _ in range(int(sec * SR))]


def envelope(x, fn):
    return [v * fn(i / SR) for i, v in enumerate(x)]


def svf(x, fc, q=0.707, mode="low", circular=False):
    """TPT state-variable filter. fc: Hz or f(t). circular: run twice so the state at the
    start equals the state at the end (seamless loops)."""
    k = 1.0 / q
    ic1 = ic2 = 0.0
    out = [0.0] * len(x)
    moving = callable(fc)

    def coeffs(f):
        g = math.tan(math.pi * min(f, SR * 0.45) / SR)
        a1 = 1.0 / (1.0 + g * (g + k))
        return a1, g * a1, g * g * a1

    a1, a2, a3 = coeffs(fc) if not moving else (0, 0, 0)
    for _ in range(2 if circular else 1):
        for i, v in enumerate(x):
            if moving:
                a1, a2, a3 = coeffs(fc(i / SR))
            v3 = v - ic2
            v1 = a1 * ic1 + a2 * v3
            v2 = ic2 + a2 * ic1 + a3 * v3
            ic1 = 2.0 * v1 - ic1
            ic2 = 2.0 * v2 - ic2
            out[i] = v2 if mode == "low" else (k * v1 if mode == "band" else v - k * v1 - v2)
    return out


def soft(x, fc, circular=False):
    """4-pole low-pass (two cascaded SVFs): keeps noise sources out of the top octave."""
    return svf(svf(x, fc, circular=circular), fc, circular=circular)


def dc_block(x, circular=False):
    r = 0.9972  # ~20 Hz
    x1 = y1 = 0.0
    out = [0.0] * len(x)
    for _ in range(2 if circular else 1):
        for i, v in enumerate(x):
            y1 = v - x1 + r * y1
            x1 = v
            out[i] = y1
    return out


def fades(x, fade_in=0.001, fade_out=0.02):
    n = len(x)
    fi, fo = max(1, int(fade_in * SR)), max(1, int(fade_out * SR))
    for i in range(min(fi, n)):
        x[i] *= i / fi
    for i in range(min(fo, n)):
        x[n - 1 - i] *= (i / fo) ** 2
    return x


def limit(x, threshold, lookahead=0.002, release=0.06):
    """Lookahead peak limiter: shaves transients so loudness can rise under the peak ceiling."""
    n = len(x)
    la = int(lookahead * SR)
    need = [min(1.0, threshold / abs(v)) if v else 1.0 for v in x]
    gain = [1.0] * n
    for i in range(n):   # n is small (SFX only), so a plain window minimum is fine
        gain[i] = min(need[max(0, i - la):i + la + 1])
    rel = math.exp(-1.0 / (release * SR))
    g = 1.0
    for i in range(n):
        g = gain[i] if gain[i] < g else gain[i] + (g - gain[i]) * rel
        gain[i] = g
    return [v * gain[i] for i, v in enumerate(x)]


def peak_normalise(x, peak=0.5):
    m = max(abs(v) for v in x) or 1.0
    return [v * peak / m for v in x]


# ---------------------------------------------------------------- instruments

MARIMBA = ((1, 1.0, 1.0), (3.98, 0.30, 3.0), (9.85, 0.06, 6.0))
XYLO = ((1, 1.0, 1.0), (3.0, 0.28, 2.5), (6.1, 0.07, 5.0))
BELL = ((1, 1.0, 1.0), (2.76, 0.40, 1.8), (5.40, 0.12, 3.0), (8.93, 0.04, 4.0))
WOOD = ((1, 1.0, 1.0), (2.57, 0.35, 1.6), (4.80, 0.12, 2.6))


def mallet(rng, fc=3000.0, sec=0.005, gain=0.25):
    n = int(sec * SR)
    x = [rng.uniform(-1, 1) * (1 - i / n) ** 2 for i in range(n)]
    return [v * gain for v in svf(x, fc)]


def struck(f, decay, rng, partials=MARIMBA, vel=1.0, click=0.2):
    """Marimba / xylophone / bell note: decaying partials plus a mallet tick."""
    x = osc(min(decay * 7.0, 3.0), f, partials, decay=decay, attack=0.0015)
    mix(x, mallet(rng, fc=min(4000.0, f * 4.0)), 0.0, click)
    return [v * vel for v in x]


def formant(x):
    return (0.25 + math.exp(-((x - 650) / 260) ** 2) + 0.6 * math.exp(-((x - 1700) / 420) ** 2)
            + 0.25 * math.exp(-((x - 2800) / 500) ** 2))


def kazoo(f, sec, vib_rate=5.5, vib_depth=0.012, attack=0.015, release=0.06):
    """Buzzy, voice-like toy horn: band-limited saw shaped by fixed formants, with vibrato."""
    parts = []
    n = 1
    while n * f < PARTIAL_CEILING:
        parts.append((n, formant(n * f) / n, 0.0))
        n += 1
    total = sec

    def amp(t):
        return min(1.0, (total - t) / release) if t > total - release else 1.0

    def freq(t):
        return f * (1.0 + vib_depth * min(1.0, t / 0.12) * math.sin(TAU * vib_rate * t))

    return osc(sec, freq, tuple(parts), attack=attack, amp=amp)


def chirp(f0, f1, sec, partials=((1, 1.0, 0.0),), attack=0.004):
    """Pitch glide f0 -> f1 (exponential) with a rounded envelope."""
    return osc(sec, lambda t: f0 * (f1 / f0) ** min(1.0, t / sec), partials, attack=attack,
               amp=lambda t: math.sin(math.pi * min(1.0, t / sec)) ** 0.6)


def sparkle(rng, count, start, end, gain=0.12, notes=(96, 98, 100, 103, 105)):
    """A few quiet glockenspiel pings from a high C-major pentatonic."""
    out = silence(end + 0.3)
    for _ in range(count):
        mix(out, struck(midi(rng.choice(notes)), 0.05, rng, BELL, click=0.05),
            rng.uniform(start, end), gain * rng.uniform(0.6, 1.0))
    return out


def chord(notes, decay, rng, partials=MARIMBA, vel=1.0):
    out = silence(min(decay * 7.0, 3.0) + 0.01)
    for n in notes:
        mix(out, struck(midi(n), decay, rng, partials, click=0.12), 0.0, vel / len(notes) ** 0.5)
    return out


# ---------------------------------------------------------------- cues
# Each returns raw samples at any scale; finish() cleans them up.

def ui_move(note):
    def make(rng):
        # Soft wooden block tick; three neighbouring pitches so runs of moves sound like a tune.
        x = silence(0.09)
        f = midi(note)
        mix(x, osc(0.09, f, WOOD, decay=0.018, attack=0.0008))
        mix(x, osc(0.05, f * 0.5, decay=0.012, attack=0.001), 0.0, 0.35)
        mix(x, mallet(rng, fc=2500.0, gain=0.3))
        return svf(x, 5000.0)
    return make


def ui_confirm(rng):
    x = silence(0.25)
    mix(x, struck(midi(79), 0.09, rng, XYLO), 0.0, 0.8)     # G5
    mix(x, struck(midi(84), 0.12, rng, XYLO), 0.07, 1.0)    # C6, up a fourth: "yes!"
    mix(x, struck(midi(84), 0.10, rng, BELL, click=0.0), 0.07, 0.25)
    mix(x, sparkle(rng, 4, 0.10, 0.19, gain=0.16))
    return fades(x, fade_out=0.05)


def ui_back(rng):
    # D5 sliding down to G4, round and soft: "boop", not a buzzer.
    x = osc(0.2, lambda t: midi(74) * (midi(67) / midi(74)) ** min(1.0, t / 0.14),
            ((1, 1.0, 0.0), (2, 0.22, 0.0), (3, 0.06, 0.0)), attack=0.006,
            amp=lambda t: math.exp(-t / 0.09))
    return fades(svf(x, 2500.0), fade_out=0.04)


def ui_toggle(rng):
    x = silence(0.25)
    # Clunk: a low wooden knock, like a big toy switch.
    mix(x, osc(0.08, lambda t: 140.0 + 70.0 * math.exp(-t / 0.02),
               ((1, 1.0, 1.0), (2.3, 0.35, 2.0)), decay=0.025, attack=0.001))
    mix(x, envelope(svf(noise(0.03, rng), 1200.0), lambda t: math.exp(-t / 0.006)), 0.0, 0.5)
    # Ding: one metallic bell, distinct from the confirm xylophone.
    mix(x, struck(midi(91), 0.08, rng, BELL, click=0.0), 0.06, 0.55)   # G6
    return fades(x, fade_out=0.05)


def pause(rng):
    # Muted plink: short marimba E6 with the brightness filtered off.
    x = silence(0.14)
    mix(x, struck(midi(88), 0.035, rng, MARIMBA, click=0.1))
    return fades(svf(x, 3000.0), fade_out=0.03)


def player_join(rng):
    x = silence(0.23)
    toy = ((1, 1.0, 0.0), (2, 0.12, 0.0), (3, 0.15, 0.0))
    mix(x, chirp(midi(72), midi(79), 0.07, toy))            # C5 -> G5
    mix(x, chirp(midi(79), midi(86), 0.10, toy), 0.11)      # G5 -> D6: "here I am!"
    return fades(svf(x, 4500.0), fade_out=0.02)


def intro_pop(rng):
    x = silence(1.2)
    # Snap of the lid coming off.
    mix(x, envelope(soft(noise(0.006, rng), 5000.0), lambda t: math.exp(-t / 0.0015)), 0.0, 0.9)
    # Cork-style rising resonance: the POP.
    mix(x, osc(0.2, lambda t: 300.0 + 600.0 * (1 - math.exp(-t / 0.012)),
               ((1, 1.0, 1.0), (2, 0.2, 1.5)), decay=0.05, attack=0.0008))
    # Lid body.
    mix(x, osc(0.12, lambda t: 110.0 + 60.0 * math.exp(-t / 0.02),
               ((1, 1.0, 1.0), (2, 0.4, 1.5)), decay=0.04, attack=0.001), 0.0, 0.5)
    # Fizz: crackles + hiss + soda bubbles, all thinning out.
    crack = silence(1.2)
    t = 0.03
    while t < 1.1:
        burst = envelope(noise(0.0015, rng), lambda u: 1 - u / 0.0015)
        mix(crack, burst, t, rng.uniform(0.05, 0.2) * math.exp(-t / 0.35))
        t += rng.expovariate(250.0 * math.exp(-t / 0.25) + 15.0)
    mix(x, soft(svf(crack, 3500.0, 0.8, "band"), 7000.0), 0.0, 1.4)
    hiss = envelope(svf(noise(1.2, rng), 3000.0, 0.6, "band"),
                    lambda u: 0.06 * math.exp(-u / 0.3) * min(1.0, u / 0.03))
    mix(x, soft(hiss, 7000.0), 0.03)
    for _ in range(16):
        at = 0.06 + rng.random() ** 1.6 * 0.85
        f0 = rng.uniform(700.0, 1600.0)
        mix(x, chirp(f0, f0 * 1.6, 0.03), at, 0.28 * math.exp(-at / 0.45))
    return fades(x, fade_out=0.15)


def intro_thump(rng):
    x = silence(1.3)
    # The landing: a pitch-dropping kick with harmonics so TV speakers still feel it.
    mix(x, osc(0.4, lambda t: 50.0 + 100.0 * math.exp(-t / 0.04),
               ((1, 1.0, 0.0), (2, 0.5, 0.0), (3, 0.2, 0.0)), attack=0.001,
               amp=lambda t: math.exp(-t / 0.11)))
    mix(x, envelope(svf(noise(0.06, rng), 500.0), lambda t: math.exp(-t / 0.015)), 0.0, 0.7)
    # Boing: twangy spring that wobbles to rest.
    twang = tuple((n, 1.0 / n ** 0.8, 0.6 + 0.4 * n) for n in range(1, 8))
    mix(x, osc(1.2, lambda t: midi(52) * (1.0 + 0.5 * math.exp(-t / 0.015))
               * (1.0 + 0.14 * math.exp(-t / 0.35) * math.sin(TAU * 9.0 * t)),
               twang, decay=0.45, attack=0.004, amp=lambda t: min(1.0, (1.2 - t) / 0.3)), 0.03, 0.45)
    return fades(svf(x, 6000.0), fade_out=0.15)


def launch(rng):
    x = silence(1.15)
    # Whoosh up: band-passed noise sweeping 300 Hz -> 3.6 kHz, swelling.
    mix(x, envelope(soft(svf(noise(0.58, rng), lambda t: 300.0 * 12.0 ** min(1.0, t / 0.55), 1.2,
                             "band"), 6000.0),
                    lambda t: math.sin(0.5 * math.pi * min(1.0, t / 0.5)) ** 2
                    * (1.0 if t < 0.5 else max(0.0, 1 - (t - 0.5) / 0.08))), 0.0, 0.7)
    # Slide whistle riding the whoosh.
    mix(x, osc(0.52, lambda t: 500.0 * 3.2 ** (t / 0.52), ((1, 1.0, 0.0), (2, 0.08, 0.0)),
               attack=0.02, amp=lambda t: (t / 0.52) ** 1.5 * min(1.0, (0.52 - t) / 0.03)), 0.0, 0.22)
    # Ta...
    mix(x, chord((72, 76, 79), 0.08, rng), 0.52, 0.8)
    for n in (72, 76, 79):
        mix(x, kazoo(midi(n), 0.09), 0.52, 0.10)
    # ...DA!
    mix(x, chord((72, 76, 79, 84), 0.25, rng), 0.66, 1.0)
    for n in (72, 76, 79):
        mix(x, kazoo(midi(n), 0.42), 0.66, 0.13)
    mix(x, sparkle(rng, 3, 0.72, 0.9, gain=0.14))
    return fades(x, fade_out=0.15)


def round_start(rng):
    x = silence(0.9)
    for i, n in enumerate((67, 72, 76)):                       # G4 C5 E5: ready, set...
        mix(x, struck(midi(n), 0.12, rng), i * 0.11, 0.7)
    mix(x, chord((79, 84), 0.3, rng, XYLO), 0.33, 1.0)          # ...go!
    mix(x, kazoo(midi(79), 0.25), 0.33, 0.12)
    mix(x, sparkle(rng, 3, 0.38, 0.55))
    return fades(x, fade_out=0.15)


def round_end(rng):
    x = silence(0.95)
    mix(x, kazoo(midi(67), 0.1), 0.0, 0.18)                      # ta
    mix(x, struck(midi(79), 0.08, rng), 0.0, 0.6)
    for n in (72, 76, 79):                                       # DA
        mix(x, kazoo(midi(n), 0.55, vib_depth=0.018), 0.14, 0.14)
    mix(x, chord((72, 76, 79, 84), 0.3, rng), 0.14, 0.9)
    mix(x, sparkle(rng, 4, 0.2, 0.5))
    return fades(x, fade_out=0.15)


# ---------------------------------------------------------------- music

BPM = 105                      # 44100 * 60 / 105 = 25200 samples per beat, exactly
BEAT = SR * 60 // BPM
BARS = 8
CHORDS = [  # (bass root, triad) per bar: C | Am | F | G | C | Am | F | G
    (36, (60, 64, 67)), (45, (57, 60, 64)), (41, (57, 60, 65)), (43, (59, 62, 67)),
    (36, (60, 64, 67)), (45, (57, 60, 64)), (41, (57, 60, 65)), (43, (59, 62, 67)),
]
MELODY = [  # eighth notes, None = rest
    72, None, 76, 79, None, 76, 74, None,
    72, None, 76, None, 81, 79, 76, None,
    77, None, 81, 77, None, 76, 74, 72,
    74, None, 79, None, 83, None, 79, None,
    79, None, 76, 79, 84, None, 79, 76,
    76, None, 72, 76, 81, None, 79, None,
    77, 76, 74, None, 72, None, 69, 72,
    74, None, 71, 74, 79, None, 77, 74,
]


def card_row_loop(rng):
    n = BEAT * 4 * BARS
    out = [0.0] * n
    beat_s = BEAT / SR

    def at(beat):
        return beat * beat_s

    def human():
        return rng.uniform(-0.004, 0.004)

    for i, note in enumerate(MELODY):
        if note is not None:
            accent = 1.0 if i % 2 == 0 else 0.85
            mix(out, struck(midi(note), 0.28, rng, MARIMBA, click=0.18),
                at(i * 0.5) + human(), 0.8 * accent * rng.uniform(0.9, 1.05), wrap=True)
    shaker = [0.0] * n
    for bar, (root, triad) in enumerate(CHORDS):
        b0 = bar * 4
        # Off-beat marimba stabs: the bounce.
        for off in (0.5, 1.5, 2.5, 3.5):
            for note in triad:
                mix(out, struck(midi(note), 0.07, rng, MARIMBA, click=0.1),
                    at(b0 + off) + human(), 0.22 * rng.uniform(0.85, 1.0), wrap=True)
        # Soft plucked bass: root, fifth, root, octave, fifth.
        for off, step, vel, dec in ((0, 0, 1.0, 0.3), (1.5, 7, 0.55, 0.15), (2, 0, 0.85, 0.25),
                                    (3, 12, 0.5, 0.12), (3.5, 7, 0.5, 0.12)):
            note = osc(min(dec * 6, 1.2), midi(root + step),
                       ((1, 1.0, 1.0), (2, 0.45, 1.6), (3, 0.18, 2.5)), decay=dec, attack=0.004)
            mix(out, note, at(b0 + off), 0.9 * vel, wrap=True)
        # Light shaker on sixteenths, accents on the "and".
        for s in range(16):
            burst = envelope(noise(0.06, rng),
                             lambda t: min(1.0, t / 0.004) * math.exp(-t / 0.018))
            mix(shaker, burst, at(b0 + s * 0.25) + human() * 0.5,
                (0.5, 0.25, 0.9, 0.3)[s % 4] * rng.uniform(0.8, 1.0), wrap=True)
    mix(out, soft(svf(shaker, 5000.0, 0.9, "band", circular=True), 7500.0, circular=True),
        0.0, 0.10)
    return dc_block(soft(out, 9500.0, circular=True), circular=True)


# Hub launch moment. Placeholders from the hub lane: the Audio lane is welcome to replace them.
TIN = ((1, 1.0, 1.0), (2.32, 0.5, 1.4), (3.9, 0.3, 2.0), (5.4, 0.15, 2.6))


def jar_rattle(rng):
    """The lid rattling on the jar, faster and higher as the pressure builds."""
    x = silence(0.55)
    t, k = 0.0, 0
    while t < 0.48:
        f = 520.0 * (1.0 + 0.9 * t / 0.48) * (1.0 if k % 2 == 0 else 1.19)
        mix(x, osc(0.07, f, TIN, decay=0.012, attack=0.0008), t, 0.5 + 0.5 * t / 0.48)
        t += 0.075 - 0.045 * (t / 0.48)
        k += 1
    return fades(svf(x, 6000.0), fade_out=0.03)


def jarling_jump(rng):
    """Slide-whistle "hup!" as the Jarling takes off."""
    x = silence(0.42)
    toy = ((1, 1.0, 0.0), (2, 0.25, 0.0), (3, 0.08, 0.0))
    mix(x, chirp(midi(64), midi(88), 0.36, toy))
    mix(x, envelope(svf(noise(0.3, rng), 1800.0, 0.8, "band"),
                    lambda t: 0.12 * math.sin(math.pi * min(1.0, t / 0.3))), 0.03)
    return fades(svf(x, 5000.0), fade_out=0.04)


def lid_land(rng):
    """The lid lands on somebody's head: tin "tonk" that wobbles like a spun coin."""
    x = silence(0.6)
    mix(x, osc(0.5, lambda t: 330.0 * (1.0 + 0.05 * math.exp(-t / 0.2) * math.sin(TAU * (9.0 + 30.0 * t) * t)),
               TIN, decay=0.11, attack=0.001))
    mix(x, mallet(rng, 2500.0), 0.0, 0.6)
    return fades(svf(x, 5500.0), fade_out=0.08)


def jar_splash(rng):
    """Plop into the jar and a splash of sparkles."""
    x = silence(0.9)
    mix(x, osc(0.16, lambda t: 240.0 + 520.0 * (1 - math.exp(-t / 0.03)),
               ((1, 1.0, 1.0), (2, 0.2, 1.5)), decay=0.05, attack=0.001), 0.0, 0.9)
    for i, n in enumerate((84, 88, 91, 96, 100, 103)):
        mix(x, struck(midi(n), 0.07, rng, BELL, click=0.05), 0.05 + i * 0.045, 0.2)
    mix(x, sparkle(rng, 8, 0.25, 0.55, 0.1))
    return fades(x, fade_out=0.15)


def jar_pop_out(rng):
    """Back from a game: the Jarling pops out of the jar, "boi-oing!"."""
    x = silence(0.5)
    mix(x, osc(0.12, lambda t: 300.0 + 500.0 * (1 - math.exp(-t / 0.012)),
               ((1, 1.0, 1.0), (2, 0.2, 1.5)), decay=0.04, attack=0.0008))
    toy = ((1, 1.0, 0.0), (2, 0.2, 0.0), (3, 0.1, 0.0))
    mix(x, chirp(midi(84), midi(72), 0.14, toy), 0.06, 0.6)
    mix(x, chirp(midi(72), midi(86), 0.2, toy), 0.2, 0.7)
    return fades(svf(x, 5000.0), fade_out=0.04)


def lid_bonk(rng):
    """The lid drops back on the jar: a round tin BONK with a short boing."""
    x = silence(0.7)
    mix(x, osc(0.3, lambda t: 70.0 + 90.0 * math.exp(-t / 0.03),
               ((1, 1.0, 0.0), (2, 0.5, 0.0)), attack=0.001, amp=lambda t: math.exp(-t / 0.07)))
    mix(x, osc(0.6, lambda t: 262.0 * (1.0 + 0.1 * math.exp(-t / 0.12) * math.sin(TAU * 11.0 * t)),
               TIN, decay=0.13, attack=0.001), 0.0, 0.7)
    mix(x, mallet(rng, 2000.0), 0.0, 0.7)
    return fades(svf(x, 5500.0), fade_out=0.1)


# ---------------------------------------------------------------- registry
# file stem -> (make, kind, trim dB). kind: "sfx" or "music". Trim lowers frequent cues.

FILES = {
    "ui_move_1": (ui_move(77), "sfx", -4.0),
    "ui_move_2": (ui_move(79), "sfx", -4.0),
    "ui_move_3": (ui_move(81), "sfx", -4.0),
    "ui_confirm": (ui_confirm, "sfx", 0.0),
    "ui_back": (ui_back, "sfx", -1.0),
    "ui_toggle": (ui_toggle, "sfx", 0.0),
    "intro_pop": (intro_pop, "sfx", 0.0),
    "intro_thump": (intro_thump, "sfx", 0.0),
    "launch": (launch, "sfx", 0.0),
    "player_join": (player_join, "sfx", 0.0),
    "round_start": (round_start, "sfx", 0.0),
    "round_end": (round_end, "sfx", 0.0),
    "pause": (pause, "sfx", -2.0),
    "jar_rattle": (jar_rattle, "sfx", 0.0),
    "jarling_jump": (jarling_jump, "sfx", 0.0),
    "lid_land": (lid_land, "sfx", 0.0),
    "jar_splash": (jar_splash, "sfx", 0.0),
    "jar_pop_out": (jar_pop_out, "sfx", 0.0),
    "lid_bonk": (lid_bonk, "sfx", 0.0),
    "card_row_loop": (card_row_loop, "music", 0.0),
}


# ---------------------------------------------------------------- ffmpeg

def write_wav(path, x):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(3)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<i", int(round(max(-1.0, min(1.0, v)) * 8388607)))[:3]
                               for v in x))


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True, check=True)


def measure(path, tile=1):
    """(integrated LUFS, true peak dBTP) via ebur128. tile > 1 loops the input first."""
    cmd = ["ffmpeg", "-hide_banner", "-nostats"]
    if tile > 1:
        cmd += ["-stream_loop", str(tile - 1)]
    cmd += ["-i", path, "-af", "ebur128=peak=true", "-f", "null", "-"]
    err = run(cmd).stderr
    summary = err[err.rfind("Summary:"):]
    num = r"(-?inf|-?\d+(?:\.\d+)?)"
    lufs = float(re.search(r"I:\s+" + num + r" LUFS", summary).group(1))
    peak = float(re.search(r"True peak:\s+Peak:\s+" + num, summary).group(1))
    return lufs, peak


def rms_db(path, highpass=None):
    af = "astats=metadata=0"
    if highpass:
        af = "highpass=f=%d,highpass=f=%d,highpass=f=%d," % ((highpass,) * 3) + af
    err = run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", af, "-f", "null", "-"]).stderr
    return float(re.findall(r"RMS level dB:\s+(-?inf|-?\d+(?:\.\d+)?)", err)[-1])


def dc_offset(path):
    err = run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", "astats=metadata=0",
               "-f", "null", "-"]).stderr
    return float(re.findall(r"DC offset:\s+(-?\d+(?:\.\d+)?)", err)[-1])


def duration(path):
    out = run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-count_packets",
               "-show_entries", "stream=duration_ts,sample_rate,duration", "-of",
               "default=nw=1", path]).stdout
    return float(re.search(r"duration=([\d.]+)", out).group(1))


def decoded_samples(path):
    raw = run_bytes(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "1", "-"])
    return struct.unpack("<%df" % (len(raw) // 4), raw)


def run_bytes(cmd):
    return subprocess.run(cmd, capture_output=True, check=True).stdout


def encode(wav, ogg, gain_db):
    run(["ffmpeg", "-y", "-hide_banner", "-v", "error", "-i", wav, "-af", "volume=%.2fdB" % gain_db,
         "-ar", str(SR), "-c:a", "libvorbis", "-q:a", "5", "-map_metadata", "-1",
         "-fflags", "+bitexact", "-flags:a", "+bitexact", ogg])


def build(stem, tmp):
    make, kind, trim = FILES[stem]
    rng = random.Random("openjar-launcher:" + stem)
    x = make(rng)
    if kind == "sfx":
        x = fades(dc_block(soft(x, 9500.0)), 0.001, 0.005)
    x = peak_normalise(x, 0.5)
    wav = os.path.join(tmp, stem + ".wav")
    write_wav(wav, x)
    secs = len(x) / SR
    tile = 10 if kind == "sfx" and secs < SHORT_CUE else 1
    target = (MUSIC_TARGET if kind == "music" else SFX_TARGET) + trim
    lufs, peak = measure(wav, tile)
    short_by = (target - lufs) - (TP_CEILING - 0.3 - peak)
    if kind == "sfx" and short_by > 0.5:
        # Peak-bound, not loudness-bound: limit the transients (at most 8 dB) and re-measure.
        x = peak_normalise(limit(x, 0.5 * 10.0 ** (-min(short_by, 8.0) / 20.0)), 0.5)
        write_wav(wav, x)
        lufs, peak = measure(wav, tile)
    gain = min(target - lufs, TP_CEILING - 0.3 - peak)
    out_dir = os.path.join(AUDIO_DIR, "music" if kind == "music" else "sfx")
    ogg = os.path.join(out_dir, stem + ".ogg")
    for _ in range(4):   # Vorbis can push peaks up a little; back off until under the ceiling
        encode(wav, ogg, gain)
        lufs, peak = measure(ogg, tile)
        if peak <= TP_CEILING:
            break
        gain -= peak - TP_CEILING + 0.1
    file_lufs = measure(ogg)[0] if tile > 1 else lufs
    return {"stem": stem, "ogg": ogg,
            "kind": kind, "seconds": duration(ogg), "lufs": file_lufs,
            "active_lufs": lufs if tile > 1 else None, "true_peak": peak, "target": target,
            "hf_db": rms_db(ogg, 10000) - rms_db(ogg), "dc": dc_offset(ogg),
            "samples_in": len(x)}


def loop_seam(ogg, samples_in):
    """Decoded length must equal the rendered length; the jump across the seam should look
    like an ordinary sample-to-sample step."""
    y = decoded_samples(ogg)
    steps = [abs(y[i + 1] - y[i]) for i in range(len(y) - 1)]
    typical = sorted(steps)[int(len(steps) * 0.99)]
    return {"decoded": len(y), "rendered": samples_in, "first": y[0], "last": y[-1],
            "seam_step": abs(y[0] - y[-1]), "p99_step": typical, "max_step": max(steps)}


def spectrogram(ogg, out_png):
    run(["ffmpeg", "-y", "-hide_banner", "-v", "error", "-i", ogg, "-filter_complex",
         "[0:a]asplit[a][b];[a]showspectrumpic=s=640x240:legend=0:stop=16000[s];"
         "[b]showwavespic=s=640x120:colors=white[w];[s][w]vstack", "-frames:v", "1", out_png])


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("only", nargs="*", help="file stems to build (default: all)")
    ap.add_argument("--keep-wav", help="write WAV sources here instead of a deleted temp dir")
    ap.add_argument("--spectrograms", help="also render <stem>.png spectrogram+waveform here")
    args = ap.parse_args()
    stems = args.only or list(FILES)
    unknown = [s for s in stems if s not in FILES]
    if unknown:
        sys.exit("unknown stem(s): %s (known: %s)" % (", ".join(unknown), ", ".join(FILES)))
    tmp = args.keep_wav or tempfile.mkdtemp(prefix="oj-cues-")
    os.makedirs(tmp, exist_ok=True)
    if args.spectrograms:
        os.makedirs(args.spectrograms, exist_ok=True)
    print("%-16s %-5s %7s %9s %9s %8s %8s %8s" % ("file", "kind", "sec", "LUFS", "active", "TP dB",
                                                 ">10k dB", "DC"))
    try:
        for stem in stems:
            r = build(stem, tmp)
            act = "%9.1f" % r["active_lufs"] if r["active_lufs"] is not None else "%9s" % "-"
            print("%-16s %-5s %7.3f %9.1f %s %8.1f %8.1f %8.5f" % (
                stem, r["kind"], r["seconds"], r["lufs"], act, r["true_peak"], r["hf_db"], r["dc"]))
            if r["kind"] == "music":
                s = loop_seam(r["ogg"], r["samples_in"])
                print("  loop: decoded %d / rendered %d samples, first %.4f last %.4f, seam step %.4f "
                      "(p99 step %.4f, max %.4f)" % (s["decoded"], s["rendered"], s["first"], s["last"],
                                                     s["seam_step"], s["p99_step"], s["max_step"]))
            if args.spectrograms:
                spectrogram(r["ogg"],
                            os.path.join(args.spectrograms, stem + ".png"))
    finally:
        if not args.keep_wav:
            shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()
