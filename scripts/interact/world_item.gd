class_name WorldItem
extends Interactable
## Предмет, лежащий в мире. Если у предмета есть 3D‑модель (items.json → model) — показывается она,
## иначе — аккуратный процедурный «свёрток» цвета категории.

var item_id := ""
var count := 1
var data: Dictionary = {}
var pickup_id := ""          ## для постоянных предметов мира (сюжет); "" — брошенные игроком
var dropped_index := -1


func _ready() -> void:
	setup_box(Vector3(0.45, 0.3, 0.45), Vector3(0, 0.15, 0), false)
	_build_visual()


func _build_visual() -> void:
	var it := ItemDB.item(item_id)
	var model := str(it.get("model", ""))
	if model != "" and Models.exists(model):
		Models.place(model, self, Transform3D(Basis(Vector3.UP, randf() * TAU), Vector3.ZERO), "", 0.0 if ItemDB.weight(item_id) > 1.0 else 0.0, 0)
		return
	var kit := MeshKit.new()
	var cat := ItemDB.category(item_id)
	match cat:
		"document", "quest":
			kit.add_box(Mats.get_mat("sign_white"), Transform3D(Basis(Vector3.UP, 0.3), Vector3(0, 0.005, 0)), Vector3(0.21, 0.006, 0.29))
		"key":
			kit.add_box(Mats.get_mat("metal_light"), Transform3D(Basis(), Vector3(0, 0.01, 0)), Vector3(0.06, 0.01, 0.02))
			kit.add_cylinder(Mats.get_mat("metal_light"), Vector3(-0.05, 0.0, 0), 0.015, 0.025, 0.025, 6)
		"water":
			kit.add_cylinder(Mats.get_mat("glass"), Vector3.ZERO, 0.3, 0.045, 0.045, 8)
			kit.add_cylinder(Mats.get_mat("hive_blue"), Vector3(0, 0.3, 0), 0.03, 0.015, 0.015, 6)
		"clothing":
			kit.add_box(Mats.get_mat("blanket"), Transform3D(Basis(Vector3.UP, 0.4), Vector3(0, 0.05, 0)), Vector3(0.45, 0.1, 0.35))
		"food":
			kit.add_cylinder(Mats.get_mat("metal_light"), Vector3.ZERO, 0.1, 0.05, 0.05, 8)
		_:
			kit.add_box(Mats.get_mat("sandbag"), Transform3D(Basis(Vector3.UP, 0.4), Vector3(0, 0.08, 0)), Vector3(0.3, 0.16, 0.22))
	add_child(kit.build_instance("Visual", false))


func get_prompt(_player: Node) -> String:
	var t := "Взять: %s" % ItemDB.item_name(item_id)
	if count > 1:
		t += " ×%d" % count
	if ItemDB.category(item_id) == "document":
		t = "Прочитать и взять: %s" % ItemDB.item_name(item_id)
	return t


func interact(player: Node) -> void:
	player.give(item_id, count, data)
	AudioLib.play_3d("pickup", global_position, -6.0)
	if pickup_id != "":
		GameState.world["p:" + pickup_id] = true
	elif GameState.world_node and GameState.world_node.has_method("remove_dropped"):
		GameState.world_node.remove_dropped(self)
	var it := ItemDB.item(item_id)
	if it.has("note"):
		player.read_note(str(it.note), item_id)
	queue_free()
