#!/usr/bin/env python3
"""
Создаёт .import‑файлы для 3D‑текстур с VRAM‑сжатием (ETC2/ASTC на Android, S3TC/BPTC на PC).
Без этого Godot импортирует JPG/PNG как несжатые (Lossless), т.к. материалы создаются из кода
и редактор не «видит» их 3D‑использование — на телефоне это съело бы сотни МБ видеопамяти.
"""
import glob
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

TEMPLATE = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://{rel}"

[params]

compress/mode=2
compress/high_quality=false
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/normal_map={normal}
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit={limit}
detect_3d/compress_to=0
"""


def main():
    n = 0
    patterns = ["assets/thirdparty/polyhaven/**/*.jpg", "assets/thirdparty/polyhaven/**/*.png"]
    for pat in patterns:
        for p in glob.glob(os.path.join(ROOT, pat), recursive=True):
            imp = p + ".import"
            if os.path.exists(imp):
                continue
            rel = os.path.relpath(p, ROOT).replace(os.sep, "/")
            low = rel.lower()
            normal = 1 if ("_normal." in low or "_nor_gl" in low) else 2
            # Земля — 1K (её видно вблизи больше всего), остальное — 512 px: экономия ~40 МБ в APK
            keep = any(k in rel for k in ("withered_grass", "forest_leaves_02", "gravel_road", "muddy_tracks"))
            limit = 0 if (keep and "_arm" not in low) else (128 if keep else 512)
            if "/models/" in rel:
                limit = 0
            with open(imp, "w", encoding="utf-8") as f:
                f.write(TEMPLATE.format(rel=rel, normal=normal, limit=limit))
            n += 1
    print("created", n, ".import files")


if __name__ == "__main__":
    main()
