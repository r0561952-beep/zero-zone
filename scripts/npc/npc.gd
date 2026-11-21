class_name NPC
extends CharacterBody3D
## Живой персонаж: распорядок дня, перемещение по точкам, восприятие (зрение, слух), память,
## диалог/торговля (дружелюбные), бой/бегство (враждебные), реакция на Гул.
## Далеко от игрока ИИ работает в «упрощённом» режиме (редкие обновления, без физики).

enum S { IDLE, ROUTINE, SLEEP, ALERT, CHASE, ATTACK, FLEE, HIDE, DEAD }

var npc_id := ""
var kind := "tikhon"
var display := "Тихон Петрович"
var hostile := false
var deaf := false
var hp := 100.0
var max_hp := 100.0
var state: S = S.ROUTINE
var schedule: Array = []          ## [[час_с, час_до, [точки маршрута Vector3], "место"], ...]
var patrol: Array = []
var home := Vector3.ZERO
var body: Humanoid
var save_id: String:
	get:
		return "npc:" + npc_id

var _path: Array = []
var _target := Vector3.ZERO
var _alert_pos := Vector3.ZERO
var _alert_t := 0.0
var _attack_cd := 0.0
var _attack_anim := 0.0
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO
var _think := 0.0
var _patrol_i := 0
var _routine_key := ""
var _see_player_t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("npc")
	add_to_group("saveable")
	collision_layer = 8
	collision_mask = 1 | 2 | 16
	_rng.seed = hash(npc_id)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.875
	add_child(cs)
	body = Humanoid.new()
	if kind == "tikhon":
		body.coat = Color(0.32, 0.3, 0.24)
		body.pants = Color(0.2, 0.22, 0.2)
		body.hat = Color(0.25, 0.22, 0.2)
		body.beard = true
		body.height = 1.7
	else:
		body.coat = Color(0.12, 0.14, 0.12) if _rng.randf() < 0.5 else Color(0.3, 0.12, 0.1)
		body.pants = Color(0.1, 0.1, 0.12)
		body.hat = Color(0.08, 0.08, 0.08)
	add_child(body)
	Events.noise_emitted.connect(_on_noise)
	var saved: Dictionary = GameState.world.get("npc:" + npc_id, {})
	if not saved.is_empty():
		load_data(saved)


# ================================================================ ЦИКЛ
func _physics_process(delta: float) -> void:
	if state == S.DEAD:
		return
	var player := GameState.player as Node3D
	var dist := 9999.0
	if player:
		dist = global_position.distance_to(player.global_position)
	# Далеко — «симуляция по расписанию» раз в секунду, без физики
	if dist > 130.0:
		_think -= delta
		if _think <= 0.0:
			_think = 1.0
			_far_tick()
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_attack_anim = maxf(0.0, _attack_anim - delta * 2.5)
	_think -= delta
	if _think <= 0.0:
		_think = 0.25 if dist < 40.0 else 0.6
		_decide(player, dist)
	var speed := _move(delta)
	body.lying = state == S.SLEEP
	body.animate(delta, speed, 1.0 - _attack_anim if _attack_anim > 0.0 else 0.0)


func _far_tick() -> void:
	if hostile:
		return
	var r := _routine_now()
	if r.size() > 0:
		var pts: Array = r[2]
		global_position = pts[-1]
		state = S.SLEEP if r[3] == "sleep" else S.ROUTINE
		_path = []


func _routine_now() -> Array:
	var h := GameState.hour()
	for r in schedule:
		var a: float = r[0]
		var b: float = r[1]
		if (a <= b and h >= a and h < b) or (a > b and (h >= a or h < b)):
			return r
	return []


func _decide(player: Node3D, dist: float) -> void:
	# Гул: враждебные прячутся в помещение
	if GameState.is_hum_active() and hostile and state != S.FLEE:
		state = S.HIDE
		_set_path([home])
		return
	if hostile:
		_hostile_logic(player, dist)
	else:
		_friendly_logic()


func _friendly_logic() -> void:
	var r := _routine_now()
	if r.is_empty():
		return
	var key := "%d" % int(r[0])
	if key != _routine_key:
		_routine_key = key
		var pts: Array = (r[2] as Array).duplicate()
		_set_path(pts)
	if _path.is_empty():
		state = S.SLEEP if r[3] == "sleep" else S.IDLE
		# повернуться к игроку, если рядом
		var p := GameState.player as Node3D
		if p and state == S.IDLE and global_position.distance_to(p.global_position) < 4.0:
			var to := p.global_position - global_position
			rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), 0.3)
	else:
		state = S.ROUTINE


func _hostile_logic(player: Node3D, dist: float) -> void:
	if hp < max_hp * 0.3:
		state = S.FLEE
		var away := (global_position - player.global_position).normalized() * 30.0
		_set_path([global_position + away])
		return
	var sees := _can_see(player, dist)
	if sees:
		_see_player_t += 0.3
	else:
		_see_player_t = maxf(0.0, _see_player_t - 0.15)
	if _see_player_t > 0.6 or (state in [S.CHASE, S.ATTACK] and dist < 18.0):
		if state != S.CHASE and state != S.ATTACK:
			AudioLib.play_3d("hit", global_position + Vector3.UP * 1.6, -30.0)
			Events.notify.emit("Вас заметили!", "bad")
		state = S.CHASE if dist > 1.7 else S.ATTACK
		_set_path([player.global_position])
		if state == S.ATTACK and _attack_cd <= 0.0:
			_attack_cd = 1.4
			_attack_anim = 1.0
			if player.has_method("take_damage"):
				player.take_damage(_rng.randf_range(9.0, 16.0), "удар")
				AudioLib.play_3d("hit", player.global_position, 0.0)
		return
	if state == S.ALERT:
		_alert_t -= 0.3
		if _path.is_empty() or _alert_t <= 0.0:
			state = S.ROUTINE
		return
	# день — спят в подсобке; ночь — патруль
	var night := GameState.is_night()
	if not night:
		if state != S.SLEEP:
			state = S.SLEEP if global_position.distance_to(home) < 2.0 else S.ROUTINE
			if state == S.ROUTINE:
				_set_path([home])
		elif _path.is_empty():
			state = S.SLEEP
	else:
		state = S.ROUTINE
		if _path.is_empty() and not patrol.is_empty():
			_patrol_i = (_patrol_i + 1) % patrol.size()
			_set_path([patrol[_patrol_i]])


func _can_see(player: Node3D, dist: float) -> bool:
	if player == null or not player.visible:
		return false
	if state == S.SLEEP:
		return dist < 2.5
	var rng := 26.0
	if GameState.is_night():
		rng = 9.0 if not (player.get("flashlight_on") or player.get("torch_on")) else 30.0
	if player.get("crouching"):
		rng *= 0.55
	if dist > rng:
		return false
	var fwd := global_transform.basis.z
	var to := (player.global_position - global_position).normalized()
	if fwd.dot(to) < 0.35 and dist > 3.0:
		return false
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.6, player.global_position + Vector3.UP * 1.4, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _on_noise(pos: Vector3, radius: float, source: Node) -> void:
	if state == S.DEAD or deaf or not hostile or source == self:
		return
	var d := global_position.distance_to(pos)
	var r := radius * (0.5 if state == S.SLEEP else 1.0)
	if d < r and state not in [S.CHASE, S.ATTACK, S.FLEE]:
		state = S.ALERT
		_alert_t = 12.0
		_set_path([pos])


func _set_path(pts: Array) -> void:
	_path = pts.duplicate()


func _move(delta: float) -> float:
	var spd := 0.0
	if not is_on_floor():
		velocity.y -= 14.0 * delta
	else:
		velocity.y = -0.5
	if state in [S.SLEEP, S.IDLE, S.DEAD] or _path.is_empty():
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return 0.0
	var target: Vector3 = _path[0]
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.6:
		_path.pop_front()
		return 0.0
	var run := state in [S.CHASE, S.FLEE, S.HIDE]
	spd = 4.6 if run else 1.4
	if state == S.ATTACK:
		spd = 0.0
	var dir := to.normalized()
	dir = _avoid(dir)
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 8.0 * delta)
	move_and_slide()
	# застревание: открыть дверь или перескочить к следующей точке
	if global_position.distance_to(_last_pos) < spd * delta * 0.25:
		_stuck_t += delta
		if _stuck_t > 0.8:
			_try_open_door()
		if _stuck_t > 4.0:
			global_position = Vector3(target.x, target.y + 0.1, target.z)
			_path.pop_front()
			_stuck_t = 0.0
	else:
		_stuck_t = 0.0
	_last_pos = global_position
	return Vector2(velocity.x, velocity.z).length()


func _avoid(dir: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 0.6
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 1.2, 1)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return dir
	for ang in [0.6, -0.6, 1.2, -1.2]:
		var d2 := dir.rotated(Vector3.UP, ang)
		var q2 := PhysicsRayQueryParameters3D.create(from, from + d2 * 1.2, 1)
		q2.exclude = [get_rid()]
		if space.intersect_ray(q2).is_empty():
			return d2
	return dir


func _try_open_door() -> void:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 1.0
	var q := PhysicsRayQueryParameters3D.create(from, from + global_transform.basis.z * 1.3, 1 | 4)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return
	var n: Node = hit.collider
	if n is Door.DoorPanel:
		var door: Door = (n as Door.DoorPanel).door
		if not door.open and not door.locked:
			door.use(self)


# ================================================================ ВЗАИМОДЕЙСТВИЕ
func get_prompt(_player: Node) -> String:
	if state == S.DEAD:
		return ""
	if hostile:
		return ""
	if state == S.SLEEP:
		return "%s — спит" % display
	return "Поговорить: %s" % display


func interact(_player: Node) -> void:
	if hostile or state == S.DEAD:
		return
	if state == S.SLEEP:
		Events.notify.emit("Тихон спит. Не стоит будить старика.", "info")
		return
	_path = []
	state = S.IDLE
	Events.npc_talked.emit(npc_id)
	Events.open_screen.emit("dialogue", self)


func take_damage(amount: float, attacker: Node) -> void:
	if state == S.DEAD:
		return
	hp -= amount
	AudioLib.play_3d("hit", global_position + Vector3.UP, 0.0)
	if not hostile:
		# нападение на мирного — он запомнит
		GameState.add_trust(npc_id, -40)
		GameState.set_flag("attacked_" + npc_id)
		Events.notify.emit("%s: «Ты что творишь?!»" % display, "bad")
		state = S.FLEE
		var away := (global_position - (attacker as Node3D).global_position).normalized() * 20.0
		_set_path([global_position + away])
	else:
		state = S.CHASE
	if hp <= 0.0:
		die()


func die() -> void:
	state = S.DEAD
	body.lying = true
	body.animate(0.1, 0.0)
	collision_layer = 0
	GameState.world["npc:" + npc_id] = save_data()
	if hostile:
		GameState.add_counter("jackals_down")
		var c := LootContainer.new()
		c.container_id = "body:" + npc_id
		c.title = "Обыскать тело"
		c.loot_table = "military"
		c.box_size = Vector3(1.6, 0.4, 0.6)
		c.blocking = false
		add_child(c)
	else:
		GameState.set_flag("dead_" + npc_id)


func save_data() -> Dictionary:
	return {"pos": SaveSystem.v3(global_position), "hp": hp, "dead": state == S.DEAD}


func load_data(d: Dictionary) -> void:
	global_position = SaveSystem.to_v3(d.get("pos"), global_position)
	hp = float(d.get("hp", max_hp))
	if d.get("dead", false):
		state = S.DEAD
		collision_layer = 0
		if body:
			body.lying = true
		if hostile and not has_node("Loot"):
			var c := LootContainer.new()
			c.name = "Loot"
			c.container_id = "body:" + npc_id
			c.title = "Обыскать тело"
			c.loot_table = "military"
			c.box_size = Vector3(1.6, 0.4, 0.6)
			c.blocking = false
			add_child(c)


## Фабрика NPC по описанию из world.json.
static func create(def: Dictionary) -> NPC:
	var n := NPC.new()
	n.npc_id = str(def.id)
	n.kind = str(def.kind)
	if n.kind == "tikhon":
		n.display = "Тихон Петрович"
		n.deaf = true
		# дом Тихона: центр (-150, -26), фасад на юг; печь, кровать, сени — см. шаблон house_b
		var g := func(x: float, z: float) -> Vector3: return Vector3(x, RegionData.height_at(x, z) + 0.5, z)
		var inside := [g.call(-152.9, -17.3), g.call(-153.5, -20.2), g.call(-153.5, -21.6), g.call(-153.5, -23.3), g.call(-151.4, -23.5), g.call(-149.0, -24.6)]
		var out_route := [g.call(-151.4, -23.5), g.call(-153.5, -23.3), g.call(-153.5, -21.6), g.call(-153.5, -20.2), g.call(-152.9, -17.3), g.call(-152.9, -14.5)]
		var to_bed := [g.call(-147.4, -25.2), g.call(-147.4, -26.8), g.call(-147.3, -28.4)]
		n.schedule = [
			[6.0, 9.0, out_route + [g.call(-139.0, -14.5), g.call(-139.0, -41.0), g.call(-145.0, -42.0)], "apiary"],
			[9.0, 12.0, [g.call(-144.0, -40.0), g.call(-148.0, -41.0)], "garden"],
			[12.0, 13.5, [g.call(-139.0, -41.0), g.call(-139.0, -14.5), g.call(-110.0, -3.0), g.call(-82.0, 11.0)], "well"],
			[13.5, 18.0, [g.call(-110.0, -3.0), g.call(-152.9, -14.5), g.call(-152.9, -17.3), g.call(-151.5, -19.8)], "porch"],
			[18.0, 22.0, inside, "home"],
			[22.0, 6.0, inside + to_bed, "sleep"],
		]
		n.home = g.call(-149.0, -24.6)
		n.max_hp = 80.0
		n.hp = 80.0
	else:
		n.display = "Шакал"
		n.hostile = true
		var hp: Array = def.home
		n.home = Vector3(hp[0], RegionData.height_at(hp[0], hp[1]) + 0.3, hp[1])
		for p in def.get("patrol", []):
			n.patrol.append(Vector3(p[0], RegionData.height_at(p[0], p[1]) + 0.3, p[1]))
		n.max_hp = 70.0
		n.hp = 70.0
	return n
