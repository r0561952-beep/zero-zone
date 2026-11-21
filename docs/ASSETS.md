# Каталог ассетов и лицензий

В проекте используются только ассеты, разрешённые для использования в играх (включая коммерческие), и собственные процедурные ассеты.
Скрипт загрузки: `tools/fetch_assets.py` (запускается воркфлоу *Fetch CC0 assets* — файлы берутся напрямую из официальных источников).

## Сводка

| Что | Источник | Лицензия |
|---|---|---|
| Игровой движок | [Godot Engine](https://godotengine.org) 4.7.2 | MIT |
| PBR‑текстуры (23 наборов: albedo/normal/ARM) | [Poly Haven](https://polyhaven.com) | CC0 1.0 |
| 3D‑модели мебели, инструментов, предметов (48) | [Poly Haven](https://polyhaven.com) | CC0 1.0 |
| Автомобили (Car Kit) | [Kenney](https://kenney.nl/assets/car-kit) | CC0 1.0 |
| Палатки, костры, верстак (Survival Kit) | [Kenney](https://kenney.nl/assets/survival-kit) | CC0 1.0 |
| Звуки интерфейса (Interface Sounds) | [Kenney](https://kenney.nl/assets/interface-sounds) | CC0 1.0 |
| Шрифт PT Sans | ParaType, [Google Fonts](https://fonts.google.com/specimen/PT+Sans) | SIL OFL 1.1 (`assets/fonts/OFL_PT_Sans.txt`) |
| Шрифт Oswald | Vernon Adams, [Google Fonts](https://fonts.google.com/specimen/Oswald) | SIL OFL 1.1 |
| Звуки окружения: ветер, дождь, гром, гул, шаги, двери, костёр, радио и др. (57 файлов) | собственный синтез, `tools/gen_audio.py` | CC0 (собственные) |
| Карта региона, рельеф, маски | собственная генерация, `tools/gen_region.py` | CC0 (собственные) |
| Иконки предметов | рендер моделей Poly Haven, `tools/godot/render_icons.gd` | CC0 |
| Деревья, кусты, трава, здания, NPC | процедурная геометрия в коде (`scripts/world/*`) | собственные |

## Poly Haven — текстуры (1K, часть ограничена до 512 px при импорте)

[`withered_grass`](https://polyhaven.com/a/withered_grass), [`forest_leaves_02`](https://polyhaven.com/a/forest_leaves_02), [`gravel_road`](https://polyhaven.com/a/gravel_road), [`road_damaged`](https://polyhaven.com/a/road_damaged), [`muddy_tracks`](https://polyhaven.com/a/muddy_tracks), [`weathered_planks`](https://polyhaven.com/a/weathered_planks), [`blue_painted_planks`](https://polyhaven.com/a/blue_painted_planks), [`worn_plaster_wall`](https://polyhaven.com/a/worn_plaster_wall), [`white_plaster_rough_01`](https://polyhaven.com/a/white_plaster_rough_01), [`brick_wall_02`](https://polyhaven.com/a/brick_wall_02), [`peeling_painted_wall`](https://polyhaven.com/a/peeling_painted_wall), [`decrepit_wallpaper`](https://polyhaven.com/a/decrepit_wallpaper), [`old_planks_02`](https://polyhaven.com/a/old_planks_02), [`old_linoleum_flooring_01`](https://polyhaven.com/a/old_linoleum_flooring_01), [`dirty_tiles`](https://polyhaven.com/a/dirty_tiles), [`rusty_corrugated_iron`](https://polyhaven.com/a/rusty_corrugated_iron), [`corrugated_iron_02`](https://polyhaven.com/a/corrugated_iron_02), [`rusty_painted_metal`](https://polyhaven.com/a/rusty_painted_metal), [`pine_bark`](https://polyhaven.com/a/pine_bark), [`rough_pine_door`](https://polyhaven.com/a/rough_pine_door), [`concrete_floor_worn_001`](https://polyhaven.com/a/concrete_floor_worn_001), [`concrete_wall_008`](https://polyhaven.com/a/concrete_wall_008), [`snow_02`](https://polyhaven.com/a/snow_02)

## Poly Haven — модели (1K, текстуры уменьшены до 512 px)

[`WoodenTable_02`](https://polyhaven.com/a/WoodenTable_02), [`dining_table`](https://polyhaven.com/a/dining_table), [`painted_wooden_chair_01`](https://polyhaven.com/a/painted_wooden_chair_01), [`painted_wooden_chair_02`](https://polyhaven.com/a/painted_wooden_chair_02), [`painted_wooden_cabinet`](https://polyhaven.com/a/painted_wooden_cabinet), [`painted_wooden_cabinet_02`](https://polyhaven.com/a/painted_wooden_cabinet_02), [`painted_wooden_shelves`](https://polyhaven.com/a/painted_wooden_shelves), [`painted_wooden_nightstand`](https://polyhaven.com/a/painted_wooden_nightstand), [`sofa_02`](https://polyhaven.com/a/sofa_02), [`steel_frame_shelves_01`](https://polyhaven.com/a/steel_frame_shelves_01), [`metal_office_desk`](https://polyhaven.com/a/metal_office_desk), [`SchoolChair_01`](https://polyhaven.com/a/SchoolChair_01), [`Television_01`](https://polyhaven.com/a/Television_01), [`scandinavian_masonry_heater`](https://polyhaven.com/a/scandinavian_masonry_heater), [`CashRegister_01`](https://polyhaven.com/a/CashRegister_01), [`wall_clock`](https://polyhaven.com/a/wall_clock), [`Barrel_01`](https://polyhaven.com/a/Barrel_01), [`russian_food_cans_01`](https://polyhaven.com/a/russian_food_cans_01), [`can_rusted`](https://polyhaven.com/a/can_rusted), [`wooden_crate_01`](https://polyhaven.com/a/wooden_crate_01), [`wooden_crate_02`](https://polyhaven.com/a/wooden_crate_02), [`metal_jerrycan_green`](https://polyhaven.com/a/metal_jerrycan_green), [`medical_box`](https://polyhaven.com/a/medical_box), [`metal_toolbox`](https://polyhaven.com/a/metal_toolbox), [`old_military_crate`](https://polyhaven.com/a/old_military_crate), [`wooden_bucket_01`](https://polyhaven.com/a/wooden_bucket_01), [`jug_01`](https://polyhaven.com/a/jug_01), [`plastic_jerrycan`](https://polyhaven.com/a/plastic_jerrycan), [`crowbar_01`](https://polyhaven.com/a/crowbar_01), [`hatchet`](https://polyhaven.com/a/hatchet), [`sledgehammer_01`](https://polyhaven.com/a/sledgehammer_01), [`handsaw_wood`](https://polyhaven.com/a/handsaw_wood), [`cross_pein_hammer`](https://polyhaven.com/a/cross_pein_hammer), [`screwdriver`](https://polyhaven.com/a/screwdriver), [`pastic_torch_6v`](https://polyhaven.com/a/pastic_torch_6v), [`vintage_lighter`](https://polyhaven.com/a/vintage_lighter), [`machete`](https://polyhaven.com/a/machete), [`vintage_oil_lamp`](https://polyhaven.com/a/vintage_oil_lamp), [`cassette_player`](https://polyhaven.com/a/cassette_player), [`medical_tape`](https://polyhaven.com/a/medical_tape), [`adjustable_wrench`](https://polyhaven.com/a/adjustable_wrench), [`stone_fire_pit`](https://polyhaven.com/a/stone_fire_pit), [`rock_07`](https://polyhaven.com/a/rock_07), [`fern_02`](https://polyhaven.com/a/fern_02), [`dry_branches_medium_01`](https://polyhaven.com/a/dry_branches_medium_01), [`tree_stump_01`](https://polyhaven.com/a/tree_stump_01), [`rollershutter_door`](https://polyhaven.com/a/rollershutter_door), [`barrel_stove`](https://polyhaven.com/a/barrel_stove)

## Временные (плейсхолдер) решения

- **Люди (NPC)** — низкополигональные процедурные фигуры с процедурной анимацией. Запланирована замена на CC0‑модели со скелетной анимацией (например, Quaternius / Kenney Animated Characters).
- **Деревья** — процедурные (ель, берёза, сухостой, яблоня, кусты): лёгкие для мобильных устройств, но стилизованные.
- **Озвучка** отсутствует — диалоги и радио показываются текстом.
