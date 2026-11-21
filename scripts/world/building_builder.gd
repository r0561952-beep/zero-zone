class_name BuildingBuilder
extends RefCounted
## Конструктор зданий. Локальная система: центр здания в (0,0), фасад смотрит в +Z, пол на floor_y.
## Вся геометрия здания сливается в один меш (по поверхности на материал), коллизия — коробки.

var root: Node3D
var kit := MeshKit.new()
var body: StaticBody3D
var bid := ""
var floor_y := 0.3
var rng := RandomNumberGenerator.new()
var _xf := Transform3D.IDENTITY
var _occluders: Array = []


func _init(parent: Node3D, id: String, pos: Vector3, rot_deg: float) -> void:
	bid = id
	rng.seed = hash(id)
	root = Node3D.new()
	root.name = "B_" + id
	root.position = pos
	root.rotation.y = deg_to_rad(rot_deg)
	parent.add_child(root)
	body = StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.set_meta("surface", "wood")
	root.add_child(body)


func m(name: String) -> Material:
	return Mats.get_mat(name)


## Коробка в локальных координатах здания (+ коллизия).
func box(mat: String, mn: Vector3, mx: Vector3, collide: bool = true) -> void:
	kit.add_box_mm(m(mat), _xf, mn, mx)
	if collide:
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = (mx - mn).abs()
		cs.shape = b
		cs.position = (mn + mx) * 0.5
		body.add_child(cs)


func rbox(mat: String, xf: Transform3D, size: Vector3, collide: bool = false) -> void:
	kit.add_box(m(mat), xf, size)
	if collide:
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = size
		cs.shape = b
		cs.transform = xf
		body.add_child(cs)


## Стена от a до b (по центральной линии, XZ). Снаружи — справа по ходу (dir × UP).
## openings: [{"at": смещение центра проёма от середины стены, "w", "bottom", "top", "kind": door|window|hole, "frame"}]
## ext/int — материалы наружной и внутренней стороны. h — высота над полом.
func wall(a: Vector2, b: Vector2, h: float, openings: Array, ext: String, inner: String, t: float = 0.2, y0: float = -999.0) -> void:
	if y0 < -998.0:
		y0 = floor_y
	var dir2 := (b - a)
	var length := dir2.length()
	var u := dir2 / length
	var dir := Vector3(u.x, 0, u.y)
	var nrm := dir.cross(Vector3.UP)
	var mid := Vector3((a.x + b.x) * 0.5, 0, (a.y + b.y) * 0.5)
	var basis := Basis(dir, Vector3.UP, nrm)
	var ops := openings.duplicate()
	ops.sort_custom(func(p, q): return float(p.at) < float(q.at))
	var cursor := -length * 0.5
	var pieces: Array = []   # [s0, s1, y0, y1]
	for o in ops:
		var c := float(o.at)
		var hw := float(o.w) * 0.5
		var s0 := c - hw
		var s1 := c + hw
		if s0 > cursor:
			pieces.append([cursor, s0, 0.0, h])
		var ob := float(o.get("bottom", 0.0))
		var ot := float(o.get("top", 2.05))
		if ob > 0.0:
			pieces.append([s0, s1, 0.0, ob])
		if ot < h:
			pieces.append([s0, s1, ot, h])
		cursor = s1
		var center := mid + dir * c
		match str(o.get("kind", "window")):
			"window":
				_window(center, basis, float(o.w), ob, ot, t, y0, str(o.get("frame", "frame_white")), o.get("broken", rng.randf() < 0.35), o.get("shutters", ""))
			"door":
				_door_frame(center, basis, float(o.w), ot, t, y0)
	if cursor < length * 0.5:
		pieces.append([cursor, length * 0.5, 0.0, h])
	for p in pieces:
		var s0: float = p[0]
		var s1: float = p[1]
		var py0: float = p[2]
		var py1: float = p[3]
		if s1 - s0 < 0.01 or py1 - py0 < 0.01:
			continue
		var c3 := mid + dir * ((s0 + s1) * 0.5) + Vector3.UP * (y0 + (py0 + py1) * 0.5)
		var size := Vector3(s1 - s0, py1 - py0, t)
		if ext == inner:
			kit.add_box(m(ext), _xf * Transform3D(basis, c3), size)
		else:
			kit.add_box(m(ext), _xf * Transform3D(basis, c3 + nrm * t * 0.25), Vector3(size.x, size.y, t * 0.5))
			kit.add_box(m(inner), _xf * Transform3D(basis, c3 - nrm * t * 0.25), Vector3(size.x, size.y, t * 0.5))
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.transform = Transform3D(basis, c3)
		body.add_child(cs)
		if s1 - s0 > 1.4 and py1 - py0 > 1.8 and ext != inner:
			_occluders.append([Transform3D(basis, c3), Vector2(s1 - s0, py1 - py0)])


func _window(center: Vector3, basis: Basis, w: float, bottom: float, top: float, t: float, y0: float, frame: String, broken: bool, shutters: String) -> void:
	var hgt := top - bottom
	var c := center + Vector3.UP * (y0 + (bottom + top) * 0.5)
	var fx := 0.06
	rbox(frame, Transform3D(basis, c + basis.x * (w * 0.5 - fx * 0.5)), Vector3(fx, hgt, t + 0.02))
	rbox(frame, Transform3D(basis, c - basis.x * (w * 0.5 - fx * 0.5)), Vector3(fx, hgt, t + 0.02))
	rbox(frame, Transform3D(basis, c + Vector3.UP * (hgt * 0.5 - fx * 0.5)), Vector3(w, fx, t + 0.02))
	rbox(frame, Transform3D(basis, c - Vector3.UP * (hgt * 0.5 - fx * 0.5)), Vector3(w, fx, t + 0.02))
	rbox(frame, Transform3D(basis, c), Vector3(0.04, hgt, 0.05))
	rbox(frame, Transform3D(basis, c + Vector3.UP * hgt * 0.15), Vector3(w, 0.04, 0.05))
	# подоконник снаружи
	rbox(frame, Transform3D(basis, c - Vector3.UP * (hgt * 0.5 + 0.03) + basis.z * (t * 0.5 + 0.05)), Vector3(w + 0.1, 0.04, 0.14))
	if not broken:
		kit.add_box(m("glass"), _xf * Transform3D(basis, c), Vector3(w - 0.1, hgt - 0.1, 0.01))
	# стекло — преграда для движения в любом случае (окна не для прохода)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w, hgt, t)
	cs.shape = bs
	cs.transform = Transform3D(basis, c)
	body.add_child(cs)
	if shutters != "":
		for side in [-1.0, 1.0]:
			rbox(shutters, Transform3D(basis, c + basis.x * side * (w * 0.5 + 0.28) + basis.z * (t * 0.5 + 0.03)), Vector3(0.5, hgt + 0.06, 0.04))
		rbox(shutters, Transform3D(basis, c + Vector3.UP * (hgt * 0.5 + 0.12) + basis.z * (t * 0.5 + 0.03)), Vector3(w + 0.3, 0.18, 0.05))


func _door_frame(center: Vector3, basis: Basis, w: float, top: float, t: float, y0: float) -> void:
	var c := center + Vector3.UP * (y0 + top * 0.5)
	rbox("frame_dark", Transform3D(basis, c + basis.x * (w * 0.5 + 0.03)), Vector3(0.07, top, t + 0.04))
	rbox("frame_dark", Transform3D(basis, c - basis.x * (w * 0.5 + 0.03)), Vector3(0.07, top, t + 0.04))
	rbox("frame_dark", Transform3D(basis, center + Vector3.UP * (y0 + top + 0.04)), Vector3(w + 0.14, 0.08, t + 0.04))


## Дверь в проёме стены. hinge — точка петли (локально), facing — угол поворота полотна (рад).
func door(id: String, a: Vector2, b: Vector2, at: float, w: float, title: String, locked: bool = false, key: String = "", mat: String = "door", h: float = 2.0, forceable: bool = true, y0: float = -999.0) -> Door:
	if y0 < -998.0:
		y0 = floor_y
	var dir2 := (b - a).normalized()
	var mid := (a + b) * 0.5 + dir2 * at
	var hinge := mid - dir2 * (w * 0.5)
	var d := Door.new()
	d.door_id = bid + "/" + id
	d.width = w
	d.height = h
	d.locked = locked
	d.key_id = key
	d.forceable = forceable
	d.title = title
	d.material_name = mat
	d.position = Vector3(hinge.x, y0, hinge.y)
	d.rotation.y = atan2(-dir2.y, dir2.x)
	if rng.randf() < 0.3 and not locked:
		d.open = true
	root.add_child(d)
	return d


func floor_rect(x0: float, z0: float, x1: float, z1: float, mat: String, y: float = -999.0, thick: float = 0.1) -> void:
	if y < -998.0:
		y = floor_y
	box(mat, Vector3(x0, y - thick, z0), Vector3(x1, y, z1))


func ceiling_rect(x0: float, z0: float, x1: float, z1: float, y: float, mat: String = "ceiling") -> void:
	kit.add_box_mm(m(mat), _xf, Vector3(x0, y, z0), Vector3(x1, y + 0.08, z1))


## Фундамент до земли (скрывает перепады рельефа).
func foundation(w: float, d: float, mat: String = "concrete", depth: float = 1.5) -> void:
	box(mat, Vector3(-w * 0.5 - 0.05, -depth, -d * 0.5 - 0.05), Vector3(w * 0.5 + 0.05, floor_y - 0.1, d * 0.5 + 0.05))


## Двускатная крыша: конёк вдоль X.
func gable_roof(w: float, d: float, wall_h: float, ridge: float, overhang: float, roof_mat: String, gable_mat: String) -> void:
	var y0 := floor_y + wall_h
	var hd := d * 0.5 + overhang
	var slope_len := sqrt(hd * hd + ridge * ridge)
	var ang := atan2(ridge, hd)
	var lx := w + overhang * 2.0
	for side in [-1.0, 1.0]:
		var bas := Basis(Vector3.RIGHT, ang * side)
		var c := Vector3(0, y0 + ridge * 0.5 + 0.06, side * hd * 0.5)
		kit.add_box(m(roof_mat), _xf * Transform3D(bas, c), Vector3(lx, 0.08, slope_len + 0.05))
	# фронтоны (с обеих сторон, наружная и внутренняя стороны)
	var gy := y0
	for sx in [-1.0, 1.0]:
		var x = sx * w * 0.5
		var p0 := Vector3(x, gy, -d * 0.5)
		var p1 := Vector3(x, gy, d * 0.5)
		var p2 := Vector3(x, gy + ridge * (d * 0.5) / hd, 0)
		if sx > 0:
			kit.add_tri(m(gable_mat), p0, p1, p2, Vector3.FORWARD, Vector3.UP)
			kit.add_tri(m(gable_mat), p0 - Vector3(0.12, 0, 0), p2 - Vector3(0.12, 0, 0), p1 - Vector3(0.12, 0, 0), Vector3.FORWARD, Vector3.UP)
		else:
			kit.add_tri(m(gable_mat), p0, p2, p1, Vector3.BACK, Vector3.UP)
			kit.add_tri(m(gable_mat), p0 + Vector3(0.12, 0, 0), p1 + Vector3(0.12, 0, 0), p2 + Vector3(0.12, 0, 0), Vector3.BACK, Vector3.UP)
	# чердак — сплошной окклюдер
	var occ := OccluderInstance3D.new()
	var bo := BoxOccluder3D.new()
	bo.size = Vector3(w * 0.9, ridge * 0.45, d * 0.6)
	occ.occluder = bo
	occ.position = Vector3(0, y0 + ridge * 0.3, 0)
	root.add_child(occ)


func flat_roof(w: float, d: float, wall_h: float, overhang: float, mat: String, parapet: String = "") -> void:
	var y := floor_y + wall_h
	kit.add_box_mm(m(mat), _xf, Vector3(-w * 0.5 - overhang, y, -d * 0.5 - overhang), Vector3(w * 0.5 + overhang, y + 0.15, d * 0.5 + overhang))
	if parapet != "":
		for s in [-1.0, 1.0]:
			kit.add_box_mm(m(parapet), _xf, Vector3(-w * 0.5 - 0.1, y, s * d * 0.5 - 0.1), Vector3(w * 0.5 + 0.1, y + 0.5, s * d * 0.5 + 0.1))
			kit.add_box_mm(m(parapet), _xf, Vector3(s * w * 0.5 - 0.1, y, -d * 0.5), Vector3(s * w * 0.5 + 0.1, y + 0.5, d * 0.5))


## Крыльцо со ступенями перед дверью (коллизия — пандус).
func porch(x: float, z_front: float, w: float, mat: String = "planks_ext") -> void:
	var depth := 1.1
	box(mat, Vector3(x - w * 0.5, floor_y - 0.12, z_front), Vector3(x + w * 0.5, floor_y, z_front + depth))
	var steps := 2
	for i in steps:
		var y_top := floor_y * float(steps - i) / float(steps + 1)
		kit.add_box_mm(m(mat), _xf, Vector3(x - w * 0.4, -0.3, z_front + depth + i * 0.3), Vector3(x + w * 0.4, y_top, z_front + depth + (i + 1) * 0.3))
	var ramp_len := 0.3 * steps + 0.2
	var ang := atan2(floor_y + 0.05, ramp_len)
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(w * 0.8, 0.1, sqrt(ramp_len * ramp_len + floor_y * floor_y) + 0.1)
	cs.shape = b
	cs.transform = Transform3D(Basis(Vector3.RIGHT, ang), Vector3(x, floor_y * 0.5 - 0.05, z_front + depth + ramp_len * 0.5))
	body.add_child(cs)


## Мебель (модель Poly Haven) в локальных координатах; y — от пола.
func prop(model_id: String, x: float, z: float, rot_deg: float = 0.0, collide: String = "box", scale_to: float = 0.0, y: float = 0.0) -> Node3D:
	if not Models.exists(model_id):
		return null
	return Models.place(model_id, root, Transform3D(Basis(Vector3.UP, deg_to_rad(rot_deg)), Vector3(x, floor_y + y, z)), collide, scale_to)


## Контейнер с добычей, совмещённый с мебелью (модель) или своим визуалом.
func container(sub_id: String, table: String, title: String, x: float, z: float, rot_deg: float = 0.0, model_id: String = "", size: Vector3 = Vector3(0.8, 0.9, 0.5), slots: int = 10, fixed: Array = [], visual: String = "", y: float = 0.0) -> LootContainer:
	var c := LootContainer.new()
	c.container_id = bid + "/" + sub_id
	c.loot_table = table
	c.title = title
	c.slots_count = slots
	c.box_size = size
	c.fixed_items = fixed
	c.visual = visual
	c.position = Vector3(x, floor_y + y, z)
	c.rotation.y = deg_to_rad(rot_deg)
	root.add_child(c)
	if model_id != "":
		if Models.exists(model_id):
			Models.place(model_id, c, Transform3D.IDENTITY, "", 0.0)
		else:
			c.visual = "box"
			c._build_visual()
	return c


## Сюжетный/постоянный предмет в мире (исчезает после подбора навсегда).
func item(item_id: String, sub_id: String, x: float, z: float, y: float = 0.0, n: int = 1) -> WorldItem:
	var pid := bid + "/" + sub_id
	if GameState.world.has("p:" + pid):
		return null
	var wi := WorldItem.new()
	wi.item_id = item_id
	wi.count = n
	wi.pickup_id = pid
	wi.position = Vector3(x, floor_y + y, z)
	root.add_child(wi)
	return wi


func indoor(x0: float, z0: float, x1: float, z1: float, h: float, basement: bool = false, y_base: float = -999.0) -> void:
	if y_base < -998.0:
		y_base = floor_y
	var a := MiscInteract.IndoorArea.new()
	a.basement = basement
	root.add_child(a)
	a.setup(Vector3(x1 - x0 - 0.2, h, z1 - z0 - 0.2), Vector3((x0 + x1) * 0.5, y_base + h * 0.5, (z0 + z1) * 0.5))
	# Тёмный «интерьерный» ambient — помещения без окон‑источников не светятся как улица
	var probe := ReflectionProbe.new()
	probe.size = Vector3(x1 - x0, h, z1 - z0)
	probe.position = Vector3((x0 + x1) * 0.5, y_base + h * 0.5, (z0 + z1) * 0.5)
	probe.interior = true
	probe.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	probe.ambient_color = Color(0.09, 0.085, 0.08) if not basement else Color(0.03, 0.03, 0.035)
	probe.ambient_color_energy = 1.0
	probe.intensity = 0.25
	probe.cull_mask = 0
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.blend_distance = 0.6
	root.add_child(probe)


func trigger(flag: String, x0: float, z0: float, x1: float, z1: float, message: String = "") -> void:
	var t := MiscInteract.Trigger.new()
	t.flag = flag
	t.message = message
	t.position = Vector3((x0 + x1) * 0.5, floor_y, (z0 + z1) * 0.5)
	root.add_child(t)
	t.setup(Vector3(absf(x1 - x0), 2.5, absf(z1 - z0)))


## Меловой знак на стене (локально).
func chalk(text: String, pos: Vector3, rot_deg: float, size: int = 96) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = Color(0.92, 0.92, 0.88, 0.85)
	l.outline_size = 0
	l.position = pos + Vector3(0, floor_y, 0)
	l.rotation.y = deg_to_rad(rot_deg)
	l.shaded = true
	l.double_sided = false
	root.add_child(l)


func finish() -> void:
	var mi := kit.build_instance("Geometry", true)
	root.add_child(mi)
	root.move_child(mi, 0)
	for o in _occluders:
		var occ := OccluderInstance3D.new()
		var q := QuadOccluder3D.new()
		q.size = o[1] * 0.92
		occ.occluder = q
		occ.transform = o[0]
		root.add_child(occ)
