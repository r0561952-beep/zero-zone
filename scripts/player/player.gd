extends CharacterBody3D
## Игрок (Глеб Ланской). Движение, камера, взаимодействие, инвентарь, экипировка,
## выживание, фонарик, удары, шум. Ввод — только через InputRouter (тач или PC).

const WALK := 3.3
const SPRINT := 5.6
const CROUCH := 1.7
const JUMP := 4.6
const GRAVITY := 14.0
const STAND_H := 1.62
const CROUCH_H := 1.0
const MAX_WEIGHT := 25.0
const INTERACT_DIST := 2.4

var survival := Survival.new()
var inventory := Inventory.new(24, MAX_WEIGHT)
var equipment: Dictionary = {}          ## слот -> {"id","n","d"}
var quickbar: Array = ["", "", "", ""]  ## id предметов
var crouching := false
var sprinting := false
var flashlight_on := false
var torch_on := false
var indoor_areas := 0
var shelter_depth := 0                  ## >0 — в подвале/убежище
var in_water := false
var near_fire := false
var dead := false
var in_vehicle: Node = null
var sleeping := false
var hum_disorient := Vector2.ZERO

var head: Node3D
var camera: Camera3D
var ray: RayCast3D
var flashlight: SpotLight3D
var torch_light: OmniLight3D
var hand_root: Node3D
var _hand_model: Node3D
var _hand_id := ""
var _yaw := 0.0
var _pitch := 0.0
var _step_dist := 0.0
var _bob := 0.0
var _target: Node = null
var _prompt := ""
var _attack_cd := 0.0
var _swing := 0.0
var _fire_check := 0.0
var _env_check := 0.0
var _hour_acc := 0.0
var _last_pos := Vector3.ZERO
var _reveal_acc := 0.0
var _land_vel := 0.0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 16
	floor_max_angle = deg_to_rad(48)
	floor_snap_length = 0.4
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.875
	cs.name = "Shape"
	add_child(cs)

	head = Node3D.new()
	head.name = "Head"
	head.position.y = STAND_H
	add_child(head)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.near = 0.05
	camera.current = true
	head.add_child(camera)

	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -INTERACT_DIST)
	ray.collision_mask = 1 | 4 | 8 | 16
	ray.collide_with_areas = false
	camera.add_child(ray)

	flashlight = SpotLight3D.new()
	flashlight.name = "Flashlight"
	flashlight.spot_range = 24.0
	flashlight.spot_angle = 26.0
	flashlight.spot_attenuation = 0.8
	flashlight.light_energy = 3.2
	flashlight.light_color = Color(1.0, 0.95, 0.85)
	flashlight.position = Vector3(0.18, -0.12, 0.0)
	flashlight.visible = false
	camera.add_child(flashlight)

	torch_light = OmniLight3D.new()
	torch_light.omni_range = 9.0
	torch_light.light_energy = 1.6
	torch_light.light_color = Color(1.0, 0.6, 0.3)
	torch_light.position = Vector3(0.3, -0.2, -0.4)
	torch_light.visible = false
	camera.add_child(torch_light)

	hand_root = Node3D.new()
	hand_root.name = "Hand"
	hand_root.position = Vector3(0.32, -0.3, -0.5)
	camera.add_child(hand_root)

	GameState.player = self
	inventory.changed.connect(func(): Events.inventory_changed.emit())
	Events.settings_changed.connect(_apply_settings)
	_apply_settings()


func _exit_tree() -> void:
	if GameState.player == self:
		GameState.player = null


func _apply_settings() -> void:
	camera.fov = Settings.fov
	camera.far = Settings.view_distance + 40.0
	flashlight.shadow_enabled = Settings.shadows >= 3


## Стартовый набор для новой игры.
func give_starting_kit() -> void:
	equipment = {
		"torso": {"id": "jacket_basic", "n": 1, "d": {}},
		"legs": {"id": "jeans", "n": 1, "d": {}},
		"feet": {"id": "boots", "n": 1, "d": {}},
	}
	inventory.add("doc_postcard", 1)
	inventory.add("tuning_fork", 1)
	inventory.add("flashlight", 1, {"charge": 60.0})
	inventory.add("crackers", 2)
	inventory.add("water_bottle", 1)
	inventory.add("matches", 1)
	inventory.add("bandage", 1)
	inventory.add("knife", 1)
	inventory.add("photo_alya", 1)
	quickbar = ["knife", "water_bottle", "crackers", "flashlight"]
	Events.equipment_changed.emit()


func set_look(yaw: float, pitch: float) -> void:
	_yaw = yaw
	_pitch = pitch
	rotation.y = _yaw
	head.rotation.x = _pitch


# ======================================================================= ЦИКЛ
func _physics_process(delta: float) -> void:
	if dead or sleeping:
		velocity = Vector3.ZERO
		return
	if in_vehicle:
		return
	var active := InputRouter.gameplay_active
	# --- камера
	var look := InputRouter.consume_look()
	if active:
		var inv := -1.0 if Settings.invert_y else 1.0
		_yaw -= deg_to_rad(look.x)
		_pitch = clampf(_pitch - deg_to_rad(look.y) * inv, deg_to_rad(-85), deg_to_rad(85))
	# дезориентация от Гула: камеру «ведёт»
	var hx := survival.hum_exposure / 100.0
	if hx > 0.15:
		var t := Time.get_ticks_msec() / 1000.0
		_yaw += sin(t * 0.7) * 0.004 * hx
		hum_disorient = Vector2(sin(t * 0.43), cos(t * 0.31)) * hx * 0.5
	else:
		hum_disorient = Vector2.ZERO
	rotation.y = _yaw
	head.rotation.x = _pitch
	head.rotation.z = lerpf(head.rotation.z, sin(Time.get_ticks_msec() / 900.0) * 0.06 * hx, 0.1)

	# --- движение
	var mv := InputRouter.move_vector() if active else Vector2.ZERO
	mv += hum_disorient * mv.length() * 0.6
	var want_crouch := Input.is_action_pressed("crouch") if active else false
	if want_crouch != crouching:
		if want_crouch or _can_stand():
			crouching = want_crouch
	var overweight := inventory.total_weight() + _equip_weight() - MAX_WEIGHT
	sprinting = active and Input.is_action_pressed("sprint") and not crouching and mv.y < 0.2 and mv.length() > 0.3 \
		and survival.stamina > 2.0 and overweight <= 0.0
	var speed := WALK
	if sprinting:
		speed = SPRINT
	elif crouching:
		speed = CROUCH
	if overweight > 0.0:
		speed *= 0.7 if overweight < 15.0 else 0.45
	if survival.health < 25.0:
		speed *= 0.8
	if in_water:
		speed *= 0.6
	var dir := (transform.basis * Vector3(mv.x, 0, mv.y))
	dir.y = 0
	var target_v := dir * speed
	var accel := 10.0 if is_on_floor() else 2.5
	velocity.x = move_toward(velocity.x, target_v.x, accel * speed * delta)
	velocity.z = move_toward(velocity.z, target_v.z, accel * speed * delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
		_land_vel = minf(_land_vel, velocity.y)
	else:
		if _land_vel < -9.0:
			var dmg := (-_land_vel - 9.0) * 6.0
			take_damage(dmg, "падение")
		_land_vel = 0.0
		if active and Input.is_action_just_pressed("jump") and survival.stamina > 10.0 and not crouching:
			velocity.y = JUMP
			survival.stamina -= 10.0
			emit_noise(6.0)
	move_and_slide()
	# страховка: если игрок как-то провалился под мир — вернуть на поверхность
	if global_position.y < -60.0:
		var gx := global_position.x
		var gz := global_position.z
		global_position = Vector3(gx, RegionData.height_at(gx, gz) + 1.0, gz)
		velocity = Vector3.ZERO
		Events.notify.emit("Вы выбрались на поверхность", "warn")

	# --- высота головы, покачивание, шаги
	var h_target := CROUCH_H if crouching else STAND_H
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hspeed > 0.5:
		_bob += hspeed * delta * 2.2
		_step_dist += hspeed * delta
		var stride := 2.1 if sprinting else 1.6
		if _step_dist > stride:
			_step_dist = 0.0
			_footstep()
	var bob_y := sin(_bob) * 0.035 if Settings.head_bob else 0.0
	head.position.y = lerpf(head.position.y, h_target + bob_y, 12.0 * delta)
	if _swing > 0.0:
		_swing = maxf(0.0, _swing - delta * 3.0)
	hand_root.rotation.x = -sin(_swing * PI) * 1.1
	hand_root.position.y = -0.3 + sin(_bob * 0.5) * 0.01

	_update_interaction()


func _process(delta: float) -> void:
	if dead:
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	var minutes := delta * GameState.minutes_per_second() if GameState.running and not get_tree().paused else 0.0
	if InputRouter.gameplay_active and not in_vehicle:
		_handle_actions()
	# Окружение (раз в 0.5 с)
	_env_check -= delta
	if _env_check <= 0.0:
		_env_check = 0.5
		_update_environment()
	# Выживание
	var wn: Node = GameState.world_node
	var ctx := {
		"moving": Vector2(velocity.x, velocity.z).length() > 0.5,
		"sprinting": sprinting and Vector2(velocity.x, velocity.z).length() > 3.0,
		"indoors": is_indoors() or (in_vehicle != null),
		"near_fire": near_fire,
		"in_water": in_water,
		"air_temp": wn.air_temperature() if wn and wn.has_method("air_temperature") else 6.0,
		"wind": wn.wind_strength() if wn and wn.has_method("wind_strength") else 0.3,
		"raining": wn.is_raining() if wn and wn.has_method("is_raining") else false,
		"rain_intensity": wn.rain_intensity() if wn and wn.has_method("rain_intensity") else 0.0,
		"rain_protect": _rain_protect(),
		"insulation": insulation(),
		"hum_active": GameState.is_hum_active(),
		"hum_protect": hum_protection(),
		"sleeping": sleeping,
	}
	if minutes > 0.0:
		survival.tick(delta, minutes, ctx)
		_hour_acc += minutes
		if _hour_acc >= 60.0:
			inventory.tick_spoil(_hour_acc / 60.0)
			_hour_acc = 0.0
	_update_lights(delta)
	if survival.is_dead():
		die(survival.last_damage_cause)


func _handle_actions() -> void:
	if Input.is_action_just_pressed("interact"):
		interact()
	if Input.is_action_just_pressed("flashlight"):
		toggle_light()
	if Input.is_action_pressed("attack") and _attack_cd <= 0.0:
		attack()
	if Input.is_action_just_pressed("tuning_fork"):
		use_tuning_fork()
	if Input.is_action_just_pressed("chalk"):
		use_chalk()
	for i in 4:
		if Input.is_action_just_pressed("slot_%d" % (i + 1)):
			use_quickbar(i)


# ===================================================================== ОКРУЖЕНИЕ
func is_indoors() -> bool:
	return indoor_areas > 0 or shelter_depth > 0


func hum_protection() -> float:
	if shelter_depth > 0:
		return 1.0
	if in_vehicle:
		return 0.75
	if indoor_areas > 0:
		return 0.6
	return 0.0


func insulation() -> float:
	var ins := 0.0
	for s in equipment:
		if s == "hand":
			continue
		ins += float(ItemDB.item(equipment[s].id).get("insulation", 0.0))
	return ins


func _rain_protect() -> float:
	var p := 0.0
	for s in equipment:
		p = maxf(p, float(ItemDB.item(equipment[s].id).get("rain", 0.0)))
	return p


func _equip_weight() -> float:
	var w := 0.0
	for s in equipment:
		w += ItemDB.weight(equipment[s].id)
	return w * 0.5   # надетое весит «вполовину»


func _update_environment() -> void:
	near_fire = false
	for f in get_tree().get_nodes_in_group("heat_source"):
		if f is Node3D and f.get("lit") and global_position.distance_to((f as Node3D).global_position) < float(f.get("heat_radius")):
			near_fire = true
			break
	var m := RegionData.mask_at(global_position.x, global_position.z)
	var ground_h := RegionData.height_at(global_position.x, global_position.z)
	in_water = m.b > 0.55 and global_position.y < ground_h + 0.4
	# Открытие карты и локаций
	_reveal_acc += 0.5
	if _reveal_acc >= 2.0:
		_reveal_acc = 0.0
		GameState.reveal_map(global_position, 70.0)
		if GameState.world_node and GameState.world_node.has_method("check_locations"):
			GameState.world_node.check_locations(global_position)


func _footstep() -> void:
	var surface := "dirt"
	var col := get_last_slide_collision()
	var m := RegionData.mask_at(global_position.x, global_position.z)
	if is_indoors() or (col and col.get_collider() and col.get_collider().has_meta("surface")):
		surface = str(col.get_collider().get_meta("surface", "wood")) if col and col.get_collider() else "wood"
	elif m.a > 0.5:
		surface = "concrete"
	elif m.r > 0.4:
		surface = "gravel"
	elif m.g > 0.4:
		surface = "grass"
	var vol := -14.0 if crouching else (-4.0 if sprinting else -9.0)
	AudioLib.play_3d("step_" + surface, global_position, vol, 1.0, 20.0)
	if sprinting:
		emit_noise(9.0)
	elif not crouching:
		emit_noise(3.5)


func emit_noise(radius: float) -> void:
	Events.noise_emitted.emit(global_position, radius, self)


# ==================================================================== ВЗАИМОДЕЙСТВИЕ
func _update_interaction() -> void:
	var t: Node = null
	if ray.is_colliding():
		var c := ray.get_collider()
		var n: Node = c
		for i in 4:
			if n == null:
				break
			if n.has_method("get_prompt"):
				t = n
				break
			n = n.get_parent()
	_target = t
	var p := ""
	if t:
		p = str(t.get_prompt(self))
	if p != _prompt:
		_prompt = p
		Events.prompt_changed.emit(p)


func interact() -> void:
	if _target and is_instance_valid(_target) and _target.has_method("interact"):
		_target.interact(self)


func current_target() -> Node:
	return _target


func aim_point() -> Dictionary:
	if ray.is_colliding():
		return {"pos": ray.get_collision_point(), "normal": ray.get_collision_normal(), "collider": ray.get_collider()}
	return {}


# ======================================================================== ПРЕДМЕТЫ
## Дать предмет игроку; лишнее падает на землю.
func give(id: String, n: int = 1, data: Dictionary = {}, silent: bool = false) -> void:
	var left := inventory.add(id, n, data)
	var got := n - left
	if got > 0 and not silent:
		Events.item_picked.emit(id, got)
		Events.notify.emit("+%d %s" % [got, ItemDB.item_name(id)], "info")
	if left > 0:
		Events.notify.emit("Не помещается: %s ×%d — брошено рядом" % [ItemDB.item_name(id), left], "warn")
		drop_world(id, left, data)


func drop_world(id: String, n: int, data: Dictionary = {}) -> void:
	if GameState.world_node and GameState.world_node.has_method("spawn_dropped"):
		var p := global_position + (-global_transform.basis.z) * 0.8 + Vector3.UP * 0.3
		GameState.world_node.spawn_dropped(id, n, data, p)


func count_item(id: String) -> int:
	return inventory.count(id)


func has_tool(tag: String) -> bool:
	if equipment.has("hand") and ItemDB.has_tag(equipment.hand.id, tag):
		return true
	return inventory.has_tag(tag)


## Использовать предмет из ячейки инвентаря.
func use_slot(i: int) -> void:
	var s = inventory.slots[i]
	if s == null:
		return
	var id: String = s.id
	var it := ItemDB.item(id)
	if it.has("note"):
		read_note(str(it.note), id)
		return
	if it.has("place"):
		if GameState.world_node and GameState.world_node.has_method("begin_placement"):
			Events.close_screens.emit()
			GameState.world_node.begin_placement(id)
		return
	if it.has("equip"):
		equip_from(i)
		return
	if ItemDB.has_tag(id, "radio"):
		Events.open_screen.emit("radio", null)
		return
	if ItemDB.has_tag(id, "fork"):
		Events.close_screens.emit()
		use_tuning_fork()
		return
	if ItemDB.has_tag(id, "light") or ItemDB.has_tag(id, "light_torch"):
		Events.close_screens.emit()
		toggle_light()
		return
	if ItemDB.has_tag(id, "chalk"):
		Events.close_screens.emit()
		use_chalk()
		return
	if it.has("use"):
		var use: Dictionary = it.use
		if use.has("recharge"):
			var fi := inventory.find(str(use.recharge))
			if fi < 0:
				Events.notify.emit("Нечего заряжать", "warn")
				return
			inventory.slots[fi].d["charge"] = 100.0
			inventory.remove_at(i, 1)
			Events.notify.emit("Фонарик заряжен", "good")
			return
		survival.apply_use(use)
		inventory.remove_at(i, 1)
		if it.has("leaves"):
			inventory.add(str(it.leaves), 1)
		var cat := ItemDB.category(id)
		AudioLib.play_2d("drink" if cat == "water" else ("eat" if cat == "food" else "pickup"), -6.0)
		if cat == "medical":
			GameState.add_skill_xp("medicine", 6)
		Events.item_used.emit(id)
		Events.notify.emit("Использовано: %s" % ItemDB.item_name(id), "info")
		return
	Events.notify.emit("Это нельзя использовать напрямую", "warn")


func use_quickbar(i: int) -> void:
	var id: String = quickbar[i]
	if id == "":
		return
	if equipment.has("hand") and equipment.hand.id == id:
		unequip("hand")
		return
	var idx := inventory.find(id)
	if idx < 0:
		Events.notify.emit("Нет: %s" % ItemDB.item_name(id), "warn")
		return
	use_slot(idx)


func equip_from(i: int) -> void:
	var s = inventory.slots[i]
	if s == null:
		return
	var slot := ItemDB.equip_slot(s.id)
	if slot == "":
		return
	var taken := inventory.remove_at(i, 1)
	if equipment.has(slot):
		var old: Dictionary = equipment[slot]
		inventory.add(old.id, 1, old.d)
	equipment[slot] = taken
	AudioLib.play_2d("pickup", -8.0)
	if slot == "hand":
		_update_hand_model()
	Events.equipment_changed.emit()
	Events.inventory_changed.emit()


func unequip(slot: String) -> void:
	if not equipment.has(slot):
		return
	var it: Dictionary = equipment[slot]
	equipment.erase(slot)
	var left := inventory.add(it.id, 1, it.d)
	if left > 0:
		drop_world(it.id, 1, it.d)
	if slot == "hand":
		_update_hand_model()
	Events.equipment_changed.emit()


func _update_hand_model() -> void:
	var id: String = equipment.hand.id if equipment.has("hand") else ""
	if id == _hand_id:
		return
	_hand_id = id
	if _hand_model:
		_hand_model.queue_free()
		_hand_model = null
	if id == "":
		return
	var model := str(ItemDB.item(id).get("model", ""))
	if model != "" and Models.exists(model):
		_hand_model = Models.place(model, hand_root, Transform3D(Basis.from_euler(Vector3(0.3, -1.2, 0.2)), Vector3.ZERO), "", 0.45, 0)
	else:
		# простая «рукоять» для предметов без модели
		var kit := MeshKit.new()
		kit.add_box(Mats.get_mat("wood_dark"), Transform3D(Basis(), Vector3(0, 0, 0)), Vector3(0.04, 0.04, 0.35))
		kit.add_box(Mats.get_mat("metal_light"), Transform3D(Basis(), Vector3(0, 0, -0.25)), Vector3(0.015, 0.05, 0.2))
		_hand_model = Node3D.new()
		_hand_model.add_child(kit.build_instance("HandItem", false))
		hand_root.add_child(_hand_model)
	if _hand_model:
		Models.set_shadows(_hand_model, false)


func drop_slot(i: int) -> void:
	var s = inventory.slots[i]
	if s == null:
		return
	if ItemDB.category(s.id) in ["key", "quest"]:
		Events.notify.emit("Это лучше оставить при себе", "warn")
		return
	var taken := inventory.remove_at(i, int(s.n))
	drop_world(taken.id, int(taken.n), taken.d)
	AudioLib.play_2d("ui:drop_002", -6.0, 1.0, "UI")


func read_note(note_id: String, item_id: String = "") -> void:
	var first := not (note_id in GameState.notes_read)
	if first:
		GameState.notes_read.append(note_id)
		var n: Dictionary = ItemDB.notes.get(note_id, {})
		for f in n.get("flags", []):
			GameState.set_flag(str(f))
		for r in n.get("unlock", []):
			GameState.learn_recipe(str(r))
		if n.has("journal"):
			GameState.journal_add("note_" + note_id, str(n.journal))
		Events.note_read.emit(note_id)
	Events.open_screen.emit("note", {"note": note_id, "item": item_id})


# ============================================================================ СВЕТ
func toggle_light() -> void:
	if flashlight_on or torch_on:
		flashlight_on = false
		torch_on = false
		AudioLib.play_2d("ui:click_004", -8.0, 1.0, "UI")
		return
	var fi := inventory.find("flashlight")
	if fi >= 0:
		if float(inventory.slots[fi].d.get("charge", 0.0)) <= 0.0:
			Events.notify.emit("Фонарик разряжен. Нужны батарейки.", "warn")
		else:
			flashlight_on = true
			AudioLib.play_2d("ui:click_004", -8.0, 1.2, "UI")
			return
	var ti := inventory.find("torch")
	if ti >= 0:
		torch_on = true
		AudioLib.play_2d("chop", -18.0, 2.0)
		return
	Events.notify.emit("Нет источника света", "warn")


func _update_lights(delta: float) -> void:
	if flashlight_on:
		var fi := inventory.find("flashlight")
		if fi < 0:
			flashlight_on = false
		else:
			var d: Dictionary = inventory.slots[fi].d
			d["charge"] = maxf(0.0, float(d.get("charge", 0.0)) - delta * 0.22)
			if float(d.charge) <= 0.0:
				flashlight_on = false
				Events.notify.emit("Фонарик сел", "warn")
			flashlight.light_energy = 3.2 * (0.55 + 0.45 * clampf(float(d.charge) / 25.0, 0.0, 1.0))
	if torch_on:
		var ti := inventory.find("torch")
		if ti < 0:
			torch_on = false
		else:
			var d2: Dictionary = inventory.slots[ti].d
			d2["charge"] = float(d2.get("charge", 100.0)) - delta * 0.8
			torch_light.light_energy = 1.5 + sin(Time.get_ticks_msec() * 0.023) * 0.15 + randf() * 0.1
			if float(d2.charge) <= 0.0:
				inventory.remove_at(ti, 1)
				torch_on = false
				Events.notify.emit("Факел догорел", "warn")
	flashlight.visible = flashlight_on
	torch_light.visible = torch_on


# ============================================================================= БОЙ
func attack() -> void:
	if not equipment.has("hand"):
		return
	var it := ItemDB.item(equipment.hand.id)
	if not it.has("weapon"):
		return
	var w: Dictionary = it.weapon
	_attack_cd = float(w.get("cooldown", 0.8))
	_swing = 1.0
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * float(w.get("range", 1.8))
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 4 | 8 | 16)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	emit_noise(5.0)
	if hit.is_empty():
		AudioLib.play_2d("pickup", -10.0, 0.6)
		return
	var c: Node = hit.collider
	var n := c
	for i in 4:
		if n == null:
			break
		if n.has_method("take_damage"):
			n.take_damage(float(w.get("damage", 10)), self)
			AudioLib.play_3d("hit", hit.position, -2.0)
			return
		if n.has_method("chop") and ItemDB.has_tag(equipment.hand.id, "axe"):
			n.chop(self)
			return
		n = n.get_parent()
	AudioLib.play_3d("hit", hit.position, -6.0, 1.3)


func take_damage(amount: float, cause: String = "ранение") -> void:
	if dead:
		return
	survival.damage(amount, cause)
	if amount >= 12.0 and cause in ["ранение", "удар"] and randf() < 0.35:
		survival.bleeding = true
		Events.notify.emit("Кровотечение! Нужен бинт.", "bad")
	Events.player_damaged.emit(amount, cause)
	Events.hud_flash.emit(Color(0.6, 0.0, 0.0, 0.35))


func die(cause: String) -> void:
	if dead:
		return
	dead = true
	flashlight_on = false
	Events.player_died.emit(cause)


# ======================================================================= ОСОБОЕ
## Камертон: подсвечивает скрытые тайники поблизости (профессия Глеба).
func use_tuning_fork() -> void:
	if not inventory.has("tuning_fork"):
		return
	AudioLib.play_2d("tuning_fork", -4.0)
	var radius := 10.0 + GameState.skill_level("search") * 3.0
	var found := 0
	for s in get_tree().get_nodes_in_group("hidden_stash"):
		if s is Node3D and global_position.distance_to((s as Node3D).global_position) < radius:
			if s.has_method("reveal"):
				s.reveal()
				found += 1
	if found > 0:
		Events.notify.emit("Звук «проваливается» — рядом пустота под полом!", "good")
		GameState.add_skill_xp("search", 10)
	else:
		Events.notify.emit("Камертон звучит ровно. Пустот рядом нет.", "info")
	emit_noise(2.0)


func use_chalk() -> void:
	var ci := inventory.find("chalk")
	if ci < 0:
		Events.notify.emit("Нет мела", "warn")
		return
	var ap := aim_point()
	if ap.is_empty() or absf((ap.normal as Vector3).y) > 0.6:
		Events.notify.emit("Наведитесь на стену или дверь", "warn")
		return
	Events.open_screen.emit("chalk", ap)


# ======================================================================= СОХРАНЕНИЕ
func save_data() -> Dictionary:
	return {
		"pos": SaveSystem.v3(global_position), "yaw": _yaw, "pitch": _pitch,
		"survival": survival.to_dict(), "inventory": inventory.to_array(),
		"equipment": equipment, "quickbar": quickbar, "crouch": crouching,
	}


func load_data(d: Dictionary) -> void:
	global_position = SaveSystem.to_v3(d.get("pos"), global_position)
	set_look(float(d.get("yaw", 0.0)), float(d.get("pitch", 0.0)))
	survival.from_dict(d.get("survival", {}))
	inventory.from_array(d.get("inventory", []))
	equipment = {}
	var eq: Dictionary = d.get("equipment", {})
	for k in eq:
		if eq[k] is Dictionary and ItemDB.exists(str(eq[k].get("id", ""))):
			equipment[k] = {"id": str(eq[k].id), "n": 1, "d": eq[k].get("d", {})}
	quickbar = d.get("quickbar", ["", "", "", ""])
	while quickbar.size() < 4:
		quickbar.append("")
	_update_hand_model()
	Events.equipment_changed.emit()


func _can_stand() -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.28
	q.shape = s
	q.transform = Transform3D(Basis(), global_position + Vector3.UP * 1.5)
	q.collision_mask = 1
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()
