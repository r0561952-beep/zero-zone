#!/usr/bin/env python3
"""
ZERO ZONE — процедурный синтез звуков окружения.

Все звуки создаются математически (шум, фильтры, осцилляторы) — собственные ассеты проекта, CC0.
Результат: assets/audio/*.ogg (Vorbis через ffmpeg; если ffmpeg нет — WAV).
"""
import os
import shutil
import subprocess
import wave

import numpy as np
from scipy import signal

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")
SR = 22050
rng = np.random.default_rng(42)


def t(sec):
    return np.arange(int(sec * SR)) / SR


def noise(sec):
    return rng.standard_normal(int(sec * SR))


def lp(x, hz, order=2):
    b, a = signal.butter(order, hz / (SR / 2), "low")
    return signal.lfilter(b, a, x)


def hp(x, hz, order=2):
    b, a = signal.butter(order, hz / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def bp(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), hi / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def smooth_env(sec, rate_hz, lo=0.3, hi=1.0, seed=0):
    r = np.random.default_rng(seed)
    n = int(sec * rate_hz) + 2
    pts = r.random(n) * (hi - lo) + lo
    pts[-1] = pts[0]
    x = np.linspace(0, n - 1, int(sec * SR))
    return np.interp(x, np.arange(n), pts)


def loopify(x, fade=0.5):
    """Бесшовная петля: перекрёстное затухание конца в начало."""
    f = int(fade * SR)
    head = x[:f].copy()
    tail = x[-f:]
    w = np.linspace(0, 1, f)
    x = x[:-f].copy()
    x[:f] = head * w + tail * (1 - w)
    return x


def norm(x, peak=0.8):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def env_ad(n, attack, decay):
    a = int(attack * SR)
    e = np.exp(-np.arange(n) / (decay * SR))
    if a > 0:
        e[:a] *= np.linspace(0, 1, a)
    return e


def write(name, x, peak=0.8):
    os.makedirs(OUT, exist_ok=True)
    x = norm(x, peak)
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    wav_path = os.path.join(OUT, name + ".wav")
    with wave.open(wav_path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    if shutil.which("ffmpeg"):
        ogg = os.path.join(OUT, name + ".ogg")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-q:a", "3", ogg], check=True)
        os.remove(wav_path)


def gen():
    # --- Ветер: коричневый шум с порывами
    sec = 12
    n = np.cumsum(noise(sec)) * 0.02
    n = hp(n, 40)
    gust = smooth_env(sec, 0.35, 0.25, 1.0, 1)
    wind = bp(n * gust, 80, 900) + bp(noise(sec), 400, 1500) * gust ** 3 * 0.15
    write("wind_loop", loopify(wind, 1.5), 0.7)

    # --- Дождь снаружи
    sec = 8
    r = hp(noise(sec), 900) * 0.35 + lp(noise(sec), 500) * 0.25
    drops = np.zeros(int(sec * SR))
    idx = rng.integers(0, len(drops) - 400, 900)
    for i in idx:
        L = 200
        drops[i:i + L] += np.sin(np.arange(L) * rng.uniform(0.4, 1.2)) * np.exp(-np.arange(L) / 30) * rng.uniform(0.2, 1)
    write("rain_loop", loopify(r + hp(drops, 1500) * 0.6, 0.8), 0.7)

    # --- Дождь по крыше (в помещении): глухо + звонкие капли по жести
    r = lp(noise(sec), 700) * 0.6
    pings = np.zeros(int(sec * SR))
    for i in rng.integers(0, len(pings) - 2000, 500):
        L = 1600
        f = rng.uniform(1800, 3200)
        pings[i:i + L] += np.sin(2 * np.pi * f * np.arange(L) / SR) * np.exp(-np.arange(L) / 250) * rng.uniform(0.1, 0.6)
    write("rain_roof_loop", loopify(r + pings * 0.35, 0.8), 0.6)

    # --- Шелест листвы
    sec = 10
    leaves = bp(noise(sec), 1500, 6000) * smooth_env(sec, 0.8, 0.1, 1.0, 3) ** 2
    write("leaves_loop", loopify(leaves, 1.0), 0.5)

    # --- Сверчки (ночь)
    sec = 6
    tt = t(sec)
    chirp = np.zeros_like(tt)
    for k, (f, rate, ph) in enumerate([(4300, 2.1, 0.0), (4700, 1.7, 0.3), (3900, 2.6, 0.7)]):
        gate = (np.sin(2 * np.pi * rate * tt + ph * 6) > 0.6).astype(float)
        trill = (np.sin(2 * np.pi * 28 * tt) > 0).astype(float)
        chirp += np.sin(2 * np.pi * f * tt) * lp(gate * trill, 300) * (0.6 + 0.4 * k / 2)
    write("crickets_loop", loopify(chirp, 0.5), 0.35)

    # --- Птицы (одиночные)
    for k in range(4):
        sec = 1.2
        tt = t(sec)
        x = np.zeros_like(tt)
        start = 0.0
        for note in range(rng.integers(2, 6)):
            dur = rng.uniform(0.06, 0.16)
            f0 = rng.uniform(2200, 4200)
            f1 = f0 * rng.uniform(0.7, 1.4)
            m = (tt >= start) & (tt < start + dur)
            lt = tt[m] - start
            ph = 2 * np.pi * (f0 * lt + (f1 - f0) * lt ** 2 / (2 * dur))
            x[m] += np.sin(ph) * np.sin(np.pi * lt / dur) ** 2
            start += dur + rng.uniform(0.03, 0.12)
        write(f"bird_{k}", x, 0.5)

    # --- Ворона (карканье) — для дневной атмосферы
    sec = 0.9
    tt = t(sec)
    x = np.zeros_like(tt)
    for c in range(2):
        s0 = c * 0.38
        m = (tt >= s0) & (tt < s0 + 0.28)
        lt = tt[m] - s0
        saw = signal.sawtooth(2 * np.pi * (520 - lt * 300) * lt)
        x[m] += bp(saw, 600, 2600) * np.sin(np.pi * lt / 0.28)
    write("crow", x + bp(noise(sec), 900, 2000) * 0.05, 0.5)

    # --- Гул «Камертона»: биения 38/41 Гц + гармоники, слышимые на телефоне
    sec = 10
    tt = t(sec)
    hum = (np.sin(2 * np.pi * 38 * tt) + np.sin(2 * np.pi * 41 * tt) * 0.9
           + np.sin(2 * np.pi * 76 * tt) * 0.6 + np.sin(2 * np.pi * 114 * tt) * 0.35
           + np.sin(2 * np.pi * 152.5 * tt) * 0.25 + np.sin(2 * np.pi * 228 * tt) * 0.12)
    hum *= 0.75 + 0.25 * np.sin(2 * np.pi * 0.2 * tt)
    hum += lp(noise(sec), 120) * 0.4
    write("hum_loop", loopify(hum, 1.0), 0.85)

    # --- Предвестник гула (нарастание, далёкий звон)
    sec = 6
    tt = t(sec)
    swell = (np.sin(2 * np.pi * 76 * tt) + np.sin(2 * np.pi * 440 * tt) * 0.15 * np.exp(-tt * 0.6)
             + np.sin(2 * np.pi * 441.7 * tt) * 0.15 * np.exp(-tt * 0.6)) * np.linspace(0, 1, len(tt)) ** 2
    write("hum_warning", swell, 0.7)

    # --- Электрический гул (трансформатор, 50 Гц)
    sec = 4
    tt = t(sec)
    buzz = sum(np.sin(2 * np.pi * 50 * k * tt) / k for k in range(1, 10)) + hp(noise(sec), 3000) * 0.05
    write("electric_buzz_loop", loopify(buzz, 0.3), 0.5)

    # --- Костёр
    sec = 6
    fire = lp(noise(sec), 400) * 0.4
    for i in rng.integers(0, int(sec * SR) - 600, 260):
        L = 500
        fire[i:i + L] += hp(rng.standard_normal(L), 1500) * np.exp(-np.arange(L) / 60) * rng.uniform(0.3, 1.5)
    write("fire_loop", loopify(fire, 0.5), 0.6)

    # --- Шаги
    def step(lo, hi, dur, crunch, k):
        nn = int(dur * SR)
        base = bp(rng.standard_normal(nn), lo, hi) * env_ad(nn, 0.004, dur / 4)
        thump = lp(rng.standard_normal(nn), 180) * env_ad(nn, 0.002, 0.03) * 2.0
        cr = np.zeros(nn)
        for i in rng.integers(0, nn // 2, crunch):
            L = 120
            cr[i:i + L] += hp(rng.standard_normal(L), 2500) * np.exp(-np.arange(L) / 25)
        return base + thump + cr * 0.6

    for k in range(4):
        write(f"step_dirt_{k}", step(150, 1200, 0.22, 4, k), 0.6)
        write(f"step_gravel_{k}", step(400, 4000, 0.25, 30, k), 0.6)
        write(f"step_grass_{k}", step(800, 5000, 0.2, 8, k) * 0.7, 0.45)
    for k in range(3):
        nn = int(0.25 * SR)
        wood = bp(rng.standard_normal(nn), 120, 900) * env_ad(nn, 0.002, 0.05)
        wood += np.sin(2 * np.pi * rng.uniform(160, 220) * np.arange(nn) / SR) * env_ad(nn, 0.001, 0.06)
        write(f"step_wood_{k}", wood, 0.6)
        conc = hp(rng.standard_normal(nn), 900) * env_ad(nn, 0.001, 0.02) + lp(rng.standard_normal(nn), 300) * env_ad(nn, 0.001, 0.02)
        write(f"step_concrete_{k}", conc, 0.55)
        write(f"step_metal_{k}", conc * 0.5 + np.sin(2 * np.pi * 520 * np.arange(nn) / SR) * env_ad(nn, 0.001, 0.08) * 0.6, 0.55)

    # --- Скрип двери
    for k in range(2):
        sec = 1.3 if k == 0 else 0.9
        tt = t(sec)
        f = 300 + 180 * np.sin(2 * np.pi * (0.6 + k * 0.3) * tt) + rng.uniform(-30, 30)
        ph = 2 * np.pi * np.cumsum(f) / SR
        stick = (np.sin(2 * np.pi * 23 * tt) > 0.2).astype(float)
        creak = signal.sawtooth(ph) * lp(stick, 60) * np.sin(np.pi * tt / sec)
        write(f"door_creak_{k}", bp(creak, 400, 3500), 0.55)
    nn = int(0.4 * SR)
    write("door_close", lp(rng.standard_normal(nn), 250) * env_ad(nn, 0.001, 0.08) + bp(rng.standard_normal(nn), 300, 1500) * env_ad(nn, 0.001, 0.03), 0.8)
    write("door_locked", bp(rng.standard_normal(int(0.25 * SR)), 1000, 5000) * env_ad(int(0.25 * SR), 0.001, 0.02), 0.6)

    # --- Взаимодействие
    nn = int(0.3 * SR)
    write("pickup", bp(rng.standard_normal(nn), 800, 4000) * env_ad(nn, 0.02, 0.06), 0.45)
    write("rummage", bp(rng.standard_normal(int(0.9 * SR)), 300, 3000) * smooth_env(0.9, 12, 0.0, 1.0, 9), 0.5)
    nn = int(0.35 * SR)
    chop = lp(rng.standard_normal(nn), 900) * env_ad(nn, 0.001, 0.05) + np.sin(2 * np.pi * 140 * np.arange(nn) / SR) * env_ad(nn, 0.001, 0.08)
    write("chop", chop, 0.85)
    write("hit", lp(rng.standard_normal(nn), 300) * env_ad(nn, 0.001, 0.04), 0.9)
    nn = int(0.6 * SR)
    clank = sum(np.sin(2 * np.pi * f * np.arange(nn) / SR) * env_ad(nn, 0.001, d) for f, d in ((870, 0.12), (1310, 0.08), (2240, 0.05)))
    write("metal_clank", clank, 0.6)
    nn = int(0.8 * SR)
    glass = hp(rng.standard_normal(nn), 2500) * env_ad(nn, 0.001, 0.15)
    for f in (3100, 4300, 5200, 6100):
        glass += np.sin(2 * np.pi * f * np.arange(nn) / SR) * env_ad(nn, 0.001, 0.2) * 0.3
    write("glass_break", glass, 0.7)
    nn = int(0.5 * SR)
    write("eat", bp(rng.standard_normal(nn), 300, 2500) * smooth_env(0.5, 16, 0, 1, 11), 0.5)
    tt = t(0.6)
    write("drink", np.sin(2 * np.pi * (300 + 200 * np.sin(2 * np.pi * 7 * tt)) * tt) * (np.sin(2 * np.pi * 7 * tt) > 0) * 0.4, 0.4)
    write("water_fill", lp(rng.standard_normal(int(1.2 * SR)), 1600) * smooth_env(1.2, 20, 0.3, 1, 5), 0.5)

    # --- Камертон: 440 Гц, долгое затухание
    tt = t(4.0)
    fork = (np.sin(2 * np.pi * 440 * tt) + np.sin(2 * np.pi * 2640 * tt) * 0.05 * np.exp(-tt * 6)) * np.exp(-tt * 0.7)
    write("tuning_fork", fork, 0.6)

    # --- Гром
    for k in range(2):
        sec = 5.0
        th = lp(np.cumsum(noise(sec)) * 0.05, 120 + k * 60)
        th = hp(th, 20) * env_ad(int(sec * SR), 0.05 + k * 0.3, 1.2) * smooth_env(sec, 6, 0.4, 1, 20 + k)
        write(f"thunder_{k}", th, 0.95)

    # --- Радио: эфирный шум
    sec = 4
    st = bp(noise(sec), 500, 4000) * 0.5
    for i in rng.integers(0, int(sec * SR) - 200, 80):
        st[i:i + 200] += hp(rng.standard_normal(200), 2000) * np.exp(-np.arange(200) / 40)
    write("radio_static_loop", loopify(st, 0.3), 0.45)
    tt = t(1.2)
    write("radio_tune", np.sin(2 * np.pi * (900 + 600 * tt) * tt) * 0.2 + bp(rng.standard_normal(len(tt)), 800, 3000) * 0.4, 0.4)

    # --- Двигатель (питч меняется в игре)
    sec = 2
    tt = t(sec)
    eng = signal.sawtooth(2 * np.pi * 42 * tt) + signal.sawtooth(2 * np.pi * 84.3 * tt) * 0.5 + lp(noise(sec), 200) * 0.6
    write("engine_loop", loopify(lp(eng, 700), 0.2), 0.6)
    nn = int(1.2 * SR)
    starter = signal.square(2 * np.pi * 14 * np.arange(nn) / SR) * lp(rng.standard_normal(nn), 400)
    write("engine_start_fail", starter * env_ad(nn, 0.02, 0.8), 0.6)

    # --- Сердцебиение (низкое здоровье)
    tt = t(1.0)
    hb = np.zeros_like(tt)
    for s0 in (0.0, 0.22):
        m = tt >= s0
        hb[m] += np.sin(2 * np.pi * 55 * (tt[m] - s0)) * np.exp(-(tt[m] - s0) * 25)
    write("heartbeat", hb, 0.8)

    # --- Тихая музыкальная тема (короткая, для ключевых моментов): дрон + редкие ноты
    sec = 16
    tt = t(sec)
    drone = np.sin(2 * np.pi * 55 * tt) * 0.4 + np.sin(2 * np.pi * 82.4 * tt) * 0.25
    notes = np.zeros_like(tt)
    for s0, f in ((1.0, 220), (4.5, 261.6), (8.0, 196), (11.5, 233.1)):
        m = tt >= s0
        lt = tt[m] - s0
        notes[m] += (np.sin(2 * np.pi * f * lt) + 0.3 * np.sin(2 * np.pi * f * 2 * lt)) * np.exp(-lt * 0.9)
    theme = (drone * np.sin(np.pi * tt / sec) + notes * 0.5)
    write("theme_discovery", lp(theme, 2500), 0.5)


if __name__ == "__main__":
    gen()
    print("ok:", len(os.listdir(OUT)), "files in", OUT)
