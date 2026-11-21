class_name TreeFactory
extends RefCounted
## Процедурные деревья средней полосы: ель/сосна, берёза (осенняя листва), сухостой.
## Для каждого вида — два уровня детализации (ближний/дальний).


static var _cache: Dictionary = {}


## Общий кэш мешей (рельеф, дворы).
static func mesh(kind: String, lod: int = 0) -> ArrayMesh:
	if _cache.is_empty():
		_cache = _build()
	return _cache[kind][lod]


static func build_all() -> Dictionary:
	if _cache.is_empty():
		_cache = _build()
	return _cache


static func _build() -> Dictionary:
	return {
		"pine": [_pine(false), _pine(true)],
		"birch": [_birch(false), _birch(true)],
		"dead": [_dead(false), _dead(true)],
		"bush": [_bush(false), _bush(true)],
		"apple": [_apple(false), _apple(true)],
	}


## Рекурсивные голые ветви (ноябрь: лиственные деревья без листвы).
static func _limbs(kit: MeshKit, mat: Material, from: Vector3, dir: Vector3, length: float, r0: float, depth: int, rng: RandomNumberGenerator) -> void:
	var to := from + dir.normalized() * length
	_branch(kit, mat, from, dir, length, r0, r0 * 0.45)
	if depth <= 0:
		return
	var n := 2 if depth > 1 else 3
	for i in n:
		var t := rng.randf_range(0.45, 0.95)
		var p := from.lerp(to, t)
		var side := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.2, 0.9), rng.randf_range(-1, 1))
		var nd := (dir.normalized() * 0.6 + side.normalized() * 0.7).normalized()
		_limbs(kit, mat, p, nd, length * rng.randf_range(0.45, 0.65), r0 * 0.5, depth - 1, rng)


static func _bush(far: bool) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var kit := MeshKit.new()
	var twig := Mats.get_mat("wood_dark")
	var leaves := Mats.get_mat("birch_foliage2")
	var n := 5 if far else 11
	for i in n:
		var a := TAU * i / n + rng.randf() * 0.4
		var d := Vector3(cos(a) * rng.randf_range(0.3, 0.7), 1.0, sin(a) * rng.randf_range(0.3, 0.7))
		if far:
			_branch(kit, twig, Vector3.ZERO, d, rng.randf_range(0.9, 1.5), 0.03, 0.01)
		else:
			_limbs(kit, twig, Vector3(0, -0.05, 0), d, rng.randf_range(0.8, 1.5), 0.025, 1, rng)
	if not far:
		for i in 4:
			_blob(kit, leaves, Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(0.5, 1.1), rng.randf_range(-0.4, 0.4)), Vector3(0.35, 0.25, 0.35), rng, 3, 5)
	else:
		_blob(kit, leaves, Vector3(0, 0.7, 0), Vector3(0.6, 0.5, 0.6), rng, 2, 4)
	return kit.commit()


static func _apple(far: bool) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 57
	var kit := MeshKit.new()
	var bark := Mats.get_mat("wood_dark")
	_branch(kit, bark, Vector3(0, -0.2, 0), Vector3(0.1, 1, 0.05), 1.8, 0.14, 0.1)
	var n := 3 if far else 6
	for i in n:
		var a := TAU * i / n + rng.randf() * 0.5
		var d := Vector3(cos(a), rng.randf_range(0.5, 1.1), sin(a))
		if far:
			_branch(kit, bark, Vector3(0.15, 1.5, 0.08), d, 1.8, 0.07, 0.02)
		else:
			_limbs(kit, bark, Vector3(0.15, 1.5, 0.08), d, rng.randf_range(1.4, 2.2), 0.07, 2, rng)
	if not far:
		_blob(kit, Mats.get_mat("birch_foliage2"), Vector3(0.4, 3.0, 0.2), Vector3(0.5, 0.3, 0.5), rng, 3, 5)
	return kit.commit()


static func _cone(kit: MeshKit, mat: Material, y: float, h: float, r: float, sides: int, jag: float, droop: float, rng: RandomNumberGenerator) -> void:
	var apex := Vector3(0, y + h, 0)
	var rim: Array = []
	for i in sides:
		var a := TAU * i / sides + rng.randf() * 0.2
		var rr := r * (1.0 - jag * (i % 2))
		rim.append(Vector3(cos(a) * rr, y - (droop if i % 2 == 0 else 0.0), sin(a) * rr))
	var center := Vector3(0, y + h * 0.18, 0)
	for i in sides:
		var p0: Vector3 = rim[i]
		var p1: Vector3 = rim[(i + 1) % sides]
		kit.add_tri(mat, apex, p0, p1, Vector3.RIGHT, Vector3.UP)
		kit.add_tri(mat, center, p1, p0, Vector3.RIGHT, Vector3.FORWARD)


static func _trunk(kit: MeshKit, mat: Material, h: float, r0: float, r1: float, sides: int) -> void:
	kit.add_cylinder(mat, Vector3(0, -0.3, 0), h + 0.3, r0, r1, sides)


static func _pine(far: bool) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var kit := MeshKit.new()
	var bark := Mats.get_mat("bark")
	var fol := Mats.get_mat("pine_foliage")
	var fol2 := Mats.get_mat("pine_foliage2")
	if far:
		_trunk(kit, bark, 6.0, 0.3, 0.12, 4)
		_cone(kit, fol, 2.4, 6.5, 2.8, 6, 0.0, 0.0, rng)
		_cone(kit, fol2, 6.5, 6.5, 1.7, 5, 0.0, 0.0, rng)
		return kit.commit()
	_trunk(kit, bark, 12.5, 0.32, 0.05, 7)
	var layers := 7
	for i in layers:
		var t := float(i) / (layers - 1)
		var y := 2.2 + i * 1.55
		var r := lerpf(2.9, 0.55, t)
		_cone(kit, fol if i % 2 == 0 else fol2, y, 2.6, r, 10, 0.28, 0.35, rng)
	return kit.commit()


static func _blob(kit: MeshKit, mat: Material, c: Vector3, rad: Vector3, rng: RandomNumberGenerator, lat: int = 4, lon: int = 7) -> void:
	var pts: Array = []
	for j in lat + 1:
		var row: Array = []
		var phi := PI * j / lat
		for i in lon:
			var th := TAU * i / lon
			var jitter := 1.0 + rng.randf_range(-0.18, 0.18) if j > 0 and j < lat else 1.0
			row.append(c + Vector3(sin(phi) * cos(th) * rad.x, cos(phi) * rad.y, sin(phi) * sin(th) * rad.z) * jitter)
		pts.append(row)
	for j in lat:
		for i in lon:
			var a: Vector3 = pts[j][i]
			var b: Vector3 = pts[j][(i + 1) % lon]
			var cc: Vector3 = pts[j + 1][(i + 1) % lon]
			var d: Vector3 = pts[j + 1][i]
			# наружу: по часовой при взгляде снаружи
			if j > 0:
				kit.add_tri(mat, a, d, b, Vector3.RIGHT, Vector3.UP)
			if j < lat - 1:
				kit.add_tri(mat, b, d, cc, Vector3.RIGHT, Vector3.UP)


static func _branch(kit: MeshKit, mat: Material, from: Vector3, dir: Vector3, length: float, r0: float, r1: float) -> void:
	var up := dir.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var fwd := side.cross(up).normalized()
	var sides := 5
	var to := from + up * length
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := side * cos(a0) + fwd * sin(a0)
		var d1 := side * cos(a1) + fwd * sin(a1)
		var p0 := from + d0 * r0
		var p1 := from + d1 * r0
		var p2 := to + d1 * r1
		var p3 := to + d0 * r1
		kit.add_tri(mat, p0, p2, p3, d0, up)
		kit.add_tri(mat, p0, p1, p2, d0, up)


static func _birch(far: bool) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var kit := MeshKit.new()
	var bark := Mats.get_mat("birch_bark")
	var twig := Mats.get_mat("wood_dark")
	var fol := Mats.get_mat("birch_foliage")
	if far:
		_trunk(kit, bark, 10.0, 0.2, 0.05, 4)
		for i in 5:
			var a := TAU * i / 5.0
			_branch(kit, twig, Vector3(0, 4.5 + i * 0.9, 0), Vector3(cos(a), 1.3, sin(a)), 2.6, 0.06, 0.015)
		return kit.commit()
	_trunk(kit, bark, 10.5, 0.2, 0.04, 7)
	for i in 9:
		var a := TAU * i / 9.0 * 2.3 + rng.randf() * 0.6
		var y := 3.8 + i * 0.68
		var d := Vector3(cos(a), rng.randf_range(0.9, 1.6), sin(a))
		_limbs(kit, twig if i > 2 else bark, Vector3(0, y, 0), d, rng.randf_range(1.6, 2.8) * (1.0 - i * 0.05), 0.06, 2, rng)
	# последние жёлтые листья
	for i in 3:
		_blob(kit, fol, Vector3(rng.randf_range(-1.2, 1.2), rng.randf_range(6.0, 9.0), rng.randf_range(-1.2, 1.2)), Vector3(0.45, 0.3, 0.45), rng, 2, 5)
	return kit.commit()


static func _dead(far: bool) -> ArrayMesh:
	var kit := MeshKit.new()
	var bark := Mats.get_mat("bark")
	if far:
		_trunk(kit, bark, 8.0, 0.25, 0.08, 4)
		return kit.commit()
	_trunk(kit, bark, 9.0, 0.27, 0.04, 6)
	_branch(kit, bark, Vector3(0, 3.5, 0), Vector3(0.9, 0.6, 0.1), 2.6, 0.09, 0.02)
	_branch(kit, bark, Vector3(0, 4.6, 0), Vector3(-0.7, 0.8, 0.5), 2.2, 0.08, 0.02)
	_branch(kit, bark, Vector3(0, 5.8, 0), Vector3(0.2, 0.7, -0.9), 2.0, 0.07, 0.02)
	_branch(kit, bark, Vector3(0, 6.8, 0), Vector3(-0.4, 1.0, -0.2), 1.5, 0.05, 0.02)
	return kit.commit()
