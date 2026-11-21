class_name Structures
extends RefCounted
## Сооружения вне зданий: колодцы, водонапорная башня, остановка, навес АЗС, ульи, стоянка туристов,
## мост, периметр с КПП‑вышкой, блокпост на трассе, линии электропередачи, дорога и ручей.


static func ground(x: float, z: float) -> float:
	return RegionData.height_at(x, z)


static func build(def: Dictionary, parent: Node3D) -> void:
	match str(def.type):
		"well": _well(def, parent)
		"water_tower": _water_tower(def, parent)
		"bus_stop": _bus_stop(def, parent)
		"fuel_canopy": _canopy(def, parent)
		"beehives": _beehives(def, parent)
		"camp": _camp(def, parent)
		"bridge": _bridge(def, parent)
		"perimeter_fence": _perimeter(def, parent)
		"watchtower": _watchtower(def, parent)
		"roadblock": _roadblock(def, parent)
		"power_line": _power_line(def, parent)


static func _node(parent: Node3D, name: String, x: float, z: float, rot_deg: float = 0.0) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = name
	b.collision_layer = 1
	b.position = Vector3(x, ground(x, z), z)
	b.rotation.y = deg_to_rad(rot_deg)
	parent.add_child(b)
	return b


static func _col(body: Node3D, size: Vector3, pos: Vector3, basis: Basis = Basis()) -> void:
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	cs.shape = s
	cs.transform = Transform3D(basis, pos)
	body.add_child(cs)


static func _well(def: Dictionary, parent: Node3D) -> void:
	var p: Array = def.pos
	var ws := MiscInteract.WaterSource.new()
	ws.title = "Колодец"
	ws.position = Vector3(p[0], ground(p[0], p[1]), p[1])
	parent.add_child(ws)
	ws.setup_box(Vector3(1.4, 1.0, 1.4), Vector3(0, 0.5, 0))
	var kit := MeshKit.new()
	# сруб
	for i in 6:
		var y := 0.1 + i * 0.16
		var off := 0.62
		kit.add_box(Mats.get_mat("bark"), Transform3D(Basis(), Vector3(0, y, off)), Vector3(1.4, 0.16, 0.16))
		kit.add_box(Mats.get_mat("bark"), Transform3D(Basis(), Vector3(0, y, -off)), Vector3(1.4, 0.16, 0.16))
		kit.add_box(Mats.get_mat("bark"), Transform3D(Basis(), Vector3(off, y + 0.08, 0)), Vector3(0.16, 0.16, 1.4))
		kit.add_box(Mats.get_mat("bark"), Transform3D(Basis(), Vector3(-off, y + 0.08, 0)), Vector3(0.16, 0.16, 1.4))
	kit.add_box(Mats.get_mat("dark"), Transform3D(Basis(), Vector3(0, 0.8, 0)), Vector3(1.05, 0.02, 1.05))
	for sx in [-0.7, 0.7]:
		kit.add_box(Mats.get_mat("wood_dark"), Transform3D(Basis(), Vector3(sx, 1.2, 0)), Vector3(0.1, 2.4, 0.1))
	kit.add_box(Mats.get_mat("wood_light"), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, 1.65, 0)), Vector3(0.18, 1.5, 0.18))
	for side in [-1.0, 1.0]:
		kit.add_box(Mats.get_mat("roof_iron"), Transform3D(Basis(Vector3.RIGHT, 0.6 * side), Vector3(0, 2.45, side * 0.45)), Vector3(1.8, 0.05, 1.05))
	kit.add_box(Mats.get_mat("metal_dark"), Transform3D(Basis(), Vector3(0.2, 1.2, 0)), Vector3(0.3, 0.32, 0.3))
	ws.add_child(kit.build_instance("Well"))


static func _water_tower(def: Dictionary, parent: Node3D) -> void:
	var p: Array = def.pos
	var b := _node(parent, "WaterTower", p[0], p[1])
	var kit := MeshKit.new()
	kit.add_cylinder(Mats.get_mat("brick"), Vector3(0, -0.5, 0), 13.0, 2.6, 2.2, 12)
	kit.add_cylinder(Mats.get_mat("metal_rust"), Vector3(0, 12.5, 0), 4.0, 3.6, 3.6, 14)
	kit.add_cylinder(Mats.get_mat("roof_iron"), Vector3(0, 16.5, 0), 1.6, 3.8, 0.3, 14)
	kit.add_box(Mats.get_mat("metal_dark"), Transform3D(Basis(), Vector3(0, 1.1, 2.55)), Vector3(0.9, 2.0, 0.1))
	b.add_child(kit.build_instance("Tower"))
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 2.5
	cyl.height = 13.0
	cs.shape = cyl
	cs.position.y = 6.0
	b.add_child(cs)
	var hum := AudioLib.make_loop_3d(b, "electric_buzz_loop", -14.0, 18.0)
	hum.position = Vector3(0, 1.0, 2.6)


static func _bus_stop(def: Dictionary, parent: Node3D) -> void:
	var p: Array = def.pos
	var b := _node(parent, "BusStop", p[0], p[1], float(def.get("rot", 0)))
	var kit := MeshKit.new()
	kit.add_box(Mats.get_mat("concrete"), Transform3D(Basis(), Vector3(0, 1.2, -0.8)), Vector3(4.0, 2.4, 0.15))
	kit.add_box(Mats.get_mat("concrete"), Transform3D(Basis(), Vector3(-2.0, 1.2, 0)), Vector3(0.15, 2.4, 1.6))
	kit.add_box(Mats.get_mat("concrete"), Transform3D(Basis(), Vector3(2.0, 1.2, 0)), Vector3(0.15, 2.4, 1.6))
	kit.add_box(Mats.get_mat("roof_slate"), Transform3D(Basis(), Vector3(0, 2.45, 0)), Vector3(4.4, 0.12, 2.0))
	kit.add_box(Mats.get_mat("wood_dark"), Transform3D(Basis(), Vector3(0, 0.45, -0.5)), Vector3(3.6, 0.08, 0.4))
	b.add_child(kit.build_instance("Stop"))
	_col(b, Vector3(4.0, 2.4, 0.15), Vector3(0, 1.2, -0.8))
	_col(b, Vector3(0.15, 2.4, 1.6), Vector3(-2.0, 1.2, 0))
	_col(b, Vector3(0.15, 2.4, 1.6), Vector3(2.0, 1.2, 0))
	var l := Label3D.new()
	l.text = "СОСНОВКА\nавтобус № 112 — Каменск\n7:10  12:40  17:55"
	l.font_size = 40
	l.pixel_size = 0.004
	l.modulate = Color(0.8, 0.8, 0.75)
	l.position = Vector3(0.8, 1.6, -0.71)
	l.shaded = true
	b.add_child(l)
	var c := LootContainer.new()
	c.container_id = "bus_stop/bag"
	c.title = "Сумка на скамейке"
	c.loot_table = "car_glove"
	c.visual = "backpack"
	c.box_size = Vector3(0.4, 0.4, 0.3)
	c.position = Vector3(-1.0, 0.5, -0.5)
	b.add_child(c)


static func _canopy(def: Dictionary, parent: Node3D) -> void:
	var p: Array = def.pos
	var b := _node(parent, "FuelCanopy", p[0], p[1], float(def.get("rot", 0)))
	var kit := MeshKit.new()
	for x in [-5.0, 5.0]:
		for z in [-3.0, 3.0]:
			kit.add_box(Mats.get_mat("white_paint"), Transform3D(Basis(), Vector3(x, 2.6, z)), Vector3(0.35, 5.2, 0.35))
			_col(b, Vector3(0.35, 5.2, 0.35), Vector3(x, 2.6, z))
	kit.add_box(Mats.get_mat("white_paint"), Transform3D(Basis(), Vector3(0, 5.4, 0)), Vector3(14.0, 0.5, 9.0))
	kit.add_box(Mats.get_mat("red_paint"), Transform3D(Basis(), Vector3(0, 5.4, 4.52)), Vector3(14.0, 0.5, 0.05))
	kit.add_box(Mats.get_mat("concrete_floor"), Transform3D(Basis(), Vector3(0, 0.08, 0)), Vector3(15.0, 0.2, 10.0))
	for x in [-2.5, 2.5]:
		kit.add_box(Mats.get_mat("concrete"), Transform3D(Basis(), Vector3(x, 0.3, 0)), Vector3(1.2, 0.4, 3.0))
		kit.add_box(Mats.get_mat("red_paint"), Transform3D(Basis(), Vector3(x, 1.2, 0)), Vector3(0.7, 1.6, 0.5))
		kit.add_box(Mats.get_mat("glass_dirty"), Transform3D(Basis(), Vector3(x, 1.5, 0.26)), Vector3(0.45, 0.35, 0.02))
		_col(b, Vector3(1.2, 2.0, 0.6), Vector3(x, 1.0, 0))
	b.add_child(kit.build_instance("Canopy"))
	var l := Label3D.new()
	l.text = "ЛУЧ  •  АЗС  •  АИ‑92  АИ‑95  ДТ"
	l.font_size = 72
	l.pixel_size = 0.008
	l.modulate = Color(0.85, 0.82, 0.78)
	l.position = Vector3(0, 5.4, 4.56)
	l.shaded = true
	b.add_child(l)
	# Следы прежнего конфликта: мешки с песком, гильзы, кострище
	var k2 := MeshKit.new()
	for i in 7:
		k2.add_box(Mats.get_mat("sandbag"), Transform3D(Basis(Vector3.UP, i * 0.15), Vector3(-6.5 + i * 0.6, 0.2 + (i % 2) * 0.35, -7.5)), Vector3(0.6, 0.32, 0.4))
	b.add_child(k2.build_instance("Sandbags"))
	_col(b, Vector3(4.4, 0.9, 0.5), Vector3(-4.7, 0.45, -7.5))


static func _beehives(def: Dictionary, parent: Node3D) -> void:
	var p: Array = def.pos
	var b := _node(parent, "Beehives", p[0], p[1], float(def.get("rot", 0)))
	var kit := MeshKit.new()
	for i in 6:
		var x := -5.0 + (i % 3) * 3.0
		var z := -1.5 + int(i / 3) * 3.0
		var mat := "hive_yellow" if i % 2 == 0 else "hive_blue"
		kit.add_box(Mats.get_mat("wood_dark"), Transform3D(Basis(), Vector3(x, 0.2, z)), Vector3(0.6, 0.4, 0.6))
		kit.add_box(Mats.get_mat(mat), Transform3D(Basis(), Vector3(x, 0.75, z)), Vector3(0.55, 0.7, 0.5))
		kit.add_box(Mats.get_mat("roof_iron"), Transform3D(Basis(), Vector3(x, 1.14, z)), Vector3(0.7, 0.06, 0.65))
		kit.add_box(Mats.get_mat("dark"), Transform3D(Basis(), Vector3(x, 0.48, z + 0.26)), Vector3(0.25, 0.03, 0.02))
		_col(b, Vector3(0.6, 1.2, 0.6), Vector3(x, 0.6, z))
	b.add_child(kit.build_instance("Hives"))
	var buzz := AudioLib.make_loop_3d(b, "electric_buzz_loop", -26.0, 9.0)
	buzz.pitch_scale = 2.3


static func _camp(def: Dictionary, parent: Node3D) -> void:
	var p: Array = def.pos
	var root := Node3D.new()
	root.name = "Camp"
	root.position = Vector3(p[0], ground(p[0], p[1]), p[1])
	parent.add_child(root)
	for t in [[Vector3(-3, 0, -1), 30.0], [Vector3(2.5, 0, -2.5), -20.0]]:
		var tent := Models.place("k:survival-kit/tent-canvas", root, Transform3D(Basis(Vector3.UP, deg_to_rad(t[1])), t[0]), "box", 2.6)
		if tent:
			Models.tint(tent, Color(0.55, 0.6, 0.5))
	var fire := MiscInteract.HeatSource.new()
	fire.source_id = "camp/fire"
	fire.title = "Кострище"
	fire.heat_radius = 3.5
	fire.light_offset = Vector3(0, 0.4, 0)
	fire.setup_box(Vector3(1.4, 0.4, 1.4), Vector3(0, 0.2, 0))
	root.add_child(fire)
	Models.place("stone_fire_pit", fire, Transform3D.IDENTITY, "", 0.0)
	Models.place("tree_stump_01", root, Transform3D(Basis(), Vector3(1.8, 0, 1.2)), "box", 0.0)
	var log_kit := MeshKit.new()
	log_kit.add_box(Mats.get_mat("bark"), Transform3D(Basis(Vector3.UP, 0.3), Vector3(-1.5, 0.2, 1.6)), Vector3(2.2, 0.35, 0.35))
	root.add_child(log_kit.build_instance("Log"))
	var c := LootContainer.new()
	c.container_id = "camp/bag"
	c.title = "Рюкзак туристов"
	c.loot_table = "cabin_chest"
	c.visual = "backpack"
	c.box_size = Vector3(0.4, 0.5, 0.3)
	c.fixed_items = [["doc_camp", 1], ["earplugs", 2]]
	c.position = Vector3(-2.0, 0, 0.6)
	root.add_child(c)


static func _bridge(def: Dictionary, parent: Node3D) -> void:
	var p: Array = def.pos
	var b := StaticBody3D.new()
	b.name = "Bridge"
	b.collision_layer = 1
	b.set_meta("surface", "wood")
	var rot := deg_to_rad(float(def.get("rot", 0)))
	var y := maxf(ground(p[0] - 9.0 * cos(rot), p[1] + 9.0 * sin(rot)), ground(p[0] + 9.0 * cos(rot), p[1] - 9.0 * sin(rot)))
	b.position = Vector3(p[0], y + 0.15, p[1])
	b.rotation.y = rot
	parent.add_child(b)
	var kit := MeshKit.new()
	for i in 34:
		kit.add_box(Mats.get_mat("planks_ext"), Transform3D(Basis(Vector3.UP, randf_range(-0.03, 0.03)), Vector3(-8.25 + i * 0.5, 0, 0)), Vector3(0.45, 0.08, 4.0))
	for z in [-2.0, 2.0]:
		kit.add_box(Mats.get_mat("wood_dark"), Transform3D(Basis(), Vector3(0, 0.6, z)), Vector3(17.0, 0.1, 0.1))
		for i in 7:
			kit.add_box(Mats.get_mat("wood_dark"), Transform3D(Basis(), Vector3(-8.0 + i * 2.66, 0.3, z)), Vector3(0.12, 0.7, 0.12))
		_col(b, Vector3(17.0, 1.2, 0.15), Vector3(0, 0.6, z))
	for i in 4:
		kit.add_box(Mats.get_mat("bark"), Transform3D(Basis(), Vector3(-4.5 + i * 3.0, -1.4, 0)), Vector3(0.4, 2.8, 3.6))
	b.add_child(kit.build_instance("Bridge"))
	_col(b, Vector3(17.0, 0.12, 4.0), Vector3.ZERO)
	# пандусы на берега
	for s in [-1.0, 1.0]:
		_col(b, Vector3(4.0, 0.12, 4.0), Vector3(s * 10.2, -0.6, 0), Basis(Vector3.FORWARD, s * 0.3))


static func _perimeter(def: Dictionary, parent: Node3D) -> void:
	var x := float(def.x)
	var gap: Array = def.gap
	var root := StaticBody3D.new()
	root.name = "Perimeter"
	root.collision_layer = 1
	parent.add_child(root)
	var kit := MeshKit.new()
	var z := RegionData.oz + 2.0
	var z_end := RegionData.oz + (RegionData.h - 1) * RegionData.cell - 2.0
	var step := 3.0
	while z < z_end:
		var z1 := z + step
		var in_gap := z1 > float(gap[0]) and z < float(gap[1])
		var y0 := ground(x, z)
		var y1 := ground(x, z1)
		kit.add_box(Mats.get_mat("concrete"), Transform3D(Basis(), Vector3(x, y0 + 1.2, z)), Vector3(0.15, 2.8, 0.15))
		if not in_gap:
			for wy in [0.6, 1.2, 1.8, 2.4]:
				var a := Vector3(x, y0 + wy, z)
				var bb := Vector3(x, y1 + wy, z1)
				var mid := (a + bb) * 0.5
				kit.add_box(Mats.get_mat("wire"), Transform3D(Basis.looking_at(bb - a, Vector3.UP), mid), Vector3(0.015, 0.015, a.distance_to(bb)))
			_col(root, Vector3(0.3, 3.0, step), Vector3(x, (y0 + y1) * 0.5 + 1.5, (z + z1) * 0.5))
		elif randf() < 0.6:
			kit.add_box(Mats.get_mat("wire"), Transform3D(Basis(Vector3.RIGHT, 0.9), Vector3(x - 0.4, y0 + 0.2, z + 1.0)), Vector3(0.015, 0.015, 2.0))
		z = z1
	root.add_child(kit.build_instance("Fence", false))
	# невидимая стена границы мира чуть дальше
	_col(root, Vector3(1.0, 60.0, 1200.0), Vector3(x - 6.0, 10.0, 0.0))
	for zz in [-200.0, 0.0, 30.0, 52.0, 200.0, 400.0, -400.0]:
		var l := Label3D.new()
		l.text = "СТОЙ!\nЗАПРЕТНАЯ ЗОНА\nПРОХОД ЗАПРЕЩЁН\nОГОНЬ НА ПОРАЖЕНИЕ"
		l.font_size = 56
		l.pixel_size = 0.005
		l.modulate = Color(0.75, 0.15, 0.1)
		l.position = Vector3(x + 0.2, ground(x, zz) + 1.6, zz)
		l.rotation.y = deg_to_rad(90)
		l.shaded = true
		root.add_child(l)


static func _watchtower(def: Dictionary, parent: Node3D) -> void:
	var p: Array = def.pos
	var b := _node(parent, "Watchtower", p[0], p[1], float(def.get("rot", 0)))
	var kit := MeshKit.new()
	for x in [-1.2, 1.2]:
		for z in [-1.2, 1.2]:
			kit.add_box(Mats.get_mat("wood_dark"), Transform3D(Basis(), Vector3(x, 3.0, z)), Vector3(0.2, 6.0, 0.2))
			_col(b, Vector3(0.2, 6.0, 0.2), Vector3(x, 3.0, z))
	kit.add_box(Mats.get_mat("planks_ext"), Transform3D(Basis(), Vector3(0, 6.0, 0)), Vector3(3.0, 0.15, 3.0))
	kit.add_box(Mats.get_mat("planks_ext"), Transform3D(Basis(), Vector3(0, 6.6, 1.5)), Vector3(3.0, 1.0, 0.08))
	kit.add_box(Mats.get_mat("planks_ext"), Transform3D(Basis(), Vector3(0, 6.6, -1.5)), Vector3(3.0, 1.0, 0.08))
	kit.add_box(Mats.get_mat("roof_iron"), Transform3D(Basis(), Vector3(0, 8.0, 0)), Vector3(3.4, 0.06, 3.4))
	for x in [-1.4, 1.4]:
		kit.add_box(Mats.get_mat("wood_dark"), Transform3D(Basis(), Vector3(x, 7.4, 1.4)), Vector3(0.1, 1.2, 0.1))
	b.add_child(kit.build_instance("Tower"))


static func _roadblock(def: Dictionary, parent: Node3D) -> void:
	var p: Array = def.pos
	var b := _node(parent, "Roadblock", p[0], p[1], float(def.get("rot", 0)))
	var kit := MeshKit.new()
	for i in 6:
		kit.add_box(Mats.get_mat("concrete"), Transform3D(Basis(Vector3.UP, randf_range(-0.1, 0.1)), Vector3(-6.0 + i * 2.4, 0.5, 0)), Vector3(2.2, 1.0, 0.6))
	for i in 10:
		kit.add_box(Mats.get_mat("sandbag"), Transform3D(Basis(Vector3.UP, i * 0.2), Vector3(-6.0 + i * 1.3, 1.15, 0.2)), Vector3(0.6, 0.3, 0.4))
	b.add_child(kit.build_instance("Block"))
	_col(b, Vector3(16.0, 3.0, 1.2), Vector3(0, 1.5, 0))
	_col(b, Vector3(1.0, 40.0, 400.0), Vector3(0, 10.0, 0))
	var l := Label3D.new()
	l.text = "КПП «Р‑17»\nПРОХОД ЗАКРЫТ\n(дальше — Зареченск: следующее обновление)"
	l.font_size = 44
	l.pixel_size = 0.006
	l.modulate = Color(0.8, 0.75, 0.6)
	l.position = Vector3(0, 2.2, -0.45)
	l.rotation.y = PI
	l.shaded = true
	b.add_child(l)


static func _power_line(def: Dictionary, parent: Node3D) -> void:
	var pts: Array = def.points
	var step := float(def.get("step", 35.0))
	var a := Vector2(pts[0][0], pts[0][1])
	var bb := Vector2(pts[1][0], pts[1][1])
	var n := int(a.distance_to(bb) / step)
	var kit := MeshKit.new()
	var wires := MeshKit.new()
	var prev := Vector3.INF
	var root := StaticBody3D.new()
	root.collision_layer = 1
	root.name = "PowerLine"
	parent.add_child(root)
	for i in n + 1:
		var q := a.lerp(bb, float(i) / maxf(n, 1))
		var y := ground(q.x, q.y)
		var tilt := Basis(Vector3.RIGHT, randf_range(-0.06, 0.06))
		kit.add_cylinder(Mats.get_mat("wood_dark"), Vector3(q.x, y - 0.5, q.y), 9.0, 0.16, 0.12, 6)
		kit.add_box(Mats.get_mat("wood_dark"), Transform3D(tilt, Vector3(q.x, y + 7.8, q.y)), Vector3(1.6, 0.12, 0.12))
		_col(root, Vector3(0.3, 9.0, 0.3), Vector3(q.x, y + 4.0, q.y))
		var top := Vector3(q.x, y + 7.95, q.y)
		if prev != Vector3.INF:
			for off in [-0.7, 0.0, 0.7]:
				var o := Vector3(0, 0, 0)
				o.x = off
				var p0 := prev + o
				var p1 := top + o
				var mid := (p0 + p1) * 0.5 - Vector3(0, 0.6, 0)
				for seg in [[p0, mid], [mid, p1]]:
					var s0: Vector3 = seg[0]
					var s1: Vector3 = seg[1]
					if s0.distance_to(s1) > 0.1:
						wires.add_box(Mats.get_mat("wire"), Transform3D(Basis.looking_at(s1 - s0, Vector3.UP), (s0 + s1) * 0.5), Vector3(0.04, 0.04, s0.distance_to(s1)))
		prev = top
	root.add_child(kit.build_instance("Poles", false))
	if not wires.is_empty():
		var wm := wires.build_instance("Wires", false)
		wm.visibility_range_end = 55.0
		root.add_child(wm)


## Асфальтовая дорога — лента поверх рельефа.
static func road_ribbon(points: Array, width: float, parent: Node3D) -> void:
	var kit := MeshKit.new()
	var mat := Mats.get_mat("asphalt")
	var pts: Array = []
	for i in points.size() - 1:
		var a := Vector2(points[i][0], points[i][1])
		var b := Vector2(points[i + 1][0], points[i + 1][1])
		var n := int(a.distance_to(b) / 4.0) + 1
		for j in n:
			pts.append(a.lerp(b, float(j) / n))
	pts.append(Vector2(points[-1][0], points[-1][1]))
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var dir := (b - a).normalized()
		var side := Vector2(-dir.y, dir.x) * width * 0.5
		var a0 := Vector3(a.x - side.x, ground(a.x - side.x, a.y - side.y) + 0.06, a.y - side.y)
		var a1 := Vector3(a.x + side.x, ground(a.x + side.x, a.y + side.y) + 0.06, a.y + side.y)
		var b0 := Vector3(b.x - side.x, ground(b.x - side.x, b.y - side.y) + 0.06, b.y - side.y)
		var b1 := Vector3(b.x + side.x, ground(b.x + side.x, b.y + side.y) + 0.06, b.y + side.y)
		# сверху: по часовой
		kit.add_quad(mat, a0, b0, b1, a1, Vector3(dir.x, 0, dir.y), Vector3(-side.normalized().x, 0, -side.normalized().y))
	var mi := kit.build_instance("Road", false)
	parent.add_child(mi)


## Ручей — тёмная вода с бликами.
static func stream_ribbon(points: Array, width: float, parent: Node3D) -> void:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
uniform vec3 deep = vec3(0.04, 0.06, 0.06);
float h(vec2 p){ return sin(p.x * 1.7 + TIME * 1.3) * cos(p.y * 1.3 - TIME * 0.9) + sin((p.x + p.y) * 3.1 + TIME * 2.1) * 0.5; }
varying vec3 wp;
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	vec2 p = wp.xz;
	float e = 0.05;
	vec3 n = normalize(vec3(h(p) - h(p + vec2(e, 0.0)), 1.0 / 0.06 * e, h(p) - h(p + vec2(0.0, e))));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ALBEDO = deep;
	ROUGHNESS = 0.08;
	METALLIC = 0.2;
	SPECULAR = 0.7;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array = []
	for i in points.size() - 1:
		var a := Vector2(points[i][0], points[i][1])
		var b := Vector2(points[i + 1][0], points[i + 1][1])
		var n := int(a.distance_to(b) / 4.0) + 1
		for j in n:
			pts.append(a.lerp(b, float(j) / n))
	pts.append(Vector2(points[-1][0], points[-1][1]))
	var body := StaticBody3D.new()
	body.collision_layer = 4
	body.name = "StreamBody"
	var src := MiscInteract.WaterSource.new()
	src.title = "Ручей Ржавец"
	src.collision_layer = 4
	parent.add_child(src)
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var dir := (b - a).normalized()
		var side := Vector2(-dir.y, dir.x) * (width * 0.5 + 0.8)
		var ya := ground(a.x, a.y) + 0.55
		var yb := ground(b.x, b.y) + 0.55
		var a0 := Vector3(a.x - side.x, ya, a.y - side.y)
		var a1 := Vector3(a.x + side.x, ya, a.y + side.y)
		var b0 := Vector3(b.x - side.x, yb, b.y - side.y)
		var b1 := Vector3(b.x + side.x, yb, b.y + side.y)
		for v in [a0, b0, b1, a0, b1, a1]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
		if i % 2 == 0:
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(width + 1.0, 0.2, a.distance_to(b) * 2.0 + 0.5)
			cs.shape = bs
			cs.transform = Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.y)), Vector3((a.x + b.x) * 0.5, (ya + yb) * 0.5 - 0.1, (a.y + b.y) * 0.5))
			src.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.name = "Stream"
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
