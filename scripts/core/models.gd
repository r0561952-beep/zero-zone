class_name Models
extends RefCounted
## Загрузка сторонних моделей (Poly Haven glTF, Kenney GLB) с кэшем, расчёт габаритов,
## создание статичных объектов с упрощённой коллизией.

const PH := "res://assets/thirdparty/polyhaven/models/%s/%s_1k.gltf"
const KENNEY := "res://assets/thirdparty/kenney/%s/%s.glb"

static var _scenes: Dictionary = {}
static var _aabbs: Dictionary = {}


## id: "WoodenTable_02" (Poly Haven) или "k:car-kit/sedan" (Kenney)
static func path_of(id: String) -> String:
	if id.begins_with("k:"):
		var p := id.substr(2).split("/")
		return KENNEY % [p[0], p[1]]
	return PH % [id, id]


static func exists(id: String) -> bool:
	return ResourceLoader.exists(path_of(id))


static func scene(id: String) -> PackedScene:
	if _scenes.has(id):
		return _scenes[id]
	var p := path_of(id)
	var s: PackedScene = load(p) if ResourceLoader.exists(p) else null
	if s == null:
		push_warning("Models: нет модели %s" % id)
	_scenes[id] = s
	return s


static func instance(id: String) -> Node3D:
	var s := scene(id)
	if s == null:
		return null
	var n := s.instantiate() as Node3D
	return n


## Габариты модели в её локальных координатах (кэшируются).
static func aabb(id: String) -> AABB:
	if _aabbs.has(id):
		return _aabbs[id]
	var n := instance(id)
	var box := AABB()
	if n:
		box = node_aabb(n, Transform3D.IDENTITY)
		n.free()
	_aabbs[id] = box
	return box


static func node_aabb(n: Node, xf: Transform3D) -> AABB:
	var box := AABB()
	var first := true
	var stack: Array = [[n, xf]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var node: Node = item[0]
		var t: Transform3D = item[1]
		if node is Node3D and node != n:
			t = t * (node as Node3D).transform
		if node is MeshInstance3D and (node as MeshInstance3D).mesh:
			var b: AABB = t * (node as MeshInstance3D).mesh.get_aabb()
			if first:
				box = b
				first = false
			else:
				box = box.merge(b)
		for c in node.get_children():
			stack.append([c, t])
	return box


## Поставить модель в мир. scale_to — подогнать по большей стороне (м), 0 — без масштаба.
## collide: "" (нет), "box" — коробка по габаритам.
static func place(id: String, parent: Node3D, xf: Transform3D, collide: String = "box", scale_to: float = 0.0, layer: int = 1) -> Node3D:
	var n := instance(id)
	if n == null:
		return null
	var box := aabb(id)
	var s := 1.0
	if scale_to > 0.0 and box.size.length() > 0.001:
		s = scale_to / maxf(box.size.x, maxf(box.size.y, box.size.z))
	var root := Node3D.new()
	root.name = id.get_file()
	root.transform = xf
	parent.add_child(root)
	n.scale = Vector3.ONE * s
	root.add_child(n)
	set_shadows(n, box.size.length() * s > 0.6)
	if collide == "box" and box.size.length() > 0.01:
		var body := StaticBody3D.new()
		body.collision_layer = layer
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = (box.size * s).max(Vector3(0.05, 0.05, 0.05))
		cs.shape = shape
		cs.position = box.get_center() * s
		body.add_child(cs)
		root.add_child(body)
	return root


static func set_shadows(n: Node, on: bool) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		set_shadows(c, on)


## Перекрасить все материалы модели (для Kenney — чтобы убрать «мультяшность»).
static func override_material(n: Node, mat: Material) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh:
			for i in mi.mesh.get_surface_count():
				mi.set_surface_override_material(i, mat)
	for c in n.get_children():
		override_material(c, mat)


## Затемнить/состарить материалы модели (multiply albedo).
static func tint(n: Node, color: Color) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh:
			for i in mi.mesh.get_surface_count():
				var m := mi.get_active_material(i)
				if m is BaseMaterial3D:
					var d := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
					d.albedo_color = d.albedo_color * color
					d.roughness = clampf(d.roughness + 0.2, 0.0, 1.0)
					mi.set_surface_override_material(i, d)
	for c in n.get_children():
		tint(c, color)
