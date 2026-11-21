class_name Interactable
extends StaticBody3D
## Базовый класс интерактивного объекта. Луч игрока ищет узел с get_prompt()/interact().
## Слои: 1 — мешает движению (мебель, двери), 4 — только для луча (мелкие предметы).

func setup_box(size: Vector3, center: Vector3 = Vector3.ZERO, blocking: bool = true) -> void:
	collision_layer = (1 | 4) if blocking else 4
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = center
	add_child(cs)


func get_prompt(_player: Node) -> String:
	return ""


func interact(_player: Node) -> void:
	pass
