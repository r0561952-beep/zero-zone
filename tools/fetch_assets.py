#!/usr/bin/env python3
"""
ZERO ZONE — загрузчик бесплатных CC0-ассетов.

Запускается в GitHub Actions (у раннера есть доступ к сайтам ассетов).
Источники: Poly Haven (CC0, публичный API без ключа) и Kenney.nl (CC0).

Режимы:
  list   — сохранить каталог Poly Haven (id, имя, категории, теги) в tools/polyhaven_catalog.json
  fetch  — скачать ассеты из tools/assets_manifest.json в assets/thirdparty/
           и дописать docs/ASSET_SOURCES.generated.md
"""
import io
import json
import os
import re
import sys
import urllib.request
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UA = {"User-Agent": "ZeroZone-AssetFetcher/1.0 (open-source game; CC0 assets)"}
OUT = os.path.join(ROOT, "assets", "thirdparty")


def get(url, binary=False):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=120) as r:
        data = r.read()
    return data if binary else data.decode("utf-8", "replace")


def save(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(data)


def cmd_list():
    catalog = {}
    for t in ("textures", "models", "hdris"):
        assets = json.loads(get(f"https://api.polyhaven.com/assets?t={t}"))
        for aid, info in assets.items():
            catalog[aid] = {
                "type": t,
                "name": info.get("name"),
                "categories": info.get("categories"),
                "tags": info.get("tags"),
                "polycount": info.get("polycount"),
                "dimensions": info.get("dimensions"),
            }
    path = os.path.join(ROOT, "tools", "polyhaven_catalog.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=0, sort_keys=True)
    print(f"catalog: {len(catalog)} assets -> {path}")


def ph_texture(aid, res, log):
    files = json.loads(get(f"https://api.polyhaven.com/files/{aid}"))
    # Карта: наш суффикс -> ключ Poly Haven
    wanted = {"albedo": ["Diffuse", "diff"], "normal": ["nor_gl"], "arm": ["arm"],
              "rough": ["Rough", "rough"], "ao": ["AO", "ao"]}
    got = []
    for suffix, keys in wanted.items():
        for k in keys:
            if k in files and res in files[k]:
                fmt = "jpg" if "jpg" in files[k][res] else next(iter(files[k][res]))
                url = files[k][res][fmt]["url"]
                dst = os.path.join(OUT, "polyhaven", "textures", aid, f"{aid}_{suffix}.{fmt}")
                save(dst, get(url, True))
                got.append(suffix)
                break
    log.append(f"| Poly Haven | texture `{aid}` ({res}: {', '.join(got)}) | CC0 | https://polyhaven.com/a/{aid} |")


def ph_model(aid, res, log):
    files = json.loads(get(f"https://api.polyhaven.com/files/{aid}"))
    g = files.get("gltf", {}).get(res, {}).get("gltf")
    if not g:
        print(f"!! no gltf {res} for {aid}")
        return
    base = os.path.join(OUT, "polyhaven", "models", aid)
    save(os.path.join(base, os.path.basename(g["url"])), get(g["url"], True))
    for rel, inc in g.get("include", {}).items():
        save(os.path.join(base, rel), get(inc["url"], True))
    log.append(f"| Poly Haven | model `{aid}` ({res}) | CC0 | https://polyhaven.com/a/{aid} |")


def kenney_kit(slug, log):
    page = get(f"https://kenney.nl/assets/{slug}")
    m = re.findall(r"https://kenney\.nl/media/pages/assets/[^\"'\s]+?\.zip", page)
    if not m:
        print(f"!! no zip link for kenney {slug}")
        return
    data = get(m[0], True)
    z = zipfile.ZipFile(io.BytesIO(data))
    base = os.path.join(OUT, "kenney", slug)
    n = 0
    for name in z.namelist():
        low = name.lower()
        keep = ("glb format/" in low and not name.endswith("/")) or low.endswith("license.txt")
        if keep:
            rel = name.split("GLB format/")[-1] if "GLB format/" in name else os.path.basename(name)
            save(os.path.join(base, rel), z.read(name))
            n += 1
    log.append(f"| Kenney | `{slug}` ({n} files) | CC0 | https://kenney.nl/assets/{slug} |")


def cmd_fetch():
    with open(os.path.join(ROOT, "tools", "assets_manifest.json"), encoding="utf-8") as f:
        man = json.load(f)
    log = ["| Источник | Ассет | Лицензия | Ссылка |", "|---|---|---|---|"]
    errors = []
    for aid in man.get("polyhaven_textures", []):
        try:
            ph_texture(aid, man.get("texture_res", "1k"), log)
        except Exception as e:  # noqa
            errors.append(f"texture {aid}: {e}")
    for aid in man.get("polyhaven_models", []):
        try:
            ph_model(aid, man.get("model_res", "1k"), log)
        except Exception as e:  # noqa
            errors.append(f"model {aid}: {e}")
    for slug in man.get("kenney_kits", []):
        try:
            kenney_kit(slug, log)
        except Exception as e:  # noqa
            errors.append(f"kenney {slug}: {e}")
    with open(os.path.join(ROOT, "docs", "ASSET_SOURCES.generated.md"), "w", encoding="utf-8") as f:
        f.write("# Загруженные сторонние ассеты (автоматически)\n\n")
        f.write("Все файлы ниже получены скриптом `tools/fetch_assets.py` из официальных источников.\n\n")
        f.write("\n".join(log) + "\n")
        if errors:
            f.write("\n## Ошибки загрузки\n\n" + "\n".join(f"- {e}" for e in errors) + "\n")
    print("\n".join(log))
    print("ERRORS:", errors)


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "fetch"
    {"list": cmd_list, "fetch": cmd_fetch}[mode]()
