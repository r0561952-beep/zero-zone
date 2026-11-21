#!/usr/bin/env python3
"""
ZERO ZONE — генератор данных региона.

Читает data/region.json и data/world.json и создаёт:
  data/region_height.bin   float32 высоты (заголовок: int32 w, int32 h, float32 cell, float32 ox, float32 oz)
  data/region_mask.bin     uint8 RGBA маски: R=грунтовые дороги, G=лес, B=вода, A=асфальт
  assets/map/region_map.png  «бумажная» карта для игрового интерфейса

Детерминирован (seed в region.json). Требует numpy и Pillow.
"""
import json
import math
import os
import struct

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Габариты шаблонов зданий (ширина фасада X, глубина Z) — синхронно с building_templates.gd
TPL_SIZE = {
    "house_a": (8.0, 6.6), "house_b": (9.6, 8.0), "fap": (13.0, 8.0), "shop": (10.0, 8.0),
    "school": (26.0, 10.0), "garage_row": (16.0, 6.0), "cabin": (5.2, 4.4),
    "gas_shop": (12.0, 7.0), "shed": (6.0, 5.0),
}


def value_noise(shape, scale, rng):
    """Сглаженный value noise: случайная решётка + бикубическая (smoothstep) интерполяция."""
    h, w = shape
    gh, gw = int(h / scale) + 3, int(w / scale) + 3
    grid = rng.random((gh, gw)).astype(np.float32)
    ys = np.arange(h) / scale
    xs = np.arange(w) / scale
    y0 = np.floor(ys).astype(int)
    x0 = np.floor(xs).astype(int)
    fy = ys - y0
    fx = xs - x0
    fy = fy * fy * (3 - 2 * fy)
    fx = fx * fx * (3 - 2 * fx)
    a = grid[np.ix_(y0, x0)]
    b = grid[np.ix_(y0, x0 + 1)]
    c = grid[np.ix_(y0 + 1, x0)]
    d = grid[np.ix_(y0 + 1, x0 + 1)]
    fx = fx[None, :]
    fy = fy[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(shape, base_scale, octaves, rng, gain=0.5):
    out = np.zeros(shape, np.float32)
    amp, total, scale = 1.0, 0.0, base_scale
    for _ in range(octaves):
        out += value_noise(shape, scale, rng) * amp
        total += amp
        amp *= gain
        scale /= 2.0
    return out / total * 2.0 - 1.0


def seg_dist(px, pz, a, b):
    ax, az = a
    bx, bz = b
    dx, dz = bx - ax, bz - az
    l2 = dx * dx + dz * dz
    t = np.clip(((px - ax) * dx + (pz - az) * dz) / max(l2, 1e-6), 0, 1)
    cx = ax + t * dx
    cz = az + t * dz
    return np.sqrt((px - cx) ** 2 + (pz - cz) ** 2)


def poly_dist(px, pz, pts):
    d = np.full(px.shape, 1e9, np.float32)
    for i in range(len(pts) - 1):
        d = np.minimum(d, seg_dist(px, pz, pts[i], pts[i + 1]))
    return d


def box_blur(a, r):
    """Box blur через интегральное изображение (numpy, без внешних зависимостей)."""
    p = np.pad(a, r, mode="edge").astype(np.float64)
    c = p.cumsum(0).cumsum(1)
    c = np.pad(c, ((1, 0), (1, 0)))
    k = 2 * r + 1
    s = c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]
    return (s / (k * k)).astype(np.float32)


def smooth01(x):
    x = np.clip(x, 0, 1)
    return x * x * (3 - 2 * x)


def main():
    reg = json.load(open(os.path.join(ROOT, "data", "region.json"), encoding="utf-8"))
    world = json.load(open(os.path.join(ROOT, "data", "world.json"), encoding="utf-8"))
    ox, oz = reg["origin"]
    sx, sz = reg["size"]
    cell = reg["cell"]
    w, h = int(sx / cell) + 1, int(sz / cell) + 1
    rng = np.random.default_rng(reg["seed"])

    xs = ox + np.arange(w) * cell
    zs = oz + np.arange(h) * cell
    PX, PZ = np.meshgrid(xs, zs)

    low = fbm((h, w), 220 / cell, 3, rng) * reg["height_amp"]            # крупные холмы
    detail = fbm((h, w), 40 / cell, 3, rng) * 1.6                         # мелкий рельеф
    height = low + detail

    # Выравнивание площадок (посёлок, заправка и т.д.)
    for fz in reg["flat_zones"]:
        cx, cz = fz["center"]
        d = np.sqrt((PX - cx) ** 2 + (PZ - cz) ** 2)
        k = 1.0 - smooth01((d - fz["radius"]) / fz["blend"])
        ci = int((cz - oz) / cell)
        cj = int((cx - ox) / cell)
        target = low[ci, cj] * 0.6
        height = height * (1 - k) + (target + detail * 0.08) * k

    # Дороги: по поперечному сечению ровные, следуют сглаженному рельефу
    road_dirt = np.zeros((h, w), np.float32)
    road_asph = np.zeros((h, w), np.float32)
    smooth_h = box_blur(height, 6)
    for r in reg["roads"]:
        d = poly_dist(PX, PZ, r["points"])
        half = r["width"] * 0.5
        core = 1.0 - smooth01((d - half) / 1.6)
        flat = 1.0 - smooth01((d - half - 1.0) / 6.0)
        height = height * (1 - flat) + smooth_h * flat
        if r["type"] == "asphalt":
            road_asph = np.maximum(road_asph, core)
            road_dirt = np.maximum(road_dirt, (1.0 - smooth01((d - half - 1.2) / 1.5)) * 0.6)
        elif r["type"] == "path":
            road_dirt = np.maximum(road_dirt, core * 0.75)
        else:
            road_dirt = np.maximum(road_dirt, core)

    # Ручей Ржавец
    st = reg["stream"]
    d = poly_dist(PX, PZ, st["points"])
    water = 1.0 - smooth01((d - st["width"] * 0.5) / 1.2)
    bank = 1.0 - smooth01((d - st["width"] * 0.5) / 7.0)
    height = height - bank * st["depth"]

    # Лес: всё, кроме посёлка, открытых пространств, дорог, воды
    forest = np.clip(0.8 + fbm((h, w), 50 / cell, 3, rng) * 0.7, 0, 1)
    edge_noise = fbm((h, w), 30 / cell, 3, rng) * 35.0
    for fz in reg["flat_zones"]:
        cx, cz = fz["center"]
        dd = np.sqrt((PX - cx) ** 2 + (PZ - cz) ** 2) + edge_noise * min(1.0, fz["radius"] / 100.0)
        forest *= smooth01((dd - fz["radius"] * 0.85) / (fz["blend"] * 0.8))
    for oa in reg["open_areas"]:
        cx, cz = oa["center"]
        rx, rz = oa["radius"]
        dd = np.sqrt(((PX - cx) / rx) ** 2 + ((PZ - cz) / rz) ** 2) + edge_noise / max(rx, rz)
        forest *= smooth01((dd - 0.85) / 0.4)
    for r in reg["roads"]:
        dd = poly_dist(PX, PZ, r["points"])
        forest *= smooth01((dd - r["width"] * 0.5 - 2.0) / 3.0)
    forest *= smooth01((d - st["width"] * 0.5 - 1.5) / 3.0)

    # Здания — расчистка вокруг
    builds = []
    for b in world["buildings"]:
        bw, bd = TPL_SIZE.get(b["tpl"], (8, 8))
        builds.append((b["pos"][0], b["pos"][1], bw, bd, b.get("rot", 0)))
        dd = np.sqrt((PX - b["pos"][0]) ** 2 + (PZ - b["pos"][1]) ** 2)
        forest *= smooth01((dd - max(bw, bd) * 0.9) / 6.0)

    # --- запись бинарных файлов ---
    os.makedirs(os.path.join(ROOT, "data"), exist_ok=True)
    with open(os.path.join(ROOT, "data", "region_height.bin"), "wb") as f:
        f.write(struct.pack("<iifff", w, h, cell, ox, oz))
        f.write(height.astype("<f4").tobytes())
    mask = np.stack([road_dirt, forest, water, road_asph], axis=-1)
    mask8 = (np.clip(mask, 0, 1) * 255).astype(np.uint8)
    with open(os.path.join(ROOT, "data", "region_mask.bin"), "wb") as f:
        f.write(struct.pack("<ii", w, h))
        f.write(mask8.tobytes())

    # --- бумажная карта ---
    paper = np.array([214, 202, 176], np.float32)
    img = np.ones((h, w, 3), np.float32) * paper
    shade = (np.gradient(height, axis=1) - np.gradient(height, axis=0)) * 0.9
    img += shade[..., None] * 14
    forest_col = np.array([128, 140, 108], np.float32)
    img = img * (1 - forest[..., None] * 0.7) + forest_col * forest[..., None] * 0.7
    img = img * (1 - water[..., None]) + np.array([96, 124, 140]) * water[..., None]
    img = img * (1 - road_dirt[..., None] * 0.8) + np.array([160, 132, 96]) * road_dirt[..., None] * 0.8
    img = img * (1 - road_asph[..., None]) + np.array([92, 88, 84]) * road_asph[..., None]
    # горизонтали
    gmag = np.hypot(np.gradient(height, axis=0), np.gradient(height, axis=1))
    contour = (np.abs(((height + 50) / 2.5) % 1.0 - 0.5) < 0.05) & (gmag > 0.06)
    img[contour] *= 0.85
    pil = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
    draw = ImageDraw.Draw(pil)
    for (bx, bz, bw, bd, rot) in builds:
        a = math.radians(rot)
        ca, sa = math.cos(a), math.sin(a)
        pts = []
        for lx, lz in ((-bw / 2, -bd / 2), (bw / 2, -bd / 2), (bw / 2, bd / 2), (-bw / 2, bd / 2)):
            wx = bx + lx * ca + lz * sa
            wz = bz - lx * sa + lz * ca
            pts.append(((wx - ox) / cell, (wz - oz) / cell))
        draw.polygon(pts, fill=(70, 58, 50))
    pil = pil.filter(ImageFilter.SMOOTH)
    os.makedirs(os.path.join(ROOT, "assets", "map"), exist_ok=True)
    pil.save(os.path.join(ROOT, "assets", "map", "region_map.png"), optimize=True)
    print(f"region {w}x{h} cells, height {height.min():.1f}..{height.max():.1f} m")


if __name__ == "__main__":
    main()
