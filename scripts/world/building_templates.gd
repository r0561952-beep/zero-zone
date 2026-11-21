class_name BuildingTemplates
extends RefCounted
## Шаблоны зданий Нулевой зоны. Габариты синхронизированы с tools/gen_region.py (TPL_SIZE).
## Мебель: модели Poly Haven (CC0). Добыча: data/loot.json. Сюжет: предметы и триггеры по id здания.

const STYLES := {"blue": "planks_blue", "planks": "planks_ext", "green": "planks_green", "ochre": "planks_ochre"}


static func build(def: Dictionary, parent: Node3D) -> Node3D:
	var pos2: Array = def.pos
	var tpl: String = def.tpl
	var size := Vector2(8, 8)
	match tpl:
		"house_a": size = Vector2(8.0, 6.6)
		"house_b": size = Vector2(9.6, 8.0)
		"fap": size = Vector2(13.0, 8.0)
		"shop": size = Vector2(10.0, 8.0)
		"school": size = Vector2(26.0, 10.0)
		"garage_row": size = Vector2(16.0, 6.0)
		"cabin": size = Vector2(5.2, 4.4)
		"gas_shop": size = Vector2(12.0, 7.0)
		"shed": size = Vector2(6.0, 5.0)
	# Высота основания — по максимуму рельефа под зданием (фундамент закроет перепад)
	var rot := deg_to_rad(float(def.get("rot", 0.0)))
	var base := -INF
	for c in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5), Vector2.ZERO]:
		var lx: float = c.x * size.x
		var lz: float = c.y * size.y
		var wx: float = pos2[0] + lx * cos(rot) + lz * sin(rot)
		var wz: float = pos2[1] - lx * sin(rot) + lz * cos(rot)
		base = maxf(base, RegionData.height_at(wx, wz))
	var b := BuildingBuilder.new(parent, str(def.id), Vector3(pos2[0], base, pos2[1]), float(def.get("rot", 0.0)))
	match tpl:
		"house_a": _house_a(b, def)
		"house_b": _house_b(b, def)
		"fap": _fap(b, def)
		"shop": _shop(b, def)
		"school": _school(b, def)
		"garage_row": _garages(b, def)
		"cabin": _cabin(b, def)
		"gas_shop": _gas_shop(b, def)
		"shed": _shed(b, def)
	if def.has("chalk"):
		var sym: String = {"пусто": "✓", "опасно": "✗", "вода": "~", "тайник": "□"}.get(def.chalk, "?")
		b.chalk(sym, Vector3(size.x * 0.5 - 1.2, 1.5, size.y * 0.5 + 0.13), 0.0, 160)
	if def.has("name") and tpl in ["shop", "fap", "school"]:
		var l := Label3D.new()
		l.text = {"shop": "ПРОДУКТЫ", "fap": "ФЕЛЬДШЕРСКО-АКУШЕРСКИЙ ПУНКТ", "school": "СОСНОВСКАЯ СРЕДНЯЯ ШКОЛА"}[tpl]
		l.font_size = 64 if tpl == "shop" else 40
		l.pixel_size = 0.006
		l.modulate = Color(0.85, 0.82, 0.75)
		l.position = Vector3(0, b.floor_y + (3.15 if tpl != "school" else 3.4), size.y * 0.5 + 0.16)
		l.shaded = true
		b.root.add_child(l)
	b.finish()
	return b.root


# ============================================================================ ДОМ А
static func _house_a(b: BuildingBuilder, def: Dictionary) -> void:
	var ext: String = STYLES.get(def.get("style", "planks"), "planks_ext")
	var w := 8.0
	var d := 6.6
	var h := 2.6
	var t := 0.2
	b.floor_y = 0.4
	var hw := w * 0.5
	var hd := d * 0.5
	b.foundation(w, d, "concrete")
	var walls_int := "wallpaper" if b.rng.randf() < 0.6 else "wall_int"
	b.floor_rect(-hw, -hd, hw, hd, "floor_wood")
	b.ceiling_rect(-hw, -hd, hw, hd, b.floor_y + h)
	var shut := "planks_blue" if ext != "planks_blue" else "frame_white"
	# наружные стены
	b.wall(Vector2(-hw - t * 0.5, hd), Vector2(hw + t * 0.5, hd), h, [
		{"at": -2.6 - 0.1, "w": 0.95, "top": 2.05, "kind": "door"},
		{"at": 0.8 + 0.1, "w": 1.1, "bottom": 0.85, "top": 2.0, "kind": "window", "shutters": shut},
		{"at": 2.8 + 0.1, "w": 1.1, "bottom": 0.85, "top": 2.0, "kind": "window", "shutters": shut}], ext, walls_int, t)
	b.wall(Vector2(hw, hd - t * 0.5), Vector2(hw, -hd + t * 0.5), h, [{"at": 0.0, "w": 1.0, "bottom": 0.85, "top": 2.0, "kind": "window", "shutters": shut}], ext, walls_int, t)
	b.wall(Vector2(hw + t * 0.5, -hd), Vector2(-hw - t * 0.5, -hd), h, [{"at": -2.0, "w": 1.0, "bottom": 0.85, "top": 2.0, "kind": "window"}], ext, walls_int, t)
	b.wall(Vector2(-hw, -hd + t * 0.5), Vector2(-hw, hd - t * 0.5), h, [], ext, "planks_ext", t)
	# перегородки
	b.wall(Vector2(-1.2, -hd + t * 0.5), Vector2(-1.2, hd - t * 0.5), h, [{"at": -1.5, "w": 0.85, "top": 2.0, "kind": "door"}], walls_int, walls_int, 0.12)
	b.wall(Vector2(-hw + t * 0.5, 0.3), Vector2(-1.2 - 0.06, 0.3), h, [{"at": 0.0, "w": 0.8, "top": 2.0, "kind": "door"}], "planks_ext", "planks_ext", 0.1)
	b.gable_roof(w, d, h, 1.8, 0.5, "roof_iron" if b.rng.randf() < 0.6 else "roof_slate", ext)
	b.porch(-2.6, hd, 1.6)
	b.door("front", Vector2(-hw - t * 0.5, hd), Vector2(hw + t * 0.5, hd), -2.7, 0.92, "Входная дверь")
	b.door("inner", Vector2(-1.2, -hd + t * 0.5), Vector2(-1.2, hd - t * 0.5), -1.5, 0.82, "Дверь в избу")
	b.door("pantry", Vector2(-hw + t * 0.5, 0.3), Vector2(-1.26, 0.3), 0.0, 0.78, "Дверь в кладовку")
	b.indoor(-hw, -hd, hw, hd, h)
	_living_room(b, -1.2, -hd, hw, hd, def)
	# сени и кладовка
	b.container("pantry_shelf", "pantry", "Полки в кладовке", -3.2, -hd + 0.35, 0.0, "painted_wooden_shelves", Vector3(0.55, 1.1, 0.4), 8)
	var cellar := CellarHatch.new()
	cellar.container_id = b.bid + "/cellar"
	cellar.loot_table = "pantry"
	cellar.title = "Подпол"
	cellar.visual = "hatch"
	cellar.box_size = Vector3(0.9, 0.1, 0.9)
	cellar.blocking = false
	cellar.position = Vector3(-2.2, b.floor_y, -1.6)
	b.root.add_child(cellar)
	b.prop("wooden_bucket_01", -3.6, 2.6, 20.0, "box")
	b.container("entry", "shed", "Хлам в сенях", -3.5, 1.2, 90.0, "wooden_crate_02", Vector3(0.55, 0.5, 1.1), 6)
	_story(b, def)
	_yard(b, def, w, d)


## Изба: печь, кровать, стол, шкафы. Прямоугольник x0..x1, z0..z1 (локально).
static func _living_room(b: BuildingBuilder, x0: float, z0: float, x1: float, z1: float, def: Dictionary) -> void:
	var stove := MiscInteract.HeatSource.new()
	stove.source_id = b.bid + "/stove"
	stove.title = "Печь"
	stove.heat_radius = 5.5
	stove.light_offset = Vector3(0.0, 0.5, 0.75)
	stove.position = Vector3(x0 + 1.0, b.floor_y, z0 + 0.95)
	stove.setup_box(Vector3(1.25, 2.3, 1.4), Vector3(0, 1.15, 0))
	b.root.add_child(stove)
	if not Models.place("scandinavian_masonry_heater", stove, Transform3D(Basis(), Vector3(0.13, 0, -0.19)), "", 0.0):
		var kit := MeshKit.new()
		kit.add_box(Mats.get_mat("stove_white"), Transform3D(Basis(), Vector3(0, 1.0, 0)), Vector3(1.2, 2.0, 1.3))
		stove.add_child(kit.build_instance("Stove"))
	# кровать
	_bed(b, x1 - 1.15, z0 + 1.1, 0.0, "Кровать", 1.0)
	b.container("nightstand", "nightstand", "Тумбочка", x1 - 2.25, z0 + 0.4, 0.0, "painted_wooden_nightstand", Vector3(0.5, 0.62, 0.5), 6)
	b.container("wardrobe", "wardrobe", "Платяной шкаф", x1 - 0.45, z0 + 2.9, -90.0, "painted_wooden_cabinet_02", Vector3(1.0, 2.5, 0.72), 12)
	# стол у окна
	b.prop("dining_table", x1 - 1.6, z1 - 1.25, 0.0, "box", 1.6)
	b.prop("painted_wooden_chair_01", x1 - 2.2, z1 - 1.9, 0.0, "box")
	b.prop("painted_wooden_chair_02", x1 - 0.9, z1 - 0.55, 180.0, "box")
	b.container("kitchen", "kitchen", "Кухонный шкафчик", x0 + 0.7, z1 - 0.4, 180.0, "painted_wooden_cabinet", Vector3(1.19, 1.18, 0.62), 10)
	if b.rng.randf() < 0.6:
		var fr := b.container("fridge", "fridge", "Холодильник «Бирюса»", x0 + 2.0, z1 - 0.4, 180.0, "", Vector3(0.6, 1.5, 0.6), 6, [], "box")
		Models.override_material(fr, Mats.get_mat("fridge"))
	if b.rng.randf() < 0.5:
		b.prop("Television_01", x0 + 2.4, z0 + 0.4, 0.0, "box", 0.0, 0.0)
	b.prop("wall_clock", x0 + 2.4, z0 + 0.12, 0.0, "", 0.0, 1.9)


static func _bed(b: BuildingBuilder, x: float, z: float, rot_deg: float, title: String, quality: float) -> void:
	var bed := MiscInteract.Bed.new()
	bed.title = title
	bed.quality = quality
	bed.position = Vector3(x, b.floor_y, z)
	bed.rotation.y = deg_to_rad(rot_deg)
	bed.setup_box(Vector3(1.0, 0.55, 2.0), Vector3(0, 0.27, 0))
	b.root.add_child(bed)
	var kit := MeshKit.new()
	kit.add_box(Mats.get_mat("wood_dark"), Transform3D(Basis(), Vector3(0, 0.22, 0)), Vector3(1.0, 0.18, 2.0))
	for cx in [-0.45, 0.45]:
		for cz in [-0.95, 0.95]:
			kit.add_box(Mats.get_mat("wood_dark"), Transform3D(Basis(), Vector3(cx, 0.2, cz)), Vector3(0.07, 0.4, 0.07))
	kit.add_box(Mats.get_mat("wood_dark"), Transform3D(Basis(), Vector3(0, 0.5, -0.97)), Vector3(1.0, 0.6, 0.05))
	kit.add_box(Mats.get_mat("mattress"), Transform3D(Basis(), Vector3(0, 0.37, 0.02)), Vector3(0.92, 0.14, 1.9))
	kit.add_box(Mats.get_mat("blanket"), Transform3D(Basis(Vector3.RIGHT, 0.02), Vector3(0, 0.46, 0.35)), Vector3(0.95, 0.05, 1.2))
	kit.add_box(Mats.get_mat("white_paint"), Transform3D(Basis(), Vector3(0, 0.49, -0.7)), Vector3(0.6, 0.1, 0.35))
	bed.add_child(kit.build_instance("Bed"))


## Двор: забор с калиткой, поленница, сарай.
static func _yard(b: BuildingBuilder, def: Dictionary, w: float, d: float) -> void:
	var yw := w + 7.0
	var front := d * 0.5 + 4.0
	var back := -d * 0.5 - 6.0
	var post := "wood_dark"
	var plank := "planks_ext"
	var kit := b.kit
	var segs := [[Vector2(-yw * 0.5, front), Vector2(-2.9 - 0.8, front)], [Vector2(-2.9 + 0.8, front), Vector2(yw * 0.5, front)],
		[Vector2(yw * 0.5, front), Vector2(yw * 0.5, back)], [Vector2(yw * 0.5, back), Vector2(-yw * 0.5, back)], [Vector2(-yw * 0.5, back), Vector2(-yw * 0.5, front)]]
	var broken := b.rng.randi_range(0, 4)
	for si in segs.size():
		var a: Vector2 = segs[si][0]
		var c: Vector2 = segs[si][1]
		var len := a.distance_to(c)
		var n := int(len / 0.22)
		var dir := (c - a).normalized()
		for i in n:
			if si == broken and i > n * 0.4 and i < n * 0.6:
				continue
			var p := a + dir * (i + 0.5) * 0.22
			var gy := RegionData.height_at(b.root.position.x, b.root.position.z) - b.root.position.y
			var hh := 1.1 + (0.08 if i % 2 == 0 else 0.0)
			kit.add_box(Mats.get_mat(plank), Transform3D(Basis(Vector3.UP, atan2(-dir.y, dir.x)), Vector3(p.x, gy + hh * 0.5 - 0.2, p.y)), Vector3(0.13, hh, 0.025))
		for i in int(len / 2.4) + 1:
			var p2 := a + dir * minf(i * 2.4, len)
			kit.add_box(Mats.get_mat(post), Transform3D(Basis(), Vector3(p2.x, 0.4, p2.y)), Vector3(0.1, 1.5, 0.1))
		for rail_y in [0.25, 0.85]:
			var mid := (a + c) * 0.5
			kit.add_box(Mats.get_mat(post), Transform3D(Basis(Vector3.UP, atan2(-dir.y, dir.x)), Vector3(mid.x, rail_y, mid.y - 0.03 * signf(dir.x))), Vector3(len, 0.06, 0.04))
		# коллизия забора
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(len, 1.4, 0.12)
		cs.shape = bs
		cs.transform = Transform3D(Basis(Vector3.UP, atan2(-dir.y, dir.x)), Vector3((a.x + c.x) * 0.5, 0.5, (a.y + c.y) * 0.5))
		if si != broken:
			b.body.add_child(cs)
	# одичавший сад: яблони и кусты
	for i in b.rng.randi_range(1, 3):
		var tp := Vector3(b.rng.randf_range(-yw * 0.5 + 1.5, yw * 0.5 - 1.5), -0.1, b.rng.randf_range(back + 1.0, -d * 0.5 - 1.2))
		var mi := MeshInstance3D.new()
		mi.mesh = TreeFactory.mesh("apple")
		mi.position = tp
		mi.rotation.y = b.rng.randf() * TAU
		mi.scale = Vector3.ONE * b.rng.randf_range(0.8, 1.2)
		b.root.add_child(mi)
		var cs_t := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.15
		cyl.height = 2.0
		cs_t.shape = cyl
		cs_t.position = tp + Vector3(0, 1.0, 0)
		b.body.add_child(cs_t)
	for i in b.rng.randi_range(2, 5):
		var side := b.rng.randi_range(0, 2)
		var bp := Vector3(-yw * 0.5 + 0.6, -0.05, b.rng.randf_range(back, front)) if side == 0 else (Vector3(yw * 0.5 - 0.6, -0.05, b.rng.randf_range(back, front)) if side == 1 else Vector3(b.rng.randf_range(-yw * 0.5, yw * 0.5), -0.05, front - 0.6))
		var bm := MeshInstance3D.new()
		bm.mesh = TreeFactory.mesh("bush")
		bm.position = bp
		bm.rotation.y = b.rng.randf() * TAU
		bm.scale = Vector3.ONE * b.rng.randf_range(0.8, 1.5)
		bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.root.add_child(bm)
	# поленница
	var wp := Vector3(yw * 0.5 - 1.0, 0.0, back + 1.5)
	var wood := LootContainer.new()
	wood.container_id = b.bid + "/woodpile"
	wood.title = "Поленница"
	wood.loot_table = ""
	wood.fixed_items = [["wood_log", b.rng.randi_range(2, 5)], ["sticks", 4]]
	wood.slots_count = 4
	wood.box_size = Vector3(0.8, 1.0, 2.0)
	wood.position = wp
	b.root.add_child(wood)
	var wk := MeshKit.new()
	for row in 3:
		for i in 7:
			var y := 0.18 + row * 0.3
			var z := -0.85 + i * 0.28 + (0.14 if row % 2 == 1 else 0.0)
			if z > 0.9:
				continue
			var xf := Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(-0.35, y, z))
			wk.add_box(Mats.get_mat("wood_light"), xf, Vector3(0.24, 0.7, 0.24))
	wood.add_child(wk.build_instance("Woodpile"))
	# сарай
	if b.rng.randf() < 0.7:
		var sp := Vector3(-yw * 0.5 + 1.8, 0, back + 1.6)
		b.box("planks_ext", sp + Vector3(-1.3, -0.3, -0.95), sp + Vector3(1.3, 2.0, -0.87))
		b.box("planks_ext", sp + Vector3(-1.34, -0.3, -0.9), sp + Vector3(-1.26, 2.0, 0.9))
		b.box("planks_ext", sp + Vector3(1.26, -0.3, -0.9), sp + Vector3(1.34, 2.0, 0.9))
		b.rbox("roof_iron", Transform3D(Basis(Vector3.RIGHT, -0.15), sp + Vector3(0, 2.1, 0)), Vector3(3.0, 0.05, 2.3))
		b.container("shed", "shed", "Сарай: инструмент и хлам", sp.x, sp.z - 0.3, 0.0, "wooden_crate_02", Vector3(0.53, 0.46, 1.17), 10)


# ============================================================================ ДОМ Б
static func _house_b(b: BuildingBuilder, def: Dictionary) -> void:
	var ext: String = STYLES.get(def.get("style", "planks"), "planks_ext")
	var w := 9.6
	var d := 8.0
	var h := 2.7
	var t := 0.2
	b.floor_y = 0.45
	var hw := w * 0.5
	var hd := d * 0.5
	b.foundation(w, d, "concrete")
	var walls_int := "wallpaper" if b.rng.randf() < 0.5 else "wall_int"
	b.floor_rect(-hw, -hd, hw, hd, "floor_wood")
	b.ceiling_rect(-hw, -hd, hw, hd, b.floor_y + h)
	var shut := "planks_blue" if ext != "planks_blue" else "frame_white"
	b.wall(Vector2(-hw - t * 0.5, hd), Vector2(hw + t * 0.5, hd), h, [
		{"at": -3.4 - 0.1, "w": 0.95, "top": 2.05, "kind": "door"},
		{"at": 0.4, "w": 1.15, "bottom": 0.85, "top": 2.05, "kind": "window", "shutters": shut},
		{"at": 3.2, "w": 1.15, "bottom": 0.85, "top": 2.05, "kind": "window", "shutters": shut}], ext, walls_int, t)
	b.wall(Vector2(hw, hd - t * 0.5), Vector2(hw, -hd + t * 0.5), h, [
		{"at": -2.0, "w": 1.05, "bottom": 0.85, "top": 2.0, "kind": "window", "shutters": shut},
		{"at": 2.0, "w": 1.05, "bottom": 0.85, "top": 2.0, "kind": "window", "shutters": shut}], ext, walls_int, t)
	b.wall(Vector2(hw + t * 0.5, -hd), Vector2(-hw - t * 0.5, -hd), h, [{"at": -1.4, "w": 1.05, "bottom": 0.85, "top": 2.0, "kind": "window"}], ext, walls_int, t)
	b.wall(Vector2(-hw, -hd + t * 0.5), Vector2(-hw, hd - t * 0.5), h, [{"at": 2.6, "w": 0.6, "bottom": 1.2, "top": 1.8, "kind": "window"}], ext, "planks_ext", t)
	# перегородки: сени|кладовка, сени|изба, изба|спальня
	b.wall(Vector2(-2.0, -hd + t * 0.5), Vector2(-2.0, hd - t * 0.5), h, [{"at": 2.5, "w": 0.85, "top": 2.0, "kind": "door"}], walls_int, walls_int, 0.12)
	b.wall(Vector2(-hw + t * 0.5, 1.0), Vector2(-2.06, 1.0), h, [{"at": 0.0, "w": 0.8, "top": 2.0, "kind": "door"}], "planks_ext", "planks_ext", 0.1)
	b.wall(Vector2(-1.94, 0.0), Vector2(hw - t * 0.5, 0.0), h, [{"at": 1.2, "w": 0.85, "top": 2.0, "kind": "door"}], walls_int, walls_int, 0.12)
	b.gable_roof(w, d, h, 2.1, 0.55, "roof_iron" if b.rng.randf() < 0.5 else "roof_slate", ext)
	b.porch(-3.5, hd, 1.7)
	b.door("front", Vector2(-hw - t * 0.5, hd), Vector2(hw + t * 0.5, hd), -3.5, 0.92, "Входная дверь", def.id == "vera", "key_vera" if def.id == "vera" else "", "door", 2.0, def.id != "vera")
	b.door("inner", Vector2(-2.0, -hd + t * 0.5), Vector2(-2.0, hd - t * 0.5), 2.5, 0.82, "Дверь в избу")
	b.door("pantry", Vector2(-hw + t * 0.5, 1.0), Vector2(-2.06, 1.0), 0.0, 0.78, "Дверь в кладовку")
	b.door("bedroom", Vector2(-1.94, 0.0), Vector2(hw - t * 0.5, 0.0), 1.2, 0.82, "Дверь в спальню")
	b.indoor(-hw, -hd, hw, hd, h)
	# изба (передняя): печь, стол, кухня
	var stove := MiscInteract.HeatSource.new()
	stove.source_id = b.bid + "/stove"
	stove.title = "Печь"
	stove.heat_radius = 6.0
	stove.light_offset = Vector3(0.0, 0.5, 0.75)
	stove.position = Vector3(-1.2, b.floor_y, 0.85)
	stove.setup_box(Vector3(1.25, 2.3, 1.4), Vector3(0, 1.15, 0))
	b.root.add_child(stove)
	Models.place("scandinavian_masonry_heater", stove, Transform3D(Basis(), Vector3(0.13, 0, -0.19)), "", 0.0)
	b.prop("dining_table", 2.6, 2.4, 0.0, "box", 1.7)
	b.prop("painted_wooden_chair_01", 1.8, 1.6, 0.0, "box")
	b.prop("painted_wooden_chair_01", 3.4, 3.3, 180.0, "box")
	b.container("kitchen", "kitchen", "Кухонный шкаф", 0.4, 0.4, 0.0, "painted_wooden_cabinet", Vector3(1.19, 1.18, 0.62), 10)
	var fr := b.container("fridge", "fridge", "Холодильник «ЗИЛ»", hw - 0.45, 0.5, -90.0, "", Vector3(0.6, 1.6, 0.6), 6, [], "box")
	Models.override_material(fr, Mats.get_mat("fridge"))
	b.prop("sofa_02", -0.9, hd - 0.6, 180.0, "box")
	# спальня (задняя)
	_bed(b, hw - 1.1, -hd + 1.2, 0.0, "Кровать", 1.0)
	b.container("nightstand", "nightstand", "Тумбочка", hw - 2.2, -hd + 0.4, 0.0, "painted_wooden_nightstand", Vector3(0.5, 0.62, 0.5), 6)
	b.container("wardrobe", "wardrobe", "Шифоньер", -1.4, -hd + 0.5, 0.0, "painted_wooden_cabinet_02", Vector3(1.0, 2.5, 0.72), 12)
	b.container("desk", "desk", "Письменный стол", 0.8, -0.5, 180.0, "", Vector3(1.2, 0.75, 0.6), 8, [], "box")
	b.prop("wall_clock", 1.8, -0.12, 180.0, "", 0.0, 1.9)
	# кладовка + подпол
	b.container("pantry_shelf", "pantry", "Полки в кладовке", -4.0, -hd + 0.35, 0.0, "painted_wooden_shelves", Vector3(0.55, 1.1, 0.4), 8)
	var cellar := CellarHatch.new()
	cellar.container_id = b.bid + "/cellar"
	cellar.loot_table = "pantry"
	cellar.title = "Подпол"
	cellar.visual = "hatch"
	cellar.box_size = Vector3(0.9, 0.1, 0.9)
	cellar.blocking = false
	cellar.position = Vector3(-3.3, b.floor_y, -1.5)
	b.root.add_child(cellar)
	b.container("entry", "shed", "Ящик в сенях", -4.2, 2.5, 90.0, "wooden_crate_02", Vector3(0.55, 0.5, 1.1), 6)
	_story(b, def)
	_yard(b, def, w, d)


## Сюжетное наполнение по id здания.
static func _story(b: BuildingBuilder, def: Dictionary) -> void:
	match str(def.id):
		"vera":
			b.container("doormat", "", "Коврик у двери", -3.5, 4.75, 0.0, "", Vector3(0.9, 0.04, 0.6), 2, [["key_vera", 1]], "mat", 0.0)
			b.item("doc_vera_1", "note1", 2.6, 2.4, 0.86)
			b.item("doc_essay_2", "alya_book", 1.0, -0.5, 0.78)
			b.trigger("entered_vera", -4.0, -3.0, 4.0, 3.0, "Дом Веры. Пахнет сыростью и её духами.")
			b.chalk("В.Л. ушла на «Луч» →", Vector3(4.65, 1.6, -1.0), -90.0, 48)
		"tikhon":
			b.item("doc_newspaper", "paper", 2.4, 2.2, 0.86)
		"h_e1":
			b.item("key_garage", "garage_key", 0.8, -0.5, 0.78)
			b.item("doc_postman", "postman_log", 1.0, 2.0, 0.86)
		"h_n3":
			_stash(b, Vector3(1.6, 0, 1.5))
		"h_e2":
			_stash(b, Vector3(-2.6, 0, -1.4))
			b.item("doc_diy", "diy", 2.0, 2.0, 0.86)
		"h_n1":
			b.item("doc_leaflet", "leaflet", -3.0, 2.0, 0.0)
		"h_s2":
			b.item("doc_chalk", "chalk_note", 2.6, 2.6, 0.86)
			b.item("chalk", "chalk", 2.2, 2.2, 0.86)
		"h_n5":
			b.item("crowbar", "crowbar", -3.6, 2.0, 0.0)
		"h_s1":
			b.item("axe", "axe", -3.6, 1.4, 0.0)


static func _stash(b: BuildingBuilder, p: Vector3) -> void:
	var c := LootContainer.new()
	c.container_id = b.bid + "/stash"
	c.loot_table = "stash"
	c.title = "Тайник под половицей"
	c.hidden = true
	c.visual = "floorboard"
	c.box_size = Vector3(0.9, 0.12, 0.3)
	c.blocking = false
	c.slots_count = 8
	c.position = p + Vector3(0, b.floor_y, 0)
	b.root.add_child(c)


# ============================================================================== ФАП
static func _fap(b: BuildingBuilder, def: Dictionary) -> void:
	var w := 13.0
	var d := 8.0
	var h := 3.0
	var t := 0.25
	b.floor_y = 0.3
	var hw := w * 0.5
	var hd := d * 0.5
	b.body.set_meta("surface", "concrete")
	b.foundation(w, d, "concrete")
	b.floor_rect(-hw, -hd, hw, hd, "linoleum")
	b.ceiling_rect(-hw, -hd, hw, hd, b.floor_y + h)
	var wi := "wall_green"
	b.wall(Vector2(-hw - t * 0.5, hd), Vector2(hw + t * 0.5, hd), h, [
		{"at": 0.0, "w": 1.1, "top": 2.15, "kind": "door"},
		{"at": -4.5, "w": 1.4, "bottom": 0.9, "top": 2.3, "kind": "window"},
		{"at": -2.0, "w": 1.0, "bottom": 0.9, "top": 2.3, "kind": "window"},
		{"at": 2.0, "w": 1.0, "bottom": 0.9, "top": 2.3, "kind": "window"},
		{"at": 4.5, "w": 1.4, "bottom": 0.9, "top": 2.3, "kind": "window"}], "plaster_white", wi, t)
	b.wall(Vector2(hw, hd - t * 0.5), Vector2(hw, -hd + t * 0.5), h, [{"at": 0.0, "w": 1.2, "bottom": 0.9, "top": 2.3, "kind": "window"}], "plaster_white", wi, t)
	b.wall(Vector2(hw + t * 0.5, -hd), Vector2(-hw - t * 0.5, -hd), h, [{"at": 4.5, "w": 1.2, "bottom": 0.9, "top": 2.3, "kind": "window"}, {"at": -4.5, "w": 1.2, "bottom": 0.9, "top": 2.3, "kind": "window"}], "plaster_white", wi, t)
	b.wall(Vector2(-hw, -hd + t * 0.5), Vector2(-hw, hd - t * 0.5), h, [{"at": 0.0, "w": 1.2, "bottom": 0.9, "top": 2.3, "kind": "window"}], "plaster_white", wi, t)
	b.wall(Vector2(-2.5, -hd + t * 0.5), Vector2(-2.5, hd - t * 0.5), h, [{"at": 1.8, "w": 0.9, "top": 2.05, "kind": "door"}], wi, wi, 0.15)
	b.wall(Vector2(2.5, hd - t * 0.5), Vector2(2.5, -hd + t * 0.5), h, [{"at": -1.8, "w": 0.9, "top": 2.05, "kind": "door"}], wi, wi, 0.15)
	b.wall(Vector2(-2.43, 0.0), Vector2(2.43, 0.0), h, [{"at": 0.0, "w": 0.9, "top": 2.05, "kind": "door"}], wi, wi, 0.15)
	b.gable_roof(w, d, h, 1.4, 0.45, "roof_slate", "plaster_white")
	b.porch(0.0, hd, 2.2, "concrete")
	b.door("front", Vector2(-hw - t * 0.5, hd), Vector2(hw + t * 0.5, hd), 0.0, 1.05, "Дверь ФАП")
	b.door("office", Vector2(-2.5, -hd + t * 0.5), Vector2(-2.5, hd - t * 0.5), 1.8, 0.88, "Кабинет фельдшера", true, "key_fap", "door", 2.0, true)
	b.door("proc", Vector2(2.5, hd - t * 0.5), Vector2(2.5, -hd + t * 0.5), -1.8, 0.88, "Процедурная")
	b.door("store", Vector2(-2.43, 0.0), Vector2(2.43, 0.0), 0.0, 0.88, "Аптечный склад", true, "", "door", 2.0, true)
	b.indoor(-hw, -hd, hw, hd, h)
	# приёмная
	for i in 3:
		b.prop("SchoolChair_01", -1.6 + i * 0.7, hd - 0.6, 180.0, "box")
	b.item("doc_leaflet", "leaflet", 1.5, 2.8, 0.0)
	# кабинет Веры
	b.prop("metal_office_desk", -4.5, -2.6, 0.0, "box")
	b.container("vera_desk", "desk", "Стол фельдшера", -4.5, -2.0, 180.0, "", Vector3(1.8, 0.1, 0.6), 8, [["doc_vera_2", 1], ["bandage", 2]], "", 0.78)
	b.prop("painted_wooden_chair_02", -4.5, -1.6, 180.0, "box")
	b.container("vera_cab", "medical", "Медицинский шкаф", -6.1, 1.0, 90.0, "painted_wooden_cabinet_02", Vector3(1.0, 2.5, 0.72), 10)
	b.prop("sofa_02", -4.4, 3.4, 180.0, "box")
	b.trigger("entered_fap_office", -6.4, -3.9, -2.6, 3.9, "Кабинет Веры. На столе — журнал приёма.")
	# процедурная
	b.container("proc_cab", "medical", "Шкаф с медикаментами", 6.1, -1.0, -90.0, "painted_wooden_cabinet_02", Vector3(1.0, 2.5, 0.72), 10)
	b.container("proc_box", "medical", "Укладка", 4.5, -3.5, 0.0, "medical_box", Vector3(0.53, 0.1, 0.35), 6, [], "", 0.0)
	_bed(b, 4.5, 2.4, 90.0, "Кушетка", 0.8)
	# склад
	b.container("store1", "medical", "Коробки с лекарствами", -1.5, -3.5, 0.0, "wooden_crate_01", Vector3(0.83, 0.35, 0.41), 8)
	b.container("store2", "medical", "Стеллаж", 1.5, -3.6, 0.0, "painted_wooden_shelves", Vector3(0.55, 1.1, 0.4), 8)


# ========================================================================= МАГАЗИН
static func _shop(b: BuildingBuilder, def: Dictionary) -> void:
	var w := 10.0
	var d := 8.0
	var h := 3.2
	var t := 0.3
	b.floor_y = 0.25
	var hw := w * 0.5
	var hd := d * 0.5
	b.body.set_meta("surface", "concrete")
	b.foundation(w, d, "concrete")
	b.floor_rect(-hw, -hd, hw, hd, "tiles")
	b.ceiling_rect(-hw, -hd, hw, hd, b.floor_y + h)
	b.wall(Vector2(-hw - t * 0.5, hd), Vector2(hw + t * 0.5, hd), h, [
		{"at": 0.0, "w": 1.3, "top": 2.2, "kind": "door"},
		{"at": -3.0, "w": 2.4, "bottom": 0.7, "top": 2.5, "kind": "window", "broken": true},
		{"at": 3.0, "w": 2.4, "bottom": 0.7, "top": 2.5, "kind": "window", "broken": false}], "brick", "wall_int", t)
	b.wall(Vector2(hw, hd - t * 0.5), Vector2(hw, -hd + t * 0.5), h, [], "brick", "wall_int", t)
	b.wall(Vector2(hw + t * 0.5, -hd), Vector2(-hw - t * 0.5, -hd), h, [{"at": -3.0, "w": 1.0, "top": 2.1, "kind": "door"}], "brick", "wall_int", t)
	b.wall(Vector2(-hw, -hd + t * 0.5), Vector2(-hw, hd - t * 0.5), h, [], "brick", "wall_int", t)
	b.wall(Vector2(-hw + t * 0.5, -1.0), Vector2(hw - t * 0.5, -1.0), h, [{"at": 3.0, "w": 0.9, "top": 2.05, "kind": "door"}], "wall_int", "wall_int", 0.15)
	b.flat_roof(w, d, h, 0.3, "roof_slate", "brick")
	b.door("front", Vector2(-hw - t * 0.5, hd), Vector2(hw + t * 0.5, hd), 0.0, 1.25, "Дверь магазина")
	b.door("store", Vector2(-hw + t * 0.5, -1.0), Vector2(hw - t * 0.5, -1.0), 3.0, 0.88, "Подсобка", true, "", "door", 2.0, true)
	b.door("back", Vector2(hw + t * 0.5, -hd), Vector2(-hw - t * 0.5, -hd), -3.0, 0.95, "Чёрный ход", true, "", "metal_rust", 2.0, true)
	b.indoor(-hw, -hd, hw, hd, h)
	# прилавок
	b.box("wood_dark", Vector3(-3.5, b.floor_y, -0.3), Vector3(1.5, b.floor_y + 1.0, 0.5))
	b.prop("CashRegister_01", 0.6, 0.1, 180.0, "", 0.0, 1.0)
	for i in 4:
		b.container("shelf_%d" % i, "shop_shelf", "Полка магазина", -4.5, -0.2 + i * 1.1, 90.0, "painted_wooden_shelves", Vector3(0.55, 1.1, 0.4), 6)
	b.container("shelf_r1", "shop_shelf", "Стеллаж", 4.5, 0.8, -90.0, "painted_wooden_shelves", Vector3(0.55, 1.1, 0.4), 6)
	b.container("shelf_r2", "shop_shelf", "Стеллаж", 4.5, 2.2, -90.0, "painted_wooden_shelves", Vector3(0.55, 1.1, 0.4), 6)
	# подсобка
	b.container("crates1", "shop_storage", "Ящики с товаром", -3.5, -3.2, 0.0, "wooden_crate_02", Vector3(0.53, 0.46, 1.17), 10)
	b.container("crates2", "shop_storage", "Коробки", -1.5, -3.4, 0.0, "wooden_crate_01", Vector3(0.83, 0.35, 0.41), 8)
	b.prop("Barrel_01", 1.2, -3.3, 0.0, "box")
	b.item("doc_newspaper", "paper", -1.0, 0.1, 1.0)


# ============================================================================ ШКОЛА
static func _school(b: BuildingBuilder, def: Dictionary) -> void:
	var w := 26.0
	var d := 10.0
	var h := 3.3
	var t := 0.35
	b.floor_y = 0.45
	var hw := w * 0.5
	var hd := d * 0.5
	b.body.set_meta("surface", "concrete")
	b.foundation(w, d, "concrete")
	b.floor_rect(-hw, -hd, hw, hd, "floor_wood")
	b.ceiling_rect(-hw, -hd, hw, hd, b.floor_y + h)
	var fr := []
	for x in [-11.0, -8.0, -5.0, 3.0, 6.0, 9.0, 11.8]:
		fr.append({"at": x, "w": 1.4, "bottom": 0.9, "top": 2.6, "kind": "window"})
	fr.append({"at": 0.0, "w": 1.6, "top": 2.3, "kind": "door"})
	b.wall(Vector2(-hw - t * 0.5, hd), Vector2(hw + t * 0.5, hd), h, fr, "brick", "wall_int", t)
	b.wall(Vector2(hw, hd - t * 0.5), Vector2(hw, -hd + t * 0.5), h, [{"at": -2.0, "w": 1.4, "bottom": 0.9, "top": 2.6, "kind": "window"}], "brick", "wall_green", t)
	var bk := []
	for x in [-10.5, -7.0, -1.5, 1.5, 7.0, 10.5]:
		bk.append({"at": x, "w": 1.5, "bottom": 0.9, "top": 2.6, "kind": "window"})
	b.wall(Vector2(hw + t * 0.5, -hd), Vector2(-hw - t * 0.5, -hd), h, bk, "brick", "wall_green", t)
	b.wall(Vector2(-hw, -hd + t * 0.5), Vector2(-hw, hd - t * 0.5), h, [{"at": 2.0, "w": 1.4, "bottom": 0.9, "top": 2.6, "kind": "window"}], "brick", "wall_green", t)
	# коридор вдоль фасада (z 2..5), классы за ним
	b.wall(Vector2(-hw + t * 0.5, 2.0), Vector2(hw - t * 0.5, 2.0), h, [
		{"at": -8.75, "w": 0.95, "top": 2.1, "kind": "door"}, {"at": 0.0, "w": 0.95, "top": 2.1, "kind": "door"}, {"at": 8.75, "w": 0.95, "top": 2.1, "kind": "door"}], "wall_green", "wall_green", 0.18)
	b.wall(Vector2(-4.5, -hd + t * 0.5), Vector2(-4.5, 1.91), h, [], "wall_green", "wall_green", 0.15)
	b.wall(Vector2(4.5, 1.91), Vector2(4.5, -hd + t * 0.5), h, [], "wall_green", "wall_green", 0.15)
	b.gable_roof(w, d, h, 2.2, 0.5, "roof_slate", "brick")
	b.porch(0.0, hd, 2.8, "concrete")
	b.door("front", Vector2(-hw - t * 0.5, hd), Vector2(hw + t * 0.5, hd), 0.0, 1.5, "Двери школы")
	for i in 3:
		b.door("class%d" % i, Vector2(-hw + t * 0.5, 2.0), Vector2(hw - t * 0.5, 2.0), [-8.75, 0.0, 8.75][i], 0.9, "Дверь класса")
	b.indoor(-hw, -hd, hw, hd, h)
	# классы
	var boards := ["3 октября\nКлассная работа\n«Осень в родном краю»", "НЕ ВЫХОДИТЕ НОЧЬЮ\nНЕ ОТВЕЧАЙТЕ", "Домашнее задание:\n§ 14, упр. 3\n\nАля Л. — дежурная"]
	for ci in 3:
		var cx = [-8.75, 0.0, 8.75][ci]
		# доска
		b.box("chalkboard", Vector3(cx - 1.8, b.floor_y + 1.0, -hd + t * 0.5), Vector3(cx + 1.8, b.floor_y + 2.2, -hd + t * 0.5 + 0.05), false)
		var lbl := Label3D.new()
		lbl.text = boards[ci]
		lbl.font_size = 40
		lbl.pixel_size = 0.005
		lbl.modulate = Color(0.85, 0.85, 0.8, 0.9)
		lbl.position = Vector3(cx, b.floor_y + 1.6, -hd + t * 0.5 + 0.07)
		lbl.shaded = true
		b.root.add_child(lbl)
		b.container("teacher_%d" % ci, "teacher_desk", "Учительский стол", cx - 2.6, -hd + 1.6, 0.0, "", Vector3(1.2, 0.75, 0.6), 8, [], "box")
		for row in 3:
			for col in 3:
				var px = cx - 2.4 + col * 2.2
				var pz := -1.8 + row * 1.25
				b.box("wood_light", Vector3(px - 0.55, b.floor_y + 0.68, pz - 0.25), Vector3(px + 0.55, b.floor_y + 0.73, pz + 0.25), false)
				b.box("metal_dark", Vector3(px - 0.5, b.floor_y, pz - 0.2), Vector3(px + 0.5, b.floor_y + 0.68, pz - 0.15))
				if (row + col + ci) % 3 != 0:
					b.prop("SchoolChair_01", px - 0.2, pz + 0.45, 180.0 + b.rng.randf_range(-20, 20), "", 0.0)
				if row == 1 and col == 1:
					b.container("desk_%d" % ci, "school_desk", "Парта", px, pz, 0.0, "", Vector3(1.0, 0.1, 0.4), 4, [["doc_essay_1", 1]] if ci == 1 else [], "", 0.73)
	# вход в убежище (во дворе за школой)
	var hatch := ShelterEntrance.new()
	hatch.position = Vector3(-3.0, 0.0, -hd - 2.6)
	hatch.school = b.root
	b.root.add_child(hatch)
	_shelter(b, Vector3(0, -30.0, 0))


## Убежище ГО под школой — отдельное помещение глубоко под землёй (вход/выход — переход).
static func _shelter(b: BuildingBuilder, o: Vector3) -> void:
	var w := 9.0
	var d := 6.0
	var h := 2.4
	var saved_floor := b.floor_y
	b.floor_y = o.y
	var hw := w * 0.5
	var hd := d * 0.5
	b.box("concrete_floor", Vector3(-hw - 0.3, o.y - 0.3, -hd - 0.3), Vector3(hw + 0.3, o.y, hd + 0.3))
	b.box("concrete", Vector3(-hw - 0.3, o.y + h, -hd - 0.3), Vector3(hw + 0.3, o.y + h + 0.3, hd + 0.3))
	b.wall(Vector2(-hw - 0.15, hd), Vector2(hw + 0.15, hd), h, [], "concrete", "concrete", 0.3, o.y)
	b.wall(Vector2(hw, hd), Vector2(hw, -hd), h, [{"at": 0.0, "w": 1.0, "top": 2.0, "kind": "door"}], "concrete", "concrete", 0.3, o.y)
	b.wall(Vector2(hw + 0.15, -hd), Vector2(-hw - 0.15, -hd), h, [], "concrete", "concrete", 0.3, o.y)
	b.wall(Vector2(-hw, -hd), Vector2(-hw, hd), h, [], "concrete", "concrete", 0.3, o.y)
	b.indoor(-hw, -hd, hw, hd, h, true, o.y)
	var exit := ShelterExit.new()
	exit.position = Vector3(hw - 0.2, o.y, 0)
	exit.rotation.y = deg_to_rad(-90)
	exit.school = b.root
	b.root.add_child(exit)
	# обстановка
	_bed(b, -hw + 0.6, -hd + 1.1, 90.0, "Нары", 0.8)
	_bed(b, -hw + 0.6, hd - 1.1, 90.0, "Нары (Аля спала здесь)", 0.8)
	b.box("wood_light", Vector3(-1.0, o.y + 0.72, -0.5), Vector3(1.0, o.y + 0.78, 0.5))
	b.box("wood_dark", Vector3(-0.9, o.y, -0.4), Vector3(-0.8, o.y + 0.72, 0.4))
	b.box("wood_dark", Vector3(0.8, o.y, -0.4), Vector3(0.9, o.y + 0.72, 0.4))
	b.item("vera_tape", "tape", -0.3, 0.0, 0.79)
	b.item("radio", "radio", 0.4, 0.1, 0.79)
	b.item("batteries", "batt", 0.6, -0.2, 0.79, 2)
	b.container("mil", "military", "Армейский ящик", 2.5, -hd + 0.6, 0.0, "old_military_crate", Vector3(1.82, 0.3, 0.98), 8, [["earplugs", 4]])
	b.container("shelf", "pantry", "Стеллаж с припасами", 2.6, hd - 0.4, 180.0, "painted_wooden_shelves", Vector3(0.55, 1.1, 0.4), 8)
	b.prop("vintage_oil_lamp", 0.0, -0.3, 0.0, "", 0.0, 0.79)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.7, 0.4)
	lamp.omni_range = 7.0
	lamp.light_energy = 1.1
	lamp.position = Vector3(0.0, o.y + 1.4, -0.3)
	b.root.add_child(lamp)
	var draw := Label3D.new()
	draw.text = "дядя Глеб\n🎹 ♪ ♫\nприезжай!"
	draw.font_size = 48
	draw.pixel_size = 0.004
	draw.modulate = Color(0.95, 0.7, 0.5)
	draw.position = Vector3(-hw + 0.17, o.y + 1.5, -1.2)
	draw.rotation.y = deg_to_rad(90)
	draw.shaded = true
	b.root.add_child(draw)
	b.trigger("entered_shelter", -hw, -hd, hw, hd, "Убежище. Здесь жили Вера и Аля. Тихо — гул сюда не доходит.")
	b.floor_y = saved_floor


# ========================================================================== ГАРАЖИ
static func _garages(b: BuildingBuilder, def: Dictionary) -> void:
	var w := 16.0
	var d := 6.0
	var h := 2.6
	b.floor_y = 0.1
	var hw := w * 0.5
	var hd := d * 0.5
	b.body.set_meta("surface", "concrete")
	b.foundation(w, d, "concrete", 1.2)
	b.floor_rect(-hw, -hd, hw, hd, "concrete_floor")
	var ops := []
	for i in 4:
		ops.append({"at": -6.0 + i * 4.0, "w": 2.8, "top": 2.2, "kind": "hole"})
	b.wall(Vector2(-hw - 0.1, hd), Vector2(hw + 0.1, hd), h, ops, "brick", "concrete", 0.2)
	b.wall(Vector2(hw, hd - 0.1), Vector2(hw, -hd + 0.1), h, [], "brick", "concrete", 0.2)
	b.wall(Vector2(hw + 0.1, -hd), Vector2(-hw - 0.1, -hd), h, [], "brick", "concrete", 0.2)
	b.wall(Vector2(-hw, -hd + 0.1), Vector2(-hw, hd - 0.1), h, [], "brick", "concrete", 0.2)
	for i in 3:
		var x := -4.0 + i * 4.0
		b.wall(Vector2(x, hd - 0.1), Vector2(x, -hd + 0.1), h, [], "concrete", "concrete", 0.15)
	b.flat_roof(w, d, h, 0.25, "roof_slate")
	b.indoor(-hw, -hd, hw, hd, h)
	for i in 4:
		var x := -6.0 + i * 4.0
		var locked := i == 1
		var dr := b.door("gate%d" % i, Vector2(-hw - 0.1, hd), Vector2(hw + 0.1, hd), x, 2.8, "Ворота гаража №%d" % (i + 1), locked, "key_garage" if locked else "", "metal_rust", 2.2, i != 1)
		dr.heavy = true
		if i == 3:
			dr.locked = false
		b.container("shelf%d" % i, "garage", "Полки гаража №%d" % (i + 1), x, -hd + 0.4, 0.0, "painted_wooden_shelves", Vector3(0.55, 1.1, 0.4), 10,
			[["car_battery", 1], ["spark_plugs", 1]] if i == 1 else [])
		if i != 1:
			b.container("box%d" % i, "toolbox", "Ящик с инструментом", x + 1.2, -hd + 0.5, 0.0, "metal_toolbox", Vector3(0.4, 0.35, 0.29), 6)
	b.chalk("№2 ПОЧТА", Vector3(-2.0, 2.35, hd + 0.12), 0.0, 64)


# ===================================================================== ОХОТН. ДОМИК
static func _cabin(b: BuildingBuilder, def: Dictionary) -> void:
	var w := 5.2
	var d := 4.4
	var h := 2.3
	var t := 0.22
	b.floor_y = 0.35
	var hw := w * 0.5
	var hd := d * 0.5
	b.foundation(w, d, "planks_ext", 1.2)
	b.floor_rect(-hw, -hd, hw, hd, "floor_wood")
	b.ceiling_rect(-hw, -hd, hw, hd, b.floor_y + h, "planks_ext")
	b.wall(Vector2(-hw - t * 0.5, hd), Vector2(hw + t * 0.5, hd), h, [{"at": -1.2, "w": 0.85, "top": 1.95, "kind": "door"}, {"at": 1.2, "w": 0.8, "bottom": 0.9, "top": 1.7, "kind": "window", "frame": "frame_dark"}], "planks_ext", "planks_ext", t)
	b.wall(Vector2(hw, hd - t * 0.5), Vector2(hw, -hd + t * 0.5), h, [], "planks_ext", "planks_ext", t)
	b.wall(Vector2(hw + t * 0.5, -hd), Vector2(-hw - t * 0.5, -hd), h, [{"at": 0.0, "w": 0.7, "bottom": 1.0, "top": 1.6, "kind": "window", "frame": "frame_dark"}], "planks_ext", "planks_ext", t)
	b.wall(Vector2(-hw, -hd + t * 0.5), Vector2(-hw, hd - t * 0.5), h, [], "planks_ext", "planks_ext", t)
	b.gable_roof(w, d, h, 1.4, 0.45, "roof_iron", "planks_ext")
	b.porch(-1.2, hd, 1.4)
	b.door("front", Vector2(-hw - t * 0.5, hd), Vector2(hw + t * 0.5, hd), -1.2, 0.82, "Дверь домика")
	b.indoor(-hw, -hd, hw, hd, h)
	var stove := MiscInteract.HeatSource.new()
	stove.source_id = b.bid + "/stove"
	stove.title = "Печка-буржуйка"
	stove.heat_radius = 4.5
	stove.position = Vector3(hw - 0.6, b.floor_y, hd - 0.7)
	stove.setup_box(Vector3(0.6, 0.86, 0.6), Vector3(0, 0.43, 0))
	b.root.add_child(stove)
	Models.place("barrel_stove", stove, Transform3D.IDENTITY, "", 0.0)
	_bed(b, -hw + 0.6, -hd + 1.1, 90.0, "Топчан", 0.8)
	b.container("chest", "cabin_chest", "Сундук охотника", hw - 0.6, -hd + 0.5, 0.0, "old_military_crate", Vector3(1.0, 0.4, 0.6), 10, [], "", 0.0)
	b.box("wood_dark", Vector3(-0.5, b.floor_y + 0.7, -hd + 0.25), Vector3(0.7, b.floor_y + 0.75, -hd + 0.9))
	b.item("doc_cabin", "diary", 0.1, -hd + 0.55, 0.76)
	b.item("matches", "matches", 0.5, -hd + 0.5, 0.76)


# ========================================================================= ЗАПРАВКА
static func _gas_shop(b: BuildingBuilder, def: Dictionary) -> void:
	var w := 12.0
	var d := 7.0
	var h := 3.0
	var t := 0.25
	b.floor_y = 0.2
	var hw := w * 0.5
	var hd := d * 0.5
	b.body.set_meta("surface", "concrete")
	b.foundation(w, d, "concrete", 1.2)
	b.floor_rect(-hw, -hd, hw, hd, "tiles")
	b.ceiling_rect(-hw, -hd, hw, hd, b.floor_y + h)
	b.wall(Vector2(-hw - t * 0.5, hd), Vector2(hw + t * 0.5, hd), h, [
		{"at": 0.0, "w": 1.2, "top": 2.2, "kind": "door"},
		{"at": -3.2, "w": 3.6, "bottom": 0.6, "top": 2.5, "kind": "window", "broken": true},
		{"at": 3.2, "w": 3.6, "bottom": 0.6, "top": 2.5, "kind": "window", "broken": true}], "plaster", "wall_int", t)
	b.wall(Vector2(hw, hd - t * 0.5), Vector2(hw, -hd + t * 0.5), h, [], "plaster", "wall_int", t)
	b.wall(Vector2(hw + t * 0.5, -hd), Vector2(-hw - t * 0.5, -hd), h, [{"at": 4.0, "w": 0.95, "top": 2.1, "kind": "door"}], "plaster", "wall_int", t)
	b.wall(Vector2(-hw, -hd + t * 0.5), Vector2(-hw, hd - t * 0.5), h, [], "plaster", "wall_int", t)
	b.wall(Vector2(1.5, -hd + t * 0.5), Vector2(1.5, 0.5), h, [], "wall_int", "wall_int", 0.15)
	b.wall(Vector2(1.43, 0.5), Vector2(hw - t * 0.5, 0.5), h, [{"at": 1.5, "w": 0.9, "top": 2.05, "kind": "door"}], "wall_int", "wall_int", 0.15)
	b.flat_roof(w, d, h, 0.4, "roof_slate", "plaster")
	b.door("front", Vector2(-hw - t * 0.5, hd), Vector2(hw + t * 0.5, hd), 0.0, 1.15, "Дверь заправки")
	b.door("office", Vector2(1.43, 0.5), Vector2(hw - t * 0.5, 0.5), 1.5, 0.88, "Подсобка")
	b.door("back", Vector2(hw + t * 0.5, -hd), Vector2(-hw - t * 0.5, -hd), 4.0, 0.92, "Чёрный ход", true, "", "metal_rust", 2.0, true)
	b.indoor(-hw, -hd, hw, hd, h)
	b.box("wood_dark", Vector3(-1.0, b.floor_y, -1.6), Vector3(0.8, b.floor_y + 1.0, -1.0))
	b.prop("CashRegister_01", -0.1, -1.3, 0.0, "", 0.0, 1.0)
	for i in 3:
		b.container("shelf%d" % i, "station_shelf", "Стеллаж", -5.4, 2.4 - i * 1.4, 90.0, "painted_wooden_shelves", Vector3(0.55, 1.1, 0.4), 6)
	# логово Шакалов в подсобке
	_bed(b, 4.6, -1.6, 0.0, "Грязный матрас", 0.6)
	b.container("jackal_crate", "military", "Ящик Шакалов", 2.6, -2.9, 0.0, "old_military_crate", Vector3(1.82, 0.3, 0.98), 8, [["doc_soldier", 1]], "", 0.0)
	b.prop("Barrel_01", 5.3, -0.2, 0.0, "box")
	# записка Марты на двери снаружи
	b.item("doc_marta", "marta_note", 0.9, hd + 0.35, 0.0)
	b.chalk("✗  ШАКАЛЫ", Vector3(-3.2, 2.7, hd + 0.14), 0.0, 96)


static func _shed(b: BuildingBuilder, def: Dictionary) -> void:
	var w := 6.0
	var d := 5.0
	var h := 2.6
	b.floor_y = 0.1
	var hw := w * 0.5
	var hd := d * 0.5
	b.body.set_meta("surface", "metal")
	b.foundation(w, d, "concrete", 1.0)
	b.floor_rect(-hw, -hd, hw, hd, "concrete_floor")
	b.wall(Vector2(-hw - 0.05, hd), Vector2(hw + 0.05, hd), h, [{"at": 0.0, "w": 1.6, "top": 2.1, "kind": "hole"}], "roof_iron", "roof_iron", 0.1)
	b.wall(Vector2(hw, hd - 0.05), Vector2(hw, -hd + 0.05), h, [], "roof_iron", "roof_iron", 0.1)
	b.wall(Vector2(hw + 0.05, -hd), Vector2(-hw - 0.05, -hd), h, [], "roof_iron", "roof_iron", 0.1)
	b.wall(Vector2(-hw, -hd + 0.05), Vector2(-hw, hd - 0.05), h, [], "roof_iron", "roof_iron", 0.1)
	b.flat_roof(w, d, h, 0.2, "roof_iron")
	var dr := b.door("gate", Vector2(-hw - 0.05, hd), Vector2(hw + 0.05, hd), 0.0, 1.6, "Ворота склада", true, "", "metal_rust", 2.1, true)
	dr.heavy = true
	b.indoor(-hw, -hd, hw, hd, h)
	b.container("shelves", "garage", "Стеллаж", -2.4, -1.5, 90.0, "painted_wooden_shelves", Vector3(0.55, 1.1, 0.4), 10)
	b.container("fuel", "", "Канистры", 2.0, -1.7, 0.0, "metal_jerrycan_green", Vector3(0.6, 0.5, 0.3), 4, [["fuel_can", 1]])
	b.prop("Barrel_01", 2.3, 1.3, 0.0, "box")
	b.prop("Barrel_01", 1.6, 1.6, 30.0, "box")


# ======================================================================== ПОДПОЛ
## Люк в подпол: обыскать; во время Гула — спрятаться (полная защита).
class CellarHatch:
	extends LootContainer

	func get_prompt(player: Node) -> String:
		if GameState.is_hum_active() or GameState.time_min > GameState.next_hum_at - 30.0:
			return "Подпол — спрятаться от Гула"
		return super.get_prompt(player)

	func interact(player: Node) -> void:
		if GameState.is_hum_active() or GameState.time_min > GameState.next_hum_at - 30.0:
			Events.open_screen.emit("hide", {"title": "Подпол"})
			return
		super.interact(player)


## Вход в убежище ГО (во дворе школы): железная дверь в приямке → переход вниз.
class ShelterEntrance:
	extends Interactable
	var school: Node3D

	func _ready() -> void:
		setup_box(Vector3(1.6, 1.2, 1.2), Vector3(0, 0.6, 0))
		var kit := MeshKit.new()
		kit.add_box(Mats.get_mat("concrete"), Transform3D(Basis(), Vector3(0, 0.3, 0)), Vector3(1.8, 0.6, 1.4))
		kit.add_box(Mats.get_mat("metal_rust"), Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, 0.75, 0.0)), Vector3(1.2, 0.08, 1.0))
		kit.add_box(Mats.get_mat("metal_dark"), Transform3D(Basis(), Vector3(0.4, 0.9, 0.2)), Vector3(0.12, 0.05, 0.05))
		add_child(kit.build_instance("Hatch"))
		var l := Label3D.new()
		l.text = "УБЕЖИЩЕ ГО\nВХОД"
		l.font_size = 48
		l.pixel_size = 0.004
		l.modulate = Color(0.8, 0.75, 0.6)
		l.position = Vector3(0, 0.62, 0.71)
		l.shaded = true
		add_child(l)

	func get_prompt(player: Node) -> String:
		if not GameState.get_flag("shelter_open") and player.count_item("key_shelter") == 0:
			return "Железная дверь убежища — заперта (ключ у Тихона?)"
		return "Спуститься в убежище"

	func interact(player: Node) -> void:
		if not GameState.get_flag("shelter_open"):
			if player.count_item("key_shelter") == 0:
				AudioLib.play_3d("door_locked", global_position, 0.0)
				Events.notify.emit("Заперто. Такой замок не взломать.", "warn")
				return
			GameState.set_flag("shelter_open")
			AudioLib.play_3d("metal_clank", global_position, 0.0)
		AudioLib.play_2d("door_creak_0", -2.0, 0.7)
		var target := school.to_global(Vector3(3.6, -30.0 + 0.1, 0.0))
		player.global_position = target
		player.set_look(school.global_rotation.y + PI * 0.5, 0.0)


class ShelterExit:
	extends Interactable
	var school: Node3D

	func _ready() -> void:
		setup_box(Vector3(1.0, 2.0, 0.3), Vector3(0, 1.0, 0))

	func get_prompt(_player: Node) -> String:
		return "Подняться наверх"

	func interact(player: Node) -> void:
		AudioLib.play_2d("door_creak_1", -2.0, 0.7)
		var p := school.to_global(Vector3(-3.0, 0.0, -5.0 - 4.2))
		p.y = RegionData.height_at(p.x, p.z) + 0.2
		player.global_position = p
		player.set_look(school.global_rotation.y + PI, 0.0)
