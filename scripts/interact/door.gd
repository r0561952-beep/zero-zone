class_name Door
extends Node3D
## Дверь на петлях. Может быть заперта (ключ или монтировка). Состояние сохраняется в мире.
## Узел стоит на оси петли; полотно — дочерний StaticBody, поворачивается вокруг Y.

var door_id := ""
var width := 0.9
var height := 2.0
var locked := false
var key_id := ""
var forceable := true
var open := false
var open_dir := 1.0
var material_name := "door"
var title := "Дверь"
var heavy := false           ## металлическая дверь убежища
var panel: StaticBody3D
var _tween: Tween


func _ready() -> void:
	var st: Dictionary = GameState.world.get("d:" + door_id, {})
	if not st.is_empty():
		open = bool(st.get("open", false))
		locked = bool(st.get("locked", locked))
	panel = DoorPanel.new()
	panel.door = self
	panel.collision_layer = 1 | 4
	panel.set_meta("surface", "wood")
	add_child(panel)
	var kit := MeshKit.new()
	var mat := Mats.get_mat(material_name)
	kit.add_box(mat, Transform3D(Basis(), Vector3(width * 0.5, height * 0.5, 0)), Vector3(width - 0.02, height - 0.02, 0.05))
	kit.add_box(Mats.get_mat("metal_dark"), Transform3D(Basis(), Vector3(width - 0.12, height * 0.48, 0.045)), Vector3(0.1, 0.03, 0.04))
	kit.add_box(Mats.get_mat("metal_dark"), Transform3D(Basis(), Vector3(width - 0.12, height * 0.48, -0.045)), Vector3(0.1, 0.03, 0.04))
	panel.add_child(kit.build_instance("DoorMesh", true))
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(width - 0.04, height - 0.04, 0.06)
	cs.shape = b
	cs.position = Vector3(width * 0.5, height * 0.5, 0)
	panel.add_child(cs)
	panel.rotation.y = _angle()


func _angle() -> float:
	return deg_to_rad(95.0) * open_dir if open else 0.0


func prompt(player: Node) -> String:
	if locked:
		if key_id != "" and player.count_item(key_id) > 0:
			return "%s — открыть ключом" % title
		if forceable and player.has_tool("crowbar"):
			return "%s — взломать монтировкой" % title
		return "%s — заперто" % title
	return ("Закрыть: " if open else "Открыть: ") + title.to_lower()


func use(player: Node) -> void:
	if locked:
		if key_id != "" and player.count_item(key_id) > 0:
			locked = false
			AudioLib.play_3d("door_locked", global_position + Vector3.UP, -2.0, 1.3)
			Events.notify.emit("Открыто: %s" % ItemDB.item_name(key_id), "good")
			GameState.set_flag("opened_" + door_id)
		elif forceable and player.has_tool("crowbar"):
			locked = false
			AudioLib.play_3d("metal_clank", global_position + Vector3.UP, 2.0, 0.8)
			AudioLib.play_3d("door_close", global_position + Vector3.UP, 2.0, 0.7)
			Events.noise_emitted.emit(global_position, 22.0, player)
			Events.notify.emit("Дверь взломана (шумно!)", "warn")
			GameState.set_flag("opened_" + door_id)
		else:
			AudioLib.play_3d("door_locked", global_position + Vector3.UP, -2.0)
			Events.notify.emit("Заперто" + (". Нужен ключ." if not forceable else ". Нужен ключ или монтировка."), "warn")
			_save()
			return
	open = not open
	# открываться — от игрока
	if open:
		var to_player: Vector3 = player.global_position - global_position
		var normal := global_transform.basis.z
		open_dir = 1.0 if to_player.dot(normal) > 0.0 else -1.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(panel, "rotation:y", _angle(), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if open:
		AudioLib.play_3d("door_creak" if randf() < 0.6 else "pickup", global_position + Vector3.UP, -4.0 if not heavy else 0.0, 0.8 if heavy else 1.0)
	else:
		AudioLib.play_3d("door_close", global_position + Vector3.UP, -6.0)
	Events.noise_emitted.emit(global_position, 6.0, player)
	_save()


func _save() -> void:
	GameState.world["d:" + door_id] = {"open": open, "locked": locked}


class DoorPanel:
	extends StaticBody3D
	var door: Door

	func get_prompt(player: Node) -> String:
		return door.prompt(player)

	func interact(player: Node) -> void:
		door.use(player)
