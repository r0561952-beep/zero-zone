extends Node
## Система сохранений: несколько слотов + автосохранение, JSON в user://saves/.
## Сохраняются: GameState (мир, время, флаги, журнал…), игрок, все узлы группы "saveable".

const DIR := "user://saves"
const SLOTS := ["auto", "1", "2", "3", "4", "5"]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)


func slot_path(slot: String) -> String:
	return "%s/slot_%s.json" % [DIR, slot]


func slot_title(slot: String) -> String:
	return "Автосохранение" if slot == "auto" else "Слот %s" % slot


func save_game(slot: String) -> bool:
	if GameState.player == null:
		return false
	var nodes := {}
	for n in get_tree().get_nodes_in_group("saveable"):
		if n.has_method("save_data") and "save_id" in n:
			nodes[str(n.save_id)] = n.save_data()
	var loc := "Нулевая зона"
	if GameState.world_node and GameState.world_node.has_method("location_name_at"):
		loc = GameState.world_node.location_name_at(GameState.player.global_position)
	var data := {
		"version": GameState.SAVE_VERSION,
		"meta": {
			"saved_at": Time.get_datetime_string_from_system(false, true),
			"unix": Time.get_unix_time_from_system(),
			"clock": GameState.clock_text(),
			"location": loc,
			"playtime": GameState.playtime,
		},
		"state": GameState.to_dict(),
		"player": GameState.player.save_data(),
		"nodes": nodes,
	}
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		Events.notify.emit("Не удалось сохранить игру", "bad")
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	if slot != "auto":
		Events.notify.emit("Игра сохранена: %s" % slot_title(slot), "good")
	return true


func read_slot(slot: String) -> Dictionary:
	if not FileAccess.file_exists(slot_path(slot)):
		return {}
	var f := FileAccess.open(slot_path(slot), FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d if typeof(d) == TYPE_DICTIONARY else {}


func slot_meta(slot: String) -> Dictionary:
	var d := read_slot(slot)
	return d.get("meta", {})


func has_any_save() -> bool:
	for s in SLOTS:
		if FileAccess.file_exists(slot_path(s)):
			return true
	return false


func latest_slot() -> String:
	var best := ""
	var best_t := -1.0
	for s in SLOTS:
		var m := slot_meta(s)
		if not m.is_empty() and float(m.get("unix", 0)) > best_t:
			best_t = float(m.get("unix", 0))
			best = s
	return best


func delete_slot(slot: String) -> void:
	if FileAccess.file_exists(slot_path(slot)):
		DirAccess.remove_absolute(slot_path(slot))


## Подготовить загрузку: состояние применяется сразу, игрок и узлы — после постройки мира.
func prepare_load(slot: String) -> bool:
	var d := read_slot(slot)
	if d.is_empty():
		Events.notify.emit("Сохранение повреждено или отсутствует", "bad")
		return false
	GameState.from_dict(d.get("state", {}))
	GameState.pending_load = d
	return true


## Вызывается миром после постройки, чтобы восстановить игрока и сохраняемые узлы.
func apply_pending() -> void:
	var d := GameState.pending_load
	if d.is_empty():
		return
	if GameState.player:
		GameState.player.load_data(d.get("player", {}))
	var nodes: Dictionary = d.get("nodes", {})
	for n in get_tree().get_nodes_in_group("saveable"):
		if "save_id" in n and nodes.has(str(n.save_id)) and n.has_method("load_data"):
			n.load_data(nodes[str(n.save_id)])
	GameState.pending_load = {}
	Events.game_loaded.emit()


# Вспомогательные функции сериализации векторов
static func v3(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]


static func to_v3(a: Variant, def: Vector3 = Vector3.ZERO) -> Vector3:
	if a is Array and a.size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return def
