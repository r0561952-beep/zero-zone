class_name MeshKit
extends RefCounted
## Сборщик геометрии: множество коробок/граней сливаются в один ArrayMesh
## (по одной поверхности на материал) → единицы draw calls на целое здание.
## UV считаются в мировых метрах (материал хранит meta "tile" — сколько метров на повтор текстуры),
## поэтому текстура непрерывна на соседних кусках стены.

var _st: Dictionary = {}     # Material -> SurfaceTool
var _count: Dictionary = {}  # Material -> число вершин


func _tool(mat: Material) -> SurfaceTool:
	if not _st.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(mat)
		_st[mat] = st
		_count[mat] = 0
	return _st[mat]


static func tile_of(mat: Material) -> float:
	return float(mat.get_meta("tile", 2.0)) if mat else 2.0


## Прямоугольная грань. Вершины по часовой стрелке, если смотреть спереди (так у Godot — лицевая сторона).
## right/up — оси грани в мире; UV проецируются на них (непрерывная текстура).
func add_face(mat: Material, center: Vector3, right: Vector3, up: Vector3, half_w: float, half_h: float) -> void:
	var st := _tool(mat)
	var tile := tile_of(mat)
	var n := right.cross(up).normalized()
	var a := center - right * half_w + up * half_h
	var b := center + right * half_w + up * half_h
	var c := center + right * half_w - up * half_h
	var d := center - right * half_w - up * half_h
	var ru := right.normalized()
	var uu := up.normalized()
	var pts := [a, b, c, a, c, d]
	for p in pts:
		st.set_normal(n)
		st.set_uv(Vector2(p.dot(ru), -p.dot(uu)) / tile)
		st.add_vertex(p)
	_count[mat] += 6


## Коробка с трансформом (масштаб задаётся size, basis должен быть ортонормированным).
func add_box(mat: Material, xf: Transform3D, size: Vector3, skip_bottom: bool = false, skip_top: bool = false) -> void:
	var e := size * 0.5
	var bx := xf.basis.x.normalized()
	var by := xf.basis.y.normalized()
	var bz := xf.basis.z.normalized()
	var o := xf.origin
	add_face(mat, o + bz * e.z, bx, by, e.x, e.y)           # +Z
	add_face(mat, o - bz * e.z, -bx, by, e.x, e.y)          # -Z
	add_face(mat, o + bx * e.x, -bz, by, e.z, e.y)          # +X
	add_face(mat, o - bx * e.x, bz, by, e.z, e.y)           # -X
	if not skip_top:
		add_face(mat, o + by * e.y, bx, -bz, e.x, e.z)      # +Y
	if not skip_bottom:
		add_face(mat, o - by * e.y, bx, bz, e.x, e.z)       # -Y


## Коробка, заданная мин/макс в локальных координатах родительского трансформа.
func add_box_mm(mat: Material, parent: Transform3D, mn: Vector3, mx: Vector3) -> void:
	var c := (mn + mx) * 0.5
	add_box(mat, parent * Transform3D(Basis(), c), (mx - mn).abs())


## Треугольник (по часовой при взгляде спереди), UV — планарная проекция на заданные оси.
func add_tri(mat: Material, a: Vector3, b: Vector3, c: Vector3, ru: Vector3, uu: Vector3) -> void:
	var st := _tool(mat)
	var tile := tile_of(mat)
	var n := (c - a).cross(b - a).normalized()
	for p in [a, b, c]:
		st.set_normal(n)
		st.set_uv(Vector2(p.dot(ru), -p.dot(uu)) / tile)
		st.add_vertex(p)
	_count[mat] += 3


## Произвольный четырёхугольник (по часовой спереди).
func add_quad(mat: Material, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ru: Vector3, uu: Vector3) -> void:
	add_tri(mat, a, b, c, ru, uu)
	add_tri(mat, a, c, d, ru, uu)


## Цилиндр (для столбов, стволов, труб).
func add_cylinder(mat: Material, base: Vector3, height: float, r_bottom: float, r_top: float, sides: int = 8) -> void:
	var st := _tool(mat)
	var tile := tile_of(mat)
	var circ := TAU * maxf(r_bottom, 0.05)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var p0 := base + d0 * r_bottom
		var p1 := base + d1 * r_bottom
		var p2 := base + d1 * r_top + Vector3.UP * height
		var p3 := base + d0 * r_top + Vector3.UP * height
		var u0 := float(i) / sides * circ / tile
		var u1 := float(i + 1) / sides * circ / tile
		var v1 := height / tile
		var verts := [[p0, d0, Vector2(u0, v1)], [p2, d1, Vector2(u1, 0)], [p3, d0, Vector2(u0, 0)],
			[p0, d0, Vector2(u0, v1)], [p1, d1, Vector2(u1, v1)], [p2, d1, Vector2(u1, 0)]]
		for v in verts:
			st.set_normal(v[1])
			st.set_uv(v[2])
			st.add_vertex(v[0])
		_count[mat] += 6


func is_empty() -> bool:
	return _st.is_empty()


## Собрать итоговый меш. Касательные считаются для карт нормалей.
func commit() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for mat in _st:
		if _count[mat] == 0:
			continue
		var st: SurfaceTool = _st[mat]
		st.generate_tangents()
		st.commit(mesh)
	return mesh


## Удобство: создать MeshInstance3D с собранным мешем.
func build_instance(name: String = "Mesh", shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
