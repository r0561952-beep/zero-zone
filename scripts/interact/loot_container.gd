class_name LootContainer
extends Interactable
## Контейнер с добычей: шкаф, холодильник, ящик, багажник, тайник под полом, ящик игрока.
## Содержимое генерируется при первом открытии (детерминированно по id) и сохраняется в мире.

var container_id := ""
var loot_table := ""
var title := "Ящик"
var slots_count := 12
var locked := false
var key_id := ""
var hidden := false            ## тайник: не виден, пока не «прослушан» камертоном
var visual := ""               ## "" — визуал задаёт мебель‑владелец; иначе простая модель
var box_size := Vector3(0.6, 0.5, 0.5)
var blocking := true
var fixed_items: Array = []    ## гарантированные предметы [[id, n], ...] (сюжет)
var player_storage := false
var inventory: Inventory
var _revealed := false
var _visual_node: Node3D


func _ready() -> void:
	setup_box(box_size, Vector3(0, box_size.y * 0.5, 0), blocking and not hidden)
	if hidden:
		add_to_group("hidden_stash")
		_revealed = GameState.world.has("rv:" + container_id)
		collision_layer = 4 if _revealed else 0
	if visual != "":
		_build_visual()
	var key := "lk:" + container_id
	if GameState.world.has(key):
		locked = false


func _build_visual() -> void:
	var kit := MeshKit.new()
	match visual:
		"backpack":
			kit.add_box(Mats.get_mat("sandbag"), Transform3D(Basis(Vector3.UP, 0.4) * Basis(Vector3.RIGHT, -0.3), Vector3(0, 0.22, 0)), Vector3(0.38, 0.45, 0.22))
			kit.add_box(Mats.get_mat("blanket"), Transform3D(Basis(Vector3.UP, 0.4), Vector3(0, 0.48, 0.02)), Vector3(0.32, 0.12, 0.2))
		"hatch":
			kit.add_box(Mats.get_mat("floor_wood"), Transform3D(Basis(), Vector3(0, 0.005, 0)), Vector3(0.9, 0.03, 0.9))
			kit.add_box(Mats.get_mat("metal_dark"), Transform3D(Basis(), Vector3(0.3, 0.03, 0)), Vector3(0.05, 0.03, 0.15))
		"floorboard":
			kit.add_box(Mats.get_mat("wood_dark"), Transform3D(Basis(Vector3.UP, 0.05), Vector3(0, 0.01, 0)), Vector3(0.9, 0.025, 0.22))
		"crate":
			if Models.exists("wooden_crate_01"):
				_visual_node = Models.place("wooden_crate_01", self, Transform3D.IDENTITY, "", 0.75, 0)
				return
			kit.add_box(Mats.get_mat("wood_light"), Transform3D(Basis(), Vector3(0, 0.3, 0)), Vector3(0.8, 0.6, 0.6))
		_:
			kit.add_box(Mats.get_mat("wood_dark"), Transform3D(Basis(), Vector3(0, box_size.y * 0.5, 0)), box_size)
	if not kit.is_empty():
		_visual_node = Node3D.new()
		_visual_node.add_child(kit.build_instance("Visual", false))
		add_child(_visual_node)
	if hidden and _visual_node:
		_visual_node.visible = _revealed


func reveal() -> void:
	if _revealed:
		return
	_revealed = true
	GameState.world["rv:" + container_id] = true
	collision_layer = 4
	if _visual_node:
		_visual_node.visible = true
	# короткая подсветка
	var l := OmniLight3D.new()
	l.light_color = Color(0.9, 0.8, 0.5)
	l.omni_range = 2.5
	l.light_energy = 1.5
	l.position = Vector3(0, 0.6, 0)
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, 4.0)
	tw.tween_callback(l.queue_free)


func ensure_inventory() -> Inventory:
	if inventory:
		return inventory
	inventory = Inventory.new(slots_count, 0.0)
	var key := "c:" + container_id
	if GameState.world.has(key):
		inventory.from_array(GameState.world[key])
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(container_id) ^ 0x1234
		for f in fixed_items:
			inventory.add(str(f[0]), int(f[1]))
		if loot_table != "":
			var bonus := 1 if GameState.skill_level("search") >= 2 and rng.randf() < 0.5 else 0
			for e in ItemDB.roll_loot(loot_table, rng, bonus):
				inventory.add(e[0], e[1])
		GameState.world[key] = inventory.to_array()
	inventory.changed.connect(_persist)
	return inventory


func _persist() -> void:
	GameState.world["c:" + container_id] = inventory.to_array()


func get_prompt(_player: Node) -> String:
	if hidden and not _revealed:
		return ""
	if locked:
		return "%s — заперто" % title
	var searched := GameState.world.has("c:" + container_id)
	if searched and ensure_inventory().free_slots() == inventory.size() and not player_storage:
		return "%s (пусто)" % title
	return "Обыскать: %s" % title if not player_storage else "Открыть: %s" % title


func interact(player: Node) -> void:
	if hidden and not _revealed:
		return
	if locked:
		if key_id != "" and player.count_item(key_id) > 0:
			locked = false
			GameState.world["lk:" + container_id] = true
			AudioLib.play_3d("door_locked", global_position, -4.0, 1.4)
			Events.notify.emit("Открыто ключом", "good")
		elif player.has_tool("crowbar"):
			locked = false
			GameState.world["lk:" + container_id] = true
			AudioLib.play_3d("metal_clank", global_position, 0.0)
			Events.noise_emitted.emit(global_position, 16.0, player)
			Events.notify.emit("Взломано монтировкой (шумно!)", "warn")
		else:
			AudioLib.play_3d("door_locked", global_position, -4.0)
			Events.notify.emit("Заперто. Нужен ключ или монтировка.", "warn")
			return
	var first := not GameState.world.has("c:" + container_id)
	ensure_inventory()
	if first and not player_storage:
		GameState.add_skill_xp("search", 2)
		if hidden:
			GameState.add_counter("stash_found")
	AudioLib.play_3d("rummage", global_position, -6.0)
	Events.open_screen.emit("container", self)
