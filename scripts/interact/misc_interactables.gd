class_name MiscInteract
extends RefCounted
## Небольшие интерактивные объекты: источник воды, печь/костёр, кровать, верстак,
## бочка для дождевой воды, зона (флаг при входе), зона помещения (защита от погоды и Гула).


class WaterSource:
	extends Interactable
	var title := "Колодец"

	func get_prompt(player: Node) -> String:
		if player.count_item("empty_bottle") > 0:
			return "%s — набрать воды (%d пуст. бутылок)" % [title, player.count_item("empty_bottle")]
		return "%s — попить сырой воды" % title

	func interact(player: Node) -> void:
		var n: int = player.count_item("empty_bottle")
		if n > 0:
			player.inventory.remove("empty_bottle", n)
			player.give("water_dirty", n, {}, true)
			AudioLib.play_3d("water_fill", global_position, -2.0)
			Events.notify.emit("Набрано: сырая вода ×%d. Вскипятите на огне." % n, "info")
		else:
			player.survival.apply_use({"thirst": 18, "sick": 12})
			AudioLib.play_3d("drink", global_position, -4.0)
			Events.notify.emit("Вы попили сырой воды. Лучше кипятить.", "warn")


## Печь, бочка‑печка, костёр: тепло, свет, «огонь» для крафта. Топливо в игровых минутах.
class HeatSource:
	extends Interactable
	var source_id := ""
	var title := "Печь"
	var heat_radius := 4.0
	var lit := false
	var fuel := 0.0
	var light: OmniLight3D
	var sound: AudioStreamPlayer3D
	var light_offset := Vector3(0, 0.6, 0)
	var flame: MeshInstance3D

	func _ready() -> void:
		add_to_group("heat_source")
		add_to_group("saveable")
		light = OmniLight3D.new()
		light.light_color = Color(1.0, 0.55, 0.25)
		light.omni_range = 7.0
		light.light_energy = 0.0
		light.shadow_enabled = false
		light.position = light_offset
		add_child(light)
		flame = MeshInstance3D.new()
		var q := SphereMesh.new()
		q.radius = 0.16
		q.height = 0.4
		q.radial_segments = 6
		q.rings = 3
		flame.mesh = q
		flame.material_override = Mats.get_mat("emissive_warm")
		flame.position = light_offset - Vector3(0, 0.25, 0)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(flame)
		sound = AudioLib.make_loop_3d(self, "fire_loop", -4.0, 14.0)
		var st: Dictionary = GameState.world.get("h:" + source_id, {})
		if not st.is_empty():
			fuel = float(st.get("fuel", 0.0))
			lit = bool(st.get("lit", false)) and fuel > 0.0
		_refresh()

	var save_id: String:
		get:
			return "heat:" + source_id

	func save_data() -> Dictionary:
		return {"fuel": fuel, "lit": lit}

	func load_data(d: Dictionary) -> void:
		fuel = float(d.get("fuel", 0.0))
		lit = bool(d.get("lit", false))
		_refresh()

	func _process(delta: float) -> void:
		if not lit:
			return
		if GameState.running and not get_tree().paused:
			fuel -= delta * GameState.minutes_per_second()
		if fuel <= 0.0:
			lit = false
			fuel = 0.0
			_refresh()
			return
		light.light_energy = 1.6 + sin(Time.get_ticks_msec() * 0.013) * 0.2 + randf() * 0.15
		GameState.world["h:" + source_id] = {"fuel": fuel, "lit": lit}

	func _refresh() -> void:
		light.visible = lit
		light.light_energy = 1.6 if lit else 0.0
		flame.visible = lit
		if sound:
			sound.stream_paused = not lit
		GameState.world["h:" + source_id] = {"fuel": fuel, "lit": lit}

	func get_prompt(player: Node) -> String:
		if lit:
			return "%s — готовить (горит ещё %d мин)" % [title, int(fuel)]
		if not player.has_tool("fire"):
			return "%s — нужны спички или зажигалка" % title
		return "%s — разжечь (дрова или хворост)" % title

	func interact(player: Node) -> void:
		if lit:
			# подбросить дров, если есть
			if fuel < 240.0 and player.count_item("wood_log") > 0:
				player.inventory.remove("wood_log", 1)
				fuel += 90.0
				Events.notify.emit("Подбросили полено", "info")
			Events.open_screen.emit("crafting", "fire")
			return
		if not player.has_tool("fire"):
			Events.notify.emit("Нечем разжечь", "warn")
			return
		var used := false
		if player.count_item("wood_log") > 0:
			player.inventory.remove("wood_log", 1)
			fuel += 90.0
			used = true
		if player.count_item("sticks") > 0:
			var n: int = mini(player.count_item("sticks"), 3)
			player.inventory.remove("sticks", n)
			fuel += 15.0 * n
			used = true
		if not used:
			Events.notify.emit("Нужно топливо: дрова или хворост", "warn")
			return
		# расход спичек
		var mi: int = player.inventory.find("matches")
		if mi >= 0 and player.inventory.find("lighter") < 0:
			var d: Dictionary = player.inventory.slots[mi].d
			d["charge"] = float(d.get("charge", 100.0)) - 20.0
			if float(d.charge) <= 0.0:
				player.inventory.remove_at(mi, 1)
				Events.notify.emit("Коробок спичек закончился", "warn")
		lit = true
		GameState.add_skill_xp("survival", 4)
		AudioLib.play_3d("chop", global_position, -10.0, 1.8)
		Events.notify.emit("Огонь разгорелся", "good")
		_refresh()


class Bed:
	extends Interactable
	var title := "Кровать"
	var quality := 1.0

	func get_prompt(_player: Node) -> String:
		return "%s — спать" % title

	func interact(_player: Node) -> void:
		Events.open_screen.emit("sleep", {"quality": quality, "title": title})


class Workbench:
	extends Interactable

	func _ready() -> void:
		add_to_group("workbench")

	func get_prompt(_player: Node) -> String:
		return "Верстак — мастерить"

	func interact(_player: Node) -> void:
		Events.open_screen.emit("crafting", "workbench")


class RainCollector:
	extends Interactable
	var source_id := ""
	var water := 0.0

	func _ready() -> void:
		water = float(GameState.world.get("rc:" + source_id, 0.0))

	func _process(delta: float) -> void:
		var w = GameState.world_node
		if w and w.has_method("is_raining") and w.is_raining() and GameState.running:
			water = minf(6.0, water + delta * GameState.minutes_per_second() / 40.0)
			GameState.world["rc:" + source_id] = water

	func get_prompt(_player: Node) -> String:
		return "Бочка: дождевая вода — %d бут. (нужны пустые бутылки)" % int(water)

	func interact(player: Node) -> void:
		var n: int = mini(int(water), player.count_item("empty_bottle"))
		if n <= 0:
			Events.notify.emit("Нет воды или пустых бутылок", "warn")
			return
		player.inventory.remove("empty_bottle", n)
		player.give("water_clean", n)
		water -= n
		GameState.world["rc:" + source_id] = water
		AudioLib.play_3d("water_fill", global_position, -2.0)


## Зона: при входе игрока ставит флаг (сюжетные триггеры) и/или сообщение.
class Trigger:
	extends Area3D
	var flag := ""
	var message := ""
	var once := true

	func setup(size: Vector3) -> void:
		collision_layer = 0
		collision_mask = 2
		monitoring = true
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = size
		cs.shape = b
		cs.position.y = size.y * 0.5
		add_child(cs)
		body_entered.connect(_on_enter)

	func _on_enter(b: Node) -> void:
		if not b.is_in_group("player"):
			return
		if once and flag != "" and GameState.get_flag(flag):
			return
		if flag != "":
			GameState.set_flag(flag)
		if message != "":
			Events.notify.emit(message, "lore")


## Помещение: игрок внутри — укрыт от погоды, частично от Гула; глубина >0 — подвал/убежище.
class IndoorArea:
	extends Area3D
	var basement := false

	func setup(size: Vector3, center: Vector3) -> void:
		collision_layer = 0
		collision_mask = 2
		monitoring = true
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = size
		cs.shape = b
		cs.position = center
		add_child(cs)
		body_entered.connect(func(n):
			if n.is_in_group("player"):
				if basement:
					n.shelter_depth += 1
				else:
					n.indoor_areas += 1)
		body_exited.connect(func(n):
			if n.is_in_group("player"):
				if basement:
					n.shelter_depth = maxi(0, n.shelter_depth - 1)
				else:
					n.indoor_areas = maxi(0, n.indoor_areas - 1))
